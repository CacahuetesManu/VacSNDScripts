--[[
############################################################
##                      Questionable                      ##
##                       Companion                        ##
############################################################

####################
##    Version     ##
##     0.0.8      ##
####################

-> 0.0.8: Added the experimental features section, and added an experimental qst reloader which will reload if it finds questionable being stuck
-> 0.0.7: Added a duty whitelist so it won't try to queue duties that don't have duty support
-> 0.0.6: Added unexpected combat handler
-> 0.0.5: Solo instances should be working properly again
-> 0.0.4: Added some extra checks which should cause it to no longer fail to queue into duties
-> 0.0.3: Should no longer vnav rebuild after short periods of time, should now be about 8 seconds
-> 0.0.2: Questionable should now start again after a duty ends
-> 0.0.1: Initial release, it is not tested properly so it might not work as intended. Consider it a testing version of sorts.

####################################################
##                  Description                   ##
####################################################

Just a simple script you can run alongside questionable to have it automatically queue and finish dungeons and instances.
Also has a stuck checker that reloads vnav and if stuck for long enough, rebuilds the zone entirely.

####################################################
##                  Requirements                  ##
####################################################

-> AutoDuty - https://puni.sh/api/repository/herc
-> Boss Mod - https://puni.sh/api/repository/veyn OR BossMod Reborn - https://raw.githubusercontent.com/FFXIV-CombatReborn/CombatRebornRepo/main/pluginmaster.json
-> Lifestream - https://raw.githubusercontent.com/NightmareXIV/MyDalamudPlugins/main/pluginmaster.json
-> Pandora - https://love.puni.sh/ment.json
-> Questionable - https://plugins.carvel.li/
-> Rotation Solver Reborn - https://raw.githubusercontent.com/FFXIV-CombatReborn/CombatRebornRepo/main/pluginmaster.json
-> Something Need Doing (Expanded Edition) - https://puni.sh/api/repository/croizat
-> Textadvance - https://raw.githubusercontent.com/NightmareXIV/MyDalamudPlugins/main/pluginmaster.json
-> Vnavmesh - https://puni.sh/api/repository/veyn

####################################################
##                    Settings                    ##
##################################################]]

-- leave this empty if you don't want the chars to stop at any specific quest, but this will cause it to never try to rotate to another char
local QuestNameToStopAt = ""

-- Toggle if you want bossmod ai to be enabled all the time or only when it's required
local bossmod_ai_outside_of_instances = true

-- Here you provide it a character list to go through, this used alongside the above option will let you get a lot of different character to X quest
local chars = {
    "EXAMPLE CHARACTER@WORLD",
    "EXAMPLE CHARACTER@WORLD",
    "EXAMPLE CHARACTER@WORLD"
}

--[[################################################
##              Experimental Features             ##
##################################################]]

-- will attempt to reload qst whenever it detects it's stuck on a step
local qst_reloader_enabled = false


--[[################################################
##                  Script Start                  ##
##################################################]]
SNDConfigFolder = os.getenv("appdata") .. "\\XIVLauncher\\pluginConfigs\\SomethingNeedDoing\\"
LoadFunctionsFileLocation = SNDConfigFolder.."vac_functions.lua"
LoadFunctions = loadfile(LoadFunctionsFileLocation)
LoadFunctions()
LoadFileCheck()

local whitelisted_duties = {
    "Sastasha",
    "The Tam-Tara Deepcroft",
    "Copperbell Mines",
    "The Bowl of Embers",
    "The Thousand Maws of Toto-Rak",
    "Haukke Manor",
    "Brayflox's Longstop",
    "The Navel",
    "The Stone Vigil",
    "The Howling Eye",
    "Castrum Meridianum",
    "The Praetorium",
    "The Porta Decumana",
    "Snowcloak",
    "The Keeper of the Lake",
    "Sohm Al",
    "The Aery",
    "The Vault",
    "The Great Gubal Library",
    "The Aetherochemical Research Facility",
    "The Antitower",
    "Sohr Khai",
    "Xelphatol",
    "Baelsar's Wall",
    "The Sirensong Sea",
    "Bardam's Mettle",
    "Doma Castle",
    "Castrum Abania",
    "Ala Mhigo",
    "The Drowned City of Skalla",
    "The Burn",
    "The Ghimlyt Dark",
    "Holminster Switch",
    "Dohn Mheg",
    "The Qitana Ravel",
    "Malikah's Well",
    "Mt. Gulg",
    "Amaurot",
    "The Grand Cosmos",
    "Anamnesis Anyder",
    "The Heroes' Gauntlet",
    "Matoya's Relict",
    "Paglth'an",
    "The Tower of Zot",
    "The Tower of Babil",
    "Vanaspati",
    "Ktisis Hyperboreia",
    "The Aitiascope",
    "The Mothercrystal",
    "The Dead Ends",
    "Alzadaal's Legacy",
    "The Fell Court of Troia",
    "Lapis Manalis",
    "The Aetherfont",
    "The Lunar Subterrane",
    "Ihuykatumu",
    "Worqor Zormor",
    "Worqor Lar Dor",
    "The Skydeep Cenote",
    "Vanguard",
    "Origenics",
    "Everkeep",
    "Alexandria"
}

function IsDutyWhitelisted(duty_name)
    -- replaces the dashes square uses with normal ones, just to be extra sure
    local function ReplaceDashes(s)
        return s:gsub("–", "-"):gsub("—", "-"):gsub("‑", "-"):gsub("‐", "-")
    end
    
    -- lowers the string in case there's inconsistencies
    local duty_name_lower = ReplaceDashes(string.lower(duty_name))

    for _, whitelisted_duty in ipairs(whitelisted_duties) do
        local whitelisted_duty_lower = ReplaceDashes(string.lower(whitelisted_duty))
        if whitelisted_duty_lower == duty_name_lower then
            return true
        end
    end
    return false
end

local function rounded_distance(x1, y1, z1, x2, y2, z2)
    local success, result = pcall(function()
        local dx = x2 - x1
        local dy = y2 - y1
        local dz = z2 - z1
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        return math.floor(dist + 0.49999999999999994)
    end)
    if success then
        return result
    else

        return nil
    end
end

local function within_three_units(x1, y1, z1, x2, y2, z2)
    local dist = rounded_distance(x1, y1, z1, x2, y2, z2)
    if dist then
        return dist <= 3
    else
        return false
    end
end

-- Qst reloader stuff
local qst_reloader_player_pos_x = GetPlayerRawXPos()
local qst_reloader_player_pos_y = GetPlayerRawYPos()
local qst_reloader_player_pos_z = GetPlayerRawZPos()
local qst_reloader_counter = 0
local qst_reloader_timer = 0

for _, char in ipairs(chars) do
    local finished = false
    if GetCharacterName(true) == char then
        -- continue, no relogging needed
    else
        RelogCharacter(char)
        Sleep(23.0)
        LoginCheck()
    end
    repeat
        Sleep(0.1)
    until IsPlayerAvailable()
    yield("/at e")
    yield("/qst start")
    yield("/rsr manual")
    if bossmod_ai_outside_of_instances then
        yield("/bmrai on")
    else
        yield("/bmrai off")
    end
    while not finished do
        -- Unexpected combat handler
        if GetCharacterCondition(26) and not GetCharacterCondition(34) then
            if not QuestionableIsRunning() then
                yield("/rsr manual")
                yield("/bmrai on")
                repeat
                    yield("/battletarget")
                    Sleep(0.1)
                until GetTargetName() ~= "" or not GetCharacterCondition(26)
                repeat
                    while GetTargetName() ~= "" and GetCharacterCondition(26) do
                        Sleep(0.1)
                    end
                    yield("/battletarget")
                    Sleep(1)
                until not GetCharacterCondition(26)
                yield("/bmrai off")
                yield("/qst start")
            end
        end

        -- Qst reloader
        if qst_reloader_enabled and QuestionableIsRunning() and not GetCharacterCondition(26) and IsPlayerAvailable() then
            if qst_reloader_counter % 2 == 0 then
                local qst_success_1 -- i just don't like them not being locals
                local qst_success_2 -- i just don't like them not being locals
                local qst_success_3 -- i just don't like them not being locals

                qst_success_1, qst_reloader_player_pos_x = pcall(GetPlayerRawXPos)
                qst_success_2, qst_reloader_player_pos_y = pcall(GetPlayerRawYPos)
                qst_success_3, qst_reloader_player_pos_z = pcall(GetPlayerRawZPos)
            elseif qst_reloader_counter % 2 == 1 then
                local success1, x1 = pcall(GetPlayerRawXPos)
                local success2, y1 = pcall(GetPlayerRawYPos)
                local success3, z1 = pcall(GetPlayerRawZPos)
                if within_three_units(qst_reloader_player_pos_x, qst_reloader_player_pos_y, qst_reloader_player_pos_z, x1, y1, z1) then
                    qst_reloader_timer = qst_reloader_timer + 1
                    if qst_reloader_timer > 10 then
                        yield("/qst reload")
                        qst_reloader_timer = 0
                    end
                else
                    qst_reloader_timer = 0
                end
            end
            qst_reloader_counter = qst_reloader_counter + 1
        end

        -- stuck checker
        if PathIsRunning() then
            local retry_timer = 0
            while PathIsRunning() do
                local success1, x1 = pcall(GetPlayerRawXPos)
                local success2, y1 = pcall(GetPlayerRawYPos)
                local success3, z1 = pcall(GetPlayerRawZPos)
                if not (success1 and success2 and success3) then
                    goto continue
                end
                Sleep(2)
                local success4, x2 = pcall(GetPlayerRawXPos)
                local success5, y2 = pcall(GetPlayerRawYPos)
                local success6, z2 = pcall(GetPlayerRawZPos)
                if not (success4 and success5 and success6) then
                    goto continue
                end
                if within_three_units(x1, y1, z1, x2, y2, z2) and PathIsRunning() then
                    yield("/qst stop")
                    retry_timer = retry_timer + 1
                    if retry_timer > 4 then -- 4 would be about 8 seconds, with some extra time since it waits a second after reloading
                        yield("/vnav rebuild")
                    else
                        yield("/vnav reload")
                    end
                    Sleep(1)
                    yield("/qst start")
                else
                    retry_timer = 0
                end
                ::continue::
            end
        end

        -- Quest checker
        if IsQuestNameAccepted(QuestNameToStopAt) then
            repeat
                Sleep(0.1)
            until IsPlayerAvailable()
            yield("/qst stop")
            finished = true
        end

        -- Duty helper
        if IsAddonReady("ContentsFinder") and DoesObjectExist("Entrance") then
            repeat
                Sleep(1)
            until IsAddonReady("JournalDetail")
            Sleep(2) -- to really make sure it's ready to pull the duty name
            local duty = GetNodeText("JournalDetail", 19)
            if IsDutyWhitelisted(duty) then
                AutoDutyRun(duty)
                Sleep(30)
                repeat
                    Sleep(1)
                until not GetCharacterCondition(34) and not GetCharacterCondition(45) and IsPlayerAvailable()
                Sleep(8) -- redundant but i just want to make sure the player is actually available
                yield("/rsr manual")
                if bossmod_ai_outside_of_instances then
                    yield("/bmrai on")
                else
                    yield("/bmrai off")
                end
                yield("/qst start")
            else
                Echo(duty.." is not on the duty whitelist")
                repeat
                    yield("/pcall ContentsFinder true -1")
                    Sleep(1)
                until not IsAddonVisible("ContentsFinder")
            end
        end

        -- Instance helper
        if IsAddonReady("SelectYesno") or IsAddonReady("DifficultySelectYesNo") then
            Sleep(3)
            local text1 = GetNodeText("SelectYesno", 15)
            local text2 = GetNodeText("DifficultySelectYesNo", 13)
            if string.find(text1, "Commence") or string.find(text2, "Commence") then
                if string.find(text1, "Commence") then
                    repeat
                        yield("/pcall SelectYesno true 0")
                        Sleep(1)
                    until not IsAddonVisible("SelectYesno")
                elseif string.find(text2, "Commence") then
                    repeat
                        yield("/pcall DifficultySelectYesNo true 0")
                        Sleep(1)
                    until not IsAddonVisible("DifficultySelectYesNo")
                end
                ZoneTransitions() -- make sure to wait properly for the transition


                -- specific stuff to deal with an instance where it has to kill a boulder
                if DoesObjectExist("Large Boulder") then
                    yield("/rsr manual")
                    yield("/rotation settings aoetype 0")
                    yield("/bmrai on")
                    yield("/bmrai followtarget on")
                    yield("/bmrai maxdistancetarget 2.5")
                    Sleep(0.5)
                    repeat
                        yield("/target Large Boulder")
                    until GetTargetName() == "Large Boulder"
                    local auto_attack_triggered = false
                    repeat
                        if GetDistanceToTarget() <= 4 and not auto_attack_triggered then
                            DoAction("Auto-attack")
                            Sleep(0.1)
                            if IsTargetInCombat() and GetCharacterCondition(26) then
                                auto_attack_triggered = true
                            end
                        end
                    until GetTargetHP() <= 0
                    yield("/bmrai followtarget off")
                    yield("/rotation settings aoetype 2")
                else
                    Sleep(1)
                    yield("/rsr auto")
                    Sleep(0.5)
                    yield("/bmrai on")
                end
                repeat
                    Sleep(1)
                until not GetCharacterCondition(34) and not GetCharacterCondition(45) and IsPlayerAvailable()
                Sleep(8) -- redundant but i just want to make sure the player is actually available
                yield("/rsr manual")
                if bossmod_ai_outside_of_instances then
                    yield("/bmrai on")
                else
                    yield("/bmrai off")
                end
                yield("/qst start")
            end
        end
        Sleep(1)
    end
    finished = false
    Teleporter("Limsa", "tp")
end
LogOut()