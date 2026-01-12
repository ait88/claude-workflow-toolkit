#!/usr/bin/env bash
# Validate template syntax and placeholder usage
# Usage: ./scripts/validate-templates.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

ERRORS=0
WARNINGS=0

echo "Validating claude-workflow-toolkit templates..."
echo ""

# Check skill templates for bash syntax
echo "Checking skill templates..."
for template in "$ROOT_DIR"/templates/skills/*.template; do
    if [[ ! -f "$template" ]]; then
        continue
    fi

    filename=$(basename "$template")

    # Skip non-bash templates
    if [[ "$filename" == *.md.template ]]; then
        continue
    fi

    # Create temp file with placeholders replaced
    temp_file=$(mktemp)
    sed 's/{{[^}]*}}/PLACEHOLDER/g' "$template" > "$temp_file"

    # Check bash syntax
    if bash -n "$temp_file" 2>/dev/null; then
        echo -e "  ${GREEN}OK${NC} $filename"
    else
        echo -e "  ${RED}ERROR${NC} $filename - Invalid bash syntax"
        bash -n "$temp_file" 2>&1 | head -5
        ((ERRORS++))
    fi

    rm -f "$temp_file"
done

echo ""

# Check for undefined placeholders in profiles
echo "Checking profiles..."
for profile in "$ROOT_DIR"/profiles/*.yaml; do
    if [[ ! -f "$profile" ]]; then
        continue
    fi

    filename=$(basename "$profile")

    # Check YAML syntax (basic check - just look for obvious errors)
    if grep -q '^[^ ].*: [^ ].*:' "$profile"; then
        echo -e "  ${YELLOW}WARNING${NC} $filename - Possible YAML formatting issue"
        ((WARNINGS++))
    else
        echo -e "  ${GREEN}OK${NC} $filename"
    fi
done

echo ""

# Check that all templates use consistent placeholder format
echo "Checking placeholder format..."

# Find all template files recursively
find "$ROOT_DIR/templates" -name "*.template" -type f | while read -r template; do
    if [[ ! -f "$template" ]]; then
        continue
    fi

    # Get relative path for better output
    relative_path="${template#$ROOT_DIR/templates/}"

    # Find any malformed placeholders (missing closing braces, etc.)
    if grep -qE '\{\{[^}]+$' "$template" || grep -qE '^[^{]*\}\}' "$template"; then
        echo -e "  ${RED}ERROR${NC} $relative_path - Malformed placeholder"
        ((ERRORS++))
    else
        # Count placeholders
        count=$(grep -oE '\{\{[^}]+\}\}' "$template" | wc -l)
        echo -e "  ${GREEN}OK${NC} $relative_path ($count placeholders)"
    fi
done

echo ""

# Check example output
echo "Checking example output..."
for example in "$ROOT_DIR"/examples/applied/.claude/skills/*; do
    if [[ ! -f "$example" ]]; then
        continue
    fi

    filename=$(basename "$example")

    # Skip README
    if [[ "$filename" == "README.md" ]]; then
        echo -e "  ${GREEN}OK${NC} $filename"
        continue
    fi

    # Check it doesn't have placeholders
    if grep -q '{{' "$example"; then
        echo -e "  ${RED}ERROR${NC} $filename - Contains unsubstituted placeholders"
        ((ERRORS++))
    else
        echo -e "  ${GREEN}OK${NC} $filename"
    fi
done

echo ""
echo "========================================"

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}$WARNINGS warning(s) found${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS error(s), $WARNINGS warning(s) found${NC}"
    exit 1
fi
