# Faza 0 - Krok 10: Placeholder konfiguracji commissioning

## Cel

Dodac minimalny kontrakt commissioning na poziomie PoC:
1. konfiguracja `passcode` i `discriminator` dla `Node`,
2. odczyt konfiguracji z API Python i core,
3. walidacja zakresow argumentow.

## Co zostalo dodane

1. Rozszerzenie core API:
   - `umatter_core_set_commissioning(handle, discriminator, passcode)`
   - `umatter_core_get_commissioning(handle, *discriminator, *passcode)`
2. Rozszerzenie `_umatter_core`:
   - `set_commissioning(handle, discriminator, passcode)`
   - `get_commissioning(handle)` -> `(discriminator, passcode)`
3. Rozszerzenie `umatter.Node`:
   - `set_commissioning(passcode=..., discriminator=...)`
   - `commissioning()` -> `(discriminator, passcode)`
4. Rozszerzenie `umatter.Light(...)`:
   - nowe argumenty opcjonalne:
     - `passcode` (domyslnie `20202021`)
     - `discriminator` (domyslnie `3840`)
   - konfiguracja commissioning jest ustawiana przy tworzeniu one-linera.

## Kontrakt walidacji

1. `passcode`:
   - dozwolone `1..99999998`
   - poza zakresem -> `ValueError("invalid passcode")`
2. `discriminator`:
   - dozwolone `0..4095` (`0x0FFF`)
   - poza zakresem -> `ValueError("invalid discriminator")`

## Uruchomienie na ESP32-C6 (COM11)

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step10 `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -SkipFlash -SkipSmoke
```

Flash:

```powershell
cd artifacts/esp32c6/c6-com11-step10
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write-flash "@flash_args"
```

Smoke:

```python
import os, umatter, _umatter_core as c
print("vfs_total", os.statvfs('/')[0] * os.statvfs('/')[2])
n = umatter.Node(device_name="C10")
print(n.commissioning())  # (3840, 20202021)
n.set_commissioning(passcode=12345678, discriminator=1234)
print(n.commissioning())  # (1234, 12345678)
l = umatter.Light(name="L10", endpoint_id=3, passcode=87654321, discriminator=2345, with_level_control=False)
print(l.commissioning())  # (2345, 87654321)
h = c.create(0xFFF1, 0x9000, "core-c10")
print(c.get_commissioning(h))  # (3840, 20202021)
print(c.set_commissioning(h, 321, 23456789))
print(c.get_commissioning(h))  # (321, 23456789)
```

## Kryterium zaliczenia

1. Build/flash C6 przechodzi z custom partycja `app=0x280000`.
2. `Node.commissioning()` i `Node.set_commissioning()` dzialaja.
3. `Light(...)` przyjmuje parametry commissioning.
4. `_umatter_core` set/get commissioning dziala.
5. Bledne zakresy daja czytelne `ValueError`.

## Nastepny krok

Przygotowac pierwszy smoke commissioning-flow:
1. generator zestawu danych commissioning (manual code/passcode/discriminator),
2. skrypt hostowy z krokami i oczekiwanymi logami,
3. dokumentacja PASS/FAIL dla C6 (transport + diagnostyka).
