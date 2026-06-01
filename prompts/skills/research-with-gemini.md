---
name: research-with-gemini
description: >-
  Offload a WIDE or context-expensive research task to Google Antigravity CLI
  (agy / Gemini models) and read back a structured digest, instead of spending
  Claude Code's own context on it. Supports shallow (quick fact) and deep
  (multi-faceted research) modes, parallel sub-query execution, and configurable
  output language. Use whenever you'd otherwise read many files to orient
  yourself, do open-web research, or condense a large document — e.g.
  "zmapuj ten moduł", "rozeznaj jak się to teraz robi", "przeszukaj repo pod
  kątem X", "streść tę dokumentację", "map this module", "research the current
  approach for X", "what changed in this changelog". Covers repo orientation,
  grounded web research, and digesting big docs.
  Do NOT use for a single known file or a one-line fact you can get directly —
  read that yourself.
---

# research-with-gemini

Delegate the *wide* part of a task to Antigravity CLI (`agy`) so it doesn't eat
our context window. `agy` runs Gemini models with a large context window and
Google Search grounding; it does the broad reading/searching and returns a
structured digest. We stay the orchestrator and the one that writes code.

This skill is Linux/macOS only (Pi5, dev box). Windows is out of scope for now —
`agy -p` has a broken-stdout bug there and we rely on stdout redirection.

## When to use vs. skip

This is a **cost/context optimization, not a new capability** — Claude Code
already has web search, file search, and subagents.

- **Use** when answering means reading 5+ files, open-web research with
  citations, or condensing a large document.
- **Skip** for a single known file, a quick grep, or a fact we already know.
  Delegating those just adds latency.

## Parameters to decide before running

| Parameter | Options | When to pick |
|---|---|---|
| `MODE` | `web`, `repo`, `docs` | web = open internet; repo = codebase files; docs = specific document(s) |
| `DEPTH` | `shallow`, `deep` | shallow = one focused question (~350 words, timeout 5m); deep = multi-faceted topic (~1000 words, tables, timeout 15m) |
| `MULTI` | yes / no | yes = topic has 2–3 clearly separable sub-questions → run `agy` in parallel per sub-query |
| `LANG` | any natural language name | match the user's language (e.g. `Polish`, `English`); default to the language of the user's request |
| `SLUG` | short kebab-case | used for output filenames |

### Decision guide

```
Is the query a single focused fact or question?
  YES → shallow, single query
  NO  → deep
        Does the topic have 2–3 clearly separable sub-topics?
          YES → deep + multi (parallel agy calls)
          NO  → deep, single query
```

---

## Workflow — single query (MULTI = no)

1. Decide MODE, DEPTH, LANG, SLUG. Set timeout: `5m` for shallow, `15m` for deep.
2. Build the prompt from the template below (pick shallow or deep output contract).
3. Run setup + `agy`:

```bash
mkdir -p research
grep -qxF "research/" .gitignore 2>/dev/null || echo "research/" >> .gitignore
agy -p "<PROMPT>" --dangerously-skip-permissions --print-timeout <TIMEOUT> \
  [--add-dir <PATH>]... \
  > research/<SLUG>.md
```

4. Validate: `[ -s research/<SLUG>.md ] && grep -q "^---" research/<SLUG>.md || echo "FAILED"`
   If empty or off-format, retry **once**. If it fails again, tell the user — do not proceed on guesses.
5. Read `research/<SLUG>.md`, extract what you need, continue the actual work yourself.

## Workflow — parallel sub-queries (MULTI = yes)

1. Decompose the topic into 2–3 focused sub-queries. Name slugs `<SLUG>-1`, `<SLUG>-2`, etc.
2. Build one prompt per sub-query (same template, DEPTH=deep, fill all variables).
3. Run setup + all `agy` calls in parallel + validate:

```bash
mkdir -p research
grep -qxF "research/" .gitignore 2>/dev/null || echo "research/" >> .gitignore

agy -p "<PROMPT_1>" --dangerously-skip-permissions --print-timeout 15m > research/<SLUG>-1.md &
agy -p "<PROMPT_2>" --dangerously-skip-permissions --print-timeout 15m > research/<SLUG>-2.md &
agy -p "<PROMPT_3>" --dangerously-skip-permissions --print-timeout 15m > research/<SLUG>-3.md &
wait

# validate — print any file that is empty or missing frontmatter
for f in research/<SLUG>-*.md; do
  { [ -s "$f" ] && grep -q "^---" "$f"; } || echo "FAILED: $f"
done
```

4. If validation prints a FAILED line, retry that specific sub-query once.
5. Read all output files and synthesize the results yourself.

---

## The prompt template

Compose `<PROMPT>` as **lead + output contract**.

**Lead — pick one by mode:**

- `web`: "Research the following topic on the web using Google Search grounding.
  Prioritize current primary sources (official docs, release notes, maintainer
  posts) over blogs/aggregators. Topic: \<QUERY\>"
- `repo`: "Explore the project files in the workspace and answer the question.
  Map only what's relevant; read files as needed but do NOT modify any file.
  Question: \<QUERY\>"
