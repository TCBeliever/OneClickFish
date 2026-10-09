local ADDON, ns = ...
local L, Skin = ns.L, ns.Skin

-- ===========================================================================
-- The settings window: three tabs. Fishing (the mode, the key, what happens
-- around a cast, the sound), HUD (what is on screen), General (the language,
-- where prices come from).
-- ===========================================================================

local O = {}
ns.Options = O

local W           = 400
local TITLE_H     = 28
local TAB_H       = 24
local TOP         = TITLE_H + TAB_H - 2   -- title bar and tab strip share a border line each
local TAB_PAD     = 14
local PAD         = 14
local FIELD_X     = 130
local ROW         = 30
local SECTION_GAP = 14
local SCALE       = 1.3

local TABS = { "fishing", "hud", "general" }

local main
local selected = "fishing"

function ns.RefreshOptions()
	if main and main:IsShown() then O.Refresh() end
end

function ns.IsOptionsShown()
	return main ~= nil and main:IsShown()
end

-- ---------------------------------------------------------------------------
-- The key: shown as the game names it; a click listens for the next key
-- ---------------------------------------------------------------------------

local IGNORED = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }

local function Combo(key)
	local m = ""
	if IsAltKeyDown() then m = "ALT-" .. m end
	if IsControlKeyDown() then m = "CTRL-" .. m end
	if IsShiftKeyDown() then m = "SHIFT-" .. m end
	return m .. key
end

local function StopListening(b)
	if not b.listening then return end
	b.listening = false
	b:EnableKeyboard(false)
	b:EnableMouseWheel(false)
	b:SetPropagateKeyboardInput(true)
	b:SetScript("OnKeyDown", nil)
	b:SetScript("OnKeyUp", nil)
	b:SetScript("OnMouseWheel", nil)
	b.pending = nil
	O.Refresh()
end

