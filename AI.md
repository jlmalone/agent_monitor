# CLAUDE.md — Agent Monitor

This file is the operational spec for Agent Monitor CLI + app integration.

## GOALS
1) Add `am quickreport <alias> <message>`
2) Document agent monitoring protocol and CLI usage
3) Provide integration test instructions
4) Ensure UI updates reflect agent activity

## SPEC (must implement)
- `quickreport` updates:
  - `lastActivity` (ms)
  - `currentAssignment`
  - `status = "active"`
  - append `progress` (keep last 50)
  - **atomic write** to `state.json`
- Command returns **< 100ms**
- Register in CLI `index.js`

## DOCS
- Agents **must update at least every 5 minutes OR at the end of a multi‑step turn**
- Prefer **`am quickreport`** for fast, atomic updates
- `state.json` is the single source of truth used by the Agent Monitor UI
- Progress entries should be short, clear, human‑readable lines

## TEST
- Integration test script: `cli/test/integration-test.sh`
- Run it after changes; it validates quickreport and state update behavior
- Verify menu bar / app UI shows updated activity and progress (when app is running)

## DELIVERABLES
- Committed changes in this repository
- New DMG at `dist/AgentMonitor.dmg`
- Short report summary + next steps

## REFERENCE
- CLI code: `cli/`
- Agent state files: `~/clawd/agents/<alias>/state.json`
- Registry: `~/clawd/agent-registry.json`

## Agent Monitoring Protocol

### Quick Report (preferred)
```bash
am quickreport <alias> "<message>"
# Optional tokens for velocity tracking:
# am quickreport <alias> "<message>" --tokens 12345
# Optional status override:
# am quickreport <alias> "Blocked on X" --status blocked
# am quickreport <alias> "Completed X" --status completed
```
Updates `state.json` with:
- `lastActivity` (ms)
- `currentAssignment` = message
- `status = active` (or overridden via --status)
- `progress` append (keep last 50)
- `tokenSamples` (optional)

### Update Frequency
- **Every 5 minutes** during active work, **OR**
- **At the end of any multi‑step turn**

### State File Location
```
~/clawd/agents/<alias>/state.json
```

### UI Expectations
- Menu bar and Agent Monitor app should show **Engaged/Active** shortly after a quick report
- Progress entries should appear in the agent detail view
