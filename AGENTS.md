# AGENTS.md - uMatter

Ten plik definiuje komplet agentow roboczych dla projektu uMatter (MicroPython + Matter + ESP32).
Uzywaj tych agentow jako stalych rol wykonawczych podczas budowy projektu od PoC do release.

## Dokumenty zrodlowe

1. `docs/ROADMAP.md` - publiczny zakres, status faz i kryteria akceptacji.
2. `mp_skill.md` - workflow build/flash/test (WSL + PowerShell).
3. `agents/*.md` - kontrakty wykonawcze agentow.
4. `docs/ARCHITECTURE.md` - aktualny model architektury.

Kontrakty rol sa dostepne w `agents/`; nie wymagaja katalogu konkretnego
uzytkownika. Nazwy skilli wymienione w kontraktach oznaczaja opcjonalne narzedzia
lokalne, a nie pliki dostarczone z repozytorium. Korzystaj z nich tylko wtedy,
gdy sa faktycznie zainstalowane. W przeciwnym razie stosuj `mp_skill.md` oraz
dokumentacje projektu i jawnie raportuj ograniczenia walidacji.

## Szybki Start

1. Zacznij od `agents/00-orchestrator.md`.
2. Wybierz faze i gate z `docs/ROADMAP.md`.
3. Deleguj zadania do agentow domenowych.
4. Zbieraj artefakty i status do jednego raportu fazy.

## Kolejnosc realizacji faz

1. Faza 0: PoC
2. Faza 1: MVP
3. Faza 2: Kompletnosc
4. Faza 3: AGD i Energia
5. Faza 4: Zaawansowane i release 2.x

## Mapa agentow

1. `agents/00-orchestrator.md` - koordynacja calosci i acceptance gate.
2. `agents/01-build-flash.md` - build, flash, deploy testowy.
3. `agents/02-cmake-integration.md` - integracja MicroPython + ESP-IDF + esp-matter.
4. `agents/03-core-binding-cpp.md` - binding C/C++ i granica runtime.
5. `agents/04-python-api.md` - API Python, device types, clusters.
6. `agents/05-memory-psram.md` - profile pamieci i limity.
7. `agents/06-runtime-event-queue.md` - wielowatkowosc i event queue.
8. `agents/07-thread-commissioning.md` - Thread i commissioning.
9. `agents/08-bridge-custom-clusters.md` - bridge i custom clusters.
10. `agents/09-test-certification.md` - test matrix, soak, interoperacyjnosc.
11. `agents/10-release-ci.md` - dystrybucja firmware i CI release.

## Definition of Done - poziom projektu

1. Build i flash dzialaja dla docelowych boardow i profili.
2. API proste i zaawansowane ma stabilne kontrakty.
3. Pamiec miesci sie w limitach PSRAM i no-PSRAM.
4. Commissioning przechodzi end-to-end na realnym firmware; wynik mocka lub
   referencyjnego virtual device nie zamyka tego gate.
5. Test matrix ma udokumentowane wyniki i ryzyka.
6. Artefakty release sa reprodukowalne i maja zweryfikowane sumy kontrolne.

To sa kryteria zakonczenia projektu, nie deklaracja obecnej gotowosci. Aktualna
Faza 0 i otwarty gate discovery/commissioning sa opisane w `docs/ROADMAP.md`.

## Standard raportowania

Kazdy agent raportuje:

1. Zakres i decyzje.
2. Zmienione pliki.
3. Wyniki walidacji.
4. Ryzyka i blocker.
5. Nastepny krok dla kolejnego agenta.

## Maintainer identity

Follow the authorship policy in CONTRIBUTING.md. Maintainer-owned commits use
`Mateusz Sury <66475105+mateuszsury@users.noreply.github.com>`.
Do not add AI author/co-author or generated-by attribution. Preserve genuine
upstream/human/bot commit authors, copyright notices and licenses. Configure Git
locally before committing; do not rewrite release tags or published checksums.
