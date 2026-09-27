<#
.SYNOPSIS
Reviews, backs up, clones, and restores Exchange Server Receive Connector configuration.

.DESCRIPTION
ExchangeReceiveConnectorManager.ps1 is an Exchange Server Receive Connector review, backup, clone, and restore tool for side-by-side deployments, upgrades, migrations, and replacement-server work.

The default mode is Configuration Review / Backup. In this mode, the script only reads Receive Connector configuration from one or more Exchange Mailbox servers. No Exchange configuration changes are made.

When -OutputFile is used in Review mode, the script creates two files with the same base name. The TXT file is a human-readable report. The JSON file is the structured, versioned backup used for Restore operations. Restore accepts JSON only.

Clone mode uses a live Exchange server as the source and compares selected Receive Connectors with one or more target servers. Clone is preview-only by default. No Exchange configuration changes are made unless -ApplyChanges is explicitly specified.

Restore mode is selected with -RestoreFile. Restore is also preview-only by default. The script reads the JSON backup, compares it with the target server, and displays the proposed restore plan. No Exchange configuration changes are made unless -ApplyChanges is explicitly specified.

The inventory and managed configuration scope includes:
- Built-in vs custom connector classification
- Enabled
- Bindings
- RemoteIPRanges
- Fqdn
- AuthMechanism
- PermissionGroups
- RequireTLS
- TlsCertificateName
- TlsDomainCapabilities
- ProtocolLoggingLevel
- MaxMessageSize
- Banner
- TransportRole
- Explicit Receive Connector AD permissions for inventory/review
- Anonymous relay state based on the explicit ms-Exch-SMTP-Accept-Any-Recipient right assigned to NT AUTHORITY\ANONYMOUS LOGON

Clone and Restore safety rules:
- Preview is the default for both Clone and Restore.
- Changes require the explicit -ApplyChanges switch.
- Custom Receive Connectors are in Clone and Restore scope by default.
- Built-in Receive Connectors are never created or deleted.
- Use -IncludeBuiltIn to include existing built-in connectors in supported property alignment.
- Source and target connector types must match; a custom name cannot overwrite a built-in connector.
- Specific source binding IP addresses must be verifiable on the target server before that connector can be changed.
- A non-empty TlsCertificateName is not applied unless the matching valid SMTP certificate is available on the target server.
- An unavailable source-specific binding or required TLS certificate blocks the entire connector, including settings, permissions, and activation.
- Apply aborts with exit code 1 before any changes if any selected connector has a BLOCKER, including after the pre-apply refresh.
- Missing backup properties are unavailable, not explicit nulls. Existing values are preserved; incomplete new connector definitions are blocked.
- Server-specific built-in connector FQDN values are translated from the source server FQDN to the target server FQDN.
- Explicit Receive Connector AD permissions remain review-only except for anonymous relay when -IncludeAnonymousRelayPermissions is specified.
- Target state is re-read before Apply. A fresh target pre-change JSON snapshot is saved immediately before changes, and Apply aborts if target connector state changes after the refreshed plan is displayed.
- Apply stops on the first runtime connector error; verification still runs for the final target state.

This script is intended for Exchange Server Mailbox servers.

.PARAMETER Server
One or more Exchange Mailbox servers to review. If omitted, the local computer is used.

.PARAMETER SourceServer
In Clone mode, the live Exchange Mailbox server whose Receive Connector configuration is used as the source.
In Restore mode, selects the source server entry when the JSON backup contains more than one server. It is optional when the backup contains only one server.

.PARAMETER TargetServers
One or more Exchange Mailbox servers that will be compared with the live source server in Clone mode.

.PARAMETER RestoreFile
Path to a JSON backup created by ExchangeReceiveConnectorManager.ps1. Supplying this parameter selects Restore mode. TXT reports are not accepted for Restore.

.PARAMETER TargetServer
Exchange Mailbox server that will receive the restored configuration. Required in Restore mode.

.PARAMETER ConnectorName
Optional connector name or built-in connector family name to process in Clone or Restore mode. Multiple values are supported. If omitted, all in-scope connectors are evaluated.

.PARAMETER IncludeBuiltIn
Includes existing Exchange built-in Receive Connectors in Clone or Restore comparison and supported property alignment. Built-in connectors are never created or deleted.

.PARAMETER IncludeAnonymousRelayPermissions
Includes alignment of the explicit ms-Exch-SMTP-Accept-Any-Recipient right for NT AUTHORITY\ANONYMOUS LOGON. Other explicit Receive Connector AD permissions remain review-only.

.PARAMETER ApplyChanges
Applies the displayed Clone or Restore plan. Without this switch, Clone and Restore are preview-only.

.PARAMETER OutputFile
In Review mode, specifies the TXT report path and also creates a JSON backup with the same base file name. The JSON file is the backup used for Restore.
In Clone or Restore mode, exports the displayed plan to a TXT file without changing the apply behavior.

.PARAMETER NoPaging
Disables console paging.

.PARAMETER Help
Displays a short usage guide and exits.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1
Reviews Receive Connector configuration on the local Exchange server. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -Server EX01,EX02
Reviews Receive Connector configuration on EX01 and EX02. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -Server EX01 -OutputFile C:\Temp\EX01-ReceiveConnectors.txt
Creates a human-readable TXT report and a restore-compatible JSON backup for EX01.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02
Previews cloning custom Receive Connectors from live server EX16-01 to EXSE01 and EXSE02. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02 -ConnectorName "App Relay" -ApplyChanges
Applies the reviewed clone plan for App Relay to EXSE01 and EXSE02.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -IncludeBuiltIn
Previews cloning custom Receive Connectors and supported alignment of existing built-in Receive Connectors. Built-in connectors are never created or deleted.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -IncludeAnonymousRelayPermissions
Previews cloning App Relay and includes alignment of the explicit anonymous relay right. Other explicit Receive Connector AD permissions remain review-only.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX16-ReceiveConnectors.json -TargetServer EXSE01
Previews restoring custom Receive Connectors from the JSON backup to EXSE01. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\ReceiveConnectors.json -SourceServer EX16-01 -TargetServer EXSE01 -ApplyChanges
Uses the EX16-01 entry from a combined JSON backup and applies the supported custom Receive Connector restore plan to EXSE01.

.NOTES
Author     : Ceyhun Kirmizitas
Version    : 1.0
Date       : 27/09/2026
Applies to : Exchange Server Mailbox servers
Shell      : Windows PowerShell 5.1
Website    : https://ceyhunkirmizitas.net
GitHub     : https://github.com/Ceyhun-Kirmizitas
LinkedIn   : https://www.linkedin.com/in/ceyhun-kirmizitas/

Change log
----------
1.0 - 27/09/2026
- Initial release of ExchangeReceiveConnectorManager.ps1.
- Added local and multi-server Receive Connector review with human-readable TXT reporting and structured JSON backup.
- Added live server-to-server Clone Preview and JSON-based Restore Preview with explicit -ApplyChanges for changes.
- Added custom connector creation and supported property alignment for existing connectors.
- Added optional alignment of existing built-in connectors with -IncludeBuiltIn; built-in connectors are never created or deleted.
- Added explicit Receive Connector AD permission inventory and optional anonymous relay alignment with -IncludeAnonymousRelayPermissions.
- Added target binding, TLS certificate, connector-type, and name-collision safety validation.
- Added refreshed pre-apply planning, drift detection, automatic target pre-change JSON snapshots, and post-apply verification.
- Added whole-plan BLOCKER handling so Apply stops before any change when a selected connector is unsafe to process.
- New custom connectors are created disabled, configured while disabled, and enabled only after all managed settings and permissions succeed.
- Missing backup properties are treated as unavailable so existing target values are preserved instead of being cleared.
- Added Windows PowerShell 5.1 compatibility handling for Exchange Management Shell initialization, remoting serialization, null/empty values, flags, and collections.
- Added startup safety information, console paging, -NoPaging, built-in -Help, and comment-based help examples.

License
-------
MIT License
Copyright (c) 2026 Ceyhun Kirmizitas

Caution
-------
Use this script at your own risk.
Review and test it in your environment before production use.
The author is not responsible for any issues, outages, or data loss resulting from its use.

.LINK
https://ceyhunkirmizitas.net

.LINK
https://github.com/Ceyhun-Kirmizitas

.LINK
https://www.linkedin.com/in/ceyhun-kirmizitas/
#>

#requires -version 5.1

