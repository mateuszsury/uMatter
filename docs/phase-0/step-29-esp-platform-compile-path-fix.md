# Faza 0 - Krok 29: wymuszenie ESP compile path dla user module

## Cel

Usunac niejednoznacznosc kompilacji `umatter_core_runtime.c`, w ktorej jeden z etapow budowy nie mial `ESP_PLATFORM`, co prowadzilo do fallback path (`mdns_last_error=-2`) zamiast realnej sciezki ESP.

## Co zostalo dodane/zmienione

1. `modules/umatter/micropython.cmake`
   - dodane:
     - `target_compile_definitions(usermod_umatter INTERFACE ESP_PLATFORM=1)`
   - efekt:
     - oba etapy kompilacji user modułu przechodza przez sciezke ESP (`mdns`),
     - znika fallback non-ESP na firmware C6.

## Walidacja

1. Build + flash C6:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -IdfRootWsl /home/thete/esp-idf-5.5.1 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step29-espflag `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -ArtifactsRoot artifacts/esp32c6
```

2. Potwierdzenie compile flags (WSL `compile_commands.json`):
   - wpisy dla `umatter_core_runtime.c` zawieraja `-DESP_PLATFORM=1`.

3. Runtime diagnostics (default):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step29-default-r2
```

4. Runtime diagnostics (symulacja):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step29-sim `
  -SimulateNetworkAdvertising
```

5. Gate pairing (network required):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step29-default-r2/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireRuntimeReadyForPairing true `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -Instance c12-com11-step29-netgate
```

## Kryterium zaliczenia

1. Domyslny runtime nie raportuje fallback `mdns_last_error=-2`.
2. `network_advertising=True` i `network_advertising_reason=signal_present` bez symulacji.
3. `RequireNetworkAdvertisingForPairing=true` nie blokuje juz pairing (brak `blocked_network_not_advertising`).

## Nastepny krok

1. Domknac discovery na realnym firmware (`discovery_precheck_status=found`).
2. Doprowadzic pairing do `status=pass` bez virtual device.
