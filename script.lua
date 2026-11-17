-- Aimbot + ESP FOV + Lock + RGB (English)
getgenv().Aimbot = false
getgenv().ESP = false
getgenv().RGB = false
getgenv().FOV = 140
getgenv().LockedTargetName = nil

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ========== MENU ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AimESP"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = player:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 210, 0, 300)
Main.Position = UDim2.new(0.05, 0, 0.22, 0)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 32)
Title.BackgroundTransparency = 1
Title.Text = "Aimbot + ESP"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = Main

local function makeBtn(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.92, 0, 0, 30)
    b.Position = UDim2.new(0.04, 0, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.Parent = Main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local AimBtn = makeBtn("Aimbot: OFF", 40)
local EspBtn = makeBtn("ESP: OFF", 76)
local RGBBtn = makeBtn("RGB: OFF", 112)
local ClearBtn = makeBtn("Normal Mode", 148)
ClearBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 80)

local FovLabel = Instance.new("TextLabel")
FovLabel.Size = UDim2.new(0.92, 0, 0, 18)
FovLabel.Position = UDim2.new(0.04, 0, 0, 186)
FovLabel.BackgroundTransparency = 1
FovLabel.Text = "FOV: 140"
FovLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
FovLabel.Font = Enum.Font.Gotham
FovLabel.TextSize = 12
FovLabel.Parent = Main

local FovBtn = makeBtn("FOV: 80 / 140 / 200 / 260", 208)
FovBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)

local CloseBtn = makeBtn("Close Menu", 250)
CloseBtn.BackgroundColor3 = Color3.fromRGB(100, 35, 35)

local ListTitle = Instance.new("TextLabel")
ListTitle.Size = UDim2.new(0.92, 0, 0, 16)
ListTitle.Position = UDim2.new(0.04, 0, 0, 286)
ListTitle.BackgroundTransparency = 1
ListTitle.Text = "Players:"
ListTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
ListTitle.Font = Enum.Font.Gotham
ListTitle.TextSize = 11
ListTitle.TextXAlignment = Enum.TextXAlignment.Left
ListTitle.Parent = Main

local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Size = UDim2.new(0.92, 0, 0, 0)
ListFrame.Position = UDim2.new(0.04, 0, 0, 304)
ListFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
ListFrame.BorderSizePixel = 0
ListFrame.ScrollBarThickness = 3
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.Visible = false
ListFrame.Parent = Main
Instance.new("UICorner", ListFrame).CornerRadius = UDim.new(0, 6)

local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 42, 0, 42)
OpenBtn.Position = UDim2.new(0.05, 0, 0.2, 0)
OpenBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
OpenBtn.Text = "AE"
OpenBtn.TextColor3 = Color3.fromRGB(90, 255, 120)
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextSize = 13
OpenBtn.Visible = false
OpenBtn.Parent = ScreenGui
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 11)

-- FOV Circle
local FOVCircle = Instance.new("Frame")
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVCircle.Size = UDim2.new(0, 280, 0, 280)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Visible = false
FOVCircle.Parent = ScreenGui

local CircleStroke = Instance.new("UIStroke")
CircleStroke.Thickness = 1.8
CircleStroke.Color = Color3.fromRGB(0, 255, 200)
CircleStroke.Parent = FOVCircle
Instance.new("UICorner", FOVCircle).CornerRadius = UDim.new(1, 0)

-- ========== HELPERS ==========
local function getRoot(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
end

local function getHead(model)
    return model and (model:FindFirstChild("Head") or getRoot(model))
end

local function isLocal(model)
    return player.Character and model == player.Character
end

local function getAllTargets()
    local list = {}
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Health > 0 then
            local model = v.Parent
            if model and not isLocal(model) then
                local root = getRoot(model)
                local head = getHead(model)
                if root and head then
                    table.insert(list, {
                        model = model,
                        root = root,
                        head = head,
                        name = model.Name,
                        hum = v
                    })
                end
            end
        end
    end
    return list
end

local function isInFOV(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    if not onScreen then return false end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    return dist <= getgenv().FOV
end

local function getLockedModel()
    if not getgenv().LockedTargetName then return nil end
    for _, t in ipairs(getAllTargets()) do
        if t.name == getgenv().LockedTargetName then
            return t
        end
    end
    return nil
end

local function getBestTarget()
    local locked = getLockedModel()
    if locked then
        return locked.head
    end

    local myRoot = player.Character and getRoot(player.Character)
    if not myRoot then return nil end

    local closest, best = nil, math.huge
    for _, t in ipairs(getAllTargets()) do
        if isInFOV(t.head.Position) then
            local d = (myRoot.Position - t.head.Position).Magnitude
            if d < best then
                best = d
                closest = t.head
            end
        end
    end
    return closest
end

-- RGB
task.spawn(function()
    local hue = 0
    while true do
        if getgenv().RGB then
            hue = (hue + 0.008) % 1
            CircleStroke.Color = Color3.fromHSV(hue, 1, 1)
        else
            CircleStroke.Color = Color3.fromRGB(0, 255, 200)
        end
        task.wait(0.04)
    end
end)

local fovSteps = {80, 140, 200, 260, 320}
local fovIndex = 2

local function updateFOV()
    getgenv().FOV = fovSteps[fovIndex]
    FOVCircle.Size = UDim2.new(0, getgenv().FOV * 2, 0, getgenv().FOV * 2)
    FovLabel.Text = "FOV: " .. getgenv().FOV
    FovBtn.Text = "FOV: " .. getgenv().FOV
end

FovBtn.MouseButton1Click:Connect(function()
    fovIndex = (fovIndex % #fovSteps) + 1
    updateFOV()
end)

AimBtn.MouseButton1Click:Connect(function()
    getgenv().Aimbot = not getgenv().Aimbot
    AimBtn.Text = getgenv().Aimbot and "Aimbot: ON" or "Aimbot: OFF"
    AimBtn.BackgroundColor3 = getgenv().Aimbot and Color3.fromRGB(20, 130, 50) or Color3.fromRGB(38, 38, 48)
    FOVCircle.Visible = getgenv().Aimbot
end)

EspBtn.MouseButton1Click:Connect(function()
    getgenv().ESP = not getgenv().ESP
    EspBtn.Text = getgenv().ESP and "ESP: ON" or "ESP: OFF"
    EspBtn.BackgroundColor3 = getgenv().ESP and Color3.fromRGB(20, 130, 50) or Color3.fromRGB(38, 38, 48)
end)

RGBBtn.MouseButton1Click:Connect(function()
    getgenv().RGB = not getgenv().RGB
    RGBBtn.Text = getgenv().RGB and "RGB: ON" or "RGB: OFF"
    RGBBtn.BackgroundColor3 = getgenv().RGB and Color3.fromRGB(120, 50, 160) or Color3.fromRGB(38, 38, 48)
end)

ClearBtn.MouseButton1Click:Connect(function()
    getgenv().LockedTargetName = nil
    ClearBtn.Text = "Normal Mode"
    ClearBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 80)
end)

CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    OpenBtn.Visible = true
end)

OpenBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    OpenBtn.Visible = false
end)

