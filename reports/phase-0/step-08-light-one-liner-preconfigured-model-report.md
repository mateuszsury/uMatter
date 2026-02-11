# Raport fazy 0 - krok 08 (`umatter.Light` prekonfiguruje model na ESP32-C6)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Rozszerzenie `umatter.Light(...)` o automatyczna konfiguracje endpointu i klastrow.
  2. Utrzymanie kompatybilnosci API (`Light` zwraca `Node`).
  3. Walidacja e2e na `ESP32-C6` (`COM11`): build, flash, smoke.
- Decyzje:
  1. `Light(...)` domyslnie tworzy endpoint `1` typu `OnOff Light`.
  2. Domyslnie dodawane sa klastry `OnOff` + `LevelControl`.
  3. Dodano kontrolowany parametr `with_level_control=False` dla lzejszego profilu.
  4. Build uruchomiony z osobnym `BuildInstance` (`c6-com11-step08`) ze wzgledu na rownolegle instancje IDF.

## 2. Zmienione pliki

1. `modules/umatter/src/mod_umatter.c`
2. `docs/phase-0/step-08-light-one-liner-preconfigured-model.md`
3. `reports/phase-0/step-08-light-one-liner-preconfigured-model-report.md`

## 3. Wyniki walidacji

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step08 -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -SkipFlash -SkipSmoke
```

Wynik:
1. Build: `PASS`
2. Board: `ESP32_GENERIC_C6`
3. User module: `usermod_umatter`
4. Rozmiar app: `0x1e53a0`, wolne ~`0xAC60` (ok. 2%)

Flash:

```powershell
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write-flash "@flash_args"
```

Wynik:
1. Flash: `PASS`

Smoke `Light` (REPL po serialu):
1. `LIGHT_TYPE <class 'Node'>`
2. `EP_COUNT_1 1`
3. `DUP_LIGHT_EP ValueError endpoint_id already exists`
4. `EP_COUNT_2 2`
5. `EP2_CL 1`
6. `STARTED_0 False`
7. `STARTED_1 True`
8. `STARTED_2 False`
9. `CLOSE_A`
10. `EP2_COUNT_1 1`
11. `DUP_LIGHT2_EP ValueError endpoint_id already exists`
12. `CLOSE_B`
13. `LIGHT_SMOKE:PASS`

Artefakty:
1. `artifacts/esp32c6/c6-com11-step08/flash_args`
2. `artifacts/esp32c6/c6-com11-step08/micropython.bin`
3. `artifacts/esp32c6/c6-com11-step08/bootloader/bootloader.bin`
4. `artifacts/esp32c6/c6-com11-step08/partition_table/partition-table.bin`
5. `artifacts/esp32c6/c6-com11-step08/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. `Light` nadal zwraca `Node`, bez dedykowanego typu `Light`.
  2. Brak commissioning end-to-end (to kolejny etap PoC).
  3. C6 jest blisko limitu partycji aplikacji (ok. 2% wolnego miejsca).
  4. `mpremote` na `COM11` bywa niestabilny w raw REPL, dlatego smoke uruchamiany jest przez bezposredni serial REPL.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 (`agents/07-thread-commissioning.md`) + Agent 09 (`agents/09-test-certification.md`):
  1. Dodac minimalny smoke commissioning flow dla C6 (zestaw komend i kryteriow PASS/FAIL).
  2. Dodac podstawowe logowanie diagnostyczne commissioning start/fail.
  3. Zmierzyc stabilnosc startu `Light` po kilku restartach (krótki soak).
