-- Recipe tracker: starred recipes stay on screen like tracked quests, with the nearest source.
local RA = _G.RecipeAtlas
RA.Tracker = RA.Tracker or {}
local Tracker = RA.Tracker
local Astrolabe = DongleStub and DongleStub("Astrolabe-0.4")

local MAX_ROWS, ROW_HEIGHT, WIDTH = 8, 30, 250
local WHITE = "Interface\\Buttons\\WHITE8X8"
local kindLabel = { t = "наставник", v = "торговец", m = "добыча", q = "задание", o = "сундук" }

---------------------------------------------------------------------------
-- Tracked list (saved per character, keeps the order of adding)
---------------------------------------------------------------------------
function Tracker:IsTracked(key)
	for _, k in ipairs(RA.db.tracked) do if k == key then return true end end
	return false
end

function Tracker:Toggle(entry)
	if not entry then return end
	local list = RA.db.tracked
	for i, k in ipairs(list) do
		if k == entry.key then
			table.remove(list, i)
			self:Refresh()
			if RA.UI and RA.UI.RequestRefresh then RA.UI:RequestRefresh() end
			return false
		end
	end
	if #list >= MAX_ROWS then
		RA:Print("отслеживать можно не больше " .. MAX_ROWS .. " рецептов.")
		return false
	end
	list[#list + 1] = entry.key
	RA.db.trackerHidden = false
	self:Refresh()
	if RA.UI and RA.UI.RequestRefresh then RA.UI:RequestRefresh() end
	return true
end

---------------------------------------------------------------------------
-- Sources with coordinates for one recipe (faction/holiday/class filters apply, source type filters don't)
---------------------------------------------------------------------------
local function collectPoints(entry)
	local points = {}
	local function addInfo(info, kind)
		if not info or not info.p then return end
		for _, p in ipairs(info.p) do
			points[#points + 1] = { name = info.n, mapFile = p.m, x = p.x, y = p.y, floor = p.f, kind = kind }
		end
	end
	for _, source in ipairs(entry.recipe.s or {}) do
		local kind = source.t
		if kind == "t" or kind == "v" or kind == "m" then
			for _, id in ipairs(source.n or {}) do
				if RA:IsSourceIDAllowed(kind, id) then addInfo(RA.Data.N[id], kind) end
			end
		elseif kind == "q" then
			for _, questID in ipairs(source.q or {}) do
				local quest = RA.Data.Q[questID]
				if quest and RA:IsSourceIDAllowed("q", questID) then
					for _, id in ipairs(quest.g or {}) do addInfo(RA.Data.N[id], "q") end
					for _, id in ipairs(quest.go or {}) do addInfo(RA.Data.O[id], "q") end
				end
			end
		elseif kind == "o" and #(source.o or {}) <= 6 then
			for _, id in ipairs(source.o or {}) do addInfo(RA.Data.O[id], "o") end
		end
	end
	return points
end

local function playerPosition()
	if not Astrolabe then return nil end
	local c, z, x, y = Astrolabe:GetCurrentPlayerPosition()
	if c and z and z > 0 and x then
		Tracker.lastPosition = { c, z, x, y }
	end
	local p = Tracker.lastPosition
	if p then return p[1], p[2], p[3], p[4] end
end

-- Nearest point: { point, distance in yards or nil }; falls back to a short text for other sources.
function Tracker:GetNearest(entry)
	local points = collectPoints(entry)
	local pc, pz, px, py = playerPosition()
	local best, bestDistance
	for _, point in ipairs(points) do
		local c, z = RA.Map and RA.Map:FindContinentZone(point.mapFile)
		local distance
		if pc and c and c == pc and Astrolabe then
			distance = Astrolabe:ComputeDistance(pc, pz, px, py, c, z, point.x, point.y)
		end
		if distance and (not bestDistance or distance < bestDistance) then
			best, bestDistance = point, distance
		elseif not best then
			best = point
		end
	end
	return best, bestDistance
end

local function fallbackText(entry)
	for _, source in ipairs(entry.recipe.s or {}) do
		if source.t == "w" then return "мировая добыча, мобы " .. source.lo .. "-" .. source.hi end
		if source.t == "d" then return "открытие при создании предметов" end
		if source.t == "i" then return "из предмета" end
		if source.t == "f" then return "рыбалка" end
		if source.t == "m" or source.t == "v" or source.t == "t" then
			local npc = source.n and RA.Data.N[source.n[1]]
			if npc and npc.z then return npc.z end
		end
	end
	if entry.recipe.hd then return "праздничные торговцы" end
	return "источник неизвестен"
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local function makeText(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local font, _, flags = fs:GetFont()
	if font then fs:SetFont(font, size, flags) end
	fs:SetTextColor(r, g, b)
	fs:SetJustifyH("LEFT")
	return fs
end

function Tracker:Create()
	if self.frame then return end
	local frame = CreateFrame("Frame", "RecipeAtlasTrackerFrame", UIParent)
	frame:SetWidth(WIDTH)
	frame:SetHeight(24)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(false)
	frame:Hide()
	self.frame = frame

	local header = CreateFrame("Button", nil, frame)
	header:SetHeight(20)
	header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
	header:SetBackdrop({ bgFile = WHITE })
	header:SetBackdropColor(0, 0, 0, 0.35)
	header:RegisterForDrag("LeftButton")
	header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	header:SetScript("OnDragStart", function() frame:StartMoving() end)
	header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		RA.db.trackerX, RA.db.trackerY = frame:GetLeft(), frame:GetTop()
		Tracker:Position()
	end)
	header:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			RA:ToggleWindow()
		else
			RA.db.trackerCollapsed = not RA.db.trackerCollapsed
			Tracker:Refresh()
		end
	end)
	header:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Отслеживание рецептов", 1, 0.82, 0.38)
		GameTooltip:AddLine("ЛКМ — свернуть/развернуть", 1, 1, 1)
		GameTooltip:AddLine("ПКМ — окно компаса", 1, 1, 1)
		GameTooltip:AddLine("Перетащите, чтобы передвинуть; /recipes track reset — вернуть под задания", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	header:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local line = header:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE); line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
	line:SetVertexColor(0.78, 0.55, 0.20, 0.9)
	local star = header:CreateTexture(nil, "ARTWORK")
	star:SetWidth(14); star:SetHeight(14)
	star:SetPoint("LEFT", header, "LEFT", 4, 0)
	star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
	local title = makeText(header, 11, 1, 0.82, 0.38)
	title:SetPoint("LEFT", star, "RIGHT", 4, 0)
	title:SetText("Рецепты")
	local collapse = makeText(header, 11, 0.8, 0.7, 0.5)
	collapse:SetPoint("RIGHT", header, "RIGHT", -6, 0)
	header.title, header.collapse = title, collapse
	self.header = header

	self.rows = {}
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", nil, frame)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -20 - (i - 1) * ROW_HEIGHT)
		row:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(row)
		bg:SetTexture(WHITE)
		bg:SetVertexColor(0, 0, 0, 0.25)
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints(row)
		highlight:SetTexture(WHITE)
		highlight:SetVertexColor(1, 0.85, 0.5, 0.08)
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetWidth(22); icon:SetHeight(22)
		icon:SetPoint("LEFT", row, "LEFT", 4, 0)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		local name = makeText(row, 11, 0.96, 0.86, 0.60)
		name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
		name:SetPoint("RIGHT", row, "RIGHT", -70, 0)
		local distance = makeText(row, 11, 0.55, 0.85, 1)
		distance:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -4)
		distance:SetJustifyH("RIGHT")
		local where = makeText(row, 10, 0.62, 0.60, 0.54)
		where:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 0)
		where:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		row.icon, row.name, row.distance, row.where = icon, name, distance, where
		row:SetScript("OnClick", function(self, mouseButton)
			local entry = self.entry
			if not entry then return end
			if mouseButton == "RightButton" then
				Tracker:Toggle(entry)
			elseif IsShiftKeyDown and IsShiftKeyDown() then
				if self.point and RA.Map then
					if RA.Map:HasTomTom() then RA.Map:AddWaypoint(self.point) else RA.Map:ShowRecipeOnMap(entry) end
				end
			elseif IsControlKeyDown and IsControlKeyDown() then
				if RA.Map then RA.Map:ShowRecipeOnMap(entry) end
			else
				RA.db.selectedProfession, RA.db.selectedSpell = entry.professionID, entry.spellID
				if RA.UI then
					RA.UI.pinFilter = nil
					RA.UI:Show()
					RA.UI:RefreshList(false)
					RA.UI:RefreshDetails()
					RA.UI:ScrollToSelected()
				end
			end
		end)
		row:SetScript("OnEnter", function(self)
			local entry = self.entry
			if not entry then return end
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(RA:GetSpellName(entry.spellID, entry.itemID), 1, 0.82, 0.38)
			GameTooltip:AddLine(RA:GetProfessionName(entry.professionID) .. ", навык " .. entry.rank, 0.8, 0.8, 0.8)
			if self.point then
				GameTooltip:AddLine((self.point.name or "?") .. " — " .. (kindLabel[self.point.kind] or ""), 1, 1, 1)
			end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("ЛКМ — открыть в компасе", 0.55, 0.80, 1.00)
			GameTooltip:AddLine("Ctrl+ЛКМ — показать на карте", 0.55, 0.80, 1.00)
			if RA.Map and RA.Map:HasTomTom() then GameTooltip:AddLine("Shift+ЛКМ — точка TomTom к ближайшему", 0.55, 0.80, 1.00) end
			GameTooltip:AddLine("ПКМ — перестать отслеживать", 0.55, 0.80, 1.00)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row:Hide()
		self.rows[i] = row
	end

	local ticker = CreateFrame("Frame", nil, frame)
	ticker:SetScript("OnUpdate", function(_, elapsed)
		Tracker.elapsed = (Tracker.elapsed or 0) + (elapsed or 0)
		if Tracker.elapsed >= 1 then
			Tracker.elapsed = 0
			Tracker:Position()        -- the quest list grows and shrinks
			Tracker:UpdateRows()
		end
	end)
end

local function formatDistance(yards)
	if yards >= 1000 then return string.format("%.1f тыс. ярд.", yards / 1000) end
	return string.format("%d ярд.", yards)
end

-- Full refresh: drops learned recipes, shows or hides the frame.
function Tracker:Refresh()
	if not RA.db then return end
	if not self.frame then self:Create() end
	local list = RA.db.tracked
	for i = #list, 1, -1 do
		local entry = RA.recipeByKey and RA.recipeByKey[list[i]]
		if not entry then
			table.remove(list, i)
		elseif RA:IsKnown(entry.professionID, entry.spellID) then
			table.remove(list, i)
			RA:Print("рецепт изучен: " .. RA:GetSpellName(entry.spellID, entry.itemID) .. " — убран из отслеживания.")
		end
	end
	if #list == 0 or RA.db.trackerHidden then
		self.frame:Hide()
		return
	end
	self.frame:Show()
	self:Position()
	self:UpdateRows()
end

---------------------------------------------------------------------------
-- Placement: glued under the quest tracker (Sirus' retail-style ObjectiveTrackerFrame
-- or the stock WatchFrame) unless the player dragged the panel somewhere else.
---------------------------------------------------------------------------
local TRACKER_FRAMES = { "ObjectiveTrackerFrame", "WatchFrame", "QuestWatchFrame" }

function Tracker:FindQuestTracker()
	for _, name in ipairs(TRACKER_FRAMES) do
		local frame = _G[name]
		if frame and frame.IsShown and frame:IsShown() and frame:GetLeft() then return frame, name end
	end
end

-- Lowest visible content inside the tracker (its own frame is often stretched to the screen bottom).
local function contentBottom(tracker)
	local top = tracker:GetTop()
	if not top then return nil end
	local fullHeight = tracker:GetHeight() or 0
	local lowest
	local function scan(frame, depth)
		if depth > 4 or not frame.GetChildren then return end
		for _, child in ipairs({ frame:GetChildren() }) do
			if child:IsShown() and child ~= Tracker.frame then
				local bottom, height = child:GetBottom(), child:GetHeight() or 0
				if bottom and height > 2 and height < fullHeight * 0.8 then
					if not lowest or bottom < lowest then lowest = bottom end
				end
				scan(child, depth + 1)
			end
		end
	end
	scan(tracker, 1)
	if not lowest or lowest > top then return top end
	return lowest
end

function Tracker:Position()
	local frame = self.frame
	if not frame then return end
	frame:ClearAllPoints()
	if RA.db.trackerX then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", RA.db.trackerX, RA.db.trackerY)
		return
	end
	local tracker = self:FindQuestTracker()
	if tracker then
		local scale = tracker:GetEffectiveScale() / frame:GetEffectiveScale()
		local bottom = contentBottom(tracker) or tracker:GetTop()
		local left = tracker:GetLeft()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * scale, bottom * scale - 10)
		local width = (tracker:GetWidth() or WIDTH) * scale
		frame:SetWidth(math.max(200, math.min(320, width)))
		frame:SetFrameStrata(tracker:GetFrameStrata() == "BACKGROUND" and "LOW" or tracker:GetFrameStrata())
		frame:SetFrameLevel((tracker:GetFrameLevel() or 1) + 10)
	else
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -260)
		frame:SetWidth(WIDTH)
	end
