# Dojah KYC integration verification

Verified on 2026-09-14 in the isolated `codex/dojah-kyc` worktree.

## Versions

- Flutter package: `dojah_kyc_sdk_flutter` 0.1.17
- Android SDK: `com.github.dojah-inc:sdk-kotlin:v0.4.2`
- iOS DojahWidget: 1.1.17 at commit
  `46f11f2938f4b70fe0cde915b68d34a5d712ba8c`
- iOS Realm compatibility candidate: 10.54.6

## Passing checks

- `flutter analyze --no-pub`
- `flutter test --no-pub --reporter expanded` (810 tests)
- `flutter build apk --debug`
- `flutter build apk --release`
- `./gradlew :dojah_kyc_sdk_flutter:compileReleaseKotlin --rerun-tasks`

Android required JitPack, Jetifier for Dojah's legacy support-library
dependency, API 36 for the Dojah library module, Kotlin/JVM 1.8 for that
module, desugaring 2.1.5, and a manifest label override for a transitive
dependency. These settings are scoped to the published SDK where possible.
The repository-local copy also applies the completion-only changes recorded in
`packages/dojah_kyc_sdk_flutter/BOCTRUST_PATCH.md`.

## iOS compatibility result

The reviewed hybrid strategy keeps existing Flutter plugins, including Smile
ID, on Swift Package Manager and installs only DojahWidget and Realm through
CocoaPods. A clean simulator build exposed two upstream compatibility issues:

1. DojahWidget 1.1.17 constrains RealmSwift to 10.52.2. That release's module
   is read by Xcode 26.6 as requiring iOS 26.5 and cannot compile for the app's
   iOS 15 target. A local podspec using Realm 10.54.6 resolves this issue.
2. Smile and Dojah both bring Lottie 4.5.2 through different dependency
   managers. Embedding both produces duplicate `Lottie.framework` commands.
   Leaving SwiftPM as the only embed owner reaches the linker but fails because
   Dojah's CocoaPods build requires `unsafeMutableAddressor` symbols that the
   SwiftPM Lottie binary does not expose.

For comparison only, disabling SwiftPM and resolving all existing iOS plugins
through CocoaPods produced a successful simulator build. That migration was
rolled back because the approved plan explicitly limits CocoaPods to Dojah and
forbids migrating the existing plugins. The hybrid configuration remains the
recorded compatibility blocker and must not be released as-is.

Physical-device capture, actual widget IDs, native completion edge cases, and
backend webhook reconciliation remain unverified until an approved iOS package
strategy and the backend provider response contract are available.

## Backend documentation check

The live demo Swagger documents `POST /api/v1/user/send-bvn-otp` with an
11-digit `bvn`, and `POST /api/v1/user/verify-bvn-otp` with a six-digit numeric
`otp`. Their HTTP 200 entries contain descriptions only and define no response
schema. It does not document a provider-aware identity initiation response or
the proposed resume/capabilities operations. The development API documentation
URL returned 404 when checked.

## iOS packaging change — 2026-09-15

Implements Task 1 of
`docs/superpowers/plans/2026-09-15-dojah-android-sdk-ios-webview-handoff.md`.
The hybrid iOS failure above remains the historical record for native iOS
Dojah; it no longer applies to this configuration.

Toolchain: Flutter 3.44.6, Xcode 26.6, CocoaPods 1.16.2 (installed, unused).

### Changes

- `dojah_kyc_sdk_flutter` is registered for Android only. The Android plugin no
  longer logs the result Intent or raw payload (`BOCTRUST_PATCH.md`).
- Removed `ios/Podfile`, `Podfile.lock`, `DojahWidget.podspec`, the
  `ios/vendor/dojah-widget` submodule and `.gitmodules`. The Xcode project,
  workspace, and Flutter xcconfigs are restored to their pre-Dojah state (the
  Dojah commit only added CocoaPods wiring to them).
- Added `webview_flutter` ^4.14.1 (resolved `webview_flutter_wkwebview`
  3.26.1). It ships a SwiftPM `Package.swift`, supports inline media playback,
  and exposes camera/microphone permission requests, but does not pass the
  requesting origin to Dart. `permission_handler` was not added.
