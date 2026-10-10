-- WoW API stubs for the OneClickFish tests (stock Lua 5.1 via lupa).
-- ROOT (repo root) and LOCALE are set by the runner. Returns T (helpers);
-- world state is T.W.

local T = { passed = 0, failed = 0 }
local realPrint = print

function T.check(cond, name)
	if cond then T.passed = T.passed + 1 else T.failed = T.failed + 1; realPrint("FAIL: " .. name) end
end
function T.eq(a, b, name)
	T.check(a == b, name .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end

local W = {
	combat = false, now = 0, epoch = 1000,
	cvars = {
		SoftTargetInteract = "1", SoftTargetInteractArc = "0", SoftTargetInteractRange = "15",
		SoftTargetInteractRangeIsHard = "1", SoftTargetInteractGameObject = "0", SoftTargetIconGameObject = "0",
		SoftTargetIconInteract = "0", SoftTargetTooltipInteract = "0",
		Sound_MusicVolume = "0.8", Sound_AmbienceVolume = "0.7", Sound_SFXVolume = "0.6",
		Sound_EnableSoundWhenGameIsInBG = "0",
		ActionButtonUseKeyDown = "1",
	},
	bindings = {},    -- action -> key
	overrides = {},   -- key -> command
	bags = {},        -- bag -> { itemID, ... }
	toolSlot = nil,   -- what is in the fishing tool slot
	items = {},       -- itemID -> { equipLoc=, classID=, subClassID=, price= }
	loot = {},        -- { { link=, qty= }, ... } in the open loot window
	fishingLoot = false,
	channel = nil,    -- { startMS=, endMS= } while the player channels
	log = {},
}
T.W = W
local function log(s) W.log[#W.log + 1] = s end
function T.logged(s)
	for _, line in ipairs(W.log) do if line == s then return true end end
	return false
end

function GetLocale() return LOCALE or "enUS" end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function InCombatLockdown() return W.combat end
function GetTime() return W.now end
function time() return W.epoch end
function issecretvalue(v) return false end
function IsControlKeyDown() return W.ctrl or false end
function IsShiftKeyDown() return W.shift or false end
function IsAltKeyDown() return false end
function IsMouseButtonDown() return false end
function GameTooltip_Hide() end
function HideUIPanel() end
function PlaySound(id) log("sound:" .. tostring(id)) end
SOUNDKIT = { MAP_PING = 3175 }
SlashCmdList = {}
UISpecialFrames = {}
NUM_BAG_SLOTS = 4
Enum = { ItemClass = { Profession = 19 }, ItemProfessionSubclass = { Fishing = 9 } }

C_CVar = {
	GetCVar = function(k) return W.cvars[k] end,
	SetCVar = function(k, v) W.cvars[k] = tostring(v); log("cvar:" .. k .. "=" .. tostring(v)); return true end,
	GetCVarBool = function(k) return W.cvars[k] == "1" end,
}

-- bindings: none of this is allowed in combat
local function Protected() if W.combat then error("protected in combat") end end
function GetBindingKey(action) return W.bindings[action] end
function GetBindingText(key) return key end
function GetBindingAction(key)
	for action, k in pairs(W.bindings) do if k == key then return action end end
	return ""
end
function SetBinding(key, action)
	Protected()
	for a, k in pairs(W.bindings) do if k == key then W.bindings[a] = nil end end
	if action then W.bindings[action] = key end
	return true
end
function SaveBindings() end
function GetCurrentBindingSet() return 1 end
function SetOverrideBinding(_, _, key, command) Protected(); W.overrides[key] = command end
function SetOverrideBindingClick(_, _, key, name, mouse) Protected(); W.overrides[key] = "CLICK " .. name .. ":" .. (mouse or "LeftButton") end
function ClearOverrideBindings() Protected(); wipe(W.overrides) end

function UnitChannelInfo()
	if W.channel then return "Fishing", "", "", W.channel.startMS, W.channel.endMS end
end
C_Spell = { GetSpellName = function(id) if id == 131474 then return "Fishing" end end }

local function ItemID(idOrLink)
	if type(idOrLink) == "number" then return idOrLink end
	return tonumber(idOrLink:match("item:(%d+)"))
end
ITEM_QUALITY_COLORS = { [0] = { hex = "|cff9d9d9d" }, [1] = { hex = "|cffffffff" } }
Enum.ItemQuality = { Poor = 0 }
-- W.junk[id]: Dejunk calls it junk
DejunkApi = { IsJunk = function(self, bag, slot) local id = W.bags[bag] and W.bags[bag][slot]; return id ~= nil and W.junk[id] == true end }
W.junk = {}
C_Item = {
	GetItemInfoInstant = function(id)
		local it = W.items[id] or {}
		return id, "", "", it.equipLoc, 0, it.classID, it.subClassID
	end,
	-- W.uncached[id]: the client has no data for it yet
	GetItemInfo = function(idOrLink)
		local id = ItemID(idOrLink)
		if W.uncached and W.uncached[id] then return nil end
		local it = W.items[id] or {}
		return "item" .. id, "link", it.quality or 1, 1, 1, "", "", 1, "", "icon" .. id, it.price or 0
	end,
	GetItemIconByID = function(id) return "icon" .. id end,
	RequestLoadItemDataByID = function(id) log("load:" .. id) end,
	EquipItemByName = function(id, slot)
		log("equip:" .. id .. ":" .. slot)
		if slot == 1 then
			if W.head then W.bags[0] = W.bags[0] or {}; table.insert(W.bags[0], W.head) end
			W.head = id
		else
			W.toolSlot = id
		end
	end,
}
function GetInventoryItemTexture(_, slot) if slot == 28 and W.toolSlot then return "pole" .. W.toolSlot end end
-- W.items[id].use: the item can be used
C_Item.GetItemSpell = function(id) local it = W.items[id]; if it and it.use then return "Use", 1 end end
function GetItemCount(id)
	local n = 0
	for _, bag in pairs(W.bags) do for _, item in ipairs(bag) do if item == id then n = n + 1 end end end
	return n
end
-- W.lure = { remainingTimeMs = } while the pole has a lure
C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot) if slot == 28 then return W.lure end end }
-- W.sets[id] = { name, equipped }
W.sets = {}
C_EquipmentSet = {
	GetEquipmentSetIDs = function() local t = {} for id in pairs(W.sets) do t[#t + 1] = id end table.sort(t) return t end,
	GetEquipmentSetInfo = function(id) local s = W.sets[id]; if s then return s[1], 134400, id, s[2] end end,
	GetEquipmentSetID = function(name) for id, s in pairs(W.sets) do if s[1] == name then return id end end end,
	UseEquipmentSet = function(id)
		log("equipset:" .. id)
		for k, s in pairs(W.sets) do s[2] = (k == id) end
		return true
	end,
}
function GetProfessions() return 1, 2, 3, 4 end
function GetProfessionInfo(i) if i == 4 then return "Fishing", "fishicon" end end
function GetCursorPosition() return 500, 400 end
C_Container = {
	GetContainerNumSlots = function(bag) return #(W.bags[bag] or {}) end,
	GetContainerItemID = function(bag, slot) return W.bags[bag] and W.bags[bag][slot] end,
}
-- the head: W.head; a new piece sends the old one to bag 0
function GetInventoryItemID(_, slot)
	if slot == 28 then return W.toolSlot end
	if slot == 1 then return W.head end
end
-- W.items[id].tip: lines of the item's tooltip
C_TooltipInfo = { GetItemByID = function(id)
	local it = W.items[id]
	if not it then return nil end
	local lines = {}
	for _, text in ipairs(it.tip or {}) do lines[#lines + 1] = { leftText = text } end
	return { lines = lines }
end }
INVSLOT_HEAD = 1

function IsFishingLoot() return W.fishingLoot end
function GetNumLootItems() return #W.loot end
function GetLootSlotLink(i) return W.loot[i] and W.loot[i].link end
function GetLootSlotInfo(i) return "icon", "name", W.loot[i] and W.loot[i].qty or 1 end
function LootSlot(i) log("loot:" .. i) end

Settings = {
	RegisterCanvasLayoutCategory = function(panel, name) return { name = name } end,
	RegisterAddOnCategory = function() end,
}

local timers = {}
C_Timer = { After = function(d, fn) timers[#timers + 1] = { d = d, fn = fn } end }
-- runs the timers whose delay is <= limit (default: all), and whatever they schedule
function T.flush(limit)
	limit = limit or 10
	for _ = 1, 10 do
		local run, keep = {}, {}
		for _, t in ipairs(timers) do
			if t.d <= limit then run[#run + 1] = t else keep[#keep + 1] = t end
		end
		if #run == 0 then break end
		timers = keep
		table.sort(run, function(a, b) return a.d < b.d end)
		for _, t in ipairs(run) do t.fn() end
	end
end

-- ---------------------------------------------------------------------------
-- A frame that accepts any widget method. Field reads that are not methods
-- stay nil, as on a real frame. Scripts and registered events are kept so
-- tests can click things and fire events at every listener. A click on a
-- secure action button logs the macro it would run.
-- ---------------------------------------------------------------------------
T.frames = {}      -- by global name
T.all = {}

local function Mock(kind, name)
	local scripts = {}
	local obj = { __kind = kind, __name = name, __shown = true, __scripts = scripts, __events = {} }
	T.all[#T.all + 1] = obj
	local methods = {
		SetScript = function(self, n, fn) scripts[n] = fn end,
		GetScript = function(self, n) return scripts[n] end,
		RegisterEvent = function(self, e) self.__events[e] = true end,
		RegisterUnitEvent = function(self, e) self.__events[e] = true end,
		UnregisterEvent = function(self, e) self.__events[e] = nil end,
		UnregisterAllEvents = function(self) self.__events = {} end,
		IsShown = function(self) return self.__shown end,
		Show = function(self)
			local was = self.__shown
			self.__shown = true
			if not was and scripts.OnShow then scripts.OnShow(self) end
		end,
		Hide = function(self)
			local was = self.__shown
			self.__shown = false
			if was and scripts.OnHide then scripts.OnHide(self) end
		end,
		SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
		SetText = function(self, text) self.__text = text end,
		GetText = function(self) return self.__text end,
		GetName = function(self) return self.__name end,
		CreateFontString = function() return Mock("FontString") end,
		CreateTexture = function() return Mock("Texture") end,
		GetStringWidth = function() return 60 end,
		GetWidth = function(self) return self.__width or 120 end,
		SetWidth = function(self, w) self.__width = w end,
		SetSize = function(self, w, h) self.__width, self.__height = w, h end,
		GetHeight = function(self) return self.__height or 20 end,
		SetHeight = function(self, h) self.__height = h end,
		GetEffectiveScale = function(self) return self.__scale or 1 end,
		GetPoint = function(self)
			if self.__point then return unpack(self.__point) end
			return "TOP", nil, "TOP", 10.4, -20.6
		end,
		StopMovingOrSizing = function(self) self.__point = { "TOP", nil, "TOP", 10.4, -20.6 } end,
		IsMouseOver = function() return false end,
		SetScale = function(self, s) self.__scale = s end,
		SetAlpha = function(self, a) self.__alpha = a end,
		SetBackdropColor = function(self, r, g, b, a) self.__bg = { r, g, b, a } end,
		SetBackdropBorderColor = function(self, r, g, b, a) self.__border = { r, g, b, a } end,
		SetColorTexture = function(self, r, g, b, a) self.__color = { r, g, b, a } end,
		SetTextColor = function(self, r, g, b) self.__textColor = { r, g, b } end,
		SetPoint = function(self, ...) self.__point = { ... } end,
		SetAttribute = function(self, k, v) self.__attributes = self.__attributes or {}; self.__attributes[k] = v end,
		GetAttribute = function(self, k) return self.__attributes and self.__attributes[k] end,
		SetTexture = function(self, t) self.__texture = t end,
		GetTexture = function(self) return self.__texture end,
		SetVertexColor = function(self, r, g, b) self.__vertex = { r, g, b } end,
		CreateMaskTexture = function() return Mock("MaskTexture") end,
		Click = function(self, button, down)
			button = button or "LeftButton"
			if scripts.PreClick then scripts.PreClick(self, button, down) end
			if self.__template and self.__template:find("SecureActionButtonTemplate", 1, true) then
				local a = self.__attributes or {}
				local prefix = W.shift and "shift-" or ""
				local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2" or ("-" .. button)
				local kind = a[prefix .. "type" .. suffix] or a["type" .. suffix] or a.type
				if kind == "macro" then log("secure:" .. tostring(a.macrotext)) end
			elseif scripts.OnClick then
				scripts.OnClick(self, button, down)
			end
			if scripts.PostClick then scripts.PostClick(self, button, down) end
		end,
	}
	return setmetatable(obj, { __index = function(_, k)
		if methods[k] then return methods[k] end
		if k == "SetLabel" then return nil end   -- only the addon's own widgets have it
		if type(k) == "string" and k:match("^%u%l+%u") then return function() end end
		return nil
	end })
end
T.Mock = Mock

function CreateFrame(kind, name, parent, template)
	local f = Mock(kind, name)
	f.__template = template
	if name then
		T.frames[name] = f
		_G[name] = f
	end
	return f
end
UIParent = Mock("Frame", "UIParent")
GameTooltip = Mock("GameTooltip", "GameTooltip")
Minimap = Mock("Frame", "Minimap")

-- Every frame listening to `event` hears it, then the timers run.
function T.raw(event, ...)
	local listeners = {}
	for _, f in ipairs(T.all) do
		if f.__events[event] and f.__scripts.OnEvent then listeners[#listeners + 1] = f end
	end
	for _, f in ipairs(listeners) do f.__scripts.OnEvent(f, event, ...) end
end
function T.fire(event, ...)
	T.raw(event, ...)
	T.flush()
end

-- ---------------------------------------------------------------------------
-- The addon, loaded from its .toc as the game does
-- ---------------------------------------------------------------------------
local ADDON = "OneClickFish"
C_AddOns = {
	GetAddOnMetadata = function() return "0.0.0" end,
	IsAddOnLoaded = function(name) return W.addons and W.addons[name] or false end,
}

function T.boot()
	local private = {}
	for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
		line = line:gsub("\r", "")
		if line ~= "" and not line:match("^#") then
			local chunk, err = loadfile(ROOT .. "/" .. line:gsub("\\", "/"))
			assert(chunk, err)
			chunk(ADDON, private)
		end
	end
	T.raw("ADDON_LOADED", ADDON)
	T.fire("PLAYER_LOGIN")
	return private
end

-- print is captured so addon chat output does not drown the results
T.chat = {}
function T.captureChat() print = function(...) T.chat[#T.chat + 1] = table.concat({ ... }, " ") end end
function T.releaseChat() print = realPrint end
function T.said(text)
	for _, line in ipairs(T.chat) do if line:find(text, 1, true) then return true end end
	return false
end

function T.report(label)
	realPrint(("%s: %d passed, %d failed"):format(label, T.passed, T.failed))
	return T.failed
end

return T
