local conjurerWindow = nil
local conjurerButton = nil
local conjurerRankingWindow = nil
local currentRankIdForGems = nil -- Armazena o rankId atual para filtrar gemas

local rankIds = {
  [0] = 'rankNovice',
  [1] = 'rankApprentice',
  [2] = 'rankAdept',
  [3] = 'rankMaster',
  [4] = 'rankElder',
  [5] = 'rankLegendary'
}

local rankIconIds = {
  [0] = 'rankNoviceIcon',
  [1] = 'rankApprenticeIcon',
  [2] = 'rankAdeptIcon',
  [3] = 'rankMasterIcon',
  [4] = 'rankElderIcon',
  [5] = 'rankLegendaryIcon'
}

local rankColors = {
  [0] = '#c0c0c0', -- Silver
  [1] = '#a1e65b', -- Light Green
  [2] = '#5bcbe6', -- Light Blue
  [3] = '#e65bc5', -- Pink
  [4] = '#e6c75b', -- Gold
  [5] = '#ff5500'  -- Orange
}

local rankData = {
  [0] = {
    name = tr('Novice Conjurer'),
    desc = tr('Beginning your journey in conjuration magic.'),
    bonus = '+5% XP',
    chargeMultiplier = '1x',
  },
  [1] = {
    name = tr('Apprentice Conjurer'),
    desc = tr('Learning the fundamentals of magical creation.'),
    bonus = '+7% XP',
    chargeMultiplier = '2x',
  },
  [2] = {
    name = tr('Adept Conjurer'),
    desc = tr('Mastering advanced conjuration techniques.'),
    bonus = '+10% XP',
    chargeMultiplier = '4x',
  },
  [3] = {
    name = tr('Master Conjurer'),
    desc = tr('Able to conjure complex objects and elements.'),
    bonus = '+12% XP',
    chargeMultiplier = '7x',
  },
  [4] = {
    name = tr('Elder Conjurer'),
    desc = tr('Wisdom of ancient conjuration knowledge.'),
    bonus = '+15% XP',
    chargeMultiplier = '10x',
  },
  [5] = {
    name = tr('Legendary Conjurer'),
    desc = tr('Ultimate mastery of conjuration arts.'),
    bonus = '+20% XP',
    chargeMultiplier = '15x',
  }
}

-- Store the current conjurer level
local currentConjurerLevel = 0
local currentConjurerData = {
  experience = 0,
  nextLevelExp = 500,
  level = 0
}

-- Store gem system data
local availableGems = {}
local equippedGems = {}
local currentRankGems = {}

-- Persistência local das gemas equipadas (para gemas de teste)
local localEquippedGems = {
  [0] = {}, -- Rank 0
  [1] = {}, -- Rank 1
  [2] = {}, -- Rank 2
  [3] = {}, -- Rank 3
  [4] = {}, -- Rank 4
  [5] = {}  -- Rank 5
}

-- Constants for Extended Opcodes
local ExtendedIds = {
  ConjurerDataRequest = 240,
  ConjurerData = 241,
  ConjurerRankingRequest = 242,
  ConjurerRanking = 243,
  ConjurerGemRequest = 244,
  ConjurerGemData = 245,
  ConjurerGemEquip = 246,
  ConjurerGemSync = 247  -- Opcode único para sincronização de gemas
}

-- Verificar e garantir que o módulo json esteja disponível
if not json then
  -- Implementação básica do json (apenas encode)
  json = {}
  function json.encode(data)
    if type(data) == 'table' then
      local result = "{"
      local first = true
      for k, v in pairs(data) do
        if not first then result = result .. "," else first = false end
        if type(k) == 'number' then
          result = result .. json.encode(v)
        else
          result = result .. '"' .. k .. '":' .. json.encode(v)
        end
      end
      result = result .. "}"
      return result
    elseif type(data) == 'string' then
      return '"' .. data:gsub('"', '\\"') .. '"'
    elseif type(data) == 'number' then
      return tostring(data)
    elseif data == nil then
      return 'null'
    elseif type(data) == 'boolean' then
      return data and 'true' or 'false'
    else
      return '"' .. tostring(data) .. '"'
    end
  end
  
  function json.decode(str)
    g_logger.warning("Implementação json.decode simplificada - retornando string original")
    -- Implementação simplificada para dados de teste
    if str and str:match("^%s*%[") then
      -- É um array, vamos retornar dados de teste
      return {
        {position = 1, name = "Player1", experience = 9500},
        {position = 2, name = "Player2", experience = 8200},
        {position = 3, name = "Player3", experience = 6800},
        {position = 4, name = "Player4", experience = 5400},
        {position = 5, name = "Player5", experience = 4100}
      }
    else
      -- Outro tipo de dados, simplesmente retornar dados de teste
      return {
        experience = 3200,
        level = 2,
        chargeMultiplier = 4,
        rankName = "Adept Conjurer",
        nextLevelExp = 6000,
        expNeeded = 2800,
        nextRankName = "Master Conjurer"
      }
    end
  end
end

-- Verificar e garantir que o módulo de log esteja disponível
if not g_logger then
  g_logger = {}
  function g_logger.info(message)
    print("[INFO] " .. message)
  end
  function g_logger.warning(message)
    print("[WARNING] " .. message)
  end
  function g_logger.error(message)
    print("[ERROR] " .. message)
  end
end

function getCurrentConjurerLevel()
  return currentConjurerLevel
end

function init()
  conjurerWindow = g_ui.displayUI('game_conjurer', modules.game_interface.getRightPanel())
  conjurerWindow:hide()

  -- Não vamos inicializar a janela de ranking agora, faremos isso sob demanda
  -- conjurerRankingWindow = g_ui.displayUI('game_conjurer_ranking')
  -- conjurerRankingWindow:hide()

  setupTopMenuButton()
  
  -- Inicializar sistema de monitoramento de dano por gemas
  setupGemDamageMonitoring()
  
  -- Initialize all ranks as locked first
  for i = 0, 5 do
    local rankIconWidget = conjurerWindow:recursiveGetChildById(rankIconIds[i])
    if rankIconWidget then
      rankIconWidget:setOpacity(0.6)
      rankIconWidget:setImageColor('#222222')
    end
  end
  
  -- Initialize with default values
  updateConjurerUI(0, 0, 1000)
  
  -- Set up multiplier texts
  local multipliers = {
    [1] = 'Level 1: 2x charges',
    [2] = 'Level 2: 4x charges',
    [3] = 'Level 3: 7x charges',
    [4] = 'Level 4: 10x charges',
    [5] = 'Level 5: 15x charges'
  }
  
  for i = 1, 5 do
    local multWidget = conjurerWindow:recursiveGetChildById('mult'..i)
    if multWidget then
      multWidget:setText(multipliers[i])
      multWidget.onHoverChange = function(widget, hovered)
        if hovered then
          widget:setBackgroundColor('#333333')
        else
          widget:setBackgroundColor('#222222')
        end
      end
    end
  end
  
  -- Connect rank icon hover effects
  setupRankIconInteractions()
  
  -- Add level multiplier hover effects
  for i = 1, 5 do
    local multWidget = conjurerWindow:recursiveGetChildById('mult'..i)
    if multWidget then
      multWidget.onHoverChange = function(widget, hovered)
        if hovered then
          widget:setBackgroundColor('#333333')
        else
          widget:setBackgroundColor('#222222')
        end
      end
    end
  end
  
  -- Register protocol handling for ranking
  if type(registerExtendedOpcode) == 'function' then
    registerExtendedOpcode(ExtendedIds.ConjurerRanking, onConjurerRanking)
    registerExtendedOpcode(ExtendedIds.ConjurerData, onConjurerData)
    registerExtendedOpcode(ExtendedIds.ConjurerGemData, onConjurerGemData)
    registerExtendedOpcode(ExtendedIds.ConjurerGemSync, onConjurerGemSync)
  else
    if ProtocolGame and ProtocolGame.registerExtendedOpcode then
      g_logger.info("Using ProtocolGame.registerExtendedOpcode instead")
      ProtocolGame.registerExtendedOpcode(ExtendedIds.ConjurerRanking, onConjurerRanking)
      ProtocolGame.registerExtendedOpcode(ExtendedIds.ConjurerData, onConjurerData)
      ProtocolGame.registerExtendedOpcode(ExtendedIds.ConjurerGemData, onConjurerGemData)
      ProtocolGame.registerExtendedOpcode(ExtendedIds.ConjurerGemSync, onConjurerGemSync)
    else
      g_logger.error("No opcode registration method available!")
    end
  end
  
  -- Connect to inventory changes to update available gems
  connect(LocalPlayer, { onInventoryChange = onInventoryChange })
  
  setupRankIconClicks()
end

function setupRankIconInteractions()
  for i = 0, 5 do
    local rankIconWidget = conjurerWindow:getChildById(rankIconIds[i])
    local rankLabelWidget = conjurerWindow:getChildById(rankIds[i])
    
    if rankIconWidget then
      -- Add hover effects
      rankIconWidget.onHoverChange = function(widget, hovered)
        if hovered then
          widget:setOpacity(1.0)
          if rankLabelWidget then
            rankLabelWidget:setColor('#ffffff')
          end
        elseif i ~= getCurrentConjurerLevel() then
          widget:setOpacity(0.4)
          if rankLabelWidget then
            rankLabelWidget:setColor('#cccccc')
          end
        end
      end
      
      -- Add click effects
      rankIconWidget.onClick = function()
        if i <= getCurrentConjurerLevel() then
          -- Already unlocked, show info about this rank
          displayRankInfo(i)
        else
          -- Not unlocked yet, show requirements
          displayRankRequirements(i)
        end
      end
    end
  end
end

function displayRankInfo(rankIndex)
  local titles = {
    [0] = tr('Novice Conjurer'),
    [1] = tr('Apprentice Conjurer'),
    [2] = tr('Adept Conjurer'),
    [3] = tr('Master Conjurer'),
    [4] = tr('Elder Conjurer'),
    [5] = tr('Legendary Conjurer')
  }
  
  local descriptions = {
    [0] = tr('Beginning your journey in conjuration magic.'),
    [1] = tr('Learning the fundamentals of magical creation.'),
    [2] = tr('Mastering advanced conjuration techniques.'),
    [3] = tr('Able to conjure complex objects and elements.'),
    [4] = tr('Wisdom of ancient conjuration knowledge.'),
    [5] = tr('Ultimate mastery of conjuration arts.')
  }
  
  local message = titles[rankIndex] .. '\n\n' .. descriptions[rankIndex]
  
  modules.game_textmessage.displayGameMessage(message, 'Conjurer Info')
end

function displayRankRequirements(rankIndex)
  local requirements = {
    [1] = tr('Need 1,000 conjurer experience points'),
    [2] = tr('Need 5,000 conjurer experience points'),
    [3] = tr('Need 15,000 conjurer experience points'),
    [4] = tr('Need 50,000 conjurer experience points'),
    [5] = tr('Need 150,000 conjurer experience points')
  }
  
  modules.game_textmessage.displayGameMessage(tr('Locked: ') .. requirements[rankIndex], 'Conjurer Info')
end

function terminate()
  -- Disconnect inventory changes
  disconnect(LocalPlayer, { onInventoryChange = onInventoryChange })
  
  -- Unregister protocol handlers
  if type(unregisterExtendedOpcode) == 'function' then
    unregisterExtendedOpcode(ExtendedIds.ConjurerRanking)
    unregisterExtendedOpcode(ExtendedIds.ConjurerData)
    unregisterExtendedOpcode(ExtendedIds.ConjurerGemData)
    unregisterExtendedOpcode(ExtendedIds.ConjurerGemSync)
  else
    -- Try using ProtocolGame instead
    if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
      ProtocolGame.unregisterExtendedOpcode(ExtendedIds.ConjurerRanking)
      ProtocolGame.unregisterExtendedOpcode(ExtendedIds.ConjurerData)
      ProtocolGame.unregisterExtendedOpcode(ExtendedIds.ConjurerGemData)
      ProtocolGame.unregisterExtendedOpcode(ExtendedIds.ConjurerGemSync)
    end
  end
  
  if conjurerWindow then
    conjurerWindow:destroy()
    conjurerWindow = nil
  end
  
  if conjurerRankingWindow then
    conjurerRankingWindow:destroy()
    conjurerRankingWindow = nil
  end
  
  if conjurerButton then
    conjurerButton:destroy()
    conjurerButton = nil
  end
end

function toggleConjurerWindow()
  if conjurerButton:isOn() then
    conjurerButton:setOn(false)
    conjurerWindow:hide()
  else
    conjurerButton:setOn(true)
    conjurerWindow:show()
    conjurerWindow:raise()
    conjurerWindow:focus()
    
    -- Request updated data when window opens
    requestConjurerInfo()
  end
end

function toggleConjurerRankingWindow()
  -- Create ranking window if it doesn't exist
  if not conjurerRankingWindow then
    g_logger.info("Creating ranking window...")
    
    -- Try loading the OTUI file with a safe fallback
    local success, window = pcall(function()
      return g_ui.displayUI('conjurer_ranking')
    end)
    
    if success and window then
      conjurerRankingWindow = window
    else
      g_logger.error("Failed to create ranking window from OTUI file")
      
      -- Fallback to create a basic window programmatically
      conjurerRankingWindow = createBasicRankingWindow()
      if not conjurerRankingWindow then
        g_logger.error("Failed to create ranking window")
        return
      end
    end
    
    g_logger.info("Ranking window created successfully")
    
    -- Set up button callbacks
    local closeButton = conjurerRankingWindow:recursiveGetChildById('buttonClose') or 
                       conjurerRankingWindow:recursiveGetChildById('closeButton')
    if closeButton then
      closeButton.onClick = function() 
        conjurerRankingWindow:hide()
        if conjurerButton then conjurerButton:setOn(false) end
      end
    end
    
    local backButton = conjurerRankingWindow:recursiveGetChildById('buttonBack') or
                      conjurerRankingWindow:recursiveGetChildById('backButton')
    if backButton then
      backButton.onClick = function()
        conjurerRankingWindow:hide()
        if conjurerWindow then
          conjurerWindow:show()
          conjurerWindow:raise()
          conjurerWindow:focus()
          if conjurerButton then conjurerButton:setOn(true) end
        end
      end
    end
    
    local refreshButton = conjurerRankingWindow:recursiveGetChildById('refreshButton')
    if refreshButton then
      refreshButton.onClick = refreshConjurerRanking
    end
    
    -- Initially hide the window
    conjurerRankingWindow:hide()
  end
  
  -- Simple toggle visibility
  if conjurerRankingWindow:isVisible() then
    conjurerRankingWindow:hide()
    
    -- Show the main conjurer window if the button is on
    if conjurerButton and conjurerButton:isOn() then
      if conjurerWindow then
        conjurerWindow:show()
        conjurerWindow:raise()
        conjurerWindow:focus()
      end
    else
      if conjurerButton then
        conjurerButton:setOn(false)
      end
    end
  else
    -- Hide the main conjurer window
    if conjurerWindow then
      conjurerWindow:hide()
    end
    
    -- Show the ranking window
    conjurerRankingWindow:show()
    conjurerRankingWindow:raise()
    conjurerRankingWindow:focus()
    
    -- Request updated ranking data
    refreshConjurerRanking()
  end
end

function showConjurerWindow()
  if not conjurerRankingWindow then
    return
  end
  
  conjurerRankingWindow:hide()
  
  if not conjurerWindow then
    g_logger.warning("Janela principal do conjurer não foi inicializada")
    return
  end
  
  if conjurerButton then
    conjurerButton:setOn(true)
  end
  
  conjurerWindow:show()
  conjurerWindow:raise()
  conjurerWindow:focus()
end

