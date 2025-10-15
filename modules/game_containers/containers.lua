local gameStart = 0

function init()
	connect(Container, {
		onOpen = onContainerOpen,
		onClose = onContainerClose,
		onSizeChange = onContainerChangeSize,
		onUpdateItem = onContainerUpdateItem
	})
	connect(g_game, {
		onGameStart = markStart,
		onGameEnd = clean
	})
	reloadContainers()
end

function terminate()
	disconnect(Container, {
		onOpen = onContainerOpen,
		onClose = onContainerClose,
		onSizeChange = onContainerChangeSize,
		onUpdateItem = onContainerUpdateItem
	})
	disconnect(g_game, {
		onGameStart = markStart,
		onGameEnd = clean
	})
end

function reloadContainers()
	clean()

	for _, container in pairs(g_game.getContainers()) do
		onContainerOpen(container)
	end
end

function clean()
	for containerid, container in pairs(g_game.getContainers()) do
		destroy(container)
	end
end

function markStart()
	gameStart = g_clock.millis()
end

function destroy(container)
	if container.window then
		container.window:destroy()

		container.window = nil
		container.itemsPanel = nil
	end
end

function refreshContainerItems(container)
    for slot = 0, container:getCapacity() - 1 do
        local itemWidget = container.itemsPanel:getChildById("item" .. slot)
        local item = container:getItem(slot)
        local tip = item and item:getTooltip() and item:getTooltip():lower() or ""
        
        local src = ""
        if tip:find("%[legendary%]") or tip:find(" legendary") then
            src = "/images/ui/rarity_gold"
        elseif tip:find("%[epic%]") or tip:find(" epic") then
            src = "/images/ui/rarity_purple"
        elseif tip:find("%[common%]") or tip:find(" common") then
            src = "/images/ui/rarity_white"
        elseif tip:find("%[rare%]") or tip:find(" rare") then
            src = "/images/ui/rarity_blue"
        end
        
        itemWidget:setImageSource(src)
        itemWidget:setTooltip(nil) -- Desabilitado para usar apenas tooltips personalizados
        itemWidget:setItem(item)
    end

    if container:hasPages() then
        refreshContainerPages(container)
    end
end

function toggleContainerPages(containerWindow, hasPages)
	if hasPages == containerWindow.pagePanel:isOn() then
		return
	end

	containerWindow.pagePanel:setOn(hasPages)

	if hasPages then
		containerWindow.miniwindowScrollBar:setMarginTop(containerWindow.miniwindowScrollBar:getMarginTop() + containerWindow.pagePanel:getHeight())
		containerWindow.contentsPanel:setMarginTop(containerWindow.contentsPanel:getMarginTop() + containerWindow.pagePanel:getHeight())
	else
		containerWindow.miniwindowScrollBar:setMarginTop(containerWindow.miniwindowScrollBar:getMarginTop() - containerWindow.pagePanel:getHeight())
		containerWindow.contentsPanel:setMarginTop(containerWindow.contentsPanel:getMarginTop() - containerWindow.pagePanel:getHeight())
	end
end

function refreshContainerPages(container)
	local currentPage = 1 + math.floor(container:getFirstIndex() / container:getCapacity())
	local pages = 1 + math.floor(math.max(0, container:getSize() - 1) / container:getCapacity())

	container.window:recursiveGetChildById("pageLabel"):setText(string.format("Page %i of %i", currentPage, pages))

	local prevPageButton = container.window:recursiveGetChildById("prevPageButton")

	if currentPage == 1 then
		prevPageButton:setEnabled(false)
	else
		prevPageButton:setEnabled(true)

		function prevPageButton.onClick()
			g_game.seekInContainer(container:getId(), container:getFirstIndex() - container:getCapacity())
		end
	end

	local nextPageButton = container.window:recursiveGetChildById("nextPageButton")

	if pages <= currentPage then
		nextPageButton:setEnabled(false)
	else
		nextPageButton:setEnabled(true)

		function nextPageButton.onClick()
			g_game.seekInContainer(container:getId(), container:getFirstIndex() + container:getCapacity())
		end
	end

	local pagePanel = container.window:recursiveGetChildById("pagePanel")

	if pagePanel then
		function pagePanel.onMouseWheel(widget, mousePos, mouseWheel)
			if pages == 1 then
				return
			end

			if mouseWheel == MouseWheelUp then
				return prevPageButton.onClick()
			else
				return nextPageButton.onClick()
			end
		end
	end
end

