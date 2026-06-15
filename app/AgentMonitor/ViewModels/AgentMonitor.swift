import Foundation
import SwiftUI
import Combine

struct BulldogStatus: Codable {
    let status: String
    let lastCheck: Date?
    let engagedCount: Int?
    let onDutyCount: Int?
}

class AgentMonitorViewModel: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var selectedAgent: Agent?
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var error: String?
    @Published var bulldogStatus: BulldogStatus?

    private var timer: Timer?
    private let agentsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clawd/agents")
    private let registryPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clawd/agent-registry.json")
    private let bulldogPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clawd/agent-monitor/bulldog.json")

    // MARK: - Legacy Counts (for backward compatibility)

    var activeCount: Int {
        agents.filter { $0.computedStatus == .active }.count
    }

    var blockedCount: Int {
        agents.filter { $0.computedStatus == .blocked }.count
    }

    var errorCount: Int {
        agents.filter { $0.computedStatus == .error }.count
    }

    var statusSummary: String {
        "\(activeCount)/\(agents.count) Active"
    }

    // MARK: - Enhanced Agent Filtering

    var onAssignmentAgents: [Agent] {
        agents.filter { $0.isOnAssignment }
    }

    var relievedAgents: [Agent] {
        agents.filter { $0.isRelieved }
    }

    var onDutyAgents: [Agent] {
        agents.filter { $0.isOnDuty && $0.isOnAssignment }
    }

    var offDutyAgents: [Agent] {
        agents.filter { $0.isOffDuty && $0.isOnAssignment }
    }

    // MARK: - Engagement Metrics

    var engagedCount: Int {
        onDutyAgents.filter { $0.isEngaged }.count
    }

    var idleCount: Int {
        onDutyAgents.filter { $0.activityStatus == .idle }.count
    }

    var derrelictCount: Int {
        onDutyAgents.filter { $0.isDerrelict }.count
    }

    var engagementPercentage: Double {
        guard !onDutyAgents.isEmpty else { return 0 }
        return Double(engagedCount) / Double(onDutyAgents.count) * 100
    }

    var overallHealth: AgentFleetHealth {
        let onDutyCount = onDutyAgents.count
        guard onDutyCount > 0 else { return .alarm } // No agents = ALARM

        // 0% engaged = ALARM
        if engagedCount == 0 {
            return .alarm
        }

        let engagementPct = engagementPercentage

        // >= 85% engaged = HEALTHY
        if engagementPct >= 85 {
            return .healthy
        }

        // 50-85% engaged = WARNING
        if engagementPct >= 50 {
            return .warning
        }

        // < 50% engaged = CRITICAL
        return .critical
    }

    var engagementSummary: String {
        "\(engagedCount)/\(onDutyAgents.count) Engaged"
    }

    var fleetTokensPerHour: Double? {
        let rates = onDutyAgents.compactMap { $0.tokensPerHour }
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +)
    }
    
    init() {
        loadAgents()
        startTimer()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func refresh() {
        loadAgents()
    }
    
    func loadAgents() {
        isLoading = true
        
        // Load registry
        guard let registryData = try? Data(contentsOf: registryPath),
              let registry = try? JSONDecoder().decode(AgentRegistry.self, from: registryData) else {
            error = "Failed to load agent registry"
            isLoading = false
            return
        }
        
        // Load state for each agent
        var loadedAgents: [Agent] = []

        for config in registry.agents {
            let statePath = agentsDir
                .appendingPathComponent(config.alias)
                .appendingPathComponent("state.json")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970

            let state = try? decoder.decode(
                AgentState.self,
                from: Data(contentsOf: statePath)
            )

            // Check if agent already exists (to preserve message tracking)
            let existingAgent = agents.first { $0.alias == config.alias }
            let agent = existingAgent ?? Agent(config: config, state: state)

            // Update state
            agent.state = state
            agent.updateComputedStatus()
            agent.updateActivityStatus()

            // Track message changes for versioning
            let currentMessage = state?.currentAssignment ?? "Working on assigned tasks"
            if let lastMessage = agent.lastAssignmentMessage {
                if currentMessage == lastMessage {
                    // Same message - check if 5+ minutes passed to increment version
                    if let lastUpdate = agent.lastMessageUpdate {
                        let minutesSinceUpdate = Date().timeIntervalSince(lastUpdate) / 60
                        if minutesSinceUpdate >= 5 {
                            agent.messageRepeatCount += 1
                            agent.lastMessageUpdate = Date()
                        }
                    }
                } else {
                    // Different message - reset version
                    agent.lastAssignmentMessage = currentMessage
                    agent.messageRepeatCount = 1
                    agent.lastMessageUpdate = Date()
                }
            } else {
                // First time seeing this agent
                agent.lastAssignmentMessage = currentMessage
                agent.messageRepeatCount = 1
                agent.lastMessageUpdate = Date()
            }

            loadedAgents.append(agent)
        }
        
        // Sort by status priority: error > blocked > active > idle > offline
        loadedAgents.sort { a, b in
            let priority: [AgentStatus: Int] = [
                .error: 0, .blocked: 1, .active: 2, .idle: 3, .offline: 4
            ]
            return (priority[a.computedStatus] ?? 5) < (priority[b.computedStatus] ?? 5)
        }
        
        DispatchQueue.main.async {
            self.agents = loadedAgents
            self.lastUpdated = Date()
            self.isLoading = false

            // Calculate and save current bulldog status
            self.saveBulldogStatus()
        }
    }
    
    func sendInstruction(to agent: Agent, message: String) {
        let instructionsPath = agentsDir
            .appendingPathComponent(agent.alias)
            .appendingPathComponent("instructions.md")
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let content = "## Instruction [\(timestamp)]\n\n\(message)\n\n---\n\n"
        
        if let existing = try? String(contentsOf: instructionsPath) {
            try? (existing + content).write(to: instructionsPath, atomically: true, encoding: .utf8)
        } else {
            try? content.write(to: instructionsPath, atomically: true, encoding: .utf8)
        }
    }
    
    func answerQuestion(agent: Agent, questionId: String, answer: String) {
        guard var state = agent.state,
              let index = state.questions.firstIndex(where: { $0.id == questionId }) else {
            return
        }

        state.questions[index].answeredAt = Date()
        state.questions[index].answer = answer

        let statePath = agentsDir
            .appendingPathComponent(agent.alias)
            .appendingPathComponent("state.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(state) {
            try? data.write(to: statePath)
        }

        refresh()
    }

    // MARK: - Word Report Management

    func loadWordReport(for agent: Agent) -> WordReportHistory? {
        let wordReportPath = agentsDir
            .appendingPathComponent(agent.alias)
            .appendingPathComponent("word-report.md")

        guard let data = try? Data(contentsOf: wordReportPath) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(WordReportHistory.self, from: data)
    }

    func checkDerrelictStatus(for agent: Agent) -> Bool {
        guard let state = agent.state else { return false }

        // Only Off Duty agents can be derrelict
        guard state.dutyStatus == .offDuty else { return false }

        // Failed without word report = Derrelict
        if state.lastTaskStatus == .failed && state.lastWordReport == nil {
            return true
        }

        // Failed with old word report (> 1 hour ago) = Derrelict
        if state.lastTaskStatus == .failed,
           let wordReportTime = state.lastWordReport,
           Date().timeIntervalSince(wordReportTime) > 3600 {
            return true
        }

        return false
    }

    // MARK: - Agent Control Actions

    func pokeAgent(_ agent: Agent, message: String? = nil) {
        let instructionsPath = agentsDir
            .appendingPathComponent(agent.alias)
            .appendingPathComponent("instructions.md")

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let defaultMessage = "Checking in. Status update requested."
        let content = """
        ## Poke [\(timestamp)]

        \(message ?? defaultMessage)

        ---


        """

        if let existing = try? String(contentsOf: instructionsPath) {
            try? (content + existing).write(to: instructionsPath, atomically: true, encoding: .utf8)
        } else {
            try? content.write(to: instructionsPath, atomically: true, encoding: .utf8)
        }
    }

    func restartAgent(_ agent: Agent) {
        // TODO: Implement launchctl restart in Phase 8
        // For now, just poke the agent
        pokeAgent(agent, message: "Restart requested. Please reinitialize and report status.")
    }

    func archiveAgent(_ agent: Agent) {
        guard var state = agent.state else { return }

        state.assignmentStatus = .relieved

        let statePath = agentsDir
            .appendingPathComponent(agent.alias)
            .appendingPathComponent("state.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(state) {
            try? data.write(to: statePath)
        }

        refresh()
    }

    func unarchiveAgent(_ agent: Agent) {
        guard var state = agent.state else { return }

        state.assignmentStatus = .onAssignment

        let statePath = agentsDir
            .appendingPathComponent(agent.alias)
            .appendingPathComponent("state.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(state) {
            try? data.write(to: statePath)
        }

        refresh()
    }

    func changeDutyStatus(_ agent: Agent, to dutyStatus: DutyStatus) {
        guard var state = agent.state else { return }

        state.dutyStatus = dutyStatus

        let statePath = agentsDir
            .appendingPathComponent(agent.alias)
            .appendingPathComponent("state.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(state) {
            try? data.write(to: statePath)
        }

        refresh()
    }

    func loadBulldogStatus() -> BulldogStatus? {
        guard let data = try? Data(contentsOf: bulldogPath) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(BulldogStatus.self, from: data)
    }

    func saveBulldogStatus() {
        let statusString: String
        switch overallHealth {
        case .healthy:
            statusString = "ok"
        case .warning:
            statusString = "warning"
        case .critical:
            statusString = "critical"
        case .alarm:
            statusString = "alarm"
        }

        let status = BulldogStatus(
            status: statusString,
            lastCheck: Date(),
            engagedCount: engagedCount,
            onDutyCount: onDutyAgents.count
        )

        // Update the published property
        self.bulldogStatus = status

        // Write to file
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(status) {
            let dir = bulldogPath.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: bulldogPath)
        }
    }

    func triggerEmergencyAlert() {
        // Called by EscalationManager when all agents are derrelict
        // Log to console for now, will be enhanced in Phase 6
        print("🚨 EMERGENCY: All on-duty agents are derrelict!")
    }
}
