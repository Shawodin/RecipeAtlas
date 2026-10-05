local RA = _G.RecipeAtlas
RA.Map = RA.Map or {}
local Map = RA.Map
local Astrolabe = DongleStub("Astrolabe-0.4")

local iconBySource = {
	v = "Interface\\Icons\\INV_Misc_Coin_01",
	t = "Interface\\Icons\\INV_Misc_Book_07",
	m = "Interface\\Icons\\INV_Misc_Bag_10",
	o = "Interface\\Icons\\INV_Box_01",
	q = "Interface\\Icons\\INV_Misc_Note_01",
}
local tintBySource = {
	v = { 1.00, 0.76, 0.22 }, t = { 0.35, 0.70, 1.00 }, m = { 0.95, 0.38, 0.30 },
	o = { 0.78, 0.58, 0.36 }, q = { 0.45, 0.88, 0.40 },
}
local priority = { t = 1, v = 2, q = 3, m = 4, o = 5 }
local MAX_OBJECT_SOURCES = 6   -- generic world chests are listed in the card, not pinned

-- Dalaran: data stores city-floor coordinates; the Underbelly map (level 2) uses another frame.
local DALARAN_CITY = { 222.495, 1052.51, 5513.33, 6066.67 }
local DALARAN_UNDERBELLY = { 352.646, 915.87, 5599.85, 5975.34 }
local function dalaranToLevel2(x, y)
	local wy = DALARAN_CITY[2] - x * (DALARAN_CITY[2] - DALARAN_CITY[1])
	local wx = DALARAN_CITY[4] - y * (DALARAN_CITY[4] - DALARAN_CITY[3])
	return (DALARAN_UNDERBELLY[2] - wy) / (DALARAN_UNDERBELLY[2] - DALARAN_UNDERBELLY[1]),
		(DALARAN_UNDERBELLY[4] - wx) / (DALARAN_UNDERBELLY[4] - DALARAN_UNDERBELLY[3])
end

local function setSize(region, w, h) region:SetWidth(w); region:SetHeight(h or w) end

---------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------
function Map:BuildZoneIndex()
	self.zoneByFile, self.zoneName = {}, {}
	if not Astrolabe or not Astrolabe.ContinentList then return end
	for continent, zones in pairs(Astrolabe.ContinentList) do
		local names = { GetMapZones(continent) }
		for zone, file in pairs(zones) do
			if type(file) == "string" then
				self.zoneByFile[file] = { continent, zone }
				self.zoneName[file] = names[zone]
			end
		end
	end
end

function Map:GetZoneName(mapFile)
	return mapFile and (self.zoneName and self.zoneName[mapFile]) or mapFile
end

function Map:FindContinentZone(mapFile)
	local info = self.zoneByFile and self.zoneByFile[mapFile]
	if info then return info[1], info[2] end
end

---------------------------------------------------------------------------
-- Logical pins (cached until filters or known recipes change)
---------------------------------------------------------------------------
function Map:Invalidate()
	self.pinCache = nil
	self.minimapStale = true
	self:RequestRefresh()
end

function Map:SetFocus(entry)
	self.focus = entry and entry.key or nil
	self:Invalidate()
	if RA.UI and RA.UI.RequestRefresh then RA.UI:RequestRefresh() end
end

local function addToPin(pins, kind, id, info, point, entry, sourceType)
	local floor = point.f or 0
	local key = kind .. id .. ":" .. point.m .. ":" .. floor
	local pin = pins[key]
	if not pin then
		pin = { kind = kind, id = id, name = info.n, mapFile = point.m, floor = floor, x = point.x, y = point.y,
			recipes = {}, recipeCount = 0, sourceTypes = {} }
		pins[key] = pin
	end
	if not pin.recipes[entry.key] then
		pin.recipes[entry.key] = entry
		pin.recipeCount = pin.recipeCount + 1
	end
	pin.sourceTypes[sourceType] = true
	if not pin.sourceType or priority[sourceType] < priority[pin.sourceType] then pin.sourceType = sourceType end
end

local function addEntity(pins, kind, id, entry, sourceType)
	local info = (kind == "o" and RA.Data.O or RA.Data.N)[id]
	if not info or not info.p then return end
	for _, point in ipairs(info.p) do addToPin(pins, kind, id, info, point, entry, sourceType) end
end

