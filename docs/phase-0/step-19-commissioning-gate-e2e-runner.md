# Faza 0 - Krok 19: commissioning gate e2e runner

## Cel

Dodac jeden skrypt uruchomieniowy, ktory spina runtime diagnostics (step16) i gate `chip-tool` (step12) w powtarzalny przeplyw testowy.

## Co zostalo dodane/zmienione

1. Nowy skrypt:
   - `scripts/phase0_step19_commissioning_gate_e2e.ps1`
2. Zakres funkcjonalny skryptu:
   - opcjonalne uruchomienie `step16` (`-SkipRuntimeDiag` pozwala uzyc gotowego logu),
   - uruchomienie `step12` z przekazaniem logu runtime diagnostics,
   - zapis wspolnego wyniku do `commissioning_gate_e2e_result.json`,
   - zachowanie logow wywolan:
     - `step16_invocation.log`
     - `step12_invocation.log`
3. Scenariusze obslugiwane przez runner:
   - preflight (`RunPairing=false`),
   - pairing z runtime-ready,
   - pairing z runtime-not-ready (oczekiwany `blocked_runtime_not_ready`).

## Walidacja

1. Parse-check skryptu:

```powershell
@'
Set-StrictMode -Version Latest
[void][System.Management.Automation.Language.Parser]::ParseFile(
  "scripts/phase0_step19_commissioning_gate_e2e.ps1",
  [ref]$null,
  [ref]$null
)
'@ | powershell -ExecutionPolicy Bypass -
```

2. Preflight-ready (na logu runtime-ready):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step17/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -Instance c19-com11-step19-preflight-ready
```

3. RunPairing blocked (na logu runtime-not-ready):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c12-com11-step18-runtime-not-ready.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -Instance c19-com11-step19-runpair-blocked
```

4. RunPairing ready (przejscie przez gate, pairing probowany):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step17/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -Instance c19-com11-step19-runpair-ready
```

## Kryterium zaliczenia

1. Runner tworzy pojedynczy artefakt wynikowy E2E.
2. Status gate i diagnostyka runtime sa propagowane do wyniku runnera.
3. Scenariusz not-ready blokuje pairing deterministycznie.

## Nastepny krok

1. Podlaczyc realny sygnal gotowosci sieciowej (transport + mDNS advertisement) do runtime diagnostics.
2. Domknac `-RunPairing` do stabilnego `status=pass` na ESP32-C6.
