# Biometric Login with Remembered Profile — Design Specification

**Date:** 2026-10-03  
**Status:** Approved design; revised 2026-10-03 after plan review (enrollment
verification, login-attempt cancellation, cleanup scope)

## 1. Objective

Add opt-in Face ID, Touch ID, and fingerprint login to the BOCTRUST iOS and
Android apps without changing the backend contract.

After a signed-in customer enables biometric login, the app remembers one
local account. On later unauthenticated visits, the login page presents a
personalized greeting containing the remembered first name, hides the
identifier field, retains password login as a fallback, and offers the
available biometric as a second login action.

The existing login API, device identity, new-device OTP, session persistence,
post-login bootstrap, and navigation remain authoritative. Local biometric
authentication only authorizes the app to read an encrypted saved credential;
it is not a replacement backend authentication mechanism.

## 2. Scope

### In scope

- iOS Face ID/Touch ID and Android enrolled biometric authentication.
- One remembered account per app installation.
- An operational biometric-login setting in Security Center.
- Secure persistence of the remembered login identifier and password.
- Persistence of the minimum remembered profile needed by the login UI,
  including the customer's first name.
- Personalized, standard, and enrollment-loading login-page modes.
- Password fallback for the remembered account.
- A switch-account action that forgets biometric enrollment.
- Explicit cleanup behavior for logout, session expiry, password reset/change,
  account deletion, capability removal, and corrupt storage.
- Reuse of the existing new-device OTP and post-login routing behavior.
- Unit, provider, widget, and lifecycle regression coverage.

### Out of scope

- Backend endpoint or request/response changes.
- Backend-issued biometric or refresh tokens.
- Remembering multiple accounts.
- Biometric approval of transfers or other transactions.
- Web, Windows, macOS, or Linux biometric login.
- Device PIN, pattern, or passcode fallback for the biometric action.

## 3. Product Decisions

1. Enabling biometrics for a new account replaces any previous remembered
   account on that installation.
2. Ordinary logout, inactivity logout, access-token expiry, HTTP 401 handling,
   and cold-start session cleanup preserve a valid biometric enrollment.
3. Disabling biometrics, choosing another account, starting password recovery
   for the remembered identifier, successfully changing the password,
   successfully deleting the account, or detecting invalid enrollment data
   removes the full biometric enrollment. Recovery for a different account
   leaves the enrollment intact.
4. The personalized login screen always retains manual password login.
5. Actual enrolled capability determines whether the UI says Face ID,
   Touch ID, or fingerprint. Platform type alone is not sufficient.
6. Biometric-only local authentication is required. The system device
   passcode must not silently authorize biometric login.
7. The login identifier may be either the email address or Nigerian phone
   number already supported by the normal login flow.
8. A successful manual login for the same remembered account may replace the
   encrypted saved password so the enrollment can recover after a password
   change performed elsewhere.
9. A transient API, device, network, or biometric lockout failure does not
   erase an otherwise consistent enrollment.

## 4. Current BOCTRUST Baseline

- `lib/helper/secure_storage.dart` already wraps `flutter_secure_storage` and
  owns versioned session and device-identity keys.
- `lib/helper/device_identity_service.dart` owns the stable device identifier
  used by login.
- `lib/module/onboarding/provider/login_flow_provider.dart` normalizes email or
  phone identifiers, submits the login request, handles new-device OTP, writes
  the authenticated session, and launches post-login bootstrap.
- `lib/module/onboarding/provider/auth_session_provider.dart` hydrates and
  clears encrypted authenticated-session state.
- `lib/module/onboarding/screens/onboarding_flow_screens.dart` currently shows
  one identifier/password login layout.
- `lib/module/account/screens/account_control_screens.dart` already displays a
  disabled biometric-login toggle in Security Center.
- `lib/app/app_router.dart` already recognizes `/login/biometric`, but redirects
  it to the normal login page for compatibility.
- `lib/app/feature_capability.dart` declares `biometricLogin` without an
  implementation requirement, so the feature is currently unavailable.
- `flutter_secure_storage` is already installed; `local_auth` is not.
- Android already uses `FlutterFragmentActivity`. The release manifest lacks
  biometric permission declarations.
