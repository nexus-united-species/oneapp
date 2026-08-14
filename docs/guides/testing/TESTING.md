# Aktuelle Testanleitung

Stand: 15. Juli 2026

## Sicherheitsregeln

- Niemals `flutter clean`, `adb uninstall` oder `flutter install` als
  Standardmaßnahme verwenden. Diese Befehle können lokale Alpha-Daten oder
  ungesicherte Identitäten zerstören.
- Vor Tests mit echten Identitäten ein App-Backup erstellen.
- Für Cross-Device-Tests zwei getrennte Testidentitäten verwenden, sofern nicht
  ausdrücklich ein Same-Seed-Szenario geprüft wird.

## Vorbereitung

```powershell
flutter pub get
flutter analyze
```

`flutter analyze` hat am 15. Juli 2026 eine Baseline von 947 Meldungen. Neue
Änderungen dürfen diese Baseline nicht unbemerkt verschlechtern; kritische
Fehler in den geänderten Dateien werden vor dem Gerätetest behoben.

## Automatische Tests

```powershell
# Governance – bekannte grüne Baseline: 596/596
flutter test test/features/governance

# Vollständiger Lauf – derzeit nicht vollständig grün
flutter test
```

Bei einem Fehler immer den konkreten Testnamen und die erste relevante
Fehlermeldung dokumentieren. Ein roter Gesamtstatus darf nicht pauschal als
„Bestand“ abgetan werden.

## Android und Windows starten

```powershell
# Android
flutter run

# Windows
flutter run -d windows
```

Wenn Joachim nicht live im Terminal mitliest, Logs in eine Datei schreiben:

```powershell
flutter run *> test-android.txt
flutter run -d windows *> test-windows.txt
```

## Pflichtmatrix für Sync-Änderungen

| Test | Gerät A | Gerät B | Erwartung |
|---|---|---|---|
| Direktnachricht | Android sendet | Windows empfängt | Inhalt einmalig und lesbar |
| Reaktion | Android reagiert | Windows synchronisiert | identisches Emoji, Relay akzeptiert Event |
| Löschen | Windows löscht eigene Nachricht | Android synchronisiert | kein Wiederauftauchen nach Neustart |
| Abstimmungsstart | Gerät A startet | Gerät B empfängt | gleicher Status und gleicher `eligibleVoters`-Snapshot |
| Delegation | A delegiert/widerruft | B empfängt | gleicher aktiver Zustand |
| Finalisierung | beide online | beide vergleichen | gleicher Decision Record und gleicher Hash |
| Retry | Erstversand ohne Relay, dann Reconnect | anderes Gerät empfängt | vollständiger, identischer Record |

## Bekannte Baseline

- Governance: 596 Tests bestanden.
- Geprüfte Navigation-/Dashboard-Auswahl: 54 bestanden, 11 fehlgeschlagen.
- Ein realer Desktop-Overflow von 30 Pixeln ist bekannt.
- Mehrere weitere Fehler stammen wahrscheinlich aus veralteten Text- und
  Label-Erwartungen und müssen einzeln geprüft werden.
- `open_file` meldet eine macOS-Plugin-Registrierungswarnung; Android und
  Windows bleiben die aktuellen Zielplattformen.

## Historische Anleitung

Der frühere reine LAN-Chat-Test bleibt unter
[legacy-chat-test.md](legacy-chat-test.md) erhalten. Bei Widersprüchen gilt
diese aktuelle Anleitung.

