local ADDON, MPH = ...
local L = MPH.L

MPH.Errors = {}

local Errors = MPH.Errors

local EVENTS = {
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
}

local IsSecret = issecretvalue or function () return false end

local hider = CreateFrame("Frame")
hider:Hide()

local events = CreateFrame("Frame")
local hooked = false
local originalParent
local inKey = false
local inEncounter = false
local suppressed = false
local hidden = 0
local reason

local function Config()
    return MPH.db.errors
end

local function InstanceType()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType or "none"
end

local function CurrentInstance()
    return (select(8, GetInstanceInfo()))
end

local function IsTrue(value)
    return not IsSecret(value) and value == true
end

local function IsKeyActive()
    if not C_ChallengeMode.IsChallengeModeActive then return false end
    return IsTrue(C_ChallengeMode.IsChallengeModeActive())
end

local function IsEncounterActive()
    local check = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress or IsEncounterInProgress
    return check ~= nil and IsTrue(check())
end

local function Hook()
    if hooked or not ScriptErrorsFrame or not ScriptErrorsFrame.DisplayMessageInternal then return end
    hooked = true
    originalParent = ScriptErrorsFrame:GetParent()
    hooksecurefunc(ScriptErrorsFrame, "DisplayMessageInternal", function ()
        if suppressed then hidden = hidden + 1 end
    end)
end

local function Update(source)
    local active = Config().enabled and (inKey or inEncounter) and hooked or false

    if active ~= suppressed then
        suppressed = active
        if active then
            ScriptErrorsFrame:SetParent(hider)
        else
            ScriptErrorsFrame:SetParent(originalParent or UIParent)
            if hidden > 0 then
                MPH.Print(reason == "raid" and L["errors.hiddenraid"] or L["errors.hiddenkey"], hidden)
            end
            hidden = 0
        end
    end
    if active then reason = inKey and "key" or "raid" end

    MPH.Debug("errors (%s): suppressed %s, key %s, encounter %s, api active %s, hidden %d",
        source, tostring(suppressed), tostring(inKey), tostring(inEncounter),
        tostring(IsKeyActive()), hidden)
end

local function Recalculate()
    local config = Config()
    local instanceType = InstanceType()
    if instanceType ~= "party" then config.completedInstance = nil end

    inKey = instanceType == "party" and IsKeyActive() and CurrentInstance() ~= config.completedInstance
    inEncounter = instanceType == "raid" and IsEncounterActive()
end

events:SetScript("OnEvent", function (_, event)
    local config = Config()
    if event == "CHALLENGE_MODE_START" then
        config.completedInstance = nil
        inKey = true
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        config.completedInstance = CurrentInstance()
        inKey = false
    elseif event == "CHALLENGE_MODE_RESET" then
        inKey = false
    elseif event == "ENCOUNTER_START" then
        inEncounter = InstanceType() == "raid"
    elseif event == "ENCOUNTER_END" then
        inEncounter = false
    else
        Recalculate()
    end
    Update(event)
end)

function Errors.Apply()
    if not MPH.db then return end
    Hook()
    if Config().enabled then
        for _, event in ipairs(EVENTS) do
            events:RegisterEvent(event)
        end
        Recalculate()
    else
        events:UnregisterAllEvents()
        inKey = false
        inEncounter = false
    end
    Update("apply")
end

function Errors.Describe()
    local config = Config()
    return string.format("enabled %s, hooked %s, suppressed %s, key %s (api %s, completed %s), encounter %s, hidden %d",
        tostring(config.enabled), tostring(hooked), tostring(suppressed), tostring(inKey),
        tostring(IsKeyActive()), tostring(config.completedInstance), tostring(inEncounter), hidden)
end

table.insert(MPH.onLogin, function ()
    Errors.Apply()
end)
