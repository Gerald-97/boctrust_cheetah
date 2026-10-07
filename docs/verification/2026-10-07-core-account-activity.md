# Core account activity and snap-to-pay: verification

Date: 7 October 2026. Branch `feat/core-account-activity`. Plan: [account activity and snap-to-pay](../superpowers/plans/2026-10-07-core-account-activity-and-snap-to-pay.md). The Core API docs are the source of truth (Swagger init SHA-256 `920fbbc4…b28c`).

## Decisions

- G1: the backend opens Core accounts. The app does not call `POST /me/bank-accounts`.
- G7: Scan to pay uses `POST /me/snap-to-pay`, with photos from `image_picker`.

## What shipped (staging only)

- **Account detail** (`/savings/account`, plus `/savings/flex/statement` for Flex):
  - The live `GET /me/bank-accounts/{n}/summary` shows the product, name, number, branch, status and available and ledger balances.
  - Balances arrive as JSON numbers and are displayed as two-decimal strings. `customerId` is dropped.
  - It opens from a savings account tile or from the Flex screen's Account details action.
- **Transactions:** the request is built to the docs (`fromDate`/`toDate` as `DD-MM-YYYY`, 7/30/60-day windows, `numberOfItems`). Rows are **not shown**: the docs publish no item schema.
- **Snap to pay:**
  - Send → Scan to pay reads a 10-digit number and offers BOCTRUST or other-bank sending with the number prefilled.
  - The BOCTRUST and other-bank account fields have a photo button.
  - A number only fills the field and never submits. Other-bank numbers still go through name enquiry.
  - Photos over 8MB are refused before upload.

## Commands

- `flutter analyze`: no issues.
- `flutter test --no-pub`: 1474 passed, 0 failed.

## Open

- [ ] Transactions item schema: capture a sanitized staging reply, type the rows, then register the transactions operation.
- [ ] Staging device checks: summary, Flex detail, snap from the camera and from the gallery, prefill into both transfer forms.
- [ ] Redacting `image`/`number` from staging logs stays deferred to production-launch preparation.
