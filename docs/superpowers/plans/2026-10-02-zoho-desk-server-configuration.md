# Zoho Desk Server-Side Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure Zoho Desk and the BOCTRUST backend so the mobile app can securely authenticate customers into tickets, knowledge base, and Business Messaging, and receive correctly isolated support notifications in staging and production.

**Architecture:** Zoho Desk ASAP owns support content, tickets, chat, and support push delivery. The BOCTRUST User Service owns customer eligibility and exposes one authenticated session endpoint that signs a short-lived Zoho JWT using a server-only secret. Staging and production use separate Zoho add-ons, secrets, support configuration, and push credentials; the mobile app receives only non-secret initialization IDs and the short-lived customer JWT.

**Tech Stack:** Existing BOCTRUST User Service and API envelope, existing bearer-token authentication, the backend's current configuration/secret manager/test framework, Zoho Desk ASAP 2.x, HS256 JWT, Firebase Cloud Messaging, Apple Push Notification service, OpenAPI, UTC timestamps.

**Spec:** `docs/superpowers/specs/2026-10-02-zoho-desk-support-design.md`

## Repository Boundary

The Flutter repository does not contain the BOCTRUST backend. This plan therefore does not invent backend language-specific source paths or commands. Task 1 must be performed in the User Service repository and records its real controller, service, configuration, OpenAPI, and test paths before code changes begin. All API names, configuration keys, claims, error codes, limits, and acceptance checks below are fixed and must not be renamed during path discovery.

## Global Constraints

- The Zoho ASAP JWT secret, OAuth credentials, agent credentials, FCM server credentials, and APNs private material remain server-side and must never be shipped in Flutter configuration.
- The session endpoint is exactly `POST /api/v1/me/support/zoho/session` and accepts no identity-bearing request body.
- The backend derives identity from the authenticated BOCTRUST session and authoritative user record.
- Zoho authentication requires a non-empty verified email.
- JWT signing uses HS256 with `email`, `email_verified`, `first_name`, `last_name`, `not_before`, and `not_after` claims; the two time claims use Unix epoch milliseconds as required by Zoho ASAP.
- Set `not_before` to server time minus 30 seconds and `not_after` to server time plus 5 minutes; the complete validity window remains below Zoho's ten-minute maximum.
- JWT and response expiry values are computed from the same captured UTC clock value.
- JWTs are returned to the authenticated client but are never persisted, logged, traced, cached across customers, or included in analytics/error reporting.
- The backend must not place NIN, BVN, OTP, password, PIN, access/refresh token, FCM token, account/card number, balance, transaction reference, or identity-document data in JWT claims.
- Zoho failure must not expire a valid BOCTRUST session unless the existing User Service authentication layer independently reports the BOCTRUST token invalid.
- Staging and production use separate Zoho ASAP add-ons and server secrets.
- Production support remains disabled until administrative setup, automated tests, physical-device tests, and agent workflow acceptance pass.

## Review Focus

- A token request begun for customer A must never return or cache a JWT for customer B after logout or account switching; Task 5 adds concurrency and identity-isolation tests.
- Missing, blank, syntactically invalid, or unverified email must return the stable verification-required error without signing a JWT; Task 5 tests every case.
- Server clock skew and boundary timestamps must not create already-expired or over-ten-minute JWTs; Task 4 adds deterministic clock tests.
- Secrets and JWTs must be redacted from application logs, HTTP logs, traces, metrics labels, and exception reporting; Task 6 adds canary-secret log scans.
- Staging credentials, mobile identifiers, push credentials, and Zoho add-on IDs must never resolve in production or vice versa; Tasks 2, 3, and 9 add environment-isolation checks.

---

## Delivery Order

1. Lock the backend repository path map and owners.
2. Resolve mobile identity/environment separation.
3. Create isolated Zoho Desk staging configuration.
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
- user lookup and verified-email fields;
- service/domain layer;
- environment/configuration schema;
- secret-manager integration;
- API response/error helpers;
- OpenAPI generation or source document;
- request logging/redaction;
- rate limiting;
- unit, integration, and contract tests;
- staging and production deployment manifests.

- [ ] **Step 2: Confirm runtime and execution commands**

Record the actual commands for focused unit tests, endpoint integration tests, lint/type checks, OpenAPI validation, full backend tests, and staging deployment. Do not substitute commands from another service.

- [ ] **Step 3: Assign accountable owners**

Name one owner for the User Service endpoint, one Zoho Desk administrator, one secrets/deployment operator, one mobile integration owner, and one support-operations acceptance owner.

