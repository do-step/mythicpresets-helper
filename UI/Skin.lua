local ADDON, MPH = ...

local EDIT_BOX_INSET = 5
local SIDE_TAB_SELECTED_ALPHA = 0.45

local SIDE_TAB_COLORS = {
    border = { 0.35, 0.35, 0.35, 1 },
    background = { 0.06, 0.06, 0.06, 0.95 },
    selected = { 0.45, 0.33, 0.05, 0.95 },
}

local skin
local pending = EllesmereUI and EllesmereUI.RegisterSkin and {} or nil

local SKINNERS = {
    shell = function (frame)
        skin.Shell(frame)
        if frame.CloseButton then skin.CloseButton(frame.CloseButton) end
        if frame.Inset then skin.Inset(frame.Inset) end
    end,
    button = function (button)
        skin.Button(button)
        skin.StateButtonLabel(button)
    end,
    editBox = function (editBox)
        skin.EditBox(editBox)
        editBox:SetTextInsets(EDIT_BOX_INSET, EDIT_BOX_INSET, 0, 0)
    end,
    check = function (check)
        skin.Checkbox(check)
    end,
    dropdown = function (dropdown)
        skin.Dropdown(dropdown)
    end,
    scroll = function (scroll)
        if scroll.ScrollBar then skin.ScrollBar(scroll.ScrollBar) end
    end,
    icon = function (icon, parent)
        skin.SquareIcon(icon, parent)
    end,
    tab = function (tab)
        skin.Tab(tab)
        local first = _G["PVEFrameTab1"]
        if first then tab:SetHeight(first:GetHeight()) end
    end,
}

local function Apply(kind, object, parent)
    if not object then return end
    if skin then
        SKINNERS[kind](object, parent)
    elseif pending then
        pending[object] = { kind = kind, parent = parent }
    end
end

local function Repaint()
    if MPH.RepaintSideTabs then MPH.RepaintSideTabs() end
end

function MPH.GetSideTabColors()
    if not skin then return SIDE_TAB_COLORS end
    local r, g, b, a = skin.GetPanelColor()
    local accentR, accentG, accentB = skin.GetAccentColor()
    return {
        border = { 0.2, 0.2, 0.2, 1 },
        background = { r, g, b, a },
        selected = { accentR, accentG, accentB, SIDE_TAB_SELECTED_ALPHA },
    }
end

function MPH.SkinShell(frame)
    Apply("shell", frame)
end

function MPH.SkinButton(button)
    Apply("button", button)
end

function MPH.SkinEditBox(editBox)
    Apply("editBox", editBox)
end

function MPH.SkinCheck(check)
    Apply("check", check)
end

function MPH.SkinDropdown(dropdown)
    Apply("dropdown", dropdown)
end

function MPH.SkinScroll(scroll)
    Apply("scroll", scroll)
end

function MPH.SkinIcon(icon, parent)
    Apply("icon", icon, parent)
end

function MPH.SkinTab(tab)
    Apply("tab", tab)
end

if pending then
    EllesmereUI.RegisterSkin(ADDON, function (S)
        skin = S
        local queued = pending
        pending = nil
        for object, entry in pairs(queued) do
            SKINNERS[entry.kind](object, entry.parent)
        end
        S.OnLooksChanged(Repaint)
        Repaint()
    end)
end
