# N.E.X.U.S. – Masterplan & Baustellen-Übersicht

> Gesamtkarte aller Arbeitsfelder. Grundlage für die Entscheidung, was wann KI-gestützt umgesetzt wird.
> Stand: 2026-06-26 · Begleitdokument zu [NEXUS_Kommandozentrale.md](NEXUS_Kommandozentrale.md)

---

## Leitprinzip

**Joachim ist der einzige Integrationspunkt des Projekts.** Jede Nachricht, jeder Post, jede Entscheidung läuft durch ihn → das ist der eigentliche Flaschenhals, nicht fehlende Substanz. **Ziel:** wiederkehrende Arbeit Schritt für Schritt an KI übergeben, damit Joachims knappe Zeit nur noch dorthin fließt, wo wirklich nur er gebraucht wird (Vision, Vertrauen, Schlüsselentscheidungen). Personen-Abhängigkeit (Freiwillige) hat wiederholt nicht getragen → KI als verlässlicher „Mitarbeiter".

---

## Die Baustellen im Überblick

| # | Baustelle | Stand | Wo Joachim Flaschenhals ist | Was KI übernehmen kann | Hebel¹ | Aufwand |
|---|---|---|---|---|---|---|
| B1 | **Wissensbasis / Kommandozentrale** | 🟡 in Aufbau | Wissen verstreut über 98 Chats + Kopf | Chats destillieren, Single Source of Truth pflegen | Fundament | gering |
| B2 | **Telegram-Bot stabilisieren** | 🟡 läuft, fehlerhaft | Bot-Wartung hängt an ihm/Coder | Bugs fixen, Einzelinstanz, Tests grün | **hoch** | mittel |
| B3 | **Community-Management** (4 TG-Gruppen, ~150 Menschen) | 🔴 100 % an Joachim | Nachrichten sichten + beantworten frisst Zeit | Triage, Antwortentwürfe, Onboarding, Moderation | **sehr hoch** | mittel |
| B4 | **Social-Media-Content** (YT, X, IG, TikTok, FB, Bluesky) | 🔴 100 % an Joachim | Jeder Post selbst geschrieben | Content aus Bauplan/Trilogie/Videos erzeugen, cross-posten | **sehr hoch** | mittel |
| B5 | **OneApp-Entwicklung** (Flutter) | 🟢 weit fortgeschritten | Einziger Tester; Dev-Steuerung | Code via Claude Code, Restore-Flow → G2 → Wallet | hoch | hoch |
| B6 | **AETHER-Wallet** (VITA/TERRA/AURA, Phase 1c) | 🔴 ~10 % | Konzept + Umsetzung an ihm | Spezifikation + Implementierung mit Claude Code | mittel | hoch |
| B7 | **Bauplan V13.1 pflegen/weiterentwickeln** | 🟢 vorhanden | Alleinige Autorenschaft | Lektorat, Konsistenz, Versionspflege, Exzerpte | mittel | gering |
| B8 | **Website nexus-terminal.org** | 🟡 läuft (GitHub Pages) | Pflege + neue Seiten | Texte, Landingpages, Download-/Wissensbereich | mittel | gering |
| B9 | **Publishing** (Trilogie, Hörbuch) | 🟢 publiziert | Fortsetzung/Vermarktung | Klappentexte, Beschreibungen, Hörbuch-Skripte | niedrig | gering |
| B10 | **Finanzierung** (Ko-fi, OpenCollective, Crowdfunding) | 🟡 vorbereitet | Aufbau + Kommunikation | Kampagnentexte, Transparenzseiten, Spenderpflege | mittel | gering |
| B11 | **Think-Tank / Freiwillige** | 🔴 ins Leere gelaufen | Akquise + Bindung kostet, trägt nicht | Strategische Entscheidung nötig (s. u.) | offen | — |

¹ Hebel = Entlastung pro Aufwand für Joachim.

---

## Abhängigkeiten

