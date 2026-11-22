local addonName = ...
local addon = CreateFrame("Frame")

local settingsCategory
local openStandaloneSettings
local windowCheckboxes = {}
local pendingArchaeologyOpen
local primaryProfessions = {}
local primaryCheckboxes = {}
local secondaryCheckboxes = {}
local runeforgingCheckbox
local professionSkillCheckboxes = {}

local BUTTON_SIZE = 48
local BUTTON_GAP = 6
local GROUP_SPACER = 14
local DIVIDER_HEIGHT = 8
local DIVIDER_TOP_GAP = 4
local PANEL_HEIGHT_PADDING = 10
local TOP_INSET = 74
local BOTTOM_INSET = 32
local RUNEFORGING_SLOT = 6
local RUNEFORGING_SPELL_ID = 53428
local RUNEFORGING_SKILL_LINE = 960

local craftingPanel = { frameName = "ProfessionsFrame", suffix = "", topInset = TOP_INSET, bottomInset = BOTTOM_INSET }
local bookPanel = {
    frameName = "ProfessionsBookFrame", suffix = "Book", topInset = 27, bottomInset = 6,
    option = "showProfessionsBook", optionLabel = "Show tabs on the Professions overview",
}
local archaeologyPanel = {
    frameName = "ArchaeologyFrame", suffix = "Archaeology", topInset = 186, bottomInset = 9,
    option = "showArchaeologyPanel", optionLabel = "Show tabs on the Archaeology panel",
}
local panels = { craftingPanel, bookPanel, archaeologyPanel }

local tabStyles = {
    Panel = { width = BUTTON_SIZE, height = BUTTON_SIZE, gap = BUTTON_GAP, left = 9, groupGap = GROUP_SPACER },
    Forever = { width = 50, height = 56, gap = 3, left = 1, groupGap = 8 },
}

local DEFAULT_TAB_STYLE = "Forever"
local DEFAULT_PANEL_POSITION = 0
local MAX_PANEL_POSITION = 100
local MIN_PANEL_SIZE = 75
local MAX_PANEL_SIZE = 110
local DEFAULT_PANEL_SIZE = math.floor((MIN_PANEL_SIZE + MAX_PANEL_SIZE) / 2 + 0.5)
local LEGACY_FRAME_HEIGHT = 658
local LEGACY_SEPARATOR_DEPTH = 2 * (BUTTON_SIZE + BUTTON_GAP) + DIVIDER_TOP_GAP + DIVIDER_HEIGHT / 2
local LEGACY_PANEL_HEIGHT = 5 * (BUTTON_SIZE + BUTTON_GAP) + GROUP_SPACER + PANEL_HEIGHT_PADDING

local primaryProfessionOptions = {
    { skillLine = 171, name = "Alchemy" },
    { skillLine = 164, name = "Blacksmithing" },
    { skillLine = 333, name = "Enchanting" },
    { skillLine = 202, name = "Engineering" },
    { skillLine = 182, name = "Herbalism" },
    { skillLine = 773, name = "Inscription" },
    { skillLine = 755, name = "Jewelcrafting" },
    { skillLine = 165, name = "Leatherworking" },
    { skillLine = 186, name = "Mining" },
    { skillLine = 393, name = "Skinning" },
    { skillLine = 197, name = "Tailoring" },
}

local primaryProfessionSlots = { 1, 2 }
local secondaryProfessionSlots = { 5, 4, 3 }

local secondaryProfessions = {
    [3] = { key = "showArchaeology", name = "Archaeology", default = true },
    [4] = { key = "showFishing", name = "Fishing", default = true },
    [5] = { key = "showCooking", name = "Cooking", default = true },
}

local professionSkills = {
    { key = "disenchant", name = "Disenchant", spellID = 13262 },
    { key = "milling", name = "Milling", recipeIDs = { 1269575, 444181, 382981 } },
    { key = "prospecting", name = "Prospecting", recipeIDs = { 1231127, 434018, 374627 } },
    { key = "skinning", name = "Skinning", spellID = 8613 },
    { key = "cookingFire", name = "Cooking Fire", spellID = 818 },
    { key = "fishing", name = "Fishing Skill", spellID = 131474 },
    { key = "survey", name = "Survey", spellID = 80451 },
}
local professionSkillSlots = {}
local lastTabSlot = RUNEFORGING_SLOT + #professionSkills
for index = 1, #professionSkills do
    professionSkillSlots[index] = RUNEFORGING_SLOT + index
end

