local RA = _G.RecipeAtlas or {}
_G.RecipeAtlas = RA

RA.Name = "RecipeAtlas"
RA.Version = "0.5.2"
RA.Data = _G.RecipeAtlasData or { P = {}, N = {}, O = {}, Q = {}, I = {}, F = {} }
RA.Data.N = RA.Data.N or {}
RA.Data.O = RA.Data.O or {}
RA.Data.Q = RA.Data.Q or {}
RA.Data.I = RA.Data.I or {}
RA.Data.F = RA.Data.F or {}

RA.Professions = {
	{ id = 171, ability = 2259, key = "ALCHEMY" },
	{ id = 164, ability = 2018, key = "BLACKSMITHING" },
	{ id = 185, ability = 2550, key = "COOKING" },
	{ id = 333, ability = 7411, key = "ENCHANTING" },
	{ id = 202, ability = 4036, key = "ENGINEERING" },
	{ id = 186, ability = 2575, key = "MINING", tradeSkillSpell = 2656 },
	{ id = 129, ability = 3273, key = "FIRST_AID" },
	{ id = 773, ability = 45357, key = "INSCRIPTION" },
	{ id = 755, ability = 25229, key = "JEWELCRAFTING" },
	{ id = 165, ability = 2108, key = "LEATHERWORKING" },
	{ id = 197, ability = 3908, key = "TAILORING" },
}
RA.ProfessionByID = {}
for _, profession in ipairs(RA.Professions) do RA.ProfessionByID[profession.id] = profession end

RA.FallbackProfessionNames = {
	[171] = "Алхимия", [164] = "Кузнечное дело", [185] = "Кулинария", [333] = "Наложение чар",
	[202] = "Инженерное дело", [186] = "Горное дело", [129] = "Первая помощь", [773] = "Начертание",
	[755] = "Ювелирное дело", [165] = "Кожевничество", [197] = "Портняжное дело",
}

RA.SourceLabels = {
	v = "Торговец", t = "Наставник", m = "Добыча", w = "Мировая добыча", o = "Контейнер",
	i = "Из предмета", q = "Задание", f = "Рыбалка", d = "Открытие",
}
RA.SourceOrder = { "t", "v", "m", "w", "q", "o", "i", "f", "d" }
RA.MapSourceTypes = { v = true, t = true, m = true, q = true, o = true }

RA.FactionNamesRU = {
	[59] = "Братство Тория", [270] = "Племя Зандалар", [529] = "Серебряный Рассвет", [576] = "Древобрюхи",
	[609] = "Круг Кенария", [749] = "Гидраксианские Повелители Вод", [932] = "Алдоры", [933] = "Консорциум",
	[934] = "Провидцы", [935] = "Ша'тар", [941] = "Маг'хар", [942] = "Экспедиция Кенария",
	[946] = "Оплот Чести", [947] = "Траллмар", [967] = "Аметистовое Око", [970] = "Спореггар",
	[978] = "Куренай", [989] = "Хранители Времени", [990] = "Песчаная Чешуя", [1011] = "Нижний Город",
	[1012] = "Пеплоусты-служители", [1037] = "Авангард Альянса", [1052] = "Экспедиция Орды",
	[1073] = "Калу'ак", [1077] = "Армия Расколотого Солнца", [1090] = "Кирин-Тор", [1091] = "Драконий союз",
	[1098] = "Рыцари Черного Клинка", [1104] = "Племя Бешеного Сердца", [1105] = "Оракулы",
	[1106] = "Серебряный Авангард", [1119] = "Сыновья Ходира", [1156] = "Пепельный союз",
}
RA.StandingNamesRU = {
	[0] = "Ненависть", [1] = "Враждебность", [2] = "Неприязнь", [3] = "Равнодушие",
	[4] = "Дружелюбие", [5] = "Уважение", [6] = "Почтение", [7] = "Превознесение",
}

