# Zoho Desk Server-Side Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure Zoho Desk and the BOCTRUST backend so the mobile app can securely authenticate customers into tickets, knowledge base, and Business Messaging, and receive correctly isolated support notifications in staging and production.

**Architecture:** Zoho Desk ASAP owns support content, tickets, chat, and support push delivery. The BOCTRUST User Service owns customer eligibility and exposes one authenticated session endpoint that signs a short-lived Zoho JWT using a server-only secret. Staging and production use separate Zoho add-ons, secrets, support configuration, and push credentials; the mobile app receives only non-secret initialization IDs and the short-lived customer JWT.

**Tech Stack:** Existing BOCTRUST User Service and API envelope, existing bearer-token authentication, the backend's current configuration/secret manager/test framework, Zoho Desk ASAP 2.x, HS256 JWT, Firebase Cloud Messaging, Apple Push Notification service, OpenAPI, UTC timestamps.

**Spec:** `docs/superpowers/specs/2026-10-02-zoho-desk-support-design.md`

**Authoritative references:**
- Zoho Desk Flutter authentication: `https://help.zoho.com/portal/en/kb/desk/developer-space/asap/flutter-sdk/articles/how-to-authenticate-users-on-your-mobile-apps-with-flutter-apps`
- Zoho Desk ASAP JWT claims and legacy-flow distinction: `https://help.zoho.com/portal/en/kb/desk/developer-space/asap/general/articles/jwt-for-authenticating-users-in-the-asap-add-ons`
- OpenAPI response-property semantics: `https://spec.openapis.org/oas/v3.0.4.html`
- Sensitive token response caching controls: `https://www.rfc-editor.org/rfc/rfc6749.html`

## Repository Boundary

The Flutter repository does not contain the BOCTRUST backend. This plan therefore does not invent backend language-specific source paths or commands. Task 1 must be performed in the User Service repository and records its real controller, service, configuration, OpenAPI, and test paths before code changes begin. All API names, configuration keys, claims, error codes, limits, and acceptance checks below are fixed and must not be renamed during path discovery. The only permitted exception is the name-claim confirmation in Task 3 Step 2, which must be recorded in the runbook and reflected back into this plan before Task 5 begins.

## Global Constraints

- The Zoho ASAP JWT secret, OAuth credentials, agent credentials, FCM server credentials, and APNs private material remain server-side and must never be shipped in Flutter configuration.
- The session endpoint is exactly `POST /api/v1/me/support/zoho/session`. It accepts an absent body or the empty JSON object `{}`; any other body is rejected, and no request value can supply identity.
- The backend derives identity from the authenticated BOCTRUST session and authoritative user record.
- Zoho authentication requires a non-empty verified email that belongs to exactly one active BOCTRUST customer. Zoho identifies the contact solely by the `email` claim, so a shared email would merge two customers' tickets and chats; the endpoint refuses to sign for a non-unique email.
- JWT signing uses HS256 with `email`, `email_verified`, `first_name`, `last_name`, `not_before`, and `not_after` claims; the two time claims use Unix epoch milliseconds as required by Zoho ASAP.
- Set `not_before` to server time minus 30 seconds and `not_after` to server time plus 5 minutes. Configuration validation enforces `ZOHO_DESK_SESSION_TTL_SECONDS + ZOHO_DESK_SESSION_NOT_BEFORE_SKEW_SECONDS < 600`, so the complete validity window stays strictly below Zoho's 600000-millisecond maximum for any configured skew.
- JWT and response expiry values are computed from the same captured UTC clock value.
- JWTs are returned to the authenticated client but are never persisted, logged, traced, cached across customers, or included in analytics/error reporting.
- Every response from the support-session endpoint must include `Cache-Control: no-store` and `Pragma: no-cache` so JWTs and related error details are not retained by clients or intermediaries.
- The backend must not place NIN, BVN, OTP, password, PIN, access/refresh token, FCM token, account/card number, balance, transaction reference, or identity-document data in JWT claims.
- Zoho failure must not expire a valid BOCTRUST session unless the existing User Service authentication layer independently reports the BOCTRUST token invalid.
- Staging and production use separate Zoho ASAP add-ons and server secrets.
- Disabling issuance on the server stops new Zoho logins only; it does not end Zoho SDK sessions that are already signed in. A hard stop requires the Zoho-side add-on/module disable documented in Task 7 and exercised in Task 11.
- Zoho data-centre location, cross-border processing, and vendor/DPA approval are decided before any Zoho organization or add-on is created, because an organization's data centre cannot be changed later.
- Production support remains disabled until administrative setup, automated tests, physical-device tests, and agent workflow acceptance pass.
- Production support remains disabled until Security/Privacy approves Zoho data residency, retention/deletion, attachment retention, agent access controls, vendor/DPA requirements, cross-border processing, customer privacy notice, and data-subject request handling.

## Review Focus

- A token request begun for customer A must never return or cache a JWT for customer B after logout or account switching; Task 5 adds concurrency and identity-isolation tests.
- Missing, blank, syntactically invalid, or unverified email must return the stable verification-required error without signing a JWT; Task 5 tests every case.
- A verified email shared by more than one active customer must return `SUPPORT_EMAIL_CONFLICT` without signing a JWT; Tasks 1 and 5 establish and test uniqueness.
- Server clock skew and boundary timestamps must not create already-expired or over-ten-minute JWTs; Task 5 adds deterministic clock tests.
- Secrets and JWTs must be redacted from application logs, HTTP logs, traces, metrics labels, and exception reporting; Task 7 adds canary-secret log scans.
- Staging credentials, mobile identifiers, push credentials, and Zoho add-on IDs must never resolve in production or vice versa; Tasks 2, 3, and 9 add environment-isolation checks.
- Customers outside the release cohort must receive the stable `SUPPORT_NOT_ENABLED_FOR_CUSTOMER` response without a JWT being signed; Tasks 6 and 11 test it.
- Rollback must distinguish stopping new logins from ending existing Zoho sessions; Tasks 7, 10, and 11 document and exercise both.

## Plan Review Notes (2026-10-02)

A review of this plan against the design spec and Zoho's published ASAP documentation found the issues below. The plan text has been revised to address each one; this section records why the changes exist and what still has to happen outside this document.

### Verified against Zoho documentation

- JWTs are signed with HMAC-SHA256 only.
- `email`, `email_verified`, `not_before`, and `not_after` are required; the two time claims are Unix epoch milliseconds.
- `not_after - not_before` must not exceed 600000 milliseconds (ten minutes).
- The Flutter SDK logs in with `ZohodeskPortalApikit.login(jwtToken, callback)`.
- Zoho's JWT page does **not** document first- or last-name claim names; `first_name` and `last_name` are unconfirmed (see open item 3).

### Blockers found in review (addressed in the plan text)