- `DojahCaptureScreen` launches native capture only on Android. On iOS it
  opens `https://identity.dojah.io/?widget_id=<widget>&reference_id=<backend
  reference>` in an embedded WebView (`dojah_webview.dart`), using the same
  backend reference the Android SDK receives. Other platforms show an
  unavailable message whose Close returns `cancelled`.
- Browser policy (`dojah_web_policy.dart`): main-frame navigation stays on
  HTTPS `dojah.io` hosts on the default port. Leaving Dojah (for example its
  configured confirmation redirect) is blocked and ends capture as `unknown`,
  which triggers the existing backend reconciliation. Other schemes,
  user-info URLs, and malformed URLs are blocked. Camera/microphone requests
  are granted only while the main frame is a trusted Dojah page. Back/Close
  returns `cancelled`; a main-frame load failure offers Close, returning
  `unknown`. Cookies, local storage, and cache are cleared when the browser is
  disposed. One guarded `_finish` closes the route, so duplicate events cannot
  pop twice.
- CI's iOS job no longer initializes submodules or runs `pod install`, and now
  fails if a Podfile, Pods, `.gitmodules`, or an iOS Dojah plugin registration
  returns.

### Checks run

- `flutter build ios --simulator --debug --dart-define-from-file=.env.stage`:
  passed, no Podfile or Pods generated. Embedded frameworks: `App`, `Flutter`,
  `Lottie`, `SmileIDSDK`, `objective_c`; no Dojah, Realm, Kingfisher, or
  GooglePlaces. `GeneratedPluginRegistrant.m` has no Dojah entry.
- `flutter build ios --release --no-codesign --dart-define-from-file=.env.stage`:
  passed (39.1MB).
- `flutter build apk --release --dart-define-from-file=.env.stage`: passed
  (128.2MB), including the edited Kotlin plugin.
- `dart format --output=none --set-exit-if-changed lib test`: no changes.
- `flutter analyze`: no issues.
- `flutter test --no-pub`: 943 tests passed after adding the WebView (policy
  and capture-screen tests included).
- `curl -L 'https://identity.dojah.io/?widget_id=test&reference_id=test'`:
  HTTP 200 HTML. This only shows the host serves the flow; it does not
  validate a widget or the `reference_id` behaviour.

### Cross-screen attempt overlap

Not reproducible through the UI, so no new guard was added. Identity and
document submission each use their notifier's `_inFlight` guard, both screens
return when unmounted after the initiation await (`kyc_screens.dart` after
`notifier.submit`), and each capture is a pushed full-screen route.

### Not verified

Physical-device runs, a clean-checkout CI run, and a real hosted Dojah
session remain unverified. `.env.stage` has empty `DOJAH_SELFIE_WIDGET_ID` and
`DOJAH_GOVERNMENT_WIDGET_ID`, so the app currently reports Dojah as not
configured before reaching either platform path. Open questions: whether
`reference_id` in the hosted URL correlates with the backend attempt and
webhook as intended (Dojah documents it as tying the session to your user),
the confirmation redirect and its status values, whether the flow requests
media from a third-party iframe, and the other section 1.1 plan questions. The
WebView has no initial-load stall warning or WebKit process-termination
handling yet.

## Correlation and result mapping from the Baobab review — 2026-09-15

Reviewed against Baobab's shipped Dojah integration
(`/Users/kenechukwu/Documents/Other/baobab`, commits `88ff536`, `4fa0439`,
`e4e0b74`).

### Changes

- **The backend reference no longer resumes a Dojah session.** The
  `dojah_kyc_sdk_flutter` documentation on pub.dev describes both `referenceId`
  and `email` as parameters that "initialize the SDK for an ongoing
  verification". In SDK 0.4.2, `referenceId` is passed to `SplashActivity` as
  the `reference_id` extra and sent to Dojah's API as a `reference_id` query
  parameter. Baobab reached the same conclusion and moved its reference to
  metadata (`e4e0b74`). Boctrust now sends the reference as
  `extra_user_data.metadata.reference` on Android and as
  `metadata[reference]` in the hosted URL on iOS, through one helper,
  `dojahAttemptMetadata`. Neither platform sends `referenceId`/`reference_id`.
