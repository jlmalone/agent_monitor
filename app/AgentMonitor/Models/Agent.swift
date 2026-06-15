import Foundation
import SwiftUI

// MARK: - Assignment Status (Lifecycle)

enum AssignmentStatus: String, Codable {
    case onAssignment  // Actively assigned to work
    case relieved      // Archived/retired (hidden from main view)
}

// MARK: - Duty Status (Availability)

enum DutyStatus: String, Codable {
    case onDuty   // Expected to be working
    case offDuty  // Waiting for cron trigger or external event
}

// MARK: - Activity Status (Real-time engagement)

enum ActivityStatus: String, Codable {
    case engaged   // Currently active (< 10 min since last activity)
    case idle      // Not active but waiting (has pending instructions)
    case completed // Finished all work, no pending instructions
    case derrelict // Failed without proper word report (Off Duty only)

    var color: Color {
        switch self {
        case .engaged: return .green
        case .idle: return .yellow
        case .completed: return .blue
        case .derrelict: return .red
        }
    }

    var symbol: String {
        switch self {
        case .engaged: return "●"
        case .idle: return "○"
        case .completed: return "✓"
        case .derrelict: return "✖"
        }
    }
}

// MARK: - Legacy Status (for backward compatibility)

enum AgentStatus: String, Codable {
    case active
    case idle
    case blocked
    case completed
    case error
    case offline

    var color: Color {
        switch self {
        case .active: return .green
        case .idle: return .yellow
        case .blocked: return .orange
        case .completed: return .blue
        case .error: return .red
        case .offline: return .gray
        }
    }

    var symbol: String {
        switch self {
        case .active: return "●"
        case .idle: return "○"
        case .blocked: return "◐"
        case .completed: return "✓"
        case .error: return "✖"
        case .offline: return "◌"
        }
    }
}

struct AgentQuestion: Codable, Identifiable {
    let id: String
    let text: String
    let audience: String?
    let askedAt: Date
    var answeredAt: Date?
    var answer: String?
    
    var isPending: Bool {
        answeredAt == nil
    }
}

struct TokenSample: Codable {
    let ts: Date
    let totalTokens: Int
}

struct AgentState: Codable {
    let alias: String
    var persona: String?
    var mandate: String?
    var currentAssignment: String?
    var progress: [String]
    var questions: [AgentQuestion]
    var status: AgentStatus  // Legacy status
    var lastActivity: Date?
    var lastReport: Date?

    // MARK: - Token Tracking

    var totalTokens: Int?
    var tokenSamples: [TokenSample]?

    // MARK: - Enhanced State Model

    var assignmentStatus: AssignmentStatus
    var dutyStatus: DutyStatus
    var lastWordReport: Date?
    var nextExpectedTrigger: Date?
    var lastTaskStatus: WordReport.TaskStatus?

    // MARK: - Computed Activity Status

    /// Check if agent has pending instructions.md file
    func hasPendingInstructions() -> Bool {
        let agentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("clawd/agents")
        let instructionsPath = agentsDir
            .appendingPathComponent(alias)
            .appendingPathComponent("instructions.md")

        guard FileManager.default.fileExists(atPath: instructionsPath.path) else {
            return false // No instructions file = no pending work
        }

        // Check if instructions are recent (< 24 hours old)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: instructionsPath.path),
              let modDate = attributes[.modificationDate] as? Date else {
            return false
        }

        let hoursSinceModified = Date().timeIntervalSince(modDate) / 3600
        return hoursSinceModified < 24 // Instructions older than 24h are stale
    }

    /// Calculate activity status based on engagement, duty, and word reports
    /// STRICT MODE: Derrelict = Off Duty + Failed + No Word Report
    func calculateActivityStatus() -> ActivityStatus {
        // Engaged: Last activity < 10 minutes
        if let lastActivity = lastActivity {
            let minutesSinceActivity = Date().timeIntervalSince(lastActivity) / 60
            if minutesSinceActivity < 10 {
                return .engaged
            }
        }

        // Derrelict Detection (STRICT MODE - Off Duty agents only)
        if dutyStatus == .offDuty {
            // Failed without word report = Derrelict
            if lastTaskStatus == .failed && lastWordReport == nil {
                return .derrelict
            }

            // Failed with old word report (> 1 hour ago) = Derrelict
            if lastTaskStatus == .failed,
               let wordReportTime = lastWordReport,
               Date().timeIntervalSince(wordReportTime) > 3600 {
                return .derrelict
            }
        }

        // Completed: On Duty + No pending instructions + Not recently active
        if dutyStatus == .onDuty && !hasPendingInstructions() {
            // Only show as completed if they've been inactive for a while (> 30 min)
            if let lastActivity = lastActivity {
                let minutesSinceActivity = Date().timeIntervalSince(lastActivity) / 60
                if minutesSinceActivity > 30 {
                    return .completed
                }
            }
        }

        // Everything else = Idle (has pending work or waiting)
        return .idle
    }

    // MARK: - Initialization

