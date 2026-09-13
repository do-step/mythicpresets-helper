local ADDON, MPH = ...
local L = MPH.L

MPH.Presets = {}
local Presets = MPH.Presets

function Presets.All()
    return MPH.db.presets
end

function Presets.Get(index)
    return MPH.db.presets[index]
end

function Presets.NewTemplate(kind)
    if kind == "raid" then
        local format = MPH.RAID_FORMATS[1]
        return {
            kind = "raid",
            name = "",
            keyText = "",
            dungeons = {},
            membersMin = format.size - MPH.RAID_MIN_OFFSET,
            armor = MPH.GetPlayerArmor(),
            armorMax = format.armorMax,
        }
    end
    return { name = "", keyText = "", dungeons = {} }
end

function Presets.Add(preset)
    table.insert(MPH.db.presets, preset)
    return #MPH.db.presets
end

function Presets.Save(index, preset)
    MPH.db.presets[index] = preset
end

function Presets.Copy(index)
    local source = MPH.db.presets[index]
    if not source then return nil end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    copy.dungeons = {}
    for _, cmID in ipairs(source.dungeons or {}) do
        table.insert(copy.dungeons, cmID)
    end
    copy.auto = nil
    copy.autoKind = nil
    copy.autoLevel = nil
    copy.listIndex = nil

    Presets.Add(copy)
    return copy
end

function Presets.Delete(index)
    local preset = MPH.db.presets[index]
    if not preset or preset.auto then return end
    table.remove(MPH.db.presets, index)
    if MPH.db.activePreset == index then
        MPH.db.activePreset = nil
    elseif MPH.db.activePreset and MPH.db.activePreset > index then
        MPH.db.activePreset = MPH.db.activePreset - 1
    end
end

function Presets.IsSelected(preset, cmID)
    for _, id in ipairs(preset.dungeons) do
        if id == cmID then return true end
    end
    return false
end

