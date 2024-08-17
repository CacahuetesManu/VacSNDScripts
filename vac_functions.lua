-- This file needs to be dropped inside %appdata%\XIVLauncher\pluginConfigs\SomethingNeedDoing\
-- So it should look like this %appdata%\XIVLauncher\pluginConfigs\SomethingNeedDoing\vac_functions.lua
-- It contains the functions required to make the scripts work

function LoadFileCheck()
	yield("/e Successfully loaded the functions file")
end

-- ###############
-- # TO DO STUFF #
-- ###############

-- Full quest list with both quest IDs and key IDs
-- Full zone ID list
-- Maybe convert job IDs to csv
-- Dungeon ID list
-- Distance stuff
-- Redo Teleporter()
-- Redo Movement()
-- Add better unstuck for worsening vnavmesh

-- #####################################
-- #####################################
-- #####################################
-- #####################################

-- InteractAndWait()
--
-- Interacts with the current target and waits until the player is available again before proceeding
function InteractAndWait()
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    yield("/interact")
    repeat
        Sleep(0.1)
    until IsPlayerAvailable()
end

-- Usage: LoginCheck()
-- Waits until player NamePlate is visible and player is ready
function LoginCheck()
    repeat
        Sleep(0.1)
    until IsAddonVisible("NamePlate") and IsPlayerAvailable()
end

-- Usage: VNavChecker()
-- Waits until player no longer has a nav path running
-- Very likely getting removed
function VNavChecker() --Movement checker, does nothing if moving
    repeat
        Sleep(0.1)
    until not PathIsRunning() and IsPlayerAvailable()
end

-- Interact()
--
-- Just interacts with the current target
function Interact()
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    yield("/interact")
end

-- Usage: IsInParty()
-- Checks if player is in a party, returns true if in party, returns false if not in party
function IsInParty()
    return GetPartyMemberName(0) ~= nil and GetPartyMemberName(0) ~= ""
end

-- Usage: ZoneCheck(129) or ZoneCheck(129, "Limsa", "tp")
-- This will need updating once we have an idea on what to do with matching zones IDs to zone names
-- Checks player against zone, and optionally teleports if player not in zone
-- TP location and TP kind not required
-- ZoneTransitions() not required
function ZoneCheck(zone_id, location, tp_kind)
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26) and not GetCharacterCondition(32)

    if GetZoneID() ~= zone_id then
        if location and tp_kind then
            Teleporter(location, tp_kind)
            ZoneTransitions()
        end
        return true -- Returns true once teleport has happened
    else
        return false -- Returns false if zone doesn't match
    end
end

-- Usage: Echo("meow")
--
-- prints provided text into chat
function Echo(text)
    yield("/echo " .. text)
end

-- Usage: Sleep(0.1) or Sleep("0.1")
--
-- replaces yield wait spam, halts the script for X seconds 
function Sleep(time)
    yield("/wait " .. tostring(time))
end

-- Usage: ZoneTransitions()
--
-- Zone transition checker, does nothing if changing zones
function ZoneTransitions()
    repeat 
         Sleep(0.1)
    until GetCharacterCondition(45) or GetCharacterCondition(51)
    repeat 
        Sleep(0.1)
    until not GetCharacterCondition(45) or not GetCharacterCondition(51)
    repeat
        Sleep(0.1)
    until IsPlayerAvailable()
end

-- Usage: QuestNPC("SelectYesno"|"CutSceneSelectString", true, 0)
--
-- NPC interaction handler, only supports one dialogue option for now. DialogueOption optional.
function QuestNPC(DialogueType, DialogueConfirm, DialogueOption)
    while not GetCharacterCondition(32) do
        yield("/interact")
        Sleep(0.1)
    end
    if DialogueConfirm then
        repeat 
            Sleep(0.1)
        until IsAddonVisible(DialogueType)
        if DialogueOption == nil then
            repeat
                yield("/pcall " .. DialogueType .. " true 0")
                Sleep(0.1)
            until not IsAddonVisible(DialogueType)
        else
            repeat
                yield("/pcall " .. DialogueType .. " true " .. DialogueOption)
                Sleep(0.1)
            until not IsAddonVisible(DialogueType)
        end
    end
    repeat
        Sleep(0.1)
    until IsPlayerAvailable()
end

-- Usage: QuestNPCSingle("SelectYesno"|"CutSceneSelectString", true, 0)
--
-- NPC interaction handler. dialogue_option optional.
function QuestNPCSingle(dialogue_type, dialogue_confirm, dialogue_option)
    while not GetCharacterCondition(32) do
        yield("/interact")
        Sleep(0.5)
    end
    if dialogue_confirm then
        repeat 
            Sleep(0.1)
        until IsAddonReady(dialogue_type)
        Sleep(0.5)
        if dialogue_option == nil then
            yield("/pcall " .. dialogue_type .. " true 0")
            Sleep(0.5)
        else
            yield("/pcall " .. dialogue_type .. " true " .. dialogue_option)
            Sleep(0.5)
        end
    end
end

-- not explicitly used
function QuestCombat(target, enemy_max_dist)
    local all_targets = {target}
    local combined_list = {}
    local best_target = 0
    local lowest_distance = 0
    for _, current_target in ipairs(all_targets) do
        local current_list = {} 
        for i = 0, 10 do
            --yield("/echo <list." .. i .. ">")
            yield("/target " .. current_target .. " <list." .. i .. ">")
            Sleep(0.1)
            if (GetTargetName() == target) and GetTargetHP() > 0 and GetDistanceToTarget() <= enemy_max_dist then
                local distance = GetDistanceToTarget()
                table.insert(current_list, {target = current_target, index = i, distance = distance})
            end
        end
        table.sort(current_list, function(a, b) return a.distance < b.distance end)
        if #current_list > 0 and (best_target == 0 or current_list[1].distance < lowest_distance) then
            best_target = #combined_list + 1
            lowest_distance = current_list[1].distance
        end
        for _, entry in ipairs(current_list) do
            table.insert(combined_list, entry)
        end
    end
    if best_target > 0 then
        local best_entry = combined_list[best_target]
        yield("/target " .. best_entry.target .. " <list." .. best_entry.index .. ">")
        --yield("/echo =====================")
        --yield("/echo best_entry.target = " .. tostring(best_entry.target))
        --yield("/echo best_entry.index = " .. tostring(best_entry.index))
        --yield("/echo =====================")
        Sleep(0.5)

        local dist_to_enemy = GetDistanceToTarget()

        if GetTargetHP() > 0 and dist_to_enemy <= enemy_max_dist then
            if GetCharacterCondition(4) then
                repeat
                    yield("/mount")
                    Sleep(0.1)
                until not GetCharacterCondition(4)
            end
            Sleep(1)
            repeat
                yield("/rotation auto")
                yield("/vnavmesh movetarget")
                yield('/ac "Auto-attack"')
                Sleep(0.2)
            until GetDistanceToTarget() <= 3
            yield("/vnavmesh stop")
        end
    end
    if not GetCharacterCondition(26) then
        repeat
            yield('/ac "Auto-attack"')
            Sleep(0.1)
        until GetCharacterCondition(26)
    end
    
    repeat
        Sleep(0.1)
    until GetTargetHP() == 0
    Sleep(0.5)
