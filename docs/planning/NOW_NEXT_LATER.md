# N.E.X.U.S. OneApp — Entscheidungsvorlage NOW / NEXT / LATER

Stand: 18. August 2026
Grundlage: [ARCHITECTURE_REALITY.md](../current/ARCHITECTURE_REALITY.md) ·
[decisions/](../decisions/) · [ANTWORT_ARCHITEKTUR_BRIEFING.md](ANTWORT_ARCHITEKTUR_BRIEFING.md) ·
[Audit Lauf A](../audits/2026-07/AUDIT_LAUF_A.md) · [Lauf B](../audits/2026-07/AUDIT_LAUF_B.md)

Zweck: eine einzige, kompakte Übersicht, was wann passiert — damit die
Architekturrunde nicht in eine dritte, vierte Diskussionsrunde läuft. Diese
Vorlage ersetzt keine Detaildokumente, sie ordnet sie nur ein.

**Leitsatz bleibt:** Messenger First — Modular Underneath. Kein Rewrite.

---

## NOW — bevor irgendetwas anderes beginnt

Diese Punkte sind bereits als Release-Blocker bestätigt (Audit Lauf A/B,
`TECH_DEBT.md`). Sie sind unabhängig von jeder Architekturentscheidung fällig
und haben Vorrang vor allen ADRs.

| ID | Thema | Warum zuerst |
|---|---|---|
| F-001 | Chat-/Kanal-Reaktionen und -Löschungen nutzen UUID statt Event-ID im `e`-Tag | Relays weisen die Events ab — sichtbarer Cross-Device-Fehler |
| F-002 | `eligibleVoters`-Snapshot wird nie gesetzt | Beteiligung/Quorum geräteabhängig — Governance-Kernfunktion betroffen |
| F-003 | Decision-Record-Retry verliert v1.3-Felder | Inhalt passt nach Fehlversand nicht mehr zum `content_hash` |
| TD-39 / V-002 | Eingehende Nostr-Events werden nicht signaturgeprüft | Voraussetzung für jede spätere Autorisierungs- oder Kooperationsentscheidung — siehe unten |

**Warum TD-39 hier steht, nicht unter NEXT:** Ohne Signaturprüfung im
Empfangspfad ist jede weitere Architekturentscheidung, die auf „wer hat das
gesendet" aufbaut (ADR-0001, ADR-0002, jede WoT-Kooperation), auf Sand gebaut.
Sie ist technisch klein (Aufruf von `NostrEvent.verify()` an einer Stelle),
aber muss vorher stehen.

**Regel:** Kein ADR wird umgesetzt, bevor NOW abgeschlossen ist. Diskussion und
Entscheidung der ADRs kann parallel laufen — Umsetzung nicht.

---

## NEXT-A — Sync-Härtung (neu, vorgezogen)

**Warum dieser Block existiert:** Die Verifikation vom 18.08. hat gezeigt, dass
Web of Trust Multi-Device-Konsistenz **ohne Device-Keys** gelöst hat — über
Per-Device-Inbox, Store-and-Forward und Generationen-Key-Rotation, alles auf
dem Shared-Seed-Modell.

Damit ist belegt: **Die heute spürbaren Multi-Device-Probleme sind
Sync-Probleme, keine Identitätsprobleme.** Sie müssen nicht auf ADR-0002
warten.

| ID | Thema | Bisherige Annahme | Jetzt |
|---|---|---|---|
| TD-33 | Zellmitglieder divergieren zwischen Android und Windows | „braucht erst Device-Identität" | **ohne ADR-0002 lösbar** |
| TD-46 | Geräteübergreifende Idempotenz über SharedPreferences | „braucht erst Device-Identität" | **ohne ADR-0002 lösbar** |

Dazu gehört fachlich [ADR-0003](../decisions/ADR-0003-zustellsemantik.md)
(transportneutrale Zustellsemantik) — es ist derselbe Problemraum und der
natürliche erste echte Architekturschritt.

**Reihenfolge in diesem Block:**

1. TD-33 und TD-46 diagnostizieren (Ursache, nicht Symptom)
2. ADR-0003 umsetzen: `PublishResultStatus` von `core/transport/nostr/` nach
   `core/transport/` heben — Zustände bleiben unverändert
3. Cross-Device-Test Android/Windows gegen die Baseline

**Was dieser Block ausdrücklich nicht ist:** kein Device-Key-Modell, keine
neue Identitätsarchitektur, kein CRDT.

---

## NEXT-B — die fünf Architekturentscheidungen

Die fünf ADRs aus [decisions/](../decisions/), sortiert nach Dringlichkeit
(wie teuer wird Nichtentscheiden pro Monat). Alle Status `VORGESCHLAGEN` —
das hier ist eine Entscheidungsvorlage, keine Umsetzungsreihenfolge.

### 1. [ADR-0001](../decisions/ADR-0001-identitaets-identifier.md) — Kanonischer Identitäts-Identifier

**Frage:** Ist `did:key` (Ed25519) oder `nostrPubkey` (secp256k1) die Person im
Datenmodell?

