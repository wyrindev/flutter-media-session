# Contributing

## Development Environment

- **Flutter SDK**: `>= 3.3.0`
- **Dart SDK**: `>= 3.3.0 < 4.0.0`

Testing on physical devices is recommended, especially for Android and iOS background behavior.

---

## Issues

Search existing issues before filing a new one.

### Bug Reports
- Use a clear title.
- Include a minimal reproduction snippet (MRE).
- List affected platforms and device models.
- Attach `flutter doctor -v` output.

### Feature Requests
- Describe the use case and, if possible, a proposed API shape.

> [!TIP]
> Open an issue to discuss significant changes before starting a PR.

---

## Pull Requests

### 1. Before You Start
- Fork the repository and branch from `main`.
- For `v2` changes, target the `dev/v2` branch.
- Follow `flutter_lints` rules.
- For anything beyond typos or small bug fixes, there should be a related issue.

### 2. PR Permissions
When opening a Pull Request, **check "Allow edits from maintainers"**.

> [!IMPORTANT]
> This is required — it allows rebasing and minor adjustments without going back and forth.

### 3. Commit & PR Format

`<type>(<platform>): <description>`

- **Types**: `feat`, `fix`, `docs`, `refactor`, `style`, `test`, `chore`
- **Platforms**: `android`, `ios`, `macos`, `windows`, `web`, `all`, `core`

**Example**: `feat(android): add support for custom media actions`

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](https://github.com/wyrindev/flutter-media-session/blob/main/LICENSE).