end

-- Usage: QuestInstance()
--
-- Targetting/Movement Logic for Solo Duties. Pretty sure this is broken atm
-- Needs rewriting
function QuestInstance()
    while true do
        -- Check if GetCharacterCondition(34) is false and exit if so
        if not GetCharacterCondition(34) then
            break
        end

        if not IsPlayerAvailable() then
            Sleep(1.0)
            yield("/pcall SelectYesno true 0")
        elseif GetCharacterCondition(1) then
            yield("/interact")
            Sleep(1.0)
            while IsPlayerCasting() do 
                Sleep(0.5)
            end
            repeat 
                Sleep(0.1)
                -- Check condition in the middle of the loop
                if not GetCharacterCondition(34) then
                    break
                end
            until not IsAddonVisible("SelectYesno")
        elseif not IsPlayerAvailable() and not GetCharacterCondition(26) then
            repeat
                Sleep(0.1)
                -- Check condition in the middle of the loop
                if not GetCharacterCondition(34) then
                    break
                end
            until GetCharacterCondition(34)
        else
            local paused = false
            while GetCharacterCondition(34) do
                if paused then
                    repeat
                        Sleep(0.1)
                        -- Check condition in the middle of the loop
                        if not GetCharacterCondition(34) then
                            break
                        end
                    until GetCharacterCondition(26, false)
                    paused = false
                else
                    Sleep(1.0)
                    yield("/rotation auto")

                    local current_target = GetTargetName()

                    if not current_target or current_target == "" then
                        yield("/targetenemy") 
                        current_target = GetTargetName()
                        if current_target == "" then
                            Sleep(1.0)
                        end
                    end

                    local enemy_max_dist = 100
                    local dist_to_enemy = GetDistanceToTarget()

                    if dist_to_enemy and dist_to_enemy > 0 and dist_to_enemy <= enemy_max_dist then
                        local enemy_x, enemy_y, enemy_z = GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos()
                        yield("/vnavmesh moveto " .. enemy_x .. " " .. enemy_y .. " " .. enemy_z)
                        Sleep(3.0)
                        yield("/vnavmesh stop")  
                    end

                    -- Check condition to pause
                    if not IsPlayerAvailable() or not GetCharacterCondition(26, true) then
                        paused = true
                    end
                end

                -- Check condition at the end of the loop iteration
                if not GetCharacterCondition(34) then
                    break
                end
            end
        end

        -- Check condition at the end of the loop iteration
        if not GetCharacterCondition(34) then
            break
        end
    end
end

-- Usage: GetNodeTextLookupUpdate("_ToDolist",16,3,4) // GetNodeTextLookupUpdate("_ToDolist",16,3)
--
-- function i really don't like the existence of, is only called by Questchecker and Nodescanner, could be called manually.
function GetNodeTextLookupUpdate(get_node_text_type, get_node_text_location, get_node_text_location_1, get_node_text_location_2)
    bypass = "next task"
    if get_node_text_location_2 == nil then 
        LogInfo("GetNodeTextLookupUpdate: "..get_node_text_type.." "..get_node_text_location.." "..get_node_text_location_1)
        get_node_text = GetNodeText(get_node_text_type, get_node_text_location, get_node_text_location_1)
        if get_node_text == get_node_text_location_1 then
            return bypass
        else
            return get_node_text
        end
    --- i hate
    else
        LogInfo("GetNodeTextLookupUpdate2: "..get_node_text_type.." "..get_node_text_location.." "..get_node_text_location_1.." "..get_node_text_location_2)
        get_node_text = GetNodeText(get_node_text_type, get_node_text_location, get_node_text_location_1, get_node_text_location_2)
        if get_node_text == get_node_text_location_2 then
            return bypass
        else
            return get_node_text
        end
    --- this function
    end
    yield("/echo uh GetNodeTextLookupUpdate fucked up")
end

-- Usage: QuestChecker(ArcanistEnemies[3], 50, "_ToDoList", "Slay little ladybugs.", extra)
--
-- needs a rewrite to deal with hunting logs, for now it works with _ToDoList
-- extra can be a string or a variable it depends on the node text type
function QuestChecker(target_name, target_distance, get_node_text_type, get_node_text_match)
    local get_node_text_location, get_node_text_location_1, get_node_text_location_2 = NodeScanner(get_node_text_type, get_node_text_match)
    local function extractTask(text)
        local task = string.match(text, "^(.-)%s%d+/%d+$")
        return task or text
    end
    while true do
        updated_node_text = GetNodeTextLookupUpdate(get_node_text_type, get_node_text_location, get_node_text_location_1, get_node_text_location_2)
        LogInfo("[JU] updated_node_text: "..updated_node_text)
        LogInfo("[JU] Extract: "..extractTask(updated_node_text))
        local last_char = string.sub(updated_node_text, -1)
        LogInfo("[JU] last char: "..updated_node_text)
        Sleep(2.0)
        if updated_node_text == get_node_text_match or not string.match(last_char, "%d") then
            break
        end
        QuestCombat(target_name, target_distance)
    end
    -- checks if player in combat before ending rotation solver
    if not GetCharacterCondition(26) then
        yield("/rotation off")
    end
end

-- Usage: NodeScanner("_ToDoList", "Slay wild dodos.")
--
-- scans provided node type for node that has provided text and returns minimum 2 but up to 3 variables with the location which you can use with GetNodeText()
--
-- this will fail if the node is too nested and scanning deeper than i am currently is just not a good idea i think
function NodeScanner(get_node_text_type, get_node_text_match)
    node_type_count = tonumber(GetNodeListCount(get_node_text_type))
    local function extractTask(text)
        local task = string.match(text, "^(.-)%s*%d*/%d*$")
        return task or text
    end
    for location = 0, node_type_count do
        for sub_node = 0, 60 do
            Sleep(0.0001)
            local node_check = GetNodeText(get_node_text_type, location, sub_node)
            local clean_node_text = extractTask(node_check)
            if clean_node_text == nil then
            else 
                --LogInfo(tostring(clean_node_text))
            end
            if clean_node_text == get_node_text_match then
                return location, sub_node
            end
        end
    end
    -- deeper scan
    for location = 0, node_type_count do
        for sub_node = 0, 60 do
            for sub_node2 = 0, 20 do
                Sleep(0.0001)
                local node_check = GetNodeText(get_node_text_type, location, sub_node, sub_node2)
                local clean_node_text = extractTask(node_check)
                if clean_node_text == nil then
                else 
                    --LogInfo(tostring(clean_node_text))
                end
                if clean_node_text == get_node_text_match then
                    return location, sub_node, sub_node2
                end
            end
        end
    end
    yield("/echo Can't find the node text, everything will probably crash now since there's no proper handler yet")
    return
