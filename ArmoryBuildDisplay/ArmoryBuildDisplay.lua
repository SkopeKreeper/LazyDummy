ArmoryBuildDisplay = {
    name = "ArmoryBuildDisplay",
    displayName = "Armory Build Display",
    varVersion = 4,
    vars = {},
    defaults = {
        hideOnPrimaryBuild = false,
        primaryBuildID = 1,
        lastBuildID = -1,
        lastBuildIconID = -1,
        left = 440,
        top = 110,
        prefix = "Build:",
        enabled = true,
        showIcon = true,
        displaySize = 100,
        textColor = {1, 1, 1, 1},
        iconColor = {1, 1, 1, 1}
    },
    displayMinSize = 35,
    maxArmorySlots = 10
}

local EM = EVENT_MANAGER
local ARMORY_NUM_BUILD_ICONS = ZO_ARMORY_NUM_BUILD_ICONS or 74
local ARMORY_BUILD_ICON_TEXTURE_FORMATTER = ZO_ARMORY_BUILD_ICON_TEXTURE_FORMATTER or "/esoui/art/armory/buildicons/buildicon_%d.dds"



--Get variable helper function
function ArmoryBuildDisplay.GetVar(varName)
    --If the variable is not set, return the default value
    if ArmoryBuildDisplay.vars[varName] == nil then
        return ArmoryBuildDisplay.defaults[varName]
    end
    return ArmoryBuildDisplay.vars[varName]
end

--Set variable helper function
function ArmoryBuildDisplay.SetVar(varName, value)
    ArmoryBuildDisplay.vars[varName] = value
end

--Returns the name of a build based on its ID. If its name is blank, give a generic numbered name.
function ArmoryBuildDisplay.GetArmoryBuildName(buildID)
    local buildName = ""
    if buildID > 0 then
        buildName = GetArmoryBuildName(buildID)
        if buildName == nil or buildName == "" then
            buildName = "Build " .. buildID
        end
    else
        buildName = ""
    end
    return buildName
end

-- Returns a list of possible build names
function ArmoryBuildDisplay.GetBuildsList(withNum)
    withNum = withNum or false
    local choices = {}
    for i = 1, GetNumUnlockedArmoryBuilds() do
        local buildName = ArmoryBuildDisplay.GetArmoryBuildName(i)
        if withNum then
            buildName = i .. ": " .. buildName
        end
        table.insert(choices, buildName)
    end
    ArmoryBuildDisplay.SetVar("builds", choices)
    return choices
end

