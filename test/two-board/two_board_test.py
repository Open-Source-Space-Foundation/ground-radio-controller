"""
These tests require another board be flashed with radio controller software and
also connected to the PC. Should be run via `bft.sh`.
"""


def test_open_data_ports(data_port_one, data_port_two):
    assert data_port_one.is_open
    assert data_port_two.is_open


def test_link_one_to_two(data_port_one, data_port_two):
    sent = b"\0"
    data_port_one.write(sent)
    data_port_one.flush()
    received = data_port_two.read(len(sent))
    assert received == sent, "Timed out waiting for data from board two"
