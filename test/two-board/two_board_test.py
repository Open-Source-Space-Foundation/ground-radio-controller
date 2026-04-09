"""
These tests require another board be flashed with radio controller software and
also connected to the PC. Should be run via `bft.sh`.
"""


def test_open_data_ports(data_port_one, data_port_two):
    tty1 = open(data_port_one)
    tty1.close()
    tty2 = open(data_port_two)
    tty2.close()
