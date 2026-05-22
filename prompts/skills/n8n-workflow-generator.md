---
name: n8n-workflow-generator
description: >-
  Generate complete, importable n8n workflow JSON files from free-text descriptions of trigger, internal logic, and output. Use this skill whenever the user asks for an n8n workflow, automation, flow, or module — including casual phrases like 'zrób workflow w n8n', 'stwórz flow n8n', 'wygeneruj automatyzację', 'automatyzacja n8n', 'create n8n workflow', 'build n8n automation', or 'make me an n8n flow'. Always trigger when the user describes a multi-step automation involving triggers (schedule, telegram, webhook, called-from-another-flow), AI agents, HTTP calls, data transformations, email/telegram outputs, or Google Sheets/Notion operations — even if they do not say n8n but the context is clear (e.g., a pi-automate discussion). Outputs two files; a workflow JSON importable into n8n 2.13.2+ and a companion markdown with required env vars, credentials, prompts to write, and a brief README. Do NOT just describe the flow in prose — always generate the actual JSON file.
---

# n8n Workflow Generator

Turn a free-text description of an automation into a complete, validated n8n workflow JSON ready to import into the user's self-hosted n8n (Raspberry Pi `pi-automate` stack, version 2.13.2+) — plus a companion markdown with everything the user needs to wire up after import.

---

## How to Use

The user describes their flow in three implicit sections (free-form prose, **not** a strict template):

- **Trigger** — when the flow fires (schedule, telegram message, webhook, executed-as-module)
- **Logic** — what happens inside (HTTP calls, LLM agents, data transforms, branching, persistence)
- **Output** — where the result goes (email, telegram, Google Sheets, Notion, return to parent module)

Read the description, extract the three sections, and ask **once** if any is critically ambiguous. Otherwise proceed straight to generation. Surface non-trivial assumptions in the companion `.md` rather than asking — user prefers minimal back-and-forth.

For deep node parameter shapes consult `references/node-catalog.md`. For recurring patterns (prompt-vault triad, telegram-with-callback, module skeleton, switch routing, retry) consult `references/patterns.md`. For the email HTML template see `references/email-template.html`. For the validation algorithm see `references/validation.md`.

---

## Output Contract

Two files in `/mnt/user-data/outputs/`, presented via `present_files` (JSON first):

1. **`<workflow_name>.json`** — drop-in import into n8n 2.13.2+
2. **`<workflow_name>.md`** — companion doc in Polish (format below)

`<workflow_name>` is `snake_case`, inferred from the description (e.g., "daily weather reporter" → `daily_weather_reporter`).

---

## High-Level Rules

### Naming
- Workflow `name`: `snake_case`, descriptive of purpose
- Node `name`: `Title Case` (`Get Prompt`, `Send Daily Report`, `Anthropic Chat Model`)
- Variables in `code` nodes: English identifiers, comments in English
- All user-facing strings (email body, telegram messages, MD): Polish

### IDs (UUIDs)
- Every `node.id` → fresh UUIDv4 (generate per node)
- Every `webhookId` (on `telegramTrigger`, `telegram`, `emailSend`, `webhook`) → fresh UUIDv4
- Every `id` inside switch/if condition arrays → fresh UUIDv4
- Top-level `versionId`, `id`, `meta.instanceId`, `meta.templateCredsSetupCompleted` → **omit** (n8n assigns on import)

### Credentials — placeholder strategy

**Never hardcode any credential ID.** Every credential reference uses:

```
__REPLACE_<TYPE>_ID__
```

If a workflow uses multiple credentials of the same type (e.g., two Telegram bots), disambiguate with a purpose suffix:

```
__REPLACE_<TYPE>_<PURPOSE>_ID__
```

Examples: `__REPLACE_SMTP_ID__`, `__REPLACE_ANTHROPIC_ID__`, `__REPLACE_TELEGRAM_TRAINER_ID__`, `__REPLACE_TELEGRAM_IDEAS_ID__`, `__REPLACE_NOTION_ID__`, `__REPLACE_GOOGLE_SHEETS_ID__`, `__REPLACE_GOOGLE_GEMINI_ID__`.

The `name` field next to the placeholder ID stays human-readable so the user recognizes it during wiring:

```json
"credentials": {
  "smtp": {
    "id": "__REPLACE_SMTP_ID__",
    "name": "SMTP account"
  }
}
```

**Every placeholder MUST be listed in the companion `.md`** — which node uses it, what credential type to plug in.

### Environment variables

- Always referenced inline as `{{ $env.VAR_NAME }}` (these are real n8n env vars, not placeholders)
- Naming: `UPPER_SNAKE_CASE`
- Every env var used MUST be listed in the companion `.md` with description + a sensible default suggestion

### Prompt placeholders

When a node fetches a system prompt (prompt-vault pattern), the URL is a placeholder:

```
__REPLACE_PROMPT_URL__
```

When the workflow uses multiple prompts:

```
__REPLACE_PROMPT_<NAME>_URL__
```

(e.g., `__REPLACE_PROMPT_CLASSIFIER_URL__`, `__REPLACE_PROMPT_GENERATOR_URL__`)

Each prompt placeholder gets its own entry in the MD with: what the prompt should do, suggested path in `prompt-vault`, and the output parser schema (if structured output is used).

### Settings — exactly this shape, always

```json
"settings": {
  "executionOrder": "v1",
  "binaryMode": "separate",
  "timezone": "Europe/Warsaw",
  "availableInMCP": false
}
```

If the workflow is a callable module, add: `"callerPolicy": "workflowsFromSameOwner"`.

### Layout

Horizontal left-to-right. Main flow: `x += 200` per node, starting from leftmost trigger. AI helper nodes for an Agent (`lmChat*`, `outputParser*`) sit **directly under** the Agent at `y + 200`. Branching nodes spread Y by `±200` per output.

---

## TypeVersions — locked to n8n 2.13.2

| Node type | typeVersion |
|---|---|
| `n8n-nodes-base.scheduleTrigger` | `1.3` |
| `n8n-nodes-base.telegramTrigger` | `1.2` |
| `n8n-nodes-base.telegram` | `1.2` |
| `n8n-nodes-base.executeWorkflowTrigger` | `1.1` |
| `n8n-nodes-base.webhook` | `2` |
| `n8n-nodes-base.manualTrigger` | `1` |
| `n8n-nodes-base.httpRequest` | `4.4` |
| `n8n-nodes-base.code` | `2` |
| `n8n-nodes-base.set` | `3.4` |
| `n8n-nodes-base.switch` | `3.4` |
| `n8n-nodes-base.if` | `2.3` |
| `n8n-nodes-base.merge` | `3.1` |
| `n8n-nodes-base.wait` | `1.1` |
| `n8n-nodes-base.emailSend` | `2.1` |
| `n8n-nodes-base.googleSheets` | `4.7` |
| `n8n-nodes-base.notion` | `2.2` |
| `@n8n/n8n-nodes-langchain.agent` | `3.1` |
| `@n8n/n8n-nodes-langchain.lmChatAnthropic` | `1.3` |
| `@n8n/n8n-nodes-langchain.googleGemini` | `1.1` |
| `@n8n/n8n-nodes-langchain.outputParserStructured` | `1.3` |

For parameter shapes per node, see `references/node-catalog.md`.

---

## Pattern Detection — apply automatically

When the description matches one of these patterns, apply without asking:

