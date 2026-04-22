---
name: course-planner
description: Generate a structured, personalized learning course plan for any technical or non-technical topic. Use this skill whenever the user wants to learn something new, master a technology, deepen expertise in a subject, or asks for a course/learning plan/curriculum — even if they phrase it casually like "jak się nauczyć X", "zrób mi plan kursu", "chcę opanować Y", "help me learn Z", or "give me a study plan for...". Also trigger when user mentions wanting to reach a specific skill level (e.g., "chcę móc swobodnie pracować z Room"), combine a topic with prior experience, or branch into related subtopics. Always use this skill — not plain conversation — when the output should be a structured multi-module curriculum with lessons.
---

# Course Planner

Generates a personalized, structured learning course based on the user's experience, goals, and topic — output is an interactive HTML page with collapsible modules, copyable lessons, and built-in role/teaching metadata.

---

## Input Parameters

Gather these from the user (may be implicit or explicit):

| Parameter | Description | Required |
|---|---|---|
| `topic` | What they want to learn | ✅ |
| `experience` | Their current knowledge level / background | ✅ |
| `goal` | Desired outcome / proficiency level description | ✅ |
| `branches` | Related subtopics or extensions they want to explore | optional |
| `connections` | Things they want to link the topic to (e.g., existing skills, projects) | optional |

If topic or goal is completely absent, ask before generating. For experience level, make a reasonable inference from context if the user hasn't stated it explicitly (e.g., "I've been doing Android for 6 years" implies senior-level; "I'm learning Python" implies beginner). Only ask if you genuinely cannot infer.

Never ask for pace preference — the slider widget handles that interactively.

---

## Teaching Methods Library

Select methods per lesson based on the **nature of the content**. Use the method IDs in the lesson metadata.

| ID | Method | Best for |
|---|---|---|
| `concept-first` | Explain theory → diagram/analogy → mini-exercise | Abstract concepts, architecture, patterns |
| `code-along` | Live coding with step-by-step commentary | APIs, libraries, syntax-heavy topics |
| `project-based` | Build a small self-contained artifact | Frameworks, tools, integration topics |
| `tdd-loop` | Write failing test → implement → refactor | Any programmatic skill (especially for developers) |
| `spaced-repetition` | Flashcard-style review of key facts/rules | Terminology, configuration keys, rules |
| `socratic` | Question-driven exploration without giving answers upfront | Design decisions, trade-offs, architecture choices |
| `reading-lab` | Read official docs/book chapter → summarize → apply | Mature, well-documented technologies |
| `debug-first` | Start with broken code / failing system → diagnose | Debugging skills, error handling, edge cases |
| `comparison` | Side-by-side contrast of two approaches | When migrating, evaluating alternatives |
| `reverse-engineering` | Analyze existing real-world code/system | Advanced topics, open-source exploration |

---

## Knowledge Check Methods

| ID | Check | Best for |
|---|---|---|
| `mini-quiz` | 3–5 written questions with expected answers | Conceptual lessons |
| `code-challenge` | Write a function / class from scratch | Coding skills |
| `build-test` | Build a small working feature | Framework/library lessons |
| `explain-back` | Explain the concept to an imaginary junior dev | Deep understanding |
| `review-checklist` | Review a provided code snippet against a checklist | Code quality, patterns |
| `debug-challenge` | Fix intentionally broken code | Error handling, debugging |
| `design-exercise` | Sketch architecture for a given scenario | Design/architecture lessons |

---

## Course Structure Rules

### Sizing — no artificial limits

**There is no fixed lesson-per-module cap.** Let the topic dictate the structure:
- A focused subtopic might need 3 lessons. A complex one might need 8–10.
- A course might have 3 modules or 9 modules. Follow the content, not a template.
- Lessons should be atomic (45–90 min each), and modules should be thematically coherent.
- **Explicitly avoid padding** — do not add filler lessons to reach a round number. But do not compress either — if 7 lessons are needed, use 7.

