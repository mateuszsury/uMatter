# Faza 0 - Krok 04: Node lifecycle + prosty one-liner `umatter.Light`

## Cel

Podniesc PoC API o kolejny maly krok:
1. Stabilny kontrakt `umatter.Node(...)` z lifecycle (`start/stop/close/is_started`).
2. Pierwszy prosty wrapper `umatter.Light(name=...)` jako one-liner API.

## Co zostalo dodane

1. Kompatybilna z MicroPython 1.27 deklaracja typu `Node` (slot-based `MP_DEFINE_CONST_OBJ_TYPE`).
2. Wspolna sciezka tworzenia obiektu Node (`umatter_node_new_from_values`).
3. Funkcja `umatter.Light(...)` zwracajaca obiekt `Node` z domyslnymi identyfikatorami.

Kontrakt API na tym etapie:
1. `import umatter, _umatter_core`
2. `n = umatter.Node(...)`
3. `n.start(); n.stop(); n.close(); n.is_started()`
4. `l = umatter.Light(name="Lampa Salon")`
5. `l.start(); l.stop(); l.close(); l.is_started()`

## Uruchomienie na C5 (COM14)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 `
  -ComPort COM14 `
  -BuildInstance c5-com14-light1 `
  -UserCModulesPath modules/umatter `
  -SmokeExpr "import sys,os,umatter,_umatter_core; l=umatter.Light(name='Lampa Salon'); print(sys.implementation); print(os.uname()); print('stub', umatter.is_stub()); print('light-type', type(l)); print('light0', l.is_started()); l.start(); print('light1', l.is_started()); l.stop(); print('light2', l.is_started()); l.close(); n=umatter.Node(vendor_id=0xFFF1, product_id=0x8002, device_name='Node PoC'); n.start(); print('node1', n.is_started()); n.stop(); n.close(); print('api-ok')"
```

## Kryterium zaliczenia

1. Build przechodzi dla `ESP32_GENERIC_C5` z `USER_C_MODULES=modules/umatter`.
2. Flash przechodzi na `COM14`.
3. Smoke zwraca:
   - `light1 True`, `light2 False`
   - `node1 True`
   - `api-ok`

## Nastepny krok

Dodac pierwszy rzeczywisty kontrakt "light-like" pod model danych:
1. placeholder endpoint/cluster API (`Node.add_endpoint`, `Endpoint.add_cluster`),
2. przygotowanie pod mapowanie na `esp-matter` w kolejnych krokach.