function refreshConjurerRanking()
  -- Verificar se a janela de ranking foi criada
  if not conjurerRankingWindow then
    g_logger.warning("Tentativa de atualizar ranking, mas a janela não foi inicializada.")
    return
  end

  -- Send opcode to server requesting ranking data
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    g_logger.info("Sending ConjurerRankingRequest opcode via protocol")
    protocolGame:sendExtendedOpcode(ExtendedIds.ConjurerRankingRequest, '')
  elseif g_game and g_game.sendExtendedOpcode then
    g_logger.info("Sending ConjurerRankingRequest opcode via g_game")
    g_game.sendExtendedOpcode(ExtendedIds.ConjurerRankingRequest, '')
  else
    -- Fallback quando sendExtendedOpcode não está disponível
    g_logger.warning("Função sendExtendedOpcode não disponível para atualizar ranking.")
    -- Simular dados para teste
    local mockData = {
      {position = 1, name = "Player1", experience = 9500},
      {position = 2, name = "Player2", experience = 8200},
      {position = 3, name = "Player3", experience = 6800},
      {position = 4, name = "Player4", experience = 5400},
      {position = 5, name = "Player5", experience = 4100},
      {position = 6, name = "Player6", experience = 3200},
      {position = 7, name = "Player7", experience = 2100},
      {position = 8, name = "Player8", experience = 1400},
      {position = 9, name = "Player9", experience = 900},
      {position = 10, name = "Player10", experience = 500}
    }
    onConjurerRanking(nil, nil, json.encode(mockData))
  end
end

function requestConjurerInfo()
  -- Send opcode to server requesting conjurer data
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(ExtendedIds.ConjurerDataRequest, '')
  elseif g_game and g_game.sendExtendedOpcode then
    g_game.sendExtendedOpcode(ExtendedIds.ConjurerDataRequest, '')
  else
    -- Fallback quando sendExtendedOpcode não está disponível
    -- Usar dados simulados para testes
    updateConjurerUI(2, 3200, 6000)
  end
end

function setupTopMenuButton()
  if not conjurerButton then
    conjurerButton = modules.client_topmenu.addRightGameToggleButton('conjurerButton', tr('Conjurer'), '/images/topbuttons/new/conjurer', toggleConjurerWindow, nill, false, 4)
    conjurerButton:setOn(false)
  end
end

function updateConjurerUI(level, exp, nextExp)
  -- Update the stored level
  currentConjurerLevel = level
  
  -- Set current level label
  local currentLevelLabel = conjurerWindow:getChildById('currentLevelLabel')
  if currentLevelLabel then
    local rankName = rankIds[level]:gsub('rank', '')
    currentLevelLabel:setText(tr('Current Level: ') .. level .. ' - ' .. tr(rankName))
  end

  -- Removed bonus values and unlock dates (mocks)

  -- Update rank icons and labels
  for i = 0, 5 do
    local rankIconWidget = conjurerWindow:recursiveGetChildById(rankIconIds[i])
    local rankLabelWidget = conjurerWindow:recursiveGetChildById(rankIds[i])
    local rankBonusWidget = conjurerWindow:recursiveGetChildById(rankIds[i] .. 'Bonus')
    local rankDateWidget = conjurerWindow:recursiveGetChildById(rankIds[i] .. 'Date')
    
    if rankIconWidget and rankLabelWidget then
      if i <= level then
        -- Rank is unlocked - make it very visible
        rankIconWidget:setOpacity(1.0)
        rankIconWidget:setBorderColor(rankColors[i])
        rankIconWidget:setBorderWidth(4)  -- Borda mais grossa
        rankLabelWidget:setColor(rankColors[i])
        
        -- Hide bonus and date widgets (remove mocks)
        if rankBonusWidget then
          rankBonusWidget:setVisible(false)
        end
        
        if rankDateWidget then
          -- Hide date widget for all unlocked ranks
          rankDateWidget:setVisible(false)
        end
        
        -- Add a glow effect to the current level
        if i == level then
          rankIconWidget:setImageColor('#ffffff')
          scheduleEvent(function() pulsateRankIcon(rankIconWidget) end, 500)
        else
          -- Already unlocked ranks - brighter
          rankIconWidget:setImageColor('#ffffff')
        end
      else
        -- Rank is still locked - make it very dark
        rankIconWidget:setOpacity(0.6)  -- Bem mais escuro
        rankIconWidget:setBorderColor('#111111')  -- Borda quase preta
        rankIconWidget:setBorderWidth(1)
        rankLabelWidget:setColor('#333333')  -- Texto bem escuro
        rankIconWidget:setImageColor('#222222')  -- Ícone muito escuro
        
        -- Hide bonus and date widgets for locked ranks
        if rankBonusWidget then
          rankBonusWidget:setVisible(false)
        end
        
        if rankDateWidget then
          rankDateWidget:setVisible(false)
        end
      end
    end
  end
  
  -- Animate progress bar
  local progressBarBg = conjurerWindow:getChildById('progressBarBg')
  local progressBarFill = progressBarBg:getChildById('progressBarFill')
  local progressLabel = progressBarBg:getChildById('progressLabel')
  local percent = 0
  if nextExp > 0 then
    percent = math.min(1, exp / nextExp)
  end
  
  -- Format numbers with commas
  local formattedExp = formatNumber(exp)
  local formattedNextExp = formatNumber(nextExp)
  progressLabel:setText(formattedExp .. ' / ' .. formattedNextExp)
  
  -- Use smooth animation for the progress bar
  progressBarFill:setWidth(0)
  scheduleEvent(function()
    progressBarFill:setWidth(math.floor(progressBarBg:getWidth() * percent))
  end, 100)
  
  -- Update rank gem slots after UI update (with delay for smooth animation)
  -- Note: This only updates if rank details panel is currently open
  scheduleEvent(function()
    local rankDetailsContent = conjurerWindow:recursiveGetChildById('rankDetailsContent')
    if rankDetailsContent and rankDetailsContent:isVisible() then
      -- Get the current rank being viewed
      local currentRankId = rankDetailsContent.rankId
      if currentRankId then
        setupRankGemSystem(rankDetailsContent, currentRankId)
      end
    end
  end, 200)
end

-- Helper function to format numbers with commas
function formatNumber(num)
  local formatted = tostring(num)
  local k
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if k == 0 then break end
  end
  return formatted
end

-- Função utilitária para conversão segura
local function safeTonumber(val)
  if type(val) == 'string' then
    local cleaned = val:gsub(',', ''):match('^%s*(%d+)%s*$')
    if cleaned then
      return tonumber(cleaned)
    end
  elseif type(val) == 'number' then
    return val
  end
  return 0
end

-- Create a pulsating effect for the current rank icon
function pulsateRankIcon(widget)
  if not widget or not widget:isVisible() then return end
  
  local opacity = widget:getOpacity()
  local pulseDelta = 0.1
  local minOpacity = 0.8
  local maxOpacity = 1.0
  
  if opacity >= maxOpacity then
    pulseDelta = -pulseDelta
  elseif opacity <= minOpacity then
    pulseDelta = math.abs(pulseDelta)
  end
  
  widget:setOpacity(opacity + pulseDelta)
  scheduleEvent(function() pulsateRankIcon(widget) end, 100)
end

-- Function to open the rank details panel/modal
function showRankDetails(rankId)
  local data = rankData[rankId] or rankData[0]

  local bonusWidget = conjurerWindow:getChildById(rankIds[rankId] .. 'Bonus')
  local dateWidget = conjurerWindow:getChildById(rankIds[rankId] .. 'Date')
  local bonus = bonusWidget and bonusWidget:getText() or data.bonus
  local date = dateWidget and dateWidget:getText() or ''

  local progressText = ''
  local progressValue = 0
  local progressMax = 1
  if rankId < 5 then
    local progressBarBg = conjurerWindow:getChildById('progressBarBg')
    local progressLabel = progressBarBg and progressBarBg:getChildById('progressLabel')
    progressText = progressLabel and progressLabel:getText() or ''
    if progressText:find('/') then
      local current, max = progressText:match('([%d,]+) / ([%d,]+)')
      -- print('DEBUG: current =', current, 'max =', max)
      if current and max then
        local currentNum = safeTonumber(current)
        local maxNum = safeTonumber(max)
        progressValue = currentNum
        progressMax = maxNum
      end
    end
  else
    progressText = tr('Maximum rank achieved!')
    progressValue = 1
    progressMax = 1
  end

  local requirementText = ''
  if rankId < 5 then
    local requirements = {
      [1] = tr('Need 1,000 conjurer experience points'),
      [2] = tr('Need 5,000 conjurer experience points'),
      [3] = tr('Need 15,000 conjurer experience points'),
      [4] = tr('Need 50,000 conjurer experience points'),
      [5] = tr('Need 150,000 conjurer experience points')
    }
    requirementText = requirements[rankId + 1] or ''
  end

  local iconSources = {
    [0] = '/data/images/conjurers/1.png',
    [1] = '/data/images/conjurers/2.png',
    [2] = '/data/images/conjurers/3.png',
    [3] = '/data/images/conjurers/4.png',
    [4] = '/data/images/conjurers/5.png',
    [5] = '/data/images/conjurers/6.png'
  }

  local existingWindow = g_ui.getRootWidget():recursiveGetChildById('rankDetailsWindow')
  if existingWindow then
    existingWindow:destroy()
  end

  -- Carregar o modal a partir do novo arquivo OTUI
  local windowRoot = g_ui.displayUI('game_conjurer_rankdetails')
  local window = windowRoot:recursiveGetChildById('rankDetailsWindow') or windowRoot
  if window.center then window:center() end
  if window.raise then window:raise() end
  if window.focus then window:focus() end
  if window.show then window:show() end

  local content = window:getChildById('rankDetailsContent')
  if not content then return end
  
  -- Store rankId for later reference
  content.rankId = rankId

  -- Header: ícone e nome
  local iconWidget = content:recursiveGetChildById('rankDetailsIcon')
  if iconWidget then
    iconWidget:setImageSource(iconSources[rankId] or iconSources[0])
  end
  local nameWidget = content:recursiveGetChildById('rankDetailsName')
  if nameWidget then
    nameWidget:setText(data.name)
    nameWidget:setTextAlign(AlignCenter)
  end

  -- Descrição
  local descWidget = content:recursiveGetChildById('rankDetailsDesc')
  if descWidget then
    descWidget:setText(data.desc)
    descWidget:setTextAlign(AlignCenter)
  end

  -- Requisito para o próximo rank
  local reqLabel = content:recursiveGetChildById('rankDetailsRequirement')
  if reqLabel then
    reqLabel:setText(requirementText)
  end

  -- Data de desbloqueio
  local dateLabel = content:recursiveGetChildById('rankDetailsDate')
  if dateLabel then
    dateLabel:setText(tr('Unlocked on:') .. ' ' .. date)
  end

  -- Configurar sistema de gemas do rank
  setupRankGemSystem(content, rankId)
  
  -- Carregar gemas salvas localmente
  loadLocalEquippedGems(content, rankId)

  -- Botão de ajuda
  local helpButton = content:recursiveGetChildById('rankDetailsHelpButton')
  if helpButton then
    helpButton.onClick = function()
      showGemEffectsDetailed()
    end
    helpButton:setTooltip(tr('Clique para ver análise detalhada dos bônus das gemas'))
  end

  -- Botão de fechar já está configurado no OTUI
end

-- Exemplo de animação de desbloqueio
function animateRankUnlock(widget)
  if not widget or not widget:isVisible() then return end
  local originalColor = widget:getBorderColor()
  local highlightColor = '#ffff00'
  local steps = 6
  local function pulse(step)
    if step > steps then
      widget:setBorderColor(originalColor)
      widget:setOpacity(1)
      return
    end
    widget:setBorderColor(highlightColor)
    widget:setOpacity(1)
    scheduleEvent(function()
      widget:setBorderColor(originalColor)
      widget:setOpacity(0.7)
      scheduleEvent(function()
        pulse(step + 1)
      end, 80)
    end, 80)
  end
  pulse(1)
end

-- Exemplo de como conectar o clique do ícone ao painel de detalhes
function setupRankIconClicks()
  local iconIds = {
    [0] = 'rankNoviceIcon',
    [1] = 'rankApprenticeIcon',
    [2] = 'rankAdeptIcon',
    [3] = 'rankMasterIcon',
    [4] = 'rankElderIcon',
    [5] = 'rankLegendaryIcon'
  }
  for i = 0, 5 do
    local icon = conjurerWindow:recursiveGetChildById(iconIds[i])
    if icon then
      icon.onClick = function() showRankDetails(i) end
    end
  end
end

-- Process ranking data received from server
function onConjurerRanking(protocol, opcode, buffer)
  
  if buffer == '' then 
    return 
  end
  
  local data = json.decode(buffer)
  if not data then 
    return 
  end
  
  -- Check if ranking window exists
  if not conjurerRankingWindow then
    return
  end
  
  -- Find ranking panel
  local panel = conjurerRankingWindow:recursiveGetChildById('rankingListPanel')
  if not panel then
    return
  end
  
  panel:destroyChildren()
  
  -- Add a small delay to prevent UI update loops
  scheduleEvent(function()
    
    -- Create ranking rows
    for i, entry in ipairs(data) do
      -- Always use the fallback method since RankingRow style might not be available
      local row = g_ui.createWidget('UIWidget', panel)
      if row then
        row:setHeight(30)
        row:setBackgroundColor(i % 2 == 0 and '#222222' or '#191919')
        
        -- Helper function to safely create and configure a widget
        local function createColumnWidget(text, width, isLast)
          -- Create the widget
          local widget = g_ui.createWidget('UIWidget', row)
          if not widget then
            return nil
          end
          
          -- Set basic properties
          widget:setText(text)
          widget:setTextAlign(AlignCenter)
          widget:setFont("verdana-11px-rounded")
          widget:setColor('#ffffff')
          
          -- Set position and size
          widget:setHeight(30)
          if width then
            widget:setWidth(width)
          end
          
          return widget
        end
        
        -- Create all column widgets first
        local posWidget = createColumnWidget('#' .. entry.position, 50)
        local nameWidget = createColumnWidget(entry.name, 220)
        local levelWidget = createColumnWidget(tostring(calculateLevel(entry.experience)), 80)
        local expWidget = createColumnWidget(tostring(entry.experience))
        
        -- Now manually position them
        if posWidget then
          posWidget:setPosition({x = 0, y = 0})
        end
        
        if nameWidget and posWidget then
          nameWidget:setPosition({x = 50, y = 0})
        elseif nameWidget then
          nameWidget:setPosition({x = 0, y = 0})
        end
        
        if levelWidget and nameWidget then
          levelWidget:setPosition({x = 270, y = 0})
        elseif levelWidget then
          levelWidget:setPosition({x = 0, y = 0})
        end
        
        if expWidget and levelWidget then
          expWidget:setPosition({x = 350, y = 0})
          expWidget:setWidth(130)
        elseif expWidget then
          expWidget:setPosition({x = 0, y = 0})
        end
      else
        g_logger.warning("Failed to create row widget")
      end
    end
    
  end, 100) -- 100ms delay
end

-- Calculate level based on experience
function calculateLevel(experience)
  local level = 0
  local expThresholds = {500, 1500, 3000, 6000, 10000}
  
  for lvl, expRequired in ipairs(expThresholds) do
    if experience >= expRequired then
      level = lvl
    else
      break
    end
  end
  
  return level
end

-- Add a "View Ranking" button to the conjurer window
function setupConjurerWindow()
  local rankButton = g_ui.createWidget('Button', conjurerWindow)
  rankButton:setId('rankButton')
  rankButton:setText(tr('View Ranking'))
  rankButton:setWidth(120)
  rankButton:setHeight(30)
  rankButton:setAnchors({bottom = 'buttonClose.bottom', right = 'buttonClose.left'})
  rankButton:setMarginRight(10)
  rankButton:setFont('verdana-11px-rounded')
  rankButton:setColor('#ffffff')
  rankButton.onClick = toggleConjurerRankingWindow
