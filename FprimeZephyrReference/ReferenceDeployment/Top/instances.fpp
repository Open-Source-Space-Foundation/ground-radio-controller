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
  }

  # ----------------------------------------------------------------------
  # Active component instances
  # ----------------------------------------------------------------------

  instance rateGroup10Hz: Svc.ActiveRateGroup base id 0x10001000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 3

  instance rateGroup1Hz: Svc.ActiveRateGroup base id 0x10002000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 4


  # ----------------------------------------------------------------------
  # Queued component instances
  # ----------------------------------------------------------------------


  # ----------------------------------------------------------------------
  # Passive component instances
  # ----------------------------------------------------------------------

  instance chronoTime: Zephyr.ZephyrTime base id 0x10010000

  instance rateGroupDriver: Svc.RateGroupDriver base id 0x10011000

  instance timer: Zephyr.ZephyrRateDriver base id 0x10013000

  instance controlComDriver: Zephyr.ZephyrUartDriver base id 0x10014000

  instance dataComDriver: Zephyr.ZephyrUartDriver base id 0x10015000

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

}
