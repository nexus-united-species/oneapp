# Audit Lauf A — N.E.X.U.S. OneApp v0.2.0-alpha

## Zusammenfassung

Die Codebasis ist für ein Alpha-Projekt bemerkenswert diszipliniert: Das
synchrone State-Locking vor DB-Awaits, die Grabstein-Verwaltung in SQLite,
die Tombstone-Reihenfolge bei Löschungen und die AETHER-Dedup-Sets sind
konsequent umgesetzt und decken die früher gemeldeten Zombie-/Race-Muster gut
ab. Die Kryptografie im eigenen Code (AES-GCM mit frischem Nonce, X25519/HKDF,
deterministische SLIP-0010/NIP-06-Ableitung) ist an den geprüften Stellen
sauber; ich habe keine Nonce-Wiederverwendung und keine stillen
Krypto-Fehlpfade gefunden, die zu falschen Ergebnissen führen.

Die drei dringendsten Punkte betreffen die geräteübergreifende Konsistenz —
also genau das, was zwanzig Tester mit Android und Windows spüren werden:

1. **F-001:** Chat- und Kanal-**Reaktionen und -Löschungen** setzen eine
   interne UUID statt einer 64-Hex-Event-ID in das Nostr-`e`-Tag. Die
   konfigurierten Relays weisen diese Events ab. Das ist die eigentliche
   Ursache für zwei der sechs bekannten Cross-Device-Inkonsistenzen
   (Nachrichten-Löschungen, Emoji-Reaktionen) — dasselbe Fehlermuster, das
   bereits dreimal auftrat, nur an einer bisher nicht bereinigten Stelle.
2. **F-002:** Der `eligibleVoters`-Snapshot, der den Beteiligungs-Nenner
   einer Abstimmung einfrieren soll, wird **nirgends im Code gesetzt**. Die
   Auswertung nimmt deshalb immer die aktuelle Mitgliederzahl zur
   Auszählzeit. In Verbindung mit der bekannten Mitglieder-Sync-Divergenz
   (TD-33) können zwei Geräte zu verschiedenen Ergebnissen kommen — die in
   TD-33/TD-34 beschriebene Absicherung existiert faktisch nicht.
3. **F-003:** Der Wiederhol-Versand von Entscheidungs-Datensätzen lässt die
   v1.3-Felder (u. a. Optionsergebnisse, Stichwahl-Info, `resultReason`) weg.
   Schlägt der Erstversand vollständig fehl, erhalten andere Geräte einen
   degradierten Datensatz, dessen Inhalt nicht mehr zum mitgesendeten
   `content_hash` passt.

Gesamteindruck: Die lokale Datensicherheit ist solide; die Schwächen liegen im
verteilten Zustand — Abstimmungs-Determinismus und Event-Konformität. Keiner
der Funde führt zu lokalem Datenverlust; F-001 bis F-003 gefährden die
Verlässlichkeit der Governance- und Chat-Kernfunktionen über Geräte hinweg.

---

## Verifizierung der bekannten Punkte

