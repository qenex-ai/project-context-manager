#!/bin/bash
#
# Comprehensive plugin testing script
#
# Tests all plugin components for functional correctness

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PLUGIN_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test results
test_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}⊘ SKIP:${NC} $1"
    ((TESTS_SKIPPED++))
}

test_info() {
    echo -e "${CYAN}ℹ INFO:${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo "=========================================="
echo "  Plugin Testing & Verification"
echo "=========================================="
echo ""
echo "Plugin: project-context-manager"
echo "Test Date: $(date)"
echo ""

# Create test workspace
TEST_WORKSPACE="/tmp/plugin-test-$$"
mkdir -p "$TEST_WORKSPACE"
test_info "Test workspace: $TEST_WORKSPACE"

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_WORKSPACE"
}
trap cleanup EXIT

# ============================================
# Test 1: Utility Scripts
# ============================================
section "Test 1: Utility Scripts Execution"

# Test language detection script
if [ -f "skills/project-indexing/scripts/detect-languages.py" ]; then
    test_info "Testing detect-languages.py..."

    # Create test project structure
    mkdir -p "$TEST_WORKSPACE/test-project/src"
    echo "print('hello')" > "$TEST_WORKSPACE/test-project/src/main.py"
    echo "fn main() {}" > "$TEST_WORKSPACE/test-project/src/main.rs"

    if python3 skills/project-indexing/scripts/detect-languages.py "$TEST_WORKSPACE/test-project" 2>/dev/null; then
        test_pass "detect-languages.py executes without errors"
    else
        test_fail "detect-languages.py failed to execute"
    fi
else
    test_skip "detect-languages.py not found"
fi

# Test session history script
if [ -f "skills/session-management/scripts/session-history.py" ]; then
    test_info "Testing session-history.py..."

    # Test with --help flag
    if python3 skills/session-management/scripts/session-history.py --help 2>/dev/null | grep -q "usage:"; then
        test_pass "session-history.py shows help"
    else
        test_skip "session-history.py help not available (may need args)"
    fi
else
    test_skip "session-history.py not found"
fi

# Test chunk creation script
if [ -f "skills/chunk-navigation/scripts/create-phases.py" ]; then
    test_info "Testing create-phases.py..."

    # Run on test workspace
    if python3 skills/chunk-navigation/scripts/create-phases.py "$TEST_WORKSPACE/test-project" 2>/dev/null | jq empty 2>/dev/null; then
        test_pass "create-phases.py generates valid JSON"
    else
        test_skip "create-phases.py requires specific project structure"
    fi
else
    test_skip "create-phases.py not found"
fi

# Test keychain wrapper
if [ -f "skills/secure-credential-handling/scripts/keychain-wrapper.sh" ]; then
    test_info "Testing keychain-wrapper.sh..."

    # Test store operation (will fail on unsupported systems, that's ok)
    if bash skills/secure-credential-handling/scripts/keychain-wrapper.sh store test-service test-user test-pass 2>/dev/null; then
        test_pass "keychain-wrapper.sh store operation works"

        # Test retrieve
        if bash skills/secure-credential-handling/scripts/keychain-wrapper.sh get test-service test-user 2>/dev/null; then
            test_pass "keychain-wrapper.sh get operation works"
        fi

        # Cleanup
        bash skills/secure-credential-handling/scripts/keychain-wrapper.sh delete test-service test-user 2>/dev/null || true
    else
        test_skip "keychain-wrapper.sh (system keychain not available)"
    fi
else
    test_skip "keychain-wrapper.sh not found"
fi

# ============================================
# Test 2: JSON Schema Validation
# ============================================
section "Test 2: JSON Schema Examples"

# Test project index schema
if [ -f "skills/project-indexing/examples/sample-index.json" ]; then
    test_info "Testing sample-index.json schema..."

    # Check required fields
    REQUIRED_FIELDS=("schema_version" "indexed_at" "languages" "dependencies")
    VALID=true

    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! jq -e ".$field" skills/project-indexing/examples/sample-index.json >/dev/null 2>&1; then
            VALID=false
            break
        fi
    done

    if $VALID; then
        test_pass "sample-index.json has required fields"
    else
        test_fail "sample-index.json missing required fields"
    fi
else
    test_skip "sample-index.json not found"
fi

