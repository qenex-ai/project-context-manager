---
name: navigate
description: Navigate between project phases/chunks with automatic context loading
allowed-tools:
  - Bash
  - Read
  - Write
---

# Navigate Command

## High-Level Overview

Jump between project chunks with automatic file loading and context restoration. Enables:
- Quick phase switching
- Automatic context loading
- Dependency-aware navigation
- Progress tracking

**When to use:** When working across different project areas, exploring codebases, or following implementation flows.

---

## Execution Flow

### Level 1: Core Operations

**Navigate to phase:** `/navigate --phase "API Layer"`
1. Find matching chunk
2. Load chunk files
3. Display chunk summary
4. Update session state

**Navigate sequentially:** `/navigate --next` or `/navigate --prev`
1. Get current chunk index
2. Calculate next/previous
3. Load new chunk
4. Update state

**Search chunks:** `/navigate --search "auth"`
1. Search chunk names/descriptions
2. Display matches
3. Prompt for selection

### Level 2: Detailed Implementation

#### Operation: Navigate to Specific Phase (`--phase`)

##### Step 1: Load Chunk Definitions

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"

if [ ! -f "$CHUNKS_FILE" ]; then
  echo "No chunks found. Run /chunk --create first."
  exit 1
fi

TARGET_PHASE="$1"
```

##### Step 2: Find Matching Chunk

```bash
# Search for chunk by name (case-insensitive)
CHUNK_INDEX=$(jq -r ".chunks | to_entries[] | select(.value.name | ascii_downcase | contains(\"$TARGET_PHASE\" | ascii_downcase)) | .key" "$CHUNKS_FILE" | head -1)

if [ -z "$CHUNK_INDEX" ]; then
  echo "No chunk found matching: $TARGET_PHASE"
  echo ""
  echo "Available chunks:"
  jq -r '.chunks[].name' "$CHUNKS_FILE"
  exit 1
fi
```

##### Step 3: Load Chunk Details

```bash
CHUNK_DATA=$(jq ".chunks[$CHUNK_INDEX]" "$CHUNKS_FILE")
CHUNK_NAME=$(echo "$CHUNK_DATA" | jq -r '.name')
CHUNK_DESC=$(echo "$CHUNK_DATA" | jq -r '.description')
CHUNK_FILES=$(echo "$CHUNK_DATA" | jq -r '.files[]')
FILE_COUNT=$(echo "$CHUNK_FILES" | wc -l)

echo "Navigating to: $CHUNK_NAME"
echo "Files: $FILE_COUNT"
```

##### Step 4: Display Chunk Summary

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  $CHUNK_NAME"
echo "═══════════════════════════════════════════════"
echo ""
echo "$CHUNK_DESC"
echo ""

# Show directory structure
if [ -n "$(echo "$CHUNK_DATA" | jq -r '.directory // empty')" ]; then
  echo "Directory: $(echo "$CHUNK_DATA" | jq -r '.directory')"
  echo ""
fi

# Show key files (entry points, main modules)
echo "Key files:"
echo "$CHUNK_FILES" | grep -E "(main|__init__|index|app|mod)" | head -5 | while read -r file; do
  echo "  • $file"
done
```

##### Step 5: Load File Context

```bash
echo ""
echo "Loading context..."

# Load first 3 files
COUNTER=0
echo "$CHUNK_FILES" | head -3 | while read -r file; do
  COUNTER=$((COUNTER + 1))
  if [ -f "$PROJECT_ROOT/$file" ]; then
    echo "  [$COUNTER] $file"
    # File automatically loaded into context
  fi
done

if [ "$FILE_COUNT" -gt 3 ]; then
  echo "  ... and $((FILE_COUNT - 3)) more files in chunk"
fi
```

##### Step 6: Show Dependencies

```bash
echo ""
echo "Dependencies/Imports:"

# Extract imports from first file
FIRST_FILE=$(echo "$CHUNK_FILES" | head -1)
if [ -f "$PROJECT_ROOT/$FIRST_FILE" ]; then
  # Python imports
  if [[ "$FIRST_FILE" == *.py ]]; then
    grep -E "^from |^import " "$PROJECT_ROOT/$FIRST_FILE" | head -10 | sed 's/^/  /'
  fi

  # Rust uses
  if [[ "$FIRST_FILE" == *.rs ]]; then
    grep -E "^use " "$PROJECT_ROOT/$FIRST_FILE" | head -10 | sed 's/^/  /'
  fi

  # Go imports
  if [[ "$FIRST_FILE" == *.go ]]; then
    awk '/^import \(/,/^\)/' "$PROJECT_ROOT/$FIRST_FILE" | grep -v "^import\|^)" | sed 's/^/  /'
  fi
fi
```

##### Step 7: Update Session State

```bash
# Update current chunk in session state
STATE_FILE="$PROJECT_ROOT/.claude/.project-state.json"

if [ -f "$STATE_FILE" ]; then
  jq ".current_chunk_index = $CHUNK_INDEX | .current_phase = \"$CHUNK_NAME\" | .last_navigation = \"$(date -Iseconds)\"" \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

echo ""
echo "✓ Navigation complete"
```

#### Operation: Navigate Next/Previous (`--next`, `--prev`)

##### Step 1: Get Current Position

```bash
STATE_FILE="$PROJECT_ROOT/.claude/.project-state.json"
CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"

CURRENT_INDEX=$(jq -r '.current_chunk_index // 0' "$STATE_FILE")
TOTAL_CHUNKS=$(jq '.chunks | length' "$CHUNKS_FILE")
```

##### Step 2: Calculate New Position

