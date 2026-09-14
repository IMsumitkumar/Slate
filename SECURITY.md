# Security

This document covers the repository-specific security expectations for Slate.

## Secrets and Sensitive Data

- Never commit signing credentials, private keys, or any other secret material.
- Do not paste secrets into issues, pull requests, screenshots, or logs shared publicly.
- Treat generated logs and exported artifacts as potentially sensitive until reviewed.

Slate's release flow needs **no `.env` file and no secret material on disk**. There is no Apple Developer account, no team ID, and no notarization credentials: builds are ad-hoc signed.

## Update Signing

Slate uses Sparkle update signing with an EdDSA (ed25519) key pair.

- `slate_public_key.pem` is the public verification key and is safe to keep in the repository. The same value is embedded in the app as `SUPublicEDKey` via `project.yml`.
- The **private** key lives only in the macOS login keychain, under the account name `slate`. It is never written to disk, never placed in `.env`, and never committed. `scripts/publish.sh` signs the appcast by passing `--account slate` to Sparkle's `generate_appcast`, which reads the key straight from the keychain.
- To inspect the public half: `generate_keys --account slate -p`
- To back the private key up before a machine migration: `generate_keys --account slate -x <file>` — then store that file somewhere safe and delete it from the working machine.
- If the private signing key is lost or replaced after releases have shipped, the existing update trust chain is broken and every installed copy must be re-installed manually.

## Code Signing

Slate is ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`). There is deliberately no `DEVELOPMENT_TEAM` and no provisioning profile in `project.yml`. Do not add one.

A consequence: distributed builds are not notarized, so Gatekeeper requires right-click → Open on first launch. That is expected, and the release notes should say so.

## Release Credentials

The only credential the release flow uses is the Sparkle private key in the login keychain, plus a `gh` CLI login for creating the GitHub release. For the current release flow, see:

- `./scripts/build.sh`
- `./scripts/publish.sh`
- `./scripts/release.sh`

## Safe Working Practices

- Review `git status` and `git diff --cached` before every commit.
- Do not add private keys or provisioning profiles to the repository, even temporarily.
- Be careful when sharing crash logs, build logs, and environment output if they may include local paths or account identifiers.

## Reporting Security Issues

If you discover a security issue or accidental secret exposure, do not open a public issue with exploit details or credential contents. Open a GitHub security advisory on [IMsumitkumar/Slate](https://github.com/IMsumitkumar/Slate/security/advisories/new) so the issue can be handled without further exposure.
