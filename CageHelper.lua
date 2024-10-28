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
local petCounts = {}  -- Table to store the count of each species of pets
local petIDs = {}  -- Table to store the pet IDs for each species
local petLevels = {}  -- Table to store the pet levels for each species

-- Function to print debug messages if debug is true
local function DebugPrint(...)
    if debug then
        print(...)  -- Print debug messages if debug mode is enabled
    end
end

-- Function to scan the player's pet journal and identify duplicate cageable pets
local function ScanPets()
    petCounts = {}  -- Reset petCounts table
    petIDs = {}  -- Reset petIDs table
    petLevels = {}  -- Reset petLevels table
    local numPets = C_PetJournal.GetNumPets(false)  -- Get the total number of pets in the journal

    DebugPrint("Number of pets in journal:", numPets)  -- Debug message to show the total number of pets

    for i = 1, numPets do
        -- Get pet information by index
        local petID, speciesID, _, _, level, isFavorite, isRevoked, speciesName, _, _, isTradeable = C_PetJournal.GetPetInfoByIndex(i)
        
        -- Check if the pet is cageable and not revoked
        local isCageable = petID and speciesID and C_PetJournal.PetIsTradable(petID) and not isRevoked

        if isCageable then  -- Only consider pets that are cageable
            petCounts[speciesID] = (petCounts[speciesID] or 0) + 1  -- Increment the count for this species
            petIDs[speciesID] = petIDs[speciesID] or {}  -- Initialize petIDs table for this species if it doesn't exist
            petLevels[speciesID] = petLevels[speciesID] or {}  -- Initialize petLevels table for this species if it doesn't exist
            table.insert(petIDs[speciesID], petID)  -- Store the pet ID
            table.insert(petLevels[speciesID], level)  -- Store the pet level
            DebugPrint("Species ID:", speciesID, "Name:", speciesName, "Level:", level, "Count:", petCounts[speciesID])  -- Debug message to show each species, name, level, and count
        else
            DebugPrint("Skipping pet - Species ID:", speciesID, "Name:", speciesName, "Reason: Not cageable or revoked")  -- Debug message for skipped pets
        end
    end
end

