# Core transaction PIN and live status UI design

Date: 7 October 2026. Status: proposed for review; implementation not started.

## Intent and scope

Integrate the newly documented mobile transfer PIN and live BankOne re-query contracts with the existing own-account, savings-withdrawal, BOCTRUST-transfer and other-bank flows. Reuse the existing review and animated result UI. Keep User Service session behavior isolated from Core errors. Bill payment authorization is a separate gated follow-up because its mobile schema has no PIN field.

Source: https://core-dev-api.centurysoftware.dev/api/v1/docs/ . Swagger init inspected 7 October 2026, SHA-256 `920fbbc499d986ebf79a47ddabb0a221e35b335b217cc36cdcaf4af19730b28c`. Re-fetch before implementation; preserve a sanitized contract fixture. This design supersedes the PIN-body prohibition and cached-only status behavior in the 2 October Core plans for these transfer endpoints only.

## Chosen approach

Collect a four-digit PIN on a dedicated secure modal after the existing review step and send it on the actual Core transfer POST. Core verifies it against User Service. Do not pre-verify through `/auth/pin/verify-current`; do not substitute biometric login for the required PIN. This follows the published contract and avoids two independently authorized requests. An alternative pre-verification/token flow would require a new backend contract. Keeping only cached status would fail to reconcile provider outcomes, so use dedicated live re-query actions.

PINs remain ephemeral local input: no provider state, draft equality, receipt, route argument, persistence, analytics, logging or exception text. Clear controller and drop local references after submission/cancel/disposal; Dart strings cannot guarantee memory zeroization. Leading zeros are valid.

## UI behavior

Form → Review → PIN → Submitting → Result. Cancel returns to review without a request. Wrong PIN reopens PIN entry on the same reviewed attempt with an empty field and a safe error (not the review step); no automatic retry. Core 403 shows restricted/locked copy without guessing a lockout threshold. A generic remote Core 401 must not log the user out or be mislabeled wrong PIN without a distinguishing backend error. A local session expiry (the client's `LocalSessionExpired` path, also surfaced as 401) is different: the request was never sent, so nothing moved, and the normal User Service expiry flow applies.

Own-account moves, withdrawals and BOCTRUST transfers use `retrievalReference` for re-query. Interbank uses `transactionReference`, never nullable BankOne `reference` or `uniqueIdentifier`. Receipt references and query identifiers are separate fields.

“Check status” submits a bodyless authenticated POST to the mobile re-query endpoint; it never submits another transfer. Show Checking while in flight. Live successful/failed/pending states map to Completed/Failed/Processing. Interbank `isReversed: true` overrides success with Reversed; unknown/null statuses stay unconfirmed. Cached interbank GET status is a separate model and must not override a newer live result.

On query 500/network error, keep the last known transaction result and offer Check again. Query 404 means no matching owned tracking record, not a failed transfer. Completed or reversed reconciliation refreshes affected account balances once per outcome transition. Do not infer completion from HTTP 200 alone.

Accepted or uncertain submission attempts cannot be resent by double tap, navigation back, screen recreation or a changed draft for the same unresolved attempt. Use one shared session-owned transfer attempt across all four operations. Reserve before PIN entry, resume unresolved result on any transfer entry, remove screen-init clears, and allow Start new transfer directly after terminal outcome/definite rejection. Wrong PIN permits correction on the same reviewed attempt. Clear on logout/account switch and ignore late results. No automatic polling or background submission retry in this slice. Process-restart reconciliation requires a later approved persistence/history contract; this slice makes no durable recovery promise.

An unresolved attempt (Processing or Unconfirmed) must not lock the customer out of transfers for the rest of the session, because a lost response can never resolve and an interbank transfer can stay pending for a long time. Its result therefore offers a secondary "Start a different transfer" action behind an explicit acknowledgement: "This transfer may still go through. Check your balance first — sending it again could pay twice." Confirming parks the attempt as an acknowledged unresolved attempt for the session (still visible and, with a tracking reference, still checkable), and opens an empty form with no prefill from the unresolved draft, so a duplicate needs deliberate re-entry. The old attempt is never resent. While a submission is in flight, no escape is offered. Logout is not offered as a way out.

If the entire submission response is lost, no tracking reference is available. Show Unconfirmed and a balance/support action, with no Check status request and no Resend action; the acknowledged escape above is the only way to start another transfer. Backend recovery/idempotency support is an explicit remaining dependency.

## Contract boundaries

- Four money-moving transfer/withdrawal bodies require `transactionPin` matching `^\d{4}$`; amounts remain exact Kobo strings.
- POST `/me/intrabank/transfers/{retrievalReference}/requery`: 12 lowercase hex characters; returns retrievalReference, nullable provider status, responseCode, nullable reference.
- POST `/me/interbank/transfers/{reference}/requery`: path uses transactionReference; returns transactionReference, nullable provider status, responseCode, isReversed.
- Both re-queries are bearer-authenticated, bodyless and read-only in effect. Core resolves original date/amount.
- GET interbank status continues to return cached pending/completed/failed.
- Provider status strings are not a closed enum. Confirm successful spellings and status/responseCode precedence with sanitized fixtures; unknown values remain unconfirmed. Existing code already documents BankOne returning the misspelled `SuccesfulButFeeNotTaken` with `00` for an approved transaction; the fixture task must confirm or rule out this and similar variants before the strict allowlist ships, or real successes will show as Unconfirmed.
- The existing client treats an interbank submission 500 as a definite rejection (failed name enquiry). Now that Core verifies the PIN through User Service, re-confirm against the current contract that every interbank 500 still means nothing moved; if not, it becomes Unconfirmed.
- Mobile bills remain gated until backend specifies PIN, errors and authorization. Do not borrow service-to-service `/bills/payments` fields.

## Acceptance

Each transfer path sends one reviewed request with an ephemeral PIN; cancel sends none. Wrong PIN can be corrected without logout, while ambiguous submissions cannot be resent. An unresolved attempt never blocks further transfers beyond an explicit acknowledgement. The correct query identifier drives live status UI. Read retries never move money. Navigation/session races cannot leak credentials or attach outcomes to another customer. Missing Core configuration leaves these flows unavailable.

## Engineering-review decisions

The implementation plan's “Decisions resolved by engineering review” section is normative for exact attempt APIs, response classification, logging, status precedence and activation gates. Unknown/duplicate 409 is unresolved and has no manual Retry; only fixture-confirmed reference collision permits an immediate new attempt, and every other unresolved outcome uses the acknowledged escape. Missing tracking disables checking without overriding a confirmed terminal outcome. Credential-bearing error logging suppresses raw exception message/error/stack trace even in staging. Live status uses the explicit allowlist with reversal first and conflicts unknown; later failed/unknown queries cannot erase confirmed results. Retain staging-only restrictions, with authorization readiness false until required contract evidence and tests pass; the readiness gate exists before any PIN submit path is wired, so no intermediate commit can send a PIN-authorized transfer. Production activation is a separate release decision.
