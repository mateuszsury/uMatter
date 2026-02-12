# Faza 0 - Krok 21: chip-tool discovery precheck przed pairing

## Cel

Dolozyc realny precheck mDNS po stronie kontrolera (`chip-tool discover`) przed `pairing`, aby gate mogl opierac decyzje o network advertising nie tylko na runtime diagnostics firmware.

## Co zostalo dodane/zmienione

1. `scripts/phase0_step12_chiptool_gate.ps1`
   - nowe parametry:
     - `RunDiscoveryPrecheck` (domyslnie `true`)
     - `DiscoveryTimeoutSeconds` (domyslnie `8`)
   - precheck uruchamiany gdy:
     - `RunPairing=true`
     - `RequireNetworkAdvertisingForPairing=true`
     - `RunDiscoveryPrecheck=true`
   - precheck (WSL mode):
     - `chip-tool discover find-commissionable-by-long-discriminator <discriminator> --discover-once true`
     - wykonanie ograniczone timeoutem (`timeout Ns`)
   - nowe artefakty/pola wyniku:
     - `chiptool_discovery.log`
     - `discovery_precheck_*` (status, reason, found, exit, mode, timeout)

2. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
   - propaguje nowe parametry discovery do step12.
   - raportuje `gate_discovery_precheck_*` w wyniku e2e.

3. Logika gate:
   - discovery nie odblokowal pairing w obecnym stanie PoC (brak wykrytego commissionable entry),
   - status pozostaje `blocked_network_not_advertising` przy wlaczonym network gate.

## Walidacja

1. Parse-check:

```powershell
@'
Set-StrictMode -Version Latest
[void][System.Management.Automation.Language.Parser]::ParseFile(
  "scripts/phase0_step12_chiptool_gate.ps1",
  [ref]$null,
  [ref]$null
)
[void][System.Management.Automation.Language.Parser]::ParseFile(
  "scripts/phase0_step19_commissioning_gate_e2e.ps1",
  [ref]$null,
  [ref]$null
)
'@ | powershell -ExecutionPolicy Bypass -
```

2. Step12 runpair + discovery precheck:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step20/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c12-com11-step21-runpair-discovery
```

3. Step19 e2e + discovery precheck:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step20/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c19-com11-step21-runpair-discovery
```

## Kryterium zaliczenia

1. Gate zapisuje i raportuje wynik discovery precheck.
2. Runner e2e propaguje status discovery.
3. Przy aktywnym network gate pairing jest blokowany deterministycznie, gdy discovery nie znajduje commissionable.

## Nastepny krok

1. Podpiac realny sygnal advertising z runtime/esp-matter (docelowo `network_advertising=True`).
2. Zachowac discovery precheck jako niezalezny sygnal kontrolera i doprowadzic `gate_status=pass`.
