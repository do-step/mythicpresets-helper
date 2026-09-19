local ADDON, MPH = ...
local L = MPH.L

local ROW_HEIGHT = 54
local ROW_GAP = 4
local BACKGROUND_SIZE = 46
local ICON_SIZE = 30
local TIME_WIDTH = 72
local BUTTON_HEIGHT = 22
local GEAR_SIZE = 20
local GEAR_GAP = 8
local HIT_PADDING = 3

local ROLE_ATLAS = {
    TANK = "UI-LFG-RoleIcon-Tank",
    HEALER = "UI-LFG-RoleIcon-Healer",
    DAMAGER = "UI-LFG-RoleIcon-DPS",
}

MPH.RapportPage = {}

local page
local rows = {}

local function PlayerName(member)
    local name = Ambiguate(member.name, "none")
    local color = member.class and C_ClassColor.GetClassColor(member.class)
    return color and color:WrapTextInColorCode(name) or name
end

local function AddGrayLine(text)
    local r, g, b = GRAY_FONT_COLOR:GetRGB()
    GameTooltip:AddLine(text, r, g, b, true)
end

local function OverRoleIcon(row)
    local member = row.member
    if not member or not member.role then return false end
    local left, right = row.Background:GetLeft(), row.Background:GetRight()
    if not left or not right then return false end
    local x = GetCursorPosition() / row:GetEffectiveScale()
    return x >= left - HIT_PADDING and x <= right + HIT_PADDING
end

local function ShowRowTooltip(self)
    local member = self.member
    if not member or not member.name then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(Ambiguate(member.name, "none"))
    GameTooltip:AddLine(MPH.Rapport.Text(member.name, member.role, member.score))
    if member.score then
        AddGrayLine(string.format(L["rapport.scoreat"], math.floor(member.score)))
    end
    local previous, previousAt = MPH.Rapport.GetPrevious(member.name)
    if previous then
        AddGrayLine(string.format(L["rapport.previous"], date("%d.%m", previousAt or time()),
            math.floor(previous)))
    end
    GameTooltip:AddLine(" ")
    if member.role then
        AddGrayLine(string.format(L["rapport.wheelrole"], MPH.Rapport.RoleWord(member.role)))
    end
    AddGrayLine(L["rapport.wheelgame"])
    GameTooltip:Show()
end

local function OnRowWheel(self, delta)
    local member = self.member
    if not member or not member.name then return end

    if self.history and MPH.RapportHistory.IsLocked() then
        MPH.RapportHistory.WheelScroll(delta)
        return
    end
    if OverRoleIcon(self) then
        MPH.Rapport.StepRole(member, delta)
    else
        MPH.Rapport.StepGame(member, delta)
    end
    if GameTooltip:IsOwned(self) then ShowRowTooltip(self) end
end

local function ClassText(member)
    local text = member.class and LOCALIZED_CLASS_NAMES_MALE[member.class] or ""
    local spec = member.spec and select(2, GetSpecializationInfoByID(member.spec))
    if MPH.NotEmpty(spec) then
        text = MPH.NotEmpty(text) and string.format("%s (%s)", text, spec) or spec
    end
    if not MPH.NotEmpty(text) then return "" end
    return GRAY_FONT_COLOR:WrapTextInColorCode(text)
end

local function ScoreText(member)
    local score = member.score
    if not score or score <= 0 then
        return GRAY_FONT_COLOR:WrapTextInColorCode("-")
    end
    local text = tostring(math.floor(score))
    local color = C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score)
    return color and color:WrapTextInColorCode(text) or text
end

function MPH.RapportPage.RunTitle(run)
    local dungeon = run and run.mapID and run.mapID > 0 and C_ChallengeMode.GetMapUIInfo(run.mapID)
    if not dungeon then
        if run and not run.active and MPH.NotEmpty(run.zone) then
            return string.format(L["rapport.gather"], run.zone)
        end
        return L["rapport.lastrun"]
    end
    if (run.level or 0) <= 0 then return dungeon end
    return string.format(L["rapport.titlerun"], dungeon, run.level)
end

function MPH.RapportPage.RunTime(run)
    if not run or not run.startedAt or run.startedAt <= 0 then return "" end
    return date("%d.%m %H:%M", run.startedAt)
end

