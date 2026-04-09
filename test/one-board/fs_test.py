"""
These tests require that only one board be connected to the PC. They should be run via `bft.sh`.
"""

from tempfile import NamedTemporaryFile


DEFAULT_TIMEOUT = 2
LIST_TIMEOUT = 5
UPLINK_TIMEOUT = 5


def test_create_directory_success(fprime_test_api):
    dir_name = "/test_dir"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
        timeout=DEFAULT_TIMEOUT,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
        timeout=DEFAULT_TIMEOUT,
    )


def test_create_directory_already_exists_fails(fprime_test_api):
    dir_name = "/tdir"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
        timeout=DEFAULT_TIMEOUT,
    )

    fprime_test_api.send_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.DirectoryCreateError",
        timeout=DEFAULT_TIMEOUT,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
        timeout=DEFAULT_TIMEOUT,
    )


def test_list_directory(fprime_test_api):
    dir_name = "/test_dir"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
        timeout=DEFAULT_TIMEOUT,
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.CreateDirectorySucceeded",
        timeout=DEFAULT_TIMEOUT,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.ListDirectory",
        ["//"],
        timeout=LIST_TIMEOUT,
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.ListDirectoryStarted",
        timeout=DEFAULT_TIMEOUT,
    )
    listed_event = fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.DirectoryListingSubdir",
        timeout=LIST_TIMEOUT,
    )

    # `.lower()` needed because fatfs is case-insensitive and returns uppercase names
    assert listed_event.args[1].val.lower() == "test_dir"

    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.ListDirectorySucceeded",
        timeout=LIST_TIMEOUT,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
        timeout=DEFAULT_TIMEOUT,
    )


def test_remove_file_missing_file(fprime_test_api):
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        ["/definitely_missing_test_file", True],
        timeout=DEFAULT_TIMEOUT,
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileRemoveError",
        timeout=DEFAULT_TIMEOUT,
    )


def test_file_uplink(fprime_test_api):
    destination = "/test_uplink.bin"
    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(b"file uplink integration test")
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, destination, timeout=UPLINK_TIMEOUT
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [destination, True],
        timeout=DEFAULT_TIMEOUT,
    )


def test_remove_file_success(fprime_test_api):
    file_name = "/trm.bin"

    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(b"remove-me")
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, file_name, timeout=UPLINK_TIMEOUT
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [file_name, False],
        timeout=DEFAULT_TIMEOUT,
    )

    fprime_test_api.send_command(
        "ReferenceDeployment.fileManager.FileSize",
        [file_name],
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileSizeError",
        timeout=DEFAULT_TIMEOUT,
    )


def test_file_size(fprime_test_api):
    payload = b"file-size-check"
    destination = "/sfs.bin"

    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(payload)
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, destination, timeout=UPLINK_TIMEOUT
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.FileSize",
        [destination],
        timeout=DEFAULT_TIMEOUT,
    )
    event = fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileSizeSucceeded",
        timeout=DEFAULT_TIMEOUT,
    )
    assert event.args[1].val == len(payload)

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [destination, True],
        timeout=DEFAULT_TIMEOUT,
    )


def test_move_file(fprime_test_api):
    payload = b"move-file-check"
    source = "/smv0.bin"
    destination = "/smv1.bin"

    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(payload)
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, source, timeout=UPLINK_TIMEOUT
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.MoveFile",
        [source, destination],
        timeout=DEFAULT_TIMEOUT,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.FileSize",
        [destination],
        timeout=DEFAULT_TIMEOUT,
    )
    event = fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileSizeSucceeded",
        timeout=DEFAULT_TIMEOUT,
    )
    assert event.args[1].val == len(payload)

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [source, True],
        timeout=DEFAULT_TIMEOUT,
    )
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [destination, True],
        timeout=DEFAULT_TIMEOUT,
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
            source_temp_file.name, source, timeout=UPLINK_TIMEOUT
        )

    with NamedTemporaryFile(mode="wb") as destination_temp_file:
        destination_temp_file.write(destination_payload)
        destination_temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            destination_temp_file.name, destination, timeout=UPLINK_TIMEOUT
        )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.AppendFile",
        [source, destination],
        timeout=DEFAULT_TIMEOUT,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.FileSize",
        [destination],
        timeout=DEFAULT_TIMEOUT,
    )
    event = fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.FileSizeSucceeded",
        timeout=DEFAULT_TIMEOUT,
    )
    assert event.args[1].val == len(source_payload) + len(destination_payload)

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [source, True],
        timeout=DEFAULT_TIMEOUT,
    )
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [destination, True],
        timeout=DEFAULT_TIMEOUT,
    )


def test_remove_directory_not_empty_fails(fprime_test_api):
    dir_name = "/tne"
    file_name = "/tne/f.bin"

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.CreateDirectory",
        [dir_name],
        timeout=DEFAULT_TIMEOUT,
    )

    with NamedTemporaryFile(mode="wb") as temp_file:
        temp_file.write(b"x")
        temp_file.flush()
        fprime_test_api.uplink_file_and_await_completion(
            temp_file.name, file_name, timeout=UPLINK_TIMEOUT
        )

    fprime_test_api.send_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
    )
    fprime_test_api.assert_event(
        "ReferenceDeployment.fileManager.DirectoryRemoveError",
        timeout=DEFAULT_TIMEOUT,
    )

    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveFile",
        [file_name, True],
        timeout=DEFAULT_TIMEOUT,
    )
    fprime_test_api.send_and_assert_command(
        "ReferenceDeployment.fileManager.RemoveDirectory",
        [dir_name],
        timeout=DEFAULT_TIMEOUT,
    )
