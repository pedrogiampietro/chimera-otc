g_logger.info("Carregando módulo game_tasks...")
g_logger.info("Inicializando módulo game_tasks...")

-- Constants
local TASK_TYPE_NORMAL = 1
local TASK_TYPE_DAILY = 2

local TASK_STATUS_AVAILABLE = 0
local TASK_STATUS_STARTED = 1
local TASK_STATUS_COMPLETED = 2

-- Define task-specific extended opcodes
local ExtendedIds = {
  TaskRequest = 100,
  TaskData = 101,
  TaskUpdate = 102,
  TaskAction = 103
}

-- Module variables
local tasksWindow
local tasksButton
local currentTasks = {}
local availableTasks = {}
local selectedTask = nil
local taskList = nil

-- Task Icons (create these icons in your client)
local taskIcons = {
  troll = "/images/game/tasks/troll",
  rotworm = "/images/game/tasks/rotworm",
  spider = "/images/game/tasks/spider",
  orc = "/images/game/tasks/orc",
  minotaur = "/images/game/tasks/minotaur",
  dwarf = "/images/game/tasks/dwarf",
  elf = "/images/game/tasks/elf",
  high_orc = "/images/game/tasks/high_orc"
}

function init()
  g_logger.info("Inicializando módulo game_tasks...")
  
  g_ui.importStyle('taskswindow')
  
  connect(g_game, { 
    onGameEnd = destroyWindow,
    onTaskData = onTaskData,
    onTaskUpdate = onTaskUpdate 
  })
  
  -- Protocol extension for tasks
  g_logger.info("Verificando GameExtendedClientPing: " .. tostring(g_game.getFeature(GameExtendedClientPing)))
  setupTopMenuButton()
  
  -- Register protocol extensions
  if ProtocolGame and ProtocolGame.registerExtendedOpcode then
    g_logger.info("Registrando opcodes estendidos...")
    ProtocolGame.registerExtendedOpcode(ExtendedIds.TaskData, onExtendedTaskData)
    ProtocolGame.registerExtendedOpcode(ExtendedIds.TaskUpdate, onExtendedTaskUpdate)
  else
    g_logger.error("ProtocolGame.registerExtendedOpcode is not available")
  end
end

function terminate()
  disconnect(g_game, { 
    onGameEnd = destroyWindow,
    onTaskData = onTaskData,
    onTaskUpdate = onTaskUpdate
  })
  
  -- Unregister protocol extensions
  if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    ProtocolGame.unregisterExtendedOpcode(ExtendedIds.TaskData)
    ProtocolGame.unregisterExtendedOpcode(ExtendedIds.TaskUpdate)
  end
  
  destroyWindow()
  
  if tasksButton then
    tasksButton:destroy()
  end
end

function destroyWindow()
  if tasksWindow then
    tasksWindow:destroy()
    tasksWindow = nil
  end
end

function setupTopMenuButton()
  g_logger.info("Configurando botão de tarefas...")
  if not g_app.isMobile() then
    g_logger.info("Não é dispositivo móvel, criando botão...")
    tasksButton = modules.client_topmenu.addRightGameToggleButton('tasksButton', tr('Tasks'), '/modules/client_topmenu/icons/tasks', 
    function()
      if tasksWindow and tasksWindow:isVisible() then
        tasksWindow:hide()
        tasksButton:setOn(false)
      else
        requestTasks()
      end
    end
    , nil, nil, true)
    g_logger.info("Botão de tarefas criado: " .. tostring(tasksButton ~= nil))
  else
    g_logger.info("É dispositivo móvel, não criando botão")
  end
end

-- Protocol extension handlers
function onExtendedTaskData(protocol, opcode, buffer)
  local data = json.decode(buffer)
  if data and type(data) == 'table' then
    onTaskData(data)
  end
end

function onExtendedTaskUpdate(protocol, opcode, buffer)
  local data = json.decode(buffer)
  if data and type(data) == 'table' then
    onTaskUpdate(data)
  end
end

function requestTasks()
  -- Request tasks data from server via extended opcode
  if g_game.getFeature(GameExtendedClientPing) then
    local protocol = g_game.getProtocolGame()
    if protocol then
      protocol:sendExtendedOpcode(ExtendedIds.TaskRequest, '{}')
    end
  else
    -- Se não tiver GameExtendedClientPing, criar uma janela básica
    g_logger.info("GameExtendedClientPing não está ativo, criando janela básica...")
    displayTasksWindow(0)
  end
end

