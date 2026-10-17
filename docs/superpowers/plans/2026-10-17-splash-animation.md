# Splash Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reveal the existing Cheetah mark, `Cheetah`, and `by BocTrust` in that order on the approved gold splash while preserving startup routing.

**Architecture:** The native splash supplies a matching static gold launch surface and mark. Flutter's first frame preserves that mark's apparent position, animates a small scale settle, then reveals the two text lines while `StartupGateNotifier` performs cold-start work. Only the cold-start route waits for the short reveal; post-login bootstrap keeps its current loading and error UI.

**Tech Stack:** Flutter/Dart, Riverpod, `flutter_native_splash` 2.4.8, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-10-17-onboarding-motion-design.md`

## Global Constraints

- Background: `BocColors.goldLight` / `#E5C367` in both themes.
- Mark: `assets/branding/cheetah_app_icon.svg` through `BocBrandMark`; do not redraw the logo.
- Flutter's first mark frame must match the static native mark; use a 1.0 → 1.04 → 1.0 scale settle without a 36 px entrance translation or an opacity reset. Use `BocColors.navy` for splash text on gold.
- Exact copy: `Cheetah`, `by BocTrust`, and `Licensed by the CBN · Deposits insured by the NDIC`.
- Cold-start sequence: 1,350 ms total; reduced motion has no animation delay.
- Preserve `AuthDestination.login` versus `AuthDestination.onboarding` selection and post-login bootstrap behavior.

## Review Focus

- Slow storage cleanup: the final splash frame remains visible until routing finishes (Task 3 widget test).
- Returning user: the same splash ends at login, not onboarding (Task 3 provider test).
- Post-login profile load: no 1,350 ms hold or splash replay (Task 3 widget test).
- Reduced motion: final mark and full name appear immediately and routing is not delayed (Tasks 2 and 3 tests).
- Platform handoff: no dark flash, disappearing mark, placement jump, or premature native title branding (Tasks 1–2 and device review).

## Source handoff before execution

- [ ] Track this plan and `docs/superpowers/specs/2026-10-17-onboarding-motion-design.md` with an explicit `git add -f` because `.gitignore` excludes new `docs/` files. Track the carousel plan and only the nine approved `*-afro-*` artwork files in `design/onboarding_previews/` in the same checkpoint. Leave older previews untracked. Commit this checkpoint before creating a fresh worktree so both plans and approved assets are available there.

---

### Task 1: Gold native launch surface

**Files:**
- Modify: `flutter_native_splash.yaml`
- Modify: generated Android/iOS splash resources via the existing generator
- Modify: `test/platform_branding_config_test.dart`

**Interfaces:**
- Produces: a static `#E5C367` native surface with the existing Cheetah mark, without native `Cheetah / by BocTrust` branding ahead of the Flutter reveal.

- [ ] **Step 1: Update the native splash test** to expect `#E5C367` for `color`, `color_dark`, and Android 12 colors, and no `branding` keys or generated Android 12 `windowSplashScreenBrandingImage` item; keep checks for the existing circle-safe icon and both platforms.
- [ ] **Step 2: Run the test to confirm the old configuration fails.** Run `flutter test test/platform_branding_config_test.dart`; expect the splash assertions to fail on `#101E30` or the branding keys.
- [ ] **Step 3: Change `flutter_native_splash.yaml`** to the tested values, keeping the current icon assets and `android_12` mask-safe image.
- [ ] **Step 4: Regenerate native resources.** Run `dart run flutter_native_splash:create --path flutter_native_splash.yaml`.
- [ ] **Step 5: Verify and commit.** Run `flutter test test/platform_branding_config_test.dart`; expect pass. Commit the config, tests, and generated splash resources together.

### Task 2: Shared brand typography and Flutter reveal

**Files:**
- Modify: `lib/module/component/branding.dart`
- Create: `lib/module/onboarding/screens/startup_brand_sequence.dart`
- Create: `test/startup_brand_sequence_test.dart`
- Modify: `test/in_app_branding_test.dart` if the brand's internal widget structure changes

