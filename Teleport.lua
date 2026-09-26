local ADDON, MPH = ...

MPH.Teleport = {}

local DIFFICULTY_KEYSTONE = 8
local DIFFICULTY_MYTHIC = 23
local PENDING_TTL = 30 * 60
local JOIN_TTL = 2 * 60
local PARTY_SIZE = 5

local FEATURE_EVENTS = {
    "LFG_LIST_JOINED_GROUP",
    "LFG_LIST_APPLICATION_STATUS_UPDATED",
    "LFG_LIST_ACTIVE_ENTRY_UPDATE",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
}

local KEEP_DISMISSED = {
    closed = true,
    teleported = true,
}

local SEARCH_SOURCES = {
    listing = true,
    joined = true,
    joining = true,
    remembered = true,
}

local JOIN_PENDING = {
    invited = true,
    inviteaccepted = true,
}

local JOIN_LOST = {
    invitedeclined = true,
    declined = true,
    declined_full = true,
    declined_delisted = true,
    cancelled = true,
    timedout = true,
    none = true,
}

local IsSecret = issecretvalue or function () return false end

local events = CreateFrame("Frame")
local current
local currentSource
local dismissedCmID
local dismissedBy
local joining
local groupSize = 0

local function Config()
    return MPH.db.teleport
end

function MPH.Teleport.IsEnabled()
    return MPH.db ~= nil and Config().enabled == true
end

local function IsInDungeon()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "party"
end

local function HasListing()
    return C_LFGList.HasActiveEntryInfo ~= nil and C_LFGList.HasActiveEntryInfo() == true
end

local function PartySize()
    if IsInRaid() then return 0 end
    return GetNumGroupMembers()
end

local function FirstActivityID(info)
    if type(info) ~= "table" then return nil, "no entry info" end

    local ids = info.activityIDs
    if IsSecret(ids) then return nil, "activityIDs <secret>" end

    local activityID = ids and ids[1] or info.activityID
    if activityID == nil or IsSecret(activityID) then
        return nil, "activityID " .. MPH.DescribeValue(activityID)
    end
    return activityID
end

local function ResolveDungeon(activityID)
    local activity = C_LFGList.GetActivityInfoTable(activityID)
    if type(activity) ~= "table" then return nil, "no activity info" end

    local difficultyID = activity.difficultyID
    local isKeystone = activity.isMythicPlusActivity
    local mapID = activity.mapID
    local activityGroupID = activity.groupFinderActivityGroupID
    MPH.Debug("teleport: activity %s, difficulty %s, keystone %s, mapID %s, group %s",
        tostring(activityID), MPH.DescribeValue(difficultyID), MPH.DescribeValue(isKeystone),
        MPH.DescribeValue(mapID), MPH.DescribeValue(activityGroupID))

    if IsSecret(difficultyID) or IsSecret(isKeystone) or IsSecret(mapID) or IsSecret(activityGroupID) then
        return nil, "secret activity fields"
    end
    if not isKeystone and difficultyID ~= DIFFICULTY_KEYSTONE and difficultyID ~= DIFFICULTY_MYTHIC then
        return nil, "not mythic"
    end

    local dungeon, matchedBy = MPH.FindDungeonByActivity(mapID, activityGroupID)
    if not dungeon then return nil, "dungeon not in table" end
    if not dungeon.teleport then return nil, "no teleport for " .. dungeon.code end

    MPH.Debug("teleport: %s matched by %s, spell %d", dungeon.code, matchedBy, dungeon.teleport)
    return dungeon
end

local function ReadDungeon(readInfo)
    local ok, dungeon, reason = pcall(function ()
        local activityID, readReason = FirstActivityID(readInfo())
        if not activityID then return nil, readReason end
        return ResolveDungeon(activityID)
    end)
    if not ok then return nil, "error " .. tostring(dungeon) end
    return dungeon, reason
end

local function ListingDungeon()
    if not HasListing() then return nil, "no listing" end
    return ReadDungeon(C_LFGList.GetActiveEntryInfo)
end

local function IsJoining()
    return joining ~= nil and time() - joining.at <= JOIN_TTL
end

