# MicroPython Firmware Workflow (WSL + PowerShell)

Ten dokument opisuje uniwersalny proces pracy z firmware MicroPython dla plytek embedded, niezaleznie od konkretnego projektu aplikacyjnego.

## 1. Cel i podzial srodowisk

Najstabilniejszy model pracy:

1. `WSL (Linux)`:
- pobranie i aktualizacja zrodel MicroPython
- przygotowanie toolchainu ESP-IDF
- kompilacja firmware
2. `PowerShell (Windows)`:
- flash firmware przez port `COMx`
- upload plikow aplikacji na urzadzenie
- uruchamianie testow i benchmarkow po IP

Powod: build jest wygodniejszy i przewidywalny w Linux, a port szeregowy `COMx` zwykle najprosciej obslugiwac po stronie Windows.

## 2. Narzedzia

Minimalny zestaw:

1. `git`
2. `python` (host)
3. `esptool` (`python -m esptool`)
4. `mpremote` (`python -m mpremote`)
5. `WSL` + `bash`
6. `ESP-IDF` z dzialajacym `idf.py` w WSL
7. `make` lub `cmake/ninja` (zaleznie od portu)

## 3. Pobranie zrodel MicroPython

W WSL:

```bash
git clone https://github.com/micropython/micropython.git
cd micropython
git checkout <tag_lub_commit>
git submodule update --init --recursive
```

Jesli uzywasz forka, ustaw `origin` na fork i utrzymuj `upstream` do oficjalnego repo.

## 4. Wybor plytki i konfiguracji

Wybierz board definiujacy pamiec, flash i peryferia:

1. Dla ESP32: `ports/esp32/boards/<BOARD_NAME>`
2. Sprawdz:
- docelowy `IDF_TARGET`
- rozmiar flash
- ustawienia PSRAM
- partycje
- manifest modulow mrozonych (frozen modules), jesli uzywane

Jezeli masz wlasny modul C:

1. Dodaj go przez mechanizm `USER_C_MODULES`.
2. Upewnij sie, ze ma poprawny plik CMake/Make oraz include paths.

## 5. Build firmware (WSL)

Typowy przeplyw dla ESP32:

```bash
cd micropython
make -C mpy-cross
make -C ports/esp32 submodules BOARD=<BOARD_NAME>
make -C ports/esp32 BOARD=<BOARD_NAME> USER_C_MODULES=<sciezka_do_modulu_c>
```

Wymagania:

1. `IDF_PATH` wskazuje poprawna instalacje ESP-IDF.
2. `idf.py --version` dziala w tej samej sesji shell.
3. Narzedzia ESP-IDF sa zaladowane (`export.sh`).

Wyniki builda:

1. `build-<BOARD_NAME>/micropython.bin`
2. `build-<BOARD_NAME>/flash_args`
3. dodatkowe binarki bootloadera i partycji

## 6. Flash firmware (PowerShell)

W Windows, z katalogu build:

```powershell
python -m esptool --chip <chip> -p <COM_PORT> -b 460800 --before default_reset --after hard_reset write_flash "@flash_args"
```

Dlaczego `@flash_args`:

1. Uzywa dokladnych offsetow i binarek wygenerowanych przez build.
2. Zmniejsza ryzyko bledow recznego mapowania adresow.

## 7. Upload plikow aplikacji na urzadzenie

Po flashu firmware zwykle trzeba wgrac pliki Python i zasoby.

Przyklady:

```powershell
python -m mpremote connect <COM_PORT> fs cp <lokalny_plik.py> :/<plik.py>
python -m mpremote connect <COM_PORT> fs cp -r <lokalny_katalog> :/
python -m mpremote connect <COM_PORT> fs rm -r :/<katalog_docelowy>
```

Dobre praktyki:

1. Najpierw usun stary katalog zasobow na urzadzeniu.
2. Wgraj calosc od nowa, aby uniknac starych plikow.
3. Jesli masz kompresje statykow, uruchom ja na urzadzeniu po synchronizacji.

## 8. Start aplikacji i weryfikacja

Uruchamianie:

```powershell
python -m mpremote connect <COM_PORT> run <lokalny_skrypt_startowy.py>
```

Szybka diagnostyka:

```powershell
python -m mpremote connect <COM_PORT> exec "print('ok')"
python -m mpremote connect <COM_PORT> exec "import network; print(network)"
```

Weryfikuj:

1. Czy interfejs sieciowy ma poprawne IP.
2. Czy serwer odpowiada HTTP/WS.
3. Czy logi nie pokazuja timeoutow, restartow, bledow pamieci.

## 9. Testy i benchmark

Rekomendowany porzadek:

1. Testy funkcjonalne (smoke, endpointy krytyczne).
2. Testy stabilnosci (dluzszy run).
3. Benchmark (latencja p50/p95/p99, error rate, throughput).
4. Porownanie konfiguracji na identycznym kodzie aplikacji.

Aby porownanie bylo miarodajne:

1. Zmieniaj tylko jeden wymiar naraz (np. transport sieciowy).
2. Utrzymuj identyczna konfiguracje runtime i ten sam zestaw endpointow.
3. Wykonuj co najmniej kilka powtorzen.

## 10. Najczestsze problemy

1. `COM port busy`:
- zamknij stare procesy `mpremote/python` trzymajace port
2. `idf.py` nie dziala w WSL:
- sprawdz `IDF_PATH`, aktywacje srodowiska i zaleznosci
3. Flash przechodzi, ale aplikacja nie dziala:
- sprawdz, czy wgrano pliki Python/zasoby po flashu
4. Niestabilne wyniki benchmarku:
- obniz chwilowo obciazenie, ustal punkt pracy, dopiero potem zwiekszaj

## 11. Minimalny checklist operacyjny

1. Zaktualizowane zrodla MicroPython i submodule.
2. Poprawny board/target.
3. Build zakonczony bez bledow.
4. Flash z `@flash_args`.
5. Upload plikow aplikacji i zasobow.
6. Start aplikacji i odczyt IP.
7. Testy funkcjonalne.
8. Testy obciazeniowe i raport.
