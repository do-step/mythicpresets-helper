local ADDON, MPH = ...
local L = MPH.L

MPH.Thanks = {}

local Thanks = MPH.Thanks

local MAX_BYTES = 255
local POPUP = "MPH_THANKS_TEXT"

local function Config()
    return MPH.db.thanks
end

function Thanks.GetText()
    local text = MPH.charDB and MPH.charDB.thanks and MPH.charDB.thanks.text
    if not MPH.NotEmpty(text) then return MPH.THANKS_DEFAULT end
    return text
end

function Thanks.SetText(text)
    text = tostring(text or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    MPH.charDB.thanks.text = MPH.NotEmpty(text) and text or MPH.THANKS_DEFAULT
    if MPH.LootPage then MPH.LootPage.Refresh() end
end

local function OnCompleted()
    if not Config().enabled then return end
    local info = MPH.Progress.CompletionInfo()
    if not info or not info.onTime or info.practiceRun then return end
    if not IsInGroup(LE_PARTY_CATEGORY_HOME) then return end
    MPH.SendParty(Thanks.GetText(), "thanks")
end

local function EditBox(dialog)
    return dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
end

StaticPopupDialogs[POPUP] = {
    text = L["thanks.edit"],
    button1 = SAVE,
    button2 = CANCEL,
    button3 = L["thanks.default"],
    hasEditBox = true,
    maxBytes = MAX_BYTES + 1,
    editBoxWidth = 300,
    OnShow = function (self)
        local editBox = EditBox(self)
        editBox:SetText(Thanks.GetText())
        editBox:HighlightText()
    end,
    OnAccept = function (self)
        Thanks.SetText(EditBox(self):GetText())
    end,
    OnAlt = function ()
        Thanks.SetText(MPH.THANKS_DEFAULT)
    end,
    EditBoxOnEnterPressed = function (editBox)
        Thanks.SetText(editBox:GetText())
        StaticPopup_Hide(POPUP)
    end,
    EditBoxOnEscapePressed = function ()
        StaticPopup_Hide(POPUP)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Thanks.ShowEditor()
    StaticPopup_Show(POPUP)
end

table.insert(MPH.onLogin, function ()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:SetScript("OnEvent", OnCompleted)
end)
