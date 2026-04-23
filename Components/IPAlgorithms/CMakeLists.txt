file(GLOB IPAlgorithms_src
     "*.h"
     "*.cpp"
)

if(APPLE)
    file(GLOB IPAlgorithms_mm_src "*.mm")
    list(APPEND IPAlgorithms_src ${IPAlgorithms_mm_src})
endif()

add_library(IPAlgorithms STATIC ${IPAlgorithms_src})

target_compile_features(IPAlgorithms PUBLIC cxx_std_17)

target_include_directories(IPAlgorithms PUBLIC
	"../Include"
	 ${wxWidgets_INCLUDE_DIRS}
	 ${OpenCV_INCLUDE_DIRS}
	 ${CUDAKernels_INCLUDE_DIRS}
)

if (WIN32)
else()
target_compile_definitions(IPAlgorithms PUBLIC
	${wxWidgets_DEFINITIONS}
	$<$<CONFIG:Debug>:${wxWidgets_DEFINITIONS_DEBUG}>)
target_compile_options(IPAlgorithms PRIVATE ${wxWidgets_CXX_FLAGS})
endif (WIN32)

if(APPLE)
    target_link_libraries(IPAlgorithms PUBLIC
        "-framework Vision"
        "-framework CoreImage"
        "-framework Foundation"
        "-framework CoreGraphics"
    )
endif()
