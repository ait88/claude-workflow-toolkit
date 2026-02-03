# Telemetry Log Format Specification

This document defines the standard format for telemetry invocation logs in claude-workflow-toolkit.

## Overview

Telemetry uses a simple, pipe-delimited log format optimized for:
- Fast appending during skill execution
- Easy parsing with standard Unix tools
- Human readability in terminal
- Minimal overhead (no escaping for typical values)

## Invocation Log Format

### File Location

```
.claude/telemetry/invocations.log
```

### Line Format

```
{timestamp}|{session_id}|{skill}|{exit_code}|{duration_ms}
```

Each line represents one skill invocation. Fields are separated by pipe (`|`) characters.

### Field Definitions

| Field | Format | Description |
|-------|--------|-------------|
| `timestamp` | ISO 8601 (UTC) | When the invocation started |
| `session_id` | `{unix_ts}-{pid}` | Correlates invocations in same session |
| `skill` | string | Skill name without path (e.g., `check-reviews`) |
| `exit_code` | integer | 0 = success, non-zero = failure |
| `duration_ms` | integer | Execution time in milliseconds |

### Example Entries

```
2026-02-03T14:23:45Z|1706972625-12345|check-reviews|0|1423
2026-02-03T14:24:12Z|1706972625-12345|claim-issue|0|892
2026-02-03T14:25:00Z|1706972625-12345|worker|0|48123
2026-02-03T14:45:33Z|1706972625-12345|submit-pr|1|2341
2026-02-03T15:00:00Z|1706976000-23456|check-reviews|0|1102
```

In this example:
- First 4 lines are from session `1706972625-12345`
- Last line is from a new session `1706976000-23456`
- The `submit-pr` invocation failed (exit_code=1)

## Field Details

### Timestamp

- **Format:** ISO 8601 with timezone (`YYYY-MM-DDTHH:MM:SSZ`)
- **Timezone:** Always UTC (Z suffix) to avoid ambiguity
- **Precision:** Second-level (milliseconds not included in timestamp)
- **Generation:** `date -u +"%Y-%m-%dT%H:%M:%SZ"`

### Session ID

- **Format:** `{unix_timestamp}-{pid}`
- **Purpose:** Link invocations within the same agent session
- **Generation:** `${CLAUDE_SESSION_ID:-$(date +%s)-$$}`
- **Persistence:** Exported as environment variable for child processes

Session IDs enable:
- Trace reconstruction ("What skills ran in this session?")
- Session metrics ("Average skills per session")
- Debugging ("Show me everything from session X")

### Skill Name

- **Format:** Base name without path or extension
- **Examples:** `check-reviews`, `worker`, `claim-issue`
- **Derivation:** `basename "$0"` in skill script

### Exit Code

- **Type:** Integer
- **Values:**
  - `0` = Success
  - `1-255` = Various failure modes
- **Capture:** Via `trap` on EXIT in skill wrapper

### Duration (milliseconds)

- **Type:** Integer
- **Calculation:** `(end_time - start_time) * 1000`
- **Precision:** Millisecond-level when available
- **Fallback:** Second-level precision on systems without high-resolution timers

## Parsing Examples

### Count Invocations per Skill (awk)

```bash
awk -F'|' '{count[$3]++} END {for (s in count) print count[s], s}' \
    .claude/telemetry/invocations.log | sort -rn
```

### Filter by Date (grep)

```bash
# Today's invocations
grep "^$(date +%Y-%m-%d)" .claude/telemetry/invocations.log

# Last 7 days
for i in {0..6}; do
    date -d "-$i days" +%Y-%m-%d
done | xargs -I{} grep "^{}" .claude/telemetry/invocations.log
```

### Find Failed Invocations (awk)

```bash
awk -F'|' '$4 != 0 {print}' .claude/telemetry/invocations.log
```

### Calculate Average Duration per Skill (awk)

```bash
awk -F'|' '{
    count[$3]++
    total[$3] += $5
} END {
    for (s in count)
        printf "%s: %.0fms avg (%d invocations)\n", s, total[s]/count[s], count[s]
}' .claude/telemetry/invocations.log
```

### Extract Unique Sessions (cut + sort)

```bash
cut -d'|' -f2 .claude/telemetry/invocations.log | sort -u
```

### Trace a Session (grep)

```bash
SESSION="1706972625-12345"
grep "|${SESSION}|" .claude/telemetry/invocations.log
```

## Design Decisions

### Why Pipe-Delimited?

1. **Easy parsing:** `cut -d'|'`, `awk -F'|'` work out of the box
2. **Terminal-friendly:** Readable without processing
3. **No escaping:** Skill names and typical values don't contain pipes
4. **Append-optimized:** Single `echo >>` to log

### Why Not JSON Lines?

- Raw logs prioritize write speed over read convenience
- JSON aggregation comes in Phase 2 (usage.json)
- Line-based format enables `tail -f`, `grep`, standard Unix tools
- JSON parsing (jq) adds overhead to simple queries

### Why ISO 8601 Timestamps?

- Unambiguous across timezones and locales
- Lexicographically sortable (`sort` works correctly)
- Standard format recognized by most tools
- UTC avoids daylight saving time issues

### Why Milliseconds for Duration?

- Sufficient precision for skill timing
- Integer format (no floating point complexity)
- Compatible with most timing tools
- Easy aggregation (sum, average)

## Storage Considerations

### Rotation

The invocations.log file can grow indefinitely. Recommended approaches:

1. **Manual rotation:** Archive logs periodically
2. **Size-based:** Rotate when exceeding threshold
3. **Aggregation:** Process into usage.json then truncate

### Git Tracking

```gitignore
# Don't commit raw logs (noise in git history)
.claude/telemetry/invocations.log

# Do commit aggregated data (useful history)
!.claude/telemetry/usage.json
```

### Backup

Raw logs can be deleted after aggregation. The aggregated usage.json retains the important metrics.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-03 | Initial specification |

## Related Documentation

- [Telemetry Overview](./TELEMETRY.md) - High-level telemetry guide
- [JSON Tally Format](#) - Aggregated data specification (Phase 2)
