# Security Policy

Octra Wallet is non-custodial software. Security issues can directly affect
wallet users, so reports should be handled carefully.

## Supported Versions

The latest GitHub Release is the only supported public build.

## Reporting a Vulnerability

Do not publish a working exploit in a public issue.

Preferred report path:

1. Open a private GitHub security advisory if available.
2. If private advisories are unavailable, contact the repository owner through
   GitHub and provide a minimal description first.
3. Include affected version, platform, reproduction steps, and impact.

Do not include real private keys, seed phrases, or funded wallet credentials in
reports.

## Scope

In scope:

- private key or seed phrase exposure
- incorrect address derivation
- incorrect transaction signing
- PVAC proof/decrypt/encrypt failures that can affect funds
- native library loading or packaging issues
- insecure storage or authentication bypasses

Out of scope:

- phishing websites not hosted by this repository
- social engineering
- third-party wallet misuse
- issues requiring a rooted or jailbroken device unless they bypass documented
  warnings

## Disclosure

Responsible disclosure is expected. Public disclosure should wait until a fix is
available or maintainers explicitly approve disclosure.
