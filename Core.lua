local ADDON, ns = ...
local L = ns.L

-- The one global: other addons (a grind tracker, say) read the session through it.
OneClickFish = ns

local PREFIX = "|cff66ccffOneClick|rFish: "
function ns.Msg(fmt, ...) print(PREFIX .. string.format(fmt, ...)) end

-- ===========================================================================
-- One key, two jobs.
--
-- The key (Key Bindings > AddOns > OneClickFish) is re-pointed as the state
-- changes: a secure click that casts Fishing while nothing is out or the
-- bobber is out of reach, and Interact With Target once the game's soft
-- target is the bobber, so the same press loots it. Interact only reaches a
-- bobber with the soft-target settings on: they are switched on for the cast
-- and put back when the channel ends, and the backup is saved, so a crash
-- mid-cast still gets them back at the next login. docs/key-binding.md weighs
-- this against a plainer binding.
--
-- The secure button the key clicks is also on screen (Button.lua): a mouse
-- click does what the key does, and Shift + left click switches fishing mode
-- off, as the minimap button does. Fishing mode off: the key then does
-- nothing, nothing is counted or changed.
--
-- The key's click comes in as a mouse button of its own ("Key"), so a Shift
-- in the key (SHIFT-F) is not taken for the Shift + left click of the mouse.
--
-- The game has no "fish on the hook" event and no addon may click the bobber:
-- the splash is the cue, which is why music and ambience are lowered while the
-- line is out, and why the game keeps its sound in the background then: a
-- splash is heard from another window too.
-- ===========================================================================

local BINDING      = "ONECLICKFISH_CAST"
local BUTTON       = "OneClickFishButton"
local KEY_CLICK    = "Key"   -- the mouse button the key's click is delivered as
local FISHING      = 131474   -- the Fishing spell; its name is what the macro casts
local FISHING_TOOL = 28       -- the fishing tool slot
local SESSION_GAP  = 30 * 60  -- a cast this long after the last one starts a new session
local PROFESSION   = Enum.ItemClass and Enum.ItemClass.Profession or 19
local FISHING_SUB  = Enum.ItemProfessionSubclass and Enum.ItemProfessionSubclass.Fishing or 9
local WEAPON       = Enum.ItemClass and Enum.ItemClass.Weapon or 2
local POLE_SUB     = Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20

ns.FISHING_TOOL = FISHING_TOOL

-- Every Fishing the client has had; the event names the one that was cast.
local FISHING_SPELLS = {}
for _, id in ipairs({ 131474, 131490, 131476, 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410,
	158743, 271990, 377895, 1224771 }) do
	FISHING_SPELLS[id] = true
end

-- Soft-target interact while the line is out. Arc 0 is the game's own
-- keyboard/mouse default (no facing cone; the gamepad value of 1 misses a
-- bobber you are not facing dead-on). Range 100 with no hard cutoff: a bobber
-- cast far out would otherwise be excluded with nothing to tell it from a miss.
local CVARS = {
	SoftTargetInteract            = "3",
	SoftTargetInteractArc         = "0",
	SoftTargetInteractRange       = "100",
	SoftTargetInteractRangeIsHard = "0",
	SoftTargetInteractGameObject  = "1",   -- a bobber is a game object
	SoftTargetIconGameObject      = "1",
	SoftTargetIconInteract        = "1",
	SoftTargetTooltipInteract     = "1",
}

local db                     -- OneClickFishDB
local fishingName = "Fishing"
local button                 -- the secure button the key clicks
local fishing     = false    -- the Fishing channel is running
local bobberReady = false    -- the soft target is the bobber
local pendingBinding = false -- asked for in combat; done when it ends
local pendingCVars   = false
local castSerial = 0         -- tells a fresh cast from a stale fallback timer
local tallied    = false     -- this loot window is counted
local callbacks  = {}

function ns.IsFishing() return fishing end
function ns.IsBobberReady() return bobberReady end
function ns.IsEnabled() return db ~= nil and db.settings.enabled end

