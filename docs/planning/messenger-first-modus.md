# Analyse: Messenger-First-Modus für N.E.X.U.S. OneApp

**Erstellt:** 2026-05-20  
**Autor:** N.E.X.U.S. KI-Assistent  
**Version:** 1.0 (reine Analyse, kein Code geändert)  
**Status:** Entwurf / offene Produktentscheidung — nicht umgesetzt  
**Letzte Einordnung:** 2026-07-15; erst nach dem Release-Härtungsblock neu priorisieren

---

## Executive Summary

Die N.E.X.U.S. OneApp ist technisch bereits modular genug, um einen
„Messenger-First-Modus" (M1) einzuführen — **ohne Code zu löschen, Tabellen
zu droppen oder bestehende Nutzer zu beeinträchtigen.** Alle Governance-,
Dorfplatz- und Zellen-Funktionen bleiben im Hintergrund vollständig erhalten.

Der Kern-Eingriff ist minimal:
1. Ein neuer `AppModeService` (SharedPreferences-Key `"app_mode"`) speichert,
   ob ein Gerät im Modus `"simple"` oder `"full"` läuft.
2. Nur **Sichtbarkeit** und **Reihenfolge** von Tabs und Tiles werden
   konditionell gesteuert — keine Route wird gelöscht.
3. Bestehende Nutzer erhalten Default `"full"` → nichts verschwindet.
4. Neuinstallationen starten in `"simple"`.

Die fünf kritischsten Code-Stellen sind:
- `lib/core/router.dart` — Tab-Reihenfolge und ShellRoute-Definition
- `lib/shared/widgets/nexus_scaffold.dart` — Tab-Bar-Rendering
- `lib/features/discover/discover_screen.dart` — Tile-Sichtbarkeit
- `lib/features/dashboard/dashboard_screen.dart` — Karten-Reihenfolge
- `lib/features/onboarding/onboarding_screen.dart` — Begriffe im Erstkontakt

**Gesamtaufwand** für M1-Rollout ohne Funktionsverlust: **mittel** (ca. 5–7
fokussierte Einzel-Prompts nach dieser Analyse).

---

## 1. Aktuelle Navigation

### Ist-Zustand

**Bottom-Tab-Leiste** (NexusScaffold, ShellRoute in `lib/core/router.dart`):

| Index | Route       | Bezeichnung | Typ                  |
|-------|-------------|-------------|----------------------|
| 0     | `/home`     | Dashboard   | Messenger + Governance gemischt |
| 1     | `/chat`     | Chat        | Messenger-Kern |
| 2     | `/dorfplatz`| Dorfplatz   | Social Feed (3 Sub-Tabs) |
| 3     | `/discover` | Entdecken   | Hub-Grid für alle Funktionen |
| 4     | `/profile`  | Profil      | Identität/Einstellungen |

**Full-Screen-Routen** (außerhalb ShellRoute, via GoRouter):
- Onboarding: `/onboarding`, `/onboarding/restore`, `/onboarding/restore-backup`
- Backup: `/backup-setup`
- Principles: `/principles/intro`, `/principles/content`, `/principles/commitment`
- Governance: `/governance` (Agora)
- Zellen: `/cell-hub`, `/request-cell-permit`
- Utility: `/settings`, `/contacts`, `/qr-scanner`, `/contact-requests`, `/invite`
- Wallet: `/wallet` (Platzhalter)

**Messenger-relevante Routen:** `/chat`, `/contacts`, `/qr-scanner`,
`/contact-requests`, `/invite`, `/profile`