    init(alias: String,
         persona: String? = nil,
         mandate: String? = nil,
         currentAssignment: String? = nil,
         progress: [String] = [],
         questions: [AgentQuestion] = [],
         status: AgentStatus = .offline,
         lastActivity: Date? = nil,
         lastReport: Date? = nil,
         totalTokens: Int? = nil,
         tokenSamples: [TokenSample]? = nil,
         assignmentStatus: AssignmentStatus = .onAssignment,
         dutyStatus: DutyStatus = .onDuty,
         lastWordReport: Date? = nil,
         nextExpectedTrigger: Date? = nil,
         lastTaskStatus: WordReport.TaskStatus? = nil) {
        self.alias = alias
        self.persona = persona
        self.mandate = mandate
        self.currentAssignment = currentAssignment
        self.progress = progress
        self.questions = questions
        self.status = status
        self.lastActivity = lastActivity
        self.lastReport = lastReport
        self.totalTokens = totalTokens
        self.tokenSamples = tokenSamples
        self.assignmentStatus = assignmentStatus
        self.dutyStatus = dutyStatus
        self.lastWordReport = lastWordReport
        self.nextExpectedTrigger = nextExpectedTrigger
        self.lastTaskStatus = lastTaskStatus
    }
}

struct AgentConfig: Codable, Identifiable {
    let id: String
    let alias: String
    let persona: String?
    let mandate: String?
    let workDir: String
    let port: Int?
    let enabled: Bool
}

struct AgentRegistry: Codable {
    let version: String
    let agents: [AgentConfig]
}

class Agent: ObservableObject, Identifiable {
    let config: AgentConfig
    @Published var state: AgentState?
    @Published var computedStatus: AgentStatus = .offline
    @Published var activityStatus: ActivityStatus = .idle
    @Published var wordReportHistory: WordReportHistory = WordReportHistory()

    // Message tracking for version increments
    @Published var lastAssignmentMessage: String?
    @Published var lastMessageUpdate: Date?
    @Published var messageRepeatCount: Int = 0

    var id: String { config.id }
    var alias: String { config.alias }

    // MARK: - Computed Properties

    var isOnAssignment: Bool {
        state?.assignmentStatus == .onAssignment
    }

    var isRelieved: Bool {
        state?.assignmentStatus == .relieved
    }

    var isOnDuty: Bool {
        state?.dutyStatus == .onDuty
    }

    var isOffDuty: Bool {
        state?.dutyStatus == .offDuty
    }

    var isEngaged: Bool {
        activityStatus == .engaged
    }

    var isDerrelict: Bool {
        activityStatus == .derrelict
    }

    var pendingQuestionsCount: Int {
        state?.questions.filter { $0.isPending }.count ?? 0
    }

    var tokensPerHour: Double? {
        guard let samples = state?.tokenSamples, samples.count >= 2 else {
            return nil
        }
        let now = Date()
        let windowStart = now.addingTimeInterval(-3600)
        let recent = samples.filter { $0.ts >= windowStart }.sorted { $0.ts < $1.ts }
        guard let first = recent.first, let last = recent.last, last.totalTokens >= first.totalTokens else {
            return nil
        }
        let elapsed = last.ts.timeIntervalSince(first.ts) / 3600
        guard elapsed > 0 else { return nil }
        return Double(last.totalTokens - first.totalTokens) / elapsed
    }

    // MARK: - Focus Summary & Versioning

    var focusSummary: String {
        let baseMessage = state?.currentAssignment ?? "Working on assigned tasks"

        // Add version number if message repeated
        if messageRepeatCount > 1 {
            return "\(messageRepeatCount). \(baseMessage)"
        }

        return baseMessage
    }

    var isMessageStale: Bool {
        guard let lastUpdate = lastMessageUpdate else { return true }
        let minutesSinceUpdate = Date().timeIntervalSince(lastUpdate) / 60
        return minutesSinceUpdate >= 7
    }

    var statusColor: Color {
        if isMessageStale {
            return .red // Stale message = red
        }
        return activityStatus.color
    }

    // MARK: - Initialization

    init(config: AgentConfig, state: AgentState? = nil) {
        self.config = config
        self.state = state
        updateComputedStatus()
        updateActivityStatus()
    }

    // MARK: - Status Updates

    func updateComputedStatus() {
        guard let state = state else {
            computedStatus = .offline
            return
        }

        // Priority: error > blocked > completed > active > idle > offline
        if state.status == .error {
            computedStatus = .error
            return
        }
        if state.status == .blocked {
            computedStatus = .blocked
            return
        }
        if state.status == .completed {
            computedStatus = .completed
            return
        }

        let hasQuestions = state.questions.contains { $0.isPending }
        if hasQuestions {
            computedStatus = .blocked
            return
        }

        guard let lastActivity = state.lastActivity else {
            computedStatus = .idle
            return
        }

        let minutesSinceActivity = Date().timeIntervalSince(lastActivity) / 60
        if minutesSinceActivity > 10 {
            computedStatus = .idle
        } else {
            computedStatus = .active
        }
    }

    func updateActivityStatus() {
        guard let state = state else {
            activityStatus = .idle
            return
        }

        activityStatus = state.calculateActivityStatus()
    }

    func refresh() {
        updateComputedStatus()
        updateActivityStatus()
    }
}
