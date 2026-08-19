# N.E.X.U.S. OneApp – Architektur-Briefing 2026

**Messenger First · Modular Underneath · Local First · Protocol First**

Quelle: Joachim, 18. August 2026
Status: **strategisches Briefing** – kein Implementierungsauftrag, keine
endgültige Architekturspezifikation.

> Dies ist die Quellfassung des Briefings, das die Architekturarbeit ab
> August 2026 auslöst. Sie wird hier unverändert im Inhalt festgehalten, damit
> die Anforderungen nachvollziehbar bleiben und nicht nur in einem Chatverlauf
> existieren. Formatierung wurde geglättet, Inhalt nicht verändert.
>
> Umsetzungsstand: [BRIEFING_ABDECKUNG.md](BRIEFING_ABDECKUNG.md)

---

## Status dieses Dokuments

Der erste Auftrag lautet ausdrücklich:

**Verstehen, prüfen, ordnen und widersprechen – noch nicht umbauen.**

Bevor größere Codeänderungen erfolgen, soll der tatsächliche technische Zustand
der OneApp ermittelt, die Dokumentationsbasis konsolidiert und daraus eine
belastbare Zielarchitektur abgeleitet werden.

## 1. Ausgangslage

Die OneApp wurde seit März 2026 weitgehend KI-gestützt mit Claude Code
entwickelt. In kurzer Zeit ist dadurch eine umfangreiche Anwendung entstanden.
Gleichzeitig haben sich Produktstrategie, Governance, Terminologie,
Architekturideen, technische Entscheidungen, Roadmaps, AETHER-Konzept und
Organisationsstruktur mehrfach weiterentwickelt.

Dadurch existieren nebeneinander: tatsächlicher Code, ältere
Implementierungspläne, aktuelle Spezifikationen, Roadmaps, Bauplan,
Bedienungsanleitungen, Governance-Dokumente, AETHER-Spezifikationen,
historische Architekturentscheidungen und neue strategische Ideen.

Eindruck: **Code, Dokumentation, Architektur und Vision sind nicht überall
synchron.** Vor der nächsten großen Entwicklungsrunde soll diese Basis
bereinigt werden.

## 2. Grundsatz: Kein Rewrite

Die bestehende OneApp wird nicht verworfen. Viele grundlegende Entscheidungen
waren richtig und sollen weitergenutzt werden:

- Flutter bleibt zunächst die primäre Client-Technologie
- vorhandene Identitätslogik bleibt Ausgangspunkt
- lokale verschlüsselte Datenhaltung bleibt
- BLE, LAN und Nostr bleiben
- vorhandene Messenger-Funktionen bleiben
- Gemeinschaften, Governance, Dorfplatz bleiben
- `MessageTransport` / `TransportManager` sind wertvolle Ausgangsbasis

Die neue Architektur soll durch **schrittweise Migration und Entkopplung**
entstehen, nicht durch Neubau.

## 3. Was N.E.X.U.S. langfristig werden soll

Selbstbestimmte digitale Identität · private Kommunikation · lokale
Kommunikation ohne Internet · lokale und thematische Gemeinschaften · Social
Feed / Dorfplatz · gemeinschaftliche Projekte · Marktplatz und Versorgung ·
Governance · Liquid Democracy · DAO-Strukturen · AETHER · gemeinschaftliche
Infrastruktur · verschiedene Lebenssphären · Community Nodes ·
Mesh-Infrastruktur · langfristig N.E.X.U.S. Linux.

Die OneApp ist der heute wichtigste Zugang. Langfristig soll N.E.X.U.S. nicht
von einer einzelnen App abhängig sein.

## 4. Aktuelle Produktstrategie: Messenger First

Ein neuer Nutzer soll N.E.X.U.S. nicht zuerst als komplexes Gesellschaftssystem
erleben. Der erste Nutzen soll sehr einfach sein: **sicher und unabhängig mit
anderen Menschen kommunizieren.**

Einstiegspfad:

