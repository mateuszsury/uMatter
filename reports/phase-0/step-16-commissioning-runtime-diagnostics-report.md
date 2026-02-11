# Raport fazy 0 - krok 16 (commissioning runtime diagnostics + C6 flash)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Naprawa blokera kompilacji (`py/objdict.h`) i domkniecie kroku 16.
  2. Dodanie API transport/ready/diagnostics dla `Node`, `Light` i `_umatter_core`.
  3. Build + flash + smoke na `ESP32_GENERIC_C6` (`COM11`).
  4. Poprawa skryptu `phase0_step02_c5_e2e.ps1`, aby flash nie byl hardcoded do `esp32c5`.
- Decyzje:
  1. Usunieto zaleznosc od `py/objdict.h`, bo `mp_obj_dict_store` jest dostepne z `py/obj.h`.
  2. `commissioning_ready` w runtime: `started && endpoint_count > 0 && transport != none`.
  3. `phase0_step02_c5_e2e.ps1` mapuje `-Board` na `--chip` (mozliwy override parametrem `-Chip`).

## 2. Zmienione pliki

1. `modules/umatter/src/mod_umatter.c`
2. `scripts/phase0_step02_c5_e2e.ps1`
3. `docs/phase-0/step-16-commissioning-runtime-diagnostics.md`
4. `reports/phase-0/step-16-commissioning-runtime-diagnostics-report.md`

## 3. Wyniki walidacji

### 3.1 Build C6

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step16b-buildonly -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -SkipFlash -SkipSmoke`
- Wynik:
  1. `PASS`
  2. `micropython.bin` size: `0x1edf20`
  3. App partition free: `0x920e0` (~23%)

### 3.2 Flash C6 przez skrypt fazowy

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step16b-buildonly -ArtifactsRoot artifacts/esp32c6 -SkipBuild -SkipSmoke`
- Wynik:
  1. `PASS`
  2. Skrypt raportuje `Chip: esp32c6`
  3. Flash + verify zakonczone poprawnie

### 3.3 Smoke commissioning runtime diagnostics

- Polecenie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step16c -EndpointId 9 -Passcode 24681357 -Discriminator 1234`
- Wynik:
  1. `PASS`
  2. Znacznik koncowy: `HOST_C16_PASS`
  3. Potwierdzone markerami:
     - `N_TRANSPORT1 thread`
     - `N_READY2 True`
     - `N_DIAG_TRANSPORT thread`
     - `L_TRANSPORT0 wifi`
     - `L_READY1 True`
     - `C_TRANS1 3`
     - `C_READY1 1`
- Artefakty:
  1. `artifacts/commissioning/c16-com11-step16c/commissioning_runtime_diag_data.json`
  2. `artifacts/commissioning/c16-com11-step16c/serial_commissioning_runtime_diag.log`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. `commissioning_diagnostics()["runtime"]` pozostaje `placeholder`.
  2. Gate `chip-tool -RunPairing` nadal zalezy od kolejnego kroku: realny runtime commissioning/mDNS.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 (`agents/07-thread-commissioning.md`) + Agent 03 (`agents/03-core-binding-cpp.md`):
  1. Podlaczyc realny commissioning runtime (Thread/WiFi) do obecnych hookow diagnostycznych.
  2. Powtorzyc `scripts/phase0_step12_chiptool_gate.ps1 -RunPairing` i domknac status do `pass`.
