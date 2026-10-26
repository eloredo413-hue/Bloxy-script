-- [[ MENU BACKGROUND HOOK — fixes the off-center menu background in the 2014 / 2015 GUI ]]
-- Works when executed before OR after Bloxy.
-- The old GUI only fills the phone's safe area (inside the notch / rounded
-- corners), so the dark background behind its menus (settings, report abuse,
-- help...) leaves strips uncovered at the sides and bottom. This draws that
-- background on its own full-screen layer instead, so it covers everything.

do
	local CoreGui = game:GetService("CoreGui")

	-- full screen, ignoring the safe area and the top bar
	local layer = Instance.new("ScreenGui")
	layer.Name = "LegacyMenuBackground"
	layer.ResetOnSpawn = false
	layer.IgnoreGuiInset = true
	pcall(function() layer.ScreenInsets = Enum.ScreenInsets.None end)
	pcall(function() layer.ClipToDeviceSafeArea = false end)
	layer.DisplayOrder = 99 -- just under the old GUI (it uses 100)
	layer.Parent = CoreGui

	local fixed = setmetatable({}, { __mode = "k" })

	local function fixShield(shield, gui)
		if fixed[shield] then return end
		fixed[shield] = true

		local background = Instance.new("Frame")
		background.Name = shield.Name
		background.BorderSizePixel = 0
		background.Size = UDim2.new(1, 0, 1, 0)
		background.BackgroundColor3 = shield.BackgroundColor3
		background.BackgroundTransparency = shield.BackgroundTransparency
		background.Visible = false
		background.Parent = layer

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

		local function update()
			layer.DisplayOrder = gui.DisplayOrder - 1
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

	-- every full-screen shield the old menus use ends in "Shield"
	-- (UserSettingsShield, SettingsShield, ReportAbuseShield, ...)
	local function check(obj, gui)
		if obj:IsA("GuiObject") and string.match(obj.Name, "Shield$") then
			fixShield(obj, gui)
		end
	end

	local function watch(gui)
		if gui.Name ~= "NewRobloxGui" or not gui:IsA("ScreenGui") then return end
		for _, d in ipairs(gui:GetDescendants()) do
			check(d, gui)
		end
		gui.DescendantAdded:Connect(function(d)
			check(d, gui)
		end)
	end

	CoreGui.ChildAdded:Connect(watch)
	for _, gui in ipairs(CoreGui:GetChildren()) do
		watch(gui)
	end

	print("[Menu Background Hook] Installed.")
end
