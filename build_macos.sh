#!/bin/bash
# build_macos.sh — macOS arm64 build for VideoSubFinder
#
# Subproject configuration lives in cmake/deps/:
#   cmake/deps/ffmpeg.cmake  — FFmpeg version & configure flags
#   cmake/deps/opencv.cmake  — OpenCV version & cmake flags
#
# Built artefacts are cached in .deps/ and reused on subsequent runs.
# To force a rebuild, delete the corresponding stamp file printed at the end.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dist"
APP="$DIST_DIR/VideoSubFinder.app"
APP_MACOS="$APP/Contents/MacOS"
APP_RESOURCES="$APP/Contents/Resources"
DEPS_DIR="$SCRIPT_DIR/.deps"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Load subproject configs ───────────────────────────────────────────────────
# Parse cmake/deps/*.cmake to extract version/url/flag variables.
# Supported variable types: set(VAR "value") and set(VAR item1 item2 ...)
parse_cmake_set() {
    local file="$1" varname="$2"
    # Extract the value of a set(...) call; strips cmake # comments and extra whitespace
    perl -0777 -ne "
        if (/set\(\s*${varname}\s+(.*?)\s*\)/s) {
            my \$val = \$1;
            \$val =~ s/#[^\n]*//g;      # strip cmake-style comments
            \$val =~ s/\"([^\"]*)\"/\$1/g; # unquote \"value\"
            \$val =~ s/\s+/ /g;
            \$val =~ s/^\s+|\s+\$//g;
            print \$val;
        }
    " "$file"
}

DEPS_CMAKE_DIR="$SCRIPT_DIR/cmake/deps"

FFMPEG_VERSION="$(parse_cmake_set "$DEPS_CMAKE_DIR/ffmpeg.cmake" FFMPEG_VERSION)"
FFMPEG_GIT_TAG="$(parse_cmake_set "$DEPS_CMAKE_DIR/ffmpeg.cmake" FFMPEG_GIT_TAG)"
FFMPEG_GIT_URL="$(parse_cmake_set "$DEPS_CMAKE_DIR/ffmpeg.cmake" FFMPEG_GIT_URL)"
FFMPEG_INSTALL="$DEPS_DIR/ffmpeg"

OPENCV_VERSION="$(parse_cmake_set "$DEPS_CMAKE_DIR/opencv.cmake" OPENCV_VERSION)"
OPENCV_GIT_TAG="$(parse_cmake_set "$DEPS_CMAKE_DIR/opencv.cmake" OPENCV_GIT_TAG)"
OPENCV_GIT_URL="$(parse_cmake_set "$DEPS_CMAKE_DIR/opencv.cmake" OPENCV_GIT_URL)"
OPENCV_INSTALL="$DEPS_DIR/opencv"

# ── Check dependencies ────────────────────────────────────────────────────────
check_dep() {
    command -v "$1" &>/dev/null || error "Required tool not found: $1. Install with: brew install $2"
}