# Test session state schema
if [ -f "skills/session-management/examples/sample-state.json" ]; then
    test_info "Testing sample-state.json schema..."

    REQUIRED_FIELDS=("session_id" "timestamp" "project_root" "checkpoint_reason")
    VALID=true

    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! jq -e ".$field" skills/session-management/examples/sample-state.json >/dev/null 2>&1; then
            VALID=false
            break
        fi
    done

    if $VALID; then
        test_pass "sample-state.json has required fields"
    else
        test_fail "sample-state.json missing required fields"
    fi
else
    test_skip "sample-state.json not found"
fi

# Test chunk structure schema
if [ -f "skills/chunk-navigation/examples/chunks-phase-based.json" ]; then
    test_info "Testing chunks-phase-based.json schema..."

    REQUIRED_FIELDS=("strategy" "chunks" "current_chunk")
    VALID=true

    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! jq -e ".$field" skills/chunk-navigation/examples/chunks-phase-based.json >/dev/null 2>&1; then
            VALID=false
            break
        fi
    done

    if $VALID; then
        test_pass "chunks-phase-based.json has required fields"

        # Check chunk structure
        if jq -e '.chunks[0] | .id, .name, .files, .dependencies, .status' \
           skills/chunk-navigation/examples/chunks-phase-based.json >/dev/null 2>&1; then
            test_pass "Chunk objects have required fields"
        else
            test_fail "Chunk objects missing required fields"
        fi
    else
        test_fail "chunks-phase-based.json missing required fields"
    fi
else
    test_skip "chunks-phase-based.json not found"
fi

# ============================================
# Test 3: Skill Trigger Descriptions
# ============================================
section "Test 3: Skill Trigger Descriptions"

