# Public Roadmap

uMatter is an **experimental Phase 0 proof of concept**. This roadmap summarizes
the checked-in implementation and validation reports. Planned phases are goals,
not declarations of supported Matter features or certification.

## Current Evidence and Open Work

- The native module, node/endpoint/cluster model, commissioning diagnostics and
  host automation are present in the repository.
- Recorded ESP32-C5/C6 build, flash and smoke results are summarized in the
  [hardware matrix](HARDWARE_MATRIX.md) and the [Phase 0 reports](../reports/phase-0/).
- The latest recorded real-device discovery probes return `not_found` on both
  Windows and WSL. Runtime-ready and mDNS publication telemetry do not establish
  successful controller discovery or Matter commissioning.
- A successful pairing experiment using the reference virtual Matter device is
  documented separately in [step 26](phase-0/step-26-virtual-matter-device-pairing-pass.md).
  It does not prove pairing of the uMatter firmware.
- Repository CI checks documentation and script syntax. It does not build the
  firmware, exercise a radio, or certify Matter interoperability.

## Milestones

| Phase | Status | Intended outcome and acceptance evidence |
|---|---|---|
| 0 — Proof of concept | In progress | Reproducible build/flash/smoke flow; diagnose discovery on real ESP32 firmware; record successful end-to-end controller commissioning before closing the phase. |
| 1 — Minimum viable product | Planned | A usable basic device API on a documented board/transport baseline, with commissioning and lifecycle regression evidence. |
| 2 — Completeness | Planned | Expand the supported API and test matrix; publish an explicit support/limitation table and memory measurements for each claimed profile. |
| 3 — Appliances and energy | Future scope | Evaluate additional device types and clusters against the stable runtime, with hardware and controller interoperability tests for any support claims. |
| 4 — Advanced features and 2.x | Future scope | Select advanced functionality after earlier acceptance gates; prepare repeatable release artifacts, compatibility evidence and upgrade guidance. |

## Next Phase 0 Gate

1. Reproduce real-device mDNS visibility with per-interface host diagnostics.
2. Correlate controller discovery with firmware publication state and timing.
3. Complete commissioning with an identified controller and actual uMatter board.
4. Record toolchain revisions, board/profile, commands, logs and unresolved risks
   in a new validation report. Keep simulated and real-device outcomes separate.

See the [architecture](ARCHITECTURE.md), [development guide](DEVELOPMENT.md) and
[release process](RELEASE.md) for implementation and evidence requirements.
Historical reports describe the environments used at the time; their local
paths and results are records, not required paths for a new checkout.
