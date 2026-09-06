local ADDON, MPH = ...
local L = MPH.L

MPH.Progress = {}
local Progress = MPH.Progress

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

local function BestFromRunHistory()
    local best = {}
    local ok, history = pcall(C_MythicPlus.GetRunHistory, true, true)
    if not ok or not history then return best, false end

    for _, run in ipairs(history) do
        if run.completed and run.mapChallengeModeID and run.level then
            local current = best[run.mapChallengeModeID] or 0
            if run.level > current then
                best[run.mapChallengeModeID] = run.level
            end
        end
    end
    return best, true
end

function Progress.GetBestInTime()
    local season = MPH.GetSeasonDungeons()
    local cmIDs = {}
    for _, dungeon in ipairs(season) do table.insert(cmIDs, dungeon.cmID) end

    local fromHistory, ready = BestFromRunHistory()
    local fromSeason = BestFromSeasonBest(cmIDs)

    local best = {}
    local trace = {}
    for _, cmID in ipairs(cmIDs) do
        local a = fromSeason and fromSeason[cmID] or 0
        local b = fromHistory[cmID] or 0
        best[cmID] = math.max(a, b)
        table.insert(trace, string.format("%d=%d", cmID, best[cmID]))
    end
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
    if not generated then return false end
    if AutoSignature(generated) == AutoSignature(MPH.Presets.All()) then
        return false
    end
    Progress.Rebuild(generated)
    return true
end

table.insert(MPH.onLogin, function ()

    if C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:SetScript("OnEvent", function ()
        if C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
    end)
end)
