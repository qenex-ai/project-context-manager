#!/bin/bash
# SessionStart hook - Load previous session context automatically
set -euo pipefail

# Get project root
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROJECT_NAME=$(basename "$PROJECT_ROOT")
STATE_FILE="$PROJECT_ROOT/.claude/.project-state.json"

# Check if project has been indexed
INDEX_FILE="$PROJECT_ROOT/.claude/.project-index.json"

# Output structure for SessionStart hook
output_message() {
  local message="$1"
  cat <<EOF
{
  "systemMessage": "$message",
  "continue": true,
  "suppressOutput": false
}
EOF
}

# Check for project state
if [ ! -f "$STATE_FILE" ]; then
  # No previous session - check if project is indexed
  if [ ! -f "$INDEX_FILE" ]; then
    output_message "New project detected: $PROJECT_NAME. Run /index-project to start tracking."
    exit 0
  else
    output_message "Project indexed: $PROJECT_NAME. Use /resume to restore previous work."
    exit 0
  fi
fi

# State file exists - load session info
LAST_SESSION=$(jq -r '.last_session_date' "$STATE_FILE" 2>/dev/null || echo "unknown")
CURRENT_PHASE=$(jq -r '.current_phase // "Unknown"' "$STATE_FILE" 2>/dev/null || echo "Unknown")
COMPLETION=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null || echo "0")

# Calculate session age
if [ "$LAST_SESSION" != "unknown" ]; then
  LAST_EPOCH=$(date -d "$LAST_SESSION" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_SESSION%:*}" +%s 2>/dev/null || echo "0")
  NOW_EPOCH=$(date +%s)
  AGE_SECONDS=$((NOW_EPOCH - LAST_EPOCH))
  AGE_HOURS=$((AGE_SECONDS / 3600))

  if [ "$AGE_HOURS" -lt 24 ]; then
    SESSION_AGE="${AGE_HOURS}h ago"
  else
    AGE_DAYS=$((AGE_HOURS / 24))
    SESSION_AGE="${AGE_DAYS}d ago"
  fi
else
  SESSION_AGE="unknown"
fi

# Check if index is stale
if [ -f "$INDEX_FILE" ]; then
  INDEX_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y "$INDEX_FILE" 2>/dev/null || stat -f %m "$INDEX_FILE" 2>/dev/null || echo "0") ))
  INDEX_AGE_HOURS=$((INDEX_AGE_SECONDS / 3600))

  if [ "$INDEX_AGE_HOURS" -gt 24 ]; then
    INDEX_WARNING="\n⚠ Project index is ${INDEX_AGE_HOURS}h old - consider running /index-project"
  else
    INDEX_WARNING=""
  fi
else
  INDEX_WARNING="\n⚠ No project index found - run /index-project first"
fi

# Build context message
MESSAGE="═══ Resuming Project: $PROJECT_NAME ═══\n\nLast session: $SESSION_AGE\nCurrent phase: $CURRENT_PHASE\nProgress: ${COMPLETION}%$INDEX_WARNING\n\nRestore full context with: /resume"

output_message "$MESSAGE"
exit 0
