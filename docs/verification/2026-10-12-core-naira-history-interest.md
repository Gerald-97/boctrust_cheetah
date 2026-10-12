# Core Naira, history and interest: verification

Date: 12 October 2026. Branch `feat/core-staged-verification`. Plan: [Naira, history and interest](../superpowers/plans/2026-10-12-core-naira-history-interest.md). Core Swagger init SHA-256 `f54d3ae9…` (rechecked after the last task; unchanged) — the single source of truth.

## What shipped

1. **Naira amounts.** Every amount is read and sent as a Naira decimal string (`coreNaira`); transfer drafts send `amount` in Naira; limit edits send Naira.
2. **Early withdrawal.** Savings plans show "Interest so far" (`accruedInterest`) and the early-withdrawal fee (`earlyWithdrawalFeePercent`); the withdraw confirmation says "Withdraw early".
3. **History transport.** `GET /me/bank-accounts/{n}/transactions` sends `fromDate`/`toDate` as `YYYY-MM-DD` with `page`/`pageSize` and reads typed `CustomerAccountTransaction` rows. The request is logged in full on staging.
4. **History rows.** The account screen lists rows with "7 days / 30 days / 60 days" (default 30), signed amounts, "Reversed" on reversed rows, "Show more" without repeats, and pull-to-refresh.
5. **BocFlex interest.** The Flex screen shows the rate, this month so far and total interest earned under the staging-only `flexInterestView`; no Flex account (404) hides the card; other errors offer a retry. Amounts follow the hidden-balance setting.
6. **Daily interest history.** "Interest history" on the Flex card and on a plan's detail menu opens `/savings/interest-history`: one row per day with the interest, rate and running total, newest first, paged by "Show more". A plan that is gone says "This plan is no longer available."

## Commands

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1580 passed, 1 failed — `platform_branding_config_test` "signs the Runner target with the push entitlement": the Debug configuration signs with the empty `RunnerDebug.entitlements` (commit `f5582fd`); decision pending.

## Staging checks before release

- [ ] A ₦10.00 transfer on each route (BOCTRUST and other bank) debits exactly ₦10.00.
- [ ] Limits, plan, product and history amounts match the BankOne statement.
- [ ] A 60-day history pages correctly: no repeated or missing rows across pages.
- [ ] Flex "This month so far" matches the last `cumulativeInterest` among this month's accruals.
- [ ] A plan's accruals sum to its `accruedInterest`.