[CmdletBinding(DefaultParameterSetName = 'Review', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(ParameterSetName = 'Review')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Server,

    [Parameter(Mandatory = $true, ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [ValidateNotNullOrEmpty()]
    [string]$SourceServer,

    [Parameter(Mandatory = $true, ParameterSetName = 'Clone')]
    [ValidateNotNullOrEmpty()]
    [string[]]$TargetServers,

    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')]
    [ValidateNotNullOrEmpty()]
    [string]$RestoreFile,

    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')]
    [ValidateNotNullOrEmpty()]
    [string]$TargetServer,

    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [string[]]$ConnectorName,

    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [switch]$IncludeBuiltIn,

    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [switch]$IncludeAnonymousRelayPermissions,

    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [switch]$ApplyChanges,

    [Parameter(ParameterSetName = 'Review')]
    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [string]$OutputFile,

    [Parameter(ParameterSetName = 'Review')]
    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [switch]$NoPaging,

    [Parameter(ParameterSetName = 'Review')]
    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ToolName = 'ExchangeReceiveConnectorManager'
$script:ScriptVersion = '1.0'
$script:ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

$script:AnonymousLogonPrincipal = 'NT AUTHORITY\ANONYMOUS LOGON'
$script:AnonymousRelayRight = 'ms-Exch-SMTP-Accept-Any-Recipient'

$script:BuiltInConnectorFamilies = @(
    'Default Frontend',
    'Client Frontend',
    'Outbound Proxy Frontend',
    'Default',
    'Client Proxy'
)

$script:ManagedProperties = @(
    'Enabled',
    'Bindings',
    'RemoteIPRanges',
    'Fqdn',
    'AuthMechanism',
    'PermissionGroups',
    'RequireTLS',
    'TlsCertificateName',
    'TlsDomainCapabilities',
    'ProtocolLoggingLevel',
    'MaxMessageSize',
    'Banner',
    'TransportRole'
)
$script:ConnectorPropertyNames = @($script:ManagedProperties)

if ($Help) {
    @"
$($script:ToolName).ps1
Exchange Server Receive Connector review, backup, clone, and restore manager

COMMON USAGE
  Review the local server (default, no changes):
    .\ExchangeReceiveConnectorManager.ps1

  Review selected servers:
    .\ExchangeReceiveConnectorManager.ps1 -Server EX01,EX02

  Create a TXT report and JSON backup:
    .\ExchangeReceiveConnectorManager.ps1 -Server EX01 -OutputFile C:\Temp\EX01-ReceiveConnectors.txt

  Preview live server-to-server clone:
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02

  Preview one connector:
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02 -ConnectorName "App Relay"

  Apply a reviewed clone plan:
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02 -ConnectorName "App Relay" -ApplyChanges

  Preview restore from JSON backup:
    .\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX16-ReceiveConnectors.json -TargetServer EXSE01

  Apply a reviewed restore plan:
    .\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\ReceiveConnectors.json -SourceServer EX16-01 -TargetServer EXSE01 -ApplyChanges

  Preview Clone including existing built-in connectors:
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -IncludeBuiltIn

  Preview Clone including anonymous relay permission alignment:
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -IncludeAnonymousRelayPermissions

NOTES
  - Review mode is read-only. Changes: NONE.
  - JSON is the backup format used by Restore. TXT is the human-readable report.
  - Clone and Restore are preview-only unless -ApplyChanges is specified.
  - Built-in Receive Connectors are never created or deleted.
  - Other explicit AD permissions remain review-only; anonymous relay is opt-in.
  - A source-specific binding that cannot be verified blocks the entire connector plan.
  - Existing disabled connectors are enabled only after all other managed changes succeed.
  - Apply stops on the first runtime connector error.
  - A target pre-change JSON snapshot is saved before Apply.
  - Console output pauses about once per screen. Press ENTER to continue or Q to stop paging.
  - For full help:
      Get-Help .\ExchangeReceiveConnectorManager.ps1 -Full
"@ | Write-Host
    return
}

# ---------------------------------------------------------------------------
# Exchange Management Shell
# ---------------------------------------------------------------------------
function Initialize-ExchangeShell {
    if (Get-Command Get-ExchangeServer -ErrorAction SilentlyContinue) { return }
    if (-not $env:ExchangeInstallPath) { throw 'Exchange Management Shell commands were not found.' }

    $remoteExchange = Join-Path $env:ExchangeInstallPath 'bin\RemoteExchange.ps1'
    if (-not (Test-Path -LiteralPath $remoteExchange)) { throw 'Exchange Management Shell commands were not found.' }

    # Microsoft's RemoteExchange.ps1 / Connect-ExchangeServer bootstrap code can
    # reference variables that are intentionally unset. Temporarily disable this
    # script's StrictMode while Exchange Management Shell is initialized, then
    # restore the script's normal StrictMode immediately afterwards.
    Set-StrictMode -Off
    try {
        . $remoteExchange
        Connect-ExchangeServer -Auto -AllowClobber | Out-Null
    }
    finally {
        Set-StrictMode -Version 2.0
    }

    if (-not (Get-Command Get-ExchangeServer -ErrorAction SilentlyContinue)) {
        throw 'Exchange Management Shell could not be initialized.'
    }
}

# ---------------------------------------------------------------------------
# Generic helpers
# ---------------------------------------------------------------------------
function Get-SafeArray {
    param($Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Object) { return $null }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return ,$Object[$Name]
        }
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }

    # Preserve collection values as one pipeline object, including an explicit empty array.
    # Unary-comma return avoids Write-Output -NoEnumerate wrapper serialization in Windows PowerShell 5.1.
    return ,$property.Value
}

function Get-SourceConnectorValue {
    param(
        [Parameter(Mandatory = $true)]$Connector,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    $values = Get-ObjectPropertyValue -Object $Connector -Name 'Values'
    if ($null -eq $values) { return '<not returned>' }
    # An omitted field is unknown. Only an explicitly present null can clear a value.
    if ($values -is [System.Collections.IDictionary]) {
        if ($values.Contains($PropertyName)) {
            return ,$values[$PropertyName]
        }
        return '<not returned>'
    }
    $property = $values.PSObject.Properties[$PropertyName]
    if ($null -eq $property) { return '<not returned>' }

    # Keep [] distinct from null when values are read back from JSON without creating a wrapper object.
    return ,$property.Value
}

function Test-IsUnavailableValue {
    param($Value)

    return ($Value -is [string] -and $Value.Equals('<not returned>', [System.StringComparison]::OrdinalIgnoreCase))
}

function ConvertTo-StrictBoolean {
    param($Value)

    if ($Value -is [bool]) { return [bool]$Value }
    if ($Value -is [string]) {
        $text = $Value.Trim()
        if ($text.Equals('true', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($text.Equals('false', [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    }
    throw "Value '$Value' cannot be converted safely to Boolean."
}

function Normalize-ByteSizeValue {
    param($Value)

    if ($null -eq $Value) { return $null }

    try {
        if ($null -ne $Value.PSObject.Methods['ToBytes']) {
            $bytes = [uint64]$Value.ToBytes()
            return ("{0}B" -f $bytes)
        }
    }
    catch {
        # Fall back to the string representation below.
    }

    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    if ($text -ieq 'Unlimited') { return 'Unlimited' }

    # Exchange ByteQuantifiedSize commonly includes the exact byte count in
    # parentheses. Prefer that value so backup/restore does not lose precision.
    if ($text -match '\((?<bytes>[\d,\. ]+)\s+bytes\)') {
        $bytes = $Matches['bytes'] -replace '[^0-9]', ''
        if ($bytes) { return "${bytes}B" }
    }

    if ($text -match '^(?<number>\d+(?:[\.,]\d+)?)\s*(?<unit>B|KB|MB|GB|TB)\b') {
        return (($Matches['number'] -replace ',', '.') + $Matches['unit'])
    }

    return $text
}

function Normalize-ConnectorPropertyValue {
    param(
        [Parameter(Mandatory = $true)][string]$PropertyName,
        $Value
    )

    if ($null -eq $Value) { return $null }
    if (Test-IsUnavailableValue -Value $Value) { return '<not returned>' }

    switch ($PropertyName) {
        { $_ -in @('Bindings','RemoteIPRanges','TlsDomainCapabilities') } {
            # Earlier backup files could serialize an empty collection as {}. Treat an
            # empty PSCustomObject from that legacy serialization as an empty list.
            if ($Value -is [PSCustomObject] -and @($Value.PSObject.Properties).Count -eq 0) {
                return ,([string[]]@())
            }

            $items = New-Object System.Collections.ArrayList
            foreach ($item in @(Get-SafeArray -Value $Value)) {
                if ($null -eq $item) { continue }
                $text = ([string]$item).Trim()
                if (-not [string]::IsNullOrWhiteSpace($text)) {
                    [void]$items.Add($text)
                }
            }

            # Return the typed array as one pipeline object. This preserves [] and
            # one-item arrays without the value/Count wrapper produced by
            # Write-Output -NoEnumerate in Windows PowerShell 5.1.
            return ,([string[]]@($items))
        }
        { $_ -in @('AuthMechanism','PermissionGroups') } {
            $items = New-Object System.Collections.ArrayList

            foreach ($item in @(Get-SafeArray -Value $Value)) {
                if ($null -eq $item) { continue }

                foreach ($part in @(([string]$item).Split(','))) {
                    $text = $part.Trim()
                    if (-not [string]::IsNullOrWhiteSpace($text)) {
                        [void]$items.Add($text)
                    }
                }
            }

            # Preserve the normalized string array as one pipeline object so a
            # single flag/group does not collapse back to a scalar string.
            return ,([string[]]@($items))
        }
        { $_ -in @('Enabled','RequireTLS') } {
            return (ConvertTo-StrictBoolean -Value $Value)
        }
        'MaxMessageSize' {
            return Normalize-ByteSizeValue -Value $Value
        }
        default {
            $text = [string]$Value
            if ([string]::IsNullOrWhiteSpace($text)) { return $null }
            return $text
        }
    }
}

function Get-SettablePermissionGroups {
    param($Value)

    if ($null -eq $Value) { return $null }
    if (Test-IsUnavailableValue -Value $Value) { return '<not returned>' }

    $normalized = Normalize-ConnectorPropertyValue -PropertyName 'PermissionGroups' -Value $Value
    $groups = New-Object System.Collections.ArrayList

    foreach ($group in @(Get-SafeArray -Value $normalized)) {
        if ($null -eq $group) { continue }

        $name = ([string]$group).Trim()
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        # Exchange can report Custom when explicit AD permissions exist, but
        # Custom is not a value that should be passed back to Set-ReceiveConnector.
        # Explicit permissions are handled separately by this script.
        if ($name -ieq 'Custom' -or $name -ieq 'None') { continue }

        if (-not (@($groups) -contains $name)) {
            [void]$groups.Add($name)
        }
    }

    # PermissionGroups uses None when no well-known permission group remains.
    if ($groups.Count -eq 0) {
        [void]$groups.Add('None')
    }

    return ,([string[]]@($groups))
}

function ConvertTo-DisplayValue {
    param($Value)

    if ($null -eq $Value) { return '<null>' }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @(Get-SafeArray -Value $Value | ForEach-Object { [string]$_ })
        if ($items.Count -eq 0) { return '<empty>' }
        return ($items -join ', ')
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return '<empty>' }
    return $text
}

function Test-EquivalentValue {
    param($Left, $Right)

    if ($null -eq $Left -and $null -eq $Right) { return $true }
    if ($null -eq $Left -or $null -eq $Right) { return $false }

    $leftIsCollection = $Left -is [System.Collections.IEnumerable] -and -not ($Left -is [string])
    $rightIsCollection = $Right -is [System.Collections.IEnumerable] -and -not ($Right -is [string])

    if ($leftIsCollection -or $rightIsCollection) {
        $leftItems = @(Get-SafeArray -Value $Left | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } | Sort-Object)
        $rightItems = @(Get-SafeArray -Value $Right | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } | Sort-Object)
        if ($leftItems.Count -ne $rightItems.Count) { return $false }
        for ($i = 0; $i -lt $leftItems.Count; $i++) {
            if ($leftItems[$i] -ne $rightItems[$i]) { return $false }
        }
        return $true
    }

    if ($Left -is [bool] -or $Right -is [bool]) {
        try {
            return ((ConvertTo-StrictBoolean -Value $Left) -eq (ConvertTo-StrictBoolean -Value $Right))
        }
        catch {
            return $false
        }
    }

    return ([string]$Left).Trim().Equals(([string]$Right).Trim(), [System.StringComparison]::OrdinalIgnoreCase)
}

function Resolve-TextOutputPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = $Path.Trim()
    if ([string]::IsNullOrWhiteSpace($resolved)) { throw 'OutputFile cannot be empty.' }

    $extension = [System.IO.Path]::GetExtension($resolved)
    if ([string]::IsNullOrWhiteSpace($extension)) {
        $resolved = "$resolved.txt"
    }
    elseif ($extension -ne '.txt') {
        throw 'OutputFile must use the .txt extension.'
    }

    if (-not [System.IO.Path]::IsPathRooted($resolved)) {
        $resolved = Join-Path -Path (Get-Location).Path -ChildPath $resolved
    }

    $parent = Split-Path -Parent $resolved
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -Path $parent -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    return [System.IO.Path]::GetFullPath($resolved)
}

# ---------------------------------------------------------------------------
# Backup import and selection
# ---------------------------------------------------------------------------
function Import-ReceiveConnectorBackup {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = $Path
    if (-not [System.IO.Path]::IsPathRooted($resolved)) {
        $resolved = Join-Path -Path (Get-Location).Path -ChildPath $resolved
    }
    $resolved = [System.IO.Path]::GetFullPath($resolved)

    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Backup file was not found: $resolved"
    }
    if ([System.IO.Path]::GetExtension($resolved) -ne '.json') {
        throw 'RestoreFile must be a JSON backup created by ExchangeReceiveConnectorManager.ps1.'
    }

    try {
        $payload = Get-Content -LiteralPath $resolved -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Unable to read the JSON backup: $($_.Exception.Message)"
    }

    $schema = Get-ObjectPropertyValue -Object $payload -Name 'BackupSchema'
    $schemaVersion = Get-ObjectPropertyValue -Object $payload -Name 'SchemaVersion'
    $tool = Get-ObjectPropertyValue -Object $payload -Name 'Tool'
    $servers = @(Get-SafeArray -Value (Get-ObjectPropertyValue -Object $payload -Name 'Servers'))

    if ($schema) {
        if ([string]$schema -ne 'ExchangeReceiveConnectorBackup') {
            throw "Unsupported backup schema '$schema'."
        }
        if ($null -ne $schemaVersion -and [int]$schemaVersion -gt 1) {
            throw "Backup schema version '$schemaVersion' is newer than this restore tool supports."
        }
    }
    elseif ([string]$tool -ne 'ExchangeReceiveConnectorManager') {
        throw 'The JSON file does not appear to be an ExchangeReceiveConnectorManager backup.'
    }

    if ($servers.Count -eq 0) {
        throw 'The JSON backup does not contain any server entries.'
    }

    return [PSCustomObject]@{
        Path          = $resolved
        Payload       = $payload
        LegacySchema  = (-not $schema)
        SchemaVersion = $(if ($schemaVersion) { [int]$schemaVersion } else { 0 })
        Servers       = $servers
    }
}

function Select-SourceBackupServer {
    param(
        [Parameter(Mandatory = $true)]$Backup,
        [string]$Identity
    )

    $servers = @($Backup.Servers)
    if (-not [string]::IsNullOrWhiteSpace($Identity)) {
        $matches = @($servers | Where-Object { ([string]$_.Server) -ieq $Identity.Trim() })
        if ($matches.Count -ne 1) {
            $available = @($servers | ForEach-Object { [string]$_.Server }) -join ', '
            throw "SourceServer '$Identity' was not found in the backup. Available entries: $available"
        }
        return $matches[0]
    }

    if ($servers.Count -eq 1) { return $servers[0] }

    $available = @($servers | ForEach-Object { [string]$_.Server }) -join ', '
    throw "The backup contains more than one server. Specify -SourceServer. Available entries: $available"
}

# ---------------------------------------------------------------------------
# Exchange target inventory
# ---------------------------------------------------------------------------
function Resolve-MailboxExchangeServer {
    param([Parameter(Mandatory = $true)][string]$Identity)

    $serverObject = Get-ExchangeServer -Identity $Identity -ErrorAction Stop
    $serverName = [string]$serverObject.Name
    $isMailbox = $false

    $isMailboxProperty = $serverObject.PSObject.Properties['IsMailboxServer']
    if ($null -ne $isMailboxProperty) {
        try { $isMailbox = [bool]$isMailboxProperty.Value } catch { $isMailbox = $false }
    }

    if (-not $isMailbox) {
        $serverRoleProperty = $serverObject.PSObject.Properties['ServerRole']
        if ($null -ne $serverRoleProperty -and ([string]$serverRoleProperty.Value) -match '(?i)Mailbox') {
            $isMailbox = $true
        }
    }

    if (-not $isMailbox) {
        throw "Exchange server '$serverName' is not a Mailbox server."
    }

    return $serverObject
}

function Get-ConnectorDescriptor {
    param(
        [Parameter(Mandatory = $true)]$Connector,
        [Parameter(Mandatory = $true)][string]$Server
    )

    $name = [string]$Connector.Name
    foreach ($family in $script:BuiltInConnectorFamilies) {
        $expectedName = "$family $Server"
        if ($name.Equals($expectedName, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [PSCustomObject]@{ Type = 'BuiltIn'; BuiltInFamily = $family }
        }
    }

    return [PSCustomObject]@{ Type = 'Custom'; BuiltInFamily = $null }
}

function Get-ConnectorPermissionSnapshot {
    param([Parameter(Mandatory = $true)]$Connector)

    $distinguishedName = [string](Get-ObjectPropertyValue -Object $Connector -Name 'DistinguishedName')
    if ([string]::IsNullOrWhiteSpace($distinguishedName)) {
        return [PSCustomObject]@{
            QueryStatus           = 'Unknown'
            ExplicitPermissions   = @()
            AnonymousRelayEnabled = $null
            Error                 = 'Receive Connector DistinguishedName is unavailable. AD permissions cannot be queried safely.'
        }
    }

    try {
        $permissions = @(Get-ADPermission -Identity $distinguishedName -ErrorAction Stop | Where-Object { $_.IsInherited -eq $false })
        $entries = New-Object System.Collections.ArrayList

        foreach ($permission in $permissions) {
            $rights = @($permission.ExtendedRights | ForEach-Object { [string]$_ } | Where-Object { $_ })
            [void]$entries.Add([PSCustomObject]@{
                User           = [string]$permission.User
                Deny           = [bool]$permission.Deny
                ExtendedRights = @($rights)
            })
        }

        $anonymousEntry = @($entries | Where-Object {
            $_.User -ieq $script:AnonymousLogonPrincipal -and
            $_.Deny -eq $false -and
            @($_.ExtendedRights | Where-Object { $_ -ieq $script:AnonymousRelayRight }).Count -gt 0
        })

        return [PSCustomObject]@{
            QueryStatus           = 'Available'
            ExplicitPermissions   = @($entries)
            AnonymousRelayEnabled = ($anonymousEntry.Count -gt 0)
            Error                 = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            QueryStatus           = 'Unknown'
            ExplicitPermissions   = @()
            AnonymousRelayEnabled = $null
            Error                 = $_.Exception.Message
        }
    }
}

function Get-TargetConnectorSnapshot {
    param([Parameter(Mandatory = $true)]$ServerObject)

    $serverName = [string]$ServerObject.Name
    $serverFqdn = [string]$ServerObject.Fqdn
    $serverVersion = [string]$ServerObject.AdminDisplayVersion
    $serverRole = [string]$ServerObject.ServerRole
    $items = New-Object System.Collections.ArrayList

    foreach ($connector in @(Get-ReceiveConnector -Server $serverName -ErrorAction Stop)) {
        $descriptor = Get-ConnectorDescriptor -Connector $connector -Server $serverName
        $permissionSnapshot = Get-ConnectorPermissionSnapshot -Connector $connector
        $values = [ordered]@{}

        foreach ($propertyName in $script:ConnectorPropertyNames) {
            $propertyInfo = $connector.PSObject.Properties[$propertyName]
            if ($null -eq $propertyInfo) {
                $values[$propertyName] = '<not returned>'
            }
            else {
                $values[$propertyName] = Normalize-ConnectorPropertyValue -PropertyName $propertyName -Value $propertyInfo.Value
            }
        }

        [void]$items.Add([PSCustomObject]@{
            Server             = $serverName
            Name               = [string]$connector.Name
            Identity           = [string]$connector.Identity
            ConnectorType      = $descriptor.Type
            BuiltInFamily      = $descriptor.BuiltInFamily
            Values             = $values
            PermissionSnapshot = $permissionSnapshot
        })
    }

    return [PSCustomObject]@{
        Server              = $serverName
        ServerFqdn          = $serverFqdn
        AdminDisplayVersion = $serverVersion
        ServerRole          = $serverRole
        Items               = @($items)
    }
}

# ---------------------------------------------------------------------------
# Safety checks and mapping
# ---------------------------------------------------------------------------
function Get-TargetConnectorName {
    param(
        [Parameter(Mandatory = $true)]$SourceConnector,
        [Parameter(Mandatory = $true)][string]$TargetServerName
    )

    if ([string]$SourceConnector.ConnectorType -ieq 'BuiltIn') {
        $family = [string]$SourceConnector.BuiltInFamily
        if ([string]::IsNullOrWhiteSpace($family)) {
            throw "Built-in connector '$($SourceConnector.Name)' does not contain BuiltInFamily metadata."
        }
        return "$family $TargetServerName"
    }

    return [string]$SourceConnector.Name
}

function Get-TargetConnector {
    param(
        [Parameter(Mandatory = $true)]$TargetSnapshot,
        [Parameter(Mandatory = $true)]$SourceConnector
    )

    $targetName = Get-TargetConnectorName -SourceConnector $SourceConnector -TargetServerName $TargetSnapshot.Server
    $matches = @($TargetSnapshot.Items | Where-Object { ([string]$_.Name) -ieq $targetName })
    if ($matches.Count -eq 0) { return $null }
    return $matches[0]
}

function Get-BindingAddress {
    param([Parameter(Mandatory = $true)][string]$Binding)

    $text = $Binding.Trim()
    if ($text -match '^\[(?<ip>.+)\]:(?<port>\d+)$') {
        return $Matches['ip']
    }
    if ($text -match '^(?<ip>[^:]+):(?<port>\d+)$') {
        return $Matches['ip']
    }
    return $null
}

function Test-TargetBindingAvailability {
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        $Bindings
    )

    $bindingItems = @(Get-SafeArray -Value $Bindings | ForEach-Object { [string]$_ } | Where-Object { $_ })
    if ($bindingItems.Count -eq 0) { return 'Missing' }

    $specificAddresses = New-Object System.Collections.ArrayList
    foreach ($binding in $bindingItems) {
        $address = Get-BindingAddress -Binding $binding
        if ([string]::IsNullOrWhiteSpace($address)) { return 'Unknown' }
        if ($address -in @('0.0.0.0','::','[::]')) { continue }
        [void]$specificAddresses.Add($address)
    }

    if ($specificAddresses.Count -eq 0) { return 'Available' }

    try {
        $localAliases = @($env:COMPUTERNAME, 'localhost', '.', '127.0.0.1', '::1')
        if ($localAliases -contains $Server) {
            $targetAddresses = @(Get-NetIPAddress -ErrorAction Stop | ForEach-Object { [string]$_.IPAddress })
        }
        else {
            $targetAddresses = @(Invoke-Command -ComputerName $Server -ScriptBlock {
                Get-NetIPAddress -ErrorAction Stop | ForEach-Object { [string]$_.IPAddress }
            } -ErrorAction Stop)
        }

        foreach ($address in $specificAddresses) {
            if (@($targetAddresses | Where-Object { $_ -ieq $address }).Count -eq 0) {
                return 'Missing'
            }
        }
        return 'Available'
    }
    catch {
        return 'Unknown'
    }
}

function Test-TargetTlsCertificateAvailability {
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [AllowNull()][string]$TlsCertificateName
    )

    if ([string]::IsNullOrWhiteSpace($TlsCertificateName)) { return 'NotApplicable' }

    try {
        $certificates = @(Get-ExchangeCertificate -Server $Server -ErrorAction Stop)
        $incompleteMatch = $false
        foreach ($certificate in $certificates) {
            $identifier = "<I>$($certificate.Issuer)<S>$($certificate.Subject)"
            if (-not $identifier.Equals($TlsCertificateName, [System.StringComparison]::OrdinalIgnoreCase)) { continue }

            $status = Get-ObjectPropertyValue -Object $certificate -Name 'Status'
            $services = Get-ObjectPropertyValue -Object $certificate -Name 'Services'
            if ([string]::IsNullOrWhiteSpace([string]$status) -or [string]::IsNullOrWhiteSpace([string]$services)) {
                $incompleteMatch = $true
                continue
            }
            $statusOK = ([string]$status) -ieq 'Valid'
            $smtpOK = ([string]$services) -match '(?i)\bSMTP\b'
            if ($statusOK -and $smtpOK) { return 'Available' }
        }
        if ($incompleteMatch) { return 'Unknown' }
        return 'Missing'
    }
    catch {
        return 'Unknown'
    }
}

function Get-DesiredConnectorPropertyValue {
    param(
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)]$SourceConnector,
        [Parameter(Mandatory = $true)]$SourceSnapshot,
        [Parameter(Mandatory = $true)]$TargetSnapshot
    )

    $sourceValue = Normalize-ConnectorPropertyValue -PropertyName $PropertyName -Value (Get-SourceConnectorValue -Connector $SourceConnector -PropertyName $PropertyName)
    $desiredValue = $sourceValue
    $mapping = $null

    if ($PropertyName -eq 'PermissionGroups' -and -not (Test-IsUnavailableValue -Value $sourceValue)) {
        $desiredValue = Get-SettablePermissionGroups -Value $sourceValue

        if (@(Get-SafeArray -Value $sourceValue | Where-Object { [string]$_ -ieq 'Custom' }).Count -gt 0) {
            $mapping = 'Custom is derived from explicit AD permissions and is not passed to Set-ReceiveConnector. Settable permission groups are aligned separately from explicit permissions.'
        }
    }

    if ($PropertyName -eq 'Fqdn' -and $null -ne $sourceValue) {
        $sourceFqdn = [string]$SourceSnapshot.ServerFqdn
        $sourceServerName = [string]$SourceSnapshot.Server
        $sourceText = [string]$sourceValue

        # A connector FQDN that is simply the source server's own name is
        # server-specific and should follow the target server during Clone or
        # Restore. Custom SMTP namespaces are preserved unchanged.
        if ((-not [string]::IsNullOrWhiteSpace($sourceFqdn) -and $sourceText -ieq $sourceFqdn) -or $sourceText -ieq $sourceServerName) {
            $desiredValue = [string]$TargetSnapshot.ServerFqdn
            $mapping = "Translated source server FQDN '$sourceText' to target server FQDN '$desiredValue'."
        }
    }

    return [PSCustomObject]@{
        SourceValue  = $sourceValue
        DesiredValue = $desiredValue
        Mapping      = $mapping
    }
}

