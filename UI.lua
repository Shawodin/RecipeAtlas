local RA = _G.RecipeAtlas
RA.UI = RA.UI or {}
local UI = RA.UI

local ROW_HEIGHT, ROW_COUNT = 32, 11
local lower = string.lower
local function safeLower(text) return text and (strlower or lower)(text) or "" end
local function setSize(region, w, h) region:SetWidth(w); region:SetHeight(h or w) end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLD, GREY, GREEN, ORANGE, BLUE, RED = "|cffffd27a", "|cff9a948a", "|cff71d78a", "|cffff9040", "|cff8cc8ff", "|cffff6060"
local PANEL_BACKDROP = { bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 } }

local function makeText(parent, text, template, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
	if size then
		local font, _, flags = fs:GetFont()
		if font then fs:SetFont(font, size, flags) end
	end
	if color then fs:SetTextColor(color[1], color[2], color[3]) end
	fs:SetText(text or "")
	return fs
end

local function makePanel(parent, r, g, b, a)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetBackdrop(PANEL_BACKDROP)
	panel:SetBackdropColor(r or 0.05, g or 0.045, b or 0.035, a or 0.9)
	panel:SetBackdropBorderColor(0.42, 0.32, 0.17, 0.9)
	return panel
end

local function makeButton(parent, text, width, height)
	local button = CreateFrame("Button", nil, parent)
	setSize(button, width, height)
	button:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
	button:SetBackdropColor(0.16, 0.11, 0.05, 0.95)
	button:SetBackdropBorderColor(0.62, 0.45, 0.20, 0.9)
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetPoint("TOPLEFT", 2, -2); highlight:SetPoint("BOTTOMRIGHT", -2, 2)
	highlight:SetTexture(WHITE)
	highlight:SetVertexColor(1, 0.75, 0.3, 0.14)
	button.text = makeText(button, text, "GameFontNormal", 11, { 0.96, 0.84, 0.56 })
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetScript("OnMouseDown", function(self) if self:IsEnabled() == 1 or self:IsEnabled() == true then self.text:SetPoint("CENTER", self, "CENTER", 1, -1) end end)
	button:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", self, "CENTER", 0, 0) end)
	button.SetLabel = function(self, label) self.text:SetText(label) end
	button.SetEnabledState = function(self, enabled)
		if enabled then
			self:Enable(); self.text:SetTextColor(0.96, 0.84, 0.56); self:SetBackdropBorderColor(0.62, 0.45, 0.20, 0.9)
		else
			self:Disable(); self.text:SetTextColor(0.45, 0.42, 0.38); self:SetBackdropBorderColor(0.3, 0.26, 0.2, 0.7)
		end
	end
	return button
end

local function makeLine(parent, y, left, right)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE)
	line:SetVertexColor(0.55, 0.39, 0.16, 0.45)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", parent, "TOPLEFT", left or 8, y)
	line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(right or 8), y)
	return line
end