-- ---------------------------------------------------------------------------
-- Saved data (OneClickFishDB)
--
--   settings = { enabled=, autoEquip=, fastLoot=, chime=, duck=, musicVol=, ambienceVol=, boostSFX=, bgSound=,
--                showButton=, minimap=, lure= (itemID), lureAuto=, hat= (itemID),
--                locale= ("enUS" | "zhTW"; absent = follow the game) },
--   headBefore = what was on the head before the hat, while the hat is on
--   hud      = { show = "always" | "never", catches=, idle= (minutes without a cast before it goes),
--                scale=, locked= (the cast button too), point=, relPoint=, x=, y= },
--   button   = { point=, relPoint=, x=, y= },   minimap = { angle= },
--   session  = { casts=, catches=, items=, market=, vendor=, source=, start=, last=,
--                loot = { [itemID] = { link=, count=, value= } } },
--   cvarBackup, soundBackup = what was there before a cast, while the cast is on
-- ---------------------------------------------------------------------------

ns.defaults = {
	settings = { enabled = true, autoEquip = true, fastLoot = true, chime = true, duck = true, musicVol = 0.15,
		ambienceVol = 0.10, boostSFX = false, bgSound = true, showButton = true, minimap = true, lureAuto = false },
	hud = { show = "always", catches = true, idle = 5, scale = 1.0, locked = false, point = "CENTER",
		relPoint = "CENTER", x = 330, y = 20 },
	button = { point = "CENTER", relPoint = "CENTER", x = 0, y = -140 },
	minimap = { angle = 220 },
	session = { casts = 0, catches = 0, items = 0, market = 0, vendor = 0 },
}

local function InitDB()
	if type(OneClickFishDB) ~= "table" then OneClickFishDB = {} end
	db = OneClickFishDB
	for section, values in pairs(ns.defaults) do
		db[section] = db[section] or {}
		for k, v in pairs(values) do
			if db[section][k] == nil then db[section][k] = v end
		end
	end
	db.session.loot = db.session.loot or {}
	ns.db = db
	ns.ApplyLocale(db.settings.locale or GetLocale())
end

-- ---------------------------------------------------------------------------
-- Settings switched for the cast: soft-target interact, and the sound
-- ---------------------------------------------------------------------------

local function ApplyCVars()
	if db.cvarBackup then return end
	if InCombatLockdown() then return end
	db.cvarBackup = {}
	for k, v in pairs(CVARS) do
		db.cvarBackup[k] = C_CVar.GetCVar(k)
		C_CVar.SetCVar(k, v)
	end
end

local function RestoreCVars()
	if not db.cvarBackup then return end
	if InCombatLockdown() then pendingCVars = true; return end
	for k, v in pairs(db.cvarBackup) do C_CVar.SetCVar(k, v) end
	db.cvarBackup = nil
	pendingCVars = false
end

