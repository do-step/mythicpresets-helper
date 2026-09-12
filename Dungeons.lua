local ADDON, MPH = ...

local MAX_CODES = 4

MPH.CMID_CODE = {
    [560] = { code = "MC",   teleport = 1254559 },
    [559] = { code = "NPX",  teleport = 1254563 },
    [558] = { code = "MGT",  teleport = 1254572 },
    [557] = { code = "WS",   teleport = 1254400 },
    [402] = { code = "AA",   teleport = 393273 },
    [239] = { code = "SOTT", teleport = 1254551 },
    [161] = { code = "SR",   teleport = 159898 },
    [556] = { code = "POS",  teleport = 1254555 },

    [588] = { code = "AOF",  teleport = 1286812 },
    [584] = { code = "TBV",  teleport = 1286801 },
    [586] = { code = "DON",  teleport = 1286807 },
    [587] = { code = "MR",   teleport = 1286809 },
    [585] = { code = "VSA",  teleport = 1286804 },
    [399] = { code = "RLP",  teleport = 393256 },
    [250] = { code = "TOS",  teleport = 1286828 },
    [249] = { code = "KR",   teleport = 1286831 },
}

local dungeonCache = nil
local activityGroupCache = nil

function MPH.InvalidateDungeons()
    dungeonCache = nil
    activityGroupCache = nil
end

local function NormalizeName(name)
    if not name then return nil end
    name = name:lower()
    name = name:gsub("^[^:]+:%s*", "")
    name = name:gsub("[%s%-'’,%.]", "")
    return name
end

local function BuildActivityGroupMap()
    if activityGroupCache then return activityGroupCache end

    local categoryID = GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2
    local map = {}
    local byName = {}

    local filterSets = {}
    if Enum and Enum.LFGListFilter then
        table.insert(filterSets, bit.bor(Enum.LFGListFilter.CurrentSeason, Enum.LFGListFilter.PvE))
        table.insert(filterSets, bit.bor(Enum.LFGListFilter.CurrentExpansion,
            Enum.LFGListFilter.NotCurrentSeason, Enum.LFGListFilter.PvE))
    else
        table.insert(filterSets, 0)
    end

    for _, filters in ipairs(filterSets) do
        local ok, groups = pcall(C_LFGList.GetAvailableActivityGroups, categoryID, filters)
        if ok and groups then
            for _, groupID in ipairs(groups) do
                local okName, name = pcall(C_LFGList.GetActivityGroupInfo, groupID)
                local key = okName and NormalizeName(name)
                if key and not byName[key] then byName[key] = groupID end
            end
        end
    end

    local cmIDs = C_ChallengeMode.GetMapTable()
    if cmIDs then
        for _, cmID in ipairs(cmIDs) do
            local key = NormalizeName(C_ChallengeMode.GetMapUIInfo(cmID))
            if key and byName[key] then map[cmID] = byName[key] end
        end
    end

    activityGroupCache = map
    return map
end

function MPH.GetActivityGroupID(cmID)
    return BuildActivityGroupMap()[cmID]
end

function MPH.GetDungeonCode(cmID)
    local entry = MPH.CMID_CODE[cmID]
    return entry and entry.code or ("#" .. tostring(cmID))
end

function MPH.GetDungeonTeleport(cmID)
    local entry = MPH.CMID_CODE[cmID]
    return entry and entry.teleport or nil
end

function MPH.GetDungeonLabel(dungeons)
    local codes = {}
    for _, cmID in ipairs(dungeons) do
        table.insert(codes, MPH.GetDungeonCode(cmID))
    end
    if #codes == 0 then return "?" end
    if #codes <= MAX_CODES then return table.concat(codes, " ") end

    local shown = {}
    for i = 1, MAX_CODES do shown[i] = codes[i] end
    return table.concat(shown, " ") .. "..."
end

function MPH.GetDungeonInfo(cmID)
    local name, _, _, texture, _, mapID = C_ChallengeMode.GetMapUIInfo(cmID)
    return {
        cmID = cmID,
        name = name or ("#" .. tostring(cmID)),
        code = MPH.GetDungeonCode(cmID),
        texture = texture,
        mapID = mapID,
        teleport = MPH.GetDungeonTeleport(cmID),
        activityGroupID = MPH.GetActivityGroupID(cmID),
    }
end

function MPH.GetSeasonDungeons()
    if dungeonCache then return dungeonCache end

    local cmIDs = C_ChallengeMode.GetMapTable()
    if not cmIDs or #cmIDs == 0 then return {} end

    local dungeons = {}
    for order, cmID in ipairs(cmIDs) do
        local info = MPH.GetDungeonInfo(cmID)
        info.order = order
        table.insert(dungeons, info)
    end

    dungeonCache = dungeons
    return dungeons
end

local function MatchDungeon(dungeon, mapID, activityGroupID)
    if mapID and dungeon.mapID == mapID then return "mapID" end
    if activityGroupID and dungeon.activityGroupID == activityGroupID then return "activityGroupID" end
    return nil
end

function MPH.FindDungeonByActivity(mapID, activityGroupID)
    local seen = {}
    for _, dungeon in ipairs(MPH.GetSeasonDungeons()) do
        seen[dungeon.cmID] = true
        local matchedBy = MatchDungeon(dungeon, mapID, activityGroupID)
        if matchedBy then return dungeon, matchedBy end
    end
    for cmID in pairs(MPH.CMID_CODE) do
        if not seen[cmID] then
            local dungeon = MPH.GetDungeonInfo(cmID)
            local matchedBy = MatchDungeon(dungeon, mapID, activityGroupID)
            if matchedBy then return dungeon, matchedBy end
        end
    end
    return nil
end

table.insert(MPH.onLogin, function ()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    frame:SetScript("OnEvent", MPH.InvalidateDungeons)
    MPH.GetSeasonDungeons()
end)
