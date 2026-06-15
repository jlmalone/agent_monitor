import Foundation
import SwiftUI

enum WatchdogInstallError: LocalizedError {
    case resourceNotFound(String)
    case copyFailed(String)
    case permissionDenied(String)
    case dependencyMissing(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let file):
            return "Watchdog resource not found: \(file)"
        case .copyFailed(let reason):
            return "Failed to copy watchdog files: \(reason)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .dependencyMissing(let dep):
            return "Missing dependency: \(dep)"
        }
    }
}

class WatchdogInstaller: ObservableObject {
    @Published var isInstalling = false
    @Published var installProgress: String = ""
    @Published var error: String?

    static let shared = WatchdogInstaller()

    private let homeDir = FileManager.default.homeDirectoryForCurrentUser
    private let scriptDestination: URL
    private let logsDestination: URL
    private let plistDestination: URL
    private let launchdLabel = "com.agentmonitor.clawdbot-watchdog"

    private init() {
        scriptDestination = homeDir.appendingPathComponent("Library/Application Support/AgentMonitor/scripts")
        logsDestination = homeDir.appendingPathComponent("Library/Logs/AgentMonitor")
        plistDestination = homeDir.appendingPathComponent("Library/LaunchAgents")
    }

    // MARK: - Installation Check

    func isWatchdogInstalled() -> Bool {
        let scriptPath = scriptDestination.appendingPathComponent("resurrect-clawdbot.sh")
        let plistPath = plistDestination.appendingPathComponent("\(launchdLabel).plist")

        return FileManager.default.fileExists(atPath: scriptPath.path) &&
               FileManager.default.fileExists(atPath: plistPath.path)
    }

    func shouldShowInstallPrompt() -> Bool {
        // Check if this is first run or watchdog not installed
        let defaults = UserDefaults.standard
        let hasPrompted = defaults.bool(forKey: "watchdog_install_prompted")

        return !hasPrompted && !isWatchdogInstalled()
    }

    func markInstallPrompted() {
        UserDefaults.standard.set(true, forKey: "watchdog_install_prompted")
    }

    // MARK: - Installation

    @MainActor
    func installWatchdog() async throws {
        isInstalling = true
        error = nil

        // Step 1: Check dependencies
        installProgress = "Checking dependencies..."
        try await checkDependencies()

        // Step 2: Create directories
        installProgress = "Creating directories..."
        try createDirectories()

        // Step 3: Copy script from bundle
        installProgress = "Installing resurrection script..."
        try await copyScriptFromBundle()

        // Step 4: Generate plist dynamically
        installProgress = "Generating launchd service..."
        try await generatePlist()

        // Step 5: Load launchd service
        installProgress = "Loading watchdog service..."
        try await loadLaunchdService()

        // Step 6: Verify installation
        installProgress = "Verifying installation..."
        try await verifyInstallation()

        installProgress = "✅ Installation complete!"
        isInstalling = false

        // Mark as installed
        markInstallPrompted()
    }

    // MARK: - Installation Steps