end

function Tracker:UpdateRows()
	if not self.frame or not self.frame:IsShown() then return end
	local list = RA.db.tracked
	local collapsed = RA.db.trackerCollapsed
	self.header.title:SetText("Рецепты (" .. #list .. ")")
	self.header.collapse:SetText(collapsed and "+" or "-")
	local shown = 0
	for i, row in ipairs(self.rows) do
		local entry = not collapsed and RA.recipeByKey[list[i] or ""]
		row.entry = entry or nil
		if entry then
			shown = shown + 1
			row.icon:SetTexture(RA:GetSpellTexture(entry.spellID, entry.itemID, entry.craftedID))
			row.name:SetText(RA:GetSpellName(entry.spellID, entry.itemID))
			local point, distance = self:GetNearest(entry)
			row.point = point
			if point then
				local zone = RA.Map and RA.Map:GetZoneName(point.mapFile) or point.mapFile
				row.where:SetText((point.name or "?") .. ", " .. (zone or "?") .. string.format(" (%.0f, %.0f)", point.x * 100, point.y * 100))
				row.distance:SetText(distance and formatDistance(distance) or "")
			else
				row.where:SetText(fallbackText(entry))
				row.distance:SetText("")
			end
			row:Show()
		else
			row:Hide()
		end
	end
	self.frame:SetHeight(20 + shown * ROW_HEIGHT)
end

function Tracker:OnDataChanged()
	if RA.db then self:Refresh() end
end
