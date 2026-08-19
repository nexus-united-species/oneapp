# ADR-0001 – Kanonischer Identitäts-Identifier im Domänenmodell

Status: `VORGESCHLAGEN`
Datum: 18. August 2026
Betrifft: Datenmodell, Identität, Transportentkopplung

## Kontext

Aus einem BIP-39-Seed werden derzeit zwei kryptografisch unabhängige
Schlüsselbäume abgeleitet:

| | NEXUS-Identität | Nostr-Identität |
|---|---|---|
| Kurve | Ed25519 | secp256k1 |
| Ableitung | SLIP-0010, [identity_service.dart:165](../../lib/core/identity/identity_service.dart) | [nostr_keys.dart:38](../../lib/core/transport/nostr/nostr_keys.dart) |
| Repräsentation | `did:key:z6Mk…` | `nostrPubkey` (hex), `npub` |
| Vorkommen | ~845 | ~103 |

Beide stammen aus demselben Seed, sind aber **nicht ineinander umrechenbar** –
verschiedene Kurven, verschiedene Schlüssel.

Das Kontaktmodell speichert beide getrennt
([contact.dart:76-87](../../lib/core/contacts/contact.dart)):

```dart
final String did;                    // Ed25519-basiert
String? encryptionPublicKey;         // X25519, aus Ed25519 abgeleitet
String? nostrPubkey;                 // secp256k1, unabhängig
```

Es ist nirgends normativ festgehalten, welcher der beiden Identifier eine
Person im Domänenmodell **ist**. In der Praxis entscheidet das jede Stelle
selbst. Beispiele:

- `MessageTransport.sendMessage` nimmt `recipientDid` – DID-orientiert.
- Governance-Events tragen `voterPubkey` – Nostr-orientiert.
- Kontakte werden über `did` geschlüsselt, aber ohne `nostrPubkey` ist kein
  Nachrichtenversand über Nostr möglich.

Das Briefing formuliert das Prinzip: „Dezentrale Kommunikation ist das Prinzip,
Nostr ist eine Implementierung davon." Solange `nostrPubkey` fachliche
Datensätze schlüsselt, ist dieses Prinzip nicht eingehalten – Nostr ist dann
Teil des Domänenmodells.

### Der Konflikt ist bereits produktiv wirksam

In der Governance-Auszählung laufen beide Identifier nebeneinander:

| Was | Identifier |
|---|---|
| `Vote` speichert | **beide** – `voterPubkey` und `voterDid` |
| Stimmberechtigten-Menge (`_loadEligibleVoterSet`) | **DID** |
| Delegations-Berechtigung | **DID** |
| Eindeutigkeit einer Stimme (`UNIQUE`) | **nostrPubkey** |
| Berechtigung einer Direktstimme | **wird nicht geprüft** |

Berechtigung wird also über DIDs geprüft, Eindeutigkeit über Pubkeys
durchgesetzt – zwei Mengen, die nicht ineinander überführbar sind.

**Das ist die strukturelle Ursache von V-005** aus
[Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md): „keine Prüfung, ob der
Wähler zum eingefrorenen Stimmberechtigten-Kreis gehört". Der Vergleich
unterblieb, weil er ohne Zuordnungsschritt nicht möglich ist.

**Konsequenz für die Reihenfolge:** V-005 lässt sich nicht sauber beheben, ohne
diesen ADR zu entscheiden. Wer den Wählerfilter ergänzt, legt zwangsläufig fest,
welcher Identifier maßgeblich ist. Ohne Entscheidung fällt sie beiläufig im
Fix-Prompt – und zwar vermutlich zugunsten von `nostrPubkey`, weil das der
Identifier ist, den die Stimme ohnehin trägt.

## Entscheidung

**Vorschlag: `did:key` ist der kanonische Identifier einer Person im
Domänenmodell. `nostrPubkey` ist eine Transportadresse.**

Daraus folgen drei Regeln:

1. **Fachliche Datensätze schlüsseln auf DID.** Anträge, Stimmen,
   Mitgliedschaften, Kontakte, Beiträge und Nachrichten identifizieren
   Personen über die DID.
2. **`nostrPubkey` lebt in der Transportschicht** und in der
   Kontakt-Adressverwaltung – analog zu einer BLE-Geräteadresse. Er ist eine
   Zustelladresse, keine Identität.
