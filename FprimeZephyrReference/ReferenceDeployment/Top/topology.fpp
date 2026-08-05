module ReferenceDeployment {

  # ----------------------------------------------------------------------
  # Symbolic constants for port numbers
  # ----------------------------------------------------------------------

  enum Ports_RateGroups {
    rateGroup100Hz
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
    instance rateGroup100Hz
    instance rateGroup1Hz
    instance rateGroupDriver
    instance timer
    instance controlUartDriver
    instance dataUartDriver
    instance dataBufferManager
    instance dataFrameBufferManager
    # uhf / uspRadio instance declared via RadioTopology.fppi below
    # (per-board selection, Phase 6 USP port -- see instances.fpp).
    instance prmDb
    instance dataComStub
    instance dataFrameAccumulator
    instance uplinkPassThrough
    instance uplinkComQueue
    instance downlinkPassThrough
    instance downlinkComQueue

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
      controlUartDriver.allocate      -> ComCcsds.commsBufferManager.bufferGetCallee
      controlUartDriver.deallocate    -> ComCcsds.commsBufferManager.bufferSendIn

      # ComDriver <-> ComStub (Uplink)
      controlUartDriver.$recv                     -> ComCcsds.comStub.drvReceiveIn
      ComCcsds.comStub.drvReceiveReturnOut -> controlUartDriver.recvReturnIn

      # ComStub <-> ComDriver (Downlink)
      ComCcsds.comStub.drvSendOut      -> controlUartDriver.$send
      controlUartDriver.ready         -> ComCcsds.comStub.drvConnected
    }

    connections Data {
      # dataUartDriver connections
      dataUartDriver.allocate                -> dataBufferManager.bufferGetCallee
      dataUartDriver.deallocate              -> dataBufferManager.bufferSendIn
      dataUartDriver.$recv                   -> dataComStub.drvReceiveIn
      dataUartDriver.ready                   -> dataComStub.drvConnected
      dataComStub.drvReceiveReturnOut        -> dataUartDriver.recvReturnIn

      # UART byte stream -> complete CCSDS TC frames
      dataComStub.dataOut                    -> dataFrameAccumulator.dataIn
      dataFrameAccumulator.dataReturnOut     -> dataComStub.dataReturnIn
      dataFrameAccumulator.bufferAllocate    -> dataFrameBufferManager.bufferGetCallee
      dataFrameAccumulator.bufferDeallocate  -> dataFrameBufferManager.bufferSendIn

      # Complete TC frames -> queued LoRa uplink
      dataFrameAccumulator.dataOut           -> uplinkPassThrough.dataIn
      uplinkPassThrough.allPacketsOut        -> uplinkComQueue.bufferQueueIn[0]
      uplinkComQueue.bufferReturnOut[0]      -> uplinkPassThrough.allPacketsReturnIn
      uplinkPassThrough.dataReturnOut        -> dataFrameAccumulator.dataReturnIn

      downlinkComQueue.dataOut                -> dataComStub.dataIn
      dataComStub.dataReturnOut               -> downlinkComQueue.dataReturnIn
      dataComStub.comStatusOut                -> downlinkComQueue.comStatusIn
      dataComStub.drvSendOut                  -> dataUartDriver.$send

    }

    # Radio (uhf / uspRadio) instance + connections: per-board selection
    # (Phase 6 USP port). RadioTopology.fppi is a symlink to
    # RadioTopology_{Lora,Usp}.fppi, created by CMakeLists.txt at configure
    # time. The Usp variant also adds a RadioRateGroup connections block
    # (UspRadio is active and needs a run port; uhf/Zephyr.LoRa is passive
    # and does not).
    include "RadioTopology.fppi"

    connections RateGroups {
      # timer to drive rate group
      timer.CycleOut -> rateGroupDriver.CycleIn

      # High rate (100Hz) rate group
      rateGroupDriver.CycleOut[Ports_RateGroups.rateGroup100Hz] -> rateGroup100Hz.CycleIn
      rateGroup100Hz.RateGroupMemberOut[0] -> controlUartDriver.schedIn
      rateGroup100Hz.RateGroupMemberOut[1] -> dataUartDriver.schedIn

      # Slow rate (1Hz) rate group
      rateGroupDriver.CycleOut[Ports_RateGroups.rateGroup1Hz] -> rateGroup1Hz.CycleIn
      rateGroup1Hz.RateGroupMemberOut[0] -> ComCcsds.comQueue.run
      rateGroup1Hz.RateGroupMemberOut[1] -> CdhCore.$health.Run
      rateGroup1Hz.RateGroupMemberOut[2] -> ComCcsds.commsBufferManager.schedIn
      rateGroup1Hz.RateGroupMemberOut[3] -> CdhCore.tlmSend.Run
      rateGroup1Hz.RateGroupMemberOut[4] -> ComCcsds.aggregator.timeout
      rateGroup1Hz.RateGroupMemberOut[5] -> CdhCore.cmdDisp.run
      rateGroup1Hz.RateGroupMemberOut[6] -> uplinkComQueue.run
      rateGroup1Hz.RateGroupMemberOut[7] -> downlinkComQueue.run
    }

    connections ReferenceDeployment {

    }

  }

}
