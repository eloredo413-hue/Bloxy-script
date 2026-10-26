-- [[ LEGACY TOPBARPLUS HOOK — classic 2016 game icons on the old top bars ]]
-- For the 2019, 2017, 2016 and 2015 GUIs. Works when executed before OR after Bloxy.
--
-- Same trick Project2016 uses: the game's TopbarPlus buttons are hidden and
-- redrawn as flat 2016-style icons (no dark bubble, white icon, bold label)
-- on the old top bar, right after the menu / chat / backpack buttons.
-- Clicking one clicks the real TopbarPlus button, so the game still works.
--
-- It turns on whenever the old Legacy top bar (CoreGui.NewRobloxGui.TopBarContainer)
-- is on screen, which is what the 2019, 2017, 2016 and 2015 GUIs use.
-- 2023 loads that bar too but hides it, so it stays off there. Pick a GUI
-- without the old top bar (2023, 2024, ...) and the game's normal
-- TopbarPlus buttons come back.

do
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local TextService = game:GetService("TextService")

	local env = (getgenv and getgenv()) or _G

	-- Running it again replaces the old copy
	if env.LegacyTopbarPlusStop then
		pcall(env.LegacyTopbarPlusStop)
	end

	local SLOT = 50   -- icon-only button width, same as the old menu / chat / backpack buttons
	local ICON = 26   -- icon size
	local PAD = 12    -- space left and right of a button's icon / text
	local GAP = 6     -- space between icon and text
	local BADGE = 16  -- notice bubble height
	local FONT = Enum.Font.SourceSansBold
	local TEXT_SIZE = 14
	-- The old top bar has to stay up (or gone) this long before we switch.
	-- 2023 loads the old bar too, then hides it a moment later.
	local SETTLE = 2

	-- TopbarPlus v2 keeps its buttons in "TopbarPlus", v3 in these
	local V3_GUIS = {
		TopbarStandard = true,
		TopbarCentered = true,
		TopbarStandardClipped = true,
		TopbarCenteredClipped = true,
	}
	local V3_SIDES = { Left = 0, Center = 1, Right = 2 }

	local running = true
	local holder = nil   -- our row of icons on the old top bar
	local zIndex = 1
	local mirrors = {}   -- TopbarPlus icon frame -> its classic copy
	local disabled = {}  -- TopbarPlus ScreenGuis we turned off -> their Enabled watcher
	local barUp = false
	local barChangedAt = os.clock()

	local function set(obj, prop, value)
		if obj[prop] ~= value then
			obj[prop] = value
		end
	end

	local function textWidth(text, size)
		local plain = (text:gsub("<[^>]*>", ""))
		return math.ceil(TextService:GetTextSize(plain, size, FONT, Vector2.new(1000, 100)).X)
	end

	------------------------------------------------------------
	-- THE OLD TOP BAR (Legacy GUIs: CoreGui.NewRobloxGui.TopBarContainer)
	------------------------------------------------------------
	local function findTopBar()
		local legacy = CoreGui:FindFirstChild("NewRobloxGui")
		local bar = legacy and legacy:FindFirstChild("TopBarContainer", true)
		if bar then
			return bar
		end
		for _, gui in ipairs(CoreGui:GetChildren()) do
			bar = gui:FindFirstChild("TopBarContainer")
			if bar then
				return bar
			end
		end
		return nil
	end

	local function isShowing(obj)
		while obj and obj ~= CoreGui do
			if obj:IsA("GuiObject") and not obj.Visible then
				return false
			end
			if obj:IsA("LayerCollector") and not obj.Enabled then
				return false
			end
			obj = obj.Parent
		end
		return obj == CoreGui
	end

	-- The frame the menu / chat / backpack buttons sit in
	local function rowOf(bar)
		local button = bar:FindFirstChild("Backpack", true)
			or bar:FindFirstChild("Settings", true)
			or bar:FindFirstChild("Chat", true)
		return (button and button.Parent) or bar
	end

	-- Right edge of the buttons on the left of the bar, so our icons go
	-- right after them (the 2019 GUI moves its backpack / emotes around)
	local function leftButtonsEnd(row, bar)
		local origin = row.AbsolutePosition
		local limit = bar.AbsolutePosition.X + bar.AbsoluteSize.X * 0.4
		local barHeight = bar.AbsoluteSize.Y
		local x, y, h, z = nil, 0, barHeight, 1
		for _, child in ipairs(row:GetChildren()) do
			if child ~= holder and child:IsA("GuiObject") and child.Visible then
				local pos, size = child.AbsolutePosition, child.AbsoluteSize
				if size.X > 0 and size.X <= 120 and size.Y >= barHeight * 0.5 and pos.X < limit then
					local right = pos.X + size.X - origin.X
					if not x or right > x then
						x, y, h, z = right, pos.Y - origin.Y, size.Y, child.ZIndex
					end
				end
			end
		end
		return x or SLOT, y, h, z
	end

	------------------------------------------------------------
	-- CLASSIC ICONS
	------------------------------------------------------------
	-- Clicks the real TopbarPlus button
	local function press(target)
		if not (target and target.Parent and target:IsA("GuiButton")) then
			return
		end
		if firesignal and pcall(firesignal, target.MouseButton1Click) then
			return
		end
		if getconnections then
			local ok, conns = pcall(getconnections, target.MouseButton1Click)
			if ok and type(conns) == "table" then
				for _, conn in ipairs(conns) do
					if conn.Function then
						task.spawn(pcall, conn.Function)
					elseif conn.Fire then
						pcall(conn.Fire, conn)
					end
				end
			end
		end
	end

	-- Text of the icon's notice bubble, nil when it has none
	local function noticeText(root)
		local notice = root and (root:FindFirstChild("NoticeFrame") or root:FindFirstChild("Notice"))
		-- v3 moves the real bubble out and leaves a copy pointing to it
		local original = notice and notice:FindFirstChild("OriginalInstance")
		if original and original:IsA("ObjectValue") and original.Value then
			notice = original.Value
		end
		local label = notice and notice:FindFirstChild("NoticeLabel")
		if label and notice.Visible and label.Text ~= "" and label.Text ~= "0" then
			return label.Text
		end
		return nil
	end

	local function sync(entry)
		local ui = entry.ui
		local image, label = entry.image, entry.label
		local hasImage = image ~= nil and image.Image ~= ""
		local text = (label and label.Text) or ""
		local hasText = text ~= ""

		if hasImage then
			-- Keeps the game's own image (and sprite sheet spot), not its
			-- modern colors, so it stays a plain white 2016 icon
			set(ui.icon, "Image", image.Image)
			set(ui.icon, "ImageRectOffset", image.ImageRectOffset)
			set(ui.icon, "ImageRectSize", image.ImageRectSize)
		end
		set(ui.icon, "Visible", hasImage)
		set(ui.label, "Text", text)
		set(ui.label, "Visible", hasText)

		local width = SLOT
		local iconX = (SLOT - ICON) / 2
		local textX, tw = PAD, 0
		if hasText then
			tw = textWidth(text, TEXT_SIZE)
			if hasImage then
				iconX = PAD
				textX = PAD + ICON + GAP
				width = textX + tw + PAD
			else
				width = math.max(SLOT, tw + PAD * 2)
				textX = math.floor((width - tw) / 2)
			end
		end
		set(ui.button, "Size", UDim2.new(0, width, 1, 0))
		set(ui.icon, "Position", UDim2.new(0, iconX, 0.5, 0))
		set(ui.label, "Position", UDim2.new(0, textX, 0, 0))
		set(ui.label, "Size", UDim2.new(0, tw, 1, 0))

		local count = noticeText(entry.noticeRoot)
		set(ui.badge, "Visible", count ~= nil)
		if count then
			local right = hasImage and (iconX + ICON) or (textX + tw)
			set(ui.badge, "Text", count)
			set(ui.badge, "Size", UDim2.fromOffset(math.max(BADGE, textWidth(count, 12) + 6), BADGE))
			set(ui.badge, "Position", UDim2.fromOffset(right - 8, 2))
		end

		set(ui.button, "Visible", entry.frame.Visible and (hasImage or hasText))
	end

	local function makeMirror(entry)
		local button = Instance.new("ImageButton")
		button.Name = "GameIcon"
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.Image = ""
		button.Size = UDim2.new(0, SLOT, 1, 0)
		button.ZIndex = zIndex

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon" -- the 2019 GUI leaves top bar images called "Icon" alone
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Size = UDim2.fromOffset(ICON, ICON)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = zIndex + 1
		icon.Parent = button

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Font = FONT
		label.TextSize = TEXT_SIZE
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.RichText = true
		label.ZIndex = zIndex + 1
		label.Parent = button

		-- Red count bubble, like the old chat button's unread count
		local badge = Instance.new("TextLabel")
		badge.Name = "Badge"
		badge.BackgroundColor3 = Color3.fromRGB(254, 54, 54)
		badge.BorderSizePixel = 0
		badge.Font = FONT
		badge.TextSize = 12
		badge.TextColor3 = Color3.new(1, 1, 1)
		badge.Visible = false
		badge.ZIndex = zIndex + 2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = badge
		badge.Parent = button

		button.MouseButton1Click:Connect(function()
			press(entry.click)
			task.delay(0.1, function()
				if entry.ui and entry.ui.button.Parent then
					pcall(sync, entry)
				end
			end)
		end)

		button.Parent = holder
		return { button = button, icon = icon, label = label, badge = badge }
	end

	------------------------------------------------------------
	-- TOPBARPLUS BUTTONS (v2 and v3)
	------------------------------------------------------------
	local function track(frame, click, image, label, noticeRoot, order, stamp)
		local entry = mirrors[frame]
		if not entry then
			entry = { frame = frame }
			entry.ui = makeMirror(entry)
			mirrors[frame] = entry
		end
		entry.click, entry.image, entry.label = click, image, label
		entry.noticeRoot, entry.order, entry.stamp = noticeRoot, order, stamp
	end

	local function collectIcons(gui, stamp)
		if gui.Name == "TopbarPlus" then
			local container = gui:FindFirstChild("TopbarContainer")
			if not container then
				return
			end
			for _, frame in ipairs(container:GetChildren()) do
				local button = frame:FindFirstChild("IconButton")
				-- TopbarPlus' own helper icons start with "_" (overflow, controller, healthbar)
				if button and frame:IsA("GuiObject") and frame.Name:sub(1, 1) ~= "_" then
					-- v2 places its icons left to right in pixels
					track(frame, button, button:FindFirstChild("IconImage"),
						button:FindFirstChild("IconLabel"), button, frame.Position.X.Offset, stamp)
				end
			end
		else
			local holders = gui:FindFirstChild("Holders")
			if not holders then
				return
			end
			for _, side in ipairs(holders:GetChildren()) do
				local group = V3_SIDES[side.Name]
				if group then
					for _, widget in ipairs(side:GetChildren()) do
						local iconButton = widget:FindFirstChild("IconButton")
						local menu = iconButton and iconButton:FindFirstChild("Menu")
						local spot = menu and menu:FindFirstChild("IconSpot")
						local contents = spot and spot:FindFirstChild("Contents")
						if contents and widget:IsA("GuiObject") and widget.Name:sub(1, 8) ~= "Overflow" then
							track(widget, spot:FindFirstChild("ClickRegion"),
								contents:FindFirstChild("IconImage", true),
								contents:FindFirstChild("IconLabel", true),
								widget, group * 1000000 + widget.LayoutOrder, stamp)
						end
					end
				end
			end
		end
	end

	-- Hide the modern buttons. TopbarPlus turns its ScreenGuis back on
	-- when the escape menu closes, so keep them off.
	local function hideGui(gui)
		if disabled[gui] then
			return
		end
		gui.Enabled = false
		disabled[gui] = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if gui.Enabled then
				gui.Enabled = false
			end
		end)
	end

	local function deactivate()
		if holder then
			holder:Destroy()
			holder = nil
		end
		mirrors = {}
		for gui, conn in pairs(disabled) do
			conn:Disconnect()
			if gui.Parent then
				gui.Enabled = true
			end
		end
		disabled = {}
	end

	local function update(bar)
		local row = rowOf(bar)
		local x, y, h, z = leftButtonsEnd(row, bar)

		if not (holder and holder.Parent == row) then
			if holder then
				holder:Destroy()
			end
			mirrors = {}
			zIndex = z
			holder = Instance.new("Frame")
			holder.Name = "LegacyTopbarPlusIcons"
			holder.BackgroundTransparency = 1
			holder.AutomaticSize = Enum.AutomaticSize.X
			holder.ZIndex = zIndex
			local list = Instance.new("UIListLayout")
			list.FillDirection = Enum.FillDirection.Horizontal
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.VerticalAlignment = Enum.VerticalAlignment.Center
			list.Parent = holder
			holder.Parent = row
		end
		set(holder, "Position", UDim2.fromOffset(x, y))
		set(holder, "Size", UDim2.fromOffset(0, h))

		local stamp = os.clock()
		local player = Players.LocalPlayer
		local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			for _, gui in ipairs(playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") and (gui.Name == "TopbarPlus" or V3_GUIS[gui.Name]) then
					hideGui(gui)
					collectIcons(gui, stamp)
				end
			end
		end

		local list = {}
		for frame, entry in pairs(mirrors) do
			if entry.stamp ~= stamp then
				-- The game removed this icon
				entry.ui.button:Destroy()
				entry.ui = nil
				mirrors[frame] = nil
			else
				table.insert(list, entry)
			end
		end
		table.sort(list, function(a, b)
			return a.order < b.order
		end)
		for i, entry in ipairs(list) do
			set(entry.ui.button, "LayoutOrder", i)
			pcall(sync, entry)
		end
	end

	------------------------------------------------------------
	-- MAIN LOOP
	------------------------------------------------------------
	env.LegacyTopbarPlusStop = function()
		running = false
		deactivate()
	end

	task.spawn(function()
		while running do
			local ok, err = pcall(function()
				local bar = findTopBar()
				local up = bar ~= nil and isShowing(bar)
				if up ~= barUp then
					barUp = up
					barChangedAt = os.clock()
				end

				if barUp and os.clock() - barChangedAt >= SETTLE then
					if not holder then
						print("[Legacy TopbarPlus] Old top bar found — using classic icons.")
					end
					update(bar)
				elseif not barUp and holder and os.clock() - barChangedAt >= SETTLE then
					print("[Legacy TopbarPlus] Old top bar gone — normal TopbarPlus icons back.")
					deactivate()
				end
			end)
			if not ok then
				warn("[Legacy TopbarPlus] " .. tostring(err))
			end
			task.wait(0.25)
		end
	end)

	print("[Legacy TopbarPlus] Installed.")
end
