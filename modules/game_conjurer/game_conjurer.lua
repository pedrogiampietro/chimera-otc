local conjurerWindow = nil
local conjurerButton = nil

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

function getCurrentConjurerLevel()
  return currentConjurerLevel
end

function init()
  conjurerWindow = g_ui.displayUI('game_conjurer', modules.game_interface.getRightPanel())
  conjurerWindow:hide()

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
  conjurerWindow:destroy()
  conjurerButton:destroy()
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
        end
        
        if rankDateWidget then
          rankDateWidget:setText(unlockDates[i])
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
          rankBonusWidget:setText('???')
        end
        
        if rankDateWidget then
          rankDateWidget:setText('')
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

-- Request updated conjurer information from the server
function requestConjurerInfo()
  -- This function should send a protocol request to the server
  -- For now we'll use example data
  updateConjurerUI(2, 3200, 6000)
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