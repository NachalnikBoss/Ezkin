--[[
    HIRUKU v2 — visual suite for MM2
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
    watermark = true, wmName = true, wmUser = true, wmFps = true, wmPing = true, wmTime = true,
    vignette = false, vigStrength = 0.6,
    bars = false, barsSize = 0.09,
    fovOn = false, fovVal = 80,
    notify = true,
    -- effects
    hat = false, hatSize = 1, hatSpin = 1.5, hatRainbow = false, hatColor = WHITE,
    halo = false, haloHeight = 0.95, haloRainbow = false, haloColor = C.gold,
    orbs = false, orbCount = 5, orbRadius = 3.2, orbSpeed = 1.2, orbRainbow = false, orbColor = WHITE,
    ring = false, ringSize = 3.4, ringRainbow = false, ringColor = WHITE,
    steps = false, stepsRainbow = false, stepsColor = WHITE,
    trail = false,
    aura = false, auraRate = 30, auraColor = WHITE,
    glow = false, glowFill = 0.75, glowColor = WHITE,
    toolGlow = false,
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
    -- misc
    music = false, musicId = "", musicVol = 0.6, musicLoop = true,
    -- settings
    menuTransp = 0.1, menuBlur = true, blurAmt = 14, dim = true, configName = "default", autoload = false,
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
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50, Parent = PlayerGui,
})
local hud = new("ScreenGui", {
    Name = "HirukuHUD", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 40, Parent = PlayerGui,
})
local fxFolder = new("Folder", { Name = "HirukuFX", Parent = workspace })

---------------------------------------------------------------- icons (Lucide)
local Glyphs = {
    eye = "◉", ["moon-star"] = "☾", feather = "✦", music = "♪", settings = "⚙", search = "⌕", save = "▣",
    user = "●", ["chevron-down"] = "▾", play = "▶", pause = "❚❚", square = "■", ["rotate-cw"] = "↻",
    code = "</>", activity = "≈", wifi = "≋", clock = "◔", power = "⏻", download = "↓", upload = "↑",
}
local iconTargets = setmetatable({}, { __mode = "k" })
local Lucide

local function applyIcon(img, name)
    if not Lucide then return end
    local ok, asset = pcall(Lucide.GetAsset, name, 48)
    if ok and asset then
        img.Image = asset.Url
        img.ImageRectSize = asset.ImageRectSize
        img.ImageRectOffset = asset.ImageRectOffset
        local g = img:FindFirstChild("Glyph")
        if g then g.Visible = false end
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
    return { preview = preview, wing = {}, hat = {}, halo = {}, orbs = {}, ring = {}, parts = {}, orig = {}, feet = 3, applied = false }
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
    subj.wing, subj.hat, subj.halo, subj.orbs, subj.ring = {}, {}, {}, {}, {}
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
            { n = 7, len = 3.0, w = 0.46, tr = 0.05 }, { n = 7, len = 2.0, w = 0.42, tr = 0.18 }, { n = 6, len = 1.15, w = 0.36, tr = 0.3 },
        }
        for r, row in ipairs(rows) do
            for i = 1, row.n do
                add(row.len * (1 - math.abs(i - 2) * 0.05), row.w, 0.05, 6 + (i - 1) * 17 + (r - 1) * 8, (r - 1) * 0.035,
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
    local open = (air and State.wingAir) and math.rad(16) or 0
    local torsoCF = subj.torso.CFrame
    for _, f in ipairs(subj.wing) do
        local yaw = math.rad(-20) + math.sin(t * spd - f.b.idx * 0.16) * amp
        local C0 = f.base * CFrame.new(0, floatY, 0) * CFrame.Angles(0, f.side * yaw, 0) * CFrame.Angles(0, 0, -f.side * (f.b.theta + open))
        if f.weld then f.weld.C0 = C0 else f.part.CFrame = torsoCF * C0 * f.c1inv end
        f.part.Color = wingColor(f.b, t)
        f.part.Transparency = math.clamp(f.b.tr + State.wingAlpha, 0, 0.95)
    end
end

-- accessories ------------------------------------------------
local function buildAccessories(subj)
    if State.hat and subj.head then
        local th = 0.16 * State.hatSize
        for i = 1, 10 do
            local d = (1 - (i - 1) / 9 * 0.9) * 2.6 * State.hatSize
            local p = mkPart(subj, Vector3.new(th, d, d), Enum.Material.Neon, Enum.PartType.Cylinder)
            table.insert(subj.hat, { part = p, i = i, y = 0.55 + (i - 1) * th * 0.85 })
        end
    end
    if State.halo and subj.head then
        for i = 1, 18 do table.insert(subj.halo, { part = mkPart(subj, Vector3.new(0.14, 0.08, 0.42)), i = i }) end
    end
    if State.orbs and subj.root then
        for i = 1, State.orbCount do
            table.insert(subj.orbs, { part = mkPart(subj, Vector3.new(0.5, 0.5, 0.5), Enum.Material.Neon, Enum.PartType.Ball), i = i })
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
            it.part.CFrame = hcf * CFrame.new(0, it.y, 0) * CFrame.Angles(0, spin, math.pi / 2)
            it.part.Color = State.hatRainbow and hue(t, it.i * 0.04, 0.25) or State.hatColor:Lerp(WHITE, (it.i - 1) / 9 * 0.6)
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
            it.part.Position = rp + Vector3.new(math.cos(a) * State.orbRadius, math.sin(a * 2 + it.i) * 0.9 + 0.3, math.sin(a) * State.orbRadius)
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

-- real-character extras --------------------------------------
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

local stepAcc = 0
local function stepReal(dt, t)
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
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 44), Size = UDim2.fromOffset(0, 26),
    AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = hud,
})
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = HUD.wmHolder,
})
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
    local ic = icon(f, iconName, 13, WHITE)
    ic.LayoutOrder = 1
    local lbl = new("TextLabel", {
        Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE, Text = text, LayoutOrder = 2, Parent = f,
    })
    return f, lbl
