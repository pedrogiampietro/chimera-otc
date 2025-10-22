Icons = {}
Icons[PlayerStates.Poison] = { tooltip = tr('You are poisoned'), path = '/images/game/states/poisoned', id = 'condition_poisoned' }
Icons[PlayerStates.Burn] = { tooltip = tr('You are burning'), path = '/images/game/states/burning', id = 'condition_burning' }
Icons[PlayerStates.Energy] = { tooltip = tr('You are electrified'), path = '/images/game/states/electrified', id = 'condition_electrified' }
Icons[PlayerStates.Drunk] = { tooltip = tr('You are drunk'), path = '/images/game/states/drunk', id = 'condition_drunk' }
Icons[PlayerStates.ManaShield] = { tooltip = tr('You are protected by a magic shield'), path = '/images/game/states/magic_shield', id = 'condition_magic_shield' }
Icons[PlayerStates.Paralyze] = { tooltip = tr('You are paralysed'), path = '/images/game/states/slowed', id = 'condition_slowed' }
Icons[PlayerStates.Haste] = { tooltip = tr('You are hasted'), path = '/images/game/states/haste', id = 'condition_haste' }
Icons[PlayerStates.Swords] = { tooltip = tr('You may not logout during a fight'), path = '/images/game/states/logout_block', id = 'condition_logout_block' }
Icons[PlayerStates.Drowning] = { tooltip = tr('You are drowning'), path = '/images/game/states/drowning', id = 'condition_drowning' }
Icons[PlayerStates.Freezing] = { tooltip = tr('You are freezing'), path = '/images/game/states/freezing', id = 'condition_freezing' }
Icons[PlayerStates.Dazzled] = { tooltip = tr('You are dazzled'), path = '/images/game/states/dazzled', id = 'condition_dazzled' }
Icons[PlayerStates.Cursed] = { tooltip = tr('You are cursed'), path = '/images/game/states/cursed', id = 'condition_cursed' }
Icons[PlayerStates.PartyBuff] = { tooltip = tr('You are strengthened'), path = '/images/game/states/strengthened', id = 'condition_strengthened' }
Icons[PlayerStates.PzBlock] = { tooltip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
Icons[PlayerStates.Pz] = { tooltip = tr('You are within a protection zone'), path = '/images/game/states/protection_zone', id = 'condition_protection_zone' }
Icons[PlayerStates.Bleeding] = { tooltip = tr('You are bleeding'), path = '/images/game/states/bleeding', id = 'condition_bleeding' }
Icons[PlayerStates.Hungry] = { tooltip = tr('You are hungry'), path = '/images/game/states/hungry', id = 'condition_hungry' }

InventorySlotStyles = {
  [InventorySlotHead] = "HeadSlot",
  [InventorySlotNeck] = "NeckSlot",
  [InventorySlotBack] = "BackSlot",
  [InventorySlotBody] = "BodySlot",
  [InventorySlotRight] = "RightSlot",
  [InventorySlotLeft] = "LeftSlot",
  [InventorySlotLeg] = "LegSlot",
  [InventorySlotFeet] = "FeetSlot",
  [InventorySlotFinger] = "FingerSlot",
  [InventorySlotAmmo] = "AmmoSlot"
}

inventoryWindow = nil
inventoryPanel = nil
inventoryButton = nil
purseButton = nil
specialContainerSlot = nil
specialContainerWindow = nil

local SPECIAL_CONTAINER_OPCODE = 0x50
local SPECIAL_CONTAINER_BASE_POSITION = 100
local specialContainerSlots = {}
local specialContainerItems = {}
local specialContainerInitialized = false

combatControlsWindow = nil
fightOffensiveBox = nil
fightBalancedBox = nil
fightDefensiveBox = nil
chaseStandBox = nil
chaseRunBox = nil
safeFightButton = nil
mountButton = nil
fightModeRadioGroup = nil
standModeRadioGroup = nil
buttonPvp = nil

soulLabel = nil
capLabel = nil
conditionPanel = nil

function setupTopMenuButton()
  if not inventoryWindow.forceOpen then
    inventoryButton = modules.client_topmenu.addRightGameToggleButton('inventoryButton', tr('Inventory') .. ' (Ctrl+I)', '/images/topbuttons/new/inventory', toggle, nil, nil, true)
  end
end

function init()
  connect(LocalPlayer, {
    onInventoryChange = onInventoryChange,
    onBlessingsChange = onBlessingsChange
  })
  connect(g_game, { onGameStart = refresh })

  ProtocolGame.registerExtendedOpcode(SPECIAL_CONTAINER_OPCODE, onSpecialContainerExtendedOpcode)
  connect(g_game, { onGameStart = onSpecialContainerGameStart, onGameEnd = onSpecialContainerGameEnd })

  g_keyboard.bindKeyDown('Ctrl+I', toggle)

  inventoryWindow = g_ui.loadUI('inventory', modules.game_interface.getRightPanel())
  inventoryWindow:disableResize()
  inventoryPanel = inventoryWindow:getChildById('contentsPanel'):getChildById('inventoryPanel')
  
  purseButton = inventoryWindow:recursiveGetChildById('purseButton')
  purseButton.onClick = function()
    local purse = g_game.getLocalPlayer():getInventoryItem(InventorySlotPurse)
    if purse then
      g_game.use(purse)
    end
  end
  
  -- special container
  specialContainerSlot = inventoryWindow:recursiveGetChildById('specialContainerSlot')
  if not specialContainerSlot then
    g_logger.info("Special container slot not found in OTUI, creating dynamically...")
    
    -- Find slot8 (feet) to position below it
    local slot8 = inventoryWindow:recursiveGetChildById('slot8')
    local conditionPanel = inventoryWindow:recursiveGetChildById('conditionPanel')
    
    if slot8 then
      g_logger.info("Found slot8 (feet), creating special container button...")
      
      -- Create the slot button
      specialContainerSlot = g_ui.createWidget('UIButton', inventoryPanel)
      specialContainerSlot:setId('specialContainerSlot')
      specialContainerSlot:setSize({width = 40, height = 10})
      specialContainerSlot:setText(tr('open'))
      specialContainerSlot:setFont('verdana-11px-rounded')
      specialContainerSlot:setTextAlign(AlignCenter)
      specialContainerSlot:setColor('#ffffff')
      specialContainerSlot:setBackgroundColor('#555555')
      specialContainerSlot:setBorderWidth(1)
      specialContainerSlot:setBorderColor('#888888')
      specialContainerSlot:setTooltip(tr('Click to open Special Container'))
      
      -- Position it in the new expanded area at the bottom
      -- Use fixed position in the expanded space - below all slots
      if conditionPanel then
        local condPos = conditionPanel:getPosition()
        local condSize = conditionPanel:getSize()
        -- Position well below everything else
        local buttonX = condPos.x + (condSize.width / 2) - 60
        local buttonY = 150  -- Lower fixed Y position
        specialContainerSlot:setPosition({x = buttonX, y = buttonY})
        g_logger.info("Special container button positioned at fixed Y=" .. buttonY .. ", X=" .. buttonX)
      else
        -- Fallback: use fixed position at bottom
        specialContainerSlot:setPosition({x = 50, y = 200})
        g_logger.info("Special container button positioned at fallback position")
      end
      
      -- Make sure it's visible
      specialContainerSlot:setVisible(true)
      specialContainerSlot:raise()
      
      g_logger.info("Special container button size: " .. specialContainerSlot:getSize().width .. "x" .. specialContainerSlot:getSize().height)
      g_logger.info("Special container button visible: " .. tostring(specialContainerSlot:isVisible()))
    else
      g_logger.error("Could not find slot8")
    end
  else
    g_logger.info("Special container slot found in OTUI")
  end
  
  if specialContainerSlot then
    specialContainerSlot.onMouseRelease = function(self, mousePos, mouseButton)
      if mouseButton == MouseRightButton then
        toggleSpecialContainer()
        return true
      end
      return false
    end
    
    specialContainerSlot.onClick = function(self)
      toggleSpecialContainer()
    end
  end
  
  -- controls
  fightOffensiveBox = inventoryWindow:recursiveGetChildById('fightOffensiveBox')
  fightBalancedBox = inventoryWindow:recursiveGetChildById('fightBalancedBox')
  fightDefensiveBox = inventoryWindow:recursiveGetChildById('fightDefensiveBox')

  chaseStandBox = inventoryWindow:recursiveGetChildById('chaseStandBox')
  chaseRunBox = inventoryWindow:recursiveGetChildById('chaseRunBox')
  safeFightButton = inventoryWindow:recursiveGetChildById('safeFightBox')
  buttonPvp = inventoryWindow:recursiveGetChildById('buttonPvp')

  mountButton = inventoryWindow:recursiveGetChildById('mountButton')
  mountButton.onClick = onMountButtonClick

  whiteDoveBox = inventoryWindow:recursiveGetChildById('whiteDoveBox')
  whiteHandBox = inventoryWindow:recursiveGetChildById('whiteHandBox')
  yellowHandBox = inventoryWindow:recursiveGetChildById('yellowHandBox')
  redFistBox = inventoryWindow:recursiveGetChildById('redFistBox')

  fightModeRadioGroup = UIRadioGroup.create()
  fightModeRadioGroup:addWidget(fightOffensiveBox)
  fightModeRadioGroup:addWidget(fightBalancedBox)
  fightModeRadioGroup:addWidget(fightDefensiveBox)

  standModeRadioGroup = UIRadioGroup.create()
  standModeRadioGroup:addWidget(chaseStandBox)
  standModeRadioGroup:addWidget(chaseRunBox)

  connect(fightModeRadioGroup, { onSelectionChange = onSetFightMode })
  connect(standModeRadioGroup, { onSelectionChange = onSetChaseMode })
  connect(safeFightButton, { onCheckChange = onSetSafeFight })
  if buttonPvp then
    connect(buttonPvp, { onClick = onSetSafeFight2 })  
  end
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onFightModeChange = update,
    onChaseModeChange = update,
    onSafeFightChange = update,
    onPVPModeChange   = update,
    onWalk = check,
    onAutoWalk = check
  })

  connect(LocalPlayer, { onOutfitChange = onOutfitChange })

  if g_game.isOnline() then
    online()
  end
