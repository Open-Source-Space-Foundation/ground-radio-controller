// ======================================================================
// \title  ActivityLeds.cpp
// \brief  Status LEDs: firmware heartbeat and radio activity
// ======================================================================

#include "FprimeZephyrReference/Components/ActivityLeds/ActivityLeds.hpp"

#include <zephyr/devicetree.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/atomic.h>

#define HEARTBEAT_LED DT_ALIAS(heartbeat_led)
#define ACTIVITY_LED DT_ALIAS(activity_led)
#define LORA DT_NODELABEL(lora0)

#define HAS_LEDS DT_NODE_EXISTS(HEARTBEAT_LED) && DT_NODE_EXISTS(ACTIVITY_LED)

#if HAS_LEDS
static const struct gpio_dt_spec heartbeatLed = GPIO_DT_SPEC_GET(HEARTBEAT_LED, gpios);
static const struct gpio_dt_spec activityLed = GPIO_DT_SPEC_GET(ACTIVITY_LED, gpios);
static const struct gpio_dt_spec radioTxEnable = GPIO_DT_SPEC_GET(LORA, tx_enable_gpios);
static const struct gpio_dt_spec radioIrqLine = GPIO_DT_SPEC_GET(LORA, dio1_gpios);

static atomic_t radioIrqCount = ATOMIC_INIT(0);
static struct gpio_callback radioIrqCallback;

static void countRadioIrq(const struct device* port, struct gpio_callback* cb, gpio_port_pins_t pins) {
    atomic_inc(&radioIrqCount);
}
#endif

namespace Components {

ActivityLeds ::ActivityLeds(const char* const compName) : ActivityLedsComponentBase(compName) {}

void ActivityLeds ::start() {
#if HAS_LEDS
    // The LoRa driver owns radioIrqLine; a second callback on the same pin only observes it.
    if (gpio_pin_configure_dt(&heartbeatLed, GPIO_OUTPUT_INACTIVE) != 0 ||
        gpio_pin_configure_dt(&activityLed, GPIO_OUTPUT_INACTIVE) != 0) {
        return;
    }
    gpio_init_callback(&radioIrqCallback, countRadioIrq, BIT(radioIrqLine.pin));
    if (gpio_add_callback(radioIrqLine.port, &radioIrqCallback) != 0) {
        return;
    }
    this->m_started = true;
#endif
}

void ActivityLeds ::run_handler(FwIndexType portNum, U32 context) {
#if HAS_LEDS
    if (!this->m_started) {
        return;
    }
    this->m_ticks = (this->m_ticks + 1) % RUN_HZ;
    gpio_pin_set_dt(&heartbeatLed, this->m_ticks < HEARTBEAT_ON_TICKS);

    const bool transmitting = gpio_pin_get_dt(&radioTxEnable) > 0;
    // TxDone also raises the IRQ line, so ignore IRQs from a tick that saw TX.
    if (atomic_clear(&radioIrqCount) != 0 && !transmitting && !this->m_wasTransmitting) {
        this->m_rxBlinkTicks = RX_BLINK_TICKS;
    }
    this->m_wasTransmitting = transmitting;
    gpio_pin_set_dt(&activityLed, transmitting || this->m_rxBlinkTicks > 0);
    if (this->m_rxBlinkTicks > 0) {
        this->m_rxBlinkTicks--;
    }
#endif
}

}  // namespace Components
