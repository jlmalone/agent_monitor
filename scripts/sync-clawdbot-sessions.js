#!/usr/bin/env node
/**
 * Sync Clawdbot sessions to Agent Monitor state files
 * 
 * This is the BRIDGE between Clawdbot's internal session tracking
 * and the Agent Monitor app's state file format.
 * 
 * Run: node sync-clawdbot-sessions.js
 * Or with watch: node sync-clawdbot-sessions.js --watch
 */

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const HOME = process.env.HOME;
const AGENTS_DIR = path.join(HOME, 'clawd', 'agents');
const REGISTRY_PATH = path.join(HOME, 'clawd', 'agent-registry.json');

// Agent aliases to track are derived from the registry at runtime (see loadRegistry).

function getClawdbotSessions() {
  try {
    // Query Clawdbot gateway for active sessions
    const result = execSync(
      'curl -s "http://localhost:18789/api/sessions?limit=50"',
      { encoding: 'utf-8', timeout: 5000 }
    );
    return JSON.parse(result);
  } catch (e) {
    console.error('  ⚠️  Cannot reach Clawdbot gateway:', e.message);
    return null;
  }
}

function createDefaultState(alias, config) {
  const now = Date.now();
  return {
    alias: alias,
    persona: config?.persona || `${alias} agent`,
    mandate: config?.mandate || 'No mandate defined',
    currentAssignment: null,
    progress: [],
    questions: [],
    status: 'idle',
    lastActivity: null,  // Will be set to milliseconds since epoch
    lastReport: null,
    assignmentStatus: 'onAssignment',
    dutyStatus: 'onDuty',
    lastWordReport: null,
    nextExpectedTrigger: null,
    lastTaskStatus: null
  };
}

function findSessionForAgent(sessions, alias) {
  if (!sessions?.sessions) return null;
  
  // Look for session with matching label
  for (const session of sessions.sessions) {
    if (session.label === alias) {
      return session;
    }
    // Also check displayName contains the alias
    if (session.displayName?.includes(alias)) {
      return session;
    }
  }
  return null;
}

function syncAgentState(alias, session, config) {
  const stateDir = path.join(AGENTS_DIR, alias);
  const statePath = path.join(stateDir, 'state.json');
  
  // Ensure directory exists
  if (!fs.existsSync(stateDir)) {
    fs.mkdirSync(stateDir, { recursive: true });
  }
  
  // Load existing state or create new
  let state;
  if (fs.existsSync(statePath)) {
    try {
      const raw = fs.readFileSync(statePath, 'utf-8');
      state = JSON.parse(raw);
      
      // Convert ISO dates to milliseconds if needed
      if (state.lastActivity && typeof state.lastActivity === 'string') {
        state.lastActivity = new Date(state.lastActivity).getTime();
      }
      if (state.lastUpdate && typeof state.lastUpdate === 'string') {
        state.lastActivity = new Date(state.lastUpdate).getTime();
      }
    } catch (e) {
      state = createDefaultState(alias, config);
    }
  } else {
    state = createDefaultState(alias, config);
  }
  
  // Update from session if available
  const now = Date.now();
  
  if (session) {
    state.status = session.abortedLastRun ? 'error' : 'active';
    state.lastActivity = session.updatedAt || now;
    state.sessionKey = session.key;
    state.sessionId = session.sessionId;
    state.totalTokens = session.totalTokens;
  } else {
    // No active session - check how stale
    if (state.lastActivity) {
      const minutesSinceActivity = (now - state.lastActivity) / 60000;
      if (minutesSinceActivity > 30) {
        state.status = 'idle';
      }
    } else {
      state.status = 'offline';
    }
  }
  
  // Ensure required fields exist with correct types
  state.alias = alias;
  state.assignmentStatus = state.assignmentStatus || 'onAssignment';
  state.dutyStatus = state.dutyStatus || 'onDuty';
  state.progress = Array.isArray(state.progress) ? state.progress : [];
  state.questions = Array.isArray(state.questions) ? state.questions : [];
  state.persona = state.persona || config?.persona || `${alias} agent`;
  state.mandate = state.mandate || config?.mandate || 'No mandate defined';
  
  // lastActivity MUST be number (milliseconds) or null
  if (state.lastActivity && typeof state.lastActivity !== 'number') {
    const parsed = new Date(state.lastActivity).getTime();
    state.lastActivity = isNaN(parsed) ? null : parsed;
  }
  
  // Write back
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  
  return state;
}

function loadRegistry() {
  try {
    const raw = fs.readFileSync(REGISTRY_PATH, 'utf-8');
    return JSON.parse(raw);
  } catch (e) {
    console.error('  ⚠️  Cannot load agent-registry.json');
    return { agents: [] };
  }
}

function sync() {
  const timestamp = new Date().toISOString();
  console.log(`\n[${timestamp}] Syncing Clawdbot sessions to Agent Monitor...`);
  
  const sessions = getClawdbotSessions();
  const registry = loadRegistry();
  
  // Build config map and derive the list of aliases from the registry
  const configMap = {};
  const aliases = [];
  for (const agent of registry.agents) {
    if (agent.enabled === false) continue;
    configMap[agent.alias] = agent;
    aliases.push(agent.alias);
  }

  if (aliases.length === 0) {
    console.log('  ⚠️  No enabled agents in registry — nothing to sync');
    return;
  }

  // Sync each agent
  for (const alias of aliases) {
    const session = findSessionForAgent(sessions, alias);
    const config = configMap[alias];
    const state = syncAgentState(alias, session, config);
    
    const statusIcon = {
      'active': '●',
      'idle': '○',
      'blocked': '◐',
      'error': '✖',
      'offline': '◌'
    }[state.status] || '?';
    
    const lastActivityStr = state.lastActivity 
      ? `${Math.round((Date.now() - state.lastActivity) / 60000)}m ago`
      : 'never';
    
    console.log(`  ${statusIcon} ${alias.padEnd(12)} ${state.status.padEnd(8)} (last: ${lastActivityStr})`);
  }
  
  console.log('  ✓ Sync complete\n');
}

// Run immediately
sync();

// If --watch, run every 30 seconds
if (process.argv.includes('--watch')) {
  console.log('Watching for changes (Ctrl+C to stop)...');
  setInterval(sync, 30000);
}
