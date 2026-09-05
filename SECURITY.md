# Security

Please do not report vulnerabilities or private screenshot content in a public issue. Use [GitHub’s private vulnerability reporting](https://github.com/0x63616c/copy-cat/security/advisories/new) for security problems.

Include the CopyCat version, macOS version, impact, and a minimal reproduction using synthetic data. Never include tokens, personal screenshots, or unredacted activity logs. The latest release is the supported version; fixes are released as new versions.

Community release ZIPs currently use ad-hoc signing and are not Apple-notarized. Each release includes a SHA-256 checksum. Automatic updates require a signed Sparkle appcast and Ed25519 archive verification before extraction; these signatures are separate from Apple notarization. See [installation](docs/install.md) and [release signing](docs/releases.md) for the precise distribution status.
