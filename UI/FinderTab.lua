local ADDON, MPH = ...
local L = MPH.L

local tab

local function IsWindowShown()
    local window = _G["MythicPresetsHelperFrame"]
    return window ~= nil and window:IsShown()
end

local function AnchorTab()
    tab:ClearAllPoints()
    local first = _G["PVEFrameTab1"]
    local top = first and first:GetTop()
    local bottom = PVEFrame:GetBottom()
    local y = (top and bottom) and (top - bottom) or 2
    tab:SetPoint("TOPRIGHT", PVEFrame, "BOTTOMRIGHT", -3, y)
end

local function SetSelected(selected)
    tab.isSelected = selected
    if selected then
        tab:LockHighlight()
    else
        tab:UnlockHighlight()
    end
    MPH.SkinTab(tab)
end

local function TabTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["window.title"], 1, 1, 1)
    GameTooltip:AddLine(L["toggle.tooltip"], nil, nil, nil, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["toggle.pin"], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function EnsureTab()
    if tab then return tab end
    if not PVEFrame or not MPH.db then return nil end

    tab = CreateFrame("Button", "MythicPresetsHelperFinderTab", PVEFrame, "PanelTabButtonTemplate")
    tab:SetText("MPH")
    PanelTemplates_TabResize(tab)
    PanelTemplates_DeselectTab(tab)
    MPH.SkinTab(tab)
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tab:SetScript("OnClick", function (_, mouseButton)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        if mouseButton == "RightButton" then
            MPH.PinWindowBesideGroupFinder()
            return
        end
        MPH.ToggleWindow()
    end)
    tab:SetScript("OnEnter", TabTooltip)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    tab:Hide()
    return tab
end

function MPH.RefreshFinderTab()
    if not EnsureTab() then return end
    local onScreen = MPH.IsGroupFinderPage()
    tab:SetShown(onScreen)
    if not onScreen then return end
    AnchorTab()
    SetSelected(IsWindowShown())
end

function MPH.DescribeFinderTab()
    if not tab then
        return string.format("not created (PVEFrame: %s)", tostring(PVEFrame ~= nil))
    end

    local function Edge(frame, getter)
        local value = frame and frame[getter] and frame[getter](frame)
        return value and tostring(math.floor(value)) or "?"
    end

    return string.format("shown %s, screen %s, window %s, x %s..%s, y %s, PVEFrame x %s..%s",
        tostring(tab:IsShown()), tostring(MPH.IsFinderScreen()), tostring(IsWindowShown()),
        Edge(tab, "GetLeft"), Edge(tab, "GetRight"), Edge(tab, "GetTop"),
        Edge(PVEFrame, "GetLeft"), Edge(PVEFrame, "GetRight"))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function (self)
    if EnsureTab() then
        self:UnregisterAllEvents()
    end
end)

table.insert(MPH.onLogin, function ()
    MPH.RefreshFinderTab()
end)
