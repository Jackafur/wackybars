-- Job pictures (his ask, Nov 24: "some of my keys like H show on my actionbar but no longer bound as an actionbar thing. so
-- i would like to put an icon on there", then "we need a clip icon and an interact icon. same size as the wow spell icons"):
-- a key bound in Key Bindings to a job that is not a bar button (H = Interact With Target, AutoClip's Save a clip) shows that
-- job's picture on its button, with its key, and the job's name when you hover it. Only a picture: the key keeps doing what
-- Key Bindings says (WackyBars never touches it), and the button's own spare slot stays below it, so a spell you drag
-- there shows instead. Pictures: icons\*.tga, 64 x 64 like the game's spell icons (drawn Nov 24).
-- Cost: nothing runs on its own: a pass over the buttons after each apply, and, while a key has a job, one when an action
-- slot changes.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local DIR = "Interface\\AddOns\\WackyBars\\icons\\"
-- the binding command -> its picture and the name if the game (or its addon) has none
local JOBS = {
	INTERACTTARGET = { icon = DIR .. "interact", name = "Interact With Target" },
	INTERACTMOUSEOVER = { icon = DIR .. "interact", name = "Interact With Mouseover" },
	AUTOCLIP_SAVE = { icon = DIR .. "clip", name = "AutoClip: save a clip (the last 2 minutes)" },
}

local pics = {}
local function jobOf(b)
	local q = b.wb
	return q and q.kind == "other" and q.other and JOBS[q.other] or nil
end
local function slotFull(b)
	local s = b.wb.slot
	return s ~= nil and HasAction(s) and true or false
end
-- the key as the button would write it: the spot's label, with s / c / a in front on a modifier bar when labels show it
local function keyLabel(b)
	local S, bar, DB = b.wb.spot, b.wb.bar, wb.db()
	if DB and DB.mods and not S.fixedMod and bar.short ~= "" then return bar.short .. S.label end
	return S.label
end
local function showing(b)
	local p = pics[b]
	return p and p:IsShown() and true or false
end

local function picOf(b)
	local p = pics[b]
	if p then return p end
	p = b:CreateTexture(nil, "ARTWORK", nil, 1) -- (over the empty slot, under the frame and the key text)
	local icon = type(b.icon) == "table" and b.icon or b
	p:SetAllPoints(icon)
	if b.IconMask and p.AddMaskTexture then p:AddMaskTexture(b.IconMask) end
	pics[b] = p
	-- the hover: the job's name and its key (Edit keys keeps its own tip)
	b:HookScript("OnEnter", function(self)
		local job = jobOf(self)
		if not (job and showing(self)) or wb.editing() then return end
		if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self)
		else GameTooltip:SetOwner(self, "ANCHOR_RIGHT") end
		GameTooltip:SetText(_G["BINDING_NAME_" .. self.wb.other] or job.name)
		GameTooltip:AddLine("Key: " .. (self.wb.def and GetBindingText(self.wb.def) or "none"), 1, 1, 1)
		GameTooltip:Show()
	end)
	-- the key text: the library asks the button for it on every update; a job button answers with its key
	local own = b.GetHotkey
	b.GetHotkey = function(self)
		local t = own and own(self)
		if (not t or t == "") and showing(self) then return keyLabel(self) end
		return t
	end
	return p
end

local function refresh(b)
	local job = b:IsShown() and jobOf(b)
	local on = job and not slotFull(b)
	if not on then
		if pics[b] then pics[b]:Hide() end
		return
	end
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
	local hk = b.HotKey
	if hk then
		hk:SetText(keyLabel(b))
		hk:Show()
	end
end
-- a spell dragged onto a job button (or taken off it): the picture goes or comes back. Listened to only while some button
-- has a job, so with none (another player, or no such key) nothing runs.
local watch = CreateFrame("Frame")
local function refreshAll()
	local any = false
	for _, b in ipairs(wb.buttons) do
		refresh(b)
		if jobOf(b) then any = true end
	end
	if any then watch:RegisterEvent("ACTIONBAR_SLOT_CHANGED") else watch:UnregisterEvent("ACTIONBAR_SLOT_CHANGED") end
end
wb.applyHooks[#wb.applyHooks + 1] = refreshAll

watch:SetScript("OnEvent", function(_, _, slot)
	for _, b in ipairs(wb.buttons) do
		if pics[b] or jobOf(b) then
			if slot == 0 or b.wb.slot == slot then refresh(b) end
		end
	end
end)

ns.wb.jobs = { list = JOBS, showing = showing, pic = function(b) return pics[b] end } -- (for the tests)
