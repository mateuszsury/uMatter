# Raport fazy 0 - krok 09 (rebalans partycji flash app/vfs na ESP32-C6)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Analiza trendu rozmiaru binarki C6.
  2. Powiekszenie partycji `factory app`.
  3. Potwierdzenie, ze VFS MicroPython pozostaje dostepny.
  4. Wdrozenie opcji custom partition CSV do skryptow build.
- Decyzje:
  1. Ustawiono `factory app = 0x280000` (2560 KiB).
  2. Pozostawiono brak wpisu `vfs` w tabeli partycji:
     MicroPython tworzy `vfs` automatycznie z wolnego taila flash.
  3. Rozwiazanie wdrozone per instancja builda (`--partition-csv`),
     aby uniknac konfliktow przy wielu rownoleglych buildach.

## 2. Zmienione pliki

1. `scripts/wsl_build_micropython_c5.sh`
2. `scripts/phase0_step02_c5_e2e.ps1`
3. `scripts/partitions/partitions-4MiBplus-app2560k.csv`
4. `docs/phase-0/step-09-flash-partition-rebalance-app-vfs.md`
5. `reports/phase-0/step-09-flash-partition-rebalance-app-vfs-report.md`

## 3. Wyniki walidacji

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step09 -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -SkipFlash -SkipSmoke
```

Wynik:
1. Build: `PASS`
2. Partycja app: `0x280000`
3. `micropython.bin`: `0x1e53b0`
4. Wolne w app: `0x9ac50` (ok. `24.18%`)

Flash:

```powershell
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write-flash "@flash_args"
```

Wynik:
1. Flash: `PASS`

Smoke:
1. `VFS_TOTAL 1507328` (ok. 1472 KiB)
2. Wykryte data partitions:
   - `nvs`
   - `phy_init`
   - `vfs` (auto)
3. `umatter.Light(...)` lifecycle: `PASS`

Analiza trendu (C6):
1. `step08`: `0x1e53a0` -> przy starej app `2.17%` free
2. `step09`: `0x1e53b0` -> przy nowej app `24.18%` free

Artefakty:
1. `artifacts/esp32c6/c6-com11-step09/flash_args`
2. `artifacts/esp32c6/c6-com11-step09/micropython.bin`
3. `artifacts/esp32c6/c6-com11-step09/partition_table/partition-table.bin`
4. `artifacts/esp32c6/c6-com11-step09/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Mniejszy VFS niz w domyslnym układzie (ok. 1.47 MiB zamiast 2 MiB).
  2. Dalszy wzrost firmware moze nadal wymagac kolejnych optymalizacji.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 (`agents/07-thread-commissioning.md`) + Agent 04 (`agents/04-python-api.md`):
  1. Dodac placeholder API commissioning (`passcode`, `discriminator`).
  2. Podlaczyc konfiguracje commissioning do `Node` i `Light`.
  3. Zwalidowac zakresy i odczyt konfiguracji na C6.
