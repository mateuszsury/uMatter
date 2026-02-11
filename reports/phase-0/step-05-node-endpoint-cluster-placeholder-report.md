# Raport fazy 0 - krok 05 (placeholder `Node -> Endpoint -> Cluster` na ESP32-C6)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Rozszerzenie API PoC o placeholder modelu danych (`Node`, `Endpoint`, `Cluster`).
  2. Walidacja e2e na `ESP32-C6` na porcie `COM11`.
- Decyzje:
  1. Zastosowano lekki model placeholderowy bez integracji z `esp-matter`.
  2. Zachowano dotychczasowe lifecycle (`start/stop/close`) i dodano warstwę modelu danych.
  3. Utrzymano izolacje buildow przez unikalny `BuildInstance`.

## 2. Zmienione pliki

1. `modules/umatter/src/mod_umatter.c`
2. `docs/phase-0/step-05-node-endpoint-cluster-placeholder.md`
3. `reports/phase-0/step-05-node-endpoint-cluster-placeholder-report.md`

## 3. Wyniki walidacji

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step05 -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -SkipFlash -SkipSmoke
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
1. `endpoint_count 1`
2. `cluster_count 2`
3. `started True`
4. `smoke-step05-ok`

Artefakty:
1. `artifacts/esp32c6/c6-com11-step05/flash_args`
2. `artifacts/esp32c6/c6-com11-step05/micropython.bin`
3. `artifacts/esp32c6/c6-com11-step05/bootloader/bootloader.bin`
4. `artifacts/esp32c6/c6-com11-step05/partition_table/partition-table.bin`
5. `artifacts/esp32c6/c6-com11-step05/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Placeholder nie wykrywa jeszcze duplikatow `endpoint_id`.
  2. Placeholder nie przechowuje realnej listy endpointow i klastrow.
  3. Build C6 jest blisko limitu partycji aplikacji (ok. 4% wolnego miejsca).
  4. `mpremote` ma niestabilny raw REPL na `COM11`; smoke wykonano bezposrednio przez REPL.

## 5. Nastepny krok dla kolejnego agenta

- Agent 03 (`agents/03-core-binding-cpp.md`) + Agent 04 (`agents/04-python-api.md`):
  1. Dodac walidacje duplikatow `endpoint_id` oraz limitow per node.
  2. Dodac wewnetrzny rejestr endpointow/klastrow (nadal placeholder, ale spojnosc stanu).
  3. Przygotowac API pod mapowanie do `esp-matter` (`node::create`, `endpoint::create`).

