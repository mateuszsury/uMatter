# Development Guide

## Recommended Environment

- Host: Windows (PowerShell)
- Build: WSL (Ubuntu + ESP-IDF)
- Device operations: `python -m esptool`, `python -m mpremote`

## Standard Loop

1. Preflight:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_preflight.ps1
```

2. Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -Board ESP32_GENERIC_C6 -ComPort COM11 -SkipFlash -SkipSmoke
```

3. Flash + smoke:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -Board ESP32_GENERIC_C6 -ComPort COM11 -SkipBuild
```

4. Commissioning diagnostics smoke:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11
```

## Concurrent Build Safety

- Always use unique `BuildInstance` values.
- Keep separate artifact roots when running parallel sessions.
- Do not share mutable build directories across active processes.

