# Core staged check migration: verification

Date: 10 October 2026. Branch `feat/core-staged-verification`. Plan: [staged verification migration](../superpowers/plans/2026-10-10-core-staged-verification-migration.md). Core Swagger init SHA-256 `4c143b37…` (rechecked before coding; unchanged) — the single source of truth.

## What changed (staging only)

- **Transfers (BOCTRUST and other bank):** initiate → `POST {reference}/pin/verify` `{transactionPin}` (Core sends the OTP when one is required) → `POST {reference}/otp/verify` `{otpCode}` only when an OTP is required → one `POST {reference}/finalize` with **no body**. `otp/resend` is an explicit button after the PIN passes. The retired `/otp/request` and liveness routes are never called.
  - A wrong PIN or OTP (401) stays on its sheet. A 409 "already completed" on a verify step advances. A reply whose `pendingChecks` still lists a finished step, or lists liveness, stops the transfer before finalize.
  - The staging `otpCode` in PIN-verify and resend replies is dropped by the parser and never shown.
  - Finalize outcomes follow the Swagger: 403 restricted/expired and 422 bank decline (with Core's reason) are definite; 409 and 500 are unknown — never "no money left", never retried.
- **Transaction limits:** "Change limits" appears on the limits screen only under the new staging-only `transactionLimitsEdit`; viewing still needs only the GET. Only changed limits are sent, never above the tier maximum; the change goes through the same PIN → OTP → bodyless finalize, then the limits are re-read. Limit inputs are sent in **Kobo** (the only unit the Swagger documents on this resource).
- **Logging:** transfer and limit requests and replies are logged in full on staging by product decision; the logger still masks `transactionPin`, and the name enquiry stays redacted (recipient BVN). The customer's OTP and the staging `otpCode` appear in staging logs.

## Commands

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1557 passed, 1 failed — `platform_branding_config_test` "signs the Runner target with the push entitlement": the Debug configuration signs with the empty `RunnerDebug.entitlements` (commit `f5582fd`); decision pending.

## Staging checks before release

- [ ] PIN-only and PIN+OTP transfers on both routes: OTP arrives after PIN verify; resend works; wrong and expired codes; real `completedChecks`/`pendingChecks` after each step.
- [ ] ₦10.00 through each route debits exactly ₦10.00.
- [ ] Finalize 200, 409, 422 and 500, and a lost finalize reply: does requery or interbank status (with which reference?) recover it, and how does BOCTRUST recover without a `retrievalReference`?
- [ ] Limit change: the accepted input unit, and that the GET afterwards shows the intended custom/effective values; a lost finalize reply.
- [ ] Logs: the PIN is masked; production builds redact by key as before.
