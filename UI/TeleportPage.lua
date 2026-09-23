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
local LOADING_ALPHA = 0.4
local FADE_DURATION = 0.3
local RANDOM_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local LIST_WIDTH = 240
local LIST_ENTRY_HEIGHT = 18
local LIST_MAX_ENTRIES = 15
local LIST_PADDING = 8
local LIST_TITLE_HEIGHT = 14
local LIST_SCROLLBAR_WIDTH = 28
local LIST_HIDE_DELAY = 0.3

local IsSecret = issecretvalue or function () return false end

MPH.TeleportPage = {}

local page
local rows = {}
local allRows = {}
local stoneRow
local travelRow
local missingList
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

local function ModeText(random, standardKey)
    local standard = random and GRAY_FONT_COLOR or NORMAL_FONT_COLOR
    local shuffled = random and NORMAL_FONT_COLOR or GRAY_FONT_COLOR
    return string.format("%s / %s",
        standard:WrapTextInColorCode(L[standardKey]),
        shuffled:WrapTextInColorCode(L["teleport.stonerandom"]))
end

local function PaintPanel(frame)
    local colors = MPH.GetSideTabColors()
    frame.Border:SetColorTexture(unpack(colors.border))
    frame.Background:SetColorTexture(unpack(colors.background))
end

local function MissingEntry(index)
    local entry = missingList.entries[index]
    if entry then return entry end

    entry = CreateFrame("Button", nil, missingList.Content)
    entry:SetHeight(LIST_ENTRY_HEIGHT)
    entry:SetPoint("TOPLEFT", missingList.Content, "TOPLEFT", 0, -(index - 1) * LIST_ENTRY_HEIGHT)
    entry:SetPoint("TOPRIGHT", missingList.Content, "TOPRIGHT", 0, -(index - 1) * LIST_ENTRY_HEIGHT)

    entry.Icon = entry:CreateTexture(nil, "ARTWORK")
    entry.Icon:SetSize(LIST_ENTRY_HEIGHT - 2, LIST_ENTRY_HEIGHT - 2)
    entry.Icon:SetPoint("LEFT", entry, "LEFT", 0, 0)
    entry.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    MPH.SkinIcon(entry.Icon, entry)

    entry.Name = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    entry.Name:SetPoint("LEFT", entry.Icon, "RIGHT", 6, 0)
    entry.Name:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
    entry.Name:SetJustifyH("LEFT")
    entry.Name:SetWordWrap(false)

    entry:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    entry:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetToyByItemID(self.id)
        GameTooltip:Show()
    end)
    entry:SetScript("OnLeave", GameTooltip_Hide)
    missingList.entries[index] = entry
    return entry
end

local function SetEntryToy(entry, id)
    entry.id = id
    entry.Icon:SetTexture(C_Item.GetItemIconByID(id))
    local name = C_Item.GetItemNameByID(id)
    entry.Name:SetText(name or "")
    if name then return end
    Item:CreateFromItemID(id):ContinueOnItemLoad(function ()
        if entry.id == id then entry.Name:SetText(C_Item.GetItemNameByID(id)) end
    end)
end

