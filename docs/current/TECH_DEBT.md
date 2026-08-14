# N.E.X.U.S. OneApp – Tech Debt

Stand: 15. Juli 2026  
Basis: Codeprüfung sowie Audit Lauf A und B vom Juli 2026

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

## Mittel

| ID | Thema | Hinweis |
|---|---|---|
| TD-25 | UI-/Navigation-Test-Failures | 11 bekannte Fehler in der geprüften Auswahl; meist veraltete Labels plus realer Desktop-Overflow |
| TD-28 | `publish_results.vote_id` polymorph | Feld trägt je nach `event_kind` auch DecisionRecord-/Delegation-IDs; später in `payload_id` umbenennen |
| TD-44 / F-004 | Background-Isolate kann aus leerem Seed ableiten | seltener partieller Secure-Storage-Zustand; nur gecachte vollständige Keys akzeptieren |
| TD-45 / F-005 | Vote mit leerem `voterPubkey` möglich | Init-Race kann UNIQUE-Kollision erzeugen; Abstimmung ohne Pubkey ablehnen |
| TD-46 | Geräteübergreifende Idempotenz teils in SharedPreferences | nach Reset/Zweitgerät sind doppelte Auto-Aktionen möglich |
| TD-47 | Fest verdrahtete Standard-Relays | Verfügbarkeit und Aufbewahrung hängen von Drittservern ab |
| TD-48 | Governance-Sync mit begrenzten `since`-Fenstern | längere Offline-Zeiten können Historie unvollständig machen |

## Wartbarkeit

| ID | Thema | Nächster kleiner Schritt |
|---|---|---|
| TD-49 | Große zentrale Services | Architekturkarte schreiben; danach nur entlang klarer Grenzen extrahieren |
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

## Quellen

- [Audit Lauf A](../audits/2026-07/AUDIT_LAUF_A.md)
- [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md)
- [Projektstatus](PROJECT_STATUS.md)