### 1. Prompt-vault AI triad
**Trigger phrase**: any mention of an LLM/agent that needs a system prompt.

Inject this trio:

```
Get Prompt (httpRequest, GET __REPLACE_PROMPT_URL__)
  → Replacer (code, JS, swaps placeholders like <current_date>, <city>)
  → Agent (langchain.agent, with Anthropic + Structured Output Parser helpers)
```

Default LLM: `claude-sonnet-4-5-20250929` via `@n8n/n8n-nodes-langchain.lmChatAnthropic`, `temperature: 0.7`. If user names another model/provider, honor it.

Default to including a Structured Output Parser when the agent's output will be consumed programmatically. Generate a reasonable JSON schema from the description and flag it as an assumption in the MD.

Full node template: `references/patterns.md` § "Prompt-vault triad".

### 2. Telegram bot with text + voice + callbacks
**Trigger phrase**: user describes a Telegram bot handling messages and/or button presses.

Inject:

```
Telegram Trigger (with updates: ["message", "callback_query"])
  → Switch (message vs button_click)
    → [message] Switch (text vs voice)
       → [voice] Download voice → STT → Set text
       → [text] Set text
    → [callback_query] handle action by data field
```

For STT, default to calling the user's existing `module_STT_on_local_whisper` via `executeWorkflow` (don't re-implement the speaches HTTP call inline). The MD notes this assumption.

Full template: `references/patterns.md` § "Telegram with callbacks".

### 3. Module (callable workflow)
**Trigger phrase**: "moduł", "module", "wywoływany z innego flow", "callable", or the description frames input/output as data interchange.

Shape:
- Trigger = `executeWorkflowTrigger` with declared `workflowInputs.values` schema
- Last node returns data via `set` (no email/telegram unless explicitly requested)
- `settings.callerPolicy: "workflowsFromSameOwner"`

Full template: `references/patterns.md` § "Module shape".

### 4. Email output
**Trigger phrase**: "wyślij maila", "send email", "report", "raport", "newsletter", "podsumowanie".

Use the **full HTML template** from `references/email-template.html` adapted to the content. Default style: dark gradient header, body cards (color-coded per category if items have a type field), tag pills, footer with stack/source meta. Subject line: emoji + workflow theme + date.

If content is single-block prose (no list of items), use the simpler variant from `references/email-template.html` § "Simple variant".

### 5. Schedule trigger
**Trigger phrase**: anything periodic ("codziennie", "co tydzień", "every morning", cron-like).

Map natural language:
- "codziennie o 7" → `triggerAtHour: 7`
- "co tydzień (w sobotę o 8)" → `field: "weeks", triggerAtHour: 8, triggerAtDay: [6]`
- "co X minut" → `field: "minutes", minutesInterval: X`

