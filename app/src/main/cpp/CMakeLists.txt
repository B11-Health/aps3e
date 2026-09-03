
# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html.
# For more examples on how to use CMake, see https://github.com/android/ndk-samples.

# Sets the minimum CMake version required for this project.
cmake_minimum_required(VERSION 3.22.1)
# Declares the project name. The project name can be accessed via ${ PROJECT_NAME},
# Since this is the top level CMakeLists.txt, the project name is also accessible
# with ${CMAKE_PROJECT_NAME} (both CMake variables are in-sync within the top level
# build script scope).
project("aps3e")

add_compile_options(-march=armv8-a)
add_compile_options(-stdlib=libc++)
#add_compile_options(-flto=thin)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_link_options(-Wl,-z,max-page-size=16384)

set(CMAKE_CXX_STANDARD 20)

project(aps3e LANGUAGES C CXX)

add_library(lang_System SHARED lang_System.cpp)

add_library(hardware_ProcessorInfo SHARED hardware_ProcessorInfo.cpp)
target_link_libraries(hardware_ProcessorInfo PRIVATE vulkan)

option(USE_NATIVE_INSTRUCTIONS "USE_NATIVE_INSTRUCTIONS makes rpcs3 compile with -march=native, which is useful for local builds, but not good for packages." OFF)
option(WITH_LLVM "Enable usage of LLVM library" ON)
option(BUILD_LLVM "Build LLVM from git submodule" ON)
option(STATIC_LINK_LLVM "Link against LLVM statically. This will get set to ON if you build LLVM from the submodule." ON)
option(USE_FAUDIO "FAudio audio backend" OFF)
option(USE_LIBEVDEV "libevdev-based joystick support" OFF)
option(USE_DISCORD_RPC "Discord rich presence integration" OFF)
option(USE_VULKAN "Vulkan render backend" ON)
option(USE_PRECOMPILED_HEADERS "Use precompiled headers" OFF)
option(USE_SDL "Enables SDL input handler" OFF)
option(USE_SYSTEM_CUBEB "Prefer system cubeb instead of the builtin one" OFF)
option(USE_SYSTEM_CURL "Prefer system Curl instead of the prebuild one" OFF)
option(USE_SYSTEM_FAUDIO "Prefer system FAudio instead of the builtin one" OFF)
option(USE_SYSTEM_FFMPEG "Prefer system ffmpeg instead of the prebuild one" OFF)
option(USE_SYSTEM_PROTOBUF "Prefer system protobuf instead of the builtin one" OFF)
option(USE_SYSTEM_GLSLANG "Prefer system glslang instead of the builtin one" OFF)
option(USE_SYSTEM_HIDAPI "Prefer system hidapi instead of the builtin one" OFF)
option(USE_SYSTEM_LIBPNG "Prefer system libpng instead of the builtin one" OFF)
option(USE_SYSTEM_LIBUSB "Prefer system libusb instead of the builtin one" OFF)
option(USE_SYSTEM_MINIUPNPC "Prefer system MiniUPnPc instead of the builtin one" OFF)
option(USE_SYSTEM_MVK "Prefer system MoltenVK instead of the builtin one" OFF)
option(USE_SYSTEM_OPENAL "Prefer system OpenAL instead of the prebuild one" ${USE_SYSTEM_OPENAL_DEFAULT})
option(USE_SYSTEM_OPENCV "Prefer system OpenCV instead of the builtin one" OFF)
option(USE_SYSTEM_PUGIXML "Prefer system pugixml instead of the builtin one" OFF)
option(USE_SYSTEM_RTMIDI "Prefer system RtMidi instead of the builtin one" OFF)
option(USE_SYSTEM_SDL "Prefer system SDL instead of the builtin one" OFF)
option(USE_SYSTEM_VULKAN_MEMORY_ALLOCATOR "Prefer system Vulkan Memory Allocator instead of the builtin one" OFF)
option(USE_SYSTEM_WOLFSSL "Prefer system wolfSSL instead of the builtin one" OFF)
option(USE_SYSTEM_ZLIB "Prefer system ZLIB instead of the builtin one" ON)
option(USE_SYSTEM_ZSTD "Prefer system zstd instead of the builtin one" OFF)
option(HAS_MEMORY_BREAKPOINTS "Add support for memory breakpoints to the interpreter" OFF)
option(USE_LTO "Use LTO for building" OFF)
option(BUILD_RPCS3_TESTS "Build RPCS3 unit tests." OFF)
option(RUN_RPCS3_TESTS "Run RPCS3 unit tests. Requires BUILD_RPCS3_TESTS" OFF)
option(USE_GAMEMODE "Choose whether to enable GameMode features or not." OFF)

add_subdirectory(rpcs3 EXCLUDE_FROM_ALL)

add_library(emu SHARED)
set_target_properties(emu PROPERTIES OUTPUT_NAME "e")

target_link_options(emu PRIVATE -Wl,--exclude-libs,ALL)

#target_compile_options(emu PRIVATE -flto)
#target_link_options(emu PRIVATE -flto)

target_sources(emu
        PRIVATE
        rpcs3/rpcs3/Input/raw_mouse_config.cpp
        rpcs3/rpcs3/Input/raw_mouse_handler.cpp
        rpcs3/rpcs3/Input/product_info.cpp
        rpcs3/rpcs3/Input/ps_move_tracker.cpp
        rpcs3/rpcs3/Input/ps_move_config.cpp
        rpcs3/rpcs3/Input/pad_thread.cpp
        rpcs3/rpcs3/rpcs3_version.cpp
        rpcs3/rpcs3/stdafx.cpp
        aps3e_rp3_impl.cpp
        aps3e_emu.cpp
        aps3e.cpp
        vkapi.cpp
        vkutil.cpp
        cpuinfo.cpp
        glsl2spv.cpp
        meminfo.cpp
        emulator.cpp
        emulator_aps3e.cpp
)

target_link_libraries(emu PRIVATE rpcs3_emu)
target_link_libraries(emu PRIVATE 3rdparty::yaml-cpp 3rdparty::hidapi 3rdparty::libusb 3rdparty::wolfssl 3rdparty::libcurl 3rdparty::glslang 3rdparty::ffmpeg)
target_link_libraries(emu PRIVATE android)
target_link_libraries(emu PRIVATE 3rdparty::fusion 3rdparty::adrenotools)
if(ANDROID AND GAMEDECK_ICONV_LIBRARY)
    target_link_libraries(emu PRIVATE "${GAMEDECK_ICONV_LIBRARY}")
    if(GAMEDECK_CHARSET_LIBRARY)
        target_link_libraries(emu PRIVATE "${GAMEDECK_CHARSET_LIBRARY}")
    endif()
endif()
