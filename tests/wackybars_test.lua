-- Checks WackyBars with fake frames: each key shows the slot it fires today, free keys get a spare slot that holds nothing,
-- keys that do something else are left alone, movement keys show arrows (ESDF or WASD, from Key Bindings), the mouse bars,
-- quick edit moves and clears keys through override bindings only, bars switch off, move mode snaps like Edit Mode and
-- saves places, the game's bars are tucked away while WackyBars shows, and the saved key bindings are never written.
-- Run: luajit tests/wackybars_test.lua (from wow-wackybars)
local out = print
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
package.path = HERE .. "/../wow-addon-harness/?.lua;" .. package.path
local M = require("wowmock")
M.install()
local failures = 0
local function check(name, cond) out(("%-76s %s"):format(name, cond and "ok" or "FAILED")); if not cond then failures = failures + 1 end end

-- Saved bindings (what GetBindingAction reads), what has something in it, the override keys WackyBars sets.
local binds = {
	Q = "ACTIONBUTTON1", W = "ACTIONBUTTON2", T = "ACTIONBUTTON5", ["1"] = "MULTIACTIONBAR1BUTTON7",
	["SHIFT-Q"] = "MULTIACTIONBAR3BUTTON1", ["CTRL-Q"] = "MULTIACTIONBAR6BUTTON2", ["\\"] = "CLICK LockMenuKey:LeftButton", CAPSLOCK = "MULTIACTIONBAR4BUTTON9",
	E = "MOVEFORWARD", S = "STRAFELEFT", D = "MOVEBACKWARD", F = "STRAFERIGHT",
	["SHIFT-E"] = "MULTIACTIONBAR2BUTTON3", F5 = "MULTIACTIONBAR3BUTTON2", F1 = "MULTIACTIONBAR3BUTTON3",
	NUMPAD1 = "MULTIACTIONBAR7BUTTON10", NUMPADPLUS = "MULTIACTIONBAR7BUTTON3", ["SHIFT-MOUSEWHEELUP"] = "MULTIACTIONBAR1BUTTON6",
	MOUSEWHEELUP = "CAMERAZOOMIN", ["CTRL-E"] = "NONE", ["CTRL-S"] = "TOGGLESOUND",
}
local actions = { [1] = true, [2] = true, [67] = true, [25] = true, [158] = true, [26] = true, [13] = true, [27] = true }
local overrides, written = {}, 0
rawset(_G, "GetBindingAction", function(key, checkOverride) if checkOverride then error("override read") end return binds[key] or "" end)
rawset(_G, "GetBindingKey", function(cmd) for k, c in pairs(binds) do if c == cmd then return k end end end)
rawset(_G, "GetBindingText", function(k) return k end)
rawset(_G, "HasAction", function(s) return actions[s] or false end)
rawset(_G, "SetBinding", function() written = written + 1 end)
rawset(_G, "SaveBindings", function() written = written + 1 end)
rawset(_G, "SetOverrideBinding", function(_, _, key, cmd) overrides[key] = { cmd = cmd } end)
rawset(_G, "SetOverrideBindingClick", function(_, _, key, name, how) overrides[key] = { click = name, how = how } end)
rawset(_G, "ClearOverrideBindings", function() overrides = {} end)
local drivers = {}
rawset(_G, "RegisterStateDriver", function(f, state, v) drivers[f] = drivers[f] or {}; drivers[f][state] = v end)
rawset(_G, "UnregisterStateDriver", function(f, state) if drivers[f] then drivers[f][state] = nil end end)
rawset(_G, "C_ActionBar", { GetOverrideBarIndex = function() return 14 end, GetVehicleBarIndex = function() return 12 end })
rawset(_G, "C_Texture", { GetAtlasInfo = function() return {} end })
rawset(_G, "RANGE_INDICATOR", "*")
local combat = false
rawset(_G, "InCombatLockdown", function() return combat end)
local shift = false
rawset(_G, "IsShiftKeyDown", function() return shift end)

-- The action button template: an id, a hotkey text, the icon and the art a wide key stretches.
local create = CreateFrame
rawset(_G, "CreateFrame", function(kind, name, parent, template)
	local f = create(kind, name, parent, template)
	if template == "ActionBarButtonTemplate" then
		rawset(f, "SetID", function(s, id) s.__id = id end)
		rawset(f, "GetID", function(s) return s.__id or 0 end)
		local hk = M.newObj("FontString", nil, f)
		rawset(hk, "SetText", function(s, t) s.__text = t end)
		rawset(f, "HotKey", hk)
		local icon = M.newObj("Texture", nil, f)
		rawset(icon, "SetTexCoord", function(s2, ...) s2.__coord = { ... } end)
		rawset(f, "icon", icon)
		rawset(f, "SetIgnoreParentAlpha", function(s, v) s.__ignoreParentAlpha = v end)
		rawset(f, "RegisterForClicks", function(s, ...) s.__clicks = { ... } end)
		-- the art, each part at the size the template leaves it (ActionButtonTemplate.xml): the frame 51 x 51 after the
		-- template's own UpdateButtonArt for a lone button (the AddRow one, with the slot background up and the slot art
		-- down), the glows 46 x 45, the icon mask at a made-up atlas size of 58
		for k, s in pairs({ NormalTexture = { 51, 51 }, PushedTexture = { 51, 51 }, HighlightTexture = { 46, 45 },
			CheckedTexture = { 46, 45 }, Flash = { 46, 45 }, Border = { 46, 45 }, NewActionTexture = { 46, 45 },
			SpellHighlightTexture = { 46, 45 }, IconMask = { 58, 58 }, SlotArt = { 45, 45 }, SlotBackground = { 45, 45 } }) do
			local t = M.newObj("Texture", nil, f)
			t.__w, t.__h = s[1], s[2]
			rawset(t, "GetSize", function(s2) return s2.__w, s2.__h end)
			rawset(f, k, t)
		end
		f.SlotArt.__shown = false
		for _, k in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture" }) do
			rawset(f, "Get" .. k, function(s) return rawget(s, k) end)
		end
		f.__normalAtlas, f.__pushedAtlas = "UI-HUD-ActionBar-IconFrame-AddRow", "UI-HUD-ActionBar-IconFrame-AddRow-Down"
		rawset(f, "SetNormalAtlas", function(s, a) s.__normalAtlas = a end)
		rawset(f, "SetPushedAtlas", function(s, a) s.__pushedAtlas = a end)
		rawset(f, "cooldown", M.newObj("Cooldown", nil, f))
	end
	-- a moved frame: GetPoint gives where it was dropped
	if kind == "Frame" and name and name:match("^WackyBars") then
		rawset(f, "StartMoving", function() end)
		rawset(f, "StopMovingOrSizing", function(s) s.__points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 300, 400 } } end)
		rawset(f, "SetIgnoreParentAlpha", function(s, v) s.__ignoreParentAlpha = v end)
	end
	return f
end)
for _, n in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }) do
	M.newObj("Frame", n)
end

WackyBarsCharDB = { v = 2 } -- (every bar on, the Shift, Ctrl and Alt copies too; the first load is checked in first_load_test)
dofile(HERE .. "/tests/fake_lab.lua")(M)
local ok, err = dofile(HERE .. "/tests/load_wackybars.lua")(M, HERE) -- (WackyBars.lua and the feature files after it)
check("loads", ok)
if not ok then out(err) os.exit(1) end
M.fire("ADDON_LOADED", "WackyBars")
M.fire("PLAYER_ENTERING_WORLD")
M.flushTimers()
check("no errors at login", #M.errors == 0)
for _, e in ipairs(M.errors) do out(e) end

local DB = WackyBarsCharDB
local function attr(n, a) return _G[n].__attrs[a] end
local function x(n) local p = _G[n].__points[#_G[n].__points]; return p and p[4] end
check("Q shows Action Bar 1 button 1, paged: every page held (page 2: slot 13), on page 1 now", attr("WackyBarsPlainQ", "action") == 1
	and attr("WackyBarsPlainQ", "labaction-2") == 13 and attr("WackyBarsPlainQ", "labaction-7") == 73
	and attr("WackyBarsPlainQ", "state") == "1")
check("1 shows slot 67 (bar 2 button 7) in state 0", attr("WackyBarsPlain1", "action") == 67 and attr("WackyBarsPlain1", "state") == "0")
check("buttons honour self cast, focus cast and Mouseover Cast like the game's", attr("WackyBarsPlainQ", "checkmouseovercast") == true
	and attr("WackyBarsPlainQ", "checkselfcast") == true and attr("WackyBarsPlainQ", "checkfocuscast") == true)
check("buttons are the library's (Bartender's), dragging follows Lock Action Bars", _G.WackyBarsPlainQ.config
	and _G.WackyBarsPlainQ.config.keyBoundClickButton == "Keybind" and attr("WackyBarsPlainQ", "buttonlock") ~= nil)
check("Shift + Q shows slot 25, Ctrl + Q slot 158", attr("WackyBarsShiftQ", "action") == 25 and attr("WackyBarsCtrlQ", "action") == 158)
check("free 2 gets spare slot 14 (13 holds something), Y one too", DB.spare.Plain2 == 14
	and DB.spare.PlainY and attr("WackyBarsPlainY", "action") == DB.spare.PlainY)
check("free Y is bound to its button (override)", overrides.Y and overrides.Y.click == "WackyBarsPlainY")
check("Caps is the \\ key: LockMenu on \\ keeps its key, the button gets a spare slot", overrides["\\"] == nil
	and DB.spare.PlainCaps ~= nil and _G.WackyBarsPlainCaps.wb.def == "\\")
check("CAPSLOCK itself is not read (Linux never sends it)", attr("WackyBarsPlainCaps", "action") ~= 45)
check("Shift + Caps is SHIFT-\\ (free: a spare slot when there are enough)", _G.WackyBarsShiftCaps.wb.def == "SHIFT-\\"
	and _G.WackyBarsShiftCaps.wb.kind == "free")
check("Caps shows no key", _G.WackyBarsPlainCaps.HotKey.__text == "*")
check("untouched game keys get no override", overrides.Q == nil and overrides["SHIFT-Q"] == nil and overrides["1"] == nil)
check("Shift + Q is labelled Q on the Shift bar", _G.WackyBarsShiftQ.HotKey.__text == "Q")
local spares, dup = {}, false
for _, s in pairs(DB.spare) do
	if spares[s] or actions[s] or (s > 24 and s < 73) or s > 120 then dup = true end
	spares[s] = true
end
check("spare slots: no repeats, never a slot in use, only 13-24 and 73-120", not dup)
-- you drop a spell onto free Y: its slot stays Y's from then on
local ySlot = DB.spare.PlainY
actions[ySlot] = true
SlashCmdList.WACKYBARS("status")
check("a filled spare slot stays with its button", DB.spare.PlainY == ySlot and attr("WackyBarsPlainY", "action") == ySlot)

-- Movement keys: arrows from Key Bindings.
local function arrowShown(n) return _G[n].wb.arrowTex.__shown end
check("E S D F (your binds) show arrows, no buttons", arrowShown("WackyBarsPlainE") and arrowShown("WackyBarsPlainF")
	and not _G.WackyBarsPlainE.__shown and DB.spare.PlainE == nil)
check("W is a button (fires Action Bar 1 button 2), no arrow", _G.WackyBarsPlainW.__shown and not arrowShown("WackyBarsPlainW"))
check("Ctrl + E set to NONE does nothing, so no arrow: a free button", not arrowShown("WackyBarsCtrlE")
	and _G.WackyBarsCtrlE.wb.kind == "free")
check("spare slots go to the plain bars first (Ctrl + E got none: every copy is on here)", DB.spare.CtrlE == nil
	and DB.spare.MouseHyperSide2 ~= nil)
check("Ctrl + F (nothing bound) moves you like F, so an arrow", arrowShown("WackyBarsCtrlF"))
check("Ctrl + S (Toggle Sound) shows S's left arrow", arrowShown("WackyBarsCtrlS"))
check("Shift + E is bound to a spell: a button, not an arrow", _G.WackyBarsShiftE.__shown and attr("WackyBarsShiftE", "action") == 51
	and not arrowShown("WackyBarsShiftE"))

-- The mouse bars.
check("mouse side 5 (F5) shows slot 26", attr("WackyBarsMousePlainSide5", "action") == 26)
check("mouse side 1 (F1) shows slot 27, labelled 1", attr("WackyBarsMousePlainSide1", "action") == 27
	and _G.WackyBarsMousePlainSide1.HotKey.__text == "1")
check("free mouse side 2 gets a spare slot", DB.spare.MousePlainSide2 ~= nil)
check("out of spare slots: the last free keys (the Alt mouse bar) hide", DB.spare.MouseAltSide12 == nil
	and not _G.WackyBarsMouseAltSide12.__shown)
local allTucked = true
for _, n in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5",
	"MultiBar6", "MultiBar7" }) do
	if _G[n]:GetParent() == UIParent then allTucked = false end
end
check("all eight game bars tucked away (also ones holding more than shows here)", allTucked)
check("no pet keys: the pet bar stays the game's", _G.PetActionBar == nil or _G.PetActionBar:GetParent() == UIParent)

-- Hypershift: your items, Numpad on the side buttons, its own bar straight off the screen (QuietHUD fades it with Bar 8).
check("Hypershift side 1 (Numpad 1) shows slot 178 (Bar 8 button 10), labelled 1", attr("WackyBarsMouseHyperSide1", "action") == 178
	and _G.WackyBarsMouseHyperSide1.HotKey.__text == "1")
check("Hypershift side 12 is Numpad +", _G.WackyBarsMouseHyperSide12.wb.def == "NUMPADPLUS")
check("QuietHUD: each bar sits in the holder of its main game bar (keyboard: Bar 1, thumbs: Bar 4, Hypershift: Bar 8)",
	_G.WackyBarsPlainQ.__parent == _G.WackyBarsHoldPlain1 and _G.WackyBarsMousePlainSide1.__parent == _G.WackyBarsHoldMousePlain4
	and _G.WackyBarsMouseHyperSide1.__parent == _G.WackyBarsHoldMouseHyper8)
