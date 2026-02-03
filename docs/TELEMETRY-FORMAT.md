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

---

# JSON Tally Format Specification (usage.json)

This section defines the aggregated telemetry format that persists metrics between sessions.

## Overview

While `invocations.log` captures raw events, `usage.json` provides:
- Pre-computed aggregations for fast reporting
- Persistent metrics across sessions
- Period-based snapshots (7d, 30d)
- Incremental update support via cursor

## File Location

```
.claude/telemetry/usage.json
```

## Schema (v1.0)

```json
{
  "version": "1.0",
  "skills": {
    "<skill-name>": {
      "invocations": 142,
      "successes": 140,
      "failures": 2,
      "total_duration_ms": 28400,
      "avg_duration_ms": 200,
      "last_invoked": "2026-02-03T23:14:00Z",
      "first_invoked": "2026-01-15T10:00:00Z",
      "sessions": 47
    }
  },
  "sessions": {
    "total": 89,
    "skill_invocations": 284,
    "avg_skills_per_session": 3.2
  },
  "periods": {
    "last_7d": {
      "invocations": 45,
      "sessions": 12,
      "updated": "2026-02-03T00:00:00Z"
    },
    "last_30d": {
      "invocations": 142,
      "sessions": 47,
      "updated": "2026-02-03T00:00:00Z"
    }
  },
  "updated": "2026-02-03T23:45:00Z",
  "log_cursor": "2026-02-03T23:45:00Z"
}
```

## Field Definitions

### Root Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Schema version for migrations |
| `skills` | object | Per-skill aggregated metrics |
| `sessions` | object | Session-level statistics |
| `periods` | object | Time-windowed snapshots |
| `updated` | ISO 8601 | When this file was last modified |
| `log_cursor` | ISO 8601 | Last processed log entry timestamp |

### Skill Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `invocations` | integer | Total times skill was called |
| `successes` | integer | Invocations with exit_code=0 |
| `failures` | integer | Invocations with exit_code≠0 |
| `total_duration_ms` | integer | Sum of all execution times |
| `avg_duration_ms` | integer | Computed average (total/invocations) |
| `last_invoked` | ISO 8601 | Most recent invocation timestamp |
| `first_invoked` | ISO 8601 | First recorded invocation |
| `sessions` | integer | Unique sessions using this skill |

### Sessions Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `total` | integer | Unique session count |
| `skill_invocations` | integer | Total invocations across all skills |
| `avg_skills_per_session` | float | Average skills used per session |

### Periods Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `invocations` | integer | Invocations in time window |
| `sessions` | integer | Unique sessions in time window |
| `updated` | ISO 8601 | When this period was last computed |

## Example usage.json

```json
{
  "version": "1.0",
  "skills": {
    "check-reviews": {
      "invocations": 47,
      "successes": 47,
      "failures": 0,
      "total_duration_ms": 66580,
      "avg_duration_ms": 1416,
      "last_invoked": "2026-02-03T14:23:45Z",
      "first_invoked": "2026-01-15T09:12:00Z",
      "sessions": 23
    },
    "worker": {
      "invocations": 35,
      "successes": 33,
      "failures": 2,
      "total_duration_ms": 1750000,
      "avg_duration_ms": 50000,
      "last_invoked": "2026-02-03T14:45:00Z",
      "first_invoked": "2026-01-16T11:30:00Z",
      "sessions": 18
    },
    "claim-issue": {
      "invocations": 28,
      "successes": 28,
      "failures": 0,
      "total_duration_ms": 25200,
      "avg_duration_ms": 900,
      "last_invoked": "2026-02-03T14:24:12Z",
      "first_invoked": "2026-01-15T09:15:00Z",
      "sessions": 28
    },
    "submit-pr": {
      "invocations": 22,
      "successes": 20,
      "failures": 2,
      "total_duration_ms": 52800,
      "avg_duration_ms": 2400,
      "last_invoked": "2026-02-03T12:30:00Z",
      "first_invoked": "2026-01-15T14:00:00Z",
      "sessions": 20
    }
  },
  "sessions": {
    "total": 47,
    "skill_invocations": 132,
    "avg_skills_per_session": 2.8
  },
  "periods": {
    "last_7d": {
      "invocations": 45,
      "sessions": 12,
      "updated": "2026-02-03T00:00:00Z"
    },
    "last_30d": {
      "invocations": 132,
      "sessions": 47,
      "updated": "2026-02-03T00:00:00Z"
    }
  },
  "updated": "2026-02-03T14:45:00Z",
  "log_cursor": "2026-02-03T14:45:00Z"
}
```

## Incremental Aggregation

The `log_cursor` field enables efficient incremental updates:

1. Read current `usage.json`
2. Process only log entries after `log_cursor`
3. Merge new data into existing aggregations
4. Update `log_cursor` to latest processed timestamp
5. Write updated `usage.json`

### Cursor Algorithm

```bash
# Pseudocode for incremental aggregation
cursor=$(jq -r '.log_cursor // ""' usage.json)

if [ -n "$cursor" ]; then
    # Process only new entries
    awk -F'|' -v cursor="$cursor" '$1 > cursor' invocations.log
else
    # Process entire log (first run)
    cat invocations.log
fi
```

## Period Recomputation

Period snapshots (`last_7d`, `last_30d`) are recomputed when:
- More than 24 hours since last update
- Explicit refresh requested

This avoids expensive full-log scans on every aggregation.

## Design Decisions

### Why JSON?

- Human-readable for debugging
- Easy manipulation with `jq`
- Native support in most languages
- Suitable for git tracking (meaningful diffs)

### Why Pre-computed Averages?

- Avoids recomputation on every read
- Enables fast dashboard rendering
- Acceptable accuracy for metrics use case

### Why Separate from Raw Logs?

- Different access patterns (append vs read/update)
- Different retention policies (logs rotate, aggregates persist)
- Different granularity (events vs summaries)

### Why Version Field?

Future schema changes can be handled gracefully:
- New fields added with defaults
- Breaking changes detected via version mismatch
- Migration scripts can transform old formats

## Schema Migrations

### From v1.0 to Future Versions

When `version` changes, the aggregation tool should:
1. Detect version mismatch
2. Apply migration transforms
3. Update version field
4. Continue with aggregation

## Git Tracking

```gitignore
# Commit aggregated metrics (useful history)
!.claude/telemetry/usage.json

# Don't commit raw logs (too noisy)
.claude/telemetry/invocations.log
```

Committing `usage.json` provides:
- Historical usage patterns
- Trend analysis via git history
- Shared team insights

## Related Documentation

- [Telemetry Overview](./TELEMETRY.md) - High-level telemetry guide
- [Invocation Log Format](#invocation-log-format) - Raw log specification