**Interfaces:**
- Produces: `CheetahBrandWords({required double markSize, double titleOpacity = 1, double bylineOpacity = 1})` in the existing `app_ui.dart` library. `CheetahBrand.launch` uses it at full opacity. Also produces `RegulatoryBadge.splash()` using the existing legal copy without the normal card border.
- Produces: `StartupBrandSequence({required bool reduceMotion})`, a widget using `BocBrandMark` plus `CheetahBrandWords` with the established lockup semantics.

- [ ] **Step 1: Write widget tests** for the reveal: the mark is visible at full size on the first Flutter frame, settles at the same position during the first 650 ms, `Cheetah` begins after 650 ms, and `by BocTrust` begins after 1,000 ms; both are fully visible at 1,350 ms. Assert navy text, immediate final composition under reduced motion, and one `Cheetah by BocTrust` semantics label.
- [ ] **Step 2: Run the focused tests and confirm they fail.** Run `flutter test test/startup_brand_sequence_test.dart`; expect missing-widget or timing failures.
- [ ] **Step 3: Extract the existing launch word styles** into `CheetahBrandWords` without changing normal `CheetahBrand` layout, color, or accessibility behavior; let the splash supply navy foreground colors. Add `RegulatoryBadge.splash()` with the current legal copy rendered as a plain navy line on gold. Build `StartupBrandSequence` with an `AnimationController` of 1,350 ms: mark scale 1.0→1.04→1.0 over 0–650 ms with fixed center and full opacity, title fade over 650–1,000 ms, byline fade over 1,000–1,350 ms. Use the existing mark and words, not a flattened image. Anchor the regulatory variant near the bottom.
- [ ] **Step 4: Verify and commit.** Run `flutter test test/startup_brand_sequence_test.dart test/in_app_branding_test.dart`; expect pass. Commit the shared brand and reveal widget with tests.

### Task 3: Cold-start gate and bootstrap integration

**Files:**
- Modify: `lib/app/bootstrap_provider.dart`
- Modify: `lib/module/onboarding/screens/startup_screens.dart`
- Modify: `test/cold_launch_auth_test.dart`
- Create: `test/bootstrap_splash_test.dart`

**Interfaces:**
- Consumes: `StartupBrandSequence({required bool reduceMotion})` from Task 2.
- Produces: `StartupGateNotifier.start({Duration minimumSplashDuration = const Duration(milliseconds: 1350)})` for cold launch only. `startAfterLogin()` keeps its existing signature and immediate behavior.

- [ ] **Step 1: Write provider/widget tests** asserting that an immediate cold-start decision publishes only after the minimum duration; slow cleanup publishes as soon as both cleanup and minimum duration finish; `Duration.zero` publishes without a hold; returning users reach login; `startAfterLogin()` keeps the loading/error path without the animated splash.
- [ ] **Step 2: Run tests to confirm they fail.** Run `flutter test test/cold_launch_auth_test.dart test/bootstrap_splash_test.dart`; expect missing-parameter or early-navigation failures.
- [ ] **Step 3: Start the minimum-duration future when `start()` begins** and await it after session cleanup but before `_publish`. Do not change `_loadProfile()` or destination selection. Use `Duration.zero` in provider-only tests that are testing authentication rather than timing.
- [ ] **Step 4: Render `StartupBrandSequence`** for `StartupGateStage.idle` and `clearingSession` on a `BocColors.goldLight` scaffold with dark status/navigation-bar icons. Pass `MediaQuery.disableAnimationsOf(context)` to the widget and use `Duration.zero` when starting the provider under reduced motion. Keep the current theme background, profile spinner, retry, and sign-out UI for `loadingProfile` / `profileError`.
- [ ] **Step 5: Verify and commit.** Run `flutter test test/cold_launch_auth_test.dart test/bootstrap_splash_test.dart test/in_app_branding_test.dart` and `flutter analyze` with writable Flutter SDK cache access; expect pass. Review a cold launch on available iOS and Android simulators/devices for mark position, title order, status bar, and native-to-Flutter continuity. Report any unavailable platform check as unverified, then commit.
