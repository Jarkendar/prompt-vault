---
name: android-compose-layout-from-screenshot
description: Convert a pasted reference screenshot (mockup, design export, phone capture) into a production-grade Jetpack Compose component, snapshot it with Paparazzi, visually compare snapshot vs reference, and iterate up to 3 times to close the gap. Use this skill whenever the user pastes or attaches an image and asks to recreate it as a Compose UI — including phrases like "zrób layout z tego screena", "odtwórz ten ekran w Compose", "build this UI", "match this mockup", "recreate this design", "implement this screenshot". Also trigger when the user mentions Paparazzi snapshot testing in the context of building from a reference, or when an image of a UI is attached without further explanation in an Android/Compose project. Do NOT use for backend logic, navigation graphs, or pure architectural questions — this skill is for the visual UI layer plus its snapshot verification loop.
---

# Android Compose Layout From Screenshot

Build a Jetpack Compose component that matches a reference screenshot, verify the match with Paparazzi snapshots, and iterate on discrepancies. The deliverable is a stateless + stateful composable pair, multi-config Previews, a Paparazzi test rendering the same configurations, and — after the iteration loop — a markdown report on remaining gaps (if any).

This skill is **visual-fidelity work driven by a closed feedback loop**. Standard Compose hygiene (state hoisting, M3 tokens, test tags, multi-Preview coverage) is the floor, not the goal. The goal is for the rendered snapshot to look like the reference. The skill stops at 3 iterations regardless of how close the match is — if it's not done, it produces a report explaining what's still off and why.

## When this skill triggers — and when it does not

**Trigger** when a visual reference exists (pasted image, attached PNG/JPG, screenshot from Figma, Claude Design export, or phone capture) and the user wants Compose code that matches it.

**Do not trigger** when:
- The user provides only prose ("build a login form") with no image → use `compose-component-creator` instead
- The user wants architecture work (ViewModels alone, navigation, DI) → use the relevant Android skill
- The image is shared for reference but the task is to *modify existing* Compose code rather than build new — in that case, use `compose-component-creator` and reference this skill's comparison loop manually if needed

If unsure whether the user wants this full snapshot-loop treatment or just a quick Compose translation, **ask**: *"Do you want the full Paparazzi snapshot loop with comparison and iteration, or just a one-shot Compose translation?"* The loop is heavier and only earns its cost when fidelity matters.

## Required inputs from the user

Before starting, confirm you have:

1. **Reference image** — pasted into the terminal (Claude Code accepts pasted images and exposes them via a temp filepath) or attached as a file. If only described in prose, stop and ask for the image.
2. **Target module / package** — where the composable should live. If absent, ask. Default suggestions: `feature-<name>/ui/screens/` for screen-sized layouts, `feature-<name>/ui/components/` for smaller pieces. Do not invent silently.
3. **Component name** — derive from the user's description if obvious (e.g., "login screen" → `LoginScreen`). Confirm if ambiguous.

## Workflow

The skill follows seven phases in order. Do not skip the verification phase; do not exceed three iterations.

### Phase 1 — Verify Paparazzi is configured

Before generating any Compose code, check the target module's Gradle setup. Run:

```bash
grep -r "paparazzi" <module>/build.gradle.kts <module>/build.gradle 2>/dev/null
grep -r "app.cash.paparazzi" gradle/libs.versions.toml 2>/dev/null
```

Decide based on results:

- **Paparazzi present** → proceed to Phase 2
- **Paparazzi absent** → stop and produce the setup snippet (see `references/paparazzi-setup.md`), ask the user to apply it and re-run the skill. Do not silently add Paparazzi to their build — it touches build configuration and the user should accept that explicitly.

Also confirm a project theme composable exists (search for `*Theme.kt` containing `MaterialTheme(...)`). If absent, ask which theme to wrap previews and snapshots in.

### Phase 2 — Describe what you see

Before writing code, write **one paragraph** describing the reference image:

- Overall layout shape (column, row, scaffold with top bar, list, etc.)
- Distinct regions and their hierarchy
- Interactive elements (buttons, inputs, toggles, clickable rows)
- Visible state (is this the loading state? Empty? Populated with sample data?)
- Color cues (primary surface, accent colors, on-surface text) — name them by role, not hex
- Typography hints (display, headline, body, label sizes — roughly)