local function BuildMissingList()
    missingList = CreateFrame("Frame", "MythicPresetsHelperMissingList", UIParent)
    missingList:SetFrameStrata("FULLSCREEN_DIALOG")
    missingList:SetClampedToScreen(true)
    missingList:EnableMouse(true)
    missingList:SetWidth(LIST_WIDTH)

    missingList.Border = missingList:CreateTexture(nil, "BACKGROUND")
    missingList.Border:SetAllPoints()
    missingList.Background = missingList:CreateTexture(nil, "BACKGROUND", nil, 1)
    missingList.Background:SetPoint("TOPLEFT", 1, -1)
    missingList.Background:SetPoint("BOTTOMRIGHT", -1, 1)

    missingList.Title = missingList:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    missingList.Title:SetPoint("TOPLEFT", missingList, "TOPLEFT", LIST_PADDING, -LIST_PADDING)
    missingList.Title:SetPoint("TOPRIGHT", missingList, "TOPRIGHT", -LIST_PADDING, -LIST_PADDING)
    missingList.Title:SetHeight(LIST_TITLE_HEIGHT)
    missingList.Title:SetJustifyH("LEFT")

    missingList.Scroll = CreateFrame("ScrollFrame", "MythicPresetsHelperMissingScrollFrame", missingList, "ScrollFrameTemplate")
    missingList.Scroll:SetPoint("TOPLEFT", missingList.Title, "BOTTOMLEFT", 0, -LIST_PADDING)
    missingList.Scroll:SetPoint("BOTTOMRIGHT", missingList, "BOTTOMRIGHT", -LIST_SCROLLBAR_WIDTH, LIST_PADDING)
    MPH.SkinScroll(missingList.Scroll)

    missingList.Content = CreateFrame("Frame", nil, missingList.Scroll)
    missingList.Content:SetSize(LIST_WIDTH - LIST_PADDING - LIST_SCROLLBAR_WIDTH, 1)
    missingList.Scroll:SetScrollChild(missingList.Content)
    missingList.entries = {}

    missingList:SetScript("OnUpdate", function (self, elapsed)
        if self:IsMouseOver() or (self.owner and self.owner:IsVisible() and self.owner:IsMouseOver()) then
            self.idle = 0
            return
        end
        self.idle = self.idle + elapsed
        if self.idle >= LIST_HIDE_DELAY then self:Hide() end
    end)
    missingList:Hide()
end

