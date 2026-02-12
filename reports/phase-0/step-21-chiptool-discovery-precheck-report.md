# Raport fazy 0 - krok 21 (chip-tool discovery precheck)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie precheck discovery w step12 przed pairing.
  2. Propagacja wynikow discovery do runnera step19.
  3. Walidacja na artefaktach commissioning C6 (`COM11`).
- Decyzje:
  1. Discovery precheck aktywowany tylko przy `RunPairing` i aktywnym network gate.
  2. Timeout discovery jest konfigurowalny (`DiscoveryTimeoutSeconds`, default 8s).
  3. Aktualna implementacja discovery precheck jest wspierana dla `chip_tool_mode=wsl`.

## 2. Zmienione pliki

1. `scripts/phase0_step12_chiptool_gate.ps1`
2. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
3. `docs/phase-0/step-21-chiptool-discovery-precheck.md`
4. `reports/phase-0/step-21-chiptool-discovery-precheck-report.md`

## 3. Wyniki walidacji

### 3.1 Parse-check

- Wynik:
  1. `PASS` (`step12`, `step19`)

### 3.2 Step12 runpair + discovery

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step20/serial_commissioning_runtime_diag.log -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c12-com11-step21-runpair-discovery`
- Wynik:
  1. `status=blocked_network_not_advertising`
  2. `discovery_precheck_enabled=true`
  3. `discovery_precheck_status=not_found`
  4. `discovery_precheck_exit=124` (timeout procesu discovery)

### 3.3 Step19 e2e + discovery

- Polecenie:
  - `scripts/phase0_step19_commissioning_gate_e2e.ps1 -SkipRuntimeDiag -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step20/serial_commissioning_runtime_diag.log -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c19-com11-step21-runpair-discovery`
- Wynik:
  1. `Commissioning gate e2e: PASS`
  2. `gate_status=blocked_network_not_advertising`
  3. `gate_discovery_precheck_status=not_found`
  4. `gate_discovery_precheck_exit=124`

### 3.4 Step12 preflight bez pairing

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 ... -Instance c12-com11-step21-preflight`
- Wynik:
  1. `status=preflight_ready`
  2. `discovery_precheck_enabled=false`
  3. `discovery_precheck_status=skipped`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Discovery precheck timeout (`exit=124`) jest oczekiwany przy braku znalezionego commissionable.
  2. Brak realnego advertising po stronie runtime nadal blokuje pairing przy wlaczonym network gate.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 03:
  1. Podpiac runtime do realnego mDNS advertisement i ustawiania `network_advertising=True`.
  2. Zweryfikowac, czy discovery precheck przechodzi (`found`) i domknac pairing do `status=pass`.
