-- QuietHUD treats a WackyBars button like the buttons of the game bar whose slot it shows (WackyBars puts it in that bar's
-- holder, WackyBarsHold<bar><n>): Fade with the group, a Mouse over bar up only under the mouse, Hide hotkeys, Bar 8 with
-- its own settings. The "WackyBars" frame itself is no longer faded (no double fade).
-- Run: luajit tests/quiethud_mirror_it.lua (from wow-wackybars)
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
package.path = HERE .. "/../wow-addon-harness/?.lua;" .. package.path
local M = require("wowmock")
M.install()
local fails = 0
local function check(n, c) io.write(("%-70s %s\n"):format(n, c and "ok" or "FAILED")) if not c then fails = fails + 1 end end
local clock = 1000
rawset(_G, "GetTime", function() return clock end)
local wb = M.newObj("Frame", "WackyBars")
M.newObj("Frame", "MultiBar7")
local function holder(name, buttonName)
	local h = M.newObj("Frame", name, wb)
	local b = M.newObj("CheckButton", buttonName, h)
	rawset(b, "HotKey", M.newObj("FontString", buttonName .. "HotKey", b))
	b.__shown = true
	h.qhudButtons = { b }
	return h, b
end
local h1, q = holder("WackyBarsHoldPlain1", "WackyBarsPlainQ") -- Q shows Action Bar 1
local h4, side1 = holder("WackyBarsHoldMousePlain4", "WackyBarsMousePlainSide1") -- a thumb shows Action Bar 4
local h8 = holder("WackyBarsHoldMouseHyper8", "WackyBarsMouseHyperSide1") -- an item shows Action Bar 8
local over, overQ = false, false
rawset(side1, "IsMouseOver", function() return over end)
-- (QuietHUD asks the holders' parent, the WackyBars bar, first: it is under the mouse whenever one of its buttons is)
rawset(wb, "IsMouseOver", function() return over or overQ end)
-- Action Bar 4: Mouse over; Action Bar 1: Hide hotkeys (bits are bars 1 to 8)
QuietHUDDB = { settingsVersion = 1, barMouse = 8, barHotkeys = 1, barClicks = 9 }
local pet1 = M.newObj("CheckButton", "PetActionButton1")
for _, b in ipairs({ q, side1, pet1 }) do
	rawset(b, "SetMouseClickEnabled", function(s, v) s.__clicks = v; s.__clickWrites = (s.__clickWrites or 0) + 1 end)
	rawset(b, "IsMouseClickEnabled", function(s) return s.__clicks ~= false end) -- (QuietHUD asks the button itself)
end
local ok, err = M.run(HERE .. "/../wow-quiethud/QuietHUD/QuietHUD.toc", "QuietHUD", {})
check("QuietHUD loads", ok) if not ok then io.write(err, "\n") os.exit(1) end
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }) do M.fire(e, "QuietHUD") end
local function run(s) for _ = 1, math.floor(s / 0.05) do clock = clock + 0.05; M.tick(1, 0.05) end end
run(10)
io.write(("idle: Q's holder %s (Action Bar 1 %s), thumb's %s, items' %s (Bar 8 %s), WackyBars %s\n"):format(tostring(h1.__alpha),
	tostring(MainActionBar.__alpha), tostring(h4.__alpha), tostring(h8.__alpha), tostring(MultiBar7.__alpha), tostring(wb.__alpha)))
check("idle: Q's holder faded like Action Bar 1", h1.__alpha < 1 and h1.__alpha == MainActionBar.__alpha)
check("idle: the items' holder like Action Bar 8", h8.__alpha == MultiBar7.__alpha)
check("the WackyBars frame itself is not faded (no double fade)", (wb.__alpha or 1) == 1)
check("Hide hotkeys on Action Bar 1: Q's hotkey hidden", q.HotKey.__alpha == 0)
check("Click through on Bars 1 and 4: Q and the thumb never take clicks", q.__clicks == false and side1.__clicks == false)
QuietHUDDB.barClicks = 128 + 9
QuietHUD_RefreshBarClicks()
check("the pet bar goes with Action Bar 8's Click through", pet1.__clicks == false)
QuietHUDDB.barClicks = 9
QuietHUD_RefreshBarClicks()
check("Bar 8 unticked: the pet bar takes clicks", pet1.__clicks == true)
q.__clickWrites = 0
QuietHUD_RefreshBarClicks()
check("applied again with nothing changed: no click write (on change only)", q.__clickWrites == 0)
q.__clicks = true -- (something else switches Q's clicks back on)
QuietHUD_RefreshBarClicks()
check("Q's clicks switched back on by something else: off again at the next apply", q.__clicks == false)
-- WackyBars sorts a new button into a holder after QuietHUD's rebuild: it gets its hover hook at the refresh.
local late = M.newObj("CheckButton", "WackyBarsPlainE", h1)
local hooked = {}
rawset(late, "HookScript", function(_, script) hooked[script] = true end)
h1.qhudButtons = { q, late }
QuietHUD_RefreshBarClicks()
check("a button WackyBars sorted in after the rebuild gets its hover hook", hooked.OnEnter and hooked.OnLeave)
h1.qhudButtons = { q }
over = true
run(2)
check("mouse on the thumb (Bar 4, Mouse over): its holder comes up", h4.__alpha > 0.5)
check("... and still takes no clicks while shown (never)", side1.__clicks == false)
-- only Action Bar 1 ticked: Bar 4's thumb takes clicks again
QuietHUDDB.barClicks = 1
QuietHUD_RefreshBarClicks()
check("Click through only on Bar 1: Q takes no clicks, the Bar 4 thumb does", q.__clicks == false and side1.__clicks == true)
QuietHUDDB.barClicks = 9
QuietHUD_RefreshBarClicks()
check("... and Action Bar 1's stay faded (Mouse over does not wake the rest)", h1.__alpha == MainActionBar.__alpha and h1.__alpha < 0.5)
over = false
run(3)
check("mouse gone: it fades again", h4.__alpha < 0.5)
rawset(q, "IsMouseOver", function() return overQ end)
overQ = true
run(2)
check("mouse on Q (Bar 1, no Mouse over of its own): the action bars come up", h1.__alpha > 0.5)
overQ = false
run(4)
rawset(_G, "UnitAffectingCombat", function() return true end)
M.fire("PLAYER_REGEN_DISABLED") -- (the game sends it just before the lock)
rawset(_G, "InCombatLockdown", function() return true end)
run(2)
check("in a fight: Q's holder up with Action Bar 1", h1.__alpha > 0.5 and h1.__alpha == MainActionBar.__alpha)
check("in a fight they still take no clicks (set before, it holds)", q.__clicks == false)
-- WackyBars' "Show when QuietHUD shows the whole HUD" unticked: holding Alt leaves its holders where they are.
rawset(_G, "UnitAffectingCombat", function() return false end)
rawset(_G, "InCombatLockdown", function() return false end)
M.fire("PLAYER_REGEN_ENABLED")
run(12)
local before = h1.__alpha
h1.qhudNoPeek = true
QuietHUDDB.peekAlt = true
rawset(_G, "IsAltKeyDown", function() return true end)
run(2)
check("Alt held: the game bars come up, the no-peek holder stays (" .. tostring(before) .. ")", MainActionBar.__alpha > 0.5
	and h1.__alpha == before)
rawset(_G, "IsAltKeyDown", function() return false end)
run(3)
check("Alt let go: it never flashed up, the bars are back down", h1.__alpha == before and MainActionBar.__alpha == before)
check("no Lua errors", #M.errors == 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
os.exit(fails == 0 and 0 or 1)
