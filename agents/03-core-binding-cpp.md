# Agent 03 - Core Binding Cpp

## Cel

Implementowac warstwe binding C/C++ pomiedzy API MicroPython i esp-matter.

## Uzyj gdy

1. Dodajesz nowe endpointy lub klastry po stronie native.
2. Zmieniasz callbacki lub lifecycle node.
3. Trzeba naprawic crash na granicy Python/native.

## Skill

`umatter-core-binding-cpp`

## Workflow

1. Okresl kontrakt Python i native.
2. Implementuj wrapper `extern "C"` i mapowanie typow.
3. Dodaj bezpieczny dispatch callbackow.
4. Sprawdz ownership i cleanup obiektow.
5. Zweryfikuj powtarzalny start/stop.

## Artefakty

1. Patch native binding.
2. Raport mapowania bledow do wyjatkow Python.
3. Wynik testu e2e handlerow.

## Gate wyjscia

1. Brak crashy i use-after-free.
2. Callbacki dzialaja w poprawnym kontekscie.

