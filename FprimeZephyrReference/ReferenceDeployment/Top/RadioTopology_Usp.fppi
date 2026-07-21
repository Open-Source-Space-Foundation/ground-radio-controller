# Radio topology connections for v5e (Semtech USP path).
# Included by topology.fpp inside topology ReferenceDeployment { }.
# Selected by CMakeLists.txt when CONFIG_LORA_BASICS_MODEM_DRIVERS is set.
#
# Same wiring as RadioTopology_Lora.fppi (see UspRadio.fpp: "External surface
# is identical to Zephyr::LoRa so the topology layer is board-agnostic") --
# only the instance name changes, plus one new wire: UspRadio is active and
# needs a run port for its revert-deadline tick + periodic telemetry flush.

    instance uspRadio

    connections RadioUHF {
      uspRadio.allocate              -> dataBufferManager.bufferGetCallee
      uspRadio.deallocate            -> dataBufferManager.bufferSendIn

      # Queued TC frames -> radio uplink
      uplinkComQueue.dataOut         -> uspRadio.dataIn
      uspRadio.dataReturnOut         -> uplinkComQueue.dataReturnIn
      uspRadio.comStatusOut          -> uplinkComQueue.comStatusIn

      # Radio downlink -> queued UART byte stream
      uspRadio.dataOut                        -> downlinkPassThrough.dataIn
      downlinkPassThrough.allPacketsOut       -> downlinkComQueue.bufferQueueIn[0]
      downlinkComQueue.bufferReturnOut[0]     -> downlinkPassThrough.allPacketsReturnIn
      downlinkPassThrough.dataReturnOut       -> uspRadio.dataReturnIn
    }

    connections RadioRateGroup {
      # UspRadio run port: revert-deadline tick + telemetry flush at 1 Hz.
      # Slot 8 is the first free slot after this topology's highest used (7,
      # downlinkComQueue.run).
      rateGroup1Hz.RateGroupMemberOut[8] -> uspRadio.run
    }
