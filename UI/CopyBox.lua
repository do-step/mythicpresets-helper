local ADDON, MPH = ...
local L = MPH.L

local frame

local KEY_HEIGHT = 132
local RAID_HEIGHT = 100

local function CreateFrame_()
    frame = CreateFrame("Frame", "MythicPresetsHelperCopyFrame", UIParent, "BasicFrameTemplateWithInset")
    MPH.SkinShell(frame)
    frame:SetSize(300, KEY_HEIGHT)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    MPH.SetTitle(frame, L["copy.title"])

    frame.Box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.Box:SetSize(250, 22)
    frame.Box:SetPoint("TOP", 6, -32)
    frame.Box:SetAutoFocus(false)
    frame.Box:SetFontObject("GameFontHighlight")
    frame.Box:SetJustifyH("CENTER")
    MPH.SkinEditBox(frame.Box)
    frame.Box:SetScript("OnEscapePressed", function () frame:Hide() end)
    frame.Box:SetScript("OnEnterPressed", function () frame:Hide() end)
    frame.Box:SetScript("OnTextChanged", function (self)
        if self:GetText() ~= frame.value then self:SetText(frame.value) end
    end)

    local function OnCopy(self, key)
        if key == "C" and IsControlKeyDown() and not frame.closing then
            frame.closing = true
            C_Timer.After(0.05, function ()
                frame.closing = nil
                frame:Hide()
            end)
        end
    end
    frame.Box:SetScript("OnKeyDown", OnCopy)
    frame.Box:SetScript("OnKeyUp", OnCopy)

    frame.AheadLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.AheadLabel:SetPoint("TOPLEFT", 16, -62)
    frame.AheadLabel:SetText(L["copy.ahead"])

    frame.AheadBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.AheadBox:SetSize(40, 20)
    frame.AheadBox:SetPoint("LEFT", frame.AheadLabel, "RIGHT", 14, 0)
    frame.AheadBox:SetAutoFocus(false)
    frame.AheadBox:SetNumeric(true)
    frame.AheadBox:SetMaxLetters(1)
    MPH.SkinEditBox(frame.AheadBox)
    frame.AheadBox:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
    frame.AheadBox:SetScript("OnEnterPressed", function (self) self:ClearFocus() end)
    frame.AheadBox:SetScript("OnTextChanged", function (self)
        local value = tonumber(self:GetText())
        if not value then return end
        if value > MPH.MAX_KEY_AHEAD then
            value = MPH.MAX_KEY_AHEAD
            self:SetText(tostring(value))
        end
        MPH.db.keyAhead = value
        if frame.preset then MPH.RefreshCopyBox() end
    end)
    frame.AheadBox:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["copy.ahead"])
        GameTooltip:AddLine(L["copy.aheaddesc"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.AheadBox:SetScript("OnLeave", GameTooltip_Hide)

    frame.Hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.Hint:SetPoint("BOTTOMLEFT", 12, 12)
    frame.Hint:SetPoint("BOTTOMRIGHT", -12, 12)
    frame.Hint:SetJustifyH("CENTER")
    frame.Hint:SetText(L["copy.hint"])

    tinsert(UISpecialFrames, "MythicPresetsHelperCopyFrame")
end

function MPH.RefreshCopyBox()
    if not frame or not frame.preset then return end
    local text = MPH.Presets.SearchText(frame.preset)
    if not text then return end
    frame.value = text
    frame.Box:SetText(text)
    frame.Box:SetFocus()
    frame.Box:HighlightText()
end

function MPH.ShowCopyBox(preset)
    if not frame then CreateFrame_() end
    local text = MPH.Presets.SearchText(preset)
    if not text then return end

    local showAhead = MPH.GetPresetKind(preset) ~= "raid"
    frame:SetHeight(showAhead and KEY_HEIGHT or RAID_HEIGHT)
    frame:ClearAllPoints()

    local host = _G["MythicPresetsHelperFrame"]
    if host and host:IsVisible() then
        local top = host:GetTop()
        if top and top + KEY_HEIGHT + 8 <= UIParent:GetHeight() then
            frame:SetPoint("BOTTOM", host, "TOP", 0, 8)
        else
            frame:SetPoint("TOP", host, "BOTTOM", 0, -8)
        end
    elseif LFGListFrame and LFGListFrame:IsVisible() then
        frame:SetPoint("BOTTOM", LFGListFrame, "TOP", 0, 8)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
    end

    frame.closing = nil
    frame.preset = preset

    MPH.SetTitle(frame, showAhead and L["copy.title"] or L["copy.titleraid"])
    frame.AheadLabel:SetShown(showAhead)
    frame.AheadBox:SetShown(showAhead)
    frame.AheadBox:SetText(tostring(tonumber(MPH.db.keyAhead) or 0))
    frame.value = text
    frame.Box:SetText(text)
    frame:Show()
    frame.Box:SetFocus()
    frame.Box:HighlightText()
end

function MPH.HideCopyBox()
    if frame then frame:Hide() end
end
