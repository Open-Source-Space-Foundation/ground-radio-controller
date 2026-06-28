"""These tests require two flashed boards connected to the PC."""

import time

from fprime_gds.common.communication.ccsds.space_data_link import (
    SpaceDataLinkFramerDeframer,
)

SCID = 0x44
VCID = 1
MAX_TC_FRAME_SIZE = 248
MAX_TC_FRAME_PAYLOAD_SIZE = 241
LONG_FRAME_COUNT = 64


def _assert_no_warnings(fprime_test_api):
    warnings = [
        event.get_str(verbose=True)
        for event in fprime_test_api.get_event_test_history().retrieve()
        if "WARNING" in str(event.get_severity())
    ]
    assert not warnings, "Unexpected warning events:\n" + "\n".join(warnings)


def _tc_frame(payload: bytes) -> bytes:
    return SpaceDataLinkFramerDeframer(scid=SCID, vcid=VCID, frame_size=None).frame(
        payload
    )


def test_link_one_to_two_64_max_tc_frames(
    fprime_test_api, data_port_one, data_port_two
):
    try:
        frames = [
            _tc_frame(bytes([frame_number]) * MAX_TC_FRAME_PAYLOAD_SIZE)
            for frame_number in range(LONG_FRAME_COUNT)
        ]
        sent = b"".join(frames)
        received = b""

        for frame in frames:
            assert len(frame) == MAX_TC_FRAME_SIZE
            assert data_port_one.write(frame) == len(frame)
            data_port_one.flush()
            received += data_port_two.read_all()
            # A 252-byte LoRa packet has about 902ms time-on-air according to
            # Semtech calculator at SF8/125 kHz/CR 4/5
            time.sleep(1.0)
        received += data_port_two.read(len(sent) - len(received))

        assert received == sent, (
            f"Expected {len(frames)} packets from board two, "
            f"received {len(received) / MAX_TC_FRAME_SIZE:g}"
        )
    finally:
        _assert_no_warnings(fprime_test_api)


def test_link_two_to_one_64_max_tc_frames(
    fprime_test_api, data_port_one, data_port_two
):
    try:
        frames = [
            _tc_frame(bytes([frame_number]) * MAX_TC_FRAME_PAYLOAD_SIZE)
            for frame_number in range(LONG_FRAME_COUNT)
        ]
        sent = b"".join(frames)
        received = b""

        for frame in frames:
            assert len(frame) == MAX_TC_FRAME_SIZE
            assert data_port_two.write(frame) == len(frame)
            # See comment in one-to-two test
            data_port_two.flush()
            received += data_port_one.read_all()
            time.sleep(1.0)

        received += data_port_one.read(len(sent) - len(received))

        assert received == sent, (
            f"Expected {len(frames)} packets from board one, "
            f"received {len(received) / MAX_TC_FRAME_SIZE:g}"
        )
    finally:
        _assert_no_warnings(fprime_test_api)
