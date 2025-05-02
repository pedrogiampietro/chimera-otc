-- Game AutoLoot Module for OTClient
-- This module will add an autoloot button and window

-- Defina os opcodes usados para autoloot
ExtendedIds = ExtendedIds or {}
ExtendedIds.AutoLootData = 210  -- Escolha um número livre e consistente com o servidor
ExtendedIds.AutoLootRequest = 211

local autolootButton = nil
autolootWindow = nil

local function setMoneyButtonText(isOn)
  if autolootWindow then
    local moneyButton = autolootWindow:recursiveGetChildById('moneyButton')
    if moneyButton then
      if isOn then
        moneyButton:setText('Money ON')
      else
        moneyButton:setText('Money OFF')
      end
    end
  end
end

local function updateItemsCount(count)
  if autolootWindow then
    local itemsCountLabel = autolootWindow:recursiveGetChildById('itemsCountLabel')
    if itemsCountLabel then
      itemsCountLabel:setText(string.format("Items %d/10", count))
    end
  end
end

local function onClearButtonClick()
  local protocol = g_game.getProtocolGame()
  if protocol then
    local data = { action = "clear" }
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
  end
end

local function setBackpackAtualLabel(nome)
  if not autolootWindow then return end
  local label = autolootWindow:recursiveGetChildById('backpackAtualLabel')
  if label then
    if nome and nome ~= '' then
      label:setText('Current backpack: ' .. nome)
      label:setColor('#00FF00')
    else
      label:setText('Current backpack: None')
      label:setColor('#FF0000')
    end
  end
end

local function onExtendedAutoLootData(protocol, opcode, buffer)
  local data = json.decode(buffer)
  -- Feedback visual se for resposta de ação
  if data and data.feedback and data.message then
    if data.feedback == "success" or data.feedback == "info" then
      displayInfoBox("AutoLoot", data.message)
      -- Atualiza o texto do botão de gold se a mensagem for sobre gold
      if data.message:find("gold has been enabled") then
        setMoneyButtonText(true)
      elseif data.message:find("gold has been disabled") then
        setMoneyButtonText(false)
      end
      -- Atualiza o label da backpack atual se for feedback de backpack
      if data.message:find("Autoloot backpack set to:") then
        local nome = data.message:match("Autoloot backpack set to:%s*(.+)")
        setBackpackAtualLabel(nome)
      end
    elseif data.feedback == "error" then
      displayErrorBox("AutoLoot", data.message)
      -- Se for erro de backpack, limpa o label
      if data.message:find("backpack") then
        setBackpackAtualLabel(nil)
      end
    else
      displayInfoBox("AutoLoot", data.message)
    end
    return
  end
  if data and type(data) == 'table' then
    print('[AutoLoot] Loot list request sent to server.')
    -- Atualiza a interface somente se a janela existir e estiver visível
    if autolootWindow and autolootWindow:isVisible() then
      local lootListPanel = autolootWindow:recursiveGetChildById('lootListPanel')
      if lootListPanel then
        lootListPanel:destroyChildren()
        for i, loot in ipairs(data) do
          local row = g_ui.createWidget('AutoLootListRow', lootListPanel)
          if not row then
            print('[AutoLoot] ERROR: Failed to create AutoLootListRow widget')
            return
          end
          
          local itemImage = row:getChildById('itemImage')
          local itemLabel = row:getChildById('itemLabel')
          local removeButton = row:getChildById('removeButton')
          
          if not itemImage or not itemLabel or not removeButton then
            print('[AutoLoot] ERROR: Missing required child widgets in AutoLootListRow')
            print('[AutoLoot] Debug - itemImage:', itemImage and 'exists' or 'nil')
            print('[AutoLoot] Debug - itemLabel:', itemLabel and 'exists' or 'nil')
            print('[AutoLoot] Debug - removeButton:', removeButton and 'exists' or 'nil')
            row:destroy()
            return
          end
          
          -- Set item image
          local imagePath = string.format('/images/items/%d.png', loot.id)
          if g_resources.fileExists(imagePath) then
            itemImage:setImageSource(imagePath)
          else
            print(string.format('[AutoLoot] Warning: Image not found for item %d: %s', loot.id, imagePath))
            itemImage:setImageSource('')
          end
          
          -- Set item label
          itemLabel:setText(string.format('%d. %s (ID: %d)', i, loot.name, loot.id))
          itemLabel:setFont('verdana-11px-rounded')
          itemLabel:setColor('#FFD700')
          
          -- Set remove button action
          removeButton.onClick = function()
            local protocol = g_game.getProtocolGame()
            if protocol then
              local data = { action = "remove", itemId = loot.id }
              protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
              
              -- Remove the row imediatamente
              row:destroy()
              
              -- Request updated list after a short delay
              scheduleEvent(function()
                requestAutoLoot()
              end, 100)
            end
          end
          
          -- Make sure the button is visible
          removeButton:setVisible(true)
          removeButton:setEnabled(true)
        end
        
        -- Update layout once after all items are added
        lootListPanel:updateLayout()
        -- Atualiza o contador de itens corretamente
        updateItemsCount(#data)
      end
    end
    -- (opcional) print no console
    for i, loot in ipairs(data) do
      print(string.format('%d. %s (ID: %d)', i, loot.name, loot.id))
    end
  else
    print('[AutoLoot] Dados de loot recebidos em formato inválido!')
  end
end

function requestAutoLoot()
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, '{}')
    print('[AutoLoot] Loot list request sent to server.')
  else
    print('[AutoLoot] ERROR: game protocol not available!')
  end
