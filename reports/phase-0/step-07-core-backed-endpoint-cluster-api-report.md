# Raport fazy 0 - krok 07 (endpoint/cluster API podlaczone do core na ESP32-C6)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie endpoint/cluster API po stronie core runtime.
  2. Wystawienie nowych funkcji w `_umatter_core`.
  3. Podlaczenie `umatter.Node` i `umatter.Endpoint` do backendu core.
  4. Walidacja e2e na `ESP32-C6` (`COM11`): build, flash, smoke.
- Decyzje:
  1. Zachowany zostal kompatybilny kontrakt bledow po stronie Python:
     - `endpoint_id already exists`
     - `cluster already exists`
  2. Placeholder runtime pozostaje lekki i statyczny (PoC), bez dynamicznej alokacji.
  3. Dla C6 flash jest wykonywany recznie przez `esptool --chip esp32c6`,
     bo skrypt e2e ma sciezke flash domyslnie pod C5.

## 2. Zmienione pliki

1. `modules/umatter/include/umatter_core.h`
2. `modules/umatter/src/umatter_core_runtime.c`
3. `modules/umatter/src/mod_umatter_core.c`
4. `modules/umatter/src/mod_umatter.c`
5. `docs/phase-0/step-07-core-backed-endpoint-cluster-api.md`
6. `reports/phase-0/step-07-core-backed-endpoint-cluster-api-report.md`

## 3. Wyniki walidacji

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step07 -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -SkipFlash -SkipSmoke
```

Wynik:
1. Build: `PASS`
2. Board: `ESP32_GENERIC_C6`
3. User module: `usermod_umatter`

Port i chip check:

```powershell
python -m esptool --chip auto -p COM11 -b 460800 chip_id
```

Wynik:
1. Port `COM11`: `ESP32-C6` wykryty poprawnie.

Flash:

```powershell
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write-flash "@flash_args"
```

Wynik:
1. Flash: `PASS`

Smoke `umatter` (REPL po serialu):
1. `EP_COUNT_0 0`
2. `EP_COUNT_1 1`
3. `CL_COUNT_1 1`
4. `DUP_EP_ERR ValueError endpoint_id already exists`
5. `DUP_CL_ERR ValueError cluster already exists`
6. `STARTED_0 False`
7. `STARTED_1 True`
8. `STARTED_2 False`
9. `CLOSE_OK`
10. `SMOKE:PASS`

Smoke `_umatter_core` (REPL po serialu):
1. `HANDLE_OK True`
2. `EP0 0`
3. `ADD_EP 0`
4. `EP1 1`
5. `ADD_CL 0`
6. `CL1 1`
7. `DUP_EP -5`
8. `DUP_CL -5`
9. `DESTROY 0`
10. `CORE_SMOKE:PASS`

Artefakty:
1. `artifacts/esp32c6/c6-com11-step07/flash_args`
2. `artifacts/esp32c6/c6-com11-step07/micropython.bin`
3. `artifacts/esp32c6/c6-com11-step07/bootloader/bootloader.bin`
4. `artifacts/esp32c6/c6-com11-step07/partition_table/partition-table.bin`
5. `artifacts/esp32c6/c6-com11-step07/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Obecny backend endpoint/cluster to nadal warstwa placeholder (bez realnego esp-matter endpoint create).
  2. Obraz aplikacji dla C6 jest blisko limitu partycji (niski zapas flash).
  3. `mpremote` bywa niestabilny na `COM11` (raw REPL), dlatego smoke jest wykonywany przez bezposredni serial REPL.

## 5. Nastepny krok dla kolejnego agenta

- Agent 04 (`agents/04-python-api.md`) + Agent 03 (`agents/03-core-binding-cpp.md`):
  1. Rozszerzyc `umatter.Light(...)` do gotowego modelu light (node + endpoint + clustery).
  2. Dodac opcje konfiguracji domyslnych klastrow bez lamania obecnego API.
  3. Potwierdzic na C6 smoke one-linera z lifecycle i licznikami endpoint/cluster.
