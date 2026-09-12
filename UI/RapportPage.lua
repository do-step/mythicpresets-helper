local ADDON, MPH = ...
local L = MPH.L

local TEXT_WIDTH = 276

local function Build(page)
    page.Title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    page.Title:SetPoint("TOPLEFT", page, "TOPLEFT", 22, -40)
    page.Title:SetText(L["rapport.title"])

    page.Status = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    page.Status:SetPoint("TOPLEFT", page.Title, "BOTTOMLEFT", 0, -8)
    page.Status:SetTextColor(ORANGE_FONT_COLOR:GetRGB())
    page.Status:SetText(L["rapport.status"])

    page.Description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    page.Description:SetPoint("TOPLEFT", page.Status, "BOTTOMLEFT", 0, -14)
    page.Description:SetWidth(TEXT_WIDTH)
    page.Description:SetJustifyH("LEFT")
    page.Description:SetText(L["rapport.desc"])
end

MPH.RegisterWindowPage({
    key = "rapport",
    order = 6,
    icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
    title = L["tabs.rapport"],
    build = Build,
})
