-- Hypershift while held (his ask, Nov 12): on the Naga's blue profile the Hypershift button is a key of its own, held while
-- you hold it, and the side buttons, edges and wheel click send their plain keys. xremap turns that key (F14, which WoW under
-- Wine can't see, like F13) into End in games (~/.config/xremap/config.yml, "games hypershift held"). While End is down,
-- the plain mouse keys press the Hypershift bar's buttons: side 1 does what Hypershift side 1 shows, E1 and E2 and the wheel
-- click do the Hypershift bar's E1, E2 and M. Let go, they are the plain ones again. With the box in /wbars ticked (the
-- default) the Hypershift bar shows only while End is held. QuietHUD fades it with the Action Bar 8 row as always, so it
-- comes up at QuietHUD's opacity (his ask, Nov 12: "follows qhuds transparency").
-- On the green and red profiles the mouse never sends End, so nothing here happens; untick the box there to keep the
-- Hypershift bar on screen as before.
-- In a fight too: the held key presses a secure button whose snippet sets and clears the keys (the game's override bindings,
-- never your saved ones) and shows and hides the bar; WackyBars only fills in its table out of a fight (after each apply).
-- What each key does while held: a button showing a game bar's slot or a pet slot fires that bar's own command (paging,
-- stealth and the pet bar as with the Numpad key); a button with a spare slot is clicked; a Numpad key bound to something
-- else (a macro, another addon's key) does that; an empty or hidden spot does nothing while held.
-- Cost: nothing runs until the key is pressed; then one snippet on press and one on release. No OnUpdate, no events.
-- Shift and Ctrl bars while held (his ask, Nov 12: "holding shift brings up the shift keyboard and mouse action bars"): with
-- a Shift or Ctrl copy switched on in /wbars and the second box there ticked (the default), the keyboard and mouse copies of
-- that modifier show only while you hold it, through the game's own state driver ([mod:shift] / [mod:ctrl]), so in a fight
-- too. QuietHUD fades them with their rows as always. Typing a capital in chat brings the Shift bars up for that moment.
-- Cost: the game's state driver (already running for the game's own bars) checks one macro condition per copy that is on,
-- every 0.2 seconds and on each modifier change. Edit keys and Move bars show them.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local HELD = "END" -- (what xremap sends for the Naga's Hypershift on blue)

local hold = CreateFrame("Button", "WackyBarsHyperHold", nil, "SecureHandlerClickTemplate")
hold:RegisterForClicks("AnyDown", "AnyUp")
hold:EnableMouse(false)
hold:SetAttribute("_onclick", [=[
	local bar = self:GetFrameRef("bar")
	if down then
		if self:GetAttribute("held") then return end -- (the key repeating while held)
		self:SetAttribute("held", true)
		for i = 1, self:GetAttribute("count") or 0 do
			local key, cmd = self:GetAttribute("key" .. i), self:GetAttribute("cmd" .. i)
			if cmd then
				self:SetBinding(true, key, cmd)
			else
				self:SetBindingClick(true, key, self:GetAttribute("click" .. i), "Keybind")
			end
		end
		if bar and self:GetAttribute("hide") then bar:Show() end
	else
		self:SetAttribute("held", nil)
		self:ClearBindings()
		if bar and self:GetAttribute("hide") then bar:Hide() end
	end
]=])
local keyOwner = CreateFrame("Frame") -- (End's own binding: kept apart, the snippet clears only the held keys)

local function bars()
	local hyper, mouse
	for _, bar in ipairs(wb.bars) do
		if bar.id == "MouseHyper" then hyper = bar elseif bar.id == "MousePlain" then mouse = bar end
	end
	return hyper, mouse
end
local function onHold()
	local DB = wb.db()
	local hyper = bars()
	return DB and hyper and wb.barOn(hyper) and not DB.hyperAlways or false
end
-- What the snippet needs, out of a fight, after each apply: per Hypershift spot, the plain mouse key of the same spot (the
-- key the mouse really sends) and what it does while held.
local function fill()
	if InCombatLockdown() then return end
	local DB = wb.db()
	local hyper, mouse = bars()
	ClearOverrideBindings(keyOwner)
	ClearOverrideBindings(hold)
	hold:SetAttribute("held", nil)
	local n = 0
	if DB and hyper and mouse and wb.barOn(hyper) then
		local keyOf = {}
		for _, b in ipairs(mouse.buttons) do keyOf[b.wb.spot.name] = b.wb.spot.key end
		for _, b in ipairs(hyper.buttons) do
			local q = b.wb
			local key, name = keyOf[q.spot.name], q.spot.name
			local gone = (DB.noEdges and (name == "Edge1" or name == "Edge2")) or (DB.noWheel and name == "Wheel")
			if key and not gone then
				local cmd, click
				if DB.hidden[q.id] then
					click = "WackyBarsNone"
				elseif (q.kind == "mirror" or q.kind == "pet") and q.cmd then
					cmd = q.cmd
				elseif q.kind == "other" and q.other and not wb.effKey(b) then
					cmd = q.other
				elseif q.slot then
					click = b:GetName()
				else
					click = "WackyBarsNone"
				end
				n = n + 1
				hold:SetAttribute("key" .. n, key)
				hold:SetAttribute("cmd" .. n, cmd)
				hold:SetAttribute("click" .. n, click)
			end
		end
		hold:SetFrameRef("bar", hyper.frame)
		SetOverrideBindingClick(keyOwner, false, HELD, "WackyBarsHyperHold")
	end
	hold:SetAttribute("count", n)
	hold:SetAttribute("hide", onHold())
	if hyper then hyper.wbHeld = onHold() end
	-- shown only while held, Edit keys and Move bars aside (you need to see it there)
	if hyper and onHold() and not (wb.editing() or wb.moving()) then hyper.frame:Hide() end
end
wb.applyHooks[#wb.applyHooks + 1] = fill
wb.modeHooks[#wb.modeHooks + 1] = function()
	if InCombatLockdown() or not onHold() then return end
	local hyper = bars()
	hyper.frame:SetShown(wb.moving() or wb.editing())
end

wb.optionRows[#wb.optionRows + 1] = {
	label = "Hypershift bar only while you hold Hypershift (Naga blue profile)",
	tab = "held", group = "Bars that show only while you hold a key",
	get = function() local DB = wb.db() return DB and not DB.hyperAlways end,
	set = function(v) wb.db().hyperAlways = (not v) or nil end,
}

-- Shift and Ctrl: the copy bars of each, on a state driver while the box is ticked (out of a fight, after each apply and
-- each mode change; the driver itself works in a fight).
-- The Alt keyboard bar too, only with its own box ticked (off by default, so nobody else's Alt bar changes: his "i dont want
-- my weird alt, ctrl, shift rules messing with them", Nov 24). His reason: "how do we make it so alt bar isnt shown when I
-- hold ~" (~ is QuietHUD's show all, which brought the always-shown Alt bar up with everything). The Alt mouse bar (the pet
-- bar) is never held.
local MOD_HELD = { Shift = "[mod:shift] show; hide", MouseShift = "[mod:shift] show; hide", Ctrl = "[mod:ctrl] show; hide",
	MouseCtrl = "[mod:ctrl] show; hide", Alt = "[mod:alt] show; hide" }
local function fillMods()
	if InCombatLockdown() then return end
	local DB = wb.db()
	local showAll = wb.editing() or wb.moving()
	for _, bar in ipairs(wb.bars) do
		local rule = MOD_HELD[bar.id]
		if rule then
			UnregisterStateDriver(bar.frame, "visibility")
			local wanted = DB and (bar.id == "Alt" and DB.altHeld or (bar.id ~= "Alt" and not DB.modsAlways))
			bar.wbHeld = DB and wb.barOn(bar) and wanted and true or false
			if bar.wbHeld and not showAll then
				RegisterStateDriver(bar.frame, "visibility", rule)
			else
				bar.frame:SetShown(wb.barOn(bar))
			end
		end
	end
end
-- QuietHUD is told when a held bar shows and goes (QuietHUD_HeldBar): with your idle opacity at 0 or its row Mouse over only it
-- would come up invisible, so while held its holders sit at the Action bars' Shown, as under the mouse. Only while the bar
-- shows because its key is held (wbHeld), not in Edit keys or Move bars (at full there anyway). OnShow and OnHide run when the
-- game shows or hides the bar, so in a fight too; nothing runs between.
local function tell(bar, on)
	if QuietHUD_HeldBar then pcall(QuietHUD_HeldBar, bar.holders, on) end
end
-- (holding Alt with the Alt bar held also brings up the Alt mouse bar, your pet bar, which itself always shows and fades
-- with QuietHUD as before: his "alt should show the pet menu to", Nov 24)
local mouseAlt
for _, bar in ipairs(wb.bars) do if bar.id == "MouseAlt" then mouseAlt = bar end end
for _, bar in ipairs(wb.bars) do
	if bar.id == "MouseHyper" or MOD_HELD[bar.id] or bar.set.held then
		bar.frame:HookScript("OnShow", function()
			if bar.wbHeld and not (wb.editing() or wb.moving()) then
				tell(bar, true)
				if bar.id == "Alt" and mouseAlt and wb.barOn(mouseAlt) then tell(mouseAlt, true) end
			end
		end)
		bar.frame:HookScript("OnHide", function()
			tell(bar, false)
			if bar.id == "Alt" and mouseAlt then tell(mouseAlt, false) end
		end)
	end
end
wb.applyHooks[#wb.applyHooks + 1] = fillMods
wb.modeHooks[#wb.modeHooks + 1] = fillMods
wb.optionRows[#wb.optionRows + 1] = {
	label = "Shift and Ctrl bars only while you hold Shift or Ctrl",
	tab = "held", group = "Bars that show only while you hold a key",
	get = function() local DB = wb.db() return DB and not DB.modsAlways end,
	set = function(v) wb.db().modsAlways = (not v) or nil end,
}
wb.optionRows[#wb.optionRows + 1] = {
	label = "Alt keyboard bar only while you hold Alt",
	tab = "held", group = "Bars that show only while you hold a key",
	get = function() local DB = wb.db() return DB and DB.altHeld and true or false end,
	set = function(v) wb.db().altHeld = v and true or nil end,
}

-- The Caps bars (his ask, Nov 26, after a focus target video: "i wish there was another modifier key", "add a caps action bar to
-- wbars? for keyboard and mouse?"). The game knows three modifiers and all three are taken, so this one is made here: while
-- the Caps key is held, each plain key that fires a bar slot presses its twin on the Caps bars instead (WackyBars.lua: same
-- spot, same slot, pages too), and the twins cast on your focus while you have one. So Caps + a key is that key's spell on
-- your focus; with no focus set it is the plain spell, on your target. Let go and every key is the plain one again. Keys
-- that do something else (moving, Interact, the pet bar, a key you hid) are left alone while held. Shift, Ctrl and Alt + key
-- keep their own jobs. The two bars show only while the key is held (and in Edit keys and Move bars).
-- The key: the one on your Caps button (Edit keys), else CAPSLOCK; /wbars capskey KEY names another. His keyboard sends Page Up
-- for Caps over games (xremap), which is what his Caps button holds.
-- In a fight too: as with Hypershift, a secure button's snippet sets and clears the keys (override bindings, never saved
-- ones) and shows and hides the bars. Who the twins cast on is one state check of the game's ([@focus,exists]): when a
-- focus comes or goes, a second snippet writes "focus" or nothing into each twin's unit, which is where the game's own
-- button code looks first. WackyBars fills both in out of a fight, after each apply.
-- Cost: nothing until the key is pressed, then one snippet on press and one on release; the focus check is the game's state
-- driver, one condition while the box is ticked. Box unticked: no key taken, no check, the bars don't exist.
local capsHold = CreateFrame("Button", "WackyBarsCapsHold", nil, "SecureHandlerClickTemplate")
capsHold:RegisterForClicks("AnyDown", "AnyUp")
capsHold:EnableMouse(false)
capsHold:SetAttribute("_onclick", [=[
	if down then
		if self:GetAttribute("held") then return end -- (the key repeating while held)
		self:SetAttribute("held", true)
		for i = 1, self:GetAttribute("count") or 0 do
			self:SetBindingClick(true, self:GetAttribute("key" .. i), self:GetAttribute("click" .. i), "Keybind")
		end
	else
		self:SetAttribute("held", nil)
		self:ClearBindings()
	end
	-- (Caps + Shift or Ctrl: the Shift and Ctrl copy buttons cast on your focus only while the key is down)
	local uf = self:GetFrameRef("unitframe")
	local unit = (down and uf and uf:GetAttribute("state-wbfocus") == "focus") and "focus" or nil
	for i = 1, self:GetAttribute("copies") or 0 do
		local b = self:GetFrameRef("c" .. i)
		if b then b:SetAttribute("unit", unit) end
	end
	for i = 1, 2 do
		local bar = self:GetFrameRef("bar" .. i)
		if bar then
			if down then bar:Show() else bar:Hide() end
		end
	end
]=])
local capsUnit = CreateFrame("Frame", "WackyBarsCapsUnit", nil, "SecureHandlerStateTemplate")
capsUnit:SetAttribute("_onstate-wbfocus", [=[
	local unit = newstate == "focus" and "focus" or nil
	for i = 1, self:GetAttribute("count") or 0 do
		local b = self:GetFrameRef("b" .. i)
		if b then b:SetAttribute("unit", unit) end
	end
	-- (a focus that comes or goes while the key is down: the Shift and Ctrl copy buttons follow too)
	local hold = self:GetFrameRef("hold")
	if hold and hold:GetAttribute("held") then
		for i = 1, self:GetAttribute("copies") or 0 do
			local b = self:GetFrameRef("c" .. i)
			if b then b:SetAttribute("unit", unit) end
		end
	end
]=])
-- Caps + Shift and Caps + Ctrl (his ask, Nov 26: "how does it handle caps+shift for mana drain?", then "yea i think we add
-- that"): the Shift and Ctrl copy bars, keyboard and mouse, need no twins. Their own buttons already show what Shift + key
-- and Ctrl + key fire, and no key presses them (the keys go through the game's bars). While the Caps key is down those keys
-- press them, and for just that long they cast on your focus. Needs the Shift or Ctrl bar switched on in /wbars. Alt + key is
-- never touched (his Alt layer is jobs and the pet bar).
local COPY_LAYER = { Shift = true, MouseShift = true, Ctrl = true, MouseCtrl = true }
local CAPS_FOCUS = "[@focus,exists] focus; none"
local capsKeyOwner = CreateFrame("Frame") -- (the held key's own binding, kept apart from the keys the snippet sets and clears)
local capsDriven = false

local function capsBars()
	local list = {}
	for _, bar in ipairs(wb.bars) do if bar.set.held then list[#list + 1] = bar end end
	return list
end
-- The key you hold: one you named, else the one on your Caps button, else the Caps key itself.
local function capsKey()
	local DB = wb.db()
	local k = DB and (DB.capsKey or (DB.keys and DB.keys.PlainCaps))
	return type(k) == "string" and k ~= "" and k or "CAPSLOCK"
end
local function fillCaps()
	if InCombatLockdown() then return end
	local DB = wb.db()
	local on = DB and DB.capsHold and true or false
	local showAll = wb.editing() or wb.moving()
	ClearOverrideBindings(capsKeyOwner)
	ClearOverrideBindings(capsHold)
	capsHold:SetAttribute("held", nil)
	local n, u = 0, 0
	local unit = (on and UnitExists and UnitExists("focus")) and "focus" or nil
	for i, bar in ipairs(capsBars()) do
		for _, b in ipairs(bar.buttons) do
			local q = b.wb
			-- (who a twin casts on: your focus while the box is ticked and you have one; nothing written otherwise)
			if b:GetAttribute("unit") ~= unit then b:SetAttribute("unit", unit) end
			u = u + 1
			capsUnit:SetFrameRef("b" .. u, b)
			if on and q.slot and q.twinKey and not DB.hidden[q.id] then
				n = n + 1
				capsHold:SetAttribute("key" .. n, q.twinKey)
				capsHold:SetAttribute("click" .. n, b:GetName())
			end
		end
		-- (handed to the snippet only while the bars come and go with the key: in Edit keys and Move bars they stay up)
		if on and not showAll then capsHold:SetFrameRef("bar" .. i, bar.frame) else capsHold:SetAttribute("frameref-bar" .. i, nil) end
		bar.wbHeld = on
		if on then bar.frame:SetShown(showAll) end
	end
	local c = 0
	for _, bar in ipairs(wb.bars) do
		if COPY_LAYER[bar.id] then
			for _, b in ipairs(bar.buttons) do
				local q = b.wb
				-- (out of a fight a copy button never keeps a focus from here)
				if b:GetAttribute("unit") ~= nil then b:SetAttribute("unit", nil) end
				local key = on and q.slot and (q.kind == "mirror" or q.kind == "free") and wb.effKey(b) or nil
				if key then
					n = n + 1
					capsHold:SetAttribute("key" .. n, key)
					capsHold:SetAttribute("click" .. n, b:GetName())
					c = c + 1
					capsHold:SetFrameRef("c" .. c, b)
					capsUnit:SetFrameRef("c" .. c, b)
				end
			end
		end
	end
	capsHold:SetFrameRef("unitframe", capsUnit)
	capsUnit:SetFrameRef("hold", capsHold)
	capsHold:SetAttribute("copies", c)
	capsUnit:SetAttribute("copies", c)
	capsHold:SetAttribute("count", n)
	capsUnit:SetAttribute("count", on and u or 0)
	if on then
		-- (priority: it wins over the Caps button's own key, which is the same key)
		SetOverrideBindingClick(capsKeyOwner, true, capsKey(), "WackyBarsCapsHold")
		if not capsDriven then
			RegisterStateDriver(capsUnit, "wbfocus", CAPS_FOCUS)
			capsDriven = true
		end
	elseif capsDriven then
		UnregisterStateDriver(capsUnit, "wbfocus")
		capsDriven = false
	end
end
wb.applyHooks[#wb.applyHooks + 1] = fillCaps
wb.modeHooks[#wb.modeHooks + 1] = fillCaps
wb.optionRows[#wb.optionRows + 1] = {
	label = "Caps bars: hold Caps and your keys cast on your focus",
	tab = "held", group = "Focus", hint = "Another key to hold: /wbars capskey KEY",
	get = function() local DB = wb.db() return DB and DB.capsHold and true or false end,
	set = function(v) wb.db().capsHold = v and true or nil end,
}
-- /wbars capskey KEY: another key to hold (as the game names it: CAPSLOCK, PAGEUP, BUTTON4 ...); /wbars capskey: back to the
-- one on your Caps button.
wb.slash.capskey = function(rest)
	if InCombatLockdown() then wb.say("after the fight.") return end
	local DB = wb.db()
	local k = (rest or ""):upper():gsub("%s+", "")
	DB.capsKey = k ~= "" and k or nil
	wb.port()
	wb.apply()
	wb.say("the Caps bars' key is " .. capsKey() .. (DB.capsHold and "." or " (the Caps bars box in /wbars is not ticked)."))
end

-- Focus keys (his ask, Nov 26: "so annoying have to set it to a bar. can we add the tilt buttons to wbar and just make them
-- invis"): the game has a Focus Target key but none to clear the focus, and a macro only gets a key through a bar button.
-- With the box ticked two keys do it with no button on any bar: one sets your focus (what your mouse is over, else your
-- target), one clears it. They press two hidden buttons that run the game's own /focus and /clearfocus. The keys: [ and ]
-- (what his mouse wheel's tilts send); /wbars focuskeys SET CLEAR names others. Override bindings, never saved ones, and
-- only on a key that is free in Key Bindings or already your Focus Target key. Off by default. Cost: none until pressed.
local FOCUS_DO = { set = "/focus [@mouseover,exists,nodead][]", clear = "/clearfocus" }
local focusOwner = CreateFrame("Frame")
local focusBtn = {}
for _, what in ipairs({ "set", "clear" }) do
	local b = CreateFrame("Button", what == "set" and "WackyBarsFocusSet" or "WackyBarsFocusClear", nil, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyDown", "AnyUp")
	b:EnableMouse(false)
	b:SetAttribute("type", "macro")
	b:SetAttribute("macrotext", FOCUS_DO[what])
	focusBtn[what] = b
end
local function focusKeys()
	local DB = wb.db()
	local k = DB and type(DB.focusKeys) == "table" and DB.focusKeys or nil
	return k and k[1] or "[", k and k[2] or "]"
end
local function fillFocus()
	if InCombatLockdown() then return end
	local DB = wb.db()
	ClearOverrideBindings(focusOwner)
	if not (DB and DB.focusKeys) then return end
	local set, clear = focusKeys()
	for what, key in pairs({ set = set, clear = clear }) do
		local cmd = GetBindingAction(key) or ""
		if cmd == "" or cmd == "NONE" or (what == "set" and cmd == "FOCUSTARGET") then
			SetOverrideBindingClick(focusOwner, false, key, focusBtn[what]:GetName())
		end
	end
end
wb.applyHooks[#wb.applyHooks + 1] = fillFocus
wb.optionRows[#wb.optionRows + 1] = {
	label = "Focus keys: [ sets your focus, ] clears it (no bar button needed)",
	tab = "held", group = "Focus", hint = "Other keys: /wbars focuskeys SET CLEAR",
	get = function() local DB = wb.db() return DB and DB.focusKeys and true or false end,
	set = function(v) local DB = wb.db() DB.focusKeys = v and (type(DB.focusKeys) == "table" and DB.focusKeys or true) or nil end,
}
-- /wbars focuskeys SET CLEAR: two other keys, as the game names them (/wbars focuskeys: back to [ and ])
wb.slash.focuskeys = function(rest)
	if InCombatLockdown() then wb.say("after the fight.") return end
	local DB = wb.db()
	local a, b = (rest or ""):upper():match("^(%S+)%s+(%S+)$")
	DB.focusKeys = a and { a, b } or true
	wb.apply()
	local set, clear = focusKeys()
	wb.say("focus keys: " .. set .. " sets your focus, " .. clear .. " clears it. A key that already does something else in Key Bindings is left alone.")
end