local function setFrames()
	for _, container in pairs(g_game.getContainers()) do
	  local panel = container.itemsPanel
	  for _, child in pairs(panel:getChildren()) do
		local tip = (child:getTooltip() or ""):lower()
		local src = "/images/ui/item"
		if tip:find("%[legendary%]") or tip:find(" legendary") then
		  src = "/images/ui/rarity_gold"
		elseif tip:find("%[epic%]") or tip:find(" epic") then
		  src = "/images/ui/rarity_purple"
		elseif tip:find("%[common%]") or tip:find(" common") then
		  src = "/images/ui/rarity_white"
		elseif tip:find("%[rare%]") or tip:find(" rare") then
		  src = "/images/ui/rarity_blue"
		end
		child:setImageSource(src)
	  end
	end
end

function onContainerOpen(container, previousContainer)
	local containerWindow = nil

	if previousContainer then
		containerWindow = previousContainer.window
		previousContainer.window = nil
		previousContainer.itemsPanel = nil
	else
		containerWindow = g_ui.createWidget("ContainerWindow", modules.game_interface.getContainerPanel())

		containerWindow:setBorderWidth(2)
		containerWindow:setBorderColor("#FFFFFF")
		scheduleEvent(function ()
			if containerWindow then
				containerWindow:setBorderWidth(0)
			end
		end, 300)
	end

	containerWindow:setId("container" .. container:getId())

	if gameStart + 1000 < g_clock.millis() then
		containerWindow:clearSettings()
	end

	local containerPanel = containerWindow:getChildById("contentsPanel")
	local containerItemWidget = containerWindow:getChildById("containerItemWidget")

	function containerWindow.onClose()
		g_game.close(container)
		containerWindow:hide()
	end

	function containerWindow.onDrop(container, widget, mousePos)
		if containerPanel:getChildByPos(mousePos) then
			return false
		end

		local child = containerPanel:getChildByIndex(-1)

		if child then
			child:onDrop(widget, mousePos, true)
		end
	end

	function containerWindow.onMouseRelease(widget, mousePos, mouseButton)
		if mouseButton == MouseButton4 then
			if container:hasParent() then
				return g_game.openParent(container)
			end
		elseif mouseButton == MouseButton5 then
			for i, item in ipairs(container:getItems()) do
				if item:isContainer() then
					return g_game.open(item, container)
				end
			end
		end
	end

	local scrollbar = containerWindow:getChildById("miniwindowScrollBar")

	scrollbar:mergeStyle({
		["$!on"] = {}
	})

	local upButton = containerWindow:getChildById("upButton")

	function upButton.onClick()
		g_game.openParent(container)
	end

	upButton:setVisible(container:hasParent())

	local name = container:getName()
	name = name:sub(1, 1):upper() .. name:sub(2)

	containerWindow:setText(name)
	containerItemWidget:setItem(container:getContainerItem())
	containerPanel:destroyChildren()

	for slot = 0, container:getCapacity() - 1 do
		local itemWidget = g_ui.createWidget("Item", containerPanel)

		itemWidget:setId("item" .. slot)
		itemWidget:setItem(container:getItem(slot))
		itemWidget:setMargin(0)
		itemWidget.position = container:getSlotPosition(slot)

		if not container:isUnlocked() then
			itemWidget:setBorderColor("red")
		end
	end

	container.window = containerWindow
	container.itemsPanel = containerPanel

	toggleContainerPages(containerWindow, container:hasPages())
	refreshContainerPages(container)

	local layout = containerPanel:getLayout()
	local cellSize = layout:getCellSize()

	containerWindow:setContentMinimumHeight(cellSize.height)
	containerWindow:setContentMaximumHeight(cellSize.height * layout:getNumLines())

	if container:hasPages() then
		local height = containerWindow.miniwindowScrollBar:getMarginTop() + containerWindow.pagePanel:getHeight() + 17

		if containerWindow:getHeight() < height then
			containerWindow:setHeight(height)
		end
	end

	if not previousContainer then
		local filledLines = math.max(math.ceil(container:getItemsCount() / layout:getNumColumns()), 1)

		containerWindow:setContentHeight(filledLines * cellSize.height)
	end

	setFrames()
	containerWindow:setup()
end

function onContainerClose(container)
	destroy(container)
end

function onContainerChangeSize(container, size)
	if not container.window then
		return
	end

	refreshContainerItems(container)
	setFrames()
end

function onContainerUpdateItem(container, slot, item, oldItem)
	if not container.window then
		return
	end

	local itemWidget = container.itemsPanel:getChildById("item" .. slot)

	itemWidget:setItem(item)
	setFrames()
end
