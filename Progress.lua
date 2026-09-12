local ADDON, MPH = ...
local L = MPH.L

MPH.Progress = {}
local Progress = MPH.Progress

local function NotedRuns()
    if not MPH.db then return {} end

    local noted = MPH.db.noted
    local season = C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason() or 0
    if season > 0 and noted.season ~= season then
        noted.season = season
        noted.runs = {}
    end
    return noted.runs
end

function Progress.NoteTimedRun(cmID, level)
    if not cmID or not level then return end

    local runs = NotedRuns()
    if level > (runs[cmID] or 0) then
        runs[cmID] = level
        MPH.Debug("noted timed run: map %s level %s", tostring(cmID), tostring(level))
    end
end

function Progress.GetRecentTimed()
    return NotedRuns()
end

local function BestFromSeasonBest(cmIDs)
    if not C_MythicPlus.GetSeasonBestForMap then return nil end

    local best = {}
    for _, cmID in ipairs(cmIDs) do
        local ok, intimeInfo = pcall(C_MythicPlus.GetSeasonBestForMap, cmID)
        if ok and intimeInfo and intimeInfo.level then
            best[cmID] = intimeInfo.level
        end
    end
    return best
end

local function WithinTimer(cmID, durationMS)
    if not durationMS or durationMS <= 0 then return nil end

    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(cmID)
    if not timeLimit or timeLimit <= 0 then return nil end
    return durationMS / 1000 <= timeLimit
end

function MPH.IsTimedRun(run)
    if not run or not run.finishedSuccess then return false end
    return WithinTimer(run.challengeModeID, run.bestRunDurationMS) ~= false
end

function MPH.GetRatingSummaryRuns()
    if not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then return nil end

    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
    if not ok or not summary then return nil end
    return summary.runs
end

local function BestFromRatingSummary()
    local runs = MPH.GetRatingSummaryRuns()
    if not runs then return nil end

    local best = {}
    for _, run in ipairs(runs) do
        if run.challengeModeID and run.bestRunLevel and MPH.IsTimedRun(run) then
            if run.bestRunLevel > (best[run.challengeModeID] or 0) then
                best[run.challengeModeID] = run.bestRunLevel
            end
        end
    end
    return best
end

local function RunHistoryReady()
    local ok, history = pcall(C_MythicPlus.GetRunHistory, true, true)
    return ok and history ~= nil
end

function Progress.GetBestInTime()
    local season = MPH.GetSeasonDungeons()
    local cmIDs = {}
    for _, dungeon in ipairs(season) do table.insert(cmIDs, dungeon.cmID) end

    local ready = RunHistoryReady()
    local fromSeason = BestFromSeasonBest(cmIDs)
    local fromSummary = BestFromRatingSummary()
    local noted = NotedRuns()

    local best = {}
    local trace = {}
    for _, cmID in ipairs(cmIDs) do
        local seasonBest = fromSeason and fromSeason[cmID] or 0
        local summaryBest = fromSummary and fromSummary[cmID] or 0
        local noteBest = noted[cmID] or 0
        best[cmID] = math.max(seasonBest, summaryBest, noteBest)
        if noteBest > 0 and math.max(seasonBest, summaryBest) >= noteBest then noted[cmID] = nil end
        table.insert(trace, string.format("%s=%d[s%d/p%d/n%d]",
            MPH.GetDungeonCode(cmID), best[cmID], seasonBest, summaryBest, noteBest))
    end

    MPH.Debug("best in time (ready %s): %s", tostring(ready), table.concat(trace, " "))
    return best, ready
end

function Progress.BuildAutoPresets()
    local season = MPH.GetSeasonDungeons()
    if #season == 0 then return nil end

    local best, ready = Progress.GetBestInTime()
    if not ready then return nil end
    local byTarget = {}
    local targets = {}
    local untimed = {}

    for _, dungeon in ipairs(season) do
        local level = best[dungeon.cmID] or 0
        if level > 0 then
            local target = level + 1
            if not byTarget[target] then
                byTarget[target] = {}
                table.insert(targets, target)
            end
            table.insert(byTarget[target], dungeon.cmID)
        else
            table.insert(untimed, dungeon.cmID)
        end
    end

    table.sort(targets, function (a, b) return a > b end)

    local presets = {}
    for _, target in ipairs(targets) do
        table.insert(presets, {
            name = MPH.GetDungeonLabel(byTarget[target]),
            keyText = tostring(target),
            dungeons = byTarget[target],
            auto = true,
            autoKind = "push",
            autoLevel = target,
        })
    end
    if #untimed > 0 then
        table.insert(presets, {
            name = MPH.GetDungeonLabel(untimed),
            keyText = "",
            dungeons = untimed,
            auto = true,
            autoKind = "new",
            autoLevel = nil,
        })
    end

    return presets
