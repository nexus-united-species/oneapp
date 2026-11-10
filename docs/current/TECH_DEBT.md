# N.E.X.U.S. OneApp – Tech Debt

Stand: 15. Juli 2026, ergänzt 6. November 2026  
Basis: Codeprüfung sowie Audit Lauf A und B vom Juli 2026; Wiederaufnahme-Sichtung vom 6. November 2026

Diese Liste enthält bestätigte Schulden und bewusst verschobene Risiken. Die
Release-Reihenfolge steht separat in
[RELEASE_READINESS.md](RELEASE_READINESS.md).

## Blockiert produktiven Release

| ID | Thema | Auswirkung | Zielrichtung |
|---|---|---|---|
| TD-37 / F-002 | Seit 09.11.2026 eingefroren und übertragen (Gerätetest offen) | Anträge ohne Liste (vor diesem Stand gestartet) zählen weiter geräteabhängig | nach dem Gerätetest schließen |
| TD-38 / F-003 | Seit 09.11.2026 nutzt der Retry denselben Payload-Builder wie der Erstversand (Gerätetest offen) | – | nach dem Livetest mit Relay-Ausfall schließen |
| TD-40 / V-003/V-005 | Senderautorisierung umgesetzt, im Zwei-Geräte-Test bestätigt (08.11.2026) | Beitrittsbestätigung (31004) und Absender der Decision Records (31013) seit 09.11.2026 geprüft (Gerätetest offen); offen: Inhalt der Decision Records (TD-41), Stimmen von Nicht-Mitgliedern in der Auszählung (braucht vollständige Mitgliederlisten, TD-33/TD-37) | Wählerfilter mit TD-37 vervollständigen |

## Hoch – vor breiter Nutzung

| ID | Thema | Aktueller Stand |
|---|---|---|
| TD-32 | `allVotes` auf Empfängergeräten leer | Fallback auf lokale Votes; delegierte Detailstimmen können fehlen |
| TD-33 | Seit 10.11.2026 Mitgliederliste vom Gründer (Kind 31007, Gerätetest offen) | offen: Änderungen von Moderatoren erreichen andere über die Liste erst, wenn der Gründer online ist; Gründer-Übergabe wird weiterhin nicht übertragen |
| TD-34 | Seit 09.11.2026 in Modell, DB (v27, additiv), Wire-Format und Vergleich (Gerätetest offen) | ältere Records ohne Zahl: Nenner weiter aus der Beteiligung rekonstruiert |
| TD-41 | Seit 09.11.2026: eigene Auszählung hat Vorrang, Abweichungen erscheinen beim Ergebnis und in der Historie (Gerätetest offen) | Hash-Kette bleibt geräteabhängig und ist keine Manipulationsprüfung; fehlende Stimmen werden nicht nachgeladen |
| TD-42 | Governance-Daten im Klartext | Anträge, Stimmen und Delegationen mit DID/Pseudonym liegen öffentlich auf Relays |
| TD-43 | Backup-Restore stellt Zellmitgliedschaften nicht vollständig her | Restore kann Gemeinschaft zeigen, aber lokale Mitgliedschaft verlieren |
| TD-57 | Selbst gesendete Direktnachrichten erreichen das Zweitgerät nie | DM-Abo filtert nur `#p` = eigener Pubkey, kein `authors`-Filter ([nostr_transport.dart:1823](../../lib/core/transport/nostr/nostr_transport.dart)); Gespräche zeigen auf dem anderen Gerät nur die Antworten des Gegenübers |
| TD-58 | Kontoumzug auf ein Zweitgerät verliert die Daten | Restore sucht Backups nur im eigenen Geräteordner, keine Dateiauswahl ([backup_service.dart:443](../../lib/services/backup_service.dart)); Seed-Restore setzt einen Zufallsnamen; der im Backup gesicherte Name wird nicht übernommen |
| TD-59 | Neues Gerät überschreibt das öffentliche Profil | Nach Seed-Restore wird sofort Kind-0 mit Zufallsnamen und leerer Bio veröffentlicht ([nostr_transport.dart:1636](../../lib/core/transport/nostr/nostr_transport.dart)); eigene Kind-0-Events werden ignoriert, das Profil lässt sich also nicht von Relays zurückholen. Kontakte sehen den Namen zwischen den Geräten wechseln |
| TD-60 | Kontakte werden nicht zwischen eigenen Geräten abgeglichen | kein Kontaktlisten-Event; Kontakte existieren nur lokal oder im Backup |
| TD-61 | Update-Prüfung nach GitHub-Umzug tot | `version.json` unter `project-nexus-official.github.io/terminal/…` liefert 404 ([update_service.dart:48](../../lib/services/update_service.dart)); installierte Apps erfahren nicht von neuen Versionen. Download-Links und Einladungs-Ersatzlink funktionieren nur noch über GitHub-Weiterleitungen |
| TD-62 | Keine Mehrsprachigkeit | keinerlei Lokalisierungsgrundlage; rund 1.500 deutsche Texte fest im Code. Ziel: DE, EN, ES, FR, RU wie die Webseite |
| TD-68 | Reaktion und Löschen am Desktop praktisch nicht erreichbar | Nachrichtenmenü nur per `onLongPress` ([conversation_screen.dart:1787](../../lib/features/chat/conversation_screen.dart), [channel_conversation_screen.dart:1151](../../lib/features/chat/channel_conversation_screen.dart)); kein Rechtsklick, kein Hover-Menü. Mit der Maus nur durch langes Gedrückthalten erreichbar |