function Map:GetPins()
	if self.pinCache then return self.pinCache end
	local pins = {}
	local db = RA.db
	for _, entry in ipairs(RA.recipeList or {}) do
		local focused = self.focus == entry.key
		if (self.focus and focused) or (not self.focus and RA:IsRecipeVisible(entry)) then
			for _, source in ipairs(entry.recipe.s or {}) do
				local kind = source.t
				if RA.MapSourceTypes[kind] and (focused or db.sourceEnabled[kind]) then
					if kind == "v" or kind == "t" or kind == "m" then
						for _, id in ipairs(source.n or {}) do
							if focused or RA:IsSourceIDAllowed(kind, id) then addEntity(pins, "n", id, entry, kind) end
						end
					elseif kind == "q" then
						for _, questID in ipairs(source.q or {}) do
							local quest = RA.Data.Q[questID]
							if quest and (focused or RA:IsSourceIDAllowed("q", questID)) then
								for _, id in ipairs(quest.g or {}) do addEntity(pins, "n", id, entry, "q") end
								for _, id in ipairs(quest.go or {}) do addEntity(pins, "o", id, entry, "q") end
							end
						end
					elseif kind == "o" and (focused or #(source.o or {}) <= MAX_OBJECT_SOURCES) then
						for _, id in ipairs(source.o or {}) do addEntity(pins, "o", id, entry, "o") end
					end
				end
			end
		end
	end
	local list = {}
	for _, pin in pairs(pins) do list[#list + 1] = pin end
	self.pinCache = list
	return list
end

-- Recipe entries of a pin, sorted by name.
function Map:PinRecipes(pin)
	local list = {}
	for _, entry in pairs(pin.recipes) do list[#list + 1] = entry end
	table.sort(list, function(a, b)
		return RA:GetSpellName(a.spellID, a.itemID) < RA:GetSpellName(b.spellID, b.itemID)
	end)
	return list
end

---------------------------------------------------------------------------
-- Pin buttons (pooled: frames can never be freed in WoW)
---------------------------------------------------------------------------
local function getTooltip(isMinimap)
	if isMinimap then return GameTooltip end
	if not Map.worldMapTooltip then
		local tip = CreateFrame("GameTooltip", "RecipeAtlasWorldMapTooltip", WorldMapFrame or UIParent, "GameTooltipTemplate")
		tip:SetFrameStrata("TOOLTIP")
		Map.worldMapTooltip = tip
	end
	return Map.worldMapTooltip
end

local function texturePrefix(path, size)
	return "|T" .. (path or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":" .. (size or 16) .. ":" .. (size or 16) .. ":0:0:64:64:5:59:5:59|t "
end

-- A Blizzard quest POI under the cursor that also lies under one of our pins:
-- our pin turns see-through and lets the mouse reach the quest icon. Shift keeps our pin.
local function questPOIUnderCursor()
	local parent = WorldMapPOIFrame
	if not parent or not parent.GetChildren then return false end
	for _, child in ipairs({ parent:GetChildren() }) do
		if child:IsShown() and child:IsMouseOver() then return true end
	end
	return false
end

-- passive = the pin is see-through over a quest icon: the info is shown next to the quest tooltip.
local function placePassiveTooltip(button, tooltip)
	tooltip:ClearAllPoints()
	local questTip = WorldMapTooltip
	if questTip and questTip:IsShown() and questTip ~= tooltip then
		tooltip:SetPoint("TOPLEFT", questTip, "BOTTOMLEFT", 0, -2)
	else
		tooltip:SetPoint("BOTTOMLEFT", button, "TOPRIGHT", 4, 4)
	end
end

local function showPinTooltip(button, passive)
	local pin = button.pin
	if not pin then return end
	local tooltip = getTooltip(button.isMinimap)
	if passive then
		tooltip:SetOwner(button, "ANCHOR_NONE")
		placePassiveTooltip(button, tooltip)
	else
		tooltip:SetOwner(button, "ANCHOR_RIGHT")
	end
	local members = pin.members or { pin }
	if #members > 1 then
		tooltip:SetText(#members .. " точек рядом", 1, 0.82, 0.38)
		for i = 1, math.min(#members, 5) do
			local member = members[i]
			local tint = tintBySource[member.sourceType] or tintBySource.v
			tooltip:AddLine("• " .. (member.name or "?"), tint[1], tint[2], tint[3])
		end
		if #members > 5 then tooltip:AddLine("и ещё " .. (#members - 5), 0.65, 0.65, 0.65) end
	else
		tooltip:SetText(pin.name or "?", 1, 0.82, 0.38)
		if pin.x then
			tooltip:AddLine(string.format("%s (%.1f, %.1f)", Map:GetZoneName(pin.mapFile) or "", pin.x * 100, pin.y * 100), 0.62, 0.62, 0.62)
		end
	end
	local labels = {}
	for _, kind in ipairs(RA.SourceOrder) do
		if pin.sourceTypes[kind] then
			local tint = tintBySource[kind] or tintBySource.v
			labels[#labels + 1] = string.format("|cff%02x%02x%02x%s|r", tint[1] * 255, tint[2] * 255, tint[3] * 255, RA.SourceLabels[kind])
		end
	end
	tooltip:AddLine(table.concat(labels, ", "), 1, 1, 1)
	tooltip:AddLine(" ")
	local recipes = Map:PinRecipes(pin)
	local limit = 12
	for i = 1, math.min(#recipes, limit) do
		local e = recipes[i]
		local name = RA:GetSpellName(e.spellID, e.itemID)
		local holiday = RA:GetHolidayName(e.recipe.hd)
		if holiday then name = name .. " |cffff9040(" .. holiday .. ")|r" end
		local r, g, b = 0.96, 0.88, 0.66
		if RA:GetRecipeStatus(e.professionID, e.spellID) ~= "missing" then r, g, b = 0.7, 0.7, 0.7 end
		tooltip:AddDoubleLine(texturePrefix(RA:GetSpellTexture(e.spellID, e.itemID, e.craftedID), 15) .. name,
			RA:GetProfessionName(e.professionID) .. " " .. e.rank, r, g, b, 0.55, 0.55, 0.55)
	end
	if #recipes > limit then tooltip:AddLine("и ещё " .. (#recipes - limit), 0.65, 0.65, 0.65) end
	tooltip:AddLine(" ")
	if passive then
		tooltip:AddLine("Зажмите Shift, чтобы выбрать эту метку", 0.55, 0.80, 1.00)
	else
		tooltip:AddLine("ЛКМ — показать эти рецепты в списке", 0.55, 0.80, 1.00)
		if Map:HasTomTom() and #members == 1 then tooltip:AddLine("ПКМ — точка TomTom", 0.55, 0.80, 1.00) end
		if not button.isMinimap and questPOIUnderCursor() then
			tooltip:AddLine("Под меткой значок задания: отпустите Shift, чтобы навести на него", 0.6, 0.6, 0.6, true)
		end
	end
	tooltip:Show()
	button.tooltip = tooltip
end

local function onPinClick(button, mouseButton)
	local pin = button.pin
	if not pin then return end
	if mouseButton == "RightButton" then
		local target = pin.members and pin.members[1] or pin
		if #(pin.members or { pin }) == 1 then Map:AddWaypoint(target) end
		return
	end
	if RA.UI then
		local members = pin.members or { pin }
		local label = #members > 1 and (#members .. " точек") or (pin.name or "?")
		RA.UI:ShowPinRecipes(label, Map:PinRecipes(pin))
	end
end

-- Round pin: dark shadow, coloured ring (source type), round icon (profession), recipe counter.
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function layoutPin(button, size)
	setSize(button, size)
	setSize(button.shadow, size + 4)
	setSize(button.ring, size)
	setSize(button.icon, size - 4)
	setSize(button.glow, size * 2)
	local badge = math.max(10, math.floor(size * 0.55))
	setSize(button.badge, badge + 2, badge)
end

local function createPinButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local glow = button:CreateTexture(nil, "BACKGROUND")
	glow:SetPoint("CENTER")
	glow:SetTexture(DISC)
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(1, 0.8, 0.3, 0.7)
	glow:Hide()
	button.glow = glow
	if button.CreateAnimationGroup then
		local group = button:CreateAnimationGroup()
		if group then
			group:SetLooping("BOUNCE")
			local fade = group:CreateAnimation("Alpha")
			fade:SetChange(-0.6)
			fade:SetDuration(0.8)
			button.pulse = group
		end
	end
	local shadow = button:CreateTexture(nil, "BACKGROUND")
	shadow:SetPoint("CENTER", 0, -1)
	shadow:SetTexture(DISC)
	shadow:SetVertexColor(0, 0, 0, 0.75)
	button.shadow = shadow
	local ring = button:CreateTexture(nil, "BORDER")
	ring:SetPoint("CENTER")
	ring:SetTexture(DISC)
	button.ring = ring
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	button.icon = icon
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetPoint("TOPLEFT", -2, 2); highlight:SetPoint("BOTTOMRIGHT", 2, -2)
	highlight:SetTexture(DISC)
	highlight:SetBlendMode("ADD")
	highlight:SetVertexColor(1, 1, 1, 0.35)
	local badge = CreateFrame("Frame", nil, button)
	badge:SetPoint("CENTER", button, "TOPRIGHT", -2, -2)
	badge:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	badge:SetBackdropColor(0.08, 0.06, 0.04, 0.95)
	badge:SetBackdropBorderColor(0.85, 0.65, 0.3, 0.9)
	local count = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	count:SetPoint("CENTER", badge, "CENTER", 1, 0)
	local font, _, flags = count:GetFont()
	if font then count:SetFont(font, 9, flags) end
	count:SetTextColor(1, 0.92, 0.7)
	button.badge, button.count = badge, count
	button:SetScript("OnEnter", function(self)
		layoutPin(self, (self.baseSize or 18) + 4)
		showPinTooltip(self)
	end)
	button:SetScript("OnLeave", function(self)
		if self.passThrough then return end
		layoutPin(self, self.baseSize or 18)
		if self.tooltip then self.tooltip:Hide(); self.tooltip = nil end
	end)
	button:SetScript("OnClick", onPinClick)
	return button
end

local function pinIcon(pin)
	local profession, single
	for _, entry in pairs(pin.recipes) do
		if profession and profession ~= entry.professionID then return iconBySource[pin.sourceType] or iconBySource.v end
		profession, single = entry.professionID, entry
	end
	if pin.recipeCount == 1 and single and Map.focus then
		return RA:GetSpellTexture(single.spellID, single.itemID, single.craftedID)
	end
	local info = profession and RA.ProfessionByID[profession]
	local texture = info and select(3, GetSpellInfo(info.ability))
	return texture or iconBySource[pin.sourceType] or iconBySource.v
end

local function configurePin(button, pin, isMinimap)
	local grouped = pin.members and #pin.members > 1
	local size = isMinimap and 15 or (grouped and 22 or 19)
	if not isMinimap and WorldMapButton then
		-- the quest-log map view scales WorldMapButton down to 0.69; keep pins the same size on screen
		local mapScale = WorldMapButton:GetScale() or 1
		if mapScale > 0.2 then size = size / mapScale end
	end
	button.baseSize = size
	layoutPin(button, size)
	local texture = pinIcon(pin)
	if not (SetPortraitToTexture and pcall(SetPortraitToTexture, button.icon, texture)) then
		button.icon:SetTexture(texture)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	local tint = tintBySource[pin.sourceType] or tintBySource.v
	button.ring:SetVertexColor(tint[1], tint[2], tint[3], 1)
	local number = pin.recipeCount or 0
	if not isMinimap and number > 1 then
		button.count:SetText(number > 99 and "99" or tostring(number))
		button.badge:SetWidth(number > 9 and 16 or 12)
		button.badge:Show()
	else
		button.badge:Hide()
	end
	local focused = Map.focus and not isMinimap
	if focused then
		button.glow:Show()
		if button.pulse then button.pulse:Play() end
	else
		button.glow:Hide()
		if button.pulse then button.pulse:Stop() end
	end
	button.pin, button.isMinimap = pin, isMinimap
	if button.tooltip and button:IsMouseOver() then showPinTooltip(button) end
end

local function acquire(pool, parent)
	pool.used = pool.used + 1
	local button = pool[pool.used]
	if not button then
		button = createPinButton(parent)
		pool[pool.used] = button
	end
	return button
end

local function releaseAll(pool, minimap)
	for i = 1, pool.used do
		local button = pool[i]
		if minimap and Astrolabe then Astrolabe:RemoveIconFromMinimap(button) end
		if button.tooltip then button.tooltip:Hide(); button.tooltip = nil end
		button:Hide()
		button.pin = nil
		if button.passThrough then button.passThrough = nil; button:SetAlpha(1); button:EnableMouse(true) end
	end
	pool.used = 0
end

---------------------------------------------------------------------------
-- Setup and refresh scheduling
---------------------------------------------------------------------------
function Map:Initialize()
	if self.initialized then return end
	self.initialized = true
	self.worldPool = { used = 0 }
	self.minimapPool = { used = 0 }
	self:BuildZoneIndex()
	self:CreateMinimapButton()
	self:HookWorldMap()
	self:Invalidate()
end

function Map:HookWorldMap()
	if self.worldMapHooked or not WorldMapFrame then return end
	self.worldMapHooked = true
	-- Own watcher frame inside the world map: it is shown and hidden together with the map,
	-- so it keeps working even if another addon or the server UI replaces WorldMapFrame scripts.
	local watcher = CreateFrame("Frame", nil, WorldMapButton or WorldMapFrame)
	watcher:SetPoint("TOPLEFT"); watcher:SetWidth(1); watcher:SetHeight(1)
	watcher:SetScript("OnShow", function() Map.worldKey = nil; Map:RequestRefresh("world") end)
	watcher:SetScript("OnHide", function()
		releaseAll(Map.worldPool, false)
		if Map.focusButton then Map.focusButton:Hide() end
		if Map.minimapPending then Map:RequestRefresh("minimap") end
	end)
	watcher:SetScript("OnUpdate", function(_, elapsed)
		Map.hoverElapsed = (Map.hoverElapsed or 0) + (elapsed or 0)
		if Map.hoverElapsed >= 0.05 then
			Map.hoverElapsed = 0
			Map:UpdateQuestOverlap()
		end
		Map.geometryElapsed = (Map.geometryElapsed or 0) + (elapsed or 0)
		if Map.geometryElapsed < 0.2 then return end
		Map.geometryElapsed = 0
		if Map:WorldGeometryKey() ~= Map.worldKey then Map:RefreshWorldMap() end
	end)
	watcher:Show()
	self.watcher = watcher
	-- Small "reset focus" button shown on the world map while one recipe is focused.
	local button = CreateFrame("Button", nil, WorldMapButton or WorldMapFrame, "UIPanelButtonTemplate")
	button:SetWidth(210); button:SetHeight(22)
	button:SetPoint("TOPLEFT", WorldMapButton or WorldMapFrame, "TOPLEFT", 8, -8)
	button:SetFrameLevel((WorldMapButton or WorldMapFrame):GetFrameLevel() + 20)
	button:SetScript("OnClick", function() Map:SetFocus(nil) end)
	button:Hide()
	self.focusButton = button
	-- Colour legend in the bottom-left corner of the world map.
	local parent = WorldMapButton or WorldMapFrame
	local legend = CreateFrame("Frame", nil, parent)
	legend:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
	legend:SetHeight(20)
	legend:SetFrameLevel(parent:GetFrameLevel() + 20)
	legend:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
	legend:SetBackdropColor(0, 0, 0, 0.6)
	legend:SetBackdropBorderColor(0.6, 0.45, 0.2, 0.8)
	local x = 7
	for _, kind in ipairs({ "t", "v", "m", "q", "o" }) do
		local dot = legend:CreateTexture(nil, "ARTWORK")
		setSize(dot, 10)
		dot:SetPoint("LEFT", legend, "LEFT", x, 0)
		dot:SetTexture(DISC)
		local tint = tintBySource[kind]
		dot:SetVertexColor(tint[1], tint[2], tint[3])
		local label = legend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", dot, "RIGHT", 3, 0)
		label:SetText(RA.SourceLabels[kind])
		x = x + 10 + 3 + (label:GetStringWidth() or 60) + 10
	end
	legend:SetWidth(x)
	legend:Hide()
	self.legend = legend
end

function Map:UpdateQuestOverlap()
	local pool = self.worldPool
	if not pool or pool.used == 0 then return end
	local shift = IsShiftKeyDown and IsShiftKeyDown()
	local checkedPOI, poiHere
	for i = 1, pool.used do
		local button = pool[i]
		local fade = false
		if button:IsShown() and button:IsMouseOver() and not shift then
			if checkedPOI == nil then checkedPOI = true; poiHere = questPOIUnderCursor() end
			fade = poiHere
		end
		if fade and not button.passThrough then
			button.passThrough = true
			button:SetAlpha(0.25)
			button:EnableMouse(false)
			layoutPin(button, button.baseSize or 18)
			showPinTooltip(button, true)
		elseif fade and button.tooltip then
			placePassiveTooltip(button, button.tooltip)   -- follow the quest tooltip once it appears
		elseif not fade and button.passThrough then
			button.passThrough = nil
			button:SetAlpha(1)
			button:EnableMouse(true)
			if button.tooltip then button.tooltip:Hide(); button.tooltip = nil end
			if button:IsMouseOver() then button:GetScript("OnEnter")(button) end
		end
	end
end

function Map:RequestRefresh(which)
	if not self.initialized then return end
	if which ~= "world" then self.minimapDirty = true end
	if which ~= "minimap" then self.worldDirty = true end
	-- Throttle, not debounce: WORLD_MAP_UPDATE can fire nonstop and must not postpone the refresh forever.
	RA:Throttle(0.05, "mapRefresh", function()
		if Map.minimapDirty then Map.minimapDirty = false; Map:RefreshMinimap() end
		if Map.worldDirty then Map.worldDirty = false; Map:RefreshWorldMap() end
	end)
end

function Map:OnWorldMapUpdate()
	if WorldMapFrame and WorldMapFrame:IsShown() then self:RequestRefresh("world") end
end

function Map:OnZoneChanged()
	self:RequestRefresh("minimap")
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
function Map:CreateMinimapButton()
	if self.minimapButton then return end
	local button = CreateFrame("Button", "RecipeAtlasMinimapButton", Minimap)
	setSize(button, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	local icon = button:CreateTexture(nil, "BACKGROUND")
	setSize(icon, 20)
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	local border = button:CreateTexture(nil, "OVERLAY")
	setSize(border, 53)
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			RA.db.markerEnabled = not RA.db.markerEnabled
			RA:RefreshAll()
			RA:Print(RA.db.markerEnabled and "метки на карте включены." or "метки на карте выключены.")
		else
			RA:ToggleWindow()
		end
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Рецептный компас", 1, 0.82, 0.38)
		GameTooltip:AddLine("ЛКМ — открыть список рецептов", 1, 1, 1)
		GameTooltip:AddLine("ПКМ — " .. (RA.db.markerEnabled and "скрыть" or "показать") .. " метки", 1, 1, 1)
		GameTooltip:AddLine("Перетащите, чтобы передвинуть", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local x, y = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			local cx, cy = Minimap:GetCenter()
			RA.db.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
			Map:PositionMinimapButton()
		end)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	self.minimapButton = button
	self:PositionMinimapButton()
end

function Map:PositionMinimapButton()
	if not self.minimapButton then return end
	local angle = math.rad(RA.db.minimapAngle or 210)
	local radius = (Minimap:GetWidth() / 2) + 10
	self.minimapButton:ClearAllPoints()
	self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
	if RA.db.minimapButton then self.minimapButton:Show() else self.minimapButton:Hide() end
end

---------------------------------------------------------------------------
-- Minimap pins
---------------------------------------------------------------------------
function Map:RefreshMinimap()
	if not self.initialized then return end
	if not self.minimapStale and self.minimapMap and RA.db.markerEnabled and Astrolabe then
		-- Sub-zone changes fire often; rebuild only when the zone map itself changed.
		local c, z = Astrolabe:GetCurrentPlayerPosition()
		local file = c and z and Astrolabe.ContinentList[c] and Astrolabe.ContinentList[c][z]
		if file and file == self.minimapMap then return end
	end
	self.minimapMap = nil
	releaseAll(self.minimapPool, true)
	self.minimapPending = false
	if not RA.db.markerEnabled or not Astrolabe or not Minimap then return end
	local continent, zone = Astrolabe:GetCurrentPlayerPosition()
	if not continent then
		-- The world map is open on another zone; try again once it closes.
		self.minimapPending = WorldMapFrame and WorldMapFrame:IsShown()
		return
	end
	if not zone or zone == 0 then return end
	local currentMap = Astrolabe.ContinentList[continent] and Astrolabe.ContinentList[continent][zone]
	if not currentMap then return end
	self.minimapMap, self.minimapStale = currentMap, false
	for _, pin in ipairs(self:GetPins()) do
		if pin.mapFile == currentMap then
			local button = acquire(self.minimapPool, Minimap)
			button:SetParent(Minimap)
			button:SetFrameStrata("MEDIUM")
			button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
			local ok = pcall(configurePin, button, pin, true)
			if not ok or Astrolabe:PlaceIconOnMinimap(button, continent, zone, pin.x, pin.y) ~= 0 then button:Hide() end
		end
	end
end

---------------------------------------------------------------------------
-- World map pins
---------------------------------------------------------------------------
function Map:WorldGeometryKey()
	if not WorldMapButton or not WorldMapFrame or not WorldMapFrame:IsShown() then return "hidden" end
	return table.concat({ tostring(GetCurrentMapContinent()), tostring(GetCurrentMapZone()), tostring(GetMapInfo()),
		tostring(GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0),
		string.format("%.1f:%.1f:%.3f", WorldMapButton:GetWidth(), WorldMapButton:GetHeight(), WorldMapButton:GetEffectiveScale()),
		tostring(RA.dataVersion), tostring(self.focus) }, ":")
end

local function clusterPins(placements, radius)
	table.sort(placements, function(a, b)
		if a.px == b.px then return a.py < b.py end
		return a.px < b.px
	end)
	local clusters, cells, cellSize = {}, {}, radius + 4
	local function cellKey(x, y) return x .. ":" .. y end
	for _, p in ipairs(placements) do
		local cx, cy = math.floor(p.px / cellSize), math.floor(p.py / cellSize)
		local best, bestDistance
		for x = cx - 1, cx + 1 do
			for y = cy - 1, cy + 1 do
				for _, cluster in ipairs(cells[cellKey(x, y)] or {}) do
					local dx, dy = p.px - cluster.ax, p.py - cluster.ay
					local d = dx * dx + dy * dy
					if d <= radius * radius and (not bestDistance or d < bestDistance) then best, bestDistance = cluster, d end
				end
			end
		end
		if not best then
			best = { ax = p.px, ay = p.py, sx = 0, sy = 0, members = {}, recipes = {}, recipeCount = 0, sourceTypes = {} }
			clusters[#clusters + 1] = best
			local key = cellKey(cx, cy)
			cells[key] = cells[key] or {}
			table.insert(cells[key], best)
		end
		local pin = p.pin
		best.members[#best.members + 1] = pin
		best.sx, best.sy = best.sx + p.px, best.sy + p.py
		for key, entry in pairs(pin.recipes) do
			if not best.recipes[key] then best.recipes[key] = entry; best.recipeCount = best.recipeCount + 1 end
		end
		for kind in pairs(pin.sourceTypes) do best.sourceTypes[kind] = true end
		if not best.sourceType or priority[pin.sourceType] < priority[best.sourceType] then best.sourceType = pin.sourceType end
	end
	for _, c in ipairs(clusters) do
		c.cx, c.cy = c.sx / #c.members, c.sy / #c.members
		local first = c.members[1]
		c.name, c.mapFile, c.x, c.y = first.name, first.mapFile, first.x, first.y
	end
	return clusters
end

function Map:RefreshWorldMap()
	if not self.initialized then return end
	self.worldKey = self:WorldGeometryKey()
	if self.worldMapTooltip then self.worldMapTooltip:Hide() end
	releaseAll(self.worldPool, false)
	local stats = { pins = 0, placed = 0, direct = 0, translated = 0, other = 0 }
	self.worldMapStats = stats
	if self.focusButton then
		local entry = self.focus and RA.recipeByKey[self.focus]
		if entry then
			self.focusButton:SetText("Сбросить: " .. RA:GetSpellName(entry.spellID, entry.itemID))
			self.focusButton:Show()
		else
			self.focusButton:Hide()
		end
	end
	if self.legend and WorldMapButton then
		local mapScale = WorldMapButton:GetScale() or 1
		local topLevel = math.max(WorldMapButton:GetFrameLevel() + 20, (WORLDMAP_POI_FRAMELEVEL or 0) + 10)
		if mapScale > 0.2 then self.legend:SetScale(1 / mapScale); self.focusButton:SetScale(1 / mapScale) end
		self.legend:SetFrameLevel(topLevel)
		self.focusButton:SetFrameLevel(topLevel)
		if RA.db.markerEnabled and WorldMapFrame and WorldMapFrame:IsShown() then self.legend:Show() else self.legend:Hide() end
	end
	if not RA.db.markerEnabled or not WorldMapFrame or not WorldMapFrame:IsShown() or not WorldMapButton then return end

	local mapContinent = tonumber(GetCurrentMapContinent()) or -1
	local mapZone = tonumber(GetCurrentMapZone()) or 0
	if mapZone < 0 then mapZone = 0 end
	local mapFile = GetMapInfo()
	local level = GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0
	stats.continent, stats.zone, stats.mapFile, stats.level = mapContinent, mapZone, mapFile, level
	local width, height = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
	local scale = WorldMapButton:GetEffectiveScale() or 1
	local placements = {}
	local pins = self:GetPins()
	stats.pins = #pins
	for _, pin in ipairs(pins) do
		local x, y
		if mapFile and pin.mapFile == mapFile then
			x, y = pin.x, pin.y
			if mapFile == "Dalaran" and level == 2 then
				if pin.floor == 2 then x, y = dalaranToLevel2(x, y) else x = nil end
			elseif mapFile == "Dalaran" and pin.floor == 2 then
				x = nil
			end
			stats.direct = stats.direct + 1
		elseif mapZone == 0 and mapContinent >= 0 then
			-- Continent or world view: translate every zone. Zone view shows only its own pins,
			-- so cities don't spill into neighbouring zone maps.
			local c, z = self:FindContinentZone(pin.mapFile)
			if c and z then
				x, y = Astrolabe:TranslateWorldMapPosition(c, z, pin.x, pin.y, mapContinent, 0)
				stats.translated = stats.translated + 1
			end
		else
			stats.other = stats.other + 1
		end
		if x and y and x == x and y == y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
			placements[#placements + 1] = { pin = pin, px = x * width * scale, py = y * height * scale }
		end
	end
	local clusters = clusterPins(placements, 20 * (UIParent:GetEffectiveScale() or 1))
	local strata = WorldMapButton:GetFrameStrata()
	-- above Blizzard quest POI icons (they sit at WORLDMAP_POI_FRAMELEVEL and +1) so quest markers can't cover pins
	local frameLevel = math.max(WorldMapButton:GetFrameLevel() + 6, (WORLDMAP_POI_FRAMELEVEL or 0) + 3)
	local failed
	for _, cluster in ipairs(clusters) do
		local button = acquire(self.worldPool, WorldMapButton)
		local ok, err = pcall(function()
			button:SetParent(WorldMapButton)
			button:SetFrameStrata(strata)
			button:SetFrameLevel(frameLevel)
			configurePin(button, cluster, false)
			button:ClearAllPoints()
			button:SetPoint("CENTER", WorldMapButton, "TOPLEFT", cluster.cx / scale, -cluster.cy / scale)
			button:Show()
		end)
		if ok then stats.placed = stats.placed + 1 else failed = failed or err end
	end
	if failed then
		stats.lastError = tostring(failed)
		-- one pin failing must not leave the zone empty: retry once on the next watcher tick
		if not self.retriedKey or self.retriedKey ~= self.worldKey then self.retriedKey, self.worldKey = self.worldKey, nil end
	end
end

---------------------------------------------------------------------------
-- Focus on one recipe / waypoints
---------------------------------------------------------------------------
function Map:HasTomTom()
	return _G.TomTom and (_G.TomTom.AddZWaypoint or _G.TomTom.AddMFWaypoint) and true or false
end

function Map:AddWaypoint(pin)
	if not self:HasTomTom() or not pin or not pin.x then return end
	local c, z = self:FindContinentZone(pin.mapFile)
	if not c then return end
	local ok = pcall(_G.TomTom.AddZWaypoint, _G.TomTom, c, z, pin.x * 100, pin.y * 100, pin.name)
	if ok then RA:Print("точка TomTom: " .. (pin.name or "?")) end
end

-- Shows the world map with only this recipe's sources. Returns false if nothing can be pinned.
function Map:ShowRecipeOnMap(entry)
	self.focus = entry.key
	self.pinCache = nil
	local pins = self:GetPins()
	if #pins == 0 then
		self.focus = nil
		self.pinCache = nil
		return false
	end
	local target
	local continent, zone = Astrolabe:GetCurrentPlayerPosition()
	local playerFile = continent and zone and Astrolabe.ContinentList[continent] and Astrolabe.ContinentList[continent][zone]
	for _, pin in ipairs(pins) do
		if pin.mapFile == playerFile then target = pin break end
	end
	target = target or pins[1]
	if not RA.db.markerEnabled then
		RA.db.markerEnabled = true
		RA:Print("метки на карте включены.")
	end
	if not WorldMapFrame:IsShown() then
		if InCombatLockdown and InCombatLockdown() then
			RA:Print("карту нельзя открыть в бою.")
		else
			ShowUIPanel(WorldMapFrame)
		end
	end
	local c, z = self:FindContinentZone(target.mapFile)
	if c then SetMapZoom(c, z) end
	if target.mapFile == "Dalaran" and target.floor == 2 and SetDungeonMapLevel then SetDungeonMapLevel(2) end
	self:Invalidate()
	if RA.UI and RA.UI.RequestRefresh then RA.UI:RequestRefresh() end
	return true
end

function Map:PrintWorldMapStatus()
	local s = self.worldMapStats or {}
	RA:Print(string.format("карта: метки=%s, открыта=%s, файл=%s, уровень=%s, континент=%s, зона=%s; точек=%d, в зоне=%d, пересчитано=%d, на карте=%d; кнопок создано=%d/%d",
		tostring(RA.db.markerEnabled), tostring(WorldMapFrame and WorldMapFrame:IsShown()), tostring(s.mapFile or GetMapInfo()),
		tostring(s.level), tostring(s.continent), tostring(s.zone), s.pins or 0, s.direct or 0, s.translated or 0,
		s.placed or 0, #self.worldPool, #self.minimapPool))
	if s.lastError then RA:Print("последняя ошибка метки: " .. s.lastError) end
end
