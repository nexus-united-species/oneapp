# N.E.X.U.S. OneApp – Tech Debt

Stand: 13. November 2026 (neu gegliedert nach Audit D-2)
Basis: Codeprüfung, Audits Juli und November 2026, Gerätetests bis 13.11.2026

Diese Datei zeigt nur den **aktuellen Stand**: was offen ist. Was wann
behoben oder geändert wurde, steht im
[Verlauf](../archive/TECH_DEBT_VERLAUF.md); neue Änderungen kommen dort
unten dazu, hier wird die betroffene Zeile angepasst oder gestrichen.
Gerätetests: [GERAETETESTS_OFFEN.md](GERAETETESTS_OFFEN.md). Reihenfolge der
Arbeit: [NOW_NEXT_LATER.md](../planning/NOW_NEXT_LATER.md).

## Blockiert breiten Einsatz

| ID | Thema | Stand und nächster Schritt |
|---|---|---|
| R-1 | Android-App mit dem Debug-Schlüssel signiert | Debug-Keystore am 13.11.2026 gesichert (Prüfwerte in der Sicherung). Wechsel auf echten Release-Schlüssel einmalig vor der Öffnung, nach Backup-Export und Prüfung der zwölf Wörter bei allen Testern |
| S-1-Ende | Übergangszeit: Nachrichten ohne Identitätsnachweis werden nur gekennzeichnet | nach einer Version DMs, Präsenz und Kanalbeiträge ohne Nachweis verwerfen |
| S-5 | Direktnachrichten außen NIP-04 (AES-CBC ohne Authentisierung, Metadaten sichtbar) | ein Nachrichtenformat NIP-17/NIP-44 als ADR (Block 4) |
| S-6 | Eigene secp256k1-Rechnung in reinem Dart (Sperrstufe 1) | Punktprüfung in `computeSharedSecret`; Wechsel auf geprüfte Bibliothek als eigener Schritt |
| TD-42 | Governance-Daten im Klartext | Anträge, Stimmen und Delegationen mit DID/Pseudonym liegen öffentlich auf Relays; Entscheidung zur Vertraulichkeit offen |
| TD-61-Rest | Hosting bleibt GitHub Raw | kein eigenes Update-Hosting (vorerst keine Priorität, Signatur deckt das Vertrauensproblem bereits ab) |

## Hoch – vor breiter Nutzung

| ID | Thema | Stand |
|---|---|---|
| TD-32 | `allVotes` auf Empfängergeräten leer | bewusster Phase-4.5c-Scope-Cut (dokumentiert in `proposal_detail_screen.dart`); Fallback auf lokale Votes zeigt direkte Stimmen korrekt, nur delegierte Detailstimmen fehlen in der Liste; Summen/Ergebnis sind unberührt |
| TD-33-Rest | Mitgliederliste und Übergabe | Moderatoren-Änderungen erreichen andere über die Liste erst, wenn der Gründer online ist; ein Gerät, das die Zelle neu entdeckt, kennt eine Übergabe erst nach der ersten Mitgliederliste. „Moderatorenrolle entziehen“ fehlt; Übergabe in der Oberfläche versteckt (Zahnrad, lange drücken) |
| TD-37/38/41 | Eingefrorene Liste, Retry, eigene Auszählung (09.11.2026) | Gerätetests offen; Hash-Kette bleibt geräteabhängig und ist keine Manipulationsprüfung |
| TD-43 | Backup-Restore stellt Zellmitgliedschaften nicht vollständig her | Restore kann Gemeinschaft zeigen, aber lokale Mitgliedschaft verlieren |
| TD-62 | Keine Mehrsprachigkeit | rund 1.500 deutsche Texte fest im Code; Ziel DE, EN, ES, FR, RU |
| TD-68 | Reaktion und Löschen am Desktop kaum erreichbar | Nachrichtenmenü nur per langem Drücken; Rechtsklick fehlt |
| Verlauf-Neu | Neues Gerät zeigt ältere Nachrichten nicht | Gerätetest 12.11.2026 (Laptop2): nur die letzten Stunden erscheinen, obwohl ältere auf den Relays liegen. Verdacht: Nachrichten kommen vor den Kontakten an. Zurückgestellt; braucht Log aus dem Release-Build (Protokoll-Schalter) |
| S-4-Rest | Neuer Kanalschlüssel nur bei bekanntem Verschlüsselungsschlüssel | Mitglieder ohne bekannten Schlüssel erhalten den neuen Kanalschlüssel nicht (Hinweis an den Admin, neu einladen); Beitritt per Annahme oder Einladung setzt die früheren Schlüssel zurück; Beiträge von Mitgliedern, die noch mit dem alten Schlüssel senden, kann der Entfernte weiter lesen, bis sie den neuen haben |
| Z-4-Rest | „Gesendet“ heißt beim Relay angekommen | keine Empfangsbestätigung vom Empfänger (kommt mit dem Nachrichtenformat in Block 4); #mesh-Rundrufe zählen nach der Übergabe sofort als gesendet; erneut gesendete Bilder im Kanal werden neu komprimiert, Antwortzitate gehen beim erneuten Senden von Medien verloren |
| Z-5-Rest | Warteschlange | „angenommen“ heißt ein Relay hat angenommen, nicht alle; kein Backoff beim Nachsenden; Warteschlange hält höchstens 7 Tage |
| Z-6-Rest | Relay-Verbindung | nach jedem Reconnect werden alle Filter mit dem `since` des Sitzungsstarts neu gesendet (mehr Daten als nötig, Doppelte verwirft die Datenbank); der Android-Hintergrunddienst hat eigene Verbindungen ohne Ping |