```
Installieren → Identität erstellen → Kontakt hinzufügen → Chatten
→ Gruppen → Dorfplatz → Gemeinschaften → Projekte / Marktplatz
→ Governance → AETHER und weitere N.E.X.U.S.-Funktionen
```

Der Nutzer muss weder den Bauplan kennen noch N.E.X.U.S. als
Gesellschaftsvision akzeptieren. Der unmittelbare Nutzen kommt zuerst.

## 5. Messenger First – Modular Underneath

Messenger First darf **nicht** bedeuten, einen Messenger zu bauen und
anschließend immer weitere Funktionen in denselben technischen Monolithen
hineinzuprogrammieren.

Stattdessen: Der Messenger soll die **erste sichtbare Anwendung eines modularen
N.E.X.U.S.-Kerns** sein.

Arbeitsprinzip: **Simple First. Modular Underneath. Expandable by Design.**

## 6. Externe Learnings

Analysiert wurden: **Web of Trust**, **Real Life Stack**, **SourceLess**.
Diese Projekte sollen nicht kopiert werden, liefern aber Architekturprinzipien.

## 7. Learning aus Web of Trust: Infrastruktur konsequent trennen

Web of Trust trennt Fähigkeiten in austauschbare Schichten bzw. Adapter:
Storage, Reactive Storage, Crypto, Discovery, Messaging, Replication,
Authorization.

**Wichtigste Erkenntnis: Eine konkrete Technologie darf nicht mit einem
N.E.X.U.S.-Prinzip verwechselt werden.**

| Prinzip | Implementierung |
|---|---|
| Local First | SQLite |
| kryptografische Identität | did:key / Ed25519 |
| lokale Discovery | BLE |
| Internettransport | Nostr |
| dezentrale Kommunikation | Nostr |

## 8. Learning aus Real Life Stack: Die Anwendung kennt nicht das Backend

Anwendungsmodule (Feed, Kalender, Karte, Kanban, Gruppen) arbeiten gegen
gemeinsame Interfaces und wissen möglichst wenig darüber, ob Daten über lokalen
Speicher, GraphQL, CRDT, P2P oder Server bereitgestellt werden.

Zielbild:

```
Agora     → NexusCore.governance      statt → direkte SQLite-Aufrufe
Demeter   → NexusCore.marketplace              direkte Nostr-Kinds
Asklepios → NexusCore.secureData               direkte Transportlogik
```

## 9. Learning aus SourceLess: Open Standards First

Verwendet werden sollen offene Standards, dokumentierte Protokolle, etablierte
Kryptografie, interoperable Formate.

Möglichst wenig Abhängigkeit von proprietären Identitätssystemen, proprietären
Domains, einzelnen Blockchains, einzelnen Firmen, proprietärer Kryptografie.

## 10. Graceful Degradation / Offline Islands

Eine lokale Gemeinschaft soll wichtige Funktionen weiter nutzen können, wenn
Internet ausfällt, Relays nicht erreichbar sind, externe Server ausfallen oder
Dienste blockiert werden.

Mindestens perspektivisch: Identität, Kontakte, lokale Discovery, Chat, lokale
Gruppen, relevante Community-Daten.

**Nicht Online oder Offline – sondern kontrollierte Degradation.**

## 11. Crypto Agility

Keine eigene Kryptografie. Etablierte, auditierbare Verfahren. Aber: Der Core
soll so aufgebaut sein, dass kryptografische Primitive später ausgetauscht
werden können (neue Sicherheitsanforderungen, gebrochene Verfahren,
Post-Quantum-Migration, neue Standards).

Die Fachlogik darf nicht neu geschrieben werden müssen, nur weil ein
kryptografisches Verfahren ersetzt wird.

## 12. KI-Agenten brauchen eigene Sicherheitsgrenzen

**Least Privilege for AI.** Ein KI-Agent erhält niemals automatisch Vollzugriff.

