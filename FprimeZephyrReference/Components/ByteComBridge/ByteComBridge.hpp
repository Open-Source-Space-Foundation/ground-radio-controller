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

    // ----------------------------------------------------------------------
    // Helper methods
    // ----------------------------------------------------------------------

    //! Forward the next queued uplink frame to the Com (LoRa) port, but only
    //! while the link has signaled readiness via comStatusIn. This honors the
    //! comStatus ping-pong so the bridge never feeds the slow LoRa link faster
    //! than it drains, which is what previously overflowed the async queue and
    //! triggered a FATAL reboot.
    void processPendingUplink();

    // ----------------------------------------------------------------------
    // Member variables
    // ----------------------------------------------------------------------

    //! Depth of the pending-uplink holding queue. Sized >= the dataBufferManager
    //! pool depth (8 buffers) so this queue never fills before the buffer pool
    //! exhausts: pool exhaustion is what back-pressures the UART source, so the
    //! drop path below is purely defensive and should never be reached.
    static constexpr FwSizeType PENDING_UPLINK_DEPTH = 10;

    //! Ring buffer of uplink frames awaiting a comStatus-ready LoRa link.
    Fw::Buffer m_pendingUplink[PENDING_UPLINK_DEPTH];

    //! Index of the oldest queued uplink frame in m_pendingUplink.
    FwSizeType m_pendingHead;

    //! Number of uplink frames currently queued in m_pendingUplink.
    FwSizeType m_pendingCount;

    //! True when the downstream Com (LoRa) has signaled readiness for the next
    //! frame via comStatusIn. Mirrors Svc::ComQueue's WAITING/READY credit:
    //! starts false (WAITING) and is primed by LoRa's initial comStatus, which
    //! it emits once transmit is enabled (uhf.start(..., ENABLED)).
    bool m_comReady;
};

}  // namespace Components

#endif
