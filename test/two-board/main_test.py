"""These tests require two flashed boards connected to the PC."""

from fprime_gds.common.communication.ccsds.space_data_link import (
    SpaceDataLinkFramerDeframer,
)

BASELINE_FREQUENCY_HZ = 437400000
PASS_FREQUENCY_HZ = 437425000
FAIL_FREQUENCY_HZ = 437435000
MAX_LORA_DATA_FRAME_SIZE = 248
TC_FRAME_OVERHEAD_SIZE = 7
SCID = 0x44
VCID = 1
ALTERNATE_FRAME_IDS = ((0x45, 3), (0x46, 4))


def _tc_frame(payload: bytes, scid: int = SCID, vcid: int = VCID) -> bytes:
    return SpaceDataLinkFramerDeframer(scid=scid, vcid=vcid, frame_size=None).frame(
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

        received = data_port_two.read(len(sent))
        assert received == sent, "Timed out waiting for data from board two"
    finally:
        _assert_no_warnings(fprime_test_api)


def test_link_one_to_two_back_to_back_packets(data_port_one, data_port_two):
    packets = [_tc_frame(f"back-to-back-{i}".encode()) for i in range(4)]

    for first, second in zip(packets[::2], packets[1::2]):
        data_port_one.write(first + second)
        assert data_port_two.read(len(first)) == first
        assert data_port_two.read(len(second)) == second


def test_link_allows_different_scids_and_vcids(
    fprime_test_api, data_port_one, data_port_two
):
    try:
        for index, (scid, vcid) in enumerate(ALTERNATE_FRAME_IDS):
            sent = _tc_frame(f"alternate-ids-{index}".encode(), scid=scid, vcid=vcid)
            data_port_one.write(sent)

            received = data_port_two.read(len(sent))
            assert received == sent, "Timed out waiting for data from board two"
    finally:
        _assert_no_warnings(fprime_test_api)


def test_link_recovers_after_frame_buffer_exhaustion(
    fprime_test_api, data_port_one, data_port_two
):
    max_size_packet = _tc_frame(
        b"x" * (MAX_LORA_DATA_FRAME_SIZE - TC_FRAME_OVERHEAD_SIZE)
    )

    data_port_one.write(max_size_packet * 3)

    assert fprime_test_api.await_event(
        "ReferenceDeployment.dataFrameAccumulator.NoBufferAvailable", timeout=2
    )

    assert data_port_two.read(len(max_size_packet)) == max_size_packet
    assert data_port_two.read(len(max_size_packet)) == max_size_packet

    # Verify packet can come through after GRC has time to return the buffer
    data_port_one.write(max_size_packet)

    assert data_port_two.read(len(max_size_packet)) == max_size_packet


def test_link_drops_unframed_bytes(fprime_test_api, data_port_one, data_port_two):
    try:
        packets = [_tc_frame(b"first"), _tc_frame(b"second")]
        received_packets = []

        sent = b"junk-before" + packets[0] + b"junk-between"
        assert data_port_one.write(sent) == len(sent)
        received_packets.append(data_port_two.read(len(packets[0])))

        assert data_port_one.write(packets[1]) == len(packets[1])
        received_packets.append(data_port_two.read(len(packets[1])))

        assert received_packets == packets, (
            f"Expected {len(packets)} framed packets from board two, "
            f"received {sum(received == expected for received, expected in zip(received_packets, packets))}"
        )
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
