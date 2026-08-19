# N.E.X.U.S. Cockpit – MVP-Plan (Stufe A)

> Detailplan vor dem Bau. Erst wenn Joachim diesen Plan freigibt, wird gebaut.
> Stand: 2026-07-05 · Begleitdokument zu [NEXUS_Blaupause_KI-Betriebssystem.md](NEXUS_Blaupause_KI-Betriebssystem.md)

---

## 1. Der Zweck in einem Satz

> **Ein Ort, an dem jede KI-Arbeit stattfindet, gespeichert wird und wiederauffindbar ist – egal welche KI sie erledigt hat.**

Das Kernprinzip gegen Joachims „Wo habe ich das nochmal gemacht?"-Problem:

**Ein Ort = ein Gedächtnis.** Heute ist die Arbeit über claude.ai, ChatGPT und Gemini verstreut – drei getrennte Verläufe, keine gemeinsame Suche, kein gemeinsames Projekt-Ordnungssystem. Im Cockpit läuft jede Aufgabe durch **eine** Datenbank auf Joachims PC. Was einmal dort erledigt wurde, ist für immer auffindbar: nach Stichwort, Projekt, KI oder Datum.

---

## 2. Wie es aussieht

Eine schlichte Web-Oberfläche im Browser (läuft lokal, Doppelklick auf Verknüpfung → Browser öffnet sich):

```
┌────────────┬───────────────────────────────────────────────┐
│  COCKPIT   │  🔍 Suche über alles...                        │
│            ├───────────────────────────────────────────────┤
│ + Neue     │  AUFGABEN                          [Filter ▾] │
│   Aufgabe  │                                               │
│            │  ● OFFEN                                      │
│ PROJEKTE   │  ┌─────────────────────────────────────────┐  │
│ ▸ Community│  │ 🟣 Claude · Community · gestern         │  │
│ ▸ Content  │  │ Antwort auf Kritik von Almuth entwerfen │  │
│ ▸ OneApp   │  └─────────────────────────────────────────┘  │
│ ▸ Bauplan  │  ┌─────────────────────────────────────────┐  │
│ ▸ Finanzen │  │ 🟢 ChatGPT · Content · vor 2 Std        │  │
│ ▸ Privat   │  │ YouTube-Skript: Was ist VITA?           │  │
│            │  └─────────────────────────────────────────┘  │
│ ABLAGE     │                                               │
│ KOSTEN     │  ✓ ERLEDIGT (letzte 7 Tage)                   │
│            │  │ 🔵 Gemini · Bauplan · Mo · Kapitel-Check │  │
└────────────┴───────────────────────────────────────────────┘
```

**Aufgaben-Detail** (Klick auf eine Aufgabe):

```
┌─────────────────────────────────────────────────────────────┐
│ YouTube-Skript: Was ist VITA?          Projekt: Content     │
│ KI: 🟢 ChatGPT   Status: offen   Tags: youtube, aether      │
├─────────────────────────────────────────────────────────────┤
│ DU:      Schreib ein 3-Min-Skript über VITA, Zielgruppe...  │
│ CHATGPT: Hier ist der Entwurf: ...                          │
│ DU:      Mach den Einstieg emotionaler                      │
│ CHATGPT: Überarbeitete Fassung: ...                         │
├─────────────────────────────────────────────────────────────┤
│ [Weiterschreiben…]  [⚖ Kreuzcheck: Claude ▾]  [📋 Kopieren] │
│ [✓ Erledigt]  [→ Andere KI übernehmen lassen]               │
└─────────────────────────────────────────────────────────────┘
```

Jede Aufgabe ist also ein **eigener kleiner Chat-Verlauf** mit der gewählten KI – mit Nachfragen, Korrekturen, allem. Farb-Badge zeigt immer, welche KI dran ist/war.

---

## 3. Was das MVP kann (Muss-Funktionen)

