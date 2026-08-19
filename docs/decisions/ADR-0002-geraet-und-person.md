# ADR-0002 – Trennung von Person und Gerät

Status: `VORGESCHLAGEN`
Datum: 18. August 2026
Betrifft: Datenmodell, Identität, Wiederherstellung, Sicherheit
Setzt voraus: [ADR-0001](ADR-0001-identitaets-identifier.md)

## Kontext

Im Code existiert kein Gerätekonzept auf Identitätsebene:

| Symbol | Vorkommen in `lib/` |
|---|---:|
| `deviceKey` / `DeviceKey` | 0 |
| `Device` als Typ | 2 |
| `device` (BLE-/LAN-Peers) | 137 |

Identität ist heute implizit gleich Gerät. Der Seed liegt im Secure Storage,
daraus entstehen die Schlüssel, und ein zweites Gerät mit demselben Seed ist
aus Sicht des Netzwerks **dieselbe, ununterscheidbare Entität**.

Praktische Folgen im Ist-Zustand:

- Ein verlorenes oder gestohlenes Gerät kann nicht einzeln widerrufen werden.
  Der einzige Weg ist ein vollständiger Identitätswechsel – also der Verlust
  aller Kontakte, Mitgliedschaften und der Governance-Historie.
- Zwei Geräte derselben Person können nicht auseinandergehalten werden. Das
  ist bereits heute als Problem sichtbar: TD-33 beschreibt divergierende
  Zellmitglieder-Ansichten zwischen Android und Windows, TD-46 beschreibt
  geräteübergreifende Idempotenzprobleme.
- Die Frage „hat diese Person abgestimmt oder ihr zweites Gerät?" ist im
  Datenmodell nicht beantwortbar.

Nicht zu verwechseln: `delegation` (205 Vorkommen) ist die
Governance-Stimmdelegation aus G2.1.6 – ein Fachkonzept, kein Gerätekonzept.

Das Briefing formuliert das Ziel in Abschnitt 22: Root Identity autorisiert
Device Keys, ein Gerät kann widerrufen werden, ohne die Person zu ersetzen.

## Entscheidung

**Vorschlag: Eine Person besitzt eine Root-Identität. Geräte erhalten eigene,
von der Root-Identität autorisierte Schlüssel.**

```
Root Identity (did:key, aus BIP-39-Seed)
      │  autorisiert
      ├── Gerät A  (eigener Schlüssel, eigene Widerrufbarkeit)
      ├── Gerät B
      └── Gerät C
```

Verbindliche Festlegungen:

1. Die **Root-Identität** ist die DID aus ADR-0001. Sie identifiziert die
   Person und bleibt langlebig.
2. Ein **Gerät** hat einen eigenen Schlüssel, der von der Root-Identität
   autorisiert wird. Die Autorisierung ist ein signierter, verbreitbarer
   Datensatz.
3. Ein Gerät kann **einzeln widerrufen** werden, ohne die Root-Identität zu
   wechseln.
4. Der **Seed bleibt der Wiederherstellungsweg** für die Root-Identität. Am
   BIP-39-Verfahren ändert sich nichts (siehe
   [DO_NOT_TOUCH.md](../current/DO_NOT_TOUCH.md), Sperrstufe 1).

## Alternativen

**A – Beim jetzigen Modell bleiben (Identität = Gerät).**
Vorteil: kein Aufwand. Nachteil: Geräteverlust bedeutet dauerhaft
Identitätsverlust. Für ein System, das Governance und perspektivisch
Werteinheiten trägt, ist das auf Dauer nicht tragbar. Zudem bleiben TD-33 und
TD-46 strukturell unlösbar. **Verworfen.**

**B – Seed auf mehrere Geräte kopieren (heutige Praxis).**
Das ist der Ist-Zustand und funktioniert kurzfristig. Nachteile: kein Widerruf
einzelner Geräte, keine Unterscheidbarkeit, und der Seed wird häufiger bewegt
als nötig – jede Kopie ist ein Angriffspunkt. **Als Dauerlösung verworfen**,
bleibt aber Übergangsmechanismus.

**C – Vollständiges Hierarchisches Schlüsselsystem sofort.**
Vorteil: fachlich sauber. Nachteil: erheblicher Aufwand, betrifft Krypto
(Sperrstufe 1) und alle Empfangspfade. Zu groß für den nächsten Schritt.
**Zurückgestellt** – dieser ADR legt nur das Modell fest, nicht die
Vollimplementierung.

