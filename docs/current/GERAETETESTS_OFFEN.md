# Offene Gerätetests (Android ↔ Windows)

Gesammelte Gerätetests für Änderungen, die schon committet, aber noch nicht
auf beiden Geräten geprüft sind. Joachim testet gebündelt. Nach dem Test
abhaken, dann pushen und den PR erstellen.

**Rollen:** Handy (`R58MA3VVQ1W`) ist Superadmin. Windows ist ein normaler
Testnutzer ohne Adminrechte.

**Start mit Log-Datei** (PowerShell, nur ein Windows-Fenster gleichzeitig,
beenden mit `q`):

```powershell
flutter run -d windows > test-batch-windows.txt 2>&1
```

```powershell
flutter run -d R58MA3VVQ1W > test-batch-android.txt 2>&1
```

Beide Geräte müssen auf demselben Stand laufen, weil die Prüfungen aus
TD-40 auf beiden Seiten den Identitätsnachweis brauchen.

## Offen

| Commit | Was prüfen | Erwartung |
|---|---|---|
| 2c13a29 | Auf dem Handy in einer laufenden Abstimmung die Stimme an Windows delegieren | Im Handy-Log kein `setState()`-Fehler |
| a728672 | Gemeinschaften-Bildschirm auf beiden Geräten nach unten scrollen | Handy zeigt „Weitere lokale Gemeinschaften (Admin, …)“, Windows zeigt diesen Bereich nicht |
| ef7f637 | Auf dem Handy einer Zelle beitreten, die Windows gegründet hat; auf Windows bestätigen | Zelle erscheint auf dem Handy unter „Meine Zellen“; im Log kein `[CELL-AUTH] Membership confirmation rejected` |
| ef7f637 | Handy-App beenden, während eine Beitrittsanfrage offen ist; auf Windows bestätigen; Handy neu starten | Zelle erscheint nach dem Start trotzdem unter „Meine Zellen“ |
| 61f0545 | Antrag mit kurzer Abstimmungsfrist anlegen, beide stimmen ab; ein Gerät während des Fristendes geschlossen lassen und danach starten | Beide Geräte zeigen dasselbe Ergebnis; im Log kein `[GOV-AUTH] kind=31013 … rejected` |

## Erledigt

| Commit | Geprüft am | Ergebnis |
|---|---|---|
| 2158ca3, 5bccb33 | 09.11.2026 | Identitätsnachweis, Austritt, Neustart, Wiederbeitritt, Entfernen, Antrag, Abstimmung, Delegation, Auflösung in Ordnung |
