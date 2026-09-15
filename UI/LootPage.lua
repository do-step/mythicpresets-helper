local ADDON, MPH = ...
local L = MPH.L

local FRAME_WIDTH = 320
local SCROLLBAR_WIDTH = 28
local ROW_WIDTH = FRAME_WIDTH - 16 - SCROLLBAR_WIDTH
local ROW_HEIGHT = 40
local ROW_GAP = 2
local ICON_SIZE = 32
local THANKS_HEIGHT = 34
local SECTION_GAP = 10
local HEADER_HEIGHT = 20

MPH.LootPage = {}

local page
local rows = {}

local function AddGrayLine(text)
    local r, g, b = GRAY_FONT_COLOR:GetRGB()
    GameTooltip:AddLine(text, r, g, b, true)
end

local function PlayerName(item)
    local name = Ambiguate(item.player, "short")
    local color = item.class and C_ClassColor.GetClassColor(item.class)
    return color and color:WrapTextInColorCode(name) or name
end

local function IsUntradable(item)
    return MPH.Loot.CanTrade(item.link) == false
end

local function InfoText(item)
    local details = {}
    local equipLoc = MPH.Loot.EquipLoc(item.link)
    local slot = equipLoc and _G[equipLoc]
    if type(slot) == "string" and slot ~= "" then
        local level = C_Item.GetDetailedItemLevelInfo(item.link)
        if level then table.insert(details, tostring(level)) end
        table.insert(details, slot)
    end
    local suffix = #details > 0 and GRAY_FONT_COLOR:WrapTextInColorCode(", " .. table.concat(details, ", ")) or ""

    if item.own then
        return GRAY_FONT_COLOR:WrapTextInColorCode(L["loot.own"]) .. suffix
    end
    if item.asked and not IsUntradable(item) then
        return string.format(L["loot.status"], GREEN_FONT_COLOR:WrapTextInColorCode(L["loot.asked"]),
            PlayerName(item)) .. suffix
    end
    return PlayerName(item) .. suffix
end

local function ShowRowTooltip(self)
    local item = self.item
    if not item then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(item.link)
    GameTooltip:AddLine(" ")
    if item.own then
        AddGrayLine(L["loot.owndesc"])
    elseif IsUntradable(item) then
        AddGrayLine(L["loot.untradabledesc"])
    else
        AddGrayLine(L["loot.message"])
        AddGrayLine(MPH.Loot.Message(item))
        AddGrayLine(L["loot.click"])
        AddGrayLine(L["loot.rightclick"])
    end
    GameTooltip:Show()
end

local function ShowThanksTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["loot.thanks"])
    AddGrayLine(L["loot.click"])
    AddGrayLine(L[MPH.db.thanks.enabled and "loot.thankson" or "loot.thanksoff"])
    GameTooltip:Show()
end

local function ShowEditTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["loot.edit"])
    AddGrayLine(L["loot.editdesc"])
    GameTooltip:Show()
end

local function CreateRow()
    local row = CreateFrame("Button", nil, page.child)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)

    row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.Highlight:SetAllPoints()
    row.Highlight:SetColorTexture(1, 1, 1, 0.10)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.Icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    MPH.SkinIcon(row.Icon, row)

    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Name:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -1)
    row.Name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)

    row.Info = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Info:SetPoint("BOTTOMLEFT", row.Icon, "BOTTOMRIGHT", 8, 1)
    row.Info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.Info:SetJustifyH("LEFT")
    row.Info:SetWordWrap(false)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function (self, button)
        if not self.item then return end
        if IsModifiedClick() then
            HandleModifiedItemClick(self.item.link)
            return
        end
        if self.item.own then return end
        if button == "RightButton" then
            MPH.Loot.Whisper(self.item)
            return
        end
        MPH.Loot.Ask(self.item)
        if GameTooltip:IsOwned(self) then ShowRowTooltip(self) end
    end)
    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function FillRow(row, item)
    row.item = item
    local _, _, _, _, icon = C_Item.GetItemInfoInstant(item.link)
    row.Icon:SetTexture(icon)
    local muted = item.own or IsUntradable(item)
    row.Icon:SetDesaturated(muted)
    row.Highlight:SetAlpha(muted and 0 or 1)

    local name, _, quality = C_Item.GetItemInfo(item.link)
    if name then
        row.Name:SetText(name)
        local r, g, b = C_Item.GetItemQualityColor(quality or 1)
        row.Name:SetTextColor(r, g, b)
    else
        row.Name:SetText(item.link)
        row.Name:SetTextColor(1, 1, 1)
        if row.waiting ~= item.link then
            row.waiting = item.link
            Item:CreateFromItemLink(item.link):ContinueOnItemLoad(function ()
                row.waiting = nil
                MPH.LootPage.Refresh()
            end)
        end
    end
    row.Info:SetText(InfoText(item))
    row:Show()
end

