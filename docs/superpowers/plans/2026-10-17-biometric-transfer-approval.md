# Biometric transaction PIN for transfers and bill payments

**Status:** Implementation plan (revised after review).
**Scope:** BOCTrust intrabank and interbank transfers, and bill payments (including airtime and data bought through the bill flow). Manual PIN entry remains available. Core-required OTP and other checks remain in place. Transaction limits, savings movements, PIN changes, and account deletion keep their current approval flows and the unchanged shared PIN sheet.

## Decision and current integration

Use the same device-local, client-side pattern as biometric login: verify the customer's current PIN, confirm with a biometric-only device prompt, save the PIN in `flutter_secure_storage`, and erase it on the same kinds of events that erase biometric login. Transfer approval has its own versioned secure-storage keys and its own Security Center toggle. It saves the four-digit transaction PIN; it never reuses the saved login password, and the two toggles never depend on each other. Like biometric login, `biometricTransfers` is a device-local capability: no server flag gates it.

At transfer time, an enrolled, signed-in customer with the app in the foreground sees a dedicated biometric approval sheet instead of the PIN sheet. On a successful prompt, the transfer biometric provider reads the saved PIN and passes it directly to `CoreTransferAttemptNotifier.verifyPin`. Core receives `{'transactionPin': pin}` at the existing intrabank or interbank `{reference}/pin/verify` endpoint. The normal OTP step, if required, and the single finalize call follow Core's result. No new endpoint is required. The [Core API documentation](https://core-dev-api.centurysoftware.dev/api/v1/docs/) lists the [intrabank](https://core-dev-api.centurysoftware.dev/api/v1/docs/#/Customer%20Intrabank%20(Mobile)/post_api_v1_me_intrabank_transfers__reference__pin_verify) and [interbank](https://core-dev-api.centurysoftware.dev/api/v1/docs/#/Customer%20Interbank%20(Mobile)/post_api_v1_me_interbank_transfers__reference__pin_verify) PIN routes.

Enrollment verifies the PIN with the User API `POST /auth/pin/verify-current` (`AuthService.verifyCurrentPin`), which needs no active transaction. Transfers verify with Core. Both check the same transaction PIN.

**The saved PIN is written only by the Security Center toggle.** Nothing else ever creates, updates, or replaces it: not a PIN typed for a transfer, not a PIN change, not a PIN reset. A PIN change or reset instead turns the toggle off and deletes the saved PIN.

**Any failed verification of the saved PIN wipes it.** If a PIN request carrying the saved PIN fails for any reason (a wrong-PIN `401`, any other error status, a network failure, or a timeout), delete the saved PIN and turn biometric approval off before showing the result. A check that never sent the PIN (expired initiation, ended session) is not a failed verification. The customer turns it on again from Security Center.

**Accepted security tradeoff:** This matches biometric login's app-level gate. Secure storage encrypts the PIN at rest, but the stored value is not cryptographically bound to a successful `local_auth` prompt. Core verifies the PIN, not the biometric. Keep the PIN out of provider state, logs, analytics, crash reports, and UI. Never store it in general preferences or share its keys with biometric login. Hardware-bound keys that the OS releases only after a biometric match would close this gap; they need a different storage plugin and would apply to biometric login too, so they are out of scope here.

**Stale saved PIN (PIN changed elsewhere):** no pre-check. Verifying the saved PIN with `verify-current` before every biometric transfer was considered and rejected: it either reads the PIN before the biometric prompt (weakening the gate) or, if run after it, costs the same wrong-PIN attempt and adds a request without changing the outcome. Core's own PIN verification is the check: on failure the PIN is wiped, biometric approval turns off, and the PIN sheet opens immediately for the same attempt (see Task 5). At most one wrong-PIN attempt is spent per stale enrollment.

**Bill payments** send the PIN inside the single money-moving `POST /me/bills/payments`; there is no separate PIN step. Its Swagger lists no `401`: a wrong PIN arrives as an undifferentiated rejection. So a bill paid with the saved PIN wipes it on every outcome except success, a detected insufficient balance (`CoreRejection.insufficientFunds`, not a PIN problem), and a request that was never sent (`ServiceStatus.blocked`). After a definite rejection that wiped it, the PIN sheet opens immediately for the same bill; after an unknown outcome the payment is never resent and its result is shown as today.

## Implementation tasks

### 1. Add isolated transfer enrollment storage

**Files:** `lib/helper/secure_storage.dart`, new `lib/helper/biometric_transfer_storage.dart`, `test/biometric_transfer_storage_test.dart`.

