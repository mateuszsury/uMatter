# Faza 0 - Krok 02: Pierwszy firmware na ESP32-C5 (COM14)

## Cel

Uruchomic end-to-end build i flash bazowego firmware MicroPython dla docelowej plytki:
- board: `ESP32_GENERIC_C5`
- port: `COM14`

Ten krok zamyka praktyczna walidacje "build + flash + smoke" pod docelowy hardware.

## Co zostalo dodane

1. `scripts/wsl_build_micropython_c5.sh`
2. `scripts/phase0_step02_c5_e2e.ps1`

## Dlaczego to jest bezpieczne przy wielu instancjach

1. Kazda instancja ma osobny worktree (`instances/<instance>/micropython`).
2. Kazda instancja buduje do osobnego katalogu `build-<board>-<instance>`.
3. Artefakty sa zapisywane do osobnego katalogu `artifacts/esp32c5/<instance>`.

Dzieki temu rownolegle buildy nie nadpisuja sobie:
- checkoutow Git
- katalogow build
- `flash_args` i binarek

## Uruchomienie

Pelny krok (build + flash + smoke):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM14
```

Jawna instancja i tag:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM14 -BuildInstance c5-agent-a -MicropythonTag v1.27.0
```

Build z `USER_C_MODULES`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM14 -BuildInstance c5-agent-a -UserCModulesPath modules/umatter
```

Tylko flash + smoke z gotowych artefaktow:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM14 -BuildInstance <instance> -SkipBuild
```

Wlasny smoke expr:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM14 -SmokeExpr "import sys,os; print(sys.implementation); print(os.uname())"
```

## Kryterium zaliczenia

1. Build konczy sie bez bledu.
2. Flash konczy sie bez bledu.
3. `mpremote` zwraca:
   - `sys.implementation` z `version=(1, 27, 0, '')`
   - `_build='ESP32_GENERIC_C5'`

## Nastepny krok

Przejsc do minimalnego PoC integracji `umatter` jako `USER_C_MODULES` w tym samym pipeline C5.
