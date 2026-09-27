--[[
    HIRUKU v8 — visual suite for MM2
    Client-side cosmetics only (only you can see them).

    Menu:  RightShift, or tap the "Hiruku" HUD.pill at the top of the screen.
    Icons: Lucide, downloaded from GitHub at runtime (falls back to plain glyphs if the download fails).
           Custom icon library:  getgenv().HirukuIconLib = "<url to lucide-roblox.luau>"  (before running)
    Configs are saved to <executor workspace>/Hiruku/*.json (needs writefile/readfile).
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")

local LP = Players.LocalPlayer
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local GRAY = Color3.fromRGB(140, 140, 150)
local OFF = Color3.fromRGB(46, 46, 52)
local function cam() return workspace.CurrentCamera end
local origFov = cam().FieldOfView

-- a second run replaces the previous copy
local env = (getgenv and getgenv()) or _G
if env.HirukuUnload then pcall(env.HirukuUnload) end

---------------------------------------------------------------- helpers
local conns = {}
local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(conns, c)
    return c
end

local function new(class, props)
    local o = Instance.new(class)
    local parent = props.Parent
    props.Parent = nil
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function stroke(o, color, transp, thick)
    return new("UIStroke", {
        Color = color or WHITE, Transparency = transp or 0.9, Thickness = thick or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o,
    })
end
local function tween(o, t, props, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local NSK, CSK = NumberSequenceKeypoint.new, ColorSequenceKeypoint.new

-- lower() that understands Cyrillic (for search)
local function lower(s)
    local ok, res = pcall(function()
        local out = {}
        for _, cp in utf8.codes(s) do
            local c = cp
            if c >= 0x410 and c <= 0x42F then c += 32 elseif c >= 0x400 and c <= 0x40F then c += 80 end
            table.insert(out, utf8.char(c))
        end
        return table.concat(out):lower()
    end)
    return ok and res or s:lower()
end
local function fmt(v, step)
    if step >= 1 then return tostring(math.floor(v + 0.5)) end
    return string.format("%.2f", v)
end

---------------------------------------------------------------- state
local C = {
    silver = Color3.fromRGB(200, 200, 208), gray = Color3.fromRGB(120, 120, 130), ice = Color3.fromRGB(170, 215, 255),
    rose = Color3.fromRGB(255, 170, 205), gold = Color3.fromRGB(255, 222, 150), violet = Color3.fromRGB(185, 160, 255),
    mint = Color3.fromRGB(160, 255, 215), red = Color3.fromRGB(255, 90, 100),
}
local Swatches = { WHITE, C.silver, C.gray, C.ice, C.rose, C.gold, C.violet, C.mint, C.red }
local DarkSwatches = {
    Color3.fromRGB(3, 3, 8), Color3.fromRGB(10, 14, 34), Color3.fromRGB(38, 48, 95), Color3.fromRGB(60, 30, 90),
    Color3.fromRGB(90, 20, 30), Color3.fromRGB(255, 150, 90), Color3.fromRGB(150, 170, 220), Color3.fromRGB(255, 225, 190), WHITE,
}
local TintSwatches = {
    WHITE, Color3.fromRGB(205, 218, 255), Color3.fromRGB(255, 225, 190), Color3.fromRGB(255, 205, 235),
    Color3.fromRGB(200, 255, 220), Color3.fromRGB(230, 200, 255),
}

local Defaults = {
    -- screen
    cross = false, crossStyle = "Ring", crossSize = 56, crossGap = 6, crossColor = WHITE,
    cursor = false, cursorSize = 14, cursorColor = WHITE,
    graph = false,
    watermark = true, wmName = true, wmUser = true, wmFps = true, wmPing = true, wmTime = true, playerInfo = true,
    accentColor = C.ice,
    vignette = false, vigStrength = 0.6,
    bars = false, barsSize = 0.09,
    fovOn = false, fovVal = 80,
    notify = true,
    -- effects
    hat = false, hatSize = 1, hatHeight = 0.68, hatForward = 0, hatSide = 0, hatSpin = 1.5, hatRainbow = false, hatColor = WHITE,
    halo = false, haloHeight = 0.95, haloRainbow = false, haloColor = C.gold,
    orbs = false, orbCount = 5, orbRadius = 3.2, orbSpeed = 1.2, orbRainbow = false, orbColor = WHITE,
    ring = false, ringSize = 3.4, ringRainbow = false, ringColor = WHITE,
    steps = false, stepsRainbow = false, stepsColor = WHITE,
    trail = false,
    aura = false, auraRate = 30, auraColor = WHITE,
    glow = false, glowFill = 0.75, glowColor = WHITE,
    toolGlow = false,
    targetEsp = false, targetMode = "Fire Spirits", targetColor = C.ice, targetName = true, targetDistance = true, targetHealth = true,
    targetVisual = "Ghost Orbit", targetCount = 6, targetRadius = 2.8, targetSpeed = 1.35, targetHeight = 2.6, targetSize = 0.65, targetPulse = true, targetRainbow = true, targetOnlyVisible = true,

    chams = false, chamsMode = "Outline", chamsColor = C.rose, chamsPulse = false, chamsTransparency = 0.45,
    jumpCircle = false, jumpCircleSize = 3.2, jumpCircleThickness = 0.12, jumpCircleColor = C.ice, jumpCircleRainbow = true, jumpCirclePulse = true, jumpFade = 2.6, jumpRise = 0.25,
    -- model
    mat = "Off", skinColor = false, skinCol = C.silver, rainbowSkin = false, ghost = 0, headless = false,
    -- wings
    wings = false, wingStyle = "Angel", wingSize = 1, wingColorA = WHITE, wingColorB = C.gray,
    wingGradient = true, wingRainbow = false, wingGlow = true, wingAlpha = 0.1,
    flapSpeed = 2.2, flapAmp = 16, wingFloat = true, wingAir = true, wingParticles = false,
    -- world
    skyPreset = "Off", shaderPreset = "Off",
    timeOn = false, timeVal = 0, timeSpeed = 0,
    stars = false, starCount = 3000,
    atmOn = false, atmDensity = 0.35, atmHaze = 1, atmGlare = 0, atmColor = Color3.fromRGB(45, 60, 120),
    fogOn = false, fogStart = 60, fogEnd = 700, fogColor = Color3.fromRGB(10, 14, 34),
    ambOn = false, ambColor = Color3.fromRGB(38, 48, 95),
    expOn = false, exposure = 0,
    bloom = false, bloomInt = 0.8, bloomSize = 28, bloomThr = 0.9,
    cc = false, ccSat = 0.2, ccCon = 0.1, ccBri = 0, tint = WHITE,
    sun = false, sunInt = 0.15, dof = false, dofFar = 0.25, blur = false, blurSize = 6,
    const = false, constCount = 10, constTwinkle = true, constColor = WHITE,
    fireflies = false, flyColor = Color3.fromRGB(255, 240, 160), snow = false, snowRate = 120, dust = false,
    worldGrid = false, worldGridSize = 22, worldGridColor = C.ice, worldGridPulse = true, worldGridStyle = "Circuit",
    worldPulse = false, worldPulseRate = 2.2, worldPulseColor = C.violet,
    worldShards = false, worldShardCount = 12, worldShardColor = C.rose, worldShardSpeed = 0.8,
    skyRings = false, skyRingCount = 3, skyRingRadius = 42, skyRingHeight = 18, skyRingSpeed = 0.35, skyRingColor = C.violet, skyRingRainbow = true,
    aurora = false, auroraColor = C.ice, auroraStrength = 0.35,
    music = false, musicId = "", musicVol = 0.6, musicLoop = true, musicTrack = "Custom",
    antiFling = false, antiFlingMaxSpeed = 85, antiFlingMaxAngular = 70, antiFlingRecovery = true,
    skinPreset = "Default", skinUserId = "", skinScale = 1,
    animId = "", animSpeed = 1, animLoop = true,
    -- settings
    menuTransp = 0.1, menuBlur = true, blurAmt = 14, dim = true, configName = "default", autoload = false,
    hudEdit = false, hudMusicX = 0.5, hudMusicY = 0.78, hudTargetX = 0.78, hudTargetY = 0.28,
}
local State = {}
for k, v in pairs(Defaults) do State[k] = v end

local render, notify, rebuildAll, refreshPreview, unload -- forward declarations
-- HUD and WIN hold what used to be dozens of separate top-level locals for the
-- on-screen overlay and the menu window; Lua/Luau caps a chunk at 200 locals,
-- so these two tables keep the main chunk well under that limit.
local HUD, WIN = {}, {}

---------------------------------------------------------------- roots
local PlayerGui = LP:WaitForChild("PlayerGui")
local gui = new("ScreenGui", {
    Name = "Hiruku", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 2147483000, Parent = PlayerGui,
})
local hud = new("ScreenGui", {
    Name = "HirukuHUD", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 2147482999, Parent = PlayerGui,
})
local fxFolder = new("Folder", { Name = "HirukuFX", Parent = workspace })

---------------------------------------------------------------- icons (Lucide)
local Glyphs = {
    eye = "O", ["moon-star"] = "*", feather = "W", music = "M", settings = "S", search = "Q", save = "D",
    user = "U", ["chevron-down"] = "v", play = ">", pause = "||", square = "#", ["rotate-cw"] = "R",
    code = "</>", activity = "~", wifi = "W", clock = "O", power = "P", download = "D", upload = "U",
    target = "O", shield = "S", zap = "Z", circle = "O", layers = "L", sparkles = "*", scan = "X", grid = "G",
}
local iconTargets = setmetatable({}, { __mode = "k" })
local Lucide

local function applyIcon(img, name)
    local g = img:FindFirstChild("Glyph")
    if g then g.Visible = true end
    img.Image = ""
    if not Lucide then return end
    local ok, asset = pcall(Lucide.GetAsset, name, 48)
    if ok and asset and asset.Url and asset.Url ~= "" then
        img.Image = asset.Url
        img.ImageRectSize = asset.ImageRectSize or Vector2.zero
        img.ImageRectOffset = asset.ImageRectOffset or Vector2.zero
        if not img:GetAttribute("HirukuIconLoadBound") then
            img:SetAttribute("HirukuIconLoadBound", true)
            pcall(function()
                img:GetPropertyChangedSignal("IsLoaded"):Connect(function()
                    if g and g.Parent then g.Visible = not img.IsLoaded end
                end)
            end)
        end
        task.defer(function()
            if g and g.Parent then g.Visible = not img.IsLoaded end
        end)
    end
end
local function icon(parent, name, size, color)
    local img = new("ImageLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), ImageColor3 = color or WHITE, Parent = parent,
    })
    new("TextLabel", {
        Name = "Glyph", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = Glyphs[name] or "•",
        TextColor3 = color or WHITE, TextSize = math.max(size - 4, 8), Font = Enum.Font.GothamBold, Parent = img,
    })
    iconTargets[img] = name
    applyIcon(img, name)
    return img
end
local function tintIcon(img, color)
    img.ImageColor3 = color
    local g = img:FindFirstChild("Glyph")
    if g then g.TextColor3 = color end
end

task.spawn(function()
    local url = env.HirukuIconLib or "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"
    local ok, lib = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(lib) == "table" and lib.GetAsset then
        Lucide = lib
        for img, name in pairs(iconTargets) do
            if img.Parent then applyIcon(img, name) end
        end
    end
end)

---------------------------------------------------------------- notifications
local toastHolder = new("Frame", {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(230, 320),
    BackgroundTransparency = 1, ZIndex = 20, Parent = gui,
})
new("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastHolder,
})
local toastN = 0
notify = function(title, text)
    if not State.notify then return end
    toastN += 1
    local t = new("CanvasGroup", {
        Size = UDim2.fromOffset(220, 44), BackgroundColor3 = Color3.fromRGB(10, 10, 12), BackgroundTransparency = 0.05,
        GroupTransparency = 1, LayoutOrder = toastN, Parent = toastHolder,
    })
    corner(t, 8)
    stroke(t, WHITE, 0.88)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 16), Text = title,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = t,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 23), Size = UDim2.new(1, -24, 0, 14), Text = text or "",
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = t,
    })
    tween(t, 0.2, { GroupTransparency = 0 })
    task.delay(1.8, function()
        if t.Parent then
            tween(t, 0.25, { GroupTransparency = 1 })
            task.delay(0.3, function() if t.Parent then t:Destroy() end end)
        end
    end)
end

---------------------------------------------------------------- world: lighting, sky, shaders
local LOrig = {}
for _, k in ipairs({ "ClockTime", "Ambient", "OutdoorAmbient", "ExposureCompensation", "FogColor", "FogStart", "FogEnd" }) do
    LOrig[k] = Lighting[k]
end
local touched = {}
local skyObj = Lighting:FindFirstChildOfClass("Sky")
local skyOrig = skyObj and { skyObj.StarCount, skyObj.CelestialBodiesShown }
local ownSky, skyTouched
local atmObj = Lighting:FindFirstChildOfClass("Atmosphere")
local atmOrig = atmObj and {
    Density = atmObj.Density, Offset = atmObj.Offset, Color = atmObj.Color,
    Decay = atmObj.Decay, Glare = atmObj.Glare, Haze = atmObj.Haze,
}
local ownAtm, atmTouched

local function getSky()
    if skyObj and skyObj.Parent then return skyObj end
    ownSky = ownSky or new("Sky", { Name = "HirukuSky", Parent = Lighting })
    return ownSky
end
local function getAtm()
    if atmObj and atmObj.Parent then return atmObj end
    ownAtm = ownAtm or new("Atmosphere", { Name = "HirukuAtmosphere", Parent = Lighting })
    return ownAtm
end
local function setL(k, v) Lighting[k] = v touched[k] = true end

local function restoreWorld()
    for k in pairs(touched) do Lighting[k] = LOrig[k] end
    table.clear(touched)
    if skyTouched then
        if skyObj and skyObj.Parent and skyOrig then skyObj.StarCount = skyOrig[1] skyObj.CelestialBodiesShown = skyOrig[2] end
        if ownSky then ownSky:Destroy() ownSky = nil end
        skyTouched = false
    end
    if atmTouched then
        if atmObj and atmObj.Parent and atmOrig then for k, v in pairs(atmOrig) do atmObj[k] = v end end
        if ownAtm then ownAtm:Destroy() ownAtm = nil end
        atmTouched = false
    end
end
local function worldOff(v) if not v then restoreWorld() end end

local function stepWorld(dt)
    if State.timeOn then
        if State.timeSpeed > 0 then State.timeVal = (State.timeVal + dt * State.timeSpeed) % 24 end
        setL("ClockTime", State.timeVal)
    end
    if State.ambOn then setL("Ambient", State.ambColor) setL("OutdoorAmbient", State.ambColor) end
    if State.expOn then setL("ExposureCompensation", State.exposure) end
    if State.fogOn then setL("FogColor", State.fogColor) setL("FogStart", State.fogStart) setL("FogEnd", State.fogEnd) end
    if State.stars then
        local s = getSky()
        s.StarCount = State.starCount
        s.CelestialBodiesShown = true
        skyTouched = true
    end
    if State.atmOn then
        local a = getAtm()
        a.Density, a.Haze, a.Glare, a.Color = State.atmDensity, State.atmHaze, State.atmGlare, State.atmColor
        atmTouched = true
    end
end

-- post-processing
local FX = {}
local function fx(class)
    if not FX[class] or not FX[class].Parent then
        FX[class] = new(class, { Name = "Hiruku" .. class, Enabled = false, Parent = Lighting })
    end
    return FX[class]
end
local function applyPost()
    local b = fx("BloomEffect")
    b.Intensity, b.Size, b.Threshold, b.Enabled = State.bloomInt, State.bloomSize, State.bloomThr, State.bloom
    local c = fx("ColorCorrectionEffect")
    c.Saturation, c.Contrast, c.Brightness, c.TintColor, c.Enabled = State.ccSat, State.ccCon, State.ccBri, State.tint, State.cc
    local s = fx("SunRaysEffect")
    s.Intensity, s.Spread, s.Enabled = State.sunInt, 0.8, State.sun
    local d = fx("DepthOfFieldEffect")
    d.FarIntensity, d.FocusDistance, d.InFocusRadius, d.NearIntensity, d.Enabled = State.dofFar, 25, 45, 0, State.dof
    local bl = fx("BlurEffect")
    bl.Size, bl.Enabled = State.blurSize, State.blur
end

local ShaderPresets = {
    Cinematic = { bloom = true, bloomInt = 0.6, cc = true, ccSat = 0.1, ccCon = 0.25, ccBri = 0, tint = Color3.fromRGB(205, 218, 255), sun = true, sunInt = 0.1, dof = true, blur = false, bars = true },
    Neon = { bloom = true, bloomInt = 1.7, bloomThr = 0.75, cc = true, ccSat = 0.6, ccCon = 0.3, ccBri = 0, tint = Color3.fromRGB(230, 200, 255), sun = false, dof = false, blur = false },
    Warm = { bloom = true, bloomInt = 0.9, cc = true, ccSat = 0.35, ccCon = 0.15, ccBri = 0.02, tint = Color3.fromRGB(255, 225, 190), sun = true, sunInt = 0.25, dof = false, blur = false },
    Noir = { bloom = true, bloomInt = 0.5, cc = true, ccSat = -1, ccCon = 0.4, ccBri = -0.02, tint = WHITE, sun = false, dof = false, blur = false, vignette = true },
    Dream = { bloom = true, bloomInt = 2.2, bloomSize = 46, bloomThr = 0.7, cc = true, ccSat = 0.3, ccCon = 0, ccBri = 0.03, tint = Color3.fromRGB(255, 205, 235), sun = true, sunInt = 0.2, dof = true, dofFar = 0.4, blur = false },
}
local SkyPresets = {
    ["Night Blue"] = { timeOn = true, timeVal = 0, timeSpeed = 0, stars = true, starCount = 4000, atmOn = true, atmDensity = 0.42, atmHaze = 1.6, atmGlare = 0, atmColor = Color3.fromRGB(45, 60, 120), fogOn = true, fogColor = Color3.fromRGB(10, 14, 34), fogStart = 60, fogEnd = 700, ambOn = true, ambColor = Color3.fromRGB(38, 48, 95), expOn = true, exposure = -0.1, bloom = true, bloomInt = 0.9, cc = true, ccSat = 0.15, ccCon = 0.2, tint = Color3.fromRGB(205, 218, 255), const = true },
    ["Deep Space"] = { timeOn = true, timeVal = 0, timeSpeed = 0, stars = true, starCount = 5000, atmOn = true, atmDensity = 0.15, atmHaze = 0.5, atmGlare = 0, atmColor = Color3.fromRGB(20, 20, 45), fogOn = true, fogColor = Color3.fromRGB(3, 3, 8), fogStart = 80, fogEnd = 900, ambOn = true, ambColor = Color3.fromRGB(28, 28, 55), expOn = true, exposure = -0.3, bloom = true, bloomInt = 1.2, cc = true, ccSat = 0.25, ccCon = 0.25, tint = Color3.fromRGB(220, 210, 255), const = true },
    Sunset = { timeOn = true, timeVal = 17.7, timeSpeed = 0, stars = false, atmOn = true, atmDensity = 0.38, atmHaze = 2.2, atmGlare = 0.4, atmColor = Color3.fromRGB(255, 160, 110), fogOn = true, fogColor = Color3.fromRGB(255, 170, 120), fogStart = 80, fogEnd = 1100, ambOn = true, ambColor = Color3.fromRGB(150, 110, 100), expOn = true, exposure = 0, bloom = true, bloomInt = 1, cc = true, ccSat = 0.35, ccCon = 0.15, tint = Color3.fromRGB(255, 225, 190), sun = true, sunInt = 0.25, const = false },
    ["Purple Haze"] = { timeOn = true, timeVal = 21, timeSpeed = 0, stars = true, starCount = 3000, atmOn = true, atmDensity = 0.45, atmHaze = 2, atmGlare = 0, atmColor = Color3.fromRGB(90, 55, 140), fogOn = true, fogColor = Color3.fromRGB(45, 24, 80), fogStart = 50, fogEnd = 650, ambOn = true, ambColor = Color3.fromRGB(80, 50, 130), expOn = true, exposure = -0.05, bloom = true, bloomInt = 1.4, cc = true, ccSat = 0.4, ccCon = 0.2, tint = Color3.fromRGB(230, 200, 255), const = true },
    ["Blood Moon"] = { timeOn = true, timeVal = 0, timeSpeed = 0, stars = true, starCount = 2500, atmOn = true, atmDensity = 0.4, atmHaze = 2.2, atmGlare = 0, atmColor = Color3.fromRGB(150, 30, 40), fogOn = true, fogColor = Color3.fromRGB(45, 8, 14), fogStart = 40, fogEnd = 550, ambOn = true, ambColor = Color3.fromRGB(90, 22, 30), expOn = true, exposure = -0.2, bloom = true, bloomInt = 1, cc = true, ccSat = 0.2, ccCon = 0.3, tint = Color3.fromRGB(255, 200, 200), const = false },
}

local buildConst, updateEmitters -- defined below
local function applyPreset(tbl)
    for k, v in pairs(tbl) do State[k] = v end
    applyPost()
    buildConst()
    render(true)
end
local function applySkyPreset(name)
    if name == "Off" then
        for _, k in ipairs({ "timeOn", "stars", "atmOn", "fogOn", "ambOn", "expOn", "const" }) do State[k] = false end
        restoreWorld()
        buildConst()
        render(true)
    else
        applyPreset(SkyPresets[name])
    end
    notify("Sky", name)
end
local function applyShaderPreset(name)
    if name == "Off" then
        for _, k in ipairs({ "bloom", "cc", "sun", "dof", "blur" }) do State[k] = false end
        State.tint = WHITE
        applyPost()
        render(true)
    else
        applyPreset(ShaderPresets[name])
    end
    notify("Shaders", name)
end

-- camera-following emitters (fireflies / snow / dust)
local SkyEm = {}
local function ensureEm(kind)
    local e = SkyEm[kind]
    if e and e.part.Parent then return e end
    local part = new("Part", {
        Name = "Hiruku" .. kind, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
        Transparency = 1, Massless = true, Parent = fxFolder,
    })
    local em = new("ParticleEmitter", {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", LightEmission = 1, Enabled = false,
        Rotation = NumberRange.new(0, 360), Shape = Enum.ParticleEmitterShape.Box,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Parent = part,
    })
    e = { part = part, em = em, off = Vector3.zero }
    if kind == "fireflies" then
        part.Size = Vector3.new(70, 16, 70)
        e.off = Vector3.new(0, -1, 0)
        em.Lifetime = NumberRange.new(5, 9)
        em.Speed = NumberRange.new(0.3, 1.2)
        em.SpreadAngle = Vector2.new(180, 180)
        em.EmissionDirection = Enum.NormalId.Top
        em.Rate = 22
        em.Size = NumberSequence.new({ NSK(0, 0), NSK(0.2, 0.45), NSK(0.8, 0.45), NSK(1, 0) })
        em.Transparency = NumberSequence.new({ NSK(0, 1), NSK(0.2, 0), NSK(0.8, 0), NSK(1, 1) })
    elseif kind == "snow" then
        part.Size = Vector3.new(90, 1, 90)
        e.off = Vector3.new(0, 30, 0)
        em.Texture = "rbxasset://textures/particles/smoke_main.dds"
        em.LightEmission = 0.4
        em.EmissionDirection = Enum.NormalId.Bottom
        em.Lifetime = NumberRange.new(9, 12)
        em.Speed = NumberRange.new(4, 7)
        em.SpreadAngle = Vector2.new(6, 6)
        em.Size = NumberSequence.new(0.22)
        em.Transparency = NumberSequence.new(0.25)
        em.Acceleration = Vector3.new(1.5, 0, 0.5)
    else
        part.Size = Vector3.new(50, 20, 50)
        e.off = Vector3.new(0, 3, 0)
        em.Lifetime = NumberRange.new(6, 10)
        em.Speed = NumberRange.new(0.2, 0.7)
        em.SpreadAngle = Vector2.new(180, 180)
        em.Rate = 25
        em.Size = NumberSequence.new(0.14)
        em.Transparency = NumberSequence.new({ NSK(0, 1), NSK(0.3, 0.35), NSK(0.7, 0.35), NSK(1, 1) })
    end
    SkyEm[kind] = e
    return e
end
updateEmitters = function()
    local function set(kind, on, color, rate)
        if on then
            local e = ensureEm(kind)
            e.em.Enabled = true
            e.em.Color = ColorSequence.new(color)
            if rate then e.em.Rate = rate end
        elseif SkyEm[kind] then
            SkyEm[kind].em.Enabled = false
        end
    end
    set("fireflies", State.fireflies, State.flyColor)
    set("snow", State.snow, WHITE, State.snowRate)
    set("dust", State.dust, Color3.fromRGB(225, 225, 240))
end

-- constellations (glowing star-lines that follow the camera like a skybox)
local constFolder
local constParts, constBeams = {}, {}
local constPos, constColor
buildConst = function()
    if constFolder then constFolder:Destroy() constFolder = nil end
    table.clear(constParts)
    table.clear(constBeams)
    constPos, constColor = nil, nil
    if not State.const then return end
    constFolder = new("Folder", { Name = "HirukuConst", Parent = fxFolder })
    local rng = Random.new(20260920)
    local R = 340
    for _ = 1, State.constCount do
        local az = rng:NextNumber(0, math.pi * 2)
        local el = rng:NextNumber(math.rad(14), math.rad(78))
        local dir = Vector3.new(math.cos(el) * math.cos(az), math.sin(el), math.cos(el) * math.sin(az))
        local basis = CFrame.lookAt(Vector3.zero, dir)
        local right, up = basis.RightVector, basis.UpVector
        local x, y, prev = 0, 0, nil
        for i = 1, rng:NextInteger(5, 8) do
            if i > 1 then
                local ang, step = rng:NextNumber(0, math.pi * 2), rng:NextNumber(14, 30)
                x += math.cos(ang) * step
                y += math.sin(ang) * step
            end
            local sz = rng:NextNumber(1.6, 3)
            local p = new("Part", {
                Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz), Material = Enum.Material.Neon, Anchored = true,
                CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Massless = true,
                Transparency = 0.1, Parent = constFolder,
            })
            local a = new("Attachment", { Parent = p })
            table.insert(constParts, { part = p, off = dir * R + right * x + up * y, phase = rng:NextNumber(0, 6.28) })
            if prev then
                table.insert(constBeams, new("Beam", {
                    Attachment0 = prev, Attachment1 = a, Width0 = 0.5, Width1 = 0.5, FaceCamera = true,
                    LightEmission = 1, Segments = 1, Parent = p,
                }))
            end
            prev = a
        end
    end
end
local twinkleAcc = 0
local function stepConst(dt, t, camPos)
    if not constFolder then return end
    if not constPos or (camPos - constPos).Magnitude > 4 then
        constPos = camPos
        for _, it in ipairs(constParts) do it.part.Position = camPos + it.off end
    end
    if constColor ~= State.constColor then
        constColor = State.constColor
        for _, it in ipairs(constParts) do it.part.Color = constColor end
        for _, b in ipairs(constBeams) do b.Color = ColorSequence.new(constColor) end
    end
    twinkleAcc += dt
    if twinkleAcc >= 0.05 then
        twinkleAcc = 0
        for _, it in ipairs(constParts) do
            it.part.Transparency = State.constTwinkle and (0.05 + (math.sin(t * 1.6 + it.phase) * 0.5 + 0.5) * 0.55) or 0.1
        end
        local bt = State.constTwinkle and (0.25 + (math.sin(t * 0.9) * 0.5 + 0.5) * 0.3) or 0.3
        for _, b in ipairs(constBeams) do b.Transparency = NumberSequence.new(bt) end
    end
end

---------------------------------------------------------------- subjects: real character + preview clone
local function newSubject(preview)
    return { preview = preview, wing = {}, hat = {}, halo = {}, orbs = {}, ring = {}, jump = {}, parts = {}, orig = {}, feet = 3, applied = false }
end
local Real, Prev = newSubject(false), newSubject(true)
Real.holder = new("Folder", { Name = "Real", Parent = fxFolder })

local function bindSubject(subj, model)
    subj.model = model
    subj.root = model and model:FindFirstChild("HumanoidRootPart")
    subj.torso = model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso"))
    subj.head = model and model:FindFirstChild("Head")
    subj.hum = model and model:FindFirstChildOfClass("Humanoid")
    subj.parts, subj.orig, subj.applied, subj.face = {}, {}, false, nil
    if model then
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then table.insert(subj.parts, d) end
        end
    end
    if subj.head then subj.face = subj.head:FindFirstChildOfClass("Decal") end
    subj.feet = 3
    if subj.hum and subj.root and subj.hum.RigType == Enum.HumanoidRigType.R15 then
        subj.feet = subj.hum.HipHeight + subj.root.Size.Y / 2
    end
end

local function mkPart(subj, size, mat, shape)
    local p = Instance.new("Part")
    p.Size = size
    p.Material = mat or Enum.Material.Neon
    p.Anchored = true
    p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    if shape then p.Shape = shape end
    p.Parent = subj.holder
    return p
end

local function clearFX(subj)
    if subj.holder then subj.holder:ClearAllChildren() end
    subj.wing, subj.hat, subj.halo, subj.orbs, subj.ring, subj.jump = {}, {}, {}, {}, {}, {}
end

-- wings ------------------------------------------------------
local WingMul = {
    Angel = { spd = 1, amp = 1 }, Demon = { spd = 0.75, amp = 1.15 },
    Fairy = { spd = 2.8, amp = 0.55 }, Cyber = { spd = 0.6, amp = 0.7 },
}
local function wingSpec(style, s)
    local B = {}
    local function add(L, W, T, theta, z, mesh, shade, tr, idx)
        B[#B + 1] = { L = L * s, W = W * s, T = T, theta = math.rad(theta), z = z or 0, mesh = mesh, shade = shade, tr = tr or 0, idx = idx }
    end
    if style == "Angel" then
        local rows = {
            { n = 7, len = 3.0, w = 0.34, tr = 0.03 }, { n = 7, len = 2.35, w = 0.31, tr = 0.12 },
            { n = 6, len = 1.72, w = 0.28, tr = 0.2 }, { n = 5, len = 1.1, w = 0.24, tr = 0.3 },
        }
        for r, row in ipairs(rows) do
            for i = 1, row.n do
                add(row.len * (1 - math.abs(i - (row.n + 1) / 2) * 0.035), row.w, 0.045, 8 + (i - 1) * 16 + (r - 1) * 7, (r - 1) * 0.04,
                    "Sphere", (r - 1) / 3 + (i - 1) / (row.n * 3), row.tr, i + r * 2)
            end
        end
    elseif style == "Demon" then
        local lens = { 3.5, 3.7, 3.3, 2.8, 2.2 }
        add(1.7, 0.22, 0.14, 4, 0, "Block", 0, 0, 0)
        for i = 1, 5 do add(lens[i], 0.13, 0.09, 14 + (i - 1) * 24, 0.01, "Block", 0, 0, i) end
        for i = 1, 4 do add((lens[i] + lens[i + 1]) * 0.36, 0.95, 0.03, 14 + (i - 0.5) * 24, -0.01, "Sphere", 1, 0.3, i) end
    elseif style == "Fairy" then
        add(3.1, 1.7, 0.03, 28, 0, "Sphere", 0, 0.35, 1)
        add(3.1, 0.07, 0.05, 28, 0.02, "Block", 1, 0, 1)
        add(2.3, 1.15, 0.03, 62, 0.03, "Sphere", 0.3, 0.5, 2)
        add(2.1, 1.15, 0.03, 118, 0, "Sphere", 0.6, 0.35, 3)
        add(2.1, 0.06, 0.05, 118, 0.02, "Block", 1, 0, 3)
    else -- Cyber
        for i = 1, 6 do add(3.2 - (i - 1) * 0.36, 0.2, 0.06, 6 + (i - 1) * 26, 0, "Block", (i - 1) / 5, 0, i) end
        for i = 1, 5 do add(1.7 - (i - 1) * 0.2, 0.16, 0.06, 19 + (i - 1) * 26, 0.045, "Block", (i - 1) / 4, 0.15, i + 1) end
    end
    return B
end

local function buildWings(subj)
    if not (State.wings and subj.torso) then return end
    local torso = subj.torso
    local spec = wingSpec(State.wingStyle, State.wingSize)
    local maxL = 0
    for _, b in ipairs(spec) do maxL = math.max(maxL, b.L) end
    local hy, hz = torso.Size.Y * 0.2, torso.Size.Z / 2 + 0.06
    for side = -1, 1, 2 do
        for _, b in ipairs(spec) do
            local p = mkPart(subj, Vector3.new(b.W, b.L, b.T), State.wingGlow and Enum.Material.Neon or Enum.Material.SmoothPlastic)
            if b.mesh == "Sphere" then new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p }) end
            local item = { part = p, side = side, b = b, base = CFrame.new(side * 0.28, hy, hz + b.z), c1inv = CFrame.new(0, b.L / 2, 0) }
            if not subj.preview then
                p.Anchored = false
                item.weld = new("Weld", { Part0 = torso, Part1 = p, C1 = CFrame.new(0, -b.L / 2, 0), Parent = p })
                if State.wingParticles and b.L >= maxL * 0.85 then
                    new("ParticleEmitter", {
                        Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 5, Lifetime = NumberRange.new(1, 2),
                        Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
                        Size = NumberSequence.new({ NSK(0, 0.3), NSK(1, 0) }), Transparency = NumberSequence.new({ NSK(0, 0), NSK(1, 1) }),
                        Color = ColorSequence.new(State.wingColorA), Parent = p,
                    })
                end
            end
            table.insert(subj.wing, item)
        end
    end
end

local function wingColor(b, t)
    if State.wingRainbow then return Color3.fromHSV((t * 0.2 + b.idx * 0.05) % 1, 0.55, 1) end
    if State.wingGradient then return State.wingColorA:Lerp(State.wingColorB, math.clamp(b.shade, 0, 1)) end
    return State.wingColorA
end

local function poseWings(subj, t, air)
    local m = WingMul[State.wingStyle] or WingMul.Angel
    local amp = math.rad(State.flapAmp) * m.amp * (air and 1.5 or 1)
    local spd = State.flapSpeed * m.spd * (air and 1.8 or 1)
    local floatY = State.wingFloat and math.sin(t * 1.3) * 0.08 or 0
    local open = (air and State.wingAir) and math.rad(18) or 0
    local torsoCF = subj.torso.CFrame
    for _, f in ipairs(subj.wing) do
        local wave = math.sin(t * spd - f.b.idx * 0.16) * amp
        local yaw = math.rad(-18) + wave
        local lift = math.sin(t * spd * 0.5 + f.b.idx * 0.11) * math.rad(3)
        local C0 = f.base * CFrame.new(0, floatY, 0) * CFrame.Angles(lift, f.side * yaw, 0) * CFrame.Angles(0, 0, -f.side * (f.b.theta + open))
        if f.weld then f.weld.C0 = C0 else f.part.CFrame = torsoCF * C0 * f.c1inv end
        f.part.Color = wingColor(f.b, t)
        f.part.Transparency = math.clamp(f.b.tr + State.wingAlpha, 0, 0.95)
    end
end

-- accessories ------------------------------------------------
local function buildAccessories(subj)
    if State.hat and subj.head then
        local layers = 12
        for i = 1, layers do
            local k = (i - 1) / (layers - 1)
            local radius = (2.55 - k * 2.15) * State.hatSize
            local thickness = 0.065 * State.hatSize
            local p = mkPart(subj, Vector3.new(thickness, radius, radius), Enum.Material.Neon, Enum.PartType.Cylinder)
            table.insert(subj.hat, { part = p, i = i, y = 0.68 + k * 0.22 * State.hatSize, radius = radius })
        end
    end
    if State.halo and subj.head then
        for i = 1, 18 do table.insert(subj.halo, { part = mkPart(subj, Vector3.new(0.14, 0.08, 0.42)), i = i }) end
    end
    if State.orbs and subj.root then
        for i = 1, State.orbCount do
            local s = 0.42 + State.orbRadius * 0.018
            table.insert(subj.orbs, { part = mkPart(subj, Vector3.new(s, s, s), Enum.Material.Neon, Enum.PartType.Ball), i = i })
        end
    end
    if State.ring and subj.root then
        for i = 1, 36 do table.insert(subj.ring, { part = mkPart(subj, Vector3.new(0.18, 0.05, 0.5)), i = i, n = 36, inner = false }) end
        for i = 1, 24 do table.insert(subj.ring, { part = mkPart(subj, Vector3.new(0.14, 0.05, 0.4)), i = i, n = 24, inner = true }) end
    end
end

local function hue(t, k, speed) return Color3.fromHSV((t * (speed or 0.2) + k) % 1, 0.5, 1) end

local function stepFX(subj, t, air)
    local root, head, torso = subj.root, subj.head, subj.torso
    if not (root and root.Parent and torso and torso.Parent) then return end
    if subj.wing[1] then poseWings(subj, t, air) end
    if subj.hat[1] and head then
        local hcf, spin = head.CFrame, t * State.hatSpin
        for _, it in ipairs(subj.hat) do
            it.part.CFrame = hcf * CFrame.new(State.hatSide, State.hatHeight + it.y - 0.68, State.hatForward) * CFrame.Angles(0, spin, math.pi / 2)
            it.part.Color = State.hatRainbow and hue(t, it.i * 0.04, 0.25) or State.hatColor:Lerp(WHITE, (it.i - 1) / math.max(#subj.hat - 1, 1) * 0.5)
        end
    end
    if subj.halo[1] and head then
        local hcf, n = head.CFrame, #subj.halo
        for _, it in ipairs(subj.halo) do
            local a = it.i / n * math.pi * 2 + t * 1.2
            local pos = Vector3.new(math.cos(a) * 0.85, State.haloHeight, math.sin(a) * 0.85)
            it.part.CFrame = hcf * CFrame.new(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
            it.part.Color = State.haloRainbow and hue(t, it.i / n) or State.haloColor
        end
    end
    if subj.orbs[1] then
        local rp, n = root.Position, #subj.orbs
        for _, it in ipairs(subj.orbs) do
            local a = t * State.orbSpeed + it.i / n * math.pi * 2
            local bob = math.sin(t * State.orbSpeed * 1.7 + it.i * 1.2) * 0.55
            local vertical = 0.75 + bob + math.sin(a * 1.5 + it.i) * 0.12
            it.part.CFrame = CFrame.new(rp + Vector3.new(math.cos(a) * State.orbRadius, vertical, math.sin(a) * State.orbRadius))
                * CFrame.Angles(t * 1.2 + it.i, a, math.sin(t + it.i) * 0.2)
            it.part.Color = State.orbRainbow and hue(t, it.i / n) or State.orbColor
        end
    end
    if subj.ring[1] then
        local rp = root.Position
        local base = Vector3.new(rp.X, rp.Y - subj.feet + 0.12, rp.Z)
        local pulse = 1 + math.sin(t * 2) * 0.03
        for _, it in ipairs(subj.ring) do
            local R = State.ringSize * (it.inner and 0.68 or 1) * pulse
            local a = it.i / it.n * math.pi * 2 + t * (it.inner and -0.9 or 0.6)
            local pos = base + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
            it.part.CFrame = CFrame.new(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
            it.part.Color = State.ringRainbow and hue(t, it.i / it.n, 0.15) or State.ringColor
        end
    end
end

-- model overrides (material / colour / ghost / headless) -----
local function restoreModel(subj)
    for p, o in pairs(subj.orig) do
        if p.Parent then
            if p:IsA("BasePart") then p.Material, p.Color, p.Transparency = o[1], o[2], o[3] else p.Transparency = o[1] end
        end
    end
    subj.orig, subj.applied = {}, false
end
local function stepModel(subj, t)
    local want = State.mat ~= "Off" or State.skinColor or State.rainbowSkin or State.ghost > 0 or State.headless
    if want then
        local mat = State.mat ~= "Off" and Enum.Material[State.mat] or nil
        for _, p in ipairs(subj.parts) do
            if p.Parent then
                local o = subj.orig[p]
                if not o then o = { p.Material, p.Color, p.Transparency } subj.orig[p] = o end
                p.Material = mat or o[1]
                if State.rainbowSkin then p.Color = Color3.fromHSV((t * 0.2) % 1, 0.5, 1)
                elseif State.skinColor then p.Color = State.skinCol
                else p.Color = o[2] end
                local tr = o[3]
                if State.ghost > 0 then tr = math.max(tr, State.ghost) end
                if State.headless and p == subj.head then tr = 1 end
                p.Transparency = tr
            end
        end
        if subj.face then
            local o = subj.orig[subj.face]
            if not o then o = { subj.face.Transparency } subj.orig[subj.face] = o end
            subj.face.Transparency = State.headless and 1 or o[1]
        end
        subj.applied = true
    elseif subj.applied then
        restoreModel(subj)
    end
end

rebuildAll = function()
    for _, s in ipairs({ Real, Prev }) do
        if s.holder then
            clearFX(s)
            if s.root and s.root.Parent then
                buildWings(s)
                buildAccessories(s)
            end
        end
    end
end

local playerVisuals = {}
local visualFolder = new("Folder", { Name = "HirukuPlayers", Parent = fxFolder })

local function destroyPlayerVisual(plr)
    local v = playerVisuals[plr]
    if v then
        if v.highlight then pcall(function() v.highlight:Destroy() end) end
        if v.billboard then pcall(function() v.billboard:Destroy() end) end
        playerVisuals[plr] = nil
    end
end

local function playerRoleText(plr)
    local role = plr:GetAttribute("Role")
    if role then return tostring(role) end
    local character = plr.Character
    if character then
        local rv = character:FindFirstChild("Role")
        if rv and rv:IsA("StringValue") then return rv.Value end
    end
    return ""
end

local function updatePlayerVisual(plr, t)
    if plr == LP or not plr.Character then
        destroyPlayerVisual(plr)
        return
    end
    local character = plr.Character
    local root = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not root or not hum then
        destroyPlayerVisual(plr)
        return
    end

    local v = playerVisuals[plr]
    if State.chams then
        if not v then v = {} playerVisuals[plr] = v end
        if not v.highlight or not v.highlight.Parent then
            v.highlight = new("Highlight", {
                Name = "HirukuChams", Adornee = character, Parent = visualFolder,
                Enabled = true, DepthMode = Enum.HighlightDepthMode.Occluded,
                FillColor = State.chamsColor, OutlineColor = WHITE,
            })
        end
        local h = v.highlight
        h.Adornee = character
        h.DepthMode = Enum.HighlightDepthMode.Occluded
        local pulse = State.chamsPulse and (0.5 + math.sin(t * 3) * 0.5) or 0
        if State.chamsMode == "Outline" then
            h.FillTransparency = 1
            h.OutlineTransparency = 0.05
        elseif State.chamsMode == "Fill" then
            h.FillTransparency = math.clamp(State.chamsTransparency - pulse * 0.2, 0.05, 0.9)
            h.OutlineTransparency = 0.2
        elseif State.chamsMode == "Pulse" then
            h.FillTransparency = math.clamp(0.72 - pulse * 0.55, 0.08, 0.8)
            h.OutlineTransparency = math.clamp(0.75 - pulse * 0.7, 0.02, 0.8)
        else
            h.FillTransparency = 0.58
            h.OutlineTransparency = 0
        end
        h.FillColor = State.chamsColor
        h.OutlineColor = State.chamsPulse and hue(t, 0, 0.16) or WHITE
    elseif v and v.highlight then
        v.highlight:Destroy()
        v.highlight = nil
    end

    if v and v.billboard then
        v.billboard:Destroy()
        v.billboard = nil
    end
    if not State.targetEsp and not State.chams then destroyPlayerVisual(plr) end
end

local targetFX = { parts = {}, rings = {}, label = nil, target = nil, lastBuild = "" }

local function clearTargetFX()
    for _, p in ipairs(targetFX.parts) do pcall(function() p:Destroy() end) end
    for _, p in ipairs(targetFX.rings) do pcall(function() p:Destroy() end) end
    if targetFX.label then pcall(function() targetFX.label:Destroy() end) end
    if targetFX.billboard then pcall(function() targetFX.billboard:Destroy() end) end
    table.clear(targetFX.parts)
    table.clear(targetFX.rings)
    targetFX.label = nil
    targetFX.billboard = nil
    targetFX.target = nil
    targetFX.lastBuild = ""
end

local function targetPart(size, shape, transparency)
    local p = new("Part", {
        Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
        Material = Enum.Material.Neon, Size = size, Transparency = transparency or 0.08, Parent = visualFolder,
    })
    if shape then p.Shape = shape end
    table.insert(targetFX.parts, p)
    return p
end

local function rebuildTargetFX()
    clearTargetFX()
    if not State.targetEsp then return end
    local mode = State.targetVisual
    local count = math.clamp(State.targetCount, 3, 10)
    if mode == "Ghost Orbit" then
        for i = 1, count do
            targetPart(Vector3.new(State.targetSize * 0.8, State.targetSize * 1.35, State.targetSize * 0.8), Enum.PartType.Ball, 0.18)
            targetPart(Vector3.new(State.targetSize * 0.32, State.targetSize * 1.9, State.targetSize * 0.32), Enum.PartType.Ball, 0.28)
        end
    elseif mode == "Crystal Orbit" then
        for i = 1, count do targetPart(Vector3.new(State.targetSize * 0.48, State.targetSize * 2.4, State.targetSize * 0.48), nil, 0.1) end
    elseif mode == "Target Circle" then
        for i = 1, 48 do targetPart(Vector3.new(0.07, 0.045, 0.48), nil, 0.04) end
    elseif mode == "Spiral" then
        for i = 1, math.max(18, count * 4) do targetPart(Vector3.new(0.08, 0.5, 0.08), nil, 0.1) end
    else
        for i = 1, 8 do targetPart(Vector3.new(0.1, 0.1, 0.72), nil, 0.04) end
    end
    local bb = new("BillboardGui", {
        Name = "HirukuTargetMarker", Size = UDim2.fromOffset(150, 26), StudsOffset = Vector3.new(0, 4.4, 0),
        AlwaysOnTop = false, MaxDistance = 250, Parent = visualFolder,
    })
    targetFX.label = new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "TARGET", TextColor3 = State.targetColor,
        TextStrokeTransparency = 0.5, Font = Enum.Font.GothamBold, TextSize = 12, Parent = bb,
    })
    targetFX.label.Visible = false
    targetFX.billboard = bb
    targetFX.lastBuild = mode .. "|" .. tostring(count) .. "|" .. tostring(State.targetSize)
end

local function visibleTarget(plr, root)
    if not State.targetOnlyVisible then return true end
    local c = cam()
    local dir = root.Position - c.CFrame.Position
    if dir.Magnitude < 1 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LP.Character, visualFolder, fxFolder }
    local hit = workspace:Raycast(c.CFrame.Position, dir, params)
    return not hit or hit.Instance:IsDescendantOf(plr.Character)
end

local function getCrosshairTarget()
    local c = cam()
    local vp = c.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local best, bestScore
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            local head = plr.Character:FindFirstChild("Head")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if root and head and hum and hum.Health > 0 then
                local pos, onScreen = c:WorldToViewportPoint(head.Position)
                if onScreen and pos.Z > 0 then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    local maxD = math.max(65, math.min(vp.X, vp.Y) * 0.18)
                    if d <= maxD and visibleTarget(plr, head) then
                        local score = d + pos.Z * 0.0015
                        if not bestScore or score < bestScore then best, bestScore = plr, score end
                    end
                end
            end
        end
    end
    return best
end

local function updateTargetFX(t)
    if not State.targetEsp then
        if targetFX.target or #targetFX.parts > 0 then clearTargetFX() end
        return
    end
    local signature = State.targetVisual .. "|" .. tostring(State.targetCount) .. "|" .. tostring(State.targetSize)
    if signature ~= targetFX.lastBuild then rebuildTargetFX() end
    local target = getCrosshairTarget()
    targetFX.target = target
    local char = target and target.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        for _, p in ipairs(targetFX.parts) do p.Transparency = 1 end
        if targetFX.label then targetFX.label.Visible = false end
        return
    end
    local colorAt = function(i, n)
        if State.targetRainbow then return hue(t, i / math.max(n, 1), 0.18) end
        return State.targetColor
    end
    local mode = State.targetVisual
    local n = #targetFX.parts
    if mode == "Ghost Orbit" then
        local pairsCount = math.max(1, math.floor(n / 2))
        for i = 1, pairsCount do
            local a = t * State.targetSpeed * 0.8 + i / pairsCount * math.pi * 2
            local rr = State.targetRadius * (0.82 + math.sin(t * 1.2 + i) * 0.035)
            local bob = math.sin(t * 1.7 + i * 0.8) * State.targetHeight * 0.16
            local base = root.Position + Vector3.new(math.cos(a) * rr, 1.45 + bob, math.sin(a) * rr)
            local p1, p2 = targetFX.parts[(i - 1) * 2 + 1], targetFX.parts[(i - 1) * 2 + 2]
            p1.CFrame = CFrame.new(base) * CFrame.Angles(0, -a, math.sin(t * 2 + i) * 0.18)
            p2.CFrame = CFrame.new(base + Vector3.new(0, 0.45 + math.sin(t * 2 + i) * 0.06, 0)) * CFrame.Angles(math.sin(t + i), -a, 0)
            p1.Color, p2.Color = colorAt(i, pairsCount), colorAt(i + 1, pairsCount)
            local pulse = State.targetPulse and (0.05 + (math.sin(t * 4 + i) * 0.5 + 0.5) * 0.18) or 0.12
            p1.Transparency, p2.Transparency = pulse, math.min(0.42, pulse + 0.18)
        end
    elseif mode == "Crystal Orbit" then
        for i, p in ipairs(targetFX.parts) do
            local a = -t * State.targetSpeed * 0.7 + i / n * math.pi * 2
            local rr = State.targetRadius * 0.78
            local y = 1.05 + (i % 3) * 0.45 + math.sin(t * 1.4 + i) * State.targetHeight * 0.15
            p.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * rr, y, math.sin(a) * rr))
                * CFrame.Angles(t * 1.3 + i, a + math.pi * 0.5, math.sin(t + i) * 0.28)
            p.Size = Vector3.new(State.targetSize * 0.42, State.targetSize * (1.8 + math.sin(t * 2 + i) * 0.15), State.targetSize * 0.42)
            p.Color = colorAt(i, n)
            p.Transparency = State.targetPulse and 0.08 + (math.sin(t * 3 + i) * 0.5 + 0.5) * 0.16 or 0.12
        end
    elseif mode == "Target Circle" then
        for i, p in ipairs(targetFX.parts) do
            local a = i / n * math.pi * 2 + t * State.targetSpeed * 0.12
            local rr = State.targetRadius * (1 + math.sin(t * 2) * 0.025)
            local y = 0.04 + math.sin(t * 1.8) * 0.035
            p.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * rr, y, math.sin(a) * rr))
                * CFrame.Angles(0, -a, 0)
            p.Color = colorAt(i, n)
            p.Transparency = 0.04 + (State.targetPulse and (math.sin(t * 3) * 0.5 + 0.5) * 0.12 or 0)
        end
    elseif mode == "Spiral" then
        for i, p in ipairs(targetFX.parts) do
            local a = t * State.targetSpeed * 0.72 + i / n * math.pi * 4
            local rr = State.targetRadius * (0.2 + (i / n) * 0.78)
            local y = 0.25 + (i / n) * State.targetHeight + math.sin(t * 2 + i) * 0.1
            p.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * rr, y, math.sin(a) * rr))
                * CFrame.Angles(a, -a, 0)
            p.Color = colorAt(i, n)
            p.Transparency = 0.06 + (math.sin(t * 3 + i) * 0.5 + 0.5) * 0.13
        end
    else
        for i, p in ipairs(targetFX.parts) do
            local side = i <= 4 and -1 or 1
            local idx = ((i - 1) % 4) + 1
            local a = t * State.targetSpeed * 0.45
            local y = 0.45 + (idx - 1) * 0.72
            local x = side * State.targetRadius * 0.68
            p.CFrame = CFrame.new(root.Position + Vector3.new(x, y, math.sin(a + idx) * 0.35))
                * CFrame.Angles(0, side * 0.2, 0)
            p.Color = colorAt(i, n)
            p.Transparency = 0.04 + (State.targetPulse and (math.sin(t * 4 + i) * 0.5 + 0.5) * 0.1 or 0)
        end
    end
    if targetFX.label then
        targetFX.label.Visible = true
        targetFX.label.Text = State.targetName and ("TARGET  " .. target.DisplayName) or "TARGET"
        targetFX.label.TextColor3 = State.targetRainbow and hue(t, 0, 0.18) or State.targetColor
        if targetFX.billboard then targetFX.billboard.Adornee = root end
    end
end

local function refreshPlayerVisuals()
    for plr in pairs(playerVisuals) do
        if plr.Parent ~= Players then destroyPlayerVisual(plr) end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then updatePlayerVisual(plr, os.clock()) end
    end
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LP then
        bind(plr.CharacterAdded, function() task.wait(0.15) updatePlayerVisual(plr, os.clock()) end)
    end
end
bind(Players.PlayerAdded, function(plr)
    bind(plr.CharacterAdded, function() task.wait(0.15) updatePlayerVisual(plr, os.clock()) end)
end)
bind(Players.PlayerRemoving, destroyPlayerVisual)

local auraEm, glowHL, toolHL
local trailStuff = {}
local function setAura()
    if auraEm then auraEm:Destroy() auraEm = nil end
    local r = Real.root
    if not (State.aura and r and r.Parent) then return end
    auraEm = new("ParticleEmitter", {
        Name = "HirukuAura", Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = State.auraRate,
        Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
        Rotation = NumberRange.new(0, 360), LightEmission = 1,
        Size = NumberSequence.new({ NSK(0, 0.5), NSK(1, 0) }), Transparency = NumberSequence.new({ NSK(0, 0), NSK(1, 1) }),
        Color = ColorSequence.new(State.auraColor, WHITE), Parent = r,
    })
end
local function updateAura()
    if auraEm then auraEm.Rate = State.auraRate end
end
local function setTrail()
    for _, i in ipairs(trailStuff) do pcall(function() i:Destroy() end) end
    table.clear(trailStuff)
    local r = Real.root
    if not (State.trail and r and r.Parent) then return end
    local a0 = new("Attachment", { Position = Vector3.new(0, 1, 0), Parent = r })
    local a1 = new("Attachment", { Position = Vector3.new(0, -1, 0), Parent = r })
    local kp = {}
    for i = 0, 6 do table.insert(kp, CSK(i / 6, Color3.fromHSV(i / 7, 0.7, 1))) end
    local tr = new("Trail", {
        Attachment0 = a0, Attachment1 = a1, Lifetime = 0.7, LightEmission = 1,
        Transparency = NumberSequence.new({ NSK(0, 0.2), NSK(1, 1) }), Color = ColorSequence.new(kp), Parent = r,
    })
    trailStuff = { a0, a1, tr }
end
local function setGlow()
    if glowHL then glowHL:Destroy() glowHL = nil end
    local c = Real.model
    if not (State.glow and c and c.Parent) then return end
    glowHL = new("Highlight", {
        Adornee = c, FillColor = State.glowColor, FillTransparency = State.glowFill, OutlineColor = WHITE,
        OutlineTransparency = 0.3, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = c,
    })
end
local function updateGlow()
    if glowHL then glowHL.FillColor, glowHL.FillTransparency = State.glowColor, State.glowFill end
end

local antiFlingLastSafeCF
local antiFlingLastSafeTime = 0
local function stepAntiFling()
    if not State.antiFling then
        antiFlingLastSafeCF = nil
        return
    end
    local r = Real.root
    local h = Real.hum
    if not (r and r.Parent and h and h.Parent) then return end
    local lv = r.AssemblyLinearVelocity
    local av = r.AssemblyAngularVelocity
    local linear = lv.Magnitude
    local angular = av.Magnitude
    local now = os.clock()
    if linear <= State.antiFlingMaxSpeed and angular <= State.antiFlingMaxAngular then
        antiFlingLastSafeCF = r.CFrame
        antiFlingLastSafeTime = now
        return
    end
    r.AssemblyLinearVelocity = Vector3.zero
    r.AssemblyAngularVelocity = Vector3.zero
    if State.antiFlingRecovery and antiFlingLastSafeCF and now - antiFlingLastSafeTime < 0.45 then
        local dist = (r.Position - antiFlingLastSafeCF.Position).Magnitude
        if dist > 12 then r.CFrame = antiFlingLastSafeCF end
    end
end

local stepAcc = 0
local function stepReal(dt, t)
    stepAntiFling()
    -- footsteps
    if State.steps and Real.root and Real.root.Parent then
        stepAcc += dt
        local v = Real.root.AssemblyLinearVelocity
        if stepAcc > 0.16 and Vector3.new(v.X, 0, v.Z).Magnitude > 3 then
            stepAcc = 0
            local pos = Real.root.Position - Vector3.new(0, Real.feet - 0.05, 0)
            local p = new("Part", {
                Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 1.4, 1.4), Material = Enum.Material.Neon,
                Color = State.stepsRainbow and hue(t, 0) or State.stepsColor, Transparency = 0.15, Anchored = true,
                CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
                CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Parent = fxFolder,
            })
            tween(p, 1.2, { Transparency = 1, Size = Vector3.new(0.05, 0.3, 0.3) })
            Debris:AddItem(p, 1.3)
        end
    end
    -- held item glow
    local tool = Real.model and Real.model:FindFirstChildOfClass("Tool")
    if State.toolGlow and tool then
        if not toolHL then
            toolHL = new("Highlight", {
                FillTransparency = 0.6, OutlineTransparency = 0, OutlineColor = WHITE,
                DepthMode = Enum.HighlightDepthMode.Occluded, Parent = fxFolder,
            })
        end
        toolHL.Adornee = tool
        toolHL.FillColor = State.glowColor
    elseif toolHL then
        toolHL:Destroy()
        toolHL = nil
    end
end

---------------------------------------------------------------- HUD
-- crosshair
HUD.crossUI = new("Frame", {
    Name = "Cross", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, Visible = false, Parent = hud,
})
HUD.crossRing = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = HUD.crossUI })
corner(HUD.crossRing, 999)
HUD.crossStroke = new("UIStroke", { Thickness = 2, Color = WHITE, Parent = HUD.crossRing })
HUD.crossGrad = new("UIGradient", {
    Transparency = NumberSequence.new({ NSK(0, 0), NSK(0.5, 0.9), NSK(1, 0) }), Parent = HUD.crossStroke,
})
HUD.crossDot = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4),
    BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = HUD.crossUI,
})
corner(HUD.crossDot, 3)
HUD.crossBars = {}
for i = 1, 4 do
    HUD.crossBars[i] = new("Frame", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Visible = false, Parent = HUD.crossUI })
end

-- custom cursor
HUD.cursorDot = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE,
    BackgroundTransparency = 0.35, Visible = false, ZIndex = 30, Parent = hud,
})
corner(HUD.cursorDot, 999)
HUD.cursorStroke = stroke(HUD.cursorDot, WHITE, 0.2, 2)
HUD.cursorHidden = false
function HUD.updateCursorState(v)
    if not v and HUD.cursorHidden then UIS.MouseIconEnabled = true HUD.cursorHidden = false end
end

-- vignette + cinematic bars
HUD.vig = {}
function HUD.vigFrame(anchor, pos, size, rot)
    local f = new("Frame", {
        AnchorPoint = anchor, Position = pos, Size = size, BackgroundColor3 = BLACK, BorderSizePixel = 0,
        Visible = false, Parent = hud,
    })
    table.insert(HUD.vig, { frame = f, grad = new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new(0.4, 1), Parent = f }) })
end
HUD.vigFrame(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.32), 90)
HUD.vigFrame(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.32), 270)
HUD.vigFrame(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1), 0)
HUD.vigFrame(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.22, 1), 180)
function HUD.updateVignette()
    for _, v in ipairs(HUD.vig) do v.grad.Transparency = NumberSequence.new(1 - State.vigStrength, 1) end
end
HUD.updateVignette()
HUD.barTop = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = hud })
HUD.barBot = new("Frame", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = hud,
})

-- motion graph
HUD.GRAPH_N = 40
HUD.graphUI = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(200, 60),
    BackgroundColor3 = Color3.fromRGB(8, 8, 10), BackgroundTransparency = 0.25, Visible = false, Parent = hud,
})
corner(HUD.graphUI, 8)
stroke(HUD.graphUI, WHITE, 0.9)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(100, 12), Text = "velocity",
    Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = HUD.graphUI,
})
HUD.graphLines, HUD.speeds = {}, {}
for i = 1, HUD.GRAPH_N do
    HUD.speeds[i] = 0
    HUD.graphLines[i] = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromOffset(6, 2), Parent = HUD.graphUI,
    })
end
function HUD.drawGraph()
    for i = 1, HUD.GRAPH_N - 1 do
        local x1, x2 = 6 + (i - 1) * 188 / (HUD.GRAPH_N - 1), 6 + i * 188 / (HUD.GRAPH_N - 1)
        local y1, y2 = 54 - math.clamp(HUD.speeds[i] / 40, 0, 1) * 38, 54 - math.clamp(HUD.speeds[i + 1] / 40, 0, 1) * 38
        local dx, dy = x2 - x1, y2 - y1
        local seg = HUD.graphLines[i]
        seg.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, 2)
        seg.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
        seg.Rotation = math.deg(math.atan2(dy, dx))
    end
    HUD.graphLines[HUD.GRAPH_N].Visible = false
end

-- watermark
HUD.wmHolder = new("Frame", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 52), Size = UDim2.fromOffset(0, 28),
    AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ClipsDescendants = false, ZIndex = 40, Parent = hud,
})
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = HUD.wmHolder,
})
local function watermarkIcon(parent, name, color)
    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), Parent = parent })
    if name == "wifi" then
        for i, w in ipairs({ 14, 10, 6 }) do
            local arc = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, w), Position = UDim2.fromOffset((16 - w) / 2, 0), Parent = holder })
            corner(arc, 999)
            stroke(arc, color, 0.05, 1.5)
            new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 10, 12), BorderSizePixel = 0, Size = UDim2.fromOffset(w + 2, w / 2 + 2), Position = UDim2.fromOffset((16 - w) / 2 - 1, -1), Parent = arc })
        end
        new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromOffset(3, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.82), Parent = holder })
    elseif name == "clock" then
        local face = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(13, 13), Position = UDim2.fromOffset(1.5, 1.5), Parent = holder })
        corner(face, 999)
        stroke(face, color, 0.05, 1.4)
        new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromOffset(1.4, 4.4), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.52), Parent = face })
        new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromOffset(4, 1.4), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.55), Parent = face })
    else
        local ic = icon(holder, name, 16, color)
        ic.Position = UDim2.fromScale(0, 0)
    end
    return holder
end

function HUD.pill(order, iconName, text)
    local f = new("Frame", {
        Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(10, 10, 12),
        BackgroundTransparency = 0.15, LayoutOrder = order, Parent = HUD.wmHolder,
    })
    corner(f, 6)
    stroke(f, WHITE, 0.9)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 9), Parent = f })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f,
    })
    local ic = watermarkIcon(f, iconName, WHITE)
    ic.LayoutOrder = 1
    ic.ZIndex = 1001
    local lbl = new("TextLabel", {
        Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE, Text = text, LayoutOrder = 2, Parent = f,
    })
    lbl.ZIndex = 1001
    return f, lbl
end
HUD.wmNamePill = HUD.pill(1, "code", "Hiruku")
HUD.wmNamePill.ZIndex = 41
HUD.wmNamePill.Active = false
for _, d in ipairs(HUD.wmNamePill:GetDescendants()) do
    if d:IsA("GuiObject") then d.ZIndex = 41 end
end
HUD.wmUserPill, HUD.wmUserLbl = HUD.pill(2, "user", LP.DisplayName)
HUD.wmFpsPill, HUD.wmFpsLbl = HUD.pill(3, "activity", "60 fps")
HUD.wmPingPill, HUD.wmPingLbl = HUD.pill(4, "wifi", "0 ms")
HUD.wmTimePill, HUD.wmTimeLbl = HUD.pill(5, "clock", "00:00")

-- music widget
HUD.snd = new("Sound", { Name = "HirukuMusic", Volume = State.musicVol, Looped = State.musicLoop, Parent = SoundService })
HUD.musicTitle = "Nothing playing"
HUD.musicPanel = new("Frame", {
    Position = UDim2.fromScale(State.hudMusicX, State.hudMusicY), Size = UDim2.fromOffset(236, 66), BackgroundColor3 = Color3.fromRGB(8, 8, 10),
    BackgroundTransparency = 0.15, Visible = false, Parent = hud,
})
corner(HUD.musicPanel, 8)
stroke(HUD.musicPanel, WHITE, 0.9)
HUD.cover = new("Frame", {
    Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, Parent = HUD.musicPanel,
})
corner(HUD.cover, 6)
HUD.coverIcon = icon(HUD.cover, "music", 22, WHITE)
HUD.coverIcon.AnchorPoint, HUD.coverIcon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
HUD.musicLbl = new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(66, 10), Size = UDim2.new(1, -110, 0, 16), Text = HUD.musicTitle,
    Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, Parent = HUD.musicPanel,
})
HUD.musicTime = new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(66, 28), Size = UDim2.fromOffset(100, 12), Text = "0:00 / 0:00",
    Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = HUD.musicPanel,
})
HUD.musicBar = new("Frame", {
    Position = UDim2.fromOffset(66, 48), Size = UDim2.new(1, -78, 0, 4), BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, Parent = HUD.musicPanel,
})
corner(HUD.musicBar, 2)
HUD.musicFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = HUD.musicBar })
corner(HUD.musicFill, 2)
HUD.musicPlay = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(28, 28),
    BackgroundTransparency = 1, Text = "", Parent = HUD.musicPanel,
})
HUD.musicPlayIcon = icon(HUD.musicPlay, "play", 16, WHITE)
HUD.musicPlayIcon.AnchorPoint, HUD.musicPlayIcon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)

HUD.targetInfo = new("CanvasGroup", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(State.hudTargetX, State.hudTargetY), Size = UDim2.fromOffset(238, 72),
    BackgroundColor3 = Color3.fromRGB(8, 8, 10), BackgroundTransparency = 0.12, GroupTransparency = 1, Visible = false, Parent = hud,
})
corner(HUD.targetInfo, 10)
stroke(HUD.targetInfo, WHITE, 0.88)
HUD.targetAvatar = new("ImageLabel", { Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, ImageTransparency = 0, ImageColor3 = WHITE, ScaleType = Enum.ScaleType.Crop, Parent = HUD.targetInfo })
corner(HUD.targetAvatar, 9)
HUD.targetName = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(74, 10), Size = UDim2.new(1, -86, 0, 20), Text = "Player", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = HUD.targetInfo })
HUD.targetLine = new("Frame", { Position = UDim2.fromOffset(74, 38), Size = UDim2.new(1, -88, 0, 5), BackgroundColor3 = WHITE, BackgroundTransparency = 0.86, BorderSizePixel = 0, Parent = HUD.targetInfo })
corner(HUD.targetLine, 3)
HUD.targetFill = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.ice, BorderSizePixel = 0, Parent = HUD.targetLine })
corner(HUD.targetFill, 3)
HUD.targetMeta = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(74, 49), Size = UDim2.new(1, -86, 0, 14), Text = "20 HP  ·  0 studs", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = HUD.targetInfo })
HUD.targetShown = false
HUD.targetPlayer = nil
HUD.targetTween = nil
HUD.targetThumb = ""

function HUD.setTargetInfo(plr, show)
    if show and plr and plr.Character then
        if HUD.targetPlayer ~= plr then
            HUD.targetPlayer = plr
            HUD.targetThumb = ""
            HUD.targetAvatar.Image = ""
            HUD.targetAvatar.ImageTransparency = 0
            local uid = tostring(plr.UserId)
            local fallback = "rbxthumb://type=AvatarHeadShot&id=" .. uid .. "&w=150&h=150"
            HUD.targetAvatar.Image = fallback
            task.spawn(function()
                local sources = {
                    {Enum.ThumbnailType.AvatarHeadShot, Enum.ThumbnailSize.Size150x150},
                    {Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150},
                    {Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size150x150},
                }
                for _, spec in ipairs(sources) do
                    if HUD.targetPlayer ~= plr or not HUD.targetAvatar.Parent then return end
                    local ok, img, ready = pcall(function()
                        return Players:GetUserThumbnailAsync(plr.UserId, spec[1], spec[2])
                    end)
                    if ok and img and img ~= "" then
                        HUD.targetThumb = img
                        HUD.targetAvatar.Image = img
                        HUD.targetAvatar.ImageTransparency = 0
                        pcall(function() ContentProvider:PreloadAsync({HUD.targetAvatar}) end)
                        if ready then return end
                    end
                    task.wait(0.08)
                end
            end)
        end
        if not HUD.targetShown then
            HUD.targetShown = true
            HUD.targetInfo.Visible = true
            HUD.targetInfo.Position = UDim2.fromScale(State.hudTargetX, State.hudTargetY + 0.025)
            tween(HUD.targetInfo, 0.2, { GroupTransparency = 0, Position = UDim2.fromScale(State.hudTargetX, State.hudTargetY) }, Enum.EasingStyle.Quart)
        end
    elseif HUD.targetShown then
        HUD.targetShown = false
        tween(HUD.targetInfo, 0.18, { GroupTransparency = 1, Position = UDim2.fromScale(State.hudTargetX, State.hudTargetY + 0.02) }, Enum.EasingStyle.Quad)
        task.delay(0.2, function() if not HUD.targetShown and HUD.targetInfo.Parent then HUD.targetInfo.Visible = false end end)
    end
end

function HUD.makeDraggable(panel, keyX, keyY)
    local dragging = false
    local start, baseX, baseY
    bind(panel.InputBegan, function(input)
        if not State.hudEdit then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            start = input.Position
            baseX, baseY = State[keyX], State[keyY]
        end
    end)
    bind(UIS.InputChanged, function(input)
        if not dragging or not State.hudEdit then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local v = cam().ViewportSize
            local dx = (input.Position.X - start.X) / math.max(v.X, 1)
            local dy = (input.Position.Y - start.Y) / math.max(v.Y, 1)
            State[keyX], State[keyY] = math.clamp(baseX + dx, 0.08, 0.92), math.clamp(baseY + dy, 0.08, 0.92)
            panel.Position = UDim2.fromScale(State[keyX], State[keyY])
        end
    end)
    bind(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

HUD.makeDraggable(HUD.musicPanel, "hudMusicX", "hudMusicY")
HUD.makeDraggable(HUD.targetInfo, "hudTargetX", "hudTargetY")

function HUD.mmss(s) s = math.max(0, math.floor(s)) return string.format("%d:%02d", s // 60, s % 60) end
function HUD.playMusic(id)
    id = tostring(id or ""):gsub("%D", "")
    if id == "" then notify("Music", "Enter a Sound ID first") return end
    HUD.snd:Stop()
    HUD.snd.SoundId = "rbxassetid://" .. id
    HUD.snd.Volume, HUD.snd.Looped = State.musicVol, State.musicLoop
    HUD.snd:Play()
    HUD.musicTitle = "Loading..."
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(tonumber(id)) end)
        HUD.musicTitle = (ok and info and info.Name) or ("Sound " .. id)
    end)
end
function HUD.toggleMusic()
    if HUD.snd.SoundId == "" then HUD.playMusic(State.musicId) return end
    if HUD.snd.IsPlaying then HUD.snd:Pause() else HUD.snd:Resume() end
end
bind(HUD.musicPlay.MouseButton1Click, HUD.toggleMusic)

-- per-frame HUD
HUD.hudAcc, HUD.frames, HUD.graphAcc = 0, 0, 0
function HUD.stepHUD(dt, t)
    -- crosshair
    HUD.crossUI.Visible = State.cross
    if State.cross then
        local s, col, st = State.crossSize, State.crossColor, State.crossStyle
        HUD.crossUI.Size = UDim2.fromOffset(s, s)
        HUD.crossRing.Visible = (st == "Ring" or st == "Spin")
        HUD.crossStroke.Color = col
        HUD.crossGrad.Rotation = st == "Spin" and (t * 140) % 360 or 0
        HUD.crossDot.BackgroundColor3 = col
        local ds = st == "Dot" and 7 or 4
        HUD.crossDot.Size = UDim2.fromOffset(ds, ds)
        local isCross = st == "Cross"
        local len, gap = math.max(4, s * 0.3), State.crossGap
        for _, b in ipairs(HUD.crossBars) do b.Visible = isCross b.BackgroundColor3 = col end
        HUD.crossBars[1].AnchorPoint, HUD.crossBars[1].Position, HUD.crossBars[1].Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 0.5, -gap), UDim2.fromOffset(2, len)
        HUD.crossBars[2].AnchorPoint, HUD.crossBars[2].Position, HUD.crossBars[2].Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.5, gap), UDim2.fromOffset(2, len)
        HUD.crossBars[3].AnchorPoint, HUD.crossBars[3].Position, HUD.crossBars[3].Size = Vector2.new(1, 0.5), UDim2.new(0.5, -gap, 0.5, 0), UDim2.fromOffset(len, 2)
        HUD.crossBars[4].AnchorPoint, HUD.crossBars[4].Position, HUD.crossBars[4].Size = Vector2.new(0, 0.5), UDim2.new(0.5, gap, 0.5, 0), UDim2.fromOffset(len, 2)
    end
    -- cursor
    local touch = UIS.TouchEnabled and not UIS.MouseEnabled
    HUD.cursorDot.Visible = State.cursor and not touch
    if State.cursor and not touch then
        local m = UIS:GetMouseLocation()
        HUD.cursorDot.Position = UDim2.fromOffset(m.X, m.Y)
        HUD.cursorDot.Size = UDim2.fromOffset(State.cursorSize, State.cursorSize)
        HUD.cursorDot.BackgroundColor3, HUD.cursorStroke.Color = State.cursorColor, State.cursorColor
        UIS.MouseIconEnabled = false
        HUD.cursorHidden = true
    end
    -- vignette / bars
    for _, v in ipairs(HUD.vig) do v.frame.Visible = State.vignette end
    local h = State.bars and State.barsSize or 0
    if HUD.barsShown ~= h then
        HUD.barsShown = h
        tween(HUD.barTop, 0.35, { Size = UDim2.new(1, 0, h, 0) })
        tween(HUD.barBot, 0.35, { Size = UDim2.new(1, 0, h, 0) })
    end
    -- graph
    HUD.graphUI.Visible = State.graph
    if State.graph then
        HUD.graphAcc += dt
        if HUD.graphAcc >= 0.05 then
            HUD.graphAcc = 0
            local r = Real.root
            local v = r and r.Parent and r.AssemblyLinearVelocity or Vector3.zero
            table.remove(HUD.speeds, 1)
            table.insert(HUD.speeds, Vector3.new(v.X, 0, v.Z).Magnitude)
            HUD.drawGraph()
        end
    end
    -- watermark text
    HUD.frames += 1
    HUD.hudAcc += dt
    if HUD.hudAcc >= 0.5 then
        local fps = math.floor(HUD.frames / HUD.hudAcc + 0.5)
        HUD.frames, HUD.hudAcc = 0, 0
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        HUD.wmFpsLbl.Text, HUD.wmPingLbl.Text, HUD.wmTimeLbl.Text = fps .. " fps", ping .. " ms", os.date("%H:%M")
        HUD.wmHolder.Visible = State.watermark
        HUD.wmNamePill.Visible, HUD.wmUserPill.Visible, HUD.wmFpsPill.Visible = State.wmName, State.wmUser, State.wmFps
        HUD.wmPingPill.Visible, HUD.wmTimePill.Visible = State.wmPing, State.wmTime
    end
    HUD.musicPanel.Visible = State.music or State.hudEdit
    HUD.musicPanel.Position = UDim2.fromScale(State.hudMusicX, State.hudMusicY)
    HUD.musicPanel.AnchorPoint = Vector2.new(0.5, 0.5)
    HUD.musicPanel.BackgroundTransparency = State.hudEdit and 0.04 or 0.15
    local target = getCrosshairTarget()
    if State.hudEdit then
        HUD.setTargetInfo(target or LP, true)
        HUD.targetInfo.BackgroundTransparency = 0.04
        HUD.targetInfo.Position = UDim2.fromScale(State.hudTargetX, State.hudTargetY)
    else
        HUD.targetInfo.BackgroundTransparency = 0.12
        HUD.setTargetInfo(target, State.playerInfo and target ~= nil)
    end
    if target and target.Character then
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        local root = target.Character:FindFirstChild("HumanoidRootPart")
        if hum and root then
            local hp = math.max(0, hum.Health)
            local maxHp = math.max(1, hum.MaxHealth)
            HUD.targetName.Text = target.DisplayName
            HUD.targetMeta.Text = string.format("%.0f / %.0f HP  ·  %.0f studs", hp, maxHp, (root.Position - (Real.root and Real.root.Position or cam().CFrame.Position)).Magnitude)
            HUD.targetFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
            HUD.targetFill.BackgroundColor3 = Color3.fromRGB(255 - math.floor(155 * math.clamp(hp / maxHp, 0, 1)), 80 + math.floor(150 * math.clamp(hp / maxHp, 0, 1)), 90)
        end
    end
    if State.music then
        HUD.musicLbl.Text = HUD.musicTitle
        local len = HUD.snd.TimeLength
        HUD.musicTime.Text = HUD.mmss(HUD.snd.TimePosition) .. " / " .. HUD.mmss(len)
        HUD.musicFill.Size = UDim2.fromScale(len > 0 and math.clamp(HUD.snd.TimePosition / len, 0, 1) or 0, 1)
        local g = HUD.musicPlayIcon:FindFirstChild("Glyph")
        if g then g.Text = HUD.snd.IsPlaying and "❚❚" or "▶" end
        local name = HUD.snd.IsPlaying and "pause" or "play"
        if iconTargets[HUD.musicPlayIcon] ~= name then
            iconTargets[HUD.musicPlayIcon] = name
            applyIcon(HUD.musicPlayIcon, name)
        end
    end
end

---------------------------------------------------------------- window
-- Android/iOS (touch, no physical keyboard) get a tall single-column layout;
-- desktop keeps the original side-by-side panel.
WIN.mobile = false
WIN.dimFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, Visible = false, ZIndex = 1, Parent = gui })
WIN.PANEL = Color3.fromRGB(8, 8, 10)

if WIN.mobile then
    WIN.WIN_W, WIN.WIN_H = 380, 660
    WIN.win = new("CanvasGroup", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WIN.WIN_W, WIN.WIN_H), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 2, Parent = gui,
    })
    WIN.mScale = new("UIScale", { Parent = WIN.win })

    -- skin preview strip (top, full width)
    local PV_H = 208
    WIN.pvPanel = new("Frame", {
        Size = UDim2.new(1, 0, 0, PV_H), BackgroundColor3 = WIN.PANEL, BackgroundTransparency = State.menuTransp, BorderSizePixel = 0, Parent = WIN.win,
    })
    corner(WIN.pvPanel, 10)
    stroke(WIN.pvPanel, WHITE, 0.9)
    WIN.avatar = new("ImageLabel", {
        Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Parent = WIN.pvPanel,
    })
    corner(WIN.avatar, 14)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 10), Size = UDim2.new(1, -64, 0, 14), Text = "PREVIEW",
        Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.pvPanel,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 24), Size = UDim2.new(1, -64, 0, 16), Text = LP.DisplayName,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = WIN.pvPanel,
    })
    WIN.viewport = new("ViewportFrame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 48), Size = UDim2.fromOffset(160, 130), BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(185, 185, 195), LightColor = WHITE, LightDirection = Vector3.new(-0.4, -0.7, -0.6), Parent = WIN.pvPanel,
    })
    WIN.pvCam = new("Camera", { FieldOfView = 50, CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -13), Vector3.zero), Parent = WIN.viewport })
    WIN.viewport.CurrentCamera = WIN.pvCam
    Prev.holder = new("Folder", { Name = "PreviewFX", Parent = WIN.viewport })
    WIN.pvTags = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -8), Size = UDim2.new(1, -28, 0, 26),
        Text = "No effects active", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = GRAY, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Bottom, Parent = WIN.pvPanel,
    })
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
        if ok and img and WIN.avatar.Parent then WIN.avatar.Image = img end
    end)

    -- main panel (below), full width
    WIN.mainP = new("Frame", {
        Position = UDim2.fromOffset(0, PV_H + 8), Size = UDim2.new(1, 0, 1, -(PV_H + 8)), BackgroundColor3 = WIN.PANEL,
        BackgroundTransparency = State.menuTransp, BorderSizePixel = 0, Parent = WIN.win,
    })
    corner(WIN.mainP, 10)
    stroke(WIN.mainP, WHITE, 0.9)

    -- nav: horizontal scrolling icon row
    WIN.nav = new("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 40), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X, Parent = WIN.mainP,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = WIN.nav,
    })
    new("Frame", { Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = WIN.mainP })

    -- top bar: save + config on row 1, search on row 2
    WIN.topbar = new("Frame", { Position = UDim2.fromOffset(8, 60), Size = UDim2.new(1, -16, 0, 80), BackgroundTransparency = 1, Parent = WIN.mainP })
    WIN.saveBtn = new("TextButton", {
        Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94,
        Text = "", AutoButtonColor = false, Parent = WIN.topbar,
    })
    corner(WIN.saveBtn, 8)
    WIN.saveIc = icon(WIN.saveBtn, "save", 16, WHITE)
    WIN.saveIc.AnchorPoint, WIN.saveIc.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
    WIN.cfgPill = new("Frame", {
        Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -44, 0, 36), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, Parent = WIN.topbar,
    })
    corner(WIN.cfgPill, 8)
    WIN.cfgBox = new("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = State.configName,
        PlaceholderText = "config", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = WHITE, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.cfgPill,
    })
    WIN.searchPill = new("Frame", {
        Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, Parent = WIN.topbar,
    })
    corner(WIN.searchPill, 8)
    WIN.searchIc = icon(WIN.searchPill, "search", 15, GRAY)
    WIN.searchIc.Position = UDim2.new(0, 12, 0.5, -7)
    WIN.search = new("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -46, 1, 0), Text = "", PlaceholderText = "Search",
        PlaceholderColor3 = GRAY, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = WHITE, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.searchPill,
    })

    WIN.content = new("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 148), Size = UDim2.new(1, -16, 1, -156), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.6,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = WIN.mainP,
    })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = WIN.content })
    new("UIPadding", { PaddingBottom = UDim.new(0, 8), Parent = WIN.content })
    WIN.contentPos = WIN.content.Position
else
    WIN.WIN_W, WIN.WIN_H = 900, 420
    WIN.win = new("CanvasGroup", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WIN.WIN_W, WIN.WIN_H), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 2, Parent = gui,
    })
    WIN.mScale = new("UIScale", { Parent = WIN.win })
    WIN.mScale.Scale = math.clamp(math.min(workspace.CurrentCamera.ViewportSize.X / 920, workspace.CurrentCamera.ViewportSize.Y / 440), 0.62, 1)

    -- skin preview panel (left)
    WIN.pvPanel = new("Frame", {
        Size = UDim2.fromOffset(184, WIN.WIN_H), BackgroundColor3 = WIN.PANEL, BackgroundTransparency = State.menuTransp, BorderSizePixel = 0, Parent = WIN.win,
    })
    corner(WIN.pvPanel, 10)
    stroke(WIN.pvPanel, WHITE, 0.9)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 14), Text = "PREVIEW",
        Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.pvPanel,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -28, 0, 18), Text = LP.DisplayName,
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = WIN.pvPanel,
    })
    WIN.viewport = new("ViewportFrame", {
        Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -104), BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(185, 185, 195), LightColor = WHITE, LightDirection = Vector3.new(-0.4, -0.7, -0.6), Parent = WIN.pvPanel,
    })
    WIN.pvCam = new("Camera", { FieldOfView = 50, CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -13), Vector3.zero), Parent = WIN.viewport })
    WIN.viewport.CurrentCamera = WIN.pvCam
    Prev.holder = new("Folder", { Name = "PreviewFX", Parent = WIN.viewport })
    WIN.pvTags = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -10), Size = UDim2.new(1, -28, 0, 40),
        Text = "No effects active", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = GRAY, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, Parent = WIN.pvPanel,
    })

    -- main panel (right)
    WIN.mainP = new("Frame", {
        Position = UDim2.fromOffset(192, 0), Size = UDim2.fromOffset(WIN.WIN_W - 192, WIN.WIN_H), BackgroundColor3 = WIN.PANEL,
        BackgroundTransparency = State.menuTransp, BorderSizePixel = 0, Parent = WIN.win,
    })
    corner(WIN.mainP, 10)
    stroke(WIN.mainP, WHITE, 0.9)
    new("Frame", { Position = UDim2.fromOffset(168, 12), Size = UDim2.fromOffset(1, WIN.WIN_H - 24), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = WIN.mainP })

    -- brand
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(140, 24), Text = "Hiruku",
        Font = Enum.Font.GothamBlack, TextSize = 21, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.mainP,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 38), Size = UDim2.fromOffset(140, 14), Text = "visual suite · mm2",
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.mainP,
    })
    new("Frame", { Position = UDim2.fromOffset(14, 62), Size = UDim2.fromOffset(140, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = WIN.mainP })

    WIN.nav = new("Frame", { Position = UDim2.fromOffset(10, 72), Size = UDim2.fromOffset(148, 260), BackgroundTransparency = 1, Parent = WIN.mainP })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = WIN.nav })

    -- footer (avatar + name)
    new("Frame", { Position = UDim2.fromOffset(14, WIN.WIN_H - 60), Size = UDim2.fromOffset(140, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = WIN.mainP })
    WIN.avatar = new("ImageLabel", {
        Position = UDim2.fromOffset(16, WIN.WIN_H - 48), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Parent = WIN.mainP,
    })
    corner(WIN.avatar, 16)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(56, WIN.WIN_H - 47), Size = UDim2.fromOffset(102, 16), Text = LP.DisplayName,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = WIN.mainP,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(56, WIN.WIN_H - 31), Size = UDim2.fromOffset(102, 14), Text = "Hiruku",
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.mainP,
    })
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
        if ok and img and WIN.avatar.Parent then WIN.avatar.Image = img end
    end)

    -- top bar (drag handle): save button · config name · search
    WIN.topbar = new("Frame", { Position = UDim2.fromOffset(169, 0), Size = UDim2.fromOffset(WIN.WIN_W - 192 - 169, 52), BackgroundTransparency = 1, Parent = WIN.mainP })
    WIN.saveBtn = new("TextButton", {
        Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(34, 32), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94,
        Text = "", AutoButtonColor = false, Parent = WIN.topbar,
    })
    corner(WIN.saveBtn, 6)
    WIN.saveIc = icon(WIN.saveBtn, "save", 16, WHITE)
    WIN.saveIc.AnchorPoint, WIN.saveIc.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
    WIN.cfgPill = new("Frame", {
        Position = UDim2.fromOffset(52, 10), Size = UDim2.fromOffset(112, 32), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, Parent = WIN.topbar,
    })
    corner(WIN.cfgPill, 6)
    WIN.cfgBox = new("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = State.configName,
        PlaceholderText = "config", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.cfgPill,
    })
    WIN.searchPill = new("Frame", {
        Position = UDim2.fromOffset(174, 10), Size = UDim2.new(1, -186, 0, 32), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, Parent = WIN.topbar,
    })
    corner(WIN.searchPill, 6)
    WIN.searchIc = icon(WIN.searchPill, "search", 15, GRAY)
    WIN.searchIc.Position = UDim2.new(0, 12, 0.5, -7)
    WIN.search = new("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -46, 1, 0), Text = "", PlaceholderText = "Search",
        PlaceholderColor3 = GRAY, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = WHITE, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = WIN.searchPill,
    })

    WIN.content = new("ScrollingFrame", {
        Position = UDim2.fromOffset(178, 56), Size = UDim2.fromOffset(WIN.WIN_W - 192 - 178 - 8, WIN.WIN_H - 64), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.6,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = WIN.mainP,
    })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = WIN.content })
    new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = WIN.content })
    WIN.contentPos = WIN.content.Position
end

WIN.searchOpen = false
WIN.searchBasePosition = UDim2.new(1, -8, WIN.searchPill.Position.Y.Scale, WIN.searchPill.Position.Y.Offset)
WIN.searchBaseSize = WIN.searchPill.Size
WIN.searchPill.AnchorPoint = Vector2.new(1, 0)
WIN.searchPill.ClipsDescendants = true
WIN.searchPill.Position = WIN.searchBasePosition
WIN.searchPill.Size = UDim2.fromOffset(34, WIN.searchBaseSize.Y.Offset)
WIN.search.TextTransparency = 1
WIN.searchIc.AnchorPoint = Vector2.new(0.5, 0.5)
WIN.searchIc.Position = UDim2.fromScale(0.5, 0.5)
WIN.searchHit = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false, Parent = WIN.searchPill })
local searchZ = WIN.searchPill.ZIndex
WIN.searchHit.ZIndex = searchZ + 2
WIN.searchIc.ZIndex = searchZ + 3
WIN.search.ZIndex = searchZ + 4
function WIN.setSearch(open)
    WIN.searchOpen = open
    local targetPos = open and WIN.searchBasePosition or UDim2.new(1, -8, WIN.searchBasePosition.Y.Scale, WIN.searchBasePosition.Y.Offset)
    local targetSize = open and WIN.searchBaseSize or UDim2.fromOffset(34, WIN.searchBaseSize.Y.Offset)
    tween(WIN.searchPill, 0.24, { Position = targetPos, Size = targetSize }, Enum.EasingStyle.Quart)
    tween(WIN.searchIc, 0.2, { Position = open and UDim2.new(0, 12, 0.5, -7) or UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quad)
    tween(WIN.search, 0.18, { TextTransparency = open and 0 or 1 }, Enum.EasingStyle.Quad)
    if open then
        task.delay(0.2, function() if WIN.searchOpen and WIN.search.Parent then WIN.search:CaptureFocus() end end)
    end
end
WIN.searchHit.MouseButton1Click:Connect(function() WIN.setSearch(not WIN.searchOpen) end)
WIN.searchIc.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then WIN.setSearch(not WIN.searchOpen) end end)
WIN.search.FocusLost:Connect(function()
    if WIN.search.Text == "" then WIN.setSearch(false) end
end)

---------------------------------------------------------------- row builders
bind(UIS.InputChanged, function(i)
    if WIN.activeSlider and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        WIN.activeSlider(i.Position.X)
    end
end)
bind(UIS.InputEnded, function(i)
    if WIN.activeSlider and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
        WIN.activeSlider = nil
        WIN.content.ScrollingEnabled = true
    end
end)

local Builders = {}
function WIN.buildRow(f, parent, order, compact) return Builders[f.kind](f, parent, order, compact) end

function WIN.newRow(parent, order)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
    return row
end
function WIN.rowLabel(head, text, compact)
    return new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(compact and 26 or 14, 0), Size = UDim2.new(0.55, 0, 0, compact and 34 or 40),
        Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = compact and Color3.fromRGB(190, 190, 198) or Color3.fromRGB(230, 230, 236),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
    })
end
function WIN.optsFrame(row, list)
    local wrap = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true,
        Visible = false, LayoutOrder = 2, Parent = row,
    })
    local o = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = BLACK, BackgroundTransparency = 0.55,
        Position = UDim2.fromOffset(0, 8), Parent = wrap,
    })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = o })
    for i, sf in ipairs(list) do WIN.buildRow(sf, o, i, true) end
    o.Name = "Content"
    task.defer(function()
        if o.Parent then
            wrap:SetAttribute("TargetHeight", o.AbsoluteSize.Y + 8)
        end
    end)
    return wrap
end

Builders.toggle = function(f, parent, order, compact)
    local row = WIN.newRow(parent, order)
    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, compact and 34 or 40), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1, Parent = row,
    })
    WIN.rowLabel(head, f.name, compact)
    local val = State[f.key]
    local track = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(34, 18),
        BackgroundColor3 = val and State.accentColor or OFF, Parent = head,
    })
    corner(track, 9)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = val and BLACK or GRAY,
        Position = val and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), Parent = track,
    })
    corner(knob, 6)
    if f.opts then
        local o = WIN.optsFrame(row, f.opts)
        local gear = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -58, 0.5, 0), Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1, Text = "", Parent = head,
        })
        local gi = icon(gear, "settings", 16, GRAY)
        gi.AnchorPoint, gi.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
        gear.MouseButton1Click:Connect(function()
            local opening = not o.Visible
            local inner = o:FindFirstChild("Content")
            local targetH = o:GetAttribute("TargetHeight") or (inner and (inner.AbsoluteSize.Y + 8) or 40)
            o.Visible = opening
            tween(gi, 0.28, { Rotation = opening and -24 or 0 }, Enum.EasingStyle.Quad)
            tintIcon(gi, opening and State.accentColor or GRAY)
            if opening then
                o.Size = UDim2.new(1, 0, 0, 0)
                o.Position = UDim2.fromOffset(0, 0)
                tween(o, 0.26, { Size = UDim2.new(1, 0, 0, targetH) }, Enum.EasingStyle.Quart)
                inner.Position = UDim2.fromOffset(0, 8)
                tween(inner, 0.28, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
            else
                tween(o, 0.2, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quart)
                tween(inner, 0.18, { Position = UDim2.fromOffset(0, -6) }, Enum.EasingStyle.Quad)
                task.delay(0.2, function()
                    if not o.Visible then return end
                    o.Visible = false
                end)
            end
        end)
    end
    head.MouseButton1Click:Connect(function()
        val = not val
        State[f.key] = val
        tween(track, 0.15, { BackgroundColor3 = val and State.accentColor or OFF })
        tween(knob, 0.15, { Position = val and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = val and BLACK or GRAY })
        if f.on then f.on(val) end
        notify(f.name, val and "Enabled" or "Disabled")
    end)
    return row
end

Builders.slider = function(f, parent, order, compact)
    local row = WIN.newRow(parent, order)
    local H = compact and 40 or 46
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, H), BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(compact and 26 or 14, 2), Size = UDim2.new(0.6, 0, 0, 22), Text = f.name,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = compact and Color3.fromRGB(190, 190, 198) or Color3.fromRGB(230, 230, 236),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
    })
    local cur = State[f.key]
    local frac0 = (cur - f.min) / (f.max - f.min)
    local valLbl = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 2), Size = UDim2.fromOffset(80, 22), Text = fmt(cur, f.step),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Right, Parent = head,
    })
    local bar = new("Frame", {
        Position = UDim2.new(0, compact and 26 or 14, 0, H - 14), Size = UDim2.new(1, (compact and 26 or 14) * -1 - 14, 0, 4),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = head,
    })
    corner(bar, 2)
    local fill = new("Frame", { Size = UDim2.fromScale(frac0, 1), BackgroundColor3 = State.accentColor, BorderSizePixel = 0, Parent = bar })
    corner(fill, 2)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(frac0, 0, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = WHITE, Parent = bar,
    })
    corner(knob, 6)
    local function setFromX(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.clamp(math.floor((f.min + (f.max - f.min) * a) / f.step + 0.5) * f.step, f.min, f.max)
        State[f.key] = v
        local frac = (v - f.min) / (f.max - f.min)
        fill.Size = UDim2.fromScale(frac, 1)
        knob.Position = UDim2.new(frac, 0, 0.5, 0)
        valLbl.Text = fmt(v, f.step)
        if f.on then f.on(v) end
    end
    local hit = new("TextButton", { Position = UDim2.fromOffset(0, H - 26), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "", Parent = head })
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            WIN.activeSlider = setFromX
            WIN.content.ScrollingEnabled = false
            setFromX(input.Position.X)
        end
    end)
    return row
end

Builders.dropdown = function(f, parent, order, compact)
    local row = WIN.newRow(parent, order)
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, compact and 34 or 40), BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
    WIN.rowLabel(head, f.name, compact)
    local btn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(136, 24), BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.92, Text = State[f.key], Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, Parent = head,
    })
    corner(btn, 6)
    new("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = btn })
    local chev = icon(btn, "chevron-down", 14, GRAY)
    chev.AnchorPoint, chev.Position = Vector2.new(1, 0.5), UDim2.new(1, -4, 0.5, 0)
    local list = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = BLACK, BackgroundTransparency = 0.55,
        Visible = false, LayoutOrder = 2, Parent = row,
    })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    local optBtns = {}
    for i, name in ipairs(f.values) do
        local ob = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = name, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = (State[f.key] == name) and State.accentColor or GRAY, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
            LayoutOrder = i, Parent = list,
        })
        new("UIPadding", { PaddingLeft = UDim.new(0, 26), Parent = ob })
        optBtns[name] = ob
        ob.MouseButton1Click:Connect(function()
            State[f.key] = name
            btn.Text = name
            list.Visible = false
            for n, b in pairs(optBtns) do b.TextColor3 = (n == name) and State.accentColor or GRAY end
            if f.on then f.on(name) end
        end)
    end
    btn.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
    return row
end

Builders.colors = function(f, parent, order, compact)
    local row = WIN.newRow(parent, order)
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, compact and 34 or 40), BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
    WIN.rowLabel(head, f.name, compact).Size = UDim2.new(0.3, 0, 0, compact and 34 or 40)
    local holder = new("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(200, 22), Parent = head,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder,
    })
    for i, c in ipairs(f.set or Swatches) do
        local b = new("TextButton", { Size = UDim2.fromOffset(18, 18), BackgroundColor3 = c, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = holder })
        corner(b, 4)
        stroke(b, WHITE, (State[f.key] == c) and 0 or 0.85, (State[f.key] == c) and 2 or 1)
        b.MouseButton1Click:Connect(function()
            State[f.key] = c
            if f.on then f.on(c) end
            render(true)
        end)
    end
    return row
end

Builders.button = function(f, parent, order, compact)
    local row = WIN.newRow(parent, order)
    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, compact and 34 or 40), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        LayoutOrder = 1, Parent = row,
    })
    local x = compact and 26 or 14
    if f.icon then
        local ic = icon(head, f.icon, 15, WHITE)
        ic.Position = UDim2.new(0, x, 0.5, -8)
        x += 26
    end
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 10, 1, 0), Text = f.name,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(230, 230, 236), TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
    })
    head.MouseEnter:Connect(function() tween(head, 0.1, { BackgroundTransparency = 0.95 }) end)
    head.MouseLeave:Connect(function() tween(head, 0.1, { BackgroundTransparency = 1 }) end)
    head.MouseButton1Click:Connect(function() if f.on then f.on() end end)
    return row
end

Builders.input = function(f, parent, order, compact)
    local row = WIN.newRow(parent, order)
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, compact and 34 or 40), BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
    WIN.rowLabel(head, f.name, compact)
    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 24), BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.92, Text = tostring(State[f.key]), PlaceholderText = f.placeholder or "", PlaceholderColor3 = GRAY,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
    })
    corner(box, 6)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = box })
    box.FocusLost:Connect(function()
        State[f.key] = box.Text
        if f.on then f.on(box.Text) end
    end)
    return row
end

Builders.label = function(f, parent, order)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Text = f.name,
        TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left,
        Parent = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent }),
    })
end

function WIN.buildGroup(parent, name, features, order)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order, Text = name, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = WHITE, BackgroundTransparency = 0.965,
        LayoutOrder = order + 1, Parent = parent,
    })
    corner(card, 8)
    stroke(card, WHITE, 0.92)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
    for i, f in ipairs(features) do
        if i > 1 then
            new("Frame", { Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, BorderSizePixel = 0, LayoutOrder = i * 2 - 1, Parent = card })
        end
        WIN.buildRow(f, card, i * 2, false)
    end
    -- spacer under the group
    new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = order + 2, Parent = parent })
end

---------------------------------------------------------------- config save / load
WIN.hasFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" and type(makefolder) == "function"
function WIN.cfgPath(name) return "Hiruku/" .. (tostring(name):gsub("[^%w_%-]", "_")) .. ".json" end
function WIN.encodeState()
    local out = {}
    for k, v in pairs(State) do
        local tv = typeof(v)
        if tv == "Color3" then out[k] = { __c = { v.R, v.G, v.B } }
        elseif tv == "number" or tv == "boolean" or tv == "string" then out[k] = v end
    end
    return HttpService:JSONEncode(out)
end
function WIN.decodeInto(json)
    local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
    if not ok or type(data) ~= "table" then return false end
    for k, v in pairs(data) do
        local d = Defaults[k]
        if d ~= nil then
            if typeof(d) == "Color3" then
                if type(v) == "table" and type(v.__c) == "table" then State[k] = Color3.new(v.__c[1], v.__c[2], v.__c[3]) end
            elseif type(v) == type(d) then
                State[k] = v
            end
        end
    end
    return true
end

function WIN.updateMenuOpacity()
    WIN.pvPanel.BackgroundTransparency, WIN.mainP.BackgroundTransparency = State.menuTransp, State.menuTransp
end
function WIN.applyAll()
    applyPost()
    HUD.updateVignette()
    updateEmitters()
    buildConst()
    rebuildAll()
    rebuildTargetFX()
    setAura() setTrail() setGlow()
    HUD.snd.Volume, HUD.snd.Looped = State.musicVol, State.musicLoop
    WIN.updateMenuOpacity()
    WIN.cfgBox.Text = State.configName
    render(true)
end
function WIN.saveConfig()
    if not WIN.hasFS then notify("Config", "Executor has no file access") return end
    State.configName = WIN.cfgBox.Text ~= "" and WIN.cfgBox.Text or "default"
    pcall(function() if isfolder and not isfolder("Hiruku") then makefolder("Hiruku") end end)
    local ok = pcall(writefile, WIN.cfgPath(State.configName), WIN.encodeState())
    notify("Config", ok and ("Saved: " .. State.configName) or "Save failed")
end
function WIN.loadConfig(silent)
    if not WIN.hasFS then if not silent then notify("Config", "Executor has no file access") end return end
    State.configName = WIN.cfgBox.Text ~= "" and WIN.cfgBox.Text or State.configName
    local path = WIN.cfgPath(State.configName)
    local ok, json = pcall(function() if isfile(path) then return readfile(path) end end)
    if ok and json and WIN.decodeInto(json) then
        WIN.applyAll()
        notify("Config", "Loaded: " .. State.configName)
    elseif not silent then
        notify("Config", "Not found: " .. State.configName)
    end
end
function WIN.setAutoload(v)
    if not WIN.hasFS then return end
    pcall(function()
        if isfolder and not isfolder("Hiruku") then makefolder("Hiruku") end
        if v then writefile("Hiruku/_auto.txt", State.configName)
        elseif isfile("Hiruku/_auto.txt") and delfile then delfile("Hiruku/_auto.txt") end
    end)
end

local currentAnimation
local savedAnimations = {}

local function stopUserAnimation()
    if currentAnimation then
        pcall(function() currentAnimation:Stop(0.15) end)
        pcall(function() currentAnimation:Destroy() end)
        currentAnimation = nil
    end
end

local function playUserAnimation(id)
    id = tostring(id or ""):gsub("%D", "")
    if id == "" then notify("Animation", "Enter an asset ID") return end
    local hum = Real.hum
    if not hum then notify("Animation", "Character not ready") return end
    local animator = hum:FindFirstChildOfClass("Animator") or new("Animator", { Parent = hum })
    stopUserAnimation()
    local anim = new("Animation", { AnimationId = "rbxassetid://" .. id })
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    anim:Destroy()
    if not ok or not track then
        notify("Animation", "Could not load this animation")
        return
    end
    track.Looped = State.animLoop
    track:Play(0.15, 1, State.animSpeed)
    currentAnimation = track
    State.animId = id
    notify("Animation", "Playing " .. id)
end

local function saveAnimationId()
    local id = tostring(State.animId or ""):gsub("%D", "")
    if id == "" then notify("Animation", "Enter an asset ID") return end
    table.insert(savedAnimations, id)
    while #savedAnimations > 12 do table.remove(savedAnimations, 1) end
    if type(writefile) == "function" then
        pcall(function()
            if makefolder and isfolder and not isfolder("Hiruku") then makefolder("Hiruku") end
            writefile("Hiruku/animations.json", HttpService:JSONEncode(savedAnimations))
        end)
    end
    notify("Animations", "Saved " .. id)
end

local function loadAnimationCollection()
    savedAnimations = {}
    if type(readfile) == "function" and type(isfile) == "function" then
        local ok, data = pcall(function()
            if isfile("Hiruku/animations.json") then return readfile("Hiruku/animations.json") end
        end)
        if ok and data then
            local good, decoded = pcall(HttpService.JSONDecode, HttpService, data)
            if good and type(decoded) == "table" then savedAnimations = decoded end
        end
    end
    if #savedAnimations == 0 then
        notify("Animations", "No saved animations")
    else
        State.animId = tostring(savedAnimations[#savedAnimations])
        notify("Animations", "Loaded " .. tostring(#savedAnimations) .. " saved")
        render(true)
    end
end

local MusicTracks = {
    ["Raining Tacos"] = { id = "142376088", title = "Raining Tacos" },
    ["Turtle"] = { id = "9245559862", title = "Parry Gripp - Turtle" },
    ["Bossa Me"] = { id = "1837768921", title = "Bossa Me (30)" },
    ["Congratulations"] = { id = "628700458", title = "Congratulations, You Won!" },
    ["Morning Mood"] = { id = "1846088038", title = "Morning Mood" },
    ["Four Seasons - Spring"] = { id = "9045766074", title = "The Four Seasons - Spring" },
    ["Classic Easter"] = { id = "1836009208", title = "Classic Easter" },
    ["Science Mysteries"] = { id = "1840776993", title = "Science Mysteries" },
    ["Paradise Falls"] = { id = "1837879082", title = "Paradise Falls" },
    ["Life in an Elevator"] = { id = "1841647093", title = "Life in an Elevator" },
    ["Chill Jazz"] = { id = "1845341094", title = "Chill Jazz" },
    ["Cool Vibes"] = { id = "1840684529", title = "Cool Vibes" },
    ["Gymnopedie No. 1"] = { id = "9045766377", title = "Gymnopedie No. 1" },
    ["Night Run"] = { id = "9044545570", title = "Night Run" },
}

HUD.selectTrack = function(name)
    local tr = MusicTracks[name]
    if tr then
        State.musicId = tr.id
        HUD.musicTitle = tr.title
        if HUD.musicIdBox then HUD.musicIdBox.Text = tr.id end
        notify("Radio", tr.title)
    end
end

HUD.playSelectedMusic = function()
    local tr = MusicTracks[State.musicTrack]
    if State.musicTrack ~= "Custom" and tr then
        HUD.playMusic(tr.id)
        HUD.musicTitle = tr.title
    else
        HUD.playMusic(State.musicId)
    end
end

---------------------------------------------------------------- pages
local function T(name, key, on, opts) return { kind = "toggle", name = name, key = key, on = on, opts = opts } end
local function S(name, key, mn, mx, step, on) return { kind = "slider", name = name, key = key, min = mn, max = mx, step = step, on = on } end
local function CL(name, key, on, set) return { kind = "colors", name = name, key = key, on = on, set = set } end
local function DD(name, key, values, on) return { kind = "dropdown", name = name, key = key, values = values, on = on } end
local function BT(name, ic, on) return { kind = "button", name = name, icon = ic, on = on } end
local function IN(name, key, ph, on) return { kind = "input", name = name, key = key, placeholder = ph, on = on } end
local function LB(text) return { kind = "label", name = text } end

local function wingPreset(style, a, b, glow, alpha, grad)
    return function()
        State.wings, State.wingStyle, State.wingColorA, State.wingColorB = true, style, a, b
        State.wingGlow, State.wingAlpha, State.wingGradient, State.wingRainbow = glow, alpha, grad, false
        rebuildAll()
        render(true)
        notify("Wings", style)
    end
end

WIN.Pages = {
    { name = "Visuals", icon = "eye", groups = {
        { name = "Screen", features = {
            T("Crosshair", "cross", nil, { DD("Style", "crossStyle", { "Ring", "Spin", "Cross", "Dot" }), S("Size", "crossSize", 20, 140, 2), S("Gap", "crossGap", 0, 20, 1), CL("Color", "crossColor") }),
            T("Custom Cursor", "cursor", HUD.updateCursorState, { S("Size", "cursorSize", 6, 40, 1), CL("Color", "cursorColor") }),
            T("Motion Graph", "graph"),
            T("Watermark", "watermark", nil, { T("Name", "wmName"), T("Username", "wmUser"), T("FPS", "wmFps"), T("Ping", "wmPing"), T("Clock", "wmTime") }),
            T("Vignette", "vignette", nil, { S("Strength", "vigStrength", 0.1, 1, 0.05, HUD.updateVignette) }),
            T("Cinematic Bars", "bars", nil, { S("Height", "barsSize", 0.04, 0.18, 0.01, function() HUD.barsShown = nil end) }),
            T("Custom FOV", "fovOn", function(v) if not v then cam().FieldOfView = origFov end end, { S("FOV", "fovVal", 40, 120, 1) }),
            T("Notifications", "notify"),
        } },
        { name = "Effects", features = {
            T("China Hat", "hat", rebuildAll, {
    S("Size", "hatSize", 0.5, 2, 0.05, rebuildAll),
    S("Height", "hatHeight", -0.4, 1.6, 0.05, rebuildAll),
    S("Forward", "hatForward", -0.8, 0.8, 0.05, rebuildAll),
    S("Side", "hatSide", -0.8, 0.8, 0.05, rebuildAll),
    S("Spin Speed", "hatSpin", 0, 8, 0.1),
    T("Rainbow", "hatRainbow"),
    CL("Color", "hatColor")
}),
            T("Halo", "halo", rebuildAll, { S("Height", "haloHeight", 0.6, 1.8, 0.05), T("Rainbow", "haloRainbow"), CL("Color", "haloColor") }),
            T("Orbiting Orbs", "orbs", rebuildAll, { S("Count", "orbCount", 2, 12, 1, rebuildAll), S("Radius", "orbRadius", 2, 6, 0.1), S("Speed", "orbSpeed", 0.2, 4, 0.1), T("Rainbow", "orbRainbow"), CL("Color", "orbColor") }),
            T("Ground Ring", "ring", rebuildAll, { S("Radius", "ringSize", 1.5, 7, 0.1), T("Rainbow", "ringRainbow"), CL("Color", "ringColor") }),
            T("Footsteps", "steps", nil, { T("Rainbow", "stepsRainbow"), CL("Color", "stepsColor") }),
            T("Rainbow Trail", "trail", setTrail),
            T("Aura Particles", "aura", setAura, { S("Density", "auraRate", 5, 100, 1, updateAura), CL("Color", "auraColor", setAura) }),
            T("Glow Outline", "glow", setGlow, { S("Fill", "glowFill", 0, 1, 0.05, updateGlow), CL("Color", "glowColor", updateGlow) }),
            T("Tool Glow", "toolGlow"),
        } },
        { name = "Players", features = {
            T("Target ESP", "targetEsp", function() rebuildTargetFX() refreshPlayerVisuals() end, {
                DD("Visual", "targetVisual", { "Ghost Orbit", "Crystal Orbit", "Target Circle", "Spiral", "Brackets" }, rebuildTargetFX),
                S("Count", "targetCount", 3, 10, 1, rebuildTargetFX),
                S("Radius", "targetRadius", 1.5, 5, 0.1),
                S("Speed", "targetSpeed", 0.3, 4, 0.1),
                S("Height", "targetHeight", 1, 4, 0.1),
                S("Size", "targetSize", 0.3, 1.2, 0.05, rebuildTargetFX),
                T("Pulse", "targetPulse"),
                T("Rainbow", "targetRainbow"),
                T("Only Visible", "targetOnlyVisible"),
                T("Name", "targetName"),
                T("Distance", "targetDistance"),
                T("Health", "targetHealth"),
                CL("Color", "targetColor"),
            }),
            T("Player Info", "playerInfo"),
            T("Chams", "chams", refreshPlayerVisuals, {
                DD("Style", "chamsMode", { "Outline", "Fill", "Pulse", "Glass" }, refreshPlayerVisuals),
                CL("Color", "chamsColor", refreshPlayerVisuals),
                T("Pulse", "chamsPulse", refreshPlayerVisuals),
                S("Transparency", "chamsTransparency", 0.05, 0.9, 0.05, refreshPlayerVisuals),
            }),
            T("Jump Circle", "jumpCircle", rebuildAll, {
                S("Size", "jumpCircleSize", 1.2, 6, 0.1, rebuildAll),
                S("Thickness", "jumpCircleThickness", 0.04, 0.3, 0.01),
                T("Pulse", "jumpCirclePulse"),
                T("Rainbow", "jumpCircleRainbow"),
                S("Fade Time", "jumpFade", 1.5, 4, 0.1),
                S("Rise", "jumpRise", 0, 0.8, 0.05),
                CL("Color", "jumpCircleColor"),
            }),
        } },
        { name = "Model", features = {
            DD("Material", "mat", { "Off", "Neon", "ForceField", "Glass", "Ice", "Metal" }),
            T("Skin Color", "skinColor", nil, { CL("Color", "skinCol") }),
            T("Rainbow Skin", "rainbowSkin"),
            S("Ghost", "ghost", 0, 0.9, 0.05),
            T("Headless", "headless"),
            BT("Refresh Preview", "rotate-cw", function() refreshPreview() notify("Preview", "Refreshed") end),
        } },
    } },
    { name = "World", icon = "moon-star", groups = {
        { name = "Sky", features = {
            DD("Sky Preset", "skyPreset", { "Off", "Night Blue", "Deep Space", "Sunset", "Purple Haze", "Blood Moon" }, applySkyPreset),
            T("Custom Time", "timeOn", worldOff, { S("Time", "timeVal", 0, 24, 0.25), S("Cycle Speed", "timeSpeed", 0, 2, 0.05) }),
            T("Stars", "stars", worldOff, { S("Amount", "starCount", 0, 5000, 100) }),
            T("Atmosphere", "atmOn", worldOff, { S("Density", "atmDensity", 0, 1, 0.01), S("Haze", "atmHaze", 0, 4, 0.1), S("Glare", "atmGlare", 0, 1, 0.05), CL("Color", "atmColor", nil, DarkSwatches) }),
            T("Fog", "fogOn", worldOff, { S("Start", "fogStart", 0, 500, 5), S("End", "fogEnd", 50, 3000, 10), CL("Color", "fogColor", nil, DarkSwatches) }),
            T("Ambient Light", "ambOn", worldOff, { CL("Color", "ambColor", nil, DarkSwatches) }),
            T("Exposure", "expOn", worldOff, { S("Value", "exposure", -2, 2, 0.05) }),
        } },
        { name = "Shaders", features = {
            DD("Preset", "shaderPreset", { "Off", "Cinematic", "Neon", "Warm", "Noir", "Dream" }, applyShaderPreset),
            T("Bloom", "bloom", applyPost, { S("Intensity", "bloomInt", 0, 3, 0.05, applyPost), S("Size", "bloomSize", 1, 56, 1, applyPost), S("Threshold", "bloomThr", 0, 2, 0.05, applyPost) }),
            T("Color Grade", "cc", applyPost, { S("Saturation", "ccSat", -1, 1.5, 0.05, applyPost), S("Contrast", "ccCon", -0.5, 1, 0.05, applyPost), S("Brightness", "ccBri", -0.3, 0.3, 0.01, applyPost), CL("Tint", "tint", applyPost, TintSwatches) }),
            T("Sun Rays", "sun", applyPost, { S("Intensity", "sunInt", 0, 0.6, 0.01, applyPost) }),
            T("Depth of Field", "dof", applyPost, { S("Far Blur", "dofFar", 0, 1, 0.05, applyPost) }),
            T("Blur", "blur", applyPost, { S("Size", "blurSize", 1, 30, 1, applyPost) }),
        } },
        { name = "World FX", features = {
            T("Digital Ground Grid", "worldGrid", nil, {
                DD("Style", "worldGridStyle", { "Circuit", "Square", "Cross" }),
                S("Size", "worldGridSize", 8, 60, 1),
                T("Pulse", "worldGridPulse"),
                CL("Color", "worldGridColor"),
            }),
            T("Sky Rings", "skyRings", nil, {
                S("Count", "skyRingCount", 1, 5, 1),
                S("Radius", "skyRingRadius", 20, 70, 1),
                S("Height", "skyRingHeight", 8, 30, 1),
                S("Speed", "skyRingSpeed", 0.1, 1.5, 0.05),
                T("Rainbow", "skyRingRainbow"),
                CL("Color", "skyRingColor"),
            }),
            T("Aurora Curtains", "aurora", nil, {
                S("Strength", "auroraStrength", 0.05, 0.8, 0.05),
                CL("Color", "auroraColor"),
            }),
            T("Shockwave Rings", "worldPulse", nil, {
                S("Rate", "worldPulseRate", 0.5, 5, 0.1),
                CL("Color", "worldPulseColor"),
            }),
            T("Floating Shards", "worldShards", nil, {
                S("Count", "worldShardCount", 4, 30, 1),
                S("Speed", "worldShardSpeed", 0.1, 2, 0.05),
                CL("Color", "worldShardColor"),
            }),
        } },
        { name = "Ambience", features = {
            T("Constellations", "const", buildConst, { S("Count", "constCount", 3, 24, 1, buildConst), T("Twinkle", "constTwinkle"), CL("Color", "constColor") }),
            T("Fireflies", "fireflies", updateEmitters, { CL("Color", "flyColor", updateEmitters) }),
            T("Snow", "snow", updateEmitters, { S("Amount", "snowRate", 20, 300, 5, updateEmitters) }),
            T("Dust Motes", "dust", updateEmitters),
        } },
    } },
    { name = "Wings", icon = "feather", groups = {
        { name = "Wings", features = {
            T("Wings", "wings", rebuildAll),
            DD("Style", "wingStyle", { "Angel", "Demon", "Fairy", "Cyber" }, rebuildAll),
            S("Size", "wingSize", 0.6, 2.2, 0.05, rebuildAll),
            CL("Primary", "wingColorA", function() if State.wingParticles then rebuildAll() end end),
            CL("Secondary", "wingColorB"),
            T("Gradient", "wingGradient"),
            T("Rainbow", "wingRainbow"),
            T("Neon Glow", "wingGlow", rebuildAll),
            S("Transparency", "wingAlpha", 0, 0.8, 0.05),
        } },
        { name = "Animation", features = {
            S("Flap Speed", "flapSpeed", 0.5, 8, 0.1),
            S("Flap Amplitude", "flapAmp", 5, 40, 1),
            T("Idle Float", "wingFloat"),
            T("Spread In Air", "wingAir"),
            T("Sparkle Particles", "wingParticles", rebuildAll),
        } },
        { name = "Presets", features = {
            BT("Seraph", nil, wingPreset("Angel", WHITE, Color3.fromRGB(200, 200, 212), true, 0.1, true)),
            BT("Vampire", nil, wingPreset("Demon", Color3.fromRGB(22, 22, 26), Color3.fromRGB(200, 40, 55), false, 0.05, true)),
            BT("Sylph", nil, wingPreset("Fairy", Color3.fromRGB(200, 240, 255), Color3.fromRGB(255, 200, 240), true, 0.3, true)),
            BT("Neon Blade", nil, wingPreset("Cyber", Color3.fromRGB(90, 255, 230), Color3.fromRGB(120, 120, 255), true, 0.1, true)),
            BT("Void", nil, wingPreset("Angel", Color3.fromRGB(14, 14, 20), Color3.fromRGB(120, 120, 136), false, 0.05, true)),
        } },
    } },
    { name = "Animations", icon = "sparkles", groups = {
        { name = "Animation Player", features = {
            IN("Animation ID", "animId", "rbxassetid number"),
            S("Speed", "animSpeed", 0.2, 3, 0.1),
            T("Loop", "animLoop"),
            BT("Play Animation", "play", function() playUserAnimation(State.animId) end),
            BT("Stop Animation", "square", stopUserAnimation),
        } },
        { name = "Library", features = {
            BT("Wave", "play", function() playUserAnimation("3344650532") end),
            BT("Applaud", "play", function() playUserAnimation("5911729486") end),
            BT("Agree", "play", function() playUserAnimation("4841397952") end),
            BT("Disagree", "play", function() playUserAnimation("4841401869") end),
            BT("Shrug", "play", function() playUserAnimation("3334392772") end),
            BT("Laugh", "play", function() playUserAnimation("3337966527") end),
            BT("Sleep", "play", function() playUserAnimation("4686925579") end),
        } },
        { name = "Saved Collection", features = {
            BT("Save Current ID", "download", saveAnimationId),
            BT("Load Saved Collection", "upload", loadAnimationCollection),
            LB("Animations use Roblox asset IDs and only play when the experience permits the requested animation."),
        } },
    } },
    { name = "Misc", icon = "music", groups = {
        { name = "Protection", features = {
            T("Anti Fling", "antiFling", nil, {
                S("Max Speed", "antiFlingMaxSpeed", 40, 180, 5),
                S("Max Angular", "antiFlingMaxAngular", 20, 180, 5),
                T("Position Recovery", "antiFlingRecovery"),
            }),
        } },
        { name = "Music", features = {
            T("Player Widget", "music"),
            DD("Playlist", "musicTrack", { "Custom", "Raining Tacos", "Turtle", "Bossa Me", "Congratulations", "Morning Mood", "Four Seasons - Spring", "Classic Easter", "Science Mysteries", "Paradise Falls", "Life in an Elevator", "Chill Jazz", "Cool Vibes", "Gymnopedie No. 1", "Night Run" }, function(v) HUD.selectTrack(v) end),
            IN("Sound ID", "musicId", "rbxassetid number"),
            BT("Play Selected", "play", function() HUD.playSelectedMusic() end),
            BT("Pause / Resume", "pause", HUD.toggleMusic),
            BT("Stop", "square", function() HUD.snd:Stop() HUD.musicTitle = "Nothing playing" end),
            S("Volume", "musicVol", 0, 1, 0.05, function(v) HUD.snd.Volume = v end),
            T("Loop", "musicLoop", function(v) HUD.snd.Looped = v end),
        } },
        { name = "Info", features = {
            LB("Paste an audio asset ID and press Play. Only assets the game is allowed to load will play."),
        } },
    } },
    { name = "Skin Changer", icon = "user", groups = {
        { name = "Avatar", features = {
            DD("Preset", "skinPreset", { "Default", "Ice", "Ghost", "Crimson", "Void", "Gold" }, function() applySkinPreset() end),
            IN("User ID", "skinUserId", "Roblox User ID", function(v) applySkinByUserId(v) end),
            BT("Apply Skin", "download", function()
                if State.skinUserId ~= "" then applySkinByUserId(State.skinUserId) else applySkinPreset() end
            end),
            S("Visual Scale", "skinScale", 0.8, 1.2, 0.01, function(v)
                if Real.model then pcall(function() Real.model:ScaleTo(v) end) end
                if Prev.model then pcall(function() Prev.model:ScaleTo(v) end) end
            end),
            LB("Skin Changer is visual and applies the selected avatar appearance locally."),
        } },
    } },
    { name = "Settings", icon = "settings", groups = {
        { name = "Menu", features = {
            CL("Accent Color", "accentColor", function() applyAccent() end),
            S("Opacity", "menuTransp", 0, 0.6, 0.02, WIN.updateMenuOpacity),
            T("Background Blur", "menuBlur", nil, { S("Amount", "blurAmt", 2, 30, 1) }),
            T("Dim Background", "dim"),
            LB("Menu key: RightShift (or tap the Hiruku pill). Drag the top bar to move the window."),
        } },
        { name = "HUD Editor", features = {
            T("Edit HUD", "hudEdit", function(v)
                if v then
                    HUD.musicPanel.Visible = State.music or true
                    HUD.targetInfo.Visible = true
                    HUD.targetInfo.GroupTransparency = 0
                else
                    HUD.targetInfo.Visible = false
                    HUD.targetInfo.GroupTransparency = 1
                end
            end),
            BT("Reset HUD Positions", "rotate-cw", function()
                State.hudMusicX, State.hudMusicY = 0.5, 0.78
                State.hudTargetX, State.hudTargetY = 0.78, 0.28
                HUD.musicPanel.Position = UDim2.fromScale(State.hudMusicX, State.hudMusicY)
                HUD.targetInfo.Position = UDim2.fromScale(State.hudTargetX, State.hudTargetY)
                render(true)
            end),
            LB("When Edit HUD is enabled, drag the Music and Player Info panels directly on the screen."),
        } },
        { name = "Config", features = {
            IN("Config Name", "configName", "default", function(t) WIN.cfgBox.Text = t end),
            BT("Save Config", "download", WIN.saveConfig),
            BT("Load Config", "upload", function() WIN.loadConfig(false) end),
            T("Auto Load On Start", "autoload", WIN.setAutoload),
        } },
        { name = "Script", features = {
            BT("Unload Hiruku", "power", function() unload() end),
        } },
    } },
}

WIN.AllFeatures = {}
for _, p in ipairs(WIN.Pages) do
    for _, g in ipairs(p.groups) do
        for _, f in ipairs(g.features) do if f.kind ~= "label" then table.insert(WIN.AllFeatures, f) end end
    end
end

WIN.current, WIN.searching = 1, false
render = function(keepScroll)
    local pos = WIN.content.CanvasPosition
    for _, c in ipairs(WIN.content:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local q = lower(WIN.search.Text)
    if q ~= "" then
        local list = {}
        for _, f in ipairs(WIN.AllFeatures) do
            if lower(f.name):find(q, 1, true) then table.insert(list, f) end
        end
        if #list == 0 then list = { LB("No results.") } end
        WIN.buildGroup(WIN.content, "Results", list, 1)
    else
        for gi, g in ipairs(WIN.Pages[WIN.current].groups) do WIN.buildGroup(WIN.content, g.name, g.features, gi * 3 - 2) end
    end
    if keepScroll then task.defer(function() WIN.content.CanvasPosition = pos end) end
end

WIN.navs = {}
function WIN.selectTab(i)
    WIN.current = i
    WIN.searching = true
    WIN.search.Text = ""
    WIN.searching = false
    for j, n in ipairs(WIN.navs) do
        local on = (j == i)
        tween(n.btn, 0.15, { BackgroundColor3 = State.accentColor, BackgroundTransparency = on and 0.84 or 1 })
        tween(n.label, 0.15, { TextColor3 = on and State.accentColor or GRAY })
        tintIcon(n.icon, on and State.accentColor or GRAY)
    end
    render()
    local base = WIN.contentPos
    WIN.content.Position = base + (WIN.mobile and UDim2.fromOffset(0, 14) or UDim2.fromOffset(14, 0))
    tween(WIN.content, 0.2, { Position = base })
end

for i, page in ipairs(WIN.Pages) do
    local b
    if WIN.mobile then
        b = new("TextButton", {
            Size = UDim2.fromOffset(100, 40), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = WIN.nav,
        })
        corner(b, 8)
        local ic = icon(b, page.icon, 16, GRAY)
        ic.Position = UDim2.fromOffset(10, 12)
        local lbl = new("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), Text = page.name,
            Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
        })
        WIN.navs[i] = { btn = b, icon = ic, label = lbl }
    else
        b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = WIN.nav,
        })
        corner(b, 8)
        local ic = icon(b, page.icon, 16, GRAY)
        ic.Position = UDim2.new(0, 12, 0.5, -8)
        local lbl = new("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -44, 1, 0), Text = page.name,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = GRAY, TextXAlignment = Enum.TextXAlignment.Left, Parent = b,
        })
        WIN.navs[i] = { btn = b, icon = ic, label = lbl }
    end
    b.MouseEnter:Connect(function() if WIN.current ~= i then tween(b, 0.1, { BackgroundTransparency = 0.95 }) end end)
    b.MouseLeave:Connect(function() if WIN.current ~= i then tween(b, 0.1, { BackgroundTransparency = 1 }) end end)
    b.MouseButton1Click:Connect(function() WIN.selectTab(i) end)
end

bind(WIN.search:GetPropertyChangedSignal("Text"), function() if not WIN.searching then render() end end)
bind(WIN.saveBtn.MouseButton1Click, WIN.saveConfig)
bind(WIN.cfgBox.FocusLost, function() State.configName = WIN.cfgBox.Text ~= "" and WIN.cfgBox.Text or "default" end)
task.defer(applyAccent)

---------------------------------------------------------------- preview clone
refreshPreview = function()
    if Prev.model then Prev.model:Destroy() end
    Prev.model, Prev.root = nil, nil
    clearFX(Prev)
    local char = Real.model
    if not (char and char.Parent and char:FindFirstChild("HumanoidRootPart")) then return end
    char.Archivable = true
    local ok, clone = pcall(function() return char:Clone() end)
    if not (ok and clone) then return end
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BaseScript") or d:IsA("Tool") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Trail")
            or d:IsA("Highlight") or d:IsA("ForceField") then
            d:Destroy()
        end
    end
    clone.Name = "PreviewModel"
    local hrp = clone:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = true end
    clone:PivotTo(CFrame.new())
    clone.Parent = WIN.viewport
    bindSubject(Prev, clone)
    buildWings(Prev)
    buildAccessories(Prev)
end

---------------------------------------------------------------- open / close
WIN.menuOpen = false
WIN.menuBlurFX = new("BlurEffect", { Name = "HirukuMenuBlur", Size = 0, Parent = Lighting })
function WIN.fitScale()
    local v = cam().ViewportSize
    return math.clamp(math.min((v.X - 20) / WIN.WIN_W, (v.Y - 20) / WIN.WIN_H), 0.4, 1)
end
function WIN.setOpen(open)
    WIN.menuOpen = open
    local fit = WIN.fitScale()
    if open then
        WIN.win.Visible = true
        WIN.mScale.Scale = fit * 0.92
        WIN.win.GroupTransparency = 1
        tween(WIN.mScale, 0.28, { Scale = fit }, Enum.EasingStyle.Back)
        tween(WIN.win, 0.2, { GroupTransparency = 0 })
        if State.dim then WIN.dimFrame.Visible = true tween(WIN.dimFrame, 0.25, { BackgroundTransparency = 0.6 }) end
        if State.menuBlur then tween(WIN.menuBlurFX, 0.3, { Size = State.blurAmt }) end
        task.spawn(refreshPreview)
    else
        tween(WIN.mScale, 0.18, { Scale = fit * 0.94 })
        tween(WIN.win, 0.18, { GroupTransparency = 1 })
        tween(WIN.dimFrame, 0.2, { BackgroundTransparency = 1 })
        tween(WIN.menuBlurFX, 0.2, { Size = 0 })
        task.delay(0.22, function()
            if not WIN.menuOpen then WIN.win.Visible = false WIN.dimFrame.Visible = false end
        end)
    end
end

-- launcher pill
local launcherGui = gui
local function launcherMetrics()
    local v = cam().ViewportSize
    local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
    local insetY = 0
    pcall(function()
        local topLeft = GuiService:GetGuiInset()
        if topLeft then insetY = math.max(0, topLeft.Y) end
    end)
    local minSide = math.min(v.X, v.Y)
    local scale = math.clamp(minSide / 700, 0.78, 1.05)
    local side = math.max(10, math.floor(v.X * 0.025))
    local top = math.max(insetY + 6, 72)
    local w = math.clamp(118 * scale, 96, 126)
    local h = math.clamp(36 * scale, 32, 40)
    if touch then
        w = math.clamp(112 * scale, 98, 122)
        h = math.clamp(38 * scale, 34, 42)
    end
    if v.X < 420 then
        side = 8
        w = math.min(w, 108)
    end
    return scale, top, side, w, h
end
WIN.launcher = new("TextButton", {
    Name = "Launcher", AnchorPoint = Vector2.new(0, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 0.12,
    Text = "", AutoButtonColor = false, Active = true, Visible = true, ZIndex = 1000, Parent = launcherGui,
})
corner(WIN.launcher, 18)
WIN.launcherStroke = stroke(WIN.launcher, State.accentColor, 0.48, 1.5)
WIN.lIc = icon(WIN.launcher, "eye", 15, WHITE)
WIN.lIc.ZIndex = 1001
WIN.lIc.AnchorPoint = Vector2.new(0, 0.5)
new("TextLabel", {
    Name = "Title", BackgroundTransparency = 1, Text = "Hiruku", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = WHITE,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 1001, Parent = WIN.launcher,
})
function WIN.updateLauncher()
    if not WIN.launcher or not WIN.launcher.Parent then return end
    local viewport = cam().ViewportSize
    if viewport.X <= 1 or viewport.Y <= 1 then return end

    local scale, top, side, w, h = launcherMetrics()
    local width = math.floor(w * scale + 0.5)
    local height = math.floor(h * scale + 0.5)
    local iconSize = math.max(13, math.floor(15 * scale + 0.5))

    WIN.launcher.Position = UDim2.fromOffset(math.floor(side + 0.5), math.floor(top + 0.5))
    WIN.launcher.Size = UDim2.fromOffset(width, height)

    WIN.lIc.Size = UDim2.fromOffset(iconSize, iconSize)
    WIN.lIc.Position = UDim2.fromOffset(
        math.floor(12 * scale + 0.5),
        math.floor((height - iconSize) / 2)
    )

    local title = WIN.launcher:FindFirstChild("Title")
    if title then
        title.Position = UDim2.fromOffset(math.floor(34 * scale + 0.5), 0)
        title.Size = UDim2.new(1, -math.floor(42 * scale + 0.5), 1, 0)
        title.TextSize = math.max(11, 14 * scale)
    end
end
WIN.updateLauncher()
bind(cam():GetPropertyChangedSignal("ViewportSize"), WIN.updateLauncher)
bind(UIS:GetPropertyChangedSignal("TouchEnabled"), WIN.updateLauncher)
bind(UIS:GetPropertyChangedSignal("KeyboardEnabled"), WIN.updateLauncher)
bind(WIN.launcher.Activated, function() WIN.setOpen(not WIN.menuOpen) end)
WIN.launcher:GetPropertyChangedSignal("Visible"):Connect(function()
    if not WIN.launcher.Visible then WIN.launcher.Visible = true end
end)

-- keep the launcher fixed near the device top edge; it is not draggable
bind(UIS.InputBegan, function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then WIN.setOpen(not WIN.menuOpen) end
end)

---------------------------------------------------------------- character binding
local function onChar(c)
    task.spawn(function()
        c:WaitForChild("HumanoidRootPart", 10)
        c:WaitForChild("Humanoid", 10)
        task.wait(0.4)
        if LP.Character ~= c then return end
        bindSubject(Real, c)
        rebuildAll()
        setAura() setTrail() setGlow()
        if WIN.menuOpen then refreshPreview() end
    end)
end
bind(LP.CharacterAdded, onChar)
bind(LP.CharacterRemoving, function()
    clearFX(Real)
    Real.model, Real.root, Real.torso, Real.head, Real.hum = nil, nil, nil, nil, nil
    Real.parts, Real.orig = {}, {}
end)
if LP.Character then onChar(LP.Character) end

local worldFX = { grid = {}, shards = {}, pulses = {}, skyRings = {}, lastPulse = 0 }

local function clearWorldFX()
    for _, list in pairs(worldFX) do
        if type(list) == "table" then
            for _, obj in ipairs(list) do pcall(function() obj:Destroy() end) end
            table.clear(list)
        end
    end
end

local function groundY(pos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LP.Character, fxFolder }
    local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
    return hit and hit.Position.Y or (pos.Y - (Real.feet or 3))
end

local function ensureWorldGrid()
    if not State.worldGrid or not Real.root then
        for _, p in ipairs(worldFX.grid) do p.Transparency = 1 end
        return
    end
    local n = 10
    while #worldFX.grid < (n * 2 + 1) * 2 do
        local p = new("Part", {
            Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
            Material = Enum.Material.Neon, Parent = fxFolder,
        })
        table.insert(worldFX.grid, p)
    end
    local size = math.max(State.worldGridSize, 8)
    local spacing = size / n
    local root = Real.root.Position
    local y = groundY(root) + 0.035
    local pulse = State.worldGridPulse and (0.24 + (math.sin(os.clock() * 2.5) * 0.5 + 0.5) * 0.18) or 0.28
    local idx = 1
    for x = -n, n do
        local p = worldFX.grid[idx]
        p.Size = Vector3.new(0.045, 0.045, size * 2)
        p.CFrame = CFrame.new(root.X + x * spacing, y, root.Z)
        p.Color = State.worldGridColor
        p.Transparency = pulse + ((State.worldGridStyle == "Circuit" and x % 3 == 0) and 0.12 or 0)
        idx += 1
    end
    for z = -n, n do
        local p = worldFX.grid[idx]
        p.Size = Vector3.new(size * 2, 0.045, 0.045)
        p.CFrame = CFrame.new(root.X, y, root.Z + z * spacing)
        p.Color = State.worldGridColor
        p.Transparency = pulse + ((State.worldGridStyle == "Circuit" and z % 3 == 0) and 0.12 or 0)
        idx += 1
    end
end

local function ensureSkyRings()
    if not State.skyRings then
        for _, p in ipairs(worldFX.skyRings or {}) do p.Transparency = 1 end
        return
    end
    worldFX.skyRings = worldFX.skyRings or {}
    local need = math.clamp(State.skyRingCount, 1, 5) * 24
    while #worldFX.skyRings < need do
        local p = new("Part", {
            Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
            Material = Enum.Material.Neon, Size = Vector3.new(0.16, 0.16, 2.2), Parent = fxFolder,
        })
        table.insert(worldFX.skyRings, p)
    end
end

local function updateSkyRings(t)
    ensureSkyRings()
    if not State.skyRings then return end
    local c = cam().CFrame.Position
    local count = math.clamp(State.skyRingCount, 1, 5)
    local seg = 24
    for i, p in ipairs(worldFX.skyRings) do
        local ring = math.floor((i - 1) / seg) + 1
        if ring <= count then
            local j = (i - 1) % seg
            local a = j / seg * math.pi * 2 + t * State.skyRingSpeed * (ring % 2 == 0 and -1 or 1)
            local rr = State.skyRingRadius + math.sin(t * 0.7 + ring) * 2
            local center = c + Vector3.new(0, State.skyRingHeight + ring * 3, 0)
            local cf = CFrame.new(center) * CFrame.Angles(0, ring * 0.45 + t * 0.08, ring * 0.35)
            local localPos = Vector3.new(math.cos(a) * rr, math.sin(a) * rr * 0.38, math.sin(a) * rr)
            local pos = cf:PointToWorldSpace(localPos)
            local tangent = cf:VectorToWorldSpace(Vector3.new(-math.sin(a), math.cos(a) * 0.38, math.cos(a)))
            p.CFrame = CFrame.lookAt(pos, pos + tangent)
            p.Color = State.skyRingRainbow and hue(t, j / seg + ring * 0.13, 0.12) or State.skyRingColor
            p.Transparency = 0.18
        else
            p.Transparency = 1
        end
    end
end

local auroraParts = {}
local function updateAurora(t)
    if not State.aurora then
        for _, p in ipairs(auroraParts) do p.Transparency = 1 end
        return
    end
    while #auroraParts < 5 do
        local p = new("Part", {
            Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
            Material = Enum.Material.Neon, Size = Vector3.new(18, 0.25, 2), Parent = fxFolder,
        })
        table.insert(auroraParts, p)
    end
    local cp = cam().CFrame.Position
    for i, p in ipairs(auroraParts) do
        local x = (i - 3) * 16
        local y = 16 + math.sin(t * 0.55 + i) * 4
        p.CFrame = CFrame.new(cp + Vector3.new(x, y, 0)) * CFrame.Angles(0, math.sin(t * 0.2 + i) * 0.3, math.rad(-12 + i * 3))
        p.Color = State.auroraColor:Lerp(WHITE, (math.sin(t * 0.8 + i) * 0.5 + 0.5) * 0.35)
        p.Transparency = 0.7 - State.auroraStrength * 0.55
    end
end

local function updateWorldShards(t)
    if not State.worldShards or not Real.root then
        for _, p in ipairs(worldFX.shards) do p.Transparency = 1 end
        return
    end
    while #worldFX.shards < State.worldShardCount do
        local p = new("Part", {
            Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
            Material = Enum.Material.Neon, Size = Vector3.new(0.12, 1.4, 0.12),
            Parent = fxFolder,
        })
        table.insert(worldFX.shards, p)
    end
    for i, p in ipairs(worldFX.shards) do
        if i <= State.worldShardCount then
            local a = t * State.worldShardSpeed + i * 2.399
            local r = 8 + (i % 5) * 1.8
            local y = 2.5 + math.sin(t * 1.3 + i) * 1.5 + (i % 4) * 0.8
            local pos = Real.root.Position + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
            p.CFrame = CFrame.new(pos) * CFrame.Angles(a * 0.7, a, a * 0.35)
            p.Color = State.worldShardColor
            p.Transparency = 0.12
        else
            p.Transparency = 1
        end
    end
end

local function updateWorldPulses(t)
    if not State.worldPulse or not Real.root then
        for _, p in ipairs(worldFX.pulses) do p.Transparency = 1 end
        return
    end
    if t - worldFX.lastPulse > 1 / math.max(State.worldPulseRate, 0.1) then
        worldFX.lastPulse = t
        local p = new("Part", {
            Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
            CastShadow = false, Material = Enum.Material.Neon, Color = State.worldPulseColor,
            Size = Vector3.new(0.05, 1.2, 1.2), Transparency = 0.05,
            CFrame = CFrame.new(Real.root.Position - Vector3.new(0, Real.feet - 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2),
            Parent = fxFolder,
        })
        table.insert(worldFX.pulses, p)
        tween(p, 1.4, { Size = Vector3.new(0.05, 14, 14), Transparency = 1 })
        Debris:AddItem(p, 1.5)
    end
end

local jumpMarks = {}
local lastAir = false

local function spawnJumpCircle()
    if not State.jumpCircle or not Real.root then return end
    local root = Real.root
    local pos = root.Position
    local y = groundY(pos) + 0.045
    local folder = new("Folder", { Name = "HirukuJumpCircle", Parent = fxFolder })
    local pieces = {}
    local n = 48
    for i = 1, n do
        local a = i / n * math.pi * 2
        local p = new("Part", {
            Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
            Material = Enum.Material.Neon, Size = Vector3.new(State.jumpCircleThickness, 0.05, 0.42),
            Transparency = 1, Parent = folder,
        })
        local r = State.jumpCircleSize
        p.CFrame = CFrame.new(Vector3.new(pos.X + math.cos(a) * r, y, pos.Z + math.sin(a) * r))
            * CFrame.Angles(0, -a, 0)
        p.Color = State.jumpCircleRainbow and hue(os.clock(), i / n, 0.25) or State.jumpCircleColor
        table.insert(pieces, p)
        tween(p, 0.22, { Transparency = 0.08 })
        tween(p, 0.22, { Size = Vector3.new(State.jumpCircleThickness, 0.06, 0.52) })
        task.delay(State.jumpFade - 0.35, function()
            if p.Parent then
                tween(p, 0.35, { Transparency = 1, Size = Vector3.new(State.jumpCircleThickness, 0.02, 0.18) })
            end
        end)
    end
    table.insert(jumpMarks, folder)
    Debris:AddItem(folder, State.jumpFade + 0.5)
    task.delay(State.jumpFade + 0.55, function()
        for i, f in ipairs(jumpMarks) do
            if f == folder then table.remove(jumpMarks, i) break end
        end
    end)
end

---------------------------------------------------------------- main loop
local prevRot, tagsAcc = 0, 0
local TagNames = {
    { "wings", "Wings" }, { "hat", "China Hat" }, { "halo", "Halo" }, { "orbs", "Orbs" }, { "ring", "Ground Ring" },
    { "trail", "Trail" }, { "aura", "Aura" }, { "glow", "Glow" }, { "steps", "Footsteps" }, { "headless", "Headless" },
    { "rainbowSkin", "Rainbow Skin" },
}
bind(RunService.RenderStepped, function(dt)
    local t = os.clock()
    local c = cam()
    stepWorld(dt)
    if State.fovOn then c.FieldOfView = State.fovVal end

    if Real.root and Real.root.Parent then
        stepModel(Real, t)
        local air = Real.hum and Real.hum.FloorMaterial == Enum.Material.Air
        if air and not lastAir then spawnJumpCircle() end
        lastAir = air
        stepFX(Real, t, air)
        stepReal(dt, t)
    end

    if State.targetEsp or State.chams then
        HUD.playerVisualAcc = (HUD.playerVisualAcc or 0) + dt
        if HUD.playerVisualAcc >= 0.12 then
            HUD.playerVisualAcc = 0
            refreshPlayerVisuals()
        end
    end
    ensureWorldGrid()
    updateWorldShards(t)
    updateWorldPulses(t)
    updateSkyRings(t)
    updateAurora(t)
    updateTargetFX(t)

    if WIN.menuOpen and Prev.model then
        prevRot += dt * 0.7
        Prev.model:PivotTo(CFrame.Angles(0, prevRot, 0))
        stepModel(Prev, t)
        stepFX(Prev, t, false)
        tagsAcc += dt
        if tagsAcc > 0.5 then
            tagsAcc = 0
            local tags = {}
            for _, e in ipairs(TagNames) do if State[e[1]] then table.insert(tags, e[2]) end end
            if State.mat ~= "Off" then table.insert(tags, State.mat) end
            WIN.pvTags.Text = #tags > 0 and table.concat(tags, "  ·  ") or "No effects active"
        end
    end

    local camPos = c.CFrame.Position
    for _, e in pairs(SkyEm) do e.part.CFrame = CFrame.new(camPos + e.off) end
    stepConst(dt, t, camPos)
    HUD.stepHUD(dt, t)
end)

---------------------------------------------------------------- unload
unload = function()
    stopUserAnimation()
    clearTargetFX()
    for _, f in ipairs(jumpMarks) do pcall(function() f:Destroy() end) end
    for _, cn in ipairs(conns) do pcall(function() cn:Disconnect() end) end
    clearFX(Real)
    restoreModel(Real)
    if auraEm then auraEm:Destroy() end
    if glowHL then glowHL:Destroy() end
    if toolHL then toolHL:Destroy() end
    for _, i in ipairs(trailStuff) do pcall(function() i:Destroy() end) end
    for _, e in pairs(FX) do pcall(function() e:Destroy() end) end
    WIN.menuBlurFX:Destroy()
    HUD.snd:Destroy()
    pcall(function() HUD.targetInfo:Destroy() end)
    restoreWorld()
    if State.fovOn then cam().FieldOfView = origFov end
    if HUD.cursorHidden then UIS.MouseIconEnabled = true end
    for plr in pairs(playerVisuals) do destroyPlayerVisual(plr) end
    clearWorldFX()
    pcall(function() visualFolder:Destroy() end)
    pcall(function() fxFolder:Destroy() end)
    hud:Destroy()
    gui:Destroy()
    env.HirukuUnload = nil
end
env.HirukuUnload = unload

---------------------------------------------------------------- start
pcall(function()
    if WIN.hasFS and isfile("Hiruku/_auto.txt") then
        State.configName = readfile("Hiruku/_auto.txt")
        WIN.loadConfig(true)
    end
end)
applyPost()
WIN.selectTab(1)
WIN.setOpen(true)
notify("Hiruku", "Loaded · RightShift toggles the menu")
