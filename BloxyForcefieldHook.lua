-- [[ BLOXY FORCEFIELD 2012 FIX (ADD-ON) ]] --
-- Execute this before OR after Bloxy. The Bloxy script itself is not changed.
--  * Before Bloxy: hooks loadstring so Bloxy's 2012 forcefield runs the fixed
--    forcefield (no studs / no decals) instead.
--  * After Bloxy: patches the 2012 forcefield that is already running, and any
--    it builds later, with the same fix.

local env = (getgenv and getgenv()) or getfenv(0)
if env.__BloxyFF2012FixLoaded then return end
env.__BloxyFF2012FixLoaded = true

local FIXED_FORCEFIELD_2012 = [==[
-- FORCEFIELD (No Studs / No Decals)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer

local ffFolder = Instance.new("Folder")
ffFolder.Name = "FFCloneHolder"
ffFolder.Parent = workspace

local function getTorso(c)
    return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
end

-- Strips studs, inlets, and disables query/touch to prevent decals or bullet marks
local function sanitizePart(part)
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.LeftSurface = Enum.SurfaceType.Smooth
    part.RightSurface = Enum.SurfaceType.Smooth
    part.FrontSurface = Enum.SurfaceType.Smooth
    part.BackSurface = Enum.SurfaceType.Smooth
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end

local function buildFF()
    local model = Instance.new("Model")
    model.Name = "Forcefield2012"
    model.Parent = ffFolder

    -- Auto-remove any decals or textures if parented to the forcefield
    model.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Decal") or descendant:IsA("Texture") then
            task.defer(function()
                if descendant.Parent then
                    descendant:Destroy()
                end
            end)
        end
    end)

    -- Main Container
    local main = Instance.new("Part")
    main.Name = "VisualForcefield2012"
    main.Anchored = true
    sanitizePart(main)
    main.CastShadow = false
    main.Transparency = 1
    main.Size = Vector3.new(1, 1, 1)
    main.Parent = model

    -- Inner Sphere
    local mc = Instance.new("Part")
    mc.Name = "MainCircle"
    mc.Anchored = true
    sanitizePart(mc)
    mc.CastShadow = false
    mc.Color = Color3.fromRGB(0, 0, 128)
    mc.Material = Enum.Material.Neon
    mc.Transparency = 0.6
    mc.Size = Vector3.new(0.9, 0.9, 0.9)
    mc.Parent = model

    local mcM = Instance.new("SpecialMesh")
    mcM.MeshType = Enum.MeshType.Sphere
    mcM.Scale = Vector3.new(7, 7, 7)
    mcM.Parent = mc

    -- Outer Sphere
    local oc = Instance.new("Part")
    oc.Name = "OuterCircle"
    oc.Anchored = true
    sanitizePart(oc)
    oc.CastShadow = false
    oc.Color = Color3.fromRGB(0, 0, 128)
    oc.Material = Enum.Material.Neon
    oc.Transparency = 0.95
    oc.Size = Vector3.new(0.9, 0.9, 0.9)
    oc.Parent = model

    local ocM = Instance.new("SpecialMesh")
    ocM.MeshType = Enum.MeshType.Sphere
    ocM.Scale = Vector3.new(7.7, 7.7, 7.7)
    ocM.Parent = oc

    -- Sparkles Part
    local sp = Instance.new("Part")
    sp.Name = "Sparkles83"
    sp.Anchored = true
    sanitizePart(sp)
    sp.Transparency = 1
    sp.Size = Vector3.new(5, 1, 5)
    sp.Parent = model

    -- Legacy Particle Style
    local old = Instance.new("ParticleEmitter")
    old.Name = "OldSparkles"
    old.Lifetime = NumberRange.new(3, 3)
    old.LightEmission = 1e9
    old.LockedToPart = true
    old.Rate = 7
    old.RotSpeed = NumberRange.new(25, 25)
    old.Rotation = NumberRange.new(8, 8)
    old.Size = NumberSequence.new(1)
    old.Speed = NumberRange.new(2, 4)
    old.Texture = "rbxassetid://6334617852"
    old.Transparency = NumberSequence.new(0.5, 1)
    old.Parent = sp

    -- Glow Rays
    local rays = Instance.new("ParticleEmitter")
    rays.Name = "Rays"
    rays.Lifetime = NumberRange.new(1, 1)
    rays.LightEmission = 1
    rays.LockedToPart = true
    rays.Rate = 100
    rays.RotSpeed = NumberRange.new(-50, 50)
    rays.Rotation = NumberRange.new(-180, 180)
    rays.Size = NumberSequence.new(2)
    rays.Speed = NumberRange.new(0, 0)
    rays.Texture = "rbxassetid://1084975295"
    rays.Transparency = NumberSequence.new(0.4, 1)
    rays.Parent = main

    -- Pulsing Animation
    task.spawn(function()
        while model.Parent do
            TweenService:Create(mc, TweenInfo.new(0.55, Enum.EasingStyle.Sine), {Transparency = 0.95}):Play()
            TweenService:Create(oc, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {Transparency = 0.6}):Play()
            task.wait(0.55)
            TweenService:Create(oc, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {Transparency = 0.95}):Play()
            TweenService:Create(mc, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {Transparency = 0.6}):Play()
            task.wait(0.35)
        end
    end)

    return model
end

local currentModel = nil
local char = lp.Character or lp.CharacterAdded:Wait()

-- Core Loop: Watch for Forcefields
task.spawn(function()
    while true do
        local ff = char and char:FindFirstChildOfClass("ForceField")
        if ff then
            ff.Visible = false -- Hide the new forcefield
            if not currentModel then 
                currentModel = buildFF() 
            end
        else
            if currentModel then
                currentModel:Destroy()
                currentModel = nil
            end
        end
        task.wait(0.1)
    end
end)

-- Follow Player
RunService.PreRender:Connect(function()
    if not currentModel or not char then return end
    local t = getTorso(char)
    if not t then return end

    local targetCF = t.CFrame
    for _, p in ipairs(currentModel:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CFrame = targetCF
        end
    end
end)

lp.CharacterAdded:Connect(function(newChar)
    char = newChar
    if currentModel then
        currentModel:Destroy()
        currentModel = nil
    end
end)
]==]

