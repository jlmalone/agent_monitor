#!/usr/bin/env bash
set -euo pipefail

ALIAS="testbot"
STATE_PATH="$HOME/clawd/agents/${ALIAS}/state.json"
CLI_PATH="$(cd "$(dirname "$0")/.." && pwd)/src/index.js"
export CLI_PATH

if [[ ! -f "$STATE_PATH" ]]; then
  echo "✖ state.json not found: $STATE_PATH"
  exit 1
fi

BACKUP_PATH="${STATE_PATH}.bak.$(date +%s)"
cp "$STATE_PATH" "$BACKUP_PATH"

MESSAGE="integration-test $(date +%s)"

# Measure execution time (<100ms requirement)
python3 - <<PY
import subprocess, time, sys
alias = "${ALIAS}"
message = "${MESSAGE}"
cmd = ["node", "${CLI_PATH}", "quickreport", alias, message]
start = time.time()
proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
elapsed = (time.time() - start) * 1000
print(proc.stdout.strip())
if proc.returncode != 0:
    print(proc.stderr.strip(), file=sys.stderr)
    sys.exit(proc.returncode)
if elapsed > 250:
    print(f"✖ quickreport took {elapsed:.1f}ms (>250ms)")
    sys.exit(1)
print(f"✓ quickreport time: {elapsed:.1f}ms")
PY

export STATE_PATH="$STATE_PATH"
export MESSAGE="$MESSAGE"

node - <<'NODE'
const fs = require('fs');
const statePath = process.env.STATE_PATH;
const message = process.env.MESSAGE;
const state = JSON.parse(fs.readFileSync(statePath, 'utf-8'));

if (state.status !== 'active') {
  console.error('✖ status not active');
  process.exit(1);
}
if (state.currentAssignment !== message) {
  console.error('✖ currentAssignment mismatch');
  process.exit(1);
}
if (!Array.isArray(state.progress) || state.progress[state.progress.length - 1] !== message) {
  console.error('✖ progress not appended');
  process.exit(1);
}
if (state.progress.length > 50) {
  console.error('✖ progress length > 50');
  process.exit(1);
}
if (typeof state.lastActivity !== 'number') {
  console.error('✖ lastActivity not number (ms)');
  process.exit(1);
}
console.log('✓ state.json updated correctly');
NODE

# Token sample test
node - <<'NODE'
const { execSync } = require('child_process');
const fs = require('fs');
const statePath = process.env.STATE_PATH;
const cliPath = process.env.CLI_PATH;
execSync(`node ${cliPath} quickreport testbot "token sample" --tokens 12345`, { stdio: 'inherit' });
const state = JSON.parse(fs.readFileSync(statePath, 'utf-8'));
if (state.totalTokens !== 12345) {
  console.error('✖ totalTokens not updated');
  process.exit(1);
}
if (!Array.isArray(state.tokenSamples) || state.tokenSamples.length === 0) {
  console.error('✖ tokenSamples missing');
  process.exit(1);
}
console.log('✓ tokenSamples recorded');
NODE

# Restore original state
mv "$BACKUP_PATH" "$STATE_PATH"

echo "✓ Integration test passed"
