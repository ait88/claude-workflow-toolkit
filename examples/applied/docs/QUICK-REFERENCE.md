# Quick Reference for Claude & Codex Agents

> **Example output** - This shows what generated documentation looks like after applying the toolkit with the `node-npm` profile.

**Read time:** 3-5 minutes

---

## Quick Start Paths

### "I need to work on an issue"
1. Find work: `gh issue list --label "agent-ready"`
2. Claim it: `/claim-issue <number>`
3. Implement: Follow coding conventions below
4. Submit: `/submit-pr`

### "I need to understand the codebase"
1. Architecture: [ARCHITECTURE.md](ARCHITECTURE.md) (if exists)
2. File navigation: [CODEBASE-MAP.md](CODEBASE-MAP.md)
3. Common questions: [FAQ-AGENTS.md](FAQ-AGENTS.md)

### "I need to implement a feature"
1. Check [FAQ-AGENTS.md](FAQ-AGENTS.md) first
2. Find relevant files in [CODEBASE-MAP.md](CODEBASE-MAP.md)
3. Follow coding conventions below
4. Run tests: `npm test`

---

## Documentation Index

| Document | What's Inside | When to Read |
|----------|---------------|--------------|
| [FAQ-AGENTS.md](FAQ-AGENTS.md) | Common questions pre-answered | Before reading longer docs |
| [CODEBASE-MAP.md](CODEBASE-MAP.md) | File navigation guide | Finding code |
| [.claude/skills/README.md](../.claude/skills/README.md) | Workflow skills (mirrored at `.codex/skills`) | Using skills |

---

## Common Tasks Quick Finder

### Workflow Tasks
- **Claim an issue:** `/claim-issue <number>`
- **Validate workflow:** `/check-workflow`
- **Submit PR:** `/submit-pr`
- **Check labels:** `gh issue view $ISSUE --json labels`

### Development Tasks
- **Run tests:** `npm test`
- **Check code style:** `npm run lint`
- **Find files:** Use [CODEBASE-MAP.md](CODEBASE-MAP.md)

---

## Pre-Flight Checklists

### Before Every Commit
- [ ] Tests pass: `npm test`
- [ ] Code style: `npm run lint`
- [ ] Conventional commit message format

### Before Creating PR
- [ ] `/check-workflow` passes
- [ ] All tests passing
- [ ] Documentation updated if needed

---

## Coding Conventions

### Commit Message Format
```
<type>(<scope>): <description> (#<issue>)
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

**Examples:**
```
feat(api): add retry logic (#35)
fix(mapper): handle null values (#42)
docs(readme): update installation steps (#18)
```

---

**Last updated:** 2026-01-06