- **The hosted URL matches Baobab's evidenced shape:**
  `https://identity.dojah.io/?widget_id=<widget>&metadata%5Breference%5D=<reference>&loading=async`,
  built with `Uri` encoding. `metadata[user_id]`, `user_data[email]`, and
  `gov_data[bvn]` are not sent: Boctrust has no confirmed user ID field and the
  plan keeps prefill off by default.
- **Native results use the SDK's own tokens.** `javap` on
  `sdk-kotlin-v0.4.2.aar` confirms the `DojahSdkKt` constants `approved`,
  `pending`, `failed`, and `closed`. `approved`/`pending` map to `submitted`
  (pending review), `failed` to `failed`, `closed` to `cancelled`, and anything
  else, including the plugin's substituted `Verification Completed`, to
  `unknown`. Previously every non-`closed` result was `unknown`.

### Not adopted from Baobab

- Its callback hosts (`baobab-web.enyata.com`, `jollofplus.admin.baobab.com`,
  `www.jollofplus.ng`) and its permissive callback rules (missing status as
  success, host-only legacy match). Boctrust still ends capture as `unknown` on
  any navigation out of Dojah until its own redirect is confirmed.
- `flutter_inappwebview`, `permission_handler`, unconditional geolocation and
  media grants, file access, and full navigation URL logging.

### Checks run

- `flutter analyze`: no issues.
- `dart format --output=none --set-exit-if-changed lib test`: no changes.
- `flutter test --no-pub`: 944 tests passed.

No Android or iOS build or device session was run for this change.

### Needs backend confirmation

The backend must reconcile Dojah webhooks by `metadata.reference` rather than
`reference_id`. This is Baobab's backend contract; confirm Boctrust's backend
uses the same field before live capture. Dojah's integration documentation also
lists location permission for its SDKs; `Info.plist` has no location usage
description, so a widget that asks for location will not get it in the iOS
WebView. Confirm the selfie and government-document widgets do not.

## Government document types — 2026-09-19

### Which documents Dojah offers is not a launch parameter

Checked against `dojah_kyc_sdk_flutter` and `sdk-kotlin` v0.4.2 (AAR extracted
from the Gradle cache, read with `javap`).

- The launch surface is `widget_id`, `reference_id`, `email` and
  `extra_user_data` only. `ExtraUserData` carries `userData`, `govData`,
  `govId`, `location`, `businessData`, `address` and `metadata`. None of them
  selects a document type: `GovId`'s fields (`national`, `passport`, `dl`,
  `voter`, `nin`, `others`) hold ID *numbers*.
- The document list the SDK shows on its `ID_OPTION` page comes from the
  widget `Config` it fetches for that `widget_id` — `passport`, `dl`, `voter`,
  `nin`, `national` and the rest as booleans (`AuthResponse.kt`). That config
  lives in the Dojah dashboard.
- `GovId.isAnyFilled()` and `GovId.getFirstIdTypeFilled()` exist but nothing in
  v0.4.2 calls them; a binary grep over the extracted classes finds references
  only inside `GovId.class`. Number prefill was therefore not adopted.
- The iOS hosted flow resolves the same widget config from `widget_id`.

So `DOJAH_GOVERNMENT_WIDGET_ID`'s dashboard configuration is the real gate on
which documents a user can capture. The app's selection is a record sent to
the backend, and the government-ID form now names the chosen document so the
user picks the same one when Dojah asks again.

### App change

`POST /users/me/kyc/government-id/initiate` requires both `documentType` and
`documentNumber`, each discovered by a rejected attempt:

| Request body | Response |
| --- | --- |
| `{"country": "NG"}` | 400 `VALIDATION_ERROR` — "documentType is required" |
| `{"documentType": "nin_slip", "country": "NG"}` | 400 `VALIDATION_ERROR` — "documentNumber is required" |

