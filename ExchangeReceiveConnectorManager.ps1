<#
.SYNOPSIS
Reviews, backs up, clones, and restores Exchange Server Receive Connector configuration, merges RemoteIPRanges, and checks relay configuration.

.DESCRIPTION
ExchangeReceiveConnectorManager.ps1 reviews, backs up, clones, and restores Exchange Server Receive Connectors, merges RemoteIPRanges into an existing connector, and checks relay configuration. It is intended for side-by-side deployments, upgrades, migrations, and server replacement.

Modes
- Review / Backup (default): reads Receive Connector configuration and explicit AD permissions from one or more servers. With -OutputFile, it saves a TXT report and a JSON backup with the same base name. Restore uses the JSON file.
- Clone: compares selected connectors on a live source server with one or more target servers and creates or updates them when Apply is approved.
- Restore: compares a JSON backup with a target server and creates or updates connectors when Apply is approved. When the backup server name equals -TargetServer, it is a same-server Restore and Bindings are included. Otherwise it is a cross-server Restore and Bindings stay target-specific.
- RemoteIPRanges Merge Only: adds IP ranges from selected custom source connectors to one existing custom target connector. Existing ranges and other settings are kept. Listener overlap and entry-count limits are checked before Apply. Added IP addresses use the target connector's existing permissions.
- Relay Configuration Check (-CheckRelay): read-only. Reports anonymous and externally secured relay configuration per connector. Anonymous relay checks evaluate explicit (non-inherited) AD permissions only. SMTP relay and mail flow are not tested.

Supported settings: Enabled, Bindings, RemoteIPRanges, Fqdn, AuthMechanism, PermissionGroups, RequireTLS, TlsCertificateName, TlsDomainCapabilities, ProtocolLoggingLevel, MaxMessageSize, Banner, TransportRole. Explicit AD permissions are reported but not copied, except the anonymous relay permission when explicitly requested (see NOTES).

Safety
- Clone, Restore, and Merge are preview-only by default. Changes require -ApplyChanges and confirmation.
- Custom connectors are in scope by default. Built-in connectors are never created or deleted. Use -IncludeBuiltIn to align existing built-in connectors.
- Bindings of an existing target connector are never changed by Clone or cross-server Restore. A missing connector is created only when its source Bindings are valid on the target.
- MANUAL: known binding problems (such as a missing target IP or broader listener exposure) skip the affected connector. Other connectors continue.
- BLOCKER: an unknown binding check, an unavailable required TLS certificate, a connector type/name conflict, or unreadable or denied relay permissions when -IncludeAnonymousRelayPermissions is used stops the entire Apply.
- Before Apply, the target is read again and a pre-change JSON snapshot is saved in the ConfigSnapshots folder next to the script. Apply stops if the target changes after the refreshed plan is shown.
- New connectors are created disabled and enabled only after their other changes succeed. Apply stops on the first connector error, and the resulting configuration is checked after Apply.
- -OutputFile saves the plan. It does not make the run report-only: with -ApplyChanges, changes are still applied after confirmation.

Exit codes
- Review, Clone, Restore, Merge: 0 = success or preview; 1 = error, BLOCKER, drift, or verification failure (including anonymous relay verification); 2 = Apply completed but MANUAL connectors remain. A Preview can return 0 even when BLOCKER or MANUAL items are shown; review the plan.
- CheckRelay: 0 = check completed, including findings; 1 = execution error. If one server cannot be checked, the other servers are still checked and the overall exit code is 1.

.PARAMETER Server
One or more Exchange servers to review. If omitted, the local computer is used.
In Relay Configuration Check mode (-CheckRelay), required: one or more Exchange servers to check.

.PARAMETER SourceServer
In Clone mode, the Exchange server whose Receive Connector configuration is used as the source.
In Restore mode, selects the source server entry when the JSON backup contains more than one server. It is optional when the backup contains only one server.
In RemoteIPRanges Merge Only mode, the live Exchange server that hosts the source connectors.

.PARAMETER TargetServers
One or more Exchange servers that will be compared with the live source server in Clone mode.

.PARAMETER RestoreFile
Path to a JSON backup created by ExchangeReceiveConnectorManager.ps1. Supplying this parameter selects Restore mode. TXT reports are not accepted for Restore.

.PARAMETER TargetServer
Exchange server that will receive the restored configuration. Required in Restore mode.
In RemoteIPRanges Merge Only mode, the Exchange server that hosts the target connector.

.PARAMETER ConnectorName
Optional connector name or built-in connector family name to process in Clone or Restore mode. Multiple values are supported. If omitted, all in-scope connectors are evaluated.
In RemoteIPRanges Merge Only mode, required: one or more custom source connectors whose RemoteIPRanges entries are merged into the target connector.
In Relay Configuration Check mode, optional: limits the check to the named connectors or built-in connector families. If omitted, all connectors are checked.

.PARAMETER TargetConnectorName
RemoteIPRanges Merge Only mode. The existing custom Receive Connector on -TargetServer that receives the merged RemoteIPRanges entries. It is never created.

.PARAMETER RemoteIPRangesMergeOnly
Selects RemoteIPRanges Merge Only mode. Only the RemoteIPRanges of the target connector are changed, by adding entries. Required together with -TargetConnectorName.

.PARAMETER CheckRelay
Selects the read-only Relay Configuration Check mode. Required together with -Server. No Exchange configuration changes are made, and -ApplyChanges is not available in this mode.

.PARAMETER IncludeBuiltIn
Includes existing Exchange built-in Receive Connectors in Clone or Restore comparison and supported property alignment. Built-in connectors are never created or deleted.

.PARAMETER IncludeAnonymousRelayPermissions
Copies the anonymous relay permission (explicit ms-Exch-SMTP-Accept-Any-Recipient for NT AUTHORITY\ANONYMOUS LOGON) from source to target: it is added when the source has it and removed when the source does not. Other explicit Receive Connector AD permissions are reported but not copied. If an explicit Deny for this permission exists on the source or target connector, that connector is blocked.

.PARAMETER ApplyChanges
Applies the displayed Clone, Restore, or RemoteIPRanges merge plan. Without this switch, these modes are preview-only.

.PARAMETER OutputFile
In Review mode, specifies the TXT report path and also creates a JSON backup with the same base file name. The JSON file is the backup used for Restore.
In Clone, Restore, or RemoteIPRanges Merge Only mode, exports the displayed plan to a TXT file. -OutputFile does not make the run report-only: together with -ApplyChanges the plan is saved and the changes are applied after confirmation. For a report-only run, omit -ApplyChanges.
In Relay Configuration Check mode, exports the relay check report to a TXT file.

.PARAMETER NoPaging
Disables console paging.

.PARAMETER Help
Displays a short usage guide and exits.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1
Reviews Receive Connector configuration on the local server. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -Server EX01 -OutputFile C:\Temp\EX01-ReceiveConnectors.txt
Saves a TXT report and a JSON backup (C:\Temp\EX01-ReceiveConnectors.json) for EX01. Run this before a migration or server rebuild.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02
Previews cloning custom Receive Connectors from EX16-01 to EXSE01 and EXSE02. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02 -OutputFile C:\Temp\Clone-Plan.txt
Previews the clone and saves the plan to a TXT file, for example for change approval. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -ApplyChanges
Clones App Relay to EXSE01. The explicit anonymous relay AD permission is not changed. PermissionGroups, including AnonymousUsers, can still be updated.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -IncludeAnonymousRelayPermissions -ApplyChanges
Clones App Relay and aligns the explicit anonymous relay permission with the source. An explicit Deny on either connector blocks the entire Apply.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -IncludeBuiltIn
Previews custom connectors and alignment of existing built-in connectors. Built-in connectors are never created or deleted. Review the Preview carefully before using -ApplyChanges.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX16-01-ReceiveConnectors.json -TargetServer EXSE01
Previews a cross-server restore of the EX16-01 backup to EXSE01. Bindings of existing connectors stay target-specific. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\ReceiveConnectors.json -SourceServer EX16-01 -TargetServer EXSE01
Previews restoring the EX16-01 entry from a backup that contains more than one server. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX01-ReceiveConnectors.json -TargetServer EX01 -ApplyChanges
Restores supported settings to the rebuilt EX01, including Bindings when valid. Built-in connectors and the explicit anonymous relay permission require their respective switches. Other explicit AD permissions are not restored.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -ConnectorName "App Relay 1","App Relay 2" -TargetServer EXSE01 -TargetConnectorName "App Relay" -RemoteIPRangesMergeOnly
Previews adding the RemoteIPRanges of App Relay 1 and App Relay 2 to the existing App Relay connector on EXSE01. No changes are made.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -ConnectorName "App Relay 1","App Relay 2" -TargetServer EXSE01 -TargetConnectorName "App Relay" -RemoteIPRangesMergeOnly -ApplyChanges
Adds the selected IP ranges to EXSE01\App Relay. Other settings are unchanged. The added IP addresses use the target connector's existing permissions.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -CheckRelay -Server EX01,EX02
Checks relay configuration on EX01 and EX02. Read-only.

.EXAMPLE
.\ExchangeReceiveConnectorManager.ps1 -CheckRelay -Server EX01,EX02 -ConnectorName "App Relay" -OutputFile C:\Temp\RelayCheck.txt
Checks App Relay on EX01 and EX02 and saves the report to a TXT file. Read-only.

.NOTES
Author     : Ceyhun Kirmizitas
Version    : 1.1
Date       : 2026-10-29
Applies to : Exchange Server 2016, Exchange Server 2019, and Exchange Server Subscription Edition (Mailbox role)
Shell      : Windows PowerShell 5.1
Website    : https://ceyhunkirmizitas.net
GitHub     : https://github.com/Ceyhun-Kirmizitas
LinkedIn   : https://www.linkedin.com/in/ceyhun-kirmizitas/

Anonymous relay permission (-IncludeAnonymousRelayPermissions)
- The anonymous relay permission is the explicit AD Allow of ms-Exch-SMTP-Accept-Any-Recipient for NT AUTHORITY\ANONYMOUS LOGON.
- Without the switch: Clone and Restore do not copy, add, or remove this explicit permission. The target's existing explicit permission stays unchanged. -ApplyChanges alone does not change it.
- With the switch: the explicit permission is included in the plan and added or removed to match the source or backup. An explicit Deny for this permission on the source or target connector is a BLOCKER. -ApplyChanges is still required.
- PermissionGroups (including AnonymousUsers) remains a managed setting in Clone and Restore, with or without this switch. Changes to PermissionGroups can therefore affect effective anonymous relay behavior. Review the Preview before Apply.
- The switch is not required for ordinary Clone or Restore.

Restore limitations
- Restore accepts JSON backups only. Use -SourceServer when the backup contains more than one server.
- Same-server Restore includes Bindings and the other supported settings. Built-in connectors are included only with -IncludeBuiltIn. The explicit anonymous relay permission is included only with -IncludeAnonymousRelayPermissions. Other explicit AD permissions are not restored.
- Missing backup properties are treated as unavailable. Existing target values are kept, and incomplete new connectors are blocked.
- A Preview can return exit code 0 even when BLOCKER or MANUAL items are shown. Always review the plan before Apply.

Change log
----------
1.1 - 2026-10-29

New Features
- Added RemoteIPRanges Merge Only to add source IP ranges
  to an existing target connector without changing other settings.
- Added read-only -CheckRelay to review anonymous and
  externally secured relay configuration without testing mail flow.

Changes
- Clone and cross-server Restore now preserve existing target
  Bindings. Same-server Restore still manages Bindings.
- Known binding problems now mark only the affected connector
  as MANUAL. Apply returns exit code 2 when manual work remains.
- With -IncludeAnonymousRelayPermissions, an explicit Deny
  on the source or target connector now blocks Apply.
- Failed anonymous relay verification now returns exit code 1.
- The start prompt now accepts only ENTER to start or Q to quit.

Improvements
- Clearer Bindings and anonymous relay information in
  Preview and Apply results.
- Restore now identifies same-server and cross-server operations.
- Improved console colors, completion messages, help, and
  Feedback / Bugs / Contact information.

Bug Fixes
- Fixed Clone and Restore failures caused by server-specific
  Receive Connector Bindings.
- Fixed source drift checks blocking Apply when unrelated
  connectors changed while -ConnectorName was used.

1.0 - 2026-09-27

New Features
- Initial release with Receive Connector Review, Backup,
  Clone, and Restore.
- Added TXT reports, JSON backups, and explicit AD
  permission inventory.
- Added Preview-first Clone and Restore, with
  -ApplyChanges required to make changes.
- Added custom connector creation and optional alignment
  of existing built-in connectors.
- Added optional anonymous relay permission management.
- Added safety checks for Bindings, TLS certificates,
  and connector conflicts. Whole-plan BLOCKER checks stop unsafe Apply.
- Missing backup properties leave existing target values unchanged.
- Added pre-change snapshots, drift detection,
  and post-change verification.
- New connectors are configured disabled and enabled
  after successful configuration.
