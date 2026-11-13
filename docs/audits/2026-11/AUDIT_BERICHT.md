# Audit-Bericht N.E.X.U.S. OneApp – November 2026

Stand: 11. November 2026 · Auftrag: [AUDIT_AUFTRAG.md](AUDIT_AUFTRAG.md)
Geprüft: Zweig `lead/multi-agent` (Commit `45244e5`, 11 Commits vor `main`)
Grundlagen: Charta V3.1, Bauplan V14.0 (Kap. 4, 6, 8.4, 9.0–9.2, 11.4, Anhang D),
`docs/current/`, `docs/decisions/`, `docs/planning/NOW_NEXT_LATER.md`,
Audits Juli 2026.

## Wie dieser Bericht zu lesen ist

- Es wurde **nichts am Code geändert und nichts committet**. Dieser Bericht
  ist die einzige neue Datei.
- Es wurde **nur gelesen**: kein `flutter test`, kein `flutter analyze`, kein
  Gerätelauf. Aussagen über Laufzeitverhalten (Akku, Geschwindigkeit,
  Verhalten am Gerät) sind deshalb *vermutet*, auch wenn der Code sie
  nahelegt.
- Kennzeichnung je Befund:
  - **geprüft ✔** – von der Prüfleitung selbst am Code nachvollzogen.
  - **geprüft** – in einer der vier Teilprüfungen am Code gelesen, mit
    Datei und Zeile belegt, aber nicht ein zweites Mal nachgelesen.
  - **vermutet** – Indiz, nicht bestätigt.
  - **Meinung** – Bewertung.
- Zeilennummern beziehen sich auf den geprüften Commit.
- Nicht prüfbar aus dem Repository: Betrieb des Relays (Sicherung,
  Überwachung, Kosten, Löschpraxis), Farbkontraste, tatsächliche
  Testabdeckung in Prozent, QR-/Einladungs-Parsing im Detail.

---

## 1. Kurzfassung

Die OneApp ist deutlich weiter, als die Dokumente unter `docs/current/`
zeigen: Signaturprüfung, Governance-Autorisierung, Outbox, eigenes Relay und
Mehrgeräte-Abgleich sind seit August dazugekommen und sauber gebaut. Die
Härtung hat aber fast nur die **Governance** erreicht. Der **Messenger** – das
erklärte Hauptprodukt – hat die schwächste Vertrauensgrenze der App.

Die zehn wichtigsten Befunde:

| # | Befund | Prio | Aufwand | Empfehlung |
|---|---|---|---|---|
| 1 | **Jeder kann sich im Chat als ein Kontakt ausgeben und dessen Gespräch auf sich umleiten.** Die Absender-DID einer Direktnachricht und einer Präsenzmeldung wird nicht an den Nostr-Schlüssel gebunden (S-1). | P0 | M | Den vorhandenen Identitätsnachweis (`IdentityProof`, TD-40) auch für DMs, Präsenz und Kanalbeiträge verlangen; Schlüsselwechsel nie still übernehmen |
| 2 | **Ein Mitglied kann mehrfach abstimmen**, indem es mehrere Nostr-Schlüssel an seine DID bindet (S-2). | P0 | S | Stimmen nach `voterDid` deduplizieren (Speicher, DB, Auszählung) |
| 3 | **Eine einzige Nachricht mit Zukunftsdatum lässt ein Gerät dauerhaft Nachrichten verpassen**; nachgereichte Outbox-Nachrichten fallen aus demselben Grund durch (Z-1, Z-2). | P0 | S–M | Zeitmarke auf „jetzt“ begrenzen, mehrere Tage Überlappung beim Abholen |
| 4 | **Android-Release ist mit dem Debug-Schlüssel signiert** (R-1). Geht der Schlüssel verloren, hilft nur Deinstallation – also Verlust der Identität. | P0 | S | Eigenen Release-Keystore anlegen und sichern, solange es wenige Tester gibt |
| 5 | **LAN und BLE prüfen nichts**: Nachrichten-Signaturen werden erzeugt, aber nirgends geprüft; „BLE Mesh“ ist eine Direktverbindung ohne Weiterleitung (S-3, Z-8). | P1 | M | Signaturprüfung an der Empfangsgrenze; Begriff „Mesh“ erst verwenden, wenn weitergeleitet wird |
| 6 | **Private Kanäle sind nur scheinbar privat**: fester Schlüssel ohne Wechsel beim Entfernen, Bilder und Sprachnachrichten gehen unverschlüsselt auf die Relays (S-4). | P1 | S (Medien) / L (Schlüsselwechsel) | Medien sofort mitverschlüsseln; Schlüsselwechsel mit Stufe E planen |
| 7 | **Kein Zustellstatus, stille Sendefehler, Outbox nur für vier Event-Arten** (Z-3 bis Z-5). Der Nutzer erfährt nicht, ob eine Nachricht ankam. | P1 | M | Erst speichern („wartet“), dann senden; ein Statusmodell für alle Transporte (ADR-0003 neu fassen) |
| 8 | **Update-Kette ohne Vertrauensanker** und kein automatischer Testlauf (R-2, R-3). | P1 | S–M | `version.json` signieren, Hash zur Pflicht; `flutter analyze` + `flutter test` bei jedem PR |
| 9 | **Bauplan 9.0 und CLAUDE.md versprechen mehr, als der Code hält** (Quadratic Voting „implementiert“, „alles Ende-zu-Ende“, „unveränderlicher Decision Record“, „BLE Mesh“); `docs/current/` ist drei Monate alt (D-1, D-2). | P1 | S | Texte berichtigen – Charta Art. 6 und Dokumentationsregel 7 verlangen das |
| 10 | **Der Weg zu „Telegram-Niveau“ ist als Funktionsliste nicht erreichbar und laut Bauplan auch nicht das Ziel.** Der Bauplan nennt als Killer-Funktion zensurfreie lokale Koordination, auch ohne Internet (4.6). | – | – | Leitsatz schärfen: „verlässlich, vertrauenswürdig, auch ohne Netz“ statt Funktionsgleichstand; siehe Abschnitt 4 und 5 |

**Was gut ist und geschützt werden sollte** (geprüft): Event-ID und
Schnorr-Signatur werden vor jeder Verarbeitung geprüft
(`nostr_event_verifier.dart`); die Governance-Regeln stehen als reine
Funktionen an einer Stelle (`governance_authorization.dart`); die eigene
Auszählung hat Vorrang vor fremden Protokollen; Delegationen sind nicht
transitiv; Seed und Schlüssel liegen nur im Secure Storage; überall
`Random.secure()` und frische Nonces; Migrationen sind additiv und
wiederholbar (v28); kein SQL aus Nutzereingaben; keine Geheimnisse im
Repository; die Änderungen seit `main` sind durchweg mit Tests geliefert
(rund 1.500 neue Testzeilen auf rund 1.700 Codezeilen).

---

## 2. Befunde je Prüffeld

Format: **Kürzel · Titel** – Beleg · Bewertung · Priorität · Aufwand ·
Empfehlung · bekannt als TD-xx oder **neu**.

### 2.1 Code-Review (Schwerpunkt: Änderungen seit `main`)

Gesamteindruck (*Meinung*): Die elf Commits sind sorgfältig – kleine reine
Funktionen (`contact_sync.dart`, `relay_config.dart`, `profile_restore.dart`),
gute Kommentare zum „Warum“, Tests je Baustein. Die Schwächen liegen dort, wo
neuer Code an die alten Großdateien andockt.

**C-1 · Kontakt-Sync überschreibt einen lebenden Kontakt mit einem
Löschvermerk**
- Beleg: `mergeContactSync` legt einen fremden Löschvermerk auch dann in
  `tombstones`, wenn der Kontakt lokal später geändert wurde und deshalb
  bleibt (`lib/core/contacts/contact_sync.dart:133-139`).
  `applySyncMerge` schreibt alle diese Vermerke in die Datenbank
  (`lib/core/contacts/contact_service.dart:133-137`); `upsertContact`
  ersetzt die ganze Zeile (`lib/core/storage/pod_database.dart:1241-1253`).
- Folge: Der Kontakt bleibt bis zum Neustart sichtbar, danach ist er samt
  Notizen und Profilangaben weg. Er kommt zurück, wenn das andere Gerät ihn
  noch führt – die lokalen Notizen nicht.
- geprüft ✔ · P2 · S · neu
- Empfehlung: Löschvermerk nur persistieren, wenn der Kontakt wirklich
  entfernt wurde; Test „gelöscht auf B, danach geändert auf A, Neustart A“.

**C-2 · Kontaktliste: Erstveröffentlichung nach fester Wartezeit**
- Beleg: `lib/features/contacts/contact_sync_service.dart:57-59` – nach 20 s
  wird veröffentlicht, wenn noch keine Liste ankam. Das Ende der
  gespeicherten Events (EOSE) steht seit diesem Zweig zur Verfügung
  (`nostr_relay_manager.dart`, `onEose`), wird hier aber nicht genutzt.
- Folge: Bei langsamer Verbindung ersetzt ein frisches Gerät, auf dem schon
  ein Kontakt angelegt wurde, die vollständige Liste auf den Relays. Ist das
  alte Gerät verloren, ist die Liste weg.
