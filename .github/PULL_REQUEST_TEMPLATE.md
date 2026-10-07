## Was und warum / What and why

<!-- 🇩🇪 Was ändert dieser Pull Request, und warum ist das nötig? Bezug auf Issues mit "Closes #123".
     🇬🇧 What does this pull request change, and why is it needed? Reference issues with "Closes #123". -->

## Wie getestet / How tested

<!-- 🇩🇪 Welche Tests hast du ausgeführt? Auf welchen Geräten (Android/Windows) hast du es ausprobiert?
     🇬🇧 Which tests did you run? On which devices (Android/Windows) did you try it? -->

## Checkliste / Checklist

- [ ] `flutter analyze` ohne neue Fehler / without new errors
- [ ] `flutter test` – keine neuen fehlschlagenden Tests / no new failing tests
- [ ] Tests ergänzt oder angepasst, wenn sich Verhalten ändert / tests added or updated when behavior changes
- [ ] Keine Geheimnisse, Seed-Phrasen oder echten persönlichen Daten / no secrets, seed phrases or real personal data
- [ ] Datenverlust- und Sync-Regeln aus `CLAUDE.md` beachtet (kein `DROP`, synchrones State-Locking, Listener vor Transport-Start) / data-loss and sync rules from CLAUDE.md respected
- [ ] Nostr-`e`-Tags enthalten nur echte 64-Hex-Event-IDs, keine UUIDs / Nostr `e` tags contain only real 64-hex event IDs, no UUIDs
