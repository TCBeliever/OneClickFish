local ADDON, ns = ...
local L, Skin = ns.L, ns.Skin

-- ===========================================================================
-- The settings window, laid out like SmartVoidcore's: a title bar, a tab
-- strip, the pages of the tab on the left, the page on the right with its
-- title and a line of explanation. Three tabs: Fishing (the mode and the key,
-- casting, sound, lure and hat), HUD (the cast button, the session HUD),
-- General (appearance, prices).
-- ===========================================================================

local O = {}
ns.Options = O

local W, H      = 600, 440
local TITLE_H   = 28
local TAB_H     = 24
local TOP       = TITLE_H + TAB_H - 2   -- title bar and tab strip share a border line each
local TAB_PAD   = 14
local LEFT_W    = 140
local RIGHT_X   = LEFT_W + 14
local RIGHT_W   = W - RIGHT_X - 14
local TREE_ROW  = 22
local DESC_GAP  = 18
local FIELD_X   = 120
local EDIT_W    = 50   -- a box for a number
local SCALE_MIN, SCALE_MAX = 0.8, 2.0

-- The tabs and their pages, in order; label and desc are locale keys.
local TABS = {
	{ key = "fishing", label = "Fishing", nodes = {
		{ key = "mode",    label = "Fishing mode", desc = "MODE_DESC" },
		{ key = "casting", label = "Casting",      desc = "CASTING_DESC" },
		{ key = "sound",   label = "Sound",        desc = "SOUND_DESC" },
		{ key = "gear",    label = "Lure and hat", desc = "GEAR_DESC" },
	} },
	{ key = "hud", label = "HUD", nodes = {
		{ key = "button",  label = "Cast button",  desc = "BUTTON_DESC" },
		{ key = "session", label = "Session HUD",  desc = "HUD_DESC" },
	} },
	{ key = "general", label = "General", nodes = {
		{ key = "look",    label = "Appearance",   desc = "LOOK_DESC" },
		{ key = "prices",  label = "Prices",       desc = "PRICES_DESC" },
	} },
}

local main
local selected = { tab = TABS[1].key, node = TABS[1].nodes[1].key }

local function TabOf(key)
	for _, tab in ipairs(TABS) do
		if tab.key == key then return tab end
	end
end

local function NodeOf(tab, key)
	for _, node in ipairs(tab.nodes) do
		if node.key == key then return node end
	end
end

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
-- Pages. A page is a column of items, each hung under the one before it, so
-- a line that wraps pushes the rest down. Layout places them again on every
-- refresh: a language switch moves where a toggle's label starts. Widgets
-- that show a saved value are kept on the window (f.checks, f.sliders) so
-- Refresh can set them all.
-- ---------------------------------------------------------------------------

local function Percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

local function Layout(page)
	local prev, prevX
	for _, item in ipairs(page.items) do
		local x = type(item.x) == "function" and item.x() or item.x
		item.frame:ClearAllPoints()
		if prev then
			item.frame:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", x - prevX, -item.gap)
		else
			item.frame:SetPoint("TOPLEFT", x, 0)
		end
		if item.fill then item.frame:SetWidth(RIGHT_W - x) end
		prev, prevX = item.frame, x
	end
end

