local ADDON, MPH = ...

local IsSecret = issecretvalue or function () return false end

local LINES = 10
local WIDTH = 520
local HEIGHT = 260
local SCROLLBAR_WIDTH = 28
local FOOTER_HEIGHT = 44

local frame

local function Clean(text)
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    text = text:gsub("|K.-|k", "")
    text = text:gsub("|cn[^:]*:", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|n", " ")
    text = text:gsub("||", "|")
    return text
end

local function ReadLines()
    local chat = DEFAULT_CHAT_FRAME
    local lines, hidden = {}, 0
    if not chat or not chat.GetNumMessages then return lines, hidden end
    for index = chat:GetNumMessages(), 1, -1 do
        local ok, text = pcall(chat.GetMessageInfo, chat, index)
        if ok and IsSecret(text) then
            hidden = hidden + 1
        elseif ok and type(text) == "string" then
            local done, clean = pcall(Clean, text)
            if done then table.insert(lines, 1, clean) end
        end
        if #lines >= LINES then break end
    end
    return lines, hidden
end

local function CreateWindow()
    frame = CreateFrame("Frame", "MythicPresetsHelperLogCopyFrame", UIParent, "BasicFrameTemplateWithInset")
    MPH.SkinShell(frame)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    MPH.SetTitle(frame, string.format("Chat, last %d lines", LINES))

    frame.Scroll = CreateFrame("ScrollFrame", "MythicPresetsHelperLogCopyScrollFrame", frame, "ScrollFrameTemplate")
    frame.Scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame.Scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, FOOTER_HEIGHT)
    MPH.SkinScroll(frame.Scroll)

    frame.Box = CreateFrame("EditBox", nil, frame.Scroll)
    frame.Box:SetMultiLine(true)
    frame.Box:SetAutoFocus(false)
    frame.Box:SetFontObject("ChatFontNormal")
    frame.Box:SetWidth(WIDTH - 12 - SCROLLBAR_WIDTH - 4)
    frame.Box:SetHeight(HEIGHT - 30 - FOOTER_HEIGHT)
    MPH.SkinEditBox(frame.Box)
    frame.Scroll:SetScrollChild(frame.Box)

    frame.Box:SetScript("OnEscapePressed", function () frame:Hide() end)
    frame.Box:SetScript("OnTextChanged", function (self, userInput)
        if userInput then
            self:SetText(frame.value)
            self:HighlightText()
        end
    end)

    local function OnCopy(self, key)
        if key == "C" and IsControlKeyDown() and not frame.closing then
            frame.closing = true
            C_Timer.After(0.05, function ()
                frame.closing = nil
                frame:Hide()
            end)
        end
    end
    frame.Box:SetScript("OnKeyDown", OnCopy)
    frame.Box:SetScript("OnKeyUp", OnCopy)

    frame.Hidden = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.Hidden:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 28)
    frame.Hidden:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 28)
    frame.Hidden:SetJustifyH("CENTER")

    frame.Hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.Hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame.Hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame.Hint:SetJustifyH("CENTER")
    frame.Hint:SetText("Ctrl+C copies, the window closes itself")

    tinsert(UISpecialFrames, "MythicPresetsHelperLogCopyFrame")
end

function MPH.ShowLogCopy()
    if not frame then CreateWindow() end
    local lines, hidden = ReadLines()
    local text = #lines > 0 and table.concat(lines, "\n") or ""
    frame.value = text
    frame.closing = nil
    frame.Box:SetText(text)
    frame.Hidden:SetText(string.format("Hidden by the game: %d", hidden))
    frame.Hidden:SetShown(hidden > 0)
    frame:Show()
    frame.Box:SetFocus()
    frame.Box:HighlightText()
    MPH.Debug("logcopy: open, lines %d, hidden %d, combat %s", #lines, hidden, tostring(InCombatLockdown()))
end
