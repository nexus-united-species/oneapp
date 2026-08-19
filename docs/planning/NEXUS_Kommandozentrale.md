# N.E.X.U.S. – Kommandozentrale

> Zentrale Wissensbasis & Steuerdokument für das Gesamtprojekt.
> Lebendes Dokument – wird laufend aus den Chat-Exporten und der Arbeit gefüllt.
> Stand: 2026-06-26 · Status: **in Aufbau** (gefüllt aus Think-Tank-Chats; Bauplan/Charta/Strategie folgen)

---

## 1. Was N.E.X.U.S. ist (Kurzfassung)

- **Vision:** Ein dezentrales „Betriebssystem für die Menschheitsfamilie" – Protokoll, keine Plattform. Parallelaufbau statt Reform. Dezentral statt Zentralmacht, Vertrauen statt Kontrolle.
- **Fundament:** Bauplan (aktuell **V13.1**), Roman-Trilogie (Band 1–3), Whitepaper, Konzeptpapier Phase 0.
- **Publiziert:** 15. Januar 2026. Seitdem Aufbau von Community, Social Media und App.
- **Gründer:** Joachim (öffentlich als „Josh Richman"). **Solo-Gründer** + KI-gestützte Umsetzung (Claude Code).
- **Lizenz:** Code AGPL-3.0 (Netzwerk-Copyleft, bewusst gewählt). Bauplan urheberrechtlich geschützt.

---

## 2. Die drei Baustellen (und wo es brennt)

| Baustelle | Stand | Engpass |
|---|---|---|
| **OneApp-Entwicklung** | Sehr weit (s. Abschnitt 3). Läuft gut mit Claude Code. | 🟢 Nur das *Testen* hängt allein an Joachim |
| **Wissen / Bauplan** | Existiert, war über ~98 Chats verstreut → jetzt im Archiv | 🟡 Wird gerade konsolidiert |
| **Außenwelt** (Nachrichten, Community, Social Media, Kooperationen) | 100 % an Joachim, kein System | 🔴 **Hier brennt es – der eigentliche Flaschenhals** |

**Kernproblem:** Joachim ist der einzige Integrationspunkt. Jede Nachricht, jeder Post, jede Entscheidung läuft durch ihn. Die vielen menschlichen Kontakte kosten so viel Zeit, dass die eigentliche Umsetzung des Bauplans stockt. Ziel: **mehr KI-gesteuert** arbeiten statt sich auf überlastete Mitstreiter verlassen.

---

## 3. OneApp – technischer Stand (Repo: `C:\nexus-oneapp`)

- **Tech:** Flutter/Dart (Android + Windows; iOS/Linux später), SQLite (verschlüsselt, AES-256-GCM), Provider, GoRouter.
- **Transport:** Nostr (primär) + BLE Mesh + LAN, Fallback-Kaskade. Offline-First.
- **Identität:** BIP-39 Seed Phrase, Ed25519, DID (W3C did:key), Self-Sovereign Identity.
- **Fertig (Auswahl):** E2E-Chat, Kanäle/Gruppen, Kontaktsystem (4 Vertrauensstufen), Dorfplatz (dezentraler Social Feed), Governance G1 + Zellgründungsfreigaben (manuell getestet), Backup, Tombstones, 35+ grüne Tests, Windows-Installer, Auto-Updater.
- **Releases:** v0.1.10, v0.2.0 (APKs vorhanden).
- **Wirklich früh (~10 %):** AETHER-Wallet (VITA/TERRA/AURA, Phase 1c) und G2 Liquid Democracy.
- **Nächste Meilensteine:** Restore-Flow reparieren → Relay-ACK für Governance → G2 (Liquid Democracy) → AETHER-Wallet.
- **Wichtige Repo-Regeln:** NIE `flutter clean`, NIE `adb uninstall`/`flutter install`, NIE DB-Tabellen droppen, immer auf Gerät testen vor Push, Push via `git push origin master:main`. (Details in `C:\nexus-oneapp\CLAUDE.md`.)

---

## 4. Think Tank „Genesis Circle" – der Think Tank der 95 %

**Idee:** Die Elite hat Think Tanks (Davos, Bilderberg, WEF). N.E.X.U.S. baut den Think Tank der **95 %** – Intelligenz von unten statt Geld von oben. Ziel ursprünglich: über die Community an Experten kommen, die den Bauplan mit umsetzen.

**Struktur (Soziokratie-inspiriert, keine Pyramide):**
- **6 Archetypen:** Architekt · Coder/Macher · Hüter · Denker · Erzähler · Macher
- **5 Arbeitskreise:** Code · Mind & Law · Soil & Hands · Care · Voice (jeder autonom, koordiniert über Liquid-Democracy-Idee)

**⚠️ Realitätsabgleich (Stand 2026-06-26):** Die im Frühjahr aufgenommenen Genesis-Circle-Mitglieder (elSID, Jackson, Josef, Angela u. a.) sind **nicht mehr dabei** – „das waren alles nur große Worte, keiner mehr dabei". Auch der erste Coder **Alex** lieferte nicht. **Der Think Tank als Experten-Pool hat sich nicht materialisiert.** Das ist der Kern von Joachims Entscheidung, künftig stärker KI-gestützt statt personenabhängig zu arbeiten.

**Lektion:** Sich auf einzelne, überlastete Freiwillige zu verlassen, hat wiederholt nicht funktioniert. Daraus folgt die strategische Wende: KI als verlässlicher „Mitarbeiter" für die wiederkehrende Arbeit.

---

## 5. Community-Infrastruktur (wie sie wirklich ist)

**Wichtige Lektion aus der Praxis:** Discord-Server für den Think Tank wurde gebaut, ist aber **ruhiggestellt** – Leute sind es satt, viele Plattformen zu bedienen. Bewusste Entscheidung: **alles auf Telegram bündeln** über Untergruppen.

**Heutige Telegram-Struktur: 4 Gruppen** (genaue Namen aus Screenshots noch zu erfassen; bekannt aus Bot-Config):
- Genesis Kanal (Ankündigungen)
- Sektor 1 – Hauptgruppe (Community)
- Sektor 2 – Wohnen, Commons & Eigentum
- Sektor 3 – AETHER-Ökonomie

**Zahlen (Stand Gespräch):** Telegram-Gruppe ~150, Kanal ~110 (evtl. redundant). Discord eingefroren, nicht gelöscht.

**Tools-Entscheidung:** GitHub bleibt technischer Arbeitsraum (Pages, Issues, Projects, Discussions, Wiki). Telegram für Community. Keine Kosten, kein eigener Server in dieser Phase.

---

## 6. Social-Media-Präsenz (seit 15.01.2026 aufgebaut)

| Kanal | Handle / Link |
|---|---|
| Website | nexus-terminal.org |
| YouTube | @Project-N.e.x.u.s-Official (Erklärvideos, Hörbuch-Playlist) |
| Telegram Kanal | t.me/NexusProjectOfficial |
| Telegram Gruppe | t.me/Nexus_Project_official |
| Facebook | NexusTerminal |
| Instagram | n.e.x.u.s._navigator |
| X (Twitter) | nexusxnavigator |
| Bluesky | nexus-navigator.bsky.social |
| TikTok | (vorhanden) |
| Amazon | Roman-Trilogie (Kindle), Hörbuch gratis auf YouTube |
| GitHub | project-nexus-official/oneapp (privat) |

---

## 7. 🤖 Der N.E.X.U.S. Telegram-Bot (existiert, läuft, ist noch fehlerhaft)

**Ort:** `2_Community_Management/telegram/nexus-telegram-bot/`
**Status:** Gebaut und lauffähig, ~6.566 Zeilen Python, sauber strukturiert, **mit Tests**. Läuft aber „noch sehr fehlerhaft".

**Stack:** `python-telegram-bot[job-queue]`, KI-Anbieter wählbar (Anthropic/Google/OpenAI) via `.env`. Deployment als Worker (`Procfile: worker: python bot.py`, `runtime.txt: python-3.12`) – also für Cloud-Hosting (Railway/Render o. ä.) vorbereitet.

**Architektur:**
- `handlers/` – admin, public, welcome, discussion, onboarding, tasks, triage, orchestrator_buttons, lage
- `services/` – ai_service, message_log, orchestrator, task_db, triage
- `config/` – settings, groups, system_prompt, master_prompt, knowledge_base, bauplan_sektoren, triage_rules, welcome_texts

**Funktionen (weit über die Spezifikation hinausgewachsen):**
- Management: `/broadcast`, `/broadcast_sektor`, `/status`, `/digest`, `/aktivmodus`, Tages-Digest + Wochenbericht (Job Queue)
- KI-Diskussion: `/frage`, @-Erwähnung, Keyword-Trigger, Aktivmodus, `/zusammenfassung`, Gesprächsgedächtnis
- **Triage-System:** passiver Sammler beobachtet Gruppennachrichten, klassifiziert sie
- **Orchestrator:** interner Triage-Kanal mit Freigabekarten + Entwurfsbearbeitung (Antwortentwürfe, die Joachim freigibt)
- **Proof-of-Work-Board + Zeiterfassung:** `/aufgaben`, `/melden`, `/zeit`, `/zeit_bericht`, `/zeit_export` (SQLite: `data/tasks.db`)
- **Onboarding:** Beitrittsanfragen mit Approve/Decline-Buttons
- Willkommensnachrichten pro Sektor

**🔴 Konkreter Bug-Befund (aus `bot.log`):**
```
telegram.error.Conflict: terminated by other getUpdates request;
make sure that only one bot instance is running
```
→ **Mehrere Bot-Instanzen liefen gleichzeitig** (z. B. Cloud-Deployment + lokaler Start). Zwei Poller reißen sich um dieselben Updates → erratisches Verhalten (doppelte/fehlende Antworten). **Häufigste und gut behebbare Ursache** für „der Bot spinnt". (Log-Einträge vom 09.06.2026 – aktuelle Symptome noch zu verifizieren.)

**Wissensbasis des Bots:** Kompakter System-Prompt (Identität, Sprachregeln, 3 Grundregeln, Genesis-Pakt, Dreischicht-Modell, AETHER VITA/TERRA/AURA, Liquid Democracy, Strategie). Bauplan-Docs liegen unter `nexus-telegram-bot/docs/` (Charta, Gründungsleitfaden, OneApp-Anleitung).

**Nächster Schritt:** Bot stabilisieren (Einzelinstanz sicherstellen, Tests grün, Symptome reproduzieren) – statt neu bauen. Mit Claude Code (hier) machbar, ohne auf einen Coder zu warten.

---

## 8. Offene Entscheidungen / nächste Schritte

1. **Wissensbasis vervollständigen:** Bauplan V12, Charta, Graswurzel-/virale Strategie, Unternehmenskongress, AETHER-Arbeitsgruppe, Leitfaden Gemeinschaftsgründung aus dem Archiv destillieren.
2. **Erste Automatisierung wählen** (Empfehlung: N.E.X.U.S.-Telegram-Bot als „Operations-Layer").
3. **Social-Media-Content-Maschine** aus vorhandenem Material (Trilogie, Whitepaper, Videos).
4. **App-Roadmap** weiterführen (Restore-Flow → G2 → Wallet).

---

## Anhang: Quellen & Arbeitsorte
- **`C:\nexus-bauplan`** – eigenes Git-Repo des Bauplans: V13.0/V13.1 als **Markdown**, Ordner `kapitel/`, `kompass/`, `quelle/`, `referenz/`, `release/`, plus `AENDERUNGSPROTOKOLL.md` und `REDAKTIONSPLAN_V13.md`. **Quelle der Wahrheit für den Bauplan** – bevorzugte Wissensquelle fürs Cockpit (statt docx-Extraktion)
- **`C:\nexus-oneapp`** – OneApp-Repo (Flutter) + Implementierungsplan (`README.md`, `CLAUDE.md`, `NEXUS_OneApp_Implementierungsplan_V5.2.md`)
- **`C:\nexus-cockpit`** – (geplant) Cockpit/Second Brain: nur Programm + Gedächtnis-Datenbank, keine Originaldokumente
- Chat-Archiv (33 substanzielle Chats): `0_Administration/chat-exporte/.../_chats_md/`
- Index aller 98 Chats: `0_Administration/chat-exporte/.../_INDEX_chats.md`
- Strategische Dokumente im Nexus-Hauptordner (Whitepaper V6.3, Konzeptpapier Phase 0, Master-Prompt)
