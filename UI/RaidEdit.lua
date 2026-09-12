local ADDON, MPH = ...
local L = MPH.L

local FRAME_WIDTH = 300
local FRAME_HEIGHT = 290
local ARMOR_TYPES = { "plate", "mail", "leather", "cloth" }
local MEMBERS_LOW, MEMBERS_HIGH = 3, 40
local ARMOR_LOW, ARMOR_HIGH = 0, 40

local dialog
local editingIndex
local selectedArmor

local function ReadNumber(box, low, high)
    local value = tonumber(strtrim(box:GetText() or ""))
    if not value or value < low or value > high then return nil end
    return value
end

local function OnSave()
    local name = strtrim(dialog.NameBox:GetText() or "")
    if not MPH.NotEmpty(name) then
        MPH.Print(L["msg.needname"])
        return
    end

    local membersMin = ReadNumber(dialog.MembersBox, MEMBERS_LOW, MEMBERS_HIGH)
    if not membersMin then
        MPH.Print(L["msg.raidmembers"], MEMBERS_LOW, MEMBERS_HIGH)
        return
    end

    local armorMax = ReadNumber(dialog.ArmorMaxBox, ARMOR_LOW, ARMOR_HIGH)
    if not armorMax then
        MPH.Print(L["msg.raidarmormax"], ARMOR_LOW, ARMOR_HIGH)
        return
    end

    local preset = {
        kind = "raid",
        name = name,
        keyText = "",
        dungeons = {},
        membersMin = membersMin,
        armor = selectedArmor,
        armorMax = armorMax,
    }

    if editingIndex then
        MPH.Presets.Save(editingIndex, preset)
    else
        MPH.Presets.Add(preset)
    end
    dialog:Hide()
    MPH.RefreshWindow()
end

local function CreateLabel(anchor, x, y, text)
    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
    label:SetText(text)
    return label
end

local function CreateNumberBox(label, low, high)
    local box = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    box:SetSize(40, 20)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -4)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(2)
    box:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
    MPH.SkinEditBox(box)

    local hint = dialog:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", box, "RIGHT", 8, 0)
    hint:SetText(string.format(L["edit.range"], low, high))

    return box
end

local function CreateDialog()
    dialog = CreateFrame("Frame", "MythicPresetsHelperRaidEditFrame", UIParent, "BasicFrameTemplateWithInset")
    MPH.SkinShell(dialog)
    dialog:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    dialog:SetPoint("CENTER")
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

    dialog.MembersLabel = CreateLabel(dialog.NameBox, -6, -10, L["edit.raidmembers"])
    dialog.MembersBox = CreateNumberBox(dialog.MembersLabel, MEMBERS_LOW, MEMBERS_HIGH)

    dialog.ArmorLabel = CreateLabel(dialog.MembersBox, -6, -12, L["edit.raidarmor"])

    dialog.ArmorDropdown = CreateFrame("DropdownButton", nil, dialog, "WowStyle1DropdownTemplate")
    dialog.ArmorDropdown:SetPoint("TOPLEFT", dialog.ArmorLabel, "BOTTOMLEFT", 0, -4)
    dialog.ArmorDropdown:SetWidth(160)
    MPH.SkinDropdown(dialog.ArmorDropdown)
    dialog.ArmorDropdown:SetupMenu(function (_, root)
        for _, armor in ipairs(ARMOR_TYPES) do
            root:CreateRadio(L["armortype." .. armor],
                function (value) return selectedArmor == value end,
                function (value) selectedArmor = value end,
                armor)
        end
    end)

    dialog.ArmorMaxLabel = CreateLabel(dialog.ArmorDropdown, 0, -12, L["edit.raidarmormax"])
    dialog.ArmorMaxBox = CreateNumberBox(dialog.ArmorMaxLabel, ARMOR_LOW, ARMOR_HIGH)

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

    tinsert(UISpecialFrames, "MythicPresetsHelperRaidEditFrame")
end

local function AnchorToList()
    local list = _G["MythicPresetsHelperFrame"]
    dialog:ClearAllPoints()
    if list and list:IsVisible() then
        dialog:SetPoint("TOPLEFT", list, "TOPRIGHT", 42, 0)
    else
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function MPH.ShowRaidEditDialog(index)
    if not dialog then CreateDialog() end

    local other = _G["MythicPresetsHelperEditFrame"]
    if other then other:Hide() end

    editingIndex = index
    local preset = index and MPH.Presets.Get(index) or MPH.Presets.NewTemplate("raid")

    MPH.SetTitle(dialog, index and L["edit.titleraidedit"] or L["edit.titleraidnew"])
    dialog.NameBox:SetText(preset.name or "")
    dialog.MembersBox:SetText(tostring(preset.membersMin or MEMBERS_LOW))
    dialog.ArmorMaxBox:SetText(tostring(preset.armorMax or ARMOR_LOW))

    selectedArmor = preset.armor or MPH.GetPlayerArmor() or ARMOR_TYPES[1]
    dialog.ArmorDropdown:GenerateMenu()

    AnchorToList()
    dialog:Show()
    dialog.NameBox:SetFocus()
end
