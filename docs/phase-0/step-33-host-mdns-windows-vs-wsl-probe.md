# Faza 0 - Krok 33: porownawczy host mDNS probe (Windows vs WSL)

## Cel

Dodac porownawczy probe mDNS uruchamiany w obu srodowiskach hosta (WSL i Windows-native), aby jednoznacznie potwierdzic, czy problem discovery wynika z warstwy sieciowej/toolingu.

## Co zostalo dodane/zmienione

1. `scripts/phase0_step12_chiptool_gate.ps1`
   - nowy parametr:
     - `HostMdnsProbeMode`: `auto|wsl|windows|both` (domyslnie `wsl` dla kompatybilnosci)
   - host probe uruchamiany per-mode:
     - WSL: `Invoke-HostMdnsProbeWsl`
     - Windows: `Invoke-HostMdnsProbeWindows` (venv w `%TEMP%`)
   - agregacja wyniku do dotychczasowych pol:
     - `host_mdns_probe_status`, `host_mdns_probe_mode`, `host_mdns_probe_*`
   - nowe pola szczegolowe:
     - `host_mdns_probe_mode_requested`
     - `host_mdns_probe_wsl_*`
     - `host_mdns_probe_windows_*`
   - nowe artefakty:
     - `host_mdns_probe_wsl.log`
     - `host_mdns_probe_wsl_result.json`
     - `host_mdns_probe_windows.log`
     - `host_mdns_probe_windows_result.json`
     - `host_mdns_probe_result.json` (agregat)

2. `scripts/phase0_step19_commissioning_gate_e2e.ps1`
   - nowy parametr `HostMdnsProbeMode`
   - propagacja wszystkich nowych pol `host_mdns_probe_*` do wyniku e2e.

## Walidacja

1. Step12 z porownaniem obu srodowisk:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -Instance c12-20260212-step33-hostprobe-both-r2 `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -RunHostMdnsProbe true `
  -HostMdnsProbeMode both `
  -HostMdnsProbeTimeoutSeconds 5
```

Wynik:
1. `host_mdns_probe_mode=wsl+windows`
2. `host_mdns_probe_wsl_status=not_found`
3. `host_mdns_probe_windows_status=not_found`
4. `host_mdns_probe_wsl_service_count=0`
5. `host_mdns_probe_windows_service_count=0`

2. Step19 e2e (propagacja):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step19_commissioning_gate_e2e.ps1 `
  -Instance c19-20260212-step33-hostprobe-both-e2e `
  -SkipRuntimeDiag `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -RunHostMdnsProbe true `
  -HostMdnsProbeMode both `
  -HostMdnsProbeTimeoutSeconds 5
```

Wynik:
1. `gate_host_mdns_probe_mode=wsl+windows`
2. `gate_host_mdns_probe_wsl_status=not_found`
3. `gate_host_mdns_probe_windows_status=not_found`

## Kryterium zaliczenia

1. Ten sam gate run raportuje wyniki discovery z WSL i Windows-native.
2. Brak regresji w statusach `step12`/`step19`.
3. Artefakty probe sa rozdzielone per-mode i zawieraja JSON do automatycznej analizy.

## Nastepny krok

1. Dodac probe na interfejsie sieciowym hosta (np. filtrowanie adaptera), aby potwierdzic czy multicast mDNS nie jest blokowany per NIC.
2. Rozszerzyc diagnostyke runtime o licznik ponawiania publikacji mDNS i timestamp ostatniej publikacji.