local function StartListening(b)
	b.listening = true
	b:EnableKeyboard(true)
	b:EnableMouseWheel(true)
	b:SetPropagateKeyboardInput(false)
	-- Bound on release, not on the press: bound at once, the release of that
	-- same press would reach the game and fire the key it just became.
	b:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			StopListening(self)
		elseif not IGNORED[key] then
			self.pending = Combo(key)
		end
	end)
	b:SetScript("OnKeyUp", function(self, key)
		local pending = self.pending
		if pending and not IGNORED[key] then
			StopListening(self)
			ns.SetKey(pending)
		end
	end)
	b:SetScript("OnMouseWheel", function(self, delta)
		StopListening(self)
		ns.SetKey(Combo(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
	end)
	O.Refresh()
end

local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function OnKeyButtonClick(self, mouseButton)
	if not self.listening then
		if mouseButton == "LeftButton" then StartListening(self) end
	elseif MOUSE[mouseButton] then
		StopListening(self)
		ns.SetKey(Combo(MOUSE[mouseButton]))
	else
		StopListening(self)   -- a left or right click while listening: never mind
	end
end

-- ---------------------------------------------------------------------------
-- Pages. A page is a frame with a cursor going down it; these helpers put
-- one thing after another on it. Widgets that show a saved value are kept
-- on the window (f.checks, f.steppers) so Refresh can set them all.
-- ---------------------------------------------------------------------------

local function Percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local function Minutes(v) return string.format(L["%d min"], v) end

local function NewPage(f, key)
	local p = CreateFrame("Frame", nil, f)
	p:SetPoint("TOPLEFT", PAD, -TOP - PAD)
	p:SetPoint("TOPRIGHT", -PAD, -TOP - PAD)
	p:SetPoint("BOTTOMRIGHT", -PAD, PAD)   -- a frame without a height draws nothing, children included
	p.y = 0
	f.pages[key] = p

	function p.Section(key)
		if p.y < 0 then p.y = p.y - SECTION_GAP end
		local label = ns.Bind(Skin.Label(p, "", "GameFontNormal", "accent"), key)
		label:SetPoint("TOPLEFT", 0, p.y)
		local rule = Skin.Fill(p, "ARTWORK", "border", 0.6)
		rule:SetHeight(1)
		rule:SetPoint("TOPLEFT", 0, p.y - 17)
		rule:SetPoint("TOPRIGHT", 0, p.y - 17)
		p.y = p.y - 26
	end
	function p.Check(key, tipKey, get, set)
		local c = ns.Bind(Skin.Checkbox(p, "", function(checked) set(checked); ns.Changed() end), key)
		c:SetPoint("TOPLEFT", 0, p.y - 1)
		if tipKey then Skin.Tooltip(c, key, tipKey) end
		c.get = get
		f.checks[#f.checks + 1] = c
		p.y = p.y - 26
		return c
	end
	-- the dim label in front of a control; with a tip, it is hoverable and carries it
	function p.Field(key, tipKey)
		if not tipKey then return Skin.Field(p, key, 0, p.y) end
		local hover = CreateFrame("Frame", nil, p)
		hover:SetPoint("TOPLEFT", 0, p.y)
		hover:SetSize(FIELD_X - 4, 20)
		hover:EnableMouse(true)
		local text = ns.Bind(Skin.Label(hover, "", nil, "dim"), key)
		text:SetPoint("LEFT", 0, 0)
		Skin.Tooltip(hover, key, tipKey)
		return hover
	end
	function p.Step(key, tipKey, get, fmt, onStep)
		p.Field(key, tipKey)
		local st = Skin.Stepper(p, function(dir) onStep(dir); ns.Changed() end)
		st:SetPoint("TOPLEFT", FIELD_X, p.y)
		st.get, st.fmt = get, fmt
		f.steppers[#f.steppers + 1] = st
		p.y = p.y - ROW
		return st
	end
	-- a paragraph of dim text, as many lines as it takes
	function p.Note(key, height)
		local fs = ns.Bind(Skin.Label(p, "", nil, "dim"), key)
		fs:SetPoint("TOPLEFT", 0, p.y)
		fs:SetWidth(W - PAD * 2)
		fs:SetJustifyH("LEFT")
		p.y = p.y - height
		return fs
	end
	return p
end

local function BuildFishing(f)
	local p = NewPage(f, "fishing")
	local S = function() return ns.db.settings end

	f.enabled = p.Check("Fishing mode", "MODE_TIP", function() return S().enabled end, function(v) ns.SetEnabled(v) end)

	Skin.Field(p, "Key", 0, p.y)
	f.keyButton = Skin.Button(p, "", 150, 20, OnKeyButtonClick)
	f.keyButton:SetPoint("TOPLEFT", FIELD_X, p.y)
	f.keyButton:RegisterForClicks("AnyUp")
	Skin.Tooltip(f.keyButton, "Key", "KEY_TIP")
	f.clear = ns.Bind(Skin.Button(p, "", 60, 20, function() ns.SetKey(nil) end), "Clear")
	f.clear:SetPoint("LEFT", f.keyButton, "RIGHT", 6, 0)
	p.y = p.y - ROW + 4
	p.Note("KEY_HINT", 30)

	p.Section("Casting")
	f.autoEquip = p.Check("Equip a fishing pole from your bags", "EQUIP_TIP",
		function() return S().autoEquip end, function(v) S().autoEquip = v end)
	f.fastLoot = p.Check("Loot the catch at once", "LOOT_TIP",
		function() return S().fastLoot end, function(v) S().fastLoot = v end)
	f.chime = p.Check("Chime when the line lands", "CHIME_TIP",
		function() return S().chime end, function(v) S().chime = v end)

	p.Section("Sound while the line is out")
	f.duck = p.Check("Lower music and ambience", "DUCK_TIP",
		function() return S().duck end, function(v) S().duck = v end)
	f.music = p.Step("Music", nil, function() return S().musicVol end, Percent, function(dir)
		S().musicVol = math.max(0, math.min(1, S().musicVol + dir * 0.05))
		ns.ApplyAudioLevels()
	end)
	f.ambience = p.Step("Ambience", nil, function() return S().ambienceVol end, Percent, function(dir)
		S().ambienceVol = math.max(0, math.min(1, S().ambienceVol + dir * 0.05))
		ns.ApplyAudioLevels()
	end)
	f.boostSFX = p.Check("Louder sound effects", "SFX_TIP",
		function() return S().boostSFX end, function(v) S().boostSFX = v end)

	-- the lure: the known lures in the bags, as icons
	p.Section("Lure")
	p.Field("Lure", "LURE_TIP")
	f.lure = Skin.IconTray(p, function(id) S().lure = id; ns.Changed() end)
	f.lure:SetPoint("TOPLEFT", FIELD_X, p.y + 4)
	p.y = p.y - ROW - 6
	f.lureAuto = p.Check("Apply before casting", "LURE_AUTO_TIP",
		function() return S().lureAuto end, function(v) S().lureAuto = v end)

	-- the hat: the known fishing hats in the bags or on the head, as icons
	p.Section("Hat")
	p.Field("Fishing hat", "HAT_TIP")
	f.hat = Skin.IconTray(p, function(id) S().hat = id; ns.Changed() end)
	f.hat:SetPoint("TOPLEFT", FIELD_X, p.y + 4)
	p.y = p.y - ROW - 6
	return p
end

local function BuildHud(f)
	local p = NewPage(f, "hud")
	local S = function() return ns.db.settings end

	p.Section("On screen")
	f.showButton = p.Check("Show the cast button", "BUTTON_TIP",
		function() return S().showButton end, function(v) S().showButton = v end)
	f.minimap = p.Check("Show the minimap button", "MINIMAP_HINT",
		function() return S().minimap end, function(v) S().minimap = v end)

	p.Section("Session HUD")
	f.hudShow = p.Check("Show the HUD", "HUD_TIP",
		function() return ns.db.hud.show ~= "never" end, function(v) ns.db.hud.show = v and "always" or "never" end)
	f.hudCatches = p.Check("Show catches on the HUD", "CATCHES_TIP",
		function() return ns.db.hud.catches end, function(v) ns.db.hud.catches = v end)
	f.idle = p.Step("Hide after", "IDLE_TIP", function() return ns.db.hud.idle end, Minutes, function(dir)
		ns.db.hud.idle = math.max(ns.HUD.IDLE_MIN, math.min(ns.HUD.IDLE_MAX, ns.db.hud.idle + dir))
	end)
	f.hudScale = p.Step("Scale", nil, function() return ns.db.hud.scale end, Percent, function(dir)
		ns.HUD.SetScale(ns.db.hud.scale + dir * ns.HUD.SCALE_STEP)
	end)
	Skin.Field(p, "Position", 0, p.y)
	f.lock = ns.Bind(Skin.Checkbox(p, "", function(checked) ns.db.hud.locked = checked end), "Lock")
	f.lock:SetPoint("TOPLEFT", FIELD_X, p.y - 1)
	Skin.Tooltip(f.lock, "Lock", "LOCK_TIP")
	f.checks[#f.checks + 1] = f.lock
	f.lock.get = function() return ns.db.hud.locked end
	f.resetPositions = ns.Bind(Skin.Button(p, "", 100, 20, function()
		ns.HUD.ResetPosition()
		ns.Button.ResetPosition()
	end), "Reset positions")
	f.resetPositions:SetPoint("LEFT", f.lock, "RIGHT", 16, 0)
	p.y = p.y - ROW
	f.resetSession = ns.Bind(Skin.Button(p, "", 100, 20, function() ns.ResetSession() end), "Reset session")
	f.resetSession:SetPoint("TOPLEFT", FIELD_X, p.y)
	p.y = p.y - ROW
	return p
end

-- The auction addons the prices can come from, and whether they are there.
local PRICE_ADDONS = { "Auctionator", "TradeSkillMaster" }

local function BuildGeneral(f)
	local p = NewPage(f, "general")

	Skin.Field(p, "Language", 0, p.y)
	f.language = Skin.Dropdown(p, 180, function()
		local items = {}
		for _, entry in ipairs(ns.LANGUAGES) do
			items[#items + 1] = { label = entry.label or L[entry.key], value = entry.code }
		end
		return items
	end, function(_, item) ns.SetLanguage(item.value) end)
	f.language:SetPoint("TOPLEFT", FIELD_X, p.y)
	p.y = p.y - ROW

	p.Section("Prices")
	p.Note("PRICES_NOTE", 56)
	f.priceAddons = {}
	for _, name in ipairs(PRICE_ADDONS) do
		local label = Skin.Label(p, name)
		label:SetPoint("TOPLEFT", 0, p.y - 4)
		local state = Skin.Label(p, "")
		state:SetPoint("TOPLEFT", FIELD_X, p.y - 4)
		f.priceAddons[name] = state
		p.y = p.y - 22
	end
	return p
end

-- ---------------------------------------------------------------------------
-- Tabs
-- ---------------------------------------------------------------------------

local function TabLabel(key)
	if key == "fishing" then return L["Fishing"] end
	if key == "hud" then return "HUD" end
	return L["General"]
end

local function CreateTab(parent, key)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(TAB_H - 2)   -- between the strip's two border lines
	b.key = key
	b.sel = Skin.Fill(b, "BACKGROUND", "selected")
	b.sel:SetAllPoints()
	b.bar = Skin.Fill(b, "BORDER", "accent")
	b.bar:SetPoint("TOPLEFT")
	b.bar:SetPoint("TOPRIGHT")
	b.bar:SetHeight(2)
	b.hover = Skin.Fill(b, "BACKGROUND", "hover", 0.5)
	b.hover:SetAllPoints()
	b.hover:Hide()
	b.text = Skin.Label(b, "", "GameFontHighlight")
	b.text:SetPoint("CENTER")
	b:SetScript("OnEnter", function(self) self.hover:Show() end)
	b:SetScript("OnLeave", function(self) self.hover:Hide() end)
	b:SetScript("OnClick", function(self) O.Select(self.key) end)
	return b
end

function O.Select(key)
	selected = key
	O.Refresh()
end

local function RefreshTabs()
	local x = 1
	for _, key in ipairs(TABS) do
		local b = main.tabs[key]
		b.text:SetText(TabLabel(key))
		b.sel:SetShown(selected == key)
		b.bar:SetShown(selected == key)
		b:SetWidth(b.text:GetStringWidth() + TAB_PAD * 2)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", x, -1)
		x = x + b:GetWidth()
	end
	for key, page in pairs(main.pages) do page:SetShown(key == selected) end
	main:SetHeight(TOP + PAD - main.pages[selected].y + PAD)
end

function O.Refresh()
	if not main then return end
	Skin.HideOptionList()
	RefreshTabs()
	for _, c in ipairs(main.checks) do c:SetChecked(c.get()) end
	for _, st in ipairs(main.steppers) do st.value:SetText(st.fmt(st.get())) end
	local b = main.keyButton
	if b.listening then
		b.label:SetTextColor(Skin.Color("accent"))
		b:SetLabel(L["Press a key..."])
	else
		local key = ns.GetKey()
		b.label:SetTextColor(Skin.Color(key and "text" or "dim"))
		b:SetLabel(key and GetBindingText(key) or L["Not bound"])
	end
	main.lure:SetItems(ns.LureCandidates(), ns.db.settings.lure)
	main.hat:SetItems(ns.HatCandidates(), ns.db.settings.hat)
	local code = ns.db.settings.locale
	for _, entry in ipairs(ns.LANGUAGES) do
		if entry.code == code then main.language:SetValueText(entry.label or L[entry.key]) end
	end
	for name, state in pairs(main.priceAddons) do
		local there = C_AddOns.IsAddOnLoaded(name)
		state:SetText(Skin.Text(there and "ok" or "dim", L[there and "STATE_installed" or "STATE_missing"]))
	end
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------

local function CreateMain()
	local f = CreateFrame("Frame", "OneClickFishFrame", UIParent, "BackdropTemplate")
	f:SetWidth(W)
	f:SetScale(SCALE)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	Skin.Backdrop(f, "bg", 1)   -- opaque: the game must not bleed through
	tinsert(UISpecialFrames, "OneClickFishFrame")   -- Esc closes it

	local bar = Skin.Panel(f, "panel")
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(TITLE_H)
	local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""
	f.title = Skin.Label(bar, Skin.Text("accent", "OneClick") .. "Fish " .. Skin.Text("dim", "v" .. version), "GameFontHighlight")
	f.title:SetPoint("LEFT", 10, 0)
	f.close = Skin.CloseButton(bar, function() f:Hide() end)
	f.close:SetPoint("RIGHT", -4, 0)

	local tabBar = Skin.Panel(f, "bg")
	tabBar:SetPoint("TOPLEFT", 0, -TITLE_H + 1)
	tabBar:SetPoint("TOPRIGHT", 0, -TITLE_H + 1)
	tabBar:SetHeight(TAB_H)
	f.tabs = {}
	for _, key in ipairs(TABS) do f.tabs[key] = CreateTab(tabBar, key) end

	f.pages, f.checks, f.steppers = {}, {}, {}
	BuildFishing(f)
	BuildHud(f)
	BuildGeneral(f)

	f:SetScript("OnShow", function()
		O.Refresh()
		ns.HUD.Refresh()   -- on screen while the window is open, so it can be placed
	end)
	f:SetScript("OnHide", function()
		Skin.HideOptionList()
		StopListening(f.keyButton)
		ns.HUD.Refresh()
	end)
	f:Hide()
	main = f
	return f
end

function O.Open()
	if not main then CreateMain() end
	main:Show()
end

function O.Toggle()
	if main and main:IsShown() then main:Hide() else O.Open() end
end
ns.ToggleOptions = O.Toggle

-- for the tests
function O.GetFrame() return main end
function O.GetSelection() return selected end

-- An entry in the game's own Options > AddOns list: a button that opens the window.
function O.RegisterInGame()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	local title = Skin.Label(panel, "|cff66ccffOneClick|rFish", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	local hint = ns.Bind(Skin.Label(panel, "", nil, "dim"), "Slash hint")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	local open = ns.Bind(Skin.Button(panel, "", 150, 24, function()
		-- the game's panel would cover ours; closing it is not allowed in combat
		if SettingsPanel and not InCombatLockdown() then HideUIPanel(SettingsPanel) end
		O.Open()
	end), "Open settings")
	open:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "OneClickFish")
	Settings.RegisterAddOnCategory(category)
	O.gamePanel = panel   -- for the tests
end
