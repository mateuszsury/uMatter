# Raport fazy 0 - krok 02 (ESP32-C5 build + flash + smoke)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Ustalenie docelowej platformy PoC na `ESP32_GENERIC_C5`.
  2. Build MicroPython `v1.27.0` pod ESP-IDF `v5.5.1`.
  3. Flash i smoke test na `COM14`.
- Decyzje:
  1. Pipeline jest przygotowany pod wiele instancji rownoleglych.
  2. Kazda instancja ma osobny worktree, build dir i artefakty.

## 2. Zmienione pliki

1. `scripts/wsl_build_micropython_c5.sh` - build C5 w WSL, per-instancja.
2. `scripts/phase0_step02_c5_e2e.ps1` - orchestracja build/flash/smoke z Windows.
3. `docs/phase-0/step-02-esp32c5-first-firmware.md` - instrukcja kroku 2.
4. `reports/phase-0/step-02-esp32c5-build-flash-report.md` - ten raport.

## 3. Wyniki walidacji

### 3.1 Weryfikacja polaczenia sprzetu

Polecenie:

```powershell
python -m esptool --chip esp32c5 -p COM14 -b 460800 read-mac
```

Wynik:
1. Chip wykryty poprawnie: `ESP32-C5 (revision v1.0)`.
2. MAC odczytany poprawnie.

### 3.2 Pelny pipeline kroku 2

Polecenie:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM14 -BuildInstance c5-com14-test1
```

Wynik:
1. Build: `PASS` (MicroPython `v1.27.0`, board `ESP32_GENERIC_C5`).
2. Flash: `PASS` (uzyto `@flash_args`, zapis bootloader/partition/app zakonczony sukcesem).
3. Smoke: `PASS` (`mpremote` zwraca `version=(1, 27, 0, '')` oraz `_build='ESP32_GENERIC_C5'`).

Artefakty instancji:
1. `artifacts/esp32c5/c5-com14-test1/flash_args`
2. `artifacts/esp32c5/c5-com14-test1/micropython.bin`
3. `artifacts/esp32c5/c5-com14-test1/bootloader/bootloader.bin`
4. `artifacts/esp32c5/c5-com14-test1/partition_table/partition-table.bin`
5. `artifacts/esp32c5/c5-com14-test1/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Brak `ccache` w WSL (dluzsze buildy, bez wplywu na poprawnosci).
  2. W `flash_args` z upstream nadal sa stare aliasy opcji esptool (`warning deprecations`), ale flash jest poprawny.

## 5. Nastepny krok dla kolejnego agenta

- Agent 02 (`agents/02-cmake-integration.md`) + Agent 03 (`agents/03-core-binding-cpp.md`):
  1. Dodac minimalny `USER_C_MODULES` dla `_umatter_core` (stub `node::create()` i rejestracja modulu).
  2. Przepuscic ten sam pipeline `phase0_step02_c5_e2e.ps1` na `COM14`.
  3. Rozszerzyc smoke test o `import umatter`.