## Mittel

| ID | Thema | Hinweis |
|---|---|---|
| TD-25 | UI-/Navigation-Tests seit 09.11.2026 grün | Tests an Dorfplatz-Tab, Agora-Kachel/-Karte und „Peers im Netzwerk“ angepasst; dabei zwei echte Überläufe in der Handy-Ansicht (400 px) behoben: Peer-Zeile unter dem Radar (44 px) und lange Abschnittstitel in Gemeinschaften (9,6 px). Offen bleiben 4 LAN-Discovery- und 5 TransportManager-Tests (Volllauf 09.11.2026: 1674 grün, 9 rot) |
| TD-28 | `publish_results.vote_id` polymorph | Feld trägt je nach `event_kind` auch DecisionRecord-/Delegation-IDs; später in `payload_id` umbenennen |
| TD-44 / F-004 | Background-Isolate kann aus leerem Seed ableiten | seltener partieller Secure-Storage-Zustand; nur gecachte vollständige Keys akzeptieren |
| TD-45 / F-005 | Vote mit leerem `voterPubkey` möglich | Init-Race kann UNIQUE-Kollision erzeugen; Abstimmung ohne Pubkey ablehnen |
| TD-46 | Geräteübergreifende Idempotenz teils in SharedPreferences | nach Reset/Zweitgerät sind doppelte Auto-Aktionen möglich |
| TD-47 | Fest verdrahtete Standard-Relays | Verfügbarkeit und Aufbewahrung hängen von Drittservern ab. **Live geprüft 06.11.2026:** `relay.nostr.band` nicht erreichbar; `relay.snort.social` läuft nur noch im Arbeitsspeicher (speichert nichts dauerhaft); `nos.lol` nimmt höchstens 128 KB pro Event an. Faktisch trägt nur `relay.damus.io`. Selbst eingetragene Relays werden nicht gespeichert; der Hintergrunddienst nutzt nur das erste Relay |
| TD-48 | Governance-Sync mit begrenzten `since`-Fenstern | längere Offline-Zeiten können Historie unvollständig machen |
| TD-63 | Neues Gerät lädt nur kurze Historie | DMs ohne bekannten Zeitstempel nur 24 h zurück, Mitgliedschaftsbestätigungen nur 7 Tage ([nostr_transport.dart:1925](../../lib/core/transport/nostr/nostr_transport.dart)); plausible Ursache von TD-33 |
| TD-64 | Medien inline als Base64 in Events | Bilder auf 1024 px verkleinert, Base64 und verschlüsselt im Event; übersteigt vermutlich das 128-KB-Limit von `nos.lol`. Keine Videos oder Dateien möglich; Lösung über Medienserver (Blossom) |
| TD-71 | Reaktionen vom eigenen Zweitgerät werden nicht übertragen | Der Transport verwirft eigene Kind-7-Events ([nostr_transport.dart](../../lib/core/transport/nostr/nostr_transport.dart), `_handleReaction`). Wer mit derselben Identität auf zwei Geräten arbeitet, sieht seine Reaktion nur auf dem Gerät, auf dem er sie gesetzt hat. Vor einer Änderung muss der Dorfplatz eigene Reaktionen getrennt behandeln, sonst entstehen Doppelungen |
| TD-65 | Verdacht: veralteter Nostr-Schlüssel im Hintergrunddienst | `NostrKeys.loadOrDerive` nutzt einen zwischengespeicherten Schlüssel; `restoreFromMnemonic` löscht ihn nicht. War vorher eine andere Identität auf dem Gerät, könnte der Hintergrunddienst mit dem alten Schlüssel arbeiten. Nicht am Gerät bestätigt; verwandt mit TD-44 |

## Wartbarkeit

