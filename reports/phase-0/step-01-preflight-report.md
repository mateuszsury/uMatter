# Raport fazy 0 - krok 01 (preflight)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres: wdrozenie pierwszego malego kroku z Fazy 0 z `plan.md`:
  - konfiguracja srodowiska budowania (MicroPython + ESP-IDF + esp-matter)
- Decyzja: preflight zostaje rozszerzony o tryb wieloinstancyjny ESP-IDF:
  1. wybor konkretnego roota IDF (`-WslIdfRoot` / `UMATTER_WSL_IDF_ROOT`)
  2. izolowany katalog build per instancja (`idf.py -B`)
  3. identyfikator procesu (`UMATTER_BUILD_INSTANCE`)

## 2. Zmienione pliki

1. `scripts/phase0_preflight.ps1` - skrypt walidacji srodowiska.
2. `scripts/wsl_idf_build.sh` - wrapper WSL z wymuszonym `-B` (build isolation).
3. `docs/phase-0/step-01-preflight.md` - instrukcja operacyjna kroku.
4. `reports/phase-0/step-01-preflight-report.md` - ten raport.

## 3. Wyniki walidacji

Uruchomienie:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_preflight.ps1
```

Wynik:
- `PASS=14`
- `WARN=2`
- `FAIL=0`
- Exit code: `0`

Wykonane naprawy:
1. Doinstalowano host tools:
   - `esptool==5.1.0`
   - `mpremote==1.27.0`
2. Preflight wybiera tylko uzywalny root ESP-IDF (test `source export.sh && idf.py --version`).

Szczegoly WARN:
1. `ccache --version (recommended)`:
   - `ccache` nie jest zainstalowany w WSL.
2. `UMATTER_BUILD_INSTANCE`:
   - brak ustawienia; zalecane ustawianie per proces przy buildach rownoleglych.

Walidacja trybu deterministycznego (jawny root + instancja):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_preflight.ps1 -WslIdfRoot /home/thete/esp-idf -BuildInstance agent-a
```

Wynik:
- `PASS=15`
- `WARN=1` (tylko `ccache`)
- `FAIL=0`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyko wydajnosciowe:
  1. Brak `ccache` wydluzy czasy pelnych buildow.
- Ryzyko operacyjne (wieloinstancyjnosc):
  1. Bez `-B` i unikalnego `UMATTER_BUILD_INSTANCE` mozliwe kolizje w katalogu build.

## 5. Nastepny krok dla kolejnego agenta

- Agent 02 (`agents/02-cmake-integration.md`):
  1. Zaczac minimalna integracje CMake PoC dla ESP32-S3.
  2. Do uruchomien rownoleglych stosowac `scripts/wsl_idf_build.sh` i unikalny `UMATTER_BUILD_INSTANCE`.
