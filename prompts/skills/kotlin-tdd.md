---
name: kotlin-tdd
description: Write, review, and refactor idiomatic Kotlin code using a strict TDD workflow (red → green → refactor) with JUnit 5, MockK, and Turbine. Use this skill whenever the user asks to write a Kotlin class, function, or module; whenever they ask for a code review or refactoring of Kotlin code; whenever they mention TDD, unit tests, or test-first development in a Kotlin context; and whenever Kotlin coroutines, Flow, sealed classes, or data classes are involved. Also trigger when the user references .kt files, JUnit, MockK, or Turbine, even if they don't explicitly say "use TDD".
---

# Kotlin TDD

Write, review, and refactor Kotlin code the way a senior Kotlin engineer would: test-first, idiomatic, immutable by default, expression-oriented, and leaning on modern async APIs (Flow, coroutines) over callbacks or RxJava.

## Three entry points, one skill

This skill handles three related tasks. Decide which one applies, then read the matching reference file:

- **Writing new code** (user asks "write a X", "implement Y", "add a class that...") → read `references/writing-new-code.md`
- **Reviewing existing code** (user pastes code and asks for review, feedback, critique, or "what's wrong with this") → read `references/code-review.md`
- **Refactoring existing code** (user asks to clean up, restructure, modernize, or improve code that already works) → read `references/refactoring.md`

If it's ambiguous (e.g. "look at this and improve it"), ask once which they want — review produces feedback, refactor produces changed code.

## Core Kotlin principles (apply to all three entry points)

These are non-negotiable defaults. Deviate only with a written reason.

### Immutability and data shape

- `val` over `var`. `var` needs justification — typically only for local accumulators inside a function.
- Prefer `data class` for values. `class` only when identity matters or behavior dominates.
- Prefer `sealed class` / `sealed interface` for closed type hierarchies (states, results, events). Exhaustive `when` over `if/else` chains or polymorphism-by-string.
- Collections default to read-only (`List`, `Map`, `Set`). Use `MutableList` only inside a function's private scope and return the read-only view.
- Nullability is a modeling decision, not a convenience. If a value is "sometimes missing", make it `T?` and force the caller to handle it. If it's "never missing", don't make it nullable "just in case".

### Expression-oriented style

- Prefer `when` as an expression returning a value over `if/else if/else` chains.
- Scope functions (`let`, `also`, `apply`, `run`, `with`) used intentionally:
  - `let` — null-safe transform: `value?.let { transform(it) }`
  - `also` — side effect on the value, return value unchanged
  - `apply` — configure a receiver, return the receiver (builders)
  - `run` — execute a block with a receiver and return its result
  - `with` — same as `run` but non-extension form
  - If you can't say in one line which one fits and why, don't use any — write a named function.
- Early returns over nested conditions. Flat is better than deeply indented.
- Single-expression functions (`fun foo() = ...`) for pure transformations.

### Async and reactive

- `suspend fun` over callback-based APIs. Always.
- `Flow<T>` over `LiveData`, `Observable`, or callback-based streams.
- Cold `Flow` by default. Use `StateFlow` for state (hot, conflated, has current value), `SharedFlow` for events (hot, no initial value).
- `CoroutineScope` is injected, not created ad-hoc. ViewModels use `viewModelScope`; other components take a scope as a constructor parameter.
- Never use `GlobalScope`. Never use `runBlocking` outside `main` or tests.
- Dispatchers are injected too — don't hardcode `Dispatchers.IO` inside a class, take a `CoroutineDispatcher` in the constructor with an `Dispatchers.IO` default. This is essential for testability.

### Error handling

- Prefer `Result<T>` or a sealed result type (`sealed interface LoadResult { data class Success(...); data class Failure(...) }`) over throwing for expected failures.
- Throw only for programmer errors (invariants violated, bug states). Prefer specific exception types; catching `Exception` is acceptable at system boundaries (repositories, API clients) where you must convert any downstream failure into a result — but always rethrow `CancellationException` first. Never catch `Throwable`.
- Coroutine cancellation (`CancellationException`) must always be rethrown. If you catch a broad exception type inside a `suspend` function, rethrow `CancellationException` explicitly:
  ```kotlin
  try {
      doWork()
  } catch (e: CancellationException) {
      throw e
  } catch (e: IOException) {
      // handle
  }
  ```

### Structure and visibility

