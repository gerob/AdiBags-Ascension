--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CANCEL = _G.CANCEL
local GetContainerItemID = _G.GetContainerItemID
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetItemInfo = _G.GetItemInfo
local ITEM_QUALITY_POOR = _G.ITEM_QUALITY_POOR
local ITEM_QUALITY_UNCOMMON = _G.ITEM_QUALITY_UNCOMMON
local KEYRING_CONTAINER = _G.KEYRING_CONTAINER
local pairs = _G.pairs
local select = _G.select
local setmetatable = _G.setmetatable
local StaticPopup_Hide = _G.StaticPopup_Hide
local StaticPopup_Show = _G.StaticPopup_Show
local StaticPopupDialogs = _G.StaticPopupDialogs
local tonumber = _G.tonumber
local tinsert = _G.tinsert
local type = _G.type
local UseContainerItem = _G.UseContainerItem
local wipe = _G.wipe
local YES = _G.YES
--GLOBALS>

local JUNK = addon.BI['Junk']

local mod = addon:RegisterFilter("Junk", 85, "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
mod.uiName = JUNK
mod.uiDesc = L['Put items of poor quality or labeled as junk in the "Junk" section.']

local DEFAULTS = {
	profile = {
		sources = { ['*'] = true },
		include = {},
		exclude = {
			[6948] = true,
		},
		sellWithAscension = true,
		showEmptySection = true,
	},
}

local prefs

local cache = setmetatable({}, { __index = function(t, itemId)
	local isJunk = mod:CheckItem(itemId)
	t[itemId] = isJunk
	return isJunk
end})

local SELL_CONFIRM_THRESHOLD = 10
local CONFIRM_SELL_JUNK = "ADIBAGS_CONFIRM_SELL_JUNK"

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, DEFAULTS)
	prefs = self.db.profile
	self.pendingSellSlots = nil

	StaticPopupDialogs[CONFIRM_SELL_JUNK] = {
		text = L["AdiBags is about to sell %d junk items.\n\nWarning: recovering items through Ascension is more expensive than using the merchant buyback."],
		button1 = YES,
		button2 = CANCEL,
		OnAccept = function()
			mod:SellPendingJunk()
		end,
		OnCancel = function()
			mod.pendingSellSlots = nil
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		preferredIndex = 3,
	}
end

function mod:OnEnable()
	prefs = self.db.profile
	self:RegisterMessage('AdiBags_OverrideFilter')
	self:Hook(addon, 'IsJunk')
	self:RegisterEvent('MERCHANT_SHOW')
	self:RegisterEvent('MERCHANT_CLOSED')
	self:HookAscensionSellCheck()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	self:EnsureAllJunkDropTargets()
	wipe(cache)
end

function mod:OnDisable()
	self:CancelAllTimers()
	self:ClearPendingSell()
	self:ClearAllJunkDropTargets()
end

--------------------------------------------------------------------------------
-- Empty Junk section drop target
--------------------------------------------------------------------------------

function mod:EnsureJunkDropTarget(container)
	if not container or not container.GetSection then return end
	if not prefs.showEmptySection then
		local key = addon:BuildSectionKey(JUNK, JUNK)
		local section = container.sections and container.sections[key]
		if section and section.keepWhenEmpty then
			section.keepWhenEmpty = nil
			container.forceLayout = true
		end
		return
	end
	local section = container:GetSection(JUNK, JUNK)
	if not section.keepWhenEmpty then
		section.keepWhenEmpty = true
		container.forceLayout = true
	end
end

function mod:EnsureAllJunkDropTargets()
	for _, bag in addon:IterateBags() do
		if bag:HasFrame() then
			self:EnsureJunkDropTarget(bag:GetFrame())
		end
	end
	self:SendMessage('AdiBags_LayoutChanged')
end

function mod:ClearAllJunkDropTargets()
	for _, bag in addon:IterateBags() do
		if bag:HasFrame() then
			local container = bag:GetFrame()
			local key = addon:BuildSectionKey(JUNK, JUNK)
			local section = container.sections and container.sections[key]
			if section then
				section.keepWhenEmpty = nil
			end
		end
	end
	self:SendMessage('AdiBags_LayoutChanged')
end

function mod:OnBagFrameCreated(bag)
	if prefs.showEmptySection then
		self:EnsureJunkDropTarget(bag:GetFrame())
	end
end

