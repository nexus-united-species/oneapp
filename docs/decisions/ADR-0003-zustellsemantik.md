# ADR-0003 – Transportneutrale Zustellsemantik

Status: `VORGESCHLAGEN`
Datum: 18. August 2026
Betrifft: Transportschicht, Messenger-Zuverlässigkeit
Abhängigkeiten: keine – sofort umsetzbar

## Kontext

Für Nostr existiert bereits ein vollständiger Zustell-Lebenszyklus
([publish_result_status.dart](../../lib/core/transport/nostr/publish_result_status.dart)):

```
PENDING → PARTIAL → ACCEPTED
        ↘ RETRYING → FAILED
        ↘ REJECTED
```

Dazu gehören `publish_result.dart` (189 Zeilen), ein DAO (119 Zeilen),
Retry-Backoff mit Test (`retry_backoff_test.dart`) und
`publish_result_dao_test.dart`. Die Semantik ist durchdacht: `PARTIAL` bildet
ab, dass einige Relays angenommen haben, aber weniger als `required_ack_count`.

Zwei Probleme:

1. **Der Code liegt unter `core/transport/nostr/`.** BLE und LAN haben keine
   vergleichbare Zustellsemantik. Eine Nachricht über BLE hat heute keinen
   definierten Zustand zwischen „abgeschickt" und „irgendwann vielleicht da".
2. **Der Begriff „Outbox" kommt im Code null mal vor.** Die
   Warteschlangen-Semantik ist implizit über `PENDING`/`RETRYING` abgebildet.
   Es gibt keine transportübergreifende Sicht auf „was ist noch unterwegs".

Das Briefing fordert in Abschnitt 23 genau das, was hier zu 80 Prozent bereits
existiert – nur eine Ebene zu tief.

Zusätzlich relevant: TD-28 vermerkt, dass `publish_results.vote_id` polymorph
ist und je nach `event_kind` auch DecisionRecord- und Delegations-IDs trägt.
Das Feld ist faktisch ein `payload_id`. Eine Verschiebung ist die natürliche
Gelegenheit, das zu bereinigen.

## Entscheidung

**Vorschlag: Die Zustellsemantik wird auf die Transportebene gehoben. Die
bestehenden Zustände und Übergänge bleiben unverändert.**

Konkret:

1. Zustandsautomat und Datenmodell wandern von `core/transport/nostr/` nach
   `core/transport/`.
2. Die Zustandsnamen `PENDING`, `PARTIAL`, `ACCEPTED`, `REJECTED`, `RETRYING`,
   `FAILED` bleiben **exakt erhalten**. Kein Neuentwurf.
3. `MessageTransport` erhält die Möglichkeit, Zustellzustände zu melden.
   Transporte, die eine Stufe nicht unterstützen, melden sie nicht – die
   Semantik ist ein Angebot, keine Pflicht.
4. `PARTIAL` bleibt Nostr-spezifisch interpretierbar (Anzahl akzeptierender
   Relays), ist aber generisch als „teilweise zugestellt" definiert.

Ausdrücklich **nicht** Teil dieser Entscheidung: die vollständige
Zustandskette aus dem Briefing (`DELIVERED_TO_DEVICE`, `ACKNOWLEDGED`, `READ`).
Diese Stufen setzen Rückkanäle voraus, die es heute nicht gibt. Sie werden
später ergänzt, wenn sie belegbar gebraucht werden.

## Alternativen

**A – Neuentwurf der Zustandsmaschine nach Briefing Abschnitt 23.**
Sechs neue Zustände (`QUEUED`, `SENT`, `ACCEPTED_BY_TRANSPORT`,
`DELIVERED_TO_DEVICE`, `ACKNOWLEDGED`, `READ`). Vorteil: vollständiger.
Nachteil: verwirft eine getestete, funktionierende Implementierung und führt
Zustände ein, für die es keine Datenquelle gibt. `DELIVERED_TO_DEVICE` ist über
Nostr-Relays nicht feststellbar. **Verworfen** – das ist Modellierung auf
Vorrat.

**B – So lassen, BLE/LAN bekommen später eigene Lösungen.**
Vorteil: null Aufwand. Nachteil: Jeder Transport erfindet die Semantik neu, und
die Chat-Schicht muss pro Transport unterschiedlich damit umgehen. Genau die
Kopplung, die vermieden werden soll. **Verworfen.**

**C – Vollständige Outbox als eigenes Konzept.**
Eine persistente, transportübergreifende Warteschlange mit eigener Verwaltung.
Vorteil: sauberstes Modell. Nachteil: deutlich größerer Eingriff, berührt
`chat_provider.dart` (2.765 Zeilen). **Zurückgestellt** – erst nach der
Verschiebung bewertbar.

## Konsequenzen

Positiv:

- **Direkter Nutzerwert.** Zuverlässige Zustellung ist die sichtbarste
  Qualität eines Messengers. Das zahlt unmittelbar auf „Messenger First" ein.
- BLE und LAN können dieselbe Chat-Logik nutzen. Für den Offline-Betrieb
  (Briefing Abschnitt 10, „Offline Islands") ist das die Voraussetzung.
- Kleinster Eingriff mit größtem architektonischen Hebel: Es entsteht ein
  zweites Beispiel dafür, dass Adaptergrenzen in diesem Projekt funktionieren –
  neben `MessageTransport`.
- Gelegenheit, TD-28 (`vote_id` → `payload_id`) mitzunehmen.

Negativ:

- Berührt eine Datenbanktabelle (`publish_results`). Die Migration muss
  additiv erfolgen – `ALTER TABLE`, kein `DROP` (siehe
  [DO_NOT_TOUCH.md](../current/DO_NOT_TOUCH.md), Sperrstufe 2).
- Governance verlässt sich auf `PublishResult` für den Decision-Record-Retry.
  Dieser Pfad ist bereits durch TD-38 als fehlerhaft markiert. Beide Themen im
  selben Zug anzufassen erhöht das Risiko – sie sollten getrennt bleiben.

## Migration

Dies ist der **vorgeschlagene erste Umsetzungsschritt** nach der
Entscheidungsrunde, weil er klein, testbar und rückbaubar ist.

1. Baseline erfassen: Testlauf vor der Änderung dokumentieren.
2. Zustandsautomat und Modell nach `core/transport/` verschieben. Reine
   Verschiebung, keine inhaltliche Änderung – die vorhandenen Tests müssen
   unverändert grün bleiben.
3. `MessageTransport` um eine optionale Zustellmeldung erweitern.
4. Nostr-Adapter meldet wie bisher. BLE und LAN melden zunächst nichts –
   Verhalten unverändert.
5. Testlauf gegen Baseline vergleichen.
6. Erst danach entscheiden, ob BLE/LAN eigene Zustände melden sollen.

Schritt 2 ist der eigentliche Kern und sollte allein testbar sein. Wenn er
nicht ohne Testanpassung gelingt, ist die Abstraktion schlechter als
angenommen – dann ist Abbruch die richtige Reaktion, nicht Nachbessern.

## Offene Fragen für die Entscheidung

- Soll TD-28 (`vote_id` → `payload_id`) im selben Schritt erledigt werden oder
  getrennt? Zusammen spart eine Migration, erhöht aber das Risiko.
- Sollen BLE und LAN überhaupt Zustellzustände melden, oder reicht es
  vorerst, dass sie es *könnten*?
