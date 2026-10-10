# Staged customer transfers: verification

Date: 10 October 2026. Branch `feat/core-account-history`. Plan: [staged customer transfers](../superpowers/plans/2026-10-10-staged-customer-transfers.md). Core Swagger init SHA-256 `ab5f1bf9…`.

## What shipped (staging only)

- **Other bank** (`interbankTransfers`): registered, staging-only. Production stays unavailable.
- **BOCTRUST** (`boctrustTransfers`): registered, staging-only. It reuses the other-bank screen with Boctrust MFB preselected (matched by name in `/me/interbank/banks`) and the customer `/me/interbank/name-enquiry`, but moves money through `/me/intrabank/transfers/initiate` → finalize. The back-office `/accounts/{n}/enquiry` is no longer called; scan-to-pay uses the same lookup. Boctrust is removed from the other-bank list.
- **Flow:** review → `POST …/initiate` (no PIN) → PIN sheet → OTP page only when `requiredChecks` includes `otp` (it calls `…/{reference}/otp/request`) → one `POST …/{reference}/finalize` → result, with live requery by the final `retrievalReference` / `transactionReference`.
- **Safety rules:**
  - A `liveness` check, an unknown check, or an expired initiation is refused before finalize. `livenessVerified` is never sent.
  - Finalize is sent once per credential entry. A 401 lets the customer re-enter the PIN on the same unexpired initiation.
  - An unknown outcome (timeout or an undocumented 5xx) stays open until the customer sets it aside. The documented interbank 500 is a definite failure.
  - The PIN and OTP never enter provider state, model fields or logs. Initiate, OTP request, status and requery are logged in full on staging for support. Finalize (PIN and OTP) and the name enquiry (Core can return the recipient's BVN) stay redacted to their path template. The staging-only parse-error log still prints the real request path.
- **Amount (updated 10 October):** both initiate routes send integer Kobo as a digit-only string (₦1,650.00 → `165000`), as the Swagger documents. Staging rejected the earlier naira `1650.00`: "amount with value 1650.00 fails to match the required pattern: /^\d+$/". Amounts over ₦25,000,000 are refused before sending.
- **Recipient lookup:** runs automatically at 10 digits (and once a bank is chosen). Any edit cancels the lookup in flight and clears the name. "Check account" remains as a retry.

## Commands

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1537 passed, 1 failed (`platform_branding_config_test`, from uncommitted iOS project changes outside this branch; failing at baseline).

## Staging checks before relying on either flow

- [ ] **Amount unit:** send ₦10.00 through each flow and confirm BocFlex is debited exactly ₦10.00, not ₦0.10 or ₦1,000. Both payloads now match Swagger's integer-Kobo format.
- [ ] **Checks:** a PIN-only amount and an OTP-required amount, with the OTP delivered and accepted; an expired initiation is refused.
- [ ] **Errors:** wrong PIN then the correct PIN on the same initiation; 403 restriction (including Core's tier lag), 404, both 409 meanings, and the interbank 500 body.
- [ ] **Uncertain finalize:** lose the finalize response (airplane mode after sending) and confirm requery or status recovers it; check whether interbank status accepts the initiation reference.
- [ ] **BOCTRUST:** confirm `/me/interbank/name-enquiry` resolves Boctrust accounts with Boctrust MFB's code, and that the bank list has exactly one entry whose name contains "Boctrust".
- [ ] **First staging attempt (10 October):** sending ₦1,000 to a Boctrust account through the other-bank route returned 400 on initiate. Core's reason is hidden by log redaction. Either that route refuses Boctrust or it rejects the naira amount; retry through the BOCTRUST flow to tell which.
- [ ] **Recovery after restart:** an unknown outcome lives only in memory. After an app restart nothing stops the customer sending the same transfer again (Core's 409 covers only 60 seconds). Record the backend recovery path before relying on either flow.
- [ ] **Status semantics:** when `responseCode` `00`, `status` and requery mean completed versus pending.
- [ ] **Logs:** confirm no recipient, reference, PIN or OTP appears in staging logs.
