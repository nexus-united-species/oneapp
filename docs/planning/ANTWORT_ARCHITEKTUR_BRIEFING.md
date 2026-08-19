# Antwort auf das Architektur-Briefing 2026

Von: Lead Architect (Claude, Sonnet 5)
An: Joachim
Datum: 18. August 2026
Bezug: [ARCHITEKTUR_BRIEFING_2026.md](ARCHITEKTUR_BRIEFING_2026.md)
Belege: [ARCHITECTURE_REALITY.md](../current/ARCHITECTURE_REALITY.md) ·
[research/](../research/) · [decisions/](../decisions/)

---

## Vorbemerkung

Das Briefing verlangt in §46 ausdrücklich Widerspruch statt Zustimmung. Diese
Antwort liefert ihn. Sie ist in drei Teile gegliedert:

1. Die Antwort auf die zwei zentralen Fragen aus §50
2. Wo ich dem Briefing widerspreche
3. Die Kooperationsfrage – Web of Trust und Real Life Stack

Teil 3 ist neu und war nicht Teil des ursprünglichen Auftrags. Er entstand,
weil die Recherche zu §6 einen Befund ergeben hat, der die Kooperationsfrage
anders stellt als erwartet.

---

# Teil 1 – Antwort auf §50

## Frage 1: Wie würde ich den Zustand zuerst untersuchen und ordnen?

**Nicht mit neun Dokumenten.** Das Briefing fordert in §48 neun
Ergebnisdokumente. Für 68.000 Zeilen Code, betrieben von einer Person, ist das
zu viel – und §30 warnt selbst vor der „Infrastruktur-Endlosschleife". Der
Audit kann selbst zu einer werden.

Meine Reihenfolge, in der Praxis so durchgeführt:

**Erstens: Den Code fragen, nicht die Dokumente.** Importanalyse,
Symbolzählung, gezieltes Lesen der Schlüsseldateien. Das dauerte etwa eine
Stunde und beantwortete mehr als jede Dokumentenanalyse hätte beantworten
können.

**Zweitens: Prüfen, ob die vorhandene Dokumentation überhaupt falsch ist.**
Das war die wichtigste Einzelentscheidung. Ergebnis: Version, Datenbankschema,
Analyze-Baseline und alle bekannten Risiken in `docs/current/` stimmen **exakt**
mit dem Code überein. Es gab keine Widersprüche.

Damit war die Prämisse des Briefings widerlegt. Das Problem war nie, dass die
Dokumentation falsch ist – sondern dass sie **nur Status beschreibt und keine
Architektur**. Es existierte kein Dokument über Schichtung, Kopplung oder
Identitätsstruktur. Diese Lücke war zu schließen, nicht eine angebliche
Wahrheitskluft.

**Drittens: Das Vorhandene würdigen, bevor man das Fehlende sucht.** Ein Audit,
der nur Probleme findet, erzeugt Refactoring-Druck auf funktionierenden Code.
`DO_NOT_TOUCH.md` war deshalb kein Anhang, sondern ein Kernergebnis.

**Viertens: Die offenen Fragen als Entscheidungen formulieren, nicht als
Befunde.** Ein Befund lädt zum Nicken ein. Ein ADR zwingt zur Entscheidung.

**Was ich anders gemacht habe als beauftragt:** Ich habe die
Dokumentenanalyse (§33B, §33D) zurückgestellt und stattdessen die
Kopplungsanalyse vorgezogen. Das war richtig, weil Kopplung im Code lebt und
Dokumente sich schneller ändern als Architektur. Es bleibt aber eine Lücke –
sie ist in [BRIEFING_ABDECKUNG.md](BRIEFING_ABDECKUNG.md) verzeichnet.

## Frage 2: Welche drei bis fünf Entscheidungen entscheiden über modular oder Monolith?

Sortiert danach, **wie schnell sie teurer werden**:

### 1. Ein kanonischer Identitäts-Identifier ([ADR-0001](../decisions/ADR-0001-identitaets-identifier.md))

Aus einem BIP-39-Seed entstehen heute **zwei kryptografisch unabhängige
Schlüssel auf zwei verschiedenen Kurven**: `did:key` über Ed25519 und
`nostrPubkey` über secp256k1. Sie sind nicht ineinander umrechenbar.

Nirgends ist festgelegt, welcher eine Person im Datenmodell *ist*. Die Folge
sieht man in der Governance:

| Was | Identifier |
|---|---|
| Stimmberechtigten-Menge | **DID** |
| Delegations-Berechtigung | **DID** |
| Eindeutigkeit einer Stimme (`UNIQUE`) | **nostrPubkey** |
| Berechtigung einer Direktstimme | **wird nicht geprüft** |

Berechtigung wird über DIDs geprüft, Eindeutigkeit über Pubkeys durchgesetzt.
Das ist die strukturelle Ursache von V-005 aus Audit Lauf B – der fehlende
Wählerfilter fehlt nicht aus Nachlässigkeit, sondern weil der Vergleich ohne
Zuordnungsschritt unmöglich ist.

**Das ist die wichtigste Entscheidung überhaupt**, und sie steht im Datenmodell.
Solange `nostrPubkey` fachliche Datensätze schlüsselt, ist Nostr Teil der
Architektur und nicht austauschbar – §19 und §28 sind dann nicht eingehalten.

### 2. Person ≠ Gerät ([ADR-0002](../decisions/ADR-0002-geraet-und-person.md))

`deviceKey` kommt im gesamten Code **null Mal** vor. Identität ist implizit
gleich Gerät. Ein verlorenes Gerät kann nur durch vollständigen
Identitätswechsel widerrufen werden – also Verlust aller Kontakte,
Mitgliedschaften und der Governance-Historie.

Auch das ist Datenmodell. Jede Funktion, die bis zur Umsetzung entsteht, geht
implizit von „Identität = Gerät" aus und muss später angefasst werden.

### 3. Wo lebt die Zustellsemantik ([ADR-0003](../decisions/ADR-0003-zustellsemantik.md))

`PublishResultStatus` mit `PENDING → PARTIAL → ACCEPTED / REJECTED / RETRYING →
FAILED` existiert bereits vollständig, mit DAO, Retry-Backoff und Tests – liegt
aber unter `core/transport/nostr/` und ist damit an einen Transport gefesselt.
BLE und LAN haben keine Entsprechung.

Das ist die kleinste Änderung mit dem größten Hebel und mein Vorschlag für den
ersten Umsetzungsschritt.

### 4. Reden Features direkt mit der Datenbank ([ADR-0004](../decisions/ADR-0004-storage-grenze.md))

Zwanzig Dateien importieren `pod_database` direkt – darunter **sechs Screens**.
Die Persistenzschicht reicht bis in die Widget-Ebene. Solange das so ist, ist
weder SQLite austauschbar noch Local First im Sinne von §20 erreichbar.

### 5. Dateigrößen-Disziplin ([ADR-0005](../decisions/ADR-0005-dateigroesse.md))

Sieben Dateien tragen 31 Prozent des Codes. `proposal_service.dart` hat 4.097
Zeilen und ist allein größer als `lib/shared/` und `lib/services/` zusammen.

Die unglamouröseste Entscheidung – und die, die bei KI-gestützter Entwicklung
tatsächlich über Wartbarkeit entscheidet, weil eine 4.000-Zeilen-Datei nicht
zuverlässig in einen Arbeitskontext passt.

### Bewusst nicht in dieser Liste

CRDT, NexusSpace, Capability-Autorisierung, Vault-Adapter, Linux. Alle sinnvoll,
alle **später nachrüstbar**, weil keine davon eine Datenmodell-Entscheidung
erzwingt. Das Briefing verwendet auf diese fünf die meiste Energie – aus meiner
Sicht in umgekehrter Reihenfolge zur Dringlichkeit.

---

# Teil 2 – Wo ich widerspreche

## Die Dokumentationsstruktur aus §38 sollte nicht kommen

Acht Ordner, darunter `02_PROTOCOLS/` mit sieben Unterordnern für Protokolle,
die nicht existieren. Leere Ordner erzeugen den Eindruck von Substanz, wo keine
ist. Die bestehende Struktur wurde am 15. Juli reorganisiert und funktioniert.
Ein zweiter Umbau in fünf Wochen kostet Zeit ohne Erkenntnisgewinn.

Umgesetzt wurde stattdessen: **ein** neuer Ordner (`decisions/`), später ein
zweiter (`research/`). Protokollordner entstehen, wenn das erste Protokoll
geschrieben wird.

## Die AURA-Sorge trifft den Code nicht

§15 vermutet, ältere AURA-Konzepte wirkten wie ein allgemeiner Reputation
Score, und fordert Bereinigung. Im Code steht:

```dart
enum TrustLevel { discovered, contact, trusted, guardian }
```

Das ist **exakt** das relationale Modell aus §13. Kein Score, nicht
übertragbar, nicht aggregiert. „AURA" kommt im gesamten Code **einmal** vor –
als Label in einem 84-Zeilen-Platzhalter.

