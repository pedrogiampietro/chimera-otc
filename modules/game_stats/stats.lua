ui = nil
updateEvent = nil

function init()
  ui = g_ui.loadUI('stats', modules.game_interface.getMapPanel())
  
  if not modules.client_options.getOption("showPing") then
    ui.fps:hide()
  end
  if not modules.client_options.getOption("showFps") then
    ui.ping:hide()
  end
  
  show()
  
  updateEvent = scheduleEvent(update, 200)
end

function terminate()
  removeEvent(updateEvent)
end

function update()
  updateEvent = scheduleEvent(update, 500)
  if ui:isHidden() then return end

  text = 'FPS: ' .. g_app.getFps()
  ui.fps:setText(text)

  local ping = g_game.getPing()
  if g_proxy and g_proxy.getPing() > 0 then
    ping = g_proxy.getPing()
  end
  
  local text = 'Ping: '
  local color
  if ping < 0 then
    text = text .. "??"
    color = 'yellow'
  else
    text = text .. ping .. ' ms'
    if ping >= 500 then
      color = 'red'
    elseif ping >= 250 then
      color = 'yellow'
    else
      color = 'green'
    end
  end
  ui.ping:setText(text)
  ui.ping:setColor(color)
end

function showBonusButton()
  if ui and ui.bonusButton then
    ui.bonusButton:show()
  end
end

function hideBonusButton()
  if ui and ui.bonusButton then
    ui.bonusButton:hide()
  end
end

function setBonusTooltip(tooltip)
  if ui and ui.bonusButton then
    ui.bonusButton:setTooltip(tooltip)
  end
end

function setBonusIcon(iconPath)
  if ui and ui.bonusButton then
    ui.bonusButton:setIcon(iconPath)
  end
end

function setBonusOnClick(callback)
  if ui and ui.bonusButton then
    ui.bonusButton.onClick = callback
  end
end

function show()
  ui:setVisible(true)
end

function hide()
  ui:setVisible(false)
end