-- The sound settings switched while the line is out, each its own option:
-- music and ambience down, sound effects up, and sound kept in the background
-- (Sound_EnableSoundWhenGameIsInBG, the game's own "Sound in Background"), so
-- a splash is heard from another window. What was there is saved, and the
-- backup names exactly the settings that were switched.
local function DuckAudio()
	if db.soundBackup then return end
	local backup = {}
	if db.settings.duck then
		backup.Sound_MusicVolume    = C_CVar.GetCVar("Sound_MusicVolume")
		backup.Sound_AmbienceVolume = C_CVar.GetCVar("Sound_AmbienceVolume")
	end
	if db.settings.boostSFX then backup.Sound_SFXVolume = C_CVar.GetCVar("Sound_SFXVolume") end
	if db.settings.bgSound then backup.Sound_EnableSoundWhenGameIsInBG = C_CVar.GetCVar("Sound_EnableSoundWhenGameIsInBG") end
	if next(backup) == nil then return end
	db.soundBackup = backup
	ns.ApplyAudioLevels()
end

-- What the sound is set to while the line is out; a change in the levels lands at once.
function ns.ApplyAudioLevels()
	local backup = db.soundBackup
	if not backup then return end
	if backup.Sound_MusicVolume then C_CVar.SetCVar("Sound_MusicVolume", tostring(db.settings.musicVol)) end
	if backup.Sound_AmbienceVolume then C_CVar.SetCVar("Sound_AmbienceVolume", tostring(db.settings.ambienceVol)) end
	if backup.Sound_SFXVolume then C_CVar.SetCVar("Sound_SFXVolume", "1") end
	if backup.Sound_EnableSoundWhenGameIsInBG then C_CVar.SetCVar("Sound_EnableSoundWhenGameIsInBG", "1") end
end

local function RestoreAudio()
	if not db.soundBackup then return end
	for k, v in pairs(db.soundBackup) do C_CVar.SetCVar(k, v) end
	db.soundBackup = nil
end

-- By hand, for whatever a crash left behind
function ns.RestoreAll()
	RestoreCVars()
	RestoreAudio()
end

-- ---------------------------------------------------------------------------
-- The pole: the fishing tool slot, filled from the bags
-- ---------------------------------------------------------------------------

-- A pole is still a weapon of the Fishing Pole kind; a few are profession tools.
local function IsPole(itemID)
	local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
	return equipLoc == "INVTYPE_FISHINGTOOL"
		or (classID == WEAPON and subClassID == POLE_SUB)
		or (equipLoc == "INVTYPE_PROFESSION_TOOL" and classID == PROFESSION and subClassID == FISHING_SUB)
end

local function HasPole()
	return GetInventoryItemID("player", FISHING_TOOL) ~= nil
end

local function EquipBagPole()
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and IsPole(id) then
				C_Item.EquipItemByName(id, FISHING_TOOL)
				return true
			end
		end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- The lure: a consumable used on the pole, a temporary enchant that raises
-- the fishing skill and runs out. Known by item ID, newest first; nothing is
-- read off names or tooltips.
--
-- The fish-named "lures" from Dragonflight on (Scalebelly Mackerel Lure,
-- Ula'tek Snakehead Lure, 誘餌 in zhTW: "increases the chance to catch X for
-- 30 min") are not these: they are a buff on the player, never on the pole,
-- so the pole would read as bare and one would be used before every cast.
-- They are left out.
-- ---------------------------------------------------------------------------

local LURE_SETTLE = 5   -- seconds after a lure is put on before the pole is read again: the enchant lands late
local lureApplied       -- GetTime() of the last lure put on by the button

local LURES = {
	-- Midnight: Writhing Wiggleworm
	262650,
	-- older, good anywhere: Worm Supreme, Heat-Treated Spinning Lure, Sharpened Fish Hook, Feathered Lure, Glow Worm,
	-- Aquadynamic Fish Attractor, Bright Baubles, Flesh Eating Worm, Aquadynamic Fish Lens, Nightcrawlers, Shiny Bauble
	124674, 46006, 34832, 68049, 67404, 6533, 6532, 7307, 6811, 6530, 6529,
	-- hats whose use is a lure: Nat's Hat, Nat's Drinking Hat, Weather-Beaten Fishing Hat
	88710, 117405, 33820,
}

-- Head pieces worth wearing at the water: Elegant Artisan's Fishing Hat, Bright Linen Fishing Hat,
-- Nat's Hat, Nat's Drinking Hat, Weather-Beaten Fishing Hat, Lucky Fishing Hat
local HATS = { 239638, 239644, 88710, 117405, 33820, 19972 }

local function Rank(list)
	local rank = {}
	for i, id in ipairs(list) do rank[id] = i end
	return rank
end
local LURE_RANK, HAT_RANK = Rank(LURES), Rank(HATS)

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- What the client says about the pole's temporary enchant; nil when there is none.
local function LureInfo()
	local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, FISHING_TOOL)
	if ok and type(info) == "table" then return info end
end

-- Is a lure on the pole, whichever lure it is? One the client reports but
-- will not say more about (a secret value) counts: it is there.
function ns.HasLure()
	local info = LureInfo()
	if not info then return false end
	local id, ms = info.enchantID, info.remainingTimeMs
	if IsSecret(id) or IsSecret(ms) then return true end
	return (type(id) == "number" and id > 0) or (type(ms) == "number" and ms > 0)
end

-- Seconds the lure on the pole has left, 0 when there is none or the client will not say.
function ns.LureLeft()
	local info = LureInfo()
	if info and type(info.remainingTimeMs) == "number" and not IsSecret(info.remainingTimeMs) then
		return math.max(0, info.remainingTimeMs / 1000)
	end
	return 0
end

-- Is a lure wanted before the next cast? Only with none on the pole at all: a
-- lure that is on, another one or one about to run out, is never replaced.
-- One just put on is given a moment to show.
function ns.LureNeeded()
	if db.settings.lure == nil or ns.HasLure() then return false end
	return lureApplied == nil or GetTime() - lureApplied >= LURE_SETTLE
end

-- The known items the player has, in the list's order: { { id=, name=, icon= }, ... }.
-- extra: an item ID to count as held as well (what is worn).
local function Held(rank, extra)
	local have = {}
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and rank[id] then have[id] = true end
		end
	end
	if extra and rank[extra] then have[extra] = true end
	local list = {}
	for id in pairs(have) do
		local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
		list[#list + 1] = { id = id, name = name or tostring(id), icon = icon or C_Item.GetItemIconByID(id) }
	end
	table.sort(list, function(a, b) return rank[a.id] < rank[b.id] end)
	return list
end

-- The lures in the bags. The lure is picked from these.
function ns.LureCandidates()
	return Held(LURE_RANK)
end

-- ---------------------------------------------------------------------------
-- The hat: a head piece worn while fishing, the one before it after
-- ---------------------------------------------------------------------------

local HEAD = INVSLOT_HEAD or 1

-- The fishing hats in the bags, or on the head. The hat is picked from these.
function ns.HatCandidates()
	return Held(HAT_RANK, GetInventoryItemID("player", HEAD))
end

-- Out of combat, before a cast: the hat, if it is not on already.
local function WearHat()
	local hat = db.settings.hat
	if not hat or InCombatLockdown() then return end
	local worn = GetInventoryItemID("player", HEAD)
	if worn == hat or GetItemCount(hat) == 0 then return end
	db.headBefore = worn or db.headBefore
	C_Item.EquipItemByName(hat, HEAD)
end

-- Fishing mode off: whatever was worn before the hat, if it is still around.
local function WearHeadBefore()
	local before = db.headBefore
	db.headBefore = nil
	if before and not InCombatLockdown() and GetItemCount(before) > 0 then C_Item.EquipItemByName(before, HEAD) end
end

-- The icon the professions book uses for Fishing, while the character has it;
-- the minimap button and the HUD wear it.
local FALLBACK_ICON = "Interface\\Icons\\Trade_Fishing"
function ns.ProfessionIcon()
	if type(GetProfessions) ~= "function" then return FALLBACK_ICON end
	local _, _, _, fishingIndex = GetProfessions()
	if fishingIndex then
		local _, icon = GetProfessionInfo(fishingIndex)
		if icon then return icon end
	end
	return FALLBACK_ICON
end

-- ---------------------------------------------------------------------------
-- The key
-- ---------------------------------------------------------------------------

-- Re-point the key to what the moment needs. Blizzard's own soft-target prompt
-- on the bobber is what says Interact will reach it; without it the key casts
-- again instead (the macro leads with /stopcasting, so a channel whose bobber
-- is out of reach is cleanly given up). With fishing mode off the key keeps
-- its own binding, which only does this.
local function RefreshBinding()
	if not button then return end
	if InCombatLockdown() then pendingBinding = true; return end
	pendingBinding = false
	ClearOverrideBindings(button)
	if not db.settings.enabled then return end
	for _, key in ipairs({ GetBindingKey(BINDING) }) do
		if fishing and bobberReady then
			SetOverrideBinding(button, true, key, "INTERACTTARGET")
		else
			SetOverrideBindingClick(button, true, key, BUTTON, KEY_CLICK)
		end
	end
end

-- The binding itself (Bindings.xml): only reached while no override is in
-- place, so it puts one there; the next press then does the work.
function OneClickFish_Run()
	RefreshBinding()
end

-- Is this the edge (key down or key up, as ActionButtonUseKeyDown says) the
-- secure click acts on? Preparing on the other one as well could stop or
-- recast the channel just started.
function ns.IsActionEdge(self, down)
	if down == nil then return true end
	local useKeyDown = self:GetAttribute("useOnKeyDown")
	if useKeyDown == nil then useKeyDown = C_CVar.GetCVarBool("ActionButtonUseKeyDown") end
	return down == (useKeyDown and true or false)
end

-- A click that casts or loots: the key's, or the mouse's left button without
-- Shift (Shift + left click switches fishing mode off: Button.lua, after the
-- click; the secure side of it is "none").
function ns.IsCastClick(mouseButton)
	if mouseButton == KEY_CLICK then return true end
	return mouseButton == "LeftButton" and not IsShiftKeyDown()
end

-- Out of combat, before the secure click: the macro for the moment, the
-- settings for the cast, the pole.
local function OnPreClick(self, mouseButton, down)
	if not ns.IsCastClick(mouseButton) or not ns.IsActionEdge(self, down) then return end
	if InCombatLockdown() or not db.settings.enabled then return end
	if fishing and bobberReady then
		-- a mouse click while the key is pointed at Interact: the same thing
		self:SetAttribute("macrotext", "/interact")
		return
	end
	if not fishing then WearHat() end
	if db.settings.lureAuto and not fishing and ns.LureNeeded() and GetItemCount(db.settings.lure) > 0 then
		-- the lure goes on the pole: that is a cast of its own, so this press
		-- does only that, and the next one casts
		self:SetAttribute("macrotext", "/use item:" .. db.settings.lure .. "\n/use " .. FISHING_TOOL)
		lureApplied = GetTime()
		C_Timer.After(1, ns.Changed)   -- the HUD and the button, once the lure is on
		return
	end
	self:SetAttribute("macrotext", "/stopcasting\n/cast " .. fishingName)
	ApplyCVars()
	-- a cast that never starts (moving, no water) must not leave the settings on
	castSerial = castSerial + 1
	local serial = castSerial
	C_Timer.After(2, function()
		if serial == castSerial and not fishing then RestoreCVars() end
	end)
	if db.settings.autoEquip and not HasPole() then EquipBagPole() end
end

local function CreateButton()
	local b = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate, BackdropTemplate")
	b:RegisterForClicks("AnyDown", "AnyUp")   -- the template acts on the one edge ActionButtonUseKeyDown picks
	b:SetAttribute("type1", "macro")           -- the left button: the right one opens the settings
	b:SetAttribute("shift-type1", "none")      -- Shift + left: no secure action; fishing mode off, in PostClick
	b:SetAttribute("type-" .. KEY_CLICK, "macro")   -- the key, Shift or not
	b:SetAttribute("macrotext", "/cast " .. fishingName)
	b:SetScript("PreClick", OnPreClick)
	ns.Button.Setup(b)   -- what it looks like on screen
	return b
end

function ns.GetKey()
	return (GetBindingKey(BINDING))
end

-- key: a binding string ("SHIFT-F"), or nil to unbind. Whatever it did before, it does this now.
function ns.SetKey(key)
	if InCombatLockdown() then ns.Msg(L["Not in combat."]); return end
	if key then
		local taken = GetBindingAction(key)
		if taken and taken ~= "" and taken ~= BINDING then
			ns.Msg(L["%s was taken from %s."], GetBindingText(key), GetBindingText(taken, nil, true) or taken)
		end
	end
	local k1, k2 = GetBindingKey(BINDING)
	if k1 then SetBinding(k1) end
	if k2 then SetBinding(k2) end
	if key then SetBinding(key, BINDING) end
	SaveBindings(GetCurrentBindingSet())
	RefreshBinding()
	ns.RefreshOptions()
	ns.Button.Refresh()
end

-- ---------------------------------------------------------------------------
-- Fishing mode: all of it on, or all of it off
-- ---------------------------------------------------------------------------

function ns.SetEnabled(on)
	on = on and true or false
	if db.settings.enabled == on then return end
	db.settings.enabled = on
	if not on then
		fishing, bobberReady = false, false
		ns.RestoreAll()
		WearHeadBefore()
	end
	RefreshBinding()
	ns.Msg(L[on and "MODE_on" or "MODE_off"])
	ns.Changed()
end

-- ---------------------------------------------------------------------------
-- The session: from the first cast, until a long pause or a reset
-- ---------------------------------------------------------------------------

local function Notify()
	ns.HUD.Refresh()
	if #callbacks == 0 then return end
	local stats = ns.GetStats()
	for _, fn in ipairs(callbacks) do pcall(fn, stats) end
end

-- quiet: no chat line (a new session starting on its own)
function ns.ResetSession(quiet)
	local s = db.session
	for k, v in pairs(ns.defaults.session) do s[k] = v end
	s.loot = {}
	s.source, s.start, s.last = nil, nil, nil
	if not quiet then ns.Msg(L["Session reset."]) end
	Notify()
end

local function BeginCast()
	local s, now = db.session, time()
	if s.last and now - s.last > SESSION_GAP then ns.ResetSession(true) end
	s.start = s.start or now
	s.last = now
	s.casts = s.casts + 1
end

-- A market price when an auction addon has one (nobody vendors fish), else what a vendor pays.
local function ItemValue(link)
	local AA = Auctionator and Auctionator.API and Auctionator.API.v1
	if AA and AA.GetAuctionPriceByItemLink then
		local ok, price = pcall(AA.GetAuctionPriceByItemLink, ADDON, link)
		if ok and type(price) == "number" and price > 0 then return price, "Auctionator" end
	end
	if TSM_API and TSM_API.GetCustomPriceValue and TSM_API.ToItemString then
		local ok, price = pcall(TSM_API.GetCustomPriceValue, "dbmarket", TSM_API.ToItemString(link))
		if ok and type(price) == "number" and price > 0 then return price, "TSM" end
	end
	local price = select(11, C_Item.GetItemInfo(link))
	return price or 0, "vendor"
end

local function TallyLoot()
	local s = db.session
	s.catches = s.catches + 1
	for i = 1, GetNumLootItems() do
		local link = GetLootSlotLink(i)
		if link then
			local _, _, quantity = GetLootSlotInfo(i)
			quantity = quantity or 1
			local price, source = ItemValue(link)
			local value = price * quantity
			s.items = s.items + quantity
			if source == "vendor" then
				s.vendor = s.vendor + value
			else
				s.market = s.market + value
				s.source = source
			end
			local id = tonumber(link:match("item:(%d+)"))
			if id then
				local entry = s.loot[id] or { link = link, count = 0, value = 0 }
				entry.count = entry.count + quantity
				entry.value = (entry.value or 0) + value
				s.loot[id] = entry
			end
		end
	end
end

-- Dejunk's verdict on what was caught, by item ID, read off the bags whenever
-- they change; the HUD leaves such catches out of its list. Nothing without Dejunk.
local junk = {}
local function RefreshJunk()
	wipe(junk)
	if not (DejunkApi and DejunkApi.IsJunk) then return end
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and db.session.loot[id] and not junk[id] then
				local ok, isJunk = pcall(DejunkApi.IsJunk, DejunkApi, bag, slot)
				if ok and isJunk then junk[id] = true end
			end
		end
	end
end
function ns.IsJunk(id) return junk[id] == true end

-- For the HUD and for other addons: OneClickFish.GetStats() -> table,
-- OneClickFish.RegisterCallback(fn) -> fn(stats) whenever the numbers change.
function ns.GetStats()
	if not db then return nil end
	local s = db.session
	local elapsed = s.start and math.max(0, time() - s.start) or 0
	local hours = elapsed / 3600
	local value = s.market + s.vendor
	return {
		casts = s.casts, catches = s.catches, items = s.items,
		value = value, marketValue = s.market, vendorValue = s.vendor, source = s.source,
		elapsed = elapsed,
		catchPerHour = elapsed >= 60 and s.catches / hours or 0,
		goldPerHour  = elapsed >= 60 and value / hours or 0,
		loot = s.loot,   -- itemID -> { link, count }
	}
end

function ns.RegisterCallback(fn)
	if type(fn) == "function" then callbacks[#callbacks + 1] = fn end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local function IsFishingSpell(spellID)
	if type(spellID) == "number" and not IsSecret(spellID) and FISHING_SPELLS[spellID] then return true end
	local name = UnitChannelInfo("player")
	return name ~= nil and name == fishingName
end

-- A passing critter or NPC can be the soft target as well: only a game object is the bobber.
local function IsGameObject(guid)
	if type(guid) ~= "string" then return false end
	local ok, found = pcall(string.find, guid, "^GameObject%-")
	return ok and found ~= nil
end

local function OnChannelStart(spellID)
	if not db.settings.enabled or not IsFishingSpell(spellID) then return end
	fishing, bobberReady = true, false
	BeginCast()
	ApplyCVars()   -- also for a Fishing cast from the action bar: the key loots that one too
	DuckAudio()
	if db.settings.chime then PlaySound(SOUNDKIT.MAP_PING, "Master") end
	RefreshBinding()
	ns.Button.Refresh()
	Notify()
end

local function OnChannelStop()
	if not fishing then return end
	fishing, bobberReady = false, false
	RefreshBinding()
	RestoreCVars()
	RestoreAudio()
	ns.Button.Refresh()
	Notify()
end

local function OnLoot()
	if tallied or not db.settings.enabled or not IsFishingLoot() then return end
	tallied = true
	TallyLoot()
	if db.settings.fastLoot then
		for i = GetNumLootItems(), 1, -1 do LootSlot(i) end
	end
	Notify()
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS",
	"PLAYER_SOFT_INTERACT_CHANGED", "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "PLAYER_REGEN_ENABLED",
	"PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED" }) do
	events:RegisterEvent(e)
end
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

events:SetScript("OnEvent", function(self, event, a1, a2, a3)
	if event == "ADDON_LOADED" then
		if a1 == ADDON then
			InitDB()
			self:UnregisterEvent("ADDON_LOADED")
		end

	elseif event == "PLAYER_LOGIN" then
		fishingName = C_Spell.GetSpellName(FISHING) or fishingName
		ns.RestoreAll()   -- whatever the last session left on (a crash, a /reload mid-cast)
		if not button then button = CreateButton() end
		RefreshBinding()
		ns.Options.RegisterInGame()
		ns.Minimap.Refresh()
		ns.Button.Refresh()
		if not GetBindingKey(BINDING) and not db.hinted then
			db.hinted = true
			ns.Msg(L["No key bound. Bind one under Key Bindings > AddOns > OneClickFish, or in /ocfish."])
		end
		ns.HUD.Refresh()

	elseif event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_BINDINGS" then
		RefreshBinding()
		if event == "UPDATE_BINDINGS" then
			ns.RefreshOptions()
			ns.Button.Refresh()   -- the key it shows
		end

	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		OnChannelStart(a3)

	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		OnChannelStop()

	elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
		local ready = fishing and IsGameObject(a2)
		if ready ~= bobberReady then
			bobberReady = ready
			RefreshBinding()
			ns.Button.Refresh()
			ns.HUD.Refresh()
		end

	elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
		OnLoot()

	elseif event == "LOOT_CLOSED" then
		tallied = false

	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingBinding then RefreshBinding() end
		if pendingCVars and not fishing then RestoreCVars() end

	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		if a1 == FISHING_TOOL then ns.Button.Refresh() end
		if a1 == HEAD then ns.RefreshOptions() end   -- the hats on offer

	elseif event == "BAG_UPDATE_DELAYED" then
		RefreshJunk()
		ns.RefreshOptions()   -- the lures and hats on offer
		ns.HUD.Refresh()

	elseif event == "GET_ITEM_INFO_RECEIVED" then
		if db.session.loot[a1] then ns.HUD.Refresh() end   -- a catch whose name arrived late

	elseif event == "PLAYER_LOGOUT" then
		ns.RestoreAll()
	end
end)

-- What every setting calls after it changed something.
function ns.Changed()
	ns.RefreshOptions()
	ns.HUD.Refresh()
	ns.Button.Refresh()
	ns.Minimap.Refresh()
end

-- ---------------------------------------------------------------------------
-- The ways in: slash command, addon compartment
-- ---------------------------------------------------------------------------

SLASH_ONECLICKFISH1 = "/ocfish"
SLASH_ONECLICKFISH2 = "/oneclickfish"
SlashCmdList.ONECLICKFISH = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "reset" then
		ns.ResetSession()
	elseif msg == "restore" then
		ns.RestoreAll()
		ns.Msg(L["Interact and sound settings restored."])
	elseif msg == "on" or msg == "off" then
		ns.SetEnabled(msg == "on")
	elseif msg == "lure" then
		-- what the client says about the pole's temporary enchant, raw, for a bug report
		local ok, info = pcall(function() return C_PaperDollInfo.GetTemporaryEnchantmentInfo(FISHING_TOOL) end)
		if not ok then
			ns.Msg("GetTemporaryEnchantmentInfo: error (%s)", tostring(info))
		elseif type(info) ~= "table" then
			ns.Msg("GetTemporaryEnchantmentInfo: %s", tostring(info))
		else
			ns.Msg("GetTemporaryEnchantmentInfo: enchantID=%s remainingTimeMs=%s charges=%s expires=%s",
				tostring(info.enchantID), tostring(info.remainingTimeMs), tostring(info.chargesRemaining), tostring(info.hasExpirationTime))
		end
		ns.Msg("LureLeft: %d s, lure item: %s", ns.LureLeft(), tostring(db.settings.lure))
	else
		ns.ToggleOptions()
	end
end

function OneClickFish_OnAddonCompartmentClick()
	ns.ToggleOptions()
end
