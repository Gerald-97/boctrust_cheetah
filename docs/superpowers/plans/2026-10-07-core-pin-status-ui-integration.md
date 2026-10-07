# Core PIN and Live Status UI Integration Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task after review. Steps use checkbox syntax for tracking. Do not execute as part of this planning request.

**Goal:** Connect the four existing mobile transfer/withdrawal flows to Core transaction PIN authorization and live status reconciliation.

**Architecture:** Keep draft models credential-free. Pass PIN directly through the one-shot submission call, retain only non-secret attempt/tracking state in one session-scoped attempt provider, which also owns live re-query state, and feed the existing result screens from it. Live status has its own model, separate from the cached interbank status model.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, existing ApiService/NotifierState and shared result widgets; no new dependency expected.

**Spec:** `docs/superpowers/specs/2026-10-07-core-pin-status-ui-design.md`.

Status: proposed; no implementation or staging verification completed. Unrelated dirty files at planning time: `analysis_options.yaml`, `macos/Runner.xcodeproj/project.pbxproj`, `pubspec.lock`. Preserve them; stage only task-owned changes.

`.gitignore` ignores `docs/`; existing tracked docs were force-added. Stage every new file under `docs/` (this plan, its spec, the contract fixture, the verification doc) with `git add -f <path>`, and confirm with `git status --short --ignored docs` that each one is staged.

## Global constraints

- Core transport only; attach current bearer token and preserve User Service session on Core 401.
- Four-digit PIN string, leading zeros preserved. Never store it in drafts, provider state, receipts, routes, logs or persistence.
- Transfers/withdrawals use exact Kobo strings; bills remain Naira strings and gated.
- No automatic money-moving retry, no second POST for an unresolved attempt, no inferred success from HTTP 200.
- Re-query retries are safe reads despite POST method. Do not put them in `CoreApiEndpoints.moneyMoving`.
- Existing denied authorizer remains the safe default for bills. For transfers, the transfer-authorization readiness gate (added in Task 2, false by default) must exist before any PIN submit path is wired in Task 3, so no intermediate commit can send a PIN-authorized transfer.
- Earlier plan PIN-body prohibitions are superseded only for the documented mobile transfers, not for bills.

## Review focus

1. `0007` remains four digits and is redacted even in staging (Task 2).
2. Missing/incorrect query identifiers never fall back to BankOne receipt references (Tasks 1, 4).
3. Back navigation, screen recreation and session changes cannot enable duplicate submission or apply stale results (Tasks 3, 4).
4. Provider success plus reversal displays Reversed; unfamiliar status and query errors never display false failure/success (Tasks 1, 4).
5. A generic remote Core 401 is distinct from documented wrong PIN and never expires User login; a local session expiry still follows the User Service expiry flow (Task 3).
6. An unresolved attempt never locks the customer out of transfers beyond an explicit acknowledgement (Tasks 3, 4).
7. Known BankOne success variants such as `SuccesfulButFeeNotTaken` are fixture-confirmed before the strict allowlist ships (Task 1).

## Endpoint → UI map

All paths below are relative to `$CORE_BASE_URL/v1`.

| Existing UI / entry | Submission | Live result action |
|---|---|---|
| Send → Between my accounts → BocFlex to savings | POST `/me/intrabank/transfers/own` + transactionPin | POST `/me/intrabank/transfers/{retrievalReference}/requery` |
| Between my accounts → savings to BocFlex / existing withdrawal entry | POST `/me/intrabank/withdrawals` + transactionPin | Same intrabank re-query |
| Send → BOCTRUST customer | POST `/me/intrabank/transfers` + transactionPin | Same intrabank re-query |
| Send → Other bank → resolved recipient | POST `/me/interbank/transfers` + transactionPin | POST `/me/interbank/transfers/{transactionReference}/requery` |
| Existing interbank cached status | GET `/me/interbank/transfers/{transactionReference}/status` | Keep distinct from live result |
| Airtime/Data/Bills | Existing mobile payment request | No activation until mobile PIN contract is published |

Reuse `own_account_move_screen.dart`, `boctrust_transfer_screen.dart`, `interbank_transfer_screen.dart` and animated `CoreSubmissionResult` in `core_flow_widgets.dart`. PIN entry is a modal launched from review, not an unrelated login/PIN-change route.

