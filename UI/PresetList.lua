local ADDON, MPH = ...
local L = MPH.L

local FRAME_WIDTH = 320
local FRAME_HEIGHT = 380
local ROW_HEIGHT = 38
local SCROLLBAR_WIDTH = 28
local ROW_WIDTH = FRAME_WIDTH - 16 - SCROLLBAR_WIDTH

local frame, scrollChild
local rows = {}

local ANCHOR_GAP = 12
local RIGHT_FRAMES = {
    "LFGListFrame",
    "PremadeGroupsFilterDialog",
    "PVEFrame",
    "RaiderIO_ProfileTooltip",
}
local TOP_FRAMES = { "LFGListFrame", "PVEFrame", "PremadeGroupsFilterDialog" }

local function ToUIParentScale(target, value)
    if not value then return nil end
    local scale = UIParent:GetEffectiveScale()
    if scale == 0 then return value end
    return value * target:GetEffectiveScale() / scale
end

local function VisibleEdge(name, getter)
    local target = _G[name]
    if not target or not target.IsVisible or not target:IsVisible() then return nil end
    return ToUIParentScale(target, target[getter](target))
end

local function HiddenRaiderIOWidth()
    local tooltip = _G["RaiderIO_ProfileTooltip"]
    if not tooltip or tooltip:IsVisible() then return 0 end
    local width = ToUIParentScale(tooltip, tooltip:GetWidth()) or 0
    if width < 1 then return 0 end
    return width + ANCHOR_GAP
end

local function AnchorToGroupFinder()
    frame:ClearAllPoints()

    local right, top
    for _, name in ipairs(RIGHT_FRAMES) do
        local edge = VisibleEdge(name, "GetRight")
        if edge and (not right or edge > right) then right = edge end
    end
    for _, name in ipairs(TOP_FRAMES) do
        local upper = VisibleEdge(name, "GetTop")
        if upper and (not top or upper > top) then top = upper end
    end

    if not right or not top then
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
        return
    end

    local x = right + ANCHOR_GAP + HiddenRaiderIOWidth() + (tonumber(MPH.db.window.offset) or 0)
    local maxX = UIParent:GetWidth() - FRAME_WIDTH
    if x > maxX then x = math.max(0, maxX) end

    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
end

local function SaveWindowPosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    MPH.db.window.point = point
    MPH.db.window.relPoint = relativePoint or point
    MPH.db.window.x = x
    MPH.db.window.y = y
end

function MPH.RestoreWindowPosition()
    if not frame then return end
    local pos = MPH.db.window
    if pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    else
        AnchorToGroupFinder()
    end
end

function MPH.PinWindowBesideGroupFinder()
    if not frame then return end
    MPH.db.window.point = nil
    AnchorToGroupFinder()
    SaveWindowPosition()
end

