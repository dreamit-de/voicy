# Security policy

## Supported versions

Only the latest released version of Voice Transcript receives security updates.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems. Instead:

1. Use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability) on this repository, or
2. Email the maintainers at `security@dreamit.de`.

Please include:
- A clear description of the vulnerability and its impact.
- Steps or a proof-of-concept that demonstrates the issue.
- Any suggested mitigation.

We aim to acknowledge reports within 3 business days and to release a fix or
mitigation guidance within 30 days for high-severity findings.

## Threat model in scope

- Local data exfiltration via the macOS clipboard, microphone, or accessibility APIs.
- Tampering with the Whisper model store or the Ollama integration.
- Code-signing or notarization bypass.

## Out of scope

- Issues that require physical access to an unlocked machine.
- Issues in third-party dependencies that have already been reported upstream
  (please link to the upstream advisory).
