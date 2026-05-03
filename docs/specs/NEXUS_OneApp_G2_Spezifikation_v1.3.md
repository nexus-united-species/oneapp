# G2-Spezifikation für die N.E.X.U.S. OneApp — v1.3

## Version

```text
Spezifikation: G2 Governance
Stand: Arbeitsfassung v1.3
Ziel: Umsetzbare Grundlage für Claude Code / Opus
Technische Zielplattform: Flutter / Dart / SQLite Proto-POD / Nostr / BLE / LAN
```

---

# Änderungsstand v1.3

Diese Version präzisiert die in v1.2 eingeführten Voting-Modi und schließt offene Lücken, die bei der Implementierung auftreten würden. Sie ändert keine bestehenden Regeln, sondern schärft sie.

Wichtigste Ergänzungen gegenüber v1.2:

```text
- §9.4: Mindest-/Maximalanzahl Optionen für SINGLE_CHOICE definiert
- §9.5: Mindest-/Maximalanzahl Kandidaten für CANDIDATE_CHOICE definiert
        + Hinweis auf YES_NO_ABSTAIN bei nur einem Kandidaten
- §9.5.1 NEU: Kandidatenrücktritt während VOTING geregelt
- §9.12: Stichwahl-Workflow vollständig spezifiziert
- §9.12 SINGLE_CHOICE: Klärung dass nur Sieger-Tie INVALID auslöst,
        Ties auf Plätzen 2+ irrelevant
- §17.6: Zählung um Option-/Kandidaten-Aggregation erweitert
- §17.10 Sonderfälle: Konflikt mit §17.10 Tally aufgelöst — Top-Tie ist
         INVALID + RUNOFF, kein REJECTED
- §20.1 proposals: votingMode-Feld + Default ergänzt
- §20.7 decision_records: resultRelation-Feld für Stichwahl-Verkettung
- Sektions-Nummerierung in §17 und §20 korrigiert (waren doppelt)
```

Zusätzlich gelten die v1.1- und v1.2-Präzisierungen unverändert verbindlich:

```text
v1.2:
- votingMode pro Proposal
- YES_NO_ABSTAIN für klassische Sachfragen
- SINGLE_CHOICE für mehrere Optionen
- CANDIDATE_CHOICE für Personen-/Kandidatenwahlen
- Proposal-Optionen werden beim Erstellen der Abstimmung angelegt
- Kandidatenwahlen: keine Delegation, kein QV, 1 Mensch = 1 Stimme
- Datenmodell ergänzt um proposal_options, selectedOptionId und optionResultsJson
- Tally Engine wird nach Voting-Modus verzweigt

v1.1:
- QV + Delegation entkoppelt: delegierte Stimmen zählen bei QV immer Gewicht 1
- Voice Credits: quarterId = YYYY-Qn, UTC, kein Übertrag
- Membership-Maturity für QV: Default 14 Tage
- participationCount zählt nur gültige direkte Stimmen + gültige erfolgreiche Delegationen
- Withdraw aus VOTING erzeugt Audit + INVALID Decision Record + Credit Refund
- AURA im MVP nullable / „noch nicht berechnet"
- Votingdauer Default: 7 Tage
- Intercell: affectedScope + invitationRationaleEnc
- audit_log bekommt proposalId und cellId
- ruleSnapshotJson ist Pflicht
- Tally sortiert Inputs deterministisch
```

---

# 1. Executive Summary

G2 ist der nächste große Governance-Ausbau der N.E.X.U.S. OneApp.

G1 verwaltet bereits:

```text
Zellen
Rollen
Proposals
Diskussionsstatus
erste Agora-Struktur
Nostr-Events
```

G2 macht daraus eine echte demokratische Entscheidungsmaschine.

G2 umfasst:

```text
Direkte Abstimmung
Delegation pro Proposal
Expertenprofile
AURA-Anzeige
Quadratic Voting
Quoren
Tally Engine
Interzelluläre Entscheidungen
Superadmin-Abwahl
Append-only Audit-Log
Hybrid-Datenmodell
Nostr PublishResult / Relay ACK
```

Die zentrale Logik lautet:

```text
Zellinterne Entscheidungen bleiben der Kern.
Interzelluläre Entscheidungen bauen darauf auf.
Agora wird die politische Oberfläche der OneApp.
```

---

# 2. Grundprinzipien aus dem Bauplan

G2 folgt diesen Prinzipien:

```text
1. Macht auf Zeit
2. Macht muss sichtbar sein
3. Keine stillen Machtpyramiden
4. Kein Social-Credit-System
5. Grundrechte/Würde = 1 Mensch, 1 Stimme
6. Expertise darf sichtbar sein, aber nicht automatisch herrschen
7. Delegation ist Vertrauen, kein Herrschaftsmandat
8. Datenschutz und Transparenz müssen gemeinsam gedacht werden
9. Geschichte darf nicht gelöscht werden
10. Technik dient dem Menschen, nicht umgekehrt
```

Besonders wichtig:

```text
N.E.X.U.S. ist keine reine Mehrheitsdemokratie.
N.E.X.U.S. ist auch keine Technokratie.
N.E.X.U.S. ist eine differenzierte Demokratie.
```

Das bedeutet:

```text
Bei Würde, Rechten, Rollen, Macht und Verfassung:
1 Mensch = 1 Stimme.

Bei fachlichen Sachfragen:
Expertise und Gewichtung sind möglich, aber begrenzt, transparent und zustimmungspflichtig.
```

---

# 3. Ziele von G2

G2 soll:

```text
- echte Abstimmungen ermöglichen
- Delegation sicher und verständlich machen
- Experten sichtbar machen
- Machtkonzentration verhindern
- interzelluläre Entscheidungen ermöglichen
- Superadmin-Abwahl friedlich regeln
- Ergebnisse korrekt und nachvollziehbar berechnen
- Governance-Daten auditierbar speichern
- sensible Inhalte schützen
- Nostr-Sync zuverlässig machen
```

G2 darf nicht:

```text
- eine globale Dauer-Delegation einführen
- transitive Machtketten erlauben
- AURA als universelles Stimmgewicht verwenden
- soziale Kontrolle erzeugen
- Geschichte löschen
- zentrale Server voraussetzen
- die bestehende Zell-Agora ersetzen
```

---

# 4. Agora-Ebenen

Die OneApp kennt künftig mehrere Agora-Ebenen.

## 4.1 Zell-Agora

Das ist die bestehende Agora innerhalb einer konkreten Zelle, z. B.:

```text
Region Teneriffa Nord → Agora → Anträge / Abstimmungen
```

Die Zell-Agora ist der primäre Ort für G2.

Dort finden statt:

```text
zellinterne Proposals
zellinterne Diskussionen
zellinterne Abstimmungen
Delegation innerhalb der Zelle
Expertenauswahl
AURA-Anzeige
Tally
Audit-Verlauf
```

## 4.2 Interzelluläre Agora

Die interzelluläre Agora zeigt Entscheidungen, die mehrere Zellen betreffen.

Dort finden statt:

```text
Einladung anderer Zellen
Teilnahme/Ablehnung durch Zielzellen
zellinterne Mandatsbildung
interzelluläre Auszählung
Entscheidung nach 1 Zelle = 1 Stimme
```

## 4.3 System-Agora

Die System-Agora betrifft Entscheidungen auf Systemebene.

Dazu gehört:

```text
Superadmin-Abwahl
Stewardship-Übergang
Systemrollen
spätere Verfassungs- und Hard-Cap-Fragen
```

---

# 5. Rollen und Stimmberechtigung

## 5.1 Bestehende Rollen

Aktuell relevant:

```text
SUPERADMIN
SYSTEM_ADMIN
FOUNDER
MODERATOR
MEMBER
PENDING
```

## 5.2 Stimmberechtigung in einer Zelle

Stimmberechtigt für zellinterne Proposals sind:

```text
aktive Zellmitglieder mit Rolle MEMBER, MODERATOR oder FOUNDER
```

Nicht stimmberechtigt:

```text
PENDING
entfernte Mitglieder
blockierte Mitglieder
nicht zur Zelle gehörende Nutzer
externe Experten ohne gesonderte Freigabe
```

## 5.3 Stimmberechtigung bei Superadmin-Abwahl

Für G2 MVP stimmberechtigt:

```text
aktive System-Admins
aktive Zell-Founder
```

Nicht verwenden:

```text
verifizierte Genesis-Mitglieder
```

Begründung:

```text
Diese Rolle existiert aktuell nicht sauber im System.
Sie darf nicht in die G2-Implementierung aufgenommen werden, solange sie technisch nicht existiert.
```

Später erweiterbar um:

```text
verifizierte Mitglieder
Bürge-Level-Mitglieder
Proof-of-Personhood-Mitglieder
```

---

# 6. Proposal-Typen

## 6.1 G2-MVP Proposal-Typen

```text
GENERAL
RESOURCE
ROLE_CHANGE
RULE_CHANGE
INTERCELL
SUPERADMIN_RECALL
```

## 6.2 Spätere Proposal-Typen

```text
CONSTITUTIONAL
MEMBER_EXCLUSION
PERSONAL_SANCTION
HARD_CAP_CHANGE
FEDERATION
SPHERE
RESTORATIVE_JUSTICE
MINORITY_PROTECTION
```

---

# 7. Proposal-Scopes

Jedes Proposal hat einen Scope.

```text
proposalScope:
- CELL
- INTERCELL
- SYSTEM
```

Später vorbereitet:

```text
FEDERATION
SPHERE
```

## Bedeutung

```text
CELL:
betrifft genau eine Zelle.

INTERCELL:
betrifft mehrere konkrete Zellen.

SYSTEM:
betrifft die OneApp-/Genesis-/Systemstruktur.

FEDERATION:
später: ganze Föderation oder Region.

SPHERE:
später: Sphären-Governance, z. B. Demeter, Asklepios, Hestia.
```

---

# 8. Proposal Lifecycle

## 8.1 Status

