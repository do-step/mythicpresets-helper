local ADDON, MPH = ...
local L = MPH.L

local FRAME_NAME = "MythicPresetsHelperRapportLabels"
local FALLBACK_WIDTH = 320
local FALLBACK_HEIGHT = 380
local BOX_HEIGHT = 20
local BOX_GAP = 6
local BOX_INDENT = 6
local SECTION_GAP = 14
local BUTTON_HEIGHT = 22
local RATINGS = { 0, 1, 2 }
local PREVIEW_ROLE = "TANK"
local PREVIEW_SCORE = 2850

MPH.RapportLabels = {}

local frame
local boxes = {}
local UpdatePreview

local function RatingColor(value)
    if value == 0 then return RED_FONT_COLOR end
    if value == 1 then return HIGHLIGHT_FONT_COLOR end
    return GREEN_FONT_COLOR
end

local function CreateBox(kind, value, anchor, indent)
    local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    box:SetHeight(BOX_HEIGHT)
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent, -BOX_GAP)
    box:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    box:SetAutoFocus(false)
    box:SetTextColor(RatingColor(value):GetRGB())
    box.kind = kind
    box.value = value

    box.Placeholder = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    box.Placeholder:SetPoint("LEFT", box, "LEFT", 6, 0)
    box.Placeholder:SetPoint("RIGHT", box, "RIGHT", -6, 0)
    box.Placeholder:SetJustifyH("LEFT")

    box.UpdatePlaceholder = function (self)
        self.Placeholder:SetShown(not MPH.NotEmpty(self:GetText()))
    end
    box:SetScript("OnTextChanged", function (self)
        self:UpdatePlaceholder()
        UpdatePreview()
    end)
    box:SetScript("OnEnterPressed", function (self)
        MPH.Rapport.SetLabel(self.kind, self.value, self:GetText())
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function (self)
        self:SetText(MPH.Rapport.IsCustomLabel(self.kind, self.value)
            and MPH.Rapport.GetLabel(self.kind, self.value) or "")
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function (self)
        MPH.Rapport.SetLabel(self.kind, self.value, self:GetText())
    end)
    MPH.SkinEditBox(box)
    return box
end

local function CurrentText(kind, value)
    for _, box in ipairs(boxes) do
        if box.kind == kind and box.value == value then
            local text = box:GetText()
            if MPH.NotEmpty(text) then return text end
        end
    end
    return MPH.Rapport.GetLabel(kind, value)
end

local function PreviewLine(value)
    local color = RatingColor(value)
    local game = MPH.Rapport.FormatGame(CurrentText("game", value), PREVIEW_SCORE)
    local role = MPH.Rapport.FormatRole(CurrentText("role", value), PREVIEW_ROLE, PREVIEW_SCORE)
    return color:WrapTextInColorCode(role) .. ", " .. color:WrapTextInColorCode(game)
end

function UpdatePreview()
    if not frame or not frame.Preview then return end
    for _, value in ipairs(RATINGS) do
        frame.Preview[value + 1]:SetText(PreviewLine(value))
    end
end

function MPH.RapportLabels.Refresh()
    if not frame or not frame:IsShown() then return end
    for _, box in ipairs(boxes) do
        box.Placeholder:SetText(MPH.Rapport.GetLabel(box.kind, box.value))
        if not box:HasFocus() then
            box:SetText(MPH.Rapport.IsCustomLabel(box.kind, box.value)
                and MPH.Rapport.GetLabel(box.kind, box.value) or "")
        end
        box:UpdatePlaceholder()
    end
    UpdatePreview()
end

local function Create()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    MPH.SkinShell(frame)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()
    MPH.SetTitle(frame, L["rapport.labelstitle"])

    frame.GameLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.GameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -36)
    frame.GameLabel:SetText(L["rapport.labelsgame"])

    local anchor = frame.GameLabel
    for index, value in ipairs(RATINGS) do
        local box = CreateBox("game", value, anchor, index == 1 and BOX_INDENT or 0)
        table.insert(boxes, box)
        anchor = box
    end

    frame.RoleLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.RoleLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -BOX_INDENT, -SECTION_GAP)
    frame.RoleLabel:SetText(L["rapport.labelsrole"])

    anchor = frame.RoleLabel
    for index, value in ipairs(RATINGS) do
        local box = CreateBox("role", value, anchor, index == 1 and BOX_INDENT or 0)
        table.insert(boxes, box)
        anchor = box
    end

    frame.Hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.Hint:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -BOX_INDENT, -SECTION_GAP)
    frame.Hint:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    frame.Hint:SetJustifyH("LEFT")
    frame.Hint:SetText(string.format(L["rapport.labelshint"], L["rapport.roletoken"], L["rapport.scoretoken"]))

    frame.PreviewLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.PreviewLabel:SetPoint("TOPLEFT", frame.Hint, "BOTTOMLEFT", 0, -SECTION_GAP)
    frame.PreviewLabel:SetText(L["rapport.labelspreview"])

    frame.Preview = {}
    anchor = frame.PreviewLabel
    for index in ipairs(RATINGS) do
        local line = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", index == 1 and BOX_INDENT or 0, -4)
        line:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
        line:SetJustifyH("LEFT")
        frame.Preview[index] = line
        anchor = line
    end

    frame.ResetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.ResetButton:SetHeight(BUTTON_HEIGHT)
    frame.ResetButton:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -BOX_INDENT, -SECTION_GAP)
    frame.ResetButton:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    frame.ResetButton:SetText(L["rapport.labelsreset"])
    frame.ResetButton:SetScript("OnClick", function ()
        MPH.Rapport.ResetLabels()
        MPH.RapportLabels.Refresh()
    end)
    MPH.SkinButton(frame.ResetButton)

    frame.BackButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.BackButton:SetHeight(BUTTON_HEIGHT)
    frame.BackButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 8)
    frame.BackButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 8)
    frame.BackButton:SetText(BACK)
    frame.BackButton:SetScript("OnClick", function ()
        frame:Hide()
    end)
    MPH.SkinButton(frame.BackButton)

    frame:SetScript("OnShow", MPH.RapportLabels.Refresh)

    local window = _G["MythicPresetsHelperFrame"]
    if window then
        window:HookScript("OnHide", function () frame:Hide() end)
    end
    tinsert(UISpecialFrames, FRAME_NAME)
end

function MPH.RapportLabels.Hide()
    if frame and frame:IsShown() then
        frame:Hide()
        MPH.Debug("rapport: labels closed by tab")
    end
end

function MPH.RapportLabels.Toggle()
    if not frame then Create() end
    if frame:IsShown() then
        frame:Hide()
        return
    end

    frame:ClearAllPoints()
    local window = _G["MythicPresetsHelperFrame"]
    if window and window:IsVisible() then
        frame:SetAllPoints(window)
    else
        frame:SetSize(FALLBACK_WIDTH, FALLBACK_HEIGHT)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:Show()
end
