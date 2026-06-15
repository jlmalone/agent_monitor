import SwiftUI

struct AgentDetailView: View {
    @ObservedObject var agent: Agent
    @ObservedObject var monitor: AgentMonitorViewModel
    @State private var instruction = ""
    @State private var answerText = ""
    @State private var selectedQuestion: AgentQuestion?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Button(action: { 
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                Text(agent.alias.uppercased())
                    .font(.headline)
                Spacer()
                Text(agent.computedStatus.symbol)
                    .foregroundColor(agent.computedStatus.color)
            }
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Persona
                    SectionView(title: "PERSONA") {
                        Text(agent.config.persona ?? agent.state?.persona ?? "Not defined")
                            .font(.body)
                    }
                    
                    // Mandate
                    SectionView(title: "MANDATE") {
                        Text(agent.config.mandate ?? agent.state?.mandate ?? "Not defined")
                            .font(.body)
                    }
                    
                    // Workspace
                    SectionView(title: "WORKSPACE") {
                        Text(agent.config.workDir)
                            .font(.system(.body, design: .monospaced))
                        if let port = agent.config.port {
                            Text("Port: \(port)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Current Assignment
                    SectionView(title: "CURRENT ASSIGNMENT") {
                        Text(agent.state?.currentAssignment ?? "None")
                            .font(.body)
                    }
                    
                    // Questions
                    let pendingQuestions = agent.state?.questions.filter { $0.isPending } ?? []
                    SectionView(title: "QUESTIONS (\(pendingQuestions.count) pending)") {
                        if pendingQuestions.isEmpty {
                            Text("No pending questions")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(pendingQuestions) { question in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(question.text)
                                        .font(.body)
                                    Text("Asked: \(question.askedAt, style: .relative) ago")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        TextField("Answer...", text: $answerText)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Send") {
                                            monitor.answerQuestion(
                                                agent: agent,
                                                questionId: question.id,
                                                answer: answerText
                                            )
                                            answerText = ""
                                        }
                                        .disabled(answerText.isEmpty)
                                    }
                                }
                                .padding(8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Status Info
                    SectionView(title: "STATUS") {
                        if let rate = agent.tokensPerHour {
                            HStack {
                                Text("Velocity:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(rate))/h")
                                    .fontWeight(.medium)
                            }
                        } else {
                            HStack {
                                Text("Velocity:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("—")
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Assignment:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let state = agent.state {
                                    Text(state.assignmentStatus == .onAssignment ? "On Assignment" : "Relieved")
                                        .fontWeight(.medium)
                                }
                            }

                            HStack {
                                Text("Duty:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let state = agent.state {
                                    DutyBadgeView(dutyStatus: state.dutyStatus)
                                }
                            }

                            HStack {
                                Text("Activity:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(agent.activityStatus.symbol)
                                        .foregroundColor(agent.activityStatus.color)
                                    Text(agent.activityStatus == .engaged ? "Engaged" :
                                         agent.activityStatus == .idle ? "Idle" : "Derrelict")
                                        .fontWeight(.medium)
                                        .foregroundColor(agent.activityStatus.color)
                                }
                            }

                            if agent.isDerrelict {
                                Text("⚠ Agent is DERRELICT - Failed without word report")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Word Reports
                    SectionView(title: "WORD REPORTS") {
                        if let history = monitor.loadWordReport(for: agent),
                           let latest = history.latestReport {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Latest:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    let statusColor = latest.status == .success ? Color.green :
                                                     latest.status == .failed ? Color.red : Color.yellow
                                    Text(latest.status == .success ? "SUCCESS" :
                                         latest.status == .failed ? "FAILED" : "PARTIAL")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(statusColor)
                                }

                                Text(latest.summary)
                                    .font(.body)

                                Text("Submitted: \(latest.timestamp, style: .relative) ago")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                if let nextTrigger = latest.nextTrigger {
                                    Text("Next: \(nextTrigger, style: .relative)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        } else {
                            Text("No word reports")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }

                    // Progress
                    let progress = agent.state?.progress.suffix(10) ?? []
                    SectionView(title: "PROGRESS (last \(progress.count))") {
                        if progress.isEmpty {
                            Text("No progress entries")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(Array(progress.enumerated()), id: \.offset) { _, entry in
                                Text("• \(entry)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Instruction input
                    SectionView(title: "SEND INSTRUCTION") {
                        HStack {
                            TextField("Instruction...", text: $instruction)
                                .textFieldStyle(.roundedBorder)
                            Button("Send") {
                                monitor.sendInstruction(to: agent, message: instruction)
                                instruction = ""
                            }
                            .disabled(instruction.isEmpty)
                        }
                    }

                    // Agent Controls
                    AgentControlsView(agent: agent, monitor: monitor)
                }
            }
        }
        .padding()
        .frame(width: 450, height: 700)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
        }
    }
}
