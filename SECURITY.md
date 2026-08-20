# Security Policy

## Supported versions

Only the latest Stellaria pre-release or release receives security fixes.
Upstream DeepSeek Harness and Node.js vulnerabilities must also be reported to
their respective upstream projects when appropriate.

## Reporting a vulnerability

Do not open a public issue for secrets, arbitrary code execution, archive path
traversal, installer privilege escalation, or credential exposure. Use GitHub's
private vulnerability reporting feature for this repository.

Never include real API keys, credentials, private hostnames, or user data in a
report. Include the release tag, architecture, kernel, host glibc, diagnostic
output with secrets removed, and reproduction steps.

## Trust model

- Verify `SHA256SUMS` before extraction.
- Run the installer as an unprivileged user; never use `sudo`.
- Release archives are currently checksum-protected but not cryptographically
  signed. This limitation is disclosed in each affected release.
- The installer does not alter system libraries or global loader settings.
