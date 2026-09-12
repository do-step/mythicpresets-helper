local ADDON, MPH = ...
local L = MPH.L

local ICON_SIZE = 40
local STATUS_ICON_SIZE = 14
local LABEL_HEIGHT = 16
local ROW_GAP = 14
local ROW_COUNT = 2
local BOTTOM_MARGIN = 12
local GCD_THRESHOLD = 2
local TICK = 1
local TOY_ID = 253629

local IsSecret = issecretvalue or function () return false end

MPH.TeleportPage = {}

local page
local rows = {}
local allRows = {}
local toyRow
local stoneRow
local PlaceButtons

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

local function Remaining(start, duration)
    if not start or not duration or IsSecret(start) or IsSecret(duration) then return 0 end
    if duration <= GCD_THRESHOLD then return 0 end

    return math.max(0, start + duration - GetTime())
end

local function GetSpellRemaining(spellID)
    local cooldown = C_Spell.GetSpellCooldown(spellID)
    if not cooldown then return 0 end
    return Remaining(cooldown.startTime, cooldown.duration)
end

local function GetItemRemaining(itemID)
    local start, duration = C_Container.GetItemCooldown(itemID)
    return Remaining(start, duration)
end

local function FormatRemaining(seconds)
    return SecondsToTime(seconds, seconds >= 60, false, 2)
end

local function StatusText(remaining, destination)
    local status
    if remaining > 0 then
        status = ORANGE_FONT_COLOR:WrapTextInColorCode(string.format(L["teleport.cooldown"], FormatRemaining(remaining)))
    else
        status = GREEN_FONT_COLOR:WrapTextInColorCode(L["teleport.ready"])
    end

    if destination and destination ~= "" then
        status = string.format(L["teleport.destination"], status, destination)
    end
    return status
end

local function LayoutName(row, known)
    row.Name:ClearAllPoints()
    if known then
        row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 10, 0)
        row.Name:SetPoint("RIGHT", row.Hit, "RIGHT", -4, 0)
    else
        row.Name:SetPoint("BOTTOMLEFT", row.Icon, "RIGHT", 10, 1)
        row.Name:SetPoint("BOTTOMRIGHT", row.Hit, "RIGHT", -4, 1)
    end
    row.Unknown:SetShown(not known)
end

local function UpdateRow(row)
    local known = IsPlayerSpell(row.dungeon.teleport)
    if row.known ~= known then
        row.known = known
        LayoutName(row, known)
    end

    row.Icon:SetDesaturated(not known)
    if known then
        row.Name:SetTextColor(1, 0.82, 0)
    else
        row.Name:SetTextColor(0.6, 0.6, 0.6)
    end
    return known
end

local function UpdateToy()
    local owned = PlayerHasToy(TOY_ID)
    toyRow.Icon:SetDesaturated(not owned)
    if not owned then
        toyRow.Name:SetTextColor(0.6, 0.6, 0.6)
        toyRow.Unknown:SetText(L["teleport.toymissing"])
        toyRow.Unknown:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        return
    end

    toyRow.Name:SetTextColor(1, 0.82, 0)
    toyRow.Unknown:SetText(StatusText(GetItemRemaining(TOY_ID), L["teleport.toyplace"]))
    toyRow.Unknown:SetTextColor(0.8, 0.8, 0.8)
end

local function SetStoneName(id)
    local name = C_Item.GetItemNameByID(id)
    if name then
        stoneRow.Name:SetText(name)
        return
    end

    stoneRow.Name:SetText("")
    Item:CreateFromItemID(id):ContinueOnItemLoad(function ()
        if stoneRow.stoneID == id then
            stoneRow.Name:SetText(C_Item.GetItemNameByID(id))
        end
    end)
end

