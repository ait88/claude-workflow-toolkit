#!/usr/bin/env bash
# telemetry-init.sh
# Initialize telemetry infrastructure for any project
# Usage: ./scripts/telemetry-init.sh --target ~/myproject

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="${SCRIPT_DIR}/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
TARGET_PROJECT=""
DRY_RUN=false
FORCE=false
USE_SYMLINKS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target|-t)
            TARGET_PROJECT="$2"
            shift 2
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --link|-l)
            USE_SYMLINKS=true
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 --target <path> [OPTIONS]

Initialize telemetry infrastructure for a project.

REQUIRED:
  --target, -t <path>  Target project path

OPTIONS:
  --dry-run, -n        Preview what would be created
  --force, -f          Overwrite existing files
  --link, -l           Use symlinks to toolkit
  --help, -h           Show this help

CREATES:
  <target>/.claude/telemetry/           Data directory
  <target>/.claude/telemetry/.gitignore Excludes raw logs
  <target>/lib/telemetry.sh             Core library
  <target>/lib/telemetry-session.sh     Session module

EXAMPLES:
  $0 --target ~/myproject
  $0 --target ~/myproject --link
  $0 --target ~/myproject --dry-run

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate target
if [[ -z "$TARGET_PROJECT" ]]; then
    echo -e "${RED}Error: --target required${NC}"
    echo "Usage: $0 --target <path>"
    exit 1
fi

if [[ ! -d "$TARGET_PROJECT" ]]; then
    echo -e "${RED}Error: Target directory does not exist: $TARGET_PROJECT${NC}"
    exit 1
fi

# Resolve to absolute path
TARGET_PROJECT="$(cd "$TARGET_PROJECT" && pwd)"

# Helper functions
_create_dir() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        echo -e "  ${CYAN}exists${NC}  $dir"
    else
        if $DRY_RUN; then
            echo -e "  ${YELLOW}would create${NC}  $dir"
        else
            mkdir -p "$dir"
            echo -e "  ${GREEN}created${NC} $dir"
        fi
    fi
}

_create_file() {
    local file="$1"
    local content="$2"

    if [[ -f "$file" ]] && [[ "$FORCE" == "false" ]]; then
        echo -e "  ${CYAN}exists${NC}  $file"
    else
        if $DRY_RUN; then
            echo -e "  ${YELLOW}would create${NC}  $file"
        else
            echo "$content" > "$file"
            echo -e "  ${GREEN}created${NC} $file"
        fi
    fi
}

_copy_file() {
    local src="$1"
    local dest="$2"

    if [[ -f "$dest" ]] && [[ "$FORCE" == "false" ]]; then
        echo -e "  ${CYAN}exists${NC}  $dest"
    else
        if $DRY_RUN; then
            echo -e "  ${YELLOW}would copy${NC}   $(basename "$src") -> $dest"
        else
            cp "$src" "$dest"
            echo -e "  ${GREEN}copied${NC}  $dest"
        fi
    fi
}

_symlink_file() {
    local src="$1"
    local dest="$2"

    if [[ -L "$dest" ]]; then
        echo -e "  ${CYAN}exists${NC}  $dest (symlink)"
    elif [[ -f "$dest" ]] && [[ "$FORCE" == "false" ]]; then
        echo -e "  ${CYAN}exists${NC}  $dest"
    else
        if $DRY_RUN; then
            echo -e "  ${YELLOW}would link${NC}   $dest -> $src"
        else
            rm -f "$dest" 2>/dev/null || true
            ln -s "$src" "$dest"
            echo -e "  ${GREEN}linked${NC}  $dest"
        fi
    fi
}

# Main
echo ""
echo "========================================"
echo -e "${BLUE}Telemetry Initialization${NC}"
echo "========================================"
echo ""
echo -e "${CYAN}Target:${NC}  $TARGET_PROJECT"
echo -e "${CYAN}Toolkit:${NC} $TOOLKIT_ROOT"
if $DRY_RUN; then
    echo -e "${YELLOW}Dry run - no changes will be made${NC}"
fi
echo ""

# 1. Create telemetry directory
echo "Creating telemetry directory..."
_create_dir "${TARGET_PROJECT}/.claude/telemetry"

# 2. Create .gitignore
echo ""
echo "Setting up gitignore..."
GITIGNORE_CONTENT="# Telemetry raw logs (too noisy for git)
invocations.log

# Keep aggregated data
!usage.json
"
_create_file "${TARGET_PROJECT}/.claude/telemetry/.gitignore" "$GITIGNORE_CONTENT"
_create_file "${TARGET_PROJECT}/.claude/telemetry/.gitkeep" ""

# 3. Create lib directory
echo ""
echo "Installing telemetry library..."
_create_dir "${TARGET_PROJECT}/lib"

if $USE_SYMLINKS; then
    _symlink_file "${TOOLKIT_ROOT}/lib/telemetry.sh" "${TARGET_PROJECT}/lib/telemetry.sh"
    _symlink_file "${TOOLKIT_ROOT}/lib/telemetry-session.sh" "${TARGET_PROJECT}/lib/telemetry-session.sh"
else
    _copy_file "${TOOLKIT_ROOT}/lib/telemetry.sh" "${TARGET_PROJECT}/lib/telemetry.sh"
    _copy_file "${TOOLKIT_ROOT}/lib/telemetry-session.sh" "${TARGET_PROJECT}/lib/telemetry-session.sh"
fi

# 4. Optionally install telemetry skills
echo ""
echo "Installing telemetry skills..."
if [[ -d "${TARGET_PROJECT}/.claude/skills" ]]; then
    if $USE_SYMLINKS; then
        _symlink_file "${TOOLKIT_ROOT}/templates/skills/telemetry-report.sh.template" "${TARGET_PROJECT}/.claude/skills/telemetry-report"
        _symlink_file "${TOOLKIT_ROOT}/templates/skills/telemetry-aggregate.sh.template" "${TARGET_PROJECT}/.claude/skills/telemetry-aggregate"
    else
        # Use install-skill.sh if available
        if [[ -x "${TOOLKIT_ROOT}/scripts/install-skill.sh" ]]; then
            if ! $DRY_RUN; then
                "${TOOLKIT_ROOT}/scripts/install-skill.sh" telemetry-report --target "$TARGET_PROJECT" 2>/dev/null || true
                "${TOOLKIT_ROOT}/scripts/install-skill.sh" telemetry-aggregate --target "$TARGET_PROJECT" 2>/dev/null || true
                echo -e "  ${GREEN}installed${NC} telemetry-report, telemetry-aggregate"
            else
                echo -e "  ${YELLOW}would install${NC} telemetry-report, telemetry-aggregate"
            fi
        fi
    fi
else
    echo -e "  ${YELLOW}skipped${NC} No .claude/skills directory (run sync-skills first)"
fi

# Summary
echo ""
echo "========================================"
echo "Next Steps"
echo "========================================"
echo ""
echo "1. Add telemetry to your skills:"
echo ""
echo -e "   ${CYAN}# At the start of your skill${NC}"
echo '   source "${SCRIPT_DIR}/../lib/telemetry.sh" 2>/dev/null || true'
echo '   telemetry_start "your-skill-name"'
echo ""
echo "2. Run skills normally - invocations logged automatically"
echo ""
echo "3. View reports:"
echo "   /telemetry-report"
echo "   /telemetry-aggregate"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}This was a dry run. Remove --dry-run to apply.${NC}"
else
    echo -e "${GREEN}Telemetry initialized for $TARGET_PROJECT${NC}"
fi
