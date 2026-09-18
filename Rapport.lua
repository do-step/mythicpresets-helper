local ADDON, MPH = ...

MPH.Rapport = {}

local Rapport = MPH.Rapport

local IsSecret = issecretvalue or function () return false end

local UNITS = { "party1", "party2", "party3", "party4" }
local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local ROLE_KEYS = { TANK = "rapport.roletank", HEALER = "rapport.rolehealer", DAMAGER = "rapport.roledps" }
local RATING_COUNT = 3
local RATING_DEFAULT = 1
local SCHEMA = 1
local SCORE_DELAY = 4
local SCORE_ATTEMPTS = 8
local SCORE_WINDOW = 900
local SCORE_UNKNOWN = -1

local events = CreateFrame("Frame")
local waiting = false
local lastTrace
local scoreAttempts = 0
local scoreTicking = false

local function Store()
    return MPH.db.rapport
end

local function Refresh()
    if MPH.RapportPage then MPH.RapportPage.Refresh() end
    if MPH.RapportHistory then MPH.RapportHistory.Refresh() end
end

function Rapport.Current()
    return Store().current
end

function Rapport.History()
    return Store().history
end

local function ByRole(a, b)
    local left, right = ROLE_ORDER[a.role] or 4, ROLE_ORDER[b.role] or 4
    if left ~= right then return left < right end
    return (a.name or "") < (b.name or "")
end

function Rapport.Members(run)
    local list = {}
    for _, member in ipairs(run and run.members or {}) do
        table.insert(list, member)
    end
    table.sort(list, ByRole)
    return list
end

function Rapport.Party(run)
    local list = Rapport.Members(run)
    if run and run.self then table.insert(list, run.self) end
    table.sort(list, ByRole)
    return list
end

local function RatingColor(value)
    if value == 0 then return RED_FONT_COLOR end
    if value == 1 then return HIGHLIGHT_FONT_COLOR end
    return GREEN_FONT_COLOR
end

function Rapport.GetLabel(kind, value)
    local labels = Store().labels[kind]
    local text = labels and labels[value + 1]
    if MPH.NotEmpty(text) then return text end
    return MPH.L[string.format("rapport.%s%d", kind, value)]
end

function Rapport.IsCustomLabel(kind, value)
    local labels = Store().labels[kind]
    return MPH.NotEmpty(labels and labels[value + 1])
end

