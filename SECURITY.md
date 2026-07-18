# Security Policy

## Supported versions

Security fixes are provided for the latest released version.

## Reporting a vulnerability

Do not publish sensitive details in a public issue. Report the vulnerability privately to the repository owner through GitHub's private vulnerability reporting feature when available.

Include:

- A concise description of the issue
- Reproduction steps
- The affected version
- Expected and observed behavior
- Any proposed mitigation

## Security model

The application reads temporary League Client credentials from the local machine and uses them only for a request to `127.0.0.1`. Credentials must never be logged, persisted, included in screenshots, or sent to external services.
