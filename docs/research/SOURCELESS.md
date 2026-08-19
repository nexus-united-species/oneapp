# SourceLess

Recherchestand: 18. August 2026

**Ergebnis vorweg: SourceLess ist als architektonisches Vorbild nicht geeignet.
Es ist als Gegenbeispiel wertvoll – und zwar genau zu den Prinzipien, die das
Briefing in §9 und §28 aufstellt.**

Dieses Dokument trennt bewusst drei Ebenen: was die Quelle behauptet, was
unabhängige Quellen sagen, und was davon fachlich prüfbar ist.

## Quellenlage

Ausgangspunkt war ein vierseitiger Artikel im **Netcoo Magazin 04/2026**,
Titelstory: „The Next Big Thing – Wie Alexandru Stratulat mit SourceLess das
Internet neu erfindet".

Zur Einordnung der Quelle: **Netcoo ist ein Branchenmagazin für Network
Marketing / MLM.** Der Artikel ist eine Titelstory in werblichem Duktus, keine
technische Fachberichterstattung. Der Schlusskasten des Artikels lautet:

> „Je aktiver das Ökosystem von Kunden genutzt wird […] desto wertvoller dürfte
> die Wertschöpfung **für den Vertrieb** werden."

Der Artikel richtet sich also an Vertriebspartner, nicht an Entwickler. Das ist
für die Bewertung der technischen Aussagen erheblich.

## A – Was der Artikel behauptet

**Architektur.** Drei Ebenen: Base Layer mit eigener Blockchain, Protocol Layer
mit `STR.Domains` als Identitäts- und Adressschicht, Application Layer für alle
Produkte des Ökosystems.

**Identität.** `STR.Domains` als **Wrapped NFTs (wNFTs)** – dauerhaft und
lebenslang dem Nutzer zugeordnet, anders als klassische Domains nicht durch
einen Registrar entziehbar. Zugleich Adresse, Identitätsnachweis und
Zugangsschlüssel zum gesamten Ökosystem.

**Kryptografie.** Ein zentrales Verschlüsselungssystem namens `GodCypher`, das
„Quantum Key Rotations, Post-Quantum-Kryptografie und Zero-Knowledge-Verifikation
zusammenführt", ergänzt um ein `ZK13 Privacy Framework` mit Stealth Addresses,
Nullifier-Logik und Commitment Trees.

**Entropiequelle.** Sogenannte **„Earthquake Randomness"**: geophysikalische
Daten, konkret Erdbebenmessungen, als Entropiequelle für kryptografische
Schlüssel – „anstatt auf softwarebasierte Zufallszahlen oder berechenbare
Muster zu setzen".

**Schutzrechte.** Mehr als 15 Patente sollen die Kerntechnologien schützen,
„darunter die Verschlüsselungsarchitektur und die Netzwerkinfrastruktur".

**Privatsphäre.** Transaktionen sind „grundsätzlich anonym angelegt", aber:
„Im Falle illegaler Aktivitäten kann die Identität hinter einer Wallet auf
Basis eines Gerichtsbeschlusses über einen KYC-Validator offengelegt werden."

**Weitere Bausteine.** `CCoin Network` (CCoin-Kryptowährung, CCoin Bank UK
Onshore, CCoin Finance Offshore, dezentrale Exchange `IgniteHex`), Offshore-Konten
mit IBAN, Kreditkarten mit Tageslimits bis 25.000 US-Dollar, `STR.Talk`
(Kommunikation), `ARES AI`, `STR4TUS` Browser, `Cognit4` Suchmaschine,
`SLNN` Mesh-Netzwerk, eSIM/MVNO-Infrastruktur, geplante eigene
**Satelliteninfrastruktur**, über 15 Marken.

**Vertriebsmodell.** `SASP` (SourceLess Affiliate Shop Program) – ein
fünfstufiges Karrieresystem mit „Einzelhandelsmargen und Direktbonus,
Binärbonus sowie Matching-Bonus". In der 4-Star-Stufe sollen „Ausschüttungen
von bis zu 25.000 US-Dollar pro Woche möglich sein". Ausdrücklich als
„modernes Multilevel-Network-Marketing" bezeichnet.

