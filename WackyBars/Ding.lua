-- Ding wave (his pick, Nov 10 night: "this was a nice one"): on a level up a purple to pink glow sweeps once, left to right,
-- across every WackyBars spot that shows (the movement keys' spots and the pet buttons in spots too), about 2 seconds, then
-- stops. /wbars ding plays it to look at. No setting.
-- Each spot's glow is the game's own spell highlight (the frame-shaped glow a suggested spell pulses with on the game's
-- buttons, ActionButtonTemplate), tinted with the spot's slice of its bar's Purple to pink gradient, at half strength: a
-- tint, not a flash (his rule: nothing bright on the HUD). The glows sit on each bar, outside the
-- holders QuietHUD fades, so the wave shows even while QuietHUD has the bars faded. Made the first time it plays, then kept.
-- Cost: nothing until a level up (one event, PLAYER_LEVEL_UP). Playing: the game's animations, about 2 seconds, one fade in
-- and out per spot, then nothing. No OnUpdate, no timer.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

-- The first spot on the left lights up at once, the last on the right 1.4 seconds later; each glows for 0.6 seconds.
local SWEEP, RISE, FALL, PEAK = 1.4, 0.25, 0.35, 0.5
local GLOW_ATLAS = "UI-HUD-ActionBar-IconFrame-Mouseover"
local layers, glows = {}, {}

-- One frame per bar for its glows: on the bar itself, over the buttons (the key text stays on top), at full whatever
-- QuietHUD sets (it fades the holders inside the bar, not the bar).
local function layerOf(bar)
	local l = layers[bar]
	if not l then
		l = CreateFrame("Frame", "WackyBarsDing" .. bar.id, bar.frame)
		l:SetAllPoints(bar.frame)
		l:EnableMouse(false)
		l:SetFrameLevel(bar.frame:GetFrameLevel() + 20)
		if l.SetIgnoreParentAlpha then l:SetIgnoreParentAlpha(true) end
		layers[bar] = l
	end
	return l
end

-- A spot's glow: the highlight texture with one fade in and one fade out; hidden again when done.
local function glowOf(b, bar)
	local g = glows[b]
	if g then return g end
	local tex = layerOf(bar):CreateTexture(nil, "OVERLAY")
	tex:SetAtlas(GLOW_ATLAS)
	tex:SetBlendMode("ADD")
	tex:SetAlpha(0)
	tex:Hide()
	local anim = tex:CreateAnimationGroup()
	local rise = anim:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(PEAK)
	rise:SetDuration(RISE)
	rise:SetSmoothing("OUT")
	rise:SetOrder(1)
	local fall = anim:CreateAnimation("Alpha")
	fall:SetFromAlpha(PEAK)
	fall:SetToAlpha(0)
	fall:SetDuration(FALL)
	fall:SetSmoothing("IN")
	fall:SetOrder(2)
	anim:SetScript("OnFinished", function() tex:Hide() end)
	g = { tex = tex, anim = anim, rise = rise }
	glows[b] = g
	return g
end

-- Plays the wave over the spots that show now: a button, a movement key's arrow, a pet key's spot with the game's pet button
-- in it. Each starts by where it sits on the screen, left to right over all the bars. Returns how many spots it lit.
local function play()
	if not wb.db() then return 0 end
	local petIn = {}
	for n = 1, 10 do
		local pb = _G["PetActionButton" .. n]
		if pb and pb.wbSpot and pb:IsVisible() then petIn[pb.wbSpot] = true end
	end
	local spots, lo, hi = {}, math.huge, -math.huge
	for _, bar in ipairs(wb.bars) do
		if wb.barOn(bar) and bar.frame:IsShown() then
			for _, b in ipairs(bar.buttons) do
				local arrow = b.wb.arrowTex
				if b:IsShown() or petIn[b] or (arrow and arrow:IsShown()) then
					local x, s = b:GetCenter(), b:GetEffectiveScale()
					x = (type(x) == "number" and type(s) == "number") and x * s or 0
					spots[#spots + 1] = { b = b, bar = bar, x = x }
					lo, hi = math.min(lo, x), math.max(hi, x)
				end
			end
		end
	end
	for _, s in ipairs(spots) do
		local g, b = glowOf(s.b, s.bar), s.b
		-- (where the game puts a button's own highlight: its frame, 46 x 45 at the top left, scaled with the button)
		local w, h
		if b.wbSize then w, h = b.wbSize[1], b.wbSize[2] else w, h = b:GetWidth(), b:GetHeight() end
		g.tex:ClearAllPoints()
		g.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
		g.tex:SetSize(46 / 45 * (w or 45), h or 45)
		wb.gradOn(g.tex, s.bar, b)
		g.rise:SetStartDelay(hi > lo and (s.x - lo) / (hi - lo) * SWEEP or 0)
		g.anim:Stop()
		g.tex:SetAlpha(0)
		g.tex:Show()
		g.anim:Play()
	end
	return #spots
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", play)

wb.slash.ding = function()
	if play() == 0 then wb.say("no bar shows, so there is nothing to light up.") end
end
