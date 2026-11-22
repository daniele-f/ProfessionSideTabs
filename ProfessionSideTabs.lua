local addonName = ...
local addon = CreateFrame("Frame")

local container
local positionAnchor
local settingsCategory
local buttons = {}
local primaryProfessions = {}
local settingsCheckboxes = {}

local BUTTON_SIZE = 48
local BUTTON_GAP = 6
local GROUP_SPACER = 14
local DIVIDER_HEIGHT = 8
local DIVIDER_TOP_GAP = 4
local PANEL_HEIGHT_PADDING = 10
local TOP_INSET = 74
local BOTTOM_INSET = 32

local DEFAULT_PANEL_POSITION = 0
local MAX_PANEL_POSITION = 100
local LEGACY_FRAME_HEIGHT = 658
local LEGACY_SEPARATOR_DEPTH = 2 * (BUTTON_SIZE + BUTTON_GAP) + DIVIDER_TOP_GAP + DIVIDER_HEIGHT / 2
local LEGACY_PANEL_HEIGHT = 5 * (BUTTON_SIZE + BUTTON_GAP) + GROUP_SPACER + PANEL_HEIGHT_PADDING

local secondaryProfessions = {
    [3] = { key = "showArchaeology", name = "Archaeology", default = false },
    [4] = { key = "showFishing", name = "Fishing", default = true },
    [5] = { key = "showCooking", name = "Cooking", default = true },
}

local function EnsureDB()
    if type(ProfessionSideTabsDB) ~= "table" then
        ProfessionSideTabsDB = {}
    end

    if type(ProfessionSideTabsDB.hiddenPrimaryProfessions) ~= "table" then
        ProfessionSideTabsDB.hiddenPrimaryProfessions = {}
    end

    local position = ProfessionSideTabsDB.panelPosition
    if type(position) ~= "number" then
        -- Convert a saved coordinate using the fully expanded layout.
        local oldSeparatorY = ProfessionSideTabsDB.panelSeparatorY
        local oldBottomY = ProfessionSideTabsDB.panelBottomY
        local oldTopY = ProfessionSideTabsDB.panelY
        if type(oldSeparatorY) == "number" then
            oldTopY = oldSeparatorY + LEGACY_SEPARATOR_DEPTH
        elseif type(oldBottomY) == "number" then
            oldTopY = oldBottomY + LEGACY_PANEL_HEIGHT
        end

        position = DEFAULT_PANEL_POSITION
        if type(oldTopY) == "number" then
            local travel = LEGACY_FRAME_HEIGHT - TOP_INSET - BOTTOM_INSET - LEGACY_PANEL_HEIGHT
            position = (-oldTopY - TOP_INSET) / travel * MAX_PANEL_POSITION
        end
    end
    ProfessionSideTabsDB.panelPosition = math.max(0, math.min(MAX_PANEL_POSITION, math.floor(position + 0.5)))

    for _, profession in pairs(secondaryProfessions) do
        if ProfessionSideTabsDB[profession.key] == nil then
            ProfessionSideTabsDB[profession.key] = profession.default
        end
    end
end

local function IsSecondaryShown(slot)
    return ProfessionSideTabsDB[secondaryProfessions[slot].key] ~= false
end

local function OpenProfessionBySlot(slotNumber)
    local professionIndex = select(slotNumber, GetProfessions())
    if not professionIndex then
        return
    end

    local skillLine = select(7, GetProfessionInfo(professionIndex))
    if not skillLine then
        return
    end

    C_TradeSkillUI.OpenTradeSkill(skillLine)
end

local function GetProfessionDataBySlot(slotNumber)
    local professionIndex = select(slotNumber, GetProfessions())
    if not professionIndex then
        return nil
    end

    local name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, skillLine, skillModifier =
        GetProfessionInfo(professionIndex)

    if not skillLine then
        return nil
    end

    return {
        slotNumber = slotNumber,
        professionIndex = professionIndex,
        name = name,
        icon = icon,
        skillLevel = skillLevel,
        maxSkillLevel = maxSkillLevel,
        skillLine = skillLine,
        skillModifier = skillModifier or 0,
    }
end