-- Function to display the duplicate pets in a custom Ace3 UI frame
local function ShowDuplicatePets()
    if CageHelperFrame then  -- If the UI frame already exists
        if CageHelperFrame:IsShown() then
            CageHelperFrame:Hide()  -- Hide the frame if it is currently shown
        else
            CageHelperFrame:Show()  -- Show the frame if it is currently hidden
        end
        return
    end

    -- Create the main frame for the UI
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Cageable Duplicate Pets")  -- Set the title of the frame
    frame:SetStatusText("List of duplicate cageable pets")  -- Set the status text
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) CageHelperFrame = nil end)  -- Release the frame when closed
    frame:SetLayout("Fill")  -- Set the layout of the frame to fill available space
    frame:SetWidth(600)  -- Set the fixed width of the frame
    frame:SetHeight(800)  -- Set the initial height of the frame
    frame.frame:SetPoint("CENTER")  -- Center the frame on the screen

    -- Hook the OnSizeChanged event to prevent resizing below a minimum size
    local MIN_WIDTH = 600
    local MIN_HEIGHT = 500

    frame.frame:HookScript("OnSizeChanged", function(self, width, height)
        if width < MIN_WIDTH then
            self:SetWidth(MIN_WIDTH)
        end
        if height < MIN_HEIGHT then
            self:SetHeight(MIN_HEIGHT)
        end
    end)

    -- Create a container for scrolling
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)  -- Set the container to take the full width of the frame
    scrollContainer:SetFullHeight(true)  -- Set the container to take the full height of the frame
    scrollContainer:SetLayout("Fill")  -- Set the layout to fill the space
    frame:AddChild(scrollContainer)  -- Add the container to the frame

    -- Add a scroll frame inside the container
    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("List")  -- Set the layout of the scroll frame to be a list
    scrollContainer:AddChild(scrollFrame)  -- Add the scroll frame to the container

    local foundDuplicates = false  -- Flag to track if any duplicates are found
    for speciesID, count in pairs(petCounts) do
        if count > 1 then  -- If the player has more than 1 of a species (duplicates)
            foundDuplicates = true
            local speciesName, icon = C_PetJournal.GetPetInfoBySpeciesID(speciesID)  -- Get the species name and icon

            DebugPrint("Duplicate found - Species ID:", speciesID, "Name:", speciesName, "Count:", count)  -- Debug message for duplicates

            -- Sort pet levels for consistent display
            table.sort(petLevels[speciesID])

            -- Create a horizontal group to hold the icon, label, and buttons
            local petGroup = AceGUI:Create("SimpleGroup")
            petGroup:SetFullWidth(true)
            petGroup:SetLayout("Flow")
            scrollFrame:AddChild(petGroup)

            -- Create an icon for each duplicate pet species
            local petIcon = CreateFrame("Button", nil, petGroup.frame)
            petIcon:SetSize(30, 30)
            petIcon:SetNormalTexture(icon)
            petIcon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            petIcon:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

            -- Add tooltip handling for the pet icon
            petIcon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local petLink = C_PetJournal.GetBattlePetLink(petIDs[speciesID][1])
                if petLink then
                    GameTooltip:SetHyperlink(petLink)
                end
                GameTooltip:Show()
            end)

            petIcon:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- Attach the icon frame to the Ace3 frame system
            local petIconWidget = AceGUI:Create("Label")
            petIconWidget:SetWidth(35)
            petIconWidget.frame = petIcon
            petGroup:AddChild(petIconWidget)

            -- Create a label for each duplicate pet species
            local petLabel = AceGUI:Create("Label")
            local levelsText = table.concat(petLevels[speciesID], ", ")  -- Concatenate levels of all duplicates
            petLabel:SetText(speciesName .. " (" .. count .. ") Levels: " .. levelsText)  -- Label text shows species, count, and levels
            petLabel:SetWidth(200)  -- Set the width of the label for better alignment
            petGroup:AddChild(petLabel)  -- Add the label to the horizontal group

            -- Declare the buttons outside to have a shared reference
            local cageLowestButton, cageHighestButton

            -- Create a button to cage the lowest level pet
            cageLowestButton = AceGUI:Create("Button")
            cageLowestButton:SetText("Cage Lowest")  -- Set the button text
            cageLowestButton:SetWidth(120)  -- Set the button width to show full text
            cageLowestButton:SetCallback("OnClick", function()
                local lowestLevel = math.huge  -- Set the initial lowest level to a very high value
                local lowestIndex = nil  -- Variable to store the index of the lowest level pet
                for index, level in ipairs(petLevels[speciesID]) do
                    if level < lowestLevel then  -- Find the pet with the lowest level
                        lowestLevel = level
                        lowestIndex = index
                    end
                end
                if lowestIndex then  -- If a lowest level pet is found
                    local lowestPetID = petIDs[speciesID][lowestIndex]  -- Get the pet ID of the lowest level pet
                    C_PetJournal.CagePetByID(lowestPetID)  -- Cage the pet
                    petCounts[speciesID] = petCounts[speciesID] - 1  -- Decrement the count for this species
                    table.remove(petIDs[speciesID], lowestIndex)  -- Remove the pet ID from the list
                    table.remove(petLevels[speciesID], lowestIndex)  -- Remove the pet level from the list

                    if petCounts[speciesID] <= 1 then  -- If only one or no pets are left
                        petLabel:SetText(speciesName .. " (" .. petCounts[speciesID] .. ") Levels: " .. table.concat(petLevels[speciesID], ", "))  -- Update the label text
                        cageLowestButton:SetDisabled(true)  -- Disable the lowest button
                        cageHighestButton:SetDisabled(true)  -- Disable the highest button
                    else
                        petLabel:SetText(speciesName .. " (" .. petCounts[speciesID] .. ") Levels: " .. table.concat(petLevels[speciesID], ", "))  -- Update the count on the label
                    end
                    DebugPrint("Caging lowest level pet:", speciesName, "(ID:", lowestPetID, ")")  -- Debug message for caging
                end
            end)
            petGroup:AddChild(cageLowestButton)  -- Add the button to the horizontal group

            -- Create a button to cage the highest level pet
            cageHighestButton = AceGUI:Create("Button")
            cageHighestButton:SetText("Cage Highest")  -- Set the button text
            cageHighestButton:SetWidth(120)  -- Set the button width to show full text
            cageHighestButton:SetCallback("OnClick", function()
                local highestLevel = -1  -- Set the initial highest level to a very low value
                local highestIndex = nil  -- Variable to store the index of the highest level pet
                for index, level in ipairs(petLevels[speciesID]) do
                    if level > highestLevel then  -- Find the pet with the highest level
                        highestLevel = level
                        highestIndex = index
                    end
                end
                if highestIndex then  -- If a highest level pet is found
                    local highestPetID = petIDs[speciesID][highestIndex]  -- Get the pet ID of the highest level pet
                    C_PetJournal.CagePetByID(highestPetID)  -- Cage the pet
                    petCounts[speciesID] = petCounts[speciesID] - 1  -- Decrement the count for this species
                    table.remove(petIDs[speciesID], highestIndex)  -- Remove the pet ID from the list
                    table.remove(petLevels[speciesID], highestIndex)  -- Remove the pet level from the list

                    if petCounts[speciesID] <= 1 then  -- If only one or no pets are left
                        petLabel:SetText(speciesName .. " (" .. petCounts[speciesID] .. ") Levels: " .. table.concat(petLevels[speciesID], ", "))  -- Update the label text
                        cageLowestButton:SetDisabled(true)  -- Disable the lowest button
                        cageHighestButton:SetDisabled(true)  -- Disable the highest button
                    else
                        petLabel:SetText(speciesName .. " (" .. petCounts[speciesID] .. ") Levels: " .. table.concat(petLevels[speciesID], ", "))  -- Update the count on the label
                    end
                    DebugPrint("Caging highest level pet:", speciesName, "(ID:", highestPetID, ")")  -- Debug message for caging
                end
            end)
            petGroup:AddChild(cageHighestButton)  -- Add the button to the horizontal group
        end
    end

    if not foundDuplicates then  -- If no duplicates are found
        local noDuplicatesLabel = AceGUI:Create("Label")
        noDuplicatesLabel:SetText("No duplicate cageable pets found.")  -- Inform the user that no duplicates were found
        noDuplicatesLabel:SetWidth(300)  -- Set the width of the label
        scrollFrame:AddChild(noDuplicatesLabel)  -- Add the label to the scroll frame
    end

    CageHelperFrame = frame  -- Store the frame in a global variable to keep track of it
end

-- Hook events to ensure Pet Journal is loaded before scanning pets
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")  -- Register the ADDON_LOADED event
frame:RegisterEvent("PLAYER_LOGIN")  -- Register the PLAYER_LOGIN event

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == "CageHelper" then  -- If the CageHelper addon is loaded
        print("CageHelper addon loaded.")  -- Print a message indicating the addon has loaded
        SLASH_CAGEHELPER1 = "/ch"  -- Register the slash command /ch
        SlashCmdList["CAGEHELPER"] = function()
            if CageHelperFrame then  -- If the frame already exists
                if CageHelperFrame:IsShown() then
                    CageHelperFrame:Hide()  -- Hide the frame if it is currently shown
                else
                    CageHelperFrame:Show()  -- Show the frame if it is currently hidden
                end
            else
                ShowDuplicatePets()  -- Show the UI if it's not already created
            end
        end
        print("CageHelper slash command registered.")  -- Print a message indicating the slash command has been registered
    elseif event == "PLAYER_LOGIN" then  -- If the player logs in
        C_Timer.After(2, function()
            ScanPets()  -- Scan pets once after /reload or logging in
            ShowDuplicatePets()  -- Automatically show the UI after /reload or logging in
        end)
    end
end)