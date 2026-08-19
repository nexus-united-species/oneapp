# Übergabe an ChatGPT — Beratungsgrundlage

Stand: 18. August 2026, 20:25 — **Architekturstand eingefroren**

> **Diese Runde ist abgeschlossen.** Drei Beratungsdurchgänge (Claude-Audit →
> ChatGPT-Korrekturen → Verifikation → redaktionelle Bereinigung) haben den
> Stand erreicht, ab dem weitere Analyse mehr kostet als sie bringt.
>
> **Ab jetzt gilt:** NOW abarbeiten → NEXT-A umsetzen → dann ADR-0001
> entscheiden. Keine weitere Architekturrunde, bevor NOW und NEXT-A erledigt
> sind.
>
> Neue Erkenntnisse werden als ADR ergänzt, nicht als neue Analyserunde.
Zweck: Damit ChatGPT die Strategiediskussion (Kooperation mit Anton /
Web of Trust) auf aktuellem und vollständigem Stand beraten kann.

## Was aus ChatGPTs letzter Rückmeldung übernommen wurde

Alle drei Punkte waren berechtigt und sind umgesetzt:

1. **Widersprüchliche Korrekturtabelle bereinigt.** In
   `ANTWORT_ARCHITEKTUR_BRIEFING.md` stand oben noch die überholte Zeile
   „Device Keys: bei ihnen spezifiziert und implementiert". Sie ist jetzt in
   zwei getrennte, korrekte Zeilen aufgelöst (Device Keys = Phase-2-Entwurf,
   nicht verdrahtet / Key Rotation = für Space-Keys implementiert) und mit
   einem Lesehinweis versehen.
2. **Falsche Abhängigkeiten in `NOW_NEXT_LATER.md` korrigiert.** CRDT und
   Schlüsselrotation hängen nicht mehr an ADR-0002.
3. **Neuer Block NEXT-A „Sync-Härtung"** eingefügt — TD-33 und TD-46 vor
   ADR-0002, mit ADR-0003 im selben Block.

