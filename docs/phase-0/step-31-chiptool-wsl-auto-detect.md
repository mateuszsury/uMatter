# Faza 0 - Krok 31: auto-detekcja chip-tool w WSL

## Cel

Usunac koniecznosc recznego podawania `-ChipToolWslPath` w `step12` przez automatyczne wykrywanie binarki `chip-tool` dla trybu WSL.

## Co zostalo dodane/zmienione

1. `scripts/phase0_step12_chiptool_gate.ps1`
   - dodana funkcja `Resolve-WslChipToolAutoPath`.
   - kolejnosc auto-detekcji:
     1. `command -v chip-tool` w WSL,
     2. `CHIP_TOOL_WSL_PATH`,
     3. `CHIP_TOOL_PATH`,
     4. `${HOME}/umatter-work/connectedhomeip/out/chip-tool/chip-tool`,
     5. `${HOME}/connectedhomeip/out/chip-tool/chip-tool`.
   - wykryta sciezka jest automatycznie ustawiana jako `chip_tool_path` i `chip_tool_mode=wsl`.

## Walidacja

1. Step12 bez `-ChipToolWslPath`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -Instance c12-20260212-step31-autochip-r2 `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8
```

Wynik:
1. `chip_tool_path=/home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool`
2. `chip_tool_mode=wsl`
3. `discovery_precheck_status=not_found` (zamiast `unavailable_tool`)

## Kryterium zaliczenia

1. Brak `unavailable_tool` przy dostepnym `chip-tool` poza PATH.
2. `step12` dziala w trybie discovery bez recznej konfiguracji sciezki.
3. Zachowana zgodnosc z dotychczasowym `-ChipToolPath` i `-ChipToolWslPath`.

## Nastepny krok

1. Dodac host-side discovery probe (mDNS) niezalezny od `chip-tool`, aby szybciej diagnozowac `not_found`.
