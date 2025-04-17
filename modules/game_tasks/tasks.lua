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
  high_orc = "/images/game/creatures/monsters/orcberserker",
  default = "/images/game/creatures/monsters/troll" -- Mudando o fallback para troll ao invés de default
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
  
  -- Initialize task structures with the correct format
  availableTasks = {
    normal = {
      {
        id = 1,
        name = "Rat Extermination",
        count = 24,
        required = 20,
        status = "in_progress",
        monsters = {"rat"},
        level = 1
      },
      {
        id = 2,
        name = "Spider Hunter",
        count = 1,
        required = 25,
        status = "in_progress",
        monsters = {"spider"},
        level = 5
      },
      {
        id = 3,
        name = "Orc Slayer",
        count = 40,
        required = 40,
        status = "completed",
        monsters = {"orc"},
        level = 10
      }
    },
    daily = {
      {
        id = 101,
        name = "Daily Rotworm Hunt",
        count = 0,
        required = 15,
        status = "in_progress",
        monsters = {"rotworm"},
        level = 8
      },
      {
        id = 103,
        name = "Daily Amazon Raid",
        count = 0,
        required = 25,
        status = "in_progress",
        monsters = {"amazon"},
        level = 20
      },
      {
        id = 102,
        name = "Daily Minotaur Cleansing",
        count = 0,
        required = 20,
        status = "in_progress",
        monsters = {"minotaur"},
        level = 15
      },
      {
        id = 104,
        name = "Daily Dragon Lair",
        count = 0,
        required = 15,
        status = "in_progress",
        monsters = {"dragon"},
        level = 25
      },
      {
        id = 105,
        name = "Daily Orc Fortress",
        count = 0,
        required = 35,
        status = "in_progress",
        monsters = {"orc"},
        level = 30
      }
    }
  }
  
  -- Copy available tasks to current tasks since they're all in progress
  currentTasks = {
    normal = {},
    daily = {}
  }
  
  -- Deep copy normal tasks that are in progress or completed
  for _, task in ipairs(availableTasks.normal) do
    if task.status == "in_progress" or task.status == "completed" then
      local taskCopy = {}
      for k, v in pairs(task) do
        taskCopy[k] = v
      end
      table.insert(currentTasks.normal, taskCopy)
    end
  end
  
  -- Deep copy daily tasks that are in progress
  for _, task in ipairs(availableTasks.daily) do
    if task.status == "in_progress" then
      local taskCopy = {}
      for k, v in pairs(task) do
        taskCopy[k] = v
      end
      table.insert(currentTasks.daily, taskCopy)
    end
  end
  
  -- Count tasks for debugging
  local normalCount = #availableTasks.normal
  local dailyCount = #availableTasks.daily
  g_logger.info("Task counts - Normal: " .. normalCount .. ", Daily: " .. dailyCount)
  
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
  tasksWindow:setVisible(true)
  
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
  
  -- Configure taskList for scrolling
  if taskList then
    -- Make sure taskList is visible and has proper size
    taskList:setVisible(true)
    
    -- Enable vertical scrolling
    if type(taskList.setVerticalScrollBar) == "function" then
      taskList:setVerticalScrollBar(taskListScrollBar)
    end
    if type(taskList.setVerticalScrolling) == "function" then
      taskList:setVerticalScrolling(true)
    end
    
    -- Set proper size for taskList
    if type(taskList.setSize) == "function" then
      local windowSize = tasksWindow:getSize()
      if windowSize then
        taskList:setSize({width = windowSize.width - 40, height = windowSize.height - 100})
      else
        taskList:setSize({width = 300, height = 400})
      end
    end
  end
  
  -- Create a container for all tasks
  local taskContainer = g_ui.createWidget('ScrollablePanel', taskList)
  taskContainer:setId('taskContainer')
  taskContainer:setFocusable(false)
  taskContainer:setVisible(true)
  
  -- Set initial container size to match taskList
  if type(taskContainer.setSize) == "function" and type(taskList.getSize) == "function" then
    local listSize = taskList:getSize()
    taskContainer:setSize({width = listSize.width - 20, height = 0}) -- Height will be adjusted after adding tasks
  end
  
  -- Populate task list into the container
  populateTaskList()
  
  -- After populating, update container height and scrollbar
  if taskListScrollBar then
    local totalContentHeight = 0
    local itemHeight = 60  -- Height of each task item
    local headerHeight = 30  -- Height of section headers
    local itemMargin = 15  -- Margin between items
    
    -- Calculate total content height
    if availableTasks.normal then
      totalContentHeight = totalContentHeight + headerHeight -- Normal Tasks header
      totalContentHeight = totalContentHeight + (#availableTasks.normal * (itemHeight + itemMargin))
    end
    
    if availableTasks.daily then
      totalContentHeight = totalContentHeight + headerHeight -- Daily Tasks header
      totalContentHeight = totalContentHeight + (#availableTasks.daily * (itemHeight + itemMargin))
    end
    
    -- Add some padding at the bottom
    totalContentHeight = totalContentHeight + 20
    
    -- Update container height
    if type(taskContainer.setSize) == "function" then
      local currentSize = taskContainer:getSize()
      taskContainer:setSize({width = currentSize.width, height = totalContentHeight})
    end
    
    -- Configure scrollbar
    if type(taskListScrollBar.setVisible) == "function" then
      taskListScrollBar:setVisible(true)
    end
    
    if type(taskListScrollBar.setMinimum) == "function" then
      taskListScrollBar:setMinimum(0)
    end
    
    if type(taskListScrollBar.setMaximum) == "function" then
      local visibleHeight = taskList:getHeight() or 400
      local maxScroll = math.max(0, totalContentHeight - visibleHeight)
      taskListScrollBar:setMaximum(maxScroll)
      taskListScrollBar:setValue(0)
    end
  end
  
  -- Set first task as selected if available
  local children = {}
  if type(taskContainer.getChildren) == "function" then
    children = taskContainer:getChildren()
  end
  
  if children and #children > 0 then
    -- Find the first non-header task item
    for _, child in ipairs(children) do
      if child.task then
        selectedTask = child.task
        updateTaskDetails(selectedTask)
        -- Highlight the selected task using proper UI methods
        if type(child.setBackgroundColor) == "function" then
          child:setBackgroundColor('#444444')
        end
        if type(child.setColor) == "function" then
          child:setColor('#ffffff')
        end
        break
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

  -- Get or create the task container
  local taskContainer = taskList:getChildById('taskContainer')
  if not taskContainer then
    taskContainer = g_ui.createWidget('TaskContainer', taskList)
    taskContainer:setId('taskContainer')
  end

  -- Make sure the container is visible and properly sized
  taskContainer:setVisible(true)
  taskContainer:setSize({width = taskList:getWidth() - 20, height = 0}) -- Height will be adjusted later

  -- Manual positioning variables
  local itemHeight = 60  -- Height of each task item
  local headerHeight = 30  -- Height of section headers
  local itemMargin = 2  -- Reduced margin between items
  local itemCount = 0  -- Counter for alternating background colors

  -- Função auxiliar para verificar o status da task
  local function getTaskStatus(taskId)
    -- Verificar em normal tasks
    if currentTasks.normal then
      for _, task in ipairs(currentTasks.normal) do
        if task.id == taskId then
          if task.count >= (task.required or 0) then
            return "completed"
          else
            return "in_progress"
          end
        end
      end
    end
    
    -- Verificar em daily tasks
    if currentTasks.daily then
      for _, task in ipairs(currentTasks.daily) do
        if task.id == taskId then
          if task.count >= (task.required or 0) then
            return "completed"
          else
            return "in_progress"
          end
        end
      end
    end
    
    return "available"
  end

  -- Função auxiliar para criar cabeçalho de seção
  local function createSectionHeader(text)
    local header = g_ui.createWidget('TaskLabel', taskContainer)
    header:setText(text)
    header:setColor('#ffff00') -- Amarelo para destacar
    header:setVisible(true)
    header:setHeight(headerHeight)
    header:setTextAlign(AlignLeft)
    header:setFont('verdana-11px-rounded')
    header:setMarginTop(5)
    header:setMarginBottom(5)
    
    return header
  end

  -- Adicionar tasks normais
  local normalHeader = createSectionHeader("Normal Tasks")
  if normalHeader then
    normalHeader:setEnabled(false) -- Desabilita interação com o header
  end
  
  if availableTasks.normal then
    g_logger.info("Adding normal tasks: " .. tostring(#availableTasks.normal))
    for i, task in ipairs(availableTasks.normal) do
      g_logger.info("Adding normal task " .. i .. ": " .. (task.name or "Unknown"))
      local widget = addTaskToList(task, taskContainer, itemCount % 2 == 0)
      itemCount = itemCount + 1
      if widget then
        local status = getTaskStatus(task.id)
        if status == "completed" then
          widget:setText(widget:getText() .. " [Completed]")
        elseif status == "in_progress" then
          widget:setText(widget:getText() .. " [In Progress]")
        end
      else
        g_logger.error("Failed to add widget for task " .. task.name)
      end
    end
  else
    g_logger.warn("No normal tasks available")
  end

  -- Add extra spacing between sections
  local spacer = g_ui.createWidget('UIWidget', taskContainer)
  spacer:setHeight(10)
  spacer:setPhantom(true)

  -- Adicionar tasks diárias
  local dailyHeader = createSectionHeader("Daily Tasks")
  if dailyHeader then
    dailyHeader:setEnabled(false) -- Desabilita interação com o header
  end
  
  if availableTasks.daily then
    g_logger.info("Adding daily tasks: " .. tostring(#availableTasks.daily))
    for i, task in ipairs(availableTasks.daily) do
      g_logger.info("Adding daily task " .. i .. ": " .. (task.name or "Unknown"))
      local widget = addTaskToList(task, taskContainer, itemCount % 2 == 0)
      itemCount = itemCount + 1
      if widget then
        local status = getTaskStatus(task.id)
        if status == "completed" then
          widget:setText(widget:getText() .. " [Completed]")
        elseif status == "in_progress" then
          widget:setText(widget:getText() .. " [In Progress]")
        end
      else
        g_logger.error("Failed to add widget for task " .. task.name)
      end
    end
  else
    g_logger.warn("No daily tasks available")
  end

  -- Update container height based on content
  local totalHeight = (itemCount * (itemHeight + itemMargin)) + (2 * headerHeight) + 40
  taskContainer:setHeight(totalHeight)
  
  g_logger.info("Task list populated with " .. tostring(taskContainer:getChildCount()) .. " tasks")
  
  -- Setup click handlers for all tasks
  local children = taskContainer:getChildren()
  for _, child in pairs(children) do
    if child.task then
      child.onClick = function()
        -- Reset all tasks to default appearance
        for _, otherChild in pairs(children) do
          if otherChild.task then
            otherChild:setBackgroundColor(otherChild == child and '#444444' or '#00000000')
            otherChild:setColor(otherChild == child and '#ffffff' or '#aaaaaa')
          end
        end
        
        -- Update selected task and details
        selectedTask = child.task
        updateTaskDetails(selectedTask)
      end
    end
  end
end

function addTaskToList(task, container, isEven)
  if not container then return nil end
  
  local taskWidget = g_ui.createWidget('TaskLabel', container)
  if not taskWidget then
    g_logger.debug("Failed to create TaskLabel widget")
    return nil
  end
  
  -- Make sure widget is visible and properly styled
  taskWidget:setVisible(true)
  taskWidget:setEnabled(true)
  taskWidget:setFocusable(true)
  taskWidget:setHeight(60)
  taskWidget:setMarginTop(1)
  taskWidget:setMarginBottom(1)
  
  local baseText = task.name or "Unknown Task"
  if task.level then
    baseText = baseText .. "\nLevel " .. task.level
  end
  
  taskWidget:setText(baseText)
  taskWidget:setTextAlign(AlignLeft)
  
  -- Set text offset to make room for the icon
  taskWidget:setTextOffset({x = 45, y = 5})
  
  -- Add alternating background colors
  taskWidget:setBackgroundColor(isEven and '#33333366' or '#44444466')
  
  -- Store reference to task data
  taskWidget.task = task
  
  -- Set size to match container width
  taskWidget:setSize({width = container:getWidth() - 20, height = 60})
  
  -- Check if this is a daily task
  local isDaily = false
  if task.name and task.name:lower():find("daily") then
    isDaily = true
    pcall(function() taskWidget:addState("daily") end)
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
      
      -- Tentar carregar o ícone com tratamento de erro
      pcall(function()
        taskWidget:setImageSource(iconSource)
        taskWidget:setImageSize({width = 32, height = 32})
        taskWidget:setImageOffset({x = 5, y = 5})
        taskWidget:setImageColor("#FFFFFF")
      end)
    end
  end
  
  -- Mark recommended tasks
  if task.recommended then
    pcall(function() taskWidget:addState("recommended") end)
    taskWidget:setText(baseText .. "\nRecommended")
  end
  
  return taskWidget
end

function updateTaskDetails(task)
  if not tasksWindow or not task then 
    g_logger.debug("Cannot update task details: no window or task") -- Mudando de warn para debug
    return 
  end
  
  g_logger.debug("Updating task details for: " .. (task.name or "Unknown Task")) -- Mudando de info para debug
  
  -- Verify that we have all required panels first
  local rewardsPanel = tasksWindow:recursiveGetChildById('rewardsPanel')
  local monstersPanel = tasksWindow:recursiveGetChildById('monstersPanel')
  local killsPanel = tasksWindow:recursiveGetChildById('killsPanel')
  
  if not rewardsPanel then
    g_logger.debug("Could not find rewardsPanel") -- Mudando de error para debug
    return
  end
  
  if not monstersPanel then
    g_logger.debug("Could not find monstersPanel") -- Mudando de error para debug
    return
  end
  
  if not killsPanel then
    g_logger.debug("Could not find killsPanel") -- Mudando de error para debug
    return
  end
  
  -- Update rewards
  local taskPointsLabel = rewardsPanel:recursiveGetChildById('taskPointsLabel')
  local experienceLabel = rewardsPanel:recursiveGetChildById('experienceLabel')
  local goldLabel = rewardsPanel:recursiveGetChildById('goldLabel')
  local itemsLabel = rewardsPanel:recursiveGetChildById('itemsLabel')
  local accessLabel = rewardsPanel:recursiveGetChildById('accessLabel')
  local teleportLabel = rewardsPanel:recursiveGetChildById('teleportLabel')
  
  -- Ajustar margem esquerda para todos os labels
  local leftMargin = 35  -- Aumentado de 15 para 35
  
  if taskPointsLabel then 
    taskPointsLabel:setText(tr('Tasks Points: %s', task.reward and task.reward.points or 1))
    taskPointsLabel:setMarginLeft(leftMargin)
  end
  
  if experienceLabel then 
    experienceLabel:setText(tr('Experience: %s', task.reward and task.reward.exp or 1000))
    experienceLabel:setMarginLeft(leftMargin)
  end
  
  if goldLabel then 
    goldLabel:setText(tr('Gold: %s', task.reward and task.reward.gold or 500))
    goldLabel:setMarginLeft(leftMargin)
  end
  
  -- Update items reward
  if itemsLabel then
    local itemText = "None"
    if task.reward and task.reward.items and #task.reward.items > 0 then
      itemText = ""
      for i, item in ipairs(task.reward.items) do
        if i > 1 then itemText = itemText .. ", " end
        itemText = itemText .. (item.name or "Unknown Item")
      end
    end
    itemsLabel:setText(itemText)
    itemsLabel:setMarginLeft(leftMargin)
  end
  
  -- Update access and teleport rewards
  if accessLabel then 
    accessLabel:setText(task.reward and task.reward.access or "None")
    accessLabel:setMarginLeft(leftMargin)
  end
  
  if teleportLabel then 
    teleportLabel:setText(task.reward and task.reward.teleport or "None")
    teleportLabel:setMarginLeft(leftMargin)
  end
  
  -- Update monsters panel
  monstersPanel:destroyChildren()
  if task.monsters then
    local x = 10
    for _, monster in ipairs(task.monsters) do
      local monsterWidget = g_ui.createWidget('UICreature', monstersPanel)
      pcall(function()
        monsterWidget:setCreature(monster)
        monsterWidget:setMarginLeft(x)
        monsterWidget:setMarginTop(10)
        x = x + 40
      end)
    end
  end
  
  -- Update kills panel
  local killsRequired = killsPanel:recursiveGetChildById('killsRequired')
  local killsProgress = killsPanel:recursiveGetChildById('killsProgress')
  local bonusLabel = killsPanel:recursiveGetChildById('bonusLabel')
  
  if killsRequired then killsRequired:setText(tostring(task.count or 100)) end
  
  -- Update progress
  if killsProgress then
    local currentCount = 0
    -- Check both normal and daily tasks for progress
    if currentTasks.normal then
      for _, currentTask in ipairs(currentTasks.normal) do
        if currentTask.id == task.id then
          currentCount = currentTask.count or 0
          break
        end
      end
    end
    if currentTasks.daily then
      for _, currentTask in ipairs(currentTasks.daily) do
        if currentTask.id == task.id then
          currentCount = currentTask.count or 0
          break
        end
      end
    end
    
    local taskCount = task.count or 100
    local progressPercent = math.min(100, math.floor((currentCount / taskCount) * 100))
    killsProgress:setPercent(progressPercent)
  end
  
  if bonusLabel then bonusLabel:setText(task.bonus or tr("No Bonuses")) end
  
  -- Update start button
  local startTaskButton = tasksWindow:getChildById('startTaskButton')
  if startTaskButton then
    local isStarted = false
    -- Check if task is in progress
    if currentTasks.normal then
      for _, currentTask in ipairs(currentTasks.normal) do
        if currentTask.id == task.id then
          isStarted = true
          break
        end
      end
    end
    if not isStarted and currentTasks.daily then
      for _, currentTask in ipairs(currentTasks.daily) do
        if currentTask.id == task.id then
          isStarted = true
          break
        end
      end
    end
    
    startTaskButton:setText(isStarted and tr("In Progress") or tr("Start Task"))
    startTaskButton:setEnabled(not isStarted)
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