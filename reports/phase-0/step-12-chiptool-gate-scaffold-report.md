# Raport fazy 0 - krok 12 (chip-tool gate scaffold)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie hostowego gate dla `chip-tool` (preflight + matrix row).
  2. Integracja z artefaktami commissioning z kroku 11.
  3. Walidacja statusu na aktualnym srodowisku hosta.
- Decyzje:
  1. Gate oddziela brak narzedzia (`blocked_tool_missing`) od bledow pairing/runtime.
  2. Domyslnie uruchamiany jest tylko preflight (bez realnego pairing command).
  3. Wynik gate zapisuje gotowa komende pairing do kolejnego etapu.

## 2. Zmienione pliki

1. `scripts/phase0_step11_commissioning_smoke.ps1` (uodpornienie parsowania `WithLevelControl`)
2. `scripts/phase0_step12_chiptool_gate.ps1`
3. `docs/phase-0/step-12-chiptool-gate-scaffold.md`
4. `reports/phase-0/step-12-chiptool-gate-scaffold-report.md`

## 3. Wyniki walidacji

### 3.1 Środowisko

1. Windows: `chip-tool` nieobecny w PATH.
2. WSL: `chip-tool` nieobecny.
3. `winget search chip-tool`: brak paczki.
4. Docker dostępny, ale próby pull publicznych obrazów `chip-tool` zwracaly `denied/not found`.

### 3.2 Uruchomienie gate

Polecenie:

```powershell
& scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step11/commissioning_data.json -Instance c12-com11-step12
```

Wynik:
1. Status: `blocked_tool_missing`
2. Powod: `chip-tool binary not found in PATH`
3. Wygenerowana komenda:
   - `chip-tool pairing onnetwork-long 112233 23456789 2222`

Artefakty:
1. `artifacts/commissioning/c12-com11-step12/chiptool_gate_result.json`
2. `artifacts/commissioning/c12-com11-step12/chiptool_preflight.log`
3. `artifacts/commissioning/c12-com11-step12/chiptool_matrix_row.md`

### 3.3 Retest kroku 11 po poprawce parametru

Polecenie:

```powershell
& scripts/phase0_step11_commissioning_smoke.ps1 -ComPort COM11 -DeviceName uMatter-C11b -EndpointId 5 -Passcode 34567890 -Discriminator 1111 -WithLevelControl false -Instance c11-com11-step11b
```

Wynik:
1. `Commissioning smoke: PASS`
2. `commissioning_data.json` poprawnie zapisuje `with_level_control=false`.

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak lokalnej binarki `chip-tool`.
- Ryzyka:
  1. Bez `chip-tool` nie da sie domknac e2e pairing na tym kroku.
  2. Firmware commissioning jest nadal placeholder, więc nawet po dostarczeniu `chip-tool` pairing moze byc logicznie ograniczony.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 (`agents/07-thread-commissioning.md`) + Agent 01 (`agents/01-build-flash.md`):
  1. Dostarczyc `chip-tool` (lokalnie lub przez kontrolowany build narzedzia).
  2. Uruchomic `scripts/phase0_step12_chiptool_gate.ps1 -RunPairing`.
  3. Zapisac wynik pairing e2e i dopiac matrix interoperability.
