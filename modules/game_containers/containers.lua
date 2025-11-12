local gameStart = 0
local MAX_VISIBLE_CONTAINERS = 8 -- Maximum containers visible at once per panel

-- Heuristic to detect corpse/monster loot containers (to be auto-closable)
-- Goal: Do NOT auto-close player backpacks or regular storage containers
local function isAutoClosableLoot(container)
	-- Safeguards
	if not container then return false end

	-- Prefer checking the container item characteristics
	local citem = container:getContainerItem()
	local name = (container:getName() or ""):lower()

	-- Common corpse name patterns across servers
	local isCorpseByName = (name:find('dead') ~= nil)
		or (name:find('remains') ~= nil)
		or (name:find('slain') ~= nil)
		or (name:find('corpse') ~= nil)

	-- If the underlying item is not pickupable and has no parent, it's very likely ground loot (e.g., corpse)
	local isLikelyGroundLoot = false
	if citem and citem.isPickupable and not citem:isPickupable() and (not container:hasParent()) then
		isLikelyGroundLoot = true
	end

	-- Conversely, avoid closing known personal/storage containers by name
	local isPersonalContainerByName = (name:find('backpack') ~= nil)
		or (name:find('bag') ~= nil)
		or (name:find('chest') ~= nil)
		or (name:find('box') ~= nil)
		or (name:find('crate') ~= nil)
		or (name:find('locker') ~= nil)
		or (name:find('depot') ~= nil)
		or (name:find('stash') ~= nil)

	-- Auto-close only monster loot/corpse-like containers, and never personal storage
	return (isCorpseByName or isLikelyGroundLoot) and not isPersonalContainerByName
end

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
    if not container.itemsPanel then
        return
    end
    
    for slot = 0, container:getCapacity() - 1 do
        local itemWidget = container.itemsPanel:getChildById("item" .. slot)
        if not itemWidget then
            return
        end
        
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
	  if panel then
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
end

function onContainerOpen(container, previousContainer)
	local containerWindow = nil

	if previousContainer then
		containerWindow = previousContainer.window
		previousContainer.window = nil
		previousContainer.itemsPanel = nil
	else
	local containerPanel = modules.game_interface.getContainerPanel()
		
		-- Check if we have too many containers open in this panel
		if containerPanel and containerPanel:getClassName() == 'UIMiniWindowContainer' then
			local openContainers = {}
			for _, cont in pairs(g_game.getContainers()) do
				if cont.window and cont.window:isVisible() and cont.window:getParent() == containerPanel then
					-- Only consider auto-closable loot containers here (skip backpacks and personal storage)
					if isAutoClosableLoot(cont) then
						table.insert(openContainers, {container = cont, yPos = cont.window:getY()})
					end
				end
			end
			
			-- Sort by Y position (oldest/highest first)
			table.sort(openContainers, function(a, b) return a.yPos < b.yPos end)
			
			-- Check if we're running out of space (calculate estimated Y position)
			local panelHeight = containerPanel:getHeight()
			local estimatedNextY = 0
			if #openContainers > 0 then
				local lastContainer = openContainers[#openContainers]
				if lastContainer.container.window then
					estimatedNextY = lastContainer.container.window:getY() + lastContainer.container.window:getHeight() + 5
				end
			end
			
			-- Close oldest container if we exceed the limit OR if running out of screen space
			if #openContainers >= MAX_VISIBLE_CONTAINERS or estimatedNextY > (panelHeight - 150) then
				local oldestContainer = openContainers[1]
				if oldestContainer and oldestContainer.container and oldestContainer.container.window then
					-- Close only the oldest auto-closable (loot) container
					g_game.close(oldestContainer.container)
				end
			end
		end
		
		containerWindow = g_ui.createWidget("ContainerWindow", containerPanel)

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