RA.Holidays = {
	WINTER_VEIL = { name = "Зимний Покров", tokens = { "winterveil", "зимн" }, fixed = { 12, 15, 1, 2 } },
	LUNAR_FESTIVAL = { name = "Лунный фестиваль", tokens = { "lunarfestival", "лунн" } },
	DAY_OF_THE_DEAD = { name = "День мертвых", tokens = { "dayofthedead", "мертв" }, fixed = { 11, 1, 11, 2 } },
	PILGRIMS_BOUNTY = { name = "Пиршество странников", tokens = { "pilgrim", "странник" } },
	MIDSUMMER = { name = "Огненный солнцеворот", tokens = { "midsummer", "солнцеворот" }, fixed = { 6, 21, 7, 5 } },
	BREWFEST = { name = "Хмельной фестиваль", tokens = { "brewfest", "хмельн" }, fixed = { 9, 20, 10, 6 } },
	HALLOWS_END = { name = "Тыквовин", tokens = { "hallowsend", "hallow", "тыкв" }, fixed = { 10, 18, 11, 1 } },
	LOVE_IS_IN_THE_AIR = { name = "Любовная лихорадка", tokens = { "loveintheair", "любов" } },
	NOBLEGARDEN = { name = "Сад чудес", tokens = { "noblegarden", "чудес" } },
	CHILDRENS_WEEK = { name = "Детская неделя", tokens = { "childrens", "детск" } },
	HARVEST_FESTIVAL = { name = "Праздник урожая", tokens = { "harvest", "урожа" } },
	PIRATES_DAY = { name = "День пирата", tokens = { "pirate", "пират" }, fixed = { 9, 19, 9, 19 } },
	DARKMOON = { name = "Ярмарка Новолуния", tokens = { "darkmoon", "новолун" } },
	DARKMOON_ELWYNN = { name = "Ярмарка Новолуния (Элвинн)", tokens = { "darkmoonfaireelwynn", "darkmoonelwynn" } },
	DARKMOON_MULGORE = { name = "Ярмарка Новолуния (Мулгор)", tokens = { "darkmoonfairemulgore", "darkmoonmulgore" } },
	DARKMOON_TEROKKAR = { name = "Ярмарка Новолуния (Тероккар)", tokens = { "darkmoonfaireterokkar", "darkmoonterokkar" } },
	FISHING_EXTRAVAGANZA = { name = "Рыбомания", tokens = { "fishing", "рыбомани" } },
	KALUAK_DERBY = { name = "Рыболовное дерби калу'ак", tokens = { "kaluak", "калу" } },
}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local lower = string.lower
local function normalized(text)
	if not text then return "" end
	local s = (strlower or lower)(text)
	return (s:gsub("[^%w\128-\255]", ""))
end
RA.Normalize = normalized

function RA:Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Рецептный компас:|r " .. tostring(message))
	end
end

-- One shared OnUpdate frame drives every delayed or debounced call.
local timerFrame = CreateFrame("Frame")
local timers = {}
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(frame)
	local now = GetTime()
	local due
	for key, timer in pairs(timers) do
		if now >= timer.at then
			due = due or {}
			due[#due + 1] = key
		end
	end
	if due then
		for _, key in ipairs(due) do
			local timer = timers[key]
			if timer and now >= timer.at then
				timers[key] = nil
				local ok, err = pcall(timer.fn)
				if not ok then geterrorhandler()(err) end
			end
		end
	end
	if not next(timers) then frame:Hide() end
end)
-- Schedules fn after delay; calling again with the same key replaces the pending call.
function RA:After(delay, key, fn)
	timers[key or fn] = { at = GetTime() + (delay or 0), fn = fn }
	timerFrame:Show()
end
function RA:Cancel(key) timers[key] = nil end
-- Like After, but an already pending call keeps its time (no endless postponing).
function RA:Throttle(delay, key, fn)
	local timer = timers[key]
	if timer then timer.fn = fn return end
	self:After(delay, key, fn)
end

