HOTKEY_MANAGER_USE = nil
-- Disabled use types - use on self, use on target, and use with crosshair removed
-- HOTKEY_MANAGER_USEONSELF = 1
-- HOTKEY_MANAGER_USEONTARGET = 2
-- HOTKEY_MANAGER_USEWITH = 3

HotkeyColors = {
  text = '#888888',
  textAutoSend = '#FFFFFF',
  -- Item colors removed - item functionality disabled
  -- itemUse = '#8888FF',
  -- itemUseSelf = '#00FF00',
  -- itemUseTarget = '#FF0000',
  -- itemUseWith = '#F5B325',
  extraAction = '#FFAA00'
}

hotkeysManagerLoaded = false
hotkeysWindow = nil
configSelector = nil
hotkeysButton = nil
currentHotkeyLabel = nil
currentItemPreview = nil
itemWidget = nil
addHotkeyButton = nil
removeHotkeyButton = nil
hotkeyText = nil
hotKeyTextLabel = nil
sendAutomatically = nil
selectObjectButton = nil
clearObjectButton = nil
useOnSelf = nil
useOnTarget = nil
useWith = nil
defaultComboKeys = nil
perCharacter = true
mouseGrabberWidget = nil
useRadioGroup = nil
currentHotkeys = nil
boundCombosCallback = {}
hotkeysList = {}
hotkeyConfigs = {}
currentConfig = 1
configValueChanged = false

-- public functions
function init()
  -- Desabilitado: botão de hotkeys removido do topbar
  -- if not g_app.isMobile() then
  --   hotkeysButton = modules.client_topmenu.addLeftGameButton('hotkeysButton', tr('Hotkeys') .. ' (Ctrl+K)', '/images/topbuttons/hotkeys', toggle, false, 7)
  -- end
  g_keyboard.bindKeyDown('Ctrl+K', toggle)
  hotkeysWindow = g_ui.displayUI('hotkeys_manager')
  hotkeysWindow:setVisible(false)
  
  configSelector = hotkeysWindow:getChildById('configSelector')
  currentHotkeys = hotkeysWindow:getChildById('currentHotkeys')
  -- Item preview and object selection controls removed - feature disabled
  currentItemPreview = nil
  addHotkeyButton = hotkeysWindow:getChildById('addHotkeyButton')
  removeHotkeyButton = hotkeysWindow:getChildById('removeHotkeyButton')
  hotkeyText = hotkeysWindow:getChildById('hotkeyText')
  hotKeyTextLabel = hotkeysWindow:getChildById('hotKeyTextLabel')
  sendAutomatically = hotkeysWindow:getChildById('sendAutomatically')
  selectObjectButton = nil
  clearObjectButton = nil
  -- Use type controls removed - feature disabled
  useOnSelf = nil
  useOnTarget = nil
  useWith = nil

  -- Radio group removed since use type controls are disabled
  useRadioGroup = nil

  -- Mouse grabber widget removed - item selection functionality disabled
  mouseGrabberWidget = nil

  currentHotkeys.onChildFocusChange = function(self, hotkeyLabel) onSelectHotkeyLabel(hotkeyLabel) end
  g_keyboard.bindKeyPress('Down', function() currentHotkeys:focusNextChild(KeyboardFocusReason) end, hotkeysWindow)
  g_keyboard.bindKeyPress('Up', function() currentHotkeys:focusPreviousChild(KeyboardFocusReason) end, hotkeysWindow)

  if hotkeysWindow.action and setupExtraHotkeys then
    setupExtraHotkeys(hotkeysWindow.action)
  end

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })  
  
  for i = 1, configSelector:getOptionsCount() do
    hotkeyConfigs[i] = g_configs.create("/hotkeys_" .. i .. ".otml")
  end

  load()
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })

  g_keyboard.unbindKeyDown('Ctrl+K')

  unload()

  hotkeysWindow:destroy()
  if hotkeysButton then
    hotkeysButton:destroy()
  end
  mouseGrabberWidget:destroy()
end

function online()
  reload()
  hide()
end

function offline()
  unload()
  hide()
end

function show()
  if not g_game.isOnline() then
    return
  end
  hotkeysWindow:show()
  hotkeysWindow:raise()
  hotkeysWindow:focus()
end

function hide()
  hotkeysWindow:hide()
end

function toggle()
  if not hotkeysWindow:isVisible() then
    show()
  else
    hide()
  end
end

function ok()
  save()
  hide()
end

function cancel()
  reload()
  hide()
end