local function Latch(source, resultID)
    if resultID == nil or IsSecret(resultID) then
        MPH.Debug("teleport: %s latch skipped, result %s", source, MPH.DescribeValue(resultID))
        return
    end

    local dungeon, reason = ReadDungeon(function ()
        return C_LFGList.GetSearchResultInfo(resultID)
    end)
    local cmID = dungeon and dungeon.cmID
    if not cmID and joining and joining.resultID == resultID and joining.cmID then
        cmID = joining.cmID
        reason = tostring(reason) .. ", kept " .. MPH.GetDungeonCode(cmID)
    end

    joining = { resultID = resultID, cmID = cmID, at = time() }
    MPH.Debug("teleport: %s latch %s, %s", source, tostring(resultID),
        dungeon and dungeon.code or tostring(reason))
end

local function DropLatch(reason, resultID)
    if not joining then return false end
    if resultID and joining.resultID ~= resultID then return false end
    MPH.Debug("teleport: latch dropped, %s", reason)
    joining = nil
    return true
end

local function JoiningDungeon()
    if not joining then return nil, "nothing joined" end
    if not IsJoining() then return nil, "join expired" end
    if not joining.cmID then return nil, "join without dungeon" end

    local dungeon = MPH.GetDungeonInfo(joining.cmID)
    if not dungeon.teleport then return nil, "no teleport for " .. dungeon.code end
    return dungeon
end

local function RememberedDungeon(checkTTL)
    local pending = Config().pending
    if not pending then return nil, "nothing remembered" end
    if not IsInGroup() and not HasListing() then return nil, "not in group" end
    if checkTTL and (not pending.at or time() - pending.at > PENDING_TTL) then
        return nil, "remembered expired"
    end

    local dungeon = MPH.GetDungeonInfo(pending.cmID)
    if not dungeon.teleport then return nil, "no teleport for " .. dungeon.code end
    return dungeon
end

local function KeystoneLevel()
    if not C_MythicPlus.GetOwnedKeystoneLevel then return nil end

    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if level == nil or IsSecret(level) or level <= 0 then return nil end
    return level
end

local function KeystoneDungeon()
    if not C_MythicPlus.GetOwnedKeystoneChallengeMapID then return nil, "no keystone API" end

    local cmID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if cmID == nil or IsSecret(cmID) or cmID == 0 then return nil, "no keystone" end

    local dungeon = MPH.GetDungeonInfo(cmID)
    if not dungeon.teleport then return nil, "no teleport for " .. dungeon.code end
    dungeon.level = KeystoneLevel()
    return dungeon
end

local function TeleportCmID(spellID)
    for cmID, entry in pairs(MPH.CMID_CODE) do
        if entry.teleport == spellID then return cmID end
    end
    return nil
end

local function Remember(dungeon)
    Config().pending = { cmID = dungeon.cmID, at = time() }
end

local SEARCH_CHAIN = {
    { name = "listing", read = ListingDungeon },
    { name = "joining", read = JoiningDungeon },
    { name = "remembered", read = RememberedDungeon },
}

local function SearchDungeon()
    if current and SEARCH_SOURCES[currentSource] then return current, currentSource end
    for _, source in ipairs(SEARCH_CHAIN) do
        local dungeon, reason = source.read()
        if dungeon then return dungeon, source.name end
        MPH.Debug("teleport: %s unavailable, %s", source.name, tostring(reason))
    end
    return nil
end

local function FindGroupDungeon()
    local dungeon, source = SearchDungeon()
    if dungeon then return dungeon, source end

    local key, reason = KeystoneDungeon()
    if key then return key, "keystone" end
    MPH.Debug("teleport: keystone unavailable, %s", tostring(reason))
    return nil
end

local function Offer(dungeon, source, reveal)
    current = dungeon
    currentSource = source
    if SEARCH_SOURCES[source] then Remember(dungeon) end
    MPH.TeleportPage.Refresh()
    if MPH.Teleport.IsEnabled() and MPH.OpenWindowOn then
        if reveal and MPH.ShowGroupFinder then MPH.ShowGroupFinder() end
        MPH.OpenWindowOn("teleport", true)
    end
end

