module ReferenceDeployment {

  # ----------------------------------------------------------------------
  # Symbolic constants for port numbers
  # ----------------------------------------------------------------------

  enum Ports_RateGroups {
    rateGroup10Hz
    rateGroup1Hz
  }

  topology ReferenceDeployment {

  # ----------------------------------------------------------------------
  # Subtopology imports
  # ----------------------------------------------------------------------
    import CdhCore.Subtopology
    import ComCcsds.Subtopology

  # ----------------------------------------------------------------------
  # Instances used in the topology
  # ----------------------------------------------------------------------
    instance chronoTime
    instance rateGroup10Hz
    instance rateGroup1Hz
    instance rateGroupDriver
    instance timer
    instance controlComDriver
    instance dataComDriver
    instance dataBufferManager
    instance uhf
    instance dataComStub
    instance prmDb

  # ----------------------------------------------------------------------
  # Pattern graph specifiers
  # ----------------------------------------------------------------------

    command connections instance CdhCore.cmdDisp
    param connections instance prmDb
    event connections instance CdhCore.events
    text event connections instance CdhCore.textLogger
    health connections instance CdhCore.$health
    time connections instance chronoTime
    telemetry connections instance CdhCore.tlmSend

  # ----------------------------------------------------------------------
  # Telemetry packets (only used when TlmPacketizer is used)
  # ----------------------------------------------------------------------

  include "ReferenceDeploymentPackets.fppi"

  # ----------------------------------------------------------------------
  # Direct graph specifiers
  # ----------------------------------------------------------------------

    connections ComCcsds_CdhCore {
      # Core events and telemetry to communication queue
      CdhCore.events.PktSend -> ComCcsds.comQueue.comPacketQueueIn[ComCcsds.Ports_ComPacketQueue.EVENTS]
      CdhCore.tlmSend.PktSend -> ComCcsds.comQueue.comPacketQueueIn[ComCcsds.Ports_ComPacketQueue.TELEMETRY]

      # Router to Command Dispatcher
      ComCcsds.fprimeRouter.commandOut -> CdhCore.cmdDisp.seqCmdBuff
      CdhCore.cmdDisp.seqCmdStatus -> ComCcsds.fprimeRouter.cmdResponseIn

    }

    connections Communications {
      # ComDriver buffer allocations
      controlComDriver.allocate      -> ComCcsds.commsBufferManager.bufferGetCallee
      controlComDriver.deallocate    -> ComCcsds.commsBufferManager.bufferSendIn

      # ComDriver <-> ComStub (Uplink)
      controlComDriver.$recv                     -> ComCcsds.comStub.drvReceiveIn
      ComCcsds.comStub.drvReceiveReturnOut -> controlComDriver.recvReturnIn

      # ComStub <-> ComDriver (Downlink)
      ComCcsds.comStub.drvSendOut      -> controlComDriver.$send
      controlComDriver.ready         -> ComCcsds.comStub.drvConnected
    }

    connections DataCommunications {
      # dataComDriver buffer allocations
      dataComDriver.allocate      -> dataBufferManager.bufferGetCallee
      dataComDriver.deallocate    -> dataBufferManager.bufferSendIn

      # dataComDriver <-> dataComStub (Uplink)
      dataComDriver.$recv                     -> dataComStub.drvReceiveIn
      dataComStub.drvReceiveReturnOut -> dataComDriver.recvReturnIn

      # dataComStub <-> dataComDriver (Downlink)
      dataComStub.drvSendOut      -> dataComDriver.$send
      dataComDriver.ready         -> dataComStub.drvConnected

      # dataComStub <-> uhf (Uplink)
      dataComStub.dataOut         -> uhf.dataIn
      uhf.dataReturnOut           -> dataComStub.dataReturnIn

      # uhf <-> dataComStub (Downlink)
      uhf.dataOut                 -> dataComStub.dataIn
      dataComStub.dataReturnOut   -> uhf.dataReturnIn

      # uhf buffer allocations
      uhf.allocate                -> dataBufferManager.bufferGetCallee
      uhf.deallocate              -> dataBufferManager.bufferSendIn
    }

    connections RateGroups {
      # timer to drive rate group
      timer.CycleOut -> rateGroupDriver.CycleIn

      # High rate (10Hz) rate group
      rateGroupDriver.CycleOut[Ports_RateGroups.rateGroup10Hz] -> rateGroup10Hz.CycleIn
      rateGroup10Hz.RateGroupMemberOut[0] -> controlComDriver.schedIn
      rateGroup10Hz.RateGroupMemberOut[1] -> dataComDriver.schedIn

      # Slow rate (1Hz) rate group
      rateGroupDriver.CycleOut[Ports_RateGroups.rateGroup1Hz] -> rateGroup1Hz.CycleIn
      rateGroup1Hz.RateGroupMemberOut[0] -> ComCcsds.comQueue.run
      rateGroup1Hz.RateGroupMemberOut[1] -> CdhCore.$health.Run
      rateGroup1Hz.RateGroupMemberOut[2] -> ComCcsds.commsBufferManager.schedIn
      rateGroup1Hz.RateGroupMemberOut[3] -> CdhCore.tlmSend.Run
      rateGroup1Hz.RateGroupMemberOut[4] -> ComCcsds.aggregator.timeout
      rateGroup1Hz.RateGroupMemberOut[5] -> dataBufferManager.schedIn
    }

    connections ReferenceDeployment {

    }

  }

}
