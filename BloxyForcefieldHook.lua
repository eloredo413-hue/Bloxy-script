-- [[ 2012 FORCEFIELD HOOK — fires when Bloxy runs the 2012 forcefield ]]

do
	local _orig = getgenv().loadstring or loadstring
	local NEW_URL = "https://gist.githubusercontent.com/eloredo413-hue/e1bf3f24da8cf13cbef1c2cd5cdab8c9/raw/2d47a851e2c75bc7908517406496b160a5821a80/Forcefield%2520fix%25202011"
	local SIG = "-- OLD FORCEFIELD"

	------------------------------------------------------------
	-- LOADSTRING HOOK
	------------------------------------------------------------
	local function patched(code, name)
		if type(code) == "string" and string.find(code, SIG, 1, true) then
			print("[2012 FF Hook] 2012 forcefield picked — loading FIXED forcefield...")
			local ok, nc = pcall(function() return game:HttpGet(NEW_URL) end)
			if ok and type(nc) == "string" and #nc > 100 then
				return _orig(nc, name)
			end
			warn("[2012 FF Hook] Fetch failed, using old 2012 forcefield.")
		end
		return _orig(code, name)
	end

	pcall(function() getgenv().loadstring = patched end)
	pcall(function() _G.loadstring = patched end)
	pcall(function() loadstring = patched end)
	print("[2012 FF Hook] Installed.")
end
