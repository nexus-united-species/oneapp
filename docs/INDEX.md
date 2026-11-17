# N.E.X.U.S. OneApp – Dokumentationsindex

Stand: 15. Juli 2026, nachgeführt 13. November 2026

Dieser Index ist der Einstiegspunkt in die Projektdokumentation. Aussagen zum
aktuellen Stand gelten nur dann als aktuell, wenn sie in `current/` oder in
diesem Index stehen. Dokumente unter `archive/` beschreiben frühere Stände und
sind keine Arbeitsgrundlage für neue Änderungen.

## Jetzt lesen

| Dokument | Zweck | Status |
|---|---|---|
| [Projektstatus](current/PROJECT_STATUS.md) | Was tatsächlich implementiert, getestet und offen ist | aktuell, Stand 13.11.2026 |
| [Architektur-Ist-Zustand](current/ARCHITECTURE_REALITY.md) | Wie die Architektur im Code tatsächlich aussieht: Schichtung, Kopplungen, Identitätsmodell | aktuell, Stand 18.08.2026 |
| [Event-Karte](current/EVENT_MAP.md) | Nostr-Kind → Handler → Service, inkl. Empfangspfad und Vertrauensprüfungen | aktuell, Stand 13.11.2026 |
| [Was nicht angefasst werden sollte](current/DO_NOT_TOUCH.md) | Bereiche, die gut genug sind und geschützt werden | aktuell, Stand 18.08.2026 |
| [Architekturentscheidungen](decisions/) | Offene und getroffene Grundsatzentscheidungen (ADRs) | ADR-0001 angenommen (08.11.2026), ADR-0002 bis 0005 vorgeschlagen |
| [Release Readiness](current/RELEASE_READINESS.md) | Blocker und Reihenfolge vor dem nächsten Alpha-Release | aktuell, Stand 13.11.2026 |
| [Tech Debt](current/TECH_DEBT.md) | Was offen ist, nach Priorität; Verlauf im [Archiv](archive/TECH_DEBT_VERLAUF.md) | aktuell, neu gegliedert 13.11.2026 |
| [Offene Gerätetests](current/GERAETETESTS_OFFEN.md) | Gesammelte Prüfungen am Gerät, die vor dem Push laufen | laufend gepflegt |
| [Bedienungsanleitung](guides/Bedienungsanleitung.md) | Nutzeranleitung für v0.2.0-alpha | aktuell, Alpha-Hinweise beachten |
| [Testanleitung](guides/testing/TESTING.md) | Reproduzierbarer Testeinstieg und bekannte Baseline | aktuell |
| [G2-Spezifikation v1.5](specs/governance/G2_Spezifikation_v1.5.md) | Konsolidierte Governance-Spezifikation | aktuell |

## Fach- und Arbeitsdokumente

