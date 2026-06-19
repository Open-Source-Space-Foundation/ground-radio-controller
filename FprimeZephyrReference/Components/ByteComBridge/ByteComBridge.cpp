// ======================================================================
// \title  ByteComBridge.cpp
// \author jrpear
// \brief  cpp file for ByteComBridge component implementation class
// ======================================================================

#include "FprimeZephyrReference/Components/ByteComBridge/ByteComBridge.hpp"

namespace Components {

// ----------------------------------------------------------------------
// Component construction and destruction
// ----------------------------------------------------------------------

ByteComBridge ::ByteComBridge(const char* const compName)
    : ByteComBridgeComponentBase(compName), m_pendingHead(0), m_pendingCount(0), m_comReady(false) {}

ByteComBridge ::~ByteComBridge() {}

// ----------------------------------------------------------------------
// Handler implementations for typed input ports
// ----------------------------------------------------------------------

void ByteComBridge ::byteStreamReady_handler(FwIndexType portNum) {
    // No action needed
}

void ByteComBridge ::byteStreamRecv_handler(FwIndexType portNum,
                                            Fw::Buffer& buffer,
                                            const Drv::ByteStreamStatus& status) {
    if (status.e != Drv::ByteStreamStatus::OP_OK) {
        // No valid data; return buffer ownership immediately
        this->byteStreamRecvReturnOut_out(0, buffer);
        return;
    }
    if (this->m_pendingCount >= PENDING_UPLINK_DEPTH) {
        // Defensive only: the holding queue is deeper than the buffer pool, so
        // the pool exhausts (back-pressuring the UART driver) before we get
        // here. Drop by returning ownership rather than overflow or assert.
        this->byteStreamRecvReturnOut_out(0, buffer);
        return;
    }
    // Queue the frame; it will be forwarded to LoRa only once the link is ready.
    const FwSizeType tail = (this->m_pendingHead + this->m_pendingCount) % PENDING_UPLINK_DEPTH;
    this->m_pendingUplink[tail] = buffer;
    this->m_pendingCount++;
    this->processPendingUplink();
}

void ByteComBridge ::comDataIn_handler(FwIndexType portNum, Fw::Buffer& data, const ComCfg::FrameContext& context) {
    this->byteStreamSend_out(0, data);
    this->comDataReturnOut_out(0, data, context);
}

void ByteComBridge ::comDataReturnIn_handler(FwIndexType portNum,
                                             Fw::Buffer& data,
                                             const ComCfg::FrameContext& context) {
    this->byteStreamRecvReturnOut_out(0, data);
}

void ByteComBridge ::comStatusIn_handler(FwIndexType portNum, Fw::Success& condition) {
    // LoRa has finished with the previous frame (success or failure) and is
    // ready for the next one. Treat any status as the flow-control credit so a
    // single failed transmit cannot stall the pipeline -- end-to-end checksums
    // and retransmit in the file-uplink protocol recover lost frames. Then
    // advance the queue.
    this->m_comReady = true;
    this->processPendingUplink();
}

void ByteComBridge ::processPendingUplink() {
    if (!this->m_comReady || this->m_pendingCount == 0) {
        return;
    }
    Fw::Buffer buffer = this->m_pendingUplink[this->m_pendingHead];
    this->m_pendingUplink[this->m_pendingHead] = Fw::Buffer();
    this->m_pendingHead = (this->m_pendingHead + 1) % PENDING_UPLINK_DEPTH;
    this->m_pendingCount--;
    // Consume the readiness credit before forwarding. comDataOut drives the
    // passive LoRa component synchronously on this thread; when it returns, LoRa
    // has already queued a fresh comStatusIn back to us that will release the
    // next frame. The buffer is returned to the UART driver later via
    // comDataReturnIn, so we must not return it here.
    this->m_comReady = false;
    ComCfg::FrameContext context;
    this->comDataOut_out(0, buffer, context);
}

}  // namespace Components
