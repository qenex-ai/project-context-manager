---
name: context-summary
description: Display comprehensive project state, progress, and statistics
allowed-tools:
  - Bash
  - Read
---

# Context Summary Command

## High-Level Overview

Display current project status including:
- Project metadata and structure
- Language breakdown
- Active session state
- Chunk progress
- Credential inventory
- Plan mode status

**When to use:** To get oriented in a project, before starting work, or to share project status.

**Goal:** Single-command overview of entire project context.

---

## Execution Flow

### Level 1: Information Hierarchy

1. **Project Identity** → Name, location, languages
2. **Structure Overview** → Files, directories, dependencies
3. **Session State** → Last activity, current phase, progress
4. **Chunks** → Total chunks, current chunk, completion
5. **Credentials** → Count of stored credentials (names only)
6. **Plan Status** → Active plan, task progress

### Level 2: Detailed Implementation

#### Step 1: Project Identity

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
INDEX_FILE="$PROJECT_ROOT/.claude/.project-index.json"

echo "═══════════════════════════════════════════════"
echo "  Project Context: $PROJECT_NAME"
echo "═══════════════════════════════════════════════"
echo ""

# Basic info
echo "Location: $PROJECT_ROOT"

# Git status
if git rev-parse --git-dir > /dev/null 2>&1; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  LAST_COMMIT=$(git log -1 --format="%h - %s" 2>/dev/null)
  echo "Branch: $CURRENT_BRANCH"
  echo "Last commit: $LAST_COMMIT"
fi

echo ""
```

#### Step 2: Structure Overview

```bash
if [ ! -f "$INDEX_FILE" ]; then
  echo "⚠ Project not indexed. Run /index-project"
  exit 0
fi

# Parse index
TOTAL_FILES=$(jq -r '.total_files' "$INDEX_FILE")
INDEXED_AT=$(jq -r '.indexed_at' "$INDEX_FILE")
INDEX_AGE=$(( $(date +%s) - $(date -d "$INDEXED_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${INDEXED_AT%:*}" +%s) ))
INDEX_AGE_HOURS=$(( INDEX_AGE / 3600 ))

echo "╔═══ Structure ═══"
echo "║"
echo "║ Total files: $TOTAL_FILES"
echo "║ Indexed: ${INDEX_AGE_HOURS}h ago"
echo "║"

# Language breakdown
echo "║ Languages:"
jq -r '.languages | to_entries[] | select(.value.files > 0) | "║   \(.key | ascii_upcase): \(.value.files) files\(.value.primary == true and " (Primary)" or "")"' "$INDEX_FILE"

echo "║"

# Dependencies
RUST_DEPS=$(jq -r '.dependencies.rust // 0' "$INDEX_FILE")
PYTHON_DEPS=$(jq -r '.dependencies.python // 0' "$INDEX_FILE")
JS_DEPS=$(jq -r '.dependencies.javascript // 0' "$INDEX_FILE")
GO_DEPS=$(jq -r '.dependencies.go // 0' "$INDEX_FILE")

if [ "$RUST_DEPS" -gt 0 ] || [ "$PYTHON_DEPS" -gt 0 ] || [ "$JS_DEPS" -gt 0 ] || [ "$GO_DEPS" -gt 0 ]; then
  echo "║ Dependencies:"
  [ "$RUST_DEPS" -gt 0 ] && echo "║   Rust: $RUST_DEPS packages"
  [ "$PYTHON_DEPS" -gt 0 ] && echo "║   Python: $PYTHON_DEPS packages"
  [ "$JS_DEPS" -gt 0 ] && echo "║   JavaScript: $JS_DEPS packages"
  [ "$GO_DEPS" -gt 0 ] && echo "║   Go: $GO_DEPS packages"
  echo "║"
fi

echo "╚═════════════════"
echo ""
```

#### Step 3: Session State

```bash
STATE_FILE="$PROJECT_ROOT/.claude/.project-state.json"