- [ ] **Step 4: Review the path map**

Expected: every logical component in Tasks 3–7 maps to a real backend file and no implementation path remains generic or unresolved.

- [ ] **Step 5: Commit**

Commit only the backend path map with message:

```text
docs: map Zoho Desk backend integration paths
```

### Task 2: Resolve Mobile Application Identity Separation

**Artifacts:**
- Update: `docs/integrations/zoho-desk/environment-matrix.md` in the User Service repository
- Input evidence: Android currently uses `com.boctrust.boctrust_savings_loan`
- Input evidence: iOS currently uses `com.boctrust.boctrustSavingsLoan`

**Interfaces:**
- Consumes: Mobile application IDs, Firebase projects, APNs identifiers, build environments, Zoho mobile add-on registration requirements.
- Produces: An approved staging/production identity matrix used by Zoho Desk, Firebase/APNs, backend configuration, and mobile build configuration.

- [ ] **Step 1: Record the production identities**

Set production Android to `com.boctrust.boctrust_savings_loan` and production iOS to `com.boctrust.boctrustSavingsLoan`, matching the current repository.

- [ ] **Step 2: Choose and approve staging identities**

Recommended values:

- Android: `com.boctrust.boctrust_savings_loan.staging`
- iOS: `com.boctrust.boctrustSavingsLoan.staging`

If the organization intentionally retains a single identity, record a signed risk acceptance explaining how production and staging push credentials, add-on selection, and installed-app testing remain isolated. Do not proceed with an undocumented shared identity.

- [ ] **Step 3: Record environment mappings**

For each environment, record the application ID/bundle ID, Firebase project, APNs environment, Zoho data centre, Zoho organization, ASAP add-on, support department, ticket layout, backend deployment, and owning team. Store identifiers only; do not place secrets in the matrix.

- [ ] **Step 4: Verify uniqueness**

Expected: no staging Zoho app ID, JWT secret reference, Firebase credential, APNs credential, or backend secret path appears in the production row, and vice versa.

- [ ] **Step 5: Commit**

Commit the approved matrix with message:

```text
docs: define Zoho Desk environment isolation
```

### Task 3: Configure the Zoho Desk Staging Add-On

**Artifacts:**
- Create/update in Zoho Desk: staging ASAP mobile add-on
- Update: `docs/integrations/zoho-desk/zoho-admin-runbook.md` in the User Service repository
- Store non-secret evidence in the approved deployment evidence system

**Interfaces:**
- Consumes: Task 2 staging application identities and the approved release scope.
- Produces: Staging org ID, app ID, data centre, department ID, ticket layout ID, and one-time JWT secret ready for secret storage.

- [ ] **Step 1: Create the staging mobile add-on**

In Zoho Desk staging, create one ASAP mobile add-on named `BOCTRUST Mobile Staging`. Register the approved staging Android application ID and iOS bundle ID.

- [ ] **Step 2: Enable only approved modules**

Enable Knowledge Base, Tickets, and Business Messaging. Leave Community, Zia/Answer Bot, Guided Conversations, and SalesIQ disabled.

- [ ] **Step 3: Select support ownership**

Map the add-on to the `Customer Support` department and `Mobile App Support` ticket layout created in Task 8. If Zoho requires these objects to exist first, create the add-on with Tickets disabled, complete Task 8, then enable Tickets; record that sequence in the runbook.

- [ ] **Step 4: Enable JWT SSO**

Enable SSO/JWT for the add-on, reveal the one-time JWT secret to the secrets operator only, and immediately place it in the staging secret manager entry defined in Task 4. Do not paste it into tickets, chat, email, source control, screenshots, or the runbook.

- [ ] **Step 5: Capture non-secret configuration**

Record:

- `ZOHO_DESK_ORG_ID`
- `ZOHO_DESK_APP_ID`
- `ZOHO_DESK_DATA_CENTER`
- `ZOHO_DESK_DEPARTMENT_ID`
- `ZOHO_DESK_TICKET_LAYOUT_ID`

- [ ] **Step 6: Verify add-on isolation**

Expected: only staging application identities are registered, production push credentials are absent, unapproved modules are disabled, and the secret is no longer visible in any working note.

- [ ] **Step 7: Commit**

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
- Produces: A typed immutable `ZohoDeskSupportConfig` equivalent containing `enabled`, `orgId`, `appId`, `dataCenter`, `departmentId`, `ticketLayoutId`, and `jwtSecret`; invalid enabled configuration fails deployment/startup.

- [ ] **Step 1: Write failing configuration tests**

