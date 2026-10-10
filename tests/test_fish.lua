-- The addon loaded as the game does, then a fishing trip driven through its
-- events against mock frames: the key, the settings switched for the cast, the
-- loot and the session, combat, a reload mid-cast, the settings window.

local T = dofile(HERE .. "/stubs.lua")
local check, eq, W, fire, flush = T.check, T.eq, T.W, T.fire, T.flush
T.captureChat()

W.items[6256] = { equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2, subClassID = 20 }   -- a pole: a weapon of the Fishing Pole kind
W.items[1234] = { price = 50 }
W.items[5678] = { price = 10 }
local FISH, JUNK = "|cff|Hitem:1234::::|h[Fish]|h|r", "|Hitem:5678|h[Junk]|h"
local CLICK = "CLICK OneClickFishButton:Key"   -- the key's click comes as a mouse button of its own

local ns = T.boot()
local L = ns.L
local db = OneClickFishDB

-- ---------------------------------------------------------------- login
check(T.said(L["No key bound. Bind one under Key Bindings > AddOns > OneClickFish, or in /ocfish."]), "no key: a hint")
eq(db.hinted, true, "the hint is given once")
local button = T.frames.OneClickFishButton
check(button ~= nil and button:IsShown(), "the secure button is there and never hidden")
check(ns.HUD.GetFrame() == nil, "no HUD before the first cast")
check(ns.Options.gamePanel ~= nil, "an entry in the game's AddOns options")

ns.SetKey("F")
eq(W.bindings.ONECLICKFISH_CAST, "F", "the key is bound")
eq(W.overrides.F, CLICK, "idle: the key clicks the cast button")
eq(T.frames.OneClickFishButton.hotkey:GetText(), "F", "the cast button shows the key")

-- ---------------------------------------------------------------- the cast
W.bags = { [0] = { 1234, 6256 } }
button:Click("Key", true)    -- the key, down, with ActionButtonUseKeyDown on
eq(W.cvars.SoftTargetInteract, "3", "soft-target interact on for the cast")
eq(W.cvars.SoftTargetInteractRange, "100", "and its range")
eq(db.cvarBackup.SoftTargetInteract, "1", "the player's own value is kept")
eq(W.toolSlot, 6256, "a pole from the bags is equipped")
check(button.__attributes.macrotext:find("/cast Fishing", 1, true), "the macro casts Fishing")
check(T.logged("secure:/stopcasting\n/cast Fishing"), "the click ran it")