function Get-SourceAnonymousRelayState {
    param([Parameter(Mandatory = $true)]$SourceConnector)

    $permissionSnapshot = Get-ObjectPropertyValue -Object $SourceConnector -Name 'PermissionSnapshot'
    if ($null -eq $permissionSnapshot) {
        return [PSCustomObject]@{ QueryStatus = 'Unknown'; Enabled = $null; ExplicitPermissionCount = 0 }
    }

    $queryStatus = Get-ObjectPropertyValue -Object $permissionSnapshot -Name 'QueryStatus'
    $enabled = Get-ObjectPropertyValue -Object $permissionSnapshot -Name 'AnonymousRelayEnabled'
    $permissions = @(Get-SafeArray -Value (Get-ObjectPropertyValue -Object $permissionSnapshot -Name 'ExplicitPermissions'))

    return [PSCustomObject]@{
        QueryStatus            = $(if ($queryStatus) { [string]$queryStatus } else { 'Unknown' })
        Enabled                = $enabled
        ExplicitPermissionCount = $permissions.Count
    }
}

# ---------------------------------------------------------------------------
# Plan construction
# ---------------------------------------------------------------------------
function New-ConnectorPlan {
    param(
        [Parameter(Mandatory = $true)]$SourceConnector,
        [Parameter(Mandatory = $true)]$SourceSnapshot,
        [Parameter(Mandatory = $true)]$TargetSnapshot
    )

    $connectorType = [string]$SourceConnector.ConnectorType
    $targetName = Get-TargetConnectorName -SourceConnector $SourceConnector -TargetServerName $TargetSnapshot.Server
    $targetConnector = Get-TargetConnector -TargetSnapshot $TargetSnapshot -SourceConnector $SourceConnector
    $targetExists = $null -ne $targetConnector
    $scopeSkipped = ($connectorType -ieq 'BuiltIn' -and -not $IncludeBuiltIn)
    $canCreate = (-not $targetExists) -and ($connectorType -ieq 'Custom') -and (-not $scopeSkipped)

    $bindings = Normalize-ConnectorPropertyValue -PropertyName 'Bindings' -Value (Get-SourceConnectorValue -Connector $SourceConnector -PropertyName 'Bindings')
    $remoteRanges = Normalize-ConnectorPropertyValue -PropertyName 'RemoteIPRanges' -Value (Get-SourceConnectorValue -Connector $SourceConnector -PropertyName 'RemoteIPRanges')
    $transportRole = Normalize-ConnectorPropertyValue -PropertyName 'TransportRole' -Value (Get-SourceConnectorValue -Connector $SourceConnector -PropertyName 'TransportRole')
    $enabledValue = Normalize-ConnectorPropertyValue -PropertyName 'Enabled' -Value (Get-SourceConnectorValue -Connector $SourceConnector -PropertyName 'Enabled')
    $bindingStatus = if ($scopeSkipped) { 'NotChecked' } else { Test-TargetBindingAvailability -Server $TargetSnapshot.Server -Bindings $bindings }

    $reviewNotes = New-Object System.Collections.ArrayList
    $blocked = $false

    if (-not $scopeSkipped -and $targetExists -and $connectorType -ine [string]$targetConnector.ConnectorType) {
        $blocked = $true
        $canCreate = $false
        [void]$reviewNotes.Add("Connector name collision: source type '$connectorType' does not match target type '$($targetConnector.ConnectorType)'. No settings or permissions will be changed.")
    }

    if ($scopeSkipped) {
        [void]$reviewNotes.Add('Built-in connector is outside the default operation scope. Use -IncludeBuiltIn to include it.')
    }
    elseif (-not $targetExists -and $connectorType -ieq 'BuiltIn') {
        [void]$reviewNotes.Add('Built-in connector is missing on the target. Built-in connectors are never created by this script.')
    }

    if ($canCreate) {
        if ($null -eq $transportRole -or (Test-IsUnavailableValue -Value $transportRole) -or [string]::IsNullOrWhiteSpace([string]$transportRole)) {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Missing custom connector cannot be created because TransportRole is not available in the backup.')
        }
        if (@(Get-SafeArray -Value $bindings).Count -eq 0 -or (Test-IsUnavailableValue -Value $bindings)) {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Missing custom connector cannot be created because Bindings are not available in the backup.')
        }
        if (@(Get-SafeArray -Value $remoteRanges).Count -eq 0 -or (Test-IsUnavailableValue -Value $remoteRanges)) {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Missing custom connector cannot be created because RemoteIPRanges are not available in the backup.')
        }
        if ($null -eq $enabledValue -or (Test-IsUnavailableValue -Value $enabledValue)) {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Missing custom connector cannot be created because Enabled state is not available in the source configuration.')
        }
    }

    # Binding safety is a prerequisite for the whole connector operation, not only
    # for a Bindings property change. A target can still contain a stale connector
    # binding that references an IP address no longer present on the server. In that
    # case applying other settings or relay permissions could expose a wildcard or
    # otherwise unintended listener state, so block the complete connector plan.
    if (-not $scopeSkipped -and $bindingStatus -in @('Missing','Unknown')) {
        $blocked = $true
        $canCreate = $false
        [void]$reviewNotes.Add("Required binding check: $bindingStatus. One or more source-specific binding IP addresses cannot be verified on the target. The entire connector is blocked; settings, permissions, and activation will not be changed.")
    }

    $enablingExisting = $targetExists -and ($enabledValue -is [bool]) -and $enabledValue -and
        (-not (Test-EquivalentValue -Left $enabledValue -Right $targetConnector.Values['Enabled']))

    # Validate the effective certificate independently of property management.
    # An omitted source field preserves the target value, but cannot bypass the
    # certificate prerequisite when that target connector is being activated.
    $sourceTlsName = Normalize-ConnectorPropertyValue -PropertyName 'TlsCertificateName' -Value (Get-SourceConnectorValue -Connector $SourceConnector -PropertyName 'TlsCertificateName')
    $targetTlsName = if ($targetExists) { Get-SourceConnectorValue -Connector $targetConnector -PropertyName 'TlsCertificateName' } else { $null }
    $sourceTlsUnavailable = Test-IsUnavailableValue -Value $sourceTlsName
    $effectiveTlsName = if ($sourceTlsUnavailable -and $targetExists) { $targetTlsName } else { $sourceTlsName }
    $tlsChangeRequired = (-not $sourceTlsUnavailable) -and ((-not $targetExists) -or (-not (Test-EquivalentValue -Left $sourceTlsName -Right $targetTlsName)))
    if (-not $scopeSkipped -and ($targetExists -or $connectorType -ieq 'Custom') -and ($tlsChangeRequired -or $enablingExisting)) {
        $certificateStatus = if (Test-IsUnavailableValue -Value $effectiveTlsName) { 'Unknown' }
            else { Test-TargetTlsCertificateAvailability -Server $TargetSnapshot.Server -TlsCertificateName ([string]$effectiveTlsName) }
        if ($certificateStatus -in @('Missing','Unknown')) {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add("Target TLS certificate check: $certificateStatus. The entire connector is blocked, including activation.")
        }
    }

    $comparisons = New-Object System.Collections.ArrayList
    foreach ($propertyName in $script:ManagedProperties) {
        $desired = Get-DesiredConnectorPropertyValue -PropertyName $propertyName -SourceConnector $SourceConnector -SourceSnapshot $SourceSnapshot -TargetSnapshot $TargetSnapshot
        $sourceValue = $desired.SourceValue
        $desiredValue = $desired.DesiredValue
        $targetValue = if ($targetExists) {
            Get-SourceConnectorValue -Connector $targetConnector -PropertyName $propertyName
        }
        else {
            $null
        }
        $targetComparisonValue = $targetValue
        if ($targetExists -and $propertyName -eq 'PermissionGroups') {
            $targetComparisonValue = Get-SettablePermissionGroups -Value $targetValue
        }

        $status = if (Test-IsUnavailableValue -Value $sourceValue) {
            'Unavailable'
        }
        elseif (-not $targetExists) {
            'Missing'
        }
        elseif (Test-EquivalentValue -Left $desiredValue -Right $targetComparisonValue) {
            'Same'
        }
        else {
            'Different'
        }

        $manage = $false
        $note = $desired.Mapping

        if ($scopeSkipped) {
            $note = 'Outside operation scope unless -IncludeBuiltIn is specified.'
        }
        elseif ($status -eq 'Unavailable') {
            $note = 'The property was not returned in the source backup and will not be applied.'
            if (-not $targetExists -and $connectorType -ieq 'Custom') {
                $blocked = $true
                $canCreate = $false
                [void]$reviewNotes.Add("Missing custom connector cannot be created because $propertyName is unavailable in the source configuration.")
            }
        }
        elseif (-not $targetExists -and $connectorType -ieq 'BuiltIn') {
            $note = 'Built-in connector will not be created.'
        }
        elseif ($propertyName -eq 'Bindings' -and $status -ne 'Same' -and $bindingStatus -in @('Missing','Unknown')) {
            $note = "Binding safety check: $bindingStatus. Bindings will not be changed automatically."
        }
        elseif ($status -eq 'Different') {
            $manage = $true
        }
        elseif ($status -eq 'Missing' -and $canCreate) {
            $manage = $true
        }

        if (-not $targetExists -and $canCreate -and $propertyName -in @('Bindings','RemoteIPRanges')) {
            $manage = $true
            $note = 'Used when the missing custom connector is created.'
        }

        [void]$comparisons.Add([PSCustomObject]@{
            Property     = $propertyName
            SourceValue  = $sourceValue
            DesiredValue = $desiredValue
            TargetValue  = $targetValue
            Status       = $status
            Manage       = $manage
            ReviewNote   = $note
        })
    }

    $sourceRelay = Get-SourceAnonymousRelayState -SourceConnector $SourceConnector
    $targetRelay = if ($targetExists) {
        [PSCustomObject]@{
            QueryStatus = [string]$targetConnector.PermissionSnapshot.QueryStatus
            Enabled     = $targetConnector.PermissionSnapshot.AnonymousRelayEnabled
        }
    }
    else {
        [PSCustomObject]@{ QueryStatus = 'Missing'; Enabled = $false }
    }

    $relayStatus = if ($sourceRelay.QueryStatus -ne 'Available') {
        'Unknown'
    }
    elseif ($targetExists -and $targetRelay.QueryStatus -ne 'Available') {
        'Unknown'
    }
    elseif ((ConvertTo-StrictBoolean -Value $sourceRelay.Enabled) -eq (ConvertTo-StrictBoolean -Value $targetRelay.Enabled)) {
        'Same'
    }
    else {
        'Different'
    }

    if (-not $scopeSkipped -and $IncludeAnonymousRelayPermissions) {
        if ($sourceRelay.QueryStatus -ne 'Available') {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Source anonymous relay permission state is unavailable. The connector plan is blocked because anonymous relay permission management was requested.')
        }
        elseif ($targetExists -and $targetRelay.QueryStatus -ne 'Available') {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Target anonymous relay permission state is unavailable. The connector plan is blocked because anonymous relay permission management was requested.')
        }
    }

    # Keep the displayed plan consistent with the execution gate.
    if ($blocked) {
        $canCreate = $false
        foreach ($comparison in $comparisons) { $comparison.Manage = $false }
    }
    $relayManage = (-not $blocked) -and (-not $scopeSkipped) -and $IncludeAnonymousRelayPermissions -and ($relayStatus -eq 'Different') -and ($targetExists -or $canCreate)
    $relayNote = if (-not $IncludeAnonymousRelayPermissions) {
        'Review only. Use -IncludeAnonymousRelayPermissions to include this explicit extended right in the change plan.'
    }
    elseif ($sourceRelay.QueryStatus -ne 'Available') {
        'Source anonymous relay state is unknown and will not be changed.'
    }
    elseif ($targetExists -and $targetRelay.QueryStatus -ne 'Available') {
        'Target anonymous relay state is unknown and will not be changed.'
    }
    else { $null }

    if ($sourceRelay.ExplicitPermissionCount -gt 0) {
        [void]$reviewNotes.Add("Source contains $($sourceRelay.ExplicitPermissionCount) explicit AD permission entr$(if ($sourceRelay.ExplicitPermissionCount -eq 1) { 'y' } else { 'ies' }). Only the anonymous relay right can be aligned automatically.")
    }

    return [PSCustomObject]@{
        SourceServer    = [string]$SourceSnapshot.Server
        SourceConnector = $SourceConnector
        TargetServer    = [string]$TargetSnapshot.Server
        TargetName      = $targetName
        TargetConnector = $targetConnector
        ConnectorType   = $connectorType
        ScopeSkipped    = $scopeSkipped
        TargetExists    = $targetExists
        CanCreate       = $canCreate
        Blocked         = $blocked
        BindingStatus   = $bindingStatus
        Comparisons     = @($comparisons)
        AnonymousRelay  = [PSCustomObject]@{
            SourceEnabled = $sourceRelay.Enabled
            TargetEnabled = $targetRelay.Enabled
            Status        = $relayStatus
            Manage        = $relayManage
            ReviewNote    = $relayNote
        }
        ReviewNotes     = @($reviewNotes)
    }
}

