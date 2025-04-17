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
  troll = "/images/game/creatures/monsters/troll",
  rotworm = "/images/game/creatures/monsters/rotworm",
  amazon = "/images/game/creatures/monsters/amazon",
  spider = "/images/game/creatures/monsters/spider",
  orc = "/images/game/creatures/monsters/orc",
  minotaur = "/images/game/creatures/monsters/minotaur",
  dwarf = "/images/game/creatures/monsters/dwarf",
  elf = "/images/game/creatures/monsters/elf",
  high_orc = "/images/game/creatures/monsters/high_orc",
  default = "/images/game/creatures/monsters/troll" -- Fallback icon
}

function init()
  g_logger.info("Inicializando módulo game_tasks...")
  
  -- Try to import style with error handling
  local success, errorMsg = pcall(function()
    g_ui.importStyle('taskswindow')
  end)
  
  if not success then
    g_logger.error("Failed to import taskswindow style: " .. errorMsg)
  end
  
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
    -- Fall back for when extended opcodes are not available
    displayErrorWindow("Extended protocol feature is not available. Tasks cannot be loaded.")
  end
end

function displayErrorWindow(message)
  if tasksWindow then
    tasksWindow:destroy()
    tasksWindow = nil
    taskList = nil
  end
  
  tasksWindow = g_ui.createWidget('MainWindow', rootWidget)
  tasksWindow:setId('tasksWindow')
  tasksWindow:setText(tr('Tasks'))
  tasksWindow:setSize({width = 400, height = 150})
  
  -- Create an error label
  local errorLabel = g_ui.createWidget('UILabel', tasksWindow)
  errorLabel:setId('errorLabel')
  errorLabel:setText(message)
  errorLabel:setColor('#ff0000')
  errorLabel:setFont('verdana-11px-rounded')
  
  -- Manually position the error label at the center
  local labelSize = errorLabel:getTextSize()
  local windowSize = tasksWindow:getSize()
  
  errorLabel:setPosition({
    x = math.floor((windowSize.width - labelSize.width) / 2),
    y = math.floor((windowSize.height - labelSize.height) / 2)
  })
  
  -- Add close button
  local closeButton = g_ui.createWidget('Button', tasksWindow)
  closeButton:setId('closeButton')
  closeButton:setText(tr('Close'))
  closeButton:setWidth(90)
  closeButton:setPosition({
    x = math.floor((windowSize.width - 90) / 2),
    y = windowSize.height - 40
  })
  
  closeButton.onClick = function()
    tasksWindow:destroy()
    tasksWindow = nil
    taskList = nil
  end
  
  tasksButton:setOn(true)
  
  tasksWindow.onDestroy = function()
    tasksButton:setOn(false)
    tasksWindow = nil
    taskList = nil
  end
end

