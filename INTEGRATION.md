# Agent Monitor Integration Guide

This document explains how to integrate your AI agent framework (Clawdbot/Moltbot, custom agents, etc.) with Agent Monitor.

## Overview

Agent Monitor is a two-way communication system:
1. **Agents → Monitor**: Agents write state files that the monitor reads
2. **Monitor → Agents**: Monitor writes instruction files that agents read

## Directory Structure

```
~/clawd/
├── agent-registry.json         # List of all agents
├── agent-monitor/
│   └── bulldog.json           # Fleet health status (written by monitor)
└── agents/
    ├── <alias>/
    │   ├── state.json         # Agent state (written by agent)
    │   ├── instructions.md    # Instructions (written by monitor, read by agent)
    │   └── word-report.md     # Word reports (written by agent)
    └── ...
```

## 1. Agent Registry (`~/clawd/agent-registry.json`)

The registry lists all agents to be monitored. Create this file before starting Agent Monitor.

```json
{
  "version": "1.0.0",
  "agents": [
    {
      "id": "unique-id-001",
      "alias": "myagent",
      "persona": "Description of agent role",
      "mandate": "What this agent does",
      "workDir": "~/projects/myproject",
      "port": 3000,
      "enabled": true
    }
  ]
}
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier (UUID recommended) |
| `alias` | Yes | Short name, used for directory paths and CLI commands |
| `persona` | No | Description of the agent's role |
| `mandate` | No | What this agent is responsible for |
| `workDir` | No | Agent's working directory |
| `port` | No | Port number if agent runs a server |
| `enabled` | No | Set to `false` to hide from monitor |

## 2. Agent State (`~/clawd/agents/<alias>/state.json`)

Each agent must write its state to this file. The monitor reads it every 30 seconds.

```json
{
  "alias": "myagent",
  "persona": "My Agent",
  "mandate": "Process tasks",
  "status": "active",
  "currentAssignment": "Working on feature X",
  "lastActivity": 1770211323679,
  "assignmentStatus": "onAssignment",
  "dutyStatus": "onDuty",
  "progress": [
    "Started task",
    "Processing step 1",
    "Completed step 1"
  ],
  "questions": [],
  "lastTaskStatus": "success",
  "lastWordReport": null
}
```

### Critical Fields for Status Detection

| Field | Type | Description |
|-------|------|-------------|
| `lastActivity` | Integer | **CRITICAL**: Milliseconds since epoch. Must be updated every 5 minutes. |
| `status` | String | `"active"`, `"blocked"`, `"completed"`, `"idle"` |
| `assignmentStatus` | String | `"onAssignment"` or `"relieved"` |
| `dutyStatus` | String | `"onDuty"` or `"offDuty"` |

### Activity Status Calculation

Agent Monitor calculates activity status as follows:

```
ENGAGED (green):    lastActivity < 10 minutes ago AND status == "active"
COMPLETED (blue):   status == "completed" AND no pending instructions
IDLE (yellow):      lastActivity > 10 minutes OR has pending instructions
DERRELICT (red):    offDuty AND lastTaskStatus == "failed" AND no word report
```

**Important**: To stay "Engaged", your agent must update `lastActivity` at least every 10 minutes.

## 3. Status Reporting Protocol

### Quick Report (Recommended)

Use the CLI for atomic state updates:

```bash
# Basic status report (sets status to "active")
am quickreport <alias> "Working on feature X"

# With status override
am quickreport <alias> "All tasks done" --status completed
am quickreport <alias> "Waiting for API" --status blocked

# With token tracking (for velocity metrics)
am quickreport <alias> "Progress update" --tokens 12345
```

This command atomically:
- Sets `lastActivity` to current timestamp
- Sets `currentAssignment` to your message
- Sets `status` (defaults to "active")
- Appends to `progress` array (keeps last 50)
- Optionally records token count

### Manual State Write

If not using the CLI, write `state.json` directly:

```javascript
const state = {
  alias: "myagent",
  status: "active",
  currentAssignment: "Working on task",
  lastActivity: Date.now(), // Milliseconds!
  // ... other fields
};

fs.writeFileSync(
  `${HOME}/clawd/agents/myagent/state.json`,
  JSON.stringify(state, null, 2)
);
```

## 4. Instructions System

Agent Monitor can send instructions to agents via the CLI or UI.

### File Location
```
~/clawd/agents/<alias>/instructions.md
```

### Format
Instructions are appended as Markdown sections:

```markdown
## Instruction [2026-02-04T05:30:00Z]

Please check on the database connection.

---

## Instruction [2026-02-04T05:00:00Z]

Start processing batch #42.

