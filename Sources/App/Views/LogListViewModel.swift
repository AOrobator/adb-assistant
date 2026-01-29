import Combine
import Foundation
import ADBAssistant

@MainActor
final class LogListViewModel: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var newLogCount: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private var isBound = false

    func bind(to logBuffer: LogBuffer) {
        guard !isBound else { return }
        isBound = true

        entries = logBuffer.filteredEntries
        isPaused = logBuffer.isPaused
        newLogCount = logBuffer.newLogCount

        logBuffer.$filteredEntries
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] entries in
                self?.entries = entries
            }
            .store(in: &cancellables)

        logBuffer.$isPaused
            .removeDuplicates()
            .sink { [weak self] isPaused in
                self?.isPaused = isPaused
            }
            .store(in: &cancellables)

        logBuffer.$newLogCount
            .removeDuplicates()
            .sink { [weak self] newLogCount in
                self?.newLogCount = newLogCount
            }
            .store(in: &cancellables)
    }

    func seed(entries: [LogEntry], isPaused: Bool = false, newLogCount: Int = 0) {
        self.entries = entries
        self.isPaused = isPaused
        self.newLogCount = newLogCount
    }
}