local function setTooltip(frame, title, text)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(title, 1, 0.82, 0.35)
		if text then GameTooltip:AddLine(type(text) == "function" and text() or text, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Text checkbox. getter/setter default to RA.db[key].
local function makeCheck(parent, label, key, title, text, getter, setter)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(18)
	local box = button:CreateTexture(nil, "ARTWORK")
	setSize(box, 16)
	box:SetPoint("LEFT", button, "LEFT", 0, 0)
	box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
	local mark = button:CreateTexture(nil, "OVERLAY")
	setSize(mark, 16)
	mark:SetPoint("CENTER", box, "CENTER")
	mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	local fs = makeText(button, label, "GameFontHighlightSmall", 11, { 0.88, 0.84, 0.72 })
	fs:SetPoint("LEFT", box, "RIGHT", 4, 0)
	fs:SetPoint("RIGHT", button, "RIGHT", 0, 0)
	fs:SetJustifyH("LEFT")
	button.mark, button.key, button.label = mark, key, fs
	button.Get = getter or function(self) return RA.db[self.key] end
	button.Toggle = setter or function(self) RA.db[self.key] = not RA.db[self.key] end
	button:SetScript("OnClick", function(self)
		self:Toggle()
		RA:RefreshAll()
	end)
	if title then setTooltip(button, title, text) end
	button.Update = function(self) if self:Get() then self.mark:Show() else self.mark:Hide() end end
	return button
end

-- Slim vertical scrollbar without arrow buttons; hides itself when there is nothing to scroll.
local function makeScrollBar(parent, onChange)
	local bar = CreateFrame("Slider", nil, parent)
	bar:SetWidth(8)
	bar:SetOrientation("VERTICAL")
	bar:SetBackdrop({ bgFile = WHITE })
	bar:SetBackdropColor(0, 0, 0, 0.35)
	local thumb = bar:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(WHITE)
	thumb:SetVertexColor(0.78, 0.56, 0.24, 0.85)
	setSize(thumb, 8, 40)
	bar:SetThumbTexture(thumb)
	bar.thumb = thumb
	bar:SetMinMaxValues(0, 0)
	bar:SetValueStep(1)
	bar:SetValue(0)
	bar:EnableMouse(true)
	bar:EnableMouseWheel(true)
	bar:SetScript("OnValueChanged", function(self, value)
		if self.updating then return end
		onChange(value)
	end)
	-- visible / total in "units"; the thumb gets a proportional height
	bar.SetRange = function(self, maxValue, visible, total)
		maxValue = math.max(0, maxValue or 0)
		self.updating = true
		self:SetMinMaxValues(0, maxValue)
		if (self:GetValue() or 0) > maxValue then self:SetValue(maxValue) end
		self.updating = false
		local trackHeight = self:GetHeight() or 100
		if total and total > 0 and visible then
			self.thumb:SetHeight(math.max(24, math.min(trackHeight, trackHeight * visible / total)))
		end
		if maxValue > 0 then self:Show() else self:Hide() end
	end
	bar.SetValueQuiet = function(self, value)
		self.updating = true
		self:SetValue(value)
		self.updating = false
	end
	return bar
end

local function cropIcon(texture) texture:SetTexCoord(0.07, 0.93, 0.07, 0.93) end

local function professionIcon(profession)
	local _, _, texture = GetSpellInfo(profession.ability)
	return texture or "Interface\\Icons\\INV_Misc_Book_09"
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------
function UI:Create()
	if self.frame then return end
	local frame = CreateFrame("Frame", "RecipeAtlasMainFrame", UIParent)
	setSize(frame, 860, 540)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = false, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	frame:SetBackdropColor(0.07, 0.06, 0.05, 0.97)
	frame:SetPoint("CENTER", UIParent, "CENTER", RA.db.windowX, RA.db.windowY)
	frame:Hide()
	frame:SetScript("OnShow", function() if UI.dirty then UI:Refresh() end end)
	frame:SetScript("OnHide", function() if UI.filterPopup then UI.filterPopup:Hide() end end)
	self.frame = frame

	-- Header ----------------------------------------------------------------
	local top = CreateFrame("Frame", nil, frame)
	top:SetHeight(44)
	top:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
	top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
	top:SetBackdrop({ bgFile = WHITE })
	top:SetBackdropColor(0.13, 0.10, 0.07, 0.95)
	top:EnableMouse(true)
	top:RegisterForDrag("LeftButton")
	top:SetScript("OnDragStart", function() frame:StartMoving() end)
	top:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local cx, cy = frame:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if cx and ux then
			RA.db.windowX, RA.db.windowY = cx - ux, cy - uy
			frame:ClearAllPoints()
			frame:SetPoint("CENTER", UIParent, "CENTER", RA.db.windowX, RA.db.windowY)
		end
	end)
	local goldLine = top:CreateTexture(nil, "ARTWORK")
	goldLine:SetTexture(WHITE)
	goldLine:SetHeight(1)
	goldLine:SetPoint("BOTTOMLEFT"); goldLine:SetPoint("BOTTOMRIGHT")
	goldLine:SetVertexColor(0.78, 0.55, 0.20, 0.9)
	local logo = top:CreateTexture(nil, "ARTWORK")
	setSize(logo, 30)
	logo:SetPoint("LEFT", top, "LEFT", 10, 0)
	logo:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
	cropIcon(logo)
	local title = makeText(top, "Рецептный компас", "GameFontNormalLarge", 16, { 1.00, 0.80, 0.36 })
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 9, -1)
	local subtitle = makeText(top, "Неизученные рецепты, где их взять и метки на карте", "GameFontHighlightSmall", 10, { 0.70, 0.67, 0.60 })
	subtitle:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 9, 1)
	local close = CreateFrame("Button", nil, top, "UIPanelCloseButton")
	close:SetPoint("RIGHT", top, "RIGHT", 2, 0)
	close:SetScript("OnClick", function() frame:Hide() end)

	local PANEL_TOP, PANEL_HEIGHT = -56, 446

	-- Left column: professions --------------------------------------------
	local left = makePanel(frame)
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, PANEL_TOP)
	setSize(left, 186, PANEL_HEIGHT)
	local professionHeader = makeText(left, "Профессии", "GameFontNormal", 12, { 0.95, 0.76, 0.38 })
	professionHeader:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -11)
	local countHeader = makeText(left, "не изучено", "GameFontDisableSmall", 9, { 0.55, 0.52, 0.46 })
	countHeader:SetPoint("TOPRIGHT", left, "TOPRIGHT", -12, -13)
	makeLine(left, -29)
	self.professionRows = {}
	for index, profession in ipairs(RA.Professions) do
		local row = CreateFrame("Button", nil, left)
		row:SetHeight(26)
		row:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -33 - (index - 1) * 26)
		row:SetPoint("TOPRIGHT", left, "TOPRIGHT", -6, -33 - (index - 1) * 26)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(row)
		bg:SetTexture(WHITE)
		bg:SetVertexColor(0.78, 0.55, 0.20, 0.13)
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints(row)
		highlight:SetTexture(WHITE)
		highlight:SetVertexColor(1, 0.85, 0.5, 0.08)
		local icon = row:CreateTexture(nil, "ARTWORK")
		setSize(icon, 20)
		icon:SetPoint("LEFT", row, "LEFT", 4, 0)
		icon:SetTexture(professionIcon(profession))
		cropIcon(icon)
		local count = makeText(row, "", "GameFontHighlightSmall", 11, { 0.85, 0.80, 0.65 })
		count:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		count:SetJustifyH("RIGHT")
		local label = makeText(row, RA:GetProfessionName(profession.id), "GameFontHighlightSmall", 11, { 0.82, 0.82, 0.78 })
		label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
		label:SetPoint("RIGHT", count, "LEFT", -4, 0)
		label:SetJustifyH("LEFT")
		row.professionID, row.bg, row.icon, row.label, row.count = profession.id, bg, icon, label, count
		row:SetScript("OnClick", function(button, mouseButton)
			local id = button.professionID
			if mouseButton == "RightButton" then
				for _, p in ipairs(RA.Professions) do RA.db.showProf[p.id] = (p.id == id) end
			else
				RA.db.showProf[id] = not RA.db.showProf[id]
			end
			UI.pinFilter = nil
			RA:RefreshAll()
		end)
		row:SetScript("OnEnter", function(button)
			local id = button.professionID
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(RA:GetProfessionName(id), 1, 0.82, 0.35)
			local known = 0
			for spellID in pairs(RA.Data.P[id] or {}) do if RA:IsKnown(id, spellID) then known = known + 1 end end
			local total = RA.recipeTotals[id] or 0
			if RA.db.scanned[id] then
				GameTooltip:AddLine(string.format("Изучено рецептов из базы: %d из %d", known, total), 1, 1, 1)
				if RA.db.partial[id] then GameTooltip:AddLine("Сканирование неполное — откройте окно профессии ещё раз.", 1, 0.55, 0.3, true) end
			else
				GameTooltip:AddLine("Ещё не просканирована. Если это ваша профессия, откройте её окно — компас запомнит изученные рецепты. Пока серым показано, сколько всего рецептов в базе.", 1, 0.7, 0.4, true)
			end
			local rank = RA:GetProfessionRank(id)
			if rank then GameTooltip:AddLine("Навык: " .. rank, 0.8, 0.8, 0.8) end
			GameTooltip:AddLine("ЛКМ — показать/скрыть, ПКМ — только эта профессия", 0.55, 0.80, 1.00)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		self.professionRows[index] = row
	end
	makeLine(left, -33 - #RA.Professions * 26 - 6)

	local scanButton = makeButton(left, "Сканировать профессию", 166, 24)
	scanButton:SetPoint("BOTTOM", left, "BOTTOM", 0, 34)
	scanButton:SetScript("OnClick", function() RA:ScanCurrentTradeSkill(true) end)
	setTooltip(scanButton, "Сканировать открытую профессию",
		"Обычно не нужно: компас сам сканирует профессию при открытии её окна и после изучения нового рецепта.")
	self.scanButton = scanButton

	local mapToggle = makeCheck(left, "Метки на карте", "markerEnabled", "Метки на карте",
		"Значки торговцев, наставников, добычи и заданий на карте мира и миникарте.")
	mapToggle:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 12, 11)
	mapToggle:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -8, 11)
	self.mapToggle = mapToggle

	-- Center column: search, filters and list -----------------------------
	local center = makePanel(frame, 0.04, 0.035, 0.03, 0.92)
	center:SetPoint("TOPLEFT", frame, "TOPLEFT", 202, PANEL_TOP)
	setSize(center, 344, PANEL_HEIGHT)
	self.center = center

	local searchBox = CreateFrame("Frame", nil, center)
	searchBox:SetHeight(24)
	searchBox:SetPoint("TOPLEFT", center, "TOPLEFT", 8, -8)
	searchBox:SetPoint("TOPRIGHT", center, "TOPRIGHT", -8, -8)
	searchBox:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 } })
	searchBox:SetBackdropColor(0, 0, 0, 0.55)
	searchBox:SetBackdropBorderColor(0.45, 0.36, 0.22, 0.9)
	local search = CreateFrame("EditBox", "RecipeAtlasSearchBox", searchBox)
	search:SetPoint("TOPLEFT", searchBox, "TOPLEFT", 8, -2)
	search:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", -24, 2)
	search:SetAutoFocus(false)
	search:SetFontObject(ChatFontSmall or GameFontHighlightSmall)
	search:SetTextColor(0.95, 0.92, 0.85)
	search:SetMaxLetters(60)
	local placeholder = makeText(searchBox, "Поиск: рецепт, NPC, задание...", "GameFontDisableSmall", 11, { 0.48, 0.46, 0.42 })
	placeholder:SetPoint("LEFT", search, "LEFT", 1, 0)
	search.placeholder = placeholder
	local clear = CreateFrame("Button", nil, searchBox)
	setSize(clear, 16)
	clear:SetPoint("RIGHT", searchBox, "RIGHT", -5, 0)
	local clearText = makeText(clear, "x", "GameFontNormal", 12, { 0.75, 0.65, 0.5 })
	clearText:SetPoint("CENTER", clear, "CENTER", 0, 1)
	clear:SetScript("OnClick", function()
		search:SetText(""); search:ClearFocus()
		RA.db.query = ""
		UI:RefreshList(true)
	end)
	clear:Hide()
	search.clear = clear
	search:SetScript("OnTextChanged", function(box, userInput)
		local text = box:GetText() or ""
		if text == "" then placeholder:Show(); clear:Hide() else placeholder:Hide(); clear:Show() end
		if userInput then
			RA.db.query = text
			RA:After(0.2, "search", function() UI:RefreshList(true) end)
		end
	end)
	search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
	self.search = search

	local filter = makeButton(center, "Фильтры", 104, 22)
	filter:SetPoint("TOPLEFT", center, "TOPLEFT", 8, -37)
	filter:SetScript("OnClick", function() UI:ToggleFilterPopup() end)
	setTooltip(filter, "Фильтры", "Типы источников, навык, фракция, класс и праздники.")
	self.filterButton = filter

	-- Status line / pin filter chip
	local status = CreateFrame("Button", nil, center)
	status:SetHeight(22)
	status:SetPoint("LEFT", filter, "RIGHT", 8, 0)
	status:SetPoint("RIGHT", center, "RIGHT", -10, 0)
	local statusText = makeText(status, "", "GameFontHighlightSmall", 11, { 0.78, 0.74, 0.64 })
	statusText:SetPoint("LEFT", status, "LEFT", 0, 0)
	statusText:SetPoint("RIGHT", status, "RIGHT", 0, 0)
	statusText:SetJustifyH("RIGHT")
	status.text = statusText
	status:SetScript("OnClick", function()
		if UI.pinFilter then UI.pinFilter = nil; UI:RefreshList(true) end
		if RA.Map and RA.Map.focus then RA.Map:SetFocus(nil) end
	end)
	self.status = status
	makeLine(center, -65, 6, 6)

	local listArea = CreateFrame("Frame", nil, center)
	listArea:SetPoint("TOPLEFT", center, "TOPLEFT", 5, -69)
	listArea:SetPoint("BOTTOMRIGHT", center, "BOTTOMRIGHT", -16, 5)
	listArea:EnableMouseWheel(true)
	self.listArea = listArea
	self.offset = 0
	local listBar = makeScrollBar(center, function(value)
		UI.offset = math.floor(value + 0.5)
		UI:RefreshRows()
	end)
	listBar:SetPoint("TOPRIGHT", center, "TOPRIGHT", -5, -70)
	listBar:SetPoint("BOTTOMRIGHT", center, "BOTTOMRIGHT", -5, 6)
	self.listBar = listBar
	local function wheel(_, delta)
		local maxOffset = math.max(0, #(UI.list or {}) - ROW_COUNT)
		local offset = math.max(0, math.min(maxOffset, UI.offset - delta * 3))
		if offset ~= UI.offset then
			UI.offset = offset
			listBar:SetValueQuiet(offset)
			UI:RefreshRows()
		end
	end
	listArea:SetScript("OnMouseWheel", wheel)
	listBar:SetScript("OnMouseWheel", wheel)

	local empty = makeText(listArea, "", "GameFontDisableSmall", 11, { 0.6, 0.58, 0.52 })
	empty:SetPoint("TOP", listArea, "TOP", 0, -40)
	empty:SetWidth(280)
	self.emptyText = empty

	self.rows = {}
	for index = 1, ROW_COUNT do
		local row = CreateFrame("Button", nil, listArea)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		row:SetPoint("RIGHT", listArea, "RIGHT", 0, 0)
		row:EnableMouseWheel(true)
		row:SetScript("OnMouseWheel", wheel)
		local stripe = row:CreateTexture(nil, "BACKGROUND")
		stripe:SetAllPoints(row)
		stripe:SetTexture(WHITE)
		stripe:SetVertexColor(1, 1, 1, index % 2 == 0 and 0.025 or 0)
		local selected = row:CreateTexture(nil, "BORDER")
		selected:SetAllPoints(row)
		selected:SetTexture(WHITE)
		selected:SetVertexColor(0.85, 0.6, 0.2, 0.22)
		selected:Hide()
		local selectedBar = row:CreateTexture(nil, "ARTWORK")
		selectedBar:SetPoint("TOPLEFT"); selectedBar:SetPoint("BOTTOMLEFT")
		selectedBar:SetWidth(2)
		selectedBar:SetTexture(WHITE)
		selectedBar:SetVertexColor(1, 0.78, 0.3, 0.9)
		selectedBar:Hide()
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints(row)
		highlight:SetTexture(WHITE)
		highlight:SetVertexColor(1, 0.85, 0.5, 0.07)
		local iconBorder = row:CreateTexture(nil, "ARTWORK")
		setSize(iconBorder, 26)
		iconBorder:SetPoint("LEFT", row, "LEFT", 6, 0)
		iconBorder:SetTexture(WHITE)
		iconBorder:SetVertexColor(0, 0, 0, 0.8)
		local icon = row:CreateTexture(nil, "OVERLAY")
		setSize(icon, 24)
		icon:SetPoint("CENTER", iconBorder, "CENTER")
		cropIcon(icon)
		local name = makeText(row, "", "GameFontHighlightSmall", 11, { 0.91, 0.87, 0.73 })
		name:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", 8, -1)
		name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		name:SetJustifyH("LEFT")
		local info = makeText(row, "", "GameFontDisableSmall", 10, { 0.58, 0.56, 0.50 })
		info:SetPoint("BOTTOMLEFT", iconBorder, "BOTTOMRIGHT", 8, 1)
		info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		info:SetJustifyH("LEFT")
		local star = row:CreateTexture(nil, "OVERLAY")
		setSize(star, 12)
		star:SetPoint("TOPRIGHT", row, "TOPRIGHT", -3, -3)
		star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
		star:Hide()
		row.star = star
		name:SetPoint("RIGHT", row, "RIGHT", -18, 0)
		row.icon, row.name, row.info, row.selected, row.selectedBar = icon, name, info, selected, selectedBar
		row:SetScript("OnClick", function(button)
			local entry = button.entry
			if not entry then return end
			if IsModifiedClick and IsModifiedClick("CHATLINK") then
				local link = RA:GetRecipeLink(entry.spellID, entry.itemID)
				if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
				return
			end
			if IsAltKeyDown and IsAltKeyDown() and RA.Tracker then
				RA.Tracker:Toggle(entry)
			end
			RA.db.selectedProfession, RA.db.selectedSpell = entry.professionID, entry.spellID
			UI:RefreshDetails()
			UI:RefreshRows()
		end)
		row:SetScript("OnEnter", function(button)
			local entry = button.entry
			if not entry then return end
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			if entry.itemID and entry.itemID > 0 and GetItemInfo(entry.itemID) then
				GameTooltip:SetHyperlink("item:" .. entry.itemID)
			else
				GameTooltip:SetHyperlink("spell:" .. entry.spellID)
			end
			GameTooltip:AddLine("Shift+клик — ссылка в чат, Alt+клик — отслеживать", 0.55, 0.80, 1.00)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		self.rows[index] = row
	end

	-- Right column: details ----------------------------------------------
	local detail = makePanel(frame)
	detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 552, PANEL_TOP)
	setSize(detail, 298, PANEL_HEIGHT)
	local iconBorder = detail:CreateTexture(nil, "ARTWORK")
	setSize(iconBorder, 40)
	iconBorder:SetPoint("TOPLEFT", detail, "TOPLEFT", 10, -10)
	iconBorder:SetTexture(WHITE)
	iconBorder:SetVertexColor(0.62, 0.45, 0.20, 0.9)
	local detailIcon = detail:CreateTexture(nil, "OVERLAY")
	setSize(detailIcon, 38)
	detailIcon:SetPoint("CENTER", iconBorder, "CENTER")
	cropIcon(detailIcon)
	local detailTitle = makeText(detail, "Выберите рецепт", "GameFontNormal", 13, { 1.0, 0.82, 0.40 })
	detailTitle:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", 9, -1)
	detailTitle:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
	detailTitle:SetJustifyH("LEFT")
	detailTitle:SetJustifyV("TOP")
	detailTitle:SetHeight(30)
	local detailSub = makeText(detail, "", "GameFontHighlightSmall", 10, { 0.66, 0.63, 0.56 })
	detailSub:SetPoint("BOTTOMLEFT", iconBorder, "BOTTOMRIGHT", 9, 0)
	detailSub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
	detailSub:SetJustifyH("LEFT")
	makeLine(detail, -58)

	local detailScroll = CreateFrame("ScrollFrame", "RecipeAtlasDetailScroll", detail)
	detailScroll:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -64)
	detailScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -18, 42)
	local detailChild = CreateFrame("Frame", nil, detailScroll)
	setSize(detailChild, 266, 300)
	detailScroll:SetScrollChild(detailChild)
	local detailText = makeText(detailChild, "", "GameFontHighlightSmall", 11, { 0.85, 0.83, 0.76 })
	detailText:SetPoint("TOPLEFT", detailChild, "TOPLEFT", 0, 0)
	detailText:SetWidth(266)
	detailText:SetJustifyH("LEFT")
	detailText:SetJustifyV("TOP")
	detailText:SetSpacing(3)
	local detailBar = makeScrollBar(detail, function(value) detailScroll:SetVerticalScroll(value) end)
	detailBar:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -6, -64)
	detailBar:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -6, 42)
	detailBar:SetValueStep(1)
	detailScroll:EnableMouseWheel(true)
	local function detailWheel(_, delta)
		local _, maxValue = detailBar:GetMinMaxValues()
		local value = math.max(0, math.min(maxValue or 0, (detailBar:GetValue() or 0) - delta * 36))
		detailBar:SetValue(value)
	end
	detailScroll:SetScript("OnMouseWheel", detailWheel)
	detailBar:SetScript("OnMouseWheel", detailWheel)
	self.detailIcon, self.detailTitle, self.detailSub, self.detailScroll, self.detailChild, self.detailText, self.detailBar =
		detailIcon, detailTitle, detailSub, detailScroll, detailChild, detailText, detailBar

	makeLine(detail, -(PANEL_HEIGHT - 38))
	local mapButton = makeButton(detail, "На карте", 88, 24)
	mapButton:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 9, 9)
	mapButton:SetScript("OnClick", function() UI:ShowSelectedOnMap() end)
	setTooltip(mapButton, "Показать на карте", "Открывает карту и оставляет на ней только источники этого рецепта. Повторное нажатие — вернуть все метки.")
	local trackButton = makeButton(detail, "Отслеживать", 104, 24)
	trackButton:SetPoint("BOTTOM", detail, "BOTTOM", 0, 9)
	trackButton:SetScript("OnClick", function()
		local entry = UI:GetSelectedEntry()
		if not RA.Tracker then
			RA:Print("|cffff6060модуль отслеживания не загружен.|r Полностью перезапустите игру (/reload не поможет): новые файлы аддона подхватываются только при запуске.")
			return
		end
		if entry then RA.Tracker:Toggle(entry); UI:RefreshDetails() end
	end)
	setTooltip(trackButton, "Отслеживать рецепт", "Рецепт появится на экране, как отслеживаемое задание: ближайший источник и расстояние до него. Изученные рецепты убираются сами. Alt+клик по строке списка — то же самое.")
	self.trackButton = trackButton
	local linkButton = makeButton(detail, "В чат", 88, 24)
	linkButton:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -9, 9)
	linkButton:SetScript("OnClick", function()
		local entry = UI:GetSelectedEntry()
		if not entry then return end
		local link = RA:GetRecipeLink(entry.spellID, entry.itemID)
		if not link then return end
		if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
			ChatEdit_InsertLink(link)
		elseif ChatFrame_OpenChat then
			ChatFrame_OpenChat(link)
		end
	end)
	self.mapButton, self.linkButton = mapButton, linkButton

	local footer = makeText(frame, "", "GameFontDisableSmall", 10, { 0.60, 0.58, 0.52 })
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
	footer:SetJustifyH("LEFT")
	self.footer = footer

	tinsert(UISpecialFrames, frame:GetName())
	self.dirty = true
