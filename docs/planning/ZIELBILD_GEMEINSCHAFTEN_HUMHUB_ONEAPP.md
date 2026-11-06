# Zielbild: Gemeinschaften, Portal und OneApp zusammenführen

Stand: 6. November 2026
Status: **Entwurf** – Diskussionsgrundlage, keine Entscheidung
Anlass: Die Community-Plattform (HumHub, `community.nexus-terminal.org`) und
die OneApp haben überlappende Begriffe und Funktionen. Langfristig soll die
OneApp das Portal ablösen, sobald sie ausgereift und auf allen Plattformen
verfügbar ist. Damit es für die Menschen einfach bleibt, wird das Zielbild
festgelegt, **bevor** Navigation und Messenger-first-Modus gebaut werden
(Phase 3 im Projektablauf).

Quellen: Server-Dokumentation im Cockpit-Repository (Abschnitt 4, HumHub und
eigene Module), [messenger-first-modus.md](messenger-first-modus.md),
[NOW_NEXT_LATER.md](NOW_NEXT_LATER.md).

---

## 1. Ausgangslage

| | OneApp (heute) | Portal / HumHub (heute) |
|---|---|---|
| Gespräche | Direktchat, Kanäle | private Nachrichten, Video-/Sprachnachrichten |
| Gruppen | Gemeinschaften (früher „Zellen“) mit Pinnwand und Agora | Kreise (thematisch: Kreis 0 Entwicklungsrat … Kreis 9 Gesundheit & Pflege, dazu Sonderkreise) |
| Neuigkeiten | Dorfplatz (Beiträge, Kommentare, Reposts) | Übersicht / Stream aus Kreisen und Profilen |
| Werkzeuge | Anträge, Abstimmungen, Liquid Democracy | Projekte & Teams, Wissen, Dateien (Nextcloud), Meetings (kMeet), Arbeitsstunden, Abzeichen, Bibliothek, Finanzen-Ampel, KI-Assistent, Übersetzen |
| Wirtschaft | Wallet-Platzhalter | Marktplatz (eigener Kreis), Karte der Gemeinschaften |
| Konto | Seed-Phrase, DID, kein zentrales Konto | E-Mail und Passwort über Authentik (SSO) |
| Plattformen | Android, Windows | jeder Browser |

Das Risiko: Würde man beide Welten einfach zusammenlegen, gäbe es fünf oder
sechs Orte, an denen „etwas los ist“. Das widerspricht dem Ziel, dass die
OneApp für neue Menschen zuerst ein einfacher, sehr guter Messenger ist.

## 2. Festgelegt (6. November 2026)

1. **Begriff: Kreis = Gemeinschaft.** Nutzerseitig heißt alles
   „Gemeinschaft“ – sowohl die thematischen Kreise aus dem Portal als auch
   örtliche Gemeinschaften. Es gibt keinen zweiten Gruppenbegriff.
2. **Kanal und Gruppe bleiben vorläufig, wie sie sind.** Ob Kanäle später
   nach dem Telegram-Modell (Gruppe = alle schreiben, Kanal = wenige
   schreiben, viele lesen) neu geordnet oder an Gemeinschaften gebunden
   werden, wird später entschieden.

## 3. Zielbild (Vorschlag)

### Wenige Grundbegriffe, alles andere sind Werkzeuge

| Grundbegriff | Bedeutung |
|---|---|
| **Chats** | Zwiegespräche, Gruppen und Kanäle (Ordnung siehe Abschnitt 2, Punkt 2) |
| **Gemeinschaften** | Eine Gruppe mit Mitgliedern, Rollen, Pinnwand und zuschaltbaren Werkzeugen – thematisch (heutige Kreise) oder örtlich |
| **Dorfplatz** | Was ist neu in *meinen* Gemeinschaften und Chats (Vorschlag, siehe offene Frage 1) |

Alles Weitere wird ein **Werkzeug, das je Gemeinschaft eingeschaltet wird**:
Anträge und Abstimmungen, Projekte & Teams, Wissen, Dateien, Meetings,
Arbeitsstunden, Marktplatz, später AETHER.

Das Portal arbeitet bereits so: Module lassen sich je Kreis ein- und
ausschalten. Es dient damit als erprobte Vorlage für den Modulrahmen der
OneApp (Phase 4).

### Eine Struktur, zwei Arten von Gemeinschaft

Thematische Gemeinschaften (heutige Kreise) und örtliche Gemeinschaften sind
technisch dasselbe Objekt. Sie unterscheiden sich nur in der Art, der
Voreinstellung der Werkzeuge und ggf. der Gründungsregel – nicht im Begriff
und nicht in der Bedienung.

### Dorfplatz statt globaler Timeline

