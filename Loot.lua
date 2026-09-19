local ADDON, MPH = ...
local L = MPH.L

MPH.Loot = {}

local Loot = MPH.Loot

local IsSecret = issecretvalue or function () return false end

local SLOT_WORD = {
    INVTYPE_HEAD = "helm",
    INVTYPE_NECK = "neck",
    INVTYPE_SHOULDER = "shoulders",
    INVTYPE_CLOAK = "cloak",
    INVTYPE_CHEST = "chest",
    INVTYPE_ROBE = "chest",
    INVTYPE_WRIST = "bracers",
    INVTYPE_HAND = "gloves",
    INVTYPE_WAIST = "belt",
    INVTYPE_LEGS = "legs",
    INVTYPE_FEET = "boots",
    INVTYPE_FINGER = "ring",
    INVTYPE_TRINKET = "trinket",
    INVTYPE_WEAPON = "weapon",
    INVTYPE_WEAPONMAINHAND = "weapon",
    INVTYPE_WEAPONOFFHAND = "weapon",
    INVTYPE_RANGED = "weapon",
    INVTYPE_RANGEDRIGHT = "weapon",
    INVTYPE_2HWEAPON = "2H",
    INVTYPE_HOLDABLE = "off-hand",
    INVTYPE_SHIELD = "shield",
}

local SKIP_CLASS = {
    [Enum.ItemClass.Tradegoods] = true,
    [Enum.ItemClass.Reagent] = true,
}

local TEST_SLOTS = { 10, 7, 13, 16 }
local TEST_NAME = "Fera"
local TEST_CLASS = "EVOKER"

local events = CreateFrame("Frame")

local function Store()
    return MPH.charDB.loot
end

local function Refresh()
    if MPH.LootPage then MPH.LootPage.Refresh() end
end

local function IsMaterial(link)
    local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, link)
    return ok and SKIP_CLASS[classID] == true
end

function Loot.Items()
    local items = Store().items
    for index = #items, 1, -1 do
        if IsMaterial(items[index].link) then table.remove(items, index) end
    end
    return items
end

function Loot.Run()
    local store = Store()
    return store.mapID, store.level
end

function Loot.EquipLoc(link)
    local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, link)
    if ok and MPH.NotEmpty(equipLoc) then return equipLoc end
    return nil
end

local function IsMountOrPet(link)
    local ok, _, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, link)
    if not ok then return false end
    if classID == Enum.ItemClass.Battlepet then return true end
    return classID == Enum.ItemClass.Miscellaneous
        and (subClassID == Enum.ItemMiscellaneousSubclass.Mount or subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet)
end

function Loot.CanTrade(link)
    local ok, warbound = pcall(C_Item.IsItemBindToAccountUntilEquip, link)
    if ok and warbound then return false end
    local bindType = select(14, C_Item.GetItemInfo(link))
    if bindType == nil then return nil end
    if bindType == Enum.ItemBind.None or bindType == Enum.ItemBind.OnEquip or bindType == Enum.ItemBind.OnUse then
        return true
    end
    if bindType == Enum.ItemBind.OnAcquire and (SLOT_WORD[Loot.EquipLoc(link) or ""] or IsMountOrPet(link)) then
        return true
    end
    return false
end

function Loot.Message(item, whisper)
    local slot = SLOT_WORD[Loot.EquipLoc(item.link) or ""]
    local question = slot and string.format("you need %s %s?", slot, item.link)
        or string.format("you need %s?", item.link)
    if whisper then
        return (question:gsub("^%l", string.upper))
    end
    return Ambiguate(item.player, "short") .. ", " .. question
end

local function IsOwn(player)
    return Ambiguate(player, "none") == UnitName("player")
end

local function Add(link, player, class)
    table.insert(Store().items, {
        link = link,
        player = player,
        class = class,
        own = IsOwn(player),
        asked = false,
    })
    Refresh()
end

local function Reset(mapID, level)
    local store = Store()
    store.mapID = mapID or 0
    store.level = level or 0
    store.items = {}
end

function Loot.CanSend()
    if not IsInGroup() then
        MPH.Print(L["loot.nogroup"])
        return false
    end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        MPH.Print(L["loot.locked"])
        return false
    end
    return true
end

function Loot.Ask(item)
    if item.own or Loot.CanTrade(item.link) == false or not Loot.CanSend() then return end
    if MPH.SendParty(Loot.Message(item), "loot") then
        item.asked = true
        Refresh()
    end
end

function Loot.Whisper(item)
    if item.own or Loot.CanTrade(item.link) == false then return end
    local lockdown = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    local sendTell = ChatFrameUtil and ChatFrameUtil.SendTellWithMessage
    local target = Ambiguate(item.player, "none")
    if lockdown or not sendTell then
        MPH.Debug("whisper: lockdown %s, sendTell %s", tostring(lockdown), tostring(sendTell ~= nil))
        if lockdown then MPH.Print(L["loot.locked"]) end
        return
    end
    local ok, err = pcall(sendTell, target, Loot.Message(item, true), DEFAULT_CHAT_FRAME)
    MPH.Debug("whisper: target %s, open %s", target, ok and "ok" or tostring(err))
end

function Loot.Thank()
    if not Loot.CanSend() then return end
    MPH.SendParty(MPH.Thanks.GetText(), "thanks")
end

local function OnCompleted()
    local info = MPH.Progress.CompletionInfo()
    Reset(info and info.mapChallengeModeID, info and info.level)
    events:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    Refresh()
    if MPH.db.loot.autoOpen and MPH.ShowWindowPage then
        MPH.ShowWindowPage("loot")
    end
end

local function OnLoot(_, itemID, link, _, player, class)
    if IsSecret(link) or IsSecret(player) then
        MPH.Debug("loot: secret values, item %s", MPH.DescribeValue(itemID))
        return
    end
    if not link or not player then return end
    if IsMaterial(link) then
        MPH.Debug("loot: material skipped, %s", link)
        return
    end
    if IsSecret(class) then class = nil end

    MPH.Debug("loot: %s -> %s", link, player)
    Add(link, Ambiguate(player, "none"), class)
end

function Loot.Test()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    Reset(mapID, level)

    local players = {}
    for index = 1, 4 do
        local unit = "party" .. index
        local name, realm = UnitName(unit)
        if name and not IsSecret(name) and not IsSecret(realm) then
            if MPH.NotEmpty(realm) then name = name .. "-" .. realm end
            table.insert(players, { name = name, class = select(2, UnitClass(unit)) })
        end
    end

    for index, slot in ipairs(TEST_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local who = players[index] or { name = TEST_NAME, class = TEST_CLASS }
            if index == #TEST_SLOTS then
                who = { name = UnitName("player"), class = select(2, UnitClass("player")) }
            end
            Add(link, who.name, who.class)
        end
    end
    MPH.ShowWindowPage("loot")
end

events:SetScript("OnEvent", function (_, event, ...)
    if event == "CHALLENGE_MODE_COMPLETED" then
        OnCompleted()
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        OnLoot(...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        if not isLogin and not isReload then
            events:UnregisterEvent("ENCOUNTER_LOOT_RECEIVED")
            events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end
end)

table.insert(MPH.onLogin, function ()
    events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
end)
