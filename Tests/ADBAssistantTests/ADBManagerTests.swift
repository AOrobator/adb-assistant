import XCTest
import Combine
@testable import ADBAssistant

@MainActor
final class ADBManagerTests: XCTestCase {
    private struct FakeADB {
        let directory: URL
        private let originalPath: String
        private let originalEnv: [String: String?]

        init(script: String, env: [String: String]) throws {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let adbPath = tempDir.appendingPathComponent("adb")
            try script.write(to: adbPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([
                .posixPermissions: 0o755
            ], ofItemAtPath: adbPath.path)
            directory = tempDir

            originalPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
            var originalEnvValues: [String: String?] = [:]
            for (key, value) in env {
                originalEnvValues[key] = ProcessInfo.processInfo.environment[key]
                setenv(key, value, 1)
            }
            originalEnv = originalEnvValues

            setenv("PATH", "\(tempDir.path):\(originalPath)", 1)
        }

        func cleanup() {
            setenv("PATH", originalPath, 1)
            for (key, value) in originalEnv {
                if let value {
                    setenv(key, value, 1)
                } else {
                    unsetenv(key)
                }
            }
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func withFakeADB(env: [String: String] = [:], perform: () async throws -> Void) async throws {
        let script = """
        #!/bin/bash
        cmd="$1"
        if [[ "$cmd" == "devices" ]]; then
          if [[ -n "$FAKE_ADB_FAIL_DEVICES" ]]; then
            echo "devices failed" 1>&2
            exit 1
          fi
          echo "List of devices attached"
          if [[ -n "$FAKE_ADB_DEVICES" ]]; then
            printf "%b" "$FAKE_ADB_DEVICES"
          fi
          exit 0
        fi

        if [[ "$cmd" == "-s" ]]; then
          serial="$2"
          shift 2
          sub="$1"
          shift
          if [[ "$sub" == "logcat" ]]; then
            if [[ "$1" == "-c" ]]; then
              exit 0
            fi
            if [[ -n "$FAKE_ADB_LOGCAT_STDERR" ]]; then
              printf "%b" "$FAKE_ADB_LOGCAT_STDERR" 1>&2
            fi
            if [[ -n "$FAKE_ADB_LOGCAT" ]]; then
              printf "%b" "$FAKE_ADB_LOGCAT"
            fi
            if [[ -n "$FAKE_ADB_LOGCAT_SLEEP" ]]; then
              sleep "$FAKE_ADB_LOGCAT_SLEEP"
            fi
            exit 0
          elif [[ "$sub" == "shell" ]]; then
            if [[ "$1" == "pidof" ]]; then
              printf "%b" "${FAKE_ADB_PIDOF:-}"
              exit 0
            elif [[ "$1" == "pm" && "$2" == "list" && "$3" == "packages" ]]; then
              printf "%b" "${FAKE_ADB_PACKAGES:-}"
              exit 0
            fi
          fi
        fi

        echo "unsupported command" 1>&2
        exit 1
        """

        let fake = try FakeADB(script: script, env: env)
        defer { fake.cleanup() }
        try await perform()
    }

    func testListDevicesParsesDevices() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_DEVICES": "serial1 device product:sdk_gphone_arm64 model:Pixel_7 device:emu\nserial2 offline\n"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            let devices = try await manager.listDevices()
            XCTAssertEqual(devices.count, 2)
            XCTAssertEqual(devices.first?.model, "Pixel_7")
            XCTAssertEqual(devices.last?.status, .offline)
        }
    }

