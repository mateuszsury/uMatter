# Faza 0 - Krok 15: chip-tool z WSL + uruchomienie gate preflight/pairing

## Cel

Zdjac blocker kroku 12 (`chip-tool` niedostepny) i doprowadzic gate commissioning do stanu:
1. `preflight_ready` na realnej binarce,
2. probe `-RunPairing` z zapisem wyniku i logu.

## Co zostalo dodane/zmienione

1. Zbudowano `chip-tool` w WSL z `connectedhomeip`:
   - repo: `~/umatter-work/connectedhomeip`
   - binarka: `~/umatter-work/connectedhomeip/out/chip-tool/chip-tool`
2. Rozszerzono `scripts/phase0_step12_chiptool_gate.ps1`:
   - nowy parametr `-ChipToolWslPath`,
   - fallback autodiscovery `chip-tool` w WSL (`command -v chip-tool`),
   - nowe pole raportowe:
     - `chip_tool_mode` (`windows` / `wsl`),
   - preflight oparty o `chip-tool pairing` (command-set usage),
   - preflight uznawany za poprawny gdy output zawiera usage command-set,
   - klasyfikacja przyczyny `fail_pairing` na podstawie logu (`mDNS timeout`, `PASE`, syntax).
3. Utrzymano integracje commissioning codes:
   - `manual_code` i `node_qr_code` trafiaja do gate result i matrix row.

## Build chip-tool (WSL)

```bash
cd ~/umatter-work
git clone --depth 1 https://github.com/project-chip/connectedhomeip.git
cd connectedhomeip
./scripts/checkout_submodules.py --shallow --platform linux
./scripts/examples/gn_build_example.sh examples/chip-tool out/chip-tool
```

Doinstalowane zaleznosci systemowe (WSL Ubuntu):
1. `libglib2.0-dev-bin`
2. `libglib2.0-dev`
3. `libevent-dev`

## Uruchomienie gate z WSL chip-tool

Preflight:

```powershell
& scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -Instance c12-com11-step14-preflight2
```

Pairing:

```powershell
& scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -Instance c12-com11-step14-runpair
```

## Kryterium zaliczenia

1. Gate potrafi wykryc i uruchomic `chip-tool` z WSL.
2. `chiptool_gate_result.json` zawiera:
   - `chip_tool_mode=wsl`,
   - status `preflight_ready` dla preflight.
3. Dla `-RunPairing`:
   - status `fail_pairing` lub `pass`,
   - log pairing zawiera diagnostyke.

## Nastepny krok

1. Rozszerzyc runtime commissioning ponad placeholder i ponowic `-RunPairing`.
2. Dodac klasyfikacje przyczyny pairing failure (np. timeout mDNS vs. auth fail) do gate result.