- iOS does not currently declare `NSFaceIDUsageDescription`.
- `UserOwnProfileData.firstName` is available while signed in, but the current
  persisted `AuthSession` deliberately does not store profile presentation
  data.

## 5. Target Architecture

Use the existing secure-storage boundary, with dedicated biometric components
layered above it:

1. `BiometricAuthService` wraps `local_auth`, capability detection, prompts,
   cancellation, and plugin-to-domain error mapping.
2. `RememberedBiometricProfile` represents non-secret, versioned remembered
   account data.
3. `BiometricLoginStorage` coordinates the remembered profile, encrypted
   credential, enabled marker, consistency validation, replacement, and
   idempotent cleanup.
4. `BiometricLoginNotifier` is the single Riverpod source of truth for
   hydration, enrollment, disabling, biometric sign-in, and switch-account
   behavior.
5. `LoginFlowNotifier` remains the only owner of backend login, new-device OTP,
   authenticated-session establishment, and post-login routing. It gains a
   structured completion contract that remembered-account login observes
   without duplicating its implementation.

The biometric layer must not call `AuthService.login()` directly or construct
its own device token. Enrollment runs while the customer is signed in, so it
confirms the password through the existing authenticated
`AuthService.verifyCurrentPassword` (`/auth/password/verify-current`) and does
not log in a second time.

## 6. Remembered Profile and Credential Model

Create `lib/module/onboarding/model/remembered_biometric_profile.dart` with an
immutable model containing:

- `schemaVersion` with initial value `1`;
- `userId`;
- normalized `identifier`;
- `identifierType`;
- trimmed `firstName`;
- detected `biometricType` as an application enum/wire value.

Only data required to identify the remembered account and render the
personalized login page belongs in this model. Do not store the full profile,
phone/email verification status, KYC data, balance data, PIN metadata, OTPs,
access token, or password in the model.

Enrollment requires a non-empty user ID, valid normalized identifier, and
non-empty first name from the authenticated `UserOwnProfileData`. If profile
data cannot satisfy that contract, the setting remains off and explains that
the account profile must finish loading before enrollment can continue.

The encrypted credential contains only the normalized identifier and password.
The stored credential identifier must match the remembered profile identifier
before any login request is submitted.

## 7. Secure Storage Design

Extend `lib/helper/secure_storage.dart` with app-owned, environment-namespaced,
versioned biometric keys. Do not reuse the legacy
`boctrust.biometric_credentials` key, which startup migration intentionally
deletes.

`BiometricLoginStorage` exposes these operations:

- `Future<void> enable(profile, identifier, password)`;
- `Future<BiometricEnrollment?> loadValidEnrollment()`;
- `Future<void> replaceCredential(identifier, password)`;
- `Future<BiometricCleanupResult> clearEnrollment()`.

Enrollment is valid only when all persisted pieces exist and agree:

- enabled marker is true;
- remembered profile parses and has supported schema version;
- encrypted credential parses;
- profile and credential identifiers match after normalization.

Write order is credential, profile, then enabled marker. If any write fails,
attempt every cleanup step and leave the feature disabled. Cleanup is
idempotent and attempts removal of every biometric key even if one removal
throws. Hydration treats missing, malformed, unsupported, or inconsistent
pieces as invalid, disables biometric use for the current process, and attempts
full cleanup.

Use device-local Keychain/Keystore options supported by the resolved
`flutter_secure_storage` version. Credentials must not migrate to another
device through backup. The explicit `local_auth` prompt is still required
before reading the credential for login.

## 8. Biometric Authentication Service

Create `lib/helper/biometric_auth_service.dart` around `LocalAuthentication`.
It must:

- report unsupported platform, absent hardware, no enrollment, and available
  biometric types;
- choose Face ID, Touch ID, or fingerprint presentation from actual available
  types;
- authenticate with `biometricOnly: true`;
- request sticky/persistent authentication across app backgrounding where the
  resolved plugin supports it;
- cancel an active prompt when its owning flow is cancelled or disposed;
- allow only one prompt at a time.

Map platform/plugin outcomes to domain results: success, user cancellation,
temporary lockout, permanent lockout, unavailable hardware, no enrollment,
unsupported platform, and unknown failure. User cancellation is not an error
toast. Lockout and availability errors keep manual password login usable.

