#!/bin/bash
#
# Clawdbot Resurrection Script
#
# This script checks if clawdbot is healthy and resurrects it if down.
# It replicates the exact manual steps an operator uses to wake up clawdbot.
#
# Exit codes:
#   0 - Clawdbot is healthy or successfully resurrected
#   1 - Failed to resurrect clawdbot
#

set -euo pipefail

# Configuration
LOG_FILE="$HOME/ios_code/server_monitor/logs/clawdbot-watchdog.log"
HEALTH_TIMEOUT=10
RESURRECT_TIMEOUT=30
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Logging function
log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

log "=== Clawdbot Watchdog Check Started ==="

# Step 1: Check clawdbot health
log "Checking clawdbot health..."

if gtimeout $HEALTH_TIMEOUT clawdbot health >/dev/null 2>&1; then
    log "✅ Clawdbot is healthy - no action needed"
    exit 0
else
    EXIT_CODE=$?
    log "❌ Clawdbot health check failed (exit code: $EXIT_CODE)"
fi

# Step 2: Attempt resurrection
log "🔄 Attempting to resurrect clawdbot..."

RESURRECT_OUTPUT=$(mktemp)

if gtimeout $RESURRECT_TIMEOUT clawdbot agent --agent main --message "Resume from where you left off. Check recent sessions and continue any incomplete work. Report current status and what you were working on." >"$RESURRECT_OUTPUT" 2>&1; then
    log "✅ Resurrection command sent successfully"

    # Step 3: Verify resurrection
    log "Verifying clawdbot is responsive..."
    sleep 3  # Give it a moment to stabilize

    if gtimeout $HEALTH_TIMEOUT clawdbot health >/dev/null 2>&1; then
        log "✅ Clawdbot successfully resurrected and is now healthy!"

        # Log the agent's response for debugging
        log "Agent response:"
        head -20 "$RESURRECT_OUTPUT" | while IFS= read -r line; do
            log "  $line"
        done

        rm -f "$RESURRECT_OUTPUT"
        exit 0
    else
        log "⚠️  Resurrection command sent, but health check still failing"
        log "Agent response:"
        cat "$RESURRECT_OUTPUT" | while IFS= read -r line; do
            log "  $line"
        done
        rm -f "$RESURRECT_OUTPUT"
        exit 1
    fi
else
    EXIT_CODE=$?
    log "❌ Failed to send resurrection command (exit code: $EXIT_CODE)"
    log "Output:"
    cat "$RESURRECT_OUTPUT" | while IFS= read -r line; do
        log "  $line"
    done
    rm -f "$RESURRECT_OUTPUT"
    exit 1
fi
