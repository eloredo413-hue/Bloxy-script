-- [[ 2014 HOOK — makes the 2014 backpack work (mobile and PC) ]]
-- Works when executed before OR after Bloxy.
-- Only adds what's missing, the 2014 GUI keeps its own look:
--    the backpack panel lists every tool you have
--    tap the arrow above the hotbar = open / close (easier to hit on phones)
--    tap a tool = equip / unequip it
--    drag a tool onto the hotbar = put it in that slot
--    ▲ ▼ (or the mouse wheel) = scroll

do
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local player = Players.LocalPlayer

	local BOX_SIZE = 51 -- 3 per row, 2 rows on phones
	local BOX_GAP = 3
	local GRID_TOP = 33 -- room under the arrow (and for the search bar on PC)
	local GRID_LEFT = 14
	local ARROW_TAP_WIDTH, ARROW_TAP_HEIGHT = 64, 30
	local DRAG_DISTANCE = 8 -- pixels you have to move before it counts as a drag

	local function v2(p)
		return Vector2.new(p.X, p.Y)
	end

	------------------------------------------------------------
	-- OPEN / CLOSE ARROW: it's only 14x9, too small to hit with a finger.
	-- Give it a bigger invisible tap area, the arrow looks the same.
	------------------------------------------------------------
	local function fixArrow(button)
		-- the scripts keep moving it with offsets made for the 14x9 arrow,
		-- this keeps the bigger area centered on the arrow
		button.AnchorPoint = Vector2.new(0.5 - 7 / ARROW_TAP_WIDTH, 0.5 - 4.5 / ARROW_TAP_HEIGHT)
		button.Size = UDim2.new(0, ARROW_TAP_WIDTH, 0, ARROW_TAP_HEIGHT)
		button.ImageTransparency = 1

		local arrow = Instance.new("ImageLabel")
		arrow.Name = "Arrow"
		arrow.BackgroundTransparency = 1
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = UDim2.new(0.5, 0, 0.5, 0)
		arrow.Size = UDim2.new(0, 14, 0, 9)
		arrow.Image = button.Image
		arrow.ZIndex = button.ZIndex
		arrow.Parent = button
		-- the 2014 script flips the arrow when it opens / closes
		button:GetPropertyChangedSignal("Image"):Connect(function()
			arrow.Image = button.Image
		end)
	end

	------------------------------------------------------------
	-- INVENTORY: the 2014 GUI is missing the script that fills the panel
	------------------------------------------------------------
	local function fixInventory(gui, loadout, backpackFrame)
		local gear = backpackFrame:WaitForChild("Gear", 10)
		local gearGrid = gear and gear:WaitForChild("GearGrid", 10)
		local template = gearGrid and gearGrid:WaitForChild("GearButton", 10)
		local scroller = gear and gear:WaitForChild("GearGridScrollingArea", 10)
		local swap = backpackFrame:WaitForChild("SwapSlot", 10)
		local swapSlot = swap and swap:WaitForChild("Slot", 10)
		local swapButton = swap and swap:WaitForChild("GearButton", 10)
		if not (template and scroller and swapSlot and swapButton) then return end

		-- the 2014 scripts use this same check for phones / small screens
		local small = gui.AbsoluteSize.Y <= 500
		local maxHotbar = small and 4 or 10

		-- the empty preview would sit on top of the list on PC
		local preview = gear:FindFirstChild("GearPreview")
		if preview then preview.Visible = false end

		local grid = Instance.new("Frame")
		grid.Name = "InventoryGrid"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.new(0, GRID_LEFT, 0, GRID_TOP)
		grid.Size = UDim2.new(1, -(GRID_LEFT + 23), 1, -GRID_TOP)
		grid.Parent = gear

		-- ▲ ▼ where 2014 put them
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
		-- inventory boxes: the 2014 GUI's own box, shadow included
		--------------------------------------------------------
		local function setLayer(b, z)
			-- keep the shadow under the icon (in the original it drew over it)
			b.ZIndex = z
			local shadow = b:FindFirstChild("Background")
			if shadow then shadow.ZIndex = z - 1 end
			local icon = b:FindFirstChild("GearImage")
			if icon then icon.ZIndex = z end
			local text = b:FindFirstChild("GearText")
			if text then text.ZIndex = z + 1 end
		end

		local function makeBox(tool)
			local b = template:Clone()
			b.Name = "GearButton"
			b.Size = UDim2.new(0, BOX_SIZE, 0, BOX_SIZE)
			b.Image = ""
			b.Visible = true
			b.GearReference.Value = tool

			local icon = Instance.new("ImageLabel")
			icon.Name = "GearImage"
			icon.BackgroundTransparency = 1
			icon.Size = UDim2.new(1, 0, 1, 0)
			icon.Image = tool.TextureId
			icon.Parent = b
			b.GearText.Text = (tool.TextureId == "") and tool.Name or ""
			setLayer(b, 2)
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
			local ghost = makeBox(press.tool)
			ghost.Name = "DraggedGear"
			ghost.GearImage.ImageTransparency = 0.3
			setLayer(ghost, 10)
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
					b = makeBox(t)
					b.InputBegan:Connect(function(input) beginPress(t, b, input) end)
					boxes[t] = b
				end
				b.GearImage.Image = t.TextureId
				b.GearText.Text = (t.TextureId == "") and t.Name or ""
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
			task.spawn(function()
				local controls = gui:WaitForChild("ControlFrame", 10)
				local arrow = controls and controls:WaitForChild("BackpackButton", 10)
				if arrow then fixArrow(arrow) end
			end)
			task.spawn(fixInventory, gui, loadout, backpackFrame)
			print("[2014 Hook] 2014 GUI found — backpack fixed.")
		end)
	end

	CoreGui.ChildAdded:Connect(tryFix)
	for _, gui in ipairs(CoreGui:GetChildren()) do
		tryFix(gui)
	end

	print("[2014 Hook] Installed.")
end
