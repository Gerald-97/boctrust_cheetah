# KYC Provider and Government-ID Catalogue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consume the authenticated KYC provider configuration and government-ID catalogue so the form offers only server-active, SDK-supported documents, including `national_id` displayed as “NIN, National Identity Number”.

**Architecture:** Add strict transport models and two authenticated reads to the existing User Service KYC layer, then expose them through session-scoped Riverpod notifiers. The form uses `providerConfig.governmentId.provider` for preflight filtering, while the provider returned by initiation remains authoritative for the actual capture attempt. Unsupported Smile mappings fail before SDK job construction.

**Tech Stack:** Flutter, Dart 3.12+, Riverpod 3, Dio 5, Equatable, existing `ApiService`/`NotifierState`/`StaleResultGuard`, Dojah, Smile ID, and Flutter unit/widget tests.

**Spec:** The 1 October 2026 API review, live [BocTrust User Service OpenAPI document](https://user-dev-api.centurysoftware.dev/api/v1/docs/), and `plan/USER_SERVICE_CONTRACT_GAPS.md`.

**Working-tree preflight (human checkpoint):** Before Task 0, run `git status --short`. `git add <path>` stages a whole file, so pre-existing uncommitted hunks in any file a task commits would be swept into that task's commit. If `lib/module/app_flow/app_flow_navigator.dart`, `lib/module/kyc/screens/kyc_screens.dart`, or any other path listed by a task has uncommitted changes the plan did not make, stop and ask your human partner to commit them (currently the `_launchingKycCapture`/`_warmUpSmileId` capture-launch work). Never commit, stash, restore, or overwrite that work yourself, and do not start Task 1 until the listed paths are clean.

**Human checkpoints:** Steps marked **(human checkpoint)** need staging dashboards, physical devices, or a release decision. A subagent must stop there, report what is needed, and wait. Never mark such a step complete from inference.

## Global Constraints

- Keep `national_id` and `nin_slip` as distinct wire values. Display them as “NIN, National Identity Number” and “NIN slip” respectively.
- Add no fabricated Smile mapping for `national_id`. It remains unavailable to Smile until backend and sandbox evidence explicitly enable it.
- Treat the API catalogue as the active-choice authority and local SDK support as an additional fail-closed filter.
- For preflight choices, use `KycProviderConfigData.governmentId.provider`, never root `activeProvider`.
- Treat the provider returned by `POST /users/me/kyc/government-id/initiate` as final authority for the attempt.
- Require exact environment mapping: app `staging` accepts API `sandbox`; app `prod` accepts API `live`; every other pairing blocks initiation.
- Load both new GETs through the authenticated User Service. Do not add them to `ApiEndpoints.publicOperations`.
- Send `documentNumber` only when the selected catalogue row requires it; omit null, blank, or hidden stale values.
- Do not call or model the Dojah webhook in Flutter and do not implement Smile ID v12 token retrieval without a published expiry contract.
- Preserve KYC status, retry/resume, reconciliation, consent, provider capture, signed upload, and the committed capture-launch busy state.
- Clear configuration state on logout, expiry, and user switching; stale responses must not repopulate it.

## Review Focus

- Adding `nationalId` must leave every enum switch exhaustive and must not let Smile construct a job for an unsupported type; pin in Task 1.
- An environment mismatch must block before the initiation POST; pin in Tasks 3 and 4.
- Unsupported-document copy must suggest only entries in the current server catalogue that the final provider can launch; pin in Tasks 1 and 4.
- Switching away from a number-required document must clear and omit the hidden number; pin in Task 4.
- A catalogue refresh or session change must not retain an invalid selection, cached job, or stale response; pin in Tasks 3 and 4.

---

### Task 0: Verify Dojah `national_id` Capability Before Enabling It

**Files:**
- Verification only; record the result in `docs/verification/dojah-kyc.md` during Task 5.

**Interfaces:**
- Produces the release decision for whether `GovernmentIdDocumentType.nationalId.isEnabledFor(KycProvider.dojah)` may return true.

- [ ] **Step 1 (human checkpoint): Inspect and exercise the staging government-ID widget**

The app cannot select `national_id` until Task 4, so verify through Dojah directly: confirm in the Dojah dashboard that NIN is enabled for `DOJAH_GOVERNMENT_WIDGET_ID`, then use the widget's own preview/test flow on controlled Android and iOS staging devices to confirm a NIN submission reaches submitted/pending status. A subagent stops here and asks your human partner for the result.

- [ ] **Step 2: Apply the deterministic outcome**

If verification passes, include `nationalId` in the Dojah-supported set in Task 1. If it fails or cannot be performed, keep `nationalId` excluded from Dojah and do not expose it in Task 4; record the external blocker rather than claiming support.

### Task 1: Model Documents and SDK Capability Safely

**Files:**
- Create: `lib/module/kyc/model/kyc_configuration_models.dart`
- Create: `test/kyc_configuration_models_test.dart`
- Modify: `lib/module/kyc/model/kyc_models.dart`
- Modify: `lib/module/kyc/model/kyc_provider_models.dart`
- Modify: `lib/module/kyc/service/smile_id_gateway.dart`
- Modify: `lib/module/kyc/screens/kyc_screens.dart` (temporary caller adapter only)
- Modify: `test/api_value_handling_test.dart`
- Modify: `test/kyc_provider_models_test.dart`
- Modify: `test/kyc_government_id_flow_test.dart`

**Interfaces:**
- Produces `GovernmentIdDocumentType.nationalId`, `SmileIdDocumentSpec? smileIdDocumentSpec`, `KycProviderOperationConfig`, `KycProviderConfigData`, `GovernmentIdDocumentOption`, `GovernmentIdDocumentCatalogue`, and an optional-number `GovernmentIdVerificationRequest`.
- Changes `governmentIdUnsupportedMessage` to accept the currently offered catalogue types instead of deriving alternatives from every enum value.

- [ ] **Step 1: Write failing enum, Smile-safety, request, and message tests**

Assert the exact `national_id` wire value and label, distinct `nin_slip` behavior, omitted optional `documentNumber`, and trimmed required values. Prove both existing Smile switches remain exhaustive, `nationalId.smileIdDocumentSpec` is null, Smile job construction rejects `national_id`, and unsupported copy never names a document absent from the supplied live catalogue.

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `flutter test test/api_value_handling_test.dart test/kyc_provider_models_test.dart test/kyc_government_id_flow_test.dart`

Expected: FAIL because `nationalId`, nullable Smile capability, optional request values, and live alternatives do not exist.

- [ ] **Step 3: Implement the document and SDK boundaries**

Add `nationalId('national_id', 'NIN, National Identity Number')`. Replace separate unconditional Smile getters with `SmileIdDocumentSpec?`, carrying `wireValue` and `captureBothSides`; retain existing specs for known mappings and return null for `nationalId`. Before `SmileIdDocumentJob.fromInitiation` reads the spec, require both `type.isEnabledFor(KycProvider.smileId)` and a non-null spec, otherwise throw `SmileIdConfigurationException`.

Keep Dojah locally enabled only for document types confirmed in Task 0; include `nationalId` only when that gate passed. Keep Smile locally enabled only for `voter_id`. Make `GovernmentIdVerificationRequest.documentNumber` nullable, trim it, and omit the key when blank.

Change unsupported-copy input to `Iterable<GovernmentIdDocumentType> offeredTypes`; filter that iterable again for the final initiation provider before naming alternatives.

Keep the app compiling at this commit: update the existing caller at `kyc_screens.dart` (the `governmentIdUnsupportedMessage` call in `_startGovernmentIdVerification`) to pass `GovernmentIdDocumentType.values` as `offeredTypes`, with a `// Replaced by the live catalogue in Task 4.` comment. Change nothing else in that file in this task. Task 4 replaces the adapter with the live offered intersection.

- [ ] **Step 4: Write and implement strict configuration models**

Test and implement parsing for `activeProvider`, `environment`, `identity`, `governmentId`, active document rows, server ordering, `requiresDocumentNumber`, immutable results, first-valid duplicate handling, and safe omission of malformed siblings. Unknown providers/environments or a catalogue with no usable rows produce `FormatException`.

`GovernmentIdDocumentOption.displayLabel` must always use the local exact label for `nationalId`; other known entries may use the nonblank server label.

`KycProviderOperationConfig` models `provider`, `product`, `sdkJobType`, and `jobType` only. The OpenAPI marks `callbackUrl` required but nullable; the form never uses it, so tolerate its presence or null value but do not parse it into app state.

- [ ] **Step 5: Run and commit the contract slice**

Run: `flutter test test/kyc_configuration_models_test.dart test/api_value_handling_test.dart test/kyc_provider_models_test.dart test/kyc_government_id_flow_test.dart`

Expected: PASS with exhaustive enum handling and no invented Smile mapping. Also run `flutter analyze` to prove the adapted screen still compiles.

```bash
git add lib/module/kyc/model/kyc_configuration_models.dart lib/module/kyc/model/kyc_models.dart lib/module/kyc/model/kyc_provider_models.dart lib/module/kyc/service/smile_id_gateway.dart lib/module/kyc/screens/kyc_screens.dart test/kyc_configuration_models_test.dart test/api_value_handling_test.dart test/kyc_provider_models_test.dart test/kyc_government_id_flow_test.dart
git commit -m "feat(kyc): model provider and document configuration"
```

### Task 2: Add Authenticated Service Operations and Capability Metadata

**Files:**
- Modify: `lib/app/api_endpoints.dart`
- Modify: `lib/app/feature_capability.dart`
- Modify: `lib/module/kyc/service/kyc_service.dart`
- Create: `test/kyc_configuration_service_test.dart`
- Modify: `test/feature_capability_test.dart`

**Interfaces:**
- Produces `ApiEndpoints.kycProviderConfig`, `ApiEndpoints.governmentIdDocumentTypes`, `KycService.getProviderConfig()`, and `KycService.getGovernmentIdDocumentTypes()`.
- Extends `FeatureCapability.kycGovernmentId` with both GET requirements in addition to status and initiation.

- [ ] **Step 1: Write failing routing and capability tests**

Record and assert exactly:

```text
GET /users/me/kyc/provider-config
GET /users/me/kyc/government-id/document-types
```

Assert both require authentication, parse the standard envelope, and are included in `capabilityRequirements[FeatureCapability.kycGovernmentId]`.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/kyc_configuration_service_test.dart test/feature_capability_test.dart`

Expected: FAIL because the operations and capability requirements are absent.

- [ ] **Step 3: Implement endpoints, methods, and capability requirements**

Add the exact endpoint constants and typed service methods using `_api.getData`. Add both GET operations to the KYC capability without adding query parameters, caching, webhook constants, or public-operation entries.

- [ ] **Step 4: Run and commit the service slice**

Run: `flutter test test/kyc_configuration_service_test.dart test/feature_capability_test.dart`

Expected: PASS with one authenticated request per operation.

```bash
git add lib/app/api_endpoints.dart lib/app/feature_capability.dart lib/module/kyc/service/kyc_service.dart test/kyc_configuration_service_test.dart test/feature_capability_test.dart
git commit -m "feat(kyc): fetch provider and document configuration"
```

### Task 3: Add Session-Scoped Configuration State

**Files:**
- Create: `lib/module/kyc/provider/kyc_configuration_provider.dart`
- Create: `test/kyc_configuration_provider_test.dart`
- Modify: `lib/app/private_user_state.dart`
- Modify: `test/logout_private_state_test.dart`

**Interfaces:**
- Produces `kycProviderConfigProvider` and `governmentIdDocumentTypesProvider`, each exposing `load()` and `clear()`.

- [ ] **Step 1: Write failing lifecycle and environment tests**

Cover idle/load/success, coalesced loads, stale-data refresh, malformed responses, `clear()`, late-result suppression, logout, and exact environment acceptance: staging/sandbox and prod/live pass; staging/live, prod/sandbox, and unknown values fail closed.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/kyc_configuration_provider_test.dart test/logout_private_state_test.dart`

Expected: FAIL because the notifiers and strict mapping do not exist.

- [ ] **Step 3: Implement providers and private-state clearing**

Follow `StaleResultGuard`: coalesce in-flight work, retain last good data during recoverable refresh errors, compare API environment to `Env.isStaging`/`Env.isProd` using the exact mapping above, and invalidate request generations in `clear()`. Do not persist either response.

- [ ] **Step 4: Run and commit the state slice**

Run: `flutter test test/kyc_configuration_provider_test.dart test/logout_private_state_test.dart`

Expected: PASS with no cross-session configuration leakage.

```bash
git add lib/module/kyc/provider/kyc_configuration_provider.dart lib/app/private_user_state.dart test/kyc_configuration_provider_test.dart test/logout_private_state_test.dart
git commit -m "feat(kyc): manage session-scoped KYC configuration"
```

### Task 4: Drive the Government-ID Widget from Live Configuration

**Files:**
- Modify: `lib/module/app_flow/app_flow_navigator.dart`
- Modify: `lib/module/kyc/screens/kyc_screens.dart`
- Modify: `lib/module/kyc/provider/kyc_providers.dart`
- Modify: `test/kyc_government_id_start_test.dart`
- Modify: `test/kyc_government_id_flow_test.dart`
- Modify: `test/kyc_government_id_smile_fallback_test.dart`
- Modify: `test/kyc_tier_return_test.dart`
- Modify: `test/responsive_layout_test.dart`
- Modify: `test/support/responsive_fixtures.dart`

**Interfaces:**
- Consumes both Task 3 providers and `providerConfig.governmentId.provider`.
- Produces a fail-closed dynamic form and optional-number submission while preserving the existing capture-launch busy state.

- [ ] **Step 1: Extend every widget fixture with configuration responses**

Default fixtures contain server-ordered passport, driver’s licence, voter ID, `national_id`, and `nin_slip` rows. Include separate root `activeProvider` and `governmentId.provider` values in at least one fixture so tests detect use of the wrong field.

- [ ] **Step 2: Write failing loading, filtering, selection, and responsive tests**

Assert loading and retry states, no hard-coded fallback, server ordering, exact NIN labels, filtering by `governmentId.provider`, safe reselection after refresh, empty-intersection blocking, and layouts at 320px, landscape, dark mode, and 200% text.

- [ ] **Step 3: Implement live selection and conditional number input**

Make the selected type nullable. Intersect catalogue rows with `config.governmentId.provider` support, retain a valid selection, otherwise select the first offered row, and disable initiation when none remain. Show descriptions and `displayLabel` values.

Render the number field only when required. Clear its controller when switching to an optional type; pass null for optional submissions. Keep the existing launch-in-progress behavior and other user changes intact.

- [ ] **Step 4: Test final initiation-provider authority**

Cover config Dojah/initiation Smile and config Smile/initiation Dojah. Re-evaluate the selected type against the initiation provider and current catalogue; error copy may suggest only current catalogue entries supported by that final provider. A removed selection cannot reuse a cached job.

Replace Task 1's temporary `GovernmentIdDocumentType.values` adapter with the current catalogue's offered types and remove its comment.

- [ ] **Step 5: Run and commit the widget slice**

Run: `flutter test test/kyc_government_id_start_test.dart test/kyc_government_id_flow_test.dart test/kyc_government_id_smile_fallback_test.dart test/kyc_tier_return_test.dart test/kyc_provider_models_test.dart test/responsive_layout_test.dart`

Expected: PASS with no hard-coded catalogue fallback or hidden number leakage.

```bash
git add lib/module/app_flow/app_flow_navigator.dart lib/module/kyc/screens/kyc_screens.dart lib/module/kyc/provider/kyc_providers.dart test/kyc_government_id_start_test.dart test/kyc_government_id_flow_test.dart test/kyc_government_id_smile_fallback_test.dart test/kyc_tier_return_test.dart test/responsive_layout_test.dart test/support/responsive_fixtures.dart
git commit -m "feat(kyc): drive government ID form from live configuration"
```

### Task 5: Verify Dojah Configuration and Document the Contract

**Files:**
- Modify: `README.md`
- Modify: `docs/SMILE_ID_V12_UPGRADE_PLAN.md`
- Modify: `docs/verification/dojah-kyc.md`
- Modify locally only: `plan/USER_SERVICE_CONTRACT_GAPS.md`

**Interfaces:**
- Produces operator guidance and staging evidence; no new runtime interface.

- [ ] **Step 1: Update documentation and record the Task 0 gate**

Document catalogue authority, strict environment mapping, exact labels, `governmentId.provider` preflight authority, initiation-provider final authority, conditional document numbers, Dojah widget configuration, and the still-blocked Smile v12 expiry contract.

- [ ] **Step 2: Run final verification**

```bash
dart format --output=none --set-exit-if-changed lib test
flutter test test/kyc_configuration_models_test.dart test/kyc_configuration_service_test.dart test/kyc_configuration_provider_test.dart test/kyc_government_id_start_test.dart test/kyc_government_id_flow_test.dart test/kyc_government_id_smile_fallback_test.dart test/kyc_tier_return_test.dart test/logout_private_state_test.dart test/feature_capability_test.dart test/responsive_layout_test.dart
flutter analyze
flutter test --no-pub --reporter expanded
git diff --check
```

Expected: all automated checks pass.

- [ ] **Step 3 (human checkpoint): Verify on authenticated staging devices**

Your human partner confirms on Android and iOS that both GETs load before the form is usable, the NIN labels and conditional number behave as specified, Retry recovers, initiation launches its own provider, and logout/login as another user reloads configuration. Retained logs and evidence must contain no tokens, document numbers, callback URLs, or raw provider payloads.

- [ ] **Step 4: Commit tracked documentation only**

```bash
git add README.md docs/SMILE_ID_V12_UPGRADE_PLAN.md docs/verification/dojah-kyc.md
git commit -m "docs(kyc): record dynamic provider and document contracts"
```

Do not force-add the ignored contract-gap file.

## Completion Criteria

- Both authenticated GETs are part of the government-ID capability contract.
- `national_id` compiles across every switch and displays exactly “NIN, National Identity Number”.
- Unsupported Smile types fail before SDK construction and no Smile mapping is invented for `national_id`.
- Preflight filtering uses `governmentId.provider`; initiation remains final provider authority.
- Only the live catalogue/provider intersection appears in the form or alternative suggestions.
- Strict staging/sandbox and prod/live mapping is enforced before POST.
- Optional document numbers and all session transitions are handled without stale data leakage.
- Dojah `national_id` is enabled only after dashboard/device verification.
- Focused tests, full tests, analysis, formatting, and Android/iOS staging checks pass.
