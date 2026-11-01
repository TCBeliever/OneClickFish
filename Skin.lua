local ADDON, ns = ...

-- ===========================================================================
-- Look: flat panels, 1px borders, one palette at a time. No Blizzard frame
-- templates and no texture or font files; everything is drawn with the white
-- 8x8 texture. Fonts stay the game's own so every locale keeps its glyphs.
-- The same skin as CombatKit and SmartVoidcore, so they read as one family.
-- ===========================================================================

local Skin = {}
ns.Skin = Skin

local WHITE = "Interface\\Buttons\\WHITE8x8"

-- The themes to pick from, in the order the settings list them; the first is
-- the default. ok, warn and bad mean the same in every theme, so an accent
-- keeps clear of green and red. The black-gold accent sits close to amber.
Skin.THEMES = {
	{ key = "tide", colors = {
		bg       = { 0.025, 0.040, 0.055 },
		panel    = { 0.040, 0.100, 0.130 },
		element  = { 0.060, 0.180, 0.230 },
		hover    = { 0.080, 0.240, 0.300 },
		selected = { 0.070, 0.230, 0.290 },
		border   = { 0.160, 0.450, 0.560 },
		accent   = { 0.300, 0.720, 0.880 },
		text     = { 1.00, 1.00, 1.00 },
		dim      = { 0.62, 0.71, 0.76 },
		ok       = { 0.34, 0.88, 0.48 },
		warn     = { 0.91, 0.66, 0.25 },
		bad      = { 0.95, 0.35, 0.35 },
	} },
	{ key = "obsidian", colors = {
		bg       = { 0.027, 0.031, 0.039 },
		panel    = { 0.059, 0.067, 0.082 },
		element  = { 0.102, 0.114, 0.137 },
		hover    = { 0.137, 0.153, 0.184 },
		selected = { 0.129, 0.141, 0.169 },
		border   = { 0.431, 0.353, 0.180 },
		accent   = { 0.831, 0.686, 0.216 },
		text     = { 1.00, 1.00, 1.00 },
		dim      = { 0.663, 0.678, 0.710 },
		ok       = { 0.34, 0.88, 0.48 },
		warn     = { 0.91, 0.66, 0.25 },
		bad      = { 0.95, 0.35, 0.35 },
	} },
}

-- The palette in force, filled by Skin.SetTheme. The table stays the same, so
-- a reference taken once keeps reading the current theme.
local C = {}
Skin.colors = C

function Skin.Color(name)
	local c = C[name]
	return c[1], c[2], c[3]
end

