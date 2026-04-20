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
    : ByteComBridgeComponentBase(compName), m_byteStreamReady(false), m_txReady(false) {}

ByteComBridge ::~ByteComBridge() {}

// ----------------------------------------------------------------------
// Handler implementations for typed input ports
// ----------------------------------------------------------------------

void ByteComBridge ::byteStreamReady_handler(FwIndexType portNum) {
    this->m_byteStreamReady = true;
}

void ByteComBridge ::byteStreamRecv_handler(FwIndexType portNum,
                                            Fw::Buffer& buffer,
                                            const Drv::ByteStreamStatus& status) {
    if (status.e != Drv::ByteStreamStatus::OP_OK) {
        this->byteStreamRecvReturnOut_out(0, buffer);
        return;
    }

    if (!this->m_byteStreamReady) {
        this->byteStreamRecvReturnOut_out(0, buffer);
        return;
    }

    if (!this->m_txReady) {
        this->log_WARNING_HI_ComNotReady();
        this->byteStreamRecvReturnOut_out(0, buffer);
        return;
    }

    this->m_txReady = false;
    ComCfg::FrameContext context;
    this->comDataOut_out(0, buffer, context);
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
                                             const ComCfg::FrameContext& context) {
    this->byteStreamRecvReturnOut_out(0, data);
}

void ByteComBridge ::comStatusIn_handler(FwIndexType portNum, Fw::Success& condition) {
    this->m_txReady = (condition.e == Fw::Success::SUCCESS);
}

}  // namespace Components
