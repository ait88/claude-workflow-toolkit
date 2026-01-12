# Claude Workflow Toolkit

## Purpose

This toolkit provides templates and patterns for optimizing Claude Code and Codex agent workflows in any repository. Use it to apply consistent, efficient workflow automation to a target project.

## When to Use This Toolkit

Use this toolkit when:
- Setting up a new project for Claude Code or Codex agent collaboration
- Optimizing an existing project's agent workflow
- Updating a project to latest workflow best practices

## How to Apply This Toolkit

### Step 1: Understand the Target Project

Before applying, gather information about the target project:
- **Language/Framework**: What tech stack? (PHP, Node, Python, Bash, etc.)
- **Package Manager**: composer, npm, pip, none?
- **Test Command**: How are tests run?
- **Lint Command**: How is code style checked?
- **Branch Naming**: Any existing conventions?
- **Label Scheme**: Existing GitHub labels?
- **Directory Structure**: Where does source code live?

### Step 2: Select a Profile

Choose the closest matching profile from `/profiles/`:
- `default.yaml` - Generic, works for any project
- `php-composer.yaml` - PHP projects using Composer
- `bash-cli.yaml` - Bash CLI tools and scripts
- `node-npm.yaml` - Node.js/TypeScript projects
- `python-poetry.yaml` - Python projects

### Step 3: Customize Variables

