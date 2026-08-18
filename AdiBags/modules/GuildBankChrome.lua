--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CanEditGuildTabInfo = _G.CanEditGuildTabInfo
local CanWithdrawGuildBankMoney = _G.CanWithdrawGuildBankMoney
local CreateFrame = _G.CreateFrame
local DepositGuildBankMoney = _G.DepositGuildBankMoney
local FONT_COLOR_CODE_CLOSE = _G.FONT_COLOR_CODE_CLOSE or "|r"
local format = _G.format
local GameTooltip = _G.GameTooltip
local GetCoinTextureString = _G.GetCoinTextureString
local GetCurrentGuildBankTab = _G.GetCurrentGuildBankTab
local GetDenominationsFromCopper = _G.GetDenominationsFromCopper
local GetGuildBankMoney = _G.GetGuildBankMoney
local GetGuildBankMoneyTransaction = _G.GetGuildBankMoneyTransaction
local GetGuildBankTabInfo = _G.GetGuildBankTabInfo
local GetGuildBankText = _G.GetGuildBankText
local GetGuildBankTransaction = _G.GetGuildBankTransaction
local GetGuildBankWithdrawMoney = _G.GetGuildBankWithdrawMoney
local GetNumGuildBankMoneyTransactions = _G.GetNumGuildBankMoneyTransactions
local GetNumGuildBankTransactions = _G.GetNumGuildBankTransactions
local GREEN_FONT_COLOR_CODE = _G.GREEN_FONT_COLOR_CODE or "|cff1eff00"
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local max = _G.max
local min = _G.min
local MoneyFrame_SetType = _G.MoneyFrame_SetType
local MoneyFrame_Update = _G.MoneyFrame_Update
local NORMAL_FONT_COLOR_CODE = _G.NORMAL_FONT_COLOR_CODE or "|cffffd200"
local PlaySound = _G.PlaySound
local QueryGuildBankLog = _G.QueryGuildBankLog
local QueryGuildBankText = _G.QueryGuildBankText
local RecentTimeDate = _G.RecentTimeDate
local RED_FONT_COLOR_CODE = _G.RED_FONT_COLOR_CODE or "|cffff2020"
local select = _G.select
local SetDesaturation = _G.SetDesaturation
local SetGuildBankText = _G.SetGuildBankText
local SetItemRef = _G.SetItemRef
local StaticPopup_Show = _G.StaticPopup_Show
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local UNKNOWN = _G.UNKNOWN or "Unknown"
local WithdrawGuildBankMoney = _G.WithdrawGuildBankMoney
--GLOBALS>

local FOOTER_HEIGHT = 52
local TAB_HEIGHT = 24
local CHROME_HEIGHT = FOOTER_HEIGHT + TAB_HEIGHT
local MIN_WIDTH = 440
local MAX_GUILDBANK_TABS = _G.MAX_GUILDBANK_TABS or 6

local VIEW_BANK, VIEW_LOG, VIEW_MONEY, VIEW_INFO = "bank", "log", "moneylog", "info"

local mod = addon:NewModule('GuildBankChrome', 'AceEvent-3.0')
mod.uiName = L['Guild bank']
mod.uiDesc = L['Show gold, logs, and info tabs on the guild bank.']

local function G(key, fallback)
	local value = _G[key]
	if type(value) == "string" then
		return value
	end
	return fallback
end

local function CurrentTab()
	return GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1
end

local function TabInfo(tab)
	if not GetGuildBankTabInfo then return end
	return GetGuildBankTabInfo(tab or CurrentTab())
end

local function AccessSuffix()
	local _, _, _, canDeposit, numWithdrawals = TabInfo()
	local label
	if not canDeposit and numWithdrawals == 0 then
		label = G("GUILDBANK_TAB_LOCKED", "Locked")
		return RED_FONT_COLOR_CODE.."("..label..")"..FONT_COLOR_CODE_CLOSE
	elseif not canDeposit then
		label = G("GUILDBANK_TAB_WITHDRAW_ONLY", "Withdraw Only")
		return RED_FONT_COLOR_CODE.."("..label..")"..FONT_COLOR_CODE_CLOSE
	elseif numWithdrawals == 0 then
		label = G("GUILDBANK_TAB_DEPOSIT_ONLY", "Deposit Only")
		return RED_FONT_COLOR_CODE.."("..label..")"..FONT_COLOR_CODE_CLOSE
	end
	label = G("GUILDBANK_TAB_FULL_ACCESS", L["Full Access"])
	return GREEN_FONT_COLOR_CODE.."("..label..")"..FONT_COLOR_CODE_CLOSE
