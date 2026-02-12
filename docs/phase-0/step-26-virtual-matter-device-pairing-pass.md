# Faza 0 - Krok 26: pairing PASS na wirtualnym urzadzeniu Matter

## Cel

Domknac pelny przebieg `discovery + pairing` do `status=pass` bez fizycznej bramki, przez uruchomienie software'owego urzadzenia Matter (`chip-all-clusters-app`) w WSL.

## Co zostalo dodane/zmienione

1. `scripts/phase0_step26_virtual_device_pairing.ps1`
   - nowy runner kroku 26:
     1. uruchamia wirtualne urzadzenie Matter (Linux all-clusters app),
     2. wykonuje `step12` z aktywnymi gate:
        - `RequireRuntimeReadyForPairing=true`
        - `RequireNetworkAdvertisingForPairing=true`
        - `RequireDiscoveryFoundForPairing=true`
     3. zapisuje wynik do `virtual_device_pairing_result.json`.
   - waliduje obecność binarek:
     - `chip-tool`
     - `chip-all-clusters-app`

2. Zakres walidowany przez runner:
   - discovery precheck (`found`),
   - run pairing (`chip-tool pairing onnetwork-long ...`),
   - finalny status gate (`pass`).

## Walidacja

1. Parse-check:

```powershell
@'
Set-StrictMode -Version Latest
[void][System.Management.Automation.Language.Parser]::ParseFile(
  "scripts/phase0_step26_virtual_device_pairing.ps1",
  [ref]$null,
  [ref]$null
)
'@ | powershell -ExecutionPolicy Bypass -
```

2. Run kroku 26:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step26_virtual_device_pairing.ps1 `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -VirtualDeviceAppWslPath /home/thete/umatter-work/connectedhomeip/out/all-clusters/chip-all-clusters-app `
  -NodeId 778899 `
  -Instance c26-com11-step26-virtual-pairing
```

## Kryterium zaliczenia

1. `gate_status=pass`.
2. `gate_discovery_precheck_status=found`.
3. `status_reason=pairing command completed successfully`.

## Nastepny krok

1. Przeniesc sciezke `pass` z wirtualnego urzadzenia na docelowy firmware uMatter (realny advertisement + commissioning stack).
2. Zachowac krok 26 jako test referencyjny kontrolera i narzedzi hostowych.
