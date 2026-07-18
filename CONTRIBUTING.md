# Contributing

Contributions that improve reliability, compatibility, documentation, or maintainability are welcome.

## Development requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7+
- A running League of Legends client for integration testing

## Workflow

1. Fork the repository and create a focused feature branch.
2. Keep changes small and limited to one purpose.
3. Follow the existing PowerShell naming and formatting conventions.
4. Run the script with `-Verbose` and verify both success and failure paths.
5. Update the README and changelog when behavior changes.
6. Open a pull request describing the problem, implementation, and test results.

## Code standards

- Use approved PowerShell verbs.
- Enable strict mode and use terminating errors where appropriate.
- Do not log, persist, or expose LCU authentication tokens.
- Do not add telemetry or external network requests.
- Avoid third-party dependencies unless there is a clear technical necessity.
- Preserve compatibility with Windows PowerShell 5.1 unless a major release explicitly changes the requirement.

## Testing checklist

- Client closed: exits with code `10` and a clear message.
- Client open and signed in: removes equipped tokens and exits with code `0`.
- Missing script: `Run.bat` exits with code `2`.
- `-NoPause`: exits without waiting for input.
- `-Verbose`: provides useful diagnostics without exposing credentials.
