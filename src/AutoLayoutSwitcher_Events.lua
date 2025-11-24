-- Event registration and slash command handler logic
local ADDON_NAME, ALS = ...

local function HandleList()
    local mappings = ALS.GetAllMappings()
    local count = 0
    for loadoutID, entry in pairs(mappings) do
        count = count + 1
        local _, layoutIndex, layoutName, usedDefault = ALS.ResolveMappingEntry(entry)
        local loadoutName
        if entry and entry.loadoutName then
            loadoutName = entry.loadoutName
        elseif C_Traits and C_Traits.GetConfigInfo then
            local info = C_Traits.GetConfigInfo(loadoutID)
            loadoutName = info and info.name
        end
        loadoutName = loadoutName or tostring(loadoutID)

        if usedDefault then
            if layoutIndex then
                print(string.format("Loadout '%s' -> Default layout '%s'", loadoutName,
                    layoutName or ("Layout " .. layoutIndex)))
            else
                print(string.format("Loadout '%s' -> Default layout (not configured)", loadoutName))
            end
        elseif layoutIndex then
            print(string.format("Loadout '%s' -> '%s'", loadoutName, layoutName or ("Layout " .. layoutIndex)))
        else
            print(string.format("Loadout '%s' -> mapped layout unavailable", loadoutName))
        end
    end
    if count == 0 then
        print("AutoLayoutSwitcher: No mappings saved.")
    end
end

local function HandleClear(loadoutToken)
    local loadoutID = tonumber(loadoutToken)
    if not loadoutID then
        print("AutoLayoutSwitcher: Invalid loadout ID.")
        return
    end

    if ALS.GetMapping(loadoutID) then
        ALS.ClearMapping(loadoutID)
        print(string.format("AutoLayoutSwitcher: Cleared mapping for loadout %d.", loadoutID))
    else
        print(string.format("AutoLayoutSwitcher: No mapping found for loadout %d.", loadoutID))
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            ALS.InitializeDebug() -- Load debug state from SavedVariables
            print(ADDON_NAME .. " loaded. Use /als to configure.")
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ALS.IsDeferredSwitchPending() then
            ALS.TrySwitchLayout(true, event) -- forced retry after combat
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Force a pass on login/zone load. Delay slightly to let APIs initialize.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function() ALS.TrySwitchLayout(true, event) end)
        else
            ALS.TrySwitchLayout(true, event)
        end
    elseif event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" then
        -- A trait configuration changed; give a short delay to allow the active config to settle.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function() ALS.TrySwitchLayout(false, event) end)
        else
            ALS.TrySwitchLayout(false, event)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        ALS.TrySwitchLayout(true, event)
    else
        ALS.TrySwitchLayout(false, event)
    end
end)

SLASH_AUTOLAYOUTSWITCHER1 = "/als"
SlashCmdList["AUTOLAYOUTSWITCHER"] = function(msg)
    msg = msg:match("^%s*(.-)%s*$") or ""
    if msg == "" or msg == "open" then
        if Settings and Settings.OpenToCategory and ALS_SettingsCategory then
            Settings.OpenToCategory(ALS_SettingsCategory:GetID())
        end
        return
    end

    local command, rest = msg:match("^(%S+)%s*(.*)$")
    command = command and command:lower() or ""

    if command == "list" then
        HandleList()
    elseif command == "clear" then
        if rest ~= "" then
            HandleClear(rest)
        else
            print("Usage: /als clear <loadoutID>")
        end
    elseif command == "debug" then
        local newDebug = not ALS.GetDebug()
        ALS.SetDebug(newDebug)
        print("AutoLayoutSwitcher: Debug mode " .. (newDebug and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    elseif command == "testapi" then
        print("=== Testing Edit Mode API ===")
        print("C_EditMode exists:", C_EditMode ~= nil)
        print("C_EditMode.GetLayouts exists:", C_EditMode and C_EditMode.GetLayouts ~= nil)
        if C_EditMode and C_EditMode.GetLayouts then
            local layouts = C_EditMode.GetLayouts()
            print("GetLayouts() returned:", type(layouts))
            if layouts then
                print("Number of layouts:", #layouts)
                for i, layout in ipairs(layouts) do
                    print(string.format("  [%d] layoutID=%s, layoutName=%s, layoutType=%s",
                        i,
                        tostring(layout.layoutID),
                        tostring(layout.layoutName),
                        tostring(layout.layoutType)))
                end
            end
        end
        if C_EditMode and C_EditMode.GetActiveLayoutInfo then
            local activeInfo = C_EditMode.GetActiveLayoutInfo()
            print("Active layout info:", activeInfo and type(activeInfo) or "nil")
            if activeInfo then
                print("  layoutID:", tostring(activeInfo.layoutID))
                print("  layoutName:", tostring(activeInfo.layoutName))
                print("  layoutType:", tostring(activeInfo.layoutType))
            end
        end
        print("Checking EditModeManagerFrame:")
        if EditModeManagerFrame then
            print("  EditModeManagerFrame exists:", true)
            if EditModeManagerFrame.GetLayouts then
                local layouts = EditModeManagerFrame:GetLayouts()
                print("  GetLayouts() returned:", type(layouts))
                if layouts then
                    print("  Number of layouts:", #layouts)
                    for i, layout in ipairs(layouts) do
                        print(string.format("    [%d] layoutName=%s, layoutType=%s",
                            i,
                            tostring(layout.layoutName),
                            tostring(layout.layoutType)))
                    end
                end
            end
        else
            print("  EditModeManagerFrame: nil")
        end
    else
        print(
        "AutoLayoutSwitcher: Unknown command. Use /als to open the options panel, /als list, /als clear <loadoutID>, /als debug, or /als testapi.")
    end
end
