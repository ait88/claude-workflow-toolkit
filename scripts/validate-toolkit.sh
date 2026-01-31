#!/usr/bin/env bash
# validate-toolkit.sh
# Validates toolkit installation against templates and profile
#
# Usage: ./scripts/validate-toolkit.sh [--target <path>] [--profile <name>]
#
# Features:
# - Checks skill completeness against profile
# - Detects outdated skills (template newer than installed)
# - Finds unreplaced placeholders
# - Verifies command documentation exists

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

# Script location (toolkit source)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
TARGET_PATH=""
PROFILE_NAME="default"
ISSUES_FOUND=0
WARNINGS_FOUND=0

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

usage() {
    echo "Usage: $0 [--target <path>] [--profile <name>]"
    echo ""
    echo "Validates toolkit installation against templates and profile."
    echo ""
    echo "Options:"
    echo "  --target <path>    Path to workspace or project to validate"
    echo "                     (default: current directory)"
    echo "  --profile <name>   Profile to validate against (default: default)"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Validate current directory"
    echo "  $0 --target ~/workspaces/myproject   # Validate specific workspace"
    echo "  $0 --profile node-npm                # Use node-npm profile"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target|-t)
            TARGET_PATH="$2"
            shift 2
            ;;
        --profile|-p)
            PROFILE_NAME="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Determine target path
if [[ -z "$TARGET_PATH" ]]; then
    # Check if we're in a workspace with workspace-config
    if [[ -f ".claude/workspace-config" ]]; then
        TARGET_PATH="$(pwd)"
    elif [[ -f "$TOOLKIT_DIR/.claude/workspace-config" ]]; then
        TARGET_PATH="$TOOLKIT_DIR"
    else
        TARGET_PATH="$(pwd)"
    fi
fi

TARGET_PATH="$(realpath "$TARGET_PATH")"

# Verify profile exists
PROFILE_FILE="$TOOLKIT_DIR/profiles/${PROFILE_NAME}.yaml"
if [[ ! -f "$PROFILE_FILE" ]]; then
    echo -e "${RED}Error: Profile '$PROFILE_NAME' not found at $PROFILE_FILE${NC}"
    echo "Available profiles:"
    ls -1 "$TOOLKIT_DIR/profiles/"*.yaml 2>/dev/null | xargs -I {} basename {} .yaml | sed 's/^/  /'
    exit 1
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Parse YAML value (simple implementation for flat values)
yaml_get() {
    local file="$1"
    local key="$2"
    grep "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/["\x27]//g' | tr -d '\r'
}

# Parse YAML list under a key
yaml_get_list() {
    local file="$1"
    local section="$2"
    local key="$3"

    # Find the section, then the key, then extract list items
    awk -v section="$section" -v key="$key" '
        $0 ~ "^" section ":" { in_section=1; next }
        in_section && /^[a-z]/ { in_section=0 }
        in_section && $0 ~ "^[[:space:]]*" key ":" { in_key=1; next }
        in_key && /^[[:space:]]*-/ { gsub(/^[[:space:]]*-[[:space:]]*/, ""); print }
        in_key && /^[[:space:]]*[a-z_]+:/ { in_key=0 }
    ' "$file"
}

# Check if file contains unreplaced placeholders
check_placeholders() {
    local file="$1"
    grep -n '{{[A-Z_]*}}' "$file" 2>/dev/null || true
}

