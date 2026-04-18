#!/usr/bin/env bash
# export-skill.sh — export a skill from prompt-vault to a Claude-compatible .skill file
# Usage: ./export-skill.sh <path-to-skill-dir-or-md>
#
# Accepts two input forms:
#   1. A directory:  prompts/skills/kotlin-tdd/
#      Must contain SKILL.md (with YAML frontmatter) plus any extra files.
#   2. A single .md file:  prompts/skills/kotlin-tdd/kotlin-tdd.md  (legacy)
#      Treated as SKILL.md; no extra files are bundled.
#
# Output: ./<skill-name>.skill  (ZIP with a single top-level folder inside)

set -euo pipefail

# ── Validate input ─────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-skill-dir-or-md>" >&2
  exit 1
fi

INPUT="$1"

# ── Resolve source directory and canonical SKILL.md ───────────────────────────
if [[ -d "$INPUT" ]]; then
  # Directory mode — expect SKILL.md inside
  SOURCE_DIR="$INPUT"
  SKILL_MD="$SOURCE_DIR/SKILL.md"
  if [[ ! -f "$SKILL_MD" ]]; then
    echo "Error: SKILL.md not found in directory: $SOURCE_DIR" >&2
    exit 1
  fi
elif [[ -f "$INPUT" ]]; then
  # Legacy single-file mode — treat the .md as SKILL.md, no extra files
  SOURCE_DIR=""
  SKILL_MD="$INPUT"
else
  echo "Error: not found: $INPUT" >&2
  exit 1
fi

# ── Extract name from YAML frontmatter ────────────────────────────────────────
SKILL_NAME=$(awk '/^---/{found++; next} found==1 && /^name:/{gsub(/^name:[[:space:]]+/, ""); print; exit}' "$SKILL_MD")

if [[ -z "$SKILL_NAME" ]]; then
  echo "Error: could not extract 'name' from YAML frontmatter in SKILL.md." >&2
  exit 1
fi

echo "Skill name: $SKILL_NAME"

# ── Build in temp dir ──────────────────────────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -n "$SOURCE_DIR" ]]; then
  # Directory mode — copy entire skill folder preserving structure
  cp -r "$SOURCE_DIR/." "$TMP_DIR/$SKILL_NAME/"
  # Ensure the root entry is named after the skill (source dir name may differ)
else
  # Legacy single-file mode — bundle just SKILL.md
  mkdir -p "$TMP_DIR/$SKILL_NAME"
  cp "$SKILL_MD" "$TMP_DIR/$SKILL_NAME/SKILL.md"
fi

# ── Pack as .skill ─────────────────────────────────────────────────────────────
OUTPUT_FILE="./$SKILL_NAME.skill"

(cd "$TMP_DIR" && zip -q -r - "$SKILL_NAME/") > "$OUTPUT_FILE"

# ── Summary ────────────────────────────────────────────────────────────────────
FILE_COUNT=$(cd "$TMP_DIR" && find "$SKILL_NAME" -type f | wc -l | tr -d ' ')
echo "Bundled $FILE_COUNT file(s) → $OUTPUT_FILE"