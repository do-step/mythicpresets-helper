local ADDON, MPH = ...
local L = MPH.L

local FRAME_NAME = "MythicPresetsHelperRapportHistory"
local FALLBACK_WIDTH = 320
local FALLBACK_HEIGHT = 380
local SCROLLBAR_WIDTH = 28
local HEADER_HEIGHT = 44
local HEADER_GAP = 4
local CLASS_ICON_SIZE = 18
local CLASS_ICON_GAP = 3
local PARTY_SIZE = 5
local PLAYER_INDENT = 12
local PLAYER_HEIGHT = 54
local PLAYER_GAP = 4
local BUTTON_HEIGHT = 22
local CHECK_SIZE = 22

MPH.RapportHistory = {}

local frame
local headers = {}
local players = {}
local expanded = {}

function MPH.RapportHistory.IsLocked()
    return MPH.db.rapport.lockHistory ~= false
end

function MPH.RapportHistory.Hide()
    if frame and frame:IsShown() then
        frame:Hide()
        MPH.Debug("rapport: history closed by tab")
    end
end

function MPH.RapportHistory.WheelScroll(delta)
    if not frame then return end
    local script = frame.Scroll:GetScript("OnMouseWheel")
    if script then script(frame.Scroll, delta) end
end

local function CreateHeader()
    local header = CreateFrame("Button", nil, frame.child)
    header:SetHeight(HEADER_HEIGHT)
    header:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    header.Time = header:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    header.Time:SetPoint("TOPRIGHT", header, "TOPRIGHT", -6, -7)
    header.Time:SetJustifyH("RIGHT")

    header.Title = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header.Title:SetPoint("TOPLEFT", header, "TOPLEFT", 6, -5)
    header.Title:SetPoint("RIGHT", header.Time, "LEFT", -8, 0)
    header.Title:SetJustifyH("LEFT")
    header.Title:SetWordWrap(false)

    header.Icons = {}
    for index = 1, PARTY_SIZE do
        local icon = header:CreateTexture(nil, "ARTWORK")
        icon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
        if index == 1 then
            icon:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 6, 4)
        else
            icon:SetPoint("LEFT", header.Icons[index - 1], "RIGHT", CLASS_ICON_GAP, 0)
        end
        header.Icons[index] = icon
    end

    header:SetScript("OnClick", function (self)
        expanded[self.run] = not expanded[self.run] or nil
        MPH.RapportHistory.Refresh()
    end)
    return header
end

local function FillHeader(header, run)
    header.run = run
    header.Title:SetText(MPH.RapportPage.RunTitle(run))
    local color = run.onTime and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
    header.Title:SetTextColor(color:GetRGB())
    header.Time:SetText(MPH.RapportPage.RunTime(run))

    local party = MPH.Rapport.Party(run)
    for index, icon in ipairs(header.Icons) do
        local member = party[index]
        if member and member.class then
            icon:SetAtlas("classicon-" .. member.class:lower())
            icon:Show()
        else
            icon:Hide()
        end
    end
    header:Show()
end

local function Place(region, y, indent)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame.child, "TOPLEFT", indent or 0, -y)
    region:SetPoint("RIGHT", frame.child, "RIGHT", 0, 0)
end

function MPH.RapportHistory.Refresh()
    if not frame or not frame:IsShown() then return end

    frame.child:SetWidth(frame.Scroll:GetWidth())

    local runs = MPH.Rapport.History()
    local y, count = 0, 0
    for index, run in ipairs(runs) do
        headers[index] = headers[index] or CreateHeader()
        Place(headers[index], y)
        FillHeader(headers[index], run)
        y = y + HEADER_HEIGHT + HEADER_GAP

        if expanded[run] then
            for _, member in ipairs(MPH.Rapport.Members(run)) do
                count = count + 1
                players[count] = players[count] or MPH.RapportPage.CreatePlayerRow(frame.child)
                players[count].history = true
                Place(players[count], y, PLAYER_INDENT)
                MPH.RapportPage.FillPlayerRow(players[count], member)
                y = y + PLAYER_HEIGHT + PLAYER_GAP
            end
            y = y + HEADER_GAP
        end
    end
    for index = #runs + 1, #headers do
        headers[index]:Hide()
    end
    for index = count + 1, #players do
        players[index]:Hide()
    end

    frame.child:SetHeight(math.max(1, y))
    frame.Empty:SetShown(#runs == 0)
end

local function Create()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    MPH.SkinShell(frame)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()
    MPH.SetTitle(frame, L["rapport.history"])

    frame.Scroll = CreateFrame("ScrollFrame", "MythicPresetsHelperRapportHistoryScrollFrame", frame, "ScrollFrameTemplate")
    frame.Scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
    frame.Scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, BUTTON_HEIGHT + CHECK_SIZE + 18)
    MPH.SkinScroll(frame.Scroll)

    frame.child = CreateFrame("Frame", nil, frame.Scroll)
    frame.child:SetSize(1, 1)
    frame.Scroll:SetScrollChild(frame.child)
    frame.Scroll:SetScript("OnSizeChanged", function ()
        MPH.RapportHistory.Refresh()
    end)

    frame.Empty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.Empty:SetPoint("TOPLEFT", frame.Scroll, "TOPLEFT", 8, -16)
    frame.Empty:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    frame.Empty:SetJustifyH("LEFT")
    frame.Empty:SetText(L["rapport.nohistory"])

    frame.Lock = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.Lock:SetSize(CHECK_SIZE, CHECK_SIZE)
    frame.Lock:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, BUTTON_HEIGHT + 12)
    frame.Lock:SetChecked(MPH.RapportHistory.IsLocked())
    frame.Lock:SetScript("OnClick", function (self)
        MPH.db.rapport.lockHistory = self:GetChecked() and true or false
        MPH.Debug("rapport: history lock %s", tostring(MPH.db.rapport.lockHistory))
    end)
    frame.Lock:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["rapport.lock"])
        local r, g, b = GRAY_FONT_COLOR:GetRGB()
        GameTooltip:AddLine(L["rapport.lockdesc"], r, g, b, true)
        GameTooltip:Show()
    end)
    frame.Lock:SetScript("OnLeave", GameTooltip_Hide)
    MPH.SkinCheck(frame.Lock)

    frame.LockLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.LockLabel:SetPoint("LEFT", frame.Lock, "RIGHT", 2, 0)
    frame.LockLabel:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    frame.LockLabel:SetJustifyH("LEFT")
    frame.LockLabel:SetText(L["rapport.lock"])

    frame.BackButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.BackButton:SetHeight(BUTTON_HEIGHT)
    frame.BackButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 8)
    frame.BackButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 8)
    frame.BackButton:SetText(BACK)
    frame.BackButton:SetScript("OnClick", function ()
        frame:Hide()
    end)
    MPH.SkinButton(frame.BackButton)

    frame:SetScript("OnShow", function ()
        frame.Lock:SetChecked(MPH.RapportHistory.IsLocked())
        MPH.RapportHistory.Refresh()
    end)

    local window = _G["MythicPresetsHelperFrame"]
    if window then
        window:HookScript("OnHide", function () frame:Hide() end)
    end
    tinsert(UISpecialFrames, FRAME_NAME)
end

function MPH.RapportHistory.Toggle()
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
