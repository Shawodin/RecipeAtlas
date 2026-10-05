-- Tooltip and merchant integration:
--  * recipe items (bags, auction house, links): learned / not learned / skill too low
--  * NPCs in the world: how many of your unlearned recipes they teach, sell or drop
--  * merchant window: unlearned recipes get a glow
local RA = _G.RecipeAtlas
RA.Tooltip = RA.Tooltip or {}
local Tip = RA.Tooltip

local PREFIX = "|cffffd200Рецептный компас:|r "

local function itemIDFromLink(link)
	return link and tonumber(link:match("item:(%d+)"))
end

-- Status lines for one recipe item; nil when the player has nothing to do with that profession.
function Tip:GetItemStatus(itemID)
	local entries = RA.recipesByItem and RA.recipesByItem[itemID]
	if not entries or not RA.db then return nil end
	local lines = {}
	for _, entry in ipairs(entries) do
		local status = RA:GetRecipeStatus(entry.professionID, entry.spellID)
		local rank = RA:GetProfessionRank(entry.professionID)
		if status == "known" then
			lines[#lines + 1] = { PREFIX .. "|cff71d78aуже изучен|r", "known" }
		elseif status == "missing" then
			if rank and rank < entry.rank then
				lines[#lines + 1] = { PREFIX .. "|cffff9040не изучен, нужен навык " .. entry.rank .. " (у вас " .. rank .. ")|r", "low" }
			else
				lines[#lines + 1] = { PREFIX .. "|cffffff60не изучен — можно учить!|r", "missing" }
			end
		elseif rank then
			lines[#lines + 1] = { PREFIX .. "|cff9a948aоткройте окно профессии, чтобы проверить|r", "unscanned" }
		end
	end
	return lines
end

local function onTooltipSetItem(tooltip)
	if not RA.db then return end
	local _, link = tooltip:GetItem()
	local itemID = itemIDFromLink(link)
	if not itemID then return end
	local lines = Tip:GetItemStatus(itemID)
	if not lines then return end
	for _, line in ipairs(lines) do tooltip:AddLine(line[1], 1, 1, 1, true) end
	if #lines > 0 then tooltip:Show() end
end

---------------------------------------------------------------------------
-- NPC tooltips
---------------------------------------------------------------------------
local kindVerb = { t = "учит", v = "продаёт", m = "добыча", q = "задание" }

function Tip:GetNPCIndex()
	if RA.recipesByNPC then return RA.recipesByNPC end
	local index = {}
	local function add(npcID, entry, kind)
		local list = index[npcID]
		if not list then list = {}; index[npcID] = list end
		list[#list + 1] = { entry = entry, kind = kind }
	end
	for _, entry in ipairs(RA.recipeList or {}) do
		for _, source in ipairs(entry.recipe.s or {}) do
			local kind = source.t
			if kind == "t" or kind == "v" or kind == "m" then
				for _, id in ipairs(source.n or {}) do add(id, entry, kind) end
			elseif kind == "q" then
				for _, questID in ipairs(source.q or {}) do
					local quest = RA.Data.Q[questID]
					for _, id in ipairs(quest and quest.g or {}) do add(id, entry, "q") end
				end
			end
		end
	end
	RA.recipesByNPC = index
	return index
end

local function npcIDFromGUID(guid)
	if not guid then return nil end
	local kind = tonumber(guid:sub(3, 5), 16)
	if not kind then return nil end
	local unitType = kind % 8           -- 3 = creature, 5 = vehicle
	if unitType ~= 3 and unitType ~= 5 then return nil end
	return tonumber(guid:sub(7, 12), 16)
end

local function onTooltipSetUnit(tooltip)
	if not RA.db or not RA.db.npcTooltip then return end
	local _, unit = tooltip:GetUnit()
	if not unit or UnitIsPlayer(unit) then return end
	local npcID = npcIDFromGUID(UnitGUID(unit))
	local list = npcID and Tip:GetNPCIndex()[npcID]
	if not list then return end
	local seen, missing, kinds = {}, {}, {}
	for _, item in ipairs(list) do
		local entry = item.entry
		if not seen[entry.key] and RA:GetRecipeStatus(entry.professionID, entry.spellID) == "missing"
			and RA:IsForPlayerClass(entry.recipe.cl) then
			seen[entry.key] = true
			missing[#missing + 1] = entry
			kinds[item.kind] = true
		end
	end
	if #missing == 0 then return end
	local verbs = {}
	for _, kind in ipairs({ "t", "v", "q", "m" }) do if kinds[kind] then verbs[#verbs + 1] = kindVerb[kind] end end
	tooltip:AddLine(PREFIX .. "неизученных рецептов: " .. #missing .. " (" .. table.concat(verbs, ", ") .. ")", 1, 1, 1)
	table.sort(missing, function(a, b) return a.rank < b.rank end)
	for i = 1, math.min(#missing, 4) do
		local e = missing[i]
		local rank = RA:GetProfessionRank(e.professionID)
		local r, g, b = 0.95, 0.88, 0.62
		if rank and rank < e.rank then r, g, b = 1, 0.55, 0.3 end
		tooltip:AddDoubleLine("  " .. RA:GetSpellName(e.spellID, e.itemID), tostring(e.rank), r, g, b, 0.6, 0.6, 0.6)
	end
	if #missing > 4 then tooltip:AddLine("  и ещё " .. (#missing - 4), 0.6, 0.6, 0.6) end
	tooltip:Show()
end

---------------------------------------------------------------------------
-- Merchant window glow
---------------------------------------------------------------------------
local function merchantOverlay(button)
	if button.recipeAtlasGlow then return button.recipeAtlasGlow end
	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	glow:SetBlendMode("ADD")
	glow:SetPoint("CENTER", button, "CENTER", 0, 0)
	glow:SetWidth(button:GetWidth() * 1.8); glow:SetHeight(button:GetHeight() * 1.8)
	glow:Hide()
	button.recipeAtlasGlow = glow
	return glow
end

function Tip:UpdateMerchant()
	if not MerchantFrame or not MerchantFrame:IsShown() then return end
	local perPage = MERCHANT_ITEMS_PER_PAGE or 10
	local buyback = MerchantFrame.selectedTab == 2
	for i = 1, perPage do
		local button = _G["MerchantItem" .. i .. "ItemButton"]
		if button then
			local glow = merchantOverlay(button)
			local state
			if not buyback and RA.db and RA.db.merchantGlow then
				local index = ((MerchantFrame.page or 1) - 1) * perPage + i
				local itemID = itemIDFromLink(GetMerchantItemLink(index))
				local lines = itemID and self:GetItemStatus(itemID)
				for _, line in ipairs(lines or {}) do
					if line[2] == "missing" then state = "missing" break end
					if line[2] == "low" then state = "low" end
				end
			end
			if state == "missing" then
				glow:SetVertexColor(0.3, 1, 0.35); glow:Show()
			elseif state == "low" then
				glow:SetVertexColor(1, 0.55, 0.15); glow:Show()
			else
				glow:Hide()
			end
		end
	end
end

function Tip:OnDataChanged()
	RA.recipesByNPC = nil
	if MerchantFrame and MerchantFrame:IsShown() then self:UpdateMerchant() end
end

function Tip:Initialize()
	if self.initialized then return end
	self.initialized = true
	for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
		if tooltip and tooltip.HookScript then tooltip:HookScript("OnTooltipSetItem", onTooltipSetItem) end
	end
	if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipSetUnit", onTooltipSetUnit) end
	if hooksecurefunc then
		if MerchantFrame_UpdateMerchantInfo then hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() Tip:UpdateMerchant() end) end
		if MerchantFrame_UpdateBuybackInfo then hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function() Tip:UpdateMerchant() end) end
	end
end
