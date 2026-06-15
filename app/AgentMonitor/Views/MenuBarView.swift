import SwiftUI

struct MenuBarView: View {
    @ObservedObject var monitor: AgentMonitorViewModel
    @ObservedObject var watchdogMonitor: WatchdogMonitor
    var openWindow: OpenWindowAction

    @State private var onAssignmentExpanded = true
    @State private var relievedExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Engagement header
            EngagementHeaderView(
                engagementPercentage: monitor.engagementPercentage,
                engagedCount: monitor.engagedCount,
                totalOnDutyCount: monitor.onDutyAgents.count,
                health: monitor.overallHealth,
                lastUpdated: monitor.lastUpdated,
                fleetTokensPerHour: monitor.fleetTokensPerHour,
                bulldogStatus: monitor.bulldogStatus,
                watchdogStatus: watchdogMonitor.status
            )

            Divider()

            // Agent sections
            ScrollView {
                VStack(spacing: 0) {
                    // On Assignment section
                    AgentSectionView(
                        title: "On Assignment",
                        agents: monitor.onAssignmentAgents,
                        isExpanded: onAssignmentExpanded,
                        onToggle: { onAssignmentExpanded.toggle() },
                        onAgentTap: { agent in
                            monitor.selectedAgent = agent
                            openWindow(id: "agent-detail")
                        },
                        onPoke: { agent in
                            monitor.pokeAgent(agent)
                        },
                        onRestart: { agent in
                            monitor.restartAgent(agent)
                        }
                    )

                    // Relieved section (collapsed by default)
                    if !monitor.relievedAgents.isEmpty {
                        AgentSectionView(
                            title: "Relieved",
                            agents: monitor.relievedAgents,
                            isExpanded: relievedExpanded,
                            onToggle: { relievedExpanded.toggle() },
                            onAgentTap: { agent in
                                monitor.selectedAgent = agent
                                openWindow(id: "agent-detail")
                            },
                            onPoke: { agent in
                                monitor.pokeAgent(agent)
                            },
                            onRestart: { agent in
                                monitor.restartAgent(agent)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 500)

            Divider()

            // Footer buttons
            HStack {
                Button("Refresh") {
                    monitor.refresh()
                }

                Spacer()

                Button(action: {
                    Task {
                        await watchdogMonitor.restartWatchdog()
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                        Text("Watchdog")
                    }
                }
                .help("Restart clawdbot watchdog service")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(8)
        }
        .frame(width: 340)
    }
}
