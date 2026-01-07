# Ralph Wiggum Integration

Optional module for iterative task execution with multi-model orchestration.

## What is Ralph?

Ralph Wiggum is a loop-based execution pattern that runs tasks iteratively until `VERIFIED_DONE` state, with automatic model routing between Claude, Codex, Gemini, and MiniMax.

## Available Skills

### `/ralph-task <issue> <description> [max-iterations]`

Execute a complex task using Ralph's iterative loop pattern.

**When to use:**
- Multi-step features requiring exploration
- Uncertain scope or ambiguous requirements
- Tasks benefiting from multi-model collaboration
- Long-running implementations needing progress visibility

**Example:**
```bash
/ralph-task 42 "Implement OAuth2 authentication with JWT tokens"
```

### `/ralph-status <issue>`

Check progress, iteration count, and model utilization for a running or completed Ralph task.

**Example:**
```bash
/ralph-status 42
watch -n 5 /ralph-status 42  # Monitor continuously
```

## When to Use Ralph vs Standard Workflow

| Use Ralph | Use Standard Workflow |
|-----------|----------------------|
| Complex multi-step features | Simple bug fixes |
| Unclear implementation path | Well-defined scope |
| Exploration + implementation | Single file changes |
| Long-running tasks | Quick hotfixes |

## Progress Tracking

Ralph creates `.ralph/progress-{issue}.json` tracking:
- Current iteration vs max
- Model utilization (Claude/Codex/Gemini/MiniMax)
- Progress percentage
- Status history

**Checkpoint format:**
```
[RALPH:42] Iteration 3/20 | Model: codex | Progress: 45% | Status: Implementing auth handler
```

## Integrated Workflow

```bash
# 1. Claim issue
/claim-issue 42

# 2. Execute with Ralph
/ralph-task 42 "Implement feature X"

# 3. Monitor progress
/ralph-status 42

# 4. Validate and submit
/check-workflow
/submit-pr
```

## Prerequisites

Ralph Wiggum plugin must be installed separately:
```bash
git clone https://github.com/ait88/ralph-wiggum
cd ralph-wiggum && ./install.sh
```

Verify: `ralph-loop --version`

## Token Optimization

Ralph reduces token costs through:
- **Multi-model routing**: Use cheaper models (MiniMax 8% cost) for reviews
- **Iterative refinement**: Catch errors early, avoid full restarts
- **Targeted context**: Each iteration receives only relevant context

Expected savings: **30-50% reduction** for complex tasks

## Configuration

Controlled via profile settings:

```yaml
ralph:
  ralph_integration: true
  ralph_default_iterations: 20
  ralph_progress_tracking: true
```

Ralph is **disabled by default** in `profiles/default.yaml`.
Enable by using `profiles/with-ralph.yaml`.

## Learn More

- Full documentation: `docs/RALPH-INTEGRATION.md`
- Skill reference: `.claude/skills/ralph/README.md`
- Ralph Wiggum project: https://github.com/ait88/ralph-wiggum
