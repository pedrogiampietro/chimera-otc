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
  dragon = "/images/game/creatures/monsters/dragon",
  rat = "/images/game/creatures/monsters/rat",
  default = "/images/game/creatures/monsters/troll"
}

-- Helper function to check task status
local function getTaskStatus(taskId)
  -- Check in normal tasks
  if currentTasks.normal then
    for _, task in ipairs(currentTasks.normal) do
      if task.id == taskId then
        if task.status == TASK_STATUS_COMPLETED then
          return "completed"
        elseif task.status == TASK_STATUS_STARTED then
          return "in_progress"
        else
          return "available"
        end
      end
    end
  end
  
  -- Check in daily tasks
  if currentTasks.daily then
    for _, task in ipairs(currentTasks.daily) do
      if task.id == taskId then
        if task.status == TASK_STATUS_COMPLETED then
          return "completed"
        elseif task.status == TASK_STATUS_STARTED then
          return "in_progress"
        else
          return "available" 
        end
      end
    end
  end
  
  -- Check in availableTasks if not found in currentTasks
  if availableTasks.normal then
    for _, task in ipairs(availableTasks.normal) do
      if task.id == taskId then
        if task.status == TASK_STATUS_STARTED then
          return "in_progress"
        else
          return "available"
        end
      end
    end
  end
  
  if availableTasks.daily then
    for _, task in ipairs(availableTasks.daily) do
      if task.id == taskId then
        if task.status == TASK_STATUS_STARTED then
          return "in_progress"
        else
          return "available"
        end
      end
    end
  end
  
  return "available"
end

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
  
  -- Log the structure of the data for debugging
  g_logger.debug("Structure of availableTasks: " .. json.encode(data.availableTasks or {}))
  g_logger.debug("Structure of currentTasks: " .. json.encode(data.currentTasks or {}))
  
  -- Use the actual data received from server
  availableTasks = data.availableTasks or { normal = {}, daily = {} }
  currentTasks = data.currentTasks or { normal = {}, daily = {} }
  
  -- Process all tasks with default values if missing
  for _, category in pairs({availableTasks, currentTasks}) do
    for _, list in pairs(category) do
      for _, task in ipairs(list) do
        -- Set monster information if not present
        if not task.monsters or #task.monsters == 0 then
          -- Try to derive monster info from task name
          local monsterName = string.match(task.name:lower(), "(%w+)")
          if monsterName and monsterName ~= "daily" then
            task.monsters = {monsterName}
          elseif task.type == TASK_TYPE_DAILY then
            -- For daily tasks, extract second word as monster name
            local words = {}
            for word in task.name:gmatch("%w+") do
              table.insert(words, word:lower())
            end
            if words[2] then
              task.monsters = {words[2]}
            else
              task.monsters = {"default"}
            end
          else
            task.monsters = {"default"}
          end
        end
        
        -- Ensure reward information exists
        if not task.reward then
          task.reward = {}
        end
        
        -- Add default reward info if missing
        if not task.reward.points then
          task.reward.points = task.type == TASK_TYPE_DAILY and 1 or 2
        end
        
        if not task.reward.exp then
          -- Calculate default experience based on level
          task.reward.exp = (task.level or 1) * 100
        end
        
        if not task.reward.gold then
          -- Calculate default gold based on level
          task.reward.gold = (task.level or 1) * 50
        end
        
        if not task.reward.access then
          task.reward.access = "None"
        end
        
        if not task.reward.teleport then
          task.reward.teleport = "None"
        end
        
        if not task.bonus then
          task.bonus = "None"
        end
      end
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

