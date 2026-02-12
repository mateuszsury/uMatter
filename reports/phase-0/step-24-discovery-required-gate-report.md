# Raport fazy 0 - krok 24 (discovery-required gate)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie warunku discovery-required do `step12`.
  2. Propagacja warunku do runnera `step19`.
  3. Dodanie propagacji `SimulateNetworkAdvertising` w `step19` -> `step16`.
- Decyzje:
  1. Discovery gate jest opcjonalny (`RequireDiscoveryFoundForPairing`, default `false`).
  2. Wlaczenie discovery-required bez discovery precheck jest bledem konfiguracji.
  3. Brak wyniku discovery (`not_found`) blokuje pairing deterministycznie statusem `blocked_discovery_not_found`.

## 2. Zmienione pliki

1. `scripts/phase0_step12_chiptool_gate.ps1`
2. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
3. `docs/phase-0/step-24-discovery-required-gate.md`
4. `reports/phase-0/step-24-discovery-required-gate-report.md`

## 3. Wyniki walidacji

### 3.1 Parse-check

- Wynik:
  1. `PASS` (`step12`, `step19`)

### 3.2 Step12: discovery-required=true

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c12-com11-step24-runpair-discovery-required`
- Wynik:
  1. `status=blocked_discovery_not_found`
  2. `discovery_gate_blocked=true`
  3. `require_discovery_found_for_pairing=true`
  4. `discovery_precheck_status=not_found`

### 3.3 Step12: discovery-required=false (porownanie)

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing false -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c12-com11-step24-runpair-discovery-optional`
- Wynik:
  1. `status=fail_pairing`
  2. `discovery_gate_blocked=false`
  3. `require_discovery_found_for_pairing=false`
  4. `discovery_precheck_status=not_found`

### 3.4 Step19: external log

- Polecenie:
  - `scripts/phase0_step19_commissioning_gate_e2e.ps1 -SkipRuntimeDiag -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c19-com11-step24-discovery-required-external`
- Wynik:
  1. `Commissioning gate e2e: PASS`
  2. `gate_status=blocked_discovery_not_found`

### 3.5 Step19: live diag + simulate flag propagation

- Polecenie:
  - `scripts/phase0_step19_commissioning_gate_e2e.ps1 -ComPort COM11 -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -SimulateNetworkAdvertising -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -Instance c19-com11-step24-discovery-required-live`
- Wynik:
  1. `step16 runtime diagnostics: PASS`
  2. `Commissioning gate e2e: PASS`
  3. `gate_status=blocked_discovery_not_found`
  4. `simulate_network_advertising=true`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. `discover=not_found` jest obecnie oczekiwany, bo runtime nie emituje jeszcze realnego commissionable mDNS.
  2. Pairing pozostaje niedomkniety do `pass` do czasu podpiecia realnej reklamy z firmware.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 03:
  1. Podpiac realny mDNS/commissionable sygnal z runtime (esp-matter) i aktualizacje `network_advertising`.
  2. Zweryfikowac `discovery_precheck_status=found` i domknac pairing do `status=pass`.