local function RefreshPrimaryProfessions()
    for slot = 1, 2 do
        primaryProfessions[slot] = GetProfessionDataBySlot(slot)
    end
end

local function IsPrimaryShown(profession)
    return profession ~= nil and not ProfessionSideTabsDB.hiddenPrimaryProfessions[profession.skillLine]
end

local function SetProfessionShown(slot, shown)
    if slot <= 2 then
        local profession = primaryProfessions[slot]
        if profession then
            ProfessionSideTabsDB.hiddenPrimaryProfessions[profession.skillLine] = not shown or nil
        end
    else
        ProfessionSideTabsDB[secondaryProfessions[slot].key] = shown
    end
end

local function RefreshSettingsCheckboxes()
    for slot, checkbox in ipairs(settingsCheckboxes) do
        if slot <= 2 then
            local profession = primaryProfessions[slot]
            if profession and profession.name then
                checkbox.label:SetText("Show " .. profession.name)
            else
                checkbox.label:SetText("Primary Profession " .. slot .. " (unlearned)")
            end
            checkbox:SetEnabled(profession ~= nil)
            checkbox.label:SetAlpha(profession and 1 or 0.5)
            checkbox:SetChecked(IsPrimaryShown(profession))
        else
            checkbox:SetChecked(IsSecondaryShown(slot))
        end
    end
end

local function GetCurrentOpenSkillLine()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then
        return nil
    end

    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    if info and info.professionID then
        return info.professionID
    end

    return nil
end

local function UpdateButtonTooltip(self)
    if not self.professionData then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("LEFT", self, "RIGHT", 12, 0)
    GameTooltip:AddLine(self.professionData.name or UNKNOWN, 1, 0.82, 0)

    local bonusText = ""
    if self.professionData.skillModifier and self.professionData.skillModifier ~= 0 then
        if self.professionData.skillModifier > 0 then
            bonusText = string.format(" |cff20ff20(+%d)|r", self.professionData.skillModifier)
        else
            bonusText = string.format(" |cffff4040(%d)|r", self.professionData.skillModifier)
        end
    end

    if self.professionData.skillLevel and self.professionData.maxSkillLevel then
        GameTooltip:AddLine(
            string.format(
                "Skill: %d/%d%s",
                self.professionData.skillLevel,
                self.professionData.maxSkillLevel,
                bonusText
            ),
            1, 1, 1
        )
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to open", 0, 1, 0)
    GameTooltip:Show()
end

local function UpdateButtonState(button, isSelected)
    if isSelected then
        button.selectedGlow:Show()
        button.leftFlair:SetAlpha(1)
        button.icon:SetAlpha(1)
    else
        button.selectedGlow:Hide()
        button.leftFlair:SetAlpha(0.35)
        button.icon:SetAlpha(0.95)
    end
end

local function CreateTabButton(parent, index)
    local button = CreateFrame("Button", addonName .. "Tab" .. index, parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.09, 0.08, 0.95)
    button.bg = bg

    local border = button:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.border = border

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 5, -5)
    icon:SetPoint("BOTTOMRIGHT", -5, 5)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local hoverGlow = button:CreateTexture(nil, "OVERLAY")
    hoverGlow:SetAllPoints()
    hoverGlow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:SetAlpha(0.55)
    hoverGlow:Hide()
    button.hoverGlow = hoverGlow

    local selectedGlow = button:CreateTexture(nil, "OVERLAY")
    selectedGlow:SetTexture("Interface\\Buttons\\CheckButtonGlow")
    selectedGlow:SetBlendMode("ADD")
    selectedGlow:SetAlpha(0.85)
    selectedGlow:SetPoint("TOPLEFT", icon, -20, 20)
    selectedGlow:SetPoint("BOTTOMRIGHT", icon, 20, -20)
    selectedGlow:Hide()
    button.selectedGlow = selectedGlow

    local leftFlair = button:CreateTexture(nil, "OVERLAY")
    leftFlair:SetWidth(10)
    leftFlair:SetPoint("TOPLEFT", -4, 0)
    leftFlair:SetPoint("BOTTOMLEFT", -4, 0)
    leftFlair:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    leftFlair:SetTexCoord(0.05, 0.18, 0.2, 0.8)
    leftFlair:SetBlendMode("ADD")
    leftFlair:SetAlpha(0.35)
    button.leftFlair = leftFlair

    local pushedShade = button:CreateTexture(nil, "OVERLAY")
    pushedShade:SetAllPoints()
    pushedShade:SetColorTexture(0, 0, 0, 0.2)
    pushedShade:Hide()
    button.pushedShade = pushedShade

    button:SetScript("OnClick", function(self)
        if self.slotNumber then
            OpenProfessionBySlot(self.slotNumber)
        end
    end)

    button:SetScript("OnEnter", function(self)
        self.hoverGlow:Show()
        UpdateButtonTooltip(self)
    end)

    button:SetScript("OnLeave", function(self)
        self.hoverGlow:Hide()
        GameTooltip_Hide()
    end)

    button:SetScript("OnMouseDown", function(self)
        self.pushedShade:Show()
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", 6, -6)
        self.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    end)

    button:SetScript("OnMouseUp", function(self)
        self.pushedShade:Hide()
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", 5, -5)
        self.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    end)

    return button
