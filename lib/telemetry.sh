#!/usr/bin/env bash
# telemetry.sh
# Core telemetry library for skill invocation logging
#
# Source this file in skills to enable automatic telemetry:
#
#   source "${TOOLKIT_ROOT:-$HOME/claude-workflow-toolkit}/lib/telemetry.sh"
#   telemetry_start "my-skill"
#   # ... skill implementation ...
#   # Exit code captured automatically via trap
#
# Zero token overhead - operates at bash layer, invisible to AI agent.

# ============================================================================
# INITIALIZATION
# ============================================================================

# Determine library location
TELEMETRY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source session module
if [[ -f "${TELEMETRY_LIB_DIR}/telemetry-session.sh" ]]; then
    # shellcheck source=./telemetry-session.sh
    source "${TELEMETRY_LIB_DIR}/telemetry-session.sh"
fi

# ============================================================================
# CONFIGURATION
# ============================================================================

# Telemetry state
_TELEMETRY_ENABLED=true
_TELEMETRY_SKILL=""
_TELEMETRY_START_TIME=0
_TELEMETRY_LOG_DIR=""

# Detect log directory based on context
_telemetry_detect_log_dir() {
    # If explicitly set, use it
    if [[ -n "${TELEMETRY_LOG_DIR:-}" ]]; then
        echo "$TELEMETRY_LOG_DIR"
        return
    fi

    # Look for workspace config
    local script_dir="${BASH_SOURCE[1]:-$PWD}"
    local workspace_config

    # Try relative to calling script
    workspace_config="$(dirname "$script_dir")/../workspace-config"
    if [[ -f "$workspace_config" ]]; then
        # shellcheck source=/dev/null
        source "$workspace_config"
        if [[ -n "${TARGET_PROJECT_PATH:-}" ]]; then
            echo "${TARGET_PROJECT_PATH}/.claude/telemetry"
            return
        fi
    fi

    # Try current directory
    if [[ -d ".claude" ]]; then
        echo ".claude/telemetry"
        return
    fi

    # Fallback to home
    echo "${HOME}/.claude/telemetry"
}

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

# Initialize telemetry for a skill invocation
# Sets up trap for exit capture, records start time
#
# Usage: telemetry_start "skill-name"
telemetry_start() {
    local skill_name="${1:-unknown}"

    # Store skill name for trap
    _TELEMETRY_SKILL="$skill_name"

    # Record start time (nanoseconds if available, else seconds)
    if date +%s%N > /dev/null 2>&1; then
        _TELEMETRY_START_TIME=$(date +%s%N)
    else
        _TELEMETRY_START_TIME=$(($(date +%s) * 1000000000))
    fi

    # Ensure session ID exists
    telemetry_session_id > /dev/null 2>&1 || true

    # Detect log directory
    _TELEMETRY_LOG_DIR="$(_telemetry_detect_log_dir)"

    # Set up exit trap (only if not already set by telemetry)
    if [[ -z "${_TELEMETRY_TRAP_SET:-}" ]]; then
        trap '_telemetry_on_exit $?' EXIT
        _TELEMETRY_TRAP_SET=1
    fi
}

# Internal: Called on skill exit via trap
_telemetry_on_exit() {
    local exit_code="${1:-0}"

    # Skip if telemetry not initialized
    [[ -z "$_TELEMETRY_SKILL" ]] && return

    # Calculate duration
    local end_time duration_ms
    if date +%s%N > /dev/null 2>&1; then
        end_time=$(date +%s%N)
    else
        end_time=$(($(date +%s) * 1000000000))
    fi
    duration_ms=$(( (end_time - _TELEMETRY_START_TIME) / 1000000 ))

    # Log the invocation
    telemetry_log "$_TELEMETRY_SKILL" "$exit_code" "$duration_ms"
}

# Log a skill invocation
# Can be called manually for custom timing scenarios
#
# Usage: telemetry_log "skill-name" exit_code duration_ms
telemetry_log() {
    local skill_name="${1:-unknown}"
    local exit_code="${2:-0}"
    local duration_ms="${3:-0}"

    # Skip if disabled
    [[ "$_TELEMETRY_ENABLED" != "true" ]] && return 0

    # Get session ID
    local session_id
    session_id=$(telemetry_session_id 2>/dev/null || echo "unknown")

    # Get timestamp (ISO 8601 UTC)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Ensure log directory exists
    local log_dir="${_TELEMETRY_LOG_DIR:-$(_telemetry_detect_log_dir)}"
    mkdir -p "$log_dir" 2>/dev/null || return 0

    local log_file="${log_dir}/invocations.log"

    # Write log entry (fail silently - don't break skills)
    # Format: {timestamp}|{session_id}|{skill}|{exit_code}|{duration_ms}
    echo "${timestamp}|${session_id}|${skill_name}|${exit_code}|${duration_ms}" >> "$log_file" 2>/dev/null || true
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Disable telemetry for current invocation
telemetry_disable() {
    _TELEMETRY_ENABLED=false
}

# Enable telemetry (default state)
telemetry_enable() {
    _TELEMETRY_ENABLED=true
}

# Check if telemetry is enabled
telemetry_is_enabled() {
    [[ "$_TELEMETRY_ENABLED" == "true" ]]
}

# Get the log file path
telemetry_log_path() {
    local log_dir="${_TELEMETRY_LOG_DIR:-$(_telemetry_detect_log_dir)}"
    echo "${log_dir}/invocations.log"
}

# ============================================================================
# SESSION ID (re-exported for convenience)
# ============================================================================

# If session module wasn't loaded, provide fallback
if ! type telemetry_session_id &>/dev/null; then
    telemetry_session_id() {
        if [[ -z "${CLAUDE_SESSION_ID:-}" ]]; then
            CLAUDE_SESSION_ID="$(date +%s)-$$"
            export CLAUDE_SESSION_ID
        fi
        echo "$CLAUDE_SESSION_ID"
    }
fi
