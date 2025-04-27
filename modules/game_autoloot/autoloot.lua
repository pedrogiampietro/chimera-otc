-- Game AutoLoot Module for OTClient
-- This module will add an autoloot button and window

-- Defina os opcodes usados para autoloot
ExtendedIds = ExtendedIds or {}
ExtendedIds.AutoLootData = 210  -- Escolha um número livre e consistente com o servidor
ExtendedIds.AutoLootRequest = 211

local autolootButton = nil
autolootWindow = nil

local function onExtendedAutoLootData(protocol, opcode, buffer)
  local data = json.decode(buffer)
  -- Feedback visual se for resposta de ação
  if data and data.feedback and data.message then
    if data.feedback == "success" then
      displayInfoBox("AutoLoot", data.message)
    elseif data.feedback == "error" then
      displayErrorBox("AutoLoot", data.message)
    else
      displayInfoBox("AutoLoot", data.message)
    end
    return
  end
  if data and type(data) == 'table' then
    print('[AutoLoot] Lista de loots recebida:')
    -- Atualiza a interface somente se a janela existir e estiver visível
    if autolootWindow and autolootWindow:isVisible() then
      local lootListPanel = autolootWindow:recursiveGetChildById('lootListPanel')
      if lootListPanel then
        lootListPanel:destroyChildren()
        for i, loot in ipairs(data) do
          local label = g_ui.createWidget('UILabel', lootListPanel)
          label:setText(string.format('%d. %s (ID: %d)', i, loot.name, loot.id))
          label:setFont('verdana-11px-rounded')
          label:setColor('#FFD700')
          label:setTextAlign(AlignLeft)
          label:setHeight(24)
          label:setMarginTop(2)
          label:setMarginBottom(2)
          -- Removido setWidth e setPosition para layout automático
        end
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
    print('[AutoLoot] Pedido de lista de loots enviado ao servidor.')
  else
    print('[AutoLoot] ERRO: protocolo de jogo não disponível!')
  end
end

local function onAddItemButtonClick()
  if not autolootWindow then return end
  local addItemEdit = autolootWindow:recursiveGetChildById('addItemEdit')
  if not addItemEdit then return end
  local itemName = addItemEdit:getText():trim()
  if itemName == "" then
    displayInfoBox("AutoLoot", "Digite o nome do item para adicionar.")
    return
  end

  -- Envie o pedido para o servidor (action = "add")
  local protocol = g_game.getProtocolGame()
  if protocol then
    local data = { action = "add", item = itemName }
    protocol:sendExtendedOpcode(ExtendedIds.AutoLootRequest, json.encode(data))
  end
end

function init()
  print('[AutoLoot] Módulo carregado!')
  -- Load the UI style
  g_ui.importStyle('autoloot')
  
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
    else
      print('[AutoLoot] ERRO: g_ui.getRootWidget não está disponível!')
    end
  end)
  
  -- Add button to the top menu
  setupTopMenuButton()
  
  if ProtocolGame and ProtocolGame.registerExtendedOpcode then
    ProtocolGame.registerExtendedOpcode(ExtendedIds.AutoLootData, onExtendedAutoLootData)
    print('[AutoLoot] Opcode de autoloot registrado!')
  else
    print('[AutoLoot] ERRO: ProtocolGame.registerExtendedOpcode não está disponível!')
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
    end
  end)
end

function terminate()
  if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    ProtocolGame.unregisterExtendedOpcode(ExtendedIds.AutoLootData)
    print('[AutoLoot] Opcode de autoloot removido!')
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
  if not g_app.isMobile() then
    autolootButton = modules.client_topmenu.addRightGameToggleButton('autolootButton', tr('Auto Loot'), '/images/topbuttons/autoloot',
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
      nil, nil, true)
  else
    g_logger.info("É dispositivo móvel, não criando botão")
  end
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
  autolootButton:setOn(false)
end

function refresh()
  -- Refresh the autoloot settings when game starts
end

function offline()
  -- Clear and hide window when going offline
  autolootWindow:hide()
  autolootButton:setOn(false)
end 