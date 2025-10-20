MessageSettings = {
  none            = {},
  consoleRed      = { color = TextColors.customWarning,    consoleTab='Default' },
  consoleOrange   = { color = TextColors.orange, consoleTab='Default' },
  consoleBlue     = { color = TextColors.blue,   consoleTab='Default' },
  centerRed       = { color = TextColors.customWarning,    consoleTab='Server Log', screenTarget='lowCenterLabel' },
  centerGreen     = { color = TextColors.customDesc,  consoleTab='Server Log', screenTarget='highCenterLabel',   consoleOption='showInfoMessagesInConsole' },
  centerWhite     = { color = TextColors.customInfo,  consoleTab='Server Log', screenTarget='middleCenterLabel', consoleOption='showEventMessagesInConsole' },
  bottomWhite     = { color = TextColors.customInfo,  consoleTab='Server Log', screenTarget='statusLabel',       consoleOption='showEventMessagesInConsole' },
  status          = { color = TextColors.customDesc,  consoleTab='Server Log', screenTarget='statusLabel',       consoleOption='showStatusMessagesInConsole' },
  statusSmall     = { color = TextColors.customInfo,                           screenTarget='statusLabel' },
  private         = { color = TextColors.customPrivate,                       screenTarget='privateLabel' },
  lootGreen       = { color = TextColors.green,  consoleTab='Server Log', screenTarget='highCenterLabel',   consoleOption='showInfoMessagesInConsole' }
}

MessageTypes = {
  [MessageModes.MonsterSay] = MessageSettings.consoleOrange,
  [MessageModes.MonsterYell] = MessageSettings.consoleOrange,
  [MessageModes.BarkLow] = MessageSettings.consoleOrange,
  [MessageModes.BarkLoud] = MessageSettings.consoleOrange,
  [MessageModes.Failure] = MessageSettings.statusSmall,
  [MessageModes.Login] = MessageSettings.bottomWhite,
  [MessageModes.Game] = MessageSettings.centerWhite,
  [MessageModes.Status] = MessageSettings.status,
  [MessageModes.Warning] = MessageSettings.centerRed,
  [MessageModes.Look] = MessageSettings.lootGreen,
  [MessageModes.Loot] = MessageSettings.lootGreen,
  [MessageModes.Red] = MessageSettings.consoleRed,
  [MessageModes.Blue] = MessageSettings.consoleBlue,
  [MessageModes.PrivateFrom] = MessageSettings.consoleBlue,

  [MessageModes.GamemasterBroadcast] = MessageSettings.consoleRed,

  [MessageModes.DamageDealed] = MessageSettings.status,
  [MessageModes.DamageReceived] = MessageSettings.status,
  [MessageModes.Heal] = MessageSettings.status,
  [MessageModes.Exp] = MessageSettings.status,

  [MessageModes.DamageOthers] = MessageSettings.none,
  [MessageModes.HealOthers] = MessageSettings.none,
  [MessageModes.ExpOthers] = MessageSettings.none,

  [MessageModes.TradeNpc] = MessageSettings.centerWhite,
  [MessageModes.Guild] = MessageSettings.centerWhite,
  [MessageModes.Party] = MessageSettings.centerGreen,
  [MessageModes.PartyManagement] = MessageSettings.centerWhite,
  [MessageModes.TutorialHint] = MessageSettings.centerWhite,
  [MessageModes.BeyondLast] = MessageSettings.centerWhite,
  [MessageModes.Report] = MessageSettings.consoleRed,
  [MessageModes.HotkeyUse] = MessageSettings.centerGreen,

  [254] = MessageSettings.private
}

messagesPanel = nil

function init()  
  for messageMode, _ in pairs(MessageTypes) do
    registerMessageMode(messageMode, displayMessage)
  end

  connect(g_game, 'onGameEnd', clearMessages)
  messagesPanel = g_ui.loadUI('textmessage', modules.game_interface.getRootPanel())
end