end

-- Usage: SpecialUiCheck("MonsterNote", true)
--
-- Closes or opens supported ui's, true is close and false or leaving it empty is open. Probably will be changed into individual functions like i've already done for some
-- or probably will be deprecated
function SpecialUiCheck(get_node_text_type, close_ui, extra)
    -- hunting log checks
    if get_node_text_type == "MonsterNote" then
        if close_ui() then
            OpenGCHuntLog(extra)
        else
            CloseGCHuntLog()
        end
    else
        return
    end
end

-- Usage: OpenHuntLog(9, 0), Defaults to rank 0 if empty
-- Valid classes: 0 = GLA, 1 = PGL, 2 = MRD, 3 = LNC, 4 = ARC, 5 = ROG, 6 = CNJ, 7 = THM, 8 = ACN, 9 = GC
-- Valid ranks/pages: 0-4 for jobs, 0-2 for GC
-- The first variable is the class to open, the second is the rank to open
function OpenHuntLog(class, rank)
    local defaultrank = 0 --
    local defaultclass = 9 -- this is the gc log
    rank = rank or defaultrank
    class = class or defaultclass
    -- 1 Maelstrom
    -- 2 Twin adders
    -- 3 Immortal flames
    repeat
        yield("/huntinglog")
        Sleep(0.5)
    until IsAddonReady("MonsterNote")
    local gc_id = GetPlayerGC()
    if class == 9 then
        yield("/pcall MonsterNote false 3 9 "..tostring(gc_id))
    else 
        yield("/pcall MonsterNote false 0 "..tostring(rank))
    end
    Sleep(0.2)
    yield("/pcall MonsterNote false 1 "..rank)
end

-- Usage: CloseHuntLog()  
-- Closes the Hunting Log if open
function CloseHuntLog()
    repeat
        yield("/huntinglog")
        Sleep(0.5)
    until not IsAddonVisible("MonsterNote")
end

-- Usage: HuntLogCheck("Amalj'aa Hunter", 9, 0)
-- Valid classes: 0 = GLA, 1 = PGL, 2 = MRD, 3 = LNC, 4 = ARC, 5 = ROG, 6 = CNJ, 7 = THM, 8 = ACN, 9 = GC
-- Valid ranks/pages: 0-4 for jobs, 0-2 for GC
-- Opens and checks current progress and returns a true if finished or a false if not
function HuntLogCheck(target_name,class,rank)
    OpenHuntLog(class,rank)
    local node_text = ""
    local function CheckTargetAmountNeeded(sub_node)
        local target_amount = tostring(GetNodeText("MonsterNote", 2, sub_node, 3))
        yield("/echo "..target_amount)
        local first_number = tonumber(target_amount:sub(1, 1))
        local last_number = tonumber(target_amount:sub(-1))
        if first_number == last_number then
            return 0
        else
            return last_number - first_number
        end
    end
    local function FindTargetNode()
        for sub_node = 5, 60 do
            Sleep(0.001)
            node_text = tostring(GetNodeText("MonsterNote", 2, sub_node, 4))
            if node_text == target_name then
                return sub_node
            end
        end
        Echo("HuntingLogChecker failed to find "..target_name)
    end
    local target_amount_needed_node = FindTargetNode()
    if not target_amount_needed_node then
        Echo("Something went wrong, target node not found")
        return "failed"
    else
        yield("/echo dd "..tostring(target_amount_needed_node))
        local target_amount_needed = CheckTargetAmountNeeded(target_amount_needed_node)
        yield("/echo "..tostring(target_amount_needed))
        if target_amount_needed == 0 then
            CloseHuntLog()
            return true, target_amount_needed
        else
            CloseHuntLog()
            return false, target_amount_needed
        end
    end
    CloseHuntLog()
end
-- Usage: DoHuntLog("Amalj'aa Hunter", 40, 9, 0)
-- Valid classes: 0 = GLA, 1 = PGL, 2 = MRD, 3 = LNC, 4 = ARC, 5 = ROG, 6 = CNJ, 7 = THM, 8 = ACN, 9 = GC
-- Valid ranks/pages: 0-4 for jobs, 0-2 for GC
-- Opens and checks current progress of Hunting Log for automated killing
function DoHuntLog(target_name, target_distance, class, rank)
    local finished = false
    local TargetsLeft, AmountLeft = HuntLogCheck(target_name,class,rank)
    if TargetsLeft == "failed" then
        AmountLeft = 0
    else
        if AmountLeft ~= 0 and TargetsLeft then
            while not finished do 
                TargetsLeft, AmountLeft = HuntLogCheck(target_name,class,rank)
                if AmountLeft == 0 then
                    finished = true
                else
                    QuestCombat(target_name, target_distance)
                end
            end
            if not GetCharacterCondition(26) then
                yield("/rotation off")
            end
        end
    end
end