local function UpdateStone()
    local id, isToy, count = MPH.Hearthstone.Get()
    stoneRow.stoneCount = count or 0
    if id ~= stoneRow.stoneID or isToy ~= stoneRow.stoneToy then
        stoneRow.stoneID = id
        stoneRow.stoneToy = isToy
        stoneRow.Icon:SetTexture(C_Item.GetItemIconByID(id or MPH.Hearthstone.ITEM))
        if id then
            SetStoneName(id)
        else
            stoneRow.Name:SetText(L["teleport.nostone"])
        end
        PlaceButtons()
    end

    stoneRow.Icon:SetDesaturated(not id)
    if not id then
        stoneRow.Name:SetTextColor(0.6, 0.6, 0.6)
        stoneRow.Unknown:SetText(L["teleport.nostonedesc"])
        stoneRow.Unknown:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        return
    end

    stoneRow.Name:SetTextColor(1, 0.82, 0)
    stoneRow.Unknown:SetText(StatusText(GetItemRemaining(id), GetBindLocation()))
    stoneRow.Unknown:SetTextColor(0.8, 0.8, 0.8)
end

local function UpdateState()
    if not page then return end

    UpdateToy()
    UpdateStone()

    local spellID
    for _, row in ipairs(rows) do
        if row.dungeon and UpdateRow(row) and not spellID then
            spellID = row.dungeon.teleport
        end
    end

    page.StatusIcon:SetShown(spellID ~= nil)
    page.Status:SetShown(spellID ~= nil)
    if not spellID then
        page.StatusHit:Hide()
        return
    end

    local remaining = GetSpellRemaining(spellID)
    if remaining > 0 then
        page.Status:SetText(string.format(L["teleport.cooldown"], FormatRemaining(remaining)))
        page.Status:SetTextColor(ORANGE_FONT_COLOR:GetRGB())
        page.StatusHit:SetWidth(STATUS_ICON_SIZE + 6 + page.Status:GetStringWidth())
        page.StatusHit:Show()
    else
        page.Status:SetText(L["teleport.ready"])
        page.Status:SetTextColor(GREEN_FONT_COLOR:GetRGB())
        page.StatusHit:Hide()
    end
end

local function ShowTooltip(self)
    local row = self.row
    if not row or not (row.toy or row.dungeon or row.stoneID) then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if row.stone then
        if row.stoneToy then
            GameTooltip:SetToyByItemID(row.stoneID)
        else
            GameTooltip:SetItemByID(row.stoneID)
        end
        local random = MPH.Hearthstone.IsRandom()
        GameTooltip:AddLine(" ")
        if random and row.stoneCount > 1 then
            GameTooltip:AddLine(L["teleport.stonereroll"], GRAY_FONT_COLOR:GetRGB())
        end
        GameTooltip:AddLine(string.format(L["teleport.stonemode"],
            L[random and "teleport.stonerandom" or "teleport.stonestandard"]), GRAY_FONT_COLOR:GetRGB())
    elseif row.toy then
        GameTooltip:SetToyByItemID(row.toy)
        if not PlayerHasToy(row.toy) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["teleport.notoy"], 1, 0.3, 0.3, true)
        end
    else
        GameTooltip:SetSpellByID(row.dungeon.teleport)
        if not IsPlayerSpell(row.dungeon.teleport) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["teleport.notknown"], 1, 0.3, 0.3, true)
        end
    end
    GameTooltip:Show()
end

local function ShowStatusTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local r, g, b = GRAY_FONT_COLOR:GetRGB()
    GameTooltip:SetText(L["teleport.cdreset"], r, g, b, 1, true)
    GameTooltip:Show()
end

local function HideOwnedTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function EnsureButton(row)
    if row.button then return row.button end
    if InCombatLockdown() then return nil end

    local button = CreateFrame("Button", "MythicPresetsHelperTeleportButton" .. row.index, UIParent,
        "SecureActionButtonTemplate")
    button:SetFrameStrata("DIALOG")
    button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    if row.toy then
        button:SetAttribute("type", "toy")
        button:SetAttribute("toy", row.toy)
    elseif row.stone then
        button:SetScript("OnMouseUp", function (self, mouseButton)
            if InCombatLockdown() then return end
            if mouseButton == "MiddleButton" then
                MPH.Hearthstone.SetRandom(not MPH.Hearthstone.IsRandom())
            elseif mouseButton == "RightButton" then
                MPH.Hearthstone.Next()
            else
                return
            end
            UpdateStone()
            if GameTooltip:IsOwned(self) then ShowTooltip(self) end
        end)
    else
        button:SetAttribute("type", "spell")
    end
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()
    button.row = row
    row.button = button
    return button
