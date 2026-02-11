# Faza 0 - Krok 11: Hostowy commissioning smoke scaffold

## Cel

Dodac powtarzalny gate hostowy dla commissioning na etapie PoC:
1. generacja zestawu danych commissioning (passcode/discriminator),
2. automatyczny smoke po serialu na urzadzeniu,
3. artefakty PASS/FAIL do dalszego etapu z `chip-tool`.

## Co zostalo dodane

1. Nowy skrypt:
   - `scripts/phase0_step11_commissioning_smoke.ps1`
2. Skrypt wykonuje:
   - preflight portu COM i zakresow argumentow,
   - uruchomienie smoke na urzadzeniu przez serial REPL,
   - walidacje markerow commissioning + lifecycle,
   - walidacje, ze VFS jest obecny po zmianie partycji,
   - zapis artefaktow:
     - `serial_commissioning_smoke.log`
     - `commissioning_data.json`
3. Dodatkowo:
   - wykrywa dostepnosc `chip-tool`,
   - zapisuje status i note o aktualnym etapie placeholder.

## Parametry skryptu

1. `-ComPort` (domyslnie `COM11`)
2. `-DeviceName` (domyslnie `uMatter-C11`)
3. `-EndpointId` (domyslnie `1`)
4. `-Passcode` (domyslnie `20202021`)
5. `-Discriminator` (domyslnie `3840`)
6. `-WithLevelControl` (domyslnie `true`)
7. `-Baud` (domyslnie `115200`)
8. `-Instance` (domyslnie auto timestamp)
9. `-ArtifactsRoot` (domyslnie `artifacts/commissioning`)

## Uruchomienie

```powershell
& scripts/phase0_step11_commissioning_smoke.ps1 `
  -ComPort COM11 `
  -DeviceName uMatter-C11 `
  -EndpointId 4 `
  -Passcode 23456789 `
  -Discriminator 2222 `
  -Instance c11-com11-step11
```

## Kryterium zaliczenia

1. Skrypt konczy sie `Commissioning smoke: PASS`.
2. W logu sa markery:
   - `C11:COMM (<discriminator>, <passcode>)`
   - `C11:EP 1`
   - `C11:START0/1/2`
   - `C11:END`
3. `VFS_TOTAL` jest > 1 MB.
4. Powstaje `commissioning_data.json` z pelnym kontekstem uruchomienia.

## Nastepny krok

Podlaczyc realny flow commissioning:
1. integracja runtime z rzeczywistym onboardingiem Matter,
2. uruchomienie host e2e z `chip-tool` (pairing + verification),
3. zapis wyniku w macierzy testowej interoperacyjnosci.