end

local function LogTime(year, month, day, hour)
	local ago
	if RecentTimeDate then
		ago = RecentTimeDate(year, month, day, hour)
	else
		ago = format("%dd %dh", day or 0, hour or 0)
	end
	local wrap = G("GUILD_BANK_LOG_TIME", "( %s )")
	local prepend = _G.GUILD_BANK_LOG_TIME_PREPEND or "|cff009999 "
	return prepend..format(wrap, ago)
end

local function CoinString(amount)
	amount = tonumber(amount) or 0
	if GetDenominationsFromCopper then
		return GetDenominationsFromCopper(amount)
	elseif GetCoinTextureString then
		return GetCoinTextureString(amount)
	end
	return tostring(amount)
end

function mod:IsGuildKind()
	return addon.guildBankKind == addon.GUILD_BANK_KIND_GUILD
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	self:RegisterEvent('GUILDBANK_UPDATE_MONEY', 'UpdateMoney')
	self:RegisterEvent('GUILDBANK_UPDATE_WITHDRAWMONEY', 'UpdateMoney')
	self:RegisterEvent('GUILDBANK_UPDATE_TABS', 'OnTabsChanged')
	self:RegisterEvent('GUILDBANKBAGSLOTS_CHANGED', 'OnTabsChanged')
	self:RegisterEvent('GUILDBANKLOG_UPDATE', 'OnLogUpdate')
	self:RegisterEvent('GUILDBANK_UPDATE_TEXT', 'OnInfoText')
	self:RegisterEvent('GUILDBANK_TEXT_CHANGED', 'OnInfoTextChanged')
	self:RegisterEvent('PLAYER_MONEY', 'UpdateMoney')
	if self.container then
		self:Refresh()
	end
end

function mod:OnDisable()
	self:SetView(VIEW_BANK)
	if self.chrome then
		self.chrome:Hide()
	end
	if self.overlay then
		self.overlay:Hide()
	end
	self:ApplyItemTabLock(false)
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "PersonalBank" then return end
	local container = bag:GetFrame()
	self.container = container
	self.view = VIEW_BANK
	self:CreateChrome(container)
	self:CreateOverlay(container)
	self:HookContainer(container)
	self:Refresh()
end

function mod:HookContainer(container)
	if self.hooked then return end
	self.hooked = true

	local origMinWidth = container.GetContentMinWidth
	function container:GetContentMinWidth()
		local width = origMinWidth(self)
		if mod.chrome and mod.chrome:IsShown() then
			return max(width, MIN_WIDTH)
		end
		return width
	end

	local origOnLayout = container.OnLayout
	function container:OnLayout()
		origOnLayout(self)
		if mod.chrome and mod.chrome:IsShown() then
			self:SetHeight(self:GetHeight() + CHROME_HEIGHT)
		end
	end

	hooksecurefunc(container, 'OnPersonalBankTabClick', function()
		mod:OnItemTabChanged()
	end)
	hooksecurefunc(container, 'UpdatePersonalBankTabs', function()
		mod:ApplyItemTabLock()
	end)
	container:HookScript('OnShow', function()
		mod:Refresh()
	end)
	container:HookScript('OnHide', function()
		mod:SetView(VIEW_BANK)
	end)
end

--------------------------------------------------------------------------------
-- Chrome: footer + bottom tabs
--------------------------------------------------------------------------------