-- Helper function to update the button based on task status
function updateTaskButton(task)
  if not tasksWindow or not task then return end
  
  local detailsPanel = tasksWindow:recursiveGetChildById('detailsPanel')
  if not detailsPanel then return end
  
  local startTaskButton = detailsPanel:getChildById('startTaskButton')
  if not startTaskButton then return end
  
  -- Determine if the task is in progress
  local isInProgress = false
  
  g_logger.debug("Verificando status da tarefa: " .. tostring(task.id))
  g_logger.debug("Status atual: " .. tostring(task.status))
  
  -- Apenas considerar iniciada se o status for explicitamente STARTED
  if task.status == TASK_STATUS_STARTED then
    isInProgress = true
    g_logger.debug("Tarefa em andamento pelo status STARTED")
  else
    -- Check in currentTasks apenas se o status não é STARTED
    -- Verifica se esta tarefa específica está nas tarefas atuais
    if currentTasks.normal then
      for _, currentTask in ipairs(currentTasks.normal) do
        if currentTask.id == task.id then
          if currentTask.status == TASK_STATUS_STARTED then
            isInProgress = true
            g_logger.debug("Tarefa em andamento encontrada em currentTasks.normal")
            break
          end
        end
      end
    end
    
    if not isInProgress and currentTasks.daily then
      for _, currentTask in ipairs(currentTasks.daily) do
        if currentTask.id == task.id then
          if currentTask.status == TASK_STATUS_STARTED then
            isInProgress = true
            g_logger.debug("Tarefa em andamento encontrada em currentTasks.daily")
            break
          end
        end
      end
    end
  end
  
  -- Não considere mais o progresso da tarefa como indicação de que ela está em andamento
  -- Apenas o status STARTED é relevante
  
  -- Update button text and state
  if isInProgress then
    g_logger.debug("Setting button to 'Cancel Task' for task: " .. task.id)
    startTaskButton:setText(tr("Cancel Task"))
  else
    g_logger.debug("Setting button to 'Start Task' for task: " .. task.id)
    startTaskButton:setText(tr("Start Task"))
  end
  
  startTaskButton:setEnabled(true)
  startTaskButton:setVisible(true)
end

