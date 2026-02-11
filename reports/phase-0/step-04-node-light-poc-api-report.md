# Raport fazy 0 - krok 04 (Node lifecycle + `umatter.Light` na ESP32-C5)

Data: 2026-02-11

## 1. Zakres i decyzje

- Zakres:
  1. Naprawa kompatybilnosci typu `Node` z MicroPython 1.27.
  2. Utrzymanie placeholder backendu `_umatter_core` i walidacja lifecycle.
  3. Dodanie pierwszego prostego API `umatter.Light(name=...)`.
  4. Walidacja end-to-end na fizycznym `ESP32-C5` (`COM14`).
- Decyzje:
  1. Typ `Node` utrzymany jako natywny obiekt C (sloty `make_new` + `locals_dict`).
  2. `Light` na tym etapie jest swiadomym wrapperem zwracajacym obiekt `Node`.
  3. Kazdy build uruchamiany na osobnym `-BuildInstance` dla bezpiecznej pracy rownoleglej.

## 2. Zmienione pliki

1. `modules/umatter/src/mod_umatter.c`
2. `docs/phase-0/step-04-node-light-poc-api.md`
3. `reports/phase-0/step-04-node-light-poc-api-report.md`

## 3. Wyniki walidacji

Polecenie:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/phase0_step02_c5_e2e.ps1 -ComPort COM14 -BuildInstance c5-com14-light1 -UserCModulesPath modules/umatter -SmokeExpr "import sys,os,umatter,_umatter_core; l=umatter.Light(name='Lampa Salon'); print(sys.implementation); print(os.uname()); print('stub', umatter.is_stub()); print('light-type', type(l)); print('light0', l.is_started()); l.start(); print('light1', l.is_started()); l.stop(); print('light2', l.is_started()); l.close(); n=umatter.Node(vendor_id=0xFFF1, product_id=0x8002, device_name='Node PoC'); n.start(); print('node1', n.is_started()); n.stop(); n.close(); print('api-ok')"
```

Wynik:
1. Build: `PASS`
2. Flash: `PASS` (`COM14`)
3. Smoke: `PASS`
   - `stub True`
   - `light-type <class 'Node'>`
   - `light0 False`, `light1 True`, `light2 False`
   - `node1 True`
   - `api-ok`

Dodatkowa walidacja (po poprawce samego typu `Node`):
1. Instancja: `c5-com14-node2`
2. Wynik smoke: `started0 False`, `started1 True`, `started2 False`, `node-ok`

Artefakty:
1. `artifacts/esp32c5/c5-com14-node2/flash_args`
2. `artifacts/esp32c5/c5-com14-node2/micropython.bin`
3. `artifacts/esp32c5/c5-com14-light1/flash_args`
4. `artifacts/esp32c5/c5-com14-light1/micropython.bin`
5. `artifacts/esp32c5/c5-com14-light1/build_info.txt`

## 4. Ryzyka i blocker

- Blokery krytyczne:
  1. Brak.
- Ryzyka:
  1. `umatter.Light` zwraca jeszcze `Node` (brak dedykowanego typu `Light`).
  2. Brak endpoint/cluster API - to nadal PoC kontraktu lifecycle.
  3. Brak commissioning i realnej integracji z `esp-matter` (placeholder runtime).

## 5. Nastepny krok dla kolejnego agenta

- Agent 03 (`agents/03-core-binding-cpp.md`) + Agent 04 (`agents/04-python-api.md`):
  1. Dodac placeholder model danych: `Node.add_endpoint(...)`.
  2. Dodac minimalne `Endpoint.add_cluster(...)` z walidacja argumentow.
  3. Rozszerzyc smoke o przejscie sciezki Node -> Endpoint -> Cluster.

