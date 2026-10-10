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

## 0.2.1 (2026-10-10)

- Sound kept in the background while the line is out (the game's own *Sound in Background*, switched on for the cast and put back after), so the splash is heard from another window. On by default; a check box under *Sound while the line is out*.
- The three sound switches no longer depend on each other: *Louder sound effects* works with *Lower music and ambience* off.
- HUD: each number has its own label. The first row is Casts, Catches and Catch/hr side by side, the rate row Gold/hr and Time, laid out like tab stops with a fixed gap; a value's slot only widens, so ticking numbers do not shift the labels after them. In zhTW the HUD's terms stay English (Casts, Catches, Catch/hr, Est. value, Gold/hr); the lure stays Chinese.
- The lure list is skill lures only: the fish-named lures from Dragonflight on (Scalebelly Mackerel Lure and the like, 誘餌) are a buff on the player, not an enchant on the pole, so the pole read as bare and one was used before every cast. Writhing Wiggleworm (Midnight), the old lures and the hats stay.
- HUD: the rows of pairs share a grid. Each label sits at its column's stop with its value right behind it, and the last pair of a row hugs the right edge, so every row ends flush there; the stops spread over the box's width. The box widens for the numbers rather than cut them; only a catch's name is cut. Time is Time in zhTW as well.
- The lure is put on by the button only when the pole has none at all. One that is on, another kind or one about to run out, is never replaced, and a second press right after applying one no longer applies another.

## 0.2.2 (2026-10-10)

- Shift + left click on the cast button switches fishing mode off, as the minimap button does. The key's click now comes in as a button of its own, so a Shift in the key (SHIFT-F) is not taken for it.
