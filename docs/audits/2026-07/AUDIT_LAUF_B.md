# Audit Lauf B — Strategischer Review, N.E.X.U.S. OneApp v0.2.0-alpha

Erstellt am: 2026-07-09
Status: GEPARKT — nicht vor Abschluss der Testphase umsetzen

---

## Zusammenfassung

Der Code ist handwerklich für ein Alpha-Projekt ordentlich; die Schwächen
liegen nicht im Detail, sondern in einer Kluft zwischen dem, was die
Dokumente zusichern, und dem, was der Code durchsetzt. Diese Kluft ist genau
das Muster, das Lauf A aufgedeckt hat, nur größer: Die App verspricht
Manipulationssicherheit, Nachprüfbarkeit und Unausschließbarkeit — und setzt
davon zentrale Teile nicht durch.

Wenn ich nur drei Dinge sagen dürfte:

**Erstens:** Eingehende Nostr-Events werden **nirgends signaturgeprüft**
(`verify()` hat null Aufrufer im Produktivcode). Damit ist jede Zusicherung
über „unveränderliche", „manipulationssichere" Abstimmungsergebnisse an der
entscheidenden Stelle — dem Empfang auf dem fremden Gerät — nicht abgesichert.
Konkret kann heute jede Person, die eine Gemeinschafts-ID kennt (sie steht
offen im Netz), per gefälschtem Auflösungs-Event **die Gemeinschaft auf allen
Geräten löschen**. Das ist das Gegenteil des Charta-Versprechens „niemand darf
ausgeschlossen werden".

**Zweitens:** Abstimmungen sind nicht so privat und nicht so gleich, wie die
Bedienungsanleitung nahelegt. Stimmen, Anträge, Ergebnisse und
Delegationen liegen als **Klartext-JSON mit DID und Pseudonym auf öffentlichen
Relays**; die Stimmberechtigung des Absenders wird bei der Auszählung nicht
geprüft. Die Bedienungsanleitung behauptet „NIP-44"-Verschlüsselung und
„niemand außer dir" — der Code liefert das für den Governance-Teil nicht.

**Drittens:** Der billigste ehrliche Weg nach vorn ist meist nicht neuer Code,
sondern ehrlichere Dokumentation. Die **Webseite ist bereits vorbildlich
vorsichtig formuliert** („soll", „Ziel ist", Alpha-Hinweis). Genau dieser Ton
fehlt in Bedienungsanleitung und README. Die Aussagen dort auf das Niveau der
Webseite zu senken, kostet Stunden statt Wochen und beseitigt die gefährlichste
Klasse von Versprechen, ohne eine Zeile Krypto zu schreiben.

Keine dieser Empfehlungen darf die Behebung der Lauf-A-Funde oder die
Testphase verzögern. Die Testphase mit rund zwanzig vertrauten Menschen ist
ohnehin das falsche Umfeld, um die hier genannten Angriffe zu fürchten — sie
werden erst relevant, wenn Fremde und Gegner ins Spiel kommen.

---

## Achse 1 — Versprechen gegen Wirklichkeit

Grundsätzliche Beobachtung vorab: Die **Charta** und die **Grundordnung** sind
überwiegend soziale/organisatorische Wertedokumente (Würde, Exit-Recht,
Minderheitenschutz, Ombudsstellen). Das meiste davon ist kein technisches
Versprechen und daher nicht gegen Code prüfbar. Der **Bauplan V13.1** ist ein
Visionsdokument; seine „Blockchain"-Sprache beschreibt eine Fernzukunft, nicht
die heutige App (die App nutzt Nostr + gehashte Datensätze, keine Blockchain).
Ich werte den Bauplan deshalb nur dort, wo er konkrete, bereits gebaute
Eigenschaften behauptet. Die konkreten, prüfbaren Zusicherungen konzentrieren
sich in **Bedienungsanleitung** und **README** — den Texten, die mit der App
ausgeliefert werden.

### V-001 — „Der Decision Record kann nicht verändert, gelöscht oder schöngeredet werden"

- **Zusicherung:** Bedienungsanleitung v0.2.0-alpha, Kap. 11: „Nach jeder
  abgeschlossenen Abstimmung wird automatisch ein **unveränderlicher** Decision
  Record erstellt. … Eine Hash-Kette zur Manipulationserkennung … *Der Decision
  Record kann nicht verändert, gelöscht oder schöngeredet werden.*" Ebenso zum
  Audit-Log: „das vollständige, **unveränderliche** Protokoll".