local function EnsureDB()
    if type(ProfessionSideTabsDB) ~= "table" then
        ProfessionSideTabsDB = {}
    end

    if type(ProfessionSideTabsDB.hiddenPrimaryProfessions) ~= "table" then
        ProfessionSideTabsDB.hiddenPrimaryProfessions = {}
    end

    if type(ProfessionSideTabsDB.shownProfessionSkills) ~= "table" then
        ProfessionSideTabsDB.shownProfessionSkills = {}
    end

    if not tabStyles[ProfessionSideTabsDB.tabStyle] then
        ProfessionSideTabsDB.tabStyle = DEFAULT_TAB_STYLE
    end
    for _, panel in ipairs(panels) do
        if panel.option and ProfessionSideTabsDB[panel.option] == nil then
            ProfessionSideTabsDB[panel.option] = true
        end
    end

    if ProfessionSideTabsDB.showRuneforging == nil then
        ProfessionSideTabsDB.showRuneforging = true
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

    local panelSize = ProfessionSideTabsDB.panelSize
    if type(panelSize) ~= "number" then
        panelSize = DEFAULT_PANEL_SIZE
    end
    ProfessionSideTabsDB.panelSize = math.max(MIN_PANEL_SIZE, math.min(MAX_PANEL_SIZE, math.floor(panelSize + 0.5)))

    for _, profession in pairs(secondaryProfessions) do
        if ProfessionSideTabsDB[profession.key] == nil then
            ProfessionSideTabsDB[profession.key] = profession.default
        end
    end
end

local function IsSecondaryShown(slot)
    return ProfessionSideTabsDB[secondaryProfessions[slot].key] ~= false
end

local function GetCurrentOpenSkillLine()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then
        return nil
    end

    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    return info and info.professionID
end

local function CloseArchaeology()
    if ArchaeologyFrame and ArchaeologyFrame:IsShown() then
        HideUIPanel(ArchaeologyFrame)
        return ArchaeologyFrame
    end
end

local function OpenArchaeology()
    if not ArchaeologyFrame then
        C_AddOns.LoadAddOn("Blizzard_ArchaeologyUI")
    end
    if not ArchaeologyFrame or ArchaeologyFrame:IsShown() then
        return
    end

    local previousSkillLine
    local function ShowArchaeology()
        local overview = ProfessionsBookFrame
        local wasOverviewOpen = overview and overview:IsShown()
        if wasOverviewOpen then
            overview:Hide()
        end

        ShowUIPanel(ArchaeologyFrame)
        if not ArchaeologyFrame:IsShown() then
            if previousSkillLine then
                C_TradeSkillUI.OpenTradeSkill(previousSkillLine)
            end
            if wasOverviewOpen then
                overview:Show()
            end
        end
    end

    if ProfessionsFrame and ProfessionsFrame:IsShown() then
        previousSkillLine = GetCurrentOpenSkillLine()
        ProfessionsFrame:CheckConfirmClose()
        if ProfessionsFrame:IsShown() then
            if StaticPopup_Visible("PROFESSIONS_SPECIALIZATION_CONFIRM_CLOSE") then
                pendingArchaeologyOpen = ShowArchaeology
            end
            return
        end
    end

    ShowArchaeology()
end

local function CloseOtherProfessionWindows()
    local archaeology = CloseArchaeology()
    local overview = ProfessionsBookFrame
    if overview and overview:IsShown() then
        overview:Hide()
    else
        overview = nil
    end
    return archaeology, overview
end

local function OpenTradeSkill(skillLine)
    local archaeology, overview = CloseOtherProfessionWindows()
    if not C_TradeSkillUI.OpenTradeSkill(skillLine) then
        if archaeology then
            ShowUIPanel(archaeology)
        end
        if overview then
            overview:Show()
        end
    end
end

local function OpenProfessionSkillRecipe(button)
    if button.professionData and not InCombatLockdown() then
        CloseOtherProfessionWindows()
        C_TradeSkillUI.OpenRecipe(button.professionData.recipeID)
    end
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

    if slotNumber == 3 then
        OpenArchaeology()
    else
        OpenTradeSkill(skillLine)
    end
end

local function OpenProfessionsOverview()
    local archaeology = CloseArchaeology()
    if not ProfessionsBookFrame or not ProfessionsBookFrame:IsShown() then
        ToggleProfessionsBook()
    end

    if not ProfessionsBookFrame or not ProfessionsBookFrame:IsShown() then
        if archaeology then
            ShowUIPanel(archaeology)
        end
    elseif ProfessionsFrame and ProfessionsFrame:IsShown() then
        ProfessionsFrame:CheckConfirmClose()
    end
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

local function IsPrimaryShown(skillLine)
    return not ProfessionSideTabsDB.hiddenPrimaryProfessions[skillLine]
end

local function SetSecondaryShown(slot, shown)
    ProfessionSideTabsDB[secondaryProfessions[slot].key] = shown
end

local function GetProfessionSkillAction(skill)
    if skill.spellID then
        if C_SpellBook.IsSpellKnown(skill.spellID)
            or (C_SpellBook.FindSpellBookSlotForSpell and C_SpellBook.FindSpellBookSlotForSpell(skill.spellID, false, false))
        then
            return skill.spellID
        end
    elseif C_TradeSkillUI.IsRecipeProfessionLearned then
        for _, recipeID in ipairs(skill.recipeIDs) do
            if C_TradeSkillUI.IsRecipeProfessionLearned(recipeID) then
                return recipeID
            end
        end
    end
