# Raport fazy 0 - krok 20 (network advertising diagnostics + pairing gate)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie sygnalow net diagnostics do `commissioning_diagnostics()`.
  2. Integracja markerow net diagnostics w step16.
  3. Dodanie opcjonalnego network gate w step12.
  4. Propagacja network gate do runnera step19.
  5. Build/flash/live smoke na ESP32-C6 (`COM11`).
- Decyzje:
  1. W Fazie 0 sygnal `network_advertising` pozostaje jawnie `False` z reason `not_integrated`.
  2. Network gate jest domyslnie `off` (`RequireNetworkAdvertisingForPairing=false`) dla kompatybilnosci.
  3. Przy wlaczonym network gate pairing jest blokowany deterministycznie przed wywolaniem `chip-tool pairing`.

## 2. Zmienione pliki

1. `modules/umatter/src/mod_umatter.c`
2. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
3. `scripts/phase0_step12_chiptool_gate.ps1`
4. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
5. `docs/phase-0/step-20-network-advertising-gate.md`
6. `reports/phase-0/step-20-network-advertising-gate-report.md`

## 3. Wyniki walidacji

### 3.1 Parse-check skryptow

- Wynik:
  1. `PASS` dla `step12`, `step16`, `step19`.

### 3.2 Build C6 (clean build-only)

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step20-buildonly -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -SkipFlash -SkipSmoke`
- Wynik:
  1. `PASS`
  2. `micropython.bin` size: `2024384` bytes
  3. Wolne w app partycji: `597056` bytes

### 3.3 Flash C6

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step20-buildonly -ArtifactsRoot artifacts/esp32c6 -SkipBuild -SkipSmoke`
- Wynik:
  1. `PASS` (`esptool write/verify`)

### 3.4 Runtime diagnostics smoke (live)

- Polecenie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step20 -EndpointId 9 -Passcode 24681357 -Discriminator 1234`
- Wynik:
  1. `PASS` (`HOST_C16_PASS`)
  2. Potwierdzone markery:
     - `C16:N_DIAG_NET_ADV False`
     - `C16:N_DIAG_NET_REASON not_integrated`
     - `C16:L_DIAG_NET_ADV False`
     - `C16:L_DIAG_NET_REASON not_integrated`

### 3.5 Gate z network gate wlaczonym

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step20/serial_commissioning_runtime_diag.log -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -Instance c12-com11-step20-runpair-netgate-known`
- Wynik:
  1. `status=blocked_network_not_advertising`
  2. `network_advertising_known=true`
  3. `network_advertising=false`
  4. `network_advertising_reason=not_integrated`

### 3.6 Runner e2e (live)

- Polecenie:
  - `scripts/phase0_step19_commissioning_gate_e2e.ps1 -ComPort COM11 -RunPairing -RequireNetworkAdvertisingForPairing true -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -Instance c19-com11-step20-live-netgate`
- Wynik:
  1. `Commissioning runtime diagnostics smoke: PASS`
  2. `gate_status=blocked_network_not_advertising`
  3. `gate_network_advertising_reason=not_integrated`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. `network_advertising` jest jeszcze sygnalem PoC (`not_integrated`), nie sygnalem runtime z esp-matter/mDNS.
  2. Do certyfikowalnego E2E potrzebna integracja realnej reklamy mDNS i ponowna walidacja `chip-tool pairing`.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 03:
  1. Podpiac realny callback/sygnal z runtime transport/mDNS do `network_advertising`.
  2. Zachowac `RequireNetworkAdvertisingForPairing=true` i domknac `step19` do `gate_status=pass`.
