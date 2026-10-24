-- [[ 2012 FORCEFIELD HOOK — fires when Bloxy runs the 2012 forcefield ]]
-- Works when executed before OR after Bloxy.

do
	local NEW_URL = "https://gist.githubusercontent.com/eloredo413-hue/e1bf3f24da8cf13cbef1c2cd5cdab8c9/raw/2d47a851e2c75bc7908517406496b160a5821a80/Forcefield%2520fix%25202011"
	-- Must be at the very START of the code, otherwise the whole Bloxy
	-- script (which contains this text inside it) would get replaced too
	local SIG = "^%s*%-%- OLD FORCEFIELD"
	local _orig = getgenv().loadstring or loadstring

	------------------------------------------------------------
	-- LOADSTRING HOOK (swaps the old 2012 forcefield for the fixed one)
	------------------------------------------------------------
	local function patched(code, name)
		if type(code) == "string" and string.find(code, SIG) then
			print("[2012 FF Hook] 2012 forcefield picked — loading FIXED forcefield...")
			local ok, nc = pcall(function() return game:HttpGet(NEW_URL) end)
			if ok and type(nc) == "string" and #nc > 100 then
				return _orig(nc, name)
			end
			warn("[2012 FF Hook] Fetch failed, using old 2012 forcefield.")
		end
		return _orig(code, name)
	end

	-- hookfunction patches loadstring itself, so Bloxy sees it no matter its env
	local hooked = false
	if hookfunction then
		hooked = pcall(function()
			local hook = function(...) return patched(...) end
			_orig = hookfunction(loadstring, newcclosure and newcclosure(hook) or hook)
		end)
	end
	if not hooked then
		pcall(function() getgenv().loadstring = patched end)
		pcall(function() getfenv(0).loadstring = patched end)
		pcall(function() _G.loadstring = patched end)
	end

	------------------------------------------------------------
	-- BACKUP: fix an old 2012 forcefield that is already running
	-- (smooth surfaces so 2012 textures skip it, no touch/query, no decals)
	------------------------------------------------------------
	local function clean(obj)
		if obj:IsA("BasePart") then
			for _, s in ipairs({"Top", "Bottom", "Left", "Right", "Front", "Back"}) do
				obj[s .. "Surface"] = Enum.SurfaceType.Smooth
			end
			obj.CanCollide, obj.CanTouch, obj.CanQuery = false, false, false
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			task.defer(function() if obj.Parent then obj:Destroy() end end)
		end
	end

	local function watchModel(m)
		if not (m:IsA("Model") and m.Name == "Forcefield2012") then return end
		for _, d in ipairs(m:GetDescendants()) do clean(d) end
		m.DescendantAdded:Connect(clean)
	end

	local function watchHolder(f)
		if not (f:IsA("Folder") and f.Name == "FFCloneHolder") then return end
		for _, m in ipairs(f:GetChildren()) do watchModel(m) end
		f.ChildAdded:Connect(watchModel)
	end

	for _, f in ipairs(workspace:GetChildren()) do watchHolder(f) end
	workspace.ChildAdded:Connect(watchHolder)

	print("[2012 FF Hook] Installed" .. (hooked and " (hookfunction)." or "."))
end