## Mittel

| ID | Thema | Hinweis |
|---|---|---|
| TD-25 | LAN-Discovery-Tests hängen vom Netz ab | rot, solange eine Windows-App im selben Netz läuft (sie empfangen deren echte Ankündigung auf UDP 51000); sonst ist die Suite grün (13.11.2026: 1838 Tests). Für CI die Tests vom echten Netz trennen |
| TD-28 | `publish_results.vote_id` polymorph | später in `payload_id` umbenennen |
| TD-46 | Geräteübergreifende Idempotenz teils in SharedPreferences | nach Reset/Zweitgerät sind doppelte Auto-Aktionen möglich; laut [ADR-0002](../decisions/ADR-0002-geraet-und-person.md) auch ohne Geräte-Identität lösbar, aber eigener, noch nicht geschnittener Schritt |
| TD-47-Rest | `nos.lol` begrenzt Events auf 128 KB | große Bilder erreichen nur die anderen Relays, bis TD-64 |
| TD-48 | Governance-Sync mit begrenzten `since`-Fenstern | längere Offline-Zeiten können Historie unvollständig machen (Z-9) |
| TD-64 | Medien inline als Base64 in Events | keine Videos oder Dateien; Lösung über Medienserver (Blossom) |
| Voice-Win | Sprachnachrichten kurz | seit 17.11.2026 AAC unter Windows und Aufnahme-Stopp vor der Größengrenze: Windows DM 17 s, Kanal 23 s; Android DM 53 s, Kanal 70 s (Gerätetest offen). Längere Nachrichten erst mit Medienserver (TD-64) |
| TD-78 | Keine Anmeldung nach NIP-42 am eigenen Relay | DMs sind für jeden abrufbar, der den Empfänger kennt (Block 4) |
| S-3-Rest | LAN | Inhalt ohne bekannten Schlüssel weiter unverschlüsselt; UDP-Ankündigung nennt die DID ungeprüft (nur Erreichbarkeit) |
| Z-8 | BLE und LAN sind Direktverbindungen | kein Weiterleiten (Mesh-Zweig) |

## Wartbarkeit

| ID | Thema | Nächster kleiner Schritt |
|---|---|---|
| TD-49 | Große zentrale Services | Reihenfolge und Grenze in [ADR-0005](../decisions/ADR-0005-dateigroesse.md) |
| TD-53 | Zwei Identitätsschlüssel | `did:key` und Nostr-Schlüssel nicht umrechenbar; Bindung über den Identitätsnachweis ([ADR-0001](../decisions/ADR-0001-identitaets-identifier.md)) |
| TD-54 | Kein Gerätekonzept auf Identitätsebene | kein Einzelwiderruf möglich ([ADR-0002](../decisions/ADR-0002-geraet-und-person.md)) |
| TD-55 | Persistenz reicht bis in die Widget-Ebene | [ADR-0004](../decisions/ADR-0004-storage-grenze.md) |
| TD-56 | Zustellsemantik an Nostr gebunden | [ADR-0003](../decisions/ADR-0003-zustellsemantik.md) |
| TD-50 | Debug-/Reparaturprimitive in Produktcode | in gekennzeichneten Wartungsbereich verschieben |
| TD-51 | Dichtes `print`-Logging | Präfixe katalogisieren und schrittweise strukturieren |
| TD-52 | `lib.zip`/Code-Dumps im Arbeitsumfeld | nur im Archiv halten |
| Grünes Häkchen | Häkchen an Nachrichten zeigt nur, dass eine Signatur mitgeschickt wurde | auf Nostr-Nachrichten die Signatur prüfen oder Häkchen an den Prüfstatus koppeln |

## Kürzlich geschlossen (Einzelheiten im Verlauf)

- 12.11.2026 am Gerät bestätigt: eigenes Relay (TD-47), Kontoumzug ohne
  Backup (TD-58/59), eigene DMs auf dem Zweitgerät (TD-57), Kontaktabgleich
  (TD-60), Gründer-Übergabe netzweit (TD-33), Zellauflösung durch
  Superadmin.
- 11.–13.11.2026 umgesetzt, Gerätetest offen: Audit C-1 bis C-3, S-1 (drei
  Schritte), S-2, S-3/C-4, S-4 (Medien und neuer Kanalschlüssel beim
  Entfernen), Z-1/Z-2.
- 13.11.2026: Debug-Keystore gesichert (R-1, Teil 1); Dokumentation
  berichtigt (D-1, D-2), Verlauf ausgelagert; `version.json` signiert
  (TD-61); 5 rote Tests repariert; CI angelegt; Chat ohne Bluetooth (Z-7);
  Zustellstatus für alle Nachrichtenarten (Z-3/Z-4); Warteschlange für alle
  wichtigen Ereignisse (Z-5); Relay-Reconnect mit Backoff und Ping (Z-6);
  Stufe-B-Restpunkte Teil 1 (TD-44, TD-45, TD-65, TD-71), Gerätetest offen.

## Quellen

- [Architektur-Ist-Zustand](ARCHITECTURE_REALITY.md)
- [Was nicht angefasst werden sollte](DO_NOT_TOUCH.md)
- [Architekturentscheidungen](../decisions/)
- [Audit Lauf A](../audits/2026-07/AUDIT_LAUF_A.md)
- [Audit Lauf B](../audits/2026-07/AUDIT_LAUF_B.md)
- [Projektstatus](PROJECT_STATUS.md)

