# Execution Log: KYC Catalogue + Core Banking Integration

Durable pick-up notes for executing:

1. `docs/superpowers/plans/2026-10-01-kyc-provider-document-catalogue.md` (KYC)
2. `docs/superpowers/plans/2026-10-02-core-banking-transfers-bills.md` (Core)

Executor: inline (`superpowers:executing-plans`), started 2026-10-02.

## How to resume

- Worktree: `.claude/worktrees/core-kyc-integration` on branch
  `feat/kyc-catalogue-core-banking`, branched from `ac3c815`
  (`feat/figma-flow-integration`).
- Read the **Status** table below, then `git log --oneline ac3c815..HEAD`.
  A task marked complete has its commits on the branch; do not redo it.
- Resume at the first task not marked complete. Read its section in the plan
  and every **Adjustment** below that names it.
- `docs/` is git-ignored in this repo; the plans and this log are force-added
  (`git add -f`) so they travel with the branch.

## Starting state

- Baseline: `flutter test --no-pub` → 1075 passing, 0 failing on `ac3c815`.
- Your uncommitted capture-launch work (`_launchingKycCapture`,
  `_warmUpSmileId` in `kyc_screens.dart`/`app_flow_navigator.dart`, the blank
  `CORE_BASE_URL=` line in `.env.example`, and a trailing newline in
  `onboarding_flow_screens.dart`) stays **untouched in the main checkout**. It
  is not on this branch. Expect overlap in `kyc_screens.dart` and
  `app_flow_navigator.dart` when the two are combined.

## Human checkpoint answers (2026-10-02)

| Checkpoint | Answer |
|---|---|
| Working-tree preflight | Worktree from HEAD; leave WIP in main checkout. |
| KYC Task 0: Dojah `national_id` | Verified by the user; enable `nationalId` for Dojah. |
| Core Task 3 gate: token + ledger equality | Confirmed by the user; proceed with Home/Savings cutover. Request IDs/masked evidence were not supplied in-session. |
| Core Tasks 4-5 fixtures | Not available; Tasks 4-5 deferred as blocked. |

## Status

| Plan | Task | Status | Commits | Notes |
|---|---|---|---|---|
| KYC | 0 | complete (human) | — | Verified by user. |
| KYC | 1 | complete | `6453e14` | nationalId, nullable Smile spec, optional number, config models |
| KYC | 2 | complete | `c27d6cb` | Two authenticated GETs + capability |
| KYC | 3 | complete | `7bfc295` | Session-scoped notifiers, env check |
| KYC | 4 | complete | `7e87465` | Live-configured form |
| KYC | 5 | complete (device check open) | `b9c8802` | README + dojah-kyc.md |
| Core | 1 | pending | | |
| Core | 2 | pending | | |
| Core | 3 | pending | | |
| Core | 4 | blocked | — | Needs sanitized bank-list/name-enquiry fixtures. |
| Core | 5 | blocked | — | Needs biller/category/payment-item fixtures, classification, string amounts; product decision. |
| Core | 6 | pending | | |
| Core | 7 | pending | | Device verification is a human checkpoint. |

## Adjustments and rulings

Format: `Ruling: <what> — <why> — <cost if wrong>`.

- Setup: Ruling: worktree created with `git worktree add` from HEAD rather than
  the native tool — the native tool branches from `origin/main`, which lacks
  this branch's work — cost if wrong: none; the branch is ordinary.
- Setup: Ruling: `.claude/worktrees/` and `.superpowers/` added to
  `.git/info/exclude` (local only) instead of committing `.gitignore` —
  avoids a commit on your branch for local tooling — cost if wrong: other
  clones must ignore these themselves.
- Setup: Ruling: skill helper scripts (`task-start`, `task-done`,
  `sdd-workspace`) cannot run under the worktree sandbox; bookkeeping is done
  by hand in this log and `.superpowers/sdd/*/progress.md` — cost if wrong:
  none functionally.
- Setup: Ruling: plans and this log are force-added under `docs/` (ignored
  directory, existing precedent: `docs/verification/dojah-kyc.md`) — so pickup
  works from any checkout — cost if wrong: remove with `git rm --cached`.
- KYC Task 0: Ruling: `nationalId` enabled for Dojah on the user's stated
  verification; no device evidence recorded in-session — cost if wrong: NIN is
  offered but Dojah's widget rejects it; revert is one line in
  `isEnabledFor` plus its test.
- Core Tasks 4-5: Ruling: deferred, capabilities stay unregistered — the plan's
  gate forbids implementing from unattached component schemas — cost if wrong:
  none; they remain unavailable as today.
- User directive (during KYC Task 2): Dojah is the default liveness/KYC SDK;
  write only the minimum necessary tests per implementation. Ruling: the
  plans' exhaustive edge-case matrices (320px/200%-text cases, every
  malformed-row variant) are skipped; one test per behavior that could
  silently break — cost if wrong: untested edge cases surface later.
- KYC Task 1: Ruling: `test/smile_id_gateway_test.dart` passport-mapping test
  rewritten to `voter_id`, plus a rejection test — the plan requires Smile
  jobs only for Smile-enabled types — cost if wrong: Smile passport jobs
  cannot be built (they were already blocked at launch).
- KYC Task 1: Ruling: environment parsed into `KycProviderEnvironment`
  (`sandbox`/`live`) — matches the OpenAPI enum.
- KYC Task 3: Ruling: environment pairing is the pure function
  `providerEnvironmentMatches`; KYC Task 4 added `appBuildEnvironmentProvider`
  so widget tests can act as a staging build.
- KYC Task 4: Ruling: TDD order slipped; the screen was written before its
  widget tests. The new tests assert catalogue-only labels, so they cannot
  pass against the old screen, but RED was not observed.
- KYC Task 4: Ruling: shared fixtures in
  `test/support/kyc_configuration_fixtures.dart`; `flowTestOverrides()` now
  runs as a staging build.
- KYC Task 5: Ruling: `docs/SMILE_ID_V12_UPGRADE_PLAN.md` and
  `plan/USER_SERVICE_CONTRACT_GAPS.md` exist only untracked in the main
  checkout, so the Smile v12 expiry blocker is recorded in the README instead.
- KYC Task 5: device verification (human checkpoint) remains open.

