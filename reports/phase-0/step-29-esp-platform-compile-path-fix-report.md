# Raport fazy 0 - krok 29 (ESP compile path fix)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Wymuszenie `ESP_PLATFORM` na poziomie user modułu.
  2. Rebuild/flash/test C6 po zmianie compile flags.
  3. Potwierdzenie, ze network gate nie blokuje juz default runtime.
- Decyzje:
  1. Flaga ustawiona lokalnie w `micropython.cmake`, aby objac oba etapy build.
  2. Traktujemy `discovery_not_found` jako kolejny blocker po usunieciu blokady network gate.

## 2. Zmienione pliki

1. `modules/umatter/micropython.cmake`
2. `docs/HARDWARE_MATRIX.md`
3. `docs/phase-0/step-29-esp-platform-compile-path-fix.md`
4. `reports/phase-0/step-29-esp-platform-compile-path-fix-report.md`
5. `CHANGELOG.md`

## 3. Wyniki walidacji

### 3.1 Build + flash C6 (COM11)

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -IdfRootWsl /home/thete/esp-idf-5.5.1 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step29-espflag -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -ArtifactsRoot artifacts/esp32c6`
- Wynik:
  1. Build: `PASS`
  2. Flash: `PASS`
  3. App size: `2036080`
  4. Free in app partition (2560 KiB): `585360`
  5. Smoke z runnera step02: `FAIL` (raw repl timeout) - manualny smoke po flashu: `PASS`.

### 3.2 Compile flags verification

- `compile_commands.json` zawiera `-DESP_PLATFORM=1` dla `umatter_core_runtime.c` w obu wpisach (wczesny i finalny etap kompilacji).

### 3.3 Step16 runtime diagnostics

- Default:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step29-default-r2`
  - `PASS`
  - Kluczowe markery:
    1. `C16:N_DIAG_NET_ADV True`
    2. `C16:N_DIAG_NET_REASON signal_present`
    3. `C16:N_DIAG_NET_MDNS_PUB True`
    4. `C16:N_DIAG_NET_MDNS_ERR 0`
    5. `C16:N_DIAG_NET_MANUAL False`
    6. `C16:C_NET1D (True, 3, True, 0, False)`
- Symulacja:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step29-sim -SimulateNetworkAdvertising`
  - `PASS`
  - Markery:
    1. `C16:N_DIAG_NET_ADV True`
    2. `C16:N_DIAG_NET_MDNS_PUB False`
    3. `C16:N_DIAG_NET_MANUAL True`

### 3.4 Step12 gate

- Network gate (default diag):
  - `status=fail_pairing`
  - `network_advertising=True`
  - `network_advertising_reason=signal_present`
  - `network_gate_blocked=false`
- Discovery-required:
  - `status=blocked_discovery_not_found`
  - `discovery_precheck_status=not_found`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. `step02` smoke nadal potrafi sporadycznie failowac na raw repl po flashu (mimo retry).
  2. Discovery nadal nie znajduje commissionable entry, wiec pairing pass na realnym firmware nie jest domkniety.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 09:
  1. Skupic sie na discovery visibility (`discover ...` ma przejsc na `found`).
  2. Domknac pairing PASS na realnym C6 bez virtual device.
