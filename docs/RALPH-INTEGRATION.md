# Ralph Wiggum Integration Guide

Comprehensive documentation for integrating Ralph Wiggum's iterative loop pattern with the Claude Workflow Toolkit.

## Table of Contents
- [What is Ralph Wiggum?](#what-is-ralph-wiggum)
- [Why Integrate with Workflow Toolkit?](#why-integrate-with-workflow-toolkit)
- [When to Use Ralph](#when-to-use-ralph)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Observability Layer](#observability-layer)
- [Progress Tracking](#progress-tracking)
- [Workflow Examples](#workflow-examples)
- [Troubleshooting](#troubleshooting)
- [Token Optimization](#token-optimization)
- [Future Possibilities](#future-possibilities)

## What is Ralph Wiggum?

Ralph Wiggum is a multi-model orchestration pattern for iterative task execution in Claude Code environments. Named after the Simpsons character who famously says "I'm helping!", Ralph provides:

- **Loop-based execution**: Tasks run iteratively until `VERIFIED_DONE` state
- **Multi-model routing**: Adaptive delegation to Claude, Codex, Gemini, MiniMax
- **Emergent properties**: Self-correction, quality gates, adaptive planning
- **Observability**: Built-in progress tracking and checkpoint outputs

### Core Philosophy

Traditional workflow: Linear execution (claim → implement → submit)
Ralph workflow: Iterative refinement (claim → loop until done → submit)

Ralph is ideal for complex, uncertain tasks where:
- The implementation path is not immediately clear
- Multiple approaches should be explored
- Quality gates need continuous validation
- Model diversity provides strategic value

## Why Integrate with Workflow Toolkit?

The Claude Workflow Toolkit optimizes GitHub workflows through atomic skills (`/claim-issue`, `/submit-pr`). Ralph integration adds a **middle layer** for complex task execution:

```
Workflow Toolkit (GitHub ops) → Ralph (iterative execution) → Task completion
```

Benefits of integration:
1. **Unified workflow**: Single command set for simple and complex tasks
2. **Progress visibility**: Ralph's observability surfaces iteration count, model usage
3. **Atomic operations**: Workflow skills ensure clean state before/after Ralph execution
4. **Token optimization**: Multi-model routing + workflow efficiency = maximum savings

## When to Use Ralph

### Decision Matrix

| Factor | Use Standard Workflow | Use Ralph Integration |
|--------|----------------------|----------------------|
| **Task complexity** | Single file, clear path | Multi-file, exploration needed |
| **Uncertainty** | Well-defined requirements | Ambiguous scope, discovery needed |
| **Time sensitivity** | Immediate completion | Can afford iteration overhead |
| **Model diversity** | Claude alone sufficient | Codex/Gemini/MiniMax add value |
| **Progress tracking** | Not needed | Valuable for monitoring |

### ✅ Use Ralph for:
- Implementing new features with unclear architecture
- Refactoring complex systems
- Debugging issues requiring investigation
- Tasks requiring research + implementation
- Multi-step workflows with dependencies
- Quality-critical implementations needing multiple review passes

### ❌ Don't use Ralph for:
- Simple bug fixes (typos, one-line changes)
- Well-scoped features with clear implementation
- Pure documentation tasks
- Operations already covered by workflow skills (claim, submit)
- Time-critical hotfixes

### Examples

**Good Ralph candidates:**
```bash
/ralph-task 42 "Implement user authentication with OAuth2 and JWT"
/ralph-task 58 "Refactor database layer to support multiple backends"
/ralph-task 91 "Investigate and fix memory leak in background worker"
```

**Poor Ralph candidates (use standard workflow):**
```bash
/claim-issue 23   # Fix typo in README
/claim-issue 45   # Add console.log for debugging
/claim-issue 67   # Update version number in package.json
```

## Installation

### Prerequisites

- Claude Code agent environment
- GitHub CLI (`gh`) authenticated
- `jq` for JSON parsing
- Git version control

### Install Ralph Wiggum Plugin

```bash
# Clone Ralph Wiggum repository
git clone https://github.com/ait88/ralph-wiggum
cd ralph-wiggum

# Run installation script
./install.sh

# Verify installation
ralph-loop --version
# Expected: ralph-loop v1.0.0 or higher
```

### Apply Workflow Toolkit with Ralph Profile

```bash
# Clone workflow toolkit
git clone https://github.com/ait88/claude-workflow-toolkit

# Navigate to your project
cd /path/to/your/project

# Ask Claude Code agent to apply toolkit with Ralph profile
# Agent will read profiles/with-ralph.yaml and generate skills
```

### Verify Integration

Check that Ralph skills were generated:

```bash
ls -la .claude/skills/
# Should see: ralph-task, ralph-status

# Make scripts executable
chmod +x .claude/skills/ralph-*

# Test status command (should show "no tasks")
.claude/skills/ralph-status 999
```

## Configuration

### Profile Settings

Ralph integration is controlled in `profiles/with-ralph.yaml`:

```yaml
project:
  name: "{{PROJECT_NAME}}"
  repo_owner: "{{REPO_OWNER}}"
  default_branch: "main"

workflow:
  skills_dir: ".claude/skills"
  docs_dir: "docs"

ralph:
  ralph_integration: true
  ralph_default_iterations: 20
  ralph_progress_tracking: true
  ralph_progress_dir: ".ralph"

output:
  skills:
    - claim-issue
    - check-workflow
    - submit-pr
    - ralph/ralph-task
    - ralph/ralph-status
    - README.md
```

### Disabling Ralph (Opt-Out)

To use workflow toolkit WITHOUT Ralph:

1. Use `profiles/default.yaml` instead of `profiles/with-ralph.yaml`
2. Or set `ralph_integration: false` in your custom profile
3. Ralph skills won't be generated

### Customizing Iteration Limits

Edit `ralph_default_iterations` in profile:

```yaml
ralph:
  ralph_default_iterations: 15  # Lower for faster tasks
  # Or: 30 for complex refactorings
```

Override per-task:
```bash
/ralph-task 42 "Description" 25
```

## Usage

### Basic Workflow

```bash
# 1. Claim issue atomically
/claim-issue 42

# 2. Execute with Ralph
/ralph-task 42 "Implement user authentication with OAuth2"

# 3. Monitor progress (in another terminal)
watch -n 5 /ralph-status 42

# 4. After completion, validate workflow
/check-workflow

# 5. Submit PR
/submit-pr
```

### Detailed Command Reference

#### `/ralph-task <issue> <description> [max-iterations]`

Initiates iterative task execution.

**Parameters:**
- `issue`: GitHub issue number (numeric)
- `description`: Task description (quoted if contains spaces)
- `max-iterations`: Optional, overrides default (1-100)

**Examples:**
```bash
# Use default max iterations (20)
/ralph-task 42 "Implement OAuth2 authentication"

# Custom iteration limit
/ralph-task 42 "Complex refactoring" 30

# Single-word description (no quotes needed)
/ralph-task 42 refactor-auth
```

**What happens:**
1. Validates issue number format
2. Creates `.ralph/` directory if missing
3. Initializes progress JSON: `.ralph/progress-42.json`
4. Enhances task prompt with observability requirements
5. Displays enhanced prompt preview
6. Waits for confirmation (press Enter)
7. Hands off to `ralph-loop` for execution
8. Displays completion status and next steps

#### `/ralph-status <issue>`

Displays current progress and model utilization.

**Parameters:**
- `issue`: GitHub issue number

**Examples:**
```bash
# One-time check
/ralph-status 42

# Continuous monitoring (refreshes every 5 seconds)
watch -n 5 /ralph-status 42

# List all Ralph tasks
ls .ralph/progress-*.json
```

**Output includes:**
- Task description and status
- Start/completion timestamps
- Iteration progress (N/max)
- Progress bar visualization
- Model utilization breakdown
- Recent progress entries (last 5)
- Error messages if failed
- Suggested next actions

### Progress States

Ralph tasks transition through states:

1. **running**: Task executing, iterations in progress
2. **completed**: Task finished successfully
3. **blocked**: Task stuck, requires manual intervention
4. **failed**: Task failed due to error (e.g., ralph-loop not installed)

## Observability Layer

The integration adds observability through two mechanisms:

### 1. Checkpoint Outputs

Ralph tasks must output checkpoints in this format:

```
[RALPH:{issue}] Iteration {N}/{max} | Model: {model} | Progress: {pct}% | Status: {brief}
```

**Examples:**
```
[RALPH:42] Iteration 1/20 | Model: claude | Progress: 10% | Status: Exploring codebase
[RALPH:42] Iteration 3/20 | Model: codex | Progress: 35% | Status: Implementing AuthHandler
[RALPH:42] Iteration 5/20 | Model: gemini | Progress: 60% | Status: Writing integration tests
[RALPH:42] Iteration 7/20 | Model: minimax | Progress: 85% | Status: Reviewing code quality
[RALPH:42] Iteration 8/20 | Model: claude | Progress: 100% | Status: Completed
```

These checkpoints:
- Allow real-time monitoring via `grep` or log tailing
- Provide human-readable progress updates
- Surface which model is handling each iteration
- Enable debugging when tasks stall

### 2. Progress JSON Files

Each Ralph task creates `.ralph/progress-{issue}.json`:

```json
{
  "issue": 42,
  "task": "Implement user authentication with OAuth2",
  "max_iterations": 20,
  "start_time": "2025-01-07T10:30:00Z",
  "completion_time": "2025-01-07T11:15:00Z",
  "status": "completed",
  "current_iteration": 8,
  "models_used": {
    "claude": 3,
    "codex": 2,
    "gemini": 2,
    "minimax": 1
  },
  "progress_entries": [
    {
      "iteration": 1,
      "timestamp": "2025-01-07T10:30:15Z",
      "model": "claude",
      "progress_pct": 10,
      "status": "Exploring codebase structure"
    },
    {
      "iteration": 3,
      "timestamp": "2025-01-07T10:35:42Z",
      "model": "codex",
      "progress_pct": 35,
      "status": "Implementing AuthHandler class"
    }
  ],
  "error": null
}
```

This JSON enables:
- Programmatic progress monitoring
- Post-task analysis of model utilization
- Debugging failed/stalled tasks
- Historical tracking of task metrics

## Progress Tracking

### Schema Definition

```typescript
interface RalphProgress {
  issue: number;                    // GitHub issue number
  task: string;                     // Task description
  max_iterations: number;           // Maximum allowed iterations
  start_time: string;               // ISO 8601 timestamp
  completion_time?: string;         // ISO 8601 timestamp (when done)
  status: "running" | "completed" | "blocked" | "failed";
  current_iteration: number;        // Last completed iteration
  models_used: {
    claude: number;                 // Count of Claude iterations
    codex: number;                  // Count of Codex iterations
    gemini: number;                 // Count of Gemini iterations
    minimax: number;                // Count of MiniMax iterations
  };
  progress_entries: Array<{
    iteration: number;
    timestamp: string;
    model: string;
    progress_pct: number;
    status: string;
  }>;
  error?: string;                   // Error message if failed/blocked
}
```

### Updating Progress

The enhanced prompt instructs Ralph to update progress after each iteration:

```javascript
// Pseudo-code for what Ralph should do
const updateProgress = (iteration, model, progressPct, status) => {
  const progress = readJSON('.ralph/progress-{issue}.json');

  progress.current_iteration = iteration;
  progress.models_used[model] += 1;
  progress.progress_entries.push({
    iteration,
    timestamp: new Date().toISOString(),
    model,
    progress_pct: progressPct,
    status
  });

  writeJSON('.ralph/progress-{issue}.json', progress);

  console.log(`[RALPH:${issue}] Iteration ${iteration}/${maxIter} | Model: ${model} | Progress: ${progressPct}% | Status: ${status}`);
};
```

### Manual Progress Inspection

```bash
# Pretty-print full progress file
cat .ralph/progress-42.json | jq .

# Extract specific fields
jq '.status' .ralph/progress-42.json
jq '.models_used' .ralph/progress-42.json
jq '.progress_entries[-5:]' .ralph/progress-42.json  # Last 5 entries

# Monitor for changes (live updates)
watch -n 2 'jq ".current_iteration" .ralph/progress-42.json'
```

## Workflow Examples

### Example 1: Feature Implementation

**Scenario:** Implement user authentication system

```bash
# Claim issue
/claim-issue 42
# Output: Created branch 42-implement-oauth2-auth

# Execute with Ralph
/ralph-task 42 "Implement OAuth2 authentication with JWT tokens"
# Ralph enhances prompt and hands off to ralph-loop
# Agent explores codebase, implements handlers, writes tests
# Checkpoint: [RALPH:42] Iteration 1/20 | Model: claude | Progress: 10% | Status: Exploring auth patterns
# Checkpoint: [RALPH:42] Iteration 3/20 | Model: codex | Progress: 40% | Status: Implementing AuthHandler
# Checkpoint: [RALPH:42] Iteration 8/20 | Model: claude | Progress: 100% | Status: Completed

# Check final status
/ralph-status 42
# Output: Status: completed | Iterations: 8/20 | Models: Claude 40%, Codex 25%, Gemini 25%, MiniMax 10%

# Validate workflow
/check-workflow
# Output: ✓ Branch matches issue | ✓ Labels correct | ✓ Ready to submit

# Submit PR
/submit-pr
# Output: PR #45 created successfully
```

### Example 2: Bug Investigation and Fix

**Scenario:** Memory leak in background worker

```bash
/claim-issue 58

# Use Ralph for investigation + fix
/ralph-task 58 "Investigate and fix memory leak in background worker process"

# Monitor in real-time (separate terminal)
watch -n 5 /ralph-status 58

# Checkpoints show investigation flow:
# [RALPH:58] Iteration 1/20 | Model: claude | Progress: 5% | Status: Profiling memory usage
# [RALPH:58] Iteration 2/20 | Model: gemini | Progress: 15% | Status: Researching common leak patterns
# [RALPH:58] Iteration 4/20 | Model: claude | Progress: 45% | Status: Found leak in connection pool
# [RALPH:58] Iteration 6/20 | Model: codex | Progress: 75% | Status: Implementing connection cleanup
# [RALPH:58] Iteration 9/20 | Model: minimax | Progress: 95% | Status: Reviewing fix
# [RALPH:58] Iteration 10/20 | Model: claude | Progress: 100% | Status: Verified with load test

/check-workflow
/submit-pr "Fix memory leak in worker connection pool"
```

### Example 3: Complex Refactoring

**Scenario:** Refactor database layer for multi-backend support

```bash
/claim-issue 91

# Use higher iteration limit for complex refactor
/ralph-task 91 "Refactor database layer to support PostgreSQL, MySQL, SQLite" 30

# Progress tracking shows multi-model collaboration:
# [RALPH:91] Iteration 1/30 | Model: claude | Progress: 5% | Status: Analyzing current DB layer
# [RALPH:91] Iteration 2/30 | Model: gemini | Progress: 10% | Status: Researching adapter patterns
# [RALPH:91] Iteration 5/30 | Model: codex | Progress: 25% | Status: Implementing base adapter
# [RALPH:91] Iteration 8/30 | Model: codex | Progress: 40% | Status: Adding PostgreSQL adapter
# [RALPH:91] Iteration 12/30 | Model: codex | Progress: 60% | Status: Adding MySQL adapter
# [RALPH:91] Iteration 15/30 | Model: gemini | Progress: 75% | Status: Writing migration guide
# [RALPH:91] Iteration 20/30 | Model: minimax | Progress: 90% | Status: Code review
# [RALPH:91] Iteration 22/30 | Model: claude | Progress: 100% | Status: All tests passing

/ralph-status 91
# Models used: Claude 6, Codex 10, Gemini 4, MiniMax 2
# Total iterations: 22/30 (73% efficiency)

/submit-pr
```

### Example 4: Failed Task Recovery

**Scenario:** Task fails due to missing dependency

```bash
/ralph-task 77 "Implement GraphQL API"

# Task fails early
# [RALPH:77] Iteration 1/20 | Model: claude | Progress: 5% | Status: Error loading schema

/ralph-status 77
# Status: failed
# Error: graphql package not found

# Fix the issue manually
npm install graphql

# Retry task
/ralph-task 77 "Implement GraphQL API (retry after installing graphql)"

# Now succeeds
# [RALPH:77] Iteration 2/20 | Model: claude | Progress: 100% | Status: Completed

/submit-pr
```

## Troubleshooting

### Common Issues

#### 1. "ralph-loop: command not found"

**Cause:** Ralph Wiggum plugin not installed

**Solution:**
```bash
git clone https://github.com/ait88/ralph-wiggum
cd ralph-wiggum
./install.sh
ralph-loop --version  # Verify
```

#### 2. Task stuck in "running" state

**Cause:** `ralph-loop` process hung or killed

**Diagnosis:**
```bash
ps aux | grep ralph-loop
/ralph-status <issue>  # Check last iteration
```

**Solution:**
```bash
# Kill hung process
killall ralph-loop

# Check progress file for last state
cat .ralph/progress-<issue>.json | jq '.progress_entries[-1]'

# Resume or restart task
/ralph-task <issue> "Resume: <description>"
```

#### 3. High iteration count without progress

**Cause:** Task spinning on blocker, unclear requirements, or infinite loop

**Diagnosis:**
```bash
/ralph-status <issue>
# Look for: same status message repeated
# Example: Iteration 15/20 with "Exploring auth patterns" → stuck

cat .ralph/progress-<issue>.json | jq '.progress_entries[-10:] | .[].status'
```

**Solution:**
1. Review recent progress entries for patterns
2. Check if task needs clearer requirements
3. Consider manual intervention or task breakdown
4. Kill and restart with refined description

#### 4. Progress file not updating

**Cause:** Ralph loop not following checkpoint protocol

**Diagnosis:**
```bash
# Check file modification time
ls -lh .ralph/progress-<issue>.json

# Monitor for changes
watch -n 2 'stat .ralph/progress-<issue>.json'
```

**Solution:**
1. Verify `ralph-loop` is running
2. Check if enhanced prompt was properly passed
3. Review ralph-loop logs for errors
4. Restart task with explicit observability reminder

#### 5. Permission denied on skills

**Cause:** Template files not executable after generation

**Solution:**
```bash
chmod +x .claude/skills/ralph-*
chmod +x .claude/skills/*
```

### Debugging Tips

#### Enable verbose logging

```bash
# Run ralph-task with debugging
bash -x .claude/skills/ralph-task 42 "Description"
```

#### Monitor progress in real-time

```bash
# Terminal 1: Run task
/ralph-task 42 "Description"

# Terminal 2: Watch status
watch -n 2 /ralph-status 42

# Terminal 3: Tail progress file
watch -n 1 'cat .ralph/progress-42.json | jq .'
```

#### Inspect checkpoint outputs

```bash
# If checkpoints go to logs
grep "RALPH:42" /path/to/logs

# If checkpoints go to stdout (captured)
/ralph-task 42 "Description" 2>&1 | tee ralph-42.log
grep "RALPH:42" ralph-42.log
```

## Token Optimization

Ralph integration provides token savings through multiple mechanisms:

### 1. Multi-Model Routing

Different models have different costs:

| Model | Relative Cost | Best For |
|-------|---------------|----------|
| Claude Opus | 100% | Complex reasoning, planning |
| Codex | ~50% | Code generation, refactoring |
| Gemini | ~30% | Research, documentation |
| MiniMax | ~8% | Code review, validation |

Ralph automatically routes tasks to appropriate models:
- Exploration/planning → Claude
- Implementation → Codex
- Research/docs → Gemini
- Review/validation → MiniMax

**Example savings:**
- 20-iteration task, all Claude: 20 × 100% = 2000 cost units
- Ralph multi-model (40% Claude, 25% Codex, 25% Gemini, 10% MiniMax):
  - 8 × 100% = 800
  - 5 × 50% = 250
  - 5 × 30% = 150
  - 2 × 8% = 16
  - **Total: 1216 cost units (39% savings)**

### 2. Workflow Skill Efficiency

Atomic GitHub operations reduce API overhead:

- Standard approach: 9-12 API calls per issue (claim, check, submit)
- Workflow skills: 3 API calls (70-75% reduction)
- Ralph + workflow: Same 3 API calls, but with better implementation quality

**No additional API cost** for using Ralph vs standard workflow.

### 3. Iteration Efficiency

Ralph's loop pattern prevents wasted work:

- **Self-correction**: Earlier iterations can catch mistakes before completion
- **Quality gates**: Continuous validation prevents shipping broken code
- **Adaptive routing**: Complex tasks get Claude, simple tasks get cheaper models

**Example:** Without Ralph, failed implementation → start over (2× cost)
With Ralph: Iteration 3 catches issue → corrects → completes (1.3× cost, 35% savings)

### Combined Impact

For a typical complex feature:

| Metric | Without Ralph | With Ralph | Savings |
|--------|---------------|------------|---------|
| GitHub API calls | 12 | 3 | 75% |
| Implementation attempts | 1-2 | 1 (iterative) | 50% |
| Token cost (multi-model) | 100% | 60% | 40% |
| **Total efficiency gain** | Baseline | **~60% savings** | **60%** |

### Optimization Tips

1. **Use appropriate iteration limits**
   - Simple tasks: 10-15 iterations
   - Complex tasks: 20-30 iterations
   - Refactorings: 30+ iterations

2. **Monitor model utilization**
   ```bash
   /ralph-status <issue> | grep "Model Utilization"
   ```
   - High Claude % → May benefit from more Codex routing
   - High iteration count → Consider breaking into subtasks

3. **Leverage checkpoints**
   - Review progress_entries to identify bottlenecks
   - Restart tasks from checkpoints when possible

## Future Possibilities

Ralph integration enables experimental capabilities:

### 1. Emergent Properties

Multi-model collaboration can produce emergent behaviors:
- **Self-review**: Codex implements → MiniMax reviews → Claude refines
- **Research-driven development**: Gemini finds patterns → Codex applies
- **Quality convergence**: Multiple models validate each other

### 2. Adaptive Routing

Future enhancements could include:
- **Context-aware model selection**: Complexity analysis → route to best model
- **Cost-aware optimization**: Budget limits → prefer cheaper models
- **Performance tracking**: Historical success rates → refine routing logic

### 3. Checkpoint Resumption

Currently experimental, future work:
- Resume tasks from specific iterations
- Replay progress with different models
- A/B test model routing strategies

### 4. Multi-Agent Orchestration

Ralph as foundation for agent orchestration:
- **Parallel sub-tasks**: Multiple Ralph instances → merge results
- **Hierarchical planning**: Claude plans → Ralph sub-agents execute
- **Consensus validation**: Multiple models vote on implementation approach

### 5. Metrics and Analytics

Enhanced observability:
- Track iteration efficiency across projects
- Identify optimal model routing patterns
- Predict task completion time based on historical data
- Cost optimization recommendations

---

## Quick Reference

### Command Cheat Sheet

```bash
# Start Ralph task
/ralph-task <issue> "<description>" [max-iterations]

# Check progress
/ralph-status <issue>

# Monitor continuously
watch -n 5 /ralph-status <issue>

# List all Ralph tasks
ls .ralph/progress-*.json

# Inspect progress file
cat .ralph/progress-<issue>.json | jq .

# Kill hung task
killall ralph-loop

# Clean up completed tasks
rm .ralph/progress-*.json
```

### When to Use What

- **Simple task, clear path** → Standard workflow (`/claim-issue` → implement → `/submit-pr`)
- **Complex task, exploration needed** → Ralph workflow (`/claim-issue` → `/ralph-task` → `/submit-pr`)
- **Need progress visibility** → Always use Ralph
- **Time-critical hotfix** → Standard workflow
- **Multi-step with dependencies** → Ralph
- **Single file edit** → Standard workflow

### Configuration Files

- **Enable Ralph**: `profiles/with-ralph.yaml`
- **Disable Ralph**: `profiles/default.yaml`
- **Progress data**: `.ralph/progress-{issue}.json`
- **Skills location**: `.claude/skills/ralph-task`, `.claude/skills/ralph-status`

---

*For more information, see `templates/skills/ralph/README.md.template` or visit [claude-workflow-toolkit](https://github.com/ait88/claude-workflow-toolkit).*
