---
name: compose-component-creator
description: Create idiomatic, testable Jetpack Compose components following Material 3 best practices, with multi-variant Previews, test tags, and behavioral tests using ComposeTestRule. Use this skill whenever the user asks to create, refactor, or review any @Composable component — list rows, cards, buttons, input fields, small composed widgets, or screen skeletons. Also trigger when the user provides a screen mockup, Figma export, Claude Design file, or phone screenshot and asks to turn it into Compose code; when they mention a sealed UiState class that a component should render; when .kt files with @Composable annotations are involved; or when the user mentions Compose + testTag, semantics, mergeDescendants, PreviewParameter, or ComposeTestRule. Do NOT use for full-app architecture (ViewModels, navigation graphs, DI modules) — use only for the UI layer.
---

# Compose Component Creator

Create small, testable Jetpack Compose components following Material 3 conventions, with multi-variant Previews and behavior-focused Compose tests. This skill targets UI-layer work: composables, Previews, test tags, and `ComposeTestRule` tests. It does not design ViewModels, repositories, or navigation.

## Core philosophy

Three non-negotiables shape every component this skill produces:

1. **Stateless composables driven by UiState.** The component receives state (typically a sealed class) and callbacks as parameters. It renders — it does not fetch, compute, or own business state. This is what makes it testable and previewable.
2. **Previews verify looks, tests verify behavior.** Don't try to test layout quality with assertions — humans do that by eye. Tests prove that *given state X, node Y exists and is displayed* and that *clicking node Z fires the right callback*. Everything visual (colors, spacing, typography, truncation) is judged through Previews.
3. **Small composables with clear responsibility.** If a composable grows unwieldy, extract sub-composables — not mechanically by line count, but when a fragment has its own cohesive responsibility (reusable, independently testable, or named meaningfully).

## When the user provides input

Users bring different levels of specification. Adapt to what you have:

- **A sealed `UiState` class** (text or code) → component renders each variant. This is the strongest signal; treat variants as the component's contract.
- **A screenshot / phone screen capture / Figma export / Claude Design file** → extract hierarchy and interaction affordances. Use Material 3 tokens only where the user's design system clearly specifies them; otherwise use `MaterialTheme.colorScheme` / `typography` / `shapes` as placeholders and flag the substitution in your response.
- **A prose description** ("a list row with avatar, title, subtitle, unread badge") → sketch a reasonable hierarchy, then confirm before generating if anything is ambiguous.

**When ambiguous, ask — don't guess.** Guessed layout is expensive to undo. Good things to ask about: which state variants exist, whether a visual element is interactive, whether two similar elements should be the same component or different, which test tags matter for the user's test strategy.

**Asking vs. defaulting — when to pick which.** Not every ambiguity is worth a round trip. If the standard interpretation of the request is obvious and the cost of being wrong is low (user scans the output, changes a line), pick sensible defaults and ship — just flag each decision in the output report so the user can spot and correct. If getting it wrong would reshape the component's contract (UiState variants, what counts as a separate callback, whether two similar-looking things are one component or two), stop and ask.

Rules of thumb:
- **Default + flag**: which icon to use, placeholder colors for brand tokens, package path when user gave only a module, choice between `titleLarge` vs `titleMedium` for a header, whether a string field can be empty.
- **Ask first**: whether `Loading` / `Empty` / `Error` variants exist beyond what was described, whether a visually distinct child element (like "View details →") has its own callback or shares the parent's, whether a row is meant to be used alone or in a list.

When you default, say so plainly in the output: *"Assumed X — change to Y if that's wrong."* Silent defaults are the problem, not defaults themselves.

## Location — always ask if not given

Before writing any file, confirm where it goes. Accept any of:
- module path (e.g., `feature-<name>`)
- package (e.g., `com.example.feature.ui.components`)
- full filesystem path

If the user names only a module, default to `ui/components/` for small composed widgets and `ui/screens/` for screen skeletons, but state your assumption and let them correct it.

## Workflow (TDD)

Follow this order. The user has explicitly opted into TDD for behavioral tests; the rhythm is red → green → refactor, one UiState variant at a time. Preview is added alongside, not before.

### 1. Define the contract

If the user hasn't provided a `UiState`, first **look for an existing one** in the target module before proposing a new one. Typical search:

- grep for `sealed.*UiState` / `sealed.*State` in the module
- check for `<ComponentName>UiState.kt`, `<ComponentName>State.kt`
- look inside `*ViewModel.kt` files — UiState is often declared nearby

If found, use it as the contract and note the location in the output. If the user mentioned a ViewModel by name, look in it specifically.

If nothing exists, propose a sealed interface/class with variants matching the states the component must render. Example shape:

```kotlin
sealed interface UserRowUiState {
    data object Loading : UserRowUiState
    data class Content(val name: String, val email: String, val unread: Int) : UserRowUiState
    data class Error(val message: String) : UserRowUiState
}
```