local function ShowMissingList(owner)
    local ids = owner.getMissing()
    if #ids == 0 then return end
    if not missingList then BuildMissingList() end

    for index, id in ipairs(ids) do
        local entry = MissingEntry(index)
        SetEntryToy(entry, id)
        entry:Show()
    end
    for index = #ids + 1, #missingList.entries do
        missingList.entries[index]:Hide()
    end

    local visible = math.min(#ids, LIST_MAX_ENTRIES)
    missingList.Content:SetHeight(#ids * LIST_ENTRY_HEIGHT)
    missingList:SetHeight(LIST_PADDING * 3 + LIST_TITLE_HEIGHT + visible * LIST_ENTRY_HEIGHT)
    missingList.Title:SetText(RED_FONT_COLOR:WrapTextInColorCode(string.format(L["teleport.missing"], #ids)))
    missingList.Scroll:SetVerticalScroll(0)
    missingList:ClearAllPoints()
    missingList:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 0, 0)
    PaintPanel(missingList)
    missingList.owner = owner
    missingList.idle = 0
    missingList:Show()
end

local function AddModeText(row, getMissing)
    row.Missing = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Missing:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.Missing:SetHeight(LABEL_HEIGHT)
    row.Missing:SetJustifyH("RIGHT")

    row.Mode = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Mode:SetPoint("TOPRIGHT", row.Missing, "TOPLEFT", 0, 0)
    row.Mode:SetHeight(LABEL_HEIGHT)
    row.Mode:SetJustifyH("RIGHT")
    row.Label:SetPoint("TOPRIGHT", row.Mode, "TOPLEFT", -6, 0)

    row.MissingHit = CreateFrame("Frame", nil, row)
    row.MissingHit:SetAllPoints(row.Missing)
    row.MissingHit:EnableMouse(true)
    row.MissingHit.getMissing = getMissing
    row.MissingHit:SetScript("OnEnter", ShowMissingList)
    row.MissingHit:Hide()
end

local function UpdateMissing(row)
    local count = #row.MissingHit.getMissing()
    row.Missing:SetText(count > 0 and string.format(" [%d]", count) or "")
    row.MissingHit:SetShown(count > 0)
end

local function AddCounter(row)
    row.Counter = row.Hit:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Counter:SetPoint("BOTTOMRIGHT", row.Hit, "RIGHT", -4, 1)
    row.Counter:SetJustifyH("RIGHT")
end

local function SetCounter(row, index, count)
    if count > 1 and index > 0 then
        row.Counter:SetText(string.format("%d/%d", index, count))
    else
        row.Counter:SetText("")
    end
end

local function LayoutName(row, known)
    row.Name:ClearAllPoints()
    if known then
        row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 10, 0)
        row.Name:SetPoint("RIGHT", row.Hit, "RIGHT", -4, 0)
    else
        row.Name:SetPoint("BOTTOMLEFT", row.Icon, "RIGHT", 10, 1)
        if row.Counter then
            row.Name:SetPoint("BOTTOMRIGHT", row.Counter, "BOTTOMLEFT", -6, 0)
        else
            row.Name:SetPoint("BOTTOMRIGHT", row.Hit, "RIGHT", -4, 1)
        end
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

local function SetGrayStatus(row, text)
    row.Name:SetTextColor(0.6, 0.6, 0.6)
    row.Unknown:SetText(text)
    row.Unknown:SetTextColor(GRAY_FONT_COLOR:GetRGB())
end

local function SetItemName(row, id, field)
    local name = C_Item.GetItemNameByID(id)
    if name then
        row.Name:SetText(name)
        return
    end

    row.Name:SetText("")
    Item:CreateFromItemID(id):ContinueOnItemLoad(function ()
        if row[field] == id then
            row.Name:SetText(C_Item.GetItemNameByID(id))
        end
    end)
end

local function Crossfade(row, texture, fromAlpha)
    row.Reveal:Stop()
    row.Base:SetTexture(texture)
    row.Fade:SetFromAlpha(fromAlpha)
    row.Icon:SetAlpha(1)
    row.Base:SetAlpha(0)
    row.Reveal:Play()
end

local function UpdateLoading(row, loading, texture)
    if loading == row.loading then return end
    if loading then
        row.Reveal:Stop()
        row.Base:SetTexture(texture)
        row.Icon:SetAlpha(0)
        row.Base:SetAlpha(LOADING_ALPHA)
    elseif row.loading then
        Crossfade(row, texture, LOADING_ALPHA)
    end
    row.loading = loading
end

local function UpdateTravel()
    local entry, count, index = MPH.Travel.Get()
    SetCounter(travelRow, index, count)
    travelRow.travelCount = count
    travelRow.Mode:SetText(ModeText(MPH.Travel.IsRandom(), "teleport.travelfixed"))
    UpdateMissing(travelRow)
    if entry ~= travelRow.entry then
        if travelRow.loading == false and travelRow.entry then
            Crossfade(travelRow, travelRow.Icon:GetTexture(), 1)
        end
        travelRow.entry = entry
        travelRow.entryID = entry and entry.id
        if not entry then
            travelRow.Icon:SetTexture(RANDOM_ICON)
            travelRow.Name:SetText(L["teleport.norandom"])
        elseif entry.kind == "toy" then
            travelRow.Icon:SetTexture(C_Item.GetItemIconByID(entry.id))
            SetItemName(travelRow, entry.id, "entryID")
        else
            travelRow.Icon:SetTexture(C_Spell.GetSpellTexture(entry.id))
            travelRow.Name:SetText(C_Spell.GetSpellName(entry.id))
        end
        PlaceButtons()
    end

    local loading = MPH.Travel.IsLoading()
    UpdateLoading(travelRow, loading, RANDOM_ICON)

    travelRow.Icon:SetDesaturated(not entry)
    if not entry then
        SetGrayStatus(travelRow, L[loading and "teleport.randomsearch" or "teleport.randomnone"])
        return
    end
    local remaining = entry.kind == "toy" and GetItemRemaining(entry.id) or GetSpellRemaining(entry.id)
    travelRow.Name:SetTextColor(1, 0.82, 0)
    travelRow.Unknown:SetText(StatusText(remaining, entry.place and L[entry.place]))
    travelRow.Unknown:SetTextColor(0.8, 0.8, 0.8)
end

local function UpdateStone()
    local id, isToy, count, index = MPH.Hearthstone.Get()
    SetCounter(stoneRow, index or 0, count or 0)
    stoneRow.stoneCount = count or 0
    stoneRow.Mode:SetText(ModeText(MPH.Hearthstone.IsRandom(), "teleport.stonestandard"))
    UpdateMissing(stoneRow)
    if id ~= stoneRow.stoneID or isToy ~= stoneRow.stoneToy then
        if stoneRow.loading == false and stoneRow.stoneID then
            Crossfade(stoneRow, stoneRow.Icon:GetTexture(), 1)
        end
        stoneRow.stoneID = id
        stoneRow.stoneToy = isToy
        stoneRow.Icon:SetTexture(C_Item.GetItemIconByID(id or MPH.Hearthstone.ITEM))
        if id then
            SetItemName(stoneRow, id, "stoneID")
        else
            stoneRow.Name:SetText(L["teleport.nostone"])
        end
        PlaceButtons()
    end

    local loading = MPH.Hearthstone.IsLoading()
    UpdateLoading(stoneRow, loading, C_Item.GetItemIconByID(MPH.Hearthstone.ITEM))

    stoneRow.Icon:SetDesaturated(not id)
    if id then
        stoneRow.Name:SetTextColor(1, 0.82, 0)
    else
        stoneRow.Name:SetTextColor(0.6, 0.6, 0.6)
    end

    if loading then
        stoneRow.Unknown:SetText(L["teleport.stonesearch"])
        stoneRow.Unknown:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    elseif not id then
        stoneRow.Unknown:SetText(L["teleport.nostonedesc"])
        stoneRow.Unknown:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    else
        stoneRow.Unknown:SetText(StatusText(GetItemRemaining(id), GetBindLocation()))
        stoneRow.Unknown:SetTextColor(0.8, 0.8, 0.8)
    end
end

local function UpdateState()
    if not page then return end

    UpdateTravel()
    UpdateStone()

    local spellID, keystone
    for _, row in ipairs(rows) do
        if row.dungeon and UpdateRow(row) and not spellID then
            spellID = row.dungeon.teleport
            keystone = row.keystone
        end
    end

    page.StatusIcon:SetShown(spellID ~= nil)
    page.Status:SetShown(spellID ~= nil)
    if not spellID then
        page.StatusHit:Hide()
        return
    end

    local remaining = GetSpellRemaining(spellID)
    page.Status:SetText(StatusText(remaining,
        keystone and GRAY_FONT_COLOR:WrapTextInColorCode(L["teleport.key"]) or nil))
    page.Status:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    if remaining > 0 then
        page.StatusHit:SetWidth(STATUS_ICON_SIZE + 6 + page.Status:GetStringWidth())
        page.StatusHit:Show()
    else
        page.StatusHit:Hide()
    end
end

local function ShowTooltip(self)
    local row = self.row
    if not row or not (row.dungeon or row.stoneID or row.entry) then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if row.travel then
        if row.entry.kind == "toy" then
            GameTooltip:SetToyByItemID(row.entry.id)
        else
            GameTooltip:SetSpellByID(row.entry.id)
        end
        GameTooltip:AddLine(" ")
        if row.travelCount > 1 then
            GameTooltip:AddLine(L["teleport.randomreroll"], GRAY_FONT_COLOR:GetRGB())
        end
        GameTooltip:AddLine(string.format(L["teleport.stonemode"],
            L[MPH.Travel.IsRandom() and "teleport.stonerandom" or "teleport.travelfixed"]), GRAY_FONT_COLOR:GetRGB())
    elseif row.stone then
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
    if row.travel then
        button:SetScript("OnMouseUp", function (self, mouseButton)
            if InCombatLockdown() or mouseButton ~= "RightButton" then return end
            MPH.Travel.SetRandom(not MPH.Travel.IsRandom())
            UpdateTravel()
            if GameTooltip:IsOwned(self) then ShowTooltip(self) end
        end)
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", function (self, delta)
            if InCombatLockdown() then return end
            MPH.Travel.Step(-delta)
            UpdateTravel()
            if GameTooltip:IsOwned(self) then ShowTooltip(self) end
        end)
    elseif row.stone then
        button:SetScript("OnMouseUp", function (self, mouseButton)
            if InCombatLockdown() or mouseButton ~= "RightButton" then return end
            MPH.Hearthstone.SetRandom(not MPH.Hearthstone.IsRandom())
            UpdateStone()
            if GameTooltip:IsOwned(self) then ShowTooltip(self) end
        end)
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", function (self, delta)
            if InCombatLockdown() then return end
            MPH.Hearthstone.Step(-delta)
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
        local button = (row.dungeon or row.stoneID or row.entry) and row:IsVisible() and EnsureButton(row)
        if button then
            button:ClearAllPoints()
            button:SetAllPoints(row.Hit)
            if row.dungeon then
                button:SetAttribute("spell", row.dungeon.teleport)
            elseif row.travel then
                local kind = row.entry.kind
                button:SetAttribute("type", kind)
                button:SetAttribute("toy", kind == "toy" and row.entry.id or nil)
                button:SetAttribute("spell", kind == "spell" and row.entry.id or nil)
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

    local search, key, reason, here = MPH.Teleport.GetDungeons()
    local entries = {}
    if search then
        table.insert(entries, { dungeon = search, label = here and "teleport.here" or "teleport.search" })
    end
    if key then table.insert(entries, { dungeon = key, label = "teleport.key" }) end

    for index, row in ipairs(rows) do
        local entry = entries[index]
        row.dungeon = entry and entry.dungeon
        row.keystone = entry and entry.label == "teleport.key"
        row.known = nil
        row:SetShown(entry ~= nil)
        if entry then
            row.Label:SetText(entry.dungeon.level
                and string.format("%s +%d", L[entry.label], entry.dungeon.level)
                or L[entry.label])
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

local function AddCrossfade(row)
    row.Base = row.Hit:CreateTexture(nil, "ARTWORK", nil, -1)
    row.Base:SetAllPoints(row.Icon)
    row.Base:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.Base:SetAlpha(0)
    MPH.SkinIcon(row.Base)

    row.Reveal = row.Hit:CreateAnimationGroup()
    local show = row.Reveal:CreateAnimation("Alpha")
    show:SetTarget(row.Icon)
    show:SetFromAlpha(0)
    show:SetToAlpha(1)
    show:SetDuration(FADE_DURATION)
    row.Fade = row.Reveal:CreateAnimation("Alpha")
    row.Fade:SetTarget(row.Base)
    row.Fade:SetToAlpha(0)
    row.Fade:SetDuration(FADE_DURATION)
end

local function BuildStoneRow()
    stoneRow = CreateRow(ROW_COUNT + 2)
    stoneRow.stone = true
    stoneRow.stoneID = false
    stoneRow.stoneCount = 0
    stoneRow:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 20, BOTTOM_MARGIN)
    stoneRow:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -20, BOTTOM_MARGIN)
    stoneRow.Name:SetFontObject("GameFontNormal")
    stoneRow.Unknown:SetWordWrap(false)

    AddCrossfade(stoneRow)

    stoneRow.Label:SetText(L["teleport.stone"])
    AddModeText(stoneRow, MPH.Hearthstone.GetMissing)
    AddCounter(stoneRow)
    LayoutName(stoneRow, false)
    stoneRow:Show()
    table.insert(allRows, stoneRow)
end

local function BuildTravelRow()
    travelRow = CreateRow(ROW_COUNT + 1)
    travelRow.travel = true
    travelRow.entry = false
    travelRow.travelCount = 0
    travelRow:SetPoint("BOTTOMLEFT", stoneRow, "TOPLEFT", 0, ROW_GAP)
    travelRow:SetPoint("BOTTOMRIGHT", stoneRow, "TOPRIGHT", 0, ROW_GAP)
    travelRow.Name:SetFontObject("GameFontNormal")
    travelRow.Unknown:SetWordWrap(false)
    travelRow.Icon:SetTexture(RANDOM_ICON)
    AddCrossfade(travelRow)
    travelRow.Label:SetText(L["teleport.travel"])
    AddModeText(travelRow, MPH.Travel.GetMissing)
    AddCounter(travelRow)
    LayoutName(travelRow, false)
    travelRow:Show()
    table.insert(allRows, travelRow)
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
    BuildTravelRow()

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
        MPH.Hearthstone.Rescan()
        MPH.Hearthstone.Next()
        MPH.Travel.Reset()
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
