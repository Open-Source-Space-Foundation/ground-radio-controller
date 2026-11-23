// ======================================================================
// \title  BootloaderTrigger.hpp
// \brief  hpp file for BootloaderTrigger component implementation class
// ======================================================================

#ifndef BootloaderTrigger_HPP
#define BootloaderTrigger_HPP

#include "FprimeZephyrReference/Components/BootloaderTrigger/BootloaderTriggerComponentAc.hpp"

namespace Components {

class BootloaderTrigger final : public BootloaderTriggerComponentBase {
  public:
    explicit BootloaderTrigger(const char* const compName);

    ~BootloaderTrigger();

  private:
    static constexpr I64 NOT_ARMED = -1;

    //! Last 4 bytes of the hardware ID behind the USB serial number, or 0 if unknown
    static U32 bootloaderKey();

    //! Reject a bootloader command whose key is wrong, and disarm
    bool checkKey(FwOpcodeType opCode, U32 cmdSeq, U32 key);

    void ARM_BOOTLOADER_cmdHandler(FwOpcodeType opCode, U32 cmdSeq, U32 key) override;

    void TRIGGER_BOOTLOADER_cmdHandler(FwOpcodeType opCode, U32 cmdSeq, U32 key) override;

    //! Uptime of the last valid ARM_BOOTLOADER, or NOT_ARMED
    I64 m_armedAtMs = NOT_ARMED;
};

}  // namespace Components

#endif