if [ -f "$STATE_FILE" ]; then
  LAST_SESSION=$(jq -r '.last_session_date' "$STATE_FILE")
  CURRENT_PHASE=$(jq -r '.current_phase // "Not set"' "$STATE_FILE")
  COMPLETION=$(jq -r '.completion_percentage // 0' "$STATE_FILE")
  LAST_FILES=$(jq -r '.last_edited_files[]' "$STATE_FILE" 2>/dev/null | head -3)

  SESSION_AGE=$(( $(date +%s) - $(date -d "$LAST_SESSION" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_SESSION%:*}" +%s) ))
  SESSION_AGE_HOURS=$(( SESSION_AGE / 3600 ))

  echo "╔═══ Session ═══"
  echo "║"
  echo "║ Last active: ${SESSION_AGE_HOURS}h ago"
  echo "║ Current phase: $CURRENT_PHASE"
  echo "║ Progress: ${COMPLETION}%"
  echo "║"

  if [ -n "$LAST_FILES" ]; then
    echo "║ Recent files:"
    echo "$LAST_FILES" | while read -r file; do
      echo "║   • $file"
    done
    echo "║"
  fi

  echo "╚═════════════════"
  echo ""
else
  echo "╔═══ Session ═══"
  echo "║"
  echo "║ No active session"
  echo "║ Run /index-project to start"
  echo "║"
  echo "╚═════════════════"
  echo ""
fi
```

#### Step 4: Chunks

```bash
CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"

if [ -f "$CHUNKS_FILE" ]; then
  TOTAL_CHUNKS=$(jq '.total_chunks' "$CHUNKS_FILE")
  CURRENT_CHUNK_INDEX=$(jq -r '.current_chunk_index // 0' "$STATE_FILE" 2>/dev/null)
  CURRENT_CHUNK_NAME=$(jq -r ".chunks[$CURRENT_CHUNK_INDEX].name" "$CHUNKS_FILE" 2>/dev/null)

  echo "╔═══ Chunks ═══"
  echo "║"
  echo "║ Total chunks: $TOTAL_CHUNKS"

  if [ -n "$CURRENT_CHUNK_NAME" ]; then
    echo "║ Current: $CURRENT_CHUNK_NAME ($(($CURRENT_CHUNK_INDEX + 1))/$TOTAL_CHUNKS)"
  fi

  echo "║"
  echo "║ All chunks:"
  jq -r '.chunks[] | "║   • \(.name) (\(.files | length) files)"' "$CHUNKS_FILE"
  echo "║"
  echo "╚═════════════════"
  echo ""
else
  echo "╔═══ Chunks ═══"
  echo "║"
  echo "║ No chunks created"
  echo "║ Run /chunk --create"
  echo "║"
  echo "╚═════════════════"
  echo ""
fi
```

#### Step 5: Credentials

```bash
# Count stored credentials (names only, never values)
CRED_COUNT=$(bash $CLAUDE_PLUGIN_ROOT/skills/secure-credential-handling/scripts/keychain-wrapper.sh \
  list "claude-code:${PROJECT_NAME}" 2>/dev/null | wc -l || echo "0")

echo "╔═══ Credentials ═══"
echo "║"

if [ "$CRED_COUNT" -gt 0 ]; then
  echo "║ Stored: $CRED_COUNT credentials"
  echo "║"
  echo "║ Use /list-credentials to view names"
else
  echo "║ No credentials stored"
  echo "║ Use /store-credential to add"
fi

echo "║"
echo "╚═════════════════"
echo ""
```

#### Step 6: Plan Status

```bash
PLAN_FILE=$(jq -r '.plan_file // ""' "$STATE_FILE" 2>/dev/null)

if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  PLAN_NAME=$(basename "$PLAN_FILE" .md)
  TOTAL_TASKS=$(grep -cE '^\- \[(x| )\]' "$PLAN_FILE" || echo "0")
  COMPLETED_TASKS=$(grep -cE '^\- \[x\]' "$PLAN_FILE" || echo "0")
  PENDING_TASKS=$(( TOTAL_TASKS - COMPLETED_TASKS ))

  NEXT_TASK=$(grep -E '^\- \[ \]' "$PLAN_FILE" | head -1 | sed 's/^- \[ \] //')

  echo "╔═══ Plan Mode ═══"
  echo "║"
  echo "║ Active plan: $PLAN_NAME"
  echo "║ Progress: $COMPLETED_TASKS/$TOTAL_TASKS tasks"
  echo "║ Remaining: $PENDING_TASKS tasks"
  echo "║"

  if [ -n "$NEXT_TASK" ]; then
    echo "║ Next task:"
    echo "║   $NEXT_TASK"
    echo "║"
  fi

  echo "╚═════════════════"
  echo ""
else
  echo "╔═══ Plan Mode ═══"
  echo "║"
  echo "║ No active plan"
  echo "║"
  echo "╚═════════════════"
  echo ""
fi
```

#### Step 7: Quick Actions

```bash
echo "╔═══ Quick Actions ═══"
echo "║"
echo "║ /resume             Continue last session"
echo "║ /chunk --current    View current chunk"
echo "║ /navigate --next    Move to next chunk"
echo "║ /index-project      Refresh project index"
echo "║"
echo "╚═════════════════"
```

---

## Arguments

- `--json` - Output in JSON format (for scripting)
- `--minimal` - Show only essential info (name, phase, progress)
- `--verbose` - Include detailed statistics

---

## Output Formats

### Standard Output

```
═══════════════════════════════════════════════
  Project Context: qenex
═══════════════════════════════════════════════

Location: /home/ubuntu/qenex
Branch: master
Last commit: a34a001 - CI: Test with Enterprise runner

╔═══ Structure ═══
║
║ Total files: 1,247
║ Indexed: 3h ago
║
║ Languages:
║   PYTHON: 312 files (Primary)
║   RUST: 185 files (Primary)
║   GO: 94 files
║   JAVASCRIPT: 156 files (Primary)
║   JULIA: 23 files
║
║ Dependencies:
║   Rust: 47 packages
║   Python: 89 packages
║   JavaScript: 124 packages
║
╚═════════════════

╔═══ Session ═══
║
║ Last active: 2h ago
║ Current phase: Phase 3: API Integration
║ Progress: 60%
║
║ Recent files:
║   • src/api/endpoints.py
║   • src/api/auth.py
║   • tests/test_api.py
║
╚═════════════════

╔═══ Chunks ═══
║
║ Total chunks: 8
║ Current: Phase 3: API Integration (3/8)
║
║ All chunks:
║   • Phase 0: Project Setup (15 files)
║   • Phase 1: Authentication (42 files)
║   • Phase 2: Database Models (65 files)
║   • Phase 3: API Integration (87 files)
║   • Phase 4: Trading Engine (143 files)
║   • Phase 5: Blockchain Integration (98 files)
║   • Phase 6: Monitoring (54 files)
║   • Phase X: Testing (312 files)
║
╚═════════════════

╔═══ Credentials ═══
║
║ Stored: 5 credentials
║
║ Use /list-credentials to view names
║
╚═════════════════

╔═══ Plan Mode ═══
║
║ Active plan: api-integration-plan
║ Progress: 12/20 tasks
║ Remaining: 8 tasks
║
║ Next task:
║   Add rate limiting middleware
║
╚═════════════════

╔═══ Quick Actions ═══
║
║ /resume             Continue last session
║ /chunk --current    View current chunk
║ /navigate --next    Move to next chunk
║ /index-project      Refresh project index
║
╚═════════════════
```

### Minimal Output (`--minimal`)

```
qenex (Phase 3: API Integration - 60%)
  Last active: 2h ago
  1,247 files | 8 chunks | 5 credentials
```

### JSON Output (`--json`)

```json
{
  "project_name": "qenex",
  "location": "/home/ubuntu/qenex",
  "structure": {
    "total_files": 1247,
    "languages": {
      "python": {"files": 312, "primary": true},
      "rust": {"files": 185, "primary": true}
    },
    "dependencies": {
      "rust": 47,
      "python": 89
    }
  },
  "session": {
    "last_active": "2024-01-22T13:30:45Z",
    "current_phase": "Phase 3: API Integration",
    "completion_percentage": 60
  },
  "chunks": {
    "total": 8,
    "current_index": 2
  },
  "credentials": {
    "count": 5
  },
  "plan": {
    "active": true,
    "name": "api-integration-plan",
    "total_tasks": 20,
    "completed_tasks": 12
  }
}
```

---

## Integration with Other Components

**All plugin commands feed into this summary:**
- `/index-project` → Structure section
- `/resume` → Session section
- `/chunk` → Chunks section
- `/store-credential` → Credentials section
- Plan mode → Plan status section

**Use cases:**
- Daily standup summary
- Project handoff documentation
- Progress reporting
- Context restoration after interruptions

---

## Performance

**Fast execution:**
- Only reads JSON files (no scanning)
- Cached data from previous operations
- Typical runtime: <1 second

**When to refresh:**
- If structure seems outdated, run `/index-project`
- If session state incorrect, run `/resume --force`

---

## Related Commands

- `/index-project` - Refresh structure data
- `/resume` - Restore detailed session context
- `/chunk --list` - See all chunks
- `/list-credentials` - View credential names
