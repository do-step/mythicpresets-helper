local ADDON, MPH = ...

MPH.Rapport = {}

local Rapport = MPH.Rapport

local IsSecret = issecretvalue or function () return false end

local UNITS = { "party1", "party2", "party3", "party4" }
local PARTY_UNITS = { party1 = true, party2 = true, party3 = true, party4 = true }
local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local ROLE_KEYS = { TANK = "rapport.roletank", HEALER = "rapport.rolehealer", DAMAGER = "rapport.roledps" }
local RATING_COUNT = 3
local RATING_DEFAULT = 1
local SCHEMA = 1
local SCORE_DELAY = 4
local SCORE_ATTEMPTS = 8
local SCORE_WINDOW = 900
local SCORE_UNKNOWN = -1
local DIFFICULTY_KEYSTONE = 8
local LEFT_MIN = 60
local LEFT_MAX = 5
local RUN_STALE = 2 * 60 * 60
local QUEUE_DELAY = 1
local INSPECT_GAP = 2
local INSPECT_TIMEOUT = 10
local INSPECT_COOLDOWN = 30
local PVP_MUTE = 10
local QUIET = { retry = true, roster = true, inspect = true }

local events = CreateFrame("Frame")
local waiting = false
local lastTrace
local scoreAttempts = 0
local scoreTicking = false
local queued
local inspecting = false
local inspectBusy = false
local inspectToken = 0
local inspectGUID
local inspectNote
local inspectAt = {}
local pvpToken = 0

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

local function ByLeft(a, b)
    return (a.leftAt or 0) > (b.leftAt or 0)
end

local function Stage(run)
    if run.saved then return "saved" end
    if run.active then return "active" end
    return run.stage or "gather"
end

function Rapport.IsGathering(run)
    return run ~= nil and run == Store().current and (run.startedAt or 0) > 0
        and not run.active and not run.saved
end

function Rapport.Members(run)
    local list = {}
    for _, member in ipairs(run and run.members or {}) do
        if not member.left then table.insert(list, member) end
    end
    table.sort(list, ByRole)
    return list
end

function Rapport.Left(run)
    local list = {}
    for _, member in ipairs(run and run.members or {}) do
        if member.left then table.insert(list, member) end
    end
    table.sort(list, ByLeft)
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

local function ReadScore(unit)
    if not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then return nil end
    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
    if not ok or type(Clean(summary)) ~= "table" then return nil end
    return Clean(summary.currentSeasonScore)
end

Rapport.ReadScore = ReadScore

local function ReadSelf()
    local role = ReadRole("player")
    if not role and GetSpecialization and GetSpecializationRole then
        local spec = GetSpecialization()
        role = spec and GetSpecializationRole(spec) or nil
    end
    return { class = Clean((select(2, UnitClass("player")))), role = role, spec = ReadSpec("player") }
end

local function InParty()
    return IsInGroup() and not IsInRaid()
end

local function Fill(member, unit, frozen, rescore)
    member.class = member.class or Clean((select(2, UnitClass(unit))))
    if frozen then
        member.role = member.role or ReadRole(unit)
    else
        member.role = ReadRole(unit) or member.role
    end
    if rescore then
        member.score = ReadScore(unit) or member.score
    elseif member.score == nil then
        member.score = ReadScore(unit)
    end
    if member.spec == nil and (not member.respec or frozen) then member.spec = ReadSpec(unit) end
end

local function TrimLeft(members)
    local gone = {}
    for _, member in ipairs(members) do
        if member.left then table.insert(gone, member) end
    end
    if #gone <= LEFT_MAX then return end

    table.sort(gone, ByLeft)
    local drop = {}
    for index = LEFT_MAX + 1, #gone do
        drop[gone[index]] = true
        MPH.Debug("rapport: group, dropped %s (limit)", gone[index].name)
    end
    for index = #members, 1, -1 do
        if drop[members[index]] then table.remove(members, index) end
    end
end

