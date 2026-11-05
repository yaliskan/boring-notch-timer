# Boring Notch 2.7.3 + Timer + System — zelf bouwen op je Mac

Dit is de officiële **Boring Notch 2.7.3** (open source, GPL-3.0, van TheBoredTeam) met twee toevoegingen en één bewuste verwijdering:

- **Timer-tabblad** in de notch.
- **System-tabblad**: CPU- en RAM-meter plus de batterijstand van verbonden Bluetooth-apparaten.
- **Camera (spiegelfunctie) verwijderd**: de app heeft geen camera-recht meer en kan de camera dus nooit gebruiken.

Deze versie is op 5 november 2026 gebouwd en getest op een MacBook Pro M4 met macOS 26.6 en Xcode 27.2.

## Wat kunnen de nieuwe tabbladen?

**Timer**
- Knoppen **5 / 10 / 15 / 30 min**, en **Custom time** met plus/min-knoppen. Hou **⌥ (Option)** ingedrukt tijdens het klikken voor grotere stappen. Typen kan niet: het notch-venster accepteert geen toetsenbord.
- Zolang de timer loopt zie je de resterende tijd klein naast de dichte notch. Pauzeren, hervatten en stoppen doe je in de Timer-tab, en bij het openen van de notch land je dan direct op Timer.
- Bij afloop: 4x een geluidje, de notch klapt open op Timer, en er staat **Done** tot je erop klikt.

**System**
- Twee ringen: **CPU** (percentage) en **RAM** (percentage en gebruikt / totaal in GB). Ververst elke 1,5 seconde, maar alleen zolang de tab zichtbaar is, om batterij te sparen.
- Schakelaar **"Show next to closed notch"**: toont "CPU xx%" en "RAM xx/yy" klein naast de dichte notch. Staat standaard uit. Muziek en een lopende timer hebben voorrang.
- Rechts de **Bluetooth-apparaten** die hun batterijstand aan macOS doorgeven: Magic Keyboard, Magic Mouse, Magic Trackpad, AirPods (links, rechts en case), Beats, game-controllers. Dit leest alleen de gegevens die macOS zelf al heeft; er wordt niets gescand en er is **geen Bluetooth-toestemming** nodig. iPhone en iPad verschijnen niet: daar heeft macOS geen openbare manier voor.

Alles is alleen-lezen en lokaal: geen netwerk, geen bestanden, geen logboek.

## Wat is er veranderd ten opzichte van het origineel?

- Nieuwe bestanden in `boringNotch/components/Live activities/`: `TimerFeature.swift`, `SystemMonitorFeature.swift`, `DeviceBatteryFeature.swift`.
- Kleine aanpassingen in `ContentView.swift`, `TabSelectionView.swift`, `enums/generic.swift`, `models/BoringViewModel.swift`.
- Camera verwijderd: camera-recht uit `boringNotch.entitlements`, camera-omschrijving uit het project, spiegelschakelaar uit `SettingsView.swift`, camerastap uit `OnboardingView.swift`, en `WebcamManager.swift` is een lege huls die nooit de camera aanraakt.
- **Automatische updates staan uit** (`boringNotchApp.swift`, `Info.plist`). Anders overschrijft de officiële versie jouw build.
- Eigen bundel-ID `local.notchtimer.boringnotch` (en `local.notchtimer.boringnotch.BoringNotchXPCHelper`), zodat het met een gratis Apple-account te ondertekenen is en naast de officiële app kan staan.
- Alle wijzigingen staan ook los in `boring-notch-timer.patch`.

## Wat heb je nodig?

- Een Mac met Apple-chip (M1 of nieuwer) en macOS 15.5 of nieuwer.
- **Xcode** (gratis uit de Mac App Store, ongeveer 15 GB). Het downloaden duurt lang; het bouwen zelf maar een paar minuten.
- Een gewoon, gratis **Apple-account** (geen betaald developer-account).
- Internet tijdens de eerste keer bouwen (Xcode haalt een paar pakketten op).

## Bouwen, stap voor stap

