#!/usr/bin/env bash
# export-skill.sh — export a skill from prompt-vault to a Claude-compatible .skill file
# Usage: ./export-skill.sh <path-to-skill.md>
#
# What it does:
#   1. Reads <skill-name>.md from prompts/skills/<skill-name>/
#   2. Extracts the skill name from YAML frontmatter
#   3. Creates a temp folder named <skill-name>/
#   4. Copies the .md as SKILL.md inside it
#   5. Packs it as <skill-name>.skill in the current directory

set -euo pipefail

# ── Validate input ─────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-skill.md>" >&2
  exit 1
fi

SOURCE_MD="$1"

if [[ ! -f "$SOURCE_MD" ]]; then
  echo "Error: file not found: $SOURCE_MD" >&2
  exit 1
fi

# ── Extract name from YAML frontmatter ────────────────────────────────────────
SKILL_NAME=$(awk '/^---/{found++; next} found==1 && /^name:/{gsub(/^name:[[:space:]]+/, ""); print; exit}' "$SOURCE_MD")

if [[ -z "$SKILL_NAME" ]]; then
  echo "Error: could not extract 'name' from YAML frontmatter in $SOURCE_MD." >&2
  exit 1
fi

echo "Skill name: $SKILL_NAME"

# ── Build in temp dir ──────────────────────────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/$SKILL_NAME"
cp "$SOURCE_MD" "$TMP_DIR/$SKILL_NAME/SKILL.md"

# ── Pack as .skill ─────────────────────────────────────────────────────────────
OUTPUT_FILE="./$SKILL_NAME.skill"

(cd "$TMP_DIR" && zip -q -r - "$SKILL_NAME/") > "$OUTPUT_FILE"

echo "Exported → $OUTPUT_FILE"