function MPH.RapportPage.CreatePlayerRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.Background = row:CreateTexture(nil, "BACKGROUND")
    row.Background:SetSize(BACKGROUND_SIZE, BACKGROUND_SIZE)
    row.Background:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.Icon:SetPoint("CENTER", row.Background, "CENTER", 0, 0)

    row.Score = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Score:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
    row.Score:SetJustifyH("RIGHT")

    row.PrevScore = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.PrevScore:SetPoint("TOPRIGHT", row.Score, "BOTTOMRIGHT", 0, -2)
    row.PrevScore:SetJustifyH("RIGHT")

    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Name:SetPoint("TOPLEFT", row.Background, "TOPRIGHT", 10, -3)
    row.Name:SetPoint("RIGHT", row.Score, "LEFT", -8, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)

    row.Info = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Info:SetPoint("TOPLEFT", row.Name, "BOTTOMLEFT", 0, -2)
    row.Info:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.Info:SetJustifyH("LEFT")
    row.Info:SetWordWrap(false)

    row.Rating = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Rating:SetPoint("TOPLEFT", row.Info, "BOTTOMLEFT", 0, -2)
    row.Rating:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.Rating:SetJustifyH("LEFT")
    row.Rating:SetWordWrap(false)

    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", OnRowWheel)
    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

function MPH.RapportPage.FillPlayerRow(row, member)
    row.member = member
    local atlas = ROLE_ATLAS[member.role]
    if atlas then
        row.Icon:SetAtlas(atlas)
        row.Background:SetAtlas(atlas .. "-Background")
    end
    row.Icon:SetShown(atlas ~= nil)
    row.Background:SetShown(atlas ~= nil)
    row.Name:SetText(PlayerName(member))
    row.Score:SetText(ScoreText(member))
    local previous = MPH.Rapport.GetPrevious(member.name)
    row.PrevScore:SetText(previous and tostring(math.floor(previous)) or "")
    row.Info:SetText(ClassText(member))
    row.Rating:SetText(MPH.Rapport.Text(member.name, member.role, member.score))
    row:Show()
end

function MPH.RapportPage.Refresh()
    if not page or not page:IsVisible() then return end

    local run = MPH.Rapport.Current()
    page.RunLabel:SetText(MPH.RapportPage.RunTitle(run))
    page.Time:SetText(MPH.RapportPage.RunTime(run))

    local members = MPH.Rapport.Members(run)
    local y = 0
    for index, member in ipairs(members) do
        rows[index] = rows[index] or MPH.RapportPage.CreatePlayerRow(page)
        local row = rows[index]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", page.RunLabel, "BOTTOMLEFT", 0, -8 - y)
        row:SetPoint("RIGHT", page, "RIGHT", -20, 0)
        MPH.RapportPage.FillPlayerRow(row, member)
        y = y + ROW_HEIGHT + ROW_GAP
    end
    for index = #members + 1, #rows do
        rows[index]:Hide()
    end

    page.Empty:SetShown(#members == 0)
end

local function Build(container)
    page = container

    page.Title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    page.Title:SetPoint("TOPLEFT", page, "TOPLEFT", 22, -40)
    page.Title:SetText(L["rapport.title"])

    page.RunLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.RunLabel:SetPoint("TOPLEFT", page.Title, "BOTTOMLEFT", -2, -18)
    page.RunLabel:SetPoint("RIGHT", page, "RIGHT", -TIME_WIDTH - 20, 0)
    page.RunLabel:SetJustifyH("LEFT")
    page.RunLabel:SetWordWrap(false)

    page.Time = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    page.Time:SetPoint("BOTTOMRIGHT", page.RunLabel, "BOTTOMRIGHT", TIME_WIDTH, 0)

    page.Empty = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    page.Empty:SetPoint("TOPLEFT", page.RunLabel, "BOTTOMLEFT", 0, -16)
    page.Empty:SetWidth(260)
    page.Empty:SetJustifyH("LEFT")
    page.Empty:SetText(L["rapport.empty"])

    page.LabelsButton = CreateFrame("Button", nil, page)
    page.LabelsButton:SetSize(GEAR_SIZE, GEAR_SIZE)
    page.LabelsButton:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -20, 8)
    page.LabelsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    page.LabelsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    page.LabelsButton:SetScript("OnClick", function ()
        MPH.RapportLabels.Toggle()
    end)
    page.LabelsButton:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["rapport.labels"])
        AddGrayLine(L["rapport.labelsdesc"])
        GameTooltip:Show()
    end)
    page.LabelsButton:SetScript("OnLeave", GameTooltip_Hide)

    page.HistoryButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    page.HistoryButton:SetHeight(BUTTON_HEIGHT)
    page.HistoryButton:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 20 + GEAR_SIZE + GEAR_GAP, 8)
    page.HistoryButton:SetPoint("RIGHT", page.LabelsButton, "LEFT", -GEAR_GAP, 0)
    page.HistoryButton:SetText(L["rapport.history"])
    page.HistoryButton:SetScript("OnClick", function ()
        MPH.RapportHistory.Toggle()
    end)
    MPH.SkinButton(page.HistoryButton)

    page:HookScript("OnShow", MPH.RapportPage.Refresh)
end

MPH.RegisterWindowPage({
    key = "rapport",
    bottom = true,
    order = 6,
    icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
    title = L["tabs.rapport"],
    build = Build,
    refresh = MPH.RapportPage.Refresh,
})
