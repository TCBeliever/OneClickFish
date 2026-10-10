local ADDON, ns = ...
local L, Skin = ns.L, ns.Skin

-- ===========================================================================
-- The cast button on screen: the secure button the key clicks, made visible.
-- Left click does what the key does (cast, or loot once the bobber is ready);
-- Shift + left click switches fishing mode off, as the minimap button does;
-- right click opens the settings. It shows the pole in the fishing tool slot
-- in the game's own action button frame, and its tooltip is that pole's. The
-- frame lights up green while a click would loot. Drag to move, unless
-- positions are locked.
--
-- A hidden button cannot be clicked by a key, so with the button switched off
-- it is only made invisible and deaf to the mouse.
-- ===========================================================================

local Button = {}
ns.Button = Button

local SIZE = 36
local FALLBACK_ICON = "Interface\\Icons\\Trade_Fishing"

local frame, tooltip, itemTooltip

local function ApplyPosition()
	local s = ns.db.button
	frame:ClearAllPoints()
	frame:SetPoint(s.point, UIParent, s.relPoint, s.x, s.y)
end

function Button.ResetPosition()
	local s, d = ns.db.button, ns.defaults.button
	s.point, s.relPoint, s.x, s.y = d.point, d.relPoint, d.x, d.y
	if frame then ApplyPosition() end
end

-- Two tooltips of ours, one under the other: what the button is and does,
-- then the pole's own tooltip. (Setting an item into a tooltip empties it
-- first, so the two cannot share one; and the game's own tooltip would
-- compare the pole with what is worn, which is the pole itself.)
local function ShowTooltip(self)
	if not tooltip then
		tooltip = CreateFrame("GameTooltip", "OneClickFishTooltip", UIParent, "GameTooltipTemplate")
		itemTooltip = CreateFrame("GameTooltip", "OneClickFishItemTooltip", UIParent, "GameTooltipTemplate")
	end
	tooltip:SetOwner(self, "ANCHOR_RIGHT")
	tooltip:SetText("|cff66ccffOneClick|rFish")
	tooltip:AddLine(L["BUTTON_WHAT"], Skin.Color("dim"))
	tooltip:AddLine(" ")
	tooltip:AddLine(L["BUTTON_LEFT"], 1, 1, 1)
	tooltip:AddLine(L["BUTTON_RIGHT"], 1, 1, 1)
	tooltip:AddLine(L["BUTTON_SHIFT"], Skin.Color("dim"))
	tooltip:AddLine(L["BUTTON_DRAG"], Skin.Color("dim"))
	-- the two lines that matter, in the header's larger font
	for i = 4, 5 do
		local line = _G["OneClickFishTooltipTextLeft" .. i]
		if line then line:SetFontObject("GameTooltipHeaderText") end
	end
	tooltip:Show()

	itemTooltip:SetOwner(self, "ANCHOR_NONE")
	itemTooltip:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, -4)
	if GetInventoryItemID("player", ns.FISHING_TOOL) then
		itemTooltip:SetInventoryItem("player", ns.FISHING_TOOL)
	else
		itemTooltip:SetText(L["No fishing pole equipped."], 1, 1, 1)
	end
	itemTooltip:Show()
	if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
	if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
end

local function HideTooltip()
	if tooltip then tooltip:Hide() end
	if itemTooltip then itemTooltip:Hide() end
end

-- b: the secure button, created in Core.lua
function Button.Setup(b)
	b:SetSize(SIZE, SIZE)
	b:SetFrameStrata("MEDIUM")
	b:SetClampedToScreen(true)
	b:SetMovable(true)
	b:RegisterForDrag("LeftButton")
	-- the game's action button art: the slot frame, a press, a hover
	b.icon = b:CreateTexture(nil, "BACKGROUND")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.frameArt = b:CreateTexture(nil, "OVERLAY")
	b.frameArt:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	b.frameArt:SetSize(SIZE * 66 / 36, SIZE * 66 / 36)
	b.frameArt:SetPoint("CENTER", 0, -1)
	b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	-- the key, in the corner, the way action buttons show theirs
	b.hotkey = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	b.hotkey:SetPoint("TOPRIGHT", -2, -2)
	b.hotkey:SetJustifyH("RIGHT")

	b:SetScript("OnDragStart", function(self)
		if not ns.db.hud.locked and not InCombatLockdown() then self:StartMoving() end
	end)
	b:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		local s = ns.db.button
		s.point, s.relPoint, s.x, s.y = point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5)
	end)
	-- the right button and Shift + left have no secure action; they are ours
	b:SetScript("PostClick", function(self, mouseButton, down)
		if not ns.IsActionEdge(self, down) then return end
		if mouseButton == "RightButton" then
			ns.ToggleOptions()
		elseif mouseButton == "LeftButton" and IsShiftKeyDown() then
			ns.SetEnabled(not ns.IsEnabled())   -- off, in practice: switched off, the button cannot be clicked
		end
	end)
	b:SetScript("OnEnter", ShowTooltip)
	b:SetScript("OnLeave", HideTooltip)
	frame = b
	ApplyPosition()
end

function Button.Refresh()
	if not frame or not ns.db then return end
	local shown = ns.db.settings.enabled and ns.db.settings.showButton
	frame:SetAlpha(shown and 1 or 0)
	frame:EnableMouse(shown)
	if not shown then return end
	frame.icon:SetTexture(GetInventoryItemTexture("player", ns.FISHING_TOOL) or FALLBACK_ICON)
	local key = ns.GetKey()
	frame.hotkey:SetText(key and GetBindingText(key, nil, true) or "")
	-- green: a click loots; amber: the pole wants a lure first
	if ns.IsBobberReady() then
		frame.frameArt:SetVertexColor(Skin.Color("ok"))
	elseif ns.LureNeeded() then
		frame.frameArt:SetVertexColor(Skin.Color("warn"))
	else
		frame.frameArt:SetVertexColor(1, 1, 1)
	end
end

-- for the tests
function Button.GetFrame() return frame end
