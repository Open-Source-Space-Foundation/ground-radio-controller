# Radio topology connections for the legacy Zephyr::LoRa path
# (ground_radio_controller, proves_flight_control_board_v5 -- both SX1276).
# Included by topology.fpp inside topology ReferenceDeployment { }.
# Selected by CMakeLists.txt when CONFIG_LORA_BASICS_MODEM_DRIVERS is not set.
#
# Identical to the wiring this topology used before the Phase 6 USP port
# (uhf is passive, no ComRetry shim -- GRC's existing convention, unlike
# proves-core-reference's legacy path).

    instance uhf

    connections RadioUHF {
      uhf.allocate                   -> dataBufferManager.bufferGetCallee
      uhf.deallocate                 -> dataBufferManager.bufferSendIn
      uhf.dataOut                    -> byteComBridge.comDataIn
      uhf.comStatusOut               -> byteComBridge.comStatusIn
      uhf.dataReturnOut              -> byteComBridge.comDataReturnIn
      byteComBridge.comDataOut       -> uhf.dataIn
      byteComBridge.comDataReturnOut -> uhf.dataReturnIn
    }