# Get file modification time as epoch
file_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo "0"
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_skills() {
    echo ""
    echo -e "${BLUE}Skills:${NC}"

    local skills_dir="$TARGET_PATH/.claude/skills"
    local templates_dir="$TOOLKIT_DIR/templates/skills"

    # Get expected skills from profile
    local expected_skills
    expected_skills=$(yaml_get_list "$PROFILE_FILE" "output" "skills" | grep -v "README" || true)

    if [[ -z "$expected_skills" ]]; then
        echo "  (no skills defined in profile)"
        return
    fi

    for skill in $expected_skills; do
        local installed_file="$skills_dir/$skill"
        local template_file="$templates_dir/${skill}.sh.template"

        # Check if skill is a shell script (not README.md)
        if [[ "$skill" == "README.md" ]]; then
            continue
        fi

        if [[ ! -f "$template_file" ]]; then
            # Template doesn't exist, skip
            continue
        fi

        if [[ ! -f "$installed_file" ]]; then
            echo -e "  $CROSS $skill (MISSING - template available)"
            echo -e "      Run: ./scripts/install-skill.sh $skill --target $TARGET_PATH"
            ((++ISSUES_FOUND))
        else
            # Check if outdated
            local installed_mtime template_mtime
            installed_mtime=$(file_mtime "$installed_file")
            template_mtime=$(file_mtime "$template_file")

            if [[ "$template_mtime" -gt "$installed_mtime" ]]; then
                local template_date
                template_date=$(date -d "@$template_mtime" +%Y-%m-%d 2>/dev/null || date -r "$template_mtime" +%Y-%m-%d 2>/dev/null || echo "unknown")
                echo -e "  $WARN $skill (OUTDATED - template modified $template_date)"
                echo -e "      Run: ./scripts/install-skill.sh $skill --target $TARGET_PATH --update"
                ((++WARNINGS_FOUND))
            else
                echo -e "  $CHECK $skill"
            fi

            # Check for unreplaced placeholders
            local placeholders
            placeholders=$(check_placeholders "$installed_file")
            if [[ -n "$placeholders" ]]; then
                echo -e "      ${YELLOW}Unreplaced placeholders found:${NC}"
                echo "$placeholders" | while read -r line; do
                    echo -e "        $line"
                done
                ((++ISSUES_FOUND))
            fi
        fi
    done
}

validate_commands() {
    echo ""
    echo -e "${BLUE}Command Documentation:${NC}"

    local commands_dir="$TARGET_PATH/.claude/commands"
    local global_commands_dir="$HOME/.claude/commands"
    local templates_dir="$TOOLKIT_DIR/templates/.claude/commands"

    # Get expected commands from profile
    local expected_commands
    expected_commands=$(yaml_get_list "$PROFILE_FILE" "output" "commands" || true)

    if [[ -z "$expected_commands" ]]; then
        echo "  (no commands defined in profile)"
        return
    fi

    for cmd in $expected_commands; do
        local template_file="$templates_dir/${cmd}.md.template"

        if [[ ! -f "$template_file" ]]; then
            continue
        fi

        # Check local commands dir first, then global
        local installed_file=""
        if [[ -f "$commands_dir/${cmd}.md" ]]; then
            installed_file="$commands_dir/${cmd}.md"
        elif [[ -f "$global_commands_dir/${cmd}.md" ]]; then
            installed_file="$global_commands_dir/${cmd}.md"
        fi

        if [[ -z "$installed_file" ]]; then
            echo -e "  $CROSS ${cmd}.md (MISSING)"
            ((++ISSUES_FOUND))
        else
            echo -e "  $CHECK ${cmd}.md"

            # Check for unreplaced placeholders
            local placeholders
            placeholders=$(check_placeholders "$installed_file")
            if [[ -n "$placeholders" ]]; then
                echo -e "      ${YELLOW}Unreplaced placeholders found:${NC}"
                echo "$placeholders" | head -5 | while read -r line; do
                    echo -e "        $line"
                done
                ((++ISSUES_FOUND))
            fi
        fi
    done
}

