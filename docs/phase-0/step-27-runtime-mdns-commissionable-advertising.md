# Faza 0 - Krok 27: runtime mDNS commissionable advertising hook

## Cel

Podpiac sygnal `network_advertising` do realnej proby publikacji service `_matterc._udp` w runtime ESP32 oraz utrzymac stabilny workflow build/flash/test.

## Co zostalo dodane/zmienione

1. `modules/umatter/src/umatter_core_runtime.c`
   - dodana warstwa ESP-only oparta o `mdns`:
     - `umatter_core_publish_commissionable(...)`
     - `umatter_core_unpublish_commissionable(...)`
   - `umatter_core_reconcile_network_advertising(...)`:
     - publikuje `_matterc._udp` po wejsciu w stan commissioning-ready,
     - unpublikuje przy stop/destroy lub utracie gotowosci,
     - mapuje wynik na:
       - `signal_present` (publikacja sukces),
       - `not_integrated` (publikacja nieudana),
       - `runtime_not_ready` (node niegotowy).
   - reconcile dostaje teraz `handle`, aby poprawnie zarzadzac ownership uslugi mDNS.

2. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
   - test akceptuje teraz oba legalne warianty runtime bez symulacji:
     1. `network_advertising=False`, reason=`not_integrated`
     2. `network_advertising=True`, reason=`signal_present`
   - analogiczna walidacja dla `Node`, `Light` i niskopoziomowego `core`.

3. `scripts/phase0_step02_c5_e2e.ps1`
   - smoke po flashu ma retry (`SmokeRetries`, `SmokeRetryDelaySeconds`), aby ograniczyc falszywe fail po restarcie urzadzenia.

4. `docs/HARDWARE_MATRIX.md`
   - notatka o `network_advertising` zaktualizowana z jednego stalego stanu na kontrakt dwuwariantowy runtime.

## Walidacja

1. Build + flash C6:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -IdfRootWsl /home/thete/esp-idf-5.5.1 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step27-mdnsadv `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -ArtifactsRoot artifacts/esp32c6
```

2. Runtime diagnostics (krok 16):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step27-mdnsadv-r2
```

3. Gate network advertising (krok 12):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step27-mdnsadv-r2/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -UseOnNetworkLong true `
  -RequireRuntimeReadyForPairing true `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing false `
  -RunDiscoveryPrecheck true `
  -Instance c12-com11-step27-netgate
```

## Kryterium zaliczenia

1. Firmware C6 buduje sie i flashuje z aktywnym runtime hookiem mDNS.
2. Step16 przechodzi deterministycznie dla obu poprawnych stanow `network_advertising`.
3. Step12 utrzymuje poprawny gate przy braku potwierdzonego advertising (`blocked_network_not_advertising`).

## Nastepny krok

1. Powiazac `network_advertising` z realnym lifecycle commissioning stacku (esp-matter), tak aby uzyskac `signal_present` bez symulacji.
2. Odtworzyc `discover=found` i pairing PASS na realnym firmware ESP32-C6.
