# Was nicht angefasst werden sollte

Stand: 18. August 2026
Basis: [ARCHITECTURE_REALITY.md](ARCHITECTURE_REALITY.md)

Ein Audit, das nur Probleme findet, erzeugt Refactoring-Druck auf Code, der
funktioniert. Dieses Dokument benennt bewusst das Gegenteil: Bereiche, die gut
genug sind und derzeit **nicht** umgebaut werden sollten – auch dann nicht,
wenn eine Zielarchitektur es theoretisch nahelegt.

Die Einstufungen gelten bis zum Widerruf durch einen ADR. Wer einen dieser
Bereiche ändern will, sollte vorher begründen, warum der Nutzen das Risiko
überwiegt.

## Sperrstufe 1 – Kryptografie und Identitätsableitung

**Nicht anfassen ohne zwingenden, benannten Grund.**

| Bereich | Datei | Begründung |
|---|---|---|
| BIP-39-Seed und Wortliste | [bip39.dart](../../lib/core/identity/bip39.dart), `bip39_wordlist.dart` | Standardkonform, getestet. Eine Änderung macht bestehende Seeds unbrauchbar – Totalverlust der Identität aller Nutzer. |
| SLIP-0010 / Ed25519-Ableitung | [identity_service.dart:165](../../lib/core/identity/identity_service.dart) | Erzeugt DID und Pod-Schlüssel deterministisch aus dem Seed. Jede Änderung ändert die Identität aller Bestandsnutzer. |
| `did:key`-Erzeugung | [did.dart](../../lib/core/identity/did.dart) | 60 Zeilen, W3C-konform, getestet. Es gibt keinen Grund, das anzufassen. |
| BIP-340-Schnorr-Signatur | [nostr_keys.dart:80](../../lib/core/transport/nostr/nostr_keys.dart) | Eigenimplementierung, aber getestet und protokollkonform. Handgeschriebene Kryptografie zu ändern ist überproportional riskant. |
| AES-256-GCM-Verschlüsselung | [lib/core/crypto/](../../lib/core/crypto/) | Schützt die gesamte lokale Datenhaltung. Getestet. |

Der Projektgrundsatz „keine eigene Kryptografie" ist hier bereits erfüllt: Es
werden etablierte Verfahren verwendet. Dass die Schnorr-Signatur handgeschrieben
ist, ist eine bewusste Altlast mit Testabdeckung – kein Anlass für einen
Neuschrieb während einer Architekturmigration.

**Ausnahme:** Die Krypto-Agilität aus dem Briefing (Abschnitt 11) bedeutet
*Austauschbarkeit vorbereiten*, nicht *Verfahren ersetzen*. Eine Abstraktion
**um** diese Bausteine herum ist zulässig. Ihr Inhalt bleibt unverändert.

## Sperrstufe 2 – Datenbankstruktur und Migration

**Nur additiv ändern.**

Der Migrationsmechanismus in
[pod_database.dart](../../lib/core/storage/pod_database.dart) (Schema 23)
folgt bereits der zwingenden Projektregel: `CREATE TABLE IF NOT EXISTS` und
`ALTER TABLE`, kein `DROP`.

Diese Regel steht in `CLAUDE.md` als nicht verhandelbares Verbot, weil ein
Verstoß Nutzerdaten vernichtet. Sie gilt unverändert auch während jeder
Architekturmigration.

Konkret bedeutet das für die geplanten Änderungen: Eine Repository-Grenze
(ADR-0004) darf **oberhalb** der Datenbank entstehen. Das Schema selbst wird
davon nicht berührt.

## Sperrstufe 3 – Frisch abgeschlossene Funktionsblöcke

| Bereich | Grund |
|---|---|
| Governance G2.1.6 / Liquid Democracy | Zuletzt abgeschlossener Block. 596 von 596 Governance-Tests grün. Delegation, Widerruf, Auto-Revoke und Auszählung sind aufeinander abgestimmt. |
| Zellgründungsfreigaben | Manuell auf Gerät getestet, Integrationstest vorhanden. |

Diese Bereiche liegen in `proposal_service.dart` – also ausgerechnet in der
größten Datei. Der Reflex, sie deshalb zuerst zu zerlegen, ist verständlich und
falsch. Frisch fertiggestellte, getestete Fachlogik ist der schlechteste
Startpunkt für einen Refactor. Siehe
[ADR-0005](../decisions/ADR-0005-dateigroesse.md) für die vorgeschlagene
Reihenfolge.

## Bewährte Abstraktionen – erhalten, nicht ersetzen

Diese Bausteine lösen bereits das, was die Zielarchitektur anstrebt. Sie sollten
als Vorlage dienen statt neu entworfen zu werden.

### `MessageTransport` / `TransportManager`

[message_transport.dart](../../lib/core/transport/message_transport.dart) ist
43 Zeilen, dokumentiert, identitätsneutral (`recipientDid`) und formuliert die
Schichtregel selbst. `TransportType` sieht `wifiDirect` und `lora` bereits vor.

Das Briefing bezeichnet diese Abstraktion zu Recht als wertvolle Ausgangsbasis.
Sie sollte das **Muster** für weitere Adapter liefern – nicht selbst
umgeschrieben werden.

### `TrustLevel`

```dart
enum TrustLevel { discovered, contact, trusted, guardian }
```

Entspricht exakt dem relationalen Vertrauensmodell des Briefings. Kein globaler
Score, nicht übertragbar, nicht aggregiert. **Hier ist nichts zu reparieren.**

Die Diskussion um AURA und Social Scoring betrifft Dokumente und Konzepte,
nicht diesen Code.

### `PublishResultStatus`

