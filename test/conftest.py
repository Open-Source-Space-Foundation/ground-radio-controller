import subprocess
import time
from pathlib import Path

import pytest
import serial


def _open_data_port(port: str) -> serial.Serial:
    tty = serial.Serial(port=port, timeout=2.0)
    tty.reset_input_buffer()
    return tty


def pytest_addoption(parser):
    parser.addoption(
        "--data-port-one",
        action="append",
        default=[],
        help="list of data_port_ones to pass to test functions",
    )
    parser.addoption(
        "--data-port-two",
        action="append",
        default=[],
        help="list of data_port_twos to pass to test functions",
    )
    parser.addoption(
        "--probe-usb-id",
        action="store",
        default="",
        help="debug probe USB VID:PID-interface",
    )
    parser.addoption(
        "--probe-one",
        action="store",
        default="",
        help="debug probe serial for board one",
    )
    parser.addoption(
        "--probe-two",
        action="store",
        default="",
        help="debug probe serial for board two",
    )
    parser.addoption(
        "--no-reset-before-test",
        action="store_true",
        default=False,
        help="do not reset board hardware before each test",
    )


def pytest_generate_tests(metafunc):
    if "data_port_one" in metafunc.fixturenames:
        metafunc.parametrize(
            "data_port_one",
            metafunc.config.getoption("--data-port-one"),
            indirect=True,
        )
    if "data_port_two" in metafunc.fixturenames:
        metafunc.parametrize(
            "data_port_two",
            metafunc.config.getoption("--data-port-two"),
            indirect=True,
        )


def _wait_for_data_ports(data_ports):
    paths = [Path(data_port) for data_port in data_ports]
    deadline = time.monotonic() + 10.0
    while time.monotonic() < deadline and not all(path.exists() for path in paths):
        time.sleep(0.1)

    missing = [path for path in paths if not path.exists()]
    if missing:
        pytest.fail(
            "Timed out waiting for reset data ports: " + ", ".join(map(str, missing))
        )


def _wait_for_gds(api):
    if (
        api.await_event(
            # FrameworkVersion is emitted during boot, so this confirms reset finished.
            # The default start="NOW" ignores stale events from earlier resets.
            "CdhCore.version.FrameworkVersion",
            timeout=10,
        )
        is None
    ):
        pytest.fail(
            "Timed out waiting for CdhCore.version.FrameworkVersion after board reset"
        )

    api.send_and_assert_command(
        # NO_OP confirms GDS can dispatch commands before the test starts.
        "CdhCore.cmdDisp.CMD_NO_OP",
        timeout=10,
    )


@pytest.fixture(autouse=True)
def reset_boards_between_tests(request):
    config = request.config
    data_ports = [config.getoption("--data-port-one")[0]]

    data_port_two = config.getoption("--data-port-two")
    if data_port_two:
        data_ports.append(data_port_two[0])

    if config.getoption("--no-reset-before-test"):
        _wait_for_data_ports(data_ports)
        return

    probe_usb_id = config.getoption("--probe-usb-id")
    probe_serials = [config.getoption("--probe-one")]
    if data_port_two:
        probe_serials.append(config.getoption("--probe-two"))

    api = None
    if "fprime_test_api" in request.fixturenames:
        api = request.getfixturevalue("fprime_test_api_session")

    for probe_serial in probe_serials:
        subprocess.run(
            [
                "probe-rs",
                "reset",
                "--probe",
                f"{probe_usb_id}:{probe_serial}",
            ],
            check=True,
            timeout=10.0,
        )

    _wait_for_data_ports(data_ports)

    if api is None:
        return

    _wait_for_gds(api)


@pytest.fixture
def data_port_one(request):
    tty = _open_data_port(request.param)
    try:
        yield tty
    finally:
        tty.close()


@pytest.fixture
def data_port_two(request):
    tty = _open_data_port(request.param)
    try:
        yield tty
    finally:
        tty.close()
