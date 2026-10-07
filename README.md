# Cheetah Savings & Payments App

Cheetah is a Flutter savings and payments application shell implementing the UX reference in `agent_assets/source.html` through a modular Flutter architecture.

## Run

```sh
flutter pub get
flutter run --dart-define-from-file=.env.stage
```

The staging configuration must define `ENV=staging`,
`BASE_URL=https://user-dev-api.centurysoftware.dev/api`, and an environment-
specific `SECURE_STORAGE_NAMESPACE`. `SITE_URL=https://boctrustmfb.com`
provides the public privacy policy and terms shown in the app. KYC builds also define
`DOJAH_SELFIE_WIDGET_ID` and `DOJAH_GOVERNMENT_WIDGET_ID` with the published
widget for each environment. `PAYSTACK_PUBLIC_KEY` is reserved for the future
card-funding integration. Copy `.env.example` for a new local setup;
environment files remain gitignored.

`CORE_BASE_URL=https://core-dev-api.centurysoftware.dev/api` points at the
separate Core Service (accounts, products, transfers, bills) and follows the
same `/api` convention; the app appends `/v1`. It is optional: left blank, the
app boots, every User Service feature works, and every Core-backed capability
is unavailable. Core requests carry the signed-in User Service bearer token,
but a Core `401` never signs the customer out.

### iOS build setup

iOS native dependencies use Swift Package Manager only, through Flutter's
generated `FlutterGeneratedPluginSwiftPackage`; the project has no Podfile. The
repository-local Dojah plugin is registered for Android only, so iOS does not
link DojahWidget or Realm. On iOS, Dojah opens the hosted identity flow
(`https://identity.dojah.io/?widget_id=…&metadata[reference]=…&loading=async`)
in an embedded WebView. Use
Flutter 3.44.6 (Dart 3.12.2) with Xcode; the local migration toolchain is Xcode
26.6. The app supports iOS 15.0 and later.

```sh
flutter pub get
flutter build ios --simulator --debug
flutter run --dart-define-from-file=.env.stage
```

For Xcode development, open `ios/Runner.xcworkspace` and select the Runner
scheme. Run Flutter with the environment configuration first so Xcode inherits
the generated build settings. Keep the scheme's **Run Prepare Flutter
Framework Script** pre-action and Flutter build phases enabled.

The tracked SwiftPM `Package.resolved` files control native dependency
versions. Do not reintroduce CocoaPods or register the Dojah plugin for iOS;
CI fails if either returns. Do not add duplicate Firebase or Smile ID packages
directly to Runner. Do not
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

### Government-ID documents

The government-ID form is driven by two authenticated User Service reads,
cleared on logout, expiry, and user switching:

- `GET /users/me/kyc/government-id/document-types` is the catalogue. Only
  active rows this build knows are offered, in server order. A failed,
  malformed, or empty catalogue shows Retry; there is no hard-coded fallback.
- `GET /users/me/kyc/provider-config` filters that catalogue by what
  `governmentId.provider` can launch. A `staging` build accepts only a
  `sandbox` environment and a `prod` build only `live`; any mismatch blocks
  initiation.

`national_id` is shown as “NIN, National Identity Number” and stays distinct
from `nin_slip` (“NIN slip”). The document number field appears, and
`documentNumber` is sent, only when the selected row has
`requiresDocumentNumber: true`.

The provider returned by `POST /users/me/kyc/government-id/initiate` remains
authoritative for each attempt. Dojah is the default provider and accepts
every known document, including `national_id` (confirmed on the staging
government-ID widget on 2 October 2026). Smile is limited to `voter_id`:
its published matrix lists only Nigerian `VOTER_ID` for Enhanced Document
Verification, and `national_id` has no Smile mapping. Dojah widget IDs remain
environment inputs because the provider config does not publish them, and the
Dojah webhook is backend-only. Smile ID v12 token retrieval waits for the
backend to publish token expiry (`expiresAt` or `expiresInSeconds`).

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

### Savings integration

Savings and Flex share the authenticated Home aggregate (`GET /users/me/home`)
with Home. The screens display the returned wallet balance/status and validated
product names. Catalogue entries are product descriptions, not customer-owned
plans. Rates, minimum deposits, earnings and history remain hidden until their
contracts are defined.

