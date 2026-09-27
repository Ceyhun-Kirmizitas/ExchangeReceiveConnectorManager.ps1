# Changelog

All notable changes to **ExchangeReceiveConnectorManager.ps1** are documented here.

## 1.0 - 2026-09-27

- Initial release of ExchangeReceiveConnectorManager.ps1.
- Added local and multi-server Receive Connector review with human-readable TXT reporting and structured JSON backup.
- Added live server-to-server Clone Preview and JSON-based Restore Preview with explicit `-ApplyChanges` for changes.
- Added custom connector creation and supported property alignment for existing connectors.
- Added optional alignment of existing built-in connectors with `-IncludeBuiltIn`; built-in connectors are never created or deleted.
- Added explicit Receive Connector AD permission inventory and optional anonymous relay alignment with `-IncludeAnonymousRelayPermissions`.
- Added target binding, TLS certificate, connector-type, and name-collision safety validation.
- Added refreshed pre-apply planning, drift detection, automatic target pre-change JSON snapshots, and post-apply verification.
- Added whole-plan BLOCKER handling so Apply stops before any change when a selected connector is unsafe to process.
- New custom connectors are created disabled, configured while disabled, and enabled only after all managed settings and permissions succeed.
- Missing backup properties are treated as unavailable so existing target values are preserved instead of being cleared.
- Added Windows PowerShell 5.1 compatibility handling for Exchange Management Shell initialization, remoting serialization, null/empty values, flags, and collections.
- Added startup safety information, console paging, `-NoPaging`, built-in `-Help`, and comment-based help examples.