| Bereich | Inhalt | Einordnung |
|---|---|---|
| [Audit November 2026](audits/2026-11/AUDIT_BERICHT.md) | Code-, Strategie-, Funktions-, UX-, Dezentralitäts- und Modularitätsprüfung mit Zwischenplan | aktuelle Befundquelle; Grundlage des Arbeitsplans |
| [Audits Juli 2026](audits/2026-07/) | Technischer Lauf A und strategischer Lauf B | Befunde größtenteils umgesetzt; Lauf B teilweise bewusst geparkt |
| [AETHER-Entwurf v0.4](specs/drafts/AETHER_Spezifikation_v0.4.docx) | Noch nicht freigegebene AETHER-Spezifikation | Entwurf, AETHER ist nicht implementiert |
| [Architektur-Briefing 2026](planning/ARCHITEKTUR_BRIEFING_2026.md) | Quellfassung des strategischen Briefings: Messenger First, Modular Underneath, Reality-Audit-Auftrag | Auftragsgrundlage seit 18.08.2026 |
| [Antwort auf das Briefing](planning/ANTWORT_ARCHITEKTUR_BRIEFING.md) | Architektenantwort: §50-Fragen, Widerspruch, Bewertung einer Kooperation mit Web of Trust (zweimal korrigiert) | Diskussionsgrundlage |
| [NOW/NEXT/LATER](planning/NOW_NEXT_LATER.md) | Arbeitsplan nach dem Audit (Blöcke 1–4, seit 11.11.2026), Stufen A–G als Inhaltsliste, Mesh-Zweig | **Arbeitsgrundlage für den nächsten Schritt** |
| [Übergabe an ChatGPT](planning/UEBERGABE_CHATGPT.md) | Welche Dokumente die Strategieberatung braucht, was verifiziert ist, was sich zuletzt geändert hat | Handreichung |
| [Briefing-Abdeckung](planning/BRIEFING_ABDECKUNG.md) | Welche Briefing-Anforderung ist erfüllt, offen oder bewusst verworfen | **fortzuschreiben nach jedem Arbeitsblock** |
| [Messenger-first-Modus](planning/messenger-first-modus.md) | Analyse einer möglichen Fokusänderung | offene Planungsentscheidung |
| [Zielbild Gemeinschaften, Portal und OneApp](planning/ZIELBILD_GEMEINSCHAFTEN_HUMHUB_ONEAPP.md) | Wie HumHub-Kreise, Übersicht, Kanäle, Dorfplatz und Gemeinschaften zusammengeführt werden; Übergangspfad zur Ablösung des Portals | Entwurf, Stand 06.11.2026; vor Phase 3 zu entscheiden |
| [Research](research/) | Analysen fremder Projekte: Web of Trust, Real Life Stack, SourceLess | Recherche, keine Entscheidung |
| [Bauplan-Extrakt V13.1](vision/BAUPLAN_V13.1_extrakt.txt) | Langfristige Vision (aktueller Bauplan: v14, außerhalb des Repos) | Vision, keine Ist-Beschreibung |
| [Bauplan-Abgleich](vision/BAUPLAN_ABGLEICH.md) | Aussagen des Bauplans, die der Code nicht deckt (Audit D-1) | zur Weitergabe an die Bauplan-Pflege |
| [Legacy-Chat-Test](guides/testing/legacy-chat-test.md) | Frühere Zwei-Geräte-LAN-Anleitung | Referenz; aktuelle Anleitung hat Vorrang |
| [Bugmeldungen](guides/testing/bugmeldungen/) | 13 gemeldete Einzelfehler aus dem Testing (Profilbilder, Verschlüsselung, KanalGruppe-Administration u. a.) | ungeprüft gegen aktuellen Code; noch nicht in TECH_DEBT.md konsolidiert |
| [Änderungswünsche](guides/testing/aenderungswuensche/) | 3 Change Requests aus dem Testing | offen |
| [Testprotokoll v0.2.0-alpha](guides/testing/NEXUS_OneApp_Testprotokoll_v0.2.0-alpha.docx) + [Bug-Reporting-Tabelle](guides/testing/NEXUS_OneApp_Bug-Reporting_v0.2.0-alpha.xlsx) | Strukturierte Testdokumentation zur v0.2.0-alpha | Referenz |
| [Masterplan & Baustellen](planning/NEXUS_Masterplan_Baustellen.md) + [Kommandozentrale](planning/NEXUS_Kommandozentrale.md) | Projektweite Priorisierung (Stand 2026-06-26); ordnet OneApp-Entwicklung in Gesamtprojekt ein | Planung, außerhalb reinem App-Scope |
| [Mesh-Grundlagen](specs/drafts/mesh/) | Reticulum/BLE-Mesh-Referenzmaterial | Hintergrund; Mesh als paralleler Zweig geplant, nicht implementiert (BLE/LAN heute nur Direktverbindung) |
| [AETHER-Synopse Ökonomie](specs/drafts/AETHER_Synopse_Oekonomie.pdf) | Ökonomisches Begleitdokument zur AETHER-Spezifikation | Entwurf |
| [Implementierungsplan V5.2 (Developer-Fassung)](archive/plans/NEXUS_OneApp_Implementierungsplan_V5.2_developer.md) | Ausführlichere Entwicklerversion des archivierten Plans | Referenz, überholt |
| [Claude-Arbeitsweise-Leitfaden](guides/NEXUS_mit_Claude_bauen_Leitfaden.md) + [Onboarding](guides/onboarding_nexus_one_app.md) | Wie mit Claude Code an der OneApp gearbeitet wird | Arbeitsanleitung |

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
3. Architektur-Grundsatzentscheidungen gehören als ADR nach `decisions/`.
4. Noch nicht freigegebene Ideen werden als Entwurf oder Planung markiert.
5. Alte Stände werden verschoben, nicht still überschrieben.
6. Versionsaussagen werden gegen `pubspec.yaml`, Installer und Code geprüft.
7. Sicherheitsversprechen beschreiben nur nachweislich implementiertes
   Verhalten; Vision und Zielbild werden ausdrücklich so benannt.