-- controls end

-- status
  soulLabel = inventoryWindow:recursiveGetChildById('soulLabel')
  capLabel = inventoryWindow:recursiveGetChildById('capLabel')
  conditionPanel = inventoryWindow:recursiveGetChildById('conditionPanel')


  connect(LocalPlayer, { onStatesChange = onStatesChange,
                         onSoulChange = onSoulChange,
                         onFreeCapacityChange = onFreeCapacityChange })
-- status end
  
  if g_game.isOnline() then
    specialContainerInitialized = true
    requestSpecialContainerData()
    refresh()
  end
  inventoryWindow:setup()
end

function terminate()
  disconnect(LocalPlayer, {
    onInventoryChange = onInventoryChange,
    onBlessingsChange = onBlessingsChange
  })
  disconnect(g_game, { onGameStart = refresh })

  ProtocolGame.unregisterExtendedOpcode(SPECIAL_CONTAINER_OPCODE, onSpecialContainerExtendedOpcode)
  disconnect(g_game, { onGameStart = onSpecialContainerGameStart, onGameEnd = onSpecialContainerGameEnd })

  g_keyboard.unbindKeyDown('Ctrl+I')

  -- controls
  if g_game.isOnline() then
    offline()
  end

  standModeRadioGroup:destroy()
  fightModeRadioGroup:destroy()
  
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onFightModeChange = update,
    onChaseModeChange = update,
    onSafeFightChange = update,
    onPVPModeChange   = update,
    onWalk = check,
    onAutoWalk = check
  })

  disconnect(LocalPlayer, { onOutfitChange = onOutfitChange })
  -- controls end
  -- status
  disconnect(LocalPlayer, { onStatesChange = onStatesChange,
                         onSoulChange = onSoulChange,
                         onFreeCapacityChange = onFreeCapacityChange })
  -- status end

  inventoryWindow:destroy()
  if inventoryButton then
    inventoryButton:destroy()
  end
