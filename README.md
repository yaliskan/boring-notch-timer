# Boring Notch + Timer + System

Een aangepaste versie van [Boring Notch](https://github.com/TheBoredTeam/boring.notch) 2.7.3 voor de Mac, met twee extra tabbladen in de notch en zonder camera.

*(English: a modified build of Boring Notch 2.7.3 with a Timer tab, a System tab (CPU / RAM / Bluetooth battery levels) and the camera feature removed. Licensed under GPL-3.0 like the original; see below.)*

## Wat zit erin?

| Tabblad | Wat het doet |
|---|---|
| **Home** en **Shelf** | Ongewijzigd uit het origineel: muziek, agenda, bestanden neerzetten, AirDrop. |
| **Timer** | Knoppen 5 / 10 / 15 / 30 min of een eigen tijd. Lopende timer klein naast de dichte notch. Bij afloop 4x een geluid en de notch klapt open. |
| **System** | CPU- en RAM-meter, en de batterijstand van verbonden Bluetooth-apparaten (AirPods, Magic Keyboard, Magic Mouse, Beats, controllers). Optioneel klein naast de dichte notch. |

De tabbladen zijn te **verslepen**: een tabje ingedrukt houden, slepen, loslaten; de volgorde wordt onthouden.

Verwijderd: de **spiegelfunctie**. Deze app heeft geen camera-recht en kan de camera dus nooit gebruiken. Automatische updates staan uit.

Alles in de nieuwe tabbladen is alleen-lezen en lokaal: geen netwerk, geen bestanden, geen logboek, geen extra rechten.

## Downloaden (kant-en-klaar)

1. Ga naar **[Releases](../../releases)** en download `BoringNotch-Timer-2.7.3.zip`.
2. Pak de zip uit en sleep `boringNotch.app` naar je map **Programma's**.
3. Draait de officiële Boring Notch? Sluit die eerst af (sterretje in de menubalk > Quit).
4. Start de app vanuit **Programma's** (dubbelklik).
5. macOS toont de eerste keer een waarschuwing, omdat de app niet bij Apple is genotariseerd (dat vereist een betaald developer-account). Ga dan naar **Systeeminstellingen > Privacy en beveiliging**, scrol naar beneden en klik bij boringNotch op **Toch openen**. Dit hoeft maar één keer.
6. macOS vraagt daarna om rechten (Agenda, Toegankelijkheid, enzovoort). Geef alleen wat je wilt gebruiken.

Vereist een Mac met Apple-chip en macOS 15.5 of nieuwer.

## Zelf bouwen

Wil je liever zelf bouwen, of de code aanpassen? Zie **[BOUWEN-NL.md](BOUWEN-NL.md)**: een stap-voor-stap-uitleg met Xcode en een gratis Apple-account. Alle wijzigingen ten opzichte van het origineel staan ook los in `boring-notch-timer.patch`.

## Licentie en herkomst

Dit project is gebaseerd op [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch), versie 2.7.3, en valt net als het origineel onder de **GNU General Public License v3.0** (zie [LICENSE](LICENSE)). De oorspronkelijke README staat in [README-original.md](README-original.md). Licenties van gebruikte onderdelen staan in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).

Wijzigingen ten opzichte van het origineel:

- Nieuw: `boringNotch/components/Live activities/TimerFeature.swift`, `SystemMonitorFeature.swift`, `DeviceBatteryFeature.swift`.
- Aangepast: `ContentView.swift`, `TabSelectionView.swift` (verslepen), `enums/generic.swift`, `models/BoringViewModel.swift`, `SettingsView.swift`, `OnboardingView.swift`, `WebcamManager.swift` (lege huls), entitlements en projectinstellingen (camera verwijderd, Sparkle uit, eigen bundel-ID).

Dit is een hobbyproject zonder verband met het Boring Notch-team of Apple.
