# Core savings plans and transaction limits: verification

Date: 10 October 2026. Branch `feat/core-account-history`. Plan: [history, statements, freeze and API expansion](../superpowers/plans/2026-10-10-core-history-statements-freeze.md), Tasks 6–11. The Core API docs are the source of truth (Swagger init SHA-256 `ab5f1bf9…`).

## What shipped (staging only)

- **Savings plans** (`savingsPlansView`):
  - Target Savings and Fixed Deposit list the customer's plans from `GET /me/savings-plans?productCode=…`, with the product balance and rate.
  - A plan opens its detail and history from `GET /me/savings-plans/{planId}`. A 404 says the plan is no longer available.
  - An owned SmartSave or Fixed Deposit account on the Save hub opens its plans.
  - Every amount is read as Kobo, because every amount input on these routes is documented in Kobo and the product balance falls back to summed principal.
  - Statuses and event types are mapped as documented. An unknown value shows as unavailable.
  - Event references are not kept. Both reads are logged by path template only.
- **Transaction limits** (`transactionLimitsView`):
  - A read-only screen, reached from the tier overview, shows the effective single-transfer, daily-transfer and single-bill-payment limits from `GET /me/transaction-limits`.
  - Tier 0 (403) is sent to BVN verification instead of seeing zero limits.
  - Values are read as Kobo: the tier ceilings are documented in Kobo, and the effective values are the smaller of custom and ceiling.
- Group Savings (Padi), plan creation, deposit, withdrawal and edit stay unavailable.

## Commands

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1517 passed, 1 failed. The failure (`platform_branding_config_test`, push entitlement) comes from uncommitted iOS project changes outside this branch and failed before it.

## Staging checks before release

- [ ] Plan amounts, product balance and event amounts display correctly in Naira (confirms the Kobo reading).
- [ ] Limits display correctly for a Tier 1–3 customer, and a Tier 0 customer gets the verification prompt.
- [ ] Plan dates (`maturityDate`, event `createdAt`) show the right day.

## Backend questions (Task 6)

- [ ] **Old routes:** the four direct customer transfer routes are no longer documented (`/me/intrabank/transfers/own`, `/me/intrabank/withdrawals`, `/me/intrabank/transfers`, `/me/interbank/transfers`). Are they still callable, when do they sunset, and what replaces own-account transfers and product withdrawals?
- [ ] **Rate bands:** no customer route exposes each savings product's tenors, rates or minimum debit (`min_amount`). Plan creation stays blocked until one exists.
- [ ] **Limit units:** the unit of the limit initiate inputs (`singleTransferLimit`, `singleBillPaymentLimit`, `dailyTransferLimit`) is not documented.
- [ ] **Liveness:** `livenessVerified` is client-asserted and never re-verified by the server, so it gives no server-side protection. Transfers that require liveness stay gated until the server verifies it.
- [ ] **BOCTRUST name enquiry:** the recipient preview uses `/accounts/{n}/enquiry`, an unauthenticated back-office route. A customer-scoped intrabank name enquiry is needed.
- [ ] **409:** how can the client tell "reference in use, safe to retry" from "similar transaction in the last 60 seconds"?
- [ ] **Interbank 500:** confirm the error body of the documented finalize 500 so it can be told apart from a gateway error.
- [ ] **OTP:** delivery, resend and expiry behaviour.
- [ ] **Uncertain finalize:** how does a customer recover after an app restart when only the initiation reference is known?

## Decision needed (Task 6, security boundary)

The new finalize routes take the PIN and OTP in the Core request body, while `TransactionAuthorizer` currently denies every money-moving action and documents that credentials never enter Core bodies. Agree the authorization gate, how credentials are captured transiently, the request body, logging and unknown-outcome recovery before savings fund/liquidate (Task 8), limit updates (Task 9) or staged transfers (Task 10) are built.