- `internal` over `public` for module-internal APIs. `private` for file/class-internal.
- Top-level functions over static utility classes.
- Extension functions to add behavior to types you don't own, not as a replacement for member functions on types you do own.
- One public type per file, named after the file. Small related helpers can share a file.

## The TDD loop

This skill writes tests first. Always. No exceptions unless the user explicitly overrides ("just write the code, skip tests").

The loop, in order:

1. **Red** — write a failing test that describes one behavior. The test must actually fail for the right reason (assertion fails, not compilation error). If the class doesn't exist yet, the test compiles against a minimal stub that returns a wrong value.
2. **Green** — write the minimum code to make the test pass. Not the elegant version — the minimum. Hardcoded return values are acceptable at this stage.
3. **Refactor** — with the test green, clean up both production code and test code. Tests must stay green after every change.
4. Repeat for the next behavior.

One behavior per test. A test named `returns empty list when source is empty and filter rejects all` is two tests, not one.

### Test structure

- **Naming**: backtick function names describing behavior: `` `returns Failure when network call throws` ``. Not `test1`, not `testGetUser`.
- **Arrange-Act-Assert** with blank lines between sections, even in short tests. Visible structure > saved lines.
- One logical assertion per test. If you need three assertions, they should all be about the same behavior (e.g. three fields of one returned object), not three separate behaviors.
- Test doubles: prefer fakes (hand-written minimal implementations of an interface) for anything used in >2 tests. MockK for one-off verification of interactions. If you find yourself writing `every { ... } returns ...` for five methods, you want a fake.

### Library-specific notes

- **JUnit 5**: `@Test`, `@BeforeEach`, `@Nested` for grouping related tests, `@DisplayName` optional (backtick names usually suffice).
- **MockK**: `mockk<T>()` for mocks, `mockk<T>(relaxed = true)` only when you genuinely don't care about unstubbed calls. `every { ... } returns ...` for stubbing, `coEvery` for suspend functions, `verify { ... }` and `coVerify` for interaction checks.
- **Turbine**: for testing `Flow`. `flow.test { ... }` block, inside use `awaitItem()`, `awaitComplete()`, `awaitError()`, `cancelAndConsumeRemainingEvents()`. Never collect a Flow manually in a test with `toList()` unless it's guaranteed finite and short.
- **Coroutine tests**: use `runTest { }` from `kotlinx-coroutines-test`. Inject `TestDispatcher` (typically `StandardTestDispatcher` via `testScheduler`) into the class under test. `advanceUntilIdle()` / `advanceTimeBy()` to control virtual time.

## Output format

