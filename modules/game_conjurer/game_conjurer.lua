local conjurerWindow = nil
local conjurerButton = nil
local conjurerRankingWindow = nil

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

-- Constants for Extended Opcodes
local ExtendedIds = {
  ConjurerDataRequest = 240,
  ConjurerData = 241,
  ConjurerRankingRequest = 242,
  ConjurerRanking = 243
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
  else
    if ProtocolGame and ProtocolGame.registerExtendedOpcode then
      g_logger.info("Using ProtocolGame.registerExtendedOpcode instead")
      ProtocolGame.registerExtendedOpcode(ExtendedIds.ConjurerRanking, onConjurerRanking)
      ProtocolGame.registerExtendedOpcode(ExtendedIds.ConjurerData, onConjurerData)
    else
      g_logger.error("No opcode registration method available!")
    end
  end
  
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
  -- Unregister protocol handlers
  if type(unregisterExtendedOpcode) == 'function' then
    unregisterExtendedOpcode(ExtendedIds.ConjurerRanking)
    unregisterExtendedOpcode(ExtendedIds.ConjurerData)
  else
    -- Try using ProtocolGame instead
    if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
      ProtocolGame.unregisterExtendedOpcode(ExtendedIds.ConjurerRanking)
      ProtocolGame.unregisterExtendedOpcode(ExtendedIds.ConjurerData)
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
    conjurerButton = modules.client_topmenu.addLeftGameToggleButton('conjurerButton', tr('Conjurer'), '/images/topbuttons/spelllist', toggleConjurerWindow, false, 4)
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

  -- Bonus values for each rank
  local bonusValues = {
    [0] = '+5% XP',
    [1] = '+7% XP',
    [2] = '+10% XP',
    [3] = '+12% XP',
    [4] = '+15% XP',
    [5] = '+20% XP'
  }
  
  -- Unlock dates for each rank (these would typically come from the server)
  local unlockDates = {
    [0] = '12/04/2024',
    [1] = '15/04/2024',
    [2] = '18/04/2024',
    [3] = '20/04/2024',
    [4] = '22/04/2024',
    [5] = '25/04/2024'
  }

  -- Update rank icons and labels
  for i = 0, 5 do
    local rankIconWidget = conjurerWindow:getChildById(rankIconIds[i])
    local rankLabelWidget = conjurerWindow:getChildById(rankIds[i])
    local rankBonusWidget = conjurerWindow:getChildById(rankIds[i] .. 'Bonus')
    local rankDateWidget = conjurerWindow:getChildById(rankIds[i] .. 'Date')
    
    if rankIconWidget and rankLabelWidget then
      if i <= level then
        -- Rank is unlocked
        rankIconWidget:setOpacity(1.0)
        rankIconWidget:setBorderColor(rankColors[i])
        rankIconWidget:setBorderWidth(3)
        rankLabelWidget:setColor(rankColors[i])
        
        -- Set bonus text and date text
        if rankBonusWidget then
          rankBonusWidget:setText(bonusValues[i])
          rankBonusWidget:setColor('#ffaa00')  -- Dourado
          rankBonusWidget:setOpacity(1.0)      -- Garantir visibilidade total
        end
        
        if rankDateWidget then
          -- Exibe informação adicional: a data ou quantidade de conjurers
          if i == 0 then
            rankDateWidget:setText(tr('Base rank'))
          elseif i == level then
            rankDateWidget:setText(tr('Current'))
          else
            rankDateWidget:setText(unlockDates[i])
          end
          rankDateWidget:setColor('#888888')  -- Cinza claro
          rankDateWidget:setOpacity(1.0)      -- Garantir visibilidade total
        end
        
        -- Add a glow effect to the current level
        if i == level then
          rankIconWidget:setImageColor('#ffffff')
          scheduleEvent(function() pulsateRankIcon(rankIconWidget) end, 500)
        else
          rankIconWidget:setImageColor('#cccccc')
        end
      else
        -- Rank is still locked
        rankIconWidget:setOpacity(0.4)
        rankIconWidget:setBorderColor('#444444')
        rankIconWidget:setBorderWidth(2)
        rankLabelWidget:setColor('#666666')
        rankIconWidget:setImageColor('#777777')
        
        -- Clear bonus and date for locked ranks
        if rankBonusWidget then
          rankBonusWidget:setText(tr('Locked'))
          rankBonusWidget:setColor('#666666')  -- Cinza
        end
        
        if rankDateWidget then
          local nextExp = {
            [0] = 1000,
            [1] = 5000,
            [2] = 15000,
            [3] = 50000,
            [4] = 150000,
            [5] = "MAX"
          }
          
          if i == level + 1 then
            -- Próximo rank - mostre a experiência necessária
            rankDateWidget:setText(nextExp[i] .. " exp")
            rankDateWidget:setColor('#666666')  -- Cinza
          else
            rankDateWidget:setText('')
          end
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
      print('DEBUG: current =', current, 'max =', max)
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

  -- Bônus
  local bonusWidget2 = content:recursiveGetChildById('rankDetailsBonus')
  if bonusWidget2 then
    bonusWidget2:setText(bonus)
  end

  -- Barra de progresso
  local progressLabel = content:recursiveGetChildById('rankDetailsProgressLabel')
  if progressLabel then
    progressLabel:setText(tr('Progress: ') .. progressText)
  end
  local progressBarBg = content:recursiveGetChildById('rankDetailsProgressBarBg')
  local progressBarFill = progressBarBg and progressBarBg:getChildById('rankDetailsProgressBarFill')
  if progressBarFill then
    local percent = math.min(1, progressValue / progressMax)
    progressBarFill:setWidth(math.floor((progressBarBg:getWidth() or 260) * percent))
  end

  -- Data de desbloqueio
  local dateLabel = content:recursiveGetChildById('rankDetailsDate')
  if dateLabel then
    dateLabel:setText(tr('Unlocked on:') .. ' ' .. date)
  end

  -- Requisito para o próximo rank
  local reqLabel = content:recursiveGetChildById('rankDetailsRequirement')
  if reqLabel then
    reqLabel:setText(requirementText)
  end

  -- Botão de ajuda
  local helpButton = content:recursiveGetChildById('rankDetailsHelpButton')
  if helpButton then
    helpButton.onClick = function()
      modules.game_textmessage.displayGameMessage(tr('Ranks grant you bonuses and unlock new conjuration powers. Progress by earning conjurer experience!'), 'Conjurer Help')
    end
  end

  -- Multiplicador de cargas
  local chargeWidget = content:recursiveGetChildById('rankDetailsCharge')
  if chargeWidget then
    local chargeText = data.chargeMultiplier or ''
    if chargeText == '' then
      chargeText = tr('N/A')
    end
    chargeWidget:setText(tr('Multiplicador de Cargas: ') .. chargeText)
  end

  -- Sistema de Alquimia
  local alchemyWidget = content:recursiveGetChildById('rankDetailsAlchemy')
  if alchemyWidget then
    alchemyWidget:setText(tr('Sistema de Alquimia: Adicione ingredientes raros na conjuração para modificar as runas (ex: +dano, +área, +efeito visual).'))
  end

  -- Configurar slots de alquimia para drag & drop
  for i = 1, 3 do
    local slot = content:recursiveGetChildById('slot'..i)
    local label = content:recursiveGetChildById('slot'..i..'_label')
    
    if slot then
      -- Limpar o slot ao abrir a janela
      slot:setItemId(0)
      
      -- Configurar tooltip
      slot:setTooltip(tr('Arraste um ingrediente raro aqui!'))
      
      -- Lista de itens recomendados para cada slot
      local recommendedItems = {
        [1] = {"flor do sol", "flor solar", "sun flower", "sunflower"},
        [2] = {"cristal arcano", "cristal mágico", "arcane crystal", "magic crystal"},
        [3] = {"essência etérea", "essência", "pó mágico", "ethereal essence", "essence"}
      }
      
      -- Função para verificar se um item é recomendado para este slot
      local function isRecommendedItem(itemName, slotIndex)
        if not itemName or not recommendedItems[slotIndex] then return false end
        
        local lowerName = itemName:lower()
        for _, recommendedName in ipairs(recommendedItems[slotIndex]) do
          if lowerName:find(recommendedName) then
            return true
          end
        end
        return false
      end
      
      -- Configurar evento de drag & drop
      slot.onDrop = function(self, dragged)
        if dragged and dragged.getItem then
          local item = dragged:getItem()
          if item then
            -- Coloca o item no slot
            self:setItem(item)
            
            -- Pega o nome do item e verifica se é recomendado
            local itemName = item:getName() or tr('Unknown Item')
            local isRecommended = isRecommendedItem(itemName, i)
            
            -- Atualiza o requisito correspondente na lista
            local reqLabel = content:recursiveGetChildById('req_item'..i)
            if reqLabel then
              if isRecommended then
                -- Item correto no slot correto
                reqLabel:setColor('#00ff00')  -- Verde para requisito cumprido
                self:setOpacity(1.0)
                self:setImageColor('#ffffff')
              else
                -- Item incorreto no slot
                reqLabel:setColor('#ffaa00')  -- Dourado para item errado
                self:setOpacity(0.85)
                self:setImageColor('#ffaa00')
              end
            end
            
            return true
          end
        end
        return false
      end
      
      -- Configurar evento de clique direito para limpar o slot
      slot.onMouseRightRelease = function(self)
        self:clearItem()
        -- Restaura a cor do requisito para vermelho (não cumprido)
        local reqLabel = content:recursiveGetChildById('req_item'..i)
        if reqLabel then
          reqLabel:setColor('#e65b5b')  -- Vermelho para requisito não cumprido
        end
        self:setOpacity(0.5)
        self:setImageColor('#aaaaaa')
      end
    end
  end
  
  -- Configurar botão de craftar para coletar itens dos slots
  local craftButton = content:recursiveGetChildById('alchemyCraftButton')
  if craftButton then
    craftButton.onClick = function()
      local items = {}
      for i = 1, 3 do
        local slot = content:recursiveGetChildById('slot'..i)
        if slot and slot.getItem and slot:getItem() then
          table.insert(items, slot:getItem():getName() or tr('Unknown Item'))
        end
      end
      
      if #items == 0 then
        modules.game_textmessage.displayGameMessage(tr('Adicione pelo menos um ingrediente para craftar!'), 'Alchemy')
      else
        modules.game_textmessage.displayGameMessage(tr('Craft realizado com: ') .. table.concat(items, ', '), 'Alchemy')
        -- Aqui você pode adicionar a lógica real de craft, enviar para o servidor, etc.
      end
    end
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

-- Handler for ConjurerData opcode (301)
function onConjurerData(protocol, opcode, buffer)
  g_logger.info("Received ConjurerData opcode with buffer length: " .. buffer:len())
  
  if buffer == '' then 
    g_logger.error("Empty buffer received for ConjurerData")
    return 
  end
  
  local success, data = pcall(function() 
    return json.decode(buffer)
  end)
  
  if not success or not data then
    g_logger.error("Failed to decode ConjurerData JSON: " .. tostring(data))
    return
  end
  
  
  -- Update the UI with the received data
  if data.level and data.experience and data.nextLevelExp then
    updateConjurerUI(data.level, data.experience, data.nextLevelExp)
  else
    g_logger.warning("ConjurerData missing required fields")
  end
end 