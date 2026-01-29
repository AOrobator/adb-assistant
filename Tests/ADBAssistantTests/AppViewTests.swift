import XCTest
import SwiftUI
import AppKit
@testable import adb_assistant
@testable import ADBAssistant

@MainActor
final class AppViewTests: XCTestCase {
    private func host<V: View>(_ view: V) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        hostingView.layoutSubtreeIfNeeded()
    }

    func testStatusBarViewHelpers() {
        XCTAssertEqual(StatusBarView.statusColor(isConnected: false, isPaused: false), .red)
        XCTAssertEqual(StatusBarView.statusColor(isConnected: true, isPaused: true), .orange)
        XCTAssertEqual(StatusBarView.statusColor(isConnected: true, isPaused: false), .green)

        XCTAssertEqual(StatusBarView.statusText(isConnected: false, isPaused: false, hasDevice: false), "No device")
        XCTAssertEqual(StatusBarView.statusText(isConnected: false, isPaused: false, hasDevice: true), "Disconnected")
        XCTAssertEqual(StatusBarView.statusText(isConnected: true, isPaused: true, hasDevice: true), "Paused")
        XCTAssertEqual(StatusBarView.statusText(isConnected: true, isPaused: false, hasDevice: true), "Streaming")

        let formatted = StatusBarView.formattedTime(Date(timeIntervalSince1970: 0))
        XCTAssertEqual(formatted.count, 8)
    }

    func testContentViewBuildFilter() {
        let filter = ContentView.buildFilter(searchText: "hello", selectedLevels: [.info, .error])
        XCTAssertEqual(filter.levels, [.info, .error])
        XCTAssertEqual(filter.searchQuery, "hello")

        let emptyFilter = ContentView.buildFilter(searchText: "", selectedLevels: [])
        XCTAssertNil(emptyFilter.searchQuery)
        XCTAssertTrue(emptyFilter.levels.isEmpty)
    }

    func testToolbarHelpers() {
        var searchText = "query"
        ToolbarView.clearSearch(&searchText)
        XCTAssertEqual(searchText, "")

        let adbManager = ADBManager(autoRefresh: false)
        let logBuffer = LogBuffer(maxSize: 10)
        ToolbarView.stopLogcat(adbManager)
        ToolbarView.startLogcat(adbManager)
        ToolbarView.clearDeviceLogs(adbManager, logBuffer)
    }

    func testDevicePickerHelpers() {
        let deviceWithModel = Device(serial: "serial123456", model: "Pixel", status: .connected)
        XCTAssertEqual(DevicePicker.deviceDisplayName(deviceWithModel), "Pixel (serial12)")
        let deviceNoModel = Device(serial: "serialABC", model: nil, status: .connected)
        XCTAssertEqual(DevicePicker.deviceDisplayName(deviceNoModel), "serialABC")

        let adbManager = ADBManager(autoRefresh: false)
        let logBuffer = LogBuffer(maxSize: 10)
        let picker = DevicePicker()
        let selectAction = picker.selectDeviceAction(device: deviceNoModel, adbManager: adbManager, logBuffer: logBuffer)
        selectAction()
        XCTAssertEqual(adbManager.selectedDevice?.serial, "serialABC")
    }

    func testLevelFilterToggleAction() {
        var selected: Set<LogLevel> = [.info]
        let view = LevelFilterView(selectedLevels: Binding(
            get: { selected },
            set: { selected = $0 }
        ))

        let toggle = view.toggleLevelAction(level: .debug)
        toggle()
        XCTAssertTrue(selected.contains(.debug))

        let toggleInfo = view.toggleLevelAction(level: .info)
        toggleInfo()
        XCTAssertFalse(selected.contains(.info))
    }

    func testLogListContentHandlers() async {
        let viewModel = LogListViewModel()
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            tag: "Tag",
            pid: 1,
            tid: 1,
            message: "Message",
            rawLine: ""
        )
        viewModel.seed(entries: [entry], isPaused: true, newLogCount: 2)

        var didResume = false
        let view = LogListContent(viewModel: viewModel, onResume: { didResume = true })

        var scrolledIDs: [UUID] = []
        view.handleAutoScrollToggle(true, scrollTo: { scrolledIDs.append($0) })
        XCTAssertEqual(scrolledIDs.last, entry.id)

        view.handleEntriesChanged(scrollTo: { scrolledIDs.append($0) })
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(didResume == false)

        view.handleInitialScroll(scrollTo: { scrolledIDs.append($0) })
        XCTAssertEqual(scrolledIDs.last, entry.id)

        view.handleResume()
        XCTAssertTrue(didResume)

        view.handleDragChanged()
    }

    func testLogListHelpers() {
        let entry = LogEntry(
            timestamp: Date(),
            level: .warning,
            tag: "Tag",
            pid: 1,
            tid: 1,
            message: "Message",
            rawLine: ""
        )

        let backgroundSelected = LogListContent.entryBackground(for: entry, selectedEntryID: entry.id)
        XCTAssertEqual(backgroundSelected, Color.accentColor.opacity(0.2))

        let backgroundWarning = LogListContent.entryBackground(for: entry, selectedEntryID: nil)
        XCTAssertEqual(backgroundWarning, Color.orange.opacity(0.05))

        var toggled: [UUID] = []
        let rowView = LogRowView(entry: entry, isExpanded: false, onToggleJSON: { toggled.append($0) })
        rowView.toggleJSONAction()
        XCTAssertEqual(toggled.first, entry.id)
    }

    func testHostingViews() {
        let adbManager = ADBManager(autoRefresh: false)
        let logBuffer = LogBuffer(maxSize: 10)
        let entry = LogEntry(
            timestamp: Date(),
            level: .error,
            tag: "Tag",
            pid: 1,
            tid: 1,
            message: "{\"key\":1}",
            rawLine: ""
        )
        logBuffer.append(entry)

        host(ContentView()
            .environmentObject(adbManager)
            .environmentObject(logBuffer))

        host(ToolbarView(searchText: .constant(""), selectedLevels: .constant([.info, .error]), isSearching: .constant(false))
            .environmentObject(adbManager)
            .environmentObject(logBuffer))

        host(StatusBarView()
            .environmentObject(adbManager)
            .environmentObject(logBuffer))

        host(LogListView()
            .environmentObject(logBuffer))

        host(LogRowView(entry: entry, isExpanded: true, onToggleJSON: { _ in }))
        host(LevelIndicator(level: .error))
        host(JSONView(jsonString: "{\"key\":1}"))
        host(ResumeButton(count: 3, action: {}))
    }

    func testAppCommandHelpers() {
        let app = ADBAssistantApp()
        XCTAssertEqual(app.aboutPanelOptions()[.applicationName] as? String, "ADB Assistant")
        app.clearLogs()
        app.togglePauseResume()
    }
}
