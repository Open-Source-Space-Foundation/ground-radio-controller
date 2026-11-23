"""
These tests require that one board be connected to the PC.
"""

import re
import subprocess
import time

from fprime_gds.common.communication.ccsds.space_data_link import (
    SpaceDataLinkFramerDeframer,
)

MAX_LORA_DATA_FRAME_SIZE = 248
TC_FRAME_OVERHEAD_SIZE = 7


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
    oversized_frame = _tc_frame(
        scid, vcid, b"x" * (MAX_LORA_DATA_FRAME_SIZE - TC_FRAME_OVERHEAD_SIZE + 1)
    )
    assert len(oversized_frame) == MAX_LORA_DATA_FRAME_SIZE + 1

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


def _serial(data_port):
    return re.search(r"_([0-9A-F]+)-if02$", data_port.port).group(1)


def _bootloader_key(data_port):
    return int(_serial(data_port)[-8:], 16)


def test_bootloader_rejects_another_boards_key(fprime_test_api, data_port_one):
    fprime_test_api.send_command(
        "ReferenceDeployment.bootloaderTrigger.ARM_BOOTLOADER",
        [_bootloader_key(data_port_one) ^ 1],
    )

    assert fprime_test_api.await_event(
        "ReferenceDeployment.bootloaderTrigger.BootloaderKeyRejected", timeout=2
    )


def test_enter_bootloader_needs_arm(fprime_test_api, data_port_one):
    fprime_test_api.send_command(
        "ReferenceDeployment.bootloaderTrigger.TRIGGER_BOOTLOADER",
        [_bootloader_key(data_port_one)],
    )

    assert fprime_test_api.await_event(
        "ReferenceDeployment.bootloaderTrigger.BootloaderNotArmed", timeout=2
    )


def test_enter_bootloader_reboots_into_bootsel(fprime_test_api, data_port_one):
    serial = _serial(data_port_one)
    key = _bootloader_key(data_port_one)
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.bootloaderTrigger.ARM_BOOTLOADER", [key]
    )
    fprime_test_api.send_command(
        "ReferenceDeployment.bootloaderTrigger.TRIGGER_BOOTLOADER", [key]
    )

    deadline = time.monotonic() + 10
    in_bootsel = False
    while not in_bootsel and time.monotonic() < deadline:
        info = subprocess.run(
            ["picotool", "info", "--ser", serial], check=False, capture_output=True
        )
        in_bootsel = info.returncode == 0
        time.sleep(0.5)
    subprocess.run(["picotool", "reboot", "--ser", serial], check=False)
    assert in_bootsel, f"{serial} did not appear in BOOTSEL"