| # | Funktion | Beschreibung |
|---|---|---|
| M1 | **Aufgabe erstellen** | Titel + Text eingeben, **KI wählen** (Claude 🟣 / ChatGPT 🟢 / Gemini 🔵), Projekt zuordnen, optional Tags |
| M2 | **Chat pro Aufgabe** | Innerhalb der Aufgabe weiterfragen/nachbessern – der Verlauf bleibt bei der Aufgabe |
| M3 | **Kreuzcheck** | Ein Klick: aktuelles Ergebnis geht mit Prüfauftrag an eine *andere* KI („Prüfe fachlich, stilistisch, auf Logikfehler"). Antwort erscheint im selben Verlauf, klar markiert |
| M4 | **KI-Wechsel** | Aufgabe samt Verlauf an andere KI übergeben („Übernimm ab hier") |
| M5 | **Projekte & Tags** | Feste Bereiche (s. Abschnitt 5) + freie Schlagworte |
| M6 | **Volltextsuche** | Ein Suchfeld über ALLE Aufgaben, Verläufe, KIs, Projekte – Treffer zeigen Kontext |
| M7 | **Status** | offen / erledigt / archiviert; Startseite zeigt Offenes zuerst |
| M8 | **N.E.X.U.S.-Kontext** | Pro Projekt ein hinterlegter System-Prompt (z. B. Sprachregeln, Bauplan-Kern bei Community/Content-Aufgaben) – jede KI antwortet automatisch „im Geist von N.E.X.U.S.", ohne dass Joachim es jedes Mal erklären muss |
| M9 | **Kostenzähler** | Laufende Monatskosten pro KI sichtbar (Budget-Wächter für die 100 €) |
| M10 | **Alles lokal** | SQLite-Datenbank auf dem PC, API-Schlüssel in `.env`, keine Cloud-Pflicht, Export als Markdown möglich |
| M11 | **Sparring-Modus** | Aufgabentyp „Denken/Sparring": freies Nachdenken mit einer KI ohne Erledigungs-Druck – für Strategie, Ideen, Zweifel. Läuft wie ein normaler Chat, gehört aber zum Projekt und ist durchsuchbar |
| M12 | **Destillieren-Knopf** | Nach einem Sparring/einer Aufgabe: ein Klick → KI zieht Erkenntnisse & Entscheidungen heraus → wird als **Wissensnotiz** gespeichert (Joachim prüft kurz). So wächst aus Gesprächen dauerhaftes Wissen, statt in Verläufen zu versinken |
| M13 | **Wissensnotizen** | Eigener Bereich: kuratierte Notizen mit Typ (💡 Erkenntnis / ⚖️ Entscheidung / 📌 Fakt / 🧭 Position), verknüpft mit Projekt + Tags. Notizen können einem Projekt „angeheftet" werden → fließen automatisch in den KI-Kontext (M8) ein — **das ist das gemeinsame Gedächtnis, in das alle KIs schauen** |
| M14 | **Mehrbenutzer-Fundament** | Benutzerkonten (Admin: Joachim · Rolle: Mitarbeiter) + Sichtbarkeit `privat`/`geteilt` auf allem. **Defaults je Rolle:** Joachim → privat als Standard; Mitarbeitende → Projekt-Arbeit standardmäßig `geteilt` (sichtbar für Team + Joachim, fließt ins Gedächtnis), nur persönliches Sparring privat. **Wissens-Schleuse:** Destillate von Mitarbeitenden landen in einer Freigabe-Warteschlange bei Joachim – nichts wird ungeprüft Teil des gemeinsamen Gehirns. **Admin-Übersicht:** Aktivität, Destillate und KI-Kosten pro Person; Projekt-Zugriff pro Person steuerbar; Kostenzähler (M9) mit Monats-Limit pro Benutzer. **Rechte-Grundgerüst:** „Vorbereiten" (Entwürfe, Recherche) für alle – „Freigeben/nach außen senden" ist ein eigenes Recht, anfangs nur Joachim, später pro Bereich/Kanal delegierbar (wirksam ab Stufe B/C) |

**Soll-Funktionen (direkt nach dem MVP, Stufe A+):**

| # | Funktion | Beschreibung |
|---|---|---|
| S1 | **Ablage** | Wichtige Ergebnisse aus *externen* Chats (claude.ai, ChatGPT-App) per Copy-Paste einwerfen → werden Teil des durchsuchbaren Gedächtnisses |
| S2 | **Import Claude-Export** | Die bereits exportierten 98 Claude-Chats (`conversations.json`) ins Archiv importieren → das Gedächtnis startet nicht bei Null |
| S3 | **Prompt-Vorlagen** | Wiederkehrende Aufträge als Baustein („Social-Post im N.E.X.U.S.-Ton", „Kritik beantworten") |
| S4 | **Datei-Anhänge** | Dokument an Aufgabe hängen (z. B. Bauplan-Kapitel als Kontext) |
| S5 | **Intelligente Wissenssuche (RAG)** | Statt nur Stichwortsuche: Bedeutungssuche über ALLES (Bauplan, Charta, Notizen, Verläufe). Die KI bekommt bei jeder Aufgabe automatisch die relevanten Passagen – auch aus 400 Seiten Bauplan. Technisch: Vektor-Index, lokal, gut machbar |
| S6 | **Web-Recherche** | Recherche-Aufgaben mit echter Websuche direkt aus dem Cockpit (alle drei Anbieter bieten das per API) – Ergebnisse landen sofort im Gedächtnis statt in einem Browser-Tab |
| S7 | **Entscheidungs-Chronik** | Gefilterte Ansicht aller ⚖️-Notizen: Was wurde wann entschieden und warum – das Gedächtnis gegen „Warum hatte ich das nochmal so gemacht?" |

**Bewusst NICHT im MVP** (kommt in Stufe B/C laut Blaupause): Posteingang/Bot-Anbindung, Freigabekarten, Morgenbriefing, Content-Ausspielung, Sprach-Eingabe.

---

## 4. Wie du den Überblick über alle KIs behältst

Das ist das Herzstück – vier Mechanismen:

1. **Eine Suche statt drei Verläufe.** „almuth", „vita demurrage", „youtube skript" → ein Suchfeld findet es, egal ob Claude, ChatGPT oder Gemini es bearbeitet hat und egal wann.
2. **Projekte statt Chat-Chaos.** Jede Aufgabe gehört zu einem Bereich. Klick auf „Content" → alles, was je für Content gemacht wurde, chronologisch.
3. **KI-Badge an jeder Aufgabe.** Du siehst auf einen Blick: das hat ChatGPT geschrieben, das hat Claude geprüft. Beim Kreuzcheck steht beides im selben Verlauf untereinander.
4. **Ehrliche Grenze + Lösung:** Was du *außerhalb* (in den Apps von claude.ai/ChatGPT/Gemini) machst, kann das Cockpit nicht automatisch sehen. Lösung: (a) neue Arbeit wandert Stück für Stück ins Cockpit, weil es dort bequemer ist; (b) wichtige externe Ergebnisse wirfst du in die **Ablage** (S1); (c) deine Claude-Historie wird einmalig **importiert** (S2). Ziel-Zustand: Das Cockpit ist dein Gedächtnis, die KI-Apps sind nur noch Notizzettel.

---

## 4b. Second-Brain-Architektur: Das Drei-Schichten-Gedächtnis

Das Cockpit ist als **Second Brain** angelegt. Drei Schichten, ein Kreislauf:

```
  ┌───────────────────────────────────────────────┐
  │ SCHICHT 3: DESTILLAT (klein, kuratiert)       │
  │ Wissensnotizen: 💡 Erkenntnisse ⚖️ Entschei-  │
  │ dungen 📌 Fakten 🧭 Positionen                │
  │ → wird jeder KI automatisch mitgegeben        │
  └──────────────▲────────────────────────────────┘
                 │ Destillieren-Knopf (M12)
  ┌──────────────┴────────────────────────────────┐
  │ SCHICHT 2: ARBEIT (vollständig, roh)          │
  │ Alle Aufgaben, Sparrings, Kreuzchecks –       │
  │ jeder Verlauf, durchsuchbar                   │
  └──────────────▲────────────────────────────────┘
                 │ Aufgaben & Gespräche
  ┌──────────────┴────────────────────────────────┐
  │ SCHICHT 1: QUELLEN (Fundament)                │
  │ Bauplan V13.1 · Charta · Chat-Exporte ·       │
  │ Ablage · Dokumente                            │
  └───────────────────────────────────────────────┘
```

**Der Kreislauf:** Du denkst/arbeitest mit einer KI (Schicht 2, gespeist aus Schicht 1) → das Wertvolle wird destilliert (Schicht 3) → ab da kennt **jede** KI diese Erkenntnis bei jedem künftigen Auftrag. Das Wissen wächst mit jeder Sitzung – und es gehört **dir**, nicht dem KI-Anbieter.

**Philosophische Passung:** Das Second Brain folgt denselben Prinzipien wie die OneApp – local-first, eigene Daten, anbieterunabhängig. Claude, ChatGPT und Gemini werden zu austauschbaren Denkern, die alle in dasselbe souveräne Gedächtnis schauen. Fällt ein Anbieter aus oder wird zu teuer: Das Wissen bleibt.

---

## 5. Vorgeschlagene Projekt-Bereiche (Startordnung)

| Projekt | Was dort läuft | Hinterlegter Kontext (M8) |
|---|---|---|
| **Community** | Antworten auf Nachrichten/Kritik, Telegram-Themen | N.E.X.U.S.-Sprachregeln + Kernwissen |
| **Content** | Posts, Skripte, Thumbnails-Ideen für YT/FB/X/TikTok | Sprachregeln + Zielgruppen-Ton |
| **OneApp** | Konzeptfragen, Texte, Release-Notes (Code bleibt in Claude Code) | Technik-Stand der App |
| **Bauplan & Charta** | Kapitel prüfen, Versionen, Exzerpte | Dokumenten-Struktur V13.1 |
| **Finanzen & Orga** | Crowdfunding, Ko-fi, Verwaltung | neutral |
| **Privat** | Alles Nicht-Nexus | neutral, wird von Nexus-Suchen ausgeklammert wenn gewünscht |

(Projekte sind im Cockpit frei änderbar – das ist nur die Startaufstellung.)

---

## 6. Technik (kurz)

- **Läuft lokal:** ein kleines Programm auf Joachims PC, Oberfläche im Browser (`localhost`), Start per Desktop-Verknüpfung
- **Stack:** Python (FastAPI) + SQLite + schlichte HTML-Oberfläche – bewusst einfach, wartbar, kein Server nötig
- **KI-Anbindung:** offizielle APIs (Anthropic, OpenAI, Google). **Startet auch mit nur dem Anthropic-Schlüssel** (existiert schon) – ChatGPT-/Gemini-Slots schalten sich frei, sobald die Keys eingetragen sind
- **Modell-Politik (Budget):** Standard = **Sonnet** (stark + günstig, wenige Cent pro Aufgabe) · **Haiku** für Routine/Triage (nochmals günstiger) · teurere Modelle nur gezielt für schwere Strategie-Aufgaben. Pro Aufgabe überschreibbar
- **Kosten:** Software 0 € · API nach Verbrauch (Zähler eingebaut) · bleibt im 100-€-Rahmen
- **Sicherheit:** Keys nur in lokaler `.env`, Datenbank nur auf dem PC, automatisches Backup der Datenbank in einen wählbaren Ordner
- **Mehrbenutzer-ready ab Tag 1 (M14):** Benutzerkonten + Sichtbarkeits-Modell sind von Anfang an im Datenmodell. Start lokal (nur Joachim); sobald Mitarbeitende Zugriff brauchen, Umzug auf Railway (~5 €/Monat, bekannt vom Bot) – **ohne Umbau**, gleiche App, gleiche Datenbank

---

## 7. Bau-Reihenfolge (wenn freigegeben)

1. Grundgerüst: Datenbank, Projekt-/Aufgabenstruktur, Oberfläche
2. Claude-Anbindung + Chat pro Aufgabe (M1, M2) → **ab hier schon täglich nutzbar**
3. Suche, Status, Projekte/Tags (M5–M7)
4. ChatGPT- + Gemini-Anbindung, Kreuzcheck, KI-Wechsel (M3, M4)
5. N.E.X.U.S.-Kontext pro Projekt (M8)
6. Kostenzähler, Backup, Feinschliff (M9, M10)
7. Danach A+: Ablage, Claude-Import, Vorlagen (S1–S3)

Jeder Schritt wird einzeln getestet, bevor der nächste beginnt (kein Sammelumbau).

---

## 8. Was Joachim dazu braucht / entscheiden muss

1. **Freigabe dieses Plans** (oder Änderungswünsche – besonders: fehlt eine Muss-Funktion?)
2. Später für M-Vollausbau: **OpenAI-API-Key** und **Google-AI-Key** anlegen (je ~5 Min, Anleitung kommt von mir, wenn es so weit ist) – zum Start reicht der vorhandene Anthropic-Key
3. Prüfen: Stimmen die 6 Projekt-Bereiche als Startaufstellung?
