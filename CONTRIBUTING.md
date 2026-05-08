# Contributing

Thanks for helping improve Octra Wallet.

## Development Principles

- Keep wallet behavior deterministic and auditable.
- Do not add a server dependency for wallet-core operations.
- Keep private keys, seed phrases, and PVAC secrets on device.
- Prefer small, reviewable changes with clear test notes.
- Do not commit secrets, personal access tokens, private keys, seed phrases, or
  production signing keys.

## Local Setup

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
```

For native PVAC work, see:

```text
docs/native-bridge.md
docs/github-actions-build.md
```

## Pull Request Checklist

- Explain what changed and why.
- Include manual test steps.
- Run Flutter analysis.
- If native code changed, run the host smoke test or explain why it was not run.
- Update docs when behavior, build, release, or security posture changes.

## Security-Sensitive Changes

Open an issue or pull request only for non-sensitive security hardening. For
vulnerabilities that could expose funds, keys, seed phrases, or signing logic,
follow `SECURITY.md`.
