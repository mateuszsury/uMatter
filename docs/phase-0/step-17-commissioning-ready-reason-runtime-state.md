# Faza 0 - Krok 17: commissioning ready reason + runtime state diagnostics

## Cel

Rozszerzyc diagnostyke commissioning o deterministyczna przyczyne gotowosci (`ready_reason`) i realny stan runtime zamiast pola placeholder.

## Co zostalo dodane/zmienione

1. Core runtime (`umatter_core`):
   - nowe stale:
     - `READY_REASON_READY`
     - `READY_REASON_TRANSPORT_NOT_CONFIGURED`
     - `READY_REASON_NO_ENDPOINTS`
     - `READY_REASON_NODE_NOT_STARTED`
   - nowe API:
     - `umatter_core_commissioning_ready_reason(handle)`
2. Binding `_umatter_core`:
   - nowa funkcja:
     - `commissioning_ready_reason(handle)` -> kod int
   - wyeksportowane stale `READY_REASON_*`
3. Python API `umatter.Node`:
   - nowa metoda:
     - `commissioning_ready_reason()` -> string
   - `commissioning_diagnostics()` rozszerzone o:
     - `runtime` (`awaiting_transport`, `awaiting_endpoint`, `awaiting_start`, `commissioning_ready`)
     - `ready_reason` (string)
     - `ready_reason_code` (int)
4. Smoke host:
   - `scripts/phase0_step16_commissioning_runtime_diag.ps1` zaktualizowany o markery dla `ready_reason` i nowych stanow runtime.

## Walidacja

1. Build-only C6:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step17-buildonly `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -SkipFlash -SkipSmoke
```

2. Flash C6:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step17 `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -SkipSmoke
```

3. Runtime diagnostics smoke:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step17 `
  -EndpointId 9 `
  -Passcode 24681357 `
  -Discriminator 1234
```

## Kryterium zaliczenia

1. C6 build przechodzi po zmianach API i core.
2. `commissioning_diagnostics()` zwraca realny runtime i przyczyne gotowosci.
3. Smoke zwraca `HOST_C16_PASS` i potwierdza markery `ready_reason`.

## Nastepny krok

1. Wpiac `ready_reason` do gate `chip-tool` jako dodatkowy sygnal diagnostyczny przed probe pairing.
2. Przejsc do realnego commissioning runtime e2e (Thread/WiFi + mDNS flow) i ponowic `-RunPairing`.

