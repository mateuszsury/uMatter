# Raport fazy 0 - krok 14 (integracja commissioning codes z chip-tool gate)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Integracja danych commissioning code (krok 13) z gate `chip-tool` (krok 12).
  2. Uzupełnienie matrix row o `manual_code` i `node_qr_code`.
  3. Retest host smoke + gate na `ESP32-C6` (`COM11`).
- Decyzje:
  1. `manual_code` ma fallback wyliczany z `discriminator/passcode`, nawet bez pliku codes.
  2. `commissioning_codes_data.json` jest dobierany automatycznie po zgodnym `passcode/discriminator`.
  3. Pairing mode jest jawny (`onnetwork-long` lub `onnetwork`) i zgodny z parametrem gate.

## 2. Zmienione pliki

1. `scripts/phase0_step12_chiptool_gate.ps1`
2. `scripts/phase0_step13_commissioning_codes_smoke.ps1`
3. `docs/phase-0/step-14-chiptool-gate-codes-integration.md`
4. `reports/phase-0/step-14-chiptool-gate-codes-integration-report.md`

## 3. Wyniki walidacji

Krok 11:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step11_commissioning_smoke.ps1 -ComPort COM11 -DeviceName uMatter-C14 -EndpointId 8 -Passcode 24681357 -Discriminator 1234 -WithLevelControl true -Instance c11-com11-step14
```

Wynik:
1. `Commissioning smoke: PASS`

Krok 13:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step13_commissioning_codes_smoke.ps1 -ComPort COM11 -DeviceName uMatter-C14 -EndpointId 8 -Passcode 24681357 -Discriminator 1234 -Instance c13-com11-step14b
```

Wynik:
1. `Commissioning code smoke: PASS`
2. W JSON zapisane:
   - `node_manual_code=00224681357`
   - `node_qr_code=MT:UMFFF18000123424681357`
   - `light_qr_code=MT:UMFFF18101123424681357`
   - `core_qr_code=MT:UMFFF19001123424681357`

Krok 12 (po integracji):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -Instance c12-com11-step14
```

Wynik:
1. Status: `blocked_tool_missing`
2. Jednoczesnie potwierdzone:
   - `commissioning_codes_status=matched`
   - `manual_code=00224681357`
   - `node_qr_code=MT:UMFFF18000123424681357`

Artefakty:
1. `artifacts/commissioning/c11-com11-step14/commissioning_data.json`
2. `artifacts/commissioning/c13-com11-step14b/commissioning_codes_data.json`
3. `artifacts/commissioning/c12-com11-step14/chiptool_gate_result.json`
4. `artifacts/commissioning/c12-com11-step14/chiptool_matrix_row.md`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak lokalnej binarki `chip-tool`.
- Ryzyka:
  1. Bez `chip-tool` nie domkniemy realnego pairing e2e.
  2. Commissioning flow runtime jest nadal etapem PoC/placeholder.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 (`agents/07-thread-commissioning.md`) + Agent 09 (`agents/09-test-certification.md`):
  1. Dostarczyc `chip-tool`.
  2. Uruchomic `scripts/phase0_step12_chiptool_gate.ps1 -RunPairing`.
  3. Uzupełnic matrix o pierwszy wynik e2e pairing dla C6.