function mod:CreateChrome(container)
	local chrome = CreateFrame("Frame", addonName.."GuildBankChrome", container)
	chrome:SetHeight(CHROME_HEIGHT)
	chrome:SetPoint("BOTTOMLEFT", 4, 2)
	chrome:SetPoint("BOTTOMRIGHT", -4, 2)
	self.chrome = chrome

	local footer = CreateFrame("Frame", nil, chrome)
	footer:SetHeight(FOOTER_HEIGHT)
	footer:SetPoint("TOPLEFT")
	footer:SetPoint("TOPRIGHT")
	self.footer = footer

	local limit = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	limit:SetPoint("TOPLEFT", 4, -2)
	limit:SetPoint("RIGHT", -180, 0)
	limit:SetJustifyH("LEFT")
	self.limitLabel = limit

	local deposit = CreateFrame("Button", addonName.."GuildBankDeposit", footer, "UIPanelButtonTemplate")
	deposit:SetSize(80, 22)
	deposit:SetPoint("TOPRIGHT", 0, -1)
	deposit:SetText(G("DEPOSIT", L["Deposit"]))
	deposit:SetScript('OnClick', function()
		mod:OnDeposit()
	end)
	self.depositButton = deposit

	local withdraw = CreateFrame("Button", addonName.."GuildBankWithdraw", footer, "UIPanelButtonTemplate")
	withdraw:SetSize(80, 22)
	withdraw:SetPoint("RIGHT", deposit, "LEFT", -4, 0)
	withdraw:SetText(G("WITHDRAW", L["Withdraw"]))
	withdraw:SetScript('OnClick', function()
		mod:OnWithdraw()
	end)
	self.withdrawButton = withdraw

	local avail = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	avail:SetPoint("BOTTOMLEFT", 4, 4)
	avail:SetText(G("GUILDBANK_AVAILABLE_MONEY", L["Available Amount:"]))
	self.availableLabel = avail

	local unlimited = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	unlimited:SetPoint("LEFT", avail, "RIGHT", 4, 0)
	unlimited:SetText(G("UNLIMITED", L["Unlimited"]))
	unlimited:Hide()
	self.unlimitedLabel = unlimited

	local withdrawMoney = CreateFrame("Frame", addonName.."GuildBankWithdrawMoney", footer, "SmallMoneyFrameTemplate")
	withdrawMoney:SetPoint("LEFT", avail, "RIGHT", 4, 0)
	withdrawMoney:SetHeight(19)
	if MoneyFrame_SetType then
		MoneyFrame_SetType(withdrawMoney, "STATIC")
	end
	self.withdrawMoney = withdrawMoney

	local guildMoney = CreateFrame("Frame", addonName.."GuildBankMoney", footer, "SmallMoneyFrameTemplate")
	guildMoney:SetPoint("BOTTOMRIGHT", 8, 2)
	guildMoney:SetHeight(19)
	if MoneyFrame_SetType then
		MoneyFrame_SetType(guildMoney, "GUILDBANK")
	end
	self.guildMoney = guildMoney

	local tabBar = CreateFrame("Frame", nil, chrome)
	tabBar:SetHeight(TAB_HEIGHT)
	tabBar:SetPoint("BOTTOMLEFT")
	tabBar:SetPoint("BOTTOMRIGHT")
	self.tabBar = tabBar

	local labels = {
		{ VIEW_BANK, G("GUILD_BANK", L["GuildBank"]) },
		{ VIEW_LOG, G("GUILD_BANK_LOG", L["Log"]) },
		{ VIEW_MONEY, G("GUILD_BANK_MONEY_LOG", L["Money Log"]) },
		{ VIEW_INFO, G("GUILD_BANK_TAB_INFO", L["Info"]) },
	}
	self.tabs = {}
	local prev
	for i, info in ipairs(labels) do
		local tab = CreateFrame("Button", addonName.."GuildBankTab"..i, tabBar, "UIPanelButtonTemplate")
		tab:SetHeight(22)
		tab:SetWidth(i == 1 and 90 or 80)
		if prev then
			tab:SetPoint("LEFT", prev, "RIGHT", 2, 0)
		else
			tab:SetPoint("BOTTOMLEFT", 0, 0)
		end
		tab:SetText(info[2])
		tab.view = info[1]
		tab:SetScript('OnClick', function(button)
			mod:SetView(button.view)
			PlaySound("igCharacterInfoTab")
		end)
		self.tabs[i] = tab
		prev = tab
	end
	chrome:Hide()
end

