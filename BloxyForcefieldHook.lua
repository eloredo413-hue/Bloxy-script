-- [[ BLOXY FORCEFIELD 2012 HOOK ]] --
-- Run this INSTEAD of the normal Bloxy loadstring.
-- It hooks loadstring so that when Bloxy runs its 2012 forcefield
-- (from the button or from saved choices) the fixed forcefield
-- (no studs / no decals) runs instead. The Bloxy script itself is not changed.

local BLOXY_URL = "https://raw.githubusercontent.com/eloredo413-hue/Bloxy-script/main/Bloxy"

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

-- Bloxy's Forcefield_2012 script always starts with this header
local function isBloxyForcefield2012(code)
	return type(code) == "string" and code:match("^%s*%-%- OLD FORCEFIELD") ~= nil
end

local env = (getgenv and getgenv()) or getfenv(0)
local originalLoadstring = env.__BloxyFFOriginalLoadstring or loadstring
env.__BloxyFFOriginalLoadstring = originalLoadstring

local function hookedLoadstring(code, ...)
	if isBloxyForcefield2012(code) then
		code = FIXED_FORCEFIELD_2012
	end
	return originalLoadstring(code, ...)
end

env.loadstring = hookedLoadstring

local bloxyFn, err = originalLoadstring(game:HttpGet(BLOXY_URL))
if not bloxyFn then
	warn("BLOXY FF HOOK: failed to load Bloxy: " .. tostring(err))
	return
end

-- Make sure Bloxy sees the hooked loadstring even if the executor gives it its own env
if setfenv then
	local base = getfenv(bloxyFn)
	setfenv(bloxyFn, setmetatable({ loadstring = hookedLoadstring }, {
		__index = base,
		__newindex = base,
	}))
end

bloxyFn()
