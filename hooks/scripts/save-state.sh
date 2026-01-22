#!/bin/bash
# Stop hook - Save current work state automatically
set -euo pipefail

# Get project root
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROJECT_NAME=$(basename "$PROJECT_ROOT")
STATE_DIR="$PROJECT_ROOT/.claude"
STATE_FILE="$STATE_DIR/.project-state.json"

# Output structure for Stop hook
output_message() {
  local message="$1"
  cat <<EOF
{
  "decision": "approve",
  "systemMessage": "$message",
  "continue": true
}
EOF
}

# Create .claude directory if it doesn't exist
mkdir -p "$STATE_DIR"

# Check if we have an existing state to update
if [ ! -f "$STATE_FILE" ]; then
  # No existing state - create minimal state
  cat > "$STATE_FILE" <<EOF
{
  "project_name": "$PROJECT_NAME",
  "project_root": "$PROJECT_ROOT",
  "last_session_date": "$(date -Iseconds)",
  "current_phase": "General Development",
  "current_chunk_index": 0,
  "last_edited_files": [],
  "todos": [],
  "plan_file": "",
  "completion_percentage": 0,
  "checkpoint_reason": "stop"
}
EOF
  output_message "✓ Session state saved for $PROJECT_NAME"
  exit 0
fi

# Update existing state with new timestamp and checkpoint reason
jq ".last_session_date = \"$(date -Iseconds)\" | .checkpoint_reason = \"stop\"" \
  "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

# Get last edited files from git if available
if git rev-parse --git-dir > /dev/null 2>&1; then
  EDITED_FILES=$(git diff --name-only HEAD 2>/dev/null | head -10 | jq -R -s 'split("\n") | map(select(length > 0))')

  if [ "$EDITED_FILES" != "[]" ] && [ "$EDITED_FILES" != "null" ]; then
    jq ".last_edited_files = $EDITED_FILES" \
      "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  fi
fi

# Create backup
if [ -f "$STATE_FILE" ]; then
  cp "$STATE_FILE" "$STATE_FILE.backup"
fi

# Update session history
HISTORY_FILE="$STATE_DIR/.session-history.json"
CURRENT_PHASE=$(jq -r '.current_phase // "Unknown"' "$STATE_FILE")
COMPLETION=$(jq -r '.completion_percentage // 0' "$STATE_FILE")
EDITED_COUNT=$(jq '.last_edited_files | length' "$STATE_FILE")

if [ ! -f "$HISTORY_FILE" ]; then
  # Create new history file
  cat > "$HISTORY_FILE" <<EOF
{
  "project_name": "$PROJECT_NAME",
  "sessions": []
}
EOF
fi

# Append to history (keep last 30 sessions)
SESSION_ENTRY=$(cat <<EOF
{
  "date": "$(date +%Y-%m-%d)",
  "timestamp": "$(date -Iseconds)",
  "phase": "$CURRENT_PHASE",
  "files_edited": $EDITED_COUNT,
  "completion": $COMPLETION,
  "checkpoint_reason": "stop"
}
EOF
)

jq ".sessions += [$SESSION_ENTRY] | .sessions |= if length > 30 then .[1:] else . end" \
  "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

output_message "✓ Session state saved\n  Phase: $CURRENT_PHASE\n  Files: $EDITED_COUNT edited\n  Progress: ${COMPLETION}%"
exit 0