function mod:OnDeposit()
	if StaticPopup_Show and _G.StaticPopupDialogs and _G.StaticPopupDialogs["GUILDBANK_DEPOSIT"] then
		StaticPopup_Show("GUILDBANK_DEPOSIT")
	end
end

function mod:OnWithdraw()
	if StaticPopup_Show and _G.StaticPopupDialogs and _G.StaticPopupDialogs["GUILDBANK_WITHDRAW"] then
		StaticPopup_Show("GUILDBANK_WITHDRAW")
	end
end

--------------------------------------------------------------------------------
-- Overlay: log / money log / info
--------------------------------------------------------------------------------

function mod:CreateOverlay(container)
	local overlay = CreateFrame("Frame", addonName.."GuildBankOverlay", container)
	overlay:EnableMouse(true)
	overlay:SetBackdrop({ bgFile = [[Interface\Tooltips\UI-Tooltip-Background]] })
	overlay:SetBackdropColor(0, 0, 0, 0.92)
	overlay:Hide()
	self.overlay = overlay

	local header = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("TOP", 0, -2)
	self.header = header

	local headerBg = overlay:CreateTexture(nil, "BACKGROUND")
	headerBg:SetTexture(0, 0, 0, 0.6)
	headerBg:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
	headerBg:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
	headerBg:SetHeight(18)
	self.headerBg = headerBg

	local logFrame = CreateFrame("ScrollingMessageFrame", addonName.."GuildBankLog", overlay)
	logFrame:SetPoint("TOPLEFT", 6, -20)
	logFrame:SetPoint("BOTTOMRIGHT", -22, 4)
	logFrame:SetFontObject(_G.GameFontHighlightSmall)
	logFrame:SetJustifyH("LEFT")
	logFrame:SetFading(false)
	logFrame:SetMaxLines(256)
	if logFrame.SetHyperlinksEnabled then
		logFrame:SetHyperlinksEnabled(true)
	end
	logFrame:EnableMouseWheel(true)
	logFrame:SetScript('OnMouseWheel', function(frame, delta)
		if delta > 0 then
			frame:ScrollUp()
		else
			frame:ScrollDown()
		end
	end)
	logFrame:SetScript('OnHyperlinkClick', function(_, link, text, button)
		if SetItemRef then
			SetItemRef(link, text, button)
		end
	end)
	logFrame:SetScript('OnHyperlinkEnter', function(frame, link)
		GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end)
	logFrame:SetScript('OnHyperlinkLeave', function()
		GameTooltip:Hide()
	end)
	self.logFrame = logFrame

	local infoScroll = CreateFrame("ScrollFrame", addonName.."GuildBankInfoScroll", overlay, "UIPanelScrollFrameTemplate")
	infoScroll:SetPoint("TOPLEFT", 6, -20)
	infoScroll:SetPoint("BOTTOMRIGHT", -30, 28)
	infoScroll:Hide()
	self.infoScroll = infoScroll

	local edit = CreateFrame("EditBox", addonName.."GuildBankInfoEdit", infoScroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(_G.ChatFontNormal)
	edit:SetMaxLetters(500)
	edit:SetWidth(200)
	edit:SetHeight(800)
	edit:SetScript('OnEscapePressed', function(box)
		box:ClearFocus()
	end)
	edit:SetScript('OnTextChanged', function()
		mod:UpdateSaveButton()
	end)
	infoScroll:SetScrollChild(edit)
	self.infoEdit = edit

	local save = CreateFrame("Button", addonName.."GuildBankInfoSave", overlay, "UIPanelButtonTemplate")
	save:SetSize(80, 22)
	save:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -4, 4)
	save:SetText(G("SAVE", L["Save"]))
	save:SetScript('OnClick', function()
		mod:SaveInfo()
	end)
	save:Hide()
	self.saveButton = save
end

function mod:LayoutOverlay()
	local container = self.container
	local overlay = self.overlay
	if not container or not overlay then return end
	overlay:ClearAllPoints()
	overlay:SetPoint("TOPLEFT", container.Content, "TOPLEFT", 0, 0)
	overlay:SetPoint("BOTTOMRIGHT", container.Content, "BOTTOMRIGHT", 0, 0)
	overlay:SetFrameLevel(container.Content:GetFrameLevel() + 20)
	if self.infoEdit then
		self.infoEdit:SetWidth(max((overlay:GetWidth() or 200) - 36, 100))
	end