end

local function IsDeathKnight()
    return select(2, UnitClass("player")) == "DEATHKNIGHT"
end

local function RefreshSettingsCheckboxes()
    if runeforgingCheckbox then
        local isDeathKnight = IsDeathKnight()
        local label = "Show Runeforging"
        if not isDeathKnight then
            label = label .. " (Only available to Death Knights)"
        elseif not C_SpellBook.IsSpellKnown(RUNEFORGING_SPELL_ID) then
            label = label .. " (Not learned)"
        end
        runeforgingCheckbox.label:SetText(label)
        runeforgingCheckbox.label:SetAlpha(isDeathKnight and 1 or 0.5)
        runeforgingCheckbox:GetCheckedTexture():SetDesaturated(not isDeathKnight)
        runeforgingCheckbox:SetChecked(ProfessionSideTabsDB.showRuneforging)
    end

    for option, checkbox in pairs(windowCheckboxes) do
        checkbox:SetChecked(ProfessionSideTabsDB[option])
    end
    local first, second = primaryProfessions[1], primaryProfessions[2]
    for skillLine, checkbox in pairs(primaryCheckboxes) do
        local learned = (first and first.skillLine == skillLine) or (second and second.skillLine == skillLine)
        checkbox.label:SetText(checkbox.professionName .. (learned and " (Learned)" or ""))
        local color = learned and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR
        checkbox.label:SetTextColor(color:GetRGB())
        checkbox:SetChecked(IsPrimaryShown(skillLine))
    end

    for slot, checkbox in pairs(secondaryCheckboxes) do
        local learned = select(slot, GetProfessions()) ~= nil
        local name = secondaryProfessions[slot].name
        checkbox.label:SetText(name .. (learned and "" or " (Not learned)"))
        checkbox:GetCheckedTexture():SetDesaturated(not learned)
        checkbox:SetChecked(IsSecondaryShown(slot))
    end
end

local function UpdateButtonTooltip(self)
    if not self.professionData then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("LEFT", self, "RIGHT", 12, 0)
    local spellID = self.professionData.spellID
    if spellID and GameTooltip:SetSpellByID(spellID) then
        GameTooltip:Show()
        return
    end

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

local function PositionButtonIcon(button, pressed)
    local isForever = button.tabStyle == tabStyles.Forever
    local xInset = isForever and 4 or 5
    local yInset = isForever and 7 or 5
    local shift = pressed and 1 or 0
    local xShift = shift - (isForever and 2 or 0)
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT", xInset + xShift, -yInset - shift)
    button.icon:SetPoint("BOTTOMRIGHT", -xInset + xShift, yInset - shift)
end

local function CreateForeverMask(button, texture)
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\AddOns\\" .. addonName .. "\\assets\\ForeverIconMask.tga",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    return mask
end

local function ApplyButtonStyle(button, style)
    if button.tabStyle == style then
        return
    end

    button.tabStyle = style
    button:SetSize(style.width, style.height)
    local isForever = style == tabStyles.Forever
    button.border:SetShown(not isForever)
    button.leftFlair:SetShown(not isForever)
    button.selectedGlow:ClearAllPoints()
    if isForever then
        if not button.foreverIconMask then
            button.foreverIconMask = CreateForeverMask(button, button.icon)

            -- Cover the inset trim while keeping the outside edge of the tab art visible.
            local inset = button:CreateTexture(nil, "BORDER")
            inset:SetPoint("TOPLEFT", 1, -5)
            inset:SetPoint("BOTTOMRIGHT", -7, 5)
            inset:SetColorTexture(0.03, 0.03, 0.03, 1)
            inset:AddMaskTexture(CreateForeverMask(button, inset))
            button.foreverInset = inset
        end
        button.icon:AddMaskTexture(button.foreverIconMask)
        button.foreverInset:Show()
        button.bg:SetAtlas("common-sidetab")
        button.hoverGlow:SetAtlas("common-sidetab-hover")
        button.selectedGlow:SetAtlas("common-sidetab-selected")
        button.selectedGlow:SetAllPoints()
        button.selectedGlow:SetBlendMode("BLEND")
        button.selectedGlow:SetAlpha(1)
    else
        button.icon:RemoveMaskTexture(button.foreverIconMask)
        button.foreverInset:Hide()
        button.bg:SetColorTexture(0.10, 0.09, 0.08, 0.95)
        button.hoverGlow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        button.hoverGlow:SetTexCoord(0, 1, 0, 1)
        button.selectedGlow:SetTexture("Interface\\Buttons\\CheckButtonGlow")
        button.selectedGlow:SetTexCoord(0, 1, 0, 1)
        button.selectedGlow:SetPoint("TOPLEFT", button.icon, -20, 20)
        button.selectedGlow:SetPoint("BOTTOMRIGHT", button.icon, 20, -20)
        button.selectedGlow:SetBlendMode("ADD")
        button.selectedGlow:SetAlpha(0.85)
    end
    PositionButtonIcon(button, false)
