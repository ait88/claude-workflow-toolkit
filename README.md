# Claude Workflow Toolkit

A reusable template system for optimizing Claude Code agent workflows across any project.

## What This Does

This toolkit provides:
- **Workflow Skills**: Bash scripts that automate GitHub issue/PR workflows with 70-80% fewer API calls
- **Documentation Templates**: Quick-reference docs that help agents navigate your codebase efficiently
- **Project Profiles**: Pre-configured settings for common tech stacks
- **Ralph Wiggum Integration** (Optional): Iterative task execution with multi-model orchestration for complex features

## How It Works

1. **One-time application**: Run the toolkit against your project
2. **Generates tailored files**: Skills and docs customized to your project
3. **Project owns the output**: Your repo maintains its own copy, independent of this toolkit
4. **Optional updates**: Re-run later to pull in new optimizations

## Quick Start

### For Claude Code Agents

If you're a Claude Code agent asked to optimize a project:

1. Read `SKILL.md` for detailed instructions
2. Identify the target project's tech stack
3. Select appropriate profile from `profiles/`
4. Apply templates with project-specific values

### For Humans

1. Clone this repo alongside your project
2. Ask your Claude Code agent to "optimize this project using the workflow toolkit"
3. Review and commit the generated files
4. Optionally delete the toolkit clone (your project is now self-contained)

## What Gets Generated

```
your-project/
├── .claude/
│   ├── skills/
│   │   ├── claim-issue      # Claim issue + create branch (1 API call)
│   │   ├── check-workflow   # Validate workflow state (1 API call)
│   │   ├── submit-pr        # Create PR + update labels (1 API call)
│   │   └── README.md
│   └── settings.local.json  # Pre-configured Claude Code permissions
└── docs/
    ├── QUICK-REFERENCE.md   # Fast navigation for agents
    ├── FAQ-AGENTS.md        # Pre-answered questions
    └── CODEBASE-MAP.md      # Annotated directory structure
```

## Profiles

| Profile | Best For |
|---------|----------|
| `default.yaml` | Any project (Ralph disabled) |
| `with-ralph.yaml` | Projects using Ralph Wiggum integration |
| `php-composer.yaml` | PHP with Composer |
| `bash-cli.yaml` | Bash CLI tools |
| `node-npm.yaml` | Node.js/TypeScript |
| `python-poetry.yaml` | Python with Poetry |

## API Efficiency

### Traditional workflow (manual commands)
- Claim issue: 3-4 API calls
- Check workflow: 4-5 API calls
- Submit PR: 2-3 API calls
- **Total: ~12 API calls per issue**

### With toolkit skills
- Claim issue: 1 API call
- Check workflow: 1 API call
- Submit PR: 1 API call
- **Total: ~3 API calls per issue**

**Result: 70-80% reduction in GitHub API usage**

## Template Variables

All templates use `{{VARIABLE}}` syntax for placeholders:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{PROJECT_NAME}}` | Repository name | `my-project` |
| `{{REPO_OWNER}}` | GitHub owner/org | `mycompany` |
| `{{DEFAULT_BRANCH}}` | Main branch name | `main` |
| `{{TEST_COMMAND}}` | How to run tests | `npm test` |
| `{{LINT_COMMAND}}` | How to check style | `npm run lint` |
| `{{PHASE_PREFIX}}` | Phase label prefix | `phase-` |
| `{{SKILLS_DIR}}` | Skills directory | `.claude/skills` |
| `{{DOCS_DIR}}` | Docs directory | `docs` |

## Repository Structure

```
claude-workflow-toolkit/
├── SKILL.md                    # Instructions for Claude agents
├── README.md                   # This file (human documentation)
├── LICENSE                     # MIT License
│
├── templates/
│   ├── skills/                 # Workflow skill templates
│   │   ├── claim-issue.sh.template
│   │   ├── check-workflow.sh.template
│   │   ├── submit-pr.sh.template
│   │   └── README.md.template
│   │
│   ├── .claude/
│   │   └── settings.local.json.template  # Claude Code permissions
│   │
│   └── docs/                   # Documentation templates
│       ├── QUICK-REFERENCE.md.template
│       ├── FAQ-AGENTS.md.template
│       └── CODEBASE-MAP.md.template
│
├── profiles/                   # Pre-configured project settings
│   ├── default.yaml
│   ├── php-composer.yaml
│   ├── bash-cli.yaml
│   ├── node-npm.yaml
│   └── python-poetry.yaml
│
├── examples/
│   └── applied/               # Example generated output
│
└── scripts/
    ├── setup-labels.sh        # Create required GitHub labels
    └── validate-templates.sh  # Template syntax validator
```

## Setup Scripts

### `scripts/setup-labels.sh`

Creates the required GitHub labels in your repository:
- **Workflow labels**: `agent-ready`, `in-progress`, `needs-review`, `blocked`
- **Phase labels**: `phase-0` through `phase-6`
- **Type labels**: `bug`, `enhancement`, `documentation`

```bash
./scripts/setup-labels.sh
```

## Optional Features

### Ralph Wiggum Integration

Enable iterative task execution with multi-model orchestration for complex features:
- Loop-based execution until `VERIFIED_DONE` state
- Automatic model routing: Claude, Codex, Gemini, MiniMax
- Progress tracking with `.ralph/progress-{issue}.json`
- 30-50% token savings on complex tasks through smart model selection

**Enable Ralph:**
```bash
# Use with-ralph.yaml profile when applying toolkit
# Agent will generate /ralph-task and /ralph-status skills
```

**Usage:**
```bash
/ralph-task 42 "Implement OAuth2 authentication"
/ralph-status 42  # Monitor progress
```

See [`docs/RALPH-INTEGRATION.md`](docs/RALPH-INTEGRATION.md) for full documentation.

## Why Use This?

### Before (Manual Workflow)
```bash
# Claiming an issue - 4 separate commands
gh issue view 35
gh issue edit 35 --remove-label "agent-ready"
gh issue edit 35 --add-label "in-progress"
git checkout -b 35-feature-name

# Each command = separate API call
# More commands to remember
# Easy to forget label updates
```

### After (Skill-Based Workflow)
```bash
# One command does everything
/claim-issue 35

# Single API call
# Atomic operation
# Can't forget labels
```

## Contributing

Contributions welcome! Please:
1. Test templates against real projects
2. Keep templates generic (no project-specific references)
3. Document new variables in SKILL.md
4. Add examples for new profiles

### Adding a New Profile

1. Create `profiles/your-stack.yaml`
2. Define appropriate `test_command`, `lint_command`, etc.
3. Add any stack-specific conventions
4. Update README.md profiles table

### Improving Templates

1. Templates should work after variable substitution
2. Use `{{VARIABLE}}` syntax consistently
3. Test by mentally substituting real values
4. Include comments explaining key logic

## License

MIT License - See [LICENSE](LICENSE)

## Related Projects

- [Claude Code](https://claude.ai/claude-code) - Anthropic's official CLI for Claude
- [GitHub CLI](https://cli.github.com/) - GitHub's official command line tool

---

**Created to reduce token usage and improve workflow consistency for Claude Code agents.**