**Governance-relevante Routen:** `/governance`, `/cell-hub`,
`/request-cell-permit`, `/dorfplatz` (Tab „Meine Zelle")

**Trennlinie M1 vs. M2–M4:**
```
M1 (Messenger):  /home, /chat, /contacts, /profile, /qr-scanner, /invite
M2 (Gemeinschaft): /dorfplatz, /cell-hub (Entdecken)
M3 (Selbstverwaltung): /governance, /request-cell-permit
M4 (Wirtschaft): /wallet (geplant)
```

Der Dorfplatz-Tab ist die einzige Position, an der M1 und M2 sich heute
überschneiden — er enthält sowohl Kontakt-Posts (M1-nah) als auch
Zellen-Posts (M2).

### Vorschlag

**M1-Tab-Leiste (umgeordnet, nichts gelöscht):**

| Index | Route        | Bezeichnung | Sichtbarkeit |
|-------|--------------|-------------|--------------|
| 0     | `/chat`      | Nachrichten | immer        |
| 1     | `/home`      | Übersicht   | immer        |
| 2     | `/dorfplatz` | Dorfplatz   | nur M2+      |
| 3     | `/discover`  | Entdecken   | immer (vereinfacht in M1) |
| 4     | `/profile`   | Profil      | immer        |

Im Simple-Modus: Chat kommt zuerst (primäre Aktion), Dorfplatz-Tab
ausgeblendet oder mit Badge „Bald verfügbar" versehen.

**Keine einzige Route wird gelöscht.** Im Simple-Modus sind die
Governance-Routen über Deep Links oder beim Upgrade weiterhin erreichbar —
sie erscheinen nur nicht in der Navigation.

---

## 2. Dashboard

### Ist-Zustand

`lib/features/dashboard/dashboard_screen.dart` zeigt aktuell:

**Kopfbereich:**
- Begrüßung (Guten Morgen/Tag/Abend) mit Pseudonym ✅ (M1-tauglich)
- Deutsches Datum ✅ (M1-tauglich)

**Karten (in ungefährer Reihenfolge):**
1. Mini-Radar (Live-Knotenanzahl, animiert) ⚠️ (technisch, Erstnutzer irritiert)
2. Nachrichten-Karte → `/chat` ✅
3. Kanäle-Karte ✅
4. Kontakte-Karte ✅
5. Governance/Agora-Karte → `/governance` ❌ (zu früh für M1)
6. Wallet-Karte (Coming Soon) ❌ (zu früh für M1)
7. Marktplatz-Karte (Coming Soon) ❌ (zu früh für M1)

**Alerts & Erinnerungen:**
- Kontaktanfragen-Badge ✅
- Feed-Updates ✅ (aber: was ist ein „Feed" für Erstnutzer?)
- Zellen-Updates ⚠️ (verwirrend in M1)
- Antrags-Updates ❌ (zu früh)
- Principles-Reminder ⚠️ (timing-kritisch)
- Backup-Reminder ✅ (wichtig für M1)

### Vorschlag

**M1-Dashboard-Reihenfolge (ohne Löschen, nur Umsortierung + konditionelle
Sichtbarkeit):**

```
1. Begrüßung (bleibt)
2. Nachrichten-Karte (aufgewertet, zuerst)
3. Kontakte-Karte
4. Kanäle-Karte
5. Backup-Reminder (prominent, bis Backup erledigt)
6. Mini-Radar (an letzter Stelle, kollabierbar oder nur im Full-Modus)
7. [Full-Modus only] Dorfplatz-Updates
8. [Full-Modus only] Governance/Agora-Karte
9. [Full-Modus only] Wallet/Marktplatz (Coming Soon)
```

Principles-Reminder: Timing von „sofort beim ersten Start" auf „nach erstem
Chat" verschieben — das schärft den ersten Eindruck.

---

## 3. Onboarding

### Ist-Zustand

`lib/features/onboarding/onboarding_screen.dart`, PageView mit 5 Schritten:

1. **Willkommen** — Neu starten / Wiederherstellen
2. **Seed-Generierung** — 12 BIP39-Wörter anzeigen
3. **Seed-Verifizierung** — 3 Zufallswörter eingeben
4. **Pseudonym** — Vergabe / Übernahme
5. **Abschluss** → `/home`

Danach (via Router-Redirect):
- `/backup-setup` — optional, aber empfohlen
- `/principles/intro` → `/principles/content` → `/principles/commitment`

**Problematische Begriffe für Erstnutzer:**
- „Menschheitsfamilie" (taucht in Principles-Screens auf) — für Messenger-Nutzer
  zu weltanschaulich im Erstkontakt
- „Zellen" (in Backup-Hinweis: „Deine Zellen-Mitgliedschaft…") — für M1 noch
  nicht relevant
- „Bauplan der Menschheitsfamilie" — Principles-Inhalt
- „Agora" — taucht in Discover-Grid auf, auch wenn noch nicht erreichbar

**Was gut ist:**
- Seed-Phrase-Flow ist sicherheitstechnisch korrekt und klar
- Pseudonym-Konzept ist für Messenger nachvollziehbar
- Kein Zwang zu Echtname

### Vorschlag

**M1-Onboarding-Flow (keine Screens gelöscht):**

```
Schritt 1: Willkommen → "Dein sicherer Messenger"
           (Untertitel: "Später entdeckst du mehr")
Schritt 2: Seed-Phrase (unverändert — Sicherheit ist Core)
Schritt 3: Seed-Verifizierung (unverändert)
Schritt 4: Pseudonym (unverändert)
Schritt 5: Abschluss → direkt zu /chat (nicht /home)

Backup-Setup: Direkt danach einblenden (unverändert)
Principles: Erst nach erstem Chat anzeigen, nicht vor /home
```

Begriffe im Onboarding für M1 anpassen:
- „Willkommen bei N.E.X.U.S." → „Dein dezentraler Messenger"
- Der Satz „Du wirst Teil der Menschheitsfamilie" → erst in Principles
- Principles-Commitment-Screen: unveränderter Inhalt, nur später im Flow

Die Principles-Screens selbst bleiben **unverändert** — nur der Zeitpunkt
ihrer Einblendung ändert sich.

---

## 4. Entdecken-Bereich

### Ist-Zustand

`lib/features/discover/discover_screen.dart`, Kachel-Grid in zwei Sektionen:

**Haupt-Kacheln (aktuell aktiv):**
- Kontakte → `/contacts` ✅ M1
- Kanäle → `/join-channels` ✅ M1
- Gemeinschaften → `/cell-hub` ⚠️ M2
- Marktplatz (Coming Soon) ❌ M4
- Einstellungen → `/settings` ✅ M1

**Sphären-Kacheln:**
- Agora (aktiv, Phase 1b) ❌ M3 — einzige aktive Sphäre
- Asklepios (Coming Soon) — M3+
- Paideia (Coming Soon) — M3+
- Demeter (Coming Soon) — M3+
- Hestia (Coming Soon) — M3+

### Vorschlag

**M1-Entdecken (konditionell, nichts gelöscht):**

```
Simple-Modus sichtbar:
  - Kontakte ✅
  - Kanäle ✅
  - Einstellungen ✅
  - [Neue Kachel] Gemeinschaft beitreten (Teaser, öffnet Erklärungstext)

Simple-Modus ausgeblendet (aber Route weiterhin erreichbar):
  - Gemeinschaften (Kachel ausgeblendet, Route /cell-hub bleibt)
  - Marktplatz (sowieso Coming Soon)
  - Agora
  - Alle weiteren Sphären
```

Ein Hinweis-Banner unter den Simple-Kacheln: „Mehr entdecken, wenn du bereit
bist →" öffnet eine Erklärungsseite zu M2–M4 (statisch, kein Router-Umbau).

---

## 5. Chat / Kontakte / Kanäle

### Ist-Zustand

**`conversations_screen.dart`** — zwei Tabs:
- Tab 0: Chats (DMs, #mesh pinned) ✅
- Tab 1: Kanäle (Gruppen-Channels, sortiert nach Aktivität) ✅

**`contacts_screen.dart`:**
- Volltextsuche, Kontaktdetail, QR-Scanner-Integration ✅
- Kontaktanfragen-Management ✅

**Reibungspunkte für Erstnutzer:**
- „#mesh"-Kanal ohne Erklärung — was ist das?
- „#nexus-global" pinned — ohne Kontext fremd
- Channel-Discovery-Liste zeigt ggf. Zellen-interne Kanäle (z.B.
  `#cell-<uuid>-bulletin`) — verwirrend wenn man noch in keiner Zelle ist
- Kontaktanfragen vs. normales Hinzufügen: Flow nicht selbsterklärend

**Was gut ist und erhalten bleiben muss:**
- DM-Verschlüsselung ist transparent (Nutzer muss nichts konfigurieren)
- FAB-Kontextualität (im Chat-Tab: neuer Chat, im Kanal-Tab: neuer Kanal) ✅
- Unread-Badges funktionieren korrekt ✅
- Kein Echtnamen-Zwang ✅

### Vorschlag

- Zellen-interne Kanäle (`#cell-*`) im Kanal-Tab im Simple-Modus ausblenden
  (nur anzeigen, wenn Nutzer bereits Zellen-Mitglied)
- Hilfetext für `#mesh` und `#nexus-global` direkt im UI als collapsed Banner
  (nutzt bestehenden `HelpIcon`-Mechanismus aus `help_texts.dart`)
- Kontaktanfrage-Flow: existing `contact_request`-Hilfetext aus `help_texts.dart`
  prominenter einsetzen

---

## 6. Dorfplatz

### Ist-Zustand

`lib/features/dorfplatz/dorfplatz_screen.dart`, 3 Sub-Tabs:
- Tab 0: **Kontakte** — Posts von Kontakten (M1-nah)
- Tab 1: **Meine Zelle** — Posts aus Zellen-Mitgliedschaft (M2)
- Tab 2: **Entdecken** — Öffentliche Posts (M2)

Sichtbarkeits-Level bei Posts: Kontakte / Meine Gemeinschaft / Öffentlich

### Konzeptionelle Einordnung

Der Dorfplatz ist **hybrid**: Tab 0 (Kontakte-Feed) gehört konzeptionell zu M1
(Nachrichten/Verbindungen), Tabs 1 und 2 gehören zu M2.

**Für M1-Nutzer** ohne Zellen-Mitgliedschaft ist Tab 1 leer und Tab 2
zeigt unbekannte öffentliche Posts ohne Community-Kontext.

### Vorschlag

**Option A (empfohlen):** Dorfplatz-Tab im Simple-Modus ausblenden.
Stattdessen: Kontakte-Feed-Tab in Chat-Bereich integrieren als dritten
Sub-Tab „Neuigkeiten" (später, als separater Prompt).

**Option B:** Dorfplatz-Tab bleibt sichtbar, aber im Simple-Modus wird
nur Tab 0 (Kontakte) angezeigt. Tabs 1+2 sind mit „Ab Gemeinschafts-Modus
verfügbar" versehen.

Option A ist sauberer aber aufwendiger. Option B ist minimalinvasiv.

**Einführungstext für Erstnutzer (im Dorfplatz, bei erster Öffnung):**
„Der Dorfplatz ist dein öffentlicher Austauschort. Wenn du einer Gemeinschaft
beitrittst, siehst du hier auch deren Beiträge."

---

## 7. Zellen / Governance

### Ist-Zustand

**UI-Einstiegspunkte zu Zellen/Governance heute:**
- Dashboard: Governance/Agora-Karte
- Discover-Tab: Kacheln „Gemeinschaften" und „Agora"
- Dorfplatz Tab 1: „Meine Zelle"
- Direkt-Route: `/governance`, `/cell-hub`
- Settings: Admin-Bereich (nur für Superadmin sichtbar) — konditionell bereits implementiert!

**Bestehende konditionelle Logik (Vorbild für App-Modus):**
In `settings_screen.dart` gibt es bereits einen konditionellen Admin-Bereich,
der nur für Superadmins erscheint. Dieses Muster ist der exakte Mechanismus,
den wir für den App-Modus brauchen.

**Was für bestehende Zellen-Mitglieder erhalten bleiben muss:**
- Alle Proposals, Votes, Delegationen: vollständig in SQLite gespeichert ✅
- Notification über Proposals läuft über `ProposalService` (unabhängig von UI) ✅
- Beim Wechsel von Simple → Full: alles sofort wieder sichtbar ✅

### Vorschlag

**Hinter Modus-Schalter verbergbare UI-Elemente (Simple-Modus):**

| Element | Datei | Aktion |
|---------|-------|--------|
| Agora-Karte auf Dashboard | `dashboard_screen.dart` | `if (mode == full)` |
| Governance-Kachel in Discover | `discover_screen.dart` | `if (mode == full)` |
| Gemeinschaften-Kachel in Discover | `discover_screen.dart` | `if (mode == full)` |
| Dorfplatz Tab 1 „Meine Zelle" | `dorfplatz_screen.dart` | `if (mode == full)` |
| Dorfplatz-Tab insgesamt | `nexus_scaffold.dart` | `if (mode == full)` |

**Für bestehende Zellen-Mitglieder:** Default-Modus `"full"` beim Upgrade →
kein einziges Element verschwindet. Nur Neuinstallationen starten in `"simple"`.

**Nahtloser Übergang:** Wenn ein Simple-Nutzer eine Einladung zu einer Zelle
annimmt (via `/invite/redeem`), wird der App-Modus automatisch auf `"full"`
hochgesetzt (oder zumindest ein Overlay gezeigt).

---

## 8. Einstellungen und Hilfetexte

### Ist-Zustand

`lib/features/settings/settings_screen.dart` — Sektionen:
1. Transport (Nostr-Relays)
2. Notifications
3. Nachrichten
4. Backup
5. Einladungen
6. Kontakte
7. Admin (konditionell — nur Superadmin)
8. Info (Grundsätze, Über die App, Version)

`lib/services/help_texts.dart` — Kontextbezogene Hilfe-Dictionary:
Enthält 25+ Einträge für Governance, Zellen, Dorfplatz, Delegation,
Voting, Vertrauen. **Keine Einträge für Messenger-Basisfunktionen** (Chat,
Kanal beitreten, #mesh-Kanal).

### Vorschlag

**Platzierung Modus-Schalter:**
Einstellungen → neue Sektion ganz oben: **„App-Erfahrung"**

```
App-Erfahrung
  ○ Einfacher Modus   (Messenger & Kontakte — ideal zum Einstieg)
  ○ Vollständiger Modus   (inkl. Gemeinschaft, Selbstverwaltung & mehr)
```

Mit kurzem Erklärungstext: „Im einfachen Modus siehst du zuerst die
wichtigsten Funktionen. Du kannst jederzeit wechseln."

**Neue Hilfetexte in `help_texts.dart` (noch nicht vorhanden):**
- `mesh_channel`: Was ist #mesh? Lokales Mesh-Netzwerk, Peers in der Nähe
- `nexus_global_channel`: Was ist #nexus-global? Öffentlicher Kanal für alle
- `simple_mode`: Was verbirgt der einfache Modus?
- `contact_add_qr`: Kontakt via QR hinzufügen

**Begriffe für M1-Nutzer neutralisieren (nur Hilfetexte, nicht UI-Labels):**
- „Zelle" → im Erstkontakt „Gemeinschaft" (ist bereits in `CLAUDE.md` als
  offizieller Begriff gelistet — also kein Widerspruch)
- „Agora" → „Abstimmungsraum" oder „Gemeinschaftsentscheidungen"
- „Antrag" → bleibt „Antrag" (verständlich)

---

## 9. Feature-Flags / App-Modi

### Ist-Zustand

**Kein Feature-Flag-System vorhanden.** Navigation ist hard-coded.

**Bereits genutzte SharedPreferences-Keys (Vorbild):**
```
nexus_dismissed_cell_ids
nexus_deleted_cell_ids
nexus_cell_wipe_at
nexus_last_export_date
channel_zombie_republish_v1_done
notification_*_enabled
nexus_cell_founding_permit_*
```

**Bestehende konditionelle Sichtbarkeit (Vorbild):**
- Admin-Bereich in Settings: `if (isAdmin) AdminSection()`
- Coming-Soon-Kacheln in Discover: `DiscoverTile(comingSoon: true)`
- Wallet/Marktplatz auf Dashboard: bereits verborgen hinter Phase-Flag

### Vorschlag

**Minimaler Ansatz: globaler Modus-State**

Neuer Service: `lib/services/app_mode_service.dart`

```
SharedPreferences-Key: "app_mode"
Werte: "simple" | "full"
Default für Neuinstallation: "simple"
Default beim Upgrade bestehender Nutzer: "full"
```

**Upgrade-Erkennung:** Beim ersten App-Start nach Update prüfen, ob ein
bestehender Identity-Key vorhanden ist (`IdentityService.hasIdentity`). Wenn
ja → `"full"` schreiben (einmalig). Wenn nein → `"simple"` schreiben.

**Warum KEIN feinkörniger Feature-Flag-Service:**
- Overhead ohne Nutzen für 4 Phasen
- Ein globaler `app_mode`-Key ist in Settings steuerbar, lesbar und resetbar
- Alle UI-Stellen prüfen nur `appMode == AppMode.full` — einfach, testbar
- Feinkörnige Flags werden erst für M4 (AETHER) relevant

**Implementierungs-Skizze (nur zur Planung, kein Code):**

```
enum AppMode { simple, full }

class AppModeService extends ChangeNotifier {
  AppMode _mode = AppMode.full;  // safe default
  
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final hasIdentity = await IdentityService.instance.hasIdentity();
    
    if (!prefs.containsKey('app_mode')) {
      // Erstes Mal: bestehende Nutzer → full, Neulinge → simple
      _mode = hasIdentity ? AppMode.full : AppMode.simple;
      await prefs.setString('app_mode', _mode.name);
    } else {
      _mode = AppMode.values.byName(prefs.getString('app_mode') ?? 'full');
    }
    notifyListeners();
  }
  
  Future<void> setMode(AppMode mode) async { ... }
}
```

`AppModeService` wird in `main.dart` initialisiert und per `Provider`
bereitgestellt — exakt wie `RoleService`, `ConversationService`, etc.

---

## 10. Risiken für bestehende Tests und Datenmigration

### Ist-Zustand

**Widget-Tests mit Navigations-Bezug:**
- `test/features/navigation/navigation_test.dart` — prüft DiscoverScreen-Kacheln,
  Agora-Tile-Aktivzustand, Phase-Badges
- `test/features/navigation/contacts_nav_test.dart` — Kontakt-Navigation
- `test/features/dashboard/dashboard_test.dart` — Dashboard-Karten-Rendering

**Risiken durch Tab-Umordnung:**
- `navigation_test.dart` prüft vermutlich Tab-Index-Zuordnungen. Wenn
  Chat von Index 1 → Index 0 verschoben wird, brechen `_indexForLocation()`-
  basierte Tests.
- Discover-Tests prüfen Kachel-Sichtbarkeit ohne Modus-Kontext — sie würden
  im Simple-Modus fehlschlagen wenn Governance-Kacheln verschwinden.

**Datenmigrations-Risiken:**
- **Keine DB-Migration nötig.** `app_mode` landet in SharedPreferences,
  nicht in SQLite.
- Bestehende Tombstones, Cells, Proposals bleiben unberührt.
- Das einzige Migrations-Risiko: wenn SharedPreferences beim Upgrade fehlt
  (Windows-Desktop-Besonderheit laut `CLAUDE.md` Regel 1) → Fallback auf
  `"full"` ist bereits im Vorschlag eingebaut.

**Implizite Funktions-Checks im Code:**
- Governance-Screen prüft: „Nutzer ist in mindestens einer Zelle Mitglied"
  (eigene Guard-Logik, unabhängig von App-Modus)
- Settings: Admin-Sektion prüft `RoleService.isSystemAdmin()` — bleibt
  unverändert
- Dorfplatz: lädt nur Posts für beigetretene Zellen — bei 0 Zellen ist
  Tab 1 ohnehin leer

**Bezug zu offenen Tech-Debts:**

| TD | Beschreibung | Einfluss durch App-Modus |
|----|-------------|--------------------------|
| TD-32 | `allVotes` leer auf Empfänger-Geräten | Keiner — nur Governance betroffen, im Simple-Modus ausgeblendet |
| TD-33 | Cell-Membership-Sync-Inkonsistenz | Keiner — Sync läuft im Hintergrund unabhängig von UI |
| TD-34 | `eligibleVotersCount` fehlt in DecisionRecord | Keiner |

**Empfehlung für Test-Anpassung:**
Alle Navigations-Tests mit einem Mock-`AppModeService` in `full`-Modus
wrappen → bestehende Tests bleiben unverändert grün. Neue Tests für
Simple-Modus separat anlegen.

---

## Empfohlene Umsetzungsreihenfolge

```
Phase A — Fundament (Abhängigkeit für alle weiteren Schritte)
  [A1] AppModeService implementieren + in main.dart registrieren     [MITTEL]
       → Abhängigkeit von: nichts (erstes Schritt)
       → Erlaubt: alle folgenden Schritte

Phase B — Navigation anpassen (abhängt von A1)
  [B1] Dorfplatz-Tab im Simple-Modus ausblenden (NexusScaffold)     [KLEIN]
  [B2] Tab-Reihenfolge: Chat an Index 0 (router.dart)               [KLEIN]
       → Achtung: Navigation-Tests updaten

Phase C — Dashboard vereinfachen (abhängt von A1)
  [C1] Governance/Agora-Karte: nur Full-Modus                       [KLEIN]
  [C2] Wallet/Marktplatz-Karten: nur Full-Modus                     [KLEIN]
  [C3] Mini-Radar: ans Ende verschieben                              [KLEIN]

Phase D — Discover-Tab anpassen (abhängt von A1)
  [D1] Gemeinschaften- und Agora-Kachel: nur Full-Modus             [KLEIN]
  [D2] Sphären-Sektion: nur Full-Modus                              [KLEIN]

Phase E — Onboarding (abhängt von A1)
  [E1] Principles-Redirect: nach erstem Chat, nicht nach Onboarding [MITTEL]
  [E2] Willkommen-Text anpassen: Messenger-First-Framing            [KLEIN]

Phase F — Einstellungen (abhängt von A1)
  [F1] Modus-Schalter in Settings-Screen einfügen                   [MITTEL]

Phase G — Hilfetexte (unabhängig, jederzeit)
  [G1] help_texts.dart: Neue Einträge für #mesh, #nexus-global      [KLEIN]
  [G2] help_texts.dart: Eintrag für simple_mode-Erklärung          [KLEIN]

Phase H — Tests (nach B, C, D)
  [H1] navigation_test.dart: AppModeService-Mock, Simple-Modus-Tests [MITTEL]
  [H2] dashboard_test.dart: Modus-konditionelle Karten-Tests        [KLEIN]
```

**Abhängigkeitsgraph:**
```
A1 → B1, B2, C1, C2, C3, D1, D2, E1, E2, F1
B2 → H1
C1, C2 → H2
```

---

## Aufwandsschätzung

| Schritt | Aufwand | Risiko | Rückrollbar? |
|---------|---------|--------|--------------|
| A1 AppModeService | Mittel | Niedrig | Ja (SharedPrefs-Key) |
| B1 Dorfplatz-Tab | Klein | Niedrig | Ja |
| B2 Tab-Reihenfolge | Klein | Mittel (Tests) | Ja |
| C1–C3 Dashboard | Klein (×3) | Niedrig | Ja |
| D1–D2 Discover | Klein (×2) | Niedrig | Ja |
| E1 Principles-Redirect | Mittel | Niedrig | Ja |
| E2 Onboarding-Text | Klein | Niedrig | Ja |
| F1 Modus-Schalter Settings | Mittel | Niedrig | Ja |
| G1–G2 Hilfetexte | Klein (×2) | Keine | Ja |
| H1–H2 Tests | Mittel (×2) | Niedrig | Ja |

**Legende:** Klein = 1 Prompt / Mittel = 2–3 Prompts / Groß = 4+ Prompts

---

## Konkrete Code-Stellen (nur zur Referenz, NICHT ändern)

```
lib/core/router.dart
  → ShellRoute-Definition: Tab-Reihenfolge, _indexForLocation()
  → GoRoute-Liste: alle Full-Screen-Routen

lib/shared/widgets/nexus_scaffold.dart
  → BottomNavigationBar: Tab-Items und Sichtbarkeit
  → _indexForLocation()-Aufruf

lib/features/dashboard/dashboard_screen.dart
  → Widget-Liste der Karten (Scroll-Reihenfolge)
  → Governance-Karte, Wallet-Karte, Radar-Widget

lib/features/discover/discover_screen.dart
  → _mainTiles-Liste (Haupt-Kacheln)
  → _sphereTiles-Liste (Sphären)

lib/features/dorfplatz/dorfplatz_screen.dart
  → TabController-Länge (3)
  → Tab-Label-Liste

lib/features/onboarding/onboarding_screen.dart
  → Willkommen-Step: Texte und Buttons
  → _onComplete()-Methode: Navigation-Ziel

lib/core/router.dart (Redirect-Logik)
  → Principles-Redirect: wann wird /principles/intro ausgelöst?

lib/features/settings/settings_screen.dart
  → Sektions-Liste: wo neuer Modus-Schalter einzufügen

lib/services/help_texts.dart
  → Map<String, String>: neue Einträge für M1-Hilfetexte

lib/main.dart
  → Provider-Liste: wo AppModeService zu registrieren wäre
  → Service-Initialisierungssequenz

test/features/navigation/navigation_test.dart
  → Kachel-Sichtbarkeits-Tests: müssen Modus-aware werden

test/features/dashboard/dashboard_test.dart
  → Karten-Rendering-Tests: müssen Modus-aware werden
```

---

## Drei konkrete erste Mini-Schritte

Diese drei Schritte sind **voneinander unabhängig**, **risikoarm** und
können sofort als separate Einzel-Prompts umgesetzt werden — ohne dass
A1 (AppModeService) fertig sein muss.

### Mini-Schritt 1 — Hilfetext für #mesh-Kanal hinzufügen

**Ziel:** Erstnutzer verstehen, was der pinned `#mesh`-Kanal ist.

**Datei:** `lib/services/help_texts.dart`

**Aktion:** Neuen Eintrag `"mesh_channel"` hinzufügen:
> „#mesh ist dein lokaler Direktkanal zu N.E.X.U.S.-Nutzern in deiner Nähe.
>  Hier findest du Peers, die gerade online sind — ohne Server, nur
>  Gerät-zu-Gerät."

**Risiko:** Keine. Neue Zeile in einem Dictionary.

---

### Mini-Schritt 2 — Dashboard: Radar-Karte ans Ende verschieben

**Ziel:** Die erste Karte, die Erstnutzer sehen, ist „Nachrichten" — nicht
eine technische Radar-Animation mit Knotenanzahlen.

**Datei:** `lib/features/dashboard/dashboard_screen.dart`

**Aktion:** Mini-Radar-Widget in der ListView-Reihenfolge nach unten
verschieben (hinter die Kontakte-Karte). Keine Logik-Änderung.

**Risiko:** Minimal. Visuell-only, kein State-Impact.

---

### Mini-Schritt 3 — Discover: Sphären-Sektion mit Heading „Bald verfügbar"

**Ziel:** Die Coming-Soon-Sphären (Asklepios, Paideia, Demeter, Hestia)
bekommen einen eindeutigen Abschnitts-Header „Bald verfügbar — weitere
Lebensbereiche", damit Erstnutzer nicht denken, die App sei unfertig,
sondern absichtlich gestaffelt.

**Datei:** `lib/features/discover/discover_screen.dart`

**Aktion:** Neues `Padding`-Widget mit `Text("Bald verfügbar — weitere
Lebensbereiche")` über den Coming-Soon-Sphären-Kacheln einfügen.
Heute ist dort bereits eine Sektions-Überschrift, diese nur
präziser formulieren.

**Risiko:** Keine. Rein visuell, kein Test betroffen.

---

*Ende der Analyse — diese Datei enthält ausschließlich Planungs-Inhalte.
Kein Code wurde geändert. Alle Umsetzungs-Schritte sind als separate
Prompts geplant, gemäß dem Prinzip „Ein Fix pro Prompt".*