-- "|cffrrggbb" for inline colouring
function Skin.Hex(name)
	local c = C[name]
	return string.format("|cff%02x%02x%02x",
		math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

function Skin.Text(name, text)
	return Skin.Hex(name) .. text .. "|r"
end

-- ---------------------------------------------------------------------------
-- Painting. Every widget coloured from the palette says how, so a theme switch
-- can paint it again. Inline Skin.Text colours are rebuilt by the refresh
-- that follows a switch.
-- ---------------------------------------------------------------------------

local painted = setmetatable({}, { __mode = "k" })   -- widget -> how it is coloured

function Skin.Paint(widget, apply)
	painted[widget] = apply
	apply(widget)
	return widget
end

-- key: one of Skin.THEMES; anything else reads as the first.
function Skin.SetTheme(key)
	local theme = Skin.THEMES[1]
	for _, t in ipairs(Skin.THEMES) do
		if t.key == key then theme = t end
	end
	Skin.theme = theme.key
	for name, c in pairs(theme.colors) do C[name] = { c[1], c[2], c[3] } end
	for widget, apply in pairs(painted) do apply(widget) end
end

-- frame must have been created with "BackdropTemplate"
function Skin.Backdrop(frame, bg, alpha, border)
	frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	Skin.Paint(frame, function(f)
		local r, g, b = Skin.Color(bg or "bg")
		f:SetBackdropColor(r, g, b, alpha or 1)
		f:SetBackdropBorderColor(Skin.Color(border or "border"))
	end)
end

function Skin.Panel(parent, bg, alpha, border)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	Skin.Backdrop(f, bg, alpha, border)
	return f
end

-- A solid colour texture
function Skin.Fill(parent, layer, name, alpha)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	return Skin.Paint(t, function(tex)
		local r, g, b = Skin.Color(name)
		tex:SetColorTexture(r, g, b, alpha or 1)
	end)
end

function Skin.Label(parent, text, template, colour)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	Skin.Paint(fs, function(f) f:SetTextColor(Skin.Color(colour or "text")) end)
	fs:SetText(text or "")
	return fs
end

-- ---------------------------------------------------------------------------
-- Widgets: button, close button, toggle, text box, row, icon tray, slider,
-- dropdown
-- ---------------------------------------------------------------------------

-- At rest: plain, or picked out when the widget is the chosen one of a group.
local function Rest(self)
	self:SetBackdropColor(Skin.Color(self.selected and "selected" or "element"))
	self:SetBackdropBorderColor(Skin.Color(self.selected and "accent" or "border"))
end

local function Hoverable(widget)
	widget:HookScript("OnEnter", function(self)
		if self.disabled then return end
		self:SetBackdropColor(Skin.Color("hover"))
		self:SetBackdropBorderColor(Skin.Color("accent"))
	end)
	widget:HookScript("OnLeave", Rest)
end
Skin.Hoverable = Hoverable

-- w is a minimum: a label longer than that (other language) widens the button.
function Skin.Button(parent, text, w, h, onClick)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(w, h or 20)
	Skin.Backdrop(b, "element")
	Skin.Paint(b, Rest)   -- a lit button stays lit through a theme switch
	local fs = Skin.Label(b, "")
	fs:SetPoint("CENTER")
	b:SetFontString(fs)
	b.label = fs
	function b:SetLabel(label)
		self:SetText(label or "")
		self:SetWidth(math.max(w, fs:GetStringWidth() + 18))
	end
	b:SetLabel(text)
	function b:SetSelected(on)
		self.selected = on and true or false
		Rest(self)
	end
	function b:SetDisabled(disabled)
		self.disabled = disabled and true or false
		self:SetAlpha(self.disabled and 0.55 or 1)
	end
	Hoverable(b)
	b:SetScript("OnClick", function(self, ...)
		if not self.disabled then onClick(self, ...) end
	end)
	return b
end

-- Two thin rotated bars: an X or a chevron, without a texture file.
local function Bars(parent, length, colour, a1, x1, a2, x2)
	local out = {}
	for i, spec in ipairs({ { a1, x1 }, { a2, x2 } }) do
		local t = Skin.Fill(parent, "ARTWORK", colour)
		t:SetSize(length, 1.5)
		t:SetPoint("CENTER", spec[2], 0)
		t:SetRotation(spec[1])
		out[i] = t
	end
	return out
end

function Skin.CloseButton(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(20, 20)
	b.bars = Bars(b, 12, "dim", math.pi / 4, 0, -math.pi / 4, 0)
	local function Tint(name)
		for _, t in ipairs(b.bars) do t:SetColorTexture(Skin.Color(name)) end
	end
	b:SetScript("OnEnter", function() Tint("text") end)
	b:SetScript("OnLeave", function() Tint("dim") end)
	b:SetScript("OnClick", onClick)
	return b
end

-- A "v" for dropdowns, anchored by the caller
function Skin.Chevron(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(10, 8)
	holder.bars = Bars(holder, 6, "dim", -math.pi / 4, -2, math.pi / 4, 2)
	return holder
end

-- A switch: off is the knob at the left on a plain track, on is the knob at
-- the right on an accent track, with 關 left of the track and 開 right of it;
-- the side in force lights up. A Button, so the label is clickable too.
-- onChange(checked). The colours are set in SetChecked, so a theme switch
-- repaints it by setting its own state again.
local TOGGLE_W, TOGGLE_H = 30, 16
local SWITCH_GAP = 4   -- between 關 / 開 and the track

-- the 關 and 開 slots share one width, measured in the current language and
-- again when the language changes
local switchW, switchFor, measure
local function SwitchW()
	local texts = ns.L["Off"] .. "/" .. ns.L["On"]
	if switchFor ~= texts then
		measure = measure or UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		measure:Hide()
		measure:SetText(ns.L["Off"])
		local a = measure:GetStringWidth()
		measure:SetText(ns.L["On"])
		switchW = math.ceil(math.max(a, measure:GetStringWidth()))
		switchFor = texts
	end
	return switchW
end

-- Where a toggle's label starts, from the toggle's left edge. A line under a
-- toggle lines up here.
function Skin.ToggleLabelX()
	return SwitchW() + SWITCH_GAP + TOGGLE_W + SWITCH_GAP + SwitchW() + 8
end

function Skin.Toggle(parent, text, onChange)
	local c = CreateFrame("Button", nil, parent)
	c:SetHeight(18)
	c.off = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	c.off:SetPoint("LEFT")
	c.box = c:CreateTexture(nil, "BACKGROUND")
	c.box:SetSize(TOGGLE_W, TOGGLE_H)
	c.box:SetPoint("LEFT", c.off, "RIGHT", SWITCH_GAP, 0)
	c.on = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	c.on:SetPoint("LEFT", c.box, "RIGHT", SWITCH_GAP, 0)
	c.fill = c:CreateTexture(nil, "BORDER")
	c.fill:SetSize(TOGGLE_W - 2, TOGGLE_H - 2)
	c.fill:SetPoint("CENTER", c.box)
	c.knob = c:CreateTexture(nil, "ARTWORK")
	c.knob:SetSize(TOGGLE_H - 6, TOGGLE_H - 6)
	c.label = Skin.Label(c, "")
	c.label:SetPoint("LEFT", c.on, "RIGHT", 8, 0)

	-- the click area follows the label, whatever the language; 關 and 開 are
	-- set here too, so a language switch (which sets the label again) reaches them
	function c:SetLabel(label)
		self.off:SetText(ns.L["Off"])
		self.off:SetWidth(SwitchW())
		self.on:SetText(ns.L["On"])
		self.on:SetWidth(SwitchW())
		self.label:SetText(label or "")
		self:SetWidth(Skin.ToggleLabelX() + self.label:GetStringWidth())
	end
	c:SetLabel(text)

	function c:SetChecked(v)
		self.checked = v and true or false
		self.knob:ClearAllPoints()
		if self.checked then
			self.knob:SetPoint("RIGHT", self.box, "RIGHT", -3, 0)
			self.knob:SetColorTexture(Skin.Color("text"))
			self.fill:SetColorTexture(Skin.Color("accent"))
		else
			self.knob:SetPoint("LEFT", self.box, "LEFT", 3, 0)
			self.knob:SetColorTexture(Skin.Color("dim"))
			self.fill:SetColorTexture(Skin.Color("element"))
		end
		self.off:SetTextColor(Skin.Color(self.checked and "dim" or "text"))
		self.on:SetTextColor(Skin.Color(self.checked and "accent" or "dim"))
		self.box:SetColorTexture(Skin.Color(self.hovered and "accent" or "border"))
	end
	function c:GetChecked() return self.checked or false end
	Skin.Paint(c, function(self) self:SetChecked(self.checked) end)

	c:SetScript("OnEnter", function(self) self.hovered = true; self.box:SetColorTexture(Skin.Color("accent")) end)
	c:SetScript("OnLeave", function(self) self.hovered = nil; self.box:SetColorTexture(Skin.Color("border")) end)
	c:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked)
		onChange(self.checked)
	end)
	return c
end

-- A one-line text box. onCommit(text) when the player is done with it
-- (Enter, or the focus leaves).
function Skin.EditBox(parent, w, onCommit)
	local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	e:SetSize(w, 20)
	Skin.Backdrop(e, "element")
	e:SetFontObject("GameFontHighlightSmall")
	e:SetTextInsets(6, 6, 0, 0)
	e:SetAutoFocus(false)
	e:SetMaxLetters(60)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(Skin.Color("accent")) end)
	e:SetScript("OnEditFocusLost", function(self)
		self:SetBackdropBorderColor(Skin.Color("border"))
		onCommit(strtrim(self:GetText() or ""))
	end)
	return e