- geprüft ✔ (Code), Eintritt *vermutet* · P2 · S · neu (ergänzt TD-60)
- Empfehlung: auf EOSE des eigenen Abos warten statt auf die Uhr.
- Nebenpunkte: Löschvermerke werden nie ausgedünnt, die Liste wächst
  unbegrenzt (bei mehreren hundert Kontakten über dem 128-KB-Limit von
  `nos.lol`); der Abgleich hängt an Gerätezeiten; der Kommentar
  „blocked … never transmitted“ in `contact.dart` stimmt nicht mehr.

**C-3 · `attach` des Kontakt-Sync läuft nicht garantiert vor dem
Transportstart**
- Beleg: `chat_provider.dart` ruft `ContactSyncService.attach` mit
  `unawaited` auf; der Listener wird erst nach zwei `await`s registriert
  (`contact_sync_service.dart:41-56`). Der Kommentar „listens before the
  transport starts“ ist damit nicht gedeckt – ein Verstoß gegen
  Sync-Gesetz 2 der CLAUDE.md.
- geprüft · P2 · S · neu

**C-4 · Eigene Nachrichten: jede Nachricht mit meiner DID gilt als „von
mir“**
- Beleg: `chat_provider.dart:1728-1733` (`isOwn = msg.fromDid == myDid`).
  Für Nostr prüft `_handleOwnDm` den eigenen Schlüssel
  (`nostr_transport.dart`), für LAN und BLE prüft niemand etwas (S-3).
- Folge: Im selben WLAN lässt sich eine Nachricht einschleusen, die im
  Gespräch mit einem Kontakt als von mir gesendet erscheint, ohne
  Benachrichtigung und an der Blockierliste vorbei.
- geprüft ✔ · P1 · S (mit S-3 zusammen) · neu

**C-5 · Gründer-Übergabe: belastbar zwischen bekannten Geräten, offen für
neu entdeckende**
- Beleg: `cell_service.dart` (`transferFounderRole`, `applyRoster`),
  `governance_authorization.dart` (`authorizeCellRoster`).
- Ein früherer Gründer kann nach der Übergabe eine zweite, neuere Liste mit
  einem anderen Nachfolger signieren. Geräte, die die Übergabe kennen,
  lehnen ab; Geräte, die die Gemeinschaft neu entdecken, sehen nur seine
  neueste Liste und folgen ihr. Bei Ketten A→B→C hält
  `_rostersAwaitingHandover` nur eine Liste pro Gemeinschaft.
- geprüft ✔ (Logik), Angriff *vermutet* · P2 · M · teils bekannt (TD-33
  nennt die Grenze, nicht die Folge)
- Empfehlung: Übergaben als nicht ersetzbare, verkettete Events führen, vom
  Nachfolger gegengezeichnet.

**C-6 · Weitere Async-Lücken und stille Fehler**
- `addContact`: Prüfung, `await _persist`, erst dann `_contacts.add`
  (`contact_service.dart:128-141`) – doppelte Kontakte möglich.
- `insertMessage`: SELECT, `await encrypt`, INSERT ohne UNIQUE-Index auf
  `message_id` (`pod_database.dart:1279-1292`).
- 52 leere `catch (_) {}`, nur 8 `unawaited(` im ganzen Code; die Lints
  `unawaited_futures`, `discarded_futures`, `cancel_subscriptions`,
  `close_sinks` sind nicht aktiv (`analysis_options.yaml`).
- geprüft · P2 · S–M · neu (verwandt TD-51)
- Die Governance-Handler sperren dagegen korrekt synchron.

**C-7 · Die drei Großdateien wachsen weiter**
- `chat_provider.dart` 2.765 → 3.756, `nostr_transport.dart` 2.976 → 3.541,
  `proposal_service.dart` 4.097 → 4.172 Zeilen seit August.
- geprüft · P1 · S (Wächter) · TD-49; siehe 2.6.

### 2.2 Strategie

**ST-1 · Der Bauplan nennt eine andere Killer-Funktion als der
Audit-Auftrag** (*Meinung*, Beleg Bauplan 4.6 und 9.2.1.4)
- Bauplan: „Killer-App statt Alles-App“; Phase 1 konzentriert sich auf
  „zensurfreie, lokale Koordination“ – das „digitale Walkie-Talkie“, das
  weiterläuft, wenn das Internet ausfällt. Reihenfolge laut 9.2.4:
  Mesh-Chat → Marktplatz → Care → Wohnen.
- Der Auftrag setzt „mindestens so angenehm wie Telegram“ als Ziel. Als
  Funktionsliste sind das rund 30 Bereiche, von denen 14 fehlen und 12 nur
  teilweise da sind (Abschnitt 3). Mit einem kleinen Team ist das ein
  Mehrjahresprogramm, und es ist nicht das, was N.E.X.U.S. von Signal,
  Threema oder Telegram unterscheidet.
- Empfehlung: Leitsatz behalten, aber schärfen: **„Messenger First“ heißt:
  die Kernabläufe (schreiben, ankommen, wissen dass es ankam, wissen mit wem
  ich schreibe, auch ohne Internet) auf Telegram-Niveau – nicht die
  Funktionsbreite.** Abschnitt 3 teilt die Liste entsprechend ein.

**ST-2 · Die Reihenfolge A–G stellt Mehrsprachigkeit vor Vertrauen und
Zustellung**
- Stufe C (rund 1.500 Texte übersetzen) liegt vor NIP-17, Medienserver,
  Zustellanzeige (D) und vor Gruppenverschlüsselung (E). Die P0-Befunde
  dieses Berichts stehen in keiner Stufe.
- Zusätzlich werden in C Texte übersetzt, die laut 2.4 erst vereinfacht
  werden müssen (Fachbegriffe, „Zelle“ oder „Gemeinschaft“).
- *Meinung* · Empfehlung: Sicherheits- und Zustellblock vorziehen;
  Lokalisierungs-**Grundlage** sofort (neue Texte nur noch über l10n),
  Massenübersetzung nach der Textbereinigung. Details in Abschnitt 4.

**ST-3 · Modul-Disziplin gilt laut Bauplan „ab sofort“, steht aber erst in
Stufe E**
- Bauplan 4.8.1: „Die Modul-Disziplin der Stufe 1 gilt ab sofort für jede
  neue Funktion … kostet keine zusätzliche Bauzeit – nur Disziplin.“
- Im Zweig wurde wieder in den ChatProvider hineingebaut (+220 Zeilen).
- *Meinung* · P1 · S · Empfehlung: Wächtertests jetzt (2.6, M-2).

**ST-4 · Was für den Bauplan fehlt, ohne in einer Stufe zu stehen**
- Schutz vor Mehrfachidentitäten als Voraussetzung jeder Abstimmung über
  die eigene Gemeinschaft hinaus (Bauplan 8.4, Charta Art. 12) – siehe 2.5.
- Wiederherstellung über Vertrauenspersonen (Bauplan 4.2.1 „Social
  Recovery“) – heute ist der Verlust der zwölf Wörter endgültig.
- Meldewege und Schutz Verletzlicher (Charta Art. 9) – nur ein
  Kanal-Meldeweg per DM (`chat_provider.dart:3227`).
- Konto- und Datenlöschung (Charta Art. 4 und 16, „Exit-Recht“) – keine
  Funktion gefunden.
- Ablauf des Gründer-Mandats (Bauplan 11.4, 730 Tage) – siehe 2.13.
- *geprüft* (Fehlen per Suche) / *Meinung* (Einordnung).

**ST-5 · Was überflüssig oder verfrüht ist** (*Meinung*)
- Platzhalter-Sphären, Wallet mit „0,00“, „Phase 1a – AETHER Protokoll“ in
  der Oberfläche (2.4, U-6): Sie versprechen, was es nicht gibt.
- Quadratic Voting, Superadmin-Abwahl, interzellulär (Stufe F) vor einem
  Identitätsschutz: Quadratische Stimmkosten sind ohne Schutz vor
  Mehrfachidentitäten wirkungslos.
- Anrufe, Bots, Sticker, Videonachrichten: zurückstellen.

### 2.3 Funktionalität

Siehe Tabelle in Abschnitt 3. Die wichtigsten Einzelbefunde:

**F-1 · „Bearbeiten“ wirkt nur auf dem eigenen Gerät** – der Empfänger sieht
weiter den alten Text. `chat_provider.dart:3638-3647`. geprüft ✔ · P1 · M
(oder S: Menüpunkt in „Lokal bearbeiten“ umbenennen) · neu.

**F-2 · Weiterleiten verliert Inhalte stillschweigend** – Sprachnachrichten
ganz, Bilder in Richtung Kanal; die Erfolgsmeldung erscheint trotzdem.
`conversation_screen.dart:1082-1090`. geprüft · P2 · S · neu.

**F-3 · Windows hat keine Systembenachrichtigungen**
(`notification_service.dart:151`: nur Android und Linux), Android im
Hintergrund nur für Direktnachrichten. geprüft ✔ · P1 · S–M · neu.

**F-4 · Sprachnachrichten unter Windows sind unkomprimiertes WAV**
(`voice_recorder.dart:44-48`), als Base64 im Event; schon wenige Sekunden
überschreiten die Relay-Grenzen. geprüft (Code), Nichtankommen *vermutet* ·
P1 · S (Opus/AAC auch unter Windows) · teils TD-64.

### 2.4 UX und UI

