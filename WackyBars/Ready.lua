-- Ready shine (idea 4 from the ideas tab; his "did you do this btw", then "probably do fear and other big spells that would be
-- worth it for mage, rogue, hunter, paladin", Nov 11): when a big cooldown comes back, its button shines once, the game's spell
-- highlight tinted with the button's slice of its bar's gradient, up and down once (about 0.6 s). A button counts by the name
-- of what it holds (a spell, an item, or a macro's spell or item), so every rank counts. One box in /wbars switches it off.
-- How it knows a cooldown came back without reading it (the game hides cooldowns from addons in a fight): it watches the
-- cooldown sweep on the button. The sweep is handed to a sweep of WackyBars' own that draws nothing (the game's numbers passed
-- on, never looked at); when that one runs out, or the button's sweep is cleared, the cooldown is over. A sweep that ran less
-- than 3 seconds was the global cooldown and is skipped.
-- Names not on the Forever client never light anything; not checked on Forever: Shadowburn, Amplify Curse, Cold Snap,
-- Presence of Mind, Arcane Power, Combustion, Preparation, Readiness, Deterrence, Repentance.
-- Cost: nothing runs on its own: a few lines when a button's sweep starts or ends, then the game's animation. No OnUpdate.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local MIN = 3 -- (seconds: a shorter sweep is the global cooldown)
local RISE, FALL, PEAK = 0.25, 0.35, 0.5
local GLOW_ATLAS = "UI-HUD-ActionBar-IconFrame-Mouseover"
local BIG = {
	WARLOCK = { "Death Coil", "Howl of Terror", "Fear", "Shadowburn", "Amplify Curse" },
	MAGE = { "Blink", "Frost Nova", "Ice Block", "Ice Barrier", "Counterspell", "Evocation", "Cold Snap", "Presence of Mind",
		"Arcane Power", "Combustion" },
	ROGUE = { "Vanish", "Sprint", "Evasion", "Blind", "Kick", "Kidney Shot", "Adrenaline Rush", "Blade Flurry", "Cold Blood",
		"Preparation" },
	HUNTER = { "Feign Death", "Disengage", "Freezing Trap", "Frost Trap", "Rapid Fire", "Bestial Wrath", "Intimidation",
		"Scatter Shot", "Deterrence", "Readiness" },
	PALADIN = { "Divine Shield", "Blessing of Protection", "Lay on Hands", "Hammer of Justice", "Divine Protection",
		"Divine Favor", "Blessing of Freedom", "Repentance" },
}
-- Items, by a part of their name (every size): the warlock's Soulstone; a Healthstone for anyone carrying one.
local ITEM_PARTS = { WARLOCK = { "Soulstone" }, ANY = { "Healthstone" } }

local big, parts
local function isBig(name)
	if type(name) ~= "string" or name == "" then return false end
	if not big then
		local _, class = UnitClass("player")
		big, parts = {}, {}
		for _, n in ipairs(BIG[class] or {}) do big[n] = true end
		for _, n in ipairs(ITEM_PARTS[class] or {}) do parts[#parts + 1] = n end
		for _, n in ipairs(ITEM_PARTS.ANY) do parts[#parts + 1] = n end
	end
	if big[name] then return true end
	for _, part in ipairs(parts) do
		if name:find(part, 1, true) then return true end
	end
	return false
end

local function on()
	local DB = wb.db()
	return DB and not DB.noReady and true or false
end

-- The shine: a frame on the button (so it fades with its bar) with the highlight, played once.
local shines = {}
local function shineOf(b)
	local s = shines[b]
	if s then return s end
	local frame = CreateFrame("Frame", nil, b)
	frame:SetAllPoints(b)
	frame:SetFrameLevel(b:GetFrameLevel() + 5) -- (over the icon and the cooldown, under the key text)
	frame:EnableMouse(false)
	local tex = frame:CreateTexture(nil, "OVERLAY")
	tex:SetAtlas(GLOW_ATLAS)
	tex:SetBlendMode("ADD")
	tex:SetAlpha(0)
	local anim = tex:CreateAnimationGroup()
	local up = anim:CreateAnimation("Alpha")
	up:SetFromAlpha(0)
	up:SetToAlpha(PEAK)
	up:SetDuration(RISE)
	up:SetSmoothing("OUT")
	up:SetOrder(1)
	local down = anim:CreateAnimation("Alpha")
	down:SetFromAlpha(PEAK)
	down:SetToAlpha(0)
	down:SetDuration(FALL)
	down:SetSmoothing("IN")
	down:SetOrder(2)
	s = { frame = frame, tex = tex, anim = anim }
	shines[b] = s
	return s
end
local function shine(b)
	if not (on() and b:IsShown() and wb.barOn(b.wb.bar)) then return end
	local kind, slot = b:GetAction()
	if kind ~= "action" or type(slot) ~= "number" or not isBig(wb.actionName(slot)) then return end
	local s = shineOf(b)
	local w, h
	if b.wbSize then w, h = b.wbSize[1], b.wbSize[2] else w, h = b:GetWidth(), b:GetHeight() end
	s.tex:ClearAllPoints()
	s.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0) -- (where the game puts the button's own highlight, scaled with it)
	s.tex:SetSize(46 / 45 * (w or 45), h or 45)
	wb.gradOn(s.tex, b.wb.bar, b)
	s.anim:Stop()
	s.anim:Play()
end

-- Each button's sweep, followed: when it started (the first time it was set since it last ended) and WackyBars' copy of it.
local watched = {} -- (a button's cooldown widget: { b = button, mirror = WackyBars' sweep, since = GetTime() or nil })
local function ended(w)
	local since = w.since
	w.since = nil
	if since and GetTime() - since >= MIN then shine(w.b) end
end
local function watch(b)
	local cd = b.cooldown
	if type(cd) ~= "table" or watched[cd] then return end
	local w = { b = b }
	watched[cd] = w
	local m = CreateFrame("Cooldown", nil, b)
	m:SetAllPoints(b)
	m:EnableMouse(false)
	if m.SetDrawSwipe then m:SetDrawSwipe(false) end
	if m.SetDrawEdge then m:SetDrawEdge(false) end
	if m.SetDrawBling then m:SetDrawBling(false) end
	if m.SetHideCountdownNumbers then m:SetHideCountdownNumbers(true) end
	m:SetScript("OnCooldownDone", function() ended(w) end)
	w.mirror = m
	local function started() if not w.since then w.since = GetTime() end end
	-- (the game's numbers are handed on as they are: the widget takes them without Lua looking at them)
	hooksecurefunc(cd, "SetCooldown", function(_, ...)
		started()
		pcall(m.SetCooldown, m, ...)
	end)
	if cd.SetCooldownFromDurationObject then
		hooksecurefunc(cd, "SetCooldownFromDurationObject", function(_, ...)
			started()
			pcall(m.SetCooldownFromDurationObject, m, ...)
		end)
	end
	hooksecurefunc(cd, "Clear", function()
		ended(w)
		pcall(m.Clear, m)
	end)
end
local function watchAll()
	for _, b in ipairs(wb.buttons) do watch(b) end
end
wb.applyHooks[#wb.applyHooks + 1] = watchAll
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	events:UnregisterEvent("PLAYER_LOGIN")
	watchAll()
end)

wb.optionRows[#wb.optionRows + 1] = {
	label = "Ready shine (a big cooldown's button shines once when it comes back)",
	get = on,
	set = function(v) wb.db().noReady = (not v) or nil end,
}
