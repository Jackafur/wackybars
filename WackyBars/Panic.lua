-- Panic flash (his pick, Nov 10 night: "not a bad idea either. especially for some other classes like mage, rogue, hunter,
-- paladin to"): in a fight, under 30% health, the buttons of your escape spells pulse, and the Healthstone's and healing
-- potions' too. A button counts by the name of what it holds (a spell, an item, or a macro's spell or item), so every rank
-- of a spell counts. One box in /wbars switches it off.
-- The game keeps your health from addons (a hidden value, also outside a fight), so WackyBars never reads it: as QuietHUD's
-- Low health column does, it hands the game a step curve (1 under 30%, 0 from 30% up) and the game sets each pulse's
-- opacity from it. The pulse is the game's own spell highlight (the frame-shaped glow a suggested spell pulses with, the same
-- 0.35 s up and down), tinted with the button's slice of its bar's Purple to pink gradient, at half strength. It sits on the
-- button, so it fades with its bar: tick Low health on that bar's row in QuietHUD and the bar comes up with it.
-- Only in a fight: out of one, low health is you eating or drinking, and nothing pulses.
-- Cost: out of a fight nothing runs (two events: a fight starting and ending). In a fight: the buttons are read once (what
-- each holds), again a frame after a page or slot change; per change of your health, one curve and one opacity per pulsing
-- button; the pulses are the game's animations (a few buttons). No OnUpdate.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local BELOW, STEP_EDGE, PEAK, HALF = 0.30, 0.001, 0.5, 0.35
local GLOW_ATLAS = "UI-HUD-ActionBar-IconFrame-Mouseover"
-- The escape spells, by class. From his Forever bar plans (built from Naowh's Forever
-- spell lists): Warlock, Mage, Rogue, Hunter and Paladin. The rest are the old game's names, not checked on Forever (he is
-- asked; a name the game doesn't have never lights anything): Hunter's Deterrence and Scatter Shot, Paladin's Divine
-- Protection, and every Priest, Warrior, Druid and Shaman spell.
local ESCAPES = {
	WARLOCK = { "Death Coil", "Howl of Terror" },
	MAGE = { "Blink", "Frost Nova", "Ice Block", "Ice Barrier" },
	ROGUE = { "Vanish", "Sprint", "Evasion", "Blind" },
	HUNTER = { "Feign Death", "Disengage", "Frost Trap", "Deterrence", "Scatter Shot" },
	PALADIN = { "Divine Shield", "Blessing of Protection", "Lay on Hands", "Hammer of Justice", "Divine Protection" },
	PRIEST = { "Psychic Scream", "Power Word: Shield", "Fade", "Desperate Prayer" },
	WARRIOR = { "Intimidating Shout", "Shield Wall", "Last Stand" },
	DRUID = { "Barkskin", "Frenzied Regeneration", "Dash", "Nature's Grasp" },
	SHAMAN = { "Earthbind Totem", "Frost Shock", "Grounding Totem" },
}
-- Every class: any Healthstone and any healing potion, every size.
local ANY_CLASS = { "Healthstone", "Healing Potion" }

local escapes
local function isEscape(name)
	if type(name) ~= "string" or name == "" then return false end
	if not escapes then
		escapes = {}
		local _, class = UnitClass("player")
		for _, n in ipairs(ESCAPES[class] or {}) do escapes[n] = true end
	end
	if escapes[name] then return true end
	for _, part in ipairs(ANY_CLASS) do
		if name:find(part, 1, true) then return true end
	end
	return false
end

