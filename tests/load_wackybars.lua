-- Loads WackyBars as the game does: WackyBars.lua, then every file after it in the TOC (the feature files), one addon table
-- shared by all of them (the libraries before it are the tests' fakes, fake_lab.lua). Returns ok, err, the addon table.
return function(M, here)
	local ns = {}
	local ok, err = M.run(here .. "/WackyBars/WackyBars.lua", "WackyBars", ns)
	if not ok then return ok, err end
	local after = false
	for line in io.lines(here .. "/WackyBars/WackyBars.toc") do
		line = line:gsub("\r$", ""):match("^%s*(.-)%s*$")
		if line == "WackyBars.lua" then
			after = true
		elseif after and line ~= "" and not line:match("^#") and line:match("%.lua$") then
			ok, err = M.run(here .. "/WackyBars/" .. line:gsub("\\", "/"), "WackyBars", ns)
			if not ok then return ok, line .. ": " .. tostring(err) end
		end
	end
	return true, nil, ns
end