```
Kalender lesen      ≠ Kalender ändern
Nachricht formulieren ≠ Nachricht senden
Proposal analysieren  ≠ Proposal einstellen
Governance erklären   ≠ Governance-Stimme abgeben
AETHER analysieren    ≠ AETHER-Vorgang signieren
```

Kritische Handlungen brauchen explizite Berechtigungen, möglichst menschliche
Freigabe, Audit Logs.

## 13. Trust muss relational bleiben

Technische Infrastruktur darf keinen universellen Menschenwert erzeugen.
Zu unterscheiden sind:

**Identity Verification** – Habe ich überprüft, dass diese Person tatsächlich
hinter diesem Schlüssel steht? (QR-Scan, Fingerprint-Abgleich, reale Begegnung)

**Relationship Trust** – Wie vertraue ich dieser Person? Relational:
Entdeckt → Kontakt → Vertrauensperson → Bürge. A kann B sehr vertrauen; C muss
B deshalb nicht ebenfalls vertrauen.

**Credentials** – Welche Qualifikation besitzt jemand? (Arzt, Elektriker,
Moderator, Entwickler)

**Attestations** – Was bestätigt eine andere Person über jemanden? (reale
Zusammenarbeit, Projektteilnahme, Begegnung, Kompetenz)

**Governance Authority** – Welche konkreten Rechte besitzt jemand in einem
bestimmten Kontext? (Mitglieder einladen, Proposal moderieren, Space verwalten)

## 14. Kein globaler Trust Score

Diese Ebenen dürfen niemals zu „Josh hat Trust 87" zusammengeführt werden.
**Der neutrale technische Core bewertet keine Menschen.**

## 15. AURA muss klar vom Core getrennt werden

Die Dokumentation enthält unterschiedliche Entwicklungsstände von AURA. Ältere
Konzepte wirken teilweise wie ein allgemeiner Reputation Score. Neuere Ansätze
sind kontextbezogen, mehrdimensional, nicht übertragbar.

Das muss im Reality Audit geprüft und bereinigt werden. Mögliche Trennung:
Trust Relations · Credentials · Attestations · Contribution Records · Mandates.

AURA darf – falls sie bestehen bleibt – nur eine klar begrenzte Anwendung
innerhalb der N.E.X.U.S.-Schicht sein. **Nicht Teil der neutralen
Identitätsinfrastruktur.**

## 16. Drei grundsätzliche Ebenen

**Ebene 1 – neutrale Infrastruktur.** Kennt keine N.E.X.U.S.-Gesellschaftsordnung:
Identity, Devices, Relations, Verification, Credentials, Attestations, Crypto,
Storage, Replication, Messaging, Spaces, Authorization, Discovery, Transport,
Vault. Darf technisch Regeln haben (Signatur gültig, Schlüssel autorisiert,
Space-Mitglied), soll aber frei von gesellschaftlichen Normen sein.

**Ebene 2 – N.E.X.U.S.-Anwendung.** Messenger, Gemeinschaften, Dorfplatz,
Projekte, Marktplatz, Agora, Rollen, Governance, weitere Sphären. Hier dürfen
bewusst N.E.X.U.S.-Regeln gelten.

**Ebene 3 – N.E.X.U.S.-Gesellschaftsprotokoll.** Charta, DAO, Liquid Democracy,
AETHER, Commons, Versorgungsarchitektur, Föderationen, Wirtschaftsmodelle.

## 17. Arbeitshypothese: NEXUS Core

Zwischen OneApp-Features und konkreten Implementierungen soll ein klarerer
**NEXUS Core** entstehen. Mögliche Bereiche: Identity, Device Management,
Trust / Relations, Credentials / Attestations, Crypto, Local State,
Replication, Spaces, Authorization, Messaging, Discovery, Transport,
Vault / Backup, Event Log.

**Das ist eine Hypothese, keine beschlossene Implementierung.**

## 18. Der bestehende TransportManager ist ein wichtiger Ausgangspunkt

Heute existiert bereits: `OneApp → TransportManager → BLE / LAN / Nostr`.

Idee: Das vorhandene Adapterprinzip auf weitere Infrastrukturbereiche
ausweiten.