**Ziel.** Geplanter Gang an die NASDAQ, angestrebte Bewertung über zehn
Milliarden US-Dollar („Decacorn").

## B – Unabhängige Quellen

| Quelle | Aussage |
|---|---|
| [BehindMLM](https://behindmlm.com/mlm-reviews/sourceless-review-nft-domain-pyramid-scheme/) | Bewertet SourceLess als „NFT domain pyramid scheme"; Affiliates würden zum Kauf von STR Domains gedrängt, weil es keine Endkundennachfrage gebe. STR-Domain-Traffic sei im Januar 2025 zu gering für eine SimilarWeb-Erfassung gewesen |
| [The Safety Reviewer](https://thesafetyreviewer.com/reviews/sourceless/) | Anzeichen für einen möglichen Online-Betrug; das Unternehmen trete als Anbieter von Finanzdienstleistungen auf, ohne Zulassung anerkannter Finanzaufsichten wie der FCA |
| [Tracing Frauds](https://tracingfrauds.com/reviews/sourceless/) | Vergleichbare Warnhinweise |
| [Trustpilot](https://www.trustpilot.com/review/www.sourceless.io) | Gemischt – teils Lob für die Innovation, teils Berichte über Probleme bei Support und Rückzahlungen |

**Vorgeschichte.** Nach diesen Quellen gründete Alexandru Stratulat vor
SourceLess das Projekt **CCoin**, das als „pump and dump crypto scam" um den
CCOS-Token beschrieben wird und Anfang 2022 zusammengebrochen sein soll.

Das ist besonders zu beachten, weil der Artikel das **CCoin Network** als
zentrale Finanzebene des heutigen Ökosystems beschreibt – der Name ist also
nicht Vergangenheit, sondern Teil der aktuellen Struktur.

Diese Angaben sind Fremdaussagen und hier als solche wiedergegeben. Sie sind
nicht durch eigene Prüfung verifiziert.

## C – Fachliche Bewertung der technischen Behauptungen

Unabhängig von den Betrugsvorwürfen lassen sich einzelne technische Aussagen
architektonisch bewerten. Diese Bewertung steht für sich.

### „Earthquake Randomness" ist kryptografisch nicht haltbar

Erdbebendaten werden weltweit von seismologischen Diensten – USGS, EMSC, GFZ
und anderen – **öffentlich und nahezu in Echtzeit publiziert**. Eine
Entropiequelle, die ein Angreifer nachschlagen kann, ist keine Entropiequelle.

Wenn Schlüssel aus öffentlich verfügbaren Messwerten abgeleitet werden, ist der
Schlüsselraum genau so groß wie die Unsicherheit über die verwendete Messung
und das Ableitungsverfahren – nicht wie die Schlüssellänge suggeriert.

Etablierte Systeme nutzen Betriebssystem-CSPRNGs, die viele unabhängige,
**nicht öffentlich beobachtbare** Quellen mischen. Physikalische Zufälligkeit
als Vermarktungsargument gegen „berechenbare Muster" auszuspielen, verdreht die
Sachlage: Der Vorwurf gegen Software-Zufall trifft schlechte PRNGs, nicht
moderne CSPRNGs.

**Bewertung:** Entweder ist es Marketing für eine harmlose Zusatzquelle, oder es
ist ein Fehler erster Ordnung. Beides spricht gegen die Verlässlichkeit der
kryptografischen Aussagen insgesamt.

### Patentierte Verschlüsselung widerspricht prüfbarer Sicherheit

Über 15 Patente auf Kerntechnologien einschließlich der
Verschlüsselungsarchitektur stehen im direkten Gegensatz zu §9 des Briefings
(„offene Standards, dokumentierte Protokolle, etablierte Kryptografie").

Kryptografie gilt als vertrauenswürdig, wenn sie offen spezifiziert, breit
implementiert und über Jahre erfolglos angegriffen wurde. Eine patentgeschützte,
proprietäre Verschlüsselungsarchitektur kann diesen Prozess strukturell nicht
durchlaufen.

Der Artikel bezeichnet die Patente als „bemerkenswert hohen Grad an Schutz des
geistigen Eigentums". Aus Sicherheitssicht ist das kein Vorzug, sondern ein
Prüfhindernis.

### Der KYC-Validator ist eine eingebaute Deanonymisierung

„Die Identität hinter einer Wallet kann auf Basis eines Gerichtsbeschlusses über
einen KYC-Validator offengelegt werden" beschreibt eine bewusst eingebaute
Hintertür mit einer privilegierten Instanz.

Das ist mit selbstsouveräner Identität nicht vereinbar. Es kann eine legitime
regulatorische Entscheidung sein – aber dann ist das System nicht das, als das
es im selben Artikel beworben wird.

### STR.Domains verletzen alle fünf Punkte aus §9

Das Briefing formuliert in §9, N.E.X.U.S. solle möglichst wenig abhängig sein
von:

| §9 nennt | SourceLess |
|---|---|
| proprietären Identitätssystemen | STR.Domains als wNFT |
| proprietären Domains | STR.Domains |
| einzelnen Blockchains | eigene Base-Layer-Blockchain |
| einzelnen Firmen | SourceLess Inc., 15+ Marken |
| proprietärer Kryptografie | GodCypher, 15+ Patente |

**SourceLess ist die exakte Umkehrung aller fünf Punkte.** Eine Identität, die
als NFT auf einer einzelnen firmeneigenen Blockchain lebt, ist genau die
Abhängigkeit, die §28 („No Single Dependency") ausschließen will.

### Der Umfang widerspricht §30

§30 des Briefings warnt ausdrücklich vor zusätzlichen Großbaustellen und nennt
beispielhaft eigener Browser, eigener Satellitendienst, eigene
eSIM-Infrastruktur, eigene Blockchain.

SourceLess baut nach eigener Darstellung **alle vier gleichzeitig** – plus
Suchmaschine, KI, Mesh-Netzwerk, Bank, Exchange und Kreditkarten.

Bemerkenswert: Joachim hat diese vier Beispiele im Briefing vermutlich genau
deshalb gewählt. Die Schlussfolgerung war also bereits gezogen, bevor diese
Recherche stattfand.

## D – Was daraus für N.E.X.U.S. folgt

**Die Prinzipien in §9, §11, §28 und §30 sind richtig – aber sie stammen aus
einer Negativabgrenzung, nicht aus einem übernehmbaren Vorbild.**

Das Briefing formuliert in §6, die drei Projekte „liefern wertvolle
Architekturprinzipien". Für Web of Trust und Real Life Stack trifft das zu. Für
SourceLess trifft es nur in dem Sinne zu, dass es zeigt, **wie es nicht gehen
soll**. Diese Klarstellung gehört in die Dokumentation, damit SourceLess in
späteren Diskussionen nicht versehentlich als gleichrangige Referenz neben den
beiden anderen steht.

**Konkret zu übernehmen ist nichts.** Es gibt keinen Code, keine offene
Spezifikation und kein Verfahren, das für die OneApp verwendbar wäre.

**Ein Nebenbefund mit Projektbezug:** N.E.X.U.S. baut eine Bewegung mit
Community, sucht Finanzierung und verspricht in Charta und Grundordnung
Unabhängigkeit von Firmen und Zentralmacht. Eine sichtbare inhaltliche Nähe zu
einem Projekt, das über MLM-Strukturen vertrieben wird und dessen Vorgänger
öffentlich als Betrug beschrieben wird, birgt ein Glaubwürdigkeitsrisiko, das
über die Technik hinausgeht. Das ist keine technische Bewertung, sondern eine
Einordnung, die für die Projektleitung relevant sein dürfte.

## Was hier nicht behauptet wird

- Es wird nicht behauptet, dass SourceLess ein Betrug ist. Wiedergegeben werden
  Einschätzungen Dritter mit Quellenangabe.
- Die technische Bewertung unter C stützt sich auf die Darstellung im
  Netcoo-Artikel. Eine offene technische Spezifikation, die diese Aussagen
  präzisieren oder widerlegen könnte, wurde im Rahmen dieser Recherche nicht
  ausgewertet.
- Die Bewertung von „Earthquake Randomness" gilt der Beschreibung im Artikel.
  Sollte die tatsächliche Implementierung öffentliche Seismikdaten nur als
  ergänzende Quelle neben einem CSPRNG mischen, wäre sie unschädlich – dann
  wäre die Darstellung jedoch irreführend.

## Quellen

- Netcoo Magazin 04/2026, S. 44–49, Titelstory (PDF vom Nutzer bereitgestellt)
- [netcoo.com – englische Fassung des Artikels](https://netcoo.com/en/the-next-big-thing-how-alexandru-stratulat-is-reinventing-the-internet-with-sourceless/)
- [BehindMLM: SourceLess Review – NFT domain pyramid scheme](https://behindmlm.com/mlm-reviews/sourceless-review-nft-domain-pyramid-scheme/)
- [The Safety Reviewer: SourceLess Review](https://thesafetyreviewer.com/reviews/sourceless/)
- [Tracing Frauds: SourceLess Review](https://tracingfrauds.com/reviews/sourceless/)
- [Trustpilot: sourceless.io](https://www.trustpilot.com/review/www.sourceless.io)
- [Crunchbase: SourceLess Blockchain](https://www.crunchbase.com/organization/sourceless)
