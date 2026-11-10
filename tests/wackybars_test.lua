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
		for _, k in ipairs({ "IconMask", "Flash", "Border", "SpellHighlightTexture" }) do rawset(f, k, M.newObj("Texture", nil, f)) end
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
local ok, err = M.run(HERE .. "/WackyBars/WackyBars.lua", "WackyBars")
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
check("the pet bar stays the game's", _G.PetActionBar == nil or _G.PetActionBar:GetParent() == UIParent)

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
caps.Border:SetSize(46, 45)
LibStub("LibActionButton-1.0").callbacks.OnButtonUpdate("OnButtonUpdate", caps)
check("after a library update Caps' glow is two keys wide again", caps.Border.__w and caps.Border.__w > 46 * 1.5)
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

-- The options: a box per bar (keyboard and mouse side by side, a row per modifier), Hypershift under them.
local boxes = {}
for _, f in ipairs(M.frames) do
	if f.__parent == _G.WackyBarsOptions and f.__template == "UICheckButtonTemplate" then boxes[#boxes + 1] = f end
end
local shiftBox = boxes[3] -- (Plain keyboard, Plain mouse, Shift keyboard, ...)
shiftBox.__scripts.OnClick(shiftBox)
check("the Shift keyboard box switches that bar off", DB.off.Shift and not _G.WackyBarsShift:IsShown())
shiftBox.__scripts.OnClick(shiftBox)
check("and on again", not DB.off.Shift and _G.WackyBarsShift:IsShown())
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

check("saved bindings never written", written == 0)
check("no errors", #M.errors == 0)
for _, e in ipairs(M.errors) do out(e) end
out(failures == 0 and "ALL OK" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