function Test-PlanHasManagedChanges {
    param([Parameter(Mandatory = $true)]$Plan)

    if ($Plan.ScopeSkipped -or $Plan.Blocked) { return $false }
    if ($Plan.CanCreate) { return $true }
    if (@($Plan.Comparisons | Where-Object { $_.Manage -and $_.Status -ne 'Same' }).Count -gt 0) { return $true }
    if ($Plan.AnonymousRelay.Manage) { return $true }
    return $false
}

# ---------------------------------------------------------------------------
# Plan display and export
# ---------------------------------------------------------------------------
function Get-PlanStatus {
    param([Parameter(Mandatory = $true)]$Plan)

    if ($Plan.ScopeSkipped) { return 'SKIP' }
    if ($Plan.Blocked) { return 'BLOCKER' }
    if ($Plan.CanCreate) { return 'CREATE' }
    if (-not $Plan.TargetExists) { return 'REVIEW' }
    if (Test-PlanHasManagedChanges -Plan $Plan) { return 'UPDATE' }
    if (@($Plan.Comparisons | Where-Object { $_.Status -notin @('Same') }).Count -gt 0 -or $Plan.AnonymousRelay.Status -notin @('Same')) { return 'REVIEW' }
    return 'SAME'
}

function Get-ConnectorPlanLines {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans)

    $operation = if ($script:PlanOperation) { [string]$script:PlanOperation } else { 'Restore' }
    $sourceValueLabel = if ($operation -eq 'Clone') { 'Source' } else { 'Backup' }
    $sourceServers = @($Plans | ForEach-Object { [string]$_.SourceServer } | Where-Object { $_ } | Select-Object -Unique)
    $targetServers = @($Plans | ForEach-Object { [string]$_.TargetServer } | Where-Object { $_ } | Select-Object -Unique)

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add(("{0}.ps1 v{1} - Receive Connector {2} plan" -f $script:ToolName,$script:ScriptVersion,$operation.ToLowerInvariant()))
    [void]$lines.Add(("Generated : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    if ($operation -eq 'Restore') {
        [void]$lines.Add(("JSON backup: {0}" -f $script:BackupPath))
    }
    else {
        [void]$lines.Add('Source type: Live Exchange server')
    }
    [void]$lines.Add(("Source    : {0}" -f ($sourceServers -join ', ')))
    [void]$lines.Add(("Target(s) : {0}" -f ($targetServers -join ', ')))
    [void]$lines.Add(("Built-in  : {0}" -f $(if ($IncludeBuiltIn) { 'Included (existing only)' } else { 'Excluded' })))
    [void]$lines.Add(("Anon relay: {0}" -f $(if ($IncludeAnonymousRelayPermissions) { 'Managed' } else { 'Review only' })))
    [void]$lines.Add(("Mode      : {0} {1}" -f $operation,$(if ($ApplyChanges) { 'Apply requested' } else { 'Preview only' })))
    [void]$lines.Add('')

    foreach ($plan in @($Plans | Sort-Object TargetServer,TargetName)) {
        $planStatus = Get-PlanStatus -Plan $plan
        [void]$lines.Add(('=' * 80))
        [void]$lines.Add(("[{0}] [{1}] {2} -> {3}" -f $planStatus,$plan.TargetServer,$plan.SourceConnector.Name,$plan.TargetName))
        [void]$lines.Add(("Type          : {0}" -f $plan.ConnectorType))
        [void]$lines.Add(("Target exists : {0}" -f $plan.TargetExists))
        [void]$lines.Add(("Binding check : {0}" -f $plan.BindingStatus))

        foreach ($item in $plan.Comparisons) {
            if ($item.Status -eq 'Same') { continue }
            $action = if ($item.Manage) { 'CHANGE' } else { 'REVIEW' }
            [void]$lines.Add(("{0,-8} {1}" -f $action,$item.Property))
            [void]$lines.Add(("  {0,-7}: {1}" -f $sourceValueLabel,(ConvertTo-DisplayValue -Value $item.SourceValue)))
            if (-not (Test-EquivalentValue -Left $item.DesiredValue -Right $item.SourceValue) -or $item.ReviewNote) {
                [void]$lines.Add(("  Desired: {0}" -f (ConvertTo-DisplayValue -Value $item.DesiredValue)))
            }
            [void]$lines.Add(("  Target : {0}" -f (ConvertTo-DisplayValue -Value $item.TargetValue)))
            if ($item.ReviewNote) { [void]$lines.Add(("  Note   : {0}" -f $item.ReviewNote)) }
        }

        if ($plan.AnonymousRelay.Status -ne 'Same' -or $IncludeAnonymousRelayPermissions) {
            [void]$lines.Add(("{0,-8} Anonymous Relay" -f $(if ($plan.AnonymousRelay.Manage) { 'CHANGE' } else { 'REVIEW' })))
            [void]$lines.Add(("  {0,-7}: {1}" -f $sourceValueLabel,(ConvertTo-DisplayValue -Value $plan.AnonymousRelay.SourceEnabled)))
            [void]$lines.Add(("  Target : {0}" -f (ConvertTo-DisplayValue -Value $plan.AnonymousRelay.TargetEnabled)))
            if ($plan.AnonymousRelay.ReviewNote) { [void]$lines.Add(("  Note   : {0}" -f $plan.AnonymousRelay.ReviewNote)) }
        }

        foreach ($note in $plan.ReviewNotes) { [void]$lines.Add(("REVIEW   {0}" -f $note)) }
        [void]$lines.Add('')
    }

    $statusGroups = @($Plans | Group-Object { Get-PlanStatus -Plan $_ })
    [void]$lines.Add('Summary')
    foreach ($status in @('CREATE','UPDATE','SAME','REVIEW','SKIP','BLOCKER')) {
        $group = @($statusGroups | Where-Object { $_.Name -eq $status })
        $count = if ($group.Count -gt 0) { $group[0].Count } else { 0 }
        [void]$lines.Add(("  {0,-7}: {1}" -f $status,$count))
    }

    return @($lines)
}

