local ADDON, MPH = ...
local L = MPH.L

table.insert(MPH.onLogin, function ()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    local category, layout = Settings.RegisterVerticalLayoutCategory(L["window.title"])

    if layout and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(L["settings.onboarding"],
            L["settings.onboardingbutton"], function ()
                MPH.ShowWindowPage("help")
            end, L["settings.onboardingdesc"], true))
    end

    local autoOpen = Settings.RegisterAddOnSetting(category, "MPH_AutoOpen", "autoOpen",
        MPH.db.window, "boolean", L["settings.autoopen"], true)
    Settings.CreateCheckbox(category, autoOpen, L["settings.autoopendesc"])

    local teleport = Settings.RegisterAddOnSetting(category, "MPH_TeleportEnabled", "enabled",
        MPH.db.teleport, "boolean", L["settings.teleport"], true)
    teleport:SetValueChangedCallback(function ()
        MPH.Teleport.Apply()
    end)
    Settings.CreateCheckbox(category, teleport, L["settings.teleportdesc"])

    local thanks = Settings.RegisterAddOnSetting(category, "MPH_ThanksEnabled", "enabled",
        MPH.db.thanks, "boolean", L["settings.thanks"], false)
    Settings.CreateCheckbox(category, thanks, L["settings.thanksdesc"])

    local loot = Settings.RegisterAddOnSetting(category, "MPH_LootAutoOpen", "autoOpen",
        MPH.db.loot, "boolean", L["settings.loot"], true)
    Settings.CreateCheckbox(category, loot, L["settings.lootdesc"])

    local errors = Settings.RegisterAddOnSetting(category, "MPH_SuppressErrors", "enabled",
        MPH.db.errors, "boolean", L["settings.errors"], true)
    errors:SetValueChangedCallback(function ()
        MPH.Errors.Apply()
    end)
    Settings.CreateCheckbox(category, errors, L["settings.errorsdesc"])

    if Settings.CreateDropdown and Settings.CreateControlTextContainer then
        local playstyle = Settings.RegisterAddOnSetting(category, "MPH_Playstyle", "value",
            MPH.db.playstyle, "number", L["settings.playstyle"], 2)
        Settings.CreateDropdown(category, playstyle, function ()
            local container = Settings.CreateControlTextContainer()
            container:Add(0, L["settings.playstylenone"])
            for value = 1, 4 do
                container:Add(value, _G["GROUP_FINDER_GENERAL_PLAYSTYLE" .. value] or tostring(value))
            end
            return container:GetData()
        end, L["settings.playstyledesc"])
    end

    local reqScore = Settings.RegisterAddOnSetting(category, "MPH_RequireScore", "score",
        MPH.db.requirements, "boolean", L["settings.reqscore"], true)
    Settings.CreateCheckbox(category, reqScore, L["settings.reqscoredesc"])

    local reqItemLevel = Settings.RegisterAddOnSetting(category, "MPH_RequireItemLevel", "itemLevel",
        MPH.db.requirements, "boolean", L["settings.reqilvl"], true)
    Settings.CreateCheckbox(category, reqItemLevel, L["settings.reqilvldesc"])

    Settings.RegisterAddOnCategory(category)
    MPH.settingsCategory = category
end)
