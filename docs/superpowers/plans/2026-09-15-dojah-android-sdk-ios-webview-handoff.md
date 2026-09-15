# Boctrust iOS Dojah WebView + Android Native SDK Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking. This document is an implementation plan; rewriting it does not implement the application changes.

**Goal:** Make the current Boctrust/Cheetah Flutter app build and run on iOS, opening Dojah verification seamlessly inside the app through a WebView while preserving Android native Dojah and the existing Smile ID journeys.

**Architecture:** Keep the existing identity/document forms, backend initiation, provider validation, and authoritative status refresh. Within the validated Dojah branch, `DojahCaptureScreen` selects native Android or embedded iOS WebView. Make the existing repository-local Dojah Flutter plugin Android-only so iOS no longer links DojahWidget or its conflicting native dependencies.

**Tech Stack:** Existing Flutter 3.44.6/Dart 3.12.2 and Riverpod 3 app; local `dojah_kyc_sdk_flutter` 0.1.17 with Android SDK 0.4.2; iOS 15.0; existing SwiftPM integration. Add one WebView package selected in Task 1 by SwiftPM support and iOS media-permission capability (`webview_flutter` preferred, `flutter_inappwebview` only if evidence requires it). Add `permission_handler` only if device testing shows WKWebView's own prompt is insufficient.

**Spec:** The project-specific design and constraints embedded below are the specification for this rewrite, based on the user's request and inspected repository state on 2026-09-15.

