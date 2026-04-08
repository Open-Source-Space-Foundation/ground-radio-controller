"""
These tests require that only one board to be connected to the PC. They should be run via `bft.sh`.
"""


def test_send_noop(fprime_test_api):
    fprime_test_api.send_and_assert_command("CdhCore.cmdDisp.CMD_NO_OP", max_delay=0.1)
    assert fprime_test_api.get_command_test_history().size() == 1


def test_open_data_port(data_port_one):
    tty = open(data_port_one)
    tty.close()


def test_write_data_port(data_port_one):
    with open(data_port_one, mode="w") as tty:
        tty.write("\0")


def test_create_directory(fprime_test_api):
    dir_name = "/test_dir"

    fprime_test_api.send_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.CreateDirectorySucceeded",
        timeout=2,
    )
