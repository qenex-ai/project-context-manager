---
name: resume
description: Resume work from last session or specific previous session with automatic context restoration
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# Resume Command

## High-Level Overview

Restore context from a previous work session, including:
- Last edited files
- Current chunk/phase location
- Todo list state
- Plan mode context
- Project index

**When to use:** Start of work session, after context reset, or when switching between projects.

**Goal:** Zero cognitive overhead when resuming work—pick up exactly where you left off.

---

## Execution Flow

### Level 1: Core Process

1. **Load session state** → Read `.claude/.project-state.json`
2. **Display session summary** → Show what was being worked on
3. **Restore file context** → Open/read last edited files
4. **Restore phase context** → Load current chunk
5. **Restore plan mode** → Reload plan if active
6. **Update index** → Refresh if project changed

### Level 2: Detailed Steps

#### Step 1: Determine Session to Restore

```bash
# Get project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# Check for session state file
STATE_FILE="$PROJECT_ROOT/.claude/.project-state.json"

if [ ! -f "$STATE_FILE" ]; then
  echo "No previous session found for project: $PROJECT_NAME"
  echo "Run /index-project to start tracking this project"
  exit 1
fi
```

**With --session argument:**
```bash
# User specified session date
SESSION_DATE="$1"  # Format: 2024-01-22
HISTORY_FILE="$PROJECT_ROOT/.claude/.session-history.json"

# Find session by date
SESSION_STATE=$(jq -r ".sessions[] | select(.date == \"$SESSION_DATE\")" "$HISTORY_FILE")
```

**With --list argument:**
```bash
# Show available sessions
echo "Available sessions for $PROJECT_NAME:"
jq -r '.sessions[] | "\(.date) - \(.phase) (\(.files_edited) files)"' \
  "$PROJECT_ROOT/.claude/.session-history.json"
exit 0
```

#### Step 2: Load Session State

Read state from JSON:

```bash
# Parse session state
LAST_SESSION_DATE=$(jq -r '.last_session_date' "$STATE_FILE")
CURRENT_PHASE=$(jq -r '.current_phase // "Unknown"' "$STATE_FILE")
LAST_FILES=$(jq -r '.last_edited_files[]' "$STATE_FILE")
CHUNK_INDEX=$(jq -r '.current_chunk_index // 0' "$STATE_FILE")
TODO_STATE=$(jq -r '.todos' "$STATE_FILE")
PLAN_FILE=$(jq -r '.plan_file // ""' "$STATE_FILE")
COMPLETION_PCT=$(jq -r '.completion_percentage // 0' "$STATE_FILE")
```

#### Step 3: Display Session Summary

Show high-level overview:

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  Resuming Session: $PROJECT_NAME"
echo "═══════════════════════════════════════════════"
echo ""
echo "Last active: $LAST_SESSION_DATE"
echo "Current phase: $CURRENT_PHASE"
echo "Progress: ${COMPLETION_PCT}% complete"
echo ""

# Show last edited files
echo "Last edited files:"
echo "$LAST_FILES" | head -5 | while read -r file; do
  echo "  • $file"
done

FILE_COUNT=$(echo "$LAST_FILES" | wc -l)
if [ "$FILE_COUNT" -gt 5 ]; then
  echo "  ... and $((FILE_COUNT - 5)) more files"
fi
echo ""
```

#### Step 4: Restore File Context

Automatically load last edited files:

```bash
echo "Loading file context..."

# Read last 3 edited files into context
COUNTER=0
echo "$LAST_FILES" | head -3 | while read -r file; do
  COUNTER=$((COUNTER + 1))
  if [ -f "$PROJECT_ROOT/$file" ]; then
    echo "  [$COUNTER] Loading: $file"
    # File will be read into context automatically
  else
    echo "  [$COUNTER] File not found: $file (may have been moved/deleted)"
  fi
done
```

#### Step 5: Restore Phase/Chunk Context

Load current chunk information:

```bash
# Check if chunks exist
CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"

if [ -f "$CHUNKS_FILE" ]; then
  # Get current chunk details
  CHUNK_NAME=$(jq -r ".chunks[$CHUNK_INDEX].name" "$CHUNKS_FILE")
  CHUNK_FILES=$(jq -r ".chunks[$CHUNK_INDEX].files[]" "$CHUNKS_FILE")
  CHUNK_SUMMARY=$(jq -r ".chunks[$CHUNK_INDEX].summary" "$CHUNKS_FILE")

  echo "Current chunk: $CHUNK_NAME"
  echo "Files in chunk:"
  echo "$CHUNK_FILES" | head -5 | while read -r file; do
    echo "  • $file"
  done
  echo ""

  if [ -n "$CHUNK_SUMMARY" ]; then
    echo "Chunk summary:"
    echo "$CHUNK_SUMMARY" | fold -w 70 -s | sed 's/^/  /'
    echo ""
  fi
fi
```

#### Step 6: Restore Plan Mode Context

If plan mode was active:

```bash
if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  echo "Plan mode was active"
  echo "Plan file: $PLAN_FILE"
  echo ""

  # Extract current task from plan
  CURRENT_TASK=$(grep -E '^\- \[ \]' "$PLAN_FILE" | head -1)
  if [ -n "$CURRENT_TASK" ]; then
    echo "Next task:"
    echo "  $CURRENT_TASK"
    echo ""
  fi

  # Show completion stats
  TOTAL_TASKS=$(grep -cE '^\- \[(x| )\]' "$PLAN_FILE")
  COMPLETED_TASKS=$(grep -cE '^\- \[x\]' "$PLAN_FILE")
  echo "Progress: $COMPLETED_TASKS/$TOTAL_TASKS tasks completed"
  echo ""