- **Wirklichkeit im Code:** Beim Empfang (`proposal_service.dart:2860`) wird der
  `content_hash` unbesehen aus dem Event-Tag übernommen und **nie neu berechnet
  oder gegen den Inhalt geprüft**. Die Hash-Kette wird auf der Empfängerseite
  nirgends verifiziert. Der Datensatz wird lokal mit
  `ConflictAlgorithm.replace` gespeichert (`pod_database.dart:2454`) und ist
  über `deleteDecisionRecord`/`deleteAllProposalDataForCell` lokal löschbar. Zwei
  Geräte können laut Lauf A (F-002) divergierende Datensätze erzeugen.
- **Art der Lücke:** Fiktion (bezogen auf „Manipulationserkennung"/„kann nicht
  verändert werden"); Teilerfüllung (lokal existiert eine Hash-Kette, sie wird
  nur nicht durchgesetzt).
- **Gewicht:** Hoch. Dies ist wörtlich derselbe Fehlertyp wie in Lauf A: eine
  Sicherheitsgarantie, die im Text steht und im Code nicht eingelöst ist. Ein
  technisch versierter Nutzer, der ein gefälschtes Ergebnis einspielt und es
  akzeptiert sieht, verliert das Vertrauen in die gesamte Governance.
- **Sicherheit:** Hoch (Code-Fakt: keine Hash-/Signaturprüfung beim Empfang).
- **Kleinste ehrliche Reaktion:** Aussage abschwächen — z. B. „lokal
  hash-verkettet zur Erkennung *versehentlicher* Abweichungen" statt
  „manipulationssicher/unveränderlich" — ist billiger als die Empfangs-
  Verifikation nachzurüsten. Ehrliche Vollreaktion wäre V-002.

### V-002 — Manipulationssicherheit ohne Signaturprüfung eingehender Events

- **Zusicherung:** Bauplan, u. a. „Jede Entscheidung … nachvollziehbar", „Die
  Blockchain wird zur technologischen Garantie"; Bedienungsanleitung Kap. 11
  „Manipulationserkennung"; README „Du besitzt deine Identität, deine Daten und
  deine Schlüssel — niemand sonst."
- **Wirklichkeit im Code:** `NostrEvent.verify()` (Signatur- und
  ID-Prüfung, `nostr_event.dart:214`) hat **null Aufrufer im Produktivcode**
  (`grep ".verify()" lib` → nur Tests). `nostr_relay_manager.dart` dedupliziert
  nur nach Event-ID und leitet ungeprüft weiter; alle `_handle…`-Handler
  vertrauen `event.pubkey`/`event.content` blind. `handleIncomingVote`/
  `handleIncomingProposal` prüfen nur, ob **ich** Mitglied bin, nicht ob der
  **Absender** berechtigt ist.
- **Art der Lücke:** Fiktion. „Manipulationssicher" ohne Absenderauthentizität
  ist die Kernaussage, die nicht trägt.
- **Gewicht:** Hoch. Ein Angreifer kann Stimmen, Anträge und Decision Records
  fälschen/einschleusen. In der Testphase (nur Vertraute) unkritisch; für einen
  produktiven Release, der Manipulationssicherheit verspricht, ist es die größte
  Einzellücke.
- **Sicherheit:** Hoch.
- **Kleinste ehrliche Reaktion:** Code — `verify()` in `_onRelayEvent` vor der
  Weiterleitung aufrufen. Das ist die günstigste echte Härtung, weil die
  Funktion bereits existiert und getestet ist; nur der Aufruf fehlt. (Zusätzlich
  bräuchte es die Zuordnung Pubkey→berechtigtes Mitglied — teurer, siehe V-005.)

### V-003 — „Niemand darf ausgeschlossen werden" vs. Fern-Löschung jeder Gemeinschaft

- **Zusicherung:** Grundordnung §… „Niemand darf innerhalb von N.E.X.U.S.
  ausgeschlossen … werden"; Charta/Webseite: Zensurresistenz, „nicht von
  zentralen Stellen abhängig"; Bedienungsanleitung: Exit-Recht und
  Selbstbestimmung.