end

-- A selectable row in a list: a highlight when hovered, picked out when selected.
function Skin.Row(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(22)
	b.sel = Skin.Fill(b, "BACKGROUND", "selected")
	b.sel:SetAllPoints()
	b.sel:Hide()
	b.bar = Skin.Fill(b, "BORDER", "accent")
	b.bar:SetPoint("TOPLEFT")
	b.bar:SetPoint("BOTTOMLEFT")
	b.bar:SetWidth(2)
	b.bar:Hide()
	b.hover = Skin.Fill(b, "BACKGROUND", "hover", 0.5)
	b.hover:SetAllPoints()
	b.hover:Hide()
	b:SetScript("OnEnter", function(self) self.hover:Show() end)
	b:SetScript("OnLeave", function(self) self.hover:Hide() end)
	function b:SetSelected(on)
		self.sel:SetShown(on)
		self.bar:SetShown(on)
	end
	return b
end

-- A row of item icons to pick one from; the first slot, an X, stands for none.
-- Hovering a slot shows the item. tray:SetItems({ { id=, icon= }, ... }, selectedID);
-- onPick(id), nil for none.
local TRAY_SIZE, TRAY_GAP = 28, 4
function Skin.IconTray(parent, onPick)
	local tray = CreateFrame("Frame", nil, parent)
	tray.buttons = {}
	local function Slot(i)
		local b = CreateFrame("Button", nil, tray, "BackdropTemplate")
		b:SetSize(TRAY_SIZE, TRAY_SIZE)
		b:SetPoint("LEFT", (i - 1) * (TRAY_SIZE + TRAY_GAP), 0)
		Skin.Backdrop(b, "element")
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetPoint("TOPLEFT", 2, -2)
		b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
		b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.bars = Bars(b, 12, "dim", math.pi / 4, 0, -math.pi / 4, 0)
		function b:SetSelected(on)
			self.selected = on and true or false
			Rest(self)
		end
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if self.id then GameTooltip:SetItemByID(self.id) else GameTooltip:SetText(ns.L["None"]) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		Hoverable(b)   -- after the scripts: it hooks them
		b:SetScript("OnClick", function(self) onPick(self.id) end)
		return b
	end
	function tray:SetItems(items, selected)
		local n = #items + 1
		for i = 1, n do
			local b = self.buttons[i]
			if not b then
				b = Slot(i)
				self.buttons[i] = b
			end
			local item = items[i - 1]
			b.id = item and item.id or nil
			b.icon:SetTexture(item and item.icon or nil)
			b.icon:SetShown(item ~= nil)
			for _, t in ipairs(b.bars) do t:SetShown(item == nil) end
			b:SetSelected(b.id == selected)
			b:Show()
		end
		for i = n + 1, #self.buttons do self.buttons[i]:Hide() end
		self:SetSize(n * (TRAY_SIZE + TRAY_GAP) - TRAY_GAP, TRAY_SIZE)
	end
	return tray
end

-- Adds a tooltip without replacing the hover scripts a skinned widget has.
-- Takes locale keys, read when shown, so it follows a language switch.
function Skin.Tooltip(widget, titleKey, bodyKey)
	widget:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(ns.L[titleKey], 1, 1, 1, 1, true)
		if bodyKey then GameTooltip:AddLine(ns.L[bodyKey], nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	widget:HookScript("OnLeave", GameTooltip_Hide)
end

-- A slider the way PrismMeter lays it out: the title on one line with the
-- value at its right, the bar under them: a thin track, filled in the
-- accent up to a square thumb. w is the whole block's width. format(v)
-- gives the value's text; onChange(v) runs when the player moves it, not
-- when SetValue sets it. Values are snapped to the step.
local SLIDER_TITLE_H = 18
function Skin.Slider(parent, w, min, max, step, format, onChange)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(w, SLIDER_TITLE_H + 12)
	holder.label = Skin.Label(holder, "", nil, "dim")
	holder.label:SetPoint("TOPLEFT", 0, -2)
	holder.label:SetPoint("RIGHT", -60, 0)
	holder.label:SetJustifyH("LEFT")
	holder.label:SetWordWrap(false)
	holder.value = Skin.Label(holder, "", nil, "accent")
	holder.value:SetPoint("TOPRIGHT", 0, -2)
	holder.value:SetJustifyH("RIGHT")

	local s = CreateFrame("Slider", nil, holder)
	s:SetPoint("TOPLEFT", 0, -SLIDER_TITLE_H)
	s:SetPoint("TOPRIGHT", 0, -SLIDER_TITLE_H)
	s:SetHeight(12)
	s:SetOrientation("HORIZONTAL")
	s:SetHitRectInsets(0, 0, -4, -4)
	local track = Skin.Fill(s, "BACKGROUND", "border")
	track:SetHeight(2)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	s:SetThumbTexture(WHITE)
	local thumb = s:GetThumbTexture()
	thumb:SetSize(10, 10)
	local fill = s:CreateTexture(nil, "ARTWORK")
	fill:SetHeight(2)
	fill:SetPoint("LEFT", track, "LEFT")
	fill:SetPoint("RIGHT", thumb, "CENTER")
	local function Tint(name)
		thumb:SetVertexColor(Skin.Color(name))
		fill:SetColorTexture(Skin.Color(name))
	end
	Skin.Paint(s, function() Tint(s.hovered and "text" or "accent") end)
	s:SetScript("OnEnter", function(self) self.hovered = true; Tint("text") end)
	s:SetScript("OnLeave", function(self) self.hovered = nil; Tint("accent") end)
	s:SetMinMaxValues(min, max)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * step) end)

	local function Snap(v)
		v = math.floor((v - min) / step + 0.5) * step + min
		return math.max(min, math.min(max, v))
	end
	s:SetScript("OnValueChanged", function(_, v)
		v = Snap(v)
		holder.value:SetText(format(v))
		if not holder.silent and v ~= holder.current then
			holder.current = v
			onChange(v)
		end
	end)
	holder.slider = s

	-- sets it without onChange: for a refresh from the saved value
	function holder:SetValue(v)
		v = Snap(v)
		self.silent = true
		self.current = v
		s:SetValue(v)
		self.silent = false
		self.value:SetText(format(v))
	end
	function holder:SetLabel(label) self.label:SetText(label or "") end
	return holder
