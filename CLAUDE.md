# Claude Workflow Toolkit

This is a template toolkit for applying workflow optimizations to other projects.

## If You're Here to Apply This Toolkit

Read `SKILL.md` for detailed instructions on how to apply these templates to a target project.

**Quick summary:**
1. Identify the target project's tech stack
2. Select a profile from `profiles/` (e.g., `node-npm.yaml`, `php-composer.yaml`)
3. For each template in `templates/`, substitute `{{VARIABLES}}` with project values
4. Write the generated files to the target project
5. Make skill scripts executable (`chmod +x`)
6. Mirror skills for Codex: `ln -s ../.claude/skills .codex/skills`

## Key Directories

- `templates/` - All template files with `{{VARIABLE}}` placeholders
- `profiles/` - Pre-configured settings for different tech stacks
- `scripts/` - Utility scripts (setup-labels.sh, validate-templates.sh)
- `SKILL.md` - Detailed application instructions

## Template Variables

Common variables to substitute:

| Variable | Example |
|----------|---------|
| `{{PROJECT_NAME}}` | `my-project` |
| `{{REPO_OWNER}}` | `username` |
| `{{TEST_COMMAND}}` | `npm test` |
| `{{LINT_COMMAND}}` | `npm run lint` |
| `{{CODEX_BOT_USER}}` | `chatgpt-codex-connector[bot]` |

See `SKILL.md` for the complete list.

## Priority Work Order

The generated skills enforce this workflow:

```
1. /check-reviews      ← Always run first
2. /address-review     ← Address any feedback found
3. /claim-issue        ← Only then claim new work
4. /check-workflow     ← Validate before submitting
5. /submit-pr          ← Create PR atomically
```
