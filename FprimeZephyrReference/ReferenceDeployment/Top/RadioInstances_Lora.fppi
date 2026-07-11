# Radio instance declarations for the legacy Zephyr::LoRa path
# (ground_radio_controller, proves_flight_control_board_v5 -- both SX1276).
# Included by instances.fpp inside module ReferenceDeployment { }.
# Selected by CMakeLists.txt when CONFIG_LORA_BASICS_MODEM_DRIVERS is not set.

  instance uhf: Zephyr.LoRa base id 0x10017000
