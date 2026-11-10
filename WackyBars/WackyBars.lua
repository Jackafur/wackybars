-- WackyBars: your keys as action bars placed like the keys on your keyboard and your Naga Pro, for WoW Forever.
-- The plain keys show; the Shift, Ctrl and Alt copies of each are bars you can switch on (off by default:
-- his plan of Nov 10 is married macros, [mod:shift] on the plain key, so those copies stay empty). The Hypershift side
-- buttons (they send Numpad) are their own bar. While WackyBars shows anything, the game's eight action bars are hidden.
--
-- Each button is a key and shows the action slot that key fires today, so nothing moves when it loads. It never writes your
-- saved key bindings (no SetBinding, no SaveBindings): the only keys it touches are override bindings, which the game
-- forgets the moment WackyBars is off. It adds them only for a key you change in quick edit, and for a free key (nothing
-- bound) that it gives a spare slot. A key you did not touch keeps going through the game's own bar button, so stealth,
-- vehicles and paging work as they always did, with that bar hidden. Fading, mouse over, fights, low health and click
-- through are QuietHUD's job: each bar sits in a holder frame of the game bar it follows (sortForQuietHUD), and QuietHUD
-- treats that holder like the game bar's own buttons. Input: a key you did not touch fires the game's own button, exactly as
-- without WackyBars; a key WackyBars binds presses its button the same way Bartender's do, on key down. Nothing is added in
-- between.
local ADDON, ns = ...
ns = ns or {} -- (the addon's table, shared with the feature files after this one in the TOC: ns.wb, end of file)
-- The buttons are Bartender4's (LibActionButton-1.0, in libs\): their secure state lives in attributes, so nothing the
-- game reads before a protected action is written by WackyBars' own code. The game's ActionBarButtonTemplate, used until
-- Nov 10, made every button "WackyBars' code" to the game (a right click got blocked; hovering in a fight, stance and
-- vehicle changes could too: the audit of Nov 10).
local LAB = LibStub("LibActionButton-1.0")
-- (QuietHUD's Tap Alt is told when a WackyBars button is used: its keys are override bindings it can't see)
local function tapUsed() if QuietHUD_TapKeyUsed then QuietHUD_TapKeyUsed() end end
-- Their settings: empty buttons show (WackyBars hides the ones it wants gone), keys bound by WackyBars press them the
-- way Bartender's do (key down casting works), the hotkey text is WackyBars' own (GetHotkey below).
local BUTTON_CONFIG = {
	showGrid = true,
	keyBoundClickButton = "Keybind",
	tooltip = "enabled",
	flyoutDirection = "UP",
	hideElements = { macro = false, hotkey = false, equipped = false },
}

local tint -- (the look, below)
local DB -- WackyBarsCharDB: keys = { [button id] = key or false }, spare = { [button id] = slot }, pos = { [bar id] = point },
-- off = { [bar id] = true }, hidden = { [button id] = true }, sizes = { [bar id] = n (nil: 1) }, stagger, mods (labels show
-- the modifier), noSnap, noEdges, noWheel, told, v

-- The modifier copies: each set (keyboard, mouse) is drawn once per layer. short: the letter in front of a label when the
-- labels show their modifier (his "sQ, cQ, aQ", Nov 10; off by default: "i like the not showing the modifier key").
local LAYERS = {
	{ id = "Plain", mod = "", short = "" },
	{ id = "Shift", mod = "SHIFT-", short = "s" },
	{ id = "Ctrl", mod = "CTRL-", short = "c" },
	{ id = "Alt", mod = "ALT-", short = "a", follow = 1 },
}
-- follow: the game bar whose row on QuietHUD's Action bars page these bars always follow (the Alt keyboard: Action Bar 1; the
-- Alt mouse goes with the plain mouse bar, set where the bars are made; his asks
-- Nov 10), whatever their keys are bound to.

