# Release & Publishing Guide

---

## 1. Pre-Release Checklist

1. **Verify static analysis and tests**:
   ```bash
   flutter analyze --fatal-infos
   flutter test
   ```
2. **Check formatting**:
   ```bash
   dart format --set-exit-if-changed .
   ```
3. **Verify example builds**:
   ```bash
   cd example
   flutter pub get
   flutter build apk --debug
   flutter build windows --debug
   flutter build web
   cd ..
   ```
4. **Bump version and update changelog**:
   - Update version in `pubspec.yaml` and `example/pubspec.yaml` ([Semantic Versioning](https://semver.org/)).
   - Add a `CHANGELOG.md` entry for the new version.

---

## 2. Dry-Run Verification

```bash
dart pub publish --dry-run
```

- No warnings or errors.
- No unintended files included (check `.pubignore` if needed).

---

## 3. Tag and Push

Push a version tag to trigger the automated release pipeline:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

Pushing the tag automatically:
1. **`release.yml`** — Creates a GitHub Release with a changelog generated from merged PRs since the previous tag. Pre-release tags (`-pre.*`) are skipped.
2. **`publish.yml`** — Publishes to pub.dev using OIDC. Requires **manual approval** in the `pub.dev` environment on GitHub Actions before the publish step runs.

> To approve: go to **Actions → Publish to pub.dev → the triggered run → Review deployments** and approve the `pub.dev` environment.

---

## 4. Verify Publication

After the Actions run completes, confirm the new version appears on [pub.dev](https://pub.dev/packages/flutter_media_session).
