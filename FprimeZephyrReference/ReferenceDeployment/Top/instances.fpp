module ReferenceDeployment {

  # ----------------------------------------------------------------------
  # Base ID Convention
  # ----------------------------------------------------------------------
  #
  # All Base IDs follow the 8-digit hex format: 0xDSSCCxxx
  #
  # Where:
  #   D   = Deployment digit (1 for this deployment)
  #   SS  = Subtopology digits (00 for main topology, 01-05 for subtopologies)
  #   CC  = Component digits (00, 01, 02, etc.)
  #   xxx = Reserved for internal component items (events, commands, telemetry)
  #

  # ----------------------------------------------------------------------
  # Defaults
  # ----------------------------------------------------------------------

  module Default {
    constant QUEUE_SIZE = 10
    constant STACK_SIZE = 8 * 1024 # Must match prj.conf thread stack size
    constant MAX_LORA_DATA_FRAME_SIZE = 248
  }

  # ----------------------------------------------------------------------
  # Active component instances
  # ----------------------------------------------------------------------

  instance rateGroup100Hz: Svc.ActiveRateGroup base id 0x10001000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 3

  instance rateGroup1Hz: Svc.ActiveRateGroup base id 0x10003000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 4

  instance uplinkComQueue: Svc.ComQueue base id 0x10004000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 5 \
    {
        phase Fpp.ToCpp.Phases.configObjects """
        Svc::ComQueue::QueueConfigurationTable configurationTable;
        Fw::MallocAllocator mallocatorInstance;
        """

        phase Fpp.ToCpp.Phases.configComponents """
        ConfigObjects::ReferenceDeployment_uplinkComQueue::configurationTable.entries[0].depth = 1;
        ConfigObjects::ReferenceDeployment_uplinkComQueue::configurationTable.entries[0].priority = 0;
        ConfigObjects::ReferenceDeployment_uplinkComQueue::configurationTable.entries[1].depth = 1;
        ConfigObjects::ReferenceDeployment_uplinkComQueue::configurationTable.entries[1].priority = 1;
        ConfigObjects::ReferenceDeployment_uplinkComQueue::configurationTable.entries[2].depth = 2;
        ConfigObjects::ReferenceDeployment_uplinkComQueue::configurationTable.entries[2].priority = 2;
        ReferenceDeployment::uplinkComQueue.configure(
            ConfigObjects::ReferenceDeployment_uplinkComQueue::configurationTable,
            0,
            ConfigObjects::ReferenceDeployment_uplinkComQueue::mallocatorInstance
        );
        """

        phase Fpp.ToCpp.Phases.tearDownComponents """
        ReferenceDeployment::uplinkComQueue.cleanup();
        """
    }

  instance downlinkComQueue: Svc.ComQueue base id 0x10005000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 5 \
    {
        phase Fpp.ToCpp.Phases.configObjects """
        Svc::ComQueue::QueueConfigurationTable configurationTable;
        Fw::MallocAllocator mallocatorInstance;
        """

        phase Fpp.ToCpp.Phases.configComponents """
        ConfigObjects::ReferenceDeployment_downlinkComQueue::configurationTable.entries[0].depth = 1;
        ConfigObjects::ReferenceDeployment_downlinkComQueue::configurationTable.entries[0].priority = 0;
        ConfigObjects::ReferenceDeployment_downlinkComQueue::configurationTable.entries[1].depth = 1;
        ConfigObjects::ReferenceDeployment_downlinkComQueue::configurationTable.entries[1].priority = 1;
        ConfigObjects::ReferenceDeployment_downlinkComQueue::configurationTable.entries[2].depth = 2;
        ConfigObjects::ReferenceDeployment_downlinkComQueue::configurationTable.entries[2].priority = 2;
        ReferenceDeployment::downlinkComQueue.configure(
            ConfigObjects::ReferenceDeployment_downlinkComQueue::configurationTable,
            1,
            ConfigObjects::ReferenceDeployment_downlinkComQueue::mallocatorInstance
        );
        """

        phase Fpp.ToCpp.Phases.tearDownComponents """
        ReferenceDeployment::downlinkComQueue.cleanup();
        """
    }


  # ----------------------------------------------------------------------
  # Queued component instances
  # ----------------------------------------------------------------------


  # ----------------------------------------------------------------------
  # Passive component instances
  # ----------------------------------------------------------------------

  instance chronoTime: Zephyr.ZephyrTime base id 0x10010000

  instance rateGroupDriver: Svc.RateGroupDriver base id 0x10011000

  instance timer: Zephyr.ZephyrRateDriver base id 0x10013000

  instance controlUartDriver: Zephyr.ZephyrUartDriver base id 0x10014000

  instance dataUartDriver: Zephyr.ZephyrUartDriver base id 0x10015000

  instance dataBufferManager: Svc.BufferManager base id 0x10016000 \
    {
        phase Fpp.ToCpp.Phases.configObjects """
        Svc::BufferManager::BufferBins bins;
        Fw::MallocAllocator mallocatorInstance;
        """

        phase Fpp.ToCpp.Phases.configComponents """
        memset(&ConfigObjects::ReferenceDeployment_dataBufferManager::bins, 0, sizeof(ConfigObjects::ReferenceDeployment_dataBufferManager::bins));
        ConfigObjects::ReferenceDeployment_dataBufferManager::bins.bins[0].bufferSize = 256;
        ConfigObjects::ReferenceDeployment_dataBufferManager::bins.bins[0].numBuffers = 8;
        ReferenceDeployment::dataBufferManager.setup(
            87, // randomly chosen mgr ID
            0,
            ConfigObjects::ReferenceDeployment_dataBufferManager::mallocatorInstance,
            ConfigObjects::ReferenceDeployment_dataBufferManager::bins
        );
        """

        phase Fpp.ToCpp.Phases.tearDownComponents """
        ReferenceDeployment::dataBufferManager.cleanup();
        """
    }

  instance dataFrameBufferManager: Svc.BufferManager base id 0x10016500 \
    {
        phase Fpp.ToCpp.Phases.configObjects """
        Svc::BufferManager::BufferBins bins;
        Fw::MallocAllocator mallocatorInstance;
        """

        phase Fpp.ToCpp.Phases.configComponents """
        memset(&ConfigObjects::ReferenceDeployment_dataFrameBufferManager::bins, 0, sizeof(ConfigObjects::ReferenceDeployment_dataFrameBufferManager::bins));
        ConfigObjects::ReferenceDeployment_dataFrameBufferManager::bins.bins[0].bufferSize = ReferenceDeployment::Default::MAX_LORA_DATA_FRAME_SIZE;
        ConfigObjects::ReferenceDeployment_dataFrameBufferManager::bins.bins[0].numBuffers = 1;
        ReferenceDeployment::dataFrameBufferManager.setup(
            88, // randomly chosen mgr ID
            0,
            ConfigObjects::ReferenceDeployment_dataFrameBufferManager::mallocatorInstance,
            ConfigObjects::ReferenceDeployment_dataFrameBufferManager::bins
        );
        """

        phase Fpp.ToCpp.Phases.tearDownComponents """
        ReferenceDeployment::dataFrameBufferManager.cleanup();
        """
    }

  instance uhf: Zephyr.LoRa base id 0x10017000

  instance prmDb: Svc.PrmDb base id 0x10018000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 5

  instance dataComStub: Svc.ComStub base id 0x10019000

  instance dataFrameAccumulator: Svc.FrameAccumulator base id 0x1001A000 \
    {
        phase Fpp.ToCpp.Phases.configObjects """
        Svc::FrameDetectors::CcsdsTcFrameDetector frameDetector;
        Fw::MallocAllocator mallocatorInstance;
        """

        phase Fpp.ToCpp.Phases.configComponents """
        ConfigObjects::ReferenceDeployment_dataFrameAccumulator::frameDetector.configure(
            0,
            true
        );
        ReferenceDeployment::dataFrameAccumulator.configure(
            ConfigObjects::ReferenceDeployment_dataFrameAccumulator::frameDetector,
            2,
            ConfigObjects::ReferenceDeployment_dataFrameAccumulator::mallocatorInstance,
            ReferenceDeployment::Default::MAX_LORA_DATA_FRAME_SIZE
        );
        """

        phase Fpp.ToCpp.Phases.tearDownComponents """
        ReferenceDeployment::dataFrameAccumulator.cleanup();
        """
    }

  instance uplinkPassThrough: Svc.PassThroughRouter base id 0x1001B000

  instance downlinkPassThrough: Svc.PassThroughRouter base id 0x1001C000

}