end

local function CreateTabButton(parent, name, onClick)
    local button = CreateFrame("Button", name, parent)
    button.tabStyle = tabStyles.Panel
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

    button:SetScript("OnClick", onClick or function(self)
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
        self.pushedShade:SetShown(self.tabStyle == tabStyles.Panel)
        PositionButtonIcon(self, true)
    end)

    button:SetScript("OnMouseUp", function(self)
        self.pushedShade:Hide()
        PositionButtonIcon(self, false)
    end)

    return button
end

local function CreateSpellAction(tab)
    -- A separate anchor keeps the protected click target off Blizzard's profession frames.
    local action = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    action:EnableMouse(true)
    action:RegisterForClicks("LeftButtonUp")
    action:SetAttribute("useOnKeyDown", false)
    local spellName = C_Spell.GetSpellName(tab.spellID) or tab.spellName
    action:SetAttribute("type1", "macro")
    action:SetAttribute("macrotext1", "/use " .. spellName)
    action:Hide()
    RegisterStateDriver(action, "visibility", "[combat] hide")

    if tab.spellID == RUNEFORGING_SPELL_ID then
        action:SetScript("PreClick", CloseOtherProfessionWindows)
    end
    for _, scriptName in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
        local handler = tab:GetScript(scriptName)
        action:SetScript(scriptName, function()
            handler(tab)
        end)
    end

    tab.spellAction = action
    return action
end

local function SyncSpellAction(tab)
    if InCombatLockdown() then
        return
    end

    local left, bottom, width, height = tab:GetRect()
    if not left then
        return
    end
    local scale = tab:GetEffectiveScale() / UIParent:GetEffectiveScale()
    left, bottom, width, height = left * scale, bottom * scale, width * scale, height * scale

    local action = tab.spellAction or CreateSpellAction(tab)
    if left ~= action.tabLeft or bottom ~= action.tabBottom or width ~= action.tabWidth or height ~= action.tabHeight then
        action:ClearAllPoints()
        action:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        action:SetSize(width, height)
        action.tabLeft, action.tabBottom, action.tabWidth, action.tabHeight = left, bottom, width, height
    end
    local strata = tab:GetFrameStrata()
    if action:GetFrameStrata() ~= strata then
        action:SetFrameStrata(strata)
    end
    local level = tab:GetFrameLevel() + 1
    if action:GetFrameLevel() ~= level then
        action:SetFrameLevel(level)
    end
    if not action:IsShown() then
        action:Show()
    end
end

local function ConfigureSpellTab(tab, spellID, spellName)
    tab.spellID = spellID
    tab.spellName = spellName
    tab:EnableMouse(false)
    tab:SetScript("OnClick", nil)
    tab:SetScript("OnUpdate", SyncSpellAction)
    tab:SetScript("OnHide", function(self)
        local action = self.spellAction
        if action then
            -- Finish a spell click if PreClick just closed the source window.
            C_Timer.After(0, function()
                if not self:IsVisible() and not InCombatLockdown() then
                    action:Hide()
                end
            end)
        end
    end)
end

local function UpdateContainerPosition(panel)
    local container = panel.container
    if not container or container:GetHeight() <= 0 then
        return false
    end

    local availableHeight = panel.frame:GetHeight() - panel.topInset - panel.bottomInset
    if availableHeight <= 0 then
        return false
    end

    local panelHeight = container:GetHeight()
    local requestedScale = ProfessionSideTabsDB.panelSize / 100
    local scale = math.min(requestedScale, availableHeight / panelHeight)
    local travel = math.max(0, availableHeight - panelHeight * scale)
    local fraction = ProfessionSideTabsDB.panelPosition / MAX_PANEL_POSITION
    container:SetScale(scale)
    panel.anchor:ClearAllPoints()
    panel.anchor:SetPoint("TOPLEFT", panel.frame, "TOPRIGHT", -1, -panel.topInset - travel * fraction)
    return true
end

local function CreateDivider(container)
    local divider = container:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(DIVIDER_HEIGHT)
    divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    divider:SetAlpha(0.9)
    divider:Hide()
    return divider
end

