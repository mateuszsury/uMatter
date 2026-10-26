# Development Guide

## Recommended Environment

- Host: Windows (PowerShell)
- Build: WSL (Ubuntu + ESP-IDF)
- Device operations: `python -m esptool`, `python -m mpremote`

## Local Tool Paths

The scripts do not require a particular Windows or WSL user name. Configure the
paths to tools you have built in your WSL installation, for example:

```powershell
$wslHome = (& wsl.exe bash -lc 'printf "%s" "$HOME"').Trim()
$env:UMATTER_IDF_ROOT_WSL = "$wslHome/esp-idf-5.5.1"
$env:UMATTER_CHIP_TOOL_WSL = "$wslHome/umatter-work/connectedhomeip/out/chip-tool/chip-tool"
$env:UMATTER_VIRTUAL_DEVICE_WSL = "$wslHome/umatter-work/connectedhomeip/out/all-clusters/chip-all-clusters-app"
```

These are example layouts, not downloads performed by the PowerShell wrappers.
Pass `-IdfRootWsl`, `-ChipToolWslPath` or `-VirtualDeviceAppWslPath` to override
them. The MicroPython build helper uses its WSL-home default when the IDF root
is omitted. The commissioning gate can auto-detect `chip-tool` for normal gate
and mock-gateway runs; the virtual-device runner requires explicit paths or
the environment variables above. Substitute the actual serial port for `COM11`.

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

5. Commissioning gate e2e (runtime diag + chip-tool gate):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step20/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath $env:UMATTER_CHIP_TOOL_WSL
```

6. Commissioning gate z network advertising gate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -ComPort COM11 `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath $env:UMATTER_CHIP_TOOL_WSL
```

7. Commissioning gate z discovery precheck:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step20/serial_commissioning_runtime_diag.log `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath $env:UMATTER_CHIP_TOOL_WSL
```

## Concurrent Build Safety

- Always use unique `BuildInstance` values.
- Keep separate artifact roots when running parallel sessions.
- Do not share mutable build directories across active processes.
