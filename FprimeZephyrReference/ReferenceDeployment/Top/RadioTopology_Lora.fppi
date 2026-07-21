# Radio topology connections for the legacy Zephyr::LoRa path
# (ground_radio_controller, proves_flight_control_board_v5 -- both SX1276).
# Included by topology.fpp inside topology ReferenceDeployment { }.
# Selected by CMakeLists.txt when CONFIG_LORA_BASICS_MODEM_DRIVERS is not set.
#
# Wiring matches main's CCSDS uplink/downlink path (uplinkComQueue feeds the
# radio; radio downlink goes through downlinkPassThrough/downlinkComQueue back
# to the data UART) -- only the radio instance name is per-board.

    instance uhf

    connections RadioUHF {
      uhf.allocate                   -> dataBufferManager.bufferGetCallee
      uhf.deallocate                 -> dataBufferManager.bufferSendIn

      # Queued TC frames -> radio uplink
      uplinkComQueue.dataOut         -> uhf.dataIn
      uhf.dataReturnOut              -> uplinkComQueue.dataReturnIn
      uhf.comStatusOut               -> uplinkComQueue.comStatusIn

      # Radio downlink -> queued UART byte stream
      uhf.dataOut                             -> downlinkPassThrough.dataIn
      downlinkPassThrough.allPacketsOut       -> downlinkComQueue.bufferQueueIn[0]
      downlinkComQueue.bufferReturnOut[0]     -> downlinkPassThrough.allPacketsReturnIn
      downlinkPassThrough.dataReturnOut       -> uhf.dataReturnIn
    }
