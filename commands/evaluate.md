---
name: evaluate
description: Evaluate project progress, phase completion, and goal achievement with actionable recommendations
allowed-tools:
  - Bash
  - Read
  - Grep
---

# Evaluate Command

## High-Level Overview

Comprehensive project evaluation system that assesses:
- **Phase completion** - Are phases truly complete or just marked done?
- **Subphase quality** - Are implementation details solid?
- **Overall progress** - Is the project on track toward big goals?
- **Blockers & risks** - What's preventing progress?
- **Recommendations** - What should happen next?

**When to use:** After completing phases, before major milestones, or when progress feels unclear.

**Goal:** Clear visibility into project health and actionable next steps.

---

## Execution Flow

### Level 1: Evaluation Types

**Phase evaluation:** `/evaluate --phase "API Integration"`
1. Assess phase completion criteria
2. Check implementation quality
3. Verify tests and documentation
4. Provide recommendations

**Project evaluation:** `/evaluate --project`
1. Assess all phases
2. Calculate overall completion
3. Identify critical path
4. Compare against project goals
5. Provide strategic recommendations

**Quick check:** `/evaluate --quick`
1. Fast health check
2. Traffic light status (🟢🟡🔴)
3. Top 3 issues
4. Next action

### Level 2: Detailed Implementation

#### Operation: Evaluate Phase (`--phase`)

##### Step 1: Load Phase Context

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"
PHASE_NAME="$1"

# Find matching chunk
CHUNK_INDEX=$(jq -r ".chunks | to_entries[] | select(.value.name | ascii_downcase | contains(\"$PHASE_NAME\" | ascii_downcase)) | .key" "$CHUNKS_FILE" | head -1)

if [ -z "$CHUNK_INDEX" ]; then
  echo "Phase not found: $PHASE_NAME"
  exit 1
fi

CHUNK_DATA=$(jq ".chunks[$CHUNK_INDEX]" "$CHUNKS_FILE")
CHUNK_NAME=$(echo "$CHUNK_DATA" | jq -r '.name')
CHUNK_FILES=$(echo "$CHUNK_DATA" | jq -r '.files[]')
```

##### Step 2: Assess Completion Criteria

```bash
echo "═══════════════════════════════════════════════"
echo "  Phase Evaluation: $CHUNK_NAME"
echo "═══════════════════════════════════════════════"
echo ""

# Criteria checklist
CRITERIA=(
  "Implementation complete"
  "Tests written and passing"
  "Documentation updated"
  "Code reviewed"
  "No TODOs or FIXMEs remaining"
  "Error handling implemented"
  "Security reviewed"
  "Performance acceptable"
)

SCORE=0
MAX_SCORE=0

# Check implementation files exist
FILE_COUNT=$(echo "$CHUNK_FILES" | wc -l)
EXISTING_FILES=0

echo "1. Implementation Completeness"
echo ""
for file in $CHUNK_FILES; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    EXISTING_FILES=$((EXISTING_FILES + 1))
  fi
done

IMPL_SCORE=$((EXISTING_FILES * 100 / FILE_COUNT))
if [ "$IMPL_SCORE" -eq 100 ]; then
  echo "   ✓ All files present (${EXISTING_FILES}/${FILE_COUNT})"
  SCORE=$((SCORE + 15))
elif [ "$IMPL_SCORE" -ge 80 ]; then
  echo "   ⚠ Most files present (${EXISTING_FILES}/${FILE_COUNT})"
  SCORE=$((SCORE + 10))
else
  echo "   ✗ Many files missing (${EXISTING_FILES}/${FILE_COUNT})"
  SCORE=$((SCORE + 5))
fi
MAX_SCORE=$((MAX_SCORE + 15))
echo ""
```

##### Step 3: Check Tests

```bash
echo "2. Test Coverage"
echo ""

# Find test files related to this phase
TEST_FILES=$(echo "$CHUNK_FILES" | grep -E "test_|_test\.py|\.test\.|_spec\.")
TEST_COUNT=$(echo "$TEST_FILES" | grep -v '^$' | wc -l)