Add money and bank-transfer routes show the user's current virtual-account
details. Entering funding refreshes the aggregate; Copy is enabled only after a
successful load with an available account, bank and account number. A failed
refresh keeps prior details visible with a warning and disables Copy. No client
action marks a transfer as completed.

Direct Savings routes restore authentication and require the current user's
profile and first transaction PIN. Home requests are shared while in flight and
discarded on session changes. Target, Fixed Deposit, Group, statements,
withdrawals, auto-save and card funding show unavailable states because this
User API does not publish those operations. Their URLs remain registered.

Focused checks: `flutter test test/savings_provider_test.dart
test/savings_product_data_test.dart test/savings_access_test.dart
test/savings_ui_test.dart test/savings_live_ui_test.dart`.
These use synthetic transport responses; authenticated staging-device
verification is a separate release check.

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
| Transfers, airtime, data, and bills | Core publishes the endpoints, but bank-list, name-enquiry, biller, category and payment-item responses have no attached schema; there is no transaction-bound authorization, idempotency rule, or success/status enum (see `docs/verification/core-banking-integration.md`) | Send and Pay hubs stay navigable, but every transfer, airtime, data, biller, authorization, and receipt route shows an unavailable state. No form, PIN, recipient, or receipt is shown | Add the transaction contract first; receipts may only render confirmed server data. `/auth/pin/verify-current` is not a substitute for transaction authorization. |
| Scan to pay | A payment contract of its own; Core name-enquiry response schema (see Transfers row) | Staging only. The account number and bank name are read from a photo on the device and the photo is deleted after use; nothing is uploaded. Continue stays disabled until Core name enquiry confirms the recipient. There is no payment step here: transfers go through the existing transfer screens, which remain unavailable until the transaction contract exists | Publish the transfer contract; no scan-specific payment endpoint is needed. |
| Transaction history and payment checkout | Transaction list and hosted-checkout contracts | `/transactions` and `/payment/webview` show unavailable states | Replace with service-backed state. |
| Beneficiaries | CRUD endpoint details | Account route shows an unavailable state with no sample recipients | Replace with service-backed provider state. |
| Notification history | Authenticated inbox, pagination, stable IDs, read state, validated deep links | Notifications route states history is unavailable. It neither lists activity nor claims the inbox is empty. Push delivery and deep-link parsing are unchanged | Add the inbox contract. |
| Loan and card launch subscriptions | Persisted subscription, consent/channel, unsubscribe | Loans and Cards say "Coming soon" and that launch notifications are not available; no subscription is offered | Add the subscription contract before offering a notify-me action. |
| Withdrawals | No transfer or payout operation is published | Withdrawal accounts can be listed, resolved, saved, and deleted, but no money movement is offered | Add the payout endpoint before building any withdrawal action. |

## UX parity checklist

- Home, Save, Send, Pay, and Account tabs are registered.
- Onboarding, verification, OTP, password, login, password reset, and new-device OTP routes are registered.
- Home, Savings and Flex render balances and the product catalogue from the Core Service; Add money keeps the User Service virtual account. Target, Lock, Group and unsupported Savings action routes show availability states.
- Scan to pay (staging only) reads an account number and bank name on the device and needs Core name enquiry before continuing; it has no payment contract and hands off to the transfer screens.
- Live: Add Money and bank-transfer funding (virtual-account details), linked withdrawal bank accounts (list, resolve, save, delete), KYC tiers, login, and PIN flows.
- Unavailable (routes registered, honest unavailable state): card funding, own-account/beneficiary/other-bank transfers, airtime, data, all biller categories, bill pay, transaction authorization, receipts (including `/transaction/receipt/demo`), transaction history, payment webview, and beneficiaries.
- There is no live transaction service and no notification-history service. No route fabricates a transaction, recipient, receipt, or notification.
- Loans and Cards (including the `notify-me` compatibility routes) show "Coming soon" without a subscription action.
- Notification deep links still parse; unknown routes fall back to Notifications.
- Linked-bank form: the visible bank and account number always match the draft that Check and Save use, across navigation, save, and delete.
