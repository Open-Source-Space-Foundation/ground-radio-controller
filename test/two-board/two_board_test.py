"""
These tests require another board be flashed with radio controller software and
also connected to the PC. Should be run via `bft.sh`.
"""

import time

BASELINE_FREQUENCY_HZ = 437400000
PASS_FREQUENCY_HZ = 437430000
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


def test_link_one_to_two_4096_bytes_one_byte_writes(
    fprime_test_api, data_port_one, data_port_two
):
    try:
        # ByteComBridge emits at most 252 bytes into each LoRa frame. The Semtech
        # LoRa calculator, https://www.semtech.com/design-support/lora-calculator,
        # gives 901.63 ms time on air for the deployed modem settings (SF8, 125
        # kHz, CR 4/5) at a 252-byte payload, which yields 252 * 8 / 0.90163 ~=
        # 2236 bits/s. Keep the test below that sustained link rate so it models
        # what the radio can drain without relying on extra bridge buffering.
        sent = bytes(range(256)) * 16
        bitrate = 2000
        byte_period_seconds = 8 / bitrate

        for byte in sent:
            assert data_port_one.write(bytes([byte])) == 1
            data_port_one.flush()
            time.sleep(byte_period_seconds)

        received = data_port_two.read(len(sent))
        assert received == sent, (
            f"Expected {len(sent)} bytes from board two, received {len(received)}"
        )
    finally:
        _assert_no_warnings(fprime_test_api)


def test_link_one_to_two_six_252_byte_packets(
    fprime_test_api, data_port_one, data_port_two
):
    try:
        chunk = bytes(range(252))
        sent = chunk * 6

        for _ in range(6):
            assert data_port_one.write(chunk) == len(chunk)
            data_port_one.flush()
            # The Semtech LoRa calculator reports about 901.63 ms time on air for
            # a 252-byte payload at SF8, 125 kHz, CR 4/5, so sleep 1 s to leave the
            # radio enough time to finish each packet before sending the next one.
            time.sleep(1.0)

        received = data_port_two.read(len(sent))
        assert received == sent, (
            f"Expected {len(sent)} bytes from board two, received {len(received)}"
        )
    finally:
        _assert_no_warnings(fprime_test_api)


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