end

--------------------------------------------------------------------------------
-- View switching
--------------------------------------------------------------------------------

function mod:SetView(view)
	self.view = view or VIEW_BANK
	self:UpdateTabs()
	self:UpdateHeader()
	self:UpdateLimit()
	self:ApplyItemTabLock()

	local overlay = self.overlay
	if not overlay then return end

	if self.view == VIEW_BANK or not self:IsGuildKind() then
		overlay:Hide()
		return
	end

	self:LayoutOverlay()
	overlay:Show()

	local isInfo = self.view == VIEW_INFO
	if isInfo then
		self.logFrame:Hide()
		self.infoScroll:Show()
		self.saveButton:Show()
		self:QueryInfo()
	else
		self.logFrame:Show()
		self.infoScroll:Hide()
		self.saveButton:Hide()
		self:QueryLog()
	end
	self:UpdateSaveButton()
end

function mod:UpdateTabs()
	if not self.tabs then return end
	for _, tab in ipairs(self.tabs) do
		if tab.view == self.view then
			tab:Disable()
		else
			tab:Enable()
		end
	end
end

function mod:Refresh()
	if not self.chrome or not self.container then return end
	if addon.DetectGuildBankKind then
		addon:DetectGuildBankKind()
	end
	if self:IsGuildKind() and self.container:IsShown() then
		self.chrome:Show()
		self:UpdateMoney()
		self:SetView(self.view or VIEW_BANK)
		if self.container.RequestLayout then
			self.container:RequestLayout()
		end
	else
		self.chrome:Hide()
		if self.overlay then
			self.overlay:Hide()
		end
		self:ApplyItemTabLock(false)
		if self.container.RequestLayout then
			self.container:RequestLayout()
		end
	end
end

function mod:OnTabsChanged()
	if addon.DetectGuildBankKind then
		addon:DetectGuildBankKind()
	end
	local shouldShow = self:IsGuildKind() and self.container and self.container:IsShown()
	local isShown = self.chrome and self.chrome:IsShown()
	if shouldShow ~= isShown then
		self:Refresh()
		return
	end
	if not isShown then return end
	self:UpdateLimit()
	self:UpdateHeader()
	self:UpdateMoney()
	self:ApplyItemTabLock()
end

function mod:OnItemTabChanged()
	if not self:IsGuildKind() then return end
	self:UpdateLimit()
	self:UpdateHeader()
	if self.view == VIEW_LOG then
		self:QueryLog()
	elseif self.view == VIEW_INFO then
		self:QueryInfo()
	end
end

--------------------------------------------------------------------------------
-- Footer
--------------------------------------------------------------------------------

function mod:UpdateLimit()
	if not self.limitLabel then return end
	local showLimit = self.view == VIEW_BANK or self.view == VIEW_LOG
	if not showLimit then
		self.limitLabel:Hide()
		return
	end
	local tab = CurrentTab()
	local name, _, _, _, _, remaining = TabInfo(tab)
	if not name or name == "" then
		name = format(G("GUILDBANK_TAB_NUMBER", L["Tab %d"]), tab)
	end
	local stacks
	if not remaining then
		stacks = G("NONE", "None")
	elseif remaining > 0 then
		stacks = format(G("STACKS", L["%d Stacks"]), remaining)
	elseif remaining == 0 then
		stacks = G("NONE", "None")
	else
		stacks = G("UNLIMITED", L["Unlimited"])
	end
	self.limitLabel:SetText(format(G("GUILDBANK_REMAINING_MONEY", L["Remaining Daily Withdrawals for %s: %s"]), name, stacks))
	self.limitLabel:Show()
end

