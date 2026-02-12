# Raport fazy 0 - krok 28 (rozszerzona diagnostyka mDNS advertising)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Rozszerzenie runtime o szczegoly stanu mDNS dla `network_advertising`.
  2. Ekspozycja nowych pol diagnostycznych w API Node i `_umatter_core`.
  3. Aktualizacja walidacji step16 o markery mDNS/manual override.
- Decyzje:
  1. Trzymac diagnostyke jako liczby i bool (bez parsowania tekstowego bledow IDF).
  2. Dla path manualnego ustawiac `manual_override=True` i `mdns_published=False`.
  3. Nie luzowac gate network: brak potwierdzonego advertising nadal blokuje pairing.

## 2. Zmienione pliki

1. `modules/umatter/include/umatter_core.h`
2. `modules/umatter/src/umatter_core_runtime.c`
3. `modules/umatter/src/mod_umatter.c`
4. `modules/umatter/src/mod_umatter_core.c`
5. `scripts/phase0_step16_commissioning_runtime_diag.ps1`
6. `docs/HARDWARE_MATRIX.md`
7. `docs/phase-0/step-28-network-advertising-mdns-diagnostics.md`
8. `reports/phase-0/step-28-network-advertising-mdns-diagnostics-report.md`

## 3. Wyniki walidacji

### 3.1 Build + flash C6 (COM11)

- Polecenie:
  - `scripts/phase0_step02_c5_e2e.ps1 -ComPort COM11 -IdfRootWsl /home/thete/esp-idf-5.5.1 -Board ESP32_GENERIC_C6 -BuildInstance c6-com11-step28-mdnsdiag -UserCModulesPath modules/umatter -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv -ArtifactsRoot artifacts/esp32c6`
- Wynik:
  1. Build: `PASS`
  2. Flash: `PASS`
  3. App size: `2034112`
  4. Free in app partition (2560 KiB): `587328`

### 3.2 Step16 runtime diagnostics - default

- Polecenie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step28-mdnsdiag-r2`
- Wynik:
  1. `PASS`
  2. Kluczowe markery:
     - `C16:N_DIAG_NET_ADV False`
     - `C16:N_DIAG_NET_REASON not_integrated`
     - `C16:N_DIAG_NET_MDNS_PUB False`
     - `C16:N_DIAG_NET_MDNS_ERR -2`
     - `C16:N_DIAG_NET_MANUAL False`
     - `C16:C_NET1D (False, 2, False, -2, False)`

### 3.3 Step16 runtime diagnostics - symulacja

- Polecenie:
  - `scripts/phase0_step16_commissioning_runtime_diag.ps1 -ComPort COM11 -Instance c16-com11-step28-mdnsdiag-sim -SimulateNetworkAdvertising`
- Wynik:
  1. `PASS`
  2. Kluczowe markery:
     - `C16:N_DIAG_NET_ADV True`
     - `C16:N_DIAG_NET_REASON signal_present`
     - `C16:N_DIAG_NET_MDNS_PUB False`
     - `C16:N_DIAG_NET_MDNS_ERR 0`
     - `C16:N_DIAG_NET_MANUAL True`
     - `C16:C_NET2D (True, 3, False, 0, True)`

### 3.4 Step12 network gate

- Default log:
  - `status=blocked_network_not_advertising`
  - `network_advertising=False`
  - `network_advertising_reason=not_integrated`
- Sim log:
  - `network_gate_blocked=false`
  - `network_advertising=True`
  - `network_advertising_reason=signal_present`
  - finalnie `status=fail_pairing` (timeout mDNS resolution), bez blokady network gate.

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Domyslny path na C6 nadal zwraca fallback (`not_integrated`, `mdns_last_error=-2`), wiec discovery/pairing nie jest domkniety.
  2. PASS pairing pozostaje na sciezce wirtualnego urzadzenia (krok 26), nie na realnym runtime.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 03:
  1. Podlaczyc mDNS publish do realnego stanu commissioning stacku (transport/netif lifecycle).
  2. Uzyskac `mdns_published=True` w default runtime diag bez symulacji.
  3. Odtworzyc `discover=found` i pairing PASS na realnym firmware C6.
