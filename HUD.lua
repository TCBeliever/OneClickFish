local ADDON, ns = ...
local L, Skin = ns.L, ns.Skin

-- ===========================================================================
-- The session HUD: one small box, on screen from the first cast on, gone
-- after some minutes without a cast.
--
--   [icon] OneClickFish Session           [Reset]
--   ---------------------------------------------
--   Casts / catches / hr             12 / 11 / 48
--   Est. value (Auctionator)                12.3g
--   Gold/hr · time                  52.1g · 14:12
--   Lure                                    7:40   <- only with a lure picked
--   ---------------------------------------------
--   [i] Scalebelly Mackerel        6     8g 10s   <- what was caught, most first; hover for the item
--   [i] Thousandbite Piranha       3     2g 05s
--   [==========------]                            <- the channel draining, only while the line is out
--
-- Right click opens the settings, drag moves, Ctrl + mouse wheel resizes.
-- ===========================================================================

local HUD = {}
ns.HUD = HUD

local PAD_X, PAD_Y = 10, 8
local LINE_H  = 16
local GAP     = 14   -- between columns
local MIN_W, MAX_W = 180, 320
local ICON    = 14
local BAR_H   = 3
local BAR_GAP = 6    -- above the bar
local RULE_GAP = 5   -- above and below a line between two blocks
local TITLE_H = 18
local MAX_CATCHES = 8

HUD.SCALE_MIN, HUD.SCALE_MAX, HUD.SCALE_STEP = 0.6, 1.8, 0.1
HUD.IDLE_MIN, HUD.IDLE_MAX = 1, 30   -- minutes without a cast before the box goes

local ROWS = { "fishing", "value", "rate", "lure" }   -- the lure row only with a lure picked

local frame

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- Money as one number and the game's coin: at most four digits and one
-- decimal, cut rather than rounded. 105.4g, 1,054g, 10.2kg, 1.2mg; under a
-- gold 34.5s, under a silver 56c.
local GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"

local function Tenth(n) return string.format("%.1f", math.floor(n * 10) / 10) end
local function Thousands(n)
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function Money(copper)
	copper = math.floor((copper or 0) + 0.5)
	local gold = copper / 10000
	if gold >= 1000000 then return Tenth(gold / 1000000) .. "m" .. GOLD end
	if gold >= 10000 then return Tenth(gold / 1000) .. "k" .. GOLD end
	if gold >= 1000 then return Thousands(gold) .. GOLD end
	if gold >= 1 then return Tenth(gold) .. GOLD end
	local silver = copper / 100
	if silver >= 1 then return Tenth(silver) .. SILVER end
	return copper .. COPPER
end
HUD.Money = Money   -- for the tests

local function Clock(seconds)
	seconds = math.floor(seconds or 0)
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
	if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
	return string.format("%d:%02d", m, s)
end

local function Values(stats)
	local left = ns.LureLeft()
	return {
		fishing = string.format("%d / %d / %.0f", stats.casts, stats.catches, stats.catchPerHour),
		value   = Money(stats.value),
		rate    = Money(stats.goldPerHour) .. " · " .. Clock(stats.elapsed),
		lure    = left > 0 and Clock(left) or Skin.Text("warn", L["LURE_none"]),
	}
end

-- The catches of the session, most first: { id=, link=, count=, value=, name=, icon= }.
-- Grey things and what Dejunk calls junk are left out. A name the client has
-- not loaded yet is read off the link and asked for; the event brings a refresh.
local POOR = Enum.ItemQuality and Enum.ItemQuality.Poor or 0
local function Catches(loot)
	local list = {}
	for id, entry in pairs(loot) do
		local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(entry.link)
		if quality == POOR or ns.IsJunk(id) then
			name = nil   -- not listed
		elseif not name then
			name = entry.link:match("%[(.-)%]") or tostring(id)
			C_Item.RequestLoadItemDataByID(id)
		end
		if name then
			local colour = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
			if colour and colour.hex then name = colour.hex .. name .. "|r" end
			list[#list + 1] = { id = id, link = entry.link, count = entry.count, value = entry.value or 0, name = name,
				icon = icon or C_Item.GetItemIconByID(id) }
		end
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then return a.count > b.count end
		return a.id < b.id
	end)
	return list
end

-- ---------------------------------------------------------------------------
-- Position and size
-- ---------------------------------------------------------------------------

local function ApplyPosition()
	local s = ns.db.hud
	frame:ClearAllPoints()
	frame:SetPoint(s.point, UIParent, s.relPoint, s.x, s.y)
end

function HUD.SetScale(scale)
	scale = math.max(HUD.SCALE_MIN, math.min(HUD.SCALE_MAX, scale))
	scale = math.floor(scale * 10 + 0.5) / 10
	ns.db.hud.scale = scale
	if frame then frame:SetScale(scale) end
	ns.RefreshOptions()
end

function HUD.ResetPosition()
	local s, d = ns.db.hud, ns.defaults.hud
	s.point, s.relPoint, s.x, s.y = d.point, d.relPoint, d.x, d.y
	if frame then ApplyPosition() end
