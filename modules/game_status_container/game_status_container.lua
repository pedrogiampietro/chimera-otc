local gameStart = 0

-- Definir constantes dos slots de inventário
local InventorySlotRight = 5
local InventorySlotLeft = 6

-- Ícones específicos para cada slot com tooltips e IDs elementais
local statusIcons = {
    [1] = {
        path = '/images/game/states/burning',
        tooltip = tr('Burning: You are on fire!'),
        elementalId = 5336
    }, -- Fire
    [2] = {
        path = '/images/game/states/dazzled',
        tooltip = tr('Dazzled: Your vision is impaired!'),
        elementalId = 5332
    }, -- Holy
    [3] = {
        path = '/images/game/states/electrified',
        tooltip = tr('Electrified: Electricity courses through you!'),
        elementalId = 5333
    }, -- Energy
    [4] = {
        path = '/images/game/states/freezing',
        tooltip = tr('Freezing: You are freezing cold!'),
        elementalId = 5335
    }, -- Ice
    [5] = {
        path = '/images/game/states/poisoned',
        tooltip = tr('Poisoned: Poison is in your veins!'),
        elementalId = 5334
    }, -- Earth
    [6] = {
        path = '/images/game/states/logout_block',
        tooltip = tr('Reset: Return to base form'),
        elementalId = 5331
    } -- Base form
}

local statusContainerWindow = nil
local statusContainerSlots = {}
local activeSlot = nil -- Rastreia qual slot está ativo
local STATUS_CONTAINER_OPCODE = 0x51 -- Opcode diferente do special container

function init()
    connect(g_game, {onGameStart = markStart, onGameEnd = clean})
    ProtocolGame.registerExtendedOpcode(STATUS_CONTAINER_OPCODE,
                                        onStatusContainerExtendedOpcode)
    reloadStatusContainer()
end

function terminate()
    disconnect(g_game, {onGameStart = markStart, onGameEnd = clean})
    ProtocolGame.unregisterExtendedOpcode(STATUS_CONTAINER_OPCODE,
                                          onStatusContainerExtendedOpcode)
    clean()
end

function reloadStatusContainer()
    clean()
    -- Não há necessidade de conectar a containers existentes, pois este é um container fixo
end

function clean()
    if statusContainerWindow then
        statusContainerWindow:destroy()
        statusContainerWindow = nil
        statusContainerSlots = {}
        activeSlot = nil -- Resetar slot ativo
    end
end

function markStart()
    gameStart = g_clock.millis()
    -- Restore active slot after game start
    addEvent(function() restoreActiveSlot() end, 1000) -- Delay to ensure everything is loaded
end

function restoreActiveSlot()
    if not g_game.isOnline() then return end

    -- Request active slot from server
    local payload = json.encode({action = 'get_active_slot'})

    if g_game.sendExtendedOpcode then
        g_game.sendExtendedOpcode(STATUS_CONTAINER_OPCODE, payload)
    else
        local protocol = g_game.getProtocolGame()
        if protocol and protocol.sendExtendedOpcode then
            protocol:sendExtendedOpcode(STATUS_CONTAINER_OPCODE, payload)
        end
    end
end

function updateSlotAppearance(slot, isActive)
    if not slot then return end

    if isActive then
        slot:setBorderColor('#00ff00') -- Borda verde para ativo
        slot:setImageColor('#ffffff') -- Imagem mais brilhante
        slot:setBorderWidth(2) -- Borda fina para ativo
    else
        slot:setBorderColor('#444444') -- Borda padrão
        slot:setImageColor('#cccccc') -- Cor normal
        slot:setBorderWidth(1) -- Borda mais fina para padrão
    end
end

function setActiveSlot(slotIndex, attemptTransform)
    if attemptTransform == nil then attemptTransform = true end
    activeSlot = slotIndex

    -- Tentar transformar o item equipado se for uma arma transformável
    if attemptTransform then tryTransformWeapon(slotIndex) end

    -- Atualizar aparência de todos os slots
    for i = 1, 6 do
        local slot = statusContainerSlots[i]
        updateSlotAppearance(slot, i == activeSlot)
    end
end

function tryTransformWeapon(slotIndex)
    if not statusIcons[slotIndex] then return end

    local player = g_game.getLocalPlayer()
    if not player then return end

    -- Verificar mão direita e esquerda
    local rightHand = player:getInventoryItem(InventorySlotRight)
    local leftHand = player:getInventoryItem(InventorySlotLeft)

    -- Sempre enviar o ID do item equipado para o servidor decidir
    local equippedId = nil
    local equippedSlot = nil

    if rightHand and type(rightHand) == 'userdata' and rightHand.getId then
        equippedId = rightHand:getId()
        equippedSlot = "right"
    elseif leftHand and type(leftHand) == 'userdata' and leftHand.getId then
        equippedId = leftHand:getId()
        equippedSlot = "left"
    end

    if not equippedId then return end

    local payload = json.encode({
        action = 'transform_elemental',
        element = slotIndex,
        equipped_item_id = equippedId
    })

    if g_game.sendExtendedOpcode then
        g_game.sendExtendedOpcode(STATUS_CONTAINER_OPCODE, payload)
        modules.game_textmessage.displayGameMessage(tr(
                                                        'Attempting to transform weapon...'))
    else
        local protocol = g_game.getProtocolGame()
        if protocol and protocol.sendExtendedOpcode then
            protocol:sendExtendedOpcode(STATUS_CONTAINER_OPCODE, payload)
            modules.game_textmessage.displayGameMessage(tr(
                                                            'Attempting to transform weapon...'))
        end
    end
