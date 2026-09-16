local ADDON, MPH = ...

MPH.ADDON = ADDON
MPH.PREFIX = "|cff33ff99MPH|r "

MPH.L = setmetatable({}, { __index = function (_, key) return key end })

function MPH.AddSlangText(text)
    MPH.SLANG_TEXT = MPH.SLANG_TEXT or {}
    for group, values in pairs(text) do
        MPH.SLANG_TEXT[group] = MPH.SLANG_TEXT[group] or {}
        for key, value in pairs(values) do
            MPH.SLANG_TEXT[group][key] = value
        end
    end
end

MPH.DB_VERSION = 1
MPH.MAX_KEY_AHEAD = 5
MPH.LAYOUT_VERSION = 2
MPH.LOG_LIMIT = 500

local DB_DEFAULTS = {
    version = MPH.DB_VERSION,
    presets = {},
    rating = {
        enabled = true,
        delta = 100,
    },
    fit = {
        enabled = false,
    },
    keyAhead = 1,
    debug = false,
    lastScore = 0,
    noted = {
        season = 0,
        runs = {},
    },
    window = {
        autoOpen = true,
        onboarded = false,
        offset = 0,
        point = nil,
        x = 0,
        y = 0,
    },
    teleport = {
        enabled = true,
        randomStone = true,
    },
    thanks = {
        enabled = false,
    },
    loot = {
        autoOpen = true,
    },
    errors = {
        enabled = true,
    },
}

MPH.THANKS_DEFAULT = "ty bb (auto-sent by MPH addon <3)"
local THANKS_OLD_DEFAULTS = { ["ty bb <3 (auto-sent by MPH addon)"] = true }

local CHAR_DEFAULTS = {
    thanks = {
        text = MPH.THANKS_DEFAULT,
    },
    loot = {
        mapID = 0,
        level = 0,
        items = {},
    },
}

local probing = false

