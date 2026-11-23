// ======================================================================
// \title  BootloaderTrigger.cpp
// \brief  cpp file for BootloaderTrigger component implementation class
// ======================================================================

#include <FprimeZephyrReference/Components/BootloaderTrigger/BootloaderTrigger.hpp>
#include <FprimeZephyrReference/Components/BootloaderTrigger/FppConstantsAc.hpp>
#include <Os/Task.hpp>
#include <zephyr/drivers/hwinfo.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/byteorder.h>
#if defined(CONFIG_SOC_FAMILY_RPI_PICO)
#include <pico/bootrom.h>
#endif

namespace Components {

BootloaderTrigger ::BootloaderTrigger(const char* const compName) : BootloaderTriggerComponentBase(compName) {}

BootloaderTrigger ::~BootloaderTrigger() {}

U32 BootloaderTrigger ::bootloaderKey() {
    // The USB stack prints these same bytes in hex as the serial number, so the
    // key is the serial's last 8 hex digits.
    U8 id[CONFIG_USBD_HWINFO_DEVID_LENGTH] = {};
    const ssize_t len = hwinfo_get_device_id(id, sizeof(id));
    if (len < 4) {
        return 0;
    }
    return sys_get_be32(&id[len - 4]);
}

bool BootloaderTrigger ::checkKey(FwOpcodeType opCode, U32 cmdSeq, U32 key) {
    const U32 expected = bootloaderKey();
    if (expected != 0 && key == expected) {
        return true;
    }
    this->m_armedAtMs = NOT_ARMED;
    this->log_WARNING_LO_BootloaderKeyRejected(key, expected);
    this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::VALIDATION_ERROR);
    return false;
}

void BootloaderTrigger ::ARM_BOOTLOADER_cmdHandler(FwOpcodeType opCode, U32 cmdSeq, U32 key) {
    if (!this->checkKey(opCode, cmdSeq, key)) {
        return;
    }
    this->m_armedAtMs = k_uptime_get();
    this->log_ACTIVITY_HI_BootloaderArmed(BootloaderTrigger_BOOTLOADER_ARM_WINDOW_S);
    this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::OK);
}

void BootloaderTrigger ::TRIGGER_BOOTLOADER_cmdHandler(FwOpcodeType opCode, U32 cmdSeq, U32 key) {
    if (!this->checkKey(opCode, cmdSeq, key)) {
        return;
    }
    const I64 armedAtMs = this->m_armedAtMs;
    this->m_armedAtMs = NOT_ARMED;
    if (armedAtMs == NOT_ARMED || k_uptime_get() - armedAtMs > BootloaderTrigger_BOOTLOADER_ARM_WINDOW_S * 1000) {
        this->log_WARNING_LO_BootloaderNotArmed();
        this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::EXECUTION_ERROR);
        return;
    }
#if defined(CONFIG_SOC_FAMILY_RPI_PICO)
    this->log_ACTIVITY_HI_EnteringBootloader();
    Os::Task::delay(Fw::TimeInterval(0, 500000));  // Let the event pass the logger and the CDC TX delay
    // Watchdog reboot into the BOOTSEL USB drive and PICOBOOT; picotool flashes from there.
    reset_usb_boot(0, 0);
#else
    this->log_WARNING_LO_BootloaderUnsupported();
    this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::EXECUTION_ERROR);
#endif
}

}  // namespace Components
