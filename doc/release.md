# Release & Publishing Guide

This guide details the steps required to prepare, test, and publish releases of `flutter_media_session` to [pub.dev](https://pub.dev/packages/flutter_media_session) and GitHub.

---

## 1. Pre-Release Checklist

Before releasing a new version:

1. **Verify All Tests and Static Analysis Pass**:
   ```bash
   flutter analyze --fatal-infos
   flutter test
   ```
2. **Format Code**:
   ```bash
   dart format --set-exit-if-changed .
   ```
3. **Verify Example Project Builds**:
   Ensure the example builds cleanly across the target platforms:
   ```bash
   cd example
   flutter pub get
   flutter build apk --debug
   flutter build windows --debug
   flutter build web
   cd ..
   ```
4. **Update Version & Changelog**:
   - Bump version in `pubspec.yaml` following [Semantic Versioning](https://semver.org/):
     - `MAJOR` for incompatible API changes.
     - `MINOR` for backwards-compatible new functionality.
     - `PATCH` for backwards-compatible bug fixes.
   - Update `CHANGELOG.md` with an entry for the new version detailing bug fixes, new features, and breaking changes.

---

## 2. Verification

Before publishing to pub.dev, perform a dry run to validate package structure, licensing, analyzer checks, and pubspec requirements:

```bash
dart pub publish --dry-run
```

Ensure that:
- No warnings or errors are raised.
- No unintended files are included in the package payload (check `.pubignore` if necessary).
- All dependencies meet pub.dev score and compatibility criteria.

---

## 3. Tagging and GitHub Release

Once dry-run validation passes and the release commit is on `main`, create and push the version tag:

1. **Create and Push Git Tag**:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

2. **Create GitHub Release**:
   Create a release on GitHub matching the pushed tag (`vX.Y.Z`) and summarize changes from `CHANGELOG.md`.

---

## 4. Publishing to Pub.dev

After tagging the release commit, publish the package to pub.dev:

```bash
dart pub publish
```

Authenticate with your Google Account as prompted by the Dart CLI.