function onTaskUpdate(data)
  -- Update task progress
  if data.taskId and data.count ~= nil then
    g_logger.debug("Received task update for ID " .. data.taskId .. " with count " .. data.count)
    
    -- Variável para armazenar a tarefa encontrada
    local updatedTask = nil
    
    -- Update task progress in normal tasks
    if currentTasks.normal then
      for i, task in ipairs(currentTasks.normal) do
        if task.id == data.taskId then
          task.count = data.count
          updatedTask = task
          g_logger.debug("Updated normal task: " .. task.name .. " with count " .. data.count)
          break
        end
      end
    end
    
    -- Same for daily tasks
    if not updatedTask and currentTasks.daily then
      for i, task in ipairs(currentTasks.daily) do
        if task.id == data.taskId then
          task.count = data.count
          updatedTask = task
          g_logger.debug("Updated daily task: " .. task.name .. " with count " .. data.count)
          break
        end
      end
    end
    
    -- If window is open, update the UI
    if tasksWindow and tasksWindow:isVisible() then
      -- If this is the selected task, update details
      if selectedTask and selectedTask.id == data.taskId then
        updateTaskDetails(selectedTask)
        updateTaskButton(selectedTask)
      end
      
      -- Always update task list to show progress
      populateTaskList()
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
  
  -- Get task list
  taskList = tasksWindow:recursiveGetChildById('taskList')
  
  -- Check if taskList was found
  if not taskList then
    g_logger.error("Failed to get taskList widget")
    return
  end
  
  g_logger.info("Found taskList widget: " .. tostring(taskList:getId()))
  
  -- Populate task list into the container
  populateTaskList()
  
  -- Set first task as selected if available
  local children = {}
  if taskList then
    children = taskList:getChildren()
  end
  
  if children and #children > 0 then
    -- Find the first non-header task item
    for _, child in ipairs(children) do
      if child.task then
        selectedTask = child.task
        updateTaskDetails(selectedTask)
        updateTaskButton(selectedTask)
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

  -- Function to create section header
  local function createSectionHeader(text)
    local header = g_ui.createWidget('TaskSectionHeader', taskList)
    header:setText(text)
    header:setEnabled(false)
    return header
  end

  -- Helper function to check if a task already exists in current tasks
  local function isTaskInCurrentTasks(taskId)
    -- Check in daily tasks
    if currentTasks.daily then
      for _, task in ipairs(currentTasks.daily) do
        if task.id == taskId then
          return true
        end
      end
    end
    
    -- Check in normal tasks
    if currentTasks.normal then
      for _, task in ipairs(currentTasks.normal) do
        if task.id == taskId then
          return true
        end
      end
    end
    
    return false
  end

  local itemCount = 0

  -- Add Daily Tasks section from currentTasks
  if currentTasks and currentTasks.daily and #currentTasks.daily > 0 then
    createSectionHeader("Daily Tasks")
    
    g_logger.info("Adding daily tasks: " .. tostring(#currentTasks.daily))
    for i, task in ipairs(currentTasks.daily) do
      g_logger.info("Adding daily task " .. i .. ": " .. (task.name or "Unknown"))
      local widget = addTaskToList(task, taskList, itemCount % 2 == 0)
      itemCount = itemCount + 1
    end
  end
  
  -- Add available daily tasks that aren't already in currentTasks
  local availableDailyTasksCount = 0
  if availableTasks and availableTasks.daily then
    for _, task in ipairs(availableTasks.daily) do
      if not isTaskInCurrentTasks(task.id) then
        availableDailyTasksCount = availableDailyTasksCount + 1
      end
    end
  end
  
  if availableDailyTasksCount > 0 then
    -- If we haven't already created the Daily Tasks header, create it now
    if not (currentTasks and currentTasks.daily and #currentTasks.daily > 0) then
      createSectionHeader("Daily Tasks")
    end
    
    for i, task in ipairs(availableTasks.daily) do
      if not isTaskInCurrentTasks(task.id) then
        g_logger.info("Adding available daily task: " .. (task.name or "Unknown"))
        local widget = addTaskToList(task, taskList, itemCount % 2 == 0)
        itemCount = itemCount + 1
      end
    end
  end
  
  -- Add current Normal Tasks
  local hasNormalTasksHeader = false
  if currentTasks and currentTasks.normal and #currentTasks.normal > 0 then
    -- Add spacer before new section
    local spacer = g_ui.createWidget('UIWidget', taskList)
    spacer:setHeight(10)
    spacer:setPhantom(true)
    
    createSectionHeader("Normal Tasks")
    hasNormalTasksHeader = true
    
    for i, task in ipairs(currentTasks.normal) do
      g_logger.info("Adding current normal task " .. i .. ": " .. (task.name or "Unknown"))
      local widget = addTaskToList(task, taskList, itemCount % 2 == 0)
      itemCount = itemCount + 1
    end
  end

  -- Add available Normal Tasks that aren't already in currentTasks
  local availableNormalTasksCount = 0
  if availableTasks and availableTasks.normal then
    for _, task in ipairs(availableTasks.normal) do
      if not isTaskInCurrentTasks(task.id) then
        availableNormalTasksCount = availableNormalTasksCount + 1
      end
    end
  end
  
  if availableNormalTasksCount > 0 then
    -- Add spacer and header if we haven't already added them
    if not hasNormalTasksHeader then
      local spacer = g_ui.createWidget('UIWidget', taskList)
      spacer:setHeight(10)
      spacer:setPhantom(true)
      
      createSectionHeader("Normal Tasks")
    end
    
    for i, task in ipairs(availableTasks.normal) do
      if not isTaskInCurrentTasks(task.id) then
        g_logger.info("Adding available normal task: " .. (task.name or "Unknown"))
        local widget = addTaskToList(task, taskList, itemCount % 2 == 0)
        itemCount = itemCount + 1
      end
    end
  end

  g_logger.info("Task list populated with " .. tostring(itemCount) .. " tasks")
  
  -- Setup click handlers for all tasks
  local children = taskList:getChildren()
  for _, child in pairs(children) do
    if child.task then
      child.onClick = function()
        -- Reset all tasks to default appearance
        for _, otherChild in pairs(children) do
          if otherChild.task then
            otherChild:setBackgroundColor(otherChild == child and '#444444' or 'alpha')
            
            -- Find the nameLabel inside the widget
            local nameLabel = otherChild:getChildById('taskName')
            if nameLabel then
              nameLabel:setColor(otherChild == child and '#ffffff' or '#cccccc')
              
              -- If it's a daily task, preserve its color
              if otherChild.task.type == TASK_TYPE_DAILY and otherChild ~= child then
                nameLabel:setColor('#ffcc00')
              end
              
              -- If it's a recommended task, preserve its color
              if otherChild.task.recommended and otherChild ~= child then
                nameLabel:setColor('#00ff00')
              end
            end
          end
        end
        
        -- Update selected task and details
        selectedTask = child.task
        updateTaskDetails(selectedTask)
        -- Guarantees the button is in the correct state
        updateTaskButton(selectedTask)
      end
    end
  end
end

function getMonsterTypeFromName(taskName)
  if not taskName then return "default" end
  
  -- Converter para minúsculas para facilitar a comparação
  local lowerName = taskName:lower()
  
  -- Mapeamento direto de nomes de tasks para tipos de monstros
  local taskToMonster = {
    ["daily amazon raid"] = "amazon",
    ["daily rotworm hunt"] = "rotworm",
    ["daily dragon lair"] = "dragon",
    ["daily minotaur cleansing"] = "minotaur",
    ["daily orc fortress"] = "orc",
    ["rat extermination"] = "rat",
    ["spider hunter"] = "spider",
    ["orc slayer"] = "orc"
  }
  
  -- Tentar encontrar correspondência exata primeiro
  if taskToMonster[lowerName] then
    return taskToMonster[lowerName]
  end
  
  -- Se não encontrar correspondência exata, procurar por palavras-chave
  local keywords = {
    ["amazon"] = "amazon",
    ["rotworm"] = "rotworm",
    ["dragon"] = "dragon",
    ["minotaur"] = "minotaur",
    ["orc"] = "orc",
    ["rat"] = "rat",
    ["spider"] = "spider"
  }
  
  for keyword, monsterType in pairs(keywords) do
    if lowerName:find(keyword) then
      return monsterType
    end
  end
  
  return "default"
end

function addTaskToList(task, container, isEven)
  if not container then return nil end
  
  -- Create a panel for the task item
  local taskWidget = g_ui.createWidget('TaskPanel', container)
  if not taskWidget then
    g_logger.debug("Failed to create task widget")
    return nil
  end
  
  -- Setup basic widget properties
  taskWidget:setVisible(true)
  taskWidget:setEnabled(true)
  taskWidget:setFocusable(true)
  taskWidget:setBackgroundColor(isEven and '#33333366' or '#44444466')
  taskWidget:setSize({width = container:getWidth() - 10, height = 60})
  
  -- Store reference to task data
  taskWidget.task = task
  
  -- Get the monster type for the icon
  local monsterType = "default"
  
  -- Get monster type from task name first
  monsterType = getMonsterTypeFromName(task.name)
  
  -- If we got a default type, try to get it from monsters array
  if monsterType == "default" and task.monsters and #task.monsters > 0 then
    monsterType = task.monsters[1]:lower()
  end
  
  -- Use the task icon from taskIcons dictionary
  local iconPath = taskIcons[monsterType]
  if not iconPath then
    iconPath = taskIcons["default"]
  end
  
  -- Set the icon
  local iconWidget = taskWidget:getChildById('taskIcon')
  if iconWidget then
    iconWidget:setImageSource(iconPath)
  end
  
  -- Create base text
  local baseText = task.name or "Unknown Task"
  if task.level then
    baseText = baseText .. " (Level " .. task.level .. ")"
  end
  
  -- Set the task name
  local nameLabel = taskWidget:getChildById('taskName')
  if nameLabel then
    nameLabel:setText(baseText)
    
    -- Set text color based on task type
    if task.type == TASK_TYPE_DAILY then
      nameLabel:setColor('#ffcc00')  -- Gold for daily tasks
    elseif task.recommended then
      nameLabel:setColor('#00ff00')  -- Green for recommended tasks
    else
      nameLabel:setColor('#cccccc')  -- Regular text color
    end
    
    -- Add progress/completion status if applicable
    local taskStatus = getTaskStatus(task.id)
    
    if taskStatus == "completed" then
      nameLabel:setText(baseText .. " [Completed]")
    elseif taskStatus == "in_progress" then
      -- Se estiver em progresso e tiver count, mostra o progresso
      if task.count and task.count > 0 then
        nameLabel:setText(baseText .. " [" .. task.count .. "/" .. (task.total or 100) .. "]")
      else
        nameLabel:setText(baseText .. " [In Progress]")
      end
    elseif task.type == TASK_TYPE_DAILY and task.count and task.count > 0 then
      -- Para daily tasks, mostra o progresso se tiver contagem
      nameLabel:setText(baseText .. " [" .. task.count .. "/" .. (task.total or 100) .. "]")
    end
  end
  
  return taskWidget
end

function updateTaskDetails(task)
  if not tasksWindow or not task then 
    g_logger.debug("Cannot update task details: no window or task")
    return 
  end
  
  -- Verificação adicional para garantir que a tarefa tenha um ID
  if not task.id then
    g_logger.debug("Cannot update task details: task has no ID")
    return
  end
  
  -- Primeiro obter o painel de detalhes
  local detailsPanel = tasksWindow:recursiveGetChildById('detailsPanel')
  if not detailsPanel then
    g_logger.debug("Cannot find detailsPanel")
    return
  end
  
  -- Verifica se o botão está presente antes de iniciar (como filho do detailsPanel)
  local startTaskButton = detailsPanel:getChildById('startTaskButton')
  g_logger.debug("Start task button found: " .. tostring(startTaskButton ~= nil))
  
  if not startTaskButton then
    g_logger.debug("Cannot update task button: start task button not found in detailsPanel")
    
    -- Tentar encontrar de forma recursiva em todo o painel de detalhes
    startTaskButton = detailsPanel:recursiveGetChildById('startTaskButton')
    g_logger.debug("Start task button found recursively in detailsPanel: " .. tostring(startTaskButton ~= nil))
    
    -- Se ainda não encontrou, tentar na janela inteira como último recurso
    if not startTaskButton then
      startTaskButton = tasksWindow:recursiveGetChildById('startTaskButton')
      g_logger.debug("Start task button found recursively in tasksWindow: " .. tostring(startTaskButton ~= nil))
    end
  end
  
  -- Verify that we have all required panels first
  local rewardsPanel = tasksWindow:recursiveGetChildById('rewardsPanel')
  local monstersPanel = tasksWindow:recursiveGetChildById('monstersPanel')
  local killsPanel = tasksWindow:recursiveGetChildById('killsPanel')
  
  if not rewardsPanel or not monstersPanel or not killsPanel then
    g_logger.debug("Could not find required panels")
    return
  end
  
  -- Ajustar margem e largura dos labels
  local leftMargin = 10  -- Reduzido para dar mais espaço ao texto
  local labelWidth = 200 -- Aumentado para garantir que o texto caiba
  
  -- Update rewards
  local taskPointsLabel = rewardsPanel:recursiveGetChildById('taskPointsLabel')
  local experienceLabel = rewardsPanel:recursiveGetChildById('experienceLabel')
  local goldLabel = rewardsPanel:recursiveGetChildById('goldLabel')
  local itemsLabel = rewardsPanel:recursiveGetChildById('itemsLabel')
  local accessLabel = rewardsPanel:recursiveGetChildById('accessLabel')
  local teleportLabel = rewardsPanel:recursiveGetChildById('teleportLabel')
  
  -- Função helper para configurar os labels
  local function setupLabel(label, text, center)
    if label then
      label:setText(text)
      if center then
        label:setTextAlign(AlignCenter)
        label:setMarginLeft(0)
      else
        label:setMarginLeft(leftMargin)
      end
      label:setWidth(labelWidth)
      label:setTextWrap(true) -- Permite quebra de linha se necessário
    end
  end
  
  -- Atualizar os labels com a nova configuração
  setupLabel(taskPointsLabel, tr('Task Points: %s', task.reward and task.reward.points or 1))
  setupLabel(experienceLabel, tr('Experience: %s', task.reward and task.reward.exp or 1000))
  setupLabel(goldLabel, tr('Gold: %s', task.reward and task.reward.gold or 500))
  
  -- Update items reward
  local itemText = "None"
  if task.reward and task.reward.items and #task.reward.items > 0 then
    itemText = ""
    for i, item in ipairs(task.reward.items) do
      if i > 1 then itemText = itemText .. ", " end
      itemText = itemText .. (item.name or "Unknown Item")
    end
  end
  setupLabel(itemsLabel, itemText)
  
  -- Update access and teleport rewards
  setupLabel(accessLabel, task.reward and task.reward.access or "None")
  setupLabel(teleportLabel, task.reward and task.reward.teleport or "None")
  
  -- Update monsters panel
  monstersPanel:destroyChildren()
  if task.monsters then
    local x = 10
    for _, monster in ipairs(task.monsters) do
      local monsterType = monster:lower()
      local iconPath = taskIcons[monsterType] or taskIcons["default"]
      
      local monsterWidget = g_ui.createWidget('UIWidget', monstersPanel)
      monsterWidget:setImageSource(iconPath)
      monsterWidget:setSize({width = 32, height = 32})
      monsterWidget:setMarginLeft(x)
      monsterWidget:setMarginTop(10)
      x = x + 40
    end
  end
  
  -- Update kills panel
  local killsRequired = killsPanel:recursiveGetChildById('killsRequired')
  local killsProgress = killsPanel:recursiveGetChildById('killsProgress')
  local bonusLabel = killsPanel:recursiveGetChildById('bonusLabel')
  
  -- Configurar labels do painel de kills
  if killsRequired then 
    setupLabel(killsRequired, tostring(task.total or task.count or 100), true)
  end
  
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
    
    local required = task.total or task.count or 100
    local progressPercent = math.min(100, math.floor((currentCount / required) * 100))
    killsProgress:setPercent(progressPercent)
  end
  
  if bonusLabel then 
    setupLabel(bonusLabel, task.bonus or tr("No Bonuses"))
  end
  
  -- Não precisamos declarar startTaskButton novamente, pois já foi declarado no início da função
  if startTaskButton then
    -- Check if task is in progress
    local isInProgress = false
    
    -- Debug log to check task structure
    g_logger.debug("Checking task status for: " .. (task.name or "unknown") .. " with ID: " .. tostring(task.id))
    
    -- Check if task status is STARTED
    if task.status == TASK_STATUS_STARTED then
      isInProgress = true
      g_logger.debug("Task is already in progress based on its status")
    end
    
    -- Check in currentTasks.normal if not already determined
    if not isInProgress and currentTasks.normal then
      for _, currentTask in ipairs(currentTasks.normal) do
        if currentTask.id == task.id then
          if currentTask.status == TASK_STATUS_STARTED then
            isInProgress = true
            g_logger.debug("Task found in progress in currentTasks.normal")
          end
          break
        end
      end
    end
    
    -- Check in currentTasks.daily if not already determined
    if not isInProgress and currentTasks.daily then
      for _, currentTask in ipairs(currentTasks.daily) do
        if currentTask.id == task.id then
          if currentTask.status == TASK_STATUS_STARTED then
            isInProgress = true
            g_logger.debug("Task found in progress in currentTasks.daily")
          end
          break
        end
      end
    end
    
    -- If task is in progress, change button text to "Cancel Task" instead of hiding it
    if isInProgress then
      g_logger.debug("Task is in progress, changing button to 'Cancel Task'")
      startTaskButton:setText(tr("Cancel Task"))
      startTaskButton:setEnabled(true)
      startTaskButton:setVisible(true) -- Mantém o botão visível para permitir cancelar a tarefa
    else
      g_logger.debug("Task is not in progress, setting button to 'Start Task'")
      startTaskButton:setText(tr("Start Task"))
      startTaskButton:setEnabled(true)
      startTaskButton:setVisible(true)
    end
    
    -- Debug log the final decision
    g_logger.debug("Task " .. (task.name or "unknown") .. " isInProgress: " .. tostring(isInProgress))
    g_logger.debug("Button text is now: " .. startTaskButton:getText())
  end
end

function startTask()
  if not selectedTask then 
    g_logger.debug("startTask called but no selectedTask")
    return 
  end
  
  g_logger.debug("Starting/canceling task: " .. (selectedTask.name or "unknown") .. " with ID: " .. tostring(selectedTask.id))
  
  -- Check if task is already in progress (to determine if we should start or cancel)
  local isInProgress = false
  
  -- Check if task status is STARTED
  if selectedTask.status == TASK_STATUS_STARTED then
    isInProgress = true
    g_logger.debug("Task is already in progress based on its status")
  end
  
  -- Check in currentTasks.normal if not already determined
  if not isInProgress and currentTasks.normal then
    for _, currentTask in ipairs(currentTasks.normal) do
      if currentTask.id == selectedTask.id then
        if currentTask.status == TASK_STATUS_STARTED then
          isInProgress = true
          g_logger.debug("Task found in progress in currentTasks.normal")
        end
        break
      end
    end
  end
  
  -- Check in currentTasks.daily if not already determined
  if not isInProgress and currentTasks.daily then
    for _, currentTask in ipairs(currentTasks.daily) do
      if currentTask.id == selectedTask.id then
        if currentTask.status == TASK_STATUS_STARTED then
          isInProgress = true
          g_logger.debug("Task found in progress in currentTasks.daily")
        end
        break
      end
    end
  end
  
  -- Send task start or cancel request to server
  if g_game.getFeature(GameExtendedClientPing) then
    local protocol = g_game.getProtocolGame()
    if protocol then
      local action = isInProgress and "cancel" or "start"
      g_logger.debug("Action to perform: " .. action .. " for task ID: " .. tostring(selectedTask.id))
      
      local data = {
        action = action,
        taskId = selectedTask.id
      }
      protocol:sendExtendedOpcode(ExtendedIds.TaskAction, json.encode(data))
      
      if action == "start" then
        -- Marca a tarefa como em progresso na estrutura de dados local
        selectedTask.status = TASK_STATUS_STARTED
        g_logger.debug("Setting task status to STARTED: " .. tostring(TASK_STATUS_STARTED))
        
        -- Adiciona a tarefa selecionada à lista de tarefas atuais
        if selectedTask.type == TASK_TYPE_DAILY then
          if not currentTasks.daily then
            currentTasks.daily = {}
          end
          
          -- Verifica se a tarefa já existe na lista
          local exists = false
          for _, task in ipairs(currentTasks.daily) do
            if task.id == selectedTask.id then
              task.status = TASK_STATUS_STARTED
              exists = true
              g_logger.debug("Updated existing daily task to STARTED")
              break
            end
          end
          
          -- Se não existir, adiciona à lista
          if not exists then
            local taskCopy = table.copy(selectedTask)
            taskCopy.status = TASK_STATUS_STARTED
            taskCopy.count = 0
            table.insert(currentTasks.daily, taskCopy)
            g_logger.debug("Added new daily task with STARTED status")
          end
        else
          if not currentTasks.normal then
            currentTasks.normal = {}
          end
          
          -- Verifica se a tarefa já existe na lista
          local exists = false
          for _, task in ipairs(currentTasks.normal) do
            if task.id == selectedTask.id then
              task.status = TASK_STATUS_STARTED
              exists = true
              g_logger.debug("Updated existing normal task to STARTED")
              break
            end
          end
          
          -- Se não existir, adiciona à lista
          if not exists then
            local taskCopy = table.copy(selectedTask)
            taskCopy.status = TASK_STATUS_STARTED
            taskCopy.count = 0
            table.insert(currentTasks.normal, taskCopy)
            g_logger.debug("Added new normal task with STARTED status")
          end
        end
      else -- action == "cancel"
        -- Remove a tarefa das tarefas atuais
        if selectedTask.type == TASK_TYPE_DAILY and currentTasks.daily then
          for i, task in ipairs(currentTasks.daily) do
            if task.id == selectedTask.id then
              table.remove(currentTasks.daily, i)
              g_logger.debug("Removed daily task from currentTasks")
              break
            end
          end
        elseif currentTasks.normal then
          for i, task in ipairs(currentTasks.normal) do
            if task.id == selectedTask.id then
              table.remove(currentTasks.normal, i)
              g_logger.debug("Removed normal task from currentTasks")
              break
            end
          end
        end
        
        -- Restaura o status da tarefa
        selectedTask.status = TASK_STATUS_AVAILABLE
        selectedTask.count = 0
        g_logger.debug("Reset task status to AVAILABLE: " .. tostring(TASK_STATUS_AVAILABLE))
      end
      
      -- Use helper function to update the button text
      updateTaskButton(selectedTask)
      
      -- Atualiza a lista de tarefas e detalhes
      populateTaskList()
      updateTaskDetails(selectedTask)
    end
  end
end 