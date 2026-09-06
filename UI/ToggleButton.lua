local ADDON, MPH = ...
local L = MPH.L

local button

local function GetPanel()
    return LFGListFrame and LFGListFrame.SearchPanel or nil
end

local function PlaceLabel(side)
    if not button.Text then return end
    button.Text:ClearAllPoints()
    if side == "left" then
        button.Text:SetPoint("RIGHT", button, "LEFT", 0, 0)
        button.Text:SetJustifyH("RIGHT")
        button:SetHitRectInsets(-34, -2, -2, -2)
    else
        button.Text:SetPoint("LEFT", button, "RIGHT", 0, 0)
        button.Text:SetJustifyH("LEFT")
        button:SetHitRectInsets(-2, -34, -2, -2)
    end
end

local function AnchorButton()
    local panel = GetPanel()
    if not button or not panel then return end

    button:ClearAllPoints()

    local pgf = _G["UsePGFButton"]
    if pgf and pgf:IsShown() then
        button:SetPoint("RIGHT", pgf, "LEFT", -2, 0)
        PlaceLabel("left")
        button.anchorKind = "pgf"
    elseif panel.CategoryName then
        button:SetPoint("LEFT", panel.CategoryName, "RIGHT", -8, 0)
        PlaceLabel("right")
        button.anchorKind = "category"
    else
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -6)
        PlaceLabel("right")
        button.anchorKind = "panel"
    end
end

local function ButtonTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["window.title"], 1, 1, 1)
    GameTooltip:AddLine(L["toggle.tooltip"], nil, nil, nil, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["toggle.pin"], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function EnsureButton()
    if button then return button end

    local panel = GetPanel()
    if not panel or not MPH.db then return nil end

    button = CreateFrame("CheckButton", "MythicPresetsHelperToggleButton", panel, "UICheckButtonTemplate")
    button:SetSize(26, 26)
    button:SetFrameLevel(panel:GetFrameLevel() + 10)
    button:SetChecked(MPH.db.window.shown and true or false)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    if button.Text then
        button.Text:SetText("MPH")
        button.Text:SetFontObject("GameFontHighlight")
        button.Text:SetWidth(34)
    end

    button:SetScript("OnClick", function (self, mouseButton)
        if mouseButton == "RightButton" then
            self:SetChecked(MPH.db.window.shown and true or false)
            MPH.PinWindowBesideGroupFinder()
            return
        end
        MPH.db.window.shown = self:GetChecked() and true or false
        MPH.UpdateWindowVisibility()
    end)
    button:SetScript("OnEnter", ButtonTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)

    AnchorButton()
    return button
end

function MPH.RefreshToggleButton()
    if not EnsureButton() then return end
    button:SetChecked(MPH.db.window.shown and true or false)
    AnchorButton()
end

function MPH.DescribeToggleButton()
    local panel = GetPanel()
    if not button then
        return string.format("not created (search panel: %s)", tostring(panel ~= nil))
    end

    local function Edge(frame, getter)
        local value = frame and frame[getter] and frame[getter](frame)
        return value and tostring(math.floor(value)) or "?"
    end

    return string.format("shown %s, visible %s, alpha %.1f, level %d, x %s..%s, y %s, anchor %s, panel x %s..%s",
        tostring(button:IsShown()), tostring(button:IsVisible()), button:GetEffectiveAlpha(),
        button:GetFrameLevel(),
        Edge(button, "GetLeft"), Edge(button, "GetRight"), Edge(button, "GetTop"),
        tostring(button.anchorKind),
        Edge(panel, "GetLeft"), Edge(panel, "GetRight"))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function (self)
    if EnsureButton() then
        self:UnregisterAllEvents()
    end
end)

table.insert(MPH.onLogin, function ()
    MPH.RefreshToggleButton()
end)
