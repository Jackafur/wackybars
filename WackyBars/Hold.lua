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
	get = function() local DB = wb.db() return DB and not DB.hyperAlways end,
	set = function(v) wb.db().hyperAlways = (not v) or nil end,
}
