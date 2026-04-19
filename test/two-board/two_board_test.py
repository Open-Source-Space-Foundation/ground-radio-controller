"""
These tests require another board be flashed with radio controller software and
also connected to the PC. Should be run via `bft.sh`.
"""

BASELINE_FREQUENCY_HZ = 437400000
PASS_FREQUENCY_HZ = 437430000
FAIL_FREQUENCY_HZ = 437435000


def test_open_data_ports(data_port_one, data_port_two):
    assert data_port_one.is_open
    assert data_port_two.is_open


def test_link_one_to_two(data_port_one, data_port_two):
    sent = b"\0"
    data_port_one.write(sent)
    data_port_one.flush()
    received = data_port_two.read(len(sent))
    assert received == sent, "Timed out waiting for data from board two"


def test_link_breaks_after_mismatched_freq(
    fprime_test_api, data_port_one, data_port_two
):
    sent = b"cfbad"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.uhf.SET_FREQ",
        [BASELINE_FREQUENCY_HZ],
        max_delay=2,
    )
    try:
        fprime_test_api.send_and_assert_command(
            "ReferenceDeployment.uhf.SET_FREQ",
            [FAIL_FREQUENCY_HZ],
            max_delay=2,
        )
        data_port_one.write(sent)
        data_port_one.flush()
        received = data_port_two.read(len(sent))
        assert received != sent, (
            "Unexpectedly received payload across mismatched frequencies"
        )
    finally:
        fprime_test_api.send_and_assert_command(
            "ReferenceDeployment.uhf.SET_FREQ",
            [BASELINE_FREQUENCY_HZ],
            max_delay=2,
        )


def test_link_survives_valid_freq_change(fprime_test_api, data_port_one, data_port_two):
    sent = b"cfgud"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.uhf.SET_FREQ",
        [BASELINE_FREQUENCY_HZ],
        max_delay=2,
    )
    try:
        fprime_test_api.send_and_assert_command(
            "ReferenceDeployment.uhf.SET_FREQ",
            [PASS_FREQUENCY_HZ],
            max_delay=2,
        )
        data_port_one.write(sent)
        data_port_one.flush()
        received = data_port_two.read(len(sent))
        assert received == sent, (
            "Timed out waiting for data from board two after frequency change"
        )
    finally:
        fprime_test_api.send_and_assert_command(
            "ReferenceDeployment.uhf.SET_FREQ",
            [BASELINE_FREQUENCY_HZ],
            max_delay=2,
        )
