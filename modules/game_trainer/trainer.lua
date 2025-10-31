local config = {
  checkBlanks = true, -- check if player have blank runes to conjure runes
  blankId = 3147,
  checkSoul = true, -- check if player have enough soul to conjure runes
  loopInterval = 5, -- seconds, check mana to make runes
  eatInterval = 30, -- seconds, search for food interval
  defaultSayChannel = 1, -- channel id
  useHotkey = true, -- if your server doesn't allow using items thru hotkeys, set to false // if false, it will search for food only in opened containers
}

local foodIds = {
  -- start with common foods ids, to save some resources..
  3607, 3592, 3600, 3601, 3725, 3582, 3577, 3578, 3583, 3723, 3731, 3732, 3595, 3593,
  -- rarest foods (review needed)
  841,904,22187,3726,3730,6392,6544,23535,32404,3601,6541,3586,3594,3578,24960,836,6393,24395,6545,3250,21143,3587,22185,11681,21145,10453,24394,20310,3723,3731,169,17821,13992,17820,7375,3588,21144,15795,14681,8010,3602,14085,3583,3591,21146,3579,23545,8011,11683,11682,14084,7376,3595,11461,6569,8012,3727,3732,16103,10329,3724,3728,9537,8013,8197,7158,8194,7377,901,3606,17457,6500,3599,3607,3584,3592,12310,3580,8016,8015,8014,6277,24408,7374,7373,3581,7159,3606,11459,11460,6543,6542,3725,3729,32401,8017,3582,6278,10219,6574,8177,3596,3598,3597,3600,11462,3585,3593,3590,3577,3589,8019,5096,6125,229
}

local customSoul = { -- spell soul info taken from modules\gamelib\spells.lua, but you can set custom soul values here..
  ['adori gran'] = 3,
  ['adori gran flam'] = 4,
}

-- CONFIG END
local lastSoul = 0 -- if we dont find information about any conjureSpell, we're going to calculate previous vs current soul and consider as required.


tWindow = nil
tButton = nil
tSettingsFile = nil
tSettings = {}
tLoop = nil

-- Basic Module Functions
function init()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  tWindow = g_ui.loadUI('trainer', modules.game_interface.getRightPanel())
  tWindow:disableResize()
  tWindow:setup()

  tButton = modules.client_topmenu.addRightGameToggleButton('trainer', tr('Trainer'), '/images/topButtons/inventory', toggleWindow)
  tButton:setOn(tWindow:isVisible())

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  offline()
  destroy()
end

function online()
  load() -- load calls setOn, that calls startLoop if enabled
end

function offline()
  save()
  stopLoop()
  destroyInput()
end

-- settings
function load()
  tSettingsFile = g_resources.getWriteDir() .. "/trainer.json"
  if g_resources.fileExists(tSettingsFile) then
    local status, result = pcall(function()
      return json.decode(g_resources.readFileContents(tSettingsFile))
    end)
    if not status then
      return g_logger.error("Error while reading trainer settings file. To fix this problem you can delete storage.json. Details: " .. result)
    end
    tSettings = result
  else
    tSettings = {}
  end
  setOptions()
  setOn(tSettings.enabled,true)
end

function save()
  local status, result = pcall(function() return json.encode(tSettings, 2) end)
  if not status then
    return g_logger.error("Error while saving trainer settings. Data won't be saved. Details: " .. result)
  end

  if result:len() > 100 * 1024 * 1024 then
    return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
  end

  g_resources.writeFileContents(tSettingsFile, result)
end

-- window
function show()
  tWindow:show()
  tButton:setOn(true)
end

function hide()
  tWindow:hide()
  tButton:setOn(false)
end

function toggleWindow()
  if tWindow:isVisible() then
    hide()
  else
    show()
  end
end

function onMiniWindowClose()
  if tButton then
    tButton:setOn(false)
  end
end

-- destroy
function destroy()
  if tWindow then
    tWindow:destroy()
    tWindow = nil
  end
  if tButton then
    tButton:destroy()
    tButton = nil
  end
  destroyInput()
end

function destroyInput()
  local rw = g_ui.getRootWidget()
  if rw then
    local widget = rw['TrainerAddSpell']
    if widget then
      widget:destroy()
    end
  end
end