- Add a separate key set `BiometricTransferStorageKey { enabled, userId, pin }` stored under `'$_prefix.biometric_transfer.v1.<name>'`, with its own read/has/write/delete methods. Leave the login `BiometricStorageKey` set and its methods untouched, so no transfer change can affect login enrollment. Use the same `IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device)`: never synced to iCloud, never restored to another device, unreadable while the device is locked. Store the PIN as a string so leading zeros survive.
- Implement `enable({required String userId, required String pin})`, `loadValidEnrollment()` (returns the enrolled `userId`, never the PIN), `readPinAfterAuthentication(String userId)`, and `clearEnrollment()`. `enable` accepts exactly four digits and a non-empty user ID, clears any previous enrollment first, and writes the enabled marker last. `clearEnrollment` deletes the marker first and attempts every key even when one fails, returning the failed keys like `BiometricLoginStorage`.
- Treat partial, corrupt, or undecryptable enrollment, and any user ID mismatch on read, as absent and clear it.
- Tests: an interrupted enable never reads as enabled; a leading-zero PIN round-trips; an undecryptable value or a mismatched user ID clears the enrollment.

### 2. Add the transfer biometric provider

**Files:** new `lib/module/core_banking/provider/biometric_transfer_provider.dart`, provider test.

- Reuse `BiometricAuthService` (capability check, single in-flight prompt, `biometricOnly: true`, outcome mapping) and biometric login's presentation of Face ID / Touch ID / fingerprint. Provider state holds the enrollment flag, capability, busy flag, and a message; never the PIN.
- `enable(currentPin)`: only for a signed-in customer with `userProfile.isCreatedPin == true`. Verify with `verifyCurrentPin`; on success, prompt; on success, save the PIN bound to the session `userId`. Failure at any step leaves the toggle off and nothing saved.
- `disable()`: confirm with a biometric prompt when biometrics are usable; otherwise turn it off directly (the customer is already signed in). Clearing is immediate and blocks use even if a deletion fails.
- `approve(int attemptId)` returns an `ApprovalResult` (`passed`, `cancelled`, `unavailable`, `wiped`, `stopped`), never the PIN. It runs only when a session exists, the app is in the foreground, recency allows biometrics, and the enrollment's `userId` matches the session. It prompts, re-checks the session `userId`, reads the PIN, and calls `notifier.verifyPin(attemptId, pin)`. `CheckPassed` → `passed`. `CheckRetry` (a Core rejection of the PIN) → wipe and return `wiped`. `CheckStopped` after the PIN request was sent and failed (the attempt settles with `CoreRejection.validation`, `checkRefused`, `initiationFailed`, or `checkInterrupted`) → wipe and return `stopped`. `CheckStopped` without a judged request (expired initiation, unsupported checks, or a session that ended mid-check, whose late reply is dropped) → keep the enrollment and return `stopped`. A cancelled prompt sends nothing. Lockout, removed biometrics, or no longer usable hardware sends nothing; removed biometrics also wipe.
- `approveBill(BillPaymentDraft draft)` returns the same `ApprovalResult`. With the same preconditions and prompt, it reads the PIN and calls `billPaymentProvider.notifier.submit(draft, transactionPin: pin)`, then reads the outcome: `AcceptedSubmission` → `passed`; `RejectedSubmission(insufficientFunds)` → keep the enrollment and return `stopped`; any other `RejectedSubmission` → wipe and return `wiped`; `UnknownSubmission` → wipe and return `stopped`. A blocked (never sent) request keeps the enrollment.
- `wipe()`: the single cleanup entry used by every erase event; it cancels any in-flight prompt (`stopAuthentication`) and bumps an operation ID so late results are dropped.
- Hydrate after `appOpenRecency.latest()`, like biometric login. Clear enrollment when the signed-in `userId` differs from the stored one.
- Tests: `approve` sends exactly one PIN verification with the saved PIN and passes; a cancelled prompt sends nothing; a rejected PIN wipes the enrollment.

### 3. Apply login-style erasure and recency

**Files:** `lib/helper/app_open_recency.dart`, `lib/app/auth_flow_listener.dart`, `lib/module/onboarding/provider/security_action_providers.dart`, `lib/module/onboarding/provider/recovery_providers.dart`, `lib/module/account/screens/account_control_screens.dart`, `test/biometric_recency_integration_test.dart`.

- **Recency (6 months):** pass `BiometricTransferStorage` into `AppOpenRecency`. In `_record`, `enrolled` is true when either enrollment exists, and a stale or unreadable last-open clears both. If either cleanup fails, keep the stale timestamp and set `biometricsBlocked`, which blocks both features for the process and retries on the next open. `_recordForegroundOpen` in `auth_flow_listener.dart` calls `revokeForRecency()` on both providers (when they exist).
- **PIN change:** after `ChangePinNotifier` succeeds, call the transfer provider's `wipe()`, mirroring the password-change `forgetEnrollment()` call. The new PIN is not saved.
- **PIN recovery** (signed-in only, from Security Center): wipe when `PinRecoveryNotifier.start` begins and again after a successful reset.
- **Account deletion:** wipe next to the existing `biometricLoginProvider.forgetEnrollment()` call in the deletion success path. The deletion notifier is still a stub, so this runs only once deletion works.
- **Other user signs in:** the stored `userId` no longer matches the session, so hydrate wipes it.
- **Biometrics removed, values undecryptable:** wipe on detection.
- Like biometric login, ordinary logout, inactivity logout, and session expiry cancel any in-flight approval but keep a valid same-account enrollment. Approval never runs while signed out or backgrounded.
- Test: recency clears both enrollments, and a failed transfer cleanup blocks both features.

