# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

### Added

- Project-level repository governance files (`README`, `LICENSE`, `CONTRIBUTING`, `SECURITY`, CI templates).
- Phase 0 documentation and report index.

### Changed

- `scripts/phase0_step02_c5_e2e.ps1` now resolves `esptool --chip` from board type (C5/C6/etc).

## [0.1.0] - 2026-02-11

### Added

- Phase 0 baseline implementation and validation pipeline.
- Core native module skeleton (`modules/umatter`) with runtime node/endpoint/cluster model.
- Commissioning and transport diagnostics API in `umatter.Node`.
- ESP32-C6 build/flash/smoke validated on hardware (`COM11`) with commissioning runtime smoke markers.