The published schema describes `documentNumber` as optional, so the
implementation is stricter than the contract. The page therefore keeps both
inputs: a document dropdown offering all four types, each shown by its label
and never by its wire key, and a required document-number field whose label,
hint and validation message name the chosen document. The form validates the
number locally rather than spending a round trip to rediscover the rule.

The provider's capture then asks for the document again from its own
configured list and is never told this choice, so the form names the chosen
document underneath the dropdown to keep the declared and captured documents
together. An attempt is bound to the document it was created for: choosing a
different one starts a new attempt rather than reopening the cached job.

`GovernmentIdDocumentType` stays for reading values back. The Smile
restriction moved out of the enum into
`GovernmentIdDocumentTypeCapability.isEnabledFor`, and a backend that answers
a document initiation with `smile_id` for a document Smile cannot verify now
ends the attempt through `governmentIdUnsupportedMessage` instead of
launching a job that must fail. That message points at support rather than
asking for a different document, because the user no longer chooses one.

The card's document label and the button's wording both come from
`GET /users/me/kyc/status`: a `pending` document step reads "Continue
verification", anything else "Start verification".

### Evidence from the development backend — 2026-09-19

Observed in app request logging against `user-dev-api.centurysoftware.dev`:

- `GET /users/me/kyc/status` returned `governmentId` as `{"status":
  "pending", "documentType": "nin_slip", "documentNumberLast4": "0008"}`. The
  backend therefore accepts and records a non-voter document; the earlier
  concern that only `voter_id` would be accepted is resolved for that type.
- `GET /users/me/tier` describes Tier 2 with a single requirement,
  `{"key": "government_id"}`, and one checklist entry, "Valid
  government-issued ID card". It publishes no document-type list, so nothing
  server-side could drive a document chooser.

### Needs confirmation before live capture

- The Dojah dashboard widget behind `DOJAH_GOVERNMENT_WIDGET_ID` must have
  every document the partner intends to accept enabled; the app cannot
  enable them and no longer names one.
- The backend must reconcile its webhook against the document the provider
  reports. The declared type is the user's intent, not evidence: Dojah lets
  them capture something else, and only the webhook knows which.
- Canonical `documentType` wire values remain an open P0 contract gap
  (`plans/2026-09-03-updated-user-service-api-endpoints-implementation-plan.md`,
  section 4). The field would be better optional, since no client can know
  the document before the provider collects it.

### Checks run

- `dart format --output=none --set-exit-if-changed lib test`: no changes.
- `flutter analyze`: no issues.
- `flutter test --no-pub`: 978 tests passed.

No Android or iOS build or device session was run for this change.

## Android moved to the hosted flow — 2026-09-19

### Why

A device run crashed the app during government-ID capture:

```
java.lang.Exception: No stepNumber
  at GovDataViewModel$logIdOptionEvents$1.invokeSuspend(GovDataViewModel.kt:1388)
  at DocTypeFragment.onViewCreated$lambda$13$lambda$11(DocTypeFragment.kt:133)
```

Read from the v0.4.2 AAR, the cause is the SDK's own step bookkeeping.
`DojahMainActivity` advances a persisted index on every destination change
with no bound against the page list:

```kotlin
val index = max(currentPageIndex ?: -1, -1)
setCurrentPageIndex(index + if (bundle?.getBoolean("skip-next-step") == true) 2 else 1)
```

and `VerificationViewModel.getCurrentPageName` resolves the step by that
index while discarding the page name it is given — the elvis makes both
branches return the same value:

```kotlin
val current = pagesFromPrefs?.getOrNull(prefManager.currentPageIndex)
return (if (current?.name == name) current else null) ?: current
```

`logIdOptionEvents` then throws on null. The widget publishes three pages
(`index`, `id-options`, `id`), and the log shows the index reaching 3:
`index` → 0, `id-options` → 1 (its events logged `stepNumber=1`), `id` → 2,
then a bounce back to `id-options` → 3. `getOrNull(3)` is null, and the
unhandled exception on the main thread kills the host process. Any backward
navigation on the document pages reaches this.

There is no fix to take: `dojah_kyc_sdk_flutter` 0.1.17 is the latest release
and is what this repo vendors, and `sdk-kotlin` v0.4.2 is the newest of the
repository's 30 tags. The 0.1.17 changelog claims "Resolved issue with gov't
ID selection page" — the same page. Neither SDK repository has an open issue
mentioning `stepNumber`.