fi
```

#### Step 7: Restore Todo State

Show incomplete todos:

```bash
echo "Outstanding todos:"
echo "$TODO_STATE" | jq -r '.[] | select(.status != "completed") | "  [\(.status)] \(.content)"' | head -10

PENDING_COUNT=$(echo "$TODO_STATE" | jq '[.[] | select(.status == "pending")] | length')
IN_PROGRESS_COUNT=$(echo "$TODO_STATE" | jq '[.[] | select(.status == "in_progress")] | length')

echo ""
echo "Todo summary: $PENDING_COUNT pending, $IN_PROGRESS_COUNT in progress"
echo ""
```

#### Step 8: Check for Project Changes

Verify index is current:

```bash
# Check index age
INDEX_FILE="$PROJECT_ROOT/.claude/.project-index.json"
if [ -f "$INDEX_FILE" ]; then
  INDEX_AGE=$(( $(date +%s) - $(stat -c %Y "$INDEX_FILE" 2>/dev/null || stat -f %m "$INDEX_FILE") ))

  # If index older than 24 hours, suggest refresh
  if [ "$INDEX_AGE" -gt 86400 ]; then
    echo "⚠ Project index is $(($INDEX_AGE / 3600)) hours old"
    echo "  Consider running /index-project to refresh"
    echo ""
  fi
fi
```

#### Step 9: Ready to Resume

```bash
echo "═══════════════════════════════════════════════"
echo "✓ Session restored successfully"
echo "═══════════════════════════════════════════════"
echo ""
echo "Ready to continue working on: $CURRENT_PHASE"
```

---

## Arguments

- `--session <date>` - Resume specific session (format: YYYY-MM-DD)
- `--list` - Show available sessions
- `--force` - Force restore even if state file is corrupted
- `--minimal` - Skip file loading (summary only)

---

## Output Format

### Standard Resume

```
═══════════════════════════════════════════════
  Resuming Session: qenex
═══════════════════════════════════════════════

Last active: 2024-01-22 15:30:45
Current phase: Phase 3: API Integration
Progress: 60% complete

Last edited files:
  • src/api/endpoints.py
  • src/api/auth.py
  • tests/test_api.py

Loading file context...
  [1] Loading: src/api/endpoints.py
  [2] Loading: src/api/auth.py
  [3] Loading: tests/test_api.py

Current chunk: Phase 3: API Integration
Files in chunk:
  • src/api/endpoints.py
  • src/api/auth.py
  • src/api/middleware.py
  • src/api/models.py
  • tests/test_api.py

Chunk summary:
  Implementing REST API endpoints with JWT authentication. Includes
  user registration, login, token refresh, and protected routes.
  Integration with existing database models.

Plan mode was active
Plan file: /root/.claude/plans/qenex-api-integration.md

Next task:
  - [ ] Add rate limiting middleware

Progress: 12/20 tasks completed

Outstanding todos:
  [in_progress] Implement JWT token refresh
  [pending] Add rate limiting
  [pending] Write API integration tests
  [pending] Update API documentation

Todo summary: 8 pending, 1 in progress

═══════════════════════════════════════════════
✓ Session restored successfully
═══════════════════════════════════════════════

Ready to continue working on: Phase 3: API Integration
```

### Session List

```
Available sessions for qenex:
2024-01-22 - Phase 3: API Integration (8 files)
2024-01-21 - Phase 2: Database Models (12 files)
2024-01-20 - Phase 1: Project Setup (5 files)
2024-01-19 - Initial Planning (3 files)
```

---

## Auto-Resume on SessionStart

This command can be triggered automatically via SessionStart hook:

```json
{
  "SessionStart": [{
    "hooks": [{
      "type": "command",
      "command": "bash $CLAUDE_PLUGIN_ROOT/scripts/session/auto-resume.sh"
    }]
  }]
}
```

Configuration in `.claude/project-context.local.md`:
```yaml
---
auto_resume_on_start: true
---
```

---

## Integration with Other Components

**Session Management Skill:**
- Detailed session state tracking
- Auto-save on Stop hook
- Session history management

**Chunk Navigation:**
- Restores current chunk position
- Loads chunk-specific context

**Plan Mode:**
- Reopens active plan file
- Restores task progress

**Project Indexing:**
- Validates index freshness
- Suggests re-indexing if stale

---

## Error Handling

**No state file:**
```
No previous session found for project: myproject
Run /index-project to start tracking this project
```

**Corrupted state:**
```
⚠ Session state file is corrupted
  File: .claude/.project-state.json

Options:
  1. Restore from backup: .claude/.project-state.json.backup
  2. Start fresh session: /index-project
```

**Missing files:**
```
⚠ Some files from last session no longer exist:
  • src/old_module.py (deleted)
  • tests/deprecated_test.py (moved)

Continuing with available files...
```

---

## Related Skills

This command uses the **session-management** skill. For detailed information about state tracking, auto-save behavior, and session history, refer to:

`$CLAUDE_PLUGIN_ROOT/skills/session-management/SKILL.md` (to be created)
