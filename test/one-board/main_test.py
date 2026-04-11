"""
These tests require that only one board be connected to the PC. They should be run via `bft.sh`.
"""

from pathlib import Path
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[2]
DICTIONARY = (
    ROOT
    / "build-artifacts"
    / "zephyr"
    / "fprime-zephyr-deployment"
    / "dict"
    / "ReferenceDeploymentTopologyDictionary.json"
)
SEQUENCE_SOURCE = ROOT / "test" / "assets" / "cs_noop.seq"


@pytest.fixture(scope="module")
def compiled_sequence_bin(tmp_path_factory):
    output_dir = tmp_path_factory.mktemp("seq")
    output_bin = output_dir / "cs_noop.bin"

    assert DICTIONARY.exists()

    result = subprocess.run(
        [
            "fprime-seqgen",
            "--dictionary",
            str(DICTIONARY),
            str(SEQUENCE_SOURCE),
            str(output_bin),
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"fprime-seqgen failed:\n{result.stderr}"

    return output_bin


def test_send_noop(fprime_test_api):
    fprime_test_api.send_and_assert_command("CdhCore.cmdDisp.CMD_NO_OP", max_delay=0.1)
    assert fprime_test_api.get_command_test_history().size() == 1


def test_open_data_port(data_port_one):
    tty = open(data_port_one)
    tty.close()


def test_write_data_port(data_port_one):
    with open(data_port_one, mode="w") as tty:
        tty.write("\0")


def test_command_seq_run(fprime_test_api, compiled_sequence_bin):
    remote_path = "/cs_noop.bin"

    fprime_test_api.uplink_file_and_await_completion(
        str(compiled_sequence_bin), remote_path, timeout=5
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.cmdSeq.CS_RUN", [remote_path, "BLOCK"], timeout=2
    )
