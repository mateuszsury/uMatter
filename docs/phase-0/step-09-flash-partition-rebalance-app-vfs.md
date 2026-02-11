# Faza 0 - Krok 09: Rebalans partycji flash (wieksza `app`, zachowany VFS)

## Cel

Zwikszyc margines dla firmware bez utraty systemu plikow MicroPython:
1. powiekszyc partycje `factory app`,
2. utrzymac automatyczny VFS po stronie MicroPython,
3. zachowac bezpieczny workflow dla rownoleglych buildow.

## Analiza rozmiaru flash

Stan przed zmiana (`partitions-4MiBplus.csv`):
1. `factory app = 0x1F0000` (1984 KiB),
2. ostatni build (`step08`) mial tylko ok. `2.17%` wolnego w `app`,
3. VFS byl tworzony automatycznie z pozostalej przestrzeni flash.

Trend binarki C6:
1. `step05`: `1942176` B
2. `step06`: `1961280` B
3. `step07`: `1981072` B
4. `step08`: `1987488` B

## Co zostalo zmienione

1. Dodano custom partition CSV:
   - `scripts/partitions/partitions-4MiBplus-app2560k.csv`
   - `factory app = 0x280000` (2560 KiB)
2. Dodano przekazywanie custom CSV do build script:
   - `scripts/wsl_build_micropython_c5.sh` (`--partition-csv`)
   - `scripts/phase0_step02_c5_e2e.ps1` (`-PartitionCsv`)
3. Zmiana jest per build-instance:
   - modyfikuje tylko worktree danej instancji,
   - nie koliduje z innymi rownoleglymi buildami.

## Uruchomienie na ESP32-C6 (COM11)

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step09 `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -PartitionCsv scripts/partitions/partitions-4MiBplus-app2560k.csv `
  -SkipFlash -SkipSmoke
```

Flash:

```powershell
cd artifacts/esp32c6/c6-com11-step09
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write-flash "@flash_args"
```

Smoke (VFS + API):

```python
import os, umatter, esp32
print("vfs_total", os.statvfs('/')[0] * os.statvfs('/')[2])
print("data_parts", len(esp32.Partition.find(esp32.Partition.TYPE_DATA)))
l = umatter.Light(name="L09")
print("endpoint_count", l.endpoint_count())
l.start(); print("started", l.is_started()); l.stop(); l.close()
```

## Kryterium zaliczenia

1. Partycja `factory` ma `0x280000`.
2. Build C6 przechodzi i raportuje znacznie wiekszy zapas `app`.
3. VFS jest obecny po starcie (`/` montuje sie poprawnie).
4. API `umatter` dziala po zmianie partycji.

## Nastepny krok

Dodac minimalny placeholder commissioning:
1. konfiguracja `passcode` i `discriminator` na `Node`,
2. ekspozycja w `umatter` i `_umatter_core`,
3. smoke walidacji zakresow i odczytu konfiguracji.