### 4. Make the Security Center toggle functional

**Files:** `lib/module/account/screens/account_control_screens.dart`, `lib/app/feature_capability.dart`, Security Center widget test.

- Replace the fixed "Fingerprint for transfers" placeholder with a provider-backed toggle named for the device biometric (for example "Face ID for transfers"), explaining that it approves transfers with the saved transaction PIN.
- Turning it on opens a four-digit current-PIN dialog with verifying and saving states and duplicate-tap prevention. A cancelled prompt silently leaves it off. Show "on" only after PIN verification, biometric confirmation, and storage all succeed.
- When the customer has no transaction PIN (`isCreatedPin != true`), keep the toggle disabled and explain that a PIN must be created first. Keep it disabled with a reason on devices without usable biometrics.
- Register `FeatureCapability.biometricTransfers: CapabilityRequirement(localOnly: true)` like `biometricLogin`, and remove it from the Security Center placeholder assertion.
- Test: enabling succeeds only after server PIN verification and a successful prompt.

### 5. Add the biometric approval sheet to the transfer flow

**Files:** new `lib/module/core_banking/screens/biometric_approval_sheet.dart`, `lib/module/core_banking/screens/core_transfer_attempt_view.dart`, transfer widget test.

- The new sheet shows the reviewed amount and transaction details, a primary "Use Face ID" / "Use Touch ID" / "Use fingerprint" button, and a "Use PIN instead" text button. It returns `approve`, `usePin`, or null (dismissed). It never sees the PIN and does not prompt automatically. The shared `TransactionPinSheet` stays unchanged for bills and limits.
- In `startCoreTransfer`'s `awaitingPin` loop, show the biometric sheet while transfer biometrics are enabled and the customer has not chosen "Use PIN instead"; otherwise show the PIN sheet exactly as today:
  - dismissed → `cancelReview(id)`, as with the PIN sheet;
  - `usePin` → show the PIN sheet for the rest of this attempt;
  - `approve` → `approve(id)`; the attempt view shows its existing verifying state while Core checks the PIN;
    - `passed` → continue to OTP / finalize as today;
    - `cancelled` → show the biometric sheet again;
    - `unavailable` (lockout or biometrics no longer usable) → show the PIN sheet with an explanation;
    - `wiped` (Core rejected the saved PIN) → show the PIN sheet immediately with "Biometric approval has been turned off. Enter your transaction PIN.";
    - `stopped` → the attempt has already ended (no money moved); show its result as today.
- Local biometric success alone never advances the transfer. OTP, liveness handling, initiation expiry, single finalize, balance refresh, and status behavior are unchanged.
- Test: the biometric sheet approves an intrabank transfer with one PIN verification; "Use PIN instead" opens the PIN sheet; a rejected saved PIN opens the PIN sheet immediately with biometric approval turned off.

### 6. Add biometric approval to bill payments

**Files:** `lib/module/core_banking/screens/bill_payment_screen.dart`, bill payment widget test.

- In `_confirm`, show the biometric approval sheet (with "Confirm payment" wording and the same bill summary) while transfer biometrics are enabled and the customer has not chosen "Use PIN instead"; otherwise the PIN sheet exactly as today. Dismissed → nothing is sent, as today.
- `approve` → move to the result step and call `approveBill(draft)`:
  - `passed` / `stopped` → show the result as today (balance and history refresh unchanged);
  - `cancelled` → show the biometric sheet again;
  - `unavailable` → show the PIN sheet with an explanation;
  - `wiped` → `billPaymentProvider.notifier.reset()` and show the PIN sheet immediately with "Biometric approval has been turned off. Enter your transaction PIN.", then submit the typed PIN as today.
- The one-POST rule is unchanged: an accepted or unknown bill is never resent.
- Test: the biometric sheet pays a bill with the saved PIN in one request; a rejected payment wipes the enrollment and opens the PIN sheet.

### 7. Verify

- Run the new and changed tests above, `flutter analyze`, and the full suite once.
- Device check on Android and iOS: enable, approve an intrabank and an interbank transfer and a bill payment, "Use PIN instead", cancel the prompt, change the PIN (toggle turns off), and a stale saved PIN (changed on another device) opening the PIN sheet with the toggle off.

## Acceptance criteria

- A signed-in customer with a transaction PIN can turn on the separate transfer-biometric toggle after server PIN verification and a biometric prompt. Only this toggle ever saves the PIN.
- While it is on, transfers and bill payments ask for biometric approval in their own sheet, with "Use PIN instead" always available. A successful prompt sends the saved PIN to the same Core endpoint used by manual entry. OTP and other Core checks still run.
- A cancelled or failed prompt never sends a PIN, finalizes a transfer, or pays a bill.
- Any failed verification of the saved PIN deletes it and turns the toggle off; a wrong PIN opens the PIN sheet immediately.
- A PIN change or reset turns the toggle off and deletes the saved PIN. The saved PIN is account-bound, encrypted at rest with biometric login's keychain settings, and erased on the same kinds of events as biometric login, including six months without an app open.
