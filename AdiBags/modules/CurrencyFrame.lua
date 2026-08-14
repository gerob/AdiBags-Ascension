--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local ExpandCurrencyList = _G.ExpandCurrencyList
local format = _G.format
local GetArenaCurrency = _G.GetArenaCurrency
local GetCurrencyListInfo = _G.GetCurrencyListInfo
local GetCurrencyListSize = _G.GetCurrencyListSize
local GetHonorCurrency = _G.GetHonorCurrency
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local IsAddOnLoaded = _G.IsAddOnLoaded
local max = _G.max or _G.math.max
local pcall = _G.pcall
local tconcat = _G.table.concat
local tinsert = _G.tinsert
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local UnitFactionGroup = _G.UnitFactionGroup
local wipe = _G.wipe
--GLOBALS>

local mod = addon:NewModule('CurrencyFrame', 'AceEvent-3.0')
mod.uiName = L['Currency']
mod.uiDesc = L['Display character currency at bottom left of the backpack.']

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			shown = { ['*'] = false },
		},
	})
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	if self.widget then
		self.widget:Show()
	end
	self:RegisterEvent('KNOWN_CURRENCY_TYPES_UPDATE', "Update")
	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', "Update")
	self:RegisterEvent('HONOR_CURRENCY_UPDATE', "Update")
	if not self.hooked then
		if IsAddOnLoaded('Blizzard_TokenUI') then
			self:ADDON_LOADED('OnEnable', 'Blizzard_TokenUI')
		else
			self:RegisterEvent('ADDON_LOADED')
		end
	end
	self:Update()
end

function mod:ADDON_LOADED(_, name)
	if name ~= 'Blizzard_TokenUI' then return end
	self:UnregisterEvent('ADDON_LOADED')
	hooksecurefunc('TokenFrame_Update', function() self:Update() end)
	self.hooked = true
end

function mod:OnDisable()
	if self.widget then
		self.widget:Hide()
	end
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then return end
	local frame = bag:GetFrame()
	self.widget = CreateFrame("Frame", addonName.."CurrencyFrame", frame)
	self.fontstring = self.widget:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	self.fontstring:SetPoint("BOTTOMLEFT", 0, 1)
	self.fontstring:SetJustifyH("LEFT")
	--AddBottomWidget(widget, side, order, height, xOffset, yOffset)
	frame:AddBottomWidget(self.widget, "LEFT", 50, 13)
	self:Update()
end

local FALLBACK_ICON = [[Interface\Icons\INV_Misc_Coin_01]]
local HONOR_ICON = [[Interface\TargetingFrame\UI-PVP-]]
local ARENA_ICON = [[Interface\PVPFrame\PVP-ArenaPoints-Icon]]

local function SafeCurrencyListInfo(index)
	if not GetCurrencyListInfo then return end
	local ok, name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon = pcall(GetCurrencyListInfo, index)
	if ok then
		return name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon
	end
end

local function HonorIcon()
	local factionGroup = UnitFactionGroup and UnitFactionGroup("player")
	if factionGroup then
		return HONOR_ICON..factionGroup
	end
	return FALLBACK_ICON
end

local IterateCurrencies
do
	local function SafeCount(api)
		if not api then return end
		local ok, count = pcall(api)
		if ok then
			return tonumber(count) or 0
		end
	end

	local function iterator(collapse, index)
		if not index then return end
		repeat
			index = index + 1
			local listSize = GetCurrencyListSize and GetCurrencyListSize() or 0
			local name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon = SafeCurrencyListInfo(index)
			if name then
				if isHeader then
					if not isExpanded and ExpandCurrencyList then
						tinsert(collapse, 1, index)
						pcall(ExpandCurrencyList, index, true)
					end
				else
					if extraCurrencyType == 1 then
						icon = ARENA_ICON
					elseif extraCurrencyType == 2 then
						icon = HonorIcon()
					end
					return index, name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon
				end
			end
			if index == listSize + 1 then
				local honor = SafeCount(GetHonorCurrency)
				if honor then
					return index, "Honor Points", false, false, false, false, honor, 2, HonorIcon()
				end
			end
			if index == listSize + (GetHonorCurrency and 2 or 1) then
				local arena = SafeCount(GetArenaCurrency)
				if arena then
					return index, "Arena Points", false, false, false, false, arena, 1, ARENA_ICON
				end
			end
		until index > (GetCurrencyListSize and GetCurrencyListSize() or 0) + 2
		if ExpandCurrencyList then
			for _, collapsedIndex in ipairs(collapse) do
				pcall(ExpandCurrencyList, collapsedIndex, false)
			end
		end
	end

	local collapse = {}
	function IterateCurrencies()
		wipe(collapse)
		return iterator, collapse, 0
	end
end

local ICON_STRING_HONOR = "%d\124T%s:0:0:0:0:128:180:20:70:20:70\124t"
local ICON_STRING = "%d\124T%s:0:0:0:0:64:64:5:59:5:59\124t"

local values = {}
local updating

local function FormatCurrency(count, extraCurrencyType, icon)
	count = tonumber(count) or 0
	if type(icon) == "number" then
		icon = tostring(icon)
	elseif type(icon) ~= "string" or icon == "" then
		icon = FALLBACK_ICON
	end
	if extraCurrencyType == 2 then
		return format(ICON_STRING_HONOR, count, icon)
	end
	return format(ICON_STRING, count, icon)
end

function mod:Update()
	if not self.widget or updating then return end
	updating = true

	wipe(values)
	pcall(function()
		local shown = self.db.profile.shown
		for _, name, _, _, _, _, count, extraCurrencyType, icon in IterateCurrencies() do
			if name and shown[name] then
				tinsert(values, FormatCurrency(count, extraCurrencyType, icon))
			end
		end
	end)

	local widget, fs = self.widget, self.fontstring
	if #values > 0 then
		fs:SetText(tconcat(values, " "))
		widget:Show()
		widget:SetWidth(max(fs:GetStringWidth() or 0, 8))
		widget:SetHeight(max(fs:GetStringHeight() or 0, 13))
	else
		widget:Hide()
	end
	wipe(values)

	local parent = widget:GetParent()
	if parent and parent.RequestLayout then
		parent:RequestLayout()
	end

	updating = false
end


function mod:GetOptions()
	local values = {}
	local function GetValueList()
		wipe(values)
		pcall(function()
			for _, name in IterateCurrencies() do
				if name then
					values[name] = name
				end
			end
		end)
		return values
	end
	
	return {
		shown = {
			name = L['Currencies to show'],
			type = 'multiselect',
			order = 10,
			values = GetValueList,
			set = function(info, ...)
				info.handler:Set(info, ...)
				mod:Update()
			end
		},
	}, addon:GetOptionHandler(self)
end

