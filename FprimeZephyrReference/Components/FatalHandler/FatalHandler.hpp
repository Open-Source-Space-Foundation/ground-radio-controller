// ======================================================================
// \title  FatalHandlerImpl.hpp
// \author mstarch
// \brief  hpp file for FatalHandler component implementation class
//
// \copyright
// Copyright 2009-2015, by the California Institute of Technology.
// ALL RIGHTS RESERVED.  United States Government Sponsorship
// acknowledged.
//
// ======================================================================

#ifndef FatalHandler_HPP
#define FatalHandler_HPP

#include "FprimeZephyrReference/Components/FatalHandler/FatalHandlerComponentAc.hpp"

namespace Components {

class FatalHandler final : public FatalHandlerComponentBase {
  public:
    // ----------------------------------------------------------------------
    // Construction, initialization, and destruction
    // ----------------------------------------------------------------------

    //! Construct object FatalHandler
    //!
    FatalHandler(const char* const compName /*!< The component name*/
    );

    //! Destroy object FatalHandler
    //!
    ~FatalHandler();

    //! Reboot the device
    //!
    void reboot();

  private:
    static constexpr I64 NOT_ARMED = -1;

    //! Reject a bootloader command whose key is wrong, and disarm
    bool checkBootloaderKey(FwOpcodeType opCode, U32 cmdSeq, U32 key);

    //! Uptime of the last valid ARM_BOOTLOADER, or NOT_ARMED
    I64 m_bootloaderArmedAtMs = NOT_ARMED;

  private:
    // ----------------------------------------------------------------------
    // Handler implementations for user-defined typed input ports
    // ----------------------------------------------------------------------

    //! Handler implementation for FatalReceive
    //!
    void FatalReceive_handler(const FwIndexType portNum, /*!< The port number*/
                              FwEventIdType Id           /*!< The ID of the FATAL event*/
    );

  private:
    // ----------------------------------------------------------------------
    // Handler implementations for commands
    // ----------------------------------------------------------------------

    //! Handler implementation for command RESTART
    //!
    //! Issue a FSW reset
    void RESTART_cmdHandler(FwOpcodeType opCode,  //!< The opcode
                            U32 cmdSeq            //!< The command sequence number
                            ) override;

    //! Handler implementation for command ARM_BOOTLOADER
    void ARM_BOOTLOADER_cmdHandler(FwOpcodeType opCode, U32 cmdSeq, U32 key) override;

    //! Handler implementation for command ENTER_BOOTLOADER
    void ENTER_BOOTLOADER_cmdHandler(FwOpcodeType opCode, U32 cmdSeq, U32 key) override;
};

}  // namespace Components

#endif
