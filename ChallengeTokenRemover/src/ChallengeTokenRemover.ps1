#requires -Version 5.1
<#
.SYNOPSIS
    Removes all equipped League of Legends challenge tokens.

.DESCRIPTION
    Discovers the local League Client API credentials and updates the player's
    challenge preferences with an empty challenge token list.

    The script communicates only with the League Client running on localhost.
    It does not modify game files and does not require a Riot developer API key.

.PARAMETER NoPause
    Prevents the script from waiting for keyboard input before it exits.

.EXAMPLE
    .\ChallengeTokenRemover.ps1

.EXAMPLE
    .\ChallengeTokenRemover.ps1 -NoPause

.NOTES
    The League Client must be running and the user must be signed in.
#>

[CmdletBinding()]
param(
    [switch]$NoPause
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ExitCode = 0

function Write-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $prefix = switch ($Level) {
        'Success' { '[SUCCESS]' }
        'Warning' { '[WARNING]' }
        'Error'   { '[ERROR]' }
        default   { '[INFO]' }
    }

    Write-Host "$prefix $Message"
}

function New-LcuCredentialObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Token,

        [Parameter(Mandatory)]
        [ValidateSet('http', 'https')]
        [string]$Protocol,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Source
    )

    [pscustomobject]@{
        Port     = $Port
        Token    = $Token
        Protocol = $Protocol
        Source   = $Source
    }
}

function Get-LcuCredentialsFromProcess {
    [CmdletBinding()]
    param()

    try {
        $process = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'LeagueClientUx.exe'" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.CommandLine) } |
            Select-Object -First 1
    }
    catch {
        Write-Verbose "Unable to inspect LeagueClientUx.exe: $($_.Exception.Message)"
        return $null
    }

    if ($null -eq $process) {
        return $null
    }

    $portMatch = [regex]::Match(
        $process.CommandLine,
        '(?:^|\s)--app-port(?:=|\s+)[\"]?(\d+)[\"]?'
    )
    $tokenMatch = [regex]::Match(
        $process.CommandLine,
        '(?:^|\s)--remoting-auth-token(?:=|\s+)[\"]?([^\"\s]+)[\"]?'
    )

    if (-not $portMatch.Success -or -not $tokenMatch.Success) {
        return $null
    }

    New-LcuCredentialObject `
        -Port ([int]$portMatch.Groups[1].Value) `
        -Token $tokenMatch.Groups[1].Value `
        -Protocol 'https' `
        -Source 'LeagueClientUx.exe process arguments'
}

function Get-LeagueInstallDirectories {
    [CmdletBinding()]
    param()

    $directories = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    try {
        $processes = Get-CimInstance -ClassName Win32_Process |
            Where-Object { $_.Name -in @('LeagueClient.exe', 'LeagueClientUx.exe') }

        foreach ($process in $processes) {
            if (-not [string]::IsNullOrWhiteSpace($process.ExecutablePath)) {
                [void]$directories.Add((Split-Path -Parent $process.ExecutablePath))
            }
        }
    }
    catch {
        Write-Verbose "Unable to discover the installation path from processes: $($_.Exception.Message)"
    }

    $candidatePaths = @(
        (Join-Path $env:SystemDrive 'Riot Games\League of Legends'),
        (Join-Path $env:ProgramFiles 'Riot Games\League of Legends'),
        $(if (${env:ProgramFiles(x86)}) {
            Join-Path ${env:ProgramFiles(x86)} 'Riot Games\League of Legends'
        }),
        'D:\Riot Games\League of Legends',
        'E:\Riot Games\League of Legends'
    )

    foreach ($path in $candidatePaths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path -PathType Container)) {
            [void]$directories.Add($path)
        }
    }

    # HashSet<T>.ToArray() is not directly available in Windows PowerShell 5.1
    # without invoking LINQ explicitly. Emitting each item keeps compatibility
    # with both Windows PowerShell 5.1 and PowerShell 7+.
    $result = @()
    foreach ($directory in $directories) {
        $result += $directory
    }

    return $result
}

function Get-LcuCredentialsFromLockfile {
    [CmdletBinding()]
    param()

    foreach ($directory in Get-LeagueInstallDirectories) {
        $lockfilePath = Join-Path $directory 'lockfile'

        if (-not (Test-Path -LiteralPath $lockfilePath -PathType Leaf)) {
            continue
        }

        try {
            $content = (Get-Content -LiteralPath $lockfilePath -Raw).Trim()
            $parts = $content.Split(':')

            if ($parts.Count -ne 5) {
                continue
            }

            $port = 0
            if (-not [int]::TryParse($parts[2], [ref]$port)) {
                continue
            }

            if ([string]::IsNullOrWhiteSpace($parts[3]) -or $parts[4] -notin @('http', 'https')) {
                continue
            }

            return New-LcuCredentialObject `
                -Port $port `
                -Token $parts[3] `
                -Protocol $parts[4] `
                -Source $lockfilePath
        }
        catch {
            Write-Verbose "Unable to read lockfile '$lockfilePath': $($_.Exception.Message)"
        }
    }

    return $null
}

function Get-LcuCredentials {
    [CmdletBinding()]
    param()

    $credentials = Get-LcuCredentialsFromProcess
    if ($null -ne $credentials) {
        return $credentials
    }

    return Get-LcuCredentialsFromLockfile
}

function Invoke-LcuRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Credentials,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method,

        [AllowNull()]
        [object]$Body
    )

    $uri = '{0}://127.0.0.1:{1}{2}' -f $Credentials.Protocol, $Credentials.Port, $Path
    $authorizationValue = [Convert]::ToBase64String(
        [Text.Encoding]::ASCII.GetBytes("riot:$($Credentials.Token)")
    )
    $headers = @{
        Authorization = "Basic $authorizationValue"
        Accept        = 'application/json'
    }

    $parameters = @{
        Uri         = $uri
        Method      = $Method
        Headers     = $headers
        ContentType = 'application/json; charset=utf-8'
        TimeoutSec  = 10
    }

    if ($null -ne $Body) {
        $parameters.Body = $Body | ConvertTo-Json -Depth 5 -Compress
    }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $parameters.SkipCertificateCheck = $true
        return Invoke-RestMethod @parameters
    }

    $previousCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback
    try {
        # The local League Client uses a self-signed certificate.
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        return Invoke-RestMethod @parameters
    }
    finally {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = $previousCallback
    }
}

function Remove-EquippedChallengeTokens {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Credentials
    )

    $request = @{
        Credentials = $Credentials
        Path        = '/lol-challenges/v1/update-player-preferences/'
        Method      = 'Post'
        Body        = @{ challengeIds = @() }
    }

    Invoke-LcuRequest @request | Out-Null
}

try {
    Write-Status 'Searching for a running League Client...'
    $credentials = Get-LcuCredentials

    if ($null -eq $credentials) {
        $script:ExitCode = 10
        throw 'League Client credentials were not found. Open the client, sign in, and try again.'
    }

    Write-Status "League Client detected using $($credentials.Source)."
    Write-Status 'Removing equipped challenge tokens...'

    Remove-EquippedChallengeTokens -Credentials $credentials

    Write-Status 'All equipped challenge tokens were removed.' -Level Success
    Write-Status 'Reopen your profile or restart the client if the banner is still cached.'
}
catch {
    if ($script:ExitCode -eq 0) {
        $script:ExitCode = 20
    }

    Write-Status $_.Exception.Message -Level Error
}
finally {
    if (-not $NoPause -and $Host.Name -eq 'ConsoleHost') {
        Write-Host
        Read-Host 'Press Enter to close' | Out-Null
    }
}

exit $script:ExitCode
