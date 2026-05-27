# cmake_minimum_required(VERSION 3.21)
# include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
# project(xc_test_knock_come)
# set(XMOS_SANDBOX_DIR "/Users/teig/Documents/_Dokumenter/Oyvind/_PROSJEKT/GitHub/workspace")
# set(APP_DEPENDENT_MODULES lib_xassert module_random)
# set(APP_HW_TARGET XK-EVK-XU316)
# XMOS_REGISTER_APP()

cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(xc_test_knock_come)

set(APP_DEPENDENT_MODULES lib_xassert lib_random)
set(APP_HW_TARGET XK-EVK-XU316)
set(XMOS_SANDBOX_DIR ${CMAKE_CURRENT_LIST_DIR}/..)

XMOS_REGISTER_APP()