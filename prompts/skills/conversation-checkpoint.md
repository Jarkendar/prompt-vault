---
name: conversation-checkpoint
description: Generate a dense, copy-pasteable conversation checkpoint designed as a handoff document for resuming work in a new LLM session. ALWAYS use this skill whenever the user types or says any of: "podsumuj rozmowę", "podsumuj sesję", "streszcz rozmowę", "zrób checkpoint", "checkpoint", "savepoint", "zapisz kontekst", "handoff", "summary", "summarize this conversation", "wrap up the chat". Also trigger when the user mentions they want to continue work in a new chat/session, pass context to another model or bot, are running out of context window, or need to brief another LLM. Output is a SINGLE markdown code block (one-click copy) in the same language as the conversation, structured for both human reading and machine ingestion. Includes topic, persona (if set), tech stack/context, short description, chosen path with rationale, rejected alternatives (only if relevant), current state, and concrete next steps. Optimized for density — no code snippets, only key signatures and architectural decisions.
---

# Conversation Checkpoint

Produce a compact, copy-pasteable summary of the current conversation so it can be pasted into a new chat (with this or another model) as a starting context. The output is engineered to be both human-readable and dense enough for another LLM to resume work without re-deriving prior decisions.

## When to trigger

Trigger whenever the user explicitly asks for a summary or handoff. Common phrasings (Polish and English, non-exhaustive):

- "podsumuj rozmowę", "podsumuj sesję", "streszcz rozmowę"
- "zrób checkpoint", "checkpoint", "savepoint", "zapisz kontekst"
- "handoff", "summary", "summarize this conversation", "wrap up"
- "potrzebuję tego do nowego chata", "kontynuujemy w nowej sesji"
- "kończy mi się kontekst", "running out of context"

Do not trigger on incidental uses of the word "summary" inside an unrelated request.

## Output format — strict

The response is a single markdown fenced code block. Nothing else of substance before or after — at most one short lead-in sentence (e.g. "Checkpoint, ready to copy:") preceding the block. No closing commentary.

**Fence:** use four backticks for the outer fence with language `markdown`. This allows triple-backtick blocks inside if absolutely necessary (rare — see content rules).

**Language of contents:** match the dominant language of the conversation. Polish conversation → Polish summary. English conversation → English summary. Mixed → use the language of the user's most recent substantive turn. This applies to section headers, labels, and body text alike.

**Section order (English template — translate headers and labels when conversation is in another language):**

```
# [Topic — one line, specific]

**Persona:** [full characterization — role, tone, approach, constraints]
**Stack/context:** [technologies, project name, environment, versions if relevant]

## Description
[2–3 sentences: what the conversation was about and why]

## Chosen path
[Decision(s) taken, with a short rationale. Include key signatures inline using single backticks if they anchor the discussion, e.g. `fun syncReceipts(since: Instant): Flow<SyncEvent>`.]

## Rejected alternatives
- [Option X — rejected because Y]
- [Option Z — rejected because W]

## Current state
[What is done, what is in progress, where we paused. Reference filenames only if they are central to continuation.]

## Next steps
- [Concrete next action]
- [Next concrete action]
- [Open question to resolve]
```

For a Polish conversation, the translated headers are: `## Opis`, `## Wybrana ścieżka`, `## Odrzucone alternatywy`, `## Stan obecny`, `## Kolejne kroki`. The `**Persona:**` and `**Stack/context:**` labels translate to `**Persona:**` and `**Stack/kontekst:**`.

## Content rules

**Include:**

- Key function/class/type signatures inline (single backticks) when they anchor a decision.
- Architectural decisions with a one-line rationale.
- File names or module paths **only** when they are central to continuing the work.
- Concrete next actions — not vague aspirations.

**Exclude:**

- Multi-line code snippets. Assume any code produced has already been transferred or understood. If a fragment is genuinely indispensable for continuation, describe its shape rather than paste it verbatim.
- Discussion paths that did not influence the final direction.
- Pleasantries, meta-commentary about the conversation itself ("we had a great discussion"), the assistant's reasoning process.
- Speculative or hedged content. If something is uncertain, mark it as an open question under Next steps.

**Optional sections:** if a section has no content, **omit it entirely**. Do not write "Persona: none" or "Rejected alternatives: none". Persona, Stack/context, and Rejected alternatives are all optional in this sense.

## Density target

Aim for 200–600 tokens of summary content. Longer is acceptable for multi-thread sessions, but stay under ~1000 tokens. The reader is another LLM with limited patience and a human who wants to scan the block in 30 seconds.

## Multi-topic conversations

If the conversation covered several distinct topics with their own decisions, produce a single checkpoint using the most important topic as `# Topic`, and use sub-sections under `## Chosen path` for each thread. Do not generate multiple separate code blocks — the user wants one copy operation.

## Example

````markdown
# PhotoVault — offline-first sync strategy for feature-sync

**Persona:** Senior Android dev pair-programming, TDD-first, Clean Architecture, one task per turn, concise and direct style.
**Stack/context:** Android (Kotlin 2.0, Compose, Coroutines/Flow, Room 2.6, Ktor client), `feature-sync` module in PhotoVault, target API 34, min API 26.

## Description
Designed a sync strategy for photo uploads between the Android app and a Ktor backend. The app must work offline-first with deferred upload, hash-based deduplication, and resilience to process restart.

## Chosen path
Repository pattern with local Room as the single source of truth. Upload via `WorkManager` with `UniqueWorkPolicy.KEEP`, status exposed as `Flow<SyncState>` from a sealed class. SHA-256 computed locally before enqueue for deduplication. Key contract: `class SyncRepository(local: PhotoDao, remote: PhotoApi) { fun observe(): Flow<SyncState>; suspend fun enqueue(uri: Uri) }`.

## Rejected alternatives
- Direct upload from UI without WorkManager — rejected, process restart loses the queue.
- Server-side deduplication as primary — rejected, wastes bandwidth on duplicates.
- RxJava instead of Flow — rejected, project is 100% coroutines.

## Current state
`SyncRepository` contract and `SyncState` sealed class designed (Idle / Enqueued / Uploading / Failed / Done). No implementation yet. Unit tests not written.

## Next steps
- Write a failing test for `enqueue()` with a mocked `WorkManager`.
- Implement `SyncWorker` with exponential backoff (max 5 retries).
- Decide: hash cache storage — column in Room or a separate `HashDao`?
````

## Final note for the assistant

When this skill triggers, do not narrate what you are about to do. Open with at most a one-line lead-in and then deliver the code block. The user wants to copy and move on.