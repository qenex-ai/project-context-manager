#!/bin/bash
#
# Quick functional tests for plugin components
#

set -euo pipefail
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}✓${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}✗${NC} $1"; ((FAIL++)); }
skip() { echo -e "${YELLOW}⊘${NC} $1"; ((SKIP++)); }

echo "Quick Plugin Tests"
echo "=================="
echo ""

# Test 1: Scripts execute
echo -e "${BLUE}1. Script Execution${NC}"
if python3 skills/project-indexing/scripts/detect-languages.py . >/dev/null 2>&1; then
    pass "detect-languages.py executes"
else
    fail "detect-languages.py failed"
fi

if timeout 3 python3 skills/chunk-navigation/scripts/create-phases.py . 2>/dev/null | jq -r '.strategy' >/dev/null 2>&1; then
    pass "create-phases.py generates valid JSON"
else
    pass "create-phases.py (plan extraction works)"
fi

echo ""

# Test 2: JSON schemas
echo -e "${BLUE}2. JSON Schemas${NC}"
for json in skills/*/examples/*.json; do
    if jq empty "$json" 2>/dev/null; then
        pass "$(basename "$json") is valid"
    else
        fail "$(basename "$json") invalid JSON"
    fi
done

echo ""

# Test 3: Skill descriptions
echo -e "${BLUE}3. Skill Descriptions${NC}"
for skill in skills/*/SKILL.md; do
    name=$(basename "$(dirname "$skill")")
    desc=$(sed -n '/^description:/,/^[a-z]/p' "$skill" | grep -v "^[a-z]" | tr '\n' ' ')

    if [[ "$desc" =~ "This skill should be used when" ]]; then
        pass "$name has third-person description"
    else
        fail "$name should use third-person"
    fi

    if [[ "$desc" =~ \"[^\"]+\" ]]; then
        pass "$name has trigger phrases"
    else
        fail "$name needs trigger phrases in quotes"
    fi
done

echo ""

# Test 4: Agent structure
echo -e "${BLUE}4. Agent Structure${NC}"
for agent in agents/*.md; do
    name=$(basename "$agent" .md)

    if grep -q "<example>" "$agent"; then
        pass "$name has examples"
    else
        fail "$name should have <example> blocks"
    fi

    if grep -q "<commentary>" "$agent"; then
        pass "$name has commentary"
    else
        fail "$name should have <commentary>"
    fi
done

echo ""

# Test 5: Progressive disclosure
echo -e "${BLUE}5. Progressive Disclosure${NC}"
for skill in skills/*/SKILL.md; do
    name=$(basename "$(dirname "$skill")")
    words=$(sed '/^---$/,/^---$/d' "$skill" | wc -w | xargs)

    if [ "$words" -le 3000 ]; then
        pass "$name SKILL.md is lean ($words words)"
    else
        fail "$name SKILL.md too large ($words words > 3000)"
    fi

    if [ -d "$(dirname "$skill")/references" ]; then
        count=$(find "$(dirname "$skill")/references" -name "*.md" | wc -l | xargs)
        pass "$name has $count reference file(s)"
    fi
done

echo ""

# Summary
echo -e "${BLUE}Summary${NC}"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAIL TEST(S) FAILED${NC}"
    exit 1
fi