- **Wirklichkeit im Code:** Das Auflösungs-Event einer Gemeinschaft (Kind-30000
  mit `deleted=true`) wird in `_handleCellAnnounceEvent`
  (`nostr_transport.dart:2458`) **ohne Prüfung, ob der Absender der Gründer
  ist**, an `handleCellDeleted` weitergereicht; dort wird die Gemeinschaft auf
  dem Gerät **permanent tombstoned** („NEVER cleared"). Mangels Signaturprüfung
  (V-002) und weil die Gemeinschafts-ID offen im Kind-30000-Announcement steht,
  kann **jede beliebige Person eine fremde Gemeinschaft auf allen Geräten ihrer
  Mitglieder löschen**.
- **Art der Lücke:** Fiktion (bezogen auf Zensurresistenz/Unausschließbarkeit).
- **Gewicht:** Hoch. Das ist ein konkreter, billiger Zerstörungs-/Zensur-
  Vektor gegen genau das zentrale Versprechen der Bewegung.
- **Sicherheit:** Hoch (Code-Fakt: kein Gründer-/Signatur-Check im
  Auflösungspfad).
- **Kleinste ehrliche Reaktion:** Code — Auflösungs-Events nur akzeptieren, wenn
  Signatur gültig **und** `event.pubkey` dem Gründer-Pubkey der Gemeinschaft
  entspricht. Eine reine Textänderung hilft hier nicht, weil das Versprechen
  („niemand kann dich rauswerfen") der Markenkern ist.

### V-004 — „Ende-zu-Ende-verschlüsselt (NIP-44)" vs. Klartext-Governance und NIP-04

- **Zusicherung:** README: „Alle Nachrichten sind Ende-zu-Ende-verschlüsselt.
  … niemand sonst." und Tech-Tabelle „Verschlüsselung: X25519 + **NIP-44**,
  Ed25519, AES-256-GCM"; Chat: „X25519 + AES-256-GCM". Bedienungsanleitung
  Kap. 4: „Immer nur für dich und dein Gegenüber lesbar." Bauplan: „Daten sind
  bereits auf der untersten Ebene verschlüsselt (Ende-zu-Ende)".
- **Wirklichkeit im Code:** Direktnachrichten laufen über **NIP-04**
  (`_nip04Encrypt`, secp256k1-ECDH + **AES-CBC ohne MAC**,
  `nostr_transport.dart:2938` `MacAlgorithm.empty`), nicht über den behaupteten
  X25519+GCM-Pfad und nicht über NIP-44. **NIP-44 ist nirgends implementiert**
  (im Permit-Handler steht sogar ein `TODO(G2): Migrate … to NIP-44`).
  Broadcasts (`_sendBroadcast`, Kind-1) und **alle Governance-Events** (Anträge,
  Stimmen, Ergebnisse, Delegationen — Kind-31010–31013) werden als
  **Klartext-`jsonEncode`** publiziert, inklusive DID und Pseudonym.
- **Art der Lücke:** „NIP-44" = Fiktion. „Alle Nachrichten E2E / niemand außer
  dir" = Teilerfüllung (DMs sind vertraulich verschlüsselt, aber unauthentisch;
  Governance und Broadcasts sind gar nicht verschlüsselt).
- **Gewicht:** Mittel bis hoch. Wer das Wort NIP-44 kennt, prüft es in Minuten
  und findet NIP-04. Für ein Projekt, das Datensouveränität verspricht, ist
  „öffentliche Stimmzettel mit DID" ein empfindlicher Widerspruch.
- **Sicherheit:** Hoch.
- **Kleinste ehrliche Reaktion:** Aussage ändern — „NIP-44" streichen, „NIP-04"
  bzw. „unverschlüsselte, aber signierte Governance-Events auf öffentlichen
  Relays" offen benennen. Das ist deutlich billiger als eine NIP-44-Migration
  plus Verschlüsselung der Governance-Schicht.

### V-005 — „8 Stimmen von 10 Stimmberechtigten": Gleichheit und Einmaligkeit nur teilweise durchgesetzt

- **Zusicherung:** Bedienungsanleitung Kap. 11: „Beteiligung: 80% (8 Stimmen
  von 10 Stimmberechtigten)"; Grundordnung §18 Liquid Democracy verlangt
  „Delegationsbegrenzung, Delegation Decay, … Minderheitenschutz".
- **Wirklichkeit im Code:** Die Auszählung zählt **direkte Stimmen ungefiltert**
  (`finalizeProposal`, `proposal_service.dart:868`) — es gibt **keine Prüfung,
  ob der Wähler zum eingefrorenen Stimmberechtigten-Kreis gehört** (nur
  Delegationen werden gegen `eligibleVoters` geprüft, Zeile 3632). Der Nenner
  „Stimmberechtigte" ist laut Lauf A (F-002) nie eingefroren. „Delegation Decay"
  und eine Delegationsbegrenzung sind nicht implementiert (Delegation ist
  immerhin nicht-transitiv, wodurch keine Ketten entstehen).
- **Art der Lücke:** Teilerfüllung. Einmaligkeit pro Nostr-Pubkey ist per
  DB-Constraint gegeben; „nur Berechtigte", „fester Nenner" und „Decay" fehlen.
- **Gewicht:** Mittel. In vertrauten Gruppen unkritisch; sobald jemand
  Nicht-Mitglieds-Stimmen einspeist oder der Nenner geräteabhängig kippt, wird
  die angezeigte Beteiligung falsch.
- **Sicherheit:** Hoch (Fehlen des Wähler-Filters ist ein klarer Code-Fakt);
  „Decay"-Fehlen ist eine Anforderung der Grundordnung, kein App-Versprechen —
  daher schwächer zu werten.
- **Kleinste ehrliche Reaktion:** Überschneidet sich mit Lauf-A-F-002 (Nenner
  einfrieren) und V-002 (Absenderberechtigung). Textlich nichts zu retten — die
  Beteiligungszahl muss korrekt sein oder gar nicht angezeigt werden.

### V-006 — Delegation „ohne unnötig persönliche Daten offenzulegen"

- **Zusicherung:** Grundordnung §17: Delegation soll „widerrufbar, begrenzt und
  transparent nachvollziehbar sein, **ohne unnötig persönliche Daten
  offenzulegen**"; §22 Digitale Souveränität.
- **Wirklichkeit im Code:** Kind-31012-Delegations-Events tragen
  `delegatorDid` **und** `delegateDid` im Klartext-Content auf öffentliche
  Relays (`nostr_transport.dart`, Delegations-Publish; Content-Aufbau in
  `_publishDelegationToNostr`/`proposal_service.dart`). Wer an wen delegiert, ist
  damit weltweit lesbar und dauerhaft.
- **Art der Lücke:** Teilerfüllung/Fiktion — das Vertrauensnetz der Delegationen
  ist vollständig öffentlich.
- **Gewicht:** Mittel. Delegationsmuster sind sozial sensibel (wer wem folgt);
  ihre dauerhafte Öffentlichkeit widerspricht der Zusicherung direkt.
- **Sicherheit:** Hoch (Code-Fakt).
- **Kleinste ehrliche Reaktion:** Aussage präzisieren (Delegationen sind
  öffentlich) oder — teurer — Governance-Events verschlüsseln.

### V-007 — „Digitale Souveränität … nicht abhängig von Servern, Firmen, Entwicklern, Administratoren"

- **Zusicherung:** Grundordnung §22: „N.E.X.U.S. nicht von einzelnen
  Plattformen, Servern, Firmen, Staaten, Entwicklern oder Administratoren
  abhängig werden darf." Webseite: „nicht von einzelnen Konzernen oder zentralen
  Stellen abhängig".
- **Wirklichkeit im Code:** Vier **fest verdrahtete öffentliche Relays**
  (`nostr_relay_manager.dart:11`: damus, snort, nos.lol, nostr.band). Ein
  **Superadmin-DID** und `bootstrapCellAuthors` (`system_config.dart`), sowie ein
  **Gründungs-Permit-System** (Kind-31006), das nur von Admin-Pubkeys akzeptiert
  wird (`nostr_transport.dart:2179`). Faktisch bestehen Abhängigkeiten von
  fremden Servern und von Administrator-Rollen.
- **Art der Lücke:** Teilerfüllung. Nutzer können eigene Relays hinzufügen; die
  Voreinstellung und die Rollenlogik schaffen dennoch reale Abhängigkeiten.
- **Gewicht:** Mittel. Für Alpha akzeptabel; das Versprechen der Unabhängigkeit
  ist aber ein Kernwert und sollte nicht überzeichnet werden.
- **Sicherheit:** Hoch (Code-Fakt der Default-Relays/Rollen); die Bewertung als
  „Abhängigkeit" ist meine Einschätzung.
- **Kleinste ehrliche Reaktion:** Text — offenlegen, dass Standard-Relays
  öffentliche Drittserver sind und eine Admin-Ebene existiert.

### V-008 — Backup: „Gerät wechseln → Daten zurück"

- **Zusicherung:** Bedienungsanleitung Kap. 14: „Wenn du das Gerät wechselst
  oder die App neu installierst, holst du deine Daten mit dem Backup zurück."
- **Wirklichkeit im Code:** Das Backup umfasst Kontakte, Kanal-/
  Zellen-Mitgliedschaften, Profil, Einstellungen — **nicht Nachrichten, Bilder,
  Sprachnachrichten** (die Tabelle im selben Kapitel sagt das ehrlich). Zusätzlich
  stellt `CellService.restoreFromBackup` nur die Zelle her, **nicht die
  `cell_members`** (Lauf A, Beobachtung) — nach Restore ist man ggf. lokal kein
  bestätigtes Mitglied der eigenen Gemeinschaft.
- **Art der Lücke:** Formulierungsfrage (die Ausschluss-Tabelle ist korrekt) mit
  einem Teilerfüllungs-Kern (fehlende Mitgliedschaften nach Restore).
- **Gewicht:** Niedrig bis mittel. Nutzer, die „Daten zurück" wörtlich nehmen,
  vermissen ihren Chat-Verlauf; das ist eher Enttäuschung als Schaden.
- **Sicherheit:** Hoch für den Umfang; mittel für die konkrete Mitgliedschafts-
  Auswirkung (aus Code abgeleitet).
- **Kleinste ehrliche Reaktion:** Satz präzisieren („deine Kontakte, Kanäle und
  Gemeinschaften — nicht deinen Nachrichtenverlauf").

**Positivbefund zu Achse 1:** Die **Webseite** (nexus-terminal.org) formuliert
durchweg vorsichtig („soll", „Ziel ist", „kann") und weist ausdrücklich auf den
Alpha-Status hin. Die exponierteste öffentliche Fläche überverspricht also
gerade **nicht**. Das Problem sitzt in den mitgelieferten Texten (README,
Bedienungsanleitung) und im Visionston des Bauplans.

---

## Achse 2 — Architektur-Risiken

- **Auszählung auf jedem Gerät (Multi-Tally-Owner).** Der Scheduler finalisiert
  auf jedem Gerät; die Idempotenz ist nur lokal. *Betroffen:*
  `proposal_scheduler.dart`, `finalizeProposal`. *Beißt ab:* sobald zwei Geräte
  pro Person üblich sind — also faktisch sofort in der Android/Windows-Testphase.
  *Stoßrichtung:* deterministische, einfrierende Auszählung (überschneidet
  Lauf-A-F-002).
- **Kein Vertrauensanker beim Empfang.** Ohne Signatur-/Berechtigungsprüfung ist
  die Vertrauensgrenze „jeder auf dem Relay". *Beißt ab:* beim ersten Gegner.
  *Stoßrichtung:* Events authentifizieren, bevor sie Zustand ändern.
- **Vier fest verdrahtete Relays.** Single Points of Failure und Zensur. *Beißt
  ab:* wenn ein Relay Nexus-Tags filtert, überlastet oder offline ist.
  *Stoßrichtung:* Relay-Satz konfigurierbar/erweiterbar halten und nicht als
  „dezentral" verkaufen.
- **Governance als ersetzbare Nostr-Events mit `since`-Fenstern (7/30 Tage).**
  Korrektheit von Verlauf und Auszählung hängt an Relay-Aufbewahrung und
  Timing. *Beißt ab:* sobald ein Mitglied länger offline ist als das Fenster.
  *Stoßrichtung:* Vollständigkeit der Governance-Historie nicht von Relay-
  Retention abhängig machen.
- **Idempotenz über SharedPreferences-Flags** (`runoff_created…`,
  `…_migrated…`). Pro Gerät, bei Daten-Reset verloren. *Beißt ab:* nach Reset
  oder auf dem Zweitgerät — dann z. B. doppelte Stichwahlen möglich.
  *Stoßrichtung:* geräteübergreifende Idempotenz-Schlüssel.
- **Klartext-Governance dauerhaft öffentlich.** DID + Pseudonym + Stimme bleiben
  auf Relays liegen. *Beißt ab:* an der Grundordnung §15 (Löschung/
  Anonymisierung) und an jeder Datenschutzerwartung, sobald Nicht-Vertraute
  mitmachen. *Stoßrichtung:* entscheiden, was wirklich öffentlich sein muss.
- **In der App ausgelieferte Reparatur-/Debug-Primitive** (`nuclearWipe`,
  `claimDiscoveredCell`, `repairFounderMemberships`, `deleteAllCellChannels`).
  Mächtige Fußangeln. *Beißt ab:* wenn ratlose Tester sie als „Fix" benutzen.
  *Stoßrichtung:* aus der Nutzer-UI heraushalten.

---

## Achse 3 — Weg zur Produktionsreife

**Zwingend, in dieser Reihenfolge:**

1. **Lauf-A-Funde F-001 (e-Tag im Chat) und F-002 (Stimmberechtigten-Snapshot)**
   beheben. Hat bereits Vorrang; steht hier nur der Vollständigkeit halber.
2. **Signaturprüfung beim Empfang** (`verify()` in `_onRelayEvent`, vor jeder
   Zustandsänderung). Schließt V-002 und ist Voraussetzung für 3.
3. **Autorisierung zustandsverändernder Governance-Events** — insbesondere
   Gemeinschafts-Auflösung nur vom Gründer-Pubkey; Stimmen/Anträge nur von
   bestätigten Mitgliedern (V-003, V-005).
4. **Dokumente auf die Wirklichkeit senken** — README und Bedienungsanleitung
   auf den vorsichtigen Ton der Webseite bringen (V-001, V-004, V-006, V-007,
   V-008). Billigster Schritt mit der größten Wirkung gegen „Fiktion".
5. **Stimmberechtigten-Zahl in den Decision Record einfrieren** und den
   `content_hash` beim Empfang neu berechnen/prüfen (V-001, TD-34).
6. **Entscheiden, ob Governance-Events vertraulich sein müssen** — falls ja,
   Verschlüsselung/DID-Sparsamkeit; falls nein, ehrlich als öffentlich benennen
   (V-004, V-006).

**Was fälschlich für nötig gehalten wird:**

- Eine eigene Blockchain / Substrate (README-Roadmap „Phase 1c"). Für die
  versprochene Nachprüfbarkeit genügt die vorhandene Hash-Kette **plus
  Signaturprüfung**; eine Blockchain löst hier kein reales Problem und bindet
  Ressourcen, die es nicht gibt.
- Reticulum-/Mesh-Ausbau und die P2P-Zweitsprachen-Brücke vor dem Release
  (siehe Achse 4).
- NIP-44-Migration als vorrangige Aufgabe — die ehrliche Textkorrektur (Schritt
  4) entschärft das Versprechen sofort; die Migration kann später folgen.
- Ausbau der Testabdeckung/CI-Härtung als Release-Blocker — 600+ Tests
  existieren; die offenen Punkte sind Design-, keine Regressionsfragen.

---

## Achse 4 — Mitwirkende und Wartbarkeit

**Einstiegshürden (Beobachtung):**

- Zwei „Gott-Dateien": `proposal_service.dart` (4097 Zeilen) und
  `nostr_transport.dart` (2976 Zeilen) tragen die meiste Logik und sind für
  Neueinsteiger schwer zu überblicken.
- Sehr dichtes `print`-Logging (Diagnose-Präfixe) mischt sich mit der
  Fachlogik; Deutsch und Englisch wechseln. Keine Übersichtskarte, welche
  Nostr-Kind-Nummer zu welchem Handler gehört (die Zuordnung liegt implizit in
  `_onRelayEvent`).
- `CLAUDE.md` ist als KI-Leitfaden gut, ersetzt aber keine menschliche
  Architektur-Einführung.
- `lib.zip` (versionierter Snapshot des `lib/`-Baums) stiftet Verwirrung bei
  Suche und Navigation.

**Sicherheits-Nebenbefund (Beobachtung, dringend, außerhalb Achse 1):** Im
Arbeitsverzeichnis des Repositories liegen unter
`audit_docs/1_Techn_.../Meine Seedphrase/` **Klartext-Seedphrases**
(`jo_seddphrase.txt`, `jo_test_seddphrase.txt`) und
`github-recovery-codes.txt`. Der Ordner ist derzeit unversioniert, steht aber
**nicht in `.gitignore`** — ein einziges `git add .` würde diese Geheimnisse
ins öffentliche Repo befördern. Das sollte unabhängig von diesem Review sofort
entschärft werden (Dateien aus dem Repo-Ordner entfernen, `.gitignore`-Eintrag).

**Bus-Faktor:** Effektiv eins. Ein einzelner Mensch ohne Entwickler, der jede
Änderung über ein KI-Werkzeug beauftragt. Das ist mit Geld allein nicht zu
heilen; billig verbessern lässt sich nur die *Übergabefähigkeit* — eine knappe
Architektur-Karte (Kind→Handler→Service) und das Auslagern der Debug-Primitive
senken die Hürde für einen späteren Mitwirkenden spürbar.

**Bewertung der P2P-/Zweitsprachen-Frage (Reticulum):** Der Ordner
`Meshnetzwerke` zeigt, dass es um **Reticulum** geht (Referenz-Stack in
Python, aufkommender Rust-Port). Es gibt keine Dart-native Reticulum-Anbindung.
Eine Einbindung erforderte entweder ein eingebettetes Python-Laufzeitsystem
oder eine **FFI-/Plattform-Kanal-Brücke zu Rust oder Go**, plus
Cross-Compilation für Android **und** Windows und deren dauerhafte Pflege.

Ehrlicher personeller Preis: Das ist **keine Aufgabe, die ein Alleingründer
ohne Entwickler über ein KI-Werkzeug tragfähig wartet.** Eine Sprachbrücke ist
kein einmaliger Aufwand — sie bricht bei jedem Plattform-/SDK-Update erneut, und
Fehler an der FFI-Grenze sind ohne Debugger-Erfahrung in der Zweitsprache kaum
zu diagnostizieren. Realistisch bräuchte es einen dedizierten, in Rust/Go **und**
Reticulum erfahrenen Mitwirkenden mit Dauerverfügbarkeit. Meine Einschätzung:
**vorerst nicht einbinden.** Nostr über die vier Relays plus das bestehende
LAN/BLE deckt die Alpha ab; Reticulum ist ein Kandidat für den Tag, an dem ein
solcher Mitwirkender real existiert — nicht davor.

---

## Die sieben Empfehlungen

### E-1 — Dokumente auf den Ton der Webseite senken

- **Was:** README und Bedienungsanleitung von harten Garantien
  („unveränderlich", „manipulationssicher", „NIP-44", „niemand außer dir") auf
  die vorsichtige, bereits auf der Webseite gelebte Sprache umstellen.
- **Warum jetzt:** Beseitigt die gefährlichste Klasse (Fiktion) ohne Code und
  ohne Risiko; schützt die Glaubwürdigkeit der Bewegung, bevor Fremde die App
  sehen.
- **Frühestens wann:** vor Testphase (reine Textarbeit, kollidiert mit nichts).
- **Kosten:** Wenige Stunden Schreibarbeit; kein Entwicklerwissen nötig.
- **Stärkstes Gegenargument:** Vorsichtigere Sprache kann die App weniger
  überzeugend wirken lassen und die Mittelbeschaffung erschweren — gerade jetzt,
  wo Geld knapp ist. Man verkauft dann eine ehrliche Alpha statt einer
  glänzenden Vision.

### E-2 — Seedphrase/Recovery-Codes aus dem Repo-Ordner entfernen

- **Was:** Die Klartext-Geheimnisse unter `audit_docs/…/Meine Seedphrase/` aus
  dem Repository-Arbeitsverzeichnis herausnehmen und `audit_docs/` in
  `.gitignore` eintragen.
- **Warum jetzt:** Ein versehentliches `git add .` legt die eigene Identität und
  GitHub-Zugänge offen — irreversibel, sobald gepusht.
- **Frühestens wann:** vor Testphase (sofort).
- **Kosten:** Minuten.
- **Stärkstes Gegenargument:** Solange nie `git add .` ausgeführt wird, passiert
  nichts; die Maßnahme adressiert ein Risiko, das der Gründer durch Disziplin
  auch vermeiden könnte. (Gegen menschliche Disziplin unter Stress würde ich
  trotzdem nicht wetten.)

### E-3 — Eingehende Events signaturprüfen

- **Was:** In `_onRelayEvent` jedes Event mit dem bereits vorhandenen
  `NostrEvent.verify()` prüfen und bei Fehlschlag verwerfen.
- **Warum später:** In der Vertrauten-Testphase kein akuter Angriff; für einen
  produktiven Release aber die Grundlage jeder Manipulationssicherheit.
- **Frühestens wann:** vor produktivem Release.
- **Kosten:** Überschaubar — die Funktion existiert und ist getestet; es fehlt
  der Aufruf plus Prüfen auf Performance/Altlasten. Ein bis wenige beauftragte
  Änderungen.
- **Stärkstes Gegenargument:** Eine strikte Prüfung kann bestehende, vor dem Fix
  erzeugte oder von abweichenden Clients stammende Events verwerfen und damit
  live Daten „verschwinden" lassen; das muss sorgfältig ausgerollt werden und
  könnte in der Alpha mehr Verwirrung stiften als Nutzen bringen.

### E-4 — Gemeinschafts-Auflösung an den Gründer-Pubkey binden

- **Was:** Auflösungs-Events (Kind-30000 `deleted=true`) nur akzeptieren, wenn
  Signatur gültig und Absender-Pubkey = Gründer-Pubkey der Gemeinschaft.
- **Warum später:** Setzt E-3 voraus; in der Testphase kein Thema, aber der
  Fern-Lösch-Vektor widerspricht dem Kernversprechen direkt.
- **Frühestens wann:** vor produktivem Release (nach E-3).
- **Kosten:** Moderat — erfordert eine verlässliche Zuordnung Gemeinschaft →
  Gründer-Pubkey, die teils schon vorhanden ist (`createdBy`).
- **Stärkstes Gegenargument:** Bindet man Auflösung streng an einen einzigen
  Pubkey, geht die Fähigkeit verloren, „verwaiste" oder von einem verlorenen
  Gründer-Gerät hinterlassene Gemeinschaften wieder loszuwerden — man tauscht
  einen Missbrauchsvektor gegen ein Aufräumproblem.

### E-5 — Architektur-Karte und Debug-Primitive trennen

- **Was:** Ein kurzes Dokument „Kind-Nummer → Handler → Service" schreiben und
  die Reparatur-/Debug-Funktionen (`nuclearWipe`, `claimDiscoveredCell`,
  `repairFounderMemberships` …) aus der regulären Nutzer-UI in einen klar
  getrennten Wartungsbereich verschieben.
- **Warum später:** Senkt Bus-Faktor-Risiko und Fehlbedienung, ist aber kein
  Blocker.
- **Frühestens wann:** nach Testphase.
- **Kosten:** Karte: Stunden. Trennung: moderater, beauftragbarer Umbau.
- **Stärkstes Gegenargument:** Genau diese Primitive haben in der Alpha wieder-
  holt den Tag gerettet, wenn Zustände verklemmt waren; sie jetzt zu verstecken,
  nimmt dem Gründer sein wichtigstes Notfallwerkzeug in der heißen Testphase.

### E-6 — Stimmberechtigten-Zahl in den Decision Record einfrieren und beim Empfang den Hash prüfen

- **Was:** `eligibleVotersCount` als echtes Feld in Modell/DB/Wire aufnehmen und
  beim Empfang eines Decision Records den `content_hash` neu berechnen und
  vergleichen.
- **Warum später:** Baut auf Lauf-A-F-002 auf und macht „Nachprüfbarkeit" erst
  wahr; in der Testphase reicht die F-002-Behebung.
- **Frühestens wann:** vor produktivem Release.
- **Kosten:** Moderat — DB-Migration plus Wire-Format-Erweiterung, mehrere
  koordinierte Änderungen.
- **Stärkstes Gegenargument:** Wire-Format-Änderungen brechen die
  Kompatibilität mit bereits im Netz liegenden v0.2.0-Events; für einen kleinen
  Nutzerkreis ist der Nutzen der echten Verifizierbarkeit womöglich kleiner als
  die Migrationskosten.

### E-7 — Öffentlichkeit der Governance-Daten bewusst entscheiden

- **Was:** Eine bewusste Entscheidung treffen und dokumentieren, ob Stimmen,
  Anträge und Delegationen mit DID/Pseudonym öffentlich sein sollen — und die
  Texte (V-004, V-006) daran ausrichten.
- **Warum später:** Verschlüsselung der Governance-Schicht ist aufwendig; die
  Entscheidung und die ehrliche Benennung sind es nicht.
- **Frühestens wann:** vor produktivem Release (Entscheidung); Umsetzung
  danach.
- **Kosten:** Entscheidung + Text: gering. Technische Umsetzung: hoch.
- **Stärkstes Gegenargument:** Öffentliche, unverschlüsselte Governance ist auch
  ein *Feature* (maximale Transparenz, unabhängige Nachprüfbarkeit durch Dritte).
  Sie zu verschlüsseln, könnte dem Transparenzversprechen der Charta zuwiderlaufen
  — hier stehen zwei Werte des Projekts gegeneinander.

---

## Was ich nicht empfehle, obwohl es naheliegt

- **Eigene Blockchain / Substrate (Rust) bauen.** Die README-Roadmap nennt es.
  Es löst kein Problem, das die vorhandene Hash-Kette plus Signaturprüfung nicht
  billiger löst, und bindet Entwicklerkapazität, die nicht existiert.
- **Reticulum / P2P-Zweitsprachen-Brücke jetzt integrieren.** Der personelle
  Dauerpreis (siehe Achse 4) übersteigt, was ein Alleingründer ohne Entwickler
  tragen kann. Kandidat für „wenn ein passender Mitwirkender da ist", nicht
  davor.
- **Die zwei Gott-Dateien jetzt refaktorieren.** Verlockend für die
  Wartbarkeit, aber ein risikoreicher Umbau ohne Entwickler kurz vor der
  Testphase; die Karte aus E-5 bringt fast denselben Orientierungsnutzen zum
  Bruchteil des Risikos.
- **Testabdeckung/CI zum Release-Kriterium machen.** 600+ Tests existieren; die
  offenen Punkte sind Design-Lücken, keine Regressionslücken. Mehr Tests würden
  die falschen Dinge absichern.

---

## Blindstellen

- **Webseite jenseits der Startseite.** Ich habe die Landingpage geprüft
  (vorsichtig formuliert, Alpha-Hinweis). Unterseiten, Discord/Telegram und
  Videos habe ich nicht gesichtet; dort könnten härtere Versprechen stehen, die
  ich nicht sehe.
- **Bauplan V13.1 (6,6 MB) nur selektiv gelesen.** Ich habe nach den
  technischen Zusicherungen gesucht, nicht das Gesamtdokument bewertet. Der
  überwiegend visionäre Charakter ist meine Einschätzung, keine vollständige
  Lektüre.
- **Charta/Grundordnung als Werte-, nicht Technikdokumente.** Ihre sozialen
  Zusicherungen (Ombudsstellen, Schiedsverfahren, Rehabilitation) sind nicht
  gegen Code prüfbar; ob die App sie organisatorisch einlöst, kann ich nicht
  beurteilen.
- **Reale Relay-Aufbewahrung und -Zensur.** Wie lange die vier Relays Events
  halten und ob sie Nexus-Tags filtern, ist ein Laufzeitfaktor, den ich statisch
  nicht messen kann.
- **Tatsächliche Ausnutzbarkeit der Fern-Löschung (V-003) und Fälschung
  (V-002).** Ich habe die fehlenden Prüfungen im Code belegt; ob ein konkreter
  Relay das Event zustellt und ob es empfangsseitig durchläuft, wäre erst im
  Live-Test mit zwei Geräten endgültig zu bestätigen.
- **Docx-Dokumente** (DAO-Masterarchitektur, Organisationspapier,
  Mitgliedschaftsmodell) habe ich nicht in Text konvertiert gelesen; sie
  betreffen dem Titel nach Organisation, nicht App-Technik.