Der `TRUST_AURA_AUDIT` ist also Dokumentenarbeit, keine Codearbeit. Eine
Kleinigkeit allerdings: Der Platzhalter zeigt „AURA · Reputation · Nicht
transferierbar · 0" – also die Ein-Zahl-Form, vor der §14 warnt. Das jetzt zu
korrigieren kostet Minuten, in zwei Jahren eine Migration.

## Der Umfang des Audits war zu groß angesetzt

Neun Dokumente hätten Wochen gekostet, und ein Teil wäre veraltet gewesen,
bevor er genutzt wird. `CODE_DOC_CONFLICTS.md` wäre leer geblieben.

Geliefert wurden vier plus zwei nicht beauftragte, die mehr Nutzen bringen:
[EVENT_MAP.md](../current/EVENT_MAP.md) (Kind → Handler → Service, erfüllt eine
seit Juli offene Forderung aus Audit Lauf B) und
[BRIEFING_ABDECKUNG.md](BRIEFING_ABDECKUNG.md).

## SourceLess gehört nicht gleichrangig neben die anderen beiden

§6 nennt drei Projekte, die „wertvolle Architekturprinzipien" liefern. Für Web
of Trust und Real Life Stack stimmt das. SourceLess liefert seine Prinzipien
**durch Negation**:

| §9 fordert Unabhängigkeit von | SourceLess |
|---|---|
| proprietären Identitätssystemen | STR.Domains als wNFT |
| proprietären Domains | STR.Domains |
| einzelnen Blockchains | eigene Base-Layer-Blockchain |
| einzelnen Firmen | SourceLess Inc., 15+ Marken |
| proprietärer Kryptografie | GodCypher, 15+ Patente |

Fünf von fünf. Dazu: §30 warnt vor eigenem Browser, Satellitendienst, eSIM und
Blockchain – SourceLess baut alle vier gleichzeitig.

Fachlich am gravierendsten ist die beworbene **„Earthquake Randomness"**:
Erdbebendaten als Entropiequelle für kryptografische Schlüssel. Seismische
Daten werden von USGS, EMSC und GFZ öffentlich in Echtzeit publiziert. Entropie,
die ein Angreifer nachschlagen kann, ist keine Entropie.

Unabhängige Quellen stufen SourceLess als MLM-Struktur ein; das Vorgängerprojekt
CCoin wird als Pump-and-Dump beschrieben, der Anfang 2022 kollabierte – und
CCoin Network ist laut Artikel die zentrale Finanzebene des heutigen Ökosystems.
Belege in [SOURCELESS.md](../research/SOURCELESS.md).

**Du hast die richtige Schlussfolgerung bereits gezogen**, bevor diese
Recherche stattfand – §9 und §30 sind praktisch die Punkt-für-Punkt-Negation
dieses Systems. Es sollte nur nicht in späteren Diskussionen als gleichrangige
Referenz erscheinen.

---

# Teil 3 – Die Kooperationsfrage

> **Diese Fassung wurde zweimal korrigiert.** Runde 1 (nach Klonen der
> Repositories) revidierte vier Aussagen, die nur auf Webseiten beruhten.
> Runde 2 (nach Prüfung durch ChatGPT, gegengeprüft am separaten
> `real-life-org/wot-spec`-Repository und am externen
> AETHER-Architecture-Master-Dokument) korrigiert drei weitere Punkte: Der
> Trust-Score ist eine **optionale Extension**, nicht Teil des WoT-Kerns.
> Device Delegation ist ein **Phase-2-Entwurf** mit best-effort-Widerruf, nicht
> abgeschlossen. Und AETHER ist **keine 84-Zeilen-Idee**, sondern hat bereits
> eine ausgearbeitete, extern dokumentierte Architektur mit einer eigenen
> Absage an globale Scores. Alle drei Korrekturen sind unten markiert und im
> Detail in [WEB_OF_TRUST.md](../research/WEB_OF_TRUST.md) belegt.

## Was ich zuerst falsch hatte