--------------------------------------------------------------------------------
-- Ascension merchant Auto Sell Junk extension
--------------------------------------------------------------------------------

local function IsAscensionAutoSellChecked()
	local check = _G.MerchantFrameSellJunkFrameAutoSellCheck
	return check and check.GetChecked and check:GetChecked()
end

function mod:HookAscensionSellCheck()
	local check = _G.MerchantFrameSellJunkFrameAutoSellCheck
	if not check or check.__AdiBagsJunkHooked then return end
	check:HookScript('OnClick', function()
		if mod:IsEnabled() then
			mod:ScheduleTimer('MaybeSellJunk', 0.1)
		end
	end)
	check.__AdiBagsJunkHooked = true
end

function mod:MERCHANT_SHOW()
	self:HookAscensionSellCheck()
	self:ScheduleTimer('MaybeSellJunk', 0.2)
end

function mod:MERCHANT_CLOSED()
	self:CancelAllTimers()
	self:ClearPendingSell()
end

function mod:ClearPendingSell()
	self.pendingSellSlots = nil
	StaticPopup_Hide(CONFIRM_SELL_JUNK)
end

-- Drag-to-Junk sets a FilterOverride + include entry. Manual Include list
-- entries have include only. Clear the drag mark after sell so buyback is
-- normal; leave purposeful include-list items alone so they keep auto-selling.
local function ClearJunkMark(itemId)
	local filterOverride = addon:GetModule('FilterOverride', true)
	if not filterOverride then return false end
	local override = filterOverride.db.profile.overrides[itemId]
	if not override then return false end
	local section = override:match("^(.-)#") or override
	if section ~= JUNK then return false end
	filterOverride.db.profile.overrides[itemId] = nil
	prefs.include[itemId] = nil
	return true
end

function mod:CollectSellableJunk()
	local slots = {}
	for bag in pairs(addon.BAG_IDS.BAGS) do
		if bag ~= KEYRING_CONTAINER then
			for slot = 1, GetContainerNumSlots(bag) do
				local itemId = GetContainerItemID(bag, slot)
				if itemId and cache[itemId] then
					local _, _, quality, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(itemId)
					-- Leave greys to Ascension; sell marked / non-poor junk only.
					if quality and quality > ITEM_QUALITY_POOR and vendorPrice and vendorPrice > 0 then
						tinsert(slots, { bag = bag, slot = slot, itemId = itemId })
					end
				end
			end
		end
	end
	return slots
end

function mod:SellJunkSlots(slots)
	if not slots then return end
	local merchant = _G.MerchantFrame
	if not merchant or not merchant:IsShown() then return end

	local cleared = false
	for i = 1, #slots do
		local entry = slots[i]
		local itemId = GetContainerItemID(entry.bag, entry.slot)
		if itemId and itemId == entry.itemId then
			UseContainerItem(entry.bag, entry.slot)
			if ClearJunkMark(itemId) then
				cleared = true
			end
		end
	end
	if cleared then
		wipe(cache)
		self:SendMessage('AdiBags_FiltersChanged')
		local acr = LibStub('AceConfigRegistry-3.0', true)
		if acr then
			acr:NotifyChange(addonName)
		end
	end
end

function mod:SellPendingJunk()
	local slots = self.pendingSellSlots
	self.pendingSellSlots = nil
	self:SellJunkSlots(slots)
end

function mod:MaybeSellJunk()
	if not prefs.sellWithAscension then return end
	if not IsAscensionAutoSellChecked() then return end
	local merchant = _G.MerchantFrame
	if not merchant or not merchant:IsShown() then return end

	local slots = self:CollectSellableJunk()
	local count = #slots
	if count == 0 then return end

	if count > SELL_CONFIRM_THRESHOLD then
		self.pendingSellSlots = slots
		StaticPopup_Show(CONFIRM_SELL_JUNK, count)
	else
		self:SellJunkSlots(slots)
	end
end

function mod:BaseCheckItem(itemId, force)
	local _, _, quality, _, _, class, subclass = GetItemInfo(itemId)
	if ((force or prefs.sources.lowQuality) and quality == ITEM_QUALITY_POOR)
		or ((force or prefs.sources.junkCategory) and quality and quality < ITEM_QUALITY_UNCOMMON and (class == JUNK or subclass == JUNK)) then
		return true
	end
	return false
end

function mod:ExtendedCheckItem(itemId, force)
	return false