Confirm this with the user before proceeding if you invented it — flag clearly in the output ("Invented UiState — confirm or replace with your own").

### 2. Declare test tags as constants

Put tags in a top-level `object` near the component — not scattered inline string literals. This keeps them discoverable from tests and prevents typos.

```kotlin
internal object UserRowTestTags {
    const val ROOT = "user_row_root"
    const val LOADING = "user_row_loading"
    const val CONTENT = "user_row_content"
    const val ERROR = "user_row_error"
    const val UNREAD_BADGE = "user_row_unread_badge"
}
```

**Visibility — default to `internal` for feature modules.** Test tags exist to serve tests of that module. They are not part of the module's public API. `internal` keeps them accessible from tests in the same module (Gradle test source sets can see `internal` members of `main`) while preventing other modules from depending on them.

- **Multi-module / feature-module projects** → `internal` is the right default.
- **Single-module apps** (one `app` module) → `internal` still works; `public` also works if you need to reference tags from shared test utilities.
- Never make them `private` — tests in `src/androidTest` or `src/test` of the same module will not see them.

Usage from tests: `UserRowTestTags.ROOT`, `UserRowTestTags.CONTENT`, etc. `object` is a singleton, so tags are statically accessible without an instance.

Tag the *root of each variant* and any element a test needs to assert on or interact with. Don't tag purely decorative elements.

**Stick to static tags by default.** When generating a single component, use plain string constants. Only reach for parameterized tags (e.g., `fun root(id: String)`) when the user explicitly asks for a list, multiple instances, or otherwise indicates the component will appear more than once on one screen. Otherwise it's overengineering — the cost is real (more API surface, more things to pass around) and the payoff only appears in the multi-instance case. If the user's request is for "a row" (singular), generate `const val ROOT = "..."` and move on.

### 3. Red: write the first failing test

Pick the simplest variant (usually `Loading`). Write one test that sets the composable with that state and asserts the expected tagged node exists and is displayed. See the testing section below for the shape.

### 4. Green: write minimum composable to pass

Implement just enough to make that test green. Often a `Box` with a spinner and the right `testTag`. Do not implement other variants yet.

### 5. Repeat for each variant

One variant, one test, one implementation step. Add interaction tests (click → callback) the same way.

### 6. Add Previews alongside

After each variant works, add a `@Preview` showing it. Don't wait until the end — previews are how you sanity-check while iterating. Use the variant set from the Preview section below.

### 7. Refactor

When all variants pass and previews look right, look at the composable. If it has distinct responsibilities you can name (e.g., `UserAvatar`, `UnreadBadge`), extract them — each becomes its own small composable with its own Preview. Don't extract for the sake of it; extract when the name is obvious and the sub-composable has a cohesive purpose.

Heuristics that suggest extraction:
- a block has its own internal conditional logic
- a block is reused in two places
- you can name the block without resorting to "Section1" / "TopPart"
- a block has meaningful independent test cases

Heuristics against extraction:
- the sub-composable would take 5+ parameters to reconstruct its context
- the name would be generic ("TheBottomRow")
- it's only visual grouping with no independent meaning

Size is a *signal* not a rule. Large composables are a prompt to *look* at whether extraction helps — sometimes it does, sometimes the monolith reads better.

**Recomposition awareness when extracting.** Unstable parameters (e.g., `List<Foo>` where `Foo` is not stable, or lambdas captured in certain ways) can break skippability and cause extracted children to recompose unnecessarily. Keep parameters stable: prefer `ImmutableList`/primitive types, hoist lambdas with `remember`, and mark data classes intentionally. If you're unsure whether extraction will help or hurt performance, say so rather than guessing.

## Composable API conventions

- **Parameters in this order**: required data, `modifier: Modifier = Modifier`, optional data with defaults, callbacks with defaults (`= {}`).
- **Always accept `Modifier`** — never bake padding/size into the component when the caller might want to override.
- **Callbacks are named `on<Event>`** — `onClick`, `onRetry`, `onItemSelected`. Avoid `listener` or `handler`.
- **Never hardcode dimensions or colors** — use `MaterialTheme.colorScheme.*`, `MaterialTheme.typography.*`, `MaterialTheme.shapes.*`. For spacing, prefer a small set of constants (`dp` values in a companion object) over magic numbers.
- **No business logic inside the composable** — no network calls, no database, no computation that should live in a ViewModel. If the design tempts you, it's a signal the contract is wrong.
- **State hoisting** — if a child needs state, lift it to the parent and pass `value + onValueChange`. The composable this skill produces is almost always stateless from the caller's perspective.

## Semantics — when and why

Semantics is how TalkBack and tests see the UI. Use these three deliberately:

- **`Modifier.semantics(mergeDescendants = true) { }`** — use when a group of elements represents a single logical unit to the user. **List rows are the canonical case**: an avatar + name + subtitle + badge should be announced as one item, and it's dramatically easier to test (`onNodeWithTag("user_row_root").performClick()` instead of hunting through children). Use it for cards that act as single clickable units too.

  **Before applying `mergeDescendants`, check: does any child have its own independent interaction?** Examples that block merging: a "View details" text with its own `onClick`, a trailing "Delete" icon button, a toggle inside the row, an inline link. If yes, **do not merge** — merging hides those interactions from TalkBack (the screen reader will announce only the row-level click and skip the nested actions). In those cases, leave the root unmerged and let each interactive child be announced separately. A card or row with a single clickable responsibility gets `mergeDescendants`; one with multiple independent actions does not.
- **`contentDescription`** — for images/icons that convey meaning. Decorative icons should get `contentDescription = null`, not an empty string.
- **`stateDescription`** — for elements whose state isn't obvious from the content (a custom toggle, an expandable card). Don't add it where default semantics already cover it (standard `Switch`, `Checkbox`, etc.).

When in doubt, ask: "how should a screen reader announce this?" and work backward.

## Material 3

Use Material 3 components and theming as default:

- `MaterialTheme.colorScheme` for colors (`primary`, `surface`, `surfaceVariant`, `onSurface`, `error`, etc.)
- `MaterialTheme.typography` for text styles (`titleMedium`, `bodySmall`, `labelLarge`, etc.)
- `MaterialTheme.shapes` for corner radii
- Prefer M3 components (`Card`, `ElevatedButton`, `ListItem`, `FilledIconButton`) over manual `Box` constructions when the semantics match.

For a component cheat sheet and "which variant for which case", read `references/material3-components.md` when you need a reminder. Don't paste the whole thing into the response — consult it, then write.

**When the cheat sheet isn't enough — search the web.** The cheat sheet covers stable, common M3 components. Newer components (e.g., from `material3-adaptive`, `material3-adaptive-navigation-suite`), recently added APIs, and components that have changed signatures between versions may not be there or may be out of date. If the user asks for a component you don't recognize from the cheat sheet, or you're unsure about the current API shape, web-search the official docs (`developer.android.com/jetpack/compose/...` or `developer.android.com/reference/kotlin/androidx/compose/material3/...`) rather than guessing a signature. Cite what you found so the user can verify.

### Surface vs Box-with-background — don't over-reach for Surface

`Surface` is useful but over-used. It does four things at once: theme-aware background color, shape + clipping, tonal elevation, and a11y surface role. Reach for `Surface` when you need *that combination*. For just a colored background, just a clipped shape, or just a clickable area, **use `Modifier` directly** — it produces fewer composition nodes and is faster to recompose.

**Use `Surface` when:**
- The element is a semantic "surface" that should respond to theme elevation (cards, elevated containers, dialogs)
- You need tonal elevation (M3 derives surface color from elevation level)
- You want the a11y surface role

**Don't use `Surface` when:**
- You just need a background color → `Modifier.background(MaterialTheme.colorScheme.xxx)`
- You just need a rounded/circular shape → `Modifier.clip(CircleShape)` or `Modifier.clip(MaterialTheme.shapes.medium)`
- You just need both → combine the two modifiers
- You're wrapping a single `Text` or `Icon` in it — that's almost always unnecessary

### Avoid redundant container nesting

Every `Box` / `Surface` / `Column` / `Row` is a node in the composition tree. Nesting them without a reason adds work to layout and recomposition, and makes the code harder to read. The common anti-pattern looks like this:

```kotlin
// ❌ Three levels to render one centered piece of text on a circle
Box(modifier = Modifier.size(40.dp).clip(CircleShape)) {
    Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = CircleShape) {
        Box(contentAlignment = Alignment.Center) {
            Text(text = initials)
        }
    }
}

// ✅ One level, same result
Box(
    modifier = Modifier
        .size(40.dp)
        .clip(CircleShape)
        .background(MaterialTheme.colorScheme.primaryContainer),
    contentAlignment = Alignment.Center,
) {
    Text(text = initials)
}
```

**The rule**: before adding a container, ask *what does this container contribute?* If the answer is "nothing that a modifier on the parent couldn't do", remove it. Signals that you're nesting unnecessarily:

- A `Box` whose only child is a single `Text`/`Icon` and the `Box` only sets `contentAlignment` — fold alignment into the parent or use `Modifier.align()` on the child if the parent is a `Column`/`Row`.
- A `Surface` wrapping a single child just to get a background color — use `Modifier.background()`.
- A `Column`/`Row` with one child — delete the wrapper.
- Two consecutive containers of the same type (`Box { Box { ... } }`) — one of them is redundant unless they have genuinely different responsibilities (e.g., outer sets size, inner sets padding that shouldn't affect size).

Exception: don't over-flatten when it hurts readability. A single extra `Box` wrapper that makes testTag/semantics application obvious is fine.

## Previews — the standard set

Every component ships with Previews that cover visual edge cases. For each `UiState` variant, generate Previews with:

1. **Happy path** — realistic mocked data
2. **Long strings** — names/titles that overflow; verify truncation/wrapping looks right
3. **Empty strings** — empty but valid content (where the contract allows it)
4. **Large numbers** — within the component's contract (if the contract says "up to 3 digits", don't preview 10000; preview 999)
5. **Dark mode** — one `uiMode = UI_MODE_NIGHT_YES` preview per critical variant

