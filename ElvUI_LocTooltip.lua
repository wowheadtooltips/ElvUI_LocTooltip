-------------------------------------------------------------------------------
-- ElvUI Location Tooltip             
-- By: Lockslap, US - Bleeding Hollow 
-------------------------------------------------------------------------------
local E, C, L, DB = unpack(ElvUI)

-------------------------------------------------------------------------------
-- Miscellaneous
-------------------------------------------------------------------------------
local _G = getfenv(0)
local format = string.format

-------------------------------------------------------------------------------
-- Libraries
-------------------------------------------------------------------------------
local LibStub 	= _G.LibStub
local QT		= LibStub("LibQTip-1.0")
local LT		= LibStub("LibTourist-3.0")
local BZ		= LibStub("LibBabble-Zone-3.0"):GetLookupTable()

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local tooltip
local CHAT_TEXT	-- for inserting into chat's editbox
local battlegrounds = {}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local ICON_PLUS = [[|TInterface\BUTTONS\UI-PlusButton-Up:15:15|t]]
local ICON_MINUS = [[|TInterface\BUTTONS\UI-MinusButton-Up:15:15|t]]
local CONTINENT_DATA = {
	[BZ["Kalimdor"]] = {
		id = 1,
		zone_names = {},
		zone_ids = {}
	},
	[BZ["Eastern Kingdoms"]] = {
		id = 2,
		zone_names = {},
		zone_ids = {}
	},
	[BZ["Outland"]] = {
		id = 3,
		zone_names = {},
		zone_ids = {}
	},
	[BZ["Northrend"]] = {
		id = 4,
		zone_names = {},
		zone_ids = {}
	},
	[BZ["The Maelstrom"]] = {
		id = 5,
		zone_names = {},
		zone_ids = {}
	},
}

-------------------------------------------------------------------------------
-- Font definitions.
-------------------------------------------------------------------------------
-- Setup the Header Font. 12
local locHeaderFont = CreateFont("locHeaderFont")
locHeaderFont:SetTextColor(1,0.823529,0)
locHeaderFont:SetFont(GameTooltipHeaderText:GetFont(), 15)

-- Setup the Regular Font. 12
local locRegFont = CreateFont("locRegFont")
locRegFont:SetTextColor(1,1,1)
locRegFont:SetFont(GameTooltipText:GetFont(), 14)

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------
local function GetZoneData(datafeed)
	local zone_status, subzone_ispvp, controlling_faction = GetZonePVPInfo()
	local current_zone = GetRealZoneText()
	local current_subzone = GetSubZoneText()

	if current_subzone == "" or current_subzone == current_zone then
		current_subzone = nil
	end
	local zone_str, subzone_str
	local label
	local r, g, b = 1.0, 1.0, 1.0

	if zone_status == "sanctuary" then
		label = _G.SANCTUARY_TERRITORY
		r, g, b = 0.41, 0.8, 0.94
	elseif  zone_status == "arena" then
		label = _G.FREE_FOR_ALL_TERRITORY
		r, g, b = 1.0, 0.1, 0.1
	elseif zone_status == "friendly" then
		label = format(_G.FACTION_CONTROLLED_TERRITORY, controlling_faction)
		r, g, b = 0.1, 1.0, 0.1
	elseif zone_status == "hostile" then
		label = format(_G.FACTION_CONTROLLED_TERRITORY, controlling_faction)
		r, g, b = 1.0, 0.1, 0.1
	elseif zone_status == "contested" then
		label = _G.CONTESTED_TERRITORY
		r, g, b = 1.0, 0.7, 0
	elseif zone_status == "combat" then
		label = _G.COMBAT_ZONE
		r, g, b = 1.0, 0.1, 0.1
	else
		label = _G.CONTESTED_TERRITORY
		r, g, b = 1.0, 0.9294, 0.7607
	end

	subzone_str = current_subzone or nil
	zone_str = current_zone or nil

	if not zone_str and not subzone_str then
		zone_str = current_zone
	end
	local colon = (zone_str and subzone_str) and ": " or ""
	local hex = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
	local text = format("%s%s%s", zone_str or "", colon, subzone_str or "")
	local color_text = format("%s%s%s%s|r", hex, zone_str or "", colon, subzone_str or "")
	label = format("%s%s|r", hex, label)

	return current_zone, current_subzone, label, color_text, text
end

local function GetCoords(to_chat)
	local x, y = GetPlayerMapPosition("player")
	local retstr = format(_G.PARENS_TEMPLATE, format("%.2f, %.2f", x * 100, y * 100))

	return to_chat and (CHAT_TEXT.." "..retstr) or retstr
end

-- Gathers all data relevant to the given instance and adds it to the tooltip.
local function Tooltip_AddInstance(instance)
	local r, g, b = LT:GetLevelColor(instance)
	local hex = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)

	local location = LT:GetInstanceZone(instance)
	local r2, g2, b2 = LT:GetFactionColor(location)
	local hex2 = format("|cff%02x%02x%02x", r2 * 255, g2 * 255, b2 * 255)

	local min, max = LT:GetLevel(instance)
	local _, x, y = LT:GetEntrancePortalLocation(instance)
	local group = LT:GetInstanceGroupSize(instance)

	local level_str

	if min == max then
		level_str = format("%s%d|r", hex, min)
	else
		level_str = format("%s%d - %d|r", hex, min, max)
	end
	local coord_str = ((not x or not y) and "" or format("%.2f, %.2f", x, y))

	local complex = LT:GetComplex(instance)
	local colon = complex and ": " or ""
	local line = tooltip:AddLine()

	tooltip:SetCell(line, 1, format("%s%s%s", complex and complex or "", colon, instance), "LEFT", 2)
	tooltip:SetCell(line, 3, level_str)
	tooltip:SetCell(line, 4, group > 0 and format("%d", group) or "")

	if location ~= complex then
		tooltip:SetCell(line, 5, format("%s%s|r", hex2, location or _G.UNKNOWN))
	end

	tooltip:SetCell(line, 6, coord_str)

	if _G.TomTom and x and y then
		tooltip:SetLineScript(line, "OnMouseUp", InstanceOnMouseUp, instance)
	end