**U-1 · Erstnutzer-Weg: rund 13 Bildschirme bis zur ersten Nachricht**
- Willkommen → Seed Phrase → drei Wörter bestätigen → Name → Fertig
  (`onboarding_screen.dart:119-155`), danach Grundsätze-Intro, vier
  Inhaltsseiten, Bekenntnis, Backup-Einrichtung (`core/router.dart:52-58`).
  Kein geführter Schritt „erster Kontakt“.
- geprüft · *Meinung*: zu lang für „Messenger First“ · P1 · M · neu
- Empfehlung: Sicherung der zwölf Wörter hinter die erste Nachricht legen
  (Erinnerungsbanner existiert, `dashboard_screen.dart:1150`), Grundsätze
  auf eine Seite, am Ende direkt in den Chat mit „Kontakt hinzufügen“.

**U-2 · Fachsprache im Erstkontakt** – „Seed Phrase“ (16 Stellen), „npub
oder DID einfügen“ (`contacts_screen.dart:135`), „Peers über BLE, LAN oder
Nostr“ (`:144`), „Nodes“, „Relay“, „Demurrage“. Die Charta verlangt
„Alltagssprache zuerst“ (Art. 20). geprüft · P1 · M · neu.

**U-3 · Desktop-Bedienung** – kein Rechtsklick (`onSecondaryTap` 0 Treffer),
kein Hover, kein Datei-Drop, keine Zwei-Spalten-Ansicht (ein Breakpoint bei
800 px, `nexus_scaffold.dart:16`), außer Enter/Shift+Enter keine
Tastenkürzel. Das Nachrichtenmenü per langem Druck betrifft auch Antworten,
Weiterleiten, Bearbeiten und Favorit. geprüft · P1 · M–L · TD-68 (nur
Reaktion/Löschen), Rest neu.

**U-4 · Barrierefreiheit** – `Semantics` 0 Treffer; 54 `IconButton`, 29
Tooltips; nur dunkles Design (`main.dart:243`); 133 Schriftgrößen von
9–11 px; Textskalierung nie abgesichert. geprüft (Zahlen) · P2 · M · neu.
Charta Art. 12 nennt Teilhabe ohne digitale Kompetenz ausdrücklich.

**U-5 · Rohe Fehlermeldungen** – rund 33 Stellen zeigen `$e` im Text, etwa
„Senden fehlgeschlagen: $e“ (`conversation_screen.dart:288, 334, 358`) und
bei der Identitätserstellung (`onboarding_screen.dart:106`). geprüft · P1 ·
S–M · neu. Empfehlung: eine zentrale Funktion für verständliche Meldungen.

**U-6 · Platzhalter und tote Einträge** – fünf „Coming soon“-Sphären in der
Seitenleiste, fünf von zehn Kacheln in „Entdecken“ ohne Funktion, Wallet
als Attrappe, „Daten exportieren – Kommt bald“, obwohl der Export im Profil
funktioniert (`nexus_scaffold.dart:420`). 109 `Navigator.push` neben 30
GoRouter-Aufrufen. geprüft · P2 · S · neu.

**U-7 · Begriffe** – „NEXUS“ ohne Punkte an 32 Stellen gegenüber 18 mit;
„Gemeinschaft“ 151-mal, „Zelle“ 3-mal; „System-Admin“; Sprachmix („Home“,
„Feed“, „Peers“). Keine Umschriften, keine Geld-Begriffe. geprüft · P2 · S.
Anmerkung: CLAUDE.md verlangt „Zellen“, Bauplan Anhang D und Charta Art. 13
verlangen nach außen „lokale N.E.X.U.S.-Gemeinschaft“. Die Oberfläche folgt
bereits der Charta; CLAUDE.md sollte angeglichen werden.

**U-8 · Fehlende Rückmeldung** – keine Anzeige wartender oder zugestellter
Nachrichten (2.9), Schlüsselwechsel-Warnung nur im geöffneten Gespräch
(`conversation_screen.dart:3290`), Bluetooth-Verweigerung stoppt den ganzen
Chat mit der Meldung „Bluetooth-Berechtigungen verweigert.“ (2.9, Z-7).

### 2.5 Dezentralität und Web of Trust

**W-1 · Wie dezentral ist die App wirklich?** (geprüft, Bewertung *Meinung*)

| Abhängigkeit | Stand | Was bei Ausfall passiert |
|---|---|---|
| Eigenes Relay | eines von drei Standard-Relays (`relay_config.dart:12-16`) | Chat läuft über die anderen zwei weiter. Es fehlen dauerhafte Aufbewahrung und Events über 128 KB (Bilder), also alte Historie, Mitgliederlisten und Kontoumzug |
| Öffentliche Relays | `relay.damus.io`, `nos.lol`, nicht beeinflussbar | Regeln, Limits und Speicherdauer können sich jederzeit ändern (TD-47 hat das schon gezeigt) |
| Superadmin | eine fest eingebaute DID (`assets/config/system.json`) | Wechsel oder Widerruf nur per App-Update; lokal per SharedPreferences überschreibbar (`system_config.dart`) |
| Gründungsgenehmigungen | ein fester Nostr-Schlüssel (`bootstrap_cell_authors`) | Ohne ihn keine neue Gemeinschaft |
| Updates | ein GitHub-Repository, keine Signatur (R-2) | Wer das Konto kontrolliert, kontrolliert alle Windows-Installationen |
| Identität | zwölf Wörter, kein Gerätekonzept, keine Wiederherstellung | Verlust ist endgültig; ein gestohlenes Gerät lässt sich nicht aussperren |

Bewertung: Die **Daten** sind dezentral (lokal, verschlüsselt, mehrere
Relays). Die **Autorität** ist es nicht: Superadmin, Genehmigungsschlüssel
und Update-Quelle sind je ein einzelner Punkt in einer Hand. Für die
Genesis-Phase ist das vertretbar (Bauplan 11.4), es muss aber benannt und
befristet sein.

**W-2 · Kein NIP-65, kein NIP-42** – Relays eines Kontakts sind nicht
auffindbar; wer ein eigenes Relay einträgt, erreicht nur, wer es zufällig
teilt. TD-78 bekannt (NIP-42); NIP-65 neu · P2 · M.

**W-3 · Vertrauensstufen sind lokale Etiketten** – `TrustLevel` (entdeckt,
Kontakt, Vertrauensperson, Bürge) wirkt nur auf dem eigenen Gerät; „Bürge“
hat keinerlei Funktion (`TrustLevel.guardian` kommt nur in Anzeige und
Filter vor). Die Mindest-Vertrauensstufe einer Gemeinschaft prüft die
**eigene** Kontaktliste des Gründers (`cell_service.dart:1476-1492`).
geprüft ✔ · P2 · L · neu.

**W-4 · Kein Schutz vor Mehrfachidentitäten bei Abstimmungen** – Eine
Identität kostet einen Tastendruck. Innerhalb einer Gemeinschaft schützt
heute allein die Aufnahme durch Gründer oder Moderator. Das reicht für
kleine Gemeinschaften, in denen man sich kennt, nicht für alles darüber.
Der Bauplan verlangt zwei persönliche Bestätigungen durch etablierte
Mitglieder (8.4.2), die Charta „Schutz vor Mehrfachidentitäten“ (Art. 12).
geprüft (Fehlen) · P1 vor interzellulärer Governance · L · neu.
- Empfehlung: signierte Bürgschaften („ich habe diese Person getroffen“)
  als eigener Event-Typ, zunächst nur als Anzeige („von 2 Mitgliedern
  bestätigt“), später als Bedingung für das Stimmrecht. Kein AURA-Zahlenwert
  (Charta Art. 16).

**W-5 · Kooperation mit Web of Trust / Real Life Stack** (*Meinung*, auf
Basis von `docs/research/`, deren Quellen nicht erneut geprüft wurden)
- Der Identitätsnachweis der OneApp (`identity_proof.dart`) ist bereits
  eine signierte Aussage „dieser DID-Schlüssel steht für diesen
  Nostr-Schlüssel“. Bürgschaften wären dieselbe Bauart. Das ist der
  natürliche Berührungspunkt.
- Empfehlung: zuerst das eigene Bürgschaftsformat klein bauen und dabei das
  Datenformat von Web of Trust als Vorlage nehmen; eine feste Abhängigkeit
  erst, wenn deren Spezifikation stabil ist. Deckt sich mit der bisherigen
  Einordnung in `NOW_NEXT_LATER.md`.

### 2.6 Modularität

**M-1 · Abhängigkeiten laufen in die falsche Richtung**
- `core/` importiert `features/`: `nostr_transport.dart:19-24`
  (Kanal-Service, Gründungsgenehmigung, Delegation, Rollen),
  `core/roles/permission_helper.dart:1-5`, `core/router.dart` (24 Screens).
- Chat und Governance importieren sich je zehnmal gegenseitig. Rund 1.000
  Zeilen Governance-Verdrahtung liegen im ChatProvider
  (`chat_provider.dart:724-1688`).
- geprüft · P1 · M · neu (ergänzt TD-49, TD-55)

**M-2 · Es gibt keinen Modulrahmen** – keine Registry, keine
Feature-Schalter, ein `switch` über 19 Event-Arten
(`nostr_transport.dart:2463-2540`), eine Migrationsdatei für alles
(`pod_database.dart`, 52 Tabellen). Governance, Mitgliederlisten und
Kontakt-Sync laufen am `TransportManager` vorbei direkt über
`NostrTransport`. geprüft · P1 · M · neu.

