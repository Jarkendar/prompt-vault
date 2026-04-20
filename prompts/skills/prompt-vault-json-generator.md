---
name: prompt-vault-json-generator
description: Generate a prompt-vault-compatible JSON metadata file for any prompt (.md) or skill (.skill / .md with YAML frontmatter). Use this skill whenever the user asks to create a JSON for a prompt, skill, or wants to add something to prompt-vault — even if they just say "napisz jsona", "zrób json", "dodaj do prompt-vault", or drop a file without further explanation. Also trigger when the user pastes a SKILL.md frontmatter or a prompt file and hasn't provided a JSON yet.
---

# Prompt Vault JSON Generator

Generates a `<name>.json` metadata file that pairs with a `.md` prompt or skill file in the prompt-vault repo, so `generate_embeddings.py` can index it.

## Schema

Every JSON must exactly match this structure (see `references/schema.md` for field details and allowed values):

```json
{
  "title": "Human-readable title",
  "category": "<category>",
  "use_case": "<use_case>",
  "tags": ["tag1", "tag2"],
  "description": "What the prompt/skill does — 1-3 sentences.",
  "trigger_description": "When to use it — conditions, keywords, contexts. Empty string for non-skills.",
  "language": "en",
  "response_language": "en",
  "author": "jarkendar",
  "created": "<YYYY-MM-DD>",
  "version": "1.0.0",
  "tested_on": "claude-sonnet",
  "compatible_with": [],
  "additional_data": []
}
```

**Always set `author: "jarkendar"` and `created` to today's date.**

## Workflow

### 1. Identify the source

The user may provide:
- A `.skill` archive → unzip it (Python `zipfile`) and read `SKILL.md` frontmatter
- A `.md` file with YAML frontmatter → read frontmatter directly
- A `.md` file without frontmatter → treat as a prompt, infer metadata from content
- Pasted text → same as above

### 2. Determine category and use_case

Read `references/schema.md` for the full list. Quick rules:
- Skills → `category: "skills"`, `use_case: "skill"`
- Claude Project system prompts → `category: "claude-projects"`, `use_case: "claude-project"`
- Everything else → pick the closest `category` from the allowed list, `use_case: "workflow"` by default

### 3. Fill all fields

- **title**: from frontmatter `name` / first `# Heading` / inferred — capitalise properly
- **description**: synthesise from frontmatter `description` + first paragraph of body; keep it tight
- **trigger_description**: for skills, extract "when to use" from frontmatter `description` or the skill body; for prompts, leave as `""`
- **tags**: 5-10 lowercase kebab-case tags covering technology, domain, output format
- **response_language**: check whether the prompt instructs responses in Polish (`pl`) or English (`en`); default `en`
- **compatible_with**: `["claude", "aider"]` for skills; `[]` for prompts
- **additional_data**: array of `{placeholder, description, required}` objects for every `{{placeholder}}` in the prompt; empty array if none

### 4. Output

Print the JSON to the conversation **and** write it as a file named `<skill-or-prompt-name>.json` via `create_file` so the user can download it.

The filename must match the `.md` / `.skill` base name exactly (e.g. `kotlin-tdd.json` for `kotlin-tdd.md`).

### 5. Confirm ambiguities

If `response_language`, `category`, or `additional_data` placeholders are unclear, ask — one question at a time. Don't silently guess on fields that affect embeddings quality.

---

Read `references/schema.md` before generating any JSON to verify allowed values.


---
<!-- reference: references/schema.md -->

# Schema Reference

Full specification of every field in a prompt-vault JSON metadata file.

---

## Fields

### `title` (string, required)
Human-readable display name. Capitalise as a proper title.
- For skills: use the heading in SKILL.md body, or capitalise the `name` slug
- For prompts: use the frontmatter `title` field if present, else infer from the `# H1`

### `category` (string, required)
Allowed values:
| Value | When to use |
|---|---|
| `skills` | Claude skill files (.skill / SKILL.md) |
| `claude-projects` | System prompts for Claude Projects |
| `finance` | Financial analysis, trading, market data |
| `git` | Git workflows, commit messages, PRs |
| `learning` | Education, tutoring, course content |
| `productivity` | Task management, planning, summarisation |
| `travel` | Trip planning, destinations |
| `android` | Android-specific prompts not packaged as skills |

Add new categories only when none of the above fits.

### `use_case` (string, required)
Allowed values:
| Value | When to use |
|---|---|
| `skill` | Skill files |
| `claude-project` | Claude Project system prompts |
| `workflow` | Everything else (default) |

### `tags` (array of strings, required)
- 5–10 tags
- Lowercase, kebab-case: `json-output`, `tdd`, `android`
- Cover: technology stack, domain, output format, key tools

### `description` (string, required)
1–3 sentences. What the prompt/skill does, what it produces, what context it requires.
Do not repeat `title`. Do not start with "This prompt…".

### `trigger_description` (string, required)
- **Skills**: when to use the skill — copy/adapt from SKILL.md frontmatter `description`, or extract the "Use when…" / "Do NOT use…" clauses
- **Prompts**: empty string `""`

### `language` (string, required)
Language the prompt/skill instructions are written in. Almost always `"en"`.

### `response_language` (string, required)
Language the model is instructed to respond in.
- `"pl"` — if the prompt contains `odpowiadaj po polsku`, `in Polish`, or Polish-only output examples
- `"en"` — default

### `author` (string, required)
Always `"jarkendar"`.

### `created` (string, required)
ISO date: `"YYYY-MM-DD"`. Use today's date when generating a new JSON.

### `version` (string, required)
Semantic version. Default `"1.0.0"` for new files.

### `tested_on` (string, required)
Model the prompt was validated on. Use `"claude-sonnet"` unless the user specifies otherwise.

### `compatible_with` (array of strings, required)
- Skills: `["claude", "aider"]`
- Prompts: `[]`

### `additional_data` (array of objects, required)
One object per `{{placeholder}}` found in the prompt body:
```json
{
  "placeholder": "current_date",
  "description": "Today's date in YYYY-MM-DD format.",
  "required": true
}
```
Empty array `[]` if the prompt has no placeholders.
