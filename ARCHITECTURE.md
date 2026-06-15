# Agent Monitor - Final Architecture

## ✅ Correct Architecture (Clawdbot Native)

```
┌─────────────────────────────────────────────────────────┐
│  Clawdbot Gateway (com.clawdbot.gateway)                │
│  Single launchd service on port 18789                   │
│                                                          │
│  Internal Agents (managed by Clawdbot):                 │
│  ├── HOT_PILATES_LIBRARIAN (numina scraper)            │
│  ├── NUMEN (numina maintainer)                          │
│  ├── VISIO (vision frontend)                            │
│  └── ... more agents defined in ~/.clawdbot/agents/    │
│                                                          │
│  Each agent writes heartbeat:                           │
│  └── ~/clawd/agents/{alias}/state.json every 5 minutes │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  Agent Monitor (Watchdog System)                        │
│  ├── Reads state files every 30s                        │
│  ├── Calculates engagement (X/Y Engaged)                │
│  ├── Detects stale agents (no activity > 10min)         │
│  ├── Escalates when agents die                          │
│  └── Can restart Clawdbot gateway if needed             │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  Dynamic Menu Bar Icon                                   │
│  🟢 ⚙️ 8/9 (89%)  ← Green gear, healthy fleet          │
│  🟡 ⚙️ 6/9 (67%)  ← Yellow, some agents derrelict       │
│  🔴 ⚙️ 3/9 (33%)  ← Red, many agents derrelict          │
│  🚨 ⚠️ 0/9 (0%)   ← Alarm, all agents dead!             │
└─────────────────────────────────────────────────────────┘
```

## 🎯 Key Components

### 1. Clawdbot Gateway (Already Running)
- **Service**: `com.clawdbot.gateway`
- **Port**: 18789
- **Manages**: All agents internally
- **launchd**: Already configured via Clawdbot setup

### 2. Clawdbot Agents (Internal to Gateway)
- Defined in `~/.clawdbot/agents/*.md`
- Run inside Clawdbot process (not separate processes)
- Write heartbeat to state files for monitoring

### 3. Agent State Files (Communication Layer)
- **Location**: `~/clawd/agents/{alias}/state.json`
- **Updated**: Every 5 minutes by Clawdbot agents
- **Format**: Matches AgentState model
- **Purpose**: Monitoring interface between Clawdbot and Agent Monitor

### 4. Agent Monitor (Watchdog)
- **Watches**: State files in `~/clawd/agents/`
- **Detects**: Stale agents, derrelict conditions
- **Alerts**: Exponential backoff escalation
- **Recovery**: Can restart Clawdbot gateway

## 📊 How It Works

### Agent Heartbeat (Clawdbot Side)
```javascript
// Inside Clawdbot agent (e.g., NUMEN)
setInterval(() => {
  const state = {
    alias: "numen",
    persona: "Numina maintainer",
    mandate: "Keep numina-web running",
    currentAssignment: "Monitoring port 4003",
    progress: ["Health check passed"],
    questions: [],
    status: "active",
    lastActivity: new Date().toISOString(), // ← Critical for monitoring
    assignmentStatus: "onAssignment",
    dutyStatus: "onDuty",
    lastWordReport: null,
    lastTaskStatus: null
  };

  fs.writeFileSync(`${HOME}/clawd/agents/numen/state.json`, JSON.stringify(state, null, 2));
}, 5 * 60 * 1000); // Every 5 minutes
```

### Agent Monitor Detection
```swift
// AgentMonitorViewModel.swift
func loadAgents() {
  for agent in registry.agents {
    let state = loadState(for: agent.alias)

    if let lastActivity = state.lastActivity {
      let minutesSinceActivity = Date().timeIntervalSince(lastActivity) / 60

      if minutesSinceActivity < 10 {
        agent.activityStatus = .engaged  // ● Green
      } else if minutesSinceActivity < 60 {
        agent.activityStatus = .idle     // ○ Yellow
      } else {
        agent.activityStatus = .derrelict // ✖ Red
      }
    }
  }

  // Update menu bar icon
  updateEngagementIcon()

  // Check for escalation
  if allOnDutyAgentsDerrelict {
    triggerEscalation()
  }
}
```

## 🛠️ CLI Commands