**M-3 · Vorschlag: Modulrahmen in kleinen, einzeln prüfbaren Schritten**
(*Meinung*)
1. **Wächtertest** (S): `core` importiert nicht aus `features`; Screens
   importieren nicht `pod_database`; Bestandsdateien dürfen nicht wachsen.
2. **`lib/app/`** (S): Router und Shell dorthin.
3. **`GovernanceBridge`** (M): die Verdrahtung aus dem ChatProvider
   verschieben, Listener-vor-Start-Reihenfolge unverändert. Wichtigster
   einzelner Schnitt für „Messenger First“.
4. **`NexusModule`** als statische Liste (S): `id`, Routen,
   Navigationseinträge, Event-Arten, Handler, Migrationen. Kein
   dynamisches Plugin-System.
5. **Navigation aus der Liste** (S–M): Platzhalter verschwinden von selbst;
   ein Messenger-Modus ist dann ein Schalter je Modul.
6. **Event-Registry** vor dem bestehenden `switch` (M).
7. **Migrationen je Modul** als Funktionen, eine globale Versionsnummer (M).
8. Später: Schalter je Gemeinschaft, dann das SDK aus Bauplan 4.8.1.

**M-4 · ADRs 0002–0005**

| ADR | Empfehlung | Begründung |
|---|---|---|
| 0002 Gerät und Person | Modell annehmen, Umsetzung zurückstellen | Mehrgeräte-Abgleich läuft über den geteilten Seed. Der Preis: kein Einzelwiderruf eines Geräts. Vor breiter Nutzung wieder aufgreifen |
| 0003 Zustellsemantik | **neu fassen**, dann annehmen | Die Annahme „keine Outbox“ ist überholt; es gibt jetzt zwei Warteschlangen (`nostr_outbox`, `publish_results`) und für Chat keinen Status (Z-4) |
| 0004 Speichergrenze | annehmen, per Wächtertest durchsetzen | Ohne Durchsetzung wirkungslos (TD-55 unverändert) |
| 0005 Dateigröße | annehmen, per Wächtertest durchsetzen | Alle drei Großdateien sind seit August gewachsen. Start mit `pod_database.dart` (Migrationen) und der GovernanceBridge; `proposal_service.dart` weiter zurückstellen, bis die Gerätetests durch sind |

### 2.7 Sicherheit und Kryptografie

Bedrohungsmodell in einem Satz (*Meinung*): Gegen einen **mitlesenden
Relay-Betreiber** schützt die App den Inhalt von Direktnachrichten und
privaten Kanaltexten, nicht aber wer mit wem wann schreibt. Gegen einen
**aktiven Teilnehmer** – irgendjemand mit einem Nostr-Schlüssel oder im
selben WLAN – schützt sie den Chat derzeit kaum.

**S-1 · Absender von Direktnachrichten und Präsenz nicht gebunden**
- `_handleDm` entschlüsselt und übernimmt `fromDid` aus dem Inhalt
  (`nostr_transport.dart:3130-3170`).
- `_learnPeer` setzt `_didToNostrPubkey[senderDid]` auf den Schlüssel des
  Absenders und zusätzlich auf einen im Inhalt behaupteten
  (`:3431-3443`). Antworten gehen danach an den Angreifer.
- Jede Nachricht darf den Verschlüsselungsschlüssel des „Absenders“ setzen
  (`chat_provider.dart:1749-1751`, `contact_service.dart:309-319`).
- Dasselbe ohne jede Nachricht: Ein öffentliches Präsenz-Event mit fremder
  DID überschreibt Verschlüsselungs- und Nostr-Schlüssel des Kontakts
  (`nostr_transport.dart:3284-3297`).
- Steuernachrichten hängen an derselben unbelegten DID: angenommene
  Kontaktanfrage, Kanalzugang samt Kanalschlüssel, Antragsdiskussion.
- Abmilderung: eine Schlüsselwechsel-Warnung im geöffneten Gespräch.
- geprüft ✔ · **P0** · M · neu (TD-73 und TD-53 streifen es)
- Empfehlung: `_idProof` in DMs, Präsenz und Kanalbeiträgen verlangen; bei
  Kontakten einen abweichenden Schlüssel nie übernehmen, sondern melden.

**S-2 · Mehrfachstimmen über mehrere Nostr-Schlüssel**
- Berechtigt wird nach DID (`governance_authorization.dart:301-311`),
  ersetzt und eindeutig gehalten nach Nostr-Schlüssel
  (`proposal_service.dart:2806-2820`, `pod_database.dart:386`), gefiltert
  wieder nach DID (`proposal_service.dart:2228-2240`).
- Ein Mitglied bindet N Nostr-Schlüssel an seine DID und stimmt N-mal.
- geprüft ✔ (Berechtigung und Deduplizierung), Zählweise aus der
  Teilprüfung · **P0** · S · neu
- Empfehlung: nach `voterDid` deduplizieren, neueste Stimme gewinnt;
  Regressionstest mit zwei Schlüsseln für eine DID. Vor der Korrektur am
  Gerät oder im Test nachstellen.

**S-3 · LAN und BLE ohne Echtheitsprüfung**
- Signiert wird beim Senden (`transport_manager.dart:139`), geprüft wird
  nie: Im ganzen `lib/` gibt es keinen Prüfaufruf für `toSignableBytes`.
- LAN: UDP-Ankündigung mit frei behaupteter DID
  (`lan_peer_discovery.dart:213-235`), TCP-Server auf allen Schnittstellen
  im Klartext (`lan_message_channel.dart:30-34`), Vorrang vor Nostr
  (`transport_manager.dart:125-131`). Ohne bekannten Schlüssel geht der
  Inhalt unverschlüsselt.
- `NexusMessage.fromWireBytes` entpackt ohne Obergrenze
  (`nexus_message.dart:185`).
- geprüft ✔ (fehlende Prüfung), übrige Punkte geprüft · P1 · M · neu
- Wichtig für den Mesh-Zweig: Jeder Funk-Transport erbt diese Lücke.

**S-4 · Private Kanäle**
- Ein fester Schlüssel je Kanal (`channel_encryption.dart`), verteilt per
  DM; kein Wechsel beim Entfernen (`channel_admin_screen.dart:139`).
- Bilder und Sprachnachrichten im Kanal werden nicht verschlüsselt:
  `sendImageToChannel` (`chat_provider.dart:2929-2949`) ruft
  `ChannelEncryption` nicht auf; im ganzen ChatProvider gibt es nur einen
  Verschlüsselungsaufruf (`:2460`, Text).
- Kein Absendernachweis: Wer den Kanalschlüssel hat, kann als jede DID
  schreiben.
- geprüft ✔ (Medien), übrige Punkte geprüft · P1 · S (Medien), L
  (Schlüsselwechsel) · neu

**S-5 · Direktnachrichten-Kryptografie** – außen NIP-04 (AES-CBC ohne
Integritätsschutz, `nostr_transport.dart:3503`), innen statisches X25519 mit
AES-GCM (`message_encryption.dart`), keine Forward Secrecy. Bilder in
Direktnachrichten haben nur die äußere Schicht
(`chat_provider.dart:2665-2687`). Metadaten öffentlich; das eigene Relay
gibt DMs ohne Anmeldung heraus (TD-78). geprüft · P1 · L · bekannt, ergänzt.

**S-6 · Eigene secp256k1-Rechnung in reinem Dart** – Signieren mit `BigInt`
(`nostr_keys.dart:80-125`) widerspricht der Projektregel „Constant Time
Crypto“; `computeSharedSecret` prüft nicht, ob der Punkt auf der Kurve liegt
(`:176-189`). geprüft (Code), Ausnutzbarkeit *vermutet* · P2 · S
(Punktprüfung), M (geprüfte Bibliothek) · teils bekannt. Dieselbe Rechnung
kostet rund 25 ms pro Signaturprüfung (2.10).

**S-7 · Klartext in der Datenbank** – `pod_messages.edited_body`
(`pod_database.dart:1511-1517`); Governance-Tabellen ganz ohne `enc`
(Stimmen mit Begründung, Diskussionen, Delegationen, Protokolle,
`:372-460`); Metadaten-Spalten. Widerspricht der Projektregel „Kein
Klartext“. geprüft · P2 · M · neu (TD-42 betrifft nur die Relays).

**S-8 · Empfangsstau und Speicher** – unbegrenzte Prüfwarteschlange, keine
Größengrenze je Event (`nostr_event_verifier.dart`,
`nostr_relay_manager.dart:443-460`). Öffentliche Abos (`nexus-mesh`,
Zell-Ankündigungen, Präsenz) lassen sich mit gültig signierten Events
fluten. geprüft · P2 · S · neu.

**S-9 · Kleinere Punkte**
- Dateiname aus fremder Nachrichten-ID beim Sprachnachrichten-Cache
  (`chat_provider.dart:2157`); unter Windows *vermutlich* Schreiben
  außerhalb des App-Ordners. P2 · S · neu.
- Hintergrunddienst leitet weiter aus leerem Seed ab
  (`background_service.dart:138`). TD-44, unverändert offen.
