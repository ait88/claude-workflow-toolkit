#!/usr/bin/env bash
# Setup required GitHub labels for Claude/Codex workflow
# Usage: ./scripts/setup-labels.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "Setting up GitHub labels for Claude/Codex workflow..."
echo ""

# Check gh CLI is available
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is required${NC}"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

# Check we're in a git repo
if ! git rev-parse --git-dir &> /dev/null; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Workflow labels
declare -A WORKFLOW_LABELS=(
    ["agent-ready"]="Task ready for agent work:#0E8A16"
    ["in-progress"]="Agent actively working:#FBCA04"
    ["needs-review"]="PR created, awaiting review:#1D76DB"
    ["blocked"]="Waiting on dependency:#B60205"
)

# Phase labels (0-6)
declare -A PHASE_LABELS=(
    ["phase-0"]="Foundation phase:#C5DEF5"
    ["phase-1"]="Phase 1:#C5DEF5"
    ["phase-2"]="Phase 2:#C5DEF5"
    ["phase-3"]="Phase 3:#C5DEF5"
    ["phase-4"]="Phase 4:#C5DEF5"
    ["phase-5"]="Phase 5:#C5DEF5"
    ["phase-6"]="Phase 6:#C5DEF5"
)

# Type labels
declare -A TYPE_LABELS=(
    ["bug"]="Something isn't working:#D73A4A"
    ["enhancement"]="New feature or request:#A2EEEF"
    ["documentation"]="Documentation improvements:#0075CA"
)

create_label() {
    local name="$1"
    local desc_color="$2"
    local description="${desc_color%%:*}"
    local color="${desc_color##*:#}"

    # Check if label exists
    if gh label list --json name -q ".[].name" | grep -q "^${name}$"; then
        echo -e "  ${YELLOW}EXISTS${NC} $name"
    else
        if gh label create "$name" --description "$description" --color "$color" 2>/dev/null; then
            echo -e "  ${GREEN}CREATED${NC} $name"
        else
            echo -e "  ${RED}FAILED${NC} $name"
        fi
    fi
}

echo -e "${BLUE}Workflow Labels${NC}"
for label in "${!WORKFLOW_LABELS[@]}"; do
    create_label "$label" "${WORKFLOW_LABELS[$label]}"
done

echo ""
echo -e "${BLUE}Phase Labels${NC}"
for label in "${!PHASE_LABELS[@]}"; do
    create_label "$label" "${PHASE_LABELS[$label]}"
done

echo ""
echo -e "${BLUE}Type Labels${NC}"
for label in "${!TYPE_LABELS[@]}"; do
    create_label "$label" "${TYPE_LABELS[$label]}"
done

echo ""
echo -e "${GREEN}Label setup complete!${NC}"
echo ""
echo "Workflow labels:"
echo "  agent-ready   → Task available for agents"
echo "  in-progress   → Agent working on it"
echo "  needs-review  → PR created"
echo "  blocked       → Waiting on something"
