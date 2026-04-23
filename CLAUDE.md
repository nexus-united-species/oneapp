# CLAUDE.md – N.E.X.U.S. OneApp (Architektur & KI-Instruktionen)

## ⛔ KRITISCHE ENTWICKLUNGSREGELN — ABSOLUTE VERBOTE
Diese Regeln verhindern Datenverlust. Sie sind NICHT verhandelbar.

1. **NIEMALS `flutter clean` vorschlagen oder ausführen.** Löscht SharedPreferences auf Windows (Datenverlust bei Tombstones/Settings). Bei Build-Problemen: Logs anfordern, andere Lösung suchen.
2. **NIEMALS `adb uninstall` oder `flutter install` verwenden.** Immer `flutter run` für Updates. Uninstall löscht den Android Keystore (Totalverlust der ungesicherten Identität).
3. **NIEMALS bestehende Datenbanken/Tabellen löschen oder neu erstellen.** Bei Migrationen IMMER `CREATE TABLE IF NOT EXISTS` und `ALTER TABLE` nutzen. `DROP` oder `DELETE FROM` auf Struktur-Ebene ist verboten.
4. **NIEMALS "Nuclear Wipe" oder "App-Daten löschen" als Standard-Fix vorschlagen.** Erst Diagnose via Logs, dann gezielter Fix.
5. **Kein Code-Push ohne vorherigen Gerätetest (`flutter run`).**

## 🧩 DEZENTRALE ARCHITEKTUR & SYNC-GESETZE
N.E.X.U.S. ist Offline-First, P2P und asynchron. Nostr-Relays sind nur dumme Pipes.

1. **SYNCHRONES STATE-LOCKING (Async Gaps schließen):** Nostr-Events fliegen parallel ein. Wenn du ein Event empfängst (`handleIncoming...`), MUSS das In-Memory-Objekt (z.B. in einer Map `_proposals[id] = p`) **SYNCHRON VOR DEM ERSTEN `await`** gespeichert werden. Sonst überschreiben parallele Relays die DB und erzeugen Phantom-Einträge.
2. **LISTENER VOR TRANSPORT-START:** Streams (`.listen()`) müssen IMMER registriert werden, **bevor** der Transport (`_manager.start()`) oder Nostr-Keys initialisiert werden, sonst kommt es zu Event-Drops beim Startup.
3. **NIP-01 e-Tag Pflicht:** Ein `e`-Tag MUSS immer eine 64-Hex Nostr-Event-ID sein. Keine UUIDs in `e`-Tags! Für interne UUIDs immer Custom-Tags (z.B. `proposal_id`) verwenden.
4. **Zustands-Validierung:** Bei jedem Nostr `publish()` MUSS die Antwort des Relays verarbeitet/geloggt werden (`[RELAY-OK]`). Keine stillen Fails.

## 🛡️ SECURITY & SAFETY AUDIT
1. **Kein Klartext:** Alle privaten Daten in der SQLite-DB (`PodDatabase`) MÜSSEN AES-256-GCM verschlüsselt in der `enc`-Spalte landen.
2. **Keine hardcoded Keys:** Private Keys gehören nur in den Memory oder Secure Storage, nie in Logs oder SharedPreferences.
3. **Constant Time Crypto:** Kryptografische Operationen (X25519, Schnorr) dürfen nicht durch naive Dart-Schleifen implementiert werden (Timing-Attacks).
4. **AETHER Nomenklatur:** Nutze Projekt-Begriffe für neue Wert-Module: `energyToken`, `vitaBalance`, `valueExchange`. NIEMALS `money`, `payment`, `price`.

## 🌍 SPRACHE & TERMINOLOGIE (User-Facing)
- **Immer:** "Menschheitsfamilie" (nie "System"/"Gesellschaft")
- **Immer:** "N.E.X.U.S." (mit Punkten)
- **Immer:** "Zellen", "Anträge", "Dorfplatz", "Pioniere"
- **Zwingend:** Echte Umlaute (ä, ö, ü, ß) in UI-Texten und Commits. Keine Umschriften. (Code-Kommentare bleiben Englisch).

## 🧪 TEST- & RELEASE-WORKFLOW
Joachim (der Tester) liest keine Live-Logs im Terminal.
- **Logfiles erzeugen:** `flutter run > test-name.txt 2>&1` (bzw. `-d windows`).
- **Aussagekräftige Präfixe:** Nutze `[CELL-CREATE]`, `[PUBLISH]`, `[ZOMBIE-DIAG]` in `print()` Statements zur schnellen Fehlerfindung.
- **Eine Sache pro Prompt:** Erst loggen/diagnostizieren, dann fixen, dann verifizieren. Keine Sammelfixes.

### Release-Prozess:
1. Version in `pubspec.yaml` erhöhen (`X.Y.Z+B`).
2. Version in `installer\windows_setup.iss` aktualisieren.
3. Builds: `flutter build apk --release` & `flutter build windows --release`.
4. Commit: `git commit -m "chore: bump version to vX.Y.Z"`.
5. Push: `git push origin master:main`.
6. Installer bauen: `installer\build_installer.bat`.
7. GitHub Release erstellen (Tag `vX.Y.Z-alpha`, Assets hochladen).

## 🤖 SELBST-VERIFIKATION (Vor jedem Commit zwingend!)
Prüfe deinen geschriebenen Code selbst:
1. `flutter analyze` fehlerfrei?
2. `flutter test` bricht keine Bestands-Tests?
3. Wurde `notifyListeners()` nach State-Änderungen gerufen?
4. Wurden neue StreamController mit `dispose()` versehen?
5. Sind Async-Gaps vor DB-Writes synchron im RAM gelockt?
-> Erst wenn alles "Ja", darf committed werden. Bei Unklarheiten: Nachfragen!

## 📌 TECH-STACK & VISION
- **Ziel:** Dezentrales Betriebssystem für die Menschheitsfamilie (Protokoll, keine Plattform).
- **Stack:** Flutter/Dart, SQLite (Proto-POD, verschlüsselt), GoRouter, Provider.
- **Transport:** Nostr (primär, NIP-konform), BLE Mesh, LAN Discovery. Offline-First ist Gesetz.
- **Identität:** BIP-39 Seed Phrase, Ed25519/SLIP-0010, did:key W3C.
- **Aktueller Fokus:** G2 Governance (Liquid Democracy, Quadratic Voting, Subsidiarität).