# Raport fazy 0 - krok 32 (host-side mDNS discovery probe)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie niezaleznego host-side mDNS probe dla `_matterc._udp.local.`.
  2. Integracja probe z `step12` i propagacja do `step19`.
  3. Walidacja runnerow commissioning bez zmian firmware.
- Decyzje:
  1. Probe uruchamiany w WSL (venv `/tmp/umatter-mdns-probe-venv`) z `zeroconf`.
  2. Probe ma charakter diagnostyczny i nie zmienia logicznej decyzji gate discovery.

## 2. Zmienione pliki

1. `scripts/host_mdns_commissionable_probe.py`
2. `scripts/phase0_step12_chiptool_gate.ps1`
3. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
4. `docs/phase-0/step-32-host-mdns-discovery-probe.md`
5. `reports/phase-0/step-32-host-mdns-discovery-probe-report.md`
6. `docs/HARDWARE_MATRIX.md`
7. `docs/README.md`
8. `CHANGELOG.md`

## 3. Wyniki walidacji

### 3.1 Step12 z host probe

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -Instance c12-20260212-step32-hostprobe-r2 -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8 -RunHostMdnsProbe true -HostMdnsProbeTimeoutSeconds 5`
- Wynik:
  1. `status=blocked_discovery_not_found`
  2. `discovery_precheck_status=not_found`
  3. `host_mdns_probe_status=not_found`
  4. `host_mdns_probe_service_count=0`
  5. `host_mdns_probe_match_count=0`

### 3.2 Step19 e2e propagacja host probe

- Polecenie:
  - `scripts/phase0_step19_commissioning_gate_e2e.ps1 -Instance c19-20260212-step32-hostprobe-e2e -SkipRuntimeDiag -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -RunHostMdnsProbe true -HostMdnsProbeTimeoutSeconds 5`
- Wynik:
  1. Runner: `PASS`
  2. `gate_status=blocked_discovery_not_found`
  3. `gate_host_mdns_probe_status=not_found`

Interpretacja:
- Oba sygnaly discovery (`chip-tool` i host probe zeroconf) sa spojne: brak widocznych wpisow commissionable po stronie kontrolera/hosta.
- Runtime firmware pozostaje gotowy (`runtime_ready=true`, `network_advertising=True`).

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Probe uruchamiany tylko w WSL moze nie odzwierciedlac zachowania Windows-native multicast.
  2. Realny discovery path nadal niedomkniety mimo pozytywnej telemetrii runtime.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 09:
  1. Dodac porownawczy probe Windows-native (zeroconf) i zestawic wyniki z WSL.
  2. Na tej podstawie domknac discovery visibility dla realnego firmware C6.
