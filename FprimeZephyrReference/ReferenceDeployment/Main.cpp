// ======================================================================
// \title  Main.cpp
// \brief main program for the F' application. Intended for CLI-based systems (Linux, macOS)
//
// ======================================================================
// Used to access topology functions
#include <FprimeZephyrReference/ReferenceDeployment/Top/ReferenceDeploymentTopology.hpp>
#include <zephyr/sys/printk.h>
#include <zephyr/usb/usbd.h>

USBD_DEVICE_DEFINE(cdc_acm_serial_two_port,
                   DEVICE_DT_GET(DT_NODELABEL(zephyr_udc0)),
                   CONFIG_LOCAL_USB_VID,
                   CONFIG_LOCAL_USB_PID);

USBD_DESC_LANG_DEFINE(cdc_acm_serial_lang);
USBD_DESC_MANUFACTURER_DEFINE(cdc_acm_serial_mfr, CONFIG_LOCAL_USB_MANUFACTURER_STRING);
USBD_DESC_PRODUCT_DEFINE(cdc_acm_serial_product, CONFIG_LOCAL_USB_PRODUCT_STRING);
IF_ENABLED(CONFIG_HWINFO, (USBD_DESC_SERIAL_NUMBER_DEFINE(cdc_acm_serial_sn)));

USBD_DESC_CONFIG_DEFINE(fs_cfg_desc, "FS Configuration");

static const uint8_t attributes = 0;  // No special attributes (e.g., self-powered, remote wakeup)

USBD_CONFIGURATION_DEFINE(cdc_acm_serial_fs_config, attributes, CONFIG_LOCAL_USB_MAX_POWER, &fs_cfg_desc);

static int cdc_acm_serial_init_device(void) {
    int err;

    err = usbd_add_descriptor(&cdc_acm_serial_two_port, &cdc_acm_serial_lang);
    if (err) {
        printk("Failed to initialize %s (%d)", "language descriptor", err);
        return err;
    }

    err = usbd_add_descriptor(&cdc_acm_serial_two_port, &cdc_acm_serial_mfr);
    if (err) {
        printk("Failed to initialize %s (%d)", "manufacturer descriptor", err);
        return err;
    }

    err = usbd_add_descriptor(&cdc_acm_serial_two_port, &cdc_acm_serial_product);
    if (err) {
        printk("Failed to initialize %s (%d)", "product descriptor", err);
        return err;
    }

    IF_ENABLED(CONFIG_HWINFO, (err = usbd_add_descriptor(&cdc_acm_serial_two_port, &cdc_acm_serial_sn);))
    if (err) {
        printk("Failed to initialize %s (%d)", "SN descriptor", err);
        return err;
    }

    err = usbd_add_configuration(&cdc_acm_serial_two_port, USBD_SPEED_FS, &cdc_acm_serial_fs_config);
    if (err) {
        printk("Failed to add configuration");
        return err;
    }

    err = usbd_register_class(&cdc_acm_serial_two_port, "cdc_acm_0", USBD_SPEED_FS, 1);
    if (err) {
        printk("Failed to register class 1");
        return err;
    }

    err = usbd_register_class(&cdc_acm_serial_two_port, "cdc_acm_1", USBD_SPEED_FS, 1);
    if (err) {
        printk("Failed to register class 2");
        return err;
    }

    err = usbd_device_set_code_triple(&cdc_acm_serial_two_port, USBD_SPEED_FS, USB_BCC_MISCELLANEOUS, 0x02, 0x01);
    if (err) {
        return err;
    }

    err = usbd_init(&cdc_acm_serial_two_port);
    if (err) {
        printk("Failed to initialize %s (%d)", "device support", err);
        return err;
    }

    err = usbd_enable(&cdc_acm_serial_two_port);
    if (err) {
        printk("Failed to enable %s (%d)", "device support", err);
        return err;
    }

    return 0;
}

int main(int argc, char* argv[]) {
    cdc_acm_serial_init_device();

    // ** DO NOT REMOVE **//
    //
    // This sleep is necessary to allow the USB CDC ACM interface to initialize before
    // the application starts writing to it.
    k_sleep(K_MSEC(3000));

    Os::init();
    // Object for communicating state to the topology
    ReferenceDeployment::TopologyState inputs;
    inputs.controlUartDevice = DEVICE_DT_GET(DT_NODELABEL(cdc_acm_uart0));
    inputs.dataUartDevice = DEVICE_DT_GET(DT_NODELABEL(cdc_acm_uart1));
    inputs.controlUartBaudRate = 115200;
    inputs.dataUartBaudRate = 115200;

    // Setup, cycle, and teardown topology
    ReferenceDeployment::setupTopology(inputs);
    ReferenceDeployment::startRateGroups();  // Program loop
    ReferenceDeployment::teardownTopology(inputs);
    return 0;
}
