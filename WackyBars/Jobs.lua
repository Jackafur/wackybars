-- Jobs on keys (his ask, Nov 24: "some of my keys like H show on my actionbar but no longer bound as an actionbar thing. so
-- i would like to put an icon on there", "we need a clip icon and an interact icon. same size as the wow spell icons", then
-- "we need a icon for downtime menu in wackybars. and let it show what its bound to on wackbars again. like right now i have
-- downtime on 2 but it shows nothing bound on my bars"): a key bound in Key Bindings to a job that is not a bar button shows
-- its key on its button and the job's name when you hover it; a job WackyBars knows shows its picture too (H = Interact
-- With Target, 2 = Downtime's menu, AutoClip's Save a clip). Only a picture: the key keeps doing what Key Bindings says
-- (WackyBars never touches it). A job with a picture holds no slot (WackyBars.lua port: kind "job"); a key without one keeps
-- its spare slot below, so a spell you drag there shows instead.
-- Pictures: icons\*.tga, 64 x 64 like the game's spell icons (drawn Nov 24, tools\make_icons.py).
-- Cost: nothing runs on its own: a pass over the buttons after each apply, and, while a key has such a job, one when an
-- action slot changes.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local DIR = "Interface\\AddOns\\WackyBars\\icons\\"
-- the binding command -> its picture, and the name if the game (or its addon) gives none
local JOBS = {
	INTERACTTARGET = { icon = DIR .. "interact", name = "Interact With Target" },
	INTERACTMOUSEOVER = { icon = DIR .. "interact", name = "Interact With Mouseover" },
	AUTOCLIP_SAVE = { icon = DIR .. "clip", name = "AutoClip: save a clip (the last 2 minutes)" },
	["CLICK DowntimeKey:LeftButton"] = { icon = DIR .. "downtime", name = "Downtime menu" },
	-- his Alt utility keys (Nov 24, "just make the icons"): Alt + Z, F, X, E. (A Shift / Ctrl / Alt copy of a movement key
	-- keeps that key's arrow, his rule of Nov 10, so autorun on Alt + E shows E's arrow; the boot shows on any other key.)
	TOGGLEUI = { icon = DIR .. "hideui", name = "Toggle User Interface" },
	FOLLOWTARGET = { icon = DIR .. "follow", name = "Follow Target" },
	SITORSTAND = { icon = DIR .. "sit", name = "Sit/Stand" },
	TOGGLEAUTORUN = { icon = DIR .. "autorun", name = "Toggle Autorun" }, -- (on a key that doesn't move you)
}
-- the raid markers, with the game's own pictures (1 star, 2 circle, 3 diamond, 4 triangle, 5 moon, 6 square, 7 cross, 8 skull)
for i = 1, 8 do
	JOBS["RAIDTARGET" .. i] = { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i, name = "Raid marker " .. i }
end

local pics, labelled, hooked, tags = {}, {}, {}, {}
-- A job on a movement key's Alt / Shift / Ctrl copy keeps the key's arrow (his rule, Nov 10); a short word under the arrow
-- says the job instead of a picture (his "just do the regular E with no icon but maybe just include a stylized AUTO in
-- there", Nov 24, after the boot and a boot with a corner arrow both looked weird).
local TAGS = { TOGGLEAUTORUN = "AUTO" }
-- the job a button's key does, when it is not a bar button (nil otherwise)
local function cmdOf(b)
	local q = b.wb
	return q and (q.kind == "other" or q.kind == "job") and q.other or nil
end
local function slotFull(b)
	local s = b.wb.kind ~= "job" and b.wb.slot
	return s and HasAction(s) and true or false
end
-- the key as the button would write it: the spot's label, with s / c / a in front on a modifier bar when labels show it
local function keyLabel(b)
	local S, bar, DB = b.wb.spot, b.wb.bar, wb.db()
	if DB and DB.mods and not S.fixedMod and bar.short ~= "" then return bar.short .. S.label end
	return S.label
end
local function nameOf(cmd)
	local job = JOBS[cmd]
	return _G["BINDING_NAME_" .. cmd] or (job and job.name) or cmd:match("^CLICK ([^:]+)") or cmd
end
local function showing(b) return labelled[b] and true or false end

local function hook(b)
	if hooked[b] then return end
	hooked[b] = true
	-- the hover: the job's name and its key (Edit keys keeps its own tip)
	b:HookScript("OnEnter", function(self)
		local cmd = cmdOf(self)
		if not (cmd and labelled[self]) or wb.editing() then return end
		if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self)
		else GameTooltip:SetOwner(self, "ANCHOR_RIGHT") end
		GameTooltip:SetText(nameOf(cmd))
		GameTooltip:AddLine("Key: " .. (self.wb.def and GetBindingText(self.wb.def) or "none"), 1, 1, 1)
		GameTooltip:Show()
	end)
	-- the key text: the library asks the button for it on every update; a job button answers with its key
	local own = b.GetHotkey
	b.GetHotkey = function(self)
		local t = own and own(self)
		if (not t or t == "") and labelled[self] then return keyLabel(self) end
		return t
	end
end
local function picOf(b)
	local p = pics[b]
	if p then return p end
	p = b:CreateTexture(nil, "ARTWORK", nil, 1) -- (over the empty slot, under the frame and the key text)
	local icon = type(b.icon) == "table" and b.icon or b
	p:SetAllPoints(icon)
	if b.IconMask and p.AddMaskTexture then p:AddMaskTexture(b.IconMask) end
	pics[b] = p
	return p
end

local function refresh(b)
	local cmd = b:IsShown() and cmdOf(b)
	-- (a button you gave a key, or cleared, in Edit keys is yours: it shows what you set there)
	local DB = wb.db()
	local edited = DB and DB.keys and DB.keys[b.wb.id] ~= nil
	local on = cmd and not edited and not slotFull(b)
	labelled[b] = on and true or nil
	local job = on and JOBS[cmd]
	if not job then
		if pics[b] then pics[b]:Hide() end
	else
		local p = picOf(b)
		p:SetTexture(job.icon)
		p.wbIcon = job.icon
		-- (a wide key, like Caps, shows the middle band of the square picture, as WackyBars crops spell icons)
		local w, h = b:GetWidth(), b:GetHeight()
		if w and h and h > 0 and w > h then
			local band = h / w
			p:SetTexCoord(0, 1, 0.5 - band / 2, 0.5 + band / 2)
		else
			p:SetTexCoord(0, 1, 0, 1)
		end
		p:Show()
	end
	if on then
		hook(b)
		local hk = b.HotKey
		if hk then
			hk:SetText(keyLabel(b))
			hk:Show()
		end
	end
end
-- a spell dragged onto a job button (or taken off it): the picture and key go or come back. Listened to only while some
-- button has such a job, so with none nothing runs.
local watch = CreateFrame("Frame")
watch.wbJobs = true -- (the tests tell it from Warlock HUD's)
local function tagOf(b)
	local t = b.wb.arrowTex
	local word = t and t:IsShown() and b.wb.mod ~= "" and b.wb.def and TAGS[GetBindingAction(b.wb.def) or ""]
	local f = tags[b]
	if not word then
		if f then f:Hide() end
		return
	end
	local host = t:GetParent()
	if not f then
		f = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		tags[b] = f
	end
	f:SetParent(host) -- (the arrow moves between its bar and the bar's holder; the word goes with it)
	local font, size = f:GetFont()
	if font then f:SetFont(font, size or 10, "OUTLINE") end
	f:SetText(word)
	f:SetTextColor(1, 0.82, 0.2) -- (the game's gold)
	f:SetAlpha(0.8)
	f:ClearAllPoints()
	f:SetPoint("TOP", t, "BOTTOM", 0, 3)
	f:Show()
end
local function refreshAll()
	local any = false
	for _, b in ipairs(wb.buttons) do
		refresh(b)
		tagOf(b)
		if cmdOf(b) then any = true end
	end
	if any then watch:RegisterEvent("ACTIONBAR_SLOT_CHANGED") else watch:UnregisterEvent("ACTIONBAR_SLOT_CHANGED") end
end
wb.applyHooks[#wb.applyHooks + 1] = refreshAll
wb.modeHooks[#wb.modeHooks + 1] = function() for _, b in ipairs(wb.buttons) do tagOf(b) end end

watch:SetScript("OnEvent", function(_, _, slot)
	for _, b in ipairs(wb.buttons) do
		if cmdOf(b) and (slot == 0 or b.wb.slot == slot) then
			local was = labelled[b]
			refresh(b)
			-- (a spell dropped on it: its own key text is the library's again, none, as for any key that isn't a bar button)
			if was and not labelled[b] and b.HotKey then b.HotKey:Hide() end
		end
	end
end)

ns.wb.jobs = { list = JOBS, showing = showing, pic = function(b) return pics[b] end,
	tag = function(b) return tags[b] end } -- (for the tests)
