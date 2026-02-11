# Raport fazy 0 - krok 13 (commissioning code API + smoke na ESP32-C6)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie API `manual_code` i `qr_code` w runtime core.
  2. Ekspozycja API w `_umatter_core` i `umatter.Node`.
  3. Walidacja end-to-end na `ESP32-C6` (`COM11`) po realnym flash.
- Decyzje:
  1. Utrzymany zostal status placeholder commissioning (diagnostyka PoC, nie finalny payload Matter).
  2. `manual_code` oparty o short discriminator (`discriminator & 0x000F`) i passcode.
  3. `qr_code` ma stabilny format `MT:UM...` do automatycznych testow hostowych.

## 2. Zmienione pliki

1. `modules/umatter/include/umatter_core.h`
2. `modules/umatter/src/umatter_core_runtime.c`
3. `modules/umatter/src/mod_umatter_core.c`
4. `modules/umatter/src/mod_umatter.c`
5. `scripts/phase0_step13_commissioning_codes_smoke.ps1`
6. `docs/phase-0/step-13-commissioning-code-api-smoke.md`
7. `reports/phase-0/step-13-commissioning-code-api-smoke-report.md`

## 3. Wyniki walidacji

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step13 -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -SkipFlash -SkipSmoke
```

Wynik:
1. Build: `PASS`
2. `micropython.bin`: `0x1ebd00`
3. Wolne w app: `0x94300` (`23%`)

Flash:

```powershell
cd artifacts/esp32c6/c6-com11-step13
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write_flash "@flash_args"
```

Wynik:
1. Flash: `PASS`

Smoke commissioning code:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step13_commissioning_codes_smoke.ps1 -ComPort COM11 -DeviceName uMatter-C13 -EndpointId 7 -Passcode 24681357 -Discriminator 1234 -Instance c13-com11-step13b
```

Wynik:
1. `Commissioning code smoke: PASS`
2. `HOST_C13_PASS` w logu
3. Potwierdzone markery:
   - `C13:MAN2 00224681357`
   - `C13:QR2 MT:UMFFF18000123424681357`
   - `C13:LIGHT_MAN 00224681357`
   - `C13:CORE_MAN 00224681357`

Artefakty:
1. `artifacts/esp32c6/c6-com11-step13/flash_args`
2. `artifacts/esp32c6/c6-com11-step13/micropython.bin`
3. `artifacts/commissioning/c13-com11-step13b/serial_commissioning_codes_smoke.log`
4. `artifacts/commissioning/c13-com11-step13b/commissioning_codes_data.json`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. `qr_code` i `manual_code` sa formatem PoC (diagnostycznym), bez gwarancji kompatybilnosci z finalnym payload Matter.
  2. Realny e2e commissioning nadal zablokowany przez brak lokalnego `chip-tool`.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 (`agents/07-thread-commissioning.md`) + Agent 09 (`agents/09-test-certification.md`):
  1. Podpiac `manual_code`/`qr_code` do `scripts/phase0_step12_chiptool_gate.ps1` i matrix row.
  2. Po dostarczeniu `chip-tool` uruchomic `-RunPairing` na `COM11` i zapisac wynik e2e.