end

local function HideButtons()
    for _, row in ipairs(allRows) do
        if row.button then
            row.button:Hide()
            row.button:ClearAllPoints()
        end
    end
end

function PlaceButtons()
    if InCombatLockdown() then return end
    for _, row in ipairs(allRows) do
        local button = (row.dungeon or row.toy or row.stoneID) and row:IsVisible() and EnsureButton(row)
        if button then
            button:ClearAllPoints()
            button:SetAllPoints(row.Hit)
            if row.dungeon then
                button:SetAttribute("spell", row.dungeon.teleport)
            elseif row.stone then
                button:SetAttribute("type", row.stoneToy and "toy" or "item")
                button:SetAttribute("toy", row.stoneToy and row.stoneID or nil)
                button:SetAttribute("item", not row.stoneToy and ("item:" .. row.stoneID) or nil)
            end
            button:Show()
        elseif row.button then
            row.button:Hide()
            row.button:ClearAllPoints()
        end
    end
end

function MPH.TeleportPage.Refresh()
    if not page then return end
    if not page:IsVisible() then
        for _, row in ipairs(rows) do row.dungeon = nil end
        PlaceButtons()
        return
    end

    local search, key, reason = MPH.Teleport.GetDungeons()
    local entries = {}
    if search then table.insert(entries, { dungeon = search, label = "teleport.search" }) end
    if key then table.insert(entries, { dungeon = key, label = "teleport.key" }) end

    for index, row in ipairs(rows) do
        local entry = entries[index]
        row.dungeon = entry and entry.dungeon
        row.known = nil
        row:SetShown(entry ~= nil)
        if entry then
            row.Label:SetText(L[entry.label])
            row.Icon:SetTexture(C_Spell.GetSpellTexture(entry.dungeon.teleport) or entry.dungeon.texture)
            row.Name:SetText(string.format("%s (%s)", entry.dungeon.name, entry.dungeon.code))
        end
    end

    page.Empty:SetShown(#entries == 0)
    if #entries == 0 then
        page.Empty:SetText(L[reason])
    else
        page.StatusIcon:ClearAllPoints()
        page.StatusIcon:SetPoint("TOPLEFT", rows[#entries], "BOTTOMLEFT", 2, -ROW_GAP)
    end
    UpdateState()
    PlaceButtons()
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, page)
    row.index = index
    row:SetHeight(LABEL_HEIGHT + ICON_SIZE)

    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.Label:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.Label:SetHeight(LABEL_HEIGHT)
    row.Label:SetJustifyH("LEFT")

    row.Hit = CreateFrame("Frame", nil, row)
    row.Hit:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -LABEL_HEIGHT)
    row.Hit:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.Hit:SetScript("OnHide", PlaceButtons)

    row.Icon = row.Hit:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.Icon:SetPoint("LEFT", row.Hit, "LEFT", 0, 0)
    row.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    MPH.SkinIcon(row.Icon, row.Hit)

    row.Name = row.Hit:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)

    row.Unknown = row.Hit:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Unknown:SetPoint("TOPLEFT", row.Icon, "RIGHT", 10, -3)
    row.Unknown:SetPoint("TOPRIGHT", row.Hit, "RIGHT", -4, -3)
    row.Unknown:SetJustifyH("LEFT")
    row.Unknown:SetText(L["teleport.unknown"])

    LayoutName(row, true)
    row:Hide()
    return row
end