- Benachrichtigung für jedes Kind-4-Event mit meinem `p`-Tag, ohne
  Signaturprüfung, auch von Blockierten. geprüft ✔ · P2 · S · neu.
- Spätstimmen sind rückdatierbar (`created_at` setzt der Absender). P3.
- Governance-Integrität: Die Hash-Kette ist geräteabhängig und keine
  Manipulationsprüfung (TD-41, bekannt). Wirksam ist allein die eigene
  Auszählung – und die ist durch S-2 angreifbar.

### 2.8 Datenschutz und Recht

Keine Rechtsberatung; die Punkte sind zur Klärung mit einer fachkundigen
Person gedacht.

**D-R1 · Keine Datenschutzerklärung in App und Repository** – Suche nach
„Datenschutz“, „Impressum“, „privacy“ in `lib/` ohne passenden Treffer;
keine entsprechende Datei im Repository. Seit dem 10.11. betreibt das
Projekt ein Relay mit dauerhafter Aufbewahrung, das DIDs, Pseudonyme,
öffentliche Profile, Präsenz (alle 90 s), Kommunikationsbeziehungen und
Governance-Daten speichert. geprüft (Fehlen) · P1 · S–M · neu.

**D-R2 · Keine Löschung** – weder „Konto löschen“ in der App noch ein
Löschweg am Relay. „Für alle löschen“ ist eine Bitte an die Relays. Charta
Art. 4 und 16 (Exit-Recht, Rückzug, Korrektur). geprüft (Fehlen) · P1 · M ·
neu. Empfehlung: Abmelde-Funktion, die Profil und Präsenz leert, und eine
dokumentierte Löschzusage für das eigene Relay.

**D-R3 · Governance-Daten öffentlich** (TD-42) – Anträge, Stimmen mit DID,
Begründungen und Delegationen liegen im Klartext auf allen Relays, also
auch, wer wie abgestimmt hat. Offene Abstimmung kann gewollt sein, muss
dann aber vor der Stimmabgabe gesagt werden. bekannt · P1 · Entscheidung
nötig (Abschnitt 5).

**D-R4 · Präsenz** – jede Installation veröffentlicht alle 90 s DID,
Pseudonym und Verschlüsselungsschlüssel, auch aus dem Hintergrund
(`background_service.dart:172`). Daraus lässt sich ein Online-Profil jeder
Person erstellen. geprüft · P2 · S (abschaltbar machen, Intervall strecken)
· neu.

**D-R5 · Meldewege** – nur für Kanalnachrichten, als DM an den Kanal-Admin
(`chat_provider.dart:3227`); nichts für Direktnachrichten, Dorfplatz oder
Profile. Das eigene Relay macht das Projekt zum Speicherort fremder
Inhalte. geprüft · P1 · M · neu.

**D-R6 · AGPL** – Lizenzdatei vorhanden. Zu prüfen: Lizenzen der
eingebundenen Pakete und der gebündelten Schriften/Bilder; Hinweis auf den
Quelltext in der App. *nicht geprüft* · P3.

### 2.9 Zuverlässigkeit, Sync und Offline

**Z-1 · Zeitmarke aus fremden Nachrichten**
- `_saveNostrTimestamp(msg.timestamp)` für jede empfangene Nachricht, auch
  öffentliche Broadcasts (`chat_provider.dart:1745`, `:1610-1617`); der
  Wert wird ohne Begrenzung zum `since` der Abos
  (`nostr_transport.dart:443-447`, `:2152-2157`).
- Eine Nachricht mit Zukunftsdatum genügt, und das Gerät holt nach dem
  nächsten Start bis zu diesem Zeitpunkt keine Direktnachrichten mehr ab.
- geprüft ✔ · **P0** · S · neu

**Z-2 · Outbox und Abholfenster passen nicht zusammen**
- Die Outbox sendet das Event unverändert, also mit dem ursprünglichen
  Zeitstempel, bis zu sieben Tage später (`nostr_outbox.dart:66-68`). Der
  Empfänger fragt ab „letzte Nachricht minus 60 Sekunden“.
- Hat er inzwischen irgendetwas Neueres erhalten und ist beim Nachreichen
  nicht verbunden, sieht er die Nachricht nie.
- geprüft ✔ (Code), Relay-Verhalten nach NIP-01 · **P0** · M · TD-74 führt
  die Outbox als erledigt, diese Lücke fehlt
- Empfehlung für Z-1 und Z-2: Marke auf `min(Zeitstempel, jetzt)` begrenzen
  und nur aus verifizierten Direktnachrichten ableiten; beim Abholen
  mehrere Tage überlappen, die Datenbank dedupliziert ohnehin.

**Z-3 · Stille Sendefehler**
- Erst senden, dann speichern (`chat_provider.dart:2374`): wirft der
  Versand, existiert die Nachricht nirgends.
- Ohne Schlüssel oder im Fehlerzustand kehrt der Nostr-Versand ohne Fehler
  zurück (`nostr_transport.dart:1784`), BLE ebenso
  (`ble_transport.dart:352-372`).
- geprüft ✔ (Reihenfolge), übrige Punkte geprüft · P1 · M · neu

**Z-4 · Kein Zustellstatus für Chat** – `pod_messages.status` bleibt immer
`pending` (`pod_database.dart:1297`); `PublishResultStatus` gibt es nur für
Governance. geprüft · P1 · M · TD-56 / TD-74.

**Z-5 · Outbox nur für vier Event-Arten** – Beitrittsanfrage, Bestätigung,
Mitglieder-Update, Mitgliederliste, Profil und Broadcast gehen ohne
Warteschlange hinaus (14 Stellen `publishFireAndForget`). Offline gestellte
Beitrittsanfragen gehen verloren. Kein Backoff; „angenommen“ heißt ein
Relay. geprüft · P1 · M · neu.

**Z-6 · Relay-Verbindung** – fester Reconnect nach 10 s, kein Ping, keine
Erkennung halboffener Verbindungen (`nostr_relay_manager.dart:291,
337-344`); bei jedem Reconnect werden alle Filter mit dem `since` des
Sitzungsstarts neu gesendet (`:355-372`). geprüft (Code), Wirkung
*vermutet* · P1 · S · neu.

**Z-7 · Bluetooth-Verweigerung stoppt den gesamten Chat** – auch Nostr
(`chat_provider.dart:259-264`). geprüft ✔ · P1 · S · neu.

**Z-8 · BLE und LAN sind Direktverbindungen** – GATT-Server und Advertising
sind TODO (`ble_transport.dart:38-41, 141`), `hopCount` wird nie
weitergereicht; LAN nimmt ein /24-Netz an. geprüft (Code), BLE zwischen zwei
App-Instanzen funktionslos *vermutet* · P2 · L · neu.

**Z-9 · Lange Offline-Zeiten** – Governance 30 Tage, Beitrittsanfragen und
Mitglieder-Updates 7 Tage, Dorfplatz 7 Tage; Stimmen, die vor ihrem Antrag
eintreffen, werden verworfen und als gesehen markiert
(`proposal_service.dart:2646, 2686`). geprüft · P1 · M · TD-48, TD-63.

**Z-10 · Mehrgeräte-Abgleich** – abgeglichen: Direktnachrichten (30 Tage),
Kontakte, Profil, Mitgliederlisten. Nicht abgeglichen: Reaktionen vom
Zweitgerät (TD-71), Bearbeitungen, Favoriten, Lesestand, lokal Gelöschtes,
Aufbewahrungsfristen, private Kanalschlüssel (*vermutet*: nur über Backup).
Kennt das Zweitgerät den Verschlüsselungsschlüssel des Empfängers nicht,
zeigt es „[Nachricht konnte nicht entschlüsselt werden]“. geprüft · P2 · L.

**Z-11 · Vorbereitung des Mesh-Zweigs** (*Meinung*, Belege aus der
Teilprüfung)
- Einhängen ist leicht: `MessageTransport` ist schlank,
  `TransportType.lora` existiert.
- Brechen wird bei wenigen hundert Byte pro Paket: JSON-Format mit Signatur
  und Schlüssel in jeder Nachricht; „kein Fehler = zugestellt“; Präsenz
  alle 90 s; Broadcast an alle Transporte; und Governance, Mitgliederlisten
  und Kontakt-Sync, die den `TransportManager` umgehen.
- Folgerung: Der Funkweg braucht ein kompaktes Binärformat, echte
  Empfangsbestätigungen und Signaturprüfung (S-3). Alle drei verbessern
  auch LAN, BLE und Nostr. Die Umstellung auf NIP-17/NIP-44 ändert das
  Nachrichtenformat ohnehin – beides sollte **einmal gemeinsam** entworfen
  werden.

**Z-12 · Datenbank** – Schema v28, additiv und wiederholbar. Kein
`onDowngrade`, keine Fehlerbehandlung in den Schritten; ein Fehler führt
zum Absturzbildschirm (`main.dart:147-161`). geprüft · P2 · S · TD-75.

### 2.10 Leistung und Ressourcen

Alle Wirkungen *vermutet* (nicht gemessen), Code geprüft.

**L-1 · Hintergrunddienst** – dauerhafter Vordergrunddienst; Reconnect fest
5/10/15 s ohne Netzprüfung; alle 90 s eine signierte Präsenzmeldung an jedes
Relay; im Hintergrund hält *vermutlich* auch der Haupt-Isolate seine
Verbindungen offen (mindestens sechs WebSockets). P1 · M · neu.

