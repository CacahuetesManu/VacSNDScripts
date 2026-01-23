--This needs to go on the party_member that helps you do the dungeons
--Needs to be manually stopped when you're done

-- Plugins needed: Autoduty and its dependencies https://docs.google.com/spreadsheets/d/151RlpqRcCpiD_VbQn6Duf-u-S71EP7d0mx3j1PDNoNA/edit?pli=1#gid=0

--============================================================================
-- SND 12.0+ Wrapper Functions
--============================================================================

-- GetNodeText wrapper
local function GetNodeText(addonName, ...)
    local addon = Addons.GetAddon(addonName)
    if addon and addon.Ready then
        local node = addon:GetNode(...)
        return node and tostring(node.Text) or ""
    end
    return ""
end

-- IsNodeVisible wrapper
local function IsNodeVisible(addonName, ...)
    local addon = Addons.GetAddon(addonName)
    if addon and addon.Ready then
        local node = addon:GetNode(...)
        return node and node.IsVisible or false
    end
    return false
end

-- NOTE: GetNearbyObjectNames is NOT available in SND 12.0+
-- Instead, use /target "name" to target specific entities by name
-- The /target command will target the nearest matching entity

-- Distance helper (Vector3 does NOT exist in SND 12.0+)
-- Use Entity.Target.DistanceTo for target distance when possible
local function Distance(pos1, pos2)
    local dx = pos2.X - pos1.X
    local dy = pos2.Y - pos1.Y
    local dz = pos2.Z - pos1.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- GetToastNodeText wrapper (specific addon handling)
local function GetToastNodeText(x, y)
    local toastAddons = {"_WideText", "_TextError", "_ScreenText"}
    for _, addonName in ipairs(toastAddons) do
        local addon = Addons.GetAddon(addonName)
        if addon and addon.Ready then
            local node = addon:GetNode(x, y)
            if node and node.Text then
                return tostring(node.Text)
            end
        end
    end
    return ""
end

-- HasStatus wrapper
-- Player.Status is a C# List with .Count and [index] access (0-based)
-- StatusId = 0 means empty slot
local function HasStatus(statusName)
    if Player.Status and Player.Status.Count then
        for i = 0, Player.Status.Count - 1 do
            local status = Player.Status[i]
            if status and status.StatusId ~= 0 and status.Name == statusName then
                return true
            end
        end
    end
    return false
end

-- TargetHasStatus wrapper
-- Same C# List access pattern
local function TargetHasStatus(statusId)
    if Entity.Target and Entity.Target.Status and Entity.Target.Status.Count then
        for i = 0, Entity.Target.Status.Count - 1 do
            local status = Entity.Target.Status[i]
            if status and status.StatusId == statusId then
                return true
            end
        end
    end
    return false
end

--============================================================================
-- Original Script Functions (Updated for SND 12.0+)
--============================================================================

function Sleep(time)
    yield("/wait " .. tostring(time))
end

-- TargetNearestObject for SND 12.0+
-- Uses /target command which automatically targets the nearest matching entity
-- Note: objectKind and radius parameters are ignored in 12.0+ (no entity enumeration)
function TargetNearestObject(target_name, objectKind, radius)
    if not target_name then
        return nil
    end

    -- Check if entity exists first
    if Entity.GetEntityByName(target_name) == nil then
        return nil
    end

    -- Target the entity (will target nearest if multiple exist)
    yield("/target \"" .. target_name .. "\"")
    yield("/wait 0.1")

    -- Verify we targeted successfully
    if Entity.Target and Entity.Target.Name == target_name then
        return target_name
    end

    return nil
end

function GetDutyInfoText(pos)
    local function GetDutyInfoStartingNode()
        for i=8, 12 do
            if IsNodeVisible("_ToDoList", 1, (70013-i)) then
                return (39-2*i)
            end
        end
        return 13
    end
    local starting_node = GetDutyInfoStartingNode()
    if not pos then
        return
    end
    local text = GetNodeText("_ToDoList", (starting_node+pos-1), 3)
    return text
end

function LeaveDuty()
    while Svc.Condition[34] do
        local selectYesnoAddon = Addons.GetAddon("SelectYesno")
        local contentsFinderAddon = Addons.GetAddon("ContentsFinderMenu")
        if selectYesnoAddon and selectYesnoAddon.Ready then
            yield("/callback SelectYesno true 0")
        elseif contentsFinderAddon and contentsFinderAddon.Exists then
            yield("/callback ContentsFinderMenu true 0")
        else
            yield("/dutyfinder")
        end
        Sleep(0.1)
    end
end

function GetDutyTimer()
    if not Svc.Condition[34] and not Svc.Condition[56] then
        Dalamud.Log("[VAC] GetDutyTimer(): You're not in a duty.")
        return
    end
    local function GetDutyTimerTextNode()
        for i=8, 12 do
            if IsNodeVisible("_ToDoList", 1, (70013-i)) then
                return (23-i)
            end
        end
        return 10
    end
    local duty_timer_node = GetDutyTimerTextNode()
    local duty_timer_text = GetNodeText("_ToDoList", duty_timer_node, 8)
    local minutes, seconds = duty_timer_text:match("^(%d+):(%d+)$")
    if not minutes or not seconds then
        return nil
    end
    local duty_timer_seconds = tonumber(minutes) * 60 + tonumber(seconds)
    return duty_timer_seconds
