local AceGUI = LibStub("AceGUI-3.0")

-- Check if Ace3 is properly loaded
if not LibStub then
    print("LibStub is missing.")
    return
end

if not LibStub:GetLibrary("AceGUI-3.0", true) then
    print("AceGUI-3.0 is missing.")
    return
end

-- Debug flag to control debug messages
local debug = false

-- Global variables to store pet data
local petCounts = {}
local petIDs = {}
local petLevels = {}

-- Function to print debug messages if debug is true
local function DebugPrint(...)
    if debug then
        print(...)
    end
end

-- Function to scan the player's pet journal and identify duplicate cageable pets
local function ScanPets()
    petCounts = {}
    petIDs = {}
    petLevels = {}
    local numPets = C_PetJournal.GetNumPets(false)

    DebugPrint("Number of pets in journal:", numPets)  -- Debug message to show the total number of pets

    for i = 1, numPets do
        local petID, speciesID, _, _, level, isFavorite, isRevoked, speciesName, _, _, isTradeable = C_PetJournal.GetPetInfoByIndex(i)
        
        -- Check if the pet is cageable and not revoked or locked
        local isCageable = C_PetJournal.PetIsTradable(petID) and not isRevoked

        if speciesID and isCageable then
            petCounts[speciesID] = (petCounts[speciesID] or 0) + 1
            petIDs[speciesID] = petIDs[speciesID] or {}
            petLevels[speciesID] = petLevels[speciesID] or {}
            table.insert(petIDs[speciesID], petID)
            table.insert(petLevels[speciesID], level)
            DebugPrint("Species ID:", speciesID, "Name:", speciesName, "Level:", level, "Count:", petCounts[speciesID])  -- Debug message to show each species, name, level, and count
        else
            DebugPrint("Skipping pet - Species ID:", speciesID, "Name:", speciesName, "Reason: Not cageable or revoked")
        end
    end
end

-- Function to display the duplicate pets in a custom Ace3 UI frame
local function ShowDuplicatePets()
    if CageHelperFrame then
        if CageHelperFrame:IsShown() then
            CageHelperFrame:Hide()
        else
            CageHelperFrame:Show()
        end
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Cageable Duplicate Pets")
    frame:SetStatusText("List of duplicate cageable pets")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) CageHelperFrame = nil end)
    frame:SetLayout("Flow")
    frame:SetWidth(400)
    frame:SetHeight(500)
    frame:SetAutoAdjustHeight(true)

    local scrollContainer = AceGUI:Create("SimpleGroup")  -- Create a container for scrolling
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    frame:AddChild(scrollContainer)

    local scrollFrame = AceGUI:Create("ScrollFrame")  -- Add a scroll frame
    scrollFrame:SetLayout("Flow")
    scrollContainer:AddChild(scrollFrame)

    local foundDuplicates = false
    for speciesID, count in pairs(petCounts) do
        if count > 1 then  -- If the player has more than 1 of a species (duplicates)
            foundDuplicates = true
            local speciesName = C_PetJournal.GetPetInfoBySpeciesID(speciesID)

            DebugPrint("Duplicate found - Species ID:", speciesID, "Name:", speciesName, "Count:", count)  -- Debug message for duplicates

            -- Create a label for each duplicate pet species
            local petLabel = AceGUI:Create("Label")
            petLabel:SetText(speciesName .. " (" .. count .. ")")  -- Label text shows species and count
            petLabel:SetWidth(250)
            scrollFrame:AddChild(petLabel)

            -- Declare the buttons outside to have a shared reference
            local cageLowestButton, cageHighestButton

            -- Create a button to cage the lowest level pet
            cageLowestButton = AceGUI:Create("Button")
            cageLowestButton:SetText("Cage Lowest")
            cageLowestButton:SetWidth(150)
            cageLowestButton:SetCallback("OnClick", function()
                local lowestLevel = math.huge
                local lowestIndex = nil
                for index, level in ipairs(petLevels[speciesID]) do
                    if level < lowestLevel then
                        lowestLevel = level
                        lowestIndex = index
                    end
                end
                if lowestIndex then
                    local lowestPetID = petIDs[speciesID][lowestIndex]
                    C_PetJournal.CagePetByID(lowestPetID)
                    petCounts[speciesID] = petCounts[speciesID] - 1
                    table.remove(petIDs[speciesID], lowestIndex)
                    table.remove(petLevels[speciesID], lowestIndex)

                    if petCounts[speciesID] <= 1 then
                        petLabel:SetText(speciesName .. " (" .. petCounts[speciesID] .. ")")
                        cageLowestButton:SetDisabled(true)
                        cageHighestButton:SetDisabled(true)
                    else
                        petLabel:SetText(speciesName .. " (" .. petCounts[speciesID] .. ")")  -- Update the count
                    end
                    DebugPrint("Caging lowest level pet:", speciesName, "(ID:", lowestPetID, ")")  -- Debug message for caging
                end
            end)
            scrollFrame:AddChild(cageLowestButton)

            -- Create a button to cage the highest level pet
            cageHighestButton = AceGUI:Create("Button")
            cageHighestButton:SetText("Cage Highest")
            cageHighestButton:SetWidth(150)
            cageHighestButton:SetCallback("OnClick", function()
                local highestLevel = -1
                local highestIndex = nil
                for index, level in ipairs(petLevels[speciesID]) do
                    if level > highestLevel then
                        highestLevel = level
                        highestIndex = index
                    end
                end
                if highestIndex then
                    local highestPetID = petIDs[speciesID][highestIndex]
                    C_PetJournal.CagePetByID(highestPetID)
                    petCounts[speciesID] = petCounts[speciesID] - 1
                    table.remove(petIDs[speciesID], highestIndex)
                    table.remove(petLevels[speciesID], highestIndex)

                    if petCounts[speciesID] <= 1 then
                        petLabel:SetText(speciesName .. " (" .. petCounts[speciesID] .. ")")
                        cageLowestButton:SetDisabled(true)
                        cageHighestButton:SetDisabled(true)
                    else
                        petLabel:SetText(speciesName .. " (" .. petCounts[speciesID] .. ")")  -- Update the count
                    end
                    DebugPrint("Caging highest level pet:", speciesName, "(ID:", highestPetID, ")")  -- Debug message for caging
                end
            end)
            scrollFrame:AddChild(cageHighestButton)
        end
    end

    if not foundDuplicates then
        local noDuplicatesLabel = AceGUI:Create("Label")
        noDuplicatesLabel:SetText("No duplicate cageable pets found.")
        noDuplicatesLabel:SetWidth(300)
        scrollFrame:AddChild(noDuplicatesLabel)
    end

    CageHelperFrame = frame
end

-- Hook events to ensure Pet Journal is loaded before scanning pets
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == "CageHelper" then
        print("CageHelper addon loaded.")
        SLASH_CAGEHELPER1 = "/ch"
        SlashCmdList["CAGEHELPER"] = function()
            if CageHelperFrame then
                if CageHelperFrame:IsShown() then
                    CageHelperFrame:Hide()
                else
                    CageHelperFrame:Show()
                end
            else
                ShowDuplicatePets()  -- Show the UI if it's not already created
            end
        end
        print("CageHelper slash command registered.")
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(2, function()
            ScanPets()  -- Scan pets once after /reload or logging in
            ShowDuplicatePets()  -- Automatically show the UI after /reload or logging in
        end)
    end
end)