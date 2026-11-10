-- Bar profiles (his pick, Nov 10 night: "this could be nice to"): one Profiles row in /wbars. Save the bars' layout under a
-- name (leveling, dungeon, PvP) and switch with one click on the name. A profile keeps which bars show, where they sit and
-- how big they are; keys, hidden buttons, the look and the other boxes stay the same in every profile.
-- Changes you make go into the profile you are on, the way everything in WackyBars saves as you go: it is taken when you
-- switch away or save another. Saved per character, with the rest of WackyBars.
-- Not built: switching by spec on its own (he is asked first). Meanwhile a macro can switch: /wbars profile <name>.
-- The row sits in the place WackyBars keeps for a feature file's box (ns.wb.optionRows): the box is swapped for the name
-- button and Save the first time the window shows.
-- Cost: nothing runs. Only clicks and /wbars profile do anything.
local _, ns = ...
local wb = ns and ns.wb
if not wb then return end

local LABEL = "Profiles"
local POPUP = "WACKYBARS_PROFILE"
local PARTS = { "off", "pos", "sizes" } -- (which bars are off, their places, their sizes: DB.off, DB.pos, DB.sizes)

local function copy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = copy(v) end
	return c
end
local function list()
	local DB = wb.db()
	if type(DB.profiles) ~= "table" then DB.profiles = {} end
	return DB.profiles
end
local function find(name)
	local low = name:lower()
	for i, p in ipairs(list()) do
		if p.name:lower() == low then return i, p end
	end
end
local function take(p)
	local DB = wb.db()
	for _, k in ipairs(PARTS) do p[k] = copy(DB[k] or {}) end
end
-- The profile you are on keeps what you see now.
local function capture()
	local DB = wb.db()
	if not DB.profile then return end
	local _, p = find(DB.profile)
	if p then take(p) end
end

local row -- (the name button and Save, once the window has them)
local function refresh()
	if row then row.pick:SetText(wb.db().profile or "None") end
end