if [ "$TEST_COUNT" -gt 0 ]; then
  echo "   ✓ Test files found: $TEST_COUNT"

  # Check if tests pass (try common test commands)
  if grep -q "pytest" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
    TEST_RESULT=$(cd "$PROJECT_ROOT" && pytest $TEST_FILES --quiet 2>&1 || echo "FAILED")
    if echo "$TEST_RESULT" | grep -q "FAILED"; then
      echo "   ✗ Some tests failing"
      SCORE=$((SCORE + 5))
    else
      echo "   ✓ Tests passing"
      SCORE=$((SCORE + 15))
    fi
  else
    echo "   ⚠ Tests exist but not run"
    SCORE=$((SCORE + 10))
  fi
else
  echo "   ✗ No test files found"
  SCORE=$((SCORE + 0))
fi
MAX_SCORE=$((MAX_SCORE + 15))
echo ""
```

##### Step 4: Check Documentation

```bash
echo "3. Documentation"
echo ""

# Check for docstrings, comments, README updates
DOC_SCORE=0

# Look for docstrings/comments in files
for file in $CHUNK_FILES; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    # Python docstrings
    if [[ "$file" == *.py ]]; then
      DOCSTRINGS=$(grep -c '"""' "$PROJECT_ROOT/$file" 2>/dev/null || echo "0")
      if [ "$DOCSTRINGS" -gt 2 ]; then
        DOC_SCORE=$((DOC_SCORE + 1))
      fi
    fi

    # Rust doc comments
    if [[ "$file" == *.rs ]]; then
      DOC_COMMENTS=$(grep -c '///' "$PROJECT_ROOT/$file" 2>/dev/null || echo "0")
      if [ "$DOC_COMMENTS" -gt 2 ]; then
        DOC_SCORE=$((DOC_SCORE + 1))
      fi
    fi
  fi
done

if [ "$DOC_SCORE" -gt "$((FILE_COUNT / 2))" ]; then
  echo "   ✓ Good documentation coverage"
  SCORE=$((SCORE + 10))
elif [ "$DOC_SCORE" -gt 0 ]; then
  echo "   ⚠ Some documentation present"
  SCORE=$((SCORE + 5))
else
  echo "   ✗ Missing documentation"
  SCORE=$((SCORE + 0))
fi
MAX_SCORE=$((MAX_SCORE + 10))
echo ""
```

##### Step 5: Check Code Quality

```bash
echo "4. Code Quality"
echo ""

# Check for TODO/FIXME/HACK comments
TODO_COUNT=0
for file in $CHUNK_FILES; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    TODOS=$(grep -Eic "TODO|FIXME|HACK" "$PROJECT_ROOT/$file" 2>/dev/null || echo "0")
    TODO_COUNT=$((TODO_COUNT + TODOS))
  fi
done

if [ "$TODO_COUNT" -eq 0 ]; then
  echo "   ✓ No TODOs/FIXMEs found"
  SCORE=$((SCORE + 10))
elif [ "$TODO_COUNT" -lt 5 ]; then
  echo "   ⚠ Minor TODOs remaining ($TODO_COUNT)"
  SCORE=$((SCORE + 7))
else
  echo "   ✗ Many TODOs remaining ($TODO_COUNT)"
  SCORE=$((SCORE + 3))
fi
MAX_SCORE=$((MAX_SCORE + 10))
echo ""
```

##### Step 6: Check Security

```bash
echo "5. Security Review"
echo ""

# Check for common security issues
SECURITY_ISSUES=0

for file in $CHUNK_FILES; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    # Check for hardcoded credentials
    if grep -Eq "password.*=.*['\"][^'\"]{8,}|api_key.*=.*['\"][^'\"]{20,}" "$PROJECT_ROOT/$file" 2>/dev/null; then
      echo "   ✗ Potential hardcoded credential in $file"
      SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
    fi

    # Check for SQL injection risks (Python)
    if [[ "$file" == *.py ]] && grep -Eq "execute.*%|execute.*format\(" "$PROJECT_ROOT/$file" 2>/dev/null; then
      echo "   ⚠ Potential SQL injection risk in $file"
      SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
    fi
  fi
done

if [ "$SECURITY_ISSUES" -eq 0 ]; then
  echo "   ✓ No obvious security issues"
  SCORE=$((SCORE + 15))