-- Usage: Teleporter("Limsa", "tp") or Teleporter("gc", "li")  
-- add support for item tp Teleporter("Vesper", "item")  
-- likely rewriting teleporter to have own version of lifestream with locations, coords and nav/tp handling
-- add trade detection to initiate /busy and remove after successful tp
-- maybe add random delays between retries
function Teleporter(location, tp_kind) -- Teleporter handler
    local lifestream_stopped = false
    local cast_time_buffer = 5 -- Just in case a buffer is required, teleports are 5 seconds long. Slidecasting, ping and fps can affect casts
    local max_retries = 10  -- Teleporter retry amount, will not tp after number has been reached for safety
    local retries = 0
    
    -- Initial check to ensure player can teleport
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26) and not GetCharacterCondition(32) -- 26 is combat, 32 is quest event
    
    -- Try teleport, retry until max_retries is reached
    while retries < max_retries do
        -- Stop lifestream only once per teleport attempt
        if tp_kind == "li" and not lifestream_stopped then
            yield("/lifestream stop")
            lifestream_stopped = true
            Sleep(0.1)
        end
        
        -- Attempt teleport
        if not IsPlayerCasting() then
            yield("/" .. tp_kind .. " " .. location)
            Sleep(2.0) -- Short wait to check if casting starts
            
            -- Check if the player started casting, indicating a successful attempt
            if IsPlayerCasting() then
                Sleep(cast_time_buffer) -- Wait for cast to complete
            end
        end
        
        -- Check if the teleport was successful
        if GetCharacterCondition(45) or GetCharacterCondition(51) then -- 45 is BetweenAreas, 51 is BetweenAreas51
            LogInfo("Teleport successful.")
            break
        end
        
        -- Teleport retry increment
        retries = retries + 1
        LogInfo("Retrying teleport attempt #" .. retries)
        
        -- Reset lifestream_stopped for next retry
        lifestream_stopped = false
    end
    
    -- Teleporter failed handling
    if retries >= max_retries then
        LogInfo("Teleport failed after " .. max_retries .. " attempts.")
        yield("/e Teleport failed after " .. max_retries .. " attempts.")
        yield("/lifestream stop") -- Not always needed but removes lifestream ui
    end
end

-- stores if the mount message in Mount() has been sent already or not
local mount_message = false
-- Usage: Mount("SDS Fenrir") 
--
-- Will use Company Chocobo if left empty
function Mount(mount_name)
    local max_retries = 10   -- Maximum number of retries
    local retry_interval = 1.0 -- Time interval between retries in seconds
    local retries = 0        -- Counter for the number of retries

    -- Check if the player has unlocked mounts by checking the quest completion
    if not (IsQuestComplete(66236) or IsQuestComplete(66237) or IsQuestComplete(66238)) then
        if not mount_message then
            yield('/e You do not have a mount unlocked, please consider completing the "My Little Chocobo" quest.')
            yield("/e Skipping mount.")
        else
            mount_message = true
        end
        return
    end
    
    -- Return if the player is already mounted
    if GetCharacterCondition(4) then
        return
    end
    
    -- Initial check to ensure the player can mount
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    
    -- Retry loop for mounting with a max retry limit (set above)
    while retries < max_retries do
        -- Attempt to mount using the chosen mount or Mount Roulette if none
        if mount_name == nil then
            yield('/mount "Company Chocobo"')
        else
            yield('/mount "' .. mount_name .. '"')
        end
        
        -- Wait for the retry interval
        Sleep(retry_interval)
        
        -- Exit loop if the player mounted
        if GetCharacterCondition(4) then
            yield("/e Successfully mounted after " .. retries .. " retries.")
            break
        end
        
        -- Increment the retry counter
        retries = retries + 1
    end
    
    -- Check if max retries were reached without success
    if retries >= max_retries then
        yield("/e Failed to mount after max retries (" .. max_retries .. ").")
    end
    
    -- Check player is available and mounted
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and GetCharacterCondition(4)
end

-- Usage: LogOut()
function LogOut()
    repeat
        yield("/logout")
        Sleep(0.1)
    until IsAddonVisible("SelectYesno")
    repeat
        yield("/pcall SelectYesno true 4")
        Sleep(0.1)
    until not IsAddonVisible("SelectYesno")
end

-- Usage: Movement(674.92, 19.37, 436.02) // Movement(674.92, 19.37, 436.02, 15)  
-- the first three are x y z coordinates and the last one is how far away it's allowed to stop from the target
-- deals with vnav movement, kind of has some stuck checks but it's probably not as reliable as it can be, you do not have to include range
function Movement(x_position, y_position, z_position, range)

    range = range or 2
    local max_retries = 100
    local stuck_check_interval = 0.1
    local stuck_threshold_seconds = 3
    local min_progress_distance = 1
    local min_distance_for_mounting = 20

    local function floor_position(pos)
        return math.floor(pos + 0.49999999999999994)
    end

    local x_position_floored = floor_position(x_position)
    local y_position_floored = floor_position(y_position)
    local z_position_floored = floor_position(z_position)

    local function IsWithinRange(xpos, ypos, zpos)
        return math.abs(xpos - x_position_floored) <= range and
               math.abs(ypos - y_position_floored) <= range and
               math.abs(zpos - z_position_floored) <= range
    end

    local function GetDistanceToTarget(xpos, ypos, zpos)
        return math.sqrt(
            (xpos - x_position_floored)^2 +
            (ypos - y_position_floored)^2 +
            (zpos - z_position_floored)^2
        )
    end

    local function NavToDestination()
        NavReload()
        repeat
            Sleep(0.1)
        until NavIsReady()

        local retries = 0
        repeat
            Sleep(0.1)
            local xpos = floor_position(GetPlayerRawXPos())
            local ypos = floor_position(GetPlayerRawYPos())
            local zpos = floor_position(GetPlayerRawZPos())
            local distance_to_target = GetDistanceToTarget(xpos, ypos, zpos)

            if distance_to_target > min_distance_for_mounting and TerritorySupportsMounting() then
                Mount()
            end
            
            yield("/vnav moveto " .. x_position .. " " .. y_position .. " " .. z_position)
            retries = retries + 1
        until PathIsRunning() or retries >= max_retries

        Sleep(0.1)
    end

    NavToDestination()

    local stuck_timer = 0
    local previous_distance_to_target = nil
    while true do
        local xpos = floor_position(GetPlayerRawXPos())
        local ypos = floor_position(GetPlayerRawYPos())
        local zpos = floor_position(GetPlayerRawZPos())

        Sleep(0.1)

        local current_distance_to_target = GetDistanceToTarget(xpos, ypos, zpos)

        if IsWithinRange(xpos, ypos, zpos) then
            yield("/vnav stop")
            break
        end

        if previous_distance_to_target then
            if current_distance_to_target >= previous_distance_to_target - min_progress_distance then
                stuck_timer = stuck_timer + stuck_check_interval
            else
                stuck_timer = 0
            end
        end
        previous_distance_to_target = current_distance_to_target

        if stuck_timer >= stuck_threshold_seconds then
            yield('/gaction "Jump"')
            Sleep(0.1)
            yield('/gaction "Jump"')
            NavReload()
            Sleep(0.5)
            NavToDestination()
            stuck_timer = 0
        end

        Sleep(0.1)
    end
end


-- Usage: OpenTimers()
--
-- Opens the timers window
function OpenTimers()
    repeat
        yield("/timers")
        Sleep(0.1)
    until IsAddonVisible("ContentsInfo")
    repeat
        yield("/pcall ContentsInfo True 12 1")
        Sleep(0.1)
    until IsAddonVisible("ContentsInfoDetail")
    repeat
        yield("/timers")
        Sleep(0.1)
    until not IsAddonVisible("ContentsInfo")