| Frühere Aussage | Tatsächlich (Stand nach Verifikation) |
|---|---|
| „Du redest mit einem Projekt, nicht mit zweien" | **Drei Projekte in bestehender Allianz** — plus ein separates Spezifikationsrepository |
| „Gleiche Krypto ⇒ Identität interoperabel" | Seed bit-identisch, aber **ein Ableitungsschritt unterscheidet sich** ⇒ verschiedene DIDs (nachgerechnet) |
| „Device Keys: bei beiden ungelöst" | **Bei ihnen als Phase-2-Entwurf spezifiziert und vektorgetestet — aber in der Anwendung nicht verdrahtet.** Web of Trust läuft heute wie wir auf Shared Seed |
| „Key Rotation: bei beiden ungelöst" | **Für Space-Keys dort implementiert und E2E-getestet** — und zwar *ohne* Device Keys. N.E.X.U.S. ist hier zurück |
| „Web of Trust hat kein Offline-Transport" | Hat eines — **anderes Modell** (Infrastruktur-Box statt Gerät-zu-Gerät) |

Übersehen hatte ich außerdem: den Lizenzunterschied, die Einordnung des
Trust-Scores, und dass Human Money Core direkt AETHER-relevant ist.

> **Achtung beim Lesen:** Die dritte Zeile wurde in einer zweiten
> Verifikationsrunde nochmals korrigiert. Eine Zwischenfassung behauptete
> „spezifiziert und implementiert, N.E.X.U.S. ist zurück" — das war für
> Device Keys zu stark. Maßgeblich ist die Fassung in dieser Tabelle und der
> Abschnitt „Was sie gelöst haben und wir nicht" weiter unten.

## Mit wem du eigentlich sprichst

| Projekt | Person | Sprache | Rolle |
|---|---|---|---|
| **Web of Trust** | Anton Tranelis | TypeScript | Identität, Vertrauen, Sync |
| **Real Life Stack** | Anton Tranelis, Sebastian Stein | TypeScript/React | App-Baukasten |
| **Human Money Core** | **Sebastian Galek** | **Rust** | Dezentrale Gutscheine (Minuto) |
| **`wot-spec`** | gemeinsam | — | **Normative Spezifikation + Test-Vektoren** |

Es gibt bereits ein gemeinsames Integrationskonzept vom 30.03.2026 (Autoren
Anton Tranelis, Sebastian Galek, Eli). **Sie haben also schon einen Prozess für
genau diese Art von Kooperation** — das ist eine gute Nachricht und zugleich
ein Hinweis: Du kommst als vierter Partner zu einer bestehenden Struktur, nicht
als erster.

Relay der Allianz: `wss://relay.utopia-lab.org`.

## Der Befund, der die Kooperation möglich macht

**Es existiert eine sprachunabhängige Protokollspezifikation mit
Test-Vektoren.** Versionierte Profile:

| Profil | Inhalt |
|---|---|
| `wot-identity@0.1` | Schlüsselableitung, did:key, JCS/JWS |
| `wot-trust@0.1` | Attestations als W3C VC-JWS, QR-Challenge |
| `wot-sync@0.1` | ECIES, Log-Einträge, Capabilities, Key Rotation, ACK |
| `wot-device-delegation@0.1` **(geplant / Phase-2-Entwurf)** | Device Key Binding, delegierte Attestations, Widerruf (best-effort) |
| `wot-hmc@0.1` | Trust Lists als SD-JWT-VC |

Standards: JCS (RFC 8785), JWS/EdDSA, W3C Verifiable Credentials, SD-JWT-VC,
DIDComm-Envelopes, did:key, ECIES, HKDF.

**Das ist der Kooperationsweg: N.E.X.U.S. implementiert Profile in Dart und
validiert gegen dieselben Test-Vektoren.** Kein gemeinsamer Code, keine
Sprachbrücke, keine Abhängigkeit — nur ein gemeinsamer Vertrag. Genau das, was
§31 des Briefings anstrebt.

## Die Identitätsdifferenz, präzise

Bis zum 64-Byte-Seed sind beide **bit-identisch**: BIP-39 englisch, Passphrase
leer, PBKDF2-HMAC-SHA512, 2048 Runden, Salt `"mnemonic"`.

Danach **ein** Unterschied:

```
Web of Trust:  HKDF-SHA256(seed64, info="wot/identity/ed25519/v1", 32)
N.E.X.U.S.:    HMAC-SHA512(key="ed25519 seed", seed64)[0..32]     // SLIP-0010
```

Folge: dieselbe Seed-Phrase, **verschiedene DIDs**. Ein Nutzer kann seine Wörter
nicht mitnehmen.

Aber: Format identisch (`did:key`, Ed25519, Multicodec `0xed01`).
**Signaturen sind systemübergreifend prüfbar.**

