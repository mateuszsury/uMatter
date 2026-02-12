# Faza 0 - Krok 22: runtime contract dla network advertising

## Cel

Przeniesc stan `network_advertising` z poziomu placeholder w API Python do natywnego runtime `umatter_core`, tak aby diagnostyka i gate mialy stabilny kontrakt sygnalu.

## Co zostalo dodane/zmienione

1. `modules/umatter/include/umatter_core.h`
   - nowe stale powodow `NETWORK_ADVERTISING_REASON_*`:
     - `UNKNOWN`
     - `RUNTIME_NOT_READY`
     - `NOT_INTEGRATED`
     - `SIGNAL_PRESENT`
     - `SIGNAL_LOST`
   - nowe API:
     - `umatter_core_set_network_advertising(handle, advertising, reason_code)`
     - `umatter_core_get_network_advertising(handle, &advertising, &reason_code)`

2. `modules/umatter/src/umatter_core_runtime.c`
   - runtime node przechowuje:
     - `network_advertising` (bool)
     - `network_advertising_reason` (uint8)
   - dodany reconcile state:
     - gdy runtime nie jest gotowe -> `network_advertising=False`, reason=`runtime_not_ready`
     - gdy runtime gotowe i brak realnego sygnalu -> reason=`not_integrated`
   - `set_network_advertising(True, ...)` zwraca `ERR_STATE`, jesli runtime nie jest gotowe.

3. `modules/umatter/src/mod_umatter_core.c`
   - nowe funkcje w `_umatter_core`:
     - `set_network_advertising(handle, advertising[, reason_code])`
     - `get_network_advertising(handle)` -> `(bool, reason_code)`
   - wyeksportowane stale `NETWORK_ADVERTISING_REASON_*`.

4. `modules/umatter/src/mod_umatter.c`
   - `Node.commissioning_diagnostics()` pobiera teraz `network_advertising` oraz `network_advertising_reason` bezposrednio z `umatter_core`.
   - mapowanie reason code -> string:
     - `runtime_not_ready`
     - `not_integrated`
     - `signal_present`
     - `signal_lost`
     - `unknown`

5. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
   - rozszerzony smoke `_umatter_core` o markery walidujace nowe API i przejscia stanu:
     - `C16:C_NET0`
     - `C16:C_SET_NET0`
     - `C16:C_NET1`
     - `C16:C_SET_NET1`
     - `C16:C_NET2`
     - `C16:C_SET_NET2`
     - `C16:C_NET3`
     - `C16:C_NET4`

## Walidacja

1. Parse-check:
   - `scripts/phase0_step16_commissioning_runtime_diag.ps1`
   - `scripts/phase0_step12_chiptool_gate.ps1`
   - `scripts/phase0_step19_commissioning_gate_e2e.ps1`

2. Runtime diagnostics smoke (live, C6 COM11):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -ComPort COM11 `
  -Instance c16-com11-step22-finalize `
  -EndpointId 9 `
  -Passcode 24681357 `
  -Discriminator 1234
```

3. Gate step12 z network gate i discovery:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step22-finalize/serial_commissioning_runtime_diag.log `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c12-com11-step22-finalize-runpair-discovery
```

4. Runner e2e step19:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -SkipRuntimeDiag `
  -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step22-finalize/serial_commissioning_runtime_diag.log `
  -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -Instance c19-com11-step22-finalize-runpair-discovery
```

## Kryterium zaliczenia

1. `network_advertising` ma stabilny kontrakt runtime w `umatter_core`.
2. `Node.commissioning_diagnostics()` nie korzysta z placeholder logic.
3. Smoke host waliduje przejscia stanu advertising i reason.

## Nastepny krok

1. Wystawic kontrolowany update sygnalu advertising na poziomie API `umatter.Node` (operator/runtime hook).
2. Uzyc tego sygnalu do testu dodatniej sciezki gate (`RequireNetworkAdvertisingForPairing=true`) przed realnym podpieciem mDNS z esp-matter.
