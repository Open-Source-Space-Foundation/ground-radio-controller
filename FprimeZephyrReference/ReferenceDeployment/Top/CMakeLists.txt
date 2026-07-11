####
# F Prime CMakeLists.txt:
#
# SOURCES: list of source files (to be compiled)
# AUTOCODER_INPUTS: list of files to be passed to the autocoders
# DEPENDS: list of libraries that this module depends on
#
# Per-board radio selection (Phase 6 -- USP port):
#   v5e (CONFIG_LORA_BASICS_MODEM_DRIVERS=y):
#       RadioInstances.fppi   -> RadioInstances_Usp.fppi   (Zephyr.UspRadio)
#       RadioTopology.fppi    -> RadioTopology_Usp.fppi
#       RadioPacketsRadio.fppi -> RadioPacketsRadio_Usp.fppi
#   ground_radio_controller / v5 (CONFIG_LORA_BASICS_MODEM_DRIVERS not set):
#       RadioInstances.fppi   -> RadioInstances_Lora.fppi  (Zephyr.LoRa)
#       RadioTopology.fppi    -> RadioTopology_Lora.fppi
#       RadioPacketsRadio.fppi -> RadioPacketsRadio_Lora.fppi
#
# FPP `include` directives resolve relative to the source file, so we
# create symbolic links in the source tree at configure time. The links
# are gitignored so they do not appear as untracked files.
#
# More information in the F´ CMake API documentation:
# https://fprime.jpl.nasa.gov/latest/docs/reference/api/cmake/API/
#
####

if(DEFINED CONFIG_LORA_BASICS_MODEM_DRIVERS)
    set(RADIO_SUFFIX "Usp")
else()
    set(RADIO_SUFFIX "Lora")
endif()

# Generate per-board .fppi symlinks in the source dir. CREATE_LINK SYMBOLIC
# COPY_ON_ERROR falls back to a file copy on platforms without symlinks.
foreach(_name "RadioInstances" "RadioTopology" "RadioPacketsRadio")
    set(_src "${CMAKE_CURRENT_LIST_DIR}/${_name}_${RADIO_SUFFIX}.fppi")
    set(_dst "${CMAKE_CURRENT_LIST_DIR}/${_name}.fppi")
    file(CREATE_LINK "${_src}" "${_dst}" SYMBOLIC COPY_ON_ERROR)
endforeach()

register_fprime_module(
    AUTOCODER_INPUTS
        "${CMAKE_CURRENT_LIST_DIR}/instances.fpp"
        "${CMAKE_CURRENT_LIST_DIR}/topology.fpp"
    SOURCES
        "${CMAKE_CURRENT_LIST_DIR}/ReferenceDeploymentTopology.cpp"
    DEPENDS
        Fw_Logger
)
