import Foundation
import SwiftUI
import Combine

// MARK: - Escalation State

enum EscalationState: String, Codable {
    case healthy
    case derrelictDetected
    case attempt1
    case attempt2
    case attempt3
    case attempt4
    case attempt5
    case attempt6
    case attempt7
    case gaveUp
    case recovered

    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .derrelictDetected: return "Derrelict Detected"
        case .attempt1: return "Attempt 1: Diagnosis"
        case .attempt2: return "Attempt 2: Alternative Fixes"
        case .attempt3: return "Attempt 3: Telegram Alert"
        case .attempt4: return "Attempt 4: WhatsApp Alert"
        case .attempt5: return "Attempt 5: Urgent Multi-Channel"
        case .attempt6: return "Attempt 6: Final Diagnostic"
        case .attempt7: return "Attempt 7: Giving Up"
        case .gaveUp: return "Gave Up"
        case .recovered: return "Recovered"
        }
    }
}

// MARK: - Escalation Manager

class EscalationManager: ObservableObject {
    static let shared = EscalationManager()

    @Published var currentState: EscalationState = .healthy
    @Published var attemptCount: Int = 0
    @Published var lastAttemptTime: Date?
    @Published var lastCheckTime: Date?
    @Published var isSnoozed: Bool = false
    @Published var snoozeUntil: Date?

    private var timer: Timer?
    private weak var monitor: AgentMonitorViewModel?
    private let notificationService = NotificationService.shared

    // Exponential backoff intervals (in seconds)
    private let backoffIntervals: [TimeInterval] = [
        0,      // Attempt 1: immediate
        600,    // Attempt 2: 10 min
        1200,   // Attempt 3: 20 min
        2400,   // Attempt 4: 40 min
        4800,   // Attempt 5: 80 min
        9600,   // Attempt 6: 160 min
        19200   // Attempt 7: 320 min
    ]

    // Escalation prompts
    private let escalationPrompts = [
        "All agents derrelict. Diagnose system health and attempt automatic recovery.",
        "Previous fix failed. Try alternative recovery strategies for agent fleet.",
        "Escalating to user. Agents still derrelict after 10 minutes. Summarize situation.",
        "Critical: All agents derrelict 30+ minutes. WhatsApp escalation. Urgent intervention needed.",
        "Severe: All agents derrelict 70+ minutes. Multi-channel urgent. What's broken?",
        "Final attempt: All agents derrelict 150+ minutes. Full system diagnostic with recommendations.",
        "Giving up: All agents derrelict 310+ minutes. Prepare incident report for manual intervention."
    ]

    private init() {}

    // MARK: - Setup

    func setup(monitor: AgentMonitorViewModel) {
        self.monitor = monitor
        startMonitoring()
        loadPersistedState()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkEscalation()
        }
        timer?.tolerance = 5 // Allow 5 second tolerance for performance
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkEscalation() {
        lastCheckTime = Date()

        // Skip if snoozed
        if let snoozeUntil = snoozeUntil, Date() < snoozeUntil {
            return
        } else if isSnoozed {
            isSnoozed = false
            snoozeUntil = nil
        }

        guard let monitor = monitor else { return }

        let derrelictCount = monitor.derrelictCount
        let onDutyCount = monitor.onDutyAgents.count

        // All agents derrelict?
        let allDerrelict = derrelictCount == onDutyCount && onDutyCount > 0

        if !allDerrelict {
            // Not all derrelict - check if we need to recover
            if currentState != .healthy && currentState != .recovered {
                recover()
            }
            return
        }

        // All derrelict - escalate
        if currentState == .healthy || currentState == .recovered {
            // New escalation
            triggerEscalation()
        } else if currentState != .gaveUp {
            // Ongoing escalation - check if next attempt due
            checkNextAttempt()
        }
    }

    // MARK: - Escalation Flow

    func triggerEscalation() {
        currentState = .attempt1
        attemptCount = 1
        lastAttemptTime = Date()

        persistState()
        executeAttempt(1)
    }

    func checkNextAttempt() {
        guard let lastAttempt = lastAttemptTime else { return }
        guard attemptCount < 7 else { return }

        let nextInterval = backoffIntervals[attemptCount]
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)