local function CreateIconButton(parent, texture, tooltipText, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)
    button:SetNormalTexture(texture)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, scrollChild)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * (ROW_HEIGHT + 2))

    row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.Highlight:SetAllPoints()
    row.Highlight:SetColorTexture(1, 1, 1, 0.10)

    row.Selected = row:CreateTexture(nil, "BACKGROUND")
    row.Selected:SetAllPoints()
    row.Selected:SetColorTexture(0.2, 0.5, 1, 0.20)
    row.Selected:Hide()

    row.Kind = row:CreateTexture(nil, "ARTWORK")
    row.Kind:SetWidth(3)
    row.Kind:SetPoint("TOPLEFT", 0, -2)
    row.Kind:SetPoint("BOTTOMLEFT", 0, 2)

    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Name:SetPoint("TOPLEFT", 10, -5)
    row.Name:SetPoint("RIGHT", row, "RIGHT", -42, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)

    row.Summary = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Summary:SetPoint("TOPLEFT", row.Name, "BOTTOMLEFT", 0, -2)
    row.Summary:SetPoint("RIGHT", row, "RIGHT", -42, 0)
    row.Summary:SetJustifyH("LEFT")
    row.Summary:SetWordWrap(false)

    row.Edit = CreateIconButton(row, "Interface\\Buttons\\UI-OptionsButton", L["tooltip.edit"], function ()
        local preset = MPH.Presets.Get(row.index)
        if preset and MPH.GetPresetKind(preset) == "raid" then
            MPH.Print(L["msg.raidnoedit"])
            return
        end
        MPH.ShowEditDialog(row.index)
    end)
    row.Edit:SetPoint("RIGHT", row, "RIGHT", -22, 0)

    row.Delete = CreateIconButton(row, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", L["tooltip.delete"], function ()
        if not IsShiftKeyDown() then
            MPH.Print(L["tooltip.delete"])
            return
        end
        MPH.Presets.Delete(row.index)
        MPH.RefreshWindow()
    end)
    row.Delete:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function (self)
        local preset = MPH.Presets.Get(self.index)
        if not preset then
            MPH.Print(L["msg.notready"])
            return
        end
        MPH.Presets.Apply(preset, self.index)
    end)
    row:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local preset = MPH.Presets.Get(self.index)
        GameTooltip:SetText(preset.name)
        GameTooltip:AddLine(L["tooltip.apply"], 1, 1, 1)
        GameTooltip:AddLine(preset.auto and L["tooltip.auto"] or L["tooltip.manual"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    return row
end

function MPH.RefreshWindow()
    if not frame then return end

    local kind = MPH.GetActiveKind()

    local isRaid = kind == "raid"

    frame.RatingCheck:SetShown(not isRaid)
    frame.RatingLabel:SetShown(not isRaid)
    frame.RatingBox:SetShown(not isRaid)
    frame.NewButton:SetShown(not isRaid)

    frame.ResetButton:ClearAllPoints()
    if isRaid then
        frame.ResetButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 8)
        frame.ResetButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 8)
    else
        frame.ResetButton:SetSize(frame.halfWidth, 22)
        frame.ResetButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 8)
    end

    frame.Scroll:SetPoint("BOTTOM",
        isRaid and frame.ResetButton or frame.RatingCheck, "TOP", 0, 4)

    local presets = {}
    for index, preset in ipairs(MPH.Presets.All()) do
        if MPH.GetPresetKind(preset) == kind then
            preset.listIndex = index
            table.insert(presets, preset)
        end
    end

    for i, preset in ipairs(presets) do
        local row = rows[i]
        if not row then
            row = CreateRow(i)
            rows[i] = row
        end
        row.index = preset.listIndex or i
        local kind = preset.auto and L["kind.auto"] or L["kind.manual"]
        row.Name:SetText(preset.name .. "  |cff909090- " .. kind .. "|r")
        row.Summary:SetText(MPH.Presets.Summary(preset))
        if preset.auto then
            row.Kind:SetColorTexture(0.25, 0.55, 1.0, 0.9)
        else
            row.Kind:SetColorTexture(0.5, 0.5, 0.5, 0.7)
        end
        row.Edit:SetShown(not isRaid)
        row.Delete:SetShown(not isRaid)
        row.Selected:SetShown(MPH.db.activePreset == row.index)
        row:Show()
    end
    for i = #presets + 1, #rows do
        rows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(1, #presets * (ROW_HEIGHT + 2)))
    frame.EmptyText:SetShown(#presets == 0)
end

local function CreateWindow()
    frame = CreateFrame("Frame", "MythicPresetsHelperFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function (self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)
    frame:Hide()

    MPH.SetTitle(frame, L["window.title"])

    frame.CloseButton:SetScript("OnClick", function ()
        MPH.db.window.shown = false
        frame:Hide()
    end)

    frame.InfoButton = CreateFrame("Button", nil, frame)
    frame.InfoButton:SetSize(18, 18)
    frame.InfoButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", 0, 0)
    frame.InfoButton:SetNormalTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    frame.InfoButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.InfoButton:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(L["info.title"])
        GameTooltip:AddLine(L["info.step1"], 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["info.step2"], 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["info.keep"], 1, 0.82, 0, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["info.note"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    frame.InfoButton:SetScript("OnLeave", GameTooltip_Hide)

    frame.PlaceButton = CreateFrame("Button", nil, frame)
    frame.PlaceButton:SetSize(18, 18)
    frame.PlaceButton:SetPoint("RIGHT", frame.InfoButton, "LEFT", 0, 0)
    frame.PlaceButton:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    frame.PlaceButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.PlaceButton:SetScript("OnClick", function ()
        MPH.PinWindowBesideGroupFinder()
    end)
    frame.PlaceButton:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["tooltip.place"])
        GameTooltip:AddLine(L["tooltip.placedesc"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.PlaceButton:SetScript("OnLeave", GameTooltip_Hide)

    frame.EmptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.EmptyText:SetPoint("CENTER", 0, 10)
    frame.EmptyText:SetWidth(FRAME_WIDTH - 50)
    frame.EmptyText:SetText(L["window.empty"])

    local halfWidth = (FRAME_WIDTH - 44) / 2
    frame.halfWidth = halfWidth
    frame.NewButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.NewButton:SetSize(halfWidth, 22)
    frame.NewButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 8)
    frame.NewButton:SetText(L["button.new"])
    frame.NewButton:SetScript("OnClick", function ()
        MPH.ShowEditDialog(nil)
    end)

    frame.ResetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.ResetButton:SetSize(halfWidth, 22)
    frame.ResetButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 8)
    frame.ResetButton:SetText(L["button.resetfilter"])
    frame.ResetButton:SetScript("OnClick", function ()
        MPH.Presets.Reset()
    end)
    frame.ResetButton:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["button.resetfilter"])
        GameTooltip:AddLine(L["tooltip.resetfilter"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.ResetButton:SetScript("OnLeave", GameTooltip_Hide)

    local function RatingTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["rating.label"])
        GameTooltip:AddLine(L["rating.tooltip"], 1, 1, 1, true)
        local score = MPH.GetPlayerScore()
        local delta = tonumber(MPH.db.rating.delta) or 0
        if score > 0 then
            GameTooltip:AddLine(string.format(L["rating.current"],
                score, math.max(0, score - delta), score + delta), 0.4, 1, 0.4, true)
        else
            GameTooltip:AddLine(L["rating.noscore"], 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end

    frame.RatingCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.RatingCheck:SetSize(22, 22)
    frame.RatingCheck:SetPoint("BOTTOMLEFT", frame.NewButton, "TOPLEFT", -4, 6)
    frame.RatingCheck:SetChecked(MPH.db.rating.enabled)
    frame.RatingCheck:SetScript("OnClick", function (self)
        MPH.db.rating.enabled = self:GetChecked() and true or false
    end)
    frame.RatingCheck:SetScript("OnEnter", RatingTooltip)
    frame.RatingCheck:SetScript("OnLeave", GameTooltip_Hide)

    frame.RatingLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.RatingLabel:SetPoint("LEFT", frame.RatingCheck, "RIGHT", 2, 0)
    frame.RatingLabel:SetText(L["rating.label"])

    frame.RatingBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.RatingBox:SetSize(48, 20)
    frame.RatingBox:SetPoint("LEFT", frame.RatingLabel, "RIGHT", 12, 0)
    frame.RatingBox:SetAutoFocus(false)
    frame.RatingBox:SetNumeric(true)
    frame.RatingBox:SetMaxLetters(4)
    frame.RatingBox:SetText(tostring(MPH.db.rating.delta or 100))
    frame.RatingBox:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
    frame.RatingBox:SetScript("OnEnterPressed", function (self) self:ClearFocus() end)
    frame.RatingBox:SetScript("OnTextChanged", function (self)
        MPH.db.rating.delta = tonumber(self:GetText()) or 0
    end)
    frame.RatingBox:SetScript("OnEnter", RatingTooltip)
    frame.RatingBox:SetScript("OnLeave", GameTooltip_Hide)

    frame.Scroll = CreateFrame("ScrollFrame", "MythicPresetsHelperScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.Scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame.Scroll:SetPoint("RIGHT", frame, "RIGHT", -SCROLLBAR_WIDTH, 0)
    frame.Scroll:SetPoint("BOTTOM", frame.RatingCheck, "TOP", 0, 4)

    scrollChild = CreateFrame("Frame", nil, frame.Scroll)
    scrollChild:SetSize(ROW_WIDTH, 1)
    frame.Scroll:SetScrollChild(scrollChild)

    tinsert(UISpecialFrames, "MythicPresetsHelperFrame")
end

function MPH.ToggleWindow()
    if not frame then
        MPH.Print(L["msg.notready"])
        return
    end
    if frame:IsShown() then
        MPH.db.window.shown = false
        frame:Hide()
    else
        MPH.db.window.shown = true
        MPH.RestoreWindowPosition()
        MPH.Progress.RebuildIfChanged()
        MPH.RefreshWindow()
        frame:Show()
    end
end

local function ShouldFollowGroupFinder()
    return LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsVisible()
end

local function UpdateVisibility()
    if not frame then return end
    if MPH.db.window.shown and ShouldFollowGroupFinder() then
        MPH.RestoreWindowPosition()

        MPH.Progress.RebuildIfChanged()
        MPH.RefreshWindow()
        frame:Show()
    else
        frame:Hide()
    end
end

table.insert(MPH.onLogin, function ()
    CreateWindow()

    if LFGListFrame and LFGListFrame.SearchPanel then
        LFGListFrame.SearchPanel:HookScript("OnShow", UpdateVisibility)
        LFGListFrame.SearchPanel:HookScript("OnHide", UpdateVisibility)
    end
    if PVEFrame then
        PVEFrame:HookScript("OnShow", UpdateVisibility)
        PVEFrame:HookScript("OnHide", UpdateVisibility)
    end

    if LFGListSearchPanel_SetCategory then
        hooksecurefunc("LFGListSearchPanel_SetCategory", function ()
            UpdateVisibility()
        end)
    end

    UpdateVisibility()
end)