**Status (2026-09-15):** Implemented in the working tree, awaiting commit: Task 1 packaging and Android raw-payload logging removal; an iOS WebView that opens `https://identity.dojah.io/?widget_id=…&reference_id=…` with the backend reference (per the user's direction, ahead of Task 2 evidence); navigation/media policy in `lib/module/kyc/service/dojah_web_policy.dart` (replacing the separate callback and permissions files in section 3); and one guarded finish in `DojahCaptureScreen`. Any navigation out of Dojah ends capture as `unknown` for backend reconciliation, so no callback vocabulary is assumed. Update after the Baobab review (same day): both platforms now send the backend reference as `metadata.reference` / `metadata[reference]` instead of the session-resuming `referenceId`/`reference_id`, the hosted URL adds `loading=async`, and native `approved`/`pending`/`failed`/`closed` results map to capture outcomes; see the verification document. Still open: section 1.1 answers (especially `reference_id` correlation and the redirect contract), staging widget IDs, the 45-second stall warning, WebKit process-termination handling, and all device verification in Task 6. See `docs/verification/dojah-kyc.md`.

**Tracking note:** `docs/` is listed in `.gitignore`. Commit this plan and verification-document updates with `git add -f`, as was done for `docs/verification/dojah-kyc.md`.

## 1. Scope and decisions

- iOS must never call native `DojahKyc.launch`; it opens an embedded WKWebView automatically when the validated backend provider is Dojah.
- Android keeps the patched native package and current launch argument mapping until evidence justifies a contract change. No automatic native-to-WebView fallback or new Android routing flag. Android does not gain a WebView path in this plan; its manifest has `CAMERA` but not `RECORD_AUDIO`, so any future Android WebView route must add audio permission deliberately.
- Keep Smile ID on both platforms, including backend-selected active Smile attempts and legacy response support. This plan does not change Smile launch, locking, or lifecycle behavior.
- Preserve iOS 15.0 and existing SwiftPM dependencies. Do not migrate the app's existing plugins to CocoaPods.
- Remove native Dojah from the iOS dependency graph as part of this work. This supersedes the earlier native-iOS packaging requirement in the September 12 plan for this integration. The goal is to remove CocoaPods from iOS entirely; keep it only if a newly selected plugin demonstrably lacks SwiftPM support.
- Use the existing `lib/module/kyc` feature and `test/` layout. Do not create a parallel `lib/features/kyc` architecture.
- Keep BVN/NIN re-entry, consent, document restrictions, clearing of sensitive form values, and backend authorization. Do not add BVN or email URL prefill by default.
- Client completion remains a capture outcome, never an authorization to unlock verified features. Refresh status/profile/tier/Home through the existing shared refresh mechanism.
- Do not invent backend endpoints, callback domains, user IDs, URL parameters, or resume semantics. Contract discovery (section 1.1) is a prerequisite for live WebView launch, not a reason to defer the iOS build repair.
- Out of scope, each needing its own plan: a cross-screen KYC attempt guard (existing notifier `_inFlight` guards already cover double submission), an Android native UI watchdog, and changes to utility bills, savings, bank verification, or global authentication policy.
- Keep provider URLs, personal data, raw provider results, and credentials out of logs. Only app-owned error categories and opaque attempt handles may enter diagnostics.

### 1.1 Blocking external questions

iOS Dojah cannot ship until the backend and Dojah dashboard owners answer these. Send them before Task 1 starts; Tasks 1, 3, and 4 proceed with mocks in the meantime.

1. **Launch URL:** Does the backend issue an attempt-bound hosted flow URL, or must the app build one from the widget ID? If built, which host and query parameters does each widget accept?
2. **Correlation:** Which parameter binds a hosted session to the backend attempt (`reference_id`, `metadata[...]`, or another)? Is the existing Android top-level `referenceId` app correlation or a Dojah resume/reverification identifier?
3. **Redirect:** What confirmation redirect URL (scheme, host, path) is configured for each widget in each environment?
4. **Callback vocabulary:** Which query keys and status values does the redirect carry for success, failure, and cancellation? Does it echo the reference?
5. **Webhook:** Which webhook field does the backend use to reconcile a hosted session with the attempt, and is it the same for native Android sessions?
6. **Capabilities:** Do the selfie and government-document widgets require microphone, location, or file upload?
7. **Origins:** Which origins does the hosted flow navigate to and request camera/microphone from?

Record answers, with sanitized evidence, in `docs/verification/dojah-kyc.md`.

### 1.2 Exact WebView URLs and payload reference

Inspected on 2026-09-15. The examples below use symbolic values, not real customer data. They document the URL contract explicitly; URL appearance alone does not establish backend correlation.

**Hosted entry point:** `https://identity.dojah.io/`.

**Current Boctrust working-tree implementation** in `lib/module/kyc/service/dojah_web_policy.dart`, `buildDojahIdentityUri`:

```text
https://identity.dojah.io/?widget_id={widgetId}&reference_id={referenceId}
```

It constructs this with `Uri.https('identity.dojah.io', '/', ...)`, trims and requires both values, and supplies the same backend `referenceId` currently forwarded by the Android gateway. This is an implemented mapping, not verified evidence that Dojah treats the value as Boctrust attempt correlation.

**Source Baobab WebView URL** from `/Users/kenechukwu/Documents/Other/baobab/lib/app/utils/dojah_webview.dart`:

```text
https://identity.dojah.io?widget_id={widgetId}&metadata[user_id]={backendUserId}&metadata[reference]={backendReference}&loading=async
```

The source optionally appends:

```text
&user_data[email]={email}
&gov_data[bvn]={bvn}
```

| Parameter | Source behavior | Boctrust rule |
|---|---|---|
| `widget_id` | Selects the dashboard flow | Use `DOJAH_SELFIE_WIDGET_ID` for identity and `DOJAH_GOVERNMENT_WIDGET_ID` for government ID |
| `reference_id` | Not present in the source WebView URL | Present in current Boctrust code; confirm whether it is a provider resume/reverification ID before accepting correlation |
| `metadata[reference]` | Carries the source backend reference | Candidate correlation mapping only after backend/webhook confirmation; do not silently replace or duplicate `reference_id` |
| `metadata[user_id]` | Source liveness call supplies the backend-issued user ID; its bank flow uses a profile ID | Boctrust initiation has no equivalent confirmed field; never invent one or substitute `smileUserId` |
| `loading` | Source sends `async` | Record whether the confirmed hosted flow needs it; it is not authentication or a callback parameter |
| `user_data[email]` | Included when email is supplied | Optional; omit by default unless the approved widget requires prefill |
| `gov_data[bvn]` | Included only for source flows supplied a BVN | Omit by default; never reconstruct BVN from a masked suffix or add it to the government-document flow automatically |

Use `Uri` query encoding for any adopted source parameters; do not reproduce string concatenation. Brackets may serialize as `%5B` and `%5D`, and a literal `+` in email must remain a plus after decoding. Do not serialize missing values as the text `null`.

The source constructor accepts `appId` and `publicKey`, but neither is used to build the hosted URL. It also receives `userData.phone` without adding it to the URL. Do not add unused keys, phone parameters, private API credentials, or an undocumented redirect parameter to Boctrust's request.

### 1.3 Exact source callback URLs and Boctrust matching rules

Source: `/Users/kenechukwu/Documents/Other/baobab/lib/app/utils/dojah_callback_matcher.dart` and its `test/app/utils/dojah_callback_*_test.dart` tests.

| Source purpose | URL | Actual source matching behavior |
|---|---|---|
| Staging identity callback | `https://baobab-web.enyata.com/dojah/callback` | Exact host; path accepts trailing slashes |
| Staging example in tests | `https://baobab-web.enyata.com/dojah/callback/?status=success` | Same callback with the source's evidenced success token |
| Bank-account callback | `https://jollofplus.admin.baobab.com/payment/callback` | Exact host and normalized path; tests include `?status=success` and `?status=cancelled` |
| Legacy callback | `https://www.jollofplus.ng/` | Source accepts **any path** on this host; `/` is illustrative, not a verified exact callback path |

These are Baobab/Jollof callback addresses, not confirmed Boctrust endpoints. The bank-account callback is reference material only; this plan covers Boctrust identity and government-document capture. Do not install these domains as Boctrust defaults or redirect customer data to them without confirmation that the Boctrust widgets intentionally use them.

The source matcher requires HTTPS but does not enforce the strict effective-port/user-info checks required by this plan. Its parser treats absent/empty status as success and also accepts `successful`, `completed`, and `approved`; only `success` is evidenced as a success token in its code/tests, not a freshly observed device session. Do not carry those permissive rules into Boctrust.

**Boctrust callback configuration:** no exact Dojah confirmation URL is present in the inspected environment files. Both widget ID values are currently empty in `.env.example`, `.env.stage`, and `.env.prod`. A configured browser redirect is also distinct from the existing Smile `callbackUrl` backend webhook. Record each published widget's actual redirect before enabling live capture.

The current working-tree `decideDojahNavigation` ends capture with `unknown` whenever navigation leaves a trusted Dojah page for another HTTP(S) URL. That is interim behavior, **not an exact callback contract**: a help/privacy/external link must not be mistaken for completion. Task 4 must distinguish confirmed callbacks from unrelated navigation.

Required callback policy:

- Match only the configured HTTPS host, effective port, and exact path; explicitly list a trailing-slash alternative if the dashboard emits it.
- Inspect main-frame navigation only; reject user-info, malformed status, and repeated status/reference keys.
- Compare a reference/state field with the active attempt if the confirmed redirect includes one. A redirect without it may trigger backend refresh but never proves verification.
- Map confirmed success to `submitted`, confirmed failure to `failed`, confirmed cancellation to `cancelled`, and missing/unknown status to `unknown`. All are client capture outcomes, never backend verification results.
- Handle both callback navigation and user Close once. Block callback loading after processing, and let the capture-screen owner perform the only Navigator pop.

### 1.4 Configuration and device checklist for the URL integration

For each environment and operation, record the following together in `docs/verification/dojah-kyc.md` before live acceptance:

1. Published widget ID, hosted entry URL, exact query-field mapping, and an encoded fixture with synthetic values.
2. Exact confirmation callback URL(s), accepted path variants, observed status vocabulary, and any echoed reference/state key.
3. Backend attempt/reference field, provider webhook correlation field, and evidence that both platforms update the intended attempt.
4. Required camera/microphone capabilities and all confirmed navigation/media origins. `https://identity.dojah.io` is the entry origin; it is not evidence that all `*.dojah.io` origins or all embedded frames are trusted.
5. Inline playback enabled, JavaScript enabled, existing iOS camera/mic usage descriptions retained, progress and Close UI, and real-iPhone capture/upload checks.
6. The selected `webview_flutter` permission API does not expose the requesting frame's origin. Checking the top-level URL cannot establish an iframe's origin; retain the platform prompt when available, or resolve this limitation with a supported origin-aware mechanism before claiming origin-based media grants.
7. No full URL/result logging, no raw BVN/email in telemetry, and browser-session cleanup verified across logout/account changes.

Sections 1.2–1.4 supply Task 2's concrete reference material and Task 4's callback/permission acceptance cases. They preserve the selected SwiftPM-compatible WebView package and the existing Task 1 progress; source `flutter_inappwebview` usage is not an instruction to replace it.

### User experience

1. The user completes the existing identity or document form and consent flow.
2. The current backend initiates/authorizes an attempt and chooses Dojah or Smile.
3. Existing launch validation checks provider, environment, operation, expiry, and reference.
4. Smile follows its current route. Dojah opens the existing capture route: Android launches native capture; iOS displays the hosted flow with a loading indicator and Close action.
5. A valid completion signal closes only that capture route. The originating screen refreshes backend state and displays pending/review or verified according to that state.
6. Closing midway returns without a success message. Loading errors and ambiguous completion show a recovery message and allow status refresh; they never silently create another provider session.

### Packaging alternatives considered

| Approach | Consequence | Decision |
|---|---|---|
| Android-only registration in the existing local plugin; iOS WebView | Removes DojahWidget/Realm conflict; reuses the already maintained fork | Selected |
| Keep native iOS dependencies but route Dart to WebView | Leaves the documented Lottie linker blocker | Rejected |
| Move all plugins to CocoaPods | Broad migration that changes working Smile/Firebase integration | Outside scope |

### WebView package alternatives

| Package | Evidence on 2026-09-15 | Decision |
|---|---|---|
| `webview_flutter` (+ `webview_flutter_wkwebview`) | Flutter-team maintained. Resolved `webview_flutter` ^4.14.1 with `webview_flutter_wkwebview` 3.26.1: ships `darwin/webview_flutter_wkwebview/Package.swift` (iOS 13+); `WebKitWebViewControllerCreationParams` exposes `allowsInlineMediaPlayback` and `mediaTypesRequiringUserAction`; `setOnPlatformPermissionRequest` receives camera/microphone capture requests. The request object does **not** expose the requesting `WKSecurityOrigin`. | Selected in Task 1 |
| `flutter_inappwebview` 6.x | Cached `flutter_inappwebview_ios` 1.1.2 has no `Package.swift`, so it would keep CocoaPods on iOS | Use only if `webview_flutter` cannot meet a confirmed flow requirement and the resolved version's SwiftPM status is rechecked |

## 2. Verified project baseline

These are repository observations, not claims of fresh successful builds or live backend support.

| Existing file | Current responsibility / evidence |
|---|---|
| `pubspec.yaml`, `packages/dojah_kyc_sdk_flutter/pubspec.yaml` | Local path dependency, package version 0.1.17; Android and iOS registration currently enabled |
| `packages/dojah_kyc_sdk_flutter/BOCTRUST_PATCH.md` | Existing native completion/concurrency patches to preserve on Android; states only completion behavior changed |
| `packages/dojah_kyc_sdk_flutter/android/build.gradle` | Native artifact `com.github.dojah-inc:sdk-kotlin:v0.4.2` |
| `packages/dojah_kyc_sdk_flutter/android/src/main/kotlin/com/dojah/dojah_kyc_sdk_flutter/DojahFlutterSdkPlugin.kt` | Lines 121 and 129 log the raw result payload with `Log.d("DojahFlutterSdkPlugin", "Got Result: ...")` |
| `android/build.gradle.kts` | Scoped plugin compileSdk 36 and Kotlin/JVM 1.8 workaround |
| `android/app/src/main/AndroidManifest.xml` | `INTERNET`, `POST_NOTIFICATIONS`, `CAMERA`; no `RECORD_AUDIO` |
| `ios/Podfile`, `ios/Podfile.lock`, `ios/DojahWidget.podspec` | Only Dojah pods (DojahWidget, Realm 10.54.6, lottie-ios, GooglePlaces, and others) plus the Lottie `post_integrate` embedding workaround |
| `.gitmodules`, `ios/vendor/dojah-widget/` | Submodule for `dojah-inc/sdk-swift` `pod-package`, consumed only by `ios/DojahWidget.podspec` |
| `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig` | Optional `#include?` of Pods-Runner xcconfig |
| `ios/Runner.xcodeproj/project.pbxproj` | 53 Pods references from CocoaPods integration |
| `ios/Runner/Info.plist` | `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` already present for Smile; no location key |
| `.github/workflows/flutter-quality.yml` | iOS job checks out submodules, runs `pod install --deployment`, and greps `Podfile.lock` to keep Firebase/Smile on SwiftPM |
| `README.md` | iOS setup requires `git submodule update --init` and `pod install --deployment`; states Dojah needs CocoaPods |
| `docs/verification/dojah-kyc.md` | Historical Android checks; hybrid iOS Lottie linker failure; backend contract evidence limitations |
| `lib/module/kyc/service/dojah_gateway.dart` | Fakeable native gateway; top-level `referenceId`; concurrent native launch exclusion |
| `lib/module/kyc/screens/dojah_capture_screen.dart` | One native launch per screen, retry/error UI, typed return |
| `lib/module/kyc/service/dojah_config.dart` | Identity/selfie and government-document widget selection |
| `lib/app/services.dart`, `.env.example` | Compile-time environment and Dojah widget IDs |
| `lib/module/kyc/model/kyc_provider_models.dart` | `validateKycLaunch`, provider/operation enums, `KycCaptureOutcome` |
| `lib/module/kyc/model/kyc_models.dart` | `KycInitiationData`: attempt/reference/expiry context; no canonical Dojah user ID or hosted launch URL |
| `lib/module/kyc/screens/kyc_screens.dart` | Existing consent/forms, provider dispatch, capture outcomes |
| `lib/module/kyc/provider/kyc_providers.dart` | Existing initiation, input validation, caching, conflict handling, and per-notifier `_inFlight` double-submit guards |
| `lib/module/kyc/provider/kyc_status_provider.dart` | Coalesced status/profile/tier/Home refresh via `refreshKycAuthoritativeState` |
| `lib/app/session_expiry_coordinator.dart` | Authentication expiry and clearing user data; no inactivity-expiry lease API |

The current gateway's `referenceId` forwarding is an implementation fact, not proof that backend/provider correlation works in production. The previous evidence document explicitly leaves live provider contracts and device capture unverified.

## 3. File and interface map

Modify existing files above only where required. Add these focused units:

| New file | Responsibility |
|---|---|
| `lib/module/kyc/service/dojah_platform_route.dart` | Pure Android/iOS/unsupported selection |
| `lib/module/kyc/model/dojah_web_launch.dart` | Validated hosted URL, callback policy, trusted origins, and attempt binding |
| `lib/module/kyc/service/dojah_web_callback.dart` | Pure callback parser; no navigation or verification authority |
| `lib/module/kyc/service/dojah_web_permissions.dart` | Web resource permission policy (origin and resource allowlist) |
| `lib/module/kyc/screens/dojah_webview.dart` | Browser body owned by `DojahCaptureScreen`; reports terminal outcomes by callback |
| `test/dojah_platform_route_test.dart` | Platform matrix |
| `test/dojah_web_launch_test.dart` | Configuration and attempt-bound payload tests |
| `test/dojah_web_callback_test.dart` | Callback origin/path/status/reference validation |
| `test/dojah_web_permissions_test.dart` | Permission allow/deny policy |
| `test/dojah_webview_test.dart` | Browser wrapper lifecycle and duplicate completion |

Extend existing `test/dojah_gateway_test.dart`, `test/dojah_capture_screen_test.dart`, `test/kyc_provider_models_test.dart`, `test/kyc_identity_flow_test.dart`, and `test/kyc_government_id_flow_test.dart`. Update `docs/verification/dojah-kyc.md` with actual evidence without overwriting the historical failure record.

## 4. Implementation tasks

### Task 1: Remove native Dojah from iOS and establish a working build

**Files:**
- Plugin: `packages/dojah_kyc_sdk_flutter/pubspec.yaml`, `packages/dojah_kyc_sdk_flutter/BOCTRUST_PATCH.md`, `packages/dojah_kyc_sdk_flutter/android/src/main/kotlin/com/dojah/dojah_kyc_sdk_flutter/DojahFlutterSdkPlugin.kt`.
- App dependencies: `pubspec.yaml`, `pubspec.lock`.
- iOS: `ios/Podfile`, `ios/Podfile.lock`, `ios/DojahWidget.podspec`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`, `ios/Runner.xcworkspace/contents.xcworkspacedata`.
- Submodule: `.gitmodules`, `ios/vendor/dojah-widget`.
- CI and docs: `.github/workflows/flutter-quality.yml`, `README.md`, `docs/verification/dojah-kyc.md`.
- Interim routing: `lib/module/kyc/screens/dojah_capture_screen.dart`, new `lib/module/kyc/service/dojah_platform_route.dart`, `test/dojah_platform_route_test.dart`, `test/dojah_capture_screen_test.dart`.

**Produces:** Reproducible iOS build without native Dojah, a chosen WebView dependency, and an explicit "unavailable on iOS" Dojah state until Task 4 lands.

- [ ] Record `flutter --version`, `xcodebuild -version`, `git status --short`, and the current dependency lock state. Read repository instructions before editing.
- [ ] Keep the local package version/path and Android code. Change its plugin declaration to:

```yaml
flutter:
  plugin:
    platforms:
      android:
        package: com.dojah.dojah_kyc_sdk_flutter
        pluginClass: DojahFlutterSdkPlugin
```

- [ ] Remove the raw payload `Log.d` calls at `DojahFlutterSdkPlugin.kt:121` and `:129` (or replace them with a category-only message that contains no payload). Update `BOCTRUST_PATCH.md` to record both the Android-only registration and the logging removal, and amend its "only completion behavior changed" statement accordingly. The unused package iOS source can remain as upstream provenance; it must not be registered or linked.
- [ ] Select the WebView package before editing lockfiles. For the latest stable `webview_flutter` and `flutter_inappwebview` compatible with Flutter 3.44.6, record: (a) whether the resolved iOS implementation ships a `Package.swift`; (b) whether it can grant WKWebView camera/microphone capture requests per origin on iOS 15+; (c) inline media playback support. Choose `webview_flutter` unless it fails (b) or (c). Record the decision and evidence in `docs/verification/dojah-kyc.md`.
- [ ] Do not add `permission_handler` in this task. WKWebView presents the system camera/microphone prompt when the existing Info.plist usage strings are present. Revisit only if Task 4 device testing demonstrates a need (for example a Settings deep link after permanent denial).
- [ ] Add the selected WebView dependency and run `flutter pub get`. Let tooling regenerate plugin registrations; do not hand-edit generated registration lists or the pub cache.
- [ ] Remove the Realm and DojahWidget pods and the Lottie `post_integrate` hook from `ios/Podfile`. Then:
  - If no remaining plugin needs CocoaPods (expected with `webview_flutter`), run `pod deintegrate` in `ios`, delete `Podfile` and `Podfile.lock`, and confirm `project.pbxproj`, `Runner.xcworkspace`, and the `Debug`/`Release` xcconfig `#include?` lines no longer reference Pods.
  - If a selected plugin lacks SwiftPM support, keep a minimal Podfile with the normal Flutter `post_install` setup, run `pod install`, and record which plugin requires it.
- [ ] Retire the submodule after confirming `ios/DojahWidget.podspec` was its only consumer: `git submodule deinit -f ios/vendor/dojah-widget`, `git rm ios/vendor/dojah-widget`, remove its `.gitmodules` entry, delete `.git/modules/ios/vendor/dojah-widget`, and delete `ios/DojahWidget.podspec`.
- [ ] Update `.github/workflows/flutter-quality.yml` in the same commit:
  - Without a Podfile: remove `submodules: true`, remove `pod install --deployment`, and replace the Podfile.lock grep with a step asserting `ios/Podfile`, `ios/Podfile.lock`, and `ios/Pods` do not exist and `.gitmodules` has no `dojah-widget` entry.
  - With a minimal Podfile: keep `pod install --deployment`, keep the Firebase/Smile grep, and add a grep asserting `Podfile.lock` contains no `DojahWidget`, `Realm`, or `dojah_kyc_sdk_flutter`.
- [ ] Update `README.md` iOS setup: remove the submodule and Dojah CocoaPods instructions (or reduce `pod install` to the plugin that needs it), and state that iOS Dojah runs through an embedded WebView while Android uses the native SDK.
- [ ] Add the pure platform router now so iOS never reaches the removed method channel between this task and Task 4:

```dart
enum DojahPlatformRoute { nativeAndroid, iosWebView, unsupported }

DojahPlatformRoute chooseDojahPlatformRoute({
  required bool isWeb,
  required bool isAndroid,
  required bool isIOS,
}) {
  if (isWeb) return DojahPlatformRoute.unsupported;
  if (isIOS) return DojahPlatformRoute.iosWebView;
  if (isAndroid) return DojahPlatformRoute.nativeAndroid;
  return DojahPlatformRoute.unsupported;
}
```

```dart
test('iOS chooses the embedded browser', () {
  expect(chooseDojahPlatformRoute(
    isWeb: false, isAndroid: false, isIOS: true,
  ), DojahPlatformRoute.iosWebView);
});
```

- [ ] In `DojahCaptureScreen`, skip the native `_launch` when the route is not `nativeAndroid`. Until Task 4 wires the browser, show a non-retryable message ("Verification with this provider is not yet available on this device.") with a Close action that returns `KycCaptureOutcome.cancelled`. Test zero native gateway calls on iOS, one on Android, and a single unsupported-platform case.
- [ ] Inspect the resolved iOS graph: no DojahWidget, Dojah Flutter iOS plugin, or Dojah-only Realm dependency; Smile and its SwiftPM Lottie dependency remain.
- [ ] Build simulator debug, unsigned device release, and Android release. If stale generated artifacts interfere, use normal Flutter/Xcode regeneration and reproduce in a clean checkout before acceptance.

```bash
flutter pub get
flutter test test/dojah_platform_route_test.dart test/dojah_capture_screen_test.dart test/dojah_gateway_test.dart
flutter build ios --simulator --debug --dart-define-from-file=.env.stage
flutter build ios --release --no-codesign --dart-define-from-file=.env.stage
flutter build apk --release --dart-define-from-file=.env.stage
```

- [ ] Record exact commands, resolved versions, build results, and remaining errors. Commit scoped packaging changes after successful checks. An iOS build is a distinct milestone; it does not establish a working hosted KYC session.

### Task 2: Establish the Boctrust hosted-flow contract

**Files:** `dojah_config.dart`, new `dojah_web_launch.dart`, `services.dart`, `.env.example`, `docs/verification/dojah-kyc.md`; modify `kyc_models.dart` only if an agreed backend response extension is required.

**Consumes:** Answers to section 1.1, existing `KycInitiationData`, selected `KycOperation`, corresponding widget ID.

**Produces:** An immutable `DojahWebLaunch` with `Uri initialUri`, `Uri callbackUri`, `String attemptId`, `String referenceId`, `Set<String> navigationOrigins`, `Set<String> mediaOrigins`, `bool requiresMicrophone`, and an explicit status/reference callback policy. Origins use normalized scheme/host/effective-port, never substring matching.

- [ ] Obtain a sanitized staging initiation response and dashboard flow link for **both** selfie and government-document widgets. Record environment, allowed documents, camera/mic requirements, confirmation redirect, emitted callback keys/statuses, and webhook correlation field. Do not put real account identifiers or launch URLs into committed fixtures.
- [ ] Trace the existing Android `referenceId` through the backend and provider event. Determine whether it represents a provider resume identifier or app correlation. Retain current forwarding unless this evidence requires a coordinated correction and regression tests.
- [ ] Prefer a backend-issued attempt-bound hosted URL when the existing contract supports one. Otherwise construct a URI from the dashboard-confirmed hosted-flow contract and the backend's existing reference, using `Uri` query parameters. Do not assume `metadata[reference]`, `reference_id`, and SDK `referenceId` are interchangeable.
- [ ] For a required backend extension, document the precise agreed response field and parser with a sanitized fixture before coding it. Do not infer a Dojah user ID from Smile credentials or unrelated profile fields. A plain widget link with no demonstrated attempt correlation is insufficient for release.
- [ ] Keep launch configuration separate from the legacy Smile `callbackUrl`; that value can be a server webhook, not a browser redirect. Add Dojah-specific compile-time configuration only for confirmed static values, using the existing `String.fromEnvironment` pattern. Missing iOS web configuration disables only that Dojah launch (keeping the Task 1 unavailable message), not app startup, Android, or Smile.
- [ ] Write failing tests for missing config, wrong environment, expired attempt, wrong operation, unsafe/non-HTTPS launch URL, unexpected host/port/user-info, and encoding of any confirmed query fields. Implement validation and run `flutter test test/dojah_web_launch_test.dart test/kyc_provider_models_test.dart`.
- [ ] Record actual callback success/failure/cancellation vocabulary. Unknown or absent status will produce `KycCaptureOutcome.unknown`. If the flow emits only a completion redirect, use it as an unknown completion signal and reconcile backend state.
- [ ] Commit the contract/configuration unit after tests pass. Without live contract evidence, continue mock-based UI work, but keep live iOS Dojah unavailable with a clear configuration message. List the exact missing section 1.1 answers as release blockers.

### Task 3: Pass launch context through the existing capture screen

**Files:** existing `dojah_capture_screen.dart`, `dojah_gateway.dart`, `kyc_screens.dart`; capture-screen and identity/document flow tests.

**Consumes:** The router from Task 1, `DojahWebLaunch` from Task 2, and the validated Dojah initiation and operation from existing provider dispatch.

**Produces:** Platform-selected content in one existing capture route, with the existing `KycCaptureOutcome` Navigator result.

- [ ] Pass the validated initiation context through `_openDojahCapture` into `DojahCaptureScreen`; retain widget selection by operation. Keep `validateKycLaunch` and Smile dispatch outside platform selection. Revalidate expiry before loading the provider after any permission wait.
- [ ] On Android retain `NativeDojahGateway`. On iOS build a `DojahWebLaunch`; if it cannot be built, keep the unavailable message from Task 1. For unsupported platforms keep the recoverable unavailable message without initializing a provider view.
- [ ] Keep the existing four-value `KycCaptureOutcome`; represent loading/permission/configuration errors in local screen state. Use one guarded `finish(KycCaptureOutcome outcome)` owner on the capture screen. Child browser events report outcomes but never pop Navigator themselves.
- [ ] Test both operations selecting their intended widget, iOS launch-configuration failure falling back to the unavailable state, and Smile never entering the platform router. Run capture/provider/flow tests and commit.

### Task 4: Implement embedded capture, callbacks, and media permissions

**Files:** new `dojah_webview.dart`, `dojah_web_callback.dart`, `dojah_web_permissions.dart`; `dojah_capture_screen.dart`, `ios/Runner/Info.plist` (only if a new capability is confirmed); corresponding tests.

**Consumes:** `DojahWebLaunch` and `void Function(KycCaptureOutcome) onFinished`.

**Produces:** A browser body that completes once, supports camera capture, and returns safe outcomes to its owner.

- [ ] Add parser tests first. Distinguish a non-callback navigation (`null`) from a matched but ambiguous callback (`KycCaptureOutcome.unknown`). Require HTTPS, exact callback host/effective-port/path, no user-info, and top-level navigation. Use `queryParametersAll` with malformed-input handling and reject duplicate status/reference keys.
- [ ] Match any callback reference/state against the active attempt using only the confirmed callback contract. Do not demand a parameter the provider does not send. A callback without a binding field can trigger status refresh for the active attempt but cannot prove verification.
- [ ] Configure the browser selected in Task 1 with the validated URI and these behaviors, using that package's API: JavaScript enabled, inline media playback allowed, media playback without a user gesture, and a navigation delegate that sees every top-level request before it loads. For `webview_flutter` this means a `WebKitWebViewControllerCreationParams` with `allowsInlineMediaPlayback: true` and `mediaTypesRequiringUserAction` empty, plus `NavigationDelegate.onNavigationRequest`.
- [ ] Intercept the exact callback before normal navigation policy. Limit top-level navigation to confirmed flow origins; deny unexpected external schemes/popups. Keep TLS validation enabled. Do not enable arbitrary file access or add a JavaScript bridge unless the confirmed flow requires one.
- [ ] Rely on the existing `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` strings, which Smile also needs; do not reword them without checking Smile. Do not introduce location, storage, or photo-library keys without a confirmed section 1.1 requirement.
- [ ] Implement web permission decisions in `dojah_web_permissions.dart` with the selected package's platform permission-request callback: grant only camera (and microphone when `requiresMicrophone`), and deny unknown resources. `webview_flutter_wkwebview` 3.26.1 does not pass the requesting origin to Dart, so enforce `mediaOrigins` by granting only while the current main-frame URL's origin is in the allowlist, and by denying navigation (including iframe loads where the navigation delegate reports them) to untrusted origins. If Dojah embeds media capture in a third-party iframe, record it and decide whether a narrow package extension is needed before release. WKWebView then presents the OS prompt itself. On a real iPhone test first-run allow, deny, and returning from Settings after denial. Add `permission_handler` only if that test shows the app must detect or deep-link a permanent denial, and then verify its SwiftPM installation and permission-enabling mechanism rather than assuming CocoaPods preprocessor macros apply.
- [ ] Display load progress, a Close action, and a 45-second initial-load stall warning. Main-frame network/HTTP/TLS failure shows a recoverable error; subresource failures do not terminate capture automatically. WebKit process termination ends as unknown and triggers reconciliation.
- [ ] Handle callback duplication across navigation events with one terminal flag. Check mounted/current-route ownership before finishing. Close/back/swipe returns cancelled; disposal stops browser work and suppresses late callbacks. Do not retain keep-alive sessions or leak cookies/session data across logout; verify clearing with the selected package's cookie/website-data API.
- [ ] On load failure, offer Close/Refresh status. Any relaunch must revalidate the existing attempt through the initiating flow; never blindly reload a possibly submitted session.
- [ ] Use a fake browser wrapper for widget tests covering progress, close, duplicate events, disposal, process loss, denied permissions, and callbacks after another route is shown. Run all four new web tests and commit.

### Task 5: Reconcile outcomes and preserve backend authority

**Files:** `kyc_screens.dart`, `dojah_capture_screen.dart`; `test/kyc_identity_flow_test.dart`, `test/kyc_government_id_flow_test.dart`, `test/dojah_capture_screen_test.dart`. Touch auth cleanup only for scoped WebView disposal.

**Consumes:** Existing initiation methods and `_inFlight` guards, validated capture route, authoritative refresh, and auth lifecycle.

**Produces:** Safe close, retry, and logout behavior for the iOS WebView route without changing Android or Smile lifecycle behavior.

- [ ] Rely on the existing notifier `_inFlight` guards for double submission. Before adding any cross-screen lock, write a failing test that starts identity and document verification concurrently; if it does not reproduce an overlap, add no guard. If it does, raise a separate plan covering Smile too.
- [ ] Re-check mounted state after awaits and before navigation. A logout must dispose the active WebView, clear its website data, and prevent stale results from updating another account's state.
- [ ] Keep the existing Android native pending-call exclusion and result classification unchanged. `Verification Completed` and unrecognised tokens remain unknown. An Android UI watchdog is out of scope; if later required, it must start only after a native closure signal, as recorded in the 2026-09-12 coding plan, never at launch.
- [ ] Route return, including cancellation/unknown/error, refreshes authoritative state once through `refreshKycAuthoritativeState`. Reuse existing screen refresh facilities instead of adding competing polling loops. Pending review remains pending, never a timed-out rejection.
- [ ] Retry first refreshes/revalidates the existing attempt. Preserve BVN/NIN backend reauthorization and reject cached expired/wrong-operation context. Changed form data must pass through initiation. Do not infer resumability from a generic 409 or masked suffix. After process restart, rely only on available backend-authorized context; if absent, show status recovery without inventing a resume endpoint or starting another session.
- [ ] Do not introduce a global session-expiry lease: this app has no such abstraction. Existing explicit logout/auth revocation continues to apply while the browser is open.
- [ ] Test WebView cancellation, unknown and error returns each refreshing once, logout during an open WebView, changed input, expired cached attempts, provider-selected Smile, and a pending backend after apparent client success. Run affected KYC tests and commit.

### Task 6: Verify builds, real capture, and release readiness

**Files:** `docs/verification/dojah-kyc.md`; fix only defects in this integration uncovered by these checks.

- [ ] Run `flutter analyze`, `dart format --output=none --set-exit-if-changed lib test`, the new tests, the existing KYC suites, and the full app test suite. Record results rather than importing historical pass counts.
- [ ] Rebuild iOS simulator and unsigned device release with staging defines after all integration changes. Boot the simulator build and verify app startup and entry into the Dojah browser with non-production test configuration. Simulator camera results are not capture acceptance.
- [ ] Rebuild Android release with the existing SDK/dependency settings and run it on a physical device. Confirm the SDK launch and patched completion behavior remain intact, and that `adb logcat` no longer shows raw Dojah result payloads.
- [ ] On a real iPhone, verify each distinct configured flow using the matrix below. Use the app's normal signing workflow; an unsigned build verifies compilation/linking only.

| Scenario | Required result |
|---|---|
| Selfie/identity and government-document launch | Correct widget, same backend-authorized attempt, inline browser |
| Capture and upload | Camera/liveness works; required audio works; no external browser jump |
| Completed with backend pending, then verified | Pending first; verified only after authoritative refresh |
| Rejection, close, back/swipe | One safe return, no false success, recoverable attempt |
| Permission denial and Settings return | Clear recovery; no unconditional web grant |
| Offline start, upload interruption, process loss | Error/unknown plus status recovery; no duplicate session |
| Repeated callbacks and double taps | One capture and one terminal navigation |
| Background/resume, logout, account change | Refresh safely; no stale UI or previous-user web session |
| App kill/restart | Backend reconciliation; no invented resume context |
| Backend selects Smile on either platform | Existing Smile capture still works |

- [ ] Verify dashboard/provider event and backend record agree on the expected attempt, user, widget, and environment for both platforms. A successful WebView render alone is not sufficient.
- [ ] Reproduce dependency installation and iOS/Android builds from a clean checkout with committed lockfiles and no submodule initialization. Inspect the iOS registration/link graph to confirm native Dojah has not returned.
- [ ] Update the verification document with build commands, package locks, device/OS, tested operation, sanitized outcome, backend evidence, and any release blockers. Commit verified changes with `git add -f` for files under `docs/`; do not claim deployment or production enablement without performing those actions.

## 5. Acceptance checklist

- [ ] iOS builds and launches with existing SwiftPM/Smile support, no linked native DojahWidget, no `dojah-widget` submodule, and no CocoaPods unless a recorded plugin requires it.
- [ ] CI and README reflect the new iOS setup and guard against native Dojah returning.
- [ ] Local Dojah 0.1.17 Android SDK 0.4.2 and completion patches are preserved; raw result logging is removed and recorded in `BOCTRUST_PATCH.md`.
- [ ] The WebView package choice and its SwiftPM/media-permission evidence are recorded.
- [ ] iOS Dojah opens seamlessly in the existing capture route and never calls its native method channel.
- [ ] Existing provider, environment, operation, expiry, consent, and form authorization behavior remains intact.
- [ ] Every section 1.1 question has a recorded answer, and hosted flow correlation is demonstrated with backend/provider evidence for both operations.
- [ ] Capture permissions, callback validation, one-shot completion, cancellation, retries, and logout pass tests and device checks.
- [ ] Backend status/profile/tier/Home remain authoritative and consistent after provider return.
- [ ] Existing Smile journeys pass on both platforms, with no change to their lifecycle behavior.
- [ ] Clean builds, relevant tests, physical-device capture, and evidence recording are complete before release.

## 6. Evidence limits and references

This rewrite inspected local code, dependency declarations, existing tests, CI configuration, the pub cache, and `docs/verification/dojah-kyc.md`. It did not execute app builds, run tests, change application code, or validate staging sessions. SwiftPM observations come from locally cached package versions and must be rechecked against versions resolved in Task 1. Backend launch/callback values and live attempt correlation remain implementation discovery requirements, explicitly separate from the actionable iOS packaging fix.

Official references checked during planning:

- [webview_flutter](https://pub.dev/packages/webview_flutter) and [webview_flutter_wkwebview](https://pub.dev/packages/webview_flutter_wkwebview): WKWebView configuration, navigation delegate, and platform permission requests.
- [InAppWebView WebRTC](https://www.inappwebview.dev/docs/web-rtc/): iOS inline playback and media permissions, for comparison only.
- [Dojah confirmation page](https://docs.dojah.io/guides/identity/easyonboard/confirmation-page): hosted flows can use a configured redirect; it does not specify Boctrust's callback parameters.
- [Dojah API changelog](https://docs.dojah.io/changelog/api_changes): references can have reverification/authentication semantics, reinforcing the need to verify correlation rather than translate parameter names mechanically.

No Baobab file, package pin, app identifier, flow ID, callback URL, metadata user ID, or build workaround is an implementation dependency of this plan.