If only frequency is given (e.g., "codziennie"), default hour to **7** (matches user's existing daily flows).

---

## Tags — auto-assign

Populate `tags` based on what's in the flow. Use existing tag names where they match. Tag IDs stay empty strings — n8n resolves by name on import:

| If workflow contains... | Add tag |
|---|---|
| `emailSend` node | `mail` |
| any `langchain.*` node | `AI` |
| `telegramTrigger` or `telegram` | `telegram` |
| HTTP to whisper / STT module | `whisper` |
| `notion` node | `notion` |
| `googleSheets` node | `sheets` |
| trigger = `executeWorkflowTrigger` | `module` |
| theme: "idea"/"pomysł" | `ideas` |
| theme: "trip"/"podróż"/"wycieczka" | `trip` |
| theme: "shares"/"akcje"/"giełda" | `shares` |

Feel free to add new descriptive tags when a workflow has a clear theme not covered above (e.g., `birds`, `running`, `weather`, `homelab`). Match user's style: lowercase, short, single word.

Tag JSON shape:
```json
"tags": [
  { "id": "", "name": "mail", "createdAt": "", "updatedAt": "" }
]
```

---

## Validation — run before writing the file

Assemble the JSON in memory first. Run these checks. If any fail, fix and re-validate. Full algorithm: `references/validation.md`.

**Hard requirements (fail-fast):**

1. Every `node.id` is a unique UUIDv4
2. Every entry in `connections` references an existing `node.name` (both as the outer key and inside each `node` field)
3. Every `typeVersion` matches the table above
4. Every `langchain.agent` has both an `ai_languageModel` and (when structured output is used) an `ai_outputParser` helper wired via the `connections` block
5. Workflow has at least one trigger node
6. No orphan main-flow nodes (every non-trigger main node has at least one incoming `main` connection)
7. Every credential reference is a placeholder of the documented form (no hardcoded IDs)
8. Every env var reference uses `{{ $env.* }}` syntax
9. `settings` matches the defaults exactly
10. Branching nodes (`switch`, `if`) — every output index used in `connections` exists in the node config

**After fix-up**, write the file. Note non-trivial assumptions in the MD's *Założenia* section.

---

## Companion Markdown Format

`<workflow_name>.md`, fully in Polish. Skip any section that doesn't apply:

```markdown
# <workflow_name>

<jedno-dwa zdania: co flow robi i jak jest wyzwalany>

---

## 🔌 Credentials do podłączenia

Po imporcie do n8n każdy placeholder credential musi zostać podmieniony na ID prawdziwego credentiala.

| Placeholder | Typ w n8n | Używany w node | Cel |
|---|---|---|---|
| `__REPLACE_SMTP_ID__` | SMTP account | `Send Report` | wysyłka maili |
| `__REPLACE_ANTHROPIC_ID__` | Anthropic API | `Anthropic Chat Model` | LLM |

**Jak podmienić**: w `.json` znajdź każdy placeholder i zamień na ID istniejącego credentiala (n8n → *Credentials* → kliknij credential → ID w URL).

---

## 🌍 Environment variables

Ustaw w `.env` n8n przed pierwszym runem:

| Variable | Opis | Sugerowana wartość |
|---|---|---|
| `N8N_AGENT_EMAIL_FROM` | adres nadawcy maili z tego flow | `n8n@example.com` |
| `WEATHER_API_KEY` | klucz do OpenWeather | `<twój klucz>` |

---

## 📝 Prompty do napisania

Workflow używa <N> systemowych promptów ściąganych z `github.com/Jarkendar/prompt-vault`. Napisz je, wrzuć do repo, podmień URL w `.json`.

### Prompt 1: `__REPLACE_PROMPT_URL__`
- **Cel**: <co prompt ma robić>
- **Używany w node**: `Get Prompt`
- **Sugerowana ścieżka w prompt-vault**: `prompts/<category>/<slug>.md`
- **Placeholdery w promptcie**: `<current_date>`, `<city>` (zamieniane w `Replacer`)
- **Output parser JSON schema** (już wstawiony do `Structured Output Parser`):

```json
<schema>
```

---

## 🚀 Import i aktywacja

1. n8n → *Workflows* → *Import from File* → `<workflow_name>.json`
2. Podmień placeholdery credentials (tabelka wyżej)
3. Ustaw env vars w `.env` (tabelka wyżej)
4. Napisz prompty, wrzuć do prompt-vault, podmień `__REPLACE_PROMPT_*_URL__` w `.json` lub bezpośrednio w n8n
5. Aktywuj workflow

---

## ⚙️ Założenia / uwagi

<lista nietrywialnych decyzji — np. "domyślnie strukturalny output JSON; jeśli nie potrzebujesz, usuń Structured Output Parser z flow">
```

---

## Generation Algorithm — step-by-step

1. **Parse** description, extract Trigger / Logic / Output. Ask once if critically ambiguous.
2. **Plan** node list. Apply pattern detection above.
3. **Build** each node: type, version, params, fresh UUID, position. Deep parameter shapes → `references/node-catalog.md`.
4. **Wire** `connections` — main flow + AI helper connections (`ai_languageModel`, `ai_outputParser`).
5. **Tag** auto-detection.
6. **Settings** — fixed defaults.
7. **Validate** — full checklist. Fix. Re-validate.
8. **Write JSON** to `/mnt/user-data/outputs/<workflow_name>.json`.
9. **Write MD** to `/mnt/user-data/outputs/<workflow_name>.md`.
10. **Present** via `present_files` (JSON first).

---

## Example Invocation

User says:

> "Codzienny flow o 7 rano: ściąga aktualną pogodę dla Poznania z openweather, LLM (Claude) generuje krótki dowcip o pogodzie, wysyła to mailem na adres z env-a. Output JSON z polami `joke` i `weather_summary`."

Skill produces:

**`daily_weather_joke.json`** — nodes:
`Schedule Trigger (7:00)` → `Get Weather (httpRequest, openweather)` → `Get Prompt (httpRequest, __REPLACE_PROMPT_URL__)` → `Replacer (code, JS)` → `Joke Generator (langchain.agent + Anthropic Chat Model + Structured Output Parser)` → `Send Joke (emailSend, full HTML)`. Tags: `mail`, `AI`, `weather`.

**`daily_weather_joke.md`** — credentials (`__REPLACE_SMTP_ID__`, `__REPLACE_ANTHROPIC_ID__`), env vars (`N8N_AGENT_EMAIL_FROM`, `WEATHER_TO_EMAIL`, `OPENWEATHER_API_KEY`, `WEATHER_CITY`), prompt to write (suggested path `prompts/fun/weather-joke.md`, schema with `joke` + `weather_summary` fields).


---
<!-- reference: references/email-template.html -->

<!--
Email HTML template — Jarek's style.

Two variants:
1. **Categorized cards** — for workflows producing N items grouped by type
   (e.g., ideas generator, trip planner, daily report). Each item gets a card
   with a colored left-border based on a category field.
2. **Simple body** — for workflows producing single-block prose
   (e.g., a single summary, a single recommendation).

When using these in n8n's `emailSend.html` field, the whole string is prefixed
with `=` (n8n expression syntax) and any `{{ ... }}` resolves at runtime.

JS-in-template (the `${...}` and `.map().join('')` constructs below) only works
because n8n evaluates the whole expression — you're inside `={{ }}` already.

Adapt:
- Header gradient: pick two related colors (dark base → mid accent)
- Header emoji + title: workflow theme
- Card border color: per category, signal urgency/type
- Body card fields: match the output parser schema
- Footer meta: list of tech stack used + a short tagline
-->

<!-- ========================================================================
     VARIANT 1: CATEGORIZED CARDS
     ========================================================================
     For: workflows outputting `{ items: [{ title, description, tags, type }] }`
     Iterate over $json.output.items using .map().join('')
-->

<div style="font-family: 'Segoe UI', Arial, sans-serif; background-color: #f4f7f9; padding: 40px 20px;">
  <div style="max-width: 650px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">

    <!-- HEADER -->
    <div style="background: linear-gradient(135deg, #2c3e50 0%, #000000 100%); color: #ffffff; padding: 30px; text-align: center;">
      <h1 style="margin: 0; font-size: 24px; letter-spacing: 1px;">🚀 WORKFLOW THEME</h1>
      <p style="margin: 5px 0 0; opacity: 0.7; font-size: 14px;">{{ $now.format('dd.MM.yyyy') }} | Subtitle</p>
    </div>

    <!-- BODY -->
    <div style="padding: 30px;">

      {{ $json.output.items.map(item => `
      <div style="margin-bottom: 40px; border-left: 5px solid ${
        item.type === 'urgent' ? '#e74c3c' :
        item.type === 'normal' ? '#2ecc71' :
        item.type === 'info'   ? '#f39c12' : '#8e44ad'
      }; padding-left: 20px;">

        <div style="display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 10px; font-weight: bold; text-transform: uppercase; background-color: #f4f6f7; color: ${
          item.type === 'urgent' ? '#e74c3c' :
          item.type === 'normal' ? '#2ecc71' :
          item.type === 'info'   ? '#f39c12' : '#8e44ad'
        }; margin-bottom: 10px;">
          ${
            item.type === 'urgent' ? '🚩 Pilne' :
            item.type === 'normal' ? '⚡ Zwykłe' :
            item.type === 'info'   ? 'ℹ️ Info'  : '📌 Inne'
          }
        </div>

        <h2 style="margin: 0 0 10px 0; color: #2c3e50; font-size: 20px;">${item.title}</h2>
        <p style="color: #546e7a; line-height: 1.6; margin: 0 0 15px 0; font-size: 15px;">
          ${item.description}
        </p>

        <div style="margin-top: 15px;">
          ${item.tags && Array.isArray(item.tags) ? item.tags.map(tag => `<span style="display: inline-block; background-color: #f1f5f9; color: #475569; padding: 5px 12px; border-radius: 15px; font-size: 12px; font-weight: 600; margin-right: 8px; margin-bottom: 8px; border: 1px solid #e2e8f0; text-transform: lowercase;">#${tag}</span>`).join('') : ''}
        </div>
      </div>
      `).join('') }}

    </div>

    <!-- FOOTER -->
    <div style="background-color: #fcfcfc; padding: 20px; text-align: center; border-top: 1px solid #eeeeee;">
      <p style="margin: 0; font-size: 12px; color: #90a4ae;">
        Stack: <tech-stack-list><br>
        <tagline>
      </p>
    </div>
  </div>
</div>


<!-- ========================================================================
     VARIANT 2: SIMPLE BODY
     ========================================================================
     For: workflows outputting a single result with a few fields,
     e.g. { goal, action_plan: [...], total_time, comment }
-->

<div style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; padding: 20px; border-radius: 8px;">

  <h2 style="color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px;">
    🎯 {{ $json.output.title }}
  </h2>

  <p style="line-height: 1.6; font-size: 15px; color: #455a64;">
    {{ $json.output.body }}
  </p>

  <!-- Optional: list inside the body -->
  <h3 style="color: #2980b9; margin-top: 20px;">🛠 Steps:</h3>
  <ul style="line-height: 1.6; font-size: 16px;">
    {{ $json.output.steps.map(s => '<li style="margin-bottom: 8px;">' + s + '</li>').join('') }}
  </ul>

  <!-- Optional: highlighted summary box -->
  <div style="background-color: #f8f9fa; padding: 15px; border-radius: 6px; margin-top: 25px;">
    <p style="margin: 0; font-size: 16px;">
      ⏳ <strong>Szacowany czas:</strong> <span style="color: #d35400; font-weight: bold;">{{ $json.output.total_time }}</span>
    </p>
  </div>

  <!-- Optional: footer comment -->
  <div style="margin-top: 25px; padding-top: 15px; border-top: 1px dashed #ccc;">
    <p style="margin: 0; font-size: 14px; color: #7f8c8d;">
      👨‍💻 <strong>Komentarz:</strong><br>
      <em>{{ $json.output.comment }}</em>
    </p>
  </div>

</div>


<!-- ========================================================================
     COLOR PALETTE — pick gradient pairs per theme
     ========================================================================
     dark/tech:     #2c3e50 → #000000
     navy/blue:     #1e3c72 → #2a5298   (used in trip generator)
     emerald:       #134e5e → #71b280
     sunset:        #e65c00 → #f9d423
     midnight:      #232526 → #414345
     plum:          #6a3093 → #a044ff

     CATEGORY BORDER COLORS — use for left-border of cards by type
     red/urgent:    #e74c3c
     green/safe:    #2ecc71
     orange/info:   #f39c12
     purple/other:  #8e44ad
     blue/calm:     #3498db
-->


<!-- ========================================================================
     SUBJECT LINE CONVENTIONS
     ========================================================================
     Always starts with `=` (n8n expression), has an emoji, theme, date.
     Examples from user's existing flows:
       =💡 [Tech Forge] 4 Nowe Pomysły na {{ $now.format('dd.MM.yyyy') }}
       =🗺️ Podróżnicze inspiracje (Baza: {{ city }}) | {{ $now.format('dd.MM.yyyy') }}
       =🚀 Action Plan: {{ $json.output.goal }}
       =📊 [Daily Report] {{ $now.format('dd.MM.yyyy') }}
-->

---
<!-- reference: references/node-catalog.md -->

# Node Catalog — n8n 2.13.2

Reference for parameter shapes per node type. Use when building each node. All shapes are validated against actual user workflows.

---

## Triggers

### `n8n-nodes-base.scheduleTrigger` — `typeVersion: 1.3`

Daily at fixed hour:
```json
{
  "parameters": {
    "rule": {
      "interval": [
        { "triggerAtHour": 7 }
      ]
    }
  },
  "type": "n8n-nodes-base.scheduleTrigger",
  "typeVersion": 1.3,
  "position": [-300, 0],
  "id": "<UUID>",
  "name": "Schedule Trigger"
}
```

Weekly:
```json
"rule": { "interval": [{ "field": "weeks", "triggerAtHour": 7 }] }
```

Every N minutes:
```json
"rule": { "interval": [{ "field": "minutes", "minutesInterval": 30 }] }
```

### `n8n-nodes-base.telegramTrigger` — `typeVersion: 1.2`

```json
{
  "parameters": {
    "updates": ["message", "callback_query"],
    "additionalFields": {}
  },
  "type": "n8n-nodes-base.telegramTrigger",
  "typeVersion": 1.2,
  "position": [-300, 0],
  "id": "<UUID>",
  "name": "Telegram Trigger",
  "webhookId": "<UUID>",
  "credentials": {
    "telegramApi": {
      "id": "__REPLACE_TELEGRAM_<PURPOSE>_ID__",
      "name": "Telegram – <Purpose>"
    }
  }
}
```

If only text messages (no buttons), use `"updates": ["message"]`.

### `n8n-nodes-base.executeWorkflowTrigger` — `typeVersion: 1.1`

Module entry point. Declare input schema:

```json
{
  "parameters": {
    "workflowInputs": {
      "values": [
        { "name": "data", "type": "object" },
        { "name": "user_id", "type": "string" }
      ]
    }
  },
  "type": "n8n-nodes-base.executeWorkflowTrigger",
  "typeVersion": 1.1,
  "position": [-300, 0],
  "id": "<UUID>",
  "name": "Start flow with data"
}
```

Inputs accessed downstream as `{{ $json.data }}`, `{{ $json.user_id }}` etc.

### `n8n-nodes-base.webhook` — `typeVersion: 2`

```json
{
  "parameters": {
    "httpMethod": "POST",
    "path": "<unique-path>",
    "options": {}
  },
  "type": "n8n-nodes-base.webhook",
  "typeVersion": 2,
  "position": [-300, 0],
  "id": "<UUID>",
  "name": "Webhook",
  "webhookId": "<UUID>"
}
```

### `n8n-nodes-base.manualTrigger` — `typeVersion: 1`

For test/dev workflows:
```json
{
  "parameters": {},
  "type": "n8n-nodes-base.manualTrigger",
  "typeVersion": 1,
  "position": [-300, 0],
  "id": "<UUID>",
  "name": "Manual Trigger"
}
```

---

## Core processing

### `n8n-nodes-base.httpRequest` — `typeVersion: 4.4`

Simple GET (e.g., fetching prompt from prompt-vault):
```json
{
  "parameters": {
    "url": "__REPLACE_PROMPT_URL__",
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.4,
  "name": "Get Prompt"
}
```

GET with query params and User-Agent header:
```json
{
  "parameters": {
    "url": "=https://api.example.com/data?key={{ $env.API_KEY }}",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        { "name": "User-Agent", "value": "n8n-pi-automate" }
      ]
    },
    "options": {}
  }
}
```

POST multipart (e.g., whisper STT — note this is what `module_STT_on_local_whisper` uses):
```json
{
  "parameters": {
    "method": "POST",
    "url": "http://speaches:8000/v1/audio/transcriptions",
    "sendBody": true,
    "contentType": "multipart-form-data",
    "bodyParameters": {
      "parameters": [
        { "parameterType": "formBinaryData", "name": "file", "inputDataFieldName": "data" },
        { "name": "model", "value": "Systran/faster-whisper-small" }
      ]
    },
    "options": {}
  }
}
```

POST JSON:
```json
"sendBody": true,
"contentType": "json",
"jsonBody": "={{ JSON.stringify({ key: $json.value }) }}"
```

Retry on flaky external API:
```json
"retryOnFail": true,
"maxTries": 5,
"waitBetweenTries": 5000
```

### `n8n-nodes-base.code` — `typeVersion: 2`

**Default: JavaScript.**

JS — single-item transform (e.g., the standard prompt placeholder replacer):
```json
{
  "parameters": {
    "jsCode": "const { DateTime } = require('luxon');\nconst prompt = $input.first().json.data;\n\nconst result = prompt\n  .replace('<current_date>', DateTime.now().toFormat('yyyy-MM-dd'));\n\nreturn [{ json: { prompt: result } }];"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "name": "Replacer"
}
```

JS — multi-item transform:
```json
"jsCode": "return $input.all().map(item => ({ json: { ...item.json, processed: true } }));"
```

Python (only when explicitly requested or heavy data work):
```json
{
  "parameters": {
    "language": "pythonNative",
    "pythonCode": "results = []\nfor item in _items:\n    data = item['json']\n    results.append({'json': {'value': data['x'] * 2}})\nreturn results"
  }
}
```

### `n8n-nodes-base.set` — `typeVersion: 3.4`

```json
{
  "parameters": {
    "assignments": {
      "assignments": [
        {
          "id": "<UUID>",
          "name": "text",
          "value": "={{ $json.message.text }}",
          "type": "string"
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "name": "Get Text"
}
```

Types: `string`, `number`, `boolean`, `array`, `object`.

### `n8n-nodes-base.switch` — `typeVersion: 3.4`

Multi-way routing with named outputs:
```json
{
  "parameters": {
    "rules": {
      "values": [
        {
          "conditions": {
            "options": { "caseSensitive": true, "typeValidation": "strict", "version": 3 },
            "conditions": [
              {
                "id": "<UUID>",
                "leftValue": "={{ $json.type }}",
                "rightValue": "voice",
                "operator": { "type": "string", "operation": "equals" }
              }
            ],
            "combinator": "and"
          },
          "renameOutput": true,
          "outputKey": "isVoice"
        },
        {
          "conditions": {
            "options": { "caseSensitive": true, "typeValidation": "strict", "version": 3 },
            "conditions": [
              {
                "id": "<UUID>",
                "leftValue": "={{ $json.type }}",
                "rightValue": "text",
                "operator": { "type": "string", "operation": "equals" }
              }
            ],
            "combinator": "and"
          },
          "renameOutput": true,
          "outputKey": "isText"
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.switch",
  "typeVersion": 3.4
}
```

Connection indexes match the output order (0 = first rule, 1 = second, etc.).

### `n8n-nodes-base.if` — `typeVersion: 2.3`

Binary branch (output 0 = true, output 1 = false):
```json
{
  "parameters": {
    "conditions": {
      "options": { "caseSensitive": false, "typeValidation": "strict", "version": 3 },
      "conditions": [
        {
          "id": "<UUID>",
          "leftValue": "={{ $json.status }}",
          "rightValue": "accepted",
          "operator": { "type": "string", "operation": "equals" }
        }
      ],
      "combinator": "and"
    },
    "options": {}
  },
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.3
}
```

### `n8n-nodes-base.merge` — `typeVersion: 3.1`

Wait for parallel paths to complete:
```json
{
  "parameters": {
    "numberInputs": 2
  },
  "type": "n8n-nodes-base.merge",
  "typeVersion": 3.1,
  "name": "Wait for all"
}
```

### `n8n-nodes-base.wait` — `typeVersion: 1.1`

Pause:
```json
{
  "parameters": {
    "amount": 5,
    "unit": "seconds"
  },
  "type": "n8n-nodes-base.wait",
  "typeVersion": 1.1
}
```

---

## Outputs

### `n8n-nodes-base.emailSend` — `typeVersion: 2.1`

```json
{
  "parameters": {
    "fromEmail": "={{ $env.N8N_AGENT_EMAIL_FROM }}",
    "toEmail": "={{ $env.REPORT_EMAIL_TO }}",
    "subject": "=📊 [Topic] {{ $now.format('dd.MM.yyyy') }}",
    "html": "=<div>...</div>",
    "options": {}
  },
  "type": "n8n-nodes-base.emailSend",
  "typeVersion": 2.1,
  "name": "Send Report",
  "webhookId": "<UUID>",
  "credentials": {
    "smtp": {
      "id": "__REPLACE_SMTP_ID__",
      "name": "SMTP account"
    }
  }
}
```

The `html` field always starts with `=` (n8n expression syntax). For the full HTML template, see `email-template.html`.

### `n8n-nodes-base.telegram` — `typeVersion: 1.2`

Send text message:
```json
{
  "parameters": {
    "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
    "text": "=<b>Title</b>\n\n{{ $json.body }}",
    "additionalFields": {
      "parse_mode": "HTML"
    }
  },
  "type": "n8n-nodes-base.telegram",
  "typeVersion": 1.2,
  "name": "Send Message",
  "webhookId": "<UUID>",
  "credentials": {
    "telegramApi": {
      "id": "__REPLACE_TELEGRAM_<PURPOSE>_ID__",
      "name": "Telegram – <Purpose>"
    }
  }
}
```

Send message with inline keyboard buttons:
```json
"additionalFields": {
  "parse_mode": "HTML",
  "reply_markup": "={\"inline_keyboard\":[[{\"text\":\"✅ Done\",\"callback_data\":\"done\"},{\"text\":\"❌ Reject\",\"callback_data\":\"rejected\"}]]}"
}
```

Download voice file:
```json
{
  "parameters": {
    "resource": "file",
    "fileId": "={{ $json.message.voice.file_id }}",
    "additionalFields": {}
  },
  "type": "n8n-nodes-base.telegram",
  "typeVersion": 1.2,
  "name": "Download voice file"
}
```

Edit a message (e.g., update inline keyboard after callback):
```json
{
  "parameters": {
    "operation": "editMessageText",
    "chatId": "={{ $json.callback_query.message.chat.id }}",
    "messageId": "={{ $json.callback_query.message.message_id }}",
    "text": "=✅ Updated"
  }
}
```

### `n8n-nodes-base.googleSheets` — `typeVersion: 4.7`

Read all rows:
```json
{
  "parameters": {
    "authentication": "serviceAccount",
    "documentId": {
      "__rl": true,
      "value": "={{ $env.MY_SHEET_LINK }}",
      "mode": "url"
    },
    "sheetName": {
      "__rl": true,
      "value": "gid=0",
      "mode": "list",
      "cachedResultName": "Sheet1"
    },
    "options": {}
  },
  "type": "n8n-nodes-base.googleSheets",
  "typeVersion": 4.7,
  "credentials": {
    "googleApi": {
      "id": "__REPLACE_GOOGLE_SHEETS_ID__",
      "name": "Google Sheets account"
    }
  }
}
```

Append row:
```json
"operation": "append",
"columns": {
  "mappingMode": "defineBelow",
  "value": {
    "Date": "={{ $now.toISO() }}",
    "Value": "={{ $json.value }}"
  }
}
```

### `n8n-nodes-base.notion` — `typeVersion: 2.2`

Common operations: `databasePage:create`, `databasePage:update`, `databasePage:getAll`. Schema depends on the user's Notion database; ask for the database ID and property names in the MD if not supplied.

Credentials block:
```json
"credentials": {
  "notionApi": {
    "id": "__REPLACE_NOTION_ID__",
    "name": "Notion account"
  }
}
```

---

## LangChain (AI)

### `@n8n/n8n-nodes-langchain.agent` — `typeVersion: 3.1`

With separate system + user message:
```json
{
  "parameters": {
    "promptType": "define",
    "text": "={{ $json.user_input }}",
    "hasOutputParser": true,
    "options": {
      "systemMessage": "={{ $('Get Prompt').item.json.data }}"
    }
  },
  "type": "@n8n/n8n-nodes-langchain.agent",
  "typeVersion": 3.1,
  "name": "Generator"
}
```

With prompt-vault triad (no separate system message; full prompt is replaced inline):
```json
{
  "parameters": {
    "promptType": "define",
    "text": "={{ $json.prompt }}",
    "hasOutputParser": true,
    "options": {}
  }
}
```

`hasOutputParser: true` is required when an `outputParserStructured` is wired as `ai_outputParser`.

### `@n8n/n8n-nodes-langchain.lmChatAnthropic` — `typeVersion: 1.3`

```json
{
  "parameters": {
    "model": {
      "__rl": true,
      "mode": "list",
      "value": "claude-sonnet-4-5-20250929",
      "cachedResultName": "Claude Sonnet 4.5"
    },
    "options": {
      "temperature": 0.7
    }
  },
  "type": "@n8n/n8n-nodes-langchain.lmChatAnthropic",
  "typeVersion": 1.3,
  "name": "Anthropic Chat Model",
  "credentials": {
    "anthropicApi": {
      "id": "__REPLACE_ANTHROPIC_ID__",
      "name": "Anthropic account"
    }
  }
}
```

Other model values (when user requests): `claude-opus-4-5-20250929`, `claude-haiku-4-5-20251001`.

### `@n8n/n8n-nodes-langchain.googleGemini` — `typeVersion: 1.1`

```json
{
  "parameters": {
    "modelId": {
      "__rl": true,
      "value": "models/gemini-2.5-flash",
      "mode": "list",
      "cachedResultName": "models/gemini-2.5-flash"
    },
    "messages": {
      "values": [
        { "content": "={{ $('Get Prompt').item.json.data }}", "role": "model" },
        { "content": "={{ $json.user_input }}" }
      ]
    },
    "builtInTools": {
      "googleSearch": true
    },
    "options": {}
  },
  "type": "@n8n/n8n-nodes-langchain.googleGemini",
  "typeVersion": 1.1,
  "name": "Gemini",
  "credentials": {
    "googlePalmApi": {
      "id": "__REPLACE_GOOGLE_GEMINI_ID__",
      "name": "Google Gemini account"
    }
  }
}
```

Note: Gemini node is a **standalone** node (not a `lmChat*` helper). It does NOT wire as `ai_languageModel` into an agent — it's called directly. Use it when the user wants Google Search grounding or non-agent LLM calls.

### `@n8n/n8n-nodes-langchain.outputParserStructured` — `typeVersion: 1.3`

```json
{
  "parameters": {
    "schemaType": "manual",
    "inputSchema": "{\n  \"type\": \"object\",\n  \"properties\": {\n    \"summary\": { \"type\": \"string\" },\n    \"score\": { \"type\": \"number\" }\n  },\n  \"required\": [\"summary\", \"score\"]\n}"
  },
  "type": "@n8n/n8n-nodes-langchain.outputParserStructured",
  "typeVersion": 1.3,
  "name": "Structured Output Parser"
}
```

Note: `inputSchema` is a **stringified** JSON Schema (escaped newlines). Build the JSON Schema as an object first, then `JSON.stringify` it with `\n` separators.

---

## Connections shapes

**Main flow** (default node-to-node):
```json
"connections": {
  "Schedule Trigger": {
    "main": [
      [{ "node": "Get Prompt", "type": "main", "index": 0 }]
    ]
  }
}
```

**AI helper wiring** (LLM and parser into agent):
```json
"connections": {
  "Anthropic Chat Model": {
    "ai_languageModel": [
      [{ "node": "Generator", "type": "ai_languageModel", "index": 0 }]
    ]
  },
  "Structured Output Parser": {
    "ai_outputParser": [
      [{ "node": "Generator", "type": "ai_outputParser", "index": 0 }]
    ]
  }
}
```

**Switch/If multi-output** — outer array is per output index:
```json
"connections": {
  "My Switch": {
    "main": [
      [{ "node": "Branch A", "type": "main", "index": 0 }],
      [{ "node": "Branch B", "type": "main", "index": 0 }]
    ]
  }
}
```

---
<!-- reference: references/patterns.md -->

# Recurring Patterns

Templates for the most common multi-node patterns. Copy node shapes, generate fresh UUIDs, adjust names to context.

---

## Prompt-vault triad

The user's standard pattern for any LLM call: fetch prompt from GitHub, replace placeholders, feed to agent with Anthropic + structured output parser.

### Nodes (5 total)

```
[Trigger / prev node]
  → Get Prompt (httpRequest)
  → Replacer (code, JS)
  → Generator (langchain.agent)
       ↑ ai_languageModel  ← Anthropic Chat Model (langchain.lmChatAnthropic)
       ↑ ai_outputParser   ← Structured Output Parser (langchain.outputParserStructured)
  → [next node]
```

### Node templates

**Get Prompt** — `httpRequest` at `[x, 0]`:
```json
{
  "parameters": {
    "url": "__REPLACE_PROMPT_URL__",
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.4,
  "position": [x, 0],
  "id": "<UUID>",
  "name": "Get Prompt"
}
```

**Replacer** — `code` at `[x+200, 0]`:
```json
{
  "parameters": {
    "jsCode": "const { DateTime } = require('luxon');\nconst prompt = $input.first().json.data;\n\nconst result = prompt\n  .replace('<current_date>', DateTime.now().toFormat('yyyy-MM-dd'));\n  // add more replacements as needed: .replace('<city>', $env.MY_CITY)\n\nreturn [{ json: { prompt: result } }];"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [x+200, 0],
  "id": "<UUID>",
  "name": "Replacer"
}
```

If extra context comes from another node (e.g., a city set earlier), the replacer pulls it via `$('Node Name').first().json.field`.

**Generator** — `langchain.agent` at `[x+400, 0]`:
```json
{
  "parameters": {
    "promptType": "define",
    "text": "={{ $json.prompt }}",
    "hasOutputParser": true,
    "options": {}
  },
  "type": "@n8n/n8n-nodes-langchain.agent",
  "typeVersion": 3.1,
  "position": [x+400, 0],
  "id": "<UUID>",
  "name": "<Descriptive Generator Name>"
}
```

**Anthropic Chat Model** — `langchain.lmChatAnthropic` at `[x+400, 200]` (directly under Generator):
```json
{
  "parameters": {
    "model": {
      "__rl": true,
      "mode": "list",
      "value": "claude-sonnet-4-5-20250929",
      "cachedResultName": "Claude Sonnet 4.5"
    },
    "options": { "temperature": 0.7 }
  },
  "type": "@n8n/n8n-nodes-langchain.lmChatAnthropic",
  "typeVersion": 1.3,
  "position": [x+400, 200],
  "id": "<UUID>",
  "name": "Anthropic Chat Model",
  "credentials": {
    "anthropicApi": {
      "id": "__REPLACE_ANTHROPIC_ID__",
      "name": "Anthropic account"
    }
  }
}
```

**Structured Output Parser** — `langchain.outputParserStructured` at `[x+550, 200]`:
```json
{
  "parameters": {
    "schemaType": "manual",
    "inputSchema": "<stringified JSON Schema>"
  },
  "type": "@n8n/n8n-nodes-langchain.outputParserStructured",
  "typeVersion": 1.3,
  "position": [x+550, 200],
  "id": "<UUID>",
  "name": "Structured Output Parser"
}
```

### Connections to add

```json
"Get Prompt": { "main": [[{ "node": "Replacer", "type": "main", "index": 0 }]] },
"Replacer": { "main": [[{ "node": "<Generator Name>", "type": "main", "index": 0 }]] },
"Anthropic Chat Model": {
  "ai_languageModel": [[{ "node": "<Generator Name>", "type": "ai_languageModel", "index": 0 }]]
},
"Structured Output Parser": {
  "ai_outputParser": [[{ "node": "<Generator Name>", "type": "ai_outputParser", "index": 0 }]]
}
```

### Variant: system message instead of placeholder-replaced prompt

When prompt-vault content is meant as a **system message** and the user input is a separate variable (e.g., a Telegram message body), drop the Replacer and use the Agent's `systemMessage` option:

```json
"parameters": {
  "promptType": "define",
  "text": "={{ $json.text }}",
  "hasOutputParser": true,
  "options": {
    "systemMessage": "={{ $('Get Prompt').item.json.data }}"
  }
}
```

Flow becomes: `Trigger → Get Prompt → [user-input prep nodes] → Generator (with systemMessage referencing Get Prompt)`.

---

## Telegram with callbacks

Telegram bot accepting text + voice messages + button clicks (callback queries).

### Nodes

```
Telegram Trigger (updates: ["message", "callback_query"])
  → Choose Telegram Action (switch: isMessage vs isButtonClick)
    Branch 0 (isMessage):
      → Input format switch (text vs voice)
         Branch 0 (text):  → Get Text (set) → ...
         Branch 1 (voice): → Download voice file (telegram) → Parse audio file (httpRequest to speaches OR executeWorkflow → module_STT_on_local_whisper) → Get parsed text (set) → ...
    Branch 1 (isButtonClick):
      → Set callback variables (set) → Choose action (switch by callback_data) → ...
```

### Choose Telegram Action — `switch`

```json
{
  "parameters": {
    "rules": {
      "values": [
        {
          "conditions": {
            "options": { "caseSensitive": true, "typeValidation": "strict", "version": 3 },
            "conditions": [
              {
                "id": "<UUID>",
                "leftValue": "={{ $json.message ? \"new_message\" : \"button_click\" }}",
                "rightValue": "new_message",
                "operator": { "type": "string", "operation": "equals" }
              }
            ],
            "combinator": "and"
          },
          "renameOutput": true,
          "outputKey": "isMessage"
        },
        {
          "conditions": {
            "options": { "caseSensitive": true, "typeValidation": "strict", "version": 3 },
            "conditions": [
              {
                "id": "<UUID>",
                "leftValue": "={{ $json.message ? \"new_message\" : \"button_click\" }}",
                "rightValue": "button_click",
                "operator": { "type": "string", "operation": "equals" }
              }
            ],
            "combinator": "and"
          },
          "renameOutput": true,
          "outputKey": "isButtonClick"
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.switch",
  "typeVersion": 3.4,
  "name": "Choose Telegram Action"
}
```

### Input format switch — `switch`

Split text vs voice:
```json
"rules": {
  "values": [
    {
      "conditions": {
        "options": { "caseSensitive": true, "typeValidation": "strict", "version": 3 },
        "conditions": [
          {
            "id": "<UUID>",
            "leftValue": "={{ $json.message.text }}",
            "rightValue": "",
            "operator": { "type": "string", "operation": "notEmpty", "singleValue": true }
          }
        ],
        "combinator": "and"
      },
      "renameOutput": true,
      "outputKey": "isText"
    },
    {
      "conditions": {
        "options": { "caseSensitive": true, "typeValidation": "strict", "version": 3 },
        "conditions": [
          {
            "id": "<UUID>",
            "leftValue": "={{ $json.message.voice.file_id }}",
            "rightValue": "",
            "operator": { "type": "string", "operation": "notEmpty", "singleValue": true }
          }
        ],
        "combinator": "and"
      },
      "renameOutput": true,
      "outputKey": "isVoice"
    }
  ]
}
```

### Voice handling — call existing whisper module

**Preferred** — call user's existing `module_STT_on_local_whisper` workflow via `executeWorkflow` (don't re-implement). User already has this module deployed.

```json
{
  "parameters": {
    "workflowId": {
      "__rl": true,
      "value": "<MODULE_WORKFLOW_ID_OR_PLACEHOLDER>",
      "mode": "list",
      "cachedResultName": "module_STT_on_local_whisper"
    },
    "workflowInputs": {
      "mappingMode": "defineBelow",
      "value": {
        "data": "={{ $binary.data }}"
      }
    },
    "options": {}
  },
  "type": "n8n-nodes-base.executeWorkflow",
  "typeVersion": 1.2,
  "name": "STT Whisper"
}
```

In the MD, note: "Workflow zakłada że masz aktywny `module_STT_on_local_whisper`. Po imporcie wskaż go w nodzie `STT Whisper` lub podmień na inline httpRequest do speaches."

**Inline alternative** if no module — use `httpRequest` to `http://speaches:8000/v1/audio/transcriptions` (see node-catalog.md § httpRequest multipart).

### Callback action handling

After `Set callback variables` (extracts `data` and `message_id` from `callback_query`), use a `switch` matching against `callback_data` strings:

```json
"rules": {
  "values": [
    { "outputKey": "actionDone",     "conditions": { ..., "rightValue": "done" } },
    { "outputKey": "actionProgress", "conditions": { ..., "rightValue": "in_progress" } },
    { "outputKey": "actionReject",   "conditions": { ..., "rightValue": "reject" } }
  ]
}
```

---

## Module shape

A workflow callable from another workflow as a reusable building block.

### Required pieces

1. **Trigger** = `executeWorkflowTrigger` with `workflowInputs.values` declaring the input schema
2. **Last node** = `set` returning the result fields (no email/telegram outputs unless explicitly requested)
3. **Settings** include `"callerPolicy": "workflowsFromSameOwner"`
4. **Tag**: `module`

### Skeleton

```
Start flow with data (executeWorkflowTrigger)
  → [processing nodes]
  → Return result (set with output fields)
```

### Trigger

```json
{
  "parameters": {
    "workflowInputs": {
      "values": [
        { "name": "data", "type": "object" }
      ]
    }
  },
  "type": "n8n-nodes-base.executeWorkflowTrigger",
  "typeVersion": 1.1,
  "name": "Start flow with data"
}
```

For multiple inputs, add more entries; types: `string`, `number`, `boolean`, `object`, `array`.

### Settings

```json
"settings": {
  "executionOrder": "v1",
  "binaryMode": "separate",
  "timezone": "Europe/Warsaw",
  "availableInMCP": false,
  "callerPolicy": "workflowsFromSameOwner"
}
```

### Last node (return)

```json
{
  "parameters": {
    "assignments": {
      "assignments": [
        {
          "id": "<UUID>",
          "name": "result",
          "value": "={{ $json.processed_value }}",
          "type": "string"
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "name": "Return result"
}
```

The parent workflow that calls this module reads it via `$json.result`.

---

## Switch routing with merge

When multiple branches need to converge (e.g., compute parallel reports, then send a unified email):

```
[upstream]
  → Switch (rule A vs rule B)
    Branch A → Process A → ┐
    Branch B → Process B → ┴ → Merge (numberInputs: 2) → Format → Send
```

`merge` typeVersion 3.1, `numberInputs` equals number of branches. Each branch's last node connects into a different input index of merge:

```json
"connections": {
  "Process A": { "main": [[{ "node": "Wait for all", "type": "main", "index": 0 }]] },
  "Process B": { "main": [[{ "node": "Wait for all", "type": "main", "index": 1 }]] }
}
```

Note `index: 0` vs `index: 1` distinguishes merge inputs.

---

## Retry on flaky API

Add to any node calling an external API where failures happen (e.g., Yahoo Finance, public LLM endpoints):

```json
"retryOnFail": true,
"maxTries": 5,
"waitBetweenTries": 5000
```

Sits at the **node root level** (sibling of `parameters`, `type`, `name`).

---

## Multi-step LLM pipeline (router → executor)

When the description involves intent classification + routing to different processing branches (like `personal_trainer`):

```
[Input]
  → Intent Classifier (langchain.agent + Anthropic + Structured Output Parser with `intent` enum)
  → Switch (by $json.output.intent)
    Branch "askQuestion"   → [QA flow]
    Branch "updateData"    → [data update flow]
    Branch "changeMetadata" → [metadata flow]
    Branch "other"         → [fallback]
```

Each branch is independent and may use its own prompt-vault triad. The classifier's output schema is tight:

```json
{
  "type": "object",
  "properties": {
    "intent": {
      "type": "string",
      "enum": ["askQuestion", "updateData", "changeMetadata", "other"]
    }
  },
  "required": ["intent"]
}
```

---
<!-- reference: references/validation.md -->

# Validation Algorithm

Run this **after** assembling the JSON in memory, **before** writing to disk. If any check fails, fix and re-run from check 1.

---

## Checks

### 1. Unique node IDs
Every `node.id` is a valid UUIDv4 and appears exactly once.

Check:
```
ids = [n.id for n in workflow.nodes]
assert len(ids) == len(set(ids)), "duplicate node IDs"
for id in ids: assert is_uuid_v4(id)
```

Fix: regenerate any duplicate IDs.

### 2. Connections reference existing nodes
For every key in `workflow.connections` and every `node` field inside, the value matches a `workflow.nodes[*].name`.

```
node_names = set(n.name for n in workflow.nodes)
for src_name, conn_block in workflow.connections.items():
    assert src_name in node_names, f"connection source '{src_name}' not in nodes"
    for conn_type in conn_block:  # main, ai_languageModel, ai_outputParser, ...
        for output_idx_list in conn_block[conn_type]:
            for target in output_idx_list:
                assert target.node in node_names, f"connection target '{target.node}' not in nodes"
```

Fix: rename or remove the bad reference. Most often it's a typo or a renamed node.

### 3. typeVersions correct
Every `node.typeVersion` matches the table in SKILL.md.

Fix: replace with the correct typeVersion.

### 4. AI agent helpers wired correctly
For every `langchain.agent` node:
- There must be exactly one node connecting to it via `ai_languageModel` (an `lmChat*` node).
- If the agent has `hasOutputParser: true`, there must be exactly one node connecting via `ai_outputParser`.

```
for agent in [n for n in workflow.nodes if n.type == "@n8n/n8n-nodes-langchain.agent"]:
    lm_sources = [src for src, cb in workflow.connections.items()
                  if "ai_languageModel" in cb and any(t.node == agent.name for tl in cb["ai_languageModel"] for t in tl)]
    assert len(lm_sources) == 1, f"agent '{agent.name}' needs exactly one ai_languageModel"

    if agent.parameters.get("hasOutputParser"):
        op_sources = [src for src, cb in workflow.connections.items()
                      if "ai_outputParser" in cb and any(t.node == agent.name for tl in cb["ai_outputParser"] for t in tl)]
        assert len(op_sources) == 1, f"agent '{agent.name}' needs exactly one ai_outputParser"
```

Fix: add the missing helper node + connection, or remove `hasOutputParser: true` if no parser is intended.

### 5. At least one trigger
The workflow has at least one node whose `type` is in:
- `n8n-nodes-base.scheduleTrigger`
- `n8n-nodes-base.telegramTrigger`
- `n8n-nodes-base.webhook`
- `n8n-nodes-base.executeWorkflowTrigger`
- `n8n-nodes-base.manualTrigger`
- `n8n-nodes-base.formTrigger`
- `n8n-nodes-base.emailReadImap`

Fix: add a trigger that matches the description. If user didn't specify, default to `scheduleTrigger` (daily at 7) for periodic flows, `manualTrigger` for testing, or ask.

### 6. No orphan main nodes
Every non-trigger node has at least one incoming connection of type `main`.

```
incoming = collections.defaultdict(int)
for src, cb in workflow.connections.items():
    for tl in cb.get("main", []):
        for t in tl:
            incoming[t.node] += 1

trigger_types = { ...as above... }
for n in workflow.nodes:
    if n.type not in trigger_types:
        # helper AI nodes (lmChat*, outputParserStructured) are wired via
        # ai_languageModel / ai_outputParser, not main — they're not orphans
        if n.type.startswith("@n8n/n8n-nodes-langchain.lm") or \
           n.type == "@n8n/n8n-nodes-langchain.outputParserStructured":
            continue
        assert incoming[n.name] >= 1, f"orphan node: {n.name}"
```

Fix: connect the orphan, or remove if it was added by mistake.

### 7. No hardcoded credential IDs
For every node with a `credentials` block, every `id` field is a placeholder of the documented form (`__REPLACE_*_ID__`).

```
import re
pattern = re.compile(r"^__REPLACE_[A-Z_]+_ID__$")
for n in workflow.nodes:
    creds = n.get("credentials", {})
    for cred_type, cred in creds.items():
        cred_id = cred.get("id", "")
        assert pattern.match(cred_id), f"node {n.name}: credential id '{cred_id}' is not a placeholder"
```

Fix: replace with the appropriate placeholder.

### 8. Env vars via `$env`
Every reference to environment data uses `{{ $env.VAR_NAME }}` form.

Soft check: scan all parameter values for the substring `$env.`. There's no enforcement that the user mentioned the var in the MD — that's a coverage concern, addressed by check 11 below.

### 9. Settings block exact
```
assert workflow.settings == {
    "executionOrder": "v1",
    "binaryMode": "separate",
    "timezone": "Europe/Warsaw",
    "availableInMCP": False,
    # plus "callerPolicy": "workflowsFromSameOwner" if module
}
```

Fix: replace with the exact block.

### 10. Switch/If output indexes match
For every `switch` or `if` node, the highest output index used in `connections` must be `<` the number of declared rules.

```
for n in [x for x in workflow.nodes if x.type in ("n8n-nodes-base.switch", "n8n-nodes-base.if")]:
    if n.type == "n8n-nodes-base.switch":
        declared_outputs = len(n.parameters["rules"]["values"])
    else:  # if
        declared_outputs = 2

    used_indexes = []
    for cb in workflow.connections.get(n.name, {}).get("main", []):
        # cb is the list of connections at a given output index
        pass
    main_lists = workflow.connections.get(n.name, {}).get("main", [])
    assert len(main_lists) <= declared_outputs, f"{n.name}: too many output branches"
```

Fix: trim excess branches or add missing rules.

### 11. MD covers all placeholders and env vars
Cross-check: every `__REPLACE_*_ID__`, every `__REPLACE_PROMPT_*_URL__`, and every `$env.VAR` in the JSON has a corresponding row in the MD's tables.

This is a **soft check** — flag missing entries as warnings and add them automatically to the MD before writing.

---

## Reporting

If validation surfaces any issues that required non-trivial fixes (e.g., adding a missing helper node, defaulting an unspecified schema), add a line to the MD's *Założenia / uwagi* section describing what was decided so the user can sanity-check.

Examples:
- "Domyślnie zakładam Anthropic Sonnet 4.5 jako LLM — jeśli chcesz inny model, podmień w nodzie `Anthropic Chat Model`."
- "Output parser schema wygenerowany na podstawie opisu (pola `summary`, `score`). Jeśli model ma zwracać inne pola, edytuj `Structured Output Parser`."
- "Schedule trigger ustawiony na 07:00 (domyślne — najczęściej używasz tej godziny). Zmień w nodzie `Schedule Trigger` jeśli chcesz inną."

---

## Order of operations summary

```
1. Build all nodes (with placeholder cred IDs, fresh UUIDs)
2. Build connections
3. Set tags, settings, name
4. Run checks 1–10 in order; fix and rerun if any fail
5. Generate MD; run check 11; auto-add missing rows
6. Write both files
7. present_files
```