function mod:UpdateMoney()
	if not self.guildMoney or not self.chrome or not self.chrome:IsShown() then return end

	if self.guildMoney.moneyType == "GUILDBANK" then
		MoneyFrame_Update(self.guildMoney:GetName(), GetGuildBankMoney and GetGuildBankMoney() or 0)
	else
		MoneyFrame_Update(self.guildMoney:GetName(), GetGuildBankMoney and GetGuildBankMoney() or 0)
	end

	local withdrawLimit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
	local canWithdraw = not CanWithdrawGuildBankMoney or CanWithdrawGuildBankMoney()
	if withdrawLimit < 0 then
		self.unlimitedLabel:Show()
		self.withdrawMoney:Hide()
		if canWithdraw then
			self.withdrawButton:Enable()
		else
			self.withdrawButton:Disable()
		end
	else
		self.unlimitedLabel:Hide()
		self.withdrawMoney:Show()
		local amount = GetGuildBankMoney and GetGuildBankMoney() or 0
		if not canWithdraw then
			amount = 0
		end
		MoneyFrame_Update(self.withdrawMoney:GetName(), min(withdrawLimit, amount))
		if withdrawLimit == 0 or not canWithdraw then
			self.withdrawButton:Disable()
		else
			self.withdrawButton:Enable()
		end
	end
end

--------------------------------------------------------------------------------
-- Item tab lock (Money Log)
--------------------------------------------------------------------------------

function mod:ApplyItemTabLock(force)
	local container = self.container
	if not container or not container.personalBankTabs then return end
	local lock = force
	if lock == nil then
		lock = self:IsGuildKind() and self.view == VIEW_MONEY and self.chrome and self.chrome:IsShown()
	end
	for _, btn in ipairs(container.personalBankTabs) do
		if btn:IsShown() then
			local tex = btn:GetNormalTexture()
			if tex then
				if SetDesaturation then
					SetDesaturation(tex, lock and 1 or nil)
				elseif tex.SetDesaturated then
					tex:SetDesaturated(not not lock)
				end
			end
			btn:SetAlpha(lock and 0.4 or 1)
			if lock then
				btn:Disable()
			else
				btn:Enable()
			end
		end
	end
	local buy = container.PersonalBankBuyTab
	if buy and buy:IsShown() then
		buy:SetAlpha(lock and 0.4 or 1)
		if lock then
			buy:Disable()
		else
			buy:Enable()
		end
	end
end

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

function mod:QueryLog()
	if self.view == VIEW_MONEY then
		if QueryGuildBankLog then
			QueryGuildBankLog(MAX_GUILDBANK_TABS + 1)
		end
		self:FillMoneyLog()
	elseif self.view == VIEW_LOG then
		if QueryGuildBankLog then
			QueryGuildBankLog(CurrentTab())
		end
		self:FillItemLog()
	end
end

function mod:OnLogUpdate()
	if not self.overlay or not self.overlay:IsShown() then return end
	if self.view == VIEW_LOG then
		self:FillItemLog()
	elseif self.view == VIEW_MONEY then
		self:FillMoneyLog()
	end
end

function mod:FillItemLog()
	local frame = self.logFrame
	if not frame then return end
	if frame.Clear then
		frame:Clear()
	end
	local tab = CurrentTab()
	local num = GetNumGuildBankTransactions and GetNumGuildBankTransactions(tab) or 0
	for i = 1, num do
		local txType, name, itemLink, count, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, i)
		name = NORMAL_FONT_COLOR_CODE..(name or UNKNOWN)..FONT_COLOR_CODE_CLOSE
		local msg
		if txType == "deposit" then
			msg = format(G("GUILDBANK_DEPOSIT_FORMAT", "%s deposited %s"), name, itemLink or "")
			if count and count > 1 then
				msg = msg..format(G("GUILDBANK_LOG_QUANTITY", " x %d"), count)
			end
		elseif txType == "withdraw" then
			msg = format(G("GUILDBANK_WITHDRAW_FORMAT", "%s |cffff2020withdrew|r %s"), name, itemLink or "")
			if count and count > 1 then
				msg = msg..format(G("GUILDBANK_LOG_QUANTITY", " x %d"), count)
			end
		elseif txType == "move" then
			local fromName = tab1 and select(1, TabInfo(tab1)) or tostring(tab1)
			local toName = tab2 and select(1, TabInfo(tab2)) or tostring(tab2)
			msg = format(G("GUILDBANK_MOVE_FORMAT", "%s moved %sx%d from %s to %s"), name, itemLink or "", count or 1, fromName or "", toName or "")
		end
		if msg then
			frame:AddMessage(msg..LogTime(year, month, day, hour))
		end
	end