## Decisions resolved by engineering review

### Attempt ownership and navigation

Create `lib/module/core_banking/provider/core_transfer_attempt_provider.dart` as the single session-owned transfer coordinator, shared by all four transfer operations. Allocate a monotonically increasing local attempt ID when the PIN dialog is opened; reserve it before any asynchronous work so repeated Confirm taps cannot open multiple dialogs. Capture the reviewed immutable draft and session generation. Implement the session generation with the existing `StaleResultGuard` mixin and an `authSessionProvider` listener, as `SessionScopedNotifier` in `lib/app/session_scoped_notifier.dart` does; do not build a second staleness mechanism. Cancellation releases the reservation without a request. A PIN submission changes that same attempt to submitting; it never creates a second attempt. Provider state contains no credential.

Expose `beginReview(kind, draft)`, `submitAuthorized(attemptId, transactionPin)`, `cancelReview(attemptId)`, `check(attemptId)`, `startNewTransfer()` and `acknowledgeUnresolved(attemptId)`; consumers cannot submit through the old transfer `submit(draft)` path. The attempt provider is the single owner of live re-query state (last good live status, check in flight, check error) for each attempt; there is no separate re-query provider. Retain one current attempt plus its latest result per authenticated session, and a short session list of acknowledged unresolved attempts (non-secret: kind, reviewed display details, tracking reference, last outcome). Re-entry to any transfer flow resumes an unresolved, unacknowledged attempt's result, including its original operation and reviewed details; remove unconditional screen-init `clear()` calls. Editing navigation is allowed only before submission or after a definite rejection. While submitting, or while the current attempt is pending/unknown and not yet acknowledged, all four transfer entries route to the current result rather than creating another transfer. Balance/support actions remain available.

Completed, failed, reversed or definite rejection permits `startNewTransfer()` directly with a new ID; the old attempt is never resent. Wrong PIN reopens PIN entry (not review) on the same reviewed attempt after clearing input; a new request is allowed only because the previous request definitively did not move money. Terminal failed/reversed results have no Retry button; offer Start new transfer. A terminal result remains visible until Start new transfer.

Unresolved escape: a Processing or Unconfirmed result (including unclassified/duplicate 409 and lost response) offers a secondary "Start a different transfer" action. It shows a confirmation with the copy "This transfer may still go through. Check your balance first — sending it again could pay twice." and offers Check balance as the primary choice. Confirming calls `acknowledgeUnresolved(attemptId)`, which moves the attempt to the acknowledged list (still visible from the transfer entry as a banner, and still checkable when it has a tracking reference), then opens an empty form: never prefill from the unresolved draft, so a duplicate requires deliberate re-entry. No escape while a submission is in flight. The acknowledged attempt is never resent, and a later live result on it updates its own entry only.

Dispose/logout/token or customer change invalidates the session generation and drops all attempt state, including the acknowledged list; every asynchronous PIN/submission/query result verifies both generation and attempt ID before acting. Logout is not a recovery mechanism and must not be offered to unlock an uncertain transfer. Persistence across process restart remains outside this slice and is documented as a limitation.

### Rejection and duplicate rules

Use `ServiceResponse.errorCode` for verified backend discriminators; never match localized/free-form messages. Maintain an endpoint-specific mapping table populated from sanitized backend fixtures in the contract evidence file; do not invent wire codes. Recognized wrong-PIN 401 is a definite rejection with PIN correction. Unrecognized remote 401 shows Core authorization unavailable, preserves login, and requires explicit return to review; it is not labeled wrong PIN. Distinguish the local session-expiry 401 that `_mapDioException` in `lib/app/network.dart` produces for `LocalSessionExpired`: the request was never sent, so classify it as a definite non-send and let the existing User Service expiry flow run; do not show Core authorization copy for it. Generic 403 is a definite restriction, with no guessed countdown or attempt count.

Interbank 500: `mapCoreSubmission` currently maps it to `recipientUnresolved` (definite rejection). Re-confirm against the current contract that a 500 still guarantees nothing moved now that Core calls User Service for PIN verification. Keep the rejection mapping only for a fixture-confirmed discriminator; otherwise map interbank 500 to Unconfirmed.

