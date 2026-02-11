# µMatter — Biblioteka Matter dla MicroPython na ESP32
## Kompletny plan projektu

---

## 1. Streszczenie wykonawcze

Projekt **µMatter** to biblioteka MicroPython implementująca pełne wsparcie dla protokołu Matter (do specyfikacji 1.4/1.5) na platformach ESP32. Rdzeń biblioteki stanowią moduły C/C++ opakowujące Espressif SDK for Matter (`esp-matter`), eksponowane do MicroPython jako natywne moduły. Biblioteka obsługuje transport WiFi (wszystkie ESP32) oraz Thread (ESP32-C6, ESP32-C5), oferując zarówno uproszczone API dla początkujących, jak i pełny zestaw narzędzi dla zaawansowanych programistów.

**Docelowa wizja użycia — prosty przykład:**

```python
import umatter

# Jedna linia — lampa Matter gotowa do komisjonowania
device = umatter.Light(name="Lampa Salon", pin=5)
device.start()
```

**Docelowa wizja użycia — zaawansowany przykład:**

```python
import umatter
from umatter import clusters, endpoints, transport

node = umatter.Node(
    vendor_id=0xFFF1,
    product_id=0x8000,
    device_name="Stacja Pogodowa"
)

ep = node.add_endpoint(umatter.TEMPERATURE_SENSOR)
ep.add_cluster(clusters.TemperatureMeasurement(min=-40, max=85))
ep.add_cluster(clusters.HumidityMeasurement())
ep.add_cluster(clusters.PressureMeasurement())

node.set_transport(transport.WiFi(ssid="dom", password="xxx"))
# lub: node.set_transport(transport.Thread())

node.on_attribute_change(my_handler)
node.start()

# W pętli głównej
while True:
    ep.update_attribute(
        clusters.TemperatureMeasurement.MEASURED_VALUE,
        read_temp_sensor()
    )
    time.sleep(30)
```

---

## 2. Analiza stanu obecnego i wykonalności

### 2.1 Aktualny ekosystem

**Espressif SDK for Matter (`esp-matter`):**
- Oficjalny framework Matter dla ESP32, zbudowany na connectedhomeip (open-source Matter SDK od CSA)
- Aktualna wersja współpracuje z ESP-IDF v5.4.1 (v5.5.1 dla C5/C61)
- API w C++ z namespace'ami: `node::create()`, `endpoint::create()`, `cluster::create()`
- Obsługuje WiFi, Thread, Ethernet; BLE używany wyłącznie do komisjonowania
- Wspiera wszystkie standardowe typy urządzeń, klastry, atrybuty, komendy

**MicroPython na ESP32:**
- Wersja v1.27 (grudzień 2025) — wspiera ESP32, C3, C6, C5, S2, S3, P4
- Budowane z ESP-IDF v5.5.1
- ESP32-C6 oficjalnie wspierany od v1.24 (październik 2024)
- ESP32-C5 oficjalnie wspierany od v1.27 (grudzień 2025)
- Mechanizm C modules pozwala na dodawanie natywnych rozszerzeń C/C++

