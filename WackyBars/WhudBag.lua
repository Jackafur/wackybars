-- The sleeping bag on Warlock HUD (his "we should add sleeping bag to lockhud", Nov 10): the Cozy Sleeping Bag (rested XP,
-- from the Cozy Sleeping Bag quest chain) gets an icon on the Warlock HUD row that holds the Healthstone and the Soulstone,
-- right beside them, the same size, with the same black border and the same cooldown sweep. It shows only while the bag is
-- in your bags. Not a button, like the stones: you use the bag from your bags or a bar, and if it sits on one of your keys
-- WhudKeys.lua puts that key on the icon too.
-- Warlock HUD is left as it is (someone else's addon, WowUp updates it): WackyBars finds the row through Warlock HUD's own
-- WarlockHudAPI.GetDemoAnchors, puts one frame of its own on it, and moves that frame onto the new row whenever Warlock HUD
-- rebuilds its rows. The stones sit at the left end of the row (his order: Healthstone, Soulstone, then the rest), so the
-- bag goes left of them; with the stones anywhere else it goes at the right end.
-- /wbars bag switches it off and on. Cost: nothing without Warlock HUD; with it, a look after your bags change and after
-- Warlock HUD rebuilds. No timer, no OnUpdate.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local BAG_ID = 211527 -- Cozy Sleeping Bag
local BAG_NAME = "Cozy Sleeping Bag" -- (also found by name, in case Forever gives it another number)
local SPACING, BORDER = 1, 1 -- (Warlock HUD's ICON_SPACING and BORDER_SIZE)
local CROP = (1 - 1 / 1.3) / 2 -- (Warlock HUD's ICON_CROP)

local holder, icon, cooldown, row, bagID

local function on()
	local DB = wb.db()
	return not (DB and DB.whudBag == false)
end
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function pictureOf(t)
	local ok, p = pcall(function()
		if t.GetTextureFileID then return t:GetTextureFileID() end
		return t:GetTexture()
	end)
	if ok and (type(p) == "number" or type(p) == "string") and not secret(p) then return p end
end

-- The bag's item number while it is in your bags, else nil.
local function findBag()
	local count = C_Item and C_Item.GetItemCount
	if count then
		local ok, n = pcall(count, BAG_ID)
		if ok and type(n) == "number" and not secret(n) and n > 0 then return BAG_ID end
	end
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
	for bag = 0, 4 do
		local ok, slots = pcall(C.GetContainerNumSlots, bag)
		if ok and type(slots) == "number" and not secret(slots) then
			for slot = 1, slots do
				local okI, info = pcall(C.GetContainerItemInfo, bag, slot)
				local link = okI and type(info) == "table" and info.hyperlink
				if type(link) == "string" and not secret(link) and link:find("[" .. BAG_NAME .. "]", 1, true) then
					return info.itemID
				end
			end
		end
	end
end

-- The row with the stones on it (Warlock HUD's Main or Utility row), its icon size, and where the bag goes on it.
local function stonePictures()
	local out = {}
	local api = WarlockHudAPI
	local stones = type(api) == "table" and type(api.Stones) == "table" and api.Stones or {}
	for _, stone in ipairs(stones) do
		for _, id in ipairs(type(stone.ids) == "table" and stone.ids or {}) do
			local p = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
			if p then out[p] = true end
		end
	end
	return out
end
-- Warlock HUD's own icons on a row: textures anchored by their middle to the row's middle.
local function rowIcons(anchor)
	local out = {}
	for _, r in ipairs({ anchor:GetRegions() }) do
		if r ~= icon and r.GetObjectType and r:GetObjectType() == "Texture" and r.GetPoint then
			local point, rel, _, x = r:GetPoint(1)
			if point == "CENTER" and rel == anchor and type(x) == "number" then
				out[#out + 1] = { tex = r, x = x, size = r:GetWidth() }
			end
		end
	end
	return out
end
local function placeOf(rows)
	local pics = stonePictures()
	for _, name in ipairs({ "utility", "main" }) do
		local anchor = rows[name]
		if type(anchor) == "table" and anchor.GetRegions then
			local list = rowIcons(anchor)
			local lo, hi, stoneLo
			for _, e in ipairs(list) do
				if not lo or e.x < lo.x then lo = e end
				if not hi or e.x > hi.x then hi = e end
				local p = pictureOf(e.tex)
				if p and pics[p] and (not stoneLo or e.x < stoneLo.x) then stoneLo = e end
			end
			if stoneLo then
				local size = stoneLo.size
				if stoneLo == lo then return anchor, lo.x - (size + SPACING), size end
				return anchor, hi.x + (size + SPACING), size
			end
		end
	end
end

local function build()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:EnableMouse(false)
	icon = holder:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(holder)
	icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	cooldown = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
	cooldown:SetAllPoints(icon)
	if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
	if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
	if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
	-- the black border, Warlock HUD's way: four edges in a frame of their own around the icon
	holder.border = CreateFrame("Frame", nil, holder)
	holder.border:SetPoint("TOPLEFT", holder, "TOPLEFT", -BORDER, BORDER)
	holder.border:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", BORDER, -BORDER)
	holder.border:SetFrameLevel(holder:GetFrameLevel() + 3)
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local edge = holder.border:CreateTexture(nil, "OVERLAY")
		edge:SetColorTexture(0, 0, 0, 1)
		edge:SetPoint(side, holder.border, side)
		if side == "TOP" or side == "BOTTOM" then
			edge:SetPoint("LEFT", holder.border, "LEFT")
			edge:SetPoint("RIGHT", holder.border, "RIGHT")
			edge:SetHeight(BORDER)
		else
			edge:SetPoint("TOP", holder.border, "TOP")
			edge:SetPoint("BOTTOM", holder.border, "BOTTOM")
			edge:SetWidth(BORDER)
		end
	end
end

-- Its picture, its cooldown, shown or not.
local function update()
	if not holder then return end
	local show = row ~= nil and bagID ~= nil and on()
	icon:SetShown(show) -- (the icon itself too: WhudKeys' key on it follows the icon's Show and Hide)
	holder:SetShown(show)
	if not show then return end
	local p = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(bagID)
	if p then icon:SetTexture(p) end
	local cd = (C_Item and C_Item.GetItemCooldown) or (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
	if cd then
		local ok, start, duration = pcall(cd, bagID)
		-- (the widget takes the values without Lua looking at them, as Warlock HUD does for the stones)
		if ok and start and duration then pcall(cooldown.SetCooldown, cooldown, start, duration) end
	end
end

-- Onto Warlock HUD's row with the stones (again after each rebuild: the rows are new frames then).
local function place()
	local api = WarlockHudAPI
	local ok, rows = pcall(function() return api and api.GetDemoAnchors and api.GetDemoAnchors() end)
	local anchor, x, size
	if ok and type(rows) == "table" then anchor, x, size = placeOf(rows) end
	if anchor then
		if not holder then build() end
		holder:SetParent(anchor)
		holder:ClearAllPoints()
		holder:SetSize(size, size)
		holder:SetPoint("CENTER", anchor, "CENTER", x, 0)
		holder:SetFrameLevel(anchor:GetFrameLevel() + 2)
		row = anchor
	else
		row = nil
	end
	update()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		events:UnregisterEvent("PLAYER_LOGIN")
		local api = WarlockHudAPI
		if type(api) ~= "table" or type(api.GetDemoAnchors) ~= "function" then return end
		-- (WackyBars loads this file before WhudKeys.lua, so the bag is on the row before the keys are worked out)
		if type(api.Rebuild) == "function" then hooksecurefunc(api, "Rebuild", place) end
		if type(WarlockHudRefreshNameplates) == "function" then hooksecurefunc(_G, "WarlockHudRefreshNameplates", place) end
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN" }) do
			events:RegisterEvent(e)
		end
		bagID = findBag()
		place()
	elseif event == "BAG_UPDATE_COOLDOWN" then
		update()
	else
		bagID = findBag()
		update()
	end
end)
events:RegisterEvent("PLAYER_LOGIN")

wb.slash.bag = function()
	local DB = wb.db()
	if not DB then return end
	if on() then DB.whudBag = false else DB.whudBag = nil end
	update()
	local where = not WarlockHudAPI and " (Warlock HUD is not loaded)"
		or not bagID and " (shows once the Cozy Sleeping Bag is in your bags)" or ""
	wb.say("the sleeping bag on Warlock HUD is " .. (on() and "on" or "off") .. where .. ".")
end