### Changes

- `chooseDojahPlatformRoute` now returns `DojahPlatformRoute.webView` for
  Android as well as iOS. `nativeAndroid` is gone, and with it
  `DojahCaptureScreen`'s native launch path.
- Android WebView camera access needs the host app to hold runtime `CAMERA`;
  granting the page's own permission request is not enough, and the native
  SDK used to ask on our behalf. `dojah_camera_permission.dart` requests it
  before the browser is built, and capture shows a refusal message with
  Close (returning `cancelled`) when it is denied. iOS asks for nothing:
  WKWebView prompts from the `Info.plist` usage descriptions, which are
  already present.
- Added `permission_handler` ^12.0.3. `permission_handler_apple` 9.6.1 ships
  a `Package.swift`, so the iOS CocoaPods-free setup is unaffected.

### Still wired but unreachable

`dojah_gateway.dart` still defines `DojahGateway`, `NativeDojahGateway`,
`dojahNativeOutcome` and `dojahGatewayProvider`, and `pubspec.yaml` still
depends on the `dojah_kyc_sdk_flutter` plugin, so the crashing SDK still
ships in the APK even though nothing launches it. `dojahAttemptMetadata` and
`dojahBvnPrefill` in that file are still used by the hosted-URL builder and
must stay. Removing the native plugin (and its JitPack, Jetifier and CI
wiring) is a separate change.

### Checks run

- `dart format --output=none --set-exit-if-changed lib test`: no changes.
- `flutter analyze`: no issues.
- `flutter test --no-pub`: 987 tests passed.
- `flutter build apk --debug --dart-define-from-file=.env.stage`: passed.
- `flutter build ios --simulator --debug --dart-define-from-file=.env.stage`:
  passed; no `ios/Podfile` or `ios/Pods` generated.

No device session was run for this change, so the Android hosted flow and its
camera prompt remain unverified on hardware.

## The hosted flow's Email step — 2026-09-19

Identity capture began asking for an email address, which the native Android
SDK never did. Walked the staging selfie widget
(`DOJAH_SELFIE_WIDGET_ID`) in a browser to find out why.

### What it is

Two separate screens were involved, only one of which matters:

- `identity.dojah.io` opens with a device-handoff landing page — "Continue
  using this device", a QR code, and an email field offering to send a link
  to a phone. That email is optional, and the page is **skipped entirely on a
  mobile user agent**, so an in-app WebView never sees it.
- The flow itself has a required **Email step** (`KycPages.EMAIL`) right
  after the instructions page, with Continue disabled until it is filled.
  That is a configured step in the EasyOnboard flow, not something the launch
  URL causes. It is what users were hitting.

### Fix

Supplying `user_data[email]` makes Dojah skip the step: with it, the staging
flow went from its instructions page straight to the BVN page. Confirmed that
`user_data[email]` alone is sufficient — an additional top-level `email`
parameter is not needed.

`buildDojahIdentityUri` now takes an optional `email`, and
`_openDojahCapture` passes the address from `userProfileProvider`. The
profile is loaded during post-login bootstrap
(`post_login_bootstrap_provider.dart`) and the startup gate fails to
`profileError` when it cannot be, so the cached read is reliable without a
fallback fetch. A profile with no email simply omits the parameter and the
user is asked, as before.

The consent dialog shown before identity capture already tells the user their
contact information reaches the provider, so no new consent is needed: the
address is one they gave us, and Dojah would otherwise ask them for it again.

### Alternative not taken

The Email step could be removed from the EasyOnboard flow in the Dojah
dashboard instead. Prefilling was chosen because it needs no dashboard change
and keeps the step available for users whose profile has no address.

### Checks run

- `dart format --output=none --set-exit-if-changed lib test`: no changes.
- `flutter analyze`: no issues.
- `flutter test --no-pub`: 990 tests passed.

The browser walk-through used the staging widget in sandbox mode with
placeholder data; no real user data was entered and no verification was
completed.
