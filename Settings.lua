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

    Settings.RegisterAddOnCategory(category)
    MPH.settingsCategory = category
end)
