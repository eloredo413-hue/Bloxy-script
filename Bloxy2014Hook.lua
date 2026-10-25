-- [[ 2014 HOOK — fixes the 2014 backpack when Bloxy loads the 2014 GUI ]]
-- Works when executed before OR after Bloxy, on mobile and PC.
-- 1. Hotbar: every slot gets its own box again instead of one big gray block
-- 2. Inventory: the backpack panel lists every tool you have, so you can use
--    more than what fits in the hotbar
--    tap/click a tool = equip it, drag it onto a hotbar slot = put it there
--    (on mobile hold the tool for a moment first, then drag)

do
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local player = Players.LocalPlayer

	-- same tone the 2014 slots already had, just not overlapping anymore
	local SLOT_COLOR = Color3.fromRGB(47, 47, 47)
	local SLOT_TRANSPARENCY = 0.35
	local DRAG_DISTANCE = 10 -- pixels you have to move before it counts as a drag
	local HOLD_TIME = 0.35 -- mobile: hold this long before dragging (a quick swipe scrolls)

	local function v2(p)
		return Vector2.new(p.X, p.Y)
	end

	------------------------------------------------------------
	-- HOTBAR: the old "DropShadow" boxes stick out 10px on every side,
	-- so the slots melt into one block. Make each box the size of its slot.
	------------------------------------------------------------
	local function restyleSlotBackground(bg)
		if not (bg:IsA("Frame") and bg.Name == "Background") then return end
		bg.Style = Enum.FrameStyle.Custom
		bg.Position = UDim2.new(0, 0, 0, 0)
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = SLOT_COLOR
		bg.BackgroundTransparency = SLOT_TRANSPARENCY
		bg.BorderSizePixel = 0
	end

	local function fixHotbar(loadout)
		for _, d in ipairs(loadout:GetDescendants()) do
			restyleSlotBackground(d)
		end
		loadout.DescendantAdded:Connect(restyleSlotBackground)
	end

	------------------------------------------------------------
	-- INVENTORY: the 2014 port is missing the script that fills the
	-- backpack panel, so it always opens empty. Fill it here.
	------------------------------------------------------------
	local function fixInventory(gui, loadout, backpackFrame)
		local gear = backpackFrame:WaitForChild("Gear", 10)
		if not gear then return end

		-- the 2014 scripts use this same check for phones / small screens
		local small = gui.AbsoluteSize.Y <= 500
		local maxHotbar = small and 4 or 10
		local cell = small and 42 or 58

		local oldGrid = gear:FindFirstChild("GearGrid")
		if oldGrid then oldGrid.Visible = false end

		local grid = Instance.new("ScrollingFrame")
		grid.Name = "InventoryGrid"
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.ScrollingDirection = Enum.ScrollingDirection.Y
		grid.ScrollBarThickness = small and 4 or 8
		grid.ScrollBarImageColor3 = Color3.new(1, 1, 1)
		grid.CanvasSize = UDim2.new(0, 0, 0, 0)
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.ZIndex = 2
		if small then
			grid.Position = UDim2.new(0, 6, 0, 6)
			grid.Size = UDim2.new(1, -12, 1, -12)
		else
			-- leave room for the search bar on top and the preview on the right
			grid.Position = UDim2.new(0, 10, 0, 34)
			grid.Size = UDim2.new(0.7, -14, 1, -44)
		end
		grid.Parent = gear

		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0, cell, 0, cell)
		layout.CellPadding = small and UDim2.new(0, 4, 0, 4) or UDim2.new(0, 6, 0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid

		-- big picture + name of the tool you're pointing at (PC only, no room on phones)
		local preview = gear:FindFirstChild("GearPreview")
		local previewImage = preview and preview:FindFirstChild("GearImage")
		local previewStats = preview and preview:FindFirstChild("GearStats")
		local previewName = previewStats and previewStats:FindFirstChild("GearName")
		if preview then
			if small then
				preview.Visible = false
			else
				preview.Position = UDim2.new(0.7, 4, 0, 34)
				preview.Size = UDim2.new(0.3, -14, 0, 200)
				if previewImage then
					previewImage.Position = UDim2.new(0, 0, 0, 0)
					previewImage.Size = UDim2.new(1, 0, 0, 150)
					previewImage.ScaleType = Enum.ScaleType.Fit
				end
				if previewStats then
					previewStats.Position = UDim2.new(0, 0, 0, 155)
					previewStats.Size = UDim2.new(1, 0, 0, 45)
				end
			end
		end

		local function showPreview(tool)
			if small or not preview then return end
			if previewImage then previewImage.Image = tool.TextureId end
			if previewName then previewName.Text = tool.Name end
		end

		--------------------------------------------------------
		-- equipping / putting tools on the hotbar
		--------------------------------------------------------
		local function toggleEquip(tool)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or not tool.Parent then return end
			if tool.Parent == char then
				hum:UnequipTools()
			else
				hum:EquipTool(tool)
			end
		end

		local function hotbarButtonFor(tool)
			for _, d in ipairs(loadout:GetDescendants()) do
				if d.Name == "GearReference" and d:IsA("ObjectValue") and d.Value == tool then
					return d.Parent
				end
			end
		end

		-- hotbar slot number (1-10) under a point, or nil
		local function slotAt(p)
			for _, f in ipairs(loadout:GetChildren()) do
				local n = f:IsA("Frame") and tonumber(string.match(f.Name, "^Slot(%d+)$"))
				if n then
					local num = (n == 0) and 10 or n
					local pos, size = f.AbsolutePosition, f.AbsoluteSize
					if num <= maxHotbar
						and p.X >= pos.X and p.X <= pos.X + size.X
						and p.Y >= pos.Y and p.Y <= pos.Y + size.Y then
						return num
					end
				end
			end
		end

		-- uses the 2014 "SwapSlot" the hotbar script already listens to
		local function putOnHotbar(tool, num)
			local swap = backpackFrame:FindFirstChild("SwapSlot")
			local swapSlot = swap and swap:FindFirstChild("Slot")
			local swapButton = swap and swap:FindFirstChild("GearButton")
			if not (swapSlot and swapButton) or not tool.Parent or hotbarButtonFor(tool) then return end

			-- unequip the tool we're replacing first, otherwise the hotbar
			-- puts it straight back into the slot we're freeing
			local frame = loadout:FindFirstChild("Slot" .. (num % 10))
			local old = frame and frame:FindFirstChildWhichIsA("ImageButton")
			local oldRef = old and old:FindFirstChild("GearReference")
			local char = player.Character
			if oldRef and oldRef.Value and char and oldRef.Value.Parent == char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum:UnequipTools() end
				task.wait()
			end

			local carrier = Instance.new("Frame")
			local ref = Instance.new("ObjectValue")
			ref.Name = "GearReference"
			ref.Value = tool
			ref.Parent = carrier
			swapSlot.Value = num % 10
			swapButton.Value = carrier
			swap.Value = true
		end

		--------------------------------------------------------
		-- tap / click / drag
		--------------------------------------------------------
		local press = nil

		local function toGui(pos)
			-- input positions skip the top bar inset, this GUI may not
			local p = v2(pos)
			if gui.IgnoreGuiInset then
				p = p + GuiService:GetGuiInset()
			end
			return p
		end

		local function endPress()
			if press and press.ghost then press.ghost:Destroy() end
			press = nil
			grid.ScrollingEnabled = true
		end

		local function startDrag(pos)
			press.dragging = true
			grid.ScrollingEnabled = false
			local ghost = Instance.new("ImageLabel")
			ghost.Name = "DraggedGear"
			ghost.Size = UDim2.new(0, cell, 0, cell)
			ghost.BackgroundColor3 = SLOT_COLOR
			ghost.BackgroundTransparency = SLOT_TRANSPARENCY
			ghost.BorderSizePixel = 0
			ghost.Image = press.tool.TextureId
			ghost.ScaleType = Enum.ScaleType.Fit
			ghost.ZIndex = 10
			if press.tool.TextureId == "" then
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.new(1, 0, 1, 0)
				label.Font = Enum.Font.Arial
				label.TextSize = small and 11 or 14
				label.TextColor3 = Color3.new(1, 1, 1)
				label.TextWrapped = true
				label.Text = press.tool.Name
				label.ZIndex = 11
				label.Parent = ghost
			end
			press.ghost = ghost
			local p = toGui(pos)
			ghost.Position = UDim2.new(0, p.X - cell / 2, 0, p.Y - cell / 2)
			ghost.Parent = gui
		end

		local function beginPress(tool, input)
			local kind = input.UserInputType
			local touch = kind == Enum.UserInputType.Touch
			if kind ~= Enum.UserInputType.MouseButton1 and not touch then return end
			endPress()
			local thisPress = {
				tool = tool,
				input = input,
				start = v2(input.Position),
				touch = touch,
				dragging = false,
			}
			press = thisPress
			showPreview(tool)
			if touch then
				-- held still long enough: pick it up
				task.delay(HOLD_TIME, function()
					if press == thisPress and not press.dragging then
						startDrag(press.input.Position)
					end
				end)
			end
		end

		UserInputService.InputChanged:Connect(function(input)
			if not press then return end
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseMovement and not press.touch
				or kind == Enum.UserInputType.Touch and input == press.input then
				if press.dragging then
					local p = toGui(input.Position)
					press.ghost.Position = UDim2.new(0, p.X - cell / 2, 0, p.Y - cell / 2)
				elseif (v2(input.Position) - press.start).Magnitude >= DRAG_DISTANCE then
					if press.touch then
						endPress() -- quick swipe = scrolling the list, not dragging
					else
						startDrag(input.Position)
					end
				end
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if not press then return end
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 and not press.touch
				or kind == Enum.UserInputType.Touch and input == press.input then
				local done = press
				endPress()
				if done.dragging then
					local num = slotAt(toGui(input.Position))
					if num then
						task.spawn(putOnHotbar, done.tool, num)
					end
				else
					toggleEquip(done.tool)
				end
			end
		end)

		--------------------------------------------------------
		-- building the list
		--------------------------------------------------------
		local order = {} -- tools in the order you got them
		local buttons = {} -- tool -> button
		local searchText = nil

		local function makeButton(tool)
			local b = Instance.new("ImageButton")
			b.Name = "GearButton"
			b.AutoButtonColor = false
			b.BackgroundColor3 = SLOT_COLOR
			b.BackgroundTransparency = SLOT_TRANSPARENCY
			b.BorderSizePixel = 0
			b.BorderColor3 = Color3.new(1, 1, 1)
			b.BorderMode = Enum.BorderMode.Inset
			b.ScaleType = Enum.ScaleType.Fit
			b.ZIndex = 3

			local label = Instance.new("TextLabel")
			label.Name = "GearText"
			label.BackgroundTransparency = 1
			label.Position = UDim2.new(0, 2, 0, 2)
			label.Size = UDim2.new(1, -4, 1, -4)
			label.Font = Enum.Font.Arial
			label.TextSize = small and 11 or 14
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextWrapped = true
			label.ZIndex = 4
			label.Parent = b

			b.InputBegan:Connect(function(input) beginPress(tool, input) end)
			b.MouseEnter:Connect(function() showPreview(tool) end)
			return b
		end

		local function refresh()
			-- only bother while the panel is open, it refreshes again when opened
			if not backpackFrame.Visible then return end

			local char = player.Character
			local backpack = player:FindFirstChildOfClass("Backpack")
			local have, list = {}, {}
			for _, container in ipairs({ backpack or false, char or false }) do
				if container then
					for _, t in ipairs(container:GetChildren()) do
						if t:IsA("Tool") and not t:FindFirstChild("RobloxBuildTool") and not have[t] then
							have[t] = true
							table.insert(list, t)
						end
					end
				end
			end

			-- keep the old order, add new tools at the end
			local newOrder, kept = {}, {}
			for _, t in ipairs(order) do
				if have[t] then
					table.insert(newOrder, t)
					kept[t] = true
				end
			end
			for _, t in ipairs(list) do
				if not kept[t] then table.insert(newOrder, t) end
			end
			order = newOrder

			for t, b in pairs(buttons) do
				if not have[t] then
					b:Destroy()
					buttons[t] = nil
				end
			end

			for i, t in ipairs(order) do
				local b = buttons[t]
				if not b then
					b = makeButton(t)
					buttons[t] = b
					b.Parent = grid
				end
				b.LayoutOrder = i
				b.Image = t.TextureId
				b.GearText.Text = (t.TextureId == "") and t.Name or ""
				b.BorderSizePixel = (t.Parent == char) and 2 or 0 -- white outline = equipped
				b.Visible = not searchText or string.find(t.Name:lower(), searchText, 1, true) ~= nil
			end
		end

		local queued = false
		local function queueRefresh()
			if queued then return end
			queued = true
			task.defer(function()
				queued = false
				refresh()
			end)
		end

		backpackFrame:GetPropertyChangedSignal("Visible"):Connect(function()
			if backpackFrame.Visible then
				refresh()
			else
				endPress()
			end
		end)

		-- the search box at the top of the panel (PC)
		task.spawn(function()
			local manager = backpackFrame:WaitForChild("BackpackManager", 10)
			local searchEvent = manager and manager:WaitForChild("SearchRequestedEvent", 10)
			if not searchEvent then return end
			searchEvent.Event:Connect(function(text)
				text = type(text) == "string" and text:lower() or ""
				if text == "" or text == "search..." then
					searchText = nil
				else
					searchText = text
				end
				refresh()
			end)
		end)

		-- watch the backpack and character for tools coming and going
		local containerConns = {}
		local function watchContainers()
			for _, c in ipairs(containerConns) do c:Disconnect() end
			containerConns = {}
			for _, container in ipairs({ player:FindFirstChildOfClass("Backpack") or false, player.Character or false }) do
				if container then
					table.insert(containerConns, container.ChildAdded:Connect(queueRefresh))
					table.insert(containerConns, container.ChildRemoved:Connect(queueRefresh))
				end
			end
			queueRefresh()
		end
		player.CharacterAdded:Connect(watchContainers)
		player.ChildAdded:Connect(function(c)
			if c:IsA("Backpack") then watchContainers() end
		end)
		watchContainers()
	end

	------------------------------------------------------------
	-- FIND THE 2014 GUI (Legacy's NewRobloxGui; only 2014 has HealthGui)
	------------------------------------------------------------
	local fixed = setmetatable({}, { __mode = "k" })

	local function tryFix(gui)
		if gui.Name ~= "NewRobloxGui" or fixed[gui] then return end
		fixed[gui] = true
		task.spawn(function()
			-- HealthGui shows up once you have a character, so give it time
			local health = gui:WaitForChild("HealthGui", 60)
			local loadout = health and gui:WaitForChild("CurrentLoadout", 10)
			local backpackFrame = loadout and gui:WaitForChild("Backpack", 10)
			if not backpackFrame then
				fixed[gui] = nil -- not the 2014 GUI
				return
			end
			fixHotbar(loadout)
			task.spawn(fixInventory, gui, loadout, backpackFrame)
			print("[2014 Hook] 2014 GUI found — fixed the hotbar and inventory.")
		end)
	end

	CoreGui.ChildAdded:Connect(tryFix)
	for _, gui in ipairs(CoreGui:GetChildren()) do
		tryFix(gui)
	end

	print("[2014 Hook] Installed.")
end
