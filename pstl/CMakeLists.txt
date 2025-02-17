#===-- CMakeLists.txt ----------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
#===----------------------------------------------------------------------===##
cmake_minimum_required(VERSION 3.13.4)

include(GNUInstallDirs)

set(PARALLELSTL_VERSION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/include/pstl/internal/pstl_config.h")
file(STRINGS "${PARALLELSTL_VERSION_FILE}" PARALLELSTL_VERSION_SOURCE REGEX "#define _PSTL_VERSION .*$")
string(REGEX REPLACE "#define _PSTL_VERSION (.*)$" "\\1" PARALLELSTL_VERSION_SOURCE "${PARALLELSTL_VERSION_SOURCE}")
math(EXPR VERSION_MAJOR "(${PARALLELSTL_VERSION_SOURCE} / 1000)")
math(EXPR VERSION_MINOR "((${PARALLELSTL_VERSION_SOURCE} % 1000) / 10)")
math(EXPR VERSION_PATCH "(${PARALLELSTL_VERSION_SOURCE} % 10)")

project(ParallelSTL VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH} LANGUAGES CXX)

set(PSTL_PARALLEL_BACKEND "serial" CACHE STRING "Threading backend to use. Valid choices are 'serial', 'omp', and 'tbb'. The default is 'serial'.")
set(PSTL_HIDE_FROM_ABI_PER_TU OFF CACHE BOOL "Whether to constrain ABI-unstable symbols to each translation unit (basically, mark them with C's static keyword).")
set(_PSTL_HIDE_FROM_ABI_PER_TU ${PSTL_HIDE_FROM_ABI_PER_TU}) # For __pstl_config_site

if (NOT TBB_DIR)
    get_filename_component(PSTL_DIR_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    string(REPLACE pstl tbb TBB_DIR_NAME ${PSTL_DIR_NAME})
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../${TBB_DIR_NAME}/cmake")
        get_filename_component(TBB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../${TBB_DIR_NAME}/cmake" ABSOLUTE)
    endif()
endif()

###############################################################################
# Setup the ParallelSTL library target
###############################################################################
add_library(ParallelSTL INTERFACE)
add_library(pstl::ParallelSTL ALIAS ParallelSTL)
target_compile_features(ParallelSTL INTERFACE cxx_std_17)

if (PSTL_PARALLEL_BACKEND STREQUAL "serial")
    message(STATUS "Parallel STL uses the serial backend")
    set(_PSTL_PAR_BACKEND_SERIAL ON)
elseif (PSTL_PARALLEL_BACKEND STREQUAL "tbb")
    find_package(TBB 2018 REQUIRED tbb OPTIONAL_COMPONENTS tbbmalloc)
    message(STATUS "Parallel STL uses TBB ${TBB_VERSION} (interface version: ${TBB_INTERFACE_VERSION})")
    target_link_libraries(ParallelSTL INTERFACE TBB::tbb)
    set(_PSTL_PAR_BACKEND_TBB ON)
elseif (PSTL_PARALLEL_BACKEND STREQUAL "omp")
    message(STATUS "Parallel STL uses the omp backend")
    target_compile_options(ParallelSTL INTERFACE "-fopenmp=libomp")
    set(_PSTL_PAR_BACKEND_OPENMP ON)
else()
    message(FATAL_ERROR "Requested unknown Parallel STL backend '${PSTL_PARALLEL_BACKEND}'.")
endif()

set(PSTL_GENERATED_HEADERS_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated_headers")
set(PSTL_CONFIG_SITE_PATH "${PSTL_GENERATED_HEADERS_DIR}/__pstl_config_site")
configure_file("include/__pstl_config_site.in"
               "${PSTL_CONFIG_SITE_PATH}"
               @ONLY)

target_include_directories(ParallelSTL
    INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<BUILD_INTERFACE:${PSTL_GENERATED_HEADERS_DIR}>
    $<INSTALL_INTERFACE:include>)

###############################################################################
# Setup tests
###############################################################################
enable_testing()
add_subdirectory(test)

###############################################################################
# Install the target and the associated CMake files
###############################################################################
include(CMakePackageConfigHelpers)
write_basic_package_version_file("${CMAKE_CURRENT_BINARY_DIR}/ParallelSTLConfigVersion.cmake"
                                 COMPATIBILITY ExactVersion)

configure_file(cmake/ParallelSTLConfig.cmake.in
               "${CMAKE_CURRENT_BINARY_DIR}/ParallelSTLConfig.cmake"
               @ONLY)

install(TARGETS ParallelSTL
        EXPORT ParallelSTLTargets)
install(EXPORT ParallelSTLTargets
        FILE ParallelSTLTargets.cmake
        NAMESPACE pstl::
        DESTINATION lib/cmake/ParallelSTL)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/ParallelSTLConfig.cmake"
              "${CMAKE_CURRENT_BINARY_DIR}/ParallelSTLConfigVersion.cmake"
        DESTINATION lib/cmake/ParallelSTL)
install(DIRECTORY include/
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
        PATTERN "*.in" EXCLUDE)
install(FILES "${PSTL_CONFIG_SITE_PATH}"
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

add_custom_target(install-pstl
                  COMMAND "${CMAKE_COMMAND}" -P "${PROJECT_BINARY_DIR}/cmake_install.cmake" -DCOMPONENT=ParallelSTL)
