# Onboarding Carousel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display the approved African-inspired GIFs in a three-slide onboarding carousel styled after the supplied screen references.

**Architecture:** Copy the reviewed GIFs and stills to named app assets. Keep `OnboardingScreen` responsible for slide index and navigation, and place each slide's art and lower panel in a focused presentation widget. The matching PNG covers GIF loading failures and reduced motion.

**Tech Stack:** Flutter/Dart, bundled GIF decoding through `Image.asset`, existing `PrimaryButton` and responsive layout widgets, Flutter widget tests, `image` dev dependency for asset validation.

**Spec:** `docs/superpowers/specs/2026-10-17-onboarding-motion-design.md`

## Global Constraints

- Approved animation sources: `design/onboarding_previews/01-save-afro-preview.gif`, `02-goals-afro-preview.gif`, and `03-pay-afro-preview.gif`, with matching `*-preview.png` stills.
- All three are 600 × 600, loop in 1,920 ms, and include `#F6F4EE` background; show on `BocColors.paper` even when the app theme is dark.
- Use the existing slide titles, descriptions, `Next` / `Get started` labels, and destinations. Do not swap product names from the screenshots into app copy.
- Preserve a visible `I already have an account` route to `AuthDestination.login`.
- Follow the screenshot layout by removing the current top `CheetahBrand`, `Skip`, and carousel `RegulatoryBadge`; keep sign-in beneath the primary button.
- Keep the new visuals in the intro flow only; the app icon and other brand surfaces stay as they are.

## Review Focus

- Slow device, missing GIF, or decode failure: show the matching still PNG without a blank frame (Task 2 widget tests).
- Rapid Next/back/dot taps: displayed image, title, progress, and button label always refer to the same slide (Task 3 widget test).
- Reduced motion: the still PNG appears and no GIF animates (Task 2 widget test).
- Small screen and 2× text: lower panel scrolls and button/sign-in remain reachable (Task 2 widget test).
- Sign-in and final slide: existing users can reach login, while `Get started` still reaches verification method (Task 3 widget test).

## Source handoff before execution

- [ ] If the shared checkpoint in the splash plan has not been made, explicitly track both plans and the design brief with `git add -f` (new `docs/` files are ignored), plus only the nine approved `*-afro-*` artwork files. Leave earlier previews untracked and commit before creating a fresh worktree.

---

### Task 1: Promote reviewed art to app assets

**Files:**
- Create: `assets/img/onboarding/save.gif`, `goals.gif`, `pay.gif`
- Create: `assets/img/onboarding/save-still.png`, `goals-still.png`, `pay-still.png`
- Modify: `pubspec.yaml`
- Create: `test/onboarding_assets_test.dart`

**Interfaces:**
- Produces: six stable `assets/img/onboarding/...` asset paths consumed by Tasks 2 and 3.

- [ ] **Step 1: Write an asset test** that reads the six intended production paths, decodes each GIF and PNG, checks each is 600 × 600, checks GIF frame count > 1 and loop duration 1,920 ms, and checks the asset directory is declared in `pubspec.yaml`.
- [ ] **Step 2: Run `flutter test test/onboarding_assets_test.dart`** and expect missing-asset failures.
- [ ] **Step 3: Copy only the approved `*-afro-preview.gif` and matching `*-afro-preview.png` files** to the six named production paths. Declare `assets/img/onboarding/` explicitly in `pubspec.yaml` so Flutter bundles nested assets.
- [ ] **Step 4: Verify and commit.** Run `flutter test test/onboarding_assets_test.dart`; expect pass. Commit the six assets, manifest, and test together. Leave older preview versions out of the app bundle.

### Task 2: Screenshot-based slide presentation

**Files:**
- Create: `lib/module/onboarding/screens/onboarding_slide_view.dart`
- Modify: `lib/module/component/branding.dart` only to retire `OnboardingIllustration` if no other use remains
- Create: `test/onboarding_slide_view_test.dart`

