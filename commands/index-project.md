---
name: index-project
description: Scan and index current project structure, languages, dependencies, and key files for multi-language codebases
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Index Project Command

## High-Level Overview

Analyze the current project to create a comprehensive index of its structure, languages, dependencies, and key files. This index enables:
- Fast project navigation
- Language-aware chunking
- Dependency tracking
- Session resumption context
- Plan mode integration

**When to use:** Run when starting work on a new project, after switching projects, or when project structure changes significantly.

---

## Execution Flow

### Level 1: Core Process

1. **Detect project root** → Find git repository or current directory
2. **Scan file structure** → Identify all source files, configs, and documentation
3. **Detect languages** → Identify Python, Rust, Go, Julia, Elixir, C++, Zig, JavaScript, etc.
4. **Extract dependencies** → Parse package managers (Cargo.toml, package.json, requirements.txt, go.mod, etc.)
5. **Identify key files** → Find entry points, configs, tests, documentation
6. **Generate index** → Create `.claude/.project-index.json`
7. **Display summary** → Show languages, file counts, dependencies

### Level 2: Detailed Steps

#### Step 1: Project Root Detection

```bash
# Determine project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
cd "$PROJECT_ROOT"

echo "Indexing project: $PROJECT_NAME"
echo "Location: $PROJECT_ROOT"
```

#### Step 2: File Structure Scan

```bash
# Create index directory if needed
mkdir -p .claude

# Scan all files (excluding common ignore patterns)
find . -type f \
  ! -path "*/node_modules/*" \
  ! -path "*/.git/*" \
  ! -path "*/venv/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  ! -path "*/target/debug/*" \
  ! -path "*/target/release/*" \
  > /tmp/project_files.txt

TOTAL_FILES=$(wc -l < /tmp/project_files.txt)
echo "Found $TOTAL_FILES files"
```

#### Step 3: Language Detection

For each file extension, determine language:

```bash
# Count by extension
echo "Detecting languages..."

PYTHON_FILES=$(grep -E '\.(py|pyw)$' /tmp/project_files.txt | wc -l)
RUST_FILES=$(grep -E '\.rs$' /tmp/project_files.txt | wc -l)
GO_FILES=$(grep -E '\.go$' /tmp/project_files.txt | wc -l)
JULIA_FILES=$(grep -E '\.jl$' /tmp/project_files.txt | wc -l)
ELIXIR_FILES=$(grep -E '\.(ex|exs)$' /tmp/project_files.txt | wc -l)
CPP_FILES=$(grep -E '\.(cpp|cc|cxx|h|hpp)$' /tmp/project_files.txt | wc -l)
ZIG_FILES=$(grep -E '\.zig$' /tmp/project_files.txt | wc -l)
JS_FILES=$(grep -E '\.(js|jsx|ts|tsx)$' /tmp/project_files.txt | wc -l)

# Determine primary language
LANGUAGES=()
[ $PYTHON_FILES -gt 0 ] && LANGUAGES+=("Python:$PYTHON_FILES")
[ $RUST_FILES -gt 0 ] && LANGUAGES+=("Rust:$RUST_FILES")
[ $GO_FILES -gt 0 ] && LANGUAGES+=("Go:$GO_FILES")
[ $JULIA_FILES -gt 0 ] && LANGUAGES+=("Julia:$JULIA_FILES")
[ $ELIXIR_FILES -gt 0 ] && LANGUAGES+=("Elixir:$ELIXIR_FILES")
[ $CPP_FILES -gt 0 ] && LANGUAGES+=("C++:$CPP_FILES")
[ $ZIG_FILES -gt 0 ] && LANGUAGES+=("Zig:$ZIG_FILES")
[ $JS_FILES -gt 0 ] && LANGUAGES+=("JavaScript:$JS_FILES")
```

#### Step 4: Dependency Extraction

Scan for dependency manifests and extract packages:

**Rust (Cargo.toml):**
```bash
if [ -f "Cargo.toml" ]; then
  RUST_DEPS=$(grep -E '^\s*[a-z0-9_-]+ = ' Cargo.toml | wc -l)
  echo "  Rust dependencies: $RUST_DEPS"
fi
```