check("a whole bar goes with its most common game bar: 1 (on Bar 2) and free Y stay with the keyboard's Bar 1",
	_G.WackyBarsPlain1.__parent == _G.WackyBarsHoldPlain1 and _G.WackyBarsPlainY.__parent == _G.WackyBarsHoldPlain1
	and _G.WackyBarsMouseHyperEdge1.__parent == _G.WackyBarsHoldMouseHyper8 and #_G.WackyBarsHoldPlain2.qhudButtons == 0)
local inList = false
for _, b in ipairs(_G.WackyBarsHoldPlain1.qhudButtons) do if b == _G.WackyBarsPlainQ then inList = true end end
check("the holder lists its buttons for QuietHUD (mouse over, hotkeys, names)", inList)
check("the Alt keyboard follows Action Bar 1, the Alt mouse the same bar as the mouse (Bar 4 here)", _G.WackyBarsAltQ.__parent == _G.WackyBarsHoldAlt1
	and _G.WackyBarsMouseAltSide1.__parent == _G.WackyBarsHoldMouseAlt4)
check("a free key presses its button the library's way (key down casting works)", overrides.Y and overrides.Y.how == "Keybind")
check("one Hypershift bar, no Shift copy", _G.WackyBarsMouseHyperShift == nil)

-- The wheel: Shift + wheel on the two keys after V; the plain wheel is the camera (no button).
check("Shift + wheel up (after V) shows slot 66, labelled sWU", attr("WackyBarsPlainWheelUp", "action") == 66
	and _G.WackyBarsPlainWheelUp.HotKey.__text == "sWU" and _G.WackyBarsPlainWheelUp.wb.def == "SHIFT-MOUSEWHEELUP")
check("Shift + wheel down is the other one", _G.WackyBarsPlainWheelDown.wb.def == "SHIFT-MOUSEWHEELDOWN")
check("no plain wheel button; not on the Shift bar twice", overrides.MOUSEWHEELUP == nil
	and _G.WackyBarsShiftWheelUp == nil and _G.WackyBarsMousePlainWheelUp == nil)
check("middle on the plain mouse bar; Shift / Ctrl + middle on their copies, not beside it", _G.WackyBarsMousePlainWheel.wb.def == "BUTTON3"
	and _G.WackyBarsMousePlainShiftWheel == nil and _G.WackyBarsMousePlainCtrlWheel == nil
	and _G.WackyBarsMouseShiftWheel.wb.def == "SHIFT-BUTTON3" and _G.WackyBarsMouseCtrlWheel.wb.def == "CTRL-BUTTON3")
check("the Alt mouse bar has E1, E2 and middle with Alt", _G.WackyBarsMouseAltEdge1.wb.def == "ALT-NUMPADMULTIPLY"
	and _G.WackyBarsMouseAltEdge2.wb.def == "ALT-NUMPADDIVIDE" and _G.WackyBarsMouseAltWheel.wb.def == "ALT-BUTTON3")
check("Hypershift has E1, E2 and middle, blank (you give them their keys)", _G.WackyBarsMouseHyperEdge1.wb.def == nil
	and _G.WackyBarsMouseHyperEdge2.wb.def == nil and _G.WackyBarsMouseHyperWheel.wb.def == nil
	and DB.spare.MouseHyperEdge1 ~= nil)
check("blank buttons after V on Shift and Ctrl, no key (not B and N); none on Alt", _G.WackyBarsShiftBlank1.wb.def == nil
	and _G.WackyBarsCtrlBlank2.wb.def == nil and _G.WackyBarsAltBlank1 == nil and _G.WackyBarsPlainBlank1 == nil
	and overrides.B == nil and overrides.N == nil and overrides["SHIFT-B"] == nil)

-- Straight rows by default: Q under 1, Caps two wide, left of A; stagger shifts them.
check("straight: Q under 1, A under Q", x("WackyBarsPlainQ") == x("WackyBarsPlain1") and x("WackyBarsPlainA") == x("WackyBarsPlainQ"))
check("Shift blanks sit where the plain bar has Shift + wheel", x("WackyBarsShiftBlank1") == x("WackyBarsShiftG"))
check("Shift + wheel up and down square off the bottom row (under G and H)", x("WackyBarsPlainWheelUp") == x("WackyBarsPlainG")
	and x("WackyBarsPlainWheelDown") == x("WackyBarsPlainH") and _G.WackyBarsPlainB == nil and _G.WackyBarsPlainN == nil)
check("Caps is two buttons wide and ends where A starts", _G.WackyBarsPlainCaps.__w == 2 * 45 + 4
	and x("WackyBarsPlainCaps") + _G.WackyBarsPlainCaps.__w + 4 == x("WackyBarsPlainA"))
local c = _G.WackyBarsPlainCaps.icon.__coord
check("Caps' icon is cropped to the wide shape, not squashed", c and c[3] > 0.2 and c[4] < 0.8)
local caps = _G.WackyBarsPlainCaps
caps.HighlightTexture:SetSize(46, 45) -- (the library puts the mouse over glow back at 46 x 45 on each update)
LibStub("LibActionButton-1.0").callbacks.OnButtonUpdate("OnButtonUpdate", caps)
check("after a library update Caps' glow is two keys wide again", caps.HighlightTexture.__w > 46 * 1.5
	and caps.Border.__w > 46 * 1.5)
do -- the art, laid out like the game's own bar buttons (his "icons are all cropped", "phantom bar behind", "the
	-- highlight is off", Nov 10)
	local w = _G.WackyBarsPlainW
	local function at(t, rel)
		local p = t.__points[1]
		return #t.__points == 1 and p[1] == "TOPLEFT" and p[2] == rel and p[3] == "TOPLEFT" and p[4] == 0 and p[5] == 0
	end
	check("W's frame: Action Bar 1's with its bar art (not the shadowed AddRow), 46 x 45 at its top left", w.__normalAtlas
		== "UI-HUD-ActionBar-IconFrame" and w.__pushedAtlas == "UI-HUD-ActionBar-IconFrame-Down" and at(w.NormalTexture, w)
		and w.NormalTexture.__w == 46 and w.NormalTexture.__h == 45 and at(w.PushedTexture, w) and w.PushedTexture.__w == 46)
	check("W's highlight and checked glow sit exactly on the frame (46 x 45 at its top left)", at(w.HighlightTexture, w)
		and w.HighlightTexture.__w == 46 and w.HighlightTexture.__h == 45 and at(w.CheckedTexture, w)
		and w.CheckedTexture.__w == 46 and w.CheckedTexture.__h == 45)
	check("W's flash, border and spell glows at their own size at its top left", at(w.Flash, w) and w.Flash.__w == 46
		and at(w.Border, w) and at(w.SpellHighlightTexture, w) and at(w.NewActionTexture, w))
	local mp = w.IconMask.__points
	check("W's icon mask keeps the game's size, centred on the icon (shrunk onto the icon it cropped them)", #mp == 1
		and mp[1][1] == "CENTER" and mp[1][2] == w.icon and w.IconMask.__w == 58 and w.IconMask.__h == 58)
	check("W's empty slot: plain dark (as the game's other bars), the bar art's faint wing hidden",
		w.SlotArt.__shown == false and w.SlotBackground.__shown == true)
	local cp = w.cooldown.__points
	check("W's cooldown 3 in from the icon's edges, as the game's", #cp == 2 and cp[1][1] == "TOPLEFT" and cp[1][2] == w.icon
		and cp[1][4] == 3 and cp[1][5] == -3 and cp[2][1] == "BOTTOMRIGHT" and cp[2][4] == -3 and cp[2][5] == 3)
	local k = caps.__w / 45
	check("Caps (two keys wide): frame, glow and mask stretch with it", math.abs(caps.NormalTexture.__w - 46 * k) < 0.01
		and caps.NormalTexture.__h == 45 and math.abs(caps.HighlightTexture.__w - 46 * k) < 0.01
		and math.abs(caps.IconMask.__w - 58 * k) < 0.01 and caps.IconMask.__h == 58)
	local e1 = _G.WackyBarsMousePlainEdge1
	check("E1 (75%): frame and mask at 75% of the game's", math.abs(e1.NormalTexture.__w - 46 * 0.75) < 0.01
		and math.abs(e1.NormalTexture.__h - 45 * 0.75) < 0.01 and math.abs(e1.IconMask.__w - 58 * 0.75) < 0.01)
	-- the library's update puts its lone-button frame (the one with the shadow) back and hides the slot of a filled button
	w:SetNormalAtlas("UI-HUD-ActionBar-IconFrame-AddRow")
	w.NormalTexture:SetSize(51, 51)
	w.SlotBackground:Hide()
	LibStub("LibActionButton-1.0").callbacks.OnButtonUpdate("OnButtonUpdate", w)
	check("after a library update W has the game's bar frame back (no shadow box) and its slot", w.__normalAtlas
		== "UI-HUD-ActionBar-IconFrame" and w.NormalTexture.__w == 46 and w.SlotBackground.__shown == true
		and at(w.NormalTexture, w))
	-- Bar art in /wbars: the game's faint wing in empty buttons instead of the plain dark slot
	SlashCmdList.WACKYBARS("")
	local box
	for _, f in ipairs(M.frames) do
		if f.__text == "Bar art (the faint wing in empty buttons)" and f.__points[1] then box = f.__points[1][2] end
	end
	if box and box.__scripts.OnClick then box.__scripts.OnClick(box) end
	check("Bar art ticked in /wbars: the faint wing shows in W's slot, the plain slot hidden", box ~= nil
		and DB.barArt == true and w.SlotArt.__shown == true and w.SlotBackground.__shown == false)
	if box and box.__scripts.OnClick then box.__scripts.OnClick(box) end
	check("... unticked: the plain dark slot again", DB.barArt == nil and w.SlotArt.__shown == false
		and w.SlotBackground.__shown == true)
	SlashCmdList.WACKYBARS("")
end
SlashCmdList.WACKYBARS("stagger")
check("stagger: Q half a key right of 1", x("WackyBarsPlainQ") > x("WackyBarsPlain1") and DB.stagger == true)
check("stagger: Caps still ends where A starts", math.abs(x("WackyBarsPlainCaps") + _G.WackyBarsPlainCaps.__w + 4 - x("WackyBarsPlainA")) < 0.01)
local function y(n) local p = _G[n].__points[#_G[n].__points]; return p and p[5] end
check("mouse: middle full size above side 2, E1 over E2 left of the grid",
	x("WackyBarsMousePlainWheel") == x("WackyBarsMousePlainSide2") and _G.WackyBarsMousePlainWheel.__w == 45
	and y("WackyBarsMousePlainWheel") == y("WackyBarsMousePlainSide2") + 45 + 4
	and x("WackyBarsMousePlainEdge1") == x("WackyBarsMousePlainEdge2") and x("WackyBarsMousePlainEdge1") < x("WackyBarsMousePlainSide1")
	and y("WackyBarsMousePlainEdge1") > y("WackyBarsMousePlainEdge2"))
check("E1 and E2 are 75%", _G.WackyBarsMousePlainEdge1.__w == 45 * 0.75)
check("E1 sits one gap (4) left of the grid", math.abs(x("WackyBarsMousePlainSide1") - (x("WackyBarsMousePlainEdge1")
	+ _G.WackyBarsMousePlainEdge1.__w) - 4) < 0.01)
check("E1 level with side 1's row, E2 with side 4's", y("WackyBarsMousePlainEdge1") > y("WackyBarsMousePlainEdge2")
	and math.abs(y("WackyBarsMousePlainEdge1") - (y("WackyBarsMousePlainSide1") - (45 - 45 * 0.75) / 2)) < 0.01)
check("E1 (on top) is Numpad *, E2 is Numpad /", _G.WackyBarsMousePlainEdge1.wb.def == "NUMPADMULTIPLY"
	and _G.WackyBarsMousePlainEdge2.wb.def == "NUMPADDIVIDE")
check("stagger leaves the mouse grid alone", x("WackyBarsMousePlainSide4") == x("WackyBarsMousePlainSide1"))
SlashCmdList.WACKYBARS("stagger")
check("stagger again: straight", x("WackyBarsPlainQ") == x("WackyBarsPlain1") and DB.stagger == nil)

-- First places: the copies in the middle of the screen, a little apart, so none is pushed onto another (Reset places).
local dp = {}
for _, n in ipairs({ "MouseShift", "MouseCtrl", "MouseAlt", "Shift" }) do
	local p = _G["WackyBars" .. n].__points[1]
	dp[n] = p
end
check("copies start mid screen: Alt mouse right of the middle, below and right of Ctrl", dp.MouseAlt[4] > dp.MouseCtrl[4]
	and dp.MouseAlt[5] < dp.MouseCtrl[5] and dp.MouseShift[4] >= 10 and dp.Shift[4] < 0)

-- Quick edit: hover Shift + Q, press T.
local edit = _G.WackyBarsEdit
_G.WackyBars_ToggleEdit()
check("edit shows the buttons at full whatever QuietHUD says", _G.WackyBarsPlainQ.__ignoreParentAlpha == true)
check("... and the movement arrows (on the bar, not the faded holder)", _G.WackyBarsPlainE.wb.arrowTex.__parent == _G.WackyBarsPlain)
rawset(_G.WackyBarsShiftQ, "IsMouseOver", function() return true end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnKeyDown(edit, "T")
check("T now does Shift + Q's job (game command, so paging works)", overrides.T and overrides.T.cmd == "MULTIACTIONBAR3BUTTON1")
check("Shift + Q does nothing now", overrides["SHIFT-Q"] and overrides["SHIFT-Q"].click == "WackyBarsNone")
check("T's own button lost its key", DB.keys.PlainT == false and _G.WackyBarsPlainT.HotKey.__text == "*")
check("Shift + Q's button shows T", _G.WackyBarsShiftQ.HotKey.__text == "T")
shift = true
edit.__scripts.OnKeyDown(edit, "LSHIFT")
check("a bare modifier does nothing", DB.keys.ShiftQ == "T")
edit.__scripts.OnKeyDown(edit, "H")
shift = false
check("Shift + H works as a new key; T is free again", DB.keys.ShiftQ == "SHIFT-H" and overrides["SHIFT-H"].cmd == "MULTIACTIONBAR3BUTTON1")
check("T stays off (its button was cleared)", overrides.T and overrides.T.click == "WackyBarsNone")
edit.__scripts.OnKeyDown(edit, "ESCAPE")
check("Esc on a key clears it", DB.keys.ShiftQ == false and overrides["SHIFT-H"] == nil)
edit.__scripts.OnKeyDown(edit, "Q")
check("plain Q onto Shift + Q's button moves Q off the plain bar", DB.keys.PlainQ == false and overrides.Q.cmd == "MULTIACTIONBAR3BUTTON1")
rawset(_G.WackyBarsShiftQ, "IsMouseOver", function() return false end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnKeyDown(edit, "ESCAPE")
check("Esc with nothing hovered finishes", not edit:IsShown() and _G.WackyBarsPlainQ.__ignoreParentAlpha == false)
check("the arrows go back into the bar's holder (they fade with it)", _G.WackyBarsPlainE.wb.arrowTex.__parent == _G.WackyBarsHoldPlain1)

-- A key that moves you is refused in edit (it would stop moving you).
_G.WackyBars_ToggleEdit()
rawset(_G.WackyBarsPlainY, "IsMouseOver", function() return true end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnKeyDown(edit, "E")
check("Edit keys refuses E (it moves you)", DB.keys.PlainY == nil and overrides.E == nil)
rawset(_G.WackyBarsPlainY, "IsMouseOver", function() return false end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnKeyDown(edit, "ESCAPE")

-- A free button gets another key in edit (Ctrl + B), and loses it with Esc.
_G.WackyBars_ToggleEdit()
rawset(_G.WackyBarsPlain2, "IsMouseOver", function() return true end)
edit.__scripts.OnUpdate(edit)
rawset(_G, "IsControlKeyDown", function() return true end)
edit.__scripts.OnKeyDown(edit, "B")
rawset(_G, "IsControlKeyDown", function() return false end)
check("free 2's button given Ctrl + B fires on it", overrides["CTRL-B"] and overrides["CTRL-B"].click == "WackyBarsPlain2"
	and _G.WackyBarsPlain2.HotKey.__text == "CTRL-B" and overrides["2"] == nil)
edit.__scripts.OnKeyDown(edit, "ESCAPE")
check("Esc takes its key off", overrides["CTRL-B"] == nil and DB.keys.Plain2 == false)
rawset(_G.WackyBarsPlain2, "IsMouseOver", function() return false end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnKeyDown(edit, "ESCAPE")

-- Hide one button: right-click it in edit.
_G.WackyBars_ToggleEdit()
rawset(_G.WackyBarsPlainY, "IsMouseOver", function() return true end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnMouseDown(edit, "RightButton")
check("right-click hides Y: faint while editing, its key off", DB.hidden.PlainY and _G.WackyBarsPlainY.__shown
	and _G.WackyBarsPlainY.__alpha < 1 and overrides.Y == nil)
rawset(_G.WackyBarsPlainY, "IsMouseOver", function() return false end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnKeyDown(edit, "ESCAPE")
check("after editing, the hidden button is gone", not _G.WackyBarsPlainY.__shown)
_G.WackyBars_ToggleEdit()
rawset(_G.WackyBarsPlainY, "IsMouseOver", function() return true end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnMouseDown(edit, "RightButton")
rawset(_G.WackyBarsPlainY, "IsMouseOver", function() return false end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnKeyDown(edit, "ESCAPE")
check("right-click again brings it back, key and all", not DB.hidden.PlainY and _G.WackyBarsPlainY.__shown
	and _G.WackyBarsPlainY.__alpha == 1 and overrides.Y ~= nil)

-- Move mode: drag a bar, its place is kept.
_G.WackyBars_ToggleMove()
check("move mode is on", _G.WackyBarsMove:IsShown())
local mover
for _, f in ipairs(M.frames) do
	if f.__parent == _G.WackyBarsMove and f.__scripts.OnDragStop then
		mover = mover or f
	end
end
DB.noSnap = true
mover.__scripts.OnDragStart(mover)
mover.__scripts.OnDragStop(mover)
check("snap off: the dragged bar's place is kept as dropped", DB.pos.Plain and DB.pos.Plain[3] == 300 and DB.pos.Plain[4] == 400)
DB.noSnap = nil
-- the game's Edit Mode rules: only within 8 pixels; the screen and grid both ways; a bar only edge to edge and only one it
-- overlaps, then only the nearer way; a corner beats everything
UIParent.__w = 1820
local function rect(f, l, b, w, h) rawset(f, "GetRect", function() return l, b, w, h end) end
for _, n in ipairs({ "WackyBarsShift", "WackyBarsCtrl", "WackyBarsAlt", "WackyBarsMousePlain", "WackyBarsMouseShift",
	"WackyBarsMouseCtrl", "WackyBarsMouseAlt", "WackyBarsMouseHyper" }) do rect(_G[n], 5000, 5000, 10, 10) end
rect(_G.WackyBarsPlain, 133, 377, 300, 100)
mover.__scripts.OnDragStart(mover)
check("while dragging, the snap lines follow (only then)", mover.__scripts.OnUpdate ~= nil)
mover.__scripts.OnUpdate(mover)
local shownLines = 0
for _, f in ipairs(M.frames) do
	local pt = f.__parent == _G.WackyBarsMove and f.__kind == "CreateTexture" and f.__shown and f.__points[1]
	if pt and (pt[1] == "BOTTOM" or pt[1] == "LEFT") then shownLines = shownLines + 1 end
end
check("two snap lines show (grid both ways)", shownLines == 2)
mover.__scripts.OnDragStop(mover)
check("dropped: no more lines, nothing runs", mover.__scripts.OnUpdate == nil)
local pl = DB.pos.Plain
check("snap: the right side goes to the grid line 3 away, the top to the one 5 away", pl and pl[1] == "TOPLEFT"
	and pl[3] == 130 and pl[4] == 472)
rect(_G.WackyBarsShift, 140, 800, 300, 100)
rect(_G.WackyBarsPlain, 136, 377, 300, 100)
mover.__scripts.OnDragStart(mover)
mover.__scripts.OnDragStop(mover)
check("a bar far above with almost the same left side: no lining up with it (grid instead)", DB.pos.Plain[3] == 130)
rect(_G.WackyBarsShift, 440, 400, 300, 100)
rect(_G.WackyBarsPlain, 136, 377, 300, 100)
mover.__scripts.OnDragStart(mover)
mover.__scripts.OnDragStop(mover)
check("beside the Shift bar, 4 away: right side to its left side, the top stays as dropped", DB.pos.Plain[3] == 140
	and DB.pos.Plain[4] == 477)
rect(_G.WackyBarsShift, 440, 380, 300, 100)
rect(_G.WackyBarsPlain, 136, 377, 300, 100)
mover.__scripts.OnDragStart(mover)
mover.__scripts.OnDragStop(mover)
check("corner: bottom right onto its bottom left, both ways", DB.pos.Plain[3] == 140 and DB.pos.Plain[4] == 480)
rect(_G.WackyBarsShift, 5000, 5000, 10, 10)
check("dragging selects the bar (gold)", mover.bg and true)
rect(_G.WackyBarsPlain, 140, 372, 300, 100)
_G.WackyBarsMove.__scripts.OnKeyDown(_G.WackyBarsMove, "UP")
check("arrow up nudges the selected bar 1 pixel", DB.pos.Plain[3] == 140 and DB.pos.Plain[4] == 473)
shift = true
_G.WackyBarsMove.__scripts.OnKeyDown(_G.WackyBarsMove, "LEFT")
shift = false
check("Shift + arrow left: 10 pixels", DB.pos.Plain[3] == 130)
-- Size, each bar its own: picking a bar shows the slider; the top left corner stays.
check("the picked bar's size slider shows", _G.WackyBarsSize:IsShown())
rect(_G.WackyBarsPlain, 130, 372, 300, 100)
_G.WackyBarsSizeSlider.__scripts.OnValueChanged(_G.WackyBarsSizeSlider, 1.23)
check("size 1.25 (steps of 5) for the keyboard only, its top left kept", DB.sizes.Plain == 1.25 and DB.sizes.MousePlain == nil
	and _G.WackyBarsPlain.__scale == 1.25 and math.abs(DB.pos.Plain[3] * 1.25 - 130) < 0.01
	and math.abs(DB.pos.Plain[4] * 1.25 - 472) < 0.01)
_G.WackyBarsSizeSlider.__scripts.OnValueChanged(_G.WackyBarsSizeSlider, 1)
check("back to 100%: no size kept", DB.sizes.Plain == nil)
DB.pos.MousePlain = nil
rect(_G.WackyBarsMousePlain, 700, 300, 200, 250)
_G.WackyBarsMoveMousePlain.__scripts.OnMouseDown(_G.WackyBarsMoveMousePlain)
_G.WackyBarsSizeSlider.__scripts.OnValueChanged(_G.WackyBarsSizeSlider, 1.5)
check("sizing a bar never moved keeps its top left too (it slid before)", DB.pos.MousePlain
	and math.abs(DB.pos.MousePlain[3] * 1.5 - 700) < 0.01 and math.abs(DB.pos.MousePlain[4] * 1.5 - 550) < 0.01)
_G.WackyBarsSizeSlider.__scripts.OnValueChanged(_G.WackyBarsSizeSlider, 1)
_G.WackyBarsMovePlain.__scripts.OnMouseDown(_G.WackyBarsMovePlain)
local lines = 0
for _, f in ipairs(M.frames) do if f.__parent == _G.WackyBarsMove and f.__kind == "CreateTexture" and f.__shown then lines = lines + 1 end end
check("move mode draws the grid", lines > 10)
-- Esc in the middle of a drag: the bar stops and keeps its place, the lines go.
rect(_G.WackyBarsPlain, 150, 380, 300, 100)
mover.__scripts.OnDragStart(mover)
local stopped = false
rawset(_G.WackyBarsPlain, "StopMovingOrSizing", function(s) stopped = true; s.__points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 222, 333 } } end)
_G.WackyBarsMove.__scripts.OnKeyDown(_G.WackyBarsMove, "ESCAPE")
check("Esc finishes moving", not _G.WackyBarsMove:IsShown())
check("Esc mid drag: the bar stops, keeps where it was, no drag work left", stopped and DB.pos.Plain[3] == 222
	and mover.__scripts.OnUpdate == nil)
mover.__scripts.OnDragStop(mover) -- (the late drop from the hidden box does nothing)
check("a late drop afterwards changes nothing", DB.pos.Plain[3] == 222)
-- A bar switched on while Move bars is open gets its box.
DB.off.MouseAlt = true
SlashCmdList.WACKYBARS("status")
_G.WackyBars_ToggleMove()
local altBox = _G.WackyBarsMoveMouseAlt
check("an off bar has no box", not altBox.__shown)
DB.off.MouseAlt = nil
SlashCmdList.WACKYBARS("status")
check("switched on while moving: its box shows", altBox.__shown)
_G.WackyBarsMove.__scripts.OnKeyDown(_G.WackyBarsMove, "ESCAPE")
-- the game's Edit Mode brings the boxes up and takes them away
local em = _G.EditModeManagerFrame
check("hooked into the game's Edit Mode", em.__scripts.OnShow ~= nil)
em.__scripts.OnShow(em)
check("opening Edit Mode shows WackyBars' boxes", _G.WackyBarsMove:IsShown())
em.__scripts.OnHide(em)
check("closing it takes them away", not _G.WackyBarsMove:IsShown())

-- Options: switch the Ctrl bar off.
SlashCmdList.WACKYBARS("")
check("/wbars opens the options window", _G.WackyBarsOptions and _G.WackyBarsOptions:IsShown())
DB.keys = {}
DB.off.Ctrl = true
SlashCmdList.WACKYBARS("status")
check("an off bar hides and sets no keys", not _G.WackyBarsCtrl:IsShown() and overrides["CTRL-Y"] == nil)
check("... and its buttons are emptied (left out of the library's passes)", _G.WackyBarsCtrlQ:GetAction("0") == "empty"
	and _G.WackyBarsCtrlQ:GetAttribute("state") == "0" and not _G.WackyBarsCtrlQ.__shown)
check("game bars stay tucked while another WackyBars bar shows", _G.MultiBar6:GetParent() ~= UIParent)
DB.off.Ctrl = nil
DB.off.Shift = true
SlashCmdList.WACKYBARS("status")
check("a bar switched off gives its empty spare slots to the others", DB.spare.Ctrl1 ~= nil
	and DB.spare.ShiftY == nil)
DB.off.Shift = nil

-- The options: a box per bar (keyboard and mouse side by side, a row per modifier), Hypershift under them; one page (the
-- Alt boxes went to QuietHUD's Show with Alt column, Nov 10).
local boxes = {}
for _, f in ipairs(M.frames) do
	if f.__parent == _G.WackyBarsOptions and f.__template == "UICheckButtonTemplate" then boxes[#boxes + 1] = f end
end
local shiftBox = boxes[3] -- (Plain keyboard, Plain mouse, Shift keyboard, ...)
shiftBox.__scripts.OnClick(shiftBox)
check("the Shift keyboard box switches that bar off", DB.off.Shift and not _G.WackyBarsShift:IsShown())
shiftBox.__scripts.OnClick(shiftBox)
check("and on again", not DB.off.Shift and _G.WackyBarsShift:IsShown())
check("no Alt boxes of its own any more (QuietHUD's Show with Alt column)", DB.noPeek == nil
	and _G.WackyBarsHoldPlain1.qhudNoPeek == nil)
check("no mouse over or fight settings of its own (QuietHUD's job)", DB.mouseover == nil and DB.combatHide == nil
	and _G.WackyBarsPlain.__alpha ~= 0)
-- Every bar off: the game's bars are back.
for _, bar in ipairs({ "Plain", "Shift", "Ctrl", "Alt", "MousePlain", "MouseShift", "MouseCtrl", "MouseAlt", "MouseHyper" }) do
	DB.off[bar] = true
end
SlashCmdList.WACKYBARS("status")
check("every WackyBars bar off: the game's bars come back", _G.MainActionBar:GetParent() == UIParent
	and _G.MultiBar7:GetParent() == UIParent)
DB.off = {}
SlashCmdList.WACKYBARS("status")

-- The edge buttons and the wheel click off (two boxes): gone from every bar, no key, the mouse bar closes up.
local h0 = _G.WackyBarsMousePlain.__h
DB.noEdges, DB.noWheel = true, true
SlashCmdList.WACKYBARS("status")
check("edges and wheel click off: hidden, no keys, no spare slots", not _G.WackyBarsMousePlainEdge1.__shown
	and not _G.WackyBarsMouseShiftWheel.__shown and overrides.NUMPADMULTIPLY == nil and DB.spare.MouseHyperEdge1 == nil)
check("the mouse bar closes up (one row less, no column on the left)", _G.WackyBarsMousePlain.__h < h0
	and x("WackyBarsMousePlainSide1") == 0)
DB.noEdges, DB.noWheel = nil, nil
SlashCmdList.WACKYBARS("status")
check("back on: they come back", _G.WackyBarsMousePlainWheel.__shown and _G.WackyBarsMousePlain.__h == h0)

-- Labels with their modifier (a box, off by default).
check("by default the Shift bar reads E (no s)", _G.WackyBarsShiftE.HotKey.__text == "E")
DB.mods = true
SlashCmdList.WACKYBARS("status")
check("with the box: sE on Shift, cQ on Ctrl, h1 on Hypershift, W stays W", _G.WackyBarsShiftE.HotKey.__text == "sE"
	and _G.WackyBarsCtrlQ.HotKey.__text == "cQ"
	and _G.WackyBarsMouseHyperSide1.HotKey.__text == "h1" and _G.WackyBarsPlainW.HotKey.__text == "W"
	and _G.WackyBarsPlainWheelUp.HotKey.__text == "sWU")
DB.mods = nil
SlashCmdList.WACKYBARS("status")

-- A key given to a button leaves a button on a bar that is off too (switching that bar on must not take it back).
DB.keys.ShiftQ = "CTRL-J"
DB.off.Shift = true
SlashCmdList.WACKYBARS("status")
_G.WackyBars_ToggleEdit()
rawset(_G.WackyBarsPlain2, "IsMouseOver", function() return true end)
edit.__scripts.OnUpdate(edit)
rawset(_G, "IsControlKeyDown", function() return true end)
edit.__scripts.OnKeyDown(edit, "J")
rawset(_G, "IsControlKeyDown", function() return false end)
rawset(_G.WackyBarsPlain2, "IsMouseOver", function() return false end)
edit.__scripts.OnUpdate(edit)
edit.__scripts.OnKeyDown(edit, "ESCAPE")
DB.off.Shift = nil
SlashCmdList.WACKYBARS("status")
check("Ctrl + J went to 2; the off Shift bar's Q lost it, also once switched on", DB.keys.Plain2 == "CTRL-J"
	and DB.keys.ShiftQ ~= "CTRL-J" and overrides["CTRL-J"] and overrides["CTRL-J"].click == "WackyBarsPlain2")
DB.keys = {}
SlashCmdList.WACKYBARS("status")

-- Combat: nothing changes until it ends.
DB.keys.PlainQ = false
SlashCmdList.WACKYBARS("status")
check("Q cleared: bound to nothing", overrides.Q and overrides.Q.click == "WackyBarsNone")
combat = true
M.fire("PLAYER_REGEN_DISABLED")
SlashCmdList.WACKYBARS("reset")
check("in a fight the keys wait", overrides.Q and overrides.Q.click == "WackyBarsNone")
combat = false
M.fire("PLAYER_REGEN_ENABLED")
check("after the fight the reset is in", overrides.Q == nil and DB.pos.Plain == nil)
DB.pos.Plain = { "TOPLEFT", "BOTTOMLEFT", 100, 400 }
SlashCmdList.WACKYBARS("status")
rect(_G.WackyBarsPlain, 100, 300, 300, 100)
SlashCmdList.WACKYBARS("scale 1.5")
check("/wbars scale sets every bar", DB.sizes.Plain == 1.5 and DB.sizes.MouseHyper == 1.5)
check("... and a placed bar keeps its top left (not moved to the old offsets at the new size)",
	math.abs(DB.pos.Plain[3] * 1.5 - 100) < 0.01 and math.abs(DB.pos.Plain[4] * 1.5 - 400) < 0.01)
DB.pos.Plain = nil
SlashCmdList.WACKYBARS("scale auto")
check("/wbars scale auto: all back", next(DB.sizes) == nil)

-- You bind Y in the game's Key Bindings: it follows. You switch to WASD: the arrows follow.
binds.Y = "MULTIACTIONBAR1BUTTON1"
M.fire("UPDATE_BINDINGS")
check("Y now shows slot 61 and has no override", attr("WackyBarsPlainY", "action") == 61 and overrides.Y == nil)
local aSlot = DB.spare.PlainA
if aSlot then actions[aSlot] = true end -- (a spell sits in A's spare slot, then A becomes strafe left)
binds.E, binds.S, binds.D, binds.F = "", "MOVEBACKWARD", "STRAFERIGHT", ""
binds.W, binds.A = "MOVEFORWARD", "STRAFELEFT"
M.fire("UPDATE_BINDINGS")
check("WASD: W A S D are arrows", arrowShown("WackyBarsPlainW") and arrowShown("WackyBarsPlainA") and arrowShown("WackyBarsPlainS")
	and arrowShown("WackyBarsPlainD"))
check("A had a spell in its spare slot and now moves you: no button, no click override (it strafes)", aSlot ~= nil
	and not _G.WackyBarsPlainA.__shown and (overrides.A == nil or overrides.A.click == nil) and DB.spare.PlainA == aSlot)
DB.moveKeys = "ESDF"
SlashCmdList.WACKYBARS("status")
check("Movement keys set to ESDF in the options: E S D F show arrows whatever the bindings say", arrowShown("WackyBarsPlainE")
	and arrowShown("WackyBarsPlainF") and not arrowShown("WackyBarsPlainW"))
DB.moveKeys = nil
SlashCmdList.WACKYBARS("status")
check("WASD: E and F are buttons again, with spare slots", _G.WackyBarsPlainE.__shown and DB.spare.PlainE ~= nil and not arrowShown("WackyBarsPlainE"))

-- The pet bar: Alt + side 1 and 2 are pet keys in Key Bindings (his Naga, Nov 10). Those two spots on the Alt mouse bar show
-- the game's own pet buttons (they change with the pet), the rest of the bar stays action buttons, the game's pet bar is
-- tucked away; unbound again, everything goes back.
rawset(_G, "hooksecurefunc", function(t, name, fn)
	if type(t) ~= "table" then return end
	local old = t[name]
	rawset(t, name, function(...) if old then old(...) end fn(...) end)
end)
local petBar = M.newObj("Frame", "PetActionBar")
local function petPart(pb, w, h, atlas)
	local t = M.newObj("Texture", nil, pb)
	t.__w, t.__h, t.__atlas = w, h, atlas
	t.__points = { { "TOPLEFT", pb, "TOPLEFT", 0, 0 } }
	rawset(t, "GetSize", function(s2) return s2.__w, s2.__h end)
	rawset(t, "GetNumPoints", function(s2) return #s2.__points end)
	rawset(t, "GetAtlas", function(s2) return s2.__atlas end)
	rawset(t, "SetVertexColor", function(s2, r, g, b) s2.__vc = { r, g, b }; s2.__grad = nil end)
	rawset(t, "GetVertexColor", function(s2) local v = s2.__vc or { 1, 1, 1 }; return v[1], v[2], v[3], 1 end)
	rawset(t, "SetDesaturated", function(s2, v) s2.__desat = v end)
	rawset(t, "IsDesaturated", function(s2) return s2.__desat end)
	rawset(t, "SetGradient", function(s2, o, c0, c1) s2.__grad = { o, c0, c1 } end)
	rawset(t, "GetDrawLayer", function() return "OVERLAY", 0 end)
	return t
end
for n = 1, 10 do
	local c = M.newObj("Frame", "PetActionBarButtonContainer" .. n, petBar)
	local pb = M.newObj("CheckButton", "PetActionButton" .. n, c)
	pb.__w, pb.__h = 30, 30
	rawset(pb, "container", c)
	rawset(pb, "icon", M.newObj("Texture", nil, pb))
	for k, v in pairs({ NormalTexture = { 35, 35, "UI-HUD-ActionBar-IconFrame-AddRow" }, PushedTexture = { 35, 35,
		"UI-HUD-ActionBar-IconFrame-AddRow-Down" }, HighlightTexture = { 31.6, 30.9 }, CheckedTexture = { 31.6, 30.9 },
		Flash = { 31.6, 30.9 }, Border = { 31.6, 30.9 }, NewActionTexture = { 31.6, 30.9 }, SpellHighlightTexture = { 31.6, 30.9 },
		IconMask = { 45, 45 }, SlotArt = { 30, 30 }, SlotBackground = { 30, 30 } }) do
		rawset(pb, k, petPart(pb, v[1], v[2], v[3]))
	end
	pb.IconMask.__points = { { "CENTER", pb.icon, "CENTER", 0, 0 } }
	pb.SlotArt.__shown = false
	pb.NormalTexture:SetVertexColor(0.3, 0.3, 0.3) -- (BetterBlizzFrames' dark on the game's pet bar)
	for _, k in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture" }) do
		rawset(pb, "Get" .. k, function(s2) return rawget(s2, k) end)
	end
	rawset(pb, "SetNormalAtlas", function(s2, a) s2.NormalTexture.__atlas = a end)
	rawset(pb, "SetPushedAtlas", function(s2, a) s2.PushedTexture.__atlas = a end)
	rawset(pb, "SetIgnoreParentAlpha", function(s2, v) s2.__ignoreParentAlpha = v end)
	local hk = M.newObj("FontString", nil, pb)
	rawset(hk, "SetText", function(s, t) s.__text = t end)
	rawset(pb, "HotKey", hk)
	rawset(pb, "SetHotkeys", function(s) s.HotKey:SetText("game") end)
end
binds["ALT-F1"], binds["ALT-F2"] = "BONUSACTIONBUTTON1", "BONUSACTIONBUTTON2"
M.fire("UPDATE_BINDINGS")
local pet1, petSpot = _G.PetActionButton1, _G.WackyBarsMouseAltSide1
check("Alt + side 1 is a pet key: the game's pet button 1 sits in its spot", pet1:GetParent() == _G.WackyBarsPetMouseAlt
	and pet1.__points[#pet1.__points][2] == petSpot and _G.PetActionButton2:GetParent() == _G.WackyBarsPetMouseAlt
	and _G.WackyBarsPetMouseAlt:GetParent() == _G.WackyBarsHoldMouseAlt9)
check("... sized to the spot, labelled like it, WackyBars' own button hidden (one key label), no spare slot",
	math.abs(pet1.__scale * 30 - petSpot:GetHeight()) < 0.01 and pet1.HotKey.__text == "1" and not petSpot.__shown
	and petSpot.wb.slot == nil)
check("... the pet button shows whenever a pet is out, by a rule of its own (his \"i swapped pets now all his abilities are gone\")",
	drivers[pet1] and drivers[pet1].visibility == "[petbattle][vehicleui][overridebar][possessbar] hide; [@pet,exists] show; hide")
-- his pet has nothing in slot 9: the game hides that pet button, the spot keeps its empty slot (his "9 disappeared")
binds["ALT-F9"] = "BONUSACTIONBUTTON9"
M.fire("UPDATE_BINDINGS")
_G.PetActionButton9:Hide() -- (the game: an empty pet slot's button is hidden)
check("a pet key whose pet slot is empty: its pet button shows anyway, as an empty slot, by its rule (his \"9 disappeared\")",
	drivers[_G.PetActionButton9] and drivers[_G.PetActionButton9].visibility == "[petbattle][vehicleui][overridebar][possessbar] hide; [@pet,exists] show; hide")
binds["ALT-F9"] = nil
M.fire("UPDATE_BINDINGS")
pet1:SetHotkeys()
check("... the game's key text is replaced again after a binding change", pet1.HotKey.__text == "1")
check("... no override: the key stays the game's pet key", overrides["ALT-F1"] == nil)
check("... they show only with a pet, not on a vehicle, override or possess bar or in a pet battle",
	drivers[_G.WackyBarsPetMouseAlt] and drivers[_G.WackyBarsPetMouseAlt].visibility
	== "[petbattle][vehicleui][overridebar][possessbar] hide; [@pet,exists] show; hide" and not drivers[_G.WackyBarsHoldMouseAlt9])
check("... and only the bar holding pet buttons runs that check (none on the others)", not (drivers[_G.WackyBarsPetPlain]
	and drivers[_G.WackyBarsPetPlain].visibility) and not (drivers[_G.WackyBarsPetMousePlain]
	and drivers[_G.WackyBarsPetMousePlain].visibility))
do -- the game's pet button takes the frame of the buttons round it, scaled for its own 30 (art review Nov 10)
	local k = 30 / 45
	local nt = pet1.NormalTexture
	local np = nt.__points[#nt.__points]
	local mp = pet1.IconMask.__points[#pet1.IconMask.__points]
	check("... the pet button gets the shadowless frame of its neighbours, 46 x 45 scaled to its 30, at its top left",
		nt.__atlas == "UI-HUD-ActionBar-IconFrame" and math.abs(nt.__w - 46 * k) < 0.01 and math.abs(nt.__h - 30) < 0.01
		and np[1] == "TOPLEFT" and np[2] == pet1 and pet1.PushedTexture.__atlas == "UI-HUD-ActionBar-IconFrame-Down")
	check("... its icon mask the game's 45 size scaled to 30 (from WackyBars' own buttons, not its own 45), on the icon",
		math.abs(pet1.IconMask.__w - 58 * k) < 0.01 and mp[1] == "CENTER" and mp[2] == pet1.icon)
	check("... a plain dark slot like its neighbours (Bar art off)", pet1.SlotBackground.__shown == true and pet1.SlotArt.__shown == false)
end
rawset(_G, "CreateColor", function(r, g, b, a) return { r = r, g = g, b = b, a = a } end)
DB.look = "gradient"
SlashCmdList.WACKYBARS("status")
do
	local g = pet1.NormalTexture.__grad
	local g2 = pet1.PushedTexture.__grad
	-- (the spot's own left and width: the fake frames all sit at 0, so the slice is the whole bar's left end, never a
	-- squashed or negative one from the pet button's scaled units)
	check("Purple to pink: the pet button gets its spot's slice, its pressed frame too", g and g2 and g[2].r >= 0xBD / 255 - 0.01
		and pet1.NormalTexture.__desat == true)
end
do -- (a stand-in Action Bar 1 for this one check, BetterBlizzFrames' dark on it; the look checks below make their own)
	local ab = M.newObj("CheckButton", "ActionButton1")
	ab.__w, ab.__h = 45, 45
	local ref = petPart(ab, 51, 51, "UI-HUD-ActionBar-IconFrame-AddRow")
	ref:SetVertexColor(0.2, 0.2, 0.2)
	rawset(ab, "GetNormalTexture", function() return ref end)
	DB.look = nil
	SlashCmdList.WACKYBARS("status")
	check("Default: the pet button takes Action Bar 1's colour like its neighbours, the gradient gone",
		pet1.NormalTexture.__grad == nil and pet1.NormalTexture.__vc and pet1.NormalTexture.__vc[1] == 0.2)
	rawset(_G, "ActionButton1", nil)
end
-- Edit keys: a pet key's spot shows faint under its pet button, so it can be hovered, given a key or hidden; both at full
SlashCmdList.WACKYBARS("edit")
check("Edit keys: the pet key's spot shows faint and empty (reachable), its pet button at full", petSpot.__shown == true
	and math.abs(petSpot.__alpha - 0.35) < 0.01 and pet1.__ignoreParentAlpha == true)
SlashCmdList.WACKYBARS("edit")
check("... done editing: the spot hidden again, the pet button follows QuietHUD's fade again", petSpot.__shown == false
	and pet1.__ignoreParentAlpha == false)
local inHolder9 = {}
for _, b in ipairs(_G.WackyBarsHoldMouseAlt9.qhudButtons) do inHolder9[b] = true end
check("... the whole Alt mouse bar goes with QuietHUD's Pet bar row (holder 9): the pet buttons and the extra buttons",
	inHolder9[pet1] and inHolder9[_G.WackyBarsMouseAltEdge1] and _G.WackyBarsMouseAltEdge1:GetParent() == _G.WackyBarsHoldMouseAlt9
	and #_G.WackyBarsHoldMouseAlt5.qhudButtons == 0)
check("... the plain mouse bar still goes with its own row", _G.WackyBarsMousePlainSide1:GetParent() ~= _G.WackyBarsHoldMousePlain9)
check("pet slot 3 has no key here: stays in the game's bar", _G.PetActionButton3:GetParent() == _G.PetActionBarButtonContainer3)
check("the other Alt mouse spots stay action buttons", _G.WackyBarsMouseAltSide11.wb.kind ~= "pet" and _G.WackyBarsMouseAltEdge1.wb.kind ~= "pet")
check("the game's pet bar is tucked away", petBar:GetParent() ~= UIParent)
binds["ALT-F1"], binds["ALT-F2"] = nil, nil
M.fire("UPDATE_BINDINGS")
check("pet keys unbound: the pet buttons and the game's pet bar are back", pet1:GetParent() == _G.PetActionBarButtonContainer1
	and pet1.__scale == 1 and pet1.HotKey.__text == "game" and petBar:GetParent() == UIParent)
do
	local nt = pet1.NormalTexture
	check("... the pet button has the game's own art and colour back (frame, mask, slots, BetterBlizzFrames' dark)",
		nt.__atlas == "UI-HUD-ActionBar-IconFrame-AddRow" and nt.__w == 35 and nt.__h == 35 and pet1.IconMask.__w == 45
		and pet1.SlotArt.__shown == false and pet1.SlotBackground.__shown == true and nt.__vc and nt.__vc[1] == 0.3
		and nt.__grad == nil and pet1.PushedTexture.__atlas == "UI-HUD-ActionBar-IconFrame-AddRow-Down")
	check("... and the pet buttons are the game's to show again (their rule gone, nothing left hidden by it)",
		not (drivers[pet1] and drivers[pet1].visibility) and pet1.__attrs.statehidden == nil)
	check("... and no bar runs the pet check any more", not (drivers[_G.WackyBarsPetMouseAlt]
		and drivers[_G.WackyBarsPetMouseAlt].visibility) and _G.WackyBarsPetMouseAlt.__shown == false)
end
check("... and the Alt mouse bar follows the mouse bar's row again", _G.WackyBarsMouseAltEdge1:GetParent() ~= _G.WackyBarsHoldMouseAlt9
	and #_G.WackyBarsHoldMouseAlt9.qhudButtons == 0)

-- The look (Nov 10): Default copies Action Bar 1's tint (BetterBlizzFrames' dark); Purple to pink sets a gradient slice.
rawset(_G, "CreateColor", function(r, g, b, a) return { r = r, g = g, b = b, a = a } end)
local function tex()
	local t = M.newObj("Texture")
	rawset(t, "SetGradient", function(s, o, c0, c1) s.__grad = { o, c0, c1 } end)
	rawset(t, "SetVertexColor", function(s, r, g, b) s.__vc = { r, g, b }; s.__grad = nil end)
	rawset(t, "GetVertexColor", function(s) local v = s.__vc or { 1, 1, 1 }; return v[1], v[2], v[3] end)
	rawset(t, "SetDesaturated", function(s, v) s.__desat = v end)
	rawset(t, "IsDesaturated", function(s) return s.__desat end)
	return t
end
local ab1 = M.newObj("CheckButton", "ActionButton1")
ab1.__w, ab1.__h = 45, 45 -- (his: 45, at Edit Mode's 100% icon size)
local refTex, qTex = tex(), tex()
refTex:SetVertexColor(0.2, 0.2, 0.2)
rawset(ab1, "GetNormalTexture", function() return refTex end)
for _, k in ipairs({ "SlotArt", "SlotBackground" }) do rawset(ab1, k, false) end
rawset(ab1, "GetPushedTexture", function() return nil end)
-- (the other buttons' frames are the fake template's, which keep no colour; Q's records it, below)
for _, v in pairs(_G) do
	if type(v) == "table" and rawget(v, "wb") then
		rawset(v, "GetNormalTexture", function() return nil end)
		rawset(v, "GetPushedTexture", function() return nil end)
		rawset(v, "SlotArt", false)
	end
end
rawset(_G.WackyBarsPlainQ, "GetNormalTexture", function() return qTex end)
-- the minimap ring, darkened by BetterBlizzFrames
local ring = tex()
ring:SetVertexColor(0.2, 0.2, 0.2)
rawset(_G, "MinimapCompassTexture", ring)
check("Default: the minimap ring is left alone", ring.__grad == nil and ring.__vc[1] == 0.2)
local arrowT = _G.WackyBarsPlainS.wb.arrowTex
rawset(arrowT, "SetGradient", function(s2, o, c0, c1) s2.__grad = { o, c0, c1 } end)
rawset(arrowT, "SetVertexColor", function(s2, r) s2.__vc = r; s2.__grad = nil end)
-- BetterBlizzFrames' classic minimap border in two pieces, left and right half of the map
local mapL, mapR = tex(), tex()
rawset(mapL, "GetLeft", function() return 0 end)
rawset(mapL, "GetRight", function() return 50 end)
rawset(mapR, "GetLeft", function() return 50 end)
rawset(mapR, "GetRight", function() return 100 end)
rawset(_G, "BBF", { classicMinimapTextures = { mapL, mapR } })
DB.look = "gradient"
SlashCmdList.WACKYBARS("status")
check("Purple to pink: the minimap border's two pieces each get their half of one gradient (they join in the middle)",
	mapL.__grad and mapR.__grad and math.abs(mapL.__grad[2].r - 0xBD / 255) < 0.01 and math.abs(mapR.__grad[3].b - 0xC6 / 255) < 0.01
	and math.abs(mapL.__grad[3].g - mapR.__grad[2].g) < 0.001 and mapL.__grad[3].g < 0x93 / 255 - 0.01)
check("Purple to pink: the movement arrows get their slice of the gradient", arrowT.__grad ~= nil and arrowT.__grad[1] == "HORIZONTAL")
check("Purple to pink: the minimap ring gets the whole gradient", ring.__grad and math.abs(ring.__grad[2].r - 0xBD / 255) < 0.01
	and math.abs(ring.__grad[3].b - 0xC6 / 255) < 0.01)
ring:SetVertexColor(0.3, 0.3, 0.3) -- (BetterBlizzFrames writes its dark again)
check("... BetterBlizzFrames writing its dark again: the gradient goes back on top", ring.__grad ~= nil)
local g = qTex.__grad
check("Purple to pink: Q's frame gets its slice of the bar's gradient (#BD93F9 at the bar's left, partway to #FF79C6)", g
	and g[1] == "HORIZONTAL" and g[2].r >= 0xBD / 255 - 0.01 and g[3].b < 0xF9 / 255 and g[3].b > 0xC6 / 255 and qTex.__desat == true)
DB.look = nil
SlashCmdList.WACKYBARS("status")
check("Default: Q copies Action Bar 1's dark tint again", qTex.__grad == nil and qTex.__vc and qTex.__vc[1] == 0.2)
-- His Action Bar 1 (readout Nov 10): button 45, icon 45, frame 51 (Hide Bar Art on: the game's lone-button AddRow frame).
-- WackyBars takes only its colour; the frame is the game's bar frame, 46 by 45 at the button's top left.
refTex.__w, refTex.__h = 51, 51
rawset(refTex, "GetAtlas", function() return "UI-HUD-ActionBar-IconFrame-AddRow" end)
SlashCmdList.WACKYBARS("status")
local qp = qTex.__points[#qTex.__points]
check(("Q's frame: the game's bar frame, 46 x 45 at the button's top left, not Action Bar 1's 51 AddRow (%s x %s)"):format(
	tostring(qTex.__w), tostring(qTex.__h)), qp and qp[1] == "TOPLEFT" and qp[2] == _G.WackyBarsPlainQ
	and math.abs(qTex.__w - 46) < 0.01 and math.abs(qTex.__h - 45) < 0.01
	and _G.WackyBarsPlainQ.__normalAtlas == "UI-HUD-ActionBar-IconFrame" and qTex.__vc and qTex.__vc[1] == 0.2)
check("Default: the minimap ring has BetterBlizzFrames' latest dark back", ring.__grad == nil and ring.__vc[1] == 0.3)
check("Default: the arrows plain grey again", arrowT.__grad == nil and arrowT.__vc == 1)
check("arrows at 30% by default", math.abs(arrowT.__alpha - 0.3) < 0.01)
DB.arrowAlpha = 0.5
SlashCmdList.WACKYBARS("status")
check("Arrows set to 50% in the options: the arrows at 50%", math.abs(arrowT.__alpha - 0.5) < 0.01)
DB.arrowAlpha = nil
SlashCmdList.WACKYBARS("status")
do -- the Arrows button in /wbars: one click, 30% to 50%
	local btn
	SlashCmdList.WACKYBARS("")
	for _, f in ipairs(M.frames) do
		if f.__parent == _G.WackyBarsOptions and f.__template == "UIPanelButtonTemplate" and f.__text == "30%" then btn = f end
	end
	if btn and btn.__scripts.OnClick then btn.__scripts.OnClick(btn) end
	check("the Arrows button in /wbars steps 30% to 50% and says so", btn and DB.arrowAlpha == 0.5 and btn.__text == "50%"
		and math.abs(arrowT.__alpha - 0.5) < 0.01)
	DB.arrowAlpha = nil
	SlashCmdList.WACKYBARS("status")
end

-- The look tab's ideas (Nov 10 night, his picks 2, 9, 8, 3, 4), each in its own block. The fakes they need are made here.
do -- 2: the gradient cooldown pie. Default leaves the game's dark pie; Purple to pink gives each button its slice's colour.
	local function pieFakes(cd)
		local fs = M.newObj("FontString")
		fs.__tc = { 1, 1, 1, 1 }
		rawset(fs, "SetTextColor", function(s, r, g, b, a) s.__tc = { r, g, b, a } end)
		rawset(fs, "GetTextColor", function(s) return s.__tc[1], s.__tc[2], s.__tc[3], s.__tc[4] end)
		rawset(cd, "SetSwipeColor", function(s, r, g, b, a) s.__swipe = { r, g, b, a } end)
		rawset(cd, "GetCountdownFontString", function() return fs end)
		return fs
	end
	local qCd = _G.WackyBarsPlainQ.cooldown
	local qNum = pieFakes(qCd)
	SlashCmdList.WACKYBARS("status")
	check("Default: the cooldown pie and its seconds stay as the game has them", qCd.__swipe == nil and qNum.__tc[1] == 1)
	DB.look = "gradient"
	SlashCmdList.WACKYBARS("status")
	local sw, tc = qCd.__swipe, qNum.__tc
	check("Purple to pink: Q's pie is its slice's colour dimmed to 40%, at the game's 0.64; the seconds in the slice's colour",
		sw and math.abs(sw[4] - 0.64) < 0.001 and math.abs(sw[1] - tc[1] * 0.4) < 0.001 and math.abs(sw[2] - tc[2] * 0.4) < 0.001
		and math.abs(sw[3] - tc[3] * 0.4) < 0.001 and tc[1] >= 0xBD / 255 - 0.01 and tc[3] <= 0xF9 / 255 + 0.01
		and tc[3] >= 0xC6 / 255 - 0.01)
	DB.look = nil
	SlashCmdList.WACKYBARS("status")
	sw = qCd.__swipe
	check("Default again: the game's dark pie back (black at 0.64), the seconds white again", sw[1] == 0 and sw[2] == 0
		and sw[3] == 0 and math.abs(sw[4] - 0.64) < 0.001 and qNum.__tc[1] == 1 and qNum.__tc[2] == 1 and qNum.__tc[3] == 1)
	-- the game's pet button in a spot: its slice's pie too, and the black its own code sets once it is back in its bar
	local petCd = M.newObj("Cooldown", nil, pet1)
	rawset(pet1, "cooldown", petCd)
	pieFakes(petCd)
	DB.look = "gradient"
	binds["ALT-F1"] = "BONUSACTIONBUTTON1"
	M.fire("UPDATE_BINDINGS")
	check("Purple to pink: the game's pet button in a spot gets its slice's pie too", pet1:GetParent() == _G.WackyBarsPetMouseAlt
		and petCd.__swipe and math.abs(petCd.__swipe[4] - 0.64) < 0.001 and petCd.__swipe[3] > 0)
	binds["ALT-F1"] = nil
	M.fire("UPDATE_BINDINGS")
	check("... back in the game's pet bar: the black its own code sets (no alpha), whatever the look", petCd.__swipe[1] == 0
		and petCd.__swipe[3] == 0 and petCd.__swipe[4] == nil and pet1:GetParent() == _G.PetActionBarButtonContainer1)
	DB.look = nil
	SlashCmdList.WACKYBARS("status")
end
do -- 9: the proc glow. LibButtonGlow as the library has it: glow frames of six textures, from a pool shared by every addon.
	local LBG, pool = {}, {}
	function LBG.ShowOverlayGlow(frame)
		if rawget(frame, "__LBGoverlay") then return end
		local o = table.remove(pool)
		if not o then
			o = {}
			for _, k in ipairs({ "spark", "innerGlow", "innerGlowOver", "outerGlow", "outerGlowOver", "ants" }) do o[k] = tex() end
		end
		rawset(frame, "__LBGoverlay", o)
	end
	function LBG.HideOverlayGlow(frame)
		local o = rawget(frame, "__LBGoverlay")
		if o then pool[#pool + 1] = o; rawset(frame, "__LBGoverlay", nil) end
	end
	local oldStub = LibStub
	rawset(_G, "LibStub", setmetatable({}, { __call = function(_, n, silent)
		if n == "LibButtonGlow-1.0" then return LBG end
		return oldStub(n, silent)
	end }))
	SlashCmdList.WACKYBARS("status") -- (a look update: the glow is hooked once the library is there)
	local Q = _G.WackyBarsPlainQ
	LBG.ShowOverlayGlow(Q)
	local o = rawget(Q, "__LBGoverlay")
	check("Default: a proc on Q shows the game's yellow glow, untouched", o and o.ants.__grad == nil and not o.ants.__desat)
	DB.look = "gradient"
	SlashCmdList.WACKYBARS("status")
	check("Purple to pink: the glow already showing takes Q's slice, all six parts (#BD93F9 at the bar's left)",
		o.ants.__grad and o.ants.__desat == true and o.outerGlow.__grad and o.spark.__grad
		and math.abs(o.ants.__grad[2].r - 0xBD / 255) < 0.01 and o.ants.__grad[1] == "HORIZONTAL")
	LBG.HideOverlayGlow(Q)
	local other = M.newObj("CheckButton", "SomeOtherAddonButton") -- (another addon's button using the same library)
	LBG.ShowOverlayGlow(other)
	local o2 = rawget(other, "__LBGoverlay")
	check("... that glow frame goes back to the shared pool: on another addon's button it is the game's yellow again",
		o2 == o and o2.ants.__grad == nil and o2.ants.__desat == false and o2.ants.__vc and o2.ants.__vc[1] == 1
		and o2.innerGlow.__vc and o2.innerGlow.__vc[3] == 1)
	LBG.HideOverlayGlow(other)
	LBG.ShowOverlayGlow(Q)
	check("... a new proc on Q: its slice again", rawget(Q, "__LBGoverlay").ants.__grad ~= nil)
	DB.look = nil
	SlashCmdList.WACKYBARS("status")
	o = rawget(Q, "__LBGoverlay")
	check("Default again: Q's glow is the game's yellow (white, not greyed)", o.ants.__grad == nil and o.ants.__desat == false
		and o.ants.__vc[1] == 1 and o.ants.__vc[2] == 1 and o.ants.__vc[3] == 1)
	LBG.HideOverlayGlow(Q)
	rawset(_G, "LibStub", oldStub)
end
do -- 8: more looks. The Look button opens a short list (the game's menu); each look colours what Purple to pink does.
	if not _G.WackyBarsOptions:IsShown() then SlashCmdList.WACKYBARS("") end
	local lookBtn
	for _, f in ipairs(M.frames) do
		if f.__parent == _G.WackyBarsOptions and f.__template == "UIPanelButtonTemplate" and f.__text == "Default" then lookBtn = f end
	end
	check("the Look button in /wbars shows Default", lookBtn ~= nil)
	if lookBtn then lookBtn.__scripts.OnClick(lookBtn) end
	check("without the game's menu a click steps to the next look: Purple to pink, and says so", DB.look == "gradient"
		and lookBtn.__text == "Purple to pink")
	local menuOwner, menuGen
	rawset(_G, "MenuUtil", { CreateContextMenu = function(owner, gen) menuOwner, menuGen = owner, gen end })
	lookBtn.__scripts.OnClick(lookBtn)
	local radios = {}
	local root = { CreateRadio = function(_, text, isSel, set) radios[#radios + 1] = { text = text, isSel = isSel, set = set } end }
	if menuGen then menuGen(menuOwner, root) end
	check("with the game's menu a click opens the list: six looks, Default first, the one picked marked", menuOwner == lookBtn
		and #radios == 6 and radios[1].text == "Default" and radios[2].text == "Purple to pink" and radios[2].isSel()
		and not radios[1].isSel() and radios[3].text == "Dracula (cyan to purple)" and DB.look == "gradient")
	local function pick(name)
		for _, r in ipairs(radios) do if r.text:find(name, 1, true) == 1 then r.set() end end
	end
	pick("Nord")
	local g = qTex.__grad
	check("Nord picked: the label says Nord, Q's frame starts at Nord's #88C0D0 on the bar's left, toward #5E81AC", DB.look == "nord"
		and lookBtn.__text == "Nord" and g and math.abs(g[2].r - 0x88 / 255) < 0.01 and math.abs(g[2].g - 0xC0 / 255) < 0.01
		and g[3].r < 0x88 / 255 and radios[4].isSel())
	check("... the minimap ring and the arrows follow Nord (#88C0D0 to #5E81AC)", ring.__grad
		and math.abs(ring.__grad[2].b - 0xD0 / 255) < 0.01 and math.abs(ring.__grad[3].r - 0x5E / 255) < 0.01 and arrowT.__grad ~= nil)
	local starts, allOk = { Dracula = 0x8BE9FD, Gruvbox = 0xFE8019, Catppuccin = 0xCBA6F7 }, true
	for name, hx in pairs(starts) do
		pick(name)
		local s = qTex.__grad and qTex.__grad[2]
		if not (s and math.abs(s.r - math.floor(hx / 65536) / 255) < 0.01 and math.abs(s.b - hx % 256 / 255) < 0.01
			and lookBtn.__text == name) then allOk = false end
	end
	check("Dracula, Gruvbox and Catppuccin each start at their own colour (cyan, orange, mauve) and say their name", allOk)
	pick("Default")
	check("Default from the list: Q has Action Bar 1's dark again, the ring BetterBlizzFrames' dark, the arrows grey",
		DB.look == nil and qTex.__grad == nil and qTex.__vc and qTex.__vc[1] == 0.2 and ring.__grad == nil and ring.__vc[1] == 0.3
		and arrowT.__grad == nil and lookBtn.__text == "Default")
	DB.look = "someday" -- (a look a newer version saved)
	SlashCmdList.WACKYBARS("status")
	check("a saved look this version does not know shows Default", qTex.__grad == nil and qTex.__vc[1] == 0.2 and ring.__grad == nil)
	DB.look = nil
	SlashCmdList.WACKYBARS("status")
	rawset(_G, "MenuUtil", nil)
end
do -- 3: glass. A box in the Look list for every colour look: one dark see-through panel per bar, in the bar's holder.
	for _, n in ipairs({ "WackyBarsPlain", "WackyBarsMouseHyper" }) do -- (their glass records its colours)
		rawset(_G[n], "CreateTexture", function(s, _, layer)
			local t = tex()
			t.__parent, t.__layer = s, layer
			return t
		end)
	end
	local lookBtn
	for _, f in ipairs(M.frames) do
		if f.__parent == _G.WackyBarsOptions and f.__template == "UIPanelButtonTemplate" and f.__text == "Default" then lookBtn = f end
	end
	local entries = {}
	local root = {
		CreateRadio = function(_, text, isSel, set) entries[#entries + 1] = { text = text, isSel = isSel, set = set } end,
		CreateDivider = function() end,
		CreateCheckbox = function(_, text, isSel, set)
			local e = { text = text, isSel = isSel, set = set, box = true }
			function e:SetEnabled(v) self.enabled = v end
			entries[#entries + 1] = e
			return e
		end,
	}
	rawset(_G, "MenuUtil", { CreateContextMenu = function(owner, gen) wipe(entries) gen(owner, root) end })
	local function click(name)
		lookBtn.__scripts.OnClick(lookBtn)
		for _, e in ipairs(entries) do if e.text:find(name, 1, true) == 1 then e.set() return e end end
	end
	lookBtn.__scripts.OnClick(lookBtn)
	local box
	for _, e in ipairs(entries) do if e.text == "Glass behind each bar" then box = e end end
	check("the Look list has a box, Glass behind each bar, after the looks, greyed while Default is picked", box and box.box
		and entries[7] == box and type(box.enabled) == "function" and box.enabled() == false and not box.isSel())
	check("Default: no glass is made", _G.WackyBarsPlain.wbGlass == nil and _G.WackyBarsMouseHyper.wbGlass == nil)
	click("Purple to pink")
	click("Glass behind each bar")
	local glass, Q = _G.WackyBarsPlain.wbGlass, _G.WackyBarsPlainQ
	local g = glass and glass.__grad
	check("Purple to pink + glass: each bar gets one panel, in the holder QuietHUD fades with its buttons, behind them",
		glass and glass.__shown ~= false and glass.__parent == Q:GetParent() and glass.__layer == "BACKGROUND"
		and _G.WackyBarsMouseHyper.wbGlass ~= nil and lookBtn.__text == "Purple to pink + glass" and DB.glass == true)
	local p1, p2 = glass.__points[1], glass.__points[2]
	check("... a little bigger than its bar (6 all round)", p1 and p2 and p1[1] == "TOPLEFT" and p1[2] == _G.WackyBarsPlain
		and p1[4] == -6 and p1[5] == 6 and p2[1] == "BOTTOMRIGHT" and p2[4] == 6 and p2[5] == -6)
	check("... dark and see-through: the look's two colours at a quarter, half see-through (#BD93F9 left, #FF79C6 right)", g
		and g[1] == "HORIZONTAL" and math.abs(g[2].r - 0xBD / 255 * 0.25) < 0.001 and math.abs(g[3].b - 0xC6 / 255 * 0.25) < 0.001
		and g[2].a == 0.5 and g[3].a == 0.5)
	SlashCmdList.WACKYBARS("move")
	local onFrame = glass.__parent == _G.WackyBarsPlain
	SlashCmdList.WACKYBARS("move")
	check("Move bars: the glass sits on the bar (full, under the arrows), back in its holder after", onFrame
		and glass.__parent == Q:GetParent())
	click("Nord")
	g = glass.__grad
	check("Nord + glass: the glass takes Nord's colours", g and math.abs(g[2].r - 0x88 / 255 * 0.25) < 0.001
		and lookBtn.__text == "Nord + glass" and glass.__shown ~= false)
	click("Default")
	check("Default: the glass hides (the box is kept for a colour look), the label says Default", glass.__shown == false
		and _G.WackyBarsMouseHyper.wbGlass.__shown == false and DB.glass == true and lookBtn.__text == "Default")
	click("Gruvbox")
	check("Gruvbox: the glass is back", glass.__shown == true and lookBtn.__text == "Gruvbox + glass")
	click("Glass behind each bar")
	check("glass unticked: hidden, the label says Gruvbox", glass.__shown == false and DB.glass == nil and lookBtn.__text == "Gruvbox")
	click("Default")
	rawset(_G, "MenuUtil", nil)
end
do -- 4: drifting colours. Off by default; a box in the Look list; a timer only while a bar shows above QuietHUD's Faded.
	local lookBtn
	for _, f in ipairs(M.frames) do
		if f.__parent == _G.WackyBarsOptions and f.__template == "UIPanelButtonTemplate" and f.__text == "Default" then lookBtn = f end
	end
	local entries = {}
	local root = {
		CreateRadio = function(_, text, isSel, set) entries[#entries + 1] = { text = text, isSel = isSel, set = set } end,
		CreateDivider = function() end,
		CreateCheckbox = function(_, text, isSel, set)
			local e = { text = text, isSel = isSel, set = set }
			function e:SetEnabled(v) self.enabled = v end
			entries[#entries + 1] = e
			return e
		end,
	}
	rawset(_G, "MenuUtil", { CreateContextMenu = function(owner, gen) wipe(entries) gen(owner, root) end })
	local function click(name)
		lookBtn.__scripts.OnClick(lookBtn)
		for _, e in ipairs(entries) do if e.text:find(name, 1, true) == 1 then e.set() return e end end
	end
	local tickers = {}
	rawset(C_Timer, "NewTicker", function(sec, fn)
		local tk = { sec = sec, fn = fn }
		function tk:Cancel() self.cancelled = true end
		tickers[#tickers + 1] = tk
		return tk
	end)
	local made, oldColor = 0, CreateColor
	rawset(_G, "CreateColor", function(...) made = made + 1 return oldColor(...) end)
	rawset(_G, "QuietHUDDB", { idle = 0.2 }) -- (QuietHUD's Global Faded)
	local clock = 0
	rawset(_G, "debugprofilestop", function() clock = clock + 0.05 return clock end)
	-- Q's frame keeps a copy of what it was given (a tick reuses its two colours)
	rawset(qTex, "SetGradient", function(s, o, c0, c1)
		s.__grad = { o, { r = c0.r, g = c0.g, b = c0.b, a = c0.a }, { r = c1.r, g = c1.g, b = c1.b, a = c1.a } }
	end)
	lookBtn.__scripts.OnClick(lookBtn)
	local box
	for _, e in ipairs(entries) do if e.text == "Colours drift along the bars" then box = e end end
	check("off by default: the Look list's last box, Colours drift along the bars, greyed with Default, no timer", box
		and entries[#entries] == box and box.enabled() == false and not box.isSel() and #tickers == 0 and not DB.drift)
	click("Purple to pink")
	check("Purple to pink alone: no timer", #tickers == 0 and math.abs(qTex.__grad[2].r - 0xBD / 255) < 0.001)
	click("Colours drift along the bars")
	local tk = tickers[1]
	check("ticked: one timer, 4 colour updates a second, the label says + drift", #tickers == 1 and tk and tk.sec == 0.25
		and DB.drift == true and lookBtn.__text == "Purple to pink + drift")
	local before = made
	tk.fn()
	local made1 = made - before
	local r1 = qTex.__grad[2].r
	tk.fn()
	check("a tick slides Q's colours along the gradient (toward pink at the bar's left)", r1 > 0xBD / 255 + 0.001
		and qTex.__grad[2].r > r1)
	check("... and a tick makes no new colours after the first (no garbage)", made1 <= 2 and made - before == made1)
	-- QuietHUD fades every bar to its Faded: the timer stops at the next tick; one bar back up starts it again
	local ids = { "Plain", "Shift", "Ctrl", "Alt", "MousePlain", "MouseShift", "MouseCtrl", "MouseAlt", "MouseHyper" }
	for _, id in ipairs(ids) do
		for i = 1, 9 do _G["WackyBarsHold" .. id .. i]:SetAlpha(0.2) end
	end
	tk.fn()
	check("every bar at QuietHUD's Faded: the timer is cancelled (nothing runs)", tk.cancelled == true and #tickers == 1)
	local held = qTex.__grad[2].r
	local home = _G.WackyBarsPlainQ:GetParent()
	home:SetAlpha(0.6)
	check("the keyboard's holder back above the Faded (QuietHUD shows it): a new timer", #tickers == 2 and not tickers[2].cancelled
		and qTex.__grad[2].r == held)
	for _, id in ipairs(ids) do
		for i = 1, 9 do _G["WackyBarsHold" .. id .. i]:SetAlpha(1) end
	end
	SlashCmdList.WACKYBARS("drift")
	local said = M.printed and M.printed[#M.printed] or ""
	check("/wbars drift says what it costs: updates, ms each, ms a second", said:find("Drifting colours: 3 updates", 1, true)
		and said:find("ms a second at 4 a second", 1, true) ~= nil)
	-- his error of Nov 10 night: QuietHUD's Low health sets a bar's opacity from his hidden health in a fight; the drift
	-- never compares it ("attempt to compare local 'a' (a secret number value)", 4 a second): such a bar counts as up
	local SECRET = setmetatable({}, { __lt = function() error("attempt to compare a secret number value") end,
		__le = function() error("attempt to compare a secret number value") end })
	rawset(_G, "issecretvalue", function(v) return v == SECRET end)
	local errorsBefore = #M.errors
	for _, id in ipairs(ids) do
		for i = 1, 9 do _G["WackyBarsHold" .. id .. i]:SetAlpha(SECRET) end
	end
	local okTick, errTick = pcall(tickers[2].fn)
	check(("a hidden opacity from Low health is never compared: the drift goes on, no error (%s)"):format(tostring(errTick)),
		okTick and #M.errors == errorsBefore and not tickers[2].cancelled)
	for _, id in ipairs(ids) do
		for i = 1, 9 do _G["WackyBarsHold" .. id .. i]:SetAlpha(1) end
	end
	rawset(_G, "issecretvalue", function() return false end)
	click("Colours drift along the bars")
	check("unticked: the timer stops, the colours stand still again (#BD93F9 at the bar's left)", tickers[2].cancelled == true
		and DB.drift == nil and math.abs(qTex.__grad[2].r - 0xBD / 255) < 0.001 and lookBtn.__text == "Purple to pink")
	click("Colours drift along the bars")
	click("Default")
	local last = tickers[#tickers]
	check("Default with the box ticked: no timer, Q has Action Bar 1's dark again", last.cancelled == true and qTex.__grad == nil
		and qTex.__vc[1] == 0.2 and DB.drift == true and lookBtn.__text == "Default")
	DB.drift = nil
	rawset(_G, "CreateColor", oldColor)
	rawset(_G, "QuietHUDDB", nil)
	rawset(_G, "MenuUtil", nil)
end

-- The feature files of the ideas he picked on Nov 10 night (Ding.lua, ...): their fakes. The fake game's animations,
-- texture atlases and blend modes keep what they are given here, so the checks can read them; put back at the end.
local objMt = getmetatable(UIParent)
local baseIndex = objMt.__index
do
	local REC = { SetAtlas = "__atlas", SetBlendMode = "__blend", SetStartDelay = "__delay", SetFromAlpha = "__from",
		SetToAlpha = "__to", SetDuration = "__dur", SetLooping = "__loop", SetSmoothing = "__smooth", SetOrder = "__order",
		SetDesaturated = "__desat" }
	objMt.__index = function(self, key)
		if REC[key] then return function(s, v) rawset(s, REC[key], v) return s end end
		if key == "CreateAnimation" then
			return function(s, kind)
				local a = M.newObj("Animation", nil, s)
				rawset(a, "__animKind", kind)
				local list = rawget(s, "__anims") or {}
				list[#list + 1] = a
				rawset(s, "__anims", list)
				return a
			end
		end
		if key == "Play" then
			return function(s) rawset(s, "__playing", true) rawset(s, "__plays", (rawget(s, "__plays") or 0) + 1) return s end
		end
		if key == "Stop" then return function(s) rawset(s, "__playing", false) return s end end
		if key == "IsPlaying" then return function(s) return rawget(s, "__playing") or false end end
		if key == "SetGradient" then return function(s, o, c0, c1) rawset(s, "__grad", { o, c0, c1 }) return s end end
		return baseIndex(self, key)
	end
end
local function groupOf(t)
	for _, o in ipairs(M.frames) do
		if o.__kind == "CreateAnimationGroup" and o.__parent == t then return o end
	end
end

-- Ding wave (Ding.lua, his "this was a nice one"): a level up plays one purple to pink glow across every spot that shows,
-- left to right, with the game's animations; /wbars ding plays it to look at.
do
	local function dingGlow(b)
		local layer = _G["WackyBarsDing" .. b.wb.bar.id]
		for _, o in ipairs(M.frames) do
			if layer and o.__kind == "CreateTexture" and o.__parent == layer then
				local p = o.__points[#o.__points]
				if p and p[2] == b then return o end
			end
		end
	end
	local all = {}
	for _, v in pairs(_G) do
		if type(v) == "table" and rawget(v, "wb") and v.wb.bar then all[#all + 1] = v end
	end
	local function spotShows(b)
		local a = b.wb.arrowTex
		return b.wb.bar.frame.__shown and (b.__shown or (a and a.__shown)) and true or false
	end
	local timers = #M.timers
	rawset(_G.WackyBarsPlainQ, "GetCenter", function() return 100, 50 end)
	rawset(_G.WackyBarsPlainY, "GetCenter", function() return 400, 50 end)
	SlashCmdList.WACKYBARS("ding")
	local want, lit, wrong, arrows = 0, 0, 0, 0
	for _, b in ipairs(all) do
		local g = dingGlow(b)
		if spotShows(b) then
			want = want + 1
			if g and g.__shown then lit = lit + 1 end
			if g and g.__shown and not b.__shown then arrows = arrows + 1 end
		elseif g and g.__shown then
			wrong = wrong + 1
		end
	end
	check(("Ding: /wbars ding lights every spot that shows (%d of %d), movement arrows too, nothing else"):format(lit, want),
		want > 0 and lit == want and wrong == 0 and arrows > 0)
	local q, yb = dingGlow(_G.WackyBarsPlainQ), dingGlow(_G.WackyBarsPlainY)
	local gq, gy = q and groupOf(q), yb and groupOf(yb)
	local riseQ, riseY = gq and gq.__anims and gq.__anims[1], gy and gy.__anims and gy.__anims[1]
	check("... left to right: the leftmost at once, Q next, Y (rightmost) 1.4 seconds after the first",
		riseQ and riseY and math.abs(riseQ.__delay - 0.35) < 0.001 and math.abs(riseY.__delay - 1.4) < 0.001
		and groupOf(dingGlow(_G.WackyBarsPlain1)).__anims[1].__delay == 0)
	check("... once: fade in 0.25 s to half strength, out in 0.35 s, played by the game (no loop)", gq and gq.__plays == 1
		and gq.__loop == nil and riseQ.__from == 0 and riseQ.__to == 0.5 and riseQ.__dur == 0.25 and gq.__anims[2].__to == 0
		and gq.__anims[2].__dur == 0.35)
	check("... the game's spell highlight, added light, tinted with the button's slice of the bar's gradient",
		q and q.__atlas == "UI-HUD-ActionBar-IconFrame-Mouseover" and q.__blend == "ADD" and q.__grad
		and q.__grad[1] == "HORIZONTAL" and q.__desat == true)
	local layer = _G.WackyBarsDingPlain
	check("... on the bar itself, not in QuietHUD's faded holders, at full whatever they fade", layer
		and layer.__parent == _G.WackyBarsPlain and layer.__ignoreParentAlpha == true)
	local onUpdate = false
	for _, o in ipairs(M.frames) do
		if o.__name and o.__name:match("^WackyBarsDing") and o.__scripts.OnUpdate then onUpdate = true end
	end
	check("... no OnUpdate and no timer: the game's animations only", not onUpdate and #M.timers == timers)
	gq.__scripts.OnFinished(gq)
	check("... when it is done the glow is hidden again", q.__shown == false)
	DB.off.Shift = true
	SlashCmdList.WACKYBARS("status")
	local shiftQ = dingGlow(_G.WackyBarsShiftQ)
	if shiftQ then shiftQ:Hide() end
	M.fire("PLAYER_LEVEL_UP", 61, 10, 10, 0, 0, 1, 1, 1, 1, 1)
	check("a level up (PLAYER_LEVEL_UP) plays it again; a bar switched off stays dark", gq.__plays == 2 and q.__shown == true
		and not (shiftQ and shiftQ.__shown))
	DB.off.Shift = nil
	SlashCmdList.WACKYBARS("status")
end

-- Bar profiles (Profiles.lua, his "this could be nice to"): one Profiles row in /wbars; a profile keeps which bars show,
-- their places and their sizes; one click on the name switches; changes go into the profile you are on.
do
	local popups = {}
	rawset(_G, "StaticPopupDialogs", {})
	rawset(_G, "StaticPopup_Show", function(which) popups[#popups + 1] = which end)
	local function dialogSays(text) return { GetEditBox = function() return { GetText = function() return text end } end } end
	local opts = _G.WackyBarsOptions
	rawset(opts, "GetRegions", function(s) -- (the window's labels; the fake game lists none)
		local out = {}
		for _, o in ipairs(M.frames) do if o.__parent == s and o.__kind == "CreateFontString" then out[#out + 1] = o end end
		return unpack(out)
	end)
	if opts.__shown then SlashCmdList.WACKYBARS("") end
	SlashCmdList.WACKYBARS("") -- (the window opens: the row is made)
	local pick, save, label = _G.WackyBarsProfilePick, _G.WackyBarsProfileSave, nil
	for _, o in ipairs(M.frames) do if o.__parent == opts and o.__text == "Profiles" then label = o end end
	local box = label and label.__points[1] and label.__points[1][2]
	check("Profiles: one row in /wbars, the label, a name button (None yet) and Save where the other rows have buttons",
		pick and save and pick.__text == "None" and save.__text == "Save" and pick.__w == 160 and box
		and box.__shown == false and label.__points[1][1] == "LEFT" and pick.__points[1][2] == box and pick.__points[1][4] == 130)
	pick.__scripts.OnClick(pick)
	check("... no profile yet: a click on the name asks for one", popups[#popups] == "WACKYBARS_PROFILE")
	local P = StaticPopupDialogs.WACKYBARS_PROFILE
	local keys0, pos0, sizes0, off0 = M.copy(DB.keys), M.copy(DB.pos), M.copy(DB.sizes), M.copy(DB.off)
	P.OnAccept(dialogSays(" Leveling "))
	check("... Save: the bars kept as Leveling (copies of which are off, places, sizes), on it now", DB.profile == "Leveling"
		and #DB.profiles == 1 and DB.profiles[1].pos ~= DB.pos and DB.profiles[1].off ~= DB.off and pick.__text == "Leveling")
	P.OnAccept(dialogSays("Dungeon"))
	-- on Dungeon: the Shift keyboard switched off, the keyboard moved, the mouse bar made bigger
	DB.off.Shift = true
	DB.pos.Plain = { "TOPLEFT", "BOTTOMLEFT", 111, 222 }
	DB.sizes.MousePlain = 1.5
	SlashCmdList.WACKYBARS("status")
	local function shiftSpares()
		local n = 0
		for id in pairs(DB.spare) do if id:match("^Shift") then n = n + 1 end end
		return n
	end
	check("... (Dungeon: Shift keyboard off, its empty spare slots handed back)", shiftSpares() == 0
		and _G.WackyBarsShift.__shown == false)
	pick.__scripts.OnClick(pick)
	local d = DB.profiles[2]
	check("one click on the name: Leveling's bars back (Shift keyboard on, the keyboard's place, the mouse bar's size)",
		DB.profile == "Leveling" and pick.__text == "Leveling" and _G.WackyBarsShift.__shown == true and DB.off.Shift == nil
		and (_G.WackyBarsPlain.__points[1][4] ~= 111) and _G.WackyBarsMousePlain.__scale == 1)
	check("... the Shift keyboard's free keys get spare slots again (as its box in /wbars does)", shiftSpares() > 0)
	check("... and Dungeon kept the changes made on it", d.name == "Dungeon" and d.off.Shift == true and d.pos.Plain[3] == 111
		and d.sizes.MousePlain == 1.5)
	pick.__scripts.OnClick(pick)
	check("one more click: Dungeon (keyboard at its place, mouse bar at 150%, Shift keyboard off)", DB.profile == "Dungeon"
		and _G.WackyBarsPlain.__points[1][4] == 111 and _G.WackyBarsMousePlain.__scale == 1.5 and _G.WackyBarsShift.__shown == false)
	local same = true
	for k, v in pairs(keys0) do if DB.keys[k] ~= v then same = false end end
	for k, v in pairs(DB.keys) do if keys0[k] ~= v then same = false end end
	check("... keys stay the same in every profile", same)
	SlashCmdList.WACKYBARS("profile leveling")
	check("/wbars profile leveling switches to it (for a macro)", DB.profile == "Leveling" and _G.WackyBarsShift.__shown == true)
	SlashCmdList.WACKYBARS("profile nope")
	check("... a name that isn't one says so", M.printed[#M.printed]:find("no profile named nope", 1, true) ~= nil)
	combat = true
	pick.__scripts.OnClick(pick)
	combat = false
	check("in a fight a click switches nothing (after the fight)", DB.profile == "Leveling"
		and M.printed[#M.printed]:find("after the fight", 1, true) ~= nil)
	P.OnAlt(dialogSays("dungeon"))
	check("Delete in the Save box: Dungeon gone, still on Leveling", #DB.profiles == 1 and DB.profile == "Leveling")
	local posNow = DB.pos
	P.OnAlt(dialogSays("Leveling"))
	check("... deleting the one you are on: no profile, the bars stay as they are", DB.profile == nil and #DB.profiles == 0
		and pick.__text == "None" and DB.pos == posNow)
	DB.keys, DB.pos, DB.sizes, DB.off, DB.profiles = keys0, pos0, sizes0, off0, nil
	SlashCmdList.WACKYBARS("status")
end

-- Panic flash (Panic.lua, his "not a bad idea either"): in a fight, under 30% health, the buttons holding an escape spell (by
-- name, any rank), a Healthstone or a healing potion pulse; the game sets their opacity from a step curve over your health
-- (hidden from addons); one box in /wbars switches it off.
do
	local hp = 1
	local curves = {}
	rawset(_G, "C_CurveUtil", { CreateCurve = function()
		local c = { points = {} }
		function c:SetType(t) self.type = t end
		function c:ClearPoints() self.points = {} end
		function c:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
		curves[#curves + 1] = c
		return c
	end })
	Enum.LuaCurveType = { Step = "Step" }
	rawset(_G, "UnitHealthPercent", function(unit, _, c) -- (a step curve: the value of the last point at or left of your health)
		if unit ~= "player" or not c then return hp end
		local v
		for _, p in ipairs(c.points) do if p[1] <= hp + 1e-9 then v = p[2] end end
		return v
	end)
	local info, spells, items, macros = {}, { [17926] = "Death Coil", [686] = "Shadow Bolt", [17928] = "Howl of Terror" }, {}, { [3] = 17928 }
	rawset(_G, "GetActionInfo", function(slot) local i = info[slot] if i then return i[1], i[2], i[3] end end)
	C_Spell.GetSpellName = function(id) return spells[id] end
	C_Item.GetItemNameByID = function(id) return items[id] end
	rawset(_G, "GetMacroSpell", function(id) return macros[id] end)
	-- four shown buttons with a slot of their own: Death Coil (a rank's id), a Healthstone, Shadow Bolt, a macro casting Howl
	-- of Terror
	local picked, seen = {}, {}
	for _, v in ipairs(M.frames) do
		if rawget(v, "wb") and v.__shown and v.wb.bar.frame.__shown and #picked < 4 then
			local kind, slot = v:GetAction()
			if kind == "action" and type(slot) == "number" and not seen[slot] then
				seen[slot] = true
				picked[#picked + 1] = v
			end
		end
	end
	local A, B, C, D = picked[1], picked[2], picked[3], picked[4]
	local function slotOf(b) return select(2, b:GetAction()) end
	info[slotOf(A)], info[slotOf(B)], info[slotOf(C)], info[slotOf(D)] = { "spell", 17926 }, { "item", 5510 }, { "spell", 686 },
		{ "macro", 3 }
	local function pulse(b)
		for _, o in ipairs(M.frames) do
			if o.__kind == "Frame" and o.__parent == b then
				for _, t in ipairs(M.frames) do
					if t.__kind == "CreateTexture" and t.__parent == o and t.__atlas == "UI-HUD-ActionBar-IconFrame-Mouseover" then
						return o, t, groupOf(t)
					end
				end
			end
		end
	end
	local function pulsing(b)
		local gate, _, g = pulse(b)
		return gate and gate.__shown and g and g.__playing and true or false
	end
	local function listening(e)
		for _, o in ipairs(M.frames) do if o.__events[e] and o.__scripts.OnEvent then return true end end
		return false
	end
	check("Panic: four buttons to try it on", D ~= nil)
	check("... out of a fight nothing pulses and your health is not listened to", not pulse(A) and not listening("UNIT_HEALTH"))
	combat = true
	M.fire("PLAYER_REGEN_DISABLED")
	check("a fight: Death Coil (by name, any rank) and the Howl of Terror macro pulse, Shadow Bolt doesn't",
		pulsing(A) and pulsing(D) and not pulsing(C))
	check("... the Healthstone's name not loaded yet: it waits for the game's item info", not pulsing(B)
		and listening("GET_ITEM_INFO_RECEIVED"))
	items[5510] = "Major Healthstone"
	M.fire("GET_ITEM_INFO_RECEIVED", 5510, true)
	M.flushTimers()
	check("... and pulses once the game has it (then stops waiting)", pulsing(B) and not listening("GET_ITEM_INFO_RECEIVED"))
	local gate, tex, g = pulse(A)
	check("... the game's spell highlight, looping 0.35 s up and down at half strength, tinted with the bar's gradient",
		tex.__blend == "ADD" and g.__loop == "REPEAT" and g.__anims[1].__to == 0.5 and g.__anims[1].__dur == 0.35
		and g.__anims[2].__to == 0 and tex.__grad and tex.__desat == true)
	check("... on the button, so it fades with its bar (QuietHUD's row)", gate.__parent == A)
	local c = curves[#curves]
	check("... a step curve over your health: 1 under 30%, 0 from 30% up", c and c.type == "Step" and #c.points == 4
		and c.points[2][2] == 1 and c.points[3][1] == 0.3 and c.points[3][2] == 0)
	hp = 0.8
	M.fire("UNIT_HEALTH", "player")
	local high = gate.__alpha
	hp = 0.25
	M.fire("UNIT_HEALTH", "player")
	check("... health 80%: hidden; 25%: shown (the game's number, never read here)", high == 0 and gate.__alpha == 1
		and select(1, pulse(D)).__alpha == 1)
	M.fire("UNIT_HEALTH", "target")
	check("... another unit's health changes nothing", gate.__alpha == 1)
	info[slotOf(A)] = { "spell", 686 }
	local before = #M.timers
	M.fire("UPDATE_BONUS_ACTIONBAR")
	M.fire("ACTIONBAR_SLOT_CHANGED", slotOf(A))
	check("a page or slot change in a fight: read again once, a frame later", #M.timers == before + 1)
	M.flushTimers()
	check("... Death Coil's button now holds Shadow Bolt: it stops", not pulsing(A) and pulsing(D))
	combat = false
	M.fire("PLAYER_REGEN_ENABLED")
	check("the fight ends: every pulse stops, your health is not listened to", not pulsing(B) and not pulsing(D)
		and not listening("UNIT_HEALTH") and not listening("UPDATE_BONUS_ACTIONBAR"))
	local noUpdate = true
	for _, b in ipairs({ A, B, C, D }) do
		local gt, t = pulse(b)
		if (gt and gt.__scripts.OnUpdate) or (t and t.__scripts.OnUpdate) then noUpdate = false end
	end
	check("... no OnUpdate on any pulse (the game's animations), no timer left", noUpdate and #M.timers == 0)
	info[slotOf(A)] = { "spell", 17926 }
	local opts = _G.WackyBarsOptions
	if not opts.__shown then SlashCmdList.WACKYBARS("") end
	local box
	for _, o in ipairs(M.frames) do
		if o.__parent == opts and o.__text == "Panic flash (escape spells pulse under 30% health)" then box = o.__points[1][2] end
	end
	box.__scripts.OnClick(box)
	combat = true
	M.fire("PLAYER_REGEN_DISABLED")
	check("the box in /wbars unticked: a fight pulses nothing, health not listened to", DB.noPanic == true
		and not pulsing(A) and not listening("UNIT_HEALTH"))
	combat = false
	M.fire("PLAYER_REGEN_ENABLED")
	SlashCmdList.WACKYBARS("")
	if not opts.__shown then SlashCmdList.WACKYBARS("") end
	box.__scripts.OnClick(box)
	combat = true
	M.fire("PLAYER_REGEN_DISABLED")
	check("... ticked again: it pulses in the next fight", DB.noPanic == nil and pulsing(A))
	combat = false
	M.fire("PLAYER_REGEN_ENABLED")
end

-- Your keys on Warlock HUD's icons (WhudKeys.lua, his "just like a wackybar thing that overlays the keys their to"): each icon
-- whose picture is on one of your keys shows that key; Warlock HUD itself is left as it is.
do
	local function listening(e)
		for _, o in ipairs(M.frames) do if o.__events[e] and o.__scripts.OnEvent then return true end end
		return false
	end
	check("Warlock HUD keys: nothing listened to until Warlock HUD is there at login", not listening("ACTIONBAR_SLOT_CHANGED"))
	-- a plain keyboard button and a Shift keyboard button that show a slot, as they are now
	local plain, shiftB
	for _, v in ipairs(M.frames) do
		if rawget(v, "wb") and v.__shown and v.wb.bar.frame.__shown and v.wb.def and select(1, v:GetAction()) == "action"
			and DB.keys[v.wb.id] == nil then
			if v.wb.bar.id == "Plain" and not plain then plain = v end
			if v.wb.bar.id == "Shift" and not shiftB then shiftB = v end
		end
	end
	local sA, sB = select(2, plain:GetAction()), select(2, shiftB:GetAction())
	local pics = { [sA] = 136197, [sB] = 136200, [45] = 136300 } -- (45: Action Bar 5 button 9, on Caps Lock, no WackyBars spot)
	rawset(_G, "GetActionTexture", function(slot) return pics[slot] end)
	local function icon(parent, x, pic)
		local t = M.newObj("Texture", nil, parent)
		rawset(t, "__pic", pic)
		rawset(t, "GetObjectType", function() return "Texture" end)
		rawset(t, "GetTextureFileID", function(s) return s.__pic end)
		rawset(t, "SetTexture", function(s, p) rawset(s, "__pic", p) end)
		t.__points = { { "CENTER", parent, "CENTER", x, 0 } }
		return t
	end
	local function row(list, holder)
		local a = M.newObj("Frame")
		local regions = {}
		local on = a
		if holder then
			on = M.newObj("Frame", nil, a)
			rawset(on, "GetRegions", function() return unpack(regions) end)
			rawset(a, "GetRegions", function() end)
		else
			rawset(a, "GetRegions", function() return unpack(regions) end)
		end
		for i, pic in ipairs(list) do regions[i] = icon(on, i * 40, pic) end
		rawset(a, "GetChildren", function(s)
			local out = {}
			for _, o in ipairs(M.frames) do if o.__parent == s and o.__kind == "Frame" then out[#out + 1] = o end end
			return unpack(out)
		end)
		return a, regions
	end
	local mainA, main = row({ 136197, 999 })
	local utilA, util = row({ 136200 })
	local buffA, buff = row({ 136300 }, true)
	local rebuilt = false
	local main2A, main2 = row({ 136200, 136197 })
	rawset(_G, "WarlockHudAPI", {
		GetDemoAnchors = function()
			if rebuilt then return { main = main2A, utility = utilA, buffs = buffA } end
			return { main = mainA, utility = utilA, buffs = buffA }
		end,
		Rebuild = function() rebuilt = true return true end,
	})
	local function keyOn(t)
		for _, o in ipairs(M.frames) do
			local p = o.__kind == "CreateFontString" and o.__points[#o.__points]
			if p and p[2] == t and o.__shown then return o.__text, o end
		end
	end
	local pointsBefore = #main[1].__points
	M.fire("PLAYER_LOGIN")
	M.flushTimers()
	local plainKey = plain.wb.spot.label
	check(("Warlock HUD's icons show the key: %s (plain keyboard), s%s (Shift keyboard, its modifier shown)"):format(plainKey,
		shiftB.wb.spot.label), keyOn(main[1]) == plainKey and keyOn(util[1]) == "s" .. shiftB.wb.spot.label)
	check("... a key bound to a game bar button that is no WackyBars spot: the game's key text", keyOn(buff[1]) == "CAPSLOCK")
	check("... an icon whose picture is on no key shows none", keyOn(main[2]) == nil)
	local _, fs = keyOn(main[1])
	local ov = fs and fs.__parent
	check("... in WackyBars' own frame on the row, at the icon's top right, like an action button's key", ov
		and ov.__parent == mainA and fs.__points[#fs.__points][1] == "TOPRIGHT" and not ov.__scripts.OnUpdate)
	do -- his "the ability you marked as swu is actually 1": a macro showing a spell's picture, earlier in the order, loses to
		-- the slot holding the spell itself
		local oldInfo = GetActionInfo
		pics[sA], pics[sB] = 136500, 136500
		rawset(_G, "GetActionInfo", function(slot)
			if slot == sA then return "macro", 1 end
			if slot == sB then return "spell", 172 end
		end)
		main[1]:SetTexture(136500)
		M.flushTimers()
		check("a macro showing a spell's picture loses to the slot with the spell itself (his sWU that is really 1)",
			keyOn(main[1]) == "s" .. shiftB.wb.spot.label)
		rawset(_G, "GetActionInfo", oldInfo)
		pics[sA], pics[sB] = 136197, 136200
		main[1]:SetTexture(136197)
		M.flushTimers()
	end
	check("... Warlock HUD left as it is (its icons keep their places, its rows get no scripts)", #main[1].__points == pointsBefore
		and next(mainA.__scripts) == nil and next(buffA.__scripts) == nil)
	DB.keys[plain.wb.id] = "Z"
	SlashCmdList.WACKYBARS("status")
	M.flushTimers()
	check("a key changed in Edit keys: the icon shows the new key", keyOn(main[1]) == "Z")
	DB.keys[plain.wb.id] = nil
	SlashCmdList.WACKYBARS("status")
	M.flushTimers()
	main[2]:SetTexture(136200)
	M.flushTimers()
	check("Warlock HUD changes an icon's picture: its key follows", keyOn(main[2]) == "s" .. shiftB.wb.spot.label)
	main[1]:Hide()
	check("Warlock HUD hides an icon: its key hides too", keyOn(main[1]) == nil)
	main[1]:Show()
	check("... and shows again with it", keyOn(main[1]) == plainKey)
	WarlockHudAPI.Rebuild()
	M.flushTimers()
	check("Warlock HUD rebuilds its rows: the keys go onto the new icons", keyOn(main2[1]) == "s" .. shiftB.wb.spot.label
		and keyOn(main2[2]) == plainKey and fs.__parent.__parent == main2A)
	M.fire("UPDATE_BINDINGS")
	M.fire("ACTIONBAR_SLOT_CHANGED", 1)
	M.fire("ACTIONBAR_SLOT_CHANGED", 2)
	check("bindings or slots changing: worked out again once, a frame later", #M.timers == 1)
	M.flushTimers()
	rawset(_G, "WarlockHudAPI", nil)
end

objMt.__index = baseIndex -- (the fake game as it was)
check("saved bindings never written", written == 0)
check("no errors", #M.errors == 0)
for _, e in ipairs(M.errors) do out(e) end
out(failures == 0 and "ALL OK" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
