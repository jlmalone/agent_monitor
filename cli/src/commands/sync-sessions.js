#!/usr/bin/env node
/**
 * Sync Clawdbot sessions to agent state files
 * This bridges the gap between Clawdbot's internal session tracking
 * and the state files that `am` CLI reads.
 * 
 * Run periodically via launchd or cron.
 */

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

const AGENTS_DIR = path.join(process.env.HOME, 'clawd', 'agents');
const REGISTRY_PATH = path.join(process.env.HOME, 'clawd', 'agent-registry.json');

// Known agent labels to session key mapping
const AGENT_LABELS = [
  'visio', 'unisex', 'knowitall', 'smith', 'jackson', 
  'david', 'getherdone', 'figurine', 'numen'
];

async function getClawdbotSessions() {
  try {
    // Use clawdbot CLI to get sessions (if available)
    // Or make HTTP request to gateway
    const result = execSync('curl -s http://localhost:18789/api/sessions?kinds=subagent', {
      encoding: 'utf-8',
      timeout: 5000
    });
    return JSON.parse(result);
  } catch (e) {
    console.error('Failed to get sessions from Clawdbot:', e.message);
    return null;
  }
}

function updateStateFile(alias, sessionData) {
  const statePath = path.join(AGENTS_DIR, alias, 'state.json');
  const stateDir = path.dirname(statePath);
  
  // Ensure directory exists
  if (!fs.existsSync(stateDir)) {
    fs.mkdirSync(stateDir, { recursive: true });
  }
  
  // Load existing state or create new
  let state = {};
  if (fs.existsSync(statePath)) {
    try {
      state = JSON.parse(fs.readFileSync(statePath, 'utf-8'));
    } catch (e) {
      state = {};
    }
  }
  
  // Update with session data
  const now = new Date().toISOString();
  
  if (sessionData) {
    // Active session found
    state.alias = alias;
    state.lastActivity = new Date(sessionData.updatedAt).toISOString();
    state.status = sessionData.abortedLastRun ? 'error' : 'active';
    state.sessionKey = sessionData.key;
    state.sessionId = sessionData.sessionId;
    state.totalTokens = sessionData.totalTokens;
    state.assignmentStatus = 'onAssignment';
    state.dutyStatus = 'onDuty';
  } else {
    // No active session - check if recently completed
    const lastActivity = state.lastActivity ? new Date(state.lastActivity) : null;
    const minutesSinceActivity = lastActivity 
      ? (Date.now() - lastActivity.getTime()) / 60000 
      : Infinity;
    
    if (minutesSinceActivity > 30) {
      state.status = 'idle';
    }
  }
  
  state.lastSyncAt = now;
  
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  return state;
}

async function syncSessions() {
  console.log(`[${new Date().toISOString()}] Syncing Clawdbot sessions to state files...`);
  
  const sessions = await getClawdbotSessions();
  
  if (!sessions) {
    console.error('Could not fetch sessions. Gateway might be down.');
    
    // Mark all agents as potentially derrelict
    for (const alias of AGENT_LABELS) {
      const statePath = path.join(AGENTS_DIR, alias, 'state.json');
      if (fs.existsSync(statePath)) {
        const state = JSON.parse(fs.readFileSync(statePath, 'utf-8'));
        state.status = 'unknown';
        state.lastSyncAt = new Date().toISOString();
        state.syncError = 'Gateway unreachable';
        fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
      }
    }
    return;
  }
  
  // Build map of label -> session
  const sessionMap = {};
  for (const session of sessions.sessions || []) {
    // Extract label from session key (e.g., "agent:main:subagent:xxx" with label "numen")
    if (session.label) {
      sessionMap[session.label] = session;
    }
  }
  
  // Update each agent's state file
  for (const alias of AGENT_LABELS) {
    const session = sessionMap[alias];
    const state = updateStateFile(alias, session);
    console.log(`  ${alias}: ${state.status} (last: ${state.lastActivity || 'never'})`);
  }
  
  console.log('Sync complete.\n');
}

// Run immediately
syncSessions();

// If --watch flag, run every 30 seconds
if (process.argv.includes('--watch')) {
  setInterval(syncSessions, 30000);
}
