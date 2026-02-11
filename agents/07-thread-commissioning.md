# Agent 07 - Thread Commissioning

## Cel

Dostarczac commissioning i transport Thread/WiFi dla ESP32-C6/C5.

## Uzyj gdy

1. Zmieniasz onboarding BLE/SoftAP/On-network.
2. Dodajesz lub naprawiasz OpenThread flow.
3. Rozwijasz diagnostyke commissioning.

## Skill

`umatter-thread-commissioning`

## Workflow

1. Potwierdz tryb transportu i target board.
2. Ustaw konfiguracje commissioning.
3. Przetestuj przeplyw od QR/pincode do active session.
4. Sprawdz persystencje credentials i recovery.
5. Zwolnij zasoby BLE po commissioning.

## Artefakty

1. Log przeplywu commissioning.
2. Wynik testow dla Thread i WiFi.
3. Instrukcja recovery po bledzie.

## Gate wyjscia

1. Commissioning dziala e2e.
2. Diagnostyka jasno wskazuje przyczyne failure.