local function EnsurePanel(panel, refresh)
    local frame = _G[panel.frameName]
    if panel.container or not frame then
        return
    end

    -- Keep the horizontal anchor at the window's scale if the buttons need to shrink.
    local anchor = CreateFrame("Frame", nil, frame)
    anchor:SetSize(1, 1)
    local prefix = addonName .. panel.suffix
    local container = CreateFrame("Frame", prefix .. "Container", frame)
    container:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    panel.frame = frame
    panel.container = container
    panel.anchor = anchor
    panel.buttons = {}
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

    container.divider = CreateDivider(container)
    container.professionSkillsDivider = CreateDivider(container)
    container.runeforgingDivider = CreateDivider(container)

    container:Hide()

    for i = 1, RUNEFORGING_SLOT do
        panel.buttons[i] = CreateTabButton(container, prefix .. "Tab" .. i)
    end

    ConfigureSpellTab(panel.buttons[RUNEFORGING_SLOT], RUNEFORGING_SPELL_ID, "Runeforging")
    for index, skill in ipairs(professionSkills) do
        local slot = professionSkillSlots[index]
        local button = CreateTabButton(container, prefix .. "Tab" .. slot, OpenProfessionSkillRecipe)
        if skill.spellID then
            ConfigureSpellTab(button, skill.spellID, skill.name)
        end
        panel.buttons[slot] = button
    end

    if type(ToggleProfessionsBook) == "function" then
        local overview = CreateTabButton(container, prefix .. "OverviewTab", OpenProfessionsOverview)
        overview.icon:SetTexture("Interface\\Spellbook\\Spellbook-Icon")
        overview.professionData = { name = "Professions Overview" }
        overview:Hide()
        panel.overview = overview
    end

    frame:HookScript("OnShow", refresh)
    frame:HookScript("OnSizeChanged", refresh)
    frame:HookScript("OnHide", function()
        container:Hide()
        if panel == craftingPanel and pendingArchaeologyOpen then
            local openAfterClose = pendingArchaeologyOpen
            pendingArchaeologyOpen = nil
            C_Timer.After(0, openAfterClose)
        end
    end)
end

local function PlaceTabButton(panel, button, y, style)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", panel.container, "TOPLEFT", style.left, -7 - y)
    return y + style.height + style.gap
end

local function LayoutButtonGroup(panel, slots, y, style)
    for _, slot in ipairs(slots) do
        local button = panel.buttons[slot]
        if button:IsShown() then
            y = PlaceTabButton(panel, button, y, style)
        end
    end
    return y
end

local function PositionDivider(divider, container, groupEnd, shown)
    if shown then
        local top = groupEnd + DIVIDER_TOP_GAP
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -top)
        divider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -16, -top)
    end
    divider:SetShown(shown)
end

local function LayoutButtons(panel, style)
    local container = panel.container
    local isPanel = style == tabStyles.Panel
    container:SetWidth(style.width + (isPanel and 20 or 2))
    container.bg:SetShown(isPanel)
    container.top:SetShown(isPanel)
    container.right:SetShown(isPanel)
    container.bottom:SetShown(isPanel)

    local primaryStart = 0
    if panel.overview and panel.overview:IsShown() then
        primaryStart = PlaceTabButton(panel, panel.overview, 0, style)
    end
    local primaryEnd = LayoutButtonGroup(panel, primaryProfessionSlots, primaryStart, style)
    local hasPrimary = primaryEnd > 0
    local secondaryStart = primaryEnd + (hasPrimary and style.groupGap or 0)
    local secondaryEnd = LayoutButtonGroup(panel, secondaryProfessionSlots, secondaryStart, style)
    local hasSecondary = secondaryEnd > secondaryStart

    local contentHeight = hasSecondary and secondaryEnd or primaryEnd
    local skillsStart = contentHeight + (contentHeight > 0 and style.groupGap or 0)
    local skillsEnd = LayoutButtonGroup(panel, professionSkillSlots, skillsStart, style)
    local hasSkills = skillsEnd > skillsStart
    PositionDivider(container.professionSkillsDivider, container, contentHeight,
        isPanel and hasSkills and contentHeight > 0)
    if hasSkills then
        contentHeight = skillsEnd
    end

    local runeforging = panel.buttons[RUNEFORGING_SLOT]
    local hasRuneforging = runeforging:IsShown()
    PositionDivider(container.divider, container, primaryEnd, isPanel and hasPrimary and hasSecondary)
    PositionDivider(container.runeforgingDivider, container, contentHeight,
        isPanel and hasRuneforging and contentHeight > 0)

    if hasRuneforging then
        local runeforgingStart = contentHeight + (contentHeight > 0 and style.groupGap or 0)
        contentHeight = PlaceTabButton(panel, runeforging, runeforgingStart, style)
    end
    container:SetHeight(math.max(contentHeight + PANEL_HEIGHT_PADDING, style.height))
    return UpdateContainerPosition(panel)
end

local function UpdatePanel(panel, professions, currentSkillLine, style)
    local container = panel.container
    if not panel.frame:IsShown() or (panel.option and not ProfessionSideTabsDB[panel.option]) then
        container:Hide()
        return
    end

    local anyButtonShown = false
    if panel.overview then
        local showOverview = ProfessionSideTabsDB.showProfessionsBook
        if showOverview then
            ApplyButtonStyle(panel.overview, style)
            UpdateButtonState(panel.overview, panel == bookPanel)
        end
        panel.overview:SetShown(showOverview)
        anyButtonShown = showOverview
    end

    for slot = 1, lastTabSlot do
        local button = panel.buttons[slot]
        local data = professions[slot]
        if data then
            ApplyButtonStyle(button, style)
            button.slotNumber = slot
            button.professionData = data
            button.icon:SetTexture(data.icon or 134400)
            button:Show()
            local isSelected = (panel == craftingPanel and data.skillLine ~= nil and currentSkillLine == data.skillLine)
                or (panel == archaeologyPanel and slot == 3)
            UpdateButtonState(button, isSelected)
            anyButtonShown = true
        else
            button.slotNumber = nil
            button.professionData = nil
            button:Hide()
            button.hoverGlow:Hide()
            button.selectedGlow:Hide()
        end
    end

    local fits = LayoutButtons(panel, style)
    container:SetShown(anyButtonShown and fits)
