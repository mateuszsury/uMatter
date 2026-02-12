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
- Phase 0 step-24 discovery-required gate (`RequireDiscoveryFoundForPairing`) with deterministic `blocked_discovery_not_found` status and step19 propagation.
- Phase 0 step-25 Python mock gateway discovery harness (`scripts/mock_matter_gateway.py`, `phase0_step25_mock_gateway_discovery.ps1`) and discovery fallback in step12 (`discover commissionables`).
- Phase 0 step-26 virtual Matter device pairing runner (`phase0_step26_virtual_device_pairing.ps1`) validating `gate_status=pass` with `chip-all-clusters-app`.
- Phase 0 step-27 runtime mDNS hook for commissionable advertisement in core (`umatter_core_runtime.c`) with ESP-side publish/unpublish reconciliation.
- Phase 0 step-28 extended network advertising diagnostics (`mdns_published`, `mdns_last_error`, `manual_override`) in runtime and Python APIs.
- Phase 0 step-29 ESP compile-path fix for user module (`ESP_PLATFORM=1` in `micropython.cmake`) to keep runtime on native mDNS path.
- Phase 0 step-30 runtime commissionable mDNS subtype publishing (`_L...`, `_S...`) with rollback on subtype registration failure.
- Phase 0 step-31 chip-tool WSL auto-detection in step12 (PATH + env + common HOME candidates), removing false `unavailable_tool` when binary exists outside PATH.
- Phase 0 step-32 host-side mDNS commissionable probe (`host_mdns_commissionable_probe.py`) integrated into step12 and propagated by step19 (`host_mdns_probe_*` diagnostics).
- Phase 0 step-33 dual host mDNS probe mode in step12/step19 (`HostMdnsProbeMode=wsl|windows|both`) with per-mode diagnostics (`host_mdns_probe_wsl_*`, `host_mdns_probe_windows_*`).

### Changed

- `scripts/phase0_step02_c5_e2e.ps1` now resolves `esptool --chip` from board type (C5/C6/etc).
- `scripts/phase0_step12_chiptool_gate.ps1` now parses runtime diagnostics logs and blocks `-RunPairing` when runtime is not ready.
- `scripts/phase0_step12_chiptool_gate.ps1` now supports optional `RequireNetworkAdvertisingForPairing` and `blocked_network_not_advertising`.
- `scripts/phase0_step19_commissioning_gate_e2e.ps1` now propagates network-gate settings and outputs `gate_network_*` fields.
- `scripts/phase0_step12_chiptool_gate.ps1` now supports optional chip-tool discovery precheck (`RunDiscoveryPrecheck`, `DiscoveryTimeoutSeconds`) before pairing.
- `scripts/phase0_step16_commissioning_runtime_diag.ps1` now accepts both valid runtime network-advertising outcomes: `False/not_integrated` and `True/signal_present`.
- `scripts/phase0_step02_c5_e2e.ps1` smoke phase now retries `mpremote` (`SmokeRetries`, `SmokeRetryDelaySeconds`) to reduce false negatives after reset.
- `scripts/phase0_step16_commissioning_runtime_diag.ps1` now validates mDNS advertising diagnostics and `_umatter_core.get_network_advertising_details(...)`.
- `modules/umatter/micropython.cmake` now forces `ESP_PLATFORM=1` for `usermod_umatter`, removing non-ESP fallback behavior in mixed build stages.

## [0.1.0] - 2026-02-11

### Added

- Phase 0 baseline implementation and validation pipeline.
- Core native module skeleton (`modules/umatter`) with runtime node/endpoint/cluster model.
- Commissioning and transport diagnostics API in `umatter.Node`.
- ESP32-C6 build/flash/smoke validated on hardware (`COM11`) with commissioning runtime smoke markers.