For 409, only a backend-confirmed reference-collision code proving no transfer was executed permits an explicit new attempt. Recognized duplicate/similar-transaction codes and every unclassified 409 become an unresolved duplicate outcome: retain any returned tracking reference, allow re-query if present, and expose neither automatic nor manual resubmission; only the acknowledged escape applies. Existing blanket `409 => referenceCollision` mapping must be removed for transfers. Tests cover classified collision, classified duplicate and unknown 409 separately.

### Credential-bearing error logging

Updating `lib/app/interceptors.dart` is mandatory. Structured Map bodies already redact `transactionPin` because `pin` is in `_alwaysRedactedKeyParts`; the real gap is `onError`, which in staging passes raw `err.message` and `err.error`, and always passes `err.stackTrace`. Detect protected credential keys recursively in request bodies before logging. For such requests in every environment, including staging, log only a fixed error message, exception type, HTTP status and sanitized structured bodies; never pass raw `err.message`, `err.error` or an exception's string representation to Logger. Suppress raw stack traces for these requests. Structured redaction remains in place. Exercise both response and error logs with a PIN echoed in plain exception text; assert no credential appears anywhere in emitted output. Do not store the PIN in interceptor metadata to perform masking.

### Outcome precedence and missing references

Live interbank `isReversed == true` takes precedence over all status/code combinations. Otherwise trim and compare provider status case-insensitively: Successful→completed, Failed→failed, Pending→pending; no fuzzy substring matching. `responseCode == "00"` supports success but does not promote null/unknown/pending to completed. Successful plus a nonempty non-00 code, or Failed plus 00, maps unknown as a conflict. Failed with empty/non-00 code maps failed; Pending remains pending. Unknown/null status remains unknown. Additional success spellings require fixture-backed additions to the explicit allowlist. The comment on `CoreTransferAck.outcome` already records BankOne approving with `00` plus the misspelled status `SuccesfulButFeeNotTaken`; Task 1 must confirm or rule out this and similar `Succesful*`/`Successful*` variants from fixtures before the allowlist ships, and add each confirmed spelling as an exact entry (still no substring matching). Apply the same status policy to intrabank live replies without a reversal field. Submission-only success from 00 is retained only where the backend fixture confirms that endpoint's completion semantics; interbank acceptance stays pending until authoritative status.

The existing `CoreTransferAck.outcome` getter (`00` → succeeded; substring `fail`/`declin` → failed) contradicts this policy and must be replaced, not extended: submission acknowledgements and live replies both classify through one shared allowlist function, and `core_flow_widgets.dart` reads the new classification.

Preserve a known terminal result when a later query fails or returns unknown/conflicting data; show a separate check warning instead of replacing the receipt. A later confirmed reversal can replace completed. Missing tracking reference only disables Check status: confirmed completed/failed stays completed/failed; accepted-but-pending or unknown stays Processing/Unconfirmed respectively, with balance/support actions and no resend. A lost response is Unconfirmed. Never substitute receipt reference/uniqueIdentifier for a tracking reference.

### Activation gates

Retain `stagingOnly: true` on every transfer capability; this plan does not activate production. Task 2 adds a transfer-authorization readiness gate, false by default, before Task 3 wires any PIN submit path; it prevents the PIN submit action until Tasks 1–4 pass and contract evidence is recorded. Task 5 only verifies and records the gate's evidence; it does not introduce it. Readiness requires: correct tracking fields and query shapes; fixture-confirmed intrabank/interbank status and submission outcome mapping; stable wrong-PIN discriminator; classified duplicate behavior with conservative unknown-409 handling; credential-safe logging; and navigation/session race checks. A missing wrong-PIN discriminator blocks readiness rather than shipping a misleading correction flow. Lockout threshold is not required because generic restricted copy is used. Missing bill PIN and durable lost-response recovery remain explicitly deferred and do not authorize their features. Production activation requires a separate release decision after staging device verification; it is not included in Task 5.

### Task 1: Model tracking identifiers and live status contracts