-- module functions
function setOn(enabled,login)
  tSettings.enabled = enabled
  local bt = tWindow:recursiveGetChildById("enableButton")
  bt:setOn(tSettings.enabled)
  stopLoop()
  if tSettings.enabled then
    if not login then
      mainLoop()
    end
    startLoop()
  end
end

function toggle()
  setOn(not tSettings.enabled)
end

-- ui functions
local checks = {'checkMT','checkRM','checkIdle','checkFood'}
local texts = {'spellMT','manaMT','spellRM','manaRM'}
function setOptions()
  -- default options
  tSettings.spellMT = tSettings.spellMT or 'utevo lux'
  tSettings.manaMT = tSettings.manaMT or '90'
  tSettings.spellRM = tSettings.spellRM or 'adori gran'
  tSettings.manaRM = tSettings.manaRM or '80'

  for e, entry in pairs(checks) do
    local box = tWindow:recursiveGetChildById(entry)
    box:setChecked(tSettings[entry])
  end
  for e, entry in pairs(texts) do
    local text = tWindow:recursiveGetChildById(entry)
    text:setText(tSettings[entry])
  end
end

function setOption(id,enabled)
  tSettings[id] = enabled
end

function inputSpell(id)
  destroyInput()

  -- create window
  tInput = g_ui.createWidget('TrainerAddSpell', g_ui.getRootWidget())
  tInput:show()
  tInput:raise()
  tInput:focus()
  tInput:setText(id == 'spellRM' and "Edit Spell for Rune Making" or "Edit Spell for Mana Training")
  
  tInput.text:setText(tSettings[id])
  tInput.text:setCursorPos(tSettings[id]:len())

  tInput.text.onTextChange = function(self, text)
    tInput.buttonOk:setEnabled(text:len() > 1)
  end

  -- functions
  local okFunc = function()
    tSettings[id] = tInput.text:getText()
    tWindow:recursiveGetChildById(id):setText(tSettings[id])
    tInput:destroy()
  end

  local cancelFunc = function()
    tInput:destroy()
  end

  -- buttons
  tInput.buttonOk.onClick = okFunc
  tInput.onEnter = okFunc
  tInput.buttonClose.onClick = cancelFunc
  tInput.onEscape = cancelFunc
end

-- loop
function startLoop()
  if tLoop or not g_game.isOnline() then
    stopLoop()
  end
  tLoop = cycleEvent(mainLoop,config.loopInterval * 1000)
end

function stopLoop()
  if tLoop then
    removeEvent(tLoop)
    tLoop = nil
  end
end

-- main
function say(text)
  g_game.talkChannel(defaultSayChannel,0,text)
end

function getSpellSoul(spell,pSoul)
  local custom = customSoul[spell:lower()]
  if custom then
    return custom
  end
  local sp = Spells.getSpellByWords(spell:lower())
  if sp and sp.soul then
    return sp.soul
  end
  if lastSoul > 0 then
    return lastSoul - pSoul
  end
  return 4 -- default soul if didnt found any information about that spell
end

local lastEat = 0

-- execute
function mainLoop()
  if not g_game.isOnline() or not tSettings.enabled then
    stopLoop()
    return
  end
  local player = g_game.getLocalPlayer()
  local set = tSettings

  -- anti idle
  if set.checkIdle then
    g_game.turn(math.random(0,3))
  end

  -- eat food
  if set.checkFood and (lastEat + config.eatInterval < g_clock.seconds()) then
    lastEat = g_clock.seconds()
    if config.useHotkey then
      for _, id in pairs(foodIds) do
        if player:getItemsCount(id) > 0 then
          g_game.useInventoryItem(id)
          break
        end
      end
    else
      for c, cont in pairs(g_game.getContainers()) do
        for i, item in ipairs(cont:getItems()) do
          if table.find(foodIds,item:getId()) then
            g_game.use(item)
            break
          end
        end
      end
    end
  end

  local pMana = (player:getMana()/player:getMaxMana()) * 100
  -- rune maker
  if set.checkRM then
    if pMana > tonumber(set.manaRM) then
      if not config.checkBlanks or player:getItemsCount(config.blankId) > 0 then
        local pSoul = player:getSoul()
        if not config.checkSoul or pSoul >= getSpellSoul(set.spellRM,pSoul) then
          lastSoul = pSoul
          return say(set.spellRM)
        end
      end
    end 
  end
  -- mana training
  if set.checkMT then
    if pMana > tonumber(set.manaMT) then
      return say(set.spellMT)
    end
  end
end