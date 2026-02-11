# Raport fazy 0 - krok 06 (walidacja duplikatow i rejestr placeholderow na ESP32-C6)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie walidacji duplikatow `endpoint_id` i `cluster_id`.
  2. Dodanie lekkich rejestrow identyfikatorow w obiektach `Node` i `Endpoint`.
  3. Walidacja e2e na `ESP32-C6` (`COM11`).
- Decyzje:
  1. Rejestry zostaly utrzymane jako tablice statyczne (profil PoC, bez dynamicznej alokacji).
  2. Komunikaty bledow sa deterministyczne i jednoznaczne.
  3. Zaleznosci lifecycle pozostaja po stronie `Node` (`close()` zeruje stan placeholdera).

## 2. Zmienione pliki

1. `modules/umatter/src/mod_umatter.c`
2. `docs/phase-0/step-06-duplicate-validation-and-registry.md`
3. `reports/phase-0/step-06-duplicate-validation-and-registry-report.md`

## 3. Wyniki walidacji

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step06 -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -SkipFlash -SkipSmoke
```

Wynik:
1. Build: `PASS`
2. Board: `ESP32_GENERIC_C6`
3. User module: `usermod_umatter`

Flash:

```powershell
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write_flash "@flash_args"
```

Wynik:
1. Flash: `PASS`

Smoke (REPL na `COM11`):
1. `ValueError: endpoint_id already exists`
2. `ValueError: cluster already exists`
3. `endpoint_count 2`
4. `cluster1 1`
5. `cluster2 1`
6. `started True`
7. `smoke-step06-ok`

Artefakty:
1. `artifacts/esp32c6/c6-com11-step06/flash_args`
2. `artifacts/esp32c6/c6-com11-step06/micropython.bin`
3. `artifacts/esp32c6/c6-com11-step06/bootloader/bootloader.bin`
4. `artifacts/esp32c6/c6-com11-step06/partition_table/partition-table.bin`
5. `artifacts/esp32c6/c6-com11-step06/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Rejestr placeholderow nie jest jeszcze mapowany do backendu `_umatter_core`.
  2. Build C6 jest blisko limitu partycji aplikacji (ok. 3% wolnego miejsca).
  3. `mpremote` na `COM11` ma niestabilny raw REPL, dlatego smoke wykonywany jest przez REPL po serialu.

## 5. Nastepny krok dla kolejnego agenta

- Agent 03 (`agents/03-core-binding-cpp.md`) + Agent 04 (`agents/04-python-api.md`):
  1. Rozszerzyc `_umatter_core` o placeholder API endpoint/cluster.
  2. Podlaczyc `Node.add_endpoint` i `Endpoint.add_cluster` do backendu `_umatter_core`.
  3. Utrzymac obecne kontrakty bledow (`endpoint_id already exists`, `cluster already exists`).

