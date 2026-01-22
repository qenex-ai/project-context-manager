---
name: chunk
description: Create, view, or manage project chunks organized by semantic phases
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Chunk Command

## High-Level Overview

Organize large projects into navigable chunks based on semantic phases (not arbitrary line counts). Enables:
- Logical project navigation
- Phase-based context loading
- Progress tracking per phase
- Manageable context windows

**When to use:** After indexing a new project, when project structure changes, or to view current chunk status.

**Philosophy:** Chunks represent logical work phases (e.g., "Authentication", "API Layer", "Testing") rather than file-size boundaries.

---

## Execution Flow

### Level 1: Core Operations

**Create chunks:** `/ chunk --create`
1. Load project index
2. Analyze file relationships
3. Identify semantic phases
4. Generate chunk definitions
5. Save to `.claude/.chunks.json`

**View current:** `/chunk --current`
1. Load chunk definitions
2. Find active chunk
3. Display chunk summary

**List all:** `/chunk --list`
1. Load chunk definitions
2. Display all chunks with progress

### Level 2: Detailed Implementation

#### Operation: Create Chunks (`--create`)

##### Step 1: Load Project Context

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# Load project index
INDEX_FILE="$PROJECT_ROOT/.claude/.project-index.json"
if [ ! -f "$INDEX_FILE" ]; then
  echo "No project index found. Run /index-project first."
  exit 1
fi

# Parse index
TOTAL_FILES=$(jq -r '.total_files' "$INDEX_FILE")
PRIMARY_LANGS=$(jq -r '.languages | to_entries[] | select(.value.primary == true) | .key' "$INDEX_FILE")

echo "Creating chunks for $PROJECT_NAME ($TOTAL_FILES files)..."
```

##### Step 2: Identify Directory Structure

```bash
# Find major directories
SRC_DIRS=$(jq -r '.structure.src_dirs[]?' "$INDEX_FILE")
TEST_DIRS=$(jq -r '.structure.test_dirs[]?' "$INDEX_FILE")
DOC_DIRS=$(jq -r '.structure.doc_dirs[]?' "$INDEX_FILE")

# Find feature directories (common patterns)
FEATURE_DIRS=$(find . -maxdepth 3 -type d \( \
  -name "auth*" -o \
  -name "api*" -o \
  -name "database" -o -name "db" -o \
  -name "models" -o \
  -name "services" -o \
  -name "controllers" -o \
  -name "handlers" -o \
  -name "middleware" -o \
  -name "utils" -o \
  -name "core" \
  \) ! -path "*/node_modules/*" ! -path "*/.git/*" | sed 's|^\./||')
```

##### Step 3: Analyze File Relationships

Group files by imports and dependencies:

```bash
# For Python files, group by import patterns
if echo "$PRIMARY_LANGS" | grep -q "python"; then
  # Find files that import from common modules
  grep -r "^from \|^import " --include="*.py" . | \
    sed 's/:from /:/; s/:import /:/; s/ import.*//; s/ as.*//' | \
    sort | uniq > /tmp/python_imports.txt
fi

# For Rust, use module declarations
if echo "$PRIMARY_LANGS" | grep -q "rust"; then
  grep -r "^mod \|^use " --include="*.rs" . | \
    sed 's/:mod /:/; s/:use /:/; s/::.*//' | \
    sort | uniq > /tmp/rust_modules.txt
fi
```

##### Step 4: Define Semantic Phases

Create chunks based on common patterns:

```bash
# Initialize chunks array
CHUNKS='[]'

# Chunk 1: Project Setup & Configuration
CONFIG_FILES=$(find . -maxdepth 2 -type f \( \
  -name "*.toml" -o -name "*.yaml" -o -name "*.json" -o \
  -name "Dockerfile" -o -name "Makefile" -o -name ".env*" \
  \) ! -path "*/node_modules/*" | sed 's|^\./||')

if [ -n "$CONFIG_FILES" ]; then
  CHUNKS=$(echo "$CHUNKS" | jq '. += [{
    "name": "Phase 0: Project Setup",
    "description": "Configuration files, build setup, and project structure",
    "files": $files,
    "priority": 0
  }]' --argjson files "$(echo "$CONFIG_FILES" | jq -R -s 'split("\n") | map(select(length > 0))')")
