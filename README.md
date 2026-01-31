# Claude Workflow Toolkit

A reusable template system for optimizing Claude Code and Codex agent workflows across any project.

## What This Does

This toolkit provides:
- **Workflow Skills**: Bash scripts that automate GitHub issue/PR workflows with 60-80% fewer API calls
- **Review-First Workflow**: Skills that ensure review feedback is addressed before new work begins
- **Security Checklists**: Tech-specific security validation guides
- **Documentation Templates**: Quick-reference docs that help agents navigate your codebase efficiently
- **Project Profiles**: Pre-configured settings for common tech stacks

## How It Works

1. **One-time application**: Run the toolkit against your project
2. **Generates tailored files**: Skills, docs, and checklists customized to your project
3. **Project owns the output**: Your repo maintains its own copy, independent of this toolkit
4. **Optional updates**: Re-run later to pull in new optimizations

## Quick Start

### For Claude Code or Codex Agents

If you're a Claude Code or Codex agent asked to apply this toolkit:

1. Read `SKILL.md` for detailed instructions
2. Identify the target project's tech stack
3. Select appropriate profile from `profiles/`
4. Apply templates with project-specific values

### For Humans

1. Clone this repo:
   ```bash
   git clone https://github.com/ait88/claude-workflow-toolkit.git ~/claude-workflow-toolkit
   ```

2. Ask your Claude Code or Codex agent:
   ```
   Apply the workflow toolkit from ~/claude-workflow-toolkit to this project.
   Use workspace mode with ~/workspaces/myproject1 as the workspace.
   Read SKILL.md in the toolkit for instructions.
   ```

3. Review the generated workspace
4. Start using skills from the workspace directory:
   ```bash
   cd ~/workspaces/myproject1
   /check-reviews
   ```

## Installation Modes

The toolkit supports two installation modes:

| Mode | Best For | Project Impact |
|------|----------|----------------|
| **Workspace** (Recommended) | New projects, clean separation | Target project unchanged |
| **Embedded** (Legacy) | Simple setups, single-project use | Adds files to target project |

### Workspace Mode (Recommended)

Keeps your target project clean by placing all toolkit infrastructure in a separate workspace directory:

```
~/workspaces/myproject1/             # Workspace (toolkit infrastructure)
├── .claude/
│   ├── skills/                      # Skills operate on target project
│   ├── commands/                    # Command documentation
│   ├── workspace-config             # Points to target project
│   └── toolkit-version              # Tracks applied version
├── .codex/skills -> .claude/skills  # Codex mirror
└── WORKSPACE.md                     # Explains relationship

~/myproject1/                        # Target project (unchanged/clean)
├── <your code>
└── .git/
```

**Benefits:**
- Target project stays free of toolkit scaffolding
- Easy to use different workspaces for different projects
- Skills support `--project` and `--repo` flags for ad-hoc usage

**Usage from workspace:**
```bash
cd ~/workspaces/myproject1
/check-reviews
/claim-issue 42
```

**Usage from anywhere (with flags):**
```bash
/check-reviews --project ~/myproject1
/claim-issue --repo owner/myproject1 42
```

### Embedded Mode (Legacy)

For simpler setups, apply the toolkit directly inside the target project:

```
your-project/
├── .claude/
│   ├── skills/              # Canonical skill scripts for both agents
│   │   ├── check-reviews    # Find PRs needing response (run first!)
│   │   ├── address-review   # Show review feedback for a PR
│   │   ├── claim-issue      # Claim issue + create branch
│   │   ├── check-workflow   # Validate workflow state
│   │   ├── submit-pr        # Create PR + update labels
│   │   └── README.md
│   ├── commands/            # Skill documentation for discoverability
│   │   ├── check-reviews.md
│   │   ├── address-review.md
│   │   ├── claim-issue.md
│   │   ├── check-workflow.md
│   │   └── submit-pr.md
│   ├── SECURITY-CHECKLIST.md  # Tech-specific security guide
│   └── settings.local.json    # Pre-configured Claude Code permissions
├── .codex/
│   └── skills -> ../.claude/skills  # Mirror so Codex sees the same commands
└── docs/
    ├── QUICK-REFERENCE.md   # Fast navigation for agents
    ├── FAQ-AGENTS.md        # Pre-answered questions
    └── CODEBASE-MAP.md      # Annotated directory structure
```

### Migrating to Workspace Mode

Convert an existing embedded installation to workspace mode:

```bash
~/claude-workflow-toolkit/scripts/migrate-to-workspace.sh \
    ~/myproject1 \
    ~/workspaces/myproject1
```

### Dual-Agent Skills (Claude + Codex)

Keep one canonical skills folder and mirror it for Codex so both agents run the same commands:

```bash
mkdir -p .codex
rm -rf .codex/skills
ln -s ../.claude/skills .codex/skills  # adjust if you customize SKILLS_DIR
```

## Profiles

| Profile | Best For |
|---------|----------|
| `default.yaml` | Any project |
| `php-composer.yaml` | PHP with Composer |
| `bash-cli.yaml` | Bash CLI tools |
| `node-npm.yaml` | Node.js/TypeScript |
| `python-poetry.yaml` | Python with Poetry |

## API Efficiency

### Traditional workflow (manual commands)
- Check for reviews: 5+ API calls
- Claim issue: 3-4 API calls
- Check workflow: 4-5 API calls
- Submit PR: 2-3 API calls
- **Total: ~15+ API calls per workflow cycle**