end

local function UpdateContainerPosition()
    if not container or container:GetHeight() <= 0 then
        return false
    end

    local availableHeight = ProfessionsFrame:GetHeight() - TOP_INSET - BOTTOM_INSET
    if availableHeight <= 0 then
        return false
    end

    local panelHeight = container:GetHeight()
    local scale = math.min(1, availableHeight / panelHeight)
    local travel = math.max(0, availableHeight - panelHeight * scale)
    local fraction = ProfessionSideTabsDB.panelPosition / MAX_PANEL_POSITION
    container:SetScale(scale)
    positionAnchor:ClearAllPoints()
    positionAnchor:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", -1, -TOP_INSET - travel * fraction)
    return true
end

local function EnsureUI()
    if container or not ProfessionsFrame then
        return
    end

    -- Keep the horizontal anchor at the window's scale if the buttons need to shrink.
    positionAnchor = CreateFrame("Frame", nil, ProfessionsFrame)
    positionAnchor:SetSize(1, 1)
    container = CreateFrame("Frame", addonName .. "Container", ProfessionsFrame)
    container:SetPoint("TOPLEFT", positionAnchor, "TOPLEFT", 0, 0)
    container:SetWidth(BUTTON_SIZE + 20)

    container.bg = container:CreateTexture(nil, "BACKGROUND")
    container.bg:SetAllPoints()
    container.bg:SetColorTexture(0.14, 0.12, 0.10, 0.94)

    container.top = container:CreateTexture(nil, "BORDER")
    container.top:SetPoint("TOPLEFT")
    container.top:SetPoint("TOPRIGHT")
    container.top:SetHeight(2)
    container.top:SetColorTexture(0.6, 0.6, 0.6, 0.8)

    container.right = container:CreateTexture(nil, "BORDER")
    container.right:SetPoint("TOPRIGHT")
    container.right:SetPoint("BOTTOMRIGHT")
    container.right:SetWidth(2)
    container.right:SetColorTexture(0.6, 0.6, 0.6, 0.8)

    container.bottom = container:CreateTexture(nil, "BORDER")
    container.bottom:SetPoint("BOTTOMLEFT")
    container.bottom:SetPoint("BOTTOMRIGHT")
    container.bottom:SetHeight(2)
    container.bottom:SetColorTexture(0.6, 0.6, 0.6, 0.8)

    container.divider = container:CreateTexture(nil, "ARTWORK")
    container.divider:SetHeight(DIVIDER_HEIGHT)
    container.divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    container.divider:SetAlpha(0.9)
    container.divider:Hide()

    container:Hide()

    for i = 1, 5 do
        buttons[i] = CreateTabButton(container, i)
    end
end

local function LayoutButtonGroup(firstSlot, lastSlot, y)
    for slot = firstSlot, lastSlot do
        local button = buttons[slot]
        if button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", container, "TOPLEFT", 9, -7 - y)
            y = y + BUTTON_SIZE + BUTTON_GAP
        end
    end
    return y
end

