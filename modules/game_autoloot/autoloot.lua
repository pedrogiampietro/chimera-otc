-- Game AutoLoot Module for OTClient
-- This module will add an autoloot button and window

-- Defina os opcodes usados para autoloot
ExtendedIds = ExtendedIds or {}
ExtendedIds.AutoLootData = 210  -- Escolha um número livre e consistente com o servidor
ExtendedIds.AutoLootRequest = 211

local autolootButton = nil
autolootWindow = nil
local backpackSelectorModal = nil
local lastSelectedBackpackId = nil

local function setMoneyButtonText(isOn)
  if autolootWindow then
    local moneyButton = autolootWindow:recursiveGetChildById('moneyButton')
    if moneyButton then
      if isOn then
        moneyButton:setText('Money ON')
        moneyButton:setBackgroundColor('#2a4a2a')
        moneyButton:setColor('#90EE90')
      else
        moneyButton:setText('Money OFF')
        moneyButton:setBackgroundColor('#4a2a2a')
        moneyButton:setColor('#FF6666')
      end
    end
  end
end

local function updateGoldBackpackStatus(message, isEnabled)
  if autolootWindow then
    local statusLabel = autolootWindow:recursiveGetChildById('goldBackpackStatus')
    if statusLabel then
      if message and message:find("disabled") then
        statusLabel:setText('Gold has been disabled')
        statusLabel:setColor('#888888')
      elseif isEnabled or (message and (message:find("enabled") or message:find("bag ID: 2004"))) then
        -- Gold está habilitado, verificar se tem bag ID 2004
        if message and message:find("will go to your bag") then
          statusLabel:setText('Loot pounch (100%)')
          statusLabel:setColor('#90EE90')
        elseif message and message:find("will go to bank") then
          statusLabel:setText('Bank (70%, fee: 30%)')
          statusLabel:setColor('#FFA500')
        else
          -- Verificar dinamicamente se o player tem uma bag ID 2004
          checkGoldBackpackStatus()
        end
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
      label:setText('Current: ' .. nome)
      label:setColor('#90EE90')
    else
      label:setText('Current: None')
      label:setColor('#FF6666')
    end
  end
end

local function onBackpackSelect(backpackId, backpackName)
  print('[AutoLoot Debug] onBackpackSelect chamado com ID:', backpackId, 'Nome:', backpackName)
  
  -- Save the selected backpack ID
  lastSelectedBackpackId = backpackId
  print('[AutoLoot Debug] Salvando seleção:', lastSelectedBackpackId)
  
  local protocol = g_game.getProtocolGame()
  if protocol then
    local data = { action = "selectBackpack", backpackId = backpackId }
    print('[AutoLoot Debug] Enviando seleção para servidor:', json.encode(data))
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
  else
    print('[AutoLoot Debug] ERRO: protocol não encontrado')
  end
  
  -- Don't hide the modal automatically - let user close it manually
  -- This prevents the list from disappearing after selection
  print('[AutoLoot Debug] Seleção concluída - mantendo modal aberto para o usuário fechar')
  
  -- Update current backpack label in main window
  if autolootWindow then
    local currentLabel = autolootWindow:recursiveGetChildById('backpackAtualLabel')
    if currentLabel then
      currentLabel:setText('Current: ' .. backpackName)
      print('[AutoLoot Debug] Label atualizado para:', backpackName)
    end
  end
  
  -- Update modal header to show selection was made
  if backpackSelectorModal then
    local headerLabel = backpackSelectorModal:recursiveGetChildById('headerPanel'):getChildren()[1]
    if headerLabel then
      headerLabel:setText('Selected: ' .. backpackName .. ' - Close modal when ready')
      headerLabel:setColor('#90EE90')
    end
  end
end

