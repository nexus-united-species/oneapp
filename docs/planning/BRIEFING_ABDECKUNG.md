# Abdeckung des Architektur-Briefings 2026

Stand: 18. August 2026
Quelle: [ARCHITEKTUR_BRIEFING_2026.md](ARCHITEKTUR_BRIEFING_2026.md)

Dieses Dokument verfolgt für **jede** Anforderung des Briefings, ob sie erfüllt,
teilweise erfüllt, bewusst verworfen oder noch offen ist. Zweck: Nichts soll in
Vergessenheit geraten, nur weil es in einem Chatverlauf besprochen wurde.

**Bei jedem weiteren Arbeitsblock ist dieses Dokument fortzuschreiben.**

## Status-Werte

| Wert | Bedeutung |
|---|---|
| ✅ `ERFÜLLT` | Umgesetzt und dokumentiert |
| 🟡 `TEILWEISE` | Angefangen, Rest benannt |
| ⬜ `OFFEN` | Noch nicht bearbeitet |
| ❌ `VERWORFEN` | Bewusst nicht umgesetzt, Begründung dokumentiert |
| 🔵 `LAUFEND` | Dauerregel, kein Abschluss möglich |

## Gesamtbild

| | Anzahl |
|---|---:|
| ✅ Erfüllt | 15 |
| 🟡 Teilweise | 7 |
| ⬜ Offen | 8 |
| ❌ Bewusst verworfen | 2 |
| 🔵 Laufende Regel | 5 |
| — Kontext ohne Auftrag | 13 |

**Der Reality Audit ist zu etwa zwei Dritteln erledigt.** Die größten offenen
Blöcke sind der Dokumenten-Audit (33B/33D), der dokumentenseitige
Trust/AURA-Audit (34) und die Bewertung der Zielarchitektur (41).

### Ergänzung 18.08.2026 – Recherche

§6 ist erfüllt. Drei Befunde aus der Recherche wirken auf andere Punkte zurück:

- **§9 extern bestätigt.** Web of Trust nutzt unabhängig denselben Krypto-Stack
  wie N.E.X.U.S. (Ed25519, X25519, AES-256-GCM, BIP-39, `did:key`, HKDF). Das
  ist ein starkes Argument gegen jeden Umbau der Identitätsschicht.
- **§21 (CRDT) weiter entkräftet.** Die CRDT-Bibliotheken der Referenzprojekte
  (Automerge, Yjs) sind JavaScript ohne Dart-Entsprechung. Zusätzliches
  Argument für die Zurückstellung.
- **§22 / §25 relativiert.** Key Rotation und Social Recovery sind bei Web of
  Trust ausdrücklich „geplant", nicht gebaut. N.E.X.U.S. liegt hier nicht
  hinter einem gelösten Stand zurück.

---

## Teil 1 – Strategie und Prinzipien (Abschnitte 1–32)

