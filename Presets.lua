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

function Presets.NewTemplate()
    return { name = "", keyText = "", dungeons = {} }
end

function Presets.Add(preset)
    table.insert(MPH.db.presets, preset)
    return #MPH.db.presets
end

function Presets.Save(index, preset)
    MPH.db.presets[index] = preset
end

function Presets.Delete(index)
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

function Presets.BuildExpression(preset, ratingMin, ratingMax)
    local parts = {}

    table.insert(parts, "mythicplus")

    if ratingMin then
        table.insert(parts, string.format("mprating >= %d and mprating <= %d", ratingMin, ratingMax))
    end

    return table.concat(parts, " and ")
end

function Presets.BuildAdvancedFilter(preset)
    local PGF = MPH.GetPGF()

    local filter = (PGF and PGF.GetAdvancedFilterDefaults and PGF.GetAdvancedFilterDefaults())
            or C_LFGList.GetAdvancedFilter()

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

    return filter
end

local function ReadSearchBox(panel)
    if not panel.SearchBox then return nil end
    local ok, text = pcall(panel.SearchBox.GetText, panel.SearchBox)
    if not ok then return nil end
    if issecretvalue and issecretvalue(text) then return nil end
    return text
end

local warnedAboutPGFDungeons = false

local function CheckPGFConflict()
    local PGF = MPH.GetPGF()
    if not PGF or not PGF.Dialog then return end

    local panel = PGF.Dialog.activePanel
    if panel and panel.name == "dungeon" and panel.GetNumDungeonsSelected
            and panel:GetNumDungeonsSelected() > 0 and not warnedAboutPGFDungeons then
        warnedAboutPGFDungeons = true
        MPH.Print(L["msg.pgfconflict"])
    end
end

local function SyncPGFPanel(selected, ratingMin, ratingMax)
    local PGF = MPH.GetPGF()
    if not PGF or not PGF.Dialog then return false end

    local panel = PGF.Dialog.activePanel
    if not panel or panel.name ~= "dungeon" then return false end
    if not panel.state or not panel.Dungeons then return false end
    if not panel.cmIDs or #panel.cmIDs == 0 then return false end

    local count = 0
    local index = 1
    while panel.Dungeons["Dungeon" .. index] do
        local cmID = panel.cmIDs[index]
        local checked = cmID ~= nil and selected[cmID] or false
        panel.state["dungeon" .. index] = checked
        if checked then count = count + 1 end
        index = index + 1
    end

    panel.state.expression = ""

    panel.state.mprating = panel.state.mprating or {}
    if ratingMin then
        panel.state.mprating.act = true
        panel.state.mprating.min = tostring(ratingMin)
        panel.state.mprating.max = tostring(ratingMax)
    else
        panel.state.mprating.act = false
        panel.state.mprating.min = ""
        panel.state.mprating.max = ""
    end

    panel:Init(panel.state)
    panel:TriggerFilterExpressionChange()
    return true
end

function Presets.Reset()
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel or not panel:IsVisible() then
        MPH.Print(L["msg.nopanel"])
        UIErrorsFrame:AddMessage(L["msg.nopanel"], 1.0, 0.3, 0.3)
        return false
    end

    MPH.db.activePreset = nil

    local PGF = MPH.GetPGF()
    if not SyncPGFPanel({}, nil, nil) then
        if PGF and PGF.Dialog and PGF.Dialog.activePanel then
            local sorting = PGF.Dialog.activePanel.name == "mini" and "" or nil
            PGF.Dialog:UpdateExpression("", sorting)
        end

        local filter = (PGF and PGF.GetAdvancedFilterDefaults and PGF.GetAdvancedFilterDefaults())
                or C_LFGList.GetAdvancedFilter()
        filter.difficultyNormal = true
        filter.difficultyHeroic = true
        filter.difficultyMythic = true
        filter.difficultyMythicPlus = true
        filter.activities = {}

        local ok, err = pcall(function ()
            if PGF and PGF.SetAdvancedFilter then
                PGF.SetAdvancedFilter(filter)
            else
                C_LFGList.SaveAdvancedFilter(filter)
            end
        end)
        if not ok then
            MPH.Print("reset: %s", tostring(err))
            return false
        end
    end

    local leftover = ReadSearchBox(panel)
    if MPH.NotEmpty(leftover) then
        MPH.Print(L["msg.clearsearchbox"], leftover)
    end

    pcall(LFGListSearchPanel_DoSearch, panel)
    if MPH.RefreshWindow then MPH.RefreshWindow() end
    return true
end

local function ApplyRaid(preset, panel)
    if not MPH.Raids.SyncPGFPanel(preset) then
        local PGF = MPH.GetPGF()
        if PGF and PGF.Dialog and PGF.Dialog.activePanel then
            local sorting = PGF.Dialog.activePanel.name == "mini" and "" or nil
            PGF.Dialog:UpdateExpression(MPH.Raids.BuildExpression(preset), sorting)
        end
    end
    return true
end

function Presets.Apply(preset, index)
    local panel = LFGListFrame and LFGListFrame.SearchPanel

    if not panel or not panel:IsVisible() then

        MPH.Print(L["msg.nopanel"])
        UIErrorsFrame:AddMessage(L["msg.nopanel"], 1.0, 0.3, 0.3)
        return false
    end

    if MPH.GetPresetKind(preset) == "raid" then
        ApplyRaid(preset, panel)

        local wanted = Presets.SearchText(preset)
        if wanted then
            if not Presets.Matches(preset, ReadSearchBox(panel)) then
                if MPH.ShowCopyBox then MPH.ShowCopyBox(preset) end
            elseif MPH.HideCopyBox then
                MPH.HideCopyBox()
            end
        end

        local okRaid = pcall(LFGListSearchPanel_DoSearch, panel)
        if not okRaid then return false end
        MPH.db.activePreset = index
        if MPH.RefreshWindow then MPH.RefreshWindow() end
        return true
    end

    if MPH.NotEmpty(preset.keyText) then
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

    local selected = {}
    for _, cmID in ipairs(preset.dungeons) do selected[cmID] = true end

    local ratingMin, ratingMax = MPH.GetRatingRange()

    local PGF = MPH.GetPGF()
    if not SyncPGFPanel(selected, ratingMin, ratingMax) then
        if PGF and PGF.Dialog and PGF.Dialog.activePanel then
            local expression = Presets.BuildExpression(preset, ratingMin, ratingMax)
            local sorting = PGF.Dialog.activePanel.name == "mini" and "" or nil
            PGF.Dialog:UpdateExpression(expression, sorting)
            CheckPGFConflict()
        else
        end

        local filter = Presets.BuildAdvancedFilter(preset)
        if ratingMin then filter.minimumRating = ratingMin end
        local okFilter, filterErr = pcall(function ()
            if PGF and PGF.SetAdvancedFilter then
                PGF.SetAdvancedFilter(filter)
            else
                C_LFGList.SaveAdvancedFilter(filter)
            end
        end)
        if not okFilter then
            MPH.Print("filter: %s", tostring(filterErr))
            return false
        end
    end

    local before = panel.totalResults
    local okSearch, searchErr = pcall(LFGListSearchPanel_DoSearch, panel)
    if not okSearch then
        MPH.Print("search: %s", tostring(searchErr))
        return false
    end

    MPH.db.activePreset = index
    if MPH.RefreshWindow then MPH.RefreshWindow() end
    return true
end