end

-- Usage: MarketBoardChecker()
--
-- just checks if the marketboard is open and keeps the script stopped until it's closed
function MarketBoardChecker()
    local ItemSearchWasVisible = false
    repeat
        Sleep(0.1)
        if IsAddonVisible("ItemSearch") then
            ItemSearchWasVisible = true
        end
    until ItemSearchWasVisible
    
    repeat
        Sleep(0.1)
    until not IsAddonVisible("ItemSearch")
end

-- Usage: BuyFromStore(1, 15) <--- buys 15 of X item
--
-- number_in_list is which item you're buying from the list, top item is 1, 2 is below that, 3 is below that etc...  
-- only works for the "Store" addon window, i'd be careful calling it anywhere else
function BuyFromStore(number_in_list, amount)
    -- compensates for the top being 0
    number_in_list = number_in_list - 1
    attempts = 0
    repeat
        attempts = attempts + 1
        Sleep(0.1)
    until (IsAddonReady("Shop") or attempts >= 100)
    -- attempts above 50 is about 5 seconds
    if attempts >= 100 then
        Echo("Waited too long, store window not found, moving on")
    end
    if IsAddonReady("Shop") and number_in_list and amount then
        yield("/pcall Shop True 0 "..number_in_list.." "..amount)
        repeat
            Sleep(0.1)
        until IsAddonReady("SelectYesno")
        yield("/pcall SelectYesno true 0")
        Sleep(0.5)
    end
end

-- Usage: CloseStore()  
-- Function used to close store windows
function CloseStore()
    if IsAddonVisible("Shop") then
        yield("/pcall Shop True -1")
    end
    
    repeat
        Sleep(0.1)
    until not IsAddonVisible("Shop")
    
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
end

-- Usage: Target("Storm Quartermaster")  
-- TODO: target checking for consistency and speed
function Target(target)
    repeat
        yield('/target "' .. target .. '"')
        Sleep(0.1)
    until GetTargetName() == target
end

-- Usage: OpenGcSupplyWindow(1)  
-- Supply tab is 0 // Provisioning tab is 1 // Expert Delivery is 2  
-- Anything above or below those numbers will not work 
--
-- All it does is open the gc supply window to whatever tab you want, or changes to a tab if it's already open
function OpenGcSupplyWindow(tab)
    -- swaps tabs if the gc supply list is already open
    if IsAddonVisible("GrandCompanySupplyList") then
        if (tab <= 0 or tab >= 3) then
            Echo("Invalid tab number")
        else
            yield("/pcall GrandCompanySupplyList true 0 " .. tab)
        end
    elseif not IsAddonVisible("GrandCompanySupplyList") then
        -- Mapping for GetPlayerGC()
        local gc_officer_names = {
            [1] = "Storm Personnel Officer",
            [2] = "Serpent Personnel Officer",
            [3] = "Flame Personnel Officer"
        }
        
        local gc_id = GetPlayerGC()
        local gc_target = gc_officer_names[gc_id]
        
        if gc_target then
            -- Target the correct GC officer
            Target(gc_target)
        else
            Echo("Unknown Grand Company ID: " .. tostring(gc_id))
        end
        
        Interact()
        
        repeat
            Sleep(0.1)
        until IsAddonReady("SelectString")
        yield("/pcall SelectString true 0")
        repeat
            Sleep(0.1)
        until IsAddonReady("GrandCompanySupplyList")
        yield("/pcall GrandCompanySupplyList true 0 " .. tab)
    end
end

-- Usage: CloseGcSupplyWindow()  
-- literally just closes the gc supply window  
-- probably is due some small consistency changes but it should be fine where it is now
function CloseGcSupplyWindow()
    attempt_counter = 0
    ::tryagain::
    if IsAddonVisible("GrandCompanySupplyList") then
        yield("/pcall GrandCompanySupplyList true -1")
        repeat
            Sleep(0.1)
        until IsAddonReady("SelectString")
        yield("/pcall SelectString true -1")
    end
    if IsAddonReady("SelectString") then
        yield("/pcall SelectString true -1")
    end
    repeat
        attempt_counter = attempt_counter + 1
        Sleep(0.1)
    until not IsAddonVisible("GrandCompanySupplyList") and not IsAddonVisible("SelectString") or attempt_counter >= 50
    if attempt_counter >= 50 then
        Echo("Window still open, trying again")
        goto tryagain
    end
end

-- Usage: GcProvisioningDeliver()
--
-- Attempts to deliver everything under the provisioning window, skipping over what it can't
function GcProvisioningDeliver()
    local function ContainsLetters(input)
        input = tostring(input)
        if input:match("%a") then
            return true
        else
            return false
        end
    end
    Sleep(0.5)
    for i = 4, 2, -1 do
        repeat
            Sleep(0.1)
        until IsAddonReady("GrandCompanySupplyList")
        local item_name = GetNodeText("GrandCompanySupplyList", 6, i, 10)
        local item_qty = tonumber(GetNodeText("GrandCompanySupplyList", 6, i, 6))
        local item_requested_amount = tonumber(GetNodeText("GrandCompanySupplyList", 6, i, 9))
        if ContainsLetters(item_name) and item_qty >= item_requested_amount then
            -- continue
        else
            yield("/echo Nothing here, moving on")
            goto skip
        end
        local row_to_call = i - 2
        yield("/pcall GrandCompanySupplyList true 1 "..row_to_call)
        local err_counter_request = 0
        local err_counter_supply = 0
        repeat
            err_counter_request = err_counter_request+1
            Sleep(0.1)
        until IsAddonReady("GrandCompanySupplyReward") or err_counter_request >= 50
        if err_counter_request >= 50 then
            Echo("Something might have gone wrong")
            err_counter_request = 0
        else 
            yield("/pcall GrandCompanySupplyReward true 0")
        end
        repeat
            err_counter_supply = err_counter_supply+1
            Sleep(0.1)
        until IsAddonReady("GrandCompanySupplyList") or err_counter_supply >= 50
        err_counter_supply = 0
        ::skip::
    end
end