function RA:FormatMoney(copper)
	copper = tonumber(copper) or 0
	if copper <= 0 then return nil end
	if GetCoinTextureString then
		local ok, text = pcall(GetCoinTextureString, copper, 10)
		if ok and text then return text end
	end
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. "з" end
	if s > 0 then parts[#parts + 1] = s .. "с" end
	if c > 0 then parts[#parts + 1] = c .. "м" end
	return table.concat(parts, " ")
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
RA.nameCache = {}

function RA:GetProfessionName(id)
	local profession = self.ProfessionByID[id]
	if not profession then return "Профессия" end
	if not profession.name then
		profession.name = GetSpellInfo(profession.ability)
	end
	return profession.name or self.FallbackProfessionNames[id] or profession.key
end

function RA:GetSpellName(spellID, itemID)
	local cached = self.nameCache[spellID]
	if cached then return cached end
	local name = GetSpellInfo(spellID)
	if name and name ~= "" then
		self.nameCache[spellID] = name
		return name
	end
	if itemID and itemID > 0 and GetItemInfo then
		local itemName = GetItemInfo(itemID)
		if itemName then return itemName end
	end
	return "Рецепт #" .. tostring(spellID)
end

local function itemIcon(itemID)
	if not itemID or itemID <= 0 then return nil end
	if GetItemIcon then
		local texture = GetItemIcon(itemID)
		if texture then return texture end
	end
	if GetItemInfo then return (select(10, GetItemInfo(itemID))) end
end

-- Icon of what the recipe makes (like the trade skill window), then the spell icon,
-- then the recipe item; placeholder spell icons ("Temp", question mark) are skipped.
function RA:GetSpellTexture(spellID, itemID, craftedID)
	local texture = itemIcon(craftedID)
	if texture then return texture end
	local _, _, spellTexture = GetSpellInfo(spellID)
	if spellTexture then
		local lowerTexture = lower(spellTexture)
		if not lowerTexture:find("temp$") and not lowerTexture:find("questionmark") then return spellTexture end
	end
	return itemIcon(itemID) or spellTexture or "Interface\\Icons\\INV_Misc_Note_01"
end

function RA:GetHolidayName(key)
	local info = key and self.Holidays[key]
	return info and info.name
end

local CLASS_BITS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, DEATHKNIGHT = 32,
	SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_NAMES_RU = { WARRIOR = "Воин", PALADIN = "Паладин", HUNTER = "Охотник", ROGUE = "Разбойник", PRIEST = "Жрец",
	DEATHKNIGHT = "Рыцарь смерти", SHAMAN = "Шаман", MAGE = "Маг", WARLOCK = "Чернокнижник", DRUID = "Друид" }
function RA:GetClassNames(mask)
	local names = {}
	for _, token in ipairs(CLASS_ORDER) do
		if bit.band(mask or 0, CLASS_BITS[token]) ~= 0 then
			names[#names + 1] = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or CLASS_NAMES_RU[token]
		end
	end
	return table.concat(names, ", ")
end

function RA:IsForPlayerClass(mask)
	if not mask or mask == 0 then return true end
	if not self.playerClassBit then
		local _, classToken = UnitClass("player")
		self.playerClassBit = CLASS_BITS[classToken or ""] or 0
	end
	if self.playerClassBit == 0 then return true end
	return bit.band(mask, self.playerClassBit) ~= 0
end

function RA:GetRecipeLink(spellID, itemID)
	if itemID and itemID > 0 and GetItemInfo then
		local _, link = GetItemInfo(itemID)
		if link then return link end
	end
	if GetSpellLink then return GetSpellLink(spellID) end
end

function RA:GetFactionName(factionID)
	if not factionID or factionID == 0 then return nil end
	if GetFactionInfoByID then
		local ok, name = pcall(GetFactionInfoByID, factionID)
		if ok and name and name ~= "" then return name end
	end
	return self.FactionNamesRU[factionID] or self.Data.F[factionID] or ("фракция #" .. factionID)
end

function RA:GetStandingName(rank)
	rank = tonumber(rank)
	if not rank then return "" end
	local label = _G["FACTION_STANDING_LABEL" .. (rank + 1)]
	return label or self.StandingNamesRU[rank] or tostring(rank)
end

---------------------------------------------------------------------------
-- Recipe index (built once)
---------------------------------------------------------------------------
function RA:BuildIndex()
	local list, byKey, total, byItem = {}, {}, {}, {}
	local function indexItem(itemID, entry)
		if not itemID or itemID == 0 then return end
		byItem[itemID] = byItem[itemID] or {}
		table.insert(byItem[itemID], entry)
	end
	for professionID, recipeSet in pairs(self.Data.P or {}) do
		total[professionID] = 0
		for spellID, recipe in pairs(recipeSet) do
			local entry = { professionID = professionID, spellID = spellID, recipe = recipe,
				itemID = recipe.i, craftedID = recipe.ci, rank = recipe.r or 0, key = professionID .. ":" .. spellID }
			local kinds = {}
			for _, source in ipairs(recipe.s or {}) do kinds[source.t] = true end
			entry.kinds = kinds
			list[#list + 1] = entry
			byKey[entry.key] = entry
			total[professionID] = total[professionID] + 1
			indexItem(recipe.i, entry)
			for _, itemID in ipairs(recipe.ia or {}) do indexItem(itemID, entry) end
		end
	end
	self.recipeList, self.recipeByKey, self.recipeTotals, self.recipesByItem = list, byKey, total, byItem
	self.recipesByNPC = nil
end

function RA:GetRecipe(professionID, spellID)
	local profession = self.Data.P and self.Data.P[professionID]
	return profession and profession[spellID]
end

function RA:GetEntry(professionID, spellID)
	return self.recipeByKey and self.recipeByKey[professionID .. ":" .. spellID]
end

---------------------------------------------------------------------------
-- Saved state
---------------------------------------------------------------------------
function RA:InitializeDB()
	if type(RecipeAtlasDB) ~= "table" then RecipeAtlasDB = {} end
	local db = RecipeAtlasDB
	if (tonumber(db.version) or 1) < 2 then
		-- v1 mixed spell and item IDs in one global "known" list and could mark
		-- recipes as known by name. Keep per-profession results; the next full
		-- scan replaces them with clean data.
		db.known = type(db.knownByProfession) == "table" and db.knownByProfession or {}
		db.knownByProfession = nil
		db.sourceFilter = nil
		db.windowPoint = nil
	end
	db.version = 2
	db.known = type(db.known) == "table" and db.known or {}
	db.scanned = type(db.scanned) == "table" and db.scanned or {}
	db.partial = type(db.partial) == "table" and db.partial or {}
	db.rank = type(db.rank) == "table" and db.rank or {}
	db.showProf = type(db.showProf) == "table" and db.showProf or {}
	db.sourceEnabled = type(db.sourceEnabled) == "table" and db.sourceEnabled or {}
	for _, kind in ipairs(self.SourceOrder) do
		if db.sourceEnabled[kind] == nil then db.sourceEnabled[kind] = true end
	end
	db.markerEnabled = db.markerEnabled ~= false
	db.hideAboveSkill = db.hideAboveSkill == true
	db.hideOpposingFaction = db.hideOpposingFaction ~= false
	db.hideInactiveHolidays = db.hideInactiveHolidays ~= false
	db.hideOtherClass = db.hideOtherClass ~= false
	db.npcTooltip = db.npcTooltip ~= false
	db.merchantGlow = db.merchantGlow ~= false
	db.tracked = type(db.tracked) == "table" and db.tracked or {}
	db.minimapButton = db.minimapButton ~= false
	db.minimapAngle = tonumber(db.minimapAngle) or 210
	db.query = type(db.query) == "string" and db.query or ""
	db.selectedProfession = tonumber(db.selectedProfession)
	db.selectedSpell = tonumber(db.selectedSpell)
	db.windowX = tonumber(db.windowX) or 0
	db.windowY = tonumber(db.windowY) or 0
	for profID in pairs(db.scanned) do
		if not db.known[profID] or not next(db.known[profID]) then db.scanned[profID] = nil end
	end
	self.db = db
end

---------------------------------------------------------------------------
-- Status and filters
---------------------------------------------------------------------------
function RA:IsKnown(professionID, spellID)
	local known = self.db and self.db.known[professionID]
	return known and known[spellID] and true or false
end

function RA:GetRecipeStatus(professionID, spellID)
	if self:IsKnown(professionID, spellID) then return "known" end
	if self.db and self.db.scanned[professionID] then return "missing" end
	return "unscanned"
end

function RA:GetPlayerFactionSide()
	if self.playerSide then return self.playerSide end
	local faction = UnitFactionGroup and UnitFactionGroup("player")
	if faction == "Alliance" then self.playerSide = "A" elseif faction == "Horde" then self.playerSide = "H" end
	return self.playerSide
end

local function opposite(side, player)
	return side and player and side ~= player
end

function RA:IsOpposingFactionNPC(npcID)
	if not self.db or not self.db.hideOpposingFaction then return false end
	local npc = self.Data.N[npcID]
	return opposite(npc and npc.s, self:GetPlayerFactionSide()) or false
end

function RA:IsOpposingFactionQuest(questID)
	if not self.db or not self.db.hideOpposingFaction then return false end
	local quest = self.Data.Q[questID]
	return opposite(quest and quest.s, self:GetPlayerFactionSide()) or false
end

-- Returns whether this specific source of a recipe is usable right now.
function RA:IsSourceIDAllowed(kind, id)
	if kind == "v" or kind == "t" then
		if self:IsOpposingFactionNPC(id) then return false end
		local npc = self.Data.N[id]
		if npc and npc.h and self.db.hideInactiveHolidays and not self:IsHolidayActive(npc.h) then return false end
	elseif kind == "q" then
		if self:IsOpposingFactionQuest(id) then return false end
		local quest = self.Data.Q[id]
		if quest and quest.h and self.db.hideInactiveHolidays and not self:IsHolidayActive(quest.h) then return false end
		if quest and quest.c and self.db.hideOtherClass and not self:IsForPlayerClass(quest.c) then return false end
	end
	return true
end

function RA:IsSourceAllowed(source)
	local kind = source.t
	if not self.db.sourceEnabled[kind] then return false end
	local ids
	if kind == "v" or kind == "t" then ids = source.n elseif kind == "q" then ids = source.q end
	if not ids then return true end
	for _, id in ipairs(ids) do
		if self:IsSourceIDAllowed(kind, id) then return true end
	end
	return false
end

function RA:GetProfessionRank(professionID)
	self.professionRankCache = self.professionRankCache or {}
	local cached = self.professionRankCache[professionID]
	if cached ~= nil then return cached or nil end
	local rank
	if GetNumSkillLines and GetSkillLineInfo then
		local prof = self.ProfessionByID[professionID]
		local expected1 = normalized(self:GetProfessionName(professionID))
		local expected2 = prof and prof.tradeSkillSpell and normalized(GetSpellInfo(prof.tradeSkillSpell))
		for index = 1, GetNumSkillLines() do
			local name, isHeader, _, currentRank = GetSkillLineInfo(index)
			if not isHeader and name then
				local norm = normalized(name)
				if norm == expected1 or (expected2 and norm == expected2) then
					rank = tonumber(currentRank)
					break
				end
			end
		end
	end
	rank = rank or (self.db and self.db.rank[professionID])
	self.professionRankCache[professionID] = rank or false
	return rank
end

function RA:CanLearnAtCurrentSkill(entry)
	if not self.db.hideAboveSkill then return true end
	local currentRank = self:GetProfessionRank(entry.professionID)
	return not currentRank or entry.rank <= currentRank
end

-- Full visibility check shared by the list and the map.
function RA:IsRecipeVisible(entry)
	local db = self.db
	if not db.showProf[entry.professionID] then return false end
	if self:IsKnown(entry.professionID, entry.spellID) then return false end
	if not self:CanLearnAtCurrentSkill(entry) then return false end
	local recipe = entry.recipe
	if db.hideOpposingFaction and opposite(recipe.fs, self:GetPlayerFactionSide()) then return false end
	if db.hideOtherClass and not self:IsForPlayerClass(recipe.cl) then return false end
	if recipe.hd and db.hideInactiveHolidays and not self:IsHolidayActive(recipe.hd) then return false end
	local sources = recipe.s or {}
	if #sources == 0 then return true end
	for _, source in ipairs(sources) do
		if self:IsSourceAllowed(source) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Holidays: in-game calendar first, server-date fallback for fixed dates
---------------------------------------------------------------------------
function RA:UpdateHolidays()
	local active, fromCalendar = {}, false
	if CalendarGetDate and CalendarGetNumDayEvents and CalendarGetDayEvent and CalendarGetMonth then
		local ok = pcall(function()
			local _, month, day, year = CalendarGetDate()
			local shownMonth, shownYear = CalendarGetMonth(0)
			if not (month and day and year and shownMonth and shownYear) or month == 0 then return end
			local offset = (year - shownYear) * 12 + (month - shownMonth)
			local count = CalendarGetNumDayEvents(offset, day) or 0
			for i = 1, count do
				local title, _, _, calendarType, _, _, texture = CalendarGetDayEvent(offset, day, i)
				if calendarType == "HOLIDAY" then
					fromCalendar = true
					local haystack = normalized((title or "") .. " " .. (texture or ""))
					for key, info in pairs(self.Holidays) do
						for _, token in ipairs(info.tokens) do
							if string.find(haystack, token, 1, true) then active[key] = true end
						end
					end
				end
			end
		end)
		if not ok then fromCalendar = false end
	end
	self.holidayActive, self.holidayFromCalendar = active, fromCalendar or self.calendarLoaded
	self.holidayCheckedAt = GetTime()
end

local function inRange(month, day, range)
	local sM, sD, eM, eD = range[1], range[2], range[3], range[4]
	local v, s, e = month * 100 + day, sM * 100 + sD, eM * 100 + eD
	if s <= e then return v >= s and v <= e end
	return v >= s or v <= e
end

function RA:IsHolidayActive(key)
	if not self.holidayCheckedAt or GetTime() - self.holidayCheckedAt > 300 then self:UpdateHolidays() end
	if self.holidayActive and self.holidayActive[key] then return true end
	if self.holidayFromCalendar then return false end
	-- Calendar data not available yet: only hide holidays with fixed dates.
	local info = self.Holidays[key]
	if not info or not info.fixed then return true end
	local month, day
	if CalendarGetDate then
		local _, m, d = CalendarGetDate()
		if m and m > 0 then month, day = m, d end
	end
	if not month then
		local t = date("*t")
		month, day = t.month, t.day
	end
	return inRange(month, day, info.fixed)
end

---------------------------------------------------------------------------
-- Profession detection and trade skill scan
---------------------------------------------------------------------------
function RA:DetectProfessions()
	local detected = {}
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local name, isHeader, _, rank = GetSkillLineInfo(i)
			if not isHeader and rank and rank > 0 then
				local norm = normalized(name)
				for _, profession in ipairs(self.Professions) do
					local expected2 = profession.tradeSkillSpell and normalized(GetSpellInfo(profession.tradeSkillSpell))
					if norm == normalized(self:GetProfessionName(profession.id)) or (expected2 and norm == expected2) then
						detected[profession.id] = true
					end
				end
			end
		end
	end
	return detected
end

function RA:ApplyDetectedProfessions()
	local changed = false
	for id in pairs(self:DetectProfessions()) do
		if self.db.showProf[id] == nil then
			self.db.showProf[id] = true
			changed = true
		end
	end
	if not self.db.selectedProfession then
		for _, profession in ipairs(self.Professions) do
			if self.db.showProf[profession.id] then self.db.selectedProfession = profession.id break end
		end
	end
	return changed
end

function RA:GetTradeSkillProfession()
	if not GetTradeSkillLine then return end
	local tradeName, rank = GetTradeSkillLine()
	if not tradeName or tradeName == "" or tradeName == "UNKNOWN" then return end
	local norm = normalized(tradeName)
	local fuzzy
	for _, profession in ipairs(self.Professions) do
		local name1 = normalized(self:GetProfessionName(profession.id))
		local name2 = profession.tradeSkillSpell and normalized(GetSpellInfo(profession.tradeSkillSpell))
		if norm == name1 or (name2 and norm == name2) then return profession.id, tonumber(rank) end
		if not fuzzy and name1 ~= "" and (string.find(name1, norm, 1, true) or string.find(norm, name1, 1, true)) then
			fuzzy = profession.id
		end
	end
	return fuzzy, tonumber(rank)
end

local function captureTradeSkillState()
	local state = { collapsed = {} }
	if TradeSkillFrameAvailableFilterCheckButton then
		state.makeable = TradeSkillFrameAvailableFilterCheckButton:GetChecked() and true or false
	end
	if GetTradeSkillItemNameFilter then state.name = GetTradeSkillItemNameFilter() end
	if GetTradeSkillSubClassFilter and not GetTradeSkillSubClassFilter(0) then
		state.sub = {}
		for i = 1, 64 do
			local ok, enabled = pcall(GetTradeSkillSubClassFilter, i)
			if not ok then break end
			if enabled then state.sub[#state.sub + 1] = i end
		end
	end
	if GetTradeSkillInvSlotFilter and not GetTradeSkillInvSlotFilter(0) then
		state.slot = {}
		for i = 1, 64 do
			local ok, enabled = pcall(GetTradeSkillInvSlotFilter, i)
			if not ok then break end
			if enabled then state.slot[#state.slot + 1] = i end
		end
	end
	for i = 1, GetNumTradeSkills() or 0 do
		local name, kind, _, expanded = GetTradeSkillInfo(i)
		if kind == "header" and not expanded and name then state.collapsed[name] = true end
	end
	state.selection = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex()
	return state
end

local function clearTradeSkillFilters()
	if TradeSkillOnlyShowMakeable then TradeSkillOnlyShowMakeable(false) end
	if SetTradeSkillItemNameFilter then SetTradeSkillItemNameFilter("") end
	if SetTradeSkillSubClassFilter then SetTradeSkillSubClassFilter(0, 1, 1) end
	if SetTradeSkillInvSlotFilter then SetTradeSkillInvSlotFilter(0, 1, 1) end
	if ExpandTradeSkillSubClass then ExpandTradeSkillSubClass(0) end
	local full = true
	if GetTradeSkillSubClassFilter and not GetTradeSkillSubClassFilter(0) then full = false end
	if GetTradeSkillInvSlotFilter and not GetTradeSkillInvSlotFilter(0) then full = false end
	for i = 1, GetNumTradeSkills() or 0 do
		local _, kind, _, expanded = GetTradeSkillInfo(i)
		if kind == "header" and not expanded then full = false break end
	end
	return full
end

local function restoreTradeSkillState(state)
	if state.sub and SetTradeSkillSubClassFilter then
		for n, index in ipairs(state.sub) do SetTradeSkillSubClassFilter(index, 1, n == 1 and 1 or nil) end
	end
	if state.slot and SetTradeSkillInvSlotFilter then
		for n, index in ipairs(state.slot) do SetTradeSkillInvSlotFilter(index, 1, n == 1 and 1 or nil) end
	end
	if state.name and state.name ~= "" and SetTradeSkillItemNameFilter then SetTradeSkillItemNameFilter(state.name) end
	if state.makeable then
		if TradeSkillOnlyShowMakeable then TradeSkillOnlyShowMakeable(true) end
		if TradeSkillFrameAvailableFilterCheckButton then TradeSkillFrameAvailableFilterCheckButton:SetChecked(true) end
	end
	if next(state.collapsed) and CollapseTradeSkillSubClass then
		for i = GetNumTradeSkills() or 0, 1, -1 do
			local name, kind, _, expanded = GetTradeSkillInfo(i)
			if kind == "header" and expanded and state.collapsed[name] then CollapseTradeSkillSubClass(i) end
		end
	end
	if state.selection and state.selection > 0 and TradeSkillFrame_SetSelection and TradeSkillFrame and TradeSkillFrame:IsShown() then
		pcall(TradeSkillFrame_SetSelection, state.selection)
	end
	if TradeSkillFrame_Update and TradeSkillFrame and TradeSkillFrame:IsShown() then pcall(TradeSkillFrame_Update) end
end

function RA:ScanCurrentTradeSkill(isManual)
	if not self.db or self.scanning or not GetNumTradeSkills then return end
	if IsTradeSkillLinked and IsTradeSkillLinked() then
		if isManual then self:Print("открыт чужой список профессии — его нельзя сохранить как ваш.") end
		return
	end
	local professionID, rank = self:GetTradeSkillProfession()
	if not professionID then
		if isManual then self:Print("сначала откройте окно своей профессии.") end
		return
	end

	self.scanning = true
	local known, count = {}, 0
	local state = captureTradeSkillState()
	local ok, fullOrErr = pcall(function()
		local full = clearTradeSkillFilters()
		for i = 1, GetNumTradeSkills() or 0 do
			local _, kind = GetTradeSkillInfo(i)
			if kind ~= "header" then
				local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
				local id = link and tonumber(link:match("enchant:(%d+)") or link:match("|H%a+:(%d+)"))
				if id and not known[id] then
					known[id] = true
					count = count + 1
				end
			end
		end
		return full
	end)
	pcall(restoreTradeSkillState, state)
	self.scanning = false
	if not ok then
		geterrorhandler()(fullOrErr)
		return
	end
	if count == 0 then
		if isManual then self:Print("в окне профессии нет рецептов — попробуйте ещё раз через секунду.") end
		return
	end

	local db = self.db
	local full = fullOrErr
	local previous = db.known[professionID] or {}
	local changed = not db.scanned[professionID] or (db.partial[professionID] and full) or db.rank[professionID] ~= rank
	local merged = full and {} or previous
	for id in pairs(known) do merged[id] = true end
	if not changed then
		for id in pairs(merged) do if not previous[id] then changed = true break end end
		for id in pairs(previous) do if not merged[id] then changed = true break end end
	end
	db.known[professionID] = merged
	db.scanned[professionID] = true
	db.partial[professionID] = (not full) or nil
	db.rank[professionID] = rank
	if db.showProf[professionID] == nil then db.showProf[professionID] = true end
	self.professionRankCache = nil

	if isManual then
		local inData, missing = 0, 0
		for spellID in pairs(self.Data.P[professionID] or {}) do
			if merged[spellID] then inData = inData + 1 else missing = missing + 1 end
		end
		self:Print(string.format("«%s»: изучено %d, в базе ещё не изучено %d%s.", self:GetProfessionName(professionID),
			count, missing, full and "" or " (часть фильтров окна не удалось сбросить)"))
	end
	if changed then self:RefreshAll() end
end

function RA:ScheduleScan(delay)
	self:After(delay or 0.3, "scan", function() RA:ScanCurrentTradeSkill(false) end)
end

---------------------------------------------------------------------------
-- Refresh plumbing
---------------------------------------------------------------------------
function RA:RefreshAll()
	self.dataVersion = (self.dataVersion or 0) + 1
	if self.UI and self.UI.RequestRefresh then self.UI:RequestRefresh() end
	if self.Map and self.Map.Invalidate then self.Map:Invalidate() end
	if self.Tooltip and self.Tooltip.OnDataChanged then self.Tooltip:OnDataChanged() end
	if self.Tracker and self.Tracker.OnDataChanged then self.Tracker:OnDataChanged() end
end

function RA:ToggleWindow()
	if not self.UI then return end
	if self.UI.frame and self.UI.frame:IsShown() then self.UI.frame:Hide() else self.UI:Show() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local learnPatterns = {}
local function buildLearnPatterns()
	for _, fmt in ipairs({ _G.ERR_LEARN_RECIPE_S, _G.ERR_LEARN_SPELL_S }) do
		if type(fmt) == "string" then
			local pattern = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+")
			learnPatterns[#learnPatterns + 1] = "^" .. pattern
		end
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(frame, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= RA.Name then return end
		frame:UnregisterEvent("ADDON_LOADED")
		RA:InitializeDB()
		RA:BuildIndex()
	elseif event == "PLAYER_LOGIN" then
		buildLearnPatterns()
		RA:GetPlayerFactionSide()
		RA:ApplyDetectedProfessions()
		if RA.UI and RA.UI.Create then RA.UI:Create() end
		if RA.Map and RA.Map.Initialize then RA.Map:Initialize() end
		if RA.Tooltip and RA.Tooltip.Initialize then RA.Tooltip:Initialize() end
		if RA.Tracker and RA.Tracker.Refresh then RA.Tracker:Refresh() end
		if not RA.Tracker or not RA.Tooltip then
			RA:Print("|cffff6060часть файлов аддона не загружена.|r Игра читает список файлов аддона только при запуске: полностью выйдите из игры и зайдите снова (/reload не поможет).")
		end
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
			"CHAT_MSG_SYSTEM", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "WORLD_MAP_UPDATE",
			"CALENDAR_UPDATE_EVENT_LIST" }) do
			frame:RegisterEvent(e)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		RA.professionRankCache = nil
		if RA:ApplyDetectedProfessions() then RA:RefreshAll() end
		if RA.Map then RA.Map:OnZoneChanged() end
		if not RA.calendarRequested and OpenCalendar then
			RA.calendarRequested = true
			RA:After(4, "calendar", function() pcall(OpenCalendar) end)
		end
	elseif event == "SKILL_LINES_CHANGED" then
		RA.professionRankCache = nil
		local added = RA:ApplyDetectedProfessions()
		if added or RA.db.hideAboveSkill then
			RA:After(2, "skills", function() RA:RefreshAll() end)
		end
	elseif event == "TRADE_SKILL_SHOW" then
		RA.tradeSkillOpen = true
		RA:ScheduleScan(0.3)
	elseif event == "TRADE_SKILL_CLOSE" then
		RA.tradeSkillOpen = false
		RA:Cancel("scan")
	elseif event == "CHAT_MSG_SYSTEM" then
		if RA.tradeSkillOpen and arg1 then
			for _, pattern in ipairs(learnPatterns) do
				if string.find(arg1, pattern) then RA:ScheduleScan(1) break end
			end
		end
	elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
		RA.calendarLoaded = true
		local before = RA.holidayActive
		RA:UpdateHolidays()
		local changed = not before
		if before then
			for k in pairs(RA.holidayActive) do if not before[k] then changed = true end end
			for k in pairs(before) do if not RA.holidayActive[k] then changed = true end end
		end
		if changed then RA:RefreshAll() end
	elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
		if RA.Map then RA.Map:OnZoneChanged() end
	elseif event == "WORLD_MAP_UPDATE" then
		if RA.Map then RA.Map:OnWorldMapUpdate() end
	end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function toggleSetting(key, onText, offText)
	RA.db[key] = not RA.db[key]
	RA:RefreshAll()
	RA:Print(RA.db[key] and onText or offText)
end

SLASH_RECIPEATLAS1 = "/recipeatlas"
SLASH_RECIPEATLAS2 = "/recipes"
SlashCmdList.RECIPEATLAS = function(message)
	message = lower(strtrim and strtrim(message or "") or (message or ""))
	if not RA.db then return end
	if message == "scan" then
		RA:ScanCurrentTradeSkill(true)
	elseif message == "map" then
		toggleSetting("markerEnabled", "метки на карте включены.", "метки на карте выключены.")
	elseif message == "minimap" then
		RA.db.minimapButton = not RA.db.minimapButton
		if RA.Map then RA.Map:PositionMinimapButton() end
		RA:Print(RA.db.minimapButton and "кнопка у миникарты показана." or "кнопка у миникарты скрыта. Вернуть: /recipes minimap")
	elseif message == "faction" then
		toggleSetting("hideOpposingFaction", "источники другой фракции скрыты.", "показаны источники обеих фракций.")
	elseif message == "event" or message == "holiday" then
		toggleSetting("hideInactiveHolidays", "рецепты неактивных праздников скрыты.", "рецепты всех праздников показаны.")
	elseif message == "class" then
		toggleSetting("hideOtherClass", "рецепты для других классов скрыты.", "показаны рецепты для всех классов.")
	elseif (message == "track" or message == "track reset") and not RA.Tracker then
		RA:Print("|cffff6060модуль отслеживания не загружен.|r Полностью перезапустите игру (/reload не поможет): новые файлы аддона подхватываются только при запуске.")
	elseif message == "track reset" then
		RA.db.trackerX, RA.db.trackerY, RA.db.trackerHidden = nil, nil, false
		if RA.Tracker then RA.Tracker:Refresh() end
		local name
		if RA.Tracker then name = select(2, RA.Tracker:FindQuestTracker()) end
		RA:Print("панель отслеживания " .. (name and ("прикреплена под задания (" .. name .. ").") or "возвращена на место по умолчанию."))
	elseif message == "track" then
		RA.db.trackerHidden = not RA.db.trackerHidden
		if RA.Tracker then RA.Tracker:Refresh() end
		RA:Print(RA.db.trackerHidden and "панель отслеживания скрыта." or "панель отслеживания показана.")
	elseif message == "npc" then
		toggleSetting("npcTooltip", "подсказка над NPC включена.", "подсказка над NPC выключена.")
	elseif message == "merchant" then
		toggleSetting("merchantGlow", "подсветка рецептов у торговцев включена.", "подсветка рецептов у торговцев выключена.")
	elseif message == "debugmap" then
		if RA.Map and RA.Map.PrintWorldMapStatus then RA.Map:PrintWorldMapStatus() end
	elseif message == "reset" then
		wipe(RA.db.known); wipe(RA.db.scanned); wipe(RA.db.partial); wipe(RA.db.rank)
		RA:RefreshAll()
		RA:Print("сохранённые рецепты сброшены. Откройте окна своих профессий заново.")
	elseif message == "help" or message == "?" then
		RA:Print("/recipes — окно; scan — пересканировать открытую профессию; map — метки; minimap — кнопка у миникарты; faction — фракция; class — чужие классы; holiday — праздники; track — панель отслеживания; npc — подсказка над NPC; merchant — подсветка у торговца; reset — забыть изученные рецепты; debugmap — диагностика карты.")
	else
		RA:ToggleWindow()
	end
end