Each template uses `{{VARIABLE}}` placeholders. Common variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{PROJECT_NAME}}` | Repository name | `my-project` |
| `{{REPO_OWNER}}` | GitHub owner/org | `username` |
| `{{DEFAULT_BRANCH}}` | Main branch name | `main` |
| `{{TEST_COMMAND}}` | How to run tests | `composer test` |
| `{{LINT_COMMAND}}` | How to check style | `npm run lint` |
| `{{PHASE_PREFIX}}` | Label prefix for phases | `phase-` |
| `{{PHASE_COUNT}}` | Number of phases (0-indexed) | `6` |
| `{{SKILLS_DIR}}` | Where skills live | `.claude/skills` |
| `{{CODEX_SKILLS_DIR}}` | Where Codex reads the mirrored skills | `.codex/skills` |
| `{{COMMANDS_DIR}}` | Command documentation directory | `.claude/commands` |
| `{{DOCS_DIR}}` | Documentation directory | `docs` |
| `{{CODEX_BOT_USER}}` | Codex review bot username | `chatgpt-codex-connector[bot]` |
| `{{TEST_UNIT_COMMAND}}` | Unit test command | `npm run test:unit` |
| `{{TEST_INTEGRATION_COMMAND}}` | Integration test command | `npm run test:integration` |
| `{{TOOLKIT_SOURCE}}` | Path to toolkit source | `~/claude-workflow-toolkit` |
| `{{TOOLKIT_COMMIT}}` | Git commit hash when applied | `a37ae2d...` |

Use `{{SKILLS_DIR}}` as the canonical location (default `.claude/skills`) and keep `{{CODEX_SKILLS_DIR}}` as a symlink or copy pointing at the same files for Codex agents.

### Step 4: Generate Files

For each template:
1. Read the template file
2. Replace all `{{VARIABLE}}` placeholders with project-specific values
3. Write to the target project location
4. Make skill scripts executable (`chmod +x`)
5. Mirror skills for Codex: ensure `{{CODEX_SKILLS_DIR}}` points to the same files (symlink recommended)

### Step 5: Verify Installation

After applying:
1. Verify skills are executable: `ls -la {{SKILLS_DIR}}/`
2. Confirm Codex mirror exists: `ls -la {{CODEX_SKILLS_DIR}}/` (symlink or copy of `{{SKILLS_DIR}}`)
3. Test claim-issue with a test issue number
4. Run check-workflow to verify it detects current state
5. Review generated documentation for accuracy

## Template Reference

### Skills Templates

#### `check-reviews.sh.template` (NEW)
Detects PRs with unaddressed review feedback - **run BEFORE claiming new issues**.
- Lists open PRs with reviews
- Shows Codex review comments with priority levels (P1/P2/P3)
- Provides guidance on next steps
- Enforces review-first workflow

#### `address-review.sh.template` (NEW)
Checks out a PR branch and displays all review feedback for addressing.
- Fetches PR details and checks out branch
- Displays Codex review suggestions with file locations
- Shows human review comments by file
- Provides commit/push workflow

#### `claim-issue.sh.template`
Atomically claims a GitHub issue and creates a feature branch.
- Removes `agent-ready` label
- Adds `in-progress` label
- Creates branch: `<issue>-<title-slug>`
- Single operation prevents inconsistent state

#### `check-workflow.sh.template`
Validates current workflow state using GraphQL (1 API call vs 4-5 REST calls).
- Extracts issue number from branch name
- Validates labels match workflow stage
- Provides fix commands for any issues
- Color-coded output for quick scanning

#### `submit-pr.sh.template`
Creates PR and updates labels atomically.
- Pushes current branch
- Creates PR with "Closes #X"
- Removes `in-progress`, adds `needs-review`

### Command Documentation Templates

Located in `templates/.claude/commands/`:

| Template | Purpose |
|----------|---------|
| `check-reviews.md.template` | Documentation for check-reviews skill |
| `address-review.md.template` | Documentation for address-review skill |
| `claim-issue.md.template` | Documentation for claim-issue skill |
| `check-workflow.md.template` | Documentation for check-workflow skill |
| `submit-pr.md.template` | Documentation for submit-pr skill |

These provide discoverability for agents browsing the `.claude/` directory.

### Security Checklist Templates

Located in `templates/.claude/`:

| Template | Best For |
|----------|----------|
| `SECURITY-CHECKLIST.md.template` | Generic (OWASP Top 10 focused) |
| `SECURITY-CHECKLIST-php.md.template` | PHP/WordPress/WooCommerce |
| `SECURITY-CHECKLIST-node.md.template` | Node.js/Express/npm |
| `SECURITY-CHECKLIST-python.md.template` | Python/Django/Flask |
| `SECURITY-CHECKLIST-bash.md.template` | Bash/Shell scripts |

Choose the checklist matching your tech stack. Include in `.claude/` for agent reference.

### Documentation Templates

#### `QUICK-REFERENCE.md.template`
Fast navigation document for agents - "where do I find X?"
- Quick start paths for common tasks
- Pre-flight checklists
- Coding conventions summary
- Links to detailed docs

#### `FAQ-AGENTS.md.template`
Pre-answered common questions to reduce repeated lookups.
- Project-specific Q&A format
- Reduces tokens spent re-discovering information

#### `CODEBASE-MAP.md.template`
Visual directory structure with annotations.
- What each directory/file does
- Entry points for common tasks
- Dependency relationships

## Optimization Principles

These skills are designed around key principles:

1. **Minimize API Calls**: GraphQL over REST where possible
2. **Atomic Operations**: Prevent inconsistent state
3. **Self-Documenting**: Skills output what they're doing
4. **Graceful Errors**: Clear messages, actionable fixes
5. **Idempotent Where Possible**: Safe to re-run

## Application Workflow

When applying this toolkit to a target project:

```
1. Clone/access target project
2. Gather project information (language, test command, etc.)
3. Select appropriate profile
4. For each template:
   a. Read template content
   b. Substitute {{VARIABLES}} with project values
   c. Write to target path
   d. Set permissions (chmod +x for scripts)
