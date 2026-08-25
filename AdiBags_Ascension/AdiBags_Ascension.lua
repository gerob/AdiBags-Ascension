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

function filter:OnInitialize()
	self.db = addon.db:RegisterNamespace('Ascension', {
		profile = { oneSectionPerSet = true },
		char = { mergedSets = { ['*'] = false } },
	})
end

function filter:OnEnable()
	addon:UpdateFilters()
end

function filter:OnDisable()
	addon:UpdateFilters()
end

function filter:Filter(slotData)
		-- Trade Goods equipment
	if slotData.itemId == 5956 or slotData.itemId == 6219 or slotData.itemId == 20824 or slotData.itemId == 20815 or slotData.itemId == 10498 or
		slotData.itemId == 22463 or slotData.itemId == 22462 or slotData.itemId == 22461 or slotData.itemId == 16207 or slotData.itemId == 11145 or
		slotData.itemId == 11130 or slotData.itemId == 6339 or slotData.itemId == 6218 or slotData.itemId == 23821 or slotData.itemId == 6954 or 
		slotData.itemId == 9149 or slotData.itemId == 2901 or slotData.itemId == 7005 then
		return "Tools", 'Trade Goods'
	end
	-- Quality-6 Ascension/Vanity first so tooltip scanning cannot skip them.
	if slotData.quality == 6 then
		if VANITY_ITEMS and VANITY_ITEMS[slotData.itemId] and VANITY_ITEMS[slotData.itemId].itemid > 0 then
			return "Ascension"
		else
			return "Vanity"
		end
	end

	-- Transmog / Mythic+ equipment
	if (slotData.class == "Weapon" or slotData.class == "Armor") then
		-- Worldforged (tooltip-tagged) — before Transmog so WF gear is not miscategorized.
		if GetItemFlavorText(slotData.itemId) and string.find(GetItemFlavorText(slotData.itemId), "@Worldforged") then
			return "Worldforged", "Equipment"
		end		
		local mythicLevel = tonumber(tostring(GetItemMythicLevel(slotData.itemId)):match("%d+")) or 0-- Tempfix for GetItemMythicLevel also returning the "10@" in "@Mythic 10@"
		if mythicLevel > 0 then-- GetItemMythicLevel(slotData.itemId) and GetItemMythicLevel(slotData.itemId) > 0 then
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
	-- Mythic+ items
	else
		local mythicLevel = tonumber(tostring(GetItemMythicLevel(slotData.itemId)):match("%d+")) or 0-- Tempfix for GetItemMythicLevel also returning the "10@" in "@Mythic 10@"
		local flavor = GetItemFlavorText(slotData.itemId)
		if mythicLevel > 0 then-- GetItemMythicLevel(slotData.itemId) and GetItemMythicLevel(slotData.itemId) > 0 then
			return "Mythic+", 'Equipment'
		elseif flavor and string.find(flavor, "This Token") then
			return "Tier Token", 'Equipment'
		elseif flavor and string.find(flavor, "@re") then
			return "Mystic Enchants"
		end
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
