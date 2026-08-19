# Web of Trust

Recherchestand: 18. August 2026
Grundlage: **Codeanalyse des geklonten Repositories**, nicht nur Website

Quellen:
- [github.com/antontranelis/web-of-trust-concept](https://github.com/antontranelis/web-of-trust-concept)
- [web-of-trust.de](https://web-of-trust.de) · [/architecture](https://web-of-trust.de/architecture)
- `real-life-org/wot-spec` (separates Spezifikationsrepository, referenziert im Code)

> **Korrekturhinweise (zwei Runden).**
> **Runde 1** (nach Codeanalyse der Repos): eine erste Fassung beruhte nur auf
> Website und GitHub-Metadaten und war in wesentlichen Punkten falsch —
> Capabilities und Outbox/ACK sind implementiert und spezifiziert, nicht
> „geplant".
> **Runde 2** (nach Analyse von `real-life-org/wot-spec`, dem separaten
> Normativ-Repository): zwei Aussagen aus Runde 1 waren selbst zu stark.
> Device Delegation ist ein **Phase-2-Entwurf** mit best-effort-Widerruf, nicht
> abgeschlossen — Web of Trust nutzt heute (Phase 1) noch dasselbe
> Shared-Seed-Modell wie N.E.X.U.S. Der Trust-Score mit Decay/Multipath ist eine
> **optionale `wot-hmc@0.1`-Extension**, kein Konflikt mit dem WoT-Kernprotokoll.
> Beide Korrekturen stehen unten an der jeweiligen Stelle markiert.

## Was es wirklich ist

Nicht ein Projekt, sondern eine **Allianz aus drei Projekten mit gemeinsamer
Spezifikation**:

| Projekt | Verantwortlich | Sprache | Rolle |
|---|---|---|---|
| **Web of Trust** | Anton Tranelis | TypeScript | Identität, Vertrauen, Sync |
| **Real Life Stack** | Anton Tranelis, Sebastian Stein | TypeScript/React | App-Baukasten, Module |
| **Human Money Core** | Sebastian Galek | **Rust** | Dezentrale Gutscheine (Minuto-Konzept) |
| **`wot-spec`** | gemeinsam | – | **Normative Spezifikation + Test-Vektoren** |

Belegt durch [`docs/concepts/wot-human-money-core-integration.md`](https://github.com/antontranelis/web-of-trust-concept/blob/main/docs/concepts/wot-human-money-core-integration.md)
(Autoren: Anton Tranelis, Sebastian Galek, Eli; Stand 30.03.2026).

Relay der Allianz: `wss://relay.utopia-lab.org`.

## Reifegrad

| | |
|---|---|
| Sprache | TypeScript |
| Umfang | **62.035 Zeilen** in 344 Dateien (ohne Tests) |
| Lizenz | **MIT** (bewusst gegen Copyleft entschieden) |
| Commits | ~1.570 |
| Sterne | 6 |
| Tests | 2.400+ (Vitest), 22 Playwright-E2E, 308 im Core |
| Pakete | `wot-core`, `wot-relay`, `wot-vault`, `wot-profiles`, `wot-cli`, `wot-fdroid`, `adapter-automerge`, `adapter-yjs` |

Zum Vergleich: N.E.X.U.S. hat 67.852 Zeilen Dart. **Die Projekte sind
größenmäßig ebenbürtig.** Wenige GitHub-Sterne bedeuten geringe Sichtbarkeit,
nicht geringe Substanz.

## Der wichtigste Befund: eine echte Protokollspezifikation

`packages/wot-core/src/protocol/` ist bewusst von der Anwendung getrennt und
darf nicht auf Storage, Messaging, CRDT oder UI zugreifen. Darüber liegt ein
**separates Spezifikationsrepository** `real-life-org/wot-spec` mit
Konformitätsmanifest und Test-Vektoren.

**Versionierte Profile:**

| Profil | Inhalt |
|---|---|
| `wot-identity@0.1` | Schlüsselableitung, did:key, DID-Resolution, JCS/JWS |
| `wot-trust@0.1` | Attestations als VC-JWS, QR-Challenge, Verifikation |
| `wot-sync@0.1` | ECIES, Log-Einträge, Capabilities, Key Rotation, Broker-Protokoll, ACK |
| `wot-device-delegation@0.1` **(geplant / Phase-2-Entwurf)** | Device Key Binding, delegierte Attestations, Widerruf (best-effort) |
| `wot-hmc@0.1` | Trust Lists als SD-JWT-VC, Trust-List-Deltas |

**Verwendete Standards:** JCS (RFC 8785), JWS/EdDSA, W3C Verifiable
Credentials, SD-JWT-VC, DIDComm-kompatible Plaintext-Envelopes, did:key,
ECIES, HKDF, AES-GCM, RFC3339.

Der Spezifikationsprozess ist real: `COVERAGE.md` verweist auf rund zwanzig
geschlossene und offene Issues im Spec-Repository (`wot-spec#16` bis `#66`),
jeweils mit Begründung, welche Regel wo normativ verankert ist.

**Das ist die entscheidende Erkenntnis für die Kooperationsfrage.** Es existiert
eine sprachunabhängige Spezifikation mit Test-Vektoren. Eine Dart-Implementierung
könnte gegen dieselben Vektoren validiert werden — **Kooperation ohne
gemeinsamen Code**. Genau das, was §31 des Briefings anstrebt.

## Identitätsableitung: die präzise Differenz

Bis zum 64-Byte-Seed sind beide Projekte **bit-identisch**:

| Schritt | Web of Trust | N.E.X.U.S. |
|---|---|---|
| Wortliste | BIP-39 **englisch** | BIP-39 **englisch** ✓ |
| Passphrase | `""` | `''` (Standard) ✓ |
| Seed | PBKDF2-HMAC-SHA512, 2048 Runden, Salt `"mnemonic"`, 64 Byte | identisch ✓ |

Danach trennen sich die Wege — **in genau einem Schritt**:

```
Web of Trust:
  ed25519Seed = HKDF-SHA256(seed64, info="wot/identity/ed25519/v1", 32)
  x25519Seed  = HKDF-SHA256(seed64, info="wot/encryption/x25519/v1", 32)

N.E.X.U.S.:
  privateKey  = HMAC-SHA512(key="ed25519 seed", seed64)[0..32]   // SLIP-0010
  x25519      = aus dem Ed25519-Privatschlüssel abgeleitet (birational)
```

**Rechnerisch verifiziert (18.08.2026)** mit dem Standard-BIP-39-Testvektor
(`abandon × 11 + about`, leere Passphrase):

| Schritt | Ergebnis |
|---|---|
| BIP-39-Seed | `5eb00bbddcf069084889a8ab…` — **identisch**, entspricht exakt `bip39_seed_hex` aus `test-vectors/phase-1-interop.json` |
| WoT HKDF | `f5dfa334475ac58513d0be39…` — **reproduziert den Testvektor `ed25519_seed_hex` byte-genau** |
| N.E.X.U.S. SLIP-0010 | `560f9f3c94558b6551928bb7…` — **abweichend** |

Damit ist nicht nur aus dem Code gelesen, sondern nachgerechnet: gleicher Seed,
verschiedene Identitätsschlüssel, verschiedene DIDs.

**Nebenbefund mit praktischem Wert:** Die WoT-Ableitung ließ sich in rund zehn
Zeilen nachbauen und traf den Testvektor auf Anhieb. Der Aufwand für eine
Dart-Implementierung von `wot-identity@0.1` ist entsprechend klein und
gegen die Vektoren objektiv prüfbar.

**Warum sie X25519 separat ableiten** (Spec `001`, Zeile 83): Web Crypto API
erzeugt Ed25519-Keys als `non-extractable`; die birationale Abbildung
Ed25519 → X25519 braucht aber den rohen Privatschlüssel und ist im Browser
deshalb unmöglich. N.E.X.U.S. nutzt genau diese birationale Ableitung — auf
nativen Plattformen zulässig, aber ein weiterer Punkt, an dem die beiden
Ableitungsbäume auseinandergehen.

Belege: [`protocol/identity/key-derivation.ts:47-50`](https://github.com/antontranelis/web-of-trust-concept/blob/main/packages/wot-core/src/protocol/identity/key-derivation.ts),
`wot-spec/01-wot-identity/001-*.md` Zeilen 29–30 und 83,
`wot-spec/test-vectors/phase-1-interop.json`, gegen
[identity_service.dart:165](../../lib/core/identity/identity_service.dart).

**Folge:** Dieselbe Seed-Phrase erzeugt in beiden Systemen **verschiedene DIDs**.
Ein Nutzer kann seine Wörter nicht einfach mitnehmen.

**Aber:** Das Format ist identisch — `did:key`, Ed25519, Multicodec `0xed01`,
base58btc. **Signaturen sind systemübergreifend prüfbar.** Wer eine
WoT-Attestation vorlegt, kann sie in N.E.X.U.S. verifizieren, sobald der
Empfangspfad überhaupt signaturprüft (siehe TD-39).

**Einordnung:** Der Unterschied ist klein und gut isoliert. N.E.X.U.S. könnte
eine zweite, HKDF-basierte Ableitung **additiv** ergänzen — ein zweiter DID
neben dem bestehenden, ohne die vorhandene Identität anzutasten. Das wäre mit
[DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) Sperrstufe 1 vereinbar, weil nichts
Bestehendes geändert wird.

Ein weiterer Unterschied: WoT nutzt zusätzlich eine Passphrase mit PBKDF2
(600.000 Runden) zur Verschlüsselung des Seeds in IndexedDB. N.E.X.U.S.
verwendet stattdessen den Secure Storage der Plattform.

## Korrekturen: was dort bereits gelöst ist

Vier Punkte, bei denen ich N.E.X.U.S. fälschlich als gleichauf dargestellt habe.

### Device Delegation — spezifiziert als Phase-2-Entwurf, nicht als stabiler Kernbaustein

> **Korrektur (zweite Prüfrunde, 18.08.2026).** Die erste Fassung stellte dies
> als „gelöst" dar. Das war zu stark. Die normative Spezifikation selbst
> markiert das Profil ausdrücklich als Entwurf.

`real-life-org/wot-spec/01-wot-identity/004-device-key-delegation.md` sagt
wörtlich:

> „**Status:** Geplanter Entwurf fuer Phase 2 … **Conformance profile:**
> `wot-device-delegation@0.1` (geplant; **nicht Teil von `wot-identity@0.1`**)"

Und zur heutigen Realität:

> „**Phase 1** nutzt das Shared-Seed-Modell: alle Geräte einer Person leiten
> denselben Identity Key ab. **Phase 2** führt optionale Device Keys ein…"

**Web of Trust ist heute (Phase 1) also selbst noch beim Shared-Seed-Modell —
alle Geräte einer Person teilen denselben Schlüssel.** Genau die Situation, die
[ADR-0002](../decisions/ADR-0002-geraet-und-person.md) für N.E.X.U.S. als
Problem beschreibt, hat Web of Trust aktuell ebenfalls.

Das Phase-2-Konzept ist trotzdem wertvoll und weiter ausgearbeitet als alles,
was N.E.X.U.S. dazu hat: eigener Ed25519-`did:key` pro Gerät, `DeviceKeyBinding`
als JWS mit Capability-Allow-Liste und Gültigkeitsfenster, ein
`Delegated-Attestation-Bundle` als portabler Offline-Container. Die
TypeScript-Referenzimplementierung (`identity/device-key-binding.ts`) erreicht
laut `COVERAGE.md` „Full"-Abdeckung gegen die Test-Vektoren
(`device-delegation.json`).

**Aber: die Anwendung nutzt sie nicht.** Eine Suche über `packages` und `apps`
nach `DeviceKeyBinding` / `delegatedAttestation` außerhalb von Tests ergibt
genau drei Fundstellen — die beiden Implementierungsdateien selbst und das
Export-Barrel `protocol/index.ts`. **Null Aufrufer in der Anwendungsschicht.**

Das ist exakt dasselbe Muster wie N.E.X.U.S.' `NostrEvent.verify()`:
Protokollbaustein implementiert, gegen Vektoren getestet, aber nicht im
Produktivpfad verdrahtet. Bei uns ist es TD-39, dort ist es Phase-2-Vorbereitung.

Was die WoT-App **heute tatsächlich** kann (laut
`docs/CURRENT_IMPLEMENTATION.md`): Multi-Device mit **derselben DID und
demselben Seed** — „Multiple connections per DID", Per-Device-Inbox,
Store-and-Forward, Key-Rotation für Spaces mit E2E-Tests („Zweitgerät liest UND
schreibt nach Rotation").

**Wichtige Einschränkung, explizit in der Spec:**

> „Phase 2 hat **keine starke temporale Revocation**. … Revocation ist
> **best-effort**. … Starke temporale Verifikation ist Aufgabe von Phase 3."

Ein widerrufenes Gerät, dessen alte Signaturen offline vorliegen, bleibt so
lange gültig, wie ein Verifizierer den Widerruf nicht kennt. Das ist ein
bewusst akzeptierter Kompromiss, kein gelöstes Problem.

**Korrekte Einordnung für [ADR-0002](../decisions/ADR-0002-geraet-und-person.md):**
Web of Trust ist bei Multi-Device-**Sync** (Per-Device-Inbox, Store-and-Forward,
Key Rotation für Spaces) klar weiter als N.E.X.U.S. Ein vollständig getrenntes
**Person-/Device-Key-Modell mit belastbarem Widerruf** ist dort jedoch ebenfalls
offene Weiterentwicklung, kein abgeschlossener Zustand. Das Phase-2-Dokument ist
eine ausgezeichnete **Vorlage** für ADR-0002 — nicht ein fertiges Ergebnis, das
man kopieren könnte.

### Die wichtigste Folgerung für unsere Reihenfolge

Web of Trust hat **Multi-Device-Konsistenz gelöst, ohne Device-Keys zu haben**.
Per-Device-Inbox, Store-and-Forward, Generationen-basierte Key-Rotation und
Seq-Kollisionserkennung laufen alle auf dem Shared-Seed-Modell.

Für N.E.X.U.S. heißt das: Die Probleme, die heute real wehtun — TD-33
(divergierende Zellmitglieder zwischen Android und Windows) und TD-46
(geräteübergreifende Idempotenz über SharedPreferences) — sind
**Sync-Probleme, keine Identitätsprobleme**. Sie lassen sich lösen, bevor
ADR-0002 entschieden ist.

Das entkoppelt zwei Dinge, die im Briefing (§22) und in ADR-0002 noch
zusammenhängen:

| Frage | Dringlichkeit |
|---|---|
| Multi-Device-**Konsistenz** (TD-33, TD-46) | real, spürbar, ohne Device-Keys lösbar |
| Person-≠-Gerät als **Identitätsmodell** | Datenmodell-Grundsatz, aber kein akuter Schmerz |

ADR-0002 bleibt richtig und wichtig — aber der Leidensdruck kommt aus der
Sync-Schicht, nicht aus dem Identitätsmodell. Das sollte in die Priorisierung
einfließen.

### Schlüsselrotation — gelöst (`wot-sync@0.1`)

Nicht „geplant". Implementiert mit Generationen-Semantik:

- `sync/key-rotation-disposition.ts` — `local+1` wird angewandt, `<=local` als
  veraltet ignoriert, `>local+1` als Zukunft gepuffert
- `keyGeneration` als Pflichtfeld in Log-Einträgen;
  `sync/log-entry-key-disposition.ts` klassifiziert `process-decrypt` gegen
  `blocked-by-key`
- `key-rotation/1.0` als Nachrichtentyp, `space-rotate` als Admin-Nachricht

**Das ist §25 des Briefings** („Membership Change muss Key Change bedeuten
können", Generation 0 → Generation 1). Dort gelöst, bei N.E.X.U.S. offen.

### Capabilities — gelöst (`wot-sync@0.1`)

- `sync/space-capability.ts` mit `capability-payload.schema.json`
- Prüfung von Audience, Space, Generation, Ablauf, Signatur
- Capability-Allow-Lists in der Device Delegation

**Das ist §26 des Briefings** (capability-basiert statt rollenbasiert).
N.E.X.U.S. hat `RoleService` mit festen Rollen. Der `AuthorizationAdapter` ist
UCAN-inspiriert, wie die Website sagt — aber konkreter als dort dargestellt.

### Outbox und ACK — gelöst (`wot-sync@0.1`)

`ports/OutboxStore.ts` und `ports/PublishStateStore.ts` existieren als
Interfaces. Dazu:

- `ack/1.0` als Nachrichtentyp
- `sync/inbox-ack-disposition.ts` — ACK **erst nach durable apply**, mit
  Pending-Buffer und Abhängigkeitsmetadaten
- Per-Device-ACK-Scoping, Replay-Historie
- `sync/broker-inbox-disposition.ts` — Zustellberechnung pro aktivem Gerät

Besonders bemerkenswert die Präzision einer Festlegung:

> „ACK is documented as per-device transport/persistence confirmation only, **not
> semantic acceptance**."

**Das ist genau die Unterscheidung, um die
[ADR-0003](../decisions/ADR-0003-zustellsemantik.md) und §23 des Briefings
kreisen** — die Trennung von „auf dem Gerät angekommen" und „inhaltlich
akzeptiert". Sie ist dort ausformuliert und im Spec-Prozess begründet
(`wot-spec#51`, `#52`).

### Zusammenfassung der Korrektur

| Thema | Briefing/ADR | Web of Trust |
|---|---|---|
| Device Delegation, Widerruf | ADR-0002, offen | Phase-2-**Entwurf**, Vektoren implementiert, Widerruf **best-effort**; Phase 1 = Shared Seed wie bei uns |
| Schlüsselrotation | §25, offen | für Space-Keys implementiert; für Identity-Keys erst mit Phase-2-Device-Keys sinnvoll |
| Capabilities | §26, zurückgestellt | **spezifiziert + implementiert** |
| Outbox / ACK | ADR-0003, offen | **spezifiziert + implementiert** |
| Attestations | fehlt im Code | **spezifiziert (VC-JWS)**, qualitativ, kein Score |
| Trust-Score / Decay / Multipath | — | separate **`wot-hmc@0.1`-Extension**, Entwurf, nicht Kern |
| CRDT-Replikation | fehlt | zwei Adapter (Automerge, Yjs) |

**Auf Protokollebene ist Web of Trust bei Sync, Capabilities und ACK-Semantik
deutlich weiter.** Bei Multi-Device-Identität (Person-/Device-Trennung mit
belastbarem Widerruf) steht die Allianz an einer ähnlich frühen Stelle wie
N.E.X.U.S. — mit einem durchdachteren Entwurf, aber ebenfalls ohne
Produktionsreife.

## Der Trust-Score ist eine optionale Extension, kein Kernkonflikt

> **Korrektur (zweite Prüfrunde, 18.08.2026).** Die erste Fassung dieses
> Abschnitts sprach von einem „direkten Widerspruch im Kern beider
> Wertesysteme". Nach Lektüre von `real-life-org/wot-spec` (dem separat
> geklonten Normativ-Repository) ist das zu grob. Die Spezifikation trennt
> sauber, was ich vorher zusammengeworfen hatte.

Der Kern-Trust-Spec beschreibt ausschließlich qualitative, signierte
Einzelaussagen nach W3C-VC-Modell — Empfängerprinzip, eine Attestation pro
Aussage, keine Aggregation. Er **schließt Score-Algorithmen ausdrücklich aus**:

> `02-wot-trust/README.md:51` — „**Nicht im Trust Core enthalten** sind
> Sync-Zustellung, Broker-Routing, Device-Key-Authority,
> **Trust-Score-Algorithmen** und App-spezifische Darstellung."
>
> `02-wot-trust/README.md:60` — „Verification bestaetigt Begegnung oder
> Identitaetsbezug. **Quantitative Bewertung ist Extension-Semantik, z.B. HMC.**"

Verstärkend die Konformitätsregel:

> `CONFORMANCE.md:151` — Eine Implementierung ist `wot-hmc@0.1`-konform, wenn
> sie Trust-Listen, Trust-Scores und Gossip-Nachrichten „erzeugt **oder sicher
> ignoriert**."

Selbst wer HMC-Konformität beansprucht, muss also keine Scores berechnen.

Trust Decay, Multipath und der **aggregierte numerische Trust-Score** stehen
in einem eigenen, separaten Dokument:
[`05-hmc-extensions/H01-trust-scores.md`](https://github.com/real-life-org/wot-spec/blob/main/05-hmc-extensions/H01-trust-scores.md),
Conformance-Profil **`wot-hmc@0.1`** — ausdrücklich als **Human-Money-Extension**
deklariert, mit Sebastian Galek als Ko-Autor. Die Spezifikation selbst
stellt es tabellarisch gegenüber:

| | Qualitative Attestation (WoT Trust) | Trust List (HMC Extension) |
|---|---|---|
| Inhalt | Freitext-Aussage | Numerische Bewertung (0–3) |
| Eigentum | Empfänger besitzt | Sender besitzt und verteilt |
| Semantik | „Das sage ich über dich" | „So sehe ich mein Netzwerk" |

**Einordnung:** Es gibt keinen Widerspruch mit dem neutralen WoT-Fundament —
`wot-identity@0.1` und `wot-trust@0.1` entsprechen bereits §13/§14 des
Briefings. Der Konflikt besteht ausschließlich mit der **optionalen**
`wot-hmc@0.1`-Erweiterung, die Sebastian Galeks Human-Money-Core-Projekt
dient, nicht der WoT-Kernidentität.

N.E.X.U.S. könnte `wot-identity@0.1` und `wot-trust@0.1` interessant finden,
ohne `wot-hmc@0.1` jemals zu übernehmen. Der HMC-Trust-Score bleibt zudem
Entwurf (`Status: Entwurf`), im Code mit **null Treffern** für `decay` /
`multipath` / `trustScore` in `wot-core/src` — Roadmap, nicht gebaut.

## Der Lizenzkonflikt

| | Lizenz | Begründung |
|---|---|---|
| Web of Trust, Real Life Stack, HMC | **MIT** | „Maximale Adoption ist in der aktuellen Phase wichtiger als Copyleft-Schutz" |
| N.E.X.U.S. OneApp | **AGPL-3.0** | Netzwerk-Copyleft, bewusst gewählt |

Die Entscheidung für MIT ist dort ausdrücklich getroffen und begründet
(Sebastian Galek, „Die Open Source Falle"). Copyleft wurde erwogen und
verworfen.

**Praktische Folgen:**

- MIT-Code darf in ein AGPL-Projekt übernommen werden. Die Richtung
  Web of Trust → N.E.X.U.S. ist lizenzrechtlich möglich.
- **Die umgekehrte Richtung nicht.** AGPL-Code kann nicht in ein MIT-Projekt
  übernommen werden, ohne dessen Lizenz zu ändern.
- Eine **gemeinsame Spezifikation** ist von beidem unberührt — Spezifikationen
  sind kein Code. Das ist ein weiteres Argument für den Protokollweg.

Bei einem Kooperationsgespräch sollte dieser Punkt früh geklärt werden. Er ist
kein Detail: Er entscheidet, in welche Richtung Beiträge überhaupt fließen
können.

## Das Offline-Modell ist ein anderes

Meine frühere Aussage „Web of Trust hat kein Offline-Transport" war unpräzise.
Beide haben eines, aber grundsätzlich verschieden:

| | N.E.X.U.S. | Web of Trust |
|---|---|---|
| Ansatz | **Gerät zu Gerät** | **Infrastruktur vor Ort** |
| Technik | BLE, LAN-Discovery direkt zwischen Geräten | Raspberry-Pi-Box mit WLAN + WebSocket-Relay (`deploy/offline-pi/`) |
| Hardware nötig | keine | eine Box |
| Reichweite | Bluetooth-/WLAN-Nähe | WLAN-Reichweite der Box |
| Datenmenge | volle Nachrichten | voller E2EE-Sync |

Dazu ein **LoRa-Mesh-Konzept** (Meshtastic, 868 MHz) mit real angeschaffter
Hardware (Heltec LoRa32 V4, Elecrow ThinkNode M1), **Status: nicht
implementiert**. Ihre Analyse dazu ist technisch sauber und selbstkritisch: LoRa
hat ~237 Byte pro Paket und 1 % Duty Cycle, deshalb

> „Den WoT-Relay ‚über LoRa' laufen zu lassen ist keine Option
> (Größenordnungen zu wenig Durchsatz). Das versuchen wir bewusst nicht."

Vorgesehen ist LoRa nur für signierte Kurzsignale: Präsenz-Beacons,
Node-Binding-Attestations, Trust-gefilterte Micro-Messages.

**Was N.E.X.U.S. hier tatsächlich voraus hat:** Kommunikation zwischen zwei
Telefonen ohne jede Infrastruktur. Das ist ein echter Unterschied und bleibt ein
starkes Argument — nur nicht das, das ich zuerst formuliert hatte.

## Was N.E.X.U.S. weiterhin einbringt

| Bereich | N.E.X.U.S. | Web of Trust |
|---|---|---|
| Governance, Anträge, Abstimmungen | **implementiert**, 596 grüne Tests | nicht vorhanden |
| Liquid Democracy, Delegation, Auto-Revoke | **implementiert** (G2.1.6) | nicht vorhanden |
| BLE/LAN ohne Infrastruktur | **implementiert** | nicht vorhanden |
| Nostr als Transport | **implementiert** | nicht vorhanden |
| Nativ Android + Windows, Installer, Auto-Updater | **implementiert** | Web, Android-Demo, F-Droid-Paket |
| Flutter/Dart-Kompetenz | vorhanden | nicht vorhanden |

**Governance ist der stärkste eigene Beitrag.** Die Allianz hat Identität,
Vertrauen, Sync und Werteinheiten — aber keine kollektive
Entscheidungsfindung. N.E.X.U.S. hat sie fertig und getestet.

Zweitens: Eine Dart-Implementierung der Spezifikation existiert nirgends. Wer
`wot-identity@0.1` in Dart implementiert, erweitert die Reichweite der
Spezifikation auf das gesamte Flutter-Ökosystem.

## Human Money Core und AETHER

> **Korrektur (zweite Prüfrunde, 18.08.2026).** „N.E.X.U.S. AETHER ist ein
> 84-Zeilen-Platzhalter" war irreführend. Das gilt nur für die
> **OneApp-Codeimplementierung** (`wallet_screen.dart`). Die **AETHER-Architektur
> selbst** ist in einem separaten, 123-seitigen Dokument
> (`AETHER_v1.0_P0_ARCHITECTURE_MASTER.docx`, Stand P0-Ready) weit
> ausgearbeitet — außerhalb des `nexus-oneapp`-Repos, in
> `!!!!!!!!!!!!!!!!!_Nexus/`, bisher **nicht in `docs/` importiert**.

Direkt relevant: **Human Money Core ist eine Rust-Library für dezentrale
Gutscheine** nach dem [Minuto-Konzept](https://minuto.org). Jeder Gutschein
trägt eine eigene Micro-Chain, offline-fähig, mit automatischer
Double-Spend-Erkennung per Gossip.

AETHER (VITA/TERRA/AURA/HNI) hat unabhängig davon bereits eine detaillierte
Monetärarchitektur: Genesis Liquidity, ein symmetrischer Monetary Controller
(M3-R) mit Realization Gate und Supply Safeguard, einen Commons-Wasserfall
(Betrieb → Reserve → Gaia → Retirement → Dividende), Realm-basierte
Mitgliedschaft mit expliziter Trennung von Membership und wirtschaftlicher
Handlungsfähigkeit. Ein Prüfbericht vom 18.08.2026 attestiert
„Monetary Core Architecture Ready · P0 Architecture Ready".

**Besonders wichtig für die Kooperations- und Wertekonflikt-Frage:** Anhang B.1
des Master-Dokuments („REMOVED / DO NOT BUILD") schließt explizit aus:

- `global_aura_score` oder jeden anderen globalen Menschenscore
- AURA-Stimmgewicht, AURA-Premiumwohnen, AURA-Rendite, AURA als Ressourcenvorrang
- automatische mittlere AURA für nicht arbeitende/kranke Menschen
- personenbezogenen monetären Skill-Multiplikator
- HNI als Personen-/Lohnscore oder autonomen Investitionsentscheider
- Recognition Counts, Leaderboards, XP, Streaks, Minus-AURA, automatische Recognition

**Das ist eine unabhängig von dieser Recherche entstandene, eigene Absage an
genau das Muster**, das oben als „Wertekonflikt" mit der optionalen
`wot-hmc@0.1`-Extension diskutiert wurde. AETHER hat diese Frage für sich
bereits beantwortet — mit derselben Antwort wie §14 des Briefings.

Ob Minuto/HMC und AETHER inhaltlich zusammenpassen, bleibt eine offene Frage
(Minuto: Zeitgutscheine mit Bürgschaft; AETHER: VITA mit Demurrage, TERRA,
AURA, HNI, Realm-Governance). Die richtige Frage ist nicht „kann HMC unser
AETHER ersetzen", sondern: **welche bereits gelösten technischen Probleme**
(Offline-Transfers, Double-Spend-Erkennung, Gossip, signierte
Transaktionshistorien) **kann AETHER von HMC lernen**, ohne die eigene,
bereits getroffene ökonomische und normative Architektur zu übernehmen.

Zu beachten bleibt: Sebastian Galeks erklärte Priorität ist „Adoption durch
Gewerbetreibende" — ein anderes Ziel als eine Gesellschaftsarchitektur für die
Menschheitsfamilie. Nicht unvereinbar, aber nicht dasselbe.

**Empfehlung:** Das AETHER-Architecture-Master-Dokument sollte nach
`docs/specs/` importiert werden — es ist die maßgebliche Quelle für alle
AETHER-bezogenen Aussagen, nicht der OneApp-Platzhaltercode. Bis dahin gilt:
jede Aussage „AETHER ist noch nicht entschieden" ist ohne Rücksprache mit
diesem Dokument nicht verlässlich.

## Was nicht übernehmbar bleibt

- **Der TypeScript-Code selbst.** Flutter/Dart hat keine gemeinsame Grundlage.
- **Automerge und Yjs** sind JavaScript ohne Dart-Entsprechung. Bestätigt die
  Zurückstellung von CRDT.
- **Der native Weg der Allianz ist Tauri** (React-WebView + Rust-Core), nicht
  Flutter. Eine gemeinsame App ist ausgeschlossen.
- **Ein Rust-Core existiert nicht.** Die Migration ist ausdrücklich „not planned
  — preparing portability only". Sollte sie kommen, wäre eine Flutter-FFI-Bindung
  denkbar — das ist aber Spekulation über einen nicht getroffenen Entschluss.

## Offene Fragen

- Ist `wot-spec` öffentlich zugänglich, und unter welcher Lizenz stehen die
  Test-Vektoren?
- Wäre eine Dart-Implementierung von `wot-identity@0.1` als
  Konformitätsimplementierung willkommen?
- Ist die Ableitung `wot/identity/ed25519/v1` verhandelbar, oder ist sie mit den
  Vektoren fixiert? (Vermutlich fixiert — dann müsste N.E.X.U.S. additiv folgen.)
- Ist der aggregierte Trust-Score eine feste Roadmap-Entscheidung oder noch
  offen?