else
  echo "   ✗ Security issues found: $SECURITY_ISSUES"
  SCORE=$((SCORE + 5))
fi
MAX_SCORE=$((MAX_SCORE + 15))
echo ""
```

##### Step 7: Check Git Integration

```bash
echo "6. Version Control"
echo ""

# Check if files are committed
UNCOMMITTED=0
for file in $CHUNK_FILES; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    if git status --porcelain "$PROJECT_ROOT/$file" 2>/dev/null | grep -q "^??"; then
      UNCOMMITTED=$((UNCOMMITTED + 1))
    fi
  fi
done

if [ "$UNCOMMITTED" -eq 0 ]; then
  echo "   ✓ All files committed"
  SCORE=$((SCORE + 10))
else
  echo "   ⚠ Uncommitted files: $UNCOMMITTED"
  SCORE=$((SCORE + 5))
fi
MAX_SCORE=$((MAX_SCORE + 10))
echo ""
```

##### Step 8: Calculate Score & Recommendations

```bash
PERCENTAGE=$((SCORE * 100 / MAX_SCORE))

echo "═══════════════════════════════════════════════"
echo "  Phase Score: $SCORE / $MAX_SCORE ($PERCENTAGE%)"
echo "═══════════════════════════════════════════════"
echo ""

# Determine status
if [ "$PERCENTAGE" -ge 90 ]; then
  STATUS="🟢 EXCELLENT"
  RECOMMENDATION="Phase is production-ready. Consider moving to next phase."
elif [ "$PERCENTAGE" -ge 75 ]; then
  STATUS="🟢 GOOD"
  RECOMMENDATION="Phase is mostly complete. Address remaining items before proceeding."
elif [ "$PERCENTAGE" -ge 60 ]; then
  STATUS="🟡 FAIR"
  RECOMMENDATION="Phase needs work. Focus on missing tests and documentation."
elif [ "$PERCENTAGE" -ge 40 ]; then
  STATUS="🟡 NEEDS WORK"
  RECOMMENDATION="Significant gaps remain. Complete implementation before moving forward."
else
  STATUS="🔴 INCOMPLETE"
  RECOMMENDATION="Phase is not ready. Focus on core implementation first."
fi

echo "Status: $STATUS"
echo ""
echo "Recommendation:"
echo "  $RECOMMENDATION"
echo ""
```

##### Step 9: Actionable Next Steps

```bash
echo "Next Steps:"
echo ""

# Generate specific actions based on gaps
if [ "$TEST_COUNT" -eq 0 ]; then
  echo "  1. Write tests for phase functionality"
fi

if [ "$DOC_SCORE" -eq 0 ]; then
  echo "  2. Add documentation to key functions"
fi

if [ "$TODO_COUNT" -gt 0 ]; then
  echo "  3. Resolve $TODO_COUNT TODOs/FIXMEs"
fi

if [ "$SECURITY_ISSUES" -gt 0 ]; then
  echo "  4. Fix $SECURITY_ISSUES security issues"
fi

if [ "$UNCOMMITTED" -gt 0 ]; then
  echo "  5. Commit $UNCOMMITTED uncommitted files"
fi

echo ""
```

#### Operation: Evaluate Project (`--project`)

##### Step 1: Evaluate All Phases

```bash
echo "═══════════════════════════════════════════════"
echo "  Project-Wide Evaluation: $PROJECT_NAME"
echo "═══════════════════════════════════════════════"
echo ""

CHUNKS_FILE="$PROJECT_ROOT/.claude/.chunks.json"
TOTAL_CHUNKS=$(jq '.total_chunks' "$CHUNKS_FILE")

# Score each phase
PHASE_SCORES=()
TOTAL_SCORE=0