Cover:

- disabled integration accepts absent Zoho values;
- enabled integration rejects blank org ID, app ID, data centre, department ID, layout ID, or secret;
- data-centre values outside `US`, `EU`, `IN`, `AU`, `JP`, `CN`, `CA`, and `SA` are rejected;
- staging and production manifests resolve different secret references;
- configuration serialization/debug output replaces the secret with `[REDACTED]`.

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

Set `ZOHO_DESK_SUPPORT_ENABLED=false` by default. Reject TTL values above `570` seconds so the 30-second backward skew cannot create a validity window exceeding ten minutes.

- [ ] **Step 4: Create environment-specific secret entries**

Use separate secret-manager entries named according to the platform convention, with logical identities `boctrust/staging/zoho-desk/asap-jwt-secret` and `boctrust/production/zoho-desk/asap-jwt-secret`. Grant read access only to the corresponding User Service runtime identity and secrets operators.

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
- has a complete validity window below 600 seconds;
- fails verification under the other environment's secret;
- is not reused for a second customer.

- [ ] **Step 2: Write failing eligibility tests**

Assert that missing email, whitespace-only email, malformed email, and `isVerifiedEmail == false` return `SUPPORT_EMAIL_VERIFICATION_REQUIRED` without invoking the signer.

- [ ] **Step 3: Write failing identity-isolation tests**

Run overlapping issuance for two customers and assert each decoded token contains only its own authoritative email/name. Repeat after simulated logout/account switch and assert no cached token is returned.

- [ ] **Step 4: Run focused issuer tests**

Expected: FAIL because the issuer is not implemented.

- [ ] **Step 5: Implement the issuer**

Capture the clock once per issuance, normalize names without inventing missing values, sign with the configured server-only secret, and return an opaque token plus the exact UTC `expiresAt`. Do not add customer IDs or diagnostic context to JWT claims.

- [ ] **Step 6: Run focused issuer tests**

Expected: PASS with deterministic claims, expiry, eligibility, cross-secret, and concurrency behavior.

- [ ] **Step 7: Commit**

Commit issuer and unit tests with message:

```text
feat: issue short-lived Zoho support JWTs
```

### Task 6: Expose the Authenticated Support Session Endpoint

**Files:**
- Modify: Exact route/controller, service, OpenAPI, and integration-test paths recorded by Task 1

**Interfaces:**
- Consumes: Existing bearer authentication, authoritative customer repository, Task 5 JWT issuer, existing response envelope.
- Produces: `POST /api/v1/me/support/zoho/session` with no request body and the exact response/error contract below.

- [ ] **Step 1: Write failing endpoint integration tests**

Cover:

- unauthenticated request returns the existing `401` envelope;
- valid verified customer returns `200`, `jwtToken`, and UTC `expiresAt`;
- any non-empty request body returns `400` through the existing validation envelope, and no body value can replace authenticated identity;
- missing/unverified email returns `422` and `SUPPORT_EMAIL_VERIFICATION_REQUIRED`;
- disabled integration returns `503` and `SUPPORT_INTEGRATION_DISABLED`;
- invalid/missing runtime configuration returns `503` and `SUPPORT_CONFIGURATION_ERROR` without configuration detail;
- signing failure returns `503` and `SUPPORT_SESSION_UNAVAILABLE`;
- customer A and B concurrent requests return tokens for their own identity only.

- [ ] **Step 2: Run focused endpoint tests**

Expected: FAIL because the route is absent.

- [ ] **Step 3: Register the endpoint**

Implement exactly:

```http
POST /api/v1/me/support/zoho/session
Authorization: Bearer <BOCTRUST access token>
Content-Type: application/json
```

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

Document the empty request, authenticated requirement, success schema, and `401`, `422`, `429`, and `503` envelopes with the stable error codes from this plan. Mark `jwtToken` as sensitive/write-only where supported and use a non-functional example value.

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

Set endpoint-specific limits to 10 requests per authenticated customer per 5 minutes and 30 requests per source IP per 5 minutes. Assert the next request returns `429` with `SUPPORT_SESSION_RATE_LIMITED` and `Retry-After`, while unrelated API endpoints remain unaffected.

- [ ] **Step 2: Write failing redaction tests**

Inject unique canary strings as the JWT secret and generated token. Exercise success and every error path, then assert neither canary appears in captured application logs, access logs, traces, metrics labels, exception reports, or serialized configuration.

- [ ] **Step 3: Write failing audit-event tests**

