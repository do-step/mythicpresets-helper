local ADDON, MPH = ...
local L = MPH.L

local FRAME_WIDTH = 320
local FRAME_HEIGHT = 380
local ROW_HEIGHT = 38
local SCROLLBAR_WIDTH = 28
local ROW_WIDTH = FRAME_WIDTH - 16 - SCROLLBAR_WIDTH

local SIDE_TAB_SIZE = 36
local SIDE_TAB_GAP = 6
local SIDE_TAB_TOP = 34

local frame, scrollChild
local rows = {}
local wanted = false
local held, pendingPage = false, nil

local pages = {}

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
    local maxX = UIParent:GetWidth() - FRAME_WIDTH - SIDE_TAB_SIZE
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

function MPH.RegisterWindowPage(page)
    table.insert(pages, page)
    table.sort(pages, function (a, b) return a.order < b.order end)
end

local function HighlightSideTabs()
    local kind = MPH.GetActiveKind()
    for _, page in ipairs(pages) do
        local selected = frame.currentPage == page.key
        for _, button in ipairs(page.buttons or {}) do
            button.Selected:SetShown(selected and (button.view.kind == nil or button.view.kind == kind))
        end
    end
end

function MPH.SelectWindowPage(key)
    if not frame then return end
    local selectedPage
    for _, page in ipairs(pages) do
        local selected = page.key == key
        page.container:SetShown(selected)
        if selected then selectedPage = page end
    end
    if key ~= "presets" then MPH.HideCopyBox() end
    frame.currentPage = key
    HighlightSideTabs()
    if selectedPage and selectedPage.refresh then
        selectedPage.refresh(selectedPage.container)
    end
end

local function SideTabTooltip(self)
    local title = self.view.title
    if type(title) == "function" then title = title() end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    GameTooltip:Show()
end

local function UpdateSideTabIcon(button)
    local icon = button.view.icon
    if type(icon) == "function" then icon = icon() end
    button.Icon:SetTexture(icon)
end

local function PaintSideTab(button)
    local colors = MPH.GetSideTabColors()
    button.Border:SetColorTexture(unpack(colors.border))
    button.Background:SetColorTexture(unpack(colors.background))
    button.Selected:SetColorTexture(unpack(colors.selected))
end

function MPH.RepaintSideTabs()
    for _, page in ipairs(pages) do
        for _, button in ipairs(page.buttons or {}) do
            PaintSideTab(button)
        end
    end
end