local waiting = false -- (an item's name the game had not loaded yet: read again when it has)
local function spellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	if GetSpellInfo then return (GetSpellInfo(id)) end
end
local function itemName(id)
	local n
	if C_Item and C_Item.GetItemNameByID then n = C_Item.GetItemNameByID(id) elseif GetItemInfo then n = GetItemInfo(id) end
	if not n then waiting = true end
	return n
end
local function secret(v) return issecretvalue and issecretvalue(v) or false end
-- What an action slot holds, by name: a spell, an item, or a macro's spell or item.
local function actionName(slot)
	local ok, kind, id, sub = pcall(GetActionInfo, slot)
	if not ok or kind == nil or id == nil or secret(kind) or secret(id) then return nil end
	if kind == "spell" then return spellName(id) end
	if kind == "item" then return itemName(id) end
	if kind == "macro" then
		if sub == "spell" then return spellName(id) end
		local s = GetMacroSpell and GetMacroSpell(id)
		if s and not secret(s) then return spellName(s) end
		local n = GetMacroItem and GetMacroItem(id)
		if type(n) == "string" and not secret(n) then return n end
	end
end

-- A button's pulse: a frame on the button (so it fades with its bar) whose opacity the game sets from your health, holding
-- the highlight that pulses.
local pulses = {}
local function pulseOf(b)
	local p = pulses[b]
	if p then return p end
	local gate = CreateFrame("Frame", nil, b)
	gate:SetAllPoints(b)
	gate:SetFrameLevel(b:GetFrameLevel() + 5) -- (over the icon and the cooldown, under the key text)
	gate:EnableMouse(false)
	gate:SetAlpha(0)
	local tex = gate:CreateTexture(nil, "OVERLAY")
	tex:SetAtlas(GLOW_ATLAS)
	tex:SetBlendMode("ADD")
	local anim = tex:CreateAnimationGroup()
	anim:SetLooping("REPEAT")
	local up = anim:CreateAnimation("Alpha")
	up:SetFromAlpha(0)
	up:SetToAlpha(PEAK)
	up:SetDuration(HALF)
	up:SetSmoothing("OUT")
	up:SetOrder(1)
	local down = anim:CreateAnimation("Alpha")
	down:SetFromAlpha(PEAK)
	down:SetToAlpha(0)
	down:SetDuration(HALF)
	down:SetSmoothing("IN")
	down:SetOrder(2)
	p = { gate = gate, tex = tex, anim = anim }
	pulses[b] = p
	return p
end

-- The game's step curve over your health: 1 under 30%, 0 from 30% up (a hidden value, only the game can use it). Without the
-- curve (an older client) a health it lets us read; else nothing pulses.
local curve
local function lowAlpha()
	if C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and UnitHealthPercent then
		local ok, v = pcall(function()
			if not curve then
				curve = C_CurveUtil.CreateCurve()
				curve:SetType(Enum.LuaCurveType.Step)
				curve:AddPoint(0, 1)
				curve:AddPoint(BELOW - STEP_EDGE, 1)
				curve:AddPoint(BELOW, 0)
				curve:AddPoint(1, 0)
			end
			return UnitHealthPercent("player", true, curve)
		end)
		if ok and v ~= nil then return v end
	end
	local ok, hp, max = pcall(function() return UnitHealth("player"), UnitHealthMax("player") end)
	if ok and type(hp) == "number" and type(max) == "number" and not secret(hp) and not secret(max) and max > 0 then
		return hp / max < BELOW and 1 or 0
	end
	return 0
end

local lit = {} -- (the buttons pulsing in this fight)
local function setGates()
	local a = lowAlpha()
	for b in pairs(lit) do pcall(pulses[b].gate.SetAlpha, pulses[b].gate, a) end
end
local function stopAll()
	for b in pairs(lit) do
		local p = pulses[b]
		p.anim:Stop()
		p.gate:Hide()
		lit[b] = nil
	end
end
-- Reads which shown buttons hold an escape (each button's action as it is now, paged or not) and starts their pulses.
local function scan()
	waiting = false
	local now = {}
	for _, b in ipairs(wb.buttons) do
		if b:IsShown() and wb.barOn(b.wb.bar) then
			local kind, slot = b:GetAction()
			if kind == "action" and type(slot) == "number" and isEscape(actionName(slot)) then now[b] = true end
		end
	end
	for b in pairs(lit) do
		if not now[b] then
			pulses[b].anim:Stop()
			pulses[b].gate:Hide()
			lit[b] = nil
		end
	end
	for b in pairs(now) do
		if not lit[b] then
			local p = pulseOf(b)
			local w, h
			if b.wbSize then w, h = b.wbSize[1], b.wbSize[2] else w, h = b:GetWidth(), b:GetHeight() end
			p.tex:ClearAllPoints()
			p.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0) -- (where the game puts the button's own highlight, scaled with it)
			p.tex:SetSize(46 / 45 * (w or 45), h or 45)
			wb.gradOn(p.tex, b.wb.bar, b)
			p.gate:Show()
			p.anim:Play()
			lit[b] = true
		end
	end
	setGates()
end

local events = CreateFrame("Frame")
-- (in a fight: your health, and a page or slot change, after which the buttons are read again a frame later, once)
local FIGHT = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM" }
local HEALTH = { "UNIT_HEALTH", "UNIT_MAXHEALTH" }
local inFight, rescanQueued = false, false
local function on()
	local DB = wb.db()
	return DB and not DB.noPanic and true or false
end
local function fight(start)
	inFight = start
	for _, e in ipairs(HEALTH) do
		if start then
			if not pcall(events.RegisterUnitEvent, events, e, "player") then events:RegisterEvent(e) end
		else
			events:UnregisterEvent(e)
		end
	end
	for _, e in ipairs(FIGHT) do
		if start then events:RegisterEvent(e) else events:UnregisterEvent(e) end
	end
	if start then
		scan()
	else
		stopAll()
		waiting = false
	end
	-- (an item whose name the game had not loaded yet: the buttons are read again once it has)
	if waiting then events:RegisterEvent("GET_ITEM_INFO_RECEIVED") else events:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end
end
local function rescan()
	rescanQueued = false
	if inFight then
		scan()
		if waiting then events:RegisterEvent("GET_ITEM_INFO_RECEIVED") else events:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end
	end
end
events:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_REGEN_DISABLED" then
		if on() then fight(true) end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if inFight then fight(false) end
	elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		if unit == "player" then setGates() end
	elseif inFight and not rescanQueued then
		rescanQueued = true
		C_Timer.After(0, rescan)
	end
end)
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

-- The box in /wbars (on unless you untick it; changed out of a fight only, so nothing is pulsing then).
wb.optionRows[#wb.optionRows + 1] = {
	label = "Panic flash (escape spells pulse under 30% health)",
	get = on,
	set = function(v) wb.db().noPanic = (not v) or nil end,
}