## 9. Login Orchestration Contract

Refactor `LoginFlowNotifier` only enough to expose a structured result for a
specific login attempt while retaining its current validation, device identity,
API request, new-device OTP, session establishment, and bootstrap behavior.

`login` returns a future that resolves exactly once with one of:

- completed authenticated login;
- invalid input;
- invalid credentials;
- device-identity failure;
- network/server failure;
- cancellation/disposal.

While new-device verification is in progress the future stays pending. Leaving
the new-device OTP screen, calling `cancel()`, or disposing the notifier (for
example `ref.invalidate(loginFlowProvider)` during logout) resolves it as
cancelled, so no caller can wait forever.

Normal login, remembered-account password fallback, and biometric credential
login all use the same identifier normalization and
`DeviceIdentityService.getOrCreate()` path. No biometric component stores a
device token or creates a second identifier.

Enrollment does not use this contract (see §5 and §10): calling `/login` while
signed in would mint a second session that the client must discard and,
depending on backend policy, could revoke the current token, send a new-login
alert, or count toward lockout. A signed-in device has already passed
new-device approval, so enrollment never needs new-device OTP.

Biometric login must not route or bootstrap twice when the shared login flow
completes.

The password exists only in the immediate operation and the encrypted storage
write/read. It must not be retained in notifier state, emitted in diagnostic
objects, logged, or copied into the remembered profile.

## 10. Enrollment and Disable Flow

Replace the disabled Security Center toggle with a capability-aware control:

- title and icon match Face ID, Touch ID, or fingerprint;
- show loading while capability or enrollment state hydrates;
- show concise unavailable copy when hardware/enrollment is missing;
- disable interaction while another operation is active.

Turning the setting on performs, in order:

1. recheck biometric capability;
2. read the signed-in user's ID, normalized identifier, and first name;
3. ask for the current BOCTRUST password without allowing identifier edits;
4. confirm it with `AuthService.verifyCurrentPassword`, without touching the
   current session or `LoginFlowNotifier`;
5. prompt for biometric confirmation;
6. atomically persist the credential, profile, and enabled marker;
7. clear the password controller and show success.

An incorrect password keeps the customer signed in and the dialog retryable.

Failure or cancellation at any stage leaves the switch off and rolls back any
partial enrollment. Duplicate submissions, dismissals that orphan work, and
late widget callbacks must be prevented.

Turning the setting off asks for biometric confirmation when biometrics remain
available. If the signed-in customer can no longer use device biometrics, the
current authenticated session authorizes cleanup. Disabling biometrics does not
log the customer out.

## 11. Personalized Login Experience

Hydrate biometric enrollment before selecting the login layout. Keep the page
shell stable during hydration so the identifier field does not flash before a
personalized screen appears.

### Standard mode

Preserve the current email-or-phone and password fields, forgot-password link,
login action, validation, and create-account footer.

### Remembered-account mode

- Heading: a time-based greeting such as `Good evening, Kenechukwu`.
- The persisted, trimmed first name supplies the personalized name.
- Omit the identifier field from the widget tree.
- Retain the password field and visibility control.
- Use the remembered identifier internally for password fallback.
- Present the primary login button and an accessible Face ID/Touch ID/
  fingerprint action.
- Allow the biometric action when the password field is empty.
- Disable both actions while either login path is active.
- Retain forgot-password access.
- Add `Not Kenechukwu? Sign in with another account`.

### Password fallback

Submit the remembered identifier and typed password through the shared login
flow. After a fully successful login for the same normalized identifier,
replace the encrypted stored password. Never replace it after a failed or
incomplete login.

### Biometric action

Dismiss the keyboard, recheck capability, prompt biometrically, then read and
validate the encrypted credential. Submit it through the shared login flow and
release local credential references immediately afterward.

If the backend rejects the stored credential, keep password fallback available
and ask the customer to enter the current password or reset it. Do not loop the
biometric prompt.

### Switch account

Cancel active biometric work, clear enrollment, clear the password and form
state, and rebuild standard mode with empty identifier and password fields. No
backend logout request is needed from this unauthenticated screen.

### Forgot password