local function Clear(reason)
    if current or Config().pending then
        MPH.Debug("teleport: cleared, %s", reason)
    end
    if not KEEP_DISMISSED[reason] then
        dismissedCmID = nil
        dismissedBy = nil
        joining = nil
        Config().pending = nil
    end
    current = nil
    currentSource = nil
    MPH.TeleportPage.Refresh()
    if MPH.ReleaseWindow then MPH.ReleaseWindow() end
end

local function Dismiss(reason, cmID)
    cmID = cmID or (current and current.cmID)
    if cmID then
        dismissedCmID = cmID
        dismissedBy = reason
    end
    Clear(reason)
end

local function OfferDungeon(source, dungeon, reveal)
    if IsInDungeon() then
        MPH.Debug("teleport: %s skipped, already in dungeon", source)
        return
    end

    Remember(dungeon)
    if dungeon.cmID == dismissedCmID then
        MPH.Debug("teleport: %s skipped, %s was %s", source, dungeon.code, tostring(dismissedBy))
        MPH.TeleportPage.Refresh()
        return
    end
    if current and current.cmID == dungeon.cmID then
        currentSource = source
        return
    end

    Offer(dungeon, source, reveal)
end

local function OfferFrom(source, readInfo)
    local dungeon, reason = ReadDungeon(readInfo)
    if not dungeon then
        MPH.Debug("teleport: %s skipped, %s", source, tostring(reason))
        return
    end
    OfferDungeon(source, dungeon)
end

local function OnActiveEntryUpdate()
    if HasListing() then
        OfferFrom("listing", C_LFGList.GetActiveEntryInfo)
    elseif IsJoining() then
        local kept = current and current.code
            or joining.cmID and MPH.GetDungeonCode(joining.cmID)
            or "-"
        MPH.Debug("teleport: listing removed while joining, kept %s", kept)
    elseif not IsInGroup() then
        Clear("listing removed")
    end
end

local function OnRosterUpdate()
    local size = PartySize()
    local filled = size >= PARTY_SIZE and groupSize < PARTY_SIZE
    groupSize = size

    if not IsInGroup() and not HasListing() then
        if IsJoining() then
            MPH.Debug("teleport: roster empty while joining, kept")
            return
        end
        return Clear("left group")
    end
    if not filled or IsInDungeon() then return end

    local dungeon, source = FindGroupDungeon()
    if not dungeon then
        MPH.Debug("teleport: group filled, dungeon unknown")
        return
    end
    if dismissedBy == "teleported" and dismissedCmID == dungeon.cmID then
        MPH.Debug("teleport: group filled, %s already teleported", dungeon.code)
        return
    end

    MPH.Debug("teleport: group filled, %s from %s", dungeon.code, source)
    dismissedCmID = nil
    dismissedBy = nil
    Offer(dungeon, source, true)
end

local function Restore(atLogin)
    local pending = Config().pending
    if not pending then
        if not current and HasListing() then OnActiveEntryUpdate() end
        return
    end
    if not atLogin then
        MPH.TeleportPage.Refresh()
        return
    end

    if not IsInGroup() and not HasListing() then return end
    if IsInDungeon() then return Clear("in dungeon") end

    local dungeon, reason = RememberedDungeon(true)
    if not dungeon then return Clear(reason) end

    MPH.Debug("teleport: restored %s", dungeon.code)
    Offer(dungeon, "remembered")
end

events:SetScript("OnEvent", function (_, event, ...)
    if event == "LFG_LIST_JOINED_GROUP" then
        local resultID = ...
        Latch("joined", resultID)
        local dungeon, reason = JoiningDungeon()
        if dungeon then
            OfferDungeon("joined", dungeon, true)
        else
            MPH.Debug("teleport: joined skipped, %s", tostring(reason))
        end
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local resultID, newStatus = ...
        if IsSecret(resultID) or IsSecret(newStatus) then return end
        if JOIN_PENDING[newStatus] then
            Latch(newStatus, resultID)
        elseif JOIN_LOST[newStatus] and DropLatch(newStatus, resultID) then
            if not IsInGroup() and not HasListing() then Clear("invite lost") end
        end
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        OnActiveEntryUpdate()
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnRosterUpdate()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local isLogin, isReload = ...
        if IsInDungeon() then
            Clear("entered dungeon")
        elseif not current then
            Restore(event == "PLAYER_ENTERING_WORLD" and (isLogin or isReload))
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = select(3, ...)
        if IsSecret(spellID) then return end
        local cmID = TeleportCmID(spellID)
        if cmID then Dismiss("teleported", cmID) end
    end
end)

