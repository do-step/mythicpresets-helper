local ADDON, MPH = ...

MPH.Filter = {}
local Filter = MPH.Filter

local IsSecret = issecretvalue or function () return false end
local CanAccess = canaccesstable or function () return true end

local BLOODLUST_CLASSES = {
    SHAMAN = true,
    MAGE   = true,
    HUNTER = true,
    EVOKER = true,
}

local function Readable(value)
    return value ~= nil and not IsSecret(value)
end

local function ReadableTable(value)
    return Readable(value) and type(value) == "table" and CanAccess(value)
end

local function SpecRole()
    local spec = GetSpecialization and GetSpecialization()
    local role = spec and GetSpecializationRole and GetSpecializationRole(spec)
    if role == "TANK" or role == "HEALER" then return role end
    return "DAMAGER"
end

function MPH.GetPartyRoles()
    local roles = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    local bloodlust = false

    local function Add(unit, fallback)
        local role = UnitGroupRolesAssigned(unit)
        if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then role = fallback end
        roles[role] = roles[role] + 1
        local _, class = UnitClass(unit)
        if class and BLOODLUST_CLASSES[class] then bloodlust = true end
    end

    Add("player", SpecRole())
    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            Add("party" .. i, "DAMAGER")
        end
    end
    return roles, bloodlust
end

local function ScanMembers(resultID, numMembers, armor)
    local armorCount, bloodlust = 0, false
    for i = 1, numMembers do
        local ok, info = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
        if not ok or not ReadableTable(info) then return nil end
        local class = info.classFilename
        if not Readable(class) then return nil end
        if armor and MPH.CLASS_ARMOR[class] == armor then armorCount = armorCount + 1 end
        if BLOODLUST_CLASSES[class] then bloodlust = true end
    end
    return armorCount, bloodlust
end

local function FitsRaid(resultID, info, preset)
    local numMembers = info.numMembers
    if not Readable(numMembers) then return true end
    if preset.membersMin and numMembers < preset.membersMin then return false end
    if not preset.armor or not preset.armorMax then return true end

    local armorCount = ScanMembers(resultID, numMembers, preset.armor)
    return armorCount == nil or armorCount <= preset.armorMax
end

local function FitsParty(resultID, info, party)
    local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
    if not ok or not ReadableTable(counts) then return true end

    local tanks, healers, damagers = counts.TANK_REMAINING, counts.HEALER_REMAINING, counts.DAMAGER_REMAINING
    if not Readable(tanks) or not Readable(healers) or not Readable(damagers) then return true end
    if tanks < party.roles.TANK or healers < party.roles.HEALER or damagers < party.roles.DAMAGER then
        return false
    end

    if party.bloodlust then return true end
    if healers - party.roles.HEALER + damagers - party.roles.DAMAGER > 0 then return true end

    local numMembers = info.numMembers
    if not Readable(numMembers) then return true end
    local _, bloodlust = ScanMembers(resultID, numMembers)
    return bloodlust ~= false
end

local function Keeps(resultID, preset, kind, ratingMax, party)
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if not ok or not ReadableTable(info) then return true end

    if kind == "raid" then return FitsRaid(resultID, info, preset) end

    if ratingMax then
        local score = info.leaderOverallDungeonScore
        if Readable(score) and score > ratingMax then return false end
    end

    if party then return FitsParty(resultID, info, party) end
    return true
end

local function ActivePreset(categoryID)
    local index = MPH.db and MPH.db.activePreset
    local preset = index and MPH.Presets.Get(index)
    if not preset then return nil end

    local kind = MPH.GetPresetKind(preset)
    local wanted = kind == "raid" and MPH.CATEGORY_RAIDS or MPH.CATEGORY_DUNGEONS
    if categoryID ~= wanted then return nil end
    return preset, kind
end

local function DisplayedCount(results, applications)
    local count = #results
    if not ReadableTable(applications) then return count end

    local listed = {}
    for _, resultID in ipairs(results) do listed[resultID] = true end
    for _, resultID in ipairs(applications) do
        if not listed[resultID] then count = count + 1 end
    end
    return count
end

local function Publish(stats)
    MPH.filterStats = stats
    if MPH.UpdateResetButton then MPH.UpdateResetButton() end
end

function Filter.OnResultList(panel)
    if MPH.UsesPGF() then return Publish(nil) end

    local results = panel.results
    if not ReadableTable(results) or #results == 0 then return Publish(nil) end

    local preset, kind = ActivePreset(panel.categoryID)
    if not preset then return Publish(nil) end

    local ratingMax, party
    if kind == "mplus" then
        ratingMax = select(2, MPH.GetRatingRange())
        if MPH.db.fit.enabled then
            local roles, bloodlust = MPH.GetPartyRoles()
            party = { roles = roles, bloodlust = bloodlust }
        end
        if not ratingMax and not party then return Publish(nil) end
    end

    local kept = {}
    for _, resultID in ipairs(results) do
        if Keeps(resultID, preset, kind, ratingMax, party) then
            table.insert(kept, resultID)
        end
    end

    MPH.Debug("filter: %d -> %d", #results, #kept)
    if #kept < #results then
        panel.results = kept
        panel.totalResults = DisplayedCount(kept, panel.applications)
        LFGListSearchPanel_UpdateResults(panel)
    end
    Publish({ total = #results, shown = #kept })
end

local lastParty

local function PartySignature()
    local roles, bloodlust = MPH.GetPartyRoles()
    return string.format("%d-%d-%d-%s", roles.TANK, roles.HEALER, roles.DAMAGER, tostring(bloodlust))
end

table.insert(MPH.onLogin, function ()
    if LFGListSearchPanel_UpdateResultList then
        hooksecurefunc("LFGListSearchPanel_UpdateResultList", Filter.OnResultList)
    end

    local PGF = MPH.GetPGF()
    if PGF and PGF.Dialog and PGF.Dialog.SetEnabled then
        hooksecurefunc(PGF.Dialog, "SetEnabled", function ()
            Publish(nil)
            MPH.Presets.PushToPGF()
        end)
    end

    lastParty = PartySignature()
    local events = CreateFrame("Frame")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    events:SetScript("OnEvent", function ()
        local signature = PartySignature()
        if signature == lastParty then return end
        lastParty = signature
        if MPH.db.fit.enabled then MPH.Presets.Reapply(true) end
    end)
end)
