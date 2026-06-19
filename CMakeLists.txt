####
# This sets up the build system for the 'fprime-zephyr-reference' project, including
# components and deployments from project.cmake. In addition, it imports the core F Prime components.
#
# Based on https://github.com/Open-Source-Space-Foundation/proves-core-reference/blob/main/CMakeLists.txt
####

cmake_minimum_required(VERSION 3.24.2)
add_compile_definitions(_POSIX_C_SOURCE=200809L)

# Set BOARD_ROOT to find custom boards
# The structure is BOARD_ROOT/boards/vendor/board
list(APPEND BOARD_ROOT "${CMAKE_CURRENT_LIST_DIR}")

# Patch in std-atomic implementations
if (BOARD STREQUAL "rpi_pico" OR FPRIME_ZEPHYR_USE_STD_ATOMIC_FIX)
    include_directories(BEFORE "${CMAKE_CURRENT_LIST_DIR}/lib/fprime-zephyr/fprime-zephyr/Os/StdAtomic")
endif()

# When running tests, avoid pulling in Zephyr (no BOARD etc. needed)
if (NOT BUILD_TESTING)
    find_package(Zephyr HINTS "${CMAKE_CURRENT_LIST_DIR}/lib/zephyr-workspace")
endif()

project(fprime-zephyr-reference C CXX)

# Enable Zephyr Pico hardware_adc library
zephyr_include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/lib/zephyr-workspace/modules/hal/rpi_pico/src/rp2_common/hardware_adc/include
)

# Use memory-mapped SIO for GPIO instead of the RP2350 GPIO coprocessor (CP0).
# The rpi_pico HAL defaults PICO_USE_GPIO_COPROCESSOR=1 (HAS_GPIO_COPROCESSOR),
# emitting `mcr p0` coprocessor instructions for gpio_set/clr_mask. With
# CONFIG_FPU disabled, Zephyr's CPACR handling (FPU-disable + RCP/CP7 enable)
# clobbers CP0 back to off after soc_reset_hook enabled it, so the first GPIO
# coprocessor op (e.g. SPI chip-select during a LoRa UHF retransmit of uplinked
# bytes) faults NOCP (UsageFault reason=33, CFSR=0x00080000) and the board
# silently reboots. Forcing the memory-mapped path removes the CP0 dependency.
zephyr_compile_definitions(PICO_USE_GPIO_COPROCESSOR=0)

# Disable F´ framework/autocoder/app unit tests; PROVES uses GoogleTests in tests/ when present
set(FPRIME_ENABLE_FRAMEWORK_UTS OFF CACHE BOOL "" FORCE)
set(FPRIME_ENABLE_AUTOCODER_UTS OFF CACHE BOOL "" FORCE)
set(FPRIME_ENABLE_APP_UTS OFF CACHE BOOL "" FORCE)

# Put in an option to force the device back into programmable state for automated testing
option(FPRIME_CI_FAILSAFE_ENABLED "Cycle count before a forced reset to programmable state" OFF)
if (FPRIME_CI_FAILSAFE_ENABLED)
    set(FPRIME_CI_FAILSAFE_CYCLE_COUNT 6000 CACHE STRING "Cycles before a forced reset")
    add_compile_definitions(FPRIME_CI_FAILSAFE_CYCLE_COUNT=${FPRIME_CI_FAILSAFE_CYCLE_COUNT})
endif()

###
# F' Core Setup
# This includes all of the F prime core components, and imports the make-system.
###
include("${CMAKE_CURRENT_LIST_DIR}/lib/fprime/cmake/FPrime.cmake")
# NOTE: register custom targets between these two lines
fprime_setup_included_code()

# This includes project-wide objects
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/FprimeZephyrReference")

if (FPRIME_USE_POSIX)
    set_target_properties(Drv_Ip PROPERTIES EXCLUDE_FROM_ALL TRUE)
    set_target_properties(Drv_TcpServer PROPERTIES EXCLUDE_FROM_ALL TRUE)
    set_target_properties(Drv_TcpClient PROPERTIES EXCLUDE_FROM_ALL TRUE)
    set_target_properties(Drv_Udp PROPERTIES EXCLUDE_FROM_ALL TRUE)
endif()
set_target_properties(Svc_FatalHandler PROPERTIES EXCLUDE_FROM_ALL TRUE)
set_target_properties(fprime-zephyr_Drv_ZephyrSpiDriver PROPERTIES EXCLUDE_FROM_ALL TRUE)
set_target_properties(Svc_FileWorker_test_FileTester PROPERTIES EXCLUDE_FROM_ALL TRUE)

# If BUILD_TESTING is ON, add GoogleTest tests (same pattern as proves-core-reference)
if (BUILD_TESTING AND EXISTS "${CMAKE_CURRENT_LIST_DIR}/tests/CMakeLists.txt")
    enable_testing()
    add_subdirectory(tests)
endif()

###
# Raspberry Pi Pico Debug Probe (ground-radio-controller)
###
set(RPI_OPENOCD_DIR "${CMAKE_BINARY_DIR}/rpi-openocd")
set(RPI_OPENOCD_BIN "${RPI_OPENOCD_DIR}/openocd")

add_custom_command(
    OUTPUT "${RPI_OPENOCD_BIN}"
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/get-rpi-openocd.sh" "${RPI_OPENOCD_DIR}"
    COMMENT "Fetching rpi-openocd into ${RPI_OPENOCD_DIR}"
    VERBATIM
)

add_custom_target(rpi-openocd DEPENDS "${RPI_OPENOCD_BIN}")

set(PROGRAM_OPENOCD_CFG "${CMAKE_SOURCE_DIR}/openocd/program.cfg")

add_custom_target(program-board
    COMMAND "${RPI_OPENOCD_BIN}"
            -s "${RPI_OPENOCD_DIR}/scripts"
            -c "set ELF \"$<TARGET_FILE:zephyr_final>\""
            -f "${PROGRAM_OPENOCD_CFG}"
    DEPENDS rpi-openocd
    USES_TERMINAL
    VERBATIM
)