local function LayoutButtons()
    local primaryEnd = LayoutButtonGroup(1, 2, 0)
    local hasPrimary = primaryEnd > 0
    local dividerTop = primaryEnd + DIVIDER_TOP_GAP
    local secondaryStart = primaryEnd + (hasPrimary and GROUP_SPACER or 0)
    local secondaryEnd = LayoutButtonGroup(3, 5, secondaryStart)
    local hasSecondary = secondaryEnd > secondaryStart

    local divider = container.divider
    if hasPrimary and hasSecondary then
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -dividerTop)
        divider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -16, -dividerTop)
        divider:Show()
    else
        divider:Hide()
    end

    local contentHeight = hasSecondary and secondaryEnd or primaryEnd
    container:SetHeight(math.max(contentHeight + PANEL_HEIGHT_PADDING, BUTTON_SIZE))
    return UpdateContainerPosition()
end

local function UpdateButtons()
    EnsureDB()
    RefreshPrimaryProfessions()
    RefreshSettingsCheckboxes()
    EnsureUI()
    if not container then
        return
    end

    local currentSkillLine = GetCurrentOpenSkillLine()
    local anyButtonShown = false

    for slot = 1, 5 do
        local button = buttons[slot]
        local data
        if slot <= 2 then
            local profession = primaryProfessions[slot]
            if IsPrimaryShown(profession) then
                data = profession
            end
        elseif IsSecondaryShown(slot) then
            data = GetProfessionDataBySlot(slot)
        end

        if data then
            button.slotNumber = slot
            button.professionData = data
            button.icon:SetTexture(data.icon or 134400)
            button:Show()
            UpdateButtonState(button, currentSkillLine and currentSkillLine == data.skillLine)
            anyButtonShown = true
        else
            button.slotNumber = nil
            button.professionData = nil
            button:Hide()
            button.hoverGlow:Hide()
            button.selectedGlow:Hide()
        end
    end

    local fits = LayoutButtons()

    if ProfessionsFrame:IsShown() and anyButtonShown and fits then
        container:Show()
    else
        container:Hide()
    end
end

