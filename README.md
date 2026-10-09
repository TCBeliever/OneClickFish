# OneClickFish

**One key casts, the same key loots.**

[繁體中文](README.zhTW.md) · [Changelog](CHANGELOG.md)

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)

Bind one key under *Key Bindings > AddOns > OneClickFish*, or in `/ocfish`. Press it at the water to cast Fishing. When the bobber splashes, press it again: it loots the bobber, no aiming, no mouse.

## What it does

- **One key.** While the line is out, the game's soft-target interact is switched on (wide arc, long range). When the soft target is the bobber, the key is re-pointed to *Interact With Target*; otherwise it casts. Your own settings are put back when the line is in, and also at login if a crash left them on.
- **Around the cast.** A fishing pole from your bags is equipped before the cast, and so is a fishing hat if you picked one (the known ones, from your bags or your head); what was on your head before comes back when fishing mode is switched off. The catch goes straight to your bags, no loot window. A short ping when the line lands.
- **Lure.** Pick one of the lures in your bags (the known ones from Dragonflight on, the old ones, and the hats whose use is a lure). What is left of it shows on the HUD and the cast button turns amber when the pole wants a new one; with *Apply before casting* on, a press puts it on the pole and the next press casts.
- **Sound.** There is no event for a bite: the splash is the cue. Music and ambience are lowered while the line is out and put back when it is in; sound effects can be boosted as well.
- **Session HUD.** A small box from the first cast on, three lines: casts / catches / per hour, value, gold per hour with the time, and under them what was caught, the most caught first, with its count and what it is worth; hover a row for the item. Grey things, and what Dejunk calls junk, stay off the list. Prices from Auctionator or TSM when one is installed, else from the vendor. The channel drains along the bottom while the line is out; a Reset button in the title row starts over. Money shows with the game's coins, at most four digits and one decimal (105.4g, 1,054g, 10.2kg). The box goes after some minutes without a cast (5 by default) and comes back with the next one; thirty minutes without a cast starts a new session.
- **On screen.** A cast button wearing the pole in your fishing tool slot, with that pole's tooltip: left click casts or loots, right click opens the settings. A minimap button in the game's own style with the Fishing profession's icon: left click switches fishing mode on or off (the key, the button, the settings switched for a cast, the counting, all at once), right click opens the settings.

Everything is drawn with the game's own fonts and a flat palette, the same as CombatKit. No libraries.

## Install

- Unzip into `World of Warcraft/_retail_/Interface/AddOns/` so that `AddOns/OneClickFish/OneClickFish.toc` exists.
- Retail only (Interface 12.1). Not built for Classic.

## Commands

- `/ocfish`: the settings. Also the addon compartment at the minimap, the game's Options > AddOns list, and a right click on the HUD.
- `/ocfish on`, `/ocfish off`: fishing mode.
- `/ocfish reset`: start the session over.
- `/ocfish restore`: put your interact and sound settings back by hand.
- `/ocfish lure`: what the client says about the lure on the pole, for a bug report.

## For other addons

`OneClickFish.GetStats()` returns the session (casts, catches, items, value, marketValue, vendorValue, source, elapsed, catchPerHour, goldPerHour); `OneClickFish.RegisterCallback(fn)` calls `fn(stats)` whenever the numbers change.

## Development

`deploy.bat` copies the addon into the game folder; `/reload` in game. `python tests/run_tests.py` (needs `pip install lupa`) compiles every file, checks the release metadata and locale coverage, and runs a fishing trip against WoW API stubs in both languages. [docs/key-binding.md](docs/key-binding.md) weighs the two ways of wiring the key.

The one-key technique follows [EasyFishing](https://www.curseforge.com/wow/addons/easyfishing) (MIT); see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