function MPH.Teleport.Apply()
    if not MPH.db then return end
    groupSize = PartySize()
    for _, event in ipairs(FEATURE_EVENTS) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    if MPH.Teleport.IsEnabled() then Restore(true) end
end

function MPH.Teleport.Dismiss()
    Dismiss("closed")
end

local function ActiveLevel()
    if not C_ChallengeMode.GetActiveKeystoneInfo then return nil end
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    if level == nil or IsSecret(level) or level <= 0 then return nil end
    return level
end

local function HereDungeon()
    local cmID = C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    if cmID ~= nil and not IsSecret(cmID) and cmID ~= 0 then
        local dungeon = MPH.GetDungeonInfo(cmID)
        if not dungeon.teleport then return nil, "no teleport for " .. dungeon.code end
        dungeon.level = ActiveLevel()
        return dungeon, "challenge"
    end

    local instanceID = select(8, GetInstanceInfo())
    if instanceID == nil or IsSecret(instanceID) then return nil, "no instance" end
    for _, dungeon in ipairs(MPH.GetSeasonDungeons()) do
        if dungeon.mapID == instanceID and dungeon.teleport then return dungeon, "instance" end
    end
    return nil, "instance " .. tostring(instanceID) .. " not in season"
end

function MPH.Teleport.GetDungeons()
    if IsInDungeon() then
        local here, reason = HereDungeon()
        if not here then
            MPH.Debug("teleport: here unavailable, %s", tostring(reason))
            return nil, nil, "teleport.indungeon"
        end
        local key = KeystoneDungeon()
        if key and key.cmID == here.cmID then key = nil end
        return here, key, nil, true
    end

    local search = SearchDungeon()
    local key = KeystoneDungeon()
    if search and key and search.cmID == key.cmID then key = nil end
    if not search and not key then return nil, nil, "teleport.nodungeon" end
    return search, key
end

function MPH.Teleport.GroupDungeon()
    if current and SEARCH_SOURCES[currentSource] then return current end
    if not MPH.db then return nil end
    local pending = Config().pending
    if not pending or not pending.cmID or not pending.at or time() - pending.at > PENDING_TTL then return nil end
    return MPH.GetDungeonInfo(pending.cmID)
end

function MPH.Teleport.Describe()
    local parts = {}
    for _, dungeon in ipairs(MPH.GetSeasonDungeons()) do
        local known = dungeon.teleport and IsPlayerSpell(dungeon.teleport)
        table.insert(parts, string.format("%s %s/%s%s", dungeon.code, tostring(dungeon.mapID),
            tostring(dungeon.teleport), known and "+" or ""))
    end
    local pending = Config().pending
    local search, key = MPH.Teleport.GetDungeons()
    local keyText = key and key.code or "-"
    if key and key.level then keyText = keyText .. " +" .. tostring(key.level) end
    return string.format("enabled %s, current %s (%s), search %s, key %s, joining %s (%s), pending %s, dismissed %s (%s), listing %s, party %d; %s",
        tostring(MPH.Teleport.IsEnabled()),
        current and current.code or "-",
        tostring(currentSource),
        search and search.code or "-",
        keyText,
        joining and joining.cmID and MPH.GetDungeonCode(joining.cmID) or "-",
        joining and tostring(joining.resultID) or "-",
        pending and MPH.GetDungeonCode(pending.cmID) or "-",
        dismissedCmID and MPH.GetDungeonCode(dismissedCmID) or "-",
        tostring(dismissedBy),
        tostring(HasListing()),
        PartySize(),
        table.concat(parts, ", "))
end

table.insert(MPH.onLogin, function ()
    C_Timer.After(0, MPH.Teleport.Apply)
end)
