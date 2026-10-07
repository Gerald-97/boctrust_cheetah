# Core Account Activity and Snap-to-Pay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a live summary and transaction history for each of the customer's Core accounts, and let a photo fill a recipient account number through snap-to-pay. Record that the backend owns account opening.

**Architecture:** Two new reads on `CoreAccountService` feed an account detail screen through session-scoped providers keyed by account number. A small `CoreOcrService` posts a picked photo to snap-to-pay. The number it returns only fills the BOCTRUST and other-bank account fields; it never submits anything. Everything ships staging-only behind its own capability.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, existing `ApiService`, `NotifierState` and `SessionScopedNotifier`. One new dependency: `image_picker`.

**Spec:** The published Core API docs are the source of truth (https://core-dev-api.centurysoftware.dev/api/v1/docs/, Swagger init SHA-256 `920fbbc499d986ebf79a47ddabb0a221e35b335b217cc36cdcaf4af19730b28c`, fetched 7 October 2026). These product decisions, from Kenechukwu on 7 October 2026, resolve gates G1 and G7 of `docs/superpowers/plans/2026-10-02-core-mobile-endpoints-integration.md`:
- G1: the backend opens Core accounts, so the app does not call `POST /me/bank-accounts`.
- G7: Scan to pay uses `POST /me/snap-to-pay` with photos from `image_picker`.
- History UI: on a per-account detail screen.

Status: proposed; nothing implemented. Branch from `feat/core-pin-live-status` (or `main` once that merges). Someone else has uncommitted edits in `lib/module/savings/screens/savings_screens.dart`, `lib/module/component/savings_widgets.dart` and `lib/module/core_banking/model/bank_product_models.dart`. Rebase onto their work before touching the savings files, and never stage changes you did not make.

## Contract (from the docs)

| Endpoint | Request | 200 `data` | Errors |
|---|---|---|---|
| `GET /me/bank-accounts/{accountNumber}/summary` | path `^\d{10}$` | `accountNumber, customerId, name, product, branch, accountStatus, notificationPreference, transactionPermission` (strings); `availableBalance, ledgerBalance` (**numbers**) | 401, 404 "No such account exists for this customer." |
| `GET /me/bank-accounts/{accountNumber}/transactions` | path `^\d{10}$`; query `fromDate*`, `toDate*` as `DD-MM-YYYY`; `numberOfItems` 1–1000, default 20 | `accountNumber`, `transactions: []` — **item schema unpublished** | 400 validation, or BankOne rejected a range it reads as more than three months, even some that look narrower; 401; 404 |
| `POST /me/snap-to-pay` | `{"image": base64 JPEG/PNG, no data-URI prefix, max 8MB}` | `{number}`: the longest run of 4+ digits anywhere in the image | 400 "No run of 4+ digits was found" |

`POST /me/bank-accounts` and `POST /me/scan-to-pay` are deliberately not integrated.

## Global Constraints

- Core transport only (`coreApiServiceProvider`). A missing `CORE_BASE_URL` returns `NotifierState.blocked`, never an exception or empty data.
- A non-`^\d{10}$` account number is never sent.
- Money stays an exact decimal string for display. The summary's numeric balances become strings with `num.toStringAsFixed(2)`; no arithmetic on them.
- `customerId` from the summary is not stored or displayed.
- The date range defaults to the last 30 days, with presets of 7, 30 and 60 days and no custom range. The docs warn that some ranges under three months are still rejected.
- No automatic retries. Tests stay minimal: one focused test per behavior.
- All new capabilities are `stagingOnly: true`.

## Review Focus

1. A 400 on transactions (range too long) keeps the summary visible and shows "Choose a shorter date range." rather than a blank or generic error (Task 3).
2. Switching accounts, or signing out mid-load, never shows one account's history under another (Task 3).
3. A snap result is a suggestion: it fills the field only after the field's own 10-digit rule passes, and never advances or submits (Task 4).
4. An image over 8MB after compression is refused before upload with a clear message (Task 4).
5. An unknown or missing field in a transaction row drops that field, not the whole list (Task 2).

---

### Task 1: Account summary read

**Files:**
- Create: `lib/module/core_banking/model/core_account_summary.dart`
- Modify: `lib/app/core_api_endpoints.dart`, `lib/module/core_banking/service/core_account_service.dart`
- Test: `test/core_account_contract_test.dart` (append)

**Interfaces — Produces:**
- `CoreApiEndpoints.bankAccountSummary(String accountNumber)` → `'/me/bank-accounts/<encoded>/summary'`; `bankAccountSummaryTemplate = '/me/bank-accounts/{accountNumber}/summary'`.
- `class CoreAccountSummary extends Equatable { accountNumber, name?, product?, branch?, CoreAccountStatus status, String? availableBalance, String? ledgerBalance; factory fromJson(Object?) }`. `status` uses the existing `CoreAccountStatus.parse`; balances accept a `num` (as `toStringAsFixed(2)`) or a decimal string.
- `CoreAccountService.getAccountSummary(String accountNumber) -> Future<NotifierState<CoreAccountSummary>>`.

- [ ] **Step 1: Write failing tests** in `test/core_account_contract_test.dart`:
  - `summary parses numeric balances to exact strings and drops customerId`: `fromJson({'accountNumber':'1100919408','customerId':'C1','name':'ADA OBI','product':'Boc Flex','branch':'HQ','accountStatus':'active','availableBalance':7654.3,'ledgerBalance':100})` gives `availableBalance == '7654.30'`, `ledgerBalance == '100.00'` and `status == CoreAccountStatus.active`, and `props` does not contain `'C1'`.
  - `summary is never requested for a malformed number`: with a recording adapter, `getAccountSummary('12')` is `isError` and records zero requests; `getAccountSummary('1100919408')` sends `GET /me/bank-accounts/1100919408/summary`.
- [ ] **Step 2: Run** `flutter test --no-pub test/core_account_contract_test.dart`. Expected: FAIL (undefined `CoreAccountSummary`).
- [ ] **Step 3: Implement** the endpoint builder, model and service method, mirroring `getBankAccount`.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(core): read a live account summary`.

### Task 2: Account transactions read

**Files:**
- Create: `lib/module/core_banking/model/core_account_transactions.dart`
- Modify: `lib/app/core_api_endpoints.dart`, `lib/module/core_banking/service/core_account_service.dart`
- Create: `docs/verification/contracts/2026-10-07-core-account-transactions.json` (sanitized sample, `git add -f`)
- Test: `test/core_account_contract_test.dart` (append)

**Interfaces — Produces:**
- `CoreApiEndpoints.bankAccountTransactions(String accountNumber)`; `bankAccountTransactionsTemplate = '/me/bank-accounts/{accountNumber}/transactions'`.
- `enum CoreHistoryRange { last7Days(7), last30Days(30), last60Days(60) }` with `({String fromDate, String toDate}) window(DateTime today)` returning `DD-MM-YYYY` strings, where `toDate` is today and `fromDate` is today minus `days`.
- `class CoreAccountTransaction extends Equatable { String? reference, DateTime? date, String? narration, String? amount, CoreTransactionDirection? direction, String? balanceAfter }` with `enum CoreTransactionDirection { credit, debit }`; `static List<CoreAccountTransaction> listFromJson(Object? data)`.
- `CoreAccountService.getAccountTransactions(String accountNumber, CoreHistoryRange range, {int numberOfItems = 50, DateTime? today}) -> Future<NotifierState<List<CoreAccountTransaction>>>`.

- [ ] **Step 1: Capture the row shape.** The docs publish `items: {}`. On authenticated staging, call the endpoint for a test account with recent activity, sanitize it (mask account numbers to their last 4 digits, replace names) and save it as the fixture. Map only the keys the sample contains onto the fields above. **If you cannot get a sample, stop at this step.** Record the blocker in the fixture and leave `listFromJson` returning rows with only the fields the docs guarantee, which is none: Task 3 then shows the summary plus "Transaction history isn't available yet."
- [ ] **Step 2: Write failing tests:**
  - `history window formats DD-MM-YYYY`: `CoreHistoryRange.last30Days.window(DateTime(2026, 10, 7))` returns `(fromDate: '07-09-2026', toDate: '07-10-2026')`.
  - `transactions request carries the window and item count`: the recorded GET is `/me/bank-accounts/1100919408/transactions` with query `{'fromDate': '07-09-2026', 'toDate': '07-10-2026', 'numberOfItems': 50}`; a malformed number records no request.
  - `a row with an unreadable field keeps the row`: built from the fixture's first row with one amount replaced by `{}`, the row parses with `amount == null` and its other fields intact.
- [ ] **Step 3: Run** `flutter test --no-pub test/core_account_contract_test.dart`. Expected: FAIL.
- [ ] **Step 4: Implement.** Amounts use the same decimal-string rule as `customer_bank_account_models.dart` (accept `num` via `toStringAsFixed(2)`). Rows are newest first by `date`, with undated rows last. The list sits under `data.transactions`; read it with `coreRows(data, const ['transactions'])`.
- [ ] **Step 5: Run** the same command. Expected: PASS.
- [ ] **Step 6: Commit** `feat(core): read live account transactions`.

### Task 3: Account detail screen

**Files:**
- Create: `lib/module/core_banking/provider/core_account_activity_providers.dart`, `lib/module/core_banking/screens/bank_account_detail_screen.dart`
- Modify: `lib/app/app_router.dart` (route), `lib/module/app_flow/route_definitions.dart`, `lib/app/feature_capability.dart`, `lib/app/private_user_state.dart`, `lib/module/savings/screens/savings_screens.dart` (entry points only)
- Test: create `test/bank_account_detail_test.dart`; append one case to `test/feature_capability_test.dart`

**Interfaces:**
- Consumes: `getAccountSummary`, `getAccountTransactions` and `CoreHistoryRange` from Tasks 1–2.
- Produces:
  - `AppRoutes.bankAccountDetail = '/savings/account'`, opened with `AppRouteArguments(entityId: accountNumber)`.
  - `FeatureCapability.coreAccountActivity`, registered `stagingOnly: true` with `GET bankAccountSummaryTemplate` and `GET bankAccountTransactionsTemplate`.
  - `coreAccountSummaryProvider` and `coreAccountTransactionsProvider` as `NotifierProvider.family`. The summary is keyed by `String accountNumber`; transactions by `({String accountNumber, CoreHistoryRange range})`. Both are cleared on session change, following `SessionScopedNotifier`, and both are cleared in `clearPrivateUserState`.

- [ ] **Step 1: Write failing tests** in `test/bank_account_detail_test.dart`, using fake services:
  - `detail shows summary and recent transactions`: route with `entityId: '1100919408'`; the screen shows the product name, `₦7,654.30` and one transaction's narration.
  - `a rejected range keeps the summary and asks for a shorter one`: transactions return `NotifierState.error('x', statusCode: 400)`; the screen shows `Choose a shorter date range.` and still shows the balance.
  - `changing the range reloads only transactions`: tap `Last 7 days`; the fake records one more transactions call and no new summary call.
  - In `feature_capability_test.dart`: `coreAccountActivity` is unavailable when `staging: false`.
- [ ] **Step 2: Run** `flutter test --no-pub test/bank_account_detail_test.dart test/feature_capability_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement the providers and screen.**
  - Screen layout: summary card (product, name, account number, branch, status, available and ledger balance), then range chips (7 / 30 / 60 days, default 30), then the list.
  - Rows: narration, date, signed amount, credit or debit tone.
  - Error and empty states use `ApiStateCard`. A 404 shows "This account isn't available." A transactions 400 shows "Choose a shorter date range."
  - Pull to refresh reloads both.
  - Respect `homeBalanceHiddenProvider` for the balances.
- [ ] **Step 4: Add the entry points**, keeping them minimal and rebased onto the concurrent savings edits. Make the savings hub's `_coreAccountTile` tappable to the route. Add a "Transactions" tile on the Flex screen for the Core Flex account. Point `AppRoutes.flexStatement` at the detail screen for the Flex account once `coreAccountActivity` is available, keeping its current unavailable page otherwise.
- [ ] **Step 5: Run** the Step 2 command, then `flutter analyze`. Expected: PASS, no issues.
- [ ] **Step 6: Commit** `feat(core): show account summary and history`.

### Task 4: Snap-to-pay account number fill

**Files:**
- Modify: `pubspec.yaml` (`image_picker`), `ios/Runner/Info.plist` (`NSPhotoLibraryUsageDescription`; `NSCameraUsageDescription` already exists, so check its wording still fits), `lib/app/core_api_endpoints.dart`, `lib/app/feature_capability.dart`
- Create: `lib/module/core_banking/service/core_ocr_service.dart`, `lib/module/core_banking/screens/snap_number_button.dart`
- Modify: `lib/module/core_banking/screens/boctrust_transfer_screen.dart`, `lib/module/core_banking/screens/interbank_transfer_screen.dart`, `lib/module/payments/screens/payments_screens.dart` (`_scanScreen`)
- Test: create `test/snap_to_pay_test.dart`

**Interfaces — Produces:**
- `CoreApiEndpoints.snapToPay = '/me/snap-to-pay'`.
- `const kSnapImageMaxBytes = 8 * 1024 * 1024`.
- `CoreOcrService.readNumber(Uint8List image) -> Future<NotifierState<String>>`. It refuses more than `kSnapImageMaxBytes` locally with "This photo is too large. Try again closer to the number." It posts `{'image': base64Encode(image)}`, and maps a 400 to "We couldn't find a number in that photo."
- `SnapNumberButton({required ValueChanged<String> onNumber})` picks from the camera or gallery via `ImagePicker().pickImage(source, maxWidth: 1600, imageQuality: 85)` and calls `onNumber` only with a `^\d{10}$` result. Any other result shows "That number isn't a 10-digit account number."
- `FeatureCapability.scanToPay` registered `stagingOnly: true` with `POST /me/snap-to-pay`.

- [ ] **Step 1: Write failing tests** in `test/snap_to_pay_test.dart`:
  - `snap sends bare base64 and returns the number`: the recorded body is `{'image': base64Encode(bytes)}`, contains no `data:` prefix, and the result `data == '0123456789'`.
  - `an oversized photo is refused before upload`: `readNumber(Uint8List(kSnapImageMaxBytes + 1))` is `isError` and records zero requests.
  - `a snapped number only fills the field`: in `BoctrustTransferFlow` with a fake `SnapNumberButton` callback delivering `'1100037777'`, the account field contains it, the screen is still the form step, and no transfer request was made.
- [ ] **Step 2: Run** `flutter test --no-pub test/snap_to_pay_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `flutter pub add image_picker`.
  - Add the service and button. Place the button as the account-number field's suffix in both transfer forms, shown only when `scanToPay` is available.
  - In the interbank form, filling the number runs the existing `_changeRecipient`, so name enquiry still has to confirm it.
  - Replace `_scanScreen` with a page that snaps a number, shows it, and offers "Send to a BOCTRUST account" (`AppRoutes.sendBeneficiary`) and "Send to another bank" (`AppRoutes.sendOtherBank`) with `entityId: number`. Both flows read `routeArguments.entityId` once in `initState` to prefill the field.
- [ ] **Step 4: Run** the Step 2 command, then `flutter analyze`. Expected: PASS, no issues. Build iOS once (`flutter build ios --simulator --no-codesign`) to confirm the plugin links.
- [ ] **Step 5: Commit** `feat(core): fill account numbers from a photo`.

### Task 5: Record decisions and verify

**Files:**
- Create: `docs/verification/2026-10-07-core-account-activity.md` (`git add -f`)
- Modify: `docs/superpowers/plans/2026-10-02-core-mobile-endpoints-integration.md` (dated notes on Tasks 1, 3 and 14 only)

- [ ] **Step 1: Write the notes.** In the 2 October plan, record under Task 1 that G1 is resolved as backend-owned, so Task 3 is not built. Record under Task 14 that G7 is resolved as snap-to-pay with `image_picker`, implemented by this plan.
- [ ] **Step 2: Verify.** Run `flutter analyze` and `flutter test --no-pub`. Record the actual counts in the verification doc, along with:
  - whether a transactions fixture was captured;
  - the staging device checks for summary, all three ranges, a range-rejection case and snap from the camera and from the gallery. Leave unchecked any check that was not run.
- [ ] **Step 3: Commit** `docs(core): record account activity and snap-to-pay`.

## Deferred and not in scope

- Account opening (`POST /me/bank-accounts`): backend-owned per G1. The `coreAccountOpening` capability stays unregistered.
- `scan-to-pay`: not used, because snap is the more forgiving endpoint.
- Bill customer-ID fill from a photo: bills stay gated until the mobile bill PIN contract exists.
- Redacting `image` and `number` from staging logs: deferred to production-launch preparation per the 2 October ruling. Base64 bodies will be large in staging logs until then.
