# Core account history, statements and freeze: verification

Date: 10 October 2026. Branch `feat/core-account-history`. Plan: [history, statements and freeze](../superpowers/plans/2026-10-10-core-history-statements-freeze.md). The Core API docs are the source of truth (Swagger init SHA-256 `920fbbc4…`, unchanged since 7 October).

## What shipped (staging only)

- **Log protection:** `GET /me/bank-accounts/{n}/transactions` is logged by its path template, so the account number and every row are redacted.
- **Account history:** the account detail page calls the history route for the last 30 days under the new staging-only `coreAccountHistory` capability. `coreAccountActivity` still covers only the summary.
  - Shows loading, error with retry, "No transactions in this period.", or "You have activity in this period. Details aren't available in the app yet."
  - No row field is shown. The docs pass BankOne items through unmapped and note that every sandbox account has returned an empty history.
  - Results are keyed by account and re-read on session change, so they never show for another account or customer.
- The general history page (`transactionHistory`) stays unavailable.

## Commands

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1499 passed, 1 failed. The failure (`platform_branding_config_test`, push entitlement) comes from uncommitted iOS project changes outside this branch and also failed before it.

## Blocked

- [ ] History rows: a staging account with real postings, a sanitized nonempty reply, then row mapping and the 7/30/60-day selector.
- [ ] Statements: the documented route returns a base64 PDF and does not promise email delivery; it needs an email-delivery route and an ownership rule for mobile customers.
- [ ] Freeze/unfreeze: the `referenceId` lifecycle, customer authorization, and whether post-no-debit is the intended control.
- [ ] Staging device check of the history card on an account with and without activity.
