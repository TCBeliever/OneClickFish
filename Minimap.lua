local ADDON, ns = ...
local L, Skin = ns.L, ns.Skin

-- ===========================================================================
-- The minimap button: left click switches fishing mode on or off, right click
-- opens the settings. It is drawn the way the game draws its own minimap
-- buttons, so it sits among the others, with the Fishing profession's icon,
-- grey while the mode is off. Drag moves it around the minimap's edge.
-- ===========================================================================

local Minimap_ = {}
ns.Minimap = Minimap_

local RADIUS = 80

local frame

local function ApplyPosition()
	local a = math.rad(ns.db.minimap.angle)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

-- While dragging, the button follows the cursor around the edge.
local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	if not mx then return end
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	ApplyPosition()
end

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("|cff66ccffOneClick|rFish")
	local on = ns.IsEnabled()
	GameTooltip:AddLine(Skin.Text(on and "ok" or "dim", L[on and "MODE_on" or "MODE_off"]))
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["MINIMAP_HINT"], Skin.Color("dim"))
	GameTooltip:Show()
end

-- The game's own minimap button: a round icon in a ring, as the tracking
-- button and most addons draw theirs.
local function Create()
	local b = CreateFrame("Button", "OneClickFishMinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(17, 17)
	b.icon:SetPoint("TOPLEFT", 7, -6)
	b.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	b.mask = b:CreateMaskTexture()
	b.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	b.mask:SetAllPoints(b.icon)
	b.icon:AddMaskTexture(b.mask)
	local ring = b:CreateTexture(nil, "OVERLAY")
	ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	ring:SetSize(53, 53)
	ring:SetPoint("TOPLEFT")

	b:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			ns.ToggleOptions()
		else
			ns.SetEnabled(not ns.IsEnabled())
		end
	end)
	b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnEnter", ShowTooltip)
	b:SetScript("OnLeave", GameTooltip_Hide)
	frame = b
	ApplyPosition()
	return b
end

function Minimap_.Refresh()
	if not ns.db then return end
	if not ns.db.settings.minimap then
		if frame then frame:Hide() end
		return
	end
	if not frame then Create() end
	frame.icon:SetTexture(ns.ProfessionIcon())
	frame.icon:SetDesaturated(not ns.IsEnabled())
	frame:Show()
end

-- for the tests
function Minimap_.GetFrame() return frame end
