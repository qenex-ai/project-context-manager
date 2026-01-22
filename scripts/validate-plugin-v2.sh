#!/bin/bash
#
# Comprehensive plugin validation script (simplified version)
#

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PLUGIN_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

error() { echo -e "${RED}✗ ERROR:${NC} $1"; ((ERRORS++)); }
warning() { echo -e "${YELLOW}⚠ WARNING:${NC} $1"; ((WARNINGS++)); }
success() { echo -e "${GREEN}✓${NC} $1"; }
section() { echo ""; echo -e "${BLUE}━━━ $1 ━━━${NC}"; }

echo "Plugin Validation: project-context-manager"
echo "=========================================="

# 1. Validate plugin.json
section "1. Plugin Manifest"

if [ ! -f ".claude-plugin/plugin.json" ]; then
    error "plugin.json not found"
else
    jq empty .claude-plugin/plugin.json 2>/dev/null && success "plugin.json is valid JSON" || error "plugin.json has syntax errors"

    jq -e '.name' .claude-plugin/plugin.json >/dev/null 2>&1 && success "Has 'name' field" || error "Missing 'name' field"
    jq -e '.version' .claude-plugin/plugin.json >/dev/null 2>&1 && success "Has 'version' field" || warning "Missing 'version' field"
fi

# 2. Check scripts
section "2. Script Executability"

SCRIPT_COUNT=0
for script in $(find . -type f \( -name "*.sh" -o -name "*.py" \) -path "*/scripts/*"); do
    ((SCRIPT_COUNT++))
    [ -x "$script" ] && success "$(basename "$script")" || error "$(basename "$script") not executable"
done
echo "   Checked $SCRIPT_COUNT scripts"

# 3. Check for hardcoded paths
section "3. Portable Paths"

ISSUES=0
for file in $(find . -type f -name "*.json" ! -path "./.git/*"); do
    if grep -qE '(/Users/|/home/[^$]|C:\\)' "$file" 2>/dev/null; then
        warning "$(basename "$file") may have hardcoded paths"
        ((ISSUES++))
    fi
done
[ $ISSUES -eq 0 ] && success "No obvious hardcoded paths found"

# 4. JSON validation
section "4. JSON Files"

JSON_COUNT=0
JSON_ERRORS=0
for json in $(find . -name "*.json" ! -path "./.git/*"); do
    ((JSON_COUNT++))
    if jq empty "$json" 2>/dev/null; then
        success "$(basename "$json")"
    else
        error "$(basename "$json") - invalid JSON"
        ((JSON_ERRORS++))
    fi
done
echo "   Validated $JSON_COUNT files, $JSON_ERRORS errors"

# 5. Skills validation
section "5. Skills"

SKILL_COUNT=0
for skill_file in $(find skills -name "SKILL.md" 2>/dev/null); do
    ((SKILL_COUNT++))
    skill_name=$(basename "$(dirname "$skill_file")")

    grep -q "^---$" "$skill_file" && success "$skill_name has frontmatter" || error "$skill_name missing frontmatter"

    # Check for required fields in frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d')
    echo "$frontmatter" | grep -q "^name:" && success "$skill_name has name" || error "$skill_name missing name"
    echo "$frontmatter" | grep -q "^description:" && success "$skill_name has description" || error "$skill_name missing description"
done
echo "   Validated $SKILL_COUNT skills"

# 6. Agents validation
section "6. Agents"

AGENT_COUNT=0
for agent_file in $(find agents -name "*.md" 2>/dev/null); do
    ((AGENT_COUNT++))
    agent_name=$(basename "$agent_file" .md)

    grep -q "^---$" "$agent_file" && success "$agent_name has frontmatter" || error "$agent_name missing frontmatter"

    frontmatter=$(sed -n '/^---$/,/^---$/p' "$agent_file" | sed '1d;$d')
    echo "$frontmatter" | grep -q "^name:" && success "$agent_name has name" || error "$agent_name missing name"
    echo "$frontmatter" | grep -q "^description:" && success "$agent_name has description" || error "$agent_name missing description"
    echo "$frontmatter" | grep -q "^model:" && success "$agent_name has model" || error "$agent_name missing model"
    echo "$frontmatter" | grep -q "^color:" && success "$agent_name has color" || error "$agent_name missing color"
done
echo "   Validated $AGENT_COUNT agents"

# 7. Commands validation
section "7. Commands"

CMD_COUNT=0
for cmd_file in $(find commands -name "*.md" 2>/dev/null); do
    ((CMD_COUNT++))
    cmd_name=$(basename "$cmd_file" .md)

    grep -q "^---$" "$cmd_file" && success "$cmd_name has frontmatter" || warning "$cmd_name missing frontmatter"
done
echo "   Validated $CMD_COUNT commands"

# 8. Hooks validation
section "8. Hooks"

if [ -f "hooks/hooks.json" ]; then
    jq empty hooks/hooks.json 2>/dev/null && success "hooks.json is valid JSON" || error "hooks.json has syntax errors"
    jq -e '.hooks' hooks/hooks.json >/dev/null 2>&1 && success "Has 'hooks' wrapper" || warning "Missing 'hooks' wrapper (use plugin format)"
else
    warning "No hooks/hooks.json found (optional)"
fi

# 9. Directory structure
section "9. Directory Structure"

[ -d ".claude-plugin" ] && success ".claude-plugin/ exists" || error ".claude-plugin/ missing"
[ -d "commands" ] && success "commands/ exists" || warning "commands/ missing (optional)"
[ -d "agents" ] && success "agents/ exists" || warning "agents/ missing (optional)"
[ -d "skills" ] && success "skills/ exists" || warning "skills/ missing (optional)"

# Ensure components NOT in .claude-plugin
for dir in commands agents skills hooks; do
    [ -d ".claude-plugin/$dir" ] && error "$dir/ should be at root, not in .claude-plugin/" || success "$dir/ correctly at root"
done

# Summary
section "Summary"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠ PASSED WITH $WARNINGS WARNINGS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ FAILED: $ERRORS errors, $WARNINGS warnings${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
