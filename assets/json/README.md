# Runtime JSON assets

`smile_config.json` is the Smile ID partner configuration. It is deliberately
Git-ignored (`.gitignore`: `**/smile_config.json`) and must be injected into
this directory by the environment's secret-delivery process before a build.

This README exists only so the directory is tracked; `pubspec.yaml` declares
`assets/json/` and Flutter reports an error when the directory is absent.