function load(forceDefaults)
  hotkeysManagerLoaded = false
  currentConfig = 1
  
  local hotkeysNode = g_settings.getNode('hotkeys') or {}
  local index = g_game.getCharacterName() .. "_" .. g_game.getClientVersion()
  if hotkeysNode[index] ~= nil and hotkeysNode[index] > 0 and hotkeysNode[index] <= #hotkeyConfigs then
    currentConfig = hotkeysNode[index]
  end  
  
  configSelector:setCurrentIndex(currentConfig, true)

  local hotkeySettings = hotkeyConfigs[currentConfig]:getNode('hotkeys')
  local hotkeys = {}

  if not table.empty(hotkeySettings) then hotkeys = hotkeySettings end

  hotkeyList = {}
  if not forceDefaults then
    if not table.empty(hotkeys) then
      for keyCombo, setting in pairs(hotkeys) do
        keyCombo = tostring(keyCombo)
        addKeyCombo(keyCombo, setting)
        hotkeyList[keyCombo] = setting
      end
    end
  end

  if currentHotkeys:getChildCount() == 0 then
    loadDefautComboKeys()
  end
  
  configValueChanged = false
  hotkeysManagerLoaded = true
end

function unload()
  local gameRootPanel = modules.game_interface.getRootPanel()
  for keyCombo,callback in pairs(boundCombosCallback) do
    g_keyboard.unbindKeyPress(keyCombo, callback, gameRootPanel)
  end
  boundCombosCallback = {}
  currentHotkeys:destroyChildren()
  currentHotkeyLabel = nil
  updateHotkeyForm(true)
  hotkeyList = {}
end

function reset()
  unload()
  load(true)
end

function reload()
  unload()
  load()
end

function save()
  if not configValueChanged then
    return
  end
  
  local hotkeySettings = hotkeyConfigs[currentConfig]:getNode('hotkeys') or {}  
  
  table.clear(hotkeySettings)

  for _,child in pairs(currentHotkeys:getChildren()) do
    hotkeySettings[child.keyCombo] = {
      autoSend = child.autoSend,
      -- Item data removed - functionality disabled
      -- itemId = child.itemId,
      -- subType = child.subType,
      -- useType = child.useType,
      value = child.value,
      action = child.action
    }
  end

  hotkeyList = hotkeySettings
  hotkeyConfigs[currentConfig]:setNode('hotkeys', hotkeySettings)
  hotkeyConfigs[currentConfig]:save()
  
  local index = g_game.getCharacterName() .. "_" .. g_game.getClientVersion()
  local hotkeysNode = g_settings.getNode('hotkeys') or {}
  hotkeysNode[index] = currentConfig
  g_settings.setNode('hotkeys', hotkeysNode)  
  g_settings.save()
end

function onConfigChange()
  if not configSelector then return end
  local index = g_game.getCharacterName() .. "_" .. g_game.getClientVersion()
  local hotkeysNode = g_settings.getNode('hotkeys') or {}
  hotkeysNode[index] = configSelector.currentIndex
  g_settings.setNode('hotkeys', hotkeysNode)  
  reload()  
end

function loadDefautComboKeys()
  if not defaultComboKeys then
    for i=1,12 do
      addKeyCombo('F' .. i)
    end
    for i=1,4 do
      addKeyCombo('Shift+F' .. i)
    end
  else
    for keyCombo, keySettings in pairs(defaultComboKeys) do
      addKeyCombo(keyCombo, keySettings)
    end
  end
end

function setDefaultComboKeys(combo)
  defaultComboKeys = combo
end

-- Item selection functions removed - functionality disabled
-- onChooseItemMouseRelease, startChooseItem, and clearObject functions have been removed

function addHotkey()
  local assignWindow = g_ui.createWidget('HotkeyAssignWindow', rootWidget)
  assignWindow:grabKeyboard()

  local comboLabel = assignWindow:getChildById('comboPreview')
  comboLabel.keyCombo = ''
  assignWindow.onKeyDown = hotkeyCapture
end