```
                  OneApp Features
                        │
                    NEXUS Core
                        │
        ┌───────────────┼────────────────┐
    Identity         Messaging         Spaces
        ├── Crypto       ├── Outbox        ├── ACL
        ├── Device       ├── ACK           ├── Keys
        ▼               ▼                ▼
                   Adapter Layer
         BLE │ LAN │ Nostr │ CRDT │ ...
```

## 19. Nostr bleibt – aber wird idealerweise eine Implementierung

Nostr ist offen, dezentral, funktionierend und tief integriert. Zu untersuchen
ist, wie stark Fachlogik direkt an Nostr gebunden ist.

Langfristiges Ziel: `Dorfplatz → NexusCore.feed → Event Layer → NostrAdapter`
statt `Dorfplatz → Nostr Kind X`. Dasselbe für Gemeinschaften, Governance,
Messaging.

## 20. Local First konsequent weiterdenken

Lokale SQLite-Datenhaltung bedeutet noch nicht vollständiges Local First.
Relevant bei mehreren Geräten, parallelen Änderungen, langen Offline-Zeiten,
gemeinschaftlichen Daten und späterer Wiederverbindung.

Nach Wiederverbindung muss ein definierter konsistenter Zustand entstehen.

## 21. CRDT als Werkzeug prüfen – nicht als Religion

Mögliche Trennung:

- **Mutable State → CRDT:** Profile, Einstellungen, bestimmte Kontakte,
  Kalender, Aufgaben, Community-Metadaten, gemeinsame Dokumente,
  Marktplatzangebote
- **Historical Truth → signed append-only events:** Governance-Entscheidungen,
  Audit Logs, relevante Willenserklärungen, AETHER, möglicherweise
  Nachrichtenhistorien

Auch diese Hypothese muss geprüft werden.

## 22. Multi-Device als Core-Funktion

Eine menschliche Identität darf nicht mit einem Gerät gleichgesetzt werden.

```
Root Identity
      ├── Smartphone
      ├── Windows-PC
      ├── Tablet
      └── Linux-System
```

Zu prüfen: Device-Key-Modell (`Root Identity → autorisiert → Device Key`).
Zu klären: Device Enrollment, Device Revocation, Recovery, Multi-Device Sync,
Offline Enrollment, Geräteverlust, Schlüsseldiebstahl.

## 23. Messaging Reliability: Outbox + ACK

Eine Nachricht ist nicht zugestellt, nur weil sie an einen Relay geschickt
wurde. Transportneutrale Zustände könnten sein:

```
QUEUED → SENT → ACCEPTED_BY_TRANSPORT → DELIVERED_TO_DEVICE
       → ACKNOWLEDGED → READ
```

Nicht jeder Transport muss jede Stufe unterstützen, aber die Semantik sollte
oberhalb einzelner Transporte definiert sein.

## 24. Universal Spaces prüfen

Statt für jeden Raumtyp separate Grundmechanismen: ein `NexusSpace` mit
Space ID, Members, Keys, Key Generation, Permissions, Replication, Metadata,
Modules. Darauf aufbauend: ChatSpace, CommunitySpace, ProjectSpace,
GovernanceSpace, MarketplaceSpace, HealthSpace.

**Nur umsetzen, wenn es den vorhandenen Code wirklich vereinfacht. Keine
Abstraktion um der Abstraktion willen.**

## 25. Schlüsselrotation muss systematisch werden

Wer einen privaten Space verlässt, besitzt möglicherweise noch den bisherigen
Gruppenschlüssel. Membership Change muss Key Change bedeuten können.

```
Generation 0: A B C D   →   D verlässt   →   Generation 1: A B C
```

Neue Inhalte werden nur noch mit Generation 1 verschlüsselt. Einmal im Core
lösen statt separat in Kanal, Gemeinschaft, Projekt und Agora.

## 26. Capability-basierte Autorisierung prüfen

