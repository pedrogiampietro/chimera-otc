minimapWidget = nil
minimapButton = nil
minimapWindow = nil
fullmapView = false
loaded = false
oldZoom = nil
oldPos = nil

function setupTopMenuButton()
  if not minimapWindow.forceOpen then
    minimapButton = modules.client_topmenu.addRightGameToggleButton('minimapButton', 
      tr('Minimap') .. ' (Ctrl+M)', '/images/topbuttons/new/minimap', toggle, nil, nil, true)
  end
end

function init()
  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRightPanel())
  minimapWindow:setContentMinimumHeight(86)

  minimapWidget = minimapWindow:recursiveGetChildById('minimap')
  minimapWindow:recursiveGetChildById('lockButton'):setVisible(false)
  
  local maximizeButton = g_ui.createWidget('MinimapMaximizeButton', minimapWindow)
  maximizeButton.onClick = toggleFullMap
  minimapWidget:recursiveGetChildById('fullMapMaximize').onClick = toggleFullMap

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyPress('Alt+Left', function() minimapWidget:move(1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() minimapWidget:move(-1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() minimapWidget:move(0,1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() minimapWidget:move(0,-1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+M', toggle)
  g_keyboard.bindKeyDown('Ctrl+Shift+M', toggleFullMap)

  minimapWindow:setup()

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  if g_game.isOnline() then
    saveMap()
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyPress('Alt+Left', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Right', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Up', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Down', gameRootPanel)
  g_keyboard.unbindKeyDown('Ctrl+M')
  g_keyboard.unbindKeyDown('Ctrl+Shift+M')

  minimapWindow:destroy()
  if minimapButton then
    minimapButton:destroy()
  end
end

function toggle()
  if not minimapButton then return end
  if minimapButton:isOn() then
    minimapWindow:close()
    minimapButton:setOn(false)
  else
    minimapWindow:open()
    minimapButton:setOn(true)
  end
end

function onMiniWindowClose()
  if minimapButton then
    minimapButton:setOn(false)
  end
end

function onNoParent()
  local parent = minimapWindow:getParent()
  if(parent:getClassName() == 'UIMiniWindowContainer') then
    minimapWindow:recursiveGetChildById('noParentBorder'):setVisible(false)
    minimapWindow:recursiveGetChildById('parentBorder1'):setVisible(true)
    minimapWindow:recursiveGetChildById('parentBorder2'):setVisible(true)
  else
    minimapWindow:recursiveGetChildById('noParentBorder'):setVisible(true)
    minimapWindow:recursiveGetChildById('parentBorder1'):setVisible(false)
    minimapWindow:recursiveGetChildById('parentBorder2'):setVisible(false)
  end
end

function online()
  if(minimapButton) then
    if(minimapWindow:isVisible()) then
      minimapButton:setOn(true)
    else
      minimapButton:setOn(false)
    end
  end
  loadMap()
  updateCameraPosition()
end

function offline()
  saveMap()
end

function loadMap()
  local clientVersion = g_game.getClientVersion()

  g_minimap.clean()
  loaded = false

  local minimapFile = '/minimap.otmm'
  local dataMinimapFile = '/data' .. minimapFile
  local versionedMinimapFile = '/minimap' .. clientVersion .. '.otmm'
  if g_resources.fileExists(dataMinimapFile) then
    loaded = g_minimap.loadOtmm(dataMinimapFile)
  end
  if not loaded and g_resources.fileExists(versionedMinimapFile) then
    loaded = g_minimap.loadOtmm(versionedMinimapFile)
  end
  if not loaded and g_resources.fileExists(minimapFile) then
    loaded = g_minimap.loadOtmm(minimapFile)
  end
  if not loaded then
    print("Minimap couldn't be loaded")
  end
  minimapWidget:load()
end

function saveMap()
  local clientVersion = g_game.getClientVersion()
  local minimapFile = '/minimap' .. clientVersion .. '.otmm' 
  g_minimap.saveOtmm(minimapFile)
  minimapWidget:save()
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if not pos then return end
  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(player:getPosition())
    end
    minimapWidget:setCrossPosition(player:getPosition())
  end
end

function toggleFullMap()
  if not fullmapView then
    fullmapView = true
    minimapWindow:hide()
    minimapWidget:setParent(modules.game_interface.getRootPanel())
    minimapWidget:fill('parent')
    minimapWidget:setAlternativeWidgetsVisible(true)
    minimapWidget:recursiveGetChildById('fullMapMaximize'):setVisible(true)
    g_keyboard.bindKeyPress('Escape', minimizeFullMap)
  else
    fullmapView = false
    minimapWidget:setParent(minimapWindow:getChildById('contentsPanel'))
    minimapWidget:fill('parent')
    minimapWindow:show()
    minimapWidget:setAlternativeWidgetsVisible(false)
    minimapWidget:recursiveGetChildById('fullMapMaximize'):setVisible(false)
    g_keyboard.unbindKeyPress('Escape', minimizeFullMap)
  end

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end

function minimizeFullMap()
  g_keyboard.unbindKeyPress('Escape', minimizeFullMap)
  if(not fullmapView) then
    return
  end
  fullmapView = false
  minimapWidget:setParent(minimapWindow:getChildById('contentsPanel'))
  minimapWidget:fill('parent')
  minimapWindow:show()
  minimapWidget:setAlternativeWidgetsVisible(false)
  minimapWidget:recursiveGetChildById('fullMapMaximize'):setVisible(false)

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end