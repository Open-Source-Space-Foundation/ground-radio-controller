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
    // TODO
}

void ByteComBridge ::byteStreamRecv_handler(FwIndexType portNum,
                                            Fw::Buffer& buffer,
                                            const Drv::ByteStreamStatus& status) {
    // TODO
}

void ByteComBridge ::comDataIn_handler(FwIndexType portNum, Fw::Buffer& data, const ComCfg::FrameContext& context) {
    // TODO
}

void ByteComBridge ::comDataReturnIn_handler(FwIndexType portNum,
                                             Fw::Buffer& data,
                                             const ComCfg::FrameContext& context) {
    // TODO
}

void ByteComBridge ::comStatusIn_handler(FwIndexType portNum, Fw::Success& condition) {
    // TODO
}

void ByteComBridge ::recvReturnIn_handler(FwIndexType portNum, Fw::Buffer& fwBuffer) {
    // TODO
}

}  // namespace Components
