-- Game AutoLoot Module for OTClient
-- This module will add an autoloot button and window

local autolootButton = nil
autolootWindow = nil

function init()
  print('[AutoLoot] Módulo carregado!')
  -- Load the UI style
  g_ui.importStyle('autoloot')
  
  print('[AutoLoot] modules.game_interface:', modules.game_interface)
  if modules.game_interface then
    print('[AutoLoot] getRootWidget:', modules.game_interface.getRootWidget)
  end
  
  connect(g_game, { 
    onGameStart = refresh,
    onGameEnd = offline
  })
  
  -- Adiar a criação da janela para garantir que o game_interface já está pronto
  addEvent(function()
    if g_ui.getRootWidget then
      autolootWindow = g_ui.createWidget('AutoLootWindow', g_ui.getRootWidget())
      autolootWindow:hide()
    else
      print('[AutoLoot] ERRO: g_ui.getRootWidget não está disponível!')
    end
  end)
  
  -- Add button to the top menu
  setupTopMenuButton()
  
  if g_game.isOnline() then
    refresh()
  end
end

function terminate()
  disconnect(g_game, { 
    onGameStart = refresh,
    onGameEnd = offline
  })
  
  if autolootButton then
    autolootButton:destroy()
    autolootButton = nil
  end
  
  if autolootWindow then
    autolootWindow:destroy()
    autolootWindow = nil
  end
end

function setupTopMenuButton()
  if not g_app.isMobile() then
    autoLootButton = modules.client_topmenu.addRightGameToggleButton('autolootButton', tr('Auto Loot'), '/images/topbuttons/new/battle', 
    function()
      if autolootWindow and autolootWindow:isVisible() then
        autolootWindow:hide()
        tasksButton:setOn(false)
      else
        requestTasks()
      end
    end
    , nil, nil, true)
  else
    g_logger.info("É dispositivo móvel, não criando botão")
  end
end

function toggle()
  if autolootWindow:isVisible() then
    autolootWindow:hide()
    autolootButton:setOn(false)
  else
    autolootWindow:show()
    autolootWindow:raise()
    autolootWindow:focus()
    autolootButton:setOn(true)
  end
end

function onCloseWindow()
  autolootButton:setOn(false)
end

function refresh()
  -- Refresh the autoloot settings when game starts
end

function offline()
  -- Clear and hide window when going offline
  autolootWindow:hide()
  autolootButton:setOn(false)
end 