end

-- A dim label in front of a control, bound to its locale key
function Skin.Field(parent, key, x, y)
	local label = ns.Bind(Skin.Label(parent, "", nil, "dim"), key)
	label:SetPoint("TOPLEFT", x or 0, y - 4)
	return label
end

-- ---------------------------------------------------------------------------
-- Dropdown: a button that opens a small pick list
-- ---------------------------------------------------------------------------

local LIST_ROWS = 12   -- more than this and the list scrolls with the mouse wheel

local optionList
local function ShowOptionList(anchor, items, onPick)
	if not optionList then
		local f = CreateFrame("Frame", "OneClickFishOptionList", UIParent, "BackdropTemplate")
		f:SetFrameStrata("TOOLTIP")
		Skin.Backdrop(f, "bg", 1, "accent")
		f:EnableMouse(true)
		f.buttons = {}
		f.measure = Skin.Label(f, "")
		f.measure:Hide()
		f.thumb = Skin.Fill(f, "ARTWORK", "accent", 0.7)
		f.thumb:SetWidth(2)
		f:EnableMouseWheel(true)
		f:SetScript("OnMouseWheel", function(self, delta)
			local last = math.max(0, #self.items - LIST_ROWS)
			self.offset = math.max(0, math.min(last, self.offset - delta))
			self.Render()
		end)
		-- click anywhere else closes it
		f:SetScript("OnUpdate", function(self)
			if IsMouseButtonDown("LeftButton") and not self:IsMouseOver() and not self.anchor:IsMouseOver() then
				self:Hide()
			end
		end)
		optionList = f
	end
	local f = optionList
	if f:IsShown() and f.anchor == anchor then f:Hide(); return end
	f.anchor = anchor
	-- it hangs off UIParent but has to match the (scaled) window it belongs to
	f:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
	f.items, f.offset = items, 0
	local w = anchor:GetWidth() - 8
	for _, item in ipairs(items) do
		f.measure:SetText(item.label)
		w = math.max(w, f.measure:GetStringWidth() + 16 + ((item.icon or item.swatch) and 22 or 0))
	end
	local rows = math.min(#items, LIST_ROWS)
	for i = 1, rows do
		local b = f.buttons[i]
		if not b then
			b = CreateFrame("Button", nil, f)
			b:SetHeight(20)
			b.hover = Skin.Fill(b, "BACKGROUND", "hover")
			b.hover:SetAllPoints()
			b.hover:Hide()
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetSize(16, 16)
			b.icon:SetPoint("LEFT", 6, 0)
			b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			b.text = Skin.Label(b, "")
			b:SetScript("OnEnter", function(self) self.hover:Show() end)
			b:SetScript("OnLeave", function(self) self.hover:Hide() end)
			b:SetScript("OnClick", function(self)
				f:Hide()
				f.onPick(self.item)
			end)
			f.buttons[i] = b
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
		b:SetWidth(w)
		b:Show()
	end
	for i = rows + 1, #f.buttons do f.buttons[i]:Hide() end

	function f.Render()
		for i = 1, rows do
			local b, item = f.buttons[i], f.items[f.offset + i]
			b.item = item
			b.text:SetText(item.label)
			b.text:ClearAllPoints()
			if item.icon or item.swatch then
				if item.swatch then
					b.icon:SetColorTexture(item.swatch[1], item.swatch[2], item.swatch[3])
				else
					b.icon:SetTexture(item.icon)
				end
				b.icon:Show()
				b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
			else
				b.icon:Hide()
				b.text:SetPoint("LEFT", 8, 0)
			end
		end
		local more = #f.items > rows
		f.thumb:SetShown(more)
		if more then
			local track = rows * 20
			f.thumb:SetHeight(track * rows / #f.items)
			f.thumb:ClearAllPoints()
			f.thumb:SetPoint("TOPRIGHT", -1, -4 - track * f.offset / #f.items)
		end
	end
	f.Render()
	f.onPick = onPick
	f:SetSize(w + 8, rows * 20 + 8)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	f:Show()
end

function Skin.HideOptionList() if optionList then optionList:Hide() end end

-- getItems(dropdown) -> { { label=, value=, icon= | swatch= }, ... }; onPick(dropdown, item)
function Skin.Dropdown(parent, w, getItems, onPick)
	local d = CreateFrame("Button", nil, parent, "BackdropTemplate")
	d:SetSize(w, 20)
	Skin.Backdrop(d, "element")
	Hoverable(d)

	d.chevron = Skin.Chevron(d)
	d.chevron:SetPoint("RIGHT", -6, 0)

	d.text = Skin.Label(d, "")
	d.text:SetPoint("LEFT", 7, 0)
	d.text:SetPoint("RIGHT", -20, 0)
	d.text:SetJustifyH("LEFT")
	d.text:SetWordWrap(false)

	d:SetScript("OnClick", function(self)
		if self.disabled then return end
		ShowOptionList(self, getItems(self), function(item) onPick(self, item) end)
	end)
	d:SetScript("OnHide", Skin.HideOptionList)

	function d:SetValueText(text, dim)
		self.text:SetText(text)
		self.text:SetTextColor(Skin.Color((dim or self.disabled) and "dim" or "text"))
	end
	function d:SetDisabled(disabled)
		self.disabled = disabled and true or false
		self:SetAlpha(self.disabled and 0.55 or 1)
	end
	return d
end

Skin.SetTheme(Skin.THEMES[1].key)   -- until the saved one is read