| ID | Thema | Nächster kleiner Schritt |
|---|---|---|
| TD-49 | Große zentrale Services | Architekturkarte geschrieben ([ARCHITECTURE_REALITY.md](ARCHITECTURE_REALITY.md), Befund 8): 7 Dateien tragen 31 % des Codes. Reihenfolge und Grenze in [ADR-0005](../decisions/ADR-0005-dateigroesse.md) |
| TD-53 | Zwei unabhängige Identitätsschlüssel ohne normative Festlegung | `did:key` (Ed25519) und `nostrPubkey` (secp256k1) sind nicht umrechenbar; welcher fachlich gilt, ist unentschieden. Siehe [ADR-0001](../decisions/ADR-0001-identitaets-identifier.md) |
| TD-54 | Kein Gerätekonzept auf Identitätsebene | Identität ist implizit gleich Gerät; kein Einzelwiderruf möglich. Verschärft TD-33 und TD-46. Siehe [ADR-0002](../decisions/ADR-0002-geraet-und-person.md) |
| TD-55 | Persistenz reicht bis in die Widget-Ebene | 6 Screens greifen direkt auf `PodDatabase` zu, 13 Zugriffe aus `features/`/`services/` gesamt. Siehe [ADR-0004](../decisions/ADR-0004-storage-grenze.md) |
| TD-56 | Zustellsemantik an Nostr gebunden | `PublishResultStatus` liegt unter `core/transport/nostr/`; BLE und LAN haben keine Entsprechung. Siehe [ADR-0003](../decisions/ADR-0003-zustellsemantik.md) |
| TD-50 | Debug-/Reparaturprimitive in Produktcode | in gekennzeichneten Wartungsbereich verschieben |
| TD-51 | Dichtes `print`-Logging | Präfixe katalogisieren und schrittweise strukturieren |
| TD-52 | `lib.zip`/Code-Dumps im Arbeitsumfeld | nur im Archiv beziehungsweise außerhalb aktiver Suche halten |

## Erledigt durch diese Dokumentationsrunde

- TD-35: Bedienungs- und Erklärdokumentation nach Liquid Democracy aktualisiert
  und als Markdown/PDF neu eingeordnet.
- Alte Meilensteine, Release-Dokumente, Pläne und KI-Kontexte aus dem aktiven
  Dokumentationsbereich entfernt und nachvollziehbar archiviert.
- Überzogene Aussagen zu NIP-44, unveränderlichen Decision Records und
  vollständig wiederherstellbaren Daten abgeschwächt.

## Ergänzung 18. August 2026 – Architektur-Audit

Ein Architektur-Ist-Zustand wurde erstmals erhoben
([ARCHITECTURE_REALITY.md](ARCHITECTURE_REALITY.md)). Ergebnisse für diese
Liste:

- **Neu aufgenommen:** TD-53 bis TD-56 (Wartbarkeit) – vier Architekturbefunde,
  die bisher nirgends erfasst waren.
- **TD-49 präzisiert:** aus einer allgemeinen Beobachtung wurden sieben
  konkrete Dateien mit Zerlegungsreihenfolge.
- **TD-39 erneut im Code bestätigt:** `NostrEvent.verify()` ist implementiert
  und getestet, wird im Produktivpfad aber an keiner Stelle aufgerufen
  ([nostr_relay_manager.dart:431](../../lib/core/transport/nostr/nostr_relay_manager.dart)).
  Status unverändert Release-Blocker.
- **Keine Korrekturen nötig:** Alle bestehenden Einträge wurden gegen den Code
  geprüft und als zutreffend bestätigt. Version, Schemastand und
  Analyze-Baseline stimmen exakt.

## Ergänzung 6. November 2026 – Wiederaufnahme

- **TD-36 / F-001:** Der Fix für Reaktionen, Löschungen und Kanal-Metadaten
  liegt fertig auf dem Zweig `integrate/F-001-nostr-event-id` (17.09.2026,
  1485 Tests bestanden, 16 bekannte Fehler aus TD-25). Er ist weder in den
  Hauptstand zusammengeführt noch auf Geräten getestet.
- **Neu aufgenommen:** TD-57 bis TD-62 (hoch) und TD-63 bis TD-65 (mittel).
  TD-57 bis TD-60 erklären den gemeldeten Fehler „Konto auf Android
  erstellt, auf Windows fehlen die Daten“. Sie sind im Code belegt; welche
  davon beim damaligen Test zugeschlagen haben, klärt ein Zwei-Geräte-Test
  mit Logdatei (Phase 0).