end

function toggleAdventurerStyle(hasBlessing)
  for slot = InventorySlotFirst, InventorySlotLast do
    local itemWidget = inventoryPanel:getChildById('slot' .. slot)
    if itemWidget then
      itemWidget:setOn(hasBlessing)
    end
  end
end

function refresh()
  if(inventoryButton) then
    if(inventoryWindow:isVisible()) then
      inventoryButton:setOn(true)
    else
      inventoryButton:setOn(false)
    end
  end

  local player = g_game.getLocalPlayer()
  for i = InventorySlotFirst, InventorySlotPurse do
    if g_game.isOnline() then
      onInventoryChange(player, i, player:getInventoryItem(i))
    else
      onInventoryChange(player, i, nil)
    end
    toggleAdventurerStyle(player and Bit.hasBit(player:getBlessings(), Blessings.Adventurer) or false)
  end
  if player then
    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())
    onStatesChange(player, player:getStates(), 0)
  end

  purseButton:setVisible(g_game.getFeature(GamePurseSlot))
end

function toggle()
  if not inventoryButton then
    return
  end
  if inventoryButton:isOn() then
    inventoryWindow:close()
    inventoryButton:setOn(false)
  else
    inventoryWindow:open()
    inventoryButton:setOn(true)
  end
end

function onMiniWindowClose()
  if not inventoryButton then
    return
  end
  inventoryButton:setOn(false)
