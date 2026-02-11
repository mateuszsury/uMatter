# Faza 0 - Krok 03: Native stub `umatter` jako USER_C_MODULES

## Cel

Zweryfikowac granice runtime C dla uMatter:
1. Modul natywny kompiluje sie razem z MicroPython.
2. Modul jest importowalny na docelowym ESP32-C5.

## Co zostalo dodane

1. `modules/umatter/micropython.cmake`
2. `modules/umatter/micropython.mk`
3. `modules/umatter/include/umatter_config.h`
4. `modules/umatter/src/mod_umatter.c`

Publiczny kontrakt stubu:
1. `import umatter`
2. `umatter.__version__` -> `"stub"`
3. `umatter.is_stub()` -> `True`

## Uruchomienie na C5 (COM14)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM14 `
  -BuildInstance c5-com14-umatter1 `
  -UserCModulesPath modules/umatter `
  -SmokeExpr "import sys,os,umatter; print(sys.implementation); print(os.uname()); print('umatter', umatter.__version__, umatter.is_stub())"
```

## Kryterium zaliczenia

1. Build przechodzi z `Found User C Module(s): usermod_umatter`.
2. Flash przechodzi na `COM14`.
3. Smoke zwraca `umatter stub True`.

## Nastepny krok

Rozszerzyc stub o pierwszy kontrakt API rdzenia:
1. `umatter.Node(...)` w Pythonie
2. natywny backend `_umatter_core` z placeholderami lifecycle (`create/start/stop`) i mapowaniem bledow.
