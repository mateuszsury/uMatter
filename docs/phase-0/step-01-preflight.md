# Faza 0 - Krok 01: Preflight srodowiska build

## Cel

Pierwszy maly krok wdrozenia z `plan.md` (Faza 0) to zamkniecie punktu:
- "Konfiguracja srodowiska budowania (MicroPython + ESP-IDF + esp-matter)".

Ten krok daje szybki sygnal pass/fail, zanim zaczniemy integracje CMake.

## Co zostalo dodane

- Skrypt: `scripts/phase0_preflight.ps1`
- Wrapper build (WSL): `scripts/wsl_idf_build.sh`
- Zakres sprawdzen:
1. Host (Windows PowerShell): `git`, `python`, `wsl`, `esptool`, `mpremote`
2. WSL (Linux): `cmake`, `ninja`, `make`, wykrycie i test wybranego `ESP-IDF`
3. Rekomendacja wydajnosciowa: `ccache` (status `WARN`, nie blokuje)
4. Polityka rownoleglego builda: `UMATTER_BUILD_INSTANCE` (status `WARN`, jesli brak)

## Uruchomienie

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_preflight.ps1
```

Wymuszenie konkretnej instancji ESP-IDF (zalecane przy wielu buildach rownoleglych):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_preflight.ps1 -WslIdfRoot <idf_root_w_wsl>
```

Opcjonalnie bez sprawdzen WSL:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_preflight.ps1 -SkipWsl
```

## Kryterium zaliczenia

- Kod wyjscia `0`
- Brak statusow `FAIL`

Status `WARN` oznacza zalecenie (np. brak `ccache`), ale nie blokuje kolejnego kroku.

## Rownolegle instancje builda (wazne)

Przy wielu procesach budowania nie polegaj na jednym globalnym katalogu build.

Zasady:
1. Ustawiaj jawny root ESP-IDF per instancja (`-WslIdfRoot` lub `UMATTER_WSL_IDF_ROOT`).
2. Uzywaj izolowanego build dir per instancja (`idf.py -B`).
3. Oznacz proces unikalnym `UMATTER_BUILD_INSTANCE`.

Do tego sluzi wrapper:

```bash
UMATTER_WSL_IDF_ROOT="<idf_root_w_wsl>" UMATTER_BUILD_INSTANCE="agent-a" \
  ./scripts/wsl_idf_build.sh <project_dir> build
```

## Nastepny krok po zaliczeniu

Uruchomic Agent 02 (`agents/02-cmake-integration.md`) i wdrozyc minimalna integracje CMake dla targetu PoC (ESP32-S3).
