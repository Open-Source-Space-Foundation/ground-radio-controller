"""
These tests require that one board be connected to the PC.
"""


def test_send_noop(fprime_test_api):
    fprime_test_api.send_and_assert_command("CdhCore.cmdDisp.CMD_NO_OP", timeout=2)
    assert fprime_test_api.get_command_test_history().size() == 1


def test_set_center_freq(fprime_test_api):
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.uhf.SET_FREQ",
        [437400000],
        timeout=2,
    )


def test_open_data_port(data_port_one):
    assert data_port_one.is_open


def test_write_data_port(data_port_one):
    assert data_port_one.write(b"\0") == 1
    data_port_one.flush()


def test_large_data_port_write_fills_bridge_buffer(fprime_test_api, data_port_one):
    sent = b"x" * 1024

    assert data_port_one.write(sent) == len(sent)
    data_port_one.flush()

    assert fprime_test_api.await_event(
        "ReferenceDeployment.byteComBridge.ByteStreamBufferFull", timeout=2
    )
