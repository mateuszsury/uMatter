# Faza 0 - Krok 25: Python mock gateway dla discovery bez fizycznej bramki

## Cel

Umowic testowanie discovery i gate commissioning bez fizycznej bramki Matter, przez lokalny emulator w Pythonie uruchamiany na hoście.

## Co zostalo dodane/zmienione

1. `scripts/mock_matter_gateway.py`
   - nowy emulator commissionable mDNS `_matterc._udp.local.`
   - publikuje pola TXT (`D`, `VP`, `CM`, `DT`, `DN`, `PH`, `PI`)
   - moze dzialac czasowo (`--lifetime-seconds`)
   - domyslnie publikuje tez subtypy discovery (`_Lxxxx`, `_Sx`)

2. `scripts/phase0_step25_mock_gateway_discovery.ps1`
   - nowy runner kroku 25:
     1. przygotowuje venv w WSL (`/tmp/umatter-mock-gateway-venv`) i instaluje `zeroconf`
     2. uruchamia `mock_matter_gateway.py`
     3. uruchamia `step12` z:
        - `RequireNetworkAdvertisingForPairing=true`
        - `RequireDiscoveryFoundForPairing=true`
     4. zapisuje wynik do `mock_gateway_discovery_result.json`

3. `scripts/phase0_step12_chiptool_gate.ps1`
   - discovery precheck rozszerzony o fallback:
     1. primary: `discover find-commissionable-by-long-discriminator`
     2. fallback: `discover commissionables --discover-once true`
   - parser discovery dopasowany do formatu logow `chip-tool` (`[DIS] ... Long Discriminator: ...`).
   - nowe pola wyniku:
     - `discovery_precheck_method`
     - `discovery_precheck_fallback_used`

4. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
   - propagacja nowych pol discovery z `step12` do wyniku e2e.

## Walidacja

1. Parse-check:
   - `scripts/phase0_step12_chiptool_gate.ps1`
   - `scripts/phase0_step19_commissioning_gate_e2e.ps1`
   - `scripts/phase0_step25_mock_gateway_discovery.ps1`
2. Python compile-check:
   - `python -m py_compile scripts/mock_matter_gateway.py`
3. Run kroku 25:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step25_mock_gateway_discovery.ps1 `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -Discriminator 1234 `
  -Instance c25-com11-step25-mock-gateway-found
```

## Kryterium zaliczenia

1. `discovery_precheck_status=found` bez fizycznej bramki.
2. `discovery_precheck_method=commissionables_fallback` jest raportowane deterministycznie.
3. Gate nie blokuje juz na discovery (`blocked_discovery_not_found` nie wystepuje), przechodzac do realnej proby pairing.

## Nastepny krok

1. Podpiac realny sygnal commissionable advertisement z runtime/esp-matter (zamiast emulacji hostowej).
2. Domknac pairing do `status=pass` (obecnie: `fail_pairing`, bo emulator nie implementuje protokolu Matter/PASE).
