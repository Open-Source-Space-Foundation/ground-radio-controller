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
            "data_port_one", metafunc.config.getoption("--data-port-one")
        )
    if "data_port_two" in metafunc.fixturenames:
        metafunc.parametrize(
            "data_port_two", metafunc.config.getoption("--data-port-two")
        )