-- A spot: key, name (for frame names and ids), label (shown when the key is its own), x (straight rows), sx (the keyboard's
-- stagger), row (0 = top), wide (key widths), small (a smaller button, centred in its spot unless alignX = "right" puts it
-- against that side). only: the layers it is on (else all). fixedMod: its key already has its modifier (Shift + wheel), so
-- its label always shows it. No key: a blank button (a spare slot; give it a key in Edit keys). A keyboard key bound to moving (yours are E S D F, the game's default W A S D and Q E)
-- shows a faint arrow instead of a button: it follows the game's Key Bindings, so a different setup just works.
local KEYBOARD = {}
do
	local rows = { { "1", "2", "3", "4", "5", "6" }, { "Q", "W", "E", "R", "T", "Y" }, { "A", "S", "D", "F", "G", "H" },
		{ "Z", "X", "C", "V" } }
	local stagger = { 1, 1.5, 1.75, 2.25 }
	for r, row in ipairs(rows) do
		for i, k in ipairs(row) do
			KEYBOARD[#KEYBOARD + 1] = { key = k, name = k, label = k, x = i, sx = stagger[r] + i - 1, row = r - 1 }
		end
	end
	-- the two after V, squaring off the grid: on the plain bar Shift + wheel up and down (his ask, Nov 10: "lave them as the
	-- 2 buttons after v"; the plain wheel is the camera, so these are the Shift ones, your Spam); on the Shift and Ctrl
	-- copies two blank buttons in their place, no key (his ask, Nov 10: "BLANK B and N buttons on shift and ctrl. dont bind
	-- them as literally B and N").
	local PLAIN, SHIFT_CTRL = { Plain = true }, { Shift = true, Ctrl = true }
	KEYBOARD[#KEYBOARD + 1] = { key = "SHIFT-MOUSEWHEELUP", name = "WheelUp", label = "sWU", x = 5, sx = 6.25, row = 3,
		only = PLAIN, fixedMod = true }
	KEYBOARD[#KEYBOARD + 1] = { key = "SHIFT-MOUSEWHEELDOWN", name = "WheelDown", label = "sWD", x = 6, sx = 7.25, row = 3,
		only = PLAIN, fixedMod = true }
	KEYBOARD[#KEYBOARD + 1] = { name = "Blank1", label = "", x = 5, sx = 6.25, row = 3, only = SHIFT_CTRL }
	KEYBOARD[#KEYBOARD + 1] = { name = "Blank2", label = "", x = 6, sx = 7.25, row = 3, only = SHIFT_CTRL }
	-- Caps: two buttons wide, ending where A starts (his ask, Nov 10). On his Linux PC Caps types \ (a custom KDE keyboard
	-- option), so the game sees \, not CAPSLOCK: the button is that key (his ask, Nov 10).
	KEYBOARD[#KEYBOARD + 1] = { key = "\\", name = "Caps", label = "Caps", x = -1, sx = -0.25, row = 2, wide = 2 }
end
-- The Naga Pro in his `wow` profile (notebook Keyboard or keypad): the side grid, 3 by 4, sends F1, F2, F3, Page Down, F5 to
-- F10, -, =; the two buttons left of left click (the edge buttons, Numpad * and /) stand in a column left of the grid, E1 on
-- top (his layout, Nov 10, kept: "E1 and E2 should stay vertical"); above side 2, full size, the wheel click, as on the
-- mouse. Shift and Ctrl + wheel click are on the Shift and Ctrl copies, where they belong (his ask, Nov 10, after a night
-- with them beside it on the plain bar).
local function sideGrid(keys, labels)
	local spots = {}
	for i, k in ipairs(keys) do
		local x, row = (i - 1) % 3, 1 + math.floor((i - 1) / 3)
		spots[#spots + 1] = { key = k, name = "Side" .. i, label = labels and labels[i] or tostring(i), x = x, sx = x, row = row }
	end
	return spots
end
-- E1, E2 and the wheel click around a side grid. (E1 and E2 are a little smaller than the grid, like on the mouse, and sit
-- tight against it, one gap away: his picks, Nov 10.) keys = nil: blank buttons.
local function aroundGrid(spots, e1, e2, m)
	spots[#spots + 1] = { key = e1, name = "Edge1", label = "E1", x = -1, sx = -1, row = 1, small = 0.75, alignX = "right" }
	spots[#spots + 1] = { key = e2, name = "Edge2", label = "E2", x = -1, sx = -1, row = 2, small = 0.75, alignX = "right" }
	spots[#spots + 1] = { key = m, name = "Wheel", label = "M", x = 1, sx = 1, row = 0 }
	return spots
end
local MOUSE = aroundGrid(sideGrid({ "F1", "F2", "F3", "PAGEDOWN", "F5", "F6", "F7", "F8", "F9", "F10", "-", "=" }),
	"NUMPADMULTIPLY", "NUMPADDIVIDE", "BUTTON3")
-- Hypershift + side button: the Naga sends Numpad 1 to 9, 0, -, + (your items, on the game's Action Bar 8). Labelled like
-- the side buttons, h in front when the labels show their modifier. Hypershift + E1, E2 and the wheel click send keys of
-- their own that nobody wrote down (Synapse has the edges set), so those three are blank: hover one in Edit keys and press
-- the real thing (his ask, Nov 10: "hyper shift should have different buttons for e1 and e2").
local HYPER = aroundGrid(sideGrid({ "NUMPAD1", "NUMPAD2", "NUMPAD3", "NUMPAD4", "NUMPAD5", "NUMPAD6", "NUMPAD7", "NUMPAD8",
	"NUMPAD9", "NUMPAD0", "NUMPADMINUS", "NUMPADPLUS" }))
-- home: the game bar its blank and free buttons follow in QuietHUD when none of its buttons show a game bar's slot.
local SETS = {
	{ id = "", name = "Keyboard", spots = KEYBOARD, staggers = true, arrows = true },
	{ id = "Mouse", name = "Mouse", spots = MOUSE },
	{ id = "MouseHyper", name = "Hypershift", spots = HYPER, plainOnly = true, home = 8, short = "h" },
}
-- The bars that show by default: the plain ones and Hypershift; the Shift, Ctrl and Alt copies are there to switch on.
local DEFAULT_ON = { Plain = true, MousePlain = true, MouseHyper = true }

-- The game's eight bars: the key command of their buttons, the page their slots are on (slot = (page - 1) * 12 + button),
-- their frame. Action Bar 1 pages (Rogue Stealth, vehicles), so a button showing one of its slots pages with it.
local BARS = {
	{ cmd = "ACTIONBUTTON", page = 1, frames = { "MainActionBar", "MainMenuBar" }, paged = true },
	{ cmd = "MULTIACTIONBAR1BUTTON", page = 6, frames = { "MultiBarBottomLeft" } },
	{ cmd = "MULTIACTIONBAR2BUTTON", page = 5, frames = { "MultiBarBottomRight" } },
	{ cmd = "MULTIACTIONBAR3BUTTON", page = 3, frames = { "MultiBarRight" } },
	{ cmd = "MULTIACTIONBAR4BUTTON", page = 4, frames = { "MultiBarLeft" } },
	{ cmd = "MULTIACTIONBAR5BUTTON", page = 13, frames = { "MultiBar5" } },
	{ cmd = "MULTIACTIONBAR6BUTTON", page = 14, frames = { "MultiBar6" } },
	{ cmd = "MULTIACTIONBAR7BUTTON", page = 15, frames = { "MultiBar7" } },
}
local BAR_BY_FRAME = {}
for i, bar in ipairs(BARS) do
	for _, n in ipairs(bar.frames) do BAR_BY_FRAME[n] = i end
end
-- Spare slots for free keys: Action Bar 1's second page (no page key is bound), then the stance pages no form of a Warlock,
-- Hunter, Paladin or Mage uses: 73 to 84 (Rogue Stealth, so not for Rogues) and 85 to 120. 121 and up are possess and
-- vehicle pages. Druids, Warriors and Priests (forms, stances, Shadowform) get page 2 only.
local function sparePool()
	local pool = {}
	for s = 13, 24 do pool[#pool + 1] = s end
	local _, class = UnitClass("player")
	if class ~= "DRUID" and class ~= "WARRIOR" and class ~= "PRIEST" then
		if class ~= "ROGUE" then
			for s = 73, 84 do pool[#pool + 1] = s end
		end
		for s = 85, 120 do pool[#pool + 1] = s end
	end
	return pool
end

local buttons, byCmd, wbBars = {}, {}, {}
local pending, applying, editing, moving, signature = false, false, false, false, nil

-- One frame holds every bar, as big as the screen, never takes the mouse (QuietHUD fades the holders inside the bars).
local container = CreateFrame("Frame", "WackyBars", UIParent)
container:SetAllPoints(UIParent)
container:EnableMouse(false)
local bindOwner = CreateFrame("Frame")
local noop = CreateFrame("Button", "WackyBarsNone", UIParent) -- a key you cleared is bound here: it does nothing
noop:Hide()
local hider = CreateFrame("Frame")
hider:Hide()
-- The buttons' secure header (they need one), and the pager of the buttons that show Action Bar 1's slots: Bartender's way
-- (its StateBar.lua). A vehicle, override, possess or temporary shapeshift bar first, then a page you picked (bar 2 to 6),
-- then a stance or stealth bar (only on page 1, as the game does), else page 1. Each paged button holds all the pages
-- (state n = page n) and is told the new one here.
local pager = CreateFrame("Frame", "WackyBarsPager", UIParent, "SecureHandlerStateTemplate")
pager:SetAttribute("_onstate-page", [[
	if newstate == "possess" then
		if HasVehicleActionBar() then
			newstate = GetVehicleBarIndex()
		elseif HasOverrideActionBar() then
			newstate = GetOverrideBarIndex()
		elseif HasTempShapeshiftActionBar() then
			newstate = GetTempShapeshiftBarIndex()
		elseif HasBonusActionBar() then
			newstate = GetBonusBarIndex()
		else
			newstate = 1
		end
	end
	newstate = tostring(newstate)
	self:SetAttribute("state", newstate)
	for i = 1, self:GetAttribute("count") or 0 do
		local b = self:GetFrameRef("b" .. i)
		if b then
			b:RunAttribute("UpdateState", newstate)
			b:CallMethod("UpdateAction")
		end
	end
]])
local PAGES = 18 -- (states 1 to 18: the six bar pages, the stance pages 7 to 10, possess 11, vehicle and override)

local ARROW_TURN = { up = -math.pi / 2, down = math.pi / 2, left = 0, right = math.pi }
-- The movement commands and the arrow each gets.
local MOVES = { MOVEFORWARD = "up", MOVEBACKWARD = "down", STRAFELEFT = "left", TURNLEFT = "left", STRAFERIGHT = "right",
	TURNRIGHT = "right" }
local hasArrowAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("NPE_ArrowLeft") and true or false
local function pointArrow(t, dir)
	if hasArrowAtlas then
		t:SetAtlas("NPE_ArrowLeft")
		t:SetRotation(ARROW_TURN[dir] or 0)
	else
		t:SetTexture("Interface\\Buttons\\JumpUpArrow")
		t:SetRotation((ARROW_TURN[dir] or 0) + math.pi / 2)
	end
	t:SetDesaturated(true)
end
for si, set in ipairs(SETS) do
	for li, L in ipairs(set.plainOnly and { LAYERS[1] } or LAYERS) do
		local bar = { id = set.id .. (set.plainOnly and "" or L.id), name = set.name .. (L.mod == "" and "" or (" " .. L.id)), set = set,
			layerIndex = li, short = set.short or L.short, arrows = {}, buttons = {},
			-- (the Alt mouse bar goes with the plain mouse bar: his pick, Nov 10)
			follow = (L.id == "Alt" and set.id == "Mouse") and "MousePlain" or L.follow }
		local f = CreateFrame("Frame", "WackyBars" .. bar.id, container)
		f:SetMovable(true)
		f:SetClampedToScreen(true)
		bar.frame = f
		-- one holder per game bar (QuietHUD fades each with that bar's row: see sortForQuietHUD); no size, no mouse. Holder 9
		-- holds the game's pet buttons placed on this bar (QuietHUD's Pet bar row; placePets)
		bar.holders = {}
		for i = 1, 9 do
			local h = CreateFrame("Frame", "WackyBarsHold" .. bar.id .. i, f)
			h:SetPoint("TOPLEFT", f, "TOPLEFT")
			h:EnableMouse(false)
			h.qhudButtons = {}
			bar.holders[i] = h
		end
		-- the game's pet buttons sit in this, inside holder 9: shown only with a pet (placePets)
		bar.petFrame = CreateFrame("Frame", "WackyBarsPet" .. bar.id, bar.holders[9])
		bar.petFrame:SetPoint("TOPLEFT", f, "TOPLEFT")
		bar.petFrame:EnableMouse(false)
		wbBars[#wbBars + 1] = bar
		for _, S in ipairs(set.spots) do
			if not S.only or S.only[L.id] then
				local b = LAB:CreateButton(#buttons + 1, "WackyBars" .. bar.id .. S.name, pager, BUTTON_CONFIG)
				b:SetParent(f)
				-- (Bartender's key binding mode, when Bartender is on too, would write saved key bindings through these:
				-- WackyBars never does; audit Nov 10)
				b.SetKey, b.ClearBindings = function() end, function() end
				-- (the game's own buttons honour self cast, focus cast and Mouseover Cast through these; the library sets none:
				-- without them a click or a WackyBars key ignored his Mouseover Cast; Codex audit Nov 10)
				b:SetAttribute("checkselfcast", true)
				b:SetAttribute("checkfocuscast", true)
				b:SetAttribute("checkmouseovercast", true)
				b.wb = { id = bar.id .. S.name, def = S.key and (L.mod .. S.key), mod = L.mod, spot = S, bar = bar }
				-- (a WackyBars key is an override binding QuietHUD's Tap Alt can't see: pressed with Alt held it flipped the
				-- whole HUD; the button says it was used; audit Nov 10)
				b:HookScript("PreClick", tapUsed)
				buttons[#buttons + 1] = b
				bar.buttons[#bar.buttons + 1] = b
				if set.arrows then
					local t = f:CreateTexture(nil, "ARTWORK")
					t:SetAlpha(0.3)
					t:Hide()
					b.wb.arrowTex = t
					bar.arrows[#bar.arrows + 1] = { tex = t, spot = S }
				end
			end
		end
	end
end

local function say(msg) print("|cff66bbffWackyBars|r: " .. msg) end
-- Runs the hooks a feature file added (ns.wb, end of this file): an error in one is reported, it doesn't stop the rest.
local function runHooks(list)
	for _, fn in ipairs(list or {}) do
		local ok, err = pcall(fn)
		if not ok then
			local h = geterrorhandler and geterrorhandler()
			if h then h(err) else error(err, 0) end
		end
	end
end
local function barOn(bar) return not (DB and DB.off[bar.id]) end
-- A button counts when its bar is on, you haven't hidden it (right-click in Edit keys) and it has a slot. One that does not
-- count shows nothing and sets no key.
local function hiddenButton(b) return DB and DB.hidden[b.wb.id] end
-- The edge buttons and the wheel click can go from every bar at once (two boxes in the options, for a mouse without them:
-- his ask, Nov 10, "someone should be able to turn off mmb and edge keys"). Gone: no key, no slot, the bar closes up.
local function spotGone(S)
	if not DB then return false end
	return (DB.noEdges and (S.name == "Edge1" or S.name == "Edge2")) or (DB.noWheel and S.name == "Wheel") or false
end
local function active(b)
	return (b.wb.slot ~= nil or b.wb.pet ~= nil) and barOn(b.wb.bar) and not hiddenButton(b) and not spotGone(b.wb.spot)
end

-- What a key does in your saved bindings: "mirror" (a game bar button: bar index, button number), "pet" (a pet bar key:
-- nil, the pet slot), "free" or "other".
local function parse(cmd)
	if not cmd or cmd == "" or cmd == "NONE" then return "free" end
	local pn = tonumber(cmd:match("^BONUSACTIONBUTTON(%d+)$"))
	if pn and pn >= 1 and pn <= 10 then return "pet", nil, pn end
	for i, bar in ipairs(BARS) do
		local n = tonumber(cmd:match("^" .. bar.cmd .. "(%d+)$"))
		if n and n >= 1 and n <= 12 then return "mirror", i, n end
	end
	return "other"
end

-- The key a button answers to now: the one you gave it in quick edit, none if you cleared it, else its own spot's key
-- (none for a spot whose key does something else, like a key bound to a non-bar command: that key is left alone).
local function effKey(b)
	if not active(b) then return nil end
	local e = DB.keys[b.wb.id]
	if e == false then return nil end
	if e then return e end
	if b.wb.kind == "other" then return nil end
	return b.wb.def -- (nil for a blank button: it has a key only once you give it one)
end

-- Reads your saved bindings: which slot each spot shows. Free spots (and spots whose key does something else) get a spare
-- slot, never one that already has something in it; one you fill stays that button's, kept for this character.
-- The binding signature: every spot's key and its bare key (a Shift or Ctrl key with nothing bound moves you if the bare
-- key does), so a change in Key Bindings is noticed.
local function bindSig()
	local sig = {}
	for _, b in ipairs(buttons) do
		if b.wb.def then
			sig[#sig + 1] = GetBindingAction(b.wb.def) or ""
			sig[#sig + 1] = GetBindingAction(b.wb.spot.key) or ""
		end
	end
	return table.concat(sig, ",")
end
-- Which way a key moves you, if it does: its own binding, or for Shift / Ctrl with nothing bound, the bare key's.
-- Movement keys: from Key Bindings (default), or WASD / ESDF picked in the options (his ask, Nov 10): then those four keys
-- show the arrows, and no other key does.
local FORCED_MOVES = {
	WASD = { W = "up", A = "left", S = "down", D = "right" },
	ESDF = { E = "up", S = "left", D = "down", F = "right" },
}
local function moveDir(q)
	if not q.def then return nil end
	local forced = DB and DB.moveKeys and FORCED_MOVES[DB.moveKeys]
	if forced then return forced[q.spot.key] end
	local c = GetBindingAction(q.def) or ""
	-- (a key set to NONE in Key Bindings does nothing, so it does not fall back to the bare key)
	-- (a modifier key bound to something that is not a bar button, like Ctrl + S's Toggle Sound, shows the bare key's arrow:
	-- his ask, Nov 10)
	if q.mod ~= "" and (c == "" or (c ~= "NONE" and parse(c) == "other" and not MOVES[c])) then
		c = GetBindingAction(q.spot.key) or ""
	end
	return MOVES[c]
end
local function port()
	wipe(byCmd)
	for _, b in ipairs(buttons) do
		local q = b.wb
		local cmd = q.def and GetBindingAction(q.def) or ""
		local kind, gi, n = parse(cmd)
		q.kind, q.game, q.n, q.cmd, q.other, q.move, q.pet = kind, gi, n, nil, nil, nil, nil
		local dir = q.arrowTex and moveDir(q)
		if dir then
			q.kind, q.move, q.slot = "move", dir, nil
		elseif kind == "pet" then
			-- (a pet key: the game's own pet button for that slot sits here, placePets)
			q.slot, q.pet, q.cmd = nil, n, cmd
		elseif kind == "mirror" then
			q.slot, q.cmd = (BARS[gi].page - 1) * 12 + n, cmd
			byCmd[cmd] = byCmd[cmd] or {}
			table.insert(byCmd[cmd], b)
		else
			q.slot = DB.spare[q.id]
			if kind == "other" then q.other = cmd end
		end
	end
	signature = bindSig()
	-- A spare slot stays with its button once you put something in it; empty ones are handed out again, in order, so there
	-- are enough to go round.
	for id, slot in pairs(DB.spare) do
		if not HasAction(slot) then DB.spare[id] = nil end
	end
	for _, b in ipairs(buttons) do
		local q = b.wb
		-- (a key that moves you never gets its old spare back: it would click the button instead of moving; audit Nov 10)
		if q.kind ~= "mirror" and q.kind ~= "move" and q.kind ~= "pet" then q.slot = DB.spare[q.id] end
	end
	local taken = {}
	for _, s in pairs(DB.spare) do taken[s] = true end
	-- (plain bars first, then the Shift, Ctrl and Alt copies: if they run out, a copy goes without)
	local pool, p = sparePool(), 1
	for li = 1, #LAYERS do
		for _, b in ipairs(buttons) do
			local q = b.wb
			if q.bar.layerIndex == li and q.kind ~= "mirror" and q.kind ~= "move" and q.kind ~= "pet" and not q.slot and barOn(q.bar)
				and not hiddenButton(b) and not spotGone(q.spot) then
				while pool[p] and (taken[pool[p]] or HasAction(pool[p])) do p = p + 1 end
				if pool[p] then
					q.slot, DB.spare[q.id], taken[pool[p]] = pool[p], pool[p], true
				end
			end
		end
	end
end

-- A button's own label: the key, with s / c / a / h in front on a modifier bar when the labels show their modifier.
local function label(b)
	local S, bar = b.wb.spot, b.wb.bar
	if DB and DB.mods and not S.fixedMod and bar.short ~= "" then return bar.short .. S.label end
	return S.label
end
local function hotkeyText(b)
	local k = effKey(b)
	if not k then return nil end
	return k == b.wb.def and label(b) or GetBindingText(k, 1)
end
local function hotkey(b)
	local hk = b.HotKey
	if not hk then return end
	local t = hotkeyText(b)
	if not t or t == "" then
		hk:SetText(RANGE_INDICATOR)
		hk:Hide()
		return
	end
	hk:SetText(t)
	hk:Show()
end
-- (the library asks each button for its hotkey text when bindings change: it gets WackyBars' label)
for _, b in ipairs(buttons) do b.GetHotkey = hotkeyText end

-- The button art, laid out as the game lays out Action Bar 1's buttons with its bar art on (ActionButtonTemplate.xml in
-- Blizzard_ActionBar and the bar branch of its UpdateButtonArt): the 46 x 45 frame and its pressed look pinned at the
-- button's top left over the 45 icon, the icon mask centred on the icon at its own size, the highlight and checked glow
-- 46 x 45 at the top left, the flash, border and spell glows at their own size at the top left, the cooldown 3 in from the
-- icon's edges. Every size is scaled by the button against the game's 45, so a wide key, a small spot and a bigger bar keep
-- the proportions. Every other game bar (Action Bars 2 to 8, Action Bar 1 with Hide Bar Art, the library's buttons) has
-- the other frame, "AddRow": 51 x 51 with a drop shadow hanging 6 past the right and bottom, which read as a box behind
-- each button (his "get rid of the weird phantom bar behind it", Nov 10); squeezed onto the icon, with the mask stretched
-- onto it, it also cropped the icons ("the icons are all cropped"). Action Bar 1 gives only its colour (colourOne, below).
-- The library puts the AddRow frame back on every update; its OnButtonUpdate callback (below) puts this back.
local FRAME_ATLAS, PUSHED_ATLAS = "UI-HUD-ActionBar-IconFrame", "UI-HUD-ActionBar-IconFrame-Down"
-- A button's part: the frame textures through their getters (as the game's own code reaches them), the rest by key.
local function part(b, key)
	local get = b["Get" .. key]
	local t = type(get) == "function" and get(b) or nil
	if type(t) ~= "table" then t = b[key] end
	return (type(t) == "table" and t.SetPoint) and t or nil
end
-- A part the template sizes by its atlas: that size on a 45 button, read once from a WackyBars button as the template made
-- it (else the atlas's), the same for every button. The game's pet buttons (30, sized by their own template) only read it.
-- Unknown: the part is left as the template made it.
local NATURAL = {}
local function naturalSize(key, t)
	local n = NATURAL[key]
	if not n and t then
		local w, h = t:GetSize()
		if not (type(w) == "number" and w > 0 and type(h) == "number" and h > 0) then
			local atlas = t.GetAtlas and t:GetAtlas()
			local info = type(atlas) == "string" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
			if type(info) == "table" then w, h = info.width, info.height end
		end
		if type(w) == "number" and w > 0 and type(h) == "number" and h > 0 then
			n = { w, h }
			NATURAL[key] = n
		end
	end
	if n then return n[1], n[2] end
end
-- { key, place }: "frame" = 46 x 45 at the top left (the frame, pressed, highlight, checked); "own" = its own size at the
-- top left (flash, border, new action and spell glows); "mask" = its own size, centred on the icon.
local ART = {
	{ "NormalTexture", "frame" }, { "PushedTexture", "frame" }, { "HighlightTexture", "frame" }, { "CheckedTexture", "frame" },
	{ "Flash", "own" }, { "Border", "own" }, { "NewActionTexture", "own" }, { "SpellHighlightTexture", "own" },
	{ "IconMask", "mask" },
}
-- (what the library resets on each update: the frame, the two glows' size, the slot background and the swipe; it never
-- touches the rest, so after its update only these go back on)
local LIBRARY_RESETS = { NormalTexture = true, HighlightTexture = true, CheckedTexture = true }
-- The cooldowns, so far in from the icon's edges (the template's): the swipe, loss of control, charges.
local COOLDOWNS = { { "cooldown", 3 }, { "lossOfControlCooldown", 3 }, { "chargeCooldown", 2 } }
local LAYERED, LAYERED_LIGHT = { "NormalTexture", "PushedTexture" }, { "NormalTexture" }
-- b: a WackyBars button, or the game's pet button in a spot (b.wbPetArt: laid out for its own size, 30). light: only what
-- the library resets (after its update).
local function art(b, light)
	local w, h
	if b.wbSize then w, h = b.wbSize[1], b.wbSize[2] else w, h = b:GetWidth(), b:GetHeight() end
	if not (type(w) == "number" and w > 0 and type(h) == "number" and h > 0) then return end
	local kx, ky = w / 45, h / 45
	local own = not b.wbPetArt
	-- (the parts sized by their atlas are read before anything here moves them)
	if own then
		for _, p in ipairs(ART) do
			local t = p[2] ~= "frame" and part(b, p[1])
			if t then naturalSize(p[1], t) end
		end
	end
	if b.SetNormalAtlas then b:SetNormalAtlas(FRAME_ATLAS) end
	if not light and b.SetPushedAtlas then b:SetPushedAtlas(PUSHED_ATLAS) end
	for _, p in ipairs(ART) do
		local key, place = p[1], p[2]
		local t = (not light or LIBRARY_RESETS[key]) and part(b, key)
		local tw, th
		if t and place == "frame" then
			tw, th = 46 * kx, 45 * ky
		elseif t then
			local nw, nh = naturalSize(key, own and t or nil)
			if nw then tw, th = nw * kx, nh * ky end
		end
		if tw then
			t:ClearAllPoints()
			if place == "mask" then
				t:SetPoint("CENTER", type(b.icon) == "table" and b.icon or b, "CENTER", 0, 0)
			else
				t:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
			end
			t:SetSize(tw, th)
		end
	end
	for _, key in ipairs(light and LAYERED_LIGHT or LAYERED) do
		local t = part(b, key)
		if t and t.SetDrawLayer then t:SetDrawLayer("OVERLAY") end
	end
	-- under the icon: a plain dark slot (as on the game's other bars), or with Bar art ticked in /wbars the faint wing of
	-- Action Bar 1 with its bar art (his "any way to turn the bar art off in wbars?", Nov 10)
	local slot, back = part(b, "SlotArt"), part(b, "SlotBackground")
	local barArt = DB and DB.barArt and true or false
	if slot then slot:SetShown(barArt) end
	if back then back:SetShown(not barArt) end
	-- (the cooldowns: the library moves the swipe on each update; loss of control and charges scale for a wide key or a
	-- smaller spot too, audit Nov 10)
	local icon = b.icon
	if type(icon) == "table" then
		for i, c in ipairs(COOLDOWNS) do
			local cd = (i == 1 or not light) and b[c[1]]
			if type(cd) == "table" and cd.SetPoint then
				cd:ClearAllPoints()
				cd:SetPoint("TOPLEFT", icon, "TOPLEFT", c[2] * kx, -c[2] * ky)
				cd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -c[2] * kx, c[2] * ky)
			end
		end
	end
end
-- The colour, from your own Action Bar 1 buttons (BetterBlizzFrames' Dark Mode tint, or the game's own).
local function copyColour(dst, src)
	if not (dst and src) then return end
	if dst.SetDesaturated and src.IsDesaturated then dst:SetDesaturated(src:IsDesaturated()) end
	if dst.SetVertexColor and src.GetVertexColor then dst:SetVertexColor(src:GetVertexColor()) end
end
-- The game's pet button as the game had it, put back when it leaves its spot: its frame, glows, slots, cooldowns and colour
-- (audit Nov 10: it kept WackyBars' colour until a reload). Taken once, before WackyBars changes anything on it.
local SNAP_PARTS = { "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "Flash", "Border",
	"NewActionTexture", "SpellHighlightTexture", "IconMask", "SlotArt", "SlotBackground" }
local SNAP_SHOWN = { SlotArt = true, SlotBackground = true } -- (the game shows and hides the others itself)
local function pointsOf(r)
	local out = {}
	for i = 1, (r.GetNumPoints and r:GetNumPoints() or 0) do
		local a, rel, c, x, y = r:GetPoint(i)
		out[i] = { a, rel, c, x, y }
	end
	return out
end
local function setPoints(r, list)
	if #list == 0 then return end
	r:ClearAllPoints()
	for _, p in ipairs(list) do r:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
end
local function snapArt(pb)
	if pb.wbSnap then return end
	local s = { parts = {}, cds = {} }
	local nt, pt = part(pb, "NormalTexture"), part(pb, "PushedTexture")
	s.normal = nt and nt.GetAtlas and nt:GetAtlas()
	s.pushed = pt and pt.GetAtlas and pt:GetAtlas()
	for _, key in ipairs(SNAP_PARTS) do
		local t = part(pb, key)
		if t then
			local o = { points = pointsOf(t) }
			o.w, o.h = t:GetSize()
			if t.IsShown then o.shown = t:IsShown() and true or false end
			if t.GetVertexColor then o.vc = { t:GetVertexColor() } end
			if t.IsDesaturated then o.desat = t:IsDesaturated() and true or false end
			if t.GetDrawLayer then o.layer, o.sub = t:GetDrawLayer() end
			s.parts[key] = o
		end
	end
	for _, c in ipairs(COOLDOWNS) do
		local cd = pb[c[1]]
		if type(cd) == "table" and cd.GetPoint then s.cds[c[1]] = pointsOf(cd) end
	end
	pb.wbSnap = s
end
local function restoreArt(pb)
	local s = pb.wbSnap
	if not s then return end
	if type(s.normal) == "string" and pb.SetNormalAtlas then pb:SetNormalAtlas(s.normal) end
	if type(s.pushed) == "string" and pb.SetPushedAtlas then pb:SetPushedAtlas(s.pushed) end
	for key, o in pairs(s.parts) do
		local t = part(pb, key)
		if t then
			setPoints(t, o.points)
			if type(o.w) == "number" and o.w > 0 and type(o.h) == "number" and o.h > 0 then t:SetSize(o.w, o.h) end
			if SNAP_SHOWN[key] and o.shown ~= nil then t:SetShown(o.shown) end
			if o.vc and t.SetVertexColor then t:SetVertexColor(o.vc[1], o.vc[2], o.vc[3], o.vc[4]) end
			if o.desat ~= nil and t.SetDesaturated then t:SetDesaturated(o.desat) end
			if type(o.layer) == "string" and t.SetDrawLayer then t:SetDrawLayer(o.layer, o.sub) end
		end
	end
	for key, list in pairs(s.cds) do
		local cd = pb[key]
		if type(cd) == "table" and cd.SetPoint then setPoints(cd, list) end
	end
end
-- The look (his ask, Nov 10: "follow the theme of my desktop and the focus window bar thats like purple to pink gradient",
-- "default and the thing i suggested"): Default copies your Action Bar 1 (BetterBlizzFrames' Dark Mode tint with it, as
-- before); Purple to pink colours each button's frame (and its empty slot's wing with Bar art) with a slice of one gradient across its bar,
-- #BD93F9 to #FF79C6 (his desktop's, the same as his mouse pointer). Set at each look update, no timer.
local GRAD_FROM, GRAD_TO = { 0xBD / 255, 0x93 / 255, 0xF9 / 255 }, { 0xFF / 255, 0x79 / 255, 0xC6 / 255 }
local function mix(t) return GRAD_FROM[1] + (GRAD_TO[1] - GRAD_FROM[1]) * t, GRAD_FROM[2] + (GRAD_TO[2] - GRAD_FROM[2]) * t,
	GRAD_FROM[3] + (GRAD_TO[3] - GRAD_FROM[3]) * t end
-- Where a button sits across its bar, 0 (left edge) to 1 (right edge), for its left and right side.
local function span(b, bar)
	local bl, bw = b:GetLeft(), b:GetWidth()
	local fl, fw = bar.frame:GetLeft(), bar.frame:GetWidth()
	if not (bl and bw and fl and fw) or fw <= 0 then return 0, 1 end
	local t0, t1 = (bl - fl) / fw, (bl + bw - fl) / fw
	return math.max(0, math.min(1, t0)), math.max(0, math.min(1, t1))
end
local function gradOn(t, bar, b)
	if type(t) ~= "table" or not (t.SetGradient and CreateColor) then return end
	local t0, t1 = span(b, bar)
	local r0, g0, b0 = mix(t0)
	local r1, g1, b1 = mix(t1)
	t:SetDesaturated(true) -- (the frame's own grey, so the colour reads true)
	t:SetGradient("HORIZONTAL", CreateColor(r0, g0, b0, 1), CreateColor(r1, g1, b1, 1))
end
-- b: a WackyBars button or a game pet button in a spot: its spot's bar, and its spot's slice (the pet button is scaled
-- into its spot, so its own left and width are in other units; audit Nov 10).
tint = function(b, bar)
	if not (DB and DB.look == "gradient") then return end
	bar = bar or (b.wb and b.wb.bar) or (b.wbSpot and b.wbSpot.wb.bar)
	if not bar then return end
	local at = b.wbSpot or b
	gradOn(part(b, "NormalTexture"), bar, at)
	gradOn(part(b, "PushedTexture"), bar, at) -- (the pressed frame too: each press flashed the plain one; audit Nov 10)
	gradOn(part(b, "SlotArt"), bar, at)
end
-- A button's colour: Action Bar 1's on the frame, the pressed look and both slots; Purple to pink (tint) goes on top.
local function colourOne(b, ref)
	copyColour(part(b, "NormalTexture"), part(ref, "NormalTexture"))
	copyColour(part(b, "PushedTexture"), part(ref, "PushedTexture"))
	copyColour(part(b, "SlotArt"), part(ref, "SlotArt"))
	copyColour(part(b, "SlotBackground"), part(ref, "SlotBackground"))
	tint(b)
end
-- The minimap's frame follows the look too (his ask, Nov 10: "any way we can match the look on the mini map to?"): the
-- ring (MinimapCompassTexture), BetterBlizzFrames' classic border and its day / night ring, #BD93F9 on the left to #FF79C6
-- on the right. BetterBlizzFrames' Dark Mode writes their colour again now and then: a hook on each (only once Purple to
-- pink was picked) puts the gradient back on top and keeps what was written, so Default puts exactly that back.
local mapBusy = false
local function mapTextures()
	local out = {}
	local function add(t) if type(t) == "table" and t.SetGradient and t.GetVertexColor then out[#out + 1] = t end end
	add(_G.MinimapCompassTexture)
	local B = _G.BBF
	if type(B) == "table" then
		if type(B.classicMinimapTextures) == "table" then
			for _, t in ipairs(B.classicMinimapTextures) do add(t) end
		end
		add(B.dielCycleBorder)
	end
	return out
end
-- (each part gets its slice of one gradient across the whole map, left to right, so the pieces of a border join up; audit
-- Nov 10. A part whose place is not known yet gets the whole gradient.)
local function mapSlices(list)
	local lo, hi, at = math.huge, -math.huge, {}
	for _, t in ipairs(list) do
		local l, r = t.GetLeft and t:GetLeft(), t.GetRight and t:GetRight()
		local p = t.GetParent and t:GetParent()
		local s = p and p.GetEffectiveScale and p:GetEffectiveScale()
		if type(l) == "number" and type(r) == "number" and type(s) == "number" and s > 0 and r > l then
			at[t] = { l * s, r * s }
			lo, hi = math.min(lo, l * s), math.max(hi, r * s)
		end
	end
	for _, t in ipairs(list) do
		local a = at[t]
		t.wbSlice = (a and hi > lo) and { (a[1] - lo) / (hi - lo), (a[2] - lo) / (hi - lo) } or nil
	end
end
local function mapOne(t)
	mapBusy = true
	if DB and DB.look == "gradient" then
		local sl = t.wbSlice
		local r0, g0, b0 = mix(sl and sl[1] or 0)
		local r1, g1, b1 = mix(sl and sl[2] or 1)
		t:SetDesaturated(true)
		t:SetGradient("HORIZONTAL", CreateColor(r0, g0, b0, 1), CreateColor(r1, g1, b1, 1))
		t.wbGrad = true
	elseif t.wbGrad then
		t.wbGrad = nil
		local o = t.wbOrig
		t:SetVertexColor(o[1], o[2], o[3])
		t:SetDesaturated(o[4])
	end
	mapBusy = false
end
local function mapLook()
	if not CreateColor then return end
	local list = mapTextures()
	if DB and DB.look == "gradient" then mapSlices(list) end
	for _, t in ipairs(list) do
		if not t.wbOrig and DB and DB.look == "gradient" then
			local r, g, b = t:GetVertexColor()
			t.wbOrig = { r or 1, g or 1, b or 1, (t.IsDesaturated and t:IsDesaturated()) and true or false }
			hooksecurefunc(t, "SetVertexColor", function(self, r2, g2, b2)
				if mapBusy then return end
				self.wbOrig[1], self.wbOrig[2], self.wbOrig[3] = r2 or 1, g2 or 1, b2 or 1
				if DB.look == "gradient" then mapOne(self) end
			end)
			hooksecurefunc(t, "SetDesaturated", function(self, v)
				if mapBusy then return end
				self.wbOrig[4] = v and true or false
				if DB.look == "gradient" then mapOne(self) end
			end)
		end
		if t.wbOrig then mapOne(t) end
	end
end
local function matchLook()
	mapLook()
	local ref = _G.ActionButton1
	if not ref then return end
	-- (only the colour here: the art is laid out by layout and after each of the library's updates)
	for _, b in ipairs(buttons) do colourOne(b, ref) end
	-- the movement arrows (his ask, Nov 10: "gradient the arrows on the movement keys to"): their slice of the bar's
	-- gradient, still at their faint 0.3; Default puts them back to plain grey
	for _, bar in ipairs(wbBars) do
		for _, a in ipairs(bar.arrows) do
			local t = a.tex
			-- (their opacity: the Arrows button in the options, 30% unless picked; QuietHUD's fade multiplies on top)
			t:SetAlpha(DB and DB.arrowAlpha or 0.3)
			if DB and DB.look == "gradient" then
				gradOn(t, bar, t)
				t.wbGrad = true
			elseif t.wbGrad then
				t.wbGrad = nil
				t:SetVertexColor(1, 1, 1)
				t:SetDesaturated(true)
			end
		end
	end
	-- the game's pet buttons in WackyBars spots: Action Bar 1's colour like the buttons round them, the gradient on top
	for n = 1, 10 do
		local pb = _G["PetActionButton" .. n]
		if pb and pb.wbSpot then colourOne(pb, ref) end
	end
	runHooks(ns.wb and ns.wb.lookHooks) -- (the feature files' looks)
end
local lookQueued = false
local function queueLook()
	if lookQueued then return end
	lookQueued = true
	C_Timer.After(0, function() lookQueued = false matchLook() end)
end
local function hookLook()
	local ref = _G.ActionButton1
	if not ref or ref.wbHooked then return end
	ref.wbHooked = true
	for _, t in ipairs({ ref:GetNormalTexture(), ref.SlotArt }) do
		if t then
			hooksecurefunc(t, "SetVertexColor", queueLook)
			hooksecurefunc(t, "SetDesaturated", queueLook)
		end
	end
end

-- The size and spacing of your Action Bar 1 buttons as they show on screen (Edit Mode's Icon Size scales the buttons, not
-- the bar), in UIParent units; measured while that bar still shows, then kept. The scale setting multiplies on top.
local measured = { size = 45, gap = 4 }
local function measure()
	local ref, ref2 = _G.ActionButton1, _G.ActionButton2
	if not (ref and ref:IsVisible()) then return end
	local w, eff, base = ref:GetWidth(), ref:GetEffectiveScale(), UIParent:GetEffectiveScale()
	if not (w and w >= 20 and eff and eff > 0 and base and base > 0) then return end
	measured.size = w * eff / base
	if ref2 and ref:GetRight() and ref2:GetLeft() then
		local g = ref2:GetLeft() - ref:GetRight()
		if g >= 0 and g <= 16 then measured.gap = g * eff / base end
	end
end
-- A wide key: its icon is cropped to the wide shape (a middle band of it) rather than squashed; the art stretches with it
-- (art, above). Kept when the game sets a new icon.
local function cropIcon(b)
	local icon, w, h = b.icon, b:GetWidth(), b:GetHeight()
	if not (type(icon) == "table" and icon.SetTexCoord and w and h and h > 0 and w > h) then return end
	local band = h / w
	icon:SetTexCoord(0, 1, 0.5 - band / 2, 0.5 + band / 2)
end
local function shape(b, light)
	art(b, light)
	cropIcon(b)
	if type(b.icon) == "table" and not b.wbCropHooked then
		b.wbCropHooked = true
		hooksecurefunc(b.icon, "SetTexture", function() cropIcon(b) end)
	end
end
-- (after the library updates a button it has put its own lone-button frame back, shown or hidden its background and reset
-- the glow sizes and the swipe: those and Action Bar 1's colour go back on. Only shown buttons: the library updates all of
-- them at a loading screen or a vehicle, most on bars that are off; a button that comes on gets the library's update on
-- show, and layout lays out every button)
LAB.RegisterCallback(buttons, "OnButtonUpdate", function(_, b)
	if not (b and b.wb and b:IsShown()) then return end
	shape(b, true)
	local ref = _G.ActionButton1
	if ref then colourOne(b, ref) end
	-- (a hidden button, or a pet key's spot, shows faint while you edit keys; the library's update set it back to full)
	if editing and b.wb and DB and DB.hidden[b.wb.id] then b:SetAlpha(0.35) end
end)

local function spotX(bar, S) return (bar.set.staggers and DB.stagger) and S.sx or S.x end
-- A bar's size (1 = your Action Bar 1 buttons' size), each bar its own (his ask, Nov 10: "resize each bars indvidually"),
-- set in Move bars like Edit Mode's Icon Size.
local function sizeOf(bar) return DB and DB.sizes and DB.sizes[bar.id] or 1 end
-- Lays out each bar's buttons and puts the bar where you moved it, or, the first time, the keyboard bars side by side at
-- the bottom and the mouse bars in a row above them.
local function layout()
	measure()
	local size, gap = measured.size, measured.gap
	local u = size + gap
	local dims = {}
	for _, bar in ipairs(wbBars) do
		local minX, maxX, minRow, maxRow = math.huge, -math.huge, math.huge, 0
		for _, S in ipairs(bar.set.spots) do
			if not spotGone(S) and (not S.only or S.only[LAYERS[bar.layerIndex].id]) then
				minX = math.min(minX, spotX(bar, S))
				maxX = math.max(maxX, spotX(bar, S) + (S.wide or 1) - 1)
				minRow, maxRow = math.min(minRow, S.row), math.max(maxRow, S.row)
			end
		end
		local w, h = (maxX - minX) * u + size, (maxRow - minRow) * u + size
		bar.frame:SetSize(w, h)
		bar.frame:SetScale(sizeOf(bar))
		dims[bar] = { w = w, h = h, minX = minX, minRow = minRow }
		for _, a in ipairs(bar.arrows) do
			local S = a.spot
			a.tex:SetSize(size * 0.6, size * 0.6)
			a.tex:ClearAllPoints()
			a.tex:SetPoint("CENTER", bar.frame, "TOPLEFT", (spotX(bar, S) - minX) * u + size / 2, -(S.row - minRow) * u - size / 2)
		end
	end
	for _, b in ipairs(buttons) do
		local S, bar = b.wb.spot, b.wb.bar
		local span = S.wide or 1
		local bw = size * span + gap * (span - 1)
		local k = S.small or 1
		local w, h = bw * k, size * k
		b:SetSize(w, h)
		-- (every button, and again after each of the library's updates, which put its own frame and the 46 x 45 glow back:
		-- Caps' glow covered only its left half; audit Nov 10)
		b.wbSize = { w, h }
		shape(b)
		b:ClearAllPoints()
		local ox = S.alignX == "right" and (bw - w) or (bw - w) / 2
		local oy = (size - h) / 2
		b:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", (spotX(bar, S) - dims[bar].minX) * u + ox, -(S.row - dims[bar].minRow) * u - oy)
	end
	-- the first-time places: the plain keyboard, the plain mouse and Hypershift in a row at the bottom, centred; the Shift,
	-- Ctrl and Alt copies in the middle of the screen, keyboard ones left of the middle, mouse ones right, each a little
	-- down and right of the one before (stacked above their plain bar they were taller than the screen, so the game pushed
	-- the Alt mouse bar onto the Ctrl one and you could not grab it: his "you cant move the alt naga bars", Nov 10)
	local between, y = size * 0.75, 140
	local plain, total = {}, 0
	for _, bar in ipairs(wbBars) do
		if bar.layerIndex == 1 then
			plain[#plain + 1] = bar
			total = total + dims[bar].w * sizeOf(bar)
		end
	end
	total = total + between * (#plain - 1)
	local x = -total / 2
	for _, bar in ipairs(plain) do
		bar.defaultPoint = { "BOTTOMLEFT", "BOTTOM", x, y }
		x = x + dims[bar].w * sizeOf(bar) + between
	end
	local midY = UIParent:GetHeight() / 2
	for _, copy in ipairs(wbBars) do
		if copy.layerIndex > 1 then
			local w, h, step = dims[copy].w * sizeOf(copy), dims[copy].h * sizeOf(copy), (copy.layerIndex - 2) * 30
			local left = copy.set.staggers and (-w - 10) or 10
			copy.defaultPoint = { "BOTTOMLEFT", "BOTTOM", left + step, midY - h / 2 - step }
		end
	end
	for _, bar in ipairs(wbBars) do
		local p = DB.pos[bar.id]
		local f = bar.frame
		f:ClearAllPoints()
		if p then
			f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
		else
			local d, k = bar.defaultPoint, sizeOf(bar)
			f:SetPoint(d[1], UIParent, d[2], d[3] / k, d[4] / k)
		end
	end
end

-- The game's eight action bars are tucked away while any WackyBars bar shows (his ask, Nov 10: "flat out disable the
-- vanilla bars when wacky bars is on"). Tucked, not switched off: their keys keep working (the game presses a bar's buttons
-- without checking that they show), which keeps stealth and vehicle paging. The stance and possess bars stay the game's; the
-- pet bar is tucked only while its buttons sit in WackyBars spots (placePets).
-- Every WackyBars bar off, or WackyBars switched off in the AddOns list: they are all back.
local tucked = {}
local function gameBars()
	local any = false
	for _, bar in ipairs(wbBars) do
		if barOn(bar) then any = true break end
	end
	for i, bar in ipairs(BARS) do
		local frame
		for _, n in ipairs(bar.frames) do frame = frame or _G[n] end
		if frame then
			if any and not tucked[i] then
				tucked[i] = frame:GetParent()
				frame:SetParent(hider)
			elseif not any and tucked[i] then
				frame:SetParent(tucked[i])
				tucked[i] = nil
			end
		end
	end
end

-- A whole WackyBars bar into the holder of the game bar most of its buttons show slots of, so QuietHUD treats it like that
-- bar (its row on the Action bars page: Fade, Mouse over, Low health, Low mana, Hide hotkeys, Hide names; his ask, Nov 10).
-- One bar, one row: per button, a key bound to another game bar (Shift + wheel click) stayed shown while the rest of its
-- bar faded on mouse over (his "shifts mmb stays out when its bars is mouseover", Nov 10). No slot shown at all: its home
-- (Hypershift: Action Bar 8) or Action Bar 1. The Alt keyboard follows Action Bar 1, the Alt mouse the plain mouse bar.
-- Out of a fight only (apply).
local function sortForQuietHUD()
	local byId = {}
	for _, o in ipairs(wbBars) do byId[o.id] = o end
	for _, bar in ipairs(wbBars) do
		local count, main, best = {}, bar.set.home or 1, 0
		for _, b in ipairs(bar.buttons) do
			if b.wb.kind == "mirror" and b.wb.game then count[b.wb.game] = (count[b.wb.game] or 0) + 1 end
		end
		for i = 1, 8 do
			if (count[i] or 0) > best then main, best = i, count[i] end
		end
		if type(bar.follow) == "string" then
			main = byId[bar.follow] and byId[bar.follow].main or main
		else
			main = bar.follow or main
		end
		-- A bar with pet keys is your pet bar: all of it goes with QuietHUD's Pet bar row, its other buttons too (his ask, Nov 10:
		-- "just attach it to the fade in the petbar stuff")
		for _, b in ipairs(bar.buttons) do
			if b.wb.kind == "pet" and active(b) and not hiddenButton(b) then main = 9 break end
		end
		bar.main = main
		for i = 1, 9 do wipe(bar.holders[i].qhudButtons) end -- (the pet buttons join holder 9's in placePets)
		local h = bar.holders[main]
		for _, b in ipairs(bar.buttons) do
			if b:GetParent() ~= h then b:SetParent(h) end
			h.qhudButtons[#h.qhudButtons + 1] = b
		end
		-- (the arrows fade with the bar, but show at full while you edit or move, like the buttons: showFull)
		bar.arrowHome = bar.holders[main]
		for _, a in ipairs(bar.arrows) do a.tex:SetParent((editing or moving) and bar.frame or bar.arrowHome) end
	end
end

-- The pet bar (his ask, Nov 10: "make the wackybar petbar function like an actual petbar", with the extra buttons kept): a
-- spot whose key is a pet key in Key Bindings (Pet bar, BONUSACTIONBUTTON1 to 10) shows the game's own pet button for that
-- slot, so it changes with the pet you summon, autocast, cooldowns and all, exactly as on the game's pet bar. The other
-- spots of that bar stay action buttons. Dominos' way: the game's button is moved into the spot (out of a fight only) and
-- sized to it; WackyBars' own button there stays hidden and only marks the place. The buttons sit in the bar's petFrame,
-- which shows only while you have a pet (a state driver, so a fight can't stop it), inside holder 9, which QuietHUD fades
-- with its Pet bar row (the whole bar is in holder 9 then: sortForQuietHUD). The game's pet bar is tucked away while any of its buttons is in a spot, and every button goes back when none is.
-- Known gap: the tucked bar no longer turns a pet key's text red out of range.
local petMoved, petTucked = {}, nil
local PET_SHOW = "[petbattle][vehicleui][overridebar][possessbar] hide; [@pet,exists] show; hide"
local function petHotkey(pb)
	if not pb.wbHooked and pb.SetHotkeys then
		pb.wbHooked = true
		-- (the game writes the key text again on every binding change: WackyBars' label goes back on)
		hooksecurefunc(pb, "SetHotkeys", function(self) if self.wbSpot then petHotkey(self) end end)
	end
	local b, hk = pb.wbSpot, pb.HotKey
	if not (b and hk) then return end
	local t = hotkeyText(b)
	if t and t ~= "" then
		hk:SetText(t)
		hk:Show()
	else
		hk:Hide()
	end
end
local function placePets()
	local want = {}
	for _, b in ipairs(buttons) do
		local q = b.wb
		if q.kind == "pet" and active(b) and not hiddenButton(b) and not want[q.pet] then want[q.pet] = b end
	end
	local any, withPets = false, {}
	for n = 1, 10 do
		local pb, b = _G["PetActionButton" .. n], want[n]
		if pb and b then
			any = true
			withPets[b.wb.bar] = true
			snapArt(pb) -- (once, before anything here changes it)
			local h, pf = b.wb.bar.holders[9], b.wb.bar.petFrame
			if pb:GetParent() ~= pf then pb:SetParent(pf) end
			-- (above the spot's own empty slot, which shows when the pet has nothing in this slot)
			if pf:GetFrameLevel() <= b:GetFrameLevel() then pf:SetFrameLevel(b:GetFrameLevel() + 2) end
			pb.wbBase = pb.wbBase or pb:GetHeight()
			local bh = b:GetHeight()
			pb:SetScale((bh and bh > 0 and pb.wbBase and pb.wbBase > 0) and bh / pb.wbBase or 1)
			pb:ClearAllPoints()
			pb:SetPoint("CENTER", b, "CENTER", 0, 0)
			pb.wbSpot, pb.wbPetArt = b, true
			h.qhudButtons[#h.qhudButtons + 1] = pb
			petHotkey(pb)
			-- (the same frame as the buttons round it: the game's pet button has the shadowed lone-button one; art review Nov 10)
			art(pb)
			-- (at full while you edit keys or move bars, like the buttons round it: showFull)
			if pb.SetIgnoreParentAlpha then pb:SetIgnoreParentAlpha((editing or moving) and true or false) end
			local ref = _G.ActionButton1
			if ref then colourOne(pb, ref) else tint(pb) end
			petMoved[n] = true
		elseif pb and petMoved[n] then
			petMoved[n], pb.wbSpot, pb.wbPetArt = nil, nil, nil
			restoreArt(pb)
			if pb.SetIgnoreParentAlpha then pb:SetIgnoreParentAlpha(false) end
			pb:SetParent(pb.container or _G.PetActionBar or UIParent)
			pb:SetScale(1)
			pb:ClearAllPoints()
			pb:SetPoint("CENTER")
			if pb.SetHotkeys then pb:SetHotkeys() end
		end
	end
	-- Each bar's pet frame shows with a pet, only while it holds a pet button (a state driver costs a check every 0.2 s:
	-- nine of them ran on every character; audit Nov 10), and not on a vehicle, an override or possess bar or in a pet
	-- battle, where the game's own pet bar is gone too (Bartender's rule).
	for _, bar in ipairs(wbBars) do
		local pf = bar.petFrame
		if withPets[bar] and pf.wbDriven ~= PET_SHOW then
			pf.wbDriven = PET_SHOW
			RegisterStateDriver(pf, "visibility", PET_SHOW)
		elseif not withPets[bar] and pf.wbDriven then
			pf.wbDriven = nil
			UnregisterStateDriver(pf, "visibility")
			pf:Hide()
		end
	end
	local bar = _G.PetActionBar
	if bar then
		if any and not petTucked then
			petTucked = bar:GetParent()
			bar:SetParent(hider)
		elseif not any and petTucked then
			bar:SetParent(petTucked)
			petTucked = nil
		end
	end
end

local refreshOptions -- (the options window, below)
local refreshMovers -- (Move bars, below: a bar switched on while it is open gets its box)
local sizeBar -- (Move bars, below)
-- Puts everything in place: which bars show, the slot of each button, the override keys, the labels, the game bars. Out of
-- a fight only.
local function apply()
	if not DB then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending, applying = false, true
	-- Which bars show (fading, mouse over and fights are QuietHUD's).
	for _, bar in ipairs(wbBars) do
		bar.frame:SetShown(barOn(bar))
	end
	-- The slots: a button showing one of Action Bar 1's holds every page (state n = page n) and the pager tells it the page;
	-- any other holds its one slot in state 0. Dragging follows the game's Lock Action Bars setting.
	local paged = {}
	local page = tostring(pager:GetAttribute("state") or "1")
	local locked = true
	if Settings and Settings.GetValue then
		local ok, v = pcall(Settings.GetValue, "lockActionBars")
		if ok and v ~= nil then locked = v and true or false end
	end
	for _, b in ipairs(buttons) do
		local q = b.wb
		b:SetAttribute("buttonlock", locked)
		-- a hidden button shows, faint, only while you edit keys (so you can right-click it back)
		-- a button that shows nothing (its bar off, hidden, no slot, a key that moves you) is emptied too, so the library leaves
		-- it out of its cooldown, usable and range passes (about 170 buttons, most on bars that are off; audit Nov 10)
		-- (a hidden button with no slot still shows, faint and empty, while you edit keys, so you can right-click it back)
		local hiddenEmpty = editing and hiddenButton(b) and not q.slot and barOn(q.bar) and not spotGone(q.spot)
		-- A pet key's spot keeps an empty slot of its own under the game's pet button: the game hides its pet button when
		-- that slot of the pet bar is empty (or no pet is out), and the spot went blank (his "9 disappeared from my wbars
		-- petbar", Nov 10 night: his pet has nothing in slot 9). It is also how Edit keys reaches the spot (audit Nov 10).
		local petMark = q.kind == "pet" and not hiddenButton(b) and barOn(q.bar) and not spotGone(q.spot)
		if hiddenEmpty or petMark then
			b:Show()
			b:SetAlpha(hiddenEmpty and 0.35 or 1)
			if tostring(b:GetAttribute("state")) ~= "0" then b:SetAttribute("state", "0") end
			b:SetState("0", "empty")
		elseif not q.slot or (hiddenButton(b) and not editing) or spotGone(q.spot) or not barOn(q.bar) then
			b:Hide()
			-- (state 0 and empty, through the library, so a paged button switched off drops its old slot too; Codex audit)
			if tostring(b:GetAttribute("state")) ~= "0" or b:GetAction("0") ~= "empty" then
				b:SetAttribute("state", "0")
				b:SetState("0", "empty")
			end
		else
			b:Show()
			b:SetAlpha(hiddenButton(b) and 0.35 or 1)
			if q.kind == "mirror" and BARS[q.game].paged then
				for p = 1, PAGES do
					local slot = (p - 1) * 12 + q.n
					b:SetStateFromHandlerInsecure(p, "action", slot)
					b:SetAttribute("labtype-" .. p, "action")
					b:SetAttribute("labaction-" .. p, slot)
				end
				b:SetAttribute("state", page)
				b:UpdateState(page)
				paged[#paged + 1] = b
			else
				if tostring(b:GetAttribute("state")) ~= "0" then b:SetAttribute("state", "0") end
				b:SetState("0", "action", q.slot)
			end
		end
	end
	for i, b in ipairs(paged) do pager:SetFrameRef("b" .. i, b) end
	pager:SetAttribute("count", #paged)

	-- The keys. A key you moved off a game bar button stops doing it (it is bound to nothing); a key you gave a button does
	-- that button's job (through the game's own command when it shows a game bar slot, so paging still works). A bar that is
	-- off sets no keys: its keys do what the game says.
	ClearOverrideBindings(bindOwner)
	local map = {}
	for _, b in ipairs(buttons) do
		local q = b.wb
		if active(b) and (q.kind == "mirror" or q.kind == "pet") and effKey(b) ~= q.def then map[q.def] = "none" end
	end
	for _, b in ipairs(buttons) do
		local q, k = b.wb, effKey(b)
		if k then
			if q.kind == "mirror" or q.kind == "pet" then
				if k ~= q.def then map[k] = { cmd = q.cmd } end
			else
				map[k] = { click = b:GetName() }
			end
		end
	end
	for key, v in pairs(map) do
		if v == "none" then
			SetOverrideBindingClick(bindOwner, false, key, "WackyBarsNone")
		elseif v.cmd then
			SetOverrideBinding(bindOwner, false, key, v.cmd)
		else
			SetOverrideBindingClick(bindOwner, false, key, v.click, "Keybind")
		end
	end
	for _, b in ipairs(buttons) do
		hotkey(b)
		local t = b.wb.arrowTex
		if t then
			if b.wb.move then pointArrow(t, b.wb.move) end
			t:SetShown(b.wb.move ~= nil)
		end
	end
	sortForQuietHUD()
	layout()
	placePets()
	-- (QuietHUD's Click through column and its mouse over hooks, per game bar: after the pet buttons joined holder 9, or
	-- they missed QuietHUD's hover until the next loading screen; audit Nov 10)
	if QuietHUD_RefreshBarClicks then QuietHUD_RefreshBarClicks() end
	gameBars()
	matchLook()
	applying = false
	if refreshOptions then refreshOptions() end
	if moving and refreshMovers then refreshMovers() end
	runHooks(ns.wb and ns.wb.applyHooks) -- (the feature files, after everything is in place)
end

local function summary()
	local mirror, spare, none, other, moves, pets = 0, 0, 0, {}, 0, 0
	for _, b in ipairs(buttons) do
		local q = b.wb
		if barOn(q.bar) then
			if q.kind == "move" then moves = moves + 1
			elseif q.kind == "pet" then pets = pets + 1
			elseif q.kind == "mirror" then mirror = mirror + 1
			elseif q.slot then spare = spare + 1
			elseif not hiddenButton(b) and not spotGone(q.spot) then none = none + 1 end
			if q.kind == "other" then other[#other + 1] = q.def .. " (" .. q.other .. ")" end
		end
	end
	say(("%d keys show the slot they fire today, %d free keys have a spare slot to fill%s."):format(mirror, spare,
		none > 0 and (", " .. none .. " free keys have no slot (out of spare slots: switch off a bar you don't use)") or ""))
	if #other > 0 then say("Left alone (they do something else): " .. table.concat(other, ", ")) end
	if moves > 0 then say(moves .. " keys move you, so they show an arrow (they follow your Key Bindings).") end
	if pets > 0 then say(pets .. " keys are pet keys, so they show your pet's buttons (the game's pet bar is hidden).") end
	say(next(tucked) and "The game's action bars are hidden while WackyBars shows (their keys still work)."
		or "The game's action bars show: every WackyBars bar is off.")
end

-- While editing or moving, the buttons show at full whatever QuietHUD says (it fades their holders), so you can see what
-- you change.
local function showFull(on)
	for _, b in ipairs(buttons) do
		if b.SetIgnoreParentAlpha then b:SetIgnoreParentAlpha(on and true or false) end
	end
	-- (the game's pet buttons in spots too: QuietHUD fades them with its Pet bar row; audit Nov 10)
	for n = 1, 10 do
		local pb = _G["PetActionButton" .. n]
		if pb and pb.wbSpot and pb.SetIgnoreParentAlpha then pb:SetIgnoreParentAlpha(on and true or false) end
	end
	-- the movement arrows are textures in the faded holder: while editing or moving they sit on the bar itself (his Ctrl
	-- bar's arrows were gone in Move bars, Nov 10)
	for _, bar in ipairs(wbBars) do
		for _, a in ipairs(bar.arrows) do a.tex:SetParent(on and bar.frame or bar.arrowHome or bar.frame) end
	end
end

-- Quick edit: hover a button, press the key you want for it (Shift, Ctrl and Alt work, and the middle and side mouse
-- buttons and the wheel). Esc on a button clears its key. Esc anywhere else, or the toggle again, finishes. Changes are
-- override keys only: your saved bindings stay as they are.
local edit = CreateFrame("Frame", "WackyBarsEdit", UIParent)
edit:SetAllPoints(UIParent)
edit:SetFrameStrata("DIALOG")
edit:Hide()
local editBg = edit:CreateTexture(nil, "BACKGROUND")
editBg:SetAllPoints()
editBg:SetColorTexture(0, 0, 0, 0.2)
local editHl = edit:CreateTexture(nil, "OVERLAY")
editHl:SetColorTexture(1, 0.82, 0, 0.35)
editHl:Hide()
local editTip = edit:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
editTip:SetPoint("TOP", edit, "TOP", 0, -120)
editTip:SetText("WackyBars: edit keys. Hover a button and press its new key. Esc on a button clears it.\nRight-click a button to hide it (or bring it back). Esc to finish.")
local hovered
local MOD_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
local function withMods(key)
	return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end
local function defaultKey(b) return b.wb.kind ~= "other" and b.wb.def or nil end
local function showTip(b)
	GameTooltip:SetOwner(b, "ANCHOR_TOP")
	local k = effKey(b)
	local name = b.wb.spot.label ~= "" and b.wb.spot.label or "(blank)"
	GameTooltip:SetText(b.wb.bar.name .. " " .. name .. ((b.wb.def or name == "(blank)") and "" or " (blank)"))
	GameTooltip:AddLine("Key: " .. (k and GetBindingText(k) or "none"), 1, 1, 1)
	if hiddenButton(b) then GameTooltip:AddLine("Hidden: right-click to bring it back.", 1, 0.5, 0.5) end
	GameTooltip:AddLine("Press a key to bind it here, Esc to clear, right-click to hide.", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end
-- Gives a button a key (false clears it). A key another button had moves here.
-- The key a button is set to, on or off (a bar that is off keeps its keys for when it comes back).
local function setTo(o)
	local e = DB.keys[o.wb.id]
	if e == false then return nil end
	return e or defaultKey(o)
end
local function setKey(b, k)
	if InCombatLockdown() then return end
	-- (a key that moves you is not taken: it would stop moving you while WackyBars is on; audit Nov 10)
	if k and MOVES[GetBindingAction(k) or ""] then
		say(GetBindingText(k) .. " moves you, so it stays a movement key. Pick another key.")
		return
	end
	if k then
		-- (the key leaves every other button, also one on a bar that is off, or switching that bar on took it back; audit
		-- Nov 10)
		for _, o in ipairs(buttons) do
			if o ~= b and (effKey(o) == k or setTo(o) == k) then
				if defaultKey(o) then DB.keys[o.wb.id] = false else DB.keys[o.wb.id] = nil end
			end
		end
	end
	local def = defaultKey(b)
	if k == def then
		DB.keys[b.wb.id] = nil
	elseif not k then
		if def then DB.keys[b.wb.id] = false else DB.keys[b.wb.id] = nil end
	else
		DB.keys[b.wb.id] = k
	end
	apply()
	if hovered == b then showTip(b) end
end
edit:SetScript("OnUpdate", function()
	local over
	for _, b in ipairs(buttons) do
		if b:IsVisible() and b:IsMouseOver() then
			over = b
			break
		end
	end
	if over ~= hovered then
		hovered = over
		if over then
			editHl:ClearAllPoints()
			editHl:SetAllPoints(over)
			editHl:Show()
			showTip(over)
		else
			editHl:Hide()
			GameTooltip:Hide()
		end
	end
end)

-- Move bars: each bar shows a box with its name; drag a box to move that bar. Esc finishes. A dropped bar snaps the way Edit
-- Mode's frames do (magnetize, below), the grid being the game's Edit Mode grid (lines from the middle of the screen, its Grid
-- Spacing setting), drawn faint here. In the game's own Edit Mode the boxes come up too, and snap when its Snap is on and its grid shows.
local movers = {}
local inBlizzardEditMode = false
local moveFrame = CreateFrame("Frame", "WackyBarsMove", UIParent)
moveFrame:SetAllPoints(UIParent)
moveFrame:SetFrameStrata("DIALOG")
moveFrame:Hide()
-- The grid spacing in UIParent units.
local function gridSpacing()
	local em = _G.EditModeManagerFrame
	local sp
	if em and em.GetAccountSettingValue and Enum and Enum.EditModeAccountSetting and Enum.EditModeAccountSetting.GridSpacing then
		local ok, v = pcall(em.GetAccountSettingValue, em, Enum.EditModeAccountSetting.GridSpacing)
		if ok and type(v) == "number" and v >= 10 then sp = v end
	end
	sp = sp or 40
	local grid = em and type(em.Grid) == "table" and em.Grid
	if grid and grid.GetEffectiveScale and (grid:GetEffectiveScale() or 0) > 0 then
		sp = sp * grid:GetEffectiveScale() / UIParent:GetEffectiveScale()
	end
	return sp
end
local gridLines = {}
local function drawGrid()
	for _, l in ipairs(gridLines) do l:Hide() end
	if inBlizzardEditMode or (DB and DB.noSnap) then return end
	local sp = gridSpacing()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local n = 0
	local function line(vertical, off)
		n = n + 1
		local t = gridLines[n]
		if not t then
			t = moveFrame:CreateTexture(nil, "BACKGROUND")
			gridLines[n] = t
		end
		t:ClearAllPoints()
		if vertical then
			t:SetSize(1, h)
			t:SetPoint("CENTER", UIParent, "CENTER", off, 0)
		else
			t:SetSize(w, 1)
			t:SetPoint("CENTER", UIParent, "CENTER", 0, off)
		end
		t:SetColorTexture(1, 1, 1, off == 0 and 0.35 or 0.12)
		t:Show()
	end
	for i = 0, math.floor(w / 2 / sp) do
		line(true, i * sp)
		if i > 0 then line(true, -i * sp) end
	end
	for i = 0, math.floor(h / 2 / sp) do
		line(false, i * sp)
		if i > 0 then line(false, -i * sp) end
	end
end
-- Whether a dropped bar snaps: in the game's Edit Mode when its Snap is on and its grid shows, else unless switched off.
local function snapOn()
	if inBlizzardEditMode then
		local em = _G.EditModeManagerFrame
		local ok, on = pcall(function() return em:IsSnapEnabled() end) -- (as the game: Snap alone; the grid only adds lines)
		return ok and on and true or false
	end
	return not DB.noSnap
end
-- Snapping, the game's Edit Mode rules (EditModeMagnetismManager, Blizzard_EditMode/Shared/EditModeUtil.lua), so a
-- WackyBars bar lands the way a game bar does (his ask, Nov 10: "they arent 1:1"). On drop, only within 8 pixels:
-- - the screen: a side to the same side, the middle to the middle, a side to the middle; and a grid line (its sides or its
--   middle), only when the grid shows;
-- - another bar: only one beside it (they overlap up and down) or above or below it (they overlap side to side), and only
--   edge to edge: your left to its right, your top to its bottom. Never lining up with a bar elsewhere on the screen.
-- - a corner (yours on its corner, beside or above it, not diagonal) within 8 * 1.4 wins over everything: both ways at once.
-- - else the screen or grid both ways, but next to a bar only the nearer of the two ways (the other stays as dropped).
-- While you drag, lines show where it will snap. The other bars: the other WackyBars bars and the game's that show (their
-- Edit Mode box, as the game measures them). Not copied: a game bar snapped to another moves with it later; WackyBars bars
-- keep their own place.
local MAGNET = 8
local GAME_BAR_FRAMES = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
	"MultiBar5", "MultiBar6", "MultiBar7", "PetActionBar", "StanceBar" }
local function sidesUI(f)
	local l, b, w, h = f:GetRect()
	if not (l and b and w and h) then return nil end
	local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	-- (where the bar really is: without QuietHUD's pixel shift, or a nudge, a resize or a snap saved the shift into its
	-- place, a few pixels more each time; audit Nov 10. While Move bars is open QuietHUD pauses the shift anyway.)
	local dx, dy = 0, 0
	if QuietHUD_ShiftOffset then
		local ok, x, y = pcall(QuietHUD_ShiftOffset, f)
		if ok and type(x) == "number" and type(y) == "number" then dx, dy = x, y end
	end
	return l * k - dx, (l + w) * k - dx, b * k - dy, (b + h) * k - dy, k
end
local function gridShown()
	if inBlizzardEditMode then
		local em = _G.EditModeManagerFrame
		local ok, shown = pcall(function() return type(em.Grid) == "table" and em.Grid:IsShown() end)
		return ok and shown
	end
	return not DB.noSnap
end
local function placeBar(bar, left, top, k)
	local f = bar.frame
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / k, top / k)
	DB.pos[bar.id] = { "TOPLEFT", "BOTTOMLEFT", left / k, top / k }
end
-- The screen and the grid, one way (vertical: the x way). The nearest, in range or not (checked after).
local function screenSnap(lo, hi, size)
	local mid = (lo + hi) / 2
	local best
	local function try(src, target)
		local d = math.abs(target - src)
		if not best or d < best.dist then best = { dist = d, delta = target - src, pos = target, screen = true } end
	end
	try(lo, 0) try(hi, size) try(mid, size / 2) try(lo, size / 2) try(hi, size / 2)
	if gridShown() then
		local sp = gridSpacing()
		for i = 1, math.floor(size / 2 / sp) do
			for _, g in ipairs({ size / 2 + i * sp, size / 2 - i * sp }) do
				try(lo, g) try(hi, g) try(mid, g)
			end
		end
	end
	return best
end
-- Where a dropped bar goes: dx, dy and the lines to show (x = a vertical line there, y = a horizontal one), or nil.
local function snapPlan(bar)
	local L, R, B, T, k = sidesUI(bar.frame)
	if not L then return nil end
	local range = MAGNET / UIParent:GetEffectiveScale()
	local h = screenSnap(L, R, UIParent:GetWidth())
	local v = screenSnap(B, T, UIParent:GetHeight())
	if h and h.dist > range then h = nil end
	if v and v.dist > range then v = nil end
	local others = {}
	for _, o in ipairs(wbBars) do
		if o ~= bar and o.frame:IsVisible() then others[#others + 1] = { sidesUI(o.frame) } end
	end
	for _, n in ipairs(GAME_BAR_FRAMES) do
		local f = _G[n]
		if f and f.IsVisible and f:IsVisible() then
			local box = (type(f.Selection) == "table" and f.Selection.GetRect and f.Selection:GetRect()) and f.Selection or f
			others[#others + 1] = { sidesUI(box) }
		end
	end
	local hFrame, vFrame
	for _, o in ipairs(others) do
		local l2, r2, b2, t2 = o[1], o[2], o[3], o[4]
		if l2 then
			-- beside it (overlapping up and down): your side to its side
			if T >= b2 and B <= t2 and (r2 < L or l2 > R) then
				local d, pos = (r2 < L) and (L - r2) or (l2 - R), (r2 < L) and r2 or l2
				if d <= range then
					local c = { dist = d, delta = (r2 < L) and (r2 - L) or (l2 - R), pos = pos, rect = o }
					if not h or d < h.dist then h = c end
					if not hFrame or d < hFrame.dist then hFrame = c end
				end
			end
			-- above or below it (overlapping side to side): your top to its bottom, your bottom to its top
			if R >= l2 and L <= r2 and (b2 > T or t2 < B) then
				local d, pos = (b2 > T) and (b2 - T) or (B - t2), (b2 > T) and b2 or t2
				if d <= range then
					local c = { dist = d, delta = (b2 > T) and (b2 - T) or (t2 - B), pos = pos, rect = o }
					if not v or d < v.dist then v = c end
					if not vFrame or d < vFrame.dist then vFrame = c end
				end
			end
		end
	end
	-- corners: of the nearest bar beside and the nearest above or below, the nearest corner pair, not diagonal
	local corner
	local mine = { TOPLEFT = { L, T }, TOPRIGHT = { R, T }, BOTTOMLEFT = { L, B }, BOTTOMRIGHT = { R, B } }
	local DIAGONAL = { TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT" }
	for _, c in ipairs({ hFrame or false, vFrame or false }) do
		if c then
			local o = c.rect
			local theirs = { TOPLEFT = { o[1], o[4] }, TOPRIGHT = { o[2], o[4] }, BOTTOMLEFT = { o[1], o[3] }, BOTTOMRIGHT = { o[2], o[3] } }
			for mn, mp in pairs(mine) do
				for tn, tp in pairs(theirs) do
					if DIAGONAL[mn] ~= tn then
						local dx, dy = tp[1] - mp[1], tp[2] - mp[2]
						local sq = dx * dx + dy * dy
						if sq <= 2 * MAGNET * MAGNET and (not corner or sq < corner.sq) then -- (Blizzard: a fixed 128, UI units)
							corner = { sq = sq, dx = dx, dy = dy, x = tp[1], y = tp[2] }
						end
					end
				end
			end
		end
	end
	if corner then return corner.dx, corner.dy, corner.x, corner.y, L, T, k end
	if h and v and h.screen and v.screen then return h.delta, v.delta, h.pos, v.pos, L, T, k end
	if h and (not v or h.dist < v.dist) then return h.delta, 0, h.pos, nil, L, T, k end
	if v then return 0, v.delta, nil, v.pos, L, T, k end
	return nil
end
local function magnetize(bar)
	local dx, dy, _, _, L, T, k = snapPlan(bar)
	if not dx then return false end
	placeBar(bar, L + dx, T + dy, k)
	return true
end
-- The lines while you drag (the game shows them too): where the bar will snap if dropped now.
local previewLines = {}
local function preview(bar)
	local x, y
	if bar and snapOn() then
		local _
		_, _, x, y = snapPlan(bar)
	end
	for i, pos in ipairs({ x or false, y or false }) do
		local t = previewLines[i]
		if not t then
			t = moveFrame:CreateTexture(nil, "OVERLAY")
			t:SetColorTexture(1, 0.82, 0, 0.9)
			previewLines[i] = t
		end
		t:ClearAllPoints()
		if pos and i == 1 then
			t:SetSize(1.5, UIParent:GetHeight())
			t:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", pos, 0)
		elseif pos then
			t:SetSize(UIParent:GetWidth(), 1.5)
			t:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, pos)
		end
		t:SetShown(pos and true or false)
	end
end
-- Arrow keys move the selected bar 1 pixel, 10 with Shift (as in the game's Edit Mode).
local function nudge(bar, dx, dy)
	local L, _, _, T, k = sidesUI(bar.frame)
	if L then placeBar(bar, L + dx, T + dy, k) end
end
local selected
local dragging -- (the bar being dragged, if one is)
-- The picked bar's size, like Edit Mode's Icon Size for one frame: a slider from 50% to 200% in steps of 5 (and - / +),
-- shown while a WackyBars bar is picked in Move bars. The bar's top left corner stays where it is.
local sizePanel = CreateFrame("Frame", "WackyBarsSize", moveFrame)
sizePanel:SetSize(330, 62)
sizePanel:SetPoint("TOP", moveFrame, "TOP", 0, -150)
sizePanel:SetFrameStrata("DIALOG")
sizePanel:EnableMouse(true)
sizePanel:Hide()
local sizeBg = sizePanel:CreateTexture(nil, "BACKGROUND")
sizeBg:SetAllPoints()
sizeBg:SetColorTexture(0, 0, 0, 0.75)
local sizeText = sizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sizeText:SetPoint("TOP", sizePanel, "TOP", 0, -8)
local slider = CreateFrame("Slider", "WackyBarsSizeSlider", sizePanel)
slider:SetOrientation("HORIZONTAL")
slider:SetSize(220, 16)
slider:SetPoint("BOTTOM", sizePanel, "BOTTOM", 0, 12)
slider:SetMinMaxValues(0.5, 2)
slider:SetValueStep(0.05)
if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
local track = slider:CreateTexture(nil, "BACKGROUND")
track:SetColorTexture(1, 1, 1, 0.25)
track:SetHeight(4)
track:SetPoint("LEFT", slider, "LEFT")
track:SetPoint("RIGHT", slider, "RIGHT")
local SIZE_MIN, SIZE_MAX = 0.5, 2
-- A bar's new size, its top left corner kept where it is (that place is saved, also for a bar never moved).
sizeBar = function(bar, v)
	local L, _, _, T = sidesUI(bar.frame)
	DB.sizes[bar.id] = (v ~= 1) and v or nil
	bar.frame:SetScale(v)
	if L then placeBar(bar, L, T, bar.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()) end -- (also a bar never moved: it slid)
end
local function resize(bar, v)
	if not bar or InCombatLockdown() then return end
	v = math.max(SIZE_MIN, math.min(SIZE_MAX, math.floor(v * 20 + 0.5) / 20))
	sizeBar(bar, v)
	sizeText:SetText(("%s: %d%%"):format(bar.name, math.floor(v * 100 + 0.5)))
end
local settingSlider = false
slider:SetScript("OnValueChanged", function(_, v)
	if not settingSlider and selected then resize(selected, v) end
end)
for i, d in ipairs({ -0.05, 0.05 }) do
	local b = CreateFrame("Button", nil, sizePanel, "UIPanelButtonTemplate")
	b:SetSize(26, 20)
	b:SetPoint(i == 1 and "RIGHT" or "LEFT", slider, i == 1 and "LEFT" or "RIGHT", i == 1 and -6 or 6, 0)
	b:SetText(i == 1 and "-" or "+")
	b:SetScript("OnClick", function()
		if not selected then return end
		local v = math.max(SIZE_MIN, math.min(SIZE_MAX, sizeOf(selected) + d))
		settingSlider = true
		slider:SetValue(v)
		settingSlider = false
		resize(selected, v)
	end)
end
local function select(bar)
	selected = bar
	if bar then
		settingSlider = true
		slider:SetValue(sizeOf(bar))
		settingSlider = false
		sizeText:SetText(("%s: %d%%"):format(bar.name, math.floor(sizeOf(bar) * 100 + 0.5)))
	end
	sizePanel:SetShown(bar and true or false)
	for b, m in pairs(movers) do
		if b == bar then
			m.bg:SetColorTexture(1, 0.82, 0, 0.45)
			m.label:SetTextColor(1, 1, 1)
		else
			m.bg:SetColorTexture(0.2, 0.5, 1, 0.35)
			m.label:SetTextColor(1, 0.82, 0)
		end
	end
end
local moveTip = moveFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
moveTip:SetPoint("TOP", moveFrame, "TOP", 0, -120)
moveTip:SetText("WackyBars: move bars. Drag a bar to move it; click one to size it, or use the arrow keys (Shift: 10). Esc to finish.")
for i, bar in ipairs(wbBars) do
	local m = CreateFrame("Frame", "WackyBarsMove" .. bar.id, moveFrame)
	m:SetFrameStrata("DIALOG")
	m:SetFrameLevel(moveFrame:GetFrameLevel() + i) -- (later bars on top: where two overlap you grab the one you see)
	m:EnableMouse(true)
	m:RegisterForDrag("LeftButton")
	m.bg = m:CreateTexture(nil, "BACKGROUND")
	m.bg:SetAllPoints()
	m.bg:SetColorTexture(0.2, 0.5, 1, 0.35)
	m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	m.label:SetPoint("CENTER")
	m.label:SetText(bar.name)
	m:SetScript("OnMouseDown", function() select(bar) end)
	m:SetScript("OnDragStart", function()
		if InCombatLockdown() then return end
		select(bar)
		bar.frame:StartMoving()
		dragging = bar
		m:SetScript("OnUpdate", function() preview(bar) end) -- (only while dragging)
	end)
	m:SetScript("OnDragStop", function()
		m:SetScript("OnUpdate", nil)
		preview(nil)
		if dragging ~= bar then return end -- (already stopped: Move bars was closed mid drag)
		dragging = nil
		bar.frame:StopMovingOrSizing()
		if bar.frame.SetUserPlaced then bar.frame:SetUserPlaced(false) end
		if not (snapOn() and magnetize(bar)) then
			local p, _, rp, x, y = bar.frame:GetPoint(1)
			if p then DB.pos[bar.id] = { p, rp, x, y } end
		end
	end)
	movers[bar] = m
end

-- A drag cut short (Esc, a fight starting, the game's Edit Mode closing): the bar stops where it is and keeps that place,
-- and the drag's lines go (audit Nov 10). A fight's first moment still allows it (PLAYER_REGEN_DISABLED comes first).
local function stopDrag()
	local bar = dragging
	if not bar then return end
	dragging = nil
	movers[bar]:SetScript("OnUpdate", nil)
	preview(nil)
	if InCombatLockdown() then return end
	bar.frame:StopMovingOrSizing()
	if bar.frame.SetUserPlaced then bar.frame:SetUserPlaced(false) end
	local p, _, rp, x, y = bar.frame:GetPoint(1)
	if p then DB.pos[bar.id] = { p, rp, x, y } end
end
refreshMovers = function()
	for b, m in pairs(movers) do m:SetShown(barOn(b)) end
end
local function stopModes()
	stopDrag()
	local wasEditing = editing
	editing, moving = false, false
	selected = nil
	edit:Hide()
	moveFrame:Hide()
	editHl:Hide()
	hovered = nil
	GameTooltip:Hide()
	showFull(false)
	if QuietHUD_ShiftPause then pcall(QuietHUD_ShiftPause, false) end -- (QuietHUD's pixel shift goes on again)
	if wasEditing then apply() end
end
local function startEdit()
	if InCombatLockdown() then
		say("not in a fight.")
		return
	end
	stopModes()
	editing = true
	showFull(true)
	apply()
	edit:Show()
	edit:EnableKeyboard(true)
	edit:EnableMouse(true)
	edit:EnableMouseWheel(true)
end
local function startMove()
	if InCombatLockdown() then
		say("not in a fight.")
		return
	end
	stopModes()
	moving = true
	-- (QuietHUD's pixel shift puts the bars back at their places while you move them, as in Edit Mode: what you drop,
	-- nudge or resize is never a shifted place; audit Nov 10)
	if QuietHUD_ShiftPause then pcall(QuietHUD_ShiftPause, true) end
	showFull(true)
	for bar, m in pairs(movers) do
		m:ClearAllPoints()
		m:SetAllPoints(bar.frame)
		m:SetShown(barOn(bar))
	end
	select(nil)
	moveFrame:Show()
	moveFrame:EnableKeyboard(true) -- (arrow keys for the selected bar; in the game's Edit Mode, Esc stays the game's)
	drawGrid()
	moveTip:SetShown(not inBlizzardEditMode)
end
-- The game's Edit Mode: our boxes come up with it and go with it.
local function hookBlizzardEditMode()
	local em = _G.EditModeManagerFrame
	if not em or em.wbHooked or not em.HookScript then return end
	em.wbHooked = true
	em:HookScript("OnShow", function()
		if InCombatLockdown() then return end
		inBlizzardEditMode = true
		startMove()
	end)
	em:HookScript("OnHide", function()
		inBlizzardEditMode = false
		if moving then stopModes() end
	end)
	-- picking one of the game's frames there drops the WackyBars selection (so the arrow keys move that one)
	if type(em.SelectSystem) == "function" then
		hooksecurefunc(em, "SelectSystem", function() if selected then select(nil) end end)
	end
end
edit:SetScript("OnKeyDown", function(self, key)
	if key == "ESCAPE" then
		self:SetPropagateKeyboardInput(false)
		if hovered then setKey(hovered, false) else stopModes() end
		return
	end
	if MOD_KEYS[key] or not hovered then
		self:SetPropagateKeyboardInput(true)
		return
	end
	self:SetPropagateKeyboardInput(false)
	setKey(hovered, withMods(key))
end)
edit:SetScript("OnMouseDown", function(_, button)
	if button == "RightButton" and hovered and not InCombatLockdown() then
		local b = hovered
		DB.hidden[b.wb.id] = not DB.hidden[b.wb.id] or nil
		port()
		apply()
		showTip(b)
		return
	end
	local k = MOUSE_KEYS[button]
	if k and hovered then setKey(hovered, withMods(k)) end
end)
edit:SetScript("OnMouseWheel", function(_, delta)
	if hovered then setKey(hovered, withMods(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")) end
end)
local ARROWS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
moveFrame:SetScript("OnKeyDown", function(self, key)
	local a = ARROWS[key]
	if a and selected and not InCombatLockdown() then
		self:SetPropagateKeyboardInput(false)
		local step = IsShiftKeyDown() and 10 or 1
		nudge(selected, a[1] * step, a[2] * step)
	elseif key == "ESCAPE" and not inBlizzardEditMode then
		self:SetPropagateKeyboardInput(false)
		stopModes()
	else
		self:SetPropagateKeyboardInput(true)
	end
end)

function WackyBars_ToggleEdit()
	if editing then stopModes() else startEdit() end
end
function WackyBars_ToggleMove()
	if moving then stopModes() else startMove() end
end

-- The options window: which bars show, staggered rows, the game bars, size, and the buttons for the two modes.
local options
local function toggleOptions()
	if not options then
		local ok, w = pcall(CreateFrame, "Frame", "WackyBarsOptions", UIParent, "ButtonFrameTemplate")
		local framed = ok and w and w.SetTitle and type(w.Inset) == "table"
		if ok and w and not framed then w:Hide() end
		options = framed and w or CreateFrame("Frame", "WackyBarsOptions", UIParent)
		options:SetSize(400, 84 + 4 * 26 + 56 + 26 + 30 + 30 + 30 + 30 + 144 + 50 + 30 * #(ns.wb and ns.wb.optionRows or {}))
		options:SetPoint("CENTER")
		options:SetFrameStrata("DIALOG")
		options:SetClampedToScreen(true)
		options:SetMovable(true)
		options:EnableMouse(true)
		options:RegisterForDrag("LeftButton")
		options:SetScript("OnDragStart", options.StartMoving)
		options:SetScript("OnDragStop", options.StopMovingOrSizing)
		if UISpecialFrames then table.insert(UISpecialFrames, "WackyBarsOptions") end
		if framed then
			options:SetTitle("WackyBars")
			if options.SetPortraitToAsset then pcall(options.SetPortraitToAsset, options, "Interface\\AddOns\\WackyBars\\icon") end -- (its own icon, as QuietHUD does)
		else
			local bg = options:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
			local title = options:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			title:SetPoint("TOP", 0, -10)
			title:SetText("WackyBars")
			local close = CreateFrame("Button", nil, options, "UIPanelCloseButton")
			close:SetPoint("TOPRIGHT", 2, 2)
		end
		local controls = {}
		local function text(x, y, s, font)
			local t = options:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
			t:SetPoint("TOPLEFT", x, y)
			t:SetText(s)
			return t
		end
		local function check(x, y, label, get, set)
			local c = CreateFrame("CheckButton", nil, options, "UICheckButtonTemplate")
			c:SetPoint("TOPLEFT", x, y)
			local t = options:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			t:SetPoint("LEFT", c, "RIGHT", 2, 0)
			t:SetText(label)
			c:SetScript("OnClick", function(self)
				if InCombatLockdown() then
					self:SetChecked(get())
					say("after the fight.")
					return
				end
				set(not get())
				port() -- (a bar switched off gives its empty spare slots back)
				apply()
			end)
			controls[#controls + 1] = function() c:SetChecked(get() and true or false) end
		end
		local function button(x, y, width, label, fn)
			local b = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
			b:SetSize(width, 24)
			b:SetPoint("TOPLEFT", x, y)
			b:SetText(label)
			b:SetScript("OnClick", function(self) fn(self) end)
			return b
		end
		-- the bars: a box per bar, keyboard and mouse side by side, one row per modifier; Hypershift under them. How they fade,
		-- show on mouse over or in a fight is set in QuietHUD, with your other bars.
		local function barById(id)
			for _, bar in ipairs(wbBars) do if bar.id == id then return bar end end
		end
		local function barBox(x, y, id, name)
			local bar = barById(id)
			if bar then check(x, y, name or "", function() return barOn(bar) end, function(v) DB.off[bar.id] = (not v) or nil end) end
		end
		text(20, -70, "Bars")
		text(140, -72, "Keyboard", "GameFontHighlightSmall")
		text(246, -72, "Mouse", "GameFontHighlightSmall")
		for i, L in ipairs(LAYERS) do
			local y = -84 - (i - 1) * 26
			text(24, y - 6, L.mod == "" and "Plain" or L.id, "GameFontHighlight")
			barBox(150, y, L.id)
			barBox(246, y, "Mouse" .. L.id)
		end
		local below = -84 - #LAYERS * 26
		barBox(20, below, "MouseHyper", "Hypershift")
		-- (how each bar fades, shows on mouse over, with the whole HUD or lets clicks through: QuietHUD's Action bars page,
		-- where each row is named after the WackyBars bars on it; one place for all of it, the owner, Nov 10)
		text(24, below - 26, "How bars fade and show: QuietHUD (if installed), Action bars page.", "GameFontHighlightSmall")
		below = below - 56
		check(20, below, "Staggered keyboard rows", function() return DB.stagger end, function(v) DB.stagger = v or nil end)
		check(20, below - 26, "Show the modifier in labels (sQ, cQ, aQ, h1)", function() return DB.mods end,
			function(v) DB.mods = v or nil end)
		check(20, below - 52, "Snap when moving bars (like Edit Mode)", function() return not DB.noSnap end,
			function(v) DB.noSnap = (not v) or nil; if moving then drawGrid() end end)
		check(20, below - 78, "Edge buttons (E1, E2)", function() return not DB.noEdges end,
			function(v) DB.noEdges = (not v) or nil end)
		check(200, below - 78, "Wheel click button", function() return not DB.noWheel end,
			function(v) DB.noWheel = (not v) or nil end)
		below = below - 26
		-- Movement keys: one button cycles Key Bindings, WASD, ESDF (three states, so not boxes)
		text(24, below - 86, "Movement keys", "GameFontHighlight")
		local MOVE_MODES = { false, "WASD", "ESDF" }
		local moveCycle = button(150, below - 80, 160, "", function()
			if InCombatLockdown() then say("after the fight.") return end
			local at = 1
			for i, m in ipairs(MOVE_MODES) do if (DB.moveKeys or false) == m then at = i end end
			DB.moveKeys = MOVE_MODES[at % #MOVE_MODES + 1] or nil
			port()
			apply()
		end)
		controls[#controls + 1] = function() moveCycle:SetText(DB.moveKeys or "From Key Bindings") end
		below = below - 30
		-- Look: Default (your Action Bar 1's, BetterBlizzFrames' dark with it) or Purple to pink (the look block above)
		text(24, below - 86, "Look", "GameFontHighlight")
		local lookCycle = button(150, below - 80, 160, "", function()
			DB.look = (DB.look ~= "gradient") and "gradient" or nil
			matchLook()
			if refreshOptions then refreshOptions() end -- (its label: it kept the old look's name; audit Nov 10)
		end)
		controls[#controls + 1] = function() lookCycle:SetText(DB.look == "gradient" and "Purple to pink" or "Default") end
		below = below - 30
		-- Bar art: the faint wing in empty buttons, as on Action Bar 1 with its bar art; off (the default) a plain dark slot, as
		-- on the game's other bars (his "any way to turn the bar art off in wbars?", Nov 10)
		check(20, below - 82, "Bar art (the faint wing in empty buttons)", function() return DB.barArt end,
			function(v) DB.barArt = v or nil end)
		below = below - 30
		-- Arrows: how strong the movement arrows are (his ask, Nov 10: "make that an option we can change"); one button cycles
		-- the steps, 30% the default. QuietHUD's fade multiplies on top (30% at his 0.6 Shown is 18% on screen).
		text(24, below - 86, "Arrows", "GameFontHighlight")
		local ARROW_STEPS = { 0.2, 0.3, 0.5, 0.7, 1 }
		local arrowCycle = button(150, below - 80, 160, "", function()
			local at = 2
			for i, v in ipairs(ARROW_STEPS) do if math.abs((DB.arrowAlpha or 0.3) - v) < 0.01 then at = i end end
			local v = ARROW_STEPS[at % #ARROW_STEPS + 1]
			DB.arrowAlpha = (v ~= 0.3) and v or nil
			matchLook()
			if refreshOptions then refreshOptions() end
		end)
		controls[#controls + 1] = function()
			arrowCycle:SetText(("%d%%"):format(math.floor((DB.arrowAlpha or 0.3) * 100 + 0.5)))
		end
		below = below - 30
		-- the boxes the feature files add (ns.wb.optionRows: { label, get, set }), one row each
		for _, r in ipairs(ns.wb and ns.wb.optionRows or {}) do
			check(20, below - 82, r.label, r.get, r.set)
			below = below - 30
		end
		text(24, below - 88, "Size: Move bars, click a bar (each bar its own, like Edit Mode)", "GameFontHighlightSmall")
		button(20, below - 110, 170, "Move bars", function() options:Hide() startMove() end)
		button(200, below - 110, 170, "Edit keys", function() options:Hide() startEdit() end)
		button(20, below - 144, 170, "Reset places", function()
			if InCombatLockdown() then say("after the fight.") return end
			DB.pos, DB.sizes = {}, {}
			apply()
		end)
		refreshOptions = function()
			if options and options:IsShown() then
				for _, f in ipairs(controls) do f() end
			end
		end
		options:SetScript("OnShow", refreshOptions)
		options:Hide()
	end
	if options:IsShown() then
		options:Hide()
	else
		options:Show()
		refreshOptions()
	end
end
function WackyBars_ToggleOptions() toggleOptions() end
-- An entry under Esc, Options, AddOns: one button that opens the window above.
local function addSettingsEntry()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("WackyBars")
	local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	note:SetText("Bars on and off, move bars, edit keys, size. Also /wbars in chat.")
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(200, 26)
	open:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
	open:SetText("Open WackyBars")
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel) end
		if not (_G.WackyBarsOptions and _G.WackyBarsOptions:IsShown()) then toggleOptions() end
	end)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "WackyBars")
	Settings.RegisterAddOnCategory(category)
end
BINDING_HEADER_WACKYBARS = "WackyBars"
BINDING_NAME_WACKYBARS_OPTIONS = "Options"
BINDING_NAME_WACKYBARS_MOVE = "Move bars"
BINDING_NAME_WACKYBARS_EDIT = "Edit keys (hover a button, press the new key)"

-- When you press a key that goes through a game bar, its buttons here go down too.
local function pushed(cmd, state)
	for _, b in ipairs(byCmd[cmd] or {}) do
		-- (also a mirror given another key in Edit keys: its new key runs the same game command)
		if b:IsVisible() and effKey(b) and b.GetButtonState and b:GetButtonState() ~= state then
			b:SetButtonState(state)
		end
	end
end
if type(ActionButtonDown) == "function" then
	hooksecurefunc("ActionButtonDown", function(id) pushed("ACTIONBUTTON" .. tostring(id), "PUSHED") end)
	hooksecurefunc("ActionButtonUp", function(id) pushed("ACTIONBUTTON" .. tostring(id), "NORMAL") end)
end
if type(MultiActionButtonDown) == "function" then
	local function cmdOf(barName, id)
		local i = BAR_BY_FRAME[barName]
		return i and (BARS[i].cmd .. tostring(id))
	end
	hooksecurefunc("MultiActionButtonDown", function(barName, id) local c = cmdOf(barName, id) if c then pushed(c, "PUSHED") end end)
	hooksecurefunc("MultiActionButtonUp", function(barName, id) local c = cmdOf(barName, id) if c then pushed(c, "NORMAL") end end)
end

-- (Bartender4's order, StateBar.lua; the pager works out "possess")
local function pageDriver()
	return "[vehicleui][overridebar][possessbar][shapeshift] possess; [bonusbar:5] possess; [bar:2] 2; [bar:3] 3; "
		.. "[bar:4] 4; [bar:5] 5; [bar:6] 6; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; 1"
end

local started = false
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("CVAR_UPDATE") -- (Lock Action Bars switched in the options reaches the buttons at once)
local function onEvent(_, event, arg)
	if event == "ADDON_LOADED" and arg == ADDON then
		WackyBarsCharDB = type(WackyBarsCharDB) == "table" and WackyBarsCharDB or {}
		DB = WackyBarsCharDB
		DB.noPeek = nil -- (the Alt boxes, Nov 10, moved to QuietHUD's Show with Alt column the same day)
		for _, k in ipairs({ "keys", "spare", "pos", "off", "hidden", "sizes" }) do
			if type(DB[k]) ~= "table" then DB[k] = {} end
		end
		-- the one size for all bars (before Nov 10, late) becomes each bar's size
		if type(DB.scale) == "number" then
			for _, bar in ipairs(wbBars) do DB.sizes[bar.id] = DB.scale end
			DB.scale = nil
		end
		-- Once, for the Nov 10 redesign (and a new character): the plain bars and Hypershift on, the Shift, Ctrl and Alt copies
		-- off. Gone from before: WackyBars' own mouse over and hide in a fight (QuietHUD's job now), Lite's four one-button
		-- bars and the game bars box (always hidden now).
		if (DB.v or 1) < 2 then
			for _, bar in ipairs(wbBars) do DB.off[bar.id] = (not DEFAULT_ON[bar.id]) or nil end
			DB.mouseover, DB.combatHide, DB.moved, DB.lite, DB.hideGame = nil, nil, nil, nil, nil
			DB.v = 2
		end
		-- Every load: the spare slots, keys and hidden marks of buttons that no longer exist go (a spell in such a slot
		-- would otherwise keep it for nothing).
		local ids = {}
		for _, b in ipairs(buttons) do ids[b.wb.id] = true end
		for _, t in ipairs({ DB.spare, DB.keys, DB.hidden }) do
			for id in pairs(t) do if not ids[id] then t[id] = nil end end
		end
		pcall(addSettingsEntry)
		pcall(hookBlizzardEditMode)
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not DB or started then return end
		if InCombatLockdown() then
			pending = true
			return
		end
		started = true
		RegisterStateDriver(pager, "page", pageDriver())
		port()
		apply()
		hookLook()
		C_Timer.After(2, matchLook)
		if not DB.told then
			DB.told = true
			summary()
			say("/wbars opens the options (bars on and off, move, edit keys, size).")
		end
	elseif event == "UPDATE_BINDINGS" then
		if not started or applying then return end
		if bindSig() ~= signature then
			port()
			apply()
		end
	elseif event == "CVAR_UPDATE" then
		if started and arg and tostring(arg):lower() == "lockactionbars" then
			if InCombatLockdown() then pending = true else apply() end
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if editing or moving then stopModes() end
		if options and options:IsShown() then options:Hide() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if not started and DB then
			onEvent(nil, "PLAYER_ENTERING_WORLD")
		elseif pending then
			apply()
		end
	end
end
events:SetScript("OnEvent", onEvent)

SLASH_WACKYBARS1, SLASH_WACKYBARS2 = "/wbars", "/wackybars"
SlashCmdList.WACKYBARS = function(msg)
	local cmd, rest = (msg or ""):lower():match("^(%S*)%s*(.-)$")
	if not DB then return end
	local extra = ns.wb and ns.wb.slash[cmd] -- (a word a feature file added)
	if extra then extra(rest) return end
	if cmd == "" or cmd == "options" then
		toggleOptions()
	elseif cmd == "edit" then
		WackyBars_ToggleEdit()
	elseif cmd == "move" then
		WackyBars_ToggleMove()
	elseif cmd == "scale" then
		local n = tonumber(rest)
		if InCombatLockdown() then say("after the fight.") return end
		-- (each bar keeps its top left corner: before, the old places came back at the new size, off where they were)
		if n and n >= 0.5 and n <= 2 then -- (the same range as the size slider)
			for _, bar in ipairs(wbBars) do sizeBar(bar, n) end
		elseif rest == "" or rest == "auto" then
			for _, bar in ipairs(wbBars) do sizeBar(bar, 1) end
		else
			say("/wbars scale 0.5 to 2 sets every bar (1 = the size of your Action Bar 1 buttons), or /wbars scale auto")
			return
		end
		apply()
	elseif cmd == "stagger" then
		DB.stagger = not DB.stagger or nil
		apply()
		say(DB.stagger and "rows staggered like the keyboard." or "straight rows.")
	elseif cmd == "reset" then
		DB.keys, DB.pos, DB.sizes, DB.hidden = {}, {}, {}, {}
		if not InCombatLockdown() then port() end -- (a hidden button gets a slot again)
		apply()
		say("keys from edit cleared, hidden buttons back, places and size back to the default. Spells in spare slots kept.")
	elseif cmd == "status" then
		if not InCombatLockdown() then port() apply() end
		summary()
	else
		local words = {}
		for w in pairs(ns.wb and ns.wb.slash or {}) do words[#words + 1] = w end
		table.sort(words)
		say("/wbars (options), move, edit, scale <n|auto>, stagger, reset, status" .. (#words > 0 and (", " .. table.concat(words, ", ")) or ""))
	end
end

-- For WackyBars' feature files, listed after this one in the TOC (the ideas he picked on Nov 10 night): what they may use
-- and where they plug in, so each lives in a file of its own instead of editing this one. optionRows: a box each in /wbars
-- ({ label, get, set }, set runs out of a fight, then the bars are applied again); slash: /wbars <word> = fn(rest);
-- lookHooks: after each look update; applyHooks: after each apply (out of a fight, everything in place).
ns.wb = {
	buttons = buttons, bars = wbBars, db = function() return DB end, say = say,
	part = part, art = art, mix = mix, gradOn = gradOn, span = span, tint = tint, colourOne = colourOne,
	effKey = effKey, hotkeyText = hotkeyText, matchLook = matchLook, apply = apply, barOn = barOn,
	editing = function() return editing end, moving = function() return moving end,
	optionRows = {}, slash = {}, lookHooks = {}, applyHooks = {},
}