end

local function onAddItemButtonClick()
  if not autolootWindow then return end
  local addItemEdit = autolootWindow:recursiveGetChildById('addItemEdit')
  if not addItemEdit then return end
  local itemName = addItemEdit:getText()
  itemName = itemName:gsub("^%s*(.-)%s*$", "%1") -- remove espaços início/fim
  itemName = itemName:gsub("%s+", " ") -- reduz múltiplos espaços internos para um só
  if itemName == "" then
    displayInfoBox("AutoLoot", "Enter the item name to add.")
    return
  end

  print('[AutoLoot Debug] Enviando para o servidor:', itemName)
  -- Envie o pedido para o servidor (action = "add")
  local protocol = g_game.getProtocolGame()
  if protocol then
    local data = { action = "add", item = itemName }
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
  end
end

local function onMoneyButtonClick()
  local protocol = g_game.getProtocolGame()
  if protocol then
    local data = { action = "gold" }
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
  end
end

local function onSetBackpackButtonClick()
  if not autolootWindow then return end
  local backpackEdit = autolootWindow:recursiveGetChildById('backpackEdit')
  if not backpackEdit then return end
  local name = backpackEdit:getText()
  name = name:gsub('^%s*(.-)%s*$', '%1')
  if name == '' then
    displayErrorBox("AutoLoot", "Enter the backpack name.")
    return
  end
  local protocol = g_game.getProtocolGame()
  if protocol then
    local data = { action = "backpack", item = name }
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
  end
end

function init()
  print('[AutoLoot] Module loaded!')
  -- Load the UI styles
  g_ui.importStyle('autoloot')
  g_ui.importStyle('autolootitem')
  
  print('[AutoLoot] modules.game_interface:', modules.game_interface)
  if modules.game_interface then
    print('[AutoLoot] getRootWidget:', modules.game_interface.getRootWidget)
  end
  
  connect(g_game, { 
    onGameStart = refresh,
    onGameEnd = offline
  })
  
  -- Adiar a criação da janela para garantir que o game_interface já está pronto
  addEvent(function()
    if g_ui.getRootWidget then
      autolootWindow = g_ui.createWidget('AutoLootWindow', g_ui.getRootWidget())
      autolootWindow:hide()
      -- Atualiza o texto do botão de gold ao abrir
      setMoneyButtonText(false)
    else
      print('[AutoLoot] ERROR: g_ui.getRootWidget is not available!')
    end
  end)
  
  -- Add button to the top menu
  setupTopMenuButton()
  
  if ProtocolGame and ProtocolGame.registerExtendedOpcode then
    ProtocolGame.registerExtendedOpcode(ExtendedIds.AutoLootData, onExtendedAutoLootData)
    print('[AutoLoot] Autoloot opcode registered!')
  else
    print('[AutoLoot] ERROR: ProtocolGame.registerExtendedOpcode is not available!')
  end
  
  if g_game.isOnline() then
    refresh()
  end
  
  addEvent(function()
    if autolootWindow then
      local addItemButton = autolootWindow:recursiveGetChildById('addItemButton')
      if addItemButton then
        addItemButton.onClick = onAddItemButtonClick
      end
      local moneyButton = autolootWindow:recursiveGetChildById('moneyButton')
      if moneyButton then
        moneyButton.onClick = onMoneyButtonClick
      end
      local clearButton = autolootWindow:recursiveGetChildById('clearButton')
      if clearButton then
        clearButton.onClick = onClearButtonClick
      end
      local setBackpackButton = autolootWindow:recursiveGetChildById('setBackpackButton')
      if setBackpackButton then
        setBackpackButton.onClick = onSetBackpackButtonClick
      end
      local closeButton = autolootWindow:recursiveGetChildById('closeButton')
      if closeButton then
        closeButton.onClick = modules.game_autoloot.onCloseWindow
      end
    end
  end)
end

function terminate()
  if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    ProtocolGame.unregisterExtendedOpcode(ExtendedIds.AutoLootData)
    print('[AutoLoot] Autoloot opcode removed!')
  end
  disconnect(g_game, { 
    onGameStart = refresh,
    onGameEnd = offline
  })
  
  if autolootButton then
    autolootButton:destroy()
    autolootButton = nil
  end
  
  if autolootWindow then
    autolootWindow:destroy()
    autolootWindow = nil
  end
end

function setupTopMenuButton()
  autolootButton = modules.client_topmenu.addLeftGameToggleButton(
    'autolootButton',
    tr('AutoLoot'),
    '/images/topbuttons/autoloot',
    function()
      if autolootWindow and autolootWindow:isVisible() then
        autolootWindow:hide()
        autolootButton:setOn(false)
      else
        requestAutoLoot()
        autolootWindow:show()
        autolootWindow:raise()
        autolootWindow:focus()
        autolootButton:setOn(true)
      end
    end,
    false, 99998
  )
  autolootButton:setOn(false)
  autolootButton:show()
end

function toggle()
  if autolootWindow:isVisible() then
    autolootWindow:hide()
    autolootButton:setOn(false)
  else
    autolootWindow:show()
    autolootWindow:raise()
    autolootWindow:focus()
    autolootButton:setOn(true)
  end
end

function onCloseWindow()
  if autolootWindow then
    autolootWindow:hide()
  end
  if autolootButton then
    autolootButton:setOn(false)
    autolootButton:show()
  end
end

function refresh()
  -- Refresh the autoloot settings when game starts
end

function offline()
  -- Clear and hide window when going offline
  autolootWindow:hide()
  autolootButton:setOn(false)
end 