function terminate()
  for messageMode, _ in pairs(MessageTypes) do
    unregisterMessageMode(messageMode, displayMessage)
  end

  disconnect(g_game, 'onGameEnd', clearMessages)
  clearMessages()
  messagesPanel:destroy()
end

function calculateVisibleTime(text)
  return math.max(#text * 50, 3000)
end

function displayMessage(mode, text)
  if not g_game.isOnline() then return end

  -- -- DEBUG: Log all message calls
  -- g_logger.info("DEBUG displayMessage - Mode: " .. tostring(mode) .. " | Text: " .. tostring(text))
  
  -- Check if this is a loot message
  if text and text:lower():find("loot") then
    g_logger.info("DEBUG LOOT MESSAGE DETECTED - Mode: " .. tostring(mode) .. " | MessageModes.Loot: " .. tostring(MessageModes.Loot))
  end

  local msgtype = MessageTypes[mode]
  if not msgtype then
    -- g_logger.info("DEBUG: No msgtype found for mode " .. tostring(mode))
    return
  end

  if msgtype == MessageSettings.none then return end

  if msgtype.consoleTab ~= nil and (msgtype.consoleOption == nil or modules.client_options.getOption(msgtype.consoleOption)) then
    modules.game_console.addText(text, msgtype, tr(msgtype.consoleTab))
    --TODO move to game_console
  end

  if msgtype.screenTarget then
    local label = messagesPanel:recursiveGetChildById(msgtype.screenTarget)
    label:setText(text)
    
    -- Force green color for loot messages (mode 29) and Look messages with loot text (mode 20)
    if mode == MessageModes.Loot or (mode == MessageModes.Look and text and text:lower():find("loot")) then
      -- g_logger.info("DEBUG: Setting GREEN color for loot message! Mode: " .. tostring(mode))
      label:setColor(TextColors.green)
    else
      -- g_logger.info("DEBUG: Setting normal color: " .. tostring(msgtype.color) .. " for mode: " .. tostring(mode))
      label:setColor(msgtype.color)
    end
    
    label:setVisible(true)
    removeEvent(label.hideEvent)
    label.hideEvent = scheduleEvent(function() label:setVisible(false) end, calculateVisibleTime(text))
  end
end

function displayPrivateMessage(text)
  displayMessage(254, text)
end

function displayStatusMessage(text)
  displayMessage(MessageModes.Status, text)
end

function displayFailureMessage(text)
  displayMessage(MessageModes.Failure, text)
end

function displayGameMessage(text)
  displayMessage(MessageModes.Game, text)
end

function displayBroadcastMessage(text)
  displayMessage(MessageModes.Warning, text)
end

function clearMessages()
  for _i,child in pairs(messagesPanel:recursiveGetChildren()) do
    if child:getId():match('Label') then
      child:hide()
      removeEvent(child.hideEvent)
    end
  end
end

-- Função para testar a nova cor do loot
function testLootColor()
  displayMessage(MessageModes.Loot, "Teste: Loot de a rotworm: 9 gold coins, 7 worms")
end

-- Função para debugar configurações
function debugLootConfig()
  g_logger.info("=== LOOT DEBUG INFO ===")
  g_logger.info("MessageModes.Loot: " .. tostring(MessageModes.Loot))
  g_logger.info("TextColors.green: " .. tostring(TextColors.green))
  g_logger.info("TextColors.customDesc: " .. tostring(TextColors.customDesc))
  
  local lootMsgType = MessageTypes[MessageModes.Loot]
  if lootMsgType then
    g_logger.info("Loot message type found:")
    g_logger.info("  - color: " .. tostring(lootMsgType.color))
    g_logger.info("  - screenTarget: " .. tostring(lootMsgType.screenTarget))
    g_logger.info("  - consoleTab: " .. tostring(lootMsgType.consoleTab))
  else
    g_logger.info("NO loot message type found!")
  end
  g_logger.info("======================")
end

function LocalPlayer:onAutoWalkFail(player)
  modules.game_textmessage.displayFailureMessage(tr('There is no way.'))
end
