# BocTrust patch to dojah_kyc_sdk_flutter 0.1.17

This directory is an otherwise unchanged copy of the published 0.1.17 package.
The native method-channel wrappers contain the following completion fixes:

- Android rejects a launch without an attached activity or widget ID.
- Android rejects a second launch while one result callback is active.
- Android returns typed errors for launch exceptions and missing result data.
- Android atomically clears the callback before completing it and reports the
  Dojah activity result as handled.
- iOS rejects concurrent launches and invalid widget IDs with typed errors.
- iOS atomically clears the callback on navigation and dismissal completions.

The package is also narrowed as follows:

- The plugin is registered for Android only. The iOS sources remain as upstream
  provenance but are not registered or linked, so the app's SwiftPM-only iOS
  build does not pull in DojahWidget, Realm, or their CocoaPods dependencies.
- Android no longer logs the activity result Intent or the raw Dojah result
  payload, which can contain provider data.

No Dojah capture, evidence collection, or matching behavior is changed. The
backend remains authoritative for verification results.