**L-2 · Medien als Base64 im Event und in der Datenbank** – jedes Öffnen
eines Gesprächs entschlüsselt alle Bilder mit; Aufräumen nur über die
Aufbewahrungsfrist. P1 · L · TD-64.

**L-3 · Skalierung**
- `listMessages` lädt und entschlüsselt ein ganzes Gespräch ohne
  Seitenweise-Laden (`pod_database.dart:1307-1328`).
- `pod_messages` hat nur einen Index auf `nostr_event_id`; `conversation_id`,
  `message_id` und Zeitstempel fehlen (`:172`).
- Die gesprächsübergreifende Suche entschlüsselt die gesamte
  Nachrichtentabelle pro Anfrage (`:1624-1660`).
- Signaturprüfung rund 25 ms pro Event, seriell: 1.000 Events Rückstand
  verzögern auch Live-Nachrichten um etwa 25 s.
- 36 `notifyListeners()` in einem Provider; 763 `print(` laufen auch im
  Release.
- P1–P2 · M · neu (Indizes, Seitenweise-Laden), TD-51.

**L-4 · Start** – rund 17 `await`s nacheinander vor dem ersten Bild
(`main.dart:171-221`). Das Absturzprotokoll wird bei jedem Start geleert
(`:86-88`). P2 · M · neu.

### 2.11 Release-Fähigkeit und Betrieb

**R-1 · Android-Release mit Debug-Signatur** –
`android/app/build.gradle.kts:45-49`; `applicationId` trägt noch ein TODO.
Folge siehe Kurzfassung Nr. 4. Im Repository liegen keine Schlüssel.
geprüft ✔ · **P0** · S · neu (weder in TECH_DEBT noch in RELEASE_READINESS).

**R-2 · Update ohne Vertrauensanker** – `version.json` von
`raw.githubusercontent.com` (`update_service.dart:50-51`); der Hash ist
optional, stammt aus derselben Datei wie die Adresse und fehlt in der
aktuellen `version.json`; der Windows-Installer ist unsigniert.
geprüft ✔ · P1 · M · TD-61 ist im Code überholt.

**R-3 · Keine CI** – `.github/` enthält nur Vorlagen. geprüft · P1 · S · neu.

**R-4 · Analyse-Hinweise** – nur `flutter_lints`, nichts ergänzt; die 763
`print(` erklären *vermutlich* den Großteil der über 900 Hinweise. P2 · M ·
TD-51. Empfehlung: `print` gesammelt durch eine Log-Funktion ersetzen, dann
bleiben die echten Hinweise sichtbar; `unawaited_futures` einschalten.

**R-5 · Tests** – 92 Dateien, Schwerpunkt Governance. Ohne oder mit kaum
Tests: Hintergrunddienst, Relay-Manager (Reconnect), BLE, alte
Migrationspfade, Kontaktanfragen, Einladungen, die großen Screens. Kein
Integrationstest; alles Geräteübergreifende wird von Hand geprüft. Die fünf
roten TransportManager-Tests sind *vermutlich* nur veraltet
(`test/core/transport/transport_manager_test.dart:133-196` erwartet die
Kaskade, der Code verteilt Broadcasts an alle). P2 · M · TD-25.

**R-6 · Rückstau an Gerätetests** – 21 offene Zeilen in
`GERAETETESTS_OFFEN.md`, fast jeder TD-Eintrag seit dem 7.11. trägt
„Gerätetest offen“. Ein Tester mit zwei Geräten ist der Engpass des
Projekts. *Meinung* · P1.
- Empfehlung: einen kleinen Zwei-Instanzen-Test im Code bauen (zwei
  `NostrTransport` gegen ein lokales Test-Relay oder ein Relay-Attrappe).
  Das fängt Z-1, Z-2, S-1, S-2 und C-1 automatisch und entlastet die
  Handtests auf das, was nur am Gerät sichtbar ist.

**R-7 · Dokumente unter `docs/current/` sind veraltet** (D-2, siehe 2.13).

**R-8 · Betrieb des Relays** – aus dem Repository nicht prüfbar. Zu klären
und aufzuschreiben: wer hat Zugang, wo liegt die tägliche Sicherung, wurde
eine Rücksicherung je geprobt, was passiert bei vollem Speicher, wer wird
bei Ausfall benachrichtigt, was kostet es. P1 · S.

### 2.12 Plattformen, Sprache, Zugang

**P-1 · Mehrsprachigkeit** – keine Grundlage (`flutter_localizations`,
`.arb`), rund 1.400–1.800 feste deutsche Texte, davon 358 Zeilen Hilfe.
geprüft · P2 · L · TD-62. Empfehlung siehe ST-2.

**P-2 · Weitere Plattformen** (*Meinung*)
- Linux: am nächsten (Benachrichtigungen sind schon vorgesehen) und nötig
  für den N.E.X.U.S.-Stick aus Bauplan 4.8.1.
- iOS: Hintergrundempfang ohne Push ist dort nicht möglich; verlangt einen
  Push-Weg, also eine neue zentrale Komponente. Früh entscheiden.
- Web: Secure Storage, SQLite und lokale Transporte fehlen; eigenes Projekt.

**P-3 · Zugang ohne eigenes Smartphone** (Bauplan 4.6.1) – nichts
vorbereitet. Der Windows-Client ist die Grundlage für ein
Gemeinschafts-Terminal; es fehlen Mehrbenutzer-Betrieb (mehrere
Identitäten, Abmelden ohne Datenreste) und Barrierefreiheit (U-4). P3 · L.

### 2.13 Abgleich mit der Charta

| Charta | Stand im Code | Bewertung |
|---|---|---|
| Art. 4 Freiwilligkeit, Exit-Recht | Austritt aus Gemeinschaften ja; Konto und Daten löschen nein (D-R2) | Lücke |
| Art. 6 Wahrheit, Ehrlichkeit | Bauplan 9.0 und CLAUDE.md behaupten mehr als der Code (D-1) | Widerspruch |
| Art. 8 Machtbegrenzung, „widerrufbar“ | Superadmin fest eingebaut, kann jede Gemeinschaft netzweit auflösen (`mayDissolveCell`), nicht abwählbar, kein Ablaufdatum | Widerspruch zur Charta; vom Bauplan (11.4) nur befristet gedeckt |
| Art. 9 Schutz Verletzlicher | Blockieren und Stummschalten ja; Meldewege kaum (D-R5); Blockierte lösen weiter Benachrichtigungen aus (S-9) | Lücke |
| Art. 11 nachvollziehbare Protokolle | Decision Records, Historie, Abweichungshinweis | gut umgesetzt; „unveränderlich“ stimmt nicht |
| Art. 12 Delegation begrenzt, widerrufbar | nicht transitiv, je Antrag, jederzeit widerrufbar, Auto-Widerruf | sehr gut umgesetzt |
| Art. 12 Schutz vor Mehrfachidentitäten | fehlt (W-4), dazu S-2 | Lücke |
| Art. 12 analoge Teilhabe | fehlt | Lücke, spät fällig |
| Art. 13 föderierte Gemeinschaften | Gemeinschaften selbstverwaltet; Gründung braucht Genehmigung eines zentralen Schlüssels | teilweise |
| Art. 16 Datenhoheit, Verschlüsselung | lokale verschlüsselte Datenbank, Schlüssel im Secure Storage | gut; Ausnahmen S-7, D-R3, D-R4 |
| Art. 16 kein Social Scoring | kein Zahlenwert im Code; Wallet-Attrappe zeigt aber „AURA 0,00“ | Anzeige entfernen |
| Art. 17 kein einzelner Server | drei Relays, eigene eintragbar | gut; Ausnahmen W-1 |
| Art. 20 Verständlichkeit | Fachsprache (U-2), nur Deutsch (P-1) | Lücke |

**D-1 · Aussagen, die der Code nicht deckt** (geprüft ✔, soweit nicht
anders vermerkt)

| Aussage | Quelle | Stand im Code |
|---|---|---|
| „Quadratic Voting: technisch implementiert, noch nicht aktiviert“ | Bauplan 9.0.3 | nur ein Hilfetext (`help_texts.dart`); keine Logik |
| „Alle Nachrichten sind Ende-zu-Ende-verschlüsselt“ | Bauplan 9.0.1 | öffentliche Kanäle, Dorfplatz, Governance und Kanal-Medien sind Klartext |
| „unveränderlicher Decision Record … Hash-Kette zur Manipulationserkennung“ | Bauplan 9.0.3 | Kette ist geräteabhängig, keine Manipulationsprüfung (TD-41) |
| „BLE – direktes Gerät-zu-Gerät-Routing … läuft heute“, „BLE Mesh“ | Bauplan 9.0.1, CLAUDE.md | kein Weiterleiten; Funktion zwischen zwei Apps *vermutet* nicht gegeben (Z-8) |
| „Anträge … derzeit nur Admins“ | Bauplan 9.0.5 | Anträge stellt, wer Mitglied ist (TD-40-Regeln) – überholt |
| „Auto-Updater (GitHub Releases, alle 6 h): aktiv“ | Bauplan 9.0.4 | war monatelang tot (TD-61), jetzt repariert, ohne Signatur |