**Python (requirements.txt, pyproject.toml):**
```bash
if [ -f "requirements.txt" ]; then
  PYTHON_DEPS=$(grep -v '^#' requirements.txt | grep -v '^$' | wc -l)
  echo "  Python dependencies: $PYTHON_DEPS"
elif [ -f "pyproject.toml" ]; then
  PYTHON_DEPS=$(grep -A 100 '\[tool.poetry.dependencies\]' pyproject.toml | grep -E '^\s*[a-z0-9_-]+ = ' | wc -l)
  echo "  Python dependencies: $PYTHON_DEPS"
fi
```

**JavaScript (package.json):**
```bash
if [ -f "package.json" ]; then
  JS_DEPS=$(jq -r '.dependencies // {} | length' package.json 2>/dev/null || echo "0")
  echo "  JavaScript dependencies: $JS_DEPS"
fi
```

**Go (go.mod):**
```bash
if [ -f "go.mod" ]; then
  GO_DEPS=$(grep -E '^\s+[a-z]' go.mod | wc -l)
  echo "  Go dependencies: $GO_DEPS"
fi
```

**Elixir (mix.exs):**
```bash
if [ -f "mix.exs" ]; then
  ELIXIR_DEPS=$(grep -A 100 'defp deps do' mix.exs | grep -E '^\s*\{:' | wc -l)
  echo "  Elixir dependencies: $ELIXIR_DEPS"
fi
```

#### Step 5: Key File Identification

Find important files by pattern matching:

**Entry points:**
```bash
ENTRY_POINTS=$(find . -maxdepth 3 -type f \( \
  -name "main.py" -o \
  -name "main.rs" -o \
  -name "main.go" -o \
  -name "app.py" -o \
  -name "index.js" -o \
  -name "index.ts" \
  \) ! -path "*/node_modules/*" ! -path "*/.git/*")
```

**Configuration files:**
```bash
CONFIGS=$(find . -maxdepth 2 -type f \( \
  -name "*.toml" -o \
  -name "*.yaml" -o \
  -name "*.yml" -o \
  -name "*.json" -o \
  -name ".env*" \
  \) ! -path "*/node_modules/*" ! -path "*/.git/*")
```

**Documentation:**
```bash
DOCS=$(find . -maxdepth 2 -type f \( \
  -name "README*" -o \
  -name "CONTRIBUTING*" -o \
  -name "LICENSE*" -o \
  -name "CHANGELOG*" \
  \))
```

#### Step 6: Generate Index JSON

Create comprehensive project index:

```bash
cat > .claude/.project-index.json <<EOF
{
  "project_name": "$PROJECT_NAME",
  "project_root": "$PROJECT_ROOT",
  "indexed_at": "$(date -Iseconds)",
  "total_files": $TOTAL_FILES,
  "languages": {
    "python": { "files": $PYTHON_FILES, "primary": $([ $PYTHON_FILES -gt 50 ] && echo "true" || echo "false") },
    "rust": { "files": $RUST_FILES, "primary": $([ $RUST_FILES -gt 20 ] && echo "true" || echo "false") },
    "go": { "files": $GO_FILES, "primary": $([ $GO_FILES -gt 20 ] && echo "true" || echo "false") },
    "julia": { "files": $JULIA_FILES, "primary": $([ $JULIA_FILES -gt 10 ] && echo "true" || echo "false") },
    "elixir": { "files": $ELIXIR_FILES, "primary": $([ $ELIXIR_FILES -gt 10 ] && echo "true" || echo "false") },
    "cpp": { "files": $CPP_FILES, "primary": $([ $CPP_FILES -gt 20 ] && echo "true" || echo "false") },
    "zig": { "files": $ZIG_FILES, "primary": $([ $ZIG_FILES -gt 10 ] && echo "true" || echo "false") },
    "javascript": { "files": $JS_FILES, "primary": $([ $JS_FILES -gt 30 ] && echo "true" || echo "false") }
  },
  "dependencies": {
    "rust": $([ -f "Cargo.toml" ] && grep -E '^\s*[a-z0-9_-]+ = ' Cargo.toml | wc -l || echo "0"),
    "python": $([ -f "requirements.txt" ] && grep -v '^#' requirements.txt | grep -v '^$' | wc -l || echo "0"),
    "javascript": $([ -f "package.json" ] && jq -r '.dependencies // {} | length' package.json 2>/dev/null || echo "0"),
    "go": $([ -f "go.mod" ] && grep -E '^\s+[a-z]' go.mod | wc -l || echo "0")
  },
  "key_files": {
    "entry_points": [$(echo "$ENTRY_POINTS" | sed 's|^\./||' | awk '{printf "\"%s\",", $0}' | sed 's/,$//')]
    "configs": [$(echo "$CONFIGS" | sed 's|^\./||' | head -10 | awk '{printf "\"%s\",", $0}' | sed 's/,$//')]
    "documentation": [$(echo "$DOCS" | sed 's|^\./||' | awk '{printf "\"%s\",", $0}' | sed 's/,$//')]
  },
  "structure": {
    "src_dirs": [$(find . -maxdepth 2 -type d -name "src" -o -name "lib" | sed 's|^\./||' | awk '{printf "\"%s\",", $0}' | sed 's/,$//')],
    "test_dirs": [$(find . -maxdepth 2 -type d -name "tests" -o -name "test" | sed 's|^\./||' | awk '{printf "\"%s\",", $0}' | sed 's/,$//')],
    "doc_dirs": [$(find . -maxdepth 2 -type d -name "docs" -o -name "doc" | sed 's|^\./||' | awk '{printf "\"%s\",", $0}' | sed 's/,$//')]
  }
}
EOF
```

#### Step 7: Display Summary

```bash
echo ""
echo "✓ Project indexed successfully"
echo ""
echo "═══ Project Summary ═══"
echo "Name: $PROJECT_NAME"
echo "Total Files: $TOTAL_FILES"
echo ""
echo "Languages:"
for lang in "${LANGUAGES[@]}"; do
  echo "  • $lang files"
done
echo ""
echo "Index saved: .claude/.project-index.json"
```

---

## Arguments

- `--force` - Re-index even if recent index exists
- `--quick` - Skip dependency extraction (faster)
- `--verbose` - Show detailed progress

---

## Output Format

### Standard Output

```
Indexing project: qenex
Location: /home/ubuntu/qenex
Found 1,247 files
Detecting languages...
  Python: 312 files
  Rust: 185 files
  Go: 94 files
  Julia: 23 files
  JavaScript: 156 files

Extracting dependencies...
  Rust dependencies: 47
  Python dependencies: 89
  JavaScript dependencies: 124

Identifying key files...
  Entry points: 8 found
  Configs: 15 found
  Documentation: 5 found

✓ Project indexed successfully

═══ Project Summary ═══
Name: qenex
Total Files: 1,247

Languages:
  • Python: 312 files (Primary)
  • Rust: 185 files (Primary)
  • Go: 94 files
  • JavaScript: 156 files (Primary)
  • Julia: 23 files

Index saved: .claude/.project-index.json
```

---

## Performance Considerations

**Large repositories (>10,000 files):**
- Use `--quick` to skip dependency parsing
- Index runs in ~5-15 seconds for typical projects
- Index is cached and reused until forced refresh

**Monorepos:**
- Index detects multiple languages automatically
- Each subproject's dependencies tracked separately
- Use chunking to navigate large codebases

---

## Integration with Other Components

**Session Management:**
- Index loaded on `/resume` for context restoration
- Tracks which files were last edited

**Chunk Navigation:**
- Index used to create semantic phase-based chunks
- Language information drives chunk boundaries

**Plan Mode:**
- Index informs plan generation
- Dependency graph helps identify task order

---

## Related Skills

This command uses the **project-indexing** skill. For detailed information about language detection algorithms, dependency parsing, and index structure, refer to:

`$CLAUDE_PLUGIN_ROOT/skills/project-indexing/SKILL.md` (to be created)