**Before writing the course, explicitly plan it:**
1. List every major area the topic covers
2. Group into natural thematic clusters
3. Assign lesson counts based on actual complexity
4. Only then generate the HTML

### Lesson content

Each lesson has:
- **Title** — clear and specific
- **Description** — 4–6 sentences covering: what will be learned, why it matters, what concrete skills the learner gains, and key gotchas or connections to other lessons
- **Tags** — key technologies/concepts (5–10 tags)
- **Teaching method** (from library above)
- **Knowledge check method**
- **Estimated time**

### Module content

Each module has:
- **Title** — thematic name
- **Description** — 3–5 sentences: what this module covers, why this grouping makes sense, what the learner can do after completing it, how it connects to adjacent modules

### Ordering and depth

- Start from user's current knowledge — skip fundamentals they already know
- Order: foundational → practical → advanced → integrative
- Weave user's existing projects/skills into project-based and tdd lessons
- Add optional "Rozszerzenia" module at the end for branch topics
- Depth: "understand basics" → broader lessons; "write production code" → narrower, deeper, more tdd/debug lessons

---

## Language Rules

**Content language:** Polish. All user-facing prose — descriptions, module names, button labels — is in Polish.

**Technical names and programming terms stay in English:** library names (Turbine, MockK, Koin, Room, Jetpack Compose), API/class/function names (StateFlow, CoroutineScope, @Composable), architectural patterns (MVI, MVVM, Repository), tool names, programming concepts (state hoisting, composable, recomposition, dependency injection). These are proper nouns and domain terms that developers use in English regardless of their native language.

**Code:** always in English (variable names, comments, identifiers).

**This SKILL.md** is in English (for the AI). Only the generated course output is in Polish.

---

## Prompt Template for Course Generation

When generating the course, think step-by-step internally:
1. Map user experience → determine starting point (skip known fundamentals)
2. Decompose topic into logical learning areas
3. Order areas from foundational → practical → advanced
4. Assign methods per lesson type (concept → code-along/tdd → project → review)
5. Estimate time per lesson realistically
6. Generate HTML output

---

## Output Format

**Always output an interactive HTML page** saved to `/mnt/user-data/outputs/course-<topic-slug>.html`.

### HTML Requirements

The page must include:

**Global metadata header** (visible at top of page, not collapsible):
```
Course: <title>
Goal: <goal description>
Experience level: <user's background>
Total estimated time: <sum>
Copy role prefix: [button] — copies the global role/context block (see below)
```

**Global Role Block** (copied when user clicks "Copy Role Prefix"):
```
You are an expert tutor helping me learn [TOPIC].
My background: [EXPERIENCE].
My goal: [GOAL].
Teaching style for this session: [METHOD_DESCRIPTION].
Knowledge check at the end: [CHECK_DESCRIPTION].
```
This block is also injected automatically when any lesson is copied.

**Module structure:**
- Collapsible `<details>/<summary>` blocks per module
- Module header shows: module name, lesson count, total time
- Each lesson inside is a card with:
  - Lesson title + description
  - Tags: technologies/concepts
  - Method badge + Check badge
  - Estimated time
  - **"Copy Lesson Prompt"** button → copies full lesson prompt (see below)

**Copied Lesson Prompt format** (what goes to clipboard):
```
[ROLE BLOCK]

---

Lesson: [LESSON TITLE]
Module: [MODULE NAME]
Topic: [TOPIC]

[LESSON DESCRIPTION]

Key concepts to cover: [TAGS]

Teaching method: [METHOD_FULL_DESCRIPTION]
How we'll check my understanding: [CHECK_FULL_DESCRIPTION]

Let's begin.
```

### Storage Note

Default output uses `localStorage` (browser-local, no server needed). To migrate to a backend (e.g., Ktor on Raspberry Pi for LAN access), replace only `loadState()` and `saveState()` with `fetch()` calls — the rest of the HTML is unchanged. Always default to localStorage; mention backend migration only if user asks.

