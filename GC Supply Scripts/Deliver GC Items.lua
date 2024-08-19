-- This script assumes you have all the items needed on all characters and delivers them to their gc
-- This is a fully automated script
-- You should use the Yes Already plugin to bypass the capped seals warning or it will break the script

-- ###########
-- # CONFIGS #
-- ###########

local use_external_character_list = true  -- Options: true = uses the external character list in the same folder, default name being CharList.lua, false uses the list you put in this file 

-- This is where you put your character list if you choose to not use the external one
-- If us_external_character_list is set to true then this list is completely skipped
local character_list = {
    "First Last@Server",
    "First Last@Server"
}

-- Edit CharList.lua file for configuring characters

-- #####################################
-- #  DON'T TOUCH ANYTHING BELOW HERE  #
-- # UNLESS YOU KNOW WHAT YOU'RE DOING #
-- #####################################

CharList = "CharList.lua"

SNDConfigFolder = os.getenv("appdata") .. "\\XIVLauncher\\pluginConfigs\\SomethingNeedDoing\\"
LoadFunctionsFileLocation = os.getenv("appdata") .. "\\XIVLauncher\\pluginConfigs\\SomethingNeedDoing\\vac_functions.lua"
LoadFunctions = loadfile(LoadFunctionsFileLocation)
LoadFunctions()
LoadFileCheck()
LogInfo("[DGCI] ##############################")
LogInfo("[DGCI] Starting script...")
LogInfo("[DGCI] SNDConfigFolder: " .. SNDConfigFolder)
LogInfo("[DGCI] CharList: " .. CharList)
LogInfo("[DGCI] SNDC+Char: " .. SNDConfigFolder .. "" .. CharList)
LogInfo("[DGCI] ##############################")
if use_external_character_list then
    local char_data = dofile(SNDConfigFolder .. CharList)
    character_list = char_data.character_list
end

MULTICHAR = true

-- #############
-- # DOL STUFF #
-- #############

function DOL()
    local home = false
    
    if GetCurrentWorld() == GetHomeWorld() then
        home = true
    else
        if not ZoneCheck(129) then
            Teleporter("Limsa", "tp")
        end
        
        yield("/li")
    end
    
    repeat
        Sleep(0.1)
        
        if GetCurrentWorld() == GetHomeWorld() then
            if GetCurrentWorld() == 0 and GetHomeWorld() == 0 then
            else
                home = true
            end
        end
    until home
    
    repeat
        Sleep(0.1)
    until IsPlayerAvailable()
    
    if not ZoneCheck(128) then
        Teleporter("Limsa", "tp")
    else
        --Movement(-89.36, 18.80, 1.78) -- this will need rethinking but it's a failsafe if you are already in limsa since /li Aftcastle will break if you are not near a crystal
        PathToObject("Aetheryte", 4)
    end
    
    yield("/li Aftcastle")
    ZoneTransitions()
    Movement(93.00, 40.27, 75.60)
    OpenGcSupplyWindow(1)
    GcProvisioningDeliver()
    CloseGcSupplyWindow()
    LogOut()
end

-- ###############
-- # MAIN SCRIPT #
-- ###############

function Main()
    DOL()
end

if MULTICHAR then
    for _, char in ipairs(character_list) do
        if GetCharacterName(true) == char then
            -- continue, no relogging needed
        else
            if not ZoneCheck(129) then
                Teleporter("Limsa", "tp")
            end
            
            RelogCharacter(char)
            Sleep(7.5)
            LoginCheck()
        end
        repeat
            Sleep(0.1)
        until IsPlayerAvailable()
        Main()
    end
else
    Main()
end
