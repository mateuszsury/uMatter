# Faza 0 - Krok 12: chip-tool gate scaffold (preflight + matrix status)

## Cel

Dodac powtarzalny gate pod realny commissioning e2e z `chip-tool`:
1. pobranie danych commissioning z poprzedniego kroku,
2. preflight binarki `chip-tool`,
3. generacja komendy pairing i statusu do matrix.

## Co zostalo dodane

1. Nowy skrypt:
   - `scripts/phase0_step12_chiptool_gate.ps1`
2. Funkcje skryptu:
   - wczytanie `commissioning_data.json`,
   - wykrycie `chip-tool` (PATH albo `-ChipToolPath`),
   - przygotowanie komendy:
     - `chip-tool pairing onnetwork-long <node_id> <passcode> <discriminator>`
   - opcjonalne uruchomienie pairing (`-RunPairing`),
   - zapis artefaktow:
     - `chiptool_preflight.log`
     - `chiptool_gate_result.json`
     - `chiptool_matrix_row.md`

## Parametry

1. `-CommissioningDataPath` (domyslnie najnowszy JSON z `artifacts/commissioning`)
2. `-ChipToolPath` (opcjonalna sciezka binarki)
3. `-NodeId` (domyslnie `112233`)
4. `-RunPairing` (opcjonalnie wykonuje pairing command)
5. `-UseOnNetworkLong` (domyslnie wlaczone)
6. `-Instance` (domyslnie auto timestamp)
7. `-ArtifactsRoot` (domyslnie `artifacts/commissioning`)

## Uruchomienie

```powershell
& scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step11/commissioning_data.json `
  -Instance c12-com11-step12
```

## Kryterium zaliczenia

1. Skrypt konczy sie bez bledu i zapisuje artefakty.
2. `chiptool_gate_result.json` zawiera:
   - status (`preflight_ready` / `pass` / `fail_*` / `blocked_*`)
   - skompilowana komende pairing
   - referencje do logow
3. `chiptool_matrix_row.md` jest gotowy do raportu matrix.

## Nastepny krok

Doprowadzic do stanu `preflight_ready` lub `pass`:
1. dostarczyc `chip-tool` w srodowisku hosta,
2. uruchomic `-RunPairing` na firmware z realnym commissioning flow,
3. uzupelnic matrix o wynik e2e pairing.