Heute: Rollen (SUPERADMIN, SYSTEM_ADMIN, CHANNEL_ADMIN, MODERATOR, FOUNDER,
MEMBER). Für die Genesis-Phase nachvollziehbar.

Langfristig ggf. capability-basiert: nicht „Person X ist Admin", sondern
„Person X darf Mitglieder einladen, bis Datum Y, in Space Z" – ohne automatisch
Space löschen, Regeln ändern oder Schlüssel exportieren zu dürfen.

**Kein vorschneller Rewrite des heutigen Rollensystems. Zuerst evaluieren.**

## 27. Vault / Backup als austauschbare Infrastruktur

`BackupAdapter` mit Implementierungen: Local Backup, USB, eigener NAS, eigener
VPS, Community Node, N.E.X.U.S. Vault, anderer kompatibler Provider.

Remote gespeicherte Daten sollten clientseitig verschlüsselt sein. Remote
Backup bleibt freiwillig.

## 28. Keine einzelne technische Abhängigkeit darf N.E.X.U.S. definieren

**No Single Dependency.** Gilt insbesondere für Nostr, SQLite, CRDT, Yjs,
bestimmte Relays, bestimmte Vaults, bestimmte Server, einzelne DID-Verfahren,
einzelne KI-Provider.

## 29. N.E.X.U.S. Linux

```
                    NEXUS Core
        ┌───────────────┼───────────────┐
     Android         Windows          Linux
```

- **Phase 1:** OneApp läuft als Linux-Client
- **Phase 2:** Einzelne Core-Komponenten als Hintergrunddienste (Identity,
  Discovery, Messaging, Sync, Vault)
- **Phase 3:** Tiefe Desktop-Integration
- **Phase 4:** Community Node – ein Rechner als Client, Relay, Local Discovery
  Node, Store-and-Forward Node, CRDT Replica, Vault, Infrastructure Node
- **Phase 5:** optional eigene Distribution, Desktop Layer, vorkonfigurierte
  Hardware

**Der Core soll Linux ermöglichen. Wir bauen Linux noch nicht jetzt.**

## 30. Was wir ausdrücklich NICHT tun wollen

- **Kein Rewrite** – bestehenden Code nicht wegwerfen
- **Kein Technologie-Hopping** – nicht von Flutter wechseln
- **Nostr nicht entfernen** – entkoppeln ist etwas anderes als ersetzen
- **Nicht alles CRDT** – nur wo CRDT tatsächlich Probleme löst
- **Keine eigene Kryptografie**
- **Kein globaler Trust Score**
- **AETHER nicht in den neutralen Core mischen**
- **Governance nicht in Identität einbauen**
- **Keine Infrastruktur-Endlosschleife** – nicht ein Jahr Core bauen und das
  Produkt vergessen; Messenger First läuft parallel weiter
- **Keine zusätzlichen Großbaustellen** – kein eigener Browser, Satellitendienst,
  eSIM-Infrastruktur, keine eigene Blockchain

## 31. Spezifikation und Implementierung trennen

Unterscheidung zwischen **Normative Specification** und **Current
Implementation**. Perspektivisch: NEXUS Identity / Device / Trust / Messaging /
Space / Replication / Authorization / Governance Protocol, AETHER Protocol.
Die OneApp wäre die wichtigste Referenzimplementierung.

Noch nicht jetzt alles spezifizieren – aber die Dokumentationsstruktur sollte
diese Entwicklung ermöglichen.

## 32. Zentrales Problem: verschiedene Wahrheiten

Zu unterscheiden sind:

| Kategorie | Frage |
|---|---|
| CODE TRUTH | Was ist tatsächlich implementiert? |
| CURRENT ARCHITECTURE | Welche Architektur gilt heute? |
| PRODUCT STRATEGY | Was wollen wir kurzfristig erreichen? |
| TARGET ARCHITECTURE | Was soll mittelfristig entstehen? |
| LONG-TERM VISION | Was soll vielleicht später entstehen? |
| RESEARCH | Welche Ideen untersuchen wir? |
| HISTORICAL | Welche alten Entscheidungen gelten nicht mehr? |