## Was gehört ins Repository?

Es gibt drei Ablagen mit unterschiedlicher Rolle. Sie bleiben getrennt.

| Ort | Rolle |
|---|---|
| `C:\nexus-oneapp` | **Arbeitsstand** — Code und alles, was ihn regiert |
| `…\Documents\!Nexus_Wissen` | **Kuratiertes Archiv** — Wissen, Medien, Organisation |
| `…\Documents\!!!!!!!!!!!!!!!!!_Nexus` | **Rohbestand** — historisch, unsortiert |

**Regel:** Ins Repository kommt, was den Code **regiert oder beschreibt** —
Spezifikationen, Bugmeldungen, Testprotokolle, Architektur, Entscheidungen,
Grenzen. Draußen bleibt, was das Projekt **umgibt** — Medien, Romane,
Marketing, Sitzungsmitschnitte, Organisation, große Referenz-PDFs.

**Vor jedem Import gilt:**

1. **Inhalt prüfen, nicht Ordnerlage.** Auch das kuratierte Archiv enthält
   falsch einsortierte Fremddateien.
2. **Auf Geheimnisse prüfen:** Passwörter, Seedphrases, Schlüssel, API-Keys.
   `.gitignore` schützt gegen die bekannten Muster, aber nicht gegen alle.
3. **Auf Projektzugehörigkeit prüfen.** N.E.X.U.S. spricht von Zellen,
   Gemeinschaften, Anträgen, Dorfplatz, Nostr, SQLite — nicht von Supabase,
   Circles oder Rituals.
4. **Bewegliche Dokumente nicht importieren.** Was gerade überarbeitet wird,
   wartet bis zur fertigen Fassung. Sonst steht Veraltetes im Repo und wird
   für gültig gehalten.

Große Referenz-PDFs werden verlinkt statt versioniert — Git speichert sie bei
jeder Änderung vollständig neu.

## Wo steht was?

| Frage | Ort |
|---|---|
| Was ist implementiert? | [current/PROJECT_STATUS.md](current/PROJECT_STATUS.md) |
| Wie ist die Architektur wirklich? | [current/ARCHITECTURE_REALITY.md](current/ARCHITECTURE_REALITY.md) |
| Warum wurde etwas so entschieden? | [decisions/](decisions/) |
| Welcher Nostr-Kind gehört zu welchem Handler? | [current/EVENT_MAP.md](current/EVENT_MAP.md) |
| Was ist kaputt oder Schuld? | [current/TECH_DEBT.md](current/TECH_DEBT.md) |
| Was darf ich nicht anfassen? | [current/DO_NOT_TOUCH.md](current/DO_NOT_TOUCH.md) |
| Was kommt als Nächstes? | [planning/NOW_NEXT_LATER.md](planning/NOW_NEXT_LATER.md) (Reihenfolge), [current/RELEASE_READINESS.md](current/RELEASE_READINESS.md) (Release-Blocker) |
| Was muss noch am Gerät geprüft werden? | [current/GERAETETESTS_OFFEN.md](current/GERAETETESTS_OFFEN.md) |
| Was untersuchen wir? | [research/](research/) |
| Was gilt nicht mehr? | `archive/` |