end

repeat
    while not Player.Available do
        Sleep(1.0534)
    end

    if (Entity.GetEntityByName("Magitek Transporter") ~= nil) then
        TargetNearestObject("Magitek Transporter", 7, 10)
        local targetName = (Entity.Target and Entity.Target.Name or "")
        if targetName == "Magitek Transporter" and current_x == Entity.Player.Position.X and current_z == Entity.Player.Position.Z then
            yield("/ad pause")
            local targetX = (Entity.Target and Entity.Target.Position.X or 0)
            local targetY = (Entity.Target and Entity.Target.Position.Y or 0)
            local targetZ = (Entity.Target and Entity.Target.Position.Z or 0)
            yield("/vnav moveto " .. targetX .. " " .. targetY .. " " .. targetZ)
            repeat
                Sleep(0.1)
            until (Entity.Target and Entity.Target.DistanceTo or 999) < 2
            yield("/interact")
            Sleep(0.5)
            local selectYesnoAddon = Addons.GetAddon("SelectYesno")
            while selectYesnoAddon and selectYesnoAddon.Ready do
                yield("/callback SelectYesno true 0")
                Sleep(0.0956)
                selectYesnoAddon = Addons.GetAddon("SelectYesno")
            end
            yield("/ad resume")
        end
    end

    local duty_timer = GetDutyTimer()

    local Terminal_List = {
        [1] = { ["Name"] = "III", ["Coords"] = "124 -13.8 123.4" },
        [2] = { ["Name"] = "IV", ["Coords"] = "140.75 -12 113.2" },
        [3] = { ["Name"] = "IX", ["Coords"] = "-14.9 -21 -143.97" },
        [4] = { ["Name"] = "VIII", ["Coords"] = "-16.22 -17.3 -177.55" }
    }

    for i=1, #Terminal_List do
        if GetToastNodeText(2, 3) == "Magitek terminal "..Terminal_List[i]["Name"].." begins counting down." then
            local counter = 0
            repeat
                yield("/cleartarget")
                yield("/vnav moveto "..Terminal_List[i]["Coords"])
                Sleep(0.22)
                counter = counter+1
            until GetToastNodeText(2, 3) == "Magitek terminal "..Terminal_List[i]["Name"].."'s countdown completes." or counter > 200
        end
    end

    local targetName = (Entity.Target and Entity.Target.Name or "")
    if duty_timer and duty_timer < 4950 and GetDutyInfoText(2) == "Clear the feasting hall: 1/1" and GetToastNodeText(2, 3) == "Magitek terminal "..Terminal_List[3]["Name"].."'s countdown completes." then
        yield("/vnav moveto "..Terminal_List[4]["Coords"])
    elseif duty_timer and duty_timer < 5010 and GetDutyInfoText(2) == "Clear the feasting hall: 1/1" and not GetDutyInfoText(4) == "Defeat Batraal: 0/1" then
        yield("/vnav moveto "..Terminal_List[3]["Coords"])
    elseif GetDutyInfoText(2) == "Clear the feasting hall: 0/1" and targetName == "All-seeing Eye" then
        local Crystal_Coords = {
            [1] = { ["x"] = 74.6, ["y"] = -13.4, ["z"] = 83.0 },
            [2] = { ["x"] = 21.6, ["y"] = -14.2, ["z"] = 90.9 },
            [3] = { ["x"] = 48.8, ["y"] = -11.6, ["z"] = 116.0 },
            [4] = { ["x"] = 15.3, ["y"] = -9.5, ["z"] = 46.7 }
        }
        yield("/ad pause")
        local crystal = 1
        while (Entity.GetEntityByName("All-seeing Eye") ~= nil) do
            yield("/vnav moveto "..Crystal_Coords[crystal]["x"].." "..Crystal_Coords[crystal]["y"].." "..Crystal_Coords[crystal]["z"])
            if not HasStatus("Crystal Veil") and current_x and current_z and current_x^2 + current_z^2 < 1 then
                crystal=crystal+1
                if crystal == 5 then crystal = 1 end
            else
                while TargetHasStatus(325)==true and HasStatus("Crystal Veil") do
                    yield("/vnav moveto "..Crystal_Coords[crystal]["x"].." "..Crystal_Coords[crystal]["y"].." "..Crystal_Coords[crystal]["z"])
                    Sleep(1.34)
                end
            end
            Sleep(1.37)
        end
        yield("/ad resume")
    elseif GetDutyInfoText(1) == "Open the grand hall gate: 0/1" and (GetToastNodeText(2, 3) == "Magitek terminal "..Terminal_List[1]["Name"].."'s countdown completes." or (duty_timer and duty_timer < 5220)) then
        yield("/vnav moveto "..Terminal_List[2]["Coords"])
    elseif duty_timer and duty_timer < 5280 and GetDutyInfoText(1) == "Open the grand hall gate: 0/1" then
        yield("/vnav moveto "..Terminal_List[1]["Coords"])
    end

    if duty_timer and duty_timer < 4200 then
        yield("/ad stop")
        LeaveDuty()
    end

    current_x = Entity.Player.Position.X
    current_z = Entity.Player.Position.Z
    Sleep(2)
until forever