**Diese Dinge dürfen nicht länger vermischt werden.**

## 33. Erster Auftrag: N.E.X.U.S. Technical Reality Audit

Bitte noch keinen Code verändern.

**A. Code Reality.** Untersuche den tatsächlichen Code, nicht aus alten
Dokumenten abgeleitet. Für jeden wichtigen Bereich:
`IMPLEMENTED` / `PARTIALLY IMPLEMENTED` / `PLACEHOLDER` / `DEAD CODE` /
`PLANNED ONLY`.

**B. Dokumenten-Audit.** Für jedes relevante technische Dokument:
`CURRENT` / `PARTIALLY CURRENT` / `SUPERSEDED` / `HISTORICAL` / `VISION` /
`RESEARCH`.

**C. Code ↔ Dokumentation.** Konkrete Liste: Dokument sagt X – Code macht Y.

**D. Dokument ↔ Dokument.** Konflikte insbesondere bei: Zelle vs. Gemeinschaft,
Governance G1/G2, Rollen, Superadmin, Trust, AURA, Nostr, Identität, Transport,
Recovery, Backup, AETHER, Roadmap.

## 34. Besonders wichtiger Audit: Trust / AURA / Reputation

Suche alle Definitionen von: Trust, Vertrauen, Reputation, AURA, Bürge,
Credential, Attestation, Skill, Contribution.

Zeige: (1) welche Definitionen im Code existieren, (2) welche in aktuellen
Dokumenten, (3) welche älteren Definitionen widersprechen, (4) welche davon
Social-Scoring-Risiken erzeugen.

Ziel: klare Trennung zwischen Identity Verification, Relationship Trust,
Credentials, Attestations, Contribution, Governance Authority, AURA.

## 35. Architektur-Kopplungsanalyse

- **Nostr-Kopplung:** Welche Features kennen Event Kinds, Relay APIs,
  Nostr-Datenmodelle?
- **SQLite-Kopplung:** Welche Features greifen direkt auf Tabellen zu?
- **Transportkopplung:** Welche Fachlogik kennt BLE, LAN, Nostr?
- **Identitätskopplung:** Wo wird `Person = Device` implizit angenommen?
- **Kryptokopplung:** Welche Fachlogik hängt an konkreten Algorithmen?
- **Gruppenlogik:** Wie viele Modelle existieren für Channel, Group, Community,
  Proposal Thread?
- **Authorization:** Wo liegen Rollen und Rechte?
- **Key Management:** Wie funktionieren private Channel Keys,
  Gruppenmitgliedschaft, Entfernung, Rotation?

## 36. Technische Schulden sichtbar machen

Kategorisieren nach `CRITICAL` / `HIGH` / `MEDIUM` / `LOW`, **zusätzlich** nach:
`MUST FIX BEFORE NEW FEATURES` / `CAN MIGRATE GRADUALLY` / `DO NOT TOUCH YET`.

Ausdrücklich zu verhindern: dass der Audit zu „Wir müssen alles refactoren"
führt.

## 37. Was wir besser NICHT ändern sollten

Ausdrücklich identifizieren: Welche bestehenden Architekturteile funktionieren
gut genug und sollten momentan nicht angefasst werden?

**Ein gutes Audit findet nicht nur Probleme. Es schützt auch funktionierende
Architektur vor unnötigem Refactoring.**

## 38. Vorgeschlagene Dokumentationsstruktur

Bitte kritisch prüfen und verbessern:

