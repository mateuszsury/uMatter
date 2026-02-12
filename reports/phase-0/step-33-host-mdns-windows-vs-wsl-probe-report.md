# Raport fazy 0 - krok 33 (host mDNS probe: Windows vs WSL)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Rozszerzenie host probe o tryb porownawczy WSL + Windows-native.
  2. Agregacja wynikow probe do jednego kontraktu `host_mdns_probe_*`.
  3. Propagacja szczegolowych pol probe do `step19` e2e.
- Decyzje:
  1. Domyslny tryb pozostaje `wsl` dla kompatybilnosci istniejacych runow.
  2. Tryb `both` uruchamia dwa niezalezne probe i zapisuje osobne artefakty.

## 2. Zmienione pliki

1. `scripts/phase0_step12_chiptool_gate.ps1`
2. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
3. `docs/phase-0/step-33-host-mdns-windows-vs-wsl-probe.md`
4. `reports/phase-0/step-33-host-mdns-windows-vs-wsl-probe-report.md`
5. `docs/HARDWARE_MATRIX.md`
6. `docs/README.md`
7. `CHANGELOG.md`

## 3. Wyniki walidacji

### 3.1 Step12 (HostMdnsProbeMode=both)

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -Instance c12-20260212-step33-hostprobe-both-r2 -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -RunHostMdnsProbe true -HostMdnsProbeMode both -HostMdnsProbeTimeoutSeconds 5`
- Wynik:
  1. `status=blocked_discovery_not_found`
  2. `host_mdns_probe_mode=wsl+windows`
  3. `host_mdns_probe_wsl_status=not_found`
  4. `host_mdns_probe_windows_status=not_found`
  5. `host_mdns_probe_wsl_service_count=0`
  6. `host_mdns_probe_windows_service_count=0`

### 3.2 Step19 e2e propagacja

- Polecenie:
  - `scripts/phase0_step19_commissioning_gate_e2e.ps1 -Instance c19-20260212-step33-hostprobe-both-e2e -SkipRuntimeDiag -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -RunHostMdnsProbe true -HostMdnsProbeMode both -HostMdnsProbeTimeoutSeconds 5`
- Wynik:
  1. Runner: `PASS`
  2. `gate_status=blocked_discovery_not_found`
  3. `gate_host_mdns_probe_mode=wsl+windows`
  4. `gate_host_mdns_probe_wsl_status=not_found`
  5. `gate_host_mdns_probe_windows_status=not_found`

Interpretacja:
- Discovery jest negatywny i spojny w obu srodowiskach hosta.
- Problem nie wynika wyłącznie z WSL toolingu; brak widocznosci commissionable dotyczy takze probe Windows-native.

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Probe nie filtruje konkretnego interfejsu NIC, wiec moze nie wykryc sytuacji per-adapter.
  2. Discovery realnego firmware pozostaje niedomkniete (`not_found`) mimo runtime-ready i network advertising telemetry.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 09:
  1. Dodac diagnostyke per-interfejs hosta (NIC-aware) dla mDNS.
  2. Rozszerzyc runtime o timestamp i licznik ponowien publikacji mDNS, aby powiazac sygnaly host/controller z firmware.
