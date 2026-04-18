#!/usr/bin/env bash
# import-skill.sh — import a skill archive into prompt-vault
# Usage: ./import-skill.sh <path-to-archive>
#
# Supported formats:
#   *.skill / *.zip   — ZIP archive
#   *.tar.gz / *.tgz  — gzipped tar archive
#
# Output is always flat — one file in prompts/skills/:
#
#   Single-file skill (SKILL.md only):
#     → prompts/skills/<skill-name>.md      (SKILL.md copied as-is)
#
#   Multi-file skill (SKILL.md + extra files):
#     → prompts/skills/<skill-name>.md      (SKILL.md + all extra files appended)
#
#     Extra files are appended in path-sorted order under a markdown separator:
#       ---
#       <!-- reference: references/code-review.md -->
#       <file content>
#
# The flat layout keeps embeddings.json paths consistent and avoids
# breaking the generate_embeddings.py pipeline.

set -euo pipefail

SKILLS_DIR="./prompts/skills"

# ── Validate input ─────────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-archive>" >&2
  exit 1
fi

SKILL_FILE="$1"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "Error: file not found: $SKILL_FILE" >&2
  exit 1
fi

# ── Detect format and unpack ───────────────────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Unpacking: $SKILL_FILE"

case "$SKILL_FILE" in
  *.tar.gz|*.tgz)
    tar -xzf "$SKILL_FILE" -C "$TMP_DIR"
    ;;
  *.skill|*.zip)
    unzip -q "$SKILL_FILE" -d "$TMP_DIR"
    ;;
  *)
    # Fallback: sniff magic bytes
    if file "$SKILL_FILE" | grep -q "gzip"; then
      tar -xzf "$SKILL_FILE" -C "$TMP_DIR"
    elif file "$SKILL_FILE" | grep -q "Zip"; then
      unzip -q "$SKILL_FILE" -d "$TMP_DIR"
    else
      echo "Error: unrecognised archive format: $SKILL_FILE" >&2
      exit 1
    fi
    ;;
esac

# ── Find SKILL.md ──────────────────────────────────────────────────────────────
SKILL_MD=$(find "$TMP_DIR" -name "SKILL.md" | head -n 1)

if [[ -z "$SKILL_MD" ]]; then
  echo "Error: SKILL.md not found inside the archive." >&2
  exit 1
fi

echo "Found: $SKILL_MD"

# ── Extract name from YAML frontmatter ────────────────────────────────────────
SKILL_NAME=$(awk '/^---/{found++; next} found==1 && /^name:/{gsub(/^name:[[:space:]]+/, ""); print; exit}' "$SKILL_MD")

if [[ -z "$SKILL_NAME" ]]; then
  echo "Error: could not extract 'name' from YAML frontmatter in SKILL.md." >&2
  exit 1
fi

echo "Skill name: $SKILL_NAME"

# ── Collect extra files (everything except SKILL.md), sorted ──────────────────
SKILL_ROOT_IN_ZIP=$(dirname "$SKILL_MD")

mapfile -t EXTRA_FILES < <(
  find "$SKILL_ROOT_IN_ZIP" -type f ! -name "SKILL.md" | sort
)

# ── Build flat output file ─────────────────────────────────────────────────────
mkdir -p "$SKILLS_DIR"
TARGET_FILE="$SKILLS_DIR/$SKILL_NAME.md"

if [[ -f "$TARGET_FILE" ]]; then
  echo "Warning: $TARGET_FILE already exists — overwriting."
fi

# Start with SKILL.md content
cp "$SKILL_MD" "$TARGET_FILE"

# Append extra files if present
if [[ ${#EXTRA_FILES[@]} -gt 0 ]]; then
  echo "" >> "$TARGET_FILE"
  for EXTRA in "${EXTRA_FILES[@]}"; do
    REL_PATH="${EXTRA#"$SKILL_ROOT_IN_ZIP/"}"
    echo ""                              >> "$TARGET_FILE"
    echo "---"                           >> "$TARGET_FILE"
    echo "<!-- reference: $REL_PATH -->" >> "$TARGET_FILE"
    echo ""                              >> "$TARGET_FILE"
    cat "$EXTRA"                         >> "$TARGET_FILE"
  done
  echo "Appended ${#EXTRA_FILES[@]} reference file(s) → $TARGET_FILE"
else
  echo "Imported (single-file) → $TARGET_FILE"
fi