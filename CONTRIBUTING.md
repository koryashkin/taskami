# Contributing to Taskami

Thanks for helping improve Taskami.

## Development workflow

1. Create a focused branch from the repository's default branch.
2. Keep changes small and include tests for new behavior or regressions.
3. Build and run the app on an iOS simulator.
4. Run the relevant unit and UI test targets before opening a pull request.
5. Describe the user-visible impact and verification performed in the pull request.

```sh
xcodebuild test \
  -project Taskami.xcodeproj \
  -scheme Taskami \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

For device builds, use your own signing team, bundle identifiers, and App Group.
Do not commit provisioning profiles, certificates, credentials, or machine-local
Xcode data.

## Code style

- Follow the existing Swift and UIKit/SwiftUI conventions.
- Prefer clear, localized changes over unrelated refactors.
- Preserve TaskPaper round-trip behavior and existing file encodings.
- Add accessibility labels and UI-test coverage for visible controls.

By contributing, you agree that your contribution is distributed under the
repository's license.
