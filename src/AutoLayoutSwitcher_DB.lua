-- Database schema and persistence layer
local ADDON_NAME, ALS = ...
if not ALS then
    ALS = {}
    _G[ADDON_NAME] = ALS
end

-- SavedVariables table (must be global for WoW to persist it)
AutoLayoutSwitcherDB = AutoLayoutSwitcherDB or {
    mappings = {},       -- [loadoutID] = entry table { layoutIndex = number, layoutName = string } or { useDefault = true }
    defaultLayout = nil, -- { layoutIndex = number, layoutName = string }
    debug = false,       -- persist debug state
}

local function EnsureTables()
    AutoLayoutSwitcherDB.mappings = AutoLayoutSwitcherDB.mappings or {}
end

function ALS.SaveMapping(loadoutID, layoutIndex, layoutName, useDefault, loadoutName)
    EnsureTables()
    if useDefault then
        AutoLayoutSwitcherDB.mappings[loadoutID] = { useDefault = true, loadoutName = loadoutName }
    else
        AutoLayoutSwitcherDB.mappings[loadoutID] = {
            layoutIndex = layoutIndex,
            layoutName = layoutName,
            loadoutName = loadoutName,
        }
    end
end

function ALS.GetMapping(loadoutID)
    EnsureTables()
    return AutoLayoutSwitcherDB.mappings[loadoutID]
end

function ALS.ClearMapping(loadoutID)
    EnsureTables()
    AutoLayoutSwitcherDB.mappings[loadoutID] = nil
end

function ALS.GetAllMappings()
    EnsureTables()
    return AutoLayoutSwitcherDB.mappings
end

function ALS.SaveDefaultLayout(layoutIndex, layoutName)
    EnsureTables()
    AutoLayoutSwitcherDB.defaultLayout = {
        layoutIndex = layoutIndex,
        layoutName = layoutName,
    }
end

function ALS.ClearDefaultLayout()
    EnsureTables()
    AutoLayoutSwitcherDB.defaultLayout = nil
end

function ALS.GetDefaultLayout()
    EnsureTables()
    return AutoLayoutSwitcherDB.defaultLayout
end