- `docs`: "Read the document(s) in the workspace and condense/answer the request.
  Extract only what's relevant to us. Request: \<QUERY\>"

---

### Output contract — SHALLOW (`DEPTH=shallow`, timeout=5m)

```
Return ONLY the Markdown below, starting at the very FIRST character with the
front-matter block. No preamble, no explanation of your process, no code fences.

---
mode: <MODE>
query: "<QUERY>"
generated_at: <TODAY as YYYY-MM-DD>
paths: [<comma-separated PATHS, or leave empty for web>]
---

# <short descriptive title>

## TL;DR
- Up to 5 bullets. The essential answer, no filler.

## Key references
- <web: source title + URL + one-line takeaway> / <repo & docs: file path or section + one-line role>

## Details
Concrete and dense. Max 200 words.

## Open questions / risks
Anything uncertain or worth verifying. Write "None" if nothing.

Rules:
- Write in <LANG>.
- Keep the whole file under ~350 words.
- Fill the front-matter values exactly as given above; do not invent others.
```

---

### Output contract — DEEP (`DEPTH=deep`, timeout=15m)

```
Return ONLY the Markdown below, starting at the very FIRST character with the
front-matter block. No preamble, no explanation of your process, no code fences.

---
mode: <MODE>
query: "<QUERY>"
generated_at: <TODAY as YYYY-MM-DD>
paths: [<comma-separated PATHS, or leave empty for web>]
---

# <short descriptive title>

## TL;DR
- Up to 7 bullets. Prioritize concrete facts, numbers, and names — no filler.

## Key references
- <web: source title + URL + one-line takeaway> / <repo & docs: file path or section + one-line role>
- Include at least 5 references.

## Details

Use ### sub-sections for distinct facets of the topic. Include tables where data
is comparative or numerical. Be concrete: numbers, versions, names, dates.
No filler sentences. Target 500–700 words for this section.

## Open questions / risks
Anything uncertain or worth verifying. Write "None" if nothing.

Rules:
- Write in <LANG>.
- Keep the whole file under ~1000 words.
- Fill the front-matter values exactly as given above; do not invent others.
```

Fill `<MODE>`, `<QUERY>`, `<TODAY>`, `<PATHS>`, and `<LANG>` with literal values
before sending, so `agy` only transcribes them rather than guessing.

---

## Model choice (optional)

The command passes no `--model` (print mode doesn't reliably accept one). Set the
default in `agy` settings instead: a Flash-tier model for shallow/cheap work,
a Pro-tier model for deep web research.

---

## Worked examples

### Example 1 — shallow, single query (repo mode)

```bash
mkdir -p research
grep -qxF "research/" .gitignore 2>/dev/null || echo "research/" >> .gitignore

agy -p "Explore the project files in the workspace and answer the question. Map only what's relevant; read files as needed but do NOT modify any file. Question: map the :feature:gallery module — key files, their responsibilities, and the public entry points.

Return ONLY the Markdown below, starting at the very FIRST character with the front-matter block. No preamble, no explanation of your process, no code fences.

---
mode: repo
query: \"map the :feature:gallery module — key files, responsibilities, entry points\"
generated_at: 2026-06-01
paths: [.]
---

# <short descriptive title>

## TL;DR
- Up to 5 bullets. The essential answer, no filler.

## Key references
- file path + one-line role

## Details
Concrete and dense. Max 200 words.

## Open questions / risks
Anything uncertain or worth verifying. Write \"None\" if nothing.

Rules:
- Write in English.
- Keep the whole file under ~350 words.
- Fill the front-matter values exactly as given above; do not invent others." \
  --dangerously-skip-permissions --print-timeout 5m --add-dir . \
  > research/map-gallery-module.md

[ -s research/map-gallery-module.md ] && grep -q "^---" research/map-gallery-module.md \
  || echo "FAILED: research/map-gallery-module.md"
```

---

### Example 2 — deep + multi, parallel (web mode)

Decompose the topic into 3 sub-queries, build each prompt using the DEEP output
contract above, then run in parallel:

```bash
mkdir -p research
grep -qxF "research/" .gitignore 2>/dev/null || echo "research/" >> .gitignore

# Build PROMPT_1, PROMPT_2, PROMPT_3 from the DEEP output contract.
# Each gets its own lead (web/repo/docs) + filled variables (MODE, QUERY, TODAY, LANG).

agy -p "<PROMPT_1>" --dangerously-skip-permissions --print-timeout 15m > research/<SLUG>-1.md &
agy -p "<PROMPT_2>" --dangerously-skip-permissions --print-timeout 15m > research/<SLUG>-2.md &
agy -p "<PROMPT_3>" --dangerously-skip-permissions --print-timeout 15m > research/<SLUG>-3.md &
wait

for f in research/<SLUG>-*.md; do
  { [ -s "$f" ] && grep -q "^---" "$f"; } || echo "FAILED: $f"
done
```

Read each output file; synthesize into a final answer yourself.