```text
DRAFT
DISCUSSION
VOTING
DECIDED
WITHDRAWN
ARCHIVED
INVALID
```

Später vorbereitet:

```text
MEDIATION
APPEALED
SUPERSEDED
```

## 8.2 Status-Bedeutung

### DRAFT

```text
Entwurf.
Noch nicht öffentlich.
Nur Ersteller oder berechtigte Rollen sehen ihn.
Kann lokal gelöscht werden, solange nie veröffentlicht.
```

### DISCUSSION

```text
Öffentliche Beratungsphase innerhalb der zuständigen Agora.
Proposal ist sichtbar.
Mitglieder können diskutieren.
Experten können Statements vorbereiten.
Noch keine Abstimmung.
```

### VOTING

```text
Abstimmungsphase.
Stimmen möglich.
Delegationen möglich.
Inhalt darf nicht mehr verändert werden.
```

### DECIDED

```text
Abstimmung abgeschlossen.
Ergebnis berechnet.
Decision Record erstellt.
```

### WITHDRAWN

```text
Proposal wurde zurückgezogen.
Bleibt sichtbar.
Grund wird gespeichert.
Audit-Trail bleibt erhalten.
```

### ARCHIVED

```text
Aus aktiven Listen entfernt.
Historisch weiterhin auffindbar.
```

### INVALID

```text
Proposal / Abstimmung ist ungültig.
Beispiele:
Quorum nicht erreicht.
Formale Regel verletzt.
Nur Enthaltungen.
Interzelluläre Aktivierung nicht erreicht.
```

## 8.3 Erlaubte Übergänge

```text
DRAFT → DISCUSSION
DISCUSSION → VOTING
DISCUSSION → WITHDRAWN
VOTING → DECIDED
VOTING → INVALID
VOTING → WITHDRAWN
DECIDED → ARCHIVED
INVALID → ARCHIVED
WITHDRAWN → ARCHIVED
```

Nicht erlaubt:

```text
DECIDED → VOTING
ARCHIVED → VOTING
WITHDRAWN → VOTING
```

## 8.4 Änderungen

```text
DRAFT:
frei bearbeitbar.

DISCUSSION:
bearbeitbar, aber versioniert.

VOTING:
nicht mehr bearbeitbar.
```

Wenn im Voting ein Fehler erkannt wird:

```text
Ersteller darf nicht selbst zurückziehen.
Ersteller kann Moderator/Admin kontaktieren.
Moderator/Admin entscheidet.
```

## 8.5 Withdraw im Voting

Während `VOTING` darf ein Proposal nur zurückgezogen oder invalidiert werden durch:

```text
Zell-Moderator
System-Admin
Superadmin / später Stewardship-Kreis
```

Pflichtfelder:

```text
withdrawnByDid
withdrawnByRole
withdrawReasonEnc
moderationDecisionNoteEnc
previousStatus
withdrawnAt
```

---

# 9. Voting-Modi

## 9.1 Grundsatz

G2 darf nicht nur Ja/Nein-Abstimmungen können. Beim Erstellen eines Proposals wird deshalb ein Abstimmungsmodus gewählt.

```text
votingMode:
- YES_NO_ABSTAIN
- SINGLE_CHOICE
- CANDIDATE_CHOICE
```

Später vorbereitbar, aber nicht Teil des G2 MVP:

```text
RANKED_CHOICE
MULTI_SELECT
CONSENT_BASED
SCORE_VOTING
```

## 9.2 Auswahl des Voting-Modus beim Erstellen

Beim Erstellen eines Proposals sieht der Ersteller sinngemäß:

```text
Welche Art von Abstimmung ist das?

1. Ja / Nein / Enthaltung
2. Auswahl zwischen mehreren Optionen
3. Kandidatenwahl / Personenwahl
```

Der gewählte Modus wird im Proposal gespeichert und darf nach Beginn der Voting-Phase nicht mehr geändert werden.

```text
In DRAFT: votingMode und Optionen frei bearbeitbar.
In DISCUSSION: Änderungen möglich, aber versioniert.
In VOTING: votingMode und Optionen eingefroren.
```

## 9.3 Modus YES_NO_ABSTAIN

Für klassische Sachentscheidungen:

```text
Sollen wir X tun?
- YES / Ja
- NO / Nein
- ABSTAIN / Enthaltung
```

Gültige Stimmarten:

```text
YES
NO
ABSTAIN
```

Deutsch in UI:

```text
Ja
Nein
Enthaltung
```

## 9.4 Modus SINGLE_CHOICE

Für Entscheidungen mit mehreren Optionen, ähnlich einer Umfrage.

Beispiele:

```text
Welchen Treffpunkt wählen wir?
- Option A
- Option B
- Option C
- Enthaltung
```

```text
Welche Lösung setzen wir um?
- Variante 1
- Variante 2
- Variante 3
- Enthaltung
```

Regeln im G2 MVP:

```text
- genau eine Option kann gewählt werden
- Enthaltung ist immer möglich
- Optionen werden beim Erstellen des Proposals angelegt
- Optionen sind ab VOTING eingefroren
- Gewinner ist die Option mit dem höchsten gültigen Gewicht
```

Anzahl Optionen:

```text
- Mindestanzahl: 2 Optionen
  (bei nur einer Option ist der Modus sinnlos —
   stattdessen YES_NO_ABSTAIN als Bestätigungs-Voting verwenden)
- Maximalanzahl: 10 Optionen im G2 MVP
  (bei mehr als 10 Optionen wird die UI unübersichtlich
   und Tally-Logik schwerer auditierbar; spätere Modi
   wie RANKED_CHOICE in G3 sind dafür besser geeignet)
```

Validierung beim Erstellen:

```text
DRAFT: weniger als 2 Optionen → Speichern erlaubt, aber kein Übergang zu DISCUSSION
VOTING-Start: weniger als 2 oder mehr als 10 ACTIVE Optionen → blockiert mit Fehlermeldung
```

Optionen besitzen eindeutige IDs:

```text
optionId
proposalId
label
shortDescription optional
sortOrder
```

Für sensible Optionen liegen Label/Beschreibung im verschlüsselten Payload.

## 9.5 Modus CANDIDATE_CHOICE

Für Personen- oder Rollenwahlen.

Beispiele:

```text
Wer soll Moderator werden?
- Anna
- Ben
- Clara
- Enthaltung
```

```text
Wer soll die Gemeinschaft im interzellulären Mandat vertreten?
- Person A
- Person B
- Person C
- Enthaltung
```

Regeln:

```text
- 1 Mensch = 1 Stimme
- keine Delegation
- kein Quadratic Voting
- keine AURA-Gewichtung
- keine transitive Macht
- Kandidaten müssen über DID referenziert werden
```

Kandidaten-Optionen enthalten zusätzlich:

```text
candidateDid
candidateDisplayName
candidateStatementEnc optional
candidateAcceptedAt optional
```

Empfehlung für G2 MVP:

```text
Ein Kandidat sollte die Kandidatur vor Beginn der Voting-Phase aktiv annehmen.
Wenn Kandidatur nicht angenommen wurde, zeigt die UI einen Warnhinweis oder blockiert den Voting-Start, je nach Proposal-Regel.
```

Anzahl Kandidaten:

```text
- Mindestanzahl: 2 Kandidaten
  (bei nur einem Kandidaten ist keine Wahl, sondern eine Bestätigung —
   stattdessen YES_NO_ABSTAIN-Bestätigungs-Voting verwenden:
   "Soll Person X die Rolle Y übernehmen? Ja / Nein / Enthaltung")
- Maximalanzahl: 20 Kandidaten im G2 MVP
  (bei mehr als 20 Kandidaten wird Tally und Tie-Detection
   praktisch problematisch; größere Personenwahlen sollten
   als zwei Phasen gestaltet werden — Vorrunde + Stichwahl)
```

Validierung beim Erstellen:

```text
DRAFT: weniger als 2 Kandidaten → Speichern erlaubt, aber kein Übergang zu DISCUSSION
VOTING-Start: weniger als 2 oder mehr als 20 ACTIVE Kandidaten → blockiert mit Fehlermeldung
VOTING-Start: weniger als 2 Kandidaten mit candidateAcceptedAt → blockiert mit Hinweis
```

## 9.5.1 Kandidatenrücktritt während VOTING

Ein Kandidat kann seine Kandidatur auch nach Beginn der Voting-Phase noch zurückziehen, z.B. wegen privater Umstände, Konflikt-Erkenntnis oder sonstiger Gründe.

Verhalten:

```text
- Status der Kandidaten-Option in proposal_options wird auf WITHDRAWN gesetzt
- candidateWithdrawnAt wird mit Zeitstempel gesetzt
- Bereits abgegebene Stimmen für diesen Kandidaten bleiben historisch erhalten
  (Audit-Log-Schutz, Transparenz, Wähler-Vertrauen)
- Stimmen werden weder gelöscht noch automatisch umverteilt
- UI markiert den Kandidaten klar als "zurückgezogen"
- Wähler können ihre Stimme bis votingEndsAt selbst ändern oder widerrufen
```

Auswirkung auf Tally:

```text
Stimmen für einen WITHDRAWN-Kandidaten zählen weiterhin:
- zur participationCount (für Quorum)
- ABER NICHT zur Sieg-Wertung (der Kandidat hat sich aus der Wahl genommen)
```

Wenn ein WITHDRAWN-Kandidat trotzdem die meisten Stimmen erhält:

```text
result = INVALID
resultReason = WINNER_WITHDRAWN
```

Dann wird ein Stichwahl-Proposal unter den verbleibenden ACTIVE-Kandidaten erstellt (siehe §9.12 Stichwahl-Workflow).

Wenn alle Kandidaten zurücktreten:

```text
result = INVALID
resultReason = ALL_CANDIDATES_WITHDRAWN
```

Dann muss ein vollständig neues Proposal mit neuen Kandidaten erstellt werden.

## 9.6 Teilnahme

Teilnahme bedeutet ausschließlich:

```text
gültige Stimme abgegeben
```

