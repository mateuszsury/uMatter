# Architecture Overview

uMatter uses a layered model:

1. MicroPython-facing API layer (`umatter` module contract)
2. Native binding layer (`modules/umatter/src/mod_umatter*.c`)
3. Core runtime model (`modules/umatter/src/umatter_core_runtime.c`)
4. ESP-IDF + Matter stack integration (planned expansion)

## Runtime Responsibilities

- Node lifecycle management (`create/start/stop/destroy`)
- Endpoint and cluster registration
- Commissioning data exposure (passcode/discriminator/manual/qr)
- Transport mode state (`none`, `wifi`, `thread`, `dual`)
- Commissioning readiness signal (`started + endpoint + transport`)

## Build Architecture

- WSL builds isolated by unique worktree and build directory.
- PowerShell handles flashing and device-side smoke flow.
- Artifacts are emitted into instance-specific directories under `artifacts/`.

See:
- [Public roadmap and current acceptance gates](ROADMAP.md)
- [Build/flash/test workflow](../mp_skill.md)
- [MicroPython build script](../scripts/wsl_build_micropython_c5.sh)

