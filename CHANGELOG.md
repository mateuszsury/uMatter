# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

### Added

- Project-level repository governance files (`README`, `LICENSE`, `CONTRIBUTING`, `SECURITY`, CI templates).
- Phase 0 documentation and report index.
- Commissioning diagnostics step-17: ready-reason state model in core and Python API (`ready_reason`, `ready_reason_code`, runtime state mapping).
- Phase 0 step-18 notes/report for runtime-ready chip-tool gate integration.
- Phase 0 step-19 e2e runner (`scripts/phase0_step19_commissioning_gate_e2e.ps1`) to chain runtime diagnostics and chip-tool gate.
- Phase 0 step-20 network diagnostics fields (`network_advertising`, `network_advertising_reason`) in commissioning diagnostics.
- Phase 0 step-21 discovery precheck fields (`discovery_precheck_*`) in chip-tool gate and e2e runner.
- Phase 0 step-22 runtime advertising contract in core (`set/get_network_advertising`, reason codes) with diagnostics wired to core state.
- Phase 0 step-23 `umatter.Node` advertising hook (`set_network_advertising`, `network_advertising`) and step16 simulation mode for positive gate path checks.

### Changed

- `scripts/phase0_step02_c5_e2e.ps1` now resolves `esptool --chip` from board type (C5/C6/etc).
- `scripts/phase0_step12_chiptool_gate.ps1` now parses runtime diagnostics logs and blocks `-RunPairing` when runtime is not ready.
- `scripts/phase0_step12_chiptool_gate.ps1` now supports optional `RequireNetworkAdvertisingForPairing` and `blocked_network_not_advertising`.
- `scripts/phase0_step19_commissioning_gate_e2e.ps1` now propagates network-gate settings and outputs `gate_network_*` fields.
- `scripts/phase0_step12_chiptool_gate.ps1` now supports optional chip-tool discovery precheck (`RunDiscoveryPrecheck`, `DiscoveryTimeoutSeconds`) before pairing.

## [0.1.0] - 2026-02-11

### Added

- Phase 0 baseline implementation and validation pipeline.
- Core native module skeleton (`modules/umatter`) with runtime node/endpoint/cluster model.
- Commissioning and transport diagnostics API in `umatter.Node`.
- ESP32-C6 build/flash/smoke validated on hardware (`COM11`) with commissioning runtime smoke markers.
