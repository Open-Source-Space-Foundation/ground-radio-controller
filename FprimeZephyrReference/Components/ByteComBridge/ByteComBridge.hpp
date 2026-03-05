// ======================================================================
// \title  ByteComBridge.hpp
// \author jrpear
// \brief  hpp file for ByteComBridge component implementation class
// ======================================================================

#ifndef Components_ByteComBridge_HPP
#define Components_ByteComBridge_HPP

#include "FprimeZephyrReference/Components/ByteComBridge/ByteComBridgeComponentAc.hpp"

namespace Components {

class ByteComBridge final : public ByteComBridgeComponentBase {
  public:
    // ----------------------------------------------------------------------
    // Component construction and destruction
    // ----------------------------------------------------------------------

    //! Construct ByteComBridge object
    ByteComBridge(const char* const compName  //!< The component name
    );

    //! Destroy ByteComBridge object
    ~ByteComBridge();

  private:
    // ----------------------------------------------------------------------
    // Handler implementations for typed input ports
    // ----------------------------------------------------------------------

    //! Handler implementation for byteStreamReady
    void byteStreamReady_handler(FwIndexType portNum  //!< The port number
                                 ) override;

    //! Handler implementation for byteStreamRecv
    void byteStreamRecv_handler(FwIndexType portNum,  //!< The port number
                                Fw::Buffer& buffer,
                                const Drv::ByteStreamStatus& status) override;

    //! Handler implementation for comDataIn
    void comDataIn_handler(FwIndexType portNum,  //!< The port number
                           Fw::Buffer& data,
                           const ComCfg::FrameContext& context) override;

    //! Handler implementation for comDataReturnIn
    //!
    //! Port receiving back ownership of buffer sent out on comDataOut
    void comDataReturnIn_handler(FwIndexType portNum,  //!< The port number
                                 Fw::Buffer& data,
                                 const ComCfg::FrameContext& context) override;

    //! Handler implementation for comStatusIn
    void comStatusIn_handler(FwIndexType portNum,    //!< The port number
                             Fw::Success& condition  //!< Condition success/failure
                             ) override;

    //! Handler implementation for recvReturnIn
    //!
    //! Port to send back ownership of data received out on byteStreamRecv port
    void recvReturnIn_handler(FwIndexType portNum,  //!< The port number
                              Fw::Buffer& fwBuffer  //!< The buffer
                              ) override;
};

}  // namespace Components

#endif