- **B1 (Wissensbasis) ist Fundament für alles**: B2/B3/B4 antworten nur dann „im Geist von N.E.X.U.S.", wenn das Wissen sauber vorliegt. → zuerst, aber schlank halten.
- **B2 (Bot) ist technische Voraussetzung für B3** (Community-Triage läuft über den Bot) und teils B4 (Broadcast/Posting).
- **B5/B6 (App/Wallet)** sind weitgehend **unabhängig** von B2–B4 – können parallel laufen, anderer Arbeitsmodus (Coding).
- **B11 (Think-Tank)** ist eine **strategische Weggabelung**, kein Bauauftrag (s. offene Fragen).

---

## Empfohlene Reihenfolge (Phasen)

**Phase 0 – Fundament (jetzt, schlank)**
- B1: Kern-Wissen sichern (Bauplan-V13.1-Essenz, Charta, Strategie) → Kommandozentrale füllen.

**Phase 1 – Akute Entlastung (größter Hebel zuerst)**
- B2: Telegram-Bot stabilisieren (Einzelinstanz, Tests, Symptome fixen).
- B3: Community-Triage scharf schalten – Bot bereitet Antwortentwürfe vor, Joachim gibt frei.
→ Ergebnis: Das Nachrichten-Hamsterrad wird durchbrochen.

**Phase 2 – Reichweite ohne Mehrarbeit**
- B4: Content-Maschine – aus vorhandenem Material (Bauplan, Trilogie, Videos) Posts für alle Kanäle.

**Phase 3 – Produktfortschritt (parallel, wenn Kapazität)**
- B5: OneApp-Roadmap (Restore-Flow → G2 Liquid Democracy → …).
- B6: AETHER-Wallet.

**Laufend / strategisch**
- B7 Bauplan-Pflege, B8 Website, B9 Publishing, B10 Finanzierung – bei Bedarf eingestreut.
- B11 Think-Tank: bewusst entscheiden statt weiter Energie verlieren.

---

## Offene Fragen an Joachim (für die Feinplanung)

1. **Priorität:** Stimmt die Reihenfolge (erst Bot+Community, dann Social Media, App parallel)? Oder drückt woanders der Schuh mehr?
2. **Telegram-Inhalte:** Joachim möchte mir die Telegram-Inhalte schicken (Community-Nachrichten). → Export-Weg s. u. Damit kann B3 (Triage/Antwortentwürfe) realistisch werden.
3. **Bot-Betrieb:** Wo läuft der Bot aktuell (Cloud/lokal/beides)? Aktuelle Fehlersymptome?
4. **Think-Tank (B11):** Freiwillige weiter akquirieren, oder bewusst auf „KI + Joachim" umstellen und die Community nur noch als Resonanzraum/Tester führen?
5. **Zeitbudget:** Wie viele Stunden/Woche kann Joachim realistisch investieren? (Bestimmt das Tempo.)
6. **Kosten:** API-Kosten (Anthropic) für den Bot laufen pro Nachricht. Budgetrahmen?

---

## Telegram-Inhalte an Claude übergeben – so geht's

**Variante A – Telegram-Chat-Export (für Community-Inhalte):**
1. **Telegram Desktop** öffnen (nicht die Handy-App – Export gibt's nur am Desktop).
2. Die gewünschte Gruppe öffnen → oben rechts **⋮ (Menü)** → **Export chat history**.
3. Format **JSON** wählen (maschinenlesbar; „Photos/Videos" kann man abwählen, um Größe zu sparen).
4. Export speichern → den Ordner nach `2_Community_Management/telegram/exporte/` kopieren.
5. Bescheid geben – ich werte aus (Themen, häufige Fragen, Stimmung, offene Anliegen).

**Variante B – der Bot loggt bereits mit:** Im Bot liegt `data/message_log.db` (SQLite). Auch daraus kann ich Community-Aktivität auslesen, ohne manuellen Export.

---

## Status-Legende
🟢 weit/stabil · 🟡 in Arbeit/teilweise · 🔴 früh/blockiert/voll an Joachim