function Presets.Summary(preset)
    if MPH.GetPresetKind(preset) == "raid" then
        return MPH.Raids.Summary(preset)
    end

    local key = MPH.NotEmpty(preset.keyText) and ("+" .. preset.keyText) or L["summary.nokey"]
    local count = #preset.dungeons
    local season = MPH.GetSeasonDungeons()
    local dungeons
    if count == 0 or (#season > 0 and count >= #season) then
        dungeons = L["summary.alldungeon"]
    else
        dungeons = string.format(L["summary.dungeons"], count)
    end

    return "|cffffd100" .. key .. "|r  " .. dungeons
end

function Presets.SearchText(preset)
    if MPH.GetPresetKind(preset) == "raid" then
        return MPH.Raids.GetCurrentRaidName()
    end

    if not MPH.NotEmpty(preset.keyText) then return nil end

    local from = tonumber(preset.keyText)
    if not from then return preset.keyText end

    local ahead = math.max(0, math.min(MPH.MAX_KEY_AHEAD, tonumber(MPH.db.keyAhead) or 0))
    return string.format("%d-%d", from, from + ahead)
end

function Presets.Matches(preset, current)
    if not MPH.NotEmpty(current) then return false end

    local wanted = Presets.SearchText(preset)
    if MPH.GetPresetKind(preset) == "raid" then
        if not wanted then return true end
        return current:lower():find(wanted:lower(), 1, true) ~= nil
    end

    return current == preset.keyText or current == wanted
end

function Presets.BuildExpression(preset, ratingMin, ratingMax, fit)
    local parts = {}

    table.insert(parts, "mythicplus")

    if ratingMin then
        table.insert(parts, string.format("mprating >= %d and mprating <= %d", ratingMin, ratingMax))
    end

    if fit then
        table.insert(parts, "partyfit and blfit")
    end

    return table.concat(parts, " and ")
end

local function BaseAdvancedFilter()
    local filter = C_LFGList.GetAdvancedFilter()
    filter.needsTank = false
    filter.needsHealer = false
    filter.needsDamage = false
    filter.hasTank = false
    filter.hasHealer = false
    filter.minimumRating = 0
    filter.difficultyNormal = true
    filter.difficultyHeroic = true
    filter.difficultyMythic = true
    filter.difficultyMythicPlus = true
    filter.activities = {}
    return filter
end

function Presets.BuildAdvancedFilter(preset, ratingMin, fit)
    local filter = BaseAdvancedFilter()

    filter.difficultyNormal = false
    filter.difficultyHeroic = false
    filter.difficultyMythic = false
    filter.difficultyMythicPlus = true

    local activities = {}
    for _, cmID in ipairs(preset.dungeons) do
        local activityGroupID = MPH.GetActivityGroupID(cmID)
        if activityGroupID then table.insert(activities, activityGroupID) end
    end
    filter.activities = activities

    if ratingMin then filter.minimumRating = ratingMin end

    if fit then
        local roles = MPH.GetPartyRoles()
        filter.needsTank = roles.TANK > 0
        filter.needsHealer = roles.HEALER > 0
        filter.needsDamage = roles.DAMAGER > 0
    end

    return filter
end

local function SaveAdvancedFilter(filter, label)
    local ok, err = pcall(C_LFGList.SaveAdvancedFilter, filter)
    if not ok then
        MPH.Print("%s: %s", label, tostring(err))
    end
    return ok
end

local function ReadSearchBox(panel)
    if not panel.SearchBox then return nil end
    local ok, text = pcall(panel.SearchBox.GetText, panel.SearchBox)
    if not ok then return nil end
    if issecretvalue and issecretvalue(text) then return nil end
    return text
end

local function PGFDungeonPanel()
    local PGF = MPH.GetPGF()
    local panel = PGF and PGF.Dialog and PGF.Dialog.activePanel
    if not panel or panel.name ~= "dungeon" then return nil end
    if not panel.state or not panel.Dungeons then return nil end
    if not panel.cmIDs or #panel.cmIDs == 0 then return nil end
    return panel
end

local function WritePGFState(panel, selected, ratingMin, ratingMax, fit)
    local index = 1
    while panel.Dungeons["Dungeon" .. index] do
        local cmID = panel.cmIDs[index]
        panel.state["dungeon" .. index] = cmID ~= nil and selected[cmID] or false
        index = index + 1
    end

    panel.state.mprating = panel.state.mprating or {}
    panel.state.mprating.act = ratingMin ~= nil
    panel.state.mprating.min = ratingMin and tostring(ratingMin) or ""
    panel.state.mprating.max = ratingMax and tostring(ratingMax) or ""

    panel.state.partyfit = fit and true or false
    panel.state.blfit = fit and true or false
end

local function SyncPGFPanel(selected, ratingMin, ratingMax, fit)
    local panel = PGFDungeonPanel()
    if not panel then return false end

    WritePGFState(panel, selected, ratingMin, ratingMax, fit)
    panel.state.expression = ""

    panel:Init(panel.state)
    panel:TriggerFilterExpressionChange()
    return true
end

local function MirrorPGFState(selected, ratingMin, fit)
    local panel = PGFDungeonPanel()
    if panel then WritePGFState(panel, selected, ratingMin, nil, fit) end
end

local function UpdatePGFExpression(expression)
    local PGF = MPH.GetPGF()
    local active = PGF and PGF.Dialog and PGF.Dialog.activePanel
    if not active then return end
    local sorting = active.name == "mini" and "" or nil
    PGF.Dialog:UpdateExpression(expression, sorting)
end

local function ApplyDungeonFilters(preset)
    local selected = {}
    for _, cmID in ipairs(preset.dungeons) do selected[cmID] = true end

    local ratingMin, ratingMax = MPH.GetRatingRange()
    local fit = MPH.db.fit.enabled

    if MPH.UsesPGF() then
        if SyncPGFPanel(selected, ratingMin, ratingMax, fit) then return true end
        UpdatePGFExpression(Presets.BuildExpression(preset, ratingMin, ratingMax, fit))
    else
        MirrorPGFState(selected, ratingMin, fit)
    end

    return SaveAdvancedFilter(Presets.BuildAdvancedFilter(preset, ratingMin, fit), "filter")
end

local function ApplyRaidFilters(preset)
    if not MPH.UsesPGF() then return end
    if MPH.Raids.SyncPGFPanel(preset) then return end
    UpdatePGFExpression(MPH.Raids.BuildExpression(preset))
end

function Presets.Reset()
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel or not panel:IsVisible() then
        MPH.Print(L["msg.nopanel"])
        UIErrorsFrame:AddMessage(L["msg.nopanel"], 1.0, 0.3, 0.3)
        return false
    end

    MPH.db.activePreset = nil

    if MPH.UsesPGF() then
        if not SyncPGFPanel({}, nil, nil, false) then
            UpdatePGFExpression("")
            if not SaveAdvancedFilter(BaseAdvancedFilter(), "reset") then return false end
        end
    else
        MirrorPGFState({}, nil, false)
        if not SaveAdvancedFilter(BaseAdvancedFilter(), "reset") then return false end
    end

    local leftover = ReadSearchBox(panel)
    if MPH.NotEmpty(leftover) then
        MPH.Print(L["msg.clearsearchbox"], leftover)
    end

    pcall(LFGListSearchPanel_DoSearch, panel)
    if MPH.RefreshWindow then MPH.RefreshWindow() end
    return true
end

function Presets.Apply(preset, index, quiet)
    local panel = LFGListFrame and LFGListFrame.SearchPanel

    if not panel or not panel:IsVisible() then
        MPH.Print(L["msg.nopanel"])
        UIErrorsFrame:AddMessage(L["msg.nopanel"], 1.0, 0.3, 0.3)
        return false
    end

    if MPH.GetPresetKind(preset) == "raid" then
        ApplyRaidFilters(preset)

        local wanted = Presets.SearchText(preset)
        if wanted and not quiet then
            if not Presets.Matches(preset, ReadSearchBox(panel)) then
                if MPH.ShowCopyBox then MPH.ShowCopyBox(preset) end
            elseif MPH.HideCopyBox then
                MPH.HideCopyBox()
            end
        end

        MPH.db.activePreset = index
        local okRaid = pcall(LFGListSearchPanel_DoSearch, panel)
        if MPH.RefreshWindow then MPH.RefreshWindow() end
        return okRaid
    end

    if MPH.NotEmpty(preset.keyText) and not quiet then
        local current = ReadSearchBox(panel)
        local wanted = Presets.SearchText(preset)
        if not Presets.Matches(preset, current) then
            if MPH.ShowCopyBox then
                MPH.ShowCopyBox(preset)
            else
                MPH.Print(L["msg.typekey"], wanted)
            end
        elseif MPH.HideCopyBox then
            MPH.HideCopyBox()
        end
    end

    if not ApplyDungeonFilters(preset) then return false end

    MPH.db.activePreset = index
    local okSearch, searchErr = pcall(LFGListSearchPanel_DoSearch, panel)
    if not okSearch then
        MPH.Print("search: %s", tostring(searchErr))
    end

    if MPH.RefreshWindow then MPH.RefreshWindow() end
    return okSearch
end

function Presets.Reapply(quiet)
    local index = MPH.db.activePreset
    local preset = index and Presets.Get(index)
    if not preset or MPH.GetPresetKind(preset) ~= "mplus" then return false end
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel or not panel:IsVisible() then return false end
    return Presets.Apply(preset, index, quiet)
end

function Presets.PushToPGF()
    if not MPH.UsesPGF() then return end

    local index = MPH.db.activePreset
    local preset = index and Presets.Get(index)
    if not preset then return end

    local kind = MPH.GetPresetKind(preset)
    if kind ~= MPH.GetActiveKind() then return end

    if kind == "raid" then
        ApplyRaidFilters(preset)
    else
        ApplyDungeonFilters(preset)
    end
end