---

### Course Header Stats Bar

The stats bar shows: number of modules, number of lessons, total estimated time, **course level**, and a pace calculator widget.

**Course level** — determined by the AI based on the topic depth and user experience:
- `🌱 Podstawy` — for beginners, fundamentals-heavy
- `⚙️ Średniozaawansowany` — solid knowledge assumed, production focus
- `🔥 Zaawansowany` — deep dives, architecture, performance

**Pace calculator** — an interactive widget below the stats bar:
- Horizontal slider: 0.5h to 4h/day (step 0.5h), default 1h
- Dynamic label: `"~N tygodni przy X godz./dzień"`
- Formula: `ceil(total_hours / hours_per_day / 7)` weeks
- Slider fill updates via CSS `linear-gradient` on input
- `updatePace()` called on `oninput` and once on `DOMContentLoaded`
- No localStorage needed — purely informational/motivational
- `total_hours` is the actual course total computed from lesson times

### Lesson Status Selector

Each lesson has a 3-state dropdown button (replaces plain checkbox):
- `⬜ Not started` → `🔄 In progress` → `✅ Completed`
- Dropdown closes on outside click
- Status persisted in localStorage as `status_<id>`
- Completed card gets a subtle green border + strikethrough title
- In-progress card gets a blue border

### Per-Quiz Copy Buttons

Each lesson has two action buttons:
- **📋 Copy Lesson Prompt** — copies the full lesson prompt with role block
- **🎯 Copy Test Prompt** — copies a structured test prompt asking for: 3 conceptual questions, 1 coding challenge, 1 trick question; requests evaluation after answers

Each **module** has a **🎯 Module Test Prompt** button at the bottom that generates a comprehensive module review (5 conceptual questions + 2 coding challenges + 1 synthesis question).

### Celebration Effects

Triggered automatically:
- **Lesson completed** → small toast slides in from top, random motivational line, mini confetti burst (0.8s)
- **Module completed** → trophy toast, larger confetti (3s)
- **Full course completed** → golden toast + sustained confetti (6s)

Toast auto-dismisses. Confetti fades out gracefully.

### Progress Tracking (localStorage)

All state is persisted to `localStorage` under a course-specific key. State survives page refresh but is browser/device-local — user understands this.

**Checkboxes** — each lesson has a checkbox. When checked:
- Lesson card gets a subtle `done` style (title struck through)
- Module mini progress bar updates
- Global progress bar updates
- Module border turns green when all lessons done

**Buttons:**
- "↺ Reset Progress" — clears all checkboxes (confirms first), keeps notes intact

### Per-Lesson Notes

Each lesson has a collapsible notes area (collapsed by default):
- Toggle button: `📝 Notes` + a green dot indicator when notes are saved
- Textarea: monospace, resizable, placeholder hints to paste AI feedback
- "Save" button — writes to localStorage, shows `saved ✓` confirmation for 2s
- Unsaved indicator appears on `oninput`
- Notes survive page refresh; dot stays visible when notes exist

### Styling

- Dark developer aesthetic (background `#0d1117`, cards `#161b22`, accent `#58a6ff`)
- Clean monospace font for tags/badges
- Method badges: blue; Check badges: green; Time: gray; Notes dot: green
- Smooth expand/collapse animations
- Responsive, mobile-friendly
- All action buttons show ✓ confirmation for 2 seconds after click

---

## Example Invocation

User says: *"Chcę opanować Jetpack Compose na poziomie, żeby móc pisać produkcyjne komponenty z animacjami i testami. Znam Androida, mam doświadczenie z XML layoutami i ViewModelem."*

→ Skill triggers, generates full course HTML with ~4–5 modules, starting from Compose fundamentals (skipping Android basics), progressing through state management, theming, animations, testing — with tdd-loop and project-based methods dominant, build-test and debug-challenge as checks.
