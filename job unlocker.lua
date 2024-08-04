-- You should have used Questionable plugin (https://git.carvel.li/liza/Questionable/) or equivalent for MSQ completion up to certain points listed below, but at the very least up until you can select your GC
-- All options are better used when a mount is unlocked, mounts are not required as it has fallback but will slow the speed of completion
-- Job quests are completed so you can unlock other jobs which are required for min/btn/fsh unlocks, only the first 3 job quests are included here
-- DoL unlocks are for use with the dol leveller script, but mainly for ability to bulk level up retainers so they can be min/btn/fsh jobs
-- Maelstrom log rank 1 should be used after you have selected your GC and ideally have gotten your mount (not required but speeds everything up)
-- Maelstrom log rank 2 should be used after you have a combat 47 as Aurum Vale requires level 47
-- The quest unlocks will unlock the optional quests required for each stage of the Maelstrom progression, see the comments below for what they are for

--##########################################
--   CONFIGS
--##########################################

-- Only set one of these
-- Should really change to a DO_JOB_QUESTS = "Arcanist" or something
--DO_JOB_QUESTS = "Arcanist"
DO_ARCANIST_QUESTS = false
DO_ARCHER_QUESTS = true

DO_DOL_QUESTS = false

DO_MAELSTROM_LOG_1 = false
DO_MAELSTROM_LOG_2 = false

-- Quest unlocks
DO_HALATALI = false                  -- Maelstrom hunt log 1 hunt enemies       Hallo Halatali
DO_THE_SUNKEN_TEMPLE_OF_QARN = false -- Maelstrom hunt log 2 hunt enemies       Braving New Depths
DO_DZEMAEL_DARKHOLD = false          -- Chief Storm Sergeant requirement        Shadows Uncast (Maelstrom)
DO_THE_AURUM_VALE = false            -- Second Storm Lieutenant requirement     Going for Gold

--##########################################
--   DON'T TOUCH ANYTHING BELOW HERE 
--   UNLESS YOU KNOW WHAT YOU'RE DOING
--##########################################

-- Enemy names for Arcanist quests
local ArcanistEnemies = {
    "Wharf Rat",           -- arcanist_01 quest 1
    "Aurelia",             -- arcanist_02 quest 1
    "Little Ladybug",      -- arcanist_03 quest 1
    "Wild Dodo",           -- arcanist_04 quest 2
    "Tiny Mandragora",     -- arcanist_05 quest 2
    "Roseling",            -- arcanist_06 quest 3
    "Wild Jackal"          -- arcanist_07 quest 3
}

-- Enemy names for Archer quests
local ArcherEnemies = {
    "Ground Squirrel",     -- archer_01 quest 1
    "Little Ladybug",      -- archer_02 quest 1
    "Forest Funguar",      -- archer_03 quest 1
    "Opo-opo",             -- archer_04 quest 2
    "Microchu",            -- archer_05 quest 2
    "Tree Slug",           -- archer_06 quest 3
    "Northern Vulture"     -- archer_07 quest 3
}

-- Enemy names for Maelstrom hunting log 1 (02-04 are inside "Halatali")
local MaelstromEnemiesLog1 = {
    "Amalj'aa Hunter",     -- maelstrom_01 "MonsterNote", 2, 18, 3
    "Heckler Imp",         -- maelstrom_02 "MonsterNote", 2, 19, 3
    "Doctore",             -- maelstrom_03 "MonsterNote", 2, 20, 3
    "Firemane",            -- maelstrom_04 "MonsterNote", 2, 21, 3
    "Sylvan Groan",        -- maelstrom_05 "MonsterNote", 2, 22, 3
    "Sylvan Sough",        -- maelstrom_06 "MonsterNote", 2, 23, 3
    "Kobold Pickman",      -- maelstrom_07 "MonsterNote", 2, 24, 3
    "Amalj'aa Bruiser",    -- maelstrom_08 "MonsterNote", 2, 25, 3
    "Ixali Straightbreak", -- maelstrom_09 "MonsterNote", 2, 26, 3
    "Ixali Wildtalon"      -- maelstrom_10 "MonsterNote", 2, 27, 3
}

-- Enemy names for Maelstrom hunting log 2 (13-15 are inside "The Sunken Temple of Qarn")
local MaelstromEnemiesLog2 = {
    "Amalj'aa Divinator",  -- maelstrom_11 "MonsterNote", 2, 18, 3
    "Kobold Pitman",       -- maelstrom_12 "MonsterNote", 2, 19, 3
    "Temple Bat",          -- maelstrom_13 "MonsterNote", 2, 20, 3
    "The Condemned",       -- maelstrom_14 "MonsterNote", 2, 21, 3
    "Teratotaur",          -- maelstrom_15 "MonsterNote", 2, 22, 3
    "Kobold Bedesman",     -- maelstrom_16 "MonsterNote", 2, 23, 3
    "Kobold Priest",       -- maelstrom_17 "MonsterNote", 2, 24, 3
    "Sylvan Sigh",         -- maelstrom_18 "MonsterNote", 2, 25, 3
    "Shelfscale Sahagin",  -- maelstrom_19 "MonsterNote", 2, 26, 3
    "Amalj'aa Pugilist"    -- maelstrom_20 "MonsterNote", 2, 27, 3
}

local QuestIDs = {
    66233,                 -- Hallo Halatali "Halatali"
    66300,                 -- Braving New Depths "The Sunken Temple of Qarn"
    66664,                 -- Shadows Uncast (Maelstrom) "Dzemael Darkhold"
    66667                  -- Gilding the Bilious (Maelstrom) "The Aurum Vale"
}

-- usage: ZoneTransitions()
function ZoneTransitions() --Zone transition checker, does nothing if changing zones
    repeat 
         yield("/wait 0.1")
    until GetCharacterCondition(45) or GetCharacterCondition(51)
    repeat 
        yield("/wait 0.1")
    until not GetCharacterCondition(45) or not GetCharacterCondition(51)
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
end

-- usage: QuestNPC("SelectYesno"|"CutSceneSelectString", true, 0)
function QuestNPC(dialogue_type, dialogue_confirm, dialogue_option) -- NPC interaction handler. dialogue_option optional.
    while not GetCharacterCondition(32) do
        yield("/pint")
        yield("/wait 0.1")
    end
    if dialogue_confirm then
        repeat 
            yield("/wait 0.1")
        until IsAddonVisible(dialogue_type)
        if dialogue_option == nil then
            repeat
                yield("/pcall " .. dialogue_type .. " true 0")
                yield("/wait 0.1")
            until not IsAddonVisible(dialogue_type)
        else
            repeat
                yield("/pcall " .. dialogue_type .. " true " .. dialogue_option)
                yield("/wait 0.1")
            until not IsAddonVisible(dialogue_type)
        end
    end
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
end

-- usage: QuestNPCSingle("SelectYesno"|"CutSceneSelectString", true, 0)
function QuestNPCSingle(dialogue_type, dialogue_confirm, dialogue_option) -- NPC interaction handler, only supports one dialogue option for now. dialogue_option optional.
    while not GetCharacterCondition(32) do
        yield("/pint")
        yield("/wait 0.5")
    end
    if dialogue_confirm then
        yield("/wait 0.5")
        if dialogue_option == nil then
            yield("/pcall " .. dialogue_type .. " true 0")
            yield("/wait 0.5")
        else
            yield("/pcall " .. dialogue_type .. " true " .. dialogue_option)
            yield("/wait 0.5")
        end
    end
end

-- ALWAYS takes target = X
-- ALWAYS takes enemy_max_dist = X
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
            yield("/wait 0.1")
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
        yield("/wait 0.5")

        local dist_to_enemy = GetDistanceToTarget()

        if GetTargetHP() > 0 and dist_to_enemy <= enemy_max_dist then
            repeat
                yield("/rotation auto")
                yield("/vnavmesh movetarget")
                
                yield("/wait 0.2")
            until GetDistanceToTarget() <= 3
            yield('/ac "Auto-attack"')
            yield("/vnavmesh stop")
        end
    end
    repeat
      yield("/wait 0.1")
    until GetTargetHP() == 0
      yield("/wait 0.5")
end

-- usage: QuestInstance()
function QuestInstance() -- Targetting/Movement Logic for Solo Duties
    while true do
        -- Check if GetCharacterCondition(34) is false and exit if so
        if not GetCharacterCondition(34) then
            break
        end

        if not IsPlayerAvailable() then
            yield("/wait 1")
            yield("/pcall SelectYesno true 0")
        elseif GetCharacterCondition(1) then
            yield("/pint")
            yield("/wait 1")
            while IsPlayerCasting() do 
                yield("/wait 0.5")
            end
            repeat 
                yield("/wait 0.1")
                -- Check condition in the middle of the loop
                if not GetCharacterCondition(34) then
                    break
                end
            until not IsAddonVisible("SelectYesno")
        elseif not IsPlayerAvailable() and not GetCharacterCondition(26) then
            repeat
                yield("/wait 0.1")
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
                        yield("/wait 0.1")
                        -- Check condition in the middle of the loop
                        if not GetCharacterCondition(34) then
                            break
                        end
                    until GetCharacterCondition(26, false)
                    paused = false
                else
                    yield("/wait 1")
                    yield("/rotation auto")

                    local current_target = GetTargetName()

                    if not current_target or current_target == "" then
                        yield("/targetenemy") 
                        current_target = GetTargetName()
                        if current_target == "" then
                            yield("/wait 1") 
                        end
                    end

                    local enemy_max_dist = 100
                    local dist_to_enemy = GetDistanceToTarget()

                    if dist_to_enemy and dist_to_enemy > 0 and dist_to_enemy <= enemy_max_dist then
                        local enemy_x, enemy_y, enemy_z = GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos()
                        yield("/vnavmesh moveto " .. enemy_x .. " " .. enemy_y .. " " .. enemy_z)
                        yield("/wait 3")
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

-- usage: QuestChecker(ArcanistEnemies[3], 25, "_ToDoList", "Slay little ladybugs.")

function QuestChecker(target_name, target_distance, get_node_text_type, get_node_text_match) -- Quest and UI element handler
    local target = target_name
    local enemy_max_dist = target_distance
    local get_node_text_location, get_node_text_location_1, get_node_text_location_2 = NodeScanner(get_node_text_type, get_node_text_match)
    local function extractTask(text)
        local task = string.match(text, "^(.-)%s%d+/%d+$")
        return task or text
    end
    while true do
        --UiCheck(get_node_text_type)
        updated_node_text = GetNodeTextLookupUpdate(get_node_text_type, get_node_text_location, get_node_text_location_1, get_node_text_location_2)
        LogInfo("[JU] updated_node_text: "..updated_node_text)
        LogInfo("[JU] Extract: "..extractTask(updated_node_text))
        local last_char = string.sub(updated_node_text, -1)
        LogInfo("[JU] last char: "..updated_node_text)
        yield("/wait 2")
        if updated_node_text == get_node_text_match or not string.match(last_char, "%d") then
            --UiCheck(get_node_text_type, true)
            LogInfo("GUUUUUUUUUUUH")
            break
        end
        QuestCombat(target_name, enemy_max_dist)
    end
    -- checks if player in combat before ending rotation solver
    if not GetCharacterCondition(26) then
        yield("/rotation off")
    end
end
-- QuestChecker(ArcanistEnemies[7], 40, "_ToDoList", "Report to Thubyrgeim at the Arcanists' Guild.")

function NodeScanner(get_node_text_type, get_node_text_match)
    node_type_count = tonumber(GetNodeListCount(get_node_text_type))
    local function extractTask(text)
        local task = string.match(text, "^(.-)%s*%d*/%d*$")
        return task or text
    end
    for location = 0, node_type_count do
        for sub_node = 0, 60 do
            yield("/wait 0.0001")
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
                yield("/wait 0.0001")
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
    yield("/echo Can't find the node text")
    return
end

function UiCheck(get_node_text_type, close_ui)
    -- hunting log checks
    if get_node_text_type == "MonsterNote" then
        if close_ui() then
            repeat
                yield("/huntinglog")
                yield("/wait 0.5")
            until not IsAddonVisible("MonsterNote")
        else
            repeat
                yield("/huntinglog")
                yield("/wait 0.5")
            until IsAddonVisible("MonsterNote")
        end
    end
end

-- usage: Teleporter("Limsa", "tp")
-- add support for item tp
function Teleporter(location, tp_kind) -- Teleporter handler
    local lifestream_stopped = false
    local extra_cast_time_buffer = 0
    -- Initial check to ensure player can teleport
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    -- Try teleport, retry if fail indefinitely
    while true do
        -- Stop lifestream only once per teleport attempt
        if tp_kind == "li" and not lifestream_stopped then
            yield("/lifestream stop")
            lifestream_stopped = true
            yield("/wait 0.1")
        end
        -- Attempt teleport
        if not IsPlayerCasting() then
            yield("/" .. tp_kind .. " " .. location)
            yield("/wait 2")
            -- If casting was not interrupted, reset lifestream_stopped for next retry
            if not IsPlayerCasting() then
                lifestream_stopped = false
            end
        elseif IsPlayerCasting() then
            yield("/wait " .. 5 + extra_cast_time_buffer) -- Wait for cast to complete
        end

        -- Exit if successful conditions are met
        if GetCharacterCondition(45) or GetCharacterCondition(51) then
            break
        end
    end
end

-- usage: Mount("SDS Fenrir") can leave empty for mount roulette
mountmessage = false
function Mount(mount_name)
    local max_retries = 10   -- Maximum number of retries
    local retry_interval = 1 -- Time interval between retries in seconds
    local retries = 0       -- Counter for the number of retries
    
    -- Check if the player has unlocked mounts by checking the quest completion
    if not (IsQuestComplete(66236) or IsQuestComplete(66237) or IsQuestComplete(66238)) then
        if not mountmessage then
            yield('/e You do not have a mount unlocked, please consider completing the "My Little Chocobo" quest.')
            yield("/e Skipping mount.")
        else
            mountmessage = true
        end
        return
    end
    
    -- Return if the player is already mounted
    if GetCharacterCondition(4) then
        return
    end
    
    -- Initial check to ensure the player can mount
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    
    -- Retry loop for mounting with a max retry limit (set above)
    while retries < max_retries do
        -- Attempt to mount using the chosen mount or Mount Roulette if none
        if mount_name == nil then
            yield('/ac "Mount Roulette"')
        else
            yield('/mount "' .. mount_name .. '"')
        end
        
        -- Wait for the retry interval
        yield("/wait " .. retry_interval)
        
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
        yield("/wait 0.1")
    until IsPlayerAvailable() and GetCharacterCondition(4)
end

-- usage: LogOut()
function LogOut()
    repeat
        yield("/logout")
        yield("/wait 0.1")
    until IsAddonVisible("SelectYesno")
    repeat
        yield("/pcall SelectYesno true 0")
        yield("/wait 0.1")
    until not IsAddonVisible("SelectYesno")
end

-- usage: Movement(674.92, 19.37, 436.02)
function Movement(x_position, y_position, z_position)
    local function floor_position(pos)
        return math.floor(pos + 0.49999999999999994)
    end

    local x_position_floored = floor_position(x_position)
    local y_position_floored = floor_position(y_position)
    local z_position_floored = floor_position(z_position)

    local range = 3

    local function NavTo()
        NavReload()
        repeat
            yield("/wait 0.1")
        until NavIsReady()

        local retries = 0
        local max_retries = 100
        repeat
            yield("/wait 0.1")
            yield("/vnav moveto " .. x_position .. " " .. y_position .. " " .. z_position)
            retries = retries + 1
        until PathIsRunning() or retries >= max_retries
        yield("/wait 1.0")
    end

    NavTo()

    while true do
        local xpos = floor_position(GetPlayerRawXPos())
        local ypos = floor_position(GetPlayerRawYPos())
        local zpos = floor_position(GetPlayerRawZPos())

        yield("/wait 0.1")

        -- Check if within 3 numbers of each pos
        if math.abs(xpos - x_position_floored) <= range and
           math.abs(ypos - y_position_floored) <= range and
           math.abs(zpos - z_position_floored) <= range then
            break
        end

        yield("/wait 0.5")
        
        local xpos2 = floor_position(GetPlayerRawXPos())
        local ypos2 = floor_position(GetPlayerRawYPos())
        local zpos2 = floor_position(GetPlayerRawZPos())

        LogInfo("[JU] x_position_floored: " .. x_position_floored)
        LogInfo("[JU] xpos: " .. xpos)
        LogInfo("[JU] y_position_floored: " .. y_position_floored)
        LogInfo("[JU] ypos: " .. ypos)
        LogInfo("[JU] z_position_floored: " .. z_position_floored)
        LogInfo("[JU] zpos: " .. zpos)

        if xpos == xpos2 and ypos == ypos2 and zpos == zpos2 then
            if math.abs(xpos - x_position_floored) > range or
               math.abs(ypos - y_position_floored) > range or
               math.abs(zpos - z_position_floored) > range then
                NavTo()
                yield('/gaction "Jump"')
                yield("/wait 0.5")
                yield('/gaction "Jump"')
            end
        end
    end
end

-- usage: Interact()
function Interact()
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable() and not IsPlayerCasting() and not GetCharacterCondition(26)
    yield("/pint")
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
end

--##############
--   ARCANIST
--##############

-- limsa arcanists' first quest level 1 "Way of the Arcanist"
function Arcanist1()
    Teleporter("Limsa", "tp")
    ZoneTransitions()
    Teleporter("Arcanist", "li")
    ZoneTransitions()
    Movement(-327.86, 12.89, 9.79)
    yield("/target Thubyrgeim")
    -- yield("/pinteract")
    -- yield("/waitaddon SelectYesno <maxwait.15><wait.9.5>")
    -- yield("/pcall SelectYesno true 0")
    QuestNPC("SelectYesno", true, 0)
    Movement(-335.29, 11.99, 54.45)
    
    Teleporter("Tempest", "li")
    ZoneTransitions()
    Movement(14.71, 64.52, 87.16)
    QuestChecker(ArcanistEnemies[1], 25, "_ToDoList", 13, 3, x, x, x, "Slay wharf rats.")
    QuestChecker(ArcanistEnemies[3], 25, "_ToDoList", 15, 3, x, x, x, "Slay little ladybugs.")
    Movement(232.67, 40.64, 57.39)
    QuestChecker(ArcanistEnemies[2], 25, "_ToDoList", 13, 3, x, x, x, "Report to Thubyrgeim at the Arcanists' Guild.")
    --yield("/wait 1.6")
    Teleporter("Limsa", "tp")
    ZoneTransitions()
    Teleporter("Arcanist", "li")
    ZoneTransitions()
    Movement(-327.86, 12.89, 9.79)
    yield("/target Thubyrgeim")
    QuestNPC()
end

-- limsa arcanists' second quest level 5 "What's in the Box"
function Arcanist2()
    Movement(-327.86, 12.89, 9.79)
    yield("/target Thubyrgeim")
    QuestNPC()
    Movement(-335.29, 11.99, 54.45)
    Teleporter("Zephyr", "li")
    ZoneTransitions()
    Movement(219.94, 66.81, 287.77)
    ZoneTransitions()
    Movement(381.76, 71.93, -256.04)
    QuestChecker(ArcanistEnemies[4], 25, "_ToDoList", 13, 3, x, x, x, "Slay wild dodos.")
    Movement(418.06, 65.90, -160.37)
    QuestChecker(ArcanistEnemies[5], 25, "_ToDoList", 13, 3, x, x, x, "Report to Thubyrgeim at the Arcanists' Guild.")
    --yield("/wait 1.6")
    Teleporter("Limsa", "tp")
    ZoneTransitions()
    Teleporter("Arcanist", "li")
    ZoneTransitions()
    Movement(-327.86, 12.89, 9.79)
    yield("/target Thubyrgeim")
    QuestNPC()
    Movement(-335.29, 11.99, 54.45)
    Teleporter("Zephyr", "li")
    ZoneTransitions()
    Movement(-0.007, 24.5, 194.68)
    yield("/target Practice Crates")
    QuestNPC()
    yield("/rotation auto")
    repeat 
        yield("/wait 0.1")
    until GetCharacterCondition(26)
    repeat 
        yield("/wait 0.1")
    until not GetCharacterCondition(26)
    yield("/rotation off")
    Movement(-0.007, 24.5, 194.68)
    yield("/wait 1.6")
    -- probably should make this a function for future stuff...
    while true do
        if DoesObjectExist("Practice Crate") then
            yield("/target Practice Crate")
            break
        else
            yield("/wait 0.1")
        end
    end
    -- yield("/pint")
    -- yield("/waitaddon CutSceneSelectString <maxwait.30><wait.6>")
    -- yield("/pcall CutSceneSelectString True 0")
    QuestNPC("CutSceneSelectString", true, 0)
    repeat
        yield("/wait 0.1")
    until not GetCharacterCondition(35)
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
    Teleporter("Limsa", "tp")
    ZoneTransitions()
    Teleporter("Arcanist", "li")
    ZoneTransitions()
    Movement(-327.86, 12.89, 9.79)
    yield("/target Thubyrgeim")
    QuestNPC()
end

-- limsa arcanists' third quest level 10 "Tactical Planning"
function Arcanist3()
    Movement(-327.86, 12.89, 9.79)
    
    yield("/target Thubyrgeim")
    QuestNPC()
    Teleporter("Swiftperch", "tp")
    ZoneTransitions()
    Movement(674.92, 19.37, 436.02)
    QuestChecker(ArcanistEnemies[6], 25, "_ToDoList", 13, 3, x, x, x, "Slay roselings.")
    --yield("/wait 1.6")
    Teleporter("Moraby", "tp")
    ZoneTransitions()
    Movement(30.84, 46.18, 831.01)
    QuestChecker(ArcanistEnemies[7], 40, "_ToDoList", 13, 3, x, x, x, "Report to Thubyrgeim at the Arcanists' Guild.")
    --yield("/wait 1.6")
    Teleporter("Limsa", "tp")
    ZoneTransitions()
    Teleporter("Arcanist", "li")
    ZoneTransitions()
    Movement(-327.86, 12.89, 9.79)
    yield("/target Thubyrgeim")
    QuestNPC()
    Movement(-347.72, -2.37, 12.88)
    yield("/target K'lyhia")
    yield("/lockon")
    QuestNPC()
    Teleporter("Summerford", "tp")
    ZoneTransitions()
    Movement(-103.76, 46.15, -253.17)
    yield("/target K'lyhia")
    yield("/pinteract")
    yield("/waitaddon SelectYesno <maxwait.10><wait.0.5>")
    yield("/pcall SelectYesno true 0")
    ZoneTransitions()
    yield("/rotation auto")
    QuestInstance()
    ZoneTransitions()
    yield("/wait 1.6")
    yield("/rotation off")
    yield("/target K'lyhia")
    yield("/lockon")
    QuestNPC()
    Teleporter("Limsa", "tp")
    ZoneTransitions()
    Teleporter("Arcanist", "li")
    ZoneTransitions()
    Movement(-327.86, 12.89, 9.79)
    yield("/target Thubyrgeim")
    QuestNPC()
end

--##############
--   ARCHER
--##############

-- gridania arcanists' first quest level 1 "Way of the Archer"
function Archer1()
    -- forgot to do this one, probs will later.
end
   
-- gridania arcanists' second quest level 5 "A Matter of Perspective"
function Archer2()
    Teleporter("New Gridania", "tp")
    ZoneTransitions()
    Teleporter("Archers' Guild", "li")
    ZoneTransitions()
    Movement(207.80, 0.10, 35.06)
    yield("/target Luciane")
    QuestNPC()
    Movement(187.65, -1.25, 63.54)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    Movement(109.31, 0.12, 59.86)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    Movement(50.87, 0.93, 25.88)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    Movement(51.35, -1.52, 61.06)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    Movement(66.11, -4.96, 91.91)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    Movement(57.20, -8.56, 105.41)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    Movement(34.93, 1.92, 34.09)
    Teleporter("Archers' Guild", "li")
    ZoneTransitions()
    Movement(207.80, 0.10, 35.06)
    yield("/target Luciane")
    QuestNPC()
    Teleporter("Fallgourd","tp")
    ZoneTransitions()
    Movement(307.65, -19.79, 171.31)
    QuestChecker(ArcherEnemies[4], 60, "_ToDoList", "Slay opo-opos.")
    Movement(301.68, -9.38, 11.51)
    QuestChecker(ArcherEnemies[5], 60, "_ToDoList", "Slay microchus.")
    Teleporter("New Gridania", "tp")
    ZoneTransitions()
    Teleporter("Archers' Guild", "li")
    ZoneTransitions()
    Movement(207.80, 0.10, 35.06)
    yield("/target Luciane")
    QuestNPC()
end

-- gridania arcanists' third quest level 10 "Training with Leih"
function Archer3()
    yield("/wait 1")
    yield("/target Luciane")
    QuestNPC()
    Movement(208.91, 0.00, 29.65)
    yield("/target Leih Aliapoh")
    QuestNPC()
    Teleporter("Bentbranch", "tp")
    ZoneTransitions()
    --First zone
    Movement(-88.03, -4.58, -73.39)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    yield("/wait 0.2")
    Movement(-112.35, -3.95, -64.35)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    yield("/wait 0.2")
    Movement(-135.89, -1.61, -71.04)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    yield("/wait 0.2")
    --Second zone
    Movement(-146.34, 3.64, -129.18)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    yield("/wait 0.2")
    Movement(-111.04, 7.75, -164.70)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    yield("/wait 0.2")
    -- Third zone
    Movement(-80.48, 0.53, -176.20)
    yield("/target Archery Butt")
    yield('/ac "Heavy Shot"')
    yield("/wait 0.2")
    -- Report to Leih Aliapoh
    Teleporter("New Gridania", "tp")
    ZoneTransitions()
    Teleporter("Archers' Guild", "li")
    ZoneTransitions()
    Movement(208.91, 0.00, 29.65)
    yield("/target Leih Aliapoh")
    QuestNPC()
    -- Kill some enemies
    Movement(147.35, -0.24, 84.22)
    Movement(115.20, -0.14, 74.28)
    Movement(94.11, 3.91, 24.27)
    Movement(99.57, 4.77, 17.09)
    yield("/vnav moveto 101.94 5.31 13.12")
    yield("/wait 2")
    ZoneTransitions()
    Movement(179.43, -2.16, -242.84)
    yield("/target Romarique")
    yield("/wait 0.5")
    yield("/pint")
    repeat 
        yield("/wait 0.1")
    until IsAddonReady("SelectIconString")
    yield("/pcall SelectIconString true 0")
    yield("/wait 1")
    repeat 
        yield("/wait 0.1")
    until IsAddonReady("SelectYesno")
    yield("/pcall SelectYesno true 0")
    ZoneTransitions()
    Movement(-496.79, 8.99, 89.93)
    QuestChecker(ArcherEnemies[7], 50, "_ToDoList", "Slay northern vultures.")
    Movement(-448.56, -0.31, 226.01)
    QuestChecker(ArcherEnemies[6], 50, "_ToDoList", "Slay tree slugs.")
    --Report to Leih
    Teleporter("New Gridania", "tp")
    ZoneTransitions()
    Teleporter("Archers' Guild", "li")
    ZoneTransitions()
    Movement(208.91, 0.00, 29.65)
    yield("/target Leih Aliapoh")
    QuestNPC()
    -- report to Luciane
    Movement(207.80, 0.10, 35.06)
    yield("/target Luciane")
    yield("/pint")
    repeat 
        yield("/wait 0.1")
    until IsAddonReady("SelectYesno")
    yield("/pcall SelectYesno true 0")
    repeat 
        yield("/wait 0.1")
    until IsPlayerAvailable()
end

--##############
-- JOB UNLOCKS
--##############

function FisherUnlock()
    Teleporter("Limsa", "tp")
    ZoneTransitions()
    Teleporter("Fisher", "li")
    ZoneTransitions()
    Movement(-167.30, 4.55, 152.46)
    
    yield("/target N'nmulika")
    yield("/pint")
    yield("/waitaddon SelectYesno <maxwait.15><wait.0.5>")
    yield("/pcall SelectYesno true 0")
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
    yield("/wait 1.6")
    yield("/target N'nmulika")
    QuestNPC()
    Movement(-173.59, 4.2, 162.77)
    
    Movement(-165.74, 4.55, 165.38)
    
    yield("/target Sisipu")
    yield("/pint")
    yield("/waitaddon SelectYesno <maxwait.15><wait.0.5>")
    yield("/pcall SelectYesno true 0")
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
end

function MinerUnlock()
    Teleporter("Ul'dah", "tp")
    ZoneTransitions()
    Teleporter("Miner", "li")
    ZoneTransitions()
    Movement(1.54, 7.6, 153.55)
    
    yield("/target Linette")
    yield("/pint")
    yield("/waitaddon SelectYesno <maxwait.15><wait.0.5>")
    yield("/pcall SelectYesno true 0")
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
    yield("/wait 1.6")
    yield("/target Linette")
    QuestNPC()
    Movement(-17.33, 6.2, 157.59)
    
    yield("/target Adalberta")
    yield("/pint")
    yield("/waitaddon SelectYesno <maxwait.15><wait.0.5>")
    yield("/pcall SelectYesno true 0")
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
end

function BotanistUnlock()
    Teleporter("Gridania", "tp")
    ZoneTransitions()
    Teleporter("Botanist", "li")
    ZoneTransitions()
    Movement(-238.64, 8, -144.90)
    
    yield("/target Leonceault")
    yield("/pint")
    yield("/waitaddon SelectYesno <maxwait.15><wait.0.5>")
    yield("/pcall SelectYesno true 0")
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
    yield("/wait 1.6")
    yield("/target Leonceault")
    QuestNPC()
    Movement(-234.09, 6.23, -170.02)
    
    yield("/target Fufucha")
    yield("/pint")
    yield("/waitaddon SelectYesno <maxwait.15><wait.0.5>")
    yield("/pcall SelectYesno true 0")
    repeat
        yield("/wait 0.1")
    until IsPlayerAvailable()
end

--##############
-- HUNT UNLOCKS
--##############

function MaelstromRank1() --needs nodescanner adding and the matching text adjusting
    -- Amalj'aa Hunter
    Teleporter("Camp Drybone", "tp")
    ZoneTransitions()
    Movement(-112.60, -27.88, 343.99)
    
    -- QuestChecker(MaelstromEnemiesLog1[1], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    Movement(-122.43, -30.10, 297.20)
    
    -- QuestChecker(MaelstromEnemiesLog1[1], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    Movement(-122.43, -30.10, 297.20)
    
    -- QuestChecker(MaelstromEnemiesLog1[1], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- Amalj'aa Bruiser
    Movement(-169.97, -46.71, 493.46)
    
    ZoneTransitions()
    Movement(-157.06, 26.13, -410.14)
    
    yield("/target Aetheryte")
    Interact()
    Movement(-32.69, 15.53, -277.9)
    
    -- QuestChecker(MaelstromEnemiesLog1[8], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    Movement(-9.38, 15.62, -291.08)
    
    -- QuestChecker(MaelstromEnemiesLog1[8], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- QuestChecker(MaelstromEnemiesLog1[8], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- Sylvan Groan + Sylvan Sough
    Teleporter("Bentbranch Meadows", "tp")
    ZoneTransitions()
    Movement(389.27, -3.36, -186.45)
    
    ZoneTransitions()
    Movement(-189.88, 4.43, 294.46)
    
    yield("/target Aetheryte")
    Interact()
    Movement(-135.26, 15.12, -1.46)
    
    -- QuestChecker(MaelstromEnemiesLog1[5], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- QuestChecker(MaelstromEnemiesLog1[6], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    Movement(-104.98, 18.52, 14.46)
    
    -- QuestChecker(MaelstromEnemiesLog1[5], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- QuestChecker(MaelstromEnemiesLog1[6], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    Movement(-71.64, 17.58, 7.27)
    
    -- QuestChecker(MaelstromEnemiesLog1[5], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- QuestChecker(MaelstromEnemiesLog1[6], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- Kobold Pickman
    Teleporter("Aleport", "tp")
    ZoneTransitions()
    Movement(417.30, 35.15, -17.66)
    
    ZoneTransitions()
    Movement(-477.30, 26.29, 61.12)
    
    -- QuestChecker(MaelstromEnemiesLog1[7], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- QuestChecker(MaelstromEnemiesLog1[7], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    Movement(-432.12, 38.29, 19.78)
    
    -- QuestChecker(MaelstromEnemiesLog1[7], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- Ixali Straightbeak
    Teleporter("New Gridania", "tp")
    ZoneTransitions()
    yield("/target Aetheryte")
    Interact()
    QuestNPCSingle("SelectString", true, "0")
    yield("/pcall TelepotTown true 11 4u <wait.1>")
    yield("/pcall TelepotTown true 11 4u")
    ZoneTransitions()
    Movement(-231, 15.75, -89.25)
    
    ZoneTransitions()
    Movement(53.52, -37.91, 312.72)
    
    -- QuestChecker(MaelstromEnemiesLog1[9], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    Movement(75.32, -38.07, 331.25)
    
    -- QuestChecker(MaelstromEnemiesLog1[9], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    Movement(75.83, -41.24, 352.80)
    
    -- QuestChecker(MaelstromEnemiesLog1[9], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    -- Ixali Wildtalon
    Movement(-36.96, -39.16, 232.40)
    
    yield("/target Aetheryte")
    Interact()
    Movement(-405, 9.5, 128)
    
    ZoneTransitions()
    Movement(468.13, 232.79, 321.85)
    -- QuestChecker(MaelstromEnemiesLog1[10], 40, "MonsterNote", "Report to Thubyrgeim at the Arcanists' Guild.")
    
    Movement(224.32, 301.51, -142.16)
    
    Movement(229.20, 312.91, -235.02)
    
    yield("/target Aetheryte")
    Interact()
    Teleport("Limsa", "tp")
end

function MaelstromRank2()
    
end

--#################
-- DUNGEON UNLOCKS
--#################

-- can also probably use questionable once commands or ipc work better
-- needs updating once nodescanner works
function HalataliUnlock()
    Teleporter("Horizon", "tp") -- could also use vesper bay ticket but needs the teleporter function adjusting
    ZoneTransitions()
    Movement(-471.37, 23.01, -355.12)
    
    yield("/target Nedrick Ironheart")
    QuestNPC()
    -- once accepted quest
    Teleporter("Camp Drybone", "tp")
    ZoneTransitions()
    Movement(-330.92, -22.48, 434.14)
    
    yield("/target Fafajoni")
    QuestNPC()
end

function TheSunkenTempleOfQarnUnlock()
    
end

function DzemaelDarkholdUnlock()
    
end

function TheAurumValeUnlock()
    
end

--##########################################
--  MAIN SCRIPT
--##########################################
function main()
    yield("/at e")
    yield("/p")
    yield("/vbm cfg AI Enabled true")
    yield("/vbmai on")
    if DO_ARCANIST_QUESTS then
        Arcanist1()
        Arcanist2()
        Arcanist3()
    elseif DO_ARCHER_QUESTS then
        Archer1()
        Archer2()
        Archer3()
    end
    
-- DoL
    if DO_DOL_QUESTS then
        FisherUnlock()
        MinerUnlock()
        BotanistUnlock()
    end
    
-- Hunt Logs
    if DO_MAELSTROM_LOG_1 then
        MaelstromRank1()
    end
    
    if DO_MAELSTROM_LOG_2 then
        MaelstromRank2()
    end
    
-- Quests
    if DO_HALATALI then
        HalataliUnlock()
    end
    
    if DO_THE_SUNKEN_TEMPLE_OF_QARN then
        TheSunkenTempleOfQarnUnlock()
    end
    
    if DO_DZEMAEL_DARKHOLD then
        DzemaelDarkholdUnlock()
    end
    
    if DO_THE_AURUM_VALE then
        TheAurumValeUnlock()
    end
    
-- GC tp
    --Teleporter("gc", "li")
end

main()
