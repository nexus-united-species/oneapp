# Research

Untersuchte externe Projekte und Technologien. Hier steht, **was andere gebaut
haben** – nicht, was N.E.X.U.S. tut.

Erfüllt §6 des [Architektur-Briefings 2026](../planning/ARCHITEKTUR_BRIEFING_2026.md).

## Abgrenzung

| Ort | Inhalt |
|---|---|
| `research/` | Fremde Projekte, Analysen, Vergleiche |
| `decisions/` | Was **wir** daraus entscheiden (ADRs) |
| `current/` | Was **bei uns** tatsächlich ist |

Ein Rechercheergebnis ist **keine Entscheidung**. Wird aus einer Analyse eine
Festlegung, gehört sie als ADR nach `decisions/`.

## Bestand

| Dokument | Gegenstand | Bewertung |
|---|---|---|
| [WEB_OF_TRUST.md](WEB_OF_TRUST.md) | Adapter-Architektur, Vertrauensmodell, Krypto-Stack | **hoch relevant** – gleiche Krypto-Wahl wie N.E.X.U.S. |
| [REAL_LIFE_STACK.md](REAL_LIFE_STACK.md) | Connector-Architektur, Modulbaukasten | **relevant als Muster** – Code nicht übernehmbar (React/TS) |
| [SOURCELESS.md](SOURCELESS.md) | Web3-Ökosystem, STR.Domains, CCoin | **Gegenbeispiel** – als Vorbild nicht geeignet |

## Stand der Recherche

Erhoben am 18. August 2026 aus öffentlichen Projektseiten, GitHub-Repositories
und unabhängigen Quellen. Projektstände ändern sich; die Momentaufnahme ist in
jedem Dokument datiert.

## Wichtiger Hinweis zur Verwandtschaft

**Web of Trust und Real Life Stack sind kein getrenntes Begriffspaar, sondern
ein zusammenhängender Stack.** Das Briefing behandelt sie als zwei separate
Learnings. Tatsächlich gilt:

```
Real Life Stack   Anwendungsmodule + Connector-Schicht (Karte, Kalender, …)
        │
Web of Trust      Vertrauens- und Identitätsebene (Adapter, DIDs, Attestations)
```

Web of Trust nennt Real Life Stack ausdrücklich als Grundlage seiner Apps;
Real Life Stack führt einen „WoT-Connector". Beide stehen unter MIT-Lizenz und
gehören zum selben Umfeld.