| # | Issue | Risk if unaddressed | Resolution in this plan |
|---|-------|---------------------|-------------------------|
| B1 | TTL was capped at a fixed 570 seconds while the skew was separately configurable; the plan also said both "below" and "not exceeding" ten minutes. | A skew of 60 seconds with TTL 570 produces a 630-second window that Zoho rejects. | Global Constraints and Task 4: enforce `TTL + skew < 600`, with boundary tests. Task 5 asserts a window strictly below 600000 ms. |
| B2 | Zoho identifies a customer only by the `email` claim, and email uniqueness across BOCTRUST customers was never established. | Two customers sharing a verified email are merged into one Zoho contact and see each other's tickets and chats. An email change silently loses ticket history. | Global Constraints, Task 1 inventory, Task 5 tests, Task 6 `409 SUPPORT_EMAIL_CONFLICT`, Task 8 Step 9 email-change procedure. |
| B3 | Data-centre and cross-border approval happened in Task 8, after Task 3 had already created the Zoho organization and add-on. | A Zoho organization's data centre cannot be changed, so a late rejection forces a full rebuild. | Task 2 Step 5 obtains data-residency pre-approval; Task 3 is blocked until it is recorded. |
| B4 | Rollback assumed disabling the server endpoint immediately removed support access. | The JWT is used only at login; customers already signed in to the Zoho SDK keep access, so an incident rollback would not stop exposure. | Global Constraints, Task 7 Step 7 soft disable vs hard stop, Task 10 Step 5 observation, Task 11 Step 7 exercises both. |
| B5 | Release-cohort gating had no defined response for non-members. | Inconsistent client behavior, possible misclassification as session expiry, and no way to test the gate. | Task 6 adds `403 SUPPORT_NOT_ENABLED_FOR_CUSTOMER` behind an injectable `isSupportEnabledForCustomer` check and a fixed check order; Task 11 Step 4 wires the cohort mechanism into it. |

### Other changes from review

- **Hidden ticket fields are client-supplied.** `cf_` context fields are set by the app through the SDK and can be forged by a modified client. Task 8 Step 5 requires agents to treat them as unverified and identify customers by the JWT-established Zoho contact email plus the BOCTRUST back-office check.
- **APNs mode follows distribution, not environment.** TestFlight and ad hoc builds use production APNs even with the staging bundle ID. Task 2 records distribution methods; Task 9 configures and tests the matching mode.
- **Name claims.** Task 3 Step 2 confirms the name claim names before Task 5; missing names are omitted rather than sent empty.
- **Request body.** An absent body or `{}` is accepted; any other body, including `null`, returns `400`.
- **Minor.** `cf_os_version` added to match the spec's allowed context; the expected-configuration manifest uses production placeholders until Task 11; the production secret entry stays empty until Task 11; secret rotation names a specific internal verification account and check.

### Open items and external dependencies

These are not resolved by editing this plan and must be closed by the named owner before the gated task starts.

| # | Item | Owner (assigned in Task 1) | Gates |
|---|------|----------------------------|-------|
| O1 | **Design spec is out of sync.** `docs/superpowers/specs/2026-10-02-zoho-desk-support-design.md` does not yet describe `403 SUPPORT_NOT_ENABLED_FOR_CUSTOMER`, `409 SUPPORT_EMAIL_CONFLICT`, the absent-or-`{}` body rule, `cf_os_version`, or soft-disable vs hard-stop semantics, and its client error handling has no entries for the two new codes. | Mobile integration owner with User Service endpoint owner | Task 6 |
| O2 | **Mobile staging build does not exist.** The Flutter repository has no Android product flavors and only the default iOS `Runner` scheme; staging identities need flavors/schemes, staging Firebase apps, and provisioning profiles, and no mobile plan currently covers this. | Mobile integration owner | Tasks 9 and 10 |
| O3 | **Name claim names unconfirmed** with Zoho (`first_name`/`last_name`). | Zoho Desk administrator | Task 5 |
| O4 | **Verified-email uniqueness** must be confirmed in the User Service data model, and any existing duplicates counted and resolved. | User Service endpoint owner | Task 5 |
| O5 | **Data-residency pre-approval** (data centre, cross-border processing, DPA, lawful basis). | Security/Privacy approver | Task 3 |
| O6 | **Hard-stop effect on signed-in SDK sessions** is unknown until observed in staging. | Zoho Desk administrator | Task 11 rollout |
| O7 | **Client handling of `SUPPORT_NOT_ENABLED_FOR_CUSTOMER`.** The knowledge base can open without a JWT, so the mobile integration must decide whether the Support hub is hidden or limited for non-cohort customers. | Mobile integration owner | Task 11 Step 5 |
| O8 | **`cf_boctrust_customer_ref` value** must be identified and approved; it must not be a raw internal customer ID without explicit Security/Privacy approval. | Security/Privacy approver | Task 8 Step 3 |

### Stakeholder Questions and Proposed Answers

Each answer is either **Confirmed** (established by the design spec, this plan, or the Flutter repository) or **Proposed** (the recommended default this plan is written against, pending sign-off by the named owner). A Proposed answer that is rejected must be reflected back into the affected tasks before they start.

**Q1. Are the Zoho data centre and privacy approval confirmed before Zoho objects are created?**
**Proposed.** Approval is required before *any* Zoho organization or add-on is created, staging included, not only production. The data centre is fixed when an organization is created, and staging is created first (Task 3). Security/Privacy records the data centre, permitted cross-border processing, vendor/DPA, and lawful basis in `data-governance-approval.md` under Task 2 Step 5. Recommended choice: the Zoho data centre that satisfies BOCTRUST's regulatory obligations for Nigerian customer data, as determined by Security/Privacy and compliance; this plan does not presume a region. Owner: Security/Privacy approver. Gates: Task 3.

**Q2. Are staging and production Zoho ASAP add-ons separate?**
**Confirmed** for add-ons: separate add-ons with separate JWT secrets, application identities, and push credentials are a Global Constraint.
**Proposed** for the organization question this leaves open: use **one Zoho Desk organization** with two add-ons, keeping staging isolated through a dedicated staging department, staging-only agent team, and separate ticket views/reports. Rationale: one data-centre decision, one licence pool, and the production department/layout can be built and accepted in the same organization. Conditions if accepted: staging tickets must never route into the production `Customer Support` department, production SLA timers, or production reports; staging agents must not have access to the production department. Use **separate organizations** instead if Security/Privacy requires that staging agents or testers never share a tenant with real customer data, or if licensing allows it at acceptable cost; in that case each organization records its own data-centre approval under Q1. Owner: Zoho Desk administrator with Security/Privacy approver. Gates: Task 3.

**Q3. What are the email uniqueness rules in BOCTRUST data?**
**Proposed.** Policy: a verified email may belong to at most one active customer, compared case-insensitively after trimming. Before Task 5, the User Service owner (a) reports whether a database constraint enforces this, (b) counts existing duplicate verified emails, and (c) agrees a resolution path for any duplicates with Support Operations. The endpoint enforces the rule regardless, returning `409 SUPPORT_EMAIL_CONFLICT` without signing (Task 5, Task 6). Affected customers keep call/email support and are told to contact support to resolve the shared address. Email changes follow the Task 8 Step 9 procedure: the Zoho Desk administrator updates the existing Zoho contact's email after the BOCTRUST change is verified, so ticket history follows the customer and the old address cannot be claimed by someone else. Owner: User Service endpoint owner. Gates: Task 5.

**Q4. Will mobile use the Zoho SDK for tickets, chat, and the knowledge base rather than backend ticket APIs?**
**Confirmed.** The design spec places tickets, knowledge base, and Business Messaging in the Zoho ASAP SDK, and the backend only issues the login JWT. The backend therefore makes no Zoho REST API calls and needs no Zoho OAuth client credentials for this release; the "OAuth credentials" reference in Global Constraints is a prohibition on shipping any such credentials in the app, not a requirement to create them. Any future server-side use (reporting, webhooks, server-created tickets) needs its own design and plan. Owner: Mobile integration owner. Gates: none.

