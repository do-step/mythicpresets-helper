local ADDON, MPH = ...

local ITEM = 6948
local BATCH = 40
local RETRY_DELAY = 3
local LOGIN_DELAY = 2
local EVENT_DELAY = 1
local MAX_ATTEMPTS = 5
local EXCLUDED = {
    [110560] = true,
    [140192] = true,
}

local IsSecret = issecretvalue or function () return false end

MPH.Hearthstone = {
    ITEM = ITEM,
}

local found = {}
local foundCount = 0
local usable = {}
local list = {}
local owned = 0
local deck = {}
local current
local generation = 0
local attempts = 0
local scheduled = false
local Schedule

local function WithOpenToyFilters(scan)
    local saved = {
        collected = C_ToyBox.GetCollectedShown(),
        uncollected = C_ToyBox.GetUncollectedShown(),
        unusable = C_ToyBox.GetUnusableShown(),
        sources = {},
        expansions = {},
    }
    local numSources = C_PetJournal.GetNumPetSources()
    for i = 1, numSources do
        saved.sources[i] = C_ToyBox.IsSourceTypeFilterChecked(i)
    end
    local numExpansions = GetNumExpansions()
    for i = 1, numExpansions do
        saved.expansions[i] = C_ToyBox.IsExpansionTypeFilterChecked(i)
    end
    local search = ToyBox and ToyBox.searchString or ""

    C_ToyBox.SetCollectedShown(true)
    C_ToyBox.SetUncollectedShown(false)
    C_ToyBox.SetUnusableShown(true)
    C_ToyBox.SetAllSourceTypeFilters(true)
    C_ToyBox.SetAllExpansionTypeFilters(true)
    C_ToyBox.SetFilterString("")
    C_ToyBox.ForceToyRefilter()

    local ok, err = pcall(scan)

    C_ToyBox.SetCollectedShown(saved.collected)
    C_ToyBox.SetUncollectedShown(saved.uncollected)
    C_ToyBox.SetUnusableShown(saved.unusable)
    for i = 1, numSources do
        C_ToyBox.SetSourceTypeFilter(i, saved.sources[i])
    end
    for i = 1, numExpansions do
        C_ToyBox.SetExpansionTypeFilter(i, saved.expansions[i])
    end
    C_ToyBox.SetFilterString(search)
    C_ToyBox.ForceToyRefilter()
    if ToyBox and ToyBox:IsVisible() then
        if ToyBox_UpdatePages then ToyBox_UpdatePages() end
        if ToyBox_UpdateButtons then ToyBox_UpdateButtons() end
    end

    if not ok then error(err, 0) end
end

local function OwnedToys()
    local toys = {}
    WithOpenToyFilters(function ()
        for index = 1, C_ToyBox.GetNumFilteredToys() or 0 do
            local id = C_ToyBox.GetToyFromIndex(index)
            if id and id > 0 and not EXCLUDED[id] and PlayerHasToy(id) then
                table.insert(toys, id)
            end
        end
    end)
    return toys
end

local function Check(id, location)
    local data = C_TooltipInfo.GetToyByItemID(id)
    if not data or not data.lines then return nil end

    local result
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text and not IsSecret(text) and text:find(ITEM_SPELL_TRIGGER_ONUSE, 1, true) == 1 then
            if text:find(location, 1, true) then return true end
            result = false
        end
    end
    return result
end

local function Shuffle(items)
    for i = #items, 2, -1 do
        local j = math.random(i)
        items[i], items[j] = items[j], items[i]
    end
    return items
end

local function Draw()
    while #deck > 0 do
        local id = table.remove(deck)
        if id ~= current and usable[id] then return id end
    end

    deck = Shuffle(CopyTable(list))
    if #deck > 1 and deck[#deck] == current then
        deck[1], deck[#deck] = deck[#deck], deck[1]
    end
    return table.remove(deck)
end

local function Finish(gen, stones, total)
    if gen ~= generation then return end

    found = stones
    foundCount = 0
    usable = {}
    list = {}
    for id in pairs(stones) do
        foundCount = foundCount + 1
        if C_ToyBox.IsToyUsable(id) then
            usable[id] = true
            table.insert(list, id)
        end
    end
    table.sort(list)
    owned = total
    deck = {}
    if current and not usable[current] then current = nil end
    MPH.Debug("hearthstone: %d usable, %d found, %d toys", #list, foundCount, total)
end

local function Pass(gen, toys, location, stones, retry, done)
    local index = 0
    local function Step()
        if gen ~= generation then return end
        for _ = 1, BATCH do
            index = index + 1
            local id = toys[index]
            if not id then return done() end

            local result = Check(id, location)
            if result then
                stones[id] = true
            elseif result == nil and retry then
                table.insert(retry, id)
                C_Item.RequestLoadItemDataByID(id)
            end
        end
        C_Timer.After(0, Step)
    end
    Step()
end

local function Scan()
    generation = generation + 1
    local gen = generation

    local location = GetBindLocation()
    if not location or IsSecret(location) or location == "" then return end

    local toys = OwnedToys()
    if #toys == 0 then
        attempts = attempts + 1
        if attempts < MAX_ATTEMPTS then Schedule(RETRY_DELAY) end
        return
    end
    attempts = 0

    local stones, retry = {}, {}
    Pass(gen, toys, location, stones, retry, function ()
        if #retry == 0 then return Finish(gen, stones, #toys) end
        C_Timer.After(RETRY_DELAY, function ()
            Pass(gen, retry, location, stones, nil, function ()
                Finish(gen, stones, #toys)
            end)
        end)
    end)
end

function Schedule(delay)
    if scheduled then return end
    scheduled = true
    C_Timer.After(delay, function ()
        scheduled = false
        Scan()
    end)
end

function MPH.Hearthstone.IsRandom()
    local config = MPH.db and MPH.db.teleport
    return not config or config.randomStone ~= false
end

local function UseStandard()
    return not MPH.Hearthstone.IsRandom() and C_Item.GetItemCount(ITEM) > 0
end

function MPH.Hearthstone.SetRandom(value)
    if not MPH.db or not MPH.db.teleport then return end
    MPH.db.teleport.randomStone = value and true or false
    if value and #list > 0 then
        current = Draw()
    end
end

function MPH.Hearthstone.Get()
    if UseStandard() then
        return ITEM, false, 0
    end

    if #list > 0 then
        if not current or not usable[current] then
            current = Draw()
        end
        return current, true, #list
    end

    current = nil
    if C_Item.GetItemCount(ITEM) > 0 then
        return ITEM, false, 0
    end
end

function MPH.Hearthstone.Next()
    if #list > 0 and not UseStandard() then
        current = Draw()
    end
    return MPH.Hearthstone.Get()
end

function MPH.Hearthstone.Describe()
    local ids = {}
    for id in pairs(found) do table.insert(ids, id) end
    table.sort(ids)

    local parts = {}
    for _, id in ipairs(ids) do
        table.insert(parts, usable[id] and tostring(id) or (id .. "-"))
    end
    return string.format("mode %s, %d usable of %d found, %d toys, bind %s, current %s: %s",
        MPH.Hearthstone.IsRandom() and "random" or "standard",
        #list, foundCount, owned, tostring(GetBindLocation()), tostring(current), table.concat(parts, ", "))
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function ()
    Schedule(EVENT_DELAY)
end)

table.insert(MPH.onLogin, function ()
    events:RegisterEvent("NEW_TOY_ADDED")
    events:RegisterEvent("HEARTHSTONE_BOUND")
    events:RegisterEvent("COVENANT_CHOSEN")
    Schedule(LOGIN_DELAY)
end)
