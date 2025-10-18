local OPCODE = 61
local window, creatureBarHP, creatureHP, creatureName = nil
local focusedBoss = 0
local focusedMob = 0

function init()
	connect(g_game, {
		onGameStart = create,
		onGameEnd = destroy,
		onAttackingCreatureChange = onAttackingCreatureChange,
		onAppear = onCreatureAppear,
		onDisappear = onCreatureDisappear
	})
	connect(Creature, {
		onHealthPercentChange = onHealthPercentChange,
		onSpecialPercentChange = onSpecialPercentChange,
		onAppear = onCreatureAppear,
		onDisappear = onCreatureDisappear
	})

	-- Registrar o opcode para receber dados do servidor
	ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)

	if g_game.isOnline() then
		create()
	end
end

function terminate()
	disconnect(g_game, {
		onGameStart = create,
		onGameEnd = destroy,
		onAttackingCreatureChange = onAttackingCreatureChange,
		onAppear = onCreatureAppear,
		onDisappear = onCreatureDisappear
	})
	disconnect(Creature, {
		onHealthPercentChange = onHealthPercentChange,
		onSpecialPercentChange = onSpecialPercentChange,
		onAppear = onCreatureAppear,
		onDisappear = onCreatureDisappear
	})
	
	-- Desregistrar o opcode
	ProtocolGame.unregisterExtendedOpcode(OPCODE)
	
	destroy()
end

function create()
	if window then
		return
	end

	window = g_ui.loadUI("bossbar", modules.game_interface.getMapPanel())

	window:hide()

	creatureBarHP = window:recursiveGetChildById("creatureBarHP")
	creatureName = window:recursiveGetChildById("creatureName")
	creatureHP = window:recursiveGetChildById("creatureHP")
	creatureSpecial = window:recursiveGetChildById("special")
end

function destroy()
	if window then
		window:destroy()

		window = nil
		creatureBarHP = nil
		creatureHP = nil
		creatureOutfit = nil
		creatureName = nil
		creatureSpecial = nil
		focusedBoss = 0
		focusedMob = 0
	end
end

function log(message)
    g_logger.info("[Boss Bar] " .. message)
end

function onExtendedOpcode(protocol, code, buffer)
    log("Received opcode: " .. code .. " with buffer: " .. buffer)
    
    if not g_game.isOnline() then
        log("Game is not online")
        return
    end

    local json_status, json_data = pcall(function ()
        return json.decode(buffer)
    end)

    if not json_status then
        log("Failed to decode JSON: " .. tostring(json_data))
        return false
    end

    log("JSON decoded successfully: action=" .. (json_data.action or "nil"))

    if json_data.action == "show" then
        log("Showing boss bar for: " .. (json_data.data.name or "unknown"))
        show(json_data.data)
    elseif json_data.action == "hide" then
        log("Hiding boss bar")
        hide()
    end
end

function show(data)
    log("Show function called with data: name=" .. (data.name or "nil") .. ", health=" .. (data.health or "nil"))
    
    if not window then
        log("Window not created yet, creating...")
        create()
    end
    
    if not window then
        log("Failed to create window!")
        return
    end
    
    focusedBoss = data.cid or 0
    creatureName:setText(data.name or "Unknown Boss")
    creatureHP:setText((data.health or 0) .. "%")
    creatureSpecial:setPercent(data.health or 0)
    
    log("Boss bar shown successfully")
    window:show()
end

function hide()
    focusedBoss = 0
    focusedMob = 0
    window:hide()
end

bossBarEnabled = true

function setEnabled(value)
	bossBarEnabled = value
end

local bossNames = {
	"Orshabaal"
}

function checkBossName(name)
    for _, bossName in ipairs(bossNames) do
        if string.lower(name) == string.lower(bossName) then
            return true
        end
    end
    return false
end

function onAttackingCreatureChange(creature, oldCreature)
    if bossBarEnabled then
        if focusedBoss ~= 0 then
            return
        end
        if creature and checkBossName(creature:getName()) then
            creatureHP:setText(creature:getHealthPercent() .. "%")
            creatureSpecial:setPercent(creature:getHealthPercent())
            focusedMob = creature:getId()
            window:show()
        else
            hide()
        end
    else
        hide()
    end
end


function onCreatureAppear(creature)
    if bossBarEnabled then
        if focusedBoss ~= 0 then
            return
        end
        if creature and checkBossName(creature:getName()) then
            creatureName:setText(creature:getName())
            creatureHP:setText(creature:getHealthPercent() .. "%")
            creatureSpecial:setPercent(creature:getHealthPercent())
            focusedMob = creature:getId()
            window:show()
        end
    end
end

function onCreatureDisappear(creature)
    if bossBarEnabled and (creature:getId() == focusedMob or creature:getId() == focusedBoss) then
        hide()
    end
end

function onHealthPercentChange(creature, health)
	if bossBarEnabled then
		if focusedBoss == creature:getId() or focusedMob == creature:getId() then
			creatureHP:setText(health .. "%")
			creatureSpecial:setPercent(health)
		end
	else
		hide()
	end
end

function onSpecialPercentChange(creature, special)
	if special > 0 then
		if not creatureSpecial:isVisible() then
			creatureSpecial:setVisible(true)
		end
		creatureSpecial:setPercent(special)
	else
		creatureSpecial:setVisible(false)
	end
end