**Warum zuerst:** Direkte Ursache von V-005 (kein Wählerfilter) — Berechtigung
wird über DID geprüft, Eindeutigkeit über Pubkey durchgesetzt. Setzt sich in
jedem neuen Feature fort, das nicht entscheidet.

**Neuer Input aus der Recherche:** Real Life Stack löst das strukturell —
Absenderidentität ist Teil der Datensatz-ID (`SHA-256[createdBy, predicate,
from, to]`), nicht nachträgliche Prüfung. Direkt verwertbares Muster,
unabhängig von jeder Kooperation.

### 2. [ADR-0002](../decisions/ADR-0002-geraet-und-person.md) — Person ≠ Gerät

**Frage:** Bekommt jedes Gerät einen eigenen, von der Root-Identität
autorisierten Schlüssel?

**Warum zuerst:** `deviceKey` kommt im Code 0× vor. Verlorenes Gerät = Verlust
der gesamten Identität. Setzt sich in jedem Multi-Device-Feature fort.

**Neuer Input aus der Recherche:** Web of Trusts Phase-2-Konzept
(`DeviceKeyBinding`, Capability-Allow-Liste, `Delegated-Attestation-Bundle`)
ist eine ausgezeichnete **Vorlage** — aber selbst noch Entwurf mit
best-effort-Widerruf. Die Protokollbausteine sind implementiert und
vektorgetestet, **werden von der Anwendung aber nicht aufgerufen** (null
Aufrufer außerhalb Tests). Web of Trust läuft heute wie wir auf Shared Seed.

**Wichtige Entkopplung (Verifikation 18.08.):** Web of Trust hat
Multi-Device-**Konsistenz** gelöst, *ohne* Device-Keys zu haben — über
Per-Device-Inbox, Store-and-Forward und Generationen-Key-Rotation. Das heißt für
uns: **TD-33 (divergierende Zellmitglieder Android/Windows) und TD-46
(Idempotenz) sind Sync-Probleme, keine Identitätsprobleme.** Sie sind lösbar,
bevor ADR-0002 entschieden ist.

Konsequenz für die Priorisierung: ADR-0002 bleibt eine richtige
Grundsatzentscheidung fürs Datenmodell — der akute Leidensdruck sitzt aber in
der Sync-Schicht. Beides sollte nicht künstlich gekoppelt werden.

### 3. [ADR-0003](../decisions/ADR-0003-zustellsemantik.md) — Transportneutrale Zustellsemantik

**Frage:** Wird `PublishResultStatus` von `core/transport/nostr/` auf
`core/transport/` gehoben?

**Warum unabhängig von 1/2:** Kleinster Eingriff, größter Hebel. Zustände
bleiben exakt erhalten, nur die Schicht ändert sich. Zahlt direkt auf
Messenger First ein — zuverlässige Zustellung ist die sichtbarste
Messenger-Qualität.

**Empfehlung:** Gehört in den Block **NEXT-A** (Sync-Härtung) — derselbe
Problemraum wie TD-33/TD-46. Klein, testbar, rückbaubar, und damit der
Machbarkeitsnachweis für evolutionäre Migration in dieser Codebasis.

### 4. [ADR-0004](../decisions/ADR-0004-storage-grenze.md) — Grenze zwischen Fachlogik und Persistenz

**Frage:** Gilt ab sofort eine Repository-Grenze für neuen Code?

**Warum zuerst:** 20 Direktimporte von `pod_database`, davon 6 aus Screens.
Reine Disziplinregel — **keine Migration bestehenden Codes.**

### 5. [ADR-0005](../decisions/ADR-0005-dateigroesse.md) — Dateigrößen-Disziplin

**Frage:** Gilt ab sofort eine 800-Zeilen-Grenze für neue Dateien, mit
festgelegter Zerlegungsreihenfolge für Bestandscode?

**Warum zuerst:** 7 Dateien tragen 31 % des Codes. Reine Disziplinregel —
`proposal_service.dart` bleibt ausdrücklich zurückgestellt (frisch
abgeschlossen, 596 grüne Tests, drei der NOW-Blocker liegen genau dort).

### Entscheidungslogik

```
ADR-0003  → vorgezogen in NEXT-A (Sync-Härtung), erster echter Umbau
ADR-0001  → fundamental: "Was ist eine Person im Datenmodell?"
             bald entscheiden, aber nach den akuten Fehlern
ADR-0002  → baut inhaltlich auf ADR-0001 auf, ist aber NICHT dringend
             (siehe unten) — getrennt entscheiden und getrennt umsetzen
ADR-0004  → Disziplinregel, gilt ab Annahme, keine Migration
ADR-0005  → Disziplinregel, gilt ab Annahme, keine Migration
```

**Präzisierung zu ADR-0001 und ADR-0002:** Sie hängen inhaltlich zusammen —
ADR-0002 setzt eine Antwort auf ADR-0001 voraus. Sie sollten aber **nicht
gemeinsam implementiert** werden:

| | Frage | Charakter |
|---|---|---|
| ADR-0001 | Was ist eine Person im Datenmodell? | fundamental, wird täglich teurer |
| ADR-0002 | Welche Geräte dürfen für diese Person handeln? | strategisch richtig, **kein akuter Zeitdruck mehr** |

Der Zeitdruck von ADR-0002 ist durch NEXT-A entfallen: Die Probleme, die
wehtun, werden dort gelöst. ADR-0002 bleibt eine wichtige
Datenmodell-Grundsatzentscheidung — aber der laufende Multi-Device-Betrieb
hängt nicht mehr davon ab.

Zielbild bleibt unverändert, nur der Zeitpunkt verschiebt sich:

```
PERSON
  └── N.E.X.U.S. Identity (DID)
        ├── Nostr-Key (Transportadresse)
        ├── Smartphone
        ├── Windows
        └── später Tablet, Linux
```

---

## LATER — bewusst zurückgestellt

Nichts davon ist falsch oder abgelehnt. Alles ist **nachrüstbar**, weil keines
eine Datenmodell-Entscheidung erzwingt — im Gegensatz zu ADR-0001/0002.

| Thema | Warum zurückgestellt | Wann wieder aufgreifen |
|---|---|---|
| CRDT (§21) | Löst Konfliktauflösung, die unsere Sync-Architektur heute nicht braucht | **Erst wenn ein konkretes Konfliktproblem auftritt, das NEXT-A nicht sauber löst** — nicht an ADR-0002 gekoppelt |
| NexusSpace (§24) | Vereinfachungsnutzen heute nicht belegbar | Wenn Gruppenlogik-Analyse (§35) vorliegt |
| Capability-Autorisierung (§26) | Rollenmodell funktioniert für Genesis-Phase | Wenn Autorisierungs-Analyse (§35) vorliegt |
| Schlüsselrotation (§25) | Nachrüstbar; Analyse zu Gruppenmitgliedschaft fehlt | **Nach Analyse von Gruppenmitgliedschaft und Sync** — nicht zwingend nach ADR-0002. Web of Trust rotiert Space-Keys ohne Device-Keys, mit Generationen-Modell als Referenz |
| Vault-/Backup-Adapter (§27) | Backup funktioniert, Adapterfähigkeit ohne zweite Implementierung spekulativ | Bei konkretem zweiten Backend |
| N.E.X.U.S. Linux (§29) | Briefing sagt selbst „nicht jetzt" | Nach stabilem Core |
| WoT: Spezifikations-/Conformance-Prototyp | `wot-spec` ist Draft mit angekündigten Breaking Changes; unumkehrbare Abhängigkeit wäre verfrüht | **Nach NOW + ADR-0001** — braucht ADR-0002 nicht |
| WoT: Device-Delegation / tiefe Integration | Setzt ein eigenes Device-Key-Modell voraus; dort selbst noch Phase-2-Entwurf | **Nach ADR-0002** |
| AETHER-Wallet-Implementierung | OneApp-Code ist Platzhalter (84 Zeilen). Die Architektur wird derzeit überarbeitet — aus dem AETHER Architecture Master (`_002`, 18.08.) entsteht eine neue AETHER-Spezifikation, erwartet Ende August. | **Warten auf die fertige Spezifikation.** Erst dann Import nach `docs/specs/` und eigener Block |

---

## Was diese Vorlage nicht entscheidet

- Ob und wie die Kooperation mit Web of Trust/Real Life Stack/Human Money
  Core konkret aussieht — das ist eine Gesprächsfrage, kein Architekturpunkt
  (siehe [ANTWORT_ARCHITEKTUR_BRIEFING.md](ANTWORT_ARCHITEKTUR_BRIEFING.md), Teil 3).
- Die Inhalte der fünf ADRs selbst — die Vorlage ordnet sie nur ein, sie werden
  einzeln entschieden.
- Ob AETHER und Human Money Core inhaltlich zusammenpassen — offene Frage,
  siehe „Human Money Core und AETHER" in der Antwort.

## Gesamtbild

```
BESTEHENDE ONEAPP
      │
      ├── NOW      vier kritische Fehler beheben (F-001…003, TD-39)
      │
      ├── NEXT-A   Multi-Device-Sync stabilisieren (TD-33, TD-46)
      │            + Zustelllogik aus Nostr herausheben (ADR-0003)
      │
      ├── NEXT-B   Identitätsmodell entscheiden (ADR-0001)
      │            Disziplinregeln setzen (ADR-0004, ADR-0005)
      │            Device-Modell entwickeln (ADR-0002, ohne Zeitdruck)
      │
      └── LATER    schrittweise erweitern, wenn Bedarf belegt ist
```

Kein Neuaufbau. Gezielte Härtung, bevor die OneApp weiter wächst.

**Messenger First. Modular Underneath. Evolution statt Rewrite.**

## Nächster konkreter Schritt

Ausschließlich NOW abarbeiten: F-001, F-002, F-003, TD-39. Parallel können die
fünf ADRs besprochen und entschieden werden — ihre Umsetzung beginnt erst
danach, und zwar mit NEXT-A.

Danach: dieses Dokument fortschreiben, nicht neu aufsetzen.
