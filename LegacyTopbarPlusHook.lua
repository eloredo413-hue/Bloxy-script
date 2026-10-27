-- [[ LEGACY TOPBARPLUS HOOK — classic 2016 game icons on the old top bars ]]
-- For the 2019, 2017, 2016 and 2015 GUIs. Works when executed before OR after Bloxy.
--
-- Same trick Project2016 uses: the game's TopbarPlus buttons are hidden and
-- redrawn as flat 2016-style icons (no dark bubble, white icon, bold label)
-- on the old top bar, right after the menu / chat / backpack buttons.
-- Clicking one clicks the real TopbarPlus button, so the game still works.
--
-- Games with lots of icons: the icons never run into the name / health /
-- leaderstats on the right. A few icons stay normal size; when they don't
-- fit they shrink only as much as needed, and if even the smallest size
-- isn't enough the rest go in a "•••" menu at the end.
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

	-- Button sizes. slot = icon-only button width (the old menu / chat /
	-- backpack buttons are 50), pad = space left and right of the icon /
	-- text, gap = space between icon and text
	local NORMAL = { slot = 50, icon = 26, pad = 12, gap = 6, text = 14 }
	-- The smallest they get when the icons don't all fit before the right
	-- side of the bar. They only shrink as much as needed to fit, in steps.
	local COMPACT = { slot = 38, icon = 22, pad = 6, gap = 4, text = 13 }
	local SHRINK_STEPS = 10
	local ROW = 36      -- height of a row in the "•••" menu
	local MARGIN = 8    -- space kept free before the name / health on the right
	local BADGE = 16    -- notice bubble height
	local MENU_Z = 8
	local FONT = Enum.Font.SourceSansBold
	local WHITE = Color3.new(1, 1, 1)
	local BLUE = Color3.fromRGB(0, 162, 255) -- old top bar "open" color
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
	local more = nil     -- the "•••" button at the end of that row
	local menu = nil     -- the list it opens, for icons that didn't fit
	local menuOpen = false
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

	local widths, widthCount = {}, 0
	local function textWidth(text, size)
		local key = size .. "|" .. text
		local width = widths[key]
		if not width then
			if widthCount >= 256 then
				widths, widthCount = {}, 0
			end
			local plain = (text:gsub("<[^>]*>", ""))
			width = math.ceil(TextService:GetTextSize(plain, size, FONT, Vector2.new(1000, 100)).X)
			widths[key] = width
			widthCount = widthCount + 1
		end
		return width
	end

	-- A size between NORMAL (t = 0) and COMPACT (t = 1)
	local function sizeAt(t)
		if t <= 0 then
			return NORMAL
		elseif t >= 1 then
			return COMPACT
		end
		local m = {}
		for key, value in pairs(NORMAL) do
			m[key] = math.floor(value + (COMPACT[key] - value) * t + 0.5)
		end
		return m
	end

	local function badgeWidth(text)
		return math.max(BADGE, textWidth(text, 12) + 6)
	end

	local function corner(parent)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = parent
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
			if child ~= holder and child ~= menu and child:IsA("GuiObject") and child.Visible then
				local pos, size = child.AbsolutePosition, child.AbsoluteSize
				if size.X > 0 and size.X <= 120 and size.Y >= barHeight * 0.5 and pos.X < limit then
					local right = pos.X + size.X - origin.X
					if not x or right > x then
						x, y, h, z = right, pos.Y - origin.Y, size.Y, child.ZIndex
					end
				end
			end
		end
		return x or NORMAL.slot, y, h, z
	end

	-- Whether something is actually drawn: text, an image or a background
	local function drawn(obj)
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			if obj.Text ~= "" and obj.TextTransparency < 1 then
				return true
			end
		elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			if obj.Image ~= "" and obj.ImageTransparency < 1 then
				return true
			end
		end
		return obj.BackgroundTransparency < 1
	end

	-- Left edge of what's drawn on the right of the bar (name / health,
	-- leaderstats), so our icons stop before it. Only things in the right
	-- half count, so something small near the left buttons (like the chat's
	-- unread count, or a thin line) can't make the icons shrink for nothing.
	local function rightSideStart(bar, startX)
		local edge = bar.AbsolutePosition.X + bar.AbsoluteSize.X
		local middle = bar.AbsolutePosition.X + bar.AbsoluteSize.X / 2
		local maxWidth = bar.AbsoluteSize.X * 0.9
		local minHeight = bar.AbsoluteSize.Y * 0.25
		local function scan(parent)
			for _, child in ipairs(parent:GetChildren()) do
				if child ~= holder and child ~= menu and child:IsA("GuiObject") and child.Visible then
					local left, size = child.AbsolutePosition.X, child.AbsoluteSize
					if size.X > 0 and size.X < maxWidth and size.Y >= minHeight
						and left >= startX + 16 and left + size.X / 2 > middle
						and left < edge and drawn(child)
					then
						edge = left
					else
						scan(child)
					end
				end
			end
		end
		scan(bar)
		return edge
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

	-- Copies the real icon's image, text and notice onto its classic copy
	local function refresh(entry)
		local ui = entry.ui
		local image, label = entry.image, entry.label
		entry.hasImage = image ~= nil and image.Image ~= ""
		entry.text = (label and label.Text) or ""
		entry.notice = noticeText(entry.noticeRoot)
		entry.show = entry.frame.Visible and (entry.hasImage or entry.text ~= "")

		if entry.hasImage then
			-- Keeps the game's own image (and sprite sheet spot), not its
			-- modern colors, so it stays a plain white 2016 icon
			set(ui.icon, "Image", image.Image)
			set(ui.icon, "ImageRectOffset", image.ImageRectOffset)
			set(ui.icon, "ImageRectSize", image.ImageRectSize)
		end
		set(ui.icon, "Visible", entry.hasImage)
		set(ui.label, "Text", entry.text)
		set(ui.label, "Visible", entry.text ~= "")
		set(ui.badge, "Visible", entry.notice ~= nil)
		if entry.notice then
			set(ui.badge, "Text", entry.notice)
		end
	end

	-- Width of an icon's button and where its icon / text go. Rows in the
	-- "•••" menu put the icon then the text from the left, notice last.
	local function measure(entry, m, inMenu)
		local tw = (entry.text ~= "") and textWidth(entry.text, m.text) or 0
		if inMenu then
			local textX = entry.hasImage and (m.pad + m.icon + m.gap) or m.pad
			local extra = entry.notice and (badgeWidth(entry.notice) + m.gap) or 0
			return math.max(m.slot, textX + tw + extra + m.pad), m.pad, textX, tw
		end
		if tw > 0 and entry.hasImage then
			local textX = m.pad + m.icon + m.gap
			return textX + tw + m.pad, m.pad, textX, tw
		elseif tw > 0 then
			local width = math.max(m.slot, tw + m.pad * 2)
			return width, 0, math.floor((width - tw) / 2), tw
		end
		return m.slot, (m.slot - m.icon) / 2, 0, 0
	end

	-- Puts a classic copy on the bar, or in the menu when menuWidth is given
	local function place(entry, m, parent, menuWidth)
		local ui = entry.ui
		local inMenu = menuWidth ~= nil
		local width, iconX, textX, tw = measure(entry, m, inMenu)
		local z = inMenu and (MENU_Z + 1) or zIndex

		set(ui.button, "Parent", parent)
		set(ui.button, "Size", inMenu and UDim2.fromOffset(menuWidth, ROW) or UDim2.new(0, width, 1, 0))
		set(ui.button, "ZIndex", z)
		set(ui.icon, "ZIndex", z + 1)
		set(ui.label, "ZIndex", z + 1)
		set(ui.badge, "ZIndex", z + 2)
		set(ui.icon, "Size", UDim2.fromOffset(m.icon, m.icon))
		set(ui.icon, "Position", UDim2.new(0, iconX, 0.5, 0))
		set(ui.label, "TextSize", m.text)
		set(ui.label, "Position", UDim2.new(0, textX, 0, 0))
		set(ui.label, "Size", UDim2.new(0, tw, 1, 0))

		if entry.notice then
			local bw = badgeWidth(entry.notice)
			set(ui.badge, "Size", UDim2.fromOffset(bw, BADGE))
			if inMenu then
				set(ui.badge, "Position", UDim2.new(0, menuWidth - m.pad - bw, 0.5, -BADGE / 2))
			else
				local right = entry.hasImage and (iconX + m.icon) or (textX + tw)
				set(ui.badge, "Position", UDim2.fromOffset(right - 8, 2))
			end
		end
		set(ui.button, "Visible", true)
	end

	local function closeMenu()
		menuOpen = false
		if menu then
			menu.Visible = false
		end
		if more then
			more.Dots.TextColor3 = WHITE
		end
	end

	local function makeMirror(entry)
		local button = Instance.new("ImageButton")
		button.Name = "GameIcon"
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.Image = ""
		button.Visible = false

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon" -- the 2019 GUI leaves top bar images called "Icon" alone
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = button

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Font = FONT
		label.TextColor3 = WHITE
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.RichText = true
		label.Parent = button

		-- Red count bubble, like the old chat button's unread count
		local badge = Instance.new("TextLabel")
		badge.Name = "Badge"
		badge.BackgroundColor3 = Color3.fromRGB(254, 54, 54)
		badge.BorderSizePixel = 0
		badge.Font = FONT
		badge.TextSize = 12
		badge.TextColor3 = WHITE
		badge.Visible = false
		corner(badge)
		badge.Parent = button

		button.MouseButton1Click:Connect(function()
			if menu and button.Parent == menu then
				closeMenu()
			end
			press(entry.click)
			task.delay(0.1, function()
				if entry.ui and entry.ui.button.Parent then
					pcall(refresh, entry)
				end
			end)
		end)

		button.Parent = holder
		return { button = button, icon = icon, label = label, badge = badge }
	end

	-- Our row on the bar, its "•••" button, and the menu that button opens
	local function build(row, bar)
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

		more = Instance.new("ImageButton")
		more.Name = "More"
		more.BackgroundTransparency = 1
		more.AutoButtonColor = false
		more.Image = ""
		more.LayoutOrder = 1000000
		more.Visible = false
		more.ZIndex = zIndex
		local dots = Instance.new("TextLabel")
		dots.Name = "Dots"
		dots.BackgroundTransparency = 1
		dots.Size = UDim2.fromScale(1, 1)
		dots.Font = FONT
		dots.TextSize = 18
		dots.TextColor3 = WHITE
		dots.Text = "•••"
		dots.ZIndex = zIndex + 1
		dots.Parent = more
		-- Red dot when an icon in the menu has a notice
		local dot = Instance.new("Frame")
		dot.Name = "Notice"
		dot.BackgroundColor3 = Color3.fromRGB(254, 54, 54)
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(8, 8)
		dot.Position = UDim2.new(1, -10, 0, 6)
		dot.Visible = false
		dot.ZIndex = zIndex + 2
		corner(dot)
		dot.Parent = more
		more.Parent = holder

		-- On the bar's ScreenGui, not inside the bar, so the bar can't clip it
		menu = Instance.new("Frame")
		menu.Name = "LegacyTopbarPlusMenu"
		menu.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
		menu.BackgroundTransparency = 0.15
		menu.BorderSizePixel = 0
		menu.Visible = false
		menu.ZIndex = MENU_Z
		local menuList = Instance.new("UIListLayout")
		menuList.SortOrder = Enum.SortOrder.LayoutOrder
		menuList.Parent = menu
		menu.Parent = bar:FindFirstAncestorWhichIsA("LayerCollector") or row

		more.MouseButton1Click:Connect(function()
			if menuOpen then
				closeMenu()
			else
				menuOpen = true
				menu.Visible = true
				dots.TextColor3 = BLUE
			end
		end)
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
						local iconMenu = iconButton and iconButton:FindFirstChild("Menu")
						local spot = iconMenu and iconMenu:FindFirstChild("IconSpot")
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
		if menu then
			menu:Destroy()
			menu = nil
		end
		more = nil
		menuOpen = false
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
			deactivate()
			zIndex = z
			build(row, bar)
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

		local shown = {}
		for i, entry in ipairs(list) do
			set(entry.ui.button, "LayoutOrder", i)
			pcall(refresh, entry)
			if entry.show then
				table.insert(shown, entry)
			else
				set(entry.ui.button, "Visible", false)
			end
		end

		-- Room between the left buttons and the right side of the bar
		local startX = row.AbsolutePosition.X + x
		local room = math.huge
		if bar.AbsoluteSize.X > 0 then
			room = rightSideStart(bar, startX) - startX - MARGIN
		end

		local function total(m)
			local sum = 0
			for _, entry in ipairs(shown) do
				sum = sum + (measure(entry, m))
			end
			return sum
		end

		-- Normal size when everything fits. Otherwise shrink only as much as
		-- needed (a few icons stay close to normal), down to COMPACT. If even
		-- that's too wide, fill the bar (keeping a spot for "•••") and put
		-- the rest in the menu.
		local m, fit = nil, #shown
		for step = 0, SHRINK_STEPS do
			local size = sizeAt(step / SHRINK_STEPS)
			if total(size) <= room then
				m = size
				break
			end
		end
		if not m then
			m, fit = COMPACT, 0
			local used = COMPACT.slot
			for i, entry in ipairs(shown) do
				used = used + (measure(entry, COMPACT))
				if used > room then
					break
				end
				fit = i
			end
		end

		local menuWidth, menuNotice = 0, false
		for i = fit + 1, #shown do
			menuWidth = math.max(menuWidth, (measure(shown[i], NORMAL, true)))
			menuNotice = menuNotice or shown[i].notice ~= nil
		end
		for i, entry in ipairs(shown) do
			if i <= fit then
				place(entry, m, holder)
			else
				place(entry, NORMAL, menu, menuWidth)
			end
		end

		local overflow = #shown - fit
		set(more, "Visible", overflow > 0)
		set(more, "Size", UDim2.new(0, m.slot, 1, 0))
		set(more.Notice, "Visible", menuNotice)
		if overflow == 0 then
			if menuOpen then
				closeMenu()
			end
			return
		end

		-- The menu hangs under the "•••" button, kept on screen
		local gui = menu.Parent
		local origin = gui:IsA("GuiBase2d") and gui.AbsolutePosition or Vector2.new()
		local screenWidth = gui:IsA("GuiBase2d") and gui.AbsoluteSize.X or math.huge
		local menuX = math.min(more.AbsolutePosition.X - origin.X, screenWidth - menuWidth - 4)
		local menuY = bar.AbsolutePosition.Y + bar.AbsoluteSize.Y - origin.Y
		set(menu, "Position", UDim2.fromOffset(math.max(0, menuX), menuY))
		set(menu, "Size", UDim2.fromOffset(menuWidth, ROW * overflow))
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