end

function mod:CheckItem(itemId)
	if not itemId then
		return false
	elseif not GetItemInfo(itemId) then
		return nil -- Should cause to rescan later
	elseif prefs.exclude[itemId] then
		return false
	elseif prefs.include[itemId] then
		return true
	elseif self:BaseCheckItem(itemId) then
		return true
	elseif self:ExtendedCheckItem(itemId) then
		return true
	end
	return false
end

function mod:IsJunk(_, itemId)
	return tonumber(itemId) and cache[tonumber(itemId)] or false
end

function mod:Filter(slotData)
	return cache[slotData.itemId] and JUNK or nil
end

function mod:AdiBags_OverrideFilter(event, section, category, ...)
	local changed = false
	local include, exclude = prefs.include, prefs.exclude
	for i = 1, select('#', ...) do
		local id = select(i, ...)
		local incFlag, exclFlag
		if section == JUNK then
			incFlag = not self:BaseCheckItem(id, true) or nil
		else
			exclFlag = (self:BaseCheckItem(id, true) or self:ExtendedCheckItem(id, true)) and true or nil
		end
		if include[id] ~= incFlag or exclude[id] ~= exclFlag then
			include[id], exclude[id] = incFlag, exclFlag
			changed = true
		end
	end
	if changed then
		self:Update()
	end
end

function mod:Update()
	wipe(cache)
	self:EnsureAllJunkDropTargets()
	self:SendMessage('AdiBags_FiltersChanged')
	local acr = LibStub('AceConfigRegistry-3.0', true)
	if acr then
		acr:NotifyChange(addonName)
	end
end

-- Options

local sourceList = {
	lowQuality = L['Low quality items'],
	junkCategory = L['Junk category'],
}
function mod:GetOptions()
	local handler = addon:GetOptionHandler(self)

	local Set = handler.Set
	function handler.Set(...)
		Set(...)
		return mod:Update()
	end

	function handler:ListItems(info)
		return prefs[info[#info]]
	end

	function handler:SetItem(info, key, value)
		return self:Set(info, key, value and true or nil)
	end

	local function True() return true end

	return {
		sources = {
			type = 'multiselect',
			name = L['Included categories'],
			values = sourceList,
			order = 10,
		},
		sellWithAscension = {
			type = 'toggle',
			name = L['Sell AdiBags Junk with Ascension auto-sell'],
			desc = L['When Ascension\'s merchant Auto Sell Junk checkbox is enabled, also sell items AdiBags considers junk (including items dragged into the Junk section). Grey items remain handled by Ascension.'],
			order = 20,
		},
		showEmptySection = {
			type = 'toggle',
			name = L['Show empty Junk section'],
			desc = L['Keep the Junk section visible even when it has no items, so you can drag items onto it to mark them as junk.'],
			order = 30,
		},
		include = {
			type = 'multiselect',
			dialogControl = 'ItemList',
			name = L['Include list'],
			desc = L['Items in this list are always considered as junk. Click an item to remove it from the list.'],
			order = 40,
			values = 'ListItems',
			get = True,
			set = 'SetItem',
		},
		exclude = {
			type = 'multiselect',
			dialogControl = 'ItemList',
			name = L['Exclude list'],
			desc = L['Items in this list are never considered as junk. Click an item to remove it from the list.'],
			order = 50,
			values = 'ListItems',
			get = True,
			set = 'SetItem',
		},
	}, handler
end

-- Third-party addon support

local Scrap = _G.Scrap
local BrainDead = LibStub('AceAddon-3.0'):GetAddon('BrainDead', true)

if Scrap and type(Scrap.IsJunk) == "function" then
	-- Scrap support

	function mod:ExtendedCheckItem(itemId, force)
		return (force or prefs.sources.Scrap) and Scrap:IsJunk(itemId)
	end

	Scrap:HookScript('OnReceiveDrag', function()
		if prefs.sources.Scrap then
			wipe(cache)
			addon:SendMessage("AdiBags_FiltersChanged")
		end
	end)

	sourceList.Scrap = "Scrap"

elseif BrainDead then
	-- BrainDead support

	local SellJunk = BrainDead:GetModule('SellJunk')

	function mod:ExtendedCheckItem(itemId, force)
		return (force or prefs.sources.BrainDead) and SellJunk.db.profile.items[itemId]
	end

	sourceList.BrainDead = "BrainDead"
end

