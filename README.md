# Challenge Token Remover

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A lightweight Windows utility that removes all equipped League of Legends challenge tokens from the profile banner by using the local League Client API (LCU).

> [!IMPORTANT]
> The League Client API is undocumented and may change without notice. This project is unofficial and is not affiliated with or endorsed by Riot Games.

## Features

- One-click launcher for Windows
- Automatic League Client detection
- Process-argument discovery with lockfile fallback
- No Riot developer API key required
- No modification of League of Legends files
- No external network requests or telemetry
- Scoped handling of the League Client's self-signed certificate
- Explicit status messages and process exit codes
- Compatible with Windows PowerShell 5.1 and PowerShell 7+

## Requirements

- Windows 10 or Windows 11
- League of Legends client running and signed in
- Windows PowerShell 5.1 or PowerShell 7+

No installation or third-party PowerShell modules are required.

## Quick start

1. Download the repository or the release archive.
2. Extract the archive.
3. Open the League of Legends client and sign in.
4. Double-click [`Run.bat`](Run.bat).
5. Reopen your profile if the banner does not refresh immediately.

## Manual usage

Run the PowerShell script directly from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\ChallengeTokenRemover.ps1
```

Run without the final input prompt:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\ChallengeTokenRemover.ps1 -NoPause
```

Enable verbose diagnostics:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\ChallengeTokenRemover.ps1 -Verbose
```

## How it works

The script discovers the temporary local credentials of the running League Client using one of two methods:

1. It reads the command-line arguments of `LeagueClientUx.exe`.
2. If that fails, it locates and reads the League Client `lockfile`.

It then authenticates against the LCU on `127.0.0.1` and sends this payload to the challenge preferences endpoint:

```json
{
  "challengeIds": []
}
```

The temporary authentication token is used only in memory. It is never logged, written to disk, or transmitted outside the local computer.

## Repository structure

```text
.
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   └── bug_report.yml
│   ├── workflows/
│   │   └── powershell.yml
│   ├── CODE_OF_CONDUCT.md
│   ├── dependabot.yml
│   └── pull_request_template.md
├── src/
│   └── ChallengeTokenRemover.ps1
├── .editorconfig
├── .gitattributes
├── .gitignore
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── PSScriptAnalyzerSettings.psd1
├── README.md
├── Run.bat
└── SECURITY.md
```

## Exit codes

| Code | Meaning |
| ---: | --- |
| `0` | Operation completed successfully |
| `2` | Launcher could not find the PowerShell script |
| `10` | League Client credentials could not be detected |
| `20` | The LCU request or another runtime operation failed |

## Troubleshooting

### League Client credentials were not found

Confirm that:

- The League Client is open.
- You are signed in and the client has fully loaded.
- The script is running under the same Windows user account as the client.
- Security software is not preventing PowerShell from inspecting local processes.

### Challenge tokens are still visible

The client may cache the profile banner. Open another profile and return to your own, or restart the client.

Do not leave the identity customization window open while running the tool. Closing that window afterward may save the old selection again.

### PowerShell execution is blocked

Use `Run.bat`. It applies `-ExecutionPolicy Bypass` only to that PowerShell process and does not permanently modify the system execution policy.

## Security and privacy

The utility communicates exclusively with the League Client on the loopback address. It does not collect telemetry, contact external services, or persist credentials.

For vulnerability reports, see [SECURITY.md](SECURITY.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## Disclaimer

Challenge Token Remover is an independent community project. Riot Games, League of Legends, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.