local function CreateSideTab(page, view, index)
    local button = CreateFrame("Button", nil, frame)
    button.page = page
    button.view = view
    button:SetFrameLevel(frame:GetFrameLevel() + 10)
    button:SetSize(SIDE_TAB_SIZE, SIDE_TAB_SIZE)
    button:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2,
        -SIDE_TAB_TOP - (index - 1) * (SIDE_TAB_SIZE + SIDE_TAB_GAP))

    button.Border = button:CreateTexture(nil, "BACKGROUND")
    button.Border:SetAllPoints()

    button.Background = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    button.Background:SetPoint("TOPLEFT", 1, -1)
    button.Background:SetPoint("BOTTOMRIGHT", -1, 1)

    button.Selected = button:CreateTexture(nil, "BACKGROUND", nil, 2)
    button.Selected:SetAllPoints(button.Background)
    button.Selected:Hide()
    PaintSideTab(button)

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetPoint("TOPLEFT", 4, -4)
    button.Icon:SetPoint("BOTTOMRIGHT", -4, 4)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    UpdateSideTabIcon(button)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", function ()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        MPH.SelectWindowPage(page.key)
        if view.category then
            MPH.OpenGroupSearch(view.category)
        end
    end)
    button:SetScript("OnEnter", SideTabTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function CreateIconButton(parent, texture, tooltipText, onClick, descText)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)
    button:SetNormalTexture(texture)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText)
        if descText then
            GameTooltip:AddLine(descText, GRAY_FONT_COLOR:GetRGB())
        end
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
            MPH.ShowRaidEditDialog(row.index)
            return
        end
        MPH.ShowEditDialog(row.index)
    end)
    row.Edit:SetPoint("RIGHT", row, "RIGHT", -22, 0)

    row.Copy = CreateIconButton(row, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", L["tooltip.copy"], function ()
        local copy = MPH.Presets.Copy(row.index)
        if not copy then return end
        MPH.Print(L["msg.copied"], copy.name)
        MPH.RefreshWindow()
    end, L["tooltip.copydesc"])
    row.Copy:SetPoint("RIGHT", row, "RIGHT", -22, 0)

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
        local note = L["tooltip.manual"]
        if preset.auto then
            note = MPH.GetPresetKind(preset) == "raid" and L["tooltip.autoraid"] or L["tooltip.auto"]
        end
        GameTooltip:AddLine(note, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    return row
end

local function HiddenGroups()
    local stats = MPH.filterStats
    if not stats then return 0, 0 end
    return math.max(0, stats.total - stats.shown), stats.total
end

function MPH.UpdateResetButton()
    if not frame or not frame.ResetButton then return end
    local hidden = HiddenGroups()
    if hidden > 0 then
        frame.ResetButton:SetText(string.format(L["button.resetfiltercount"], hidden))
    else
        frame.ResetButton:SetText(L["button.resetfilter"])
    end
end

function MPH.RefreshWindow()
    if not frame then return end

    local kind = MPH.GetActiveKind()

    for _, page in ipairs(pages) do
        for _, button in ipairs(page.buttons or {}) do
            UpdateSideTabIcon(button)
        end
    end
    HighlightSideTabs()

    local isRaid = kind == "raid"

    frame.RatingCheck:SetShown(not isRaid)
    frame.RatingLabel:SetShown(not isRaid)
    frame.RatingBox:SetShown(not isRaid)
    frame.FitCheck:SetShown(not isRaid)
    frame.FitLabel:SetShown(not isRaid)

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
        row.Edit:SetShown(not preset.auto)
        row.Delete:SetShown(not preset.auto)
        row.Copy:SetShown(preset.auto and true or false)
        row.Selected:SetShown(MPH.db.activePreset == row.index)
        row:Show()
    end
    for i = #presets + 1, #rows do
        rows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(1, #presets * (ROW_HEIGHT + 2)))
    frame.EmptyText:SetShown(#presets == 0)
    MPH.UpdateResetButton()
end

local HELP_HINT_INDENT = 20

local HELP_LINES = {
    { key = "info.title", font = "GameFontNormalLarge", gap = 0 },
    { key = "info.features", font = "GameFontNormalMed3", gap = 12 },
    { key = "info.feature.mplus", icon = 4352494, font = "GameFontHighlight", gap = 6 },
    { key = "info.when.mplus", font = "GameFontHighlightSmall", gap = 1, indent = HELP_HINT_INDENT, hint = true },
    { key = "info.feature.raid", icon = "Interface\\LFGFrame\\UI-LFR-PORTRAIT", font = "GameFontHighlight", gap = 4 },
    { key = "info.when.raid", font = "GameFontHighlightSmall", gap = 1, indent = HELP_HINT_INDENT, hint = true },
    { key = "info.feature.teleport", icon = "Interface\\Icons\\INV_12_Mage_Portal", font = "GameFontHighlight", gap = 4 },
    { key = "info.when.teleport", font = "GameFontHighlightSmall", gap = 1, indent = HELP_HINT_INDENT, hint = true },
    { key = "info.feature.loot", icon = "Interface\\Icons\\INV_Scroll_08", font = "GameFontHighlight", gap = 4 },
    { key = "info.when.loot", font = "GameFontHighlightSmall", gap = 1, indent = HELP_HINT_INDENT, hint = true },
    { key = "info.feature.slang", icon = "Interface\\Icons\\INV_Scroll_03", font = "GameFontHighlight", gap = 4 },
    { key = "info.feature.rapport", icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend", font = "GameFontHighlight", gap = 4 },
    { key = "info.mplus", font = "GameFontNormalMed3", gap = 18 },
    { key = "info.step1", font = "GameFontHighlight", gap = 6 },
    { key = "info.step2", font = "GameFontHighlight", gap = 8 },
    { key = "info.keep", font = "GameFontNormal", gap = 8 },
    { key = "info.note", font = "GameFontDisable", gap = 8 },
    { key = "info.raidtitle", font = "GameFontNormalMed3", gap = 18 },
    { key = "info.raid1", font = "GameFontHighlight", gap = 6 },
    { key = "info.raid2", font = "GameFontHighlight", gap = 8 },
    { key = "info.raid3", font = "GameFontHighlight", gap = 8 },
    { key = "info.raidnote", font = "GameFontDisable", gap = 8 },
}

local HELP_PADDING = 10

local function MeasureHelp(page)
    local height = HELP_PADDING * 2
    for index, text in ipairs(page.lines) do
        height = height + HELP_LINES[index].gap + text:GetStringHeight()
    end
    page.child:SetHeight(height)
end

local function BuildHelpPage(page)
    local scroll = CreateFrame("ScrollFrame", "MythicPresetsHelperHelpScrollFrame", page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 10)
    MPH.SkinScroll(scroll)

    page.child = CreateFrame("Frame", nil, scroll)
    page.child:SetWidth(ROW_WIDTH)
    scroll:SetScrollChild(page.child)

    page.lines = {}
    local previous, previousIndent = nil, 0
    for _, line in ipairs(HELP_LINES) do
        local indent = line.indent or 0
        local text = page.child:CreateFontString(nil, "ARTWORK", line.font)
        text:SetWidth(ROW_WIDTH - 12 - indent)
        text:SetJustifyH("LEFT")
        if line.hint then
            text:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        end
        if line.icon then
            text:SetText("|T" .. line.icon .. ":16:16|t " .. L[line.key])
        else
            text:SetText(L[line.key])
        end
        if previous then
            text:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", indent - previousIndent, -line.gap)
        else
            text:SetPoint("TOPLEFT", page.child, "TOPLEFT", 8 + indent, -HELP_PADDING)
        end
        table.insert(page.lines, text)
        previous, previousIndent = text, indent
    end
    MeasureHelp(page)
end

local function BuildPresetsPage(page)
    frame.EmptyText = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.EmptyText:SetPoint("CENTER", frame, "CENTER", 0, 10)
    frame.EmptyText:SetWidth(FRAME_WIDTH - 50)
    frame.EmptyText:SetText(L["window.empty"])

    local halfWidth = (FRAME_WIDTH - 44) / 2
    frame.halfWidth = halfWidth
    frame.NewButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    frame.NewButton:SetSize(halfWidth, 22)
    frame.NewButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 8)
    frame.NewButton:SetText(L["button.new"])
    frame.NewButton:SetScript("OnClick", function ()
        if MPH.GetActiveKind() == "raid" then
            MPH.ShowRaidEditDialog(nil)
        else
            MPH.ShowEditDialog(nil)
        end
    end)
    MPH.SkinButton(frame.NewButton)

    frame.ResetButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
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
        local hidden, total = HiddenGroups()
        if hidden > 0 then
            local r, g, b = GRAY_FONT_COLOR:GetRGB()
            GameTooltip:AddLine(string.format(L["tooltip.filterhidden"], hidden, total), r, g, b, true)
        end
        GameTooltip:Show()
    end)
    frame.ResetButton:SetScript("OnLeave", GameTooltip_Hide)
    MPH.SkinButton(frame.ResetButton)

    local function RatingTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["rating.label"])
        local r, g, b = GRAY_FONT_COLOR:GetRGB()
        GameTooltip:AddLine(L["rating.tooltip"], r, g, b, true)
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

    frame.RatingCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    frame.RatingCheck:SetSize(22, 22)
    frame.RatingCheck:SetPoint("BOTTOMLEFT", frame.NewButton, "TOPLEFT", -4, 6)
    frame.RatingCheck:SetChecked(MPH.db.rating.enabled)
    frame.RatingCheck:SetScript("OnClick", function (self)
        MPH.db.rating.enabled = self:GetChecked() and true or false
        MPH.Presets.Reapply()
    end)
    frame.RatingCheck:SetScript("OnEnter", RatingTooltip)
    frame.RatingCheck:SetScript("OnLeave", GameTooltip_Hide)
    MPH.SkinCheck(frame.RatingCheck)

    frame.RatingLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.RatingLabel:SetPoint("LEFT", frame.RatingCheck, "RIGHT", 2, 0)
    frame.RatingLabel:SetText(L["rating.label"])

    frame.RatingBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    frame.RatingBox:SetSize(48, 20)
    frame.RatingBox:SetPoint("LEFT", frame.RatingLabel, "RIGHT", 12, 0)
    frame.RatingBox:SetAutoFocus(false)
    frame.RatingBox:SetNumeric(true)
    frame.RatingBox:SetMaxLetters(4)
    frame.RatingBox:SetText(tostring(MPH.db.rating.delta or 100))
    frame.RatingBox:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
    frame.RatingBox:SetScript("OnEnterPressed", function (self) self:ClearFocus() end)
    frame.RatingBox:SetScript("OnEditFocusGained", function (self)
        self.startDelta = MPH.db.rating.delta
    end)
    frame.RatingBox:SetScript("OnEditFocusLost", function (self)
        if MPH.db.rating.delta ~= self.startDelta then
            MPH.Presets.Reapply()
        end
    end)
    frame.RatingBox:SetScript("OnTextChanged", function (self)
        MPH.db.rating.delta = tonumber(self:GetText()) or 0
    end)
    frame.RatingBox:SetScript("OnEnter", RatingTooltip)
    frame.RatingBox:SetScript("OnLeave", GameTooltip_Hide)
    MPH.SkinEditBox(frame.RatingBox)

    local function FitTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["fit.label"])
        local r, g, b = GRAY_FONT_COLOR:GetRGB()
        GameTooltip:AddLine(L["fit.tooltip"], r, g, b, true)
        GameTooltip:Show()
    end

    frame.FitCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    frame.FitCheck:SetSize(22, 22)
    frame.FitCheck:SetChecked(MPH.db.fit.enabled)
    frame.FitCheck:SetScript("OnClick", function (self)
        MPH.db.fit.enabled = self:GetChecked() and true or false
        MPH.Presets.Reapply()
    end)
    frame.FitCheck:SetScript("OnEnter", FitTooltip)
    frame.FitCheck:SetScript("OnLeave", GameTooltip_Hide)
    MPH.SkinCheck(frame.FitCheck)

    frame.FitLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.FitLabel:SetPoint("LEFT", frame.FitCheck, "RIGHT", 2, 0)
    frame.FitLabel:SetText(L["fit.label"])

    local rowWidth = FRAME_WIDTH - 36
    local ratingWidth = 22 + 2 + frame.RatingLabel:GetStringWidth() + 12 + frame.RatingBox:GetWidth()
    local fitWidth = 22 + 2 + frame.FitLabel:GetStringWidth()
    if ratingWidth + 12 + fitWidth <= rowWidth then
        frame.FitCheck:SetPoint("LEFT", frame.RatingCheck, "LEFT", rowWidth - fitWidth, 0)
    else
        frame.FitCheck:SetPoint("BOTTOMLEFT", frame.NewButton, "TOPLEFT", -4, 6)
        frame.RatingCheck:ClearAllPoints()
        frame.RatingCheck:SetPoint("BOTTOMLEFT", frame.FitCheck, "TOPLEFT", 0, 2)
    end

    frame.Scroll = CreateFrame("ScrollFrame", "MythicPresetsHelperScrollFrame", page, "ScrollFrameTemplate")
    frame.Scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame.Scroll:SetPoint("RIGHT", frame, "RIGHT", -SCROLLBAR_WIDTH, 0)
    frame.Scroll:SetPoint("BOTTOM", frame.RatingCheck, "TOP", 0, 4)
    MPH.SkinScroll(frame.Scroll)

    scrollChild = CreateFrame("Frame", nil, frame.Scroll)
    scrollChild:SetSize(ROW_WIDTH, 1)
    frame.Scroll:SetScrollChild(scrollChild)
