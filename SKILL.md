# Claude Workflow Toolkit

## Purpose

This toolkit provides templates and patterns for optimizing Claude Code agent workflows in any repository. Use it to apply consistent, efficient workflow automation to a target project.

## When to Use This Toolkit

Use this toolkit when:
- Setting up a new project for Claude Code agent collaboration
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
| `{{DOCS_DIR}}` | Documentation directory | `docs` |

### Step 4: Generate Files

For each template:
1. Read the template file
2. Replace all `{{VARIABLE}}` placeholders with project-specific values
3. Write to the target project location
4. Make skill scripts executable (`chmod +x`)

### Step 5: Verify Installation

After applying:
1. Verify skills are executable: `ls -la {{SKILLS_DIR}}/`
2. Test claim-issue with a test issue number
3. Run check-workflow to verify it detects current state
4. Review generated documentation for accuracy

## Template Reference

### Skills Templates

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
5. Update target project's .gitignore if needed
6. Test the generated skills
7. Commit changes to target project
```

## Output Structure

After applying, the target project will have:

```
target-project/
├── {{SKILLS_DIR}}/
│   ├── claim-issue      # Claim issue + create branch
│   ├── check-workflow   # Validate workflow state
│   ├── submit-pr        # Create PR + update labels
│   └── README.md        # Skills documentation
└── {{DOCS_DIR}}/
    ├── QUICK-REFERENCE.md   # Navigation hub
    ├── FAQ-AGENTS.md        # Pre-answered questions
    └── CODEBASE-MAP.md      # Annotated directory structure
```

## Maintenance

When updating the toolkit:
1. Update templates in this repo
2. For projects using this toolkit, re-run the application process
3. Projects can diff changes and selectively adopt updates

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

### Skills not appearing as slash commands
Skills should be in `{{SKILLS_DIR}}/` directory. Verify:
1. Files exist and are executable
2. Files have no `.sh` extension (just `claim-issue`, not `claim-issue.sh`)
3. Claude Code is restarted after adding skills