local function NewPage(f, key)
	local p = CreateFrame("Frame", nil, f.detail)
	p.items = {}
	f.pages[key] = p

	-- fill: the item takes the rest of the line (a paragraph that wraps)
	local function Add(frame, x, gap, fill)
		p.items[#p.items + 1] = { frame = frame, x = x, gap = gap, fill = fill }
		return frame
	end
	p.Add = Add

	-- A toggle with its line under it, lined up with the toggle's label. The
	-- line says what Off does.
	function p.Toggle(key, descKey, get, set)
		local c = ns.Bind(Skin.Toggle(p, "", function(checked) set(checked); ns.Changed() end), key)
		Add(c, 0, 12)
		c.get = get
		f.checks[#f.checks + 1] = c
		c.desc = ns.Bind(Skin.Label(p, "", nil, "dim"), descKey)
		c.desc:SetJustifyH("LEFT")
		Add(c.desc, Skin.ToggleLabelX, 3, true)
		return c
	end
	-- a dim label, with the control the caller puts on the returned row at
	-- the control column
	function p.Row(key, h)
		local row = CreateFrame("Frame", nil, p)
		row:SetSize(RIGHT_W, h or 20)
		Skin.Field(row, key, 0, -((h or 20) - 20) / 2)
		return Add(row, 0, 12)
	end
	-- the title with the value at its right, the bar under them
	function p.Slider(key, min, max, step, get, onChange)
		local s = ns.Bind(Skin.Slider(p, RIGHT_W - 20, min, max, step, Percent,
			function(v) onChange(v); ns.Changed() end), key)
		Add(s, 0, 12)
		s.get = get
		f.sliders[#f.sliders + 1] = s
		return s
	end
	-- a paragraph of dim text, as many lines as it takes
	function p.Note(key)
		local fs = ns.Bind(Skin.Label(p, "", nil, "dim"), key)
		fs:SetJustifyH("LEFT")
		return Add(fs, 0, 8, true)
	end
	return p
end

local function BuildMode(f)
	local p = NewPage(f, "mode")
	local S = function() return ns.db.settings end
	f.enabled = p.Toggle("Fishing mode", "MODE_OFF", function() return S().enabled end, function(v) ns.SetEnabled(v) end)

	local row = p.Row("Key")
	f.keyButton = Skin.Button(row, "", 150, 20, OnKeyButtonClick)
	f.keyButton:SetPoint("TOPLEFT", FIELD_X, 0)
	f.keyButton:RegisterForClicks("AnyUp")
	Skin.Tooltip(f.keyButton, "Key", "KEY_TIP")
	f.clear = ns.Bind(Skin.Button(row, "", 60, 20, function() ns.SetKey(nil) end), "Clear")
	f.clear:SetPoint("LEFT", f.keyButton, "RIGHT", 6, 0)
	p.Note("KEY_HINT")
end

local function BuildCasting(f)
	local p = NewPage(f, "casting")
	local S = function() return ns.db.settings end
	f.autoEquip = p.Toggle("Equip a fishing pole from your bags", "EQUIP_OFF",
		function() return S().autoEquip end, function(v) S().autoEquip = v end)
	f.fastLoot = p.Toggle("Loot the catch at once", "LOOT_OFF",
		function() return S().fastLoot end, function(v) S().fastLoot = v end)
	f.chime = p.Toggle("Chime when the line lands", "CHIME_OFF",
		function() return S().chime end, function(v) S().chime = v end)
end

local function BuildSound(f)
	local p = NewPage(f, "sound")
	local S = function() return ns.db.settings end
	f.duck = p.Toggle("Lower music and ambience", "DUCK_OFF",
		function() return S().duck end, function(v) S().duck = v end)
	f.music = p.Slider("Music", 0, 1, 0.05, function() return S().musicVol end, function(v)
		S().musicVol = v
		ns.ApplyAudioLevels()
	end)
	f.ambience = p.Slider("Ambience", 0, 1, 0.05, function() return S().ambienceVol end, function(v)
		S().ambienceVol = v
		ns.ApplyAudioLevels()
	end)
	f.boostSFX = p.Toggle("Louder sound effects", "SFX_OFF",
		function() return S().boostSFX end, function(v) S().boostSFX = v end)
	f.bgSound = p.Toggle("Keep sound in the background", "BG_OFF",
		function() return S().bgSound end, function(v) S().bgSound = v end)
end

-- the lure and the hat: the known ones in the bags (the hat also on the head), as icons
local function BuildGear(f)
	local p = NewPage(f, "gear")
	local S = function() return ns.db.settings end
	local row = p.Row("Lure", 28)
	f.lure = Skin.IconTray(row, function(id) S().lure = id; ns.Changed() end)
	f.lure:SetPoint("TOPLEFT", FIELD_X, 0)
	f.lureAuto = p.Toggle("Apply before casting", "LURE_AUTO_OFF",
		function() return S().lureAuto end, function(v) S().lureAuto = v end)
	row = p.Row("Fishing hat", 28)
	f.hat = Skin.IconTray(row, function(id) S().hat = id; ns.Changed() end)
	f.hat:SetPoint("TOPLEFT", FIELD_X, 0)
end

local function BuildButton(f)
	local p = NewPage(f, "button")
	local S = function() return ns.db.settings end
	f.showButton = p.Toggle("Show the cast button", "BUTTON_OFF",
		function() return S().showButton end, function(v) S().showButton = v end)
	f.buttonScale = p.Slider("Button size", ns.Button.SCALE_MIN, ns.Button.SCALE_MAX, ns.Button.SCALE_STEP,
		function() return ns.db.button.scale end, function(v) ns.Button.SetScale(v) end)
	f.minimap = p.Toggle("Show the minimap button", "MINIMAP_OFF",
		function() return S().minimap end, function(v) S().minimap = v end)
end

local function BuildSession(f)
	local p = NewPage(f, "session")
	local hud = function() return ns.db.hud end
	f.hudShow = p.Toggle("Show the HUD", "HUD_OFF",
		function() return hud().show ~= "never" end, function(v) hud().show = v and "always" or "never" end)
	f.hudCatches = p.Toggle("Show catches on the HUD", "CATCHES_OFF",
		function() return hud().catches end, function(v) hud().catches = v end)

	-- minutes, typed in
	local row = p.Row("Hide after")
	f.idle = Skin.EditBox(row, EDIT_W, function(text)
		local v = tonumber(text)
		if v then hud().idle = math.max(ns.HUD.IDLE_MIN, math.min(ns.HUD.IDLE_MAX, math.floor(v))) end
		ns.Changed()
	end)
	f.idle:SetNumeric(true)
	f.idle:SetMaxLetters(2)
	f.idle:SetJustifyH("CENTER")
	f.idle:SetPoint("TOPLEFT", FIELD_X, 0)
	Skin.Tooltip(f.idle, "Hide after", "IDLE_TIP")
	local unit = ns.Bind(Skin.Label(row, "", nil, "dim"), "minutes")
	unit:SetPoint("LEFT", f.idle, "RIGHT", 6, 0)

	f.hudScale = p.Slider("HUD size", ns.HUD.SCALE_MIN, ns.HUD.SCALE_MAX, ns.HUD.SCALE_STEP,
		function() return hud().scale end, function(v) ns.HUD.SetScale(v) end)
	f.lock = p.Toggle("Lock the HUD and the cast button", "LOCK_OFF",
		function() return hud().locked end, function(v) hud().locked = v end)

	local buttons = CreateFrame("Frame", nil, p)
	buttons:SetSize(RIGHT_W, 22)
	p.Add(buttons, 0, 14)
	f.resetPositions = ns.Bind(Skin.Button(buttons, "", 100, 22, function()
		ns.HUD.ResetPosition()
		ns.Button.ResetPosition()
	end), "Reset positions")
	f.resetPositions:SetPoint("TOPLEFT")
	f.resetSession = ns.Bind(Skin.Button(buttons, "", 100, 22, function() ns.ResetSession() end), "Reset session")
	f.resetSession:SetPoint("LEFT", f.resetPositions, "RIGHT", 8, 0)
end

local function ThemeItems()
	local items = {}
	for _, theme in ipairs(Skin.THEMES) do
		items[#items + 1] = { label = L["THEME_" .. theme.key], value = theme.key, swatch = theme.colors.accent }
	end
	return items
end

local function BuildLook(f)
	local p = NewPage(f, "look")
	local row = p.Row("Language")
	f.language = Skin.Dropdown(row, 200, function()
		local items = {}
		for _, entry in ipairs(ns.LANGUAGES) do
			items[#items + 1] = { label = entry.label or L[entry.key], value = entry.code }
		end
		return items
	end, function(_, item) ns.SetLanguage(item.value) end)
	f.language:SetPoint("TOPLEFT", FIELD_X, 0)

	row = p.Row("Theme")
	f.theme = Skin.Dropdown(row, 200, ThemeItems, function(_, item) ns.SetTheme(item.value) end)
	f.theme:SetPoint("TOPLEFT", FIELD_X, 0)

	f.windowScale = p.Slider("Window scale", SCALE_MIN, SCALE_MAX, 0.1,
		function() return ns.db.settings.windowScale end, function(v) O.SetWindowScale(v) end)
end

-- The auction addons the prices can come from, and whether they are there.
local PRICE_ADDONS = { "Auctionator", "TradeSkillMaster" }

local function BuildPrices(f)
	local p = NewPage(f, "prices")
	f.priceAddons = {}
	for _, name in ipairs(PRICE_ADDONS) do
		local row = CreateFrame("Frame", nil, p)
		row:SetSize(RIGHT_W, 20)
		p.Add(row, 0, 4)
		Skin.Label(row, name):SetPoint("TOPLEFT", 0, -4)
		local state = Skin.Label(row, "")
		state:SetPoint("TOPLEFT", FIELD_X, -4)
		f.priceAddons[name] = state
	end
end

-- ---------------------------------------------------------------------------
-- Top: the tabs. Left: the pages of the selected tab. Right: the page.
-- ---------------------------------------------------------------------------

local function CreateTab(parent, tab)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(TAB_H - 2)   -- between the strip's two border lines
	b.key = tab.key
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

local function CreateTreeRow(parent)
	local b = Skin.Row(parent)
	b:SetHeight(TREE_ROW)
	b.text = Skin.Label(b, "", "GameFontHighlight")
	b.text:SetPoint("LEFT", 10, 0)
	b.text:SetPoint("RIGHT", -4, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	b:SetScript("OnClick", function(self) O.Select(self.tab, self.node) end)
	return b
end

function O.Select(tabKey, nodeKey)
	local tab = TabOf(tabKey)
	if not tab then return end
	if not NodeOf(tab, nodeKey) then nodeKey = tab.nodes[1].key end
	selected = { tab = tabKey, node = nodeKey }
	O.Refresh()
end

function O.GetSelection() return selected.tab, selected.node end

local function RefreshTabs()
	local x = 1
	for _, tab in ipairs(TABS) do
		local b = main.tabs[tab.key]
		b.text:SetText(L[tab.label])
		b.sel:SetShown(selected.tab == tab.key)
		b.bar:SetShown(selected.tab == tab.key)
		b:SetWidth(b.text:GetStringWidth() + TAB_PAD * 2)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", x, -1)
		x = x + b:GetWidth()
	end
end

local function RefreshTree()
	local tab = TabOf(selected.tab)
	local y = -6
	for i, node in ipairs(tab.nodes) do
		local b = main.treeRows[i]
		if not b then
			b = CreateTreeRow(main.tree)
			main.treeRows[i] = b
		end
		b.tab, b.node = tab.key, node.key
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 1, y)
		b:SetPoint("TOPRIGHT", -1, y)
		b.text:SetText(L[node.label])
		b:SetSelected(selected.node == node.key)
		b:Show()
		y = y - TREE_ROW
	end
	for i = #tab.nodes + 1, #main.treeRows do main.treeRows[i]:Hide() end
end

local function RefreshDetail()
	local node = NodeOf(TabOf(selected.tab), selected.node)
	local d = main.detail
	d.title:SetText(L[node.label])
	d.desc:SetText(L[node.desc])
	for key, page in pairs(main.pages) do
		page:SetShown(key == node.key)
		Layout(page)
	end
end

function O.Refresh()
	if not main then return end
	Skin.HideOptionList()
	RefreshTabs()
	RefreshTree()
	RefreshDetail()
	for _, c in ipairs(main.checks) do c:SetChecked(c.get()) end
	for _, s in ipairs(main.sliders) do s:SetValue(s.get()) end
	if not main.idle:HasFocus() then main.idle:SetText(tostring(ns.db.hud.idle)) end
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
	main.theme:SetValueText(L["THEME_" .. Skin.theme])
	for name, state in pairs(main.priceAddons) do
		local there = C_AddOns.IsAddOnLoaded(name)
		state:SetText(Skin.Text(there and "ok" or "dim", L[there and "STATE_installed" or "STATE_missing"]))
	end
end

function O.SetWindowScale(scale)
	scale = math.max(SCALE_MIN, math.min(SCALE_MAX, scale))
	scale = math.floor(scale * 10 + 0.5) / 10
	ns.db.settings.windowScale = scale
	if main then main:SetScale(scale) end
	ns.RefreshOptions()
end

local function TitleText()
	local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""
	return Skin.Text("accent", "OneClick") .. "Fish " .. Skin.Text("dim", "v" .. version)
end

-- key: one of Skin.THEMES; anything else reads as the first
function ns.SetTheme(key)
	Skin.SetTheme(key)
	ns.db.settings.theme = Skin.theme
	if main then main.title:SetText(TitleText()) end
	ns.Changed()   -- the inline colours: the HUD, the cast button, this window
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------

local function CreateMain()
	local f = CreateFrame("Frame", "OneClickFishFrame", UIParent, "BackdropTemplate")
	f:SetSize(W, H)
	f:SetScale(ns.db.settings.windowScale)
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
	f.title = Skin.Label(bar, TitleText(), "GameFontHighlight")
	f.title:SetPoint("LEFT", 10, 0)
	f.close = Skin.CloseButton(bar, function() f:Hide() end)
	f.close:SetPoint("RIGHT", -4, 0)

	local tabBar = Skin.Panel(f, "bg")
	tabBar:SetPoint("TOPLEFT", 0, -TITLE_H + 1)
	tabBar:SetPoint("TOPRIGHT", 0, -TITLE_H + 1)
	tabBar:SetHeight(TAB_H)
	f.tabs = {}
	for _, tab in ipairs(TABS) do f.tabs[tab.key] = CreateTab(tabBar, tab) end

	local tree = Skin.Panel(f, "panel")
	tree:SetPoint("TOPLEFT", 0, -TOP)
	tree:SetPoint("BOTTOMLEFT")
	tree:SetWidth(LEFT_W)
	f.tree = tree
	f.treeRows = {}

	local d = CreateFrame("Frame", nil, f)
	d:SetPoint("TOPLEFT", RIGHT_X, -TOP - 12)
	d:SetSize(RIGHT_W, H - TOP - 24)
	f.detail = d
	d.title = Skin.Label(d, "", "GameFontHighlightLarge")
	d.title:SetPoint("TOPLEFT", 0, 0)
	d.desc = Skin.Label(d, "", nil, "dim")
	d.desc:SetPoint("TOPLEFT", 0, -22)
	d.desc:SetWidth(RIGHT_W)
	d.desc:SetJustifyH("LEFT")

	f.pages, f.checks, f.sliders = {}, {}, {}
	BuildMode(f)
	BuildCasting(f)
	BuildSound(f)
	BuildGear(f)
	BuildButton(f)
	BuildSession(f)
	BuildLook(f)
	BuildPrices(f)
	for _, page in pairs(f.pages) do
		-- under the page's line of explanation, however many lines it takes
		page:SetPoint("TOPLEFT", d.desc, "BOTTOMLEFT", 0, -DESC_GAP)
		page:SetPoint("BOTTOMRIGHT")   -- a frame without a height draws nothing, children included
	end

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

function O.GetFrame() return main end   -- for the tests

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