function onTaskData(data)
  -- Process task data received from server
  if data.availableTasks then
    availableTasks = data.availableTasks
  end
  
  if data.currentTasks then
    currentTasks = data.currentTasks
  end
  
  local taskPoints = data.taskPoints or 0
  
  -- Display tasks window
  displayTasksWindow(taskPoints)
end

function onTaskUpdate(data)
  -- Update task progress
  if data.taskId and data.count and currentTasks.normal then
    -- Update task progress
    for i, task in ipairs(currentTasks.normal) do
      if task.id == data.taskId then
        task.count = data.count
        
        -- If window is open, update the UI
        if tasksWindow and tasksWindow:isVisible() and selectedTask and selectedTask.id == data.taskId then
          updateTaskDetails(selectedTask)
        end
        
        break
      end
    end
    
    -- Same for daily tasks
    if currentTasks.daily then
      for i, task in ipairs(currentTasks.daily) do
        if task.id == data.taskId then
          task.count = data.count
          
          -- If window is open, update the UI
          if tasksWindow and tasksWindow:isVisible() and selectedTask and selectedTask.id == data.taskId then
            updateTaskDetails(selectedTask)
          end
          
          break
        end
      end
    end
  end
end

function displayTasksWindow(taskPoints)
  if tasksWindow then
    tasksWindow:destroy()
  end
  
  tasksWindow = g_ui.createWidget('TasksWindow', rootWidget)
  if not tasksWindow then
    g_logger.error("Não foi possível criar a janela de tarefas")
    return
  end
  
  -- Se não tiver GameExtendedClientPing, mostrar mensagem
  if not g_game.getFeature(GameExtendedClientPing) then
    local mainPanel = tasksWindow:getChildById('mainPanel')
    if mainPanel then
      local messageLabel = g_ui.createWidget('Label', mainPanel)
      messageLabel:setText("Sistema de tarefas não está disponível.\nO servidor não suporta esta funcionalidade.")
      messageLabel:setTextAlign(AlignCenter)
      messageLabel:setColor('#ff0000')
      messageLabel:setMarginTop(50)
    end
    return
  end
  
  taskList = tasksWindow:recursiveGetChildById('taskList')
  if not taskList then
    g_logger.error("Não foi possível encontrar o taskList")
    return
  end
  
  -- Update current task points
  local currentPointsLabel = tasksWindow:recursiveGetChildById('currentTaskPoints')
  if currentPointsLabel then
    currentPointsLabel:setText(tr('Current Tasks Points: %s', taskPoints))
  end
  
  -- Populate task list
  populateTaskList()
  
  -- Set first task as selected
  if taskList:getChildCount() > 0 then
    taskList:selectChild(taskList:getFirstChild())
    if taskList:getFocusChild() then
      selectedTask = taskList:getFocusChild().task
      updateTaskDetails(selectedTask)
    end
  end
  
  -- Setup task list selection callback
  taskList.onChildFocusChange = function(self, focusedChild)
    if focusedChild == nil then return end
    selectedTask = focusedChild.task
    updateTaskDetails(selectedTask)
  end
  
  tasksWindow.onDestroy = function()
    if tasksButton then
      tasksButton:setOn(false)
    end
    tasksWindow = nil
    taskList = nil
  end
  
  if tasksButton then
    tasksButton:setOn(true)
  end
end

function filterTasks()
  if not tasksWindow then return end
  
  local taskList = tasksWindow:recursiveGetChildById('taskList')
  if not taskList then return end
  
  local searchText = tasksWindow:recursiveGetChildById('searchText')
  if not searchText then return end
  
  local searchQuery = searchText:getText():lower()
  
  for _, child in pairs(taskList:getChildren()) do
    if child and child.task then
      if searchQuery == "" then
        child:setVisible(true)
      else
        local monsterStr = ""
        if child.task.monsters then
          for _, monster in ipairs(child.task.monsters) do
            monsterStr = monsterStr .. monster .. " "
          end
        end
        
        local fullText = (child.task.name or "") .. " " .. monsterStr
        fullText = fullText:lower()
        
        child:setVisible(fullText:find(searchQuery) and true or false)
      end
    end
  end
end

function populateTaskList()
  taskList:destroyChildren()
  
  -- Add normal tasks
  if availableTasks.normal then
    for _, task in ipairs(availableTasks.normal) do
      addTaskToList(task)
    end
  end
  
  -- Add daily tasks
  if availableTasks.daily then
    for _, task in ipairs(availableTasks.daily) do
      addTaskToList(task)
    end
  end
end