Bei YES_NO_ABSTAIN:

```text
YES / NO / ABSTAIN
```

Bei SINGLE_CHOICE:

```text
selectedOptionId gesetzt
oder ABSTAIN
```

Bei CANDIDATE_CHOICE:

```text
selectedOptionId mit candidateDid gesetzt
oder ABSTAIN
```

Nicht als Teilnahme zählen:

```text
Proposal geöffnet
Proposal gelesen
Diskussion gelesen
keine Stimme abgegeben
ungültige Delegation
Delegation an Person ohne gültige Stimme
```

## 9.7 Widerruf

Wenn ein Nutzer seine Stimme widerruft:

```text
voteStatus = REVOKED
Stimme zählt nicht mehr
Stimme zählt nicht zum Quorum
```

## 9.8 Änderbarkeit

Bis `votingEndsAt` darf ein Nutzer:

```text
Stimme ändern
Stimme widerrufen
Delegation setzen, wenn Proposal delegierbar ist
Delegation widerrufen
von Delegation zu Direktvote wechseln
```

Nach `votingEndsAt`:

```text
keine Änderungen mehr möglich
```

## 9.9 Votingdauer

```text
Minimum: 48 Stunden
Maximum: 30 Tage
Default: 7 Tage
einstellbar vom Ersteller
```

Wenn der Ersteller weniger als 7 Tage wählt:

```text
UI-Hinweis:
„Kurze Abstimmungsdauer kann die Beteiligung verringern. Mindestdauer ist 48 Stunden."
```

Ausnahme Superadmin-Abwahl:

```text
Minimum: 7 Tage
Maximum: 30 Tage
Default: 14 Tage
```

## 9.10 Early Close

```text
Kein Early Close im G2 MVP.
```

Abstimmungen enden nie vorzeitig, auch wenn das Ergebnis klar erscheint.

## 9.11 Sichtbarkeit der Stimmen

Innerhalb der Gemeinschaft:

```text
pseudonym sichtbar
```

Außerhalb der Gemeinschaft / global:

```text
nur aggregierte Ergebnisse
```

## 9.12 Tally je Voting-Modus

Die Tally Engine verzweigt nach `votingMode`.

### YES_NO_ABSTAIN

```text
YES > NO → ACCEPTED
NO >= YES → REJECTED
ABSTAIN zählt zum Quorum, nicht zur YES/NO-Mehrheit
```

### SINGLE_CHOICE

```text
Option mit höchstem gültigem Gewicht gewinnt.
ABSTAIN zählt zum Quorum, aber nicht für eine Option.
```

Klärung zu Gleichständen:

```text
Im G2 MVP ist nur der Sieger (Platz 1) entscheidungsrelevant.
Gleichstände auf Platz 2 oder tiefer haben keine Auswirkung auf das Ergebnis,
solange Platz 1 eindeutig ist.
Der Decision Record speichert ausschließlich die Gewinner-Option
(oder INVALID bei Top-Tie auf Platz 1).
```

Wenn zwei oder mehr Optionen gleichauf auf Platz 1 liegen:

```text
result = INVALID
resultReason = TIE_REQUIRES_RUNOFF
tieOptionIdsJson = IDs der gleichauf liegenden Optionen
```

Dann wird ein Stichwahl-Proposal angelegt (siehe §9.12.1).

### CANDIDATE_CHOICE

```text
Kandidat/Option mit den meisten gültigen Stimmen gewinnt.
ABSTAIN zählt zum Quorum, aber nicht für einen Kandidaten.
Stimmen für WITHDRAWN-Kandidaten zählen zum Quorum,
aber nicht zur Sieger-Wertung (siehe §9.5.1).
Keine Delegation.
Kein QV.
```

Klärung zu Gleichständen:

```text
Wie bei SINGLE_CHOICE: nur Platz 1 ist entscheidungsrelevant.
Ties auf Plätzen 2+ haben keine Auswirkung.
```

Bei Top-Gleichstand auf Platz 1:

```text
result = INVALID
resultReason = TIE_REQUIRES_RUNOFF
tieOptionIdsJson = IDs der gleichauf liegenden Kandidaten
```

Bei Sieg eines zurückgetretenen Kandidaten (siehe §9.5.1):

```text
result = INVALID
resultReason = WINNER_WITHDRAWN
```

In beiden Fällen wird ein Stichwahl-Proposal angelegt (siehe §9.12.1).

## 9.12.1 Stichwahl-Workflow

Wenn ein Proposal-Ergebnis INVALID wird mit `resultReason ∈ { TIE_REQUIRES_RUNOFF, WINNER_WITHDRAWN }`, wird ein Folge-Proposal als Stichwahl angelegt.

Initiierung:

```text
- System erstellt automatisch ein neues Proposal im Status DRAFT
- creatorDid = creatorDid des Original-Proposals
- previousProposalId zeigt auf das Original-Proposal
- Zell-Admin oder Original-Ersteller veröffentlicht das Stichwahl-Proposal
  in DISCUSSION (oder DIREKT in VOTING bei sehr klaren Fällen,
  per Zell-Regel konfigurierbar)
```

Stichwahl-Inhalt:

```text
- votingMode bleibt identisch zum Original (SINGLE_CHOICE oder CANDIDATE_CHOICE)
- proposalType bleibt identisch zum Original
- proposalScope bleibt identisch zum Original
- Optionen / Kandidaten:
    bei TIE_REQUIRES_RUNOFF: nur die im Tie befindlichen Optionen
    bei WINNER_WITHDRAWN: alle ACTIVE-Kandidaten ohne den
    zurückgetretenen Sieger
```

Stichwahl-Quoren:

```text
- quorumRule identisch zum Original-Proposal
- majorityRule identisch zum Original-Proposal
- Begründung: Eine Stichwahl darf nicht weniger demokratische
  Legitimität haben als die Originalwahl
```

Stichwahl-Votingdauer:

```text
- Default: halbe Originaldauer
  (z.B. Original 7 Tage → Stichwahl 3-4 Tage)
- Aber weiterhin innerhalb der globalen Grenzen aus §9.9:
    Minimum 48 Stunden, Maximum 30 Tage
- Einstellbar vom Stichwahl-Ersteller
- Bei Ausnahme Superadmin-Abwahl: Stichwahl-Default = 7 Tage
  (halbe von 14 Tagen)
```

Decision Record der Stichwahl:

```text
resultRelation = "RUNOFF_OF"
previousProposalId = ID des Original-Proposals
```

Verkettung mehrerer Stichwahlen:

```text
Wenn auch die Stichwahl in einem Tie endet, wird wiederum
eine Stichwahl angelegt mit:
  previousProposalId = ID der ersten Stichwahl
  resultRelation = "RUNOFF_OF"

Es gibt keine harte Begrenzung auf maximale Stichwahl-Tiefe,
aber im G2 MVP wird eine Empfehlung im UI angezeigt
nach 2 aufeinanderfolgenden Tied-Stichwahlen
("Erwägt eine Pause oder eine Diskussionsrunde").
```

## 9.13 QV bei mehreren Optionen

Für G2 MVP gilt:

```text
YES_NO_ABSTAIN:
QV erlaubt bei GENERAL und RESOURCE.

SINGLE_CHOICE:
QV optional erlaubt bei GENERAL und RESOURCE, wenn usesQuadraticVoting = true.
Der Nutzer gewichtet nur seine selbst gewählte Option.

CANDIDATE_CHOICE:
QV immer verboten.
```

Bei SINGLE_CHOICE + QV:

```text
qvVoteWeight = gewähltes Gewicht
voiceCreditsSpent = qvVoteWeight²
voteWeight = qvVoteWeight
```

Delegierte Stimmen bei QV bleiben gemäß v1.1 entschärft:

```text
Die eigene Stimme des Delegierten kann QV-Gewicht haben.
Delegierte Stimmen zählen im G2 MVP immer mit Gewicht 1.
```

## 9.14 Datenregel für Vote

Ein Vote kann je nach Modus enthalten:

```text
voteType: YES | NO | ABSTAIN | OPTION
selectedOptionId nullable
```

Regeln:

```text
YES_NO_ABSTAIN:
selectedOptionId = null
voteType = YES | NO | ABSTAIN

SINGLE_CHOICE:
voteType = OPTION
selectedOptionId = gewählte Option
oder voteType = ABSTAIN

CANDIDATE_CHOICE:
voteType = OPTION
selectedOptionId = Kandidaten-Option
oder voteType = ABSTAIN
```

# 10. Delegation

## 10.1 Grundsatz

```text
Delegation ist nur pro Proposal möglich.
Delegation ist nur zellintern möglich.
Delegation ist nicht transitiv.
Delegation ist jederzeit bis Voting-Ende widerrufbar.
Direktvote überschreibt Delegation.
```

## 10.2 Wer darf delegieren?

Ein Mitglied darf delegieren, wenn:

```text
es stimmberechtigtes Zellmitglied ist
Proposal im Status VOTING ist
Votingfrist läuft
Proposal delegierbar ist
Delegierter gültig ist
Delegierter Delegationen für dieses Proposal annimmt
```

## 10.3 Wer darf Delegationen empfangen?

Eine Person darf Delegationen empfangen, wenn:

```text
sie Mitglied derselben Zelle ist
sie als Experte / Delegationsperson sichtbar ist
sie Delegationen aktiv annimmt
sie ein Statement zum Proposal abgegeben hat
sie sich verpflichtet hat abzustimmen
Delegationslimit nicht erreicht ist
```

## 10.4 Keine transitive Delegation

Beispiel:

```text
Anna delegiert an Ben.
Ben delegiert an Clara.
```

Dann gilt:

```text
Annas Stimme folgt nicht Clara.
```

Regel:

```text
Wer Delegationen empfangen hat, darf für dasselbe Proposal nicht weiterdelegieren.
```

## 10.5 Direktvote überschreibt Delegation

Wenn ein Nutzer delegiert hat und später selbst abstimmt:

```text
Delegation wird deaktiviert.
Direkte Stimme zählt.
```

Audit:

```text
DELEGATION_REVOKED_BY_DIRECT_VOTE
VOTE_CAST
```

## 10.6 Delegierter stimmt nicht ab

Wenn der Delegierte bis Ende der Frist nicht abstimmt:

```text
Delegationen verfallen
zählen nicht zum Quorum
zählen nicht zum Ergebnis
Warnhinweis im Expertenprofil
```

## 10.7 Delegierter muss nicht jede Delegation einzeln annehmen

Festgelegt:

```text
Option A
```

Das bedeutet:

```text
Experte öffnet Delegation pro Proposal.
Einzelne Delegationen brauchen keine separate Annahme.
```

## 10.8 Delegationslimit

Delegationslimit ist konfigurierbar pro Zelle.

```text
Default: 20
Minimum: 5
Maximum: 150
```

Zusätzlich Anti-Oligarchie-Cap:

```text
Eine Person darf maximal 30 % der stimmberechtigten Zellmitglieder als Delegationen für ein Proposal bündeln.
```

Tatsächliches Limit:

```text
min(maxDelegationsPerProposal, 30 % der stimmberechtigten Zellmitglieder)
```

## 10.9 Nicht delegierbare Proposal-Typen

Nicht delegierbar:

```text
ROLE_CHANGE
RULE_CHANGE
SUPERADMIN_RECALL
MEMBER_EXCLUSION
PERSONAL_SANCTION
CONSTITUTIONAL
HARD_CAP_CHANGE
QUORUM_CHANGE
DELEGATION_RULE_CHANGE
```

Delegierbar:

```text
GENERAL
RESOURCE
TECHNICAL
ORGANIZATIONAL
```

---

# 11. Expertenprofile und AURA

## 11.1 Grundsatz

```text
Experten sind freiwillig sichtbare Delegationspersonen.
```

Niemand wird automatisch Experte.

## 11.2 Aktivierung

Nutzer muss aktiv einschalten:

```text
availableForDelegation = true
```

Optional:

```text
expertiseDomains auswählen
Bio hinzufügen
```

## 11.3 Expertenprofil

Pflichtfelder:

```text
expertProfileId
did
displayName
bioEnc
expertiseDomains[]
cellMemberships[]
auraScore
auraMaxScore
auraByDomainJson
activeDelegationsTotal
activeDelegationsPerProposal
maxDelegationsPerProposal
delegationAcceptanceMode
acceptsMessages
lastActiveAt
createdAt
updatedAt
```

## 11.4 AURA

Anzeige:

```text
AURA: 8.420 / 10.000
```

Domänenspezifisch optional:

```text
AURA Gesundheit: 9.100
AURA Technik: 3.200
AURA Bildung: 5.700
```

## 11.5 Rolle von AURA im G2 MVP

```text
AURA ist ein Vertrauens- und Kompetenzsignal.
AURA beeinflusst im G2 MVP NICHT direkt das Stimmgewicht.
```

AURA dient:

```text
Orientierung bei Expertenwahl
Vertrauensanzeige
Sybil-Resistenz indirekt
```

AURA darf nicht:

```text
bei Superadmin-Abwahl zählen
bei Grundrechten zählen
bei Rollenentscheidungen automatisch zählen
käuflich sein
übertragbar sein
delegierbar sein
```

## 11.6 Visuelle Darstellung

AURA darf visuell hervorgehoben werden:

```text
Farbskala
Bronze / Silber / Gold
Punktewert
```

Aber:

```text
rein visuell, keine Zusatzmacht
```

## 11.7 Experten-Statement

Ein Experte kann Delegationen nur annehmen, wenn ein Statement zum Proposal existiert.

```text
statementId
proposalId
expertDid
position: YES | NO | ABSTAIN | UNDECIDED
shortReason
encLongReason nullable
createdAt
updatedAt
signature
```

Regeln:

```text
ohne Statement keine Delegation
Statement darf geändert werden
alte Version bleibt im Audit-Log
Delegierende werden bei Änderung informiert
```

## 11.8 Sortierung und Empfehlung

```text
Kein Empfehlungssystem im MVP.
Keine versteckte algorithmische Priorisierung.
```

User-gesteuerte Sortierung:

```text
AURA
Delegationen
Fachgebiet
Aktivität
alphabetisch
```

---

# 12. Quadratic Voting

## 12.1 Grundsatz

Quadratic Voting ist nur für bestimmte Proposal-Typen erlaubt.

Erlaubt:

```text
GENERAL
RESOURCE
```

Nicht erlaubt:

```text
ROLE_CHANGE
RULE_CHANGE
SUPERADMIN_RECALL
MEMBER_EXCLUSION
PERSONAL_SANCTION
CONSTITUTIONAL
HARD_CAP_CHANGE
```

## 12.2 Voice Credits

```text
100 Voice Credits pro Kalenderquartal pro Gemeinschaft/Zelle
quarterId-Format: YYYY-Q1, YYYY-Q2, YYYY-Q3, YYYY-Q4
Zeitzone: UTC
kein Übertrag ins nächste Quartal
nicht übertragbar zwischen Gemeinschaften/Zellen
nicht übertragbar auf andere Personen
nicht käuflich
```

Neue Mitglieder erhalten Voice Credits anteilig für das laufende Quartal. QV-Gewichte über 1 werden erst nach einer Membership-Maturity-Frist aktiv.

```text
Default Membership-Maturity: 14 Tage
```

Die Gemeinschaft kann erlauben, dass neue Mitglieder vor Ablauf der 14 Tage bereits mit Gewicht 1 abstimmen. QV-Gewicht > 1 bleibt vor Ablauf der Frist gesperrt.

## 12.3 Kostenformel

```text
Kosten = Stimmengewicht²
```

Beispiele:

```text
1 Stimme = 1 Credit
2 Stimmen = 4 Credits
3 Stimmen = 9 Credits
5 Stimmen = 25 Credits
10 Stimmen = 100 Credits
```

## 12.4 UI-Regel

```text
Die UI verhindert, dass mehr Credits ausgegeben werden als verfügbar.
```

Keine automatische Reduktion.

## 12.5 Delegation + QV

Regel für G2 MVP:

```text
Die eigene Stimme des Delegierten kann QV-Gewicht haben.
Delegierte Stimmen zählen immer mit Gewicht 1.
```

Beispiel:

```text
Delegierter stimmt YES mit QV-Gewicht 3.
5 Menschen delegieren an ihn.

Gesamtgewicht YES:
Eigene Stimme des Delegierten = 3
Delegierte Stimmen = 5 × 1
Gesamt = 8
```

Begründung:

```text
QV drückt die eigene Priorität einer Person aus.
Delegierende haben keine eigenen Voice Credits ausgegeben.
Deshalb darf Delegation das QV-Gewicht des Delegierten nicht multiplizieren.
```

---

# 13. Quoren und Entscheidungsregeln

## 13.1 Grundsatz

Eine Entscheidung braucht:

```text
ausreichende Beteiligung = Quorum
ausreichende Zustimmung = Mehrheit
```

Wenn Quorum nicht erreicht:

```text
result = INVALID
```

Wenn Quorum erreicht, aber Mehrheit fehlt:

```text
result = REJECTED
```

## 13.2 Regeln nach Proposal-Typ

### GENERAL

```text
Quorum: 20 %
Mehrheit: einfache Mehrheit
Delegation: ja
QV: ja
```

### RESOURCE

```text
Quorum: abhängig vom resourceImpactLevel
Mehrheit: abhängig vom resourceImpactLevel
Delegation: ja
QV: ja
```

RESOURCE-Stufen:

```text
LOW:
Quorum 30 %
Mehrheit einfache Mehrheit

MEDIUM:
Quorum 40 %
Mehrheit 60 %

HIGH:
Quorum 50 %
Mehrheit 2/3
```

### ROLE_CHANGE

```text
Quorum: 40 %
Mehrheit: 60 %
Delegation: nein
QV: nein
```

### RULE_CHANGE

```text
Quorum: 50 %
Mehrheit: 2/3
Delegation: nein
QV: nein
```

### INTERCELL

```text
Aktivierung: prozentual nach eingeladenen Zellen
Entscheidung: 1 Zelle = 1 Stimme
Mehrheit: einfache Mehrheit der teilnehmenden Zellen
```

### SUPERADMIN_RECALL

```text
Quorum: 2/3 der Stimmberechtigten
Mehrheit: 2/3 YES-Stimmen
Delegation: nein
QV: nein
```

## 13.3 Enthaltungen

```text
Enthaltungen zählen zum Quorum.
Enthaltungen zählen nicht zu YES/NO.
```

## 13.4 Gleichstand

```text
YES == NO → REJECTED
```

Grund:

```text
Veränderung braucht klare Zustimmung.
```

## 13.5 Kleine Zellen

Für Zellen unter 10 stimmberechtigten Mitgliedern gilt zusätzlich:

```text
GENERAL / RESOURCE:
mindestens 3 gültige Teilnehmer

ROLE_CHANGE / RULE_CHANGE:
mindestens 5 gültige Teilnehmer, sofern möglich
```

Wenn die Zelle weniger Mitglieder hat:

```text
alle stimmberechtigten Mitglieder müssen benachrichtigt worden sein
mindestens 60 % müssen teilnehmen
```

---

# 14. Interzelluläre Entscheidungen

## 14.1 Grundsatz

```text
Interzelluläre Entscheidungen betreffen mehrere Zellen.
Im G2 MVP gilt: 1 Zelle = 1 Stimme.
```

## 14.2 Startberechtigung

Interzelluläre Proposals dürfen starten:

```text
Zell-Founder
Zell-Moderator
System-Admin
Superadmin / später Stewardship-Kreis
```

Später optional:

```text
Mitglied mit Zellmandat
```

## 14.3 Struktur

```text
proposalId
proposalScope = INTERCELL
initiatingCellId
targetCellIds[]
proposalType
title
summary
detailsEnc
createdBy
createdAt
invitedExpertDids[] optional
```