On request (not by default):
- RTL (`locale = "ar"`)
- Font scale (`fontScale = 2.0f` on `@Preview`)
- Narrow width (`widthDp = 320`)

When multiple variants × multiple data shapes would produce a wall of `@Preview` functions, use `@PreviewParameter` with a `PreviewParameterProvider`. See `references/preview-patterns.md` for the pattern and concrete examples.

**Mocked data placement — keep preview-only classes out of release builds.**

`@Preview` functions themselves are fine to keep next to the component in `src/main/` — they're `private`, Android Studio finds them automatically, and their runtime footprint is negligible. But `PreviewParameterProvider` classes and nasty-data `object`s (`NastyStrings`, hardcoded mock users, etc.) are regular classes holding test data. Without help they *are* compiled into release APKs.

The native Android Gradle Plugin way to prevent this is **build variant source sets**. Every Android module has a `debug` and `release` variant, and AGP automatically includes `src/debug/kotlin/` only in debug builds. Placing preview-only classes there strips them from release entirely.

**Recommended placement:**

- `@Preview` composables → stay in `src/main/kotlin/<package>/` next to the component (Android Studio DX)
- `PreviewParameterProvider` classes + nasty-data objects → `src/debug/kotlin/<package>/preview/`
- Mark them `internal` for good measure so they don't leak as API even if they did end up in main

**Before generating**, check the module's `build.gradle.kts` (or `build.gradle`) for a `debug` source set configuration. If one exists (or the standard Android conventions are in place — which is the default), place providers in `src/debug/`. If the module has no `debug` source set and the user doesn't want to add one, keep providers in `src/main/` but mark them `internal` and note this in the output report as a known trade-off.

Always report in the output which source set you used and why.

## Testing with ComposeTestRule

Tests go in `src/androidTest/java/...` alongside the component's package (or `src/test/java/...` with Robolectric if the project is set up for it — check before assuming).

### Dependencies expected

```kotlin
androidTestImplementation("androidx.compose.ui:ui-test-junit4:<version>")
debugImplementation("androidx.compose.ui:ui-test-manifest:<version>")
```

If these aren't in the module, mention it; don't silently assume.

### Test shape

```kotlin
class UserRowTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun whenLoading_showsLoadingIndicator() {
        composeTestRule.setContent {
            AppTheme {
                UserRow(state = UserRowUiState.Loading)
            }
        }

        composeTestRule
            .onNodeWithTag(UserRowTestTags.LOADING)
            .assertIsDisplayed()
    }

    @Test
    fun whenContent_clickingRowFiresOnClick() {
        var clicked = false
        composeTestRule.setContent {
            AppTheme {
                UserRow(
                    state = UserRowUiState.Content("Ada", "ada@x.io", 3),
                    onClick = { clicked = true },
                )
            }
        }

        composeTestRule
            .onNodeWithTag(UserRowTestTags.ROOT)
            .performClick()

        assertTrue(clicked)
    }
}
```

### What to test — go beyond "node exists"

Asserting that a tagged node is displayed is the baseline. Useful tests go further — they verify that the state contract is actually rendered, that interactions behave correctly, and that accessibility semantics match intent. Aim to cover several categories for non-trivial components:

**Cover every UiState variant — exhaustively.** Before finishing, cross-reference the test file against the `UiState` sealed hierarchy: every variant must appear in at least one test scenario. If the state is `sealed interface Foo { Loading, Content(read=Bool), Error }`, you need at least three scenarios — and for variants with meaningful sub-cases (like `Content` with `read=true` vs `read=false` producing visibly different output), each sub-case needs coverage too. A `when(state)` inside the composable is a contract; the tests should exercise every branch. Missing a variant means a future refactor can break that branch silently.

When you write the test file, list the variants in a comment at the top ("// Covers: Loading, Content(read=true), Content(read=false)") and tick them off as you add tests. This makes gaps obvious on review and forces the check rather than hoping you remembered.

**Combine assertions in one test when they check the same scenario.** A test is a scenario ("given Loading state"), not a single assertion. If three things should be true given one state, assert all three in the same test — don't split into three tests each with one setup and one assertion. Splitting gives you more tests on paper, but each one is thin and the setup duplication hides what's actually different between them. Reach for separate tests only when the *scenario* is different (different state, different interaction sequence).

Example of the right granularity:

```kotlin
@Test
fun whenContent_rendersAllFieldsAndIsClickable() {
    var clicked = false
    composeTestRule.setContent {
        AppTheme {
            NotificationRow(
                state = sampleContent(title = "Ada", preview = "Hi"),
                onClick = { clicked = true },
            )
        }
    }

    composeTestRule.onNodeWithTag(NotificationRowTestTags.CONTENT).assertIsDisplayed()
    composeTestRule.onNodeWithText("Ada").assertIsDisplayed()
    composeTestRule.onNodeWithText("Hi").assertIsDisplayed()
    composeTestRule.onNodeWithTag(NotificationRowTestTags.ROOT).assert(hasClickAction())
    composeTestRule.onNodeWithTag(NotificationRowTestTags.ROOT).performClick()
    assertTrue(clicked)
}
```

One test, one scenario ("Content state"), six assertions that together describe what Content should do. Don't split this into six tests.

**1. Presence per variant** (baseline — always include)

For each `UiState` variant, one test that the variant's root tag is displayed.

```kotlin
composeTestRule.onNodeWithTag(UserRowTestTags.LOADING).assertIsDisplayed()
```

**2. Content rendering — does data from state reach the screen**

Not just "the content block is there", but "the content block shows the fields from the state". Use `onNodeWithText` for this — it reads semantic text, so it also incidentally verifies a11y.

```kotlin
composeTestRule.onNodeWithText("Ada Lovelace").assertIsDisplayed()
composeTestRule.onNodeWithText("ada@analytical.engine").assertIsDisplayed()
```

**3. Negative assertions — elements that should NOT exist**

Especially important when variants differ by presence of optional elements (unread badge, error retry button, etc.).

```kotlin
// In the read variant, the unread indicator must be absent
composeTestRule.onNodeWithTag(UserRowTestTags.UNREAD_INDICATOR).assertDoesNotExist()
```

**4. Interactions — callbacks fire with the right arguments**

Don't just assert that a callback fired. If the callback takes an argument, assert on the argument.

```kotlin
var clickedId: String? = null
composeTestRule.setContent {
    AppTheme {
        UserRow(
            state = UserRowUiState.Content(id = "u-42", name = "Ada", /* ... */),
            onClick = { id -> clickedId = id },
        )
    }
}

composeTestRule.onNodeWithTag(UserRowTestTags.ROOT).performClick()
assertEquals("u-42", clickedId)
```

**5. Semantic actions — the row is announced correctly to a11y**

For rows using `mergeDescendants`, verify the merged root actually has the click action:

```kotlin
import androidx.compose.ui.test.hasClickAction

composeTestRule.onNodeWithTag(UserRowTestTags.ROOT).assert(hasClickAction())
```

For toggles, assert the toggled state is reflected in semantics:

```kotlin
composeTestRule.onNodeWithTag(TOGGLE).assertIsOn() // or assertIsOff()
```

**6. State transitions — behavior when state changes**

For components that visibly differ between states, verify that updating the state updates the UI. This is where `mutableStateOf` in the test content helps:

```kotlin
var state: UserRowUiState by mutableStateOf(UserRowUiState.Loading)
composeTestRule.setContent {
    AppTheme { UserRow(state = state) }
}

composeTestRule.onNodeWithTag(UserRowTestTags.LOADING).assertIsDisplayed()

state = UserRowUiState.Content(/* ... */)

composeTestRule.onNodeWithTag(UserRowTestTags.LOADING).assertDoesNotExist()
composeTestRule.onNodeWithTag(UserRowTestTags.CONTENT).assertIsDisplayed()
```

**7. Multi-instance scenarios — only when the component is actually reused**

Skip this category for single-component generation. If the user asks for a list, a grid, or otherwise indicates multiple instances on one screen, static tags collide and you'll need parameterized tags (see section 2). For a single-row component, a multi-instance test is noise — don't write it.

### What NOT to test

- Exact pixel positions, sizes, or spacing — those are Preview's job
- Color values — ditto
- Animation intermediate frames — fragile and usually not worth it
- Internal composable structure (e.g., "there's exactly 3 Box's") — couples tests to implementation
- Things already covered by the Compose framework itself (`Text` renders its string, `Button` is clickable) — don't re-verify framework guarantees

### Wrapping in the theme

Always wrap test content (and Previews) in the project's theme composable. Without it, `MaterialTheme.*` lookups fall back to defaults and the component may look different than in the app.

**Detect the theme — don't assume a name.** Before writing Previews or tests, find the project's theme composable:

1. Search for files named `*Theme.kt` or `Theme.kt` in the module and sibling modules (common locations: `ui/theme/`, `designsystem/`, `core-ui/`)
2. Look for a `@Composable` function that wraps children in `MaterialTheme(...)` — its name is the theme to use
3. If multiple candidates exist, ask the user which one; if none found, ask rather than inventing a name

## Output format

When you deliver a component, produce these files (adjust names to the component):

