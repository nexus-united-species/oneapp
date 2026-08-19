# N.E.X.U.S. – Blaupause: Das KI-Betriebssystem für die Bewegung

> Zieldokument für Joachims „KI-Master mit Agenten-Team".
> Beschlossen auf Basis von Joachims Antworten am 2026-07-05.
> Begleitdokumente: [NEXUS_Kommandozentrale.md](NEXUS_Kommandozentrale.md) · [NEXUS_Masterplan_Baustellen.md](NEXUS_Masterplan_Baustellen.md)

---

## 1. Getroffene Entscheidungen (Joachims Antworten)

| Frage | Entscheidung |
|---|---|
| Bot-Betrieb | Läuft **nur auf Railway**. Probleme: Freigabekarten oft unverständlich, Antwortvorschläge unzureichend, Sinnerkennung schwach. **Joachim macht selbst eine Test-Session** (mit seinem Bot-Claude-Code-Projekt) und meldet die Fehler. |
| Steuerungs-Ort | **NICHT Telegram.** Eine eigene Oberfläche („Cockpit"), in der alles zusammenläuft – inkl. Arbeit mit mehreren KIs (Claude, ChatGPT, Gemini), **KI-Wahl pro Aufgabe**, KIs gegenseitig prüfen lassen. |
| Sofort-Autonomie | Bot macht schon einiges autonom (Inventur s. Abschnitt 3) – Umfang okay, Qualität muss besser werden. |
| Prioritäts-Kanäle | **YouTube, Facebook, X, TikTok** |
| Zeitfenster | **Morgens**, Dauer je nach Aufwand → Morgenbriefing |
| Budget | **max. ~100 €/Monat** (Solo-Finanzierung, etwas Unterstützung aus der Gruppe) |
| Offen | Volumen-Verteilung der Eingangskanäle (Frage 7) · E-Mail-Anbieter Gmail vs. Proton (Frage 8) · Ergebnis der Bot-Test-Session |

---

## 2. Das Zielbild: N.E.X.U.S. Cockpit

Eine lokale Web-Oberfläche auf Joachims PC (später hostbar), die drei Dinge vereint:

```
┌────────────────────────────────────────────────────────┐
│                  N.E.X.U.S. COCKPIT                    │
│                                                        │
│  ① AUFGABEN-ZENTRALE                                   │
│     Aufgabe eingeben → KI wählen (Claude/GPT/Gemini)   │
│     → Ergebnis ansehen → ggf. Kreuzcheck durch         │
│     andere KI → übernehmen/verwerfen                   │
│                                                        │
│  ② POSTEINGANG & FREIGABEN                             │
│     Alle eingehenden Nachrichten (Telegram-Bot,        │
│     E-Mail, Kommentare, weitergeleitetes WhatsApp)     │
│     → Triage → Antwortentwürfe → Freigabe-Klick        │
│     (ersetzt die unverständlichen Telegram-Karten)     │
│                                                        │
│  ③ MORGENBRIEFING                                      │
│     Was ist passiert · was wartet auf Freigabe ·       │
│     was schlägt die KI heute vor                       │
└────────────────────────────────────────────────────────┘
         │                    │                  │
   KOMMUNIKATION          CONTENT           ENTWICKLUNG
   Telegram-Bot           YT/FB/X/TikTok    OneApp via
   (Railway) + weitere    Pipeline mit      Claude Code
   Konnektoren            Freigabe-Queue    (wie bisher)
```

**Multi-KI-Prinzip:** Jede Aufgabe hat ein KI-Dropdown (Anthropic/OpenAI/Google per API). Zusätzlich „Kreuzcheck"-Knopf: Ergebnis von KI A wird an KI B zur Kritik geschickt – genau Joachims heutiger Workflow, nur ohne Copy-Paste zwischen drei Browsertabs.

**Wichtig (Kosten/Zugang):** Das Cockpit nutzt **API-Schlüssel** – das ist getrennt von ChatGPT-Plus/Gemini-Abos. Benötigt: Anthropic-Key (existiert, Bot nutzt ihn), OpenAI-Key und Google-AI-Key (je 5 Min Einrichtung, Pay-per-Use). Bei Joachims Volumen realistisch 20–60 €/Monat für alle drei zusammen + ~5 € Railway → **im 100-€-Rahmen**.

---

## 3. Inventur: Was der Bot heute schon autonom macht (Code-geprüft)

**Vollautonom (ohne Freigabe):**
- KI-Antworten im **Privat-Chat** mit dem Bot (immer)
- KI-Antworten bei **@Erwähnung** und bei **Reply auf eine Bot-Nachricht** in Gruppen
- Keyword-Fragen („Was ist VITA?") – aber **nur wenn Aktivmodus für die Gruppe an ist**
- **Onboarding-Interview**: Bot führt bei Beitrittsanfragen selbstständig das Interview im Privat-Chat
- **Staffelstab-Begrüßung**: neues Mitglied kommt → Bot bittet das vorherige Mitglied, es zu begrüßen
- **Tagesdigest** (Statistik) und **KI-Wochenbericht** an Admins (Job Queue)
- Passives Mitlesen aller Gruppennachrichten für Triage + Wochenbericht

**Mit Freigabe (Karten an Joachim):**
- Beitritts-Entscheidung (Approve/Decline)
- Zeiterfassungs-Freigaben
- Triage-Antwortentwürfe (Orchestrator-Karten) ← *hier liegt die Qualitäts-Baustelle*
- Broadcasts (nur manuell per Befehl)

**⚠️ Beobachtung aus dem Code** (für Joachims Test-Session): In `handlers/welcome.py` wird das Willkommens-Template zwar geladen, aber **nie gesendet** – nur die Staffelstab-Nachricht geht raus. Falls neue Mitglieder eigentlich einen Willkommenstext bekommen sollen: das ist entweder ein Bug oder ein stiller Funktionswechsel.

---

## 4. Ausbaustufen

**Stufe A – Cockpit-MVP** *(erster Bauabschnitt, lokal, kostenlos)*
- Aufgaben-Eingabe + KI-Wahl pro Aufgabe (Claude/GPT/Gemini) + Verlauf
- Kreuzcheck-Funktion (KI prüft KI)
- Aufgabenliste mit Status
- Ort: `C:\nexus-cockpit` · Stack: Python/FastAPI + SQLite + schlichte Web-UI, Keys in `.env`

**Stufe B – Posteingang & Freigaben**
- Anbindung Telegram-Bot (Railway) → Triage-Karten erscheinen im Cockpit statt als kryptische Telegram-Karten
- Weiterleitungs-Trick für WhatsApp & Co. (alles in einen Trichter)
- E-Mail-Konnektor (Gmail leicht, Proton via Bridge)

**Stufe C – Morgenbriefing & Content-Maschine**
- Tägliches Briefing (morgens): Lage, Freigaben, Vorschläge
- Content-Pipeline für YouTube, Facebook, X, TikTok: Entwurf aus Bauplan/Trilogie-Material → Freigabe-Queue → Ausspielung (Reuse prüfen: z. B. Open-Source-Scheduler Postiz) → einfaches Tracking
- Sprach-Eingabe für Aufgaben (Transkription)

**Stufe D – Teilautonomie**
- Bewährte Routinen laufen ohne Freigabe, Joachim bekommt Berichte
- Autonomie pro Bereich einzeln hochgedreht, nie pauschal

---

## 5. Arbeitsteilung jetzt

| Wer | Was |
|---|---|
| **Joachim** | Test-Session mit dem Bot (eigenes Claude-Code-Projekt), Fehler sammeln → Ergebnis melden. Antworten auf Frage 7 (Kanal-Volumen) + 8 (E-Mail-Anbieter) nachliefern. OpenAI-/Google-API-Keys anlegen (Anleitung folgt bei Bedarf). |
| **Claude Code (hier)** | Cockpit-MVP bauen (Stufe A), danach Bot-Anbindung (Stufe B) – abgestimmt mit den Ergebnissen der Test-Session. |

**Leitplanke:** Nichts geht ohne Joachims Klick nach außen, bis er einem Bereich ausdrücklich Autonomie gibt. Die KI spricht nie ungeprüft im Namen der Bewegung (Stufe D ist immer eine bewusste Entscheidung pro Bereich).

---

## 5b. Sequenzierung: Erst alle lokalen Erweiterungen, dann Railway-Umzug (2026-07-06)

**Entscheidung von Josh:** Der Umzug des Cockpits auf Railway (nötig für Handy-Zugriff
und echte Telegram-Bot-Anbindung) kommt **zuletzt**, nicht jetzt. Vorher werden alle
Erweiterungen gebaut, die rein lokal funktionieren — vermeidet, dass Auth/Postgres/
Hosting-Arbeit mehrfach gemacht werden muss.

**Warum der Umzug kein einfaches Kopieren ist** (festgehalten für später):
1. **Login wird Pflicht** — aktuell kein Zugriffsschutz (unkritisch lokal, kritisch
   sobald öffentlich erreichbar). Bauzeitpunkt: direkt vor dem Umzug.
2. **Second-Brain-Quellen sind lokale Ordnerpfade** (`C:\nexus-bauplan`,
   `C:\Users\joach\Documents\...`) — ein Server kann die nicht lesen. Lösung
   vermutlich: Sync bleibt lokal (liest Joshs Ordner), Ergebnis-Datenbank wechselt
   zu Postgres (von PC und Server erreichbar).
3. **Persistenter Speicher auf Railway** nötig (sonst Datenverlust bei Neustarts).
4. **Embedding-Modell-Ressourcenbedarf** auf Railway noch zu pruefen (RAM-Tarif).

**Reihenfolge danach vereinbart:**
1. Ablage (S1)
2. Prompt-Vorlagen (S3)
3. Entscheidungs-Chronik (S7)
4. Content-Pipeline (Stufe C, zunaechst ohne Auto-Posting — Entwuerfe + manuelle Freigabe)
5. **Zuletzt:** Railway-Umzug (Login/Postgres/Persistenz) + echte Telegram-Bot-Anbindung
   (bidirektional: Bot fragt Second Brain ab, Gruppen-Inhalte fliessen mit Freigabe
   ins Second Brain)

## 6. Erfolgs-Maßstab

Aus dem Bauplan übernommen („Wir messen in Zeit, nicht in Zahlen"):
> **Wie viele Stunden pro Woche gewinnt Joachim zurück für Arbeit, die nur er tun kann?**

Zweitmetriken: Reaktionszeit auf Community-Nachrichten ↓ · veröffentlichte Posts/Woche ↑ bei gleichem Zeiteinsatz · Freigabe-Quote der KI-Entwürfe ↑ (Qualitätsindikator).