function Show-ConnectorPlan {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans)

    foreach ($line in @(Get-ConnectorPlanLines -Plans $Plans)) {
        $color = if ($line -match '^\[BLOCKER\]|^BLOCKER') { 'Red' }
        elseif ($line -match '^\[(CREATE|UPDATE)\]|^CHANGE') { 'Yellow' }
        elseif ($line -match '^\[SAME\]') { 'Green' }
        elseif ($line -match '^\[(REVIEW|SKIP)\]|^REVIEW') { 'DarkYellow' }
        else { $null }

        if ($color) { Write-ResultHost $line -ForegroundColor $color } else { Write-ResultHost $line }
    }
}

function Export-ConnectorPlan {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans
    )

    $resolved = Resolve-TextOutputPath -Path $Path
    Set-Content -LiteralPath $resolved -Value @(Get-ConnectorPlanLines -Plans $Plans) -Encoding UTF8 -ErrorAction Stop
    return $resolved
}

# ---------------------------------------------------------------------------
# Pre-change backup
# ---------------------------------------------------------------------------
function Export-PreChangeSnapshot {
    param([Parameter(Mandatory = $true)]$TargetSnapshot)

    $snapshotFolder = Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath 'ConfigSnapshots'
    if (-not (Test-Path -LiteralPath $snapshotFolder -PathType Container)) {
        New-Item -Path $snapshotFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path -Path $snapshotFolder -ChildPath ("ReceiveConnectors-PreChange-{0}-{1}.json" -f $TargetSnapshot.Server,$timestamp)
    $counter = 2
    while (Test-Path -LiteralPath $path) {
        $path = Join-Path -Path $snapshotFolder -ChildPath ("ReceiveConnectors-PreChange-{0}-{1}-{2}.json" -f $TargetSnapshot.Server,$timestamp,$counter)
        $counter++
    }

    $payload = [PSCustomObject]@{
        BackupSchema  = 'ExchangeReceiveConnectorBackup'
        SchemaVersion = 1
        Tool           = $script:ToolName
        ToolVersion    = $script:ScriptVersion
        Generated      = (Get-Date).ToString('o')
        GeneratedUtc   = (Get-Date).ToUniversalTime().ToString('o')
        Operator       = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Mode           = 'Automatic pre-change target snapshot'
        Changes        = 'NONE'
        Servers        = @($TargetSnapshot)
    }

    $payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8 -ErrorAction Stop
    return $path
}

function Get-ConnectorSnapshotStateText {
    param([Parameter(Mandatory = $true)]$Snapshot)

    $canonicalItems = New-Object System.Collections.ArrayList
    foreach ($connector in @($Snapshot.Items | Sort-Object Name)) {
        $values = [ordered]@{}
        foreach ($propertyName in $script:ConnectorPropertyNames) {
            $values[$propertyName] = Get-ObjectPropertyValue -Object $connector.Values -Name $propertyName
        }

        $permissions = New-Object System.Collections.ArrayList
        foreach ($permission in @($connector.PermissionSnapshot.ExplicitPermissions | Sort-Object User,Deny)) {
            [void]$permissions.Add([ordered]@{
                User           = [string]$permission.User
                Deny           = [bool]$permission.Deny
                ExtendedRights = @($permission.ExtendedRights | ForEach-Object { [string]$_ } | Sort-Object)
            })
        }

        [void]$canonicalItems.Add([ordered]@{
            Name          = [string]$connector.Name
            ConnectorType = [string]$connector.ConnectorType
            BuiltInFamily = [string]$connector.BuiltInFamily
            Values        = $values
            Permission    = [ordered]@{
                QueryStatus           = [string]$connector.PermissionSnapshot.QueryStatus
                AnonymousRelayEnabled = $connector.PermissionSnapshot.AnonymousRelayEnabled
                ExplicitPermissions   = @($permissions)
            }
        })
    }

    $canonical = [ordered]@{
        Server     = [string]$Snapshot.Server
        ServerFqdn = [string]$Snapshot.ServerFqdn
        Items      = @($canonicalItems)
    }

    return ($canonical | ConvertTo-Json -Depth 12 -Compress)
}

function Test-ConnectorSnapshotUnchanged {
    param(
        [Parameter(Mandatory = $true)]$Before,
        [Parameter(Mandatory = $true)]$After
    )

    return ((Get-ConnectorSnapshotStateText -Snapshot $Before) -ceq (Get-ConnectorSnapshotStateText -Snapshot $After))
}

# ---------------------------------------------------------------------------
# Apply and verification
# ---------------------------------------------------------------------------
function ConvertTo-ExchangeParameterValue {
    param(
        [Parameter(Mandatory = $true)][string]$PropertyName,
        $Value
    )

    switch ($PropertyName) {
        'PermissionGroups' {
            $settableGroups = Get-SettablePermissionGroups -Value $Value
            return (@(Get-SafeArray -Value $settableGroups | ForEach-Object { [string]$_ }) -join ',')
        }
        'AuthMechanism' {
            return (@(Get-SafeArray -Value $Value | ForEach-Object { [string]$_ }) -join ',')
        }
        { $_ -in @('Bindings','RemoteIPRanges','TlsDomainCapabilities') } {
            return [string[]]@(Get-SafeArray -Value $Value | ForEach-Object { [string]$_ })
        }
        { $_ -in @('Enabled','RequireTLS') } {
            return (ConvertTo-StrictBoolean -Value $Value)
        }
        default { return $Value }
    }
}

function Invoke-PlanConnectorCreate {
    param([Parameter(Mandatory = $true)]$Plan)

    $source = $Plan.SourceConnector
    $transportRole = Normalize-ConnectorPropertyValue -PropertyName 'TransportRole' -Value (Get-SourceConnectorValue -Connector $source -PropertyName 'TransportRole')
    $bindings = Normalize-ConnectorPropertyValue -PropertyName 'Bindings' -Value (Get-SourceConnectorValue -Connector $source -PropertyName 'Bindings')
    $remoteRanges = Normalize-ConnectorPropertyValue -PropertyName 'RemoteIPRanges' -Value (Get-SourceConnectorValue -Connector $source -PropertyName 'RemoteIPRanges')

    $params = @{
        Name           = $Plan.TargetName
        Server         = $Plan.TargetServer
        TransportRole  = $transportRole
        Bindings       = [string[]]@(Get-SafeArray -Value $bindings)
        RemoteIPRanges = [string[]]@(Get-SafeArray -Value $remoteRanges)
        Enabled        = $false
        ErrorAction    = 'Stop'
    }

    New-ReceiveConnector @params -Custom | Out-Null
}

function Invoke-ExistingConnectorPreChangeState {
    param([Parameter(Mandatory = $true)]$Plan)

    if (-not $Plan.TargetExists) { return }

    $enabledComparison = @($Plan.Comparisons | Where-Object { $_.Property -eq 'Enabled' } | Select-Object -First 1)
    if ($enabledComparison.Count -eq 0 -or -not $enabledComparison[0].Manage -or $enabledComparison[0].Status -eq 'Unavailable') { return }

    $desiredEnabled = ConvertTo-StrictBoolean -Value $enabledComparison[0].DesiredValue
    $currentEnabled = ConvertTo-StrictBoolean -Value $enabledComparison[0].TargetValue

    # If the source state is disabled, disable the existing target first so all
    # subsequent property/permission work occurs with the connector inactive.
    if (-not $desiredEnabled -and $currentEnabled) {
        Write-ResultHost '  Disable existing Receive Connector before other managed changes' -ForegroundColor Cyan
        Set-ReceiveConnector -Identity ([string]$Plan.TargetConnector.Identity) -Enabled $false -ErrorAction Stop | Out-Null
    }
}

function Invoke-PlanPropertyChanges {
    param([Parameter(Mandatory = $true)]$Plan)

    $identity = if ($Plan.TargetExists) { [string]$Plan.TargetConnector.Identity } else { "$($Plan.TargetServer)\$($Plan.TargetName)" }
    $params = @{ Identity = $identity; ErrorAction = 'Stop' }
    $changedProperties = New-Object System.Collections.ArrayList

    foreach ($item in @($Plan.Comparisons | Where-Object { $_.Manage -and $_.Status -ne 'Same' })) {
        # Enabled is handled separately so a disabled connector is never enabled
        # until every other managed property and optional relay permission succeeds.
        if ($item.Property -eq 'Enabled') { continue }
        if ($Plan.CanCreate -and $item.Property -in @('Bindings','RemoteIPRanges','TransportRole')) { continue }

        $params[$item.Property] = ConvertTo-ExchangeParameterValue -PropertyName $item.Property -Value $item.DesiredValue
        [void]$changedProperties.Add($item.Property)
    }

    if ($changedProperties.Count -eq 0) { return }

    Write-ResultHost ("  Set properties: {0}" -f (@($changedProperties) -join ', ')) -ForegroundColor Cyan
    Set-ReceiveConnector @params | Out-Null
}

function Invoke-PlanAnonymousRelayChange {
    param([Parameter(Mandatory = $true)]$Plan)

    if (-not $Plan.AnonymousRelay.Manage) { return }

    $identity = if ($Plan.TargetExists) { [string]$Plan.TargetConnector.Identity } else { "$($Plan.TargetServer)\$($Plan.TargetName)" }
    $connector = Get-ReceiveConnector -Identity $identity -ErrorAction Stop
    $distinguishedName = [string](Get-ObjectPropertyValue -Object $connector -Name 'DistinguishedName')
    if ([string]::IsNullOrWhiteSpace($distinguishedName)) {
        throw "Receive Connector '$identity' DistinguishedName is unavailable. Anonymous relay permission change is blocked."
    }

    if (ConvertTo-StrictBoolean -Value $Plan.AnonymousRelay.SourceEnabled) {
        Write-ResultHost '  Add anonymous relay extended right' -ForegroundColor Cyan
        Add-ADPermission -Identity $distinguishedName -User $script:AnonymousLogonPrincipal -ExtendedRights $script:AnonymousRelayRight -ErrorAction Stop | Out-Null
    }
    else {
        Write-ResultHost '  Remove anonymous relay extended right' -ForegroundColor Cyan
        Remove-ADPermission -Identity $distinguishedName -User $script:AnonymousLogonPrincipal -ExtendedRights $script:AnonymousRelayRight -Confirm:$false -ErrorAction Stop | Out-Null
    }
}

function Invoke-PlanFinalEnabledState {
    param([Parameter(Mandatory = $true)]$Plan)

    $enabledComparison = @($Plan.Comparisons | Where-Object { $_.Property -eq 'Enabled' } | Select-Object -First 1)
    if ($enabledComparison.Count -eq 0 -or $enabledComparison[0].Status -eq 'Unavailable') {
        if ($Plan.CanCreate) {
            throw 'The source Enabled state is unavailable. The newly created connector will remain disabled.'
        }
        return
    }

    $desiredEnabled = ConvertTo-StrictBoolean -Value $enabledComparison[0].DesiredValue
    $identity = if ($Plan.TargetExists) { [string]$Plan.TargetConnector.Identity } else { "$($Plan.TargetServer)\$($Plan.TargetName)" }

    if ($Plan.CanCreate) {
        if ($desiredEnabled) {
            Write-ResultHost '  Enable newly created Receive Connector after all managed changes succeeded' -ForegroundColor Cyan
            Set-ReceiveConnector -Identity $identity -Enabled $true -ErrorAction Stop | Out-Null
        }
        else {
            Write-ResultHost '  Newly created Receive Connector remains disabled to match the source state' -ForegroundColor Cyan
        }
        return
    }

    if (-not $enabledComparison[0].Manage -or $enabledComparison[0].Status -eq 'Same') { return }

    $currentEnabled = ConvertTo-StrictBoolean -Value $enabledComparison[0].TargetValue
    if ($desiredEnabled -and -not $currentEnabled) {
        Write-ResultHost '  Enable existing Receive Connector after all other managed changes succeeded' -ForegroundColor Cyan
        Set-ReceiveConnector -Identity $identity -Enabled $true -ErrorAction Stop | Out-Null
    }
    # Desired Disabled is handled before other changes by
    # Invoke-ExistingConnectorPreChangeState.
}

function Invoke-ConnectorPlan {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans)

    $errors = New-Object System.Collections.ArrayList

    foreach ($plan in @($Plans | Sort-Object TargetServer,TargetName)) {
        if (-not (Test-PlanHasManagedChanges -Plan $plan)) { continue }

        Write-ResultHost ''
        Write-ResultHost ("Configuring [{0}] {1}" -f $plan.TargetServer,$plan.TargetName) -ForegroundColor Yellow

        $createdThisRun = $false
        try {
            if ($plan.CanCreate) {
                Write-ResultHost '  Create custom Receive Connector in disabled state' -ForegroundColor Cyan
                Invoke-PlanConnectorCreate -Plan $plan
                $createdThisRun = $true
            }
            else {
                Invoke-ExistingConnectorPreChangeState -Plan $plan
            }

            Invoke-PlanPropertyChanges -Plan $plan
            Invoke-PlanAnonymousRelayChange -Plan $plan
            Invoke-PlanFinalEnabledState -Plan $plan
        }
        catch {
            $applyError = $_

            if ($createdThisRun) {
                try {
                    Set-ReceiveConnector -Identity ("{0}\{1}" -f $plan.TargetServer,$plan.TargetName) -Enabled $false -ErrorAction Stop | Out-Null
                    Write-ResultHost '  Safety action: newly created connector was left disabled after the failure.' -ForegroundColor Yellow
                }
                catch {
                    Write-ResultHost ("  WARNING: Could not confirm the new connector is disabled: {0}" -f $_.Exception.Message) -ForegroundColor Red
                }
            }

            [void]$errors.Add([PSCustomObject]@{
                Target    = $plan.TargetServer
                Connector = $plan.TargetName
                Error     = $applyError.Exception.Message
            })
            Write-ResultHost ("  ERROR: {0}" -f $applyError.Exception.Message) -ForegroundColor Red
            Write-ResultHost '  Apply stopped. Remaining connector plans were not modified.' -ForegroundColor Yellow
            break
        }
    }

    return @($errors)
}