fi

# Chunk 2-N: Feature-based chunks
CHUNK_NUM=1
echo "$FEATURE_DIRS" | while read -r dir; do
  if [ -z "$dir" ]; then continue; fi

  # Get all files in this directory
  DIR_FILES=$(find "$dir" -type f \( \
    -name "*.py" -o -name "*.rs" -o -name "*.go" -o \
    -name "*.js" -o -name "*.ts" -o -name "*.jl" \
    \) | sed 's|^\./||')

  FILE_COUNT=$(echo "$DIR_FILES" | wc -l)
  if [ "$FILE_COUNT" -lt 3 ]; then continue; fi

  # Create human-readable phase name
  PHASE_NAME=$(echo "$dir" | sed 's|.*/||; s|_| |g; s|\b\(.\)|\u\1|g')

  # Generate description from directory purpose
  DESC=$(head -20 "$DIR_FILES" | head -1 | grep -E "^(//|#|\"\"\")" | sed 's|^[/#"]*||; s|"""$||')

  CHUNKS=$(echo "$CHUNKS" | jq ". += [{
    \"name\": \"Phase $CHUNK_NUM: $PHASE_NAME\",
    \"description\": \"$DESC\",
    \"files\": \$files,
    \"directory\": \"$dir\",
    \"priority\": $CHUNK_NUM
  }]" --argjson files "$(echo "$DIR_FILES" | jq -R -s 'split("\n") | map(select(length > 0))')")

  CHUNK_NUM=$((CHUNK_NUM + 1))
done

# Final chunk: Tests
TEST_FILES=$(find . -path "*/test*" -type f \( \
  -name "*.py" -o -name "*.rs" -o -name "*.go" -o -name "*.js" \
  \) | sed 's|^\./||')

if [ -n "$TEST_FILES" ]; then
  CHUNKS=$(echo "$CHUNKS" | jq ". += [{
    \"name\": \"Phase X: Testing\",
    \"description\": \"Test suites and test utilities\",
    \"files\": \$files,
    \"priority\": 99
  }]" --argjson files "$(echo "$TEST_FILES" | jq -R -s 'split("\n") | map(select(length > 0))')")
fi
```

##### Step 5: Save Chunk Definitions

```bash
# Create chunks metadata
CHUNK_METADATA=$(cat <<EOF
{
  "project_name": "$PROJECT_NAME",
  "created_at": "$(date -Iseconds)",
  "total_chunks": $(echo "$CHUNKS" | jq 'length'),
  "strategy": "phase-based",
  "chunks": $CHUNKS
}
EOF
)

# Save to file
echo "$CHUNK_METADATA" | jq '.' > "$PROJECT_ROOT/.claude/.chunks.json"

echo "✓ Created $(echo "$CHUNKS" | jq 'length') chunks"
```

##### Step 6: Display Chunk Summary

```bash
echo ""
echo "═══ Project Chunks ═══"
echo "$CHUNKS" | jq -r '.[] | "\(.name)\n  Files: \(.files | length)\n  \(.description)\n"'
```

#### Operation: View Current Chunk (`--current`)

```bash
# Load state to find current chunk
STATE_FILE="$PROJECT_ROOT/.claude/.project-state.json"
CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"

if [ ! -f "$STATE_FILE" ] || [ ! -f "$CHUNKS_FILE" ]; then
  echo "No active session or chunks found"
  exit 1
fi

# Get current chunk index
CHUNK_INDEX=$(jq -r '.current_chunk_index // 0' "$STATE_FILE")

# Get chunk details
CHUNK_DATA=$(jq ".chunks[$CHUNK_INDEX]" "$CHUNKS_FILE")

echo "═══ Current Chunk ═══"
echo "Name: $(echo "$CHUNK_DATA" | jq -r '.name')"
echo "Description: $(echo "$CHUNK_DATA" | jq -r '.description')"
echo ""
echo "Files ($(echo "$CHUNK_DATA" | jq '.files | length')):"
echo "$CHUNK_DATA" | jq -r '.files[]' | head -10 | while read -r file; do
  echo "  • $file"