end

function onMinimize()
  conditionPanel:setOn(true)
end

function onMaximize()
  conditionPanel:setOn(false)
end

-- hooked events
function onInventoryChange(player, slot, item, oldItem)
	if InventorySlotPurse < slot then
		return
	end

	if slot == InventorySlotPurse then
		if g_game.getFeature(GamePurseSlot) then
			-- Nothing
		end
		return
	end

	local itemWidget = inventoryPanel:getChildById("slot" .. slot)

    if item then
        itemWidget:setStyle("InventoryItem")
        itemWidget:setItem(item)

        local itemInfo = player:getInventoryItem(slot)
        local tip = (itemInfo:getTooltip() or ""):lower()
        local src = "/images/ui/item"
        
        if tip:find("%[legendary%]") or tip:find(" legendary") then
            src = "/images/ui/rarity_gold"
        elseif tip:find("%[epic%]") or tip:find(" epic") then
            src = "/images/ui/rarity_purple"
        elseif tip:find("%[rare%]") or tip:find(" rare") then
            src = "/images/ui/rarity_blue"
          elseif tip:find("%[common%]") or tip:find(" common") then
            src = "/images/ui/rarity_white"
          end
        
        itemWidget:setImageSource(src)
    else
        itemWidget:setStyle(InventorySlotStyles[slot])
        itemWidget:setItem(nil)
        itemWidget:setTooltip(nil)
    end
end

function onBlessingsChange(player, blessings, oldBlessings)
  local hasAdventurerBlessing = Bit.hasBit(blessings, Blessings.Adventurer)
  if hasAdventurerBlessing ~= Bit.hasBit(oldBlessings, Blessings.Adventurer) then
    toggleAdventurerStyle(hasAdventurerBlessing)
  end
end


-- controls
function update()
  local fightMode = g_game.getFightMode()
  if fightMode == FightOffensive then
    fightModeRadioGroup:selectWidget(fightOffensiveBox)
  elseif fightMode == FightBalanced then
    fightModeRadioGroup:selectWidget(fightBalancedBox)
  else
    fightModeRadioGroup:selectWidget(fightDefensiveBox)
  end
  local chaseMode = g_game.getChaseMode()
  if chaseMode == DontChase then
    standModeRadioGroup:selectWidget(chaseStandBox)
  else
    standModeRadioGroup:selectWidget(chaseRunBox)
  end

  local safeFight = g_game.isSafeFight()
  safeFightButton:setChecked(not safeFight)
  if buttonPvp then
    if safeFight then
      buttonPvp:setOn(false)
    else
      buttonPvp:setOn(true)  
    end
  end
  
  if g_game.getFeature(GamePVPMode) then
    local pvpMode = g_game.getPVPMode()
    local pvpWidget = getPVPBoxByMode(pvpMode)
  end