**Interfaces:**
- Consumes: production paths from Task 1.
- Produces: `OnboardingSlideView({required String gifAsset, required String stillAsset, required String title, required String description, required int index, required int slideCount, required VoidCallback onNext, required VoidCallback onLogin, required ValueChanged<int> onSelect})`.

- [ ] **Step 1: Write widget tests** for the illustrated upper area on `BocColors.paper`, two pale off-canvas arcs, the 600 × 600 source scaled into a viewport-bounded square with `BoxFit.contain`, a white lower panel with rounded top corners, current title/body, accessible progress dots with at least 44 × 44 logical-pixel tap targets, `PrimaryButton`, and visible sign-in action. Assert `MediaQuery.disableAnimations` selects `stillAsset`; test no overflow or unreachable actions at 320 × 640, text scale 2.0, and 768 px width, including dark system theme.
- [ ] **Step 2: Run `flutter test test/onboarding_slide_view_test.dart`** and expect missing-widget failures.
- [ ] **Step 3: Implement `OnboardingSlideView`** using the existing `ResponsiveContent`, `ScrollableFill`, and `PrimaryButton` patterns. Paint subtle arcs behind only the illustration, keep the image in a stable viewport-bounded square, use a white lower panel with approximately 32 px top radius, navy title/button, centered copy and progress. Put the sign-in link below the button. Remove the old top lockup, Skip, and regulatory card when wiring the view in Task 3. Add semantic labels and large tap targets to the dots.
- [ ] **Step 4: Use `Image.asset(gifAsset)` with `frameBuilder`** to render `Image.asset(stillAsset)` until `frame` is non-null; use `errorBuilder` to render that still if GIF loading fails. Under `MediaQuery.disableAnimationsOf(context)`, build only the still image. Key the active GIF by the slide index so switching away and back starts a fresh loop; do not precache inactive GIFs. Test the first-frame fallback and an intentionally invalid GIF asset path.
- [ ] **Step 5: Verify and commit.** Run `flutter test test/onboarding_slide_view_test.dart` and `flutter analyze`; expect pass. Commit the presentation widget and tests.

### Task 3: Wire the three-slide flow

**Files:**
- Modify: `lib/module/onboarding/screens/startup_screens.dart`
- Modify: `test/in_app_branding_test.dart`
- Create: `test/onboarding_carousel_test.dart`

**Interfaces:**
- Consumes: `OnboardingSlideView` and its callbacks from Task 2.
- Produces: the existing `OnboardingScreen` route with the approved art in slide order Save → Goals → Send and pay.

- [ ] **Step 1: Write flow tests** for all three image/title/description pairs, dot selection, `Next` on slides 1–2, `Get started` on slide 3, and `I already have an account` navigation. Assert the carousel no longer uses `OnboardingIllustration`, top `CheetahBrand`, `Skip`, or `RegulatoryBadge`; keep logo assertions for bootstrap, login, and home.
- [ ] **Step 2: Run `flutter test test/onboarding_carousel_test.dart test/in_app_branding_test.dart`** and expect the new layout assertions to fail.
- [ ] **Step 3: Replace each slide's icon field** with its `gifAsset` and `stillAsset` path in `_OnboardingScreenState._slides`; keep the current titles and descriptions. Render `OnboardingSlideView` on a `BocColors.paper` scaffold even in dark mode, use dark status/navigation-bar icons, and connect callbacks to the current `_advance()` and `openAuthDestination` logic. Remove `OnboardingIllustration` only if `rg` confirms no other consumer.
- [ ] **Step 4: Verify and commit.** Run `flutter test test/onboarding_assets_test.dart test/onboarding_slide_view_test.dart test/onboarding_carousel_test.dart test/in_app_branding_test.dart test/widget_test.dart`, then `flutter analyze`, with writable Flutter SDK cache access; expect pass. Check all three slides on available iOS and Android simulators/devices at normal and large text sizes, including a full GIF loop and dark system theme. Report unavailable platform checks as unverified, then commit.
