-- Debug utilities module
local ADDON_NAME, ALS = ...

local DEBUG = false

-- Initialize DEBUG from SavedVariables (called after ADDON_LOADED)
function ALS.InitializeDebug()
	DEBUG = AutoLayoutSwitcherDB and type(AutoLayoutSwitcherDB.debug) == "boolean" and AutoLayoutSwitcherDB.debug or false
end

function ALS.DebugPrint(...)
	if DEBUG then
		print("|cff00ff00[ALS Debug]|r", ...)
	end
end

function ALS.GetDebug()
	return DEBUG
end

function ALS.SetDebug(val)
	DEBUG = val
	if AutoLayoutSwitcherDB then AutoLayoutSwitcherDB.debug = val end
end