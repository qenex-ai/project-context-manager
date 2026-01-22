#!/bin/bash
#
# Comprehensive plugin validation script
#
# Validates:
# - plugin.json schema
# - Script executability
# - No hardcoded paths
# - JSON syntax
# - Skill trigger descriptions
# - Agent frontmatter
# - Hook configuration

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PLUGIN_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "=========================================="
echo "  Plugin Validation"
echo "=========================================="
echo ""
echo "Plugin: $(basename "$PLUGIN_ROOT")"
echo "Location: $PLUGIN_ROOT"
echo ""

# Helper functions
error() {
    echo -e "${RED}✗ ERROR:${NC} $1"
    ((ERRORS++))
}

warning() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1"
    ((WARNINGS++))
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 1. Validate plugin.json
section "1. Validating plugin.json"

if [ ! -f ".claude-plugin/plugin.json" ]; then
    error "plugin.json not found at .claude-plugin/plugin.json"
else
    # Check JSON syntax
    if jq empty .claude-plugin/plugin.json 2>/dev/null; then
        success "plugin.json is valid JSON"
    else
        error "plugin.json has syntax errors"
    fi

    # Check required fields
    if jq -e '.name' .claude-plugin/plugin.json >/dev/null 2>&1; then
        NAME=$(jq -r '.name' .claude-plugin/plugin.json)
        success "Has required 'name' field: $NAME"

        # Validate name format (lowercase, hyphens only)
        if [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            success "Name format is valid (lowercase-kebab-case)"
        else
            error "Name format invalid (use lowercase-kebab-case): $NAME"
        fi
    else
        error "Missing required 'name' field"
    fi

    # Check recommended fields
    for field in version description author; do
        if jq -e ".$field" .claude-plugin/plugin.json >/dev/null 2>&1; then
            success "Has recommended '$field' field"
        else
            warning "Missing recommended '$field' field"
        fi
    done
fi

# 2. Check script executability
section "2. Checking Script Executability"

SCRIPT_COUNT=0
NON_EXECUTABLE=0

while IFS= read -r -d '' script; do
    ((SCRIPT_COUNT++))
    if [ -x "$script" ]; then
        success "$(basename "$script") is executable"
    else
        error "$(basename "$script") is NOT executable"
        ((NON_EXECUTABLE++))
    fi
done < <(find . -type f \( -name "*.sh" -o -name "*.py" \) -path "*/scripts/*" -print0)

if [ $SCRIPT_COUNT -eq 0 ]; then
    warning "No scripts found in scripts/ directories"
else
    info "Checked $SCRIPT_COUNT scripts, $NON_EXECUTABLE not executable"
fi

# 3. Check for hardcoded paths
section "3. Checking for Hardcoded Paths"

HARDCODED_PATHS=0

# Check for common hardcoded path patterns
while IFS= read -r file; do
    # Skip binary files and this script
    if [ "$file" = "./scripts/validate-plugin.sh" ]; then
        continue
    fi

    # Check for hardcoded paths
    if grep -qE '(/Users/|/home/[^/]+/|C:\\|/opt/)' "$file" 2>/dev/null; then
        # Check if it's using CLAUDE_PLUGIN_ROOT variable
        if grep -q 'CLAUDE_PLUGIN_ROOT' "$file"; then
            success "$(basename "$file") uses \$CLAUDE_PLUGIN_ROOT (has hardcoded paths but properly handled)"
        else
            error "$(basename "$file") contains hardcoded paths without \$CLAUDE_PLUGIN_ROOT"
            ((HARDCODED_PATHS++))
        fi
    fi
done < <(find . -type f \( -name "*.md" -o -name "*.sh" -o -name "*.py" -o -name "*.json" \) ! -path "./.git/*")

if [ $HARDCODED_PATHS -eq 0 ]; then
    success "No problematic hardcoded paths found"
fi

# 4. Lint all JSON files
section "4. Linting JSON Files"

JSON_COUNT=0
JSON_ERRORS=0

while IFS= read -r -d '' json_file; do
    ((JSON_COUNT++))
    if jq empty "$json_file" 2>/dev/null; then
        success "$(basename "$json_file") is valid JSON"
    else
        error "$(basename "$json_file") has JSON syntax errors"
        ((JSON_ERRORS++))
    fi
done < <(find . -type f -name "*.json" ! -path "./.git/*" -print0)

info "Validated $JSON_COUNT JSON files, $JSON_ERRORS with errors"

# 5. Validate skill trigger descriptions
section "5. Validating Skill Trigger Descriptions"

SKILL_COUNT=0
SKILL_ISSUES=0

while IFS= read -r -d '' skill_file; do
    ((SKILL_COUNT++))
    skill_name=$(basename "$(dirname "$skill_file")")

    # Check frontmatter exists
    if ! grep -q "^---$" "$skill_file"; then
        error "Skill $skill_name: No YAML frontmatter found"
        ((SKILL_ISSUES++))
        continue
    fi

    # Extract frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d')

    # Check for name field
    if echo "$frontmatter" | grep -q "^name:"; then
        success "Skill $skill_name: Has name field"
    else
        error "Skill $skill_name: Missing name field"
        ((SKILL_ISSUES++))
    fi

    # Check for description field
    if echo "$frontmatter" | grep -q "^description:"; then
        desc=$(echo "$frontmatter" | grep "^description:" | cut -d: -f2- | xargs)

        # Check for third-person format
        if [[ "$desc" =~ ^This\ skill\ should\ be\ used\ when ]]; then
            success "Skill $skill_name: Description uses third-person format"
        else
            warning "Skill $skill_name: Description should use third-person (This skill should be used when...)"
        fi

        # Check for trigger phrases
        if [[ "$desc" =~ \"[^\"]+\" ]]; then
            success "Skill $skill_name: Has trigger phrases in quotes"
        else
            warning "Skill $skill_name: Should include specific trigger phrases in quotes"
        fi

        # Check length
        desc_length=${#desc}
        if [ $desc_length -ge 50 ] && [ $desc_length -le 500 ]; then
            success "Skill $skill_name: Description length appropriate ($desc_length chars)"
        else
            warning "Skill $skill_name: Description length should be 50-500 chars (is $desc_length)"
        fi
    else
        error "Skill $skill_name: Missing description field"
        ((SKILL_ISSUES++))
    fi

    # Check for version
    if echo "$frontmatter" | grep -q "^version:"; then
        success "Skill $skill_name: Has version field"
    else
        warning "Skill $skill_name: Missing version field"
    fi
done < <(find skills -name "SKILL.md" -type f -print0 2>/dev/null)

info "Validated $SKILL_COUNT skills, $SKILL_ISSUES with issues"

# 6. Validate agent frontmatter
section "6. Validating Agent Frontmatter"

AGENT_COUNT=0
AGENT_ISSUES=0

while IFS= read -r -d '' agent_file; do
    ((AGENT_COUNT++))
    agent_name=$(basename "$agent_file" .md)

    # Check frontmatter exists
    if ! grep -q "^---$" "$agent_file"; then
        error "Agent $agent_name: No YAML frontmatter found"
        ((AGENT_ISSUES++))
        continue
    fi

    # Extract frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$agent_file" | sed '1d;$d')

    # Check for name field
    if echo "$frontmatter" | grep -q "^name:"; then
        name=$(echo "$frontmatter" | grep "^name:" | cut -d: -f2- | xargs)

        # Validate name format
        if [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] && [ ${#name} -ge 3 ] && [ ${#name} -le 50 ]; then
            success "Agent $agent_name: Name format valid ($name)"
        else
            error "Agent $agent_name: Name format invalid (use lowercase-kebab-case, 3-50 chars)"
            ((AGENT_ISSUES++))
        fi
    else
        error "Agent $agent_name: Missing name field"
        ((AGENT_ISSUES++))
    fi

    # Check for description field
    if echo "$frontmatter" | grep -q "^description:"; then
        desc=$(echo "$frontmatter" | sed -n '/^description:/,/^[a-z]/p' | grep -v "^[a-z]" | sed 's/^description://' | tr -d '\n' | xargs)

        # Check for example blocks
        if [[ "$desc" =~ \<example\> ]]; then
            success "Agent $agent_name: Has example blocks in description"
        else
            warning "Agent $agent_name: Should include <example> blocks"
        fi

        # Check length
        desc_length=${#desc}
        if [ $desc_length -ge 100 ]; then
            success "Agent $agent_name: Description length sufficient ($desc_length chars)"
        else
            warning "Agent $agent_name: Description should be at least 100 chars (is $desc_length)"
        fi
    else
        error "Agent $agent_name: Missing description field"
        ((AGENT_ISSUES++))
    fi

    # Check for required fields
    for field in model color; do
        if echo "$frontmatter" | grep -q "^$field:"; then
            success "Agent $agent_name: Has required '$field' field"
        else
            error "Agent $agent_name: Missing required '$field' field"
            ((AGENT_ISSUES++))
        fi
    done
done < <(find agents -name "*.md" -type f -print0 2>/dev/null)

info "Validated $AGENT_COUNT agents, $AGENT_ISSUES with issues"

# 7. Validate hook configuration
section "7. Validating Hook Configuration"

if [ -f "hooks/hooks.json" ]; then
    # Check JSON syntax
    if jq empty hooks/hooks.json 2>/dev/null; then
        success "hooks.json is valid JSON"

        # Check for hooks field wrapper
        if jq -e '.hooks' hooks/hooks.json >/dev/null 2>&1; then
            success "Has 'hooks' wrapper field (plugin format)"
        elif jq -e '.PreToolUse or .PostToolUse or .Stop' hooks/hooks.json >/dev/null 2>&1; then
            warning "Using direct format (settings format), should use 'hooks' wrapper for plugins"
        fi

        # Check hook events
        HOOK_EVENTS=$(jq -r '.hooks | keys[]' hooks/hooks.json 2>/dev/null || jq -r 'keys[]' hooks/hooks.json)
        VALID_EVENTS="PreToolUse PostToolUse Stop SubagentStop SessionStart SessionEnd UserPromptSubmit PreCompact Notification"

        echo "$HOOK_EVENTS" | while read -r event; do
            if echo "$VALID_EVENTS" | grep -qw "$event"; then
                success "Valid hook event: $event"
            else
                error "Invalid hook event: $event"
            fi
        done

        # Check for portable paths in commands
        if grep -q "command" hooks/hooks.json; then
            if grep -q "\$CLAUDE_PLUGIN_ROOT\|/root/.claude/plugins/cache/claude-plugins-official/plugin-dev/e30768372b41" hooks/hooks.json; then
                success "Hook commands use portable paths"
            else
                warning "Hook commands should use \$CLAUDE_PLUGIN_ROOT for portability"
            fi
        fi
    else
        error "hooks/hooks.json has JSON syntax errors"
    fi
else
    warning "No hooks/hooks.json found (hooks are optional)"
fi

# 8. Check command files
section "8. Validating Commands"

COMMAND_COUNT=0
COMMAND_ISSUES=0

while IFS= read -r -d '' cmd_file; do
    ((COMMAND_COUNT++))
    cmd_name=$(basename "$cmd_file" .md)

    # Check frontmatter exists
    if ! grep -q "^---$" "$cmd_file"; then
        error "Command $cmd_name: No YAML frontmatter found"
        ((COMMAND_ISSUES++))
        continue
    fi

    # Extract frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$cmd_file" | sed '1d;$d')

    # Check for name field
    if echo "$frontmatter" | grep -q "^name:"; then
        success "Command $cmd_name: Has name field"
    else
        error "Command $cmd_name: Missing name field"
        ((COMMAND_ISSUES++))
    fi

    # Check for description field
    if echo "$frontmatter" | grep -q "^description:"; then
        success "Command $cmd_name: Has description field"
    else
        error "Command $cmd_name: Missing description field"
        ((COMMAND_ISSUES++))
    fi
done < <(find commands -name "*.md" -type f -print0 2>/dev/null)

info "Validated $COMMAND_COUNT commands, $COMMAND_ISSUES with issues"

# 9. Check directory structure
section "9. Validating Directory Structure"

# Check for required directories
if [ -d ".claude-plugin" ]; then
    success ".claude-plugin/ directory exists"
else
    error ".claude-plugin/ directory missing"
fi

# Check component directories at root level
for dir in commands agents skills hooks; do
    if [ -d "$dir" ]; then
        success "$dir/ directory exists at root level"
    else
        info "$dir/ directory not found (optional)"
    fi
done

# Ensure components not nested in .claude-plugin
for dir in commands agents skills hooks; do
    if [ -d ".claude-plugin/$dir" ]; then
        error "$dir/ should be at plugin root, not inside .claude-plugin/"
    fi
done

# 10. Final summary
section "Summary"

echo ""
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠ VALIDATION PASSED WITH WARNINGS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Errors: $ERRORS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    exit 1
fi