1. `UserRow.kt` — the composable(s), test tag object, and Previews together or in a sibling `UserRowPreviews.kt` if the file gets large (>~200 lines is a good signal to split previews out)
2. `UserRowTest.kt` — the Compose tests

Report back with:
- where the files were placed (module + package)
- **UiState variant coverage** — list every variant of the sealed hierarchy and map each to the test(s) that cover it. If any variant is not covered, say so explicitly and explain why (e.g., "Error variant not in original request — omitted"). This is a deliberate audit, not a list of what was done.
- which previews are included (list them)
- which tests are included (list them)
- any assumptions you made (theme name, data types in UiState, etc.) — explicitly, so the user can correct you

## Anti-patterns — things this skill refuses to produce

- Composables that call `viewModel()` internally or do any kind of DI lookup — state always comes from parameters
- Hardcoded hex colors or `sp`/`dp` magic numbers for typography
- `testTag` as a literal string scattered across the file — always via the tag object
- Tests that assert on layout coordinates or exact pixel sizes
- `mergeDescendants` applied reflexively to every row without considering whether children are independently actionable
- Giant monolithic composables that could be split *when* the split has a clear name and purpose
- Previews with only the happy path

## Handling screen inputs (mockups, Claude Design, screenshots)

When the user provides a visual reference:

1. **Describe what you see** in one sentence before writing code. This gives the user a chance to correct your interpretation before you commit to it.
2. **Identify the state variants** visible (is this just the happy state? Is there a loading/empty state the user expects you to infer?). Ask if unclear.
3. **Use design-system tokens only where you're confident.** For primary brand colors, typography scales, and spacing rhythm from a design system you can see, use them. For anything uncertain, use `MaterialTheme.*` and flag it: "I used `MaterialTheme.colorScheme.primary` as a placeholder — replace with your brand color if different."
4. **Note interaction assumptions.** "I assumed the whole row is clickable and the trailing icon is decorative — is that right?"

## Reference files

- `references/material3-components.md` — cheat sheet of M3 components with typical use-cases. Consult when picking between `Card` / `ElevatedCard` / `OutlinedCard`, or when unsure which M3 primitive matches the design.
- `references/preview-patterns.md` — concrete patterns for `PreviewParameter`, multi-variant preview layouts, and common "nasty data" providers (long strings, empty states, large numbers).


---
<!-- reference: references/material3-components.md -->

# Material 3 components cheat sheet

A quick reference to pick the right Material 3 composable for a given role. This is not a replacement for the official docs — it's a decision aid for when you're mid-component and need to remember which variant fits.

## Containers

| Component | When to use |
|---|---|
| `Card` | Default grouped content — list rows, tiles, compact summaries. Filled surface. |
| `ElevatedCard` | Card that needs visual emphasis above siblings; higher tonal elevation. |
| `OutlinedCard` | Card on low-contrast or busy backgrounds where elevation looks muddy; uses a border instead. |
| `Surface` | Raw themed container when you want theme-aware background + shape but no Card chrome. Good for custom layouts. |
| `Scaffold` | Screen-level skeleton (top bar, bottom bar, FAB slots). Rarely needed inside small components. |

## Lists

| Component | When to use |
|---|---|
| `ListItem` | Standard M3 list row — has `headlineContent`, `supportingContent`, `leadingContent`, `trailingContent`, `overlineContent` slots. Use this before rolling your own `Row`. |
| Custom `Row` inside `Card` | When `ListItem`'s slot shape doesn't fit (e.g., two-line trailing with custom layout). |
| `LazyColumn` / `LazyRow` | Scrolling lists. Always provide `key` for stable identity across recompositions. |

## Buttons

| Component | Emphasis | When to use |
|---|---|---|
| `Button` | High (filled) | Primary action on a screen/section. |
| `FilledTonalButton` | Medium-high | Secondary action that's still visually prominent. |
| `ElevatedButton` | Medium | Action on a busy/low-contrast surface where a filled button would dominate. |
| `OutlinedButton` | Medium-low | Secondary action, usually paired with a filled primary. |
| `TextButton` | Low | Tertiary action, dialog dismissals, inline calls to action. |
| `IconButton` / `FilledIconButton` / `FilledTonalIconButton` / `OutlinedIconButton` | Matches above | Icon-only equivalents. Remember `contentDescription`. |

## Text inputs

| Component | When to use |
|---|---|
| `TextField` | Filled style — default for most forms. |
| `OutlinedTextField` | When the surface behind is already filled, or the form needs a lighter visual. |
| `BasicTextField` | Full control; use only when M3 styles don't fit. You lose the decoration box by default. |

## Selection controls

| Component | When to use |
|---|---|
| `Checkbox` | Independent boolean choice, typically in lists. |
| `TriStateCheckbox` | "Select all" that reflects partial selection. |
| `Switch` | On/off that takes effect immediately (settings-style). |
| `RadioButton` | One-of-many within a group. Always inside a `Row` with `Modifier.selectableGroup()`. |
| `Slider` | Continuous range selection. |
| `RangeSlider` | Two-thumb range selection. |