Die Erfahrung aus dem Portal: Die Timeline war den Menschen zu viel und wurde
am 28.10.2026 auf den Marktplatz reduziert. Für die OneApp folgt daraus:
Der Dorfplatz zeigt in erster Linie Neuigkeiten aus den eigenen
Gemeinschaften und von Kontakten, keinen ungefilterten Gesamtstrom. Ein
öffentlicher Bereich ist höchstens ein bewusst gewählter Zusatz.

## 4. Zu klärende Unstimmigkeiten

1. **Gründung von Gemeinschaften läuft auseinander.** Im Portal gründen sich
   Gemeinschaften laut Entscheidung vom 30.09.2026 zuerst im Portal (Karte der
   Gemeinschaften). Die OneApp hat einen eigenen Gründungsweg mit
   Gründungsgenehmigung. Vor jeder Weiterentwicklung der Gemeinschaften in der
   OneApp abstimmen, welcher Weg gilt und wie beide zusammenpassen.
2. **Marktplatz gibt es bereits im Portal.** Ein OneApp-Marktplatz muss
   dessen Inhalte und Regeln übernehmen können, statt einen zweiten
   Marktplatz daneben zu stellen.
3. **Private Gemeinschaften brauchen Gruppenverschlüsselung.** Kreise sind
   heute nur für Mitglieder sichtbar. Auf Nostr ist das nur möglich, wenn
   Inhalte für die Gruppe verschlüsselt sind oder ein Relay die
   Mitgliedschaft durchsetzt. Heute liegen Governance-Daten im Klartext auf
   öffentlichen Relays (TD-42). Optionen:
   - **NIP-29** (Gruppen, deren Mitgliedschaft das Relay verwaltet): passt
     zum geplanten eigenen Relay, macht die Gemeinschaft aber von diesem
     Relay abhängig.
   - **Ende-zu-Ende-Gruppenverschlüsselung** mit Schlüsselrotation:
     dezentraler, deutlich aufwendiger (siehe LATER „Schlüsselrotation“).

   → eigene Architekturentscheidung (ADR) nötig, bevor private
   Gemeinschaften in der OneApp gebaut werden.
4. **Einige Werkzeuge brauchen dauerhaft Server** (Dateien, Video, Wissen mit
   Versionen, Meetings). Das ist mit dem Prinzip vereinbar, solange es
   austauschbare Dienste bleiben und keine zentrale Plattform entsteht.
5. **Zwei Kontomodelle.** Portal: E-Mail/Passwort über Authentik. OneApp:
   Seed-Phrase, kein zentrales Konto. Ein zentraler Login in der OneApp
   widerspräche deren Grundprinzip.
6. **Plattformen.** Das Portal läuft in jedem Browser. Ablösung setzt
   mindestens iOS und macOS voraus; eine Browser-Fassung einer App mit
   Seed-Phrase ist sicherheitlich heikel und gesondert zu bewerten.

## 5. Übergangspfad (Vorschlag)

| Stufe | Portal | OneApp |
|---|---|---|
| 1. Jetzt | Ort für Organisation und Zusammenarbeit | sicherer Messenger; baut bewusst *nicht* nach, was das Portal gut kann, sondern was es nicht kann: verschlüsselt, mobil, offline, ohne zentralen Betreiber |
| 2. Brücke | bleibt führend | Konto-Verknüpfung (OneApp-Identität ↔ Portal-Konto); Hinweise „Neues in deinen Gemeinschaften“ mit Link ins Portal |
| 3. Umzug | schrumpft Werkzeug für Werkzeug | sobald ein Werkzeug gleichwertig ist, zieht eine Gemeinschaft damit um |
| 4. Ablösung | Export, dann Abschaltung | alle Plattformen bedient, alle Werkzeuge umgezogen |

## 6. Offene Entscheidungen

| # | Frage | Empfehlung | Wer |
|---|---|---|---|
| 1 | Wird der Dorfplatz die Übersicht der eigenen Gemeinschaften statt einer globalen Timeline? | ja | Community / Josh |
| 2 | Welcher Gründungsweg für Gemeinschaften gilt (Portal, OneApp, beide)? | Portal-Weg als Vorgabe, OneApp übernimmt ihn | Josh |
| 3 | Technische Grundlage privater Gemeinschaften: NIP-29 oder Ende-zu-Ende? | als ADR vorbereiten | Architektur |
| 4 | Konto-Verknüpfung Portal ↔ OneApp: ja oder nein? | ja, als Voraussetzung für den Umzug | Josh / Joachim |
| 5 | Ordnung von Kanal und Gruppe | vorläufig zurückgestellt | später |
| 6 | Welche Plattformen sind Pflicht vor der Ablösung (iOS, macOS, Linux, Browser)? | iOS und macOS mindestens | Joachim |

**Zeitpunkt:** Die Entscheidungen 1 bis 4 sollen vor Phase 3 (Navigation,
Messenger-first-Modus) stehen. Phase 0 bis 2 (Aufräumen, Konto und Sync,
Mehrsprachigkeit) hängen nicht davon ab.
