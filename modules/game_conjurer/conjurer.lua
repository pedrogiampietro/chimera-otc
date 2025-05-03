-- game_conjurer/conjurer.lua

local window = nil
local button = nil

local STORAGE_CONJURER_EXP = 30001
local STORAGE_CONJURER_LEVEL = 30002

local conjurerRanks = {
  'Novice Conjurer',
  'Apprentice Conjurer',
  'Adept Conjurer',
  'Master Conjurer',
  'Elder Conjurer',
  'Legendary Conjurer'
}

local conjurerExp = { 0, 500, 1500, 3000, 6000, 10000 }
local conjurerMultipliers = { 1, 2, 4, 7, 10, 15 }

function init()
  connect(g_game, { onGameEnd = hide })
  button = modules.client_topmenu.addLeftGameToggleButton('conjurerButton',
    tr('Conjurer'),
    '/images/topbuttons/conjurer',
    toggle,
    false, 99999)
  button:setOn(false)
end

function terminate()
  disconnect(g_game, { onGameEnd = hide })
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
  end
  updateWindow()
  window:show()
  window:raise()
  window:focus()
  button:setOn(true)
end

function hide()
  if window then window:hide() end
  if button then button:setOn(false) end
end

function updateWindow()
  if not window then return end
  local player = g_game.getLocalPlayer()
  if not player then return end
  local exp = player:getStorageValue(STORAGE_CONJURER_EXP)
  local level = player:getStorageValue(STORAGE_CONJURER_LEVEL)
  if exp < 0 then exp = 0 end
  if level < 0 then level = 0 end
  local nextExp = conjurerExp[math.min(level+2, #conjurerExp)] or conjurerExp[#conjurerExp]
  local rank = conjurerRanks[level+1] or 'Unknown'
  local multiplier = conjurerMultipliers[level+1] or 1
  window:getChildById('rankLabel'):setText('Rank: ' .. rank)
  window:getChildById('xpLabel'):setText('XP: ' .. exp .. ' / ' .. nextExp)
  window:getChildById('xpBar'):setMaximum(nextExp)
  window:getChildById('xpBar'):setValue(exp)
  window:getChildById('multiplierLabel'):setText('Multiplicador: x' .. multiplier)
  window:getChildById('nextRankLabel'):setText('Próximo rank: ' .. (conjurerRanks[math.min(level+2,#conjurerRanks)] or '-') .. ' (' .. nextExp .. ' XP)')
end

function onTestButtonClick()
  displayInfoBox('Teste de conjuração', 'Aqui você pode simular um efeito visual ou ganho de XP!')
end 