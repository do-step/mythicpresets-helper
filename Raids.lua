local ADDON, MPH = ...

MPH.Raids = {}
local Raids = MPH.Raids

MPH.CLASS_ARMOR = {
    DEATHKNIGHT = "plate",
    PALADIN     = "plate",
    WARRIOR     = "plate",
    EVOKER      = "mail",
    HUNTER      = "mail",
    SHAMAN      = "mail",
    DEMONHUNTER = "leather",
    DRUID       = "leather",
    MONK        = "leather",
    ROGUE       = "leather",
    MAGE        = "cloth",
    PRIEST      = "cloth",
    WARLOCK     = "cloth",
}

MPH.RAID_MIN_OFFSET = 7

MPH.RAID_FORMATS = {
    { label = "2-2-6",  size = 10, armorMax = 2 },
    { label = "2-3-9",  size = 14, armorMax = 3 },
    { label = "2-4-14", size = 20, armorMax = 4 },
}

local raidNameCache = nil

function Raids.InvalidateRaid()
    raidNameCache = nil
end

local RAID_FILTER_CANDIDATES = { 5, 1, 6, 2, 4, 0 }

local function RaidFilterList()
    local candidates = {}

    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if panel and panel.categoryID == MPH.CATEGORY_RAIDS and panel.filters then
        table.insert(candidates, panel.filters)
    end
    for _, value in ipairs(RAID_FILTER_CANDIDATES) do
        table.insert(candidates, value)
    end
    return candidates
end

function Raids.GetCurrentRaidName()
    if raidNameCache then return raidNameCache end

    for _, filters in ipairs(RaidFilterList()) do
        local ok, groups = pcall(C_LFGList.GetAvailableActivityGroups,
            MPH.CATEGORY_RAIDS, filters)
        if ok and groups and #groups > 0 then
            local okName, name = pcall(C_LFGList.GetActivityGroupInfo, groups[1])
            if okName and name and name ~= "" then
                raidNameCache = name
                return name
            end
        end
    end
    return nil
end

function MPH.GetPlayerArmor()
    local _, class = UnitClass("player")
    return class and MPH.CLASS_ARMOR[class] or nil
end

table.insert(MPH.onLogin, function ()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", Raids.InvalidateRaid)
end)

function Raids.BuildAutoPresets()
    local armor = MPH.GetPlayerArmor()
    if not armor then return nil end

    local presets = {}
    for _, format in ipairs(MPH.RAID_FORMATS) do
        table.insert(presets, {
            kind = "raid",
            name = format.label,
            keyText = "",
            dungeons = {},
            raidSize = format.size,
            membersMin = format.size - MPH.RAID_MIN_OFFSET,
            armor = armor,
            armorMax = format.armorMax,
            auto = true,
            autoKind = "raid",
            autoLevel = format.size,
        })
    end
    return presets
end

function Raids.Summary(preset)
    return string.format(MPH.L["summary.raid"],
        preset.membersMin or 0, preset.armorMax or 0,
        MPH.L["armor." .. (preset.armor or "unknown")])
end

function Raids.BuildArmorExpression(preset)
    if not preset.armor or not preset.armorMax then return "" end
    return string.format("%s <= %d", preset.armor, preset.armorMax)
end

function Raids.BuildExpression(preset)
    local parts = {}
    if preset.membersMin then
        table.insert(parts, string.format("members >= %d", preset.membersMin))
    end
    local armor = Raids.BuildArmorExpression(preset)
    if armor ~= "" then table.insert(parts, armor) end
    return table.concat(parts, " and ")
end

function Raids.SyncPGFPanel(preset)
    local PGF = MPH.GetPGF()
    if not PGF or not PGF.Dialog then return false end

    local panel = PGF.Dialog.activePanel
    if not panel or panel.name ~= "raid" then return false end
    if not panel.state then return false end

    panel.state.members = panel.state.members or {}
    panel.state.members.act = true
    panel.state.members.min = tostring(preset.membersMin or "")
    panel.state.members.max = ""

    panel.state.expression = Raids.BuildArmorExpression(preset)

    panel:Init(panel.state)
    panel:TriggerFilterExpressionChange()
    return true
end
