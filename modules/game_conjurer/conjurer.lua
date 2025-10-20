-- game_conjurer/conjurer.lua

local window = nil
local button = nil
local statusTab = nil
local rankingTab = nil

local STORAGE_CONJURER_EXP = 30001
local STORAGE_CONJURER_LEVEL = 30002

-- Constants for Extended Opcodes
local ExtendedIds = {
  ConjurerDataRequest = 300,
  ConjurerData = 301,
  ConjurerRankingRequest = 302,
  ConjurerRanking = 303
}

local conjurerRanks = {
  'Novice',
  'Apprentice',
  'Adept',
  'Master',
  'Elder',
  'Legendary'
}

local conjurerExp = { 0, 500, 1500, 3000, 6000, 10000 }
local conjurerMultipliers = { 1, 2, 4, 7, 10, 15 }

-- Check if extended opcodes are available
local function checkExtendedOpcodesAvailability()
  local result = {
    registerAvailable = (type(registerExtendedOpcode) == 'function'),
    sendAvailable = (g_game and type(g_game.sendExtendedOpcode) == 'function'),
    protocolEnabled = nil
  }
  
  -- Try to send a test opcode to see if the protocol accepts it
  if result.sendAvailable then
    local success, error = pcall(function()
      g_game.sendExtendedOpcode(999, 'test')
    end)
    result.protocolEnabled = success
    
    if not success then
      g_logger.warning("Extended opcodes protocol test failed: " .. tostring(error))
    end
  end
  
  g_logger.info("Extended opcodes availability check: " .. 
                "Register: " .. tostring(result.registerAvailable) .. 
                ", Send: " .. tostring(result.sendAvailable) .. 
                ", Protocol: " .. tostring(result.protocolEnabled))
  
  return result
end

function init()
  connect(g_game, { 
    onGameEnd = hide,
    onGameStart = requestConjurerData
  })
  
  button = modules.client_topmenu.addLeftGameToggleButton('conjurerButton',
    tr('Conjurer'),
    '/images/topbuttons/new/conjurer',
    toggle, nil, nil, true)
  button:setOn(false)
  
  -- Check extended opcodes availability and register handlers
  local extendedOpcodesStatus = checkExtendedOpcodesAvailability()
  
  -- Register protocol handling - add error handling
  local function safeRegister(opcode, handler)
    if extendedOpcodesStatus.registerAvailable then
      local success, error = pcall(function()
        registerExtendedOpcode(opcode, handler)
      end)
      if not success then
        g_logger.error("Failed to register opcode " .. opcode .. ": " .. tostring(error))
      else
        g_logger.info("Successfully registered opcode " .. opcode)
      end
    else
      g_logger.warning("Function registerExtendedOpcode not available")
    end
  end
  
  safeRegister(ExtendedIds.ConjurerData, onConjurerData)
  safeRegister(ExtendedIds.ConjurerRanking, onConjurerRanking)
  
  -- Add ranking button to the main conjurer window
  local mainWindow = modules.game_interface.getRightPanel():getChildById('conjurerWindow')
  if mainWindow then
    local closeButton = mainWindow:getChildById('buttonClose')
    if closeButton then
      local rankButton = g_ui.createWidget('Button', mainWindow)
      rankButton:setId('rankButton')
      rankButton:setText(tr('View Ranking'))
      rankButton:setWidth(120)
      rankButton:setHeight(28)
      rankButton:setAnchors({bottom = 'buttonClose.bottom', right = 'buttonClose.left'})
      rankButton:setMarginRight(10)
      rankButton.onClick = toggleConjurerRankingWindow
    end
  end
end

function terminate()
  disconnect(g_game, { 
    onGameEnd = hide,
    onGameStart = requestConjurerData
  })
  
  -- Unregister protocol handlers - add error handling
  local function safeUnregister(opcode)
    if type(unregisterExtendedOpcode) == 'function' then
      local success, error = pcall(function()
        unregisterExtendedOpcode(opcode)
      end)
      if not success then
        g_logger.error("Failed to unregister opcode " .. opcode .. ": " .. tostring(error))
      end
    end
  end
  
  safeUnregister(ExtendedIds.ConjurerData)
  safeUnregister(ExtendedIds.ConjurerRanking)
  
  if window then window:destroy() window = nil end
  if button then button:destroy() button = nil end
end

function toggle()
  if not window or window:isHidden() then
    show()
  else
    hide()
  end
end

function show()
  if not window then
    window = g_ui.displayUI('ConjurerWindow')
    window:hide() -- só mostra se for chamado
    
    -- Setup tab bar
    local tabBar = window:getChildById('tabBar')
    statusTab = tabBar:addTab(tr('Status'), nil, showStatusTab)
    rankingTab = tabBar:addTab(tr('Ranking'), nil, showRankingTab)
    
    -- Select status tab by default
    tabBar:selectTab(statusTab)
  end
  
  -- Update data when opening window
  requestConjurerData()
  refreshRanking()
  
  window:show()
  window:raise()
  window:focus()
  button:setOn(true)
end

function hide()
  if window then window:hide() end
  if button then button:setOn(false) end
end

function showStatusTab()
  local statusPanel = window:getChildById('statusPanel')
  local rankingPanel = window:getChildById('rankingPanel')
  
  statusPanel:setVisible(true)
  rankingPanel:setVisible(false)
end

function showRankingTab()
  local statusPanel = window:getChildById('statusPanel')
  local rankingPanel = window:getChildById('rankingPanel')
  
  statusPanel:setVisible(false)
  rankingPanel:setVisible(true)
  
  -- Refresh ranking data when tab is shown
  refreshRanking()
end