task.spawn(function()
    while true do
        if Main.Visible then
            for _, c in pairs(ListFrame:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            local targets = getAllTargets()
            local y = 3
            for _, t in ipairs(targets) do
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -6, 0, 22)
                b.Position = UDim2.new(0, 3, 0, y)
                b.BackgroundColor3 = (getgenv().LockedTargetName == t.name) and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(45, 45, 55)
                b.Text = t.name
                b.TextColor3 = Color3.fromRGB(255, 255, 255)
                b.Font = Enum.Font.Gotham
                b.TextSize = 11
                b.Parent = ListFrame
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

                b.MouseButton1Click:Connect(function()
                    getgenv().LockedTargetName = t.name
                    ClearBtn.Text = "Locked: " .. t.name
                    ClearBtn.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
                end)
                y = y + 26
            end
            ListFrame.CanvasSize = UDim2.new(0, 0, 0, y + 4)
            ListFrame.Size = UDim2.new(0.92, 0, 0, math.min(y + 4, 110))
            ListFrame.Visible = #targets > 0
            Main.Size = UDim2.new(0, 210, 0, 310 + math.min(y, 110))
        end
        task.wait(1.2)
    end
end)

-- ========== AIMBOT ==========
RunService.RenderStepped:Connect(function()
    if not getgenv().Aimbot then return end
    local target = getBestTarget()
    if target then
        local camPos = Camera.CFrame.Position
        local goal = CFrame.new(camPos, target.Position)
        Camera.CFrame = Camera.CFrame:Lerp(goal, 0.45)
    end
end)

-- ========== ESP ==========
local espFolder = Instance.new("Folder")
espFolder.Name = "ESPFolder"
espFolder.Parent = ScreenGui

local function clearESP()
    for _, v in pairs(espFolder:GetChildren()) do
        v:Destroy()
    end
end

task.spawn(function()
    while true do
        clearESP()
        if getgenv().ESP then
            -- Líneas salen más arriba (cerca de "Tiempo restante")
            local lineOrigin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y * 0.12)
            local rgbColor = Color3.fromHSV((tick() % 6) / 6, 1, 1)

            for _, t in ipairs(getAllTargets()) do
                local screenPos, onScreen = Camera:WorldToViewportPoint(t.root.Position)
                if onScreen then
                    local col = getgenv().RGB and rgbColor or Color3.fromRGB(255, 70, 70)
                    if getgenv().LockedTargetName == t.name then
                        col = Color3.fromRGB(255, 40, 40)
                    end

                    local hl = Instance.new("Highlight")
                    hl.Adornee = t.model
                    hl.FillColor = col
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.62
                    hl.Parent = espFolder

                    local bb = Instance.new("BillboardGui")
                    bb.Adornee = t.root
                    bb.Size = UDim2.new(0, 130, 0, 24)
                    bb.AlwaysOnTop = true
                    bb.StudsOffset = Vector3.new(0, 3, 0)
                    bb.Parent = espFolder

                    local txt = Instance.new("TextLabel")
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.Text = t.name
                    txt.TextColor3 = col
                    txt.TextStrokeTransparency = 0.35
                    txt.Font = Enum.Font.GothamBold
                    txt.TextSize = 12
                    txt.Parent = bb

                    -- Line from top center
                    local pos = Vector2.new(screenPos.X, screenPos.Y)
                    local delta = pos - lineOrigin
                    local dist = math.max(delta.Magnitude, 1)
                    local angle = math.deg(math.atan2(delta.Y, delta.X))

                    local line = Instance.new("Frame")
                    line.AnchorPoint = Vector2.new(0, 0.5)
                    line.Position = UDim2.new(0, lineOrigin.X, 0, lineOrigin.Y)
                    line.Size = UDim2.new(0, dist, 0, 1.8)
                    line.Rotation = angle
                    line.BackgroundColor3 = col
                    line.BorderSizePixel = 0
                    line.Parent = espFolder
                end
            end
        end
        task.wait(0.35)
    end
end)

updateFOV()
print("Aimbot + ESP loaded")
