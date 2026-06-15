import SwiftUI

// MARK: - Engagement Header

struct EngagementHeaderView: View {
    let engagementPercentage: Double
    let engagedCount: Int
    let totalOnDutyCount: Int
    let health: AgentFleetHealth
    let lastUpdated: Date?
    let fleetTokensPerHour: Double?
    let bulldogStatus: BulldogStatus?
    let watchdogStatus: WatchdogStatus

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Engagement icon
                EngagementIconView(
                    engagementPercentage: engagementPercentage,
                    health: health,
                    showPercentage: false
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent Monitor")
                        .font(.headline)

                    Text("\(engagedCount)/\(totalOnDutyCount) Engaged")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(health.color)

                    if let tokens = fleetTokensPerHour {
                        Text("Velocity: \(Int(tokens))/h")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Velocity: —")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Percentage display
                Text("\(Int(engagementPercentage))%")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(health.color)
            }

            // Last updated timestamp
            if let lastUpdated = lastUpdated {
                HStack {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            if let bulldog = bulldogStatus {
                HStack {
                    let statusText = bulldog.status.uppercased()
                    Text("Bulldog: \(statusText)")
                        .font(.caption2)
                        .foregroundColor(bulldog.status == "ok" ? .secondary : .red)
                    if let lastCheck = bulldog.lastCheck {
                        Text("(\(lastCheck, style: .relative) ago)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }

            // Watchdog status
            HStack(spacing: 4) {
                Image(systemName: watchdogStatus.health.icon)
                    .font(.system(size: 10))
                    .foregroundColor(watchdogStatus.health.color)

                Text("Watchdog: \(watchdogStatus.statusText)")
                    .font(.caption2)
                    .foregroundColor(watchdogStatus.health == .healthy ? .secondary : watchdogStatus.health.color)

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Previews

#Preview("Healthy") {
    EngagementHeaderView(
        engagementPercentage: 100,
        engagedCount: 9,
        totalOnDutyCount: 9,
        health: .healthy,
        lastUpdated: Date(),
        fleetTokensPerHour: 1200,
        bulldogStatus: BulldogStatus(status: "ok", lastCheck: Date(), engagedCount: 9, onDutyCount: 9),
        watchdogStatus: WatchdogStatus(isLoaded: true, lastRun: Date(), lastSuccess: true, consecutiveFailures: 0)
    )
    .frame(width: 320)
}

#Preview("Warning") {
    EngagementHeaderView(
        engagementPercentage: 70,
        engagedCount: 7,
        totalOnDutyCount: 10,
        health: .warning,
        lastUpdated: Date(),
        fleetTokensPerHour: 850,
        bulldogStatus: BulldogStatus(status: "warning", lastCheck: Date(), engagedCount: 7, onDutyCount: 10),
        watchdogStatus: WatchdogStatus(isLoaded: true, lastRun: Date(), lastSuccess: false, consecutiveFailures: 1)
    )
    .frame(width: 320)
}

#Preview("Critical") {
    EngagementHeaderView(
        engagementPercentage: 40,
        engagedCount: 4,
        totalOnDutyCount: 10,
        health: .critical,
        lastUpdated: Date(),
        fleetTokensPerHour: 300,
        bulldogStatus: BulldogStatus(status: "critical", lastCheck: Date(), engagedCount: 4, onDutyCount: 10),
        watchdogStatus: WatchdogStatus(isLoaded: true, lastRun: Date(), lastSuccess: false, consecutiveFailures: 3)
    )
    .frame(width: 320)
}

#Preview("Alarm") {
    EngagementHeaderView(
        engagementPercentage: 0,
        engagedCount: 0,
        totalOnDutyCount: 10,
        health: .alarm,
        lastUpdated: Date(),
        fleetTokensPerHour: nil,
        bulldogStatus: BulldogStatus(status: "alarm", lastCheck: Date(), engagedCount: 0, onDutyCount: 10),
        watchdogStatus: WatchdogStatus(isLoaded: false, lastRun: nil, lastSuccess: nil, consecutiveFailures: 0)
    )
    .frame(width: 320)
}
