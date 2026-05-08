# Governance

Octra Wallet is maintained as a pragmatic open-source wallet project.

## Maintainer Responsibilities

- Review changes for user safety and maintainability.
- Keep release notes accurate.
- Avoid accepting code that weakens key management or transaction safety.
- Keep native PVAC behavior documented and reproducible.

## Release Policy

Production releases should include:

- a GitHub Release
- downloadable APK artifact
- release notes
- validation notes for Flutter and native builds
- no committed secrets or signing credentials

## Decision Records

Architecture decisions should be documented in `docs/` when they affect:

- wallet derivation
- transaction signing
- native PVAC behavior
- storage security
- release packaging
