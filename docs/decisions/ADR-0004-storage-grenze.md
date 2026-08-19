# ADR-0004 – Grenze zwischen Fachlogik und Persistenz

Status: `VORGESCHLAGEN`
Datum: 18. August 2026
Betrifft: Schichtung, Testbarkeit, Local First

## Kontext

20 Dateien importieren [pod_database.dart](../../lib/core/storage/pod_database.dart)
direkt. Davon liegen 13 in `features/` und `services/` – also oberhalb der
Persistenzschicht:

```
features/chat/          channel_conversation_screen · chat_provider
                        conversation_screen · conversation_service
                        group_channel_service · message_search_screen
features/governance/    cell_founding_permit_service · cell_service
                        proposal_detail_screen · proposal_service
features/dorfplatz/     feed_service
features/profile/       profile_screen
features/settings/      settings_screen
services/               contact_request_service · role_service
```

Auffällig: **Sechs davon sind Screens.** `proposal_detail_screen`,
`profile_screen`, `settings_screen`, `conversation_screen`,
`channel_conversation_screen` und `message_search_screen` greifen direkt auf
die Datenbank zu. Die Persistenzschicht reicht damit bis in die Widget-Ebene.

Es existieren einzelne DAOs (`publish_result_dao`, `proposal_option_dao`,
`delegation_dao`), aber sie sind nicht durchgängig. Eine Repository-Grenze gibt
es nicht.

Auswirkungen:

- **Testbarkeit.** Fachlogik, die direkt an SQLite hängt, braucht für Tests
  eine echte Datenbank. Das erklärt einen Teil des Aufwands in der bestehenden
  Testsuite.
- **Local First.** Das Briefing stellt in Abschnitt 20 richtig fest, dass
  lokale SQLite-Haltung noch kein Local First ist. Solange Screens direkt
  Tabellen lesen, ist keine Schicht vorhanden, in der Konfliktauflösung oder
  Replikation überhaupt stattfinden könnte.
- **Austauschbarkeit.** Der Grundsatz „No Single Dependency" (Abschnitt 28)
  nennt SQLite ausdrücklich. Mit 13 direkten Zugriffen aus der Fachschicht ist
  SQLite heute nicht austauschbar.

## Entscheidung

**Vorschlag: Zwischen Fachlogik und Datenbank gilt eine Repository-Grenze.
Sie wird ab sofort für neuen Code eingehalten und bei Gelegenheit auf
Bestandscode angewendet – nicht in einer Migration.**

Zwei Regeln:

1. **Widgets greifen nicht auf die Datenbank zu.** Ein Screen erhält seine
   Daten über einen Service oder Provider. Diese Regel gilt ohne Ausnahme für
   neuen Code.
2. **Neue Fachlogik nutzt ein DAO oder Repository**, keinen direkten
   `PodDatabase`-Zugriff. Bestehende DAOs sind die Vorlage.

Ausdrücklich **nicht** entschieden: eine vollständige
Clean-Architecture-Schichtung mit `domain/`, `data/` und `presentation/`. Diese
Struktur wäre für dieses Projekt Overengineering – sie erzwingt Mapping-Code
zwischen Schichten, ohne dass es dafür heute einen Bedarf gibt.

## Alternativen

**A – Vollständige Repository-Schicht für alle 20 Zugriffsstellen.**
Vorteil: sauber und einheitlich. Nachteil: Betrifft `proposal_service.dart`
(4.097 Zeilen) und `chat_provider.dart` (2.765 Zeilen) – die am schwersten zu
testenden Dateien der Codebasis. Ein solcher Umbau ohne Auslöser ist genau der
Refactor, vor dem das Briefing in Abschnitt 36 warnt. **Verworfen.**

**B – Nichts festlegen.**
Vorteil: kein Aufwand. Nachteil: Die Zahl der Direktzugriffe wächst weiter,
insbesondere aus Screens. Was heute 13 Stellen sind, sind in einem Jahr
zwanzig. **Verworfen.**

**C – Clean Architecture mit `domain/` / `data/` / `presentation/`.**
Vorteil: etabliertes Muster. Nachteil: Erzwingt Entitäten-Mapping und verdoppelt
Modellklassen. Für ein Einzelprojekt dieser Größe steht der Aufwand nicht im
Verhältnis. **Verworfen.**

## Konsequenzen

Positiv:

- Das Wachstum des Problems stoppt sofort, ohne Migrationsaufwand.
- Neue Fachlogik wird ohne echte Datenbank testbar.
- Schafft die Stelle, an der später Replikation oder Konfliktauflösung
  ansetzen könnte – Voraussetzung für eine ernsthafte CRDT-Bewertung.
- Screens werden schlanker, was ADR-0005 unterstützt.

Negativ:

- Es entsteht ein uneinheitlicher Zustand: neuer Code folgt der Regel, alter
  nicht. Das ist unbefriedigend, aber der Preis dafür, funktionierenden Code
  nicht anzufassen.
- Ohne Durchsetzungsmechanismus wird die Regel vergessen. Ein Lint- oder
  Review-Schritt wäre nötig, sonst bleibt es eine Absichtserklärung.

## Migration

**Es gibt keine Migration.** Das ist der Kern dieser Entscheidung.

- Die Regel gilt ab Annahme für neuen Code.
- Bestandscode wird angepasst, **wenn er ohnehin angefasst wird** – nicht
  vorher, nicht als eigener Arbeitsblock.
- Wird eine der sieben großen Dateien nach [ADR-0005](ADR-0005-dateigroesse.md)
  zerlegt, wird die Repository-Grenze dabei mitgezogen. Beide ADRs greifen an
  derselben Stelle ineinander.

Empfohlener Durchsetzungsmechanismus: ein einfacher Prüfschritt, der
`import`-Zeilen auf `pod_database` in `features/**/*_screen.dart` meldet. Das
ist eine Zeile Grep und fängt den häufigsten Verstoß.

## Offene Fragen für die Entscheidung

- Soll der Prüfschritt als Git-Hook, als Lint-Regel oder als manueller
  Review-Punkt laufen? Angesichts der Arbeitsweise mit Claude Code wäre ein
  automatischer Hook am wirksamsten.
- Gilt die Screen-Regel auch für lesende Einzelabfragen, oder nur für
  Schreibzugriffe? Vorschlag: für beide, weil sonst die Grenze verhandelbar
  wird.
