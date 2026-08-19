# Real Life Stack

Recherchestand: 18. August 2026
Grundlage: **Codeanalyse des geklonten Repositories**

Quellen: [github.com/real-life-org/real-life-stack](https://github.com/real-life-org/real-life-stack) ·
[real-life-stack.de](https://real-life-stack.de)

> **Korrekturhinweis.** Eine erste Fassung beruhte nur auf der Website und
> beschrieb Real Life Stack als reinen Frontend-Baukasten mit einer schmalen
> Connector-Schicht. Der Code zeigt mehr: sieben Connectoren, ein
> Vokabular-/Typmanifest-System, Relation Records mit kryptografischer
> Absenderbindung und einen `wot-connector` mit eigener Inbox- und
> Identitätsverwaltung.

## Was es ist

Ein modularer App-Baukasten in TypeScript/React für lokale Gemeinschaften. Die
Anwendungsschicht über [Web of Trust](WEB_OF_TRUST.md).

```
Real Life Stack   Module + DataInterface + Connectoren
        │
Web of Trust      Identität, Vertrauen, Sync (via wot-connector)
        │
Human Money Core  Gutscheine (Rust, geplant als RLS-Modul)
```

## Reifegrad

| | |
|---|---|
| Sprache | TypeScript, React 19 |
| Umfang | 319 Dateien (`.ts`/`.tsx`, ohne Tests) |
| Lizenz | MIT |
| Commits | ~1.075 |
| Sterne | 4 |
| Modulreife | Feed v0.1, Kanban v0.2, Kalender v0.1, Karte v0.2 — durchweg **Draft** |

## Die Pakete

| Paket | Inhalt |
|---|---|
| `data-interface` | Die Schnittstelle: Basis-Connector, Vokabular, Typmanifest, Relation Records, Claims, Votes |
| `mock-connector` | In-Memory, für Entwicklung und Tests |
| `local-connector` | IndexedDB mit Cross-Tab-Sync |
| `graphql-connector` + `graphql-server` | klassischer Server |
| `supabase-connector` | Backend-as-a-Service |
| `wot-connector` | Brücke zu Web of Trust: Identität, Attestation-Wire, Inbox, Biometrie, Cross-Group-Index |
| `toolkit` | UI-Bausteine |

**Fünf Connectoren gegen eine Schnittstelle**, von In-Memory bis dezentral-E2EE.
Das ist die belastbarste Demonstration des Prinzips aus §8 des Briefings, die ich
gefunden habe: Dieselben Module laufen gegen fünf grundverschiedene Backends.

## Der übertragbare Kern

### Fähigkeiten deklarieren statt voraussetzen

> „Each connector implements the DataInterface and **only the capabilities its
> data source supports**."

Ein Connector implementiert nur, was seine Datenquelle kann. Das ist unabhängige
Bestätigung für den Entwurf in
[ADR-0003](../decisions/ADR-0003-zustellsemantik.md), wo Transporte
Zustellzustände melden *können*, aber nicht müssen.

### Relation Records mit kryptografischer Absenderbindung

Der wertvollste Einzelbefund. In [`votes.ts`](https://github.com/real-life-org/real-life-stack/blob/master/packages/data-interface/src/votes.ts)
sind Stimmen keine eigenständigen Objekte, sondern Beziehungssätze:

```
predicate: "votesOn"
from:      global:<voterDid>
to:        item:<statementId>
fields:    { value }
```

Die Garantien:

- `createdBy` kommt **aus der authentifizierten Identität, nie vom Aufrufer**
- die kanonische ID ist ein **SHA-256 über `[createdBy, predicate, from, to]`** —
  also genau eine ID pro (Wähler, Statement)
- gelesen wird ein Satz nur akzeptiert, wenn `from === global:<createdBy>` —
  **ein Satz, der den Endpunkt eines anderen behauptet, zählt nie**
- eine vorab angelegte ID mit fremder Identität **scheitert**, statt idempotent
  zu gelingen

**Das ist strukturell gelöst, was N.E.X.U.S. als Prüfung fehlt.** Audit Lauf B
hält in V-005 fest, dass Direktstimmen nicht gegen die
Stimmberechtigten-Menge geprüft werden. Lauf A findet in F-005, dass eine Stimme
mit leerem `voterPubkey` gespeichert werden kann und über
`UNIQUE(proposal_id, voter_pubkey)` mit REPLACE eine fremde Stimme
überschreiben könnte.

Beide Probleme entstehen, weil Absender und Datensatz-Identität in N.E.X.U.S.
**getrennt** sind und die Verbindung geprüft werden *muss*. Bei Real Life Stack
ist die Absenderidentität **Teil der Datensatz-ID** — Fälschung ist nicht
verboten, sondern unmöglich.

Das ist ein direkt verwertbares Muster für
[ADR-0001](../decisions/ADR-0001-identitaets-identifier.md) und für die Behebung
von V-005/F-005: Wer die Identität in die Datensatz-ID bindet, braucht keinen
nachgelagerten Wählerfilter.

### Weitere Muster

- **Mock-Connector.** N.E.X.U.S. hat keinen In-Memory-Datenpfad; Fachlogik hängt
  direkt an SQLite und Tests brauchen eine echte Datenbank. Ein Mock-Pfad ist
  ein kleiner, eigenständiger Nutzen — unabhängig von
  [ADR-0004](../decisions/ADR-0004-storage-grenze.md).
- **Vokabular und Typmanifest** (`vocab.ts`, `type-manifest.ts`). Datentypen
  sind deklariert, nicht hart verdrahtet. Grundlage dafür, dass Gruppen Module
  ohne Codeänderung aktivieren.
- **Offene Formate.** Kalender über iCal/CalDAV, Karte über
  OpenStreetMap/MapLibre. Kein Eigenformat, wo ein Standard existiert — §9 des
  Briefings in der Praxis.

## Was das „votes"-Modul nicht ist

Zur Vermeidung eines Missverständnisses: Das Resonance-Modul kennt drei Werte
(`green`, `yellow`, `red`) und umfasst 103 Zeilen. Es ist ein
Stimmungsbild-Mechanismus.

Es hat **nicht**: Antragslebenszyklus, Quorum, Delegation, Liquid Democracy,
Decision Records mit Hash-Kette, eingefrorene Stimmberechtigten-Snapshots,
Single Choice, Candidate Choice, Stichwahl.

N.E.X.U.S. hat all das — `proposal_service.dart` allein hat 4.097 Zeilen und 596
grüne Tests. **Governance bleibt der stärkste eigene Beitrag.** Aber die kleine
Abstimmungsprimitive dort löst die Absenderbindung eleganter.

## Was nicht übernehmbar ist

- **Der Code.** TypeScript/React 19 gegen Flutter/Dart — keine gemeinsame
  Grundlage. Weder Module noch Connectoren noch das Toolkit lassen sich
  übernehmen oder portieren, ohne sie neu zu schreiben.
- **Die Modulliste ist keine Vorlage.** Karte, Kalender, Kanban und Feed decken
  sich nur teilweise mit Dorfplatz, Zellen, Agora und Governance.
- **Die Connector-Schicht sitzt im Frontend**, unterhalb einer Schnittstelle für
  UI-Module. Sie ist keine vollständige Infrastrukturabstraktion für Transport,
  Krypto oder Replikation — das leistet Web of Trust eine Ebene tiefer. Das
  Zielbild aus §8 (`Agora → NexusCore.governance`) beschreibt eine tiefere
  Abstraktion als das, was Real Life Stack tut.

## Offene Fragen

- Ist das Relation-Record-Modell (`docs/spec/08-relation-records.md`) Teil der
  gemeinsamen Spezifikation oder RLS-intern? Falls spezifiziert, wäre es ein
  Kandidat für eine Dart-Implementierung.
- Lohnt ein Mock-/In-Memory-Datenpfad für N.E.X.U.S.-Tests, unabhängig von
  jeder Kooperation?
