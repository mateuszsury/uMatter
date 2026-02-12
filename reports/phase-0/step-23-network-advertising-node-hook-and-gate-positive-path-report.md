# Raport fazy 0 - krok 23 (Node advertising hook + dodatnia sciezka gate)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie w API `Node` metod do ustawiania i odczytu stanu `network_advertising`.
  2. Rozszerzenie step16 o opcjonalna symulacje sygnalu advertising.
  3. Walidacja dodatniej sciezki gate network na logu symulowanym.
- Decyzje:
  1. Hook API pozostaje jawny i kontrolowany (`set_network_advertising`), z walidacja reason string.
  2. Step16 domyslnie zachowuje stare zachowanie, a symulacja wlaczana jest explicite (`-SimulateNetworkAdvertising`).
  3. Dodatnia sciezka gate jest uznana za zaliczona, gdy status nie jest `blocked_network_not_advertising`.

## 2. Zmienione pliki

1. `modules/umatter/src/mod_umatter.c`
2. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
3. `docs/phase-0/step-23-network-advertising-node-hook-and-gate-positive-path.md`
4. `reports/phase-0/step-23-network-advertising-node-hook-and-gate-positive-path-report.md`

## 3. Wyniki walidacji

### 3.1 Build + flash C6

- Build-only:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step23-buildonly -ArtifactsRoot artifacts/esp32c6 -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -SkipFlash -SkipSmoke`
  - Wynik: `PASS`
  - Rozmiar app: `2033040`
  - Wolne w partycji app: `588400`
- Flash:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step23-buildonly -ArtifactsRoot artifacts/esp32c6 -SkipBuild -SkipSmoke`
  - Wynik: `PASS`

### 3.2 Step16 runtime diagnostics

- Domyslnie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step23-default -EndpointId 9 -Passcode 24681357 -Discriminator 1234`
  - Wynik: `PASS`
- Z symulacja:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step23-sim-netadv -EndpointId 9 -Passcode 24681357 -Discriminator 1234 -SimulateNetworkAdvertising`
  - Wynik: `PASS`
  - Potwierdzone markery:
    1. `C16:N_SET_NET1_ADV True`
    2. `C16:N_SET_NET1_REASON signal_present`
    3. `C16:N_DIAG_NET_ADV True`
    4. `C16:N_DIAG_NET_REASON signal_present`
    5. `C16:L_SET_NET1_ADV True`
    6. `C16:L_SET_NET1_REASON signal_present`
    7. `C16:L_DIAG_NET_ADV True`
    8. `C16:L_DIAG_NET_REASON signal_present`

### 3.3 Step12 network gate (log symulowany)

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c12-com11-step23-runpair-netadv-sim`
- Wynik:
  1. `status=fail_pairing`
  2. `status_reason=pairing timeout waiting for mDNS resolution`
  3. Network gate **nie** zablokowal pairing (`blocked_network_not_advertising` nie wystapil).

### 3.4 Step19 e2e (log symulowany)

- Polecenie:
  - `scripts/phase0_step19_commissioning_gate_e2e.ps1 -SkipRuntimeDiag -RuntimeDiagLogPath artifacts/commissioning/c16-com11-step23-sim-netadv/serial_commissioning_runtime_diag.log -CommissioningDataPath artifacts/commissioning/c11-com11-step14/commissioning_data.json -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool -RunPairing -RequireNetworkAdvertisingForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -Instance c19-com11-step23-runpair-netadv-sim`
- Wynik:
  1. `Commissioning gate e2e: PASS`
  2. `gate_status=fail_pairing`
  3. Brak blokady `blocked_network_not_advertising`.

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Dodatnia sciezka gate opiera sie aktualnie na hooku/symulacji, nie na realnym sygnale mDNS z firmware.
  2. `chip-tool pairing` nadal timeoutuje na mDNS (brak realnej reklamy commissionable end-to-end).

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 03:
  1. Podpiac update `network_advertising` do realnego eventu stacku Matter (mDNS advertisement state).
  2. Domknac pairing do `status=pass` bez symulacji.