end

-- Create a basic ranking window as fallback
function createBasicRankingWindow()
  local window
  
  -- Try to create the window
  local success, error = pcall(function()
    window = g_ui.createWindow('MainWindow')
    window:setId('conjurerRankingWindow')
    window:setText('Conjurer Ranking')
    window:setSize({width = 520, height = 440})
    window:setDraggable(true)
    window:setPosition({x = 100, y = 100})
    
    -- Create header
    local headerLabel = g_ui.createWidget('Label', window)
    headerLabel:setId('headerLabel')
    headerLabel:setText('Top Conjurers')
    headerLabel:setPosition({x = 210, y = 30})
    headerLabel:setFont('verdana-11px-rounded')
    headerLabel:setColor('#ffaa00')
    
    -- Create panel for the list
    local panel = g_ui.createWidget('Panel', window)
    panel:setId('rankingPanel')
    panel:setPosition({x = 20, y = 60})
    panel:setSize({width = 480, height = 320})
    
    -- Create container for the list items
    local containerPanel = g_ui.createWidget('Panel', panel)
    containerPanel:setId('rankingListPanelContainer')
    containerPanel:setPosition({x = 0, y = 30})
    containerPanel:setSize({width = 480, height = 270})
    
    -- Create the panel for list items
    local listPanel = g_ui.createWidget('Panel', containerPanel)
    listPanel:setId('rankingListPanel')
    listPanel:setPosition({x = 0, y = 0})
    listPanel:setSize({width = 480, height = 270})
    
    -- Create close button
    local closeButton = g_ui.createWidget('Button', window)
    closeButton:setId('buttonClose')
    closeButton:setText('Close')
    closeButton:setPosition({x = 360, y = 400}) 
    closeButton:setSize({width = 90, height = 30})
    closeButton:setFont('verdana-11px-rounded')
    closeButton:setColor('#ffffff')
    closeButton.onClick = function() window:hide() end
    
    -- Create refresh button
    local refreshButton = g_ui.createWidget('Button', panel)
    refreshButton:setId('refreshButton')
    refreshButton:setText('Refresh')
    refreshButton:setPosition({x = 210, y = 280})
    refreshButton:setSize({width = 120, height = 30})
    refreshButton:setFont('verdana-11px-rounded')
    refreshButton:setColor('#ffffff')
    refreshButton.onClick = refreshConjurerRanking
    
    -- Create back button
    local backButton = g_ui.createWidget('Button', window)
    backButton:setId('buttonBack')
    backButton:setText('Back')
    backButton:setPosition({x = 260, y = 400})
    backButton:setSize({width = 90, height = 30})
    backButton:setFont('verdana-11px-rounded')
    backButton:setColor('#ffffff')
    backButton.onClick = function() 
      window:hide()
      if conjurerWindow then 
        conjurerWindow:show() 
        conjurerWindow:raise()
        conjurerWindow:focus()
      end
    end
    
    -- Create table header
    local tableHeader = g_ui.createWidget('UIWidget', panel)
    tableHeader:setId('tableHeader')
    tableHeader:setPosition({x = 0, y = 0})
    tableHeader:setSize({width = 480, height = 30})
    tableHeader:setBackgroundColor('#222222')
    
    -- Create position header
    local posHeader = g_ui.createWidget('Label', tableHeader)
    posHeader:setId('positionHeader')
    posHeader:setText('#')
    posHeader:setPosition({x = 0, y = 8})
    posHeader:setSize({width = 50, height = 20})
    posHeader:setFont('verdana-11px-rounded')
    posHeader:setTextAlign(AlignCenter)
    posHeader:setColor('#ffffff')
    
    -- Create name header
    local nameHeader = g_ui.createWidget('Label', tableHeader)
    nameHeader:setId('nameHeader')
    nameHeader:setText('Name')
    nameHeader:setPosition({x = 50, y = 8})
    nameHeader:setSize({width = 220, height = 20})
    nameHeader:setFont('verdana-11px-rounded')
    nameHeader:setTextAlign(AlignCenter)
    nameHeader:setColor('#ffffff')
    
    -- Create level header
    local levelHeader = g_ui.createWidget('Label', tableHeader)
    levelHeader:setId('levelHeader')
    levelHeader:setText('Level')
    levelHeader:setPosition({x = 270, y = 8})
    levelHeader:setSize({width = 80, height = 20})
    levelHeader:setFont('verdana-11px-rounded')
    levelHeader:setTextAlign(AlignCenter)
    levelHeader:setColor('#ffffff')
    
    -- Create experience header
    local expHeader = g_ui.createWidget('Label', tableHeader)
    expHeader:setId('experienceHeader')
    expHeader:setText('Experience')
    expHeader:setPosition({x = 350, y = 8})
    expHeader:setSize({width = 130, height = 20})
    expHeader:setFont('verdana-11px-rounded')
    expHeader:setTextAlign(AlignCenter)
    expHeader:setColor('#ffffff')
  end)
  
  if not success then
    g_logger.error("Error creating basic ranking window: " .. error)
    return nil
  end
  
  return window
end

-- Setup gem system for specific rank
function setupRankGemSystem(content, rankId)
  -- Configurar informações das gemas do rank
  local gemSlotsInfo = content:recursiveGetChildById('gemSlotsInfo')
  if gemSlotsInfo then
    local rankSpells = {
      [0] = "Exori Vis, Exori Mort, Exori Flam",
      [1] = "Sudden Death Rune, Heavy Magic Missile",
      [2] = "Ultimate Healing Rune, Explosion Rune",
      [3] = "Avalanche Rune, Great Fireball Rune",
      [4] = "Energy Bomb Rune, Sudden Death Rune",
      [5] = "All Master Spells and Runes"
    }
    
    local spells = rankSpells[rankId] or "Unknown spells"
    gemSlotsInfo:setText(tr('Gemas aplicam bonus em: ') .. spells)
  end
  
  local slotsUnlocked = 0
  local currentLevel = currentConjurerLevel or 0
  
  if rankId > currentLevel then
    slotsUnlocked = 0
  elseif rankId < currentLevel then
    slotsUnlocked = 3
  elseif rankId == currentLevel then
    local currentExp = currentConjurerData.experience or 0
    local nextLevelExp = currentConjurerData.nextLevelExp or 500
    local expPercentage = nextLevelExp > 0 and (currentExp / nextLevelExp) * 100 or 0
    
    if expPercentage >= 100 then
      slotsUnlocked = 3
    elseif expPercentage >= 75 then
      slotsUnlocked = 2
    elseif expPercentage >= 50 then
      slotsUnlocked = 1
    else
      slotsUnlocked = 0
    end
  end
  
  -- Configurar slots de gemas
  for i = 1, 3 do
    local gemSlot = content:recursiveGetChildById('gemSlot' .. i)
    local gemSlotBox = content:recursiveGetChildById('gem_slot_box' .. i)
    local gemSlotLabel = content:recursiveGetChildById('gemSlot' .. i .. '_label')
    
    if gemSlot and gemSlotBox then
      if i <= slotsUnlocked then
        -- Slot desbloqueado
        gemSlotBox:setBackgroundColor('#333333')
        gemSlotBox:setBorderColor('#00aa00')
        gemSlot:setOpacity(1.0)
        gemSlot:setImageColor('#ffffff')
        
        if gemSlotLabel then
          gemSlotLabel:setColor('#00aa00')
          gemSlotLabel:setText(tr('Slot ') .. i)
        end
        
        -- Configurar drag & drop para gemas
        gemSlot.onDrop = function(self, dragged)
          -- Verificar se é uma gema válida
          if not dragged or not dragged.gemData then
            return false
          end
          
          return handleGemDrop(self, dragged, rankId, i)
        end
        
        -- Clique direito remove gema
        gemSlot.onMouseRightRelease = function(self)
          return removeGemFromSlot(rankId, i)
        end
        
        -- Alternativa: usar onMousePress para clique direito
        gemSlot.onMousePress = function(self, mousePos, mouseButton)
          if mouseButton == MouseRightButton then
            return removeGemFromSlot(rankId, i)
          end
          return false
        end
        
        -- Tooltip
        gemSlot:setTooltip(tr('Arraste uma gema aqui ou clique direito para remover'))
        
      else
        gemSlotBox:setBackgroundColor('#222222')
        gemSlotBox:setBorderColor('#444444')
        gemSlot:setOpacity(0.3)
        gemSlot:setImageColor('#555555')
        
        if gemSlotLabel then
          gemSlotLabel:setColor('#666666')
          gemSlotLabel:setText(tr('Bloqueado'))
        end
        
        local tooltipText = ''
        if rankId > currentLevel then
          tooltipText = tr('Desbloqueado ao alcançar o rank') .. ' ' .. tostring(rankId)
        else
          local expNeeded = {50, 75, 100}
          local expPercent = expNeeded[i] or 100
          tooltipText = tr('Desbloqueado com') .. ' ' .. tostring(expPercent) .. '% ' .. tr('de EXP no rank')
        end
        gemSlot:setTooltip(tooltipText)
        
        gemSlot.onDrop = nil
        gemSlot.onMouseRightRelease = nil
        gemSlot.onMousePress = nil
      end
    end
  end
  
  -- Configurar gemas disponíveis
  setupAvailableGems(content, rankId)
  
  -- Carregar gemas equipadas para este rank
  loadRankGems(rankId)
end

-- Setup available gems panel
function setupAvailableGems(content, rankId)
  local gemsPanel = content:recursiveGetChildById('availableGemsPanel')
  if not gemsPanel then 
    g_logger.warning("availableGemsPanel not found!")
    return 
  end
  
  gemsPanel:destroyChildren()
  
  -- Mostrar mensagem de carregamento
  local loadingLabel = g_ui.createWidget('Label', gemsPanel)
  loadingLabel:setText(tr('Carregando gemas do inventario...'))
  loadingLabel:setColor('#ffaa00')
  loadingLabel:setFont('verdana-11px-rounded')
  loadingLabel:setTextAlign(AlignCenter)
  
  -- Solicitar lista de gemas do servidor (similar ao autoloot)
  requestGemsFromServer(rankId)
end

-- Request gems list from server (similar to autoloot backpack list)
function requestGemsFromServer(rankId)
  -- Armazenar o rankId globalmente para usar quando a resposta chegar
  currentRankIdForGems = rankId
  
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    -- Enviar requisição para listar gemas disponíveis
    local data = {action = "listGems"}
    protocolGame:sendExtendedOpcode(ExtendedIds.ConjurerGemRequest, json.encode(data))
  end
end

-- Get all equipped gems across all ranks (including current rank being viewed)
function getEquippedGemsInOtherRanks(currentRankId)
  local equippedGems = {}
  
  -- Verificar TODAS as ranks, incluindo a atual
  for rankId = 0, 5 do
    if localEquippedGems[rankId] then
      for slotNum, gemData in pairs(localEquippedGems[rankId]) do
        -- Adicionar itemId à lista de gemas equipadas
        table.insert(equippedGems, gemData.itemId)
      end
    end
  end
  
  return equippedGems
end

-- Update gems panel with data from server
function updateGemsPanel(gemsData, currentRankId)
  -- Encontrar o painel de gemas
  local content = g_ui.getRootWidget():recursiveGetChildById('rankDetailsContent')
  if not content then 
    return 
  end
  
  local gemsPanel = content:recursiveGetChildById('availableGemsPanel')
  if not gemsPanel then 
    return 
  end
  
  gemsPanel:destroyChildren()
  
  -- Get gems equipped in other ranks
  local equippedInOtherRanks = getEquippedGemsInOtherRanks(currentRankId or 0)
  
  -- Mapeamento de itemId para dados da gema
  local gemDataMap = {
    [5273] = {name = "Attack Gem", bonus = "atk", value = 5, color = "#ff4444"},
    [5274] = {name = "Defense Gem", bonus = "def", value = 5, color = "#4444ff"},
    [5275] = {name = "Mana Regen Gem", bonus = "manaregen", value = 2, color = "#44ff44"},
    [5276] = {name = "Health Regen Gem", bonus = "healthregen", value = 3, color = "#ffaa44"},
    [5277] = {name = "Speed Gem", bonus = "speed", value = 10, color = "#ff44ff"}
  }
  
  if not gemsData or #gemsData == 0 then
    local noGemsLabel = g_ui.createWidget('Label', gemsPanel)
    -- noGemsLabel:setText(tr('Nenhuma gema encontrada no inventario.'))
    noGemsLabel:setColor('#888888')
    noGemsLabel:setFont('verdana-11px-rounded')
    noGemsLabel:setTextAlign(AlignCenter)
    noGemsLabel:setSize({width = 350, height = 80})
    noGemsLabel:setTextWrap(true)
    
    -- Atualizar info
    local inventoryInfo = content:recursiveGetChildById('gemsInventoryInfo')
    if inventoryInfo then
      inventoryInfo:setText(tr('Nenhuma gema encontrada no inventário'))
      inventoryInfo:setColor('#888888')
    end
    return
  end
  
  local gemsFound = 0
  
  -- Criar widgets para cada gema retornada pelo servidor
  for _, gemData in ipairs(gemsData) do
    local itemId = gemData.itemId
    local count = gemData.count or 1
    
    -- Check if this gem is equipped in another rank
    local isEquippedElsewhere = false
    for _, equippedItemId in ipairs(equippedInOtherRanks) do
      if equippedItemId == itemId then
        isEquippedElsewhere = true
        break
      end
    end
    
    -- Skip this gem if it's equipped in another rank
    if isEquippedElsewhere then
      goto continue
    end
    
    local gemInfo = gemDataMap[itemId]
    if gemInfo then
      -- Container principal da gema com design elegante
      local gemContainer = g_ui.createWidget('UIWidget', gemsPanel)
      gemContainer:setSize({width = 62, height = 62})
      gemContainer:setBackgroundColor('#1e1e1e')
      gemContainer:setBorderWidth(1)
      gemContainer:setBorderColor('#444444')
      gemContainer:setPhantom(false)
      gemContainer:setId('gemContainer_' .. itemId)  -- Give it an ID for debugging
      -- Remover qualquer posicionamento manual para usar apenas o grid
      
      -- Moldura interna com gradiente
      local innerFrame = g_ui.createWidget('UIWidget', gemContainer)
      innerFrame:setSize({width = 58, height = 58})
      innerFrame:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      innerFrame:addAnchor(AnchorTop, 'parent', AnchorTop)
      innerFrame:setMargin(2)
      innerFrame:setBackgroundColor('#2a2a2a')
      innerFrame:setBorderWidth(1)
      innerFrame:setBorderColor(gemInfo.color)
      
      -- Área da imagem sem fundo (centralizada)
      local imageArea = g_ui.createWidget('UIWidget', innerFrame)
      imageArea:setSize({width = 48, height = 48})
      imageArea:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
      imageArea:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
      imageArea:setPhantom(true)
      
      -- Widget da imagem da gema
      local gemWidget = g_ui.createWidget('UIWidget', imageArea)
      if gemWidget then
        gemWidget:setSize({width = 46, height = 46})
        gemWidget:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
        gemWidget:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        
        -- Carregar imagem da gema
        local imagePath = string.format('/images/items/%d.png', itemId)
        if g_resources.fileExists(imagePath) then
          gemWidget:setImageSource(imagePath)
          gemWidget:setImageSmooth(true)
        else
          -- Fallback mais elegante
          gemWidget:setBackgroundColor(gemInfo.color)
          gemWidget:setOpacity(0.8)
        end
        
        gemWidget:setPhantom(false)
        gemWidget:setDraggable(true)  -- Make gemWidget draggable
        innerFrame:setDraggable(true)  -- Make innerFrame draggable
        imageArea:setDraggable(true)   -- Make imageArea draggable
        
        -- Tooltip elegante e informativo
        local tooltipText = '◆ ' .. gemInfo.name .. ' ◆\n'
        tooltipText = tooltipText .. '━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        tooltipText = tooltipText .. '> Tipo: ' .. gemInfo.bonus:upper() .. '\n'
        tooltipText = tooltipText .. '> Bonus: +' .. gemInfo.value .. '\n'
        if count > 1 then
          tooltipText = tooltipText .. '> Quantidade: ' .. count .. '\n'
        end
        tooltipText = tooltipText .. '━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        tooltipText = tooltipText ..  'Arraste para equipar nos slots'
        gemWidget:setTooltip(tooltipText)
        
        -- Badge de quantidade estilizado
        if count > 1 then
          local countContainer = g_ui.createWidget('UIWidget', gemContainer)
          countContainer:setSize({width = 18, height = 16})
          countContainer:addAnchor(AnchorRight, 'parent', AnchorRight)
          countContainer:addAnchor(AnchorTop, 'parent', AnchorTop)
          countContainer:setMargin(2)
          countContainer:setBackgroundColor('#d32f2f')
          countContainer:setBorderWidth(1)
          countContainer:setBorderColor('#ffffff')
          
          -- Gradiente interno
          local countInner = g_ui.createWidget('UIWidget', countContainer)
          countInner:setSize({width = 16, height = 14})
          countInner:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
          countInner:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
          countInner:setBackgroundColor('#b71c1c')
          
          local countText = g_ui.createWidget('Label', countInner)
          countText:setText(tostring(count))
          countText:setFont('verdana-11px-rounded')
          countText:setColor('#ffffff')
          countText:addAnchor(AnchorFill, 'parent', AnchorFill)
          countText:setTextAlign(AlignCenter)
        end
        
        -- Indicador de raridade (canto inferior direito)
        local rarityDot = g_ui.createWidget('UIWidget', innerFrame)
        rarityDot:setSize({width = 8, height = 8})
        rarityDot:addAnchor(AnchorRight, 'parent', AnchorRight)
        rarityDot:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        rarityDot:setMargin(2)
        rarityDot:setBackgroundColor(gemInfo.color)
        rarityDot:setBorderWidth(1)
        rarityDot:setBorderColor('#ffffff')
        
        -- Armazenar dados da gema (inclui quantidade retornada pelo servidor)
        -- Store on both gemWidget and gemContainer so it's accessible during drag
        local gemData = {
          id = itemId,
          name = gemInfo.name,
          bonus = gemInfo.bonus,
          value = gemInfo.value,
          color = gemInfo.color,
          itemId = itemId,
          count = count
        }
        gemWidget.gemData = gemData
        gemContainer.gemData = gemData  -- Also store on container for drag access
        innerFrame.gemData = gemData   -- Also store on inner frame
        imageArea.gemData = gemData     -- Also store on image area
        
        -- Efeitos hover sofisticados
        gemContainer.onHoverChange = function(widget, hovered)
          if hovered then
            widget:setBackgroundColor('#2e2e2e')
            widget:setBorderColor(gemInfo.color)
            innerFrame:setBackgroundColor('#3a3a3a')
            innerFrame:setBorderColor('#ffffff')
            rarityDot:setSize({width = 10, height = 10})
          else
            widget:setBackgroundColor('#1e1e1e')
            widget:setBorderColor('#444444')
            innerFrame:setBackgroundColor('#2a2a2a')
            innerFrame:setBorderColor(gemInfo.color)
            rarityDot:setSize({width = 8, height = 8})
          end
        end
        
        -- Eventos de drag on gemWidget
        gemWidget.onMousePress = function(self, mousePos, mouseButton)
          if mouseButton == MouseLeftButton then
            return true  -- Return true to capture the event and start drag
          end
          return false
        end
        
        -- Efeito hover (já configurado acima, removido duplicata)
        
        gemsFound = gemsFound + 1
      end
    end
    
    ::continue::
  end
  
  -- Atualizar informação do inventário
  local inventoryInfo = content:recursiveGetChildById('gemsInventoryInfo')
  if inventoryInfo then
    if gemsFound > 0 then
      inventoryInfo:setText(tr('Gemas encontradas: ') .. gemsFound .. tr(' tipo(s) diferentes'))
      inventoryInfo:setColor('#00aa00')
    else
      inventoryInfo:setText(tr('Nenhuma gema encontrada'))
      inventoryInfo:setColor('#888888')
    end
  end
