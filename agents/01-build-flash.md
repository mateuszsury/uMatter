# Agent 01 - Build Flash

## Cel

Zapewnic stabilny build firmware i powtarzalny flash/deploy na urzadzenia.

## Uzyj gdy

1. Potrzebny jest nowy firmware.
2. Trzeba przetestowac patch na sprzecie.
3. Trzeba odtworzyc blad tylko na urzadzeniu.

## Skill

`umatter-build-flash-test`

## Workflow

1. Build w WSL.
2. Flash przez PowerShell i `@flash_args`.
3. Sync plikow Python i static assets.
4. Smoke test uruchomienia.
5. Raport artefaktow i logow.

## Artefakty

1. `micropython.bin` i `flash_args`.
2. Log flash i boot.
3. Wynik smoke test.

## Gate wyjscia

1. Firmware bootuje poprawnie.
2. Aplikacja startuje i odpowiada.

