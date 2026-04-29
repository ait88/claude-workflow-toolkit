#!/usr/bin/env bash
# test-changelog-feature.sh
# Validates the profile-driven CHANGELOG awareness feature (issue #78).
#
# Bootstraps two temporary install targets — one with `changelog.enabled: true`
# (node-npm) and one with `enabled: false` (default) — then asserts that the
# rendered files differ exactly where expected.
#
# Usage: ./scripts/test-changelog-feature.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
TMP_ROOT=""

cleanup() {
    [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]] && rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

assert_contains() {
    local file="$1" needle="$2" label="$3"
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}PASS${NC} $label"
        ((++PASS))
    else
        echo -e "  ${RED}FAIL${NC} $label (expected to find: $needle)"
        echo "         in: $file"
        ((++FAIL))
    fi
}

assert_absent() {
    local file="$1" needle="$2" label="$3"
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
        echo -e "  ${RED}FAIL${NC} $label (expected NOT to find: $needle)"
        echo "         in: $file"
        ((++FAIL))
    else
        echo -e "  ${GREEN}PASS${NC} $label"
        ((++PASS))
    fi
}

TMP_ROOT="$(mktemp -d -t cwt-changelog-test.XXXXXX)"
ENABLED_DIR="$TMP_ROOT/enabled"
DISABLED_DIR="$TMP_ROOT/disabled"
mkdir -p "$ENABLED_DIR" "$DISABLED_DIR"

echo "Installing toolkit with changelog.enabled=true (node-npm profile)..."
"$TOOLKIT_DIR/scripts/install-skill.sh" --full \
    --target "$ENABLED_DIR" \
    --profile node-npm \
    --update >/dev/null

echo "Installing toolkit with changelog.enabled=false (default profile)..."
"$TOOLKIT_DIR/scripts/install-skill.sh" --full \
    --target "$DISABLED_DIR" \
    --profile default \
    --update >/dev/null

echo ""
echo "Asserting changelog-enabled output..."

assert_contains "$ENABLED_DIR/CLAUDE.md" \
    "## CHANGELOG Convention" \
    "CLAUDE.md has CHANGELOG Convention section"

# Placeholder should be substituted to "true" at install time
assert_contains "$ENABLED_DIR/.claude/skills/submit-pr" \
    'if [[ "true" == "true" ]]' \
    "submit-pr has CHANGELOG_ENABLED gate baked as true"

assert_contains "$ENABLED_DIR/.claude/skills/review-pr" \
    "7. CHANGELOG Entry" \
    "review-pr emits 7th checklist item"

assert_contains "$ENABLED_DIR/.claude/commands/review-pr.md" \
    "### 7. CHANGELOG Entry" \
    "review-pr.md documents 7th checklist item"

assert_contains "$ENABLED_DIR/.claude/commands/worker.md" \
    "update \`CHANGELOG.md\`" \
    "worker.md mentions CHANGELOG update step"

assert_contains "$ENABLED_DIR/.claude/WORKER-ROLE.md" \
    "update CHANGELOG.md '[Unreleased]'" \
    "WORKER-ROLE.md mentions CHANGELOG in workflow"

assert_contains "$ENABLED_DIR/.claude/WORKER-ROLE.md" \
    "Add a \`## [Unreleased]\` entry to \`CHANGELOG.md\`" \
    "WORKER-ROLE.md lists CHANGELOG as autonomous action"

assert_contains "$ENABLED_DIR/.claude/docs/QUICK-REFERENCE.md" \
    "\`CHANGELOG.md\` updated under" \
    "QUICK-REFERENCE.md adds pre-flight item"

echo ""
echo "Asserting changelog-disabled output..."

assert_absent "$DISABLED_DIR/CLAUDE.md" \
    "## CHANGELOG Convention" \
    "CLAUDE.md has NO CHANGELOG Convention section"

assert_absent "$DISABLED_DIR/.claude/skills/review-pr" \
    "7. CHANGELOG Entry" \
    "review-pr does NOT emit 7th checklist item"

assert_absent "$DISABLED_DIR/.claude/commands/review-pr.md" \
    "### 7. CHANGELOG Entry" \
    "review-pr.md has NO 7th checklist item"

assert_absent "$DISABLED_DIR/.claude/commands/worker.md" \
    "update \`CHANGELOG.md\`" \
    "worker.md does NOT mention CHANGELOG"

assert_absent "$DISABLED_DIR/.claude/WORKER-ROLE.md" \
    "update CHANGELOG.md" \
    "WORKER-ROLE.md does NOT mention CHANGELOG in workflow"

assert_absent "$DISABLED_DIR/.claude/WORKER-ROLE.md" \
    "Add a \`## [Unreleased]\` entry" \
    "WORKER-ROLE.md does NOT list CHANGELOG as autonomous action"

assert_absent "$DISABLED_DIR/.claude/docs/QUICK-REFERENCE.md" \
    "\`CHANGELOG.md\` updated under" \
    "QUICK-REFERENCE.md has NO CHANGELOG pre-flight item"

# submit-pr is always present, but the runtime gate should be baked as "false"
assert_contains "$DISABLED_DIR/.claude/skills/submit-pr" \
    'if [[ "false" == "true" ]]' \
    "submit-pr has CHANGELOG_ENABLED gate baked as false"

# Conditional markers must never leak through to installed output
echo ""
echo "Asserting no marker leaks..."
for f in "$ENABLED_DIR/CLAUDE.md" "$DISABLED_DIR/CLAUDE.md" \
         "$ENABLED_DIR/.claude/WORKER-ROLE.md" "$DISABLED_DIR/.claude/WORKER-ROLE.md" \
         "$ENABLED_DIR/.claude/skills/review-pr" "$DISABLED_DIR/.claude/skills/review-pr" \
         "$ENABLED_DIR/.claude/commands/worker.md" "$DISABLED_DIR/.claude/commands/worker.md" \
         "$ENABLED_DIR/.claude/docs/QUICK-REFERENCE.md" "$DISABLED_DIR/.claude/docs/QUICK-REFERENCE.md"; do
    [[ -f "$f" ]] || continue
    if grep -qE '\{\{(IF|END):' "$f"; then
        echo -e "  ${RED}FAIL${NC} marker leak in $f"
        ((++FAIL))
    fi
done
echo -e "  ${GREEN}PASS${NC} no IF/END markers in installed output"
((++PASS))

echo ""
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}All $PASS assertions passed${NC}"
    exit 0
else
    echo -e "${RED}$FAIL of $((PASS + FAIL)) assertions failed${NC}"
    exit 1
fi
