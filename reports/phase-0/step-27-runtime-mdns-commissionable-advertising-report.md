# Raport fazy 0 - krok 27 (runtime mDNS commissionable advertising hook)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Podpiecie runtime `network_advertising` do realnej proby publikacji `_matterc._udp` w ESP (`mdns`).
  2. Utrzymanie stabilnosci testu step16 dla stanu zintegrowanego i fallback.
  3. Uodpornienie kroku build/flash/smoke na opozniony start REPL po flashu.
- Decyzje:
  1. Publikacja mDNS jest best-effort i nie podnosi wyjatku; wynik trafia do reason code.
  2. Brak publikacji mapowany jest na `not_integrated`, a nie na sztuczne `signal_present`.
  3. Smoke po flashu dostaje retry zamiast pojedynczej proby.

## 2. Zmienione pliki

1. `modules/umatter/src/umatter_core_runtime.c`
2. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
3. `scripts/phase0_step02_c5_e2e.ps1`
4. `docs/HARDWARE_MATRIX.md`
5. `docs/phase-0/step-27-runtime-mdns-commissionable-advertising.md`
6. `reports/phase-0/step-27-runtime-mdns-commissionable-advertising-report.md`

## 3. Wyniki walidacji

### 3.1 Build + flash C6 (COM11)

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -IdfRootWsl /home/thete/esp-idf-5.5.1 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step27-mdnsadv -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -ArtifactsRoot artifacts/esp32c6`
- Wynik:
  1. Build: `PASS`
  2. Flash: `PASS`
  3. App size: `2033184`
  4. Free in app partition (2560 KiB): `588256`
  5. Pierwsza proba smoke po flashu: `FAIL` (`mpremote: could not enter raw repl`)
  6. Smoke po poprawce retry (`-SkipBuild -SkipFlash`): `PASS`

### 3.2 Step16 runtime diagnostics

- Polecenie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step27-mdnsadv-r2`
- Wynik:
  1. `PASS`
  2. Markery:
     - `C16:N_DIAG_NET_ADV False`
     - `C16:N_DIAG_NET_REASON not_integrated`
     - `C16:L_DIAG_NET_ADV False`
     - `C16:L_DIAG_NET_REASON not_integrated`
     - `C16:C_NET1 (False, 2)`
  3. Kontrakt testu zaktualizowany tak, aby akceptowac rowniez wariant zintegrowany (`True/signal_present`).

### 3.3 Step12 network gate

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step27-mdnsadv-r2/serial_commissioning_runtime_diag.log -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -UseOnNetworkLong true -RequireRuntimeReadyForPairing true -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing false -RunDiscoveryPrecheck true -Instance c12-com11-step27-netgate`
- Wynik:
  1. `status=blocked_network_not_advertising`
  2. `status_reason=network diagnostics gate: mDNS advertisement not confirmed (network_advertising=False) (reason=not_integrated)`
  3. Gate zachowuje sie zgodnie z kontraktem po integracji hooka.

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. W obecnym PoC mDNS publishing nie jest jeszcze stabilnie aktywowany jako `signal_present` na scenariuszu testowym (stan `not_integrated`).
  2. Pairing PASS na realnym firmware nadal wymaga pelnej integracji commissioning stacku i discovery.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 03 + Agent 09:
  1. Podlaczyc state `network_advertising` do realnych eventow commissioning/transport.
  2. Uzyskac `discovery_precheck_status=found` na realnym firmware C6.
  3. Domknac pairing PASS bez urzadzenia wirtualnego.
