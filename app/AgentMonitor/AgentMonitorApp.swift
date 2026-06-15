import SwiftUI

@main
struct AgentMonitorApp: App {
    @StateObject private var monitor = AgentMonitorViewModel()
    @StateObject private var escalationManager = EscalationManager.shared
    @StateObject private var watchdogMonitor = WatchdogMonitor.shared
    @StateObject private var watchdogInstaller = WatchdogInstaller.shared
    @State private var showInstallPrompt = false
    @Environment(\.openWindow) var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor, watchdogMonitor: watchdogMonitor, openWindow: openWindow)
                .onAppear {
                    // Set up escalation manager when app appears
                    escalationManager.setup(monitor: monitor)

                    // Check if watchdog needs installation
                    if watchdogInstaller.shouldShowInstallPrompt() {
                        showInstallPrompt = true
                    } else {
                        // Start watchdog monitor if already installed
                        watchdogMonitor.start()
                    }
                }
                .sheet(isPresented: $showInstallPrompt) {
                    WatchdogInstallPrompt(
                        installer: watchdogInstaller,
                        isPresented: $showInstallPrompt
                    )
                    .onDisappear {
                        // Start monitoring after install (or skip)
                        watchdogMonitor.start()
                    }
                }
        } label: {
            // Dynamic icon with skull at 0%
            let health = monitor.overallHealth
            let engagedCount = monitor.engagedCount
            let totalOnDuty = monitor.onDutyAgents.count

            let icon: String = {
                // Skull when 0% engaged
                if engagedCount == 0 {
                    return "skull.fill"  // 💀 Skull
                }

                switch health {
                case .healthy: return "face.smiling.fill"      // 😊 Happy
                case .warning: return "face.dashed.fill"       // 😐 Neutral
                case .critical: return "face.frowning.fill"    // ☹️ Sad
                case .alarm: return "exclamationmark.triangle.fill"  // 🚨 Alarm
                }
            }()

            HStack(spacing: 3) {
                Image(systemName: icon)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(health.color)

                Text("\(engagedCount)/\(totalOnDuty)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(health.color)
            }
        }
        .menuBarExtraStyle(.window)

        // Separate window for agent details (allows TextField focus)
        WindowGroup("Agent Details", id: "agent-detail") {
            if let agent = monitor.selectedAgent {
                AgentDetailView(agent: agent, monitor: monitor)
                    .onAppear {
                        // Bring window to front when opened
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
            } else {
                Text("No agent selected")
                    .frame(width: 400, height: 300)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 650)
        .defaultPosition(.center)

        Settings {
            SettingsView(monitor: monitor)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var monitor: AgentMonitorViewModel
    
    var body: some View {
        Form {
            Section("Connection") {
                TextField("Remote Host", text: .constant(""))
                TextField("Agents Dir", text: .constant("~/clawd/agents"))
            }
            
            Section("Refresh") {
                Picker("Interval", selection: .constant(30)) {
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
