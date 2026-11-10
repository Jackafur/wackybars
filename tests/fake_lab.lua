-- A stand-in for LibStub and LibActionButton-1.0 in the fake game: buttons from the action button template, with the
-- library's state calls (state n holds an action; the current state's action is the "action" attribute).
return function(M)
	local libs = {}
	local LAB = {}
	function LAB:CreateButton(id, name, header, config)
		local f = CreateFrame("CheckButton", name, header, "ActionBarButtonTemplate")
		f.__states, f.config = {}, config
		f:SetAttribute("state", "0")
		rawset(f, "SetStateFromHandlerInsecure", function(s, state, kind, action) s.__states[tostring(state)] = action end)
		rawset(f, "UpdateState", function(s, state)
			state = tostring(state or s:GetAttribute("state"))
			if state == tostring(s:GetAttribute("state")) then s:SetAttribute("action", s.__states[state]) end
		end)
		rawset(f, "GetAction", function(s, state)
			state = tostring(state or s:GetAttribute("state"))
			return s.__kinds and s.__kinds[state] or "empty", s.__states[state]
		end)
		rawset(f, "SetState", function(s, state, kind, action)
			s.__kinds = s.__kinds or {}
			s.__kinds[tostring(state)] = kind or "empty"
			s:SetStateFromHandlerInsecure(state, kind, action)
			s:UpdateState(state)
		end)
		return f
	end
	LAB.callbacks = {}
	function LAB.RegisterCallback(owner, event, fn) LAB.callbacks[event] = fn end
	libs["LibActionButton-1.0"] = LAB
	rawset(_G, "LibStub", setmetatable({}, { __call = function(_, n) return libs[n] end }))
end