W.channel = { startMS = 0, endMS = 20000 }
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-1", 131474)
eq(ns.IsFishing(), true, "the line is out")
eq(db.session.casts, 1, "one cast")
eq(db.session.start, 1000, "the session starts with it")
eq(W.cvars.Sound_MusicVolume, "0.15", "music lowered")
eq(W.cvars.Sound_AmbienceVolume, "0.1", "ambience lowered")
eq(db.soundBackup.Sound_MusicVolume, "0.8", "the player's own volume is kept")
eq(W.cvars.Sound_SFXVolume, "0.6", "sound effects left alone (boost is off)")
eq(W.cvars.Sound_EnableSoundWhenGameIsInBG, "1", "sound kept in the background, so the splash is heard from another window")
eq(db.soundBackup.Sound_EnableSoundWhenGameIsInBG, "0", "the player's own setting is kept")
check(T.logged("sound:3175"), "a chime")
local hud = ns.HUD.GetFrame()
check(hud ~= nil and hud:IsShown(), "the HUD comes up with the first cast")
local R = function(i, j) return hud.rows[i].pairs[j] end
eq(R(1, 1).label:GetText(), L["ROW_casts"], "the first row: casts")
eq(R(1, 1).value:GetText(), "1", "one")
eq(R(1, 2).label:GetText(), L["ROW_catches"], "catches")
eq(R(1, 2).value:GetText(), "0", "none yet")
eq(R(1, 3).label:GetText(), L["ROW_perHour"], "and per hour")
eq(R(1, 3).value:GetText(), "0", "none yet")
check(R(1, 2).label.__point[2] > R(1, 1).label.__point[2], "pairs laid out left to right")
eq(R(3, 1).label.__point[2], R(1, 1).label.__point[2], "the rate row's first pair at the same stop as the first row's")
check(R(1, 1).value.__point[2] == R(1, 1).label and R(1, 1).value.__point[4] == 4, "a value sits right behind its label")
check(R(1, 3).value.__point[1] == "TOPRIGHT" and R(1, 3).value.__point[2] == -10, "the last pair of a row ends at the right edge")
check(R(3, 2).value.__point[1] == "TOPRIGHT" and R(3, 2).value.__point[2] == -10, "Time as well")
check(R(3, 2).label.__point[2] == R(3, 2).value, "its label right before it")
R(1, 3).value.GetStringWidth = function() return 300 end   -- a number wider than the box allows
ns.HUD.Refresh()
check(hud:GetWidth() >= 300 + 20, "the box widens past its cap rather than let a number run out of it")
R(1, 3).value.GetStringWidth = nil
eq(R(2, 1).label:GetText(), string.format(L["ROW_value"], L["SRC_vendor"]), "vendor prices so far")
check(hud.title:GetText():find(L["Session"], 1, true), "titled a session")
eq(hud.icon:GetTexture(), "fishicon", "the profession's icon")
eq(W.overrides.F, CLICK, "bobber not registered yet: the key would cast again")

fire("PLAYER_SOFT_INTERACT_CHANGED", nil, "Creature-0-1-2-3-4")
eq(ns.IsBobberReady(), false, "a critter is not the bobber")
eq(W.overrides.F, CLICK, "so the key still casts")
fire("PLAYER_SOFT_INTERACT_CHANGED", "Creature-0-1-2-3-4", "GameObject-0-1-2-3-4")
eq(ns.IsBobberReady(), true, "the bobber")
eq(W.overrides.F, "INTERACTTARGET", "the key now interacts")

-- ---------------------------------------------------------------- the loot
W.fishingLoot = true
W.loot = { { link = FISH, qty = 2 }, { link = JUNK, qty = 1 } }
fire("LOOT_READY")
eq(db.session.catches, 1, "one catch")
eq(db.session.items, 3, "three items")
eq(db.session.vendor, 110, "valued at vendor prices")
check(T.logged("loot:2") and T.logged("loot:1"), "looted at once")
eq(db.session.loot[1234].count, 2, "the catch is on the list")
eq(hud.catches[1].count:GetText(), "2", "HUD: the most caught first")
check(hud.catches[1].name:GetText():find("item1234", 1, true), "with its name")
eq(hud.catches[2].count:GetText(), "1", "then the rest")
check(hud.catches[1].value:GetText():find("^1.0") and hud.catches[1].value:GetText():find("SilverIcon"), "what the catch is worth")
check(hud.rule:IsShown(), "under a line")
eq(hud.catches[1].frame.link, FISH, "the row knows its item, for the tooltip")
hud.catches[1].frame:GetScript("OnEnter")(hud.catches[1].frame)
check(GameTooltip:IsShown(), "hover: the item")
fire("LOOT_OPENED")
eq(db.session.catches, 1, "the same window is not counted twice")
fire("LOOT_CLOSED")
W.fishingLoot = false
fire("LOOT_READY")
eq(db.session.catches, 1, "loot that is not from fishing is not counted")

W.channel = nil
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-1", 131474)
eq(ns.IsFishing(), false, "the line is in")
eq(W.cvars.SoftTargetInteract, "1", "soft-target interact back")
eq(db.cvarBackup, nil, "nothing left to restore")
eq(W.cvars.Sound_MusicVolume, "0.8", "music back")
eq(W.cvars.Sound_EnableSoundWhenGameIsInBG, "0", "background sound back")
eq(db.soundBackup, nil, "nothing left to restore (sound)")
eq(W.overrides.F, CLICK, "the key casts again")
check(hud:IsShown(), "the HUD stays")

