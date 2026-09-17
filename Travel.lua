local ADDON, MPH = ...

local GCD_THRESHOLD = 2

local FIXED = {
    { kind = "toy", id = 253629, place = "teleport.toyplace" },
    { kind = "toy", id = 266370, place = "teleport.dandan" },
    { kind = "toy", id = 140192, place = "teleport.dalaran" },
    { kind = "spell", id = 265225 },
    { kind = "spell", id = 312372 },
    { kind = "spell", id = 193753 },
    { kind = "spell", id = 50977 },
    { kind = "spell", id = 126892 },
    { kind = "spell", id = 556 },
}

local IsSecret = issecretvalue or function () return false end

MPH.Travel = {}

local list = {}
local deck = {}
local current
local fixedCurrent
local random = false
local missing = {}
local toyEntries = {}

local function ToyEntry(id)
    toyEntries[id] = toyEntries[id] or { kind = "toy", id = id }
    return toyEntries[id]
end

local function Shuffle(items)
    for i = #items, 2, -1 do
        local j = math.random(i)
        items[i], items[j] = items[j], items[i]
    end
    return items
end

local function IsToyAvailable(id)
    return PlayerHasToy(id) and C_ToyBox.IsToyUsable(id)
end

local function IsReady(id)
    if not IsToyAvailable(id) then return false end
    local start, duration = C_Container.GetItemCooldown(id)
    if not start or not duration or IsSecret(start) or IsSecret(duration) then return true end
    return duration <= GCD_THRESHOLD or start + duration <= GetTime()
end

local function Ready()
    local ready = {}
    for _, id in ipairs(list) do
        if IsReady(id) then table.insert(ready, id) end
    end
    return ready
end

local function Draw()
    while #deck > 0 do
        local id = table.remove(deck)
        if id ~= current and IsReady(id) then return id end
    end

    deck = Shuffle(Ready())
    if #deck > 1 and deck[#deck] == current then
        deck[1], deck[#deck] = deck[#deck], deck[1]
    end
    return table.remove(deck)
end

local function IsFixedAvailable(entry)
    if entry.kind == "toy" then return IsToyAvailable(entry.id) end
    return IsPlayerSpell(entry.id)
end

local function AvailableFixed()
    local available = {}
    for _, entry in ipairs(FIXED) do
        if IsFixedAvailable(entry) then table.insert(available, entry) end
    end
    return available
end

local function Cycle(items, selected, delta)
    local index = delta > 0 and 0 or 1
    for i, item in ipairs(items) do
        if item == selected then index = i end
    end
    return items[(index - 1 + delta) % #items + 1]
end

function MPH.Travel.SetToys(toys)
    list = {}
    for id in pairs(toys) do table.insert(list, id) end
    table.sort(list)
    deck = {}
    if current and not toys[current] then current = nil end
    return #list
end

function MPH.Travel.SetMissing(ids)
    missing = ids
end

function MPH.Travel.GetMissing()
    return missing
end

function MPH.Travel.IsRandom()
    return random
end

function MPH.Travel.SetRandom(value)
    random = value and true or false
end

function MPH.Travel.IsLoading()
    return MPH.Travel.IsRandom() and #list == 0 and not MPH.Hearthstone.IsSettled()
end

function MPH.Travel.Get()
    if not MPH.Travel.IsRandom() then
        local available = AvailableFixed()
        if not fixedCurrent or not IsFixedAvailable(fixedCurrent) then
            fixedCurrent = available[1]
        end
        return fixedCurrent, #available, fixedCurrent and tIndexOf(available, fixedCurrent) or 0
    end

    if current and not IsReady(current) then current = nil end
    if not current and #list > 0 then current = Draw() end
    local ready = Ready()
    return current and ToyEntry(current), #ready, current and tIndexOf(ready, current) or 0
end

function MPH.Travel.Reset()
    random = false
    fixedCurrent = nil
end

function MPH.Travel.Step(delta)
    if MPH.Travel.IsRandom() then
        local ready = Ready()
        if #ready > 0 then current = Cycle(ready, current, delta) end
    else
        local available = AvailableFixed()
        if #available > 0 then fixedCurrent = Cycle(available, fixedCurrent, delta) end
    end
    return MPH.Travel.Get()
end

function MPH.Travel.Describe()
    local fixed = {}
    for _, entry in ipairs(FIXED) do
        table.insert(fixed, IsFixedAvailable(entry) and (entry.id .. "+") or tostring(entry.id))
    end
    local found = {}
    for _, id in ipairs(list) do
        table.insert(found, IsReady(id) and (id .. "+") or tostring(id))
    end
    return string.format("mode %s, fixed %s [%s], random %s, %d found [%s], %d missing [%s]",
        MPH.Travel.IsRandom() and "random" or "fixed",
        fixedCurrent and tostring(fixedCurrent.id) or "-", table.concat(fixed, ", "),
        tostring(current), #list, table.concat(found, ", "),
        #missing, table.concat(missing, ", "))
end
