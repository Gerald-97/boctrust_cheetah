# Core Mobile Endpoints and Remaining Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Superseded in part (7 October 2026):** for the four mobile transfer and withdrawal POSTs, the transaction-PIN body prohibition and cached-only status behaviour here are replaced by [Core transaction PIN and live status](../specs/2026-10-07-core-pin-status-ui-design.md) and its [integration plan](2026-10-07-core-pin-status-ui-integration.md). Bills are unchanged.

**Goal:** Integrate every remaining Core Service mobile endpoint (account opening, single-account read, own-account transfers and withdrawals, BOCTRUST transfers, interbank directory/enquiry/transfer/status, bill catalogues and payments, beneficiaries, snap/scan-to-pay) and close the open KYC, backend and release items, each slice shipping only when its gate is met.

**Architecture:** Everything Core goes through the existing isolated transport (`coreApiServiceProvider`, `CoreApiEndpoints`, `ApiBackend.core`) and the session-scoped notifier pattern in `lib/module/core_banking/provider/core_account_providers.dart`. Money movement shares one foundation: exact money parsing, a transaction-authorization interface, one submission state machine that never auto-retries, and one outcome model. Each feature registers its own capability only when its slice is complete, so partial delivery is always honest.

**Tech Stack:** Flutter, Dart 3.12+, Riverpod 3, Dio 5, Equatable, `file_picker` (already a dependency), Flutter unit/widget tests.

**Spec:** Live Core OpenAPI (`https://core-dev-api.centurysoftware.dev/api/v1/docs/`, SHA-256 `f150ae0096c4429a9a1626f396f5eb35556d66ed3ad21ca13cef084815dbf0ab`), its **Contract Update** section in `docs/superpowers/plans/2026-10-02-core-banking-transfers-bills.md`, the execution log `docs/superpowers/execution/2026-10-02-kyc-core-execution-log.md`, and the 2 October 2026 device-run findings recorded below.

**Builds on:** Core Tasks 1–3 and KYC Tasks 1–5 (shipped). This plan supersedes the deferred Core Tasks 4–5 and the plan's "Future Money-Moving Plan Gate".

**Working-tree preflight (human checkpoint):** run `git status --short` first. Commit or set aside unrelated work (currently `lib/app.dart`, `lib/app/theme.dart`, `test/button_theme_contrast_test.dart`) before any task stages files.

**Human checkpoints:** Steps marked **(human checkpoint)** need backend, security, product, staging or device input. Stop, report what is needed, wait. Never mark one complete from inference.

## Contract Facts This Plan Relies On

