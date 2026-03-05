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

ByteComBridge ::ByteComBridge(const char* const compName) : ByteComBridgeComponentBase(compName) {}

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
    if (status.e == Drv::ByteStreamStatus::OP_OK) {
        ComCfg::FrameContext context;
        this->comDataOut_out(0, buffer, context);
    } else {
        // No valid data; return buffer ownership immediately
        this->byteStreamRecvReturnOut_out(0, buffer);
    }
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
    // No action needed
}

}  // namespace Components
