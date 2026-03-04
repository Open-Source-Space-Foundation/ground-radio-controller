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

void ByteComBridge ::TODO_handler(FwIndexType portNum, U32 context) {
    // TODO
}

}  // namespace Components