Always produce actual Kotlin code in properly-fenced code blocks (` ```kotlin `). Multiple files → one code block per file, with the file path as the first line comment:

```kotlin
// core/src/main/kotlin/com/example/UserRepository.kt
package com.example
// ...
```

When presenting a TDD cycle, label the phases clearly: "Red:", "Green:", "Refactor:". Show the test file and production file separately.

When writing new code: tests first, then production code, then a short note on what was skipped and why (e.g. "I didn't add a test for the empty-list branch because it's covered by the `emptyList()` default — add one if you disagree").

When reviewing: see `references/code-review.md` for format.

When refactoring: see `references/refactoring.md` for format.

## When to ask vs when to write

Write without asking when the request is specific enough:
- "Write a `UserRepository` with `fun getUser(id: String): Flow<User>` backed by Ktor" — clear enough, proceed.
- "Add a test for the error case" — clear enough, proceed.

Ask before writing when:
- The public API shape is ambiguous (suspend vs Flow? nullable return vs Result?).
- There's no hint about dependencies (is this Android, pure JVM, KMP?).
- Multiple fundamentally different designs would all fit ("cache for users" could be in-memory TTL, LRU, persisted, reactive — each leads to a different class).
- The user says "something like X" — "something like" is a signal they haven't decided.

**How to ask**: one clarifying *message* maximum, not one question. That message can list multiple options (labeled A/B/C/D) or ask about several related dimensions at once — but the user shouldn't have to answer, wait, answer again, wait. One round trip.

**Always include a fallback**: at the end of the clarifying message, state what you'll do if the user says "just pick one" or gives a vague answer. Example: "If you say 'keep it simple', I'll go with A — in-memory TTL cache with injected Clock." This way the user can opt out of deciding.

**One question maximum in the message** if a single axis matters more than the others. If you're presenting 4 full options (A/B/C/D), that counts as one question. Don't also ask about testing framework preference in the same message — stick to the decision that unblocks the work.

After the clarifying round, make assumptions for anything still unclear, write the code, and note the assumptions inline ("I assumed the API is `suspend`, not callback-based — happy to adapt if not").

## Comments

Kotlin code speaks for itself. Comments explain *why*, not *what*. If a block needs a comment to explain what it does, rename the variables or extract a function instead.

Exceptions: KDoc on public API, non-obvious performance tradeoffs, workarounds for library bugs (link the issue).

**Important**: all code comments in generated code must be in English, regardless of the conversation language.


---
<!-- reference: references/code-review.md -->

# Kotlin code review

Use when the user pastes code and asks for review, feedback, critique, or "what's wrong". The output is *feedback on their code*, not a rewrite — unless they explicitly ask for one.

## What to look for, in priority order

Review top-down. A correctness bug matters more than a style preference. Don't bury critical findings under nitpicks.

### 1. Correctness and safety

- **Coroutine cancellation**: is `CancellationException` accidentally swallowed by a broad catch? This is the #1 Kotlin-specific correctness bug.
- **Leaked scopes**: `GlobalScope`, `CoroutineScope(Job())` created ad-hoc in a class, scope never cancelled.
- **Race conditions**: mutable state accessed from multiple coroutines without `Mutex` or without being on a single-threaded dispatcher.
- **Null safety shortcuts**: `!!`, `lateinit var` that can be read before init, `requireNotNull` on a value that could legitimately be null at runtime.
- **Wrong Flow operator**: using `collect` where `collectLatest` is needed (or vice versa), `combine` vs `zip` confusion, missing `flowOn` for expensive upstream work.
- **StateFlow misuse**: `MutableStateFlow` exposed publicly instead of `.asStateFlow()`; updating via `.value = computeNew(_state.value)` instead of `.update { }` (the latter is atomic, the former has a TOCTOU gap under concurrency).

### 2. Testability

- Hardcoded dependencies instead of injected (dispatchers, clocks, random, side-effecting services).
- Functions that are untestable because they create their own collaborators inside.
- Static/singleton state that tests can't reset.
- Long functions that force integration-style testing when behavior could be split.

### 3. API design

- Public API leaking implementation details (`MutableStateFlow` exposed, internal types in public signatures).
- Nullable returns where a sealed result type would communicate more (`User?` vs `UserLoadResult`).
- Boolean parameters that should be enums (`notify = true` → `notificationMode = NotificationMode.Silent | Loud`).
- Too many parameters; parameter object would help.
- `fun` where `suspend fun` is warranted, or `suspend fun` returning `Unit` when a Flow of progress would serve the caller better.

### 4. Idiomatic style

- `var` where `val` works.
- `if/else` chains on a sealed type (should be `when`).
- Manual null-checks where `?.`, `?:`, `let` would read cleaner.
- Imperative loops building a list where `map`/`filter`/`fold` would be clearer.
- Scope functions used without clear purpose (nested `apply` inside `also` inside `let` — pick one or none).
- Data classes used where behavior dominates, or regular classes used where a value type fits.

### 5. Test quality (if tests are included)

- Tests that test the mock, not the code (only `verify` calls, no state assertions).
- Single test covering multiple behaviors.
- Over-mocking: every collaborator mocked when a fake would be simpler and more robust.
- No test for the error path.
- Flow tested by `toList()` where Turbine would be safer.
- `runBlocking` in tests instead of `runTest`.

### 6. Minor / style

Small readability improvements, naming, comment clarity. Keep these brief — don't drown the important findings.

## Format

Structure the review as:

```
## Review of [component name]

### Critical
<issues that affect correctness, safety, or cause bugs. Empty section is OK — write "None." >

### Important
<testability, API design, significant idiomatic issues>

### Minor
<style, naming, small readability wins>

### What's done well  [OPTIONAL — default is to omit this section]
<See rules below.>
```

**Rules for "What's done well":**

Default is to **omit the section entirely**. Adding it costs the user attention with low signal. Only include it when at least one of these is true:

1. The code is actually good and the review is short (mostly empty Critical / Important sections) — then the praise carries real information.
2. There's a specific non-obvious thing the author did right that you want to reinforce so they keep doing it (e.g. "good call injecting the `Clock` instead of using `System.currentTimeMillis()` — made the whole thing easy to test").
3. The author's message signals they want some positive feedback ("harsh but fair review please", "first time writing Kotlin, how'd I do").

**Do not include it** when:

- You had to reach for bullets (if you catch yourself writing "uses MutableStateFlow — correct choice for UI state" while simultaneously flagging it as leaked, that's not praise, that's filler).
- The praise is just "you used a standard language feature correctly" (using `data class`, `val`, or `suspend fun` correctly is the floor, not the ceiling).
- The review is long and critical — adding two weak positives at the end doesn't soften the blow, it just buries the important findings further.

If you include the section: 1–3 bullets, each pointing to something specific, not vague. "Good coroutine usage" is filler; "`flowOn(dispatcher)` right before the terminal operator, not upstream of a `map` — correct placement" is a genuine bullet.

For each finding:

1. **Where**: line number, function name, or quoted snippet.
2. **What**: the problem in one sentence.
3. **Why**: the consequence — what breaks, what's hard to test, what's confusing.
4. **Fix**: a concrete suggestion, ideally with a short code snippet.

Example finding:

> **`UserRepository.kt`, `fetchUser()`** — the `catch (e: Exception)` block swallows `CancellationException`, so if the calling coroutine is cancelled during `api.call()`, cancellation is converted into `LoadResult.Failure`. This breaks structured concurrency — callers that cancel and expect the flow to stop will instead see a spurious failure emission.
>
> Fix: rethrow cancellation explicitly.
> ```kotlin
> } catch (e: CancellationException) {
>     throw e
> } catch (e: IOException) {
>     emit(LoadResult.Failure(e))
> }
> ```

## Tone

Direct, specific, not performatively polite. "This is wrong because X" beats "you might want to consider possibly reviewing whether X could potentially..." — the user wants signal, not cushioning.

Disagreements with the user's choices are fine; say so and give the reasoning. If a choice is defensible and you'd just do it differently, say that too ("I'd use a sealed type here, but your nullable return is defensible if X").

## What not to do

- Don't rewrite the whole file unless asked. The user wrote it; they want to learn what to change.
- Don't invent problems. If the code is good, say so and keep the review short.
- Don't nitpick formatting the IDE already handles (spacing, import order).
- Don't cite "best practices" abstractly — always tie back to a concrete consequence in *this* code.

---
<!-- reference: references/refactoring.md -->

# Kotlin refactoring

Use when the user has working code and wants it cleaned up, restructured, modernized, or improved — without changing external behavior.

The iron rule: **tests stay green after every step**. If there are no tests, write them first.

## Is this actually a refactor?

If the user said something ambiguous like "improve this" or "look at this", confirm once before proceeding:

- **Refactor** — you change the code, behavior stays the same, user gets modified files back.
- **Review** — user keeps their code, you give feedback, user decides what to change.
- **Rewrite** — you throw out the existing code and write a new version. This is a different beast; flag it.

These produce very different outputs. If you can tell from context ("clean up this ViewModel", "extract the network layer" → refactor; "is this idiomatic?", "what would you change?" → review), just proceed. If you can't tell, ask.

## Pre-flight checks

Before touching a single line:

1. **Are there tests?** If no, refactor is unsafe. Say so, and offer to write characterization tests first (tests that pin down current behavior, even quirky behavior). Don't skip this — silent behavior change is the failure mode of refactoring.

   A characterization test doesn't assert what the code *should* do — it asserts what it *currently does*, including bugs. You run the code, observe the output, and pin it down:

   ```kotlin
   @Test
   fun `characterization - formatPrice returns empty string for negative input`() {
       // This is the current behavior as of [date / commit]. Not necessarily correct,
       // but we're pinning it so the refactor doesn't change it silently.
       assertEquals("", formatPrice(-5.0))
   }
   ```

   Write one per observable behavior, even edge cases that look like bugs. Refactor, then decide separately whether to fix the bugs (that's a behavior change, not a refactor).

2. **Do the tests actually pass right now?** Run them mentally or ask. Refactoring broken code is debugging, not refactoring.
3. **What's the goal?** "Make it better" is not a goal. Extract what specifically: readability? testability? removing duplication? splitting a god class? Modernizing from Java-style to idiomatic Kotlin? Name the target.

4. **Scope check — what's public, what's internal?** Before proposing any change that touches a signature, constructor, or data class shape, ask: *who else uses this?* A `data class Order(val status: String)` might be serialized to JSON, stored in Room, sent over a wire, or depended on by 12 other files. Changing `status: String` to `status: OrderStatus` inside the target class is safe; changing it on the shared `Order` is a breaking change disguised as a refactor.

   Rule of thumb for this skill's scope:
   - **Private / file-local / `internal`** — refactor freely.
   - **`public` API of the class being refactored** — flag clearly; only change if the user accepted it as the goal.
   - **Shared types used outside the refactor target** — don't touch. Introduce a local sealed type instead, and map at the boundary.

   If you catch yourself mid-step realizing the change leaks outside the target, stop and flag it — don't silently narrow the scope hoping the user won't notice.

If the user hasn't given a clear target, ask once, then proceed with an explicit assumption.

## Common refactor patterns

### Extract function

**When**: a block inside a function has a clear single purpose and a name you can give it.

```kotlin
// Before
fun process(input: List<String>): Report {
    val filtered = input.filter { it.isNotBlank() && !it.startsWith("#") }
        .map { it.trim().lowercase() }
        .distinct()
    // ... more code using filtered ...
}

