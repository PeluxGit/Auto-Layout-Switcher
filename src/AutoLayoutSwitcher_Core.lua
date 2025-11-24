-- Core logic: loadout/layout switching, mapping resolution
local ADDON_NAME, ALS = ...

local lastLoadoutID
local deferredSwitchPending = false

function ALS.GetActiveLoadoutID()
	if C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
		local specIndex = GetSpecialization()
		if specIndex then
			local specID = select(1, GetSpecializationInfo(specIndex))
			if specID then
				local id = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
				if id and id ~= 0 then return id end
			end
		end
	end
	return nil
end

local function GetActiveLayoutInfo()
	return EditModeManagerFrame:GetActiveLayoutInfo()
end

local function GetLayoutsRaw()
	return EditModeManagerFrame:GetLayouts() or {}
end

local function GetActiveLayoutIndex()
	local info = GetActiveLayoutInfo()
	if info and info.layoutIndex then return info.layoutIndex end
	if info and info.layoutName then
		for i, li in ipairs(GetLayoutsRaw()) do
			if li.layoutName == info.layoutName then
				return i
			end
		end
	end
	return nil
end

local function GetLayoutInfoByIndex(layoutIndex)
	if not layoutIndex then return nil end
	local info = GetLayoutsRaw()[layoutIndex]
	if info then info.layoutIndex = layoutIndex end
	return info
end

local function SetActiveLayout(layoutIndex)
	if InCombatLockdown() then
		ALS.DebugPrint("Cannot set layout in combat")
		return false
	end
	ALS.DebugPrint("Setting active layout to index:", layoutIndex)
	if C_EditMode and C_EditMode.SetActiveLayout then
		C_EditMode.SetActiveLayout(layoutIndex)
		return true
	end
	ALS.DebugPrint("C_EditMode.SetActiveLayout not available")
	return false
end

function ALS.ResolveDefaultLayout()
	local entry = ALS.GetDefaultLayout()
	if not entry or not entry.layoutIndex then return end
	local info = GetLayoutInfoByIndex(entry.layoutIndex)
	if not info then return end
	if info.layoutName and entry.layoutName ~= info.layoutName then
		ALS.SaveDefaultLayout(info.layoutIndex, info.layoutName)
	end
	return info.layoutIndex, info.layoutIndex, entry.layoutName or info.layoutName or ("Layout " .. info.layoutIndex)
end

function ALS.ResolveMappingEntry(entry)
	if not entry then return end
	if entry.useDefault then
		local layoutIndex, _, layoutName = ALS.ResolveDefaultLayout()
		return layoutIndex, layoutIndex, layoutName, true
	end
	if not entry.layoutIndex then return end
	local info = GetLayoutInfoByIndex(entry.layoutIndex)
	if not info then return end
	if info.layoutName and entry.layoutName ~= info.layoutName then
		entry.layoutName = info.layoutName
	end
	return info.layoutIndex, info.layoutIndex, entry.layoutName or info.layoutName or ("Layout " .. info.layoutIndex)
end

function ALS.TrySwitchLayout(force, triggerEvent)
	local loadoutID = ALS.GetActiveLoadoutID()
	ALS.DebugPrint("=== TrySwitchLayout called ===")
	ALS.DebugPrint("  force:", force)
	ALS.DebugPrint("  triggerEvent:", triggerEvent or "unknown")
	ALS.DebugPrint("  loadoutID:", loadoutID)
	ALS.DebugPrint("  lastLoadoutID:", lastLoadoutID)
	
	if not loadoutID then
		ALS.DebugPrint("  No active loadout, aborting")
		deferredSwitchPending = false
		return
	end
	
	local activeLoadoutName
	if C_Traits and C_Traits.GetConfigInfo then
		local info = C_Traits.GetConfigInfo(loadoutID)
		activeLoadoutName = info and info.name
		ALS.DebugPrint("  Active loadout:", activeLoadoutName or "unknown")
	end

	if not force and loadoutID == lastLoadoutID then
		ALS.DebugPrint("  Already processed this loadout, skipping")
		return
	end

	local mappingEntry = ALS.GetMapping(loadoutID)
	ALS.DebugPrint("  Direct ID mapping:", mappingEntry and "exists" or "nil")
	if mappingEntry then
		ALS.DebugPrint("    layoutIndex:", mappingEntry.layoutIndex)
		ALS.DebugPrint("    layoutName:", mappingEntry.layoutName)
		ALS.DebugPrint("    useDefault:", mappingEntry.useDefault)
		ALS.DebugPrint("    loadoutName:", mappingEntry.loadoutName)
	end

	if not mappingEntry and activeLoadoutName then
		ALS.DebugPrint("  Attempting name-based fallback for:", activeLoadoutName)
		local allMappings = ALS.GetAllMappings()
		for id, entry in pairs(allMappings) do
			if entry.loadoutName == activeLoadoutName then
				ALS.DebugPrint("  Name fallback matched! Stored ID:", id, "Active ID:", loadoutID)
				mappingEntry = entry
				break
			end
		end
		if not mappingEntry then
			ALS.DebugPrint("  Name fallback found no match")
		end
	end
	
	local desiredLayoutIndex, _, desiredLayoutName, usesDefault = ALS.ResolveMappingEntry(mappingEntry)
	ALS.DebugPrint("  After resolve:")
	ALS.DebugPrint("    desiredLayoutIndex:", desiredLayoutIndex)
	ALS.DebugPrint("    desiredLayoutName:", desiredLayoutName)
	ALS.DebugPrint("    usesDefault:", usesDefault)

	if not desiredLayoutIndex then
		deferredSwitchPending = false
		lastLoadoutID = loadoutID
		return
	end

	local activeIndex = GetActiveLayoutIndex()
	ALS.DebugPrint("  activeIndex:", activeIndex)

	local needsSwitch = (desiredLayoutIndex ~= activeIndex)
	ALS.DebugPrint("  needsSwitch:", needsSwitch, force and " (force recheck)" or "")

	if needsSwitch then
		if not InCombatLockdown() then
			ALS.DebugPrint("  Calling SetActiveLayout with index:", desiredLayoutIndex)
			SetActiveLayout(desiredLayoutIndex)
			local layoutLabel = desiredLayoutName or ("Layout " .. tostring(desiredLayoutIndex))
			local loadoutLabel = activeLoadoutName or (mappingEntry and mappingEntry.loadoutName) or ("ID " .. tostring(loadoutID))
			local msg = string.format("AutoLayoutSwitcher: Switched to layout '%s' for loadout '%s'", layoutLabel, loadoutLabel)
			if ALS.GetDebug and ALS.GetDebug() then
				msg = string.format("%s (slot %s, id %s, trigger: %s)", msg, tostring(desiredLayoutIndex), tostring(loadoutID), triggerEvent or "unknown")
			end
			print(msg)
			deferredSwitchPending = false
		else
			print("AutoLayoutSwitcher: Cannot switch layout in combat. Will retry after combat ends.")
			deferredSwitchPending = true
		end
	else
		if force then
			ALS.DebugPrint("  Force flag set but layout already correct - skipping redundant switch")
		end
		ALS.DebugPrint("  No switch needed - already on correct layout")
		deferredSwitchPending = false
	end
	
	-- Always update lastLoadoutID after processing to prevent duplicate switches
	lastLoadoutID = loadoutID
end

-- Export deferredSwitchPending accessor for Events module
function ALS.IsDeferredSwitchPending()
	return deferredSwitchPending
end
