# Faza 0 - Krok 05: Placeholder data model `Node -> Endpoint -> Cluster`

## Cel

Dodac pierwszy kontrakt modelu danych poza samym lifecycle:
1. `Node.add_endpoint(...)`
2. `Endpoint.add_cluster(...)`
3. Liczniki kontrolne placeholderow (`endpoint_count`, `cluster_count`)

## Co zostalo dodane

1. Typ natywny `Endpoint` w module `umatter`.
2. Metoda `Node.add_endpoint(endpoint_id=..., device_type=...)`.
3. Metoda `Node.endpoint_count()`.
4. Metoda `Endpoint.add_cluster(cluster_id)`.
5. Metoda `Endpoint.cluster_count()`.
6. Stale placeholder:
   - `DEVICE_TYPE_ON_OFF_LIGHT = 0x0100`
   - `CLUSTER_ON_OFF = 0x0006`
   - `CLUSTER_LEVEL_CONTROL = 0x0008`

## Kontrakt API na tym etapie

1. `n = umatter.Node(...)`
2. `ep = n.add_endpoint(endpoint_id=1, device_type=umatter.DEVICE_TYPE_ON_OFF_LIGHT)`
3. `ep.add_cluster(umatter.CLUSTER_ON_OFF)`
4. `ep.add_cluster(umatter.CLUSTER_LEVEL_CONTROL)`
5. `n.endpoint_count() == 1`
6. `ep.cluster_count() == 2`

## Uruchomienie na ESP32-C6 (`COM11`)

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step05 `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -SkipFlash -SkipSmoke
```

Flash:

```powershell
cd artifacts/esp32c6/c6-com11-step05
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write_flash "@flash_args"
```

Smoke (REPL):

```python
import sys, os, umatter, _umatter_core
n = umatter.Node(vendor_id=0xFFF1, product_id=0x8004, device_name="C6 Node DM")
ep = n.add_endpoint(endpoint_id=1, device_type=umatter.DEVICE_TYPE_ON_OFF_LIGHT)
ep.add_cluster(umatter.CLUSTER_ON_OFF)
ep.add_cluster(umatter.CLUSTER_LEVEL_CONTROL)
print(sys.implementation)
print(os.uname())
print("endpoint_count", n.endpoint_count())
print("cluster_count", ep.cluster_count())
n.start()
print("started", n.is_started())
n.stop()
n.close()
print("smoke-step05-ok")
```

## Kryterium zaliczenia

1. Build dla `ESP32_GENERIC_C6` przechodzi z `Found User C Module(s): usermod_umatter`.
2. Flash na `COM11` przechodzi.
3. Smoke zwraca:
   - `endpoint_count 1`
   - `cluster_count 2`
   - `started True`
   - `smoke-step05-ok`

## Nastepny krok

Przejsc z placeholderow do pierwszej realnej semantyki modelu:
1. walidacja duplikatow `endpoint_id`,
2. przechowywanie listy endpointow i klastrow per node,
3. przygotowanie mapowania do backendu `esp-matter`.