This serves two purposes: gives the user a chance to correct misinterpretation cheaply, and forces explicit grounding before code is committed.

### Phase 3 — Generate the Compose code

Produce a stateless + stateful pair following these rules:

**Stateless composable** (`<ComponentName>Content` or just `<ComponentName>` if no stateful wrapper is needed):
- Takes a `UiState` (sealed interface) plus callbacks as parameters
- No `viewModel()` calls, no `remember` for business state, no side effects beyond UI animation
- Material 3 only — `MaterialTheme.colorScheme`, `MaterialTheme.typography`, `MaterialTheme.shapes`. No hardcoded hex / sp / dp magic numbers for tokens. Spacing is fine to hardcode in `dp` where it doesn't map to a token.
- Test tags via an `internal object` of `const val` strings near the component
- Accessibility: `contentDescription` on icons, `mergeDescendants` on row-shaped clickable areas where appropriate

**Stateful wrapper** (`<ComponentName>` if the stateless one was suffixed `Content`):
- Only generate this if the screen needs a `ViewModel` OR the user explicitly asked for it OR the component owns local UI state that won't make sense to hoist further (e.g., a `SearchBar` with its own focus state)
- Hoists state from a `ViewModel` via `collectAsStateWithLifecycle` and forwards callbacks to the VM
- If a `ViewModel` is needed and the user hasn't given one, **ask before generating it**. Do not invent ViewModels silently — they imply repository contracts you don't know.

**Sealed UiState class**:
- Generate only if the user's reference shows or implies multiple states (loading spinner visible, empty state illustration, error banner)
- If only one state is visible, generate a single `data class` for content and note: *"Reference shows only the populated state — added `Content` as the sole variant. Add `Loading`/`Error`/`Empty` if needed."*

### Phase 4 — Generate Previews (minimum 4)

The user requires at least these four:

| Preview | `uiMode` | `device` |
|---|---|---|
| Light + Portrait | `UI_MODE_NIGHT_NO` | `Devices.PHONE` (default) |
| Dark + Portrait | `UI_MODE_NIGHT_YES` | `Devices.PHONE` |
| Light + Landscape | `UI_MODE_NIGHT_NO` | `spec:parent=pixel_5,orientation=landscape` |
| Dark + Landscape | `UI_MODE_NIGHT_YES` | `spec:parent=pixel_5,orientation=landscape` |

Each Preview wraps the composable in the project's theme. Add more Previews when the UiState has multiple variants — one preview per variant per orientation/mode is overkill; prefer one orientation/mode pair per variant plus the 4-config matrix on the main happy state.

### Phase 5 — Generate the Paparazzi snapshot test

One test file per component. The test renders the *same configurations as the Previews* so that what the user sees in Android Studio Previews matches what gets snapshotted. Pattern:

```kotlin
class <ComponentName>SnapshotTest {
    @get:Rule
    val paparazzi = Paparazzi(
        deviceConfig = DeviceConfig.PIXEL_5,
        theme = "android:Theme.Material.Light.NoActionBar",
        renderingMode = SessionParams.RenderingMode.SHRINK,
    )

    @Test
    fun lightPortrait() = paparazzi.snapshot { AppTheme(darkTheme = false) { <Component>(state = sampleState) } }

    @Test
    fun darkPortrait() = paparazzi.snapshot { AppTheme(darkTheme = true) { <Component>(state = sampleState) } }

    @Test
    fun lightLandscape() {
        paparazzi.unsafeUpdateConfig(DeviceConfig.PIXEL_5.copy(orientation = ScreenOrientation.LANDSCAPE))
        paparazzi.snapshot { AppTheme(darkTheme = false) { <Component>(state = sampleState) } }
    }

    @Test
    fun darkLandscape() {
        paparazzi.unsafeUpdateConfig(DeviceConfig.PIXEL_5.copy(orientation = ScreenOrientation.LANDSCAPE))
        paparazzi.snapshot { AppTheme(darkTheme = true) { <Component>(state = sampleState) } }
    }
}
```

Then run the snapshot task to *record* (not verify) — we need the fresh PNGs to compare against the reference:

```bash
./gradlew :<module>:recordPaparazzi<Variant>   # usually recordPaparazziDebug
```