    private func checkDependencies() async throws {
        // Check for gtimeout (from coreutils)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["gtimeout"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw WatchdogInstallError.dependencyMissing(
                    "gtimeout (coreutils) not found. Please install: brew install coreutils"
                )
            }
        } catch {
            throw WatchdogInstallError.dependencyMissing(
                "Failed to check for gtimeout: \(error.localizedDescription)"
            )
        }
    }

    private func createDirectories() throws {
        // Create script directory
        try FileManager.default.createDirectory(
            at: scriptDestination,
            withIntermediateDirectories: true
        )

        // Create logs directory
        try FileManager.default.createDirectory(
            at: logsDestination,
            withIntermediateDirectories: true
        )

        // LaunchAgents directory should already exist, but ensure it
        try FileManager.default.createDirectory(
            at: plistDestination,
            withIntermediateDirectories: true
        )
    }

    private func copyScriptFromBundle() async throws {
        guard let bundleScript = Bundle.main.url(
            forResource: "resurrect-clawdbot",
            withExtension: "sh"
        ) else {
            throw WatchdogInstallError.resourceNotFound("resurrect-clawdbot.sh not found in app bundle")
        }

        let destination = scriptDestination.appendingPathComponent("resurrect-clawdbot.sh")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: destination)

        // Copy from bundle
        try FileManager.default.copyItem(at: bundleScript, to: destination)

        // Make executable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", destination.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw WatchdogInstallError.copyFailed("Failed to make script executable")
        }
    }

    private func generatePlist() async throws {
        let scriptPath = scriptDestination.appendingPathComponent("resurrect-clawdbot.sh").path
        let logPath = logsDestination.appendingPathComponent("clawdbot-watchdog.log").path
        let errorLogPath = logsDestination.appendingPathComponent("clawdbot-watchdog-error.log").path

        // Build PATH with common locations for homebrew and nvm
        let pathComponents = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        // Check for nvm and add node path if found
        var finalPath = pathComponents.joined(separator: ":")
        let nvmNodePath = homeDir.appendingPathComponent(".nvm/versions/node").path
        if FileManager.default.fileExists(atPath: nvmNodePath) {
            // Find the latest node version
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: nvmNodePath),
               let latest = contents.sorted().last {
                let nodeBin = "\(nvmNodePath)/\(latest)/bin"
                finalPath = "\(nodeBin):\(finalPath)"
            }
        }

        let plistContent = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>\(launchdLabel)</string>

    <key>Comment</key>
    <string>Clawdbot Watchdog - Monitors and resurrects clawdbot when down</string>

    <key>ProgramArguments</key>
    <array>
      <string>\(scriptPath)</string>
    </array>

    <key>StartInterval</key>
    <integer>300</integer>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>

    <key>WorkingDirectory</key>
    <string>\(homeDir.path)</string>

    <key>StandardOutPath</key>
    <string>\(logPath)</string>
    <key>StandardErrorPath</key>
    <string>\(errorLogPath)</string>

    <key>EnvironmentVariables</key>
    <dict>
      <key>HOME</key>
      <string>\(homeDir.path)</string>
      <key>PATH</key>
      <string>\(finalPath)</string>
    </dict>
  </dict>
</plist>
"""

        let destination = plistDestination.appendingPathComponent("\(launchdLabel).plist")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: destination)

        // Write generated plist
        try plistContent.write(to: destination, atomically: true, encoding: .utf8)
    }

    private func loadLaunchdService() async throws {
        let plistPath = plistDestination.appendingPathComponent("\(launchdLabel).plist")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WatchdogInstallError.copyFailed("Failed to load launchd service: \(errorOutput)")
        }
    }

    private func verifyInstallation() async throws {
        // Check if launchd service is loaded
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if !output.contains(launchdLabel) {
            throw WatchdogInstallError.copyFailed("Service loaded but not found in launchctl list")
        }
    }
}

// MARK: - Installation Prompt View

struct WatchdogInstallPrompt: View {
    @ObservedObject var installer: WatchdogInstaller
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Install Clawdbot Watchdog?")
                .font(.headline)

            Text("The watchdog monitors clawdbot and automatically restarts it if it crashes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if installer.isInstalling {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(installer.installProgress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let error = installer.error {
                VStack(spacing: 8) {
                    Text("Installation Failed")
                        .font(.subheadline)
                        .foregroundColor(.red)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                HStack(spacing: 12) {
                    Button("Not Now") {
                        installer.markInstallPrompted()
                        isPresented = false
                    }

                    Button("Install") {
                        Task {
                            do {
                                try await installer.installWatchdog()
                                try? await Task.sleep(nanoseconds: 1_000_000_000) // Show success for 1 sec
                                isPresented = false
                            } catch {
                                installer.error = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}