Der Zustandsautomat `PENDING → PARTIAL → ACCEPTED / REJECTED / RETRYING →
FAILED` ist inhaltlich richtig. Er ist lediglich am falschen Ort.

**Wichtig:** ADR-0003 schlägt vor, ihn zu *verschieben und zu erweitern* – nicht
neu zu entwerfen. Die Zustandsnamen und Übergänge bleiben.

## Die Testsuite

67 Testdateien, 28.028 Zeilen, 41 Prozent des Produktivcodes.

Die Testsuite ist der wichtigste Schutz für jede Migration. Regeln:

- Tests werden **nicht** angepasst, damit geänderter Code grün wird. Wenn ein
  Test nach einer Änderung fällt, ist zunächst die Änderung verdächtig.
- Die 11 bekannten Fehler in der Navigations-/Dashboard-Auswahl (TD-25) sind
  veraltete Label-Erwartungen plus ein realer Desktop-Overflow. Sie sind
  bekannt und dokumentiert – kein Anlass, die Suite umzubauen.
- Vor jeder Migration wird die Baseline erfasst, nach der Migration verglichen.

## Die Dokumentationsstruktur

Die Prüfung hat ergeben, dass `docs/current/` inhaltlich korrekt ist: Version,
Schemastand, Analyze-Baseline und die bekannten Risiken stimmen exakt mit dem
Code überein.

Das Briefing schlägt in Abschnitt 38 eine neue achtstufige Ordnerstruktur vor
(`00_PROJECT_STATE/` bis `08_ARCHIVE/`, darunter `02_PROTOCOLS/` mit sieben
Unterordnern). **Empfehlung: nicht umsetzen.**

Begründung:

- Die bestehende Struktur wurde erst am 15. Juli 2026 reorganisiert
  (Commit `19f74c5`) und hat einen funktionierenden Einstieg über
  [INDEX.md](../INDEX.md).
- `02_PROTOCOLS/` würde sieben Ordner für Protokolle anlegen, die es nicht gibt.
  Leere Ordner erzeugen den Eindruck von Substanz, wo keine ist.
- Ein zweiter Umbau innerhalb von fünf Wochen kostet Zeit und bringt keinen
  Erkenntnisgewinn.

Stattdessen wurde genau ein Ordner ergänzt: [../decisions/](../decisions/) für
Architecture Decision Records. Protokollordner entstehen, wenn das erste
Protokoll geschrieben wird – nicht vorher.

## Ausdrücklich zurückgestellt

Diese Ideen aus dem Briefing sind sinnvoll, aber **nicht jetzt**. Sie sind
später nachrüstbar, weil sie keine Datenmodell-Entscheidungen erzwingen.

| Thema | Briefing | Warum zurückgestellt |
|---|---|---|
| CRDT / Yjs | Abschnitt 21 | Löst ein Problem, das erst mit echtem Multi-Device auftritt. Vorher nicht bewertbar. Setzt ADR-0002 voraus. |
| `NexusSpace`-Abstraktion | Abschnitt 24 | Große Abstraktion über Chat, Kanal, Zelle, Agora. Nur sinnvoll, wenn sie Code *vereinfacht* – das ist heute nicht belegbar. |
| Capability-Autorisierung | Abschnitt 26 | Das Rollenmodell funktioniert für die Genesis-Phase. Ein Umbau ohne konkreten Bedarf ist reines Risiko. |
| Schlüsselrotation bei Mitgliederwechsel | Abschnitt 25 | Reales Sicherheitsproblem, aber nachrüstbar. Nach ADR-0002. |
| Vault-/Backup-Adapter | Abschnitt 27 | Backup funktioniert. Adapterfähigkeit ohne zweite Implementierung ist spekulativ. |
| N.E.X.U.S. Linux | Abschnitt 29 | Das Briefing sagt es selbst: „Wir bauen Linux noch nicht jetzt." |

Das Briefing warnt vor der „Infrastruktur-Endlosschleife" (Abschnitt 30). Diese
Tabelle ist der konkrete Schutz davor.

## Übernommen aus Audit Lauf B

[Lauf B](../audits/2026-07/AUDIT_LAUF_B.md) führt unter „Was ich nicht empfehle,
obwohl es naheliegt" vier Punkte auf. Alle vier gelten unverändert weiter:

| Nicht tun | Begründung von Lauf B |
|---|---|
| Eigene Blockchain / Substrate bauen | Löst kein Problem, das Hash-Kette plus Signaturprüfung nicht billiger löst |
| Reticulum-/P2P-Sprachbrücke jetzt integrieren | Dauerpflege einer FFI-Grenze übersteigt, was ein Alleingründer ohne Entwickler tragen kann |
| Die Gott-Dateien jetzt refaktorieren | Risikoreicher Umbau ohne Entwickler; die Event-Karte bringt fast denselben Nutzen |
| Testabdeckung/CI zum Release-Kriterium machen | 600+ Tests existieren; offene Punkte sind Design-, keine Regressionslücken |

Besonders zu beachten: Der dritte Punkt betrifft direkt
[ADR-0005](../decisions/ADR-0005-dateigroesse.md). Dieser ADR schlägt deshalb
**keine Refactoring-Kampagne** vor, sondern eine Regel für neuen Code und eine
Reihenfolge für den Fall, dass eine Datei ohnehin angefasst wird.

Die von Lauf B als Alternative empfohlene Architekturkarte (E-5) wurde
inzwischen geliefert: [EVENT_MAP.md](EVENT_MAP.md).

## Geltungsdauer

Dieses Dokument ist eine Momentaufnahme. Es wird ungültig, sobald ein ADR eine
der Einstufungen ausdrücklich aufhebt. Änderungen an Sperrstufe 1 sollten in
keinem Fall ohne eigenen ADR erfolgen.