The PNGs land in `<module>/src/test/snapshots/images/`. Read the filepaths from the test class's fully-qualified name + test method name.

### Phase 6 — Compare snapshot vs reference (LLM vision)

For each of the four primary snapshots:

1. **Read** the generated PNG from `src/test/snapshots/images/` using the Read tool (Claude Code's vision will load it)
2. **Read** the reference image
3. **Compare** semantically across these axes — in this order:
   - **Layout structure**: are the same regions present? Are they in the right relative positions? Is anything missing or extra?
   - **Spacing & alignment**: padding, gaps between elements, alignment within rows/columns
   - **Typography hierarchy**: do display/headline/body sizes match the reference? Don't worry about exact pixel sizes — worry about *hierarchy* (is the title clearly larger than the body?)
   - **Colors by role**: do surfaces, accents, and on-surface text match the reference's *role*, not necessarily the exact hex (the project's theme owns the exact palette)
   - **Iconography**: are the right icons in the right slots? Material icons rarely match exactly — flag substitutions, don't try to fake exact custom icons
   - **States visible**: if the reference shows a populated list with 5 items, does the snapshot also show 5? Sample data parity matters for the comparison.

4. Produce a **discrepancy list** — concrete, actionable items. Bad: "colors look slightly off". Good: "the primary accent in the reference is a deeper teal; current snapshot uses `MaterialTheme.colorScheme.primary` which appears more saturated. Either accept (theme owns it) or update the theme."

Skip dark/landscape comparisons if the reference is only light/portrait — note this explicitly and don't fabricate gaps.

### Phase 7 — Iterate (up to 3 times)

For each iteration:

1. Apply fixes targeting the highest-impact discrepancies first — usually layout structure and spacing, then typography, then color, then iconography. Don't try to fix everything in one pass if there's a layout issue blocking the rest.
2. Re-run `recordPaparazzi<Variant>` to regenerate snapshots
3. Re-compare and produce an updated discrepancy list
4. If the list is empty or only contains items you've judged as "theme-owned / acceptable" → stop, produce the success summary (see Output format)
5. If iteration count reaches 3 with remaining discrepancies → stop, produce the iteration report (see Output format)

**Do not exceed 3 iterations.** This is a hard cap. If you're tempted to "just one more" — that's the signal to write the report instead.

**What counts as "done":**
- No layout-structure issues remain
- No clear spacing/alignment misses (>~8dp off in obvious places)
- Typography hierarchy matches
- Color discrepancies are either matched or explicitly attributed to the project's theme
- Sample data in the snapshot is plausible for the reference

**What does NOT count as a discrepancy worth iterating on:**
- Exact pixel-level color differences when both are sensible interpretations of the same role
- Font-rendering differences between Paparazzi's renderer and the reference's source
- Custom illustrations / brand icons that the user didn't provide as assets — flag and move on
- Subtle shadow / elevation differences — Paparazzi's shadow rendering is known to differ from real devices

## Output format

### On success (any iteration ≤ 3 produces a clean comparison):

Report back with:
- **Files produced** — paths to composable file, snapshot test file, theme/state files if newly created
- **Iteration count** — 1, 2, or 3
- **Generated snapshot paths** — the 4 PNGs in `src/test/snapshots/images/`
- **UiState variants covered** — list each, map to Preview + snapshot
- **Resolved discrepancies** — what was fixed across iterations
- **Accepted-as-theme items** — color/typography items left to the project's theme, with reasoning
- **Assumptions** — sample data invented, icon substitutions made, package paths chosen, theme name detected

### On stop after 3 iterations with remaining gaps:

Write a markdown report at `.claude/reports/<ComponentName>-iteration-report.md`. Use the template at `references/iteration-report-template.md`. **Write the report in the language the user has been using in the conversation** — detect from their messages (Polish → write in Polish, English → write in English, etc.). Code, identifiers, and file paths stay in English regardless.

The report must include:
- Component name, module, date
- All three iterations: what was attempted, what changed, what comparison revealed
- Final discrepancy list, categorized: **structural** (layout differs), **stylistic** (spacing/typography/color), **asset** (missing icon/illustration), **environmental** (Paparazzi renderer limitation)
- For each remaining item: a concrete suggestion for the user (e.g., "Replace `Icons.Default.Star` with the custom star asset at `res/drawable/ic_star_brand.xml` — not provided in this skill run")
- Next-step recommendation: continue manually, request specific assets, accept the gap

