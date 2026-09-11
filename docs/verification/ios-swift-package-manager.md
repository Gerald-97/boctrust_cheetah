# iOS Swift Package Manager migration verification

Date: 2026-09-11. Baseline commit: `c679a23ba3f3f90b332d1e1d00137a1f99372592`.

## Scope and baseline

Executed in the existing `feat/user-service-api-integration` checkout so the
current application changes participate in validation. Unrelated tracked and
untracked work was preserved; the pre-migration diff, README, and file hashes
were saved under `/tmp/boctrust-spm-*`. No repository reset or bulk staging was
used. The iOS files had no pre-existing changes.

Toolchain: Flutter 3.44.6, Dart 3.12.2, Xcode 26.6 (17F113), CocoaPods 1.16.2.
SwiftPM uses Flutter's default-enabled setting. Deployment target remains 15.0.
`flutter pub get` succeeded without changing pubspec.lock.

The baseline `flutter build ios --simulator --debug` succeeded (Xcode build:
57.0 seconds) and emitted the exact non-standard Podfile migration warning.
Log: `/tmp/boctrust-spm-baseline.log`.

## Migration

`pod deintegrate` succeeded and removed Pods framework links, both manifest
check phases, Pods file groups, and the three RunnerTests Pods base
configurations. Podfile and Podfile.lock were deleted. The remaining Pods
workspace reference and xcconfig includes were removed; local legacy Pods,
.symlinks, and Flutter.podspec artifacts were removed where present.

Runner retains its generated Swift package dependency, prepare pre-action,
Flutter build/embed phases, signing configuration, bundle identifier, and
Debug/Release/Profile xcconfig mappings. No native SDK was added manually.
The eight native plugins remain managed by Flutter: file_picker 10.3.10,
firebase_core 4.13.0, firebase_messaging 16.5.0,
flutter_local_notifications 19.5.0, flutter_secure_storage_darwin 0.3.2,
fluttertoast 10.0.0, shared_preferences_foundation 2.5.6, and smile_id 11.2.12.

## Checks

- Project syntax: `plutil -lint ios/Runner.xcodeproj/project.pbxproj` passed.
- Active Pods references in project, workspace and app xcconfigs: none.
- `git diff --check`: passed after deintegration.
- `flutter clean` and subsequent `flutter pub get`: passed.
- Clean simulator Debug build: passed, Xcode 40.0 seconds, log
  `/tmp/boctrust-spm-debug.log`.
- Unsigned device Profile build: passed, Xcode 51.1 seconds, log
  `/tmp/boctrust-spm-profile.log`.
- Unsigned device Release build: passed, Xcode 40.8 seconds, log
  `/tmp/boctrust-spm-release.log`.
- No CocoaPods migration warning or installation invocation in migrated build
  logs; Podfile, Podfile.lock, Pods, and .symlinks were not recreated.
- `flutter analyze --no-pub`: no issues (4.2 seconds), log
  `/tmp/boctrust-spm-analyze.log`.
- `flutter test --no-pub --reporter expanded`: 858 tests passed, log
  `/tmp/boctrust-spm-tests.log`.
- pubspec.yaml, pubspec.lock and both tracked Package.resolved files: unchanged.
- Independent scoped code review: no actionable findings.
- Simulator launch via `flutter run --no-resident`: passed on iPhone 16e,
  iOS 26.3.1, simulator `F751CA6E-F279-4F97-A0B9-F84FC1805F86`. Used public
  staging endpoint configuration and the separate `spm_migration_smoke` secure
  storage namespace; no account credentials were entered. Onboarding rendered,
  and tapping **I already have an account** displayed the login form. This
  exercises startup through notification initialization, preferences, and
  anonymous session bootstrap, but does not certify authenticated persistence
  or notification delivery. Log: `/tmp/boctrust-spm-launch.log`.
- Native tests: `xcodebuild test` passed with the existing RunnerTests target
  and unchanged `import Flutter`. One empty example test passed, verifying
  compile/link/test-host launch rather than application behavior. The log
  confirms the prepare pre-action and generated plugin package participated.
  Command:

  ```sh
  xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
    -configuration Debug \
    -destination 'platform=iOS Simulator,id=F751CA6E-F279-4F97-A0B9-F84FC1805F86' \
    -clonedSourcePackagesDirPath build/ios/SourcePackages \
    -disableAutomaticPackageResolution
  ```

  Log: `/tmp/boctrust-spm-native-tests.log`. Xcode emitted non-fatal stale
  build-output path warnings when switching from Flutter's build directory to
  the native test build; exit status was 0 with `TEST SUCCEEDED`.
- Hosted CI: not run from this local task; no remote push has been performed.

CI uses `macos-26` rather than the plan's provisional `macos-15`: the current
[official arm64 image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
defaults to Xcode 26.6 (17F113), matching the verified local toolchain. Flutter
is pinned to 3.44.6 in the new job. Existing Ubuntu analysis is unchanged.
Workflow YAML parsing passed using Ruby's YAML parser. The runner's default
Xcode may change as GitHub updates the image; the job prints the selected
version in its logs.

Xcode GUI access was attempted by application name and bundle identifier;
both computer-use calls timed out. Native command-line workspace testing is
used for automation; a successful Xcode GUI Run is not claimed.

## Existing runtime prerequisites

App launch requires ENV, BASE_URL, and SECURE_STORAGE_NAMESPACE, passed through
the existing environment configuration workflow. Builds can compile without
those values but application bootstrap rejects them at runtime.

README already documents missing Firebase native application configuration;
FCM is expected to fail closed until that configuration is supplied. Push
delivery cannot be certified by package compilation. Smile ID camera/APNs and
authenticated persistence checks require a configured physical device/test
account; unsigned device builds do not validate signing or distribution.

## Remaining release checks

- Run the new hosted CI job after the change is pushed.
- Run from the Xcode GUI when its automation/accessibility service responds.
- With a configured test account, verify login and persisted secure storage,
  preferences across restart, file picking, and toast display.
- With Firebase configuration and a physical iOS device, verify push/local
  notification delivery and Smile ID camera capture/cancellation.
- Validate signed archive/distribution through the normal release process.

These checks are not represented by the empty RunnerTests example or unsigned
builds. No dependency upgrade, native app-code edit, or unrelated application
change was needed for the migration.