**Modify:** `lib/app/core_api_endpoints.dart`, `lib/module/core_banking/model/core_submission_models.dart`, `lib/module/core_banking/service/core_transfer_service.dart`.
**Create:** `lib/module/core_banking/model/core_transfer_requery_models.dart`.
**Tests:** `test/core_payments_models_test.dart`, `test/core_payments_service_test.dart`.

**Interfaces:** Extend `CoreTransferAck` with nullable `retrievalReference` and `transactionReference`. Replace `CoreTransferAck.outcome` with the shared allowlist classifier described under Outcome precedence. Add `CoreTransferKind { intrabank, interbank }`, `CoreTrackingReference(kind, value)` (Equatable, value equality), and `CoreLiveTransferStatus` with `state { completed, failed, pending, reversed, unknown }`, raw status, responseCode, trackingReference and isReversed. Service produces `Future<NotifierState<CoreLiveTransferStatus>> requeryTransfer(CoreTrackingReference tracking)`.

- [ ] Capture sanitized live OpenAPI definitions under `docs/verification/contracts/2026-10-07-core-pin-status.json`; record hash and confirm live provider status spellings/precedence using backend fixtures. Explicitly confirm or rule out `SuccesfulButFeeNotTaken` and other BankOne success variants on submission and re-query replies, and confirm whether interbank submission 500 still guarantees nothing moved. Use the exact outcome policy above; additional backend spellings require explicit fixture-backed allowlist entries. Record missing required evidence as an activation blocker. Stage the fixture with `git add -f` (`docs/` is gitignored).
- [ ] Add cases proving acknowledgment preserves both new identifiers separately; query uses transactionReference even if reference differs; intrabank rejects invalid 12-hex reference before network; query carries bearer and no amount/date/PIN/body; `Successful` maps completed, `Pending` pending, `Failed` failed, null/unrecognized unknown, isReversed overrides success; each fixture-confirmed variant such as `SuccesfulButFeeNotTaken` + `00` maps completed and an unconfirmed variant maps unknown; the replaced acknowledgement classifier no longer treats `00` with null/unknown status as completed or matches `fail`/`declin` substrings; two `CoreTrackingReference`s with the same kind and value are equal.
- [ ] Run `flutter test --no-pub test/core_payments_models_test.dart test/core_payments_service_test.dart`; confirm new cases fail before changes.
- [ ] Implement URI-encoded endpoint builders and service method; parse the existing success/message/data/meta envelope through ApiService. Keep cached interbank model untouched. Do not reuse submission error mapping for query failures.
- [ ] Update `core_flow_widgets.dart` only as far as needed to read the replaced classifier, so the build stays green.
- [ ] Run the same tests and confirm PASS; stage only named task files and contract fixture (`git add -f` for the fixture); commit `feat(core): model transfer tracking and live requery`.

### Task 2: Secure transaction PIN entry and readiness gate

**Modify:** `lib/module/core_banking/service/transaction_authorizer.dart`, `lib/module/core_banking/screens/core_flow_widgets.dart`, `lib/app/interceptors.dart` (mandatory credential-bearing error logging changes), `lib/app/feature_capability.dart` (readiness gate only).
**Create:** `lib/module/core_banking/screens/transaction_pin_sheet.dart`.
**Test:** `test/transaction_pin_sheet_test.dart`, `test/logging_redaction_test.dart`, `test/feature_capability_test.dart`.

**Interfaces:** Preserve the existing boolean authorizer for gated bills. Add a separate PIN collection API `Future<String?> collectCoreTransactionPin(BuildContext context, TransactionSummary summary, {String? errorMessage})`; null means cancel. The calling screen owns the returned string only while submitting. Add the transfer-authorization readiness gate, false by default, that every transfer PIN submit path must consult; while false, the PIN sheet's continue action is unavailable and no transfer POST can be sent.

