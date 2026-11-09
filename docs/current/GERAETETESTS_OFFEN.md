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
| 2a20285 | Neuen Antrag in einer Zelle mit beiden Geräten anlegen und Abstimmung starten; danach ein drittes Konto oder neues Mitglied beitreten lassen (falls möglich) | Beide Logs zeigen `[TALLY-SNAPSHOT]` mit derselben Anzahl; Anzeige „x von N“ gleich auf beiden Geräten; Stimme eines später Beigetretenen zählt nicht |
| 0698c8f | Mit dem Knopf „Force beenden“ in einem Antrag auf einem Gerät auszählen; das andere Gerät normal laufen lassen | Auf dem zweiten Gerät erscheint `[TALLY-LOCAL]` erst nach Ablauf von Frist und Nachfrist bzw. bei eigener Auszählung; beide zeigen dasselbe Ergebnis; kein `[TALLY-MISMATCH]` |
| 5fd72b5 | Nur möglich, wenn einem Gerät Stimmen fehlen: Handy offline schalten, auf Windows abstimmen, Frist ablaufen lassen, Handy erst nach seiner eigenen Auszählung wieder online | Beim Ergebnis auf dem Handy erscheint der orange Hinweis „… meldet ein anderes Ergebnis“, in der Historie ein ⚠️-Eintrag. Optional, aufwendig |
| 2d346db | Antrag mit Optionen (Einzelauswahl) abstimmen; auf einem Gerät kurz vor der Auszählung das Netz trennen, nach der Auszählung wieder verbinden | Log zeigt `[RETRY] SUCCESS`; das andere Gerät meldet kein `[TALLY-MISMATCH]` |
| 5f23cc2 | Beim ersten Start nach dem Update | Log zeigt `[DB-MIGRATION-27]`; App startet normal; nach einer Auszählung zeigt das Ergebnis „x Stimmen von N Stimmberechtigten“ mit N = Anzahl aus `[TALLY-SNAPSHOT]` |
| 4f1a73c | Beim ersten Start nach dem Update auf beiden Geräten | Log zeigt `[DB-MIGRATION-27]` und `[DB-MIGRATION-28]`; App startet normal, Zellen, Anträge und Chats sind vollständig da |
| 4f1a73c | Optional, falls ein drittes Gerät oder Testkonto verfügbar: App frisch installieren, Zelle beitreten, abstimmen, auszählen | Kein `DatabaseException` im Log; Ergebnis wird angezeigt |
| 63556cb | Windows: Startseite öffnen, Fenster schmal ziehen (knapp über der Handy-Ansicht) und breit ziehen | Keine gelb-schwarzen Streifen an den Karten; Untertitel enden notfalls mit „…“ |
| f38d5a2 | Handy: Startseite (Zeile „Lokal: … Peers“ unter dem Radar) und Gemeinschaften als Admin (Überschrift „Weitere lokale Gemeinschaften (Admin, …)“) ansehen | Keine gelb-schwarzen Streifen; lange Überschriften brechen um |
| 61f0545 | Antrag mit kurzer Abstimmungsfrist anlegen, beide stimmen ab; ein Gerät während des Fristendes geschlossen lassen und danach starten | Beide Geräte zeigen dasselbe Ergebnis; im Log kein `[GOV-AUTH] kind=31013 … rejected` |

## Erledigt

| Commit | Geprüft am | Ergebnis |
|---|---|---|
| 2158ca3, 5bccb33 | 09.11.2026 | Identitätsnachweis, Austritt, Neustart, Wiederbeitritt, Entfernen, Antrag, Abstimmung, Delegation, Auflösung in Ordnung |
