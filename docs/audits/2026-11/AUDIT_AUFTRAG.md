# Audit-Auftrag N.E.X.U.S. OneApp – November 2026

Stand: 11. November 2026 · Auftraggeber: Joachim (Projektleitung)
Diesen Text als Auftrag an das prüfende Modell geben. Bauplan v14 und die
N.E.X.U.S.-Charta lädt Joachim zusätzlich hoch.

---

## Rolle und Rahmen

Du prüfst die N.E.X.U.S. OneApp unabhängig – als erfahrener Architekt,
Sicherheitsprüfer und Produktgestalter in einer Person. Du **änderst
nichts** am Code und committest nichts. Ergebnis ist ein Bericht und ein
Zwischenplan.

- **Repository:** `C:\nexus-oneapp`, Zweig **`lead/multi-agent`** (11 Commits
  vor `main`, noch nicht gepusht, Gerätetests stehen aus). Prüfe diesen
  Zweig, nicht `main`.
- **Umfang:** Flutter/Dart, rund 72.600 Zeilen in `lib/`, 92 Testdateien,
  zuletzt 1773 Tests grün, 5 bekannte rote (TransportManager).
- **Zielplattformen heute:** Android und Windows.
- **Einstieg in die Doku:** `docs/INDEX.md`, dann `docs/current/` (vor allem
  `TECH_DEBT.md`, `EVENT_MAP.md`, `ARCHITECTURE_REALITY.md`,
  `DO_NOT_TOUCH.md`, `GERAETETESTS_OFFEN.md`), `docs/decisions/` (ADRs),
  `docs/planning/NOW_NEXT_LATER.md` (aktuelle Gesamtplanung Stufen A–G mit
  Mesh-Zweig), frühere Audits unter `docs/audits/2026-07/` und `2026-08/`.
- **Projektregeln:** `CLAUDE.md` im Repository (u. a. Offline-First,
  Empfang ist eine Vertrauensgrenze, nur additive DB-Migrationen, AETHER-
  Begriffe statt „Geld/Zahlung“).
- **Vision:** Bauplan v14 und Charta (hochgeladen). Die OneApp soll die
  digitale Basis sein, um den Bauplan in die Realität zu bringen.

**Leitsatz bisher:** Messenger First – Modular Underneath. Kein Rewrite.
Du darfst diesen Leitsatz begründet in Frage stellen.

## Arbeitsweise

- **Belege statt Eindrücke:** Jeder Befund mit Datei und Zeile
  (`pfad/datei.dart:123`) oder Dokumentstelle. Kennzeichne klar:
  *geprüft* (im Code gesehen), *vermutet* (Indiz, nicht bestätigt),
  *Meinung* (Bewertung).
- **Bekanntes nicht neu erfinden:** Gleiche Befunde mit `TECH_DEBT.md` und
  den früheren Audits ab. Nenne, was dort fehlt, falsch eingeschätzt oder
  inzwischen erledigt ist.
- **Priorität und Aufwand:** P0 (blockiert Nutzung/Sicherheit), P1 (vor
  breiter Nutzung), P2 (wichtig), P3 (später). Aufwand grob S/M/L.
- **Realistisch bleiben:** Kleines Team, Entwicklung überwiegend mit KI,
  ein Tester mit zwei Geräten. Empfehlungen müssen in dieser Lage
  umsetzbar sein; kein Big-Bang-Umbau.

## Prüffelder

### 1. Code-Review
Korrektheit, Fehlerbehandlung, Nebenläufigkeit (Async-Gaps, parallele
Relay-Events), Datenintegrität (Migrationen, Verschlüsselung der POD-
Spalte `enc`), Testabdeckung und -qualität, Lesbarkeit. Schwerpunkt auf den
Änderungen seit `main` (`git log origin/main..lead/multi-agent`).

### 2. Strategie-Review
Passt der Ist-Stand und die Planung (Stufen A–G in `NOW_NEXT_LATER.md`)
zu Bauplan v14 und Charta? Was fehlt für die Umsetzung des Bauplans, was ist
überflüssig, was ist in falscher Reihenfolge? Konkrete Vorschläge.

### 3. Funktionalität – Messenger auf Telegram-Niveau
Ziel: ein erstklassiger Messenger, mindestens so angenehm wie Telegram,
aber Ende-zu-Ende-verschlüsselt und dezentral. Prüfe den Ist-Stand gegen
diese Liste und bewerte, was fehlt und wie schwer es ist:
Einzel- und Gruppenchats, große Gruppen, Kanäle, Antworten/Zitate,
Bearbeiten, Weiterleiten, Löschen für alle, Reaktionen, Erwähnungen,
Anheften, Suche (lokal, über Gespräche), Medien (Bilder, Video, Dateien,
Sprachnachrichten, Videonachrichten), Link-Vorschau, Entwürfe, Lese- und
Zustellstatus, Tippanzeige, Ordner/Archiv, „Gespeicherte Nachrichten“,
Umfragen, Sticker/Emoji, Benachrichtigungen (auch im Hintergrund, Desktop),
Mehrgeräte-Betrieb mit vollständigem Verlauf, Sprach- und Videoanrufe,
Bots/Automationen. Nenne auch, wo Telegram bewusst **kein** Vorbild sein
soll (Cloud ohne E2E, Telefonnummer als Identität).