Then report back to the user inline:
- "Stopped after 3 iterations. Wrote report to `.claude/reports/<...>-iteration-report.md`."
- Brief summary (3-5 lines) of what's still off and what the user should do next.

## Anti-patterns — refused by this skill

- Generating code without first describing the reference (Phase 2 is non-negotiable)
- Adding Paparazzi to the user's build silently
- Inventing a `ViewModel` to satisfy the stateful wrapper when none was requested — ask first
- Hardcoded hex colors / sp values for tokens (spacing in `dp` is fine where no token applies)
- Test tags scattered as inline literals — always via the `internal object`
- Continuing past iteration 3 because "we're so close"
- Reporting in English when the user has been writing in another language (or vice versa)
- Writing a multi-iteration report without actually running the snapshots — the report describes what *was attempted*, not what *might have been*

## Reference files

- `references/paparazzi-setup.md` — Gradle/Catalog snippets to add Paparazzi to a module when missing
- `references/iteration-report-template.md` — markdown template for the after-3-iterations report

## Related skills

- `compose-component-creator` — for Compose components without a visual reference (prose specs, sealed UiState only)
- `android-compose-ui` — Compose patterns beyond MVI (stability, recomposition, animations)
- `android-testing` — ViewModel/repository tests; this skill only covers Paparazzi snapshot tests
- `kotlin-tdd` — pure Kotlin (non-UI) TDD workflow


---
<!-- reference: references/iteration-report-template.md -->

# Iteration report template

Use this template when the skill stops after 3 iterations with remaining discrepancies. Write the report at `.claude/reports/<ComponentName>-iteration-report.md`.

**Language rule:** detect the conversation language and write all *narrative* sections (headings, descriptions, recommendations) in that language. Code, file paths, identifiers, Compose APIs, and Paparazzi terminology stay in English. Headings below are shown in English as scaffolding — translate them when emitting the report.

---

```markdown
# <ComponentName> — iteration report

**Module:** `<module-path>`
**Package:** `<package>`
**Date:** YYYY-MM-DD
**Reference image:** <path-or-"pasted-by-user">
**Stopped at:** iteration 3 of 3

## Summary

<1–3 sentence overview of where things landed: how close the snapshot is to the reference, and the dominant category of remaining gaps (structural / stylistic / asset / environmental).>

## Iteration log

### Iteration 1

**Discrepancies identified:**
- <item>
- <item>

**Changes applied:**
- <file/composable + what changed>
- <file/composable + what changed>

**Outcome:** <what the post-iteration comparison revealed — what was fixed, what regressed, what remained>

### Iteration 2

**Discrepancies identified:**
- <item>

**Changes applied:**
- <file/composable + what changed>

**Outcome:** <as above>

### Iteration 3

**Discrepancies identified:**
- <item>

**Changes applied:**
- <file/composable + what changed>

**Outcome:** <as above>

## Remaining discrepancies

Categorized by type. Each item: concrete description + concrete suggestion.

### Structural
<items where layout shape, regions, or hierarchy still differ from the reference. These are the most expensive to leave open and usually mean the reference shows something the skill didn't successfully translate to Compose.>

- **<short title>** — <description of mismatch>
  - Suggestion: <concrete next action for the user>

### Stylistic
<spacing, alignment, typography hierarchy, color role. The reference and snapshot agree on shape but differ on polish.>

- **<short title>** — <description>
  - Suggestion: <concrete next action>

### Asset
<missing custom icons, illustrations, brand fonts, or images the skill couldn't generate.>

- **<short title>** — <what's missing>
  - Suggestion: <e.g., "provide asset at `res/drawable/<name>.xml`" or "share the brand font file">

### Environmental
<Paparazzi renderer limitations, font-rendering quirks, shadow/elevation approximations. Usually accepted and documented, not fixed.>

- **<short title>** — <description>
  - Suggestion: <usually "accept" or "verify on device">

## Files produced

- `<path/to/Composable.kt>`
- `<path/to/ComposableSnapshotTest.kt>`
- `<path/to/UiState.kt>` (if generated)
- `<path/to/ViewModel.kt>` (if generated)

## Generated snapshots

- `<module>/src/test/snapshots/images/<fqcn>_lightPortrait.png`
- `<module>/src/test/snapshots/images/<fqcn>_darkPortrait.png`
- `<module>/src/test/snapshots/images/<fqcn>_lightLandscape.png`
- `<module>/src/test/snapshots/images/<fqcn>_darkLandscape.png`

## Recommended next steps

<Pick one or combine — be concrete, not generic:>

1. **Continue manually** — the remaining items are small enough to address in-IDE with live Preview rather than another full snapshot cycle. Specifically: <which items>.
2. **Provide missing assets** — the skill cannot proceed further without <X, Y, Z>. After providing them, re-run the skill or apply directly.
3. **Accept the gap** — remaining differences are <environmental / theme-owned> and not worth pursuing.
4. **Re-run with adjusted reference** — if the reference image itself is ambiguous (e.g., compressed, cropped, dark-mode-only), a higher-quality source would let the skill converge.

## Assumptions made during the run

<List anything inferred without explicit user confirmation: theme name, sample data, icon substitutions, package, ViewModel creation, UiState variants invented, etc. The user reads this to spot any wrong assumption that may have caused a gap.>

- <assumption>
- <assumption>
```

