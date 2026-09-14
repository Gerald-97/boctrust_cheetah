# Dojah KYC integration verification

Verified on 2026-09-14 in the isolated `codex/dojah-kyc` worktree.

## Versions

- Flutter package: `dojah_kyc_sdk_flutter` 0.1.17
- Android SDK: `com.github.dojah-inc:sdk-kotlin:v0.4.2`
- iOS DojahWidget: 1.1.17 at commit
  `46f11f2938f4b70fe0cde915b68d34a5d712ba8c`
- iOS Realm compatibility candidate: 10.54.6

## Passing checks

- `flutter analyze --no-pub`
- `flutter test --no-pub --reporter expanded` (810 tests)
- `flutter build apk --debug`
- `flutter build apk --release`
- `./gradlew :dojah_kyc_sdk_flutter:compileReleaseKotlin --rerun-tasks`

Android required JitPack, Jetifier for Dojah's legacy support-library
dependency, API 36 for the Dojah library module, Kotlin/JVM 1.8 for that
module, desugaring 2.1.5, and a manifest label override for a transitive
dependency. These settings are scoped to the published SDK where possible.
The repository-local copy also applies the completion-only changes recorded in
`packages/dojah_kyc_sdk_flutter/BOCTRUST_PATCH.md`.

## iOS compatibility result

The reviewed hybrid strategy keeps existing Flutter plugins, including Smile
ID, on Swift Package Manager and installs only DojahWidget and Realm through
CocoaPods. A clean simulator build exposed two upstream compatibility issues:

1. DojahWidget 1.1.17 constrains RealmSwift to 10.52.2. That release's module
   is read by Xcode 26.6 as requiring iOS 26.5 and cannot compile for the app's
   iOS 15 target. A local podspec using Realm 10.54.6 resolves this issue.
2. Smile and Dojah both bring Lottie 4.5.2 through different dependency
   managers. Embedding both produces duplicate `Lottie.framework` commands.
   Leaving SwiftPM as the only embed owner reaches the linker but fails because
   Dojah's CocoaPods build requires `unsafeMutableAddressor` symbols that the
   SwiftPM Lottie binary does not expose.

For comparison only, disabling SwiftPM and resolving all existing iOS plugins
through CocoaPods produced a successful simulator build. That migration was
rolled back because the approved plan explicitly limits CocoaPods to Dojah and
forbids migrating the existing plugins. The hybrid configuration remains the
recorded compatibility blocker and must not be released as-is.

Physical-device capture, actual widget IDs, native completion edge cases, and
backend webhook reconciliation remain unverified until an approved iOS package
strategy and the backend provider response contract are available.

## Backend documentation check

The live demo Swagger documents `POST /api/v1/user/send-bvn-otp` with an
11-digit `bvn`, and `POST /api/v1/user/verify-bvn-otp` with a six-digit numeric
`otp`. Their HTTP 200 entries contain descriptions only and define no response
schema. It does not document a provider-aware identity initiation response or
the proposed resume/capabilities operations. The development API documentation
URL returned 404 when checked.