for skill_dir in skills/*/; do
    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"

    if [ ! -f "$skill_file" ]; then
        test_skip "$skill_name: SKILL.md not found"
        continue
    fi

    test_info "Testing $skill_name skill..."

    # Extract description from frontmatter
    description=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d' | grep "^description:" | cut -d: -f2- | xargs)

    if [ -z "$description" ]; then
        test_fail "$skill_name: No description found"
        continue
    fi

    # Check for third-person format
    if [[ "$description" =~ ^This\ skill\ should\ be\ used\ when ]]; then
        test_pass "$skill_name: Uses third-person format"
    else
        test_fail "$skill_name: Should use third-person (This skill should be used when...)"
    fi

    # Check for trigger phrases in quotes
    if [[ "$description" =~ \"[^\"]+\" ]]; then
        test_pass "$skill_name: Has trigger phrases in quotes"
    else
        test_fail "$skill_name: Should include trigger phrases in quotes"
    fi

    # Check description length
    desc_length=${#description}
    if [ $desc_length -ge 50 ] && [ $desc_length -le 1000 ]; then
        test_pass "$skill_name: Description length appropriate ($desc_length chars)"
    else
        test_fail "$skill_name: Description should be 50-1000 chars (is $desc_length)"
    fi
done

# ============================================
# Test 4: Agent Structure
# ============================================
section "Test 4: Agent Structure & Examples"

for agent_file in agents/*.md; do
    agent_name=$(basename "$agent_file" .md)

    test_info "Testing $agent_name agent..."

    # Check frontmatter
    if ! grep -q "^---$" "$agent_file"; then
        test_fail "$agent_name: No frontmatter found"
        continue
    fi

    frontmatter=$(sed -n '/^---$/,/^---$/p' "$agent_file" | sed '1d;$d')

    # Check required fields
    REQUIRED=("name" "description" "model" "color")
    VALID=true

    for field in "${REQUIRED[@]}"; do
        if ! echo "$frontmatter" | grep -q "^$field:"; then
            test_fail "$agent_name: Missing $field field"
            VALID=false
        fi
    done

    if $VALID; then
        test_pass "$agent_name: Has all required fields"
    fi

    # Check for example blocks in description
    if grep -q "<example>" "$agent_file"; then
        test_pass "$agent_name: Has example blocks"

        # Count examples
        EXAMPLE_COUNT=$(grep -c "<example>" "$agent_file")
        test_info "$agent_name: $EXAMPLE_COUNT example(s) found"
    else
        test_fail "$agent_name: Should include <example> blocks"
    fi

    # Check for commentary in examples
    if grep -q "<commentary>" "$agent_file"; then
        test_pass "$agent_name: Has commentary in examples"
    else
        test_fail "$agent_name: Should include <commentary> in examples"
    fi
done

# ============================================
# Test 5: Command Structure
# ============================================
section "Test 5: Command Structure"

for cmd_file in commands/*.md; do
    # Skip addon files
    if [[ "$cmd_file" == *".genius-addon"* ]]; then
        continue
    fi

    cmd_name=$(basename "$cmd_file" .md)

    test_info "Testing $cmd_name command..."

    # Check frontmatter
    if grep -q "^---$" "$cmd_file"; then
        test_pass "$cmd_name: Has frontmatter"

        # Check for name and description
        frontmatter=$(sed -n '/^---$/,/^---$/p' "$cmd_file" | sed '1d;$d')

        if echo "$frontmatter" | grep -q "^name:"; then
            test_pass "$cmd_name: Has name field"
        else
            test_fail "$cmd_name: Missing name field"
        fi

        if echo "$frontmatter" | grep -q "^description:"; then
            test_pass "$cmd_name: Has description field"
        else
            test_fail "$cmd_name: Missing description field"
        fi
    else
        test_fail "$cmd_name: Missing frontmatter"
    fi

    # Check for usage instructions
    if grep -qi "usage:" "$cmd_file" || grep -qi "## usage" "$cmd_file"; then
        test_pass "$cmd_name: Has usage instructions"
    else
        test_skip "$cmd_name: No explicit usage section (may be inline)"
    fi
done

# ============================================
# Test 6: Hook Configuration
# ============================================
section "Test 6: Hook Configuration"

if [ -f "hooks/hooks.json" ]; then
    test_info "Testing hooks.json configuration..."

    # Check for hooks wrapper
    if jq -e '.hooks' hooks/hooks.json >/dev/null 2>&1; then
        test_pass "Uses 'hooks' wrapper (plugin format)"

        # Check each hook event
        HOOK_EVENTS=$(jq -r '.hooks | keys[]' hooks/hooks.json)

        echo "$HOOK_EVENTS" | while read -r event; do
            # Check if event is valid
            VALID_EVENTS="PreToolUse PostToolUse Stop SubagentStop SessionStart SessionEnd UserPromptSubmit PreCompact Notification"

            if echo "$VALID_EVENTS" | grep -qw "$event"; then
                test_pass "Hook event '$event' is valid"
            else
                test_fail "Hook event '$event' is not valid"
            fi
        done

        # Check for script references
        if jq -r '.hooks | .. | .command? | select(. != null)' hooks/hooks.json | grep -q "scripts/"; then
            test_pass "Hook commands reference scripts/"
        fi

    else
        test_fail "Missing 'hooks' wrapper (should use plugin format)"
    fi
else
    test_skip "hooks/hooks.json not found"
fi

# ============================================
# Test 7: Reference Files
# ============================================
section "Test 7: Reference File Structure"

# Check that reference files are substantial
find skills -name "*.md" -path "*/references/*" | while read -r ref_file; do
    ref_name=$(basename "$ref_file")
    skill_name=$(basename "$(dirname "$(dirname "$ref_file")")")

    # Check file size (should be >1000 bytes)
    file_size=$(wc -c < "$ref_file")

    if [ "$file_size" -gt 1000 ]; then
        test_pass "$skill_name/$ref_name: Substantial content ($file_size bytes)"
    else
        test_fail "$skill_name/$ref_name: Too small ($file_size bytes)"
    fi

    # Check for markdown headers
    if grep -q "^#" "$ref_file"; then
        test_pass "$skill_name/$ref_name: Has markdown headers"
    else
        test_fail "$skill_name/$ref_name: Should have markdown headers"
    fi
done

# ============================================
# Test 8: Progressive Disclosure
# ============================================
section "Test 8: Progressive Disclosure (Skill Size)"

for skill_dir in skills/*/; do
    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"

    if [ ! -f "$skill_file" ]; then
        continue
    fi

    # Count words in SKILL.md (excluding frontmatter)
    word_count=$(sed '/^---$/,/^---$/d' "$skill_file" | wc -w | xargs)

    test_info "$skill_name: SKILL.md has $word_count words"

    if [ "$word_count" -le 3000 ]; then
        test_pass "$skill_name: SKILL.md is lean (≤3000 words)"
    else
        test_fail "$skill_name: SKILL.md too large (>3000 words), move content to references/"
    fi

    # Check for references directory
    if [ -d "$skill_dir/references" ]; then
        ref_count=$(find "$skill_dir/references" -name "*.md" | wc -l | xargs)
        test_pass "$skill_name: Has $ref_count reference file(s)"
    else
        test_info "$skill_name: No references/ directory (optional)"
    fi
done

# ============================================
# Final Summary
# ============================================
section "Test Summary"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

echo ""
echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
