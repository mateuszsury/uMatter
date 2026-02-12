# Faza 0 - Krok 20: network advertising diagnostics + pairing gate

## Cel

Rozdzielic diagnostycznie stan `runtime ready` od faktycznej gotowosci do odkrycia przez kontroler (mDNS advertisement) i dodac opcjonalny gate blokujacy pairing, gdy reklama sieciowa nie jest potwierdzona.

## Co zostalo dodane/zmienione

1. `modules/umatter/src/mod_umatter.c`
   - `Node.commissioning_diagnostics()` rozszerzone o:
     - `network_advertising` (bool)
     - `network_advertising_reason` (string)
   - W aktualnym runtime PoC:
     - `network_advertising=False`
     - `network_advertising_reason=not_integrated` gdy runtime jest gotowe.

2. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
   - nowe markery:
     - `C16:N_DIAG_NET_ADV`
     - `C16:N_DIAG_NET_REASON`
     - `C16:L_DIAG_NET_ADV`
     - `C16:L_DIAG_NET_REASON`
   - smoke host waliduje obecność markerow net diagnostics.

3. `scripts/phase0_step12_chiptool_gate.ps1`
   - nowe wejscie:
     - `RequireNetworkAdvertisingForPairing` (domyslnie `false`)
   - parser runtime logu obsluguje:
     - `network_advertising_known`
     - `network_advertising`
     - `network_advertising_reason`
   - nowy status gate:
     - `blocked_network_not_advertising`
   - wynik JSON rozszerzony o pola network gate.

4. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
   - propaguje `RequireNetworkAdvertisingForPairing` do step12.
   - wynik runnera zawiera pola `gate_network_*`.

## Walidacja

1. Build-only C6 (unikalna instancja pod rownolegly build):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step20-buildonly `
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
  -BuildInstance c6-com11-step20-buildonly `
  -ArtifactsRoot artifacts/esp32c6 `
  -SkipBuild -SkipSmoke
```

3. Runtime diagnostics smoke (live):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step20 `
  -EndpointId 9 `
  -Passcode 24681357 `
  -Discriminator 1234
```

4. Gate z aktywnym network gate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step20/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -Instance c12-com11-step20-runpair-netgate-known
```

5. Runner e2e bez `-SkipRuntimeDiag`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -ComPort COM11 `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -Instance c19-com11-step20-live-netgate
```

## Kryterium zaliczenia

1. Runtime diagnostics zwraca pola net diagnostics i step16 przechodzi.
2. Gate potrafi zablokowac pairing osobno z powodu braku potwierdzenia advertising.
3. Runner e2e propaguje status network gate i reason do jednego artefaktu.

## Nastepny krok

1. Podlaczyc realny sygnal mDNS advertisement (z runtime/esp-matter) i zmienic `network_advertising` na sygnal rzeczywisty.
2. Powtorzyc step19 z `RequireNetworkAdvertisingForPairing=true` i domknac `gate_status=pass`.
