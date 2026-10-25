-- [[ 2014 HOOK — makes the 2014 backpack work and look like real 2014 ]]
-- Works when executed before OR after Bloxy, on mobile and PC.
-- 1. Hotbar: item boxes keep their shadows, with 2014's 46px slots so the
--    shadows sit apart instead of running together into one gray block
-- 2. Inventory: puts back 2014's inventory script (missing from the 2014 GUI),
--    so the backpack lists every tool you have
--    drag a tool onto a hotbar slot = put it there
--    double tap a tool = put it in the first free hotbar slot
--    ▲ ▼ = scroll, PC: click a tool that's on the hotbar = "Remove Hotkey"

do
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local player = Players.LocalPlayer

	local ICON_SIZE = 46 -- real 2014 size (the 2014 GUI uses 54, so the shadows overlapped)
	local DRAG_DISTANCE = 6 -- pixels you have to move before it counts as a drag
	local DOUBLE_TAP = 0.5

	local function v2(p)
		return Vector2.new(p.X, p.Y)
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
	-- INVENTORY: 2014's "BackpackGear" script, rebuilt for the 2014 GUI
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

		-- 2014 never showed the preview either
		local preview = gear:FindFirstChild("GearPreview")
		if preview then preview.Visible = false end

		-- same spot 2014 put the grid (the strip on top is where the PC search bar sits)
		local grid = Instance.new("Frame")
		grid.Name = "ScrollingFrame"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.new(0, 0, 0, 30)
		grid.Size = UDim2.new(1, 0, 1, -30)
		grid.Parent = gearGrid

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
		local buttons = {} -- tool -> inventory box
		local searchTerms = nil
		local firstRow, lastRow = 0, 0
		local press = nil
		local menu = nil
		local needsLayout = false

		--------------------------------------------------------
		-- grid layout: fill rows left to right, ▲ ▼ move a row at a time
		--------------------------------------------------------
		local function layout()
			local list = {}
			for _, t in ipairs(order) do
				local b = buttons[t]
				if b and b.Parent == grid then table.insert(list, b) end
			end
			local w, h = grid.AbsoluteSize.X, grid.AbsoluteSize.Y
			local cols = math.max(1, math.floor((w - 1) / ICON_SIZE))
			local rows = math.max(1, math.floor(h / ICON_SIZE))
			lastRow = math.max(0, math.ceil(#list / cols) - rows)
			firstRow = math.max(0, math.min(firstRow, lastRow))
			-- center the grid like 2014 did
			local xOff = math.ceil(math.floor(w % ICON_SIZE) / 2)
			local yOff = math.ceil(math.floor(h % ICON_SIZE) / 2)
			for i, b in ipairs(list) do
				local row = math.floor((i - 1) / cols) - firstRow
				local col = (i - 1) % cols
				b.Position = UDim2.new(0, xOff + col * ICON_SIZE, 0, yOff + row * ICON_SIZE)
				b.Visible = row >= 0 and row < rows
			end
		end

		local scrollHeld = 0
		local function holdToScroll(button, dir)
			button.MouseButton1Down:Connect(function()
				scrollHeld = scrollHeld + 1
				local mine = scrollHeld
				firstRow = firstRow + dir
				layout()
				task.wait(0.2)
				while scrollHeld == mine and (dir < 0 and firstRow > 0 or dir > 0 and firstRow < lastRow) do
					firstRow = firstRow + dir
					layout()
					task.wait(0.1)
				end
			end)
		end
		holdToScroll(scrollUp, -1)
		holdToScroll(scrollDown, 1)

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

		local function removeFromHotbar(tool)
			local num = hotbarSlotOf(tool)
			if not num or not waitForSwap() then return end
			unequipIfHeld(tool)
			sendSwap(num, nil)
		end

		local function putOnHotbar(tool, num)
			if not tool.Parent or not waitForSwap() then return end
			local from = hotbarSlotOf(tool)
			if from == num then return end
			if from then
				-- moving it to another slot: take it out of the old one first
				removeFromHotbar(tool)
				if not waitForSwap() then return end
			end
			local frame = loadout:FindFirstChild("Slot" .. (num % 10))
			local old = frame and frame:FindFirstChildWhichIsA("GuiButton")
			local oldRef = old and old:FindFirstChild("GearReference")
			unequipIfHeld(oldRef and oldRef.Value)
			sendSwap(num, tool)
		end

		--------------------------------------------------------
		-- PC: "Remove Hotkey" menu for tools that are on the hotbar
		--------------------------------------------------------
		local function hideMenu()
			if menu then
				menu:Destroy()
				menu = nil
			end
		end

		local function showMenu(button, tool)
			hideMenu()
			if not hotbarSlotOf(tool) then return end
			local abs = button.AbsolutePosition
			menu = Instance.new("TextButton")
			menu.Name = "UnequipContextMenu"
			menu.Style = Enum.ButtonStyle.RobloxButtonDefault
			-- just above the box, so a double click can't land on it by accident
			menu.Position = UDim2.new(0, abs.X - 16, 0, abs.Y - 32)
			menu.Size = UDim2.new(0, 115, 0, 30)
			menu.Font = Enum.Font.Arial
			menu.TextSize = 14
			menu.TextColor3 = Color3.new(1, 1, 1)
			menu.Text = "Remove Hotkey"
			menu.ZIndex = 9
			menu.Parent = gui
			menu.MouseButton1Click:Connect(function()
				hideMenu()
				task.spawn(removeFromHotbar, tool)
			end)
			menu.MouseLeave:Connect(hideMenu)
		end

		--------------------------------------------------------
		-- tap / double tap / drag
		--------------------------------------------------------
		local function toGui(pos)
			-- input positions skip the top bar inset, this GUI may not
			local p = v2(pos)
			if gui.IgnoreGuiInset then
				p = p + GuiService:GetGuiInset()
			end
			return p
		end

		local function setLayer(b, z)
			b.ZIndex = z
			local shadow = b:FindFirstChild("Background")
			if shadow then shadow.ZIndex = z - 1 end
			local icon = b:FindFirstChild("GearImage")
			if icon then icon.ZIndex = z end
			local text = b:FindFirstChild("GearText")
			if text then text.ZIndex = z + 1 end
		end

		local function dropBack(b, home, animate)
			local abs = b.AbsolutePosition
			b.Parent = grid
			setLayer(b, 2)
			if animate then
				local g = grid.AbsolutePosition
				b.Position = UDim2.new(0, abs.X - g.X, 0, abs.Y - g.Y)
				b:TweenPosition(home, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true)
			else
				b.Position = home
			end
			if needsLayout then
				needsLayout = false
				layout()
			end
		end

		local lastTap = setmetatable({}, { __mode = "k" })

		local function beginPress(tool, b, input)
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
			if press then return end
			hideMenu()
			press = {
				tool = tool,
				button = b,
				input = input,
				touch = kind == Enum.UserInputType.Touch,
				start = v2(input.Position),
				grab = toGui(input.Position) - b.AbsolutePosition,
				dragging = false,
			}
		end

		local function startDrag()
			hideMenu()
			local b = press.button
			press.dragging = true
			press.home = b.Position
			local abs = b.AbsolutePosition
			-- lift the box out of the panel so it can follow you down to the hotbar
			b.Parent = gui
			b.Position = UDim2.new(0, abs.X, 0, abs.Y)
			setLayer(b, 10)
		end

		UserInputService.InputChanged:Connect(function(input)
			if not press then return end
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseMovement and not press.touch
				or kind == Enum.UserInputType.Touch and input == press.input then
				if not press.dragging and (v2(input.Position) - press.start).Magnitude >= DRAG_DISTANCE then
					startDrag()
				end
				if press.dragging then
					local p = toGui(input.Position) - press.grab
					press.button.Position = UDim2.new(0, p.X, 0, p.Y)
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
				press = nil
				if done.dragging then
					local num = slotAt(toGui(input.Position))
					dropBack(done.button, done.home, not num)
					if num then
						task.spawn(putOnHotbar, done.tool, num)
					end
				else
					local now = os.clock()
					if lastTap[done.tool] and now - lastTap[done.tool] < DOUBLE_TAP then
						lastTap[done.tool] = nil
						local num = not hotbarSlotOf(done.tool) and findEmptySlot()
						if num then
							task.spawn(putOnHotbar, done.tool, num)
						end
					else
						lastTap[done.tool] = now
						if not done.touch then
							showMenu(done.button, done.tool)
						end
					end
				end
			end
		end)

		--------------------------------------------------------
		-- building the list
		--------------------------------------------------------
		local function makeButton(tool)
			-- 2014's own inventory box (shadow included), at 2014's size
			local b = template:Clone()
			b.Name = "GearButton"
			b.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
			b.Image = ""
			b.Visible = false
			b.GearReference.Value = tool

			-- icon in its own label so the shadow always stays under it
			local icon = Instance.new("ImageLabel")
			icon.Name = "GearImage"
			icon.BackgroundTransparency = 1
			icon.Size = UDim2.new(1, 0, 1, 0)
			icon.Parent = b
			setLayer(b, 2)

			b.InputBegan:Connect(function(input) beginPress(tool, b, input) end)
			return b
		end

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

			local dragged = press and press.dragging and press.button
			for t, b in pairs(buttons) do
				if not have[t] then
					if b == dragged then press = nil end
					b:Destroy()
					buttons[t] = nil
				end
			end

			for _, t in ipairs(order) do
				local b = buttons[t]
				if not b then
					b = makeButton(t)
					buttons[t] = b
				end
				b.GearImage.Image = t.TextureId
				b.GearText.Text = (t.TextureId == "") and t.Name or ""
				if b ~= dragged then
					b.Parent = matches(t) and grid or nil
				end
			end

			if dragged then
				needsLayout = true
			else
				layout()
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
				hideMenu()
			end
		end)
		-- the panel slides open, so lay the grid out again as it grows
		grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if not (press and press.dragging) then layout() end
		end)

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