// After
fun process(input: List<String>): Report {
    val normalized = input.normalize()
    // ... more code using normalized ...
}

private fun List<String>.normalize(): List<String> =
    filter { it.isNotBlank() && !it.startsWith("#") }
        .map { it.trim().lowercase() }
        .distinct()
```

### Replace nullable return with sealed result

**When**: `null` is overloaded to mean multiple things ("not found", "error", "not loaded yet").

```kotlin
// Before
suspend fun getUser(id: String): User?

// After
suspend fun getUser(id: String): UserResult

sealed interface UserResult {
    data class Found(val user: User) : UserResult
    data object NotFound : UserResult
    data class Error(val cause: Throwable) : UserResult
}
```

### Replace if-chain with when on sealed type

**When**: branching on a type or a stringly-typed tag.

```kotlin
// Before — stringly typed, no compiler help if a new status appears
fun label(status: String): String {
    return if (status == "loading") "Loading…"
    else if (status == "success") "Done"
    else if (status == "error") "Failed"
    else "Unknown"
}

// After — exhaustive when on a sealed type, compiler tells you if a branch is missing
sealed interface Status {
    data object Loading : Status
    data object Success : Status
    data class Error(val message: String) : Status
}

fun label(status: Status): String = when (status) {
    Status.Loading -> "Loading…"
    Status.Success -> "Done"
    is Status.Error -> "Failed: ${status.message}"
}
```

The win: add a new `Status` variant and the compiler lights up every `when` that handles it. Stringly-typed code silently falls through to the `else`.

### Inject the dispatcher

**When**: a class hardcodes `Dispatchers.IO` or `Dispatchers.Default`.

```kotlin
// Before
class Repo {
    suspend fun load() = withContext(Dispatchers.IO) { ... }
}

