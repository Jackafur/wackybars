-- The first load after the Nov 10 redesign (and a new character's first load): the plain keyboard, the plain mouse and
-- Hypershift on, the Shift, Ctrl and Alt copies off; WackyBars' own mouse over and fight settings, Lite and the game bars
-- box gone; spare slots of buttons that no longer exist dropped. Once only: what you switch on afterwards stays on.
-- Run: luajit tests/first_load_test.lua (from wow-wackybars)
local out = print
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
package.path = HERE .. "/../wow-addon-harness/?.lua;" .. package.path
local M = require("wowmock")
M.install()
local fails = 0
local function check(n, c) out(("%-74s %s"):format(n, c and "ok" or "FAILED")) if not c then fails = fails + 1 end end
local binds = { Q = "ACTIONBUTTON1", NUMPAD1 = "MULTIACTIONBAR7BUTTON10" }
local written = 0
rawset(_G, "GetBindingAction", function(k) return binds[k] or "" end)
rawset(_G, "GetBindingKey", function(cmd) for k, c in pairs(binds) do if c == cmd then return k end end end)
rawset(_G, "GetBindingText", function(k) return k end)
local acts = { [1] = true, [13] = true, [15] = true, [178] = true }
rawset(_G, "HasAction", function(s) return acts[s] or false end)
rawset(_G, "SetBinding", function() written = written + 1 end)
rawset(_G, "SaveBindings", function() written = written + 1 end)
rawset(_G, "SetOverrideBinding", function() end)
rawset(_G, "SetOverrideBindingClick", function() end)
rawset(_G, "ClearOverrideBindings", function() end)
rawset(_G, "RegisterStateDriver", function() end)
rawset(_G, "UnregisterStateDriver", function() end)
rawset(_G, "C_ActionBar", {})
rawset(_G, "RANGE_INDICATOR", "*")
local create = CreateFrame
rawset(_G, "CreateFrame", function(kind, name, parent, template)
	local f = create(kind, name, parent, template)
	if template == "ActionBarButtonTemplate" then
		rawset(f, "SetID", function(s, id) s.__id = id end)
		local hk = M.newObj("FontString", nil, f)
		rawset(hk, "SetText", function(s, t) s.__text = t end)
		rawset(f, "HotKey", hk)
	end
	return f
end)
for _, n in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }) do
	M.newObj("Frame", n)
end
-- A character's saved settings before (Nov 10, 02:39), shortened: all bars on, the Shift and Ctrl ones on mouse over.
WackyBarsCharDB = { hideGame = true, told = true, off = {}, keys = { PlainBlank1 = "B" }, hidden = {}, combatHide = {},
	mouseover = { Shift = true, Ctrl = true, MouseShift = true, MouseCtrl = true },
	spare = { PlainBlank1 = 13, MousePlainWheelUp = 83, PlainCaps = 15, Shift3 = 16 },
	pos = { Plain = { "TOPLEFT", "BOTTOMLEFT", 1029, 299 } }, scale = 1.1 }
dofile(HERE .. "/tests/fake_lab.lua")(M)
local ok, err = M.run(HERE .. "/WackyBars/WackyBars.lua", "WackyBars")
check("loads", ok) if not ok then out(err) os.exit(1) end
M.fire("ADDON_LOADED", "WackyBars")
M.fire("PLAYER_ENTERING_WORLD")
M.flushTimers()
local DB = WackyBarsCharDB
check("the plain keyboard, the plain mouse and Hypershift show", _G.WackyBarsPlain:IsShown() and _G.WackyBarsMousePlain:IsShown()
	and _G.WackyBarsMouseHyper:IsShown())
check("the Shift, Ctrl and Alt copies are off (mouse over ones too)", DB.off.Shift and DB.off.Ctrl and DB.off.Alt and DB.off.MouseShift
	and DB.off.MouseCtrl and DB.off.MouseAlt and not _G.WackyBarsShift:IsShown())
check("WackyBars' own mouse over, fight, Lite and game bar settings are gone", DB.mouseover == nil and DB.combatHide == nil
	and DB.hideGame == nil and DB.lite == nil and DB.v == 2)
check("spare slots and keys of buttons that no longer exist are dropped", DB.spare.PlainBlank1 == nil
	and DB.spare.MousePlainWheelUp == nil and DB.keys.PlainBlank1 == nil)
check("a kept button keeps its filled spare slot; your places stay", DB.spare.PlainCaps == 15 and DB.pos.Plain[3] == 1029)
check("the off bars take no spare slots", DB.spare.Shift3 == nil)
check("the old one size becomes each bar's size", DB.scale == nil and DB.sizes.Plain == 1.1 and DB.sizes.MouseHyper == 1.1)
check("Hypershift side 1 shows your Bar 8 slot (178)", _G.WackyBarsMouseHyperSide1.__attrs.action == 178)
check("the game's action bars are tucked away", _G.MainActionBar:GetParent() ~= UIParent and _G.MultiBar7:GetParent() ~= UIParent)
-- you switch the Shift copy on; the next load keeps it
DB.off.Shift = nil
M.fire("ADDON_LOADED", "WackyBars")
check("once only: a copy you switched on stays on", not DB.off.Shift)
check("saved bindings never written", written == 0)
check("no Lua errors", #M.errors == 0)
for _, e in ipairs(M.errors) do out(e) end
os.exit(fails == 0 and 0 or 1)
