"""
These tests require another board be flashed with radio controller software and
the connected PC is looping back data `cat /dev/ttyX >/dev/ttyX`
"""


def test_open_data_ports(data_port_one, data_port_two):
    tty1 = open(data_port_one)
    tty1.close()
    tty2 = open(data_port_one)
    tty2.close()


def test_write_increments_packets_received():
    # validate that 1 tx causes another rx on 1 board
    pass


def test_full_loopback():
    # validate that data out = data in
    pass


# Then test with changing doppler params