validate_workspace_config() {
    echo ""
    echo -e "${BLUE}Workspace Configuration:${NC}"

    local config_file="$TARGET_PATH/.claude/workspace-config"

    if [[ ! -f "$config_file" ]]; then
        echo -e "  $WARN No workspace-config found (embedded mode assumed)"
        return
    fi

    echo -e "  $CHECK workspace-config exists"

    # Source the config and validate required fields
    source "$config_file"

    if [[ -z "${TARGET_PROJECT_PATH:-}" ]]; then
        echo -e "  $CROSS TARGET_PROJECT_PATH not set"
        ((++ISSUES_FOUND))
    elif [[ ! -d "$TARGET_PROJECT_PATH" ]]; then
        echo -e "  $CROSS TARGET_PROJECT_PATH does not exist: $TARGET_PROJECT_PATH"
        ((++ISSUES_FOUND))
    else
        echo -e "  $CHECK TARGET_PROJECT_PATH: $TARGET_PROJECT_PATH"
    fi

    if [[ -z "${TARGET_REPO_OWNER:-}" ]]; then
        echo -e "  $WARN TARGET_REPO_OWNER not set"
        ((++WARNINGS_FOUND))
    else
        echo -e "  $CHECK TARGET_REPO_OWNER: $TARGET_REPO_OWNER"
    fi

    if [[ -z "${TARGET_REPO_NAME:-}" ]]; then
        echo -e "  $WARN TARGET_REPO_NAME not set"
        ((++WARNINGS_FOUND))
    else
        echo -e "  $CHECK TARGET_REPO_NAME: $TARGET_REPO_NAME"
    fi
}

validate_labels() {
    echo ""
    echo -e "${BLUE}GitHub Labels:${NC}"

    # Try to get repo info
    local owner repo
    if [[ -f "$TARGET_PATH/.claude/workspace-config" ]]; then
        source "$TARGET_PATH/.claude/workspace-config"
        owner="${TARGET_REPO_OWNER:-}"
        repo="${TARGET_REPO_NAME:-}"
    fi

    if [[ -z "$owner" ]] || [[ -z "$repo" ]]; then
        # Try to detect from git
        if [[ -d "$TARGET_PATH/.git" ]]; then
            local repo_info
            repo_info=$(cd "$TARGET_PATH" && gh repo view --json owner,name 2>/dev/null) || true
            if [[ -n "$repo_info" ]]; then
                owner=$(echo "$repo_info" | jq -r '.owner.login')
                repo=$(echo "$repo_info" | jq -r '.name')
            fi
        fi
    fi

    if [[ -z "$owner" ]] || [[ -z "$repo" ]]; then
        echo "  (could not determine repository)"
        return
    fi

    # Check for required workflow labels
    local required_labels=("agent-ready" "in-progress" "needs-review" "blocked")
    local existing_labels
    existing_labels=$(gh label list --repo "$owner/$repo" --json name --jq '.[].name' 2>/dev/null || true)

    for label in "${required_labels[@]}"; do
        if echo "$existing_labels" | grep -q "^${label}$"; then
            echo -e "  $CHECK $label"
        else
            echo -e "  $CROSS $label (MISSING)"
            echo -e "      Run: gh label create '$label' --repo $owner/$repo"
            ((++ISSUES_FOUND))
        fi
    done
}

# ============================================================================
# MAIN
# ============================================================================

echo ""
echo "========================================"
echo "Toolkit Validation Report"
echo "========================================"
echo -e "Profile: ${BLUE}$PROFILE_NAME${NC}"
echo -e "Target:  ${BLUE}$TARGET_PATH${NC}"
echo -e "Toolkit: ${BLUE}$TOOLKIT_DIR${NC}"

validate_workspace_config
validate_skills
validate_commands
validate_labels

# Summary
echo ""
echo "========================================"
echo "Summary"
echo "========================================"

if [[ $ISSUES_FOUND -eq 0 ]] && [[ $WARNINGS_FOUND -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
elif [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${YELLOW}$WARNINGS_FOUND warning(s) found${NC}"
    exit 0
else
    echo -e "${RED}$ISSUES_FOUND issue(s) found${NC}"
    [[ $WARNINGS_FOUND -gt 0 ]] && echo -e "${YELLOW}$WARNINGS_FOUND warning(s) found${NC}"
    exit 1
fi
