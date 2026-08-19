# ADR-0005 – Dateigrößen-Disziplin und Zerlegungsreihenfolge

Status: `VORGESCHLAGEN`
Datum: 18. August 2026
Betrifft: Wartbarkeit, Arbeitsweise mit KI-Unterstützung
Verwandt: TD-49

## Kontext

Sieben Dateien tragen ein Drittel der Codebasis:

| Datei | Zeilen | Anteil an `lib/` |
|---|---:|---:|
| [proposal_service.dart](../../lib/features/governance/proposal_service.dart) | 4.097 | 6,0 % |
| [conversation_screen.dart](../../lib/features/chat/conversation_screen.dart) | 3.690 | 5,4 % |
| [nostr_transport.dart](../../lib/core/transport/nostr/nostr_transport.dart) | 2.976 | 4,4 % |
| [proposal_detail_screen.dart](../../lib/features/governance/proposal_detail_screen.dart) | 2.766 | 4,1 % |
| [chat_provider.dart](../../lib/features/chat/chat_provider.dart) | 2.765 | 4,1 % |
| [pod_database.dart](../../lib/core/storage/pod_database.dart) | 2.632 | 3,9 % |
| [channel_conversation_screen.dart](../../lib/features/chat/channel_conversation_screen.dart) | 2.396 | 3,5 % |
| **Summe** | **21.322** | **31,4 %** |

`proposal_service.dart` allein ist größer als `lib/shared/` und
`lib/services/` zusammen.

