# Core banking integration verification

Plan: `docs/superpowers/plans/2026-10-02-core-banking-transfers-bills.md`.
Execution notes: `docs/superpowers/execution/2026-10-02-kyc-core-execution-log.md`.

## Contract snapshot

- Core OpenAPI: `https://core-dev-api.centurysoftware.dev/api/v1/docs/`,
  `swagger-ui-init.js` SHA-256
  `57f5cbf244f6d4d5ea0c99122e7f263053927b7ef69416c608c7b4b0fec6bee0`
  (unchanged between plan writing and execution on 2 October 2026).
  Re-inspected later that day: SHA-256
  `f150ae0096c4429a9a1626f396f5eb35556d66ed3ad21ca13cef084815dbf0ab`. No
  endpoints were added or removed; `CustomerBillPaymentRequest` now requires
  only `billerId`, `paymentItemId`, `customerId` and `amount`, and the
  snap-to-pay OCR wording changed. See the plan's **Contract Update** section.
- `CORE_BASE_URL=https://core-dev-api.centurysoftware.dev/api`; the app appends
  `/v1`. Blank is valid and leaves every Core capability unavailable.

## Data ownership

| Data | Authority |
|---|---|
| Home wallet balance, Flex balance, owned savings accounts | Core `GET /me/bank-accounts` (active `bocFlex` account, decimal strings) |
| Savings product names/descriptions | Core `GET /bank-products` (read-only; account opening out of scope) |
| Profile, tier, KYC, dedicated virtual account (Add money) | User Service |

Core `totalAvailableBalance`, `interestRate`, `tenure` and `loanCycle` are JSON
numbers and are never displayed. There is no runtime fallback from Core to the
User Service `flexWallet` balance.

## Shipped

- Isolated Core Dio/`ApiService` (`lib/app/core_network.dart`) and
  `CoreApiEndpoints`. The same User Service bearer token is attached; a Core
  `401` never expires the User session.
- Capability metadata carries `ApiBackend.user`/`ApiBackend.core`; a Core
  capability is unavailable when `CORE_BASE_URL` is blank.
- `customerid` is redacted from logs in every environment.
- Session-scoped `customerBankAccountsProvider` and `coreBankProductsProvider`,
  cleared on logout, expiry, and session change.
- Home and Savings (hub, Flex) read balances from Core.

## Gates

- Token acceptance and `flexWallet`/`bocFlex` ledger equality: confirmed by the
  product owner on 2 October 2026; request IDs were not recorded here.
- Flex product code assumed to be `bocFlex` (the User Service code; Core
  publishes no example). A different code shows the balance as unavailable,
  never another account's balance.

## Deferred: blocked on contracts

| Slice | Endpoints | Blocker |
|---|---|---|
| Interbank directory and name enquiry | `GET /me/interbank/banks`, `POST /me/interbank/name-enquiry` | `200` responses have no attached schema; sanitized fixtures needed. |
| Bill, Airtime and Data catalogues | `GET /me/bills/billers`, `/billers/categories`, `/payment-items` | No attached schema, filter semantics, Airtime/Data rule, or string amounts. Browse-only release also needs product sign-off. |
| Own-account and interbank transfers, transfer status | `POST /me/intrabank/transfers/own`, `POST /me/interbank/transfers`, `GET …/{reference}/status` | No transaction-bound authorization, replay/idempotency rules, or status enums. |
| Airtime, Data and bill payment | `POST /me/bills/payments` | Same authorization gap; `status`/`responseCode` success values not enumerated. |

`/auth/pin/verify-current` is not transaction authorization and must not be
reused as such.

Future amount rule (for the money-moving plan): parse exact decimal text to
Kobo without floating point; cap at the lowest of the applicable tier limit,
the active `bocFlex` available balance, and signed int64 Kobo.

## Checks run

- `flutter analyze`: no issues.
- `flutter test --no-pub`: all tests pass (see the execution log for counts).
- A test pins that no capability depends on a Core money-moving operation and
  that `transfers`, `airtime`, `data`, and `bills` remain unavailable.

## Not verified

Controlled staging on physical Android and iOS: exact hosts, Core-401
isolation, logout/account-switch clearing across both hosts, Core balance and
product rendering, responsive/accessibility states, and the absence of every
money-moving request.
