local ADDON, MPH = ...

MPH.ADDON = ADDON
MPH.PREFIX = "|cff33ff99MPH|r "

MPH.L = setmetatable({}, { __index = function (_, key) return key end })

MPH.DB_VERSION = 1
MPH.MAX_KEY_AHEAD = 5
MPH.LAYOUT_VERSION = 1

local DB_DEFAULTS = {
    version = MPH.DB_VERSION,
    presets = {},
    rating = {
        enabled = true,
        delta = 100,
    },
    keyAhead = 1,
    debug = false,
    lastScore = 0,
    noted = {
        season = 0,
        runs = {},
    },
    window = {
        shown = true,
        offset = 0,
        point = nil,
        x = 0,
        y = 0,
    },
}

function MPH.Print(msg, ...)
    if select("#", ...) > 0 then msg = string.format(msg, ...) end
    DEFAULT_CHAT_FRAME:AddMessage(MPH.PREFIX .. tostring(msg))
end

function MPH.Debug(msg, ...)
    if not MPH.db or not MPH.db.debug then return end
    if select("#", ...) > 0 then msg = string.format(msg, ...) end
    DEFAULT_CHAT_FRAME:AddMessage(MPH.PREFIX .. "|cff888888" .. tostring(msg) .. "|r")
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

function MPH.GetSearchCategory()
    if not LFGListFrame then return nil end

    local panel = LFGListFrame.SearchPanel
    if panel and panel:IsVisible() and panel.categoryID then
        return panel.categoryID
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

MPH.onLogin = {}

local function InitDB()
    MythicPresetsHelperDB = MythicPresetsHelperDB or {}
    MythicPresetsHelperDB.window = MythicPresetsHelperDB.window or {}
    MythicPresetsHelperDB.window.reserve = nil
    MPH.FillDefaults(MythicPresetsHelperDB, DB_DEFAULTS)
    MPH.db = MythicPresetsHelperDB
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
        for _, fn in ipairs(MPH.onLogin) do
            local ok, err = pcall(fn)
            if not ok then MPH.Print("init: %s", tostring(err)) end
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

function MPH.Probe()
    MPH.Print("---- probe ----")
    MPH.Print("client build: %s / interface %s", (select(1, GetBuildInfo())), tostring(select(4, GetBuildInfo())))
    MPH.Print("PGF installed: %s", tostring(MPH.HasPGF()))
    MPH.Print("toggle button: %s", MPH.DescribeToggleButton and MPH.DescribeToggleButton() or "module not loaded")
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
        MPH.Probe()
    elseif cmd == "debug" then
        MPH.db.debug = not MPH.db.debug
        MPH.Print("debug: %s", tostring(MPH.db.debug))
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
