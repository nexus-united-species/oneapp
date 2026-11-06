# N.E.X.U.S. OneApp – Tech Debt

Stand: 15. Juli 2026, ergänzt 6. November 2026  
Basis: Codeprüfung sowie Audit Lauf A und B vom Juli 2026; Wiederaufnahme-Sichtung vom 6. November 2026

Diese Liste enthält bestätigte Schulden und bewusst verschobene Risiken. Die
Release-Reihenfolge steht separat in
[RELEASE_READINESS.md](RELEASE_READINESS.md).

## Blockiert produktiven Release

| ID | Thema | Auswirkung | Zielrichtung |
|---|---|---|---|
| TD-36 / F-001 | UUIDs in Nostr-`e`-Tags | Relay-Ablehnung; Reaktionen/Löschungen fehlen auf anderen Geräten | reale 64-Hex-Event-ID persistieren und nutzen |
| TD-37 / F-002 | `eligibleVoters` wird nicht eingefroren | geräteabhängige Beteiligung, Quoren und Hashes | Snapshot in `startVoting` setzen und synchronisieren |
| TD-38 / F-003 | Decision-Record-Retry unvollständig | degradierter Inhalt und Hash-Mismatch nach Erstversand-Ausfall | gemeinsamen Payload-Builder verwenden |
| TD-39 / V-002 | Keine Signaturprüfung eingehender Nostr-Events | gefälschte Events können Zustand verändern | `NostrEvent.verify()` vor Dispatch, kompatibel ausrollen |
| TD-40 / V-003/V-005 | Keine vollständige Senderautorisierung | unberechtigte Zellauflösung, Votes oder Anträge möglich | Pubkey gegen Rolle/Mitgliedschaft prüfen |

## Hoch – vor breiter Nutzung

| ID | Thema | Aktueller Stand |
|---|---|---|
| TD-32 | `allVotes` auf Empfängergeräten leer | Fallback auf lokale Votes; delegierte Detailstimmen können fehlen |
| TD-33 | Zellmitglieder-Sync divergiert | Android/Windows zeigten unterschiedliche Mitgliederzahlen; F-002 verschärft das Problem |
| TD-34 | `eligibleVotersCount` fehlt im Decision Record | Nenner wird fragil aus Beteiligung rekonstruiert |
| TD-41 | `content_hash`/Hash-Kette werden beim Empfang nicht geprüft | lokale Hash-Kette existiert, ist aber keine durchgesetzte Manipulationsprüfung |
| TD-42 | Governance-Daten im Klartext | Anträge, Stimmen und Delegationen mit DID/Pseudonym liegen öffentlich auf Relays |
| TD-43 | Backup-Restore stellt Zellmitgliedschaften nicht vollständig her | Restore kann Gemeinschaft zeigen, aber lokale Mitgliedschaft verlieren |
| TD-57 | Selbst gesendete Direktnachrichten erreichen das Zweitgerät nie | DM-Abo filtert nur `#p` = eigener Pubkey, kein `authors`-Filter ([nostr_transport.dart:1823](../../lib/core/transport/nostr/nostr_transport.dart)); Gespräche zeigen auf dem anderen Gerät nur die Antworten des Gegenübers |
| TD-58 | Kontoumzug auf ein Zweitgerät verliert die Daten | Restore sucht Backups nur im eigenen Geräteordner, keine Dateiauswahl ([backup_service.dart:443](../../lib/services/backup_service.dart)); Seed-Restore setzt einen Zufallsnamen; der im Backup gesicherte Name wird nicht übernommen |
| TD-59 | Neues Gerät überschreibt das öffentliche Profil | Nach Seed-Restore wird sofort Kind-0 mit Zufallsnamen und leerer Bio veröffentlicht ([nostr_transport.dart:1636](../../lib/core/transport/nostr/nostr_transport.dart)); eigene Kind-0-Events werden ignoriert, das Profil lässt sich also nicht von Relays zurückholen. Kontakte sehen den Namen zwischen den Geräten wechseln |
| TD-60 | Kontakte werden nicht zwischen eigenen Geräten abgeglichen | kein Kontaktlisten-Event; Kontakte existieren nur lokal oder im Backup |
| TD-61 | Update-Prüfung nach GitHub-Umzug tot | `version.json` unter `project-nexus-official.github.io/terminal/…` liefert 404 ([update_service.dart:48](../../lib/services/update_service.dart)); installierte Apps erfahren nicht von neuen Versionen. Download-Links und Einladungs-Ersatzlink funktionieren nur noch über GitHub-Weiterleitungen |
| TD-62 | Keine Mehrsprachigkeit | keinerlei Lokalisierungsgrundlage; rund 1.500 deutsche Texte fest im Code. Ziel: DE, EN, ES, FR, RU wie die Webseite |

## Mittel

| ID | Thema | Hinweis |
|---|---|---|
| TD-25 | UI-/Navigation-Test-Failures | 11 bekannte Fehler in der geprüften Auswahl; meist veraltete Labels plus realer Desktop-Overflow |
| TD-28 | `publish_results.vote_id` polymorph | Feld trägt je nach `event_kind` auch DecisionRecord-/Delegation-IDs; später in `payload_id` umbenennen |
| TD-44 / F-004 | Background-Isolate kann aus leerem Seed ableiten | seltener partieller Secure-Storage-Zustand; nur gecachte vollständige Keys akzeptieren |
| TD-45 / F-005 | Vote mit leerem `voterPubkey` möglich | Init-Race kann UNIQUE-Kollision erzeugen; Abstimmung ohne Pubkey ablehnen |
| TD-46 | Geräteübergreifende Idempotenz teils in SharedPreferences | nach Reset/Zweitgerät sind doppelte Auto-Aktionen möglich |
| TD-47 | Fest verdrahtete Standard-Relays | Verfügbarkeit und Aufbewahrung hängen von Drittservern ab. **Live geprüft 06.11.2026:** `relay.nostr.band` nicht erreichbar; `relay.snort.social` läuft nur noch im Arbeitsspeicher (speichert nichts dauerhaft); `nos.lol` nimmt höchstens 128 KB pro Event an. Faktisch trägt nur `relay.damus.io`. Selbst eingetragene Relays werden nicht gespeichert; der Hintergrunddienst nutzt nur das erste Relay |
| TD-48 | Governance-Sync mit begrenzten `since`-Fenstern | längere Offline-Zeiten können Historie unvollständig machen |
| TD-63 | Neues Gerät lädt nur kurze Historie | DMs ohne bekannten Zeitstempel nur 24 h zurück, Mitgliedschaftsbestätigungen nur 7 Tage ([nostr_transport.dart:1925](../../lib/core/transport/nostr/nostr_transport.dart)); plausible Ursache von TD-33 |
| TD-64 | Medien inline als Base64 in Events | Bilder auf 1024 px verkleinert, Base64 und verschlüsselt im Event; übersteigt vermutlich das 128-KB-Limit von `nos.lol`. Keine Videos oder Dateien möglich; Lösung über Medienserver (Blossom) |
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
- Einordnung in den Projektablauf: [NOW_NEXT_LATER.md](../planning/NOW_NEXT_LATER.md).

## Quellen

- [Architektur-Ist-Zustand](ARCHITECTURE_REALITY.md)
- [Was nicht angefasst werden sollte](DO_NOT_TOUCH.md)
- [Architekturentscheidungen](../decisions/)
- [Audit Lauf A](../audits/2026-07/AUDIT_LAUF_A.md)
- [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md)
- [Projektstatus](PROJECT_STATUS.md)

