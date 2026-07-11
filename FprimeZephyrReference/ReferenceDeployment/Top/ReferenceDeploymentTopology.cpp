// ======================================================================
// \title  ReferenceDeploymentTopology.cpp
// \brief cpp file containing the topology instantiation code
//
// ======================================================================
// Provides access to autocoded functions
#include <FprimeZephyrReference/ReferenceDeployment/Top/ReferenceDeploymentTopologyAc.hpp>
// Note: Uncomment when using Svc:TlmPacketizer
// #include <FprimeZephyrReference/ReferenceDeployment/Top/ReferenceDeploymentPacketsAc.hpp>

// Necessary project-specified types
#include <Fw/Types/MallocAllocator.hpp>
#include <Fw/Logger/Logger.hpp>

// Phase 6 (USP port): per-board radio startup.
//   v5e (CONFIG_LORA_BASICS_MODEM_DRIVERS=y): Zephyr::UspRadio + RalSessionImpl
//   ground_radio_controller / v5 (legacy):    Zephyr::LoRa (uhf.start(), below)
#ifdef CONFIG_LORA_BASICS_MODEM_DRIVERS
#include "fprime-zephyr/Drv/UspRadio/RalSessionImpl.hpp"
#include "fprime-zephyr/Drv/UspRadio/UspRadio.hpp"

// Static RalSessionImpl instance (lives for the entire run).
//
// Frequency/TX power are runtime constructor args to RalSessionImpl -- they
// no longer come from LoRaCfg.hpp once uhf becomes UspRadio (LoRaCfg.hpp
// requires CONFIG_LORA=y, which is absent on the v5e-USP target; see
// RalSessionImpl.cpp's own "NOTE: LoRaCfg.hpp is intentionally NOT included
// here" comment). Hardcoded here to match GRC's own COMMITTED LoRaCfg.hpp
// convention (project/config/LoRaCfg.hpp: DEFAULT_FREQ, TX_POWER) rather
// than proves-core-reference's local bench override (437.4 MHz / +10 dBm) --
// per Phase 6 scope doc: those flight values are a deliberate local
// bench-safety cap, not the shared convention.
//
// TODO: LoRaConfig::TX_POWER (23 dBm) exceeds the SX1262 driver's advertised
// +22 dBm max -- a pre-existing bug independent of this port (see
// grc-v5e-board-port memory: "stock TX_POWER=23 exceeds +22dBm max"). Revisit
// before flying v5e at full power; the bench working tree already carries an
// uncommitted 13 dBm override for link-margin testing (see LoRaCfg.hpp diff,
// deliberately not carried into this port -- bench-only, stays uncommitted).
static Zephyr::RalSessionImpl s_ralSession(
    437400000U,  // 437.4 MHz (matches GRC's committed LoRaConfig::DEFAULT_FREQ)
    23           // +23 dBm (matches GRC's committed LoRaConfig::TX_POWER; see TODO above)
);
#endif  // CONFIG_LORA_BASICS_MODEM_DRIVERS

// Allows easy reference to objects in FPP/autocoder required namespaces
using namespace ReferenceDeployment;

// Instantiate a malloc allocator for cmdSeq buffer allocation
Fw::MallocAllocator mallocator;

constexpr FwSizeType BASE_RATEGROUP_PERIOD_MS = 1;  // 1Khz

// Helper function to calculate the period for a given rate group frequency
constexpr FwSizeType getRateGroupPeriod(const FwSizeType hz) {
    return 1000 / (hz * BASE_RATEGROUP_PERIOD_MS);
}

// The reference topology divides the incoming clock signal (1Hz) into sub-signals: 1Hz, 1/2Hz, and 1/4Hz with 0 offset
Svc::RateGroupDriver::DividerSet rateGroupDivisorsSet{{
    // Array of divider objects
    {getRateGroupPeriod(100), 0},  // 100Hz
    {getRateGroupPeriod(10), 0},   // 10Hz
    {getRateGroupPeriod(1), 0},    // 1Hz
}};

