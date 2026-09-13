local ADDON, MPH = ...
local L = MPH.L

local FRAME_WIDTH = 300
local DUNGEON_ROW_HEIGHT = 24

local dialog
local dungeonRows = {}
local editingIndex

local function CreateDungeonRow(index, parent, anchorTo)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - 50, DUNGEON_ROW_HEIGHT)
    if index == 1 then
        row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -6)
    else
        row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, 0)
    end

    row.Check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.Check:SetSize(22, 22)
    row.Check:SetPoint("LEFT", 0, 0)
    MPH.SkinCheck(row.Check)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(18, 18)
    row.Icon:SetPoint("LEFT", row.Check, "RIGHT", 2, 0)
    row.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    MPH.SkinIcon(row.Icon, row)

    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
    row.Name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)

    return row
end

local function LayoutDungeons(selected)
    local dungeons = MPH.GetSeasonDungeons()
    local anchor = dialog.DungeonsLabel

    for i, dungeon in ipairs(dungeons) do
        local row = dungeonRows[i]
        if not row then
            row = CreateDungeonRow(i, dialog, anchor)
            dungeonRows[i] = row
        end
        row.cmID = dungeon.cmID
        row.Icon:SetTexture(dungeon.texture)
        row.Name:SetText(dungeon.name)
        row.Check:SetChecked(selected[dungeon.cmID] or false)
        row:Show()
        anchor = row
    end
    for i = #dungeons + 1, #dungeonRows do
        dungeonRows[i]:Hide()
    end

    return #dungeons * DUNGEON_ROW_HEIGHT, #dungeons
end

local function SetAllDungeons(checked)
    for _, row in ipairs(dungeonRows) do
        if row:IsShown() then row.Check:SetChecked(checked) end
    end
end

local function CollectPreset()
    local dungeons = {}
    for _, row in ipairs(dungeonRows) do
        if row:IsShown() and row.Check:GetChecked() then
            table.insert(dungeons, row.cmID)
        end
    end
    return {
        name = strtrim(dialog.NameBox:GetText() or ""),
        keyText = strtrim(dialog.KeyBox:GetText() or ""),
        dungeons = dungeons,
    }
end

local function OnSave()
    local preset = CollectPreset()
    if not MPH.NotEmpty(preset.name) then
        MPH.Print(L["msg.needname"])
        return
    end
    if #preset.dungeons == 0 then
        MPH.Print(L["msg.needdungeon"])
        return
    end

    if editingIndex then
        MPH.Presets.Save(editingIndex, preset)
    else
        MPH.Presets.Add(preset)
    end
    dialog:Hide()
    MPH.RefreshWindow()
end

local function CreateDialog()
    dialog = CreateFrame("Frame", "MythicPresetsHelperEditFrame", UIParent, "BasicFrameTemplateWithInset")
    MPH.SkinShell(dialog)
    dialog:SetWidth(FRAME_WIDTH)
    dialog:SetHeight(320)
    dialog:SetPoint("CENTER")
    dialog.AnchorToList = function (self)
        local list = _G["MythicPresetsHelperFrame"]
        self:ClearAllPoints()
        if list and list:IsVisible() then
            self:SetPoint("TOPLEFT", list, "TOPRIGHT", 42, 0)
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide()

    dialog.NameLabel = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dialog.NameLabel:SetPoint("TOPLEFT", 16, -34)
    dialog.NameLabel:SetText(L["edit.name"])

    dialog.NameBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    dialog.NameBox:SetSize(FRAME_WIDTH - 46, 20)
    dialog.NameBox:SetPoint("TOPLEFT", dialog.NameLabel, "BOTTOMLEFT", 6, -4)
    dialog.NameBox:SetAutoFocus(false)
    dialog.NameBox:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
    MPH.SkinEditBox(dialog.NameBox)

    dialog.KeyLabel = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dialog.KeyLabel:SetPoint("TOPLEFT", dialog.NameBox, "BOTTOMLEFT", -6, -10)
    dialog.KeyLabel:SetText(L["edit.keylevel"])

    dialog.KeyBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    dialog.KeyBox:SetSize(60, 20)
    dialog.KeyBox:SetPoint("TOPLEFT", dialog.KeyLabel, "BOTTOMLEFT", 6, -4)
    dialog.KeyBox:SetAutoFocus(false)
    dialog.KeyBox:SetMaxLetters(10)
    dialog.KeyBox:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
    MPH.SkinEditBox(dialog.KeyBox)

    dialog.KeyHint = dialog:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    dialog.KeyHint:SetPoint("LEFT", dialog.KeyBox, "RIGHT", 8, 0)
    dialog.KeyHint:SetPoint("RIGHT", dialog, "RIGHT", -16, 0)
    dialog.KeyHint:SetJustifyH("LEFT")
    dialog.KeyHint:SetText(L["edit.keylevelhint"])

    dialog.DungeonsLabel = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dialog.DungeonsLabel:SetPoint("TOPLEFT", dialog.KeyBox, "BOTTOMLEFT", -6, -12)
    dialog.DungeonsLabel:SetText(L["edit.dungeons"])

    dialog.AllButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.AllButton:SetSize(60, 18)
    dialog.AllButton:SetPoint("LEFT", dialog.DungeonsLabel, "RIGHT", 12, 0)
    dialog.AllButton:SetText(L["button.all"])
    dialog.AllButton:SetScript("OnClick", function () SetAllDungeons(true) end)
    MPH.SkinButton(dialog.AllButton)

    dialog.NoneButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.NoneButton:SetSize(60, 18)
    dialog.NoneButton:SetPoint("LEFT", dialog.AllButton, "RIGHT", 4, 0)
    dialog.NoneButton:SetText(L["button.none"])
    dialog.NoneButton:SetScript("OnClick", function () SetAllDungeons(false) end)
    MPH.SkinButton(dialog.NoneButton)

    dialog.SaveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.SaveButton:SetSize(110, 22)
    dialog.SaveButton:SetPoint("BOTTOMLEFT", 16, 12)
    dialog.SaveButton:SetText(L["button.save"])
    dialog.SaveButton:SetScript("OnClick", OnSave)
    MPH.SkinButton(dialog.SaveButton)

    dialog.CancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.CancelButton:SetSize(110, 22)
    dialog.CancelButton:SetPoint("BOTTOMRIGHT", -16, 12)
    dialog.CancelButton:SetText(L["button.cancel"])
    dialog.CancelButton:SetScript("OnClick", function () dialog:Hide() end)
    MPH.SkinButton(dialog.CancelButton)

    tinsert(UISpecialFrames, "MythicPresetsHelperEditFrame")
end

function MPH.ShowEditDialog(index)
    if not dialog then CreateDialog() end

    local other = _G["MythicPresetsHelperRaidEditFrame"]
    if other then other:Hide() end

    editingIndex = index
    local preset = index and MPH.Presets.Get(index) or MPH.Presets.NewTemplate()

    MPH.SetTitle(dialog, index and L["edit.titleedit"] or L["edit.titlenew"])
    dialog.NameBox:SetText(preset.name or "")
    dialog.KeyBox:SetText(preset.keyText or "")

    local selected = {}
    for _, cmID in ipairs(preset.dungeons) do selected[cmID] = true end

    local listHeight, count = LayoutDungeons(selected)
    if count == 0 then

        MPH.Print(L["msg.nodungeondata"])
    end
    dialog:SetHeight(150 + listHeight + 44)

    dialog:AnchorToList()
    dialog:Show()
    dialog.NameBox:SetFocus()
end