local function StripColors(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

function MPH.Log(msg)
    local log = MythicPresetsHelperLog
    if type(log) ~= "table" or type(log.lines) ~= "table" then return end
    local lines = log.lines
    lines[#lines + 1] = date("%m-%d %H:%M:%S") .. " " .. StripColors(tostring(msg))
    while #lines > MPH.LOG_LIMIT do
        table.remove(lines, 1)
    end
end

function MPH.Print(msg, ...)
    if select("#", ...) > 0 then msg = string.format(msg, ...) end
    if probing then
        MPH.Log(msg)
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage(MPH.PREFIX .. tostring(msg))
end

function MPH.Debug(msg, ...)
    if not MPH.db or not MPH.db.debug then return end
    if select("#", ...) > 0 then msg = string.format(msg, ...) end
    MPH.Log(msg)
end

local function LogSession(reason)
    local version, build = GetBuildInfo()
    local addon = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    MPH.Log(string.format("---- %s, MPH %s, client %s.%s, %s-%s ----", reason, tostring(addon),
        tostring(version), tostring(build), tostring(UnitName("player")), tostring(GetRealmName())))
end

function MPH.SendParty(text, tag)
    local lockdown = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    local active = C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    local send = C_ChatInfo.SendChatMessage or SendChatMessage
    local ok, err = pcall(send, text, "PARTY")
    MPH.Debug("%s: lockdown %s, active %s, send %s", tag or "chat", tostring(lockdown), tostring(active),
        ok and "ok" or tostring(err))
    return ok
end

function MPH.FillDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            MPH.FillDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function MPH.SetTitle(frame, text)
    local title = frame.TitleText
            or (frame.TitleContainer and frame.TitleContainer.TitleText)
    if title then title:SetText(text) end
end

function MPH.NotEmpty(str)
    return str ~= nil and str ~= ""
end

function MPH.GetPlayerScore()
    if not C_ChallengeMode or not C_ChallengeMode.GetOverallDungeonScore then return 0 end
    local ok, score = pcall(C_ChallengeMode.GetOverallDungeonScore)
    return ok and score or 0
end

function MPH.GetRatingRange()
    local rating = MPH.db and MPH.db.rating
    if not rating or not rating.enabled then return nil end

    local score = MPH.GetPlayerScore()
    if not score or score <= 0 then return nil end

    local delta = tonumber(rating.delta) or 0
    return math.max(0, math.floor(score - delta)), math.floor(score + delta), score
end

MPH.CATEGORY_DUNGEONS = 2
MPH.CATEGORY_RAIDS = 3

local IsSecret = issecretvalue or function () return false end

local function IsFinderCategory(categoryID)
    return categoryID == MPH.CATEGORY_DUNGEONS or categoryID == MPH.CATEGORY_RAIDS
end

local function ListingCategory()
    if not C_LFGList.HasActiveEntryInfo or not C_LFGList.HasActiveEntryInfo() then return nil end

    local info = C_LFGList.GetActiveEntryInfo()
    if type(info) ~= "table" or IsSecret(info.activityIDs) then return nil end

    local activityID = info.activityIDs and info.activityIDs[1] or info.activityID
    if activityID == nil or IsSecret(activityID) then return nil end

    local activity = C_LFGList.GetActivityInfoTable(activityID)
    if type(activity) ~= "table" or IsSecret(activity.categoryID) then return nil end
    return activity.categoryID
end

function MPH.IsFinderScreen()
    if not LFGListFrame then return false end

    local search = LFGListFrame.SearchPanel
    if search and search:IsVisible() then
        return IsFinderCategory(search.categoryID)
    end

    local viewer = LFGListFrame.ApplicationViewer
    if viewer and viewer:IsVisible() then
        local ok, categoryID = pcall(ListingCategory)
        return ok and IsFinderCategory(categoryID)
    end
    return false
end

function MPH.IsGroupFinderPage()
    return GroupFinderFrame ~= nil and GroupFinderFrame:IsVisible()
end

local function CategoryFilters(selection, categoryID)
    for _, button in ipairs(selection.CategoryButtons or {}) do
        if button.categoryID == categoryID then return button.filters end
    end
    return 0
end

function MPH.OpenGroupSearch(categoryID)
    if not LFGListFrame or not LFGListPVEStub or not PVEFrame_ShowFrame then return end
    if InCombatLockdown() then return end

    categoryID = categoryID or (MPH.GetActiveKind() == "raid" and MPH.CATEGORY_RAIDS or MPH.CATEGORY_DUNGEONS)
    local search = LFGListFrame.SearchPanel
    if search and search:IsVisible() and search.categoryID == categoryID then return end

    local listed = C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()
    local ok, err = pcall(function ()
        if PVEFrame:IsShown() then
            PVEFrame_ShowFrame("GroupFinderFrame", LFGListPVEStub)
        else
            PVEFrame_ToggleFrame("GroupFinderFrame", LFGListPVEStub)
        end
        if listed then return end
        local selection = LFGListFrame.CategorySelection
        LFGListCategorySelection_SelectCategory(selection, categoryID, CategoryFilters(selection, categoryID))
        LFGListCategorySelection_StartFindGroup(selection)
    end)
    MPH.Debug("group search: category %s, %s", tostring(categoryID), ok and "opened" or tostring(err))
end

function MPH.GetSearchCategory()
    if not LFGListFrame then return nil end

    local panel = LFGListFrame.SearchPanel
    if panel and panel:IsVisible() and panel.categoryID then
        return panel.categoryID
    end

    local viewer = LFGListFrame.ApplicationViewer
    if viewer and viewer:IsVisible() then
        local ok, categoryID = pcall(ListingCategory)
        if ok and categoryID then return categoryID end
    end

    local selection = LFGListFrame.CategorySelection
    return selection and selection.selectedCategory or nil
end

function MPH.GetPresetKind(preset)
    return preset.kind or "mplus"
end

function MPH.GetActiveKind()
    local category = MPH.GetSearchCategory()
    if category == MPH.CATEGORY_RAIDS then return "raid" end
    return "mplus"
end

function MPH.GetPGF()
    return PremadeGroupsFilter and PremadeGroupsFilter.Debug or nil
end

function MPH.HasPGF()
    return PremadeGroupsFilter ~= nil
end

function MPH.UsesPGF()
    local PGF = MPH.GetPGF()
    if not PGF or not PGF.Dialog or not PGF.Dialog.GetEnabled then return false end
    return PGF.Dialog:GetEnabled() and true or false
end

MPH.onLogin = {}

local function InitDB()
    MythicPresetsHelperDB = MythicPresetsHelperDB or {}
    MythicPresetsHelperDB.window = MythicPresetsHelperDB.window or {}
    MythicPresetsHelperDB.window.reserve = nil
    MythicPresetsHelperDB.window.shown = nil
    local teleport = MythicPresetsHelperDB.teleport
    if type(teleport) == "table" then
        teleport.point, teleport.relPoint, teleport.x, teleport.y = nil, nil, nil, nil
    end
    MPH.FillDefaults(MythicPresetsHelperDB, DB_DEFAULTS)
    MPH.db = MythicPresetsHelperDB
    if type(MythicPresetsHelperLog) ~= "table" then MythicPresetsHelperLog = {} end
    if type(MythicPresetsHelperLog.lines) ~= "table" then MythicPresetsHelperLog.lines = {} end
    MythicPresetsHelperCharDB = MPH.FillDefaults(MythicPresetsHelperCharDB or {}, CHAR_DEFAULTS)
    if THANKS_OLD_DEFAULTS[MythicPresetsHelperCharDB.thanks.text] then
        MythicPresetsHelperCharDB.thanks.text = MPH.THANKS_DEFAULT
    end
    MPH.charDB = MythicPresetsHelperCharDB
end

local eventFrame = CreateFrame("Frame", "MythicPresetsHelperEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function (_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
    elseif event == "PLAYER_LOGIN" then
        if not MPH.db then InitDB() end
        if MPH.db.window.layout ~= MPH.LAYOUT_VERSION then
            MPH.db.window.layout = MPH.LAYOUT_VERSION
            MPH.db.window.point = nil
        end
        if MPH.db.debug then LogSession("login") end
        for _, fn in ipairs(MPH.onLogin) do
            local ok, err = pcall(fn)
            if not ok then
                MPH.Print("init: %s", tostring(err))
                MPH.Debug("init: %s", tostring(err))
            end
        end
    end
end)

local function DescribeValue(value)
    local isSecret = issecretvalue and issecretvalue(value)
    if isSecret then return "<secret>" end
    if value == nil then return "nil" end
    if type(value) == "string" then return string.format("%q (len %d)", value, #value) end
    return tostring(value)
end

MPH.DescribeValue = DescribeValue

function MPH.Probe()
    MPH.Print("---- probe ----")
    MPH.Print("client build: %s / interface %s", (select(1, GetBuildInfo())), tostring(select(4, GetBuildInfo())))
    MPH.Print("PGF installed: %s", tostring(MPH.HasPGF()))
    MPH.Print("finder tab: %s", MPH.DescribeFinderTab and MPH.DescribeFinderTab() or "module not loaded")
    MPH.Print("window: %s", MPH.DescribeWindow and MPH.DescribeWindow() or "module not loaded")
    local pending, tries = MPH.Progress.GetPending()
    MPH.Print("score: %d, last seen %s, pending rebuild %s (attempt %d)",
        MPH.GetPlayerScore(), tostring(MPH.db.lastScore), tostring(pending), tries)
    MPH.Print("category: %s -> kind %s",
        tostring(MPH.GetSearchCategory()), tostring(MPH.GetActiveKind()))
    local counts = { mplus = 0, raid = 0 }
    for _, preset in ipairs(MPH.Presets.All()) do
        local kind = MPH.GetPresetKind(preset)
        counts[kind] = (counts[kind] or 0) + 1
    end
    MPH.Print("presets: mplus %d, raid %d, armor %s",
        counts.mplus, counts.raid, tostring(MPH.GetPlayerArmor()))

    local history = {}
    local okRuns, runs = pcall(C_MythicPlus.GetRunHistory, true, true)
    if okRuns and runs then
        for _, run in ipairs(runs) do
            local id = run.mapChallengeModeID
            if id and run.level then
                local entry = history[id] or { timed = 0, any = 0 }
                if run.completed then entry.timed = math.max(entry.timed, run.level) end
                entry.any = math.max(entry.any, run.level)
                history[id] = entry
            end
        end
    end

    local summary = {}
    for _, run in ipairs(MPH.GetRatingSummaryRuns() or {}) do
        if run.challengeModeID then
            summary[run.challengeModeID] = string.format("%s%s",
                tostring(run.bestRunLevel), MPH.IsTimedRun(run) and "" or "*")
        end
    end

    local recent = MPH.Progress.GetRecentTimed()
    MPH.Print("dungeon best (season intime/overtime, history timed/any, summary, noted; * = not timed):")
    for _, dungeon in ipairs(MPH.GetSeasonDungeons()) do
        local okBest, intime, overtime = pcall(C_MythicPlus.GetSeasonBestForMap, dungeon.cmID)
        local entry = history[dungeon.cmID]
        MPH.Print("   %-4s %s: %s/%s, %d/%d, %s, %d",
            dungeon.code, dungeon.name,
            (okBest and intime) and tostring(intime.level) or "-",
            (okBest and overtime) and tostring(overtime.level) or "-",
            entry and entry.timed or 0, entry and entry.any or 0,
            summary[dungeon.cmID] or "-",
            recent[dungeon.cmID] or 0)
    end
    MPH.Print("teleport (code mapID/spell, + = known): %s", MPH.Teleport.Describe())
    MPH.Print("hearthstone (- = not usable): %s", MPH.Hearthstone.Describe())
    MPH.Print("errors: %s", MPH.Errors.Describe())
    MPH.Print("current raid: %s", tostring(MPH.Raids.GetCurrentRaidName()))
    for _, filters in ipairs({ 5, 1, 6, 2, 4, 0 }) do
        local ok, groups = pcall(C_LFGList.GetAvailableActivityGroups, MPH.CATEGORY_RAIDS, filters)
        MPH.Print("   raid filter %d -> %s groups", filters,
            ok and tostring(groups and #groups or 0) or "error")
    end

    local interesting = {}
    pcall(function ()
        for name in pairs(C_LFGList) do
            if name:find("earch") or name:find("ensor") or name:find("Filter") then
                table.insert(interesting, name)
            end
        end
    end)
    table.sort(interesting)
    MPH.Print("C_LFGList search/censor API: %s", table.concat(interesting, ", "))

    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel or not panel:IsVisible() then
        MPH.Print("group finder search panel is not open - open it and run /mph probe again")
        return
    end

    local okBox, boxText = pcall(function ()
        return panel.SearchBox and panel.SearchBox:GetText()
    end)
    MPH.Print("search box text: %s", okBox and DescribeValue(boxText) or "<read blocked>")
    MPH.Print("results shown: %s (total %s)",
        tostring(panel.results and #panel.results or 0), tostring(panel.totalResults))

    local total, results = C_LFGList.GetSearchResults()
    MPH.Print("C_LFGList.GetSearchResults: total=%s returned=%s",
        tostring(total), tostring(results and #results or 0))

    local resultID = results and results[1]
    if not resultID then
        MPH.Print("no search results to inspect")
        return
    end

    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info then
        MPH.Print("GetSearchResultInfo returned nil for result %s", tostring(resultID))
        return
    end
    MPH.Print("first result fields:")
    for _, field in ipairs({ "censored", "name", "comment", "leaderName", "requiredDungeonScore",
                             "leaderOverallDungeonScore", "requiredItemLevel", "numMembers", "age" }) do
        MPH.Print("   %s = %s", field, DescribeValue(info[field]))
    end
    MPH.Print("---- end probe ----")
end

function MPH.RunProbe()
    probing = true
    local ok, err = pcall(MPH.Probe)
    probing = false
    if ok then
        MPH.Print("probe written to log, /reload to save")
    else
        MPH.Log("probe failed: " .. tostring(err))
        MPH.Print("probe: %s", tostring(err))
    end
end

function MPH.SetDebug(enabled)
    MPH.db.debug = enabled and true or false
    LogSession(MPH.db.debug and "debug on" or "debug off")
    MPH.Print("debug: %s", tostring(MPH.db.debug))
    if MPH.RefreshDebugButtons then MPH.RefreshDebugButtons() end
end

function MPH.ClearLog()
    if type(MythicPresetsHelperLog) ~= "table" then return end
    MythicPresetsHelperLog.lines = {}
    LogSession("cleared")
    MPH.Print("log cleared, /reload to save")
end

local HELP_LINES = {
    { "/mph",            "help.toggle" },
    { "/mph probe",      "help.probe"  },
    { "/mph debug",      "help.debug"  },
    { "/mph offset <n>", "help.offset" },
    { "/mph reset",      "help.reset"  },
}

local function PrintHelp()
    for _, line in ipairs(HELP_LINES) do
        MPH.Print("|cffffd100%s|r  %s", line[1], MPH.L[line[2]])
    end
end

SLASH_MYTHICPRESETSHELPER1 = "/mph"
SLASH_MYTHICPRESETSHELPER2 = "/mythicpresets"
SlashCmdList["MYTHICPRESETSHELPER"] = function (msg)
    local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "probe" then
        MPH.RunProbe()
    elseif cmd == "debug" then
        MPH.SetDebug(not MPH.db.debug)
    elseif cmd == "clearlog" then
        MPH.ClearLog()
    elseif cmd == "reset" then
        MPH.db.window.point = nil
        MPH.db.window.x = 0
        MPH.db.window.y = 0
        if MPH.RestoreWindowPosition then MPH.RestoreWindowPosition() end
        MPH.Print(MPH.L["msg.positionreset"])
    elseif cmd == "offset" then
        local value = tonumber(rest)
        if value then
            MPH.db.window.offset = math.floor(value)
            if MPH.PinWindowBesideGroupFinder then MPH.PinWindowBesideGroupFinder() end
        end
        MPH.Print("offset: %d", tonumber(MPH.db.window.offset) or 0)
    elseif cmd == "loot" and rest == "test" and MPH.db.debug then
        MPH.Loot.Test()
    elseif cmd == "help" then
        PrintHelp()
    else
        if MPH.ToggleWindow then
            MPH.ToggleWindow()
        else
            MPH.Print(MPH.L["msg.notready"])
        end
        PrintHelp()
    end
end
