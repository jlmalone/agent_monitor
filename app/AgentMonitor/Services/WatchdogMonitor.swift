import Foundation
import SwiftUI

struct WatchdogStatus: Codable {
    let isLoaded: Bool
    let lastRun: Date?
    let lastSuccess: Bool?
    let consecutiveFailures: Int

    var statusText: String {
        if !isLoaded {
            return "Not Running"
        }

        if let lastRun = lastRun {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let timeAgo = formatter.localizedString(for: lastRun, relativeTo: Date())

            if let success = lastSuccess {
                return success ? "✅ \(timeAgo)" : "❌ \(timeAgo)"
            }
            return "⏱️ \(timeAgo)"
        }

        return "Starting..."
    }

    var health: WatchdogHealth {
        if !isLoaded {
            return .notRunning
        }

        if consecutiveFailures >= 3 {
            return .critical
        }

        if consecutiveFailures >= 1 {
            return .warning
        }

        return .healthy
    }
}

enum WatchdogHealth {
    case healthy
    case warning
    case critical
    case notRunning

    var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        case .notRunning: return .gray
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        case .critical: return "xmark.shield.fill"
        case .notRunning: return "shield.slash.fill"
        }
    }
}

class WatchdogMonitor: ObservableObject {
    @Published var status: WatchdogStatus
    @Published var error: String?

    private var timer: Timer?
    private let launchdLabel = "com.agentmonitor.clawdbot-watchdog"
    private let logPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/AgentMonitor/clawdbot-watchdog.log")

    static let shared = WatchdogMonitor()

    private init() {
        self.status = WatchdogStatus(
            isLoaded: false,
            lastRun: nil,
            lastSuccess: nil,
            consecutiveFailures: 0
        )
    }

    // MARK: - Lifecycle

    func start() {
        // Ensure watchdog is loaded
        Task {
            await ensureWatchdogLoaded()
            await checkStatus()
        }

        // Check every 10 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task {
                await self?.checkStatus()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Watchdog Control

    @MainActor
    func ensureWatchdogLoaded() async {
        let isLoaded = await checkIfLoaded()

        if !isLoaded {
            print("Watchdog not loaded - loading now...")
            await loadWatchdog()
        }
    }

    @MainActor
    func loadWatchdog() async {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchdLabel).plist")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath.path]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                print("✅ Watchdog loaded successfully")
            } else {
                error = "Failed to load watchdog (exit code: \(process.terminationStatus))"
            }
        } catch {
            self.error = "Failed to load watchdog: \(error.localizedDescription)"
        }

        await checkStatus()
    }

    @MainActor
    func restartWatchdog() async {
        await unloadWatchdog()
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await loadWatchdog()
    }

    @MainActor
    func unloadWatchdog() async {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchdLabel).plist")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            self.error = "Failed to unload watchdog: \(error.localizedDescription)"
        }
    }

    // MARK: - Status Checking

    @MainActor
    func checkStatus() async {
        let isLoaded = await checkIfLoaded()
        let (lastRun, lastSuccess, failures) = parseLogFile()

        status = WatchdogStatus(
            isLoaded: isLoaded,
            lastRun: lastRun,
            lastSuccess: lastSuccess,
            consecutiveFailures: failures
        )
    }

    private func checkIfLoaded() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return output.contains(launchdLabel)
        } catch {
            return false
        }
    }

    private func parseLogFile() -> (lastRun: Date?, lastSuccess: Bool?, consecutiveFailures: Int) {
        guard FileManager.default.fileExists(atPath: logPath.path) else {
            return (nil, nil, 0)
        }

        do {
            let content = try String(contentsOf: logPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard !lines.isEmpty else {
                return (nil, nil, 0)
            }

            // Parse last run timestamp
            var lastRun: Date?
            if let lastLine = lines.last,
               let timestampMatch = lastLine.range(of: #"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]"#, options: .regularExpression) {
                let timestamp = String(lastLine[timestampMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                lastRun = formatter.date(from: timestamp)
            }

            // Parse last success/failure
            var lastSuccess: Bool?
            var consecutiveFailures = 0

            for line in lines.reversed() {
                if line.contains("✅ Clawdbot is healthy") || line.contains("✅ Clawdbot successfully resurrected") {
                    if lastSuccess == nil {
                        lastSuccess = true
                    }
                    break
                } else if line.contains("❌") {
                    if lastSuccess == nil {
                        lastSuccess = false
                    }
                    consecutiveFailures += 1
                } else if line.contains("=== Clawdbot Watchdog Check Started ===") {
                    // New check cycle - stop counting
                    if consecutiveFailures > 0 {
                        break
                    }
                }
            }

            return (lastRun, lastSuccess, consecutiveFailures)
        } catch {
            return (nil, nil, 0)
        }
    }
}
