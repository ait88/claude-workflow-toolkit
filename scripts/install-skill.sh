#!/usr/bin/env bash
# install-skill.sh
# Automated skill installation from templates
#
# Usage:
#   ./scripts/install-skill.sh <skill-name> [options]
#   ./scripts/install-skill.sh --list
#   ./scripts/install-skill.sh --all
#   ./scripts/install-skill.sh --full
#
# Options:
#   --target <path>    Target workspace/project directory
#   --profile <name>   Profile to use for placeholder values (default: default)
#   --update           Force update even if skill exists
#   --full             Sync everything: skills + commands + CLAUDE.md + roles + docs
#   --dry-run          Show what would be done without making changes

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
TARGET_PATH=""
PROFILE_NAME="default"
UPDATE_MODE=false
DRY_RUN=false
LIST_MODE=false
ALL_MODE=false
FULL_MODE=false
INSTALL_CLAUDE_MD=false
SKILL_NAME=""

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

usage() {
    cat <<EOF
Usage: $0 <skill-name> [options]
       $0 --list
       $0 --all [options]
       $0 --full [options]

Install skills from templates to a workspace or project.

Arguments:
  <skill-name>         Name of skill to install (e.g., worker, claim-issue)

Options:
  --target <path>      Target workspace/project directory (default: current dir)
  --profile <name>     Profile for placeholder values (default: default)
  --update             Force update even if skill already exists
  --dry-run            Show what would be done without making changes
  --list               List available skills
  --all                Install all skills from profile
  --full               Full toolkit sync: skills + CLAUDE.md + roles + docs + config
  --with-claude-md     Also install CLAUDE.md to project root
  --help               Show this help message

Examples:
  $0 worker                           # Install worker to current directory
  $0 worker --target ~/my-workspace   # Install to specific workspace
  $0 --all --profile node-npm         # Install all skills with node profile
  $0 --full --target ~/my-workspace   # Full toolkit sync
  $0 claim-issue --update             # Update existing skill
  $0 --list                           # Show available skills

EOF
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
        --update|-u)
            UPDATE_MODE=true
            shift
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --list|-l)
            LIST_MODE=true
            shift
            ;;
        --all|-a)
            ALL_MODE=true
            shift
            ;;
        --full)
            FULL_MODE=true
            ALL_MODE=true
            shift
            ;;
        --with-claude-md)
            INSTALL_CLAUDE_MD=true
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
            if [[ -z "$SKILL_NAME" ]]; then
                SKILL_NAME="$1"
            else
                echo -e "${RED}Unexpected argument: $1${NC}"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Parse simple YAML value
yaml_get() {
    local file="$1"
    local key="$2"
    grep "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/["\x27]//g' | tr -d '\r'
}

# Parse YAML list under a section.key
yaml_get_list() {
    local file="$1"
    local section="$2"
    local key="$3"

    awk -v section="$section" -v key="$key" '
        $0 ~ "^" section ":" { in_section=1; next }
        in_section && /^[a-z]/ { in_section=0 }
        in_section && $0 ~ "^[[:space:]]*" key ":" { in_key=1; next }
        in_key && /^[[:space:]]*-/ { gsub(/^[[:space:]]*-[[:space:]]*/, ""); print }
        in_key && /^[[:space:]]*[a-z_]+:/ { in_key=0 }
    ' "$file"
}

