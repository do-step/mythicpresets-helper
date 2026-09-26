local ADDON, MPH = ...

local function ApplyPlaystyle(entry)
    local wanted = MPH.db.playstyle.value or 0
    local current = entry.generalPlaystyle
    if wanted == 0 or (current and current ~= Enum.LFGEntryGeneralPlaystyle.None) then
        MPH.Debug("playstyle: skipped, wanted %s, current %s", tostring(wanted), tostring(current))
        return
    end

    local ok, err = pcall(function ()
        LFGListEntryCreation_OnPlayStyleSelectedInternal(entry, wanted)
        entry.PlayStyleDropdown:GenerateMenu()
    end)
    MPH.Debug("playstyle: set %s, activity %s, %s", tostring(wanted), tostring(entry.selectedActivity),
        ok and "ok" or tostring(err))
end

local PARTY_UNITS = { "party1", "party2", "party3", "party4" }

local written = {}

local function GroupScore()
    local score = C_ChallengeMode.GetOverallDungeonScore and C_ChallengeMode.GetOverallDungeonScore()
    if not score then return 0, "own unknown" end
    score = math.floor(score)
    if not IsInGroup() then return score, "solo" end
    if IsInRaid() then return 0, "raid" end

    local lowest = score
    for _, unit in ipairs(PARTY_UNITS) do
        if UnitExists(unit) then
            local member = MPH.Rapport.ReadScore(unit)
            if not member then return 0, unit .. " unknown" end
            lowest = math.min(lowest, math.floor(member))
        end
    end
    return lowest, "group min"
end

local function OwnItemLevel()
    if IsInGroup() then return 0, "group" end
    local _, equipped = GetAverageItemLevel()
    return equipped and math.floor(equipped) or 0, "solo"
end

local function Fill(key, field, enabled, value, source)
    if not enabled then return "off" end
    if not field or not field:IsShown() then return "hidden" end
    local text = field.EditBox:GetText()
    if text ~= "" and text ~= written[key] then return "kept " .. text end

    local wanted = value > 0 and tostring(value) or ""
    if wanted == text then return "same " .. text .. " (" .. source .. ")" end
    local ok, err = pcall(function ()
        field.EditBox:SetText(wanted)
        if wanted == "" then field.CheckButton:SetChecked(false) end
    end)
    if not ok then return tostring(err) end
    written[key] = wanted ~= "" and wanted or nil
    return (wanted ~= "" and "set " .. wanted or "cleared") .. " (" .. source .. ")"
end

local function ApplyRequirements(entry)
    local settings = MPH.db.requirements
    local score = Fill("score", entry.MythicPlusRating, settings.score, GroupScore())
    local itemLevel = Fill("itemLevel", entry.ItemLevel, settings.itemLevel, OwnItemLevel())
    MPH.Debug("requirements: score %s, item level %s, activity %s", score, itemLevel,
        tostring(entry.selectedActivity))
end

local function Apply(entry)
    if LFGListEntryCreation_IsEditMode and LFGListEntryCreation_IsEditMode(entry) then
        MPH.Debug("listing: edit mode, skipped")
        return
    end
    ApplyPlaystyle(entry)
    ApplyRequirements(entry)
end

table.insert(MPH.onLogin, function ()
    if not LFGListEntryCreation_Show or not LFGListEntryCreation_OnPlayStyleSelectedInternal
        or not (Enum and Enum.LFGEntryGeneralPlaystyle) then
        MPH.Debug("playstyle: not hooked")
        return
    end
    hooksecurefunc("LFGListEntryCreation_Show", Apply)
end)
