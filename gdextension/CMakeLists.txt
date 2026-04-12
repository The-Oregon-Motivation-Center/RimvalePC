cmake_minimum_required(VERSION 3.22)
project(rimvale_engine CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ─── godot-cpp ────────────────────────────────────────────────────────────────
# Clone with:
#   git submodule add https://github.com/godotengine/godot-cpp.git gdextension/godot-cpp
#   git submodule update --init --recursive
set(GODOT_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp")
if(NOT EXISTS "${GODOT_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
        "godot-cpp not found at ${GODOT_CPP_DIR}.\n"
        "Run: git submodule add https://github.com/godotengine/godot-cpp.git gdextension/godot-cpp && git submodule update --init --recursive")
endif()
add_subdirectory(${GODOT_CPP_DIR})

# ─── Engine source (shared with Android project) ─────────────────────────────
set(ENGINE_SRC "${CMAKE_CURRENT_SOURCE_DIR}/../../AndroidStudioProjects/RimvaleMobile/app/src/main/cpp")

# ─── Extension sources ────────────────────────────────────────────────────────
set(EXTENSION_SOURCES
    src/rimvale_extension.cpp
    src/register_types.cpp
    src/platform_out.cpp
    # Game logic from the Android project (no Android-specific files)
    ${ENGINE_SRC}/Character.cpp
    ${ENGINE_SRC}/Behavior.cpp
    ${ENGINE_SRC}/CombatManager.cpp
    # Utility.cpp excluded: contains Android-specific OpenGL code (checkAndLogGlError, matrix builders)
    # that has no equivalent on PC and is not used by any game logic.
    # NOTE: Do NOT include main.cpp, Renderer.cpp, Shader.cpp,
    #       TextureAsset.cpp, jni_bridge.cpp, or AndroidOut.cpp
    #       Those are Android-specific and replaced by this GDExtension.
)

add_library(rimvale_engine SHARED ${EXTENSION_SOURCES})

# ─── Include paths ────────────────────────────────────────────────────────────
# IMPORTANT: src/ must come BEFORE ENGINE_SRC so our cross-platform
# AndroidOut.h shadows the original Android-specific one.
target_include_directories(rimvale_engine PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${ENGINE_SRC}"
)
target_link_libraries(rimvale_engine PUBLIC godot-cpp)

# ─── Output directory ─────────────────────────────────────────────────────────
set(OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../addons/rimvale_engine/bin")
set_target_properties(rimvale_engine PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
    LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
    ARCHIVE_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
)

# ─── Platform-specific output naming (matches .gdextension file) ──────────────
if(WIN32)
    set_target_properties(rimvale_engine PROPERTIES
        OUTPUT_NAME "librimvale_engine.windows.$<IF:$<CONFIG:Debug>,debug,release>.x86_64"
        SUFFIX ".dll"
    )
elseif(UNIX AND NOT APPLE AND NOT ANDROID)
    set_target_properties(rimvale_engine PROPERTIES
        OUTPUT_NAME "librimvale_engine.linux.$<IF:$<CONFIG:Debug>,debug,release>.x86_64"
        SUFFIX ".so"
    )
elseif(APPLE AND NOT IOS)
    set_target_properties(rimvale_engine PROPERTIES
        OUTPUT_NAME "librimvale_engine.macos.$<IF:$<CONFIG:Debug>,debug,release>"
        SUFFIX ".framework"
    )
elseif(ANDROID)
    set_target_properties(rimvale_engine PROPERTIES
        OUTPUT_NAME "librimvale_engine.android.$<IF:$<CONFIG:Debug>,debug,release>.arm64"
        SUFFIX ".so"
    )
endif()

# ─── Compiler warnings ────────────────────────────────────────────────────────
if(MSVC)
    target_compile_options(rimvale_engine PRIVATE /W3)
    # Force-include our cross-platform AndroidOut.h stub BEFORE any source file
    # so its include guard blocks the Android-specific version in ENGINE_SRC
    # /bigobj: rimvale_extension.cpp exceeds default COFF section limit
    target_compile_options(rimvale_engine PRIVATE
        /FI "${CMAKE_CURRENT_SOURCE_DIR}/src/AndroidOut.h"
        /bigobj
    )
else()
    target_compile_options(rimvale_engine PRIVATE -Wall -Wextra -Wno-unused-parameter)
endif()