Dies ist als TD-49 („Große zentrale Services") bereits erfasst.
[Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md) benennt in Achse 4 die „zwei
Gott-Dateien" `proposal_service.dart` und `nostr_transport.dart` als
Einstiegshürde und Bus-Faktor-Risiko.

Neu ist hier die Ausweitung: Es sind nicht zwei, sondern **sieben Dateien** mit
zusammen 31 Prozent der Codebasis.

**Lauf B empfiehlt ausdrücklich, die Gott-Dateien nicht zu refaktorieren**
(„risikoreicher Umbau ohne Entwickler kurz vor der Testphase; die Karte aus E-5
bringt fast denselben Orientierungsnutzen zum Bruchteil des Risikos"). Diese
Einschätzung wird hier **übernommen, nicht revidiert**: Die E-5-Karte wurde
inzwischen als [EVENT_MAP.md](../current/EVENT_MAP.md) geliefert, und
`proposal_service.dart` ist unten ausdrücklich zurückgestellt.

Dieser ADR ist deshalb in erster Linie eine **Regel für neuen Code** – keine
Refactoring-Kampagne.

Warum das in diesem Projekt besonders wiegt:

- Die Entwicklung erfolgt weitgehend KI-gestützt. Eine 4.000-Zeilen-Datei passt
  nicht zuverlässig in einen Arbeitskontext. Änderungen daran erfolgen auf
  Basis von Ausschnitten – das erhöht die Wahrscheinlichkeit, Zusammenhänge zu
  übersehen.
- Die Projektregeln in `CLAUDE.md` fordern synchrones State-Locking vor
  `await` und Listener-Registrierung vor Transportstart. Solche Invarianten
  sind in großen Dateien schwerer nachzuweisen.
- Mehrere der bestätigten Fehler (TD-36 bis TD-38) liegen in genau diesen
  Dateien.

Das Briefing behandelt Dateigröße nicht. Aus meiner Sicht ist sie dennoch eine
der Größen, die in zwei Jahren über Wartbarkeit entscheiden – unabhängig davon,
wie gut die Schichtung ist.

## Entscheidung

**Vorschlag: Eine Obergrenze für neue Dateien, und eine festgelegte Reihenfolge
für die Zerlegung bestehender Dateien.**

### Regel für neuen Code

- Neue Dateien bleiben unter **800 Zeilen**.
- Wird eine bestehende Datei über 800 Zeilen erweitert, wird die Erweiterung
  in eine neue Datei ausgelagert statt angehängt.

800 Zeilen entspricht der bereits im Projektumfeld verwendeten Obergrenze.

### Reihenfolge für Bestandscode

Nicht nach Größe, sondern nach **Risiko und Anlass**:

| Rang | Datei | Begründung |
|---:|---|---|
| 1 | `pod_database.dart` | Rein strukturell (Schema, DAOs, Migrationen). Zerlegung ohne Fachlogikrisiko. Guter Startpunkt, um das Verfahren zu erproben. |
| 2 | `nostr_transport.dart` | Wird durch [ADR-0003](ADR-0003-zustellsemantik.md) ohnehin angefasst. Anlass ist gegeben. |
| 3 | `chat_provider.dart` | Zentral für „Messenger First". Hoher Nutzen, aber echtes Risiko – erst nach Erfahrung aus 1 und 2. |
| 4 | `conversation_screen.dart` / `channel_conversation_screen.dart` | Reine UI, vermutlich mit Duplikaten zwischen beiden. Zerlegung gut isolierbar. |
| — | `proposal_service.dart` | **Vorerst nicht.** Siehe unten. |
| — | `proposal_detail_screen.dart` | **Vorerst nicht.** Siehe unten. |

### Warum die größte Datei zuletzt kommt

`proposal_service.dart` ist die größte Datei und enthält G2.1.6 – den zuletzt
abgeschlossenen Funktionsblock mit 596 grünen Tests. Sie enthält außerdem drei
der fünf Release-Blocker (TD-36 bis TD-38).

Frisch fertiggestellte, getestete Fachlogik mit offenen Fehlern gleichzeitig zu
zerlegen, vermischt zwei Risiken. Die Blocker sollten zuerst behoben werden;
eine Zerlegung ist danach zu bewerten.

Diese Einstufung deckt sich mit
[DO_NOT_TOUCH.md](../current/DO_NOT_TOUCH.md), Sperrstufe 3.

## Alternativen

**A – Keine Regel, nach Bedarf zerlegen.**
Ist der Ist-Zustand. TD-49 steht seit Juli in der Liste, ohne dass sich etwas
verändert hat. Ohne feste Regel gewinnt im Zweifel immer die schnellere
Variante: anhängen. **Verworfen.**

**B – Alle sieben Dateien zerlegen.**
Vorteil: einheitliches Ergebnis. Nachteil: ein großer Refactor ohne
funktionalen Anlass, an Code, der funktioniert und Nutzer bedient. Genau das,
wovor das Briefing in Abschnitt 36 und 37 warnt. **Verworfen.**

**C – Strengere Grenze, etwa 400 Zeilen.**
Vorteil: kleinere Einheiten. Nachteil: In Flutter erzeugen Screens
naturgemäß längere Dateien. Eine zu strenge Grenze führt zu künstlicher
Zerstückelung oder wird ignoriert. **Verworfen** zugunsten von 800.

## Konsequenzen

Positiv:

- Das Wachstum stoppt sofort, ohne Migrationsaufwand.
- KI-gestützte Änderungen werden zuverlässiger, weil mehr Dateien vollständig
  in den Arbeitskontext passen.
- Rang 1 und 2 fallen ohnehin an – die Regel erzeugt kaum Zusatzaufwand.
- Greift mit [ADR-0004](ADR-0004-storage-grenze.md) ineinander: Wer eine Datei
  zerlegt, zieht die Repository-Grenze mit.

Negativ:

- Mehr Dateien bedeuten mehr Navigationsaufwand und mehr Importe.
- Die Regel ist ohne Durchsetzung wirkungslos. Ein automatischer Prüfschritt
  wäre nötig.
- Eine harte Zeilengrenze ist ein grobes Maß. Eine gut strukturierte Datei mit
  900 Zeilen kann besser sein als drei schlecht geschnittene mit je 300.

## Migration

- Die 800-Zeilen-Regel gilt ab Annahme für neuen Code.
- Bestandsdateien werden **nur bei ohnehin nötigem Anlass** zerlegt, in der
  oben festgelegten Reihenfolge.
- Vor jeder Zerlegung wird die Testbaseline erfasst, danach verglichen. Eine
  Zerlegung ist eine verhaltensneutrale Änderung – fällt ein Test, war es
  keine.
- Kein eigener Arbeitsblock „Refactoring". Zerlegung passiert im Rahmen
  anderer Arbeit.

## Offene Fragen für die Entscheidung

- Soll die 800-Zeilen-Grenze technisch durchgesetzt werden (Hook, der Writes
  über 800 Zeilen meldet), oder als Konvention gelten?
- Gilt die Grenze auch für Testdateien? Vorschlag: nein – Testdateien dürfen
  länger sein, weil sie linear lesbar sind.