**Q5. Does mobile handle disabled and non-cohort support states?**
**Proposed** client behavior (the spec must be updated to match, open item O1):

| Response | App behavior |
|----------|--------------|
| `401` | Existing session-expiry flow. |
| `503 SUPPORT_INTEGRATION_DISABLED` | Support-unavailable state; call and email remain. |
| `503 SUPPORT_CONFIGURATION_ERROR` / `SUPPORT_SESSION_UNAVAILABLE` | Support-unavailable state with one manual retry; call and email remain. |
| `403 SUPPORT_NOT_ENABLED_FOR_CUSTOMER` | Hide Zoho entry points (tickets, chat, and knowledge base) and show call and email only. Never treat as session expiry. |
| `409 SUPPORT_EMAIL_CONFLICT` | Explain that online support is unavailable for this account and offer call and email. |
| `422 SUPPORT_EMAIL_VERIFICATION_REQUIRED` | Existing profile email-verification prompt. |
| `429 SUPPORT_SESSION_RATE_LIMITED` | Ask the customer to try again after `Retry-After`. |

The knowledge base is hidden for non-cohort customers too, so the cohort controls the whole Zoho experience rather than only authenticated modules. On any `403`, `409`, or `503 SUPPORT_INTEGRATION_DISABLED`, the app also logs out of the Zoho SDK if it is signed in, so a soft disable reaches already-signed-in customers on their next support launch; the Zoho-side hard stop remains the immediate control. The app sends no request body: `ApiClient.postData` in `lib/app/network.dart` passes `data: null`, which Dio sends as an absent body. Owner: Mobile integration owner. Gates: Task 11 Step 5.

**Q6. Should support start globally enabled, cohort-gated, or staff-allowlist-only?**
**Confirmed** sequence (Task 11): production deploys disabled, then the internal staff allowlist only, then deterministic customer percentages, then general availability. **Proposed** parameters:

- Internal canary: at least 10 staff accounts across Android and iOS for at least 5 business days.
- Customer cohorts: 5%, then 25%, then 50%, then 100%, each held for at least 3 business days.
- Expansion thresholds: session success at least 99% excluding `409`/`422`, no Sev-1/Sev-2 support incident, push delivery confirmed on both platforms, and agent first-response within the approved SLA.
- Approvers for each step: User Service endpoint owner and Support Operations acceptance owner, with Security/Privacy sign-off on the first customer cohort.
- Mechanism: Task 1 records whether the User Service already has one; otherwise build the Task 11 Step 4 allowlist and hashed-percentage mechanism.

The mobile build also needs a `ZOHO_DESK_ENABLED` compile-time value set to `true` for the release that ships support, following the existing `Env` `String.fromEnvironment` pattern in `lib/app/services.dart`; server-side gating, not that build flag, decides who can use support. Owner: Support Operations acceptance owner. Gates: Task 11 Steps 5 and 6.

### Additional Clarifications Needed

| # | Question | Proposed answer | Owner | Gates |
|---|----------|-----------------|-------|-------|
| C1 | Which JWT claims set the Zoho contact's first and last name? (O3) | Use `first_name` and `last_name` unless Zoho support or the staging login test shows otherwise. | Zoho Desk administrator | Task 5 |
| C2 | What value goes in `cf_boctrust_customer_ref`? (O8) | The customer-facing reference already shown to the customer in the app, if one exists; otherwise leave the field empty and let agents identify customers by contact email. Not the raw internal customer ID. | Security/Privacy approver | Task 8 Step 3 |
| C3 | Who builds the staging mobile app identity? (O2) | The mobile integration owner adds Android flavors and an iOS scheme/configuration for the `.staging` IDs, plus staging Firebase apps, under a separate mobile plan. | Mobile integration owner | Tasks 9 and 10 |
| C4 | How do staging testers receive iOS builds? | TestFlight, so Zoho's staging APNs mode is **production**; Xcode-installed debug builds additionally use sandbox and are tested only if developers rely on them. | Mobile integration owner | Task 9 |
| C5 | Who fills each Task 1 Step 3 role? | Named individuals recorded in the Task 1 path map; every open item's owner resolves from it. | Engineering lead | Task 1 |
| C6 | Who may perform the Zoho-side hard stop, and how fast? | Zoho Desk administrator plus one named backup, reachable within the incident on-call window, recorded in the Task 7 runbook. | Zoho Desk administrator | Task 7 Step 7 |

---

## Delivery Order

1. Lock the backend repository path map and owners.
2. Resolve mobile identity/environment separation and obtain data-residency pre-approval.
3. Create the staging support structure and isolated Zoho Desk add-on using the current Flutter JWT flow.
4. Establish secret/configuration management.
5. Implement and verify JWT construction.
6. Expose the authenticated session endpoint.
7. Add security, redaction, rate limiting, and observability.
8. Configure support fields, knowledge base, chat, SLA, and agent workflow.
9. Configure FCM/APNs support notifications.
10. Run staging acceptance, create production configuration, and execute controlled rollout.

### Task 1: Lock Backend Ownership and Real File Paths

**Artifacts:**
- Create in the User Service repository: `docs/integrations/zoho-desk/backend-path-map.md`
- Reference: `docs/superpowers/specs/2026-10-02-zoho-desk-support-design.md` from the Flutter repository

**Interfaces:**
- Consumes: Existing User Service authentication middleware, current user repository/profile model, API response envelope, configuration loader, secret manager, OpenAPI source, structured logger, rate limiter, test runner, and deployment manifests.
- Produces: A reviewed path map naming the exact files and owners that every later backend task must modify.

- [ ] **Step 1: Inventory the User Service repository**

Record the exact paths for:

- authenticated `/me` route/controller registration;
- user lookup and verified-email fields, including whether a uniqueness constraint exists on verified email across active customers;
- the customer reference value the mobile app already holds and may place in `cf_boctrust_customer_ref`;
- service/domain layer;
- environment/configuration schema;
- secret-manager integration;
- API response/error helpers;
- OpenAPI generation or source document;
- request logging/redaction;
- rate limiting;
- feature flags, account allowlists, deterministic percentage rollout, or another existing cohort-release mechanism;
- unit, integration, and contract tests;
- staging and production deployment manifests.

- [ ] **Step 2: Confirm runtime and execution commands**

Record the actual commands for focused unit tests, endpoint integration tests, lint/type checks, OpenAPI validation, full backend tests, and staging deployment. Do not substitute commands from another service.

- [ ] **Step 3: Assign accountable owners**

Name one owner for the User Service endpoint, one Zoho Desk administrator, one secrets/deployment operator, one mobile integration owner, one Security/Privacy data-governance approver, and one support-operations acceptance owner.

- [ ] **Step 4: Review the path map**

Expected: every logical backend, deployment, observability, and rollout-control component in Tasks 3–11 maps to a real file or managed platform with an accountable owner, and no implementation path remains generic or unresolved.

- [ ] **Step 5: Commit**

Commit only the backend path map with message:

```text
docs: map Zoho Desk backend integration paths
```

### Task 2: Resolve Mobile Application Identity Separation

