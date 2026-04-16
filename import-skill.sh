#!/usr/bin/env bash
# import-skill.sh — import a .skill (ZIP) file into prompt-vault
# Usage: ./import-skill.sh <path-to-file.skill>
#
# What it does:
#   1. Unpacks the .skill ZIP
#   2. Finds SKILL.md inside
#   3. Extracts the skill name from YAML frontmatter
#   4. Renames SKILL.md to <skill-name>.md
#   5. Places it in ./prompts/skills/<skill-name>/

set -euo pipefail

SKILLS_DIR="./prompts/skills"

# ── Validate input ─────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-file.skill>" >&2
  exit 1
fi

SKILL_FILE="$1"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "Error: file not found: $SKILL_FILE" >&2
  exit 1
fi

# ── Unpack to temp dir ─────────────────────────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Unpacking: $SKILL_FILE"
unzip -q "$SKILL_FILE" -d "$TMP_DIR"

# ── Find SKILL.md ──────────────────────────────────────────────────────────────
SKILL_MD=$(find "$TMP_DIR" -name "SKILL.md" | head -n 1)

if [[ -z "$SKILL_MD" ]]; then
  echo "Error: SKILL.md not found inside the archive." >&2
  exit 1
fi

echo "Found: $SKILL_MD"

# ── Extract name from YAML frontmatter ────────────────────────────────────────
# Looks for:  name: some-skill-name
SKILL_NAME=$(awk '/^---/{found++; next} found==1 && /^name:/{gsub(/^name:[[:space:]]+/, ""); print; exit}' "$SKILL_MD")

if [[ -z "$SKILL_NAME" ]]; then
  echo "Error: could not extract 'name' from YAML frontmatter in SKILL.md." >&2
  exit 1
fi

echo "Skill name: $SKILL_NAME"

# ── Copy SKILL.md as <skill-name>.md directly into skills dir ─────────────────
mkdir -p "$SKILLS_DIR"

TARGET_FILE="$SKILLS_DIR/$SKILL_NAME.md"

if [[ -f "$TARGET_FILE" ]]; then
  echo "Warning: $TARGET_FILE already exists — overwriting."
fi

cp "$SKILL_MD" "$TARGET_FILE"

echo "Imported → $TARGET_FILE"