# Raport fazy 0 - krok 17 (commissioning ready reason + runtime state)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Dolozenie deterministycznej przyczyny `commissioning_ready` w core i API.
  2. Zamiana `runtime=placeholder` na realny stan runtime w diagnostyce.
  3. Aktualizacja smoke host dla nowych markerow.
  4. Walidacja na ESP32-C6 (`COM11`).
- Decyzje:
  1. Priorytet przyczyn gotowosci:
     - `transport_not_configured`
     - `no_endpoints`
     - `node_not_started`
     - `ready`
  2. `runtime` mapowany z `ready_reason`:
     - `awaiting_transport`
     - `awaiting_endpoint`
     - `awaiting_start`
     - `commissioning_ready`

## 2. Zmienione pliki

1. `modules/umatter/include/umatter_core.h`
2. `modules/umatter/src/umatter_core_runtime.c`
3. `modules/umatter/src/mod_umatter_core.c`
4. `modules/umatter/src/mod_umatter.c`
5. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
6. `docs/phase-0/step-17-commissioning-ready-reason-runtime-state.md`
7. `reports/phase-0/step-17-commissioning-ready-reason-runtime-state-report.md`

## 3. Wyniki walidacji

### 3.1 Build C6 (clean build-only)

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step17-buildonly -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -SkipFlash -SkipSmoke`
- Wynik:
  1. `PASS`
  2. App size: `2024192` bytes
  3. Wolne w partycji app: `597248` bytes

### 3.2 Flash C6

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 ... -BuildInstance c6-com11-step17 -SkipSmoke`
- Wynik:
  1. Build + flash technicznie zakonczone poprawnie.
  2. `esptool` write/verify: `PASS`.

### 3.3 Runtime smoke (step16 po rozszerzeniu markerow)

- Polecenie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step17 -EndpointId 9 -Passcode 24681357 -Discriminator 1234`
- Wynik:
  1. `PASS`
  2. Znacznik koncowy: `HOST_C16_PASS`
  3. Potwierdzone markery:
     - `N_REASON0 transport_not_configured`
     - `N_REASON1 no_endpoints`
     - `N_REASON2 node_not_started`
     - `N_REASON3 ready`
     - `N_DIAG_RUNTIME commissioning_ready`
     - `N_DIAG_REASON ready`
     - `L_DIAG_RUNTIME commissioning_ready`
     - `C_REASON0 1`, `C_REASON1 2`, `C_REASON2 3`, `C_REASON3 0`, `C_REASON4 3`
- Artefakty:
  1. `artifacts/commissioning/c16-com11-step17/serial_commissioning_runtime_diag.log`
  2. `artifacts/commissioning/c16-com11-step17/commissioning_runtime_diag_data.json`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. `mpremote` smoke z `phase0_step02_c5_e2e.ps1` na tej plytce/porcie bywa niestabilny (wejscie w bootrom DOWNLOAD po auto-reset), mimo poprawnego flash.
  2. Commissioning runtime e2e (`chip-tool` pairing pass) nadal wymaga dalszej integracji transport/mDNS.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 03:
  1. Wlaczyc `ready_reason` do preflight gate `chip-tool` jako warunek gotowosci runtime.
  2. Rozszerzyc runtime flow commissioning do realnego e2e pairing i domknac `status=pass`.