validate_bundled_dylibs() {
    local frameworks_dir="$APP/Contents/Frameworks"
    local file dep rel missing
    local -a files

    files=("$APP_MACOS/VideoSubFinderWXW")
    if [ -d "$frameworks_dir" ]; then
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find "$frameworks_dir" -maxdepth 1 -type f -name '*.dylib' -print0)
    fi

    missing=0
    for file in "${files[@]}"; do
        [ -f "$file" ] || continue
        while IFS= read -r dep; do
            case "$dep" in
                ""|/usr/lib/*|/System/Library/*)
                    ;;
                @rpath/*)
                    if [ ! -f "$frameworks_dir/${dep##*/}" ]; then
                        warning "Unresolved @rpath dependency: $file -> $dep"
                        missing=1
                    fi
                    ;;
                @loader_path/*)
                    rel="${dep#@loader_path/}"
                    if [ ! -e "$(dirname "$file")/$rel" ]; then
                        warning "Unresolved @loader_path dependency: $file -> $dep"
                        missing=1
                    fi
                    ;;
                @executable_path/*)
                    rel="${dep#@executable_path/}"
                    if [ ! -e "$APP_MACOS/$rel" ]; then
                        warning "Unresolved @executable_path dependency: $file -> $dep"
                        missing=1
                    fi
                    ;;
                "$APP"/*)
                    ;;
                /*)
                    warning "External dependency remains: $file -> $dep"
                    missing=1
                    ;;
            esac
        done < <(otool -L "$file" | awk 'NR > 1 { print $1 }')
    done

    [ "$missing" -eq 0 ] || error "Bundle dependency validation failed"
    info "Bundle dependency validation passed."
}

info "Checking host dependencies..."
check_dep cmake     cmake
check_dep git       git
check_dep pkg-config pkg-config
check_dep wx-config wxwidgets
pkg-config --exists tbb || error "TBB not found. Install with: brew install tbb"

CPU_COUNT="$(sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
mkdir -p "$DEPS_DIR"

# ── Build minimal FFmpeg ──────────────────────────────────────────────────────
FFMPEG_STAMP="$FFMPEG_INSTALL/.built_${FFMPEG_VERSION}"

if [ ! -f "$FFMPEG_STAMP" ]; then
    info "Building FFmpeg $FFMPEG_VERSION (one-time, ~3 min)..."

    FFMPEG_SRC="$DEPS_DIR/src/ffmpeg-${FFMPEG_VERSION}"
    if [ ! -d "$FFMPEG_SRC/.git" ]; then
        info "Cloning FFmpeg $FFMPEG_GIT_TAG..."
        git clone --depth=1 --branch "$FFMPEG_GIT_TAG" "$FFMPEG_GIT_URL" "$FFMPEG_SRC"
    fi

    FFMPEG_CONF_FLAGS="$(parse_cmake_set "$DEPS_CMAKE_DIR/ffmpeg.cmake" FFMPEG_CONFIGURE_ARGS)"

    pushd "$FFMPEG_SRC" > /dev/null
    # shellcheck disable=SC2086  — intentional word-split of flag string
    ./configure --prefix="$FFMPEG_INSTALL" $FFMPEG_CONF_FLAGS
    make -j"$CPU_COUNT"
    make install
    popd > /dev/null

    touch "$FFMPEG_STAMP"
    info "FFmpeg $FFMPEG_VERSION build complete."
fi

# ── Build minimal OpenCV ──────────────────────────────────────────────────────
OPENCV_STAMP="$OPENCV_INSTALL/.built_${OPENCV_VERSION}"

if [ ! -f "$OPENCV_STAMP" ]; then
    info "Building OpenCV $OPENCV_VERSION (one-time, ~5 min)..."

    OPENCV_SRC="$DEPS_DIR/src/opencv-${OPENCV_VERSION}"
    OPENCV_BUILD="$DEPS_DIR/opencv-build"

    if [ ! -d "$OPENCV_SRC/.git" ]; then
        info "Cloning OpenCV $OPENCV_GIT_TAG..."
        git clone --depth=1 --branch "$OPENCV_GIT_TAG" "$OPENCV_GIT_URL" "$OPENCV_SRC"
    fi

    rm -rf "$OPENCV_BUILD"

    OPENCV_CONF_FLAGS="$(parse_cmake_set "$DEPS_CMAKE_DIR/opencv.cmake" OPENCV_CMAKE_ARGS)"
    OPENCV_BUILD_LIST="$(parse_cmake_set "$DEPS_CMAKE_DIR/opencv.cmake" OPENCV_BUILD_LIST)"

    PKG_CONFIG_PATH="$FFMPEG_INSTALL/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
    cmake -S "$OPENCV_SRC" -B "$OPENCV_BUILD" \
        -DCMAKE_INSTALL_PREFIX="$OPENCV_INSTALL" \
        -DBUILD_LIST="$OPENCV_BUILD_LIST" \
        $OPENCV_CONF_FLAGS \
        -DWITH_FFMPEG=ON \
        -DFFMPEG_INCLUDE_DIR="$FFMPEG_INSTALL/include" \
        -DFFMPEG_LIB_DIR="$FFMPEG_INSTALL/lib"

    cmake --build "$OPENCV_BUILD" --parallel "$CPU_COUNT"
    cmake --install "$OPENCV_BUILD"
    rm -rf "$OPENCV_BUILD"
    touch "$OPENCV_STAMP"
    info "OpenCV $OPENCV_VERSION build complete."
fi

# ── Build VideoSubFinder ──────────────────────────────────────────────────────
info "Configuring VideoSubFinder..."
PKG_CONFIG_PATH="$FFMPEG_INSTALL/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_CUDA=OFF \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DOpenCV_DIR="$OPENCV_INSTALL/lib/cmake/opencv4" \
    -DwxWidgets_CONFIG_EXECUTABLE="$(which wx-config)"

info "Building VideoSubFinder ($CPU_COUNT cores)..."
cmake --build "$BUILD_DIR" --parallel "$CPU_COUNT"

BINARY="$BUILD_DIR/Interfaces/VideoSubFinderWXW/VideoSubFinderWXW"
[ -f "$BINARY" ] || error "Build failed: binary not found at $BINARY"

# ── Install to dist ───────────────────────────────────────────────────────────
info "Installing..."
cmake --install "$BUILD_DIR" --prefix "$DIST_DIR/stage"

# ── Create .app bundle ────────────────────────────────────────────────────────
info "Creating VideoSubFinder.app..."
rm -rf "$APP"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cp "$DIST_DIR/stage/VideoSubFinder/VideoSubFinderWXW" "$APP_MACOS/"
cp -r "$DIST_DIR/stage/VideoSubFinder/bitmaps"        "$APP_MACOS/bitmaps"
cp -r "$DIST_DIR/stage/VideoSubFinder/settings"       "$APP_MACOS/settings"
cp -r "$DIST_DIR/stage/VideoSubFinder/Docs"           "$APP_MACOS/Docs"

ICON_MAKER="$SCRIPT_DIR/tools/make_macos_icon.swift"
if [ -f "$ICON_MAKER" ]; then
    info "Generating macOS icon from original application icon..."
    mkdir -p "$BUILD_DIR/swift-module-cache"
    swift -module-cache-path "$BUILD_DIR/swift-module-cache" "$ICON_MAKER"
fi

ICNS_SRC="$SCRIPT_DIR/Data/VideoSubFinder.icns"
ICNS_OUT="$APP_RESOURCES/VideoSubFinder.icns"
if [ -f "$ICNS_SRC" ]; then
    cp "$ICNS_SRC" "$ICNS_OUT"
else
    warning "macOS icon not found: $ICNS_SRC"
fi

PLIST_FILE="$APP/Contents/Info.plist"
cat > "$PLIST_FILE" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>VideoSubFinder</string>
    <key>CFBundleDisplayName</key>
    <string>VideoSubFinder</string>
    <key>CFBundleIdentifier</key>
    <string>com.videosubfinder.VideoSubFinder</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>VideoSubFinderWXW</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>VideoSubFinder by Simeon Kosnitsky</string>
</dict>
</plist>
PLIST

if [ -f "$ICNS_OUT" ]; then
    ICON_ENTRY="    <key>CFBundleIconFile<\/key>\n    <string>VideoSubFinder<\/string>"
    sed -i '' "s|<key>NSHighResolutionCapable<\/key>|${ICON_ENTRY}\n    <key>NSHighResolutionCapable<\/key>|" "$PLIST_FILE"
fi

# ── Bundle dylibs ─────────────────────────────────────────────────────────────
if command -v dylibbundler &>/dev/null; then
    info "Bundling dylib dependencies..."
    mkdir -p "$APP/Contents/Frameworks"

    DYLIBBUNDLER_LOG="$(mktemp)"
    DYLIBBUNDLER_ARGS=(
        -od -b
        -x "$APP_MACOS/VideoSubFinderWXW"
        -d "$APP/Contents/Frameworks/"
        -p "@rpath/"
        -s "$FFMPEG_INSTALL/lib"
        -s "$OPENCV_INSTALL/lib"
    )
    if command -v brew &>/dev/null && brew --prefix gcc &>/dev/null 2>/dev/null; then
        DYLIBBUNDLER_ARGS+=(-s "$(brew --prefix gcc)/lib/gcc/current")
    fi

    OPENCV_RPATH_WARNING_RE="^/!\\\\ WARNING : can't get path for '@rpath/libopencv_.*\\.dylib'$"

    if dylibbundler "${DYLIBBUNDLER_ARGS[@]}" >"$DYLIBBUNDLER_LOG" 2>&1; then
        MSGS="$(grep -E '(^/!\\|^Error:|Cannot resolve|failed)' "$DYLIBBUNDLER_LOG" \
               | grep -Evi 'invalidate the code signature|replacing existing signature' \
               | grep -Ev "$OPENCV_RPATH_WARNING_RE" || true)"
        [ -n "$MSGS" ] && { printf '%s\n' "$MSGS"; warning "dylibbundler completed with messages above"; } \
                       || info "dylibbundler completed."
    else
        cat "$DYLIBBUNDLER_LOG"; rm -f "$DYLIBBUNDLER_LOG"
        error "dylibbundler failed"
    fi
    rm -f "$DYLIBBUNDLER_LOG"

    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_MACOS/VideoSubFinderWXW" 2>/dev/null || true

    # dylibbundler replaces @loader_path rpaths with bare "@rpath/" which
    # macOS dyld 14+ rejects as invalid. Strip them from all bundled dylibs.
    info "Removing invalid @rpath/ entries from bundled dylibs..."
    for dylib in "$APP/Contents/Frameworks/"*.dylib; do
        count=$(otool -l "$dylib" 2>/dev/null \
                | awk '/LC_RPATH/{f=1} f && /path /{print $2; f=0}' \
                | grep -c "^@rpath/$" || true)
        for ((i=0; i<count; i++)); do
            install_name_tool -delete_rpath "@rpath/" "$dylib" 2>/dev/null || true
        done
    done

    validate_bundled_dylibs
else
    warning "dylibbundler not found — app requires Homebrew libs on target machine."
    warning "Install with: brew install dylibbundler"
fi

# ── Code sign (ad-hoc) ────────────────────────────────────────────────────────
info "Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP" 2>/dev/null || warning "Code signing failed (non-fatal)"

# ── Cleanup + report ──────────────────────────────────────────────────────────
rm -rf "$DIST_DIR/stage"

APP_SIZE="$(du -sh "$APP" | cut -f1)"
DYLIB_COUNT="$(ls "$APP/Contents/Frameworks/" 2>/dev/null | wc -l | tr -d ' ')"
info "Done!  $APP  ($APP_SIZE, $DYLIB_COUNT bundled dylibs)"
info "Run:   open \"$APP\""
info ""
info "To force rebuild a subproject, delete its stamp file:"
info "  FFmpeg : $FFMPEG_STAMP"
info "  OpenCV : $OPENCV_STAMP"