        if timeSinceLastAttempt >= nextInterval {
            escalate()
        }
    }

    func escalate() {
        attemptCount += 1
        lastAttemptTime = Date()

        switch attemptCount {
        case 1: currentState = .attempt1
        case 2: currentState = .attempt2
        case 3: currentState = .attempt3
        case 4: currentState = .attempt4
        case 5: currentState = .attempt5
        case 6: currentState = .attempt6
        case 7:
            currentState = .attempt7
            giveUp()
            return
        default: return
        }

        persistState()
        executeAttempt(attemptCount)
    }

    func executeAttempt(_ attempt: Int) {
        guard attempt > 0 && attempt <= 7 else { return }

        let prompt = escalationPrompts[attempt - 1]

        // System notification
        notificationService.sendSystemNotification(
            title: "🚨 Agent Fleet Alert (Attempt \(attempt)/7)",
            body: prompt,
            urgent: attempt >= 5
        )

        // Execute Claude CLI for diagnosis/recovery
        notificationService.executeClaude(prompt: prompt) { [weak self] output in
            guard let self = self else { return }

            if let output = output {
                print("📋 Claude response (Attempt \(attempt)):\n\(output)")
            } else {
                print("✖ Claude CLI failed for attempt \(attempt)")
            }
        }

        // Multi-channel notifications
        if attempt >= 3 {
            let message = """
            🚨 AGENT MONITOR ALERT (Attempt \(attempt)/7)

            ALL ON-DUTY AGENTS ARE DERRELICT

            Time elapsed: \(getTimeElapsed())
            Status: \(currentState.displayName)

            \(prompt)
            """

            notificationService.sendTelegram(message)
        }

        if attempt >= 4 {
            let message = """
            🚨 URGENT: AGENT FLEET DOWN (Attempt \(attempt)/7)

            ALL agents derrelict for \(getTimeElapsed())

            \(prompt)

            Immediate attention required.
            """

            notificationService.sendWhatsApp(message)
        }

        // Log escalation
        logEscalation(attempt: attempt, prompt: prompt)
    }

    func recover() {
        let wasEscalated = currentState != .healthy && currentState != .recovered
        let previousState = currentState

        currentState = .recovered
        let recoveryTime = Date()

        persistState()

        if wasEscalated {
            let message = """
            ✅ AGENT FLEET RECOVERED

            At least one agent is now engaged.
            Previous state: \(previousState.displayName)
            Recovered at: \(recoveryTime.formatted())

            Escalation has been reset.
            """

            notificationService.sendSystemNotification(
                title: "✅ Agent Fleet Recovered",
                body: message,
                urgent: false
            )

            print(message)
        }

        // Reset escalation after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            if self?.currentState == .recovered {
                self?.currentState = .healthy
                self?.attemptCount = 0
                self?.lastAttemptTime = nil
                self?.persistState()
            }
        }
    }

    func giveUp() {
        currentState = .gaveUp
        persistState()

        let finalReport = """
        🚨🚨🚨 AGENT FLEET: ALL HANDS LOST 🚨🚨🚨

        ALL ON-DUTY AGENTS REMAIN DERRELICT AFTER 7 ATTEMPTS (~10.5 HOURS)

        Escalation Timeline:
        - Attempt 1: Immediate diagnosis
        - Attempt 2: 10 min - Alternative fixes
        - Attempt 3: 30 min - Telegram alert
        - Attempt 4: 70 min - WhatsApp alert
        - Attempt 5: 150 min - Urgent multi-channel
        - Attempt 6: 310 min - Final diagnostic
        - Attempt 7: 630 min - THIS MESSAGE

        MANUAL INTERVENTION REQUIRED.

        Check ~/ios_code/agent_monitor/logs/ for details.
        """

        notificationService.sendSystemNotification(
            title: "🚨 AGENT FLEET: ALL HANDS LOST",
            body: finalReport,
            urgent: true
        )

        notificationService.sendTelegram(finalReport)
        notificationService.sendWhatsApp(finalReport)

        notificationService.executeClaude(
            prompt: "Generate incident report for agent fleet total failure after 7 escalation attempts."
        ) { output in
            if let report = output {
                print("📋 Incident Report:\n\(report)")
            }
        }

        print(finalReport)
    }

    // MARK: - User Actions

    func acknowledge() {
        currentState = .healthy
        attemptCount = 0
        lastAttemptTime = nil
        isSnoozed = false
        snoozeUntil = nil

        persistState()

        notificationService.sendSystemNotification(
            title: "Escalation Acknowledged",
            body: "Agent monitor escalation has been reset.",
            urgent: false
        )
    }

    func snooze(hours: Int) {
        isSnoozed = true
        snoozeUntil = Date().addingTimeInterval(TimeInterval(hours * 3600))

        persistState()

        notificationService.sendSystemNotification(
            title: "Escalation Snoozed",
            body: "Agent monitor alerts snoozed for \(hours) hour(s).",
            urgent: false
        )
    }

    func manualTrigger() {
        checkEscalation()
    }

    // MARK: - Persistence

    private let stateFilePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".agent-monitor/escalation-state.json")

    func persistState() {
        let state = EscalationManagerState(
            currentState: currentState,
            attemptCount: attemptCount,
            lastAttemptTime: lastAttemptTime,
            isSnoozed: isSnoozed,
            snoozeUntil: snoozeUntil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(state) {
            let dir = stateFilePath.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: stateFilePath)
        }
    }

    func loadPersistedState() {
        guard let data = try? Data(contentsOf: stateFilePath) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let state = try? decoder.decode(EscalationManagerState.self, from: data) else { return }

        currentState = state.currentState
        attemptCount = state.attemptCount
        lastAttemptTime = state.lastAttemptTime
        isSnoozed = state.isSnoozed
        snoozeUntil = state.snoozeUntil
    }

    // MARK: - Helpers

    private func getTimeElapsed() -> String {
        guard let start = lastAttemptTime else { return "unknown" }

        let elapsed = Date().timeIntervalSince(start)
        let hours = Int(elapsed / 3600)
        let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func logEscalation(attempt: Int, prompt: String) {
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("ios_code/agent_monitor/logs")

        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let logFile = logDir.appendingPathComponent("escalation.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] Attempt \(attempt): \(prompt)\n"

        if let existing = try? String(contentsOf: logFile) {
            try? (existing + entry).write(to: logFile, atomically: true, encoding: .utf8)
        } else {
            try? entry.write(to: logFile, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Persisted State Model

struct EscalationManagerState: Codable {
    let currentState: EscalationState
    let attemptCount: Int
    let lastAttemptTime: Date?
    let isSnoozed: Bool
    let snoozeUntil: Date?
}