local function ReadMembers(run, rescore)
    local frozen = Stage(run) == "active"
    local previous = {}
    for _, member in ipairs(run.members) do previous[member.name] = member end

    local members, missing, seen = {}, {}, {}
    local complete, count = true, 0
    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            count = count + 1
            local name = ReadName(unit)
            local member = name and previous[name]
            if not name then
                complete = false
                table.insert(missing, unit .. " name")
            elseif member or not frozen then
                if not member then
                    member = { name = name, joinedAt = time() }
                    MPH.Debug("rapport: group, joined %s", name)
                elseif member.left and not frozen then
                    member.left, member.leftAt = nil, nil
                    MPH.Debug("rapport: group, back %s", name)
                end
                seen[name] = true
                Fill(member, unit, frozen, rescore)
                if member.score == nil then table.insert(missing, unit .. " rating") end
                if member.spec == nil then table.insert(missing, unit .. " spec") end
                table.insert(members, member)
            end
        end
    end
    if count < GetNumGroupMembers() - 1 then complete = false end

    for _, member in ipairs(run.members) do
        if not seen[member.name] then
            if frozen or member.left or not complete then
                table.insert(members, member)
            elseif not member.carried and time() - (member.joinedAt or 0) < LEFT_MIN then
                MPH.Debug("rapport: group, dropped %s (short)", member.name)
            else
                member.left, member.leftAt = true, time()
                MPH.Debug("rapport: group, left %s", member.name)
                table.insert(members, member)
            end
        end
    end
    TrimLeft(members)
    return members, missing
end

local function SetWaiting(value)
    if waiting == value then return end
    waiting = value
    if value then
        events:RegisterEvent("UNIT_NAME_UPDATE")
        events:RegisterEvent("PARTY_MEMBER_ENABLE")
        events:RegisterEvent("UNIT_CONNECTION")
    else
        events:UnregisterEvent("UNIT_NAME_UPDATE")
        events:UnregisterEvent("PARTY_MEMBER_ENABLE")
        events:UnregisterEvent("UNIT_CONNECTION")
    end
end

local function InspectTargets()
    local wanted = {}
    for _, member in ipairs(Store().current.members) do
        if not member.left and member.spec == nil then wanted[member.name] = true end
    end
    local list = {}
    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            local name = ReadName(unit)
            if name and wanted[name] then table.insert(list, { unit = unit, name = name }) end
        end
    end
    return list
end

local function SetInspecting(value)
    if inspecting == value then return end
    inspecting = value
    if value then
        events:RegisterEvent("INSPECT_READY")
        events:RegisterEvent("UNIT_IN_RANGE_UPDATE")
    else
        events:UnregisterEvent("INSPECT_READY")
        events:UnregisterEvent("UNIT_IN_RANGE_UPDATE")
        inspectNote = nil
    end
end

local TryInspect

local function Hold(delay)
    inspectBusy = true
    inspectToken = inspectToken + 1
    local token = inspectToken
    C_Timer.After(delay, function ()
        if token ~= inspectToken then return end
        inspectBusy = false
        TryInspect("timer")
    end)
end

local function MutePvpFrame()
    if not InspectPVPFrame or INSPECTED_UNIT then return end
    InspectPVPFrame:UnregisterEvent("INSPECT_HONOR_UPDATE")
    pvpToken = pvpToken + 1
    local token = pvpToken
    C_Timer.After(PVP_MUTE, function ()
        if token ~= pvpToken then return end
        InspectPVPFrame:RegisterEvent("INSPECT_HONOR_UPDATE")
    end)
end

local function Note(text)
    if text == inspectNote then return end
    inspectNote = text
    MPH.Debug("rapport: inspect waiting, %s", text)
end

