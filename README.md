# ExchangeReceiveConnectorManager.ps1

PowerShell tool for reviewing, backing up, cloning, and restoring **Exchange Server Receive Connector** configuration.

The script is designed for side-by-side Exchange deployments, upgrades, migrations, and replacement-server work. Review and Backup are read-only. Clone and Restore are preview-only by default and require `-ApplyChanges` before any supported configuration change is made.

## Download

- [ExchangeReceiveConnectorManager.ps1](ExchangeReceiveConnectorManager.ps1)
- [Raw download](https://raw.githubusercontent.com/Ceyhun-Kirmizitas/ExchangeReceiveConnectorManager.ps1/main/ExchangeReceiveConnectorManager.ps1)

## Modes

### Review / Backup

Reads Receive Connector configuration from one or more Exchange Mailbox servers.

When `-OutputFile` is used, the script creates:

- a TXT report for human review
- a versioned JSON backup for Restore operations

No Exchange configuration changes are made.

### Clone

Uses a live Exchange server as the source and compares selected Receive Connectors with one or more target servers.

Clone is preview-only unless `-ApplyChanges` is specified.

### Restore

Reads a JSON backup created by this script and compares it with a target Exchange server.

Restore is preview-only unless `-ApplyChanges` is specified. TXT reports are not accepted for Restore.

## Managed configuration

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
- Explicit Receive Connector AD permissions for inventory and review
- Anonymous relay state based on `ms-Exch-SMTP-Accept-Any-Recipient` for `NT AUTHORITY\ANONYMOUS LOGON`

## Safety behavior

- Review and Backup are read-only.
- Clone and Restore are preview-only by default.
- Changes require the explicit `-ApplyChanges` switch.
- Custom Receive Connectors are in Clone and Restore scope by default.
- Built-in Receive Connectors are never created or deleted.
- `-IncludeBuiltIn` allows supported alignment of existing built-in connectors.
- Source and target connector types must match.
- Source-specific binding IP addresses must be verifiable on the target before that connector can be changed.
- A non-empty `TlsCertificateName` is not applied unless the required valid SMTP certificate is available on the target.
- Any BLOCKER aborts the entire Apply operation before any selected connector is changed.
- Missing backup properties are treated as unavailable rather than empty, so existing target values are preserved.
- Server-specific built-in connector FQDN values are translated from source server FQDN to target server FQDN.
- Explicit Receive Connector AD permissions are review-only except for anonymous relay when `-IncludeAnonymousRelayPermissions` is used.
- Target state is refreshed before Apply.
- A pre-change JSON snapshot of the target is saved immediately before mutation.
- Apply aborts if target connector state changes after the refreshed plan is displayed.
- New custom connectors are created disabled, configured while disabled, and enabled only after managed settings and permissions succeed.
- Apply stops on the first runtime connector error and then verifies the final target state.

## Parameters

| Parameter | Description |
|---|---|
| `-Server` | One or more Exchange Mailbox servers to review. |
| `-SourceServer` | Live source server for Clone, or source-server selection for a multi-server Restore backup. |
| `-TargetServers` | One or more target servers for Clone. |
| `-RestoreFile` | JSON backup created by this script. |
| `-TargetServer` | Target server for Restore. |
| `-ConnectorName` | Optional connector name or built-in connector family filter. Multiple values are supported. |
| `-IncludeBuiltIn` | Includes existing built-in connectors in supported property alignment. |
| `-IncludeAnonymousRelayPermissions` | Includes alignment of the explicit anonymous relay right. |
| `-ApplyChanges` | Applies the displayed Clone or Restore plan. |
| `-OutputFile` | Saves Review output or Clone/Restore plans to a TXT file. Review also creates the matching JSON backup. |
| `-NoPaging` | Disables console paging. |
| `-Help` | Displays the built-in usage guide. |

## Examples

Review the local Exchange server:

```powershell
.\ExchangeReceiveConnectorManager.ps1
```

Review multiple servers:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -Server EX01,EX02
```

Create a TXT report and JSON backup:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -Server EX01 -OutputFile C:\Temp\EX01-ReceiveConnectors.txt
```

Preview cloning custom connectors:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02
```

Apply a reviewed clone plan for one connector:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02 -ConnectorName "App Relay" -ApplyChanges
```

Preview existing built-in connector alignment:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -IncludeBuiltIn
```

Preview anonymous relay alignment:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -IncludeAnonymousRelayPermissions
```

Preview a Restore operation:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX16-ReceiveConnectors.json -TargetServer EXSE01
```

Apply a Restore operation:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\ReceiveConnectors.json -SourceServer EX16-01 -TargetServer EXSE01 -ApplyChanges
```

Built-in help:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -Help
```

Full PowerShell help:

```powershell
Get-Help .\ExchangeReceiveConnectorManager.ps1 -Full
```

## Requirements

- Exchange Server Mailbox server environment
- Windows PowerShell 5.1
- Exchange Management Shell / required Exchange administrative permissions
- PowerShell remoting for remote server operations

## Notes

Version 1.0 was validated with live Clone and Restore scenarios including clean creation, existing-connector updates, idempotent re-runs, anonymous relay alignment, disabled connectors, FQDN translation, pre-change snapshots, BLOCKER zero-mutation behavior, and preservation of target values when a backup property is unavailable.

Always review the generated plan before using `-ApplyChanges`, and test the script in your environment before production use.

## Feedback and issues

For bugs, feedback, or feature requests, use [GitHub Issues](https://github.com/Ceyhun-Kirmizitas/ExchangeReceiveConnectorManager.ps1/issues).

Website: [ceyhunkirmizitas.net](https://ceyhunkirmizitas.net/)

## License

MIT. See [LICENSE](LICENSE).
