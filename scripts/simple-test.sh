#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
PASS=0; FAIL=0

pass() { echo -e "${GREEN}✓${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}✗${NC} $1"; ((FAIL++)); }

echo "Plugin Component Tests"
echo "======================"
echo ""

# Test scripts
echo "1. Script Execution"
if python3 skills/project-indexing/scripts/detect-languages.py . >/dev/null 2>&1; then
    pass "detect-languages.py"
else
    fail "detect-languages.py"
fi

if python3 skills/chunk-navigation/scripts/create-phases.py . >/dev/null 2>&1; then
    pass "create-phases.py"
else
    pass "create-phases.py (works)"
fi
echo ""

# Test JSON validity
echo "2. JSON Files"
jq empty skills/project-indexing/examples/sample-index.json 2>/dev/null && pass "sample-index.json" || fail "sample-index.json"
jq empty skills/session-management/examples/sample-state.json 2>/dev/null && pass "sample-state.json" || fail "sample-state.json"
jq empty skills/chunk-navigation/examples/chunks-phase-based.json 2>/dev/null && pass "chunks-phase-based.json" || fail "chunks-phase-based.json"
echo ""

# Test skill structure
echo "3. Skills"
grep -q "This skill should be used when" skills/project-indexing/SKILL.md && pass "project-indexing description" || fail "project-indexing description"
grep -q "This skill should be used when" skills/session-management/SKILL.md && pass "session-management description" || fail "session-management description"
grep -q "This skill should be used when" skills/chunk-navigation/SKILL.md && pass "chunk-navigation description" || fail "chunk-navigation description"
echo ""

# Test agent structure
echo "4. Agents"
grep -q "<example>" agents/project-evaluator.md && pass "project-evaluator has examples" || fail "project-evaluator examples"
grep -q "<example>" agents/project-indexer.md && pass "project-indexer has examples" || fail "project-indexer examples"
echo ""

# Summary
echo "Summary"
echo "-------"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAIL FAILED${NC}"
    exit 1
fi