for i in $(seq 0 $((TOTAL_CHUNKS - 1))); do
  CHUNK_NAME=$(jq -r ".chunks[$i].name" "$CHUNKS_FILE")

  # Quick evaluation per phase (simplified)
  CHUNK_FILES=$(jq -r ".chunks[$i].files[]" "$CHUNKS_FILE")
  FILE_COUNT=$(echo "$CHUNK_FILES" | wc -l)
  EXISTING=0

  for file in $CHUNK_FILES; do
    [ -f "$PROJECT_ROOT/$file" ] && EXISTING=$((EXISTING + 1))
  done

  PHASE_SCORE=$((EXISTING * 100 / FILE_COUNT))
  PHASE_SCORES+=("$PHASE_SCORE")
  TOTAL_SCORE=$((TOTAL_SCORE + PHASE_SCORE))

  # Status indicator
  if [ "$PHASE_SCORE" -ge 90 ]; then
    STATUS="🟢"
  elif [ "$PHASE_SCORE" -ge 60 ]; then
    STATUS="🟡"
  else
    STATUS="🔴"
  fi

  echo "$STATUS $CHUNK_NAME: ${PHASE_SCORE}%"
done

AVERAGE_SCORE=$((TOTAL_SCORE / TOTAL_CHUNKS))
echo ""
echo "Overall Progress: ${AVERAGE_SCORE}%"
echo ""
```

##### Step 2: Assess Project Goals

```bash
echo "Goal Achievement:"
echo ""

# Check if plan file exists
STATE_FILE="$PROJECT_ROOT/.claude/.project-state.json"
PLAN_FILE=$(jq -r '.plan_file // ""' "$STATE_FILE" 2>/dev/null || echo "")

