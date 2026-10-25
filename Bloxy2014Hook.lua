-- [[ 2014 HOOK — fixes the 2014 hotbar and inventory, made for mobile ]]
-- Works when executed before OR after Bloxy, on mobile and PC.
-- 1. Hotbar: item boxes keep their shadows, with 2014's 46px slots so the
--    shadows sit apart instead of running together into one gray block
-- 2. Inventory: the backpack panel lists every tool you have
--    tap the handle above the hotbar = open / close the inventory
--    tap a tool = equip / unequip it
--    drag a tool onto the hotbar = put it in that slot
--    ▲ ▼ (or the mouse wheel) = scroll

do
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local player = Players.LocalPlayer

	local ICON_SIZE = 46 -- real 2014 hotbar size (the 2014 GUI uses 54, so the shadows overlapped)
	local BOX_SIZE = 51 -- inventory boxes
	local BOX_GAP = 3
	local GRID_TOP = 33 -- room under the handle (and for the search bar on PC)
	local GRID_LEFT = 14
	local HANDLE_WIDTH, HANDLE_HEIGHT = 112, 20
	local PANEL_COLOR = Color3.fromRGB(31, 31, 31)
	local BOX_COLOR = Color3.fromRGB(18, 18, 18)
	local BORDER_COLOR = Color3.fromRGB(150, 150, 150)
	local EQUIPPED_COLOR = Color3.new(1, 1, 1)
	local DRAG_DISTANCE = 8 -- pixels you have to move before it counts as a drag

	local function v2(p)
		return Vector2.new(p.X, p.Y)
	end

	local function addCorner(obj, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = obj
	end

	local function addBorder(obj, color, thickness, transparency)
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = color
		s.Thickness = thickness
		s.Transparency = transparency or 0
		s.Parent = obj
		return s
	end

	------------------------------------------------------------
	-- HOTBAR: back to 2014's slot size, shadows untouched
	------------------------------------------------------------
	local function fixSlotSize(f)
		if f:IsA("Frame") and string.match(f.Name, "^Slot%d+$") then
			f.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
		end
	end

	local function fixHotbar(loadout)
		loadout.Size = UDim2.new(loadout.Size.X.Scale, loadout.Size.X.Offset, 0, ICON_SIZE)
		for _, f in ipairs(loadout:GetChildren()) do
			fixSlotSize(f)
		end
		loadout.ChildAdded:Connect(fixSlotSize)
	end

	------------------------------------------------------------
	-- OPEN / CLOSE HANDLE: the 2014 toggle is a tiny 14x9 arrow, too small
	-- to hit with a finger. Turn it into a tab sitting on top of the hotbar
	-- (and on top of the panel while it's open).
	------------------------------------------------------------
	local function fixHandle(button, backpackFrame)
		-- the scripts keep moving it with an X offset made for the 14px arrow,
		-- this keeps the wide tab centered on the same spot
		button.AnchorPoint = Vector2.new(0.5 - 7 / HANDLE_WIDTH, 0)
		button.Size = UDim2.new(0, HANDLE_WIDTH, 0, HANDLE_HEIGHT)
		button.BackgroundColor3 = PANEL_COLOR
		button.BorderSizePixel = 0
		button.ImageTransparency = 1
		button.ZIndex = 3
		addCorner(button, 8)
		addBorder(button, BORDER_COLOR, 1.5, 0.2)

		-- the arrow, flipped by the 2014 script when it opens / closes
		local arrow = Instance.new("ImageLabel")
		arrow.Name = "Arrow"
		arrow.BackgroundTransparency = 1
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = UDim2.new(0.5, 0, 0.5, 0)
		arrow.Size = UDim2.new(0, 21, 0, 14)
		arrow.Image = button.Image
		arrow.ZIndex = 4
		arrow.Parent = button
		button:GetPropertyChangedSignal("Image"):Connect(function()
			arrow.Image = button.Image
		end)

		local function update()
			button.BackgroundTransparency = backpackFrame.Visible and 0.05 or 0.35
		end
		backpackFrame:GetPropertyChangedSignal("Visible"):Connect(update)
		update()
	end

	------------------------------------------------------------
	-- INVENTORY: the 2014 GUI is missing the script that fills the panel
	------------------------------------------------------------
	local function fixInventory(gui, loadout, backpackFrame)
		local gear = backpackFrame:WaitForChild("Gear", 10)
		local scroller = gear and gear:WaitForChild("GearGridScrollingArea", 10)
		local swap = backpackFrame:WaitForChild("SwapSlot", 10)
		local swapSlot = swap and swap:WaitForChild("Slot", 10)
		local swapButton = swap and swap:WaitForChild("GearButton", 10)
		if not (scroller and swapSlot and swapButton) then return end

		-- the 2014 scripts use this same check for phones / small screens
		local small = gui.AbsoluteSize.Y <= 500
		local maxHotbar = small and 4 or 10

		-- dark, solid panel
		backpackFrame.BackgroundColor3 = PANEL_COLOR
		backpackFrame.BackgroundTransparency = 0.08

		-- old empty grid and preview aren't used
		for _, name in ipairs({ "GearGrid", "GearPreview" }) do
			local old = gear:FindFirstChild(name)
			if old then old.Visible = false end
		end

		-- the gray frame around the hotbar shows while the panel is open
		local hotbarFrame = loadout:FindFirstChild("Background")
		if hotbarFrame and hotbarFrame:IsA("ImageLabel") then
			local function update()
				hotbarFrame.Visible = backpackFrame.Visible
			end
			backpackFrame:GetPropertyChangedSignal("Visible"):Connect(update)
			update()
		end

		local grid = Instance.new("Frame")
		grid.Name = "InventoryGrid"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.new(0, GRID_LEFT, 0, GRID_TOP)
		grid.Size = UDim2.new(1, -(GRID_LEFT + 23), 1, -GRID_TOP)
		grid.Parent = gear

		-- ▲ ▼ on the right, where 2014 had them
		local bar = Instance.new("Frame")
		bar.Name = "ScrollBar"
		bar.BackgroundTransparency = 0.9
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.Position = UDim2.new(0, 0, 0, 18)
		bar.Size = UDim2.new(0, 17, 1, -36)
		bar.Parent = scroller

		local function makeScrollButton(name, image, position)
			local b = Instance.new("ImageButton")
			b.Name = name
			b.BackgroundTransparency = 1
			b.Image = image
			b.Position = position
			b.Size = UDim2.new(0, 17, 0, 17)
			b.ZIndex = 4
			b.Parent = scroller
			return b
		end
		local scrollUp = makeScrollButton("ScrollUpButton", "rbxasset://textures/ui/scrollbuttonUp.png", UDim2.new(0, 0, 0, 0))
		local scrollDown = makeScrollButton("ScrollDownButton", "rbxasset://textures/ui/scrollbuttonDown.png", UDim2.new(0, 0, 1, -17))

		local order = {} -- tools in the order you got them
		local boxes = {} -- tool -> inventory box
		local searchTerms = nil
		local firstRow, lastRow = 0, 0
		local press = nil

		--------------------------------------------------------
		-- grid layout: fill rows left to right, ▲ ▼ move a row at a time
		--------------------------------------------------------
		local function layout()
			local list = {}
			for _, t in ipairs(order) do
				local b = boxes[t]
				if b and b.Parent == grid then table.insert(list, b) end
			end
			local step = BOX_SIZE + BOX_GAP
			local cols = math.max(1, math.floor((grid.AbsoluteSize.X + BOX_GAP) / step))
			local rows = math.max(1, math.floor((grid.AbsoluteSize.Y + BOX_GAP) / step))
			lastRow = math.max(0, math.ceil(#list / cols) - rows)
			firstRow = math.max(0, math.min(firstRow, lastRow))
			for i, b in ipairs(list) do
				local row = math.floor((i - 1) / cols) - firstRow
				local col = (i - 1) % cols
				b.Position = UDim2.new(0, col * step, 0, row * step)
				b.Visible = row >= 0 and row < rows
			end
		end

		local function scrollBy(rows)
			firstRow = firstRow + rows
			layout()
		end

		local scrollHeld = 0
		local function holdToScroll(button, dir)
			button.MouseButton1Down:Connect(function()
				scrollHeld = scrollHeld + 1
				local mine = scrollHeld
				scrollBy(dir)
				task.wait(0.3)
				while scrollHeld == mine and (dir < 0 and firstRow > 0 or dir > 0 and firstRow < lastRow) do
					scrollBy(dir)
					task.wait(0.15)
				end
			end)
		end
		holdToScroll(scrollUp, -1)
		holdToScroll(scrollDown, 1)

		grid.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				scrollBy(input.Position.Z > 0 and -1 or 1)
			end
		end)

		--------------------------------------------------------
		-- hotbar helpers (through the "SwapSlot" the 2014 hotbar listens to)
		--------------------------------------------------------
		local function hotbarSlotOf(tool)
			for _, f in ipairs(loadout:GetChildren()) do
				local n = f:IsA("Frame") and tonumber(string.match(f.Name, "^Slot(%d+)$"))
				if n then
					for _, b in ipairs(f:GetChildren()) do
						local ref = b:FindFirstChild("GearReference")
						if ref and ref.Value == tool then
							return (n == 0) and 10 or n
						end
					end
				end
			end
		end

		local function findEmptySlot()
			for num = 1, maxHotbar do
				local f = loadout:FindFirstChild("Slot" .. (num % 10))
				if f and not f:FindFirstChildWhichIsA("GuiButton") then return num end
			end
		end

		local function inside(p, obj)
			local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
			return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
		end

		-- hotbar slot number (1-10) to drop on: the slot under the finger,
		-- or the first free slot when dropped anywhere else on the hotbar
		local function dropSlotAt(p)
			for _, f in ipairs(loadout:GetChildren()) do
				local n = f:IsA("Frame") and tonumber(string.match(f.Name, "^Slot(%d+)$"))
				if n then
					local num = (n == 0) and 10 or n
					if num <= maxHotbar and inside(p, f) then return num end
				end
			end
			local pos, size = loadout.AbsolutePosition, loadout.AbsoluteSize
			if p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y - 10 and p.Y <= pos.Y + size.Y + 10 then
				return findEmptySlot()
			end
		end

		local function unequipIfHeld(tool)
			-- put a held tool away first, otherwise the hotbar puts it
			-- straight back into the slot we're changing
			local char = player.Character
			if tool and char and tool.Parent == char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum:UnequipTools() end
				task.wait()
			end
		end

		local function waitForSwap()
			for _ = 1, 60 do
				if not swap.Value then return true end
				task.wait()
			end
			return false
		end

		local function sendSwap(num, tool)
			local carrier = nil
			if tool then
				carrier = Instance.new("Frame")
				local ref = Instance.new("ObjectValue")
				ref.Name = "GearReference"
				ref.Value = tool
				ref.Parent = carrier
			end
			swapSlot.Value = num % 10
			swapButton.Value = carrier
			swap.Value = true
		end

		local function putOnHotbar(tool, num)
			if not tool.Parent or not waitForSwap() then return end
			local from = hotbarSlotOf(tool)
			if from == num then return end
			if from then
				-- moving it to another slot: take it out of the old one first
				unequipIfHeld(tool)
				sendSwap(from, nil)
				if not waitForSwap() then return end
			end
			local frame = loadout:FindFirstChild("Slot" .. (num % 10))
			local old = frame and frame:FindFirstChildWhichIsA("GuiButton")
			local oldRef = old and old:FindFirstChild("GearReference")
			unequipIfHeld(oldRef and oldRef.Value)
			sendSwap(num, tool)
		end

		local function toggleEquip(tool)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or not tool.Parent or not tool:IsA("Tool") then return end
			if tool.Parent == char then
				hum:UnequipTools()
			else
				hum:EquipTool(tool)
			end
		end

		--------------------------------------------------------
		-- inventory boxes
		--------------------------------------------------------
		local function makeBox(tool, parent)
			local b = Instance.new("ImageButton")
			b.Name = "GearButton"
			b.AutoButtonColor = false
			b.BackgroundColor3 = BOX_COLOR
			b.BackgroundTransparency = 0.15
			b.BorderSizePixel = 0
			b.Size = UDim2.new(0, BOX_SIZE, 0, BOX_SIZE)
			b.ZIndex = 2
			addCorner(b, 4)
			addBorder(b, BORDER_COLOR, 1.5)

			local icon = Instance.new("ImageLabel")
			icon.Name = "GearImage"
			icon.BackgroundTransparency = 1
			icon.Position = UDim2.new(0, 4, 0, 4)
			icon.Size = UDim2.new(1, -8, 1, -8)
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Image = tool.TextureId
			icon.ZIndex = 3
			icon.Parent = b

			local text = Instance.new("TextLabel")
			text.Name = "GearText"
			text.BackgroundTransparency = 1
			text.Position = UDim2.new(0, 2, 0, 2)
			text.Size = UDim2.new(1, -4, 1, -4)
			text.Font = Enum.Font.SourceSans
			text.TextSize = 14
			text.TextColor3 = Color3.new(1, 1, 1)
			text.TextWrapped = true
			text.Text = (tool.TextureId == "") and tool.Name or ""
			text.ZIndex = 4
			text.Parent = b

			b.Parent = parent
			return b
		end

		--------------------------------------------------------
		-- tap / drag
		--------------------------------------------------------
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
		end

		local function moveGhost(pos)
			local p = toGui(pos) - press.grab
			press.ghost.Position = UDim2.new(0, p.X, 0, p.Y)
		end

		local function startDrag(pos)
			press.dragging = true
			-- a see-through copy follows your finger, the box stays in the panel
			local ghost = makeBox(press.tool, nil)
			ghost.Name = "DraggedGear"
			ghost.BackgroundTransparency = 0.45
			ghost.GearImage.ImageTransparency = 0.25
			ghost.ZIndex = 10
			ghost.GearImage.ZIndex = 11
			ghost.GearText.ZIndex = 12
			press.ghost = ghost
			moveGhost(pos)
			ghost.Parent = gui
		end

		local function beginPress(tool, b, input)
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
			if press then return end
			press = {
				tool = tool,
				input = input,
				touch = kind == Enum.UserInputType.Touch,
				start = v2(input.Position),
				grab = toGui(input.Position) - b.AbsolutePosition,
				dragging = false,
			}
		end

		UserInputService.InputChanged:Connect(function(input)
			if not press then return end
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseMovement and not press.touch
				or kind == Enum.UserInputType.Touch and input == press.input then
				if press.dragging then
					moveGhost(input.Position)
				elseif (v2(input.Position) - press.start).Magnitude >= DRAG_DISTANCE then
					startDrag(input.Position)
				end
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				scrollHeld = scrollHeld + 1 -- let go of ▲ ▼
			end
			if not press then return end
			if kind == Enum.UserInputType.MouseButton1 and not press.touch
				or kind == Enum.UserInputType.Touch and input == press.input then
				local done = press
				endPress()
				if done.dragging then
					local num = dropSlotAt(toGui(input.Position))
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
		local function matches(tool)
			if not searchTerms then return true end
			local name = tool.Name:lower()
			for _, term in ipairs(searchTerms) do
				if string.find(name, term, 1, true) then return true end
			end
			return false
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
						if (t:IsA("Tool") or t:IsA("HopperBin")) and not t:FindFirstChild("RobloxBuildTool") and not have[t] then
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

			for t, b in pairs(boxes) do
				if not have[t] then
					b:Destroy()
					boxes[t] = nil
				end
			end

			for _, t in ipairs(order) do
				local b = boxes[t]
				if not b then
					b = makeBox(t, nil)
					b.InputBegan:Connect(function(input) beginPress(t, b, input) end)
					boxes[t] = b
				end
				b.GearImage.Image = t.TextureId
				b.GearText.Text = (t.TextureId == "") and t.Name or ""
				-- white border = the tool you're holding
				local held = t.Parent == char
				b.UIStroke.Color = held and EQUIPPED_COLOR or BORDER_COLOR
				b.UIStroke.Thickness = held and 2.5 or 1.5
				b.Parent = matches(t) and grid or nil
			end
			layout()
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
		-- the panel slides open, so lay the grid out again as it grows
		grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

		-- the search box at the top of the panel (PC)
		task.spawn(function()
			local manager = backpackFrame:WaitForChild("BackpackManager", 10)
			local searchEvent = manager and manager:WaitForChild("SearchRequestedEvent", 10)
			if not searchEvent then return end
			searchEvent.Event:Connect(function(text)
				local terms = {}
				if type(text) == "string" and text:lower() ~= "search..." then
					for word in string.gmatch(text:lower(), "%S+") do
						table.insert(terms, word)
					end
				end
				searchTerms = (#terms > 0) and terms or nil
				firstRow = 0
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
			task.spawn(function()
				local controls = gui:WaitForChild("ControlFrame", 10)
				local handle = controls and controls:WaitForChild("BackpackButton", 10)
				if handle then fixHandle(handle, backpackFrame) end
			end)
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
