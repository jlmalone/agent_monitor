import SwiftUI

// MARK: - Agent Section (On Assignment / Relieved)

struct AgentSectionView: View {
    let title: String
    let agents: [Agent]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onAgentTap: (Agent) -> Void
    let onPoke: (Agent) -> Void
    let onRestart: (Agent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button(action: onToggle) {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    Text("(\(agents.count))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
            }
            .buttonStyle(.plain)

            // Agent list (collapsible)
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(agents) { agent in
                        EnhancedAgentRowView(
                            agent: agent,
                            onTap: { onAgentTap(agent) },
                            onPoke: { onPoke(agent) },
                            onRestart: { onRestart(agent) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Enhanced Agent Row

struct EnhancedAgentRowView: View {
    @ObservedObject var agent: Agent
    @State private var isHovering = false

    let onTap: () -> Void
    let onPoke: () -> Void
    let onRestart: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Activity status indicator (red if stale)
                Text(agent.activityStatus.symbol)
                    .foregroundColor(agent.statusColor)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Agent alias
                        Text(agent.alias)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)

                        // Duty badge
                        if let state = agent.state {
                            DutyBadgeView(dutyStatus: state.dutyStatus)
                        }

                        // Derrelict warning
                        if agent.isDerrelict {
                            Text("DERRELICT")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(3)
                        }
                    }

                    // Focus summary with version tracking
                    Text(agent.focusSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Question indicator
                if agent.pendingQuestionsCount > 0 {
                    Text("⚠ \(agent.pendingQuestionsCount)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // Hover controls
                if isHovering {
                    HStack(spacing: 4) {
                        Button(action: onPoke) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Poke agent")

                        Button(action: onRestart) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Restart agent")
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Duty Badge

struct DutyBadgeView: View {
    let dutyStatus: DutyStatus

    var body: some View {
        Text(dutyStatus == .onDuty ? "ON DUTY" : "OFF DUTY")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(dutyStatus == .onDuty ? .white : .secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(dutyStatus == .onDuty ? Color.green : Color.gray.opacity(0.3))
            .cornerRadius(3)
    }
}

// MARK: - Previews

#Preview("On Assignment Section") {
    AgentSectionView(
        title: "On Assignment",
        agents: [],
        isExpanded: true,
        onToggle: {},
        onAgentTap: { _ in },
        onPoke: { _ in },
        onRestart: { _ in }
    )
    .frame(width: 320)
}