-- This is just a list holding the ids for all worlds
WorldIDList={["Cerberus"]={ID=80},["Louisoix"]={ID=83},["Moogle"]={ID=71},["Omega"]={ID=39},["Phantom"]={ID=401},["Ragnarok"]={ID=97},["Sagittarius"]={ID=400},["Spriggan"]={ID=85},["Alpha"]={ID=402},["Lich"]={ID=36},["Odin"]={ID=66},["Phoenix"]={ID=56},["Raiden"]={ID=403},["Shiva"]={ID=67},["Twintania"]={ID=33},["Zodiark"]={ID=42},["Adamantoise"]={ID=73},["Cactuar"]={ID=79},["Faerie"]={ID=54},["Gilgamesh"]={ID=63},["Jenova"]={ID=40},["Midgardsormr"]={ID=65},["Sargatanas"]={ID=99},["Siren"]={ID=57},["Balmung"]={ID=91},["Brynhildr"]={ID=34},["Coeurl"]={ID=74},["Diabolos"]={ID=62},["Goblin"]={ID=81},["Malboro"]={ID=75},["Mateus"]={ID=37},["Zalera"]={ID=41},["Cuchulainn"]={ID=408},["Golem"]={ID=411},["Halicarnassus"]={ID=406},["Kraken"]={ID=409},["Maduin"]={ID=407},["Marilith"]={ID=404},["Rafflesia"]={ID=410},["Seraph"]={ID=405},["Behemoth"]={ID=78},["Excalibur"]={ID=93},["Exodus"]={ID=53},["Famfrit"]={ID=35},["Hyperion"]={ID=95},["Lamia"]={ID=55},["Leviathan"]={ID=64},["Ultros"]={ID=77},["Bismarck"]={ID=22},["Ravana"]={ID=21},["Sephirot"]={ID=86},["Sophia"]={ID=87},["Zurvan"]={ID=88},["Aegis"]={ID=90},["Atomos"]={ID=68},["Carbuncle"]={ID=45},["Garuda"]={ID=58},["Gungnir"]={ID=94},["Kujata"]={ID=49},["Tonberry"]={ID=72},["Typhon"]={ID=50},["Alexander"]={ID=43},["Bahamut"]={ID=69},["Durandal"]={ID=92},["Fenrir"]={ID=46},["Ifrit"]={ID=59},["Ridill"]={ID=98},["Tiamat"]={ID=76},["Ultima"]={ID=51},["Anima"]={ID=44},["Asura"]={ID=23},["Chocobo"]={ID=70},["Hades"]={ID=47},["Ixion"]={ID=48},["Masamune"]={ID=96},["Pandaemonium"]={ID=28},["Titan"]={ID=61},["Belias"]={ID=24},["Mandragora"]={ID=82},["Ramuh"]={ID=60},["Shinryu"]={ID=29},["Unicorn"]={ID=30},["Valefor"]={ID=52},["Yojimbo"]={ID=31},["Zeromus"]={ID=32}}

-- Usage: FindWorldByID(11) // FindWorldByID(GetHomeWorld())
-- 
-- Looks through the WorldIDList for the world name with X id and returns the name
function FindWorldByID(searchID)
    for name, data in pairs(WorldIDList) do
      if data.ID == searchID then
        return name, data
      end
    end
    return nil, nil
end

DatacentersWithWorlds={["Chaos"]={"Cerberus","Louisoix","Moogle","Omega","Phantom","Ragnarok","Sagittarius","Spriggan"},["Light"]={"Alpha","Lich","Odin","Phoenix","Raiden","Shiva","Twintania","Zodiark"},["Aether"]={"Adamantoise","Cactuar","Faerie","Gilgamesh","Jenova","Midgardsormr","Sargatanas","Siren"},["Crystal"]={"Balmung","Brynhildr","Coeurl","Diabolos","Goblin","Malboro","Mateus","Zalera"},["Dynamis"]={"Cuchulainn","Golem","Halicarnassus","Kraken","Maduin","Marilith","Rafflesia","Seraph"},["Primal"]={"Behemoth","Excalibur","Exodus","Famfrit","Hyperion","Lamia","Leviathan","Ultros"},["Materia"]={"Bismarck","Ravana","Sephirot","Sophia","Zurvan"},["Elemental"]={"Aegis","Atomos","Carbuncle","Garuda","Gungnir","Kujata","Tonberry","Typhon"},["Gaia"]={"Alexander","Bahamut","Durandal","Fenrir","Ifrit","Ridill","Tiamat","Ultima"},["Mana"]={"Anima","Asura","Chocobo","Hades","Ixion","Masamune","Pandaemonium","Titan"},["Meteor"]={"Belias","Mandragora","Ramuh","Shinryu","Unicorn","Valefor","Yojimbo","Zeromus"}}

-- Usage: FindDCWorldIsOn("Cerbeus") Will return Chaos
-- 
-- Looks through the DatacentersWithWorlds table and returns the datacenter a world is on
function FindDCWorldIsOn(worldName)
    for datacenter, worlds in pairs(DatacentersWithWorlds) do
        for _, world in ipairs(worlds) do
            if world == worldName then
                return datacenter
            end
        end
    end
    return nil
end
-- Usage: ContainsLetters("meow")  
-- 
-- Will return if whatever you provide it has letters or not
function ContainsLetters(input)
    if input:match("%a") then
        return true
    else
        return false
    end
end

-- Usage: Distance(-96.71, 18.60, 0.50, -88.33, 18.60, -10.48) or anything that gives you an x y z pos value
-- Used to calculate the distance between two sets of x y z coordinates
-- Euclidean Distance
function Distance(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx^2 + dy^2 + dz^2)
end

-- Usage: DistanceName("First Last", "First Last") or DistanceName("Aetheryte", "Retainer Bell")
-- Used to calculate the distance between two object names
-- Euclidean Distance
function DistanceName(distance_char_name1, distance_char_name2)
    local x1 = GetObjectRawXPos(distance_char_name1)
    local y1 = GetObjectRawYPos(distance_char_name1)
    local z1 = GetObjectRawZPos(distance_char_name1)
    
    local x2 = GetObjectRawXPos(distance_char_name2)
    local y2 = GetObjectRawYPos(distance_char_name2)
    local z2 = GetObjectRawZPos(distance_char_name2)
    
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx^2 + dy^2 + dz^2)
end

-- Usage: PathToObject("First Last") or PathToObject("Aetheryte")
-- Finds specified object and paths to it
function PathToObject(path_object_name)
    Movement(GetObjectRawXPos(path_object_name), GetObjectRawYPos(path_object_name), GetObjectRawZPos(path_object_name))
end

-- Finds where your estate entrance is and paths to it
-- I think this will break though since there will be multiple entrances around a housing area
-- So maybe needs nearest logic
function PathToEstateEntrance()
    Movement(GetObjectRawXPos("Entrance"), GetObjectRawYPos("Entrance"), GetObjectRawZPos("Entrance"))
end

-- Paths to Limsa bell
function PathToLimsaBell()
    if ZoneCheck(129, "Limsa", "tp") then
        -- stuff could go here
    else
        Movement(-123.72, 18.00, 20.55)
    end
