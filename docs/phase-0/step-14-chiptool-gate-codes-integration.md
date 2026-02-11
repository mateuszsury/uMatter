# Faza 0 - Krok 14: Integracja commissioning codes z chip-tool gate

## Cel

Podlaczyc wynik kroku 13 (`manual_code`/`qr_code`) do hostowego gate kroku 12, aby matrix interoperability mial kompletne dane commissioning nawet gdy `chip-tool` jest niedostepny.

## Co zostalo dodane

1. Rozszerzenie `scripts/phase0_step12_chiptool_gate.ps1`:
   - nowy parametr `-CommissioningCodesDataPath`,
   - automatyczne wyszukiwanie `commissioning_codes_data.json` po zgodnym `passcode/discriminator`,
   - dolaczenie do wyniku:
     - `manual_code`,
     - `node_qr_code`,
     - `commissioning_codes_status`,
     - `commissioning_codes_data_path`,
   - poprawka uruchamiania pairing:
     - respektowany `-UseOnNetworkLong` (`onnetwork-long` albo `onnetwork`).
2. Rozszerzenie `scripts/phase0_step13_commissioning_codes_smoke.ps1`:
   - `commissioning_codes_data.json` zawiera teraz:
     - `node_manual_code`,
     - `node_qr_code`,
     - `light_qr_code`,
     - `core_qr_code`.

## Uruchomienie

1. Dane commissioning (krok 11):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step11_commissioning_smoke.ps1 `
  -ComPort COM11 `
  -DeviceName uMatter-C14 `
  -EndpointId 8 `
  -Passcode 24681357 `
  -Discriminator 1234 `
  -Instance c11-com11-step14
```

2. Dane commissioning codes (krok 13):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step13_commissioning_codes_smoke.ps1 `
  -ComPort COM11 `
  -DeviceName uMatter-C14 `
  -EndpointId 8 `
  -Passcode 24681357 `
  -Discriminator 1234 `
  -Instance c13-com11-step14b
```

3. Gate (krok 12 z integracja codes):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -Instance c12-com11-step14
```

## Kryterium zaliczenia

1. `chiptool_gate_result.json` zawiera commissioning codes metadata.
2. `chiptool_matrix_row.md` zawiera `manual=` oraz `qr=` w polu details.
3. Status gate pozostaje rozroznywalny (`blocked_tool_missing`, `preflight_ready`, `pass`, `fail_*`).

## Nastepny krok

1. Dostarczyc lokalny `chip-tool`.
2. Uruchomic:
   - `scripts/phase0_step12_chiptool_gate.ps1 -RunPairing ...`
3. Zamknac pierwszy realny wynik e2e pairing w matrix dla C6.
