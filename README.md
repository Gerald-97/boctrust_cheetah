# BOCTrust Savings & Payments App

BOCTrust is a Flutter savings and payments application shell implementing the UX reference in `agent_assets/source.html` through a modular Flutter architecture.

## Run

```sh
flutter pub get
flutter run --dart-define=ENV=dev --dart-define=BASE_URL=https://dev-api.boctrustmfb.com/api
```

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

## Prototype routing

The route table keeps design-spec deep links discoverable. Related routes may
currently resolve to the same prototype screen—for example, Flex Save actions
share the Flex screen and support routes share Account. These are explicit
aliases, not silently missing pages. Unknown routes use the app's dedicated
fallback route.

## Backend-contract blockers

The first implementation keeps production calls behind service boundaries and route shells where endpoint contracts are not confirmed.

| Area | Missing contract | Current behavior | Replacement steps |
|---|---|---|---|
| WhatsApp OTP | Delivery endpoint and response shape | Route shell only, mock-capable service boundary expected | Add endpoint to onboarding service and map provider state. |
| Liveness, NIN, next of kin, utility bill upload | Payload, upload, and status response contracts | KYC route shells marked as backend-blocked | Replace blocked service response with typed API calls. |
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
