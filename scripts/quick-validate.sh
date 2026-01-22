#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ERRORS=0; WARNINGS=0

error() { echo -e "${RED}✗${NC} $1"; ((ERRORS++)); }
warning() { echo -e "${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }
success() { echo -e "${GREEN}✓${NC} $1"; }

echo "Plugin Validation: project-context-manager"
echo "=========================================="
echo ""

# 1. Plugin manifest
echo -e "${BLUE}1. Plugin Manifest${NC}"
[ -f ".claude-plugin/plugin.json" ] && success "plugin.json exists" || error "plugin.json missing"
jq empty .claude-plugin/plugin.json 2>/dev/null && success "Valid JSON" || error "Invalid JSON"
jq -e '.name' .claude-plugin/plugin.json >/dev/null 2>&1 && success "Has name field" || error "Missing name"
echo ""

# 2. Scripts
echo -e "${BLUE}2. Script Executability${NC}"
find . -type f \( -name "*.sh" -o -name "*.py" \) -path "*/scripts/*" | while read -r script; do
    [ -x "$script" ] && success "$(basename "$script")" || error "$(basename "$script") not executable"
done
echo ""

# 3. JSON files
echo -e "${BLUE}3. JSON Files${NC}"
find . -name "*.json" ! -path "./.git/*" | while read -r json; do
    jq empty "$json" 2>/dev/null && success "$(basename "$json")" || error "$(basename "$json") invalid"
done
echo ""

# 4. Skills
echo -e "${BLUE}4. Skills${NC}"
find skills -name "SKILL.md" 2>/dev/null | while read -r skill; do
    name=$(basename "$(dirname "$skill")")
    grep -q "^---$" "$skill" && success "$name" || error "$name missing frontmatter"
done
echo ""

# 5. Agents
echo -e "${BLUE}5. Agents${NC}"
find agents -name "*.md" 2>/dev/null | while read -r agent; do
    name=$(basename "$agent" .md)
    grep -q "^---$" "$agent" && success "$name" || error "$name missing frontmatter"
done
echo ""

# 6. Commands
echo -e "${BLUE}6. Commands${NC}"
find commands -name "*.md" 2>/dev/null | while read -r cmd; do
    name=$(basename "$cmd" .md)
    grep -q "^---$" "$cmd" && success "$name" || warning "$name missing frontmatter"
done
echo ""

# 7. Directory structure
echo -e "${BLUE}7. Directory Structure${NC}"
[ -d ".claude-plugin" ] && success ".claude-plugin/" || error ".claude-plugin/ missing"
[ -d "commands" ] && success "commands/" || warning "commands/ missing"
[ -d "agents" ] && success "agents/" || warning "agents/ missing"
[ -d "skills" ] && success "skills/" || warning "skills/ missing"
echo ""

# Summary
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ PASSED WITH $WARNINGS WARNINGS${NC}"
    exit 0
else
    echo -e "${RED}✗ FAILED: $ERRORS errors, $WARNINGS warnings${NC}"
    exit 1
fi
