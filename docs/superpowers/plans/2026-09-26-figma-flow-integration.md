# Figma Flow Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter app into functional and visual alignment with the renewed Figma design under the BOCTRUST/BOC customer-facing brand, in this priority order: (1) completely missing flows and screens, (2) heavy modifications to current screens, (3) minor changes to current screens. A shared, normalised design system (Phase 0) is the prerequisite for all three.

**Design stance:** Figma is the source of *product intent, information hierarchy and brand character*, not a pixel specification. The file is not internally consistent (two fonts plus a third on one screen, three gold values, gold text on light backgrounds that fails contrast, mixed input styles, placeholder copy and typos). This plan normalises it into one coherent Material 3 mobile system: one token set, one type scale, 4-pt spacing, 48-dp touch targets, WCAG AA contrast in light and dark, and one component per pattern. Where the plan deliberately departs from Figma, the departure and its reason are recorded in the tables below so reviewers can tell a normalisation from a mistake.

**Architecture:** Preserve the existing Flutter/Riverpod structure. Screens and shared components are `part of 'app_flow/app_flow_navigator.dart'`; models, providers and services are separate libraries. Screens render, providers own async state, services own transport, `AppRouter` owns deep links. One local capability registry (`FeatureCapability`) is the only source of truth for whether a flow can submit. One private-route gate protects every signed-in route. A screen may render its full structure without a backend, but its final action is disabled or opens an availability sheet until the registry says the contract exists.

**Tech Stack:** Flutter, Material 3, Riverpod 3, Dio, `shared_preferences`, `file_picker`, `pin_code_fields`, `intl`, `flutter_test`.