function Rapport.SetLabel(kind, value, text)
    text = tostring(text or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    Store().labels[kind][value + 1] = MPH.NotEmpty(text) and text or nil
    Refresh()
end

function Rapport.ResetLabels()
    Store().labels = { game = {}, role = {} }
    Refresh()
end

function Rapport.RoleWord(role)
    local key = ROLE_KEYS[role]
    return key and MPH.L[key] or ""
end

local function Entry(name, create)
    if not MPH.NotEmpty(name) then return nil end
    local players = Store().players
    local entry = players[name]
    if not entry and create then
        entry = { roles = {} }
        players[name] = entry
    end
    return entry
end

function Rapport.IsRated(name)
    return Entry(name) ~= nil
end

function Rapport.GetGame(name)
    local entry = Entry(name)
    return entry and entry.game or RATING_DEFAULT
end

function Rapport.GetRole(name, role)
    local entry = role and Entry(name)
    return entry and entry.roles[role] or RATING_DEFAULT
end

local function Step(value, delta)
    value = value + (delta > 0 and 1 or -1)
    return math.max(0, math.min(RATING_COUNT - 1, value))
end

local function Prune(name)
    local entry = Entry(name)
    if not entry then return end
    if entry.game ~= RATING_DEFAULT then return end
    for _, value in pairs(entry.roles) do
        if value ~= RATING_DEFAULT then return end
    end
    Store().players[name] = nil
end

local function Remember(entry, member)
    if not member then return end
    entry.class = member.class or entry.class
    entry.spec = member.spec or entry.spec
    entry.role = member.role or entry.role
    if entry.score == nil then
        entry.score = member.score
        entry.scoreAt = member.score and time() or nil
    end
end

function Rapport.StepGame(member, delta)
    local entry = Entry(member.name, true)
    if not entry then return end
    Remember(entry, member)
    entry.game = Step(Rapport.GetGame(member.name), delta)
    entry.ts = time()
    Prune(member.name)
    MPH.Debug("rapport: rating %s game %s", member.name, tostring(entry.game))
    Refresh()
end

function Rapport.StepRole(member, delta)
    local role = member.role
    if not role then return end
    local entry = Entry(member.name, true)
    if not entry then return end
    Remember(entry, member)
    entry.roles[role] = Step(Rapport.GetRole(member.name, role), delta)
    entry.ts = time()
    Prune(member.name)
    MPH.Debug("rapport: rating %s %s %s", member.name, role, tostring(entry.roles[role]))
    Refresh()
end

function Rapport.GetPrevious(name)
    local entry = Entry(name)
    if not entry or entry.prevScore == nil then return nil end
    return entry.prevScore, entry.prevAt
end

function Rapport.FormatGame(text, score)
    local number = tonumber(score)
    return (text:gsub(MPH.L["rapport.scoretoken"], number and tostring(math.floor(number)) or "-"))
end

function Rapport.FormatRole(text, role, score)
    text = Rapport.FormatGame(text, score)
    local word = Rapport.RoleWord(role)
    local replaced, count = text:gsub(MPH.L["rapport.roletoken"], word)
    if count > 0 then return replaced end
    if not MPH.NotEmpty(word) then return text end
    return replaced .. " " .. word
end

local function GameText(value, score)
    return Rapport.FormatGame(Rapport.GetLabel("game", value), score)
end

local function RoleText(role, value, score)
    return Rapport.FormatRole(Rapport.GetLabel("role", value), role, score)
end

local function GamePart(name, score, plain)
    local value = Rapport.GetGame(name)
    local text = GameText(value, score)
    return plain and text or RatingColor(value):WrapTextInColorCode(text)
end

local function RolePart(name, role, score, plain)
    if not role then return nil end
    local value = Rapport.GetRole(name, role)
    local text = RoleText(role, value, score)
    return plain and text or RatingColor(value):WrapTextInColorCode(text)
end

function Rapport.Text(name, role, score, plain)
    local parts = {}
    local rolePart = RolePart(name, role, score, plain)
    if rolePart then table.insert(parts, rolePart) end
    table.insert(parts, GamePart(name, score, plain))
    return table.concat(parts, ", ")
end

local function Clean(value)
    if value == nil or IsSecret(value) then return nil end
    return value
end

local function Copy(member)
    if not member then return nil end
    local copy = {}
    for key, value in pairs(member) do copy[key] = value end
    return copy
end

local function ReadName(unit)
    local name, realm = UnitFullName(unit)
    name, realm = Clean(name), Clean(realm)
    if not MPH.NotEmpty(name) or name == UNKNOWNOBJECT then return nil end
    if not MPH.NotEmpty(realm) then realm = GetNormalizedRealmName() end
    if not MPH.NotEmpty(realm) then return nil end
    return name .. "-" .. realm
end

local function ReadRole(unit)
    local role = Clean(UnitGroupRolesAssigned(unit))
    if role == "NONE" then return nil end
    return role
end

local function ReadSpec(unit)
    if UnitIsUnit(unit, "player") then
        local index = GetSpecialization and GetSpecialization()
        local id = index and GetSpecializationInfo(index)
        return Clean(id)
    end
    if not GetInspectSpecialization then return nil end
    local ok, id = pcall(GetInspectSpecialization, unit)
    if not ok then return nil end
    id = Clean(id)
    if not id or id == 0 then return nil end
    return id
end

local function RequestInspect(unit)
    if not unit or not CanInspect or not NotifyInspect then return end
    local ok, err = pcall(function ()
        if CanInspect(unit) then NotifyInspect(unit) end
    end)
    MPH.Debug("rapport: inspect %s, %s", unit, ok and "requested" or tostring(err))
end

local function ReadScore(unit)
    if not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then return nil end
    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
    if not ok or type(Clean(summary)) ~= "table" then return nil end
    return Clean(summary.currentSeasonScore)
end

local function ReadSelf()
    local role = ReadRole("player")
    if not role and GetSpecialization and GetSpecializationRole then
        local spec = GetSpecialization()
        role = spec and GetSpecializationRole(spec) or nil
    end
    return { class = Clean((select(2, UnitClass("player")))), role = role, spec = ReadSpec("player") }
end

local function ReadMembers(previous)
    local members, missing, inspect = {}, {}, nil
    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            local name = ReadName(unit)
            if name then
                local member = previous[name] or { name = name }
                member.class = member.class or Clean((select(2, UnitClass(unit))))
                member.role = member.role or ReadRole(unit)
                if member.score == nil then member.score = ReadScore(unit) end
                if member.spec == nil then member.spec = ReadSpec(unit) end
                if member.score == nil then table.insert(missing, unit .. " rating") end
                if member.spec == nil then
                    table.insert(missing, unit .. " spec")
                    inspect = inspect or unit
                end
                table.insert(members, member)
            else
                table.insert(missing, unit .. " name")
            end
        end
    end
    return members, missing, inspect
end

local function SetWaiting(value)
    if waiting == value then return end
    waiting = value
    if value then
        events:RegisterEvent("GROUP_ROSTER_UPDATE")
        events:RegisterEvent("UNIT_NAME_UPDATE")
        events:RegisterEvent("INSPECT_READY")
    else
        events:UnregisterEvent("GROUP_ROSTER_UPDATE")
        events:UnregisterEvent("UNIT_NAME_UPDATE")
        events:UnregisterEvent("INSPECT_READY")
    end
end

local function ActiveRun()
    if not C_ChallengeMode.IsChallengeModeActive or not C_ChallengeMode.IsChallengeModeActive() then return nil end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    if not mapID or not level or level == 0 then return false end
    return mapID, level
end

local TickScores

local function ApplyScore(name, score)
    local store = Store()
    local run = store.current
    for _, member in ipairs(run.members) do
        if member.name == name then member.score = score end
    end
    local saved = store.history[1]
    if saved and saved.startedAt == run.startedAt then
        for _, member in ipairs(saved.members) do
            if member.name == name then member.score = score end
        end
    end
    local rated = Entry(name)
    if rated then
        rated.score, rated.scoreAt = score, time()
    end
end

local function StopScores(reason)
    local pending = Store().current.pending
    if not pending then return end
    local missed = {}
    for name in pairs(pending) do table.insert(missed, name) end
    Store().current.pending = nil
    scoreAttempts = 0
    events:UnregisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    MPH.Debug("rapport: scores %s, missed %s", reason, #missed > 0 and table.concat(missed, ", ") or "none")
end

local function PollScores(reason)
    local pending = Store().current.pending
    if not pending then return end

    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            local name = ReadName(unit)
            local base = name and pending[name]
            if base then
                local score = ReadScore(unit)
                if score and score ~= base then
                    ApplyScore(name, score)
                    pending[name] = nil
                    MPH.Debug("rapport: score %s, %s -> %s", name, tostring(base), tostring(score))
                end
            end
        end
    end

    local left = 0
    for _ in pairs(pending) do left = left + 1 end
    MPH.Debug("rapport: scores %s, left %d, attempt %d", reason, left, scoreAttempts)
    Refresh()

    if left == 0 then
        StopScores("done")
    elseif scoreAttempts >= SCORE_ATTEMPTS then
        StopScores("gave up")
    else
        TickScores()
    end
end

function TickScores()
    if scoreTicking then return end
    scoreTicking = true
    C_Timer.After(SCORE_DELAY, function ()
        scoreTicking = false
        scoreAttempts = scoreAttempts + 1
        PollScores("retry")
    end)
end

local function StartScores(reason)
    local store = Store()
    local pending = store.current.pending
    if not pending then return end
    if not next(pending) then
        store.current.pending = nil
        return
    end

    local saved = store.history[1]
    local endedAt = saved and saved.startedAt == store.current.startedAt and saved.endedAt or 0
    if time() - endedAt > SCORE_WINDOW then
        StopScores("stale")
        return
    end

    scoreAttempts = 0
    events:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    PollScores(reason)
end

local function Save(reason, mapID, level, keep)
    local store = Store()
    if not keep then
        StopScores("new run")
        store.current = { mapID = mapID, level = level, startedAt = time(), members = {} }
    end
    local run = store.current

    local previous = {}
    for _, member in ipairs(run.members) do previous[member.name] = member end
    run.self = run.self or ReadSelf()

    local members, missing, inspect = ReadMembers(previous)
    run.members = members

    local trace = string.format("map %s level %s, self %s/%s, members %d, missing %s", tostring(mapID),
        tostring(level), tostring(run.self.class), tostring(run.self.role), #members,
        #missing > 0 and table.concat(missing, ", ") or "none")
    if trace ~= lastTrace or reason ~= "retry" then
        MPH.Debug("rapport: %s, %s", reason, trace)
        lastTrace = trace
    end
    SetWaiting(#missing > 0)
    if inspect then RequestInspect(inspect) end
    Refresh()
end

local function Start(reason)
    local mapID, level = ActiveRun()
    if mapID == nil and reason ~= "start" then
        if reason ~= "resume" then MPH.Debug("rapport: %s, no active run", reason) end
        return
    end
    if not mapID then
        MPH.Debug("rapport: %s, active, map not ready", reason)
        events:RegisterEvent("WORLD_STATE_TIMER_START")
        return
    end
    events:UnregisterEvent("WORLD_STATE_TIMER_START")

    local run = Store().current
    local same = run.mapID == mapID and run.level == level
    Save(reason, mapID, level, reason ~= "start" and same)
end

local function Stop(reason)
    if not waiting then return end
    MPH.Debug("rapport: %s, stop waiting, members %d", reason, #Store().current.members)
    SetWaiting(false)
end

local function Complete()
    local info = MPH.Progress.CompletionInfo()
    if info and info.practiceRun then return end

    local store = Store()
    local run = store.current
    if run.saved or (run.startedAt or 0) == 0 then
        MPH.Debug("rapport: completed, nothing to save (started %s, saved %s)",
            tostring(run.startedAt), tostring(run.saved))
        return
    end
    local mapID = info and Clean(info.mapChallengeModeID)
    if mapID and mapID ~= run.mapID then
        MPH.Debug("rapport: completed map %s, stored map %s, not saved", tostring(mapID), tostring(run.mapID))
        return
    end

    local entry = {
        mapID = run.mapID,
        level = run.level,
        startedAt = run.startedAt,
        endedAt = time(),
        onTime = info and info.onTime and true or false,
        self = Copy(run.self),
        members = {},
    }
    local pending = {}
    for _, member in ipairs(run.members) do
        table.insert(entry.members, Copy(member))
        pending[member.name] = member.score or SCORE_UNKNOWN
        local rated = Entry(member.name)
        if rated then
            if rated.scoreAt and rated.scoreAt < (run.startedAt or 0) then
                rated.prevScore, rated.prevAt = rated.score, rated.scoreAt
            end
            rated.score, rated.scoreAt = member.score, time()
            rated.class = member.class or rated.class
            rated.spec = member.spec or rated.spec
            rated.role = member.role or rated.role
            rated.last = time()
            MPH.Debug("rapport: player %s, score %s, previous %s", member.name,
                tostring(rated.score), tostring(rated.prevScore))
        end
    end
    table.insert(store.history, 1, entry)
    run.saved = true
    run.pending = pending

    MPH.Debug("rapport: saved, map %s level %s, onTime %s (info %s), members %d, history %d",
        tostring(entry.mapID), tostring(entry.level), tostring(entry.onTime), tostring(info ~= nil),
        #entry.members, #store.history)
    if MPH.SetPageAlert then MPH.SetPageAlert("rapport", true) end
    Refresh()
    StartScores("completed")
end

local function OnUnitTooltip(tooltip)
    if tooltip ~= GameTooltip then return end
    local _, unit = TooltipUtil.GetDisplayedUnit(tooltip)
    if not unit or IsSecret(unit) or not UnitIsPlayer(unit) then return end

    local name = ReadName(unit)
    if not name or not Rapport.IsRated(name) then return end
    tooltip:AddLine(Rapport.Text(name, ReadRole(unit), ReadScore(unit)))
end

function Rapport.Describe()
    local store = Store()
    local run = store.current
    local rated, pending = 0, 0
    for _ in pairs(Store().players) do rated = rated + 1 end
    for _ in pairs(run.pending or {}) do pending = pending + 1 end
    return string.format("map %s level %s, members %d, saved %s, history %d, waiting %s, rated %d, pending %d",
        tostring(run.mapID), tostring(run.level), #run.members, tostring(run.saved), #store.history,
        tostring(waiting), rated, pending)
end

events:SetScript("OnEvent", function (_, event, ...)
    if event == "CHALLENGE_MODE_START" then
        Start("start")
    elseif event == "WORLD_STATE_TIMER_START" then
        Start("timer")
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        Stop("completed")
        Complete()
    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
        PollScores("maps update")
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        if isLogin or isReload then
            Start("resume")
            StartScores("resume")
        elseif not ActiveRun() then
            Stop("left dungeon")
            PollScores("left dungeon")
        end
    elseif waiting then
        if event == "INSPECT_READY" and ClearInspectPlayer then ClearInspectPlayer() end
        local mapID, level = ActiveRun()
        if mapID then
            Save("retry", mapID, level, true)
        elseif mapID == nil then
            Stop("run ended")
        end
    end
end)

function Rapport.Reset()
    StopScores("reset")
    local store = Store()
    store.current = { mapID = 0, level = 0, startedAt = 0, members = {} }
    store.history = {}
    store.players = {}
    store.schema = SCHEMA
    MPH.Debug("rapport: reset, schema %d", SCHEMA)
    Refresh()
end

table.insert(MPH.onLogin, function ()
    if MPH.charDB.rapport then
        MPH.charDB.rapport = nil
        MPH.Debug("rapport: dropped character data")
    end

    if Store().schema ~= SCHEMA then
        Rapport.Reset()
    end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
    else
        MPH.Debug("rapport: tooltip hook not available")
    end

    events:RegisterEvent("CHALLENGE_MODE_START")
    events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
end)
