# ExchangeReceiveConnectorManager.ps1

A Windows PowerShell 5.1 tool for reviewing, backing up, cloning, restoring, and managing **Exchange Server Receive Connectors**. Useful when moving to new Exchange servers, replacing a server, or reviewing relay configuration.

[Download the script](ExchangeReceiveConnectorManager.ps1) · [Changelog](CHANGELOG.md) · [Report an issue](https://github.com/Ceyhun-Kirmizitas/ExchangeReceiveConnectorManager.ps1/issues)

## What it does

| Mode | Purpose |
|---|---|
| **Review / Backup** | Review Receive Connectors on one or more servers. `-OutputFile` writes a readable TXT report and a JSON backup for Restore. |
| **Clone** | Compare connectors on a live source server with one or more target servers, then apply supported changes if requested. |
| **Restore** | Restore supported settings from a JSON backup. Same-server Restore manages Bindings; cross-server Restore preserves existing target Bindings. |
| **RemoteIPRanges Merge Only** | Add IP ranges from selected custom source connectors to one existing custom target connector. Other settings are not changed. |
| **CheckRelay** | Read-only review of anonymous and externally secured relay configuration per connector. It does not send mail or test SMTP relay. |

Review, Clone, Restore, and Merge are **preview-only by default**. To change a target, add `-ApplyChanges` and confirm the displayed plan. `-CheckRelay` is always read-only.

## Examples

Run these commands from a server with the required Exchange permissions. The script can load Exchange Management Shell on an Exchange server.

**Review the local server:**

```powershell
.\ExchangeReceiveConnectorManager.ps1
```

**Back up a server (TXT + JSON):**

```powershell
.\ExchangeReceiveConnectorManager.ps1 -Server EX01 -OutputFile C:\Temp\EX01-ReceiveConnectors.txt
```

**Preview cloning connectors to new servers:**

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02
```

**Clone one connector without copying its explicit anonymous relay AD permission:**

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -ApplyChanges
```

**Clone with explicit anonymous relay permission handling:**

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -IncludeAnonymousRelayPermissions -ApplyChanges
```

**Preview a Restore to a new server:**

```powershell
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX16-01-ReceiveConnectors.json -TargetServer EXSE01
```

**Restore a rebuilt server using its JSON backup:**

```powershell
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX01-ReceiveConnectors.json -TargetServer EX01 -ApplyChanges
```

**Preview merging IP ranges into an existing connector:**

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -ConnectorName "App Relay 1","App Relay 2" -TargetServer EXSE01 -TargetConnectorName "App Relay" -RemoteIPRangesMergeOnly
```

**Review relay configuration on two servers:**

```powershell
.\ExchangeReceiveConnectorManager.ps1 -CheckRelay -Server EX01,EX02
```

For full options and additional examples:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -Help
Get-Help .\ExchangeReceiveConnectorManager.ps1 -Full
```

## Important behavior

- **Preview before Apply:** Clone, Restore, and Merge require `-ApplyChanges` and confirmation to change anything. An Apply run with `-OutputFile` can still make changes; the file is not a report-only switch.
- **Bindings:** Existing target Bindings are preserved during Clone and cross-server Restore. Same-server Restore can restore Bindings. Binding problems may require manual action; an unknown safety check may block Apply.
- **Built-in connectors:** Never created or deleted. Use `-IncludeBuiltIn` only when you want to align existing built-in connectors.
- **Anonymous relay:** Without `-IncludeAnonymousRelayPermissions`, the explicit AD relay permission is not copied, added, or removed. However, **PermissionGroups** (including `AnonymousUsers`) is still managed and can affect effective relay behavior. With the switch, explicit Allow permissions can be aligned; an explicit Deny blocks Apply.
- **IP range merge:** The target connector must already exist. Adding IP addresses can give those clients access to permissions already granted on the target connector. Listener overlap and entry-count limits are checked.
- **Backups:** Restore uses JSON files, not TXT. Before Apply, a fresh JSON snapshot is saved under `ConfigSnapshots` next to the script.
- **Verification:** New connectors are created disabled and enabled after supported changes succeed. Apply stops on the first connector error and verifies the resulting configuration.
- **CheckRelay:** Reports configured relay settings and explicit AD permissions; it does not perform an SMTP relay test.

**Exit codes:** For Review/Clone/Restore/Merge: 0 = completed/preview; 1 = error or failed Apply; 2 = Apply completed with MANUAL items. A Preview can return 0 even when BLOCKER or MANUAL items are shown. For CheckRelay: 0 = completed, including findings; 1 = execution error.

## Requirements

- Exchange Server 2016, Exchange Server 2019, or Exchange Server Subscription Edition (Mailbox role)
- Windows PowerShell 5.1
- Required Exchange administrative permissions and access to the target servers

The tool does not manage Send Connectors, firewall/NAT rules, certificates, or test SMTP delivery. Review the plan and test changes in your environment before production use.

## Feedback

For problems or suggestions, use [GitHub Issues](https://github.com/Ceyhun-Kirmizitas/ExchangeReceiveConnectorManager.ps1/issues).

Website: [ceyhunkirmizitas.net](https://ceyhunkirmizitas.net/) · [GitHub](https://github.com/Ceyhun-Kirmizitas) · [LinkedIn](https://www.linkedin.com/in/ceyhun-kirmizitas/)

## License

MIT. See [LICENSE](LICENSE).