end

function check()
  if modules.client_options.getOption('autoChaseOverride') then
    if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
      g_game.setChaseMode(DontChase)
    end
  end
end

function online()
  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()

    local lastCombatControls = g_settings.getNode('LastCombatControls')

    if not table.empty(lastCombatControls) then
      if lastCombatControls[char] then
        g_game.setFightMode(lastCombatControls[char].fightMode)
        g_game.setChaseMode(lastCombatControls[char].chaseMode)
        g_game.setSafeFight(lastCombatControls[char].safeFight)
        if lastCombatControls[char].pvpMode then
          g_game.setPVPMode(lastCombatControls[char].pvpMode)
        end
      end
    end

    if g_game.getFeature(GamePlayerMounts) then
      mountButton:setVisible(true)
      mountButton:setChecked(player:isMounted())
    else
      mountButton:setVisible(false)
    end
  end

  update()
end

function offline()
  local lastCombatControls = g_settings.getNode('LastCombatControls')
  if not lastCombatControls then
    lastCombatControls = {}
  end

  conditionPanel:destroyChildren()

  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()
    lastCombatControls[char] = {
      fightMode = g_game.getFightMode(),
      chaseMode = g_game.getChaseMode(),
      safeFight = g_game.isSafeFight()
    }

    if g_game.getFeature(GamePVPMode) then
      lastCombatControls[char].pvpMode = g_game.getPVPMode()
    end

    -- save last combat control settings
    g_settings.setNode('LastCombatControls', lastCombatControls)
  end
end

function onSetFightMode(self, selectedFightButton)
  if selectedFightButton == nil then return end
  local buttonId = selectedFightButton:getId()
  local fightMode
  if buttonId == 'fightOffensiveBox' then
    fightMode = FightOffensive
  elseif buttonId == 'fightBalancedBox' then
    fightMode = FightBalanced
  else
    fightMode = FightDefensive
  end
  g_game.setFightMode(fightMode)
end

function onSetChaseMode(self, selectedChaseButton)
  if selectedChaseButton == nil then return end
  local buttonId = selectedChaseButton:getId()
  local chaseMode
  if buttonId == 'chaseRunBox' then
    chaseMode = ChaseOpponent
  else
    chaseMode = DontChase
  end
  g_game.setChaseMode(chaseMode)
end

function onSetSafeFight(self, checked)
  g_game.setSafeFight(not checked)
  if buttonPvp then
    if not checked then
      buttonPvp:setOn(false)
    else
      buttonPvp:setOn(true)  
    end
  end
end

function onSetSafeFight2(self)
  onSetSafeFight(self, not safeFightButton:isChecked())
end

function onSetPVPMode(self, selectedPVPButton)
  if selectedPVPButton == nil then
    return
  end

  local buttonId = selectedPVPButton:getId()
  local pvpMode = PVPWhiteDove
  if buttonId == 'whiteDoveBox' then
    pvpMode = PVPWhiteDove
  elseif buttonId == 'whiteHandBox' then
    pvpMode = PVPWhiteHand
  elseif buttonId == 'yellowHandBox' then
    pvpMode = PVPYellowHand
  elseif buttonId == 'redFistBox' then
    pvpMode = PVPRedFist
  end

  g_game.setPVPMode(pvpMode)
end

function onMountButtonClick(self, mousePos)
  local player = g_game.getLocalPlayer()
  if player then
    player:toggleMount()
  end
end

function onOutfitChange(localPlayer, outfit, oldOutfit)
  if outfit.mount == oldOutfit.mount then
    return
  end

  mountButton:setChecked(outfit.mount ~= nil and outfit.mount > 0)
end