function onTaskData(data)
  -- Process task data received from server
  g_logger.info("Received task data from server")
  
  -- Print data structure for debugging
  local dataStr = ""
  for k, v in pairs(data) do
    dataStr = dataStr .. k .. ", "
  end
  g_logger.info("Data keys: " .. dataStr)
  
  -- Check if we have availableTasks in the expected format
  if data.availableTasks then
    g_logger.info("Processing availableTasks")
    
    -- Check if it's already in the proper format (with normal/daily categories)
    if type(data.availableTasks) == "table" and (data.availableTasks.normal or data.availableTasks.daily) then
      availableTasks = data.availableTasks
      g_logger.info("availableTasks is properly categorized")
    else
      -- If it's just an array, organize it into normal tasks
      g_logger.info("Converting task array to categorized format")
      availableTasks = {
        normal = data.availableTasks,
        daily = data.dailyTasks or {}
      }
    end
    
    -- Count tasks for debugging
    local normalCount = availableTasks.normal and #availableTasks.normal or 0
    local dailyCount = availableTasks.daily and #availableTasks.daily or 0
    g_logger.info("Task counts - Normal: " .. normalCount .. ", Daily: " .. dailyCount)
  else
    g_logger.error("No availableTasks in data")
    -- Create empty structure if no data
    availableTasks = {
      normal = {},
      daily = {}
    }
  end
  
  -- Handle currentTasks similarly
  if data.currentTasks then
    g_logger.info("Processing currentTasks")
    
    if type(data.currentTasks) == "table" and (data.currentTasks.normal or data.currentTasks.daily) then
      currentTasks = data.currentTasks
    else
      currentTasks = {
        normal = data.currentTasks,
        daily = data.dailyCurrentTasks or {}
      }
    end
  else
    g_logger.error("No currentTasks in data")
    currentTasks = {
      normal = {},
      daily = {}
    }
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
  
  -- Create tasks window
  tasksWindow = g_ui.createWidget('TasksWindow', rootWidget)
  
  -- Update current task points
  local currentPointsLabel = tasksWindow:getChildById('currentTaskPoints')
  if currentPointsLabel then
    currentPointsLabel:setText(tr('Current Tasks Points: %s', taskPoints))
  end
  
  -- Get task list and scrollbar
  taskList = tasksWindow:recursiveGetChildById('taskList')
  local taskListScrollBar = tasksWindow:recursiveGetChildById('taskListScrollBar')
  
  -- Check if taskList was found
  if not taskList then
    g_logger.error("Failed to get taskList widget")
    return
  end
  
  g_logger.info("Found taskList widget: " .. tostring(taskList:getId()))
  
  -- Setup scrollbar connection - don't use setVerticalScrollBar directly
  if taskListScrollBar then
    g_logger.info("Setting up scrollbar connection")
    
    -- First try to check what scrollbar methods are available
    local hasSetValue = type(taskListScrollBar.setValue) == "function"
    local hasSetRange = type(taskListScrollBar.setRange) == "function"
    local canHandleScrollChange = type(taskList.onScrollChange) ~= "nil"
    local canSetScrollBarValue = type(taskList.setVerticalScrollBarValue) == "function"
    
    g_logger.info("Scrollbar capabilities: setValue=" .. tostring(hasSetValue) .. 
                  ", setRange=" .. tostring(hasSetRange) .. 
                  ", canHandleScrollChange=" .. tostring(canHandleScrollChange) ..
                  ", canSetScrollBarValue=" .. tostring(canSetScrollBarValue))
    
    -- Connect scrollbar value changes to update task list if methods are available
    if hasSetValue and canSetScrollBarValue then
      connect(taskListScrollBar, { onValueChange = function(scrollbar, value)
        taskList:setVerticalScrollBarValue(value)
      end })
    end
    
    -- Update scrollbar when task list scrolls
    if hasSetValue and canHandleScrollChange then
      connect(taskList, { onScrollChange = function(widget, value)
        taskListScrollBar:setValue(value)
      end })
    end
    
    -- Set scrollbar range based on task list size if method is available
    if hasSetRange then
      local childCount = taskList:getChildCount() or 0
      taskListScrollBar:setRange(0, math.max(0, childCount * 30 - taskList:getHeight()))
    end
  else
    g_logger.error("Failed to get taskListScrollBar widget")
  end
  
  -- Populate task list
  populateTaskList()
  
  -- Set first task as selected if available
  if taskList:getChildCount() > 0 then
    -- Check if the selection methods exist
    if type(taskList.selectChild) == "function" and type(taskList.getFirstChild) == "function" then
      local firstChild = taskList:getFirstChild()
      if firstChild then
        taskList:selectChild(firstChild)
        if type(taskList.getFocusChild) == "function" then
          local focusedChild = taskList:getFocusChild()
          if focusedChild and focusedChild.task then
            selectedTask = focusedChild.task
            updateTaskDetails(selectedTask)
          else
            g_logger.error("Could not get task from focused child")
            -- Fallback: use the first child's task directly
            if firstChild.task then
              selectedTask = firstChild.task
              updateTaskDetails(selectedTask)
            end
          end
        else
          -- Fallback: use the first child's task directly
          if firstChild.task then
            selectedTask = firstChild.task
            updateTaskDetails(selectedTask)
          end
        end
      else
        g_logger.error("getFirstChild returned nil")
      end
    else
      g_logger.error("selectChild or getFirstChild method not available")
      -- Fallback: try to get the first child directly
      local children = taskList:getChildren()
      if children and #children > 0 then
        selectedTask = children[1].task
        updateTaskDetails(selectedTask)
      end
    end
  else
    g_logger.info("No tasks to select")
  end
  
  -- Setup task list selection callback (if supported)
  if type(taskList.onChildFocusChange) ~= "nil" then
    taskList.onChildFocusChange = function(self, focusedChild)
      if focusedChild == nil then return end
      if focusedChild.task then
        selectedTask = focusedChild.task
        updateTaskDetails(selectedTask)
      end
    end
  else
    -- Alternative: try to set up a click handler on each task item
    for _, child in pairs(taskList:getChildren()) do
      if child and type(child.onClick) ~= "nil" then
        child.onClick = function()
          selectedTask = child.task
          updateTaskDetails(selectedTask)
        end
      end
    end
  end
  
  -- Setup window destroy callback
  tasksWindow.onDestroy = function()
    tasksButton:setOn(false)
    tasksWindow = nil
    taskList = nil
  end
  
  tasksButton:setOn(true)
