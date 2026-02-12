# Faza 0 - Krok 30: runtime mDNS commissionable subtypes

## Cel

Dodac do runtime publikacje subtypes dla commissionable mDNS (`_L...`, `_S...`), aby firmware emitowal komplet sygnalow discovery zgodnych z praktyka `chip-tool`.

## Co zostalo dodane/zmienione

1. `modules/umatter/src/umatter_core_runtime.c`
   - po `mdns_service_add(... "_matterc" "_udp" ...)` dodane:
     - `mdns_service_subtype_add_for_host(..., "_L%04u")`
     - `mdns_service_subtype_add_for_host(..., "_S%u")`
   - na bledzie dodania subtype:
     - `mdns_service_remove("_matterc", "_udp")`
     - propagacja `mdns_error_out`.

## Walidacja

1. Build-only C6:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -IdfRootWsl /home/thete/esp-idf-5.5.1 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step30c-buildonly `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -ArtifactsRoot artifacts/esp32c6 `
  -SkipFlash -SkipSmoke
```

Wynik:
1. `PASS`
2. `micropython.bin` size: `2036624`
3. free in app partition (2560 KiB): `584816`

2. Runtime diagnostics C6/COM11:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step16_commissioning_runtime_diag.ps1 `
  -Port COM11 `
  -Instance c16-20260212-141341
```

Wynik:
1. `PASS`
2. `network_advertising=True`
3. `network_advertising_reason=signal_present`
4. `network_advertising_mdns_published=True`
5. `network_advertising_mdns_last_error=0`

3. Gate discovery z chip-tool (WSL path jawnie podany):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step12_chiptool_gate.ps1 `
  -Instance c12-20260212-step30chiptool `
  -ChipToolWslPath /home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool `
  -RunPairing `
  -RequireNetworkAdvertisingForPairing true `
  -RequireDiscoveryFoundForPairing true `
  -RunDiscoveryPrecheck true `
  -DiscoveryTimeoutSeconds 12
```

Wynik:
1. `status=blocked_discovery_not_found`
2. `discovery_precheck_status=not_found`
3. `discovery_precheck_fallback_used=true`
4. `network_gate_blocked=false`

## Kryterium zaliczenia

1. Runtime publikuje mDNS bez bledu (`mdns_last_error=0`).
2. Firmware emituje subtypes `_L/_S` w tej samej transakcji publikacji service.
3. Brak regresji w runtime-ready/network gate.

## Nastepny krok

1. Domknac controller-side discovery visibility dla realnego firmware (bez mock gateway).
2. Dodac automatyczne wykrywanie lokalizacji `chip-tool`, aby uniknac `unavailable_tool`.
