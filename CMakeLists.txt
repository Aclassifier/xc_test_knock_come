cmake_minimum_required(VERSION 3.21)

# XMOS requires xcommon.cmake to be included BEFORE the project definition
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)

project(xc_test_knock_come)

# Set build type. Options: Debug, Release, RelWithDebInfo, MinSizeRel
set(CMAKE_BUILD_TYPE Debug)

# Flags used specifically for the Debug configuration (-O0 disables optimization)
set(XCC_FLAGS_DEBUG "-O0 -g")

set(APP_DEPENDENT_MODULES lib_xassert lib_random)
set(APP_HW_TARGET XK-EVK-XU316)
set(XMOS_SANDBOX_DIR ${CMAKE_CURRENT_LIST_DIR}/..)

XMOS_REGISTER_APP()