- [ ] Add widget cases: fewer than four digits cannot continue, `0007` is returned unchanged, cancel returns null, input is obscured and emptied on close, review amount/recipient is shown. In `test/logging_redaction_test.dart`, keep a regression case for transactionPin in nested Map bodies (already redacted) and focus new cases on the `onError` gap: with staging logging enabled, a credential-bearing request whose exception message, `err.error` and string representation echo the PIN emits no PIN anywhere, including no raw stack trace. In `test/feature_capability_test.dart`, readiness defaults to false and blocks transfer authorization.
- [ ] Run `flutter test --no-pub test/transaction_pin_sheet_test.dart test/logging_redaction_test.dart test/feature_capability_test.dart`; confirm new cases fail.
- [ ] Implement modal with secure input and existing app styling. Clear TextEditingController on completion/disposal; disable interactive submit while already closing. No User Service verification call or biometric authorization shortcut.
- [ ] Implement the readiness gate in `feature_capability.dart`, false by default; do not touch `stagingOnly` or bill capability.
- [ ] Run targeted tests; confirm PASS; commit only task files as `feat(core): collect ephemeral transaction pin behind readiness gate`.

### Task 3: Credential-aware single submission and transfer UI wiring

**Modify:** `core_transfer_service.dart`, `provider/core_submission_notifier.dart`, `provider/intrabank_submission_providers.dart`, `provider/core_payments_providers.dart`, `model/core_submission_models.dart` under `lib/module/core_banking/`; the three transfer screens named above.
**Create:** `lib/module/core_banking/provider/core_transfer_attempt_provider.dart`.
**Tests:** `test/core_submission_test.dart`, `test/core_payments_providers_test.dart`; create `test/core_transfer_pin_ui_test.dart` and `test/core_transfer_attempt_provider_test.dart`.

**Interfaces:** Transfer service methods take `{required String transactionPin}`. Preserve bill signatures. Add transfer-only `submitAuthorized(D draft, {required String transactionPin})` through a dedicated transfer notifier base; do not make PIN optional for transfer calls. Store a non-secret session-scoped attempt record keyed by local attempt ID, with draft, outcome and tracking reference, never PIN. Add an explicit wrong-PIN rejection only when response classification is reliable; generic unauthorized gets safe Core access copy.

- [ ] Verify wrong-PIN response fixture/error discriminator with backend; document generic bearer 401 fallback. Do not assume three-attempt lockout. Apply the rejection and duplicate rules above; unknown 409 also prohibits manual retry. Record the verified wire codes in the contract fixture.
- [ ] Add cases: all four request bodies include transactionPin and reviewed draft fields; PIN absent from notifier state/toString; cancel sends zero requests; double tap sends one; wrong PIN reopens PIN entry (not review) and allows correction without logout; accepted/unknown attempt cannot resend after back/re-entry or a changed draft; logout ignores delayed response; two Confirm taps open one PIN modal; unresolved unacknowledged attempts resume across all transfer entries; terminal outcomes permit Start new transfer; classified/unknown duplicate 409 cannot resend. Restriction/lockout stops submit and shows safe copy. Unresolved escape: Processing and Unconfirmed (including lost response with no tracking) show "Start a different transfer"; cancelling the confirmation keeps the result; confirming acknowledges the attempt, keeps it listed and checkable, opens an empty form with no prefill, and never resends it; no escape while submitting. Local `LocalSessionExpired` 401 is a definite non-send that follows the User Service expiry flow, while a remote unrecognized 401 preserves login. Interbank 500 maps to rejection only with the fixture-confirmed discriminator, otherwise Unconfirmed. With the readiness gate false, no transfer POST is sent.
- [ ] Run `flutter test --no-pub test/core_submission_test.dart test/core_payments_providers_test.dart test/core_transfer_pin_ui_test.dart test/core_transfer_attempt_provider_test.dart`; confirm new cases fail.
- [ ] Implement transfer-only submission path and retain attempt guard beyond screen disposal. Do not use a stored callback capturing PIN. Screens collect PIN after review, submit once, clear local input references in finally, and switch to existing result widgets. Definite wrong PIN reopens PIN entry on the same attempt; uncertain result stays on result with no Resend, offering only the acknowledged escape. Implement the attempt ownership/navigation API above; remove screen-init clears and retire old transfer submit entry points. Keep terminal receipts until explicit Start new transfer; bills retain their current notifier path.
- [ ] Run targeted tests; confirm PASS; commit named files as `feat(core): authorize transfer submissions with transaction pin`.

### Task 4: Connect live reconciliation to result UI

**Modify:** `lib/module/core_banking/provider/core_transfer_attempt_provider.dart` (owns live re-query state), three transfer screens and `core_flow_widgets.dart`; use existing account providers for balance refresh.
**Tests:** extend `test/core_transfer_attempt_provider_test.dart`; create `test/core_transfer_requery_ui_test.dart`.

