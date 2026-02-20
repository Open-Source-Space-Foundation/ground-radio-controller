"""
These tests require that only one board to be connected to the PC. They should be run via `bft.sh`.
"""


def test_send_noop(fprime_test_api):
    fprime_test_api.send_and_assert_command("CdhCore.cmdDisp.CMD_NO_OP", max_delay=0.1)
    assert fprime_test_api.get_command_test_history().size() == 1


def test_open_data_port(data_port_one):
    tty = open(data_port_one)
    tty.close()