function getPVPBoxByMode(mode)
  local widget = nil
  if mode == PVPWhiteDove then
    widget = whiteDoveBox
  elseif mode == PVPWhiteHand then
    widget = whiteHandBox
  elseif mode == PVPYellowHand then
    widget = yellowHandBox
  elseif mode == PVPRedFist then
    widget = redFistBox
  end
  return widget
end

-- status
function toggleIcon(bitChanged)
  local icon = conditionPanel:getChildById(Icons[bitChanged].id)
  if icon then
    icon:destroy()
  else
    icon = loadIcon(bitChanged)
    icon:setParent(conditionPanel)
  end
end

function loadIcon(bitChanged)
  local icon = g_ui.createWidget('ConditionWidget', conditionPanel)
  icon:setId(Icons[bitChanged].id)
  icon:setImageSource(Icons[bitChanged].path)
  icon:setTooltip(Icons[bitChanged].tooltip)
  return icon
end

function onSoulChange(localPlayer, soul)
  if not soul then return end
  soulLabel:setText(soul)
end

function onFreeCapacityChange(player, freeCapacity)
  if not freeCapacity then return end
  if freeCapacity > 99 then
    freeCapacity = math.floor(freeCapacity * 10) / 10
  end
  if freeCapacity > 999 then
    freeCapacity = math.floor(freeCapacity)
  end
  if freeCapacity > 99999 then
    --freeCapacity = math.min(9999, math.floor(freeCapacity/1000)) .. "k"
  end
  capLabel:setText(freeCapacity .. " oz")
end

function onStatesChange(localPlayer, now, old)
  if now == old then return end
  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then
      toggleIcon(bitChanged)
    end
  end
end

local function getSpecialContainerSlotWidget(slotIndex)
  if not specialContainerWindow then
    return nil
  end

  local slot = specialContainerSlots[slotIndex]
  if slot and not slot:isDestroyed() then
    return slot
  end

  slot = specialContainerWindow:recursiveGetChildById('specialSlot' .. slotIndex)
  if slot then
    specialContainerSlots[slotIndex] = slot
  end
  return slot
end

local function styleSpecialContainerSlot(slot, hasItem, isPending)
  if not slot then return end

  if hasItem then
    slot:setBorderWidth(1)
    if isPending then
      slot:setBorderColor('#ffaa00')
    else
      slot:setBorderColor('#c9a86a')
    end
    slot:setImageColor('#ffffff')
  else
    slot:setBorderWidth(1)
    slot:setBorderColor('#5c5c5c')
    slot:setImageColor('#888888')
    slot:setItemCount(0)
  end
end

local function updateSpecialContainerSlot(slotIndex)
  local slot = getSpecialContainerSlotWidget(slotIndex)
  if not slot then 
    return 
  end

  local itemData = specialContainerItems[slotIndex]
  
  if itemData then
    -- Test if item exists in client
    local itemExists = false
    
    -- Safe test for item existence
    local success, result = pcall(function()
      return g_things.getThingType(itemData.id, ThingCategoryItem)
    end)
    
    if success and result then
      itemExists = true
    end
    
    if itemExists then
      slot:setItemId(itemData.id)
      slot:setItemCount(itemData.count or 1)
      
      if itemData.pending then
        slot:setTooltip(string.format('%s\nID: %d\n%s %d\n%s', tr('Slot') .. ' ' .. slotIndex, itemData.id, tr('Amount'), itemData.count or 1, tr('Waiting for server confirmation...')))
      else
        slot:setTooltip(string.format('%s\nID: %d\n%s %d', tr('Slot') .. ' ' .. slotIndex, itemData.id, tr('Amount'), itemData.count or 1))
      end
    else
      -- Use gold coin (3031) as fallback
      slot:setItemId(3031)
      slot:setItemCount(itemData.count or 1)
      slot:setTooltip(string.format('%s\nOriginal ID: %d (not found)\nFallback: Gold Coin\n%s %d', tr('Slot') .. ' ' .. slotIndex, itemData.id, tr('Amount'), itemData.count or 1))
    end
    
    styleSpecialContainerSlot(slot, true, itemData.pending)
  else
    slot:setItemId(0)
    slot:setTooltip(tr('Empty special container slot'))
    styleSpecialContainerSlot(slot, false)
  end
