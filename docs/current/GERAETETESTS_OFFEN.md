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
| 0698c8f, 61f0545 | Läuft von selbst: Windows zählt testantrag911-2-Nachfolger nach Frist + Nachfrist (≈ 7,5 Tage) selbst aus | Gleiches Ergebnis wie auf dem Handy; kein `[TALLY-MISMATCH]`. Hinweis: `[GOV-AUTH] kind=31013 … rejected` ist normal, sobald ein Gerät schon selbst ausgezählt hat |
| 2d346db | Optional: Antrag mit Optionen (Einzelauswahl); auf einem Gerät kurz vor der Auszählung das Netz trennen, danach wieder verbinden | Log zeigt `[RETRY] SUCCESS`; das andere Gerät meldet kein `[TALLY-MISMATCH]` |
| 5fd72b5 | Optional, aufwendig: einem Gerät fehlen Stimmen (offline bis nach der eigenen Auszählung) | Oranger Hinweis „… meldet ein anderes Ergebnis“, ⚠️-Eintrag in der Historie |
| 4f1a73c | Optional, mit drittem Gerät: App frisch installieren, Zelle beitreten, abstimmen, auszählen | Kein `DatabaseException` im Log; Ergebnis wird angezeigt |

## Erledigt

| Commit | Geprüft am | Ergebnis |
|---|---|---|
| 2158ca3, 5bccb33 | 09.11.2026 | Identitätsnachweis, Austritt, Neustart, Wiederbeitritt, Entfernen, Antrag, Abstimmung, Delegation, Auflösung in Ordnung |
| 5f23cc2, 4f1a73c | 09.11.2026 | Handy migriert bis v28 (`[DB-MIGRATION-28]`), Windows-DB steht auf v28 mit neuer Spalte; Daten vollständig |
| 63556cb, f38d5a2, a728672 | 09.11.2026 | Keine Überläufe (Windows schmal/breit, Handy-Startseite); Admin-Bereich nur auf dem Handy |
| ef7f637 | 09.11.2026 | Beitritt zu „test911“ mit Windows-Neustart: Bestätigung nach dem Start angenommen, Zelle unter „Meine Zellen“ |
| 2a20285, 2c13a29 | 09.11.2026 | `[TALLY-SNAPSHOT]` 2 auf beiden Geräten, keine Abweichung; Delegation angekommen, kein `setState()`-Fehler |
| 2a20285, 5f23cc2 | 09.11.2026 | Handy: angenommen, „2 Stimmen von 2 Stimmberechtigten“ (Delegation gezählt). Windows: Fremdprotokoll korrekt abgelehnt, aber Statuswechsel übernommen → TD-76 gefunden |
| 3462048 | 09.11.2026 | Durchgang 4 wiederholt: Windows lehnt „beendet/entschieden“ (`kind=31010`) und das Protokoll (`kind=31013`) des Handys ab, Abstimmung läuft dort weiter; Handy zählt aus. Dabei TD-77 gefunden |
| e5e2292 | 09.11.2026 | Neustart beider Apps: kein `DECIDED → VOTING` mehr; alte Antrags-Events werden mit `[GOV-AUTH] kind=31010 … rejected` abgelehnt |
