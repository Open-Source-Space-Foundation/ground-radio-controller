"""
These tests require that only one board to be connected to the PC. They should be run via `bft.sh`.
"""

from tempfile import NamedTemporaryFile


def test_send_noop(fprime_test_api):
    fprime_test_api.send_and_assert_command("CdhCore.cmdDisp.CMD_NO_OP", max_delay=0.1)
    assert fprime_test_api.get_command_test_history().size() == 1


def test_open_data_port(data_port_one):
    tty = open(data_port_one)
    tty.close()


def test_write_data_port(data_port_one):
    with open(data_port_one, mode="w") as tty:
        tty.write("\0")


def test_create_and_remove_directory(fprime_test_api):
    dir_name = "/test_dir"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
        timeout=2,
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.CreateDirectorySucceeded",
        timeout=2,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
        timeout=2,
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.RemoveDirectorySucceeded",
        timeout=2,
    )


def test_list_directory(fprime_test_api):
    dir_name = "/test_dir"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
        timeout=2,
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.CreateDirectorySucceeded",
        timeout=2,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.ListDirectory",
        ["//"],
        timeout=5,
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.ListDirectoryStarted",
        timeout=2,
    )
    listed_event = fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.DirectoryListingSubdir",
        timeout=5,
    )

    # `.lower()` needed because fatfs is case-insensitive and returns uppercase names
    assert listed_event.args[1].val.lower() == "test_dir"

    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.ListDirectorySucceeded",
        timeout=5,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
        timeout=2,
    )


def test_remove_file_missing_file(fprime_test_api):
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        ["/definitely_missing_test_file", True],
        timeout=2,
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileRemoveError",
        timeout=2,
    )


def test_file_uplink(fprime_test_api):
    destination = "/test_uplink.bin"
    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(b"file uplink integration test")
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, destination, timeout=1
        )


def test_file_size(fprime_test_api):
    payload = b"file-size-check"
    destination = "/sfs.bin"

    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(payload)
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, destination, timeout=5
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.FileSize",
        [destination],
        timeout=2,
    )
    event = fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileSizeSucceeded",
        timeout=2,
    )
    assert event.args[1].val == len(payload)

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [destination, True],
        timeout=2,
    )


def test_move_file(fprime_test_api):
    payload = b"move-file-check"
    source = "/smv0.bin"
    destination = "/smv1.bin"

    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(payload)
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, source, timeout=5
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.MoveFile",
        [source, destination],
        timeout=2,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.FileSize",
        [destination],
        timeout=2,
    )
    event = fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileSizeSucceeded",
        timeout=2,
    )
    assert event.args[1].val == len(payload)

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [source, True],
        timeout=2,
    )
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [destination, True],
        timeout=2,
    )


def test_append_file(fprime_test_api):
    source = "/sap0.bin"
    destination = "/sap1.bin"
    source_payload = b"src"
    destination_payload = b"destination-payload"

    with NamedTemporaryFile(mode="wb") as source_temp_file:
        source_temp_file.write(source_payload)
        source_temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            source_temp_file.name, source, timeout=5
        )

    with NamedTemporaryFile(mode="wb") as destination_temp_file:
        destination_temp_file.write(destination_payload)
        destination_temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            destination_temp_file.name, destination, timeout=5
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.AppendFile",
        [source, destination],
        timeout=2,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.FileSize",
        [destination],
        timeout=2,
    )
    event = fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileSizeSucceeded",
        timeout=2,
    )
    assert event.args[1].val == len(source_payload) + len(destination_payload)

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [source, True],
        timeout=2,
    )
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [destination, True],
        timeout=2,
    )


def test_create_directory_already_exists_fails(fprime_test_api):
    dir_name = "/tdir"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
        timeout=2,
    )

    fprime_test_api.send_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.DirectoryCreateError",
        timeout=2,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
        timeout=2,
    )


def test_remove_directory_not_empty_fails(fprime_test_api):
    dir_name = "/tne"
    file_name = "/tne/f.bin"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
        timeout=2,
    )

    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(b"x")
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, file_name, timeout=5
        )

    fprime_test_api.send_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.DirectoryRemoveError",
        timeout=2,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [file_name, True],
        timeout=2,
    )
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
        timeout=2,
    )


def test_remove_file_success(fprime_test_api):
    file_name = "/trm.bin"

    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(b"remove-me")
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, file_name, timeout=5
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [file_name, False],
        timeout=2,
    )

    fprime_test_api.send_command(
        "ReferenceDeployment.fileManager.FileSize",
        [file_name],
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileSizeError",
        timeout=2,
    )


def test_remove_file_missing_file_without_ignore_fails(fprime_test_api):
    fprime_test_api.send_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        ["/tmiss.bin", False],
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileRemoveError",
        timeout=2,
    )