```
docs/
  00_PROJECT_STATE/   CURRENT_STATE · CURRENT_RELEASE · KNOWN_LIMITATIONS
  01_ARCHITECTURE/    CORE_ARCHITECTURE · IDENTITY · DEVICES · TRUST · CRYPTO
                      STORAGE · REPLICATION · MESSAGING · SPACES
                      AUTHORIZATION · TRANSPORT · VAULT
  02_PROTOCOLS/       identity/ trust/ messaging/ spaces/ replication/
                      governance/ aether/
  03_PRODUCT/         MESSENGER_FIRST · ONEAPP_MODULES · UX_ROADMAP
  04_IMPLEMENTATION/  FLUTTER_ARCHITECTURE · DATABASE_SCHEMA · NOSTR_MAPPING
                      BLE · LAN
  05_ROADMAP/         NOW · NEXT · LATER
  06_DECISIONS/       ADR-0001 · ADR-0002 · …
  07_RESEARCH/        WEB_OF_TRUST · REAL_LIFE_STACK · SOURCELESS
  08_ARCHIVE/
```

## 39. Architecture Decision Records

Neue Grundsatzentscheidungen als ADR festhalten: Title, Status
(PROPOSED / ACCEPTED / SUPERSEDED), Context, Decision, Consequences.

Damit dieselbe Architekturfrage nicht nach sechs Monaten erneut ungeklärt
auftaucht.

## 40. Single Source of Truth

| Frage | Ort |
|---|---|
| Was ist implementiert? | Code + CURRENT_STATE |
| Welche Architektur gilt? | ARCHITECTURE |
| Warum wurde etwas entschieden? | ADR |
| Was kommt als Nächstes? | ROADMAP/NOW + NEXT |
| Was ist Zukunft? | ROADMAP/LATER |
| Was untersuchen wir? | RESEARCH |
| Was gilt nicht mehr? | ARCHIVE |

## 41. Erst danach: Zielarchitektur bewerten

Nach dem Reality Audit soll die NEXUS-Core-Architektur kritisch bewertet
werden. **Bitte nicht automatisch bestätigen.**

- Welche Teile sind sinnvoll?
- Welche Teile sind Overengineering?
- Welche Abstraktionen kommen zu früh?
- Welche können wir mit geringem Risiko einführen?
- Welche bestehenden Komponenten könnten bereits als Core dienen?
- Was sollte maximal evolutionär verändert werden?
- Wo wäre ein Refactor gefährlicher als der aktuelle Zustand?

## 42. Mögliche spätere Migrationsreihenfolge

Noch nicht beschlossen, nur Arbeitshypothese:

| Phase | Inhalt |
|---|---|
| 0 | Reality Audit – Code und Dokumentation ordnen |
| 1 | Dokumentation – Current State, Architektur, ADRs, Archive |
| 2 | Domain Boundaries – Features von Infrastrukturgrenzen trennen |
| 3 | Messaging Reliability – Outbox, ACK, Zustellstatus |
| 4 | Identity + Devices – Multi-Device, Device Keys, Revocation |
| 5 | Local-first-Prototyp – kleiner Bereich, CRDT evaluieren |
| 6 | Space-Abstraktion – einen Raumtyp testweise migrieren |
| 7 | Key Rotation |
| 8 | Authorization / Capabilities |
| 9 | Vault / Community Nodes |

## 43. Parallel bleibt Messenger First aktiv

Der Nutzer soll vom Architekturumbau möglichst wenig merken. Parallel muss der
Messenger stabiler, einfacher, schneller und verständlicher werden.

**Core-Arbeit ist kein Selbstzweck. Sie soll den Weg
Installieren → Identität → Kontakt → Nachricht zuverlässiger machen.**

## 44. Strategisches Zielbild

```
                         N.E.X.U.S.
                 Gesellschaftsarchitektur
        Charta · DAO · Governance · AETHER
                       │
                  OneApp Layer
   Messenger · Gruppen · Dorfplatz · Gemeinschaften
   Projekte · Kalender · Marktplatz · Agora · weitere Sphären
                       │
                   NEXUS CORE
   Identity · Devices · Relations/Trust · Credentials/Attestations
   Crypto · Local State · Replication · Spaces · Authorization
   Messaging · Discovery · Event Log · Backup/Vault
                       │
                  ADAPTER LAYER
   BLE · LAN · Nostr · SQLite · CRDT · Local Vault
   Community Node · zukünftige Implementierungen
```

