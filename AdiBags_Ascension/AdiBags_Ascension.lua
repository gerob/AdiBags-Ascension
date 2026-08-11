--[[
AdiBags_Ascension - Ascension-specific filters for AdiBags.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local _, ns = ...

local addon = LibStub('AceAddon-3.0'):GetAddon('AdiBags')
local L = setmetatable({}, {__index = addon.L})

do -- Localization
	L["uiName"] = "Ascension filter"
	L["UiDesc"] = "Putting items that are from Ascension in a specific section."
	local locale = GetLocale()
end

-----------------------------------------------------------
-- Filter Setup
-----------------------------------------------------------

-- Register our filter with AdiBags
local filter = addon:RegisterFilter("Ascension", 95, 'AceEvent-3.0')
filter.uiName = L['uiName']
filter.uiDesc = L['UiDesc']

local SCAN_TIP_NAME = "AdiBagsAscensionScanTip"
local scanTip
local worldforgedCache = {}

local function EnsureScanTip()
	if scanTip then return end
	scanTip = CreateFrame("GameTooltip", SCAN_TIP_NAME, nil, "GameTooltipTemplate")
	scanTip:SetOwner(UIParent, "ANCHOR_NONE")
end

-- Returns true / false / nil (nil = not ready or error; do not cache).
local function TooltipHasWorldforged(link)
	if not link then return false end
	EnsureScanTip()

	local ok = pcall(function()
		scanTip:ClearLines()
		scanTip:SetHyperlink(link)
	end)
	if not ok then
		return nil
	end

	local line1 = _G[SCAN_TIP_NAME .. "TextLeft1"]
	local line1Text = line1 and line1:GetText()
	if line1Text == "Retrieving item information..." then
		return nil
	end

	local numLines = scanTip:NumLines() or 0
	for i = 1, numLines do
		local fs = _G[SCAN_TIP_NAME .. "TextLeft" .. i]
		local text = fs and fs:GetText()
		if text and string.find(string.lower(text), "worldforged", 1, true) then
			return true
		end
	end
	return false
end

local function IsWorldforged(itemId, link)
	if not itemId then return false end
	local cached = worldforgedCache[itemId]
	if cached ~= nil then
		return cached
	end

	local item = GetItemInfoInstant(itemId)
	if item and item.description and type(item.description) == "string"
		and string.find(string.lower(item.description), "worldforged", 1, true) then
		worldforgedCache[itemId] = true
		return true
	end

	local tipResult = TooltipHasWorldforged(link)
	if tipResult == nil then
		return false -- retry on next bag update; do not cache
	end
	worldforgedCache[itemId] = tipResult
	return tipResult
end

function filter:OnInitialize()
	self.db = addon.db:RegisterNamespace('Ascension', {
		profile = { oneSectionPerSet = true },
		char = { mergedSets = { ['*'] = false } },
	})
end

function filter:OnEnable()
	EnsureScanTip()
	wipe(worldforgedCache)
	addon:UpdateFilters()
end

function filter:OnDisable()
	addon:UpdateFilters()
end

function filter:Filter(slotData)
	-- Quality-6 Ascension/Vanity first so tooltip scanning cannot skip them.
	if slotData.quality == 6 then
		if VANITY_ITEMS and VANITY_ITEMS[slotData.itemId] and VANITY_ITEMS[slotData.itemId].itemid > 0 then
			return "Ascension"
		else
			return "Vanity"
		end
	end

	-- Worldforged (tooltip-tagged) — before Transmog so WF gear is not miscategorized.
	if IsWorldforged(slotData.itemId, slotData.link) then
		return "Worldforged", "Equipment"
	end

	-- Transmog / Mythic+ equipment
	if (slotData.class == "Weapon" or slotData.class == "Armor") then
		local item = GetItemInfoInstant(slotData.itemId)
		if item and item.description and (string.find(item.description, "@Mythic %d") or string.find(item.description, "@Mythic Level")) then
			return "Mythic+", 'Equipment'
		end
		if C_Appearance and slotData.subclass ~= "Thrown" and slotData.itemId ~= 5956 then
			local appearanceID = C_Appearance.GetItemAppearanceID(slotData.itemId)
			if appearanceID then
				local isCollected = C_AppearanceCollection.IsAppearanceCollected(appearanceID)
				if not isCollected then
					Owned = 3
					return "Transmog", 'Equipment'
				end
			end
		end
	else
		local item = GetItemInfoInstant(slotData.itemId)
		if item and item.description and (string.find(item.description, "@Mythic %d") or string.find(item.description, "@Mythic Level")) then
			return "Mythic+", 'Equipment'
		elseif item and item.description and item.inventoryType == 0 and (string.find(item.description, "This Token") or string.find(item.description, "This token")) then
			return "Tier Token", 'Equipment'
		elseif item and item.description and string.find(item.description, "@re") then
			return "Mystic Enchants"
		end
	end
	-- Trade Goods equipment
	if slotData.itemId == 5956 or slotData.itemId == 6219 or slotData.itemId == 20824 or slotData.itemId == 20815 or slotData.itemId == 10498 or
		slotData.itemId == 22463 or slotData.itemId == 22462 or slotData.itemId == 22461 or slotData.itemId == 16207 or slotData.itemId == 11145 or
		slotData.itemId == 11130 or slotData.itemId == 6339 or slotData.itemId == 6218 or slotData.itemId == 23821 or slotData.itemId == 6954 or 
		slotData.itemId == 9149 or slotData.itemId == 2901 or slotData.itemId == 7005 then
		return "Tools", 'Trade Goods'
	end
end

function filter:GetFilterOptions()
	return {
		-- oneSectionPerSet = {
		-- 	name = L['One section per set'],
		-- 	desc = L['Check this to display one individual section per set. If this is disabled, there will be one big "Sets" section.'],
		-- 	type = 'toggle',
		-- 	order = 10,
		-- }
	}, addon:GetOptionHandler(self, true)
end
