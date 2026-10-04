# Branding and Local Notifications — Verification

**Date:** 3 October 2026
**Branch:** `feat/branding-local-notifications`
**Spec:** `docs/superpowers/specs/2026-10-02-branding-and-local-notifications-design.md`
**Plan:** `docs/superpowers/plans/2026-10-02-branding-and-local-notifications.md`

## Automated evidence

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | Pass, 0 files changed |
| Static analysis | `flutter analyze --no-pub` | Pass, no issues |
| Full test suite | `flutter test --no-pub` | 1,275 pass, 0 fail (4 Oct 2026) |
| Feature tests | `branding_assets`, `in_app_branding`, `platform_branding_config`, `notification_payload`, `local_notification_service`, `notification_delivery_policy`, `notification_tap_flow` | All pass |
| Whitespace | `git diff --check main...HEAD` | Two trailing-whitespace lines in generated `values-v31/styles.xml` and `values-night-v31/styles.xml`, kept verbatim so regeneration stays diff-free |
| Android builds | `flutter build apk --debug`, `flutter build apk --release` | Both built |
| iOS builds | `flutter build ios --simulator --debug`, `flutter build ios --release --no-codesign` | Both built |

### Previously failing KYC tests (fixed 4 Oct 2026)

The same 12 tests fail on the base commit `e8d8d23`, before any branding or notification change. They are in `kyc_government_id_smile_fallback_test.dart`, `kyc_government_id_start_test.dart` and `kyc_tier_return_test.dart`, and failed because the `DropdownButtonFormField<GovernmentIdDocumentType>` they tap was not found. Cause: they predate the rule that KYC opens only with a verified email and phone (`d379826`); their profile stubs had none, so the screen correctly showed the contact gate. The stubs now supply verified contacts. No app defect.

## Regeneration

Running `python3 tool/branding/generate_derivatives.py`, `dart run flutter_launcher_icons -f flutter_launcher_icons.yaml` and `dart run flutter_native_splash:create --path flutter_native_splash.yaml` reproduces every committed image and resource byte for byte. The generators also make two edits that must be reverted after every regeneration:

- `flutter_launcher_icons` sets `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon` in `ios/Runner.xcodeproj/project.pbxproj` (a generator bug; the committed value is `YES`).
- `flutter_native_splash` rewrites `ios/Runner/Info.plist`, adding only `UIStatusBarHidden = false` (the default) and reformatting the file.

Revert both with `git checkout ios/Runner.xcodeproj/project.pbxproj ios/Runner/Info.plist`.

## Visual review (automated renders)

The adaptive foreground was rendered over `#4F7EB4` under circle, squircle and rounded-square masks. The Cheetah's speed lines meet the mask edge as designed, with no floating cut, exposed off-canvas path or halo. The Android 12 splash icon sits inside its 768 px circle with its corners intact. The full icon reads at 24, 36, 52 and 96 px.

## Outstanding before release

| Item | Owner | Status |
|---|---|---|
| Monochrome Cheetah | Product owner | **Resolved 4 Oct 2026.** By the product owner's decision (replacing designer sign-off), `assets/branding/cheetah_monochrome.svg` is the approved path clipped to the frame without the blue field. The `ic_stat_boctrust` small icons (24–96 px, white on alpha), the Firebase default-icon metadata and the Android 13 themed icon are generated from it. The adaptive foreground inset is now 0%; the generator default of 16% had pulled the bleed inside the mask. |
| Backend sends data-only messages, or generic `notification` text | Backend | **Open.** OS-managed notification-payload messages show server text on the lock screen; release is blocked until confirmed. |
| White splash in dark mode | Design | **Open.** Needs confirmation. |
| Physical Android checks (launcher masks, themed icon, Android 12+ splash, dark mode, foreground/background/terminated delivery, permission denial, duplicate prevention, signed-in/out taps) | QA | **Not run.** No device in this session. |
| Physical iOS checks (AppIcon, launch screen, notification icon, delivery states, permission denial, best-effort data-only delivery, taps) | QA | **Not run.** |
| FCM taps still fire `onMessageOpenedApp` and `getInitialMessage()` after the `AppDelegate` delegate change | QA | **Not run.** This is the known failure mode of that change. |
| Device privacy check with data-only payloads holding fake balances, names and account numbers | QA | **Not run.** Covered by unit tests (generic copy, no content in logs, route/id-only payloads). |

Data-only background delivery on iOS remains best-effort and subject to APNs scheduling.