end

---------------------------------------------------------------------------
-- Filter popup: source types + visibility options
---------------------------------------------------------------------------
local OPTION_DEFS = {
	{ "Только доступные по навыку", "hideAboveSkill", "Скрывает рецепты, которым нужен навык выше вашего." },
	{ "Только моя фракция", "hideOpposingFaction", "Скрывает торговцев, наставников, задания и рецепты другой фракции." },
	{ "Только для моего класса", "hideOtherClass", "Скрывает рецепты, которые может изучить только другой класс (например, классовые инженерные очки)." },
	{ "Только идущие праздники", "hideInactiveHolidays", "Скрывает праздничные рецепты и источники, если праздник сейчас не идёт (по игровому календарю)." },
}

function UI:ToggleFilterPopup()
	if not self.filterPopup then
		local popup = CreateFrame("Frame", nil, self.frame)
		popup:SetFrameStrata("FULLSCREEN_DIALOG")
		popup:SetBackdrop(PANEL_BACKDROP)
		popup:SetBackdropColor(0.07, 0.06, 0.045, 0.98)
		popup:SetBackdropBorderColor(0.62, 0.45, 0.20, 0.95)
		popup:EnableMouse(true)
		local sourceCount, optionCount = #RA.SourceOrder, #OPTION_DEFS
		setSize(popup, 230, 30 + sourceCount * 18 + 26 + optionCount * 18 + 40)
		popup:SetPoint("TOPLEFT", self.filterButton, "BOTTOMLEFT", 0, -3)
		local header = makeText(popup, "Источники", "GameFontNormal", 11, { 0.95, 0.76, 0.38 })
		header:SetPoint("TOPLEFT", popup, "TOPLEFT", 11, -9)
		popup.checks = {}
		local y = -26
		for _, kind in ipairs(RA.SourceOrder) do
			local check = makeCheck(popup, RA.SourceLabels[kind] .. (RA.MapSourceTypes[kind] and "" or "  |cff777777(без меток)|r"), kind, nil, nil,
				function(self) return RA.db.sourceEnabled[self.key] end,
				function(self) RA.db.sourceEnabled[self.key] = not RA.db.sourceEnabled[self.key] end)
			check:SetPoint("TOPLEFT", popup, "TOPLEFT", 11, y)
			check:SetPoint("RIGHT", popup, "RIGHT", -8, 0)
			popup.checks[#popup.checks + 1] = check
			y = y - 18
		end
		y = y - 6
		local optionHeader = makeText(popup, "Показывать", "GameFontNormal", 11, { 0.95, 0.76, 0.38 })
		optionHeader:SetPoint("TOPLEFT", popup, "TOPLEFT", 11, y)
		y = y - 18
		for _, def in ipairs(OPTION_DEFS) do
			local check = makeCheck(popup, def[1], def[2], def[1], def[3])
			check:SetPoint("TOPLEFT", popup, "TOPLEFT", 11, y)
			check:SetPoint("RIGHT", popup, "RIGHT", -8, 0)
			popup.checks[#popup.checks + 1] = check
			y = y - 18
		end
		local all = makeButton(popup, "Все источники", 112, 20)
		all:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 8, 8)
		all:SetScript("OnClick", function()
			for _, kind in ipairs(RA.SourceOrder) do RA.db.sourceEnabled[kind] = true end
			RA:RefreshAll()
		end)
		local done = makeButton(popup, "Готово", 90, 20)
		done:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -8, 8)
		done:SetScript("OnClick", function() popup:Hide() end)
		popup:Hide()
		self.filterPopup = popup
		self.sourcePopup = popup          -- old name, kept for compatibility
	end
	if self.filterPopup:IsShown() then self.filterPopup:Hide() else self.filterPopup:Show(); self:UpdateFilterPopup() end
