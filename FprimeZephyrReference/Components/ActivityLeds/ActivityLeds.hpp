// ======================================================================
// \title  ActivityLeds.hpp
// \brief  Status LEDs: firmware heartbeat and radio activity
// ======================================================================

#ifndef Components_ActivityLeds_HPP
#define Components_ActivityLeds_HPP

#include "FprimeZephyrReference/Components/ActivityLeds/ActivityLedsComponentAc.hpp"

namespace Components {

class ActivityLeds final : public ActivityLedsComponentBase {
  public:
    static constexpr U32 RUN_HZ = 100;
    static constexpr U32 HEARTBEAT_ON_TICKS = 10;
    static constexpr U32 RX_BLINK_TICKS = 5;

    explicit ActivityLeds(const char* const compName);

    ~ActivityLeds() = default;

    //! Configure the LED pins and hook the radio interrupt line
    void start();

  private:
    void run_handler(FwIndexType portNum, U32 context) override;

    U32 m_ticks = 0;
    U32 m_rxBlinkTicks = 0;
    bool m_wasTransmitting = false;
    bool m_started = false;
};

}  // namespace Components

#endif