end

local function UpdateButtons()
    EnsureDB()
    RefreshPrimaryProfessions()
    RefreshSettingsCheckboxes()

    local professions = {}
    for slot = 1, 2 do
        local profession = primaryProfessions[slot]
        if profession and IsPrimaryShown(profession.skillLine) then
            professions[slot] = profession
        end
    end
    for slot = 3, 5 do
        if IsSecondaryShown(slot) then
            professions[slot] = GetProfessionDataBySlot(slot)
        end
    end

    if ProfessionSideTabsDB.showRuneforging and IsDeathKnight() and C_SpellBook.IsSpellKnown(RUNEFORGING_SPELL_ID) then
        professions[RUNEFORGING_SLOT] = {
            name = "Runeforging",
            icon = C_Spell.GetSpellTexture(RUNEFORGING_SPELL_ID),
            skillLine = RUNEFORGING_SKILL_LINE,
        }
    end

    for index, skill in ipairs(professionSkills) do
        local actionID = GetProfessionSkillAction(skill)
        local shown = ProfessionSideTabsDB.shownProfessionSkills[skill.key] == true
        local checkbox = professionSkillCheckboxes[index]
        if checkbox then
            checkbox.label:SetText(skill.name .. (actionID and "" or " (Not learned)"))
            checkbox:GetCheckedTexture():SetDesaturated(not actionID)
            checkbox:SetChecked(shown)
        end
        if shown and actionID then
            professions[professionSkillSlots[index]] = {
                name = C_Spell.GetSpellName(actionID) or skill.name,
                icon = C_Spell.GetSpellTexture(actionID),
                spellID = actionID,
                recipeID = skill.recipeIDs and actionID or nil,
            }
        end
    end

    local currentSkillLine = GetCurrentOpenSkillLine()
    local style = tabStyles[ProfessionSideTabsDB.tabStyle]
    for _, panel in ipairs(panels) do
        EnsurePanel(panel, UpdateButtons)
        if panel.container then
            UpdatePanel(panel, professions, currentSkillLine, style)
        end
    end
end

local function CreateStandaloneSettingsWindow(title, height)
    local window = CreateFrame("Frame", nil, UIParent, "ButtonFrameTemplate")
    window:Hide()
    local width = 650
    window:SetSize(width, height)
    window:HookScript("OnShow", function(self)
        local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
        if screenWidth and screenWidth > 16 and screenHeight > 16 then
            self:SetScale(math.min(1, (screenWidth - 16) / width, (screenHeight - 16) / height))
        end
    end)
    window:SetPoint("CENTER", UIParent, "CENTER")
    window:SetFrameStrata("DIALOG")
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:SetTitle(title)
    ButtonFrameTemplate_HideAttic(window)
    ButtonFrameTemplate_HidePortrait(window)
    ButtonFrameTemplate_HideButtonBar(window)

    local titleBar = window.TitleContainer
    titleBar:SetHitRectInsets(0, window.CloseButton:GetWidth(), 0, 0)
    titleBar:EnableMouse(true)
    for _, dragSurface in ipairs({ window, titleBar }) do
        dragSurface:RegisterForDrag("LeftButton")
        dragSurface:SetScript("OnDragStart", function()
            window:StartMoving()
        end)
        dragSurface:SetScript("OnDragStop", function()
            window:StopMovingOrSizing()
        end)
    end
    window:SetScript("OnHide", window.StopMovingOrSizing)
    window.CloseButton:SetScript("OnClick", function()
        window:Hide()
    end)
    return window
end

