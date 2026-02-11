# Raport fazy 0 - krok 10 (placeholder commissioning config na ESP32-C6)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie placeholder API commissioning do warstwy core.
  2. Ekspozycja commissioning w `_umatter_core`.
  3. Dodanie commissioning do `umatter.Node` i `umatter.Light`.
  4. Walidacja e2e na `ESP32-C6` (`COM11`) z powiekszona partycja app.
- Decyzje:
  1. Domyslne wartosci commissioning:
     - `discriminator=3840`
     - `passcode=20202021`
  2. Walidacja zakresow:
     - `passcode`: `1..99999998`
     - `discriminator`: `0..4095`
  3. `commissioning()` zwraca tuple `(discriminator, passcode)`.

## 2. Zmienione pliki

1. `modules/umatter/include/umatter_core.h`
2. `modules/umatter/src/umatter_core_runtime.c`
3. `modules/umatter/src/mod_umatter_core.c`
4. `modules/umatter/src/mod_umatter.c`
5. `docs/phase-0/step-10-commissioning-config-placeholder.md`
6. `reports/phase-0/step-10-commissioning-config-placeholder-report.md`

## 3. Wyniki walidacji

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step10 -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -SkipFlash -SkipSmoke
```

Wynik:
1. Build: `PASS`
2. App partition: `0x280000`
3. `micropython.bin`: `0x1eb960`
4. Wolne w app: `0x946a0` (ok. `23.19%`)

Flash:

```powershell
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write-flash "@flash_args"
```

Wynik:
1. Flash: `PASS`

Smoke commissioning + VFS:
1. `VFS_TOTAL 1507328`
2. `COMM_DEF (3840, 20202021)`
3. `COMM_SET (1234, 12345678)`
4. `COMM_PASS_ERR ValueError invalid passcode`
5. `COMM_DISC_ERR ValueError invalid discriminator`
6. `L_COMM (2345, 87654321)`
7. `L_EP 1`
8. `C_GET0 (3840, 20202021)`
9. `C_SET 0`
10. `C_GET1 (321, 23456789)`
11. `C_DEST 0`
12. `STEP10_SMOKE:PASS`

Artefakty:
1. `artifacts/esp32c6/c6-com11-step10/flash_args`
2. `artifacts/esp32c6/c6-com11-step10/micropython.bin`
3. `artifacts/esp32c6/c6-com11-step10/partition_table/partition-table.bin`
4. `artifacts/esp32c6/c6-com11-step10/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. To nadal placeholder commissioning (bez realnego procesu Matter commissioning).
  2. Brakuje jeszcze integracji z chip-tool i realnym onboardingiem Thread/WiFi.
  3. `mpremote` na `COM11` bywa niestabilny dla raw REPL, dlatego smoke idzie przez bezposredni serial.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 (`agents/07-thread-commissioning.md`) + Agent 09 (`agents/09-test-certification.md`):
  1. Dodac hostowy smoke commissioning-flow (procedura, komendy i logi oczekiwane).
  2. Rozszerzyc diagnostyke stanu commissioning po stronie runtime.
  3. Przygotowac pierwsza probe end-to-end z chip-tool dla C6.