function Test-ConnectorPlan {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans,
        [Parameter(Mandatory = $true)]$FreshTargetSnapshot
    )

    $results = New-Object System.Collections.ArrayList
    $targetPlans = @($Plans | Where-Object {
        (Test-PlanHasManagedChanges -Plan $_) -and ([string]$_.TargetServer -ieq [string]$FreshTargetSnapshot.Server)
    })

    foreach ($plan in $targetPlans) {
        $freshTarget = Get-TargetConnector -TargetSnapshot $FreshTargetSnapshot -SourceConnector $plan.SourceConnector
        if ($null -eq $freshTarget) {
            [void]$results.Add([PSCustomObject]@{ Target = $plan.TargetServer; Connector = $plan.TargetName; Item = 'Connector'; Status = 'Mismatch'; Expected = 'Present'; Actual = 'Missing' })
            continue
        }

        foreach ($item in @($plan.Comparisons | Where-Object { $_.Manage -and $_.Status -ne 'Same' })) {
            $actual = Get-SourceConnectorValue -Connector $freshTarget -PropertyName $item.Property
            $actualComparisonValue = $actual
            if ($item.Property -eq 'PermissionGroups') {
                $actualComparisonValue = Get-SettablePermissionGroups -Value $actual
            }
            $status = if (Test-EquivalentValue -Left $item.DesiredValue -Right $actualComparisonValue) { 'Verified' } else { 'Mismatch' }
            [void]$results.Add([PSCustomObject]@{
                Target    = $plan.TargetServer
                Connector = $plan.TargetName
                Item      = $item.Property
                Status    = $status
                Expected  = ConvertTo-DisplayValue -Value $item.DesiredValue
                Actual    = ConvertTo-DisplayValue -Value $actual
            })
        }

        if ($plan.AnonymousRelay.Manage) {
            $actualRelay = $freshTarget.PermissionSnapshot
            $status = if ($actualRelay.QueryStatus -eq 'Available' -and (ConvertTo-StrictBoolean -Value $actualRelay.AnonymousRelayEnabled) -eq (ConvertTo-StrictBoolean -Value $plan.AnonymousRelay.SourceEnabled)) { 'Verified' } else { 'Mismatch' }
            [void]$results.Add([PSCustomObject]@{
                Target    = $plan.TargetServer
                Connector = $plan.TargetName
                Item      = 'Anonymous Relay'
                Status    = $status
                Expected  = [string]$plan.AnonymousRelay.SourceEnabled
                Actual    = $(if ($actualRelay.QueryStatus -eq 'Available') { [string]$actualRelay.AnonymousRelayEnabled } else { 'Unknown' })
            })
        }
    }

    return @($results)
}

function Show-Verification {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Results)

    Write-ResultHost ''
    Write-ResultHost 'Verification summary' -ForegroundColor Cyan
    Write-ResultHost '--------------------' -ForegroundColor Cyan

    if ($Results.Count -eq 0) {
        Write-ResultHost 'No managed changes required verification.' -ForegroundColor Green
        return
    }

    foreach ($result in $Results) {
        $color = if ($result.Status -eq 'Verified') { 'Green' } else { 'Red' }
        Write-ResultHost ("[{0}] {1} - {2}: {3}" -f $result.Target,$result.Connector,$result.Item,$result.Status) -ForegroundColor $color
        if ($result.Status -ne 'Verified') {
            Write-ResultHost ("  Expected : {0}" -f $result.Expected)
            Write-ResultHost ("  Actual   : {0}" -f $result.Actual)
        }
    }
}

# ---------------------------------------------------------------------------
# Review / backup helpers
# ---------------------------------------------------------------------------
function Get-NormalizedServers {
    param([Parameter(Mandatory = $true)][string[]]$Servers)

    $result = @($Servers | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Select-Object -Unique)
    if ($result.Count -eq 0) { throw 'At least one Exchange server is required.' }
    return $result
}

function Select-SourceConnectors {
    param(
        [Parameter(Mandatory = $true)]$SourceSnapshot,
        [string[]]$Names
    )

    $sourceConnectors = @(Get-SafeArray -Value $SourceSnapshot.Items)
    if (-not $Names) { return $sourceConnectors }

    $requestedNames = @($Names | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Select-Object -Unique)
    $selected = New-Object System.Collections.ArrayList

    foreach ($requestedName in $requestedNames) {
        $matches = @($sourceConnectors | Where-Object {
            ([string]$_.Name) -ieq $requestedName -or
            (-not [string]::IsNullOrWhiteSpace([string]$_.BuiltInFamily) -and ([string]$_.BuiltInFamily) -ieq $requestedName)
        })

        if ($matches.Count -eq 0) {
            throw "Connector '$requestedName' was not found on source '$($SourceSnapshot.Server)'."
        }

        foreach ($match in $matches) {
            if (@($selected | Where-Object { ([string]$_.Name) -ieq ([string]$match.Name) }).Count -eq 0) {
                [void]$selected.Add($match)
            }
        }
    }

    return @($selected)
}

function Resolve-BackupPaths {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = $Path.Trim()
    if ([string]::IsNullOrWhiteSpace($resolved)) { throw 'OutputFile cannot be empty.' }

    $extension = [System.IO.Path]::GetExtension($resolved)
    if ([string]::IsNullOrWhiteSpace($extension)) {
        $resolved = "$resolved.txt"
    }
    elseif ($extension -ne '.txt') {
        throw 'OutputFile must use the .txt extension.'
    }

    if (-not [System.IO.Path]::IsPathRooted($resolved)) {
        $resolved = Join-Path -Path (Get-Location).Path -ChildPath $resolved
    }

    $parent = Split-Path -Parent $resolved
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -Path $parent -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $resolved = [System.IO.Path]::GetFullPath($resolved)
    $directory = Split-Path -Parent $resolved
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
    $txtPath = $resolved
    $jsonPath = Join-Path -Path $directory -ChildPath ($baseName + '.json')

    if ((Test-Path -LiteralPath $txtPath) -or (Test-Path -LiteralPath $jsonPath)) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $candidateBase = "{0}_{1}" -f $baseName, $timestamp
        $txtPath = Join-Path -Path $directory -ChildPath ($candidateBase + '.txt')
        $jsonPath = Join-Path -Path $directory -ChildPath ($candidateBase + '.json')
        $suffix = 2

        while ((Test-Path -LiteralPath $txtPath) -or (Test-Path -LiteralPath $jsonPath)) {
            $candidateBase = "{0}_{1}_{2}" -f $baseName, $timestamp, $suffix
            $txtPath = Join-Path -Path $directory -ChildPath ($candidateBase + '.txt')
            $jsonPath = Join-Path -Path $directory -ChildPath ($candidateBase + '.json')
            $suffix++
        }
    }

    return [PSCustomObject]@{
        TxtPath  = [System.IO.Path]::GetFullPath($txtPath)
        JsonPath = [System.IO.Path]::GetFullPath($jsonPath)
    }
}

# ---------------------------------------------------------------------------
# Connector identity and permissions
# ---------------------------------------------------------------------------

