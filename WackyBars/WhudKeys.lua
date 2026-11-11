-- Your keys on Warlock HUD's icons (his /whud message, Nov 10: "has a thing where it shows a WA style thing. it would be nice
-- if my keys for the things it showed, showed up on it to. just like a wackybar thing that overlays the keys their to"):
-- while Warlock HUD is loaded, each of its icons whose spell or item sits on one of your keys shows that key in its top
-- right corner, the way an action button shows its key. No box.
-- How an icon finds its key: by its picture. A Warlock HUD icon shows the same picture as the action slot that holds its
-- spell (every rank alike) or its item (the Healthstone); the key is the one that fires that slot: a WackyBars button's (the
-- key you gave it in Edit keys too), with its modifier always in front (sQ, cQ, aQ, h1: on the HUD no bar says which), else
-- the key bound in Key Bindings to the game's bar button for that slot. One picture on several keys: the slot with the
-- spell or item itself, then a macro casting only that one spell, then any other macro; a key without Shift, Ctrl or Alt
-- before one with; then WackyBars' order (the plain keyboard first).
-- Warlock HUD is left as it is: WackyBars finds its rows through Warlock HUD's own WarlockHudAPI.GetDemoAnchors and puts one
-- frame of its own on each row, over the icons, so the keys show, fade and move with the row. It only reads the icons (and
-- follows when Warlock HUD changes one's picture or shows or hides it).
-- Cost: nothing without Warlock HUD. With it nothing runs on its own: the keys are worked out again a frame after a change
-- (your bindings, an action slot, WackyBars' bars, Warlock HUD rebuilding its rows or changing an icon's picture).
-- Warlock HUD rebuilds its rows by itself too, on a pet summoned (his "the binds are gone on whud" after swapping Imp and
-- Voidwalker, Nov 10 night), a spec profile, after a fight; every rebuild ends with its WarlockHudRefreshNameplates (called
-- only there and once at its login), so the keys follow that call.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local ROWS = { "main", "utility", "buffs", "consumes", "procs" } -- (Warlock HUD's rows with spell and item icons)
-- The game's eight bars: the key command of their buttons and the page their slots are on (as WackyBars.lua has them), for
-- a key bound to a game bar button that is no WackyBars spot.
local GAME_BARS = { { "ACTIONBUTTON", 1 }, { "MULTIACTIONBAR1BUTTON", 6 }, { "MULTIACTIONBAR2BUTTON", 5 },
	{ "MULTIACTIONBAR3BUTTON", 3 }, { "MULTIACTIONBAR4BUTTON", 4 }, { "MULTIACTIONBAR5BUTTON", 13 },
	{ "MULTIACTIONBAR6BUTTON", 14 }, { "MULTIACTIONBAR7BUTTON", 15 } }

local overlays = {} -- (row name: WackyBars' frame on that row and its key labels)
local hooked, pictures, labelOf = {}, {}, {} -- (per Warlock HUD icon: followed, its last picture, its key label)
local queued, refresh = false, nil
local function queue()
	if queued then return end
	queued = true
	C_Timer.After(0, function()
		queued = false
		refresh()
	end)
end

local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function pictureOf(t)
	local ok, p = pcall(function()
		if t.GetTextureFileID then return t:GetTextureFileID() end
		return t:GetTexture()
	end)
	if ok and (type(p) == "number" or type(p) == "string") and not secret(p) then return p end
end

-- A WackyBars button's key as the HUD shows it: its spot's label with the modifier in front, or a key given in Edit keys.
local function keyText(b, k)
	if k == b.wb.def then
		local S, bar = b.wb.spot, b.wb.bar
		if bar.short ~= "" and not S.fixedMod then return bar.short .. S.label end
		return S.label
	end
	return GetBindingText(k, 1)
end
-- A key with Shift, Ctrl or Alt in it.
local function modified(k) return type(k) == "string" and (k:find("SHIFT%-") or k:find("CTRL%-") or k:find("ALT%-")) and true or false end
-- How many spells a macro casts (its /cast, /castsequence and /use lines, conditions and reset= left out).
local function macroSpells(body)
	local seen, n = {}, 0
	for line in body:gmatch("[^\n]+") do
		local cmd, rest = line:match("^%s*/(%a+)%s*(.*)$")
		cmd = cmd and cmd:lower()
		if cmd == "cast" or cmd == "castsequence" or cmd == "use" or cmd == "castrandom" then
			rest = rest:gsub("%b[]", ""):gsub("reset=%S+", "")
			for part in rest:gmatch("[^;,]+") do
				local nm = part:gsub("^%s*!?", ""):gsub("%s*$", ""):lower()
				if nm ~= "" and not seen[nm] then
					seen[nm] = true
					n = n + 1
				end
			end
		end
	end
	return n
end
-- How much a slot stands for the picture it shows: 0 the spell or item itself, 1 a macro that casts only one spell, 2 any
-- other macro (a cast sequence showing whatever it casts next). His "the ability you marked as swu is actually 1", then
-- "its still sWU" (Nov 10 night): his Agony macro on 1 and his Spam macro on Shift + wheel up both cast
-- only Bane of Agony, so the key without Shift, Ctrl or Alt decides.
local function rankOf(slot)
	local ok, kind, id = pcall(GetActionInfo, slot)
	if not ok or secret(kind) then return 2 end
	if kind ~= "macro" then return 0 end
	if not secret(id) and GetMacroInfo then
		local okm, _, _, body = pcall(GetMacroInfo, id)
		if okm and type(body) == "string" and not secret(body) and macroSpells(body) == 1 then return 1 end
	end
	return 2
end
-- Each picture on one of your keys, and that key.
local function keysByPicture()
	local list, seen = {}, {}
	for _, b in ipairs(wb.buttons) do
		local k = b:IsShown() and wb.effKey(b)
		if k then
			local kind, slot = b:GetAction()
			if kind == "action" and type(slot) == "number" and not seen[slot] then
				seen[slot] = true
				list[#list + 1] = { slot, keyText(b, k), modified(k) }
			end
		end
	end
	for _, g in ipairs(GAME_BARS) do
		for n = 1, 12 do
			local slot = (g[2] - 1) * 12 + n
			local key = not seen[slot] and GetBindingKey(g[1] .. n)
			if key then
				seen[slot] = true
				list[#list + 1] = { slot, GetBindingText(key, 1), modified(key) }
			end
		end
	end
	-- Several keys showing one picture: the one that stands for it most (rankOf), then one without Shift, Ctrl or Alt,
	-- then the order above (the plain keyboard first).
	local best = {}
	for _, e in ipairs(list) do
		local p = GetActionTexture(e[1])
		if not secret(p) and p ~= nil and type(e[2]) == "string" and e[2] ~= "" then
			local score = rankOf(e[1]) * 2 + (e[3] and 1 or 0)
			if not best[p] or score < best[p].score then best[p] = { score = score, key = e[2] } end
		end
	end
	local out = {}
	for p, e in pairs(best) do out[p] = e.key end
	return out
end

-- The pictures on a row: its own textures and its holders' (one level down).
local function iconsOf(anchor)
	local out = {}
	local function take(f)
		if not f.GetRegions then return end
		for _, r in ipairs({ f:GetRegions() }) do
			if r.GetObjectType and r:GetObjectType() == "Texture" then out[#out + 1] = r end
		end
	end
	take(anchor)
	for _, c in ipairs({ anchor:GetChildren() }) do take(c) end
	return out
end
-- An icon whose picture Warlock HUD changes, or that it shows or hides: its key follows.
local function follow(icon, p)
	pictures[icon] = p
	if hooked[icon] then return end
	hooked[icon] = true
	hooksecurefunc(icon, "SetTexture", function(self)
		if pictureOf(self) ~= pictures[self] then queue() end
	end)
	local function shown(self)
		local fs = labelOf[self]
		if fs then fs:SetShown(self:IsShown()) end
	end
	hooksecurefunc(icon, "Show", shown)
	hooksecurefunc(icon, "Hide", shown)
	hooksecurefunc(icon, "SetShown", shown)
end
-- WackyBars' frame on a row (made once, moved onto the new row when Warlock HUD rebuilds its rows), over its icons and the
-- aura buttons on them.
local function overlayOf(name, anchor)
	local o = overlays[name]
	if not o then
		o = { frame = CreateFrame("Frame", nil, anchor), labels = {}, used = 0 }
		o.frame:EnableMouse(false)
		overlays[name] = o
	end
	if o.anchor ~= anchor then
		o.anchor = anchor
		o.frame:SetParent(anchor)
		o.frame:ClearAllPoints()
		o.frame:SetAllPoints(anchor)
		o.frame:SetFrameLevel(anchor:GetFrameLevel() + 50)
		o.frame:Show()
	end
	return o
end
local function labelFor(o, icon)
	o.used = o.used + 1
	local fs = o.labels[o.used]
	if not fs then
		fs = o.frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray") -- (the game's key text on its buttons)
		fs:SetJustifyH("RIGHT")
		o.labels[o.used] = fs
	end
	fs:ClearAllPoints()
	fs:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -2)
	return fs
end

refresh = function()
	local api = WarlockHudAPI
	local ok, rows = pcall(function() return api and api.GetDemoAnchors and api.GetDemoAnchors() end)
	for _, o in pairs(overlays) do o.used = 0 end
	wipe(labelOf)
	if ok and type(rows) == "table" then
		local keys = keysByPicture()
		for _, name in ipairs(ROWS) do
			local anchor = rows[name]
			if type(anchor) == "table" and anchor.GetRegions then
				local o = overlayOf(name, anchor)
				for _, icon in ipairs(iconsOf(anchor)) do
					local p = pictureOf(icon)
					follow(icon, p)
					local key = p ~= nil and keys[p]
					if key then
						local fs = labelFor(o, icon)
						fs:SetText(key)
						-- a key wider than its icon is left off (his "can we take this caps text off here", Nov 11: Caps
						-- spilled over the small icons of Warlock HUD's buff row)
						local w, tw = icon:GetWidth(), fs:GetStringWidth()
						if type(w) == "number" and type(tw) == "number" and not secret(w) and not secret(tw) and tw > w - 2 then
							fs:Hide()
							o.used = o.used - 1
						else
							fs:SetShown(icon:IsShown())
							labelOf[icon] = fs
						end
					end
				end
			end
		end
	end
	for _, o in pairs(overlays) do
		for i = o.used + 1, #o.labels do o.labels[i]:Hide() end
	end
end

-- With Warlock HUD loaded: its rebuilds (its options call WarlockHudAPI.Rebuild; the rest come after these events, so the
-- keys are worked out a frame later), your bindings, action slots, WackyBars' bars.
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
	if event ~= "PLAYER_LOGIN" then
		queue()
		return
	end
	events:UnregisterEvent("PLAYER_LOGIN")
	local api = WarlockHudAPI
	if type(api) ~= "table" or type(api.GetDemoAnchors) ~= "function" then return end
	if type(api.Rebuild) == "function" then hooksecurefunc(api, "Rebuild", queue) end
	if type(WarlockHudRefreshNameplates) == "function" then hooksecurefunc(_G, "WarlockHudRefreshNameplates", queue) end
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED",
		"ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_REGEN_ENABLED" }) do
		events:RegisterEvent(e)
	end
	wb.applyHooks[#wb.applyHooks + 1] = queue
	queue()
end)
events:RegisterEvent("PLAYER_LOGIN")
