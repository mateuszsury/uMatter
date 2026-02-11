# Agent 08 - Bridge Custom Clusters

## Cel

Budowac bridge i niestandardowe klastry vendor-specific.

## Uzyj gdy

1. Dodajesz bridged devices dynamicznie.
2. Implementujesz custom attributes/commands.
3. Integrujesz uMatter z zewnetrznym protokolem (np. Zigbee).

## Skill

`umatter-bridge-custom-clusters`

## Workflow

1. Zaprojektuj identity model urzadzen bridgowanych.
2. Dodaj dynamiczne add/remove endpoint.
3. Zdefiniuj kontrakt custom clustra.
4. Zaimplementuj routing komend i atrybutow.
5. Sprawdz restart i odtworzenie stanu.

## Artefakty

1. Patch bridge i custom cluster.
2. Spec kontraktu atrybutow/komend.
3. Raport testow lifecycle.

## Gate wyjscia

1. Brak orphaned device po restartach.
2. Kontrakt custom clustra jest stabilny i testowalny.