local function BuildStoneRow()
    stoneRow = CreateRow(ROW_COUNT + 2)
    stoneRow.stone = true
    stoneRow.stoneID = false
    stoneRow.stoneCount = 0
    stoneRow:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 20, BOTTOM_MARGIN)
    stoneRow:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -20, BOTTOM_MARGIN)
    stoneRow.Label:SetText(L["teleport.stone"])
    stoneRow.Name:SetFontObject("GameFontNormal")
    stoneRow.Unknown:SetWordWrap(false)
    LayoutName(stoneRow, false)
    stoneRow:Show()
    table.insert(allRows, stoneRow)
end

local function BuildToyRow()
    toyRow = CreateRow(ROW_COUNT + 1)
    toyRow.toy = TOY_ID
    toyRow:SetPoint("BOTTOMLEFT", stoneRow, "TOPLEFT", 0, ROW_GAP)
    toyRow:SetPoint("BOTTOMRIGHT", stoneRow, "TOPRIGHT", 0, ROW_GAP)
    toyRow.Label:SetText(L["teleport.toy"])
    toyRow.Name:SetFontObject("GameFontNormal")
    toyRow.Icon:SetTexture(C_Item.GetItemIconByID(TOY_ID))
    LayoutName(toyRow, false)
    toyRow:Show()
    table.insert(allRows, toyRow)

    Item:CreateFromItemID(TOY_ID):ContinueOnItemLoad(function ()
        toyRow.Name:SetText(C_Item.GetItemNameByID(TOY_ID))
    end)
end

local function Build(container)
    page = container

    for index = 1, ROW_COUNT do
        local row = CreateRow(index)
        if index == 1 then
            row:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -44)
            row:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -44)
        else
            local previous = rows[index - 1]
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -ROW_GAP)
            row:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -ROW_GAP)
        end
        rows[index] = row
        allRows[index] = row
    end
    BuildStoneRow()
    BuildToyRow()

    page.StatusIcon = page:CreateTexture(nil, "ARTWORK")
    page.StatusIcon:SetSize(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    page.StatusIcon:SetPoint("TOPLEFT", rows[1], "BOTTOMLEFT", 2, -ROW_GAP)
    page.StatusIcon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
    page.StatusIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    MPH.SkinIcon(page.StatusIcon, page)

    page.Status = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.Status:SetPoint("LEFT", page.StatusIcon, "RIGHT", 6, 0)
    page.Status:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    page.Status:SetJustifyH("LEFT")
    page.Status:SetWordWrap(false)

    page.StatusHit = CreateFrame("Frame", nil, page)
    page.StatusHit:SetPoint("LEFT", page.StatusIcon, "LEFT", 0, 0)
    page.StatusHit:SetHeight(STATUS_ICON_SIZE + 4)
    page.StatusHit:EnableMouse(true)
    page.StatusHit:SetScript("OnEnter", ShowStatusTooltip)
    page.StatusHit:SetScript("OnLeave", GameTooltip_Hide)
    page.StatusHit:SetScript("OnHide", HideOwnedTooltip)
    page.StatusHit:Hide()

    page.Empty = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    page.Empty:SetPoint("CENTER", page, "CENTER", 0, 10)
    page.Empty:SetWidth(260)

    local elapsed = 0
    page:SetScript("OnUpdate", function (_, delta)
        elapsed = elapsed + delta
        if elapsed < TICK then return end
        elapsed = 0
        UpdateState()
    end)
    page:HookScript("OnShow", function ()
        MPH.Hearthstone.Next()
        MPH.TeleportPage.Refresh()
    end)
end

MPH.RegisterWindowPage({
    key = "teleport",
    order = 3,
    icon = "Interface\\Icons\\INV_12_Mage_Portal",
    title = L["tab.teleport"],
    build = Build,
    refresh = function ()
        MPH.TeleportPage.Refresh()
    end,
})

events:SetScript("OnEvent", function (_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        HideButtons()
    else
        PlaceButtons()
    end
end)