- **TD-47 aktualisiert** mit einer Live-Prüfung der Standard-Relays.
- **Zwei-Geräte-Test A (07.11.2026, Android ↔ Windows, F-001 enthalten):**
  Textnachrichten in Chat und Kanal kommen in beide Richtungen an. Reaktionen
  und Löschungen werden korrekt mit echten Event-IDs gesendet und empfangen
  (F-001 wirkt), aber beim Empfänger nicht angewendet. Neu: TD-66 bis TD-69
  (hoch) und TD-70 (mittel). Das Android-Log brach nach dem Start ab
  (Verbindung zum Gerät verloren); die Befunde stammen aus dem Windows-Log.
- **TD-66 erledigt (07.11.2026):** „Für alle löschen“ wird beim Empfänger
  angewendet, in Chat und Kanal, auch für eigene Löschungen vom zweiten Gerät.
  Eine Löschung wirkt nur, wenn sie mit dem Schlüssel des Verfassers signiert
  ist. Nachrichten in nicht geöffneten Gesprächen werden über die neue Spalte
  `pod_messages.nostr_event_id` gefunden (DB v24, rein additiv). Am Gerät in
  beide Richtungen bestätigt. Ältere Nachrichten ohne gespeicherte Event-ID
  lassen sich nur löschen, solange sie im geöffneten Gespräch geladen sind.
- **TD-67 erledigt (07.11.2026, Gerätetest offen):** Empfangene Reaktionen in
  Chat und Kanal werden gespeichert und sofort angezeigt, auch in nicht
  geöffneten Gesprächen. In Direktchats wird nur der Gesprächspartner
  angenommen, in Kanälen jeder Absender. Mehrfach zugestellte Events werden
  einmal gespeichert und einmal gemeldet; NIP-25 „+“ wird zu 👍, „-“ und
  überlange Texte werden verworfen. Neu: TD-71.
- **TD-70 erledigt (07.11.2026, Gerätetest offen):** Wird eine Nachricht
  gelöscht, lokal oder per „Für alle löschen“ vom Verfasser, werden ihre
  Reaktionen mitgelöscht.
- **Zurücknehmen von Reaktionen (bisher Teil von TD-71) erledigt, Gerätetest
  offen:** Eine zurückgenommene eigene Reaktion wird per Kind-5 auf das
  Reaktions-Event gemeldet und beim Gegenüber entfernt, aber nur, wenn der
  Kind-5 vom Reagierenden selbst stammt. TD-71 umfasst nur noch das eigene
  Zweitgerät. Neu: TD-72.
- **TD-69 erledigt (07.11.2026, Gerätetest offen):** Die Kind-7- und
  Kind-5-Abos holen keinen weltweiten Fremdverkehr mehr. Chat- und
  Kanalreaktionen tragen jetzt `t=nexus-reaction`, Nachrichten- und
  Reaktionslöschungen `t=nexus-message-delete`. Abonniert werden diese
  Markierungen (bei Kind-5 zusätzlich `nexus-channel-delete`) sowie
  unmarkierte Events vom eigenen Schlüssel und von Kontakten; Letzteres wird
  mit der Kontaktliste alle 30 Minuten erneuert. Einschränkung: Reaktionen und
  Löschungen älterer App-Versionen von Absendern, die kein Kontakt sind
  (etwa in Kanälen), kommen nicht mehr an.
- **TD-73 erledigt (08.11.2026, Gerätetest offen):** Über LAN zugestellte
  Nachrichten bekommen ihre Nostr-Event-ID nachträglich. Direktnachrichten an
  einen LAN-Partner gehen zusätzlich über Nostr. Kommt die Nostr-Kopie einer
  bereits zugestellten Nachricht an, trägt der Empfänger deren Event-ID nach
  (Cache und Datenbank), statt die Kopie wegzuwerfen; das gilt auch für
  Kanalbeiträge. Nachgetragen wird nur, wenn Absender, Empfänger, Zeitpunkt
  und die Ed25519-Signatur des Absenders übereinstimmen (bei unsignierten
  Nachrichten der Text) und der Nostr-Schlüssel zum bekannten Schlüssel des
  Verfassers passt; eine vorhandene Event-ID wird nie ersetzt. Ist der
  Verfasser kein Kontakt, wird sein Nostr-Schlüssel nicht geprüft (Teil von
  TD-39). Vor dem Update empfangene Nachrichten bleiben ohne Event-ID.
- **TD-74 erledigt (08.11.2026, Gerätetest offen):** Direktnachrichten,
  Kanalbeiträge, Reaktionen und Löschungen, die kein Relay angenommen hat,
  landen signiert und verschlüsselt in der neuen Tabelle `nostr_outbox`
  (DB v25, nur `CREATE TABLE IF NOT EXISTS`). Sobald ein Relay (wieder)
  verbunden ist, werden sie unverändert erneut gesendet und nach Annahme
  entfernt; nach 7 Tagen verfallen sie. Die Warteschlange übersteht einen
  Neustart. Präsenz, Profil und Governance sind ausgenommen (Governance hat
  ihre eigene Retry-Queue). Offen: Die Oberfläche zeigt noch nicht an, dass
  eine Nachricht wartet.
