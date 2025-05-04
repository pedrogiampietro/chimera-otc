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

-- Function to open the rank details panel/modal
function showRankDetails(rankId)
  -- Close any existing rank details window
  local existingWindow = g_ui.getRootWidget():recursiveGetChildById('rankDetailsWindow')
  if existingWindow then
    existingWindow:destroy()
  end

  local rankData = {
    [0] = {
      title = tr('Novice Conjurer'),
      desc = tr('Beginning your journey in conjuration magic.'),
      bonus = tr('Bonus') .. ': +5% XP',
      date = tr('Unlocked on:') .. ' 12/04/2024',
      next = tr('Next rank:') .. ' 200/1000 XP'
    },
    [1] = {
      title = tr('Apprentice Conjurer'),
      desc = tr('Learning the fundamentals of magical creation.'),
      bonus = tr('Bonus') .. ': +7% XP',
      date = tr('Unlocked on:') .. ' 15/04/2024',
      next = tr('Next rank:') .. ' 800/2000 XP'
    },
    [2] = {
      title = tr('Adept Conjurer'),
      desc = tr('Mastering advanced conjuration techniques.'),
      bonus = tr('Bonus') .. ': +10% XP',
      date = tr('Unlocked on:') .. ' 18/04/2024',
      next = tr('Next rank:') .. ' 1200/3000 XP'
    },
    [3] = {
      title = tr('Master Conjurer'),
      desc = tr('Able to conjure complex objects and elements.'),
      bonus = tr('Bonus') .. ': +12% XP',
      date = tr('Unlocked on:') .. ' 20/04/2024',
      next = tr('Next rank:') .. ' 2000/5000 XP'
    },
    [4] = {
      title = tr('Elder Conjurer'),
      desc = tr('Wisdom of ancient conjuration knowledge.'),
      bonus = tr('Bonus') .. ': +15% XP',
      date = tr('Unlocked on:') .. ' 22/04/2024',
      next = tr('Next rank:') .. ' 3500/8000 XP'
    },
    [5] = {
      title = tr('Legendary Conjurer'),
      desc = tr('Ultimate mastery of conjuration arts.'),
      bonus = tr('Bonus') .. ': +20% XP',
      date = tr('Unlocked on:') .. ' 25/04/2024',
      next = tr('Maximum rank achieved!')
    }
  }
  
  -- Get data for the selected rank or default to Novice if invalid
  local data = rankData[rankId] or rankData[0]
  
  -- Criar a janela diretamente na raiz da interface para garantir que ela apareça por cima
  local window = g_ui.createWidget('MainWindow', g_ui.getRootWidget())
  if not window then
    print("Error: Could not create window widget")
    return
  end
  
  window:setId('rankDetailsWindow')
  window:setText(tr('Rank Details'))
  window:setSize({width = 320, height = 260})
  window:setDraggable(true)
  window:setFocusable(true)
  
  -- Create title label
  local titleLabel = g_ui.createWidget('Label', window)
  titleLabel:setId('detailTitle')
  titleLabel:setFont('verdana-11px-rounded')
  titleLabel:setColor('#ffaa00')
  titleLabel:setText(data.title)
  titleLabel:setMarginTop(18)
  titleLabel:setAnchors({['top'] = 'parent.top', ['horizontalCenter'] = 'parent.horizontalCenter'})
  
  -- Create description label
  local descLabel = g_ui.createWidget('Label', window)
  descLabel:setId('detailDesc')
  descLabel:setFont('verdana-11px-rounded')
  descLabel:setColor('#cccccc')
  descLabel:setText(data.desc)
  descLabel:setMarginTop(10)
  descLabel:setWidth(280)
  descLabel:enableTextWrap(true)
  descLabel:setAnchors({['top'] = 'detailTitle.bottom', ['horizontalCenter'] = 'parent.horizontalCenter'})
  
  -- Create bonus label
  local bonusLabel = g_ui.createWidget('Label', window)
  bonusLabel:setId('detailBonus')
  bonusLabel:setFont('verdana-11px-rounded')
  bonusLabel:setColor('#ffaa00')
  bonusLabel:setText(data.bonus)
  bonusLabel:setMarginTop(10)
  bonusLabel:setAnchors({['top'] = 'detailDesc.bottom', ['horizontalCenter'] = 'parent.horizontalCenter'})
  
  -- Create date label
  local dateLabel = g_ui.createWidget('Label', window)
  dateLabel:setId('detailDate')
  dateLabel:setFont('verdana-11px-rounded')
  dateLabel:setColor('#888888')
  dateLabel:setText(data.date)
  dateLabel:setMarginTop(10)
  dateLabel:setAnchors({['top'] = 'detailBonus.bottom', ['horizontalCenter'] = 'parent.horizontalCenter'})
  
  -- Create next rank label
  local nextLabel = g_ui.createWidget('Label', window)
  nextLabel:setId('detailNext')
  nextLabel:setFont('verdana-11px-rounded')
  nextLabel:setColor('#cccccc')
  nextLabel:setText(data.next)
  nextLabel:setMarginTop(10)
  nextLabel:setAnchors({['top'] = 'detailDate.bottom', ['horizontalCenter'] = 'parent.horizontalCenter'})
  
  -- Create close button
  local closeButton = g_ui.createWidget('Button', window)
  closeButton:setId('closeButton')
  closeButton:setText(tr('Close'))
  closeButton:setFont('verdana-11px-rounded')
  closeButton:setWidth(80)
  closeButton:setMarginBottom(15)
  closeButton:setAnchors({['bottom'] = 'parent.bottom', ['horizontalCenter'] = 'parent.horizontalCenter'})
  closeButton.onClick = function() window:destroy() end
  
  -- Center the window on the screen
  window:center()
  
  -- Use métodos adicionais para garantir que a janela apareça no topo
  window:raise()
  window:focus()
  window:show()
  
  -- Aplicar um atraso e elevar novamente para garantir que ela fique no topo
  scheduleEvent(function()
    if window and window:isVisible() then
      window:raise()
      window:focus()
    end
  end, 50)
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