-- Returns a list of possible build IDs
function ArmoryBuildDisplay.GetBuildsIDList()
    local buildIDs = {}
    for i = 1, GetNumUnlockedArmoryBuilds() do
        buildIDs[#buildIDs + 1] = i
    end
    return buildIDs
end

function ArmoryBuildDisplay.OnAddOnLoaded(eventCode, addonName)
    --If the addon is not the correct, exit
    if (addonName ~= ArmoryBuildDisplay.name) then
        return
    end
    EM:UnregisterForEvent(ArmoryBuildDisplay.name, EVENT_ADD_ON_LOADED) --Unregister the event now that we are loading

    --Create the HUD fragment to use as our display
    ArmoryBuildDisplay.fragment = ZO_HUDFadeSceneFragment:New(ArmoryBuildDisplayFrame)

    --Initialize the variables for the addon by loading the saved variables or setting them to the default values if they don't exist
    ArmoryBuildDisplay.vars =
        ZO_SavedVars:NewCharacterIdSettings(
        "ArmoryBuildDisplaySavedVariables",
        ArmoryBuildDisplay.varVersion,
        nil,
        ArmoryBuildDisplay.defaults
    )

    -- Check the that the display size is not too small. If it is, reset to default.
    if ArmoryBuildDisplay.GetVar("displaySize") < ArmoryBuildDisplay.displayMinSize then
        ArmoryBuildDisplay.SetVar("displaySize", ArmoryBuildDisplay.defaults.displaySize)
    end

    --Draw the display
    ArmoryBuildDisplay.ApplySettings()

    --Create the Addon Menu
    ArmoryBuildDisplay.CreateMenu()
end

--Callback for when the user has dragged the display to a new position
function ArmoryBuildDisplay.OnMoveStop()
    ArmoryBuildDisplay.SetVar("left", ArmoryBuildDisplayFrame:GetLeft())
    ArmoryBuildDisplay.SetVar("top", ArmoryBuildDisplayFrame:GetTop())
end

--Callback from the ZOS Armory Manager when a full update has been triggered
function ArmoryBuildDisplay.BuildFullUpdate(_, buildIndex)
    --CHAT_SYSTEM:AddMessage("ArmoryBuildDisplay EVENT_ARMORY_BUILDS_FULL_UPDATE")
    ArmoryBuildDisplay.UpdateBuildIDs(buildIndex)
end

--Callback from the ZOS Armory Manager when a build has been updated
function ArmoryBuildDisplay.BuildUpdate(_, buildIndex)
    --CHAT_SYSTEM:AddMessage("ArmoryBuildDisplay EVENT_ARMORY_BUILD_UPDATED")
    ArmoryBuildDisplay.UpdateBuildIDs(buildIndex)
end

--Callback from the ZOS Armory Manager when a build has been restored/loaded
function ArmoryBuildDisplay.BuildRestored(_, result, buildIndex)
    --CHAT_SYSTEM:AddMessage("ArmoryBuildDisplay EVENT_ARMORY_BUILD_RESTORE_RESPONSE")
    ArmoryBuildDisplay.UpdateBuildIDs(buildIndex)
end

--Store the last build ID and if build ID is valid, store the last build icon ID and update the display
function ArmoryBuildDisplay.UpdateBuildIDs(buildIndex)
    if buildIndex ~= nil then
        ArmoryBuildDisplay.SetVar("lastBuildID", buildIndex)
        if buildIndex > 0 then
            ArmoryBuildDisplay.SetVar("lastBuildIconID", GetArmoryBuildIconIndex(buildIndex))
        end
        ArmoryBuildDisplay.UpdateUI()
    end
end

-- Shows the build display
function ArmoryBuildDisplay.Show()
    SCENE_MANAGER:GetScene("hud"):AddFragment(ArmoryBuildDisplay.fragment)
    SCENE_MANAGER:GetScene("hudui"):AddFragment(ArmoryBuildDisplay.fragment)
    ArmoryBuildDisplayFrame:SetHidden(false)
end

--Hides the build display
function ArmoryBuildDisplay.Hide()
    SCENE_MANAGER:GetScene("hud"):RemoveFragment(ArmoryBuildDisplay.fragment)
    SCENE_MANAGER:GetScene("hudui"):RemoveFragment(ArmoryBuildDisplay.fragment)
    ArmoryBuildDisplayFrame:SetHidden(true)
end


--Handles the display and formating of the build icon.
function ArmoryBuildDisplay.SetBuildIcon(buildIconIndex)
    -- Set the build icon texture if valid otherwise show a blank icon.
    if buildIconIndex >= 1 and buildIconIndex <= ARMORY_NUM_BUILD_ICONS and ArmoryBuildDisplay.GetVar("showIcon") then
        ArmoryBuildDisplayFrame:GetNamedChild("Icon"):SetTexture(
            string.format(ARMORY_BUILD_ICON_TEXTURE_FORMATTER , ArmoryBuildDisplay.vars.lastBuildIconID)
        )
    else
        ArmoryBuildDisplayFrame:GetNamedChild("Icon"):SetTexture("/esoui/art/icons/heraldrycrests_misc_blank_01.dds")
    end

    --If a custom icon color is set, use it. Otherwise, use the default color.
    if not ArmoryBuildDisplay.GetVar("iconColor") then
        ArmoryBuildDisplayFrame:GetNamedChild("Icon"):SetColor(unpack(ArmoryBuildDisplay.defaults.iconColor))
    else
        ArmoryBuildDisplayFrame:GetNamedChild("Icon"):SetColor(unpack(ArmoryBuildDisplay.GetVar("iconColor")))
    end
end

--Handles the display and formating of the build name.
function ArmoryBuildDisplay.SetBuildText(buildIndex)
    if buildIndex >= 1 then
        ArmoryBuildDisplayFrameLabel:SetText(
            string.format(
                "%s %s",
                string.gsub(ArmoryBuildDisplay.GetVar("prefix"), "None", "", 1),
                ArmoryBuildDisplay.GetArmoryBuildName(ArmoryBuildDisplay.GetVar("lastBuildID"))
            )
        )
    else
        ArmoryBuildDisplayFrameLabel:SetText("BUILD UNKNOWN!")
    end

    if not ArmoryBuildDisplay.GetVar("textColor") then
        ArmoryBuildDisplayFrameLabel:SetColor(unpack(ArmoryBuildDisplay.defaults.textColor))
    else
        --ArmoryBuildDisplayFrameLabel:SetColor(unpack(ArmoryBuildDisplay.GetVar("textColor")))
        
		if ArmoryBuildDisplay.GetArmoryBuildName(ArmoryBuildDisplay.GetVar("lastBuildID")):find("craft") then
			ArmoryBuildDisplayFrameLabel:SetColor(0, 1, 0)
		else 		
			ArmoryBuildDisplayFrameLabel:SetColor(1, 0, 0)
			
		end
    end
end


--Updates the UI with the current build data.
function ArmoryBuildDisplay.UpdateUI()
    -- If disabled or hidden on primary build is selected while current build is primary, hide the display.
    if  ArmoryBuildDisplay.GetVar("enabled") == false or
            (ArmoryBuildDisplay.GetVar("hideOnPrimaryBuild") and
                ArmoryBuildDisplay.GetVar("lastBuildID") == ArmoryBuildDisplay.GetVar("primaryBuildID"))
     then
        ArmoryBuildDisplay.Hide()
        return
    end

    --Setup frame
    ArmoryBuildDisplayFrame:ClearAnchors()
    ArmoryBuildDisplayFrame:SetAnchor(
        TOPLEFT,
        GuiRoot,
        TOPLEFT,
        ArmoryBuildDisplay.GetVar("left"),
        ArmoryBuildDisplay.GetVar("top")
    )

    --Set scale
    ArmoryBuildDisplayFrame:SetScale(ArmoryBuildDisplay.vars.displaySize / 100)

    --Set icon and name
    ArmoryBuildDisplay.SetBuildIcon(ArmoryBuildDisplay.GetVar("lastBuildIconID"))
    ArmoryBuildDisplay.SetBuildText(ArmoryBuildDisplay.GetVar("lastBuildID"))

    --if no previous build id, hide the display
    if ArmoryBuildDisplay.GetVar("lastBuildID") ~= -1 then
        ArmoryBuildDisplay.Show()
    --else
    --    ArmoryBuildDisplay.Hide()
    end
end

--Registers to Armory events to know when to update the UI.
function ArmoryBuildDisplay.RegisterEvents()
    EM:RegisterForEvent(ArmoryBuildDisplay.name, EVENT_ARMORY_BUILD_UPDATED, ArmoryBuildDisplay.BuildUpdate)
    EM:RegisterForEvent(ArmoryBuildDisplay.name, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, ArmoryBuildDisplay.BuildRestored)
end

--Unregisters all Armory events.
function ArmoryBuildDisplay.UnRegisterEvents()
    EM:UnregisterForEvent(ArmoryBuildDisplay.name, EVENT_ARMORY_BUILD_UPDATED)
    EM:UnregisterForEvent(ArmoryBuildDisplay.name, EVENT_ARMORY_BUILD_RESTORE_RESPONSE)
end


--Triggers the UI update.
function ArmoryBuildDisplay.ApplySettings()
    if ArmoryBuildDisplay.GetVar("enabled") then
        ArmoryBuildDisplay.RegisterEvents()
    else
        ArmoryBuildDisplay.UnRegisterEvents()
    end
    ArmoryBuildDisplay.UpdateUI()
end

--Load addon
EM:RegisterForEvent(ArmoryBuildDisplay.name, EVENT_ADD_ON_LOADED, ArmoryBuildDisplay.OnAddOnLoaded)