end

function onStatusContainerExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= STATUS_CONTAINER_OPCODE then return end

    if not buffer or buffer:len() == 0 then return end

    local status, data = pcall(function() return json.decode(buffer) end)
    if not status or type(data) ~= 'table' then return end

    local action = data.action
    if action == 'transform_success' then
        modules.game_textmessage.displayGameMessage(tr(
                                                        'Weapon transformed successfully!'))
    elseif action == 'transform_failed' then
        modules.game_textmessage.displayGameMessage(tr(
                                                        'Failed to transform weapon.'))
    elseif action == 'set_active_slot' then
        -- Restore the active slot from server
        if data.slot and data.slot >= 1 and data.slot <= 6 then
            setActiveSlot(data.slot, false)
        end
    end
end

function toggleStatusContainer()
    if statusContainerWindow and statusContainerWindow:isVisible() then
        statusContainerWindow:close()
    else
        openStatusContainer()
    end
end

function openStatusContainer()
    if not statusContainerWindow then
        -- Criar MiniWindow dinamicamente
        statusContainerWindow = g_ui.createWidget('MiniWindow',
                                                  modules.game_interface
                                                      .getRightPanel())

        if not statusContainerWindow then
            g_logger.error("Failed to create status container window")
            return
        end

        statusContainerWindow:setId('statusContainerWindow')
        statusContainerWindow:setText(tr('Status Container'))
        statusContainerWindow:setHeight(85)
        statusContainerWindow:setWidth(240) -- Aumentado para acomodar 6 ícones
        statusContainerWindow:disableResize()
        statusContainerWindow:setup()

        -- Obter o painel de conteúdo
        local contentsPanel =
            statusContainerWindow:getChildById('contentsPanel') or
                statusContainerWindow:getChildById('miniwindowContents')

        if not contentsPanel then
            -- Criar painel de conteúdo manualmente
            contentsPanel = g_ui.createWidget('Panel', statusContainerWindow)
            contentsPanel:setId('contentsPanel')
            contentsPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
            contentsPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            contentsPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
            contentsPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
            contentsPanel:setMarginTop(28)
            contentsPanel:setMarginLeft(6)
            contentsPanel:setMarginRight(6)
            contentsPanel:setMarginBottom(3)
        end

        contentsPanel:setPadding(2)
        contentsPanel:setClipping(false)

        -- Desabilitar scrollbar se existir
        local scrollbar = statusContainerWindow:getChildById(
                              'miniwindowScrollBar')
        if scrollbar then
            scrollbar:setVisible(false)
            scrollbar:disable()
        end

        -- Criar 6 slots com ícones fixos
        statusContainerSlots = {}

        for i = 1, 6 do
            local slot = g_ui.createWidget('Item', contentsPanel)
            slot:setId('statusSlot' .. i)
            slot:setImageSource('/images/ui/item')
            slot:setWidth(28) -- Diminuído de 34 para 28
            slot:setHeight(28) -- Diminuído de 34 para 28
            slot:setPhantom(false)
            slot:setVisible(true)
            slot:setFocusable(true) -- Tornar focável para interações

            -- Definir o ícone específico para o slot
            if statusIcons[i] then
                slot:setImageSource(statusIcons[i].path)
                slot:setTooltip(statusIcons[i].tooltip)
            end

            -- Configurar aparência inicial
            updateSlotAppearance(slot, false)

            -- Efeitos de hover
            slot.onHoverChange = function(self, hovered)
                if hovered and i ~= activeSlot then
                    self:setBorderColor('#ffff00') -- Borda amarela no hover
                    self:setImageColor('#ffffff') -- Brilho na imagem
                elseif not hovered and i ~= activeSlot then
                    updateSlotAppearance(self, false) -- Voltar ao padrão
                end
                -- Se estiver ativo, manter a aparência ativa mesmo no hover
            end

            -- Ação ao clicar
            slot.onClick = function(self)
                setActiveSlot(i) -- Definir este slot como ativo
            end

            slot:addAnchor(AnchorTop, 'parent', AnchorTop)
            slot:setMarginTop(2)
            slot:setMarginBottom(2)

            if i == 1 then
                slot:addAnchor(AnchorLeft, 'parent', AnchorLeft)
                slot:setMarginLeft(10)
            else
                slot:addAnchor(AnchorLeft, 'prev', AnchorRight)
                slot:setMarginLeft(4)
            end

            statusContainerSlots[i] = slot
        end
    end

    if statusContainerWindow then
        statusContainerWindow:open()
        statusContainerWindow:setup()

        -- Atualizar aparência dos slots após abrir
        for i = 1, 6 do
            local slot = statusContainerSlots[i]
            updateSlotAppearance(slot, i == activeSlot)
        end
    end
end

function onStatusContainerClose()
    if statusContainerWindow then statusContainerWindow:hide() end
end