# Get nested YAML value (section.key)
yaml_get_nested() {
    local file="$1"
    local section="$2"
    local key="$3"

    awk -v section="$section" -v key="$key" '
        $0 ~ "^" section ":" { in_section=1; next }
        in_section && /^[a-z]/ { in_section=0 }
        in_section && $0 ~ "^[[:space:]]*" key ":" {
            gsub(/^[[:space:]]*[a-z_]+:[[:space:]]*/, "")
            gsub(/["\x27]/, "")
            gsub(/[[:space:]]*#.*$/, "")  # Remove comments
            print
            exit
        }
    ' "$file"
}

# Global placeholder map
declare -A PLACEHOLDERS

# Build placeholder substitution map from profile
build_placeholder_map() {
    local profile="$1"

    # Project settings
    PLACEHOLDERS[DEFAULT_BRANCH]=$(yaml_get_nested "$profile" "project" "default_branch")
    [[ -z "${PLACEHOLDERS[DEFAULT_BRANCH]:-}" ]] && PLACEHOLDERS[DEFAULT_BRANCH]="main" || true

    # Workflow settings
    PLACEHOLDERS[PHASE_PREFIX]=$(yaml_get_nested "$profile" "workflow" "phase_prefix")
    [[ -z "${PLACEHOLDERS[PHASE_PREFIX]:-}" ]] && PLACEHOLDERS[PHASE_PREFIX]="phase-" || true

    PLACEHOLDERS[CODEX_BOT_USER]=$(yaml_get_nested "$profile" "workflow" "codex_bot_user")
    [[ -z "${PLACEHOLDERS[CODEX_BOT_USER]:-}" ]] && PLACEHOLDERS[CODEX_BOT_USER]="chatgpt-codex-connector[bot]" || true

    # Commands
    PLACEHOLDERS[TEST_COMMAND]=$(yaml_get_nested "$profile" "commands" "test")
    [[ -z "${PLACEHOLDERS[TEST_COMMAND]:-}" ]] && PLACEHOLDERS[TEST_COMMAND]="echo 'No test command configured'" || true

    PLACEHOLDERS[LINT_COMMAND]=$(yaml_get_nested "$profile" "commands" "lint")
    [[ -z "${PLACEHOLDERS[LINT_COMMAND]:-}" ]] && PLACEHOLDERS[LINT_COMMAND]="echo 'No lint command configured'" || true

    PLACEHOLDERS[TEST_UNIT_COMMAND]=$(yaml_get_nested "$profile" "commands" "test_unit") || true
    PLACEHOLDERS[TEST_INTEGRATION_COMMAND]=$(yaml_get_nested "$profile" "commands" "test_integration") || true

    # Worker settings
    PLACEHOLDERS[WORKER_MAX_RETRIES]=$(yaml_get_nested "$profile" "worker" "max_retries")
    [[ -z "${PLACEHOLDERS[WORKER_MAX_RETRIES]:-}" ]] && PLACEHOLDERS[WORKER_MAX_RETRIES]="3" || true

    PLACEHOLDERS[WORKER_MAX_ISSUES]=$(yaml_get_nested "$profile" "worker" "max_issues")
    [[ -z "${PLACEHOLDERS[WORKER_MAX_ISSUES]:-}" ]] && PLACEHOLDERS[WORKER_MAX_ISSUES]="10" || true

    PLACEHOLDERS[WORKER_POLL_INTERVAL]=$(yaml_get_nested "$profile" "worker" "poll_interval")
    [[ -z "${PLACEHOLDERS[WORKER_POLL_INTERVAL]:-}" ]] && PLACEHOLDERS[WORKER_POLL_INTERVAL]="60" || true

    PLACEHOLDERS[WORKER_PARALLEL_DEFAULT]=$(yaml_get_nested "$profile" "worker" "parallel_default")
    [[ -z "${PLACEHOLDERS[WORKER_PARALLEL_DEFAULT]:-}" ]] && PLACEHOLDERS[WORKER_PARALLEL_DEFAULT]="1" || true

    PLACEHOLDERS[WORKER_PARALLEL_MAX]=$(yaml_get_nested "$profile" "worker" "parallel_max")
    [[ -z "${PLACEHOLDERS[WORKER_PARALLEL_MAX]:-}" ]] && PLACEHOLDERS[WORKER_PARALLEL_MAX]="5" || true
}

# Substitute placeholders in a file
substitute_placeholders() {
    local input_file="$1"
    local output_file="$2"

    local content
    content=$(cat "$input_file")

    # Substitute each placeholder
    for key in "${!PLACEHOLDERS[@]}"; do
        local value="${PLACEHOLDERS[$key]}"
        # Escape special characters in value for sed
        value=$(echo "$value" | sed 's/[&/\]/\\&/g')
        content=$(echo "$content" | sed "s|{{${key}}}|${value}|g")
    done

    if $DRY_RUN; then
        echo "[DRY RUN] Would write to: $output_file"
    else
        # Write to temp file then atomically move into place.
        # This prevents corruption when a skill overwrites itself during sync.
        local tmp_file
        tmp_file=$(mktemp "${output_file}.XXXXXX")
        echo "$content" > "$tmp_file"
        mv -f "$tmp_file" "$output_file"
    fi
}

# Check for unreplaced placeholders
check_placeholders() {
    local file="$1"
    local unreplaced
    unreplaced=$(grep -o '{{[A-Z_]*}}' "$file" 2>/dev/null | sort -u || true)

    if [[ -n "$unreplaced" ]]; then
        echo -e "${YELLOW}Warning: Unreplaced placeholders in $file:${NC}"
        echo "$unreplaced" | sed 's/^/  /'
        return 1
    fi
    return 0
}

# List available skills
list_skills() {
    echo "Available skills:"
    echo ""

    for template in "$TOOLKIT_DIR/templates/skills/"*.sh.template; do
        [[ -f "$template" ]] || continue
        local skill_name
        skill_name=$(basename "$template" .sh.template)

        # Get description from template
        local description
        description=$(grep "^# Description:" "$template" 2>/dev/null | sed 's/^# Description:[[:space:]]*//' || echo "")

        printf "  %-20s %s\n" "$skill_name" "$description"
    done

    echo ""
    echo "Use: $0 <skill-name> to install"
}

# Install a single skill
install_skill() {
    local skill="$1"
    local skill_template="$TOOLKIT_DIR/templates/skills/${skill}.sh.template"
    local cmd_template="$TOOLKIT_DIR/templates/.claude/commands/${skill}.md.template"
    local skill_output="$TARGET_PATH/.claude/skills/$skill"
    local cmd_output="$TARGET_PATH/.claude/commands/${skill}.md"

    # Check template exists
    if [[ ! -f "$skill_template" ]]; then
        echo -e "${RED}Error: Template not found: $skill_template${NC}"
        return 1
    fi

    # Check if already installed (unless --update)
    if [[ -f "$skill_output" ]] && ! $UPDATE_MODE; then
        echo -e "  ${YELLOW}⊘${NC} $skill (already installed, use --update to override)"
        return 0
    fi

    # Create output directories
    if ! $DRY_RUN; then
        mkdir -p "$TARGET_PATH/.claude/skills"
        mkdir -p "$TARGET_PATH/.claude/commands"
    fi

    # Install skill script
    if $DRY_RUN; then
        echo -e "  ${BLUE}→${NC} $skill"
        echo "      Would install: $skill_output"
    else
        substitute_placeholders "$skill_template" "$skill_output"
        chmod +x "$skill_output"

        # Check for unreplaced placeholders
        if ! check_placeholders "$skill_output"; then
            echo -e "  ${YELLOW}⚠${NC} $skill (installed with warnings)"
        else
            echo -e "  ${GREEN}✓${NC} $skill"
        fi
    fi

    # Install command documentation if template exists
    if [[ -f "$cmd_template" ]]; then
        if $DRY_RUN; then
            echo "      Would install: $cmd_output"
        else
            substitute_placeholders "$cmd_template" "$cmd_output"
        fi
    fi

    return 0
}

# Install CLAUDE.md to project root
install_claude_md() {
    local template="$TOOLKIT_DIR/templates/CLAUDE.md.template"
    local output="$TARGET_PATH/CLAUDE.md"

    if [[ ! -f "$template" ]]; then
        echo -e "${YELLOW}Warning: CLAUDE.md template not found${NC}"
        return 1
    fi

    if [[ -f "$output" ]] && ! $UPDATE_MODE; then
        echo -e "  ${YELLOW}⊘${NC} CLAUDE.md (already exists, use --update to override)"
        return 0
    fi

    # Add repo-specific placeholders
    # Try to detect from workspace-config or git
    local repo_owner="" repo_name=""
    if [[ -f "$TARGET_PATH/.claude/workspace-config" ]]; then
        # shellcheck source=/dev/null
        source "$TARGET_PATH/.claude/workspace-config"
        repo_owner="${TARGET_REPO_OWNER:-}"
        repo_name="${TARGET_REPO_NAME:-}"
    fi

    if [[ -z "$repo_owner" ]] && [[ -d "$TARGET_PATH/.git" ]]; then
        local remote_url
        remote_url=$(cd "$TARGET_PATH" && git remote get-url origin 2>/dev/null || true)
        if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
            repo_owner="${BASH_REMATCH[1]}"
            repo_name="${BASH_REMATCH[2]}"
        fi
    fi

    [[ -z "$repo_owner" ]] && repo_owner="OWNER"
    [[ -z "$repo_name" ]] && repo_name="REPO"

    # Add to placeholders temporarily
    PLACEHOLDERS[REPO_OWNER]="$repo_owner"
    PLACEHOLDERS[REPO_NAME]="$repo_name"

    if $DRY_RUN; then
        echo -e "  ${BLUE}→${NC} CLAUDE.md"
        echo "      Would install: $output"
    else
        substitute_placeholders "$template" "$output"
        echo -e "  ${GREEN}✓${NC} CLAUDE.md"
    fi

    return 0
}

# ============================================================================
# FULL MODE FUNCTIONS
# ============================================================================

# Detect repo owner/name and populate workspace/project placeholders
_detect_repo_info() {
    local repo_owner="" repo_name="" target_project_path=""
    if [[ -f "$TARGET_PATH/.claude/workspace-config" ]]; then
        # shellcheck source=/dev/null
        source "$TARGET_PATH/.claude/workspace-config"
        repo_owner="${TARGET_REPO_OWNER:-}"
        repo_name="${TARGET_REPO_NAME:-}"
        target_project_path="${TARGET_PROJECT_PATH:-}"
    fi

    if [[ -z "$repo_owner" ]] && [[ -d "$TARGET_PATH/.git" ]]; then
        local remote_url
        remote_url=$(cd "$TARGET_PATH" && git remote get-url origin 2>/dev/null || true)
        if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
            repo_owner="${BASH_REMATCH[1]}"
            repo_name="${BASH_REMATCH[2]}"
        fi
    fi

    PLACEHOLDERS[REPO_OWNER]="${repo_owner:-OWNER}"
    PLACEHOLDERS[REPO_NAME]="${repo_name:-REPO}"

    # Workspace/project placeholders
    PLACEHOLDERS[PROJECT_NAME]="${repo_name:-$(basename "$TARGET_PATH")}"
    PLACEHOLDERS[TARGET_PROJECT_PATH]="${target_project_path:-$TARGET_PATH}"
    PLACEHOLDERS[WORKSPACE_NAME]="$(basename "$TARGET_PATH")"
    PLACEHOLDERS[WORKSPACE_PATH]="$TARGET_PATH"

    # Standard directory paths
    PLACEHOLDERS[SKILLS_DIR]=".claude/skills"
    PLACEHOLDERS[CODEX_SKILLS_DIR]=".codex/skills"
    PLACEHOLDERS[DOCS_DIR]=".claude/docs"

    # Dynamic placeholders (available to all install functions)
    PLACEHOLDERS[TOOLKIT_SOURCE]="$TOOLKIT_DIR"
    PLACEHOLDERS[TOOLKIT_COMMIT]=$(cd "$TOOLKIT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    PLACEHOLDERS[CURRENT_DATE]=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
}

# Install WORKER-ROLE.md (always overwrite)
install_worker_role() {
    local template="$TOOLKIT_DIR/templates/.claude/WORKER-ROLE.md.template"
    local output="$TARGET_PATH/.claude/WORKER-ROLE.md"

    if [[ ! -f "$template" ]]; then
        echo -e "  ${YELLOW}⊘${NC} WORKER-ROLE.md (template not found)"
        return 0
    fi

    if $DRY_RUN; then
        echo -e "  ${BLUE}→${NC} .claude/WORKER-ROLE.md"
        return 0
    fi

    mkdir -p "$TARGET_PATH/.claude"
    substitute_placeholders "$template" "$output"
    echo -e "  ${GREEN}✓${NC} .claude/WORKER-ROLE.md"
}

# Install SECURITY-CHECKLIST.md (always overwrite)
install_security_checklist() {
    # Determine which security checklist to use from profile
    local security_template=""
    local security_name
    security_name=$(yaml_get_list "$PROFILE_FILE" "output" "security" | head -1)

    if [[ -n "$security_name" ]]; then
        security_template="$TOOLKIT_DIR/templates/.claude/${security_name}.template"
    fi

    # Fallback to generic
    if [[ -z "$security_template" ]] || [[ ! -f "$security_template" ]]; then
        security_template="$TOOLKIT_DIR/templates/.claude/SECURITY-CHECKLIST.md.template"
    fi

    if [[ ! -f "$security_template" ]]; then
        echo -e "  ${YELLOW}⊘${NC} SECURITY-CHECKLIST.md (template not found)"
        return 0
    fi

    local output="$TARGET_PATH/.claude/SECURITY-CHECKLIST.md"

    if $DRY_RUN; then
        echo -e "  ${BLUE}→${NC} .claude/SECURITY-CHECKLIST.md"
        return 0
    fi

    mkdir -p "$TARGET_PATH/.claude"
    substitute_placeholders "$security_template" "$output"
    echo -e "  ${GREEN}✓${NC} .claude/SECURITY-CHECKLIST.md"
}

# Install toolkit-version file (always regenerate)
install_toolkit_version() {
    local template="$TOOLKIT_DIR/templates/.claude/toolkit-version.template"
    local output="$TARGET_PATH/.claude/toolkit-version"

    if [[ ! -f "$template" ]]; then
        echo -e "  ${YELLOW}⊘${NC} toolkit-version (template not found)"
        return 0
    fi

    # Installation mode (toolkit-version specific)
    PLACEHOLDERS[INSTALLATION_MODE]="full"

    if $DRY_RUN; then
        echo -e "  ${BLUE}→${NC} .claude/toolkit-version"
        return 0
    fi

    mkdir -p "$TARGET_PATH/.claude"
    substitute_placeholders "$template" "$output"
    echo -e "  ${GREEN}✓${NC} .claude/toolkit-version"
}

# Ensure .codex/skills symlink exists
ensure_codex_symlink() {
    local symlink="$TARGET_PATH/.codex/skills"

    if $DRY_RUN; then
        echo -e "  ${BLUE}→${NC} .codex/skills -> .claude/skills"
        return 0
    fi

    mkdir -p "$TARGET_PATH/.codex"
    if [[ -L "$symlink" ]]; then
        echo -e "  ${GREEN}✓${NC} .codex/skills (symlink exists)"
    else
        rm -f "$symlink"
        ln -s ../.claude/skills "$symlink"
        echo -e "  ${GREEN}✓${NC} .codex/skills -> .claude/skills"
    fi
}

# Install docs (create-if-missing, never overwrite)
install_docs() {
    local docs_dir="$TARGET_PATH/.claude/docs"

    if ! $DRY_RUN; then
        mkdir -p "$docs_dir"
    fi

    local doc_templates=(
        "QUICK-REFERENCE.md:templates/docs/QUICK-REFERENCE.md.template"
        "FAQ-AGENTS.md:templates/docs/FAQ-AGENTS.md.template"
        "CODEBASE-MAP.md:templates/docs/CODEBASE-MAP.md.template"
    )

    for entry in "${doc_templates[@]}"; do
        local doc_name="${entry%%:*}"
        local template_path="$TOOLKIT_DIR/${entry#*:}"
        local output="$docs_dir/$doc_name"

        if [[ ! -f "$template_path" ]]; then
            continue
        fi

        if [[ -f "$output" ]]; then
            echo -e "  ${YELLOW}⊘${NC} .claude/docs/$doc_name (exists, preserved)"
            continue
        fi

        if $DRY_RUN; then
            echo -e "  ${BLUE}→${NC} .claude/docs/$doc_name"
        else
            substitute_placeholders "$template_path" "$output"
            echo -e "  ${GREEN}✓${NC} .claude/docs/$doc_name"
        fi
    done
}

# Install WORKSPACE.md (create-if-missing, never overwrite)
install_workspace_md() {
    local template="$TOOLKIT_DIR/templates/WORKSPACE.md.template"
    local output="$TARGET_PATH/WORKSPACE.md"

    if [[ ! -f "$template" ]]; then
        return 0
    fi

    if [[ -f "$output" ]]; then
        echo -e "  ${YELLOW}⊘${NC} WORKSPACE.md (exists, preserved)"
        return 0
    fi

    if $DRY_RUN; then
        echo -e "  ${BLUE}→${NC} WORKSPACE.md"
    else
        substitute_placeholders "$template" "$output"
        echo -e "  ${GREEN}✓${NC} WORKSPACE.md"
    fi
}

# Install CLAUDE.md with marker-based merge
install_claude_md_with_markers() {
    local template="$TOOLKIT_DIR/templates/CLAUDE.md.template"
    local output="$TARGET_PATH/CLAUDE.md"

    if [[ ! -f "$template" ]]; then
        echo -e "${YELLOW}Warning: CLAUDE.md template not found${NC}"
        return 1
    fi

    # Prepare toolkit content from template with placeholders resolved
    local toolkit_content
    toolkit_content=$(cat "$template")
    for key in "${!PLACEHOLDERS[@]}"; do
        local value="${PLACEHOLDERS[$key]}"
        value=$(echo "$value" | sed 's/[&/\]/\\&/g')
        toolkit_content=$(echo "$toolkit_content" | sed "s|{{${key}}}|${value}|g")
    done

    local marker_begin="<!-- TOOLKIT:BEGIN -->"
    local marker_end="<!-- TOOLKIT:END -->"

    if $DRY_RUN; then
        if [[ ! -f "$output" ]]; then
            echo -e "  ${BLUE}→${NC} CLAUDE.md (create with markers)"
        elif grep -q "$marker_begin" "$output" 2>/dev/null; then
            echo -e "  ${BLUE}→${NC} CLAUDE.md (update marker section)"
        elif $UPDATE_MODE; then
            echo -e "  ${BLUE}→${NC} CLAUDE.md (prepend toolkit section)"
        else
            echo -e "  ${YELLOW}⊘${NC} CLAUDE.md (no markers, use --update to prepend)"
        fi
        return 0
    fi

    # Case 1: File doesn't exist - create with markers
    if [[ ! -f "$output" ]]; then
        local tmp_file
        tmp_file=$(mktemp "${output}.XXXXXX")
        echo "$toolkit_content" > "$tmp_file"
        mv -f "$tmp_file" "$output"
        echo -e "  ${GREEN}✓${NC} CLAUDE.md (created with markers)"
        return 0
    fi

    # Case 2: File exists with markers - replace between markers
    if grep -q "$marker_begin" "$output" 2>/dev/null; then
        local tmp_file
        tmp_file=$(mktemp "${output}.XXXXXX")

        # Extract content before markers, toolkit content, and content after markers
        awk -v begin="$marker_begin" -v end="$marker_end" '
            BEGIN { state="before" }
            state=="before" && index($0, begin) { state="inside"; next }
            state=="inside" && index($0, end) { state="after"; next }
            state=="before" { print }
            state=="after" { print }
        ' "$output" > "$tmp_file.parts"

        # Get before-marker content
        local before_content after_content
        before_content=$(awk -v begin="$marker_begin" '
            index($0, begin) { exit }
            { print }
        ' "$output")

        after_content=$(awk -v end="$marker_end" '
            found { print; next }
            index($0, end) { found=1 }
        ' "$output")

        {
            if [[ -n "$before_content" ]]; then
                echo "$before_content"
            fi
            echo "$toolkit_content"
            if [[ -n "$after_content" ]]; then
                echo "$after_content"
            fi
        } > "$tmp_file"

        rm -f "$tmp_file.parts"
        mv -f "$tmp_file" "$output"
        echo -e "  ${GREEN}✓${NC} CLAUDE.md (markers updated, user content preserved)"
        return 0
    fi

    # Case 3: File exists without markers
    if $UPDATE_MODE; then
        # Prepend toolkit section
        local tmp_file
        tmp_file=$(mktemp "${output}.XXXXXX")
        {
            echo "$toolkit_content"
            echo ""
            cat "$output"
        } > "$tmp_file"
        mv -f "$tmp_file" "$output"
        echo -e "  ${GREEN}✓${NC} CLAUDE.md (toolkit section prepended)"
        return 0
    fi

    echo -e "  ${YELLOW}⊘${NC} CLAUDE.md (no markers found, use --update to prepend)"
    return 0
}

# ============================================================================
# MAIN
# ============================================================================

# Handle --list mode
if $LIST_MODE; then
    list_skills
    exit 0
fi

# Validate we have a skill name or --all/--full
if [[ -z "$SKILL_NAME" ]] && ! $ALL_MODE; then
    echo -e "${RED}Error: Skill name required (or use --all / --full)${NC}"
    echo ""
    usage
    exit 1
fi

# Determine target path
if [[ -z "$TARGET_PATH" ]]; then
    if [[ -f ".claude/workspace-config" ]]; then
        TARGET_PATH="$(pwd)"
    else
        TARGET_PATH="$(pwd)"
    fi
fi
TARGET_PATH="$(realpath "$TARGET_PATH")"

# Verify profile exists
PROFILE_FILE="$TOOLKIT_DIR/profiles/${PROFILE_NAME}.yaml"
if [[ ! -f "$PROFILE_FILE" ]]; then
    echo -e "${RED}Error: Profile '$PROFILE_NAME' not found${NC}"
    echo "Available profiles:"
    ls -1 "$TOOLKIT_DIR/profiles/"*.yaml 2>/dev/null | xargs -I {} basename {} .yaml | sed 's/^/  /'
    exit 1
fi

# Build placeholder map
build_placeholder_map "$PROFILE_FILE"

# Detect repo info and populate workspace/project placeholders
_detect_repo_info

echo ""
echo "Installing skills..."
echo -e "  Profile: ${BLUE}$PROFILE_NAME${NC}"
echo -e "  Target:  ${BLUE}$TARGET_PATH${NC}"
echo ""

# Determine which skills to install
SKILLS_TO_INSTALL=()

if $ALL_MODE; then
    # Get all skills from profile
    while IFS= read -r skill; do
        [[ -n "$skill" ]] && [[ "$skill" != "README.md" ]] && SKILLS_TO_INSTALL+=("$skill")
    done < <(yaml_get_list "$PROFILE_FILE" "output" "skills")

    if [[ ${#SKILLS_TO_INSTALL[@]} -eq 0 ]]; then
        # Fallback: list all templates
        for template in "$TOOLKIT_DIR/templates/skills/"*.sh.template; do
            [[ -f "$template" ]] || continue
            skill=$(basename "$template" .sh.template)
            SKILLS_TO_INSTALL+=("$skill")
        done
    fi
else
    SKILLS_TO_INSTALL+=("$SKILL_NAME")
fi

# Install each skill
INSTALLED=0
FAILED=0

for skill in "${SKILLS_TO_INSTALL[@]}"; do
    if install_skill "$skill"; then
        ((++INSTALLED))
    else
        ((++FAILED))
    fi
done

# Install CLAUDE.md if requested (legacy --with-claude-md)
if $INSTALL_CLAUDE_MD && ! $FULL_MODE; then
    echo ""
    echo "Installing CLAUDE.md..."
    install_claude_md || ((++FAILED))
fi

# Full mode: install everything else
if $FULL_MODE; then
    echo ""
    echo "Installing toolkit files..."

    # Always overwrite (toolkit-managed)
    install_worker_role || ((++FAILED))
    install_security_checklist || ((++FAILED))
    install_toolkit_version || ((++FAILED))
    ensure_codex_symlink || ((++FAILED))

    # CLAUDE.md with marker-based merge
    echo ""
    echo "Installing CLAUDE.md..."
    install_claude_md_with_markers || ((++FAILED))

    # Create-if-missing
    echo ""
    echo "Installing docs (create-if-missing)..."
    install_docs || ((++FAILED))
    install_workspace_md || ((++FAILED))
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}Done!${NC} $INSTALLED skill(s) processed"
else
    echo -e "${YELLOW}Done with errors:${NC} $INSTALLED installed, $FAILED failed"
    exit 1
fi