---
```

### Agent Responsibility

Your agent should:
1. **Poll** `instructions.md` every 10 minutes (or on wake)
2. **Parse** new instructions (after timestamp you last processed)
3. **Execute** the instruction
4. **Report** via quickreport or state update
5. **Optionally** clear processed instructions

## 5. Word Reports (Optional)

Word reports provide detailed check-ins for debugging.

### File Location
```
~/clawd/agents/<alias>/word-report.md
```

### CLI Command
```bash
am word-report <alias> --status success --summary "Completed batch processing"
am word-report <alias> --status blocked --summary "Waiting for API response"
```

## 6. Watchdog Service

The Agent Monitor includes an optional watchdog that monitors Clawdbot health.

### Installation
The watchdog is installed automatically when you first launch Agent Monitor (with user consent).

### What It Does
- Runs every 5 minutes via launchd
- Checks if Clawdbot is healthy (`clawdbot health`)
- Attempts resurrection if down (`clawdbot agent --agent main --message "Resume..."`)

### Files
- Script: `~/Library/Application Support/AgentMonitor/scripts/resurrect-clawdbot.sh`
- Plist: `~/Library/LaunchAgents/com.agentmonitor.clawdbot-watchdog.plist`
- Logs: `~/Library/Logs/AgentMonitor/clawdbot-watchdog.log`

### Requirement
The watchdog requires `gtimeout` from coreutils:
```bash
brew install coreutils
```

## 7. Example Integration (Node.js)

```javascript
const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME;
const ALIAS = 'myagent';
const STATE_FILE = path.join(HOME, 'clawd/agents', ALIAS, 'state.json');
const INSTRUCTIONS_FILE = path.join(HOME, 'clawd/agents', ALIAS, 'instructions.md');

// Update state every 5 minutes
function updateState(message) {
  const state = {
    alias: ALIAS,
    status: 'active',
    currentAssignment: message,
    lastActivity: Date.now(),
    assignmentStatus: 'onAssignment',
    dutyStatus: 'onDuty',
    progress: [],
    questions: []
  };

  // Load existing progress
  try {
    const existing = JSON.parse(fs.readFileSync(STATE_FILE));
    state.progress = existing.progress || [];
  } catch {}

  // Add new progress entry (keep last 50)
  state.progress.push(message);
  state.progress = state.progress.slice(-50);

  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

// Check for instructions every 10 minutes
function checkInstructions() {
  try {
    const content = fs.readFileSync(INSTRUCTIONS_FILE, 'utf8');
    // Parse and process instructions...
  } catch {}
}

// Heartbeat loop
setInterval(() => {
  updateState('Heartbeat - still working');
}, 5 * 60 * 1000); // Every 5 minutes

setInterval(checkInstructions, 10 * 60 * 1000); // Every 10 minutes
```

## 8. CLI Reference

```bash
# List agents
am list
am ls

# Agent status
am status <alias>

# Send instruction
am instruct <alias> "Your message"

# Quick status report
am quickreport <alias> "Status message"
am quickreport <alias> "Done" --status completed
am quickreport <alias> "Blocked" --status blocked

# Word reports
am word-report <alias> --status success --summary "Done"
am word-reports <alias>

# Poke agent (send wake-up instruction)
am poke <alias>

# Change duty status
am change-duty <alias> offDuty
am change-duty <alias> onDuty

# Archive/relieve agent
am archive <alias>
```

## 9. Troubleshooting

### Agent Not Showing
- Check `~/clawd/agent-registry.json` includes the agent
- Ensure `enabled: true` or field is absent
- Verify state directory exists: `~/clawd/agents/<alias>/`

### Agent Shows "Derrelict"
- `lastActivity` hasn't been updated in 10+ minutes
- OR `dutyStatus` is "offDuty" with `lastTaskStatus: "failed"`
- Fix: Update state with current activity

### Agent Shows "Idle" When Working
- `lastActivity` timestamp is stale (>10 min old)
- Fix: Call `am quickreport <alias> "message"` more frequently

### Instructions Not Being Read
- Agent not polling `instructions.md`
- Fix: Implement 10-minute polling in your agent

### Watchdog Not Starting
- Missing `gtimeout`: `brew install coreutils`
- Check logs: `tail ~/Library/Logs/AgentMonitor/clawdbot-watchdog.log`

## 10. Summary Checklist

For agents to work with Agent Monitor:

- [ ] Register agent in `~/clawd/agent-registry.json`
- [ ] Create `~/clawd/agents/<alias>/` directory
- [ ] Write `state.json` with `lastActivity` (milliseconds)
- [ ] Update `lastActivity` every 5-10 minutes
- [ ] Poll `instructions.md` every 10 minutes
- [ ] Use `am quickreport` for easy updates
- [ ] Set `status: "completed"` when work is done
- [ ] File word reports for detailed check-ins

---

*Compatible with Agent Monitor v1.0+*
