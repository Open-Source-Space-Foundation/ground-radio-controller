# Radio topology connections for v5e (Semtech USP path).
# Included by topology.fpp inside topology ReferenceDeployment { }.
# Selected by CMakeLists.txt when CONFIG_LORA_BASICS_MODEM_DRIVERS is set.
#
# Same Svc.Com/Svc.BufferAllocation wiring as the legacy uhf instance (see
# UspRadio.fpp: "External surface is identical to Zephyr::LoRa so the
# topology layer is board-agnostic") -- only the instance name changes,
# plus one new wire: UspRadio is active and needs a run port for its
# revert-deadline tick + periodic telemetry flush.

    instance uspRadio

    connections RadioUHF {
      uspRadio.allocate                   -> dataBufferManager.bufferGetCallee
      uspRadio.deallocate                 -> dataBufferManager.bufferSendIn
      uspRadio.dataOut                    -> byteComBridge.comDataIn
      uspRadio.comStatusOut               -> byteComBridge.comStatusIn
      uspRadio.dataReturnOut              -> byteComBridge.comDataReturnIn
      byteComBridge.comDataOut            -> uspRadio.dataIn
      byteComBridge.comDataReturnOut      -> uspRadio.dataReturnIn
    }

    connections RadioRateGroup {
      # UspRadio run port: revert-deadline tick + telemetry flush at 1 Hz.
      # Slot 7 is the first free slot after this topology's highest used (6).
      rateGroup1Hz.RateGroupMemberOut[7] -> uspRadio.run
    }
