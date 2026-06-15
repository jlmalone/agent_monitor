import fs from 'fs';
import { getStatePath } from '../lib/config.js';

export async function quickReport(alias, message, options = {}) {
  const statePath = getStatePath(alias);

  try {
    const data = fs.readFileSync(statePath, 'utf-8');
    const state = JSON.parse(data);

    const now = Date.now();
    const progress = Array.isArray(state.progress) ? state.progress : [];
    progress.push(message);

    state.lastActivity = now;
    state.currentAssignment = message;
    state.status = 'active';
    state.progress = progress.slice(-50);

    if (options.status) {
      state.status = options.status;
    }

    if (typeof options.tokens === 'number' && !Number.isNaN(options.tokens)) {
      state.totalTokens = options.tokens;
      const samples = Array.isArray(state.tokenSamples) ? state.tokenSamples : [];
      samples.push({ ts: now, totalTokens: options.tokens });
      const oneHourAgo = now - 3600 * 1000;
      state.tokenSamples = samples.filter(s => s.ts >= oneHourAgo).slice(-50);
    }

    const tempPath = `${statePath}.tmp-${process.pid}`;
    fs.writeFileSync(tempPath, JSON.stringify(state));
    fs.renameSync(tempPath, statePath);

    console.log(`✓ Quick report saved for ${alias}`);
  } catch (err) {
    console.log(`Failed to save quick report: ${err.message}`);
  }
}
