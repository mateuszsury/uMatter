# uMatter

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

uMatter is a MicroPython + Matter integration project for ESP32-class boards, focused on practical embedded delivery from PoC to release.

Note: workflow templates are currently stored in `.github/workflows-disabled/`.
Move them to `.github/workflows/` after enabling GitHub token scope `workflow`.

Current repository status: active Phase 0 implementation with hardware-validated build/flash/test flow on ESP32-C5/C6.

## Key Goals

- Build a usable Matter runtime for MicroPython on ESP32.
- Provide a simple API (`umatter.Light(...)`) and an advanced API (`Node`, `Endpoint`, `Cluster`).
- Keep build and flashing reproducible across WSL + Windows PowerShell.
- Evolve toward release-grade CI, artifact integrity, and certification-readiness evidence.

## What Is Implemented Today

- Native user C module scaffold (`modules/umatter`).
- Core runtime model with nodes, endpoints, clusters, commissioning data, and transport state.
- Host-driven build and flash automation scripts.
- Phase-by-phase technical docs and reports with real artifacts.

See:
- `docs/README.md`
- `docs/phase-0/`
- `reports/phase-0/`

## Repository Layout

```text
agents/                Agent contracts by domain
modules/umatter/       Native MicroPython C module (core + bindings)
scripts/               Build/flash/smoke and commissioning utilities
docs/                  Technical documentation and phase implementation notes
reports/               Validation reports and risks per step
artifacts/             Local output artifacts (ignored by git except metadata)
plan.md                Main product and architecture plan
mp_skill.md            Build/flash/test workflow (WSL + PowerShell)
AGENTS.md              Orchestration and agent usage policy
```

## Quick Start (Windows + WSL)

1. Run environment preflight:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_preflight.ps1
```

2. Build/flash/smoke for ESP32 target:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -ArtifactsRoot artifacts/esp32c6
```

3. Run commissioning runtime diagnostics smoke:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11
```

## Supported Development Flow

- Build: WSL (ESP-IDF + MicroPython sources/worktrees)
- Flash/device ops: Windows PowerShell (`esptool`, `mpremote`)
- Concurrency-safe builds: unique `BuildInstance` and isolated worktrees/build directories

## Documentation Map

- Product scope and architecture: `plan.md`
- Build workflow: `mp_skill.md`
- Agent execution model: `AGENTS.md`, `agents/`
- Implementation notes by phase: `docs/phase-0/`
- Validation reports: `reports/phase-0/`
- Contribution process: `CONTRIBUTING.md`
- Security policy: `SECURITY.md`

## Roadmap

Roadmap phases are tracked in `plan.md`:

1. Phase 0: PoC
2. Phase 1: MVP
3. Phase 2: Completeness
4. Phase 3: Appliances and Energy
5. Phase 4: Advanced + 2.x release

## License

This project is licensed under the Apache License 2.0.
See `LICENSE`.