1. **Installeer Xcode** uit de Mac App Store. Open Xcode één keer, accepteer de licentie en laat eventuele extra onderdelen installeren.
2. **Pak de zip uit** (dubbelklik). Je krijgt een map `BoringNotch-2.7.3-Timer`. Zet die bijvoorbeeld in je Documenten-map. Verplaats de map daarna niet meer.
3. **Open het project:** dubbelklik in die map op `boringNotch.xcodeproj`. Wacht tot bovenin "Resolving Packages" klaar is. Drie gele waarschuwingen linksboven zijn normaal.
4. **Voeg je Apple-account toe:** menubalk **Xcode > Settings…**, tabblad **Accounts**, klik linksonder op **+**, kies **Apple ID** en log in.
5. **Kies je team:** klik helemaal links bovenin op het blauwe project-icoon "boringNotch". In het midden, onder **TARGETS**, klik op **boringNotch**. Klik bovenin op **Signing & Capabilities**. Vink **Automatically manage signing** aan en kies bij **Team** jouw naam met **(Personal Team)**. Doe daarna precies hetzelfde voor de target **BoringNotchXPCHelper**. Druk op **⌘S**.
6. **Bouw:** controleer bovenin dat er `boringNotch` en `My Mac` staat. Druk op **⌘B**. Na een paar minuten staat er "Build Succeeded".
7. **Vind de app:** menubalk **Product > Show Build Folder in Finder**. Open daar **Products > Debug**. Daar staat `boringNotch.app`.
8. **Installeer:** sluit eerst de officiële Boring Notch af als die draait (sterretje in de menubalk > Quit). Sleep `boringNotch.app` naar je map **Programma's**.
9. **Start de app zelf vanuit de Finder** (dubbelklik in Programma's). Start hem niet vanuit de Terminal: dan kan het neerzetten van bestanden op de Shelf stilletjes niet werken.
10. macOS vraagt de rechten opnieuw (Agenda, Toegankelijkheid, enzovoort; niet meer om de camera). Geef alleen wat je wilt gebruiken. Wil je dat de app meestart bij het inloggen, zet dat dan aan in de instellingen van de app.

## Als je Apple-account de bundel-ID weigert

Zie je onder Team een rode melding zoals "Failed to register bundle identifier", dan is die naam al door iemand anders geclaimd. Kies dan een eigen naam en vervang hem op vier plekken. Gebruik alleen kleine letters, cijfers en punten, bijvoorbeeld `local.jouwnaam.boringnotch`:

1. In Xcode, target **boringNotch**, tab Signing & Capabilities: veld **Bundle Identifier** → `local.jouwnaam.boringnotch`.
2. Target **BoringNotchXPCHelper**, zelfde tab: **Bundle Identifier** → `local.jouwnaam.boringnotch.BoringNotchXPCHelper`.
3. Bestand `boringNotch/XPCHelperClient/XPCHelperClient.swift`, regel 8: vervang de naam tussen de aanhalingstekens door `local.jouwnaam.boringnotch.BoringNotchXPCHelper`.
4. Bestand `BoringNotchXPCHelper/BoringNotchXPCHelperProtocol.swift`, regel 28: idem.

Let op: de naam van de XPC-helper moet overal exact gelijk zijn, anders werkt de mediaweergave niet. Snelste manier: in Xcode **⌘⇧F** (zoek in project), zoek `local.notchtimer.boringnotch` en gebruik **Replace All**.

## Veelvoorkomende fouten

- **"Framework MediaRemoteAdapter.framework did not contain an Info.plist"**: de zip is uitgepakt zonder de snelkoppelingen in het framework te bewaren. Pak de zip opnieuw uit met de Finder (dubbelklik), niet met een ander programma. Werkt dat niet, zorg dan dat in `mediaremote-adapter/MediaRemoteAdapter.framework` deze drie snelkoppelingen bestaan: `Versions/Current → A`, `Resources → Versions/Current/Resources`, `MediaRemoteAdapter → Versions/Current/MediaRemoteAdapter`.
- **"Signing requires a development team"**: stap 5 is voor één van de twee targets overgeslagen.
- **Bestanden slepen naar de Shelf doet niets**: sluit de app af en start hem opnieuw vanuit de Finder (zie stap 9).
- **De Bluetooth-lijst in System is leeg**: alleen verbonden apparaten die hun batterijstand aan macOS melden verschijnen. Controleer in Systeeminstellingen > Bluetooth of macOS zelf een percentage toont; zo niet, dan kan de app het ook niet.
- **De notch is leeg of ziet er raar uit na de eerste start**: dat is de eerste keer normaal; macOS vraagt eerst om rechten.

## Voor wie liever de Terminal gebruikt

Na stap 5 kun je ook bouwen met dit commando (vanuit de projectmap, alles op één regel). Xcode maakt het certificaat dan zelf aan:

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -destination 'platform=macOS' -configuration Release -derivedDataPath ./DerivedData -allowProvisioningUpdates CODE_SIGN_IDENTITY="Apple Development" build
```

De app staat daarna in `DerivedData/Build/Products/Release/boringNotch.app`.

## Veiligheid in het kort

- Rechten (entitlements) van deze build: app-sandbox, agenda, Apple Events naar Spotify/Music, netwerk (voor de muziekfuncties van het origineel), bestanden die je zelf kiest. **Geen camera.**
- De nieuwe onderdelen (Timer, System, Bluetooth-batterijen) gebruiken geen netwerk, schrijven geen bestanden en vragen geen extra rechten.
- Deze build krijgt **geen automatische updates**. Beveiligingsfixes van het origineel moet je zelf ophalen door de nieuwe broncode te pakken en de patch opnieuw toe te passen.
- Deel je dit verder, dan moet de broncode mee en blijft de licentie GPL-3.0 (zie `LICENSE`).
- Origineel project: https://github.com/TheBoredTeam/boring.notch