| § | Anforderung | Status | Wo / Anmerkung |
|---|---|---|---|
| 1 | Ausgangslage: Code/Doku/Vision nicht synchron | ✅ | Geprüft. Ergebnis war **überraschend gut**: keine Widersprüche in `docs/current/`. Siehe [ARCHITECTURE_REALITY](../current/ARCHITECTURE_REALITY.md), Abschnitt „Code gegen Dokumentation" |
| 2 | Kein Rewrite | 🔵 | Leitregel. In [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) verankert |
| 3 | Langfristige Vision | — | Kontext |
| 4 | Messenger First als Produktstrategie | 🔵 | Leitregel. In allen ADRs als Bewertungsmaßstab genutzt |
| 5 | Simple First / Modular Underneath | 🔵 | Leitregel |
| 6 | Externe Learnings (3 Projekte) | ✅ | [research/](../research/): [Web of Trust](../research/WEB_OF_TRUST.md), [Real Life Stack](../research/REAL_LIFE_STACK.md), [SourceLess](../research/SOURCELESS.md). **Befund: WoT und RLS sind ein zusammenhängender Stack, nicht zwei Projekte. SourceLess ist Gegenbeispiel, kein Vorbild** |
| 7 | Prinzip ≠ Implementierung trennen | ✅ | Kern von [ADR-0001](../decisions/ADR-0001-identitaets-identifier.md) und [ADR-0003](../decisions/ADR-0003-zustellsemantik.md). Adapterliste aus WoT als Prüfliste in [WEB_OF_TRUST](../research/WEB_OF_TRUST.md) |
| 8 | Anwendung kennt nicht das Backend | 🟡 | Analysiert (Befund 2, 7). **Präzisierung durch Recherche:** Die Connector-Schicht von Real Life Stack sitzt im Frontend und ist enger als §8 nahelegt. Zielbild nicht festgelegt – gehört zu §41 |
| 9 | Open Standards First | ✅ | Bestätigt: BIP-39, SLIP-0010, did:key W3C, BIP-340 im Einsatz. [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) Sperrstufe 1. **Extern gestützt:** Web of Trust nutzt unabhängig denselben Krypto-Stack |
| 10 | Graceful Degradation / Offline Islands | 🟡 | Als Ziel in [ADR-0003](../decisions/ADR-0003-zustellsemantik.md) aufgenommen. Keine eigene Analyse des Offline-Verhaltens |
| 11 | Crypto Agility | 🟡 | In [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) präzisiert: Abstraktion *um* die Krypto zulässig, Inhalt unverändert. Keine Abstraktion entworfen |
| 12 | Least Privilege for AI | ⬜ | **Nicht bearbeitet.** Kein KI-Agent im Code vorhanden, daher heute ohne Codebezug – aber die Regel ist nirgends festgehalten |
| 13 | Trust relational halten | ✅ | Code erfüllt es bereits: `TrustLevel { discovered, contact, trusted, guardian }`. Befund 5 |
| 14 | Kein globaler Trust Score | ✅ | Im Code bestätigt: 0 Treffer. Befund 5 |
| 15 | AURA vom Core trennen | ✅ | **Bereits entschieden, extern dokumentiert.** Der AETHER Architecture Master (außerhalb `docs/`) schließt in Anhang B.1 explizit aus: globaler AURA-Score, AURA-Stimmgewicht, Recognition-Leaderboards, personenbezogener Skill-Multiplikator, HNI als Lohnscore. Nicht im OneApp-Code sichtbar (Platzhalter), aber architektonisch entschieden. **Kein Import jetzt** — das Dokument ist in aktiver Überarbeitung (Stand `_002`, 18.08.), daraus entsteht eine neue AETHER-Spezifikation. Import erst nach deren Fertigstellung, siehe [NOW_NEXT_LATER](NOW_NEXT_LATER.md) |
| 16 | Drei Ebenen (Infrastruktur / Anwendung / Gesellschaftsprotokoll) | ⬜ | Als Modell nicht bewertet. Gehört zu §41 |
| 17 | NEXUS Core als Hypothese | 🟡 | Befund: `lib/core/` deckt ~80 % ab. Bewertung, welche Bereiche fehlen/überflüssig sind, steht aus (§41) |
| 18 | TransportManager als Ausgangspunkt | ✅ | Bestätigt als tragfähig. Befund 3, [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) |
| 19 | Nostr als Implementierung, nicht Architektur | ✅ | Kopplung gemessen (Befund 2), Entscheidung vorbereitet ([ADR-0001](../decisions/ADR-0001-identitaets-identifier.md)) |
| 20 | Local First konsequent | 🟡 | Storage-Kopplung analysiert (Befund 7), [ADR-0004](../decisions/ADR-0004-storage-grenze.md). Mehrgeräte-Konsistenz nicht analysiert |
| 21 | CRDT prüfen, nicht dogmatisch | ❌ | **Bewusst zurückgestellt.** Begründung in [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md): ohne Multi-Device (§22) nicht bewertbar |
| 22 | Multi-Device als Core-Funktion | ✅ | Befund 6, [ADR-0002](../decisions/ADR-0002-geraet-und-person.md) |
| 23 | Outbox + ACK | ✅ | Befund 4, [ADR-0003](../decisions/ADR-0003-zustellsemantik.md) |
| 24 | Universal Spaces | ❌ | **Bewusst zurückgestellt.** [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md): nur sinnvoll, wenn Vereinfachung belegbar – ist sie heute nicht |
| 25 | Schlüsselrotation | ⬜ | Zurückgestellt, aber **Analyse fehlt** – siehe §35 „Key Management" |
| 26 | Capability-Autorisierung | 🟡 | Zurückgestellt in [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md). Rollensystem nicht analysiert – siehe §35 „Authorization" |
| 27 | Vault/Backup-Adapter | ⬜ | Zurückgestellt. Keine Analyse des Backup-Codes |
| 28 | No Single Dependency | ✅ | Leitprinzip in [ADR-0001](../decisions/ADR-0001-identitaets-identifier.md) und [ADR-0004](../decisions/ADR-0004-storage-grenze.md) |
| 29 | N.E.X.U.S. Linux | — | Kontext. Briefing sagt selbst „nicht jetzt" |
| 30 | Was wir NICHT tun wollen | ✅ | Vollständig in [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) übernommen, ergänzt um Lauf-B-Liste |
| 31 | Spezifikation ≠ Implementierung | 🟡 | ADR-Struktur geschaffen. Protokollordner bewusst **nicht** angelegt (§38) |
| 32 | Sieben Wahrheitskategorien trennen | ✅ | „Wo steht was?"-Tabelle in [INDEX.md](../INDEX.md) |