if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  # Analyze plan progress
  TOTAL_TASKS=$(grep -cE '^\- \[(x| )\]' "$PLAN_FILE" 2>/dev/null || echo "0")
  COMPLETED_TASKS=$(grep -cE '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || echo "0")

  if [ "$TOTAL_TASKS" -gt 0 ]; then
    PLAN_PROGRESS=$((COMPLETED_TASKS * 100 / TOTAL_TASKS))
    echo "  Plan tasks: $COMPLETED_TASKS / $TOTAL_TASKS ($PLAN_PROGRESS%)"
  fi

  # Extract project goal from plan (first heading)
  PROJECT_GOAL=$(grep -E '^#[^#]' "$PLAN_FILE" | head -1 | sed 's/^# //')
  if [ -n "$PROJECT_GOAL" ]; then
    echo "  Goal: $PROJECT_GOAL"

    if [ "$PLAN_PROGRESS" -ge 90 ]; then
      echo "  Status: 🟢 Goal achieved"
    elif [ "$PLAN_PROGRESS" -ge 60 ]; then
      echo "  Status: 🟡 Significant progress"
    else
      echo "  Status: 🔴 More work needed"
    fi
  fi
else
  echo "  ⚠ No plan file found - goal unclear"
fi
echo ""
```

##### Step 3: Identify Blockers

```bash
echo "Blockers & Risks:"
echo ""

# Check for common blockers
BLOCKERS=()

# Missing dependencies
if [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
  if ! cargo check --quiet 2>/dev/null; then
    BLOCKERS+=("Rust dependencies not resolved")
  fi
fi

# Failing tests
if command -v pytest &> /dev/null; then
  if ! pytest --quiet 2>/dev/null; then
    BLOCKERS+=("Tests are failing")
  fi
fi

# Uncommitted changes
if git status --porcelain | grep -q "^"; then
  UNCOMMITTED_COUNT=$(git status --porcelain | wc -l)
  BLOCKERS+=("$UNCOMMITTED_COUNT uncommitted changes")
fi

# Stale index
INDEX_FILE="$PROJECT_ROOT/.claude/.project-index.json"
if [ -f "$INDEX_FILE" ]; then
  INDEX_AGE=$(( $(date +%s) - $(stat -c %Y "$INDEX_FILE" 2>/dev/null || stat -f %m "$INDEX_FILE") ))
  if [ "$INDEX_AGE" -gt 86400 ]; then
    BLOCKERS+=("Project index is stale")
  fi
fi

if [ ${#BLOCKERS[@]} -eq 0 ]; then
  echo "  ✓ No blockers detected"
else
  for blocker in "${BLOCKERS[@]}"; do
    echo "  ✗ $blocker"
  done
fi
echo ""
```

##### Step 4: Strategic Recommendations

```bash
echo "═══════════════════════════════════════════════"
echo "  Recommendations"
echo "═══════════════════════════════════════════════"
echo ""

if [ "$AVERAGE_SCORE" -ge 90 ]; then
  echo "🎉 Project is in excellent shape!"
  echo ""
  echo "Next steps:"
  echo "  1. Final testing and quality assurance"
  echo "  2. Update documentation for release"
  echo "  3. Prepare deployment pipeline"
  echo "  4. Consider code freeze for release candidate"

elif [ "$AVERAGE_SCORE" -ge 75 ]; then
  echo "👍 Project is on track with minor gaps."
  echo ""
  echo "Priority actions:"
  echo "  1. Complete phases below 75% completion"
  echo "  2. Address security issues if any"
  echo "  3. Ensure all tests pass"
  echo "  4. Update documentation"

elif [ "$AVERAGE_SCORE" -ge 50 ]; then
  echo "⚠️ Project needs focused effort."
  echo ""
  echo "Critical actions:"
  echo "  1. Focus on incomplete phases (below 60%)"
  echo "  2. Write missing tests"
  echo "  3. Resolve blockers"
  echo "  4. Consider scope reduction if needed"

else
  echo "🔴 Project requires significant work."
  echo ""
  echo "Immediate actions:"
  echo "  1. Re-assess project scope and timeline"
  echo "  2. Focus on core features first"
  echo "  3. Complete basic implementation"
  echo "  4. Establish testing foundation"
fi

echo ""
```

#### Operation: Quick Check (`--quick`)

```bash
echo "Quick Health Check"
echo ""

# Fast evaluation (30 seconds max)
HEALTH_SCORE=100

# Check index exists
[ ! -f "$PROJECT_ROOT/.claude/.project-index.json" ] && HEALTH_SCORE=$((HEALTH_SCORE - 20))

# Check recent activity
STATE_FILE="$PROJECT_ROOT/.claude/.project-state.json"
if [ -f "$STATE_FILE" ]; then
  LAST_SESSION=$(jq -r '.last_session_date' "$STATE_FILE")
  SESSION_AGE=$(( $(date +%s) - $(date -d "$LAST_SESSION" +%s 2>/dev/null || echo "0") ))
  [ "$SESSION_AGE" -gt 604800 ] && HEALTH_SCORE=$((HEALTH_SCORE - 15))  # > 1 week
fi

# Check git status
if git status --porcelain | grep -q "^"; then
  HEALTH_SCORE=$((HEALTH_SCORE - 10))
fi

# Determine status
if [ "$HEALTH_SCORE" -ge 80 ]; then
  echo "Status: 🟢 Healthy ($HEALTH_SCORE/100)"
elif [ "$HEALTH_SCORE" -ge 60 ]; then
  echo "Status: 🟡 Needs Attention ($HEALTH_SCORE/100)"
else
  echo "Status: 🔴 Issues Detected ($HEALTH_SCORE/100)"
fi

echo ""
echo "Top 3 Actions:"
echo "  1. Run /evaluate --project for detailed assessment"
echo "  2. Update stale components"
echo "  3. Commit pending changes"
```

---

## Arguments

- `--phase <name>` - Evaluate specific phase
- `--project` - Evaluate entire project
- `--quick` - Fast health check
- `--json` - Output in JSON format
- `--verbose` - Include detailed metrics

---

## Integration with Other Components

**Plan Mode:**
- Reads plan file for goal assessment
- Tracks task completion percentage

**Chunks:**
- Evaluates each chunk/phase
- Provides per-phase scores

**Session State:**
- Uses completion percentage
- Tracks progress over time

**Git:**
- Checks commit status
- Identifies uncommitted work

---

## Best Practices

**When to evaluate:**
- After completing each phase
- Before major milestones
- Weekly project health checks
- When progress feels unclear

**Using recommendations:**
- Address high-priority items first
- Track improvements over time
- Re-evaluate after fixes

---

## Related Commands

- `/context-summary` - Current project state
- `/chunk --list` - View all phases
- `/navigate --phase` - Jump to phase needing work

## Related Skills

For evaluation methodology and criteria:

`$CLAUDE_PLUGIN_ROOT/skills/project-evaluation/SKILL.md` (to be created)
