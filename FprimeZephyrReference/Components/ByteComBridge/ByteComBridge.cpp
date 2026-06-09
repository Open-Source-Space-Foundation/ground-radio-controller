// ======================================================================
// \title  ByteComBridge.cpp
// \author jrpear
// \brief  cpp file for ByteComBridge component implementation class
// ======================================================================

#include "FprimeZephyrReference/Components/ByteComBridge/ByteComBridge.hpp"
#include <Fw/Types/Assert.hpp>

namespace Components {

// ----------------------------------------------------------------------
// Component construction and destruction
// ----------------------------------------------------------------------

ByteComBridge ::ByteComBridge(const char* const compName)
    : ByteComBridgeComponentBase(compName),
      m_comTxReady(false),
      m_txCircularBufferStorage{},
      m_txCircularBuffer{},
      m_comFrameStorage{} {
    this->m_txCircularBuffer.setup(this->m_txCircularBufferStorage, CIRCULAR_BUFFER_SIZE);
}

ByteComBridge ::~ByteComBridge() {}

void ByteComBridge::enqueueByteStreamData(const Fw::Buffer& buffer) {
    const FwSizeType requested = buffer.getSize();
    const FwSizeType available = this->m_txCircularBuffer.get_free_size();
    if (requested > available) {
        this->log_WARNING_HI_ByteStreamBufferFull(requested, available);
        return;
    }

    const Fw::SerializeStatus status = this->m_txCircularBuffer.serialize(buffer.getData(), requested);
    FW_ASSERT(status == Fw::FW_SERIALIZE_OK, static_cast<FwAssertArgType>(status));
}

void ByteComBridge::requestSendQueuedData() {
    if (!this->m_trySendQueuedDataPending) {
        // Set bool first so you don't accidentally set it after the handler
        // has already run
        this->m_trySendQueuedDataPending = true;
        this->trySendQueuedData_internalInterfaceInvoke();
    }
}

void ByteComBridge::trySendQueuedData_internalInterfaceHandler() {
    this->m_trySendQueuedDataPending = false;
    // The F´ communication adapter interface requires dataReturnOut for a
    // transmitted buffer to happen before the corresponding comStatusOut; see
    // lib/fprime/docs/reference/communication-adapter-interface.md. So we use
    // the later comTxReady as the gate for reusing m_comFrameStorage.
    if (!this->m_comTxReady || this->m_txCircularBuffer.get_allocated_size() == 0) {
        return;
    }

    const FwSizeType sendSize = FW_MIN(this->m_txCircularBuffer.get_allocated_size(), COM_TX_FRAME_SIZE);
    Fw::SerializeStatus status = this->m_txCircularBuffer.peek(this->m_comFrameStorage, sendSize);
    FW_ASSERT(status == Fw::FW_SERIALIZE_OK, static_cast<FwAssertArgType>(status));
    status = this->m_txCircularBuffer.rotate(sendSize);
    FW_ASSERT(status == Fw::FW_SERIALIZE_OK, static_cast<FwAssertArgType>(status));
    Fw::Buffer data(this->m_comFrameStorage, sendSize);
    ComCfg::FrameContext context;

    this->m_comTxReady = false;
    this->comDataOut_out(0, data, context);
}

// ----------------------------------------------------------------------
// Handler implementations for typed input ports
// ----------------------------------------------------------------------

void ByteComBridge ::byteStreamReady_handler(FwIndexType portNum) {}

void ByteComBridge ::byteStreamRecv_handler(FwIndexType portNum,
                                            Fw::Buffer& buffer,
                                            const Drv::ByteStreamStatus& status) {
    if (status.e != Drv::ByteStreamStatus::OP_OK) {
        this->byteStreamRecvReturnOut_out(0, buffer);
        return;
    }

    this->enqueueByteStreamData(buffer);
    this->byteStreamRecvReturnOut_out(0, buffer);
    this->requestSendQueuedData();
}

void ByteComBridge ::comDataIn_handler(FwIndexType portNum, Fw::Buffer& data, const ComCfg::FrameContext& context) {
    const Drv::ByteStreamStatus status = this->byteStreamSend_out(0, data);
    if (status.e != Drv::ByteStreamStatus::OP_OK) {
        this->log_WARNING_HI_ByteStreamSendFailed(status);
    }
    this->comDataReturnOut_out(0, data, context);
}

void ByteComBridge ::comDataReturnIn_handler(FwIndexType portNum,
                                             Fw::Buffer& data,
                                             const ComCfg::FrameContext& context) {}

void ByteComBridge ::comStatusIn_handler(FwIndexType portNum, Fw::Success& status) {
    if (status.e != Fw::Success::SUCCESS) {
        this->log_WARNING_HI_ComStatusFailed(status);
        // After a failed transmit status we still reopen the gate and keep
        // draining buffered data, hoping the downstream link recovers anyway.
    }

    this->m_comTxReady = true;
    this->requestSendQueuedData();
}

}  // namespace Components
