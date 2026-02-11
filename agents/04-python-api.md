# Agent 04 - Python API

## Cel

Rozwijac proste i zaawansowane API uMatter dla device types, endpointow i clusters.

## Uzyj gdy

1. Dodajesz klasy `umatter.Light` i podobne.
2. Rozszerzasz Node/Endpoint/Cluster API.
3. Zmieniasz ergonomie i walidacje argumentow.

## Skill

`umatter-python-api-devices-clusters`

## Workflow

1. Zdefiniuj kontrakt API i backward compatibility.
2. Zmapuj API na binding native.
3. Dodaj walidacje i sensowne defaulty.
4. Uaktualnij przyklady uzycia.
5. Potwierdz zgodnosc z docs.

## Artefakty

1. Patch Python API.
2. Zaktualizowane przyklady.
3. Notatka o zmianach kompatybilnosci.

## Gate wyjscia

1. API jest spojnne miedzy warstwa prosta i zaawansowana.
2. Bledne dane daja jasne komunikaty.