**Istniejące próby integracji:**
- Dyskusja na GitHub MicroPython (#14168) — próba integracji CMake, zakończona błędami kompilacji
- Wątek na ESP32 Forum — podobne problemy z konfliktem systemów budowania
- Kluczowy wniosek z dyskusji: *"The problem is you need to combine three things: the Matter SDK, MicroPython, and the vendor SDK, and all three expect to be in charge"*
- Nie istnieje żadna działająca biblioteka MicroPython+Matter
- Archiwowane repozytorium `esp32-arduino-matter` (Arduino) — demonstruje podejście z prekompilowanymi bibliotekami

### 2.2 Główne wyzwania techniczne

| Wyzwanie | Poziom ryzyka | Opis |
|----------|:---:|-------|
| Integracja systemów budowania | 🔴 Krytyczny | MicroPython, ESP-IDF i connectedhomeip używają różnych systemów CMake. Trzeba je pogodzić w jednym procesie budowania |
| Zarządzanie pamięcią RAM | 🟡 Wysoki | Sam Matter SDK zużywa ~180-250 KB DRAM. MicroPython potrzebuje ~80-120 KB. Współczesne ESP32 praktycznie zawsze mają PSRAM (2-8 MB), więc strategia to: alokacja w PSRAM z automatycznym fallbackiem do DRAM. Wewnętrzny SRAM rezerwujemy dla krytycznych struktur Matter/WiFi |
| Ograniczenia Flash | 🟡 Wysoki | Matter firmware ~1.5-2 MB. MicroPython ~600 KB-1.2 MB. Wymagane minimum 4 MB flash, rekomendowane 8-16 MB |
| C++ do C bridge | 🟡 Wysoki | esp-matter API jest w C++, a MicroPython C modules operują na czystym C. Potrzebna warstwa `extern "C"` |
| Thread networking | 🟡 Wysoki | MicroPython nie posiada natywnego wsparcia dla OpenThread. Trzeba je zintegrować na poziomie C |
| Kryptografia | 🟡 Wysoki | Matter wymaga CASE/PASE (session establishment), certyfikatów DAC, grupy kryptograficznych operacji — obsługiwane przez SDK, ale wymagają alokacji w wewnętrznym DRAM (nie PSRAM) ze względu na timing-sensitivity |
| Wielowątkowość | 🟠 Średni | Matter stack działa w osobnym tasku FreeRTOS. Synchronizacja z jednowątkowym MicroPython wymaga callbacków i event queue |
| Rozmiar API | 🟠 Średni | Pełne wsparcie Matter obejmuje 50+ typów urządzeń, 100+ klastrów. Mapowanie tego na Pythonowe obiekty wymaga starannego designu |

### 2.3 Wymagania sprzętowe (minimalne)

| Platforma | Flash | SRAM | PSRAM | Wsparcie transportu | Status w MicroPython |
|-----------|-------|------|-------|---------------------|---------------------|
| ESP32 (WROVER) | 4 MB+ | 520 KB | 4-8 MB | WiFi | ✅ Pełny |
| ESP32-S3 | 8 MB+ | 512 KB | 2-8 MB | WiFi | ✅ Pełny |
| ESP32-C3 | 4 MB+ | 400 KB | — (brak PSRAM) | WiFi | ✅ Pełny |
| ESP32-C6 | 4 MB+ | 512 KB | — (brak PSRAM*) | WiFi + Thread | ✅ od v1.24 |
| ESP32-C5 | 4 MB+ | 512 KB | — (brak PSRAM*) | WiFi + Thread | ✅ od v1.27 |

*ESP32-C6 i C5 nie posiadają interfejsu PSRAM, ale ich 512 KB SRAM jest wystarczające dzięki agresywnej optymalizacji (BLE zwalniany po komisjonowaniu, newlib nano, selektywna kompilacja klastrów).

**Założenie projektowe:** Zdecydowana większość współczesnych modułów ESP32 i ESP32-S3 dostępnych na rynku posiada PSRAM (warianty WROVER, N8R8, N16R8 itp.). Biblioteka µMatter zakłada obecność PSRAM jako domyślny scenariusz i stosuje strategię **PSRAM-first z fallbackiem do DRAM:**

- **Heap MicroPython** — alokowany w PSRAM (duże obiekty, bufory, dane użytkownika)
- **WiFi/LWIP bufory** — przenoszone do PSRAM (`CONFIG_SPIRAM_TRY_ALLOCATE_WIFI_LWIP`)
- **BSS segmenty** — opcjonalnie w PSRAM (`CONFIG_SPIRAM_ALLOW_BSS_SEG_EXTERNAL_MEMORY`)
- **Matter event bufory** — w PSRAM
- **Wewnętrzny DRAM** — zarezerwowany wyłącznie dla: DMA, ISR handlers, Matter crypto core, FreeRTOS stacks, krytycznych struktur WiFi/BLE
- **Fallback** — jeśli PSRAM niedostępny (C3, C6, C5), biblioteka automatycznie przechodzi na alokację DRAM z ograniczonym profilem klastrów

Ta strategia jest realizowana w C module przez `heap_caps_malloc(size, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT)` z fallbackiem do `MALLOC_CAP_DEFAULT`.

---

## 3. Architektura biblioteki

### 3.1 Warstwy architektury

```
┌──────────────────────────────────────────────────┐
│          Warstwa 5: Prosty API (Python)           │
│   umatter.Light(), umatter.Switch(), etc.         │
│   "One-liner" urządzenia, auto-konfiguracja       │
├──────────────────────────────────────────────────┤
│          Warstwa 4: Zaawansowane API (Python)     │
│   Node, Endpoint, Cluster, Attribute              │
│   Pełna kontrola nad data modelem                 │
├──────────────────────────────────────────────────┤
│          Warstwa 3: Python Glue (Python)          │
│   umatter/__init__.py, device_types.py            │
│   Mapowanie typów, walidacja, helpery             │
├──────────────────────────────────────────────────┤
│          Warstwa 2: C Binding Layer (C/C++)       │
│   _umatter_core — natywny moduł MicroPython       │
│   extern "C" wrappery wokół esp-matter C++ API    │
│   Callback dispatching do Pythona                  │
├──────────────────────────────────────────────────┤
│          Warstwa 1: Silnik Matter (C++)           │
│   esp-matter SDK + connectedhomeip               │
│   OpenThread, BLE (NimBLE), WiFi, mDNS           │
│   Kryptografia (mbedTLS), NVS, OTA               │
├──────────────────────────────────────────────────┤
│          Warstwa 0: Hardware / ESP-IDF             │
│   FreeRTOS, WiFi/BT driver, IEEE 802.15.4        │
└──────────────────────────────────────────────────┘
```

### 3.2 Warstwa C Binding — szczegóły

Kluczowy moduł `_umatter_core` napisany w C/C++ jako MicroPython User C Module:

```
modules/umatter/
├── micropython.cmake          # Integracja z MicroPython build system
├── micropython.mk             # Makefile fragment
├── src/
│   ├── mod_umatter.c          # Rejestracja modułu MicroPython
│   ├── matter_node.cpp        # Wrapper node::create/start/stop
│   ├── matter_node.h
│   ├── matter_endpoint.cpp    # Wrapper endpoint management
│   ├── matter_endpoint.h
│   ├── matter_cluster.cpp     # Wrapper cluster/attribute/command
│   ├── matter_cluster.h
│   ├── matter_transport.cpp   # WiFi/Thread configuration
│   ├── matter_transport.h
│   ├── matter_callbacks.cpp   # Event dispatching do MicroPython
│   ├── matter_callbacks.h
│   ├── matter_commissioning.cpp # Commissioning flow
│   ├── matter_commissioning.h
│   ├── matter_ota.cpp         # OTA update support
│   ├── matter_ota.h
│   ├── matter_nvs.cpp         # Persistent storage
│   ├── matter_nvs.h
│   ├── matter_mem.h           # PSRAM-first alokator z fallbackiem do DRAM
│   └── matter_platform.cpp    # Platform detection (PSRAM, transport) & config
└── include/
    └── umatter_config.h       # Konfiguracja kompilacji
```

**Wzorzec wrappera C++ → C (przykład):**

```c
// matter_node.cpp
#include <esp_matter.h>
extern "C" {
#include "py/runtime.h"
#include "py/obj.h"

using namespace esp_matter;

typedef struct {
    mp_obj_base_t base;
    node_t *node;
    mp_obj_t attr_update_cb;
    mp_obj_t identify_cb;
} umatter_node_obj_t;

static mp_obj_t umatter_node_make_new(const mp_obj_type_t *type,
    size_t n_args, size_t n_kw, const mp_obj_t *args) {
    // Parse Python kwargs → node::config_t
    node::config_t config;
    // ... parse vendor_id, product_id, etc.
    
    umatter_node_obj_t *self = mp_obj_malloc(umatter_node_obj_t, type);
    self->node = node::create(&config, attribute_update_cb_trampoline,
                               identify_cb_trampoline, self);
    return MP_OBJ_FROM_PTR(self);
}

// Callback trampoline: C callback → Python callback
static esp_err_t attribute_update_cb_trampoline(
    callback_type_t type, uint16_t endpoint_id,
    uint32_t cluster_id, uint32_t attribute_id,
    esp_matter_attr_val_t *val, void *priv_data) {
    
    umatter_node_obj_t *self = (umatter_node_obj_t *)priv_data;
    if (self->attr_update_cb != mp_const_none) {
        // Schedule callback na MicroPython scheduler
        // (bezpieczne dla wielowątkowego kontekstu)
        mp_sched_schedule(self->attr_update_cb,
            pack_callback_args(type, endpoint_id, cluster_id,
                             attribute_id, val));
    }
    return ESP_OK;
}

} // extern "C"
```

### 3.3 Warstwa Python — struktura modułu

```
umatter/
├── __init__.py               # Główny import, proste API
├── node.py                   # Klasa Node (zaawansowane)
├── endpoint.py               # Klasa Endpoint
├── cluster.py                # Bazowa klasa Cluster
├── attribute.py              # Attribute management
├── command.py                # Command handling
├── transport/
│   ├── __init__.py
│   ├── wifi.py               # WiFi transport config
│   └── thread.py             # Thread transport config
├── device_types/
│   ├── __init__.py           # Rejestr typów urządzeń
│   ├── lighting.py           # Light, DimmableLight, ColorLight, etc.
│   ├── switches.py           # OnOffSwitch, DimmerSwitch, etc.
│   ├── sensors.py            # TemperatureSensor, HumiditySensor, etc.
│   ├── hvac.py               # Thermostat, Fan, AirPurifier, etc.
│   ├── closures.py           # DoorLock, WindowCovering, etc.
│   ├── media.py              # VideoPlayer, Speaker, etc.
│   ├── appliances.py         # Washer, Dryer, Oven, etc.
│   ├── energy.py             # EVSE, SolarPower, Battery, etc.
│   └── safety.py             # SmokeAlarm, AirQualitySensor, etc.
├── clusters/
│   ├── __init__.py
│   ├── on_off.py             # OnOff cluster
│   ├── level_control.py      # LevelControl cluster
│   ├── color_control.py      # ColorControl cluster
│   ├── temperature.py        # TemperatureMeasurement
│   ├── humidity.py           # RelativeHumidityMeasurement
│   ├── pressure.py           # PressureMeasurement
│   ├── occupancy.py          # OccupancySensing
│   ├── door_lock.py          # DoorLock cluster
│   ├── window_covering.py    # WindowCovering cluster
│   ├── thermostat.py         # Thermostat cluster
│   ├── fan_control.py        # FanControl cluster
│   ├── pump.py               # PumpConfigAndControl
│   ├── valve.py              # ValveConfigAndControl
│   └── ...                   # (pełna lista poniżej)
├── commissioning.py          # Komisjonowanie, QR kody
├── ota.py                    # Over-The-Air updates
├── storage.py                # Persistent storage wrappers
├── bridge.py                 # Matter Bridge device type
├── diagnostics.py            # Network & device diagnostics
└── utils.py                  # Helpery, konwersje
```

---

## 4. Kompletna lista wspieranych typów urządzeń

### 4.1 Matter 1.0 — Fundamenty

| Kategoria | Typ urządzenia | Device Type ID | Priorytet |
|-----------|---------------|----------------|-----------|
| **Oświetlenie** | On/Off Light | 0x0100 | P0 |
| | Dimmable Light | 0x0101 | P0 |
| | Color Temperature Light | 0x0102 | P0 |
| | Extended Color Light | 0x010D | P0 |
| **Przełączniki** | On/Off Light Switch | 0x0103 | P0 |
| | Dimmer Switch | 0x0104 | P0 |
| | Color Dimmer Switch | 0x0105 | P1 |
| | Generic Switch | 0x000F | P0 |
| **Zasilanie** | On/Off Plug-in Unit | 0x010A | P0 |
| | Dimmable Plug-In Unit | 0x010B | P1 |
| **Sensory** | Contact Sensor | 0x0015 | P0 |
| | Occupancy Sensor | 0x0107 | P0 |
| | Temperature Sensor | 0x0302 | P0 |
| | Humidity Sensor | 0x0307 | P0 |
| | Pressure Sensor | 0x0305 | P1 |
| | Flow Sensor | 0x0306 | P1 |
| | Light Sensor | 0x0106 | P1 |
| **Zamki** | Door Lock | 0x000A | P0 |
| | Door Lock Controller | 0x000B | P1 |
| **Rolety** | Window Covering | 0x0202 | P0 |
| **HVAC** | Thermostat | 0x0301 | P0 |
| | Heating/Cooling Unit | 0x0300 | P1 |
| **Media** | Basic Video Player | 0x0028 | P2 |
| | Casting Video Player | 0x0023 | P2 |
| | Speaker | 0x0022 | P2 |
| | Content App | 0x0024 | P2 |
| **Sieć** | Bridged Device | 0x0013 | P1 |
| | Aggregator (Bridge) | 0x000E | P1 |

### 4.2 Matter 1.2 — Rozszerzone urządzenia

| Kategoria | Typ urządzenia | Priorytet |
|-----------|---------------|-----------|
| **AGD** | Refrigerator | P2 |
| | Room Air Conditioner | P2 |
| | Dishwasher | P2 |
| | Laundry Washer | P2 |
| **Czystość** | Robotic Vacuum Cleaner | P2 |
| | Air Purifier | P1 |
| **Wentylacja** | Fan | P1 |
| **Bezpieczeństwo** | Smoke/CO Alarm | P1 |
| **Jakość powietrza** | Air Quality Sensor | P1 |

### 4.3 Matter 1.3 — Energia i AGD

| Kategoria | Typ urządzenia | Priorytet |
|-----------|---------------|-----------|
| **AGD** | Microwave Oven | P2 |
| | Oven | P2 |
| | Cooktop | P2 |
| | Extractor Hood | P2 |
| | Laundry Dryer | P2 |
| **Energia** | EVSE (ładowarka EV) | P2 |
| | Device Energy Management | P2 |

### 4.4 Matter 1.4 — Zarządzanie energią

| Kategoria | Typ urządzenia | Priorytet |
|-----------|---------------|-----------|
| **Energia** | Solar Power (Inverter, Panel) | P2 |
| | Battery (BESS) | P2 |
| | Heat Pump | P2 |
| | Water Heater | P2 |
| **Kontrola** | Mounted On/Off Control | P1 |
| | Mounted Dimmable Load Control | P1 |
| **Sieć** | HRAP (Home Router/AP) | P3 |

### 4.5 Matter 1.5 — Kamery i więcej

| Kategoria | Typ urządzenia | Priorytet |
|-----------|---------------|-----------|
| **Kamery** | Camera | P3 |
| **Sensory** | Soil Moisture Sensor | P2 |
| **Zamknięcia** | Enhanced Closures | P2 |

**Legenda priorytetów:**
- **P0** — Faza 1 (MVP) — podstawowe, najczęściej używane typy
- **P1** — Faza 2 — popularne typy, wymagane dla kompletności
- **P2** — Faza 3 — specjalistyczne urządzenia i AGD
- **P3** — Faza 4 — zaawansowane/rzadkie typy

---

## 5. Kompletna lista wspieranych klastrów

### 5.1 Klastry Utility (Endpoint 0)

Obsługiwane automatycznie przez bibliotekę, bez konieczności ręcznej konfiguracji:

- **Basic Information** — nazwa, vendor, product, wersja
- **General Commissioning** — komisjonowanie urządzenia
- **Network Commissioning** — konfiguracja WiFi/Thread
- **Operational Credentials** — certyfikaty, NOC
- **General Diagnostics** — diagnostyka ogólna
- **WiFi Network Diagnostics** — diagnostyka WiFi
- **Thread Network Diagnostics** — diagnostyka Thread
- **Administrator Commissioning** — zarządzanie komisjonowaniem
- **Access Control** — lista kontroli dostępu (ACL)
- **Group Key Management** — zarządzanie kluczami grup
- **OTA Software Update Provider/Requestor** — aktualizacje firmware
- **Descriptor** — opis endpointów
- **Binding** — powiązania między endpointami
- **Identify** — identyfikacja fizyczna urządzenia
- **Time Synchronization** — synchronizacja czasu

### 5.2 Klastry aplikacyjne (eksponowane w API)

| Klaster | Zastosowanie | Faza |
|---------|-------------|------|
| OnOff | Włącz/wyłącz | 1 |
| LevelControl | Jasność/poziom | 1 |
| ColorControl | Kolor (HSV, XY, temp.) | 1 |
| TemperatureMeasurement | Odczyt temperatury | 1 |
| RelativeHumidityMeasurement | Odczyt wilgotności | 1 |
| PressureMeasurement | Odczyt ciśnienia | 1 |
| OccupancySensing | Detekcja obecności | 1 |
| BooleanState | Sensor kontaktowy | 1 |
| DoorLock | Zamek drzwi | 1 |
| WindowCovering | Sterowanie roletami | 1 |
| Thermostat | Kontrola temperatury | 1 |
| FanControl | Sterowanie wentylatorem | 2 |
| PumpConfigAndControl | Sterowanie pompą | 2 |
| ValveConfigAndControl | Sterowanie zaworem | 2 |
| FlowMeasurement | Odczyt przepływu | 2 |
| IlluminanceMeasurement | Odczyt natężenia światła | 2 |
| BallastConfiguration | Konfiguracja ballasta | 3 |
| SmokeCoAlarm | Alarm dymu/CO | 2 |
| AirQuality | Jakość powietrza | 2 |
| CarbonMonoxideConcentration | Stężenie CO | 2 |
| CarbonDioxideConcentration | Stężenie CO2 | 2 |
| PM2.5 / PM10 / Ozone / Formaldehyde / NO2 | Pomiary jakości powietrza | 2 |
| HepaFilterMonitoring | Monitoring filtra HEPA | 3 |
| ActivatedCarbonFilter | Monitoring filtra węglowego | 3 |
| ModeSelect | Wybór trybu | 2 |
| LaundryWasherMode | Tryb pralki | 3 |
| DishwasherMode | Tryb zmywarki | 3 |
| RefrigeratorAndTCCMode | Tryb lodówki | 3 |
| OvenMode | Tryb piekarnika | 3 |
| MicrowaveOvenControl | Kontrola mikrofali | 3 |
| OperationalState | Stan operacyjny | 2 |
| RvcRunMode / RvcCleanMode | Tryby odkurzacza | 3 |
| TemperatureControl | Kontrola temperatury (AGD) | 3 |
| Scenes | Sceny | 2 |
| Groups | Grupy urządzeń | 2 |
| PowerSource | Źródło zasilania | 1 |
| Switch (GenericSwitch) | Przycisk fizyczny | 1 |
| EnergyEVSE | Ładowanie EV | 3 |
| DeviceEnergyManagement | Zarządzanie energią | 3 |
| ElectricalMeasurement | Pomiary elektryczne | 2 |
| ElectricalEnergyMeasurement | Pomiar energii | 2 |
| PowerTopology | Topologia zasilania | 3 |
| WaterHeaterManagement | Zarządzanie podgrzewaczem | 3 |
| MediaPlayback / AudioOutput / Channel | Media | 3 |
| ContentLauncher / TargetNavigator | Nawigacja treści | 3 |
| AccountLogin / ApplicationBasic | Aplikacje | 3 |
| KeypadInput / WakeOnLan | Sterowanie pilotem | 3 |

---

## 6. Szczegółowy design API

### 6.1 Proste API (Warstwa 5) — Quick Start

Cel: uruchomienie urządzenia Matter w kilku liniach kodu.

```python
import umatter

# ===== OŚWIETLENIE =====
light = umatter.Light(name="Lampa", pin=5)
light.start()  # Gotowe! Komisjonowanie przez BLE

dimmable = umatter.DimmableLight(name="Ściemniacz", pin=5, pwm=True)
dimmable.start()

color = umatter.ColorLight(name="RGB", pins={"r": 25, "g": 26, "b": 27})
color.start()

# ===== SENSORY =====
temp = umatter.TemperatureSensor(name="Termometr", read_fn=my_temp_fn)
temp.start()  # Automatycznie raportuje co 30s (konfigurowalnie)

contact = umatter.ContactSensor(name="Drzwi", pin=4)
contact.start()

motion = umatter.OccupancySensor(name="Ruch", pin=13)
motion.start()

# ===== PRZEŁĄCZNIKI =====
switch = umatter.Switch(name="Wyłącznik", pin=0, on_press=my_callback)
switch.start()

plug = umatter.SmartPlug(name="Gniazdko", relay_pin=5, power_meter_pin=34)
plug.start()

# ===== ZAMKI =====
lock = umatter.DoorLock(name="Zamek", lock_fn=my_lock, unlock_fn=my_unlock)
lock.start()

# ===== ROLETY =====
cover = umatter.WindowCovering(name="Roleta", up_pin=25, down_pin=26)
cover.start()

# ===== TERMOSTAT =====
thermo = umatter.Thermostat(
    name="Termostat", 
    temp_fn=read_temp, 
    heat_fn=turn_on_heat,
    cool_fn=turn_on_cool
)
thermo.start()
```

**Cechy prostego API:**
- Auto-detekcja platformy (WiFi/Thread na C6, WiFi-only na innych)
- Auto-generowanie Vendor/Product ID dla developmentu
- Wbudowana obsługa BLE commissioning
- Domyślne wartości dla wszystkich parametrów
- Automatyczny event loop w tle
- Automatyczna persystencja stanu w NVS

### 6.2 Zaawansowane API (Warstwa 4)

```python
import umatter
from umatter.node import Node
from umatter.endpoint import Endpoint
from umatter.clusters import (
    OnOff, LevelControl, ColorControl,
    TemperatureMeasurement, OccupancySensing
)
from umatter.transport import WiFi, Thread
from umatter.commissioning import CommissioningConfig

# --- Konfiguracja node'a ---
node = Node(
    vendor_id=0xFFF1,           # Test vendor ID
    product_id=0x8000,
    vendor_name="MojaFirma",
    product_name="SmartMultiSensor",
    hw_version=1,
    sw_version=1,
    serial_number="SN001",
    commissioning=CommissioningConfig(
        discriminator=3840,
        passcode=20202021,
        discovery_mode="ble",  # "ble", "softap", "on_network"
    )
)

# --- Endpoint 1: Lampa ---
light_ep = node.add_endpoint(
    device_type=umatter.EXTENDED_COLOR_LIGHT,
    endpoint_id=1  # opcjonalne, auto-assign jeśli pominięte
)
light_ep.add_cluster(OnOff(default_on=False))
light_ep.add_cluster(LevelControl(
    min_level=1, max_level=254, default_level=127
))
light_ep.add_cluster(ColorControl(
    color_capabilities=["hue_saturation", "color_temperature"],
    min_mireds=153, max_mireds=500
))

# --- Endpoint 2: Sensor temperatury ---
temp_ep = node.add_endpoint(
    device_type=umatter.TEMPERATURE_SENSOR,
    endpoint_id=2
)
temp_ep.add_cluster(TemperatureMeasurement(
    min_measured=-40.0,
    max_measured=125.0,
    tolerance=0.5
))

# --- Endpoint 3: Sensor ruchu ---
occ_ep = node.add_endpoint(
    device_type=umatter.OCCUPANCY_SENSOR,
    endpoint_id=3
)
occ_ep.add_cluster(OccupancySensing(
    sensor_type="pir"  # "pir", "ultrasonic", "pir_and_ultrasonic", "radar"
))

# --- Transport ---
node.set_transport(WiFi())  # Użyje zapisanych credentials lub poprosi przy komisjonowaniu
# LUB
node.set_transport(Thread())  # Dla ESP32-C6/C5

# --- Callbacki ---
@node.on_attribute_write
def handle_write(endpoint_id, cluster_id, attribute_id, value):
    """Wywoływane gdy kontroler zmienia atrybut"""
    if endpoint_id == 1 and cluster_id == OnOff.ID:
        if attribute_id == OnOff.Attributes.ON_OFF:
            set_light(value)
    return True  # Akceptuj zmianę

@node.on_command
def handle_command(endpoint_id, cluster_id, command_id, data):
    """Wywoływane przy otrzymaniu komendy"""
    pass

@node.on_identify
def handle_identify(endpoint_id, identify_type):
    """Wywoływane przy żądaniu identyfikacji"""
    blink_led(5)

@node.on_commissioning_complete
def commissioned():
    print("Urządzenie skonfigurowane!")

@node.on_connectivity_change
def connectivity(transport_type, connected):
    print(f"Połączenie {transport_type}: {connected}")

# --- Start ---
node.start()

# --- Główna pętla ---
while True:
    temp_value = read_dht22()
    temp_ep.update_attribute(
        TemperatureMeasurement.ID,
        TemperatureMeasurement.Attributes.MEASURED_VALUE,
        int(temp_value * 100)  # Matter używa setnych stopnia
    )
    
    occupancy = read_pir()
    occ_ep.update_attribute(
        OccupancySensing.ID,
        OccupancySensing.Attributes.OCCUPANCY,
        occupancy
    )
    
    time.sleep(10)
```

### 6.3 API dla Matter Bridge

```python
import umatter
from umatter.bridge import Bridge

bridge = Bridge(name="Zigbee Bridge")

# Dynamiczne dodawanie urządzeń za bridgem
dev1 = bridge.add_bridged_device(
    device_type=umatter.ON_OFF_LIGHT,
    name="Żarówka Zigbee",
    reachable=True
)

dev2 = bridge.add_bridged_device(
    device_type=umatter.TEMPERATURE_SENSOR,
    name="Termometr 433MHz"
)

@bridge.on_bridged_write
def handle(device, cluster_id, attribute_id, value):
    # Przekaż do Zigbee/433MHz/etc.
    pass

# Dynamiczne usuwanie
bridge.remove_bridged_device(dev1)

bridge.start()
```

### 6.4 API dla niestandardowych klastrów (Custom Clusters)

```python
from umatter.cluster import CustomCluster, Attribute, Command

class MyCustomCluster(CustomCluster):
    ID = 0xFFF10001  # Vendor-specific
    
    class Attributes:
        CUSTOM_VALUE = Attribute(
            id=0x0000,
            type="uint16",
            default=0,
            access="rw",
            persistent=True
        )
        CUSTOM_STRING = Attribute(
            id=0x0001,
            type="string",
            max_length=32,
            access="r"
        )
    
    class Commands:
        DO_SOMETHING = Command(
            id=0x00,
            request_fields=[("param1", "uint8"), ("param2", "string")],
            response_fields=[("result", "bool")]
        )
    
    def handle_command(self, command_id, data):
        if command_id == self.Commands.DO_SOMETHING.id:
            # Process command
            return {"result": True}

# Użycie
ep.add_cluster(MyCustomCluster())
```

---

## 7. System budowania (Build System)

### 7.1 Podejście: Customowy MicroPython Port

Ze względu na złożoność integracji, rekomendowane jest podejście **custom MicroPython firmware**:

```
umatter-firmware/
├── micropython/              # Git submodule → micropython repo
├── esp-idf/                  # Git submodule → esp-idf v5.4.1/v5.5.1
├── esp-matter/               # Git submodule → esp-matter repo
├── modules/
│   └── umatter/              # C/C++ moduł (USER_C_MODULES)
│       ├── micropython.cmake
│       ├── CMakeLists.txt    # Linkuje z esp-matter komponentami
│       └── src/              # Kod C/C++
├── python/
│   └── umatter/              # Pliki Python (frozen modules)
├── boards/
│   ├── UMATTER_ESP32/        # Board definition dla ESP32
│   ├── UMATTER_ESP32S3/      # Board definition dla ESP32-S3
│   ├── UMATTER_ESP32C3/      # Board definition dla ESP32-C3
│   ├── UMATTER_ESP32C6/      # Board definition dla ESP32-C6 (WiFi+Thread)
│   └── UMATTER_ESP32C5/      # Board definition dla ESP32-C5 (WiFi+Thread)
├── partitions/
│   ├── partitions_4mb.csv    # Tabela partycji dla 4MB flash
│   ├── partitions_8mb.csv    # Tabela partycji dla 8MB flash
│   └── partitions_16mb.csv   # Tabela partycji dla 16MB flash
├── sdkconfig.defaults        # Domyślna konfiguracja ESP-IDF + Matter
├── Makefile                  # Główny skrypt budowania
├── build.py                  # Skrypt automatyzacji budowania
└── README.md
```

### 7.2 Strategia integracji CMake

Kluczowy problem: pogodzenie trzech systemów budowania.

**Rozwiązanie:**

1. **MicroPython jest main** — budowanie startuje z MicroPython's CMakeLists.txt
2. **esp-matter jako IDF component** — dodany do `EXTRA_COMPONENT_DIRS`
3. **C module linkuje z esp-matter** — przez `target_link_libraries`

```cmake
# modules/umatter/micropython.cmake
add_library(usermod_umatter INTERFACE)

# Źródła C/C++
target_sources(usermod_umatter INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}/src/mod_umatter.c
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_node.cpp
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_endpoint.cpp
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_cluster.cpp
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_transport.cpp
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_callbacks.cpp
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_commissioning.cpp
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_ota.cpp
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_nvs.cpp
    ${CMAKE_CURRENT_LIST_DIR}/src/matter_platform.cpp
)

target_include_directories(usermod_umatter INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}/include
)

# Linkowanie z komponentami esp-matter
# (dostępne po dodaniu esp-matter do EXTRA_COMPONENT_DIRS)
target_link_libraries(usermod_umatter INTERFACE
    idf::esp_matter
    idf::esp_matter_console
    idf::chip
    idf::bt
    idf::openthread
)

target_link_libraries(usermod INTERFACE usermod_umatter)
```

### 7.3 Konfiguracja partycji (8MB flash — rekomendowane)

```csv
# Name,      Type, SubType,  Offset,    Size
nvs,         data, nvs,      0x9000,    0x6000
otadata,     data, ota,      0xf000,    0x2000
phy_init,    data, phy,      0x11000,   0x1000
ota_0,       app,  ota_0,    0x20000,   0x300000   # 3MB app
ota_1,       app,  ota_1,    0x320000,  0x300000   # 3MB OTA
fctry,       data, nvs,      0x620000,  0x6000     # Factory NVS
vfs,         data, fat,      0x626000,  0x19A000   # ~1.6MB dla Python files
```

### 7.4 Optymalizacja konfiguracji (`sdkconfig.defaults`)

```ini
# --- Matter core ---
CONFIG_CHIP_TASK_STACK_SIZE=6144
CONFIG_ESP_MATTER_MAX_DYNAMIC_ENDPOINT_COUNT=8
CONFIG_ESP_MATTER_MAX_DEVICE_TYPE_COUNT=8

# --- RAM optimization ---
CONFIG_USE_BLE_ONLY_FOR_COMMISSIONING=y
CONFIG_NIMBLE_MAX_CONNECTIONS=1
CONFIG_BT_NIMBLE_ROLE_CENTRAL=n
CONFIG_BT_NIMBLE_ROLE_OBSERVER=n
CONFIG_EVENT_LOGGING_CRIT_BUFFER_SIZE=512
CONFIG_EVENT_LOGGING_INFO_BUFFER_SIZE=512
CONFIG_EVENT_LOGGING_DEBUG_BUFFER_SIZE=256
CONFIG_ESP_SYSTEM_EVENT_QUEUE_SIZE=16

# --- Flash optimization ---
CONFIG_COMPILER_OPTIMIZATION_SIZE=y
CONFIG_NEWLIB_NANO_FORMAT=y

# --- PSRAM-first memory strategy (domyślnie włączone) ---
CONFIG_SPIRAM=y
CONFIG_SPIRAM_MODE_OCT=y
CONFIG_SPIRAM_TRY_ALLOCATE_WIFI_LWIP=y
CONFIG_SPIRAM_ALLOW_BSS_SEG_EXTERNAL_MEMORY=y
CONFIG_SPIRAM_MALLOC_ALWAYSINTERNAL=4096
CONFIG_SPIRAM_MALLOC_RESERVE_INTERNAL=65536
# ^ Alokacje ≤4KB → wewnętrzny DRAM (szybszy, DMA-capable)
# ^ Alokacje >4KB → PSRAM (pojemniejszy)
# ^ Minimalna rezerwa 64KB wewnętrznego DRAM dla krytycznych operacji

# --- MicroPython heap w PSRAM ---
CONFIG_MICROPYTHON_HEAP_SIZE=2097152  # 2MB heap w PSRAM (domyślnie)
# Dla ESP32 bez PSRAM (C3, C6, C5) automatycznie fallback do 128KB DRAM

# --- Thread (tylko C6/C5 — brak PSRAM, więc agresywna optymalizacja DRAM) ---
CONFIG_OPENTHREAD_ENABLED=y
CONFIG_OPENTHREAD_FTD=n  # End device only (oszczędność DRAM)
CONFIG_OPENTHREAD_MTD=y
```

---

## 8. Rozwiązywanie kluczowych problemów

### 8.1 Strategia zarządzania pamięcią: PSRAM-first z fallbackiem do DRAM

Współczesne moduły ESP32 praktycznie zawsze posiadają PSRAM (ESP32-WROVER, ESP32-S3 N8R8/N16R8). Biblioteka µMatter zakłada PSRAM jako bazowy scenariusz i implementuje trójwarstwową strategię alokacji:

**Warstwa 1: Automatyczna alokacja PSRAM-first (C module)**

```c
// umatter_mem.h — centralny alokator biblioteki
#include "esp_heap_caps.h"

// Alokacja w PSRAM z fallbackiem do DRAM
static inline void *umatter_malloc(size_t size) {
    void *ptr = heap_caps_malloc(size, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (ptr == NULL) {
        // Fallback: wewnętrzny DRAM
        ptr = heap_caps_malloc(size, MALLOC_CAP_DEFAULT);
    }
    return ptr;
}

// Alokacja wymuszona w wewnętrznym DRAM (dla DMA, ISR, crypto)
static inline void *umatter_malloc_internal(size_t size) {
    return heap_caps_malloc(size, MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
}

// Alokacja z callbackiem na brak pamięci
static inline void *umatter_malloc_or_fail(size_t size, const char *tag) {
    void *ptr = umatter_malloc(size);
    if (ptr == NULL) {
        ESP_LOGE(tag, "PSRAM+DRAM alloc failed for %d bytes", size);
        // Próba zwolnienia MicroPython GC i ponowna alokacja
        mp_sched_schedule(gc_collect_callback, mp_const_none);
        ptr = umatter_malloc(size);
    }
    return ptr;
}
```

**Warstwa 2: Podział odpowiedzialności pamięci**

| Typ danych | Lokalizacja | Powód |
|-----------|-------------|-------|
| MicroPython heap (obiekty Python, bufory użytkownika) | **PSRAM** | Największy konsument, niewymagający DMA |
| WiFi/LWIP bufory | **PSRAM** | Duże, niewymagające DMA na większości SoC |
| Matter event log bufory | **PSRAM** | Do 4KB per bufor, nie krytyczne czasowo |
| Matter attribute storage | **PSRAM** (fallback DRAM) | Średni rozmiar, częsty dostęp |
| FreeRTOS task stacks | **DRAM** | Wymagane w wewnętrznej pamięci |
| BLE NimBLE bufory | **DRAM** | DMA-capable wymagane |
| Matter crypto (mbedTLS) | **DRAM** | Operacje kryptograficzne wrażliwe na timing |
| DMA bufory (SPI, I2C, UART) | **DRAM** | Wymóg sprzętowy |
| ISR handlery | **IRAM** | Wymóg sprzętowy |

**Warstwa 3: Runtime detection i adaptive config**

```c
// matter_platform.cpp — inicjalizacja z detekcją PSRAM
void umatter_platform_init(void) {
    size_t psram_size = heap_caps_get_total_size(MALLOC_CAP_SPIRAM);
    
    if (psram_size > 0) {
        ESP_LOGI(TAG, "PSRAM detected: %d KB — using PSRAM-first strategy", 
                 psram_size / 1024);
        // Pełna konfiguracja: duży heap, wszystkie klastry dostępne
        g_umatter_config.heap_size = MIN(psram_size / 2, 4 * 1024 * 1024);
        g_umatter_config.max_endpoints = 16;
        g_umatter_config.event_buffer_size = 4096;
    } else {
        ESP_LOGW(TAG, "No PSRAM — using DRAM-only mode with reduced profile");
        // Ograniczona konfiguracja: mały heap, basic klastry
        g_umatter_config.heap_size = 128 * 1024;
        g_umatter_config.max_endpoints = 4;
        g_umatter_config.event_buffer_size = 512;
    }
}
```

**Warstwa 4: Selective cluster compilation (oszczędność Flash + DRAM)**

Niezależnie od PSRAM, nieużywane klastry mogą być wyłączone na etapie kompilacji:

```c
// umatter_config.h
#define UMATTER_INCLUDE_LIGHTING    1
#define UMATTER_INCLUDE_SENSORS     1
#define UMATTER_INCLUDE_HVAC        0   // Wyłączone = oszczędność ~30KB Flash
#define UMATTER_INCLUDE_MEDIA       0   // Wyłączone = oszczędność ~50KB Flash
#define UMATTER_INCLUDE_APPLIANCES  0   // Wyłączone = oszczędność ~40KB Flash
```

Dodatkowo Python moduły klastrów używają lazy loading:

```python
# clusters/__init__.py — ładowanie na żądanie, nie zajmuje RAM dopóki niepotrzebne
def __getattr__(name):
    if name == "DoorLock":
        from umatter.clusters.door_lock import DoorLock
        return DoorLock
    raise AttributeError(name)
```

**Estymacja zużycia pamięci:**

| Komponent | DRAM (z PSRAM) | PSRAM | DRAM (bez PSRAM) |
|-----------|:---:|:---:|:---:|
| ESP-IDF + FreeRTOS | ~40 KB | — | ~60 KB |
| WiFi stack | ~25 KB | ~35 KB (LWIP) | ~60 KB |
| BLE (komisjonowanie*) | ~30 KB | — | ~30 KB |
| Matter SDK core | ~50 KB | ~30 KB | ~80 KB |
| Matter clusters (basic) | ~15 KB | ~15 KB | ~30 KB |
| MicroPython VM | ~20 KB | — | ~40 KB |
| MicroPython heap | — | **2-4 MB** | ~60 KB |
| **Suma DRAM** | **~180 KB** | — | **~360 KB** |
| **Wolny DRAM po komisjonowaniu** | **~210 KB** | — | **~60-80 KB** |
| **Heap użytkownika** | — | **2-4 MB** | **~60 KB** |

*BLE jest zwalniany po komisjonowaniu, odzyskując ~30 KB DRAM.

**Kluczowy wniosek:** Z PSRAM (typowy scenariusz) użytkownik ma 2-4 MB heapu Pythona i ~210 KB wolnego DRAM dla systemu — komfortowy margines. Bez PSRAM (C3, C6, C5) działanie jest możliwe, ale ograniczone do prostych urządzeń.

### 8.2 Problem: Synchronizacja wątków

Matter stack działa w dedykowanym tasku FreeRTOS, MicroPython w głównym tasku.

**Rozwiązanie: Asynchroniczna kolejka zdarzeń**

```c
// W C module
static QueueHandle_t event_queue;

// Wywoływane z Matter task
static void matter_event_callback(...) {
    matter_event_t evt = {.type = ..., .data = ...};
    xQueueSend(event_queue, &evt, 0);
}

// Wywoływane z MicroPython task (przez mp_sched_schedule)
static mp_obj_t umatter_poll(void) {
    matter_event_t evt;
    while (xQueueReceive(event_queue, &evt, 0) == pdTRUE) {
        // Dispatch do Pythonowych callbacków
        dispatch_to_python(&evt);
    }
    return mp_const_none;
}

// Opcja 2: Integration z asyncio
// Rejestracja FD-like obiektu w select/poll
```

**Dla użytkownika to transparentne:**
```python
# Opcja 1: Automatyczny polling w tle (timer)
device.start()  # Automatycznie ustawia timer dla event poll

# Opcja 2: Manualne w pętli
while True:
    umatter.poll()  # Procesuj Matter events
    # ... reszta kodu
    time.sleep_ms(100)

# Opcja 3: asyncio integration
async def main():
    await umatter.async_start()
    while True:
        await umatter.async_poll()
        await asyncio.sleep_ms(100)
```

### 8.3 Problem: Thread Networking na ESP32-C6/C5

**Stan wsparcia:**
- ESP-IDF obsługuje OpenThread na C6/C5 natywnie
- MicroPython nie ma OpenThread API, ale ma WiFi
- ESPHome od 2025.6 dodał podstawowe wsparcie OpenThread na ESP-IDF

**Rozwiązanie:**
- Warstwa Thread w C module bezpośrednio korzysta z OpenThread API ESP-IDF
- Python API jest abstrakcją:

```python
from umatter.transport import Thread

# Automatyczne dołączenie do sieci Thread przy komisjonowaniu
node.set_transport(Thread())

# Lub manualna konfiguracja
node.set_transport(Thread(
    dataset="0e080000000000010000...",  # Operational Dataset TLV
    channel=15,
    panid=0x1234,
))

# Diagnostyka
info = node.transport.get_info()
print(info)  # {"type": "thread", "role": "child", "rloc16": "0x0400", ...}
```

### 8.4 Problem: Komisjonowanie (Commissioning)

**Przepływ komisjonowania:**

1. Urządzenie startuje w trybie niekonfigurowanym
2. Rozgłasza się przez BLE (lub SoftAP/On-Network)
3. Kontroler (Google Home / Apple Home / Alexa) skanuje QR kod
4. Nawiązanie bezpiecznego kanału (PASE z passcode)
5. Transfer credentials (WiFi SSID/hasło lub Thread dataset)
6. Urządzenie łączy się z siecią
7. Establishment bezpiecznej sesji (CASE z certyfikatami)
8. Urządzenie gotowe

**API komisjonowania:**

```python
# Automatyczne (domyślne) — QR kod drukowany na serial
device = umatter.Light(name="Lampa")
device.start()
# Na serial: "QR Code: MT:Y.K900H710O00KA0648G00"
# Lub: "Manual code: 34970112332"

# Zaawansowane
from umatter.commissioning import CommissioningConfig, generate_qr

config = CommissioningConfig(
    discriminator=0xF00,
    passcode=20202021,
    discovery_mode="ble_and_softap",
    custom_flow=False
)

# Generowanie QR kodu
qr_data = generate_qr(
    vendor_id=0xFFF1,
    product_id=0x8000,
    discriminator=config.discriminator,
    passcode=config.passcode
)
print(f"QR: {qr_data}")

# Resetowanie komisjonowania
umatter.factory_reset()
```

---

## 9. System dystrybucji

### 9.1 Model dystrybucji: Pre-built Firmware

Ponieważ biblioteka wymaga kompilacji z ESP-IDF + Matter SDK, dystrybucja jako czysty Python package (pip) nie jest możliwa. Modele dystrybucji:

**Model 1: Pre-built firmware images (główny)**
- Gotowe pliki .bin dla każdej platformy + profilu
- Instalacja przez `esptool.py` (jak standardowe MicroPython)
- Profile: "Full", "Lite" (podstawowe klastry), "Thread" (C6/C5)

```bash
# Instalacja
esptool.py --baud 460800 write_flash 0 umatter-esp32s3-full-v1.0.0.bin
```

**Model 2: Docker build environment**
- Kontener Docker z pełnym środowiskiem budowania
- Użytkownik konfiguruje które klastry chce i buduje custom firmware

```bash
docker run -v ./my_config:/config umatter/builder build \
    --target esp32c6 \
    --clusters "lighting,sensors,hvac" \
    --flash 8mb
```

**Model 3: GitHub Actions / CI**
- Repozytorium z Makefile + GitHub Actions
- Użytkownik forkuje, edytuje konfigurację, CI buduje firmware

### 9.2 Narzędzie konfiguracji

Webowe narzędzie do konfiguracji firmware:

```
┌─────────────────────────────────────────┐
│        µMatter Firmware Builder          │
├─────────────────────────────────────────┤
│ Platforma: [ESP32-C6 ▼]                │
│ Flash:     [8 MB ▼]                     │
│ PSRAM:     [Tak (domyślnie) ▼]           │
│                                         │
│ Klastry:                                │
│ ☑ Oświetlenie   ☑ Sensory              │
│ ☑ Przełączniki  ☑ Zamki                │
│ ☐ HVAC          ☐ Media                │
│ ☐ AGD           ☑ Rolety               │
│ ☐ Energia       ☑ Bezpieczeństwo       │
│                                         │
│ Transport: ☑ WiFi  ☑ Thread            │
│ OTA:       ☑ Tak                        │
│ Debug:     ☐ Tak                        │
│                                         │
│ Estymacja: Flash: 2.8/8 MB              │
│            DRAM:  180/512 KB             │
│            PSRAM heap: 2 MB              │
│                                         │
│ [Buduj firmware]  [Pobierz .bin]        │
└─────────────────────────────────────────┘
```

---

## 10. Testowanie i jakość

### 10.1 Strategia testowania

| Warstwa | Metoda | Narzędzia |
|---------|--------|-----------|
| C Module | Unit testy | Unity (ESP-IDF), custom test harness |
| Python API | Unit testy | MicroPython unittest na qemu + hardware |
| Integracyjne | Testy E2E | chip-tool, Python Matter Server |
| Komisjonowanie | Manualne + auto | Google Home, Apple Home, Amazon Alexa |
| Certyfikacja | CSA Test Harness | Matter TH (Test Harness) |
| Pamięć | Profiling | ESP-IDF heap trace, `gc.mem_free()` |
| Stabilność | Soak testing | 72h ciągłego działania |
| Thread | Mesh testing | Multiple C6 devices + Border Router |

### 10.2 Macierz kompatybilności

| Kontroler | WiFi Light | WiFi Sensor | Thread Light | Thread Sensor | Bridge |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Google Home | ✓ | ✓ | ✓ | ✓ | ✓ |
| Apple Home | ✓ | ✓ | ✓ | ✓ | ✓ |
| Amazon Alexa | ✓ | ✓ | ✓ | ✓ | ? |
| Samsung SmartThings | ✓ | ✓ | ✓ | ✓ | ? |
| Home Assistant | ✓ | ✓ | ✓ | ✓ | ✓ |
| chip-tool | ✓ | ✓ | ✓ | ✓ | ✓ |

---

## 11. Roadmapa — Fazy realizacji

### Faza 0: Proof of Concept (8-10 tygodni)

**Cel:** Zbudować firmware MicroPython z esp-matter, uruchomić najprostszą lampę.

- [ ] Konfiguracja środowiska budowania (MicroPython + ESP-IDF + esp-matter)
- [ ] Rozwiązanie konfliktów CMake między trzema systemami
- [ ] Minimalny C module z `node::create()` i `extended_color_light::create()`
- [ ] Python wrapper: `umatter.Light()` → komisjonowanie z chip-tool
- [ ] Testowanie na ESP32-S3 (PSRAM — główna platforma) i ESP32-C6 (Thread, bez PSRAM)
- [ ] Profilowanie DRAM/PSRAM/Flash, walidacja strategii PSRAM-first z fallbackiem
- [ ] **Decyzja go/no-go** na podstawie wyników

**Kryteria sukcesu PoC:**
- Urządzenie komisjonuje się z Google Home lub Apple Home
- Sterowanie on/off działa z 2-sekundowym lag max
- Wolny DRAM po komisjonowaniu ≥ 150 KB (z PSRAM) / ≥ 30 KB (bez PSRAM, profil Lite)
- Heap MicroPython w PSRAM ≥ 1 MB na platformach z PSRAM

### Faza 1: MVP (12-16 tygodni)

**Cel:** Stabilna biblioteka z podstawowymi typami urządzeń.

- [ ] Pełne API Node/Endpoint/Cluster w C module
- [ ] Callbacki z Matter do Pythona (event queue + scheduler)
- [ ] Typy urządzeń P0: Light, Switch, Contact/Temp/Humidity/Occupancy Sensor, DoorLock, WindowCovering, Thermostat, SmartPlug
- [ ] Proste API (one-liner) dla wszystkich P0 typów
- [ ] WiFi transport kompletny
- [ ] Thread transport na C6/C5 (basic)
- [ ] BLE commissioning
- [ ] Persystencja stanu (NVS)
- [ ] Testy z chip-tool i min. 2 ekosystemami (Google + Apple)
- [ ] Dokumentacja: Quick Start, API Reference
- [ ] Pre-built firmware images dla ESP32-S3, C3, C6

### Faza 2: Kompletność (12-16 tygodni)

**Cel:** Pełne wsparcie Matter 1.0-1.2 + zaawansowane feature'y.

- [ ] Typy urządzeń P1: wszystkie sensory, Fan, AirPurifier, SmokeAlarm, Bridged Device, AirQuality, Mounted Controls
- [ ] Bridge API (dynamiczne dodawanie/usuwanie urządzeń)
- [ ] Custom Clusters API
- [ ] Groups i Scenes
- [ ] OTA updates
- [ ] asyncio integration
- [ ] Diagnostyka i monitoring
- [ ] Tiered compilation (wybór klastrów)
- [ ] Docker build environment
- [ ] Firmware builder (webowy konfigurator)
- [ ] Pełne testy certyfikacyjne z CSA Test Harness

### Faza 3: AGD i Energia (10-14 tygodni)

**Cel:** Matter 1.3-1.4, urządzenia AGD i zarządzanie energią.

- [ ] Typy urządzeń P2: Washer, Dryer, Oven, Microwave, Cooktop, RoboVac, EVSE, Solar, Battery, Water Heater, Heat Pump, Soil Moisture
- [ ] Delegate pattern dla złożonych klastrów (Mode, OperationalState)
- [ ] Energy management clusters
- [ ] Enhanced closures (Matter 1.5)

### Faza 4: Zaawansowane (8-12 tygodni)

**Cel:** Matter 1.5+, edge cases, certyfikacja.

- [ ] Typy urządzeń P3: Camera, HRAP, Media players
- [ ] Enhanced Multi-Admin
- [ ] Thread 1.4 features (jeśli obsługiwane przez ESP-IDF)
- [ ] NFC onboarding
- [ ] Certyfikacja CSA (opcjonalna, wymaga członkostwa)
- [ ] Long-term stability testing
- [ ] Performance optimization

---

## 12. Znane ograniczenia i ryzyka

### 12.1 Ograniczenia fundamentalne

1. **Rozmiar firmware** — firmware µMatter będzie 2-3x większy niż standardowy MicroPython. Na 4 MB flash zostanie mało miejsca na pliki użytkownika. Rekomendowane 8+ MB.

2. **Platformy bez PSRAM (ESP32-C3, C6, C5)** — te SoC nie posiadają interfejsu PSRAM. Na nich użytkownik dysponuje ~60-80 KB heapu po komisjonowaniu. Wystarczy na proste urządzenia (1-2 endpointy, kilka klastrów). Dla tych platform generowany jest automatycznie profil "Lite" z ograniczonym zestawem klastrów. Platformy z PSRAM (ESP32-WROVER, ESP32-S3) — będące standardem rynkowym — nie mają tych ograniczeń.

3. **Czas budowania** — pełny build (MicroPython + Matter SDK + esp-matter) zajmuje 15-30 minut. ccache jest konieczny.

4. **Brak hot-reload** — w przeciwieństwie do standardowego MicroPython, zmiany w konfiguracji Matter (typy urządzeń, klastry) wymagają przeflashowania firmware (bo model danych jest tworzony w C). Jedynie logika biznesowa (callbacki, odczyt sensorów) może być zmieniana w runtime.

5. **Certyfikacja** — bez certyfikacji CSA urządzenia działają tylko w trybie developerskim. Certyfikacja wymaga członkostwa w CSA (~7000 USD/rok) i opłat certyfikacyjnych.

### 12.2 Ryzyka projektowe

| Ryzyko | Prawdopodobieństwo | Wpływ | Mitygacja |
|--------|:---:|:---:|-----------|
| CMake nie daje się pogodzić | Średnie | Krytyczny | PoC w Fazie 0; alternatywa: prebuild esp-matter jako static lib |
| Ciasny DRAM na C3/C6/C5 (brak PSRAM) | Średnie | Średni | Profil "Lite" z selektywną kompilacją; alokator PSRAM-first z fallbackiem; agresywna optymalizacja sdkconfig |
| Niestabilność (crash/reboot) | Średnie | Wysoki | Extensive soak testing; watchdog; crash reporting |
| Zmiany w esp-matter API | Niskie | Średni | Pinowanie wersji; abstrakcja w binding layer |
| Matter 1.5+ łamie kompatybilność | Niskie | Niski | Matter SDK jest backward-compatible by design |
| Brak zainteresowania community | Średnie | Średni | Aktywny marketing; good docs; examples repo |

---

## 13. Estymacja kosztów i zasobów

### 13.1 Zespół

| Rola | Ilość | Kompetencje |
|------|:---:|-------------|
| Lead Developer (C/C++) | 1 | ESP-IDF, Matter SDK, MicroPython internals, CMake |
| Python Developer | 1 | MicroPython, API design, dokumentacja |
| Hardware/QA Engineer | 1 | Testowanie na wielu platformach, certyfikacja |
| DevOps | 0.5 | CI/CD, Docker, firmware distribution |

### 13.2 Timeline

| Faza | Czas | Kamień milowy |
|------|------|---------------|
| Faza 0 (PoC) | 2-2.5 miesiąca | Pierwsza lampa Matter z MicroPython |
| Faza 1 (MVP) | 3-4 miesiące | Beta release z 10 typami urządzeń |
| Faza 2 (Kompletność) | 3-4 miesiące | Stabilny release 1.0 |
| Faza 3 (AGD/Energia) | 2.5-3.5 miesiąca | Release 1.1 z pełnym Matter 1.4 |
| Faza 4 (Zaawansowane) | 2-3 miesiące | Release 2.0 z Matter 1.5 |
| **Suma** | **~13-17 miesięcy** | Kompletna biblioteka |

---

## 14. Struktura repozytorium i dokumentacji

```
umatter/
├── README.md                    # Główny README z Quick Start
├── LICENSE                      # Apache 2.0
├── docs/
│   ├── getting-started.md       # Instalacja i pierwszy projekt
│   ├── api-reference/           # Pełna dokumentacja API
│   ├── device-types.md          # Lista typów urządzeń + przykłady
│   ├── clusters.md              # Dokumentacja klastrów
│   ├── transport.md             # WiFi vs Thread
│   ├── commissioning.md         # Przewodnik komisjonowania
│   ├── bridge.md                # Tworzenie bridge'y
│   ├── custom-clusters.md       # Niestandardowe klastry
│   ├── optimization.md          # Optymalizacja RAM/Flash
│   ├── building.md              # Budowanie firmware
│   ├── troubleshooting.md       # Rozwiązywanie problemów
│   └── certification.md         # Ścieżka do certyfikacji
├── examples/
│   ├── simple_light/            # Najprostszy przykład
│   ├── dimmable_light/
│   ├── color_light/
│   ├── temperature_sensor/
│   ├── contact_sensor/
│   ├── smart_plug/
│   ├── door_lock/
│   ├── thermostat/
│   ├── window_covering/
│   ├── multi_endpoint/          # Wiele urządzeń na jednym node
│   ├── bridge/                  # Matter bridge
│   ├── thread_sensor/           # Sensor na Thread (C6)
│   ├── weather_station/         # Zaawansowany przykład
│   └── custom_cluster/          # Niestandardowy klaster
├── firmware/                    # Pre-built firmware images
│   ├── esp32s3-full/
│   ├── esp32c6-thread/
│   └── esp32c3-lite/
├── tools/
│   ├── firmware_builder/        # Webowy konfigurator
│   └── flash.py                 # Uproszczony skrypt flashowania
└── tests/
    ├── unit/
    ├── integration/
    └── hardware/
```

---

## 15. Podsumowanie

Projekt µMatter jest ambitny, ale wykonalny. Kluczowe czynniki sukcesu:

1. **Faza 0 (PoC) jest kluczowa** — jeśli integracja CMake i profil pamięci się zgadzają, reszta to kwestia czasu i wysiłku.

2. **PSRAM jest standardem** — współczesne moduły ESP32/ESP32-S3 praktycznie zawsze mają PSRAM. Strategia PSRAM-first z fallbackiem do DRAM oznacza, że typowy użytkownik ma 2-4 MB heapu Pythona. Platformy bez PSRAM (C3, C6, C5) działają z ograniczonym profilem, ale nadal są w pełni funkcjonalne dla prostych urządzeń.

3. **esp-matter SDK to solidny fundament** — nie trzeba implementować Matter od zera. Wrapper wokół istniejącego C++ API to realistyczne podejście.

4. **Dwupoziomowe API (prosty + zaawansowany)** — pozwala dotrzeć do szerokiego grona użytkowników, od hobbyistów po profesjonalistów.

5. **Nikt tego jeszcze nie zrobił** — mimo prób, nie istnieje działająca biblioteka MicroPython+Matter. To szansa na bycie pierwszym.

Całkowity koszt realizacji to ~13-17 miesięcy pracy zespołu 2-3 osobowego, z pierwszym użytecznym release'em (MVP) po ~5-6 miesiącach.