**Artifacts:**
- Update: `docs/integrations/zoho-desk/environment-matrix.md` in the User Service repository
- Create: `docs/integrations/zoho-desk/data-governance-approval.md` in the User Service repository (data-residency pre-approval section)
- Input evidence: Android currently uses `com.boctrust.boctrust_savings_loan`
- Input evidence: iOS currently uses `com.boctrust.boctrustSavingsLoan`

**Interfaces:**
- Consumes: Mobile application IDs, Firebase projects, APNs identifiers, build environments and distribution methods, Zoho mobile add-on registration requirements.
- Produces: An approved staging/production identity matrix used by Zoho Desk, Firebase/APNs, backend configuration, and mobile build configuration; a recorded data-residency pre-approval; and a tracked mobile build prerequisite.

- [ ] **Step 1: Record the production identities**

Set production Android to `com.boctrust.boctrust_savings_loan` and production iOS to `com.boctrust.boctrustSavingsLoan`, matching the current repository.

- [ ] **Step 2: Choose and approve staging identities**

Recommended values:

- Android: `com.boctrust.boctrust_savings_loan.staging`
- iOS: `com.boctrust.boctrustSavingsLoan.staging`

If the organization intentionally retains a single identity, record a signed risk acceptance explaining how production and staging push credentials, add-on selection, and installed-app testing remain isolated. Do not proceed with an undocumented shared identity.

- [ ] **Step 3: Record environment mappings**

For each environment, record the application ID/bundle ID, Firebase project, distribution method (local/debug, ad hoc, TestFlight, App Store), APNs environment derived from that distribution method, Zoho data centre, Zoho organization, ASAP add-on, support department, ticket layout, backend deployment, and owning team. Store identifiers only; do not place secrets in the matrix.

- [ ] **Step 4: Verify uniqueness**

Expected: no staging Zoho app ID, JWT secret reference, Firebase credential, APNs credential, or backend secret path appears in the production row, and vice versa.

- [ ] **Step 5: Obtain data-residency pre-approval**

Before Task 3 creates any Zoho object, Security/Privacy must approve and record in `docs/integrations/zoho-desk/data-governance-approval.md` the Zoho organization and data centre for each environment, permitted cross-border processing, and vendor/DPA and lawful-basis requirements. Task 3 is blocked until this approval exists. The remaining governance decisions are completed in Task 8.

- [ ] **Step 6: Record the mobile build prerequisite**

The Flutter repository currently has no Android product flavors and only the default iOS `Runner` scheme, so the staging identities require mobile work outside this plan: Android flavors or an equivalent application-ID override, an iOS scheme/configuration, a staging Firebase app per platform, and staging provisioning profiles. Record the owning mobile plan or ticket and its owner in the matrix. Tasks 9 and 10 are blocked until an installable staging build with the approved identities exists.

- [ ] **Step 7: Commit**

Commit the approved matrix and data-residency pre-approval with message:

```text
docs: define Zoho Desk environment isolation
```

### Task 3: Configure the Zoho Desk Staging Foundation and Add-On

**Artifacts:**
- Create/update in Zoho Desk: staging ASAP mobile add-on
- Update: `docs/integrations/zoho-desk/zoho-admin-runbook.md` in the User Service repository
- Store non-secret evidence in the approved deployment evidence system

**Interfaces:**
- Consumes: Task 2 staging application identities, the recorded data-residency pre-approval, and the approved release scope.
- Produces: Staging support department/layout, org ID, app ID, data centre, department ID, ticket layout ID, confirmed Flutter JWT-flow version, and one-time JWT secret ready for secret storage.

- [ ] **Step 1: Create the staging support structure**

In the Zoho organization created in the data centre approved by Task 2, create department `Customer Support` and ticket layout `Mobile App Support` before creating the add-on. Assign only the staging support team. Task 8 completes fields, routing, SLA, content, chat, and workflow acceptance on these objects.

- [ ] **Step 2: Confirm the supported mobile authentication flow**

Record the Zoho Desk ASAP add-on/setup version and the Flutter SDK version in the runbook. Confirm in the current Zoho console and Flutter documentation that this add-on uses the updated flow in which the BOCTRUST app obtains a JWT from `POST /api/v1/me/support/zoho/session` and passes it to `ZohodeskPortalApikit.login(jwtToken, callback)`. Do not configure the legacy Zoho IAM callback flow that calls a `GET` endpoint with `user_token` and expects a plain-string response. Stop setup if the tenant exposes only the legacy flow and revise the server contract before implementation.

Zoho's published ASAP JWT documentation names only `email`, `email_verified`, `not_before`, and `not_after`. Confirm with Zoho support or a staging test login which claim names populate the contact's first and last name. If they differ from `first_name` and `last_name`, record the confirmed names in the runbook and update this plan's Global Constraints and Task 5 before implementation; otherwise record that `first_name` and `last_name` were confirmed.

- [ ] **Step 3: Create the staging mobile add-on**

In Zoho Desk staging, create one ASAP mobile add-on named `BOCTRUST Mobile Staging`. Register the approved staging Android application ID and iOS bundle ID.

- [ ] **Step 4: Enable only approved modules**

Enable Knowledge Base, Tickets, and Business Messaging. Leave Community, Zia/Answer Bot, Guided Conversations, and SalesIQ disabled.

- [ ] **Step 5: Select support ownership**

Map the add-on to the `Customer Support` department and `Mobile App Support` ticket layout created in Step 1. Verify Tickets remains enabled after the mapping.

- [ ] **Step 6: Enable JWT SSO**

Before revealing the one-time value, the secrets operator must provision the staging secret-manager entry using the logical identity `boctrust/staging/zoho-desk/asap-jwt-secret` and restrict write/read access to secrets operators and the staging User Service runtime. Then enable SSO/JWT, reveal the JWT secret to that operator only, and place it directly into the entry. Do not paste it into tickets, chat, email, source control, screenshots, shell history, or the runbook. Task 4 binds and validates the reference in application configuration.

- [ ] **Step 7: Capture non-secret configuration**

Record:

- `ZOHO_DESK_ORG_ID`
- `ZOHO_DESK_APP_ID`
- `ZOHO_DESK_DATA_CENTER`
- `ZOHO_DESK_DEPARTMENT_ID`
- `ZOHO_DESK_TICKET_LAYOUT_ID`

- [ ] **Step 8: Verify add-on isolation and authentication flow**

Expected: only staging application identities are registered, production push credentials are absent, unapproved modules are disabled, the updated Flutter JWT flow and confirmed name claims are recorded, the organization's data centre matches the Task 2 approval, the department/layout mapping is valid, and the secret is no longer visible in any working note.

- [ ] **Step 9: Commit**

Commit the sanitized runbook with message:

```text
docs: record Zoho Desk staging setup
```

### Task 4: Add Backend Secret and Configuration Management

**Files:**
- Modify: Exact configuration schema and deployment-manifest paths recorded by Task 1
- Test: Exact configuration test path recorded by Task 1
- Update: `docs/integrations/zoho-desk/zoho-admin-runbook.md`

**Interfaces:**
- Consumes: Task 3 non-secret identifiers and staging JWT secret.
- Produces: A typed immutable `ZohoDeskSupportConfig` equivalent containing `enabled`, `orgId`, `appId`, `dataCenter`, `departmentId`, `ticketLayoutId`, and `jwtSecret`; deployment validation rejects invalid enabled configuration before promotion, while a running User Service isolates invalid support configuration to the support endpoint.

- [ ] **Step 1: Write failing configuration tests**

Cover:

- disabled integration accepts absent Zoho values;
- enabled integration rejects blank org ID, app ID, data centre, department ID, layout ID, or secret;
- data-centre values outside `US`, `EU`, `IN`, `AU`, `JP`, `CN`, `CA`, and `SA` are rejected;
- negative skew, non-positive TTL, and any combination where TTL plus skew is 600 seconds or more are rejected, including TTL `570` with skew `30` and TTL `540` with skew `60`; TTL `300` with skew `30` is accepted;
- staging and production manifests resolve different secret references;
- configuration serialization/debug output replaces the secret with `[REDACTED]`;
- the deployment preflight command exits non-zero for invalid enabled configuration;
- the runtime loader represents invalid support configuration without crashing the User Service or making unrelated banking endpoints unavailable.

- [ ] **Step 2: Run the focused configuration tests**

Use the command recorded in Task 1. Expected: FAIL because the Zoho configuration schema does not exist.

- [ ] **Step 3: Add exact server configuration keys**

Add:

```text
ZOHO_DESK_SUPPORT_ENABLED
ZOHO_DESK_ORG_ID
ZOHO_DESK_APP_ID
ZOHO_DESK_DATA_CENTER
ZOHO_DESK_DEPARTMENT_ID
ZOHO_DESK_TICKET_LAYOUT_ID
ZOHO_DESK_ASAP_JWT_SECRET
ZOHO_DESK_SESSION_TTL_SECONDS=300
ZOHO_DESK_SESSION_NOT_BEFORE_SKEW_SECONDS=30
```

Set `ZOHO_DESK_SUPPORT_ENABLED=false` by default. Reject a negative skew, a non-positive TTL, and any configuration where `ZOHO_DESK_SESSION_TTL_SECONDS + ZOHO_DESK_SESSION_NOT_BEFORE_SKEW_SECONDS >= 600`, so the validity window stays strictly below ten minutes whatever skew is configured.

Add a deployment preflight validator that fails the build or promotion when support is enabled with invalid configuration. At runtime, retain a support-specific unavailable state so `POST /api/v1/me/support/zoho/session` can return `503 SUPPORT_CONFIGURATION_ERROR`; do not fail the User Service process or its general readiness solely because optional Zoho support configuration is invalid.

- [ ] **Step 4: Verify environment-specific secret entries and access**

Verify the staging entry provisioned in Task 3 and provision the separate production entry according to the platform convention; the production entry stays empty until Task 11 Step 1 generates the production secret, and enabled production configuration must fail preflight while it is empty. Use logical identities `boctrust/staging/zoho-desk/asap-jwt-secret` and `boctrust/production/zoho-desk/asap-jwt-secret`. Grant read access only to the corresponding User Service runtime identity and secrets operators, and prove that neither runtime can read the other environment's entry.

- [ ] **Step 5: Run focused configuration tests**

Expected: PASS, including cross-environment secret-reference assertions and redacted debug output.

- [ ] **Step 6: Commit**

Commit configuration, manifests, tests, and sanitized documentation with message:

```text
feat: configure Zoho Desk support sessions
```

### Task 5: Implement the Zoho JWT Issuer

**Files:**
- Create/modify: Exact support-domain/service path recorded by Task 1
- Test: Exact unit-test path recorded by Task 1

**Interfaces:**
- Consumes: `ZohoDeskSupportConfig`, authenticated authoritative customer profile, and an injectable UTC clock.
- Produces: `issueZohoSupportSession(customer, now) -> { jwtToken, expiresAt }`, or the backend's idiomatic equivalent with the same inputs and result fields.

- [ ] **Step 1: Write failing deterministic JWT tests**

Assert that the decoded test token:

- uses HS256;
- contains authoritative `email`, `email_verified: true`, `first_name`, and `last_name`;
- contains no BOCTRUST access token or prohibited customer fields;
- sets `not_before` to `now - 30 seconds` and `not_after` to `now + 300 seconds` as Unix epoch milliseconds, while the response `expiresAt` represents the same `not_after` instant as a UTC ISO-8601 string;
- has a complete validity window strictly below 600000 milliseconds;
- omits `first_name` or `last_name` rather than sending an empty or invented value when the authoritative profile lacks it;
- fails verification under the other environment's secret;
- is not reused for a second customer.

- [ ] **Step 2: Write failing eligibility tests**

Assert that missing email, whitespace-only email, malformed email, and `isVerifiedEmail == false` return `SUPPORT_EMAIL_VERIFICATION_REQUIRED` without invoking the signer. Assert that a verified email held by more than one active customer, compared case-insensitively after trimming, returns `SUPPORT_EMAIL_CONFLICT` without invoking the signer. If Task 1 found a database uniqueness constraint on verified email, keep the check as defense in depth and test it with a repository fake.

- [ ] **Step 3: Write failing identity-isolation tests**

Run overlapping issuance for two customers and assert each decoded token contains only its own authoritative email/name. Repeat after simulated logout/account switch and assert no cached token is returned.

- [ ] **Step 4: Run focused issuer tests**

Expected: FAIL because the issuer is not implemented.

- [ ] **Step 5: Implement the issuer**

Capture the clock once per issuance, normalize names without inventing missing values, sign with the configured server-only secret, and return an opaque token plus the exact UTC `expiresAt`. Do not add customer IDs or diagnostic context to JWT claims.

- [ ] **Step 6: Run focused issuer tests**

Expected: PASS with deterministic claims, expiry, eligibility, email-uniqueness, cross-secret, and concurrency behavior.

- [ ] **Step 7: Commit**

Commit issuer and unit tests with message:

```text
feat: issue short-lived Zoho support JWTs
```

### Task 6: Expose the Authenticated Support Session Endpoint

**Files:**
- Modify: Exact route/controller, service, OpenAPI, and integration-test paths recorded by Task 1

**Interfaces:**
- Consumes: Existing bearer authentication, authoritative customer repository, Task 5 JWT issuer, existing response envelope, and an injectable `isSupportEnabledForCustomer(customer)` release-access check. Until Task 11 Step 4 wires the cohort mechanism, the check returns the global `ZOHO_DESK_SUPPORT_ENABLED` value.
- Produces: `POST /api/v1/me/support/zoho/session` with no request body and the exact response/error contract below.

- [ ] **Step 1: Write failing endpoint integration tests**

Cover:

- unauthenticated request returns the existing `401` envelope;
- valid verified customer returns `200`, `jwtToken`, and UTC `expiresAt`;
- an absent body and the empty JSON object `{}` are both accepted; any other body, including `null`, returns `400` through the existing validation envelope, and no body value can replace authenticated identity;
- missing/unverified email returns `422` and `SUPPORT_EMAIL_VERIFICATION_REQUIRED`;
- disabled integration returns `503` and `SUPPORT_INTEGRATION_DISABLED`;
- an authenticated customer outside the release cohort returns `403` and `SUPPORT_NOT_ENABLED_FOR_CUSTOMER` without invoking the signer, and the client must not treat it as session expiry;
- a verified email shared with another active customer returns `409` and `SUPPORT_EMAIL_CONFLICT` without invoking the signer;
- invalid/missing runtime configuration returns `503` and `SUPPORT_CONFIGURATION_ERROR` without configuration detail;
- signing failure returns `503` and `SUPPORT_SESSION_UNAVAILABLE`;
- customer A and B concurrent requests return tokens for their own identity only;
- checks run in this order, each short-circuiting: authentication (`401`), body validation (`400`), global disable (`503 SUPPORT_INTEGRATION_DISABLED`), runtime configuration (`503 SUPPORT_CONFIGURATION_ERROR`), release cohort (`403`), per-customer rate limit (`429`), email eligibility (`422`/`409`), signing (`503 SUPPORT_SESSION_UNAVAILABLE`);
- every `200`, `400`, `401`, `403`, `409`, `422`, `429`, and `503` response includes `Cache-Control: no-store` and `Pragma: no-cache`.