Assert one `support.zoho.session` event is emitted with customer ID, environment, outcome, error code when present, request/correlation ID, and timestamp. Assert it excludes email, names, token, secret, request headers, and response body.

- [ ] **Step 4: Implement controls**

Apply the rate limiter after authentication, extend structured-log and trace redaction, emit the safe audit event, and add metrics for request count, success, verification-required, rate-limited, configuration failure, signing failure, and latency.

- [ ] **Step 5: Add alerts**

Create alerts for sustained session failure rate above 5% for 10 minutes, any production configuration failure, and zero successful sessions during a period with requests. Alerts must identify environment and correlation IDs without customer data.

- [ ] **Step 6: Document secret rotation**

The runbook must cover maintenance-window rotation because ASAP exposes a single active JWT secret unless the configured account proves otherwise: disable mobile support, rotate/regenerate the Zoho secret, update the corresponding server secret, deploy/restart, verify a staging-style session, then re-enable. Phone and email remain available during the window.

- [ ] **Step 7: Run focused security tests**

Expected: PASS for limits, redaction canaries, safe audit payloads, and unrelated-route isolation.

- [ ] **Step 8: Commit**

Commit controls, tests, alerts, and runbook with message:

```text
feat: secure Zoho support session issuance
```

### Task 8: Configure Ticketing, Knowledge Base, and Business Messaging

**Artifacts:**
- Configure in Zoho Desk staging: department, layout, fields, categories, SLA, escalation, knowledge base, Business Messaging, agent hours
- Update: `docs/integrations/zoho-desk/zoho-admin-runbook.md`

**Interfaces:**
- Consumes: Approved customer experience and privacy constraints from the design spec.
- Produces: A mobile support form and agent workflow matching the fields the Flutter integration may display or prefill.

- [ ] **Step 1: Create the staging support structure**

Create department `Customer Support` and layout `Mobile App Support`. Assign only the staging support team while configuration is under test.

- [ ] **Step 2: Configure customer-visible fields**

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
- `cf_environment`
- `cf_correlation_id`

- [ ] **Step 3: Configure issue categories**

Set exact customer-facing values:

- Account access
- Profile and security
- Identity verification (KYC)
- Transfers
- Airtime, data, and bills
- Savings
- Other

- [ ] **Step 4: Configure privacy copy and field restrictions**

Show: `Do not include your password, OTP, transaction PIN, BVN, NIN, complete account or card number.` Limit attachments to the business-approved types and maximum size; prohibit executable/archive formats. Ensure hidden context fields are not editable by customers.

- [ ] **Step 5: Configure routing, SLA, and escalation**

Map categories to queues, owners, priorities, first-response targets, resolution targets, business hours, and escalation contacts approved by Support Operations. Do not show response-time promises in the app unless the configured SLA is approved for customer publication.

- [ ] **Step 6: Configure Knowledge Base**

Enable mobile access only to published, customer-approved articles. Seed and approve articles for login/account recovery, KYC, transfers, airtime/data/bills, savings, notification troubleshooting, fraud reporting, and contacting support. Remove internal-only notes and agent procedures.

- [ ] **Step 7: Configure Business Messaging**

Set operating timezone to `Africa/Lagos`, approved operating hours, greeting, queue/offline copy, and offline action to create a ticket. Verify no SalesIQ, Zia, Guided Conversations, or Community module is enabled.

- [ ] **Step 8: Perform agent workflow acceptance**

Using staging customers, create one ticket per category, reply, add a public comment, change status/priority, close/reopen where allowed, test attachment policy, and verify the correct agent queue and SLA timers.

- [ ] **Step 9: Commit sanitized configuration evidence**

Commit the runbook/checklist without customer content or secrets with message:

```text
docs: record Zoho support workflow configuration
```

### Task 9: Configure Zoho Support Push Credentials

**Artifacts:**
- Configure in Zoho Desk staging: Android FCM and iOS APNs support notification credentials
- Update: `docs/integrations/zoho-desk/zoho-admin-runbook.md`

**Interfaces:**
- Consumes: Task 2 identities, staging Firebase/APNs credentials, Zoho staging add-on.
- Produces: Ticket status, priority, reply, public-comment, and Business Messaging notifications deliverable to staging devices.

- [ ] **Step 1: Confirm credential ownership and environment**

Verify the Android credential belongs to the staging Firebase project and the iOS credential is valid for the staging bundle ID and sandbox APNs environment. Do not reuse production credentials.

- [ ] **Step 2: Store credentials through the Zoho administrative channel**

