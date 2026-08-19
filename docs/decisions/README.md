# Architecture Decision Records

Hier stehen Grundsatzentscheidungen zur Architektur der N.E.X.U.S. OneApp –
jeweils mit Kontext, Entscheidung und Konsequenzen.

**Zweck:** Verhindern, dass dieselbe Architekturfrage nach sechs Monaten
erneut ungeklärt auftaucht.

## Status-Werte

| Status | Bedeutung |
|---|---|
| `VORGESCHLAGEN` | Zur Entscheidung vorgelegt, noch nicht entschieden. Kein Code darf sich darauf berufen. |
| `ANGENOMMEN` | Entschieden und gültig. Neuer Code richtet sich danach. |
| `ABGELEHNT` | Geprüft und verworfen. Bleibt erhalten, damit die Frage nicht erneut gestellt wird. |
| `ÜBERHOLT` | Durch einen späteren ADR ersetzt. Verweis auf den Nachfolger steht im Dokument. |

Ein ADR wird nach der Annahme nicht mehr inhaltlich geändert. Neue Erkenntnisse
führen zu einem neuen ADR, der den alten als `ÜBERHOLT` markiert.

## Aktueller Bestand

| ADR | Thema | Status |
|---|---|---|
| [0001](ADR-0001-identitaets-identifier.md) | Kanonischer Identitäts-Identifier im Domänenmodell | `VORGESCHLAGEN` |
| [0002](ADR-0002-geraet-und-person.md) | Trennung von Person und Gerät | `VORGESCHLAGEN` |
| [0003](ADR-0003-zustellsemantik.md) | Transportneutrale Zustellsemantik | `VORGESCHLAGEN` |
| [0004](ADR-0004-storage-grenze.md) | Grenze zwischen Fachlogik und Persistenz | `VORGESCHLAGEN` |
| [0005](ADR-0005-dateigroesse.md) | Dateigrößen-Disziplin und Zerlegungsreihenfolge | `VORGESCHLAGEN` |

Alle fünf stammen aus dem [Architektur-Ist-Zustand](../current/ARCHITECTURE_REALITY.md)
vom 18. August 2026 und sind nach abnehmender Dringlichkeit sortiert.

Sie beantworten die zweite zentrale Frage aus §50 des
[Architektur-Briefings](../planning/ARCHITEKTUR_BRIEFING_2026.md): welche drei
bis fünf Architekturentscheidungen darüber entscheiden, ob in zwei Jahren eine
modulare Plattform oder ein schwer wartbarer Monolith steht.

Der Umsetzungsstand des gesamten Briefings steht in
[BRIEFING_ABDECKUNG.md](../planning/BRIEFING_ABDECKUNG.md).

## Reihenfolge der Entscheidung

ADR-0001 und ADR-0002 hängen zusammen und sollten gemeinsam entschieden werden:
Beide betreffen das Datenmodell und werden mit jeder weiteren Funktion teurer.

ADR-0003 ist unabhängig und kann sofort umgesetzt werden.

ADR-0004 und ADR-0005 sind Disziplinregeln ohne Migrationszwang – sie gelten ab
Annahme für neuen Code und werden bei Gelegenheit auf Bestandscode angewendet.

## Vorlage

```markdown
# ADR-XXXX – Titel

Status: VORGESCHLAGEN
Datum: TT. Monat JJJJ

## Kontext
Was ist die Ausgangslage? Belege aus dem Code.

## Entscheidung
Was wird festgelegt?

## Alternativen
Was wurde erwogen und warum verworfen?

## Konsequenzen
Was folgt daraus – positiv und negativ?

## Migration
Was ist zu tun? Was ausdrücklich nicht?
```