- **TD-36 / F-001 erledigt:** Mit PR #4 (07.11.2026) in den Hauptstand
  übernommen und im Zwei-Geräte-Test bestätigt.
- **TD-39 / V-002 erledigt (08.11.2026, Gerätetest offen):** Jedes
  eingehende Nostr-Event wird vor der Weitergabe auf korrekte Event-ID und
  Schnorr-Signatur geprüft (`NostrEventVerifier` im `NostrRelayManager`);
  ungültige Events werden mit `[NOSTR-VERIFY] Rejected` verworfen. Die
  Prüfung läuft stapelweise in einem Hintergrund-Isolate (rund 25 ms pro
  Event in reinem Dart), Reihenfolge und Deduplizierung bleiben erhalten;
  dedupliziert wird erst nach der Prüfung, damit eine Fälschung mit fremder
  Event-ID das echte Event nicht verdrängt. Damit sind die Absenderprüfungen
  (Löschen nur durch den Verfasser usw.) belastbar. Die fachliche
  Autorisierung (TD-40, TD-72) bleibt offen.
- **TD-72 erledigt (08.11.2026, Gerätetest offen):** Der Dorfplatz-Löschpfad
  bekommt den Signaturschlüssel des Kind-5 mitgeliefert. Beiträge werden nur
  gelöscht, wenn der Unterzeichner ihr Verfasser ist (neu gespeichert:
  `FeedPost.authorPubkey` aus dem empfangenen Event, sonst Kontaktschlüssel);
  Reaktionen nur, wenn sie für den Unterzeichner gespeichert sind. Die
  ungeprüfte `deleteReactionsByNostrEventIds` ist entfernt. Einschränkung:
  Vorher empfangene Beiträge von Nicht-Kontakten haben keinen gespeicherten
  Schlüssel und lassen sich von deren Verfasser nicht mehr fernlöschen.
- **TD-40 weitgehend erledigt (08.11.2026, Gerätetest offen):** ADR-0001 ist
  angenommen. Jedes Gerät signiert einmal mit seinem DID-Schlüssel (Ed25519)
  die Zuordnung zu seinem Nostr-Schlüssel (`IdentityProof`, Feld `_idProof`
  im Event-Inhalt). Geprüft wird an der Empfangsgrenze im `ChatProvider`
  (Regeln in `governance_authorization.dart`), abgelehnte Events loggen
  `[CELL-AUTH]` bzw. `[GOV-AUTH]`:
  - Zellauflösung: nur der Gründer (`createdBy`).
  - Zell-Ankündigung (Entdecken, Umbenennen): nur der Gründer; `createdBy`
    einer bekannten Zelle lässt sich nicht von außen ändern.
  - Mitglieder-Update: Austritt nur durch das Mitglied selbst, Beitritt und
    Entfernen nur durch Gründer oder lokal bekannte Moderatoren; der Gründer
    ist nicht entfernbar.
  - Antrag: neu nur durch den Antragsteller, der als Mitglied bekannt sein
    muss; bearbeiten und zurückziehen nur durch ihn; Abstimmung starten auch
    Gründer/Moderator. Andere Mitglieder dürfen nur die automatischen
    Fristwechsel melden (Abstimmung → beendet → entschieden → archiviert);
    von ihren Events wird nur der Status übernommen, Inhalt, Optionen,
    Kategorie und Frist werden verworfen.
  - Stimme: nur die im Inhalt genannte `voterDid`.
  - Delegation: nur die delegierende Person.
  - Beitrittsbestätigung (Kind 31004, seit 09.11.2026): nur für eine bekannte
    Zelle mit offener eigener Beitrittsanfrage, nur für mich als einfaches
    Mitglied, nur solange ich noch nicht Mitglied bin, unterschrieben vom
    Gründer oder einem lokal bekannten Moderator (`confirmedBy`). Der
    Gründer der bekannten Zelle darf sich nicht ändern, übernommen werden
    die lokal bekannten Zelldaten. Bestätigungen, die vor der
    Zell-Ankündigung eintreffen, werden bis zu deren Eintreffen gehalten.
    **Einschränkung:** Ein Bewerber kennt die Moderatoren einer Zelle noch
    nicht. Bestätigt ein Moderator statt des Gründers, verwirft das Gerät des
    Bewerbers die Bestätigung. Lösbar erst mit übertragbaren Mitgliederlisten
    (TD-33/TD-37) oder einem vom Gründer signierten Moderatoren-Nachweis.
  - Entscheidungsprotokoll (Kind 31013, seit 09.11.2026): jedes Gerät zählt
    selbst aus und veröffentlicht dasselbe Protokoll, darum darf jedes
    nachgewiesene Mitglied der Zelle senden. Der Antrag muss zur genannten
    Zelle gehören, die Abstimmung muss laufen oder beendet sein, und Frist
    samt Nachfrist für späte Stimmen müssen nach der eigenen Uhr abgelaufen
    sein.
