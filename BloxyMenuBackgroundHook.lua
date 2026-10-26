-- [[ MENU BACKGROUND HOOK — fixes the menu background in the 2014 GUI ]]
-- Works when executed before OR after Bloxy.
-- The 2014 GUI only fills the phone's safe area (inside the notch / rounded
-- corners), so the dark background behind its menus (settings, report abuse,
-- help...) leaves strips uncovered at the sides and bottom, and the menu
-- button, leaderboard and chat show on top of it. This draws the background
-- over the whole screen, above all of those, with the open menu on top.

do
	local CoreGui = game:GetService("CoreGui")

	local BACKGROUND_Z = 9 -- above the leaderboard (8), chat and menu button
	local LIFT = 10 -- the open menu goes this much higher, above the background

	local fixed = setmetatable({}, { __mode = "k" })

	-- keep a menu piece above the background, even if its script changes its ZIndex
	local function lift(obj)
		if not obj:IsA("GuiObject") or fixed[obj] then return end
		fixed[obj] = true
		local expected = obj.ZIndex + LIFT
		obj.ZIndex = expected
		obj:GetPropertyChangedSignal("ZIndex"):Connect(function()
			if obj.ZIndex ~= expected then
				expected = obj.ZIndex + LIFT
				obj.ZIndex = expected
			end
		end)
	end

	local function fixShield(shield, gui)
		if fixed[shield] then return end
		fixed[shield] = true

		-- way bigger than the screen so it covers past the safe area and padding
		local background = Instance.new("Frame")
		background.Name = shield.Name .. "Background"
		background.BorderSizePixel = 0
		background.Position = UDim2.new(0, -2000, 0, -2000)
		background.Size = UDim2.new(1, 4000, 1, 4000)
		background.BackgroundColor3 = shield.BackgroundColor3
		background.BackgroundTransparency = shield.BackgroundTransparency
		background.ZIndex = BACKGROUND_Z
		background.Visible = false
		background.Parent = gui

		-- the shield keeps blocking taps, it just doesn't draw anymore
		local function takeLook()
			if shield.BackgroundTransparency < 1 then
				background.BackgroundColor3 = shield.BackgroundColor3
				background.BackgroundTransparency = shield.BackgroundTransparency
				shield.BackgroundTransparency = 1
			end
		end
		takeLook()
		shield:GetPropertyChangedSignal("BackgroundTransparency"):Connect(takeLook)

		-- the menu itself goes above the background
		fixed[shield] = nil
		lift(shield)
		for _, d in ipairs(shield:GetDescendants()) do lift(d) end
		shield.DescendantAdded:Connect(lift)

		local function update()
			background.Visible = shield.Visible and shield:IsDescendantOf(gui)
		end
		shield:GetPropertyChangedSignal("Visible"):Connect(update)
		shield.AncestryChanged:Connect(function()
			if shield:IsDescendantOf(game) then
				update()
			else
				background:Destroy()
			end
		end)
		update()
	end

	-- every full-screen shield the 2014 menus use ends in "Shield"
	-- (UserSettingsShield, ReportAbuseShield, HelpDialogShield, ...)
	local function check(obj, gui)
		if obj:IsA("GuiObject") and string.match(obj.Name, "Shield$") then
			fixShield(obj, gui)
		end
	end

	local watched = setmetatable({}, { __mode = "k" })

	local function watch(gui)
		if gui.Name ~= "NewRobloxGui" or not gui:IsA("ScreenGui") or watched[gui] then return end
		watched[gui] = true
		task.spawn(function()
			-- only the 2014 GUI has HealthGui (2015's menu already works)
			if not gui:WaitForChild("HealthGui", 60) then
				watched[gui] = nil
				return
			end
			-- let the background draw outside the safe area
			pcall(function() gui.ClipToDeviceSafeArea = false end)
			for _, d in ipairs(gui:GetDescendants()) do
				check(d, gui)
			end
			gui.DescendantAdded:Connect(function(d)
				check(d, gui)
			end)
		end)
	end

	CoreGui.ChildAdded:Connect(watch)
	for _, gui in ipairs(CoreGui:GetChildren()) do
		watch(gui)
	end

	print("[Menu Background Hook] Installed.")
end
