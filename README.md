# Reşo

It doesn't matter if you are rich or poor 

Reşo ist ein Flutter-Prototyp für zivile Gruppenkoordination. Er enthält eine
Kartenansicht, Demo-Einladungen mit Ablaufzeit, Gruppenchat, Teilnehmerliste und
bestätigungspflichtige Sicherheitsmeldungen.

## Lokal ausprobieren

Voraussetzung ist das Flutter SDK. Im Projektordner:

```powershell
flutter pub get
flutter run -d chrome
```

Oder die Web-Vorschau als lokalen Webserver im Heimnetz starten:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Rufe die im Terminal angezeigte lokale IP-Adresse mit Port `8080` auf einem
anderen Gerät im selben WLAN auf. Firewall und WLAN müssen Verbindungen zwischen
den Geräten erlauben. Dies ist nur ein Entwicklungsserver und nicht für einen
öffentlichen Betrieb gedacht.

Für einen iPhone-Test kann Flutter die App direkt starten:

```powershell
flutter devices
flutter run -d <geraete-id>
```

Ein iOS-Build benötigt macOS mit Xcode. Android kann mit installiertem Android
SDK direkt getestet werden.

## Online-Betrieb mit Render

Die Flutter-Oberfläche und der Express-Server sind zwei getrennte Deployments:
Der Render-Web-Service unter `https://project-cat-and-mouse.onrender.com` ist
nur die API. Damit die App im Browser erreichbar ist, muss zusätzlich eine
Render Static Site angelegt werden.

### API-Server

Der API-Server benötigt PostgreSQL. In Render eine PostgreSQL-Datenbank anlegen
und beim Web-Service für `genz-server` die Umgebungsvariable `DATABASE_URL` auf
deren interne Verbindungs-URL setzen. `DATABASE_SSL=true` ist nur nötig, wenn
die verwendete Verbindungs-URL TLS verlangt. Beim Serverstart werden die
Tabellen angelegt. Der Web-Service braucht als Root Directory `genz-server`
und als Start Command `npm start`.

### Flutter-Web-App

In Render **New > Static Site** wählen, das GitHub-Repository und den Branch
verbinden und als Root Directory das Repository-Hauptverzeichnis verwenden
(Root Directory leer lassen). Flutter ist in der Build-Umgebung nicht
vorinstalliert; dieser Build Command lädt das Flutter-SDK und baut die App:

```sh
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter" && export PATH="$HOME/flutter/bin:$PATH" && flutter config --no-analytics && flutter pub get && flutter build web --release --dart-define=API_BASE_URL=https://project-cat-and-mouse.onrender.com
```

Als Publish Directory `build/web` eintragen. Nach dem Deploy stellt Render die
Browser-App unter einer eigenen `onrender.com`-Adresse bereit. Falls der
API-Service eine andere Adresse hat, diese im Build Command hinter
`API_BASE_URL=` einsetzen. Änderungen an der Oberfläche werden durch einen
neuen Static-Site-Deploy veröffentlicht.

Für einen lokalen Client-Build:

```powershell
flutter pub get
flutter build web --release
```

Für Android/iOS die jeweilige Flutter-App bauen. Ein iOS-Build benötigt macOS
mit Xcode.

## Online-Server oder P2P?

Für eine plattformübergreifende Gruppen-App ist ein kleiner, abgesicherter
Server in der Regel die zuverlässigere Grundlage: Er funktioniert auch bei
Mobilfunk, NAT und wechselnder Erreichbarkeit und kann abgelaufene Einladungen
sowie Gruppenberechtigungen zentral prüfen. P2P ist nicht automatisch sicherer:
Mobilgeräte sind oft nicht direkt erreichbar, Verbindungen brechen im Hintergrund
ab und für die Verbindungseinrichtung oder Weiterleitung wird häufig weiterhin
ein Server benötigt. Für echte private Chats sollte zusätzlich Ende-zu-Ende-
Verschlüsselung verwendet werden.

„Anonym“ bedeutet dabei nicht, dass Standortdaten risikofrei sind. Namen können
Pseudonyme sein, aber Standortverläufe sind sensibel und müssen sparsam erhoben,
geschützt und gelöscht werden.

## Prototyp-Grenzen

Mitgliedskennungen werden lokal auf dem Gerät gespeichert; eine Anmeldung,
Kennungs-Wiederherstellung, Ratenbegrenzung und automatische Datenlöschung sind
noch nicht eingerichtet. Einladungen gewähren den Beitritt bis zu ihrem Ablauf,
aber Gruppen und Nachrichten werden derzeit nicht automatisch gelöscht. Die
Karte bleibt eine illustrative Darstellung ohne Kartenanbieter oder GPS-Ortung.
Vor einem produktiven Einsatz müssen insbesondere Identität, Zugriffsschutz,
Aufbewahrungsfristen, Datenschutz und Einwilligung zur Standortfreigabe ergänzt
werden.
