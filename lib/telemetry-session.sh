#!/usr/bin/env bash
# telemetry-session.sh
# Session ID generation and propagation for telemetry
#
# This module provides session correlation for telemetry invocations.
# Source this file to access session ID functions.
#
# Usage:
#   source "${TOOLKIT_ROOT}/lib/telemetry-session.sh"
#   SESSION_ID=$(telemetry_session_id)
#
# Environment:
#   CLAUDE_SESSION_ID - If set, used as session ID. Otherwise generated.

# ============================================================================
# SESSION ID GENERATION
# ============================================================================

# Generate or retrieve session ID
# Format: {unix_timestamp}-{pid}
# Example: 1706972625-12345
#
# If CLAUDE_SESSION_ID is already set, returns it.
# Otherwise generates a new one and exports it.
telemetry_session_id() {
    if [[ -z "${CLAUDE_SESSION_ID:-}" ]]; then
        # Generate new session ID: timestamp-pid
        CLAUDE_SESSION_ID="$(date +%s)-$$"
        export CLAUDE_SESSION_ID
    fi
    echo "$CLAUDE_SESSION_ID"
}

# Initialize session ID at shell startup
# Call this early in a session to establish the ID
telemetry_session_init() {
    telemetry_session_id > /dev/null
    echo "Session ID: $CLAUDE_SESSION_ID"
}

# Get session start timestamp from session ID
# Returns: Unix timestamp when session started
telemetry_session_timestamp() {
    local session_id="${1:-$CLAUDE_SESSION_ID}"
    if [[ -z "$session_id" ]]; then
        echo "0"
        return 1
    fi
    echo "${session_id%%-*}"
}

# Get PID from session ID
# Returns: Process ID that started the session
telemetry_session_pid() {
    local session_id="${1:-$CLAUDE_SESSION_ID}"
    if [[ -z "$session_id" ]]; then
        echo "0"
        return 1
    fi
    echo "${session_id##*-}"
}

# Check if we're in an existing session
# Returns: 0 if session exists, 1 if not
telemetry_has_session() {
    [[ -n "${CLAUDE_SESSION_ID:-}" ]]
}

# Format session ID for display
# Returns: Human-readable session info
telemetry_session_info() {
    local session_id="${1:-$(telemetry_session_id)}"
    local timestamp
    timestamp=$(telemetry_session_timestamp "$session_id")

    if [[ "$timestamp" == "0" ]]; then
        echo "No session"
        return 1
    fi

    local start_time
    start_time=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
                 date -r "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
                 echo "unknown")

    echo "Session: $session_id (started: $start_time)"
}

# ============================================================================
# WORKER INTEGRATION
# ============================================================================

# Set session ID for worker loop
# Call at worker start so all skills share the session
telemetry_worker_session() {
    if [[ -z "${CLAUDE_SESSION_ID:-}" ]]; then
        CLAUDE_SESSION_ID="worker-$(date +%s)-$$"
        export CLAUDE_SESSION_ID
    fi
    echo "$CLAUDE_SESSION_ID"
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export session ID if already set (for child processes)
if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
    export CLAUDE_SESSION_ID
fi
