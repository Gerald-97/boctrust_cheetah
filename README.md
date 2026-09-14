# Cheetah Savings & Payments App

Cheetah is a Flutter savings and payments application shell implementing the UX reference in `agent_assets/source.html` through a modular Flutter architecture.

## Run

```sh
flutter pub get
flutter run --dart-define-from-file=.env.stage
```

The staging configuration must define `ENV=staging`,
`BASE_URL=https://user-dev-api.centurysoftware.dev/api`, and an environment-
specific `SECURE_STORAGE_NAMESPACE`. KYC builds also define
`DOJAH_SELFIE_WIDGET_ID` and `DOJAH_GOVERNMENT_WIDGET_ID` with the published
widget for each environment. `PAYSTACK_PUBLIC_KEY` is reserved for the future
card-funding integration. Copy `.env.example` for a new local setup;
environment files remain gitignored.

### iOS build setup

iOS native dependencies use Swift Package Manager through Flutter's generated
`FlutterGeneratedPluginSwiftPackage`. Dojah's Flutter package additionally
requires the checked-in CocoaPods configuration for DojahWidget and Realm. Use
Flutter 3.44.6 (Dart 3.12.2) with Xcode; the local migration toolchain is Xcode
26.6. The app supports iOS 15.0 and later.

```sh
git submodule update --init
flutter pub get
cd ios && pod install --deployment && cd ..
flutter build ios --simulator --debug
flutter run --dart-define-from-file=.env.stage
```

For Xcode development, open `ios/Runner.xcworkspace` and select the Runner
scheme. Run Flutter with the environment configuration first so Xcode inherits
the generated build settings. Keep the scheme's **Run Prepare Flutter
Framework Script** pre-action and Flutter build phases enabled.

Run `pod install --deployment` after `flutter pub get`. The checked-in Podfile
and Podfile.lock pin Dojah's CocoaPods dependencies, while the tracked SwiftPM
`Package.resolved` files control the remaining native dependency versions. Do
not add duplicate Firebase or Smile ID packages directly to Runner. Do not
commit `ios/Flutter/ephemeral`, `Generated.xcconfig`, or generated registrants.
CI checks a simulator Debug build and an unsigned device Release build;
physical-device plugin checks and distribution signing remain separate release
checks.

### KYC provider configuration

Dojah is launched only when the backend initiation response selects `dojah`.
The app supplies the backend-issued reference and the operation-specific widget
ID; it does not send the BVN or document number to the SDK. Provider completion
is reconciled against the backend status because the SDK return value is not a
verification verdict. Smile ID remains supported when the backend selects it or
returns the existing legacy Smile job context.

### Smile ID configuration

KYC capture needs `assets/json/smile_config.json`, the partner configuration
downloaded from the Smile ID portal. It is gitignored and must be injected into
the build workspace by each environment's secret-delivery process before
`flutter run` or `flutter build`; see `assets/json/README.md`. Without it the
app still builds, and the document-capture screen shows a retry state rather
than crashing.

Do not set `SMILE_ID_API_KEY`. It was removed: that key is the backend's
signature secret, and the mobile SDK takes its `auth_token` from the asset
config instead. Never pass it to `SmileID.initializeWithApiKey`.

### Logging

API traffic is printed through the `logger` package with structured request,
response, error, and duration details. Staging logs are intentionally
unredacted so testers can read server-returned OTPs, and must only be captured
on controlled development devices. Production logs recursively redact the
`_sensitiveKeyParts` set.

A narrower set is redacted in **every** environment, staging included, and does
not depend on that flag: `auth_token`, `partner_id`, the Smile config, the Smile
`callbackUrl` and its query, `accountNumber`, `identityNumber`,
`documentNumber`, and raw SDK result JSON. See `_alwaysRedactedKeyParts` in
`lib/app/interceptors.dart`. Do not move a value out of that set to make
debugging easier.

## Verify

```sh
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
```

`flutter analyze` is expected to report no issues.

### Physical-device testing

The Dojah and Smile ID capture flows use native camera views and cannot be
exercised by `flutter test` or a simulator. Before releasing a change to the KYC
journey, verify both providers on one physical Android and one physical iOS
device: initialization failure and retry, camera and microphone permission
denied and re-granted, selfie liveness, a successful Voter ID capture, user
cancellation, a native SDK error, submission acknowledgement, delayed and
failed webhooks, manual refresh, background/resume refresh, and logout cleanup.

