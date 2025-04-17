questLogButton = nil
questLineWindow = nil

function setupTopMenuButton()
  if not g_app.isMobile() then
    questLogButton = modules.client_topmenu.addRightGameToggleButton('questLogButton', tr('Quest Log'), '/images/topbuttons/new/questlog', 
    function()
      if (questLogWindow and questLogWindow:isVisible()) or questLineWindow then 
        if questLogWindow then questLogWindow:hide() end
        if questLineWindow then questLineWindow:destroy() end
        questLogButton:setOn(false)
      else
        g_game.requestQuestLog()
      end
    end
    , nil, nil, true)
  end
end

function init()
  g_ui.importStyle('questlogwindow')
  g_ui.importStyle('questlinewindow')
  
  connect(g_game, { onQuestLog = onGameQuestLog,
                    onQuestLine = onGameQuestLine,
                    onGameEnd = destroyWindows})
end

function terminate()
  disconnect(g_game, { onQuestLog = onGameQuestLog,
                       onQuestLine = onGameQuestLine,
                       onGameEnd = destroyWindows})

  destroyWindows()
  if questLogButton then
    questLogButton:destroy()
  end
end

function destroyWindows()
  if questLogWindow then
    questLogWindow:destroy()
  end

  if questLineWindow then
    questLineWindow:destroy()
  end
end

function onGameQuestLog(quests)
  destroyWindows()

  questLogButton:setOn(true)

  questLogWindow = g_ui.createWidget('QuestLogWindow', rootWidget)
  local questList = questLogWindow:getChildById('questList')

  for i,questEntry in pairs(quests) do
    local id, name, completed = unpack(questEntry)

    local questLabel = g_ui.createWidget('QuestLabel', questList)
    questLabel:setOn(completed)
    questLabel:setText(name)
    questLabel.onDoubleClick = function()
      questLogWindow:hide()
      g_game.requestQuestLine(id)
    end
  end

  questLogWindow.onDestroy = function()
    questLogButton:setOn(false)
    questLogWindow = nil
  end

  questList:focusChild(questList:getFirstChild())
end

function onGameQuestLine(questId, questMissions)
  if questLogWindow then questLogWindow:hide() end
  if questLineWindow then questLineWindow:destroy() end

  questLineWindow = g_ui.createWidget('QuestLineWindow', rootWidget)
  local missionList = questLineWindow:getChildById('missionList')
  local missionDescription = questLineWindow:getChildById('missionDescription')

  connect(missionList, { onChildFocusChange = function(self, focusedChild)
    if focusedChild == nil then return end
    missionDescription:setText(focusedChild.description)
  end })

  for i,questMission in pairs(questMissions) do
    local name, description = unpack(questMission)

    local missionLabel = g_ui.createWidget('MissionLabel')
    missionLabel:setText(name)
    missionLabel.description = description
    missionList:addChild(missionLabel)
  end

  questLineWindow.onDestroy = function()
    if questLogWindow then questLogWindow:show() end
    questLineWindow = nil
  end

  missionList:focusChild(missionList:getFirstChild())
end

