import SwiftUI
import AppKit
import ADBAssistant

struct LogListView: View {
    @EnvironmentObject private var logBuffer: LogBuffer
    @StateObject private var viewModel = LogListViewModel()
    
    var body: some View {
        LogListContent(
            viewModel: viewModel,
            onResume: {
                logBuffer.resume()
            }
        )
        .onAppear {
            viewModel.bind(to: logBuffer)
        }
    }
}

struct LogTextView: NSViewRepresentable {
    let entries: [LogEntry]
    let expandedJSONEntries: Set<UUID>
    let isAutoScrollEnabled: Bool
    let isPaused: Bool
    let scrollToBottomRequest: Int
    let onToggleJSON: (UUID) -> Void
    let onUserScroll: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.usesFindBar = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 4)
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .underlineStyle: 0
        ]
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = false
            textContainer.heightTracksTextView = false
            textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textContainer.lineBreakMode = .byClipping
        }
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        context.coordinator.attach(textView: textView, scrollView: scrollView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateTextIfNeeded(
            entries: entries,
            expandedJSONEntries: expandedJSONEntries
        )

        if scrollToBottomRequest != context.coordinator.lastScrollRequest {
            context.coordinator.lastScrollRequest = scrollToBottomRequest
            context.coordinator.scrollToBottom(keepingHorizontalOffset: true)
        } else if context.coordinator.didAppendContent, isAutoScrollEnabled, !isPaused {
            context.coordinator.scrollToBottom(keepingHorizontalOffset: true)
        }
        context.coordinator.didAppendContent = false
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private static let baseFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        private static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter
        }()

        var parent: LogTextView
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?

        var lastScrollRequest: Int = 0
        var didAppendContent = false

        private var lastEntryCount = 0
        private var lastFirstID: UUID?
        private var lastLastID: UUID?
        private var lastExpandedJSONEntries: Set<UUID> = []
        private var isProgrammaticScroll = false
        private var isObserverInstalled = false

        init(_ parent: LogTextView) {
            self.parent = parent
        }

        func attach(textView: NSTextView, scrollView: NSScrollView) {
            self.textView = textView
            self.scrollView = scrollView
            installScrollObserverIfNeeded()
        }

        private func installScrollObserverIfNeeded() {
            guard let scrollView, !isObserverInstalled else { return }
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScrollNotification(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            isObserverInstalled = true
        }

        @objc private func handleScrollNotification(_ notification: Notification) {
            guard !isProgrammaticScroll else { return }
            parent.onUserScroll()
        }

        func updateTextIfNeeded(entries: [LogEntry], expandedJSONEntries: Set<UUID>) {
            guard let textView else { return }

            let firstID = entries.first?.id
            let lastID = entries.last?.id
            let shouldRebuild = expandedJSONEntries != lastExpandedJSONEntries
                || entries.count < lastEntryCount
                || firstID != lastFirstID
                || (entries.count == lastEntryCount && lastID != lastLastID)

            if shouldRebuild {
                let fullText = buildAttributedText(entries: entries, expandedJSONEntries: expandedJSONEntries)
                textView.textStorage?.setAttributedString(fullText)
                didAppendContent = entries.count > 0
            } else if entries.count > lastEntryCount {
                let newEntries = entries.suffix(entries.count - lastEntryCount)
                let appendedText = buildAttributedText(entries: Array(newEntries), expandedJSONEntries: expandedJSONEntries)
                textView.textStorage?.append(appendedText)
                didAppendContent = true
            } else {
                didAppendContent = false
            }

            lastEntryCount = entries.count
            lastFirstID = firstID
            lastLastID = lastID
            lastExpandedJSONEntries = expandedJSONEntries
            resizeTextViewToFitContent()
        }

        func scrollToBottom(keepingHorizontalOffset: Bool) {
            guard let scrollView, let documentView = scrollView.documentView else { return }
            let contentView = scrollView.contentView
            var newOrigin = contentView.bounds.origin
            newOrigin.y = max(0, documentView.bounds.height - contentView.bounds.height)
            if !keepingHorizontalOffset {
                newOrigin.x = max(0, documentView.bounds.width - contentView.bounds.width)
            }

            isProgrammaticScroll = true
            contentView.setBoundsOrigin(newOrigin)
            scrollView.reflectScrolledClipView(contentView)
            DispatchQueue.main.async { [weak self] in
                self?.isProgrammaticScroll = false
            }
        }

        private func resizeTextViewToFitContent() {
            guard let textView, let scrollView else { return }
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let inset = textView.textContainerInset
            let width = max(usedRect.width + inset.width * 2, scrollView.contentSize.width)
            let height = max(usedRect.height + inset.height * 2, scrollView.contentSize.height)
            textView.setFrameSize(NSSize(width: width, height: height))
        }

        private func buildAttributedText(entries: [LogEntry], expandedJSONEntries: Set<UUID>) -> NSAttributedString {
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: Self.baseFont,
                .foregroundColor: NSColor.textColor
            ]
            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: Self.baseFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let indicatorAttributes: [NSAttributedString.Key: Any] = [
                .font: Self.baseFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let jsonAttributes: [NSAttributedString.Key: Any] = [
                .font: Self.baseFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]

            let result = NSMutableAttributedString()
            result.beginEditing()
            for entry in entries {
                let isExpanded = expandedJSONEntries.contains(entry.id)
                let indicator = entry.containsJSON ? (isExpanded ? "v " : "> ") : "  "
                let indicatorString = NSMutableAttributedString(
                    string: indicator,
                    attributes: indicatorAttributes
                )
                if entry.containsJSON {
                    indicatorString.addAttribute(.link, value: entry.id.uuidString, range: NSRange(location: 0, length: indicatorString.length))
                }
                result.append(indicatorString)

                let levelColor = color(for: entry.level)
                let levelAttributes: [NSAttributedString.Key: Any] = [
                    .font: Self.baseFont,
                    .foregroundColor: levelColor
                ]
                result.append(NSAttributedString(string: "\(entry.level.character) ", attributes: levelAttributes))

                let timeString = Self.timeFormatter.string(from: entry.timestamp)
                result.append(NSAttributedString(string: "\(timeString) ", attributes: timeAttributes))

                let tagAttributes: [NSAttributedString.Key: Any] = [
                    .font: Self.baseFont,
                    .foregroundColor: tagColor(for: entry.tag)
                ]
                result.append(NSAttributedString(string: "\(entry.tag) ", attributes: tagAttributes))

                result.append(NSAttributedString(string: "\(entry.message)\n", attributes: baseAttributes))

                if isExpanded, let json = JSONDetector.extractJSON(from: entry.message), let prettyJSON = JSONDetector.prettyPrintJSON(json) {
                    let indented = prettyJSON
                        .split(separator: "\n", omittingEmptySubsequences: false)
                        .map { "    \($0)" }
                        .joined(separator: "\n")
                    result.append(NSAttributedString(string: "\(indented)\n", attributes: jsonAttributes))
                }
            }
            result.endEditing()
            return result
        }

        private func color(for level: LogLevel) -> NSColor {
            switch level {
            case .verbose:
                return NSColor.systemGray
            case .debug:
                return NSColor.systemBlue
            case .info:
                return NSColor.systemGreen
            case .warning:
                return NSColor.systemOrange
            case .error:
                return NSColor.systemRed
            case .fatal:
                return NSColor.systemPurple
            case .silent:
                return NSColor.textColor
            }
        }

        private func tagColor(for tag: String) -> NSColor {
            var hash = 0
            for char in tag.utf8 {
                hash = (hash &* 31) &+ Int(char)
            }

            let hue = CGFloat(abs(hash) % 360) / 360.0
            return NSColor(calibratedHue: hue, saturation: 0.7, brightness: 0.8, alpha: 1.0)
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let idString = link as? String, let id = UUID(uuidString: idString) {
                parent.onToggleJSON(id)
                return true
            }
            return false
        }
    }
}