**Gute Nachricht:** Der Unterschied ist klein und isoliert. N.E.X.U.S. könnte
eine zweite, HKDF-basierte Ableitung **additiv** ergänzen — ein zweiter
WoT-kompatibler DID neben dem bestehenden, ohne die vorhandene Identität
anzutasten. Größenordnung: wenige Dutzend Zeilen. Vereinbar mit
`DO_NOT_TOUCH` Sperrstufe 1, weil nichts Bestehendes geändert wird.

## Was sie gelöst haben und wir nicht — und was noch offen ist

| Thema | N.E.X.U.S. | Web of Trust |
|---|---|---|
| Device Delegation + Widerruf | ADR-0002, **offen** | **Phase-2-Entwurf**, Widerruf **best-effort**; Phase 1 = Shared Seed, wie bei uns |
| Schlüsselrotation (Spaces) | §25, **offen** | Generationen-Semantik, implementiert |
| Capabilities | §26, zurückgestellt | `space-capability.ts` + Schema |
| Outbox / ACK | ADR-0003, **offen** | `OutboxStore`, `ack/1.0`, ACK erst nach durable apply |
| Attestations | fehlt | VC-JWS spezifiziert, qualitativ |
| CRDT-Replikation | fehlt | zwei Adapter |

> **Korrektur.** Ich hatte Device Delegation ursprünglich als „gelöst,
> Coverage Full" dargestellt. Die normative Spec widerspricht dem selbst:
> `01-wot-identity/004-device-key-delegation.md` markiert das Profil
> ausdrücklich als „**Geplanter Entwurf für Phase 2**", „**nicht Teil von
> `wot-identity@0.1`**", mit „**keiner starken temporalen Revocation**" —
> Widerruf ist **best-effort**. Und: „Phase 1 nutzt das Shared-Seed-Modell:
> alle Geräte einer Person leiten denselben Identity Key ab" — **Web of Trust
> ist bei genau dem Problem, das ADR-0002 für uns beschreibt, heute selbst
> noch nicht weiter.** Was real und getestet ist: die TS-Implementierung
> erreicht „Full"-Abdeckung gegen die Test-Vektoren — das Konzept ist also
> präzise durchdacht und größtenteils implementiert, nur eben noch nicht
> normativ stabil und mit bewusst schwachem Widerruf.

Besonders lehrreich eine ihrer Festlegungen zu ACK:

> „ACK is documented as per-device transport/persistence confirmation only,
> **not semantic acceptance**."

Das ist exakt die Unterscheidung, um die ADR-0003 und §23 kreisen — dort
ausformuliert und im Spec-Prozess begründet.

**Korrigierte Einordnung:** Bei Sync, Capabilities und ACK-Semantik sind sie
deutlich weiter. Bei Multi-Device-**Identität** (Person ≠ Gerät mit
belastbarem Widerruf) stehen beide Projekte an einer ähnlich frühen Stelle —
ihr Entwurf ist aber die bessere Vorlage, als eine fertige Lösung zum
Übernehmen.

## Lizenzrahmen und ein inhaltlicher Klärungspunkt bei HMC

> **Präzisierung.** Eine frühere Fassung nannte diese beiden Punkte „zwei harte
> Hindernisse". Nach der Verifikation ist das zu stark: Der Lizenzunterschied
> ist ein handhabbarer Rahmen, kein Blocker — und der Trust-Score betrifft eine
> **optionale HMC-Extension**, nicht das WoT-Kernprotokoll.

### Der Lizenzkonflikt

| | Lizenz |
|---|---|
| Web of Trust, Real Life Stack, HMC | **MIT** — ausdrücklich gegen Copyleft entschieden |
| N.E.X.U.S. OneApp | **AGPL-3.0** — Netzwerk-Copyleft, bewusst gewählt |