done

FILE_COUNT=$(echo "$CHUNK_DATA" | jq '.files | length')
if [ "$FILE_COUNT" -gt 10 ]; then
  echo "  ... and $((FILE_COUNT - 10)) more files"
fi
```

#### Operation: List All Chunks (`--list`)

```bash
CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"

if [ ! -f "$CHUNKS_FILE" ]; then
  echo "No chunks found. Run /chunk --create first."
  exit 1
fi

echo "═══ All Chunks for $PROJECT_NAME ═══"
jq -r '.chunks[] | "\n\(.name)\n  Files: \(.files | length)\n  \(.description)"' "$CHUNKS_FILE"

TOTAL=$(jq '.total_chunks' "$CHUNKS_FILE")
echo ""
echo "Total: $TOTAL chunks"
```

---

## Arguments

- `--create` - Create new chunk definitions (analyzes project structure)
- `--current` - Show currently active chunk
- `--list` - List all chunks
- `--strategy <type>` - Chunking strategy: phase-based (default), module-based, file-based

---

## Output Formats

### Create Chunks

```
Creating chunks for qenex (1,247 files)...

✓ Created 8 chunks

═══ Project Chunks ═══
Phase 0: Project Setup
  Files: 15
  Configuration files, build setup, and project structure

Phase 1: Authentication
  Files: 42
  User authentication with JWT tokens and session management

Phase 2: API Layer
  Files: 87
  REST API endpoints and request handlers

Phase 3: Database Models
  Files: 65
  SQLAlchemy models and database migrations

Phase 4: Trading Engine
  Files: 143
  High-frequency trading algorithms and order execution

Phase 5: Blockchain Integration
  Files: 98
  Smart contract interactions and blockchain node connections

Phase 6: Monitoring
  Files: 54
  Prometheus metrics, Grafana dashboards, and alerting

Phase X: Testing
  Files: 312
  Test suites and test utilities
```

### View Current

```
═══ Current Chunk ═══
Name: Phase 2: API Layer
Description: REST API endpoints and request handlers

Files (87):
  • src/api/endpoints.py
  • src/api/auth.py
  • src/api/middleware.py
  • src/api/models.py
  • src/api/validators.py
  • src/api/serializers.py
  • src/api/routes.py
  • src/api/__init__.py
  • tests/test_api.py
  • tests/test_auth.py
  ... and 77 more files
```

---

## Chunking Strategies

### Phase-Based (Default)

Groups files by logical project phases:
- Setup/Configuration
- Core features (auth, API, database, etc.)
- Testing
- Documentation

**Best for:** Most projects, especially those with clear feature separation

### Module-Based

Groups files by language module structure:
- Python packages
- Rust crates
- Go packages

**Best for:** Large monorepos with many submodules

### File-Based

Groups files by type and directory:
- All Python files
- All Rust files
- All configuration

**Best for:** Small projects or simple analysis

---

## Integration with Other Components

**Navigation Command:**
- `/navigate --phase "API Layer"` jumps to specific chunk
- `/navigate --next` moves to next chunk

**Session Management:**
- Current chunk saved in session state
- Restored on `/resume`

**Plan Mode:**
- Chunks can define plan phases
- Progress tracked per chunk

---

## Best Practices

**When to re-chunk:**
- After major refactoring
- When adding significant features
- When directory structure changes

**Chunk size guidelines:**
- Target: 30-100 files per chunk
- Avoid chunks with >200 files (subdivide)
- Merge chunks with <10 files

**Naming conventions:**
- Use "Phase N:" prefix for clarity
- Use descriptive feature names
- Keep names concise (<30 characters)

---

## Related Skills

This command uses the **chunk-navigation** skill. For detailed information about semantic chunking algorithms, chunk strategies, and navigation patterns, refer to:

`$CLAUDE_PLUGIN_ROOT/skills/chunk-navigation/SKILL.md` (to be created)