5. Mirror skills for Codex (symlink `{{CODEX_SKILLS_DIR}}` to `{{SKILLS_DIR}}` or copy files)
6. Update target project's .gitignore if needed
7. Test the generated skills
8. Commit changes to target project
```

## Output Structure

After applying, the target project will have:

```
target-project/
├── .claude/
│   ├── skills/              # Canonical skills for both agents
│   │   ├── check-reviews    # Detect unaddressed reviews (run first!)
│   │   ├── address-review   # Address review feedback
│   │   ├── claim-issue      # Claim issue + create branch
│   │   ├── check-workflow   # Validate workflow state
│   │   ├── submit-pr        # Create PR + update labels
│   │   └── README.md        # Skills documentation
│   ├── commands/            # Command documentation
│   │   ├── check-reviews.md
│   │   ├── address-review.md
│   │   ├── claim-issue.md
│   │   ├── check-workflow.md
│   │   └── submit-pr.md
│   ├── toolkit-version      # Tracks applied toolkit version
│   ├── SECURITY-CHECKLIST.md  # Tech-specific security guide
│   └── settings.local.json  # Pre-configured Claude Code permissions
├── {{CODEX_SKILLS_DIR}} -> {{SKILLS_DIR}}  # Codex mirror of the skills
└── {{DOCS_DIR}}/
    ├── QUICK-REFERENCE.md   # Navigation hub
    ├── FAQ-AGENTS.md        # Pre-answered questions
    └── CODEBASE-MAP.md      # Annotated directory structure
```

### Optional: Setup GitHub Labels

Before using the workflow, the target repository needs the required labels. Run the setup script from this toolkit in the target repo:

```bash
# From target project directory
/path/to/claude-workflow-toolkit/scripts/setup-labels.sh
```

This creates: `agent-ready`, `in-progress`, `needs-review`, `blocked`, `phase-0` through `phase-6`, and type labels.

## Maintenance

When updating the toolkit:
1. Update templates in this repo
2. For projects using this toolkit, re-run the application process
3. Projects can diff changes and selectively adopt updates

## Automatic Update Check

The `/check-reviews` skill automatically checks for toolkit updates once per session:

- **Silent by default**: No output if toolkit is current or not installed
- **Minimal overhead**: Uses local git comparison only (no network fetch)
- **Non-blocking**: Displays a note and continues with normal operation

When updates are available, you'll see:
```
NOTE: Workflow toolkit updates available in ~/claude-workflow-toolkit
      (Applied: a37ae2d, Current: b48bf3e)
```

To apply updates:
1. Review changes in the toolkit: `git -C ~/claude-workflow-toolkit log --oneline`
2. Re-run the application process with updated templates
3. The `toolkit-version` file will be updated automatically

### Generating toolkit-version

When applying the toolkit, generate the version file:

```bash
# Get current toolkit commit
TOOLKIT_COMMIT=$(git -C ~/claude-workflow-toolkit rev-parse HEAD)

# Substitute in template
sed "s/{{TOOLKIT_SOURCE}}/~\/claude-workflow-toolkit/g; \
     s/{{TOOLKIT_COMMIT}}/$TOOLKIT_COMMIT/g; \
     s/{{CURRENT_DATE}}/$(date +%Y-%m-%d)/g" \
    templates/.claude/toolkit-version.template > target/.claude/toolkit-version
```

## Troubleshooting

### "Permission denied" when running skills
```bash
chmod +x {{SKILLS_DIR}}/*
```

### "gh: command not found"
Install GitHub CLI: https://cli.github.com/

### "jq: command not found"
Install jq:
- macOS: `brew install jq`
- Ubuntu/Debian: `sudo apt-get install jq`
- RHEL/CentOS: `sudo yum install jq`

### Skills not appearing as slash commands (Claude or Codex)
Skills should be in `{{SKILLS_DIR}}/` with a mirror at `{{CODEX_SKILLS_DIR}}`. Verify:
1. Files exist and are executable in the canonical `{{SKILLS_DIR}}`
2. `{{CODEX_SKILLS_DIR}}` points to the same scripts (symlink or copy)
3. Files have no `.sh` extension (just `claim-issue`, not `claim-issue.sh`)
4. The agent (Claude or Codex) is restarted after adding skills

### SSH authentication fails
The skill templates include automatic SSH/HTTPS fallback. If SSH fails, they'll attempt to use `gh auth setup-git` to configure HTTPS authentication. Ensure:
1. GitHub CLI is authenticated: `gh auth status`
2. If using SSH, keys are properly configured: `ssh -T git@github.com`
