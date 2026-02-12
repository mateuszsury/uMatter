# Raport fazy 0 - krok 30 (runtime mDNS commissionable subtypes)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie subtypes `_L` i `_S` do publikacji commissionable mDNS w runtime.
  2. Walidacja runtime diagnostics po zmianie.
  3. Walidacja gate discovery z realnym `chip-tool`.
- Decyzje:
  1. Uzyto `mdns_service_subtype_add_for_host(...)`, bo `mdns_service_subtype_add(...)` nie wystepuje w mdns `1.1.0`.
  2. Przy bledzie subtype publikacja service jest wycofywana (`mdns_service_remove`), aby utrzymac spojny stan.

## 2. Zmienione pliki

1. `modules/umatter/src/umatter_core_runtime.c`
2. `docs/phase-0/step-30-runtime-mdns-commissionable-subtypes.md`
3. `reports/phase-0/step-30-runtime-mdns-commissionable-subtypes-report.md`
4. `docs/HARDWARE_MATRIX.md`
5. `docs/README.md`
6. `CHANGELOG.md`

## 3. Wyniki walidacji

### 3.1 Build-only C6

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -IdfRootWsl /home/thete/esp-idf-5.5.1 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step30c-buildonly -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -ArtifactsRoot artifacts/esp32c6 -SkipFlash -SkipSmoke`
- Wynik:
  1. `PASS`
  2. `micropython.bin` size: `2036624`
  3. free in app partition (2560 KiB): `584816`

### 3.2 Runtime diagnostics (C6/COM11)

- Polecenie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -Port COM11 -Instance c16-20260212-141341`
- Wynik:
  1. `PASS`
  2. `network_advertising=True`
  3. `network_advertising_reason=signal_present`
  4. `network_advertising_mdns_published=True`
  5. `network_advertising_mdns_last_error=0`

### 3.3 Step12 gate (discovery required)

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -Instance c12-20260212-step30chiptool -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 12`
- Wynik:
  1. `status=blocked_discovery_not_found`
  2. `discovery_precheck_status=not_found`
  3. `discovery_precheck_fallback_used=true`
  4. `network_gate_blocked=false`
  5. `runtime_gate_blocked=false`

Interpretacja:
- Zmiana runtime nie wprowadza regresji i mDNS publikuje sie poprawnie.
- Discovery po stronie kontrolera dla realnego firmware nadal nie znajduje wpisu commissionable.

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Realny discovery path pozostaje niedomkniety (`not_found`) mimo poprawnej telemetrii runtime.
  2. Bez jawnej sciezki `chip-tool` gate moze wpasc w `unavailable_tool`, jesli binary nie jest w PATH.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 09:
  1. Domknac discovery visibility dla realnego firmware (bez hostowego mocka).
  2. Dodac auto-detekcje lokalizacji `chip-tool` w `step12`.