function TryInspect(reason)
    local targets = InspectTargets()
    if #targets == 0 or Stage(Store().current) == "saved" then
        if inspecting then
            MPH.Debug("rapport: inspect stopped, %s", #targets == 0 and "done" or "saved")
        end
        SetInspecting(false)
        return
    end
    SetInspecting(true)
    if inspectBusy or not CanInspect or not NotifyInspect then return end
    if InspectFrame and InspectFrame:IsShown() then return Note("inspect frame open") end
    if IsEncounterInProgress() then return Note("encounter") end

    local now = GetTime()
    local far, wait = {}, nil
    for _, target in ipairs(targets) do
        local rest = INSPECT_COOLDOWN - (now - (inspectAt[target.name] or -INSPECT_COOLDOWN))
        if rest > 0 then
            wait = math.min(wait or rest, rest)
        else
            local ok, can = pcall(CanInspect, target.unit)
            if ok and can then
                MutePvpFrame()
                local sent, err = pcall(NotifyInspect, target.unit)
                inspectAt[target.name] = now
                inspectGUID = Clean(UnitGUID(target.unit))
                inspectNote = nil
                Hold(INSPECT_TIMEOUT)
                MPH.Debug("rapport: inspect %s %s (%s)", target.name,
                    sent and "requested" or ("failed " .. tostring(err)), reason)
                return
            end
            table.insert(far, target.name)
        end
    end
    Note(#far > 0 and table.concat(far, ", ") or "cooldown")
    if wait then Hold(wait) end
end

local function InstanceZone()
    local name, instanceType, difficultyID = GetInstanceInfo()
    name, instanceType, difficultyID = Clean(name), Clean(instanceType), Clean(difficultyID)
    local keystone = instanceType == "party" and difficultyID == DIFFICULTY_KEYSTONE
    return MPH.NotEmpty(name) and name or nil, keystone
end

local function SlottedKeystone()
    if not C_ChallengeMode.GetSlottedKeystoneInfo then return nil end
    local ok, mapID, _, level = pcall(C_ChallengeMode.GetSlottedKeystoneInfo)
    if not ok then return nil end
    mapID, level = Clean(mapID), Clean(level)
    if not mapID or mapID == 0 then return nil end
    return mapID, level or 0
end

local function Scene()
    local zone, keystone = InstanceZone()

    if C_ChallengeMode.IsChallengeModeActive and Clean(C_ChallengeMode.IsChallengeModeActive()) then
        local mapID = Clean(C_ChallengeMode.GetActiveChallengeMapID())
        local level = Clean((C_ChallengeMode.GetActiveKeystoneInfo()))
        if not mapID or not level or level == 0 then return "active", nil, nil, zone end
        return "active", mapID, level, zone
    end

    if not keystone then return nil end

    local mapID, level = SlottedKeystone()
    if not mapID then mapID = MPH.FindChallengeMapByName(zone) end
    return "gather", mapID or 0, level or 0, zone
end

local function SameDungeon(run, mapID, zone)
    if mapID and mapID > 0 and (run.mapID or 0) > 0 then return run.mapID == mapID end
    return MPH.NotEmpty(zone) and run.zone == zone
end

local TickScores
local Abandon

local function ApplyScore(name, score)
    local store = Store()
    local run = store.current
    for _, member in ipairs(run.members) do
        if member.name == name then member.score = score end
    end
    local saved = store.history[1]
    if saved and saved.startedAt == (run.pendingRun or run.startedAt) then
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
    Store().current.pendingRun = nil
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
        store.current.pendingRun = nil
        return
    end

    local saved = store.history[1]
    local endedAt = saved and saved.startedAt == (store.current.pendingRun or store.current.startedAt) and saved.endedAt or 0
    if time() - endedAt > SCORE_WINDOW then
        StopScores("stale")
        return
    end

    scoreAttempts = 0
    events:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    PollScores(reason)
end

local function NewRun(stage)
    local store = Store()
    local old = store.current
    store.current = { stage = stage, mapID = 0, level = 0, startedAt = time(), openedAt = time(), members = {},
        pending = old.pending, pendingRun = old.pendingRun }
end

local function Save(reason, stage, mapID, level, zone, keep, carry)
    if not keep then NewRun(stage) end
    local run = Store().current
    run.left = nil
    run.seenAt = time()
    if MPH.NotEmpty(zone) then run.zone = zone end
    if mapID and mapID > 0 then run.mapID = mapID end
    if level and level > 0 then run.level = level end
    local starting = stage == "active" and not run.active
    if not run.active and stage ~= "active" then run.stage = stage end
    if starting or not run.self then run.self = ReadSelf() end

    local members, missing = ReadMembers(run, starting)
    run.members = members
    if carry then
        for _, member in ipairs(members) do member.carried = true end
    end
    if starting then
        run.active = true
        run.stage = "active"
        run.startedAt = time()
        MPH.Debug("rapport: frozen at start, members %d, left %d", #Rapport.Members(run), #Rapport.Left(run))
    end

    local trace = string.format("%s, map %s level %s, zone %s, self %s/%s, members %d, left %d, missing %s",
        stage, tostring(run.mapID), tostring(run.level), tostring(run.zone), tostring(run.self.class),
        tostring(run.self.role), #Rapport.Members(run), #Rapport.Left(run),
        #missing > 0 and table.concat(missing, ", ") or "none")
    if trace ~= lastTrace or not QUIET[reason] then
        MPH.Debug("rapport: %s, %s%s", reason, keep and "" or "new run, ", trace)
        lastTrace = trace
    end
    SetWaiting(#missing > 0)
    TryInspect(reason)
    Refresh()
end

local function Stop(reason)
    if not waiting then return end
    MPH.Debug("rapport: %s, stop waiting, members %d", reason, #Store().current.members)
    SetWaiting(false)
end

local function GroupScene()
    local dungeon = MPH.Teleport and MPH.Teleport.GroupDungeon and MPH.Teleport.GroupDungeon()
    return "group", dungeon and dungeon.cmID or 0, 0, nil
end

local function Reopen(run)
    Abandon(run, "reopen")
    run.active, run.stage = nil, "group"
    run.mapID, run.level, run.zone = 0, 0, nil
    run.startedAt = time()
    for _, member in ipairs(run.members) do member.carried = true end
    MPH.Debug("rapport: key not finished, gathering again, members %d", #run.members)
end

local function Start(reason)
    local stage, mapID, level, zone = Scene()
    if not stage then
        if not InParty() then
            if reason == "retry" then
                Stop("no group")
            elseif not QUIET[reason] and reason ~= "resume" and reason ~= "enter" then
                MPH.Debug("rapport: %s, no dungeon", reason)
            end
            return
        end
        stage, mapID, level, zone = GroupScene()
    end
    if stage == "active" and not mapID then
        MPH.Debug("rapport: %s, active, map not ready", reason)
        events:RegisterEvent("WORLD_STATE_TIMER_START")
        return
    end
    events:UnregisterEvent("WORLD_STATE_TIMER_START")

    local run = Store().current
    local now = Stage(run)
    if now == "saved" and not run.left
        and (stage == "group" or stage == "gather" and SameDungeon(run, mapID, zone)) then
        if not QUIET[reason] then MPH.Debug("rapport: %s, run here already saved", reason) end
        return
    end
    local stale = time() - (run.seenAt or run.startedAt or 0) > RUN_STALE
    if now == "active" and stage == "group" then
        if reason ~= "roster" then return end
        if not stale then
            Reopen(run)
            now = Stage(run)
        end
    end

    local keep = now ~= "saved" and not run.closed and (run.startedAt or 0) > 0
        and (now == "active" and SameDungeon(run, mapID, zone) or now ~= "active" and not stale)
    local carry = not keep and now == "saved" and stage == "group" and reason ~= "roster"
    if not keep and now == "active" then Abandon(run, stale and "stale" or "new key") end
    Save(reason, stage, mapID, level, zone, keep, carry)
end

local function Close()
    local run = Store().current
    local now = Stage(run)
    if now == "active" then
        Abandon(run, "left group")
        run.saved = true
    elseif (now == "group" or now == "gather") and not run.closed and (run.startedAt or 0) > 0 then
        run.closed = true
        MPH.Debug("rapport: group closed, members %d, left %d", #Rapport.Members(run), #Rapport.Left(run))
        Refresh()
    end
    TryInspect("closed")
end

local function Flush(reason)
    if reason == "roster" and not InParty() then return Close() end
    Start(reason)
end

local function Queue(reason)
    if queued then
        if reason == "roster" then queued = reason end
        return
    end
    queued = reason
    C_Timer.After(QUEUE_DELAY, function ()
        local reason = queued
        queued = nil
        Flush(reason)
    end)
end

local function OnInspectReady(guid)
    guid = Clean(guid)
    local ours = guid ~= nil and guid == inspectGUID
    if ours then inspectGUID = nil end
    for _, unit in ipairs(guid and UNITS or {}) do
        if UnitExists(unit) and Clean(UnitGUID(unit)) == guid then
            local name = ReadName(unit)
            for _, member in ipairs(Store().current.members) do
                if member.name == name then member.respec = nil end
            end
        end
    end
    Start("inspect")
    if ours then Hold(INSPECT_GAP) end
end

local function OnSpecChanged(unit)
    if IsSecret(unit) then return end
    local run = Store().current
    if run.active or run.saved or (run.startedAt or 0) == 0 then return end
    if unit == "player" then
        run.self = ReadSelf()
        MPH.Debug("rapport: spec changed, self %s/%s", tostring(run.self.spec), tostring(run.self.role))
        Refresh()
        return
    end
    if not PARTY_UNITS[unit] then return end
    local name = ReadName(unit)
    for _, member in ipairs(run.members) do
        if member.name == name and not member.left then
            member.spec, member.respec = nil, true
            inspectAt[name] = nil
            MPH.Debug("rapport: spec changed, %s", name)
            Refresh()
            TryInspect("spec")
            return
        end
    end
end

local function Archive(run, onTime, unfinished)
    local store = Store()
    local entry = {
        mapID = run.mapID,
        level = run.level,
        startedAt = run.startedAt,
        endedAt = time(),
        onTime = onTime,
        unfinished = unfinished or nil,
        self = Copy(run.self),
        members = {},
    }
    local pending = {}
    for _, member in ipairs(run.members) do
        table.insert(entry.members, Copy(member))
        if not member.left then pending[member.name] = member.score or SCORE_UNKNOWN end
        local rated = not member.left and Entry(member.name)
        if rated then
            if rated.scoreAt and rated.scoreAt < (run.openedAt or run.startedAt or 0) then
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
    return entry, pending
end

function Abandon(run, reason)
    if not run.active or run.saved or (run.startedAt or 0) == 0 then return end
    local entry = Archive(run, false, true)
    MPH.Debug("rapport: unfinished (%s), map %s level %s, members %d, left %d, history %d", reason,
        tostring(entry.mapID), tostring(entry.level), #Rapport.Members(entry), #Rapport.Left(entry),
        #Store().history)
    Refresh()
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

    local entry, pending = Archive(run, info and info.onTime and true or false)
    StopScores("next key")
    run.saved = true
    run.pending = pending
    run.pendingRun = entry.startedAt
    TryInspect("saved")

    MPH.Debug("rapport: saved, map %s level %s, onTime %s (info %s), members %d, left %d, history %d",
        tostring(entry.mapID), tostring(entry.level), tostring(entry.onTime), tostring(info ~= nil),
        #Rapport.Members(entry), #Rapport.Left(entry), #store.history)
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
    local stage, mapID, level, zone = Scene()
    return string.format("stage %s (map %s level %s, zone %s), party %s, run %s map %s level %s closed %s, "
        .. "members %d, left %d, history %d, waiting %s, inspect %s/%d, rated %d, pending %d",
        tostring(stage), tostring(mapID), tostring(level), tostring(zone), tostring(InParty()), Stage(run),
        tostring(run.mapID), tostring(run.level), tostring(run.closed), #Rapport.Members(run),
        #Rapport.Left(run), #store.history, tostring(waiting), tostring(inspecting), #InspectTargets(),
        rated, pending)
end

events:SetScript("OnEvent", function (_, event, ...)
    if event == "CHALLENGE_MODE_START" then
        Start("start")
    elseif event == "CHALLENGE_MODE_KEYSTONE_SLOTTED" then
        Start("keystone")
    elseif event == "WORLD_STATE_TIMER_START" then
        Start("timer")
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        Stop("completed")
        Complete()
    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
        PollScores("maps update")
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        local inside = Scene() ~= nil
        if not inside then Store().current.left = true end
        if isLogin or isReload then
            Start("resume")
            StartScores("resume")
        else
            Start("enter")
            if not inside then
                if not InParty() then Stop("left dungeon") end
                PollScores("left dungeon")
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        Queue("roster")
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        OnSpecChanged(...)
    elseif event == "INSPECT_READY" then
        OnInspectReady(...)
    elseif event == "UNIT_IN_RANGE_UPDATE" then
        local unit, inRange = ...
        if IsSecret(unit) or not PARTY_UNITS[unit] then return end
        if IsSecret(inRange) or inRange then TryInspect("range") end
    elseif waiting then
        Queue("retry")
    end
end)

function Rapport.Reset()
    StopScores("reset")
    local store = Store()
    store.current = { mapID = 0, level = 0, startedAt = 0, openedAt = 0, members = {} }
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
    events:RegisterEvent("CHALLENGE_MODE_KEYSTONE_SLOTTED")
    events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end)
