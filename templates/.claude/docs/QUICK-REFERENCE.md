# Quick Reference - Agent Workflow

## IMPORTANT: PR-Based Workflow Required

**NEVER push directly to main.** This repository uses a PR-based workflow.

## Standard Workflow

```
1. /check-reviews     ← Always start here (address feedback first)
2. /claim-issue <n>   ← Claim issue, creates feature branch
3. [implement]        ← Make your changes
4. /check-workflow    ← Validate state before PR
5. /submit-pr         ← Create PR for review
```

## Session Startup

When starting a new session:

```bash
# Option 1: Read this file first
claude -c "read CLAUDE.md then /check-reviews"

# Option 2: Use the worker (autonomous mode)
/worker --once
```

## Skill Reference

### Core Workflow Skills

| Skill | When to Use |
|-------|-------------|
| `/check-reviews` | **FIRST** - Check for PRs needing attention |
| `/claim-issue <n>` | Claim an issue and create feature branch |
| `/check-workflow` | Validate current branch/issue/PR state |
| `/submit-pr` | Submit PR when implementation complete |
| `/worker` | Autonomous loop (claim → implement → submit) |

### Utility Skills

| Skill | Purpose |
|-------|---------|
| `/sync-skills` | Update skills from toolkit templates |
| `/address-review` | Checkout PR branch to address feedback |

### Telemetry Skills

| Skill | Purpose |
|-------|---------|
| `/telemetry-init` | Initialize telemetry for a project |
| `/telemetry-report` | View skill usage statistics |
| `/telemetry-aggregate` | Aggregate logs into usage.json |

## Finding Work

```bash
# List issues ready for agents
gh issue list --label agent-ready

# Check what's in progress
gh issue list --label in-progress

# Check PRs needing review
gh pr list --state open
```

## Branch Naming

Branches must follow: `<issue-number>-<slug>`

Examples:
- `25-agent-feedback-from-session-initialisation`
- `42-fix-login-button`

## Label Flow

```
agent-ready → in-progress → needs-review → [merged]
                  ↓
               blocked (if stuck)
```

## Commit Messages

Format: `<type>(<scope>): <description> (#<issue>)`

Examples:
- `feat(worker): add retry logic (#25)`
- `fix(claim-issue): handle missing labels (#18)`
- `docs(readme): update workflow section (#12)`

## Troubleshooting

### "Not on an issue branch"
You're on main. Use `/claim-issue <n>` to create a feature branch.

### "PR already exists"
Check with `gh pr list --head <branch>` and either update it or close and recreate.

### Labels out of sync
Run `/check-workflow` for suggested fix commands.

## More Information

- `CLAUDE.md` - Root-level workflow instructions
- `.claude/docs/FAQ-AGENTS.md` - Common questions
- `.claude/docs/CODEBASE-MAP.md` - Project structure
