# Raport fazy 0 - krok 22 (runtime contract network advertising)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie natywnego kontraktu `network_advertising` w `umatter_core`.
  2. Rozszerzenie `_umatter_core` o set/get stanu advertising.
  3. Podpiecie `Node.commissioning_diagnostics()` do danych runtime zamiast placeholder.
  4. Rozszerzenie smoke step16 o walidacje przejsc stanu advertising.
- Decyzje:
  1. Wymusic `runtime_not_ready` jako nadrzedny reason, gdy node nie jest commissioning-ready.
  2. Dla runtime-ready bez integracji mDNS raportowac `not_integrated`.
  3. Zabronic ustawienia `advertising=True` w stanie niegotowym (`ERR_STATE`).

## 2. Zmienione pliki

1. `modules/umatter/include/umatter_core.h`
2. `modules/umatter/src/umatter_core_runtime.c`
3. `modules/umatter/src/mod_umatter_core.c`
4. `modules/umatter/src/mod_umatter.c`
5. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
6. `docs/phase-0/step-22-runtime-network-advertising-state-contract.md`
7. `reports/phase-0/step-22-runtime-network-advertising-state-contract-report.md`

## 3. Wyniki walidacji

### 3.1 Parse-check

- Wynik:
  1. `PASS`:
     - `scripts/phase0_step16_commissioning_runtime_diag.ps1`
     - `scripts/phase0_step12_chiptool_gate.ps1`
     - `scripts/phase0_step19_commissioning_gate_e2e.ps1`

### 3.2 Step16 runtime diagnostics (live)

- Polecenie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step22-finalize -EndpointId 9 -Passcode 24681357 -Discriminator 1234`
- Wynik:
  1. `Commissioning runtime diagnostics smoke: PASS`
  2. Potwierdzone markery `_umatter_core`:
     - `C16:C_NET0 (False, 1)`
     - `C16:C_SET_NET0 -3`
     - `C16:C_NET1 (False, 2)`
     - `C16:C_SET_NET1 0`
     - `C16:C_NET2 (True, 3)`
     - `C16:C_SET_NET2 0`
     - `C16:C_NET3 (False, 4)`
     - `C16:C_NET4 (False, 1)`

### 3.3 Step12 network gate + discovery

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step22-finalize/serial_commissioning_runtime_diag.log -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c12-com11-step22-finalize-runpair-discovery`
- Wynik:
  1. `status=blocked_network_not_advertising`
  2. reason zawiera `not_integrated`

### 3.4 Step19 e2e runner

- Polecenie:
  - `scripts/phase0_step19_commissioning_gate_e2e.ps1 -SkipRuntimeDiag -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step22-finalize/serial_commissioning_runtime_diag.log -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c19-com11-step22-finalize-runpair-discovery`
- Wynik:
  1. `Commissioning gate e2e: PASS`
  2. `gate_status=blocked_network_not_advertising`
  3. reason zawiera `not_integrated`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Sygnal advertising wciaz nie jest podpiety do realnego mDNS/esp-matter.
  2. Przy aktywnym network gate pairing pozostaje blokowany, dopoki brak potwierdzenia advertising.

## 5. Nastepny krok dla kolejnego agenta

- Agent 04 + Agent 07:
  1. Dodac kontrolowany hook API `Node` do ustawiania sygnalu advertising (przejscie testowe do sciezki dodatniej gate).
  2. Przygotowac przejscie z hooka testowego do realnego sygnalu z runtime/esp-matter.