## 14.4 Phase 1: Einladung

Ablauf:

```text
Initiierende Zelle erstellt Proposal.
Zielzellen erhalten Einladung.
Jede Zielzelle entscheidet intern über Teilnahme.
```

## 14.5 Phase 2: Aktivierung

Aktivierung:

```text
acceptedCells / invitedCells >= activationThresholdPercent
```

Default:

```text
50 %
```

Nach Typ:

```text
GENERAL: 50 %
RESOURCE: 60 %
RULE_CHANGE: 66 %
SANCTION: 75 %
```

## 14.6 Phase 3: Zellinterne Meinungsbildung

Jede teilnehmende Zelle führt intern ein normales G2-Voting durch.

Ergebnis pro Zelle:

```text
YES
NO
ABSTAIN
```

## 14.7 Zellmandat

Nach Abschluss erzeugt jede Zelle ein Mandat.

```text
mandateId
proposalId
cellId
position: YES | NO | ABSTAIN
delegateDid
voteResultHash
encMandateText
createdAt
updatedAt
signature
```

## 14.8 Delegierter

Der Delegierte:

```text
vertritt die Entscheidung der Zelle
darf nicht frei entscheiden
ist an das Mandat gebunden
```

Formel:

```text
Delegierter = Übermittler, nicht Entscheider
```

## 14.9 Interzelluläre Auswertung

```text
YES = Anzahl Zellen mit YES
NO = Anzahl Zellen mit NO
ABSTAIN = Anzahl Zellen mit ABSTAIN
```

Entscheidung:

```text
YES-Zellen > NO-Zellen → ACCEPTED
NO-Zellen >= YES-Zellen → REJECTED
```

---

# 15. Externe Experten

## 15.1 Grundsatz

Zellen können externe Experten einladen.

Modi:

```text
ADVISOR_ONLY
DELEGATION_ALLOWED
```

Default:

```text
ADVISOR_ONLY
```

## 15.2 Rechte externer Experten

Externe Experten dürfen:

```text
Proposal lesen, soweit freigegeben
Statement abgeben
in Diskussion antworten
angeschrieben werden
als Berater sichtbar sein
```

Externe Experten dürfen nur Stimmen erhalten, wenn:

```text
Zelle ausdrücklich EXTERNAL_DELEGATION_ALLOWED aktiviert
```

---

# 16. Superadmin-Abwahl und Stewardship-Übergang

## 16.1 Grundsatz

```text
Keine Macht ist dauerhaft.
Auch die höchste Rolle muss friedlich abwählbar sein.
```

## 16.2 Proposal

```text
proposalType = SUPERADMIN_RECALL
proposalScope = SYSTEM
```

## 16.3 Startberechtigung

```text
System-Admins
Zell-Founder aktiver Zellen
```

## 16.4 Pflichtinhalt

```text
title
reasonEnc
evidenceRefs optional
createdBy
createdAt
transitionDurationDays
```

## 16.5 Cooldown

Nach gescheitertem Recall:

```text
90 Tage kein neuer Recall
```

## 16.6 Voting-Regeln

```text
1 Mensch = 1 Stimme
keine Delegation
kein QV
YES = Abwahl
NO = Beibehalten
ABSTAIN = Enthaltung
```

## 16.7 Quorum und Mehrheit

```text
Quorum: 2/3 der Stimmberechtigten
Mehrheit: 2/3 YES-Stimmen
```

## 16.8 Votingdauer

```text
Minimum: 7 Tage
Maximum: 30 Tage
```

## 16.9 Übergangsphase

Nach erfolgreicher Abwahl:

```text
RECALL_ACCEPTED
```

Der Proposal-Ersteller schlägt die Übergabedauer vor.

Systemgrenzen:

```text
Minimum: 1 Tag
Maximum: 14 Tage
Default: 3 Tage
```

Die gewählte Dauer ist Teil des Proposals und wird durch die Abstimmung mitbestätigt.

## 16.10 Übergangsrolle

```text
role = SUPERADMIN_TRANSITION
permissions = LIMITED
expiresAt = decidedAt + transitionDurationDays
```

Der abgewählte Superadmin darf:

```text
Systeme dokumentieren
Wissen übergeben
technische Übergaben begleiten
```

Der abgewählte Superadmin darf nicht:

```text
Governance ändern
Rollen vergeben
Systemzugriffe erweitern
neue Proposals mit Sonderrechten starten
kritische Systementscheidungen treffen
```

Nach Ablauf:

```text
role = REMOVED
```

## 16.11 Stewardship-Kreis

Nach erfolgreicher Abwahl entsteht:

```text
SYSTEM_STEWARD_COUNCIL
```

MVP:

```text
3 bis 7 Personen
aus System-Admins und Zell-Foundern
```

Entscheidungsregel:

```text
Multisig-Prinzip, z. B. 3 von 5
```

Aufgabe:

```text
System stabil halten
Übergang begleiten
neues Stewardship-Modell vorbereiten
```

Innerhalb von 30 Tagen:

```text
neues Stewardship-Modell per Proposal bestätigen
```

---

# 17. Tally Engine

## 17.1 Grundsatz

```text
Gleiche Inputs → immer gleiches Ergebnis.
```

Die Tally Engine ist deterministisch.

## 17.2 Inputs

```text
proposal
validVotes[]
validDelegations[]
voiceCreditsLedger
eligibleVoters
proposalRules
```

## 17.3 Gültige Stimme

Eine Stimme ist gültig, wenn:

```text
vote.status == ACTIVE
proposal.status war VOTING zum Zeitpunkt der Abgabe
votingStartsAt <= vote.createdAt <= votingEndsAt
voter ist stimmberechtigtes Zellmitglied
vote nicht widerrufen
```

## 17.4 Direkte Stimmen zuerst

```text
Direkte Stimme überschreibt Delegation.
```

## 17.5 Gültige Delegation

Eine Delegation ist gültig, wenn:

```text
delegation.status == ACTIVE
delegator hat keine direkte Stimme
delegate hat gültige Stimme
delegate hat Statement abgegeben
Delegationslimit nicht überschritten
```

## 17.6 Zählung

Die Zählung verzweigt nach `votingMode` des Proposals.

### YES_NO_ABSTAIN

Initial:

```text
yesWeight = 0
noWeight = 0
abstainWeight = 0
participationCount = 0
```

Direkte Stimme:

```text
YES → yesWeight += weight
NO → noWeight += weight
ABSTAIN → abstainWeight += weight
participationCount += 1
```

Delegation:

```text
übernimmt die Auswahl / Position des Delegierten
bei normalem Voting: voteWeight = 1
bei QV-Proposals: delegierte Stimme zählt Gewicht 1
participationCount += 1 nur für gültige erfolgreiche Delegationen
```

### SINGLE_CHOICE

Initial:

```text
optionWeights = Map<optionId, double>   // alle Optionen starten mit 0
abstainWeight = 0
participationCount = 0
```

Direkte Stimme:

```text
voteType = OPTION:
  optionWeights[selectedOptionId] += weight
  participationCount += 1

voteType = ABSTAIN:
  abstainWeight += weight
  participationCount += 1
```

Delegation (wenn Proposal delegierbar):

```text
übernimmt selectedOptionId / voteType des Delegierten
voteWeight = 1 (gemäß v1.1: delegierte Stimmen zählen Gewicht 1)
bei QV-Proposals: delegierte Stimme zählt Gewicht 1
participationCount += 1 nur für gültige erfolgreiche Delegationen
```

### CANDIDATE_CHOICE

Initial:

```text
optionWeights = Map<optionId, int>   // alle Kandidaten-Optionen starten mit 0
abstainWeight = 0
participationCount = 0
```

Direkte Stimme:

```text
voteType = OPTION:
  optionWeights[selectedOptionId] += 1
  // 1 Mensch = 1 Stimme, kein QV-Multiplier
  participationCount += 1

voteType = ABSTAIN:
  abstainWeight += 1
  participationCount += 1
```

Keine Delegation, kein QV (per §9.5).

Stimmen für WITHDRAWN-Kandidaten:

```text
- werden in optionWeights weiterhin gezählt (historisch korrekt)
- werden in der Sieger-Auswahl ABER ausgeschlossen (§9.5.1)
- zählen weiterhin zur participationCount für Quorum
```

## 17.7 QV

Wenn erlaubt:

```text
weight = gewählte Stimmenanzahl
cost = weight²
```

## 17.8 Quorum

```text
participationRate = participationCount / eligibleVoters
```

Wenn:

```text
participationRate < quorumThreshold
```

Dann:

```text
result = INVALID
```

## 17.9 Mehrheit

```text
totalDecisionWeight = yesWeight + noWeight
```

Enthaltungen werden nicht in YES/NO-Mehrheit gerechnet.

Einfache Mehrheit:

```text
YES > NO → ACCEPTED
NO >= YES → REJECTED
```

Qualifizierte Mehrheit:

```text
YES / (YES + NO) >= threshold → ACCEPTED
sonst REJECTED
```

## 17.10 Tally nach Voting-Modus

### YES_NO_ABSTAIN

```text
yesWeight, noWeight und abstainWeight werden berechnet.
ABSTAIN zählt zur participationCount, aber nicht zur YES/NO-Mehrheit.
```

### SINGLE_CHOICE

```text
Für jede Option wird optionWeight berechnet.
ABSTAIN zählt zur participationCount, aber nicht zu einer Option.
Gewinner = Option mit höchstem optionWeight.
```

Bei Gleichstand der führenden Optionen:

```text
result = INVALID
resultReason = TIE_REQUIRES_RUNOFF
tieOptionIdsJson = IDs der gleichauf liegenden Optionen
```

### CANDIDATE_CHOICE

```text
Wie SINGLE_CHOICE, aber jede Option referenziert einen Kandidaten-DID.
Keine Delegation.
Kein QV.
1 Mensch = 1 Stimme.
```

Bei Gleichstand:

```text
result = INVALID
resultReason = TIE_REQUIRES_RUNOFF
```

## 17.11 Sonderfälle

```text
keine Stimmen → INVALID
nur Enthaltungen → INVALID
Delegierter stimmt nicht → Delegationen verfallen
```

Hinweis zu Gleichstand:

```text
Bei YES_NO_ABSTAIN gilt §17.9 (NO >= YES → REJECTED).
Bei SINGLE_CHOICE und CANDIDATE_CHOICE gilt §17.10
(Top-Tie auf Platz 1 → INVALID + RUNOFF).
Es gibt damit kein generisches "Gleichstand → REJECTED" mehr;
das Verhalten hängt vom votingMode ab.
```

## 17.12 Decision Record

```text
decisionId
proposalId
result: ACCEPTED | REJECTED | INVALID
yesWeight
noWeight
abstainWeight
optionResultsJson nullable
selectedOptionId nullable
winningOptionLabelEnc nullable
tieOptionIdsJson nullable
resultReason nullable
participationCount
eligibleVoters
participationRate
quorumReached
majorityRuleUsed
calculatedAt
inputHash
resultHash
signature
```

---

# 18. Audit-Log

## 18.1 Grundsatz

```text
Audit-Log ist append-only.
Keine Updates.
Keine Deletes.
```

## 18.2 Pflicht-Events

```text
PROPOSAL_CREATED
PROPOSAL_PUBLISHED
PROPOSAL_UPDATED
PROPOSAL_STATUS_CHANGED
DISCUSSION_STARTED
VOTING_STARTED
VOTE_CAST
VOTE_CHANGED
VOTE_REVOKED
DELEGATION_CREATED
DELEGATION_REVOKED
DELEGATION_REVOKED_BY_DIRECT_VOTE
DELEGATE_STATEMENT_CREATED
DELEGATE_STATEMENT_UPDATED
DELEGATE_FAILED_TO_VOTE
PROPOSAL_WITHDRAWN
TALLY_STARTED
TALLY_COMPLETED
DECISION_RECORD_CREATED
PROPOSAL_ARCHIVED
PROPOSAL_INVALIDATED
```

Interzellulär zusätzlich:

```text
INTERCELL_PROPOSAL_CREATED
CELL_INVITED
CELL_ACCEPTED
CELL_DECLINED
INTERCELL_ACTIVATED
CELL_VOTE_COMPLETED
CELL_MANDATE_CREATED
INTERCELL_RESULT_CALCULATED
INTERCELL_DECISION_FINALIZED
```

Superadmin zusätzlich:

```text
SUPERADMIN_RECALL_CREATED
SUPERADMIN_RECALL_VOTING_STARTED
SUPERADMIN_RECALL_VOTE_CAST
SUPERADMIN_RECALL_RESULT
SUPERADMIN_TRANSITION_STARTED
SUPERADMIN_REMOVED
STEWARD_COUNCIL_CREATED
STEWARD_ACTION
```

---

# 19. Datenschutz- und Transparenzmodell

## 19.1 Grundsatz

```text
Alles, was für Tally nötig ist, muss auditierbar sein.
Alles Persönliche oder Sensible muss verschlüsselt sein.
```

## 19.2 Klartext-Indexfelder

Dürfen klar in SQLite liegen:

```text
proposalId
cellId
proposalScope
proposalType
votingMode
status
createdByDid
createdAt
updatedAt
votingStartsAt
votingEndsAt
quorumRule
majorityRule
isDelegable
usesQuadraticVoting
contentHash
nostrEventId
syncStatus
```

## 19.3 Verschlüsselte Payloads

In `encPayload` gehören:

```text
proposalTitle
proposalSummary
proposalDetails
withdrawReason
moderationNotes
voteReason
delegationReason
expertStatementLongReason
cellMandateText
privateDiscussionRefs
attachmentsMetadata
```

## 19.4 Hashes

```text
contentHash
voteHash
delegationHash
statementHash
mandateHash
inputHash
resultHash
eventHash
previousHash
```

---

# 20. Datenmodell

## 20.1 proposals

```text
proposalId
cellId
proposalScope
proposalType
votingMode: YES_NO_ABSTAIN | SINGLE_CHOICE | CANDIDATE_CHOICE
            DEFAULT YES_NO_ABSTAIN für Migration und Altbestand
status
createdByDid
createdAt
updatedAt
publishedAt
discussionStartsAt
votingStartsAt
votingEndsAt
decidedAt
archivedAt
isDelegable
usesQuadraticVoting
quorumRule
majorityRule
ruleSnapshotJson nullable
encPayload
contentHash
previousProposalId nullable
nostrEventId nullable
syncStatus
```

Migrationsregel für Altbestand:

```text
Beim Schema-Upgrade auf v2.x (votingMode-Einführung) wird
für alle existierenden proposals automatisch gesetzt:
  votingMode = 'YES_NO_ABSTAIN'

Das ist semantisch korrekt, weil v1.x-Proposals ausschließlich
YES_NO_ABSTAIN-Voting kannten.
```

## 20.2 proposal_options

Für SINGLE_CHOICE und CANDIDATE_CHOICE.

```text
optionId
proposalId
optionType: TEXT | CANDIDATE
sortOrder
labelEnc
descriptionEnc nullable
candidateDid nullable
candidateDisplayNameEnc nullable
candidateStatementEnc nullable
candidateAcceptedAt nullable
status: ACTIVE | WITHDRAWN | INVALID
createdAt
updatedAt
optionHash
```

Regeln:

```text
In DRAFT frei bearbeitbar.
In DISCUSSION nur versioniert änderbar.
In VOTING eingefroren.
Withdrawn/invalid Optionen bleiben auditierbar.
```

## 20.3 votes

```text
voteId
proposalId
cellId
voterDid
voteType: YES | NO | ABSTAIN | OPTION
selectedOptionId nullable
voteWeight
qvVoteWeight nullable
voiceCreditsSpent
status: ACTIVE | REVOKED | SUPERSEDED
createdAt
updatedAt
revokedAt nullable
encReason nullable
voteHash
signature
nostrEventId nullable
syncStatus
```

Validierungsregeln:

```text
votingMode = YES_NO_ABSTAIN:
  voteType ∈ { YES, NO, ABSTAIN }
  selectedOptionId = NULL

votingMode = SINGLE_CHOICE:
  voteType = OPTION → selectedOptionId muss eine ACTIVE Option des Proposals sein
  voteType = ABSTAIN → selectedOptionId = NULL

votingMode = CANDIDATE_CHOICE:
  voteType = OPTION → selectedOptionId muss eine ACTIVE oder WITHDRAWN
                       Kandidaten-Option des Proposals sein
                       (WITHDRAWN-Stimme bleibt für Audit erhalten,
                        zählt aber nicht zur Sieger-Wertung)
  voteType = ABSTAIN → selectedOptionId = NULL
```

## 20.4 delegations

```text
delegationId
proposalId
cellId
delegatorDid
delegateDid
status: ACTIVE | REVOKED | SUPERSEDED | EXPIRED | INVALID
createdAt
updatedAt
revokedAt nullable
delegateStatementId
encReason nullable
delegationHash
signature
nostrEventId nullable
syncStatus
```

## 20.5 expert_profiles

```text
expertProfileId
did
displayName
expertiseDomainsJson
auraScore
auraMaxScore
auraByDomainJson
availableForDelegation
delegationAcceptanceMode
acceptsMessages
activeDelegationsTotal
createdAt
updatedAt
encBio
profileHash
nostrEventId nullable
syncStatus
```

## 20.6 expert_statements

```text
statementId
proposalId
expertDid
position: YES | NO | ABSTAIN | UNDECIDED
shortReason
encLongReason nullable
createdAt
updatedAt
isCurrent
statementHash
signature
nostrEventId nullable
syncStatus
```

## 20.7 voice_credits_ledger

```text
ledgerId
did
cellId
quarterId
creditsGranted
creditsSpent
creditsRemaining
createdAt
updatedAt
ledgerHash
```

## 20.8 decision_records

```text
decisionId
proposalId
cellId nullable
proposalScope
result: ACCEPTED | REJECTED | INVALID
yesWeight
noWeight
abstainWeight
optionResultsJson nullable
selectedOptionId nullable
winningOptionLabelEnc nullable
tieOptionIdsJson nullable
resultReason nullable
resultRelation: NULL | RUNOFF_OF | REPLACEMENT_OF
previousProposalId nullable
participationCount
eligibleVoters
participationRate
quorumReached
majorityRuleUsed
calculatedAt
inputHash
resultHash
signature
nostrEventId nullable
syncStatus
```

resultReason-Werte:

```text
NULL                       — Standard, kein Sonderfall
QUORUM_NOT_MET             — participationRate unter quorumThreshold
NO_VALID_VOTES             — keine gültigen Stimmen abgegeben
ALL_ABSTAIN                — nur Enthaltungen
TIE_REQUIRES_RUNOFF        — Top-Tie, Stichwahl nötig (§9.12)
WINNER_WITHDRAWN           — Sieger ist zurückgetretener Kandidat (§9.5.1)
ALL_CANDIDATES_WITHDRAWN   — alle Kandidaten zurückgetreten (§9.5.1)
WITHDRAWN_DURING_VOTING    — Proposal wurde während VOTING zurückgezogen (§8.5)
```

resultRelation-Werte:

```text
NULL              — eigenständiges Proposal, keine Beziehung zu vorherigem
RUNOFF_OF         — Stichwahl zu einem Vorgänger-Proposal mit
                    TIE_REQUIRES_RUNOFF oder WINNER_WITHDRAWN
REPLACEMENT_OF    — Komplettes Ersatz-Proposal nach
                    ALL_CANDIDATES_WITHDRAWN oder
                    Withdraw + Neuauflage
```

Bei `resultRelation = RUNOFF_OF` oder `REPLACEMENT_OF`:

```text
previousProposalId muss auf das Vorgänger-Proposal zeigen.
Diese Verkettung erlaubt vollständiges Audit-Tracing über
alle Iterationen einer Entscheidung.
```