**D-2 · Veraltete Arbeitsdokumente** (geprüft ✔)
- `INDEX.md`: Stand 15. Juli; „5 Entscheidungen offen“ (ADR-0001 ist
  angenommen); nennt „Phase 0–5“ statt Stufen A–G; verweist auf
  Bauplan-Extrakt V13.1.
- `PROJECT_STATUS.md`: Schema 23 (ist 28), „keine Signaturprüfung“.
- `EVENT_MAP.md`: Diagramm zeigt „KEINE Signaturprüfung“ und „kein Handler
  prüft die Berechtigung“; nennt Rollen-Abos im `RoleService`, der keinen
  Netzcode hat.
- `RELEASE_READINESS.md`: P1-Punkte offen, die laut TECH_DEBT umgesetzt
  sind; Signatur, CI und Update-Vertrauen fehlen.
- `TECH_DEBT.md`: TD-61 steht noch als „tot“; die Datei ist zu einem
  Verlaufsprotokoll von 485 Zeilen geworden, der aktuelle Stand ist schwer
  ablesbar.
- Empfehlung (S): TECH_DEBT in „offen“ (Tabelle) und „Verlauf“ (Archiv)
  trennen; die anderen vier Dateien auf den Stand bringen.

---

## 3. Telegram-Abgleich

Status nach Codeprüfung. „Kern“ = gehört nach ST-1 zum
Messenger-Fundament; „später“ = bewusst zurückstellen.

| Funktion | Stand | Aufwand | Einordnung | Empfehlung |
|---|---|---|---|---|
| Einzelchats | vorhanden | M | Kern | Absenderbindung (S-1), dann NIP-17/44 |
| Gruppenchats | teilweise – Gruppen sind benannte Kanäle mit festem Schlüssel | L | Kern | Kanal-Medien sofort verschlüsseln; Schlüsselwechsel in Stufe E |
| Große Gruppen | teilweise – keine definierte Grenze, 30-Tage-Fenster | L | später | erst nach Gruppenverschlüsselung |
| Kanäle (Ankündigung) | vorhanden; Durchsetzung beim Empfänger *vermutet* nur in der Oberfläche | M | Kern | Rollenprüfung an der Empfangsgrenze |
| Antworten/Zitate | vorhanden | S | Kern | Bezug auf Event-ID statt Textkopie |
| Bearbeiten | nur lokal (F-1) | M | Kern | netzweit bauen oder ehrlich benennen |
| Weiterleiten | teilweise (F-2) | S | Kern | Medien mitnehmen oder Hinweis zeigen |
| Löschen für alle | vorhanden (Bitte an Relays) | S | Kern | Hinweis „nicht garantiert“ |
| Reaktionen | vorhanden; nicht vom Zweitgerät (TD-71) | S | Kern | TD-71 |
| Erwähnungen | fehlt | M | später | – |
| Anheften | fehlt | S / M | später | Gespräche anheften zuerst (lokal, S) |
| Suche im Gespräch | Einzelchat ja, Kanal nein | S | Kern | Kanal nachziehen |
| Suche über Gespräche | vorhanden, entschlüsselt alles (L-3) | M | Kern | lokaler Suchindex |
| Bilder | vorhanden, Base64 im Event | L | Kern | Medienserver (TD-64) |
| Video, Dateien | fehlt | L | später | folgt aus dem Medienserver |
| Sprachnachrichten | vorhanden; Windows unkomprimiert (F-4) | S | Kern | Kompression unter Windows |
| Videonachrichten | fehlt | L | später | – |
| Link-Vorschau | fehlt im Chat | S–M | später | nur lokal erzeugen, nie über fremde Server |
| Entwürfe | fehlt | S | Kern | je Gespräch lokal speichern |
| Zustellstatus | fehlt (Z-4) | M | **Kern, höchste Priorität** | „wartet / gesendet / angekommen“ |
| Lesestatus | fehlt | M | später | abschaltbar, nur für Kontakte |
| Tippanzeige | fehlt | S–M | später | Metadaten-Abfluss abwägen |
| Ordner/Archiv | fehlt | M | später | Archiv zuerst |
| Gespeicherte Nachrichten | teilweise (Favoriten je Gespräch) | S–M | später | Selbst-Chat, synchron über eigene Geräte |
| Umfragen | nur im Dorfplatz | M | später | Governance deckt Entscheidungen ab |
| Sticker/Emoji | Emoji ja, Sticker nein | M | später | – |
| Benachrichtigungen Android | nur Direktnachrichten, ohne Namen | M | Kern | Kanäle, Namen, Blockierliste |
| Benachrichtigungen Windows | fehlt (F-3) | S–M | Kern | Systemmeldungen |
| Mehrgeräte mit Verlauf | teilweise (Z-10) | L | Kern | Verlauf über Backup-Datei statt Relay-Historie |
| Sprach-/Videoanrufe | fehlt | L | später | braucht Vermittlungsserver – neue zentrale Komponente |
| Bots/Automationen | fehlt | L | später | gehört zum SDK (Bauplan 4.8.1) |
| Stummschalten | Kontakte ja, Kanäle nein | S | Kern | Kanäle nachziehen |
| Blockieren | vorhanden | S | Kern | auch in Kanälen und im Hintergrunddienst |
| Verschwindende Nachrichten | nur lokal | M | später | – |

**Wo Telegram bewusst kein Vorbild ist** (*Meinung*)
- **Telefonnummer als Identität** – die OneApp macht es richtig. Der Preis
  ist die Kontaktfindung; sie braucht einen sehr einfachen Weg (QR-Code,
  Einladungslink), nicht „npub oder DID einfügen“.
- **Cloud ohne Ende-zu-Ende** – Telegrams Komfort (voller Verlauf überall,
  Serversuche, riesige Gruppen, Bots) beruht genau darauf. Vollen Verlauf
  und Suche gibt es dezentral nur über verschlüsselte Sicherung und lokalen
  Index.
- **Lesebestätigung, „zuletzt online“, Tippanzeige** – Metadaten. Die
  90-Sekunden-Präsenz geht heute schon weiter als nötig (D-R4).
- **Link-Vorschau über einen Server** – verrät, was man liest.
- **Algorithmische Empfehlungen** – der Dorfplatz verzichtet zu Recht.
- **Zentrale Moderation** – stattdessen lokale Werkzeuge und Meldewege in
  der Gemeinschaft (Charta Art. 9, 21).

---

## 4. Zwischenplan für die nächsten drei bis sechs Monate

Zuordnung zu `NOW_NEXT_LATER.md`: Stufen A–G und Mesh-Zweig. **neu** = dort
nicht enthalten. ⚠ = Abweichung von der bisherigen Reihenfolge.

Grundregel bleibt: eine Sache nach der anderen, erst nachstellen, dann
beheben, dann am Gerät bestätigen.

### Block 1 – Sofort: Vertrauen und Verlustfreiheit (etwa 3–4 Wochen)

| Schritt | Befund | Zuordnung |
|---|---|---|
| 1.1 Offene Gerätetests abarbeiten und den Zweig pushen | R-6 | Stufe A |
| 1.2 Release-Keystore anlegen, sichern, Umstieg mit den Testern planen | R-1 | **neu** ⚠ |
| 1.3 Stimmen nach DID deduplizieren | S-2 | **neu** ⚠ |
| 1.4 Zeitmarke begrenzen, Abholfenster überlappen | Z-1, Z-2 | **neu** ⚠ (Nacharbeit zu TD-74) |
| 1.5 Identitätsnachweis für Direktnachrichten, Präsenz, Kanalbeiträge; Schlüsselwechsel nur mit Hinweis | S-1 | **neu** ⚠ (Fortsetzung von TD-40) |
| 1.6 Signaturprüfung für LAN/BLE, Entpackgrenze | S-3, C-4 | **neu** ⚠ |
| 1.7 Bilder und Sprachnachrichten in privaten Kanälen verschlüsseln | S-4 | **neu** ⚠ (aus Stufe E vorgezogen) |
| 1.8 Kontakt-Sync: Löschvermerk-Fehler, EOSE statt Wartezeit | C-1, C-2 | Stufe B (Nacharbeit TD-60) |
| 1.9 Dokumente berichtigen: `docs/current/`, CLAUDE.md, Hinweis für Bauplan 9.0 | D-1, D-2 | **neu** |

Begründung der Abweichung: 1.2 bis 1.7 betreffen genau das, was die App
verspricht – wissen, mit wem man schreibt, dass Nachrichten ankommen, dass
eine Stimme eine Stimme ist. Alles Weitere baut darauf. 1.2 wird mit jedem
neuen Tester teurer.

1.5 ändert das Nachrichtenformat: Ältere Versionen ohne Nachweis müssen für
eine Übergangszeit mit Warnhinweis angenommen werden. Das braucht eine
kurze Entscheidung (Abschnitt 5, Nr. 4).

### Block 2 – Zustellung sichtbar machen, Arbeitsweise absichern (etwa 4–6 Wochen)

