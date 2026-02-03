# Skill Telemetry

Track skill usage patterns to understand workflow efficiency and identify optimization opportunities.

## Why Telemetry?

- **Track usage patterns** - See which skills are used most, when, and for how long
- **Identify unused code** - Find skills that might be candidates for removal
- **Measure workflow efficiency** - Understand the claim → implement → submit cycle
- **Debug failures** - Correlate skill failures with specific sessions
- **Zero token overhead** - Operates at bash layer, invisible to AI agent

## Quick Start

### 1. Initialize Telemetry

For an existing project:

```bash
# From within the project
/telemetry-init

# Or from toolkit, apply to external project
./scripts/telemetry-init.sh --target ~/myproject
```

### 2. Use Skills Normally

All instrumented skills automatically log invocations:

```bash
/check-reviews        # Logged automatically
/claim-issue 42       # Logged automatically
/submit-pr            # Logged automatically
```

### 3. View Reports

```bash
# Usage report with period comparison
/telemetry-report

# Aggregate logs into usage.json
/telemetry-aggregate

# View 30-day report
/telemetry-report --period 30d
```

## Understanding the Output

### Telemetry Report

```
========================================
Skill Usage Report
========================================
Period: Last 7 days vs Previous 7 days

Rank  Skill              This  Prev  Change  Trend
----  -----              ----  ----  ------  -----
1     check-reviews        47    38    +24%    ↑
2     worker               35    42    -17%    ↓
3     claim-issue          28    28     0%     →
4     submit-pr            22    15    +47%    ↑
5     sync-skills          10     2   +400%    ↑↑

Sessions: 23 (was 19, +21%)
Avg skills/session: 6.2 (was 5.4)

========================================
Insights
========================================

New this period: telemetry-report
Inactive this period: address-review
Trending up: submit-pr, sync-skills
```

### Trend Indicators

| Indicator | Meaning |
|-----------|---------|
| ↑↑ | Increased >50% |
| ↑ | Increased 10-50% |
| → | Stable (-10% to +10%) |
| ↓ | Decreased 10-50% |
| ↓↓ | Decreased >50% |
| ✨ | New this period |

## Instrumenting Custom Skills

Add telemetry to your own skills:

```bash
#!/usr/bin/env bash
# my-custom-skill.sh

# Standard setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize telemetry (fails silently if not available)
if [[ -f "${SCRIPT_DIR}/../../lib/telemetry.sh" ]]; then
    source "${SCRIPT_DIR}/../../lib/telemetry.sh"
    telemetry_start "my-custom-skill"
fi

# ... rest of your skill ...

# Exit code captured automatically via trap
```

### Key Points

- Source `lib/telemetry.sh` early in your script
- Call `telemetry_start "skill-name"` after sourcing
- Exit code and duration captured automatically via EXIT trap
- Silent failure if telemetry not available (graceful degradation)

## Data Files

### Invocation Log

Raw log of all skill invocations:

```
.claude/telemetry/invocations.log
```

Format (pipe-delimited):
```
{timestamp}|{session_id}|{skill}|{exit_code}|{duration_ms}
```

Example:
```
2026-02-03T14:23:45Z|1706972625-12345|check-reviews|0|1423
2026-02-03T14:24:12Z|1706972625-12345|claim-issue|0|892
2026-02-03T14:45:33Z|1706972625-12345|submit-pr|1|2341
```

### Aggregated Data

Pre-computed statistics for fast reporting:

```
.claude/telemetry/usage.json
```

Updated by `/telemetry-aggregate` or automatically after reports.

## Configuration

### Git Tracking

Recommended `.gitignore` entries (created by `/telemetry-init`):

```gitignore
# Don't commit raw logs (noise in git history)
.claude/telemetry/invocations.log

# Do commit aggregated data (useful history)
!.claude/telemetry/usage.json
```

### Session IDs

Sessions are tracked automatically via `CLAUDE_SESSION_ID` environment variable:

- Format: `{unix_timestamp}-{pid}`
- Worker sessions use: `worker-{timestamp}-{pid}`
- Exported to child processes

## Privacy & What's Logged

### Logged

- Skill name (e.g., "claim-issue")
- Timestamp (UTC)
- Exit code (0 = success)
- Duration in milliseconds
- Session ID (for correlation)

### NOT Logged

- Skill arguments or parameters
- File contents
- Issue numbers or PR details
- User identity
- API responses
- Any sensitive data

## Troubleshooting

### "No telemetry data found"

Telemetry is not yet enabled. Run:

```bash
/telemetry-init
```

### Empty report

Log file exists but has no entries. Skills have not been invoked since telemetry was enabled.

### Skills not logging

Ensure the skill sources telemetry.sh:

```bash
source "${SCRIPT_DIR}/../../lib/telemetry.sh"
telemetry_start "skill-name"
```

### Stale aggregation

Run aggregation to update usage.json:

```bash
/telemetry-aggregate
```

## Related Documentation

- [Telemetry Format Specification](./TELEMETRY-FORMAT.md) - Technical details on log formats
- [Skill Templates](./CONTRIBUTING.md) - How to create new skills

## Skills Reference

| Skill | Description |
|-------|-------------|
| `/telemetry-init` | Initialize telemetry for a project |
| `/telemetry-report` | Generate usage reports |
| `/telemetry-aggregate` | Aggregate logs into usage.json |
