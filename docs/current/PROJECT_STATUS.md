# Projektstatus – N.E.X.U.S. OneApp

Stand: 15. Juli 2026  
Codeversion: `0.2.0+12` laut `pubspec.yaml`  
Datenbankschema: Version 23

## Kurzfassung

Die App ist eine funktionsreiche Alpha für Android und Windows. Der letzte
große Entwicklungsblock war G2.1.6: antragsbezogene, nicht-transitive
Stimmdelegation (Liquid Democracy) einschließlich Widerruf, Auto-Revoke,
Auszählung und Nutzeroberfläche. Quadratic Voting ist spezifiziert, aber noch
nicht implementiert. AETHER ist ein Entwurf beziehungsweise Platzhalter und
kein aktives Produktmodul.

Der sinnvolle Wiedereinstieg ist keine neue Großfunktion, sondern ein kurzer
Release-Härtungsblock. Drei bestätigte Fehler gefährden derzeit die
geräteübergreifende Zuverlässigkeit. Zusätzlich fehlen zentrale
Authentizitäts- und Autorisierungsprüfungen für eingehende Nostr-Events; diese
sind spätestens vor einem produktiven Release erforderlich.

## Implementierter Stand

| Bereich | Aktueller Stand |
|---|---|
| Identität | BIP-39-Seed, deterministische Schlüssel/DID, lokaler Identity-Flow |
| Kommunikation | Direktchat, Kanäle, Text/Bilder/Audio, Reaktionen und Löschpfade; Transport über Nostr, LAN und BLE |
| Gemeinschaften | Zellen, Beitritts- und Mitgliederverwaltung, Pinnwand und Agora |
| Dorfplatz | Posts, Kommentare, Reposts, Reaktionen und Löschungen |
| Governance | Anträge, Diskussion, YNA/Single Choice/Candidate Choice, Tally, Decision Records, Stichwahlpfade |
| Liquid Democracy | Pro Antrag delegieren, widerrufen und durch eigene Stimme aufheben; nicht transitiv; Candidate Choice ausgenommen |
| Plattformen | Android und Windows im aktiven Projektumfang |

## Nicht als fertig behandeln

- Quadratic Voting und Voice Credits
- Superadmin-Abwahl über Grundstimm-Recht
- vollständige Expertenprofile, AURA und Statementpflicht
- interzelluläre Governance
- AETHER-Wallet und Marktplatz
- iOS/macOS-Auslieferung
- NIP-44-Migration
- vertrauliche Governance-Events
- belastbare Manipulations- und Berechtigungsprüfung beim Event-Empfang

## Verifizierte Testbaseline

Bei der Wiederaufnahme am 15. Juli 2026 wurden folgende vorhandene Tests
ausgeführt:

- Governance-Suite: **596 von 596 Tests bestanden**.
- Navigation-/Dashboard-Auswahl: **54 bestanden, 11 fehlgeschlagen**.
- Die 11 Fehler bestehen überwiegend aus veralteten Text-/Label-Erwartungen;
  zusätzlich wurde ein realer Desktop-Overflow von 30 Pixeln beobachtet.
- Der vollständige Testlauf endet derzeit mit Exitcode 1.
- `flutter analyze` meldet 947 Hinweise/Probleme; diese Zahl ist eine Baseline,
  nicht automatisch 947 Release-Blocker.
- Die macOS-Registrierung des Pakets `open_file` erzeugt eine Plugin-Warnung,
  obwohl macOS derzeit nicht das Ziel der Alpha ist.

## Bestätigte Risiken

Die vollständigen Belege stehen in [Audit Lauf A](../audits/2026-07/AUDIT_LAUF_A.md)
und [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md).

1. Chat-/Kanal-Reaktionen, Löschungen und Kanal-Metadaten können interne UUIDs
   statt 64-Hex-Nostr-Event-IDs in `e`-Tags senden.
2. Der `eligibleVoters`-Snapshot wird beim Start einer Abstimmung nicht gesetzt;
   Beteiligung und Quorum können dadurch von der lokalen Mitgliederansicht
   abhängen.
3. Decision-Record-Retries übertragen nicht dieselbe vollständige Nutzlast wie
   der Erstversand.
4. Eingehende Nostr-Events werden im Produktivpfad nicht mit
   `NostrEvent.verify()` verifiziert.
5. Governance-Events liegen derzeit als Klartext auf öffentlichen Relays;
   Direktnachrichten über Nostr verwenden NIP-04, nicht NIP-44.

## Empfohlener nächster Arbeitsblock

1. Die drei geräteübergreifenden Release-Blocker F-001 bis F-003 beheben.
2. Betroffene Cross-Device-Flows mit Android und Windows testen.
3. Veraltete UI-/Navigation-Tests und den Desktop-Overflow bereinigen.
4. Signaturprüfung und Absenderautorisierung als eigenen Härtungsblock planen.
5. Erst danach über Quadratic Voting oder einen anderen Funktionsblock
   entscheiden.

Die operative Checkliste steht in
[RELEASE_READINESS.md](RELEASE_READINESS.md).