Cancel active biometric work and open recovery with the remembered identifier
prefilled. The login page does not clear enrollment itself; recovery does so
once the identifier is confirmed (§12).

## 12. Cleanup Semantics

Keep authenticated-session cleanup separate from biometric-enrollment cleanup.

### Session-only cleanup

`AuthSessionNotifier.clear()` continues to remove the access token, persisted
session metadata, and in-memory authenticated state. Manual logout, inactivity,
session expiry, unauthorized responses, and cold-start expiry use this path and
preserve biometric enrollment.

### Enrollment cleanup

Every caller outside `BiometricLoginNotifier` clears through
`BiometricLoginNotifier.forgetEnrollment({onlyForIdentifier})`, never through
`BiometricLoginStorage` directly, so provider state and storage cannot disagree.
After cleanup the provider reports disabled even if a key deletion failed.

Clear enrollment for:

- disabling the Security Center setting;
- `Sign in with another account`;
- password recovery for the remembered identifier;
- successful in-app password change;
- successful account deletion;
- corrupt/inconsistent enrollment, including stored values that fail to
  decrypt after a backup restore;
- permanent removal of supported biometrics from the device.

`PasswordRecoveryNotifier.start` clears only after the identifier (and phone
channel) validates, only when the normalized identifier matches the remembered
profile, and before the first OTP request. A typo or recovery for another
account leaves the enrollment intact. Abandoning a recovery that did clear it
cannot restore the old biometric credential.

Account deletion is currently feature-gated as unavailable, and
`AccountDeletionNotifier.delete` is a stub. The cleanup hook goes in the
screen's deletion success path before logout so enabling that capability later
cannot leave deleted-account credentials on the device; move it into the
notifier when the deletion contract lands.

## 13. Feature Availability and Routing

Register `FeatureCapability.biometricLogin` as a device-local capability. Its
runtime provider still decides whether the current platform and device have a
usable enrolled biometric.

The `/login/biometric` compatibility route may continue to resolve to the same
login screen because layout is state-driven. Remove any redirect behavior that
would discard or bypass remembered-account hydration.

Unsupported platforms always render standard login and never expose the
Security Center biometric control as actionable.

## 14. Platform Configuration

### Flutter

- Add a compatible stable `local_auth` dependency.
- Reuse the installed `flutter_secure_storage` package.
- Do not add platform implementation packages directly unless required by the
  resolved plugin API.

### Android

- Add `android.permission.USE_BIOMETRIC`.
- Add `USE_FINGERPRINT` only if required for the supported Android range.
- Retain the existing `FlutterFragmentActivity` base class.
- Verify AppCompat theme and minimum-SDK requirements against the resolved
  package rather than changing them preemptively.
- Leave the app's backup policy unchanged. Keystore keys are never backed up,
  so restored biometric values cannot decrypt on another device; treat any
  biometric read or decryption error as invalid enrollment and clear it.

### iOS

- Add `NSFaceIDUsageDescription` with BOCTRUST-specific login copy.
- Write every biometric key with
  `KeychainAccessibility.unlocked_this_device` so it never syncs or migrates.
- Add entitlements or Xcode project settings only if required by the resolved
  `flutter_secure_storage` configuration.
- Do not add a second in-app permission prompt before the system biometric
  prompt.

## 15. State and Error Handling

`BiometricLoginNotifier` state must represent: hydrating, unavailable,
disabled, verifying password, awaiting new-device verification (remembered
login only), confirming biometric, enabling, enabled, authenticating, clearing,
and recoverable error.

State may contain the remembered non-secret profile and presentation type. It
must not contain a password, decrypted credential, access token, device token,
or complete server response.

Rules:

- one visible owner displays each error;
- user cancellation is silent;
- invalid password leaves enrollment off and the confirmation flow retryable;
- network/server/device-identity failure leaves existing valid enrollment
  intact;
- temporary/permanent lockout preserves enrollment and password fallback;
- missing biometrics during hydration clears enrollment and uses standard
  login;
- late async results after disposal do not navigate or show UI;
- rapid taps cannot create overlapping prompts, writes, or login requests;
- every login attempt resolves, including after OTP back-out or logout, so the
  operation lock is always released.

### Accepted risk