- **Zahl der Stimmberechtigten im Protokoll, TD-34 (09.11.2026, Gerätetest
  offen):** `DecisionRecord.eligibleVotersCount` (Spalte
  `eligible_voters_count`, Migration v27 per `ALTER TABLE`, nullable) wird
  aus der eingefrorenen Liste (TD-37) gesetzt, im Kind-31013-Inhalt
  mitgeschickt, bei der Beteiligungsanzeige als Nenner genutzt und beim
  Vergleich (TD-41) geprüft, wenn beide Seiten sie haben. In den Hash ging
  die Zahl schon vorher ein.
- **Retry der Entscheidungsprotokolle, TD-38 (09.11.2026, Gerätetest offen):**
  Der Wiederholungsversand baute den Inhalt bisher von Hand nach; es
  fehlten `cellId`, `votingMode`, `resultReason`, `optionResultsJson`,
  `tieOptionIdsJson` und die gewählten Optionen der Stimmen. Seit TD-41
  hätten Empfänger bei Abstimmungen mit Optionen deshalb eine falsche
  Abweichung gemeldet. Jetzt erzeugt `decisionRecordRetryContent` den
  Inhalt mit demselben Builder wie der Erstversand; ein Regressionstest
  vergleicht beide. Ist der Antrag lokal nicht mehr bekannt, entfällt der
  Retry (`[RETRY] Decision record retry skipped`).
- **Eigene Auszählung hat Vorrang, TD-41 (09.11.2026, Gerätetest offen):**
  Ein empfangenes Entscheidungsprotokoll löst zuerst die eigene Auszählung
  aus (`[TALLY-LOCAL]`); übernommen wird es nie, auch nicht, wenn keine
  eigene Auszählung möglich ist (`[TALLY-SKIP-ADOPT]`). Weicht es vom eigenen
  Ergebnis ab, loggt das Gerät `[TALLY-MISMATCH]` mit beiden Zahlenreihen
  (`decision_record_comparison.dart`), speichert einen Historien-Eintrag
  `RESULT_MISMATCH` und zeigt beim Ergebnis einen Hinweis mit Absender und
  gemeldeten Zahlen (`result_mismatch_notice.dart`). Der `content_hash` wird bewusst nicht
  verglichen: Ihn berechnet der Absender selbst, und er enthält den Hash des
  vorigen Protokolls auf dem Absendergerät. Mehrere gleichzeitige
  Auszählungen (Scheduler, App-Start, Empfang) warten aufeinander.
  Abweichungen zwischen ehrlichen Geräten bleiben möglich, wenn einem Gerät
  Stimmen fehlen; die eingefrorene Liste (TD-37) beseitigt nur die
  Unterschiede in der Mitgliederliste.

  Events älterer App-Versionen ohne Nachweis werden abgelehnt; ein Gerät,
  das alte Anträge/Stimmen von Relays neu einliest, übernimmt sie nicht.
  Gründerwechsel und Moderatorenrolle werden weiterhin nicht synchronisiert,
  Moderatoren-Aktionen gelten daher nur auf Geräten, die die Rolle kennen.
  Governance-Events werden in Empfangsreihenfolge geprüft und verarbeitet;
  Auflösungen noch unbekannter Zellen werden vorgemerkt und beim Eintreffen
  der Gründer-Ankündigung angewendet. Bekannte Restlücke: Wer eine Zell-ID
  kennt, kann sie auf einem Gerät, das die Zelle noch nie gesehen hat, mit
  sich selbst als Gründer zuerst ankündigen; die echte Ankündigung wird dort
  dann abgelehnt.
- **Stimmberechtigung bei Austritt (08.11.2026, Gerätetest offen):** Regel
  „Start-Liste minus Austritte“. Jedes Gerät merkt sich Austritte und
  Entfernungen dauerhaft (Tabelle `cell_departures`, DB v26, additiv). Stimmen
  von Personen, deren Austritt nach dem Abstimmungsstart liegt, zählen weder
  in der Anzeige noch in der Auszählung (`[TALLY-ELIGIBLE]`); gespeichert
  bleiben sie. Die Anzeige zeigt nie mehr Stimmen als Stimmberechtigte
  („2 von 1“ behoben).
