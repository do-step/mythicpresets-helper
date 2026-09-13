local ADDON, MPH = ...
local L = MPH.L

if not MPH.SLANG_TEXT then return end

local TEXT_WIDTH = 264
local CHILD_WIDTH = 276
local PADDING = 10
local SCROLLBAR_WIDTH = 28
local INDENT = 14
local TAG_WIDTH = 48
local ENTRY_GAP = 9
local DETAIL_GAP = 2
local SECTION_GAP = 20
local HEADER_ICON = 20
local SPEC_ICON = 16
local SPELL_ICON = 16
local MENU_ICON = 16

local GOLD = "|cffffd100%s|r"
local GREY = "|cff909090%s|r"
local PLAIN = "%s"

local DETAIL_COLOR = { 0.75, 0.75, 0.75 }
local TAG_COLORS = {
    ["cc"] = { 1, 0.6, 0.2 },
    ["aoe cc"] = { 1, 0.3, 0.3 },
}

local text = MPH.SLANG_TEXT

local function FormatTerms(terms, color)
    local parts = {}
    for term in string.gmatch(terms, "[^,]+") do
        term = strtrim(term)
        local word, english = term:match("^(.-)%s*%((.-)%)$")
        local formatted = string.format(color, word or term)
        if english then
            formatted = formatted .. " " .. string.format(GREY, "(" .. english .. ")")
        end
        table.insert(parts, formatted)
    end
    return table.concat(parts, ", ")
end

local function Lookup(group, key)
    return text[group] and text[group][key]
end

local page, child, dropdown
local texts, tags = {}, {}
local selectedClass

local function Pack(ok, ...)
    if ok then return ... end
end

local function Call(fn, ...)
    if not fn then return nil end
    return Pack(pcall(fn, ...))
end

local function ClassList()
    local list = {}
    for classID = 1, Call(GetNumClasses) or 0 do
        local name, file = Call(GetClassInfo, classID)
        if name and file then
            table.insert(list, { id = classID, name = name, file = file })
        end
    end
    return list
end

local function ColoredClassName(file, name)
    local color = C_ClassColor and C_ClassColor.GetClassColor(file)
    return color and color:WrapTextInColorCode(name) or name
end

local function ClassIcon(file, size)
    local atlas = "classicon-" .. file:lower()
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then return "" end
    return CreateAtlasMarkup(atlas, size, size) .. " "
end

local function TextureIcon(texture, size)
    if not texture then return "" end
    return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t ", texture, size, size)
end

local function CurrentSpecID()
    local api = C_SpecializationInfo
    local index = Call(api and api.GetSpecialization or GetSpecialization)
    if not index or index == 0 then return nil end
    return (Call(api and api.GetSpecializationInfo or GetSpecializationInfo, index))
end

local function SectionDetail(key)
    local detail = Lookup("details", key)
    if detail then return detail end
    if key:find("^INVTYPE_") then return _G[key] end
    return nil
end

local function CollectLines()
    local lines = {}
    local function Add(line)
        table.insert(lines, line)
    end
    local function AddEntry(terms, detail, tag, icon)
        Add({ text = TextureIcon(icon, SPELL_ICON) .. FormatTerms(terms, GOLD), font = "GameFontHighlight", gap = ENTRY_GAP })
        Add({ text = detail, font = "GameFontHighlight", gap = DETAIL_GAP, indent = INDENT,
              color = DETAIL_COLOR, tag = tag })
    end

    local _, ownFile = UnitClass("player")
    local classFile = selectedClass or ownFile
    local className, classID = classFile, nil
    for _, class in ipairs(ClassList()) do
        if class.file == classFile then
            className, classID = class.name, class.id
        end
    end

    Add({ text = ClassIcon(classFile, HEADER_ICON) .. ColoredClassName(classFile, className),
          font = "GameFontNormalLarge", gap = 0 })
    Add({ text = L["slang.status"], font = "GameFontNormal", gap = 6, color = { ORANGE_FONT_COLOR:GetRGB() } })
    if GetLocale() ~= "ruRU" then
        Add({ text = L["slang.feedback"], font = "GameFontDisableSmall", gap = 2 })
    end

    local names = Lookup("names", classFile)
    if names then
        Add({ text = string.format(L["slang.classnames"], FormatTerms(names, GOLD)),
              font = "GameFontHighlight", gap = 10 })
    end
    local armor = MPH.CLASS_ARMOR and Lookup("armor", MPH.CLASS_ARMOR[classFile] or "")
    if armor then
        Add({ text = string.format(L["slang.armor"], FormatTerms(armor, GOLD)),
              font = "GameFontHighlight", gap = 4 })
    end

    Add({ text = L["slang.specs"], font = "GameFontNormalMed3", gap = SECTION_GAP })
    local currentID = classFile == ownFile and CurrentSpecID() or nil
    for i = 1, Call(GetNumSpecializationsForClassID, classID) or 0 do
        local specID, specName, _, specIcon = Call(GetSpecializationInfoForClassID, classID, i)
        if specID then
            local abbr = Lookup("specs", specID)
            local line = abbr and string.format("%s: %s", specName, FormatTerms(abbr, PLAIN)) or specName
            line = TextureIcon(specIcon, SPEC_ICON) .. line
            if specID == currentID then
                Add({ text = string.format(L["slang.currentspec"], line), font = "GameFontNormal", gap = 6 })
            else
                Add({ text = line, font = "GameFontDisable", gap = 6 })
            end
        end
    end

    local spells = {}
    for _, spell in ipairs(MPH.SLANG.classes[classFile] or {}) do
        local term = Lookup("spells", spell[1])
        local name = term and C_Spell.GetSpellName(spell[1])
        if name then
            table.insert(spells, { term = term, name = name, tag = spell[2],
                                   icon = C_Spell.GetSpellTexture(spell[1]) })
        end
    end
    if #spells > 0 then
        Add({ text = L["slang.spells"], font = "GameFontNormalMed3", gap = SECTION_GAP })
        for _, spell in ipairs(spells) do
            AddEntry(spell.term, spell.name, spell.tag, spell.icon)
        end
    end

    for _, section in ipairs(MPH.SLANG.sections) do
        local entries = {}
        for _, key in ipairs(section.keys) do
            local term, detail = Lookup("terms", key), SectionDetail(key)
            if term and detail then
                table.insert(entries, { term = term, detail = detail })
            end
        end
        if #entries > 0 then
            Add({ text = L[section.title], font = "GameFontNormalMed3", gap = SECTION_GAP })
            for _, entry in ipairs(entries) do
                AddEntry(entry.term, entry.detail)
            end
        end
    end
    return lines
