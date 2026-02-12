# Hardware Matrix (Current)

## Validated Targets

| Target | Board | Transport focus | Status |
|---|---|---|---|
| ESP32-C5 | `ESP32_GENERIC_C5` | Wi-Fi + Thread (planned runtime expansion) | Build/flash validated in Phase 0 |
| ESP32-C6 | `ESP32_GENERIC_C6` | Wi-Fi + Thread | Build/flash/smoke validated on COM11 |

## Notes

- Device-level commissioning diagnostics expose runtime state and ready reason (`runtime`, `ready_reason`, `ready_reason_code`) and are consumed by chip-tool gate.
- Device-level diagnostics expose `network_advertising` and `network_advertising_reason` with runtime contract:
  - integrated path: `True/signal_present`
  - fallback path: `False/not_integrated`
- Device-level diagnostics additionally expose mDNS internals for advertising debug:
  - `network_advertising_mdns_published`
  - `network_advertising_mdns_last_error`
  - `network_advertising_manual_override`
- Runtime mDNS publication now adds commissionable subtypes `_L<discriminator>` and `_S<discriminator_low4>` on ESP path.
- Latest ESP32-C6 run on `COM11` reports integrated advertising path (`True/signal_present`, `mdns_published=True`), while controller discovery is still `not_found`.
- Controller-side gate supports `chip-tool` discovery precheck (`discover find-commissionable-by-long-discriminator`) before pairing.
- Controller-side gate now auto-detects WSL `chip-tool` from common locations, so missing PATH no longer forces `unavailable_tool`.
- Controller-side gate now also records host-side mDNS probe diagnostics (`host_mdns_probe_*`) to separate discovery visibility from tooling issues.
- Host-side mDNS probe supports comparative mode (`HostMdnsProbeMode=both`) and records separate WSL/Windows findings in one gate run.
- Full commissioning e2e (`chip-tool` pairing pass) is tracked as next-phase runtime task.

## Planned Expansion

- Broader board/profile matrix with memory profiles.
- Interoperability matrix and soak outcomes in `reports/`.