function addKeyCombo(keyCombo, keySettings, focus)
  if keyCombo == nil or #keyCombo == 0 then return end
  if not keyCombo then return end
  local hotkeyLabel = currentHotkeys:getChildById(keyCombo)
  if not hotkeyLabel then
    hotkeyLabel = g_ui.createWidget('HotkeyListLabel')
    hotkeyLabel:setId(keyCombo)

    local children = currentHotkeys:getChildren()
    children[#children+1] = hotkeyLabel
    table.sort(children, function(a,b)
      if a:getId():len() < b:getId():len() then
        return true
      elseif a:getId():len() == b:getId():len() then
        return a:getId() < b:getId()
      else
        return false
      end
    end)
    for i=1,#children do
      if children[i] == hotkeyLabel then
        currentHotkeys:insertChild(i, hotkeyLabel)
        break
      end
    end

    if keySettings then
      currentHotkeyLabel = hotkeyLabel
      hotkeyLabel.keyCombo = keyCombo
      hotkeyLabel.autoSend = toboolean(keySettings.autoSend)
      hotkeyLabel.action = keySettings.action
      -- Item functionality completely removed - ignore item data
      hotkeyLabel.itemId = nil
      hotkeyLabel.subType = nil
      hotkeyLabel.useType = nil
      if keySettings.value then hotkeyLabel.value = tostring(keySettings.value) end
    else
      hotkeyLabel.keyCombo = keyCombo
      hotkeyLabel.autoSend = false
      -- Item functionality removed
      hotkeyLabel.itemId = nil
      hotkeyLabel.subType = nil
      hotkeyLabel.useType = nil
      hotkeyLabel.action = nil
      hotkeyLabel.value = ''
    end

    updateHotkeyLabel(hotkeyLabel)

    local gameRootPanel = modules.game_interface.getRootPanel()
    if keyCombo:lower():find("ctrl") then
      if boundCombosCallback[keyCombo] then
        g_keyboard.unbindKeyPress(keyCombo, boundCombosCallback[keyCombo], gameRootPanel)      
      end
    end

    boundCombosCallback[keyCombo] = function(k, c, ticks) prepareKeyCombo(keyCombo, ticks) end
    g_keyboard.bindKeyPress(keyCombo, boundCombosCallback[keyCombo], gameRootPanel)
        
    if not keyCombo:lower():find("ctrl") then
      local keyComboCtrl = "Ctrl+" .. keyCombo
      if not boundCombosCallback[keyComboCtrl] then
        boundCombosCallback[keyComboCtrl] = function(k, c, ticks) prepareKeyCombo(keyComboCtrl, ticks) end
        g_keyboard.bindKeyPress(keyComboCtrl, boundCombosCallback[keyComboCtrl], gameRootPanel)   
      end
    end
  end

  if focus then
    currentHotkeys:focusChild(hotkeyLabel)
    currentHotkeys:ensureChildVisible(hotkeyLabel)
    updateHotkeyForm(true)
  end
  configValueChanged = true
end

function prepareKeyCombo(keyCombo, ticks)
    local hotKey = hotkeyList[keyCombo]
    if (keyCombo:lower():find("ctrl") and not hotKey) or (hotKey and (not hotKey.value or #hotKey.value == 0) and not hotKey.action) then
      keyCombo = keyCombo:gsub("Ctrl%+", "")
      keyCombo = keyCombo:gsub("ctrl%+", "")
      hotKey = hotkeyList[keyCombo]
    end
    if not hotKey then
      return
    end
    
    if hotKey.itemId == nil and hotKey.action == nil then -- say
      scheduleEvent(function() doKeyCombo(keyCombo, ticks >= 5) end, g_settings.getNumber('hotkeyDelay'))
    else
      doKeyCombo(keyCombo, ticks >= 5)
    end
end

function doKeyCombo(keyCombo, repeated)
  if not g_game.isOnline() then return end
  if modules.game_console and modules.game_console.isChatEnabled() then
    if keyCombo:len() == 1 then 
      return
    end
  end
  if modules.game_walking then
    modules.game_walking.checkTurn()
  end
  
  local hotKey = hotkeyList[keyCombo]
  if not hotKey then return end

  local hotkeyDelay = 100  
  if hotKey.hotkeyDelayTo == nil or g_clock.millis() > hotKey.hotkeyDelayTo + hotkeyDelay then
    hotkeyDelay = 200 -- for first use
  end
  if hotKey.hotkeyDelayTo ~= nil and g_clock.millis() < hotKey.hotkeyDelayTo then
    return
  end
  if hotKey.action then
    executeExtraHotkey(hotKey.action, repeated)  
  else
    -- Only text/command hotkeys are supported - item functionality removed
    if not hotKey.value or #hotKey.value == 0 then return end
    if hotKey.autoSend then
      modules.game_console.sendMessage(hotKey.value)
    else
      modules.game_console.setTextEditText(hotKey.value)
    end
    hotKey.hotkeyDelayTo = g_clock.millis() + hotkeyDelay
  end
  -- Removed use on self, use on target, and use with crosshair functionality
  -- All items will use normal use behavior only
end

function updateHotkeyLabel(hotkeyLabel)
  if not hotkeyLabel then return end
  if hotkeyLabel.action ~= nil then  
    hotkeyLabel:setText(tr('%s: (Action: %s)', hotkeyLabel.keyCombo, getActionDescription(hotkeyLabel.action)))
    hotkeyLabel:setColor(HotkeyColors.extraAction)    
  else
    -- Only text/command hotkeys supported - item functionality removed
    local text = hotkeyLabel.keyCombo .. ': '
    if hotkeyLabel.value then
      text = text .. hotkeyLabel.value
    end
    hotkeyLabel:setText(text)
    if hotkeyLabel.autoSend then
      hotkeyLabel:setColor(HotkeyColors.autoSend)
    else
      hotkeyLabel:setColor(HotkeyColors.text)
    end
  end
end

function updateHotkeyForm(reset)
  configValueChanged = true
  if hotkeysWindow.action then
    if currentHotkeyLabel then
      hotkeysWindow.action:enable()
      if currentHotkeyLabel.action then
        hotkeysWindow.action:setCurrentIndex(translateActionToActionComboboxIndex(currentHotkeyLabel.action), true)      
      else
        hotkeysWindow.action:setCurrentIndex(1, true)
      end
    else
      hotkeysWindow.action:disable()    
      hotkeysWindow.action:setCurrentIndex(1, true)
    end
  end
  local hasCustomAction = hotkeysWindow.action and hotkeysWindow.action.currentIndex > 1
  if currentHotkeyLabel and not hasCustomAction then
    removeHotkeyButton:enable()
    -- Object/item functionality completely removed - only text hotkeys allowed
    hotkeyText:enable()
    hotkeyText:focus()
    hotKeyTextLabel:enable()
    if reset then
      hotkeyText:setCursorPos(-1)
    end
    hotkeyText:setText(currentHotkeyLabel.value or "")
    sendAutomatically:setChecked(currentHotkeyLabel.autoSend or false)
    sendAutomatically:setEnabled(currentHotkeyLabel.value and #currentHotkeyLabel.value > 0)
  else
    removeHotkeyButton:disable()
    hotkeyText:disable()
    sendAutomatically:disable()
    -- Object controls removed - no need to disable them
    hotkeyText:clearText()
    sendAutomatically:setChecked(false)
  end
end

function removeHotkey()
  if currentHotkeyLabel == nil then return end
  local gameRootPanel = modules.game_interface.getRootPanel()
  configValueChanged = true
  g_keyboard.unbindKeyPress(currentHotkeyLabel.keyCombo, boundCombosCallback[currentHotkeyLabel.keyCombo], gameRootPanel)
  boundCombosCallback[currentHotkeyLabel.keyCombo] = nil
  currentHotkeyLabel:destroy()
  currentHotkeyLabel = nil
end

function updateHotkeyAction()
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  configValueChanged = true
  currentHotkeyLabel.action = translateActionComboboxIndexToAction(hotkeysWindow.action.currentIndex)
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onHotkeyTextChange(value)
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  currentHotkeyLabel.value = value
  if value == '' then
    currentHotkeyLabel.autoSend = false
  end
  configValueChanged = true
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onSendAutomaticallyChange(autoSend)
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  if not currentHotkeyLabel.value or #currentHotkeyLabel.value == 0 then return end
  configValueChanged = true
  currentHotkeyLabel.autoSend = autoSend
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onChangeUseType(useTypeWidget)
  -- Function disabled - use type selection removed
  -- All items will use normal use behavior only
  if not hotkeysManagerLoaded then return end
  if currentHotkeyLabel == nil then return end
  configValueChanged = true
  -- Force normal use type only
  currentHotkeyLabel.useType = HOTKEY_MANAGER_USE
  updateHotkeyLabel(currentHotkeyLabel)
  updateHotkeyForm()
end

function onSelectHotkeyLabel(hotkeyLabel)
  currentHotkeyLabel = hotkeyLabel
  updateHotkeyForm(true)
end

function hotkeyCapture(assignWindow, keyCode, keyboardModifiers)
  local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers)
  local comboPreview = assignWindow:getChildById('comboPreview')
  comboPreview:setText(tr('Current hotkey to add: %s', keyCombo))
  comboPreview.keyCombo = keyCombo
  comboPreview:resizeToText()
  assignWindow:getChildById('addButton'):enable()
  return true
end

function hotkeyCaptureOk(assignWindow, keyCombo)
  addKeyCombo(keyCombo, nil, true)
  assignWindow:destroy()
end
