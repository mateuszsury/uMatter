# Faza 0 - Krok 13: Commissioning code API + smoke na C6

## Cel

Dolozyc jawny kontrakt diagnostyczny commissioning dla PoC:
1. `manual_code` z danych commissioning,
2. `qr_code` z danych commissioning,
3. walidacja tej samej semantyki na `Node`, `Light` i `_umatter_core`.

## Co zostalo dodane

1. Rozszerzenie core API:
   - `umatter_core_get_manual_code(handle, out, out_size)`
   - `umatter_core_get_qr_code(handle, out, out_size)`
2. Rozszerzenie `_umatter_core`:
   - `get_manual_code(handle)` -> `str`
   - `get_qr_code(handle)` -> `str`
3. Rozszerzenie `umatter.Node`:
   - `manual_code()` -> `str`
   - `qr_code()` -> `str`
4. Nowy host smoke:
   - `scripts/phase0_step13_commissioning_codes_smoke.ps1`
   - waliduje markery commissioning code po serialu na `COM11`.

## Kontrakt placeholder (krok 13)

1. `manual_code`:
   - format: `DDDPPPPPPPP` (11 cyfr)
   - `DDD = discriminator & 0x000F` jako 3 cyfry z zerami wiodacymi
   - `PPPPPPPP = passcode` jako 8 cyfr
2. `qr_code`:
   - format: `MT:UM<VENDOR_HEX4><PRODUCT_HEX4><DISC_DEC4><PASS_DEC8>`
   - przyklad: `MT:UMFFF18000123424681357`
3. To jest kontrakt PoC do diagnostyki hostowej, nie finalny format Matter payload.

## Uruchomienie na ESP32-C6 (COM11)

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step13 `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -SkipFlash -SkipSmoke
```

Flash:

```powershell
cd artifacts/esp32c6/c6-com11-step13
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write_flash "@flash_args"
```

Smoke:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step13_commissioning_codes_smoke.ps1 `
  -ComPort COM11 `
  -DeviceName uMatter-C13 `
  -EndpointId 7 `
  -Passcode 24681357 `
  -Discriminator 1234 `
  -Instance c13-com11-step13b
```

## Kryterium zaliczenia

1. Build i flash C6 przechodza na aktualnej partycji app `0x280000`.
2. `Node.manual_code()` i `Node.qr_code()` zwracaja stabilny wynik.
3. `Light.manual_code()` i `Light.qr_code()` sa spójne z commissioning config.
4. `_umatter_core.get_manual_code/get_qr_code` zwracaja identyczna semantyke.
5. Host smoke konczy sie `HOST_C13_PASS`.

## Nastepny krok

1. Spiac krok 13 z krokiem 12:
   - rozszerzyc `chiptool_gate` o automatyczne dolaczanie `manual_code`/`qr_code` do raportu matrix.
2. Po dostarczeniu `chip-tool` wykonac `-RunPairing` i zarejestrowac wynik e2e commissioning.