---

## Teil 2 – Der Audit-Auftrag (Abschnitte 33–40)

| § | Anforderung | Status | Wo / Anmerkung |
|---|---|---|---|
| 33 A | Code Reality je Bereich: IMPLEMENTED / PARTIALLY / PLACEHOLDER / DEAD CODE / PLANNED ONLY | 🟡 | Inhaltlich in [PROJECT_STATUS](../current/PROJECT_STATUS.md) und [ARCHITECTURE_REALITY](../current/ARCHITECTURE_REALITY.md), aber **nicht in dieser Taxonomie**. Einzelbefunde vorhanden: Wallet = PLACEHOLDER, `NostrEvent.verify()` = DEAD CODE, Multi-Device = PLANNED ONLY |
| 33 B | Dokumenten-Audit: CURRENT / PARTIALLY CURRENT / SUPERSEDED / HISTORICAL / VISION / RESEARCH | ⬜ | **Offen.** Entspricht `DOCUMENT_STATUS_MATRIX.md`. Bewusst aus dem Audit-Light herausgenommen, aber **nicht abgearbeitet** |
| 33 C | Code ↔ Dokumentation: Dokument sagt X, Code macht Y | 🟡 | Für `docs/current/` durchgeführt → **keine Widersprüche**. **Nicht geprüft:** `guides/`, `specs/`, die 29 am 18.08. importierten Dokumente, README |
| 33 D | Dokument ↔ Dokument: Zelle vs. Gemeinschaft, G1/G2, Rollen, Superadmin, Trust, AURA, Nostr, Identität, Transport, Recovery, Backup, AETHER, Roadmap | ⬜ | **Offen. Nicht begonnen.** Dies ist der größte ungeprüfte Block |
| 34 | Trust/AURA/Reputation-Audit über Code **und** Dokumente | 🟡 | **Codeseite vollständig** (Befund 5). **Dokumentenseite offen** – gerade dort vermutet das Briefing das Problem. Entspricht `TRUST_AURA_AUDIT.md` |
| 35 | Kopplungsanalyse – 8 Achsen | 🟡 | Siehe Detailtabelle unten |
| 36 | Schulden zweiachsig: Schwere **und** MUST FIX / CAN MIGRATE / DO NOT TOUCH YET | 🟡 | [TECH_DEBT](../current/TECH_DEBT.md) hat die Schwere-Achse. **Die zweite Achse fehlt** |
| 37 | Was NICHT ändern | ✅ | [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) |
| 38 | Dokumentationsstruktur prüfen und verbessern | ✅ | Geprüft und **begründet abgelehnt**. Stattdessen `decisions/` ergänzt. [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md), Abschnitt „Die Dokumentationsstruktur" |
| 39 | ADRs einführen | ✅ | [decisions/](../decisions/) mit Vorlage, Statusmodell und 5 ADRs |
| 40 | Single Source of Truth je Informationstyp | ✅ | „Wo steht was?"-Tabelle in [INDEX.md](../INDEX.md) |

