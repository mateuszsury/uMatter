# Faza 0 - Krok 18: chip-tool gate z warunkiem runtime ready

## Cel

Wpiac diagnostyke runtime commissioning (`ready_reason`, `runtime`, `ready`) do gate `chip-tool`, tak aby pairing byl blokowany gdy firmware nie jest gotowe do komisjonowania.

## Co zostalo dodane/zmienione

1. `scripts/phase0_step12_chiptool_gate.ps1`:
   - nowe parametry:
     - `RuntimeDiagLogPath`
     - `RequireRuntimeReadyForPairing` (domyslnie `true`)
   - parser logu runtime diagnostics:
     - markery `C16:N_DIAG_RUNTIME`, `C16:N_DIAG_REASON`, `C16:N_DIAG_REASON_CODE`, `C16:N_DIAG_READY`
     - fallback do `C16:N_REASON3`
   - auto-detekcja najnowszego `serial_commissioning_runtime_diag.log` pod `artifacts/commissioning`
   - nowy status gate:
     - `blocked_runtime_not_ready` (pairing pomijany, gdy runtime niegotowy)
2. Wynik `chiptool_gate_result.json` rozszerzony o pola runtime:
   - `runtime_diag_status`
   - `runtime_diag_status_reason`
   - `runtime_state`
   - `runtime_ready`
   - `runtime_ready_reason`
   - `runtime_ready_reason_code`
   - `require_runtime_ready_for_pairing`
   - `runtime_gate_blocked`
3. Wiersz macierzy (`chiptool_matrix_row.md`) zawiera runtime status/reason i uzywa stanu runtime jako transport state.

## Walidacja

1. Parse-check skryptu:

```powershell
@'
Set-StrictMode -Version Latest
[void][System.Management.Automation.Language.Parser]::ParseFile(
  "scripts/phase0_step12_chiptool_gate.ps1",
  [ref]$null,
  [ref]$null
)
'@ | powershell -ExecutionPolicy Bypass -
```

2. Preflight z logiem runtime-ready:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step17/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -Instance c12-com11-step18-preflight-ready
```

3. RunPairing z runtime-ready:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step17/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -Instance c12-com11-step18-runpair-ready
```

4. RunPairing z logiem not-ready (pairing zablokowany przez gate):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c12-com11-step18-runtime-not-ready.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -Instance c12-com11-step18-runpair-blocked
```

## Kryterium zaliczenia

1. Gate rozpoznaje `runtime ready` i pozwala uruchomic pairing.
2. Gate blokuje pairing przy runtime not-ready (`blocked_runtime_not_ready`).
3. Wynik JSON i matrix row zawieraja pelna diagnostyke runtime.

## Nastepny krok

1. Dodac jeden runner e2e spinajacy step16 + step12 w powtarzalny przeplyw.
2. Kontynuowac integracje runtime commissioning, aby przejsc do stabilnego `status=pass` dla `-RunPairing`.