local function PlaceRow(index, y, item)
    rows[index] = rows[index] or CreateRow()
    local row = rows[index]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, -y)
    FillRow(row, item)
    return y + ROW_HEIGHT + ROW_GAP
end

function MPH.LootPage.Refresh()
    if not page or not page:IsVisible() then return end

    page.Thanks.Text:SetText(MPH.Thanks.GetText())

    local mapID, level = MPH.Loot.Run()
    local dungeon = mapID and mapID > 0 and C_ChallengeMode.GetMapUIInfo(mapID)
    if dungeon then
        page.LootLabel:SetText(string.format(L["loot.titlerun"], dungeon, level or 0))
    else
        page.LootLabel:SetText(L["loot.title"])
    end

    local items = MPH.Loot.Items()
    local tradable, untradable = {}, {}
    for _, item in ipairs(items) do
        table.insert(IsUntradable(item) and untradable or tradable, item)
    end

    local count, y = 0, 0
    for _, item in ipairs(tradable) do
        count = count + 1
        y = PlaceRow(count, y, item)
    end

    page.Untradable:SetShown(#untradable > 0)
    if #untradable > 0 then
        if #tradable > 0 then y = y + SECTION_GAP end
        page.Untradable:ClearAllPoints()
        page.Untradable:SetPoint("TOPLEFT", page.child, "TOPLEFT", 4, -y)
        y = y + HEADER_HEIGHT
        for _, item in ipairs(untradable) do
            count = count + 1
            y = PlaceRow(count, y, item)
        end
    end

    for index = count + 1, #rows do
        rows[index].item = nil
        rows[index]:Hide()
    end

    page.child:SetHeight(math.max(1, y))
    page.Empty:SetShown(#items == 0)
    page.Empty:SetText(L[dungeon and "loot.none" or "loot.empty"])
end

local function Build(container)
    page = container

    page.ThanksLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.ThanksLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -38)
    page.ThanksLabel:SetText(L["loot.thanks"])

    page.Thanks = CreateFrame("Button", nil, page)
    page.Thanks:SetPoint("TOPLEFT", page.ThanksLabel, "BOTTOMLEFT", -4, -4)
    page.Thanks:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    page.Thanks:SetHeight(THANKS_HEIGHT)

    page.Thanks.Highlight = page.Thanks:CreateTexture(nil, "HIGHLIGHT")
    page.Thanks.Highlight:SetAllPoints()
    page.Thanks.Highlight:SetColorTexture(1, 1, 1, 0.10)

    page.Thanks.Text = page.Thanks:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    page.Thanks.Text:SetPoint("LEFT", page.Thanks, "LEFT", 4, 0)
    page.Thanks.Text:SetPoint("RIGHT", page.Thanks, "RIGHT", -26, 0)
    page.Thanks.Text:SetJustifyH("LEFT")
    page.Thanks.Text:SetMaxLines(2)

    page.Thanks:RegisterForClicks("LeftButtonUp")
    page.Thanks:SetScript("OnClick", function ()
        MPH.Loot.Thank()
    end)
    page.Thanks:SetScript("OnEnter", ShowThanksTooltip)
    page.Thanks:SetScript("OnLeave", GameTooltip_Hide)

    page.Edit = CreateFrame("Button", nil, page.Thanks)
    page.Edit:SetSize(16, 16)
    page.Edit:SetPoint("RIGHT", page.Thanks, "RIGHT", -4, 0)
    page.Edit:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    page.Edit:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    page.Edit:SetScript("OnClick", function ()
        MPH.Thanks.ShowEditor()
    end)
    page.Edit:SetScript("OnEnter", ShowEditTooltip)
    page.Edit:SetScript("OnLeave", GameTooltip_Hide)

    page.LootLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.LootLabel:SetPoint("TOPLEFT", page.Thanks, "BOTTOMLEFT", 4, -14)
    page.LootLabel:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    page.LootLabel:SetJustifyH("LEFT")
    page.LootLabel:SetWordWrap(false)

    local scroll = CreateFrame("ScrollFrame", "MythicPresetsHelperLootScrollFrame", page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page.LootLabel, "BOTTOMLEFT", -8, -6)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 10)
    MPH.SkinScroll(scroll)

    page.child = CreateFrame("Frame", nil, scroll)
    page.child:SetSize(ROW_WIDTH, 1)
    scroll:SetScrollChild(page.child)

    page.Untradable = page.child:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.Untradable:SetText(L["loot.untradable"])
    page.Untradable:Hide()

    page.Empty = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    page.Empty:SetPoint("TOP", scroll, "TOP", 0, -40)
    page.Empty:SetWidth(260)

    page:HookScript("OnShow", MPH.LootPage.Refresh)
end

MPH.RegisterWindowPage({
    key = "loot",
    order = 4,
    atlas = "delves-bountiful",
    title = L["tabs.loot"],
    build = Build,
    refresh = MPH.LootPage.Refresh,
})