    func testRefreshDevicesWithAutoSelect() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_DEVICES": "serial1 device model:Pixel_8\n"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            manager.isConnected = true
            await manager.refreshDevicesWithAutoSelect()
            XCTAssertEqual(manager.selectedDevice?.serial, "serial1")
        }
    }

    func testRefreshDevicesWithAutoSelectHandlesDisconnectedSelection() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_DEVICES": "serial2 device model:Pixel_9\n"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            manager.isConnected = true
            manager.selectedDevice = Device(serial: "missing", model: nil, status: .connected)
            await manager.refreshDevicesWithAutoSelect()
            XCTAssertEqual(manager.selectedDevice?.serial, "serial2")
        }
    }

    func testRefreshDevicesWithAutoSelectErrorSetsConnectionError() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_FAIL_DEVICES": "1"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            await manager.refreshDevicesWithAutoSelect()
            XCTAssertNotNil(manager.connectionError)
        }
    }

    func testStartLogcatStreamsEntriesAndDisconnects() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_DEVICES": "serial1 device\n",
            "FAKE_ADB_LOGCAT": "01-28 15:42:01.234  1234  5678 D Tag: Hello\n--------- beginning of main\n"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            manager.selectedDevice = Device(serial: "serial1", model: nil, status: .connected)

            let expectation = XCTestExpectation(description: "Received log entries")
            var received: [LogEntry] = []
            let cancellable = manager.logStream
                .sink { entries in
                    received.append(contentsOf: entries)
                    if received.count >= 2 {
                        expectation.fulfill()
                    }
                }

            try await manager.startLogcat()
            XCTAssertTrue(manager.isConnected)
            await fulfillment(of: [expectation], timeout: 1.0)
            XCTAssertEqual(received.count, 2)

            try? await Task.sleep(nanoseconds: 600_000_000)
            XCTAssertFalse(manager.isConnected)

            manager.stopLogcat()
            cancellable.cancel()
        }
    }

    func testStartLogcatWithFilter() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_DEVICES": "serial1 device\n",
            "FAKE_ADB_LOGCAT": "01-28 15:42:01.234  1234  5678 I Tag: Filtered\n"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            manager.selectedDevice = Device(serial: "serial1", model: nil, status: .connected)
            try await manager.startLogcat(filter: "MyFilter")
            manager.stopLogcat()
        }
    }

    func testStartLogcatWithoutDeviceThrows() async {
        let manager = ADBManager(autoRefresh: false)
        do {
            try await manager.startLogcat()
            XCTFail("Expected noDeviceSelected error")
        } catch let error as ADBError {
            if case .noDeviceSelected = error {
                // expected
            } else {
                XCTFail("Unexpected ADBError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClearLogsGetPIDAndListPackages() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_DEVICES": "serial1 device\n",
            "FAKE_ADB_PIDOF": "4242\n",
            "FAKE_ADB_PACKAGES": "package:com.example.app\npackage:com.test.app\n"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            manager.selectedDevice = Device(serial: "serial1", model: nil, status: .connected)
            try await manager.clearLogs()
            let pid = try await manager.getPID(for: "com.example.app")
            XCTAssertEqual(pid, 4242)
            let packages = try await manager.listPackages()
            XCTAssertEqual(packages, ["com.example.app", "com.test.app"])
        }
    }

    func testGetPIDInvalidReturnsNil() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_DEVICES": "serial1 device\n",
            "FAKE_ADB_PIDOF": "notanint\n"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            manager.selectedDevice = Device(serial: "serial1", model: nil, status: .connected)
            let pid = try await manager.getPID(for: "com.example.app")
            XCTAssertNil(pid)
        }
    }

    func testLogcatErrorPipeSetsConnectionError() async throws {
        try await withFakeADB(env: [
            "FAKE_ADB_DEVICES": "serial1 device\n",
            "FAKE_ADB_LOGCAT_STDERR": "logcat error\n",
            "FAKE_ADB_LOGCAT_SLEEP": "0.2"
        ]) {
            let manager = ADBManager(autoRefresh: false)
            manager.selectedDevice = Device(serial: "serial1", model: nil, status: .connected)
            try await manager.startLogcat()
            let deadline = Date().addingTimeInterval(1.0)
            while manager.connectionError == nil && Date() < deadline {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            XCTAssertEqual(manager.connectionError?.trimmingCharacters(in: .whitespacesAndNewlines), "logcat error")
            manager.stopLogcat()
        }
    }

    func testADBErrorDescriptions() {
        XCTAssertEqual(ADBError.noDeviceSelected.errorDescription, "No device selected")
        XCTAssertEqual(ADBError.commandFailed("oops").errorDescription, "ADB command failed: oops")
        XCTAssertEqual(ADBError.notInstalled.errorDescription, "ADB is not installed or not in PATH")
    }
}