## Konsequenzen

Positiv:

- Geräteverlust wird beherrschbar statt katastrophal.
- TD-33 und TD-46 werden strukturell lösbar statt nur symptomatisch.
- Voraussetzung für eine sinnvolle Bewertung von CRDT (Briefing Abschnitt 21) –
  ohne Multi-Device gibt es das Problem nicht, das CRDT löst.
- Voraussetzung für Community Nodes und die spätere Linux-Variante, in der ein
  Rechner gleichzeitig Client und Infrastruktur ist.

Negativ:

- Betrifft den Empfangspfad: Wer prüft, ob ein Gerät noch autorisiert ist?
  Diese Prüfung hängt direkt an TD-39 (Signaturprüfung), die heute fehlt.
- Widerruf muss verbreitet werden. In einem System ohne zentrale Instanz ist
  Widerruf ein hartes Problem – ein offline gebliebenes Gerät erfährt nichts
  davon.
- Erhöht die Komplexität des Onboardings, das laut Produktstrategie
  „Messenger First" gerade einfach bleiben soll.

**Wichtiger Hinweis zum Zeitpunkt (revidiert 18.08.2026):** Dies ist eine
Datenmodell-Entscheidung. Jede Funktion, die zwischen heute und der Umsetzung
entsteht, geht implizit von „Identität = Gerät" aus und muss später angefasst
werden — das spricht weiter dafür, die Frage nicht ewig offen zu lassen.

**Der akute Zeitdruck ist jedoch entfallen.** Die Verifikation gegen Web of
Trust hat gezeigt, dass Multi-Device-**Konsistenz** ohne Device-Keys lösbar
ist: Per-Device-Inbox, Store-and-Forward und Generationen-Key-Rotation laufen
dort auf demselben Shared-Seed-Modell, das N.E.X.U.S. heute nutzt.

Damit sind TD-33 (divergierende Zellmitglieder) und TD-46 (Idempotenz)
**Sync-Probleme, keine Identitätsprobleme** — sie werden im Block NEXT-A
gelöst, nicht hier. Siehe [NOW_NEXT_LATER.md](../planning/NOW_NEXT_LATER.md).

Folge für die Priorisierung: ADR-0002 bleibt strategisch richtig, sollte aber
**nach** ADR-0001 und **nach** der Sync-Härtung entschieden und umgesetzt
werden. Der laufende Multi-Device-Betrieb hängt nicht davon ab.

## Migration

**Ausdrücklich nicht Teil dieses ADR:** keine sofortige Implementierung von
Device Enrollment, Revocation oder Multi-Device-Sync.

Was dieser ADR festlegt, ist das **Modell** – damit neuer Code nicht weiter
gegen die Annahme „Identität = Gerät" gebaut wird.

Vorgeschlagene Reihenfolge, wenn entschieden:

1. **Begriffliche Trennung im Code.** Dort, wo heute implizit „Gerät" gemeint
   ist, aber „Person" steht (und umgekehrt), benennen. Kostet wenig, schafft
   Klarheit.
2. **Gerätekennung einführen**, zunächst nur lokal und ohne Netzwerkwirkung.
   Erlaubt, TD-46 (Idempotenz) sauber zu lösen.
3. **Signaturprüfung schließen** (TD-39). Ohne sie ist keine
   Autorisierungsprüfung möglich – Geräteautorisierung ohne Signaturprüfung
   ist wirkungslos.
4. Erst danach: Autorisierungsdatensatz, Widerruf, Verbreitung.

Schritt 3 ist ohnehin ein Release-Blocker. Dieser ADR macht sichtbar, dass er
zusätzlich eine architektonische Voraussetzung ist.

## Offene Fragen für die Entscheidung

- Soll ein Gerät einen eigenen Ed25519-Schlüssel bekommen, oder reicht eine
  vom Seed abgeleitete Kennung mit Index (SLIP-0010-Pfad)? Letzteres wäre
  deutlich billiger, erlaubt aber keinen echten Widerruf ohne Seed.
- Wie erfährt ein lange offline gewesenes Gerät von seinem eigenen Widerruf?
- Bleibt „Seed auf zweites Gerät" als einfacher Weg erhalten, oder soll
  Enrollment der einzige Weg werden? Für „Messenger First" spricht viel dafür,
  den einfachen Weg zu behalten.