end

function mod:FillMoneyLog()
	local frame = self.logFrame
	if not frame then return end
	if frame.Clear then
		frame:Clear()
	end
	local num = GetNumGuildBankMoneyTransactions and GetNumGuildBankMoneyTransactions() or 0
	for i = 1, num do
		local txType, name, amount, year, month, day, hour = GetGuildBankMoneyTransaction(i)
		name = NORMAL_FONT_COLOR_CODE..(name or UNKNOWN)..FONT_COLOR_CODE_CLOSE
		local money = CoinString(amount)
		local msg
		if txType == "deposit" then
			msg = format(G("GUILDBANK_DEPOSIT_MONEY_FORMAT", "%s deposited %s"), name, money)
		elseif txType == "withdraw" then
			msg = format(G("GUILDBANK_WITHDRAW_MONEY_FORMAT", "%s |cffff2020withdrew|r %s"), name, money)
		elseif txType == "repair" then
			msg = format(G("GUILDBANK_REPAIR_MONEY_FORMAT", "%s withdrew %s for repairs"), name, money)
		elseif txType == "withdrawForTab" then
			msg = format(G("GUILDBANK_WITHDRAWFORTAB_MONEY_FORMAT", "%s withdrew %s for a guild bank tab"), name, money)
		elseif txType == "buyTab" then
			msg = format(G("GUILDBANK_BUYTAB_MONEY_FORMAT", "%s purchased a guild bank tab for %s"), name, money)
		end
		if msg then
			frame:AddMessage(msg..LogTime(year, month, day, hour))
		end
	end
end

function mod:UpdateHeader()
	if not self.header then return end
	if self.view == VIEW_MONEY then
		self.header:SetText(G("GUILD_BANK_MONEY_LOG", L["Money Log"]))
		return
	end
	local tab = CurrentTab()
	local name = TabInfo(tab)
	if not name or name == "" then
		name = format(G("GUILDBANK_TAB_NUMBER", L["Tab %d"]), tab)
	end
	local title
	if self.view == VIEW_LOG then
		title = format(G("GUILDBANK_LOG_TITLE_FORMAT", L["%s Log"]), name)
	elseif self.view == VIEW_INFO then
		title = format(G("GUILDBANK_INFO_TITLE_FORMAT", L["%s Info"]), name)
	else
		self.header:SetText("")
		return
	end
	self.header:SetText(title.." "..AccessSuffix())
end

--------------------------------------------------------------------------------
-- Info
--------------------------------------------------------------------------------

function mod:QueryInfo()
	if QueryGuildBankText then
		QueryGuildBankText(CurrentTab())
	end
	self:FillInfo()
end

function mod:OnInfoText(_, tab)
	if self.view ~= VIEW_INFO then return end
	if tab and tonumber(tab) ~= CurrentTab() then return end
	self:FillInfo()
end

function mod:OnInfoTextChanged(_, tab)
	if self.view ~= VIEW_INFO then return end
	if tab and tonumber(tab) == CurrentTab() and QueryGuildBankText then
		QueryGuildBankText(tab)
	end
end

function mod:FillInfo()
	if not self.infoEdit then return end
	local text = GetGuildBankText and GetGuildBankText(CurrentTab()) or ""
	self.infoEdit.text = text
	self.infoEdit:SetText(text)
	local canEdit = CanEditGuildTabInfo and CanEditGuildTabInfo(CurrentTab())
	self.infoEdit:EnableMouse(not not canEdit)
	self.infoEdit:EnableKeyboard(not not canEdit)
	if not canEdit then
		self.infoEdit:ClearFocus()
	end
	self:UpdateSaveButton()
end

function mod:UpdateSaveButton()
	if not self.saveButton then return end
	local canEdit = self.view == VIEW_INFO and CanEditGuildTabInfo and CanEditGuildTabInfo(CurrentTab())
	if canEdit then
		self.saveButton:Show()
	else
		self.saveButton:Hide()
	end
end

function mod:SaveInfo()
	if not SetGuildBankText or not self.infoEdit then return end
	SetGuildBankText(CurrentTab(), self.infoEdit:GetText() or "")
	self.infoEdit:ClearFocus()
end
