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
| 46aceec | Optional: Windows offline (WLAN aus), dem Handy eine Nachricht schreiben (bleibt in der Warteschlange); auf dem Handy derweil eine neuere Nachricht von jemand anderem empfangen und die App schließen; Windows wieder online, dann Handy-App starten | Die nachgereichte Nachricht von Windows erscheint auf dem Handy; Log `[SYNC] DMs and channels fetched with 7 days overlap` |
| 208fa71 | Zwei Geräte derselben Identität: Kontakt auf Gerät 2 löschen, kurz danach auf Gerät 1 die Vertrauensstufe dieses Kontakts ändern; Gerät 1 neu starten | Der Kontakt bleibt auf Gerät 1 erhalten, auch nach dem Neustart, samt Notiz; auf Gerät 2 kommt er zurück |
| 0f43b2f | Optional, braucht drei Identitäten: Handy gründet eine Gemeinschaft und ernennt Windows zum Moderator; ein drittes Gerät stellt eine Beitrittsanfrage, **Windows** bestätigt | Das dritte Gerät nimmt die Bestätigung an (Log `[ROSTER] Applicant roster …`, danach „Membership confirmed“) und sieht sofort alle Mitglieder |
| 33026b9 | Auf Gerät 2 einen Kontakt löschen, danach Gerät 1 neu starten | Der Kontakt ist auch auf Gerät 1 weg und kommt nicht zurück |
| c26511b | Neues Gerät nach dem Seed-Restore | **Fehlgeschlagen am 12.11.2026 (Laptop2):** Nur Nachrichten der letzten Stunden erscheinen. Ältere liegen nachweislich noch auf den Relays (eigenes Relay ab 11.11., nos.lol ab 07.11.). Verdacht: Sie kommen beim Start an, bevor die Kontakte da sind. Zur Diagnose fehlt ein Log vom Release-Build (Protokoll-Schalter geplant); vorerst zurückgestellt |
| 43bb68c | Backup-Datei vom alten Gerät (Einstellungen → Backup exportieren) auf das neue kopieren und auswählen | Kontakte, Kanäle, Gemeinschaften übernommen; „Dein Name: …“ auf dem Erfolgsbildschirm |
| 43bb68c | Eine fremde oder beschädigte `.enc`-Datei auswählen | Meldung „… lässt sich mit deiner Seed Phrase nicht öffnen …“, nichts wird übernommen |
| 0698c8f, 61f0545 | Läuft von selbst: Windows zählt testantrag911-2-Nachfolger nach Frist + Nachfrist (≈ 7,5 Tage) selbst aus | Gleiches Ergebnis wie auf dem Handy; kein `[TALLY-MISMATCH]`. Hinweis: `[GOV-AUTH] kind=31013 … rejected` ist normal, sobald ein Gerät schon selbst ausgezählt hat |
| 2d346db | Optional: Antrag mit Optionen (Einzelauswahl); auf einem Gerät kurz vor der Auszählung das Netz trennen, danach wieder verbinden | Log zeigt `[RETRY] SUCCESS`; das andere Gerät meldet kein `[TALLY-MISMATCH]` |
| 5fd72b5 | Optional, aufwendig: einem Gerät fehlen Stimmen (offline bis nach der eigenen Auszählung) | Oranger Hinweis „… meldet ein anderes Ergebnis“, ⚠️-Eintrag in der Historie |
| 4f1a73c | Optional, mit drittem Gerät: App frisch installieren, Zelle beitreten, abstimmen, auszählen | Kein `DatabaseException` im Log; Ergebnis wird angezeigt |

## Erledigt

| Commit | Geprüft am | Ergebnis |
|---|---|---|
| a6dbd7e | 12.11.2026 | Drei Standard-Relays verbunden; eigenes Relay übersteht den Neustart und lässt sich entfernen; eine Benachrichtigung im Hintergrund |
| 0f43b2f | 12.11.2026 | Gründer-Übergabe Handy → Windows, auch mit Flugmodus (Bedienung versteckt: Zahnrad, lange drücken) |
| 39b5106, dc5cab8, 950171c | 12.11.2026 | Superadmin löscht fremde Gemeinschaft ohne Beitritt, sie verschwindet auch auf Windows (vorher Fehler, behoben) |
| 43bb68c, 33026b9 | 12.11.2026 | Laptop2 per Seed ohne Backup: Bildschirm „Kein Backup“, richtiger Name, Kontakte kommen von selbst |
| c26511b, 33026b9 | 12.11.2026 | Nachricht von Laptop2 erscheint auf Laptop1 als eigene; Vertrauensstufe wandert zwischen Laptop2 und Laptop1 |
| 2158ca3, 5bccb33 | 09.11.2026 | Identitätsnachweis, Austritt, Neustart, Wiederbeitritt, Entfernen, Antrag, Abstimmung, Delegation, Auflösung in Ordnung |
| 5f23cc2, 4f1a73c | 09.11.2026 | Handy migriert bis v28 (`[DB-MIGRATION-28]`), Windows-DB steht auf v28 mit neuer Spalte; Daten vollständig |
| 63556cb, f38d5a2, a728672 | 09.11.2026 | Keine Überläufe (Windows schmal/breit, Handy-Startseite); Admin-Bereich nur auf dem Handy |
| ef7f637 | 09.11.2026 | Beitritt zu „test911“ mit Windows-Neustart: Bestätigung nach dem Start angenommen, Zelle unter „Meine Zellen“ |
| 2a20285, 2c13a29 | 09.11.2026 | `[TALLY-SNAPSHOT]` 2 auf beiden Geräten, keine Abweichung; Delegation angekommen, kein `setState()`-Fehler |
| 2a20285, 5f23cc2 | 09.11.2026 | Handy: angenommen, „2 Stimmen von 2 Stimmberechtigten“ (Delegation gezählt). Windows: Fremdprotokoll korrekt abgelehnt, aber Statuswechsel übernommen → TD-76 gefunden |
| 3462048 | 09.11.2026 | Durchgang 4 wiederholt: Windows lehnt „beendet/entschieden“ (`kind=31010`) und das Protokoll (`kind=31013`) des Handys ab, Abstimmung läuft dort weiter; Handy zählt aus. Dabei TD-77 gefunden |
| e5e2292 | 09.11.2026 | Neustart beider Apps: kein `DECIDED → VOTING` mehr; alte Antrags-Events werden mit `[GOV-AUTH] kind=31010 … rejected` abgelehnt |
| 1162510, 2398096, d990268 | 10.11.2026 | Antrags-Knopf in der Zelle für Windows sichtbar; Delegation erscheint ohne Seitenwechsel; Handy veröffentlicht Kind-31007, Windows übernimmt („Applied roster … 2 members“, auch 6 Mitglieder in einer weiteren Zelle); Moderator-Ernennung kommt auf Windows an |
| 39b5106 | 10.11.2026 | Windows als Gründer und letztes Mitglied: „Gemeinschaft löschen“ sichtbar, Testzelle811 mit Identitätsnachweis aufgelöst. Die alte Superadmin-Löschung vom Handy kam nicht von selbst an (offen: Superadmin löscht eine fremde Zelle) |