- **Zellen löschen (10.11.2026, Gerätetest offen):** Seit TD-40 nahmen andere
  Geräte eine Auflösung nur vom Gründer an; Admin-Löschungen fremder Zellen
  wirkten deshalb nur auf dem Admin-Gerät (Testzelle811 blieb auf Windows).
  Entscheidung: Gründer oder Superadmin dürfen auflösen
  (`mayDissolveCell`). Die Superadmin-DID kommt aus
  `assets/config/system.json`; System-Admins werden nicht zwischen Geräten
  abgeglichen und sind deshalb nicht netzweit berechtigt. Eine lokale
  Superadmin-Übertragung (SharedPreferences) kennt nur das eigene Gerät.
  Außerdem sieht ein Gründer, der als letztes Mitglied übrig ist,
  „Gemeinschaft löschen“; bisher konnte er weder löschen noch austreten.
- **TD-33 Mitgliederliste vom Gründer (10.11.2026, Gerätetest offen):**
  Ursachen der abweichenden Listen: Neue Mitglieder kannten nur Gründer und
  sich selbst, Moderatoren-Ernennungen verließen das Gründergerät nie, und
  31005-Meldungen älter als 7 Tage werden nie geholt. Jetzt veröffentlicht
  der Gründer eine signierte Liste aller bestätigten Mitglieder mit Rolle
  (`cell_roster.dart`, Kind 31007, ersetzbar pro Zelle) nach jeder Aufnahme,
  Entfernung, jedem Austritt und jeder Moderator-Ernennung sowie beim
  Verbinden eines Relays (pro Relay höchstens alle 10 Minuten). Mitglieder
  übernehmen nur die Liste des nachgewiesenen Gründers und nur, wenn sie
  neuer ist; dabei bleiben der eigene Eintrag, später lokal Beigetretene und
  später Ausgetretene (nicht wieder aufgenommen) gewahrt. Der Gründer wendet
  seine eigene Liste nie an. Austritte zählen weiterhin nur aus
  ausdrücklichen 31005-Meldungen. Grenzen: Die angewandte Listenversion
  liegt nur im Speicher; eine lokale Gründer-Übergabe wird nicht übertragen
  (das Gerät veröffentlicht danach keine Liste mehr); Bewerber übernehmen
  die Liste noch nicht (Voraussetzung, um Bestätigungen durch Moderatoren
  zuzulassen).
- **TD-77 Status springt beim Start zurück (09.11.2026 im Gerätetest
  gefunden und behoben):** Relays heben ältere Antrags-Events des
  Antragstellers auf (z. B. „Abstimmung gestartet“) und liefern sie bei
  jedem Start erneut aus. Weil der Antragsteller jeden Status setzen durfte,
  sprang ein entschiedener Antrag dadurch auf „Abstimmung läuft“ zurück
  (`Status: DECIDED → VOTING`), samt alter Frist. Jetzt geht der Status nur
  vorwärts (Entwurf → Diskussion → Abstimmung → beendet → entschieden →
  archiviert); Rückschritte werden für jeden Absender abgelehnt. Ein
  zurückgezogener Antrag bleibt zurückgezogen, ein entschiedener kann nicht
  mehr zurückgezogen werden. Bereits zurückgesprungene Anträge laufen bis
  zur alten Frist weiter und werden dann von der eigenen Auszählung wieder
  auf „entschieden“ gesetzt (vorhandener Entscheidungsdatensatz bleibt).
- **TD-76 Vorzeitiges Abstimmungsende von außen (09.11.2026 im Gerätetest
  gefunden und behoben):** Die TD-40-Regeln erlaubten jedem Mitglied die
  „automatischen“ Statuswechsel und dem Antragsteller jeden Status, ohne die
  eigene Frist zu prüfen. Ein „Force beenden“ auf dem Handy setzte den
  Antrag auf Windows deshalb über die Statusmeldungen auf „entschieden“,
  obwohl die Frist dort noch lief; Windows zählte nie selbst aus und zeigte
  „Ungültig“. Jetzt gilt für alle Absender, auch den Antragsteller:
  „Abstimmung beendet“ nur nach Ablauf der Frist auf der eigenen Uhr,
  „entschieden“ nie von außen (nur die eigene Auszählung setzt es),
  „archiviert“ erst nach eigener Entscheidung. Zurückziehen bleibt dem
  Antragsteller erlaubt. Bereits so beschädigte Anträge (entschieden ohne
  Ergebnis) werden nicht automatisch geheilt.