local function RegisterSettings()
    -- Keep the controls out of the shared setting lookup used by action-bar mouse clicks.
    local page = CreateFrame("Frame", nil, UIParent)
    page:Hide()
    local y = -20

    local function AddText(text, font)
        local label = page:CreateFontString(nil, "ARTWORK", font)
        label:SetPoint("TOPLEFT", 24, y)
        label:SetText(text)
        y = y - 24
    end

    local function AddProfessionCheckbox(slot)
        local checkbox = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", 24, y)
        checkbox:SetSize(26, 26)
        checkbox.label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        settingsCheckboxes[slot] = checkbox
        if slot >= 3 then
            checkbox.label:SetText("Show " .. secondaryProfessions[slot].name)
        end
        checkbox:SetScript("OnClick", function(self)
            SetProfessionShown(slot, not not self:GetChecked())
            UpdateButtons()
        end)
        y = y - 30
    end

    AddText("Profession Side Tabs", "GameFontNormalLarge")
    y = y - 12
    AddText("Primary Professions", "GameFontNormal")
    for slot = 1, 2 do
        AddProfessionCheckbox(slot)
    end

    y = y - 8
    AddText("Secondary Professions", "GameFontNormal")
    for slot = 3, 5 do
        AddProfessionCheckbox(slot)
    end

    y = y - 8
    AddText("Panel Position", "GameFontNormal")
    AddText("Vertical Position", "GameFontHighlight")

    local sliderOptions = Settings.CreateSliderOptions(0, MAX_PANEL_POSITION, 1)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Left, function()
        return "Top"
    end)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function()
        return "Bottom"
    end)
    local slider = CreateFrame("Frame", nil, page, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("TOPLEFT", 24, y)
    slider:SetSize(240, 20)
    slider:Init(
        ProfessionSideTabsDB.panelPosition,
        sliderOptions.minValue,
        sliderOptions.maxValue,
        sliderOptions.steps,
        sliderOptions.formatters
    )
    slider:RegisterCallback("OnValueChanged", function(_, value)
        ProfessionSideTabsDB.panelPosition = math.floor(value + 0.5)
        UpdateContainerPosition()
    end, page)

    function page:OnDefault()
        for _, profession in pairs(primaryProfessions) do
            ProfessionSideTabsDB.hiddenPrimaryProfessions[profession.skillLine] = nil
        end
        for _, profession in pairs(secondaryProfessions) do
            ProfessionSideTabsDB[profession.key] = profession.default
        end
        ProfessionSideTabsDB.panelPosition = DEFAULT_PANEL_POSITION
        slider:SetValue(DEFAULT_PANEL_POSITION)
        UpdateButtons()
    end

    RefreshSettingsCheckboxes()
    local category = Settings.RegisterCanvasLayoutCategory(page, "Profession Side Tabs")
    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
end

local function OnProfessionWindowHidden()
    if container then
        container:Hide()
    end
end

local function TryHookProfessionFrame()
    if not ProfessionsFrame then
        return
    end

    EnsureUI()

    if not ProfessionsFrame.__ProfessionSideTabsHooked then
        ProfessionsFrame:HookScript("OnShow", UpdateButtons)
        ProfessionsFrame:HookScript("OnHide", OnProfessionWindowHidden)
        ProfessionsFrame:HookScript("OnSizeChanged", UpdateButtons)
        ProfessionsFrame.__ProfessionSideTabsHooked = true
    end
end

addon:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        RefreshPrimaryProfessions()
        RegisterSettings()
        TryHookProfessionFrame()
        return
    end

    if event == "TRADE_SKILL_SHOW" then
        TryHookProfessionFrame()
        UpdateButtons()
        return
    end

    if event == "TRADE_SKILL_CLOSE" then
        OnProfessionWindowHidden()
        return
    end

    if event == "SKILL_LINES_CHANGED"
        or event == "SPELLS_CHANGED"
        or event == "CHAT_MSG_SKILL"
        or event == "TRADE_SKILL_LIST_UPDATE"
        or event == "TRADE_SKILL_NAME_UPDATE"
    then
        UpdateButtons()
        return
    end
end)

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("TRADE_SKILL_SHOW")
addon:RegisterEvent("TRADE_SKILL_CLOSE")
addon:RegisterEvent("SKILL_LINES_CHANGED")
addon:RegisterEvent("SPELLS_CHANGED")
addon:RegisterEvent("CHAT_MSG_SKILL")
addon:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
addon:RegisterEvent("TRADE_SKILL_NAME_UPDATE")

SLASH_PROFESSIONSIDETABS1 = "/pst"

SlashCmdList["PROFESSIONSIDETABS"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" and settingsCategory then
        C_Timer.After(0, function()
            if InCombatLockdown() then
                print("|cff00ff98PST|r: Settings can be opened after combat.")
                return
            end

            Settings.OpenToCategory(settingsCategory:GetID())
        end)
        return
    end

    EnsureDB()

    local cmd, arg = msg:match("^(%S+)%s*(%S*)$")
    if cmd == "archy" then
        cmd = "archaeology"
    end

    local validAction = arg == "show" or arg == "hide"
    local shown = arg == "show"
    local status = shown and "shown" or "hidden"

    if cmd == "secondary" then
        if not validAction then
            print("|cff00ff98PST|r usage: /pst secondary show/hide")
            return
        end

        for slot = 3, 5 do
            SetProfessionShown(slot, shown)
        end
        UpdateButtons()
        print("|cff00ff98PST|r: All secondary professions " .. status)
        return
    end

    for slot, profession in pairs(secondaryProfessions) do
        if cmd == profession.name:lower() then
            if not validAction then
                print("|cff00ff98PST|r usage: /pst " .. cmd .. " show/hide")
                return
            end

            SetProfessionShown(slot, shown)
            print("|cff00ff98PST|r: " .. profession.name .. " " .. status)
            UpdateButtons()
            return
        end
    end

    print("|cff00ff98PST|r commands:")
    print("|cff00ff98PST|r /pst archy show/hide")
    print("|cff00ff98PST|r /pst fishing show/hide")
    print("|cff00ff98PST|r /pst cooking show/hide")
    print("|cff00ff98PST|r /pst secondary show/hide")
end