-- ---------------------------------------------------------------- market prices, rates
W.addons = { Auctionator = true }
Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(_, link)
	if link:find("item:1234", 1, true) then return 1000 end
end } } }
W.epoch = 1000 + 600
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-2", 131474)
W.fishingLoot = true
W.loot = { { link = FISH, qty = 1 } }
fire("LOOT_READY")
fire("LOOT_CLOSED")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-2", 131474)
eq(db.session.market, 1000, "an Auctionator price")
eq(db.session.source, "Auctionator", "and its source")
local stats = ns.GetStats()
eq(stats.value, 1110, "market and vendor together")
eq(stats.elapsed, 600, "ten minutes")
eq(stats.catchPerHour, 12, "two catches in ten minutes")
eq(stats.goldPerHour, 6660, "gold per hour")
check(R(2, 1).value:GetText():find("11.1", 1, true) and R(2, 1).value:GetText():find("UI-SilverIcon", 1, true), "value row: 11.1 silver, with the coin")
local M = ns.HUD.Money
check(M(0):find("^0") and M(0):find("CopperIcon"), "0c")
check(M(56):find("^56") and M(56):find("CopperIcon"), "56c")
check(M(3456):find("^34.5") and M(3456):find("SilverIcon"), "34.5s, cut not rounded")
check(M(1054500):find("^105.4") and M(1054500):find("GoldIcon"), "105.4g")
check(M(10544500):find("^1,054") and M(10544500):find("GoldIcon"), "1,054g: no decimal past four digits")
check(M(102000000):find("^10.2k") and M(102000000):find("GoldIcon"), "10.2kg")
check(M(12345000000):find("^1.2m"), "1.2mg")
eq(R(2, 1).label:GetText(), string.format(L["ROW_value"], "Auctionator"), "says who priced it")
eq(R(3, 1).label:GetText(), L["ROW_gold"], "the rate row: gold per hour")
check(R(3, 1).value:GetText():find("^66.6") and R(3, 1).value:GetText():find("UI-SilverIcon", 1, true), "66.6 silver an hour, with the coin")
eq(R(3, 2).label:GetText(), L["ROW_time"], "and the time")
eq(R(3, 2).value:GetText(), "10:00", "ten minutes")
eq(R(1, 2).value:GetText(), "2", "two catches")
eq(R(1, 3).value:GetText(), "12", "twelve an hour")

local got
ns.RegisterCallback(function(s) got = s end)
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-3", 131474)
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-3", 131474)
check(got ~= nil and got.casts == 3, "another addon is told")

-- each sound switch on its own: no ducking, but the boost and the background sound
db.settings.duck, db.settings.boostSFX = false, true
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-3a", 131474)
eq(W.cvars.Sound_MusicVolume, "0.8", "duck off: music left alone")
eq(W.cvars.Sound_SFXVolume, "1", "boost on its own: sound effects up")
eq(W.cvars.Sound_EnableSoundWhenGameIsInBG, "1", "and sound in the background")
eq(db.soundBackup.Sound_MusicVolume, nil, "only what was switched is in the backup")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-3a", 131474)
eq(W.cvars.Sound_SFXVolume, "0.6", "sound effects back")
eq(W.cvars.Sound_EnableSoundWhenGameIsInBG, "0", "background sound back")
db.settings.boostSFX, db.settings.bgSound = false, false
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-3b", 131474)
eq(db.soundBackup, nil, "all three off: the sound is not touched")
eq(W.cvars.Sound_EnableSoundWhenGameIsInBG, "0", "background sound left alone")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-3b", 131474)
db.settings.duck, db.settings.bgSound = true, true

