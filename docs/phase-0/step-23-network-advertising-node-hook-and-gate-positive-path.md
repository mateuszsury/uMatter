# Faza 0 - Krok 23: Node hook dla network advertising i dodatnia sciezka gate

## Cel

Dodac kontrolowany hook API w `umatter.Node`, ktory pozwala runtime/operatorowi ustawic sygnal `network_advertising`, a nastepnie zweryfikowac dodatnia sciezke network gate (`RequireNetworkAdvertisingForPairing=true`).

## Co zostalo dodane/zmienione

1. `modules/umatter/src/mod_umatter.c`
   - nowe metody klasy `Node`:
     - `set_network_advertising(advertising[, reason])`
     - `network_advertising()` -> `(bool, reason)`
   - wspierane reason string:
     - `unknown`
     - `runtime_not_ready`
     - `not_integrated`
     - `signal_present`
     - `signal_lost`
   - eksport stale modulowe:
     - `NETWORK_ADVERTISING_REASON_*`

2. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
   - nowy parametr:
     - `-SimulateNetworkAdvertising`
   - gdy aktywny:
     - skrypt ustawia `set_network_advertising(True, "signal_present")` na `Node` i `Light`,
     - waliduje markery:
       - `C16:N_SET_NET1_ADV`
       - `C16:N_SET_NET1_REASON`
       - `C16:L_SET_NET1_ADV`
       - `C16:L_SET_NET1_REASON`
       - oraz `*_DIAG_NET_ADV=True` / `*_DIAG_NET_REASON=signal_present`.
   - gdy nieaktywny:
     - utrzymuje dotychczasowa sciezke (`*_DIAG_NET_ADV=False`).

## Walidacja

1. Build-only C6:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step23-buildonly `
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
  -BuildInstance c6-com11-step23-buildonly `
  -ArtifactsRoot artifacts/esp32c6 `
  -SkipBuild -SkipSmoke
```

3. Step16 smoke (default):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step23-default `
  -EndpointId 9 `
  -Passcode 24681357 `
  -Discriminator 1234
```

4. Step16 smoke (symulacja advertising):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step23-sim-netadv `
  -EndpointId 9 `
  -Passcode 24681357 `
  -Discriminator 1234 `
  -SimulateNetworkAdvertising
```

5. Step12 gate z network gate + discovery (na logu symulowanym):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c12-com11-step23-runpair-netadv-sim
```

6. Step19 e2e runner (na logu symulowanym):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c19-com11-step23-runpair-netadv-sim
```

## Kryterium zaliczenia

1. `Node` ma jawny hook do update sygnalu advertising.
2. Step16 ma dwie stabilne sciezki: default i symulowana.
3. Przy logu symulowanym network gate nie blokuje pairing (`status != blocked_network_not_advertising`).

## Nastepny krok

1. Zastapic hook symulacyjny realnym sygnalem mDNS/commissionable advertisement z integracji esp-matter.
2. Domknac `chip-tool pairing` do `status=pass` (bez timeout mDNS).
