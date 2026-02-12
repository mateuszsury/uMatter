# Raport fazy 0 - krok 31 (chip-tool WSL auto-detect)

Data: 2026-02-12

## 1. Zakres i decyzje

- Zakres:
  1. Dodanie auto-detekcji `chip-tool` do `step12`.
  2. Walidacja gate bez jawnego `-ChipToolWslPath`.
- Decyzje:
  1. Zastosowano lekki probing przez `wsl.exe` zamiast wieloliniowego skryptu `bash -lc`.
  2. Utrzymano priorytet parametrow jawnych (`ChipToolWslPath`, `ChipToolPath`) nad auto-detekcja.

## 2. Zmienione pliki

1. `scripts/phase0_step12_chiptool_gate.ps1`
2. `docs/phase-0/step-31-chiptool-wsl-auto-detect.md`
3. `reports/phase-0/step-31-chiptool-wsl-auto-detect-report.md`
4. `docs/README.md`
5. `docs/HARDWARE_MATRIX.md`
6. `CHANGELOG.md`

## 3. Wyniki walidacji

### 3.1 Step12 bez jawnej sciezki chip-tool

- Polecenie:
  - `scripts/phase0_step12_chiptool_gate.ps1 -Instance c12-20260212-step31-autochip-r2 -RunPairing -RequireNetworkAdvertisingForPairing true -RequireDiscoveryFoundForPairing true -RunDiscoveryPrecheck true -DiscoveryTimeoutSeconds 8`
- Wynik:
  1. `status=blocked_discovery_not_found`
  2. `chip_tool_path=/home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool`
  3. `chip_tool_mode=wsl`
  4. `discovery_precheck_status=not_found`

Interpretacja:
- Auto-detekcja dziala poprawnie i usuwa falszywy stan `unavailable_tool`.
- Realny blocker pozostaje bez zmian: discovery wpisu commissionable dla firmware nadal `not_found`.

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. Auto-detekcja zaklada standardowe lokalizacje builda `chip-tool` w HOME.
  2. Discovery realnego firmware pozostaje niedomkniete.

## 5. Nastepny krok dla kolejnego agenta

- Agent 07 + Agent 09:
  1. Dodac dodatkowy host-side probe mDNS (niezalezny od chip-tool) do szybszej diagnostyki `not_found`.
  2. Domknac discovery visibility dla realnego firmware.