## Chips

| Component | When to use |
|---|---|
| `AssistChip` | Contextual suggestion ("Add calendar event"). Low emphasis. |
| `FilterChip` | Toggleable filter within a set of options. Use with `selected` state. |
| `InputChip` | Represents discrete user input — email recipient, tag. Usually dismissible. |
| `SuggestionChip` | Smart-reply style suggestion, typically non-persistent. |

## Feedback & status

| Component | When to use |
|---|---|
| `CircularProgressIndicator` | Indeterminate waiting with no known duration. Default for loading states in components. |
| `LinearProgressIndicator` | Progress along a process where direction matters (upload, form steps). |
| `Snackbar` | Transient message at screen level — usually in `Scaffold`, not inside small components. |
| `Badge` / `BadgedBox` | Unread counts, notification dots. |

## Dividers

| Component | When to use |
|---|---|
| `HorizontalDivider` | Separating items in a list or sections within a card. |
| `VerticalDivider` | Separating inline elements in a row. |

## Typography scale reference

Use these via `MaterialTheme.typography.<name>` — never hardcode `sp`:

| Scale | Typical use |
|---|---|
| `displayLarge/Medium/Small` | Hero numbers, large screens only. Rare in small components. |
| `headlineLarge/Medium/Small` | Screen titles, major section headers. |
| `titleLarge` | Top-of-card title, dialog title. |
| `titleMedium` | Card heading, list-item headline (primary text). |
| `titleSmall` | Compact heading, usually paired with `bodySmall` below. |
| `bodyLarge` | Long-form reading text. |
| `bodyMedium` | Default body — list item supporting text, paragraph text. |
| `bodySmall` | De-emphasized metadata, timestamps. |
| `labelLarge` | Button text, prominent labels. |
| `labelMedium` | Chip text, secondary labels. |
| `labelSmall` | Caption text, overline-style metadata. |

## Color roles reference

Via `MaterialTheme.colorScheme.<role>`:

| Role | Typical use |
|---|---|
| `primary` / `onPrimary` | Main brand color + text/icons on top of it. |
| `primaryContainer` / `onPrimaryContainer` | Tonal variant for less prominent primary surfaces. |
| `secondary` / `onSecondary` | Secondary accent + its text/icons. |
| `tertiary` / `onTertiary` | Tertiary accent — contrasts with primary/secondary. |
| `surface` / `onSurface` | Default container background + its text. |
| `surfaceVariant` / `onSurfaceVariant` | De-emphasized surface — card backgrounds, input fields. |
| `background` / `onBackground` | Screen background + text. In M3 often same as surface. |
| `error` / `onError` | Error states, destructive actions. |
| `errorContainer` / `onErrorContainer` | Error surface tint (error banners). |
| `outline` | Borders, dividers. |
| `outlineVariant` | Subtler borders, dividers. |

## Shape reference

Via `MaterialTheme.shapes.<size>`:

| Shape | Typical use |
|---|---|
| `extraSmall` | Small chips, small buttons. |
| `small` | Buttons, chips. |
| `medium` | Cards, dialogs, bottom sheets top corners. |
| `large` | Larger cards, extended FABs. |
| `extraLarge` | Hero surfaces, full-screen dialogs. |

---
<!-- reference: references/preview-patterns.md -->

# Preview patterns for Compose components

Concrete patterns for generating multi-variant Previews without drowning the file in `@Preview` functions. Consult this when a component has more than 2–3 variants, when nasty data would bloat the file, or when `@PreviewParameter` would clean things up.

> **Note on `AppTheme` in examples below:** `AppTheme` is a placeholder for whatever the project's theme composable is actually called (`MyAppTheme`, `AcmeTheme`, etc.). Detect the real name from the project and substitute — don't assume `AppTheme` exists.

## The four preview anchors

Every component has at least these previews:

1. **Happy path** — one per `UiState` variant, with realistic data
2. **Long strings** — the happy path with names/titles overflowing
3. **Empty strings** — where the contract allows emptiness
4. **Dark mode** — one preview of the most content-rich variant

Large numbers only if the component shows numbers; font-scale 2.0 rarely (when the component is text-heavy and layout might break).

## Pattern 1: Manual `@Preview` functions — for 2–4 previews total

When the number of previews is small, explicit functions are most readable.