Die MIT-Entscheidung ist dort begründet und getroffen (Sebastian Galek, „Die
Open Source Falle"): maximale Adoption vor Copyleft-Schutz.

- MIT → N.E.X.U.S.: lizenzrechtlich möglich
- **N.E.X.U.S. → MIT-Projekt: nicht möglich** ohne Lizenzwechsel
- **Eine Spezifikation ist von beidem unberührt**

Das ist kein Detail. Es entscheidet, in welche Richtung Beiträge fließen können —
und es ist ein weiteres starkes Argument für den Protokollweg statt Code.
**Früh klären.**

### Der Trust-Score ist eine optionale Extension, kein Kernkonflikt

> **Korrektur.** Ich hatte hier von einem „direkten Widerspruch im Wertekern
> beider Projekte" gesprochen. Das war zu grob — und ChatGPTs Einwand trifft
> zu.

Der Kern-Trust-Spec (`02-wot-trust/`) enthält **null Treffer** für „decay",
„multipath" oder Score-Aggregation — nur qualitative, signierte
Einzelaussagen. Trust Decay, Multipath und der aggregierte numerische Score
stehen in einem **separaten** Dokument,
[`05-hmc-extensions/H01-trust-scores.md`](https://github.com/real-life-org/wot-spec/blob/main/05-hmc-extensions/H01-trust-scores.md),
Conformance-Profil `wot-hmc@0.1` — ausdrücklich als **Human-Money-Extension**
deklariert, gemeinsam mit Sebastian Galek verfasst. Die Spec selbst trennt es
tabellarisch: „Qualitative Attestation (WoT Trust)" gegen „Trust List (HMC
Extension)".

Das Briefing sagt in §14:

> „Diese Ebenen dürfen niemals zu ‚Josh hat Trust 87' zusammengeführt werden.
> **Der neutrale technische Core bewertet keine Menschen.**"

**Es gibt keinen Widerspruch mit dem neutralen WoT-Fundament** —
`wot-identity@0.1` und `wot-trust@0.1` entsprechen bereits §13/§14. Der
Konflikt besteht ausschließlich mit der **optionalen** `wot-hmc@0.1`-Erweiterung
für Sebastian Galeks Human-Money-Projekt, nicht mit Web of Trust selbst.

**Noch ein Grund, es kleiner zu hängen:** AETHER hat unabhängig davon bereits
eine eigene, dokumentierte Absage an genau dieses Muster getroffen (siehe
„Human Money Core und AETHER" unten) — Anhang B.1 des AETHER-Master-Dokuments
schließt `global_aura_score` und vergleichbare Aggregationen explizit aus.

**Weiterhin gültig:** Es ist Roadmap, nicht Code. `decay`/`multipath`/`trustScore`
in `wot-core/src`: null Treffer. Verifikation ist getrennt von Vertrauen, kein
Score.

**Praktische Folge:** Man kann `wot-identity@0.1` und `wot-trust@0.1`
interessant finden, ohne `wot-hmc@0.1` jemals zu übernehmen. Falls das Gespräch
mit Sebastian Galek zu HMC/AETHER überhaupt stattfindet, ist das der Punkt, an
dem die AETHER-Position (Anhang B.1) sich direkt einbringen lässt — nicht als
Kritik an Web of Trust, sondern als Positionierung gegenüber der optionalen
HMC-Erweiterung.

## Was N.E.X.U.S. einbringt

| Bereich | N.E.X.U.S. | Allianz |
|---|---|---|
| Governance, Anträge, Quorum, Decision Records | **fertig**, 596 grüne Tests | nicht vorhanden |
| Liquid Democracy, Delegation, Auto-Revoke | **fertig** (G2.1.6) | nicht vorhanden |
| BLE/LAN **ohne Infrastruktur** | **fertig** | nicht vorhanden |
| Nostr als Transport | **fertig** | nicht vorhanden |
| Nativ Android + Windows, Installer, Auto-Updater | **fertig** | Web, Android-Demo, F-Droid |
| Flutter/Dart | vorhanden | nicht vorhanden |

**Governance ist der stärkste Beitrag.** Die Allianz hat Identität, Vertrauen,
Sync und Werteinheiten — aber **keine kollektive Entscheidungsfindung**. Real
Life Stack hat ein Resonance-Modul mit drei Werten (grün/gelb/rot, 103 Zeilen).
Kein Antragslebenszyklus, kein Quorum, keine Delegation.

Zweitens: Eine **Dart-Implementierung der Spezifikation existiert nirgends**.
Wer `wot-identity@0.1` in Dart baut, erweitert die Reichweite der Spezifikation
auf das Flutter-Ökosystem.

Drittens, zum Offline-Thema präziser als vorher: Ihr Modell ist eine
Raspberry-Pi-Box mit WLAN und Relay. LoRa-Mesh ist Konzept mit angeschaffter
Hardware, nicht implementiert — und ihre eigene Analyse sagt korrekt, dass LoRa
für Sync-Verkehr um Größenordnungen zu schmal ist. **Was wir voraus haben:
Kommunikation zwischen zwei Telefonen ohne jede Infrastruktur.**

## Human Money Core und AETHER

> **Korrektur — die wichtigste der drei.** „N.E.X.U.S. AETHER ist ein
> 84-Zeilen-Platzhalter" stimmt nur für den OneApp-Code
> (`wallet_screen.dart`). Es gibt ein separates, 123-seitiges
> Architekturdokument (`AETHER_v1.0_P0_ARCHITECTURE_MASTER.docx`, Status
> „Monetary Core Architecture Ready · P0 Architecture Ready"), das bisher
> außerhalb von `docs/` lag und mir nicht bekannt war. Ich hätte danach fragen
> müssen, bevor ich AETHER als unentschieden dargestellt habe.

HMC ist eine **Rust-Library für dezentrale Gutscheine** nach dem
[Minuto-Konzept](https://minuto.org). Jeder Gutschein trägt eine eigene
Micro-Chain, offline-fähig, automatische Double-Spend-Erkennung per Gossip.

AETHER hat unabhängig davon bereits eine ausgearbeitete Monetärarchitektur:
Genesis Liquidity, ein symmetrischer Monetary Controller (M3-R) mit
Realization Gate und Supply Safeguard, einen Commons-Wasserfall (Betrieb →
Reserve → Gaia → Retirement → Dividende), Realm-basierte Mitgliedschaft mit
expliziter Trennung von Mitgliedschaft und wirtschaftlicher
Handlungsfähigkeit.

**Direkt relevant für die Trust-Score-Diskussion oben:** Anhang B.1
(„REMOVED / DO NOT BUILD") schließt bereits explizit aus: `global_aura_score`
oder jeden anderen globalen Menschenscore, AURA-Stimmgewicht,
AURA-Premiumwohnen, AURA-Rendite, personenbezogenen monetären
Skill-Multiplikator, HNI als Personen-/Lohnscore, Recognition Counts,
Leaderboards, XP, Streaks, Minus-AURA. **Das ist dieselbe Antwort wie §14 des
Briefings — unabhängig davon getroffen.**

Die richtige Frage ist deshalb nicht „kann HMC unser AETHER ersetzen", sondern:
Welche bereits gelösten technischen Probleme (Offline-Transfers,
Double-Spend-Erkennung, Gossip, signierte Transaktionshistorien) kann AETHER
von HMC lernen, **ohne** die eigene, bereits getroffene ökonomische und
normative Architektur zu übernehmen?

Zu beachten bleibt: Sebastian Galeks erklärte Priorität ist „Adoption durch
Gewerbetreibende". Das ist ein anderes Ziel als eine Gesellschaftsarchitektur
für die Menschheitsfamilie — nicht unvereinbar, aber nicht dasselbe.

**Konkrete Empfehlung:** Das AETHER-Master-Dokument gehört nach
`docs/specs/` importiert, bevor eine der nächsten Architekturrunden AETHER
erneut streift.

## Ein direkt verwertbares Muster, unabhängig von der Kooperation

Real Life Stack modelliert Stimmen als Relation Records, deren kanonische ID ein
**SHA-256 über `[createdBy, predicate, from, to]`** ist, wobei `createdBy` aus
der authentifizierten Identität kommt und `from === global:<createdBy>` gelten
muss.

Folge: Ein Datensatz, der den Endpunkt eines anderen behauptet, **zählt nie**.
Fälschung ist nicht verboten, sondern unmöglich.

**Das löst strukturell, was bei uns als Prüfung fehlt** — V-005 (kein
Wählerfilter) und F-005 (leerer `voterPubkey` kann via REPLACE eine fremde
Stimme überschreiben). Beide Probleme entstehen, weil Absender und
Datensatz-Identität bei uns getrennt sind. Ein direkt verwertbares Muster für
ADR-0001.

## Empfehlung

**Ja zum Gespräch.** Deutlich klarer als in meiner ersten Fassung, aber mit
anderer Begründung: nicht weil wir gleichauf sind, sondern weil sie auf
Protokollebene weiter sind und eine sprachunabhängige Spezifikation existiert,
die Kooperation ohne Codekopplung erlaubt.

**Reihenfolge:**

1. **Gespräch führen, Fragen unten stellen.** Kostet nichts.
2. **Lizenzrahmen und den HMC-Klärungspunkt früh ansprechen.** Beides ist
   handhabbar, aber es klärt sich besser im ersten Gespräch als nach sechs
   Monaten.
3. **`wot-spec` lesen**, sobald zugänglich — vor allem
   `wot-device-delegation@0.1` (Phase-2-Entwurf). Selbst ohne jede Kooperation
   ist das die beste verfügbare Vorlage für ADR-0002.
4. **Nicht sofort implementieren.** Erst die Release-Blocker: F-001 bis F-003
   und die Signaturprüfung (TD-39). Das spüren zwanzig Tester, eine
   Protokollkooperation spürt vorerst niemand.
5. **Dann prüfen**, ob eine additive HKDF-Ableitung und eine Dart-Implementierung
   von `wot-identity@0.1` sinnvoll sind.

**Was ich weiterhin nicht empfehle:** gemeinsame App (ihr Weg ist Tauri, unserer
Flutter), Code-Übernahme in die andere Richtung (Lizenz), CRDT jetzt (Automerge
und Yjs sind JavaScript ohne Dart-Entsprechung).

**Bleibendes Risiko:** Beide Seiten haben Bus-Faktor eins. Zwei solche Projekte
ergeben zusammen nicht Bus-Faktor zwei, sondern zwei Ausfallpunkte plus eine
Abhängigkeit. Und Koordination kostet genau deine knappste Ressource — deine
eigene Kommandozentrale hält fest, dass du der Flaschenhals bist.

## Fragen an Anton

**Zur Spezifikation (das Wichtigste):**

1. Ist `real-life-org/wot-spec` öffentlich, und unter welcher Lizenz stehen die
   Test-Vektoren?
2. Wäre eine **Dart-Implementierung** von `wot-identity@0.1` als weitere
   Konformitätsimplementierung willkommen?
3. Ist die Ableitung `wot/identity/ed25519/v1` durch die Vektoren fixiert, oder
   ist sie noch verhandelbar? (Ich vermute fixiert — dann folgen wir additiv.)
4. Wie ist der Governance-Prozess der Spezifikation? Wer entscheidet über ein
   neues Profil?

**Zur HMC-Extension (nicht zu Web of Trust selbst):**

5. `wot-hmc@0.1` mit Trust Decay, Multipath und aggregiertem Score ist als
   Entwurf markiert und explizit von `wot-trust@0.1` getrennt — ist das schon
   eine feste Richtung für HMC, oder ist die Frage dort noch offen? AETHER hat
   für sich bereits entschieden, keinen aggregierten Personen-Score zu bauen
   (Anhang B.1 unseres Architecture-Master-Dokuments), und wir würden diese
   Position gern einbringen, falls das für euch/Sebastian Galek relevant ist.
6. Wie verhält sich das zu eurem eigenen Satz „Verbinden ≠ Vertrauen" —
   gilt der auch für die HMC-Extension, oder ist dort eine andere Philosophie
   bewusst gewählt?

**Zur Lizenz:**

7. Wie sähe eine Kooperation zwischen einem MIT- und einem AGPL-Projekt für
   euch aus? Ist eine reine Spezifikationskooperation für euch tragfähig?

**Zum Technischen:**

8. Prüft ihr eingehende Nachrichten und Attestations auf Signatur, bevor sie
   Zustand ändern? (Wir tun es derzeit nicht — TD-39, unser bekanntester offener
   Punkt. Ich lege das offen, weil es eine Vorbedingung für jede
   Vertrauensinteroperabilität ist.)
9. Wie weit ist `wot-device-delegation@0.1` in der Praxis erprobt — läuft es
   real mit mehreren Geräten?
10. Ist das Relation-Record-Modell aus Real Life Stack spezifiziert oder intern?

**Zum Strategischen:**

11. Wie viele Menschen arbeiten tatsächlich an den drei Projekten?
12. Wie ist der NGI-Zero-Antrag ausgegangen?
13. Wärt ihr an Governance interessiert? Das ist der Bereich, in dem wir
    Fertiges beitragen könnten.
14. **Wenn wir uns auf ein gemeinsames Profil einigen — wer entscheidet bei
    Uneinigkeit, und was passiert, wenn ein Projekt einschläft?**

Frage 14 bleibt die wichtigste und wird am häufigsten vergessen.

## Was diese Antwort nicht beantwortet

Ob eine Kooperation **strategisch** sinnvoll ist — Bewegung, Reichweite,
Finanzierung, Glaubwürdigkeit — kann ich nicht beurteilen. Technisch lautet die
Antwort: anschlussfähig über die Spezifikation, nicht über Code. Sie sind bei
Sync, Capabilities und ACK-Semantik weiter, wir haben Governance und
infrastrukturfreies Offline.

Zu klären bleiben zwei Punkte — beide handhabbar, keiner davon ein Blocker:
der **Lizenzrahmen** (MIT/CC BY 4.0 gegen AGPL, wobei eine reine
Spezifikationskooperation davon unberührt ist) und ein **inhaltlicher
Klärungspunkt bei der optionalen HMC-Extension** (aggregierter Trust-Score,
zu dem AETHER bereits eine eigene Position hat).