### 4. UX und UI
Erstnutzer-Weg (Onboarding, Seed Phrase, Backup), Alltagsabläufe,
Konsistenz, Barrierefreiheit, Desktop-Bedienung (Maus, Tastatur,
Rechtsklick), Fehlermeldungen in verständlicher Sprache, Begriffe laut
CLAUDE.md („Menschheitsfamilie“, „Gemeinschaften“, „Anträge“, „Dorfplatz“).
Wo verwirrt die App, wo fehlt Rückmeldung?

### 5. Dezentralität und Web of Trust
Wie dezentral ist die App wirklich (Abhängigkeit von Relays, eigenem VPS-
Relay `relay.nexus-terminal.org`, Superadmin-Rolle, Update-Server)? Was
passiert, wenn das eigene Relay ausfällt? Bewertung des Vertrauensmodells
(Kontakte mit Vertrauensstufen, Identitätsnachweis DID↔Nostr, Bürgen) und
der möglichen Kooperation mit Web of Trust / Real Life Stack
(`docs/research/`). Sybil-Resistenz für Abstimmungen.

### 6. Modularität
Ist der Weg „erst Messenger, dann Module“ im Code vorbereitet? Wie sollte
ein Modulrahmen aussehen (je Gemeinschaft zuschaltbare Werkzeuge,
Governance, später Marktplatz/AETHER, Sphären aus dem Bauplan)? Bewertung
der großen Dateien (`chat_provider.dart` 3756 Zeilen,
`proposal_service.dart` 4172, `nostr_transport.dart` 3541) und der offenen
ADRs 0002–0005.

### 7. Sicherheit und Kryptografie
Bedrohungsmodell, Schlüsselverwaltung (BIP-39, Secure Storage,
Hintergrunddienst), Direktnachrichten noch über NIP-04 (Metadaten sichtbar;
NIP-17/NIP-44 geplant), Empfangsprüfung (Signatur, Absenderberechtigung),
Governance-Integrität (eigene Auszählung, Hash-Kette, Quorum). Was ist
wirklich geschützt, was nur scheinbar?

### 8. Datenschutz und Recht
Personenbezogene Daten auf dem eigenen Relay (dauerhafte Speicherung,
Löschanfragen), Governance-Daten öffentlich im Klartext (TD-42),
Datenschutzerklärung, Meldewege für Inhalte, AGPL-Lizenz.

### 9. Zuverlässigkeit, Sync und Offline
Mehrgeräte-Konsistenz (Kontakte, eigene Nachrichten, Profile,
Mitgliederlisten), Warteschlangen, Verhalten bei langen Offline-Phasen,
LAN/BLE, Vorbereitung des Mesh-Zweigs (Reticulum/LoRa für den Teneriffa-
Piloten, siehe `NOW_NEXT_LATER.md` und `docs/specs/drafts/mesh/`).

### 10. Leistung und Ressourcen
Akku und Datenvolumen (Hintergrunddienst, Abos, Bilder als Base64 in
Events), Startzeit, Speicherwachstum, Verhalten mit vielen Kontakten,
Gruppen und Anträgen.

### 11. Release-Fähigkeit und Betrieb
Build- und Release-Prozess, Update-Mechanismus, Code-Signierung,
`flutter analyze`-Hinweise (Baseline über 900), rote Tests, CI, Rückstau
an Gerätetests, Betrieb des Relays (Sicherung, Überwachung, Kosten).

### 12. Plattformen, Sprache, Zugang
iOS/macOS/Linux/Web, Mehrsprachigkeit (noch keine, rund 1.500 feste
deutsche Texte), Zugang ohne eigenes Smartphone laut Bauplan.

### 13. Abgleich mit der Charta
Wo widerspricht der Code den Werten der Charta (z. B. zentrale Rollen,
Datenhoheit, Transparenz der Abstimmungen)? Wo setzt er sie gut um?

## Ergebnis

1. **Kurzfassung** (eine Seite): die zehn wichtigsten Befunde und
   Empfehlungen, nach Priorität.
2. **Befunde je Prüffeld**, jeweils: Befund · Beleg · Bewertung
   (geprüft/vermutet/Meinung) · Priorität · Aufwand · Empfehlung.
3. **Telegram-Abgleich als Tabelle:** Funktion · vorhanden/teilweise/fehlt ·
   Aufwand · Empfehlung.
4. **Zwischenplan:** die nächsten 3–6 Monate in Stufen. Ordne jeden Schritt
   den bestehenden Stufen A–G und dem Mesh-Zweig aus `NOW_NEXT_LATER.md`
   zu oder kennzeichne ihn als **neu**. Markiere, wo du von der bisherigen
   Reihenfolge abweichst, und begründe es.
5. **Offene Entscheidungen**, die nur Joachim oder die Community treffen
   können, mit deiner Empfehlung.

Schreibe auf Deutsch, mit echten Umlauten.