```bash
if [ "$DIRECTION" = "next" ]; then
  NEW_INDEX=$(( (CURRENT_INDEX + 1) % TOTAL_CHUNKS ))
else
  NEW_INDEX=$(( (CURRENT_INDEX - 1 + TOTAL_CHUNKS) % TOTAL_CHUNKS ))
fi

NEW_CHUNK_NAME=$(jq -r ".chunks[$NEW_INDEX].name" "$CHUNKS_FILE")

echo "Moving to: $NEW_CHUNK_NAME"
```

##### Step 3: Load New Chunk

(Same as steps 3-7 from phase navigation)

#### Operation: Search Chunks (`--search`)

##### Step 1: Search Implementation

```bash
SEARCH_TERM="$1"
CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"

# Search in chunk names and descriptions
MATCHES=$(jq -r ".chunks | to_entries[] | select(.value.name | ascii_downcase | contains(\"$SEARCH_TERM\" | ascii_downcase)) | .key,.value.name,.value.description" "$CHUNKS_FILE" | paste -sd '|||' | sed 's/|||/\n/g')

if [ -z "$MATCHES" ]; then
  # Try description search
  MATCHES=$(jq -r ".chunks | to_entries[] | select(.value.description | ascii_downcase | contains(\"$SEARCH_TERM\" | ascii_downcase)) | .key,.value.name,.value.description" "$CHUNKS_FILE" | paste -sd '|||' | sed 's/|||/\n/g')
fi

if [ -z "$MATCHES" ]; then
  echo "No chunks found matching: $SEARCH_TERM"
  exit 1
fi
```

##### Step 2: Display Matches

```bash
echo "Found matching chunks:"
echo "$MATCHES" | while IFS='|' read -r index name desc; do
  echo ""
  echo "[$index] $name"
  echo "    $desc"
done

echo ""
echo "Navigate to chunk by running: /navigate --phase \"<name>\""
```

---

## Arguments

- `--phase <name>` - Navigate to specific phase (partial matching)
- `--next` - Move to next chunk
- `--prev` - Move to previous chunk
- `--search <term>` - Search chunks by name or description
- `--index <n>` - Navigate to chunk by index number

---

## Output Formats

### Navigate to Phase

```
Navigating to: Phase 2: API Layer
Files: 87

═══════════════════════════════════════════════
  Phase 2: API Layer
═══════════════════════════════════════════════

REST API endpoints and request handlers. Implements
authentication, rate limiting, and data validation.

Directory: src/api

Key files:
  • src/api/__init__.py
  • src/api/main.py
  • src/api/app.py

Loading context...
  [1] src/api/endpoints.py
  [2] src/api/auth.py
  [3] src/api/middleware.py
  ... and 84 more files in chunk

Dependencies/Imports:
  from fastapi import FastAPI, HTTPException
  from fastapi.middleware.cors import CORSMiddleware
  from src.database import get_db_session
  from src.models import User, Token
  from src.utils import verify_token
  import logging
  import os

✓ Navigation complete
```

### Navigate Next

```
Moving to: Phase 3: Database Models

═══════════════════════════════════════════════
  Phase 3: Database Models
═══════════════════════════════════════════════

SQLAlchemy ORM models and database migrations.
Includes user models, trading data, and audit logs.

Directory: src/models

Loading context...
  [1] src/models/__init__.py
  [2] src/models/user.py
  [3] src/models/trading.py
  ... and 62 more files in chunk

✓ Navigation complete
```

### Search Results

```
Found matching chunks:

[1] Phase 1: Authentication
    User authentication with JWT tokens and session management

[4] Phase 4: Trading Engine
    High-frequency trading algorithms with authentication checks

Navigate to chunk by running: /navigate --phase "Authentication"
```

---

## Navigation Patterns

### Sequential Workflow

```bash
/chunk --create          # Create chunks
/navigate --phase "Setup" # Start at beginning
/navigate --next         # Move through phases
/navigate --next
/navigate --next
```

### Feature Exploration

```bash
/navigate --search "auth"  # Find authentication chunks
/navigate --phase "Auth"   # Jump to authentication
/navigate --search "test"  # Find related tests
/navigate --phase "Testing Auth"
```

### Dependency Following

```bash
/navigate --phase "API"    # Start at API layer
# See imports: "from src.models import User"
/navigate --phase "Models" # Jump to models
# See imports: "from src.database import Base"
/navigate --phase "Database"
```

---

## Integration with Other Components

**Chunk Command:**
- Chunks must be created first with `/chunk --create`
- Navigation uses chunk definitions from `.claude/.chunks.json`

**Session Management:**
- Current chunk position saved automatically
- Restored on `/resume`

**Plan Mode:**
- Can navigate to plan phase by name
- Plan phases map to chunk phases

---

## Keyboard-Like Navigation

Think of chunks as "chapters" in the codebase:

- `/navigate --next` = Turn page forward
- `/navigate --prev` = Turn page backward
- `/navigate --search <term>` = Index lookup
- `/navigate --phase <name>` = Jump to chapter

---

## Performance Considerations

**Large chunks (>100 files):**
- Only first 3 files loaded initially
- Additional files loaded on demand
- Use `/chunk --create` with finer granularity

**Context loading:**
- Files load into context window
- Previous chunk context remains unless cleared
- Use `/clear` before navigation if needed

---

## Related Skills

This command uses the **chunk-navigation** skill. For detailed information about navigation strategies, context management, and dependency tracking, refer to:

`$CLAUDE_PLUGIN_ROOT/skills/chunk-navigation/SKILL.md` (to be created)
