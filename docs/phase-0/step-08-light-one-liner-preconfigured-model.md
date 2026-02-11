# Faza 0 - Krok 08: `umatter.Light(...)` z prekonfigurowanym modelem

## Cel

Rozszerzyc prosty one-liner API tak, aby `umatter.Light(...)` tworzyl od razu gotowy model danych:
1. automatyczny endpoint dla `On/Off Light`,
2. automatyczne klastry bazowe,
3. zachowanie kompatybilnosci (`Light` nadal zwraca `Node`).

## Co zostalo dodane

1. `umatter.Light(...)` tworzy teraz:
   - endpoint (domyslnie `endpoint_id=1`),
   - klaster `OnOff`,
   - opcjonalnie klaster `LevelControl`.
2. Nowe opcjonalne argumenty `Light(...)`:
   - `endpoint_id` (domyslnie `1`),
   - `with_level_control` (domyslnie `True`).
3. Zachowana kompatybilnosc:
   - zwracany typ: `Node`,
   - dalej dzialaja metody `start/stop/close/is_started`.
4. Zachowane kontrakty bledow:
   - duplikat endpointu: `ValueError("endpoint_id already exists")`.

## Uruchomienie na ESP32-C6 (COM11)

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step08 `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -SkipFlash -SkipSmoke
```

Flash:

```powershell
cd artifacts/esp32c6/c6-com11-step08
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write-flash "@flash_args"
```

Smoke (REPL):

```python
import umatter
l = umatter.Light(name="L08-A")
print("type", type(l))
print("endpoint_count", l.endpoint_count())  # 1
try:
    l.add_endpoint(endpoint_id=1, device_type=umatter.DEVICE_TYPE_ON_OFF_LIGHT)
except Exception as e:
    print(type(e).__name__, str(e))  # ValueError endpoint_id already exists
ep2 = l.add_endpoint(endpoint_id=2, device_type=umatter.DEVICE_TYPE_ON_OFF_LIGHT)
ep2.add_cluster(umatter.CLUSTER_ON_OFF)
print("endpoint_count2", l.endpoint_count())  # 2
print("ep2_cluster_count", ep2.cluster_count())  # 1
print("started0", l.is_started())
l.start(); print("started1", l.is_started())
l.stop(); print("started2", l.is_started())
l.close()

l2 = umatter.Light(name="L08-B", endpoint_id=7, with_level_control=False)
print("endpoint_count_l2", l2.endpoint_count())  # 1
l2.close()
```

## Kryterium zaliczenia

1. Build C6 przechodzi z `USER_C_MODULES=modules/umatter`.
2. Flash na `COM11` przechodzi.
3. Smoke potwierdza:
   - `type <class 'Node'>`,
   - `endpoint_count == 1` po `Light(...)`,
   - duplikat `endpoint_id=1` daje `ValueError endpoint_id already exists`,
   - lifecycle: `False -> True -> False`,
   - wariant `with_level_control=False` dziala.

## Nastepny krok

Przygotowac pierwszy krok pod commissioning (Thread/WiFi):
1. minimalna konfiguracja commissioning flow dla C6,
2. diagnostyka stanu uruchomienia i bledow transportu,
3. smoke startu node z gotowym modelem `Light`.
