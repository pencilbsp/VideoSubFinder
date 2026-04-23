# OpenCV subproject configuration
# ─────────────────────────────────────────────────────────────────────────────
# Version 4.11.0
#
# VideoSubFinder uses exactly 5 modules (from #include analysis):
#   core      — Mat, basic types, OpenCL GPU acceleration
#   imgproc   — threshold, morphology, colour conversion
#   imgcodecs — imread / imwrite (PNG, JPEG)
#   highgui   — included via <opencv2/highgui.hpp> in IPAlgorithms.h
#   videoio   — cv::VideoCapture used in OCVVideo component
#
# Excluded and why they bloat the Homebrew build:
#   viz      drags in VTK          (~93 MB)
#   dnn      drags in OpenVINO     (~23 MB)
#   sfm      drags in Ceres solver  (~7 MB)
#   gapi     drags in Abseil        (~6 MB)
#   text     drags in Tesseract     (~3 MB, unused by this project)
#   ml, calib3d, features2d, objdetect, photo, stitching — all unused
# ─────────────────────────────────────────────────────────────────────────────

set(OPENCV_VERSION "4.11.0")
set(OPENCV_GIT_TAG "4.11.0")
set(OPENCV_GIT_URL "https://github.com/opencv/opencv.git")

set(OPENCV_BUILD_LIST "core,imgproc,imgcodecs,highgui,videoio")

set(OPENCV_CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_OSX_ARCHITECTURES=arm64
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0

    -DWITH_VTK=OFF
    -DWITH_OPENVINO=OFF
    -DWITH_PROTOBUF=OFF
    -DBUILD_PROTOBUF=OFF
    -DWITH_OPENEXR=OFF
    -DWITH_WEBP=OFF
    -DWITH_TIFF=OFF
    -DWITH_1394=OFF
    -DWITH_V4L=OFF
    -DWITH_GSTREAMER=OFF
    -DWITH_QT=OFF
    -DWITH_GTK=OFF
    -DWITH_LAPACK=OFF
    -DWITH_EIGEN=OFF

    -DWITH_OPENCL=ON
    -DWITH_TBB=ON
    -DWITH_AVFOUNDATION=ON
    -DWITH_JPEG=ON
    -DWITH_PNG=ON

    -DBUILD_TESTS=OFF
    -DBUILD_PERF_TESTS=OFF
    -DBUILD_EXAMPLES=OFF
    -DBUILD_DOCS=OFF
    -DBUILD_JAVA=OFF
    -DBUILD_opencv_python=OFF
    -DBUILD_opencv_python2=OFF
    -DBUILD_opencv_python3=OFF
)
