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

    //! Handler implementation for TODO
    //!
    //! TODO
    void TODO_handler(FwIndexType portNum,  //!< The port number
                      U32 context           //!< The call order
                      ) override;
};

}  // namespace Components

#endif