`flutter_secure_storage` does not bind the stored password to a
biometric-gated key, so the biometric prompt is an app-level gate. On a rooted
or jailbroken device the password is readable without the prompt.
Hardware-bound credentials need backend-issued biometric tokens, which are out
of scope (§2).

## 16. Testing Strategy

### Unit and storage tests

- remembered-profile JSON round trip and schema rejection;
- identifier normalization and profile/credential mismatch rejection;
- write ordering, rollback, idempotent cleanup, and partial-delete failure;
- biometric plugin outcome mapping and capability presentation;
- secure credential replacement only for the same remembered identifier.

### Provider tests

- hydration into enabled, disabled, unavailable, and corrupt-state outcomes;
- enrollment success and failure at each stage;
- enrollment uses `verifyCurrentPassword`, never `/login`, and leaves the
  current session untouched;
- pending login attempts resolve as cancelled on `cancel()`, OTP back-out, and
  disposal;
- `forgetEnrollment` scoped to a matching versus different identifier;
- biometric login through shared login orchestration;
- operation locking and cancellation;
- session-only logout preserving enrollment;
- password recovery/change and account deletion clearing enrollment.

### Widget tests

- stable hydration shell;
- standard versus remembered-account layouts;
- persisted first name in the time-based greeting;
- identifier field absent in remembered mode;
- manual password and biometric buttons with shared loading state;
- switch-account restoration of empty standard form;
- forgot-password prefill without clearing enrollment on the login page;
- OTP back-out during remembered login leaves biometric login usable;
- capability-specific labels, semantics, unavailable, and lockout states.

### Platform and regression verification

- Flutter formatting and static analysis;
- focused biometric tests and the full Flutter test suite;
- Android debug build with biometric permissions and plugin registration;
- iOS simulator build without signing and Info.plist validation;
- manual checks on at least one enrolled Android device and one enrolled iOS
  device before release, because simulators cannot prove hardware behavior.

## 17. Acceptance Criteria

- A signed-in mobile customer with an enrolled biometric can enable biometric
  login from Security Center.
- Enrollment succeeds only after `verifyCurrentPassword` and a biometric
  prompt both succeed, without creating a second session.
- The credential is stored only in encrypted, device-local storage.
- Ordinary logout and session expiry preserve enrollment.
- The next unauthenticated login shows a greeting with the persisted first name
  and does not render an identifier field.
- Password fallback uses the remembered identifier and remains available after
  biometric cancellation, unavailability, or lockout.
- Face ID, Touch ID, or fingerprint presentation matches the device's actual
  enrolled capability.
- Biometric sign-in reuses existing login, device identity, OTP, session, and
  post-login bootstrap behavior.
- Switching account restores a blank standard login form and deletes all
  remembered biometric data.
- Starting password recovery for the remembered identifier clears enrollment
  before the first OTP request; recovery for another account does not.
- Successful password change and account deletion clear enrollment.
- Missing, malformed, inconsistent, or unsupported stored data safely returns
  to standard login.
- No password, access token, or device token is stored in the remembered
  profile, Riverpod state, SharedPreferences, logs, analytics, or UI.

## 18. Expected File Areas

### New files

- `lib/module/onboarding/model/remembered_biometric_profile.dart`
- `lib/helper/biometric_auth_service.dart`
- `lib/helper/biometric_login_storage.dart`
- `lib/module/onboarding/provider/biometric_login_provider.dart`
- focused unit/provider/widget test files under `test/`

### Existing files

- `pubspec.yaml` and `pubspec.lock`
- `lib/helper/secure_storage.dart`
- `lib/module/onboarding/provider/login_flow_provider.dart`
- `lib/module/onboarding/provider/auth_session_provider.dart`
- `lib/module/onboarding/provider/recovery_providers.dart`
- `lib/module/onboarding/provider/security_action_providers.dart`
- `lib/module/onboarding/screens/onboarding_flow_screens.dart`
- `lib/module/account/screens/account_control_screens.dart`
- `lib/app/feature_capability.dart`
- `lib/app/app_router.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- platform project files only when required by resolved dependency constraints

The implementation plan must verify exact line ranges and split tasks along
model/storage, login orchestration, enrollment settings, personalized login,
cleanup integration, platform setup, and end-to-end verification boundaries.