end
UI.ToggleSourcePopup = UI.ToggleFilterPopup

function UI:UpdateFilterPopup()
	if not self.filterPopup then return end
	for _, check in ipairs(self.filterPopup.checks) do check:Update() end
end

---------------------------------------------------------------------------
-- Showing and refreshing
---------------------------------------------------------------------------
function UI:Show()
	if not self.frame then self:Create() end
	-- Above the fullscreen world map when it is open, normal dialog level otherwise.
	self.frame:SetFrameStrata(WorldMapFrame and WorldMapFrame:IsShown() and "FULLSCREEN_DIALOG" or "DIALOG")
	self.frame:Show()
	self.frame:Raise()
	if self.dirty then self:Refresh() end
end

function UI:RequestRefresh()
	self.dirty = true
	if self.frame and self.frame:IsShown() then
		RA:After(0.05, "uiRefresh", function() UI:Refresh() end)
	end
end

function UI:Refresh()
	if not self.frame then return end
	self.dirty = false
	self.mapToggle:Update()
	self:UpdateFilterPopup()
	local disabled = 0
	for _, kind in ipairs(RA.SourceOrder) do if not RA.db.sourceEnabled[kind] then disabled = disabled + 1 end end
	self.filterButton:SetLabel(disabled == 0 and "Фильтры" or ("Фильтры |cffff9040•|r " .. (#RA.SourceOrder - disabled) .. "/" .. #RA.SourceOrder))
	if self.search:GetText() ~= RA.db.query then self.search:SetText(RA.db.query) end
	if RA.db.query == "" then self.search.placeholder:Show(); self.search.clear:Hide()
	else self.search.placeholder:Hide(); self.search.clear:Show() end
	self:RefreshList(false)
	self:RefreshDetails()
end

local function sourceSummary(entry)
	local labels = {}
	for _, kind in ipairs(RA.SourceOrder) do
		if entry.kinds[kind] then labels[#labels + 1] = RA.SourceLabels[kind] end
	end
	return table.concat(labels, ", ")
end

local function searchText(entry)
	if entry.search then return entry.search end
	local parts = { RA:GetSpellName(entry.spellID, entry.itemID) }
	local holiday = RA:GetHolidayName(entry.recipe.hd)
	if holiday then parts[#parts + 1] = holiday end
	for _, source in ipairs(entry.recipe.s or {}) do
		for _, id in ipairs(source.n or {}) do
			local npc = RA.Data.N[id]
			if npc then parts[#parts + 1] = npc.n end
		end
		for _, id in ipairs(source.q or {}) do
			local quest = RA.Data.Q[id]
			if quest then parts[#parts + 1] = quest.n end
		end
		for _, id in ipairs(source.o or {}) do
			local obj = RA.Data.O[id]
			if obj then parts[#parts + 1] = obj.n end
		end
	end
	local text = safeLower(table.concat(parts, "\n"))
	if RA.nameCache[entry.spellID] then entry.search = text end
	return text
end

function UI:BuildList()
	local list, perProfession = {}, {}
	local query = safeLower(RA.db.query or "")
	local pinSet = self.pinFilter and self.pinFilter.set
	local missing, unscanned = 0, 0
	local showProf = RA.db.showProf
	for _, entry in ipairs(RA.recipeList) do
		local id = entry.professionID
		local wasShown = showProf[id]
		showProf[id] = true
		local visible = RA:IsRecipeVisible(entry)
		showProf[id] = wasShown
		if visible then
			perProfession[id] = (perProfession[id] or 0) + 1
			if wasShown and (not pinSet or pinSet[entry.key]) and (query == "" or string.find(searchText(entry), query, 1, true)) then
				entry.status = RA:GetRecipeStatus(id, entry.spellID)
				entry.name = RA:GetSpellName(entry.spellID, entry.itemID)
				entry.sortName = safeLower(entry.name)
				entry.sortProfession = safeLower(RA:GetProfessionName(id))
				list[#list + 1] = entry
				if entry.status == "missing" then missing = missing + 1 else unscanned = unscanned + 1 end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.status ~= b.status then return a.status == "missing" end
		if a.sortProfession ~= b.sortProfession then return a.sortProfession < b.sortProfession end
		if a.rank ~= b.rank then return a.rank < b.rank end
		return a.sortName < b.sortName
	end)
	return list, perProfession, missing, unscanned
end

function UI:RefreshList(resetScroll)
	if not self.frame then return end
	local list, perProfession, missing, unscanned = self:BuildList()
	self.list = list
	local shownCount = 0
	for _, row in ipairs(self.professionRows) do
		local id = row.professionID
		local shown = RA.db.showProf[id]
		if shown then shownCount = shownCount + 1 end
		if shown then row.bg:Show() else row.bg:Hide() end
		row.icon:SetDesaturated(not shown)
		row.icon:SetAlpha(shown and 1 or 0.45)
		row.label:SetTextColor(shown and 0.98 or 0.55, shown and 0.88 or 0.53, shown and 0.66 or 0.49)
		local n = perProfession[id] or 0
		if not RA.db.scanned[id] then
			row.count:SetText(n > 0 and ("|cff6f6a62" .. n .. "|r") or "")          -- grey: not scanned yet
		elseif RA.db.partial[id] then
			row.count:SetText("|cffff9933" .. n .. "|r")
		else
			row.count:SetText(n > 0 and ("|cffffe0a0" .. n .. "|r") or "|cff71d78aвсё|r")
		end
	end
	self.multiProfession = shownCount > 1
	if self.pinFilter then
		self.status.text:SetText(GOLD .. self.pinFilter.label .. "|r: " .. #list .. "  " .. BLUE .. "[все]|r")
	elseif RA.Map and RA.Map.focus and RA.recipeByKey[RA.Map.focus] then
		self.status.text:SetText(GOLD .. "На карте один рецепт|r  " .. BLUE .. "[сбросить]|r")
	else
		self.status.text:SetText("Рецептов: |cffffffff" .. #list .. "|r")
	end
	local footer = "Не изучено: |cffffe0a0" .. missing .. "|r"
	if unscanned > 0 then footer = footer .. "     Из непросканированных профессий: |cffbbbbbb" .. unscanned .. "|r (откройте окно профессии)" end
	local partial = {}
	for _, p in ipairs(RA.Professions) do
		if RA.db.showProf[p.id] and RA.db.partial[p.id] then partial[#partial + 1] = RA:GetProfessionName(p.id) end
	end
	if #partial > 0 then footer = footer .. "     |cffff9933Неполный скан:|r " .. table.concat(partial, ", ") end
	self.footer:SetText(footer)

	if #list == 0 then
		if shownCount == 0 then
			self.emptyText:SetText("Выберите профессию слева.")
		elseif (RA.db.query or "") ~= "" then
			self.emptyText:SetText("Ничего не найдено.")
		else
			self.emptyText:SetText("Все доступные рецепты изучены.\nМожно ослабить фильтры.")
		end
		self.emptyText:Show()
	else
		self.emptyText:Hide()
	end

	-- keep a valid selection: the first recipe when the old one is no longer listed
	local selected = RA.db.selectedProfession and RA.db.selectedSpell and (RA.db.selectedProfession .. ":" .. RA.db.selectedSpell)
	local found = false
	for _, entry in ipairs(list) do if entry.key == selected then found = true break end end
	if not found then
		local first = list[1]
		RA.db.selectedProfession, RA.db.selectedSpell = first and first.professionID, first and first.spellID
		if self.detailText then self:RefreshDetails() end
	end

	if resetScroll then self.offset = 0 end
	self:RefreshRows()
end

function UI:RefreshRows()
	if not self.rows then return end
	local list = self.list or {}
	local maxOffset = math.max(0, #list - ROW_COUNT)
	self.offset = math.max(0, math.min(self.offset or 0, maxOffset))
	self.listBar:SetRange(maxOffset, ROW_COUNT, #list)
	self.listBar:SetValueQuiet(self.offset)
	local offset = self.offset
	local selected = RA.db.selectedProfession and RA.db.selectedSpell and (RA.db.selectedProfession .. ":" .. RA.db.selectedSpell)
	for index, row in ipairs(self.rows) do
		local entry = list[index + offset]
		row.entry = entry
		if entry then
			row.icon:SetTexture(RA:GetSpellTexture(entry.spellID, entry.itemID, entry.craftedID))
			local holiday = RA:GetHolidayName(entry.recipe.hd)
			row.name:SetText(entry.name .. (holiday and (" " .. ORANGE .. "(" .. holiday .. ")|r") or ""))
			local parts = {}
			if self.multiProfession then parts[#parts + 1] = RA:GetProfessionName(entry.professionID) end
			parts[#parts + 1] = "навык " .. entry.rank
			local summary = sourceSummary(entry)
			if summary ~= "" then parts[#parts + 1] = summary end
			if entry.status == "missing" then
				row.name:SetTextColor(0.96, 0.86, 0.60)
				row.icon:SetDesaturated(false)
				row.icon:SetAlpha(1)
			else
				row.name:SetTextColor(0.68, 0.70, 0.72)
				row.icon:SetDesaturated(true)
				row.icon:SetAlpha(0.75)
			end
			row.info:SetText(table.concat(parts, "  •  "))
			if entry.key == selected then row.selected:Show(); row.selectedBar:Show() else row.selected:Hide(); row.selectedBar:Hide() end
			if RA.Tracker and RA.Tracker:IsTracked(entry.key) then row.star:Show() else row.star:Hide() end
			row:Show()
		else
			row:Hide()
		end
	end
end

function UI:ScrollToSelected()
	local selected = RA.db.selectedProfession and RA.db.selectedSpell and (RA.db.selectedProfession .. ":" .. RA.db.selectedSpell)
	for index, entry in ipairs(self.list or {}) do
		if entry.key == selected then
			if index <= self.offset or index > self.offset + ROW_COUNT then
				self.offset = math.max(0, math.min(index - 1, #self.list - ROW_COUNT))
			end
			break
		end
	end
	self:RefreshRows()
end

-- Called from a map pin: list only the recipes of that pin.
function UI:ShowPinRecipes(label, entries)
	local set = {}
	for _, entry in ipairs(entries) do set[entry.key] = true end
	self.pinFilter = { label = label, set = set }
	if entries[1] then RA.db.selectedProfession, RA.db.selectedSpell = entries[1].professionID, entries[1].spellID end
	self:Show()
	self:RefreshList(true)
	self:RefreshDetails()
	self:ScrollToSelected()
end

function UI:GetSelectedEntry()
	local p, s = RA.db.selectedProfession, RA.db.selectedSpell
	return p and s and RA:GetEntry(p, s)
end

function UI:ShowSelectedOnMap()
	local entry = self:GetSelectedEntry()
	if not entry or not RA.Map then return end
	if RA.Map.focus == entry.key then
		RA.Map:SetFocus(nil)
		return
	end
	if not RA.Map:ShowRecipeOnMap(entry) then
		RA:Print("у источников этого рецепта нет точек на карте (подземелье, мировая добыча или нет данных).")
	else
		self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
	end
end

---------------------------------------------------------------------------
-- Details card
---------------------------------------------------------------------------
local INDENT = "     "

local function playerMapFile()
	local Astrolabe = DongleStub and DongleStub("Astrolabe-0.4")
	if not Astrolabe or (WorldMapFrame and WorldMapFrame:IsShown()) then return UI.lastPlayerMap end
	local c, z = Astrolabe:GetCurrentPlayerPosition()
	local file = c and z and Astrolabe.ContinentList[c] and Astrolabe.ContinentList[c][z]
	UI.lastPlayerMap = file or UI.lastPlayerMap
	return UI.lastPlayerMap
end

local function locationText(info, here)
	if not info then return "место неизвестно" end
	local points = info.p
	if points and #points > 0 then
		local point = points[1]
		for _, p in ipairs(points) do if p.m == here then point = p break end end
		local zone = RA.Map and RA.Map:GetZoneName(point.m) or point.m
		local text = string.format("%s (%.0f, %.0f)", zone or "?", point.x * 100, point.y * 100)
		if point.f == 2 then text = text .. ", Клоака" end
		if #points > 1 then text = text .. string.format(" и ещё %d", #points - 1) end
		return text
	end
	if info.z then return info.z end
	return "место неизвестно"
end

local function holidayTag(key)
	local name = RA:GetHolidayName(key)
	return name and (" " .. ORANGE .. "(" .. name .. ")|r") or ""
end

local function sortByLocation(ids, data, here)
	local items = {}
	for i, id in ipairs(ids) do items[#items + 1] = { id = id, info = data[id], order = i } end
	table.sort(items, function(a, b)
		local ah = a.info and a.info.p and a.info.p[1] and a.info.p[1].m == here
		local bh = b.info and b.info.p and b.info.p[1] and b.info.p[1].m == here
		if ah ~= bh then return ah and true or false end
		return a.order < b.order
	end)
	return items
end

local function addHeader(lines, text)
	if #lines > 0 and lines[#lines] ~= " " then lines[#lines + 1] = " " end
	lines[#lines + 1] = GOLD .. text .. "|r"
end

local function appendNPCs(lines, label, source, here, limit, chanceList)
	local shown, hidden, total = 0, 0, 0
	local limited = {}
	for _, id in ipairs(source.l or {}) do limited[id] = true end
	local heroic = {}
	for _, id in ipairs(source.h or {}) do heroic[id] = true end
	local chances = {}
	if chanceList then for i, id in ipairs(source.n or {}) do chances[id] = chanceList[i] end end
	local items = chanceList and sortByLocation(source.n or {}, {}, here) or sortByLocation(source.n or {}, RA.Data.N, here)
	local out = {}
	for _, item in ipairs(items) do
		total = total + 1
		local id = item.id
		if (source.t == "v" or source.t == "t") and not RA:IsSourceIDAllowed(source.t, id) then
			hidden = hidden + 1
		elseif shown < limit then
			shown = shown + 1
			local npc = RA.Data.N[id]
			local name = "|cffffffff" .. (npc and npc.n or ("NPC #" .. id)) .. "|r"
			if heroic[id] then name = name .. GREY .. " (героик)|r" end
			name = name .. holidayTag(npc and npc.h)
			local extra = {}
			if chances[id] then extra[#extra + 1] = "шанс " .. chances[id] .. "%" end
			if limited[id] then extra[#extra + 1] = "ограниченный запас" end
			out[#out + 1] = "• " .. name
			out[#out + 1] = GREY .. INDENT .. locationText(npc, here) .. (#extra > 0 and (", " .. table.concat(extra, ", ")) or "") .. "|r"
		end
	end
	if shown == 0 and hidden == 0 then return end
	addHeader(lines, label)
	for _, text in ipairs(out) do lines[#lines + 1] = text end
	local rest = total - shown - hidden
	if rest > 0 then lines[#lines + 1] = GREY .. "и ещё " .. rest .. "|r" end
	if hidden > 0 then lines[#lines + 1] = GREY .. "скрыто фильтрами (фракция/праздник): " .. hidden .. "|r" end
end

local function appendSourceLines(lines, entry)
	local here = playerMapFile()
	for _, source in ipairs(entry.recipe.s or {}) do
		local kind = source.t
		if kind == "t" then
			appendNPCs(lines, "Наставники", source, here, 6)
		elseif kind == "v" then
			appendNPCs(lines, "Торговцы", source, here, 6)
		elseif kind == "m" then
			appendNPCs(lines, "Добыча с NPC", source, here, 8, source.c)
		elseif kind == "w" then
			addHeader(lines, "Мировая добыча")
			lines[#lines + 1] = "Мобы " .. source.lo .. "-" .. source.hi .. " уровня, шанс около " .. source.c .. "%"
			local zones = {}
			for _, file in ipairs(source.z or {}) do zones[#zones + 1] = RA.Map and RA.Map:GetZoneName(file) or file end
			if #zones > 0 then lines[#lines + 1] = GREY .. "Чаще всего: " .. table.concat(zones, ", ") .. "|r" end
		elseif kind == "q" then
			local hiddenQuests, first = 0, true
			for _, questID in ipairs(source.q or {}) do
				local quest = RA.Data.Q[questID]
				if quest and not RA:IsSourceIDAllowed("q", questID) then
					hiddenQuests = hiddenQuests + 1
				elseif quest then
					if first then addHeader(lines, "Задания"); first = false end
					lines[#lines + 1] = "• |cffffffff" .. quest.n .. "|r" .. GREY .. " [" .. (quest.l or "?") .. "]|r" .. holidayTag(quest.h)
					local giver = quest.g and quest.g[1] and RA.Data.N[quest.g[1]]
					local object = not giver and quest.go and quest.go[1] and RA.Data.O[quest.go[1]]
					local from = giver or object
					if from then lines[#lines + 1] = GREY .. INDENT .. from.n .. ", " .. locationText(from, here) .. "|r" end
				end
			end
			if hiddenQuests > 0 then
				if first then addHeader(lines, "Задания") end
				lines[#lines + 1] = GREY .. "скрыто фильтрами (фракция/класс/праздник): " .. hiddenQuests .. "|r"
			end
		elseif kind == "o" then
			addHeader(lines, "Сундуки и предметы на земле")
			for i, id in ipairs(source.o or {}) do
				if i > 6 then lines[#lines + 1] = GREY .. "и ещё " .. (#source.o - 6) .. "|r" break end
				local obj = RA.Data.O[id]
				lines[#lines + 1] = "• |cffffffff" .. (obj and obj.n or ("#" .. id)) .. "|r"
				lines[#lines + 1] = GREY .. INDENT .. locationText(obj, here) .. (source.c and source.c[i] and (", шанс " .. source.c[i] .. "%") or "") .. "|r"
			end
		elseif kind == "i" then
			addHeader(lines, "Из предмета")
			for i, id in ipairs(source.i or {}) do
				if i > 6 then lines[#lines + 1] = GREY .. "и ещё " .. (#source.i - 6) .. "|r" break end
				local name = GetItemInfo(id) or RA.Data.I[id] or ("#" .. id)
				lines[#lines + 1] = "• |cffffffff" .. name .. "|r" .. GREY .. (source.c and source.c[i] and (" — " .. source.c[i] .. "%") or "") .. "|r"
			end
		elseif kind == "f" then
			addHeader(lines, "Рыбалка")
			lines[#lines + 1] = table.concat(source.z or {}, ", ")
		elseif kind == "d" then
			addHeader(lines, "Открытие")
			for _, spellID in ipairs(source.d or {}) do
				if spellID > 0 then
					lines[#lines + 1] = "Случайно при создании «" .. RA:GetSpellName(spellID) .. "»"
				else
					lines[#lines + 1] = "Случайно при создании предметов этой профессии"
				end
			end
		end
	end
end

function UI:SetDetailText(text)
	self.detailText:SetText(text)
	local height = (self.detailText:GetStringHeight() or 0) + 8
	self.detailChild:SetHeight(math.max(height, 10))
	local visible = self.detailScroll:GetHeight() or 300
	local range = math.max(0, math.floor(height - visible + 0.5))
	self.detailBar:SetRange(range, visible, height)
end

function UI:RefreshDetails()
	if not self.detailText then return end
	local entry = self:GetSelectedEntry()
	if not entry then
		self.detailIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
		self.detailTitle:SetText("Выберите рецепт")
		self.detailSub:SetText("")
		self:SetDetailText("Выберите рецепт в списке, чтобы увидеть, где его взять.\n\n" ..
			"Откройте окно каждой своей профессии один раз — компас запомнит изученные рецепты и будет обновлять список сам.")
		self.mapButton:SetEnabledState(false)
		self.linkButton:SetEnabledState(false)
		self.trackButton:SetEnabledState(false)
		return
	end
	local recipe = entry.recipe
	self.detailIcon:SetTexture(RA:GetSpellTexture(entry.spellID, entry.itemID, entry.craftedID))
	self.detailTitle:SetText(RA:GetSpellName(entry.spellID, entry.itemID))
	local status = RA:GetRecipeStatus(entry.professionID, entry.spellID)
	local statusText = status == "known" and (GREEN .. "изучен|r") or status == "missing" and (GOLD .. "не изучен|r")
		or (GREY .. "профессия не просканирована|r")
	self.detailSub:SetText(RA:GetProfessionName(entry.professionID) .. ", навык " .. entry.rank .. "  •  " .. statusText)

	local lines = {}
	if recipe.hd then
		local active = RA:IsHolidayActive(recipe.hd)
		lines[#lines + 1] = ORANGE .. "Праздничный рецепт: " .. (RA:GetHolidayName(recipe.hd) or recipe.hd) .. "|r" ..
			GREY .. (active and " — идёт сейчас" or " — сейчас не идёт") .. "|r"
	end
	if recipe.rf then
		lines[#lines + 1] = BLUE .. "Репутация:|r " .. RA:GetFactionName(recipe.rf) .. " — " .. RA:GetStandingName(recipe.rr)
	end
	if recipe.fs then
		lines[#lines + 1] = BLUE .. "Фракция:|r только " .. (recipe.fs == "A" and "Альянс" or "Орда")
	end
	if recipe.cl then
		local forMe = RA:IsForPlayerClass(recipe.cl)
		lines[#lines + 1] = BLUE .. "Класс:|r " .. (forMe and "" or RED) .. RA:GetClassNames(recipe.cl) .. (forMe and "" or "|r")
	end
	local price = recipe.pr and RA:FormatMoney(recipe.pr)
	if price then lines[#lines + 1] = BLUE .. "Цена у торговца:|r " .. price end
	local before = #lines
	appendSourceLines(lines, entry)
	if #lines == before then
		if #lines > 0 then lines[#lines + 1] = " " end
		if recipe.hd then
			lines[#lines + 1] = GREY .. "Продаётся у праздничных торговцев во время праздника.|r"
		else
			lines[#lines + 1] = GREY .. "Источник не указан в базе WotLK 3.3.5 — возможно, рецепт удалён из игры или на сервере изменён.|r"
		end
	end
	self:SetDetailText(table.concat(lines, "\n"))
	if self.lastDetailKey ~= entry.key then
		self.detailBar:SetValue(0)
		self.detailScroll:SetVerticalScroll(0)
	end
	self.lastDetailKey = entry.key
	local focused = RA.Map and RA.Map.focus == entry.key
	self.mapButton:SetLabel(focused and "Все метки" or "На карте")
	local tracked = RA.Tracker and RA.Tracker:IsTracked(entry.key)
	self.trackButton:SetLabel(tracked and "Не следить" or "Отслеживать")
	self.trackButton:SetEnabledState(status ~= "known" or tracked)
	self.mapButton:SetEnabledState(true)
	self.linkButton:SetEnabledState(true)
end
