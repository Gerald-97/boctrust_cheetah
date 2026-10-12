# Core savings actions and Payments history: verification

Date: 13 October 2026. Branch `feat/core-staged-verification`. Plan: [savings actions and Payments history](../superpowers/plans/2026-10-13-core-savings-actions-history.md). Core Swagger init SHA-256 `f54d3ae9…` (rechecked after the last task; unchanged) — the single source of truth. Everything below is staging-only.

## What shipped

1. **Payments history** (`transactionHistory`). The Payments tab lists the active Flex account's transactions from `GET /me/bank-accounts/{n}/transactions`, with the same range chips, rows and "Show more" as the account screen. With no Flex account it says so; a failed account load offers a retry.
2. **Plan top-up** (`savingsPlanDeposit`). "Deposit" opens an amount sheet ("Add money"), sends `POST /me/savings-plans/{planId}/fund` `{amount}` in Naira, and shows "Money added" with the new principal.
3. **Early withdrawal** (`savingsPlanWithdraw`). Confirming "Withdraw early" sends `POST /me/savings-plans/{planId}/liquidate` with no body and shows "Withdrawn": paid to Boc Flex, interest earned, early withdrawal fee, and interest still to come. A 403 says "This plan can no longer be withdrawn."
4. **Plan creation** (`smartSaveCreate`, `fixedDepositCreate`). The wizard sends `POST /me/savings-plans`:
   - Terms: 3/6/9/12 months → 90/180/270/365 `tenorDays`.
   - Funding: the funding step is gone, because Core always funds from BocFlex.
   - Fixed Deposit: it has no amount step (Core moves the term's minimum) and takes an optional name.
   - SmartSave: it sends `targetAmount`, plus `saveFrequency` and `recurringAmount` ("Amount each time") when auto-save is on.
   - Outcome: success opens the new plan, and Core's rejection reason stays on the confirm step with the draft kept.

Common rules:
- Requests are not repeatable: one request per tap, and a money-moving POST is never resent.
- No PIN or OTP is asked, because the Swagger asks for none.
- After a move, the plans, plan detail and Flex balance are re-read, even if the sheet was closed meanwhile.
- No response, a 5xx or an unreadable 2xx is "not confirmed". The app asks the customer to check their plans and never says no money moved. An unconfirmed create also closes the wizard, to avoid a duplicate plan.

## Commands

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1594 passed, 1 failed — `platform_branding_config_test` "signs the Runner target with the push entitlement": the Debug configuration signs with the empty `RunnerDebug.entitlements` (commit `f5582fd`); decision pending.

## Staging checks before release

- [ ] Which of 90/180/270/365 days each product accepts; what Core says for one it doesn't.
- [ ] The minimum moved at creation matches the Flex debit; an insufficient Flex balance shows Core's reason.
- [ ] A ₦100.00 top-up moves exactly ₦100.00 from Flex into the plan.
- [ ] A liquidation's payout equals principal plus interest minus the fee, and lands in Flex.
- [ ] Payments history matches the Flex account screen's history.
- [ ] Logs show the create, fund and liquidate requests and replies in full.
