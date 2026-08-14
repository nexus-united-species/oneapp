# N.E.X.U.S. OneApp – Dokumentationsindex

Stand: 15. Juli 2026

Dieser Index ist der Einstiegspunkt in die Projektdokumentation. Aussagen zum
aktuellen Stand gelten nur dann als aktuell, wenn sie in `current/` oder in
diesem Index stehen. Dokumente unter `archive/` beschreiben frühere Stände und
sind keine Arbeitsgrundlage für neue Änderungen.

## Jetzt lesen

| Dokument | Zweck | Status |
|---|---|---|
| [Projektstatus](current/PROJECT_STATUS.md) | Was tatsächlich implementiert, getestet und offen ist | aktuell |
| [Release Readiness](current/RELEASE_READINESS.md) | Blocker und Reihenfolge vor dem nächsten Alpha-Release | aktuell |
| [Tech Debt](current/TECH_DEBT.md) | Bestätigte technische Schulden mit Priorität | aktuell |
| [Bedienungsanleitung](guides/Bedienungsanleitung.md) | Nutzeranleitung für v0.2.0-alpha | aktuell, Alpha-Hinweise beachten |
| [Testanleitung](guides/testing/TESTING.md) | Reproduzierbarer Testeinstieg und bekannte Baseline | aktuell |
| [G2-Spezifikation v1.5](specs/governance/G2_Spezifikation_v1.5.md) | Konsolidierte Governance-Spezifikation | aktuell |

## Fach- und Arbeitsdokumente

| Bereich | Inhalt | Einordnung |
|---|---|---|
| [Audits Juli 2026](audits/2026-07/) | Technischer Lauf A und strategischer Lauf B | aktuelle Befundquellen; Lauf B teilweise bewusst geparkt |
| [AETHER-Entwurf v0.4](specs/drafts/AETHER_Spezifikation_v0.4.docx) | Noch nicht freigegebene AETHER-Spezifikation | Entwurf, AETHER ist nicht implementiert |
| [Messenger-first-Modus](planning/messenger-first-modus.md) | Analyse einer möglichen Fokusänderung | offene Planungsentscheidung |
| [Bauplan-Extrakt V13.1](vision/BAUPLAN_V13.1_extrakt.txt) | Langfristige Vision | Vision, keine Ist-Beschreibung |
| [Legacy-Chat-Test](guides/testing/legacy-chat-test.md) | Frühere Zwei-Geräte-LAN-Anleitung | Referenz; aktuelle Anleitung hat Vorrang |

## Archiv

`archive/` enthält abgeschlossene Phasen, alte Release-Dokumente,
Planungsstände, frühere Spezifikationen und Code-Snapshots. Diese Dateien
bleiben zur Nachvollziehbarkeit erhalten, werden aber nicht mehr gepflegt.

- `archive/releases/` – Dokumente früherer App-Versionen
- `archive/milestones/` – Abschluss- und Ist-Berichte früherer Phasen
- `archive/plans/` – überholte Implementierungspläne
- `archive/audits/` – ältere Audits
- `archive/specs/` – abgelöste Spezifikationsstände
- `archive/ai-context/` – alte KI-Kontextdateien
- `archive/code-snapshots/` – große, regenerierbare Quelltextauszüge

## Dokumentationsregeln

1. Aktuelle Zustandsaussagen gehören nach `current/`.
2. Normative Fachentscheidungen gehören nach `specs/`.
3. Noch nicht freigegebene Ideen werden als Entwurf oder Planung markiert.
4. Alte Stände werden verschoben, nicht still überschrieben.
5. Versionsaussagen werden gegen `pubspec.yaml`, Installer und Code geprüft.
6. Sicherheitsversprechen beschreiben nur nachweislich implementiertes
   Verhalten; Vision und Zielbild werden ausdrücklich so benannt.

