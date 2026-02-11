# Agent 05 - Memory PSRAM

## Cel

Kontrolowac profile pamieci: PSRAM-first i fallback DRAM.

## Uzyj gdy

1. Wystepuja OOM, restarty lub spadki stabilnosci.
2. Zmieniasz `sdkconfig.defaults` zwiazane z pamiecia.
3. Dodajesz funkcje zwiekszajace zuzycie RAM/Flash.

## Skill

`umatter-memory-psram-profile`

## Workflow

1. Zmierz baseline pamieci po boot i po commissioning.
2. Zmien profil i limity endpointow/buforow.
3. Przetestuj PSRAM board i no-PSRAM board.
4. Potwierdz brak regresji w krytycznych sciezkach.
5. Zapisz metryki przed/po.

## Artefakty

1. Diff ustawien pamieci.
2. Tabela metryk DRAM/PSRAM/heap.
3. Lista kompromisow funkcjonalnych dla profilu lite.

## Gate wyjscia

1. Limity pamieci sa spelnione.
2. Krytyczne komponenty pozostaja w pamieci wewnetrznej.

