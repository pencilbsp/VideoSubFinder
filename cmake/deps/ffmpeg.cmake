# FFmpeg subproject configuration
# ─────────────────────────────────────────────────────────────────────────────
# Version 6.1.1 — last stable release fully compatible with OpenCV 4.11.x
# (avcodec_close removed in 7.0; av_stream_get_side_data removed in 8.0)
#
# Build strategy: decoder-only (no encoders, no muxers, no programs)
# Hardware decode: VideoToolbox (system framework on Apple Silicon)
#
# Included codecs (all built-in, no external codec libs required):
#   Video decode  H.264, H.265/HEVC, VP8, VP9, AV1, MPEG-4, MPEG-2,
#                 MPEG-1, MJPEG, FLV/Sorenson, WMV3/VC-1, Theora
#   Containers    MP4/MOV, MKV/WebM, AVI, MPEG-TS, FLV, ASF/WMV, RM
#   Protocols     file, pipe (local files only)
#
# To add network streams, append to FFMPEG_CONFIGURE_ARGS:
#   --enable-protocol=http,https,tcp,tls
# ─────────────────────────────────────────────────────────────────────────────

set(FFMPEG_VERSION "6.1.1")
set(FFMPEG_GIT_TAG "n6.1.1")
set(FFMPEG_GIT_URL "https://github.com/FFmpeg/FFmpeg.git")

set(FFMPEG_CONFIGURE_ARGS
    --arch=arm64
    --enable-shared
    --disable-static
    --disable-programs
    --disable-doc
    --disable-debug
    --disable-avdevice
    --disable-postproc
    --disable-encoders
    --disable-muxers
    --enable-videotoolbox
    --enable-hwaccel=h264_videotoolbox,hevc_videotoolbox,vp9_videotoolbox,av1_videotoolbox
    --disable-iconv
)
