# Changelog

Changes to **ExchangeReceiveConnectorManager.ps1**.

## 1.1 - 2026-10-29

### New Features
- Added **RemoteIPRanges Merge Only** to add source IP ranges to an existing target connector without changing other settings.
- Added read-only **`-CheckRelay`** to review anonymous and externally secured relay configuration without testing mail flow.

### Changes
- Clone and cross-server Restore now preserve existing target **Bindings**. Same-server Restore still manages Bindings.
- Known binding problems now mark only the affected connector as **MANUAL**. Apply returns exit code **2** when manual work remains.
- With `-IncludeAnonymousRelayPermissions`, an explicit Deny on the source or target connector now blocks Apply.
- Failed anonymous relay verification now returns exit code **1**.
- The start prompt now accepts only ENTER to start or Q to quit.

### Improvements
- Clearer Bindings and anonymous relay information in Preview and Apply results.
- Restore now identifies same-server and cross-server operations.
- Improved console messages, help, and Feedback / Bugs / Contact information.

### Bug Fixes
- Fixed Clone and Restore failures caused by server-specific Receive Connector Bindings.
- Fixed source drift checks blocking Apply when unrelated connectors changed while `-ConnectorName` was used.

## 1.0 - 2026-09-27

### New Features
- Initial release with Receive Connector Review, Backup, Clone, and Restore.
- Added TXT reports, JSON backups, and explicit AD permission inventory.
- Added Preview-first Clone and Restore, with `-ApplyChanges` required to make changes.
- Added custom connector creation and optional alignment of existing built-in connectors.
- Added optional anonymous relay permission management.
- Added safety checks for Bindings, TLS certificates, connector conflicts, and incomplete backups.
- Added pre-change snapshots, drift detection, and post-change verification.
- New connectors are configured disabled and enabled after successful configuration.
- Added Windows PowerShell 5.1 compatibility handling, startup guidance, console paging, and help.
