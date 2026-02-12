# Faza 0 - Krok 28: rozszerzona diagnostyka mDNS dla network advertising

## Cel

Dodac obserwowalnosc stanu `_matterc._udp` w runtime, aby jasno rozroznic:

1. brak integracji/reklamy (`not_integrated`),
2. reklame wymuszona manualnie,
3. reklame wynikajaca z runtime mDNS.

## Co zostalo dodane/zmienione

1. `modules/umatter/src/umatter_core_runtime.c`
   - dodane pola runtime per-node:
     - `network_advertising_manual_override`
     - `network_advertising_mdns_published`
     - `network_advertising_mdns_last_error`
   - rozszerzona logika publish:
     - zapisuje kod bledu z `mdns_init`/`mdns_service_add`,
     - rozroznia ownership uslugi i bledy stanu.
   - dodane API:
     - `umatter_core_get_network_advertising_details(...)`
       zwraca: advertising, reason, mdns_published, mdns_last_error, manual_override.

2. `modules/umatter/include/umatter_core.h`
   - deklaracja `umatter_core_get_network_advertising_details(...)`.

3. `modules/umatter/src/mod_umatter.c`
   - `Node.commissioning_diagnostics()` zwraca dodatkowo:
     - `network_advertising_manual_override`
     - `network_advertising_mdns_published`
     - `network_advertising_mdns_last_error`

4. `modules/umatter/src/mod_umatter_core.c`
   - nowa funkcja low-level:
     - `_umatter_core.get_network_advertising_details(handle)`
       -> `(advertising, reason, mdns_published, mdns_last_error, manual_override)`

5. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
   - rozszerzone markery testowe o pola `*_mdns_*` i `*_manual`.
   - walidacja wariantowa:
     - path fallback: `False/not_integrated`, `mdns_published=False`, `mdns_last_error=<nonzero>`
     - path integrated: `True/signal_present`, `mdns_published=True`, `mdns_last_error=0`

## Walidacja

1. Build + flash C6:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -IdfRootWsl /home/thete/esp-idf-5.5.1 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step28-mdnsdiag `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -ArtifactsRoot artifacts/esp32c6
```

2. Runtime diagnostics (default):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step28-mdnsdiag-r2
```

3. Runtime diagnostics (symulacja):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step28-mdnsdiag-sim `
  -SimulateNetworkAdvertising
```

4. Gate network (default log):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step28-mdnsdiag-r2/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireRuntimeReadyForPairing true `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -Instance c12-com11-step28-netgate
```

## Kryterium zaliczenia

1. Diagnostyka zwraca pelny stan advertising (reason + mdns + override).
2. Step16 przechodzi dla default i symulacji z nowymi markerami.
3. Gate network zachowuje sie deterministycznie:
   - default -> `blocked_network_not_advertising`
   - symulacja -> brak blokady network gate.

## Nastepny krok

1. Podlaczyc realne eventy commissioning/transport do publikacji mDNS tak, aby `mdns_published=True` bez symulacji.
2. Domknac discovery `found` i pairing PASS na realnym firmware C6.
