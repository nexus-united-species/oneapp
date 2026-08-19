# Mesh — Referenzmaterial

Hintergrundmaterial zu Reticulum und LoRa-Mesh. **Kein Implementierungsauftrag.**

## Status

Mesh-Transport ist im Tech-Stack (`CLAUDE.md`) als Ziel genannt, aber **nicht
implementiert**. `TransportType` kennt `lora` als Platzhalter, mehr nicht.

[Audit Lauf B](../../../audits/2026-07/AUDIT_LAUF_B.md) rät ausdrücklich davon
ab, eine Reticulum-Brücke jetzt zu bauen: Es gäbe keine Dart-native Anbindung,
nötig wäre eine FFI-Brücke zu Rust oder Go plus Cross-Compilation für Android
und Windows — laufender Pflegeaufwand, den ein Alleingründer ohne Entwickler
nicht tragen kann.

Auch [Web of Trust](../../../research/WEB_OF_TRUST.md) hat LoRa nur als Konzept
und kommt zum selben technischen Schluss: LoRa hat ~237 Byte pro Paket und 1 %
Duty Cycle in EU 868 — für Sync-Verkehr um Größenordnungen zu schmal. Dort ist
LoRa nur für signierte Kurzsignale vorgesehen (Präsenz-Beacons,
Node-Bindungen), nicht als Transport.

## Inhalt dieses Ordners

| Datei | Thema |
|---|---|
| `Reticulum & Mesh-Netzwerke_ Ihr Einstieg in die digitale Freiheit.pdf` | Einführung |
| `Technisches Implementierungskonzept_ Dezentrale Mesh-Netzwerke mit Reticulum.pdf` | Umsetzungskonzept |
| `Hardware-Komponenten für dein Mesh-Netzwerk_ Ein Leitfaden für Einsteiger.pdf` | Hardware-Leitfaden |
| `README_GERALD.md` | Notiz |

## Nicht in diesem Repository

**`Reticulum_Global_Mesh.pdf`** (18 MB) ist bewusst **nicht** versioniert — zu
groß für ein Git-Repository, gemessen am Nutzen für eine zurückgestellte
Technologie. Git speichert PDFs bei jeder Änderung vollständig neu.

Die Datei liegt unter:

```
C:\Users\joach\Documents\!Nexus_Wissen\3_Technik\Mesh\Reticulum_Global_Mesh.pdf
```

Der Ausschluss steht in `.gitignore`. Wer sie doch versionieren will, muss den
Eintrag dort entfernen.