local function updateBackpackList(backpacks)
  print('[AutoLoot Debug] updateBackpackList chamada com ' .. #backpacks .. ' backpacks')
  print('[AutoLoot Debug] Verificando se modal existe:', backpackSelectorModal and 'SIM' or 'NÃO')
  
  -- Always ensure modal exists and is accessible
  if not backpackSelectorModal then 
    print('[AutoLoot Debug] ERRO: Modal não existe quando deveria existir!')
    print('[AutoLoot Debug] Isso indica um problema de escopo de variável')
    return
  end
  
  -- Get the list panel - should always exist in modal
  local listPanel = backpackSelectorModal:recursiveGetChildById('modalBackpackListPanel')
  if not listPanel then 
    print('[AutoLoot Debug] ERRO: modalBackpackListPanel não encontrado no modal!')
    -- Try to debug what children exist
    local children = backpackSelectorModal:getChildren()
    print('[AutoLoot Debug] Modal tem', #children, 'filhos:')
    for i, child in ipairs(children) do
      print('[AutoLoot Debug] - Filho', i, ':', child:getId())
    end
    return
  end
  
  print('[AutoLoot Debug] modalBackpackListPanel encontrado, atualizando lista...')
  
  print('[AutoLoot Debug] modalBackpackListPanel encontrado:', listPanel)
  
  print('[AutoLoot Debug] Atualizando lista de backpacks no modal')
  
  -- Always recreate to apply correct selection state
  print('[AutoLoot Debug] Recriando lista de backpacks para aplicar estado correto')
  listPanel:destroyChildren()
  
  if #backpacks == 0 then
    -- No backpacks found
    local label = g_ui.createWidget('Label', listPanel)
    label:setText('No backpacks found')
    label:setColor('#888888')
    label:setTextAlign(AlignCenter)
    return
  end
  
  -- Add backpack items
  for _, backpack in ipairs(backpacks) do
    print('[AutoLoot Debug] Criando BackpackListRow para:', backpack.name)
    local row = g_ui.createWidget('BackpackListRow', listPanel)
    if row then
      print('[AutoLoot Debug] BackpackListRow criado com sucesso, ID:', row:getId())
      print('[AutoLoot Debug] BackpackRow visível?', row:isVisible())
      print('[AutoLoot Debug] BackpackRow tamanho:', row:getSize())
      
      -- Force visible and size
      row:setVisible(true)
      row:setHeight(36)
      local image = row:getChildById('backpackImage')
      local backpackInfo = row:getChildById('backpackInfo')
      local nameLabel = backpackInfo and backpackInfo:getChildById('backpackLabel')
      local idLabel = backpackInfo and backpackInfo:getChildById('backpackIdLabel')
      local button = row:getChildById('selectButton')
      
      print('[AutoLoot Debug] Backpack elementos:')
      print('[AutoLoot Debug] - image:', image and 'OK' or 'MISSING')
      print('[AutoLoot Debug] - backpackInfo:', backpackInfo and 'OK' or 'MISSING')
      print('[AutoLoot Debug] - nameLabel:', nameLabel and 'OK' or 'MISSING')
      print('[AutoLoot Debug] - idLabel:', idLabel and 'OK' or 'MISSING')
      print('[AutoLoot Debug] - button:', button and 'OK' or 'MISSING')
      
      if image and nameLabel and idLabel and button then
        -- Set backpack image
        local imagePath = string.format('/images/items/%d.png', backpack.id)
        if g_resources.fileExists(imagePath) then
          image:setImageSource(imagePath)
        end
        
        -- Set backpack labels
        nameLabel:setText(backpack.name)
        idLabel:setText(string.format('ID: %d', backpack.id))
        print('[AutoLoot Debug] Labels definidos:', backpack.name, 'ID:', backpack.id)
        
        -- Check if this backpack was previously selected
        local isSelected = (lastSelectedBackpackId == backpack.id)
        if isSelected then
          print('[AutoLoot Debug] Backpack', backpack.name, 'foi selecionado anteriormente')
          button:setText('Selected')
          button:setBackgroundColor('#2a4a2a')
          button:setColor('#90EE90')
        else
          button:setText('Select')
          button:setBackgroundColor('#2a2a4a')
          button:setColor('#87CEEB')
        end
        
        -- Set select button action
        print('[AutoLoot Debug] Definindo onClick para botão de', backpack.name)
        button.onClick = function()
          print('[AutoLoot Debug] Botão SELECT clicado para backpack:', backpack.name, 'ID:', backpack.id)
          print('[AutoLoot Debug] Modal antes da seleção - visível?', backpackSelectorModal:isVisible())
          
          -- Visual feedback - change button to show selection
          button:setText('Selected')
          button:setBackgroundColor('#2a4a2a')
          button:setColor('#90EE90')
          
          -- Reset all other buttons
          local listPanel = backpackSelectorModal:recursiveGetChildById('modalBackpackListPanel')
          if listPanel then
            for _, child in ipairs(listPanel:getChildren()) do
              local otherButton = child:getChildById('selectButton')
              if otherButton and otherButton ~= button then
                otherButton:setText('Select')
                otherButton:setBackgroundColor('#2a2a4a')
                otherButton:setColor('#87CEEB')
              end
            end
          end
          
          onBackpackSelect(backpack.id, backpack.name)
          print('[AutoLoot Debug] Modal após seleção - visível?', backpackSelectorModal:isVisible())
        end
        print('[AutoLoot Debug] onClick definido com sucesso')
      end
    end
  end
  
  -- Force layout update for proper scrolling
  listPanel:updateLayout()
  
  -- Ensure scrollbar is working
  local scrollBar = backpackSelectorModal:getChildById('modalBackpackScrollBar')
  if scrollBar then
    scrollBar:setMaximum(#backpacks * 40) -- 40 = height of each row + spacing
    scrollBar:setStep(40)
    print('[AutoLoot Debug] Scrollbar configurado para', #backpacks, 'itens')
  end
  
  print('[AutoLoot Debug] Modal de backpacks atualizado com', #backpacks, 'itens com estado preservado')
end

function onBackpackModalEscape()
  print('[AutoLoot Debug] ESC pressionado no modal de backpack')
  if backpackSelectorModal then
    print('[AutoLoot Debug] Tentando esconder modal via ESC')
    backpackSelectorModal:hide()
    print('[AutoLoot Debug] Modal escondido via ESC')
  else
    print('[AutoLoot Debug] ERRO: backpackSelectorModal não existe para ESC')
  end
end

function onCancelBackpackSelection()
  print('[AutoLoot Debug] Cancel função chamada via @onClick')
  if backpackSelectorModal then
    print('[AutoLoot Debug] Tentando esconder modal via Cancel')
    backpackSelectorModal:hide()
    print('[AutoLoot Debug] Modal escondido via Cancel')
  else
    print('[AutoLoot Debug] ERRO: backpackSelectorModal não existe para Cancel')
  end
end



local function onSelectBackpackButtonClick()
  print('[AutoLoot Debug] Botão Choose Backpack clicado')
  
  -- Always recreate the modal to ensure fresh state
  if backpackSelectorModal then
    print('[AutoLoot Debug] Destruindo modal existente para recriar')
    backpackSelectorModal:destroy()
    backpackSelectorModal = nil
  end
  
  -- Create fresh modal
  print('[AutoLoot Debug] Criando novo backpackSelectorModal')
  backpackSelectorModal = g_ui.createWidget('BackpackSelectorModal', g_ui.getRootWidget())
  print('[AutoLoot Debug] Modal criado:', backpackSelectorModal and 'SUCESSO' or 'FALHA')
  
  -- Configure modal events
  backpackSelectorModal.onHide = function()
    print('[AutoLoot Debug] Modal sendo ocultado (evento onHide)')
  end
  
  backpackSelectorModal.onKeyPress = function(self, keyCode)
    if keyCode == KeyEscape then
      print('[AutoLoot Debug] ESC detectado via onKeyPress')
      self:hide()
      return true
    end
    return false
  end
  
  -- Configure cancel button
  local cancelButton = backpackSelectorModal:recursiveGetChildById('cancelButton')
  if cancelButton then
    print('[AutoLoot Debug] Cancel button encontrado, configurando onClick')
    cancelButton.onClick = function()
      print('[AutoLoot Debug] Cancel button clicado - fechando modal')
      if backpackSelectorModal and backpackSelectorModal:isVisible() then
        backpackSelectorModal:hide()
      end
    end
  else
    print('[AutoLoot Debug] ERRO: Cancel button não encontrado!')
  end
  
  print('[AutoLoot Debug] Modal criado com sucesso')
  
  -- Reset modal header text when opening
  local headerLabel = backpackSelectorModal:recursiveGetChildById('headerPanel'):getChildren()[1]
  if headerLabel then
    headerLabel:setText('Choose a backpack for gold storage')
    headerLabel:setColor('#FFD700')
  end
  
  -- Show modal
  backpackSelectorModal:show()
  backpackSelectorModal:raise()
  backpackSelectorModal:focus()
  print('[AutoLoot Debug] Modal mostrado')
  
  -- Request backpack data immediately
  print('[AutoLoot Debug] Solicitando lista de backpacks do servidor')
  local protocol = g_game.getProtocolGame()
  if protocol then
    local data = { action = "listBackpacks" }
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
  else
    print('[AutoLoot Debug] ERRO: Protocol não encontrado')
  end
end

local function onExtendedAutoLootData(protocol, opcode, buffer)
  local data = json.decode(buffer)
  print('[AutoLoot Debug] Recebido do servidor:', buffer)
  
  -- Handle backpack list response
  if data and data.action == "backpackList" and data.backpacks then
    print('[AutoLoot Debug] Recebida lista de backpacks com ' .. #data.backpacks .. ' itens')
    print('[AutoLoot Debug] Modal existe no handler?', backpackSelectorModal and 'SIM' or 'NÃO')
    
    -- Ensure modal exists before updating
    if not backpackSelectorModal then
      print('[AutoLoot Debug] ERRO CRÍTICO: Modal não existe no handler da resposta!')
      print('[AutoLoot Debug] Isso indica problema de timing ou escopo')
      return
    end
    
    -- Check if modal is visible (should be, since we just requested data)
    if not backpackSelectorModal:isVisible() then
      print('[AutoLoot Debug] Modal não está visível, mas recebemos dados de backpack')
    end
    
    print('[AutoLoot Debug] Chamando updateBackpackList...')
    updateBackpackList(data.backpacks)
    return
  end
  
  -- Feedback visual se for resposta de ação
  if data and data.feedback and data.message then
    if data.feedback == "success" or data.feedback == "info" then
      displayInfoBox("AutoLoot", data.message)
      -- Atualiza o texto do botão de gold se a mensagem for sobre gold
      if data.message:find("gold has been enabled") or data.message:find("Gold autoloot has been enabled") then
        setMoneyButtonText(true)
        updateGoldBackpackStatus(data.message, true)
      elseif data.message:find("gold has been disabled") or data.message:find("Gold autoloot has been disabled") then
        setMoneyButtonText(false)
        updateGoldBackpackStatus(data.message, false)
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
    -- Atualiza a interface se a janela existir
    if autolootWindow then
      local lootListPanel = autolootWindow:recursiveGetChildById('lootListPanel')
      if lootListPanel then
        print('[AutoLoot Debug] lootListPanel encontrado')
        print('[AutoLoot Debug] Atualizando lista com ' .. #data .. ' itens')
        print('[AutoLoot Debug] lootListPanel:', lootListPanel)
        print('[AutoLoot Debug] lootListPanel visível?', lootListPanel:isVisible())
        local panelSize = lootListPanel:getSize()
        local panelPos = lootListPanel:getPosition()
        print('[AutoLoot Debug] lootListPanel tamanho:', panelSize.width .. 'x' .. panelSize.height)
        print('[AutoLoot Debug] lootListPanel posição:', panelPos.x .. ',' .. panelPos.y)
        
        -- Verificar se o parent está visível
        local parent = lootListPanel:getParent()
        if parent then
          print('[AutoLoot Debug] Parent do lootListPanel visível?', parent:isVisible())
          local parentSize = parent:getSize()
          print('[AutoLoot Debug] Parent tamanho:', parentSize.width .. 'x' .. parentSize.height)
        end
        
        -- Forçar tamanho mínimo se necessário
        if panelSize.width < 50 or panelSize.height < 50 then
          print('[AutoLoot Debug] Painel muito pequeno, forçando tamanho mínimo')
          lootListPanel:setSize({width = 250, height = 200})
        end
        
        lootListPanel:destroyChildren()
        
        for i, loot in ipairs(data) do
          print('[AutoLoot Debug] Criando widget para item ' .. i .. ': ' .. loot.name)
          print('[AutoLoot Debug] Verificando se AutoLootListRow existe...')
          
          -- Test if style exists
          local testWidget = g_ui.createWidget('Panel')
          if testWidget then
            testWidget:destroy()
            print('[AutoLoot Debug] Panel básico funciona')
          end
          
          print('[AutoLoot Debug] Tentando g_ui.createWidget AutoLootListRow...')
          local row = g_ui.createWidget('AutoLootListRow', lootListPanel)
          if not row then
            print('[AutoLoot] ERROR: Failed to create AutoLootListRow widget')
            return
          end
          print('[AutoLoot Debug] Widget criado com sucesso, ID:', row:getId())
          print('[AutoLoot Debug] Widget visível?', row:isVisible())
          print('[AutoLoot Debug] Widget tamanho:', row:getSize())
          
          -- Force visible and size
          row:setVisible(true)
          row:setHeight(40)
          print('[AutoLoot Debug] Widget após forçar visibilidade e altura:', row:getSize())
          
          local itemImage = row:getChildById('itemImage')
          local itemInfo = row:getChildById('itemInfo')
          local itemLabel = itemInfo and itemInfo:getChildById('itemLabel')
          local itemIdLabel = itemInfo and itemInfo:getChildById('itemIdLabel')
          local removeButton = row:getChildById('removeButton')
          
          print('[AutoLoot Debug] Elementos encontrados:')
          print('[AutoLoot Debug] - itemImage:', itemImage and 'OK' or 'MISSING')
          print('[AutoLoot Debug] - itemLabel:', itemLabel and 'OK' or 'MISSING')
          print('[AutoLoot Debug] - itemIdLabel:', itemIdLabel and 'OK' or 'MISSING')  
          print('[AutoLoot Debug] - removeButton:', removeButton and 'OK' or 'MISSING')
          
          if not itemImage or not itemLabel or not itemIdLabel or not removeButton then
            row:destroy()
            return
          end
          
          -- Set item image
          local imagePath = string.format('/images/items/%d.png', loot.id)
          print('[AutoLoot Debug] Tentando carregar imagem:', imagePath)
          if g_resources.fileExists(imagePath) then
            itemImage:setImageSource(imagePath)
            print('[AutoLoot Debug] Imagem carregada com sucesso')
          else
            print(string.format('[AutoLoot] Warning: Image not found for item %d: %s', loot.id, imagePath))
            itemImage:setImageSource('')
          end
          
          -- Set item labels
          local itemText = string.format('%d. %s', i, loot.name)
          local itemIdText = string.format('ID: %d', loot.id)
          itemLabel:setText(itemText)
          itemIdLabel:setText(itemIdText)
          print('[AutoLoot Debug] Labels definidos:', itemText, '|', itemIdText)
          
          -- Verificar se o texto foi definido
          print('[AutoLoot Debug] Texto atual do label:', itemLabel:getText())
          print('[AutoLoot Debug] Texto atual do ID label:', itemIdLabel:getText())
          
          -- Forçar estilos para garantir visibilidade
          itemLabel:setColor('#FFD700') -- Dourado
          itemLabel:setVisible(true)
          itemIdLabel:setColor('#888888') -- Cinza
          itemIdLabel:setVisible(true)
          itemImage:setVisible(true)
          removeButton:setVisible(true)
          removeButton:setText('X')
          
          print('[AutoLoot Debug] Estilos forçados nos elementos')
          
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
      else
        print('[AutoLoot Debug] ERRO: lootListPanel não encontrado!')
      end
    else
      print('[AutoLoot Debug] ERRO: autolootWindow não existe!')
    end
    -- (opcional) print no console
    for i, loot in ipairs(data) do
      print(string.format('%d. %s (ID: %d)', i, loot.name, loot.id))
    end
  else
  end
end

function requestAutoLoot()
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, '{}')
  else
    print('[AutoLoot] ERROR: game protocol not available!')
  end
end

local function checkGoldBackpackStatus()
  -- Verificar se o player tem uma bag (ID: 2004) no inventário
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  local hasBag = false
  -- Verificar slots do inventário (slots 1-10)
  for slot = 1, 10 do
    local item = player:getInventoryItem(slot)
    if item then
      -- Função recursiva para verificar containers
      local function checkContainer(container)
        if container:getId() == 2004 then
          return true
        end
        if container:isContainer() then
          for i = 0, container:getItemsCount() - 1 do
            local childItem = container:getItem(i)
            if childItem and childItem:isContainer() then
              if checkContainer(childItem) then
                return true
              end
            end
          end
        end
        return false
      end
      
      if checkContainer(item) then
        hasBag = true
        break
      end
    end
  end
  
  -- Atualizar o status baseado na presença da bag
  if autolootWindow then
    local statusLabel = autolootWindow:recursiveGetChildById('goldBackpackStatus')
    if statusLabel then
      if hasBag then
        statusLabel:setText('Gold → Bag (100%)')
        statusLabel:setColor('#90EE90')
      else
        statusLabel:setText('Gold → Bank (70%, fee: 30%)')
        statusLabel:setColor('#FFA500')
      end
    end
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
    
    -- Limpar o campo após enviar
    addItemEdit:setText("")
  end
end

local function onMoneyButtonClick()
  local protocol = g_game.getProtocolGame()
  if protocol then
    local data = { action = "gold" }
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
    
    -- Agendar uma verificação do status da backpack após o click
    scheduleEvent(function()
      checkGoldBackpackStatus()
    end, 200)
  end
end

function init()
  -- Load the UI styles
  g_ui.importStyle('autoloot')
  g_ui.importStyle('autolootitem')
    
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
      -- Inicializar status da backpack de gold
      if autolootWindow then
        local statusLabel = autolootWindow:recursiveGetChildById('goldBackpackStatus')
        if statusLabel then
          statusLabel:setText('Bank (70%, fee: 30%)')
          statusLabel:setColor('#FFA500')
        end
      end
    else
      print('[AutoLoot] ERROR: g_ui.getRootWidget is not available!')
    end
  end)
  
  -- Add button to the top menu
  setupTopMenuButton()
  
  if ProtocolGame and ProtocolGame.registerExtendedOpcode then
    ProtocolGame.registerExtendedOpcode(ExtendedIds.AutoLootData, onExtendedAutoLootData)
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
      local selectBackpackButton = autolootWindow:recursiveGetChildById('selectBackpackButton')
      if selectBackpackButton then
        print('[AutoLoot Debug] Conectando botão selectBackpackButton')
        selectBackpackButton.onClick = onSelectBackpackButtonClick
      else
        print('[AutoLoot Debug] ERRO: selectBackpackButton não encontrado!')
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
  autolootButton = modules.client_topmenu.addRightGameToggleButton(
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
        checkGoldBackpackStatus() -- Verificar status da backpack de gold
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
    checkGoldBackpackStatus() -- Verificar status da backpack de gold
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