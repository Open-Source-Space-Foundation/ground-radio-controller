"""
These tests require two boards be flashed with radio controller software and
connected to the PC.
"""

import time

BASELINE_FREQUENCY_HZ = 437400000
PASS_FREQUENCY_HZ = 437425000
FAIL_FREQUENCY_HZ = 437435000


def _assert_no_warnings(fprime_test_api):
    warnings = [
        event.get_str(verbose=True)
        for event in fprime_test_api.get_event_test_history().retrieve()
        if "WARNING" in str(event.get_severity())
    ]
    assert not warnings, "Unexpected warning events:\n" + "\n".join(warnings)


def test_open_data_ports(fprime_test_api, data_port_one, data_port_two):
    assert data_port_one.is_open
    assert data_port_two.is_open


def test_link_one_to_two(fprime_test_api, data_port_one, data_port_two):
    try:
        sent = b"\0"
        data_port_one.write(sent)
        data_port_one.flush()
        received = data_port_two.read(len(sent))
        assert received == sent, "Timed out waiting for data from board two"
    finally:
        _assert_no_warnings(fprime_test_api)


def test_link_one_to_two_single_252_byte_write(
    fprime_test_api, data_port_one, data_port_two
):
    try:
        sent = bytes(range(252))

        assert data_port_one.write(sent) == len(sent)
        data_port_one.flush()

        received = data_port_two.read(len(sent))
        assert received == sent, "Timed out waiting for 252-byte payload from board two"
    finally:
        _assert_no_warnings(fprime_test_api)


def test_link_survives_valid_freq_change(fprime_test_api, data_port_one, data_port_two):
    sent = b"cfgud"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.uhf.SET_FREQ",
        [BASELINE_FREQUENCY_HZ],
        timeout=2,
    )
    try:
        fprime_test_api.send_and_assert_command(
            "ReferenceDeployment.uhf.SET_FREQ",
            [PASS_FREQUENCY_HZ],
            timeout=2,
        )
        data_port_one.write(sent)
        data_port_one.flush()
        received = data_port_two.read(len(sent))
        assert received == sent, (
            "Timed out waiting for data from board two after frequency change"
        )
    finally:
        _assert_no_warnings(fprime_test_api)
        fprime_test_api.send_and_assert_command(
            "ReferenceDeployment.uhf.SET_FREQ",
            [BASELINE_FREQUENCY_HZ],
            timeout=2,
        )


def test_link_breaks_after_mismatched_freq(
    fprime_test_api, data_port_one, data_port_two
):
    sent = b"cfbad"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.uhf.SET_FREQ",
        [BASELINE_FREQUENCY_HZ],
        timeout=2,
    )
    try:
        fprime_test_api.send_and_assert_command(
            "ReferenceDeployment.uhf.SET_FREQ",
            [FAIL_FREQUENCY_HZ],
            timeout=2,
        )
        data_port_one.write(sent)
        data_port_one.flush()
        received = data_port_two.read(len(sent))
        assert received != sent, (
            "Unexpectedly received payload across mismatched frequencies"
        )
    finally:
        _assert_no_warnings(fprime_test_api)
        fprime_test_api.send_and_assert_command(
            "ReferenceDeployment.uhf.SET_FREQ",
            [BASELINE_FREQUENCY_HZ],
            timeout=2,
        )
