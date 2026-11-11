-- Interrupt nudge (idea 5 from the ideas tab; his "maybe this to if its legal", Nov 11): when the enemy you have targeted starts
-- a cast or a channel, the buttons of the spells that can stop it pulse until the cast ends, you change target, or the fight
-- ends. Mostly for PvP. It only shows: it never casts anything (that is what keeps it allowed, like every cast bar addon). It
-- listens to your target only, and reads nothing about the cast (the game may hide that): only that one started and ended.
-- The pulse is Panic flash's: the game's spell highlight, tinted with the button's slice of its bar's gradient, 0.35 s up and
-- down. A button counts by the name of what it holds (a spell, an item, or a macro's spell or item); Spell Lock is your
-- Felhunter's, so it pulses where a macro casting it sits on a WackyBars button (the game's pet buttons are not followed).
-- One box in /wbars switches it off. Not checked on Forever: Intimidation.
-- Cost: four events on your target (a cast starting and ending), a target change; per cast, the buttons read once. No OnUpdate.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local PEAK, HALF = 0.5, 0.35
local GLOW_ATLAS = "UI-HUD-ActionBar-IconFrame-Mouseover"
local STOPPERS = {
	WARLOCK = { "Death Coil", "Spell Lock" },
	MAGE = { "Counterspell" },
	ROGUE = { "Kick", "Kidney Shot", "Gouge" },
	HUNTER = { "Scatter Shot", "Intimidation" },
	PALADIN = { "Hammer of Justice" },
}
local START = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }
local STOP = { "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP" }

local stoppers
local function isStopper(name)
	if type(name) ~= "string" then return false end
	if not stoppers then
		stoppers = {}
		local _, class = UnitClass("player")
		for _, n in ipairs(STOPPERS[class] or {}) do stoppers[n] = true end
	end
	return stoppers[name] == true
end
local function on()
	local DB = wb.db()
	return DB and not DB.noNudge and true or false
end
local function secret(v) return issecretvalue and issecretvalue(v) or false end
-- An enemy target (a hidden answer counts as one: the pulse only shows, so a wrong guess costs nothing).
local function enemy()
	local ok, v = pcall(UnitCanAttack, "player", "target")
	if not ok then return false end
	if secret(v) then return true end
	return v and true or false
end

local pulses, lit = {}, {}
local function pulseOf(b)
	local p = pulses[b]
	if p then return p end
	local frame = CreateFrame("Frame", nil, b)
	frame:SetAllPoints(b)
	frame:SetFrameLevel(b:GetFrameLevel() + 5) -- (over the icon and the cooldown, under the key text)
	frame:EnableMouse(false)
	local tex = frame:CreateTexture(nil, "OVERLAY")
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
	p = { frame = frame, tex = tex, anim = anim }
	pulses[b] = p
	return p
end
local function stop()
	for b in pairs(lit) do
		pulses[b].anim:Stop()
		pulses[b].frame:Hide()
		lit[b] = nil
	end
end
local function start()
	stop()
	if not on() or not enemy() then return end
	for _, b in ipairs(wb.buttons) do
		if b:IsShown() and wb.barOn(b.wb.bar) then
			local kind, slot = b:GetAction()
			if kind == "action" and type(slot) == "number" and isStopper(wb.actionName(slot)) then
				local p = pulseOf(b)
				local w, h
				if b.wbSize then w, h = b.wbSize[1], b.wbSize[2] else w, h = b:GetWidth(), b:GetHeight() end
				p.tex:ClearAllPoints()
				p.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
				p.tex:SetSize(46 / 45 * (w or 45), h or 45)
				wb.gradOn(p.tex, b.wb.bar, b)
				p.frame:Show()
				p.anim:Play()
				lit[b] = true
			end
		end
	end
end

local events = CreateFrame("Frame")
local function listen(e)
	if not pcall(events.RegisterUnitEvent, events, e, "target") then events:RegisterEvent(e) end
end
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_LOGIN" then
		events:UnregisterEvent("PLAYER_LOGIN")
		local _, class = UnitClass("player")
		if not STOPPERS[class] then return end -- (a class with nothing on the list: nothing listened to)
		for e in pairs(START) do listen(e) end
		for _, e in ipairs(STOP) do listen(e) end
		events:RegisterEvent("PLAYER_TARGET_CHANGED")
		events:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
		stop()
	elseif unit == "target" then
		if START[event] then start() else stop() end
	end
end)

wb.optionRows[#wb.optionRows + 1] = {
	label = "Interrupt nudge (your target casts: the spells that stop it pulse)",
	get = on,
	set = function(v) wb.db().noNudge = (not v) or nil end,
}
