# Faza 0 - Krok 16: commissioning runtime diagnostics + C6 flash path

## Cel

Dostarczyc minimalna diagnostyke runtime commissioning w API `umatter.Node` oraz domknac walidacje build/flash/smoke dla `ESP32_GENERIC_C6` na `COM11`.

## Co zostalo dodane/zmienione

1. Runtime diagnostics w `umatter.Node`:
   - `set_transport(mode)`
   - `transport()`
   - `commissioning_ready()`
   - `commissioning_diagnostics()`
2. Rozszerzenie prostego API:
   - `umatter.Light(..., transport="wifi" | "thread" | "dual" | "none")`
3. Core API i binding:
   - `umatter_core_set_transport`
   - `umatter_core_get_transport`
   - `umatter_core_commissioning_ready`
   - stale transportu `TRANSPORT_NONE/WIFI/THREAD/DUAL`
4. Poprawka toolingu build/flash:
   - `scripts/phase0_step02_c5_e2e.ps1` dobiera `--chip` do `esptool` na podstawie `-Board` (m.in. C6/C5).

## Walidacja

1. Build C6:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step16b-buildonly `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -SkipFlash -SkipSmoke
```

2. Flash C6 (po poprawce skryptu, auto `chip=esp32c6`):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step16b-buildonly `
  -ArtifactsRoot artifacts/esp32c6 `
  -SkipBuild -SkipSmoke
```

3. Smoke commissioning runtime diagnostics:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step16c `
  -EndpointId 9 `
  -Passcode 24681357 `
  -Discriminator 1234
```

## Kryterium zaliczenia

1. Build `ESP32_GENERIC_C6` przechodzi.
2. Flash na `COM11` przechodzi skryptem fazowym (bez recznego `esptool`).
3. Smoke `step16` zwraca `HOST_C16_PASS`.

## Nastepny krok

1. Przejsc z `runtime=placeholder` do realnego flow commissioning i ponowic gate `chip-tool -RunPairing`.
