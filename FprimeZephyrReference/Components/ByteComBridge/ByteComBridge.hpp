// ======================================================================
// \title  ByteComBridge.hpp
// \author jrpear
// \brief  hpp file for ByteComBridge component implementation class
// ======================================================================

#ifndef Components_ByteComBridge_HPP
#define Components_ByteComBridge_HPP

#include "FprimeZephyrReference/Components/ByteComBridge/ByteComBridgeComponentAc.hpp"
#include <Utils/Types/CircularBuffer.hpp>

namespace Components {

class ByteComBridge final : public ByteComBridgeComponentBase {
  public:
    static constexpr FwSizeType COM_TX_FRAME_SIZE = 252;
    static constexpr FwSizeType CIRCULAR_BUFFER_SIZE = 252;

    // ----------------------------------------------------------------------
    // Component construction and destruction
    // ----------------------------------------------------------------------

    //! Construct ByteComBridge object
    ByteComBridge(const char* const compName  //!< The component name
    );

    //! Destroy ByteComBridge object
    ~ByteComBridge();

  private:
    bool m_byteStreamDriverReady;
    bool m_comTxReady;
    std::atomic<bool> m_trySendQueuedDataPending;
    U8 m_txCircularBufferStorage[CIRCULAR_BUFFER_SIZE];
    Types::CircularBuffer m_txCircularBuffer;
    U8 m_comFrameStorage[COM_TX_FRAME_SIZE];

  private:
    void enqueueByteStreamData(const Fw::Buffer& buffer);
    void requestSendQueuedData();

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
    void comStatusIn_handler(FwIndexType portNum,  //!< The port number
                             Fw::Success& status   //!< Condition success/failure
                             ) override;

    //! Handler implementation for trySendQueuedData
    //!
    //! Internal async handler for processing received data
    void trySendQueuedData_internalInterfaceHandler() override;
};

}  // namespace Components

#endif
