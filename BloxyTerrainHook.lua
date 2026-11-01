-- [[ TERRAIN HOOK — adds a "what terrain do you want?" step to Bloxy's setup wizard ]]
-- Choices: 2013, 2014, none.
-- The new step shows right after "choose your forcefield" (before "old particles").
-- Works when executed before OR after Bloxy.
--
-- Your pick is saved (BloxyTerrainChoice.json), so when Bloxy's "skip setup"
-- box is ticked the saved terrain loads by itself, just like Bloxy's own choices.

do
	local TERRAIN_URLS = {
		["2013"] = "https://gist.githubusercontent.com/eloredo413-hue/473229ff3e22a0a59a019f10597490d9/raw/4983bc3859ddf7127704224ff8bd7e6ca4519834/2013%2520Voxel%2520terrain",
		["2014"] = "https://gist.githubusercontent.com/eloredo413-hue/2438eed5e9ddba639d9f92861d1e74ab/raw/1517f0ddefb3c56a85401491f960b312f3a35035/2014%2520Voxel%2520Terrian",
	}

	local SAVE_FILE = "BloxyTerrainChoice.json"
	local BLOXY_CONFIG = "BloxyParadoxConfig.json"
	local BLOXY_GUI = "BloxyParadoxProject"
	-- The wizard step our question goes in front of
	local NEXT_STEP_TEXT = "Do you want old particles?"

	local CLICK_ID = "rbxassetid://12221967"
	local HEADER_IMAGE = "rbxthumb://type=Asset&id=131822012703327&w=420&h=420"

	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local HttpService = game:GetService("HttpService")

	local Env = (getgenv and getgenv()) or _G

	-- Running it again replaces the old copy
	if Env.BloxyTerrainHookCleanup then
		pcall(Env.BloxyTerrainHookCleanup)
	end
	local connections = {}
	local function connect(signal, fn)
		local c = signal:Connect(fn)
		table.insert(connections, c)
		return c
	end
	Env.BloxyTerrainHookCleanup = function()
		for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
		table.clear(connections)
	end

	------------------------------------------------------------
	-- SAVE / LOAD
	------------------------------------------------------------
	local function readJson(file)
		if not (readfile and isfile) then return nil end
		local ok, data = pcall(function()
			if isfile(file) then return HttpService:JSONDecode(readfile(file)) end
		end)
		return ok and type(data) == "table" and data or nil
	end

	local function loadChoice()
		local data = readJson(SAVE_FILE)
		return data and data.Terrain or nil
	end

	local function saveChoice(choice)
		if not writefile then return end
		pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode({ Terrain = choice })) end)
	end

	-- True when Bloxy's "skip setup" box is ticked
	local function bloxySkipOn()
		local data = readJson(BLOXY_CONFIG)
		return data and data.isSkipped == true or false
	end

	------------------------------------------------------------
	-- LOAD THE TERRAIN (only once per server)
	------------------------------------------------------------
	local function runTerrain(choice)
		local url = TERRAIN_URLS[choice]
		if not url then return end
		if Env.BloxyTerrainLoaded then
			if Env.BloxyTerrainLoaded ~= choice then
				warn("[Terrain Hook] " .. Env.BloxyTerrainLoaded .. " terrain is already loaded. Rejoin to switch to " .. choice .. ".")
			end
			return
		end
		Env.BloxyTerrainLoaded = choice
		task.spawn(function()
			print("[Terrain Hook] Loading " .. choice .. " voxel terrain...")
			local ok, code = pcall(function() return game:HttpGet(url) end)
			if not ok or type(code) ~= "string" or #code < 100 then
				Env.BloxyTerrainLoaded = nil
				warn("[Terrain Hook] Could not download the " .. choice .. " terrain.")
				return
			end
			local fn, err = loadstring(code)
			if not fn then
				Env.BloxyTerrainLoaded = nil
				warn("[Terrain Hook] Syntax error: " .. tostring(err))
				return
			end
			local ran, runErr = pcall(fn)
			if not ran then warn("[Terrain Hook] Runtime error: " .. tostring(runErr)) end
		end)
	end

	------------------------------------------------------------
	-- UI (same look as Bloxy's own wizard)
	------------------------------------------------------------
	local sfx = Instance.new("Sound")
	sfx.SoundId = CLICK_ID
	sfx.Volume = 0.6
	sfx.Parent = game:GetService("SoundService")

	local function playClick()
		sfx:Stop()
		sfx:Play()
	end

	local function makeButton(text, pos, width, parent)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, width, 0, 32)
		btn.Position = pos
		btn.Text = text
		btn.Font = Enum.Font.Legacy
		btn.TextScaled = true
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		btn.ZIndex = 5
		btn.Parent = parent

		local constraint = Instance.new("UITextSizeConstraint", btn)
		constraint.MaxTextSize = 16
		constraint.MinTextSize = 8

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.BorderColor3 = Color3.fromRGB(255, 0, 0)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextColor3 = Color3.fromRGB(0, 0, 0)
			btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
		end)
		return btn
	end

	-- Shows the terrain question; calls onDone after the player picks
	local function showTerrainUI(sg, onDone)
		local f = Instance.new("Frame")
		f.Name = "TerrainHookStep"
		f.Size = UDim2.new(0, 450, 0, 95)
		f.Position = UDim2.new(0.5, -225, 0, -250)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.Parent = sg

		local img = Instance.new("ImageLabel")
		img.Name = "HeaderImage"
		img.BackgroundTransparency = 1
		img.Image = HEADER_IMAGE
		img.Size = UDim2.new(0, 260, 0, 160)
		img.Position = UDim2.new(0.5, -130, 0, -111)
		img.BorderSizePixel = 0
		img.ZIndex = 10
		img.Parent = f

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0, 35)
		t.BackgroundTransparency = 1
		t.Text = "What terrain do you want?"
		t.Font = Enum.Font.Legacy
		t.TextSize = 14
		t.Parent = f

		local picked = false
		local function pick(choice)
			if picked then return end
			picked = true
			playClick()

			saveChoice(choice)
			-- Bloxy only saves (doesn't run) when you re-configure with "skip" ticked
			if not bloxySkipOn() then runTerrain(choice) end

			local tw = TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Position = UDim2.new(0.5, -225, 0, -250) })
			tw:Play()
			tw.Completed:Connect(function()
				f:Destroy()
				task.spawn(onDone)
			end)
		end

		makeButton("2013", UDim2.new(0, 10, 0, 50), 135, f).MouseButton1Click:Connect(function() pick("2013") end)
		makeButton("2014", UDim2.new(0, 155, 0, 50), 135, f).MouseButton1Click:Connect(function() pick("2014") end)
		makeButton("none", UDim2.new(0, 300, 0, 50), 140, f).MouseButton1Click:Connect(function() pick("none") end)

		TweenService:Create(f, TweenInfo.new(0.4), { Position = UDim2.new(0.5, -225, 0.5, -47) }):Play()
	end

	------------------------------------------------------------
	-- HOOK INTO BLOXY'S WIZARD
	-- When Bloxy shows "old particles" (the step after forcefield),
	-- hide it, ask about terrain first, then let it slide in.
	------------------------------------------------------------
	local function isNextStep(frame)
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("TextLabel") and d.Text == NEXT_STEP_TEXT then return true end
		end
		return false
	end

	local function onWizardFrame(sg, frame)
		if not frame:IsA("Frame") or frame.Name == "TerrainHookStep" then return end
		-- Bloxy sets the label text right after parenting the frame, so check a moment later
		task.defer(function()
			if not frame.Parent or not isNextStep(frame) then return end
			frame.Visible = false
			showTerrainUI(sg, function()
				if frame.Parent then frame.Visible = true end
			end)
		end)
	end

	local appliedSaved = false
	local function watchBloxy(sg)
		if not (sg:IsA("ScreenGui") and sg.Name == BLOXY_GUI) then return end
		connect(sg.ChildAdded, function(child) onWizardFrame(sg, child) end)

		-- "Skip setup" ticked: Bloxy applies its saved choices, we apply the saved terrain
		if not appliedSaved and bloxySkipOn() then
			appliedSaved = true
			local saved = loadChoice()
			if saved then runTerrain(saved) end
		end
	end

	local plr = Players.LocalPlayer
	while not plr do
		task.wait()
		plr = Players.LocalPlayer
	end
	local pg = plr:WaitForChild("PlayerGui")

	for _, g in ipairs(pg:GetChildren()) do watchBloxy(g) end
	connect(pg.ChildAdded, watchBloxy)

	print("[Terrain Hook] Installed. Saved terrain: " .. tostring(loadChoice() or "none yet"))
end
