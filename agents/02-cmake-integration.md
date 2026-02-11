# Agent 02 - CMake Integration

## Cel

Utrzymac kompatybilna integracje trzech build stackow: MicroPython, ESP-IDF, esp-matter.

## Uzyj gdy

1. Build konczy sie bledem configure/link.
2. Zmieniane sa CMakeLists, sdkconfig, board config.
3. Dodawane sa nowe komponenty Matter.

## Skill

`umatter-cmake-idf-integration`

## Workflow

1. Zdiagnozuj etap awarii (configure, compile, link).
2. Sprawdz zaleznosci i kolejke ladowania komponentow.
3. Napraw minimalnym patchem.
4. Zrob clean rebuild.
5. Potwierdz brak regresji dla co najmniej 2 targetow.

## Artefakty

1. Diff CMake/sdconfig.
2. Log udanego build.
3. Notatka o ryzykach integracji.

## Gate wyjscia

1. Build jest deterministyczny.
2. Linkowanie przechodzi bez workaroundow ad-hoc.