local function RegisterSettings()
    -- Keep the controls out of the shared setting lookup used by action-bar mouse clicks.
    local title = "Profession Side Tabs"
    local canvas = CreateFrame("Frame", nil, UIParent)
    canvas:Hide()
    local canvasTitle = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    canvasTitle:SetPoint("TOPLEFT", 24, -20)
    canvasTitle:SetText(title)
    local scrollFrame = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)
    scrollFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -30, 8)

    local page = CreateFrame("Frame", nil, content)
    local function DockSettingsPage()
        page:SetParent(content)
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", content, "TOPLEFT")
        page:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
    end
    DockSettingsPage()

    local headingX = 24
    local indent = 20
    local optionX = headingX + indent
    local y = -20

    local function AddText(text, font, x)
        local label = page:CreateFontString(nil, "ARTWORK", font)
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(text)
        y = y - 24
    end

    local function AddSectionHeading(title)
        y = y - 16
        AddText(title, "GameFontNormal", headingX)
    end

    local columns = 3
    local columnWidth = 180
    local checkboxRowHeight = 30
    local function AddCheckbox(label, onClick, x, rowY)
        local checkbox = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", x or optionX, rowY or y)
        checkbox:SetSize(26, 26)
        checkbox.label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        checkbox.label:SetText(label)
        checkbox:SetScript("OnClick", onClick)
        if rowY == nil then
            y = y - checkboxRowHeight
        else
            checkbox.label:SetWidth(columnWidth - 36)
            checkbox.label:SetJustifyH("LEFT")
        end
        return checkbox
    end

    AddText("Tab Style", "GameFontNormal", headingX)
    local styleDropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    styleDropdown:SetPoint("TOPLEFT", optionX, y)
    styleDropdown:SetWidth(150)
    styleDropdown:SetText(ProfessionSideTabsDB.tabStyle)
    styleDropdown:SetupMenu(function(_, menu)
        for _, styleName in ipairs({ "Forever", "Panel" }) do
            menu:CreateRadio(styleName, function()
                return ProfessionSideTabsDB.tabStyle == styleName
            end, function()
                ProfessionSideTabsDB.tabStyle = styleName
                styleDropdown:SetText(styleName)
                UpdateButtons()
            end)
        end
    end)
    y = y - 30

    AddSectionHeading("Additional Windows")
    for _, panel in ipairs(panels) do
        if panel.option then
            windowCheckboxes[panel.option] = AddCheckbox(panel.optionLabel, function(self)
                ProfessionSideTabsDB[panel.option] = not not self:GetChecked()
                UpdateButtons()
            end)
        end
    end

    AddSectionHeading("Primary Professions")
    for index, profession in ipairs(primaryProfessionOptions) do
        local skillLine = profession.skillLine
        local name
        if C_TradeSkillUI.GetTradeSkillDisplayName then
            name = C_TradeSkillUI.GetTradeSkillDisplayName(skillLine)
        end
        if not name or name == "" then
            name = profession.name
        end
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local checkbox = AddCheckbox(name, function(self)
            ProfessionSideTabsDB.hiddenPrimaryProfessions[skillLine] = not self:GetChecked() or nil
            UpdateButtons()
        end, optionX + column * columnWidth, y - row * checkboxRowHeight)
        checkbox.professionName = name
        primaryCheckboxes[skillLine] = checkbox
    end
    y = y - math.ceil(#primaryProfessionOptions / columns) * checkboxRowHeight

    y = y - 8
    AddSectionHeading("Secondary Professions")
    for column, slot in ipairs(secondaryProfessionSlots) do
        secondaryCheckboxes[slot] = AddCheckbox("", function(self)
            SetSecondaryShown(slot, not not self:GetChecked())
            UpdateButtons()
        end, optionX + (column - 1) * columnWidth, y)
    end
    y = y - checkboxRowHeight

    y = y - 8
    AddSectionHeading("Profession Skills")
    for index, skill in ipairs(professionSkills) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        professionSkillCheckboxes[index] = AddCheckbox(skill.name, function(self)
            ProfessionSideTabsDB.shownProfessionSkills[skill.key] = self:GetChecked() and true or nil
            UpdateButtons()
        end, optionX + column * columnWidth, y - row * checkboxRowHeight)
    end
    y = y - math.ceil(#professionSkills / columns) * checkboxRowHeight

    y = y - 8
    AddSectionHeading("Death Knights")
    runeforgingCheckbox = AddCheckbox("", function(self)
        ProfessionSideTabsDB.showRuneforging = not not self:GetChecked()
        UpdateButtons()
    end)

    local dockedSliderWidth = 220
    local sliderLabelX = optionX + indent
    local sliderLabelWidth = 46
    local function AddPanelSlider(setting, options, leftText)
        local slider = CreateFrame("Frame", nil, page, "MinimalSliderWithSteppersTemplate")
        slider:SetPoint("TOPLEFT", sliderLabelX + sliderLabelWidth, y)
        slider:SetSize(dockedSliderWidth, 20)
        slider:Init(ProfessionSideTabsDB[setting], options.minValue, options.maxValue, options.steps, options.formatters)
        local leftLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        leftLabel:SetPoint("LEFT", slider, "LEFT", -sliderLabelWidth, 0)
        leftLabel:SetText(leftText)
        slider:RegisterCallback("OnValueChanged", function(_, value)
            ProfessionSideTabsDB[setting] = math.floor(value + 0.5)
            for _, panel in ipairs(panels) do
                UpdateContainerPosition(panel)
            end
        end, page)
        return slider
    end

    y = y - 8
    AddSectionHeading("Panel Position")
    AddText("Vertical Position", "GameFontHighlight", optionX)
    y = y + 4
    local positionOptions = Settings.CreateSliderOptions(0, MAX_PANEL_POSITION, 1)
    positionOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function()
        return "Bottom"
    end)
    local positionSlider = AddPanelSlider("panelPosition", positionOptions, "Top")

    y = y - 28
    AddText("Panel Size", "GameFontHighlight", optionX)
    y = y + 4
    local sizeOptions = Settings.CreateSliderOptions(MIN_PANEL_SIZE, MAX_PANEL_SIZE, 1)
    sizeOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function()
        return "Large"
    end)
    local sizeSlider = AddPanelSlider("panelSize", sizeOptions, "Small")
    content:SetHeight(-y + sizeSlider:GetHeight() + 12)

    function canvas:OnDefault()
        ProfessionSideTabsDB.hiddenPrimaryProfessions = {}
        ProfessionSideTabsDB.shownProfessionSkills = {}
        for _, profession in pairs(secondaryProfessions) do
            ProfessionSideTabsDB[profession.key] = profession.default
        end
        ProfessionSideTabsDB.showRuneforging = true
        ProfessionSideTabsDB.panelPosition = DEFAULT_PANEL_POSITION
        ProfessionSideTabsDB.panelSize = DEFAULT_PANEL_SIZE
        for _, panel in ipairs(panels) do
            if panel.option then
                ProfessionSideTabsDB[panel.option] = true
            end
        end
        ProfessionSideTabsDB.tabStyle = DEFAULT_TAB_STYLE
        positionSlider:SetValue(DEFAULT_PANEL_POSITION)
        sizeSlider:SetValue(DEFAULT_PANEL_SIZE)
        styleDropdown:SetText(DEFAULT_TAB_STYLE)
        UpdateButtons()
    end

    local standalone
    canvas:SetScript("OnShow", function()
        if standalone then
            standalone:Hide()
            DockSettingsPage()
            positionSlider:SetWidth(dockedSliderWidth)
            sizeSlider:SetWidth(dockedSliderWidth)
        end
    end)

    openStandaloneSettings = function(resetPosition)
        if SettingsPanel:IsShown() then
            SettingsPanel:Close(true)
            if SettingsPanel:IsShown() then
                return
            end
        end

        if not standalone then
            standalone = CreateStandaloneSettingsWindow(title, content:GetHeight() + 50)
        elseif resetPosition then
            standalone:StopMovingOrSizing()
            standalone:ClearAllPoints()
            standalone:SetPoint("CENTER", UIParent, "CENTER")
        end

        page:SetParent(standalone)
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", standalone, "TOPLEFT", 24, -20)
        page:SetPoint("BOTTOMRIGHT", standalone, "BOTTOMRIGHT", -24, 16)
        positionSlider:SetWidth(230)
        sizeSlider:SetWidth(230)
        standalone:Show()
    end

    local popout = CreateFrame("Button", nil, canvas)
    popout:SetPoint("TOPRIGHT", -36, -16)
    popout:SetSize(24, 24)
    popout:SetNormalAtlas("RedButton-Expand")
    popout:SetPushedAtlas("RedButton-Expand-Pressed")
    popout:SetHighlightAtlas("RedButton-Highlight", "ADD")
    popout:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Open in a movable window")
        GameTooltip:Show()
    end)
    popout:SetScript("OnLeave", GameTooltip_Hide)
    popout:SetScript("OnClick", function()
        openStandaloneSettings()
    end)

    RefreshSettingsCheckboxes()
    local category = Settings.RegisterCanvasLayoutCategory(canvas, title)
    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