// After
class Repo(private val dispatcher: CoroutineDispatcher = Dispatchers.IO) {
    suspend fun load() = withContext(dispatcher) { ... }
}
```

### Replace MutableStateFlow leak with asStateFlow

**When**: a ViewModel exposes `MutableStateFlow` publicly.

```kotlin
// Before
val state = MutableStateFlow<State>(State.Idle)

// After
private val _state = MutableStateFlow<State>(State.Idle)
val state: StateFlow<State> = _state.asStateFlow()
```

### Replace .value = f(.value) with .update { }

**When**: state is updated based on its previous value.

```kotlin
// Before
_state.value = _state.value.copy(count = _state.value.count + 1)

// After
_state.update { it.copy(count = it.count + 1) }
```

### Replace callback with suspend / Flow

**When**: Java-style callback or listener API in Kotlin code.

Wrap with `suspendCancellableCoroutine` or `callbackFlow`. Make sure to handle cancellation and remove the listener in the cleanup block (`invokeOnCancellation` / `awaitClose`).

### Split a god class

**When**: one class has multiple responsibilities (fetching + caching + mapping + UI state).

Steps:
1. Identify the seams. Usually there are 2-4 logical chunks.
2. For each chunk, extract an interface describing just what it does.
3. Create the new class implementing that interface.
4. Inject the new class into the god class; delegate calls.
5. Move the tests for each chunk to the new class's test file.
6. Once all chunks are extracted, the god class is either a thin coordinator (fine) or empty (delete it).

Do this one chunk at a time, tests green between each step.

## The refactor step pattern

Each atomic refactor follows this pattern:

1. **Run tests** — confirm green starting state.
2. **Make one small change** — the smallest meaningful unit (extract one function, rename one thing, inline one variable).
3. **Run tests** — must still be green. If not, revert.
4. **Commit** (or note as a checkpoint).
5. Next change.

If you find yourself doing two things at once ("I'll extract this function *and* change its signature"), split: extract first (tests green), change signature second (tests green).

## Flag, don't fix

A refactor preserves behavior. That means: if you notice a bug while refactoring, **do not fix it in the same refactor**. Flag it at the end and let the user decide whether to address it as a separate task.

Why: bug fixes change behavior. If you fix a bug during a refactor, the characterization tests that pinned current behavior either need updating (silently, inside the refactor) or will fail (breaking the "tests stay green" invariant). Either way, the refactor is no longer auditable — a reviewer can't tell which line changed semantics and which was pure restructuring.

What to flag:
- Logic bugs in branches you're restructuring ("this `else` branch is never reachable").
- Concurrency issues (`MutableList` iterated while possibly mutated from another thread).
- Error messages that leak internals or mislead users.
- Nullable returns that hide real error cases (null == "network error" — user can't tell).
- Bad defaults in `CoroutineScope`, dispatcher, or timeout values.

How to flag: in the "What was not changed and why" section at the end, list each issue with:
- What you saw.
- Why it's a behavior change, not a refactor.
- A short suggested direction for fixing it separately.

Example:

> **`listeners: MutableList` is not thread-safe.** Adding a listener from thread A while `processOrder` iterates from thread B throws `ConcurrentModificationException`. Not fixed here because the correct fix (switch to `CopyOnWriteArrayList` or replace the listener pattern with a `SharedFlow`) changes semantics: listeners added mid-iteration currently see the event on some runs and not others — any replacement picks one answer. Suggest: separate ticket, decide on the semantics first.

The one exception: **if leaving the bug in place makes the refactor itself unsafe** (e.g., a race condition that would now fire more often because coroutines replace a thread), say so and ask the user whether to stop, or to fix the race first as a pre-refactor step with its own tests.

## Output format

When refactoring, structure the response as:

1. **Baseline check**: confirm tests exist and pass (or note that they need to be written first).
2. **Plan**: list the refactor steps in order, as a short numbered list. Each step should be one atomic change.
3. **Execution**: for each step, show:
   - The change (diff-style or before/after snippets).
   - Why it's safe (what property it preserves).
   - Which tests cover it.
4. **Final state**: the finished code, fully assembled.
5. **What was not changed and why**: scope is easy to creep. If you saw other issues but left them alone, say so.

## Anti-patterns to avoid when refactoring

- Changing behavior "while I'm in there". If behavior needs to change, that's a separate task.
- Renaming alongside restructuring in one step — two cognitive loads at once.
- Rewriting instead of refactoring. If you delete the old code and write new code, it's a rewrite; say so clearly and the user can decide if that's what they wanted.
- Refactoring without tests. Offer to write characterization tests first.
- Optimizing prematurely. Readability first; performance refactor only with a measured reason.

---
<!-- reference: references/writing-new-code.md -->

# Writing new Kotlin code

Use when the user asks to write a new class, function, module, or feature. Follow the TDD loop from SKILL.md.

## The workflow

### 1. Clarify the shape (if ambiguous)

Before writing a single line, make sure you know:
- **Input**: what does the caller pass in? Types, nullability, collections.
- **Output**: what comes back? `T`, `T?`, `Flow<T>`, `Result<T>`, `suspend fun` that returns?
- **Side effects**: does this touch the network, disk, DB? Those become injected dependencies.
- **Failure modes**: what can go wrong and how is it communicated?

If any of these is unclear and you have to guess, either ask one question or make a choice and state it out loud before writing.

### 2. Sketch the public API

Before tests, write the minimal interface/class signature as a stub. This is what the first test will compile against.

```kotlin
class UserRepository(
    private val api: UserApi,
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    fun getUser(id: String): Flow<LoadResult<User>> = TODO()
}
```

The stub returns `TODO()` or a wrong-but-compilable value. Tests will drive out the real implementation.

### 3. Red — first failing test

Pick the simplest meaningful behavior. Often "happy path with minimal input". Write it in AAA form:

```kotlin
class UserRepositoryTest {