### Gateway Management
```bash
am gateway status       # Check if Clawdbot is running
am gateway restart      # Restart Clawdbot (restarts all agents)
am gateway start        # Start Clawdbot
am gateway stop         # Stop Clawdbot
am gateway logs         # Tail Clawdbot logs
```

### Agent Monitoring
```bash
am list                       # All agents status
am status <alias>             # Detailed agent view
am word-reports <alias>       # Agent check-in history
am check-derrelict <alias>    # Is agent dead?
```

### Agent Control
```bash
am instruct <alias> "message"   # Send instruction
am poke <alias>                 # Quick poke
am archive <alias>              # Move to Relieved
am change-duty <alias> onDuty   # Change duty status
```

## 🚨 Escalation Flow

When agents die (no heartbeat > 10 min):

1. **T+0min**: All agents stale detected
2. **T+0min**: Attempt 1 - Try `am gateway restart`
3. **T+10min**: Attempt 2 - Alternative diagnostics
4. **T+30min**: Attempt 3 - **Telegram alert** 📱
5. **T+70min**: Attempt 4 - **WhatsApp alert** 📱
6. **T+150min**: Attempt 5 - Urgent multi-channel
7. **T+310min**: Attempt 6 - Final diagnostic
8. **T+630min**: Attempt 7 - Give up, incident report

## 🎯 Menu Bar Icon Behavior

### Dynamic Color Coding
- **🟢 Green**: ≥85% agents engaged (healthy fleet)
- **🟡 Yellow**: 15-85% engaged (some issues)
- **🔴 Red**: <15% engaged (critical)
- **🚨 Pulsing Red Triangle**: ALL agents derrelict (alarm)

### Display Format
```
Icon Type    Count      Percentage   Color
─────────────────────────────────────────────
⚙️ Gear      8/9        89%          Green
⚙️ Gear      6/9        67%          Yellow
⚙️ Gear      3/9        33%          Red
⚠️ Triangle  0/9        0%           Red (pulsing)
```

## 📝 Integration Checklist

### For Each Clawdbot Agent:

1. **Add State File Writer**:
   ```javascript
   // In agent initialization
   setInterval(writeStateFile, 5 * 60 * 1000);
   ```

2. **Register in agent-registry.json**:
   ```json
   {
     "id": "agent-numen-001",
     "alias": "numen",
     "persona": "Numina maintainer",
     "mandate": "Keep numina-web running",
     "workDir": "~/WebstormProjects/numina-web",
     "port": 4003,
     "enabled": true
   }
   ```

3. **Test Monitoring**:
   ```bash
   am list | grep numen
   # Should show "● Active" with recent timestamp
   ```

## ✅ What Was Removed

### ❌ Per-Agent launchd Services
- **Removed**: Individual agent launchd plists
- **Removed**: `am service install <agent>` commands
- **Reason**: Agents run inside Clawdbot, not as separate processes

### ✅ What Was Added

- **Added**: `am gateway` commands for Clawdbot control
- **Added**: Dynamic menu bar icon (gear + percentage)
- **Added**: Clawdbot gateway monitoring
- **Added**: Matching icon (bright green gear on black)

## 🎨 Icon Design

**Style**: Matches Mythoman theming
- Bright green (#00FF00) on black (#000000)
- Gear icon with 3 agent dots inside
- Clean, bold, iconic silhouette
- 1024x1024 PNG → .icns format

**Files**:
- `app/AgentMonitor/AgentMonitor.icns`
- `app/AgentMonitor/agent_monitor_icon.png`

## 🚀 Getting Started

### 1. Test Current System
```bash
# Check Clawdbot is running
am gateway status

# Check agents
am list

# Test gateway restart
am gateway restart
```

### 2. Build Swift App
```bash
cd ~/ios_code/agent_monitor/app/AgentMonitor
xcodebuild -scheme AgentMonitor -configuration Debug
open build/Debug/AgentMonitor.app
```

### 3. Watch Menu Bar
- Menu bar icon shows fleet health
- Click to see all agents
- Engagement percentage updates every 30s

### 4. Integrate Clawdbot Agents
Add state file writers to each Clawdbot agent following the integration checklist above.

---

**Architecture Status**: ✅ Finalized and Correct

**Core Principle**: Agent Monitor watches Clawdbot agents via state files. Clawdbot manages agents internally. Monitor detects failures and can restart the gateway.
