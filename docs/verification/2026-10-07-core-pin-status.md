# Core transaction PIN and live status: verification

Date: 7 October 2026. Branch `feat/core-pin-live-status`.
Spec: [design](../superpowers/specs/2026-10-07-core-pin-status-ui-design.md). Plan: [integration plan](../superpowers/plans/2026-10-07-core-pin-status-ui-integration.md).
Contract: [sanitized fixture](contracts/2026-10-07-core-pin-status.json), Swagger init SHA-256 `920fbbc4…b28c`, matching the hash recorded in the spec.

The published Core API docs are the source of truth for every contract question below.

## What shipped

- All four transfer and withdrawal POSTs send `transactionPin` from a four-digit sheet opened after review. The PIN lives only in one local variable for one request; it is never in state, drafts, routes or logs.
- One session-scoped attempt is shared by all four flows. An attempt is sent at most once per PIN entry. An unresolved attempt resumes from any transfer entry. "Start a different transfer" sets it aside only after an explicit warning; set-aside transfers stay listed above each form and can still be checked.
- Responses are classified per the docs:
  - 401 means the PIN is incorrect, and the same attempt can be corrected.
  - A 401 the client produced itself for an expired session was never sent, and follows the normal sign-out flow.
  - 403 means the account is restricted or PIN-locked.
  - 409 means a reference collision or a similar transfer within 60 seconds; either way this request was not sent.
  - An interbank 500 means the recipient was unresolved or the transfer was rejected.
  - A 200 means the transfer was accepted, which is shown as Processing.
- Check status sends a bodyless POST to the live re-query, keyed on `retrievalReference` for intrabank and `transactionReference` for interbank; receipt references are never used. A final live result can be replaced only by a reversal. A completed or reversed result refreshes balances once.
- Request bodies that carry a credential never log the raw exception message, error or stack trace, in any environment, and every echo of the PIN is masked.

## Commands (actual results)

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1460 passed, 0 failed (includes concurrent unrelated working-tree edits).

## Gates still open

- [ ] `kTransferAuthorizationEvidenceReady` stays `false`. Before flipping it, run the staging device verification below.
- [ ] Staging device verification with approved test accounts was **not performed**: the four review→PIN→result paths, one incorrect PIN, the restricted fixture, live-versus-cached status, the navigation guard, the set-aside escape, Core 401 isolation, missing Core configuration and session switch. Use backend-controlled pending, reversal and error cases rather than repeated real transfers.
- [ ] Intrabank `00` is shown as Processing until checked; the docs say only "accepted". Promote it to completed only if the backend documents `00` as final.
- [ ] The production release decision is separate. `stagingOnly` remains on every transfer capability.

## Deferred backend dependencies

1. Lost-response recovery: with no tracking reference, the attempt can only be set aside. This needs a client idempotency key or an owned-attempt lookup.
2. The mobile bill-payment PIN contract is absent; bills keep their existing gate.
3. The lockout threshold is undocumented, so generic restricted copy is used.