    private val api = mockk<UserApi>()
    private val dispatcher = StandardTestDispatcher()
    private val repository = UserRepository(api, dispatcher)

    @Test
    fun `emits Success with user when api returns successfully`() = runTest(dispatcher) {
        // Arrange
        val expectedUser = User(id = "42", name = "Ada")
        coEvery { api.fetchUser("42") } returns expectedUser

        // Act & Assert
        repository.getUser("42").test {
            assertEquals(LoadResult.Success(expectedUser), awaitItem())
            awaitComplete()
        }
    }
}
```

Run it. It must fail — and fail on the assertion, not on compilation. If it fails with `NotImplementedError` from `TODO()`, that counts as a valid red.

### 4. Green — minimum implementation

Write the least code that makes the test pass. Don't anticipate future tests.

```kotlin
fun getUser(id: String): Flow<LoadResult<User>> = flow {
    emit(LoadResult.Success(api.fetchUser(id)))
}.flowOn(dispatcher)
```

Run the test. Green.

### 5. Refactor

Look at both the test and the production code. Anything unclear? Any duplication? Any stringly-typed thing that should be a sealed type? Clean it up. Tests must stay green.

At this stage, if you see a missing branch (error case, empty case, edge input), that's the next red test.

### 6. Next behavior

Pick the next behavior. Common sequence:
1. Happy path
2. Primary error path (network fails, returns null, etc.)
3. Edge cases (empty input, boundary values)
4. Cancellation / concurrency behavior (if relevant)

## Default skeletons

### ViewModel with StateFlow

```kotlin
class FeatureViewModel(
    private val repository: FeatureRepository,
    private val dispatcher: CoroutineDispatcher = Dispatchers.Default,
) : ViewModel() {

    private val _state = MutableStateFlow<FeatureState>(FeatureState.Idle)
    val state: StateFlow<FeatureState> = _state.asStateFlow()

    fun onAction(action: FeatureAction) {
        when (action) {
            is FeatureAction.Load -> load(action.id)
            FeatureAction.Retry -> /* ... */
        }
    }

    private fun load(id: String) {
        viewModelScope.launch(dispatcher) {
            repository.observeFeature(id).collect { result ->
                _state.update { toState(result) }
            }
        }
    }

    private fun toState(result: LoadResult<Feature>): FeatureState = when (result) {
        LoadResult.Loading -> FeatureState.Loading
        is LoadResult.Success -> FeatureState.Content(result.value)
        is LoadResult.Failure -> FeatureState.Error(result.error.message ?: "Unknown")
    }
}