- Added Windows PowerShell 5.1 compatibility handling,
  startup guidance, console paging, and help.

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
    [Parameter(Mandatory = $true, ParameterSetName = 'CheckRelay')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Server,

    [Parameter(Mandatory = $true, ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Merge')]
    [ValidateNotNullOrEmpty()]
    [string]$SourceServer,

    [Parameter(Mandatory = $true, ParameterSetName = 'Clone')]
    [ValidateNotNullOrEmpty()]
    [string[]]$TargetServers,

    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')]
    [ValidateNotNullOrEmpty()]
    [string]$RestoreFile,

    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Merge')]
    [ValidateNotNullOrEmpty()]
    [string]$TargetServer,

    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Merge')]
    [Parameter(ParameterSetName = 'CheckRelay')]
    [string[]]$ConnectorName,

    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [switch]$IncludeBuiltIn,

    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [switch]$IncludeAnonymousRelayPermissions,

    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [Parameter(ParameterSetName = 'Merge')]
    [switch]$ApplyChanges,

    [Parameter(ParameterSetName = 'Review')]
    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [Parameter(ParameterSetName = 'Merge')]
    [Parameter(ParameterSetName = 'CheckRelay')]
    [string]$OutputFile,

    [Parameter(ParameterSetName = 'Review')]
    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [Parameter(ParameterSetName = 'Merge')]
    [Parameter(ParameterSetName = 'CheckRelay')]
    [switch]$NoPaging,

    [Parameter(ParameterSetName = 'Review')]
    [Parameter(ParameterSetName = 'Clone')]
    [Parameter(ParameterSetName = 'Restore')]
    [Parameter(ParameterSetName = 'Merge')]
    [Parameter(ParameterSetName = 'CheckRelay')]
    [switch]$Help,

    [Parameter(Mandatory = $true, ParameterSetName = 'Merge')]
    [ValidateNotNullOrEmpty()]
    [string]$TargetConnectorName,

    [Parameter(ParameterSetName = 'Merge')]
    [switch]$RemoteIPRangesMergeOnly,

    [Parameter(Mandatory = $true, ParameterSetName = 'CheckRelay')]
    [switch]$CheckRelay
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ToolName = 'ExchangeReceiveConnectorManager'
$script:ScriptVersion = '1.1'
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
$script:BindingMode = 'TargetSpecific'
$script:RestoreType = $null
$script:BackupContainsTargetEntry = $false

if ($Help) {
    @"
$($script:ToolName).ps1
Exchange Server Receive Connector review, backup, clone, restore, RemoteIPRanges merge, and relay check

COMMON USAGE
  Review the local server (read-only):
    .\ExchangeReceiveConnectorManager.ps1
  Back up a server (TXT report + JSON backup):
    .\ExchangeReceiveConnectorManager.ps1 -Server EX01 -OutputFile C:\Temp\EX01-ReceiveConnectors.txt
  Preview a clone:
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02
  Clone one connector (explicit anonymous relay permission not copied):
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -ApplyChanges
  Clone one connector including the explicit anonymous relay permission:
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -IncludeAnonymousRelayPermissions -ApplyChanges
  Preview a restore to another server:
    .\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX16-01-ReceiveConnectors.json -TargetServer EXSE01
  Restore to the same rebuilt server (Bindings included):
    .\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX01-ReceiveConnectors.json -TargetServer EX01 -ApplyChanges
  Preview a RemoteIPRanges merge:
    .\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -ConnectorName "App Relay 1","App Relay 2" -TargetServer EXSE01 -TargetConnectorName "App Relay" -RemoteIPRangesMergeOnly
  Check relay configuration on EX01 and EX02 (read-only):
    .\ExchangeReceiveConnectorManager.ps1 -CheckRelay -Server EX01,EX02

NOTES
  - Clone, Restore, and Merge are preview-only by default. Add -ApplyChanges after reviewing the plan.
  - Built-in connectors are never created or deleted. -IncludeBuiltIn aligns existing ones.
  - The explicit anonymous relay permission is managed only with
    -IncludeAnonymousRelayPermissions. PermissionGroups, including
    AnonymousUsers, can still change without it. With the switch,
    an explicit Deny blocks the entire Apply.
  - Existing target Bindings are preserved except during same-server Restore.
    Known binding problems mark the affected connector MANUAL;
    an unknown binding check can block Apply.
  - In Clone, Restore, and Merge, -OutputFile saves the plan.
    It does not disable -ApplyChanges.
  - Exit codes: 0 completed/preview, 1 error/BLOCKER/verification
    failure, 2 Apply completed with MANUAL items.
    Preview may return 0 even when BLOCKERs are shown.
    -CheckRelay: 0 completed (including findings), 1 error.
  - Press ENTER to start or Q to quit. Use -NoPaging to disable console paging.
  - Full help: Get-Help .\ExchangeReceiveConnectorManager.ps1 -Full
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

function ConvertTo-BindingEndpoint {
    param([AllowNull()][string]$Binding)

    # Parse one Receive Connector binding into address family, port, and scope.
    # Only valid IPv4 dotted-quad and bracketed IPv6 forms are accepted. Any
    # other form returns $null so it can never be treated as covered.
    if ([string]::IsNullOrWhiteSpace($Binding)) { return $null }
    $text = $Binding.Trim()
    $addressText = $null
    $portText = $null
    $family = $null

    if ($text -match '^\[(?<ip>[^\[\]]+)\]:(?<port>\d{1,5})$') {
        $addressText = $Matches['ip']
        $portText = $Matches['port']
        $family = 'IPv6'
    }
    elseif ($text -match '^(?<ip>\d{1,3}(?:\.\d{1,3}){3}):(?<port>\d{1,5})$') {
        $addressText = $Matches['ip']
        $portText = $Matches['port']
        $family = 'IPv4'
    }
    else {
        return $null
    }

    $port = [int]$portText
    if ($port -lt 1 -or $port -gt 65535) { return $null }

    if ($family -eq 'IPv4') {
        foreach ($octet in $addressText.Split('.')) {
            if ([int]$octet -gt 255) { return $null }
        }
    }

    $parsedAddress = $null
    if (-not [System.Net.IPAddress]::TryParse($addressText, [ref]$parsedAddress)) { return $null }
    if ($family -eq 'IPv4' -and $parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $null }
    if ($family -eq 'IPv6' -and $parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) { return $null }

    $isWildcard = if ($family -eq 'IPv4') { $parsedAddress.Equals([System.Net.IPAddress]::Any) } else { $parsedAddress.Equals([System.Net.IPAddress]::IPv6Any) }

    return [PSCustomObject]@{
        Family  = $family
        Port    = $port
        Scope   = $(if ($isWildcard) { 'Wildcard' } else { 'Specific' })
        Address = $parsedAddress.ToString().ToLowerInvariant()
    }
}

function Get-BindingExposureResult {
    param(
        $SourceBindings,
        $TargetBindings
    )

    # Compare listener exposure per address family and port. The target is
    # covered only when every target binding is within the source exposure:
    # same family and port, no wildcard where the source is IP-specific, and
    # no more specific addresses than the source. Anything that cannot be
    # parsed is NotComparable and must never be treated as covered.
    if ((Test-IsUnavailableValue -Value $SourceBindings) -or (Test-IsUnavailableValue -Value $TargetBindings)) { return 'NotComparable' }

    $sourceItems = @(Get-SafeArray -Value $SourceBindings | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $targetItems = @(Get-SafeArray -Value $TargetBindings | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($sourceItems.Count -eq 0 -or $targetItems.Count -eq 0) { return 'NotComparable' }

    $sourceEndpoints = New-Object System.Collections.ArrayList
    foreach ($item in $sourceItems) {
        $endpoint = ConvertTo-BindingEndpoint -Binding $item
        if ($null -eq $endpoint) { return 'NotComparable' }
        [void]$sourceEndpoints.Add($endpoint)
    }
    $targetEndpoints = New-Object System.Collections.ArrayList
    foreach ($item in $targetItems) {
        $endpoint = ConvertTo-BindingEndpoint -Binding $item
        if ($null -eq $endpoint) { return 'NotComparable' }
        [void]$targetEndpoints.Add($endpoint)
    }

    $sourceWildcardKeys = @{}
    $sourceSpecificAddresses = @{}
    foreach ($endpoint in $sourceEndpoints) {
        $key = '{0}:{1}' -f $endpoint.Family,$endpoint.Port
        if ($endpoint.Scope -eq 'Wildcard') {
            $sourceWildcardKeys[$key] = $true
        }
        else {
            if (-not $sourceSpecificAddresses.ContainsKey($key)) { $sourceSpecificAddresses[$key] = @{} }
            $sourceSpecificAddresses[$key][$endpoint.Address] = $true
        }
    }

    $targetSpecificAddresses = @{}
    foreach ($endpoint in $targetEndpoints) {
        $key = '{0}:{1}' -f $endpoint.Family,$endpoint.Port
        if ($sourceWildcardKeys.ContainsKey($key)) { continue }
        if (-not $sourceSpecificAddresses.ContainsKey($key)) { return 'Widening' }
        if ($endpoint.Scope -eq 'Wildcard') { return 'Widening' }
        if (-not $targetSpecificAddresses.ContainsKey($key)) { $targetSpecificAddresses[$key] = @{} }
        $targetSpecificAddresses[$key][$endpoint.Address] = $true
    }

    foreach ($key in @($targetSpecificAddresses.Keys)) {
        if ($targetSpecificAddresses[$key].Count -gt $sourceSpecificAddresses[$key].Count) { return 'Widening' }
    }

    return 'Covered'
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

function Test-AnonymousRelayDenyEntry {
    param($Connector)

    # True when the connector's explicit permission snapshot contains a Deny of
    # ms-Exch-SMTP-Accept-Any-Recipient for NT AUTHORITY\ANONYMOUS LOGON.
    if ($null -eq $Connector) { return $false }
    $permissionSnapshot = Get-ObjectPropertyValue -Object $Connector -Name 'PermissionSnapshot'
    if ($null -eq $permissionSnapshot) { return $false }
    foreach ($entry in @(Get-SafeArray -Value (Get-ObjectPropertyValue -Object $permissionSnapshot -Name 'ExplicitPermissions'))) {
        if ($null -eq $entry) { continue }
        if (([string](Get-ObjectPropertyValue -Object $entry -Name 'User')) -ine $script:AnonymousLogonPrincipal) { continue }
        if ((Get-ObjectPropertyValue -Object $entry -Name 'Deny') -ne $true) { continue }
        if (@(Get-SafeArray -Value (Get-ObjectPropertyValue -Object $entry -Name 'ExtendedRights') | Where-Object { ([string]$_) -ieq $script:AnonymousRelayRight }).Count -gt 0) { return $true }
    }
    return $false
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
    # Bindings are target-specific in Clone and cross-server Restore: an existing
    # target connector keeps its own Bindings, so its own Bindings are checked.
    # Same-server Restore manages Bindings from the backup. A missing built-in
    # connector is never created, so its Bindings are not checked.
    $bindingsManaged = ([string]$script:BindingMode -eq 'Managed')
    $targetBindings = if ($targetExists) {
        Normalize-ConnectorPropertyValue -PropertyName 'Bindings' -Value (Get-SourceConnectorValue -Connector $targetConnector -PropertyName 'Bindings')
    }
    else {
        $null
    }
    $bindingCheckInput = if ($targetExists -and -not $bindingsManaged) { $targetBindings } else { $bindings }
    $bindingStatus = if ($scopeSkipped -or (-not $targetExists -and $connectorType -ieq 'BuiltIn')) {
        'NotChecked'
    }
    else {
        Test-TargetBindingAvailability -Server $TargetSnapshot.Server -Bindings $bindingCheckInput
    }
    $bindingExposure = 'NotChecked'
    if (-not $scopeSkipped -and $targetExists -and -not $bindingsManaged) {
        $bindingExposure = Get-BindingExposureResult -SourceBindings $bindings -TargetBindings $targetBindings
    }

    $manual = $false
    $manualReason = $null
    $manualMessage = $null
    $manualAction = $null

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
    # for a Bindings property change. An unverifiable binding state (Unknown) blocks
    # the plan. A known binding problem (missing IP, broader listener exposure, or
    # Bindings that cannot be compared) skips only this connector as MANUAL, so no
    # settings, permissions, or activation are applied to it.
    if (-not $scopeSkipped -and $bindingStatus -eq 'Unknown') {
        $blocked = $true
        $canCreate = $false
        [void]$reviewNotes.Add('Required binding check: Unknown. The binding IP addresses could not be verified on the target. The entire connector is blocked; settings, permissions, and activation will not be changed.')
    }
    elseif (-not $scopeSkipped -and $bindingStatus -eq 'Missing') {
        $manual = $true
        if ($bindingsManaged) {
            $manualReason = 'BackupBindingNotOnServer'
            $manualMessage = "Backed-up Bindings contain IP addresses that do not exist on '$($TargetSnapshot.Server)'."
            $manualAction = 'Configuration required. Restore or adjust the Bindings manually, then run again.'
        }
        elseif ($targetExists) {
            $manualReason = 'StaleTargetBinding'
            $manualMessage = "Target Bindings contain IP addresses that do not exist on '$($TargetSnapshot.Server)'."
            $manualAction = 'Configuration required. Correct the target Bindings, then run again.'
        }
        else {
            $manualReason = 'SourceBindingNotOnTarget'
            $manualMessage = "Source Bindings contain IP addresses that do not exist on '$($TargetSnapshot.Server)'."
            $manualAction = "Configuration required. Create the connector on '$($TargetSnapshot.Server)' with a target IP binding (recommended -Enabled `$false), then run again."
        }
    }

    if (-not $manual -and $bindingExposure -eq 'Widening') {
        $manual = $true
        $manualReason = 'ExposureWidening'
        $manualMessage = 'Target Bindings listen more broadly than the source (wildcard instead of a specific IP, a new port, a new address family, or more IP addresses).'
        $manualAction = 'Configuration required. Review the target Bindings, then run again.'
    }
    elseif (-not $manual -and $bindingExposure -eq 'NotComparable') {
        $manual = $true
        $manualReason = 'ExposureNotComparable'
        $manualMessage = 'Source or target Bindings cannot be compared reliably.'
        $manualAction = 'Configuration required. Review the Bindings, then run again.'
    }

    if ($manual) { $canCreate = $false }

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
        elseif ($propertyName -eq 'Bindings' -and $targetExists -and -not $bindingsManaged) {
            # Target-specific: existing target Bindings are never changed.
            if ($status -eq 'Different') {
                $status = 'TargetSpecific'
                $note = 'Server-specific. Existing target Bindings are not changed.'
            }
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
            [void]$reviewNotes.Add('Source anonymous relay permission state is unavailable. The connector plan is blocked because -IncludeAnonymousRelayPermissions was specified.')
        }
        elseif ($targetExists -and $targetRelay.QueryStatus -ne 'Available') {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Target anonymous relay permission state is unavailable. The connector plan is blocked because -IncludeAnonymousRelayPermissions was specified.')
        }
        elseif (Test-AnonymousRelayDenyEntry -Connector $SourceConnector) {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Source connector has an explicit Deny of ms-Exch-SMTP-Accept-Any-Recipient for NT AUTHORITY\ANONYMOUS LOGON. The connector plan is blocked because -IncludeAnonymousRelayPermissions was specified. Resolve the Deny entry manually.')
        }
        elseif ($targetExists -and (Test-AnonymousRelayDenyEntry -Connector $targetConnector)) {
            $blocked = $true
            $canCreate = $false
            [void]$reviewNotes.Add('Target connector has an explicit Deny of ms-Exch-SMTP-Accept-Any-Recipient for NT AUTHORITY\ANONYMOUS LOGON. The connector plan is blocked because -IncludeAnonymousRelayPermissions was specified. Resolve the Deny entry manually.')
        }
    }

    # Keep the displayed plan consistent with the execution gate.
    if ($blocked -or $manual) {
        $canCreate = $false
        foreach ($comparison in $comparisons) { $comparison.Manage = $false }
    }
    $relayManage = (-not $blocked) -and (-not $manual) -and (-not $scopeSkipped) -and $IncludeAnonymousRelayPermissions -and ($relayStatus -eq 'Different') -and ($targetExists -or $canCreate)
    $bindingsPreserved = (-not $blocked) -and (-not $manual) -and (-not $scopeSkipped) -and
        (@($comparisons | Where-Object { $_.Property -eq 'Bindings' -and $_.Status -eq 'TargetSpecific' }).Count -gt 0)
    $relayNote = if (-not $IncludeAnonymousRelayPermissions) {
        'Not copied. Use -IncludeAnonymousRelayPermissions to include the source permission in the plan.'
    }
    elseif ($sourceRelay.QueryStatus -ne 'Available') {
        'Source anonymous relay permission state is unknown. The permission will not be changed.'
    }
    elseif ($targetExists -and $targetRelay.QueryStatus -ne 'Available') {
        'Target anonymous relay permission state is unknown. The permission will not be changed.'
    }
    else { $null }

    if ($sourceRelay.ExplicitPermissionCount -gt 0) {
        [void]$reviewNotes.Add("Source contains $($sourceRelay.ExplicitPermissionCount) explicit AD permission entr$(if ($sourceRelay.ExplicitPermissionCount -eq 1) { 'y' } else { 'ies' }). Only the anonymous relay permission can be copied (-IncludeAnonymousRelayPermissions).")
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
        BindingExposure = $bindingExposure
        SourceBindings  = $bindings
        TargetBindings  = $targetBindings
        Manual          = $manual
        ManualReason    = $manualReason
        ManualMessage   = $manualMessage
        ManualAction    = $manualAction
        BindingsPreserved = $bindingsPreserved
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

    if ($Plan.ScopeSkipped -or $Plan.Blocked -or $Plan.Manual) { return $false }
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
    if ($Plan.Manual) { return 'MANUAL' }
    if ($Plan.CanCreate) { return 'CREATE' }
    if (-not $Plan.TargetExists) { return 'REVIEW' }
    if (Test-PlanHasManagedChanges -Plan $Plan) { return 'UPDATE' }
    if (@($Plan.Comparisons | Where-Object { $_.Status -notin @('Same','TargetSpecific') }).Count -gt 0 -or $Plan.AnonymousRelay.Status -notin @('Same')) { return 'REVIEW' }
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
    [void]$lines.Add(("Anonymous relay : {0}" -f $(if ($IncludeAnonymousRelayPermissions) { 'Source permission included in plan (-IncludeAnonymousRelayPermissions)' } else { 'Permission will not be copied from source to target(s)' })))
    [void]$lines.Add(("Bindings  : {0}" -f $(if ([string]$script:BindingMode -eq 'Managed') { 'Restored from the backup (same-server restore)' } else { 'Target-specific (not copied to existing connectors)' })))
    if ($operation -eq 'Restore' -and $script:RestoreType) {
        [void]$lines.Add(("Restore   : {0}" -f $(if ($script:RestoreType -eq 'Same-server') { 'Same-server (Bindings included)' } else { 'Cross-server (Bindings target-specific)' })))
        if ($script:BackupContainsTargetEntry) {
            [void]$lines.Add(("REVIEW   The backup also contains an entry for '{0}'. Selected source is '{1}'. This is a cross-server restore." -f ($targetServers -join ', '),($sourceServers -join ', ')))
        }
    }
    [void]$lines.Add(("Mode      : {0} {1}" -f $operation,$(if ($ApplyChanges) { 'Apply requested' } else { 'Preview only' })))
    [void]$lines.Add('')

    foreach ($plan in @($Plans | Sort-Object TargetServer,TargetName)) {
        $planStatus = Get-PlanStatus -Plan $plan
        [void]$lines.Add(('=' * 80))
        [void]$lines.Add(("[{0}] [{1}] {2} -> {3}" -f $planStatus,$plan.TargetServer,$plan.SourceConnector.Name,$plan.TargetName))
        [void]$lines.Add(("Type          : {0}" -f $plan.ConnectorType))
        [void]$lines.Add(("Target exists : {0}" -f $plan.TargetExists))
        [void]$lines.Add(("Binding check : {0}" -f $plan.BindingStatus))
        if ($plan.BindingExposure -ne 'NotChecked') {
            [void]$lines.Add(("Exposure      : {0}" -f $plan.BindingExposure))
        }

        foreach ($item in $plan.Comparisons) {
            if ($item.Status -eq 'Same') { continue }
            $action = if ($item.Manage) { 'CHANGE' } elseif ($item.Status -eq 'TargetSpecific') { 'INFO' } else { 'REVIEW' }
            [void]$lines.Add(("{0,-8} {1}" -f $action,$item.Property))
            [void]$lines.Add(("  {0,-7}: {1}" -f $sourceValueLabel,(ConvertTo-DisplayValue -Value $item.SourceValue)))
            if ($item.Status -ne 'TargetSpecific' -and (-not (Test-EquivalentValue -Left $item.DesiredValue -Right $item.SourceValue) -or $item.ReviewNote)) {
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

        if ($plan.Manual) {
            [void]$lines.Add(("MANUAL   {0}" -f (Get-ManualMessageText -Plan $plan)))
            [void]$lines.Add(("MANUAL   {0}" -f $plan.ManualAction))
        }
        foreach ($note in $plan.ReviewNotes) { [void]$lines.Add(("REVIEW   {0}" -f $note)) }
        [void]$lines.Add('')
    }

    $statusGroups = @($Plans | Group-Object { Get-PlanStatus -Plan $_ })
    [void]$lines.Add('Summary')
    foreach ($status in @('CREATE','UPDATE','SAME','REVIEW','SKIP','MANUAL','BLOCKER')) {
        $group = @($statusGroups | Where-Object { $_.Name -eq $status })
        $count = if ($group.Count -gt 0) { $group[0].Count } else { 0 }
        [void]$lines.Add(("  {0,-7}: {1}" -f $status,$count))
    }

    foreach ($attentionLine in @(Get-BindingAttentionLines -Plans $Plans)) {
        [void]$lines.Add($attentionLine)
    }

    return @($lines)
}

function Get-ManualMessageText {
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [switch]$AfterApply
    )

    # Tense-aware MANUAL reason text. Plan and preview output describe what
    # will happen; post-Apply output describes what happened.
    $text = [string]$Plan.ManualMessage
    if ([string]$Plan.ManualReason -eq 'SourceBindingNotOnTarget') {
        $text += $(if ($AfterApply) { ' The connector was not created.' } else { ' The connector will not be created automatically.' })
    }
    return $text
}

function Get-ManualPlanCount {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans)

    return @($Plans | Where-Object { $_.Manual -and -not $_.Blocked -and -not $_.ScopeSkipped }).Count
}

function Get-BindingAttentionLines {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans,
        [AllowEmptyCollection()][array]$Verification = @(),
        [switch]$AfterApply
    )

    # One place that lists every connector needing binding-related attention:
    # MANUAL connectors (skipped) and connectors whose target Bindings were
    # preserved. "Applied" wording is used only when managed changes existed and
    # every Verification item for that connector is Verified.
    $manualPlans = @($Plans | Where-Object { $_.Manual -and -not $_.Blocked -and -not $_.ScopeSkipped } | Sort-Object TargetServer,TargetName)
    $preservedPlans = @($Plans | Where-Object { $_.BindingsPreserved } | Sort-Object TargetServer,TargetName)
    if ($manualPlans.Count -eq 0 -and $preservedPlans.Count -eq 0) { return @() }

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('')
    [void]$lines.Add('Bindings attention')
    [void]$lines.Add('------------------')

    foreach ($plan in $manualPlans) {
        $targetText = if ($plan.TargetExists) { ConvertTo-DisplayValue -Value $plan.TargetBindings } else { '<connector not created>' }
        [void]$lines.Add(("[MANUAL]    [{0}] {1}" -f $plan.TargetServer,$plan.TargetName))
        [void]$lines.Add(("  Source Bindings : {0}" -f (ConvertTo-DisplayValue -Value $plan.SourceBindings)))
        [void]$lines.Add(("  Target Bindings : {0}" -f $targetText))
        [void]$lines.Add(("  Reason          : {0}" -f (Get-ManualMessageText -Plan $plan -AfterApply:$AfterApply)))
        [void]$lines.Add(("  Action          : {0}" -f $plan.ManualAction))
    }

    foreach ($plan in $preservedPlans) {
        $changeCount = @($plan.Comparisons | Where-Object { $_.Manage -and $_.Status -ne 'Same' }).Count
        if ($plan.AnonymousRelay.Manage) { $changeCount++ }

        $otherText = if (-not $AfterApply) {
            if ($changeCount -gt 0) { '{0} change(s) planned.' -f $changeCount } else { 'no changes required.' }
        }
        elseif ($changeCount -eq 0) {
            'no changes were required.'
        }
        else {
            $items = @($Verification | Where-Object { [string]$_.Target -ieq [string]$plan.TargetServer -and [string]$_.Connector -ieq [string]$plan.TargetName })
            $notVerified = @($items | Where-Object { $_.Status -ne 'Verified' }).Count
            if ($items.Count -ge $changeCount -and $notVerified -eq 0) { 'changes applied and verified.' }
            else { 'not fully applied or verified. See Verification summary.' }
        }

        [void]$lines.Add(("[PRESERVED] [{0}] {1}" -f $plan.TargetServer,$plan.TargetName))
        [void]$lines.Add(("  Source Bindings : {0}" -f (ConvertTo-DisplayValue -Value $plan.SourceBindings)))
        [void]$lines.Add(("  Target Bindings : {0}" -f (ConvertTo-DisplayValue -Value $plan.TargetBindings)))
        [void]$lines.Add(("  Other settings  : {0}" -f $otherText))
        $preservedAction = if ($AfterApply) { 'Review. Target Bindings were preserved.' } else { 'Review. Target Bindings will be preserved.' }
        [void]$lines.Add(('  Action          : {0}' -f $preservedAction))
    }

    return @($lines)
}

function Show-BindingAttention {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans,
        [AllowEmptyCollection()][array]$Verification = @()
    )

    foreach ($line in @(Get-BindingAttentionLines -Plans $Plans -Verification $Verification -AfterApply)) {
        if ($line -match '^\[MANUAL\]') { Write-ResultHost $line -ForegroundColor Yellow }
        elseif ($line -match '^\[PRESERVED\]') { Write-ResultHost $line -ForegroundColor DarkGray }
        elseif ($line -match '^Bindings attention|^-+$') { Write-ResultHost $line -ForegroundColor Cyan }
        else { Write-ResultHost $line }
    }
}

function Show-ConnectorPlan {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans)

    # Console colors only. The line text comes unchanged from
    # Get-ConnectorPlanLines, which is also used for the TXT plan export.
    $statusColors = @{ CREATE = 'Cyan'; UPDATE = 'Cyan'; SAME = 'Green'; REVIEW = 'Yellow'; SKIP = 'DarkGray'; MANUAL = 'Yellow'; BLOCKER = 'Red' }
    $inSummary = $false
    foreach ($line in @(Get-ConnectorPlanLines -Plans $Plans)) {
        if ($line -eq 'Summary') { $inSummary = $true; Write-ResultHost $line -ForegroundColor Cyan; continue }
        if ($inSummary -and [string]::IsNullOrEmpty($line)) { $inSummary = $false }

        if ($inSummary -and $line -match '^  (CREATE|UPDATE|SAME|REVIEW|SKIP|MANUAL|BLOCKER)\s*: (\d+)$') {
            $color = if ([int]$Matches[2] -eq 0) { 'DarkGray' } else { $statusColors[$Matches[1]] }
            Write-ResultHost $line -ForegroundColor $color
            continue
        }

        $color = if ($line -match '^\[BLOCKER\]|^BLOCKER') { 'Red' }
        elseif ($line -match '^\[MANUAL\]|^MANUAL') { 'Yellow' }
        elseif ($line -match '^\[PRESERVED\]|^INFO') { 'DarkGray' }
        elseif ($line -match '^\[(CREATE|UPDATE)\]|^CHANGE') { 'Cyan' }
        elseif ($line -match '^\[SAME\]') { 'Green' }
        elseif ($line -match '^\[SKIP\]') { 'DarkGray' }
        elseif ($line -match '^\[REVIEW\]|^REVIEW') { 'Yellow' }
        elseif ($line -match '^Bindings attention$|^-+$') { 'Cyan' }
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

function Get-SelectedSourceConnectorSnapshot {
    param(
        [Parameter(Mandatory = $true)]$Snapshot,
        [string[]]$Names
    )

    # Without -ConnectorName the complete source snapshot remains the drift
    # comparison scope. With -ConnectorName only connectors matching the
    # selection (same name / built-in family matching as Select-SourceConnectors)
    # are kept, so unrelated source connectors cannot block Apply. A selected
    # connector that disappears, or a new connector that starts matching the
    # selection, changes the filtered state and is reported as drift.
    if (-not $Names) { return $Snapshot }

    $requestedNames = @($Names | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Select-Object -Unique)
    $selectedItems = New-Object System.Collections.ArrayList
    foreach ($item in @(Get-SafeArray -Value $Snapshot.Items)) {
        $itemName = [string]$item.Name
        $itemFamily = [string]$item.BuiltInFamily
        foreach ($requestedName in $requestedNames) {
            if ($itemName -ieq $requestedName -or
                (-not [string]::IsNullOrWhiteSpace($itemFamily) -and $itemFamily -ieq $requestedName)) {
                [void]$selectedItems.Add($item)
                break
            }
        }
    }

    return [PSCustomObject]@{
        Server     = [string]$Snapshot.Server
        ServerFqdn = [string]$Snapshot.ServerFqdn
        Items      = @($selectedItems)
    }
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
        Write-ResultHost '  Disable existing Receive Connector before other configuration changes' -ForegroundColor Cyan
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
        Write-ResultHost '  Add anonymous relay permission' -ForegroundColor Cyan
        Add-ADPermission -Identity $distinguishedName -User $script:AnonymousLogonPrincipal -ExtendedRights $script:AnonymousRelayRight -ErrorAction Stop | Out-Null
    }
    else {
        Write-ResultHost '  Remove anonymous relay permission' -ForegroundColor Cyan
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
            Write-ResultHost '  Enable newly created Receive Connector after all configuration changes succeed' -ForegroundColor Cyan
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
        Write-ResultHost '  Enable existing Receive Connector after all other configuration changes succeed' -ForegroundColor Cyan
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
        Write-ResultHost 'No configuration changes required verification.' -ForegroundColor Green
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
            # One label width for every field in the connector block. The width
            # fits the longest label (TlsDomainCapabilities). Console only.
            $fieldFormat = '{0,-21} : {1}'
            Write-ResultHost ($fieldFormat -f 'Connector', $connector.Name) -ForegroundColor Yellow
            Write-ResultHost ($fieldFormat -f 'Identity', $connector.Identity)
            Write-ResultHost ($fieldFormat -f 'Type', $connector.ConnectorType)
            if ($connector.BuiltInFamily) {
                Write-ResultHost ($fieldFormat -f 'Built-in Family', $connector.BuiltInFamily)
            }

            foreach ($propertyName in $script:ConnectorPropertyNames) {
                Write-ResultHost ($fieldFormat -f $propertyName, (ConvertTo-DisplayValue -Value $connector.Values[$propertyName]))
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

            Write-ResultHost ($fieldFormat -f 'Anonymous Relay', $relayText)
            Write-ResultHost ($fieldFormat -f 'Explicit AD Perms', @($connector.PermissionSnapshot.ExplicitPermissions).Count)

            if ($connector.PermissionSnapshot.Error) {
                Write-ResultHost ($fieldFormat -f 'Permission Error', $connector.PermissionSnapshot.Error) -ForegroundColor Yellow
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
# RemoteIPRanges merge (RemoteIPRanges Merge Only mode)
# ---------------------------------------------------------------------------
# Dedicated merge path. It never calls the Clone / Restore plan or apply
# functions and changes only the RemoteIPRanges of one existing target
# connector, by adding entries. Existing entries are never removed.
$script:MergeEntryLimit = 1200
$script:MergeEntryWarning = 1000
$script:MergeExtendedExcludedProperties = @(
    'RemoteIPRanges',
    'WhenChanged',
    'WhenChangedUTC',
    'OriginatingServer',
    'RunspaceId',
    'PSComputerName',
    'PSShowComputerName',
    'PSSourceJobInstanceId',
    'ObjectState',
    'IsValid'
)

function ConvertTo-MergeIPAddress {
    param([AllowNull()][string]$Text)

    # Strict address parsing: dotted-quad IPv4 with octets <= 255, or IPv6.
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $value = $Text.Trim()
    $family = $null
    if ($value -match '^\d{1,3}(?:\.\d{1,3}){3}$') {
        foreach ($octet in $value.Split('.')) {
            # Leading zeros are ambiguous (octal in some parsers) and rejected.
            if ($octet.Length -gt 1 -and $octet.StartsWith('0')) { return $null }
            if ([int]$octet -gt 255) { return $null }
        }
        $family = 'IPv4'
    }
    elseif ($value.Contains(':')) {
        $family = 'IPv6'
    }
    else {
        return $null
    }

    $parsedAddress = $null
    if (-not [System.Net.IPAddress]::TryParse($value, [ref]$parsedAddress)) { return $null }
    if ($family -eq 'IPv4' -and $parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $null }
    if ($family -eq 'IPv6' -and $parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) { return $null }

    return [PSCustomObject]@{
        Family = $family
        Bytes  = [byte[]]$parsedAddress.GetAddressBytes()
    }
}

function Compare-MergeAddressBytes {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Left,
        [Parameter(Mandatory = $true)][byte[]]$Right
    )

    for ($index = 0; $index -lt $Left.Length; $index++) {
        if ($Left[$index] -lt $Right[$index]) { return -1 }
        if ($Left[$index] -gt $Right[$index]) { return 1 }
    }
    return 0
}

function ConvertTo-RemoteIPRangeBounds {
    param([AllowNull()][string]$Entry)

    # Normalizes one RemoteIPRanges entry (single address, start-end range,
    # CIDR, or address(netmask)) to family and lower/upper address bytes.
    # Anything that cannot be parsed returns $null.
    if ([string]::IsNullOrWhiteSpace($Entry)) { return $null }
    $text = $Entry.Trim()
    $family = $null
    $lowerBytes = $null
    $upperBytes = $null
    $addressText = $null
    $prefix = -1

    if ($text -match '^(?<addr>[^/()\-]+)/(?<prefix>\d{1,3})$') {
        $addressText = $Matches['addr']
        $prefix = [int]$Matches['prefix']
    }
    elseif ($text -match '^(?<addr>[^/()\-]+)\((?<mask>[^/()\-]+)\)$') {
        $addressText = $Matches['addr']
        $mask = ConvertTo-MergeIPAddress -Text $Matches['mask']
        if ($null -eq $mask -or $mask.Family -ne 'IPv4') { return $null }
        $prefix = 0
        $seenZero = $false
        foreach ($maskByte in $mask.Bytes) {
            for ($bit = 7; $bit -ge 0; $bit--) {
                if (($maskByte -band (1 -shl $bit)) -ne 0) {
                    if ($seenZero) { return $null }
                    $prefix++
                }
                else {
                    $seenZero = $true
                }
            }
        }
    }

    if ($null -ne $addressText) {
        $address = ConvertTo-MergeIPAddress -Text $addressText
        if ($null -eq $address) { return $null }
        $bitCount = $address.Bytes.Length * 8
        if ($prefix -lt 0 -or $prefix -gt $bitCount) { return $null }
        $family = $address.Family
        $lowerBytes = New-Object byte[] $address.Bytes.Length
        $upperBytes = New-Object byte[] $address.Bytes.Length
        for ($index = 0; $index -lt $address.Bytes.Length; $index++) {
            $bitsInByte = [Math]::Max(0, [Math]::Min(8, $prefix - ($index * 8)))
            $byteMask = if ($bitsInByte -eq 0) { 0 } else { (0xFF -shl (8 - $bitsInByte)) -band 0xFF }
            $lowerBytes[$index] = [byte]($address.Bytes[$index] -band $byteMask)
            $upperBytes[$index] = [byte](($address.Bytes[$index] -band $byteMask) -bor ((-bnot $byteMask) -band 0xFF))
        }
    }
    elseif ($text -match '^(?<low>[^/()\-]+)-(?<high>[^/()\-]+)$') {
        $low = ConvertTo-MergeIPAddress -Text $Matches['low']
        $high = ConvertTo-MergeIPAddress -Text $Matches['high']
        if ($null -eq $low -or $null -eq $high -or $low.Family -ne $high.Family) { return $null }
        if ((Compare-MergeAddressBytes -Left $low.Bytes -Right $high.Bytes) -gt 0) { return $null }
        $family = $low.Family
        $lowerBytes = $low.Bytes
        $upperBytes = $high.Bytes
    }
    else {
        $single = ConvertTo-MergeIPAddress -Text $text
        if ($null -eq $single) { return $null }
        $family = $single.Family
        $lowerBytes = [byte[]]$single.Bytes.Clone()
        $upperBytes = [byte[]]$single.Bytes.Clone()
    }

    return [PSCustomObject]@{
        Text   = $text
        Family = $family
        Lower  = [byte[]]$lowerBytes
        Upper  = [byte[]]$upperBytes
        Key    = '{0}|{1}|{2}' -f $family,[System.BitConverter]::ToString([byte[]]$lowerBytes),[System.BitConverter]::ToString([byte[]]$upperBytes)
    }
}

function Get-RemoteIPRangeRelation {
    param(
        [Parameter(Mandatory = $true)]$Left,
        [Parameter(Mandatory = $true)]$Right
    )

    # Relation of Left to Right: Disjoint, Equal, Inside (Left strictly
    # inside Right), Contains (Left strictly contains Right), Partial, or
    # DifferentFamily.
    if ([string]$Left.Family -ne [string]$Right.Family) { return 'DifferentFamily' }
    if ((Compare-MergeAddressBytes -Left $Left.Lower -Right $Right.Upper) -gt 0) { return 'Disjoint' }
    if ((Compare-MergeAddressBytes -Left $Right.Lower -Right $Left.Upper) -gt 0) { return 'Disjoint' }

    $lowerCompare = Compare-MergeAddressBytes -Left $Left.Lower -Right $Right.Lower
    $upperCompare = Compare-MergeAddressBytes -Left $Left.Upper -Right $Right.Upper
    if ($lowerCompare -eq 0 -and $upperCompare -eq 0) { return 'Equal' }
    if ($lowerCompare -ge 0 -and $upperCompare -le 0) { return 'Inside' }
    if ($lowerCompare -le 0 -and $upperCompare -ge 0) { return 'Contains' }
    return 'Partial'
}

function Test-AllAddressRange {
    param([Parameter(Mandatory = $true)]$Bounds)

    foreach ($value in $Bounds.Lower) { if ($value -ne 0) { return $false } }
    foreach ($value in $Bounds.Upper) { if ($value -ne 255) { return $false } }
    return $true
}

function Test-WideRemoteIPRange {
    param([Parameter(Mandatory = $true)]$Bounds)

    # IPv4: more than 256 addresses. IPv6: spans more than one /64.
    if ($Bounds.Family -eq 'IPv4') {
        $lowValue = ([uint64]$Bounds.Lower[0] * 16777216) + ([uint64]$Bounds.Lower[1] * 65536) + ([uint64]$Bounds.Lower[2] * 256) + [uint64]$Bounds.Lower[3]
        $highValue = ([uint64]$Bounds.Upper[0] * 16777216) + ([uint64]$Bounds.Upper[1] * 65536) + ([uint64]$Bounds.Upper[2] * 256) + [uint64]$Bounds.Upper[3]
        return (($highValue - $lowValue + 1) -gt 256)
    }
    for ($index = 0; $index -lt 8; $index++) {
        if ($Bounds.Lower[$index] -ne $Bounds.Upper[$index]) { return $true }
    }
    return $false
}

function Get-MergeBindingEndpoints {
    param($Connector)

    # Returns @{ Valid = bool; Endpoints = list }.
    $values = Get-SourceConnectorValue -Connector $Connector -PropertyName 'Bindings'
    if (Test-IsUnavailableValue -Value $values) { return [PSCustomObject]@{ Valid = $false; Endpoints = @() } }
    $items = @(Get-SafeArray -Value $values | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($items.Count -eq 0) { return [PSCustomObject]@{ Valid = $false; Endpoints = @() } }
    $endpoints = New-Object System.Collections.ArrayList
    foreach ($item in $items) {
        $endpoint = ConvertTo-BindingEndpoint -Binding $item
        if ($null -eq $endpoint) { return [PSCustomObject]@{ Valid = $false; Endpoints = @() } }
        [void]$endpoints.Add($endpoint)
    }
    return [PSCustomObject]@{ Valid = $true; Endpoints = @($endpoints) }
}

function Test-ListenerRelevance {
    param(
        [AllowEmptyCollection()][array]$TargetEndpoints = @(),
        [AllowEmptyCollection()][array]$OtherEndpoints = @()
    )

    # Two connectors share a listener when a binding of each uses the same
    # address family and port and overlapping local addresses.
    $relevant = $false
    $identical = $false
    $identicalText = $null
    foreach ($targetEndpoint in $TargetEndpoints) {
        foreach ($otherEndpoint in $OtherEndpoints) {
            if ($targetEndpoint.Family -ne $otherEndpoint.Family -or $targetEndpoint.Port -ne $otherEndpoint.Port) { continue }
            if ($targetEndpoint.Scope -eq 'Wildcard' -or $otherEndpoint.Scope -eq 'Wildcard' -or $targetEndpoint.Address -eq $otherEndpoint.Address) {
                $relevant = $true
                if ($targetEndpoint.Scope -eq $otherEndpoint.Scope -and $targetEndpoint.Address -eq $otherEndpoint.Address) {
                    $identical = $true
                    $identicalText = if ($targetEndpoint.Family -eq 'IPv6') { '[{0}]:{1}' -f $targetEndpoint.Address,$targetEndpoint.Port } else { '{0}:{1}' -f $targetEndpoint.Address,$targetEndpoint.Port }
                }
            }
        }
    }
    return [PSCustomObject]@{ Relevant = $relevant; Identical = $identical; IdenticalBinding = $identicalText }
}

function Get-MergePermissionQueryStatus {
    param($Connector)

    # Explicit AD permission snapshot status of one connector. Anything other
    # than 'Available' means the permissions could not be read.
    $snapshot = Get-ObjectPropertyValue -Object $Connector -Name 'PermissionSnapshot'
    if ($null -eq $snapshot) { return 'Unknown' }
    $status = Get-ObjectPropertyValue -Object $snapshot -Name 'QueryStatus'
    if ([string]::IsNullOrWhiteSpace([string]$status)) { return 'Unknown' }
    return [string]$status
}

function Get-RemoteIPRangeOverlapFindings {
    param(
        [Parameter(Mandatory = $true)]$TargetSnapshot,
        [Parameter(Mandatory = $true)]$TargetConnector,
        [AllowEmptyCollection()][array]$AddItems = @()
    )

    # Listener-aware overlap validation against the other connectors on the
    # target server. Messages describe the pairwise relation only; they do
    # not state which connector finally accepts a connection.
    $findings = New-Object System.Collections.ArrayList
    $targetBindings = Get-MergeBindingEndpoints -Connector $TargetConnector
    if (-not $targetBindings.Valid) {
        [void]$findings.Add([PSCustomObject]@{ Level = 'BLOCKER'; Message = ("The Bindings of target connector '{0}' cannot be evaluated. Listener overlap cannot be checked." -f $TargetConnector.Name) })
        return @($findings)
    }

    foreach ($other in @($TargetSnapshot.Items | Where-Object { [string]$_.Name -ine [string]$TargetConnector.Name } | Sort-Object Name)) {
        $otherBindings = Get-MergeBindingEndpoints -Connector $other
        if (-not $otherBindings.Valid) {
            [void]$findings.Add([PSCustomObject]@{ Level = 'BLOCKER'; Message = ("The Bindings of connector '{0}' on '{1}' cannot be evaluated. Listener overlap cannot be checked." -f $other.Name,$TargetSnapshot.Server) })
            continue
        }
        $relevance = Test-ListenerRelevance -TargetEndpoints $targetBindings.Endpoints -OtherEndpoints $otherBindings.Endpoints
        if (-not $relevance.Relevant) { continue }

        $otherRangeValues = Get-SourceConnectorValue -Connector $other -PropertyName 'RemoteIPRanges'
        if (Test-IsUnavailableValue -Value $otherRangeValues) {
            [void]$findings.Add([PSCustomObject]@{ Level = 'BLOCKER'; Message = ("RemoteIPRanges of connector '{0}' (shared listener) were not returned. Overlap cannot be checked." -f $other.Name) })
            continue
        }
        $otherBounds = New-Object System.Collections.ArrayList
        $otherParseFailed = $false
        foreach ($rangeText in @(Get-SafeArray -Value $otherRangeValues | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $bounds = ConvertTo-RemoteIPRangeBounds -Entry $rangeText
            if ($null -eq $bounds) { $otherParseFailed = $true; break }
            [void]$otherBounds.Add($bounds)
        }
        if ($otherParseFailed) {
            [void]$findings.Add([PSCustomObject]@{ Level = 'BLOCKER'; Message = ("RemoteIPRanges of connector '{0}' (shared listener) cannot be parsed. Overlap cannot be checked." -f $other.Name) })
            continue
        }

        foreach ($addItem in $AddItems) {
            foreach ($otherRange in $otherBounds) {
                $relation = Get-RemoteIPRangeRelation -Left $addItem.Bounds -Right $otherRange
                switch ($relation) {
                    'Equal' {
                        if ($relevance.Identical) {
                            [void]$findings.Add([PSCustomObject]@{ Level = 'BLOCKER'; Message = ("{0}: the same remote range ({1}) exists on '{2}', which uses an identical binding ({3}). Exchange requires a unique combination of bindings and remote IP ranges." -f $addItem.Entry,$otherRange.Text,$other.Name,$relevance.IdenticalBinding) })
                        }
                        else {
                            [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = ("{0}: the same remote range ({1}) exists on '{2}' with an overlapping but different binding. Which connector accepts these connections depends on the local bindings; validate before use." -f $addItem.Entry,$otherRange.Text,$other.Name) })
                        }
                    }
                    'Inside' {
                        [void]$findings.Add([PSCustomObject]@{ Level = 'INFO'; Message = ("{0} is inside range {1} of '{2}' (shared listener). Exchange prefers the most specific remote range match; final connector selection also depends on all other connectors and bindings." -f $addItem.Entry,$otherRange.Text,$other.Name) })
                    }
                    'Contains' {
                        [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = ("'{0}' has a more specific range {1} inside {2} (shared listener). Connections from {1} may continue to use '{0}'." -f $other.Name,$otherRange.Text,$addItem.Entry) })
                    }
                    'Partial' {
                        [void]$findings.Add([PSCustomObject]@{ Level = 'BLOCKER'; Message = ("{0} partially overlaps {1} of '{2}' (shared listener). Partially overlapping remote ranges on connectors that share a listener are not supported." -f $addItem.Entry,$otherRange.Text,$other.Name) })
                    }
                    default { }
                }
            }
        }
    }
    return @($findings)
}

function New-RemoteIPRangeMergePlan {
    param(
        [Parameter(Mandatory = $true)]$SourceSnapshot,
        [Parameter(Mandatory = $true)][string[]]$SourceNames,
        [Parameter(Mandatory = $true)]$TargetSnapshot,
        [Parameter(Mandatory = $true)][string]$TargetName
    )

    $blockers = New-Object System.Collections.ArrayList
    $warnings = New-Object System.Collections.ArrayList
    $sourceEntries = New-Object System.Collections.ArrayList
    $selectedSources = New-Object System.Collections.ArrayList

    # Source connectors: same name / built-in family matching as Clone.
    $requestedNames = @($SourceNames | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Select-Object -Unique)
    foreach ($requestedName in $requestedNames) {
        $found = @($SourceSnapshot.Items | Where-Object {
            ([string]$_.Name) -ieq $requestedName -or
            (-not [string]::IsNullOrWhiteSpace([string]$_.BuiltInFamily) -and ([string]$_.BuiltInFamily) -ieq $requestedName)
        })
        if ($found.Count -eq 0) {
            [void]$blockers.Add(("Source connector '{0}' was not found on '{1}'." -f $requestedName,$SourceSnapshot.Server))
            continue
        }
        foreach ($sourceConnector in $found) {
            if (@($selectedSources | Where-Object { ([string]$_.Name) -ieq ([string]$sourceConnector.Name) }).Count -gt 0) { continue }
            if ([string]$sourceConnector.ConnectorType -ieq 'BuiltIn') {
                [void]$blockers.Add(("Source connector '{0}' is a built-in connector. Built-in connectors cannot be used as merge sources." -f $sourceConnector.Name))
                continue
            }
            [void]$selectedSources.Add($sourceConnector)
        }
    }

    # Target connector: must exist and be custom. Never created.
    $targetMatches = @($TargetSnapshot.Items | Where-Object { ([string]$_.Name) -ieq $TargetName })
    $targetConnector = if ($targetMatches.Count -gt 0) { $targetMatches[0] } else { $null }
    $targetExists = $null -ne $targetConnector
    if (-not $targetExists) {
        [void]$blockers.Add(("Target connector '{0}' was not found on '{1}'. RemoteIPRanges Merge Only never creates connectors." -f $TargetName,$TargetSnapshot.Server))
    }
    elseif ([string]$targetConnector.ConnectorType -ieq 'BuiltIn') {
        [void]$blockers.Add(("Target connector '{0}' is a built-in connector. Built-in connectors cannot be used as the merge target." -f $targetConnector.Name))
    }
    if ($targetExists -and ([string]$SourceSnapshot.Server -ieq [string]$TargetSnapshot.Server) -and
        @($selectedSources | Where-Object { ([string]$_.Name) -ieq ([string]$targetConnector.Name) }).Count -gt 0) {
        [void]$blockers.Add(("Target connector '{0}' is also selected as a source connector." -f $targetConnector.Name))
    }

    # Existing target entries.
    $existingEntries = New-Object System.Collections.ArrayList
    $existingBounds = New-Object System.Collections.ArrayList
    $targetRangesValid = $false
    if ($targetExists) {
        $targetRangeValues = Get-SourceConnectorValue -Connector $targetConnector -PropertyName 'RemoteIPRanges'
        if (Test-IsUnavailableValue -Value $targetRangeValues) {
            [void]$blockers.Add(("RemoteIPRanges of target connector '{0}' were not returned." -f $targetConnector.Name))
        }
        else {
            $targetRangesValid = $true
            foreach ($rangeText in @(Get-SafeArray -Value $targetRangeValues | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                [void]$existingEntries.Add($rangeText)
                $bounds = ConvertTo-RemoteIPRangeBounds -Entry $rangeText
                if ($null -eq $bounds) {
                    $targetRangesValid = $false
                    [void]$blockers.Add(("Target RemoteIPRanges entry '{0}' cannot be parsed." -f $rangeText))
                }
                else {
                    [void]$existingBounds.Add($bounds)
                }
            }
        }
    }

    # Source entries.
    foreach ($sourceConnector in $selectedSources) {
        $sourceRangeValues = Get-SourceConnectorValue -Connector $sourceConnector -PropertyName 'RemoteIPRanges'
        if (Test-IsUnavailableValue -Value $sourceRangeValues) {
            [void]$blockers.Add(("RemoteIPRanges of source connector '{0}' were not returned." -f $sourceConnector.Name))
            continue
        }
        foreach ($rangeText in @(Get-SafeArray -Value $sourceRangeValues | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $bounds = ConvertTo-RemoteIPRangeBounds -Entry $rangeText
            if ($null -eq $bounds) {
                [void]$blockers.Add(("Source RemoteIPRanges entry '{0}' of '{1}' cannot be parsed." -f $rangeText,$sourceConnector.Name))
                continue
            }
            if (Test-AllAddressRange -Bounds $bounds) {
                [void]$blockers.Add(("Source RemoteIPRanges entry '{0}' of '{1}' covers all addresses and cannot be merged." -f $rangeText,$sourceConnector.Name))
                continue
            }
            [void]$sourceEntries.Add([PSCustomObject]@{ Connector = [string]$sourceConnector.Name; Entry = $rangeText; Bounds = $bounds })
        }
    }

    # Merge: equal or contained entries are not added; duplicates once.
    $toAdd = New-Object System.Collections.ArrayList
    $notAdded = New-Object System.Collections.ArrayList
    foreach ($sourceEntry in $sourceEntries) {
        $reason = $null
        foreach ($existing in $existingBounds) {
            if ((Get-RemoteIPRangeRelation -Left $sourceEntry.Bounds -Right $existing) -eq 'Equal') {
                $reason = "Already present (target entry {0})" -f $existing.Text
                break
            }
        }
        if (-not $reason) {
            foreach ($existing in $existingBounds) {
                if ((Get-RemoteIPRangeRelation -Left $sourceEntry.Bounds -Right $existing) -eq 'Inside') {
                    $reason = "Already covered by target entry {0}" -f $existing.Text
                    break
                }
            }
        }

        if ($reason) {
            $known = @($notAdded | Where-Object { $_.Key -eq $sourceEntry.Bounds.Key })
            if ($known.Count -gt 0) {
                if (-not ($known[0].Sources -contains $sourceEntry.Connector)) { [void]$known[0].Sources.Add($sourceEntry.Connector) }
            }
            else {
                $sources = New-Object System.Collections.ArrayList
                [void]$sources.Add($sourceEntry.Connector)
                [void]$notAdded.Add([PSCustomObject]@{ Entry = $sourceEntry.Entry; Key = $sourceEntry.Bounds.Key; Sources = $sources; Reason = $reason })
            }
            continue
        }

        $pending = @($toAdd | Where-Object { $_.Bounds.Key -eq $sourceEntry.Bounds.Key })
        if ($pending.Count -gt 0) {
            if (-not ($pending[0].Sources -contains $sourceEntry.Connector)) { [void]$pending[0].Sources.Add($sourceEntry.Connector) }
            continue
        }
        $sources = New-Object System.Collections.ArrayList
        [void]$sources.Add($sourceEntry.Connector)
        [void]$toAdd.Add([PSCustomObject]@{ Entry = $sourceEntry.Entry; Bounds = $sourceEntry.Bounds; Sources = $sources })
    }

    $existingCount = $existingEntries.Count
    $addCount = $toAdd.Count
    $projectedCount = $existingCount + $addCount
    if ($projectedCount -gt $script:MergeEntryLimit) {
        [void]$blockers.Add(("Projected RemoteIPRanges entry count {0} exceeds the safe limit of {1} entries (Exchange administrative limit about 1,200-1,300). Use ranges or CIDR entries, or another connector." -f $projectedCount,$script:MergeEntryLimit))
    }
    elseif ($addCount -gt 0 -and $projectedCount -ge $script:MergeEntryWarning) {
        [void]$warnings.Add(("Projected RemoteIPRanges entry count {0} is close to the Exchange administrative limit (about 1,200-1,300 entries). Consider ranges or CIDR entries." -f $projectedCount))
    }

    if ($addCount -gt 0) {
        [void]$warnings.Insert(0, ("Newly added IP addresses inherit the existing access of '{0}'. No permissions or other settings are changed by this operation." -f $TargetName))
        foreach ($item in $toAdd) {
            if (Test-WideRemoteIPRange -Bounds $item.Bounds) {
                [void]$warnings.Add(("{0} is a wide range (more than 256 IPv4 addresses or more than one IPv6 /64)." -f $item.Entry))
            }
        }
    }
    $targetEnabled = $null
    if ($targetExists) {
        $enabledValue = Get-SourceConnectorValue -Connector $targetConnector -PropertyName 'Enabled'
        if (-not (Test-IsUnavailableValue -Value $enabledValue) -and $null -ne $enabledValue) {
            try { $targetEnabled = ConvertTo-StrictBoolean -Value $enabledValue } catch { $targetEnabled = $null }
        }
        if ($addCount -gt 0 -and $targetEnabled -eq $false) {
            [void]$warnings.Add(("Target connector '{0}' is disabled. The change is applied, but has no effect until the connector is enabled." -f $TargetName))
        }
    }

    # Permission snapshots of every connector on the target server are
    # required to verify after Apply that permissions remain unchanged.
    if ($targetExists -and $addCount -gt 0) {
        foreach ($connector in @($TargetSnapshot.Items | Sort-Object Name)) {
            $permissionStatus = Get-MergePermissionQueryStatus -Connector $connector
            if ($permissionStatus -ne 'Available') {
                [void]$blockers.Add(("Explicit AD permissions of connector '{0}' on '{1}' could not be read (QueryStatus {2}). Unchanged permissions cannot be verified after Apply." -f $connector.Name,$TargetSnapshot.Server,$permissionStatus))
            }
        }
    }

    $findings = @()
    if ($targetExists -and $targetRangesValid -and $addCount -gt 0 -and [string]$targetConnector.ConnectorType -ine 'BuiltIn') {
        $findings = @(Get-RemoteIPRangeOverlapFindings -TargetSnapshot $TargetSnapshot -TargetConnector $targetConnector -AddItems @($toAdd))
        foreach ($finding in @($findings | Where-Object { $_.Level -eq 'BLOCKER' })) {
            [void]$blockers.Add($finding.Message)
        }
    }

    $finalEntries = New-Object System.Collections.ArrayList
    foreach ($entry in $existingEntries) { [void]$finalEntries.Add($entry) }
    foreach ($item in $toAdd) { [void]$finalEntries.Add($item.Entry) }

    $status = if ($blockers.Count -gt 0) { 'BLOCKER' } elseif ($addCount -eq 0) { 'SAME' } else { 'UPDATE' }

    return [PSCustomObject]@{
        SourceServer     = [string]$SourceSnapshot.Server
        SourceNames      = @($selectedSources | ForEach-Object { [string]$_.Name })
        SourceEntries    = @($sourceEntries)
        TargetServer     = [string]$TargetSnapshot.Server
        TargetName       = $TargetName
        TargetExists     = $targetExists
        TargetIdentity   = $(if ($targetExists) { [string]$targetConnector.Identity } else { $null })
        TargetEnabled    = $targetEnabled
        ExistingEntries  = @($existingEntries)
        ExistingBounds   = @($existingBounds)
        ToAdd            = @($toAdd)
        NotAdded         = @($notAdded)
        FinalEntries     = @($finalEntries)
        ExistingCount    = $existingCount
        AddCount         = $addCount
        ProjectedCount   = $projectedCount
        Findings         = @($findings)
        Warnings         = @($warnings)
        Blockers         = @($blockers)
        Status           = $status
    }
}

function Get-RemoteIPRangeMergeLines {
    param([Parameter(Mandatory = $true)]$Plan)

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add(("{0}.ps1 v{1} - RemoteIPRanges merge plan" -f $script:ToolName,$script:ScriptVersion))
    [void]$lines.Add(("Generated : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    [void]$lines.Add(("Mode      : RemoteIPRanges Merge Only - {0}" -f $(if ($ApplyChanges) { 'Apply requested' } else { 'Preview only' })))
    [void]$lines.Add('Changes   : RemoteIPRanges ONLY')
    [void]$lines.Add(("Source    : {0} ({1})" -f $Plan.SourceServer,(@($Plan.SourceNames) -join ', ')))
    [void]$lines.Add(("Target    : {0}\{1}" -f $Plan.TargetServer,$Plan.TargetName))
    [void]$lines.Add('')
    [void]$lines.Add(('=' * 80))
    [void]$lines.Add(("[{0}] [{1}] {2}" -f $Plan.Status,$Plan.TargetServer,$Plan.TargetName))

    [void]$lines.Add('Source entries')
    if (@($Plan.SourceEntries).Count -eq 0) { [void]$lines.Add('  <none>') }
    foreach ($sourceEntry in $Plan.SourceEntries) { [void]$lines.Add(("  [{0}] {1}" -f $sourceEntry.Connector,$sourceEntry.Entry)) }

    [void]$lines.Add(("Target existing entries ({0})" -f $Plan.ExistingCount))
    if ($Plan.ExistingCount -eq 0) { [void]$lines.Add('  <none>') }
    foreach ($entry in $Plan.ExistingEntries) { [void]$lines.Add(("  {0}" -f $entry)) }

    [void]$lines.Add(("Entries to add ({0})" -f $Plan.AddCount))
    if ($Plan.AddCount -eq 0) { [void]$lines.Add('  <none>') }
    foreach ($item in $Plan.ToAdd) { [void]$lines.Add(("ADD      {0}  (from {1})" -f $item.Entry,(@($item.Sources) -join ', '))) }

    if (@($Plan.NotAdded).Count -gt 0) {
        [void]$lines.Add(("Not added ({0})" -f @($Plan.NotAdded).Count))
        foreach ($item in $Plan.NotAdded) { [void]$lines.Add(("SKIP     {0}  (from {1}) - {2}" -f $item.Entry,(@($item.Sources) -join ', '),$item.Reason)) }
    }

    if ($Plan.TargetExists -and $Plan.Status -ne 'BLOCKER') {
        [void]$lines.Add(("Final combined list ({0})" -f $Plan.ProjectedCount))
        foreach ($entry in $Plan.FinalEntries) { [void]$lines.Add(("  {0}" -f $entry)) }
    }

    [void]$lines.Add(("Entry count : existing {0}, add {1}, projected {2} (safe limit {3})" -f $Plan.ExistingCount,$Plan.AddCount,$Plan.ProjectedCount,$script:MergeEntryLimit))

    $nonBlockingFindings = @($Plan.Findings | Where-Object { $_.Level -ne 'BLOCKER' })
    if ($nonBlockingFindings.Count -gt 0) {
        [void]$lines.Add('Overlap with other connectors on the target server')
        foreach ($finding in $nonBlockingFindings) { [void]$lines.Add(("{0,-8} {1}" -f $finding.Level,$finding.Message)) }
    }
    foreach ($warning in $Plan.Warnings) { [void]$lines.Add(("REVIEW   {0}" -f $warning)) }
    foreach ($blocker in $Plan.Blockers) { [void]$lines.Add(("BLOCKER  {0}" -f $blocker)) }

    [void]$lines.Add('')
    [void]$lines.Add('Summary')
    [void]$lines.Add(("  Status : {0}" -f $Plan.Status))
    [void]$lines.Add(("  Add    : {0}" -f $Plan.AddCount))
    [void]$lines.Add(("  Skip   : {0}" -f @($Plan.NotAdded).Count))
    return @($lines)
}

function Show-RemoteIPRangeMergePlan {
    param([Parameter(Mandatory = $true)]$Plan)

    # Console colors only. The line text comes unchanged from
    # Get-RemoteIPRangeMergeLines, which is also used for the TXT plan export.
    $statusColors = @{ CREATE = 'Cyan'; UPDATE = 'Cyan'; SAME = 'Green'; REVIEW = 'Yellow'; SKIP = 'DarkGray'; MANUAL = 'Yellow'; BLOCKER = 'Red' }
    $inSummary = $false
    foreach ($line in @(Get-RemoteIPRangeMergeLines -Plan $Plan)) {
        if ($line -eq 'Summary') { $inSummary = $true; Write-ResultHost $line -ForegroundColor Cyan; continue }

        if ($inSummary) {
            $color = if ($line -match '^  Status : (\S+)$' -and $statusColors.ContainsKey($Matches[1])) { $statusColors[$Matches[1]] }
            elseif ($line -match '^  Add    : (\d+)$') { if ([int]$Matches[1] -eq 0) { 'DarkGray' } else { 'Cyan' } }
            elseif ($line -match '^  Skip   : (\d+)$') { 'DarkGray' }
            else { $null }
        }
        else {
            $color = if ($line -match '^\[BLOCKER\]|^BLOCKER') { 'Red' }
            elseif ($line -match '^\[UPDATE\]|^ADD') { 'Cyan' }
            elseif ($line -match '^\[SAME\]') { 'Green' }
            elseif ($line -match '^REVIEW') { 'Yellow' }
            elseif ($line -match '^INFO|^SKIP') { 'DarkGray' }
            else { $null }
        }

        if ($color) { Write-ResultHost $line -ForegroundColor $color } else { Write-ResultHost $line }
    }
}

function Export-RemoteIPRangeMergePlan {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Plan
    )

    $resolved = Resolve-TextOutputPath -Path $Path
    Set-Content -LiteralPath $resolved -Value @(Get-RemoteIPRangeMergeLines -Plan $Plan) -Encoding UTF8 -ErrorAction Stop
    return $resolved
}

function ConvertTo-MergeComparableText {
    param($Value)

    if ($null -eq $Value) { return '<null>' }
    if ($Value -is [string]) { return $Value }
    if ($Value -is [System.Collections.IEnumerable]) {
        return ((@($Value | ForEach-Object { [string]$_ }) | Sort-Object) -join '|')
    }
    return [string]$Value
}

function Get-ReceiveConnectorExtendedState {
    param([Parameter(Mandatory = $true)][string]$Identity)

    # All properties returned by Get-ReceiveConnector except RemoteIPRanges
    # and dynamic/session properties. Used only for verification.
    $connector = Get-ReceiveConnector -Identity $Identity -ErrorAction Stop
    $state = [ordered]@{}
    foreach ($property in @($connector.PSObject.Properties | Sort-Object Name)) {
        if ($script:MergeExtendedExcludedProperties -contains $property.Name) { continue }
        $state[$property.Name] = ConvertTo-MergeComparableText -Value $property.Value
    }
    return $state
}

function Get-MergeConnectorStateText {
    param(
        [Parameter(Mandatory = $true)]$Snapshot,
        [Parameter(Mandatory = $true)]$Connector,
        [switch]$MaskRemoteIPRanges
    )

    # Canonical managed-property and permission state of one connector. For
    # the merge target, RemoteIPRanges is masked; it is verified separately.
    $values = [ordered]@{}
    foreach ($propertyName in $script:ConnectorPropertyNames) {
        $values[$propertyName] = Get-ObjectPropertyValue -Object $Connector.Values -Name $propertyName
    }
    if ($MaskRemoteIPRanges) { $values['RemoteIPRanges'] = '<merge-target>' }
    $item = [PSCustomObject]@{
        Server             = $Connector.Server
        Name               = $Connector.Name
        Identity           = $Connector.Identity
        ConnectorType      = $Connector.ConnectorType
        BuiltInFamily      = $Connector.BuiltInFamily
        Values             = $values
        PermissionSnapshot = $Connector.PermissionSnapshot
    }
    return Get-ConnectorSnapshotStateText -Snapshot ([PSCustomObject]@{ Server = $Snapshot.Server; ServerFqdn = $Snapshot.ServerFqdn; Items = @($item) })
}

function Invoke-RemoteIPRangeMerge {
    param([Parameter(Mandatory = $true)]$Plan)

    # The only change made by this mode: one Set-ReceiveConnector call that
    # writes the complete planned RemoteIPRanges list (the existing target
    # entries followed by the entries to add). No other parameter is passed.
    # The hashtable Add form is not used: it failed parameter binding in
    # Exchange Management Shell.
    # Two safety gates run first. Any failure throws without calling
    # Set-ReceiveConnector:
    #   1)  FinalEntries must be non-empty and contain exactly the planned
    #       existing and added entries (counts and duplicates included).
    #   2)  Read-only re-read of the target RemoteIPRanges immediately before
    #       Set. The current entries must equal Plan.ExistingEntries as
    #       normalized ranges, including count and duplicate occurrences;
    #       order and notation are ignored.
    $abortText = 'Set-ReceiveConnector was not called. No changes were applied.'
    $identity = [string]$Plan.TargetIdentity
    $existingEntries = [string[]]@(Get-SafeArray -Value $Plan.ExistingEntries | ForEach-Object { [string]$_ })
    $addEntries = [string[]]@(Get-SafeArray -Value $Plan.ToAdd | ForEach-Object { [string]$_.Entry })
    $finalEntries = [string[]]@(Get-SafeArray -Value $Plan.FinalEntries | ForEach-Object { [string]$_ })

    Write-ResultHost ''
    Write-ResultHost ("Configuring [{0}] {1}" -f $Plan.TargetServer,$Plan.TargetName) -ForegroundColor Yellow
    Write-ResultHost ("  Add RemoteIPRanges entries: {0}" -f ($addEntries -join ', ')) -ForegroundColor Cyan

    # Gate 1 - validate FinalEntries (no Exchange access).
    if ([string]::IsNullOrWhiteSpace($identity)) {
        throw "RemoteIPRanges merge aborted: the target connector identity is unavailable. $abortText"
    }
    if ($finalEntries.Count -eq 0) {
        throw "RemoteIPRanges merge aborted: the final RemoteIPRanges list is empty. $abortText"
    }
    if (@($finalEntries | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
        throw "RemoteIPRanges merge aborted: the final RemoteIPRanges list contains an empty entry. $abortText"
    }
    $expectedCount = [int]$Plan.ExistingCount + [int]$Plan.AddCount
    if ([int]$Plan.AddCount -lt 1 -or
        $existingEntries.Count -ne [int]$Plan.ExistingCount -or
        $addEntries.Count -ne [int]$Plan.AddCount -or
        $finalEntries.Count -ne $expectedCount) {
        throw ("RemoteIPRanges merge aborted: the final RemoteIPRanges list has {0} entries; expected {1} (existing {2} + add {3}). {4}" -f $finalEntries.Count,$expectedCount,$Plan.ExistingCount,$Plan.AddCount,$abortText)
    }
    $finalCounts = New-Object 'System.Collections.Generic.Dictionary[string,int]' -ArgumentList ([System.StringComparer]::Ordinal)
    foreach ($entry in $finalEntries) {
        if ($finalCounts.ContainsKey($entry)) { $finalCounts[$entry] = $finalCounts[$entry] + 1 } else { $finalCounts[$entry] = 1 }
    }
    foreach ($entry in $existingEntries) {
        if (-not $finalCounts.ContainsKey($entry) -or $finalCounts[$entry] -lt 1) {
            throw ("RemoteIPRanges merge aborted: existing target entry '{0}' is not preserved in the final RemoteIPRanges list. {1}" -f $entry,$abortText)
        }
        $finalCounts[$entry] = $finalCounts[$entry] - 1
    }
    foreach ($entry in $addEntries) {
        if (-not $finalCounts.ContainsKey($entry) -or $finalCounts[$entry] -lt 1) {
            throw ("RemoteIPRanges merge aborted: planned entry '{0}' is missing from the final RemoteIPRanges list. {1}" -f $entry,$abortText)
        }
        $finalCounts[$entry] = $finalCounts[$entry] - 1
    }
    foreach ($key in @($finalCounts.Keys)) {
        if ($finalCounts[$key] -ne 0) {
            throw ("RemoteIPRanges merge aborted: the final RemoteIPRanges list contains unplanned entry '{0}'. {1}" -f $key,$abortText)
        }
    }
    foreach ($entry in $finalEntries) {
        if ($null -eq (ConvertTo-RemoteIPRangeBounds -Entry $entry)) {
            throw ("RemoteIPRanges merge aborted: final entry '{0}' cannot be parsed. {1}" -f $entry,$abortText)
        }
    }

    # Gate 2 - read-only re-read of the target RemoteIPRanges immediately before Set.
    $plannedKeys = New-Object System.Collections.ArrayList
    foreach ($entry in $existingEntries) {
        $bounds = ConvertTo-RemoteIPRangeBounds -Entry $entry
        if ($null -eq $bounds) {
            throw ("RemoteIPRanges merge aborted: planned existing entry '{0}' cannot be parsed. {1}" -f $entry,$abortText)
        }
        [void]$plannedKeys.Add([string]$bounds.Key)
    }
    try {
        $currentConnector = @(Get-ReceiveConnector -Identity $identity -ErrorAction Stop)
    }
    catch {
        throw ("RemoteIPRanges merge aborted: target connector '{0}' could not be re-read before Set ({1}). {2}" -f $identity,$_.Exception.Message,$abortText)
    }
    if ($currentConnector.Count -ne 1 -or $null -eq $currentConnector[0]) {
        throw ("RemoteIPRanges merge aborted: target connector '{0}' could not be re-read before Set. {1}" -f $identity,$abortText)
    }
    $currentProperty = $currentConnector[0].PSObject.Properties['RemoteIPRanges']
    if ($null -eq $currentProperty) {
        throw ("RemoteIPRanges merge aborted: current RemoteIPRanges of '{0}' were not returned. {1}" -f $identity,$abortText)
    }
    $currentEntries = [string[]]@(Get-SafeArray -Value (Normalize-ConnectorPropertyValue -PropertyName 'RemoteIPRanges' -Value $currentProperty.Value))
    $currentKeys = New-Object System.Collections.ArrayList
    foreach ($entry in $currentEntries) {
        $bounds = ConvertTo-RemoteIPRangeBounds -Entry $entry
        if ($null -eq $bounds) {
            throw ("RemoteIPRanges merge aborted: current target entry '{0}' cannot be parsed. {1}" -f $entry,$abortText)
        }
        [void]$currentKeys.Add([string]$bounds.Key)
    }
    $plannedSorted = [string[]]@($plannedKeys)
    $currentSorted = [string[]]@($currentKeys)
    [System.Array]::Sort($plannedSorted, [System.StringComparer]::Ordinal)
    [System.Array]::Sort($currentSorted, [System.StringComparer]::Ordinal)
    $sameEntries = ($plannedSorted.Count -eq $currentSorted.Count)
    if ($sameEntries) {
        for ($index = 0; $index -lt $plannedSorted.Count; $index++) {
            if (-not $plannedSorted[$index].Equals($currentSorted[$index], [System.StringComparison]::Ordinal)) { $sameEntries = $false; break }
        }
    }
    if (-not $sameEntries) {
        throw ("RemoteIPRanges merge aborted: target RemoteIPRanges changed after the plan was built (current {0} entries: {1}; planned {2} entries: {3}). Run the command again and review the new plan. {4}" -f $currentEntries.Count,($currentEntries -join ', '),$existingEntries.Count,($existingEntries -join ', '),$abortText)
    }

    Write-ResultHost ("  Set complete RemoteIPRanges list: {0} entries (existing {1} + added {2})" -f $finalEntries.Count,$existingEntries.Count,$addEntries.Count) -ForegroundColor Cyan
    Set-ReceiveConnector -Identity $identity -RemoteIPRanges $finalEntries -ErrorAction Stop | Out-Null
}

function Test-RemoteIPRangeMerge {
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)]$PreSnapshot,
        [Parameter(Mandatory = $true)]$PostSnapshot,
        $PreExtended,
        $PostExtended
    )

    $results = New-Object System.Collections.ArrayList
    $targetName = [string]$Plan.TargetName
    $serverName = [string]$Plan.TargetServer

    # Check: target RemoteIPRanges = existing + added (notation/order independent).
    $postTarget = @($PostSnapshot.Items | Where-Object { ([string]$_.Name) -ieq $targetName })
    if ($postTarget.Count -eq 0) {
        [void]$results.Add([PSCustomObject]@{ Target = $serverName; Connector = $targetName; Item = 'Connector'; Status = 'Mismatch'; Expected = 'Present'; Actual = 'Missing' })
    }
    else {
        $expectedKeys = @(@($Plan.ExistingBounds | ForEach-Object { $_.Key }) + @($Plan.ToAdd | ForEach-Object { $_.Bounds.Key }) | Sort-Object -Unique)
        $actualValues = Get-SourceConnectorValue -Connector $postTarget[0] -PropertyName 'RemoteIPRanges'
        $actualKeys = New-Object System.Collections.ArrayList
        $unparsed = New-Object System.Collections.ArrayList
        if (-not (Test-IsUnavailableValue -Value $actualValues)) {
            foreach ($rangeText in @(Get-SafeArray -Value $actualValues | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                $bounds = ConvertTo-RemoteIPRangeBounds -Entry $rangeText
                if ($null -eq $bounds) { [void]$unparsed.Add($rangeText) } else { [void]$actualKeys.Add($bounds.Key) }
            }
        }
        $actualUnique = @($actualKeys | Sort-Object -Unique)
        $sameSet = ($unparsed.Count -eq 0) -and (($expectedKeys -join ';') -eq ($actualUnique -join ';'))
        [void]$results.Add([PSCustomObject]@{
            Target    = $serverName
            Connector = $targetName
            Item      = 'RemoteIPRanges (existing + added)'
            Status    = $(if ($sameSet) { 'Verified' } else { 'Mismatch' })
            Expected  = ("{0} entries: {1}" -f @($Plan.FinalEntries).Count,(@($Plan.FinalEntries) -join ', '))
            Actual    = ("{0} entries: {1}" -f @(Get-SafeArray -Value $actualValues).Count,(ConvertTo-DisplayValue -Value $actualValues))
        })
    }

    # Check: supported settings and explicit permissions of every
    # connector on the target server (target RemoteIPRanges masked).
    $names = @(@($PreSnapshot.Items | ForEach-Object { [string]$_.Name }) + @($PostSnapshot.Items | ForEach-Object { [string]$_.Name }) | Sort-Object -Unique)
    foreach ($connectorName in $names) {
        $isTarget = $connectorName -ieq $targetName
        $before = @($PreSnapshot.Items | Where-Object { ([string]$_.Name) -ieq $connectorName })
        $after = @($PostSnapshot.Items | Where-Object { ([string]$_.Name) -ieq $connectorName })
        $label = if ($isTarget) { 'Configuration and permissions (except RemoteIPRanges)' } else { 'Configuration and permissions' }
        if ($before.Count -eq 0 -or $after.Count -eq 0) {
            [void]$results.Add([PSCustomObject]@{ Target = $serverName; Connector = $connectorName; Item = $label; Status = 'Mismatch'; Expected = $(if ($before.Count -gt 0) { 'Present' } else { 'Absent' }); Actual = $(if ($after.Count -gt 0) { 'Present (not made by this run)' } else { 'Missing (not made by this run)' }) })
            continue
        }
        $beforeText = Get-MergeConnectorStateText -Snapshot $PreSnapshot -Connector $before[0] -MaskRemoteIPRanges:$isTarget
        $afterText = Get-MergeConnectorStateText -Snapshot $PostSnapshot -Connector $after[0] -MaskRemoteIPRanges:$isTarget
        # Unavailable permission snapshots are never reported as Verified,
        # even when the before and after states match.
        $beforePermission = Get-MergePermissionQueryStatus -Connector $before[0]
        $afterPermission = Get-MergePermissionQueryStatus -Connector $after[0]
        $permissionsAvailable = ($beforePermission -eq 'Available' -and $afterPermission -eq 'Available')
        $actualText = if (-not $permissionsAvailable) {
            "Permissions not available (before {0}, after {1})" -f $beforePermission,$afterPermission
        }
        elseif ($beforeText -ceq $afterText) { 'Unchanged' }
        elseif ($isTarget) { 'Changed' }
        else { 'Changed (not made by this run)' }
        $isVerified = ($permissionsAvailable -and $beforeText -ceq $afterText)
        if ($isTarget) {
            [void]$results.Add([PSCustomObject]@{ Target = $serverName; Connector = $connectorName; Item = $label; Status = $(if ($isVerified) { 'Verified' } else { 'Mismatch' }); Expected = 'Unchanged'; Actual = $actualText })
        }
        elseif (-not $isVerified) {
            [void]$results.Add([PSCustomObject]@{ Target = $serverName; Connector = $connectorName; Item = $label; Status = 'Mismatch'; Expected = 'Unchanged'; Actual = $actualText })
        }
    }
    $otherMismatches = @($results | Where-Object { $_.Connector -ine $targetName -and $_.Status -ne 'Verified' }).Count
    [void]$results.Add([PSCustomObject]@{ Target = $serverName; Connector = '<other connectors>'; Item = 'Configuration and permissions'; Status = $(if ($otherMismatches -eq 0) { 'Verified' } else { 'Mismatch' }); Expected = 'Unchanged'; Actual = $(if ($otherMismatches -eq 0) { 'Unchanged' } else { "$otherMismatches changed" }) })

    # Check: other target properties (dynamic properties excluded).
    if ($null -ne $PreExtended -and $null -ne $PostExtended) {
        $changed = New-Object System.Collections.ArrayList
        $keys = @(@($PreExtended.Keys) + @($PostExtended.Keys) | Sort-Object -Unique)
        foreach ($key in $keys) {
            $beforeValue = if ($PreExtended.Contains($key)) { [string]$PreExtended[$key] } else { '<absent>' }
            $afterValue = if ($PostExtended.Contains($key)) { [string]$PostExtended[$key] } else { '<absent>' }
            if ($beforeValue -cne $afterValue) { [void]$changed.Add($key) }
        }
        [void]$results.Add([PSCustomObject]@{ Target = $serverName; Connector = $targetName; Item = 'Extended properties (except RemoteIPRanges and dynamic properties)'; Status = $(if ($changed.Count -eq 0) { 'Verified' } else { 'Mismatch' }); Expected = 'Unchanged'; Actual = $(if ($changed.Count -eq 0) { 'Unchanged' } else { 'Changed: ' + (@($changed) -join ', ') }) })
    }
    else {
        [void]$results.Add([PSCustomObject]@{ Target = $serverName; Connector = $targetName; Item = 'Extended properties (except RemoteIPRanges and dynamic properties)'; Status = 'Mismatch'; Expected = 'Captured before and after'; Actual = 'Not available' })
    }

    return @($results)
}

# ---------------------------------------------------------------------------
# Relay configuration check (read-only)
# ---------------------------------------------------------------------------
function Get-RelayAssessment {
    param(
        [Parameter(Mandatory = $true)]$Connector,
        [Parameter(Mandatory = $true)][string]$Server
    )

    # Read-only classification of one connector from an existing snapshot item.
    # No Exchange or AD call is made here. Only explicit (non-inherited) AD
    # permissions collected by Get-ConnectorPermissionSnapshot are evaluated.
    $connectorValues = Get-ObjectPropertyValue -Object $Connector -Name 'Values'
    $v = @{}
    foreach ($propertyName in @('Enabled','Bindings','RemoteIPRanges','PermissionGroups','AuthMechanism','TransportRole')) {
        $v[$propertyName] = '<not returned>'
        if ($connectorValues -is [System.Collections.IDictionary] -and $connectorValues.Contains($propertyName)) {
            $v[$propertyName] = $connectorValues[$propertyName]
        }
    }

    $permission = Get-ObjectPropertyValue -Object $Connector -Name 'PermissionSnapshot'
    $queryStatus = 'Unknown'
    $permissionError = 'Permission snapshot is unavailable.'
    if ($null -ne $permission) {
        $queryStatus = [string](Get-ObjectPropertyValue -Object $permission -Name 'QueryStatus')
        $permissionError = [string](Get-ObjectPropertyValue -Object $permission -Name 'Error')
    }
    if ([string]::IsNullOrWhiteSpace($queryStatus)) { $queryStatus = 'Unknown' }
    if ([string]::IsNullOrWhiteSpace($permissionError)) { $permissionError = 'No error text was returned.' }

    $entries = if ($queryStatus -eq 'Available') { @(Get-SafeArray -Value (Get-ObjectPropertyValue -Object $permission -Name 'ExplicitPermissions')) } else { @() }
    $relayEntries = @($entries | Where-Object {
        @(Get-SafeArray -Value (Get-ObjectPropertyValue -Object $_ -Name 'ExtendedRights') | Where-Object { ([string]$_) -ieq $script:AnonymousRelayRight }).Count -gt 0
    })
    $anonymousAllow = @($relayEntries | Where-Object { ([string]$_.User) -ieq $script:AnonymousLogonPrincipal -and -not [bool]$_.Deny }).Count
    $anonymousDeny = @($relayEntries | Where-Object { ([string]$_.User) -ieq $script:AnonymousLogonPrincipal -and [bool]$_.Deny }).Count
    $otherRelayPrincipals = @($relayEntries | Where-Object { ([string]$_.User) -ine $script:AnonymousLogonPrincipal -and -not [bool]$_.Deny } | ForEach-Object { [string]$_.User } | Sort-Object -Unique)

    $groupsKnown = -not (Test-IsUnavailableValue -Value $v['PermissionGroups'])
    $authKnown = -not (Test-IsUnavailableValue -Value $v['AuthMechanism'])
    $groups = if ($groupsKnown) { @(Get-SafeArray -Value $v['PermissionGroups'] | ForEach-Object { [string]$_ }) } else { @() }
    $auth = if ($authKnown) { @(Get-SafeArray -Value $v['AuthMechanism'] | ForEach-Object { [string]$_ }) } else { @() }
    $hasAnonymousUsers = @($groups | Where-Object { $_ -ieq 'AnonymousUsers' }).Count -gt 0
    $hasExchangeServers = @($groups | Where-Object { $_ -ieq 'ExchangeServers' }).Count -gt 0
    $hasExternalAuthoritative = @($auth | Where-Object { $_ -ieq 'ExternalAuthoritative' }).Count -gt 0

    # Anonymous relay: AnonymousUsers + explicit Allow of the relay right for
    # NT AUTHORITY\ANONYMOUS LOGON. Unknown input is never NOT CONFIGURED.
    $anonymousStatus = if ($queryStatus -ne 'Available' -or -not $groupsKnown) { 'UNKNOWN' }
    elseif ($anonymousDeny -gt 0) { 'CONFLICT' }
    elseif ($anonymousAllow -gt 0 -and $hasAnonymousUsers) { 'CONFIRMED' }
    elseif ($anonymousAllow -gt 0) { 'INCOMPLETE' }
    else { 'NOT CONFIGURED' }

    $anonymousDetail = if ($anonymousStatus -eq 'UNKNOWN') {
        if ($queryStatus -ne 'Available') { 'Explicit AD permissions could not be read: {0}' -f $permissionError } else { 'PermissionGroups was not returned.' }
    }
    elseif ($anonymousStatus -eq 'CONFLICT') {
        '{0} has an explicit Deny for {1}.' -f $script:AnonymousLogonPrincipal,$script:AnonymousRelayRight
    }
    elseif ($anonymousStatus -eq 'CONFIRMED') {
        'AnonymousUsers is in PermissionGroups and {0} has an explicit Allow for {1}.' -f $script:AnonymousLogonPrincipal,$script:AnonymousRelayRight
    }
    elseif ($anonymousStatus -eq 'INCOMPLETE') {
        '{0} has an explicit Allow for {1}, but AnonymousUsers is not in PermissionGroups.' -f $script:AnonymousLogonPrincipal,$script:AnonymousRelayRight
    }
    elseif ($hasAnonymousUsers) {
        'AnonymousUsers is in PermissionGroups. No explicit Allow for ms-Exch-SMTP-Accept-Any-Recipient.'
    }
    else { $null }

    # Externally secured: AuthMechanism ExternalAuthoritative with the
    # ExchangeServers permission group.
    $externalStatus = if (-not $authKnown -or -not $groupsKnown) { 'UNKNOWN' }
    elseif ($hasExternalAuthoritative -and $hasExchangeServers) { 'CONFIRMED' }
    elseif ($hasExternalAuthoritative) { 'INCOMPLETE' }
    else { 'NOT CONFIGURED' }

    $externalDetail = if ($externalStatus -eq 'UNKNOWN') {
        'AuthMechanism or PermissionGroups was not returned.'
    }
    elseif ($externalStatus -eq 'CONFIRMED') {
        'AuthMechanism includes ExternalAuthoritative and PermissionGroups includes ExchangeServers.'
    }
    elseif ($externalStatus -eq 'INCOMPLETE') {
        'AuthMechanism includes ExternalAuthoritative, but PermissionGroups does not include ExchangeServers.'
    }
    else { $null }

    $findings = New-Object System.Collections.ArrayList
    $relayConfigured = ($anonymousStatus -in @('CONFIRMED','INCOMPLETE')) -or ($externalStatus -in @('CONFIRMED','INCOMPLETE'))
    if ($relayConfigured) {
        if (Test-IsUnavailableValue -Value $v['RemoteIPRanges']) {
            [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = 'RemoteIPRanges was not returned. Potential exposure cannot be evaluated.' })
        }
        else {
            foreach ($rangeEntry in @(Get-SafeArray -Value $v['RemoteIPRanges'] | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                $bounds = ConvertTo-RemoteIPRangeBounds -Entry $rangeEntry
                if ($null -eq $bounds) {
                    [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = ("RemoteIPRanges entry '{0}' could not be evaluated." -f $rangeEntry) })
                }
                elseif (Test-AllAddressRange -Bounds $bounds) {
                    [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = ('Potential security exposure: RemoteIPRanges entry {0} covers all addresses.' -f $rangeEntry) })
                }
                elseif (Test-WideRemoteIPRange -Bounds $bounds) {
                    [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = ('Potential security exposure: wide RemoteIPRanges entry {0} (more than 256 IPv4 addresses or more than one IPv6 /64).' -f $rangeEntry) })
                }
            }
        }
        if ([string]$Connector.ConnectorType -ieq 'BuiltIn') {
            [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = 'Relay configuration is present on a built-in Receive Connector.' })
        }
        if ([string]$v['TransportRole'] -ieq 'HubTransport') {
            [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = 'Relay configuration is present on a HubTransport connector.' })
        }
        if (($anonymousStatus -in @('CONFIRMED','INCOMPLETE')) -and ($externalStatus -in @('CONFIRMED','INCOMPLETE'))) {
            [void]$findings.Add([PSCustomObject]@{ Level = 'REVIEW'; Message = 'Both anonymous relay and externally secured settings are present on this connector.' })
        }
        if ($v['Enabled'] -is [bool] -and -not $v['Enabled']) {
            [void]$findings.Add([PSCustomObject]@{ Level = 'INFO'; Message = 'The connector is disabled. Its relay configuration is not active while it is disabled.' })
        }
    }
    if ($otherRelayPrincipals.Count -gt 0) {
        [void]$findings.Add([PSCustomObject]@{ Level = 'INFO'; Message = ('Other principals with an explicit Allow for {0}: {1}' -f $script:AnonymousRelayRight,($otherRelayPrincipals -join ', ')) })
    }

    $statuses = @($anonymousStatus,$externalStatus)
    $overall = if ($statuses -contains 'UNKNOWN') { 'UNKNOWN' }
    elseif ($statuses -contains 'CONFLICT') { 'CONFLICT' }
    elseif ($statuses -contains 'INCOMPLETE') { 'INCOMPLETE' }
    elseif ($statuses -contains 'CONFIRMED') { 'CONFIRMED' }
    else { 'NOT CONFIGURED' }

    return [PSCustomObject]@{
        Server                  = $Server
        Name                    = [string]$Connector.Name
        ConnectorType           = [string]$Connector.ConnectorType
        TransportRole           = $v['TransportRole']
        Enabled                 = $v['Enabled']
        Bindings                = $v['Bindings']
        RemoteIPRanges          = $v['RemoteIPRanges']
        PermissionGroups        = $v['PermissionGroups']
        AuthMechanism           = $v['AuthMechanism']
        PermissionQueryStatus   = $queryStatus
        Status                  = $overall
        AnonymousStatus         = $anonymousStatus
        AnonymousDetail         = $anonymousDetail
        ExternallySecuredStatus = $externalStatus
        ExternallySecuredDetail = $externalDetail
        Findings                = @($findings)
    }
}

function Get-RelayCheckLines {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Assessments,
        [Parameter(Mandatory = $true)][string[]]$Servers,
        [AllowEmptyCollection()][array]$ServerErrors = @()
    )

    $confirmedText = ' - Configuration confirmed (explicit settings and permissions). SMTP relay was not tested.'
    $fieldFormat = '{0,-18} : {1}'
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add(("{0}.ps1 v{1} - Receive Connector relay configuration check" -f $script:ToolName,$script:ScriptVersion))
    [void]$lines.Add(("Generated : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    [void]$lines.Add('Mode      : Relay Configuration Check (read-only)')
    [void]$lines.Add(("Server(s) : {0}" -f (@($Servers) -join ', ')))
    [void]$lines.Add('Scope     : Explicit Receive Connector settings and explicit (non-inherited) AD permissions.')
    [void]$lines.Add('            Inherited AD permissions are not evaluated. No SMTP session or mail flow is tested.')
    [void]$lines.Add('')

    foreach ($assessment in @($Assessments | Sort-Object Server,Name)) {
        [void]$lines.Add(('=' * 80))
        [void]$lines.Add(("[{0}] [{1}] {2}" -f $assessment.Status,$assessment.Server,$assessment.Name))
        [void]$lines.Add(($fieldFormat -f 'Type',$assessment.ConnectorType))
        [void]$lines.Add(($fieldFormat -f 'TransportRole',(ConvertTo-DisplayValue -Value $assessment.TransportRole)))
        [void]$lines.Add(($fieldFormat -f 'Enabled',(ConvertTo-DisplayValue -Value $assessment.Enabled)))
        [void]$lines.Add(($fieldFormat -f 'Bindings',(ConvertTo-DisplayValue -Value $assessment.Bindings)))
        [void]$lines.Add(($fieldFormat -f 'RemoteIPRanges',(ConvertTo-DisplayValue -Value $assessment.RemoteIPRanges)))
        [void]$lines.Add(($fieldFormat -f 'PermissionGroups',(ConvertTo-DisplayValue -Value $assessment.PermissionGroups)))
        [void]$lines.Add(($fieldFormat -f 'AuthMechanism',(ConvertTo-DisplayValue -Value $assessment.AuthMechanism)))
        [void]$lines.Add(($fieldFormat -f 'AD permissions',$(if ($assessment.PermissionQueryStatus -eq 'Available') { 'Available (explicit entries only)' } else { 'Unknown' })))

        foreach ($relayType in @(
            @{ Label = 'Anonymous relay'; Status = [string]$assessment.AnonymousStatus; Detail = $assessment.AnonymousDetail },
            @{ Label = 'Externally secured'; Status = [string]$assessment.ExternallySecuredStatus; Detail = $assessment.ExternallySecuredDetail })) {
            $statusText = if ($relayType.Status -eq 'CONFIRMED') { $relayType.Status + $confirmedText } else { $relayType.Status }
            [void]$lines.Add(($fieldFormat -f $relayType.Label,$statusText))
            if (-not [string]::IsNullOrWhiteSpace([string]$relayType.Detail)) {
                [void]$lines.Add(("  Detail : {0}" -f $relayType.Detail))
            }
        }

        foreach ($finding in @($assessment.Findings)) {
            [void]$lines.Add(("{0,-8} {1}" -f $finding.Level,$finding.Message))
        }
        [void]$lines.Add('')
    }

    foreach ($serverError in @($ServerErrors)) {
        [void]$lines.Add(('=' * 80))
        [void]$lines.Add(("[ERROR] [{0}] Server could not be checked." -f $serverError.Server))
        [void]$lines.Add(("  Detail : {0}" -f $serverError.Error))
        [void]$lines.Add('')
    }

    $summaryFormat = '  {0,-29} : {1}'
    [void]$lines.Add('Summary')
    [void]$lines.Add(($summaryFormat -f 'Connectors checked',@($Assessments).Count))
    [void]$lines.Add(($summaryFormat -f 'Servers not checked',@($ServerErrors).Count))
    foreach ($status in @('CONFIRMED','INCOMPLETE','CONFLICT','UNKNOWN')) {
        [void]$lines.Add(($summaryFormat -f ('Anonymous relay ' + $status),@($Assessments | Where-Object { $_.AnonymousStatus -eq $status }).Count))
    }
    foreach ($status in @('CONFIRMED','INCOMPLETE','UNKNOWN')) {
        [void]$lines.Add(($summaryFormat -f ('Externally secured ' + $status),@($Assessments | Where-Object { $_.ExternallySecuredStatus -eq $status }).Count))
    }
    [void]$lines.Add(($summaryFormat -f 'REVIEW findings',@($Assessments | ForEach-Object { @($_.Findings) } | Where-Object { $_.Level -eq 'REVIEW' }).Count))
    [void]$lines.Add('')
    [void]$lines.Add('Note: CONFIRMED means the relay configuration is confirmed. SMTP relay functionality was not tested.')
    [void]$lines.Add('Note: Which connector accepts a connection depends on the Bindings and RemoteIPRanges of every connector on the server.')
    return @($lines)
}

function Show-RelayCheck {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Assessments,
        [Parameter(Mandatory = $true)][string[]]$Servers,
        [AllowEmptyCollection()][array]$ServerErrors = @()
    )

    # Console colors only. The line text comes unchanged from
    # Get-RelayCheckLines, which is also used for the TXT report.
    $statusColors = @{ 'CONFIRMED' = 'Cyan'; 'INCOMPLETE' = 'Yellow'; 'CONFLICT' = 'Yellow'; 'UNKNOWN' = 'Red'; 'NOT CONFIGURED' = 'DarkGray' }
    $inSummary = $false
    foreach ($line in @(Get-RelayCheckLines -Assessments $Assessments -Servers $Servers -ServerErrors $ServerErrors)) {
        if ($line -eq 'Summary') { $inSummary = $true; Write-ResultHost $line -ForegroundColor Cyan; continue }

        $color = $null
        if ($inSummary -and $line -match '^  (Anonymous relay|Externally secured) (CONFIRMED|INCOMPLETE|CONFLICT|UNKNOWN)\s+: (\d+)$') {
            $color = if ([int]$Matches[3] -eq 0) { 'DarkGray' } else { $statusColors[$Matches[2]] }
        }
        elseif ($inSummary -and $line -match '^  REVIEW findings\s+: (\d+)$') {
            $color = if ([int]$Matches[1] -eq 0) { 'DarkGray' } else { 'Yellow' }
        }
        elseif ($inSummary -and $line -match '^  Servers not checked\s+: (\d+)$') {
            $color = if ([int]$Matches[1] -eq 0) { 'DarkGray' } else { 'Red' }
        }
        elseif ($line -match '^\[ERROR\] ') {
            $color = 'Red'
        }
        elseif ($line -match '^\[(CONFIRMED|INCOMPLETE|CONFLICT|UNKNOWN)\] ') {
            $color = $statusColors[$Matches[1]]
        }
        elseif ($line -match '^(Anonymous relay|Externally secured)\s+: (CONFIRMED|INCOMPLETE|CONFLICT|UNKNOWN|NOT CONFIGURED)') {
            $color = $statusColors[$Matches[2]]
        }
        elseif ($line -match '^REVIEW ') { $color = 'Yellow' }
        elseif ($line -match '^INFO |^  Detail : |^Note: |^Scope     : |^            ') { $color = 'DarkGray' }

        if ($color) { Write-ResultHost $line -ForegroundColor $color } else { Write-ResultHost $line }
    }
}

function Export-RelayCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Assessments,
        [Parameter(Mandatory = $true)][string[]]$Servers,
        [AllowEmptyCollection()][array]$ServerErrors = @()
    )

    $resolved = Resolve-TextOutputPath -Path $Path
    Set-Content -LiteralPath $resolved -Value @(Get-RelayCheckLines -Assessments $Assessments -Servers $Servers -ServerErrors $ServerErrors) -Encoding UTF8 -ErrorAction Stop
    return $resolved
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

function Get-AnonymousRelayPlanNotices {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans)

    # Display only. Uses the anonymous relay state already stored in each plan;
    # relay permission management itself is not changed here.
    $notices = New-Object System.Collections.ArrayList
    foreach ($plan in @($Plans | Where-Object { -not $_.ScopeSkipped } | Sort-Object TargetServer,TargetName)) {
        $relay = $plan.AnonymousRelay
        $sourceEnabled = ($relay.SourceEnabled -eq $true)
        $label = '[{0}] {1}' -f $plan.TargetServer,$plan.TargetName

        if ($IncludeAnonymousRelayPermissions) {
            if ($relay.Manage) {
                $verb = if ($sourceEnabled) { 'added' } else { 'removed' }
                [void]$notices.Add([PSCustomObject]@{ Level = 'CHANGE'; Text = ('{0}: the anonymous relay permission will be {1}.' -f $label,$verb) })
            }
            elseif ($relay.Status -eq 'Unknown') {
                [void]$notices.Add([PSCustomObject]@{ Level = 'REVIEW'; Text = ('{0}: the anonymous relay permission state is unknown. The permission will not be changed.' -f $label) })
            }
            elseif ($relay.Status -eq 'Different') {
                $reason = if ($plan.Blocked) { 'the connector plan is BLOCKER' } elseif ($plan.Manual) { 'the connector requires manual configuration' } else { 'the connector is not in the apply plan' }
                [void]$notices.Add([PSCustomObject]@{ Level = 'REVIEW'; Text = ('{0}: the anonymous relay permission differs and will not be changed ({1}).' -f $label,$reason) })
            }
        }
        else {
            if (-not $plan.TargetExists -and $sourceEnabled) {
                $text = if ($plan.CanCreate) {
                    '{0}: the source has the anonymous relay permission. The target connector will be created without it.' -f $label
                }
                else {
                    '{0}: the source has the anonymous relay permission. The target connector does not exist, and the permission will not be copied.' -f $label
                }
                [void]$notices.Add([PSCustomObject]@{ Level = 'REVIEW'; Text = $text })
            }
            elseif ($plan.TargetExists -and $relay.Status -eq 'Different') {
                [void]$notices.Add([PSCustomObject]@{ Level = 'REVIEW'; Text = ('{0}: the anonymous relay permission differs (source {1}, target {2}) and will not be copied.' -f $label,$(if ($sourceEnabled) { 'enabled' } else { 'disabled' }),$(if ($relay.TargetEnabled -eq $true) { 'enabled' } else { 'disabled' })) })
            }
            elseif ($relay.Status -eq 'Unknown') {
                [void]$notices.Add([PSCustomObject]@{ Level = 'REVIEW'; Text = ('{0}: the anonymous relay permission state is unknown. The permission will not be changed.' -f $label) })
            }
        }
    }
    return @($notices)
}

function Show-AnonymousRelayNotices {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans)

    # Preview only. Console output; nothing is written to plan files.
    $notices = @(Get-AnonymousRelayPlanNotices -Plans $Plans)
    if ($notices.Count -eq 0) { return }

    Write-ResultHost ''
    Write-ResultHost 'Anonymous relay permissions' -ForegroundColor Cyan
    foreach ($notice in $notices) {
        Write-ResultHost ("{0,-8} {1}" -f $notice.Level,$notice.Text) -ForegroundColor $(if ($notice.Level -eq 'CHANGE') { 'Cyan' } else { 'Yellow' })
    }
    if (-not $IncludeAnonymousRelayPermissions -and @($notices | Where-Object { $_.Level -eq 'REVIEW' }).Count -gt 0) {
        Write-ResultHost 'Use -IncludeAnonymousRelayPermissions to include the source anonymous relay permission in the plan.' -ForegroundColor Cyan
    }
}

function Get-AnonymousRelayOutcomes {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans,
        [AllowEmptyCollection()][array]$Verification = @(),
        [AllowEmptyCollection()][array]$ApplyErrors = @(),
        [AllowEmptyCollection()][array]$PostApplySnapshots
    )

    # Outcome per connector from existing plan, verification, and apply error
    # data. Specifying -IncludeAnonymousRelayPermissions alone is never
    # reported as success; only a Verified 'Anonymous Relay' item is.
    # After Apply (-PostApplySnapshots supplied), an unchanged relay right is
    # confirmed from the post-Apply AD permission snapshot, never from the
    # pre-Apply plan. Without it (no Apply was run), the pre-Apply read is
    # reported as such.
    $afterApply = $PSBoundParameters.ContainsKey('PostApplySnapshots')
    $ordered = @($Plans | Where-Object { -not $_.ScopeSkipped } | Sort-Object TargetServer,TargetName)
    $managedOrder = @($ordered | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
    $stopIndex = -1
    if (@($ApplyErrors).Count -gt 0) {
        $failed = @($ApplyErrors)[0]
        for ($index = 0; $index -lt $managedOrder.Count; $index++) {
            if ([string]$managedOrder[$index].TargetServer -ieq [string]$failed.Target -and [string]$managedOrder[$index].TargetName -ieq [string]$failed.Connector) {
                $stopIndex = $index
                break
            }
        }
    }

    $outcomes = New-Object System.Collections.ArrayList
    foreach ($plan in $ordered) {
        $relay = $plan.AnonymousRelay
        $sourceEnabled = ($relay.SourceEnabled -eq $true)
        $outcome = $null
        $detail = $null

        if ($relay.Manage) {
            $position = -1
            for ($index = 0; $index -lt $managedOrder.Count; $index++) {
                if ([string]$managedOrder[$index].TargetServer -ieq [string]$plan.TargetServer -and [string]$managedOrder[$index].TargetName -ieq [string]$plan.TargetName) {
                    $position = $index
                    break
                }
            }
            if ($stopIndex -ge 0 -and $position -gt $stopIndex) {
                $outcome = 'Not Applied'
                $detail = 'Apply stopped before this connector.'
            }
            else {
                $items = @($Verification | Where-Object {
                    [string]$_.Target -ieq [string]$plan.TargetServer -and [string]$_.Connector -ieq [string]$plan.TargetName -and [string]$_.Item -eq 'Anonymous Relay'
                })
                if ($items.Count -gt 0 -and @($items | Where-Object { $_.Status -ne 'Verified' }).Count -eq 0) {
                    $outcome = 'Applied and Verified'
                    $detail = if ($sourceEnabled) { 'Anonymous relay permission added.' } else { 'Anonymous relay permission removed.' }
                }
                else {
                    $outcome = 'Verification Failed'
                    $detail = if ($items.Count -gt 0) { 'Expected {0}, actual {1}.' -f $items[0].Expected,$items[0].Actual } else { 'No verification result was returned.' }
                }
            }
        }
        elseif ($relay.Status -eq 'Same') {
            if ($sourceEnabled -and -not $afterApply) {
                $outcome = 'Already Configured'
                $detail = 'No Apply was run. State read from the target before Apply.'
            }
            elseif ($sourceEnabled) {
                $postSnapshot = @(@($PostApplySnapshots) | Where-Object { $null -ne $_ -and [string]$_.Server -ieq [string]$plan.TargetServer }) | Select-Object -First 1
                $postConnector = if ($null -ne $postSnapshot) { Get-TargetConnector -TargetSnapshot $postSnapshot -SourceConnector $plan.SourceConnector } else { $null }
                $postPermission = if ($null -ne $postConnector) { Get-ObjectPropertyValue -Object $postConnector -Name 'PermissionSnapshot' } else { $null }
                $postStatus = if ($null -ne $postPermission) { [string](Get-ObjectPropertyValue -Object $postPermission -Name 'QueryStatus') } else { '' }
                if ($null -eq $postSnapshot) {
                    $outcome = 'Not Verified'
                    $detail = 'The post-Apply target snapshot is unavailable.'
                }
                elseif ($null -eq $postConnector) {
                    $outcome = 'Verification Failed'
                    $detail = 'The target connector was not found in the post-Apply snapshot.'
                }
                elseif ($postStatus -ne 'Available') {
                    $outcome = 'Not Verified'
                    $detail = 'The post-Apply anonymous relay permission state could not be read.'
                }
                elseif ((Get-ObjectPropertyValue -Object $postPermission -Name 'AnonymousRelayEnabled') -eq $true) {
                    $outcome = 'Already Configured'
                    $detail = 'Verified in the post-Apply AD permission snapshot.'
                }
                else {
                    $outcome = 'Verification Failed'
                    $detail = 'The anonymous relay permission was expected, but the post-Apply AD permission snapshot does not contain it.'
                }
            }
        }
        elseif ($relay.Status -eq 'Different') {
            $outcome = 'Not Applied'
            $detail = if (-not $IncludeAnonymousRelayPermissions) { '-IncludeAnonymousRelayPermissions was not specified.' }
            elseif ($plan.Blocked) { 'The connector plan is BLOCKER.' }
            elseif ($plan.Manual) { 'The connector requires manual configuration.' }
            else { 'The connector is not in the apply plan.' }
            if ($sourceEnabled -and -not $plan.TargetExists -and $plan.CanCreate) {
                $detail += ' A connector created by this run does not have the anonymous relay permission.'
            }
        }
        elseif ($relay.Status -eq 'Unknown') {
            $outcome = 'Not Applied'
            $detail = 'The anonymous relay permission state is unknown.'
        }

        if ($outcome) {
            [void]$outcomes.Add([PSCustomObject]@{ Target = [string]$plan.TargetServer; Connector = [string]$plan.TargetName; Outcome = $outcome; Detail = $detail })
        }
    }
    return @($outcomes)
}

function Show-AnonymousRelayOutcome {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Plans,
        [AllowEmptyCollection()][array]$Verification = @(),
        [AllowEmptyCollection()][array]$ApplyErrors = @(),
        [AllowEmptyCollection()][array]$PostApplySnapshots
    )

    # Apply completion only. Console output; exit codes are not affected.
    $outcomeArguments = @{ Plans = $Plans; Verification = $Verification; ApplyErrors = $ApplyErrors }
    if ($PSBoundParameters.ContainsKey('PostApplySnapshots')) { $outcomeArguments['PostApplySnapshots'] = $PostApplySnapshots }
    $outcomes = @(Get-AnonymousRelayOutcomes @outcomeArguments)
    if ($outcomes.Count -eq 0 -and -not $IncludeAnonymousRelayPermissions) { return }

    Write-ResultHost ''
    Write-ResultHost 'Anonymous relay permissions' -ForegroundColor Cyan
    Write-ResultHost '---------------------------' -ForegroundColor Cyan
    if ($outcomes.Count -eq 0) {
        Write-ResultHost 'No anonymous relay permission changes were required.' -ForegroundColor DarkGray
        return
    }

    $outcomeColors = @{ 'Applied and Verified' = 'Green'; 'Already Configured' = 'Green'; 'Not Applied' = 'Yellow'; 'Not Verified' = 'Yellow'; 'Verification Failed' = 'Red' }
    foreach ($item in $outcomes) {
        Write-ResultHost ("[{0}] {1}: {2}. {3}" -f $item.Target,$item.Connector,$item.Outcome,$item.Detail) -ForegroundColor $outcomeColors[$item.Outcome]
    }

    $counts = @{}
    foreach ($name in @('Applied and Verified','Already Configured','Not Applied','Not Verified','Verification Failed')) {
        $counts[$name] = @($outcomes | Where-Object { $_.Outcome -eq $name }).Count
    }
    $countColor = if ($counts['Verification Failed'] -gt 0) { 'Red' } elseif ($counts['Not Applied'] -gt 0 -or $counts['Not Verified'] -gt 0) { 'Yellow' } else { 'Green' }
    Write-ResultHost ("Applied and Verified: {0}; Already Configured: {1}; Not Applied: {2}; Not Verified: {3}; Verification Failed: {4}" -f $counts['Applied and Verified'],$counts['Already Configured'],$counts['Not Applied'],$counts['Not Verified'],$counts['Verification Failed']) -ForegroundColor $countColor
}

function Show-PreviewCompletion {
    param(
        [Parameter(Mandatory = $true)][string]$Operation,
        [int]$BlockerCount = 0,
        [int]$ChangeCount = 0,
        [int]$ManualCount = 0,
        [int]$ReviewCount = 0
    )

    # Console completion message for Preview runs only. The counts are taken
    # from the existing plan results by the caller; nothing is recalculated
    # here, and return values, exit codes, and paging are not affected.
    Write-ResultHost ''
    if ($BlockerCount -gt 0) {
        Write-ResultHost ("{0} preview completed." -f $Operation) -ForegroundColor Cyan
        Write-ResultHost 'No Exchange configuration changes were made.' -ForegroundColor DarkGray
        Write-ResultHost 'Resolve the BLOCKER items above before running Apply.' -ForegroundColor Red
        return
    }

    if ($ChangeCount -gt 0) {
        Write-ResultHost ("{0} preview completed. No Exchange configuration changes were made." -f $Operation) -ForegroundColor Green
        if ($ManualCount -gt 0) {
            Write-ResultHost ("Manual configuration required: {0} connector(s). See Bindings attention." -f $ManualCount) -ForegroundColor Yellow
        }
        Write-ResultHost 'Run the same command with -ApplyChanges after reviewing the plan.' -ForegroundColor Cyan
        return
    }

    if ($ManualCount -gt 0 -or $ReviewCount -gt 0) {
        Write-ResultHost ("{0} preview completed. No automatic changes are required." -f $Operation) -ForegroundColor Yellow
        if ($ManualCount -gt 0) {
            Write-ResultHost ("Manual configuration required: {0} connector(s). See Bindings attention." -f $ManualCount) -ForegroundColor Yellow
        }
        if ($ReviewCount -gt 0) {
            Write-ResultHost 'Review the REVIEW items above.' -ForegroundColor Yellow
        }
        return
    }

    Write-ResultHost ("{0} preview completed. No changes are required." -f $Operation) -ForegroundColor Green
}

function Show-RuntimeFeedbackFooter {
    # Shown once, only on normal completion paths (exit 0 and exit 2).
    # Not shown for -Help, errors, BLOCKER, drift, or cancellation, and never
    # written to TXT, JSON, plan, or snapshot files.
    # Uses Write-ResultHost so the footer counts toward console paging. When
    # the footer fits on one page but not on the remaining part of the
    # current page, pause first so the footer lines stay together.
    # Colors: separators, heading, and the leading '# ' Cyan; labels White; URLs Gray.
    $footerSeparator = '##########################################################'
    $footerLines = @(
        '',
        $footerSeparator,
        '# Feedback / Bugs / Contact',
        $footerSeparator,
        '# GitHub  : https://github.com/Ceyhun-Kirmizitas',
        '# Website : https://ceyhunkirmizitas.net',
        '# LinkedIn: https://www.linkedin.com/in/ceyhun-kirmizitas/',
        $footerSeparator
    )

    $footerLineCount = 0
    foreach ($footerLine in $footerLines) {
        $footerLineCount += Get-ResultDisplayLineCount -Text $footerLine
    }
    if ($script:PagingEnabled -and $script:PagingLineCount -gt 0 -and
        $footerLineCount -le $script:PagingPageHeight -and
        (($script:PagingLineCount + $footerLineCount) -gt $script:PagingPageHeight)) {
        Invoke-ResultPagingPause
    }

    foreach ($footerLine in $footerLines) {
        $urlIndex = $footerLine.IndexOf('https://')
        if ($footerLine -eq $footerSeparator -or $footerLine -eq '# Feedback / Bugs / Contact') {
            Write-ResultHost $footerLine -ForegroundColor Cyan
        }
        elseif ($urlIndex -gt 2) {
            Write-ResultHost '# ' -ForegroundColor Cyan -NoNewline
            Write-ResultHost $footerLine.Substring(2, $urlIndex - 2) -ForegroundColor White -NoNewline
            Write-ResultHost $footerLine.Substring($urlIndex) -ForegroundColor Gray
        }
        else {
            Write-ResultHost $footerLine
        }
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
try {
    $operationMode = [string]$PSCmdlet.ParameterSetName
    $isReviewMode = $operationMode -eq 'Review'
    $isCloneMode = $operationMode -eq 'Clone'
    $isRestoreMode = $operationMode -eq 'Restore'
    $isMergeMode = $operationMode -eq 'Merge'
    $isCheckRelayMode = $operationMode -eq 'CheckRelay'

    # The Merge parameter set requires the explicit mode switch. Checked
    # before any banner or Exchange Management Shell initialization.
    if ($isMergeMode -and -not $RemoteIPRangesMergeOnly) {
        throw 'Specify -RemoteIPRangesMergeOnly to run the RemoteIPRanges merge operation.'
    }

    Write-Host ''
    Write-Host ("{0}.ps1" -f $script:ToolName) -ForegroundColor Yellow
    Write-Host 'Exchange Server Receive Connector review, backup, clone, restore, RemoteIPRanges merge, and relay check' -ForegroundColor DarkCyan
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
        Write-Host ("Anonymous relay : {0}" -f $(if ($IncludeAnonymousRelayPermissions) { 'Source permission included in plan (-IncludeAnonymousRelayPermissions)' } else { 'Permission will not be copied from source to target(s)' })) -ForegroundColor $(if ($IncludeAnonymousRelayPermissions) { 'Yellow' } else { 'Cyan' })
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
    elseif ($isMergeMode) {
        Write-Host ("Mode    : {0}" -f $(if ($ApplyChanges) { 'RemoteIPRanges Merge Only - Apply Changes' } else { 'RemoteIPRanges Merge Only - Preview' })) -ForegroundColor Cyan
        Write-Host ("Changes : {0}" -f $(if ($ApplyChanges) { 'RemoteIPRanges ONLY' } else { 'NONE' })) -ForegroundColor $(if ($ApplyChanges) { 'Yellow' } else { 'Green' })
        Write-Host ''
        if ($ApplyChanges) {
            Write-Host 'The script adds RemoteIPRanges entries to one existing target Receive Connector. No other setting or permission is changed.' -ForegroundColor Yellow
            Write-Host 'Review the complete merge plan before confirming the operation.' -ForegroundColor Yellow
        }
        else {
            Write-Host 'Merge Preview compares the selected source connectors with the target connector.' -ForegroundColor Cyan
            Write-Host 'No Exchange configuration changes will be made.' -ForegroundColor Cyan
        }
    }
    elseif ($isCheckRelayMode) {
        Write-Host 'Mode    : Relay Configuration Check' -ForegroundColor Cyan
        Write-Host 'Changes : NONE' -ForegroundColor Green
        Write-Host ''
        Write-Host 'The script only reads Receive Connector configuration and explicit AD permissions in this mode.' -ForegroundColor Cyan
        Write-Host 'No Exchange configuration changes will be made. SMTP relay is not tested.' -ForegroundColor Cyan
    }
    else {
        Write-Host ("Mode    : {0}" -f $(if ($ApplyChanges) { 'Restore - Apply Changes' } else { 'Restore Preview' })) -ForegroundColor Cyan
        Write-Host ("Changes : {0}" -f $(if ($ApplyChanges) { 'ENABLED' } else { 'NONE' })) -ForegroundColor $(if ($ApplyChanges) { 'Yellow' } else { 'Green' })
        Write-Host ("Anonymous relay : {0}" -f $(if ($IncludeAnonymousRelayPermissions) { 'Source permission included in plan (-IncludeAnonymousRelayPermissions)' } else { 'Permission will not be copied from source to target(s)' })) -ForegroundColor $(if ($IncludeAnonymousRelayPermissions) { 'Yellow' } else { 'Cyan' })
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
    # Only ENTER starts the run and only Q quits. Any other input is rejected.
    while ($true) {
        $startResponse = [string](Read-Host 'Press ENTER to start, or Q to quit')
        if ($startResponse.Length -eq 0) { break }
        if ($startResponse -match '^(?i)\s*q\s*$') {
            Write-Host 'Cancelled. No Exchange configuration changes were made.' -ForegroundColor Yellow
            return
        }
        Write-Host 'Invalid input. Press ENTER to start, or Q to quit.' -ForegroundColor Yellow
    }
    Write-Host ''

    Initialize-ExchangeShell
    Initialize-ResultPaging

    if ($isCheckRelayMode) {
        # -------------------------------------------------------------------
        # Relay Configuration Check - read-only. Uses the same read path as
        # Review (Get-ExchangeServer, Get-ReceiveConnector, Get-ADPermission).
        # -------------------------------------------------------------------
        $relayServers = Get-NormalizedServers -Servers @($Server)

        # Each server is checked independently. A failure on one server is
        # recorded and reported; the remaining servers are still checked.
        Write-ResultHost 'Collecting Receive Connector configuration and permissions...' -ForegroundColor DarkGray
        $relayAssessments = New-Object System.Collections.ArrayList
        $relayServerErrors = New-Object System.Collections.ArrayList
        $relayServerList = New-Object System.Collections.ArrayList
        foreach ($serverIdentity in $relayServers) {
            try {
                $serverObject = Resolve-MailboxExchangeServer -Identity $serverIdentity
                if (@($relayServerList | Where-Object { $_ -ieq [string]$serverObject.Name }).Count -gt 0) { continue }
                $relaySnapshot = Get-TargetConnectorSnapshot -ServerObject $serverObject
                $serverAssessments = @(@(Select-SourceConnectors -SourceSnapshot $relaySnapshot -Names $ConnectorName) | ForEach-Object {
                    Get-RelayAssessment -Connector $_ -Server ([string]$relaySnapshot.Server)
                })
                foreach ($serverAssessment in $serverAssessments) { [void]$relayAssessments.Add($serverAssessment) }
                [void]$relayServerList.Add([string]$serverObject.Name)
            }
            catch {
                $relayErrorMessage = [string]$_.Exception.Message
                [void]$relayServerErrors.Add([PSCustomObject]@{ Server = [string]$serverIdentity; Error = $relayErrorMessage })
                [void]$relayServerList.Add([string]$serverIdentity)
                Write-ResultHost ("ERROR: [{0}] {1}" -f $serverIdentity,$relayErrorMessage) -ForegroundColor Red
            }
        }
        $relayServerNames = [string[]]@($relayServerList)

        Write-ResultHost ''
        Show-RelayCheck -Assessments @($relayAssessments) -Servers $relayServerNames -ServerErrors @($relayServerErrors)

        if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
            $relayReportPath = Export-RelayCheck -Path $OutputFile -Assessments @($relayAssessments) -Servers $relayServerNames -ServerErrors @($relayServerErrors)
            Write-ResultHost ''
            Write-ResultHost ("Relay check report saved: {0}" -f $relayReportPath) -ForegroundColor Green
        }

        Write-ResultHost ''
        if ($relayServerErrors.Count -gt 0) {
            Write-ResultHost ("Relay configuration check completed with errors: {0} of {1} server(s) could not be checked. No Exchange configuration changes were made." -f $relayServerErrors.Count,$relayServerNames.Count) -ForegroundColor Red
            exit 1
        }
        Write-ResultHost 'Relay configuration check completed. No Exchange configuration changes were made.' -ForegroundColor Green
        Show-RuntimeFeedbackFooter
        return
    }

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
            Write-ResultHost 'The JSON file is the restore-compatible backup.' -ForegroundColor DarkGray
        }
        Write-ResultHost ''
        Write-ResultHost 'Review completed. No Exchange configuration changes were made.' -ForegroundColor Green
        Show-RuntimeFeedbackFooter
        return
    }

    # -----------------------------------------------------------------------
    # RemoteIPRanges Merge Only - live source connectors to one existing target
    # -----------------------------------------------------------------------
    if ($isMergeMode) {
        $script:PlanOperation = 'Merge'
        $script:BackupPath = $null

        $sourceServerObject = Resolve-MailboxExchangeServer -Identity $SourceServer
        $targetServerObject = Resolve-MailboxExchangeServer -Identity $TargetServer

        Write-ResultHost ("Source server     : {0}" -f $sourceServerObject.Name) -ForegroundColor Cyan
        Write-ResultHost ("Source connectors : {0}" -f (@($ConnectorName) -join ', ')) -ForegroundColor Cyan
        Write-ResultHost ("Target server     : {0}" -f $targetServerObject.Name) -ForegroundColor Cyan
        Write-ResultHost ("Target connector  : {0}" -f $TargetConnectorName) -ForegroundColor Cyan
        Write-ResultHost ''
        Write-ResultHost 'Collecting Receive Connector configuration and permissions...' -ForegroundColor DarkGray

        $sourceSnapshot = Get-TargetConnectorSnapshot -ServerObject $sourceServerObject
        $targetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject
        $mergePlan = New-RemoteIPRangeMergePlan -SourceSnapshot $sourceSnapshot -SourceNames $ConnectorName -TargetSnapshot $targetSnapshot -TargetName $TargetConnectorName

        Show-RemoteIPRangeMergePlan -Plan $mergePlan

        if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
            $planPath = Export-RemoteIPRangeMergePlan -Path $OutputFile -Plan $mergePlan
            Write-ResultHost ''
            Write-ResultHost ("Merge plan saved: {0}" -f $planPath) -ForegroundColor Green
        }

        if (-not $ApplyChanges) {
            Show-PreviewCompletion -Operation 'RemoteIPRanges merge' `
                -BlockerCount $(if ($mergePlan.Status -eq 'BLOCKER') { 1 } else { 0 }) `
                -ChangeCount $(if ($mergePlan.Status -eq 'UPDATE') { 1 } else { 0 }) `
                -ReviewCount (@($mergePlan.Warnings).Count + @($mergePlan.Findings | Where-Object { $_.Level -eq 'REVIEW' }).Count)
            Show-RuntimeFeedbackFooter
            return
        }

        if ($mergePlan.Status -eq 'BLOCKER') {
            throw 'RemoteIPRanges merge aborted: resolve every BLOCKER in the plan before applying. No Exchange configuration changes were applied.'
        }
        if ($mergePlan.Status -eq 'SAME') {
            Write-ResultHost ''
            Write-ResultHost 'No RemoteIPRanges changes are required.' -ForegroundColor Green
            Show-RuntimeFeedbackFooter
            return
        }

        Write-ResultHost ''
        Write-ResultHost 'Refreshing source and target state and validating the merge plan...' -ForegroundColor Cyan

        $preConfirmSourceSnapshot = Get-TargetConnectorSnapshot -ServerObject $sourceServerObject
        $preConfirmTargetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject
        $applyMergePlan = New-RemoteIPRangeMergePlan -SourceSnapshot $preConfirmSourceSnapshot -SourceNames $ConnectorName -TargetSnapshot $preConfirmTargetSnapshot -TargetName $TargetConnectorName

        Write-ResultHost ''
        Write-ResultHost 'Refreshed pre-apply plan' -ForegroundColor Cyan
        Write-ResultHost '------------------------' -ForegroundColor Cyan
        Show-RemoteIPRangeMergePlan -Plan $applyMergePlan

        if ($applyMergePlan.Status -eq 'BLOCKER') {
            throw 'RemoteIPRanges merge aborted: the refreshed plan contains BLOCKER conditions. No Exchange configuration changes were applied.'
        }
        if ($applyMergePlan.Status -eq 'SAME') {
            Write-ResultHost ''
            Write-ResultHost 'No RemoteIPRanges changes are required after the pre-apply refresh.' -ForegroundColor Green
            Show-RuntimeFeedbackFooter
            return
        }

        $mergeTargetText = '{0}\{1}' -f $applyMergePlan.TargetServer,$applyMergePlan.TargetName
        if (-not $PSCmdlet.ShouldProcess($mergeTargetText, ("Add {0} RemoteIPRanges entries (RemoteIPRanges only)" -f $applyMergePlan.AddCount))) {
            Write-ResultHost 'Operation cancelled. No Exchange configuration changes were applied.' -ForegroundColor Yellow
            return
        }

        # Final reads after confirmation: selected-source drift and full target drift.
        $finalSourceSnapshot = Get-TargetConnectorSnapshot -ServerObject $sourceServerObject
        $sourceDriftBefore = Get-SelectedSourceConnectorSnapshot -Snapshot $preConfirmSourceSnapshot -Names $ConnectorName
        $sourceDriftAfter = Get-SelectedSourceConnectorSnapshot -Snapshot $finalSourceSnapshot -Names $ConnectorName
        if (-not (Test-ConnectorSnapshotUnchanged -Before $sourceDriftBefore -After $sourceDriftAfter)) {
            throw "Receive Connector configuration changed on source '$($preConfirmSourceSnapshot.Server)' after the refreshed plan was displayed. No changes were applied. Run the command again and review the new plan."
        }
        $finalTargetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject
        if (-not (Test-ConnectorSnapshotUnchanged -Before $preConfirmTargetSnapshot -After $finalTargetSnapshot)) {
            throw "Receive Connector configuration changed on '$($preConfirmTargetSnapshot.Server)' after the refreshed plan was displayed. No changes were applied. Run the command again and review the new plan."
        }

        $preExtendedState = Get-ReceiveConnectorExtendedState -Identity ([string]$applyMergePlan.TargetIdentity)
        $preChangePath = Export-PreChangeSnapshot -TargetSnapshot $finalTargetSnapshot
        Write-ResultHost ''
        Write-ResultHost ("Pre-change JSON snapshot [{0}]: {1}" -f $finalTargetSnapshot.Server,$preChangePath) -ForegroundColor Green

        $mergeError = $null
        try {
            Invoke-RemoteIPRangeMerge -Plan $applyMergePlan
        }
        catch {
            $mergeError = $_.Exception.Message
            Write-ResultHost ("  ERROR: {0}" -f $mergeError) -ForegroundColor Red
        }

        Write-ResultHost ''
        Write-ResultHost 'Verifying RemoteIPRanges and unchanged configuration and permissions on the target server...' -ForegroundColor Cyan
        $postTargetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject
        $postExtendedState = $null
        try {
            $postExtendedState = Get-ReceiveConnectorExtendedState -Identity ([string]$applyMergePlan.TargetIdentity)
        }
        catch {
            Write-ResultHost ("  WARNING: Extended target properties could not be read: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
        $mergeVerification = @(Test-RemoteIPRangeMerge -Plan $applyMergePlan -PreSnapshot $finalTargetSnapshot -PostSnapshot $postTargetSnapshot -PreExtended $preExtendedState -PostExtended $postExtendedState)
        Show-Verification -Results $mergeVerification

        if ($mergeError) {
            Write-ResultHost ''
            Write-ResultHost 'RemoteIPRanges merge failed. Review the error and verification results above.' -ForegroundColor Red
            exit 1
        }
        if (@($mergeVerification | Where-Object { $_.Status -ne 'Verified' }).Count -gt 0) {
            Write-ResultHost ''
            Write-ResultHost 'RemoteIPRanges merge finished with verification mismatches. Review the Verification summary above.' -ForegroundColor Red
            exit 1
        }

        Write-ResultHost ''
        Write-ResultHost 'RemoteIPRanges merge completed and verified. Changes: RemoteIPRanges ONLY.' -ForegroundColor Green
        Show-RuntimeFeedbackFooter
        return
    }

    # -----------------------------------------------------------------------
    # Clone - live source server to one or more live target servers
    # -----------------------------------------------------------------------
    if ($isCloneMode) {
        $script:PlanOperation = 'Clone'
        $script:BackupPath = $null
        $script:BindingMode = 'TargetSpecific'
        $script:RestoreType = $null
        $script:BackupContainsTargetEntry = $false

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
            Show-AnonymousRelayNotices -Plans @($plans)
            Show-PreviewCompletion -Operation 'Clone' `
                -BlockerCount (@($plans | Where-Object { $_.Blocked }).Count) `
                -ChangeCount (@($plans | Where-Object { Test-PlanHasManagedChanges -Plan $_ }).Count) `
                -ManualCount (Get-ManualPlanCount -Plans @($plans)) `
                -ReviewCount (@($plans | Where-Object { (Get-PlanStatus -Plan $_) -eq 'REVIEW' }).Count)
            Show-RuntimeFeedbackFooter
            return
        }

        if (@($plans | Where-Object { $_.Blocked }).Count -gt 0) {
            throw 'Clone apply aborted: resolve every BLOCKER in the plan before applying. No Exchange configuration changes were applied.'
        }
        $managedPlans = @($plans | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
        if ($managedPlans.Count -eq 0) {
            Show-AnonymousRelayOutcome -Plans @($plans)
            $manualCount = Get-ManualPlanCount -Plans @($plans)
            Write-ResultHost ''
            if ($manualCount -gt 0) {
                Write-ResultHost ("No automatic Receive Connector changes are required. Manual configuration required: {0} connector(s). See Bindings attention." -f $manualCount) -ForegroundColor Yellow
                Show-RuntimeFeedbackFooter
                exit 2
            }
            Write-ResultHost 'No automatic Receive Connector changes are required.' -ForegroundColor Green
            Show-RuntimeFeedbackFooter
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
        Show-AnonymousRelayNotices -Plans @($applyPlans)

        if (@($applyPlans | Where-Object { $_.Blocked }).Count -gt 0) {
            throw 'Clone apply aborted: the refreshed plan contains BLOCKER conditions. No Exchange configuration changes were applied.'
        }
        $managedPlans = @($applyPlans | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
        if ($managedPlans.Count -eq 0) {
            Show-AnonymousRelayOutcome -Plans @($applyPlans)
            $manualCount = Get-ManualPlanCount -Plans @($applyPlans)
            Write-ResultHost ''
            if ($manualCount -gt 0) {
                Write-ResultHost ("No automatic Receive Connector changes are required after the pre-apply refresh. Manual configuration required: {0} connector(s). See Bindings attention." -f $manualCount) -ForegroundColor Yellow
                Show-RuntimeFeedbackFooter
                exit 2
            }
            Write-ResultHost 'No automatic Receive Connector changes are required after the pre-apply refresh.' -ForegroundColor Green
            Show-RuntimeFeedbackFooter
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
        # Source drift scope: selected source connectors only when -ConnectorName
        # is used; otherwise the complete source snapshot.
        $sourceDriftBefore = Get-SelectedSourceConnectorSnapshot -Snapshot $preConfirmSourceSnapshot -Names $ConnectorName
        $sourceDriftAfter = Get-SelectedSourceConnectorSnapshot -Snapshot $finalSourceSnapshot -Names $ConnectorName
        if (-not (Test-ConnectorSnapshotUnchanged -Before $sourceDriftBefore -After $sourceDriftAfter)) {
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

        Write-ResultHost ''
        Write-ResultHost 'Verifying Receive Connector configuration and permissions on target servers...' -ForegroundColor Cyan
        $verification = New-Object System.Collections.ArrayList
        $postApplySnapshots = New-Object System.Collections.ArrayList
        foreach ($targetObject in $targetObjects) {
            $freshTargetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetObject
            [void]$postApplySnapshots.Add($freshTargetSnapshot)
            foreach ($result in @(Test-ConnectorPlan -Plans @($applyPlans) -FreshTargetSnapshot $freshTargetSnapshot)) {
                [void]$verification.Add($result)
            }
        }
        Show-Verification -Results @($verification)
        Show-BindingAttention -Plans @($applyPlans) -Verification @($verification)
        Show-AnonymousRelayOutcome -Plans @($applyPlans) -Verification @($verification) -ApplyErrors @($applyErrors) -PostApplySnapshots @($postApplySnapshots)

        if ($applyErrors.Count -gt 0) {
            Write-ResultHost ''
            Write-ResultHost ("Clone apply did not complete: {0} connector error(s). Review the errors and verification results above." -f $applyErrors.Count) -ForegroundColor Red
            exit 1
        }

        if (@($verification | Where-Object { $_.Status -ne 'Verified' }).Count -gt 0) {
            Write-ResultHost ''
            Write-ResultHost 'Clone apply finished with verification mismatches against the source configuration. Review the Verification summary above.' -ForegroundColor Red
            exit 1
        }

        $relayVerificationProblems = @(Get-AnonymousRelayOutcomes -Plans @($applyPlans) -Verification @($verification) -ApplyErrors @($applyErrors) -PostApplySnapshots @($postApplySnapshots) | Where-Object { $_.Outcome -in @('Verification Failed','Not Verified') })
        if ($relayVerificationProblems.Count -gt 0) {
            Write-ResultHost ''
            Write-ResultHost ("Clone apply finished, but the anonymous relay permission could not be verified on {0} connector(s). Review the Anonymous relay permissions section above." -f $relayVerificationProblems.Count) -ForegroundColor Red
            exit 1
        }

        $manualCount = Get-ManualPlanCount -Plans @($applyPlans)
        Write-ResultHost ''
        if ($manualCount -gt 0) {
            Write-ResultHost ("Receive Connector clone completed. Applied changes were verified. Manual configuration required: {0} connector(s). See Bindings attention." -f $manualCount) -ForegroundColor Yellow
            Show-RuntimeFeedbackFooter
            exit 2
        }
        Write-ResultHost 'Receive Connector clone completed. All applied changes were verified.' -ForegroundColor Green
        Show-RuntimeFeedbackFooter
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

    # Restore type is decided once by server name and reused for the refreshed
    # plan. Same-server Restore restores Bindings; cross-server Restore keeps
    # Bindings target-specific like Clone.
    $script:RestoreType = if ([string]$sourceSnapshot.Server -ieq [string]$targetServerObject.Name) { 'Same-server' } else { 'Cross-server' }
    $script:BindingMode = if ($script:RestoreType -eq 'Same-server') { 'Managed' } else { 'TargetSpecific' }
    $script:BackupContainsTargetEntry = ($script:RestoreType -eq 'Cross-server') -and
        (@($backup.Servers | Where-Object { [string](Get-ObjectPropertyValue -Object $_ -Name 'Server') -ieq [string]$targetServerObject.Name }).Count -gt 0)

    Write-ResultHost ("Backup schema : {0}" -f $(if ($backup.LegacySchema) { 'Legacy v1.0 backup (accepted)' } else { "ExchangeReceiveConnectorBackup v$($backup.SchemaVersion)" })) -ForegroundColor Cyan
    Write-ResultHost ("Source server : {0}" -f $sourceSnapshot.Server) -ForegroundColor Cyan
    Write-ResultHost ("Target server : {0}" -f $targetSnapshot.Server) -ForegroundColor Cyan
    Write-ResultHost ("Restore type  : {0}" -f $(if ($script:RestoreType -eq 'Same-server') { 'Same-server (Bindings included)' } else { 'Cross-server (Bindings target-specific)' })) -ForegroundColor Cyan
    if ($script:BackupContainsTargetEntry) {
        Write-ResultHost ("REVIEW: The backup also contains an entry for '{0}'. Selected source is '{1}'. This is a cross-server restore." -f $targetSnapshot.Server,$sourceSnapshot.Server) -ForegroundColor DarkYellow
    }
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
        Show-AnonymousRelayNotices -Plans @($plans)
        Show-PreviewCompletion -Operation 'Restore' `
            -BlockerCount (@($plans | Where-Object { $_.Blocked }).Count) `
            -ChangeCount (@($plans | Where-Object { Test-PlanHasManagedChanges -Plan $_ }).Count) `
            -ManualCount (Get-ManualPlanCount -Plans @($plans)) `
            -ReviewCount (@($plans | Where-Object { (Get-PlanStatus -Plan $_) -eq 'REVIEW' }).Count)
        Show-RuntimeFeedbackFooter
        return
    }

    if (@($plans | Where-Object { $_.Blocked }).Count -gt 0) {
        throw 'Restore apply aborted: resolve every BLOCKER in the plan before applying. No Exchange configuration changes were applied.'
    }
    $managedPlans = @($plans | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
    if ($managedPlans.Count -eq 0) {
        Show-AnonymousRelayOutcome -Plans @($plans)
        $manualCount = Get-ManualPlanCount -Plans @($plans)
        Write-ResultHost ''
        if ($manualCount -gt 0) {
            Write-ResultHost ("No automatic Receive Connector changes are required. Manual configuration required: {0} connector(s). See Bindings attention." -f $manualCount) -ForegroundColor Yellow
            Show-RuntimeFeedbackFooter
            exit 2
        }
        Write-ResultHost 'No automatic Receive Connector changes are required.' -ForegroundColor Green
        Show-RuntimeFeedbackFooter
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
    Show-AnonymousRelayNotices -Plans @($applyPlans)

    if (@($applyPlans | Where-Object { $_.Blocked }).Count -gt 0) {
        throw 'Restore apply aborted: the refreshed plan contains BLOCKER conditions. No Exchange configuration changes were applied.'
    }
    $managedPlans = @($applyPlans | Where-Object { Test-PlanHasManagedChanges -Plan $_ })
    if ($managedPlans.Count -eq 0) {
        Show-AnonymousRelayOutcome -Plans @($applyPlans)
        $manualCount = Get-ManualPlanCount -Plans @($applyPlans)
        Write-ResultHost ''
        if ($manualCount -gt 0) {
            Write-ResultHost ("No automatic Receive Connector changes are required after the pre-apply refresh. Manual configuration required: {0} connector(s). See Bindings attention." -f $manualCount) -ForegroundColor Yellow
            Show-RuntimeFeedbackFooter
            exit 2
        }
        Write-ResultHost 'No automatic Receive Connector changes are required after the pre-apply refresh.' -ForegroundColor Green
        Show-RuntimeFeedbackFooter
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

    Write-ResultHost ''
    Write-ResultHost 'Verifying Receive Connector configuration and permissions on target servers...' -ForegroundColor Cyan
    $freshTargetSnapshot = Get-TargetConnectorSnapshot -ServerObject $targetServerObject
    $verification = @(Test-ConnectorPlan -Plans @($applyPlans) -FreshTargetSnapshot $freshTargetSnapshot)
    Show-Verification -Results $verification
    Show-BindingAttention -Plans @($applyPlans) -Verification @($verification)
    Show-AnonymousRelayOutcome -Plans @($applyPlans) -Verification @($verification) -ApplyErrors @($applyErrors) -PostApplySnapshots @($freshTargetSnapshot)

    if ($applyErrors.Count -gt 0) {
        Write-ResultHost ''
        Write-ResultHost ("Restore apply did not complete: {0} connector error(s). Review the errors and verification results above." -f $applyErrors.Count) -ForegroundColor Red
        exit 1
    }

    if (@($verification | Where-Object { $_.Status -ne 'Verified' }).Count -gt 0) {
        Write-ResultHost ''
        Write-ResultHost 'Restore apply finished with verification mismatches against the JSON backup. Review the Verification summary above.' -ForegroundColor Red
        exit 1
    }

    $relayVerificationProblems = @(Get-AnonymousRelayOutcomes -Plans @($applyPlans) -Verification @($verification) -ApplyErrors @($applyErrors) -PostApplySnapshots @($freshTargetSnapshot) | Where-Object { $_.Outcome -in @('Verification Failed','Not Verified') })
    if ($relayVerificationProblems.Count -gt 0) {
        Write-ResultHost ''
        Write-ResultHost ("Restore apply finished, but the anonymous relay permission could not be verified on {0} connector(s). Review the Anonymous relay permissions section above." -f $relayVerificationProblems.Count) -ForegroundColor Red
        exit 1
    }

    $manualCount = Get-ManualPlanCount -Plans @($applyPlans)
    Write-ResultHost ''
    if ($manualCount -gt 0) {
        Write-ResultHost ("Receive Connector restore completed. Applied changes were verified. Manual configuration required: {0} connector(s). See Bindings attention." -f $manualCount) -ForegroundColor Yellow
        Show-RuntimeFeedbackFooter
        exit 2
    }
    Write-ResultHost 'Receive Connector restore completed. All applied changes were verified.' -ForegroundColor Green
    Show-RuntimeFeedbackFooter
}
catch {
    Write-Host ''
    Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}