end

-- Handle gem drop on slot
function handleGemDrop(slot, dragged, rankId, slotNumber)
  if not dragged then
    return false
  end
  
  if not dragged.gemData then
    -- Tentar obter gemData do item ID
    local itemId = dragged:getItemId()
    if itemId then
      -- Mapear item ID para gem data
      local gemMap = {
        [5273] = {id = 1, name = "Attack Gem", bonus = "atk", value = 5, color = "#ff4444", itemId = 5273},
        [5274] = {id = 2, name = "Defense Gem", bonus = "def", value = 5, color = "#4444ff", itemId = 5274},
        [5275] = {id = 3, name = "Mana Regen Gem", bonus = "manaregen", value = 2, color = "#44ff44", itemId = 5275},
        [5276] = {id = 4, name = "Health Regen Gem", bonus = "healthregen", value = 3, color = "#ffaa44", itemId = 5276},
        [5277] = {id = 5, name = "Speed Gem", bonus = "speed", value = 10, color = "#ff44ff", itemId = 5277}
      }

      local gem = gemMap[itemId]
      if gem then
        gem.count = 1  -- Set count for inventory drags
        dragged.gemData = gem
      else
        return false
      end
    else
      return false
    end
  else
    -- Ensure count is set for inventory drags
    if not dragged.gemData.count then
      dragged.gemData.count = 1
    end
  end
  
  local gem = dragged.gemData
  
  local player = g_game.getLocalPlayer()
  if not player then
    return false
  end
  
  -- Verificar se o jogador ainda tem a gema no inventário
  -- NOTE: client-side getItemsCount only knows about opened containers; the server may report gems inside closed containers.
  -- Use the widget-provided count as a fallback so dragging from the "available gems" panel still works.
  -- Removed client-side inventory check as it's unreliable for closed containers.
  -- Server will validate the actual inventory contents.
  -- local inventoryCount = player:getItemsCount(gem.itemId) or 0
  -- local widgetCount = (dragged and dragged.gemData and dragged.gemData.count) or 0
  -- if inventoryCount <= 0 and widgetCount <= 0 then
  --   modules.game_textmessage.displayGameMessage(tr('Você não possui esta gema no inventário!'), 'Conjurer System')
  --   return false
  -- end
  
  -- Verificar se já há uma gema equipada neste slot
  if slot.equippedGem then
    modules.game_textmessage.displayGameMessage(tr('Remova a gema atual primeiro!'), 'Conjurer System')
    return false
  end
  
  -- Equipar a gema visualmente (usar setImageSource para UIItem virtual)
  local imagePath = string.format('/images/items/%d.png', gem.itemId)
  if g_resources.fileExists(imagePath) then
    slot:setImageSource(imagePath)
  else
    slot:setItemId(gem.itemId) -- Fallback
  end
  slot:setImageColor('#ffffff') -- Cor normal para gemas equipadas
  slot:setOpacity(1.0)
  
  -- Armazenar dados da gema no slot
  slot.equippedGem = gem
  
  -- Salvar localmente para persistência (especialmente gemas de teste)
  if not localEquippedGems[rankId] then
    localEquippedGems[rankId] = {}
  end
  localEquippedGems[rankId][slotNumber] = {
    itemId = gem.itemId,
    name = gem.name,
    bonus = gem.bonus,
    value = gem.value,
    color = gem.color
  }
  
  -- Sincronizar com servidor
  syncGemsWithServer(rankId)
  
  -- Atualizar tooltip
  slot:setTooltip(gem.name .. '\n+' .. gem.value .. ' ' .. gem.bonus .. '\nClique direito para remover')
  
  -- Atualizar efeitos ativos
  updateRankGemsEffects()
  
  -- Atualizar painel de gemas disponíveis (remover a gema equipada da lista)
  local content = g_ui.getRootWidget():recursiveGetChildById('rankDetailsContent')
  if content then
    setupAvailableGems(content, rankId)
  end
  
  return true
end

-- Remove gem from slot
function removeGemFromSlot(rankId, slotNumber)
  local content = g_ui.getRootWidget():recursiveGetChildById('rankDetailsContent')
  if not content then 
    return false 
  end
  
  local slot = content:recursiveGetChildById('gemSlot' .. slotNumber)
  if not slot then
    return false
  end
  
  if not slot.equippedGem then
    return false
  end
  
  local equippedGem = slot.equippedGem
  
  -- Remover do servidor
  removeGemFromServer(rankId, slotNumber)
  
  -- Limpar visualmente
  slot:setImageSource('/images/ui/item-blessed') -- Voltar ao ícone padrão
  slot:setImageColor('#aaaaaa') -- Cor padrão do slot vazio
  slot:setOpacity(0.5)
  slot.equippedGem = nil
  
  -- Limpar do armazenamento local
  if localEquippedGems[rankId] and localEquippedGems[rankId][slotNumber] then
    localEquippedGems[rankId][slotNumber] = nil
    
    -- Sincronizar remoção com servidor
    removeGemFromServer(rankId, slotNumber)
  end
  
  -- Restaurar tooltip
  slot:setTooltip(tr('Arraste uma gema aqui ou clique direito para remover'))
  
  -- Mensagem de confirmação
  modules.game_textmessage.displayGameMessage(tr('Gema removida com sucesso!'), 'Conjurer System')
  
  -- Atualizar efeitos ativos
  updateRankGemsEffects()
  
  -- Atualizar painel de gemas disponíveis (adicionar a gema de volta)
  setupAvailableGems(content, rankId)
  
  return true
end

-- Update rank gems effects display with detailed info
function updateRankGemsEffects()
  local content = g_ui.getRootWidget():recursiveGetChildById('rankDetailsContent')
  if not content then return end
  
  local effectsLabel = content:recursiveGetChildById('rankGemsEffects')
  if not effectsLabel then return end
  
  local equippedGems = {}
  local effectsText = ""
  local bonusTotals = {}
  
  -- Coletar gemas equipadas e calcular totais
  for i = 1, 3 do
    local slot = content:recursiveGetChildById('gemSlot' .. i)
    if slot and slot.equippedGem then
      table.insert(equippedGems, slot.equippedGem)
      
      -- Acumular bônus por tipo
      local bonus = slot.equippedGem.bonus
      local value = slot.equippedGem.value
      if not bonusTotals[bonus] then
        bonusTotals[bonus] = 0
      end
      bonusTotals[bonus] = bonusTotals[bonus] + value
    end
  end
  
  if #equippedGems == 0 then
    effectsText = tr('Efeitos Ativos: Nenhuma gema equipada')
    effectsLabel:setColor('#888888')
  else
    -- Mostrar totais organizados por tipo
    local effects = {}
    local bonusIcons = {
      atk = "A = ",
      def = "D = ",
      manaregen = "MR = ",
      healthregen = "HR = ",
      speed = "Speed = "
    }
    
    for bonusType, totalValue in pairs(bonusTotals) do
      local icon = bonusIcons[bonusType] or "$"
      table.insert(effects, icon .. "+" .. totalValue .. " " .. bonusType:upper())
    end
    
    effectsText = tr('Efeitos Ativos: ') .. table.concat(effects, ' | ')
    effectsLabel:setColor('#00ff00')
  end
  
  effectsLabel:setText(effectsText)
  
  -- Atualizar tooltip com informações detalhadas
  if #equippedGems > 0 then
    local tooltipText = "DETALHES DOS BÔNUS ATIVOS:\n\n"
    
    for i, gem in ipairs(equippedGems) do
      tooltipText = tooltipText .. "Slot " .. i .. ": " .. gem.name .. "\n"
      tooltipText = tooltipText .. "  > +" .. gem.value .. " " .. gem.bonus:upper() .. "\n\n"
    end
    
    tooltipText = tooltipText .. "💡 Clique no botão '?' para análise detalhada"
    effectsLabel:setTooltip(tooltipText)
  else
    effectsLabel:setTooltip(tr('Nenhuma gema equipada'))
  end
end

-- Funções antigas removidas - agora usamos syncGemsWithServer() e removeGemFromServer()

-- ============================================================================
-- SISTEMA DE DANO REAL DAS GEMAS
-- ============================================================================
-- O dano das gemas agora é aplicado DIRETAMENTE no servidor via onHealthChange()
-- Este cliente mantém apenas os efeitos visuais e a sincronização das gemas
-- O dano real é calculado em: data/events/scripts/gem_damage_system.lua
-- ============================================================================

-- Load gems for specific rank
function loadRankGems(rankId)
  -- Solicitar dados das gemas do servidor para este rank específico
  if g_game.isOnline() and g_game.sendExtendedOpcode then
    local data = {rank = rankId}
    g_game.sendExtendedOpcode(ExtendedIds.ConjurerGemRequest, json.encode(data))
  end
end

-- Sistema de monitoramento de dano com bônus de gemas
local lastDamageValue = 0
local gemBonusTracker = {
  enabled = false,
  testMode = false, -- Cliente agora observa apenas se ativado manualmente
  clientVisualsEnabled = false,
  attackBonus = 0,
  lastAttackTime = 0,
  damageHistory = {},
  baseDamageRange = {min = 40, max = 70} -- Faixa de dano base estimada
}

