# N.E.X.U.S. OneApp — Tech-Debt-Liste

Stand: nach G2.1.6 / Liquid Democracy Release-Anker

Diese Liste dokumentiert bekannte technische Schulden, bewusste Scope-Cuts und Architekturpunkte, die vor einem produktiven Release geprüft oder bereinigt werden sollten.

## TD-25 — Bestehende UI-/Navigation-Test-Failures

**Status:** offen  
**Priorität:** mittel  
**Phase:** vor Release-Härtung

Einige bestehende UI-/Navigation-Tests schlagen bereits unabhängig von G2 fehl. Diese Fehler sind nicht durch Liquid Democracy entstanden, sollten aber vor einem breiteren Release bereinigt oder bewusst dokumentiert werden.

---

## TD-28 — `publish_results.vote_id` wird polymorph genutzt

**Status:** offen  
**Priorität:** mittel  
**Phase:** vor produktivem Release

Das Feld `vote_id` in `publish_results` wird nicht mehr ausschließlich für Vote-IDs genutzt, sondern je nach Event-Kind auch für andere Payload-IDs, z. B. DecisionRecord-IDs oder Delegation-IDs.

**Risiko:**  
Die Spaltensemantik ist unklar und kann spätere Wartung erschweren.

**Mögliche Lösung:**  
Sammel-Migration: `vote_id` in `payload_id` umbenennen und zusammen mit `event_kind` sauber als generische Publish-Queue-Referenz modellieren.

---

## TD-32 — `allVotes` auf Empfänger-Geräten leer

**Status:** offen  
**Priorität:** mittel bis hoch  
**Phase:** vor produktivem Release

`handleIncomingDecisionRecord` setzt `allVotes` derzeit auf `const []`. Dadurch hat nur das Tally-Owner-Gerät die vollständige Vote-Liste inklusive Synthetic Votes aus Liquid Democracy. Empfänger-Geräte fallen in der Ergebnisanzeige auf lokale `proposal_votes` / `getVotes()` zurück.

**Auswirkung:**  
Delegierte Stimmen sind auf Empfänger-Geräten in der Detail-Liste nicht vollständig sichtbar, auch wenn das Tally-Ergebnis korrekt ist.

**Mitigation:**  
G2.1.4b nutzt einen Fallback: Wenn `DecisionRecord.allVotes` leer ist, wird `getVotes()` verwendet.

**Mögliche Lösung:**  
`allVotes` aus dem DecisionRecord-Wire-Content auch auf Empfänger-Geräten persistieren.

---

## TD-33 — Cell-Membership-Sync-Inkonsistenz

**Status:** offen  
**Priorität:** mittel  
**Phase:** vor Release-Härtung

Im Live-Test sah Android 4 Cell-Mitglieder, Windows aber nur 2. Für Tallys wird diese Inkonsistenz durch den eingefrorenen `eligibleVoters`-Snapshot abgefangen.

**Auswirkung:**  
Die Abstimmung selbst bleibt korrekt, aber UI-Anzeigen und Mitgliederlisten können geräteabhängig unterschiedlich wirken.

**Mögliche Lösung:**  
Cell-Membership-Sync und Empfangs-/Persistenzpfade prüfen. UI sollte für Tally-relevante Anzeigen möglichst den eingefrorenen Snapshot oder DecisionRecord-Daten nutzen.

---

## TD-34 — `eligibleVotersCount` fehlt im DecisionRecord

**Status:** offen  
**Priorität:** mittel  
**Phase:** vor produktivem Release

Der `DecisionRecord` enthält aktuell `participation`, aber kein eigenes Feld `eligibleVotersCount`. Die Beteiligungsanzeige muss deshalb den Nenner aus `participation` zurückrechnen.

**Auswirkung:**  
Mathematisch möglich, aber fragiler als ein expliziter Wert.

**Mitigation:**  
G2.1.4c rechnet den Nenner aus `num / participation` zurück.

**Mögliche Lösung:**  
`eligibleVotersCount` als reguläres Feld in Modell, DB, Wire-Format und Hash-Input aufnehmen.

---

## TD-35 — Release-Dokumentation / Bedienungsanleitung

**Status:** offen  
**Priorität:** hoch  
**Phase:** Release-Anker nach Liquid Democracy

Nach Abschluss von G2.1.6 braucht die App eine verständliche Bedienungs- und Erklärdokumentation für Pioniere.

**Inhalte:**
- Was ist Liquid Democracy?
- Wie delegiere ich eine Stimme?
- Wie widerrufe ich eine Delegation?
- Was passiert, wenn der Delegate nicht abstimmt?
- Was bedeuten die Ergebnisanzeigen?
- Welche Funktionen sind noch nicht enthalten?