struct LogListContent: View {
    @ObservedObject var viewModel: LogListViewModel
    let onResume: () -> Void
    @State private var expandedJSONEntries: Set<UUID> = []
    @State private var isAutoScrollEnabled = true
    @State private var scrollToBottomRequest = 0

    var body: some View {
        VStack(spacing: 0) {
            // Auto-scroll toggle
            HStack {
                Toggle("Auto-scroll", isOn: $isAutoScrollEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: isAutoScrollEnabled) { newValue in
                        handleAutoScrollToggle(newValue)
                    }

                Spacer()

                if viewModel.isPaused {
                    Button("Resume", action: handleResume)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.05))

            LogTextView(
                entries: viewModel.entries,
                expandedJSONEntries: expandedJSONEntries,
                isAutoScrollEnabled: isAutoScrollEnabled,
                isPaused: viewModel.isPaused,
                scrollToBottomRequest: scrollToBottomRequest,
                onToggleJSON: toggleJSON,
                onUserScroll: handleUserScroll
            )
            .onAppear {
                scrollToBottomRequest += 1
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isPaused && viewModel.newLogCount > 0 {
                ResumeButton(count: viewModel.newLogCount, action: handleResume)
                    .padding(.bottom, 16)
            }
        }
    }

    func toggleJSON(for entryID: UUID) {
        if expandedJSONEntries.contains(entryID) {
            expandedJSONEntries.remove(entryID)
        } else {
            expandedJSONEntries.insert(entryID)
        }
    }
    
    func handleAutoScrollToggle(_ newValue: Bool) {
        guard newValue else { return }
        scrollToBottomRequest += 1
    }
    
    func handleResume() {
        onResume()
        isAutoScrollEnabled = true
        scrollToBottomRequest += 1
    }
    
    func handleUserScroll() {
        // Detect user scrolling to disable auto-scroll
        if isAutoScrollEnabled {
            isAutoScrollEnabled = false
        }
    }
    
    static func entryBackground(for entry: LogEntry, selectedEntryID: UUID?) -> Color {
        if entry.id == selectedEntryID {
            return Color.accentColor.opacity(0.2)
        }
        switch entry.level {
        case .verbose:
            return Color.gray.opacity(0.05)
        case .debug:
            return Color.blue.opacity(0.05)
        case .info:
            return Color.green.opacity(0.05)
        case .warning:
            return Color.orange.opacity(0.05)
        case .error:
            return Color.red.opacity(0.05)
        case .fatal:
            return Color.purple.opacity(0.08)
        case .silent:
            return Color.clear
        }
    }
}

struct LogRowView: View, Equatable {
    let entry: LogEntry
    let isExpanded: Bool
    let onToggleJSON: (UUID) -> Void
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    private static var tagColorCache: [String: Color] = [:]
    
