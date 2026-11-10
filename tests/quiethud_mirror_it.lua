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
M.newObj("Frame", "PetActionBar")
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
check("Click through on Bar 8 alone: the pet bar (its own row since Nov 10) still takes clicks", pet1.__clicks ~= false)
QuietHUDDB.barClicks = 256 + 9
QuietHUD_RefreshBarClicks()
check("the Pet bar row's own Click through: its buttons take no clicks", pet1.__clicks == false)
QuietHUDDB.barClicks = 9
QuietHUD_RefreshBarClicks()
check("Pet bar unticked: it takes clicks again", pet1.__clicks == true)
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
-- QuietHUD's Show with Alt column (Nov 10; WackyBars' Alt tab before): a row unticked carries on as if the whole HUD were not
-- shown: Alt neither brings it up nor stops it mid fade; the other rows come up.
local before = h1.__alpha
QuietHUDDB.barPeek = 511 - 1 -- (Bar 1, Q's row, unticked)
QuietHUDDB.peekAlt = true
rawset(_G, "IsAltKeyDown", function() return true end)
run(2)
check("Alt held: Bar 8 comes up, Bar 1 (Show with Alt unticked) stays (" .. tostring(before) .. ")", MultiBar7.__alpha > 0.5
	and h1.__alpha == before and MainActionBar.__alpha == before)
rawset(_G, "IsAltKeyDown", function() return false end)
run(3)
check("Alt let go: Bar 1 never flashed up", h1.__alpha == before)
overQ = true
run(2)
check("the mouse on Q still brings Bar 1 up", h1.__alpha > 0.5)
overQ = false
run(0.3)
local midQ = h1.__alpha
rawset(_G, "IsAltKeyDown", function() return true end)
run(3)
check(("Alt pressed while Bar 1 fades: it keeps fading (%.2f -> %.2f), Bar 8 up"):format(midQ, h1.__alpha),
	midQ > 0.05 and h1.__alpha < 0.05 and MultiBar7.__alpha > 0.5)
rawset(_G, "IsAltKeyDown", function() return false end)
run(4)
-- A Mouse over only row unticked (his Hypershift, Nov 10): only the mouse brings it up, Alt or not.
QuietHUDDB.barPeek = 511 - 8 -- (Bar 4, the thumb's row)
overQ = true
run(2)
local b4 = h4.__alpha
check("group up by Q's hover: the Mouse over thumb stays down (" .. tostring(b4) .. ")", b4 < 0.5 and h1.__alpha > 0.5)
rawset(_G, "IsAltKeyDown", function() return true end)
run(2)
check("Alt held with the group up: the thumb's row stays", h4.__alpha == b4)
overQ = false
rawset(_G, "IsAltKeyDown", function() return false end)
run(4)
over = true
run(2)
check("the mouse on the thumb: up", h4.__alpha > 0.5)
over = false
run(0.1)
local mid = h4.__alpha
rawset(_G, "IsAltKeyDown", function() return true end)
run(2)
check("Alt pressed mid fade: it keeps fading down, no freeze (" .. tostring(mid) .. " -> " .. tostring(h4.__alpha) .. ")",
	h4.__alpha < mid and h4.__alpha < 0.05)
over = true
run(2)
check("mouse on it while Alt is held: it comes up", h4.__alpha > 0.5)
over = false
run(3)
check("mouse gone, Alt still held: it fades again", h4.__alpha < 0.05)
check("... while the rest of the HUD shows for Alt", MultiBar7.__alpha > 0.5)
rawset(_G, "IsAltKeyDown", function() return false end)
QuietHUDDB.barPeek = 511
run(3)
-- The pet bar's own Shown (Opacity page, Pet bar): it fades with the Action bars, up to its own opacity.
QuietHUDDB.ovPetBar = 0.4
overQ = true
run(2)
check(("bars up: the pet bar at its own 0.40 (%.2f), Action Bar 1 at the bars' (%.2f)"):format(PetActionBar.__alpha,
	MainActionBar.__alpha), math.abs(PetActionBar.__alpha - 0.4) < 0.01 and MainActionBar.__alpha > 0.5)
overQ = false
run(4)
check("bars down: the pet bar down with them", PetActionBar.__alpha < 0.05)
QuietHUDDB.ovPetBar = 0
overQ = true
run(2)
check("Pet bar at 0 (Action bars): the bars' opacity", math.abs(PetActionBar.__alpha - MainActionBar.__alpha) < 0.01)
overQ = false
run(4)
-- "Mouse over only bars come up together" (QuietHUD's Action bars page, Nov 10): Bars 4 and 8 Mouse over only; the mouse
-- on the thumb (Bar 4) brings the items (Bar 8) up too, only with the box ticked.
QuietHUDDB.barMouse = 8 + 128
run(3)
over = true
run(2)
check("box unticked: the mouse on the thumb brings only Bar 4 up", h4.__alpha > 0.5 and h8.__alpha < 0.5)
QuietHUDDB.mouseTogether = true
run(2)
check("box ticked: the items' bar (Bar 8) comes up with it", h4.__alpha > 0.5 and h8.__alpha > 0.5)
check("... and Bar 1 (no Mouse over only) stays down", h1.__alpha < 0.5)
over = false
run(4)
check("mouse gone: both fade back", h4.__alpha < 0.5 and h8.__alpha < 0.5)
-- Audit 2026-11-10 evening fixes.
-- (1) QuietHUD switched off while the pet bar (own Shown) and a Show with bar are faded: every bar back at 1.
QuietHUDDB.ovPetBar, QuietHUDDB.barPeek = 0.5, 511 - 1
run(6)
QuietHUDDB.enabled = false
run(3)
check(("QuietHUD off while faded: the pet bar (%.2f) and the Show with bar (%.2f) are back at 1"):format(PetActionBar.__alpha,
	h1.__alpha), PetActionBar.__alpha == 1 and h1.__alpha == 1)
QuietHUDDB.enabled = true
run(6)
-- (2) The whole HUD held up with a Show with bar unticked: once settled, the bars are not written every update.
local writes = 0
local realSet = MultiBar7.SetAlpha
rawset(MultiBar7, "SetAlpha", function(f, v) writes = writes + 1 return realSet(f, v) end)
rawset(_G, "IsAltKeyDown", function() return true end)
run(3)
writes = 0
run(2)
check(("Alt held 2 s more, settled: Bar 8 written %d times (not every update)"):format(writes), writes <= 2)
rawset(_G, "IsAltKeyDown", function() return false end)
rawset(MultiBar7, "SetAlpha", nil)
run(4)
-- (3) No way to show the whole HUD set: an old untick counts for nothing (the column is hidden then).
QuietHUDDB.peekAlt = false
SlashCmdList["QUIETHUD"]("peek")
run(2)
check("nothing set on the Show when page: /qhud peek shows Bar 1 (unticked earlier) too", h1.__alpha > 0.5)
SlashCmdList["QUIETHUD"]("peek")
run(4)
QuietHUDDB.peekAlt, QuietHUDDB.barPeek, QuietHUDDB.ovPetBar = true, 511, 0
run(2)
-- The Action bars page names each row after the WackyBars bars on it; a row with none keeps its game name (greyed).
SlashCmdList["QUIETHUD"]("")
local texts = {}
for _, f in ipairs(M.frames) do if f.__text then texts[f.__text] = f end end
check("rows named after WackyBars: Keyboard (Bar 1), Mouse (Bar 4), Hypershift (Bar 8), Pet bar",
	texts["Keyboard"] and texts["Mouse"] and texts["Hypershift"] and texts["Pet bar"] and not texts["Action Bar 1"])
check("a row with no WackyBars bar keeps its game name (Action Bar 2)", texts["Action Bar 2"] ~= nil)
local peekHead
for _, f in ipairs(M.frames) do if f.__text and f.__text:find("^Show with") then peekHead = f end end
check("the last column is named after the way set: Show with Alt", peekHead and peekHead.__text == "Show with\nAlt"
	and peekHead.__shown ~= false)
-- (untick "While I hold Alt" on the Show when page, as a click: the column follows at once)
local altBox
for _, f in ipairs(M.frames) do
	if f.__text == "While I hold Alt" and f.__points[1] then altBox = f.__points[1][2] end
end
local clickHead
for _, f in ipairs(M.frames) do if f.__text == "Click\nthrough" then clickHead = f end end
local function xOf(f) return f.__points[1] and f.__points[1][4] end
local clickX = xOf(clickHead)
altBox.__scripts.OnClick(altBox)
check("nothing set on the Show when page: the column is gone", QuietHUDDB.peekAlt == false and peekHead.__shown == false)
check(("  and the columns after it close up (Click through %s -> %s)"):format(tostring(clickX), tostring(xOf(clickHead))),
	xOf(clickHead) == clickX - 64)
altBox.__scripts.OnClick(altBox)
check("ticked again: back, Show with Alt", QuietHUDDB.peekAlt == true and peekHead.__shown ~= false)
check("  and they open up again", xOf(clickHead) == clickX)
check("no Lua errors", #M.errors == 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
os.exit(fails == 0 and 0 or 1)
