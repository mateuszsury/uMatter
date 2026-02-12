# Faza 0 - Krok 24: discovery-required gate przed pairing

## Cel

Dolozyc osobny, opcjonalny warunek gate: `RequireDiscoveryFoundForPairing`, ktory blokuje pairing, gdy precheck `chip-tool discover` nie zwroci commissionable entry.

## Co zostalo dodane/zmienione

1. `scripts/phase0_step12_chiptool_gate.ps1`
   - nowy parametr:
     - `RequireDiscoveryFoundForPairing` (domyslnie `false`)
   - walidacja parametrow:
     - `RequireDiscoveryFoundForPairing=true` wymaga `RunDiscoveryPrecheck=true`
   - nowy status gate:
     - `blocked_discovery_not_found`
   - nowe pola JSON:
     - `require_discovery_found_for_pairing`
     - `discovery_gate_blocked`

2. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
   - nowy parametr:
     - `RequireDiscoveryFoundForPairing` (domyslnie `false`)
   - propagacja parametru do step12.
   - nowy parametr:
     - `SimulateNetworkAdvertising`
   - propagacja `SimulateNetworkAdvertising` do step16, gdy runner nie ma `-SkipRuntimeDiag`.
   - nowe pola wyniku e2e:
     - `gate_discovery_gate_blocked`
     - `gate_require_discovery_found_for_pairing`
     - `simulate_network_advertising`

## Walidacja

1. Parse-check:
   - `scripts/phase0_step12_chiptool_gate.ps1`
   - `scripts/phase0_step19_commissioning_gate_e2e.ps1`

2. Step12, discovery wymagane:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c12-com11-step24-runpair-discovery-required
```

3. Step12, discovery niewymagane (porownanie):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing false `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c12-com11-step24-runpair-discovery-optional
```

4. Step19, log zewnetrzny:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c19-com11-step24-discovery-required-external
```

5. Step19 live (runner uruchamia step16):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -ComPort COM11 `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -SimulateNetworkAdvertising `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -Instance c19-com11-step24-discovery-required-live
```

## Kryterium zaliczenia

1. Przy `RequireDiscoveryFoundForPairing=true` i `discover=not_found` status to `blocked_discovery_not_found`.
2. Przy `RequireDiscoveryFoundForPairing=false` gate nie blokuje na discovery i pairing przechodzi do prob wykonania.
3. Runner step19 propaguje nowy status i pola discovery gate.

## Nastepny krok

1. Podpiac realny sygnal commissionable advertisement z runtime/esp-matter, aby `discover=found`.
2. Domknac pairing do `status=pass` bez symulacji.