| Schritt | Befund | Zuordnung |
|---|---|---|
| 2.1 CI: `flutter analyze` + `flutter test` bei jedem PR | R-3 | **neu** |
| 2.2 Zwei-Instanzen-Test im Code | R-6 | **neu** |
| 2.3 Wächtertests: Importrichtung, Speichergrenze, Dateigröße; ADR-0004/0005 annehmen | M-1, C-7 | Stufe E ⚠ vorgezogen |
| 2.4 ADR-0003 neu fassen; erst speichern, dann senden; Status „wartet / gesendet“ in der Nachrichtenblase | Z-3, Z-4 | Stufe B (ADR-0003) + D („Anzeige wartender Nachrichten“) ⚠ vorgezogen |
| 2.5 Outbox für alle Event-Arten, Backoff, Ping | Z-5, Z-6 | Stufe B (TD-48-Umfeld) |
| 2.6 Bluetooth-Verweigerung darf den Chat nicht stoppen | Z-7 | **neu** |
| 2.7 Update: `version.json` signieren, Hash Pflicht | R-2 | Stufe B (TD-61) |
| 2.8 Restliche Stufe-B-Punkte: TD-32, TD-44, TD-45, TD-46, TD-65, TD-71 | – | Stufe B |
| 2.9 Lokalisierungs-**Grundlage** einführen; neue Texte nur noch darüber | P-1 | Stufe C ⚠ nur der erste Teil |

Begründung: 2.3 kostet zwei Tage und verhindert, dass jeder weitere Schritt
die Großdateien vergrößert (Bauplan 4.8.1: „ab sofort“). 2.1 und 2.2 lösen
den Engpass „ein Tester, zwei Geräte“.

### Block 3 – Messenger-Alltag (etwa 6–8 Wochen)

| Schritt | Befund | Zuordnung |
|---|---|---|
| 3.1 Zielbild-Entscheidungen 1–4 und Begriffe („Gemeinschaft“) | U-7 | Stufe D (Voraussetzung) |
| 3.2 Erstnutzer-Weg kürzen, Fachbegriffe ersetzen, Platzhalter ausblenden | U-1, U-2, U-6 | Stufe D (Messenger-first-Modus) |
| 3.3 Verständliche Fehlermeldungen zentral | U-5 | Stufe D |
| 3.4 Desktop: Rechtsklick-Menü, dann Zwei-Spalten-Ansicht | U-3 | Stufe D (TD-68) |
| 3.5 Benachrichtigungen: Windows, Kanäle, Namen, Blockierliste | F-3, S-9 | Stufe D |
| 3.6 Datenbank-Indizes, seitenweises Laden, Startpfad | L-3, L-4 | **neu** |
| 3.7 Kleine Lücken: Bearbeiten, Weiterleiten, Entwürfe, Kanalsuche, Kanal stummschalten, Kompression unter Windows | F-1, F-2, F-4 | Stufe D |
| 3.8 Texte herauslösen und übersetzen (DE/EN) – **nach** 3.1 bis 3.3 | P-1 | Stufe C ⚠ nach hinten |
| 3.9 Datenschutzerklärung, Abmelde-Funktion, Löschzusage, Meldewege | D-R1, D-R2, D-R5 | **neu** |

Begründung zu 3.8: Sonst werden rund 1.500 Texte übersetzt, von denen ein
Teil in 3.1 bis 3.3 umformuliert oder gestrichen wird.

### Block 4 – Format und Funk gemeinsam (ab etwa Monat 4)

| Schritt | Befund | Zuordnung |
|---|---|---|
| 4.1 Mesh M0 (Klären mit Gerald) und M1 (Machbarkeit), zeitlich begrenzt | Z-11 | Mesh-Zweig ⚠ M0/M1 früher, als Vorarbeit für 4.2 |
| 4.2 **Ein** neues Nachrichtenformat entwerfen (ADR): NIP-17/NIP-44 für Nostr, kompakte Form für Funk, Empfangsbestätigung, Absendernachweis | S-5, Z-11 | Stufe D (NIP-17/44) + Mesh M2 ⚠ zusammengelegt |
| 4.3 Medienserver (Blossom) mit Verschlüsselung | L-2 | Stufe D (TD-64) |
| 4.4 GovernanceBridge, `lib/app/`, Modul-Liste, Navigation aus der Liste | M-3 | Stufe E |
| 4.5 NIP-42 am eigenen Relay | TD-78 | Stufe D |

Begründung zu 4.1/4.2: Der Bauplan macht Kommunikation ohne Internet zur
Killer-Funktion, und auf Teneriffa steht die Hardware bereit. Die
Machbarkeitsprüfung entscheidet über das Nachrichtenformat; wird NIP-17
vorher allein entworfen, wird das Format zweimal umgebaut. M3 und M4
(Einbau, Erweiterungen) bleiben danach.

### Danach (außerhalb des Zeitraums)

- Stufe E: Gruppenschlüssel mit Wechsel, vertrauliche Governance (TD-42),
  Übergabe-Kette (C-5), Gerätekonzept (ADR-0002).
- **neu, vor Stufe F:** Bürgschaften als Schutz vor Mehrfachidentitäten
  (W-4), Wiederherstellung über Vertrauenspersonen, Ablauf des
  Superadmin-Mandats.
- Stufe F in dieser Reihenfolge: zuerst der Identitätsschutz, dann
  interzellulär und Quadratic Voting; AETHER nach fertiger Spezifikation.
- Stufe G: Linux zuerst (Stick), iOS nach der Push-Entscheidung.

---

## 5. Offene Entscheidungen

Nur Joachim oder die Gemeinschaft können sie treffen. Jeweils mit
Empfehlung (*Meinung*).

| # | Entscheidung | Empfehlung |
|---|---|---|
| 1 | **Was heißt „Telegram-Niveau“?** Funktionsgleichstand oder Verlässlichkeit der Kernabläufe plus Betrieb ohne Internet | Verlässlichkeit plus Offline. Einteilung „Kern / später“ aus Abschnitt 3 als Arbeitsgrundlage beschließen |
| 2 | **Reihenfolge:** Sicherheits- und Zustellblock vor Mehrsprachigkeit? | Ja. Lokalisierungs-Grundlage sofort, Übersetzung nach der Textbereinigung |
| 3 | **Android-Schlüsselwechsel jetzt**, mit einmaliger Neuinstallation bei allen Testern | Jetzt, mit Anleitung „erst Backup exportieren und zwölf Wörter prüfen“. Jede Woche Warten vergrößert den Kreis der Betroffenen |
| 4 | **Wie lange werden Nachrichten älterer Versionen ohne Identitätsnachweis angenommen?** | Eine Version lang mit sichtbarem Hinweis „Absender nicht bestätigt“, danach ablehnen |
| 5 | **Governance-Daten öffentlich oder vertraulich?** (TD-42) | Innerhalb einer Gemeinschaft vertraulich nach außen und namentlich nach innen. Bis das gebaut ist: klarer Hinweis vor der Stimmabgabe |
| 6 | **Superadmin:** Befugnisse, Dauer, Nachfolge | Ablaufdatum festlegen (Bauplan 11.4: höchstens 730 Tage); netzweites Auflösen fremder Gemeinschaften auf Charta-Verstöße beschränken und jede Nutzung protokollieren; Abwahl vor Ablauf bauen |
| 7 | **Bauplan 9.0 berichtigen** | Ja, mit der nächsten Fassung. Bis dahin ein Hinweis im Repository (`docs/vision/`), was abweicht |
| 8 | **„Zelle“ oder „Gemeinschaft“ in der Oberfläche** | „Gemeinschaft“, wie Charta Art. 13 und Bauplan Anhang D; CLAUDE.md angleichen |
| 9 | **Eigenes Relay:** Aufbewahrungsdauer, Löschzusage, verantwortliche Stelle | Aufbewahrung begrenzen, wo möglich (Präsenz Tage, Direktnachrichten Monate); Löschweg zusagen; rechtlich prüfen lassen, bevor der Nutzerkreis wächst |
| 10 | **Mesh:** M0/M1 schon in Block 4 statt nach Stufe B/C offen zu lassen | Ja, als zeitlich begrenzte Machbarkeitsprüfung, weil sie das Nachrichtenformat bestimmt |
| 11 | **Schutz vor Mehrfachidentitäten:** eigenes Bürgschaftsformat oder Anschluss an Web of Trust | Klein und eigen beginnen, am Format von Web of Trust ausrichten; Bindung erst bei stabiler Spezifikation. Kein Zahlenwert (Charta Art. 16) |
| 12 | **Push für iOS und stromsparendes Android** – eine neue zentrale Komponente | Vor jeder iOS-Arbeit entscheiden. UnifiedPush mit eigenem Server ist der mit der Charta verträglichste Weg |
| 13 | **Platzhalter in der Oberfläche** (Sphären, Wallet, AURA-Anzeige) | Ausblenden, bis die Funktion existiert |

---

## Anhang: Nicht geprüft

- Laufzeitverhalten jeder Art; `flutter analyze` und `flutter test` wurden
  nicht ausgeführt.
- QR-, Einladungs- und Link-Verarbeitung im Detail; BLE über die
  Stichwortsuche hinaus; Erzeugung des Initialisierungsvektors in NIP-04.
- Dorfplatz (`feed_service.dart`) und `proposal_service.dart` nur in
  Ausschnitten.
- Paketversionen (`pubspec.lock`), native Konfiguration, Lizenzen der
  Abhängigkeiten.
- Die 13 Bugmeldungen unter `docs/guides/testing/bugmeldungen/` wurden
  nicht gegen den Code abgeglichen.
- Die Quellen hinter `docs/research/` (Web of Trust, Real Life Stack).
- Betrieb, Sicherung und Kosten des Relays.
