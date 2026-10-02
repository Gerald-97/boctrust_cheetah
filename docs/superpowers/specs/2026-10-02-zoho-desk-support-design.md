# Zoho Desk Customer Support Design

**Date:** 2026-10-02

**Status:** Proposed for implementation planning

## Purpose

Replace the app's placeholder support experience with authenticated Zoho Desk
support while preserving BOCTRUST's visual language and the existing telephone
and email fallbacks. The first release includes the essential and recommended
features approved for the app: tickets, knowledge base, Business Messaging,
JWT single sign-on, support notifications, and explicitly consented diagnostic
context.

Success means a signed-in customer can find help, create and follow a ticket,
reply to support, chat when agents are available, and open a relevant support
conversation from a notification without signing in to a second system.

## Selected Approach

Use Zoho Desk's current ASAP Flutter SDK for the customer-facing knowledge
base, ticket, and Business Messaging experiences. Place an app-owned gateway
between Flutter widgets/providers and the SDK's static APIs. Add one
authenticated BOCTRUST backend endpoint that returns a short-lived Zoho JWT.

This hybrid approach is preferred to a custom Zoho REST client because it
avoids rebuilding ticket conversations, attachment handling, Help Center
content, chat, and Zoho-specific push routing. It is preferred to a hosted
WebView because it provides stronger native navigation, accessibility, theme,
authentication, and attachment behavior.

Official references:

- [Zoho ASAP Flutter integration](https://help.zoho.com/portal/en/kb/desk/developer-space/asap/flutter-sdk/articles/how-to-integrate-the-asap-sdk-with-flutter-apps)
- [Zoho ASAP Flutter modules](https://help.zoho.com/portal/en/kb/desk/developer-space/asap/flutter-sdk/articles/working-with-the-asap-sdk-for-flutter)
- [Zoho ASAP JWT authentication](https://help.zoho.com/portal/en/kb/desk/developer-space/asap/flutter-sdk/articles/how-to-authenticate-users-on-your-mobile-apps-with-flutter-apps)
- [Zoho ASAP ticket configuration](https://help.zoho.com/portal/en/kb/desk/developer-space/asap/flutter-sdk/articles/how-to-customize-the-tickets-module-for-the-asap-flutter-sdk)
- [Zoho ASAP push notifications](https://help.zoho.com/portal/en/kb/desk/developer-space/asap/flutter-sdk/articles/how-to-enable-push-notifications-for-the-asap-sdk-via-the-flutter-apps)

## Release Scope

### Included

- A BOCTRUST-native Support hub under Account.
- Search and browse of Zoho Desk knowledge-base articles.
- Authenticated ticket creation, list, detail, status, replies, comments, and
  attachments supported by the configured Zoho form.
- Zoho Desk Business Messaging for live-agent chat.
- JWT single sign-on using the signed-in BOCTRUST customer.
- Push registration and routing for ticket and chat updates.
- Optional, allowlisted diagnostic metadata and an explicitly selected
  transaction reference.
- Existing customer-care telephone numbers and support email as fallbacks.
- Feature-flagged staging and production configuration.

### Deferred

- Zoho Community.
- Zia or Answer Bot.
- Guided Conversations.
- SalesIQ, unless BOCTRUST later chooses it as the support team's chat system.
- A custom Flutter implementation of Zoho ticket or article screens.
- Agent-facing Zoho Desk administration.

## Customer Experience

The current Account support group becomes an entry point to a dedicated
Support hub. The hub uses existing BOCTRUST components, spacing, typography,
colors, accessibility preferences, and light/dark theme. It shows:

1. **Help articles** — opens the Zoho knowledge-base module.
2. **Create a support ticket** — opens the configured ticket form.
3. **My support tickets** — opens the authenticated ticket list.
4. **Chat with support** — opens Business Messaging when configured and
   available.
5. **Call customer care** — preserves the two published telephone numbers.
6. **Email support** — preserves `info@boctrustmfb.com`.

The hub must not display fabricated response times, unread counts, agent
availability, or ticket state. Zoho-owned modules may display authoritative
values returned by Zoho.

If Zoho is disabled, misconfigured, unavailable, or cannot authenticate the
customer, the hub remains usable and clearly presents call and email. Retry is
offered for recoverable failures. A Zoho failure never signs the customer out
of BOCTRUST.

## Navigation and Access Control

The support hub and all routes that can expose ticket or chat data are private
routes guarded by the existing `PrivateRouteGate`. The placeholder preview
mapping for support routes is removed.

The route set is:

- `/account/support` — BOCTRUST Support hub.
- `/account/support/articles` — opens Zoho knowledge base.
- `/account/support/tickets` — opens the authenticated ticket list.
- `/account/support/tickets/new` — opens ticket creation.
- `/account/support/chat` — opens Business Messaging.

Telephone and email actions remain on the private Support hub. They do not
need separate preview routes. A notification may target the ticket list or a
specific ticket identifier, but navigation waits until the BOCTRUST session,
home destination, Zoho SDK, and Zoho user session are ready.

## App Architecture

Create a focused `lib/module/support/` feature with model, service, provider,
and screen subdirectories. Widgets and providers do not import Zoho packages
directly.

### `ZohoDeskGateway`

The gateway owns all SDK-specific behavior:

- Initialize exactly once per process with organization ID, application ID,
  and data centre.
- Apply the current light or dark SDK theme and approved BOCTRUST brand
  customizations.
- Report whether the SDK is configured and initialized.
- Authenticate with a backend-issued JWT.
- Log out and clear the Zoho user session.
- Open knowledge base, ticket list, ticket creation, ticket detail, and
  Business Messaging.
- Register and unregister push tokens.
- Identify and pass Zoho notification payloads to the SDK.

The production implementation adapts the ASAP SDK. Tests replace it with a
fake through a Riverpod provider override. Static SDK calls must not appear in
screens or state notifiers.

### Support session coordinator

A Riverpod notifier coordinates SDK initialization and the Zoho user session.
It uses the existing stale-result guard pattern so a response started for one
BOCTRUST user cannot authenticate a later user. Concurrent support launches
share one in-flight initialization/authentication future.

The coordinator keeps the Zoho JWT and expiry in memory only. It requests a
fresh token when none exists or when the current token is within 60 seconds of
expiry. It authenticates immediately before opening an authenticated Zoho
module. Knowledge-base access may initialize without a JWT, but entry from the
signed-in Support hub still uses the same private route.

On BOCTRUST logout, session expiry, account deletion, or user change, the
coordinator logs out of Zoho, unregisters the current push token when possible,
invalidates in-flight work, and clears all in-memory support state.

## Configuration

Add compile-time values for:

- `ZOHO_DESK_ENABLED`
- `ZOHO_DESK_ORG_ID`
- `ZOHO_DESK_APP_ID`
- `ZOHO_DESK_DATA_CENTER`
- `ZOHO_DESK_DEPARTMENT_ID`
- `ZOHO_DESK_TICKET_LAYOUT_ID`

These identifiers are configuration, not authentication secrets. The app
bootstrap validates them only when `ZOHO_DESK_ENABLED` is true. Invalid or
partial configuration fails closed with a support-specific unavailable state;
it must not prevent the rest of the banking app from launching.

Use the current Zoho ASAP "new setup" Flutter packages and pin one exact,
mutually compatible release set after resolving it against the repository's
Flutter, Android, iOS, Gradle, and CocoaPods versions. Android must include
Zoho's documented Maven repositories. The app already exceeds the documented
Android SDK requirements and targets iOS 15; both release builds still require
verification after dependency resolution.

SDK logs may be enabled only in staging and must be disabled in production.

## Backend Contract and JWT Security

Add this authenticated User Service operation:

```http
POST /api/v1/me/support/zoho/session
Authorization: Bearer <BOCTRUST access token>
Content-Type: application/json
```

The request body is empty. The backend derives the customer identity from the
access token and current user record. It must not accept an app-supplied email,
user ID, verification state, or signing claims.

Successful response:

```json
{
  "success": true,
  "message": "Support session created.",
  "data": {
    "jwtToken": "<opaque-signed-token>",
    "expiresAt": "2026-10-02T12:05:00Z"
  }
}
```

The backend signs the Zoho token with the ASAP JWT secret held in server-side
secret storage. Claims use the authoritative BOCTRUST profile and include the
verified email, `email_verified`, first name, last name, `not_before`, and
`not_after`. The validity window must not exceed Zoho's documented ten-minute
maximum. The API rejects customers without a non-empty verified email using a
stable error code such as `SUPPORT_EMAIL_VERIFICATION_REQUIRED`.

The response follows the app's existing API envelope. The client validates a
non-empty token, a parseable UTC expiry, and an expiry in the future. It never
persists or logs the token. The Zoho JWT secret, OAuth credentials, and agent
credentials must never appear in Flutter build arguments, source, assets,
logs, analytics, crash reports, or remote configuration.

## Ticket Form and Context

Zoho Desk owns departments, layouts, required fields, assignment, SLAs, and
escalation rules. BOCTRUST configures the selected department/layout in Zoho
and restricts the mobile form to approved fields:

- issue category;
- subject;
- description;
- optional transaction reference;
- optional customer attachment.

Allowed automatic context is:

- BOCTRUST customer reference;
- app version and build number;
- operating system and version;
- staging or production environment;
- a correlation/request ID when the customer arrived from a failed request.

A transaction reference is included only when the customer explicitly starts
support from a transaction or selects one in the support flow. The form shows
that reference before submission and lets the customer remove it.

The following data is prohibited from ticket fields, metadata, attachments
created by the app, logs, and analytics: NIN, BVN, OTP, password, transaction
PIN, access or refresh tokens, FCM tokens, full account numbers, card numbers,
CVV, balances, raw API payloads, and identity documents. Customers receive a
short warning not to type credentials or identity numbers into free text.

## Notifications

The existing Firebase token registration remains authoritative for BOCTRUST.
Zoho registration is an additional consumer of the same device token after
both the BOCTRUST and Zoho sessions are ready.

- Register the current FCM token with Zoho after Zoho login.
- Re-register after every FCM token refresh.
- Disable Zoho push for the current token during logout when possible.
- Configure the existing transparent notification icon for Android Zoho
  notifications.
- Add the documented iOS APNs registration/processing bridge and use sandbox
  or production mode according to the build environment.

Notification handling classifies payloads before generic route parsing. A
validated Zoho payload is handed to the Zoho SDK only after SDK initialization
and authenticated-destination readiness. All other payloads continue through
the existing `NotificationNavigator`.

Foreground presentation must produce at most one visible alert. The
integration must not show both an app-created local notification and a second
Zoho alert for the same message. Cold-start, background, and foreground opens
must reach the appropriate ticket or chat destination without bypassing the
private route gate.

## Theme, Accessibility, and Design Integration

The Support hub is a normal BOCTRUST screen using `AppScaffold`, existing
cards/tiles, shared buttons, spacing tokens, and semantic colors. It supports
the current text scaling, bold text, high-contrast preference, and screen
reader labels.

Zoho modules use the SDK's light or dark theme matching the current app theme.
Brand customization uses BOCTRUST navy, gold, typography where supported, and
the approved icon. Unsupported SDK styling is accepted rather than patched in
native vendor code. Theme changes made while a Zoho module is open take effect
on the next module launch unless the SDK officially supports live updates.

Loading, unavailable, authentication-required, and retry states are rendered
by BOCTRUST before launching a Zoho module. When control has passed to Zoho,
Zoho owns its internal loading and error UI.

## Error Handling and Observability

Support errors are scoped to support and never expire the BOCTRUST session
unless the User Service itself reports the existing authenticated session as
expired.

- Missing/invalid build configuration: show support unavailable plus call and
  email.
- Backend JWT 401: use the existing session-expiry behavior.
- Email verification required: explain that support history needs a verified
  email and link to the existing profile verification flow.
- Zoho authentication failure: clear the in-memory token and allow one manual
  retry.
- Offline/timeout: show a retryable connection message.
- Chat unavailable or outside operating hours: offer ticket creation, call,
  and email.
- SDK launch exception: return to the Support hub with a non-sensitive error.

Record only event names, coarse outcomes, platform, environment, and existing
request/correlation IDs. Never log JWTs, notification tokens, Zoho payload
contents, ticket descriptions, attachments, customer email, or transaction
references. Production SDK logging remains disabled.

## Zoho Desk Administrative Setup

Before mobile release, an authorized Zoho administrator must:

1. Create separate staging and production ASAP mobile add-ons.
2. Register the Android application ID and iOS bundle ID for each environment.
3. Select the correct data centre and record the org/app identifiers.
4. Enable SSO/JWT and store the one-time JWT secret in backend secret storage.
5. Configure the support department, ticket layout, categories, mandatory
   fields, attachment policy, routing, SLA, and escalation rules.
6. Enable Knowledge Base, Tickets, and Business Messaging for mobile.
7. Configure agent operating hours and offline behavior.
8. Configure Android FCM and iOS APNs credentials for the relevant environment.
9. Publish reviewed knowledge-base content and customer-facing privacy copy.

No mobile build proceeds to production merely because SDK initialization
succeeds; the administrative setup and agent workflow must also pass staging
acceptance.

## Testing and Release Gates

Automated coverage includes:

- configuration parsing and fail-closed behavior;
- backend response parsing and malformed/expired token rejection;
- single-flight initialization and authentication;
- stale response rejection after logout or user change;
- verified-email eligibility;
- gateway calls for articles, tickets, ticket creation, ticket detail, chat,
  push registration, and logout;
- private-route enforcement;
- Support hub loading, available, disabled, error, and fallback states;
- allowlisted ticket context and prohibited-field absence;
- FCM refresh registration and logout cleanup;
- Zoho/non-Zoho payload classification, deduplication, and pending cold-start
  navigation;
- light, dark, high-contrast, text-scale, and semantics behavior.

Build verification includes Flutter analysis and tests, Android debug/release
builds, iOS simulator/debug and no-codesign release builds, and dependency
inspection for minimum platform changes.

Physical-device staging acceptance covers Android and iOS ticket creation,
attachment upload, ticket history, replies, Business Messaging, knowledge-base
search, notification receipt/open in foreground/background/cold start, token
refresh, offline recovery, app logout, and switching between two customer
accounts. Network and application logs are inspected to confirm that no
prohibited data or JWT appears.

Production enablement is controlled by `ZOHO_DESK_ENABLED`. Rollout begins
with internal staff, then a limited customer cohort, then general availability.
Phone and email remain visible throughout rollout and rollback consists of
disabling Zoho while leaving those channels available.

## Acceptance Criteria

- A signed-in customer with a verified email enters Zoho without a second
  login and can create, list, open, and reply to their own tickets.
- Help articles and Business Messaging are reachable from a BOCTRUST-styled
  Support hub.
- Support ticket/chat data cannot be opened through a public route.
- Zoho JWTs are issued by the backend, remain memory-only, and are cleared on
  logout or user change.
- The app sends only allowlisted context and never sends prohibited banking,
  identity, authentication, or notification-token data as ticket context.
- Ticket and chat notifications open the intended Zoho destination after
  authentication and produce no duplicate foreground alert.
- Zoho outages or configuration errors do not block banking features or remove
  call/email fallbacks.
- Light, dark, high-contrast, large-text, and screen-reader use remain
  functional across the BOCTRUST-owned support UI.
- Automated tests, platform builds, physical-device staging checks, Zoho
  administrative setup, and support-agent workflow acceptance all pass before
  production enablement.
