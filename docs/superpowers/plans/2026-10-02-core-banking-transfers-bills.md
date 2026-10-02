# Core Banking, Transfers, and Bills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the separate Core Service into Home, Savings, Send, and Payments while keeping User Service behavior isolated and leaving money-moving actions unavailable until secure authorization and response contracts are published.

**Architecture:** Add an optional Core transport rooted at its own `/api` base URL, with separate endpoint metadata, Dio instances, authentication failure policy, services, and session-scoped providers. Deliver accounts/products, interbank directory/name enquiry, and bill catalogues as independently gated slices. Do not call transfer or bill-payment submission endpoints in this release.

**Tech Stack:** Flutter, Dart 3.12+, Riverpod 3, Dio 5, Equatable, existing `ApiService`/`NotifierState`/`StaleResultGuard`, and Flutter unit/widget tests.

**Spec:** The user’s 2 October 2026 endpoint/widget mapping and the live [BocTrust Core Service OpenAPI document](https://core-dev-api.centurysoftware.dev/api/v1/docs/#/), inspected 2 October 2026. Inspected `swagger-ui-init.js` SHA-256: `57f5cbf244f6d4d5ea0c99122e7f263053927b7ef69416c608c7b4b0fec6bee0`. Re-inspected later on 2 October 2026 (SHA-256 `f150ae0096c4429a9a1626f396f5eb35556d66ed3ad21ca13cef084815dbf0ab`); see **Contract Update** below.

**Related delivery stream:** KYC remains on the User Service and is planned in `docs/superpowers/plans/2026-10-01-kyc-provider-document-catalogue.md`. Never route one service’s endpoints through the other service’s transport.

**Working-tree preflight (human checkpoint):** Before Task 1, run `git status --short`. `git add <path>` stages a whole file, so pre-existing uncommitted hunks in any file a task commits would be swept into that task's commit. If `.env.example`, `lib/module/app_flow/app_flow_navigator.dart`, or any other path listed by a task has uncommitted changes the plan did not make, stop and ask your human partner to commit them first. Never commit, stash, restore, or overwrite that work yourself, and do not start Task 1 until the listed paths are clean. Execute this plan after the KYC plan when both touch the same files.

**Human checkpoints:** Steps marked **(human checkpoint)** need staging credentials, backend/product sign-off, physical devices, or a product decision. A subagent must stop there, report what is needed, and wait. Never mark such a step complete from inference.

## Delivery Boundary

### Implement in this release

| Design flow | Endpoint(s) | Widget behavior |
|---|---|---|
| Home balance overview | `GET /me/bank-accounts` | Use verified active Core `bocFlex.availableBalance`; keep User Service DVA independently. |
| Savings hub | `GET /me/bank-accounts`, `GET /bank-products` | Show owned Core accounts and read-only product catalogue. |
| Other-bank recipient | `GET /me/interbank/banks`, `POST /me/interbank/name-enquiry` | Built and tested behind `interbankRecipientLookup`, but held unavailable with no customer entry point until interbank submission ships. |
| Biller directory | `GET /me/bills/billers`, `GET /me/bills/billers/categories` | Server-backed searchable categories and billers, browse only. |
| Airtime/Data catalogue | Above plus `GET /me/bills/payment-items` | Server-approved Mobile/Recharge networks and packages, browse only; no customer-detail entry and no payment submission. |

### Publish endpoints but keep unavailable

| Design flow | Endpoint(s) | Reason |
|---|---|---|
| Send to own account | `POST /me/intrabank/transfers/own` | No transaction-bound authorization or replay/idempotency contract. |
| Send to other bank | `POST /me/interbank/transfers` | Same authorization gap; POST response semantics are incomplete. |
| Transfer status | `GET /me/interbank/transfers/{reference}/status` | No reference can be created while submission is disabled. |
| Buy Airtime/Data and Pay bill | `POST /me/bills/payments` | No transaction-bound authorization and success/response-code contract is incomplete. |

## Contract Update (re-inspected 2 October 2026)

A diff of the two snapshots shows **no endpoints added or removed**. Every endpoint below was already published at plan time; this section records the ones the plan did not scope, plus the three changed definitions.

### Changed definitions

| Item | Change | Effect on this plan |
|---|---|---|
| `CustomerBillPaymentRequest` (`POST /me/bills/payments`) | Required fields reduced to `billerId`, `paymentItemId`, `customerId`, `amount`. `billerName`, `billerCategoryId`, `billerCategoryName` and `paymentItemName` are resolved server-side from the IDs; `customerEmail` and `customerPhone` were removed. | The future bill-payment slice sends IDs only, never display names, and no longer collects or prefills email/phone. Supersedes "mandatory contact fields" wherever this plan mentions them. |
| `POST /me/bills/payments` `404` | Now also returned when `billerId`/`paymentItemId` do not match a real catalogue entry, or the caller has no biodata on file. | A `404` is not only "no BocFlex account"; map it to a customer-safe catalogue/profile error, never retry. |
| `POST /me/snap-to-pay` / `SnapToPayResponse` | OCR returns the longest run of 4+ digits found anywhere in the image; `400` means no such run was found. | Out of scope; recorded for a future Scan-to-pay plan. |

### Mobile endpoints not in this plan's scope

All require `bearerAuth` and use the same Core transport (`coreApiServiceProvider`) when scoped.

| Endpoint | Purpose | Status / prerequisite |
|---|---|---|
| `POST /me/bank-accounts` | Opens a real BankOne CASA account for the caller, one per requested `productCodes` entry (all active catalogue products when omitted). The first successful account needs biodata: `lastName`, `firstName`, `city`, `address`, `gender`, `dateOfBirth`, `phoneNumber`, `bvn`, `email`; later calls reuse the stored record. Returns per-product `created`/`already_exists`/`failed`. | **Blocking dependency for Home/Savings.** Staging users have no Core accounts (`products: []`, `missingProducts: []`), so Task 3 cannot be device-verified until accounts exist. Backend/product must decide whether accounts are opened server-side (for example after Tier 1) or by an app flow; if app-side, write a new plan with its own biodata, consent and duplicate-submission rules. |
| `GET /me/bank-accounts/{accountNumber}` | One owned account with a live balance (`CustomerBankAccountSummary`). | Not needed while Home/Savings use the list call; candidate for a Flex detail refresh. Encode `accountNumber` as one path segment; never log it. |
| `POST /me/intrabank/transfers` | Sends money from the caller's BocFlex account to another BOCTRUST account (`toAccountNumber`, `amount`). | Money-moving; same authorization/idempotency gate as other transfers. Kept out (BOCTRUST-customer transfer was excluded). |
| `POST /me/intrabank/withdrawals` | Moves money from one of the caller's other product accounts back into BocFlex (`fromProductCode`, `amount`). | Money-moving counterpart of `/transfers/own`; would back Savings "Withdraw". Same gate. |
| `POST /me/beneficiaries` | Saves a beneficiary: a bank account (`type: bank_account`, `bankCode` from `GET /me/interbank/banks`, `number`, optional `nickname`) or a biller account. | Excluded (beneficiaries). Depends on the interbank directory fixtures (Task 4 gate). |
| `GET /me/beneficiaries` | Lists the caller's saved beneficiaries (`BeneficiaryResponse[]`). | Excluded; would feed Send recipient pickers. |
| `DELETE /me/beneficiaries/{beneficiaryId}` | Removes a saved beneficiary. | Excluded. |
| `POST /me/snap-to-pay`, `POST /me/scan-to-pay` | OCR: read an account/meter number out of a photo (`image` body). | Excluded (Scan to pay); would prefill an account or customer-ID field only, never submit. |

### Back-office endpoints the app must not call

`PUT /customers`, `PUT /accounts/tier`, `POST /accounts`, `POST /customers/identification`, `POST /customers/passport`, `POST /accounts/supporting-documents`, `/account-management/*`, and the non-`/me` intrabank, interbank and bills operations declare no security and are service-to-service only.

Address verification is **not** a Core mobile flow. The customer submits address and utility bill to the User Service (`/users/me/kyc/utility-bill/initiate` → upload → `/complete`) for manual admin review. Core only stores the address (`PUT /customers`: `address`, `city`) and raises the BankOne tier with `PUT /accounts/tier`, which takes a required `skipAddressVerification` flag. Open backend questions: does Tier 3 approval call these, with which flag value, and is the reviewed address (state → `city`) written back?

## Global Constraints

- Configure `CORE_BASE_URL` using the existing convention: `https://core-dev-api.centurysoftware.dev/api`; append `/v1` once in code.
- A blank Core URL is valid. The app must boot, User Service must continue working, and every Core capability must fail closed as unavailable.
- User and Core operations must carry an explicit backend identifier in capability metadata.
- Core `401` must never expire the User Service session. It produces a Core-scoped unavailable/error state. User Service `401` behavior stays unchanged.
- Core Dio attaches the current User Service bearer token in every configured environment, but no Core-backed capability is registered until Task 3's staging gate proves Core accepts that token. OpenAPI `bearerAuth` naming is not proof of issuer/audience compatibility.
- Do not expose a standalone name enquiry. Without a transfer behind it, it is a free account-holder-name lookup for arbitrary account numbers and spends NIP enquiries for no transaction.
- Do not collect customer identifiers, recipient phone numbers, or account numbers for a flow that cannot be submitted in this release.
- After balance cutover, Core is the sole Home/Savings balance authority. Never fall back to User `flexWallet` during a Core error.
- Cut over only after staging proves User `flexWallet` and Core `bocFlex` represent the same ledger for the same signed-in customer.
- Keep User Service authoritative for profile, tier, KYC, and dedicated funding/DVA data.
- Treat financial values as strings. Never parse money with `double` or `num.tryParse`.
- Never expose or log BVN, KYC payloads, full account numbers, customer IDs, phone/email, PINs, or raw Core responses.
- Keep current money-moving capabilities unavailable. Do not reuse `/auth/pin/verify-current` as transaction authorization.
- Clear Core state on logout, expiry, token/user changes, and late-response races.
- Add no beneficiary, account-opening, history, statement, receipt-sharing, or BOCTRUST-customer-transfer work.

## Contract Gates

Before the directory tasks can be enabled, obtain sanitized authenticated fixtures and bind each operation’s `200` response to its actual `{success, message, data, meta}` envelope:

1. `GET /me/interbank/banks` and `POST /me/interbank/name-enquiry` must specify list/object shapes and stable bank identifiers.
2. Biller categories, billers, and payment items must specify query parameters, list/object shapes, and exact relationships.
3. Backend must define the exact Airtime-versus-Data classification within `Mobile/Recharge`.
4. Payment-item amount must be a decimal string with currency/unit semantics before the client uses it.

If a gate is unresolved, stop that task and leave its capability unavailable. Never infer a payload shape from a component schema that is not attached to the operation.

Money-moving tasks remain outside this release until backend/security publishes transaction-bound authorization, replay/idempotency rules, sanitized fixtures, and success/pending/failure semantics.

## Review Focus

- Missing Core configuration or a Core 401 must not crash or log out an otherwise valid User Service session; pin in Task 1.
- Backend-aware capability metadata must prevent identical paths on different hosts from being treated as the same operation; pin in Task 1.
- A late Core response from user A must not populate user B’s account, bank, biller, or item state; pin in every provider task.
- Balance cutover must happen only after ledger equivalence and must have no cross-service runtime fallback; pin in Task 3.
- Bank/account or biller/item/customer changes must invalidate resolved/review state and never enable a money-moving POST; pin in Tasks 4 and 5.

---

### Task 1: Add Optional, Isolated Core Transport and Backend-Aware Capabilities

**Files:**
- Create: `lib/app/core_api_endpoints.dart`
- Create: `lib/app/core_network.dart`
- Create: `test/core_network_test.dart`
- Modify: `.env.example`
- Modify: `README.md`
- Modify: `lib/app/services.dart`
- Modify: `lib/app/interceptors.dart`
- Modify: `lib/app/feature_capability.dart`
- Modify: `test/feature_capability_test.dart`
- Modify: `test/logging_redaction_test.dart`
- Modify: `test/savings_live_ui_test.dart`
- Modify: `test/savings_provider_test.dart`

**Interfaces:**
- Produces `Env.coreBaseUrl`, `Env.hasCoreBaseUrl`, `coreBaseUrl() -> String?`, `coreDioProvider -> Provider<Dio?>`, `coreApiServiceProvider -> Provider<ApiService?>`, and `CoreApiEndpoints`.
- Changes capability metadata to `enum ApiBackend { user, core }` and `typedef ApiOperation = ({ApiBackend backend, String method, String path});`.
- Produces `configuredApiBackendsProvider -> Provider<Set<ApiBackend>>`. Keep `availabilityOf(capability)` as the structural registry check for source compatibility; `featureAvailabilityProvider` additionally requires every operation backend to be present in the configured set.
- Extends `AuthInterceptor` with optional `isPublicOperation` and `expireSessionOnRemote401` policies while preserving every current constructor call.

- [ ] **Step 1: Write failing environment, routing, auth, and compatibility tests**

Assert:

- blank `CORE_BASE_URL` returns null transport and does not fail `AppBootstrap.initialize()`;
- `https://core-dev-api.centurysoftware.dev/api` becomes `https://core-dev-api.centurysoftware.dev/api/v1`;
- invalid configured values fail validation, including non-HTTPS, `/v1`, or `/api/api/v1`;
- existing User `BASE_URL` behavior is unchanged;
- current three-argument `AuthInterceptor` construction in savings tests still compiles and behaves as before;
- Core requests attach the current bearer token, but Core `401` does not call `expireSessionOnce`;
- User `401` still expires the matching current session and stale-token protection remains intact;
- signed-upload traffic remains token-free;
- capability requirements distinguish `ApiBackend.user` and `ApiBackend.core`.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/core_network_test.dart test/feature_capability_test.dart test/savings_live_ui_test.dart test/savings_provider_test.dart test/logging_redaction_test.dart`

Expected: FAIL because optional Core transport and backend-aware operations do not exist.

- [ ] **Step 3: Implement configuration and transport policies**

Add `CORE_BASE_URL=https://core-dev-api.centurysoftware.dev/api` to `.env.example`. Trim the compile-time value; blank means unconfigured. Validate a nonblank Core URL using the same `/api` convention as User Service and append `/v1` once.

Make the new `AuthInterceptor` parameters optional and default them to current User behavior. User Dio passes User public-operation policy and remote-401 expiry enabled. Core Dio treats every requested operation as authenticated and sets remote-401 expiry false. Local expiry still cancels requests through the existing session path.

Define exact Core endpoint constants/builders for every endpoint in the delivery tables. URI-encode transfer references as one path segment.

- [ ] **Step 4: Add backend-aware capability metadata**

Add `ApiBackend.user` to all existing operations and reserve `ApiBackend.core` for new requirements. `configuredApiBackendsProvider` always contains User and contains Core only when `Env.hasCoreBaseUrl`. Preserve `availabilityOf(capability)` for structural tests and have `featureAvailabilityProvider` downgrade a capability to unavailable when any required backend is not configured. A missing Core transport never makes a User capability unavailable.

- [ ] **Step 5: Extend always-on redaction**

Add normalized `customerid` to `_alwaysRedactedKeyParts`. Keep normalized `accountnumber`, which already covers `receiverAccountNumber`. Test nested and stringified Core bodies, name-enquiry BVN/KYC, customer IDs, full account numbers, and query-like references in both staging and production logging modes.

- [ ] **Step 6: Run and commit the transport slice**

Run: `flutter test test/core_network_test.dart test/feature_capability_test.dart test/savings_live_ui_test.dart test/savings_provider_test.dart test/logging_redaction_test.dart test/api_conflict_data_test.dart`

Expected: PASS with exact host routing, source-compatible interceptors, isolated Core 401 handling, and no sensitive values in logs.

```bash
git add .env.example README.md lib/app/core_api_endpoints.dart lib/app/core_network.dart lib/app/services.dart lib/app/interceptors.dart lib/app/feature_capability.dart test/core_network_test.dart test/feature_capability_test.dart test/logging_redaction_test.dart test/savings_live_ui_test.dart test/savings_provider_test.dart
git commit -m "feat(core): add isolated optional API transport"
```

### Task 2: Model and Load Core Accounts and Products

**Files:**
- Create: `lib/module/core_banking/model/customer_bank_account_models.dart`
- Create: `lib/module/core_banking/model/bank_product_models.dart`
- Create: `lib/module/core_banking/service/core_account_service.dart`
- Create: `lib/module/core_banking/provider/core_account_providers.dart`
- Create: `test/core_account_contract_test.dart`
- Create: `test/core_account_provider_test.dart`
- Modify: `lib/app/private_user_state.dart`
- Modify: `test/logout_private_state_test.dart`

**Interfaces:**
- Produces `CustomerBankAccount`, `CustomerBankAccountsData`, `CoreBankProduct`, `CoreAccountService`, `customerBankAccountsProvider`, and `coreBankProductsProvider`.
- Consumes nullable `coreApiServiceProvider`; missing configuration returns an unavailable state without throwing.

- [ ] **Step 1: Write failing strict parser and selection tests**

Cover required product/account identity, status values, decimal-string balances, immutable collections, duplicate conflicts, malformed sibling rows, UTC dates, and ignoring numeric `totalAvailableBalance`. Select exactly one active, unfrozen `bocFlex`; ambiguity or absence is unavailable.

- [ ] **Step 2: Write failing provider lifecycle tests**

Cover unconfigured Core, idle/load/refresh, in-flight coalescing, retained stale data, logout clearing, token/user changes, and late-response suppression.

- [ ] **Step 3: Run tests and verify failure**

Run: `flutter test test/core_account_contract_test.dart test/core_account_provider_test.dart test/logout_private_state_test.dart`

Expected: FAIL because the models/services/providers do not exist.

- [ ] **Step 4: Implement services and session-scoped providers**

Add `getBankAccounts()` and `getBankProducts()` using the Core service only. Follow existing `UserHomeNotifier` stale-result patterns and never manufacture empty successful data when Core is unconfigured.

- [ ] **Step 5: Run and commit the account slice**

Run: `flutter test test/core_account_contract_test.dart test/core_account_provider_test.dart test/logout_private_state_test.dart`

Expected: PASS with no Core state surviving a session change.

```bash
git add lib/module/core_banking/model/customer_bank_account_models.dart lib/module/core_banking/model/bank_product_models.dart lib/module/core_banking/service/core_account_service.dart lib/module/core_banking/provider/core_account_providers.dart lib/app/private_user_state.dart test/core_account_contract_test.dart test/core_account_provider_test.dart test/logout_private_state_test.dart
git commit -m "feat(core): load customer accounts and products"
```

### Task 3: Verify Authentication and Ledger Equality, Then Cut Over Home and Savings

**Gate:** On controlled staging, prove the same signed-in bearer token can read Core accounts/products and that User `flexWallet` and Core `bocFlex` represent the same ledger. If either check fails, stop before changing widget authority.

**Files:**
- Modify: `lib/module/home/screens/home_screen.dart`
- Modify: `lib/module/savings/screens/savings_screens.dart`
- Modify: `lib/module/savings/provider/savings_provider.dart`
- Modify: `lib/module/savings/model/savings_product_data.dart`
- Modify: `lib/module/app_flow/app_flow_navigator.dart`
- Modify: `lib/app/feature_capability.dart`
- Create: `test/core_home_savings_ui_test.dart`
- Modify: `test/savings_provider_test.dart`
- Modify: `test/savings_product_data_test.dart`
- Modify: `test/savings_ui_test.dart`
- Modify: `test/savings_live_ui_test.dart`
- Modify: `test/savings_access_test.dart`
- Modify: `test/responsive_layout_test.dart`

**Interfaces:**
- Repoints `flexSavingsView` to Core bank accounts and `savingsCatalogueView` to Core accounts plus products.
- Retains User `userHomeProvider` only for DVA/funding and unrelated User Service data.

- [ ] **Step 1 (human checkpoint): Record staging gate evidence**

Your human partner supplies request IDs and masked customer/account identifiers proving token acceptance, plus written backend/product confirmation that `flexWallet` and `bocFlex` are the same ledger. Do not store access tokens or full account numbers, and do not infer equivalence from similar balances. A subagent stops here until that evidence is provided; if either check fails, stop the plan after Task 2.

- [ ] **Step 2: Write failing source-authority tests**

Assert Home uses active `bocFlex.availableBalance`, never numeric aggregate or User `flexWallet`; Core failure has no User-balance fallback; missing/frozen/ambiguous `bocFlex` restricts Send/Pay; DVA remains independently sourced from User Home; Savings uses Core accounts/products; missing Core configuration makes only Core-backed views unavailable.

- [ ] **Step 3: Run tests and verify failure**

Run: `flutter test test/core_home_savings_ui_test.dart test/savings_ui_test.dart test/savings_access_test.dart test/responsive_layout_test.dart`

Expected: FAIL because Home and Savings still use User Home balance/catalogue data.

- [ ] **Step 4: Switch display authority and capabilities**

Match owned accounts to Core products by exact product code. Keep unowned products read-only because account opening is out of scope. Use existing loading/error/stale/responsive components and preserve existing app-flow changes.

Update capability requirements explicitly: `flexSavingsView` requires Core bank accounts; `savingsCatalogueView` requires Core bank accounts and bank products. Do not mark transfers or payments available.

- [ ] **Step 5: Run and commit the widget slice**

Run: `flutter test test/core_home_savings_ui_test.dart test/savings_provider_test.dart test/savings_product_data_test.dart test/savings_ui_test.dart test/savings_live_ui_test.dart test/savings_access_test.dart test/feature_capability_test.dart test/responsive_layout_test.dart`

Expected: PASS with Core as sole balance authority and User DVA preserved.

```bash
git add lib/module/home/screens/home_screen.dart lib/module/savings/screens/savings_screens.dart lib/module/savings/provider/savings_provider.dart lib/module/savings/model/savings_product_data.dart lib/module/app_flow/app_flow_navigator.dart lib/app/feature_capability.dart test/core_home_savings_ui_test.dart test/savings_provider_test.dart test/savings_product_data_test.dart test/savings_ui_test.dart test/savings_live_ui_test.dart test/savings_access_test.dart test/feature_capability_test.dart test/responsive_layout_test.dart
git commit -m "feat(core): show verified accounts on home and savings"
```

### Task 4: Add Interbank Directory and Bound Name Enquiry Only

**Gate:** Obtain sanitized fixtures for bank-list and name-enquiry envelopes. Do not implement from unattached OpenAPI component schemas.

**Files:**
- Create: `lib/module/core_banking/model/interbank_models.dart`
- Create: `lib/module/core_banking/service/core_transfer_service.dart`
- Create: `lib/module/core_banking/provider/interbank_bank_directory_provider.dart`
- Create: `lib/module/core_banking/provider/interbank_recipient_draft_provider.dart`
- Create: `test/interbank_directory_test.dart`
- Create: `test/interbank_name_enquiry_test.dart`
- Modify: `lib/module/send/screens/transaction_flow_screens.dart`
- Modify: `lib/app/feature_capability.dart`
- Modify: `lib/app/private_user_state.dart`
- Modify: `test/transaction_flow_test.dart`
- Modify: `test/transaction_availability_test.dart`
- Modify: `test/feature_capability_test.dart`
- Modify: `test/responsive_layout_test.dart`

**Interfaces:**
- Produces `interbankBankDirectoryProvider`, `ResolvedInterbankRecipient`, and a draft bound to exact bank code plus ten-digit account number.
- Adds the `FeatureCapability.interbankRecipientLookup` enum member but does not register it in `capabilityRequirements`, so `availabilityOf` reports it unavailable in this release. Record its two Core operations in a comment beside the registry for the future submission plan to register together with `transfers`.
- Adds no customer entry point: `send_screens.dart` and the `transfers`-gated tiles at `app_flow_navigator.dart` stay unchanged. Widget tests reach the recipient flow by overriding `featureAvailabilityProvider(FeatureCapability.interbankRecipientLookup)`.
- Does not replace existing withdrawal `bankCatalogueProvider` or existing unavailable `transferSubmissionProvider`.

- [ ] **Step 1: Write failing fixture/parser and draft-integrity tests**

Require nonblank stable bank code/name, immutable deduplicated lists, exact ten-digit account input, and a nonblank resolved name. Parse and discard BVN/KYC. Changing bank or any account digit clears resolution/review; late enquiries cannot overwrite newer drafts; repeated taps coalesce one request.

Also assert that with the registry unmodified, `interbankRecipientLookup` is unavailable, no Send tile or route opens the recipient flow, and no name-enquiry request is issued.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/interbank_directory_test.dart test/interbank_name_enquiry_test.dart test/transaction_flow_test.dart`

Expected: FAIL because the directory and bound draft do not exist.

- [ ] **Step 3: Implement directory, enquiry, and recipient widgets**

Load banks through `interbankBankDirectoryProvider`. Add an explicit Check account action; do not query per keystroke. Replace free-text bank name with searchable server-backed selection and show a resolved name only for the current fingerprint. Gate the recipient widgets with `interbankRecipientLookup`; because it is unregistered, they are reachable only in tests this release.

Keep amount/review/submission unavailable. The existing `transferSubmissionProvider` remains unchanged and continues returning unavailable; do not convert Core results into `TransactionReceipt`.

- [ ] **Step 4: Run and commit the recipient slice**

Run: `flutter test test/interbank_directory_test.dart test/interbank_name_enquiry_test.dart test/transaction_flow_test.dart test/transaction_availability_test.dart test/feature_capability_test.dart test/logging_redaction_test.dart test/responsive_layout_test.dart`

Expected: PASS with recipient validation proven in tests, no production entry point, no money-moving POST, and no BVN/KYC/account leakage.

```bash
git add lib/module/core_banking/model/interbank_models.dart lib/module/core_banking/service/core_transfer_service.dart lib/module/core_banking/provider/interbank_bank_directory_provider.dart lib/module/core_banking/provider/interbank_recipient_draft_provider.dart lib/module/send/screens/transaction_flow_screens.dart lib/app/feature_capability.dart lib/app/private_user_state.dart test/interbank_directory_test.dart test/interbank_name_enquiry_test.dart test/transaction_flow_test.dart test/transaction_availability_test.dart test/feature_capability_test.dart test/responsive_layout_test.dart
git commit -m "feat(core): resolve interbank recipients"
```

### Task 5: Add Bill, Airtime, and Data Catalogues Without Payment Submission

**Gate:** Obtain sanitized fixtures, query/filter semantics, Airtime/Data classification, and string amount/currency semantics.

**Files:**
- Create: `lib/module/core_banking/model/bill_catalogue_models.dart`
- Create: `lib/module/core_banking/service/core_bill_service.dart`
- Create: `lib/module/core_banking/provider/bill_catalogue_providers.dart`
- Create: `test/bill_catalogue_contract_test.dart`
- Create: `test/bill_catalogue_provider_test.dart`
- Modify: `lib/module/payments/screens/payments_screens.dart`
- Modify: `lib/app/route_arguments.dart`
- Modify: `lib/app/feature_capability.dart`
- Modify: `lib/app/private_user_state.dart`
- Modify: `test/transaction_availability_test.dart`
- Modify: `test/feature_capability_test.dart`
- Modify: `test/responsive_layout_test.dart`

**Interfaces:**
- Produces typed immutable category, biller, and payment-item providers plus typed category/biller/item route IDs.
- Adds read-only `billerDirectoryView`, `airtimeCatalogueView`, and `dataCatalogueView` capabilities backed by the verified GET operations, registered only if Step 1 confirms the browse-only release.
- Leaves Airtime, Data, and bill-payment submission capabilities unavailable.

- [ ] **Step 1 (human checkpoint): Confirm the browse-only release with product**

A catalogue customers can browse but not pay from is a product decision. Your human partner confirms that browse-only Airtime/Data/biller screens should ship, or chooses to keep them unregistered like `interbankRecipientLookup`. If they choose to hold them, still build and test, but leave `billerDirectoryView`, `airtimeCatalogueView`, and `dataCatalogueView` out of `capabilityRequirements`.

- [ ] **Step 2: Write failing parser and relationship tests**

Cover stable IDs, names, active flags, category relationships, currency, customer-field labels, string amounts, fixed/variable amount semantics, malformed siblings, duplicate conflicts, empty lists, session clearing, and no cross-biller item leakage. Widget tests assert that no phone, customer-ID, or amount input and no review action render.

- [ ] **Step 3: Run tests and verify failure**

Run: `flutter test test/bill_catalogue_contract_test.dart test/bill_catalogue_provider_test.dart`

Expected: FAIL because catalogue models/providers do not exist.

- [ ] **Step 4: Implement catalogues and directory widgets**

Use documented query parameters from the corrected fixtures. Filter by exact server IDs and approved classification; never infer Data from display text. Replace static category/biller choices with server-backed searchable widgets, deterministic local icons, and a generic fallback. Carry stable typed IDs through `AppRouteArguments`.

Airtime/Data/bill screens are browse only: customers may view networks, billers, and server packages, but render no recipient phone, customer-ID, or amount fields and no Continue/review action. Show honest copy that payments are not yet available. Keep the existing `airtime`, `data`, and `bills` write capabilities unavailable.

- [ ] **Step 5: Run and commit the catalogue slice**

Run: `flutter test test/bill_catalogue_contract_test.dart test/bill_catalogue_provider_test.dart test/transaction_availability_test.dart test/feature_capability_test.dart test/responsive_layout_test.dart`

Expected: PASS with live catalogues and no bill-payment POST.

```bash
git add lib/module/core_banking/model/bill_catalogue_models.dart lib/module/core_banking/service/core_bill_service.dart lib/module/core_banking/provider/bill_catalogue_providers.dart lib/module/payments/screens/payments_screens.dart lib/app/route_arguments.dart lib/app/feature_capability.dart lib/app/private_user_state.dart test/bill_catalogue_contract_test.dart test/bill_catalogue_provider_test.dart test/transaction_availability_test.dart test/feature_capability_test.dart test/responsive_layout_test.dart
git commit -m "feat(core): show live biller catalogues"
```

### Task 6: Record Deferred Money-Moving Contracts Without Enabling Them

**Files:**
- Modify: `README.md`
- Modify: `lib/app/feature_capability.dart`
- Modify: `test/feature_capability_test.dart`
- Modify: `test/transaction_availability_test.dart`
- Create: `docs/verification/core-banking-integration.md`

**Interfaces:**
- Keeps own-account transfer, interbank submission/status, Airtime, Data, and bill payment unavailable.
- Records the exact future validation rule: maximum transfer amount is the minimum applicable User tier limit, available active `bocFlex` balance, and signed-int64 Kobo capacity.

- [ ] **Step 1: Pin unavailable-capability tests**

Assert `interbankRecipientLookup` is unregistered and unavailable; `billerDirectoryView`, `airtimeCatalogueView`, and `dataCatalogueView` match the Task 5 product decision and are independent of the write capabilities; while no provider or widget calls `POST /me/intrabank/transfers/own`, `POST /me/interbank/transfers`, status GET, or `POST /me/bills/payments`; no current-PIN verification is treated as authorization; and directory success does not enable submission.

- [ ] **Step 2: Document backend requirements for the future slice**

Require transaction-bound authorization, replay/idempotency rules, exact response envelopes/status enums, and sanitized fixtures. Record future amount parsing as exact decimal text converted to Kobo without floating point and bounded by tier, balance, and signed int64.

- [ ] **Step 3: Run the capability audit**

Run: `flutter test test/feature_capability_test.dart test/transaction_availability_test.dart`

Expected: PASS with every money-moving capability unavailable.

- [ ] **Step 4: Commit the audit**

```bash
git add README.md lib/app/feature_capability.dart test/feature_capability_test.dart test/transaction_availability_test.dart docs/verification/core-banking-integration.md
git commit -m "docs(core): record banking integration readiness"
```

### Task 7: Final Regression and Device Verification

**Files:**
- Verification only; add findings to `docs/verification/core-banking-integration.md` if necessary and stage that exact file separately.

**Interfaces:**
- Produces release evidence; no runtime interface.

- [ ] **Step 1: Run focused and full verification**

```bash
dart format --output=none --set-exit-if-changed lib test
flutter test test/core_network_test.dart test/core_account_contract_test.dart test/core_account_provider_test.dart test/core_home_savings_ui_test.dart test/interbank_directory_test.dart test/interbank_name_enquiry_test.dart test/bill_catalogue_contract_test.dart test/bill_catalogue_provider_test.dart test/feature_capability_test.dart test/transaction_availability_test.dart test/logging_redaction_test.dart test/logout_private_state_test.dart test/responsive_layout_test.dart
flutter analyze
flutter test --no-pub --reporter expanded
flutter build apk --debug
flutter build ios --simulator --debug
git diff --check
```

Expected: all checks pass and the iOS build preserves SwiftPM-only configuration.

- [ ] **Step 2 (human checkpoint): Verify controlled staging behavior**

On Android and iOS, verify exact hosts, bearer-token acceptance, Core-401 isolation, logout/account-switch clearing, ledger equality evidence, Core balance/product rendering, no reachable name-enquiry entry point, browse-only bill catalogue relationships with no customer-detail fields, responsive/accessibility states, and the absence of every money-moving request.

## Future Money-Moving Plan Gate

Do not execute this section in the current release. Once backend/security supplies the required contracts, write a new dated plan that:

1. implements `CoreMoneyInput.nairaToKobo` with tier/balance/int64 bounds;
2. adds a dedicated own-account provider returning Submitted, never `TransactionReceipt`;
3. adds interbank submission and status providers with no automatic POST retry, registering `interbankRecipientLookup` in the same change as `transfers`;
4. adds shared typed Airtime/Data/bill-payment state without putting a PIN in Core JSON, sending only `billerId`, `paymentItemId`, `customerId` and `amount` (the server resolves names; email/phone are no longer part of the request);
5. refreshes balances only after authoritative completion semantics;
6. decides whether `POST /me/intrabank/withdrawals` (product account → BocFlex) ships with own-account transfers under the same authorization contract;
7. lists `transaction_flow_screens.dart`, `transaction_availability_test.dart`, `responsive_layout_test.dart`, and `route_arguments.dart` in every task that actually changes them.

## Completion Criteria

- Blank Core configuration cannot crash the app or disable User Service features.
- User and Core operations are distinguishable in capability metadata and use separate transports.
- Core 401 never expires the User session.
- Accounts/products load as session-scoped Core data and cannot cross user boundaries.
- Home/Savings cut over only after token and ledger-equivalence evidence, with no User-balance fallback afterward.
- Interbank bank/name enquiry is built only from verified fixtures and has no customer entry point; bill catalogues are browse only, collect no customer details, and ship only with product confirmation.
- Provider names do not collide with existing withdrawal providers, and the legacy unavailable transfer provider is not repurposed.
- Customer IDs, account numbers, BVN/KYC, and other Core secrets remain redacted.
- All money-moving POSTs and transfer-status polling remain unavailable in this release.
- Focused tests, full tests, analysis, Android/iOS builds, and controlled device verification pass.