function refreshRanking()
  if g_game.isOnline() then
    local extendedOpcodesStatus = checkExtendedOpcodesAvailability()
    
    if extendedOpcodesStatus.sendAvailable and extendedOpcodesStatus.protocolEnabled then
      g_game.sendExtendedOpcode(ExtendedIds.ConjurerRankingRequest, '')
    else
      g_logger.warning("Cannot refresh ranking: Extended opcodes not available.")
      displayErrorMessage("Extended opcodes not available. Please contact an administrator.")
    end
  else
    g_logger.warning("Cannot refresh ranking: Not online.")
  end
end

function displayErrorMessage(message)
  modules.game_textmessage.displayGameMessage(message, "Conjurer System")
end

function requestConjurerData()
  if g_game.isOnline() then
    local extendedOpcodesStatus = checkExtendedOpcodesAvailability()
    
    if extendedOpcodesStatus.sendAvailable and extendedOpcodesStatus.protocolEnabled then
      g_logger.info("Requesting conjurer data...")
      g_game.sendExtendedOpcode(ExtendedIds.ConjurerDataRequest, '')
    else
      g_logger.warning("Function sendExtendedOpcode not available for updating conjurer data.")
      displayErrorMessage("Extended opcodes not available. Please contact an administrator.")
      
      -- Use mock data as a fallback
      updateStatusTab({
        rankName = "Adept Conjurer",
        experience = 3200,
        nextLevelExp = 6000,
        chargeMultiplier = 4,
        nextRankName = "Master Conjurer",
        expNeeded = 2800
      })
    end
  else
    g_logger.warning("Not online, can't request conjurer data.")
  end
end

function updateStatusTab(data)
  if not window then return end
  
  local rankLabel = window:getChildById('rankLabel')
  local xpBar = window:getChildById('xpBar')
  local xpLabel = window:getChildById('xpLabel')
  local multiplierLabel = window:getChildById('multiplierLabel')
  local nextRankLabel = window:getChildById('nextRankLabel')
  
  rankLabel:setText('Rank: ' .. data.rankName)
  
  if data.nextLevelExp > 0 then
    xpBar:setMaximum(data.nextLevelExp)
    xpBar:setValue(data.experience)
    xpLabel:setText('XP: ' .. data.experience .. ' / ' .. data.nextLevelExp)
    nextRankLabel:setText('Próximo rank: ' .. data.nextRankName .. ' (' .. data.expNeeded .. ' XP)')
  else
    xpBar:setMaximum(100)
    xpBar:setValue(100)
    xpLabel:setText('XP: ' .. data.experience .. ' (Nível Máximo)')
    nextRankLabel:setText('Rank Máximo Alcançado')
  end
  
  multiplierLabel:setText('Multiplicador: x' .. data.chargeMultiplier)
end

function updateRankingTab(rankingData)
  if not window then return end
  
  local panel = window:getChildById('rankingListPanel')
  panel:destroyChildren()
  
  for i, entry in ipairs(rankingData) do
    local row = g_ui.createWidget('RankingTableRow', panel)
    row:getChildById('position'):setText(entry.position)
    row:getChildById('name'):setText(entry.name)
    row:getChildById('experience'):setText(entry.experience)
    
    -- Apply alternating background colors
    if i % 2 == 0 then
      row:setColor('alpha')
    else
      row:setColor(row.alternatedBackgroundColor)
    end
  end
end

function onConjurerData(protocol, opcode, buffer)
  g_logger.info("Received ConjurerData opcode with buffer length: " .. buffer:len())
  
  if buffer == '' then return end
  
  local success, data = pcall(function() 
    return json.decode(buffer)
  end)
  
  if not success or not data then
    g_logger.error("Failed to decode ConjurerData JSON: " .. tostring(data))
    return
  end
  
  updateStatusTab(data)
end

function onConjurerRanking(protocol, opcode, buffer)
  g_logger.info("Received ConjurerRanking opcode with buffer length: " .. buffer:len())
  
  if buffer == '' then return end
  
  local success, data = pcall(function() 
    return json.decode(buffer)
  end)
  
  if not success or not data then
    g_logger.error("Failed to decode ConjurerRanking JSON: " .. tostring(data))
    return
  end
  
  updateRankingTab(data)
end

function onTestButtonClick()
  displayInfoBox('Teste de conjuração', 'Aqui você pode simular um efeito visual ou ganho de XP!')
end

-- Function to toggle the ranking window
function toggleConjurerRankingWindow()
  if g_game.isOnline() then
    -- Request ranking data first
    local extendedOpcodesStatus = checkExtendedOpcodesAvailability()
    
    if extendedOpcodesStatus.sendAvailable and extendedOpcodesStatus.protocolEnabled then
      g_logger.info("Requesting conjurer ranking data...")
      g_game.sendExtendedOpcode(ExtendedIds.ConjurerRankingRequest, '')
    else
      g_logger.warning("Extended opcodes not available for updating ranking.")
      displayErrorMessage("Extended opcodes not available. Please contact an administrator.")
    end
  end
  
  -- Check if the module has a function to handle this
  if modules.game_conjurer and modules.game_conjurer.toggleConjurerRankingWindow then
    modules.game_conjurer.toggleConjurerRankingWindow()
  else
    -- Fallback: create a simple message box with mock data
    local messageBox = displayInfoBox(tr('Conjurer Ranking'), 
      tr('Top 5 Conjurers:\n\n') ..
      '1. Wizard King - 9500 exp\n' ..
      '2. Archmage - 8200 exp\n' ..
      '3. Sorcerer - 6800 exp\n' ..
      '4. Conjurer - 5400 exp\n' ..
      '5. Apprentice - 4100 exp')
    
    if messageBox then
      messageBox:setWidth(300)
      messageBox:setHeight(250)
    end
  end
end 