Upload/configure FCM and APNs material using the current Zoho Desk console flow. No credential content belongs in the backend repository or runbook.

- [ ] **Step 3: Verify allowed notification events**

Enable ticket priority update, ticket status update, agent reply, public comment, and Business Messaging agent reply. Disable unrelated marketing or community notifications.

- [ ] **Step 4: Test Android delivery**

For one authenticated staging customer, verify receipt and open behavior from foreground, background, terminated app, token refresh, and logout. Confirm exactly one visible alert per event.

- [ ] **Step 5: Test iOS delivery**

Repeat on a physical iOS device using sandbox APNs. Verify foreground, background, terminated app, token refresh, and logout, with exactly one visible alert.

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

Verify unauthenticated `401`, unverified-email `422`, verified-customer `200`, token signature/claims/expiry, rate-limit `429`, and disabled/configuration-error `503` behavior. Use disposable staging accounts and never paste returned JWTs into the release checklist.

- [ ] **Step 4: Run full backend verification**

Run the exact lint/type, unit, integration, contract/OpenAPI, and full-suite commands recorded in Task 1. Expected: all pass with no snapshot containing tokens or secrets.

- [ ] **Step 5: Run mobile/server end-to-end acceptance**

Verify tickets, ticket history/replies, attachments, knowledge-base search, Business Messaging, notification opens, FCM token refresh, offline recovery, logout, and switching between two customers on Android and iOS.

- [ ] **Step 6: Inspect logs and traces**

Search by staging correlation IDs and canary values. Expected: operational outcomes are visible; email, names, JWT, secret, FCM token, transaction reference, ticket content, and raw Zoho payload are absent.

- [ ] **Step 7: Obtain acceptance sign-off**

Require approval from Backend, Mobile, Security/Privacy, Zoho Administration, and Support Operations. Each signs the release checklist against the design acceptance criteria.

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

Create `BOCTRUST Mobile Production`, register production app identities, enable only Knowledge Base, Tickets, and Business Messaging, configure the production department/layout/workflows, generate a new production JWT secret, and store it only in the production secret manager.

- [ ] **Step 2: Configure production push**

Use the production Firebase project and production APNs credential/mode. Verify that no staging credential or application identity appears.

- [ ] **Step 3: Deploy production disabled**

Deploy all backend code and production identifiers with `ZOHO_DESK_SUPPORT_ENABLED=false`. Run configuration health checks and regression smoke tests for unrelated User Service endpoints.

- [ ] **Step 4: Perform internal canary enablement**

Enable access for the internal staff cohort through the existing release-control mechanism. Verify session issuance, tickets, chat, articles, notifications, logout, and logs before customer rollout.

- [ ] **Step 5: Expand rollout**

Progress from internal staff to a limited customer cohort and then general availability only while session success, latency, support queue health, push delivery, and agent workload stay within approved thresholds.

- [ ] **Step 6: Exercise rollback**

Disable Zoho support and verify the mobile hub immediately preserves call/email fallbacks, banking APIs remain healthy, and no new support JWTs are issued. Re-enable only after the rollback evidence is recorded.

- [ ] **Step 7: Close the release checklist**

Record production identifiers (never secrets), deployment versions, approvals, rollout timestamps, dashboard links, alert ownership, next secret-rotation date, and rollback evidence.

- [ ] **Step 8: Commit**

Commit sanitized production configuration/runbook changes with message:

```text
docs: complete Zoho Desk production rollout
```

## Final Verification Checklist

- [ ] Backend config tests prove disabled behavior, required values, environment isolation, and redaction.
- [ ] JWT tests prove HS256 signature, authoritative claims, five-minute expiry, clock behavior, eligibility, and cross-customer isolation.
- [ ] Endpoint tests prove `401`, `200`, `422`, `429`, and `503` contracts.
- [ ] Logs, traces, metrics, and errors contain no JWT, secret, email, notification token, or ticket content.
- [ ] Zoho staging and production use distinct add-ons, secrets, application identities, and push credentials.
- [ ] Ticket fields and diagnostic context match the allowlist; prohibited identity, banking, and authentication data are absent.
- [ ] Knowledge Base, Tickets, and Business Messaging are enabled; Community, Zia, Guided Conversations, and SalesIQ are disabled.
- [ ] Android and iOS support notifications work in foreground, background, and terminated states without duplicates.
- [ ] Logout and account switching prevent access to the previous customer's Zoho session or notification destination.
- [ ] Call and email remain usable when Zoho is disabled or unavailable.
- [ ] Staging acceptance and production canary approvals are recorded before general availability.