**Altes Audit v0.1.11 (`nexus_codebase_audit_v0111.txt`):** Diese Datei ist
**kein Befund-Bericht**, sondern eine reine Quelltext-Konkatenation von 190
Dateien mit einer Datei-Inhaltsübersicht und einer einzeiligen „AUDIT
SUMMARY: Total files". Es gibt darin keine damaligen Prüfpunkte, die man als
„behoben" oder „fortbestehend" markieren könnte. (Der einzige Treffer auf
„CRITICAL" ist ein Code-Kommentar, kein Befund.)

**LOGIK_AUDIT.md (Stand 2026-04-06):** Teilweise überholt.
- Punkt 1 („Proposals — KEINE Nostr-Synchronisation") ist **nicht mehr
  zutreffend**: `publishToDiscussion` ruft `_publishProposalToNostr`, es gibt
  `publishProposalEvent` (Kind-31010) und Subscriptions in
  `refreshGovernanceSubscriptions`. Widerspruch Code↔Doku (siehe Beobachtung).
- Punkt 2 („Restore — Nostr-Re-Subscriptions fehlen") ist **abgemildert**:
  `restoreFromFile` besitzt jetzt einen `onRestored`-Callback und
  `NostrTransport.resetSubscriptions` (Zeile ~2061). Ob der Restore-Screen
  ihn übergibt, konnte ich statisch nicht abschließend belegen — Restpunkt.
- Die genannten Datei/Zeilen-Referenzen stimmen nicht mehr (die Datei heißt
  `restore_screen.dart`, nicht `restore_backup_screen.dart`).

**TD-28/TD-29 (`vote_id` polymorph):** **Bestätigt.** In
`proposal_service.dart:3138-3150` wird bei Delegations-Retries die
`delegationId` aus dem Feld `pendingResult.voteId` gelesen; die Diskriminierung
erfolgt über `eventKind`. Funktioniert, ist aber fragil wie beschrieben.

**TD-32 (`allVotes: const []` auf Empfänger-Geräten):** **Bestätigt.**
`proposal_service.dart:2859` setzt `allVotes: const []` beim Empfang eines
Decision-Records. Der `getVotes()`-Fallback existiert.

**TD-33 (Cell-Membership-Sync-Inkonsistenz):** **Schlimmer als beschrieben.**
Die Aussage „Auswertungsergebnis bleibt korrekt, weil `eligibleVoters`
eingefroren wird" trifft nicht zu — der Snapshot wird nie gesetzt (siehe
F-002). Die Divergenz der Mitgliederzahl schlägt damit direkt auf den
Beteiligungs-Nenner und potenziell auf das Ergebnis durch.

**TD-34 (`eligibleVotersCount` fehlt im DecisionRecord):** **Bestätigt und
schlimmer.** Das Feld fehlt im `decision_records`-Schema (nur `participation`
ist gespeichert); zusätzlich wird der Wert, der in den `content_hash` einfließt,
aus der Live-Mitgliederzahl gebildet, nicht aus einem eingefrorenen Snapshot.

**Fehlermuster „NIP-01 e-Tag-Verstoß":** **Weiterer Verstoß gefunden** — siehe
F-001 (Chat-/Kanal-Reaktionen und -Löschungen). Die bereits abgesicherten
Stellen (Kanal-Löschung `publishChannelDeletion`, Dorfplatz-Repost) prüfen
korrekt auf `length == 64`; die Chat-Pfade tun das nicht.

**Grabsteine in SharedPreferences:** **Behoben/abgemildert.** Tombstones liegen
jetzt primär in der SQLite-Tabelle `tombstones` (Migration v14) mit
Einmal-Migration aus SharedPreferences; SharedPreferences dient nur noch als
Fallback. Der ursprüngliche Datenverlust-Pfad bei App-Daten-Reset ist damit
entschärft.

**DID ändert sich nach Reset + Seed-Wiederherstellung:** **Nicht aus dem Code
reproduzierbar.** `_deriveIdentityData` (SLIP-0010 Ed25519 → DID) ist rein
deterministisch aus dem Mnemonic; dieselbe Seed erzeugt dieselbe DID. Wenn die
DID sich dennoch ändert, liegt die Ursache außerhalb des geprüften Dart-Codes
(z. B. Keystore-/Secure-Storage-Verhalten der Plattform). Siehe Blindstellen.

**Zombie-Beitrittsanfragen:** **Bestätigt (Teil-Ursache).** `handleCellDeleted`
räumt lokal auf, aber ein Antragsteller entfernt seine offene Anfrage
(`_myRequests`) nur, wenn ihn das Auflösungs-Event (Kind-30000 `deleted=true`)
erreicht. Ohne Zustellung bleibt die Anfrage „ausstehend".

**Cross-Device-Inkonsistenz in sechs Bereichen:** Für zwei davon
(Nachrichten-Löschungen, Emoji-Reaktionen) ist F-001 die konkrete Ursache.

---

## Funde

### [Blockiert produktiven Release] F-001 — Chat-/Kanal-Reaktionen und -Löschungen nutzen UUID statt Event-ID im `e`-Tag

- **Schwere:** Blockiert produktiven Release
- **Schwerpunkt:** 3 (Nostr-Protokollkonformität)
- **Datei(en):** [nostr_transport.dart:549](../../../lib/core/transport/nostr/nostr_transport.dart#L549) (`publishDeletion`), [nostr_transport.dart:720](../../../lib/core/transport/nostr/nostr_transport.dart#L720) (`publishReaction`), [nostr_transport.dart:527](../../../lib/core/transport/nostr/nostr_transport.dart#L527) (`publishChannelMetadata`); Aufrufer [chat_provider.dart:2077](../../../lib/features/chat/chat_provider.dart#L2077) und [chat_provider.dart:2345](../../../lib/features/chat/chat_provider.dart#L2345)
- **Was ist falsch:** `publishReaction(messageId, …)` und `publishDeletion(messageId)` schreiben `['e', messageId]`. `messageId` ist die `NexusMessage.id` bzw. `GroupChannel.id` — beides UUIDs im Format `xxxxxxxx-xxxx-…` (36 Zeichen), erzeugt von `NexusMessage._generateId` ([nexus_message.dart:185](../../../lib/core/transport/nexus_message.dart#L185)). Ein NIP-01-`e`-Tag muss aber eine 64-Hex-Event-ID sein. `publishChannelMetadata` (Kind-41) hat denselben Fehler mit `channelData['id']`. Dies ist exakt das dreimal aufgetretene Muster, nur in den Chat-Pfaden, die — anders als `publishChannelDeletion` — keine `length == 64`-Prüfung besitzen.
- **Wie äußert es sich für den Nutzer:** Auf den konfigurierten Relays (damus/snort/nos.lol) werden diese Kind-7- und Kind-5-Events mit `invalid: unexpected size for fixed-size tag: e` abgewiesen. Emoji-Reaktionen auf Chat-/Kanal-Nachrichten und das Löschen einer Nachricht erscheinen deshalb nie auf dem zweiten Gerät. Das erklärt zwei der bekannten Cross-Device-Inkonsistenzen.
- **Wie reproduzierbar:** Gerät A reagiert mit Emoji auf eine Kanal-Nachricht oder löscht eine eigene Nachricht → Relay-Log zeigt Ablehnung → Gerät B sieht die Reaktion/Löschung nicht. Empfangsseitig ist das Matching (per UUID) korrekt; nur die Zustellung scheitert am Relay.
- **Sicherheit der Einschätzung:** Hoch (Code-Fakt: UUID-Format + fehlende Längenprüfung). Die Relay-Ablehnung ist durch das im Auftrag zitierte Fehlerbild belegt; einzelne Relays könnten toleranter sein.
- **Fix-Prompt:** „In `lib/core/transport/nostr/nostr_transport.dart` verletzen die Methoden `publishDeletion`, `publishReaction` und `publishChannelMetadata` NIP-01, weil sie eine interne UUID (Format `xxxxxxxx-xxxx-…`, 36 Zeichen) als `['e', …]`-Tag setzen. Nostr-`e`-Tags müssen 64-Hex-Event-IDs sein, sonst weisen Relays das Event ab. Ändere die drei Methoden so, dass sie die reale 64-Hex-Nostr-Event-ID der ursprünglichen Nachricht bzw. des Kanals im `e`-Tag verwenden (analog zu `publishChannelDeletion`, das bereits auf `nostrEventId.length == 64` prüft und den Wert nur dann einfügt). Die Chat-Nachrichten müssen dafür ihre publizierte Nostr-Event-ID persistieren (analog zu `group_channels.nostr_event_id` und `feed_posts.nostr_event_id`); nutze diese als `e`-Tag. Fällt keine gültige 64-Hex-ID vor, sende das Event nicht mit einem UUID-`e`-Tag, sondern lasse es entweder aus oder verwende einen dokumentierten Custom-Tag. Ändere nur diese eine Sache (e-Tag-Korrektheit in den Chat-Pfaden)."

---

### [Blockiert produktiven Release] F-002 — `eligibleVoters`-Snapshot wird nie gesetzt; Beteiligungs-Nenner ist geräteabhängig

- **Schwere:** Blockiert produktiven Release
- **Schwerpunkt:** 2 (Governance-Korrektheit)
- **Datei(en):** [proposal_service.dart:691](../../../lib/features/governance/proposal_service.dart#L691) (`startVoting`, setzt Snapshot nicht), Nutzung in [proposal_service.dart:846](../../../lib/features/governance/proposal_service.dart#L846), [proposal_service.dart:1002](../../../lib/features/governance/proposal_service.dart#L1002), [proposal_service.dart:1222](../../../lib/features/governance/proposal_service.dart#L1222); Modell [proposal.dart:105](../../../lib/features/governance/proposal.dart#L105)
- **Was ist falsch:** Das Feld `Proposal.eligibleVoters` (DB-Spalte `eligible_voters_json`, Migration v22) soll beim Übergang DISCUSSION→VOTING die stimmberechtigten DIDs einfrieren. Eine Suche über die gesamte Codebasis zeigt: `eligibleVoters` wird **nur gelesen und serialisiert, nie zugewiesen** (`grep "eligibleVoters =" lib` → einziger Treffer ist die Serialisierung in `toMap`). `startVoting` setzt Status, `votingStartedAt`, `votingEndsAt` — aber nicht den Snapshot. Der Kommentar in `proposal.dart:104` („Wird in Phase 4.x … gesetzt") beschreibt einen nicht implementierten Zustand. Damit ist `p.eligibleVoters` in Produktion immer `null`, und alle drei Auszählpfade nehmen den Fallback `_loadEligibleVoterSet(cellId)` = aktuelle `cell_members`.
- **Wie äußert es sich für den Nutzer:** Der Beteiligungs-Nenner und damit die Quorumsprüfung werden zur Auszählzeit aus der momentanen (geräteabhängigen) Mitgliederzahl gebildet. Da laut TD-33 Android und Windows unterschiedliche Mitgliederzahlen sehen und die Auswertung (`finalizeProposal`) vom Scheduler auf **jedem** Gerät läuft, können zwei Geräte, die kurz nacheinander finalisieren, verschiedene Beteiligungswerte, verschiedene Quorumsergebnisse und verschiedene `content_hash`-Werte erzeugen. Jedes Gerät persistiert seinen eigenen DecisionRecord; ein später eintreffender fremder Record wird als „already exists" verworfen — die Geräte bleiben dauerhaft uneins. Das bricht zusätzlich die Hash-Kette (`previousDecisionHash`) für die Zelle.
- **Wie reproduzierbar:** Zelle mit divergenter Mitgliederliste (TD-33), Antrag in VOTING_ENDED, Grace-Period läuft ab, während beide Geräte online sind → beide Scheduler finalisieren, bevor sie den fremden Kind-31013 empfangen → unterschiedliche `resultParticipation`/`result` in den lokalen DBs.
- **Sicherheit der Einschätzung:** Hoch, dass der Snapshot nie gesetzt wird (Code-Fakt). Mittel für die reale Häufigkeit der Ergebnis-Divergenz — sie erfordert nahezu gleichzeitige Finalisierung auf zwei Geräten mit abweichender Mitgliedersicht; im Normalfall finalisiert ein Gerät zuerst und die anderen übernehmen dessen Record.
- **Fix-Prompt:** „In `lib/features/governance/proposal_service.dart`, Methode `startVoting`, wird der stimmberechtigten-Snapshot `Proposal.eligibleVoters` nie gesetzt, obwohl die Auszähllogik (`finalizeProposal`, `_finalizeSingleChoice`, `_finalizeCandidateChoice`) ihn als eingefrorenen Nenner erwartet und sonst auf die Live-Mitgliederzahl zurückfällt. Ergänze `startVoting` so, dass beim Übergang DISCUSSION→VOTING die Menge der aktuell bestätigten Mitglieder-DIDs der Zelle ermittelt (analog `_loadEligibleVoterSet(cellId)`, nur bestätigte Mitglieder) und in `p.eligibleVoters` geschrieben wird, bevor `_saveProposalToDb(p)` läuft. Der Wert wird bereits korrekt über `Proposal.toMap()` (`eligible_voters_json`) persistiert und über das Kind-31010-Event verteilt, falls dort vorgesehen — prüfe das, aber ändere nur das Setzen des Snapshots in `startVoting`."

---

### [Blockiert produktiven Release] F-003 — Wiederhol-Versand des Entscheidungs-Datensatzes verliert v1.3-Felder

- **Schwere:** Blockiert produktiven Release
- **Schwerpunkt:** 4 (Verteilung/Nebenläufigkeit) / 2 (Governance)
- **Datei(en):** [proposal_service.dart:3164-3196](../../../lib/features/governance/proposal_service.dart#L3164) (`_processRetryQueue`, Decision-Record-Zweig)
- **Was ist falsch:** Beim Erstversand baut `_buildRecordContent` ([proposal_service.dart:1547](../../../lib/features/governance/proposal_service.dart#L1547)) ein vollständiges Payload inklusive `votingMode`, `resultReason`, `resultRelation`, `previousProposalId`, `optionResultsJson`, `tieOptionIdsJson` und `selectedOptionId` je Stimme. Der Retry-Zweig baut das Payload jedoch neu und **weglässt** genau diese v1.3-Felder — er enthält nur `proposalId, finalTitle, finalDescription, result, yesVotes, noVotes, abstainVotes, participation, decidedAt, allVotes(ohne selectedOptionId)`. Der mitgesendete `content_hash`-Tag bleibt aber `record.contentHash` (über die vollständigen Felder berechnet).
- **Wie äußert es sich für den Nutzer:** Nur relevant, wenn der Erstversand vollständig fehlschlug (0 Relays akzeptiert) und ausschließlich der Retry ankommt. Dann sehen Empfänger bei SINGLE_CHOICE-/CANDIDATE_CHOICE-Abstimmungen kein Optionsergebnis und keine Stichwahl-Information (`tieOptionIdsJson` fehlt → keine automatische Stichwahl-Auslösung beim Empfänger), und ein `content_hash`, der nicht zum übertragenen Inhalt passt (spätere Verifikation schlägt fehl).
- **Wie reproduzierbar:** Antrag im SINGLE_CHOICE-Modus finalisieren, während keine Relay-Verbindung besteht → Erstversand scheitert → nach Reconnect greift der Retry → Empfänger erhält Decision-Record ohne `optionResultsJson`/`tieOptionIdsJson`.
- **Sicherheit der Einschätzung:** Hoch (Code-Fakt: die Feldliste im Retry ist nachweislich unvollständig gegenüber `_buildRecordContent`).
- **Fix-Prompt:** „In `lib/features/governance/proposal_service.dart`, Methode `_processRetryQueue`, baut der Decision-Record-Retry-Zweig (Zweig `pendingResult.eventKind == 31013`) das `recordContent`-Payload manuell und lässt die v1.3-Felder `votingMode`, `resultReason`, `resultRelation`, `previousProposalId`, `optionResultsJson`, `tieOptionIdsJson` sowie `selectedOptionId` je Stimme weg. Dadurch weicht das erneut gesendete Payload vom Original ab und passt nicht mehr zum `content_hash`. Ersetze den manuellen Payload-Aufbau im Retry durch einen Aufruf von `_buildRecordContent(...)` mit demselben Proposal und Record (bzw. rekonstruiere die identische Feldmenge), sodass Retry und Erstversand byte-identischen Inhalt erzeugen. Ändere nur diesen Zweig."

---

### [Später] F-004 — Background-Isolate leitet Nostr-Keys aus leerem Seed ab, wenn Cache fehlt

- **Schwere:** Später
- **Schwerpunkt:** 5 (Kryptografische Korrektheit)
- **Datei(en):** [background_service.dart:135](../../../lib/services/background_service.dart#L135); Ableitung [nostr_keys.dart:49](../../../lib/core/transport/nostr/nostr_keys.dart#L49)
- **Was ist falsch:** `nostrKeys = await NostrKeys.loadOrDerive(Uint8List(0))` übergibt einen leeren Seed. `loadOrDerive` gibt zwischengespeicherte Keys zurück, wenn `nostr_private_key` **und** `nostr_public_key` im Secure Storage liegen; andernfalls leitet es aus dem übergebenen Seed ab — hier also aus einem 0-Byte-Seed — und **schreibt** diese falschen Keys in den Secure Storage. Der aufrufende Guard prüft nur `pubKeyHex != null` (= `nostr_public_key`), nicht den Private-Key. Bei einem partiellen Cache-Zustand (Public vorhanden, Private fehlt) entstünde eine falsche, persistierte Nostr-Identität.
- **Wie äußert es sich für den Nutzer:** Im Normalfall harmlos (beide Keys liegen nach dem ersten Start vor). Im seltenen Teilverlust-Fall würde das Background-Isolate eine deterministisch falsche Identität ableiten und speichern, was Presence/DM-Empfang im Hintergrund stören kann.
- **Wie reproduzierbar:** Nicht ohne gezielte Manipulation des Secure Storage reproduzierbar; rein aus dem Code abgeleitet.
- **Sicherheit der Einschätzung:** Vermutung (Edge-Case, hängt vom Plattformverhalten des Secure Storage ab).
- **Fix-Prompt:** „In `lib/services/background_service.dart` wird `NostrKeys.loadOrDerive(Uint8List(0))` mit leerem Seed aufgerufen. Falls der Key-Cache im Secure Storage unvollständig ist (Public vorhanden, Private fehlt), leitet `loadOrDerive` aus dem 0-Byte-Seed falsche Keys ab und persistiert sie. Ändere die Stelle so, dass im Background-Isolate ausschließlich bereits gecachte Keys geladen werden: Lies `nostr_private_key` und `nostr_public_key` direkt aus dem Secure Storage und rekonstruiere `NostrKeys` nur, wenn beide vorhanden sind; andernfalls überspringe die Nostr-Verbindung im Hintergrund, statt aus einem leeren Seed abzuleiten. Ändere nur diese eine Stelle."

---

### [Später] F-005 — `castVote` kann Stimme mit leerem `voterPubkey` speichern (UNIQUE-Kollision)

- **Schwere:** Später
- **Schwerpunkt:** 2 (Governance-Korrektheit)
- **Datei(en):** [proposal_service.dart:1771](../../../lib/features/governance/proposal_service.dart#L1771); DB-Constraint [pod_database.dart:348](../../../lib/core/storage/pod_database.dart#L348)
- **Was ist falsch:** `final myPubkey = getMyNostrPubkeyHex?.call() ?? '';` — ist der Nostr-Transport (bzw. der Callback) noch nicht initialisiert, wird die Stimme mit `voterPubkey == ''` gespeichert. Die DB-Eindeutigkeit ist `UNIQUE(proposal_id, voter_pubkey)` mit REPLACE-Konfliktverhalten. Stimmten zwei verschiedene Nutzer auf demselben Gerät/Import-Pfad mit leerem Pubkey ab, kollidierten sie auf `(proposal_id, '')` und die zweite Stimme überschriebe die erste.
- **Wie äußert es sich für den Nutzer:** Realistisch nur, wenn abgestimmt wird, bevor der Transport bereit ist. Da Abstimmen Zellmitgliedschaft (und damit i. d. R. einen laufenden Transport) voraussetzt, ist das Fenster klein — aber ein leerer Pubkey unterläuft die Ein-Stimme-pro-Wähler-Garantie.
- **Wie reproduzierbar:** Nicht zuverlässig aus dem Code reproduzierbar; abhängig vom Init-Timing von `getMyNostrPubkeyHex`.
- **Sicherheit der Einschätzung:** Vermutung.
- **Fix-Prompt:** „In `lib/features/governance/proposal_service.dart`, Methode `castVote`, wird `voterPubkey` auf `''` gesetzt, wenn `getMyNostrPubkeyHex` noch keinen Wert liefert. Da die Stimmen-Tabelle `UNIQUE(proposal_id, voter_pubkey)` mit REPLACE nutzt, können so verschiedene Wähler auf `(proposal_id, '')` kollidieren. Ergänze eine Vorbedingung: Ist der eigene Nostr-Pubkey leer, wirf einen aussagekräftigen `StateError` (‚Transport noch nicht bereit — Stimme kann nicht sicher abgegeben werden'), statt mit leerem `voterPubkey` zu speichern. Ändere nur diese eine Stelle."

---

## Beobachtungen

- `LOGIK_AUDIT.md` und `nexus_codebase_audit_v0111.txt` sind unversioniert und
  inhaltlich überholt (falsche Datei/Zeilen-Referenzen, „Proposals ohne
  Nostr-Sync" trifft nicht mehr zu) — Widerspruch Code↔Dokumentation.
- `lib.zip` **ist versioniert** (`git ls-files` listet es) und enthält ein
  vollständiges Archiv des `lib/`-Verzeichnisses (166 Dateien, Stand
  März/April 2026). Ein eingecheckter Snapshot des Quellbaums im Repository
  ist ungewöhnlich und kann bei Suchen/Tools zu Verwechslungen führen.
- `finalizeProposal` läuft über den Scheduler auf jedem Gerät; die
  Idempotenz-Absicherung ist rein lokal (DB-Record-Existenz), nicht
  geräteübergreifend — die eigentliche Determinismus-Absicherung hängt an
  F-002.
- Backup/Restore stellt Zellen (`Cell.toJson()`), aber keine
  `cell_members`-Einträge wieder her; nach Restore ist man ggf. lokal kein
  bestätigtes Mitglied der eigenen Zelle (manuelle Reparatur über
  `repairFounderMemberships`).
- `handleIncomingDecisionRecord` schreibt den empfangenen Record nur dann in
  das lokale Proposal, wenn `_proposals[proposalId] != null`; ist das Proposal
  lokal unbekannt, bleibt der Record „verwaist" gespeichert, ohne Statusupdate.
- Android-`AndroidManifest.xml` setzt kein `android:allowBackup="false"` und
  keine `dataExtractionRules` — Standard-Auto-Backup-Verhalten ist damit nicht
  explizit gesteuert (relevant für die Identitäts-/Keystore-Frage, nicht
  abschließend geprüft).

## Blindstellen

- **DID-Wechsel nach Reset+Restore:** Statisch ist die Ableitung deterministisch
  (gleicher Seed → gleiche DID). Die Ursache des gemeldeten DID-Wechsels liegt,
  wenn real, im Laufzeit-/Plattformverhalten von `flutter_secure_storage` und
  dem Android-Keystore — das kann ich ohne Gerät und Logs nicht beurteilen.
- **Reale Relay-Toleranz:** Ob einzelne der konfigurierten Relays nicht-konforme
  `e`-Tags (F-001) doch akzeptieren, lässt sich nur mit Live-Relay-Antworten
  bestätigen; die Einschätzung stützt sich auf das im Auftrag zitierte
  Fehlerbild.
- **Tatsächliche Ergebnis-Divergenz (F-002):** Wie oft zwei Geräte real
  gleichzeitig finalisieren, hängt vom Scheduler-Timing und der Netzlage ab und
  ist nur im Live-Test mit zwei Geräten messbar.
- **Windows-spezifische Ablage (Schwerpunkt 5):** Ich habe die Dart-seitigen
  Pfade (`getApplicationDocumentsDirectory`, `USERPROFILE\Documents\NEXUS`) und
  die deterministische Schlüsselableitung geprüft; die native Windows-Runner-
  Konfiguration unter `windows/` habe ich nicht vollständig gelesen.
- **UI-Schichten:** `*_screen.dart`-Dateien wurden nur punktuell gelesen; der
  Fokus lag auf Service-/Transport-/Storage-Logik gemäß Auftrag.
- **Testausführung:** Tests wurden gemäß Auftrag nur gelesen, nicht ausgeführt;
  Aussagen zur Testabdeckung beruhen auf statischer Sichtung.
