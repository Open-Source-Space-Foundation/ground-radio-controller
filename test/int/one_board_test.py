def test_send_noop(fprime_test_api):
    fprime_test_api.send_and_assert_command("CdhCore.cmdDisp.CMD_NO_OP", max_delay=0.1)
    assert fprime_test_api.get_command_test_history().size() == 1


def test_open_data_port():
    tty = open("/dev/serial/by-id/usb-F_Prime_Pomona_Ground_Station-if02")
    tty.close()