## 20.9 audit_log

```text
auditId
entityType
entityId
proposalId nullable
cellId nullable
actionType
actorDid
actorRole
createdAt
previousHash
eventHash
encDetails nullable
nostrEventId nullable
syncStatus
```

## 20.10 publish_results

```text
publishResultId
localEventId
nostrEventId
eventKind
proposalId nullable
cellId nullable
relayUrl
status: PENDING | ACCEPTED | REJECTED | FAILED | RETRYING | PARTIAL
attemptedAt
ackReceivedAt nullable
errorCode nullable
errorMessage nullable
retryCount
nextRetryAt nullable
requiredAckCount
acceptedRelayCount
failedRelayCount
finalStatus
```

## 20.11 intercell_proposals

```text
proposalId
initiatingCellId
targetCellIdsJson
acceptedCellIdsJson
rejectedCellIdsJson
activationThresholdPercent
intercellStatus
createdAt
activatedAt nullable
closedAt nullable
```

## 20.12 cell_mandates

```text
mandateId
proposalId
cellId
delegateDid
cellPosition: YES | NO | ABSTAIN
voteResultHash
encMandateText
createdAt
updatedAt
signature
nostrEventId nullable
syncStatus
```

## 20.13 external_expert_invites

```text
inviteId
proposalId
cellId
expertDid
mode: ADVISOR_ONLY | DELEGATION_ALLOWED
status: invited | accepted | declined | revoked
createdAt
respondedAt
```

---

# 21. Nostr Event Modell

## 21.1 Event-Kinds

Vorhandene Kinds bleiben erhalten, soweit bereits im Code genutzt.

Empfohlene Erweiterung:

```text
31010 = Proposal
31011 = Vote
31012 = Delegation
31013 = Decision Record
31014 = Expert Profile
31015 = Expert Statement
31016 = Cell Mandate
31017 = Audit Event
31018 = Intercell Invite / Response
```

## 21.2 ACK-Pflicht

PublishResult zwingend für:

```text
Proposal veröffentlicht
Voting gestartet
Vote abgegeben
Vote geändert
Vote widerrufen
Delegation gesetzt
Delegation widerrufen
Expert Statement erstellt/geändert
Decision Record erstellt
Cell Mandate erstellt
Intercell Invite/Response
Superadmin Recall
Rollenänderungen
Mitgliedschaftsänderungen
```

## 21.3 PublishResult-Regel

```text
requiredAckCount = 2 Relays
```

Status:

```text
0 ACK → FAILED oder RETRYING
1 ACK → PARTIAL
2+ ACK → ACCEPTED
```

## 21.4 Retry

```text
Retry nach:
1 Minute
5 Minuten
15 Minuten
1 Stunde
6 Stunden
```

Nach mehrfacher Fehlübertragung:

```text
Status = FAILED
UI zeigt "manuell erneut senden"
```

## 21.5 Sync-Status

```text
LOCAL_ONLY
PENDING
PARTIAL
ACCEPTED
FAILED
RETRYING
```

UI-Texte:

```text
Lokal gespeichert
Wird gesendet
Teilweise bestätigt
Synchronisiert
Fehlgeschlagen
Wird erneut versucht
```

---

# 22. Sybil-Resistenz und Mitgliedschaft

## 22.1 G2 MVP

Stimmberechtigung basiert auf:

```text
DID
aktive Zellmitgliedschaft
Rolle innerhalb der Zelle
```

Zusätzlich wichtig:

```text
Mitgliedschafts-Broadcast muss vor G2 stabil sein.
```

Vor G2 zwingend zu erledigen:

```text
Zellen-Mitgliedschafts-Broadcast
Async-Gaps in ProposalService / handleIncoming beheben
Restore-Flow prüfen
```

## 22.2 Später

Ausbau mit:

```text
Web of Trust
Bürgen
AURA
Staked Trust
physische Verifikation
Proof-of-Personhood
Cross-Cell-Audit
```

---

# 23. Edge Cases

## 23.1 Stimme nach Ablauf

```text
blockieren
Audit optional: VOTE_REJECTED_AFTER_DEADLINE
```

## 23.2 Stimme vor Voting

```text
blockieren
```

## 23.3 Doppelte Relay-Events

```text
idempotent behandeln
eventHash prüfen
keine Doppelzählung
```

## 23.4 Nutzer delegiert und stimmt selbst

```text
Direktvote gewinnt
Delegation wird deaktiviert
```

## 23.5 Delegierter stimmt nicht

```text
Delegationen verfallen
kein Quorum-Beitrag
Warnhinweis
```

## 23.6 Nur Enthaltungen

```text
INVALID
```

## 23.7 Quorum nicht erreicht

```text
INVALID
```

## 23.8 Gleichstand

```text
REJECTED
```

## 23.9 Proposal in Voting fehlerhaft

```text
nur Moderator/Admin kann withdraw/invalid setzen
Begründung Pflicht
Audit Pflicht
```

## 23.10 Interzelluläre Aktivierung nicht erreicht

```text
INTERCELL_INVALID / INVALID
```

---

# 24. Pflicht-Tests

## 24.1 Voting

```text
YES/NO/ABSTAIN funktioniert
Stimme ändern vor Ablauf
Stimme nach Ablauf blockiert
Widerruf entfernt Stimme aus Quorum
Nur eine aktive Stimme pro Proposal
```

## 24.2 Delegation

```text
Delegation pro Proposal funktioniert
Delegation widerrufbar
Direktvote überschreibt Delegation
Delegierter ohne Vote → Delegation verfällt
Delegationslimit greift
Transitive Delegation wird blockiert
```

## 24.3 Experten

```text
Expertenprofil aktivierbar
Experte ohne Statement kann keine Delegationen empfangen
Statementänderung erzeugt Audit
AURA sichtbar
Delegationen aggregiert sichtbar
```

## 24.4 QV

```text
100 Credits pro Quartal
Kosten = Stimmen²
3 Stimmen kosten 9 Credits
Überschreitung wird UI-seitig blockiert
QV nur bei GENERAL / RESOURCE
```

## 24.5 Tally

```text
gleiche Inputs → gleiches Ergebnis
Delegation korrekt addiert
Enthaltungen zählen zum Quorum, nicht zur Mehrheit
Quorum korrekt geprüft
Gleichstand → REJECTED
Nur Enthaltungen → INVALID
```

## 24.6 Intercell

```text
Zellen einladen
Teilnahme annehmen/ablehnen
Aktivierungsschwelle korrekt
Zellmandat entsteht
1 Zelle = 1 Stimme
Intercell-Ergebnis korrekt
```

## 24.7 Superadmin

```text
Recall erstellbar
nur berechtigte Rollen können starten
keine Delegation möglich
kein QV möglich
Quorum 2/3
Mehrheit 2/3
Übergangsrolle korrekt
Rechte nach Ablauf entzogen
```

## 24.8 Audit

```text
Audit append-only
keine Deletes
previousHash/eventHash korrekt
alle kritischen Aktionen geloggt
```

## 24.9 Nostr

```text
PublishResult gespeichert
2 Relay ACKs erforderlich
PARTIAL bei 1 ACK
Retry-Logik funktioniert
FAILED sichtbar
```

## 24.10 Datenschutz

```text
sensible Felder verschlüsselt
Indexfelder klar
Hashes vorhanden
private Gründe nicht öffentlich
```

---

# 25. MVP-Umfang

## Muss in G2 rein

```text
Zellinterne Abstimmungen
YES / NO / ABSTAIN
Stimme ändern
Stimme widerrufen
Delegation pro Proposal
Expertenprofile
AURA-Anzeige
Statementpflicht
Delegationslimit
QV für GENERAL / RESOURCE
Quoren
Tally Engine
Interzelluläre Entscheidungen
Superadmin-Abwahl
Übergangsrolle Superadmin
Audit-Log
Hybrid-Datenmodell
Nostr PublishResult
```

## Nicht in G2

```text
Delegation Decay
Zufalls-Bürgerräte
vollständiges Föderationsparlament
Cross-Cell-Audit
Minoritätenschutz-Protokoll
Restorative Justice Layer
AURA als Stimmgewicht
globale Mitgliedsabstimmungen
vollständige Sybil-Resistenz
Verfassungsgericht
Hard-Cap Enforcement in voller Tiefe
```

---

# 26. G2.1 / spätere Ausbaustufen

## G2.1

```text
Mediation vor interzellulären Abstimmungen
bessere Expertenlogik
Delegation Decay erste Version
Benachrichtigungen bei Experten-Statementänderung
Externe Experten verfeinern
```

## G3

```text
vollständige Föderations-Governance
Sphären-Governance
Cross-Cell-Audit
Minoritätenschutz
Sortition / Zufalls-Bürgerrat
AURA-basierte begrenzte Expertise-Gewichtung
```

## G4

```text
Grundstimmrecht bei Verfassungsfragen
Hard-Cap-Mechanismen
Verfassungsgericht / Resolution Layer
```

---

# 27. Definition of Done für G2

G2 ist fertig, wenn:

```text
1. Zellinterne Abstimmungen vollständig funktionieren.
2. Delegation pro Proposal vollständig funktioniert.
3. Expertenprofile mit AURA sichtbar sind.
4. Statementpflicht enforced ist.
5. QV mit 100 Credits pro Quartal funktioniert.
6. Quoren und Entscheidungsregeln korrekt angewendet werden.
7. Interzelluläre Entscheidungen funktionsfähig sind.
8. Superadmin-Abwahl mit Übergangsphase funktioniert.
9. Tally Engine deterministisch arbeitet.
10. Audit-Log append-only ist.
11. sensible Daten verschlüsselt sind.
12. PublishResult / Relay ACKs gespeichert werden.
13. Retry-Logik funktioniert.
14. UI zeigt Sync-Status ehrlich an.
15. alle Pflicht-Tests grün sind.
16. keine bestehenden DB-Tabellen gelöscht wurden.
17. Migrationen nur über ALTER TABLE laufen.
18. keine Hard Deletes bei veröffentlichten Governance-Daten erfolgen.
19. Alle drei Voting-Modi funktionieren:
    YES_NO_ABSTAIN, SINGLE_CHOICE, CANDIDATE_CHOICE.
20. proposal_options-Tabelle ist implementiert und ab DRAFT
    verwendbar.
21. CANDIDATE_CHOICE-Wahlen erzwingen 1-Mensch=1-Stimme,
    keine Delegation, kein QV.
22. Stichwahl-Workflow funktioniert (TIE_REQUIRES_RUNOFF und
    WINNER_WITHDRAWN erzeugen Folge-Proposal mit RUNOFF_OF).
23. Kandidatenrücktritt während VOTING ist sauber abgebildet
    (WITHDRAWN-Status, Stimmen bleiben erhalten, kein Sieg
    für zurückgetretene Kandidaten).
24. Validierungen für Optionen-Anzahl beim VOTING-Start aktiv
    (SINGLE_CHOICE: 2-10, CANDIDATE_CHOICE: 2-20).
25. Schema-Migration setzt votingMode = YES_NO_ABSTAIN für
    Altbestand.
```

---

# 28. Kritische Vorbedingungen vor Implementierung

Vor G2 müssen laut technischem Stand zwingend stabilisiert werden:

```text
1. Zellen-Mitgliedschafts-Broadcast
2. Async-Gaps in ProposalService / handleIncoming
3. Restore-Flow / Backup-Recovery prüfen
4. State-Locking bei parallelen Relay-Events
5. Keine doppelten Inserts bei Relay-Race-Conditions
```

Warum?

```text
G2-Quoren hängen von korrekter Mitgliedschaft ab.
G2-Tally hängt von eindeutigen Votes und Delegationen ab.
Governance darf keine Race Conditions haben.
```

---

# 29. Verbindliche v1.1/v1.2/v1.3-Präzisierungen

Diese Präzisierungen sind Bestandteil der Spezifikation und ersetzen widersprechende ältere Formulierungen.

## 29.1 QV + Delegation

```text
Bei QV-Proposals kann nur die eigene Stimme des Delegierten QV-Gewicht haben.
Delegierte Stimmen zählen im G2 MVP immer mit Gewicht 1.
```

## 29.2 Voice Credits

```text
quarterId = YYYY-Q1 / YYYY-Q2 / YYYY-Q3 / YYYY-Q4
UTC-Kalenderquartale
100 Credits pro Quartal und Gemeinschaft/Zelle
kein Übertrag
nicht käuflich
nicht übertragbar
Membership-Maturity für QV > 1: Default 14 Tage
```

## 29.3 participationCount

```text
participationCount zählt nur gültige direkte Stimmen und gültige erfolgreiche Delegationen.
Ungültige Delegationen zählen nicht.
```

## 29.4 Kleine Gemeinschaften

Bei unter 10 stimmberechtigten Mitgliedern überschreibt die Kleine-Gemeinschaften-Regel das normale Prozentquorum.

## 29.5 Withdraw aus VOTING

```text
Withdraw/Invalid aus VOTING erzeugt Audit-Event.
Bereits abgegebene Votes bleiben historisch erhalten.
Sie zählen nicht zum Ergebnis.
Voice Credits werden zurückerstattet.
Decision Record erhält result = INVALID und resultReason = WITHDRAWN_BY_MODERATION.
```

## 29.6 AURA im MVP

```text
AURA bleibt vorbereitet, aber wenn kein Wert berechnet ist, zeigt die UI:
„AURA noch nicht berechnet" / „AURA folgt in G2.1".
Keine Fake-Scores.
Keine negative 0/10000-Darstellung.
Keine AURA-Stimmgewichtung im G2 MVP.
```

## 29.7 Interzelluläre Einladungen

Interzelluläre Proposals erhalten:

```text
affectedScope: MANUAL | REGION | DOMAIN | SPHERE
invitationRationaleEnc Pflicht
```

Bei MANUAL zeigt die UI einen Transparenzhinweis, dass relevante Gemeinschaften fehlen könnten.

## 29.8 Externe Experten

Workflow:

```text
INVITED
ACCEPTED
DECLINED
STATEMENT_SUBMITTED
ELIGIBLE_FOR_DELEGATION
REVOKED
EXPIRED
```

Externe Experten haben keine direkte Zellstimme, solange sie keine Mitglieder sind.

## 29.9 Regel-Snapshot

Bei Start der Voting-Phase wird `ruleSnapshotJson` eingefroren. Die Tally Engine nutzt diesen Snapshot, nicht spätere Änderungen an Gemeinschaftsregeln.

## 29.10 Deterministische Sortierung

Vor Tally und Hashing sortiert die Engine:

```text
votes: createdAt ASC, voteId ASC
delegations: createdAt ASC, delegationId ASC
expertStatements: createdAt ASC, statementId ASC
cellMandates: createdAt ASC, mandateId ASC
proposalOptions: sortOrder ASC, optionId ASC
```

## 29.11 Sync-Konflikte

Ein gültig signierter Decision Record mit gültigem inputHash/resultHash gewinnt gegenüber lokalem VOTING-Status.

## 29.12 Neue Voting-Modi v1.2

```text
YES_NO_ABSTAIN: klassische Ja/Nein/Enthaltung
SINGLE_CHOICE: eine Option aus mehreren auswählen
CANDIDATE_CHOICE: Kandidaten-/Personenwahl
```

CANDIDATE_CHOICE ist immer:

```text
keine Delegation
kein QV
1 Mensch = 1 Stimme
```

## 29.13 v1.3-Präzisierungen

### 29.13.1 Anzahl-Limits für Voting-Modi

```text
SINGLE_CHOICE: 2-10 Optionen im G2 MVP
CANDIDATE_CHOICE: 2-20 Kandidaten im G2 MVP

Bei nur einem Kandidaten:
  Stattdessen YES_NO_ABSTAIN-Bestätigungs-Voting verwenden:
  "Soll Person X die Rolle Y übernehmen?"

VOTING-Start blockiert wenn Anzahl außerhalb der Grenzen.
```

### 29.13.2 Kandidatenrücktritt während VOTING

```text
Kandidat-Status wird auf WITHDRAWN gesetzt.
Stimmen bleiben historisch erhalten.
Stimmen für WITHDRAWN-Kandidaten zählen zur participationCount,
aber nicht zur Sieger-Wertung.

Bei Sieg eines zurückgetretenen Kandidaten:
  result = INVALID
  resultReason = WINNER_WITHDRAWN
  Stichwahl unter ACTIVE-Kandidaten

Bei Rücktritt aller Kandidaten:
  result = INVALID
  resultReason = ALL_CANDIDATES_WITHDRAWN
  Vollständig neues Proposal nötig
```

### 29.13.3 Stichwahl-Workflow

```text
Bei TIE_REQUIRES_RUNOFF oder WINNER_WITHDRAWN:
  - Neues Stichwahl-Proposal mit previousProposalId
  - votingMode, proposalType, proposalScope unverändert
  - Optionen: nur die im Tie / nur ACTIVE-Kandidaten
  - Quoren identisch zum Original
  - Default-Dauer: halbe Originaldauer (im Rahmen der globalen Grenzen)
  - Decision Record: resultRelation = RUNOFF_OF
```

### 29.13.4 Top-Tie-Klärung

```text
Im G2 MVP ist nur Platz 1 entscheidungsrelevant.
Gleichstände auf Platz 2+ haben keine Auswirkung.
Decision Record speichert nur den Gewinner (oder INVALID bei Top-Tie).
```

### 29.13.5 Migration für Altbestand

```text
proposals.votingMode bekommt DEFAULT 'YES_NO_ABSTAIN'.
Beim Schema-Upgrade auf v2.x wird für alle existierenden
proposals automatisch votingMode = 'YES_NO_ABSTAIN' gesetzt.
```

### 29.13.6 Korrekturen aus v1.2

```text
- §17.10 (Sonderfälle) ist jetzt §17.11.
  Konflikt mit §17.10 (Tally) aufgelöst:
  Top-Tie löst INVALID + RUNOFF aus, kein REJECTED mehr.
- §20.1 proposals enthält jetzt votingMode-Feld.
- §20.2/20.3 Doppel-Nummerierung korrigiert
  (proposal_options bleibt 20.2, votes wird 20.3, delegations wird 20.4 etc.).
- §20.8 decision_records erweitert um resultRelation und previousProposalId.
- §17.6 Zählung erweitert um Option-/Kandidaten-Aggregation für
  SINGLE_CHOICE und CANDIDATE_CHOICE.
```

---

# 30. Kurzform für Claude Code

```text
Implementiere G2 Governance für die N.E.X.U.S. OneApp.

G2 umfasst:
- Zellinterne Abstimmungen
- Interzelluläre Abstimmungen
- YES/NO/ABSTAIN
- SINGLE_CHOICE für mehrere Optionen
- CANDIDATE_CHOICE für Kandidaten-/Personenwahl
- Vote ändern/widerrufen
- Delegation pro Proposal
- Expertenprofile mit AURA
- Statementpflicht
- Quadratic Voting für GENERAL/RESOURCE
- Quoren
- deterministische Tally Engine
- Superadmin-Abwahl mit Übergangsrolle
- append-only Audit-Log
- Hybrid-Datenmodell
- Nostr PublishResult mit 2 Relay ACKs

Wichtig:
- Keine transitive Delegation
- Keine globale Dauerdelegation
- Keine AURA-Stimmgewichtung im MVP
- Keine Hard Deletes nach Veröffentlichung
- Kandidatenwahl: keine Delegation, kein QV, 1 Mensch = 1 Stimme
- Direkte Stimme überschreibt Delegation
- Delegierter ohne Vote lässt Delegationen verfallen
- Intercell: 1 Zelle = 1 Stimme
- Superadmin Recall: 1 Mensch = 1 Stimme, kein QV, keine Delegation
```
