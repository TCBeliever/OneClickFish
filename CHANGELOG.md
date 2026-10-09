# Changelog

## 0.1.0 (2026-10-09)

- One key casts Fishing; while the bobber is the soft target the same key loots it. The soft-target interact settings are on only while the line is out and put back afterwards, also at login after a crash or a reload mid-cast.
- A fishing pole from your bags is equipped before the cast, and a fishing hat if one is picked (what was worn before is put back when fishing mode goes off); the catch is looted at once; a chime when the line lands.
- A lure picked from the bags: what is left of it on the HUD, the cast button amber when the pole wants one, and optionally applied by the button before a cast.
- Music and ambience lowered while the line is out, sound effects optionally boosted; levels in the settings.
- Session HUD: casts, catches, catches per hour, value, gold per hour, time, the catches of the session under them (count, value, hover for the item), the channel draining along the bottom, and a Reset button. Prices from Auctionator or TSM, else the vendor. Gone after five minutes without a cast (adjustable), a new session after thirty.
- A cast button on screen wearing the equipped pole, showing its key, with its tooltip: left click casts or loots, right click opens the settings. A minimap button with the Fishing profession's icon: left click switches fishing mode on or off, right click opens the settings.
- Settings window in three tabs (Fishing, HUD, General) with a key capture and a note on where prices come from; `/ocfish`, `/ocfish on|off`, `/ocfish reset`, `/ocfish restore`; the addon compartment and the game's AddOns list.
- `OneClickFish.GetStats()` and `OneClickFish.RegisterCallback(fn)` for other addons.
- Locales: enUS, zhTW.
