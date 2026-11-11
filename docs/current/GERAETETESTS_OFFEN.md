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
| (TD-33 Übergabe, noch nicht committet) | Handy gründet eine Testgemeinschaft, Windows tritt bei. Handy: Mitglied Windows → „Gründerrolle übertragen“ | Windows zeigt sich nach kurzer Zeit als Gründer (Log `[FOUNDER-HANDOVER] … now led by …`); Windows kann die Gemeinschaft umbenennen, Mitglieder entfernen und auflösen; das Handy ist einfaches Mitglied und kann Windows nicht entfernen |
| (TD-33 Übergabe) | Wie oben, aber Handy vor dem Übertragen in den Flugmodus, übertragen, dann wieder online | Die Übergabe kommt trotzdem auf Windows an (Log `Re-sent handover roster`), danach `successor confirmed` auf dem Handy |
| (TD-33 Bewerber, noch nicht committet) | Optional, braucht drei Identitäten: Handy gründet eine Gemeinschaft und ernennt Windows zum Moderator; ein drittes Gerät stellt eine Beitrittsanfrage, **Windows** bestätigt | Das dritte Gerät nimmt die Bestätigung an (Log `[ROSTER] Applicant roster …`, danach „Membership confirmed“) und sieht sofort alle Mitglieder |
| 33026b9 | Zwei Geräte derselben Identität: auf Gerät 1 einen Kontakt hinzufügen bzw. Vertrauensstufe ändern, 1 Minute warten | Auf Gerät 2 erscheint der Kontakt bzw. die neue Stufe, Name und Bild folgen über das Profil; Log `[CONTACT-SYNC] Merged: +1 …` |
| 33026b9 | Auf Gerät 2 einen Kontakt löschen, danach Gerät 1 neu starten | Der Kontakt ist auch auf Gerät 1 weg und kommt nicht zurück |
| 33026b9 | Neues Gerät per Seed, **ohne** Backup | Kontakte erscheinen nach etwa einer halben Minute von selbst |
| c26511b | Nur mit zwei Geräten derselben Identität (z. B. neues Gerät aus dem Kontoumzug-Test): auf Gerät 1 einem Kontakt schreiben | Auf Gerät 2 erscheint die Nachricht im Gespräch mit diesem Kontakt als **eigene** (rechts), ohne Benachrichtigung; Log `[SYNC] Own DM …` |
| c26511b | Auf dem sendenden Gerät selbst nachsehen | Die Nachricht steht **einmal** im Gespräch, nicht doppelt |
| c26511b | Neues Gerät nach dem Seed-Restore | Gespräche der letzten 30 Tage sind da (nicht nur 24 Stunden); Beitrittsbestätigungen älterer Gemeinschaften werden angenommen |
| 43bb68c | Kontoumzug auf ein frisches Gerät oder Profil (am besten drittes Gerät; sonst nur nach Rückfrage, keine bestehende Identität überschreiben): Seed eingeben | Bildschirm „Kein Backup auf diesem Gerät“ mit „Backup-Datei auswählen“; Log `[PROFILE-RESTORE] Looking up own Kind-0`, danach „own profile found“; Name, Bio und Bild wie auf dem alten Gerät, kein Zufallsname |
| 43bb68c | Backup-Datei vom alten Gerät (Einstellungen → Backup exportieren) auf das neue kopieren und auswählen | Kontakte, Kanäle, Gemeinschaften übernommen; „Dein Name: …“ auf dem Erfolgsbildschirm |
| 43bb68c | Eine fremde oder beschädigte `.enc`-Datei auswählen | Meldung „… lässt sich mit deiner Seed Phrase nicht öffnen …“, nichts wird übernommen |
| 43bb68c | Auf dem anderen Gerät (Kontakt) den Namen beobachten, während das neue Gerät startet | Der Name wechselt **nicht** kurz auf einen Zufallsnamen |
| a6dbd7e | Beide Geräte: Einstellungen → Nostr-Netzwerk | `relay.nexus-terminal.org`, `relay.damus.io`, `nos.lol` stehen auf „Verbunden“; `relay.snort.social` und `relay.nostr.band` sind weg. Chat, Antrag und Stimme kommen wie bisher an |
| a6dbd7e | Eigenes Relay eintragen (z. B. `wss://relay.primal.net`), App neu starten, danach wieder entfernen | Nach dem Neustart noch da; Papierkorb nur bei eigenen Relays; nach dem Entfernen weg, auch nach erneutem Neustart |
| a6dbd7e | Handy: App in den Hintergrund, von Windows eine DM schicken | Genau **eine** Benachrichtigung; Dienst-Benachrichtigung zeigt „Verbunden mit 3 von 3 Relays“ |
| 39b5106 | Optional: Handy (Superadmin) löscht eine Zelle, in der Windows Mitglied, aber nicht Gründer ist | Die Zelle verschwindet auch auf Windows |
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
| 1162510, 2398096, d990268 | 10.11.2026 | Antrags-Knopf in der Zelle für Windows sichtbar; Delegation erscheint ohne Seitenwechsel; Handy veröffentlicht Kind-31007, Windows übernimmt („Applied roster … 2 members“, auch 6 Mitglieder in einer weiteren Zelle); Moderator-Ernennung kommt auf Windows an |
| 39b5106 | 10.11.2026 | Windows als Gründer und letztes Mitglied: „Gemeinschaft löschen“ sichtbar, Testzelle811 mit Identitätsnachweis aufgelöst. Die alte Superadmin-Löschung vom Handy kam nicht von selbst an (offen: Superadmin löscht eine fremde Zelle) |
