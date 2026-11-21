// ======================================================================
// \title  FatalHandlerImpl.cpp
// \author mstarch
// \brief  cpp file for FatalHandler component implementation class
//
// \copyright
// Copyright 2009-2015, by the California Institute of Technology.
// ALL RIGHTS RESERVED.  United States Government Sponsorship
// acknowledged.
//
// ======================================================================

#include <Fw/Logger/Logger.hpp>
#include <FprimeZephyrReference/Components/FatalHandler/FatalHandler.hpp>
#include <FprimeZephyrReference/Components/FatalHandler/FppConstantsAc.hpp>
#include <Fw/FPrimeBasicTypes.hpp>
#include <zephyr/sys/reboot.h>
#include <zephyr/logging/log_ctrl.h>
#include <zephyr/kernel.h>
#include <zephyr/drivers/hwinfo.h>
#include <zephyr/sys/byteorder.h>
#if defined(CONFIG_SOC_FAMILY_RPI_PICO)
#include <pico/bootrom.h>
#endif

namespace Components {

// ----------------------------------------------------------------------
// Construction, initialization, and destruction
// ----------------------------------------------------------------------

FatalHandler ::FatalHandler(const char* const compName) : FatalHandlerComponentBase(compName) {}

FatalHandler ::~FatalHandler() {}

void FatalHandler::reboot() {
// When running in CI failsafe mode and the board is a teensy,
// then we should invoke bkpt #251 to trigger the soft reboot enabling a
// flash of new software
#if defined(FPRIME_CI_FAILSAFE_CYCLE_COUNT)
    // Magic bootloader breakpoint, provided by PRJC
    if (strncmp(CONFIG_BOARD, "teensy", 6) == 0) {
        asm("bkpt #251");
    }
#endif
    // Otherwise, use Zephyr to reboot the system
    sys_reboot(SYS_REBOOT_COLD);
}

void FatalHandler::FatalReceive_handler(const FwIndexType portNum, FwEventIdType Id) {
    Fw::Logger::log("FATAL %" PRI_FwEventIdType "handled.\n", Id);
    Os::Task::delay(Fw::TimeInterval(0, 100000));  // Delay to allow log to be processed
    LOG_PANIC();
    /*log_panic();*/
    /*log_flush();*/
    this->reboot();  // Reboot the system
}

// ----------------------------------------------------------------------
// Handler implementations for commands
// ----------------------------------------------------------------------

void FatalHandler ::RESTART_cmdHandler(FwOpcodeType opCode, U32 cmdSeq) {
    this->log_ACTIVITY_HI_Rebooting();
    Os::Task::delay(Fw::TimeInterval(0, 100000));  // Delay to allow event to go out
    this->reboot();
    this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::OK);
}

U32 FatalHandler ::bootloaderKey() {
    // The USB stack prints these same bytes in hex as the serial number, so the
    // key is the serial's last 8 hex digits.
    U8 id[CONFIG_USBD_HWINFO_DEVID_LENGTH] = {};
    const ssize_t len = hwinfo_get_device_id(id, sizeof(id));
    if (len < 4) {
        return 0;
    }
    return sys_get_be32(&id[len - 4]);
}

bool FatalHandler ::checkBootloaderKey(FwOpcodeType opCode, U32 cmdSeq, U32 key) {
    const U32 expected = bootloaderKey();
    if (expected != 0 && key == expected) {
        return true;
    }
    this->m_bootloaderArmedAtMs = NOT_ARMED;
    this->log_WARNING_LO_BootloaderKeyRejected(key, expected);
    this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::VALIDATION_ERROR);
    return false;
}

void FatalHandler ::ARM_BOOTLOADER_cmdHandler(FwOpcodeType opCode, U32 cmdSeq, U32 key) {
    if (!this->checkBootloaderKey(opCode, cmdSeq, key)) {
        return;
    }
    this->m_bootloaderArmedAtMs = k_uptime_get();
    this->log_ACTIVITY_HI_BootloaderArmed(FatalHandler_BOOTLOADER_ARM_WINDOW_S);
    this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::OK);
}

void FatalHandler ::ENTER_BOOTLOADER_cmdHandler(FwOpcodeType opCode, U32 cmdSeq, U32 key) {
    if (!this->checkBootloaderKey(opCode, cmdSeq, key)) {
        return;
    }
    const I64 armedAtMs = this->m_bootloaderArmedAtMs;
    this->m_bootloaderArmedAtMs = NOT_ARMED;
    if (armedAtMs == NOT_ARMED || k_uptime_get() - armedAtMs > FatalHandler_BOOTLOADER_ARM_WINDOW_S * 1000) {
        this->log_WARNING_LO_BootloaderNotArmed();
        this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::EXECUTION_ERROR);
        return;
    }
#if defined(CONFIG_SOC_FAMILY_RPI_PICO)
    this->log_ACTIVITY_HI_EnteringBootloader();
    Os::Task::delay(Fw::TimeInterval(0, 100000));  // Delay to allow event to go out
    // Watchdog reboot into the BOOTSEL USB drive and PICOBOOT; picotool flashes from there.
    reset_usb_boot(0, 0);
#else
    this->log_WARNING_LO_BootloaderUnsupported();
    this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::EXECUTION_ERROR);
#endif
}

}  // namespace Components
