-- QuietHUD's pixel shift (with the action bars ticked) moves WackyBars' bars, and puts them back when it is turned off.
local out = print
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
package.path = HERE .. "/../wow-addon-harness/?.lua;" .. package.path
local M = require("wowmock")
M.install()
local fails = 0
local function check(n, c) out(("%-60s %s"):format(n, c and "ok" or "FAILED")) if not c then fails = fails + 1 end end
local clock = 1000
rawset(_G, "GetTime", function() return clock end)
M.newObj("Frame", "WackyBars")
local bars = {}
for _, n in ipairs({ "WackyBarsPlain", "WackyBarsMouseCtrl" }) do
	local f = M.newObj("Frame", n, _G.WackyBars)
	f.__points = { { "BOTTOMLEFT", UIParent, "BOTTOM", -200, 140 } }
	rawset(f, "GetNumPoints", function(s) return #s.__points end)
	bars[#bars + 1] = f
end
QuietHUDDB = { settingsVersion = 1, pixelShift = true, shiftBars = true, shiftPixels = 4, shiftMinutes = 1 }
local ok, err = M.run(HERE .. "/../wow-quiethud/QuietHUD/QuietHUD.toc", "QuietHUD", {})
check("QuietHUD loads", ok) if not ok then out(err) os.exit(1) end
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_MACROS" }) do M.fire(e, "QuietHUD") end
local function run(seconds) for _ = 1, math.floor(seconds / 0.1) do clock = clock + 0.1; M.tick(1, 0.1) end end
local seen = { false, false }
for _ = 1, 6 do
	run(65)
	for i, f in ipairs(bars) do
		local p = f.__points[1]
		seen[i] = seen[i] or (p[4] ~= -200 or p[5] ~= 140)
	end
end
check("the plain keyboard bar moves with the pixel shift", seen[1])
check("the Ctrl mouse bar too", seen[2])
SlashCmdList["QUIETHUD"]("shift off")
run(1)
local p = bars[1].__points[1]
check("shift off puts it back exactly", p[4] == -200 and p[5] == 140)
check("no Lua errors", #M.errors == 0)
for _, e in ipairs(M.errors) do out(e) end
os.exit(fails == 0 and 0 or 1)
