import { readFile } from 'fs/promises';
import { homedir } from 'os';
import { join } from 'path';

// Base clawd dir is overridable via CLAWD_DIR (resolved at call time) so tests
// and alternate layouts don't read or write the real ~/clawd.
function clawdDir() {
  return process.env.CLAWD_DIR || join(homedir(), 'clawd');
}

export async function loadRegistry() {
  try {
    const data = await readFile(join(clawdDir(), 'agent-registry.json'), 'utf-8');
    return JSON.parse(data);
  } catch (err) {
    console.error('Failed to load agent registry:', err.message);
    return { agents: [] };
  }
}

export async function loadAgentState(alias) {
  try {
    const data = await readFile(getStatePath(alias), 'utf-8');
    return JSON.parse(data);
  } catch (err) {
    return null;
  }
}

export function getAgentsDir() {
  return join(clawdDir(), 'agents');
}

export function getStatePath(alias) {
  return join(getAgentsDir(), alias, 'state.json');
}