end

-- ---------------------------------------------------------------------------
-- The box
-- ---------------------------------------------------------------------------

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine("|cff66ccffOneClick|rFish")
	GameTooltip:AddLine(L["HUD_HINT"], Skin.Color("dim"))
	GameTooltip:Show()
end

-- Dragging and resizing work from anywhere on the box, the catch rows included.
local function MakeHandle(widget)
	widget:EnableMouseWheel(true)
	widget:RegisterForDrag("LeftButton")
	widget:SetScript("OnDragStart", function()
		if not ns.db.hud.locked then frame:StartMoving() end
	end)
	widget:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relPoint, x, y = frame:GetPoint()
		local s = ns.db.hud
		s.point, s.relPoint, s.x, s.y = point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5)
	end)
	widget:SetScript("OnMouseWheel", function(_, delta)
		if IsControlKeyDown() then HUD.SetScale(ns.db.hud.scale + delta * HUD.SCALE_STEP) end
	end)
	widget:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "RightButton" then ns.ToggleOptions() end
	end)
end

-- The channel draining: how much of the cast is left, each frame while the line is out.
local function UpdateBar(self)
	local _, _, _, startMS, endMS = UnitChannelInfo("player")
	if not (startMS and endMS) or IsSecret(startMS) or IsSecret(endMS) or endMS <= startMS then return end
	local frac = (endMS - GetTime() * 1000) / (endMS - startMS)
	frac = math.max(0, math.min(1, frac))
	self.fill:SetWidth(math.max(0.01, (self:GetWidth() - PAD_X * 2) * frac))
end

local function OnUpdate(self, elapsed)
	if ns.IsFishing() then UpdateBar(self) end
	self.tick = (self.tick or 0) + elapsed
	if self.tick >= 1 then
		self.tick = 0
		HUD.Refresh()   -- the clock, the rates, and the idle timeout
	end
end

-- A catch row: a strip that shows the item on hover, with the icon, the name
-- and two right-aligned columns, the count and the value.
local function CatchRow(f, i)
	local r = f.catches[i]
	if not r then
		local strip = CreateFrame("Frame", nil, f)
		strip:SetHeight(LINE_H)
		strip:EnableMouse(true)
		MakeHandle(strip)
		strip:SetScript("OnEnter", function(self)
			if not self.link then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.link)
			GameTooltip:Show()
		end)
		strip:SetScript("OnLeave", GameTooltip_Hide)
		r = { frame = strip, icon = strip:CreateTexture(nil, "ARTWORK"), name = Skin.Label(strip, ""),
			count = Skin.Label(strip, ""), value = Skin.Label(strip, "", nil, "dim") }
		r.icon:SetSize(ICON, ICON)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.icon:SetPoint("LEFT", 0, 0)
		r.name:SetPoint("LEFT", ICON + 5, 0)
		r.name:SetJustifyH("LEFT")
		r.name:SetWordWrap(false)
		r.count:SetJustifyH("RIGHT")
		r.value:SetJustifyH("RIGHT")
		r.value:SetPoint("RIGHT", 0, 0)
		f.catches[i] = r
	end
	return r
end

local function Rule(f)
	local t = Skin.Fill(f, "ARTWORK", "border", 0.6)
	t:SetHeight(1)
	return t
end

local function CreateHUD()
	local f = CreateFrame("Frame", "OneClickFishHUD", UIParent, "BackdropTemplate")
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	Skin.Backdrop(f, "bg", 0.8, "accent")
	MakeHandle(f)
	f:SetScript("OnEnter", ShowTooltip)
	f:SetScript("OnLeave", GameTooltip_Hide)
	f:SetScript("OnUpdate", OnUpdate)

	-- the title row, with a line under it
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(ICON, ICON)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.icon:SetPoint("TOPLEFT", PAD_X, -PAD_Y - 1)
	f.title = Skin.Label(f, "", "GameFontHighlight")
	f.title:SetPoint("LEFT", f.icon, "RIGHT", 5, 0)
	f.reset = ns.Bind(Skin.Button(f, "", 40, 16, function() ns.ResetSession() end), "Reset")
	f.reset:SetPoint("TOPRIGHT", -PAD_X, -PAD_Y)
	f.titleRule = Rule(f)
	f.titleRule:SetPoint("TOPLEFT", PAD_X, -(PAD_Y + TITLE_H + RULE_GAP))
	f.titleRule:SetPoint("TOPRIGHT", -PAD_X, -(PAD_Y + TITLE_H + RULE_GAP))

	-- the numbers
	f.rows = {}
	local top = PAD_Y + TITLE_H + RULE_GAP * 2 + 1
	for i = 1, #ROWS do
		local y = -(top + LINE_H * (i - 1)) - 1
		local r = { label = Skin.Label(f, "", nil, "dim"), value = Skin.Label(f, "") }
		r.label:SetPoint("TOPLEFT", PAD_X, y)
		r.value:SetPoint("TOPRIGHT", -PAD_X, y)
		r.value:SetJustifyH("RIGHT")
		f.rows[i] = r
	end
	f.rowsTop = top

	-- the catches, under a line of their own
	f.rule = Rule(f)
	f.catches = {}

	f.track = Skin.Fill(f, "ARTWORK", "border", 0.5)
	f.track:SetHeight(BAR_H)
	f.track:SetPoint("BOTTOMLEFT", PAD_X, PAD_Y)
	f.track:SetPoint("BOTTOMRIGHT", -PAD_X, PAD_Y)
	f.fill = Skin.Fill(f, "OVERLAY", "accent")
	f.fill:SetHeight(BAR_H)
	f.fill:SetPoint("BOTTOMLEFT", PAD_X, PAD_Y)

	f:SetScale(ns.db.hud.scale)
	frame = f
	ApplyPosition()
	return f