end

-- Usage: WaitForGilIncrease(1)
-- Obtains current gil and waits for specified gil to be traded
-- Acts as the trigger before moving on
function WaitForGilIncrease(gil_increase_amount)
    -- Gil variable store before trade
    local previous_gil = GetGil()
    
    while true do
        Sleep(1.0) -- Wait for 1 second between checks
        
        local current_gil = GetGil()
        if current_gil > previous_gil and (current_gil - previous_gil) == gil_increase_amount then
            Echo(gil_increase_amount .. " Gil successfully traded")
            break -- Exit the loop when the gil increase is detected
        end
        
        previous_gil = current_gil -- Update gil amount for the next check
    end
end

-- Usage: PartyInvite("First Last")
-- Will target and invite player to a party, and retrying if the invite timeout happens
-- Can only be used if target is in range
function PartyInvite(party_invite_name)
    local invite_timeout = 305 -- 300 Seconds is the invite timeout, adding 5 seconds for good measure
    local start_time = os.time() -- Stores the invite time
    
    while not IsInParty() do
        repeat
            Sleep(0.1)
        until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
        
        Target(party_invite_name)
        yield("/invite")
        
        -- Wait for the target player to accept the invite or the timeout to expire
        while not IsInParty() do
            Sleep(0.1)
            
            -- Check if the invite has expired
            if os.time() - start_time >= invite_timeout then
                Echo("Invite expired. Reinviting " .. party_invite_name)
                start_time = os.time() -- Reset the start time for the new invite
                break -- Break the loop to resend the invite
            end
        end
    end
    -- stuff could go here
end

-- Usage: PartyInviteMenu("First", "First Last")
-- Will invite player to a party through the social menu, and retrying if the invite timeout happens
-- Can be used from anywhere
-- Semi broken at the moment
function PartyInviteMenu(party_invite_menu_first, party_invite_menu_full)
    local invite_timeout = 305 -- 300 Seconds is the invite timeout, adding 5 seconds for good measure
    local start_time = os.time() -- Stores the invite time
    
    while not IsInParty() do
        repeat
            Sleep(0.1)
        until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
        
        repeat
            yield('/search first "' .. party_invite_menu_first .. '" en jp de fr')
            Sleep(0.5)
        until IsAddonVisible("SocialList")
        
        -- Probably needs the node scanner here to match the name, otherwise it will invite whoever was previously searched, will probably mess up for multiple matches too
        
        repeat
            yield('/pcall SocialList true 1 0 "' .. party_invite_menu_full .. '"')
            Sleep(0.5)
        until IsAddonVisible("ContextMenu")
        
        repeat
            yield("/pcall ContextMenu true 0 3 0")
            Sleep(0.1)
        until not IsAddonVisible("ContextMenu")
        
        repeat
            yield("/pcall Social true -1")
            Sleep(0.1)
        until not IsAddonVisible("Social")
        
        -- Wait for the target player to accept the invite or the timeout to expire
        while not IsInParty() do
            Sleep(0.1)
            
            -- Check if the invite has expired
            if os.time() - start_time >= invite_timeout then
                Echo("Invite expired. Reinviting " .. party_invite_menu_full)
                start_time = os.time() -- Reset the start time for the new invite
                break -- Break the loop to resend the invite
            end
        end
    end
    -- stuff could go here
end

-- Usage: PartyDisband()
-- Will check if player is in party and disband party
function PartyDisband()
    if IsInParty() then
        repeat
            Sleep(0.1)
        until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
        
        yield("/partycmd disband")
        
        repeat
            yield("/pcall SelectYesno true 0")
            Sleep(0.1)
        until not IsAddonVisible("SelectYesno")
    end
end

-- Usage: PartyAccept()
-- Will accept party invite if not in party
-- NEEDS a name arg
function PartyAccept()
    if not IsInParty() then
        repeat
            Sleep(0.1)
        until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
        
        repeat
            yield("/pcall SelectYesno true 0")
            Sleep(0.1)
        until not IsAddonVisible("SelectYesno")
    end
end

function PartyLeave()
    if IsInParty() then
        repeat
            Sleep(0.1)
        until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
        yield("/partycmd leave")
        repeat
            Sleep(0.1)
        until IsAddonVisible("SelectYesno")
        repeat
            yield("/pcall SelectYesno true 0")
            Sleep(0.1)
        until not IsAddonVisible("SelectYesno")
    end
end
-- Usage: EstateTeleport("First Last", 0)
-- Options: 0 = Free Company, 1 = Personal, 2 = Apartment
-- Opens estate list of added friend and teleports to specified location
-- ZoneTransitions() not required
function EstateTeleport(estate_char_name, estate_type)
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    
    yield("/estatelist " .. estate_char_name)
    
    repeat
        yield("/pcall TeleportHousingFriend true " .. estate_type)
        Sleep(0.1)
    until not IsAddonVisible("TeleportHousingFriend")
    
    ZoneTransitions()
end

-- Usage: RelogCharacter("First Last@Server")
-- Relogs specified character, should be followed with a LoginCheck()
-- Requires @Server else it will not work
-- Requires Auto Retainer plugin
function RelogCharacter(relog_char_name)
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    
    yield("/ays relog " .. relog_char_name)
end

-- Usage: EquipRecommendedGear()
-- Equips recommended gear if any available
function EquipRecommendedGear()
    repeat
        Sleep(0.1)
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    
    repeat
        yield("/character")
        Sleep(0.1)
    until IsAddonVisible("Character")
    
    repeat
        yield("/pcall Character true 12")
        Sleep(0.1)
    until IsAddonVisible("RecommendEquip")
    
    repeat
        yield("/character")
        Sleep(0.1)
    until not IsAddonVisible("Character")
    
    repeat
        yield("/pcall RecommendEquip true 0")
        Sleep(0.1)
    until not IsAddonVisible("RecommendEquip")
end

-- Usage: WaitUntilObjectExists("First Last") or WaitUntilObjectExists("Aetheryte")
-- Checks if specified object exists near to your character
function WaitUntilObjectExists(object_name)
    repeat
        Sleep(0.1)
    until DoesObjectExist(object_name)
end

-- Usage: GetRandomNumber(1.5, 3.5) or GetRandomNumber(2, 4)
-- Allows for variance in values such as differing Sleep() wait times
function GetRandomNumber(min, max)
    -- Reseed the random number
    math.randomseed(os.time() + os.clock() * 100000)
    
    -- Generate and return a random number from the min and max values
    return min + (max - min) * math.random()
end