end

addon:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        RefreshPrimaryProfessions()
        RegisterSettings()
        UpdateButtons()
        return
    end

    if event == "ADDON_LOADED" then
        if loadedAddon == "Blizzard_Professions" or loadedAddon == "Blizzard_ProfessionsBook"
            or loadedAddon == "Blizzard_ArchaeologyUI"
        then
            UpdateButtons()
        end
        return
    end

    if event == "TRADE_SKILL_CLOSE" then
        if craftingPanel.container then
            craftingPanel.container:Hide()
        end
        return
    end

    if event == "TRADE_SKILL_SHOW"
        or event == "SKILL_LINES_CHANGED"
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
addon:RegisterEvent("ADDON_LOADED")
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
    if cmd == "window" and openStandaloneSettings then
        if arg == "" or arg == "reset" then
            C_Timer.After(0, function()
                openStandaloneSettings(arg == "reset")
            end)
        else
            print("|cff00ff98PST|r usage: /pst window [reset]")
        end
        return
    end

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
            SetSecondaryShown(slot, shown)
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

            SetSecondaryShown(slot, shown)
            print("|cff00ff98PST|r: " .. profession.name .. " " .. status)
            UpdateButtons()
            return
        end
    end

    print("|cff00ff98PST|r commands:")
    print("|cff00ff98PST|r /pst window [reset]")
    print("|cff00ff98PST|r /pst archy show/hide")
    print("|cff00ff98PST|r /pst fishing show/hide")
    print("|cff00ff98PST|r /pst cooking show/hide")
    print("|cff00ff98PST|r /pst secondary show/hide")
end
