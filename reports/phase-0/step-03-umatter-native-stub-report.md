# Raport fazy 0 - krok 03 (native stub `umatter` na ESP32-C5)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie minimalnego natywnego modulu `umatter` jako `USER_C_MODULES`.
  2. Integracja z istniejacym pipeline C5 (`build + flash + smoke`).
  3. Walidacja na fizycznym urzadzeniu `ESP32-C5` pod `COM14`.
- Decyzje:
  1. Start od prostego stubu (`is_stub`) zamiast od razu `Node`/`esp-matter`.
  2. Reuzycie `phase0_step02_c5_e2e.ps1` (dodany parametr `-UserCModulesPath`).

## 2. Zmienione pliki

1. `modules/umatter/micropython.cmake`
2. `modules/umatter/micropython.mk`
3. `modules/umatter/include/umatter_config.h`
4. `modules/umatter/src/mod_umatter.c`
5. `scripts/wsl_build_micropython_c5.sh`
6. `scripts/phase0_step02_c5_e2e.ps1`
7. `docs/phase-0/step-02-esp32c5-first-firmware.md`
8. `docs/phase-0/step-03-umatter-native-stub.md`
9. `reports/phase-0/step-03-umatter-native-stub-report.md`

## 3. Wyniki walidacji

Polecenie:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM14 -BuildInstance c5-com14-umatter1 -UserCModulesPath modules/umatter -SmokeExpr "import sys,os,umatter; print(sys.implementation); print(os.uname()); print('umatter', umatter.__version__, umatter.is_stub())"
```

Wynik:
1. Build: `PASS`
   - log zawiera: `Found User C Module(s): usermod_umatter`
2. Flash: `PASS` (COM14)
3. Smoke: `PASS`
   - `umatter stub True`
   - MicroPython: `1.27.0`
   - board build: `ESP32_GENERIC_C5`

Artefakty:
1. `artifacts/esp32c5/c5-com14-umatter1/flash_args`
2. `artifacts/esp32c5/c5-com14-umatter1/micropython.bin`
3. `artifacts/esp32c5/c5-com14-umatter1/bootloader/bootloader.bin`
4. `artifacts/esp32c5/c5-com14-umatter1/partition_table/partition-table.bin`
5. `artifacts/esp32c5/c5-com14-umatter1/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Modul jest jeszcze stubem - brak realnej logiki Matter.
  2. Brak `ccache` w WSL (wydajnosc buildow).

## 5. Nastepny krok dla kolejnego agenta

- Agent 03 (`agents/03-core-binding-cpp.md`) + Agent 04 (`agents/04-python-api.md`):
  1. Dodac API `Node` po stronie Python.
  2. Dodac natywny backend `_umatter_core` z placeholderami lifecycle i kontrolowanym mapowaniem bledow.
  3. Rozszerzyc smoke o `import umatter` + `Node` constructor path.