| Endpoint | Request (required `*`) | Success | Notable errors |
|---|---|---|---|
| `POST /me/bank-accounts` | `lastName* firstName* city* address* gender* dateOfBirth* phoneNumber* bvn* email*`, optional `middleName placeOfBirth nin accountTier transactionPermission notificationPreference productCodes[]` | `results[]: {productCode, productName, status: created\|already_exists\|failed, accountNumber?, reason?}` (best-effort, per product) | 400 validation |
| `GET /me/bank-accounts/{accountNumber}` | path `^\d{10}$` | `CustomerBankAccountSummary` | 404 not the caller's |
| `POST /me/intrabank/transfers/own` | `toProductCode*`, `amount*` (Kobo string), `narration` ≤100 | `{responseCode, reference?, message?}` (example `00`) | 400, 403 frozen, 404, 409 reference collision "safe to retry" |
| `POST /me/intrabank/withdrawals` | `fromProductCode*`, `amount*` (Kobo), `narration` ≤100 | same as above | same |
| `POST /me/intrabank/transfers` | `toAccountNumber*`, `amount*` (Kobo), `narration` ≤100 | same as above | same |
| `GET /me/interbank/banks` | — | **no `data` schema attached** (component `CommercialBankResponse {code,id,name}`) | — |
| `POST /me/interbank/name-enquiry` | `accountNumber*`, `bankCode*` | **no `data` schema attached** (component `NameEnquiryResponse {name?, bvn?, kyc?}`) | — |
| `POST /me/interbank/transfers` | `receiverBankCode*`, `receiverAccountNumber*`, `amount*` (Kobo), `narration` ≤100 | `{status, reference?, uniqueIdentifier?, responseCode, message?}` | 400, 403, 404, 409, **500 name enquiry failed or rejected** |
| `GET /me/interbank/transfers/{reference}/status` | path | `{reference, status: pending\|completed\|failed, transferStatus?, responseCode?, message?}` (last known, not a live re-query) | 400 format, 404 |
| `GET /me/bills/billers`, `/billers/categories`, `/payment-items` | no parameters | **no `data` schemas attached** (components: category `{id,name,description,isAirtime}`; biller `{billerId:int,billerCategoryId,categoryName,name,shortName,currencyCode,customerField1?,customerField2?,isActive}`; item `{id,code,billerId,name,amount:number}`) | — |
| `POST /me/bills/payments` | `billerId*`, `paymentItemId*`, `customerId*` (biller's identifier), `amount*` (**Naira** string) | `{status, reference?, uniqueIdentifier?, responseCode, message?}` | 400, 403, 404 (no Flex, unknown biller/item, no biodata), 409 |
| `POST /me/beneficiaries` | bank: `type*=bank_account, bankCode*, number*, nickname≤100`; bill: `type*∈electricity\|water\|cable_tv\|internet\|betting, billerId*, name*, billerCategoryId*, billerCategoryName*, paymentItemId*, paymentItemName*, number*` | `BeneficiaryResponse` | 404 unknown bank, 409 duplicate |
| `GET /me/beneficiaries?type=` | optional type filter | `BeneficiaryResponse[]` | — |
| `DELETE /me/beneficiaries/{beneficiaryId}` | path | — | 404 |
| `POST /me/snap-to-pay`, `/me/scan-to-pay` | `image*`: base64 JPEG/PNG, no data-URI prefix, ≤ 8 MB | `{number}` (snap: longest run of ≥4 digits; scan: whole text must be digits) | 400 nothing found |

## Global Constraints

- Core calls use only `coreApiServiceProvider`/`CoreApiEndpoints`; add every new path to `CoreApiEndpoints` and every capability operation with `backend: ApiBackend.core`.
- Transfers and withdrawals send **Kobo** integer strings; bill payments send **Naira** decimal strings. Never parse money with `double`/`num`; reuse `formatApiAmount` for display.
- Payment-item `amount` is a JSON number: do not display or submit it until it is published as a decimal string (gate G5).
- Every reference is generated server-side; there is no idempotency key. **Never auto-retry a money-moving POST.** A `409` may be retried only by an explicit customer action. A timeout, dropped connection or `5xx` other than the documented interbank `500` is **Unknown**: show guidance, refresh balances, never re-enable Submit for the same draft.
- A `200` means accepted. Show "Completed" only for interbank `status: completed` from the status GET; intrabank and bills show "Submitted"/"Processing" unless gate G4 publishes success semantics.
- No transaction is submitted without the gate-G2 authorization step; a PIN never goes into a Core request body.
- Never log or persist full account numbers, `customerId` (biller identifiers), BVN, name-enquiry `kyc`, images or PINs (redaction already covers `accountnumber`, `customerid`, `bvn`, `pin`; add `image` and `number` in Task 2).
- Changing any input (account, bank, product, biller, item, customer ID, amount) invalidates review and authorization.
- Each capability becomes available only when its slice's endpoints, models, service, session-scoped provider, widgets and tests all exist and its gates passed; otherwise it stays unregistered.
- Clear every new provider through `clearPrivateUserState` and on session change.
- Minimum necessary tests per implementation (user directive, 2 October 2026).

## Gates

| Gate | Question | Owner | Unblocks |
|---|---|---|---|
| G1 | Who opens Core accounts: the backend (after which KYC tier?) or an app flow? Why is `missingProducts` empty on staging? | Backend/product | Tasks 3–4, and device verification of Home/Savings |
| G2 | Transaction authorization: backend transaction-bound token/PIN, or signed-off step-up using `/auth/pin/verify-current`? | Security | Tasks 6–8, 10, 12 |
| G3 | Sanitized authenticated fixtures and attached `200` schemas for banks, name enquiry, categories, billers, payment items | Backend | Tasks 9, 11 |
| G4 | Meaning of `responseCode` (`00` = success?) for intrabank and bills; bill `status` values | Backend | Final success copy in Tasks 6–8, 12 |
| G5 | Payment-item `amount` as decimal string with unit; Airtime vs Data rule within `Mobile/Recharge` (`isAirtime` on category?) | Backend | Tasks 11–12 |
| G6 | BOCTRUST recipient confirmation: is there a mobile name lookup for `toAccountNumber`? If not, product accepts "account number only, irreversible" copy? | Backend/product | Task 8 |
| G7 | Snap vs scan: which endpoint does the app use (snap is more forgiving)? Image dependency (`image_picker`) approved? | Product/engineering | Task 14 |

## Review Focus

- A second tap, app background or network drop during any money POST must never produce a second POST; pin in Task 5 provider tests.
- A timed-out transfer must not show Success or Failed, and must not re-enable Submit for that draft; pin in Task 5.
- `12.345`, `1e3`, `-5`, `0`, `000`, `₦1,000.50` and a 20-digit amount must parse to the documented result or a validation error; pin in Task 5 money tests.
- A frozen (`403`) or missing (`404`) Flex account must show an account-state message, not a generic failure; pin in Task 5 outcome tests.
- Name enquiry for an old bank/account must never be attached to a newer draft; pin in Task 9.

---

## Phase A: Accounts

### Task 1 (human checkpoint): Resolve account-opening ownership (G1)

> **Resolved 7 October 2026 (Kenechukwu): the backend opens Core accounts.** Task 3 is not built; `coreAccountOpening` stays unregistered.

**Files:** record the decision in `docs/verification/core-banking-integration.md`.

- [ ] **Step 1:** Ask backend/product the G1 questions; record the answer and date.
- [ ] **Step 2:** If the backend opens accounts, skip Task 3 and mark it "backend-owned". If app-side, continue with Task 3.

### Task 2: Extend endpoints and capabilities for the whole plan

> Done (`797e07a`).

> Ruling (2 October 2026, user): log redaction for `image`/`number` is deferred to production-launch preparation; Task 2 adds endpoints and capabilities only.

**Files:**
- Modify: `lib/app/core_api_endpoints.dart`, `lib/app/feature_capability.dart`
- Test: `test/core_network_test.dart`, `test/feature_capability_test.dart`

**Interfaces — Produces:**
- `CoreApiEndpoints.bankAccount(String accountNumber)`, `.intrabankWithdrawals = '/me/intrabank/withdrawals'`, `.intrabankTransfers = '/me/intrabank/transfers'`, `.beneficiaries = '/me/beneficiaries'`, `.beneficiary(String id)`, `.snapToPay = '/me/snap-to-pay'`, `.scanToPay = '/me/scan-to-pay'` (builders URI-encode one segment).
- New `FeatureCapability` members, **unregistered** until their task: `coreAccountOpening`, `ownAccountTransfers`, `savingsWithdrawals`, `boctrustTransfers`, `interbankTransfers`, `billerDirectoryView`, `airtimePurchase`, `dataPurchase`, `billPayment`, `beneficiariesManage` (existing `beneficiaries`, `scanToPay` reused).

- [ ] **Step 1: Write failing tests:** `bankAccount('0000000001')` → `/me/bank-accounts/0000000001`; `beneficiary('a/b')` → `/me/beneficiaries/a%2Fb`; redaction test logs `{'image': '<base64>', 'number': '0123456789'}` in staging mode and asserts neither value appears; capability test asserts every new member is `unavailable`.
- [ ] **Step 2: Run** `flutter test test/core_network_test.dart test/logging_redaction_test.dart test/feature_capability_test.dart` — FAIL.
- [ ] **Step 3: Implement** the constants/builders, add `'image'` and `'number'` to `_alwaysRedactedKeyParts`, add the enum members without registry entries.
- [ ] **Step 4: Run** the same command — PASS; then `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(core): add endpoints and capabilities for mobile banking`.

### Task 3: Open Core accounts from the app (only if G1 = app-side)

**Files:**
- Create: `lib/module/core_banking/model/account_opening_models.dart`, `lib/module/core_banking/provider/account_opening_provider.dart`, `lib/module/core_banking/screens/account_opening_screen.dart`
- Modify: `lib/module/core_banking/service/core_account_service.dart`, `lib/module/home/screens/home_screen.dart`, `lib/app/app_router.dart`, `lib/app/feature_capability.dart`, `lib/app/private_user_state.dart`
- Test: `test/account_opening_test.dart`

**Interfaces — Produces:**
- `class AccountOpeningRequest { lastName, firstName, city, address, gender, dateOfBirth (DD-MM-YYYY), phoneNumber, bvn, email, List<String>? productCodes; Map<String,Object?> toJson(); }`
- `enum AccountOpeningStatus { created, alreadyExists, failed, unknown }`; `class AccountOpeningResult { productCode, productName, status, accountNumber? , reason? }`
- `CoreAccountService.openAccounts(AccountOpeningRequest) -> Future<NotifierState<List<AccountOpeningResult>>>`
- `accountOpeningProvider` (single-flight; never auto-retries).
- Route `AppRoutes.openAccount = '/accounts/open'`.

- [ ] **Step 1: Write failing tests:** request JSON has exactly the nine required keys plus `productCodes` only when set; `dateOfBirth` `'01-Jun-1982'` from profile becomes `'01-06-1982'`; results parse `already_exists` → `alreadyExists` and unknown → `unknown`; double submit sends one POST; Home with zero accounts shows an "Open your account" card only when `coreAccountOpening` is available; success reloads `customerBankAccountsProvider`.
- [ ] **Step 2: Run** `flutter test test/account_opening_test.dart` — FAIL.
- [ ] **Step 3: Implement.** Prefill from `userProfileProvider` (names, gender, DOB, email) and the BVN recorded by KYC (ask the backend whether `/users/me/kyc/status` can return it; otherwise the customer re-enters it); collect `city`, `address`, `phoneNumber`. Show per-product results; a `failed` product shows its `reason` and a Retry that re-sends only failed product codes.
- [ ] **Step 4: Register** `coreAccountOpening` with `POST /me/bank-accounts`; run tests and `flutter analyze` — PASS.
- [ ] **Step 5: Commit** `feat(core): open bank accounts from the app`.

### Task 4: Refresh one account and show product accounts with live balances

> Done (`b88411f`). Ruling: no family provider; `CustomerBankAccountsNotifier.refreshAccount(accountNumber)` replaces that row in the shared list (`CustomerBankAccountsData.withAccount`), so Home/Savings/Flex stay consistent. It skips while a full load is in flight and drops a late reply if the list changed. Flex pull-to-refresh and the Refresh button use it.

**Files:**
- Modify: `lib/module/core_banking/service/core_account_service.dart`, `lib/module/core_banking/provider/core_account_providers.dart`, `lib/module/savings/screens/savings_screens.dart`
- Test: `test/core_account_provider_test.dart`

**Interfaces — Produces:** `CoreAccountService.getBankAccount(String accountNumber) -> Future<NotifierState<CustomerBankAccount>>`; `coreBankAccountProvider` (family by account number, session-scoped, auto-dispose).

- [ ] **Step 1: Write failing tests:** a malformed number (`'12345'`) returns an error without a request; `404` maps to "Account not found"; the Flex screen pull-to-refresh calls the single-account GET, not the list.
- [ ] **Step 2–4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Commit** `feat(core): refresh a single account balance`.

## Phase B: Money-movement foundation

### Task 5: Money parsing, authorization seam, submission state machine and outcomes

> Done (`c0acdc3`). Rulings: `CoreTransferAck` lives here (`core_submission_models.dart`), not in Task 7. Outcomes are the sealed classes `AcceptedSubmission(ack)`, `RejectedSubmission(reason)` and `UnknownSubmission()`, with customer-safe copy on `CoreRejection.message` (server messages are not shown verbatim). `transactionAuthorizerProvider` defaults to `DeniedTransactionAuthorizer` (authorizes nothing) instead of throwing, until G2. An accepted or unknown draft can never be resent; `reset()` only clears a rejection. Tests kept to the minimum (user directive).

**Files:**
- Create: `lib/module/core_banking/model/core_money.dart`, `lib/module/core_banking/model/core_submission_models.dart`, `lib/module/core_banking/service/transaction_authorizer.dart`, `lib/module/core_banking/provider/core_submission_notifier.dart`
- Test: `test/core_money_test.dart`, `test/core_submission_test.dart`

**Interfaces — Produces:**
- `sealed class MoneyInput { const factory MoneyInput.valid(String minorUnits); const factory MoneyInput.invalid(String message); }`
- `MoneyInput parseNairaToKobo(String text, {required String maxKobo})` and `MoneyInput parseNairaAmount(String text, {required String maxNaira})` (bills).
- `sealed class CoreSubmissionOutcome`: `accepted({String? reference, String? responseCode, String? message})`, `rejected({required String message, required CoreRejection reason})`, `unknown({required String message})`; `enum CoreRejection { validation, insufficientFunds, accountRestricted, accountMissing, referenceCollision, recipientUnresolved, other }`.
- `CoreSubmissionOutcome mapCoreSubmission(ServiceResponse<Object?> response, {bool interbank = false})`.
- `abstract interface class TransactionAuthorizer { Future<bool> authorize(BuildContext context, TransactionSummary summary); }` with `class TransactionSummary { String title; String amountDisplay; List<(String, String)> lines; }`; `transactionAuthorizerProvider` throws `UnimplementedError` until G2.
- `abstract class CoreSubmissionNotifier<D extends Object> extends Notifier<CoreSubmissionState<D>>` with `submit(D draft)`, `reset()`, `clear()`; `CoreSubmissionState { D? draft; bool inFlight; CoreSubmissionOutcome? outcome; }`.

- [ ] **Step 1: Write failing money tests:** `parseNairaToKobo('1')` → `'100'`; `'1.2'` → `'120'`; `'1.23'` → `'123'`; `'₦1,000.50'` → `'100050'`; `'0'`, `'-5'`, `'1e3'`, `'12.345'`, `''`, `'abc'` → invalid; `'000'` → invalid; above `maxKobo` → invalid "exceeds your limit"; `parseNairaAmount('1,000.5')` → `'1000.50'`.
- [ ] **Step 2: Write failing outcome tests:** 200 + body → `accepted` with reference; 403 → `rejected(accountRestricted)`; 404 → `rejected(accountMissing)`; 409 → `rejected(referenceCollision)`; 400 with "insufficient" in message → `insufficientFunds`; interbank 500 → `rejected(recipientUnresolved)`; transport timeout, connection error and other 5xx → `unknown`.
- [ ] **Step 3: Write failing state-machine tests:** two `submit` calls before the first completes produce one service call; after `unknown`, `submit` with the same draft is refused; `reset()` after `rejected(referenceCollision)` allows one explicit resubmit; `clear()` mid-flight discards the late result.
- [ ] **Step 4: Run** `flutter test test/core_money_test.dart test/core_submission_test.dart` — FAIL.
- [ ] **Step 5: Implement.** String arithmetic only (`BigInt` for comparison); strip `₦`, spaces and thousands commas; at most two decimals.
- [ ] **Step 6: Run** — PASS; `flutter analyze` clean.
- [ ] **Step 7: Commit** `feat(core): add money, authorization and submission foundation`.

### Task 6 (human checkpoint): Implement the approved authorizer (G2)

**Files:** Create `lib/module/core_banking/service/pin_step_up_authorizer.dart` (or a backend-token authorizer); Modify `transaction_authorizer.dart`; Test `test/transaction_authorizer_test.dart`.

- [ ] **Step 1:** Record the security decision in `docs/verification/core-banking-integration.md`.
- [ ] **Step 2: Write failing tests** for the chosen authorizer: wrong PIN returns false and never calls the transfer; three failures lock per the backend's rule; the PIN controller is cleared after each attempt.
- [ ] **Step 3–5:** Run (FAIL), implement against the existing `/transaction/authorize` route (replace its placeholder), run (PASS).
- [ ] **Step 6: Commit** `feat(core): authorize transactions before submission`.

## Phase C: Transfers and withdrawals

### Task 7: Own-account transfer and savings withdrawal

> Built (`f01dec4`), capabilities **not registered** (waiting on G2). Rulings: one `OwnAccountMoveDraft` with `OwnAccountDirection { toSavings, toFlex }` and one `ownAccountMoveProvider` instead of two drafts/providers (the endpoints share a shape); service method `CoreTransferService.moveBetweenOwnAccounts(draft)`. Both directions live in one screen (`lib/module/core_banking/screens/own_account_move_screen.dart`, a part of the app-flow library) behind Send → "Between my accounts"; a direction appears only when its capability is available. The Savings product-tile "Withdraw to Flex" entry is deferred to registration time. Limits come from the source account's balance via `balanceToKobo`. A blocked (unconfigured) reply now maps to a rejection, since nothing was sent. To enable after G2: register `ownAccountTransfers` (`POST /me/intrabank/transfers/own`) and `savingsWithdrawals` (`POST /me/intrabank/withdrawals`) and swap in the approved authorizer.

**Files:**
- Create: `lib/module/core_banking/model/intrabank_models.dart`, `lib/module/core_banking/service/core_transfer_service.dart`, `lib/module/core_banking/provider/intrabank_submission_providers.dart`
- Modify: `lib/module/send/screens/transaction_flow_screens.dart` (route `sendOwnAccount`), `lib/module/savings/screens/savings_screens.dart` (product account "Withdraw to Flex"), `lib/app/feature_capability.dart`, `lib/app/private_user_state.dart`
- Test: `test/intrabank_own_account_test.dart`

**Interfaces — Consumes:** Task 5 (`parseNairaToKobo`, `CoreSubmissionNotifier`, `mapCoreSubmission`, `TransactionAuthorizer`), `customerBankAccountsProvider`. **Produces:** `OwnAccountTransferDraft {toProductCode, amountKobo, narration?}`, `SavingsWithdrawalDraft {fromProductCode, amountKobo, narration?}`, `class CoreTransferAck {String? responseCode; String? reference; String? message; String? status; String? uniqueIdentifier;}` (parses the intrabank, interbank and bill-payment `200` bodies; reused by Tasks 8, 10, 12), `CoreTransferService.transferToOwnAccount(...)`, `.withdrawToFlex(...)` returning `ServiceResponse<CoreTransferAck>`, `ownAccountTransferProvider`, `savingsWithdrawalProvider`.

- [ ] **Step 1: Write failing tests:** JSON keys exactly `toProductCode`/`amount`/`narration` (and `fromProductCode` for withdrawal); destinations exclude `bocFlex` and non-active accounts; amount above the source's `availableBalance` is blocked before review; narration over 100 chars is blocked; accepted shows "Submitted" with the reference and reloads accounts; unknown shows "We couldn't confirm this transfer. Check your balance before trying again." with no Submit.
- [ ] **Step 2–4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Register** `ownAccountTransfers` and `savingsWithdrawals` (operations + G2 done); update `transaction_availability_test.dart` expectations.
- [ ] **Step 6: Commit** `feat(core): move money between own accounts`.

### Task 8: Send to another BOCTRUST account (requires G6)

**Files:** Modify `core_transfer_service.dart`, `intrabank_submission_providers.dart`, `transaction_flow_screens.dart` (route `sendBeneficiary` renamed in copy to "To a BOCTRUST account"); Test `test/intrabank_boctrust_transfer_test.dart`.

**Interfaces — Produces:** `BoctrustTransferDraft {toAccountNumber (10 digits), amountKobo, narration?}`, `CoreTransferService.transferToBoctrust(...)`, `boctrustTransferProvider`.

- [ ] **Step 1: Write failing tests:** non-10-digit account blocked; the caller's own account numbers are rejected; review shows the masked number (`•••• 7777`) and the G6-approved irreversibility copy; one POST per authorization.
- [ ] **Step 2–4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Register** `boctrustTransfers`; commit `feat(core): send to BOCTRUST accounts`.

### Task 9: Interbank directory and bound name enquiry (requires G3)

**Files:** Create `lib/module/core_banking/model/interbank_models.dart`, `lib/module/core_banking/provider/interbank_bank_directory_provider.dart`, `lib/module/core_banking/provider/interbank_recipient_draft_provider.dart`; Modify `core_transfer_service.dart`, `transaction_flow_screens.dart`; Test `test/interbank_recipient_test.dart` (fixtures in `test/fixtures/core/interbank_*.json` from G3).

**Interfaces — Produces:** `CommercialBank {code, id, name}`, `ResolvedRecipient {bankCode, accountNumber, name}` (BVN/KYC dropped at parse), `interbankBankDirectoryProvider`, `interbankRecipientDraftProvider` with `selectBank`, `setAccountNumber`, `resolve()`.

- [ ] **Step 1: Write failing tests** from the G3 fixtures: list parses and dedupes by code; enquiry result keeps only `name`; changing bank or any digit clears the resolution; a late enquiry for an old fingerprint is discarded; repeated Check taps send one request.
- [ ] **Step 2–4:** Run (FAIL), implement (searchable bank list, explicit "Check account" action), run (PASS).
- [ ] **Step 5: Commit** `feat(core): resolve interbank recipients`.

### Task 10: Interbank transfer and status

**Files:** Create `lib/module/core_banking/provider/interbank_transfer_providers.dart`; Modify `core_transfer_service.dart`, `transaction_flow_screens.dart`, `feature_capability.dart`, `private_user_state.dart`; Test `test/interbank_transfer_test.dart`.

**Interfaces — Consumes:** Task 9 `ResolvedRecipient`. **Produces:** `interbankTransferProvider`, `interbankTransferStatusProvider(String reference)` (family; GET only), `InterbankTransferStatus {reference, status: pending|completed|failed|unknown, message?}`.

- [ ] **Step 1: Write failing tests:** request keys `receiverBankCode`/`receiverAccountNumber`/`amount`/`narration` from the resolved draft only; accepted navigates to a status panel keyed by reference; `completed` shows Completed and reloads accounts; `pending` offers Refresh (GET only); `failed` is terminal; `500` shows "We couldn't verify the receiving account"; status for a missing reference is never requested.
- [ ] **Step 2–4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Register** `interbankTransfers` and `FeatureCapability.transfers`; commit `feat(core): send to other banks and track status`.

## Phase D: Bills, airtime and data

### Task 11: Bill catalogues (requires G3, G5)

**Files:** Create `lib/module/core_banking/model/bill_catalogue_models.dart`, `lib/module/core_banking/service/core_bill_service.dart`, `lib/module/core_banking/provider/bill_catalogue_providers.dart`; Modify `lib/module/payments/screens/payments_screens.dart`, `lib/app/route_arguments.dart`; Test `test/bill_catalogue_test.dart`.

**Interfaces — Produces:** `BillerCategory {id, name, description, isAirtime}`, `Biller {billerId (String), categoryId, name, shortName, currencyCode, customerFieldLabel?, isActive}`, `PaymentItem {id, code, billerId, name, amountNaira? }` (null until G5), providers `billerCategoriesProvider`, `billersProvider`, `paymentItemsProvider`; `AppRouteArguments.billerId`, `.paymentItemId`.

- [ ] **Step 1: Write failing tests** from G3 fixtures: integer `billerId` becomes a string; inactive billers hidden; items filtered by exact `billerId`; Airtime/Data split follows the G5 rule only; `customerField1` drives the customer-ID label with "Customer ID" fallback; static grid replaced by server categories with local icons and a generic fallback.
- [ ] **Step 2–4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Register** `billerDirectoryView`; commit `feat(core): show live bill catalogues`.

### Task 12: Airtime, data and bill payment

**Files:** Create `lib/module/core_banking/model/bill_payment_models.dart`, `lib/module/core_banking/provider/bill_payment_provider.dart`; Modify `core_bill_service.dart`, `payments_screens.dart`, `feature_capability.dart`, `private_user_state.dart`; Test `test/bill_payment_test.dart`.

**Interfaces — Consumes:** Tasks 5, 11. **Produces:** `BillPaymentDraft {billerId, paymentItemId, customerId, amountNaira}`; `billPaymentProvider`; one flow with variants `airtime` (recipient phone as `customerId`), `data` (fixed package amount), `bill` (fixed or variable amount per item).

- [ ] **Step 1: Write failing tests:** JSON has exactly `billerId`, `paymentItemId`, `customerId`, `amount` (Naira, `'100.00'`) — no names, email or phone; changing biller/item/customer ID/amount clears review; `404` shows "This biller or plan is no longer available"; accepted shows "Payment submitted" plus reference (or "Paid" only once G4 defines success); unknown never re-enables Pay.
- [ ] **Step 2–4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Register** `airtimePurchase`, `dataPurchase`, `billPayment` (and existing `airtime`, `data`, `bills`); commit `feat(core): pay bills, airtime and data`.

## Phase E: Beneficiaries and Scan to pay

### Task 13: Beneficiaries

**Files:** Create `lib/module/core_banking/model/beneficiary_models.dart`, `lib/module/core_banking/service/core_beneficiary_service.dart`, `lib/module/core_banking/provider/beneficiary_providers.dart`; Modify the `manageBeneficiaries` screen, Send recipient step (Task 9/10), bill customer-ID step (Task 12), `feature_capability.dart`, `private_user_state.dart`; Test `test/beneficiaries_test.dart`.

**Interfaces — Produces:** `enum BeneficiaryType { bankAccount('bank_account'), electricity, water, cableTv('cable_tv'), internet, betting }`; `Beneficiary {id, type, nickname?, number, name, bankCode?, bankName?, billerId?, billerCategoryId?, billerCategoryName?, paymentItemId?, paymentItemName?, createdAt}`; `beneficiariesProvider(BeneficiaryType?)`; `addBankBeneficiary(bankCode, number, nickname?)`, `addBillBeneficiary(...)`, `deleteBeneficiary(id)`.

- [ ] **Step 1: Write failing tests:** list filter sends `?type=bank_account`; bank add sends exactly `type`/`bankCode`/`number`/`nickname`; bill add sends the eight required keys; `409` shows "Already saved"; delete removes the row only after `200`; choosing a bank beneficiary fills the recipient draft and still requires name enquiry (Task 9) before amount; numbers display masked.
- [ ] **Step 2–4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Register** `beneficiaries` and `beneficiariesManage`; commit `feat(core): save and reuse beneficiaries`.

### Task 14: Snap/Scan to pay prefill (requires G7)

> **Resolved 7 October 2026 (Kenechukwu): snap-to-pay with `image_picker`.** Implemented by [account activity and snap-to-pay](2026-10-07-core-account-activity-and-snap-to-pay.md); bill customer-ID fill stays deferred with bills.

**Files:** Create `lib/module/core_banking/service/core_ocr_service.dart`, `lib/module/payments/screens/scan_to_pay_screen.dart`; Modify the recipient and customer-ID fields (Tasks 9, 12) to add "Scan number"; `pubspec.yaml` only if G7 approves `image_picker`; Test `test/scan_to_pay_test.dart`.

**Interfaces — Produces:** `CoreOcrService.readNumber(Uint8List imageBytes) -> Future<NotifierState<String>>` (base64 without prefix; rejects > 8 MB before upload).

- [ ] **Step 1: Write failing tests:** body is `{'image': base64}` with no `data:` prefix; a 9 MB file is rejected locally; `400` shows "No number found — try a clearer photo"; the result only fills the field (never submits) and is re-validated by that field's rules.
- [ ] **Step 2–4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Register** `scanToPay`; commit `feat(core): fill account and meter numbers from a photo`.

## Phase F: Rest of the integration

### Task 15: Close the open KYC items

**Files:** Modify `lib/module/kyc/service/dojah_web_policy.dart`, `lib/module/kyc/screens/kyc_screens.dart`; Test `test/dojah_web_policy_test.dart`.

- [ ] **Step 1 (human checkpoint):** Run one government-ID passport capture with the debug log; record the `[DojahWebView] main-frame finish:` host.
- [ ] **Step 2:** If the host is `*.dojah.services`, write a failing test that `decideDojahNavigation('https://liveness.dojah.services/x')` returns `allow`, then extend `_isTrustedDojahPage` to `dojah.io` and `dojah.services`; if it is the widget's configured redirect, record that the early close is by design.
- [ ] **Step 3 (human checkpoint):** With the backend, confirm whether utility-bill `residentialState`, `residentialLga` and meter fields are required for review or the Core `city` sync; if required, add validators and a failing-then-passing widget test.
- [ ] **Step 4:** Raise the Dojah SDK body logging (selfie base64 in `I/OkHttp`) with Dojah; record the response.
- [ ] **Step 5: Commit** `fix(kyc): keep Dojah capture open across its own domains`.

### Task 16 (human checkpoint): Backend fixes to track

Record owner and status for each in `docs/verification/core-banking-integration.md`; no app code:
- `GET /users/me/home` → `500 DATABASE_ERROR` for every user (blocks funding account / Add money).
- Private KYC S3 bucket not configured (blocks Tier 3 utility bill).
- Notification service URL not configured (welcome email skipped).
- Tier 3 approval → Core `PUT /customers` (address, `city`) and `PUT /accounts/tier` (`skipAddressVerification` value).

### Task 17: Release readiness and verification

**Files:** Modify `docs/verification/core-banking-integration.md`, `docs/superpowers/execution/2026-10-02-kyc-core-execution-log.md`, `README.md`.

- [ ] **Step 1:** `flutter doctor --android-licenses` (human), then `flutter build appbundle --release --dart-define-from-file=.env.stage` — expect no "failed to strip debug symbols" message.
- [ ] **Step 2:** `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --no-pub` — all clean.
- [ ] **Step 3 (human checkpoint):** Device matrix on Android and iOS for each registered capability: happy path, rejected (`403`/`404`), timeout (airplane mode mid-submit → Unknown, no duplicate), logout clears drafts, 320 px / 200 % text / dark mode / screen reader.
- [ ] **Step 4:** Update the README capability table and the execution log; commit `docs(core): record mobile banking integration readiness`.

## Execution Order

1. Task 2 (no gates) → Task 4 → Task 5 (foundation) — can start immediately.
2. Task 1 → Task 3 as soon as G1 is answered (unblocks all device verification).
3. Task 15 Step 1–2 and Task 17 Step 1 in parallel (device/toolchain only).
4. G2 → Task 6 → Task 7 → Task 8 (G6).
5. G3 → Task 9 → Task 10; G3 + G5 → Task 11 → Task 12.
6. Task 13 after Tasks 9 and 12; Task 14 after G7.
7. Task 16 tracked throughout; Task 17 last.

Each phase is a releasable increment: an unregistered capability ships as an honest "unavailable" state.