end

function Progress.BuildAll()
    local presets = Progress.BuildAutoPresets()
    if not presets then return nil end

    for _, preset in ipairs(MPH.Raids.BuildAutoPresets() or {}) do
        table.insert(presets, preset)
    end
    return presets
end

function Progress.Rebuild(generated)
    generated = generated or Progress.BuildAll()
    if not generated then
        MPH.Print(L["msg.nodungeondata"])
        return nil
    end

    local manual = {}
    for _, preset in ipairs(MPH.Presets.All()) do
        if not preset.auto then table.insert(manual, preset) end
    end

    local combined = generated
    for _, preset in ipairs(manual) do table.insert(combined, preset) end

    MPH.db.presets = combined
    MPH.db.activePreset = nil
    return #generated
end

local function AutoSignature(presets)
    local parts = {}
    for _, preset in ipairs(presets) do
        if preset.auto then
            local sorted = {}
            for _, cmID in ipairs(preset.dungeons) do table.insert(sorted, cmID) end
            table.sort(sorted)
            table.insert(parts, string.format("%s:%s:%s:%s",
                tostring(preset.autoKind), tostring(preset.autoLevel),
                tostring(preset.armorMax) .. "/" .. tostring(preset.membersMin),
                table.concat(sorted, ",")))
        end
    end
    return table.concat(parts, "|")
end

function Progress.RebuildIfChanged()
    local generated = Progress.BuildAll()
    if not generated then
        MPH.Debug("rebuild skipped, data not ready")
        return false
    end

    local fresh = AutoSignature(generated)
    local current = AutoSignature(MPH.Presets.All())
    if fresh == current then
        MPH.Debug("rebuild skipped, nothing changed")
        return false
    end

    MPH.Debug("rebuild: %s", fresh)
    Progress.Rebuild(generated)
    return true
end

local CHECK_DELAY = 3
local MAX_ATTEMPTS = 10

local pendingRun = false
local attempts = 0
local scheduled = false

function Progress.CompletionInfo()
    if not C_ChallengeMode.GetChallengeCompletionInfo then return nil end
    local ok, info = pcall(C_ChallengeMode.GetChallengeCompletionInfo)
    return ok and info or nil
end

local function ScheduleCheck()
    if scheduled then return end
    scheduled = true
    C_Timer.After(CHECK_DELAY, function ()
        scheduled = false
        Progress.CheckForUpdate()
    end)
end

function Progress.GetPending()
    return pendingRun, attempts
end

function Progress.CheckForUpdate()
    local score = MPH.GetPlayerScore()
    if not pendingRun and score > 0 and score == (MPH.db.lastScore or 0) then
        MPH.Debug("check skipped, score unchanged (%d)", score)
        return
    end

    MPH.db.lastScore = score
    if pendingRun then attempts = attempts + 1 end
    MPH.Debug("check: score %d, pending %s, attempt %d", score, tostring(pendingRun), attempts)

    if Progress.RebuildIfChanged() then
        pendingRun = false
        attempts = 0
        MPH.RefreshWindow()
    elseif pendingRun and attempts < MAX_ATTEMPTS then
        ScheduleCheck()
    end
end

table.insert(MPH.onLogin, function ()

    if C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function (_, event)
        MPH.Debug("event %s, pending %s", event, tostring(pendingRun))

        if event == "CHALLENGE_MODE_COMPLETED" then
            local info = Progress.CompletionInfo()
            if info then
                MPH.Debug("completed: map %s level %s onTime %s practice %s score %s -> %s",
                    tostring(info.mapChallengeModeID), tostring(info.level), tostring(info.onTime),
                    tostring(info.practiceRun), tostring(info.oldOverallDungeonScore),
                    tostring(info.newOverallDungeonScore))
            end
            if info and info.practiceRun then return end
            if info and info.onTime then
                Progress.NoteTimedRun(info.mapChallengeModeID, info.level)
            end

            pendingRun = true
            attempts = 0
            if C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
        elseif event == "PLAYER_ENTERING_WORLD" and pendingRun then
            attempts = 0
            if C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
        end

        ScheduleCheck()
    end)
end)