end

local function Refresh()
    if not page or not page:IsVisible() then return end

    local lines = CollectLines()
    local y = PADDING
    for index, line in ipairs(lines) do
        local fontString = texts[index]
        if not fontString then
            fontString = child:CreateFontString(nil, "ARTWORK")
            fontString:SetJustifyH("LEFT")
            texts[index] = fontString
        end

        local indent = line.indent or 0
        fontString:SetFontObject(line.font)
        if line.color then
            fontString:SetTextColor(unpack(line.color))
        else
            fontString:SetTextColor(_G[line.font]:GetTextColor())
        end
        fontString:SetWidth(TEXT_WIDTH - indent - (line.tag and TAG_WIDTH or 0))
        y = y + line.gap
        fontString:ClearAllPoints()
        fontString:SetPoint("TOPLEFT", child, "TOPLEFT", 8 + indent, -y)
        fontString:SetText(line.text)
        fontString:Show()

        local tag = tags[index]
        if line.tag then
            if not tag then
                tag = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                tag:SetJustifyH("RIGHT")
                tag:SetWidth(TAG_WIDTH)
                tags[index] = tag
            end
            tag:ClearAllPoints()
            tag:SetPoint("TOPLEFT", fontString, "TOPRIGHT", 0, -1)
            tag:SetText(line.tag)
            tag:SetTextColor(unpack(TAG_COLORS[line.tag] or DETAIL_COLOR))
            tag:Show()
        elseif tag then
            tag:Hide()
        end

        y = y + fontString:GetStringHeight()
    end
    for index = #lines + 1, #texts do
        texts[index]:Hide()
        if tags[index] then tags[index]:Hide() end
    end
    child:SetHeight(y + PADDING)
end

local function Build(container)
    page = container

    dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", page, "TOPLEFT", 18, -32)
    dropdown:SetWidth(180)
    MPH.SkinDropdown(dropdown)
    dropdown:SetupMenu(function (_, root)
        local _, ownFile = UnitClass("player")
        for _, class in ipairs(ClassList()) do
            root:CreateRadio(ClassIcon(class.file, MENU_ICON) .. ColoredClassName(class.file, class.name),
                function (file) return (selectedClass or ownFile) == file end,
                function (file)
                    selectedClass = file
                    Refresh()
                end,
                class.file)
        end
    end)

    page:GetParent():HookScript("OnHide", function ()
        selectedClass = nil
        dropdown:GenerateMenu()
    end)

    local scroll = CreateFrame("ScrollFrame", "MythicPresetsHelperSlangScrollFrame", page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -64)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 10)
    MPH.SkinScroll(scroll)

    child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(CHILD_WIDTH)
    scroll:SetScrollChild(child)

    page:HookScript("OnShow", Refresh)
end

MPH.RegisterWindowPage({
    key = "slang",
    order = 5,
    icon = "Interface\\Icons\\INV_Scroll_03",
    title = L["tabs.slang"],
    build = Build,
    refresh = Refresh,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:SetScript("OnEvent", Refresh)