end

MPH.RegisterWindowPage({
    key = "help",
    order = 1,
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    title = L["info.title"],
    build = BuildHelpPage,
    refresh = MeasureHelp,
})

MPH.RegisterWindowPage({
    key = "presets",
    order = 2,
    tabs = {
        {
            kind = "mplus",
            icon = 4352494,
            title = L["tabs.presetsmplus"],
            category = MPH.CATEGORY_DUNGEONS,
        },
        {
            kind = "raid",
            icon = "Interface\\LFGFrame\\UI-LFR-PORTRAIT",
            title = L["tabs.presetsraid"],
            category = MPH.CATEGORY_RAIDS,
        },
    },
    build = BuildPresetsPage,
})

local function CreateWindow()
    frame = CreateFrame("Frame", "MythicPresetsHelperFrame", UIParent, "BasicFrameTemplateWithInset")
    MPH.SkinShell(frame)
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
    frame:SetScript("OnMouseUp", function (_, mouseButton)
        if mouseButton == "RightButton" and IsShiftKeyDown() then
            MPH.PinWindowBesideGroupFinder()
        end
    end)
    frame:Hide()

    MPH.SetTitle(frame, L["window.title"])

    frame.CloseButton:SetScript("OnClick", function ()
        frame:Hide()
    end)

    frame.PlaceButton = CreateFrame("Button", nil, frame)
    frame.PlaceButton:SetSize(18, 18)
    frame.PlaceButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", 0, 0)
    frame.PlaceButton:SetNormalTexture("Interface\\CURSOR\\UI-Cursor-Move")
    frame.PlaceButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.PlaceButton:SetScript("OnClick", function ()
        MPH.PinWindowBesideGroupFinder()
    end)
    frame.PlaceButton:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["tooltip.place"])
        GameTooltip:AddLine(L["tooltip.placedesc"], 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["tooltip.placedrag"], 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine(L["tooltip.placeshift"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    frame.PlaceButton:SetScript("OnLeave", GameTooltip_Hide)

    frame.ReloadButton = CreateFrame("Button", nil, frame)
    frame.ReloadButton:SetSize(16, 16)
    frame.ReloadButton:SetPoint("LEFT", frame, "TOPLEFT", 6, -11)
    frame.ReloadButton:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    frame.ReloadButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.ReloadButton:SetScript("OnClick", function ()
        ReloadUI()
    end)
    frame.ReloadButton:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(RELOADUI or "/reload")
        GameTooltip:Show()
    end)
    frame.ReloadButton:SetScript("OnLeave", GameTooltip_Hide)

    local index = 0
    for _, page in ipairs(pages) do
        page.container = CreateFrame("Frame", nil, frame)
        page.container:SetAllPoints()
        page.container:Hide()
        page.build(page.container)
        page.buttons = {}
        for _, view in ipairs(page.tabs or { page }) do
            index = index + 1
            table.insert(page.buttons, CreateSideTab(page, view, index))
        end
    end

    frame:HookScript("OnShow", function ()
        local key = pendingPage
        pendingPage = nil
        if not MPH.db.window.onboarded then
            MPH.db.window.onboarded = true
            key = key or "help"
        end
        MPH.SelectWindowPage(key or "presets")
        MPH.RefreshFinderTab()
    end)
    frame:HookScript("OnHide", function ()
        wanted = false
        MPH.HideCopyBox()
        if held then
            held = false
            MPH.Teleport.Dismiss()
        end
        MPH.RefreshFinderTab()
    end)

    tinsert(UISpecialFrames, "MythicPresetsHelperFrame")
end

function MPH.ToggleWindow()
    if not frame then
        MPH.Print(L["msg.notready"])
        return
    end
    if frame:IsShown() then
        frame:Hide()
    else
        wanted = true
        MPH.RestoreWindowPosition()
        MPH.Progress.RebuildIfChanged()
        MPH.RefreshWindow()
        frame:Show()
    end
    MPH.RefreshFinderTab()
end

function MPH.ShowWindowPage(key)
    if not frame then
        MPH.Print(L["msg.notready"])
        return
    end
    wanted = true
    if frame:IsShown() then
        MPH.SelectWindowPage(key)
    else
        pendingPage = key
        MPH.RestoreWindowPosition()
        MPH.Progress.RebuildIfChanged()
        MPH.RefreshWindow()
        frame:Show()
    end
    MPH.RefreshFinderTab()
end

function MPH.OpenWindowOn(key, hold)
    if not frame then return end
    if hold then held = true end
    if frame:IsShown() then
        MPH.SelectWindowPage(key)
        return
    end
    pendingPage = key
    MPH.RestoreWindowPosition()
    MPH.Progress.RebuildIfChanged()
    MPH.RefreshWindow()
    frame:Show()
end

function MPH.ReleaseWindow()
    if not held then return end
    held = false
    if frame and frame:IsShown() and not wanted then
        frame:Hide()
    end
end

local onPage = false

local function UpdateVisibility()
    if not frame then return end

    local page = MPH.IsGroupFinderPage()
    if onPage and not page then
        wanted = false
    end
    if page and not onPage and MPH.db.window.autoOpen then
        if not frame:IsShown() and MPH.db.window.onboarded then
            pendingPage = "teleport"
        end
        wanted = true
    end
    onPage = page

    if wanted or held then
        MPH.RestoreWindowPosition()

        MPH.Progress.RebuildIfChanged()
        MPH.RefreshWindow()
        frame:Show()
    else
        frame:Hide()
    end
    MPH.RefreshFinderTab()
end

MPH.UpdateWindowVisibility = UpdateVisibility

local updateQueued = false
local function QueueVisibilityUpdate()
    if updateQueued then return end
    updateQueued = true
    C_Timer.After(0, function ()
        updateQueued = false
        UpdateVisibility()
    end)
end

table.insert(MPH.onLogin, function ()
    CreateWindow()

    if LFGListFrame then
        for _, panel in ipairs({ LFGListFrame.SearchPanel, LFGListFrame.ApplicationViewer }) do
            panel:HookScript("OnShow", UpdateVisibility)
            panel:HookScript("OnHide", QueueVisibilityUpdate)
        end
    end

    local entryEvents = CreateFrame("Frame")
    entryEvents:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    entryEvents:SetScript("OnEvent", UpdateVisibility)
    if PVEFrame then
        PVEFrame:HookScript("OnShow", UpdateVisibility)
        PVEFrame:HookScript("OnHide", QueueVisibilityUpdate)
    end

    if GroupFinderFrame then
        GroupFinderFrame:HookScript("OnShow", UpdateVisibility)
        GroupFinderFrame:HookScript("OnHide", QueueVisibilityUpdate)
    end

    if LFGListCategorySelection_SelectCategory then
        hooksecurefunc("LFGListCategorySelection_SelectCategory", function ()
            if frame:IsShown() then MPH.RefreshWindow() end
        end)
    end

    if LFGListSearchPanel_SetCategory then
        hooksecurefunc("LFGListSearchPanel_SetCategory", function ()
            UpdateVisibility()
        end)
    end

    UpdateVisibility()
end)