- [ ] **Step 2: Run focused endpoint tests**

Expected: FAIL because the route is absent.

- [ ] **Step 3: Register the endpoint**

Implement exactly:

```http
POST /api/v1/me/support/zoho/session
Authorization: Bearer <BOCTRUST access token>
Content-Type: application/json
```

The body is absent or `{}`.

Return:

```json
{
  "success": true,
  "message": "Support session created.",
  "data": {
    "jwtToken": "<opaque-signed-token>",
    "expiresAt": "<UTC ISO-8601 timestamp>"
  }
}
```

- [ ] **Step 4: Update OpenAPI**

Document the empty request, authenticated requirement, success schema, no-cache response headers, and `400`, `401`, `403`, `409`, `422`, `429`, and `503` envelopes with the stable error codes from this plan. Define `jwtToken` in a response-only schema, mark it required and `readOnly: true` where supported, and use a non-functional example value. Do not mark it `writeOnly`, because OpenAPI treats write-only properties as request-only and generated response clients may omit them. Apply a generator-specific sensitive annotation only if it does not remove the field from response models. Document that the knowledge base can be opened without a JWT, so this endpoint's cohort gate hides only authenticated modules; the mobile integration decides separately whether to hide the Support hub for customers who receive `SUPPORT_NOT_ENABLED_FOR_CUSTOMER`.

- [ ] **Step 5: Run endpoint and OpenAPI validation tests**

Expected: PASS; generated documentation contains no real tokens, secrets, or customer data.

- [ ] **Step 6: Commit**

Commit route, service wiring, OpenAPI, and tests with message:

```text
feat: expose Zoho support session endpoint
```

### Task 7: Add Rate Limiting, Redaction, Audit Events, and Operational Controls

**Files:**
- Modify: Exact limiter, logging/redaction, metrics, alerting, and tests recorded by Task 1
- Update: `docs/integrations/zoho-desk/zoho-admin-runbook.md`

**Interfaces:**
- Consumes: Task 6 endpoint outcomes and existing request/correlation IDs.
- Produces: Abuse protection, safe audit events, dashboards/alerts, and a secret-rotation procedure.

- [ ] **Step 1: Write failing rate-limit tests**

Set the primary endpoint-specific limit to 10 requests per authenticated customer per 5 minutes. Use the existing configurable WAF/anomaly-control mechanism for source-IP protection; start with a monitor-only or substantially higher threshold approved from staging traffic rather than a fixed 30 requests per 5 minutes. Assert a customer's next over-limit request returns `429` with `SUPPORT_SESSION_RATE_LIMITED` and `Retry-After`, one customer cannot consume another customer's allowance even when both share an IP address, and unrelated API endpoints remain unaffected.

- [ ] **Step 2: Write failing redaction tests**

Inject unique canary strings as the JWT secret and generated token. Exercise success and every error path, then assert neither canary appears in captured application logs, access logs, traces, metrics labels, exception reports, or serialized configuration.

- [ ] **Step 3: Write failing audit-event tests**

Assert one `support.zoho.session` event is emitted with environment, coarse outcome, error code when present, request/correlation ID, timestamp, and platform only when it is already available from trusted request context. Assert it excludes raw customer ID, email, names, token, secret, request headers, and response body. If Security/Privacy explicitly requires customer-level audit correlation, use a keyed pseudonymous audit subject with documented key ownership, access control, retention, deletion, and rotation; never use the raw customer ID or a reversible encoding.

- [ ] **Step 4: Implement controls**

Apply the per-customer rate limiter after authentication, configure the approved source-IP anomaly control independently, extend structured-log and trace redaction, emit the safe audit event, and add metrics for request count, success, verification-required, email-conflict, not-in-cohort, rate-limited, configuration failure, signing failure, and latency. Rate-limit metrics must not use customer ID or source IP as labels.

- [ ] **Step 5: Add alerts**

Create alerts for sustained session failure rate above 5% for 10 minutes, any production configuration failure, and zero successful sessions during a period with requests. Alerts must identify environment and correlation IDs without customer data.

- [ ] **Step 6: Document secret rotation**

The runbook must cover maintenance-window rotation because ASAP exposes a single active JWT secret unless the configured account proves otherwise: disable mobile support, rotate/regenerate the Zoho secret, update the corresponding server secret, deploy/restart, then sign in with the environment's designated internal verification account (named in the runbook and on the release allowlist), confirm a `200` session response and a successful Zoho login that lists the account's tickets, and re-enable. Phone and email remain available during the window.

- [ ] **Step 7: Document the two levels of disable**

The runbook must define:

- **Soft disable:** set `ZOHO_DESK_SUPPORT_ENABLED=false` or reduce the cohort. New session requests fail, so no new Zoho logins occur, but customers already signed in to the Zoho SDK keep access to tickets and chat until they log out or the SDK session ends.
- **Hard stop:** additionally disable the ASAP add-on or its Tickets and Business Messaging modules in the Zoho console. Record the exact console path, who may perform it, the expected effect on signed-in SDK sessions as observed in staging, and how to restore it.

Use soft disable for routine rollback and hard stop for suspected data exposure or a security incident.

- [ ] **Step 8: Run focused security tests**

Expected: PASS for limits, redaction canaries, safe audit payloads, and unrelated-route isolation.

- [ ] **Step 9: Commit**

Commit controls, tests, alerts, and runbook with message:

```text
feat: secure Zoho support session issuance
```

### Task 8: Configure Ticketing, Knowledge Base, and Business Messaging

**Artifacts:**
- Configure in Zoho Desk staging: department, layout, fields, categories, SLA, escalation, knowledge base, Business Messaging, agent hours
- Update: `docs/integrations/zoho-desk/zoho-admin-runbook.md`
- Create/update: `docs/integrations/zoho-desk/data-governance-approval.md`
- Create/update: `docs/integrations/zoho-desk/sanitized-configuration-manifest.md`

**Interfaces:**
- Consumes: Approved customer experience and privacy constraints from the design spec.
- Produces: An approved data-governance record, sanitized expected-configuration manifest, and a mobile support form and agent workflow matching the fields the Flutter integration may display or prefill.

- [ ] **Step 1: Verify the staging support structure**

Verify the `Customer Support` department and `Mobile App Support` layout created in Task 3 exist, are mapped to the staging add-on, and remain restricted to the staging support team while configuration is under test.

- [ ] **Step 2: Complete the data-governance approval**

Confirm the Task 2 data-residency pre-approval (organization, data centre, cross-border processing, vendor/DPA, lawful basis) is still current. Security/Privacy and Support Operations must then document and approve, before production configuration begins:

- ticket, chat, audit, and attachment retention/deletion periods;
- customer data-access, correction, export, and deletion request procedures;
- least-privilege agent/admin roles, MFA, joiner/mover/leaver access reviews, and audit-log review ownership;
- customer-facing privacy notice and prohibited-data copy;
- incident response, breach notification, and vendor escalation ownership.

