# Faza 0 - Krok 06: Walidacja duplikatow i rejestr placeholderow

## Cel

Uszczelnic placeholder modelu danych:
1. wykrywac duplikaty `endpoint_id` w ramach `Node`,
2. wykrywac duplikaty `cluster_id` w ramach `Endpoint`,
3. utrzymywac prosty, spojny rejestr identyfikatorow.

## Co zostalo dodane

1. Rejestr endpointow w `Node`:
   - `endpoint_ids[UMATTER_ENDPOINTS_MAX_PER_NODE]`
   - helpery `umatter_node_has_endpoint_id`, `umatter_node_next_endpoint_id`
2. Rejestr klastrow w `Endpoint`:
   - `cluster_ids[UMATTER_CLUSTERS_MAX_PER_ENDPOINT]`
   - helper `umatter_endpoint_has_cluster_id`
3. Walidacje:
   - `Node.add_endpoint(endpoint_id=...)` rzuca `ValueError("endpoint_id already exists")`
   - `Endpoint.add_cluster(cluster_id)` rzuca `ValueError("cluster already exists")`
4. Spojnosc lifecycle:
   - `Node.close()` zeruje licznik i rejestr endpointow.

## Uruchomienie na ESP32-C6 (`COM11`)

Build:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM11 `
  -Board ESP32_GENERIC_C6 `
  -BuildInstance c6-com11-step06 `
  -ArtifactsRoot artifacts/esp32c6 `
  -UserCModulesPath modules/umatter `
  -SkipFlash -SkipSmoke
```

Flash:

```powershell
cd artifacts/esp32c6/c6-com11-step06
python -m esptool --chip esp32c6 -p COM11 -b 460800 --before default_reset --after hard_reset --no-stub write_flash "@flash_args"
```

Smoke (REPL):

```python
import sys, os, umatter, _umatter_core
n = umatter.Node(vendor_id=0xFFF1, product_id=0x8005, device_name="C6 Node Step06")
ep1 = n.add_endpoint(endpoint_id=1, device_type=umatter.DEVICE_TYPE_ON_OFF_LIGHT)
ep1.add_cluster(umatter.CLUSTER_ON_OFF)
n.add_endpoint(endpoint_id=1)                # ValueError: endpoint_id already exists
ep1.add_cluster(umatter.CLUSTER_ON_OFF)      # ValueError: cluster already exists
ep2 = n.add_endpoint(device_type=umatter.DEVICE_TYPE_ON_OFF_LIGHT)
ep2.add_cluster(umatter.CLUSTER_LEVEL_CONTROL)
print("endpoint_count", n.endpoint_count())  # 2
print("cluster1", ep1.cluster_count())       # 1
print("cluster2", ep2.cluster_count())       # 1
n.start()
print("started", n.is_started())
n.stop()
n.close()
print("smoke-step06-ok")
```

## Kryterium zaliczenia

1. Build C6 przechodzi z `USER_C_MODULES`.
2. Flash na `COM11` przechodzi.
3. Smoke zwraca:
   - `ValueError: endpoint_id already exists`
   - `ValueError: cluster already exists`
   - `endpoint_count 2`
   - `cluster1 1`
   - `cluster2 1`
   - `smoke-step06-ok`

## Nastepny krok

Przygotowac przejscie od placeholdera do backendu:
1. mapowanie `Node.add_endpoint` i `Endpoint.add_cluster` do warstwy `_umatter_core`,
2. rozszerzenie `_umatter_core` o API endpoint/cluster,
3. zachowanie tych samych kontraktow bledow po stronie Pythona.

