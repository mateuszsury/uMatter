# Hardware Matrix (Current)

## Validated Targets

| Target | Board | Transport focus | Status |
|---|---|---|---|
| ESP32-C5 | `ESP32_GENERIC_C5` | Wi-Fi + Thread (planned runtime expansion) | Build/flash validated in Phase 0 |
| ESP32-C6 | `ESP32_GENERIC_C6` | Wi-Fi + Thread | Build/flash/smoke validated on COM11 |

## Notes

- Device-level commissioning diagnostics currently rely on placeholder runtime markers for some fields.
- Full commissioning e2e (`chip-tool` pairing pass) is tracked as next-phase runtime task.

## Planned Expansion

- Broader board/profile matrix with memory profiles.
- Interoperability matrix and soak outcomes in `reports/`.