**Dieses Diagramm ist eine Hypothese, nicht der Auftrag, es blind umzusetzen.**

## 45. Strategische Leitfrage

Bei jeder technischen Entscheidung künftig fragen:

> **Ist dies ein N.E.X.U.S.-Prinzip oder lediglich unsere derzeitige
> Implementierung dieses Prinzips?**

## 46. Erwartungen an den Lead Architect

Keine Zustimmung um der Zustimmung willen. Sondern:

1. widersprich, wenn eine Idee technisch schlecht ist
2. benenne Overengineering
3. identifiziere versteckte Migrationsrisiken
4. schütze funktionierenden Code vor unnötigem Refactoring
5. unterscheide Vision von Produktanforderung
6. unterscheide Prinzip von Implementierung
7. bevorzuge evolutionäre Migration
8. behalte Security und Privacy als Architekturgrenzen
9. denke Offline und Multi-Device von Anfang an mit
10. behalte Messenger First als Produktfokus

## 47. Erster konkreter Auftrag

Plan für den **N.E.X.U.S. Technical Reality Audit V1** mit: Was wird
untersucht? In welcher Reihenfolge? Welche Dateien/Verzeichnisse/Dokumente?
Welche automatischen Analysen? Welche manuellen Architekturprüfungen? Wie
bestimmen wir Code Truth? Wie erkennen wir veraltete Dokumentation? Wie
dokumentieren wir Konflikte? Wie vermeiden wir versehentliche Codeänderungen
während des Audits? Welche Ergebnisse entstehen am Ende?

## 48. Gewünschte Ergebnisse des Audits

```
CURRENT_STATE.md · ARCHITECTURE_REALITY.md · DOCUMENT_STATUS_MATRIX.md
CODE_DOC_CONFLICTS.md · ARCHITECTURE_DEBT.md · TRUST_AURA_AUDIT.md
CORE_CANDIDATES.md · DO_NOT_TOUCH.md · MIGRATION_RISK_MAP.md
```

Noch keine finale Core-Architektur. Noch keine Migration. Noch kein Refactor.

## 49. Danach Brainstorming

Erst nach dem Audit entscheiden: ob NEXUS Core sinnvoll ist, wie groß er sein
sollte, welche Komponenten zuerst abstrahiert werden, ob CRDT sinnvoll ist, wie
Multi-Device umgesetzt wird, ob ein NexusSpace sinnvoll ist, welche vorhandenen
Komponenten bleiben, welche externen Komponenten verwendet werden, welche Dinge
wir weiterhin selbst entwickeln.

## 50. Die zentrale Frage

Wenn du heute die bestehende OneApp als Lead Architect übernehmen würdest und
wüsstest: Das Produkt existiert bereits · ein Rewrite ist ausgeschlossen ·
Messenger First bleibt · Local First ist wichtig · echte Dezentralität ist
wichtig · Offline-Betrieb ist wichtig · Multi-Device wird wichtig · die
Plattform soll bis Linux und Community Nodes wachsen · Governance und AETHER
sollen später auf derselben Basis funktionieren · der neutrale technische
Unterbau soll möglichst unabhängig von der N.E.X.U.S.-Gesellschaftsordnung
bleiben –

**dann: Wie würdest du den heutigen technischen Zustand zuerst untersuchen und
ordnen, bevor du entscheidest, welche Architektur wir tatsächlich verändern?**

**Und: Welche drei bis fünf Architekturentscheidungen werden entscheidend dafür
sein, ob wir in zwei Jahren eine modulare Plattform oder einen schwer wartbaren
Monolithen haben?**

## Abschließender Grundsatz

> Wir bauen nicht neu, nur weil andere etwas elegant gelöst haben.
> Wir lernen. Wir prüfen. Wir übernehmen gute Prinzipien.
> Wir schützen, was funktioniert. Wir ersetzen nur, wenn der Nutzen klar ist.
>
> Ziel: **Eine einfache OneApp für Menschen auf einem modularen, offenen,
> resilienten und austauschbaren technischen Fundament.**
