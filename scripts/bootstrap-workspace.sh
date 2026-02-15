#!/usr/bin/env bash
# bootstrap-workspace.sh
# Single-command setup for a new workspace with all toolkit features
#
# Usage:
#   ./scripts/bootstrap-workspace.sh <workspace-path> --source <project-path>
#   ./scripts/bootstrap-workspace.sh ~/workspaces/myproject --source ~/myproject
#
# Options:
#   --source <path>     Target project path (required)
#   --profile <name>    Profile to use (default: default)
#   --repo <owner/name> Explicit repo override
#   --dry-run           Show what would be done

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script location (toolkit source)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
WORKSPACE_PATH=""
SOURCE_PATH=""
PROFILE_NAME="default"
REPO_OWNER=""
REPO_NAME=""
DRY_RUN=false

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

usage() {
    cat <<EOF
Usage: $0 <workspace-path> --source <project-path> [options]

Bootstrap a new workspace for the workflow toolkit.

Arguments:
  <workspace-path>     Path where workspace will be created

Options:
  --source <path>      Target project path (required)
  --profile <name>     Profile to use (default: default)
  --repo <owner/name>  Explicit GitHub repo (auto-detected if not provided)
  --dry-run            Show what would be done without making changes
  --help               Show this help message

Examples:
  $0 ~/workspaces/myproject --source ~/myproject
  $0 ~/workspaces/myproject --source ~/myproject --profile node-npm
  $0 ~/workspaces/myproject --source ~/myproject --repo myorg/myproject

What it does:
  1. Creates workspace directory structure
  2. Installs all skills from profile
  3. Installs CLAUDE.md with workflow rules
  4. Creates workspace-config pointing to target
  5. Sets up .codex/skills symlink for dual-agent support
  6. Prints agent priming command

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source|-s)
            SOURCE_PATH="$2"
            shift 2
            ;;
        --profile|-p)
            PROFILE_NAME="$2"
            shift 2
            ;;
        --repo|-r)
            REPO_OWNER="${2%%/*}"
            REPO_NAME="${2##*/}"
            shift 2
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            if [[ -z "$WORKSPACE_PATH" ]]; then
                WORKSPACE_PATH="$1"
            else
                echo -e "${RED}Unexpected argument: $1${NC}"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$WORKSPACE_PATH" ]]; then
    echo -e "${RED}Error: Workspace path required${NC}"
    echo ""
    usage
    exit 1
fi

if [[ -z "$SOURCE_PATH" ]]; then
    echo -e "${RED}Error: --source <project-path> required${NC}"
    echo ""
    usage
    exit 1
fi

# Resolve paths
WORKSPACE_PATH="$(realpath -m "$WORKSPACE_PATH")"
SOURCE_PATH="$(realpath "$SOURCE_PATH")"

# Validate source exists
if [[ ! -d "$SOURCE_PATH" ]]; then
    echo -e "${RED}Error: Source project not found: $SOURCE_PATH${NC}"
    exit 1
fi

# Validate profile exists
PROFILE_FILE="$TOOLKIT_DIR/profiles/${PROFILE_NAME}.yaml"
if [[ ! -f "$PROFILE_FILE" ]]; then
    echo -e "${RED}Error: Profile '$PROFILE_NAME' not found${NC}"
    echo "Available profiles:"
    ls -1 "$TOOLKIT_DIR/profiles/"*.yaml 2>/dev/null | xargs -I {} basename {} .yaml | sed 's/^/  /'
    exit 1
fi

# ============================================================================
# REPO DETECTION
# ============================================================================

if [[ -z "$REPO_OWNER" ]] || [[ -z "$REPO_NAME" ]]; then
    if [[ -d "$SOURCE_PATH/.git" ]]; then
        # Try to get from gh cli
        repo_info=$(cd "$SOURCE_PATH" && gh repo view --json owner,name 2>/dev/null) || true
        if [[ -n "$repo_info" ]]; then
            REPO_OWNER=$(echo "$repo_info" | jq -r '.owner.login')
            REPO_NAME=$(echo "$repo_info" | jq -r '.name')
        else
            # Try to parse from remote URL
            remote_url=$(cd "$SOURCE_PATH" && git remote get-url origin 2>/dev/null) || true
            if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
                REPO_OWNER="${BASH_REMATCH[1]}"
                REPO_NAME="${BASH_REMATCH[2]}"
            fi
        fi
    fi
