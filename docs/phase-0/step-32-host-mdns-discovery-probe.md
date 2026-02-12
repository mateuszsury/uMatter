# Faza 0 - Krok 32: host-side mDNS discovery probe

## Cel

Dodac niezalezny probe mDNS po stronie hosta do diagnostyki discovery, aby oddzielic problem narzedzia `chip-tool` od realnej widocznosci advertisement `_matterc._udp.local.`.

## Co zostalo dodane/zmienione

1. `scripts/host_mdns_commissionable_probe.py`
   - nowy skrypt Python (zeroconf) do skanowania `_matterc._udp.local.`
   - raportuje:
     - `service_count`
     - `match_count` (po TXT `D=<discriminator>`)
     - `entries` z TXT/adresami
   - zwraca status: `found` / `not_found` / `unavailable_dependency`.

2. `scripts/phase0_step12_chiptool_gate.ps1`
   - nowe parametry:
     - `RunHostMdnsProbe` (domyslnie `true`)
     - `HostMdnsProbeTimeoutSeconds` (domyslnie `6`)
   - automatyczne uruchomienie host probe (WSL venv + `zeroconf`) w gate flow.
   - nowe pola wyniku:
     - `host_mdns_probe_*`
     - `run_host_mdns_probe`
     - `host_mdns_probe_timeout_seconds`.

3. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
   - propagacja nowych parametrow i pol `host_mdns_probe_*` do raportu e2e.

## Walidacja

1. Step12 (host probe wlaczony):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -Instance c12-20260212-step32-hostprobe-r2 `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 8 `
  -RunHostMdnsProbe true `
  -HostMdnsProbeTimeoutSeconds 5
```

Wynik:
1. `status=blocked_discovery_not_found`
2. `discovery_precheck_status=not_found`
3. `host_mdns_probe_status=not_found`
4. `host_mdns_probe_service_count=0`

2. Step19 e2e (propagacja):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -Instance c19-20260212-step32-hostprobe-e2e `
  -SkipRuntimeDiag `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -RunHostMdnsProbe true `
  -HostMdnsProbeTimeoutSeconds 5
```

Wynik:
1. `Commissioning gate e2e: PASS` (runner)
2. `gate_status=blocked_discovery_not_found`
3. `gate_host_mdns_probe_status=not_found`

## Kryterium zaliczenia

1. Gate daje dodatkowy, niezalezny sygnal diagnostyczny `host_mdns_probe_*`.
2. Brak regresji dotychczasowych statusow `step12` i `step19`.
3. Artefakty probe sa zapisywane deterministycznie (`host_mdns_probe.log`, `host_mdns_probe_result.json`).

## Nastepny krok

1. Dodac probe w trybie Windows-native (bez WSL), aby porownac widocznosc multicast mDNS miedzy hostem Windows i WSL.
2. Na podstawie porownania zamknac realny discovery path dla firmware na C6.