function Show-ReceiveConnectorInventory {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Snapshots)

    foreach ($snapshot in $Snapshots) {
        Write-ResultHost ''
        Write-ResultHost ("[{0}] Receive Connector configuration" -f $snapshot.Server) -ForegroundColor Cyan
        Write-ResultHost ('-' * ([Math]::Min(78, 34 + $snapshot.Server.Length))) -ForegroundColor Cyan
        Write-ResultHost ("Server FQDN : {0}" -f (ConvertTo-DisplayValue -Value $snapshot.ServerFqdn))
        Write-ResultHost ("Version     : {0}" -f (ConvertTo-DisplayValue -Value $snapshot.AdminDisplayVersion))
        Write-ResultHost ("Server Role : {0}" -f (ConvertTo-DisplayValue -Value $snapshot.ServerRole))
        Write-ResultHost ("Connectors  : {0}" -f @($snapshot.Items).Count)

        foreach ($connector in @($snapshot.Items | Sort-Object Name)) {
            Write-ResultHost ''
            Write-ResultHost ("Connector       : {0}" -f $connector.Name) -ForegroundColor Yellow
            Write-ResultHost ("Identity        : {0}" -f $connector.Identity)
            Write-ResultHost ("Type            : {0}" -f $connector.ConnectorType)
            if ($connector.BuiltInFamily) {
                Write-ResultHost ("Built-in Family : {0}" -f $connector.BuiltInFamily)
            }

            foreach ($propertyName in $script:ConnectorPropertyNames) {
                Write-ResultHost ("{0,-20}: {1}" -f $propertyName, (ConvertTo-DisplayValue -Value $connector.Values[$propertyName]))
            }

            $relayText = if ($connector.PermissionSnapshot.QueryStatus -ne 'Available') {
                'Unknown'
            }
            elseif ($connector.PermissionSnapshot.AnonymousRelayEnabled) {
                'Enabled'
            }
            else {
                'Disabled'
            }

            Write-ResultHost ("Anonymous Relay     : {0}" -f $relayText)
            Write-ResultHost ("Explicit AD Perms   : {0}" -f @($connector.PermissionSnapshot.ExplicitPermissions).Count)

            if ($connector.PermissionSnapshot.Error) {
                Write-ResultHost ("Permission Error    : {0}" -f $connector.PermissionSnapshot.Error) -ForegroundColor Yellow
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Backup output
# ---------------------------------------------------------------------------

function Export-ReceiveConnectorTextReport {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Snapshots
    )

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add(("{0}.ps1 v{1} - Receive Connector configuration report" -f $script:ToolName, $script:ScriptVersion))
    [void]$lines.Add(("Generated : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    [void]$lines.Add(("Operator  : {0}" -f [System.Security.Principal.WindowsIdentity]::GetCurrent().Name))
    [void]$lines.Add('Mode      : Read-only Configuration Review / Report')
    [void]$lines.Add('Changes   : NONE')
    [void]$lines.Add('')

    foreach ($snapshot in $Snapshots) {
        [void]$lines.Add(('=' * 80))
        [void]$lines.Add(("Server: {0}" -f $snapshot.Server))
        [void]$lines.Add(("Server FQDN: {0}" -f (ConvertTo-DisplayValue -Value $snapshot.ServerFqdn)))
        [void]$lines.Add(("Version: {0}" -f (ConvertTo-DisplayValue -Value $snapshot.AdminDisplayVersion)))
        [void]$lines.Add(("Server Role: {0}" -f (ConvertTo-DisplayValue -Value $snapshot.ServerRole)))
        [void]$lines.Add(('=' * 80))
        [void]$lines.Add('')

        foreach ($connector in @($snapshot.Items | Sort-Object Name)) {
            [void]$lines.Add(("[{0}]" -f $connector.Name))
            [void]$lines.Add(("Identity = {0}" -f $connector.Identity))
            [void]$lines.Add(("Type = {0}" -f $connector.ConnectorType))
            if ($connector.BuiltInFamily) {
                [void]$lines.Add(("BuiltInFamily = {0}" -f $connector.BuiltInFamily))
            }

            foreach ($propertyName in $script:ConnectorPropertyNames) {
                [void]$lines.Add(("{0} = {1}" -f $propertyName, (ConvertTo-DisplayValue -Value $connector.Values[$propertyName])))
            }

            [void]$lines.Add(("AnonymousRelay.Enabled = {0}" -f (ConvertTo-DisplayValue -Value $connector.PermissionSnapshot.AnonymousRelayEnabled)))
            [void]$lines.Add(("Permissions.QueryStatus = {0}" -f $connector.PermissionSnapshot.QueryStatus))

            if ($connector.PermissionSnapshot.Error) {
                [void]$lines.Add(("Permissions.Error = {0}" -f $connector.PermissionSnapshot.Error))
            }

            # Keep the human-readable TXT report concise. Full explicit AD
            # permission detail remains in the JSON backup.
            [void]$lines.Add(("ExplicitPermissions.Count = {0}" -f @($connector.PermissionSnapshot.ExplicitPermissions).Count))

            [void]$lines.Add('')
        }
    }

    Set-Content -LiteralPath $Path -Value @($lines) -Encoding UTF8 -ErrorAction Stop
}

function Export-ReceiveConnectorJsonBackup {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Snapshots
    )

    $payload = [PSCustomObject]@{
        BackupSchema = 'ExchangeReceiveConnectorBackup'
        SchemaVersion = 1
        Tool          = $script:ToolName
        ToolVersion   = $script:ScriptVersion
        Version       = $script:ScriptVersion
        Generated     = (Get-Date).ToString('o')
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Operator      = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Mode          = 'Read-only Configuration Review / Backup'
        Changes       = 'NONE'
        RestoreCompatibility = [PSCustomObject]@{
            RestoreTool          = 'ExchangeReceiveConnectorManager'
            MinimumRestoreVersion = '1.0'
            ConnectorProperties  = @($script:ConnectorPropertyNames)
            ExplicitPermissionPolicy = 'Inventory only; automatic restore is limited to the explicit anonymous relay right.'
        }
        Servers       = @($Snapshots)
    }

    $payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop
}

# ---------------------------------------------------------------------------
# Console paging
# ---------------------------------------------------------------------------
$script:PagingEnabled = $false
$script:PagingLineCount = 0
$script:PagingPageHeight = 0
$script:PagingWindowWidth = 120

function Initialize-ResultPaging {
    $script:PagingEnabled = $false
    $script:PagingLineCount = 0
    $script:PagingPageHeight = 0
    $script:PagingWindowWidth = 120

    if ($NoPaging -or -not [string]::IsNullOrWhiteSpace($OutputFile)) { return }

    try {
        $windowSize = $Host.UI.RawUI.WindowSize
        $height = [int]$windowSize.Height
        $width = [int]$windowSize.Width
        if ($height -ge 10 -and $width -ge 20) {
            $script:PagingPageHeight = [Math]::Max(5, ($height - 3))
            $script:PagingWindowWidth = [Math]::Max(20, $width)
            $script:PagingEnabled = $true
        }
    }
    catch {
        $script:PagingEnabled = $false
    }
}

function Get-ResultDisplayLineCount {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) { return 1 }

    $width = [Math]::Max(20, [int]$script:PagingWindowWidth)
    $count = 0
    foreach ($line in @($Text -split "`r`n|`n|`r")) {
        $lineText = [string]$line
        $count += [Math]::Max(1, [int][Math]::Ceiling(($lineText.Length + 1) / [double]$width))
    }
    return $count
}

function Invoke-ResultPagingPause {
    if (-not $script:PagingEnabled) { return }

    Write-Host ''
    $response = Read-Host 'Press ENTER to continue, or Q to stop paging'
    if ([string]$response -match '(?i)^q$') {
        $script:PagingEnabled = $false
    }
    $script:PagingLineCount = 0
}

function Write-ResultHost {
    param(
        [AllowNull()][string]$Text = '',
        [System.ConsoleColor]$ForegroundColor,
        [switch]$NoNewline
    )

    $lineCount = Get-ResultDisplayLineCount -Text $Text
    if ($script:PagingEnabled -and $script:PagingLineCount -gt 0 -and (($script:PagingLineCount + $lineCount) -gt $script:PagingPageHeight)) {
        Invoke-ResultPagingPause
    }

    if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
        Write-Host $Text -ForegroundColor $ForegroundColor -NoNewline:$NoNewline
    }
    else {
        Write-Host $Text -NoNewline:$NoNewline
    }

    if (-not $NoNewline) { $script:PagingLineCount += $lineCount }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
try {
    $operationMode = [string]$PSCmdlet.ParameterSetName
    $isReviewMode = $operationMode -eq 'Review'
    $isCloneMode = $operationMode -eq 'Clone'
    $isRestoreMode = $operationMode -eq 'Restore'

    Write-Host ''
    Write-Host ("{0}.ps1" -f $script:ToolName) -ForegroundColor Yellow
    Write-Host 'Exchange Server Receive Connector review, backup, clone, and restore manager' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host 'Author  : Ceyhun Kirmizitas' -ForegroundColor Cyan
    Write-Host ("Version : {0}" -f $script:ScriptVersion) -ForegroundColor Cyan

    if ($isReviewMode) {
        Write-Host 'Mode    : Configuration Review / Backup' -ForegroundColor Cyan
        Write-Host 'Changes : NONE' -ForegroundColor Green
        Write-Host ''
        Write-Host 'The script only reads Receive Connector configuration and permissions in this mode.' -ForegroundColor Cyan
        Write-Host 'No Exchange configuration changes will be made.' -ForegroundColor Cyan
    }
    elseif ($isCloneMode) {
        Write-Host ("Mode    : {0}" -f $(if ($ApplyChanges) { 'Clone - Apply Changes' } else { 'Clone Preview' })) -ForegroundColor Cyan
        Write-Host ("Changes : {0}" -f $(if ($ApplyChanges) { 'ENABLED' } else { 'NONE' })) -ForegroundColor $(if ($ApplyChanges) { 'Yellow' } else { 'Green' })
        Write-Host ''
        if ($ApplyChanges) {
            Write-Host 'The script can create custom Receive Connectors and modify supported settings on the target server(s).' -ForegroundColor Yellow
            Write-Host 'Review the complete clone plan before confirming the operation.' -ForegroundColor Yellow
        }
        else {
            Write-Host 'Clone Preview compares the live source server with the target server(s).' -ForegroundColor Cyan
            Write-Host 'No Exchange configuration changes will be made.' -ForegroundColor Cyan
        }
    }
    else {
        Write-Host ("Mode    : {0}" -f $(if ($ApplyChanges) { 'Restore - Apply Changes' } else { 'Restore Preview' })) -ForegroundColor Cyan
        Write-Host ("Changes : {0}" -f $(if ($ApplyChanges) { 'ENABLED' } else { 'NONE' })) -ForegroundColor $(if ($ApplyChanges) { 'Yellow' } else { 'Green' })
        Write-Host ''
        if ($ApplyChanges) {
            Write-Host 'The script can create custom Receive Connectors and modify supported settings on the target server.' -ForegroundColor Yellow
            Write-Host 'Review the complete restore plan before confirming the operation.' -ForegroundColor Yellow
        }
        else {
            Write-Host 'Restore Preview reads the JSON backup and target Receive Connector configuration.' -ForegroundColor Cyan
            Write-Host 'No Exchange configuration changes will be made.' -ForegroundColor Cyan
        }
    }

    Write-Host ''
    [void](Read-Host 'Press ENTER to start')
    Write-Host ''

    Initialize-ExchangeShell
    Initialize-ResultPaging

    # -----------------------------------------------------------------------
    # Review / Backup
    # -----------------------------------------------------------------------
    if ($isReviewMode) {
        $requestedServers = if ($Server) { @($Server) } else { @($env:COMPUTERNAME) }
        $requestedServers = Get-NormalizedServers -Servers $requestedServers

        $serverObjects = New-Object System.Collections.ArrayList
        foreach ($serverIdentity in $requestedServers) {
            $serverObject = Resolve-MailboxExchangeServer -Identity $serverIdentity
            if (@($serverObjects | Where-Object { $_.Name -ieq $serverObject.Name }).Count -eq 0) {
                [void]$serverObjects.Add($serverObject)
            }
        }

        $snapshots = New-Object System.Collections.ArrayList
        foreach ($serverObject in $serverObjects) {
            [void]$snapshots.Add((Get-TargetConnectorSnapshot -ServerObject $serverObject))
        }

        Show-ReceiveConnectorInventory -Snapshots @($snapshots)

        if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
            $paths = Resolve-BackupPaths -Path $OutputFile
            Export-ReceiveConnectorTextReport -Path $paths.TxtPath -Snapshots @($snapshots)
            Export-ReceiveConnectorJsonBackup -Path $paths.JsonPath -Snapshots @($snapshots)

            Write-ResultHost ''
            Write-ResultHost ("TXT report  : {0}" -f $paths.TxtPath) -ForegroundColor Green
            Write-ResultHost ("JSON backup : {0}" -f $paths.JsonPath) -ForegroundColor Green
            Write-ResultHost 'The JSON file is the restore-compatible backup. No Exchange configuration changes were applied.' -ForegroundColor Green
        }
        return
    }

    # -----------------------------------------------------------------------
    # Clone - live source server to one or more live target servers
    # -----------------------------------------------------------------------
    if ($isCloneMode) {
        $script:PlanOperation = 'Clone'
        $script:BackupPath = $null

        $sourceServerObject = Resolve-MailboxExchangeServer -Identity $SourceServer
        $sourceSnapshot = Get-TargetConnectorSnapshot -ServerObject $sourceServerObject
        $script:SourceSnapshot = $sourceSnapshot

        $requestedTargets = Get-NormalizedServers -Servers @($TargetServers)
        $targetObjects = New-Object System.Collections.ArrayList
        foreach ($targetIdentity in $requestedTargets) {
            $targetObject = Resolve-MailboxExchangeServer -Identity $targetIdentity
            if ([string]$targetObject.Name -ieq [string]$sourceServerObject.Name) {
                throw "SourceServer and TargetServers cannot contain the same server '$($targetObject.Name)'."
            }
            if (@($targetObjects | Where-Object { $_.Name -ieq $targetObject.Name }).Count -eq 0) {
                [void]$targetObjects.Add($targetObject)
            }
        }

        $sourceConnectors = @(Select-SourceConnectors -SourceSnapshot $sourceSnapshot -Names $ConnectorName)
        if ($sourceConnectors.Count -eq 0) { throw 'No source Receive Connectors were selected.' }

        Write-ResultHost ("Source server : {0}" -f $sourceSnapshot.Server) -ForegroundColor Cyan
        Write-ResultHost ("Target server(s): {0}" -f (@($targetObjects | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Cyan
        Write-ResultHost ''
        Write-ResultHost 'Collecting Receive Connector configuration and permissions...' -ForegroundColor DarkGray

        $plans = New-Object System.Collections.ArrayList
        $targetSnapshots = @{}
        foreach ($targetObject in $targetObjects) {
            $targetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetObject
            $targetSnapshots[[string]$targetSnapshot.Server] = $targetSnapshot
            foreach ($sourceConnector in $sourceConnectors) {
                [void]$plans.Add((New-ConnectorPlan -SourceConnector $sourceConnector -SourceSnapshot $sourceSnapshot -TargetSnapshot $targetSnapshot))
            }
        }

        Show-ConnectorPlan -Plans @($plans)

        if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
            $planPath = Export-ConnectorPlan -Path $OutputFile -Plans @($plans)
            Write-ResultHost ''
            Write-ResultHost ("Clone plan saved: {0}" -f $planPath) -ForegroundColor Green
        }

        if (-not $ApplyChanges) {
            Write-ResultHost ''
            Write-ResultHost 'Clone preview completed. Changes: NONE.' -ForegroundColor Green
            Write-ResultHost 'Run the same command with -ApplyChanges after reviewing the plan.' -ForegroundColor Cyan
            return
        }

        if (@($plans | Where-Object { $_.Blocked }).Count -gt 0) {
            throw 'Clone apply aborted: resolve every BLOCKER in the plan before applying. No Exchange configuration changes were applied.'
        }
        $managedPlans = @($plans | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
        if ($managedPlans.Count -eq 0) {
            Write-ResultHost ''
            Write-ResultHost 'No automatic Receive Connector changes are required.' -ForegroundColor Green
            return
        }

        Write-ResultHost ''
        Write-ResultHost 'Refreshing target state and validating the apply plan...' -ForegroundColor Cyan

        # Re-read every target before confirmation and rebuild the plan from current state.
        # This prevents the Apply phase and the pre-change backup from relying on
        # the older objects that were collected for the initial preview.
        $preConfirmSourceSnapshot = Get-TargetConnectorSnapshot -ServerObject $sourceServerObject
        $preConfirmSourceConnectors = @(Select-SourceConnectors -SourceSnapshot $preConfirmSourceSnapshot -Names $ConnectorName)
        $preConfirmSnapshots = @{}
        $applyPlans = New-Object System.Collections.ArrayList
        foreach ($targetObject in $targetObjects) {
            $currentSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetObject
            $preConfirmSnapshots[[string]$currentSnapshot.Server] = $currentSnapshot
            foreach ($sourceConnector in $preConfirmSourceConnectors) {
                [void]$applyPlans.Add((New-ConnectorPlan -SourceConnector $sourceConnector -SourceSnapshot $preConfirmSourceSnapshot -TargetSnapshot $currentSnapshot))
            }
        }

        Write-ResultHost ''
        Write-ResultHost 'Refreshed pre-apply plan' -ForegroundColor Cyan
        Write-ResultHost '------------------------' -ForegroundColor Cyan
        Show-ConnectorPlan -Plans @($applyPlans)

        if (@($applyPlans | Where-Object { $_.Blocked }).Count -gt 0) {
            throw 'Clone apply aborted: the refreshed plan contains BLOCKER conditions. No Exchange configuration changes were applied.'
        }
        $managedPlans = @($applyPlans | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
        if ($managedPlans.Count -eq 0) {
            Write-ResultHost ''
            Write-ResultHost 'No automatic Receive Connector changes are required after the pre-apply refresh.' -ForegroundColor Green
            return
        }

        $targetNames = @($targetObjects | ForEach-Object { [string]$_.Name })
        if (-not $PSCmdlet.ShouldProcess(($targetNames -join ', '), "Clone supported Receive Connector configuration from live server '$($sourceSnapshot.Server)'")) {
            Write-ResultHost 'Operation cancelled. No Exchange configuration changes were applied.' -ForegroundColor Yellow
            return
        }

        # Read the targets again immediately after confirmation. If anything
        # changed while the confirmation was pending, abort rather than applying
        # a plan the operator did not review. The snapshot written below is from
        # this final read, immediately before the configuration changes.
        $finalSourceSnapshot = Get-TargetConnectorSnapshot -ServerObject $sourceServerObject
        if (-not (Test-ConnectorSnapshotUnchanged -Before $preConfirmSourceSnapshot -After $finalSourceSnapshot)) {
            throw "Receive Connector configuration changed on source '$($preConfirmSourceSnapshot.Server)' after the refreshed plan was displayed. No changes were applied. Run the command again and review the new plan."
        }

        $finalTargetSnapshots = @{}
        foreach ($targetObject in $targetObjects) {
            $finalSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetObject
            $targetName = [string]$finalSnapshot.Server
            if (-not (Test-ConnectorSnapshotUnchanged -Before $preConfirmSnapshots[$targetName] -After $finalSnapshot)) {
                throw "Receive Connector configuration changed on '$targetName' after the refreshed plan was displayed. No changes were applied. Run the command again and review the new plan."
            }
            $finalTargetSnapshots[$targetName] = $finalSnapshot
            $preChangePath = Export-PreChangeSnapshot -TargetSnapshot $finalSnapshot
            Write-ResultHost ("Pre-change JSON snapshot [{0}]: {1}" -f $targetName,$preChangePath) -ForegroundColor Green
        }

        $applyErrors = @(Invoke-ConnectorPlan -Plans @($applyPlans))

        $verification = New-Object System.Collections.ArrayList
        foreach ($targetObject in $targetObjects) {
            $freshTargetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetObject
            foreach ($result in @(Test-ConnectorPlan -Plans @($applyPlans) -FreshTargetSnapshot $freshTargetSnapshot)) {
                [void]$verification.Add($result)
            }
        }
        Show-Verification -Results @($verification)

        if ($applyErrors.Count -gt 0) {
            Write-ResultHost ''
            Write-ResultHost ("Clone apply completed with {0} connector error(s). Review the errors and verification results above." -f $applyErrors.Count) -ForegroundColor Red
            exit 1
        }

        if (@($verification | Where-Object { $_.Status -ne 'Verified' }).Count -gt 0) {
            Write-ResultHost ''
            Write-ResultHost 'Clone apply completed, but one or more verification items do not match the source configuration.' -ForegroundColor Yellow
            exit 1
        }

        Write-ResultHost ''
        Write-ResultHost 'Receive Connector clone completed and managed changes were verified.' -ForegroundColor Green
        return
    }

    # -----------------------------------------------------------------------
    # Restore - JSON backup to one target server
    # -----------------------------------------------------------------------
    $script:PlanOperation = 'Restore'
    $backup = Import-ReceiveConnectorBackup -Path $RestoreFile
    $script:BackupPath = $backup.Path
    $sourceSnapshot = Select-SourceBackupServer -Backup $backup -Identity $SourceServer
    $script:SourceSnapshot = $sourceSnapshot

    $targetServerObject = Resolve-MailboxExchangeServer -Identity $TargetServer
    $targetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject

    Write-ResultHost ("Backup schema : {0}" -f $(if ($backup.LegacySchema) { 'Legacy v1.0 backup (accepted)' } else { "ExchangeReceiveConnectorBackup v$($backup.SchemaVersion)" })) -ForegroundColor Cyan
    Write-ResultHost ("Source server : {0}" -f $sourceSnapshot.Server) -ForegroundColor Cyan
    Write-ResultHost ("Target server : {0}" -f $targetSnapshot.Server) -ForegroundColor Cyan
    Write-ResultHost ''

    $sourceConnectors = @(Select-SourceConnectors -SourceSnapshot $sourceSnapshot -Names $ConnectorName)
    if ($sourceConnectors.Count -eq 0) { throw 'No source Receive Connectors were selected.' }

    $plans = New-Object System.Collections.ArrayList
    foreach ($sourceConnector in $sourceConnectors) {
        [void]$plans.Add((New-ConnectorPlan -SourceConnector $sourceConnector -SourceSnapshot $sourceSnapshot -TargetSnapshot $targetSnapshot))
    }

    Show-ConnectorPlan -Plans @($plans)

    if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
        $planPath = Export-ConnectorPlan -Path $OutputFile -Plans @($plans)
        Write-ResultHost ''
        Write-ResultHost ("Restore plan saved: {0}" -f $planPath) -ForegroundColor Green
    }

    if (-not $ApplyChanges) {
        Write-ResultHost ''
        Write-ResultHost 'Restore preview completed. Changes: NONE.' -ForegroundColor Green
        Write-ResultHost 'Run the same command with -ApplyChanges after reviewing the plan.' -ForegroundColor Cyan
        return
    }

    if (@($plans | Where-Object { $_.Blocked }).Count -gt 0) {
        throw 'Restore apply aborted: resolve every BLOCKER in the plan before applying. No Exchange configuration changes were applied.'
    }
    $managedPlans = @($plans | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
    if ($managedPlans.Count -eq 0) {
        Write-ResultHost ''
        Write-ResultHost 'No automatic Receive Connector changes are required.' -ForegroundColor Green
        return
    }

    Write-ResultHost ''
    Write-ResultHost 'Refreshing target state and validating the apply plan...' -ForegroundColor Cyan

    # Refresh the target before confirmation and rebuild the plan from current state.
    $preConfirmSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject
    $applyPlans = New-Object System.Collections.ArrayList
    foreach ($sourceConnector in $sourceConnectors) {
        [void]$applyPlans.Add((New-ConnectorPlan -SourceConnector $sourceConnector -SourceSnapshot $sourceSnapshot -TargetSnapshot $preConfirmSnapshot))
    }

    Write-ResultHost ''
    Write-ResultHost 'Refreshed pre-apply plan' -ForegroundColor Cyan
    Write-ResultHost '------------------------' -ForegroundColor Cyan
    Show-ConnectorPlan -Plans @($applyPlans)

    if (@($applyPlans | Where-Object { $_.Blocked }).Count -gt 0) {
        throw 'Restore apply aborted: the refreshed plan contains BLOCKER conditions. No Exchange configuration changes were applied.'
    }
    $managedPlans = @($applyPlans | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
    if ($managedPlans.Count -eq 0) {
        Write-ResultHost ''
        Write-ResultHost 'No automatic Receive Connector changes are required after the pre-apply refresh.' -ForegroundColor Green
        return
    }

    if (-not $PSCmdlet.ShouldProcess($preConfirmSnapshot.Server, "Restore supported Receive Connector configuration from JSON backup '$($sourceSnapshot.Server)'")) {
        Write-ResultHost 'Operation cancelled. No Exchange configuration changes were applied.' -ForegroundColor Yellow
        return
    }

    $finalTargetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject
    if (-not (Test-ConnectorSnapshotUnchanged -Before $preConfirmSnapshot -After $finalTargetSnapshot)) {
        throw "Receive Connector configuration changed on '$($preConfirmSnapshot.Server)' after the refreshed plan was displayed. No changes were applied. Run the command again and review the new plan."
    }

    $preChangePath = Export-PreChangeSnapshot -TargetSnapshot $finalTargetSnapshot
    Write-ResultHost ''
    Write-ResultHost ("Pre-change JSON snapshot: {0}" -f $preChangePath) -ForegroundColor Green

    $applyErrors = @(Invoke-ConnectorPlan -Plans @($applyPlans))

    $freshTargetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject
    $verification = @(Test-ConnectorPlan -Plans @($applyPlans) -FreshTargetSnapshot $freshTargetSnapshot)
    Show-Verification -Results $verification

    if ($applyErrors.Count -gt 0) {
        Write-ResultHost ''
        Write-ResultHost ("Restore apply completed with {0} connector error(s). Review the errors and verification results above." -f $applyErrors.Count) -ForegroundColor Red
        exit 1
    }

    if (@($verification | Where-Object { $_.Status -ne 'Verified' }).Count -gt 0) {
        Write-ResultHost ''
        Write-ResultHost 'Restore apply completed, but one or more verification items do not match the JSON backup.' -ForegroundColor Yellow
        exit 1
    }

    Write-ResultHost ''
    Write-ResultHost 'Receive Connector restore completed and managed changes were verified.' -ForegroundColor Green
}
catch {
    Write-Host ''
    Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}