### §35 – Kopplungsanalyse im Detail

| Achse | Status | Ergebnis |
|---|---|---|
| Nostr-Kopplung | ✅ | Befund 2: 6 Importe, 9 Kind-Stellen. Schwächer als erwartet |
| SQLite-Kopplung | ✅ | Befund 7: 20 Importe, davon 6 Screens |
| Transportkopplung | ✅ | Befund 3: `MessageTransport` hält |
| Identitätskopplung (`Person = Device`) | ✅ | Befund 1 und 6 |
| Kryptokopplung | 🟡 | Verortet ([DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) Sperrstufe 1), aber **nicht gemessen**, welche Fachlogik an konkreten Algorithmen hängt |
| **Gruppenlogik** (Channel / Group / Community / Proposal Thread) | ⬜ | **Nicht analysiert.** Direkte Voraussetzung für die Bewertung von §24 (NexusSpace) |
| **Authorization** (wo liegen Rollen und Rechte) | ⬜ | **Nicht analysiert.** Voraussetzung für §26 |
| **Key Management** (Channel Keys, Mitgliedschaft, Entfernung, Rotation) | ⬜ | **Nicht analysiert.** Voraussetzung für §25 |

---

## Teil 3 – Ergebnisse und Folgeschritte (Abschnitte 41–50)

| § | Anforderung | Status | Wo / Anmerkung |
|---|---|---|---|
| 41 | Zielarchitektur kritisch bewerten – 7 Fragen | 🟡 | **Nur im Gespräch beantwortet, nicht dokumentiert.** Entspricht `CORE_CANDIDATES.md`. Teilantworten verstreut in [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md) |
| 42 | Migrationsreihenfolge Phase 0–9 | 🟡 | Phasen 3 und 4 als ADR-0003/0002 vorbereitet. **Gesamtreihenfolge nicht bewertet.** Entspricht `MIGRATION_RISK_MAP.md` |
| 43 | Messenger First läuft parallel weiter | 🔵 | 13 Bugmeldungen + 3 Änderungswünsche importiert, **noch nicht gegen Code geprüft** |
| 44 | Strategisches Zielbild | 🟡 | Als Hypothese entgegengenommen, nicht bewertet. Gehört zu §41 |
| 45 | Leitfrage „Prinzip oder Implementierung?" | 🔵 | In [decisions/README](../decisions/README.md) als Arbeitsprinzip |
| 46 | Erwartungen an den Lead Architect (10 Punkte) | ✅ | Widerspruch geleistet zu §38 (Doku-Struktur), §21/§24 (CRDT/Spaces), Umfang des Audits |
| 47 | Plan für den Reality Audit | ✅ | Als „Audit-Light" vorgelegt und entschieden |
| 48 | Neun Ergebnisdokumente | 🟡 | Siehe Detailtabelle unten |
| 49 | Brainstorming nach dem Audit | ⬜ | Steht aus. Voraussetzung: §41 |
| 50 | Die zwei zentralen Fragen | 🟡 | **Nur im Gespräch beantwortet.** Antwort 2 (die 3–5 entscheidenden Entscheidungen) ist als ADR-0001 bis 0005 dokumentiert; Antwort 1 (Vorgehen) nicht |

### §48 – Die neun geforderten Ergebnisdokumente