Only `voter_id` is enabled. Smile's published matrix lists only Nigerian
`VOTER_ID` for Enhanced Document Verification, so each other document type
stays disabled until a sandbox submission succeeds for this partner on both
platforms and its webhook reaches `pending` or `success`.

## Architecture

- `lib/app/` contains app bootstrap, routing, navigation, theme, networking, interceptors, and service response primitives.
- `lib/helper/` contains cross-cutting secure storage and notification helpers.
- `lib/module/` contains vertical feature slices and shared UI components.
- `lib/utils/` contains validators, formatters, enums, form helpers, and formatting utilities.

## UI conventions

- Plus Jakarta Sans is the only application font and is applied by the root
  `ThemeData` for every route.
- System, light, and dark mode are owned by the Riverpod theme controller and
  persisted with `SharedPreferences`.
- Screens use semantic, mode-aware colors from the theme extension instead of
  hard-coded light surfaces.
- Brand artwork and remote images are deliberately represented by simple icon
  placeholders until final assets are supplied.
- Reusable cards, buttons, fields, spacing, and bottom navigation live in the
  shared component layer; feature screens should compose those primitives.

## Routing and authentication

The app starts at a session bootstrap route. It restores a valid namespaced
secure-storage session, loads the authenticated profile, and then routes to
first-PIN creation or Home. Expired and malformed sessions are cleared locally.
Signup, password recovery, new-device approval, logout, profile, tier, and
security-secret flows use the staging User API.

## Backend-contract blockers

The User API is wired for its documented mobile endpoints. Product areas with
no contract in that API remain explicitly unavailable.

| Area | Missing contract | Current behavior | Replacement steps |
|---|---|---|---|
| Firebase native setup | Staging Android and iOS Firebase application files | FCM initialization fails closed; login and the rest of bootstrap continue | Supply `google-services.json` and `GoogleService-Info.plist` for the staging Firebase project. |
| Tier 1 webhook | Whether the identity webhook processes a Biometric KYC (job 1) result | Capture works: consent, ID confirmation, selfie and liveness all submit to Smile. The verification then stays `pending` — `hasLivenessSelfie` does not flip and the tier does not move | Backend handles the job-1 callback, sets both identity flags, and upgrades Tier 1. See `plan/BACKEND_TIER1_BIOMETRIC_KYC_SERVER_PLAN.md` Task 4. |
| Resuming an interrupted government-ID job | 409 does not return the existing `smileUserId`, `smileJobId`, and `callbackUrl` | Capture reopens from the in-memory initiation. After a process restart nothing can reopen it, and the card says a verification is already in progress and offers Refresh | Backend returns the existing job context on 409. Pinned by a test in `test/kyc_government_id_flow_test.dart`. |
| Next of kin | Submission endpoint | Route states plainly that it is a later step | Add a typed submission endpoint. |
| Group Save invitations and schedules | Invitation, contribution schedule, roles, missed-payment endpoints | Group routes show blocked integration state where needed | Add typed models and service methods. |
| Card funding | Paystack/provider handoff and callback contract | Card funding route shell marked blocked | Wire WebView URL creation and callback parser. |
| Bills and scan-to-pay | Biller catalogue, customer lookup, payment, QR payload contracts | Payment routes render UI shell and blocked integration states | Add biller models, lookup service, and receipt mapping. |
| Beneficiaries | CRUD endpoint details | Account route renders a blocked shell | Replace shell with service-backed provider state. |
| Withdrawals | No transfer or payout operation is published | Withdrawal accounts can be listed, resolved, saved, and deleted, but no money movement is offered | Add the payout endpoint before building any withdrawal action. |

## UX parity checklist

- Home, Save, Send, Pay, and Account tabs are registered.
- Onboarding, verification, OTP, password, login, password reset, and new-device OTP routes are registered.
- Savings product routes cover Flex, Target, Lock, and Group actions including statement, settings, sort, details, add-to-lock, invite, contribute, and full-member list.
- Wallet funding routes cover Add Money, bank transfer, and card funding.
- Send routes cover own account, Cheetah beneficiary, and other-bank transfers.
- Payments routes cover airtime, data, bill categories, bill pay, scan-to-pay, and recent transaction receipt drill-down route support.
- Account routes cover tiers, beneficiaries, linked banks, security, support, legal, social, theme, loans, cards, and notify-me actions.
- Notifications route supports grouping labels and deep-link helper parsing.
- Transaction authorization and success receipt routes are shared across money-moving flows.
