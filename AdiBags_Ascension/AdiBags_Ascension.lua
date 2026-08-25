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

-- Profession tools (blacksmith hammer, mining pick, runed rods, etc.)
local TOOLS = {
	[5956] = true, [6219] = true, [20824] = true, [20815] = true, [10498] = true,
	[22463] = true, [22462] = true, [22461] = true, [16207] = true, [11145] = true,
	[11130] = true, [6339] = true, [6218] = true, [23821] = true, [6954] = true,
	[9149] = true, [2901] = true, [7005] = true,
}

-- GetItemMythicLevel may return "10@" instead of 10.
local function MythicLevel(itemId)
	if not GetItemMythicLevel then return 0 end
	return tonumber(tostring(GetItemMythicLevel(itemId)):match("%d+")) or 0
end

function filter:Filter(slotData)
	local itemId = slotData.itemId
	if not itemId then return end

	if TOOLS[itemId] then
		return "Tools", "Trade Goods"
	end

	if slotData.quality == 6 then
		if VANITY_ITEMS and VANITY_ITEMS[itemId] and VANITY_ITEMS[itemId].itemid > 0 then
			return "Ascension"
		end
		return "Vanity"
	end

	local flavor = GetItemFlavorText and GetItemFlavorText(itemId)
	local isGear = slotData.class == "Weapon" or slotData.class == "Armor"

	if isGear then
		if flavor and string.find(flavor, "@Worldforged", 1, true) then
			return "Worldforged", "Equipment"
		end
		if MythicLevel(itemId) > 0 then
			return "Mythic+", "Equipment"
		end
		if C_Appearance and slotData.subclass ~= "Thrown" then
			local appearanceID = C_Appearance.GetItemAppearanceID(itemId)
			if appearanceID and C_AppearanceCollection and not C_AppearanceCollection.IsAppearanceCollected(appearanceID) then
				return "Transmog", "Equipment"
			end
		end
	else
		if MythicLevel(itemId) > 0 then
			return "Mythic+", "Equipment"
		end
		if flavor then
			if string.find(flavor, "This Token", 1, true) then
				return "Tier Token", "Equipment"
			end
			if string.find(flavor, "@re", 1, true) then
				return "Mystic Enchants"
			end
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
