# Raport fazy 0 - krok 18 (chip-tool runtime-ready gate)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Integracja markerow runtime diagnostics z gate `chip-tool`.
  2. Dodanie warunku blokujacego pairing, gdy runtime nie jest gotowy.
  3. Rozszerzenie artefaktow gate o pola runtime i status blokady.
- Decyzje:
  1. Domyslnie wymagac runtime-ready przed `-RunPairing` (`RequireRuntimeReadyForPairing=true`).
  2. Traktowac brak/niepoprawnosc logu runtime jako stan `not ready` dla pairing.
  3. Pozostawic mozliwosc override przez `-RequireRuntimeReadyForPairing:$false`.

## 2. Zmienione pliki

1. `scripts/phase0_step12_chiptool_gate.ps1`
2. `docs/phase-0/step-18-chiptool-runtime-ready-gate.md`
3. `reports/phase-0/step-18-chiptool-runtime-ready-gate-report.md`

## 3. Wyniki walidacji

### 3.1 Parse-check skryptu gate

- Wynik:
  1. `PASS`

### 3.2 Preflight z runtime-ready log

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step17/serial_commissioning_runtime_diag.log -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -Instance c12-com11-step18-preflight-ready`
- Wynik:
  1. `status=preflight_ready`
  2. `runtime_diag_status=ready`

### 3.3 RunPairing z runtime-ready log

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 ... -RunPairing -Instance c12-com11-step18-runpair-ready`
- Wynik:
  1. `status=fail_pairing`
  2. `status_reason=pairing timeout waiting for mDNS resolution`
  3. `runtime_gate_blocked=false`

### 3.4 RunPairing z runtime-not-ready log

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 ... -RuntimeDiagLogPath artifacts/commissioning/c12-com11-step18-runtime-not-ready.log -RunPairing -Instance c12-com11-step18-runpair-blocked`
- Wynik:
  1. `status=blocked_runtime_not_ready`
  2. `runtime_gate_blocked=true`
  3. Pairing nie zostal uruchomiony (`pairing_exit=-999`)

### 3.5 Artefakty walidacji

1. `artifacts/commissioning/c12-com11-step18-preflight-ready/chiptool_gate_result.json`
2. `artifacts/commissioning/c12-com11-step18-runpair-ready/chiptool_gate_result.json`
3. `artifacts/commissioning/c12-com11-step18-runpair-blocked/chiptool_gate_result.json`
4. `artifacts/commissioning/c12-com11-step18-runtime-not-ready.log`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. E2E pairing nadal zatrzymuje sie na mDNS timeout mimo runtime-ready.
  2. Runtime-ready gate bazuje na markerach serial smoke; to sygnal gotowosci runtime, nie pelna gwarancja interoperacyjnosci w sieci.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 09:
  1. Dodac runner e2e (step16 + step12) dla powtarzalnych testow commissioning gate.
  2. Rozszerzyc diagnostyke o sygnaly transport/mDNS i powtorzyc `-RunPairing` do uzyskania `status=pass`.
