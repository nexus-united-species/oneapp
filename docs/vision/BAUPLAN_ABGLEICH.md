# Bauplan-Abgleich: Aussagen, die der Code nicht deckt

Stand: 13. November 2026 · Quelle: [Audit November 2026](../audits/2026-11/AUDIT_BERICHT.md), Befund D-1

Der Bauplan beschreibt Vision und Zielbild. Einige Stellen in Bauplan 9.0
lesen sich aber wie der heutige Stand der OneApp. Diese Liste ist für die
Bauplan-Pflege gedacht (aktuell v14, v15 in Arbeit): Bei den genannten
Stellen bitte deutlich machen, dass es Ziel ist, oder den Text an den Stand
anpassen. Der Bauplan selbst liegt nicht im Repository.

| Aussage im Bauplan | Abschnitt | Stand im Code (13.11.2026) | Vorschlag |
|---|---|---|---|
| „Quadratic Voting: technisch implementiert, noch nicht aktiviert“ | 9.0.3 | nur ein Hilfetext, keine Logik | „spezifiziert, nicht implementiert“ |
| „Alle Nachrichten sind Ende-zu-Ende-verschlüsselt“ | 9.0.1 | Direktnachrichten und private Kanäle (seit 13.11.2026 auch deren Bilder und Sprachnachrichten) sind verschlüsselt; öffentliche Kanäle, Dorfplatz und Governance sind bewusst öffentlich | „Direktnachrichten und private Kanäle sind Ende-zu-Ende-verschlüsselt“ |
| „unveränderlicher Decision Record … Hash-Kette zur Manipulationserkennung“ | 9.0.3 | Kette ist geräteabhängig, keine Manipulationsprüfung beim Empfang (TD-41); abweichende Ergebnisse werden angezeigt | „Entscheidungsprotokoll; Manipulationsprüfung geplant“ |
| „BLE – direktes Gerät-zu-Gerät-Routing … läuft heute“, „BLE Mesh“ | 9.0.1 | BLE und LAN sind Direktverbindungen ohne Weiterleiten; Mesh ist ein geplanter, paralleler Zweig | „direkte Verbindung über Bluetooth und WLAN; Mesh in Vorbereitung“ |
| „Anträge … derzeit nur Admins“ | 9.0.5 | Anträge stellt jedes bestätigte Mitglied einer Gemeinschaft | „Anträge stellen Mitglieder“ |
| „Auto-Updater (GitHub Releases, alle 6 h): aktiv“ | 9.0.4 | Update-Prüfung läuft wieder (nach dem GitHub-Umzug repariert), die Update-Information ist aber noch nicht signiert | „aktiv; Signatur der Update-Information geplant“ |

Wenn eine dieser Aussagen im Bauplan schon angepasst ist, die Zeile hier
streichen.
