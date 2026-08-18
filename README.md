# BOCTrust Savings & Payments App

BOCTrust is a Flutter savings and payments application shell implementing the UX reference in `agent_assets/source.html` through a modular Flutter architecture.

## Run

```sh
flutter pub get
flutter run --dart-define-from-file=.env.stage
```

The staging configuration must define `ENV=staging`,
`BASE_URL=https://user-dev-api.centurysoftware.dev/api`, and an environment-
specific `SECURE_STORAGE_NAMESPACE`. `PAYSTACK_PUBLIC_KEY` is reserved for the
future card-funding integration. Copy `.env.example` for a new local setup;
environment files remain gitignored.

API traffic is printed through the `logger` package with structured request,
response, error, and duration details. Staging logs intentionally include raw
headers and payloads, including authentication values, and must only be
captured on controlled development devices. Production logs recursively redact
sensitive fields.

## Verify

```sh
flutter analyze
dart format --output=none --set-exit-if-changed lib
```

Automated tests are intentionally deferred while the UI prototype is being
stabilized. Pull requests currently enforce formatting and static analysis.

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
| Liveness, BVN, NIN, next of kin, utility bill upload | Submission endpoints and upload contracts | Tier data is read from the API; submission actions are clearly unavailable | Add typed submission endpoints when the backend publishes them. |
| Group Save invitations and schedules | Invitation, contribution schedule, roles, missed-payment endpoints | Group routes show blocked integration state where needed | Add typed models and service methods. |
| Card funding | Paystack/provider handoff and callback contract | Card funding route shell marked blocked | Wire WebView URL creation and callback parser. |
| Bills and scan-to-pay | Biller catalogue, customer lookup, payment, QR payload contracts | Payment routes render UI shell and blocked integration states | Add biller models, lookup service, and receipt mapping. |
| Beneficiaries and linked banks management | CRUD endpoint details | Account routes render blocked shell when unavailable | Replace shell with service-backed provider state. |

## UX parity checklist

- Home, Save, Send, Pay, and Account tabs are registered.
- Onboarding, verification, OTP, password, login, password reset, and new-device OTP routes are registered.
- Savings product routes cover Flex, Target, Lock, and Group actions including statement, settings, sort, details, add-to-lock, invite, contribute, and full-member list.
- Wallet funding routes cover Add Money, bank transfer, and card funding.
- Send routes cover own account, BOCTrust beneficiary, and other-bank transfers.
- Payments routes cover airtime, data, bill categories, bill pay, scan-to-pay, and recent transaction receipt drill-down route support.
- Account routes cover tiers, beneficiaries, linked banks, security, support, legal, social, theme, loans, cards, and notify-me actions.
- Notifications route supports grouping labels and deep-link helper parsing.
- Transaction authorization and success receipt routes are shared across money-moving flows.
