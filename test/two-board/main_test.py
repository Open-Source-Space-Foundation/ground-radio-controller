"""These tests require two flashed boards connected to the PC."""

from fprime_gds.common.communication.ccsds.space_data_link import (
    SpaceDataLinkFramerDeframer,
)

BASELINE_FREQUENCY_HZ = 437400000
PASS_FREQUENCY_HZ = 437425000
FAIL_FREQUENCY_HZ = 437435000
SCID = 0x44
VCID = 1


def _tc_frame(payload: bytes) -> bytes:
    return SpaceDataLinkFramerDeframer(scid=SCID, vcid=VCID, frame_size=248).frame(
        payload
    )


def _assert_no_warnings(fprime_test_api):
    warnings = [
        event.get_str(verbose=True)
        for event in fprime_test_api.get_event_test_history().retrieve()
        if "WARNING" in str(event.get_severity())
    ]
    assert not warnings, "Unexpected warning events:\n" + "\n".join(warnings)


def test_link_one_to_two_one_packet(fprime_test_api, data_port_one, data_port_two):
    try:
        sent = _tc_frame(b"one-packet")
        data_port_one.write(sent)
        data_port_one.flush()

        received = data_port_two.read(len(sent))
        assert received == sent, "Timed out waiting for data from board two"
    finally:
        _assert_no_warnings(fprime_test_api)


def test_link_survives_valid_freq_change(fprime_test_api, data_port_one, data_port_two):
    sent = _tc_frame(b"freq-ok")

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
    sent = _tc_frame(b"freq-bad")

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