    static func == (lhs: LogRowView, rhs: LogRowView) -> Bool {
        lhs.entry.id == rhs.entry.id && lhs.isExpanded == rhs.isExpanded
    }
    
    var toggleJSONAction: () -> Void {
        { onToggleJSON(entry.id) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Level indicator
                LevelIndicator(level: entry.level)
                
                // Timestamp
                Text(formattedTime(entry.timestamp))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 88, alignment: .leading)
                
                // Tag
                Text(entry.tag)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(tagColor(for: entry.tag))
                    .frame(minWidth: 220, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: true, vertical: false)
                
                // Message
                HStack(spacing: 4) {
                    if entry.containsJSON {
                        Button(action: toggleJSONAction) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(entry.message)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, 2)
            
            // Expanded JSON view
            if isExpanded, let json = JSONDetector.extractJSON(from: entry.message) {
                JSONView(jsonString: json)
                    .padding(.leading, 200)
                    .padding(.bottom, 4)
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
    
    private func tagColor(for tag: String) -> Color {
        if let cached = Self.tagColorCache[tag] {
            return cached
        }
        
        var hash = 0
        for char in tag.utf8 {
            hash = (hash &* 31) &+ Int(char)
        }
        
        let hue = Double(abs(hash) % 360) / 360.0
        let color = Color(hue: hue, saturation: 0.7, brightness: 0.8)
        Self.tagColorCache[tag] = color
        return color
    }
}

struct LevelIndicator: View {
    let level: LogLevel
    
    var body: some View {
        Text(level.character)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .frame(width: 16, height: 16)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(3)
    }
    
    private var backgroundColor: Color {
        switch level {
        case .verbose: return Color.gray.opacity(0.2)
        case .debug: return Color.blue.opacity(0.2)
        case .info: return Color.green.opacity(0.2)
        case .warning: return Color.orange.opacity(0.3)
        case .error: return Color.red.opacity(0.3)
        case .fatal: return Color.purple.opacity(0.4)
        case .silent: return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch level {
        case .verbose: return .gray
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .fatal: return .purple
        case .silent: return .clear
        }
    }
}

struct JSONView: View {
    let jsonString: String
    
    var body: some View {
        if let prettyJSON = JSONDetector.prettyPrintJSON(jsonString) {
            Text(prettyJSON)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        } else {
            Text(jsonString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

struct ResumeButton: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("\(count) new logs")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(16)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}