end

local function SetCoordLine()
	local x, y = GetPlayerMapPosition("player")
	tooltip:SetCell(coord_line, 6, format("%.2f, %.2f", x * 100, y * 100))
end

-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------
local function DrawTooltip(self)
	-- get zone data
	local current_zone, current_subzone, pvp_label, zone_text, _ = GetZoneData(false)

	if QT:IsAcquired("ElvuiLocTooltip") then
		tooltip:Clear()
	else
		tooltip = QT:Acquire("ElvuiLocTooltip", 6, "LEFT", "LEFT", "CENTER", "RIGHT", "RIGHT", "RIGHT")
		self.tooltip = tooltip
		tooltip:EnableMouse(true)
		tooltip:SetBackdropColor(0,0,0,1)
		tooltip:SetHeaderFont(locHeaderFont)
		tooltip:SetFont(locRegFont)
		tooltip:SmartAnchorTo(ElvuiLoc)
		tooltip:SetAutoHideDelay(0.1, self)
	end
	
	-- add the zone headers
	local line, column = tooltip:AddHeader()
	tooltip:SetCell(line, 1, zone_text .. " " .. pvp_label, "LEFT", 6)
	tooltip:AddLine(" ")
	
	local header_line = tooltip:AddHeader()
	
	-- add any dungeons for current zone
	if LT:DoesZoneHaveInstances(current_zone) then
		local count = 0
		tooltip:AddSeparator()
		
		for instance in LT:IterateZoneInstances(current_zone) do
			Tooltip_AddInstance(instance)
			count = count + 1
		end
		tooltip:SetCell(header_line, 1, (count > 1 and _G.MULTIPLE_DUNGEONS or _G.LFG_TYPE_DUNGEON), "LEFT")
	else
		tooltip:SetCell(header_line, 1, "Dungeon", "LEFT")
		tooltip:SetCell(header_line, 1, "|cffff0000None in this zone.", "LEFT")
	end
	tooltip:AddLine(" ")
	
	local found_battleground = false
	
	-- recommended instances
	if LT:HasRecommendedInstances() then
		line = tooltip:AddHeader()
		tooltip:SetCell(line, 1, "Recommended Instances", "LEFT")
		
		tooltip:AddSeparator()
		
		for instance in LT:IterateRecommendedInstances() do
			if LT:IsBattleground(instance) then
				-- its a BG so add to our table to display later
				if not found_battleground then
					_G.wipe(battlegrounds)
					found_battleground = true
				end
				battlegrounds[instance] = true
			else
				Tooltip_AddInstance(instance)
			end
		end
		tooltip:AddLine(" ")
	end
	
	-- recommended zones
	line = tooltip:AddHeader()
	tooltip:SetCell(line, 1, "Recommended Zones", "LEFT")
	tooltip:AddSeparator()
	for zone in LT:IterateRecommendedZones() do
		local r1, g1, b1 = LT:GetLevelColor(zone)
		local hex1 = format("|cff%02x%02x%02x", r1 * 255, g1 * 255, b1 * 255)
		local r2, g2, b2 = LT:GetFactionColor(zone)
		local hex2 = format("|cff%02x%02x%02x", r1 * 255, g1 * 255, b1 * 255)
		local min, max = LT:GetLevel(zone)
		local level_str
		
		if min == max then
			level_str = format("%s%d|r", hex1, min)
		else
			level_str = format("%s%d - %d|r", hex1, min, max)
		end
		
		line = tooltip:AddLine()
		tooltip:SetCell(line, 1, format("%s%s|r", hex2, zone), "LEFT", 2)
		tooltip:SetCell(line, 3, level_str)
		tooltip:SetCell(line, 5, LT:GetContinent(zone))
	end
	tooltip:AddLine(" ")
	
	-- battlegrounds (if any)
	if found_battleground then
		line = tooltip:AddHeader()
		tooltip:SetCell(line, 1, _G.BATTLEGROUNDS, "LEFT")
		tooltip:AddSeparator()
		
		for instance in pairs(battlegrounds) do
			Tooltip_AddInstance(instance)
		end
		tooltip:AddLine(" ")
	end
	
	-- set the look of the tooltip
	local noscalemult = E.mult * C["general"].uiscale
	tooltip:SetBackdrop({
	  bgFile = C["media"].blank, 
	  edgeFile = C["media"].blank, 
	  tile = false, tileSize = 0, edgeSize = noscalemult, 
	  insets = { left = -noscalemult, right = -noscalemult, top = -noscalemult, bottom = -noscalemult}
	})
	tooltip:SetBackdropColor(unpack(C.media.backdropfadecolor))
	tooltip:SetBackdropBorderColor(unpack(C.media.bordercolor))
	tooltip:Show()
end
ElvuiLoc:SetScript("OnEnter", DrawTooltip)