**Design source:** Renewed [Figma file](https://www.figma.com/design/DKh0wTvp0BCVSnfUqcolXr/Untitled?node-id=0-1) (single page `0:1`). Node IDs below refer to that file.

## Decisions (confirmed 2026-09-26)

| Topic | Decision | Consequence |
| --- | --- | --- |
| Typeface | **Plus Jakarta Sans** for text; **FH Oscar** (`kFigureFontFamily`, `assets/font/FHOscarTest-*.otf`) for figures | Balances, amounts and limits use FH Oscar via `TextStyle.figures` or the `display*` text styles (tabular digits); everything else is Plus Jakarta Sans. Outfit is not shipped. `BocMoneyText` builds on `displayMedium` / `.figures`. |
| Bottom navigation | Keep **Home / Save / Send / Pay / Account** | Figma's Investment tab and "Coming soon" screen (`2:6028`) are not built. Only the nav bar's visual style is adopted. |
| API-less features in Figma | Build as **gated shells** | Face ID login, fingerprint for transfers, freeze account, request limit increase, change mobile, bills/airtime/data/QR are built under `FeatureCapability.unavailable`, with no network calls and no simulated results. |
| Dark mode | **Derive dark tokens** | Every semantic token gets a dark value built from the app's existing navy dark palette, checked for WCAG AA. |
| Delete-account eligibility | **Backend decides; balance must be zero** | The client never computes eligibility or shows a balance until the API supplies it. After the server confirms a zero balance, deletion requires the existing current-PIN verification (`/auth/pin/verify-current`) before the delete call is made (Task 4). |
| Security alerts | **Always on** | The notification-preferences row is shown but disabled, with an explanation (Task 5). |
| SVG assets | **Add `flutter_svg`** (approved 2026-09-26) | Figma vector art (wallet wave lines, tier badge, copy and eye icons) ships as SVG in `assets/svg/` and renders with `SvgPicture.asset`. SVG filters are not supported, so the tier badge's drop shadow is an offset copy of its shape. |

## Global Constraints

- Use BOCTRUST/BOC in all customer-visible copy (Figma and the current app still say "Cheetah" in several places; Task 16 lists every visible occurrence). Internal identifiers (`CheetahApp`, `CheetahTheme`, logger names, doc comments) are not renamed. Do not rename package identifiers, storage keys, route paths, API payloads or backend values just to change display copy. Route paths stay as they are (`/savings/target`, `/savings/lock`, `/savings/group`); only the labels become Boc SmartSave, Boc Fixed Deposit and Boc Padi.
- Screens use only `Theme.of(context)`, `context.bocColors` and the `Boc*` token classes. No new `Color(0x…)`, raw font sizes or magic paddings in screen files. Existing `k*` constants stay as compatibility aliases, and no new code uses them.
- Layout targets the 390-logical-pixel mobile canvas and keeps `ResponsiveContent` behaviour. Every screen must work at 320 px width and at 200% text scale without clipping a primary action.
- Every API-backed screen shows loading, empty, error and retry states from real provider data (reuse `ApiStateCard` / `ApiLoadingSection`).
- Never render sample balances, recipients, device lists, references, receipts, completion messages or account data as if they were live. Figma's sample content (₦1,248,530.75, "iPhone 15 Pro", "Ifeoma Nwachukwu", `BOC7734912X`, and so on) must not reach code.
- **Automated verification is limited to four safety tests plus `flutter analyze` (and `dart format`, matching CI).** The four tests guard capability derivation, the deep-link gate, delete-account re-authentication, and no success on a failed transfer. Tasks do not schedule runs of other existing tests; CI (`.github/workflows/flutter-quality.yml`) gates on format and analyze only, so a full `flutter test` run is not a release gate in this plan. Visual, layout, copy and happy-path behaviour are verified manually in the running app.
- Do not add a package unless an existing platform or API facility cannot satisfy the requirement. This plan adds only `flutter_svg` (approved for Figma vector assets). Receipt sharing (`share_plus`) and biometrics (`local_auth`) are explicit deferrals.
- `FeatureCapability` gates every flow without a live service contract. Screens never infer availability from route presence or hard-code their own availability rules. Existing ad-hoc availability handling is migrated onto the registry (Task 0).
- Any new provider that holds per-user state is cleared in `clearPrivateUserState` (`lib/app/private_user_state.dart`) in the same task that creates it.
- Every new route is added to `AppRoutes` and `allRoutes`, then mapped in `app_flow_screens.dart` to **either** a dedicated `AppScreen` (via `appScreenForRoute`, built in the `app_flow_navigator.dart` screen switch) for real flows, **or** an `AppPreviewRoute` (via `appPreviewRouteForRoute`) for generic, static or unavailable pages. Never both. Every signed-in route is also in `AppRoutes.privateRoutes` (Task 0b).

## Review Focus

- A deep link must not bypass sign-in, PIN setup, KYC or transaction authorisation.
- A server failure must not advance a flow to a success or receipt screen.
- A feature with no confirmed API capability stays hidden or is explicitly unavailable.
- Dark mode and 200% text scale keep AA contrast and never clip a primary action.
- Destructive actions (delete account, freeze account, early withdrawal/liquidation, remove device, remove bank) need an explicit, clearly labelled confirmation. The destructive button is never the visually dominant default.
- A logout followed by a sign-in as another user shows none of the first user's drafts, preferences or balances.

---

# Part A: Normalised design system

## A1. Colour tokens

The Figma variables were read from frames `2:5206`, `2:6069`, `2:5373`, `2:4040`, `2:6915`, `2:3042`, `2:5971`, `2:4815` and `2:9388`. "Normalised" means the value the app uses and why it differs.

### Brand

| Token (`BocColors`) | Figma source | Light | Dark | Use / rule |
| --- | --- | --- | --- | --- |
| `navy` | Text/Dark brand `#1A2A3C` | `#1A2A3C` | `#1A2A3C` (surfaces use `surfaceRaised`) | Primary button fill, wallet card, active nav. Replaces `#142B45`. `navy2` becomes `#22364D`. |
| `gold` | Text/Brand 2 `#E5C367` | `#E5C367` | `#E5C367` | Label colour **on navy only** (8.9:1), Flex card fill, selected segment fill (navy label). Never text on light surfaces (1.6:1 fails). |
| `goldStrong` | Secondary/5 `#CAA335`, app `#BF910C` | `#8A6A12` | `#E5C367` | The only gold allowed as **text/icon on light** (≥4.5:1 on paper). Replaces Figma's gold "See all"/"Cancel" labels. |
| `goldPale` | Secondary/1, Fade/6 `#F2E9CE` | `#F2E9CE` | `#3A2E10` | Chips, OTP idle border, tier tags. |
| `blue` | Button/Primary-back, Text/Brand `#4F7EB4` | `#4F7EB4` | `#8FB3DD` | Icons, large text, focus ring. |
| `blueStrong` | app `#3A6497` | `#3A6497` | `#A9C6E8` | Small link text ("Continue", "Go back and edit", "See all") at ≥4.5:1. Figma's `#4F7EB4` small text fails (3.9:1 on paper). |
| `bluePale` | Primary/1 `#DCE5F0` | `#E6EDF6` | `#1D3348` | Quick-action tiles, info fills. |

### Surfaces and text (`BocSemanticColors` — new fields)

| Field | Figma | Light | Dark | Notes |
| --- | --- | --- | --- | --- |
| `background` | Background/pri 1 `#F6F4EE` | `#F6F4EE` | `#101E30` | Scaffold. `Background/Main #FCFBF5` is dropped as a near-duplicate. |
| `surface` | Background/White | `#FFFFFF` | `#17293D` | Cards, grouped lists, fields, sheets. |
| `surfaceMuted` | Background/pri 2 `#FCFCFA` | `#FBFAF6` | `#1D3348` | Secondary button fill, keypad keys, unselected chips. |
| `border` | (implicit) | `#E7E2D6` | `#2A3D52` | Card hairlines, dividers, field idle border. |
| `textPrimary` | Text/Primary `#101924` (also `#0F1515`, `#0B0B25`) | `#101924` | `#ECEFF3` | One value; the Figma variants are unified. |
| `textSecondary` | Text/Secondary `#333C47` | `#333C47` | `#C3CCD6` | Body copy. |
| `textTertiary` | Text/Tertiary `#5C636C` | `#5C636C` | `#93A2B4` | Helper text, subtitles, inactive nav labels (5.6:1). |
| `textHint` | Text/Fade `#8995A2` | `#8995A2` | `#6F8196` | Placeholders and decorative captions **only**. Never helper or error text (3.1:1). |
| `textDisabled` | Text/Disabled `#D0D5DA` | `#A9B1BA` | `#4A5B6E` | Disabled labels (Figma value is too faint to read; raised). |
| `onNavy` / `onNavyMuted` | Text/White, Text/White-mini `#DCE5F0` | `#FFFFFF` / `#DCE5F0` | same | Text on the wallet card. |

### Status

| Field | Figma | Light fg / bg | Dark fg / bg | Rule |
| --- | --- | --- | --- | --- |
| `success` / `successContainer` | Success 1 `#30BE83` / Success 2 `#EAFBEF` | icon `#30BE83`, **text `#1E7F57`** / `#EAFBEF` | `#4FD39D` / `#123424` | Credit amounts and "Successful" use the text value (Figma green text is 2.4:1). |
| `error` / `errorContainer` | Error 1 `#D85D57` | icon `#D85D57`, **text `#B3403A`** / `#FDECEB` | `#F08A84` / `#3A1A1A` | Field errors, destructive labels. |
| `warning` / `warningContainer` | Caution/4 `#FFBB53` | icon `#E59A1F`, text `#8A5A00` / `#FFF7EC` | `#FFC874` / `#3A2A10` | "Pending…", weak-password meter. |
| `info` / `infoContainer` | Info 1 `#497CFC` | `#2F5FD0` / `#EAF0FF` | `#8AA8FF` / `#1A2548` | Info banners. |

### Product accents (one accent per savings product)

Figma paints every product with the same off-palette purple. Each product gets exactly one accent from the brand family, used for its icon tile, progress ring and chip:

| Product | Accent / container (light) | Dark container |
| --- | --- | --- |
| Boc Flex Savings | `gold` / `goldPale` | `#3A2E10` |
| Boc SmartSave | `blue` / `bluePale` | `#1D3348` |
| Boc Fixed Deposit | `purple #6E5A96` / `#EFEAF5` | `#2A2440` |
| Boc Padi | `success #30BE83` / `#EAFBEF` | `#123424` |

Transaction-type tints (history rows) reuse the status set: credit → success, debit → error, internal move → blue, interest → success, bonus → gold, pending → warning.

## A2. Typography (Plus Jakarta Sans)

Figma uses a `size/weight` naming (`14/2` = 14 Medium, `/3` = SemiBold, `/4` = Bold) with 100% line height. Line height is replaced with readable values, and every style scales with the system text size.

| `TextTheme` slot | Figma style | Size / weight / line height | Used for |
| --- | --- | --- | --- |
| `displaySmall` | 28/3 | 28 / 700 / 1.15, tabular figures | Wallet and savings balances |
| `headlineSmall` | 24/4 | 24 / 700 / 1.2 | Page hero titles ("Request Statement of Account") |
| `titleLarge` | 20/4 | 20 / 700 / 1.25 | Sheet titles, amounts on receipts |
| `titleMedium` | 16/4 | 16 / 700 / 1.3 | App-bar title, section headers, card titles |
| `titleSmall` | 14/3 | 14 / 600 / 1.35 | List-row titles, chip labels |
| `bodyLarge` | 16/2 | 16 / 500 / 1.45 | Field input text, paragraphs |
| `bodyMedium` | 14/2 | 14 / 500 / 1.45 | Body copy, sheet messages |
| `bodySmall` | 12/2 | 12 / 500 / 1.4 | Helper text, row subtitles, timestamps |
| `labelLarge` | 16/4 | 16 / 700 / 1.2 | Buttons |
| `labelMedium` | 12/3 | 12 / 600 / 1.3, letterSpacing 0.24 | Field labels, nav labels, tags |

Rules:
- **Money:** `BocMoneyText` renders amounts with `FontFeature.tabularFigures()`, a naira sign (FH Oscar has no ₦ glyph, so every figure style falls back to Plus Jakarta Sans via `kFigureFontFallback`), grouping, and kobo at 60% size (Figma "₦69,400.00"). Hidden balances render `₦ ••••••` with the same width. Figma's mono-style numerals are not reproduced.
- **Field labels:** sentence case at `labelMedium` ("Mobile number"), not Figma's uppercase. Uppercase at 12 px hurts readability and screen-reader pronunciation.
- Figma's 20 px Medium input text becomes `bodyLarge` 16. It stays legible and avoids clipping at large text scales.
- Effective text scale at the app root = `clamp(systemScale × preferenceMultiplier, 0.9, 2.0)`, where `preferenceMultiplier` comes from the Accessibility preference (Task 5; 1.0 by default).

## A3. Spacing, radii, elevation, motion (`lib/app/tokens.dart`)

```dart
abstract final class BocSpace {
  static const xxs = 4.0, xs = 8.0, sm = 12.0, md = 16.0, lg = 24.0, xl = 32.0, xxl = 48.0;
  static const gutter = md;          // page side padding (Figma 16)
  static const sectionGap = lg;      // between page sections
  static const cardPadding = md;
  static const minTouch = 48.0;      // Material minimum; Figma's 40px back button gets a 48 hit area
}

abstract final class BocRadius {
  static const xs = 8.0;   // OTP/PIN cells, small tags
  static const sm = 12.0;  // buttons, fields, keypad keys, segmented control
  static const md = 16.0;  // cards, wallet card, grouped lists
  static const lg = 24.0;  // bottom-sheet top corners
  static const pill = 999.0;
}

abstract final class BocMotion {
  static const fast = Duration(milliseconds: 150);   // toggles, chips
  static const normal = Duration(milliseconds: 250); // page, sheet
  static const curve = Curves.easeOutCubic;
}
```

- Cards sit flat on `background`, with no shadow and a 1 px `border` only in dark mode. This replaces `kBoxRadius = 18` with `BocRadius.md`.
- Only sheets and the bottom nav cast shadows (Figma nav: `0 -1 2 rgba(180,180,180,.1)`).
- Honour `MediaQuery.disableAnimations`: motion durations drop to zero.

## A4. Figma component → Flutter component map

"Extend" means modify the existing component in place, keeping its public API backwards compatible. "New" goes in the file named. All files are `part of app_flow_navigator.dart`.

| Figma component (node) | Flutter | Action | Spec (normalised) |
| --- | --- | --- | --- |
| Button "Next" dark (`2:7180`) | `PrimaryButton` (buttons.dart) | Extend | Height 56, radius `sm`, fill `navy`, label `gold` `labelLarge`. Loading state (`isLoading`) shows a 20 px spinner and keeps the width. Disabled: fill `navy` at 38%, label `textDisabled`. |
| Button "Next" light (`2:7180` var.) | `SecondaryButton` | Extend | Fill `surfaceMuted`, 1 px `border`, label `navy` (Figma's blue/gold labels on light fail contrast). |
| Gold filled "Close" (`2:9338`) | — | Drop | Collapses to `SecondaryButton`. Two filled styles side by side dilute hierarchy. |
| Text actions ("Go back and edit", "Continue") | `BocTextButton` (new, buttons.dart) | New | `blueStrong` `titleSmall`, 48 px min height. |
| Destructive actions ("Yes" in `2:2733`, "Delete account") | `DestructiveButton` (new, buttons.dart) | New | Fill `errorContainer`, label `error` text value, explicit verb label ("Withdraw and forfeit interest"), never "Yes". |
| Title bar (`2:8542`) | `BocAppBar` (new, flow_widgets.dart) used by `AppScaffold` | New + adopt | Height 56, `background` colour, centred `titleMedium`, leading 40 px white circular back button inside a 48 px hit area, optional trailing action (overflow ⋮ on plan detail). Hairline shadow once content scrolls under it. |
| Nav bar (`2:8196`) | `AppBottomNavigation` | Restyle only | Keep current 5 tabs. White surface, top shadow, 24 px icons (outlined inactive / filled active), `labelMedium`; active `navy` 700 weight, inactive `textTertiary`. 12 px top / 24 px bottom padding plus safe area. |
| Wallet card (`2:8345` "Main Wallet"; `SsdTjTt78rgm3GDS90HjbJ` `56:9476`) | `BalanceCard` + `BocTierBadge` (cards.dart) | Rebuilt | Flat navy `#1A2A3C`, radius `md`, min height 126, laid out on Figma's 358×126 frame. **Art layer** (scaled with the card via `FittedBox.cover`, excluded from semantics): `assets/svg/wallet_waves.svg` (6 white lines at 10%) at left −192 / top −179, flipped vertically and rotated −6.56°; a rounded highlight (166×99, radius 58.5, `#F4F4F9` at 5%) rotated −167.62° at bottom right; `assets/img/wallet_noise.png` tiled at 10%. Figma's "CHT" watermark is dropped. **Row 1:** "Wallet balance - " (`bodyMedium`, `onNavyMuted`) + account number (FH Oscar bold, white) + `copy.svg` button (48 hit, SnackBar "Account number copied"). The number is the confirmed funding account; it is omitted until the server confirms it. **Row 2:** `BocMoneyText` 28 SemiBold white with kobo at 60% + `eye.svg`/`eye_slash.svg` toggle; hidden state persisted and app-wide. **Row 3:** optional server note (e.g. interest earned today; omitted without data) and non-active wallet status, with `BocTierBadge` (scalloped `tier_badge.svg` + live tier number) and "Tier N" right-aligned. Ledger balance moves to the Flex screen. |
| Quick actions (`2:8566`, `2:8571`) | `QuickAction` (cards.dart) | Extend | 4-up row in a `surface` card. 48 px icon tile `bluePale`, radius `sm`, icon `navy`, label `titleSmall`. Whole column tappable, ≥48×72. |
| Tier callout (Home `2:5206`) | `TierCard` (kyc_widgets.dart) | Extend | Icon tile, "Tier N", limit rows (`LimitRow`), `SecondaryButton` "Complete KYC". Renders only from the tier provider. |
| Segmented control Phone/Email (`2:7845`) | `BocSegmentedControl<T>` (new, flow_widgets.dart) | New | Track `surface` 56 h radius `sm`, 4 px inset. Selected segment `gold` fill with `navy` label (Figma's white-on-gold fails). Semantics `selected`. |
| Text fields (`2:7881`, `2:8064`, `2:8421`) | `AppTextField`, `AppPasswordField`, `PhoneNumberInput` | Extend + unify | **One field style app-wide**: filled `surface`, radius `sm`, min height 56, 1 px `border` idle, 1.5 px `navy` focus, `error` border and message below. Label above in `labelMedium`; helper text `bodySmall` `textTertiary`. Figma's underline fields (auth/savings) and filled fields (statement/CAC) are merged into this single style. |
| Password strength (`2:8064` var.) | `PasswordStrengthComponent` | Restyle | 3 segments, 4 px, pill. Weak = warning, strong = success. The label uses status text colours. |
| OTP cells (`2:7914`) | `OtpBox` / `pin_code_fields` | Restyle | 6 cells 48×56, radius `xs`, idle border `goldPale`, active border `gold` 1.5, filled text `titleLarge`. Autofill (`AutofillHints.oneTimeCode`), paste support. |
| PIN entry + keypad (`2:4815`, `2:4588`) | `PinInputField`, `PinDots`, `MoneyKeypad` | Restyle | Summary card (amount + purpose) above 4 masked cells. Custom keypad 3×4 keys `surface`, radius `sm`, height 56, backspace with semantics label. The biometric link shows only when `FeatureCapability.biometricTransfers` is available (hidden now). |
| Toggle (`2:8535`) | Material `Switch` via `SwitchThemeData` | Theme | Active track `success`, thumb white. Inactive track `border`. Always paired with a text label in a `SettingsTile` (whole row toggles). |
| Settings rows (`2:9008`, Account `2:6069`, Security `2:7015`) | `SettingsGroup`, `SettingsTile` (list_tiles.dart) | Extend | Grouped `surface` card radius `md`. Rows ≥56 h, 24 px leading icon `navy`, title `titleSmall`, subtitle `bodySmall` `textTertiary`, trailing chevron **or** `Switch` **or** status tag. Group captions are left-aligned `labelMedium` (Figma centres them). |
| Transaction row (`2:8601`, history `2:7097`) | `TransactionTile` (list_tiles.dart) | Extend | 40 px rounded tile tinted by type, title ellipsised to one line, subtitle time plus optional status tag, amount right-aligned tabular. Credit `+` in success text colour; debit `−` in `textPrimary`. **The sign follows the API direction field**; Figma's "+₦50,000" withdrawal is a design error. |
| Section header + "See all" | `SectionHeader` | Extend | `titleMedium` + `BocTextButton` in `blueStrong` (not gold). |
| Bottom sheet (`2:2693`, `2:2733`, `2:2796`, `2:9338`) | `AppActionSheet` + new `AppConfirmSheet` (app_action_sheet.dart) | Extend | `surface`, top radius `lg`, drag handle 36×4, centred `titleLarge` + `bodyMedium` message. Actions **stacked** full width, primary first. Figma's floating "×" above the sheet is dropped (drag handle, Back and the scrim all close it). `AppConfirmSheet` returns `Future<bool>` and invokes nothing itself. |
| Summary tiles ("Confirm your new goal" `2:2796`) | `BocSummaryGrid` (new, flow_widgets.dart) | New | 2-column grid of label/value tiles (`surface`, radius `md`). It becomes one column when text scale is above 1.3. |
| Status screen ("Created" `2:4481`) | `BocStatusScreen` (new, flow_widgets.dart) | New | 64 px icon in a status container, `titleLarge` title, `bodyMedium` message, primary + text action pinned to the bottom. Variants: success / pending / failed. Only reachable from a server-confirmed result. |
| Receipt card (`2:4350`, `2:3042`) | `BocReceiptCard` (new, transaction_widgets.dart) + `ReceiptRow` | New | Ticket card with scalloped bottom edge (`CustomClipper`), success badge overlapping the top, amount `displaySmall`, status text, detail rows, reference with copy. "Share receipt" is gated (`receiptSharing` unavailable). |
| Chips (durations, frequency, days: `2:5373`, `2:5384`) | `FrequencySelector` → `BocChoiceChips<T>` (savings_widgets.dart) | Replace | Pill `ChoiceChip`s, min height 40 inside a 48 hit area. Unselected `surfaceMuted` + `border`; selected `navy` fill + `gold` label with check icon. Single- and multi-select modes. Wraps. |
| Product carousel ("Choose a plan" `2:5284`) | `ProductTile` (cards.dart) | Extend | 160×150 cards, horizontal list with 16 px peek. Product accent icon tile, `titleMedium`, 2-line `bodySmall`. |
| Flex card (`2:5284`) / Flex hero (`2:5320`) | `SavingsHeroCard` (savings_widgets.dart) | Extend | Product-accent gradient (gold→goldPale for Flex), rate pill, `BocMoneyText`, Add Money / Withdraw buttons (primary/secondary). |
| Info tiles (Deposits / Withdrawals… `2:5320`) | `GridViewInfo` | Restyle | 2-column `surface` tiles, label `bodySmall`, value `titleSmall`. |
| Target gauge (`2:5448`) | `BocProgressArc` (new, savings_widgets.dart) | New | Semicircle `CustomPainter`, track `successContainer`, progress product accent, start/target labels. Semantics "{pct}% of ₦{target}". |
| Tier list card (`2:6418`) | `TierCard` / `VerificationCard` | Restyle | Current-tier banner (`gold` fill, navy text), per-tier card with badge, requirement tags (`goldPale`), lock caption. |
| Upload field (`2:9050`, `2:9035`) | `DashedLikeUpload` (kyc_widgets.dart) | Restyle | Uses the unified field style ("Name of document" + "Choose file" in `blueStrong`). File name, size and type after picking; remove action. **Figma's CAC screen styling (Outfit, pink `#F70C9B`, purple `#5D5FEF`, lavender background) is discarded entirely.** |
| Device list sheet (`2:9338`) | `DeviceSessionTile` (new, flow_widgets.dart) | New | Title (device), subtitle (location · last active), "This device" tag. Rendered only from API data. |
| Text-size selector (`2:6161`) | `BocSegmentedControl<TextSizePreference>` | Reuse | Three options showing "Aa" at each scale, plus High contrast and Bold text `SettingsTile` switches. |
| Home banner ("Banner Ads") | — | Omit | No content source exists. Deferred. |

## A5. Copy normalisation (Figma → shipped copy)

| Figma | Ship |
| --- | --- |
| "Cheetah customer", "· Cheetah", "Cheetah" bank labels | BOCTRUST / "BOCTRUST MFB" (bank names come from API data) |
| "Go bak and edit" | "Go back and edit" |
| "Use ae Face ID or Fingerprint" | "Use Face ID or fingerprint" (hidden until capability exists) |
| "Move Moeny", "Notification Prefrences", "Request Limit Increse", "has ben received" | "Move money", "Notification preferences", "Request limit increase", "has been received" |
| Placeholder "e.g Phone" on Padi name/members | "e.g. Office rent circle" / "e.g. 6" |
| Security: "Device management — Use face recognition to sign in" | "Device management — See where you're signed in" |
| Security: "Fingerprint for transfers — …to sign in" | "Fingerprint for transfers — Approve transfers with your fingerprint" |
| Liquidate sheet "No, Cancel" / "Yes" | "Keep saving" (primary) / "Withdraw and forfeit interest" (destructive) |
| "Coming Soon!!" | "Coming soon" |

---

# Part B: Implementation

## Delivery order

| Phase | Priority tier | Outcome |
| --- | --- | --- |
| 0 | Foundation (prerequisite) | Capability registry, private-route gate, tokens, themed components |
| 1 | **Completely missing flows/screens** | Document KYC; Security Center additions (devices, freeze, biometrics, change mobile); delete account; statement request; notification + accessibility preferences; limit-increase entry; savings plan management; transaction details |
| 2 | **Heavy modifications** | Home; Save hub + Flex; SmartSave / Fixed / Padi creation; Send hub, PIN authorisation, result + receipt; transaction history; Payments hub; Account hub; Account tiers |
| 3 | **Minor changes** | Splash, onboarding, sign-up/in, password reset, OTP, PIN setup, basic KYC steps, linked banks, beneficiaries, support/legal, theme, profile, visible brand copy |

## File structure

| Path | Responsibility |
| --- | --- |
| `lib/app/colors.dart` | Figma-normalised `BocColors`, expanded `BocSemanticColors` (light + derived dark); `k*` aliases retained |
| `lib/app/tokens.dart` (new) | `BocSpace`, `BocRadius`, `BocMotion` |
| `lib/app/theme.dart` | Text theme (A2), component themes (buttons, inputs, switch, chips, sheets, nav, snackbar), text-scale clamp |
| `lib/app/feature_capability.dart` (new) | `FeatureCapability`, `FeatureAvailability`, requirement table, `featureAvailabilityProvider` |
| `lib/app/app_router.dart` | New routes, `privateRoutes`; remove `receiptDemo` |
| `lib/module/component/private_route_gate.dart` (new, part) | Generalised `SavingsAccessGate` for all private routes |
| `lib/module/component/flow_widgets.dart` (new, part) | `BocAppBar`, `BocSegmentedControl`, `BocSummaryGrid`, `BocStatusScreen`, `BocUnavailableSheet`, `DeviceSessionTile`, `BocMoneyText` |
| `lib/module/component/transaction_widgets.dart` (new, part) | `BocReceiptCard`, `TransactionDetailRows`, `SourcePickerSheet`, `BeneficiaryTile` |
| `lib/module/account/model/account_preferences.dart` | `NotificationPreferences`, `AccessibilityPreferences`, `TextSizePreference` |
| `lib/module/account/provider/account_preferences_provider.dart` | Persisted preferences (per signed-in user key) |
| `lib/module/account/screens/account_control_screens.dart` (new, part) | Security Center additions, devices, delete account, statement request, preferences, accessibility, notification preferences, limit increase, change mobile |
| `lib/module/kyc/model/document_verification_models.dart` | CAC / bank-statement types and status |
| `lib/module/kyc/provider/document_verification_provider.dart` | Document verification state |
| `lib/module/kyc/screens/document_verification_screens.dart` (new, part) | Requirements → pick → submitted/pending |
| `lib/module/savings/model/savings_plan_models.dart` | Product, plan draft, schedule, funding source, plan status |
| `lib/module/savings/provider/savings_plan_provider.dart` | Plan workflow state |
| `lib/module/savings/screens/savings_plan_screens.dart` (new, part) | Creation wizards, plan detail, edit, liquidate, top-up |
| `lib/module/send/model/transaction_models.dart` | Draft, status, recipient, receipt |
| `lib/module/send/provider/transaction_provider.dart` | Draft + confirmation state; approved endpoints only |
| `lib/module/send/screens/transaction_flow_screens.dart` (new, part) | Beneficiary, amount, review, PIN, result, receipt, history detail |
| `test/feature_capability_test.dart` | Unavailable unless every required endpoint exists (Task 0) |
| `test/private_route_gate_test.dart` | Signed-out deep link cannot build a private screen (Task 0b) |
| `test/account_controls_test.dart` | Delete account is sent only after current-PIN verification succeeds (Task 4) |
| `test/transaction_flow_test.dart` | A failed transfer never shows success or a reference (Task 11) |

Commit at the end of every task (`git commit` with a conventional message, e.g. `feat(design): …`).

---

## Phase 0 — Foundation

### Task 0: Capability registry derived from declared requirements

**Files:** Create `lib/app/feature_capability.dart`, `test/feature_capability_test.dart`. Modify `lib/module/send/screens/send_screens.dart`, `lib/module/payments/screens/payments_screens.dart`, `lib/module/account/screens/account_screens.dart`, `lib/app/app_router.dart`, `lib/module/app_flow/app_flow_screens.dart`.

**Produces:**

```dart
typedef ApiOperation = ({String method, String path});

enum FeatureAvailability { available, comingSoon, unavailable }

enum FeatureCapability {
  // live today: read-only displays
  flexSavingsView, savingsCatalogueView, linkedBanksView,
  // live today: mutations with an existing endpoint + model + service + provider
  linkedBanksManage, kycIdentity, kycGovernmentId, kycUtilityBill,
  passwordPinControls,
  // device-only
  notificationPreferences, accessibilityPreferences,
  // mutations without contracts (one capability per action)
  flexTopUp, flexWithdraw, flexStatement, flexAutoSave,
  smartSaveCreate, fixedDepositCreate, padiCreate, padiJoin,
  savingsPlansView, savingsPlanDeposit, savingsPlanEdit, savingsPlanWithdraw,
  kycCacDocument, kycBankStatement, deviceSessions, accountDeletion,
  accountStatement, freezeAccount, biometricLogin, biometricTransfers,
  limitIncrease, changeMobile,
  walletFunding, cardFunding, transfers, beneficiaries, transactionHistory,
  transactionReceipts, receiptSharing, airtime, data, bills, scanToPay,
  // product not launched
  loans, cards,
}

/// Read-only displays and mutations are separate capabilities: a screen may be
/// viewable (e.g. Flex balance from GET /users/me/home) while every action on it
/// (top-up, withdraw, statement) stays unavailable until its own contract exists.
class CapabilityRequirement {
  const CapabilityRequirement({this.operations = const {}, this.localOnly = false, this.comingSoon = false});
  /// Every endpoint the action needs. Only listed once the endpoint, typed
  /// request/response models, service method and provider mapping all exist.
  final Set<ApiOperation> operations;
  final bool localOnly;               // device-only feature, no API
  final bool comingSoon;              // product not launched
}

const capabilityRequirements = <FeatureCapability, CapabilityRequirement>{
  FeatureCapability.flexSavingsView: CapabilityRequirement(operations: {(method: 'GET', path: ApiEndpoints.ownHome)}),
  FeatureCapability.savingsCatalogueView: CapabilityRequirement(operations: {(method: 'GET', path: ApiEndpoints.ownHome)}),
  FeatureCapability.linkedBanksView: CapabilityRequirement(operations: {(method: 'GET', path: ApiEndpoints.withdrawalBankAccounts)}),
  FeatureCapability.linkedBanksManage: CapabilityRequirement(operations: {/* resolve, POST, DELETE — as used by withdrawal_bank_service.dart */}),
  // kycIdentity / kycGovernmentId / kycUtilityBill / passwordPinControls: their existing endpoints
  FeatureCapability.notificationPreferences: CapabilityRequirement(localOnly: true),
  FeatureCapability.accessibilityPreferences: CapabilityRequirement(localOnly: true),
  FeatureCapability.loans: CapabilityRequirement(comingSoon: true),
  FeatureCapability.cards: CapabilityRequirement(comingSoon: true),
  // every other capability: const CapabilityRequirement()  → unavailable
};

FeatureAvailability availabilityOf(FeatureCapability c);   // comingSoon > localOnly/operations.isNotEmpty ? available : unavailable
final featureAvailabilityProvider = Provider.family<FeatureAvailability, FeatureCapability>(…);
```

- [ ] Write the failing test (one case): the set of `available` capabilities equals exactly `{flexSavingsView, savingsCatalogueView, linkedBanksView, linkedBanksManage, kycIdentity, kycGovernmentId, kycUtilityBill, passwordPinControls, notificationPreferences, accessibilityPreferences}`. In particular `flexTopUp`, `flexWithdraw` and every savings-plan mutation are `unavailable`; any capability switched on without a declared requirement fails this test.
- [ ] Run `flutter test test/feature_capability_test.dart` → fails (missing symbols).
- [ ] Implement. No network, no fallback to `available`, map is `const`.
- [ ] Migrate existing ad-hoc availability: the send/payments unavailable screens and the loans/cards coming-soon routes read `featureAvailabilityProvider`. Remove the `receiptDemo` route from `AppRoutes`, `allRoutes` and `app_flow_screens.dart`. Delete `DemoToggle` from `forms.dart` if unused after Phase 1, or replace its usages with `Switch`.
- [ ] Run `flutter test test/feature_capability_test.dart` and `flutter analyze`.
- [ ] Commit.

### Task 0b: Private-route gate for every signed-in route

**Files:** Create `lib/module/component/private_route_gate.dart` (part of `app_flow_navigator.dart`), `test/private_route_gate_test.dart`. Modify `lib/app/app_router.dart`, `lib/module/app_flow/app_flow_navigator.dart` (part line only).

**Produces:** `AppRoutes.publicRoutes` (bootstrap, onboarding/*, login/*, password reset, new-device OTP) and `AppRoutes.privateRoutes = allRoutes.difference(publicRoutes)`. `PrivateRouteGate({required String routeName, required Widget child})` hydrates the session, then requires a profile and a PIN, using the same checks as `SavingsAccessGate`.

**Insertion point:** in `AppRouter._pageFor`, when `settings.name` is in `privateRoutes`, wrap the `AppFlowRouteScreen` in `PrivateRouteGate(routeName: settings.name!, child: AppFlowRouteScreen(...))`. The gate decides from the **original route name**, not from the navigator's current `_screen` (which changes during in-flow navigation). Redirects use the named routes `AppRoutes.login` or `AppRoutes.createFirstPin` via `pushReplacementNamed`. The child is not built until the checks pass. The existing `SavingsAccessGate` inside the navigator stays as it is, because it covers in-flow navigation to savings screens.

- [ ] Write a failing widget test (one case): deep-link to `AppRoutes.tierOverview` with no session; expect redirect to login and no private widget built.
- [ ] Run → fails (non-savings routes are ungated today).
- [ ] Implement the gate and the `_pageFor` wrapper.
- [ ] Run `flutter test test/private_route_gate_test.dart` and `flutter analyze`.
- [ ] Commit.

### Task 1: Tokens and theme

**Files:** Modify `lib/app/colors.dart`, `lib/app/theme.dart`. Create `lib/app/tokens.dart`.

- [ ] Implement A1 (new `BocColors` values; `BocSemanticColors` gains `background, surface, surfaceMuted, border, textPrimary, textSecondary, textTertiary, textHint, textDisabled, onNavy, onNavyMuted, success, successText, successContainer, error, errorText, errorContainer, warning, warningText, warningContainer, info, infoContainer, goldStrong, blueStrong` plus product accents; `copyWith`/`lerp` updated). Keep existing fields and `k*` aliases, pointing them at the new values.
- [ ] Implement A2 text theme, A3 tokens, and component themes in `theme.dart`: `FilledButtonThemeData`, `OutlinedButtonThemeData`, `TextButtonThemeData`, `InputDecorationTheme` (unified field), `SwitchThemeData`, `ChipThemeData`, `BottomSheetThemeData` (top radius `lg`, drag handle), `SnackBarThemeData`, `NavigationBarThemeData`, and the root `MediaQuery` text-scale clamp.
- [ ] Check the A1 text/background pairs in a contrast checker (≥4.5:1 light and dark) and adjust any value that fails before moving on.
- [ ] Run `flutter analyze`.
- [ ] Commit.

### Task 2: Shared components

**Files:** Create `lib/module/component/flow_widgets.dart` and `lib/module/component/transaction_widgets.dart` (add `part` lines in `app_flow_navigator.dart`). Modify `buttons.dart`, `cards.dart`, `list_tiles.dart`, `forms.dart`, `text_fields.dart`, `app_action_sheet.dart`, `savings_widgets.dart`, `kyc_widgets.dart`, `money_widgets.dart`, `app_scaffold.dart`.

Implement every "New", "Extend" and "Restyle" row of A4. Public constructors of existing components stay source-compatible; new behaviour is opt-in via named parameters.

- [ ] Implement the components. Then swap `AppScaffold`'s app bar for `BocAppBar` and restyle `AppBottomNavigation` (same 5 tabs).
- [ ] Run `flutter analyze`.
- [ ] Run the app (`/run`) and check Home, Save and Account in light and dark, at 320 px and the largest system text: no overflow, no clipped actions, ≥48 px tap targets.
- [ ] Commit.

---

## Phase 1 — Completely missing flows and screens

Each new route: register it in the three places, add it to `privateRoutes`, and gate its submit with `FeatureCapability`. An unavailable CTA opens `BocUnavailableSheet` ("This isn't available yet. We'll switch it on in the app as soon as it's ready.") instead of a disabled button with no explanation.

### Task 3: Document KYC — CAC certificate and bank statement

**Figma:** `2:9050` (CAC), `2:9035` (bank statement). Restyled per A4 "Upload field".
**Files:** Create `lib/module/kyc/model/document_verification_models.dart`, `lib/module/kyc/provider/document_verification_provider.dart`, `lib/module/kyc/screens/document_verification_screens.dart` (part). Modify `app_router.dart` (`/account/tier/cac`, `/account/tier/bank-statement`), `app_flow_screens.dart`, `app_flow_navigator.dart`, `kyc_screens.dart` (entry from tiers), `private_user_state.dart`.

**Produces:** `DocumentVerificationType { cac, bankStatement }`; `DocumentVerificationStatus { unsupported, draft, uploading, submitted, approved, rejected }`; provider modelled on `utilityBillUploadProvider`'s initiate → upload → complete shape, so wiring the API later only adds a service.

Screen: `BocAppBar("KYC verification")` → `headlineSmall` title ("Upload your CAC certificate") → `bodyMedium` explanation → upload field (PDF only, ≤10 MB, validated client-side with an inline error) → pinned `PrimaryButton("Upload document")`. File selection and its validation are presentation-only and may work while the capability is unavailable. The submit action opens the unavailable sheet while `kycCacDocument`/`kycBankStatement` is unavailable; nothing is sent and no status is shown. `BocStatusScreen.pending("Document received", …)` is reachable only from the provider state that follows a server-confirmed submission, and that state cannot exist until the capability is available.

- [ ] Implement; bank statement reuses the same widgets via `DocumentVerificationType`. Register the provider in `clearPrivateUserState`.
- [ ] Run `flutter analyze`, then open both routes in the app and confirm the CTA opens the unavailable sheet. Commit.

### Task 4: Security Center additions, devices, delete account, statement request, limit increase, change mobile

**Figma:** Security Center `2:7015`; devices sheet `2:9338`; delete account `2:2693`, `2:2701`, `2:4580`; statement request `2:7150`; change mobile `2:9324`; Account row "Request limit increase" (`2:6069`).
**Files:** Create `lib/module/account/screens/account_control_screens.dart` (part), `test/account_controls_test.dart`. Modify `app_router.dart`, `app_flow_screens.dart`, `app_flow_navigator.dart`, `account_screens.dart` (entry rows only).

Security Center (extends the existing `/account/security` screen, keeping password and PIN change behaviour):

| Row | Control | Capability | Behaviour now |
| --- | --- | --- | --- |
| Face ID login | Switch | `biometricLogin` | Row visible and disabled, with a "Not available yet" tag |
| Fingerprint for transfers | Switch | `biometricTransfers` | Same |
| Password | Chevron | `passwordPinControls` | Existing flow |
| Transaction PIN | Chevron | `passwordPinControls` | Existing flow |
| Device management | Chevron → sheet | `deviceSessions` | Sheet shows the unavailable state; no list is rendered |
| Freeze account | Switch → `AppConfirmSheet` | `freezeAccount` | Disabled with tag; when available, turning on requires confirmation ("Freeze account" destructive) |
| Change mobile number | Chevron | `changeMobile` | Unavailable sheet |

Delete account (`/account/delete`): an explanation screen, then a confirmation sheet. Eligibility (balance must be zero) comes **only** from an API. Until then the CTA opens the unavailable sheet, and no balance is shown. When available, the sheet shows the API-supplied balance with "Move money out" (primary) and "Cancel". When the server confirms a zero balance it shows "Delete account" (`DestructiveButton`). Tapping it opens the existing current-PIN verification (`verifyCurrentPinProvider` → `/auth/pin/verify-current`), and the delete request is sent only after that verification succeeds. A failed or cancelled PIN verification sends nothing.

Statement request (`/account/statement`): From/To date pickers (`showDateRangePicker`, max range 12 months, not in the future) and `PrimaryButton("Request statement")`, gated by `accountStatement`. Success copy only after a server confirmation.

Limit increase: an Account row opening the unavailable sheet (no screen until a contract exists).

- [ ] Failing widget test (one case). With `accountDeletion` overridden to available and a fake server eligibility of zero balance, tapping "Delete account" does not call the injected delete action. A failed fake PIN verification still does not call it. A successful one calls it exactly once.
- [ ] Run → fails. Implement.
- [ ] Run `flutter test test/account_controls_test.dart` and `flutter analyze`. Commit.

### Task 5: Preferences — notifications, accessibility, preferences hub

**Figma:** Preferences `2:6194`, Notification preferences `2:6122`/`2:6131`, Accessibility `2:6161`, theme `2:6903`/`2:6915`.
**Files:** Create `lib/module/account/model/account_preferences.dart`, `lib/module/account/provider/account_preferences_provider.dart`. Modify `lib/app/preferences.dart` (keys), `lib/app/app.dart` (apply text scale / bold / high contrast), `account_control_screens.dart`, `private_user_state.dart`.

- Keys: `boctrust.prefs.<userId>.notifications`, `boctrust.prefs.<userId>.accessibility` (per user). The theme choice stays device-wide as today.
- Accessibility: text size Small/Medium/Large sets `preferenceMultiplier` to 0.9/1.0/1.15, applied once as `clamp(systemScale × preferenceMultiplier, 0.9, 2.0)`; Bold text → `MediaQuery.boldText`; High contrast → switches `textTertiary`/`textHint` to `textSecondary` and borders to 2 px (a `highContrast` variant of `BocSemanticColors`).
- Notifications: toggles for transactions, savings reminders, security alerts (always on and disabled, with an explanation) and marketing. Stored locally only; the copy says "on this device" until an API syncs them.

- [ ] Implement. Run `flutter analyze`, then in the app set Large + Bold, restart, confirm they persist, log out and confirm they reset. Commit.

### Task 6: Savings plan management (detail, edit, top-up, withdraw/liquidate)

**Figma:** plan detail "My Rent" `2:5448`/`2:5474`, overflow "More" `2:3092`, Edit plan `2:5410`/`2:5420`, interest sheets `2:2709`–`2:2757`, liquidate `2:2733`, fund from `2:2845`/`2:2888`, withdraw to `2:2908`/`2:2928`, top-up `2:5688`, "Money added" `2:4449`.
**Files:** Create `lib/module/savings/model/savings_plan_models.dart`, `lib/module/savings/provider/savings_plan_provider.dart`, `lib/module/savings/screens/savings_plan_screens.dart` (part). Modify `savings_screens.dart` (routing into detail), `private_user_state.dart`.

Detail screen: `BocAppBar(planName, trailing: ⋮)` → balance `BocMoneyText` + rate caption with an info icon (opens the interest sheet) → `BocProgressArc` → transactions (`TransactionTile`, "See all") → pinned `PrimaryButton("Deposit")`. The screen is shown under `savingsPlansView`. Deposit, Edit plan and Withdraw are gated by `savingsPlanDeposit`, `savingsPlanEdit` and `savingsPlanWithdraw`; the ⋮ menu offers Edit plan and Withdraw. Withdraw before maturity uses `AppConfirmSheet` with the A5 liquidation copy and a `DestructiveButton`. Every value is rendered from the plan provider; with no plan data it shows `ApiStateCard`.

- [ ] Implement. Run `flutter analyze`. Commit.

### Task 7: Transaction details and statement entry

**Figma:** Transaction Details 1–4 `2:7141`–`2:7150`.
**Files:** Create `lib/module/send/model/transaction_models.dart`, `lib/module/send/provider/transaction_provider.dart`, `lib/module/send/screens/transaction_flow_screens.dart` (part), `lib/module/component/transaction_widgets.dart` (receipt/detail widgets). Modify `app_router.dart` (`/transactions/detail`), `private_user_state.dart`.

**Produces:** `TransactionDirection { credit, debit, internal }`, `TransactionStatus { pending, successful, failed, reversed }`, `TransactionRecord`, `TransactionReceipt` (constructible only from a parsed server response via `TransactionReceipt.fromJson`); the detail screen reuses `BocReceiptCard`.

- [ ] Implement. `BocReceiptCard` takes a `TransactionReceipt` (success only) and has no constructor that accepts free-form status text. Run `flutter analyze`. Commit.

---

## Phase 2 — Heavy modifications to current screens

### Task 8: Home

**Figma:** `2:5206`, `2:5248`. **Files:** `home_screen.dart`, `cards.dart`, `kyc_widgets.dart`.

Order: greeting row ("Hi, {firstName}" `titleMedium` + masked phone `bodySmall`, notification bell with unread dot from the notifications provider) → `BalanceCard` → quick actions (Add money, Send, Save, Pay) → `TierCard` (only when tier < max) → savings highlight (only with plan data) → recent activity (only when history is available; otherwise omitted, not faked). Figma's "Banner Ads" and "Cheetah customer" cards are omitted. Pull-to-refresh reloads home, tier and profile.

- [ ] Implement the recomposition. Run `flutter analyze`. Commit.

### Task 9: Save hub and Flex Savings

**Figma:** Save `2:5284` (new) versus `2:5818` (old), Flex `2:5320`, `2:5545`, Add money `2:5607`, Withdraw `2:5724`, Interest `2:2749`.
**Files:** `savings_screens.dart`, `savings_widgets.dart`, `cards.dart`.

Save hub: "Total savings" + eye → Flex card (gold accent) → "Choose a plan" product carousel (SmartSave, Fixed, Padi; each opens its intro or create, or the unavailable sheet) → "Your plans" (only with data). Flex: displayed under `flexSavingsView`; hero card with a rate pill and Add money/Withdraw (gated by `flexTopUp`/`flexWithdraw`, so both open the unavailable sheet today) → interest-rate row (opens the sheet) → 2×2 info tiles (only API-supplied fields; a missing field hides its tile) → interest history.

- [ ] Implement. Run `flutter analyze`. Commit.

### Task 10: SmartSave, Fixed Deposit and Padi creation

**Figma:** SmartSave create `2:5373`/`2:5500`, day of week `2:2764`/`2:2779`, fund from `2:2845`, confirm `2:2796`/`2:2819`, created `2:4481`; Fixed intro `2:9276`; Padi create `2:5384`, created `2:4502`, invite/members (existing `groupInvite`/`groupMembers` routes are **restyled and reused**, not duplicated).
**Files:** `savings_plan_screens.dart`, `savings_screens.dart`, `savings_widgets.dart`.

One wizard component with product-specific steps. The final submit is gated by `smartSaveCreate`, `fixedDepositCreate` or `padiCreate`. Normalisations:
- A progress indicator (`StepIndicator`) is added to multi-step flows, which Figma lacks.
- The SmartSave step order is: name + target → duration (chips) → auto-save on/off → frequency + day (chips) → funding source (sheet) → confirm (`BocSummaryGrid` sheet) → status. Fixed: amount → term → maturity disclosure (rate, maturity date, early-exit penalty) → funding → confirm. Padi: name → members (stepper, 2–20) → contribution amount → frequency → contribution day(s) (multi-select chips) → start date → payout order explanation → confirm.
- Dates use `showDatePicker`, not free-text "dd/mm/yy".
- The pinned `PrimaryButton("Continue")` stays disabled until its step is valid; inline validation messages appear under the fields.
- The penalty disclosure appears before confirmation, not only in helper text.

- [ ] Implement. The "created" status screen is reachable only from the provider's confirmed-result state (same pattern as Task 11). Run `flutter analyze`. Commit.

### Task 11: Send hub, PIN authorisation, result and receipt

**Figma:** Send `2:5971`, Move money `2:5868`, beneficiary `2:5766`/`2:5887`/`2:5910`, account `2:5933`, from/to `2:9108`/`2:9139`, PIN `2:4815` family, Money added `2:4350` family, receipts `2:3042` family.
**Files:** `send_screens.dart`, `transaction_flow_screens.dart`, `transaction_widgets.dart`, `forms.dart`, `money_widgets.dart`. Create `test/transaction_flow_test.dart`.

- Send hub: three `PaymentActionCard`s (Move money, To BOCTRUST, To another bank) with gold-accent icon tiles, then "Send to beneficiaries" (only from the beneficiaries API; unavailable → section omitted). Figma's sample names are not rendered.
- Amount → review (`BocSummaryGrid`: to, bank, amount, fee, total) → PIN screen (summary card + keypad) → `BocStatusScreen`/`BocReceiptCard` only from a confirmed server result. Network timeout → a pending state with a "Check status" action, never success.
- Keep the existing unavailable messaging for unsupported flows through the registry.

- [ ] Failing widget test (one case): with a fake **failed** server response, recipient → amount → review → PIN ends on the failure status, and neither "Successful" nor any reference text renders.
- [ ] Implement. Run `flutter test test/transaction_flow_test.dart` and `flutter analyze`. Commit.

### Task 12: Transaction history and Payments hub

**Figma:** history `2:7097`, Payments `2:6035`, Airtime `2:4998`/`2:5043`/`2:5084`, airtime receipt `2:4247`.
**Files:** `payments_screens.dart`, `transaction_flow_screens.dart`, `payment_widgets.dart`, `list_tiles.dart`.

- History: grouped by month (sticky month header with In/Out totals, only from the API), `TransactionTile`s, and a filter by type via a chips row. It is gated by `transactionHistory`; unavailable shows the unavailable state, not an empty list.
- Payments hub: search field (filters the biller grid locally), Scan to pay card, bill grid (`BillGridItem`: 4 columns at 390 and 3 below 360, each with a distinct icon per category; Figma reuses one icon for all), recent transactions (only with history). Every biller and scan tile is gated and opens the unavailable sheet. The airtime screens are built as a shell: network chips, a phone field with contact-picker affordance hidden, and amount presets.

- [ ] Implement. Run `flutter analyze`. Commit.

### Task 13: Account hub and Account tiers

**Figma:** Account `2:6069`, My profile `2:7031`, Account tiers `2:6418` family, Tier 2/3 `2:6831`/`2:6867`, tier verification `2:6927`/`2:6963`.
**Files:** `account_screens.dart`, `kyc_screens.dart`, `kyc_widgets.dart`, `app_flow_screens.dart`.

- Account hub: header (avatar, name, email · account number with copy, tier tag) → `SettingsGroup`s: *Account details* (My profile, Account tier, Request limit increase, Account statement), *Settings* (Manage beneficiaries, Linked banks, Security Center, Preferences), *More services* (Loans, Cards → coming soon via the registry), *Support* (Support, Privacy policy, Terms), then Log out and Delete account (`error` text colour) at the bottom. The theme toggle moves from Figma's header icon into Preferences, which is a clearer home.
- Tiers: current-tier banner, then tier cards with requirement tags and lock captions. Tier 3 adds the CAC / bank-statement entry points from Task 3 when relevant.

- [ ] Implement. Run `flutter analyze`. Commit.

---

## Phase 3 — Minor changes to current screens

### Task 14: Auth, onboarding and basic KYC visual alignment

**Figma:** Splash `2:3160`, Onboarding 1–3 `2:3342`/`2:3355`/`2:3879`, Open up `2:4022`, Sign up `2:4040`–`2:4127`, Sign in `2:4523`, Forgot password `2:4557`/`2:5146`/`2:5132`, Reset `2:4460`, Set PIN `2:4569`/`2:4659`, Tier 1 steps `2:6449`–`2:6630`, BVN error `2:9388`.
**Files:** `onboarding_flow_screens.dart`, `kyc_screens.dart`, `forms.dart`, `text_fields.dart`, `branding.dart`.

- Adopt `BocAppBar`, the unified field, the segmented Phone/Email control, OTP cells, PIN keypad, the password meter and `BocStatusScreen`. The onboarding pager gets dots (Figma `2:7185`) and Skip/Next.
- The "Use Face ID" link on sign-in is hidden (biometric capability unavailable; `/login/biometric` keeps its existing redirect).
- The SMS/WhatsApp "Send my code by" choice (`2:7845`) is shown **only** if the OTP API accepts a channel; otherwise it is omitted (no fake choice).
- Authentication and KYC request semantics do not change.

- [ ] Implement. Run `flutter analyze`. Commit.

### Task 15: Remaining account surfaces

**Figma:** Linked banks `2:6334`/`2:6390`/`2:6249`, beneficiaries `2:6337`/`2:6351`, Support `2:6221`, My profile `2:7031`, Theme `2:6903`.
**Files:** `linked_bank_accounts_screen.dart`, `account_screens.dart`, `list_tiles.dart`.

- Restyle only (`BankRow`, `ContactCard`, `SettingsTile`, unified fields). Linked banks keeps its live CRUD, and removal uses `AppConfirmSheet` + `DestructiveButton`.
- [ ] Run `flutter analyze`. Commit.

### Task 16: Customer-visible brand copy

**Files:** `lib/app.dart`, `lib/app/app_router.dart`, `lib/module/component/branding.dart`, `lib/module/onboarding/screens/onboarding_flow_screens.dart`, `lib/module/send/screens/send_screens.dart`, `lib/module/account/screens/account_screens.dart`, `lib/module/account/model/user_profile_model.dart`, `lib/module/app_flow/app_flow_navigator.dart`.

Replace every customer-visible "Cheetah" string. Identifiers (`CheetahApp`, `CheetahTheme`, `_CheetahMaterialApp`), the `'Cheetah.Model'` logger name and doc comments stay unchanged.

| Location | Current | Replacement |
| --- | --- | --- |
| `app.dart` `MaterialApp.title` | `'Cheetah'` | `'BOCTRUST'` |
| `branding.dart` logo wordmark | `'Cheetah'` | `'BOCTRUST'` |
| `app_router.dart` fallback title | `'Cheetah'` | `'BOCTRUST'` |
| `onboarding_flow_screens.dart` slide copy | "…between your Cheetah accounts…" | "…between your BOCTRUST accounts…" |
| `send_screens.dart` hub card / unavailable message | "To a Cheetah beneficiary", "…another Cheetah user…" | "To a BOCTRUST account", "…another BOCTRUST user…" |
| `account_screens.dart` display-name fallback, `user_profile_model.dart` fallback | "Cheetah customer" | "BOCTRUST customer" |
| `account_screens.dart` OTP helper | "Cheetah will send a one-time verification code." | "BOCTRUST will send a one-time verification code." |
| `account_screens.dart` social labels | "Cheetah MFB" | "BOCTRUST MFB" |
| `account_screens.dart` support email / social handles | `info@cheetahmfb.com`, `@cheetahmfb` | Official BOCTRUST values (**to be supplied**). Until supplied, hide those rows rather than show Cheetah contacts. |
| `app_flow_navigator.dart` loans/cards unavailable messages | "…part of Cheetah's app yet…" | "…part of the BOCTRUST app yet…" |

- [ ] Replace, then run `flutter analyze` and check the listed screens in the app. Commit.

---

## Final verification

- [ ] `dart format --set-exit-if-changed lib test`
- [ ] `flutter analyze`
- [ ] `flutter test test/feature_capability_test.dart test/private_route_gate_test.dart test/account_controls_test.dart test/transaction_flow_test.dart`
- [ ] `grep -rn "Color(0x" lib/module` shows no new hard-coded colours outside `colors.dart`; no string literal shown to customers contains "Cheetah" (review `grep -rn "'[^']*Cheetah\|\"[^\"]*Cheetah" lib`; matches in identifiers, logger names and comments are expected and allowed).
- [ ] Run the app and compare against Figma intent at 390 px in light **and** dark: Home, Save hub, SmartSave create, plan detail, Send review + PIN, receipt, Security Center, Account, CAC upload, onboarding. Repeat Home, SmartSave and Security at 320 px with the largest system text.
- [ ] TalkBack/VoiceOver pass on Home, PIN entry and a confirmation sheet: every control has a label, amounts read as currency, and hidden balances read "Balance hidden".
- [ ] Every private route redirects when signed out; no unavailable capability can submit; no screen presents fabricated financial data.
- [ ] Customer-facing labels use BOCTRUST/BOC; package names, storage keys, route paths and API payloads are unchanged.

## Explicit deferrals

- **Investment tab and screen** (`2:6028`): not built; the current nav is kept.
- **Home "Banner Ads"**: needs a content source.
- **Receipt sharing**: needs `share_plus` (a new package), so it requires approval. The button stays gated.
- **Biometric login/transfers**: need `local_auth` and a backend device-binding contract. Shells only.
- **Any API request** whose endpoint, authentication, request schema and response schema are absent from the repository or supplied documentation.
- **Flipping a capability to `available`** requires, together in one change: the endpoint in `ApiEndpoints`, typed request and response models, the service method, provider success/error mapping, and the registry requirement entry. No new test is required unless the flow moves money or is destructive, in which case one failure-path test is added.
- **FH Oscar typeface**: only if BOCTRUST obtains a commercial licence. It is then a one-line `kFontFamily` change plus the font assets.
- No golden, snapshot, contrast, layout or copy tests; no device end-to-end automation. The four safety tests plus the existing suite are the agreed regression floor.
