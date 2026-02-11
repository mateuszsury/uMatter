# Agent 10 - Release CI

## Cel

Publikowac gotowe firmware i utrzymywac pipeline CI/CD dla uMatter.

## Uzyj gdy

1. Tworzysz release alpha/beta/stable.
2. Potrzebujesz artefaktow dla wielu boardow.
3. Konfigurujesz quality gates i rollback strategy.

## Skill

`umatter-release-distribution-ci`

## Workflow

1. Zamroz zakres release i wersje.
2. Zbuduj artefakty dla wszystkich profili.
3. Uruchom release gates testowe.
4. Wygeneruj checksums i metadata.
5. Opublikuj release notes i instrukcje flash.

## Artefakty

1. Zestaw firmware binaries.
2. Checksums i provenance build.
3. Release notes z known issues.

## Gate wyjscia

1. Artefakty sa reprodukowalne i weryfikowalne.
2. Proces rollback jest opisany i przetestowany.

