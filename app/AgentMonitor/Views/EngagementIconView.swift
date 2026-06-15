import SwiftUI

// MARK: - Overall Health State

enum AgentFleetHealth {
    case healthy      // ≥85% engaged
    case warning      // 15-50% derrelict
    case critical     // 50%+ derrelict
    case alarm        // ALL derrelict

    var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .alarm: return .red
        }
    }

    var shouldPulse: Bool {
        self == .alarm
    }
}

// MARK: - Engagement Icon View

struct EngagementIconView: View {
    let engagementPercentage: Double
    let health: AgentFleetHealth
    let showPercentage: Bool

    @State private var pulseAnimation = false

    init(engagementPercentage: Double, health: AgentFleetHealth, showPercentage: Bool = true) {
        self.engagementPercentage = engagementPercentage
        self.health = health
        self.showPercentage = showPercentage
    }

    var body: some View {
        ZStack {
            // Skull at 0% engagement
            if engagementPercentage == 0 {
                Image(systemName: "skull.fill")
                    .font(.system(size: 16))
                    .foregroundColor(health.color)
                    .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                    .opacity(pulseAnimation ? 0.8 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                    .onAppear {
                        pulseAnimation = true
                    }
            } else if health.shouldPulse {
                // Alarm state: pulsing triangle
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(health.color)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.7 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                    .onAppear {
                        pulseAnimation = true
                    }
            } else {
                // Smiley icons based on health
                let iconName: String = {
                    switch health {
                    case .healthy: return "face.smiling.fill"      // 😊 Happy
                    case .warning: return "face.dashed.fill"       // 😐 Neutral
                    case .critical: return "face.frowning.fill"    // ☹️ Sad
                    case .alarm: return "exclamationmark.triangle.fill"
                    }
                }()

                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(health.color)
            }

            // Percentage badge (optional)
            if showPercentage {
                Text("\(Int(engagementPercentage))%")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .offset(x: 8, y: 8)
            }
        }
    }
}

// MARK: - Menu Bar Status Icon

struct MenuBarStatusIcon: View {
    let engagementPercentage: Double
    let engagedCount: Int
    let totalOnDutyCount: Int
    let health: AgentFleetHealth

    var body: some View {
        HStack(spacing: 4) {
            EngagementIconView(
                engagementPercentage: engagementPercentage,
                health: health,
                showPercentage: false
            )

            Text("\(engagedCount)/\(totalOnDutyCount)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(health.color)
        }
    }
}

// MARK: - Preview

#Preview("Healthy") {
    EngagementIconView(
        engagementPercentage: 100,
        health: .healthy
    )
    .padding()
}

#Preview("Warning") {
    EngagementIconView(
        engagementPercentage: 70,
        health: .warning
    )
    .padding()
}

#Preview("Critical") {
    EngagementIconView(
        engagementPercentage: 40,
        health: .critical
    )
    .padding()
}

#Preview("Alarm") {
    EngagementIconView(
        engagementPercentage: 0,
        health: .alarm
    )
    .padding()
}

#Preview("Menu Bar") {
    MenuBarStatusIcon(
        engagementPercentage: 85,
        engagedCount: 8,
        totalOnDutyCount: 10,
        health: .healthy
    )
    .padding()
}
