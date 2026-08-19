# NEXUS LoRa-Mesh — Flash-Paket für Heltec V4

**Für:** Gerald
**Von:** Josh (über Claude)
**Stand:** Mai 2026

Hallo Gerald — hier ist das komplette Paket zum Flashen deiner 18+ Heltec V4
Boards als eigenständige Reticulum Transport Nodes. Alles drin, was du nach
einer einmaligen Einrichtung dauerhaft offline brauchst.

---

## Antworten auf deine drei Fragen

**1. Welche Firmware für den Standalone-Betrieb?**

Empfehlung: **RTNode-HeltecV4** von jrl290 (Version 1.0.30, "stable beta").
Diese Firmware ist speziell für den Heltec V4 entwickelt, läuft komplett
eigenständig (kein Raspberry Pi nötig), und kann optional zusätzlich eine
WiFi → TCP/IP-Brücke zu einem entfernten Reticulum-Backbone aufbauen — genau
das, was wir später für die internationale Vernetzung brauchen.

Die Alternative microReticulum_Firmware (attermann) ist allgemeiner gehalten,
aber nicht V4-spezifisch und ohne die TCP-Brücke. Für dein Mesh ist
RTNode-HeltecV4 der bessere Fit.

**Wichtiger Hinweis:** Beide sind formal "Beta" — du bist als erfahrener
Funker genau die Zielgruppe, die das auf echter Hardware validieren soll.

**2. Wo gibt es die Firmware?**

Original-Quelle: `https://github.com/jrl290/RTNode-HeltecV4`

In diesem Paket sind die fertigen Binärdateien für den V4 schon enthalten —
du brauchst dafür nicht mehr ins Netz:

- `rtnode_heltec_v4_v1.0.30_merged.bin` — stable beta (empfohlen)
- `rtnode_heltec_v4_v1.0.33_merged.bin` — latest beta (neueste Fixes)

"merged" bedeutet: Bootloader + Partitionen + App in einer Datei.
Das ist genau, was du für Erstinstallationen brauchst.

**3. Kann ich offline flashen?**

Ja — nach einer **einmaligen** Einrichtung (siehe unten) brauchst du nie
wieder Internet zum Flashen. Selbst bei 18, 50 oder 200 Boards.

---

## Einmalige Einrichtung (nur einmal pro PC)

Du brauchst Python 3 und das Tool `esptool`. Das ist alles.

**Windows / macOS / Linux:**

```
pip install esptool
```

Falls `pip` nicht erkannt wird, vorher Python 3 installieren von
`https://www.python.org/downloads/`.

Test, ob es funktioniert:

```
esptool.py version
```

(Auf Windows ggf. `python -m esptool version`.)

Das war's. Ab jetzt: alles offline.

---

## Pro Board: Flashen in ~30 Sekunden

**Schritt 1.** Heltec V4 per USB-Datenkabel an den PC anschließen. Wichtig:
echtes Datenkabel, kein reines Ladekabel. Das Board sollte sich am OLED-
Display melden.

**Schritt 2.** Port herausfinden:

- **Windows:** Geräte-Manager → "Anschlüsse (COM & LPT)" → dort steht z.B.
  `COM5`
- **macOS:** `ls /dev/cu.usbmodem*` im Terminal
- **Linux:** `ls /dev/ttyACM*` im Terminal

**Schritt 3.** Flash-Befehl ausführen.

**Windows (Eingabeaufforderung, im Paket-Ordner):**

```
flash_v4_windows.bat COM5
```

(Ersetze `COM5` durch den tatsächlichen Port.)

**macOS / Linux (Terminal, im Paket-Ordner):**

```
./flash_v4_linux_mac.sh /dev/ttyACM0
```

**Schritt 4.** Warten — der Vorgang dauert ca. 20–40 Sekunden. Am Ende
erscheint "Fertig!"

**Schritt 5.** Board abstecken, mit einem Etikett versehen (z.B. "R-01",
"R-02", ...), nächstes Board anstecken.

---

## Latest beta verwenden (optional)

Wenn du v1.0.33 statt v1.0.30 flashen willst:

```
flash_v4_windows.bat COM5 v1.0.33
./flash_v4_linux_mac.sh /dev/ttyACM0 v1.0.33
```

v1.0.33 enthält "mixed-path proof routing and harnesses" — relevant wenn du
komplexere Routing-Szenarien testen willst. Für den ersten Aufbau auf
Teneriffa würde ich erstmal bei v1.0.30 bleiben — das ist die letzte als
"non-prerelease" markierte Version.

---

## Nach dem Flashen: Erste Konfiguration

Beim ersten Start öffnet das Board einen offenen WLAN-Hotspot namens
**RNode-Boundary-Setup**. Mit Handy oder Laptop verbinden — ein Captive
Portal sollte automatisch aufgehen. Falls nicht: im Browser
`http://192.168.4.1` aufrufen.

Dort konfigurierst du pro Board:

- WLAN-SSID/-Passwort (für den TCP-Backbone-Uplink, falls gewünscht)
- LoRa-Parameter (Frequenz, Spreading Factor, Bandbreite)
- Optional: Hostname/Port des entfernten Reticulum-Backbones (z.B.
  `rmap.world`) — nur wenn dieser Knoten eine Brücke zum Internet sein soll
- Optional: "Announce on network" — nur einschalten, wenn der Knoten
  öffentlich auf rmap.world erscheinen soll

---

## Frequenz-Hinweis für Teneriffa (Spanien, EU)

Auf dem 868-MHz-ISM-Band gilt in der EU eine Sendeleistungs-Begrenzung —
für die meisten Sub-Bänder 14 dBm (25 mW) bei 1 % Duty-Cycle. Der V4 kann
bis 28 dBm. Auf 868 MHz lizenzfrei musst du die Leistung in der
Konfiguration entsprechend drosseln.

Für maximale Reichweite mit voller Leistung: dein Amateurfunk-Spielraum.
Das musst du als Lizenzinhaber selbst einschätzen und entsprechend
einstellen. Wir können das nochmal in Ruhe besprechen, bevor du das
finale Frequenzschema festlegst.

---

## Wenn etwas schiefgeht

**"esptool nicht gefunden"** → `pip install esptool` nicht ausgeführt oder
fehlgeschlagen. Auf Windows ggf. `python -m esptool` statt `esptool.py`.

**"Permission denied" auf Linux** → User braucht Zugriff auf serielle
Schnittstellen:
```
sudo usermod -a -G dialout $USER
```
Dann ab- und wieder anmelden.

**Board reagiert nicht / Flash bricht ab** → Anderes USB-Kabel probieren
(häufigste Ursache!), oder Reset-Taste gedrückt halten beim Start des
Flash-Vorgangs.

**Display bleibt dunkel nach Flash** → Reset-Taste am Board drücken. Beim
allerersten Start kann der Boot 10–15 Sekunden dauern.

---

## Was als nächstes?

Sobald die ersten 2–3 Boards laufen, sollten wir kurz zusammen schauen:

1. Reichweiten-Test zwischen zwei Boards auf Teneriffa (line-of-sight,
   real-world)
2. Reticulum-Identität pro Board generieren und sauber dokumentieren
3. Einen ersten Backbone-Knoten als Internet-Brücke konfigurieren (für die
   spätere internationale Anbindung — das große Bild aus unserer
   Vordiskussion)

Wenn du beim ersten Board hängst oder eine Reticulum-Config-Vorlage
brauchst — schick einfach Bescheid, dann setze ich dir das auf.

Viel Erfolg beim Aufbau — schön, dass du das in die Hand nimmst.

— Josh & Claude
