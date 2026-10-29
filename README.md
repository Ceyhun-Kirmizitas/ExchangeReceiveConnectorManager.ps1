# ExchangeReceiveConnectorManager.ps1

During an Exchange migration, custom Receive Connectors such as application relay connectors have to be recreated on the new servers. Each one carries its own RemoteIPRanges, authentication, permission groups, TLS settings, and sometimes an explicit anonymous relay permission. Recreating them by hand is easy to get slightly wrong.

This script reads Receive Connectors from existing servers, can save their configuration as a backup, and shows exactly what would change on the target servers before anything is applied. It also helps you merge relay IP lists and check how relay is configured.

[Download the script](ExchangeReceiveConnectorManager.ps1) · [Changelog](CHANGELOG.md) · [Report an issue](https://github.com/Ceyhun-Kirmizitas/ExchangeReceiveConnectorManager.ps1/issues)

## What it does

| Mode | What it is for |
|---|---|
| **Review / Backup** (default) | Read Receive Connectors on one or more servers. With `-OutputFile`, saves a TXT report and a JSON backup. Read-only. |
| **Clone** | Compare connectors on a live source server with one or more target servers, then create or update them. |
| **Restore** | Restore connectors from a JSON backup to the same server after a rebuild, or to a different server. |
| **RemoteIPRanges Merge Only** | Add IP ranges from selected source connectors to one existing target connector. Nothing else is changed. |
| **CheckRelay** | Report anonymous and externally secured relay configuration per connector. Read-only; no mail is sent. |

Clone, Restore, and Merge only show a plan by default. Nothing changes until you add `-ApplyChanges` and confirm.

## Examples

Review the local server:

```powershell
.\ExchangeReceiveConnectorManager.ps1
```

Back up a server (TXT report + JSON backup):

```powershell
.\ExchangeReceiveConnectorManager.ps1 -Server EX01 -OutputFile C:\Temp\EX01-ReceiveConnectors.txt
```

Preview cloning connectors from an old server to new servers:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01,EXSE02
```

Clone one connector. The explicit anonymous relay permission is not copied:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -ApplyChanges
```

Clone one connector and also copy the explicit anonymous relay permission:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -TargetServers EXSE01 -ConnectorName "App Relay" -IncludeAnonymousRelayPermissions -ApplyChanges
```

Preview restoring a backup to a different server:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX16-01-ReceiveConnectors.json -TargetServer EXSE01
```

Restore a rebuilt server from its own backup (Bindings included):

```powershell
.\ExchangeReceiveConnectorManager.ps1 -RestoreFile C:\Temp\EX01-ReceiveConnectors.json -TargetServer EX01 -ApplyChanges
```

Preview merging two relay connectors' IP ranges into one existing connector:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -SourceServer EX16-01 -ConnectorName "App Relay 1","App Relay 2" -TargetServer EXSE01 -TargetConnectorName "App Relay" -RemoteIPRangesMergeOnly
```

Check relay configuration on two servers:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -CheckRelay -Server EX01,EX02
```

More options and examples:

```powershell
.\ExchangeReceiveConnectorManager.ps1 -Help
Get-Help .\ExchangeReceiveConnectorManager.ps1 -Full
```

## Good to know

- **Preview first.** Clone, Restore, and Merge change nothing without `-ApplyChanges`. `-OutputFile` only saves the plan; with `-ApplyChanges`, changes are still applied after confirmation.
- **Bindings.** Clone and cross-server Restore never change the Bindings of an existing target connector. A new connector is created only if its Bindings are valid on the target. Same-server Restore restores Bindings.
- **MANUAL and BLOCKER.** A connector with a known binding problem, such as a missing IP on the target, is marked MANUAL and skipped; the others continue. A BLOCKER, such as an unknown binding check or a missing TLS certificate, stops the entire Apply before anything is changed.
- **Built-in connectors** are never created or deleted. Use `-IncludeBuiltIn` only if you want to align existing ones.
- **Anonymous relay.** Without `-IncludeAnonymousRelayPermissions`, the explicit AD relay permission (`ms-Exch-SMTP-Accept-Any-Recipient` for `ANONYMOUS LOGON`) is not copied, added, or removed. With the switch, it is added or removed to match the source or backup, and an explicit Deny blocks the Apply. Either way, **PermissionGroups** (including AnonymousUsers) is copied like any other setting, so check the plan.
- **Merge.** The target connector must already exist. New IP addresses get whatever the target connector already allows, including relay. Listener overlap and entry count are checked before Apply.
- **Backups and snapshots.** Restore accepts JSON only. Use `-SourceServer` when the backup contains more than one server. Before every Apply, a JSON snapshot of the target is saved in the `ConfigSnapshots` folder next to the script.
- **After Apply.** New connectors are created disabled and enabled only after their settings succeed. Apply stops on the first error, and the result is verified.
- **CheckRelay** looks at configuration and explicit (non-inherited) AD permissions only. It does not test SMTP relay.

## Exit codes

| Mode | 0 | 1 | 2 |
|---|---|---|---|
| Review, Clone, Restore, Merge | Completed or preview | Error, BLOCKER, drift, or verification failure | Apply completed, MANUAL connectors remain |
| CheckRelay | Completed, including findings | Error (other servers are still checked) | — |

A preview returns 0 even when it shows BLOCKER or MANUAL items, so always read the plan.

## Requirements

- Exchange Server 2016, Exchange Server 2019, or Exchange Server Subscription Edition (Mailbox role)
- Windows PowerShell 5.1, run on an Exchange server. The script loads Exchange Management Shell itself.
- Exchange permissions to read and change Receive Connectors and their AD permissions on the servers involved

The script does not handle Send Connectors, firewall or load balancer rules, or certificates. It does not send test mail. Test in your own environment before using it in production.

## Feedback

Found a bug or have a suggestion? Open a [GitHub issue](https://github.com/Ceyhun-Kirmizitas/ExchangeReceiveConnectorManager.ps1/issues).

[ceyhunkirmizitas.net](https://ceyhunkirmizitas.net/) · [GitHub](https://github.com/Ceyhun-Kirmizitas) · [LinkedIn](https://www.linkedin.com/in/ceyhun-kirmizitas/)

## License

MIT. See [LICENSE](LICENSE).