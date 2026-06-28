"""
These tests require that one board be connected to the PC.
"""

import time

from fprime_gds.common.communication.ccsds.space_data_link import (
    SpaceDataLinkFramerDeframer,
)


def _tc_frame(scid: int, vcid: int, payload: bytes = b"x") -> bytes:
    return SpaceDataLinkFramerDeframer(scid=scid, vcid=vcid, frame_size=1024).frame(
        payload
    )


def _assert_no_warnings(fprime_test_api):
    warnings = [
        event.get_str(verbose=True)
        for event in fprime_test_api.get_event_test_history().retrieve()
        if "WARNING" in str(event.get_severity())
    ]
    assert not warnings, "Unexpected warning events:\n" + "\n".join(warnings)


def test_rejects_oversized_tc_frame(fprime_test_api, data_port_one):
    scid = 0x44
    vcid = 1
    oversized_frame = _tc_frame(scid, vcid, b"x" * 250)

    data_port_one.write(oversized_frame)

    assert fprime_test_api.await_event(
        "ReferenceDeployment.dataFrameAccumulator.FrameDetectionSizeError",
        args=[len(oversized_frame)],
        timeout=2,
    )


def test_reports_no_frame_buffer_available(fprime_test_api, data_port_one):
    scid = 0x44
    vcid = 1

    data_port_one.write(_tc_frame(scid, vcid, b"a") + _tc_frame(scid, vcid, b"b"))

    assert fprime_test_api.await_event(
        "ReferenceDeployment.dataFrameAccumulator.NoBufferAvailable", timeout=2
    )


def test_accepts_valid_tc_frames(fprime_test_api, data_port_one):
    scid = 0x44
    vcid = 1
    frame = _tc_frame(scid, vcid, b"payload")

    data_port_one.write(frame)
    time.sleep(1)

    _assert_no_warnings(fprime_test_api)