```kotlin
@Preview(name = "Content", showBackground = true)
@Composable
private fun UserRowContentPreview() {
    AppTheme {
        UserRow(
            state = UserRowUiState.Content(
                name = "Ada Lovelace",
                email = "ada@analytical.engine",
                unread = 3,
            ),
        )
    }
}

@Preview(name = "Content — long name", showBackground = true)
@Composable
private fun UserRowLongNamePreview() {
    AppTheme {
        UserRow(
            state = UserRowUiState.Content(
                name = "Maria Skłodowska-Curie-van-der-Berg-Nakamura",
                email = "very.long.address.that.keeps.going@example.com",
                unread = 999,
            ),
        )
    }
}

@Preview(name = "Loading", showBackground = true)
@Composable
private fun UserRowLoadingPreview() {
    AppTheme { UserRow(state = UserRowUiState.Loading) }
}

@Preview(name = "Dark", showBackground = true, uiMode = UI_MODE_NIGHT_YES)
@Composable
private fun UserRowDarkPreview() {
    AppTheme {
        UserRow(
            state = UserRowUiState.Content(
                name = "Ada Lovelace",
                email = "ada@analytical.engine",
                unread = 3,
            ),
        )
    }
}
```

Notes:
- `private fun` so they don't leak into the public API
- Name each preview with `name = "..."` — otherwise the Preview pane shows function names, which is noisier
- Always wrap in the theme

## Pattern 2: `@PreviewParameter` — for many variants of the same state

When the component has one primary state and you want to see 5+ data shapes side by side, use a parameter provider.

```kotlin
class UserRowContentProvider : PreviewParameterProvider<UserRowUiState.Content> {
    override val values = sequenceOf(
        UserRowUiState.Content(
            name = "Ada Lovelace",
            email = "ada@analytical.engine",
            unread = 0,
        ),
        UserRowUiState.Content(
            name = "Maria Skłodowska-Curie-van-der-Berg-Nakamura",
            email = "very.long.address.that.keeps.going@example.com",
            unread = 999,
        ),
        UserRowUiState.Content(
            name = "",
            email = "anonymous@example.com",
            unread = 1,
        ),
    )
}

@Preview(name = "Content variants", showBackground = true)
@Composable
private fun UserRowContentPreviews(
    @PreviewParameter(UserRowContentProvider::class) state: UserRowUiState.Content,
) {
    AppTheme { UserRow(state = state) }
}
```

This renders one preview per value in the sequence, labeled with the index. One `@Preview` function, N previews.

## Pattern 3: Composite preview showing all states stacked

Useful when you want to see the component's full state space at a glance — good for screen components or rows that differ subtly between states.

```kotlin
@Preview(name = "All states", showBackground = true, heightDp = 600)
@Composable
private fun UserRowAllStatesPreview() {
    AppTheme {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            UserRow(state = UserRowUiState.Loading)
            UserRow(
                state = UserRowUiState.Content(
                    name = "Ada Lovelace",
                    email = "ada@analytical.engine",
                    unread = 3,
                ),
            )
            UserRow(state = UserRowUiState.Error("Network error"))
        }
    }
}
```

Include `heightDp` large enough to show all states — default preview height can clip.

## Pattern 4: Multi-preview annotations — for dark/light + font scale combinations

If the user wants consistent coverage across several dimensions, define a custom annotation once:

```kotlin
@Preview(name = "Light", group = "themes")
@Preview(name = "Dark", group = "themes", uiMode = UI_MODE_NIGHT_YES)
annotation class LightDarkPreview

@Preview(name = "Normal", group = "font")
@Preview(name = "Large font", group = "font", fontScale = 1.5f)
annotation class FontScalePreview
```

Use it:

```kotlin
@LightDarkPreview
@Composable
private fun UserRowThemes() {
    AppTheme {
        UserRow(
            state = UserRowUiState.Content(name = "Ada", email = "ada@x.io", unread = 3),
        )
    }
}
```

Use this pattern sparingly — it expands fast. Good for shared components that absolutely must work across themes; overkill for one-off rows.

## Nasty-data providers — reusable

For components that share data shapes (many components accept a `String` name), put nasty-data providers in a shared preview utilities file:

```kotlin
// in ui/preview/NastyStrings.kt (debug source set if available)

object NastyStrings {
    const val LONG_NAME = "Maria Skłodowska-Curie-van-der-Berg-Nakamura-Rodriguez"
    const val LONG_EMAIL = "very.long.address.that.keeps.going.forever@example.com"
    const val EMPTY = ""
    const val WITH_EMOJI = "Ada 🧮 Lovelace"
    const val RTL_SAMPLE = "آدا لافليس"
}
```

Then reference them in previews:

```kotlin
UserRowUiState.Content(name = NastyStrings.LONG_NAME, ...)
```

This keeps preview files focused on layout and makes it trivial to test the same nasty string across components.

## When a component is in a library module with no `debug` source set

Compose previews live in `src/main` by default. In release builds, `@Preview` functions are not stripped automatically — but they produce no runtime overhead unless called. Still, it's good hygiene to:
- mark preview functions `private`
- mark preview parameter providers `internal` or `private` so they don't leak to API

If the project has a `debug` source set configured for the module, put preview files there and the compiler will strip them entirely from release.
