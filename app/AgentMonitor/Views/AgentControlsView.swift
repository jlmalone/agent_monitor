import SwiftUI

// MARK: - Agent Controls (Detail View)

struct AgentControlsView: View {
    @ObservedObject var agent: Agent
    let monitor: AgentMonitorViewModel

    @State private var pokeMessage = ""
    @State private var showPokeDialog = false
    @State private var showChangeDutyDialog = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Controls")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Quick actions
            HStack(spacing: 8) {
                Button(action: { monitor.pokeAgent(agent) }) {
                    Label("Quick Poke", systemImage: "bell.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button(action: { showPokeDialog = true }) {
                    Label("Poke with Message", systemImage: "text.bubble.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            HStack(spacing: 8) {
                Button(action: { monitor.restartAgent(agent) }) {
                    Label("Restart", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button(action: { showChangeDutyDialog = true }) {
                    Label("Change Duty", systemImage: "clock.badge.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            }

            // Archive/unarchive
            if agent.isOnAssignment {
                Button(action: { monitor.archiveAgent(agent) }) {
                    Label("Archive (Relieve)", systemImage: "archivebox.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            } else {
                Button(action: { monitor.unarchiveAgent(agent) }) {
                    Label("Unarchive (Reassign)", systemImage: "arrow.up.bin.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showPokeDialog) {
            PokeDialogView(
                agent: agent,
                message: $pokeMessage,
                onSubmit: {
                    monitor.pokeAgent(agent, message: pokeMessage)
                    showPokeDialog = false
                    pokeMessage = ""
                }
            )
        }
        .sheet(isPresented: $showChangeDutyDialog) {
            ChangeDutyDialogView(
                agent: agent,
                onSubmit: { newStatus in
                    monitor.changeDutyStatus(agent, to: newStatus)
                    showChangeDutyDialog = false
                }
            )
        }
    }
}

// MARK: - Poke Dialog

struct PokeDialogView: View {
    let agent: Agent
    @Binding var message: String
    let onSubmit: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Poke \(agent.alias)")
                .font(.headline)

            TextField("Message (optional)", text: $message, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Send Poke") {
                    onSubmit()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Change Duty Dialog

struct ChangeDutyDialogView: View {
    let agent: Agent
    let onSubmit: (DutyStatus) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedStatus: DutyStatus

    init(agent: Agent, onSubmit: @escaping (DutyStatus) -> Void) {
        self.agent = agent
        self.onSubmit = onSubmit
        _selectedStatus = State(initialValue: agent.state?.dutyStatus ?? .onDuty)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Change Duty Status")
                .font(.headline)

            Text(agent.alias)
                .font(.system(.body, design: .monospaced))

            Picker("Duty Status", selection: $selectedStatus) {
                Text("On Duty").tag(DutyStatus.onDuty)
                Text("Off Duty").tag(DutyStatus.offDuty)
            }
            .pickerStyle(.radioGroup)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Change") {
                    onSubmit(selectedStatus)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Preview

#Preview {
    AgentControlsView(
        agent: Agent(
            config: AgentConfig(
                id: "test",
                alias: "test-agent",
                persona: nil,
                mandate: nil,
                workDir: "/tmp",
                port: nil,
                enabled: true
            )
        ),
        monitor: AgentMonitorViewModel()
    )
    .frame(width: 400)
}