**Interfaces:** Implement `check(attemptId)` on the attempt provider, for the current attempt and acknowledged unresolved attempts alike. Each attempt record holds last good live result, check inFlight and check error; there is no separate re-query provider, so the "never overwrite a confirmed result" rule lives in one place. Result widgets read the attempt record; completion is associated with attempt/customer, not screen-local state.

- [ ] Add cases: repeated Check status taps produce one query; loading disables the button; cached interbank result cannot overwrite newer live result; query 500/404/network error retains transaction state; unknown/missing reference makes no query; reversal overrides success; account switch discards late result; transition to completed/reversed triggers one balance refresh; checking an acknowledged unresolved attempt updates only that attempt's entry and never the current attempt.
- [ ] Run `flutter test --no-pub test/core_transfer_attempt_provider_test.dart test/core_transfer_requery_ui_test.dart`; confirm FAIL before implementation.
- [ ] Implement result actions: Checking…, Check status, Check again; Completed, Failed, Processing, Reversed and Unconfirmed presentation. Use transactionReference for interbank and retrievalReference for intrabank. Preserve shared animation/receipt details. No automatic polling. Apply the missing-reference policy above: preserve confirmed terminal outcomes, disable checking without tracking, and use Unconfirmed only for uncertain outcomes. Include tests for a successful acknowledgment without tracking, a lost response, conflicting live fields and unknown query after confirmed completion.
- [ ] Run tests; confirm PASS; commit task files as `feat(core): reconcile transfer outcomes in result screens`.

### Task 5: Capability wiring and release verification

**Modify:** `lib/app/feature_capability.dart`, `docs/verification/core-banking-integration.md`, the two 2 October Core plans (add dated supersession links only).
**Tests:** existing `test/transaction_availability_test.dart`, `test/core_network_test.dart`, full suite.

- [ ] Update operation metadata to include both mobile re-query POST templates as Core reads; keep moneyMoving set restricted to money POSTs. Preserve missing-configuration behavior. Keep stagingOnly restrictions and the readiness gate added in Task 2; this task records its evidence and decides whether staging readiness may flip, it does not create the gate. Test readiness false before contract evidence and tests pass, and verify production remains unavailable even when staging readiness is true. Do not enable bill capability through this transfer authorizer.
- [ ] Run `flutter analyze` and `flutter test --no-pub`; require no analyzer errors and all tests passing. Record actual command results, not historic counts. Inspect diff for accidental inclusion of unrelated dirty files.
- [ ] On authenticated staging with approved test accounts, verify all four review→PIN→result paths, one incorrect PIN attempt, safe restriction fixture, cached-vs-live status, navigation retry guard, the acknowledged unresolved escape, Core401 isolation, missing Core config and session-switch behavior. Use backend-controlled pending/reversal/error cases rather than creating repeated transfers to force failures. Record sanitized request IDs and device/platform evidence; unresolved gates stay unchecked.
- [ ] Update verification doc and dated links in old plans; record missing-reference recovery, provider-status contract and bill PIN gaps. Stage new `docs/` files with `git add -f`. Commit only task-owned changes as `docs(core): verify pin and live status integration`.

## Deferred backend dependencies

1. A lost response leaves the client without the generated query reference. Require client-generated idempotency/reference support or an owned-attempt/history lookup for durable recovery; never invent such an endpoint.
2. Mobile bill payment PIN contract is absent. Keep its existing gate; update its request and UI in a separate follow-up once published.
3. PIN errors need a stable discriminator from bearer authentication errors; lockout/recovery rules need backend documentation.
4. Provider status/responseCode conflicts and successful spellings (including `SuccesfulButFeeNotTaken`) need authoritative fixtures. Until resolved, fail to Unconfirmed rather than manufacture a terminal outcome.
5. Interbank submission 500 semantics need re-confirmation now that Core verifies the PIN through User Service. Until confirmed, treat it as Unconfirmed.

## Handoff

Review this plan and its linked design before implementation. Execute Tasks 1–5 in order; task-level contract gates block only the dependent behavior. No product code was changed when preparing this plan.