Record decision owners, approval dates, evidence links, and review/expiry dates without including customer content or secrets. Production rollout is blocked while any required decision is unresolved.

- [ ] **Step 3: Configure customer-visible fields**

Required editable fields:

- `Subject`
- `Description`
- `cf_issue_category`

Optional editable fields:

- `cf_transaction_reference`
- customer-selected attachment

Hidden, locked, prefilled fields:

- `cf_boctrust_customer_ref`
- `cf_app_version`
- `cf_platform`
- `cf_os_version`
- `cf_environment`
- `cf_correlation_id`

- [ ] **Step 4: Configure issue categories**

Set exact customer-facing values:

- Account access
- Profile and security
- Identity verification (KYC)
- Transfers
- Airtime, data, and bills
- Savings
- Other

- [ ] **Step 5: Configure privacy copy and field restrictions**

Show: `Do not include your password, OTP, transaction PIN, BVN, NIN, complete account or card number.` Limit attachments to the business-approved types and maximum size; prohibit executable/archive formats. Ensure hidden context fields are not editable in the customer form.

Hidden context fields are set by the mobile app through the SDK, so a modified client can supply any value. `cf_boctrust_customer_ref` must be the reference recorded in Task 1 and approved by Security/Privacy; it must not be a raw internal customer ID unless Security/Privacy explicitly approves that. The runbook must instruct agents to treat every `cf_` context field as unverified customer-supplied data, to identify the customer by the Zoho contact email established through the JWT, and to confirm identity through the existing BOCTRUST back-office process before discussing or acting on account details.

- [ ] **Step 6: Configure routing, SLA, and escalation**

Map categories to queues, owners, priorities, first-response targets, resolution targets, business hours, and escalation contacts approved by Support Operations. Do not show response-time promises in the app unless the configured SLA is approved for customer publication.

- [ ] **Step 7: Configure Knowledge Base**

Enable mobile access only to published, customer-approved articles. Seed and approve articles for login/account recovery, KYC, transfers, airtime/data/bills, savings, notification troubleshooting, fraud reporting, and contacting support. Remove internal-only notes and agent procedures.

- [ ] **Step 8: Configure Business Messaging**

Set operating timezone to `Africa/Lagos`, approved operating hours, greeting, queue/offline copy, and offline action to create a ticket. Verify no SalesIQ, Zia, Guided Conversations, or Community module is enabled.

- [ ] **Step 9: Define email-change handling**

Because Zoho keys the contact on email, a customer who changes their verified email will sign in as a new Zoho contact without their earlier tickets. Support Operations must document in the runbook whether agents merge or update the Zoho contact after an email change, who triggers it, and how the old address is prevented from reaching a different customer. Test the procedure once in staging.

- [ ] **Step 10: Record the sanitized expected configuration**

Record the expected non-secret settings for both environments; production identifiers that do not yet exist are recorded as explicit placeholders and filled in during Task 11 Step 1: enabled modules, org/data-centre identifiers, application identities, department/layout names and IDs, fields, categories, attachment policy, routing, SLA, operating hours, offline behavior, knowledge-base visibility, notification event types, and responsible owners. This manifest is the basis for staging verification and the production two-person comparison; never store credentials, secrets, device tokens, or customer content.

- [ ] **Step 11: Perform agent workflow acceptance**

Using staging customers, create one ticket per category, reply, add a public comment, change status/priority, close/reopen where allowed, test attachment policy, and verify the correct agent queue and SLA timers.

- [ ] **Step 12: Commit sanitized configuration evidence**

Commit the runbook/checklist without customer content or secrets with message:

```text
docs: record Zoho support workflow configuration
```

### Task 9: Configure Zoho Support Push Credentials

**Artifacts:**
- Configure in Zoho Desk staging: Android FCM and iOS APNs support notification credentials
- Update: `docs/integrations/zoho-desk/zoho-admin-runbook.md`

**Interfaces:**
- Consumes: Task 2 identities and APNs environment per distribution method, an installable staging build from the Task 2 mobile prerequisite, staging Firebase/APNs credentials, Zoho staging add-on.
- Produces: Ticket status, priority, reply, public-comment, and Business Messaging notifications deliverable to staging devices.

- [ ] **Step 1: Confirm credential ownership and environment**

Verify the Android credential belongs to the staging Firebase project and the iOS credential is valid for the staging bundle ID. The APNs environment follows the build's distribution method, not the backend environment: Xcode/debug installs use sandbox APNs, while ad hoc and TestFlight builds use production APNs even with the staging bundle ID. Configure Zoho's APNs mode to match the distribution method recorded in Task 2 and do not reuse production credentials.

- [ ] **Step 2: Store credentials through the Zoho administrative channel**

Upload/configure FCM and APNs material using the current Zoho Desk console flow. No credential content belongs in the backend repository or runbook.

- [ ] **Step 3: Verify allowed notification events**

Enable ticket priority update, ticket status update, agent reply, public comment, and Business Messaging agent reply. Disable unrelated marketing or community notifications.

- [ ] **Step 4: Test Android delivery**

For one authenticated staging customer, verify receipt and open behavior from foreground, background, terminated app, token refresh, and logout. Confirm exactly one visible alert per event.

- [ ] **Step 5: Test iOS delivery**

Repeat on a physical iOS device using the distribution method staging testers will actually receive, with the matching APNs mode; if both debug and TestFlight builds are used, test both. Verify foreground, background, terminated app, token refresh, and logout, with exactly one visible alert.

- [ ] **Step 6: Test cross-environment isolation**

Expected: a staging Zoho event cannot reach a production-installed app or use production credentials; a logged-out or different customer cannot open the previous customer's support content.

- [ ] **Step 7: Record non-secret evidence**

Record timestamps, event types, device platforms, outcome, and sanitized notification identifiers. Do not record device tokens or raw payloads.

- [ ] **Step 8: Commit**

Commit the sanitized push checklist/runbook update with message:

```text
docs: verify Zoho support push configuration
```

### Task 10: Deploy to Staging and Complete End-to-End Acceptance

**Files:**
- Modify: Staging deployment manifest/config paths recorded by Task 1
- Update: `docs/integrations/zoho-desk/release-checklist.md`

**Interfaces:**
- Consumes: Tasks 3–9 complete staging setup and a mobile staging build configured for the staging add-on.
- Produces: Evidence that the backend endpoint and Zoho configuration work together before production resources are created.

- [ ] **Step 1: Deploy disabled configuration**

Deploy the endpoint with `ZOHO_DESK_SUPPORT_ENABLED=false`. Verify authenticated requests return `503 SUPPORT_INTEGRATION_DISABLED`, other User Service endpoints are healthy, and call/email remain available in the mobile app.

- [ ] **Step 2: Enable staging support**

Set the staging identifiers and secret reference, enable the feature, deploy, and verify startup/configuration health without printing any sensitive value.

- [ ] **Step 3: Run API smoke tests**

Verify unauthenticated `401`, invalid-body `400` (with absent body and `{}` accepted), unverified-email `422`, shared-email `409`, non-cohort `403`, verified-customer `200`, token signature/claims/expiry, rate-limit `429`, and disabled `503` behavior. The automated Task 6 integration test—not a deliberately broken staging deployment—proves the runtime configuration-error `503` contract. Assert `Cache-Control: no-store` and `Pragma: no-cache` on every response. Use disposable staging accounts and never paste returned JWTs into the release checklist.

