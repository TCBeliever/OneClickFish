local ADDON, ns = ...

-- ===========================================================================
-- Look: flat panels, 1px borders, one palette. No Blizzard frame templates and
-- no texture or font files; everything is drawn with the white 8x8 texture.
-- Fonts stay the game's own so every locale keeps its glyphs.
-- The same "Tide" skin as CombatKit, so the two read as one family.
-- ===========================================================================

local Skin = {}
ns.Skin = Skin

local WHITE = "Interface\\Buttons\\WHITE8x8"

-- To restyle the addon, change this table and nothing else.
local C = {
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
}
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

-- frame must have been created with "BackdropTemplate"
function Skin.Backdrop(frame, bg, alpha, border)
	frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	local r, g, b = Skin.Color(bg or "bg")
	frame:SetBackdropColor(r, g, b, alpha or 1)
	frame:SetBackdropBorderColor(Skin.Color(border or "border"))
end

function Skin.Panel(parent, bg, alpha, border)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	Skin.Backdrop(f, bg, alpha, border)
	return f
end

-- A solid colour texture
function Skin.Fill(parent, layer, name, alpha)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	local r, g, b = Skin.Color(name)
	t:SetColorTexture(r, g, b, alpha or 1)
	return t
end

function Skin.Label(parent, text, template, colour)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	fs:SetTextColor(Skin.Color(colour or "text"))
	fs:SetText(text or "")
	return fs
end

-- ---------------------------------------------------------------------------
-- Widgets: button, close button, check box, stepper, dropdown
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
-- SetLabel instead of SetText keeps that true when the language changes.
function Skin.Button(parent, text, w, h, onClick)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(w, h or 20)
	Skin.Backdrop(b, "element")
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

-- A plain Button that behaves like a check box. onChange(checked)
function Skin.Checkbox(parent, text, onChange)
	local c = CreateFrame("Button", nil, parent)
	c:SetHeight(18)
	c.box = Skin.Fill(c, "BACKGROUND", "border")
	c.box:SetSize(14, 14)
	c.box:SetPoint("LEFT")
	c.fill = Skin.Fill(c, "BORDER", "element")
	c.fill:SetSize(12, 12)
	c.fill:SetPoint("CENTER", c.box)
	c.mark = Skin.Fill(c, "ARTWORK", "accent")
	c.mark:SetSize(8, 8)
	c.mark:SetPoint("CENTER", c.box)
	c.mark:Hide()
	c.label = Skin.Label(c, "")
	c.label:SetPoint("LEFT", c.box, "RIGHT", 6, 0)

	-- the click area follows the label, whatever the language
	function c:SetLabel(label)
		self.label:SetText(label or "")
		self:SetWidth(14 + 6 + self.label:GetStringWidth())
	end
	c:SetLabel(text)

	function c:SetChecked(v)
		self.checked = v and true or false
		self.mark:SetShown(self.checked)
	end
	function c:GetChecked() return self.checked or false end

	c:SetScript("OnEnter", function(self) self.box:SetColorTexture(Skin.Color("accent")) end)
	c:SetScript("OnLeave", function(self) self.box:SetColorTexture(Skin.Color("border")) end)
	c:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked)
		onChange(self.checked)
	end)
	return c
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

-- "- 100% +" as one block the caller places; .value is the label in the middle
function Skin.Stepper(parent, onStep)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(20 + 2 + 52 + 2 + 20, 20)
	local minus = Skin.Button(holder, "-", 20, 20, function() onStep(-1) end)
	minus:SetWidth(20)   -- a button grows with its label; these two must not, the block has a fixed width
	minus:SetPoint("LEFT")
	holder.value = Skin.Label(holder, "100%")
	holder.value:SetPoint("LEFT", minus, "RIGHT", 2, 0)
	holder.value:SetWidth(52)
	holder.value:SetJustifyH("CENTER")
	holder.value:SetWordWrap(false)
	local plus = Skin.Button(holder, "+", 20, 20, function() onStep(1) end)
	plus:SetWidth(20)
	plus:SetPoint("LEFT", holder.value, "RIGHT", 2, 0)
	holder.minus, holder.plus = minus, plus
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
	local w = anchor:GetWidth() - 8
	for _, item in ipairs(items) do
		f.measure:SetText(item.label)
		w = math.max(w, f.measure:GetStringWidth() + 16)
	end
	for i, item in ipairs(items) do
		local b = f.buttons[i]
		if not b then
			b = CreateFrame("Button", nil, f)
			b:SetHeight(20)
			b.hover = Skin.Fill(b, "BACKGROUND", "hover")
			b.hover:SetAllPoints()
			b.hover:Hide()
			b.text = Skin.Label(b, "")
			b.text:SetPoint("LEFT", 8, 0)
			b:SetScript("OnEnter", function(self) self.hover:Show() end)
			b:SetScript("OnLeave", function(self) self.hover:Hide() end)
			b:SetScript("OnClick", function(self)
				f:Hide()
				f.onPick(self.item)
			end)
			f.buttons[i] = b
		end
		b.item = item
		b.text:SetText(item.label)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
		b:SetWidth(w)
		b:Show()
	end
	for i = #items + 1, #f.buttons do f.buttons[i]:Hide() end
	f.onPick = onPick
	f:SetSize(w + 8, #items * 20 + 8)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	f:Show()
end

function Skin.HideOptionList() if optionList then optionList:Hide() end end

-- getItems(dropdown) -> { { label=, value= }, ... }; onPick(dropdown, item)
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
		ShowOptionList(self, getItems(self), function(item) onPick(self, item) end)
	end)
	d:SetScript("OnHide", Skin.HideOptionList)

	function d:SetValueText(text)
		self.text:SetText(text)
	end
	return d
end
