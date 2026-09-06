local ADDON, MPH = ...

local MAX_CODES = 4

MPH.CMID_CODE = {
    [560] = "MC",
    [559] = "NPX",
    [558] = "MGT",
    [557] = "WS",
    [402] = "AA",
    [239] = "SOTT",
    [161] = "SR",
    [556] = "POS",

    [588] = "AOF",
    [584] = "TBV",
    [586] = "DON",
    [587] = "MR",
    [585] = "VSA",
    [399] = "RLP",
    [250] = "TOS",
    [249] = "KR",
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
    return MPH.CMID_CODE[cmID] or ("#" .. tostring(cmID))
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
    local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(cmID)
    return {
        cmID = cmID,
        name = name or ("#" .. tostring(cmID)),
        code = MPH.GetDungeonCode(cmID),
        texture = texture,
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

table.insert(MPH.onLogin, function ()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    frame:SetScript("OnEvent", MPH.InvalidateDungeons)
    MPH.GetSeasonDungeons()
end)
