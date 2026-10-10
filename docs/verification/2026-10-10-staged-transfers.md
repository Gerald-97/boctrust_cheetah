# Staged customer transfers: verification

Date: 10 October 2026. Branch `feat/core-account-history`. Plan: [staged customer transfers](../superpowers/plans/2026-10-10-staged-customer-transfers.md). Core Swagger init SHA-256 `ab5f1bf9…`.

## What shipped (staging only)

- **BOCTRUST** (`boctrustTransfers`) and **other bank** (`interbankTransfers`), registered separately and staging-only. Production stays unavailable.
- **Flow:** review → `POST …/initiate` (no PIN) → PIN sheet → OTP page only when `requiredChecks` includes `otp` (it calls `…/{reference}/otp/request`) → one `POST …/{reference}/finalize` → result, with live requery by the final `retrievalReference` / `transactionReference`.
- **Safety rules:**
  - A `liveness` check, an unknown check, or an expired initiation is refused before finalize. `livenessVerified` is never sent.
  - Finalize is sent once per credential entry. A 401 lets the customer re-enter the PIN on the same unexpired initiation.
  - An unknown outcome (timeout or an undocumented 5xx) stays open until the customer sets it aside. The documented interbank 500 is a definite failure.
  - The PIN and OTP never enter provider state, model fields or logs. Every transfer request is logged by path template only.
- **Amount:** sent as a plain naira string (for example `1000.50`), converted exactly from Kobo, per the 10 October product decision. **The Swagger still says Kobo.** Amounts over ₦25,000,000 are refused before sending.
- **Recipient lookup:** runs automatically at 10 digits (and once a bank is chosen). Any edit cancels the lookup in flight and clears the name. "Check account" remains as a retry.

## Commands

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1533 passed, 1 failed (`platform_branding_config_test`, from uncommitted iOS project changes outside this branch; failing at baseline).

## Staging checks before relying on either flow

- [ ] **Amount unit:** send ₦10.00 and confirm BocFlex is debited exactly ₦10.00, not ₦0.10 or ₦1,000. Update the Swagger or the app to match.
- [ ] **Checks:** a PIN-only amount and an OTP-required amount, with the OTP delivered and accepted; an expired initiation is refused.
- [ ] **Errors:** wrong PIN then the correct PIN on the same initiation; 403 restriction (including Core's tier lag), 404, both 409 meanings, and the interbank 500 body.
- [ ] **Uncertain finalize:** lose the finalize response (airplane mode after sending) and confirm requery or status recovers it; check whether interbank status accepts the initiation reference.
- [ ] **BOCTRUST lookup authorization:** confirm a customer cannot read arbitrary accounts through `/accounts/{n}/enquiry`, or obtain a customer-scoped route.
- [ ] **Status semantics:** when `responseCode` `00`, `status` and requery mean completed versus pending.
- [ ] **Logs:** confirm no recipient, reference, PIN or OTP appears in staging logs.