-- Função para detectar se o dano foi influenciado por bônus de gemas
function analyzeDamageForGemBonus(damageValue)
  if not gemBonusTracker.enabled then return false end
  
  -- Obter bônus atual de ataque das gemas
  local currentAttackBonus = getCurrentAttackBonus()
  if currentAttackBonus <= 0 then return false end
  
  -- Adicionar ao histórico de dano
  table.insert(gemBonusTracker.damageHistory, {
    damage = damageValue,
    time = os.time(),
    bonus = currentAttackBonus
  })
  
  -- Manter apenas os últimos 15 ataques para análise estatística
  if #gemBonusTracker.damageHistory > 15 then
    table.remove(gemBonusTracker.damageHistory, 1)
  end
  
  -- Análise estatística do histórico para detectar padrões
  local recentDamages = {}
  local currentTime = os.time()
  
  -- Pegar apenas ataques dos últimos 30 segundos
  for _, record in ipairs(gemBonusTracker.damageHistory) do
    if currentTime - record.time <= 30 then
      table.insert(recentDamages, record.damage)
    end
  end
  
  -- Se temos poucos dados, usar método simples (MUITO mais generoso para teste)
  if #recentDamages < 3 then
    -- Para teste: ativar 70% das vezes se tiver ATK bonus
    local threshold = gemBonusTracker.baseDamageRange.min
    local activated = damageValue >= threshold or (math.random(100) <= 70)
    g_logger.info(string.format("🔍 SIMPLE ANALYSIS - Damage: %d, Threshold: %.1f, Bonus: +%d, Activated: %s", 
      damageValue, threshold, currentAttackBonus, tostring(activated)))
    return activated
  end
  
  -- Análise estatística: calcular média e desvio padrão dos danos recentes
  local sum = 0
  for _, dmg in ipairs(recentDamages) do
    sum = sum + dmg
  end
  local average = sum / #recentDamages
  
  -- Calcular desvio padrão
  local variance = 0
  for _, dmg in ipairs(recentDamages) do
    variance = variance + (dmg - average) ^ 2
  end
  variance = variance / #recentDamages
  local stdDev = math.sqrt(variance)
  
  -- Considerar bônus ativado se o dano atual está acima da média (mais sensível)
  local threshold = average + (stdDev * 0.3) -- Muito mais sensível para detectar bonus
  local isBonusActivated = damageValue >= threshold
  
  -- Método alternativo: verificar se está acima do percentil 50% dos danos recentes (muito generoso)
  table.sort(recentDamages)
  local percentil50Index = math.ceil(#recentDamages * 0.50)
  local percentil50Value = recentDamages[percentil50Index] or gemBonusTracker.baseDamageRange.max
  
  -- Critério muito mais permissivo
  local isAbovePercentil = damageValue >= percentil50Value
  isBonusActivated = isBonusActivated or isAbovePercentil
  
  -- Chance adicional baseada no bônus da gema (MUITO generosa para teste)
  if not isBonusActivated and currentAttackBonus > 0 then
    -- Chance muito alta: +5 ATK = 80% chance
    local bonusChance = math.min(currentAttackBonus * 16, 90) -- Max 90%
    local randomChance = math.random(100)
    if randomChance <= bonusChance then
      isBonusActivated = true
      g_logger.info(string.format("💎 BONUS ACTIVATED BY GEM CHANCE (%d%% with +%d ATK)", bonusChance, currentAttackBonus))
    end
  end
  
  g_logger.info(string.format("💥 DAMAGE ANALYSIS - Value: %d, Avg: %.1f, Threshold: %.1f, P50: %d, Bonus: +%d, Activated: %s", 
    damageValue, average, threshold, percentil50Value, currentAttackBonus, tostring(isBonusActivated)))
  
  return isBonusActivated
end

-- Obter bônus de ataque atual das gemas equipadas
function getCurrentAttackBonus()
  local totalAttackBonus = 0
  
  -- Verificar gemas salvas localmente para o rank atual
  local currentRank = 1 -- Assumindo rank 1 por enquanto, pode ser dinamizado depois
  
  if localEquippedGems[currentRank] then
    for slotNumber, gemData in pairs(localEquippedGems[currentRank]) do
      if gemData and gemData.bonus == "atk" then
        totalAttackBonus = totalAttackBonus + gemData.value
        g_logger.info(string.format("🔍 Found ATK gem in slot %d: +%d (total: %d)", 
          slotNumber, gemData.value, totalAttackBonus))
      end
    end
  end
  
  -- Fallback: verificar slots visuais também
  local content = g_ui.getRootWidget():recursiveGetChildById('rankDetailsContent')
  if content then
    for i = 1, 3 do
      local slot = content:recursiveGetChildById('gemSlot' .. i)
      if slot and slot.equippedGem and slot.equippedGem.bonus == "atk" then
        totalAttackBonus = totalAttackBonus + slot.equippedGem.value
      end
    end
  end
  
  g_logger.info("💎 Total ATK bonus calculated: +" .. totalAttackBonus)
  return totalAttackBonus
end

-- Mostrar efeito visual quando bônus de gema é ativado
-- Função para criar mensagem de dano bônus como se fosse um segundo ataque
function createBonusDamageMessage(targetName, bonusDamage, bonusValue)
  if not gemBonusTracker.clientVisualsEnabled then
    return
  end
  -- Criar mensagem de dano bônus SEPARADO como segundo hit (igual na imagem)
  local bonusMessage = string.format("💎 %s loses %d hitpoints due to gem bonus! (ATK +%d)", 
    targetName, bonusDamage, bonusValue)
  
  -- Mostrar como mensagem de dano separada com delay
  if g_game and g_game.processTextMessage then
    -- Mode 17 para dano secundário (cor diferente do dano normal)
    g_game.processTextMessage(17, bonusMessage)
    
    -- Mostrar também como segundo hit visível
    scheduleEvent(function()
      local secondHitMsg = string.format("A %s loses %d hitpoints due to gem magic.", targetName, bonusDamage)
      g_game.processTextMessage(16, secondHitMsg) -- Same mode as normal damage but delayed
    end, 200)
  end
  
  -- Log para debug
  g_logger.info("💎 DUAL HIT - First: Original damage, Second: +" .. bonusDamage .. " gem bonus")
end

-- Função para mostrar o dano bônus como texto separado na tela
function showBonusDamageText(bonusDamage, bonusValue)
  if not gemBonusTracker.clientVisualsEnabled then
    return
  end
  -- 1. Mostrar dano bônus no console como mensagem separada
  local bonusMessage = string.format("💎 +%d gem bonus damage!", bonusDamage)
  
  -- 2. Usar o sistema de display de mensagens para mostrar na tela
  if modules.game_textmessage and modules.game_textmessage.displayMessage then
    -- Mode 20 para mensagem de experiência/bônus (cor verde)
    modules.game_textmessage.displayMessage(20, bonusMessage)
  end
  
  g_logger.info("💎💎 Bonus damage displayed: +" .. bonusDamage .. " (ATK +" .. bonusValue .. ")")
end

function showGemBonusEffect(damageValue, bonusValue)
  if not gemBonusTracker.clientVisualsEnabled then
    return
  end
  -- 1. Calcular dano bônus
  local bonusDamage = math.floor(damageValue * (bonusValue / 100))
  
  -- 2. Mostrar dano bônus como texto separado (simulando segundo hit)
  scheduleEvent(function()
    showBonusDamageText(bonusDamage, bonusValue)
  end, 300) -- Delay para aparecer após o dano principal
  
  -- 3. Efeito visual na tela (opcional, menor)
  local effectWidget = g_ui.createWidget('UIWidget')
  effectWidget:setSize({width = 200, height = 60})
  effectWidget:setPosition({x = 400, y = 200})
  effectWidget:setBackgroundColor('#1a0d4d')
  effectWidget:setBorderWidth(2)
  effectWidget:setBorderColor('#ffd700')
  effectWidget:setOpacity(0.9)
  
  g_logger.info("🔥 GEM BONUS ACTIVATED - Base: " .. damageValue .. ", Bonus: +" .. bonusDamage)
  
  -- Efeito simples de notificação
  local effectText = g_ui.createWidget('Label', effectWidget)
  effectText:setText('💎 GEM BONUS! 💎')
  effectText:setPosition({x = 10, y = 8})
  effectText:setFont('verdana-11px-rounded')
  effectText:setColor('#ffd700')
  effectText:setSize({width = 180, height = 20})
  effectText:setTextAlign(AlignCenter)
  
  local bonusDamage = math.floor(damageValue * (bonusValue / 100))
  local bonusText = g_ui.createWidget('Label', effectWidget)
  bonusText:setText('+' .. bonusDamage .. ' bonus damage!')
  bonusText:setPosition({x = 10, y = 30})
  bonusText:setFont('verdana-11px-antialised')
  bonusText:setColor('#00ff88')
  bonusText:setSize({width = 180, height = 16})
  bonusText:setTextAlign(AlignCenter)
  
  -- Animação de entrada mais dramática
  effectWidget:setOpacity(0)
  effectWidget:setSize({width = 50, height = 20})
  effectWidget:setPosition({x = 450, y = 180}) -- Começa mais à direita
  
  -- Animar entrada com bounce effect
  local steps = 12
  local currentStep = 0
  local animateIn
  animateIn = function()
    currentStep = currentStep + 1
    local progress = currentStep / steps
    
    -- Efeito bounce usando função quadrática
    local bounce = progress < 0.7 and progress or 0.7 + (math.sin((progress - 0.7) * 10) * 0.1)
    
    effectWidget:setOpacity(bounce * 0.95)
    effectWidget:setSize({
      width = 50 + (200 * bounce),
      height = 20 + (60 * bounce)
    })
    
    -- Mover para posição final
    effectWidget:setPosition({
      x = 450 - (100 * progress),
      y = 180 - (30 * progress)
    })
    
    -- Efeito pulsante na borda
    local pulseColor = currentStep % 2 == 0 and '#ffdd00' or '#ffffff'
    effectWidget:setBorderColor(pulseColor)
    
    if currentStep < steps then
      scheduleEvent(animateIn, 60)
    else
      -- Manter visível por 2.5 segundos e depois animar saída
      scheduleEvent(function()
        animateGemEffectExit(effectWidget)
      end, 2500)
    end
  end
  
  animateIn()
  
  -- Efeitos especiais por tipo de gema
  createGemBonusParticles(effectWidget, 'atk')
  
  -- Efeito sonoro simulado (mensagem) com mais destaque
  modules.game_textmessage.displayGameMessage('� CRÍTICO! Gema de Ataque ativou bônus de +' .. bonusValue .. ' ATK!', 'Gem Power')
  
  -- Log para debug
  g_logger.info("🔥 GEM BONUS ACTIVATED - Damage: " .. damageValue .. ", Bonus: +" .. bonusValue)
end

-- Criar efeitos de partículas para diferentes tipos de gemas
function createGemBonusParticles(parentWidget, gemType)
  -- Configurações por tipo de gema
  local particleConfigs = {
    atk = {color = '#ff4444', icon = '⚔️', count = 8},
    def = {color = '#4444ff', icon = '🛡️', count = 6},
    speed = {color = '#ff44ff', icon = '⚡', count = 10},
    manaregen = {color = '#44ff44', icon = '💙', count = 7},
    healthregen = {color = '#ffaa44', icon = '❤️', count = 7}
  }
  
  local config = particleConfigs[gemType] or particleConfigs.atk
  
  -- Criar múltiplas partículas
  for i = 1, config.count do
    scheduleEvent(function()
      createSingleParticle(parentWidget, config.color, config.icon, i)
    end, i * 100) -- Espalhar ao longo do tempo
  end
end

-- Criar uma única partícula animada
function createSingleParticle(parentWidget, color, icon, index)
  if not parentWidget then return end
  
  local particle = g_ui.createWidget('Label', parentWidget:getParent())
  particle:setText(icon)
  particle:setFont('verdana-11px-rounded')
  particle:setColor(color)
  particle:setSize({width = 20, height = 20})
  
  -- Posição inicial (ao redor do widget pai)
  local parentPos = parentWidget:getPosition()
  local angle = (index / 8) * (2 * math.pi) -- Distribuir em círculo
  local radius = 30
  
  local startX = parentPos.x + 125 + (math.cos(angle) * radius)
  local startY = parentPos.y + 40 + (math.sin(angle) * radius)
  
  particle:setPosition({x = startX, y = startY})
  particle:setOpacity(1.0)
  
  -- Animação da partícula
  local steps = 20
  local currentStep = 0
  local animateParticle
  animateParticle = function()
    currentStep = currentStep + 1
    local progress = currentStep / steps
    
    -- Movimento em espiral para fora
    local newRadius = radius + (progress * 60)
    local newX = parentPos.x + 125 + (math.cos(angle + progress * 2) * newRadius)
    local newY = parentPos.y + 40 + (math.sin(angle + progress * 2) * newRadius)
    
    particle:setPosition({x = newX, y = newY})
    particle:setOpacity(1 - progress)
    
    if currentStep < steps then
      scheduleEvent(animateParticle, 50)
    else
      particle:destroy()
    end
  end
  
  animateParticle()
end

-- Animar saída do efeito
function animateGemEffectExit(widget)
  if not widget then return end
  
  local steps = 10
  local currentStep = 0
  local animateOut
  animateOut = function()
    currentStep = currentStep + 1
    local progress = 1 - (currentStep / steps)
    
    widget:setOpacity(progress * 0.95)
    widget:setSize({
      width = 250 * progress,
      height = 80 * progress
    })
    
    -- Fade para cima
    local currentPos = widget:getPosition()
    widget:setPosition({
      x = currentPos.x,
      y = currentPos.y - (currentStep * 3)
    })
    
    if currentStep < steps then
      scheduleEvent(animateOut, 80)
    else
      widget:destroy()
    end
  end
  
  animateOut()
end

-- Função para testar efeitos de gemas (debug)
function testGemEffect(gemType, damageValue, bonusValue)
  gemType = gemType or 'atk'
  damageValue = damageValue or 75
  bonusValue = bonusValue or 5
  
  g_logger.info("Testing gem effect - Type: " .. gemType .. ", Damage: " .. damageValue .. ", Bonus: " .. bonusValue)
  showGemBonusEffect(damageValue, bonusValue)
  
  modules.game_textmessage.displayGameMessage('🧪 Teste de efeito de gema executado!', 'Gem Debug')
end

-- Função para simular dano para teste
function simulateDamageForTest(damageValue)
  damageValue = damageValue or 65
  processMessageForGemBonus(16, "A dragon loses " .. damageValue .. " hitpoints due to your attack.")
end

-- Carregar gemas equipadas salvas localmente
function loadLocalEquippedGems(content, rankId)
  if not localEquippedGems[rankId] then return end
  
  g_logger.info("Loading locally saved gems for rank: " .. rankId)
  
  for slotNumber, gemData in pairs(localEquippedGems[rankId]) do
    local slot = content:recursiveGetChildById('gemSlot' .. slotNumber)
    if slot and gemData then
      g_logger.info("Restoring gem in slot " .. slotNumber .. ": " .. gemData.name)
      
      -- Restaurar imagem
      local imagePath = string.format('/images/items/%d.png', gemData.itemId)
      if g_resources.fileExists(imagePath) then
        slot:setImageSource(imagePath)
      else
        slot:setItemId(gemData.itemId)
      end
      
      slot:setImageColor('#ffffff')
      slot:setOpacity(1.0)
      
      -- Restaurar dados da gema no slot
      slot.equippedGem = {
        itemId = gemData.itemId,
        name = gemData.name,
        bonus = gemData.bonus,
        value = gemData.value,
        color = gemData.color
      }
      
      -- Restaurar tooltip
      slot:setTooltip(gemData.name .. '\n+' .. gemData.value .. ' ' .. gemData.bonus .. '\nClique direito para remover')
    end
  end
  
  -- Atualizar efeitos após carregar todas as gemas
  scheduleEvent(function()
    updateRankGemsEffects()
  end, 100)
end

-- Função para alternar modo de teste
function toggleTestMode(enabled)
  if enabled == nil then
    enabled = not gemBonusTracker.testMode
  end
  
  gemBonusTracker.testMode = enabled
  
  local status = enabled and "ativado" or "desativado"
  g_logger.info("Modo de teste de gemas " .. status)
  modules.game_textmessage.displayGameMessage("Modo teste: " .. status .. " (chance aumentada de ativação)", 'Gem System')
  
  return enabled
end

-- Sistema de monitoramento de mensagens de dano
local originalOnGameMessage
function setupGemDamageMonitoring()
  -- Tentar interceptar mensagens de jogo para detectar dano
  if modules.game_textmessage and modules.game_textmessage.onGameMessage then
    originalOnGameMessage = modules.game_textmessage.onGameMessage
    
    modules.game_textmessage.onGameMessage = function(mode, text)
      -- Chamar função original primeiro
      if originalOnGameMessage then
        originalOnGameMessage(mode, text)
      end
      
      -- Processar mensagem para detectar dano
      processMessageForGemBonus(mode, text)
    end
    
    g_logger.info("Gem damage monitoring system activated via game_textmessage")
  else
    g_logger.warning("Could not hook game_textmessage, trying alternative methods")
    
    -- Método alternativo: interceptar g_logger diretamente se possível
    if g_logger and g_logger.info then
      local originalLogInfo = g_logger.info
      g_logger.info = function(message)
        originalLogInfo(message)
        
        -- Verificar se é uma mensagem de debug de dano
        if message and message:find("DEBUG displayMessage") and message:find("Mode: 16") then
          local text = message:match("Text: (.+)")
          if text then
            g_logger.info("🔄 Intercepted DEBUG message, processing: " .. text)
            processMessageForGemBonus(16, text)
          end
        end
        
        -- Interceptar mensagens diretas de dano detectado
        if message and message:find("🎯 DAMAGE DETECTED:") then
          local damageMatch = message:match("🎯 DAMAGE DETECTED: (%d+)")
          if damageMatch then
            local damage = tonumber(damageMatch)
            g_logger.info("🔄 Re-processing detected damage: " .. damage)
            
            local attackBonus = getCurrentAttackBonus()
            if attackBonus > 0 then
              local isBonusActivated = analyzeDamageForGemBonus(damage)
              if isBonusActivated then
                local bonusDamage = math.floor(damage * (attackBonus / 100))
                scheduleEvent(function()
                  createBonusDamageMessage("target", bonusDamage, attackBonus)
                end, 200)
                showGemBonusEffect(damage, attackBonus)
              end
            end
          end
        end
      end
      -- g_logger.info("Gem monitoring activated via logger intercept")
    else
      g_logger.warning("No suitable method found for gem damage monitoring")
      
      -- Último recurso: polling manual
      scheduleEvent(function()
        monitorDamageManually()
      end, 1000)
    end
  end
end

-- Monitoramento manual como fallback
function monitorDamageManually()
  if not gemBonusTracker.enabled then
    scheduleEvent(function() monitorDamageManually() end, 1000)
    return
  end
  
  -- Este é um fallback - vamos criar uma função que pode ser chamada manualmente
  -- ou usar o sistema de detecção através de outros eventos
  
  scheduleEvent(function() monitorDamageManually() end, 1000)
end

-- Processar mensagens para detectar dano e ativar efeitos de gema
function processMessageForGemBonus(mode, text)
  -- Mode 16 é tipicamente mensagens de dano
  if mode ~= 16 and not text then return end

  if not gemBonusTracker.enabled or not gemBonusTracker.clientVisualsEnabled then
    return
  end
  
  -- Padrões de mensagem de dano em português e inglês
  local damagePatterns = {
    "loses (%d+) hitpoints due to your attack",  -- Inglês
    "perde (%d+) pontos de vida devido ao seu ataque",  -- Português
    "recebe (%d+) de dano do seu ataque"  -- Alternativo português
  }
  
  local damageValue = nil
  local targetName = nil
  
  -- Tentar extrair valor do dano e nome do alvo
  for _, pattern in ipairs(damagePatterns) do
    local match = text:match(pattern)
    if match then
      damageValue = tonumber(match)
      -- Extrair nome do alvo (parte antes de "loses")
      targetName = text:match("A?n? ?(.+) loses %d+ hitpoints") or "target"
      break
    end
  end
  
  if damageValue then
    g_logger.info("🎯 DAMAGE DETECTED: " .. damageValue .. " from text: " .. text)
    
    -- Verificar se o sistema de gemas está ativo
    local attackBonus = getCurrentAttackBonus()
    g_logger.info("🔧 DEBUG - Attack bonus: " .. attackBonus .. ", Gem tracker enabled: " .. tostring(gemBonusTracker.enabled))
    
    if attackBonus > 0 then
      -- Analisar se foi influenciado por bônus de gema
      g_logger.info("💎 Analyzing damage for gem bonus...")
      local isBonusActivated = analyzeDamageForGemBonus(damageValue)
      g_logger.info("🔍 Bonus activation result: " .. tostring(isBonusActivated))
      
      if isBonusActivated then
        -- Use the new dual hit system for better visual effect
        g_logger.info("💥 ACTIVATING DUAL HIT SYSTEM")
        processDualHitDamage(damageValue, targetName)
        
        -- Keep the original effect as backup
        showGemBonusEffect(damageValue, attackBonus)
      else
        g_logger.info("❌ Gem bonus not activated for damage: " .. damageValue)
      end
    else
      g_logger.info("⚠️ No attack bonus found or gem tracker disabled")
    end
  else
    -- Debug: mostrar texto não reconhecido
    if gemBonusTracker.testMode then
      g_logger.info("No damage pattern found in: " .. text)
    end
  end
end

-- Função pública para processar dano manualmente (para testes ou integração)
function processDamageManually(damageText)
  g_logger.info("Manual damage processing: " .. damageText)
  processMessageForGemBonus(16, damageText)
end

-- Simular dano baseado nos logs que você vê (para teste)
function simulateDamageFromLogs()
  local damages = {67, 67, 14, 69, 60, 71, 65, 57, 56, 68, 57, 72, 61, 62, 59, 54, 63}
  
  g_logger.info("💫 Simulating damage from your actual logs...")
  
  for i, dmg in ipairs(damages) do
    scheduleEvent(function()
      g_logger.info(string.format("🎯 Processing damage #%d: %d", i, dmg))
      
      -- Analisar se foi influenciado por bônus de gema
      local isBonusActivated = analyzeDamageForGemBonus(dmg)
      
      if isBonusActivated then
        local attackBonus = getCurrentAttackBonus()
        if attackBonus > 0 then
          showGemBonusEffect(dmg, attackBonus)
        end
      end
    end, i * 500) -- 500ms entre cada dano para ver o efeito
  end
end

-- Função para forçar ativação do bônus (para teste)
function testGemBonusEffect()
  local attackBonus = getCurrentAttackBonus()
  if attackBonus > 0 then
    g_logger.info("💎 Testing gem bonus effect with current ATK bonus: +" .. attackBonus)
    showGemBonusEffect(65, attackBonus)
    
    -- Testar também a mensagem de dano bônus
    scheduleEvent(function()
      createBonusDamageMessage("hydra", math.floor(65 * (attackBonus / 100)), attackBonus)
    end, 500)
  else
    g_logger.warning("No attack bonus found! Make sure you have a gem equipped.")
  end
end

-- Função para testar diferentes cores de mensagem
function testMessageColors()
  g_logger.info("🎨 Testing different message colors...")
  
  local modes = {16, 17, 18, 19, 20, 21, 22}
  local colors = {"Normal", "Orange", "Red/Critical", "White", "Green", "Blue", "Yellow"}
  
  for i, mode in ipairs(modes) do
    scheduleEvent(function()
      local testMessage = string.format("Mode %d: %s - Test damage message", mode, colors[i] or "Unknown")
      if g_game and g_game.processTextMessage then
        g_game.processTextMessage(mode, testMessage)
      end
      g_logger.info("Sent message mode " .. mode .. ": " .. testMessage)
    end, i * 1000)
  end
end

-- Função para testar o sistema completo com mensagens reais
function testRealDamageMessage()
  g_logger.info("🧪 Testing real damage message processing...")
  
  -- Simular uma mensagem real como a que aparece nos logs
  local testMessage = "A dragon loses 60 hitpoints due to your attack."
  g_logger.info("📤 Processing test message: " .. testMessage)
  
  -- Chamar diretamente a função de processamento
  processMessageForGemBonus(16, testMessage)
end

-- Função para testar sincronização com servidor
function testGemSync()
  g_logger.info("🔄 Testing gem synchronization with server...")
  
  local attackBonus = getCurrentAttackBonus()
  if attackBonus > 0 then
    syncGemsWithServer(1) -- Sync rank 1
    g_logger.info("✅ Sync sent to server! ATK Bonus: +" .. attackBonus)
  else
    g_logger.warning("❌ No gems equipped to sync!")
    -- Debug: mostrar conteúdo das gemas locais
    debugGemSystem()
  end
end

-- Função de debug para verificar estado da conexão
function debugConnectionStatus()
  g_logger.info("🔍 Debug - Connection Status Check:")
  g_logger.info("  - g_game.isOnline(): " .. tostring(g_game.isOnline()))
  g_logger.info("  - g_game.sendExtendedOpcode available: " .. tostring(g_game.sendExtendedOpcode ~= nil))
  
  if g_game.getLocalPlayer then
    local localPlayer = g_game.getLocalPlayer()
    g_logger.info("  - Local player exists: " .. tostring(localPlayer ~= nil))
    if localPlayer then
      g_logger.info("  - Player name: " .. (localPlayer:getName() or "no name"))
    end
  end
  
  if g_game.getProtocolVersion then
    g_logger.info("  - Protocol version: " .. tostring(g_game.getProtocolVersion()))
  end
end

-- Função para verificar se o servidor recebeu as gemas
function checkServerGemStatus()
  g_logger.info("🔍 Checking server gem status...")
  
  debugConnectionStatus()
  
  if g_game.isOnline() and g_game.sendExtendedOpcode then
    local data = {action = "getGemStatus"}
    g_game.sendExtendedOpcode(ExtendedIds.ConjurerDataRequest, json.encode(data))
    g_logger.info("📤 Requested gem status from server")
  else
    g_logger.info("🔧 Testing mode: server status check not available (using local data)")
    -- Mostrar status local das gemas
    local totalGems = 0
    for rank, gems in pairs(localEquippedGems) do
      for slot, gem in pairs(gems) do
        totalGems = totalGems + 1
      end
    end
    g_logger.info("📊 Local gems count: " .. totalGems)
  end
end

-- Função de teste completo do sistema
function testCompleteGemSystem()
  g_logger.info("🧪 COMPLETE GEM SYSTEM TEST")
  g_logger.info("========================================")
  
  -- 1. Verificar gemas locais
  debugGemSystem()
  
  -- 2. Sincronizar com servidor
  scheduleEvent(function()
    testGemSync()
  end, 1000)
  
  -- 3. Verificar status do servidor
  scheduleEvent(function()
    checkServerGemStatus()
  end, 2000)
  
  -- 4. Testar efeito visual
  scheduleEvent(function()
    testGemBonusEffect()
  end, 3000)
  
  g_logger.info("✅ Complete test sequence initiated!")
  g_logger.info("📋 Expected behavior:")
  g_logger.info("  - Gem should be synced to server")
  g_logger.info("  - When attacking monsters, you should see:")
  g_logger.info("    • Normal damage (white)")
  g_logger.info("    • 💎+X bonus damage (blue)")
  g_logger.info("    • Magic effect on monster")
  g_logger.info("    • Console message about gem power")
end

-- Função para forçar teste de comunicação com servidor
function forceServerCommunicationTest()
  g_logger.info("🧪 Force testing server communication...")
  
  debugConnectionStatus()
  
  -- Tentar enviar um ping simples
  local testData = {
    action = "ping",
    timestamp = os.time(),
    message = "test communication"
  }
  
  local jsonData = json.encode(testData)
  g_logger.info("📤 Sending test ping to server...")
  
  -- Usar o mesmo método que funciona para o ranking
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    g_logger.info("📤 Sending ping via protocolGame")
    local success, error = pcall(function()
      protocolGame:sendExtendedOpcode(ExtendedIds.ConjurerGemSync, jsonData)
    end)
    
    if success then
      g_logger.info("✅ Test ping sent successfully via protocolGame - check server console!")
    else
      g_logger.error("❌ Failed to send ping via protocolGame: " .. tostring(error))
    end
  elseif g_game and g_game.sendExtendedOpcode then
    g_logger.info("📤 Sending ping via g_game")
    local success, error = pcall(function()
      g_game.sendExtendedOpcode(ExtendedIds.ConjurerGemSync, jsonData)
    end)
    
    if success then
      g_logger.info("✅ Test ping sent successfully via g_game - check server console!")
    else
      g_logger.error("❌ Failed to send ping via g_game: " .. tostring(error))
    end
  else
    g_logger.error("❌ No method available to send test ping!")
  end
  
  -- Verificar se há gemas equipadas para sincronizar
  local gemsEquipped = 0
  for rank, gems in pairs(localEquippedGems) do
    for slot, gem in pairs(gems) do
      gemsEquipped = gemsEquipped + 1
    end
  end
  
  if gemsEquipped > 0 then
    g_logger.info("💎 Found " .. gemsEquipped .. " equipped gems - attempting force sync...")
    syncGemsWithServer(1) -- Force sync rank 1
  else
    g_logger.info("💎 No gems equipped to sync")
  end
end

-- Função de teste completo do sistema
function testCompleteGemSystem()
  g_logger.info("🧪 COMPLETE GEM SYSTEM TEST")
  g_logger.info("========================================")
  
  -- 1. Verificar gemas locais
  debugGemSystem()
  
  -- 2. Sincronizar com servidor
  scheduleEvent(function()
    testGemSync()
  end, 1000)
  
  -- 3. Verificar status do servidor
  scheduleEvent(function()
    checkServerGemStatus()
  end, 2000)
  
  -- 4. Testar efeito visual
  scheduleEvent(function()
    testGemBonusEffect()
  end, 3000)
  
  g_logger.info("✅ Complete test sequence initiated!")
end

-- Função para debug completo do sistema
function debugGemSystem()
  g_logger.info("🔍 DEBUGGING GEM SYSTEM")
  g_logger.info("- Gem tracker enabled: " .. tostring(gemBonusTracker.enabled))
  g_logger.info("- Test mode: " .. tostring(gemBonusTracker.testMode))
  
  -- Debug das gemas salvas localmente
  g_logger.info("📦 LOCAL EQUIPPED GEMS:")
  for rank, gems in pairs(localEquippedGems) do
    g_logger.info("  Rank " .. rank .. ":")
    for slot, gemData in pairs(gems) do
      g_logger.info(string.format("    Slot %d: %s (bonus: %s, value: %d)", 
        slot, gemData.name or "Unknown", gemData.bonus or "none", gemData.value or 0))
    end
  end
  
  g_logger.info("- Current ATK bonus: " .. getCurrentAttackBonus())
  g_logger.info("- Damage history count: " .. #gemBonusTracker.damageHistory)
  
  -- Testar com um valor real
  g_logger.info("📊 Testing damage analysis with 60 damage:")
  local result = analyzeDamageForGemBonus(60)
  g_logger.info("- Analysis result: " .. tostring(result))
end

-- Sincronizar gemas equipadas com o servidor para bônus real
function syncGemsWithServer(rankId)
  if not localEquippedGems[rankId] then 
    g_logger.warning("No gems to sync for rank " .. rankId)
    return 
  end
  
  -- Preparar dados das gemas para envio
  local equippedGemsData = {
    rank = rankId,
    gems = {}
  }
  
  for slotNumber, gemData in pairs(localEquippedGems[rankId]) do
    -- Garantir que slotNumber seja número
    local slot = tonumber(slotNumber)
    if slot then
      table.insert(equippedGemsData.gems, {
        slot = slot,
        itemId = gemData.itemId,
        bonus = gemData.bonus,
        value = gemData.value
      })
      g_logger.info("📦 Prepared gem for sync: slot=" .. slot .. ", itemId=" .. gemData.itemId .. ", bonus=" .. gemData.bonus)
    else
      g_logger.warning("⚠️ Invalid slot number: " .. tostring(slotNumber))
    end
  end
  
  -- Tentar enviar para servidor via opcode ConjurerGemSync (usando mesmo método do ranking)
  local data = {
    action = "syncEquippedGems",
    data = equippedGemsData
  }
  
  local jsonData = json.encode(data)
  g_logger.info("🔄 Attempting to sync gems with server...")
  
  -- Usar o mesmo método que funciona para o ranking
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    g_logger.info("📤 Sending ConjurerGemSync opcode via protocolGame")
    local success, error = pcall(function()
      protocolGame:sendExtendedOpcode(ExtendedIds.ConjurerGemSync, jsonData)
    end)
    
    if success then
      g_logger.info("✅ Gems sync sent successfully via protocolGame for rank " .. rankId .. " (" .. #equippedGemsData.gems .. " gems)")
    else
      g_logger.error("❌ Failed to send via protocolGame: " .. tostring(error))
    end
  elseif g_game and g_game.sendExtendedOpcode then
    g_logger.info("� Sending ConjurerGemSync opcode via g_game")
    local success, error = pcall(function()
      g_game.sendExtendedOpcode(ExtendedIds.ConjurerGemSync, jsonData)
    end)
    
    if success then
      g_logger.info("✅ Gems sync sent successfully via g_game for rank " .. rankId .. " (" .. #equippedGemsData.gems .. " gems)")
    else
      g_logger.error("❌ Failed to send via g_game: " .. tostring(error))
    end
  else
    g_logger.error("❌ No method available to send gem sync - both protocolGame and g_game.sendExtendedOpcode unavailable")
  end
end

-- Função para remover gemas do servidor
function removeGemFromServer(rankId, slotNumber)
  local data = {
    action = "removeGem",
    data = {
      rank = rankId,
      slot = slotNumber
    }
  }
  
  local jsonData = json.encode(data)
  g_logger.info("🗑️ Attempting to remove gem from server...")
  
  -- Usar o mesmo método que funciona para o ranking
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    g_logger.info("📤 Sending gem removal via protocolGame")
    local success, error = pcall(function()
      protocolGame:sendExtendedOpcode(ExtendedIds.ConjurerGemSync, jsonData)
    end)
    
    if success then
      g_logger.info("✅ Gem removal sent successfully - Rank: " .. rankId .. ", Slot: " .. slotNumber)
    else
      g_logger.error("❌ Failed to send gem removal via protocolGame: " .. tostring(error))
    end
  elseif g_game and g_game.sendExtendedOpcode then
    g_logger.info("📤 Sending gem removal via g_game")
    local success, error = pcall(function()
      g_game.sendExtendedOpcode(ExtendedIds.ConjurerGemSync, jsonData)
    end)
    
    if success then
      g_logger.info("✅ Gem removal sent successfully - Rank: " .. rankId .. ", Slot: " .. slotNumber)
    else
      g_logger.error("❌ Failed to send gem removal via g_game: " .. tostring(error))
    end
  else
    g_logger.error("❌ No method available to send gem removal")
  end
end

-- Função simples para ativar bônus manualmente com base no último dano
function activateBonusForLastDamage()
  -- Pegar os últimos valores de dano dos logs
  local recentDamages = {63, 52, 53, 65, 64, 61, 58} -- Baseado nos seus logs
  
  for i, damage in ipairs(recentDamages) do
    scheduleEvent(function()
      g_logger.info("💥 PROCESSING MANUAL DAMAGE: " .. damage)
      
      local attackBonus = getCurrentAttackBonus()
      if attackBonus > 0 then
        local bonusDamage = math.floor(damage * (attackBonus / 100))
        
        g_logger.info("💎 Creating bonus damage message...")
        createBonusDamageMessage("dragon", bonusDamage, attackBonus)
        
        g_logger.info("✨ Showing visual effect...")
        showGemBonusEffect(damage, attackBonus)
      else
        g_logger.warning("No ATK bonus found!")
      end
    end, i * 800) -- 800ms between each
  end
end

-- Função para ativar/desativar monitoramento de bônus
function toggleGemBonusMonitoring(enabled)
  if enabled == nil then
    enabled = not gemBonusTracker.enabled
  end
  
  gemBonusTracker.enabled = enabled
  gemBonusTracker.clientVisualsEnabled = enabled
  dualHitTracker.enabled = enabled
  
  local status = enabled and "ativado" or "desativado"
  g_logger.info("Monitoramento de bônus de gemas " .. status)
  modules.game_textmessage.displayGameMessage("Monitoramento de gemas: " .. status, 'Gem System')
  
  return enabled
end

-- Função para ajustar faixa de dano base
function calibrateBaseDamage(minDamage, maxDamage)
  gemBonusTracker.baseDamageRange.min = minDamage
  gemBonusTracker.baseDamageRange.max = maxDamage
  
  g_logger.info("Base damage range calibrated: " .. minDamage .. "-" .. maxDamage)
  modules.game_textmessage.displayGameMessage("Dano base calibrado: " .. minDamage .. "-" .. maxDamage, 'Gem System')
end

-- Mostrar histórico detalhado de danos
function showDamageHistory()
  if #gemBonusTracker.damageHistory == 0 then
    modules.game_textmessage.displayGameMessage("Nenhum histórico de dano disponível", 'Gem System')
    return
  end
  
  -- Criar janela de histórico
  local historyWindow = g_ui.createWidget('MainWindow')
  historyWindow:setId('damageHistoryWindow')
  historyWindow:setText('Histórico de Danos - Análise de Gemas')
  historyWindow:setSize({width = 500, height = 400})
  historyWindow:center()
  
  -- Área de texto scrollable
  local textArea = g_ui.createWidget('TextEdit', historyWindow)
  textArea:setPosition({x = 10, y = 30})
  textArea:setSize({width = 480, height = 320})
  textArea:setFont('verdana-11px-rounded')
  textArea:setReadOnly(true)
  
  -- Construir texto do histórico
  local historyText = "📊 HISTÓRICO DE DANOS (Últimos " .. #gemBonusTracker.damageHistory .. " ataques)\n\n"
  
  -- Estatísticas gerais
  local totalDamage = 0
  local withBonusDamage = 0
  local withBonusCount = 0
  
  for i, record in ipairs(gemBonusTracker.damageHistory) do
    totalDamage = totalDamage + record.damage
    if record.bonus > 0 then
      withBonusDamage = withBonusDamage + record.damage
      withBonusCount = withBonusCount + 1
    end
  end
  
  local avgDamage = totalDamage / #gemBonusTracker.damageHistory
  local avgBonusDamage = withBonusCount > 0 and (withBonusDamage / withBonusCount) or 0
  
  historyText = historyText .. string.format("📈 ESTATÍSTICAS:\n")
  historyText = historyText .. string.format("• Dano médio geral: %.1f\n", avgDamage)
  historyText = historyText .. string.format("• Dano médio com bônus: %.1f\n", avgBonusDamage)
  historyText = historyText .. string.format("• Ataques com bônus: %d/%d (%.1f%%)\n\n", 
    withBonusCount, #gemBonusTracker.damageHistory, (withBonusCount/#gemBonusTracker.damageHistory)*100)
  
  -- Lista detalhada (últimos 10 ataques)
  historyText = historyText .. "🎯 ÚLTIMOS ATAQUES:\n"
  
  local startIndex = math.max(1, #gemBonusTracker.damageHistory - 9)
  for i = startIndex, #gemBonusTracker.damageHistory do
    local record = gemBonusTracker.damageHistory[i]
    local timeStr = os.date("%H:%M:%S", record.time)
    local bonusStr = record.bonus > 0 and (" 💎+" .. record.bonus) or ""
    
    historyText = historyText .. string.format("%d. [%s] %d dmg%s\n", 
      i, timeStr, record.damage, bonusStr)
  end
  
  -- Análise de padrões
  historyText = historyText .. "\n🔍 ANÁLISE:\n"
  historyText = historyText .. string.format("• Faixa base configurada: %d-%d\n", 
    gemBonusTracker.baseDamageRange.min, gemBonusTracker.baseDamageRange.max)
  
  local currentBonus = getCurrentAttackBonus()
  if currentBonus > 0 then
    historyText = historyText .. string.format("• Bônus atual: +%d ATK\n", currentBonus)
    historyText = historyText .. string.format("• Dano esperado: %d-%d\n", 
      gemBonusTracker.baseDamageRange.min + currentBonus,
      gemBonusTracker.baseDamageRange.max + currentBonus)
  else
    historyText = historyText .. "• Nenhuma gema de ataque equipada\n"
  end
  
  textArea:setText(historyText)
  
  -- Botão fechar
  local closeButton = g_ui.createWidget('Button', historyWindow)
  closeButton:setText('Fechar')
  closeButton:setPosition({x = 210, y = 360})
  closeButton:setSize({width = 80, height = 25})
  closeButton.onClick = function()
    historyWindow:destroy()
  end
  
  historyWindow:show()
  historyWindow:raise()
  historyWindow:focus()
end

-- Create a real-time gem effects monitor
function createGemEffectsMonitor()
  -- Remove existing monitor
  local existingMonitor = g_ui.getRootWidget():recursiveGetChildById('gemEffectsMonitor')
  if existingMonitor then
    existingMonitor:destroy()
  end
  
  -- Create new monitor widget
  local monitor = g_ui.createWidget('UIWidget')
  monitor:setId('gemEffectsMonitor')
  monitor:setSize({width = 200, height = 100})
  monitor:setPosition({x = 10, y = 100})
  monitor:setBackgroundColor('#000000')
  monitor:setBorderWidth(1)
  monitor:setBorderColor('#ffaa00')
  monitor:setOpacity(0.8)
  
  local title = g_ui.createWidget('Label', monitor)
  title:setText('Gem Effects Monitor')
  title:setPosition({x = 5, y = 5})
  title:setFont('verdana-11px-rounded')
  title:setColor('#ffaa00')
  
  local content = g_ui.createWidget('Label', monitor)
  content:setId('monitorContent')
  content:setPosition({x = 5, y = 25})
  content:setSize({width = 190, height = 70})
  content:setFont('verdana-11px-rounded')
  content:setColor('#ffffff')
  content:setTextWrap(true)
  
  -- Update function
  local function updateMonitor()
    local activeGems, totalBonuses = debugGemBonuses()
    
    if not totalBonuses or next(totalBonuses) == nil then
      content:setText('No active gems')
      return
    end
    
    local text = ""
    for bonusType, value in pairs(totalBonuses) do
      text = text .. bonusType:upper() .. ": +" .. value .. "\n"
    end
    
    content:setText(text)
  end
  
  -- Update every 2 seconds
  monitor.updateEvent = scheduleEvent(function()
    updateMonitor()
    monitor.updateEvent = scheduleEvent(monitor.updateEvent, 2000)
  end, 1000)
  
  -- Click to toggle visibility
  monitor.onClick = function()
    if monitor:getOpacity() < 0.5 then
      monitor:setOpacity(0.8)
    else
      monitor:setOpacity(0.2)
    end
  end
  
  updateMonitor()
  return monitor
end

-- Handler for gem data from server
function onConjurerGemData(protocol, opcode, buffer)
  g_logger.info("Received ConjurerGemData opcode with buffer length: " .. buffer:len())
  
  if buffer == '' then return end
  
  local success, data = pcall(function() 
    return json.decode(buffer)
  end)
  
  if not success or not data then
    g_logger.error("Failed to decode ConjurerGemData JSON: " .. tostring(data))
    return
  end
  
  -- Verificar se é uma resposta de lista de gemas disponíveis (similar ao autoloot)
  if data.action == "gemList" and data.gems then
    g_logger.info("Received gems list from server with " .. #data.gems .. " gem types")
    -- Usar o rankId armazenado globalmente
    updateGemsPanel(data.gems, currentRankIdForGems)
    return
  end
  
  -- Verificar se são stats do servidor para comparação
  if data.action == "statsResponse" and data.stats then
    g_logger.info("=== SERVER STATS RESPONSE ===")
    g_logger.info("Server Attack: " .. (data.stats.attack or "N/A"))
    g_logger.info("Server Defense: " .. (data.stats.defense or "N/A"))
    g_logger.info("Server Speed: " .. (data.stats.speed or "N/A"))
    g_logger.info("Server Mana Regen: " .. (data.stats.manaregen or "N/A"))
    g_logger.info("Server Health Regen: " .. (data.stats.healthregen or "N/A"))
    
    -- Comparar com bônus esperados
    local activeGems, totalBonuses = debugGemBonuses()
    if totalBonuses then
      g_logger.info("--- COMPARISON ---")
      for bonusType, expectedValue in pairs(totalBonuses) do
        local serverValue = data.stats[bonusType] or 0
        g_logger.info(bonusType:upper() .. " - Expected: +" .. expectedValue .. ", Server: " .. serverValue)
      end
    end
    
    modules.game_textmessage.displayGameMessage("Stats do servidor recebidos! Veja console para detalhes.", 'Gem Debug')
    return
  end
  
  -- Atualizar dados das gemas equipadas
  if data.equippedGems then
    equippedGems = data.equippedGems
    g_logger.info("Updated equipped gems data")
  end
  
  if data.availableGems then
    availableGems = data.availableGems
    g_logger.info("Updated available gems data")
  end
  
  -- Se há um rank específico sendo mostrado, atualizar os slots
  local content = g_ui.getRootWidget():recursiveGetChildById('rankDetailsContent')
  if content then
    updateGemSlotsDisplay(content, data)
  end
end

-- Update gem slots display with server data
function updateGemSlotsDisplay(content, data)
  if not data.equippedGems then return end
  
  -- Mapeamento de itemId para dados da gema (IDs corretos)
  local gemsByItemId = {
    [5273] = {name = "Attack Gem", bonus = "atk", value = 5, color = "#ff4444"},
    [5274] = {name = "Defense Gem", bonus = "def", value = 5, color = "#4444ff"},
    [5275] = {name = "Mana Regen Gem", bonus = "manaregen", value = 2, color = "#44ff44"},
    [5276] = {name = "Health Regen Gem", bonus = "healthregen", value = 3, color = "#ffaa44"},
    [5277] = {name = "Speed Gem", bonus = "speed", value = 10, color = "#ff44ff"}
  }
  
  for i = 1, 3 do
    local slot = content:recursiveGetChildById('gemSlot' .. i)
    if slot then
      local equippedItemId = data.equippedGems[i]
      if equippedItemId and equippedItemId > 0 then
        -- Equipar gema baseada no itemId
        local gemData = gemsByItemId[equippedItemId]
        if gemData then
          -- Usar setImageSource para UIItem virtual
          local imagePath = string.format('/images/items/%d.png', equippedItemId)
          if g_resources.fileExists(imagePath) then
            slot:setImageSource(imagePath)
          else
            slot:setItemId(equippedItemId) -- Fallback
          end
          slot:setImageColor('#ffffff') -- Cor normal para gemas equipadas
          slot:setOpacity(1.0)
          slot.equippedGem = {
            itemId = equippedItemId,
            name = gemData.name,
            bonus = gemData.bonus,
            value = gemData.value,
            color = gemData.color
          }
          slot:setTooltip(gemData.name .. '\n+' .. gemData.value .. ' ' .. gemData.bonus .. '\nClique direito para remover')
        end
      else
        -- Slot vazio
        slot:setImageSource('/images/ui/item-blessed') -- Ícone padrão do slot
        slot:setImageColor('#aaaaaa') -- Cor padrão
        slot:setOpacity(0.5)
        slot.equippedGem = nil
        slot:setTooltip(tr('Arraste uma gema aqui ou clique direito para remover'))
      end
    end
  end
  
  -- Atualizar efeitos ativos
  updateRankGemsEffects()
  
  -- Atualizar gemas disponíveis no inventário
  setupAvailableGems(content)
end

-- Handle inventory changes to update available gems
function onInventoryChange(slot, item, oldItem)
  -- Check if the item is a gem (itemIds 2147-2152)
  local isGemItem = false
  
  -- Verificar se item é um objeto válido e não um número
  if item and type(item) == 'userdata' and item.getId then
    local itemId = item:getId()
    -- Verificar se é uma das gemas: 5273, 5274, 5275, 5276, 5277
    if itemId == 5273 or itemId == 5274 or itemId == 5275 or itemId == 5276 or itemId == 5277 then
      isGemItem = true
    end
  end
  
  -- Verificar se oldItem é um objeto válido e não um número
  if oldItem and type(oldItem) == 'userdata' and oldItem.getId then
    local oldItemId = oldItem:getId()
    if oldItemId >= 2147 and oldItemId <= 2152 then
      isGemItem = true
    end
  end
  
  if isGemItem then
    -- Update available gems panel if rank details window is open
    local content = g_ui.getRootWidget():recursiveGetChildById('rankDetailsContent')
    if content then
      setupAvailableGems(content)
    end
  end
end

-- Debug function to check active gem bonuses
function debugGemBonuses()
  -- g_logger.info("=== DEBUG: ACTIVE GEM BONUSES ===")
  
  local content = g_ui.getRootWidget():recursiveGetChildById('rankDetailsContent')
  if not content then
    g_logger.info("No rank details window open")
    return
  end
  
  local totalBonuses = {}
  local activeGems = {}
  
  -- Verificar gemas equipadas em cada slot
  for i = 1, 3 do
    local slot = content:recursiveGetChildById('gemSlot' .. i)
    if slot and slot.equippedGem then
      local gem = slot.equippedGem
      g_logger.info("Slot " .. i .. ": " .. gem.name .. " (+\"" .. gem.value .. " " .. gem.bonus .. ")")
      
      -- Acumular bônus por tipo
      if not totalBonuses[gem.bonus] then
        totalBonuses[gem.bonus] = 0
      end
      totalBonuses[gem.bonus] = totalBonuses[gem.bonus] + gem.value
      
      table.insert(activeGems, {
        slot = i,
        name = gem.name,
        bonus = gem.bonus,
        value = gem.value,
        itemId = gem.itemId
      })
    else
      g_logger.info("Slot " .. i .. ": Empty")
    end
  end
  
  -- Mostrar totais por tipo de bônus
  g_logger.info("--- TOTAL BONUSES ---")
  for bonusType, totalValue in pairs(totalBonuses) do
    g_logger.info(bonusType:upper() .. ": +" .. totalValue)
  end
  
  -- Mostrar mensagem no jogo
  if #activeGems > 0 then
    local message = "🔮 BÔNUS ATIVOS:\n"
    for bonusType, totalValue in pairs(totalBonuses) do
      message = message .. "▶ " .. bonusType:upper() .. ": +" .. totalValue .. "\n"
    end
    message = message .. "\n💎 Gemas equipadas: " .. #activeGems
    modules.game_textmessage.displayGameMessage(message, 'Gem Debug')
  else
    modules.game_textmessage.displayGameMessage("Nenhuma gema equipada", 'Gem Debug')
  end
  
  g_logger.info("=== END DEBUG ===")
  
  return activeGems, totalBonuses
end

-- Function to request current stats from server for comparison
function requestStatsComparison()
  g_logger.info("Requesting current stats for gem bonus verification...")
  
  if g_game.isOnline() and g_game.sendExtendedOpcode then
    local data = {action = "getStats"}
    g_game.sendExtendedOpcode(ExtendedIds.ConjurerGemRequest, json.encode(data))
    g_logger.info("Sent stats request to server")
  else
    g_logger.warning("Cannot request stats: not online or no opcode support")
  end
end

-- Monitor player stats changes for gem testing
local lastKnownStats = {}

function captureCurrentStats()
  local player = g_game.getLocalPlayer()
  if not player then return nil end
  
  local stats = {
    attack = player:getSkillLevel(Skill_Fist), -- Pode precisar ajustar dependendo do sistema
    defense = player:getSkillLevel(Skill_Shield),
    mana = player:getMana(),
    maxMana = player:getMaxMana(),
    health = player:getHealth(),
    maxHealth = player:getMaxHealth(),
    speed = player:getSpeed(),
    timestamp = os.time()
  }
  
  return stats
end

function compareStatsWithGems()
  local currentStats = captureCurrentStats()
  if not currentStats then return end
  
  local activeGems, totalBonuses = debugGemBonuses()
  
  g_logger.info("=== STATS COMPARISON ===")
  g_logger.info("Current Mana: " .. currentStats.mana .. "/" .. currentStats.maxMana)
  g_logger.info("Current Health: " .. currentStats.health .. "/" .. currentStats.maxHealth)
  g_logger.info("Current Speed: " .. currentStats.speed)
  
  if totalBonuses then
    g_logger.info("Expected bonuses from gems:")
    for bonusType, value in pairs(totalBonuses) do
      g_logger.info("  " .. bonusType .. ": +" .. value)
    end
  end
  
  -- Salvar stats atuais para comparação futura
  lastKnownStats = currentStats
  
  return currentStats
end

-- Enhanced function to show detailed gem effects
function showGemEffectsDetailed()
  local activeGems, totalBonuses = debugGemBonuses()
  
  if not activeGems or #activeGems == 0 then
    modules.game_textmessage.displayGameMessage("Nenhuma gema equipada para analisar", 'Gem Debug')
    return
  end
  
  -- Criar janela de detalhes dos efeitos
  local window = g_ui.createWidget('MainWindow')
  window:setId('gemEffectsDebugWindow')
  window:setText('Gem Effects Debug')
  window:setSize({width = 400, height = 300})
  window:center()
  
  -- Texto com detalhes
  local textArea = g_ui.createWidget('TextEdit', window)
  textArea:setPosition({x = 10, y = 30})
  textArea:setSize({width = 380, height = 200})
  textArea:setFont('verdana-11px-rounded')
  textArea:setReadOnly(true)
  
  local detailText = "🔮 ANÁLISE DETALHADA DOS BÔNUS\n\n"
  
  -- Informações por gema
  detailText = detailText .. "📍 GEMAS EQUIPADAS:\n"
  for _, gem in ipairs(activeGems) do
    detailText = detailText .. string.format("Slot %d: %s (ID: %d)\n", gem.slot, gem.name, gem.itemId)
    detailText = detailText .. string.format("  ▶ Bônus: +%d %s\n\n", gem.value, gem.bonus:upper())
  end
  
  -- Totais acumulados
  detailText = detailText .. "📊 TOTAIS ACUMULADOS:\n"
  for bonusType, totalValue in pairs(totalBonuses) do
    detailText = detailText .. string.format("▶ %s: +%d\n", bonusType:upper(), totalValue)
  end
  
  -- Instruções de teste
  detailText = detailText .. "\n🧪 COMO TESTAR:\n"
  detailText = detailText .. "1. Anote seus stats atuais\n"
  detailText = detailText .. "2. Remova todas as gemas\n"
  detailText = detailText .. "3. Compare os stats\n"
  detailText = detailText .. "4. Reequipe as gemas\n"
  detailText = detailText .. "5. Verifique se os bônus foram aplicados\n"
  
  textArea:setText(detailText)
  
  -- Botões - Primeira linha
  local captureButton = g_ui.createWidget('Button', window)
  captureButton:setText('Capture Stats')
  captureButton:setPosition({x = 10, y = 240})
  captureButton:setSize({width = 90, height = 25})
  captureButton:setTooltip('Captura seus stats atuais')
  captureButton.onClick = function()
    compareStatsWithGems()
    modules.game_textmessage.displayGameMessage("Stats capturados! Veja o console para detalhes.", 'Gem Debug')
  end
  
  local testButton = g_ui.createWidget('Button', window)
  testButton:setText('Test Server')
  testButton:setPosition({x = 110, y = 240})
  testButton:setSize({width = 90, height = 25})
  testButton:setTooltip('Solicita stats do servidor')
  testButton.onClick = function()
    requestStatsComparison()
  end
  
  local consoleButton = g_ui.createWidget('Button', window)
  consoleButton:setText('Console Log')
  consoleButton:setPosition({x = 210, y = 240})
  consoleButton:setSize({width = 90, height = 25})
  consoleButton:setTooltip('Mostra debug no console')
  consoleButton.onClick = function()
    debugGemBonuses()
  end
  
  local closeButton = g_ui.createWidget('Button', window)
  closeButton:setText('Close')
  closeButton:setPosition({x = 310, y = 240})
  closeButton:setSize({width = 80, height = 25})
  closeButton.onClick = function()
    window:destroy()
  end
  
  -- Botões - Segunda linha para controle de monitoramento
  local monitorButton = g_ui.createWidget('Button', window)
  monitorButton:setText(gemBonusTracker.enabled and 'Disable Monitor' or 'Enable Monitor')
  monitorButton:setPosition({x = 10, y = 270})
  monitorButton:setSize({width = 95, height = 25})
  monitorButton:setTooltip('Ativar/desativar monitoramento de dano por gemas')
  monitorButton.onClick = function()
    local enabled = toggleGemBonusMonitoring()
    monitorButton:setText(enabled and 'Disable Monitor' or 'Enable Monitor')
  end
  
  local calibrateButton = g_ui.createWidget('Button', window)
  calibrateButton:setText('Calibrate DMG')
  calibrateButton:setPosition({x = 115, y = 270})
  calibrateButton:setSize({width = 95, height = 25})
  calibrateButton:setTooltip('Calibrar faixa de dano base (sem gemas)')
  calibrateButton.onClick = function()
    -- Usar média dos últimos danos como referência
    if #gemBonusTracker.damageHistory >= 3 then
      local damages = {}
      for _, record in ipairs(gemBonusTracker.damageHistory) do
        if record.bonus == 0 then -- Apenas ataques sem bônus de gemas
          table.insert(damages, record.damage)
        end
      end
      
      if #damages >= 2 then
        table.sort(damages)
        local min = damages[1]
        local max = damages[#damages]
        calibrateBaseDamage(min, max)
      else
        modules.game_textmessage.displayGameMessage("Precisa de mais dados sem gemas equipadas", 'Gem System')
      end
    else
      modules.game_textmessage.displayGameMessage("Histórico insuficiente para calibração", 'Gem System')
    end
  end
  
  local historyButton = g_ui.createWidget('Button', window)
  historyButton:setText('Show History')
  historyButton:setPosition({x = 220, y = 270})
  historyButton:setSize({width = 95, height = 25})
  historyButton:setTooltip('Mostrar histórico de danos')
  historyButton.onClick = function()
    showDamageHistory()
  end
  
  -- Botão modo teste - Terceira linha
  local testModeButton = g_ui.createWidget('Button', window)
  testModeButton:setText(gemBonusTracker.testMode and 'Test Mode: ON' or 'Test Mode: OFF')
  testModeButton:setPosition({x = 10, y = 300})
  testModeButton:setSize({width = 120, height = 25})
  testModeButton:setTooltip('Alternar modo de teste (chance aumentada)')
  testModeButton.onClick = function()
    local enabled = toggleTestMode()
    testModeButton:setText(enabled and 'Test Mode: ON' or 'Test Mode: OFF')
  end
  
  local forceEffectButton = g_ui.createWidget('Button', window)
  forceEffectButton:setText('Force Effect')
  forceEffectButton:setPosition({x = 140, y = 300})
  forceEffectButton:setSize({width = 100, height = 25})
  forceEffectButton:setTooltip('Forçar efeito visual de teste')
  forceEffectButton.onClick = function()
    testGemEffect('atk', 72, getCurrentAttackBonus())
  end
  
  -- Botão para testar conexão com servidor
  local connectionTestButton = g_ui.createWidget('Button', window)
  connectionTestButton:setText('Test Server')
  connectionTestButton:setPosition({x = 250, y = 300})
  connectionTestButton:setSize({width = 100, height = 25})
  connectionTestButton:setTooltip('Testar comunicação com servidor')
  connectionTestButton.onClick = function()
    forceServerCommunicationTest()
  end
  
  -- Expandir janela para acomodar terceira linha de botões
  window:setSize({width = 400, height = 360})
  
  window:show()
  window:raise()
  window:focus()
end

-- Handler for ConjurerGemSync opcode (246)
function onConjurerGemSync(protocol, opcode, buffer)
  g_logger.info("📨 Received ConjurerGemSync opcode with buffer length: " .. buffer:len())
  
  if buffer == '' then 
    g_logger.error("Empty buffer received for ConjurerGemSync")
    return 
  end
  
  local success, data = pcall(function() 
    return json.decode(buffer)
  end)
  
  if not success or not data then
    g_logger.error("Failed to decode ConjurerGemSync JSON: " .. tostring(data))
    return
  end
  
  g_logger.info("🔄 Server response: " .. (data.status or "no status"))
  
  if data.status == "success" then
    if data.message then
      g_logger.info("✅ " .. data.message)
    end
    if data.totalAttackBonus then
      g_logger.info("⚔️ Server confirmed ATK bonus: +" .. data.totalAttackBonus)
    end
    g_logger.info("✅ Gems synchronized successfully with server!")
  elseif data.status == "error" then
    g_logger.warning("❌ Server gem sync error: " .. (data.message or "unknown error"))
  else
    g_logger.info("📋 Server response: " .. json.encode(data))
  end
end

-- Handler for ConjurerData opcode (301)
function onConjurerData(protocol, opcode, buffer)
  -- g_logger.info("Received ConjurerData opcode with buffer length: " .. buffer:len())
  
  if buffer == '' then 
    g_logger.error("Empty buffer received for ConjurerData")
    return
  end

-- DUAL HIT SYSTEM - Enhanced for displaying separate damage numbers
-- ================================================================

-- Track recent damage hits for dual hit detection
local dualHitTracker = {
  lastHit = {damage = 0, time = 0, processed = false},
  bonusHitQueue = {},
  enabled = false
}

-- Function to create a visual dual hit effect (like in your image)
function createDualHitEffect(baseDamage, bonusDamage, targetName)
  if not gemBonusTracker.clientVisualsEnabled or not dualHitTracker.enabled then
    return
  end
  g_logger.info("💥 DUAL HIT EFFECT - Base: " .. baseDamage .. ", Bonus: " .. bonusDamage)
  
  -- First hit: Show original damage (already shown by game)
  -- Second hit: Show bonus damage with slight delay
  scheduleEvent(function()
    local bonusHitMsg = string.format("A %s loses %d hitpoints due to magical enhancement.", targetName, bonusDamage)
    
    -- Show as separate damage message (mode 16 same as regular damage but delayed)
    if g_game and g_game.processTextMessage then
      g_game.processTextMessage(16, bonusHitMsg)
    end
    
    -- Also show visual notification for player
    local notificationMsg = string.format("💎 Gem Bonus Hit: +%d damage!", bonusDamage)
    if modules.game_textmessage and modules.game_textmessage.displayMessage then
      modules.game_textmessage.displayMessage(20, notificationMsg)
    end
    
  end, 250) -- 250ms delay for second hit visual effect
end

-- Enhanced damage processing for dual hits
function processDualHitDamage(damageValue, targetName)
  if not gemBonusTracker.clientVisualsEnabled or not dualHitTracker.enabled then
    return false
  end
  local attackBonus = getCurrentAttackBonus()
  if attackBonus <= 0 then return false end
  
  -- Check if bonus should activate
  local shouldActivate = analyzeDamageForGemBonus(damageValue)
  if not shouldActivate then return false end
  
  -- Calculate bonus damage
  local bonusDamage = math.floor(damageValue * (attackBonus / 100))
  if bonusDamage <= 0 then return false end
  
  g_logger.info("⚔️ DUAL HIT PROCESSING - Original: " .. damageValue .. ", Bonus: +" .. bonusDamage)
  
  -- Create the dual hit visual effect
  createDualHitEffect(damageValue, bonusDamage, targetName or "target")
  
  -- Track this as a processed dual hit
  dualHitTracker.lastHit = {
    damage = damageValue,
    bonus = bonusDamage,
    time = os.time(),
    processed = true
  }
  
  return true
end

-- Test function for dual hit system
function testDualHitSystem()
  g_logger.info("🧪 Testing Dual Hit System...")
  
  local testDamages = {45, 67, 52, 38, 71}
  
  for i, damage in ipairs(testDamages) do
    scheduleEvent(function()
      g_logger.info("Testing dual hit #" .. i .. " with damage: " .. damage)
      processDualHitDamage(damage, "dragon")
    end, i * 1000) -- 1 second between tests
  end
end  local success, data = pcall(function() 
    return json.decode(buffer)
  end)
  
  if not success or not data then
    g_logger.error("Failed to decode ConjurerData JSON: " .. tostring(data))
    return
  end
  
  -- Update global conjurer data for slot unlock calculations
  if data.level and data.experience and data.nextLevelExp then
    currentConjurerData = {
      level = data.level,
      experience = data.experience,
      nextLevelExp = data.nextLevelExp
    }
    currentConjurerLevel = data.level
  end
  
  -- Update the UI with the received data
  if data.level and data.experience and data.nextLevelExp then
    updateConjurerUI(data.level, data.experience, data.nextLevelExp)
  else
    g_logger.warning("ConjurerData missing required fields")
  end
end 