// Rate groups may supply a context token to each of the attached children whose purpose is set by the project. The
// reference topology sets each token to zero as these contexts are unused in this project.
U32 rateGroup100HzContext[Svc::ActiveRateGroup::CONNECTION_COUNT_MAX] = {getRateGroupPeriod(100)};
U32 rateGroup10HzContext[Svc::ActiveRateGroup::CONNECTION_COUNT_MAX] = {getRateGroupPeriod(10)};
U32 rateGroup1HzContext[Svc::ActiveRateGroup::CONNECTION_COUNT_MAX] = {getRateGroupPeriod(1)};

/**
 * \brief configure/setup components in project-specific way
 *
 * This is a *helper* function which configures/sets up each component requiring project specific input. This includes
 * allocating resources, passing-in arguments, etc. This function may be inlined into the topology setup function if
 * desired, but is extracted here for clarity.
 */
void configureTopology() {
    // Rate group driver needs a divisor list
    rateGroupDriver.configure(rateGroupDivisorsSet);
    // Rate groups require context arrays.
    rateGroup100Hz.configure(rateGroup100HzContext, FW_NUM_ARRAY_ELEMENTS(rateGroup100HzContext));
    rateGroup10Hz.configure(rateGroup10HzContext, FW_NUM_ARRAY_ELEMENTS(rateGroup10HzContext));
    rateGroup1Hz.configure(rateGroup1HzContext, FW_NUM_ARRAY_ELEMENTS(rateGroup1HzContext));
    // Allocate sequence buffer (5KB is sufficient for typical sequences)
    cmdSeq.allocateBuffer(0, mallocator, 5 * 1024);
    // Enable all TlmPacketizer groups and set default rates for the REALTIME section.
    // loadParameters() runs after configureTopology() and may override these if saved params exist.
    // Without this, groups remain SILENCED+DISABLED after a fresh flash (empty parameter DB).
    for (FwChanIdType grp = 0; grp < static_cast<FwChanIdType>(Svc::NUM_CONFIGURABLE_TLMPACKETIZER_GROUPS); grp++) {
        CdhCore::tlmSend.initGroupRate(
            Svc::TelemetrySection::REALTIME, grp, Svc::RateLogic::EVERY_MAX, 0, 10);
    }
}

// Public functions for use in main program are namespaced with deployment name ReferenceDeployment
namespace ReferenceDeployment {
void setupTopology(const TopologyState& state) {
    // Autocoded initialization. Function provided by autocoder.
    initComponents(state);
    // Autocoded id setup. Function provided by autocoder.
    setBaseIds();
    // Autocoded connection wiring. Function provided by autocoder.
    connectComponents();
    // Autocoded command registration. Function provided by autocoder.
    regCommands();
    // Autocoded configuration. Function provided by autocoder.
    configComponents(state);
    // Project-specific component configuration. Function provided above. May be inlined, if desired.
    configureTopology();
    // Autocoded parameter loading. Function provided by autocoder.
    loadParameters();
    // Autocoded task kick-off (active components). Function provided by autocoder.
    startTasks(state);

    // Uplink is configured for receive so a socket task is started
    controlUartDriver.configure(state.controlUartDevice, state.controlUartBaudRate);

    dataUartDriver.configure(state.dataUartDevice, state.dataUartBaudRate);

    // Radio startup: per-board selection (Phase 6 USP port). Both paths start
    // with TX ENABLED, matching this topology's existing (no startup-sequence
    // gating) convention.
#ifdef CONFIG_LORA_BASICS_MODEM_DRIVERS
    uspRadio.configure(s_ralSession);
    if (!uspRadio.startRadio(Zephyr::UspTransmitState::ENABLED)) {
        Fw::Logger::log("[Topology] UspRadio startRadio() failed -- radio inactive\n");
    }
#else
    uhf.start(state.loraDevice, Zephyr::TransmitState::ENABLED);
#endif
}

void startRateGroups() {
    timer.configure(BASE_RATEGROUP_PERIOD_MS);
    timer.start();
    while (1) {
        timer.cycle();
    }
}

void stopRateGroups() {
    timer.stop();
}

void teardownTopology(const TopologyState& state) {
    // Autocoded (active component) task clean-up. Functions provided by topology autocoder.
    stopTasks(state);
    freeThreads(state);
    cmdSeq.deallocateBuffer(mallocator);
    tearDownComponents(state);
}
};  // namespace ReferenceDeployment