-- Usage: GetPlayerPos()
-- Finds and returns player x, y, z pos
function GetPlayerPos()
    -- Find and format player pos
    local x, y, z = GetPlayerRawXPos(), GetPlayerRawYPos(), GetPlayerRawZPos()
    local pos = string.format("%.2f, %.2f, %.2f", x, y, z)
    
    return pos
end

-- NEEDS excel browser adding
-- Usage: GetJob()
-- Returns the current player job abbreviation
function GetJob()
    -- Mapping for GetClassJobId()
    local job_names = {
        [0]  = "ADV", -- Adventurer
        [1]  = "GLA", -- Gladiator
        [2]  = "PGL", -- Pugilist
        [3]  = "MRD", -- Marauder
        [4]  = "LNC", -- Lancer
        [5]  = "ARC", -- Archer
        [6]  = "CNJ", -- Conjurer
        [7]  = "THM", -- Thaumaturge
        [8]  = "CRP", -- Carpenter
        [9]  = "BSM", -- Blacksmith
        [10] = "ARM", -- Armorer
        [11] = "GSM", -- Goldsmith
        [12] = "LTW", -- Leatherworker
        [13] = "WVR", -- Weaver
        [14] = "ALC", -- Alchemist
        [15] = "CUL", -- Culinarian
        [16] = "MIN", -- Miner
        [17] = "BTN", -- Botanist
        [18] = "FSH", -- Fisher
        [19] = "PLD", -- Paladin
        [20] = "MNK", -- Monk
        [21] = "WAR", -- Warrior
        [22] = "DRG", -- Dragoon
        [23] = "BRD", -- Bard
        [24] = "WHM", -- White Mage
        [25] = "BLM", -- Black Mage
        [26] = "ACN", -- Arcanist
        [27] = "SMN", -- Summoner
        [28] = "SCH", -- Scholar
        [29] = "ROG", -- Rogue
        [30] = "NIN", -- Ninja
        [31] = "MCH", -- Machinist
        [32] = "DRK", -- Dark Knight
        [33] = "AST", -- Astrologian
        [34] = "SAM", -- Samurai
        [35] = "RDM", -- Red Mage
        [36] = "BLU", -- Blue Mage
        [37] = "GNB", -- Gunbreaker
        [38] = "DNC", -- Dancer
        [39] = "RPR", -- Reaper
        [40] = "SGE", -- Sage
        [41] = "VPR", -- Viper
        [42] = "PCT"  -- Pictomancer
    }
    
    -- Find and return job ID
    local job_id = GetClassJobId()
    return job_names[job_id] or "Unknown job"
end

-- Usage: DoAction("Heavy Shot")
-- Uses specified action
function DoAction(action_name)
    yield('/ac "' .. action_name .. '"')
end

-- Usage: DoGeneralAction("Jump")
-- Uses specified general action
function DoGeneralAction(general_action_name)
    yield('/gaction "' .. general_action_name .. '"')
end

-- Usage: DoTargetLockon()
-- Locks on to current target
function DoTargetLockon(target_lockon_name)
    yield("/lockon")
end

-- NEEDS excel browser adding
-- Usage: IsQuestDone("Hallo Halatali")
-- Checks if you have completed the specified quest
function IsQuestDone(quest_done_name)
    -- Look up the quest by name
    local quest = QuestNameList[quest_done_name]

    -- Check if the quest exists
    if quest then
        return IsQuestComplete(quest.quest_key)
    end
end

-- NEEDS excel browser adding
-- Usage: DoQuest("Hallo Halatali")
-- Checks if you have completed the specified quest and starts if you have not
function DoQuest(quest_do_name)
    -- Look up the quest by name
    local quest = QuestNameList[quest_do_name]
    
    -- If the quest not found, echo and return false
    if not quest then
        Echo('Quest "' .. quest_do_name .. '" not found.')
        return false
    end
    
    -- Check if the quest is already completed
    if IsQuestComplete(quest.quest_key) then
        Echo('You have already completed the "' .. quest_do_name .. '" quest.')
        return true
    end
    
    -- Start the quest
    yield("/qst next " .. quest.quest_id)
    Sleep(0.5)
    yield("/qst start")
    
    -- Wait until the quest is complete, with condition checking since some NPCs talk too long
    repeat
        Sleep(0.1)
    until IsQuestComplete(quest.quest_key) and IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26) and not GetCharacterCondition(32)
    
    Sleep(0.5)
    
    return true
end

-- Usage: IsPlayerLowerThanLevel(100)
-- Checks if player level lower than specified amount, returns true if so
function IsPlayerLowerThanLevel(player_lower_level)
    if GetLevel() < player_lower_level then
        return true
    end
end

-- Usage: IsPlayerHigherThanLevel(1)
-- Checks if player level higher than specified amount, returns true if so
function IsPlayerHigherThanLevel(player_higher_level)
    if GetLevel() > player_higher_level then
        return true
    end
end

-- NEEDS some kind of translation so you can just do "Sastasha" than needing to do 1
-- Usage: QueueDuty(1, 1) for "Sastasha"
-- Options: 0-9 for duty tab, 1-999 for duty number
-- Automatically queues for specified duty, waits until player has exited duty
function QueueDuty(queue_tab_number, queue_duty_number)
    -- Open duty finder
    repeat
        yield("/dutyfinder")
        Sleep(0.1)
    until IsAddonVisible("ContentsFinder")
    
    -- Pick the duty tab
    repeat
        yield("/pcall ContentsFinder true 1 " .. queue_tab_number)
        Sleep(0.1)
    until IsAddonVisible("JournalDetail")
    
    -- Clear the duty selection
    repeat
        yield("/pcall ContentsFinder true 12 1")
        Sleep(0.1)
    until IsAddonVisible("ContentsFinder")
    
    -- Pick the duty
    repeat
        yield("/pcall ContentsFinder true 3 " .. queue_duty_number)
        Sleep(0.1)
    until IsAddonVisible("ContentsFinder")
    
    -- Take note of current ZoneID to know when duty is over later
    Sleep(0.1)
    local current_zone_id = GetZoneID()
    
    -- Queue the duty
    repeat
        yield("/pcall ContentsFinder true 12 0")
        Sleep(0.1)
    until IsAddonVisible("ContentsFinderConfirm")
    
    -- Accept the duty
    repeat
        yield("/pcall ContentsFinderConfirm true 8")
        Sleep(0.1)
    until not IsAddonVisible("ContentsFinderConfirm")
    
    -- Compare ZoneID to know when duty is over
    Sleep(5.0)
    if GetZoneID() ~= current_zone_id then
        repeat
            ZoneCheck(GetZoneID())
            Sleep(0.1)
        until current_zone_id == GetZoneID()
    end
end