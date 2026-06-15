#!/bin/bash

# Test Agent Runner - Simulates a responsive agent for integration testing
# This script monitors instructions.md and responds automatically

AGENT_ALIAS="${1:-testbot}"
AGENT_DIR="$HOME/clawd/agents/$AGENT_ALIAS"
INSTRUCTIONS_FILE="$AGENT_DIR/instructions.md"
STATE_FILE="$AGENT_DIR/state.json"
CHECK_INTERVAL=5  # seconds

echo "▶ Test Agent Runner for: $AGENT_ALIAS"
echo "📁 Monitoring: $INSTRUCTIONS_FILE"
echo "⏱️  Check interval: ${CHECK_INTERVAL}s"
echo ""

# Function to update state with activity
update_state() {
    local message="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Read current state
    if [ -f "$STATE_FILE" ]; then
        local current_state=$(cat "$STATE_FILE")

        # Update using jq
        echo "$current_state" | jq \
            --arg ts "$timestamp" \
            --arg msg "$message" \
            '.lastActivity = $ts | .progress += [$msg]' \
            > "$STATE_FILE"

        echo "✓ Updated state.json - lastActivity: $timestamp"
    fi
}

# Function to submit word report
submit_word_report() {
    local status="$1"
    local summary="$2"

    am word-report "$AGENT_ALIAS" \
        --status "$status" \
        --summary "$summary" \
        2>&1

    echo "✓ Submitted word report"
}

# Function to process instruction
process_instruction() {
    local instruction="$1"

    echo ""
    echo "📬 New Instruction: $instruction"

    # Simple command routing
    case "$instruction" in
        *hello*|*Hello*)
            echo "🎉 Responding: Hello World received!"
            update_state "Received hello instruction - responded"
            submit_word_report "success" "Responded to hello instruction"
            ;;

        *status*|*Status*)
            echo "📊 Responding with status"
            local uptime_info=$(uptime)
            update_state "Status check - $uptime_info"
            submit_word_report "success" "Status: $uptime_info"
            ;;

        *test*|*Test*)
            echo "🧪 Running test"
            local date_info=$(date)
            update_state "Test completed - $date_info"
            submit_word_report "success" "Test passed at $date_info"
            ;;

        *date*|*Date*)
            echo "📅 Date check"
            local date_full=$(date "+%Y-%m-%d %H:%M:%S %Z")
            update_state "Date check - $date_full"
            submit_word_report "success" "Current time: $date_full"
            ;;

        *ls*|*list*)
            echo "📂 Listing directory"
            local files=$(ls -la "$AGENT_DIR" | head -10)
            update_state "Listed directory contents"
            submit_word_report "success" "Directory listing complete"
            ;;

        *)
            echo "❓ Unknown instruction, acknowledging"
            update_state "Received instruction: $instruction"
            submit_word_report "success" "Acknowledged instruction: ${instruction:0:50}"
            ;;
    esac
}

# Track last modification time
last_mtime=0

echo "✅ Agent runner started. Monitoring for instructions..."
echo "   Press Ctrl+C to stop"
echo ""

# Main monitoring loop
while true; do
    if [ -f "$INSTRUCTIONS_FILE" ]; then
        # Get current modification time
        if [[ "$OSTYPE" == "darwin"* ]]; then
            current_mtime=$(stat -f %m "$INSTRUCTIONS_FILE")
        else
            current_mtime=$(stat -c %Y "$INSTRUCTIONS_FILE")
        fi

        # Check if file was modified
        if [ "$current_mtime" != "$last_mtime" ]; then
            # File changed - process latest instruction
            last_instruction=$(grep -A 2 "## Instruction\|## Poke" "$INSTRUCTIONS_FILE" | tail -3 | head -1 | sed 's/^[[:space:]]*//')

            if [ -n "$last_instruction" ] && [ "$last_instruction" != "Monitoring for new instructions..." ]; then
                process_instruction "$last_instruction"
                last_mtime="$current_mtime"
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
