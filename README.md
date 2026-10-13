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

Die Web-Oberfläche kann als statische Flutter-Web-App gebaut werden:

```powershell
flutter build web --release
```

Die erzeugten Dateien liegen in `build/web` und können auf einem Webhost mit
HTTPS ausgeliefert werden. Das ist nur die Oberfläche: Gruppen, Chat, Einladungen
und Standortdaten werden in diesem Prototyp nicht zwischen Geräten synchronisiert.
Dafür ist zusätzlich ein Backend mit Anmeldung über zufällige anonyme Kennungen,
kurzlebigen Einladungs-Codes, Rollen-/Zugriffskontrollen, Echtzeitnachrichten und
Löschfristen für sensible Daten nötig. Standortfreigabe sollte ausdrücklich
opt-in, zeitlich begrenzt und jederzeit stoppbar sein.

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

Gruppeneinladungen und Chat sind lokale Demo-Daten; Codes lassen sich nur innerhalb
dieser laufenden Vorschau verwenden. Die Karte ist eine illustrative Darstellung
ohne Kartenanbieter oder GPS-Ortung. Die individuelle Demo-Einladung kann auf
1 bis 168 Stunden eingestellt werden. Vor einer echten Veröffentlichung müssen insbesondere Backend,
Datenschutz, Einwilligung zur Standortfreigabe und ein Sicherheitskonzept ergänzt
werden.