- **TD-75 Schema bei Neuinstallation unvollständig (09.11.2026 behoben,
  Gerätetest offen):** `_onCreate` legte nur den Stand von Schema v12 an;
  alle späteren Spalten und Tabellen gab es nur in den Migrationsschritten,
  die eine Neuinstallation nie durchläuft. Es fehlten u. a.
  `proposals.voting_mode`/`eligible_voters_json`,
  `proposal_votes.selected_option_id`, `group_channels.nostr_event_id`, alle
  v1.3-Felder von `decision_records` und die Tabelle `proposal_options` —
  auf neu installierten Geräten scheiterten Auszählungen mit einem
  SQL-Fehler. Jetzt führt die Neuinstallation nach den Basistabellen alle
  Schritte ab v13 aus (alle additiv und abgesichert; der Umbenennungsschritt
  v12 nicht). DB v28 repariert bereits neu installierte Geräte, indem sie
  dieselben Schritte noch einmal anwendet; auf vollständigen Schemata ändert
  das nichts. Test: `test/core/storage/fresh_install_schema_test.dart`.
  Regel für künftige Migrationen: jeder Schritt muss additiv und
  wiederholbar sein, da er auch bei Neuinstallation und Reparatur läuft.
- **Eingefrorene Start-Liste, TD-37 (09.11.2026, Gerätetest offen):** Wer die
  Abstimmung startet, friert die bestätigten Mitglieder samt Gründer als
  `eligibleVoters` ein (`voting_snapshot.dart`, Log `[TALLY-SNAPSHOT]`) und
  schickt die Liste mit `votingStartedAt` im Antrags-Event mit. Empfänger
  übernehmen sie einmal, zusammen mit der Startzeit und nur solange sie
  selbst noch nicht ausgezählt haben; eine spätere Liste ersetzt sie nicht.
  Abweichungen zur eigenen Mitgliederliste loggt `[TALLY-SNAPSHOT-DIFF]`.
  Wer nicht auf der Liste steht, sieht beim Abstimmen einen Hinweis, dass
  seine Stimme nicht zählt. Nur Events von
  Antragsteller oder Gründer/Moderator tragen Inhalt (TD-40). Gezählt werden
  nur Stimmen von Personen auf der Liste, abzüglich Austritten nach dem Start;
  wer später beitritt, stimmt nicht mit ab. Anträge ohne Liste (vor diesem
  Stand gestartet) zählen weiter mit der aktuellen Mitgliederliste.
  Restrisiko: Die Liste ist nur so vollständig wie die Mitgliederliste des
  startenden Geräts (TD-33), und ein böswilliger Antragsteller kann eine
  falsche Liste schicken.
- **Zellen älterer App-Versionen (08.11.2026):** Beim ersten Entdecken werden
  Zell-Ankündigungen auch ohne DID-Nachweis angezeigt (`[CELL-AUTH] Legacy
  discovery`). Jede spätere Änderung verlangt den Nachweis des Gründers; eine
  unbelegte Ankündigung mit mir als Gründer wird nie übernommen.
- **Austritt getrennt von Ausblenden (08.11.2026, Gerätetest offen):** Wer
  eine Zelle verlässt oder entfernt wird, setzte sie bisher auf dieselbe
  Sperrliste wie ausgeblendete Zellen: Sie verschwand aus „Entdecken“, und
  ein Wiederbeitritt wurde blockiert. Jetzt eigene Markierung (Tombstone-Typ
  `cell_left` mit Zeitpunkt); alte Austritte (`cell_dismissed`/
  `leave_or_removed`) werden beim Start umgestellt. Eine Beitrittsbestätigung
  für eine verlassene Zelle gilt nur, wenn eine eigene offene Anfrage besteht
  und die Bestätigung nach dem Austritt ausgestellt wurde.
- **TD-25 ergänzt (08.11.2026):** Der Test „Kind-31012 revoke event arrives
  before vote“ in `delegation_incoming_test.dart` ist zeitabhängig: Delegation
  und Widerruf entstehen in derselben Millisekunde, und die Stale-Prüfung
  (`updatedAtMs <= existing`) verwirft den Widerruf. Einzeln läuft er durch,
  in der Gesamtsuite gelegentlich nicht.
- **TD-25 ergänzt:** Bei der Messung am 06.11.2026 schlugen zusätzlich 5 Tests
  im TransportManager fehl.
- Einordnung in den Projektablauf: [NOW_NEXT_LATER.md](../planning/NOW_NEXT_LATER.md).

## Quellen

- [Architektur-Ist-Zustand](ARCHITECTURE_REALITY.md)
- [Was nicht angefasst werden sollte](DO_NOT_TOUCH.md)
- [Architekturentscheidungen](../decisions/)
- [Audit Lauf A](../audits/2026-07/AUDIT_LAUF_A.md)
- [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md)
- [Projektstatus](PROJECT_STATUS.md)