-- Puts a profile's layout on: the bars on and off (spare slots handed out again, as the bar boxes do), then places and sizes.
local function use(p)
	local DB = wb.db()
	capture()
	for _, k in ipairs(PARTS) do DB[k] = copy(p[k] or {}) end
	DB.profile = p.name
	wb.port()
	wb.apply()
	refresh()
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function saveAs(name)
	name = trim(name)
	if name == "" then
		wb.say("type a name for the profile.")
		return
	end
	local DB = wb.db()
	capture()
	local _, p = find(name)
	if not p then
		p = { name = name }
		local l = list()
		l[#l + 1] = p
	end
	take(p)
	DB.profile = p.name
	refresh()
	wb.say(("bars saved as %s. Changes you make now go into %s; click the name in /wbars to switch."):format(p.name, p.name))
end
local function delete(name)
	name = trim(name)
	local i, p = find(name)
	if not i then
		wb.say(("no profile named %s."):format(name ~= "" and name or "(blank)"))
		return
	end
	table.remove(list(), i)
	local DB = wb.db()
	if DB.profile and DB.profile:lower() == p.name:lower() then DB.profile = nil end -- (the bars stay as they are)
	refresh()
	wb.say(("profile %s deleted."):format(p.name))
end

-- Save asks for the name (filled in with the profile you are on): Save keeps the bars under it, Delete removes the profile
-- with that name.
local function editBoxOf(dialog)
	return dialog and ((dialog.GetEditBox and dialog:GetEditBox()) or dialog.editBox)
end
local function askName()
	if not (StaticPopupDialogs and StaticPopup_Show) then return end
	StaticPopupDialogs[POPUP] = StaticPopupDialogs[POPUP] or {
		text = "WackyBars: save which bars show, where they sit and how big they are, as a profile named:",
		button1 = "Save",
		button2 = CANCEL or "Cancel",
		button3 = "Delete",
		hasEditBox = 1,
		maxLetters = 24,
		OnShow = function(dialog)
			local e = editBoxOf(dialog)
			if e then
				e:SetText(wb.db().profile or "")
				if e.HighlightText then e:HighlightText() end
			end
		end,
		OnAccept = function(dialog)
			local e = editBoxOf(dialog)
			saveAs(e and e:GetText())
		end,
		OnAlt = function(dialog)
			local e = editBoxOf(dialog)
			delete(e and e:GetText())
		end,
		EditBoxOnEnterPressed = function(editBox)
			saveAs(editBox:GetText())
			editBox:GetParent():Hide()
		end,
		EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
		hideOnEscape = 1,
		timeout = 0,
		whileDead = 1,
	}
	StaticPopup_Show(POPUP)
end

-- One click on the name: the next profile, in the order they were saved. None saved yet: name the first one.
local function nextProfile()
	if InCombatLockdown() then
		wb.say("after the fight.")
		return
	end
	local l = list()
	if #l == 0 then
		askName()
		return
	end
	local DB = wb.db()
	local at = DB.profile and find(DB.profile) or 0
	if at > 0 and #l == 1 then
		wb.say("only one profile: Save another to switch between them.")
		return
	end
	use(l[at % #l + 1])
end

local function tip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Profiles")
	GameTooltip:AddLine("Click: the next profile. A profile keeps which bars show, where they sit and how big they are.", 1, 1, 1, true)
	GameTooltip:AddLine("Changes you make go into the profile you are on. Save: a new one, or Delete.", 0.7, 0.7, 0.7, true)
	GameTooltip:Show()
end
-- The row: WackyBars made a box labelled Profiles in the place it keeps for this file; the box goes, the label lines up with
-- Movement keys, Look and Arrows, and the name button and Save sit where their buttons do.
local function decorate()
	if row then
		refresh()
		return
	end
	local options = _G.WackyBarsOptions
	if not (options and options.GetRegions) then return end
	local box, label
	for _, r in ipairs({ options:GetRegions() }) do
		if r.GetText and r.GetPoint and r:GetText() == LABEL then
			local _, rel = r:GetPoint(1)
			if type(rel) == "table" and rel.SetChecked then box, label = rel, r end
		end
	end
	if not box then return end
	box:Hide()
	label:ClearAllPoints()
	label:SetPoint("LEFT", box, "LEFT", 4, 0)
	local pick = CreateFrame("Button", "WackyBarsProfilePick", options, "UIPanelButtonTemplate")
	pick:SetSize(160, 24)
	pick:SetPoint("LEFT", box, "LEFT", 130, 0)
	pick:SetScript("OnClick", nextProfile)
	pick:SetScript("OnEnter", tip)
	pick:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local save = CreateFrame("Button", "WackyBarsProfileSave", options, "UIPanelButtonTemplate")
	save:SetSize(60, 24)
	save:SetPoint("LEFT", pick, "RIGHT", 6, 0)
	save:SetText("Save")
	save:SetScript("OnClick", askName)
	row = { pick = pick, save = save }
	refresh()
end

-- (the row's place: WackyBars asks get each time the window shows or the bars are applied, which is when the row is made and
-- kept up to date; were the box ever left, a click on it is the name button's click)
wb.optionRows[#wb.optionRows + 1] = {
	label = LABEL,
	get = function()
		decorate()
		return false
	end,
	set = nextProfile,
}

-- /wbars profile: the names; /wbars profile <name>: switch to it (for a macro).
wb.slash.profile = function(rest)
	rest = trim(rest)
	local l = list()
	if rest == "" then
		local names = {}
		for _, p in ipairs(l) do names[#names + 1] = p.name end
		wb.say(#names > 0 and ("profiles: " .. table.concat(names, ", ") .. " (on: " .. (wb.db().profile or "none") .. ")")
			or "no profiles yet: Save one in /wbars.")
		return
	end
	local _, p = find(rest)
	if not p then
		wb.say(("no profile named %s."):format(rest))
	elseif InCombatLockdown() then
		wb.say("after the fight.")
	else
		use(p)
		wb.say("profile: " .. p.name)
	end
end