function addTaskToList(task)
  local taskWidget = g_ui.createWidget('TaskLabel', taskList)
  
  local baseText = task.name or "Unknown Task"
  if task.level then
    baseText = baseText .. "\nLevel " .. task.level
  end
  
  taskWidget:setText(baseText)
  
  -- Store reference to task data
  taskWidget.task = task
  
  -- Set icon based on task monster type (example using first monster)
  if task.monsters and #task.monsters > 0 then
    local monster = task.monsters[1]:lower()
    local iconSource = taskIcons[monster]
    if iconSource then
      taskWidget:setImageSource(iconSource)
    end
  end
  
  -- Mark recommended tasks
  if task.recommended then
    taskWidget:addState("recommended")
    taskWidget:setText(baseText .. "\nRecommended")
  end
  
  return taskWidget
end

function updateTaskDetails(task)
  if not tasksWindow or not task then return end
  
  -- Update rewards
  local rewardsPanel = tasksWindow:getChildById('rewardsPanel')
  local taskPointsLabel = rewardsPanel:getChildById('taskPointsLabel')
  local experienceLabel = rewardsPanel:getChildById('experienceLabel')
  local goldLabel = rewardsPanel:getChildById('goldLabel')
  local itemsLabel = rewardsPanel:getChildById('itemsLabel')
  local accessLabel = rewardsPanel:getChildById('accessLabel')
  local teleportLabel = rewardsPanel:getChildById('teleportLabel')
  
  if task.reward then
    taskPointsLabel:setText(tr('Tasks Points: %s', task.reward.points or 1))
    experienceLabel:setText(tr('Experience: %s', task.reward.exp or 0))
    goldLabel:setText(tr('Gold: %s', task.reward.gold or 0))
    
    local itemText = ""
    if task.reward.items then
      for _, item in ipairs(task.reward.items) do
        if item.name then
          itemText = item.name
          break
        end
      end
    end
    itemsLabel:setText(itemText ~= "" and itemText or "None")
    
    accessLabel:setText(task.reward.access or "None")
    teleportLabel:setText(task.reward.teleport or "None")
  else
    taskPointsLabel:setText(tr('Tasks Points: 1'))
    experienceLabel:setText(tr('Experience: 0'))
    goldLabel:setText(tr('Gold: 0'))
    itemsLabel:setText("None")
    accessLabel:setText("None")
    teleportLabel:setText("None")
  end
  
  -- Update monsters
  local monstersPanel = tasksWindow:getChildById('monstersPanel')
  monstersPanel:destroyChildren()
  
  if task.monsters then
    local x = 10
    for _, monster in ipairs(task.monsters) do
      local monsterIcon = g_ui.createWidget('UICreature', monstersPanel)
      monsterIcon:setCreature(monster)
      monsterIcon:setMarginLeft(x)
      monsterIcon:setMarginTop(10)
      x = x + 40
    end
  end
  
  -- Update required kills
  local killsPanel = tasksWindow:getChildById('killsPanel')
  local killsRequired = killsPanel:getChildById('killsRequired')
  local killsProgress = killsPanel:getChildById('killsProgress')
  local bonusLabel = killsPanel:getChildById('bonusLabel')
  
  killsRequired:setText(tostring(task.count or 0))
  
  -- Check if task is in progress
  local currentCount = 0
  local isStarted = false
  
  -- Look in both normal and daily tasks
  if currentTasks.normal then
    for _, currentTask in ipairs(currentTasks.normal) do
      if currentTask.id == task.id then
        currentCount = currentTask.count or 0
        isStarted = true
        break
      end
    end
  end
  
  if not isStarted and currentTasks.daily then
    for _, currentTask in ipairs(currentTasks.daily) do
      if currentTask.id == task.id then
        currentCount = currentTask.count or 0
        isStarted = true
        break
      end
    end
  end
  
  -- Update progress bar
  local taskCount = task.count or 100
  local progressPercent = math.min(100, math.floor((currentCount / taskCount) * 100))
  killsProgress:setPercent(progressPercent)
  
  -- Update start button text based on status
  local startTaskButton = tasksWindow:getChildById('startTaskButton')
  if isStarted then
    startTaskButton:setText(tr("In Progress"))
    startTaskButton:setEnabled(false)
  else
    startTaskButton:setText(tr("Start Task"))
    startTaskButton:setEnabled(true)
  end
  
  -- Update bonuses
  bonusLabel:setText(task.bonus or tr("No Bonuses"))
end

function startTask()
  if not selectedTask then return end
  
  -- Send task start request to server
  if g_game.getFeature(GameExtendedClientPing) then
    local protocol = g_game.getProtocolGame()
    if protocol then
      local data = {
        action = "start",
        taskId = selectedTask.id
      }
      protocol:sendExtendedOpcode(ExtendedIds.TaskAction, json.encode(data))
    end
  end
end 