fi

# Fallback to directory name
[[ -z "$REPO_OWNER" ]] && REPO_OWNER="OWNER"
[[ -z "$REPO_NAME" ]] && REPO_NAME="$(basename "$SOURCE_PATH")"

# ============================================================================
# BOOTSTRAP
# ============================================================================

echo ""
echo "========================================"
echo -e "${BLUE}Bootstrapping Workspace${NC}"
echo "========================================"
echo -e "Workspace: ${BLUE}$WORKSPACE_PATH${NC}"
echo -e "Target:    ${BLUE}$SOURCE_PATH${NC}"
echo -e "Repo:      ${BLUE}$REPO_OWNER/$REPO_NAME${NC}"
echo -e "Profile:   ${BLUE}$PROFILE_NAME${NC}"
echo -e "Toolkit:   ${BLUE}$TOOLKIT_DIR${NC}"
echo ""

# Check if workspace exists
if [[ -d "$WORKSPACE_PATH/.claude" ]]; then
    echo -e "${YELLOW}Warning: Workspace already exists at $WORKSPACE_PATH${NC}"
    echo "Use install-skill.sh --update to update existing installation"
    echo ""
fi

# Create directory structure
echo "Creating directory structure..."

_mkdir() {
    if $DRY_RUN; then
        echo -e "  ${BLUE}→${NC} $1"
    else
        mkdir -p "$1"
        echo -e "  ${GREEN}✓${NC} $1"
    fi
}

_mkdir "$WORKSPACE_PATH/.claude/skills"
_mkdir "$WORKSPACE_PATH/.claude/commands"
_mkdir "$WORKSPACE_PATH/.claude/docs"
_mkdir "$WORKSPACE_PATH/.claude/worker"

# Create .codex symlink
echo ""
echo "Setting up Codex compatibility..."
if $DRY_RUN; then
    echo -e "  ${BLUE}→${NC} .codex/skills -> .claude/skills"
else
    mkdir -p "$WORKSPACE_PATH/.codex"
    rm -f "$WORKSPACE_PATH/.codex/skills"
    ln -s ../.claude/skills "$WORKSPACE_PATH/.codex/skills"
    echo -e "  ${GREEN}✓${NC} .codex/skills -> .claude/skills"
fi

# Create workspace-config
echo ""
echo "Creating workspace configuration..."
WORKSPACE_CONFIG="$WORKSPACE_PATH/.claude/workspace-config"
if $DRY_RUN; then
    echo -e "  ${BLUE}→${NC} workspace-config"
else
    cat > "$WORKSPACE_CONFIG" <<CONFIGEOF
# Workspace configuration for claude-workflow-toolkit
# Generated by bootstrap-workspace.sh

# Target project this workspace operates on
TARGET_PROJECT_PATH="$SOURCE_PATH"

# GitHub repository information
TARGET_REPO_OWNER="$REPO_OWNER"
TARGET_REPO_NAME="$REPO_NAME"

# Toolkit source (for updates)
TOOLKIT_SOURCE="$TOOLKIT_DIR"

# Profile used for installation
TOOLKIT_PROFILE="$PROFILE_NAME"
CONFIGEOF
    echo -e "  ${GREEN}✓${NC} workspace-config"
fi

# Install everything via --full
echo ""
echo "Installing toolkit (skills, CLAUDE.md, roles, docs)..."
if $DRY_RUN; then
    "$TOOLKIT_DIR/scripts/install-skill.sh" --full --target "$WORKSPACE_PATH" --profile "$PROFILE_NAME" --update --dry-run
else
    "$TOOLKIT_DIR/scripts/install-skill.sh" --full --target "$WORKSPACE_PATH" --profile "$PROFILE_NAME" --update
fi

# Summary
echo ""
echo "========================================"
echo -e "${GREEN}Bootstrap Complete!${NC}"
echo "========================================"
echo ""
echo "Start agents with:"
echo -e "  ${BLUE}cd $WORKSPACE_PATH${NC}"
echo -e "  ${BLUE}claude -c \"read CLAUDE.md then /check-workflow\"${NC}"
echo ""
echo "Or use the autonomous worker:"
echo -e "  ${BLUE}claude -c \"/worker --once\"${NC}"
echo ""
