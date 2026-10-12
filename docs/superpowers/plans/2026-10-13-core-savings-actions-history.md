# Savings Actions and Payments History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn on, in staging, the five features whose Core endpoints exist but have no app code: Payments transaction history, plan top-up, early withdrawal, and SmartSave and Fixed Deposit creation.

**Architecture:** Each feature gets its endpoint constant, its typed models, a service method, a provider and its screen wiring. Its `FeatureCapability` is then registered `stagingOnly` with exactly the operations it calls. All money moves through `CoreSavingsPlanService`. After a move, the screens re-read `savingsPlansProvider` and `savingsPlanDetailProvider`, never adjusting balances locally. Payments history reuses Task 4's account history reader for the active Flex account.

**Tech Stack:** Flutter, Riverpod, Dio `ApiService`, `NotifierState`, flutter_test.

**Spec:** [Live Core Swagger](https://core-dev-api.centurysoftware.dev/api/v1/docs/), swagger-ui-init SHA-256 `f54d3ae9…` (rechecked 13 October 2026). It is the single source of truth.
- `POST /me/savings-plans`:
  - Required: `productCode`, `tenorDays`. Optional: `planName`, `targetAmount` (Naira, required for target savings), `saveFrequency` (`daily|weekly|monthly`, target savings only), `recurringAmount` (Naira, target savings only).
  - Core creates the plan and funds it from BocFlex with the product's minimum for that tenor.
  - Replies: 200 returns a plan summary including `planId`. 400 covers validation, no rate for this tenor, and insufficient BocFlex balance.
- `POST /me/savings-plans/{planId}/fund`:
  - Body `{amount}` (Naira).
  - Replies: 200 `SavingsPlanActionResult`. 403 means the plan is matured, liquidated or cancelled. 404 means it is not the caller's.
- `POST /me/savings-plans/{planId}/liquidate`:
  - No body.
  - Replies: 200 `SavingsPlanActionResult`, which carries `amountPaidOut`, `interestAccrued`, `earlyWithdrawalFee`, `interestPaid` and `interestPending`, all Naira. 403 means the plan is already matured, liquidated or cancelled. 404 means it is not the caller's.
- None of the three takes a PIN or OTP.
- `GET /me/bank-accounts/{accountNumber}/transactions` is already implemented in `CoreAccountService.getAccountTransactions`.

## Global Constraints

- Swagger `f54d3ae9…` is the source of truth. Re-fetch it before staging; if the hash differs, re-diff before continuing.
- All amounts are Naira decimal strings, read with `coreNaira`. Typed amounts are parsed with `parseNairaToKobo` and sent as `koboToNaira(kobo)`.
- Every new capability is `stagingOnly: true`. Every new POST path is added to `CoreApiEndpoints.moneyMoving`, so the existing "money-moving Core operations are staging-only" test covers it.
- Logs are kept in full on staging. Do not add `privacySensitivePathKey`.
- Amount fields use `ThousandsAmountFormatter`.
- Tests are minimal and strictly necessary: only the ones named here.
- Do not retry a money-moving POST. If the reply is unknown (no response or 5xx), say the outcome is unknown and re-read the plans; never say "no money moved".
- Out of scope: Padi, plan edit, Flex top-up and withdraw, receipts.

## Review Focus

1. A lost reply or a 5xx on fund, liquidate or create leaves the money state unknown. The customer should be told to check their plans, and the plans should be re-read. Nothing should be resent.
2. The wizard offers 3, 6, 9 and 12 months, but Core only accepts tenors that match a rate band. A 400 "no rate for this tenor" should show Core's reason on the confirm step and keep the draft.
3. A double tap on Confirm or Withdraw must send only one request.
4. When a move succeeds, the plan detail, the plans list and the Flex balance should all show the new figures without a manual refresh.
5. Without a Flex account, Payments history should say there is no account, not show an error.

---

### Task 1: Payments history from the Flex account

**Files:**
- Modify: `lib/app/feature_capability.dart` (register `transactionHistory`).
- Modify: `lib/module/core_banking/screens/bank_account_detail_screen.dart`: extract `_history` and `_historyRow` into a public `CoreAccountHistoryList`.
- Create: `lib/module/core_banking/screens/core_account_history_list.dart`.
- Modify: `lib/module/send/screens/transaction_flow_screens.dart` (`_transactionHistoryScreen`) and `lib/module/send/screens/send_screens.dart`.
- Test: `test/feature_capability_test.dart`, and create `test/payments_history_test.dart`.

**Interfaces:**
- Consumes: `coreAccountHistoryProvider`, `PagedRowsFooter`, `customerBankAccountsProvider` (`.data?.activeFlexAccount?.accountNumber`).
- Produces: `class CoreAccountHistoryList extends ConsumerStatefulWidget { const CoreAccountHistoryList({required String accountNumber}) }`. It holds the range chips, rows and footer exactly as the account screen shows them today. It is a widget for a ListView's children, so it has no scroll of its own.
- `FeatureCapability.transactionHistory`: `stagingOnly`, operations `{GET bankAccounts, GET bankAccountTransactionsTemplate}`.

- [ ] **Step 1: Write the failing tests**
  - `feature_capability_test.dart`: add `FeatureCapability.transactionHistory` to the staging slices list.
  - `payments_history_test.dart` › `payments history lists the Flex account's transactions`:
    - The Flex account is `'1100919408'`, with one row: credit `'5000.00'` "SALARY".
    - Open `AppRoutes.transactionHistory` and expect the texts `'SALARY'` and `'+₦5,000.00'`.
  - `payments_history_test.dart` › `payments history without a Flex account says so`: expect `'You have no Boc Flex account yet.'`.
- [ ] **Step 2: Run** `flutter test --no-pub test/payments_history_test.dart test/feature_capability_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
  - Move the account screen's history UI into `CoreAccountHistoryList`. The account screen keeps its pull-to-refresh by reading the same provider key. The list owns `_range` and exposes nothing else.
  - The Payments history screen is gated on `transactionHistory`:
    - It calls `ensureLoaded()` on `customerBankAccountsProvider`.
    - With a Flex account number, it shows `CoreAccountHistoryList` inside the existing scaffold. Without one, it shows an info `ApiStateCard` with the copy above. While accounts load, it shows `ApiLoadingSection`.
  - Delete `transactionHistoryProvider` and its stub notifier only if nothing else reads them. Otherwise leave them.
- [ ] **Step 4: Run** the Step 2 command and `flutter test --no-pub test/bank_account_detail_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(payments): show Flex transactions in Payments history`.

### Task 2: Plan action result and top-up

**Files:**
- Modify: `lib/app/core_api_endpoints.dart`, `lib/app/feature_capability.dart`, `lib/module/savings/model/savings_plan_models.dart`, `lib/module/savings/service/core_savings_plan_service.dart`, `lib/module/savings/screens/savings_plan_screens.dart` (Deposit button).
- Create: `lib/module/savings/provider/savings_plan_action_provider.dart`.
- Test: `test/core_savings_plan_test.dart`, `test/savings_plans_ui_test.dart`, `test/feature_capability_test.dart`.

**Interfaces:**
- Produces:
  - `CoreApiEndpoints.savingsPlanFund(String planId)`, `savingsPlanFundTemplate = '$savingsPlanTemplate/fund'`. Add the template to `moneyMoving`.
  - `class SavingsPlanActionResult extends Equatable { planId, status (SavingsPlanStatus), principalAmount, amountPaidOut, interestAccrued, earlyWithdrawalFee, interestPaid, interestPending; static SavingsPlanActionResult? fromJson(Object?) }`. Amounts go through `coreNaira`. It is null when `planId` is missing.
  - `CoreSavingsPlanService.fundPlan(String planId, String amountNaira) -> Future<NotifierState<SavingsPlanActionResult>>`.
  - `enum SavingsPlanActionPhase { idle, sending, done, failed, unknown }`.
  - `final savingsPlanActionProvider = NotifierProvider.autoDispose<SavingsPlanActionNotifier, SavingsPlanActionState>`, where `SavingsPlanActionState { phase, result, message }` and the notifier has `Future<void> fund(String planId, String amountNaira)`.
    - The provider ignores calls while `sending`.
    - On `done`, it invalidates `savingsPlansProvider` and `savingsPlanDetailProvider(planId)` and refreshes `customerBankAccountsProvider`.
    - No response or 5xx → `unknown`. Every other failure → `failed` with Core's message.
  - `FeatureCapability.savingsPlanDeposit`: `stagingOnly`, operations `{POST savingsPlanFundTemplate}`.

- [ ] **Step 1: Write the failing tests**
  - `core_savings_plan_test.dart` › `funding sends Naira to the encoded plan`: `fundPlan('p/1', '2500.00')` → POST `/me/savings-plans/p%2F1/fund`, body `{'amount': '2500.00'}`. The reply `{planId:'p/1', status:'active', principalAmount:'7500.00'}` gives `principalAmount == '7500.00'`.
  - `savings_plans_ui_test.dart` › `depositing into a plan sends the typed amount`:
    - Make `savingsPlanDeposit` available, then tap `'Deposit'`.
    - Enter `'2,500'`, then tap `'Add money'`.
    - The fake records `('p1', '2500.00')`, and the text `'Money added'` shows.
  - `feature_capability_test.dart`: add `savingsPlanDeposit` to the staging slices.
- [ ] **Step 2: Run** `flutter test --no-pub test/core_savings_plan_test.dart test/savings_plans_ui_test.dart test/feature_capability_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
  - "Deposit" opens an `AppActionSheet`:
    - Title `'Add money to <plan name>'`, an amount `AppTextField` with `ThousandsAmountFormatter`, a note `'From Boc Flex Savings'`, a primary `'Add money'` and `'Cancel'`.
    - Parse with `parseNairaToKobo(maxKobo: <a large bound, e.g. '100000000000'>)` and show its error inline.
  - Outcomes:
    - `done`: show a success sheet titled `'Money added'` with the new principal.
    - `failed`: keep the sheet open and show Core's message.
    - `unknown`: show `"We couldn't confirm this. Check your plan before trying again."` and invalidate the providers.
- [ ] **Step 4: Run** the Step 2 command → PASS.
- [ ] **Step 5: Commit** `feat(savings): add money to a savings plan`.

### Task 3: Early withdrawal

**Files:**
- Modify: `lib/app/core_api_endpoints.dart`, `lib/app/feature_capability.dart`, `lib/module/savings/service/core_savings_plan_service.dart`, `lib/module/savings/provider/savings_plan_action_provider.dart`, `lib/module/savings/screens/savings_plan_screens.dart` (`_withdrawFromPlan`).
- Test: `test/core_savings_plan_test.dart`, `test/savings_plans_ui_test.dart`, `test/feature_capability_test.dart`.

**Interfaces:**
- Consumes: Task 2's `SavingsPlanActionResult`, `savingsPlanActionProvider` and phases.
- Produces:
  - `CoreApiEndpoints.savingsPlanLiquidate(String planId)`, `savingsPlanLiquidateTemplate`. Add it to `moneyMoving`.
  - `CoreSavingsPlanService.liquidatePlan(String planId)` → POST with no body.
  - `SavingsPlanActionNotifier.liquidate(String planId)`, with the same rules as `fund`.
  - `FeatureCapability.savingsPlanWithdraw`: `stagingOnly`, operations `{POST savingsPlanLiquidateTemplate}`.

- [ ] **Step 1: Write the failing tests**
  - `core_savings_plan_test.dart` › `liquidation sends no body and reads the payout`:
    - POST `/me/savings-plans/p1/liquidate` with `data == null`.
    - The reply `{planId:'p1', status:'liquidated', amountPaidOut:'5117.40', interestAccrued:'120.40', earlyWithdrawalFee:'3.01', interestPaid:'117.39', interestPending:'0.00'}` maps to those fields.
  - `savings_plans_ui_test.dart` › `withdrawing early shows what was paid`:
    - Confirm `'Withdraw early'` on the existing sheet.
    - Expect the texts `'Withdrawn'`, `'₦5,117.40'` (label `'Paid to Boc Flex'`) and `'₦3.01'` (label `'Early withdrawal fee'`).
  - `feature_capability_test.dart`: add `savingsPlanWithdraw` to the staging slices.
- [ ] **Step 2: Run** the Task 2 Step 2 command → FAIL.
- [ ] **Step 3: Implement.**
  - When the existing confirm sheet returns true, call `liquidate`.
  - On `done`, show a result sheet titled `'Withdrawn'` with these rows, each only when present:
    - `'Paid to Boc Flex'` (`amountPaidOut`)
    - `'Interest earned'` (`interestAccrued`)
    - `'Early withdrawal fee'` (`earlyWithdrawalFee`)
    - `'Interest still to come'` (`interestPending`, only when it is not `0.00`)
  - Then return to the plans list.
  - `failed` and `unknown` behave as in Task 2. A 403 shows `'This plan can no longer be withdrawn.'`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(savings): withdraw a savings plan early`.

### Task 4: Create SmartSave and Fixed Deposit plans

**Files:**
- Modify: `lib/app/feature_capability.dart`, `lib/app/core_api_endpoints.dart` (add `savingsPlans` to `moneyMoving` for POST), `lib/module/savings/model/savings_plan_models.dart`, `lib/module/savings/service/core_savings_plan_service.dart`, `lib/module/savings/provider/savings_plan_action_provider.dart`, `lib/module/savings/screens/savings_plan_screens.dart` (the wizard).
- Test: `test/core_savings_plan_test.dart`, `test/savings_plans_ui_test.dart`, `test/feature_capability_test.dart`.

**Interfaces:**
- Produces:
  - `const tenorDaysForMonths = {3: 90, 6: 180, 9: 270, 12: 365};`
  - `class CreateSavingsPlanRequest extends Equatable { productCode, tenorDays, planName?, targetAmount?, saveFrequency?, recurringAmount?; Map<String, Object> toJson() }`. It omits null fields.
  - `CreateSavingsPlanRequest? SavingsPlanDraft.toCreateRequest()`. It returns null for Flex, Padi, a missing tenor, or an unparseable amount.
  - `SavingsPlanDraft` gains `String recurringAmount = ''`.
  - `CoreSavingsPlanService.createPlan(CreateSavingsPlanRequest) -> Future<NotifierState<String>>`, which returns the new `planId`.
  - `SavingsPlanActionNotifier.create(CreateSavingsPlanRequest)`, with the result's `planId`.
  - `FeatureCapability.smartSaveCreate` and `fixedDepositCreate`: `stagingOnly`, operations `{POST savingsPlans}`.

- [ ] **Step 1: Write the failing tests**
  - `core_savings_plan_test.dart` › `a SmartSave draft becomes Core's create request`:
    - Draft: type smartSave, name `'Rent'`, amount `'200,000'`, `durationMonths: 6`, `autoSave: true`, `frequency: weekly`, `recurringAmount: '5,000'`.
    - Expected `toJson()`: `{'productCode':'bocSmartSave','tenorDays':180,'planName':'Rent','targetAmount':'200000.00','saveFrequency':'weekly','recurringAmount':'5000.00'}`.
  - `core_savings_plan_test.dart` › `a Fixed Deposit draft sends only its term and name`: type fixed, name `''`, `durationMonths: 3` → `{'productCode':'boctrustFixedDeposit','tenorDays':90}`.
  - `savings_plans_ui_test.dart` › `creating a goal opens the new plan`:
    - Walk the SmartSave wizard and tap `'Create goal'`.
    - The fake returns `'p9'`, and the plan detail for `p9` opens.
  - `savings_plans_ui_test.dart` › `a term Core does not offer keeps the draft`: the fake fails 400 `'No rate for this tenor.'` → that text shows, and `'Create goal'` is still on screen.
  - `feature_capability_test.dart`: add both create capabilities to the staging slices.
- [ ] **Step 2: Run** the Task 2 Step 2 command → FAIL.
- [ ] **Step 3: Implement.**
  - **Steps for these two products:** they drop `_WizardStep.funding`, because Core always funds from BocFlex.
  - **Fixed Deposit:** drops `_WizardStep.amount`, because Core funds the minimum for the term. Its steps become `[schedule, confirm]` with an optional name on confirm.
  - **SmartSave auto-save:** the days step gains an `'Amount each time'` field (`ThousandsAmountFormatter`) and the frequency chips. `contributionDays` is not sent, since Core has no such field. Keep the chips only if removing them breaks other types; otherwise remove them for SmartSave.
  - **Confirm step:**
    - Shows `'Funded from Boc Flex Savings'` and `'We'll move the minimum for this term from Boc Flex Savings now.'`.
    - The button is `'Create goal'` for SmartSave and `'Create deposit'` for Fixed.
    - On `done`, it goes to `AppRoutes.savingsPlanDetail` with `entityId: planId`.
    - On `failed`, it shows Core's message under the button and keeps the draft.
    - On `unknown`, it shows the Task 2 unknown copy and invalidates the plans.
- [ ] **Step 4: Run** → PASS, then run `flutter analyze` → no issues.
- [ ] **Step 5: Commit** `feat(savings): create SmartSave and Fixed Deposit plans`.

### Task 5: Verification

**Files:** Create `docs/verification/2026-10-13-core-savings-actions-history.md` (commit with `git add -f`).

- [ ] **Step 1:** Run `flutter analyze` and `flutter test --no-pub`. Expected: no issues. Any failure is named; the known `platform_branding_config_test` push-entitlement failure is pre-existing.
- [ ] **Step 2:** Write the note. It covers what shipped per task, the Swagger SHA-256, the command results, and these staging checks:
  - Which of 90/180/270/365 days each product accepts.
  - The minimum moved at creation, matched against the Flex debit.
  - Top-up of ₦100.00 moves exactly ₦100.00.
  - The liquidation payout equals principal plus interest minus the fee.
  - Payments history matches the account screen.
- [ ] **Step 3: Commit** `docs: record the savings actions and Payments history verification`.
