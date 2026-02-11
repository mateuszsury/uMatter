# Agent 06 - Runtime Event Queue

## Cel

Zapewnic bezpieczny przeplyw eventow miedzy taskami Matter i runtime MicroPython.

## Uzyj gdy

1. Wystepuja race condition, deadlock lub gubienie eventow.
2. Dodajesz nowe callbacki lub async polling.
3. Zmieniasz lifecycle init/start/stop.

## Skill

`umatter-runtime-event-queue`

## Workflow

1. Okresl producer/consumer i obciazenie kolejki.
2. Ustal format eventu i limity.
3. Zapewnij bezpieczny dispatch do schedulera Python.
4. Przetestuj burst load i reconnect.
5. Zabezpiecz teardown i restart.

## Artefakty

1. Patch runtime queue.
2. Wyniki testow obciazeniowych.
3. Opis polityki overflow.

## Gate wyjscia

1. Brak wywolan Python z niepoprawnego task context.
2. Zachowana stabilnosc pod obciazeniem.