### With toolkit skills
- Check reviews: 2-3 API calls
- Address review: 2 API calls
- Claim issue: 1 API call
- Check workflow: 1 API call (GraphQL)
- Submit PR: 1 API call
- **Total: ~5-7 API calls per workflow cycle**

**Result: 60-80% reduction in GitHub API usage**

## Template Variables

All templates use `{{VARIABLE}}` syntax for placeholders:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{PROJECT_NAME}}` | Repository name | `my-project` |
| `{{REPO_OWNER}}` | GitHub owner/org | `mycompany` |
| `{{DEFAULT_BRANCH}}` | Main branch name | `main` |
| `{{TEST_COMMAND}}` | How to run tests | `npm test` |
| `{{TEST_UNIT_COMMAND}}` | Unit tests only | `npm run test:unit` |
| `{{TEST_INTEGRATION_COMMAND}}` | Integration tests | `npm run test:integration` |
| `{{LINT_COMMAND}}` | How to check style | `npm run lint` |
| `{{PHASE_PREFIX}}` | Phase label prefix | `phase-` |
| `{{SKILLS_DIR}}` | Skills directory | `.claude/skills` |
| `{{CODEX_SKILLS_DIR}}` | Codex skills mirror | `.codex/skills` |
| `{{COMMANDS_DIR}}` | Command docs directory | `.claude/commands` |
| `{{DOCS_DIR}}` | Docs directory | `docs` |
| `{{CODEX_BOT_USER}}` | Codex review bot username | `chatgpt-codex-connector[bot]` |

### Workspace Mode Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{TARGET_PROJECT_PATH}}` | Absolute path to target project | `/home/user/myproject1` |
| `{{WORKSPACE_NAME}}` | Name of workspace directory | `myproject1` |
| `{{WORKSPACE_PATH}}` | Full path to workspace | `/home/user/workspaces/myproject1` |
| `{{INSTALLATION_MODE}}` | Installation mode | `workspace` or `embedded` |
| `{{TOOLKIT_SOURCE}}` | Path to toolkit source | `~/claude-workflow-toolkit` |
| `{{TOOLKIT_COMMIT}}` | Git commit hash when applied | `1425680...` |

Keep `{{SKILLS_DIR}}` as the canonical skill location and point `{{CODEX_SKILLS_DIR}}` at the same files (symlink recommended) so Claude and Codex use identical commands.

## Repository Structure

```
claude-workflow-toolkit/
├── SKILL.md                    # Instructions for Claude/Codex agents
├── README.md                   # This file (human documentation)
├── LICENSE                     # MIT License
│
├── templates/
│   ├── WORKSPACE.md.template   # Workspace documentation (workspace mode)
│   │
│   ├── skills/                 # Workflow skill templates
│   │   ├── check-reviews.sh.template     # Review detection
│   │   ├── address-review.sh.template    # Review addressing
│   │   ├── claim-issue.sh.template       # Issue claiming
│   │   ├── check-workflow.sh.template    # Workflow validation
│   │   ├── submit-pr.sh.template         # PR submission
│   │   └── README.md.template
│   │
│   ├── .claude/
│   │   ├── commands/           # Skill documentation templates
│   │   │   ├── check-reviews.md.template
│   │   │   ├── address-review.md.template
│   │   │   ├── claim-issue.md.template
│   │   │   ├── check-workflow.md.template
│   │   │   └── submit-pr.md.template
│   │   ├── SECURITY-CHECKLIST.md.template       # Generic
│   │   ├── SECURITY-CHECKLIST-php.md.template   # PHP/WordPress
│   │   ├── SECURITY-CHECKLIST-node.md.template  # Node.js
│   │   ├── SECURITY-CHECKLIST-python.md.template # Python
│   │   ├── SECURITY-CHECKLIST-bash.md.template  # Bash
│   │   ├── settings.local.json.template
│   │   ├── toolkit-version.template     # Version tracking (workspace mode)
│   │   └── workspace-config.template    # Workspace configuration
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
    ├── setup-labels.sh           # Create required GitHub labels
    ├── validate-templates.sh     # Template syntax validator
    └── migrate-to-workspace.sh   # Convert embedded to workspace mode
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

### `scripts/migrate-to-workspace.sh`

Converts an embedded installation to workspace mode:

```bash
./scripts/migrate-to-workspace.sh ~/myproject1 ~/workspaces/myproject1
```

The migration script:
1. Creates the workspace directory structure
2. Copies skills and commands to the workspace
3. Generates workspace-config pointing to the target project
4. Interactively prompts before removing old files from target

## Why Use This?

### Before (Manual Workflow)
```bash
# Did anyone review my PRs? Manual checking...
gh pr list --state open
gh pr view 42 --comments
# Easy to miss reviews and start new work prematurely

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
# First: Check if any reviews need attention
/check-reviews
# Shows all PRs with unaddressed feedback, with priority levels

# Address any reviews found
/address-review 42
# Checks out PR branch, shows all feedback organized by file

# Then claim new work
/claim-issue 35
# Single API call, atomic operation, can't forget labels
```

### Key Benefits
- **Review-first workflow**: Never start new work with unaddressed feedback
- **Atomic operations**: Labels and branches updated together
- **60-80% fewer API calls**: GraphQL and batching optimizations
- **Security checklists**: Tech-specific guides for secure coding
- **Workspace mode**: Keep target projects clean with separate workflow directory

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
- Codex agents - Mirror `.claude/skills` to `.codex/skills` so Codex runs the same skills
- [GitHub CLI](https://cli.github.com/) - GitHub's official command line tool

---

**Created to reduce token usage and improve workflow consistency for Claude Code and Codex agents.**