| Gefordert | Status | Realisiert als |
|---|---|---|
| `CURRENT_STATE.md` | ✅ | [PROJECT_STATUS.md](../current/PROJECT_STATUS.md) (bestand bereits, geprüft) |
| `ARCHITECTURE_REALITY.md` | ✅ | [ARCHITECTURE_REALITY.md](../current/ARCHITECTURE_REALITY.md) |
| `DOCUMENT_STATUS_MATRIX.md` | ⬜ | **fehlt** |
| `CODE_DOC_CONFLICTS.md` | 🟡 | Als Abschnitt in ARCHITECTURE_REALITY; nur `docs/current/` geprüft |
| `ARCHITECTURE_DEBT.md` | ✅ | Eingearbeitet als TD-53 bis TD-56 in [TECH_DEBT.md](../current/TECH_DEBT.md) – bewusst kein eigenes Dokument, um eine zweite Schuldenliste zu vermeiden |
| `TRUST_AURA_AUDIT.md` | 🟡 | Codeseite als Befund 5; **Dokumentenseite fehlt** |
| `CORE_CANDIDATES.md` | ⬜ | **fehlt** |
| `DO_NOT_TOUCH.md` | ✅ | [DO_NOT_TOUCH.md](../current/DO_NOT_TOUCH.md) |
| `MIGRATION_RISK_MAP.md` | ⬜ | **fehlt** |

**Zusätzlich geliefert, nicht im Briefing gefordert:**
[EVENT_MAP.md](../current/EVENT_MAP.md) – erfüllt Empfehlung E-5 aus
[Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md).

---

## Offene Punkte, nach Nutzen sortiert

Was aus meiner Sicht als Nächstes zählt – nicht die Reihenfolge des Briefings,
sondern nach Hebel:

**1. §41 / `CORE_CANDIDATES.md` – Zielarchitektur bewerten.**
Das Briefing verlangt ausdrücklich Widerspruch statt Zustimmung. Die Antworten
existieren, stehen aber nur im Gesprächsverlauf. Ohne dieses Dokument ist die
Kernfrage „Ist NEXUS Core sinnvoll und wie groß?" unbeantwortet – und §49
(Brainstorming) nicht möglich.

**2. §35 – die drei fehlenden Kopplungsachsen.**
Gruppenlogik, Authorization, Key Management. Alle drei sind Voraussetzung, um
§24 (NexusSpace), §26 (Capabilities) und §25 (Rotation) überhaupt bewerten zu
können. Ohne sie bleiben diese drei Themen Spekulation.

**3. §34 / §15 – Trust und AURA auf der Dokumentenseite.**
Der Code ist sauber. Die widersprüchlichen AURA-Definitionen liegen in den
Dokumenten – genau dort, wo noch nicht geprüft wurde. Betrifft unter anderem
`AETHER_Spezifikation_v0.4.docx` und die AETHER-Synopse.

**4. §33 D – Dokument-gegen-Dokument-Konflikte.**
Dreizehn benannte Konfliktfelder, keines geprüft. Besonders relevant: „Zelle
vs. Gemeinschaft" – die Umbenennung fand statt (Commit `a11bde5`), aber ob die
Dokumente konsistent sind, ist ungeprüft.

**5. §36 – zweite Schuldenachse.**
`MUST FIX BEFORE NEW FEATURES` / `CAN MIGRATE GRADUALLY` / `DO NOT TOUCH YET`.
Kleine Ergänzung an TECH_DEBT.md, hoher Steuerungsnutzen.

**6. §43 – die 13 Bugmeldungen.**
Messenger First soll parallel laufen. Bisher sind die Meldungen nur importiert,
nicht geprüft.

---

## Was bewusst nicht kommt

| Thema | Begründung |
|---|---|
| Doku-Struktur nach §38 | [DO_NOT_TOUCH](../current/DO_NOT_TOUCH.md): zweiter Umbau in fünf Wochen, leere Protokollordner |
| CRDT-Bewertung (§21) | Ohne Multi-Device nicht bewertbar. Nach [ADR-0002](../decisions/ADR-0002-geraet-und-person.md) |
| NexusSpace (§24) | Vereinfachungsnutzen heute nicht belegbar |
| Linux (§29) | Briefing sagt selbst „nicht jetzt" |

## Fortschreibung

Dieses Dokument ist nach jedem Arbeitsblock zu aktualisieren. Ein Punkt gilt
erst als erfüllt, wenn das Ergebnis **in einer Datei im Repository** steht –
nicht, wenn es im Gespräch beantwortet wurde. Genau dieser Unterschied hat die
Lücken in dieser Liste erzeugt.