---
<!-- reference: references/paparazzi-setup.md -->

# Paparazzi setup

Use these snippets when Phase 1 detects Paparazzi is absent from the target module. **Present them to the user — do not apply them automatically.** Build configuration is a deliberate decision that should be opted into explicitly.

## 1. Version catalog (`gradle/libs.versions.toml`)

```toml
[versions]
paparazzi = "1.3.5"

[plugins]
paparazzi = { id = "app.cash.paparazzi", version.ref = "paparazzi" }
```

> Pin to the latest stable release at the time of integration. `1.3.5` is a known-good version compatible with AGP 8.x and recent Compose BOMs; the user may want a newer one — flag this and let them choose.

## 2. Module `build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.android.library)            // or android.application
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)             // Compose Compiler plugin (Kotlin 2.0+)
    alias(libs.plugins.paparazzi)
}

// Optional but recommended: ensure Paparazzi uses a stable JVM
// (Paparazzi runs LayoutLib in-process on the JVM)
tasks.withType<Test>().configureEach {
    // Snapshot tests can be memory-hungry on larger components
    maxHeapSize = "2g"
}
```

No additional `dependencies` block is needed — applying the plugin pulls in the test dependency. The user's existing `testImplementation` setup (JUnit etc.) is enough.

## 3. Recording vs verifying

Paparazzi exposes two task families per build variant:

| Task | Purpose |
|---|---|
| `recordPaparazzi<Variant>` | Generate / overwrite snapshot PNGs under `src/test/snapshots/images/` |
| `verifyPaparazzi<Variant>` | Run tests and fail if any snapshot differs from the recorded baseline |

For this skill's workflow we always use **record** — we need the fresh PNGs to read back and compare to the reference. `verify` is for regression testing in CI, which is out of scope here but the user gets it for free.

Common variant names: `recordPaparazziDebug` for app modules, `recordPaparazziDebug` for library modules with default flavors. Confirm by running `./gradlew :<module>:tasks --group=paparazzi`.

## 4. CI considerations (informational — not added by this skill)

Paparazzi is JVM-only (no emulator), so it runs on any GitHub Actions / GitLab runner. If the user has an existing CI pipeline (the `pi-automate` repo or `AndroidLab` GHA workflows), they may want to add a `verifyPaparazzi` step — that's a follow-up, not part of this skill's run.

## 5. Known gotchas

- **Font rendering**: Paparazzi uses LayoutLib's font renderer, which can differ subtly from a real device. Don't iterate on minor font kerning differences.
- **Shadows / elevation**: rendered approximately. Treat elevation discrepancies as low-priority.
- **System bars**: Paparazzi can include or exclude them depending on `theme` and `showSystemUi`. The default in our test template excludes them — adjust if the reference includes them.
- **Animations**: Paparazzi snapshots a single frame; animations are captured at frame 0 unless you advance the clock with `paparazzi.gif { }` or similar APIs.
