import Foundation

/// Word report submitted by agents after task completion
/// Location: ~/clawd/agents/{alias}/word-report.md
struct WordReport: Codable, Identifiable {
    let id: String  // UUID
    let timestamp: Date
    let status: TaskStatus
    let summary: String
    let nextTrigger: Date?
    let triggerType: TriggerType?

    enum TaskStatus: String, Codable {
        case success
        case failed
        case partial
    }

    enum TriggerType: String, Codable {
        case cron
        case external
        case manual
        case dependency
    }

    var isSuccess: Bool {
        status == .success
    }

    var isFailed: Bool {
        status == .failed
    }
}

/// Container for multiple word reports
struct WordReportHistory: Codable {
    var reports: [WordReport]

    var latestReport: WordReport? {
        reports.max(by: { $0.timestamp < $1.timestamp })
    }

    var lastSuccessfulReport: WordReport? {
        reports.filter { $0.isSuccess }.max(by: { $0.timestamp < $1.timestamp })
    }

    var lastFailedReport: WordReport? {
        reports.filter { $0.isFailed }.max(by: { $0.timestamp < $1.timestamp })
    }

    init(reports: [WordReport] = []) {
        self.reports = reports
    }
}