-- a cast from the action bar: no click, but the key loots that one as well
W.cvars.SoftTargetInteract = "1"
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-4", 131474)
eq(W.cvars.SoftTargetInteract, "3", "soft-target interact on without the button")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-4", 131474)

-- grey things, and what Dejunk calls junk, stay off the list
W.items[6001] = { price = 1, quality = 0 }   -- grey
W.items[6002] = { price = 5 }                 -- fine, but Dejunk says junk
W.items[6003] = { price = 5 }                 -- fine
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-4a", 131474)
W.loot = { { link = "|Hitem:6001|h[Grey]|h", qty = 1 }, { link = "|Hitem:6002|h[Junk]|h", qty = 1 }, { link = "|Hitem:6003|h[Fine]|h", qty = 1 } }
fire("LOOT_READY")
fire("LOOT_CLOSED")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-4a", 131474)
W.bags = { [0] = { 1234, 6256, 6001, 6002, 6003 } }
W.junk = { [6002] = true }
fire("BAG_UPDATE_DELAYED")
local listed = {}
for _, r in ipairs(hud.catches) do if r.frame:IsShown() then listed[#listed + 1] = r.frame.link end end
check(not table.concat(listed, "|"):find("item:6001", 1, true), "a grey catch is not listed")
check(not table.concat(listed, "|"):find("item:6002", 1, true), "nor what Dejunk calls junk")
check(table.concat(listed, "|"):find("item:6003", 1, true), "the rest is")
eq(db.session.items, 7, "all three counted all the same")
W.junk = {}

-- a catch the client has no name for yet
W.uncached = { [9999] = true }
W.items[9999] = { price = 1 }
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-4b", 131474)
W.loot = { { link = "|Hitem:9999|h[Late Fish]|h", qty = 1 } }
fire("LOOT_READY")
fire("LOOT_CLOSED")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-4b", 131474)
local function Row(id)
	for _, r in ipairs(hud.catches) do if r.frame:IsShown() and r.frame.link:find("item:" .. id, 1, true) then return r end end
end
check(Row(9999) and Row(9999).name:GetText():find("Late Fish", 1, true), "named off the link meanwhile")
check(T.logged("load:9999"), "and asked for")
W.uncached = nil
fire("GET_ITEM_INFO_RECEIVED", 9999)
check(Row(9999) and Row(9999).name:GetText():find("item9999", 1, true), "named when the data arrives")

-- ---------------------------------------------------------------- a cast that never starts
button:Click("LeftButton", true)
eq(W.cvars.SoftTargetInteract, "3", "switched on for the click")
flush()   -- two seconds later, nothing was cast
eq(W.cvars.SoftTargetInteract, "1", "switched back")
eq(db.cvarBackup, nil, "and forgotten")
button:Click("LeftButton", false)
eq(db.cvarBackup, nil, "the key-up edge does nothing")

-- ---------------------------------------------------------------- a long pause: a new session
W.epoch = W.epoch + 31 * 60
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-5", 131474)
eq(db.session.casts, 1, "a new session")
eq(db.session.catches, 0, "from nothing")
eq(db.session.start, W.epoch, "starting now")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-5", 131474)

-- ---------------------------------------------------------------- combat
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-6", 131474)
fire("PLAYER_SOFT_INTERACT_CHANGED", nil, "GameObject-0-1-2-3-4")
eq(W.overrides.F, "INTERACTTARGET", "ready")
W.combat = true
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-6", 131474)   -- combat breaks the channel
eq(W.overrides.F, "INTERACTTARGET", "in combat the key cannot be re-pointed")
eq(W.cvars.SoftTargetInteract, "3", "nor the settings put back")
eq(W.cvars.Sound_MusicVolume, "0.8", "the sound can")
W.combat = false
fire("PLAYER_REGEN_ENABLED")
eq(W.overrides.F, CLICK, "after combat: the key casts")
eq(W.cvars.SoftTargetInteract, "1", "and the settings are back")

-- ---------------------------------------------------------------- a reload mid-cast
db.cvarBackup = { SoftTargetInteract = "1" }
db.soundBackup = { Sound_MusicVolume = "0.8" }
W.cvars.SoftTargetInteract, W.cvars.Sound_MusicVolume = "3", "0.15"
fire("PLAYER_LOGIN")
eq(W.cvars.SoftTargetInteract, "1", "login puts the interact settings back")
eq(W.cvars.Sound_MusicVolume, "0.8", "and the sound")

-- ---------------------------------------------------------------- the settings window
SlashCmdList.ONECLICKFISH("")
local main = ns.Options.GetFrame()
check(main ~= nil and main:IsShown(), "/ocfish opens the window")
check(UISpecialFrames[1] == "OneClickFishFrame", "Esc closes it")
eq(ns.Options.GetSelection(), "fishing", "opens on the Fishing tab")
check(main.pages.fishing:IsShown() and not main.pages.hud:IsShown(), "only that page is shown")
main.tabs.hud:Click()
eq(ns.Options.GetSelection(), "hud", "the HUD tab")
check(main.pages.hud:IsShown() and not main.pages.fishing:IsShown(), "shows its page")
main.tabs.general:Click()
check(main.priceAddons.Auctionator:GetText():find(L["STATE_installed"], 1, true), "Auctionator seen")
check(main.priceAddons.TradeSkillMaster:GetText():find(L["STATE_missing"], 1, true), "TSM not")
main.tabs.fishing:Click()
eq(main.keyButton:GetText(), "F", "the key is shown")
eq(main.autoEquip:GetChecked(), true, "equip: on by default")
main.autoEquip:Click()
eq(db.settings.autoEquip, false, "equip switched off")
eq(main.bgSound:GetChecked(), true, "background sound: on by default")
main.bgSound:Click()
eq(db.settings.bgSound, false, "and switched off")
main.bgSound:Click()
main.music.plus:Click()
eq(db.settings.musicVol, 0.2, "music up a step")
eq(main.music.value:GetText(), "20%", "and shown")
main.hudShow:Click()
eq(db.hud.show, "never", "HUD off")
check(not hud:IsShown(), "and gone")
main.hudShow:Click()
check(hud:IsShown(), "and back")
main.hudScale.plus:Click()
eq(db.hud.scale, 1.1, "HUD scale up")
main.hudCatches:Click()
eq(db.hud.catches, false, "catch list off")
check(not hud.rule:IsShown(), "and gone")
main.hudCatches:Click()
main.idle.minus:Click()
eq(db.hud.idle, 4, "idle minutes down a step")
main.idle.plus:Click()
db.button.x = 99
main.resetPositions:Click()
eq(db.button.x, 0, "the cast button is put back too")
hud.reset:Click()
eq(db.session.casts, 0, "the HUD's Reset button resets the session")
eq(next(db.session.loot), nil, "and the catches with it")
check(T.said(L["Session reset."]), "and said so")
check(hud:IsShown(), "the HUD stays while the window is open")

-- the key: cleared, then listened for
main.clear:Click()
eq(W.bindings.ONECLICKFISH_CAST, nil, "key cleared")
eq(main.keyButton:GetText(), L["Not bound"], "and shown as such")
eq(next(W.overrides), nil, "no override without a key")
main.keyButton:Click("LeftButton")
eq(main.keyButton:GetText(), L["Press a key..."], "listening")
main.keyButton:GetScript("OnKeyDown")(main.keyButton, "LSHIFT")
eq(main.keyButton:GetText(), L["Press a key..."], "a modifier alone is not a key")
W.shift = true
main.keyButton:GetScript("OnKeyDown")(main.keyButton, "G")
W.shift = false
eq(W.bindings.ONECLICKFISH_CAST, nil, "not bound on the press (its release would fire the key)")
main.keyButton:GetScript("OnKeyUp")(main.keyButton, "G")
eq(W.bindings.ONECLICKFISH_CAST, "SHIFT-G", "shift-G bound on the release")
eq(main.keyButton:GetText(), "SHIFT-G", "and shown")
eq(W.overrides["SHIFT-G"], CLICK, "and re-pointed")
main.keyButton:Click("LeftButton")
main.keyButton:GetScript("OnKeyDown")(main.keyButton, "ESCAPE")
eq(main.keyButton:GetText(), "SHIFT-G", "Escape: never mind")
W.bindings.OTHER = "H"
main.keyButton:Click("LeftButton")
main.keyButton:GetScript("OnKeyDown")(main.keyButton, "H")
main.keyButton:GetScript("OnKeyUp")(main.keyButton, "H")
eq(W.bindings.OTHER, nil, "a key taken from another action")
check(T.said("H"), "is announced")

-- language
ns.SetLanguage("zhTW")
eq(main.autoEquip.label:GetText(), ns.locales.zhTW["Equip a fishing pole from your bags"], "labels follow the language")
eq(hud.reset:GetText(), ns.locales.zhTW["Reset"], "so does the HUD")
eq(hud.rows[1].pairs[1].label:GetText(), "Casts", "whose terms stay English")
ns.SetLanguage(nil)
eq(main.autoEquip.label:GetText(), L["Equip a fishing pole from your bags"], "and back to the game's")

main:Hide()
check(not hud:IsShown(), "with the window closed and nothing cast, no HUD")

-- ---------------------------------------------------------------- the HUD by hand
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-7", 131474)
check(hud:IsShown(), "a cast brings it back")
hud:GetScript("OnDragStop")(hud)
eq(db.hud.x, 10, "dragged: the place is kept")
W.ctrl = true
hud:GetScript("OnMouseWheel")(hud, -1)
eq(db.hud.scale, 1.0, "Ctrl + wheel resizes")
W.ctrl = false
hud:GetScript("OnMouseUp")(hud, "RightButton")
check(main:IsShown(), "right click: the settings")
main:Hide()
SlashCmdList.ONECLICKFISH("restore")
check(T.said(L["Interact and sound settings restored."]), "/ocfish restore")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-7", 131474)

-- ---------------------------------------------------------------- idle: the HUD goes, and comes back
W.epoch = W.epoch + 4 * 60
ns.HUD.Refresh()
check(hud:IsShown(), "four minutes on: still there")
W.epoch = W.epoch + 2 * 60
ns.HUD.Refresh()
check(not hud:IsShown(), "six minutes without a cast: gone")
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-8", 131474)
check(hud:IsShown(), "the next cast brings it back")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-8", 131474)

-- ---------------------------------------------------------------- the cast button on screen
eq(button.__alpha, 1, "the cast button is on screen")
eq(button.icon:GetTexture(), "pole6256", "wearing the pole")
button:GetScript("OnEnter")(button)
check(T.frames.OneClickFishTooltip:IsShown() and T.frames.OneClickFishItemTooltip:IsShown(), "hover: the hints, then the pole")
button:GetScript("OnLeave")(button)
check(not T.frames.OneClickFishItemTooltip:IsShown(), "and gone")
button:Click("RightButton", true)
check(main:IsShown(), "right click: the settings")
button:Click("RightButton", true)
check(not main:IsShown(), "and closed again")
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-9", 131474)
fire("PLAYER_SOFT_INTERACT_CHANGED", nil, "GameObject-0-1-2-3-4")
check(button.frameArt.__vertex[2] > 0.8, "ready: the frame goes green")
button:Click("LeftButton", true)
eq(button.__attributes.macrotext, "/interact", "a mouse click while ready loots")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-9", 131474)
db.settings.showButton = false
ns.Button.Refresh()
eq(button.__alpha, 0, "switched off: invisible")
check(button:IsShown(), "but never hidden, so the key can still click it")
db.settings.showButton = true
ns.Button.Refresh()

-- ---------------------------------------------------------------- Shift + left click: fishing mode off
W.shift = true
local before = #W.log
button:Click("LeftButton", true)
eq(db.settings.enabled, false, "Shift + left click: fishing mode off")
check(T.said(L["MODE_off"]), "and said so")
eq(#W.log, before, "nothing cast, nothing switched")
eq(db.cvarBackup, nil, "no settings switched for a cast")
W.shift = false
ns.SetEnabled(true)
W.shift = true
button:Click("Key", true)   -- the key is SHIFT-something: its Shift is not the mouse's
check(W.log[#W.log] == "secure:/stopcasting\n/cast Fishing", "a Shift in the key still casts")
eq(db.settings.enabled, true, "and does not switch fishing mode")
W.shift = false
flush()

-- ---------------------------------------------------------------- the minimap button and fishing mode
local mm = ns.Minimap.GetFrame()
check(mm ~= nil and mm:IsShown(), "a minimap button")
eq(mm.icon:GetTexture(), "fishicon", "with the profession's icon")
mm:Click("LeftButton")
eq(db.settings.enabled, false, "left click: fishing mode off")
check(T.said(L["MODE_off"]), "and said so")
eq(next(W.overrides), nil, "the key does nothing")
eq(button.__alpha, 0, "no cast button")
check(not hud:IsShown(), "no HUD")
local casts = db.session.casts
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-10", 131474)
eq(db.session.casts, casts, "a cast is not counted")
eq(W.cvars.SoftTargetInteract, "1", "nor are the settings touched")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-10", 131474)
mm:Click("LeftButton")
eq(db.settings.enabled, true, "and on again")
eq(W.overrides.J, nil, "(no key bound right now)")
eq(button.__alpha, 1, "the cast button is back")
mm:Click("RightButton")
check(main:IsShown(), "right click: the settings")
main:Hide()
db.settings.minimap = false
ns.Minimap.Refresh()
check(not mm:IsShown(), "the minimap button can be switched off")
db.settings.minimap = true
ns.Minimap.Refresh()
SlashCmdList.ONECLICKFISH("off")
eq(db.settings.enabled, false, "/ocfish off")
SlashCmdList.ONECLICKFISH("on")
eq(db.settings.enabled, true, "/ocfish on")

-- ---------------------------------------------------------------- the lure
W.items[88710] = { use = true, price = 1 }     -- Nat's Hat: a hat, and a lure
W.items[262650] = { use = true, price = 1 }    -- Wriggling Worm
W.items[7777] = { use = true, price = 1 }      -- a potion: usable, not a lure
W.bags = { [0] = { 7777, 88710, 262650, 262650 } }
local candidates = ns.LureCandidates()
eq(#candidates, 2, "the known lures in the bags, once each")
eq(candidates[1].id, 262650, "newest first")
eq(candidates[2].id, 88710, "then the hat")
check(not R(4, 1).label:IsShown(), "no lure row without a lure picked")
db.settings.lure = 262650
W.lure = nil
ns.Changed()
eq(ns.LureLeft(), 0, "no lure on the pole")
check(R(4, 1).label:IsShown(), "the lure row")
check(R(4, 1).value:GetText():find(L["LURE_none"], 1, true), "says none")
check(button.frameArt.__vertex[1] > 0.9 and button.frameArt.__vertex[2] < 0.7, "the button goes amber")
button:Click("LeftButton", true)
check(button.__attributes.macrotext:find("/cast", 1, true), "without auto apply, the press still casts")
db.settings.lureAuto = true
button:Click("LeftButton", true)
eq(button.__attributes.macrotext, "/use item:262650\n/use 28", "auto: the press puts the lure on the pole")
W.now = W.now + 2
button:Click("LeftButton", true)
check(button.__attributes.macrotext:find("/cast", 1, true), "a second press before the enchant shows casts: no second lure")
W.now = W.now + 10
button:Click("LeftButton", true)
eq(button.__attributes.macrotext, "/use item:262650\n/use 28", "still none on the pole after a while: applied again")
W.lure = { remainingTimeMs = 540000 }
ns.Changed()
eq(R(4, 1).value:GetText(), "9:00", "the client says nine minutes")
button:Click("LeftButton", true)
check(button.__attributes.macrotext:find("/cast", 1, true), "with a lure on, the press casts")
W.lure = { remainingTimeMs = 30000 }
check(not ns.LureNeeded(), "half a minute left is still a lure: not replaced")
W.lure = { enchantID = 4225 }
check(ns.HasLure() and not ns.LureNeeded(), "another lure the client will not time is still a lure")
W.lure = { enchantID = 0, remainingTimeMs = 0 }
check(not ns.HasLure(), "an empty report is none")
W.lure = { remainingTimeMs = 30000 }
SlashCmdList.ONECLICKFISH("lure")
check(T.said("remainingTimeMs=30000"), "/ocfish lure reports the raw answer")
W.lure = nil
db.settings.lure, db.settings.lureAuto = nil, false

-- ---------------------------------------------------------------- the hat
W.items[239638] = { price = 1 }   -- Elegant Artisan's Fishing Hat: worn
W.items[33820] = { price = 1 }    -- Weather-Beaten Fishing Hat: in a bag
W.items[5555] = { price = 1 }     -- some helmet: not a fishing hat
W.bags = { [0] = { 5555, 33820 } }
W.head = 239638
local hats = ns.HatCandidates()
eq(#hats, 2, "the known hats in the bags or on the head")
eq(hats[1].id, 239638, "the one worn counts, and comes first")
eq(hats[2].id, 33820, "then the one in the bag")
db.settings.hat = 33820
button:Click("LeftButton", true)
eq(W.head, 33820, "the hat goes on before the cast")
eq(db.headBefore, 239638, "and what was there is remembered")
button:Click("LeftButton", true)
local swaps = 0
for _, line in ipairs(W.log) do if line == "equip:33820:1" then swaps = swaps + 1 end end
eq(swaps, 1, "only once")
ns.SetEnabled(false)
eq(W.head, 239638, "fishing mode off: the old head piece is back")
eq(db.headBefore, nil, "and forgotten")
ns.SetEnabled(true)
db.settings.hat = nil

-- the settings show them as icons
W.bags = { [0] = { 262650, 33820 } }
SlashCmdList.ONECLICKFISH("")
db.settings.lure, db.settings.hat = 262650, nil
ns.Options.Refresh()
eq(#main.lure.buttons, 3, "the lure tray: none, the worm, and the hat (its use is a lure)")
eq(main.lure.buttons[2].id, 262650, "the worm")
check(main.lure.buttons[2].selected, "picked")
check(not main.lure.buttons[1].selected, "none is not")
eq(main.hat.buttons[2].id, 239638, "the hat tray: the one worn")
eq(main.hat.buttons[3].id, 33820, "and the one in the bag")
check(main.hat.buttons[1].selected, "none picked")
main.hat.buttons[3]:Click()
eq(db.settings.hat, 33820, "a click picks")
main.hat.buttons[1]:Click()
eq(db.settings.hat, nil, "the X picks none")
main.lure.buttons[2]:GetScript("OnEnter")(main.lure.buttons[2])
check(GameTooltip:IsShown(), "hover: the item")
db.settings.lure, db.settings.hat = nil, nil
main:Hide()

-- the binding's own function: only ever puts the override in place
W.bindings.ONECLICKFISH_CAST = "J"
OneClickFish_Run()
eq(W.overrides.J, CLICK, "the base binding arms the key")

return T.report("fish " .. GetLocale())