end
HUD.wmNamePill = HUD.pill(1, "code", "Hiruku")
HUD.wmUserPill, HUD.wmUserLbl = HUD.pill(2, "user", LP.DisplayName)
HUD.wmFpsPill, HUD.wmFpsLbl = HUD.pill(3, "activity", "60 fps")
HUD.wmPingPill, HUD.wmPingLbl = HUD.pill(4, "wifi", "0 ms")
HUD.wmTimePill, HUD.wmTimeLbl = HUD.pill(5, "clock", "00:00")

-- music widget
HUD.snd = new("Sound", { Name = "HirukuMusic", Volume = State.musicVol, Looped = State.musicLoop, Parent = SoundService })
HUD.musicTitle = "Nothing playing"
HUD.musicPanel = new("Frame", {
    Position = UDim2.fromOffset(12, 56), Size = UDim2.fromOffset(236, 66), BackgroundColor3 = Color3.fromRGB(8, 8, 10),
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
    -- music widget
    HUD.musicPanel.Visible = State.music
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
WIN.mobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
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
    local o = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = BLACK, BackgroundTransparency = 0.55,
        Visible = false, LayoutOrder = 2, Parent = row,
    })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = o })
    for i, sf in ipairs(list) do WIN.buildRow(sf, o, i, true) end
    return o
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
        BackgroundColor3 = val and WHITE or OFF, Parent = head,
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
            o.Visible = not o.Visible
            tintIcon(gi, o.Visible and WHITE or GRAY)
        end)
    end
    head.MouseButton1Click:Connect(function()
        val = not val
        State[f.key] = val
        tween(track, 0.15, { BackgroundColor3 = val and WHITE or OFF })
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
    local fill = new("Frame", { Size = UDim2.fromScale(frac0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bar })
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
            TextColor3 = (State[f.key] == name) and WHITE or GRAY, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
            LayoutOrder = i, Parent = list,
        })
        new("UIPadding", { PaddingLeft = UDim.new(0, 26), Parent = ob })
        optBtns[name] = ob
        ob.MouseButton1Click:Connect(function()
            State[f.key] = name
            btn.Text = name
            list.Visible = false
            for n, b in pairs(optBtns) do b.TextColor3 = (n == name) and WHITE or GRAY end
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
            T("China Hat", "hat", rebuildAll, { S("Size", "hatSize", 0.5, 2, 0.05, rebuildAll), S("Spin Speed", "hatSpin", 0, 8, 0.1), T("Rainbow", "hatRainbow"), CL("Color", "hatColor") }),
            T("Halo", "halo", rebuildAll, { S("Height", "haloHeight", 0.6, 1.8, 0.05), T("Rainbow", "haloRainbow"), CL("Color", "haloColor") }),
            T("Orbiting Orbs", "orbs", rebuildAll, { S("Count", "orbCount", 2, 12, 1, rebuildAll), S("Radius", "orbRadius", 2, 6, 0.1), S("Speed", "orbSpeed", 0.2, 4, 0.1), T("Rainbow", "orbRainbow"), CL("Color", "orbColor") }),
            T("Ground Ring", "ring", rebuildAll, { S("Radius", "ringSize", 1.5, 7, 0.1), T("Rainbow", "ringRainbow"), CL("Color", "ringColor") }),
            T("Footsteps", "steps", nil, { T("Rainbow", "stepsRainbow"), CL("Color", "stepsColor") }),
            T("Rainbow Trail", "trail", setTrail),
            T("Aura Particles", "aura", setAura, { S("Density", "auraRate", 5, 100, 1, updateAura), CL("Color", "auraColor", setAura) }),
            T("Glow Outline", "glow", setGlow, { S("Fill", "glowFill", 0, 1, 0.05, updateGlow), CL("Color", "glowColor", updateGlow) }),
            T("Tool Glow", "toolGlow"),
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
    { name = "Misc", icon = "music", groups = {
        { name = "Music", features = {
            T("Player Widget", "music"),
            IN("Sound ID", "musicId", "rbxassetid number"),
            BT("Play", "play", function() HUD.playMusic(State.musicId) end),
            BT("Pause / Resume", "pause", HUD.toggleMusic),
            BT("Stop", "square", function() HUD.snd:Stop() HUD.musicTitle = "Nothing playing" end),
            S("Volume", "musicVol", 0, 1, 0.05, function(v) HUD.snd.Volume = v end),
            T("Loop", "musicLoop", function(v) HUD.snd.Looped = v end),
        } },
        { name = "Info", features = {
            LB("Paste an audio asset ID and press Play. Only assets the game is allowed to load will play."),
        } },
    } },
    { name = "Settings", icon = "settings", groups = {
        { name = "Menu", features = {
            S("Opacity", "menuTransp", 0, 0.6, 0.02, WIN.updateMenuOpacity),
            T("Background Blur", "menuBlur", nil, { S("Amount", "blurAmt", 2, 30, 1) }),
            T("Dim Background", "dim"),
            LB("Menu key: RightShift (or tap the Hiruku pill). Drag the top bar to move the window."),
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
        tween(n.btn, 0.15, { BackgroundTransparency = on and 0.9 or 1 })
        tween(n.label, 0.15, { TextColor3 = on and WHITE or GRAY })
        tintIcon(n.icon, on and WHITE or GRAY)
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
WIN.launcher = new("TextButton", {
    Name = "Launcher", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(112, 32),
    BackgroundColor3 = BLACK, BackgroundTransparency = 0.3, Text = "", AutoButtonColor = false, ZIndex = 10, Parent = gui,
})
corner(WIN.launcher, 16)
stroke(WIN.launcher, WHITE, 0.85)
WIN.lIc = icon(WIN.launcher, "eye", 14, WHITE)
WIN.lIc.Position = UDim2.new(0, 14, 0.5, -7)
WIN.lIc.ZIndex = 11
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), Text = "Hiruku", Font = Enum.Font.GothamBold,
    TextSize = 14, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = WIN.launcher,
})

-- dragging (window via top bar, launcher via itself)
function WIN.draggable(handle, target, onClick)
    local drag, moved, origin, startPos = false, false, nil, nil
    bind(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag, moved = true, false
            origin, startPos = input.Position, target.Position
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    drag = false
                    c:Disconnect()
                    if onClick and not moved then onClick() end
                end
            end)
        end
    end)
    bind(UIS.InputChanged, function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - origin
            if d.Magnitude > 5 then moved = true end
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
WIN.draggable(WIN.topbar, WIN.win)
WIN.draggable(WIN.launcher, WIN.launcher, function() WIN.setOpen(not WIN.menuOpen) end)
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
        stepFX(Real, t, air)
        stepReal(dt, t)
    end

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
    restoreWorld()
    if State.fovOn then cam().FieldOfView = origFov end
    if HUD.cursorHidden then UIS.MouseIconEnabled = true end
    fxFolder:Destroy()
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