end

local function refreshSpecialContainerSlots()
  for i = 1, 3 do
    updateSpecialContainerSlot(i)
  end
end

local function resetSpecialContainerState()
  specialContainerItems = {}
  refreshSpecialContainerSlots()
end

local function sendSpecialContainerOpcode(opcode, payload)
  if not g_game.isOnline() then
    return false
  end

  if g_game.sendExtendedOpcode then
    g_game.sendExtendedOpcode(opcode, payload)
    return true
  end

  local protocol = g_game.getProtocolGame()
  if protocol and protocol.sendExtendedOpcode then
    protocol:sendExtendedOpcode(opcode, payload)
    return true
  end

  g_logger.warning('Extended opcode API unavailable; unable to communicate with server for special container')
  return false
end

function requestSpecialContainerData()
  if not g_game.isOnline() then return end
  local payload = json.encode({ action = 'request' })
  sendSpecialContainerOpcode(SPECIAL_CONTAINER_OPCODE, payload)
end

local function applySpecialContainerData(items)
  specialContainerItems = {}

  if type(items) == 'table' then
    for key, entry in pairs(items) do
      local slotIndex = nil
      if type(key) == 'number' then
        slotIndex = key
      elseif type(key) == 'string' then
        slotIndex = tonumber(key)
      end

      if slotIndex and entry and entry.id then
        specialContainerItems[slotIndex] = {
          id = entry.id,
          count = entry.count or 1,
          pending = false  -- Explicitly set pending to false when loading from server
        }
      end
    end
  end

  refreshSpecialContainerSlots()
end

function onSpecialContainerExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= SPECIAL_CONTAINER_OPCODE then
    return
  end

  if not buffer or buffer:len() == 0 then
    return
  end

  local status, data = pcall(function() return json.decode(buffer) end)
  if not status or type(data) ~= 'table' then
    return
  end

  local action = data.action
  if action == 'loadSpecialContainer' then
    applySpecialContainerData(data.items or {})
  elseif action == 'updateSlot' then
    local slotIndex = tonumber(data.slot)
    if slotIndex then
      if data.item and data.item.id then
        specialContainerItems[slotIndex] = {
          id = data.item.id,
          count = data.item.count or 1
        }
      else
        specialContainerItems[slotIndex] = nil
      end
      updateSpecialContainerSlot(slotIndex)
    end
  elseif action == 'error' and data.message then
    modules.game_textmessage.displayGameMessage(data.message)
  end
end

function onSpecialContainerGameStart()
  specialContainerInitialized = true
  requestSpecialContainerData()
end

function onSpecialContainerGameEnd()
  specialContainerInitialized = false
  resetSpecialContainerState()
  specialContainerSlots = {}
  if specialContainerWindow then
    specialContainerWindow:close()
    specialContainerWindow:destroy()
    specialContainerWindow = nil
  end
end

-- Special Container functions
function toggleSpecialContainer()
  if specialContainerWindow and specialContainerWindow:isVisible() then
    specialContainerWindow:close()
  else
    openSpecialContainer()
  end
end

