# Feedback: Worker Skill Installation Experience

**Date:** 2026-01-31
**Context:** Attempting to add `/worker` skill to an existing workspace
**Outcome:** Successfully installed after manual intervention

---

## Summary

The `/worker` skill templates exist in the toolkit but weren't installed to the workspace. Installing them required understanding multiple files, manually processing templates, and copying to two different locations. The process revealed several gaps in the toolkit's installation/update workflow.

---

## Friction Points Encountered

### 1. No "What's Missing" Detection

**Problem:** When `/worker` wasn't available, there was no way to know:
- That it should exist
- That templates were available but not installed
- What other skills might be missing

**Current state:** User must manually compare `profiles/default.yaml` output list against installed skills.

**Suggestion:** Add a `/check-toolkit` or `validate-installation.sh` script that:
```bash
# Compares expected skills (from profile) vs installed skills
# Reports: "Missing skills: worker"
# Reports: "Skills needing update: check-reviews (template newer than installed)"
```

---

### 2. No Installation Automation

**Problem:** `SKILL.md` documents a 5-step manual process for applying templates:
1. Read template file
2. Replace `{{VARIABLE}}` placeholders
3. Write to target location
4. Make executable
5. Mirror for Codex

**Reality:** I had to:
- Find templates in two locations (`templates/skills/`, `templates/.claude/commands/`)
- Look up placeholder values in `profiles/default.yaml`
- Run sed commands manually
- Remember to `chmod +x`
- Install to both `.claude/skills/` AND `~/.claude/commands/`

**Suggestion:** Create `install-skill.sh`:
```bash
./scripts/install-skill.sh worker --profile default --target ~/workspaces/my-workspace
```

Or a comprehensive installer:
```bash
./scripts/apply-toolkit.sh --profile default --target ~/workspaces/my-workspace --skills worker
```

---

### 3. Profile System is Passive

**Problem:** Profiles (`profiles/*.yaml`) define configuration values but nothing consumes them programmatically. They're reference documentation, not automation input.

**Current workflow:**
1. Human reads `profiles/default.yaml`
2. Human manually extracts values
3. Human runs sed/replace commands

**Suggestion:** Make profiles machine-readable and create tooling:
```bash
# Parse profile, substitute templates, output to target
./scripts/render-template.sh templates/skills/worker.sh.template --profile default
```

---

### 4. Dual Installation Locations Are Confusing

**Problem:** Skills require files in TWO places:
- `.claude/skills/worker` - The executable script
- `~/.claude/commands/worker.md` - The command documentation (global)

This split isn't documented clearly. I almost missed installing the command doc.

**Questions this raises:**
- Why is command doc global (`~/.claude/commands/`) while skill is local?
- Should workspace installations have their own commands dir?
- What happens with multiple workspaces - do they share command docs?

**Suggestion:** Either:
- Document this clearly in SKILL.md under "Installation Locations"
- Or consolidate: put command docs in workspace `.claude/commands/` and configure Claude to look there

---

### 5. Workspace vs Toolkit Source Relationship Unclear

**Problem:** The relationship between these directories is confusing:
- `/home/agent-116/claude-workflow-toolkit` - Toolkit source (templates live here)
- `/home/agent-116/workspaces/claude-workflow-toolkit` - A workspace using the toolkit

The `workspace-config` file points to the toolkit as `TOOLKIT_SOURCE` but there's no mechanism to:
- Pull updates from source to workspace
- Detect when source templates are newer than installed skills
- Re-apply specific skills after toolkit updates

**Suggestion:** Add update workflow:
```bash
# From workspace directory
./scripts/update-from-source.sh  # Re-applies templates from TOOLKIT_SOURCE
./scripts/update-from-source.sh --skill worker  # Update specific skill
```

---

### 6. Template Placeholders Not Validated

**Problem:** After installation, I had to manually grep to verify placeholders were replaced. If a placeholder is misspelled or missing from the profile, it silently remains as `{{PLACEHOLDER}}` in the output.

**Suggestion:** Add template validation:
```bash
./scripts/validate-templates.sh  # Existing script
# Should also check: "All placeholders have values in profile"
# Should warn: "Template has {{FOO}} but profile doesn't define FOO"
```

---

### 7. No Rollback/Uninstall

**Problem:** If a skill is installed incorrectly or needs to be removed, there's no documented process.

**Suggestion:** Add uninstall capability:
```bash
./scripts/uninstall-skill.sh worker --target ~/workspaces/my-workspace
```

---

## Recommendations Summary

| Priority | Recommendation | Effort |
|----------|----------------|--------|
| High | Create `install-skill.sh` script | Medium |
| High | Add "missing skills" detection | Low |
| Medium | Make profiles machine-consumable | Medium |
| Medium | Document dual installation locations | Low |
| Medium | Add `update-from-source.sh` | Medium |
| Low | Template placeholder validation | Low |
| Low | Uninstall capability | Low |

---

## Workaround Used

For this session, I manually installed the worker skill:

```bash
# Copy template
cp templates/skills/worker.sh.template .claude/skills/worker

# Substitute placeholders (values from profiles/default.yaml)
sed -i 's/{{WORKER_MAX_RETRIES}}/3/g; ...' .claude/skills/worker

# Make executable
chmod +x .claude/skills/worker

# Install command documentation
cp templates/.claude/commands/worker.md.template ~/.claude/commands/worker.md
sed -i 's/{{WORKER_MAX_RETRIES}}/3/g; ...' ~/.claude/commands/worker.md
```

This worked but required understanding the toolkit internals rather than having a guided process.

---

## Related Issues

Consider creating issues for:
- [ ] `feat: Add install-skill.sh script`
- [ ] `feat: Add toolkit validation/diff command`
- [ ] `docs: Document installation locations and workspace model`
- [ ] `feat: Profile-driven template rendering`