Zusätzlich: ADR-0002 selbst wurde angepasst (der Abschnitt „wird täglich
teurer" stimmte nach dem Sync-Befund nicht mehr) und ADR-0001/0002 sind als
getrennt zu entscheiden markiert.

---

## ⚠️ Zuerst: Was sich seit der letzten Übergabe geändert hat

ChatGPT hat eine Fassung vom **Nachmittag** erhalten. Danach lief eine
**Verifikationsrunde**, in der drei Aussagen präzisiert und eine neue
Erkenntnis gewonnen wurde. **Wer auf dem alten Stand berät, priorisiert
möglicherweise falsch.**

### Neu und beratungsrelevant

**1. Die Schlüsselableitung ist jetzt mathematisch bewiesen, nicht nur gelesen.**

Mit dem Standard-BIP-39-Testvektor (`abandon ×11 + about`) nachgerechnet:

| Schritt | Ergebnis |
|---|---|
| BIP-39-Seed | `5eb00bbddcf069…` — identisch mit WoTs `test-vectors/phase-1-interop.json` |
| WoT HKDF | `f5dfa334475ac5…` — **Testvektor byte-genau reproduziert** |
| N.E.X.U.S. SLIP-0010 | `560f9f3c94558b…` — abweichend |

Bedeutung: Gleicher Seed, verschiedene DIDs, Divergenz in genau einem Schritt.
Und: Die WoT-Ableitung ließ sich in ~10 Zeilen nachbauen und traf den Vektor
sofort — **eine Dart-Implementierung von `wot-identity@0.1` ist klein und
objektiv prüfbar.** Das stützt den Protokollweg konkret.

**2. Device Delegation ist noch schwächer verankert als zuletzt berichtet.**

`DeviceKeyBinding` hat **null Aufrufer in der Anwendungsschicht** — nur die
Implementierungsdateien selbst und das Export-Barrel. Implementiert und
vektorgetestet, aber nicht verdrahtet. Was die WoT-App real tut: Multi-Device
mit **derselben DID und demselben Seed**.

**3. Die Trust-Score-Trennung ist stärker belegt als „null Treffer".**

- `02-wot-trust/README.md:51`: „**Nicht im Trust Core enthalten** sind …
  Trust-Score-Algorithmen"
- `02-wot-trust/README.md:60`: „Quantitative Bewertung ist **Extension-Semantik,
  z.B. HMC**"
- `CONFORMANCE.md:151`: Selbst `wot-hmc@0.1`-Konformität erlaubt, Scores
  „**erzeugt oder sicher ignoriert**"

**4. ⭐ Die wichtigste neue Erkenntnis — betrifft die Priorisierung direkt**

**Web of Trust hat Multi-Device-Konsistenz gelöst, ohne Device-Keys zu haben.**
Per-Device-Inbox, Store-and-Forward, Generationen-Key-Rotation — alles auf dem
Shared-Seed-Modell.

Folge für N.E.X.U.S.: **TD-33** (divergierende Zellmitglieder Android/Windows)
und **TD-46** (Idempotenz) sind **Sync-Probleme, keine Identitätsprobleme**.
Sie sind lösbar, *bevor* ADR-0002 entschieden ist.

Das entkoppelt zwei Dinge, die im Briefing (§22) noch zusammenhingen:

| Frage | Charakter |
|---|---|
| Multi-Device-**Konsistenz** (TD-33, TD-46) | akuter, spürbarer Schmerz — ohne Device-Keys lösbar |
| Person ≠ Gerät als **Identitätsmodell** (ADR-0002) | Datenmodell-Grundsatz — wichtig, aber kein akuter Schmerz |

**5. AETHER-Dokument:** Es gibt zwei Versionen. Die aktuelle ist
`AETHER_v1.0_P0_ARCHITECTURE_MASTER_002.docx` (129 Seiten). Anhang B.1 ist
identisch zur älteren Fassung **plus ein Eintrag** (realmübergreifender
Genesis-Claim) — der Prüfbericht wurde bereits umgesetzt.

---

## Der Dokumentensatz

### Kern — das braucht ChatGPT auf jeden Fall

| Datei | Was drin steht | Warum nötig |
|---|---|---|
| [`planning/ANTWORT_ARCHITEKTUR_BRIEFING.md`](ANTWORT_ARCHITEKTUR_BRIEFING.md) | Architektenantwort in 3 Teilen: §50-Fragen, Widerspruch, **Kooperationsbewertung + 14 Fragen an Anton** | Das Hauptdokument für die Kooperationsdiskussion |
| [`planning/NOW_NEXT_LATER.md`](NOW_NEXT_LATER.md) | Entscheidungsvorlage: Release-Blocker, die 5 ADRs, Zurückgestelltes | Die operative Priorisierung |
| [`research/WEB_OF_TRUST.md`](../research/WEB_OF_TRUST.md) | Vollständige Analyse inkl. aller Belege und Zitate | Faktengrundlage; **wurde zuletzt überarbeitet** |

### Kontext — hilfreich, aber nicht zwingend

| Datei | Was drin steht |
|---|---|
| [`planning/ARCHITEKTUR_BRIEFING_2026.md`](ARCHITEKTUR_BRIEFING_2026.md) | Das Original-Briefing (ChatGPT hat es selbst verfasst — nur zur Referenz) |
| [`planning/BRIEFING_ABDECKUNG.md`](BRIEFING_ABDECKUNG.md) | Welche der 50 Briefing-Punkte erfüllt/offen sind |
| [`current/ARCHITECTURE_REALITY.md`](../current/ARCHITECTURE_REALITY.md) | Die 8 Code-Befunde zur OneApp mit Belegen |
| [`research/REAL_LIFE_STACK.md`](../research/REAL_LIFE_STACK.md) | RLS-Analyse; enthält das Relation-Record-Muster |
| [`decisions/`](../decisions/) | Die 5 ADRs im Volltext |

### Nicht nötig für diese Diskussion

`SOURCELESS.md` (abgeschlossen: Gegenbeispiel, kein Vorbild),
`EVENT_MAP.md`, `DO_NOT_TOUCH.md`, `TECH_DEBT.md` — technische Details ohne
strategischen Beratungsbedarf.

---

## Was verifiziert ist und was nicht

Damit ChatGPT weiß, worauf es sich verlassen kann:

### Hart verifiziert (Code gelesen, nachgerechnet, Zitat belegt)

- Schlüsselableitung beider Projekte — **nachgerechnet gegen Testvektor**
- Trust-Score liegt in `wot-hmc@0.1`, nicht im Kern — **wörtliches Zitat**
- Device Delegation ist Phase-2-Entwurf, Widerruf best-effort — **wörtliches Zitat**
- `DeviceKeyBinding` hat null Anwendungsaufrufer — **Codesuche**
- N.E.X.U.S.-Release-Blocker F-001, F-002, TD-39 alle offen — **Codesuche**
- AETHER Anhang B.1 schließt globale Scores aus — **Dokumentextraktion**
- Lizenzen: WoT/RLS/HMC = MIT, `wot-spec` = CC BY 4.0, OneApp = AGPL-3.0

### Nicht verifiziert / offen

- **Ob Anton kooperieren will** — reine Gesprächsfrage
- **Wie viele Menschen real an den drei Projekten arbeiten** — Frage 11
- **Ausgang des NGI-Zero-Antrags** — Frage 12
- **Ob HMC und AETHER inhaltlich zusammenpassen** — nur oberflächlich verglichen
- **Reifegrad von `wot-spec`** — bezeichnet sich selbst als Draft, Breaking
  Changes bis v1.0 vorgesehen
- **Strategische Dimension insgesamt** — Bewegung, Reichweite, Finanzierung,
  Glaubwürdigkeit. Das kann ich nicht beurteilen, und genau dort liegt
  ChatGPTs Beitrag.

---

## Wo ChatGPT tatsächlich beraten sollte

Die technischen Fragen sind weitgehend geklärt. Offen und **strategisch** sind:

1. **Lohnt die Kooperation überhaupt?** Zwei Projekte mit Bus-Faktor eins
   ergeben zusammen nicht Bus-Faktor zwei. Koordination kostet Joachims
   knappste Ressource.

2. **Was ist die Verhandlungsposition?** N.E.X.U.S. bringt Governance
   (fertig, 596 Tests), infrastrukturfreies BLE/LAN und Flutter-Reichweite.
   Die Allianz bringt Protokollreife bei Sync, Capabilities, ACK.

3. **Wie umgehen mit dem Lizenzunterschied?** MIT → AGPL geht, umgekehrt
   nicht. `wot-spec` steht unter CC BY 4.0 — Spezifikationskooperation ist
   davon unberührt. Handhabbarer Rahmen, kein Blocker. Ist das für beide Seiten
   tragfähig?

4. **Wie den HMC-Trust-Score ansprechen?** Es ist *kein* Konflikt mit Web of
   Trust selbst, sondern mit einer optionalen Extension. AETHER hat für sich
   bereits dagegen entschieden. Einbringen oder erstmal nur zuhören?
   Gesprächston kann entspannt sein: „Euer relationaler Core passt gut zu
   unserem Ansatz; bei der optionalen HMC-Bewertungslogik gehen wir mit AETHER
   bewusst teilweise einen anderen Weg."

5. **Reihenfolge:** Gespräch jetzt führen oder erst die Release-Blocker
   abarbeiten? Meine Empfehlung: Gespräch kostet nichts und kann parallel
   laufen — aber **keine Implementierung** vor NOW.

6. **Timing gegenüber `wot-spec`-Reife:** Die Spec ist Draft mit angekündigten
   Breaking Changes. Lesen und lernen ja, Kompatibilitätsprototyp eventuell,
   unumkehrbare Abhängigkeit nein.

---

## Kurzfassung für ChatGPT (falls nur ein Absatz weitergegeben wird)

> Web of Trust, Real Life Stack und Human Money Core sind eine bestehende
> Allianz mit gemeinsamer, sprachunabhängiger Protokollspezifikation
> (`real-life-org/wot-spec`, CC BY 4.0, Draft) und Test-Vektoren. N.E.X.U.S.
> und Web of Trust haben unabhängig denselben Krypto-Stack gewählt
> (Ed25519/X25519/AES-256-GCM/BIP-39/did:key); die Identitätsableitung
> unterscheidet sich in genau einem Schritt (HKDF vs. SLIP-0010), was
> nachgerechnet wurde. Kooperation ist über die **Spezifikation** möglich,
> nicht über Code (TypeScript vs. Flutter, MIT vs. AGPL). Die Allianz ist bei
> Sync, Capabilities und ACK-Semantik weiter; N.E.X.U.S. hat Governance und
> infrastrukturfreies Offline. Kein Wertekonflikt mit dem WoT-Kern — der
> aggregierte Trust-Score ist eine optionale HMC-Extension, und AETHER hat
> gegen globale Scores bereits selbst entschieden. Beide Seiten haben
> Bus-Faktor eins. Vor jeder Umsetzung stehen vier Release-Blocker
> (F-001, F-002, F-003, TD-39).
