-- private variables for global bonus
local bonusData = {active = false, endTime = 0, rewards = {}}
local bonusUpdateEvent = nil

-- private functions for global bonus
local function updateBonusDisplay()
    if bonusData.active then
        local remaining = math.max(0, bonusData.endTime - os.time())
        local hours = math.floor(remaining / 3600)
        local mins = math.floor((remaining % 3600) / 60)
        local secs = remaining % 60
        local timeStr = string.format("%02d:%02d:%02d", hours, mins, secs)

        local bonusType = bonusData.rewards.type or "xp"
        local multiplier = bonusData.rewards.multiplier or 1
        local bonusStr = bonusType .. " x" .. multiplier

        local iconPath = ""
        if bonusType == "xp" then
            iconPath = "/images/game/prey/prey_xp.png"
        elseif bonusType == "loot" then
            iconPath = "/images/game/prey/prey_loot.png"
        elseif bonusType == "skill" then
            iconPath = "/images/game/prey/prey_damage.png"
        end

        modules.game_stats.setBonusTooltip(
            "Global Bonus: " .. bonusStr .. "\nTime left: " .. timeStr)
        modules.game_stats.setBonusIcon(iconPath)
        modules.game_stats.showBonusButton()

        -- Schedule next update
        bonusUpdateEvent = scheduleEvent(updateBonusDisplay, 1000)
    else
        if modules.game_stats then
            modules.game_stats.hideBonusButton()
        end
        removeEvent(bonusUpdateEvent)
    end
end

local function onExtendedOpcode(protocol, opcode, buffer)
    if opcode == 251 then
        local data = json.decode(buffer)
        if data then
            bonusData = data
            updateBonusDisplay()
        end
    end
end

local function showBonusWindow()
    -- Optional: show a window with details
    local bonusStr = "No active bonus"
    if bonusData.active then
        local remaining = math.max(0, bonusData.endTime - os.time())
        local hours = math.floor(remaining / 3600)
        local mins = math.floor((remaining % 3600) / 60)
        local secs = remaining % 60
        local timeStr = string.format("%02d:%02d:%02d", hours, mins, secs)

        local bonusType = bonusData.rewards.type or "xp"
        local multiplier = bonusData.rewards.multiplier or 1
        bonusStr = "Active bonus: " .. bonusType .. " x" .. multiplier .. "\nTime left: " .. timeStr
    end

    modules.game_textmessage.displayGameMessage(bonusStr)
end

function init()
    if modules.game_interface and modules.game_interface.setupTopMenuButton then
        modules.game_interface.setupTopMenuButton()
    end
    if modules.client_options and modules.client_options.setupTopMenuButton then
        modules.client_options.setupTopMenuButton()
    end
    if modules.game_viplist and modules.game_viplist.setupTopMenuButton then
        modules.game_viplist.setupTopMenuButton()
    end
    if modules.game_skills and modules.game_skills.setupTopMenuButton then
        modules.game_skills.setupTopMenuButton()
    end
    if modules.game_questlog and modules.game_questlog.setupTopMenuButton then
        modules.game_questlog.setupTopMenuButton()
    end
    if modules.game_minimap and modules.game_minimap.setupTopMenuButton then
        modules.game_minimap.setupTopMenuButton()
    end
    if modules.game_inventory and modules.game_inventory.setupTopMenuButton then
        modules.game_inventory.setupTopMenuButton()
    end
    if modules.game_battle and modules.game_battle.setupTopMenuButton then
        modules.game_battle.setupTopMenuButton()
    end
    if modules.game_healthinfo and modules.game_healthinfo.setupTopMenuButton then
        modules.game_healthinfo.setupTopMenuButton()
    end
    if modules.game_autoloot and modules.game_autoloot.setupTopMenuButton then
        modules.game_autoloot.setupTopMenuButton()
    end
    if modules.game_conjurer and modules.game_conjurer.setupTopMenuButton then
        modules.game_conjurer.setupTopMenuButton()
    end
    -- Removed game_globalbonus call

    -- Setup bonus button in game_stats
    if modules.game_stats then
        modules.game_stats.setBonusOnClick(showBonusWindow)
    end

    -- Register extended opcode for bonus
    if ProtocolGame and ProtocolGame.registerExtendedOpcode then
        ProtocolGame.registerExtendedOpcode(251, onExtendedOpcode)
    end

    -- game_store button is created directly in the mod's init()
    -- game_shop disabled - if modules.game_shop and modules.game_shop.setupTopMenuButton then modules.game_shop.setupTopMenuButton() end
end

function terminate()
    if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
        ProtocolGame.unregisterExtendedOpcode(251)
    end
    removeEvent(bonusUpdateEvent)
end
