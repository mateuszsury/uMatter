# Faza 0 - Krok 07: Endpoint/Cluster API podlaczone do backendu core

## Cel

Zamknac pierwszy etap przejscia z placeholdera do backendu runtime:
1. dodac API endpoint/cluster po stronie `_umatter_core`,
2. podlaczyc `umatter.Node` i `umatter.Endpoint` do tego API,
3. zachowac jasne i stabilne kontrakty bledow po stronie Python.

## Co zostalo dodane

1. Rozszerzenie kontraktu core (`umatter_core.h`):
   - nowy kod bledu `UMATTER_CORE_ERR_EXISTS`,
   - nowe funkcje:
     - `umatter_core_add_endpoint(...)`,
     - `umatter_core_add_cluster(...)`,
     - `umatter_core_endpoint_count(...)`,
     - `umatter_core_cluster_count(...)`.
2. Implementacja placeholder backendu runtime:
   - tablice endpointow i klastrow per node,
   - walidacja duplikatow i limitow,
   - zwracanie spojnych kodow bledu.
3. Ekspozycja nowego API do MicroPython przez `_umatter_core`:
   - `add_endpoint`, `add_cluster`, `endpoint_count`, `cluster_count`,
   - stala `ERR_EXISTS`.
4. Podlaczenie warstwy `umatter` do backendu:
   - `Node.add_endpoint(...)` -> `_umatter_core.add_endpoint(...)`,
   - `Endpoint.add_cluster(...)` -> `_umatter_core.add_cluster(...)`,
   - `Node.endpoint_count()` i `Endpoint.cluster_count()` czytaja dane z backendu.

## Uruchomienie na ESP32-C6 (COM11)

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step07 `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -SkipFlash -SkipSmoke
```

Flash:

```powershell
cd artifacts/esp32c6/c6-com11-step07
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write-flash "@flash_args"
```

Smoke (`umatter`):

```python
import umatter
n = umatter.Node()
print("EP_COUNT_0", n.endpoint_count())
ep = n.add_endpoint(endpoint_id=1, device_type=0x0100)
print("EP_COUNT_1", n.endpoint_count())
ep.add_cluster(0x0006)
print("CL_COUNT_1", ep.cluster_count())
try:
    n.add_endpoint(endpoint_id=1, device_type=0x0100)
except Exception as e:
    print("DUP_EP_ERR", type(e).__name__, str(e))
try:
    ep.add_cluster(0x0006)
except Exception as e:
    print("DUP_CL_ERR", type(e).__name__, str(e))
print("STARTED_0", n.is_started())
n.start(); print("STARTED_1", n.is_started())
n.stop(); print("STARTED_2", n.is_started())
n.close(); print("CLOSE_OK")
```

Smoke (`_umatter_core`):

```python
import _umatter_core as c
h = c.create(0xFFF1, 0x8000, "core-test")
print("EP0", c.endpoint_count(h))
print("ADD_EP", c.add_endpoint(h, 11, 0x0100))
print("EP1", c.endpoint_count(h))
print("ADD_CL", c.add_cluster(h, 11, 0x0006))
print("CL1", c.cluster_count(h, 11))
print("DUP_EP", c.add_endpoint(h, 11, 0x0100))
print("DUP_CL", c.add_cluster(h, 11, 0x0006))
print("DESTROY", c.destroy(h))
```

## Kryterium zaliczenia

1. Build C6 przechodzi z `USER_C_MODULES=modules/umatter`.
2. Flash na `COM11` przechodzi.
3. Smoke `umatter` zwraca:
   - `EP_COUNT_0 0`, `EP_COUNT_1 1`, `CL_COUNT_1 1`,
   - `DUP_EP_ERR ValueError endpoint_id already exists`,
   - `DUP_CL_ERR ValueError cluster already exists`,
   - `STARTED_0 False`, `STARTED_1 True`, `STARTED_2 False`, `CLOSE_OK`.
4. Smoke `_umatter_core` zwraca:
   - `ADD_EP 0`, `ADD_CL 0`, `DUP_EP -5`, `DUP_CL -5`, `DESTROY 0`.

## Nastepny krok

Rozszerzyc one-liner `umatter.Light(...)`, aby tworzyl gotowy model light:
1. domyslny endpoint + podstawowe klastry (`OnOff`, opcjonalnie `LevelControl`),
2. utrzymanie obecnych kontraktow bledow,
3. smoke na C6 dla sciezki `l = umatter.Light(...); l.start()/stop()/close()`.
