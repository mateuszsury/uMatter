# Raport fazy 0 - krok 15 (chip-tool w WSL + gate commissioning)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Zbudowanie `chip-tool` lokalnie w WSL.
2. Integracja uruchamiania WSL `chip-tool` w `phase0_step12_chiptool_gate.ps1`.
  3. Wykonanie preflight i probe `-RunPairing` z artefaktami.
  4. Dodanie klasyfikacji przyczyny pairing failure (np. timeout mDNS).
- Decyzje:
  1. Wsparcie binarki Linux przez parametr `-ChipToolWslPath`.
  2. Preflight oparty o `chip-tool pairing` (output usage command-set), bo `--help` nie jest stabilnym kodem wyjscia.
  3. Wynik pairing raportowany bez maskowania: `fail_pairing` + log diagnostyczny.

## 2. Zmienione pliki

1. `scripts/phase0_step12_chiptool_gate.ps1`
2. `scripts/phase0_step13_commissioning_codes_smoke.ps1`
3. `docs/phase-0/step-15-chiptool-wsl-build-and-gate.md`
4. `reports/phase-0/step-15-chiptool-wsl-build-and-gate-report.md`

## 3. Wyniki walidacji

### 3.1 Build chip-tool (WSL)

1. Repo: `~/umatter-work/connectedhomeip`
2. Binarka: `~/umatter-work/connectedhomeip/out/chip-tool/chip-tool`
3. Status: `PASS`

Wymagane pakiety WSL doinstalowane:
1. `libglib2.0-dev-bin`
2. `libglib2.0-dev`
3. `libevent-dev`

### 3.2 Gate preflight

Polecenie:

```powershell
& scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -Instance c12-com11-step14-preflight2
```

Wynik:
1. `status=preflight_ready`
2. `chip_tool_mode=wsl`
3. `commissioning_codes_status=matched`
4. `manual_code=00224681357`
5. `node_qr_code=MT:UMFFF18000123424681357`

Artefakty:
1. `artifacts/commissioning/c12-com11-step14-preflight2/chiptool_gate_result.json`
2. `artifacts/commissioning/c12-com11-step14-preflight2/chiptool_preflight.log`

### 3.3 Gate RunPairing

Polecenie:

```powershell
& scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -Instance c12-com11-step14-runpair
```

Wynik:
1. `status=fail_pairing` (oczekiwane na obecnym placeholder commissioning)
2. `pairing_exit=1`
3. W logu: timeout mDNS (`Timeout waiting for mDNS resolution`)
4. `status_reason=pairing timeout waiting for mDNS resolution`

Artefakty:
1. `artifacts/commissioning/c12-com11-step14-runpair/chiptool_gate_result.json`
2. `artifacts/commissioning/c12-com11-step14-runpair/chiptool_pairing.log`
3. `artifacts/commissioning/c12-com11-step14-runpair/chiptool_matrix_row.md`
4. `artifacts/commissioning/c12-com11-step15-runpair2/chiptool_gate_result.json`
5. `artifacts/commissioning/c12-com11-step15-runpair2/chiptool_pairing.log`
6. `artifacts/commissioning/c12-com11-step15-runpair2/chiptool_matrix_row.md`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak, `chip-tool` jest dostepny i gate dziala.
- Ryzyka:
  1. Runtime commissioning jest nadal placeholder, dlatego pairing e2e nie przechodzi.
  2. Brak transportowego flow commissioning na urzadzeniu (odpowiedzi mDNS/on-network) dla realnej sesji.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 (`agents/07-thread-commissioning.md`) + Agent 03 (`agents/03-core-binding-cpp.md`):
  1. Dolozyc realny commissioning runtime flow po stronie firmware.
  2. Powtorzyc `-RunPairing` i sklasyfikowac wynik jako `pass` albo konkretny blad protokolu.