----------------------------------------------------------------------------------------------------
-- [[ BEFORE BLOXY: SWAP THE 2012 FORCEFIELD SCRIPT ]] --
----------------------------------------------------------------------------------------------------
-- Bloxy's Forcefield_2012 script always starts with this header
local function isBloxyForcefield2012(code)
	return type(code) == "string" and code:match("^%s*%-%- OLD FORCEFIELD") ~= nil
end

local originalLoadstring = loadstring

local function makeHook(callOriginal)
	return function(code, ...)
		if isBloxyForcefield2012(code) then
			code = FIXED_FORCEFIELD_2012
		end
		return callOriginal(code, ...)
	end
end

local hooked = false
if hookfunction then
	hooked = pcall(function()
		local old
		local hook = makeHook(function(...) return old(...) end)
		old = hookfunction(loadstring, newcclosure and newcclosure(hook) or hook)
	end)
end
if not hooked then
	env.loadstring = makeHook(originalLoadstring)
end

----------------------------------------------------------------------------------------------------
-- [[ AFTER BLOXY: PATCH A FORCEFIELD THAT IS ALREADY RUNNING ]] --
----------------------------------------------------------------------------------------------------
local patchedModels = setmetatable({}, { __mode = "k" })

-- Strips studs, inlets, and disables query/touch to prevent decals or bullet marks
local function sanitize(obj)
	if obj:IsA("BasePart") then
		obj.TopSurface = Enum.SurfaceType.Smooth
		obj.BottomSurface = Enum.SurfaceType.Smooth
		obj.LeftSurface = Enum.SurfaceType.Smooth
		obj.RightSurface = Enum.SurfaceType.Smooth
		obj.FrontSurface = Enum.SurfaceType.Smooth
		obj.BackSurface = Enum.SurfaceType.Smooth
		obj.CanCollide = false
		obj.CanTouch = false
		obj.CanQuery = false
	elseif obj:IsA("Decal") or obj:IsA("Texture") then
		task.defer(function()
			if obj.Parent then
				obj:Destroy()
			end
		end)
	end
end

local function patchModel(model)
	if not model:IsA("Model") or model.Name ~= "Forcefield2012" or patchedModels[model] then return end
	patchedModels[model] = true
	for _, d in ipairs(model:GetDescendants()) do
		sanitize(d)
	end
	model.DescendantAdded:Connect(sanitize)
end

local function watchHolder(folder)
	if not folder:IsA("Folder") or folder.Name ~= "FFCloneHolder" then return end
	for _, m in ipairs(folder:GetChildren()) do
		patchModel(m)
	end
	folder.ChildAdded:Connect(patchModel)
end

for _, child in ipairs(workspace:GetChildren()) do
	watchHolder(child)
end
workspace.ChildAdded:Connect(watchHolder)