end

-- Shown from the first cast until `idle` minutes pass without one; always while the settings are open.
local function Wanted(stats)
	local s = ns.db.hud
	if s.show == "never" or not ns.IsEnabled() then return ns.IsOptionsShown() and s.show ~= "never" end
	if ns.IsOptionsShown() or ns.IsFishing() then return true end
	if stats.casts == 0 then return false end
	local last = ns.db.session.last or 0
	return time() - last < s.idle * 60
end

function HUD.Refresh()
	if not ns.db then return end
	local stats = ns.GetStats()
	if not Wanted(stats) then
		if frame then frame:Hide() end
		return
	end
	if not frame then CreateHUD() end

	local fishing = ns.IsFishing()
	frame.icon:SetTexture(ns.ProfessionIcon())
	frame.title:SetText(Skin.Text("accent", "OneClick") .. "Fish " .. L["Session"])

	-- the numbers: two columns, as wide as the widest of them
	local values = Values(stats)
	local labelW, valueW = 0, 0
	local shownRows = ns.db.settings.lure and #ROWS or #ROWS - 1
	for i, key in ipairs(ROWS) do
		local r = frame.rows[i]
		if i <= shownRows then
			local label = L["ROW_" .. key]
			if key == "value" then label = string.format(label, stats.source or L["SRC_vendor"]) end   -- who priced it
			r.label:SetText(label)
			r.value:SetText(values[key])
			labelW = math.max(labelW, r.label:GetStringWidth())
			valueW = math.max(valueW, r.value:GetStringWidth())
			r.label:Show(); r.value:Show()
		else
			r.label:Hide(); r.value:Hide()
		end
	end

	-- the catches: measured before the box is sized, a long name is cut to fit
	local list = ns.db.hud.catches and Catches(stats.loot) or {}
	local shown = math.min(#list, MAX_CATCHES)
	local nameW, countW, moneyW = 0, 0, 0
	for i = 1, shown do
		local r, c = CatchRow(frame, i), list[i]
		r.frame.link = c.link
		r.icon:SetTexture(c.icon)
		r.name:SetWidth(0)   -- unbound, to measure
		r.name:SetText(c.name)
		r.count:SetText(tostring(c.count))
		r.value:SetText(c.value > 0 and Money(c.value) or "")
		nameW = math.max(nameW, r.name:GetStringWidth())
		countW = math.max(countW, r.count:GetStringWidth())
		if c.value > 0 then moneyW = math.max(moneyW, r.value:GetStringWidth()) end
	end

	local titleW = ICON + 5 + frame.title:GetStringWidth() + GAP + frame.reset:GetWidth()
	local inner = math.max(labelW + GAP + valueW, titleW)
	local columns = countW + (moneyW > 0 and GAP + moneyW or 0)
	if shown > 0 then inner = math.max(inner, ICON + 5 + nameW + GAP + columns) end
	local width = math.max(MIN_W, math.min(MAX_W, PAD_X + inner + PAD_X))
	local y = -(frame.rowsTop + LINE_H * shownRows)

	frame.rule:SetShown(shown > 0)
	if shown > 0 then
		frame.rule:ClearAllPoints()
		frame.rule:SetPoint("TOPLEFT", PAD_X, y - RULE_GAP)
		frame.rule:SetPoint("TOPRIGHT", -PAD_X, y - RULE_GAP)
		y = y - RULE_GAP * 2 - 1
		local nameRoom = width - PAD_X * 2 - ICON - 5 - GAP - columns
		for i = 1, shown do
			local r = frame.catches[i]
			r.frame:ClearAllPoints()
			r.frame:SetPoint("TOPLEFT", PAD_X, y)
			r.frame:SetPoint("TOPRIGHT", -PAD_X, y)
			r.name:SetWidth(nameRoom)
			r.count:ClearAllPoints()
			r.count:SetPoint("RIGHT", -(moneyW > 0 and GAP + moneyW or 0), 0)
			r.frame:Show()
			y = y - LINE_H
		end
	end
	for i = shown + 1, #frame.catches do frame.catches[i].frame:Hide() end

	local height = -y + PAD_Y
	if fishing then height = height + BAR_GAP + BAR_H end
	frame:SetSize(width, height)
	frame.track:SetShown(fishing)
	frame.fill:SetShown(fishing)
	frame:Show()
end

-- for the settings and the tests
function HUD.GetFrame() return frame end
