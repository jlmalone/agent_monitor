# Agent Monitor

[![macOS](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://www.apple.com/macos/)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-green.svg)](https://nodejs.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/jlmalone/agent_monitor/pulls)

Monitor and control AI agent fleets from the menu bar and command line.

## Features

- **Menu Bar App** - Native SwiftUI app with real-time status indicators
- **CLI Tool (`am`)** - Command-line interface for automation and scripting
- **Engagement Metrics** - Track agent activity, token velocity, and progress
- **Watchdog Service** - Auto-resurrection via launchd when agents go down
- **Intelligent Escalation** - Detect when agents need human attention
- **Question Handling** - Answer pending agent questions from CLI or GUI
- **Instruction System** - Send instructions to agents

## Installation

### Prerequisites

- macOS 13.0+
- Node.js 18+ (for CLI)
- Xcode 15+ (for building from source)

### Download DMG (Recommended)

Download the latest release from the [releases page](https://github.com/jlmalone/agent_monitor/releases) or [website](https://jlmalone.github.io/agent_monitor/).

### Build from Source

```bash
git clone https://github.com/jlmalone/agent_monitor.git
cd agent_monitor/app
xcodebuild -project AgentMonitor.xcodeproj -scheme AgentMonitor -configuration Release build

# Package as DMG
../scripts/package-dmg.sh Release
```

### CLI Installation

```bash
cd agent_monitor/cli
npm install
npm link  # Makes 'am' available globally
```

## Quick Start

### 1. Setup Data Directory

```bash
# Create the clawd directory structure
mkdir -p ~/clawd/agents

# Copy and customize the registry
cp agent-registry.example.json ~/clawd/agent-registry.json
# Edit ~/clawd/agent-registry.json to add your agents
```

### 2. Configure Agents

Create `~/clawd/agent-registry.json`:

```json
{
  "version": "1.0.0",
  "agents": [
    {
      "id": "unique-id",
      "alias": "myagent",
      "persona": "Description of agent role",
      "mandate": "What this agent does",
      "workDir": "~/projects/myproject",
      "enabled": true
    }
  ]
}
```

### 3. Launch

- **GUI**: Launch AgentMonitor.app from Applications
- **CLI**: Run `am list` to see all agents

## CLI Commands

| Command | Description |
|---------|-------------|
| `am list` | List all agents with status |
| `am ls` | Alias for list |
| `am status <alias>` | Detailed status for one agent |
| `am quickreport <alias> "msg"` | Update agent status (fast, atomic) |
| `am quickreport <alias> "msg" --status completed` | Mark agent as completed |
| `am quickreport <alias> "msg" --tokens 12345` | Include token count |
| `am instruct <alias> "message"` | Send instruction to agent |
| `am answer <alias> <qid> "text"` | Answer a pending question |
| `am logs <alias>` | View progress history |

## Status Colors

| Status | Color | Meaning |
|--------|-------|---------|
| Active | Green | Working, recent activity (<10min) |
| Idle | Yellow | Running but no activity >10min |
| Blocked | Orange | Has unanswered questions |
| Completed | Blue | All tasks done, awaiting instructions |
| Error | Red | Session crashed/errored |
| Offline | Gray | No session found |

## Configuration

### Agent Registry

Location: `~/clawd/agent-registry.json`

See `agent-registry.example.json` for a complete example with all options.

### Agent State Files

Each agent writes state to `~/clawd/agents/<alias>/state.json`:

```json
{
  "agent": "MYAGENT",
  "alias": "myagent",
  "status": "active",
  "currentAssignment": "Working on task X",
  "lastActivity": 1706886000000,
  "progress": ["Step 1 completed", "Step 2 in progress"],
  "questions": []
}
```

See `state.example.json` for the complete schema.

## Integration

Agent Monitor integrates with AI agent frameworks like Clawdbot. See [INTEGRATION.md](INTEGRATION.md) for:

- Watchdog setup and auto-resurrection
- Agent protocol specification
- State file format details
- CLI automation patterns

## Architecture

```
agent_monitor/
├── app/                    # SwiftUI menu bar application
│   ├── AgentMonitor.xcodeproj
│   └── AgentMonitor/
│       ├── Models/         # Data models
│       ├── Services/       # Business logic
│       ├── ViewModels/     # MVVM view models
│       ├── Views/          # SwiftUI views
│       └── Watchdog/       # Auto-resurrection
├── cli/                    # Node.js CLI tool
│   ├── src/
│   │   ├── commands/       # CLI commands
│   │   └── lib/            # Shared utilities
│   └── package.json
├── scripts/                # Build and utility scripts
├── docs/                   # GitHub Pages website
├── agent-registry.example.json
├── state.example.json
└── README.md
```

## Troubleshooting

### App won't launch
- Ensure macOS 13.0+
- Check System Settings > Privacy & Security

### CLI not found
```bash
cd cli && npm link
```

### Agents not showing
- Verify `~/clawd/agent-registry.json` exists and is valid JSON
- Check that `enabled: true` for each agent
- Ensure `~/clawd/agents/<alias>/state.json` exists

### State not updating
- Agents must update via `am quickreport` at least every 5 minutes
- Check file permissions on `~/clawd/agents/`

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

PRs welcome! Please follow existing code style and include tests for new functionality.