function openSpecialContainer()
  if not specialContainerWindow then
    -- Create MiniWindow dynamically using the proper style
    specialContainerWindow = g_ui.createWidget('MiniWindow', modules.game_interface.getRightPanel())
    
    if not specialContainerWindow then
      g_logger.error("Failed to create special container window")
      return
    end
    
    specialContainerWindow:setId('specialContainerWindow')
    specialContainerWindow:setText(tr('Special Container'))
    specialContainerWindow:setHeight(85)
    specialContainerWindow:setWidth(130)
    specialContainerWindow:disableResize() -- Disable resizing
    specialContainerWindow:setup()
    
    -- Get the contents panel
    local contentsPanel = specialContainerWindow:getChildById('contentsPanel') or specialContainerWindow:getChildById('miniwindowContents')
    
    if not contentsPanel then
      -- Create contents panel manually
      contentsPanel = g_ui.createWidget('Panel', specialContainerWindow)
      contentsPanel:setId('contentsPanel')
      contentsPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
      contentsPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      contentsPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
      contentsPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
      contentsPanel:setMarginTop(28)
      contentsPanel:setMarginLeft(6)
      contentsPanel:setMarginRight(6)
      contentsPanel:setMarginBottom(3)
    end
    
    contentsPanel:setPadding(2)
    contentsPanel:setClipping(false)
    
    -- Disable scrollbar if exists
    local scrollbar = specialContainerWindow:getChildById('miniwindowScrollBar')
    if scrollbar then
      scrollbar:setVisible(false)
      scrollbar:disable()
    end
    
    -- Create only 3 slots with ANCHORS for proper positioning
    specialContainerSlots = {}
    
    for i = 1, 3 do
      local slot = g_ui.createWidget('Item', contentsPanel)
      slot:setId('specialSlot' .. i)
      slot:setImageSource('/images/ui/item')
      slot:setWidth(34)
      slot:setHeight(34)
      slot:setPhantom(false)
      slot:setVisible(true)
      slot:setFocusable(false)

      slot:addAnchor(AnchorTop, 'parent', AnchorTop)
      slot:setMarginTop(2)
      slot:setMarginBottom(2)

      if i == 1 then
        slot:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        slot:setMarginLeft(2)
      else
        slot:addAnchor(AnchorLeft, 'prev', AnchorRight)
        slot:setMarginLeft(4)
      end
      
      specialContainerSlots[i] = slot
      updateSpecialContainerSlot(i)
      
      
      slot.onDrop = function(self, dragged)
        return onSpecialContainerDrop(self, dragged, i)
      end
      
      slot.onMouseRelease = function(self, mousePos, mouseButton)
        if mouseButton == MouseRightButton then
          return removeFromSpecialContainer(i)
        end
        return false
      end
    end
  end
  
  if specialContainerWindow then
    if g_game.isOnline() then
      requestSpecialContainerData()
    end
    specialContainerWindow:open()
    specialContainerWindow:setup()
  end
end

function onSpecialContainerClose()
  if specialContainerWindow then
    specialContainerWindow:hide()
  end
end



function onSpecialContainerClose()
  if specialContainerWindow then
    specialContainerWindow:hide()
  end
end

function onSpecialContainerDrop(slot, dragged, slotIndex)
  if specialContainerItems[slotIndex] then
    modules.game_textmessage.displayGameMessage(tr('This slot is already occupied.'))
    return false
  end

  if not dragged or not dragged.getItem or not dragged:getItem() then
    return false
  end
  
  local item = dragged:getItem()
  if not item then
    return false
  end
  
  local itemId = item:getId()
  local count = item:getCount()
  
  -- Mark as pending on client while waiting for server confirmation
  specialContainerItems[slotIndex] = {
    id = itemId,
    count = count,
    pending = true
  }
  updateSpecialContainerSlot(slotIndex)
  
  -- Use slots 11, 12, 13 (above CONST_SLOT_AMMO=10) for special container
  -- These slots don't have UI elements in the default client
  local toPos = {x = 65535, y = 10 + slotIndex, z = 0}  -- 11, 12, 13
  g_game.move(item, toPos, count)
  
  modules.game_textmessage.displayGameMessage(tr('Moving to special container...'))
  
  return true
end

function removeFromSpecialContainer(slotIndex)
  local itemData = specialContainerItems[slotIndex]
  if not itemData then
    modules.game_textmessage.displayGameMessage(tr('This slot is already empty.'))
    return false
  end
  
  local payload = json.encode({ action = 'remove', slot = slotIndex })
  if specialContainerItems[slotIndex] then
    specialContainerItems[slotIndex].pending = true
    updateSpecialContainerSlot(slotIndex)
  end
  sendSpecialContainerOpcode(SPECIAL_CONTAINER_OPCODE, payload)

  return true
end