end

function filterTasks()
  if not tasksWindow then return end
  if not taskList then return end
  
  local searchTextWidget = tasksWindow:recursiveGetChildById('searchText')
  if not searchTextWidget then return end
  
  local searchText = searchTextWidget:getText():lower()
  local visibleCount = 0
  
  for _, child in pairs(taskList:getChildren()) do
    local task = child.task
    if task then
      if searchText == "" then
        child:setVisible(true)
        visibleCount = visibleCount + 1
      else
        local monsterStr = ""
        if task.monsters then
          for _, monster in ipairs(task.monsters) do
            monsterStr = monsterStr .. monster .. " "
          end
        end
        
        local fullText = (task.name or "") .. " " .. monsterStr
        fullText = fullText:lower()
        
        if fullText:find(searchText) then
          child:setVisible(true)
          visibleCount = visibleCount + 1
        else
          child:setVisible(false)
        end
      end
    end
  end
  
  -- Update scrollbar range if possible
  local scrollBar = tasksWindow:recursiveGetChildById('taskListScrollBar')
  if scrollBar and type(scrollBar.setRange) == "function" then
    scrollBar:setRange(0, math.max(0, visibleCount * 30 - taskList:getHeight()))
  end
end

function populateTaskList()
  if not taskList then 
    g_logger.error("Task list is nil in populateTaskList")
    return 
  end
  
  taskList:destroyChildren()
  g_logger.info("Populating task list...")
  
  -- Add normal tasks
  if availableTasks.normal then
    g_logger.info("Adding normal tasks: " .. tostring(#availableTasks.normal))
    for i, task in ipairs(availableTasks.normal) do
      g_logger.info("Adding normal task " .. i .. ": " .. (task.name or "Unknown"))
      local widget = addTaskToList(task)
      if widget then
        g_logger.info("Added widget for task " .. task.name)
      else
        g_logger.error("Failed to add widget for task " .. task.name)
      end
    end
  else
    g_logger.warn("No normal tasks available")
  end
  
  -- Add daily tasks
  if availableTasks.daily then
    g_logger.info("Adding daily tasks: " .. tostring(#availableTasks.daily))
    for i, task in ipairs(availableTasks.daily) do
      g_logger.info("Adding daily task " .. i .. ": " .. (task.name or "Unknown"))
      local widget = addTaskToList(task)
      if widget then
        g_logger.info("Added widget for task " .. task.name)
      else
        g_logger.error("Failed to add widget for task " .. task.name)
      end
    end
  else
    g_logger.warn("No daily tasks available")
  end
  
  g_logger.info("Task list populated with " .. tostring(taskList:getChildCount()) .. " tasks")
end

function addTaskToList(task)
  if not taskList then return nil end
  
  local taskWidget = g_ui.createWidget('TaskLabel', taskList)
  if not taskWidget then
    g_logger.error("Failed to create TaskLabel widget")
    return nil
  end
  
  local baseText = task.name or "Unknown Task"
  if task.level then
    baseText = baseText .. "\nLevel " .. task.level
  end
  
  taskWidget:setText(baseText)
  taskWidget:setTextOffset({x = 45, y = 5}) -- Ajustado o offset do texto para dar mais espaço ao ícone
  
  -- Store reference to task data
  taskWidget.task = task
  
  -- Check if this is a daily task
  local isDaily = false
  if task.name and task.name:lower():find("daily") then
    isDaily = true
    if type(taskWidget.addState) == "function" then
      pcall(function() taskWidget:addState("daily") end)
    end
  end
  
  -- Extract monster name from task name for daily tasks
  local monsterName = nil
  if isDaily then
    local words = {}
    for word in task.name:gmatch("%w+") do
      table.insert(words, word:lower())
    end
    
    if #words >= 2 then
      monsterName = words[2]
      g_logger.info("Extracted monster name from daily task: " .. monsterName)
    end
  end
  
  -- Set icon based on monster type
  local iconKey = nil
  
  if task.monsters and #task.monsters > 0 then
    iconKey = task.monsters[1]:lower()
  elseif monsterName then
    iconKey = monsterName
  end
  
  if iconKey then
    local iconSource = taskIcons[iconKey] or taskIcons.default
    if iconSource then
      if not iconSource:find(".png") then
        iconSource = iconSource .. ".png"
      end
      
      g_logger.info("Setting icon for task " .. task.name .. " to " .. iconSource)
      
      -- Configurar o ícone com tamanho e posição adequados
      pcall(function()
        taskWidget:setImageSource(iconSource)
        taskWidget:setImageSize({width = 32, height = 32}) -- Definindo tamanho fixo para o ícone
        taskWidget:setImageOffset({x = 5, y = 5}) -- Ajustando a posição do ícone
        taskWidget:setImageColor("#FFFFFF") -- Garantindo que a imagem está visível
      end)
    end
  end
  
  -- Mark recommended tasks
  if task.recommended then
    if type(taskWidget.addState) == "function" then
      pcall(function() taskWidget:addState("recommended") end)
    end
    taskWidget:setText(baseText .. "\nRecommended")
  end
  
  -- Update scrollbar range if possible
  local scrollBar = tasksWindow:recursiveGetChildById('taskListScrollBar')
  if scrollBar and type(scrollBar.setRange) == "function" then
    local childCount = taskList:getChildCount() or 0
    scrollBar:setRange(0, math.max(0, childCount * 30 - taskList:getHeight()))
  end
  
  return taskWidget
end

function updateTaskDetails(task)
  if not tasksWindow or not task then 
    g_logger.warn("Cannot update task details: no window or task")
    return 
  end
  
  g_logger.info("Updating task details for: " .. (task.name or "Unknown Task"))
  
  -- Verify that we have all required panels first
  local rewardsPanel = tasksWindow:getChildById('rewardsPanel')
  local monstersPanel = tasksWindow:getChildById('monstersPanel')
  local killsPanel = tasksWindow:getChildById('killsPanel')
  
  if not rewardsPanel then
    g_logger.error("Could not find rewardsPanel")
  end
  
  if not monstersPanel then
    g_logger.error("Could not find monstersPanel")
  end
  
  if not killsPanel then
    g_logger.error("Could not find killsPanel")
  end
  
  -- Update rewards if we have the rewards panel
  if rewardsPanel then
    local taskPointsLabel = rewardsPanel:getChildById('taskPointsLabel')
    local experienceLabel = rewardsPanel:getChildById('experienceLabel')
    local goldLabel = rewardsPanel:getChildById('goldLabel')
    local itemsLabel = rewardsPanel:getChildById('itemsLabel')
    local accessLabel = rewardsPanel:getChildById('accessLabel')
    local teleportLabel = rewardsPanel:getChildById('teleportLabel')
    
    -- Ensure we have all required labels
    if not (taskPointsLabel and experienceLabel and goldLabel and 
            itemsLabel and accessLabel and teleportLabel) then
      g_logger.error("Could not find all required labels in rewardsPanel")
    else
      -- Update reward information
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
    end
  end
  
  -- Update monsters if we have the monsters panel
  if monstersPanel then
    monstersPanel:destroyChildren()
    
    if task.monsters then
      local x = 10
      for _, monster in ipairs(task.monsters) do
        -- Try to create a creature widget or use an icon as fallback
        local monsterWidget = nil
        local success = pcall(function()
          monsterWidget = g_ui.createWidget('UICreature', monstersPanel)
          monsterWidget:setCreature(monster)
        end)
        
        if not success or not monsterWidget then
          -- Fallback to just an icon
          monsterWidget = g_ui.createWidget('UIWidget', monstersPanel)
          monsterWidget:setSize({width = 32, height = 32})
          
          -- Try to set an icon
          local monsterIcon = taskIcons[monster:lower()] or taskIcons.default
          if monsterIcon then
            if not monsterIcon:find(".png") then
              monsterIcon = monsterIcon .. ".png"
            end
            monsterWidget:setImageSource(monsterIcon)
          end
        end
        
        -- Position the widget
        if monsterWidget then
          monsterWidget:setMarginLeft(x)
          monsterWidget:setMarginTop(10)
          x = x + 40
        end
      end
    end
  end
  
  -- Update required kills if we have the kills panel
  if killsPanel then
    local killsRequired = killsPanel:getChildById('killsRequired')
    local killsProgress = killsPanel:getChildById('killsProgress')
    local bonusLabel = killsPanel:getChildById('bonusLabel')
    
    if not (killsRequired and killsProgress and bonusLabel) then
      g_logger.error("Could not find all required widgets in killsPanel")
    else
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
      
      -- Update bonuses
      bonusLabel:setText(task.bonus or tr("No Bonuses"))
    end
    
    -- Update start button text based on status
    local startTaskButton = tasksWindow:getChildById('startTaskButton')
    if startTaskButton then
      if isStarted then
        startTaskButton:setText(tr("In Progress"))
        startTaskButton:setEnabled(false)
      else
        startTaskButton:setText(tr("Start Task"))
        startTaskButton:setEnabled(true)
      end
    end
  end
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