- [ ] **Step 4: Run full backend verification**

Run the exact lint/type, unit, integration, contract/OpenAPI, and full-suite commands recorded in Task 1. Expected: all pass with no snapshot containing tokens or secrets.

- [ ] **Step 5: Run mobile/server end-to-end acceptance**

Verify tickets, ticket history/replies, attachments, knowledge-base search, Business Messaging, notification opens, FCM token refresh, offline recovery, logout, and switching between two customers on Android and iOS.

Then, with a customer signed in to Zoho, apply the soft disable and record whether the open session keeps access; apply the hard stop and record its observed effect. Update the Task 7 runbook with the observed behavior and restore staging.

- [ ] **Step 6: Inspect logs and traces**

Search by staging correlation IDs and canary values. Expected: operational outcomes are visible; email, names, JWT, secret, FCM token, transaction reference, ticket content, and raw Zoho payload are absent.

- [ ] **Step 7: Obtain acceptance sign-off**

Require approval from Backend, Mobile, Security/Privacy, Zoho Administration, and Support Operations. Security/Privacy must confirm every Task 8 data-governance decision is approved and current. Two authorized reviewers must compare the live staging configuration with the sanitized expected-configuration manifest and sign any accepted deviations. Each owner signs the release checklist against the design acceptance criteria.

- [ ] **Step 8: Commit**

Commit sanitized staging results with message:

```text
docs: verify Zoho Desk staging integration
```

### Task 11: Create Production Configuration and Roll Out Safely

**Artifacts:**
- Configure in Zoho Desk production: production ASAP add-on and support workflow
- Modify: Production deployment manifest/config paths recorded by Task 1
- Update: `docs/integrations/zoho-desk/release-checklist.md`

**Interfaces:**
- Consumes: Signed staging acceptance and production identities/credentials.
- Produces: Production configuration equivalent to staging, initially disabled, followed by controlled enablement and a tested rollback.

- [ ] **Step 1: Recreate—not clone secrets from—the production setup**

Create `BOCTRUST Mobile Production`, register production app identities, enable only Knowledge Base, Tickets, and Business Messaging, configure the production department/layout/workflows, generate a new production JWT secret, and store it only in the production secret manager. Fill in the production placeholders in `sanitized-configuration-manifest.md`. Two authorized reviewers must compare all non-secret production settings with the manifest, record deviations and approvals, and verify that no staging identifier or credential reference is present.

- [ ] **Step 2: Configure production push**

Use the production Firebase project and production APNs credential/mode. Verify that no staging credential or application identity appears.

- [ ] **Step 3: Deploy production disabled**

Deploy all backend code and production identifiers with `ZOHO_DESK_SUPPORT_ENABLED=false`. Run configuration health checks and regression smoke tests for unrelated User Service endpoints.

- [ ] **Step 4: Configure and verify controlled release access**

Use the release-control mechanism recorded in Task 1. It must support an internal-staff allowlist and a limited customer cohort independently of the global emergency switch. If no existing mechanism exists, implement a server-side authenticated-customer allowlist for the canary and a deterministic percentage cohort for expansion: hash `zoho-support:<environment>:<stable-authoritative-customer-id>` with SHA-256, interpret the first eight digest bytes as an unsigned integer, and include the customer when `value mod 100` is less than the configured percentage. Store allowlist and percentage values in normal non-secret server configuration. Wire the mechanism into the `isSupportEnabledForCustomer` check from Task 6 so non-members receive `403 SUPPORT_NOT_ENABLED_FOR_CUSTOMER`. Test membership determinism, boundary percentages `0` and `100`, allowlist precedence, environment isolation, and immediate global disable. Do not expose or log the hashing input, and do not use client-only flags for authorization.

- [ ] **Step 5: Perform internal canary enablement**

Enable access only for the internal staff allowlist. Verify an included account can use session issuance, tickets, chat, articles, notifications, and logout; verify a non-member receives `403 SUPPORT_NOT_ENABLED_FOR_CUSTOMER`, the app shows the approved support-unavailable behavior, and call/email remain available; then inspect logs and metrics before customer rollout.

- [ ] **Step 6: Expand rollout**

Progress from internal staff to explicit deterministic customer percentages and then general availability only while session success, latency, support queue health, push delivery, and agent workload stay within thresholds approved and recorded before rollout. Record each cohort value, start/end timestamp, approver, metrics snapshot, and rollback decision.

- [ ] **Step 7: Exercise rollback**

Apply the soft disable and verify no new support JWTs are issued, a customer without a Zoho session sees the support-unavailable state with call/email fallbacks, and banking APIs remain healthy. Record that customers already signed in to Zoho may keep access until logout. Then exercise the hard stop on the internal verification account and confirm the effect observed in staging. Re-enable only after the rollback evidence is recorded.

- [ ] **Step 8: Close the release checklist**

Record production identifiers (never secrets), deployment versions, data-governance approval, configuration-manifest comparison, rollout mechanism and cohort history, approvals, rollout timestamps, dashboard links, alert ownership, next secret-rotation date, and rollback evidence.

- [ ] **Step 9: Commit**

Commit sanitized production configuration/runbook changes with message:

```text
docs: complete Zoho Desk production rollout
```

## Final Verification Checklist

- [ ] Backend config tests prove disabled behavior, required values, environment isolation, and redaction.
- [ ] Configuration rejects any TTL and skew whose sum is 600 seconds or more.
- [ ] JWT tests prove HS256 signature, authoritative claims, five-minute expiry, clock behavior, eligibility, email uniqueness, and cross-customer isolation.
- [ ] Endpoint tests prove `200`, `400`, `401`, `403`, `409`, `422`, `429`, and `503` contracts and the documented check order.
- [ ] Every support-session response carries `Cache-Control: no-store` and `Pragma: no-cache`; OpenAPI exposes `jwtToken` in its response schema and generated clients retain the field.
- [ ] Logs, traces, metrics, errors, and audit events contain no raw customer ID, JWT, secret, email, notification token, or ticket content.
- [ ] Zoho staging and production use distinct add-ons, secrets, application identities, and push credentials.
- [ ] Ticket fields and diagnostic context match the allowlist; prohibited identity, banking, and authentication data are absent.
- [ ] Knowledge Base, Tickets, and Business Messaging are enabled; Community, Zia, Guided Conversations, and SalesIQ are disabled.
- [ ] Android and iOS support notifications work in foreground, background, and terminated states without duplicates.
- [ ] Logout and account switching prevent access to the previous customer's Zoho session or notification destination.
- [ ] Call and email remain usable when Zoho is disabled or unavailable.
- [ ] Staging acceptance and production canary approvals are recorded before general availability.
- [ ] Security/Privacy data-governance approval and the two-person production configuration comparison are recorded before enablement.
- [ ] Internal allowlist, limited deterministic cohort, global disable, and rollback behavior are proven before general availability.
- [ ] Data-residency pre-approval was recorded before any Zoho object was created.
- [ ] Soft disable and hard stop are documented with their observed effect on already-signed-in Zoho sessions.
- [ ] Agents are instructed to treat `cf_` context fields as unverified, and email-change handling is documented and tested.
- [ ] iOS push was verified with the APNs mode matching each staging distribution method.