sealed interface FeatureState {
    data object Idle : FeatureState
    data object Loading : FeatureState
    data class Content(val data: Feature) : FeatureState
    data class Error(val message: String) : FeatureState
}

sealed interface FeatureAction {
    data class Load(val id: String) : FeatureAction
    data object Retry : FeatureAction
}
```

### Repository returning Flow

```kotlin
class FeatureRepository(
    private val api: FeatureApi,
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    fun observeFeature(id: String): Flow<LoadResult<Feature>> = flow {
        emit(LoadResult.Loading)
        val result = try {
            LoadResult.Success(api.fetch(id))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            LoadResult.Failure(e)
        }
        emit(result)
    }.flowOn(dispatcher)
}

sealed interface LoadResult<out T> {
    data object Loading : LoadResult<Nothing>
    data class Success<out T>(val value: T) : LoadResult<T>
    data class Failure(val error: Throwable) : LoadResult<Nothing>
}
```

## Anti-patterns to avoid when writing new code

- Writing production code before the test that requires it.
- Adding "just in case" nullability, parameters, or branches not driven by a test.
- Hardcoding `Dispatchers.IO` inside a class (inject instead).
- Using `!!` (non-null assertion). If you "know" it's not null, the type should say so; otherwise handle the null.
- Throwing from a function whose signature returns `Result`/`LoadResult` (the whole point is no throw).
- `runBlocking` anywhere except `main` or tests.
- One giant test method covering five behaviors.

## Output format

When delivering new code, structure the response as:

1. Brief plan (2-3 sentences): what you're building and in what order.
2. **Red** — the first failing test, in a Kotlin code block with file path.
3. **Green** — the implementation that makes it pass.
4. **Refactor** — if anything needed cleanup, show the diff or the final version.
5. Next iterations: repeat 2-4 for each subsequent behavior.
6. At the end: what's left untested, and why.
