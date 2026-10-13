# Reşo

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

## Online-Betrieb

Die App synchronisiert Gruppen, Einladungen, Chatnachrichten und
Sicherheitsmeldungen mit dem Express-Server. Die API-Adresse ist standardmäßig
`https://project-cat-and-mouse.onrender.com`; sie kann beim Build mit
`--dart-define=API_BASE_URL=<URL>` überschrieben werden.

Der Server benötigt PostgreSQL. Für Render eine PostgreSQL-Datenbank anlegen und
bei der Web-Service-Umgebung `DATABASE_URL` auf deren interne Verbindungs-URL
setzen. `DATABASE_SSL=true` ist nur nötig, wenn die verwendete Verbindungs-URL
TLS verlangt. Beim Serverstart werden die Tabellen angelegt. Danach den Service
mit dem aktualisierten `genz-server`-Quellcode neu deployen.

Für einen Client-Build:

```powershell
flutter pub get
flutter build web --release
```

oder für Android/iOS die jeweilige Flutter-App bauen. Eine Flutter-Web-App muss
separat gehostet werden; die Render-Adresse ist hier die API und liefert nicht
die Flutter-Oberfläche aus.

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