3. **Die Zuordnung DID ↔ nostrPubkey ist eine überprüfbare Behauptung**, kein
   Naturgesetz. Sie wird beim Kontaktaufbau übertragen und sollte perspektivisch
   signiert sein.

## Alternativen

**A – `nostrPubkey` als kanonischer Identifier.**
Vorteil: entspricht dem Ist-Zustand in Governance, kein Umbau dort. Nachteil:
zementiert Nostr im Datenmodell dauerhaft. Ein Transportwechsel wäre dann
faktisch ein Identitätswechsel für alle Nutzer. Widerspricht dem Kerngrundsatz
„No Single Dependency" (Briefing Abschnitt 28). **Verworfen.**

**B – Beides gleichberechtigt lassen.**
Vorteil: kein Aufwand. Nachteil: Das ist der Ist-Zustand. Jede neue Funktion
trifft die Entscheidung erneut und möglicherweise anders. Die Kosten steigen
monoton. **Verworfen.**

**C – Ein dritter, neuer Identifier.**
Vorteil: sauberer Schnitt. Nachteil: Migration aller Bestandsdaten, ohne
erkennbaren Vorteil gegenüber der bereits vorhandenen DID. **Verworfen.**

## Konsequenzen

Positiv:

- Nostr wird zu einem austauschbaren Adapter, wie das Briefing es anstrebt.
- Multi-Device (ADR-0002) wird überhaupt erst formulierbar: Eine Person hat
  eine DID und mehrere Transportadressen.
- Die DID ist bereits W3C-konform und in der App etabliert (845 Vorkommen).
- `MessageTransport` ist bereits DID-orientiert – die Kernabstraktion passt.

Negativ:

- Governance-Datensätze verwenden derzeit `voterPubkey`. Diese Felder wären
  langfristig zu migrieren. Das betrifft Daten, die bereits auf Relays liegen.
- Jede Nachricht braucht eine DID→nostrPubkey-Auflösung vor dem Versand. Fehlt
  der Mapping-Eintrag, ist der Kontakt nicht erreichbar. Das muss ein
  definierter Fehlerfall werden, kein stiller Fehlschlag.
- Kurzfristig entsteht kein sichtbarer Nutzerwert. Der Wert ist reine
  Optionserhaltung.

Risiko bei Nichtentscheidung: Mit jedem Funktionsblock wächst die Zahl der
Stellen, die `nostrPubkey` fachlich verwenden. Der Aufwand steigt, und
irgendwann ist die Entscheidung faktisch zugunsten von Alternative A gefallen –
ohne dass sie je getroffen wurde.

## Migration

**Ausdrücklich nicht Teil dieses ADR:** keine Massenmigration bestehender
Governance-Daten, kein Umschreiben von `proposal_service.dart`.

Vorgeschlagenes Vorgehen:

1. **Ab sofort geltend für neuen Code.** Neue fachliche Datensätze schlüsseln
   auf DID. Das kostet nichts und stoppt das Wachstum des Problems.
2. **Mapping explizit machen.** Eine klare Stelle, die DID → Transportadresse
   auflöst, statt impliziter Annahmen über das Kontaktobjekt.
3. **Bestandsdaten bleiben zunächst unverändert.** `voterPubkey` in
   Governance-Events wird nicht angefasst, solange G2 stabil laufen muss.
4. Eine spätere Migration wird erst geplant, wenn Schritt 1 bis 3 stehen und
   der Nutzen konkret ist.

Der wesentliche Wert dieses ADR liegt in Schritt 1: die Blutung stoppen, bevor
migriert wird.

**Ausnahme mit Vorrang:** Wird V-005 (Wählerfilter bei Direktstimmen) behoben,
muss dieser ADR vorher entschieden sein – dort fällt die Entscheidung sonst
implizit. Dasselbe gilt für TD-40 / V-003 (Absenderautorisierung): Die Frage
„ist dieser Absender berechtigt?" setzt voraus, dass feststeht, womit der
Absender identifiziert wird.

## Offene Fragen für die Entscheidung

- Soll die Zuordnung DID ↔ nostrPubkey signiert werden, und wenn ja – mit
  welchem Schlüssel? Das berührt die Signaturprüfung aus TD-39.
- Sollen Governance-Events perspektivisch auf DID umgestellt werden, oder ist
  `voterPubkey` dort dauerhaft akzeptabel, weil Governance ohnehin über Nostr
  läuft?
