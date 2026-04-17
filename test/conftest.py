import pytest
import serial


SERIAL_READ_TIMEOUT_SECONDS = 5.0


def _open_data_port(port: str) -> serial.Serial:
    tty = serial.Serial(port=port, timeout=SERIAL_READ_TIMEOUT_SECONDS)
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
