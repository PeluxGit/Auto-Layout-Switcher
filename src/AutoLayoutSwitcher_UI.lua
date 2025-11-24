-- UI Panel for mapping layouts to loadouts
local ADDON_NAME, ALS = ...

-- UI Panel
local panel = CreateFrame("Frame", "AutoLayoutSwitcherOptionsPanel")
panel.name = "Auto Layout Switcher"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Auto Layout Switcher")

local function GetSpecs()
    local specs = {}
    for i = 1, GetNumSpecializations() do
        local id, name = GetSpecializationInfo(i)
        specs[#specs+1] = {id = id, name = name, index = i}
    end
    return specs
end

local function GetLoadoutsForSpec(specID)
    local configs = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
    local out = {}
    for _, configID in ipairs(configs) do
        local info = C_Traits.GetConfigInfo(configID)
        if info then
            out[#out+1] = {id = configID, name = info.name}
        end
    end
    return out
end

local function GetLayouts()
    local layouts = EditModeManagerFrame:GetLayouts() or {}
    ALS.DebugPrint("Raw layouts count:", #layouts)
    
    local out = {}
    for i, info in ipairs(layouts) do
        ALS.DebugPrint(string.format("Layout %d: name=%s, type=%s", i, tostring(info.layoutName), tostring(info.layoutType)))
        out[#out+1] = {
            index = i,
            layoutID = info.layoutID,
            name = info.layoutName or ("Layout "..i),
            layoutType = info.layoutType,
        }
    end
    
    ALS.DebugPrint("Processed " .. #out .. " layouts")
    return out
end

local dropdowns = {}
local specLabels = {}
local loadoutLabels = {}
local defaultLabel
local defaultDropdown

local NONE_VALUE = "ALS_NONE"
local DEFAULT_VALUE = "ALS_DEFAULT"

local function SkinDropdownWithElvUI(dropdown)
    if not dropdown then return end
    local elv = _G.ElvUI
    if type(elv) ~= "table" then return end
    local E = elv[1]
    if not E or not E.GetModule then return end
    local private = E.private
    if private and private.skins and private.skins.blizzard and private.skins.blizzard.enable == false then
        return
    end
    local skins = E:GetModule("Skins", true)
    if not skins or not skins.HandleDropDownBox then return end
    if dropdown.__ALS_ElvUISkinned then return end
    skins:HandleDropDownBox(dropdown)
    dropdown.__ALS_ElvUISkinned = true
end

local function ExpandDropdownClickArea(dropdown)
    if not dropdown or dropdown.__ALS_FullClickAreaApplied then return end
    local button = dropdown.Button
    if not button and dropdown.GetName then
        local name = dropdown:GetName()
        if name then
            button = _G[name .. "Button"]
        end
    end
    if not button then return end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
    button:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)
    button:SetHitRectInsets(0, 0, 0, 0)
    dropdown.__ALS_FullClickAreaApplied = true
end

local function RefreshPanel()
    local y = -48
    local layouts = GetLayouts()
    
    ALS.DebugPrint("Found " .. #layouts .. " layouts")

    local specLabelCount, loadoutLabelCount, dropdownCount = 0, 0, 0

    local function AcquireSpecLabel()
        specLabelCount = specLabelCount + 1
        local label = specLabels[specLabelCount]
        if not label then
            label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            specLabels[specLabelCount] = label
        else
            label:Show()
            label:ClearAllPoints()
        end
        return label
    end

    local function AcquireLoadoutLabel()
        loadoutLabelCount = loadoutLabelCount + 1
        local label = loadoutLabels[loadoutLabelCount]
        if not label then
            label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            loadoutLabels[loadoutLabelCount] = label
        else
            label:Show()
            label:ClearAllPoints()
        end
        return label
    end

    local function AcquireDropdown()
        dropdownCount = dropdownCount + 1
        local dd = dropdowns[dropdownCount]
        if not dd then
            local name = string.format("ALSLayoutDropdown%d", dropdownCount)
            dd = CreateFrame("Frame", name, panel, "UIDropDownMenuTemplate")
            dropdowns[dropdownCount] = dd
        else
            dd:Show()
            dd:ClearAllPoints()
        end
        SkinDropdownWithElvUI(dd)
        ExpandDropdownClickArea(dd)
        return dd
    end

    if not defaultLabel then
        defaultLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        defaultLabel:SetText("Default layout")
    end
    if not defaultDropdown then
        defaultDropdown = CreateFrame("Frame", "ALSDefaultLayoutDropdown", panel, "UIDropDownMenuTemplate")
    end
    SkinDropdownWithElvUI(defaultDropdown)
    ExpandDropdownClickArea(defaultDropdown)

    defaultLabel:Show()
    defaultLabel:ClearAllPoints()
    defaultLabel:SetPoint("TOPLEFT", 24, y)
    defaultLabel:SetText("Default layout")

    defaultDropdown:Show()
    defaultDropdown:ClearAllPoints()
    defaultDropdown:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, y)
    defaultDropdown.layouts = layouts
    defaultDropdown.initialize = function(self)
        local selectedLayoutIndex = select(1, ALS.ResolveDefaultLayout())

        local info = UIDropDownMenu_CreateInfo()
        info.text = "Not set"
        info.value = NONE_VALUE
        info.checked = not selectedLayoutIndex
        info.func = function()
            ALS.ClearDefaultLayout()
            UIDropDownMenu_SetSelectedValue(self, NONE_VALUE)
            ALS.TrySwitchLayout(true)
        end
        UIDropDownMenu_AddButton(info)

        for _, layout in ipairs(self.layouts or {}) do
            local layoutInfo = UIDropDownMenu_CreateInfo()
            layoutInfo.text = layout.name
            layoutInfo.value = layout.index
            layoutInfo.checked = (selectedLayoutIndex == layout.index)
            layoutInfo.func = function()
                ALS.SaveDefaultLayout(layout.index, layout.name)
                UIDropDownMenu_SetSelectedValue(self, layout.index)
                ALS.TrySwitchLayout(true)
            end
            UIDropDownMenu_AddButton(layoutInfo)
        end
    end
    UIDropDownMenu_SetWidth(defaultDropdown, 160)
    UIDropDownMenu_Initialize(defaultDropdown, defaultDropdown.initialize)
    local currentDefaultValue = select(1, ALS.ResolveDefaultLayout()) or NONE_VALUE
    UIDropDownMenu_SetSelectedValue(defaultDropdown, currentDefaultValue)

    y = y - 48

    for _, spec in ipairs(GetSpecs()) do
        local specLabel = AcquireSpecLabel()
        specLabel:SetPoint("TOPLEFT", 24, y)
        specLabel:SetText(spec.name)
        y = y - 24
        for _, loadout in ipairs(GetLoadoutsForSpec(spec.id)) do
            local loadoutLabel = AcquireLoadoutLabel()
            loadoutLabel:SetPoint("TOPLEFT", 48, y)
            loadoutLabel:SetText(loadout.name)

            local dd = AcquireDropdown()
            dd:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, y)
            dd.loadoutID = loadout.id
            dd.loadoutName = loadout.name
            dd.layouts = layouts
            dd.initialize = function(self)
                    local entry = ALS.GetMapping(self.loadoutID)
                    local selectedLayoutIndex = entry and entry.layoutIndex
                    local usesDefault = entry and entry.useDefault
                    local selectedValue = usesDefault and DEFAULT_VALUE or selectedLayoutIndex

                    local function AddOption(text, value, isChecked, onClick)
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = text
                        info.value = value
                        info.checked = isChecked
                        info.func = function()
                            onClick()
                            UIDropDownMenu_SetSelectedValue(self, value)
                            if self.loadoutID == ALS.GetActiveLoadoutID() then
                                ALS.TrySwitchLayout(true)
                            end
                        end
                        UIDropDownMenu_AddButton(info)
                    end

                    AddOption("None (do not switch)", NONE_VALUE, not entry, function()
                        ALS.ClearMapping(self.loadoutID)
                    end)

                    AddOption("Default layout", DEFAULT_VALUE, usesDefault, function()
                        ALS.SaveMapping(self.loadoutID, nil, nil, true, self.loadoutName)
                    end)

                    for _, layout in ipairs(self.layouts or {}) do
                        local isChecked = selectedLayoutIndex == layout.index and not usesDefault
                        ALS.DebugPrint(string.format("Layout '%s': index=%s selectedIndex=%s checked=%s", layout.name, tostring(layout.index), tostring(selectedLayoutIndex), tostring(isChecked)))
                        AddOption(layout.name, layout.index, isChecked, function()
                            ALS.DebugPrint(string.format("Saving: loadoutID=%s layoutIndex=%s layoutName=%s loadoutName=%s", tostring(self.loadoutID), tostring(layout.index), tostring(layout.name), tostring(self.loadoutName)))
                            ALS.SaveMapping(self.loadoutID, layout.index, layout.name, false, self.loadoutName)
                        end)
                    end
            end

            UIDropDownMenu_SetWidth(dd, 160)
            UIDropDownMenu_Initialize(dd, dd.initialize)
            local selectedEntry = ALS.GetMapping(loadout.id)
            ALS.DebugPrint(string.format("Loading loadout %s: entry=%s", tostring(loadout.id), selectedEntry and "exists" or "nil"))
            if selectedEntry then
                ALS.DebugPrint(string.format("  useDefault=%s layoutIndex=%s layoutName=%s", tostring(selectedEntry.useDefault), tostring(selectedEntry.layoutIndex), tostring(selectedEntry.layoutName)))
            end
            local selectedValue
            if selectedEntry then
                if selectedEntry.useDefault then
                    selectedValue = DEFAULT_VALUE
                else
                    selectedValue = selectedEntry.layoutIndex
                end
            end
            selectedValue = selectedValue or NONE_VALUE
            ALS.DebugPrint("Setting dropdown value to:", tostring(selectedValue))
            UIDropDownMenu_SetSelectedValue(dd, selectedValue)
            y = y - 32
        end
    end

    for i = specLabelCount + 1, #specLabels do specLabels[i]:Hide() end
    for i = loadoutLabelCount + 1, #loadoutLabels do loadoutLabels[i]:Hide() end
    for i = dropdownCount + 1, #dropdowns do dropdowns[i]:Hide() end
end

panel:SetScript("OnShow", RefreshPanel)

-- Register with the new Settings API (Dragonflight+)
ALS_SettingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Auto Layout Switcher")
Settings.RegisterAddOnCategory(ALS_SettingsCategory)
