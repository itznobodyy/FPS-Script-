--[[  ZilikHub v8  |  Aimbot (persistent lock) + ESP/Skeleton
      Red menu · draggable FOV · bots · nearest-target selection · config saving
]]

if getgenv().ZilikHub then return end
getgenv().ZilikHub = true

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if workspace.CurrentCamera then Camera = workspace.CurrentCamera end
end)

--// ================= SETTINGS =================
local S = {
    Aimbot = false, HoldKey = false, AimToggle = false, AimKey = "MouseButton2",
    Smooth = 14, FOV = 140, FOVVisible = true,
    Style = 1, RGB = false, LockPart = "Head",
    TeamCheck = false, AliveCheck = true,
    ESP = false, Boxes = true, Tracers = true, Names = true,
    Health = true, Distance = true, HeadDot = false, Skeleton = false,
    ESPThick = 1.5, ESPTransp = 0.8, ESPTextSize = 14,
    Bots = false, MaxDist = 800, LookSens = 1, Grace = 0.55,
    IconX = 0.05, IconY = 0.14,
    Locked = nil
}
local DEFAULTS = {}
for k, v in pairs(S) do DEFAULTS[k] = v end

--// ================= CONFIG PERSISTENCE =================
local CONFIG_FILE = "ZilikHub_config.json"

local function saveConfig()
    local data = {}
    for k, v in pairs(S) do
        if k ~= "Locked" and DEFAULTS[k] ~= nil then data[k] = v end
    end
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
end

local saveQueued = false
local function queueSave()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.6, function()
        saveQueued = false
        saveConfig()
    end)
end

local function loadConfig()
    if not (isfile and isfile(CONFIG_FILE)) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if not ok or type(data) ~= "table" then return end
    for k, v in pairs(data) do
        if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then
            S[k] = v
        end
    end
end

loadConfig()

--// ================= THEME =================
local ACCENT      = Color3.fromRGB(214, 38, 52)
local ACCENT_DARK = Color3.fromRGB(110, 18, 28)
local BG          = Color3.fromRGB(13, 13, 16)
local PANEL       = Color3.fromRGB(22, 22, 27)
local ELEM        = Color3.fromRGB(34, 34, 41)
local ELEM_ON     = Color3.fromRGB(126, 22, 32)
local TXT         = Color3.fromRGB(236, 236, 240)
local DIM         = Color3.fromRGB(148, 148, 158)

local Refreshers, Conns = {}, {}

local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(Conns, c)
    return c
end

local function getRoot(m)
    if not m then return nil end
    return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso")
end
local function getHead(m)
    return m and (m:FindFirstChild("Head") or getRoot(m))
end
local function getHum(m)
    return m and m:FindFirstChildOfClass("Humanoid")
end
local function getPart(m, name)
    if not m then return nil end
    if name == "Head" then return getHead(m) end
    if name == "HumanoidRootPart" then return getRoot(m) end
    return m:FindFirstChild(name) or getRoot(m)
end

--// ================= BOTS =================
local BotCache = {}

task.spawn(function()
    while getgenv().ZilikHub do
        local list = {}
        if S.Bots then
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("Humanoid") and v.Health > 0 and v.Parent then
                    local m = v.Parent
                    if m ~= LP.Character and not Players:GetPlayerFromCharacter(m)
                        and m:FindFirstChild("HumanoidRootPart") and m:FindFirstChild("Head") then
                        list[m] = true
                    end
                end
            end
        end
        BotCache = list
        task.wait(0.4)
    end
end)

--// ================= TARGETS =================
local function buildEntry(model, name)
    local hum, root, head = getHum(model), getRoot(model), getHead(model)
    if hum and root and head then
        if S.AliveCheck and hum.Health <= 0 then return nil end
        return {model = model, hum = hum, root = root, head = head, name = name}
    end
    return nil
end

local function getAllTargets()
    local out = {}
    local myRoot = LP.Character and getRoot(LP.Character)

    for _, m in ipairs(Players:GetPlayers()) do
        if m ~= LP and m.Character then
            local e = buildEntry(m.Character, m.Name)
            if e then
                e.plr = m
                if S.TeamCheck and m.Team and LP.Team and m.Team == LP.Team then e = nil end
                if e and myRoot and (myRoot.Position - e.root.Position).Magnitude > S.MaxDist then e = nil end
                if e then table.insert(out, e) end
            end
        end
    end

    if S.Bots then
        for m in pairs(BotCache) do
            local e = buildEntry(m, m.Name)
            if e then
                if myRoot and (myRoot.Position - e.root.Position).Magnitude > S.MaxDist then e = nil end
                if e then table.insert(out, e) end
            end
        end
    end

    return out
end

local function screenDist(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    if not on or sp.Z <= 0 then return nil end
    local c = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return (Vector2.new(sp.X, sp.Y) - c).Magnitude
end

local function getLockedTarget()
    local L = S.Locked
    if not L then return nil end

    if L.type == "player" then
        local p = Players:FindFirstChild(L.name)
        if not p or not p.Character then return nil end
        local e = buildEntry(p.Character, p.Name)
        if e then e.plr = p end
        return e
    end

    local m = L.model
    if not m or not m.Parent then return nil end
    return buildEntry(m, m.Name)
end

local function getBestTarget()
    local locked = getLockedTarget()
    if locked then return locked end

    local myRoot = LP.Character and getRoot(LP.Character)
    if not myRoot then return nil end

    local best, bestD = nil, math.huge
    for _, t in ipairs(getAllTargets()) do
        local part = getPart(t.model, S.LockPart) or t.head
        local sd = screenDist(part.Position)
        if sd and sd <= S.FOV then
            local d = (myRoot.Position - t.root.Position).Magnitude
            if d < bestD then bestD, best = d, t end
        end
    end
    return best
end

--// ================= UI =================
local Gui = Instance.new("ScreenGui")
Gui.Name = "ZilikHub"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
pcall(function() Gui.Parent = game:GetService("CoreGui") end)
if not Gui.Parent then Gui.Parent = LP:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 252, 0, 392)
Main.Position = UDim2.new(0.05, 0, 0.14, 0)
Main.BackgroundColor3 = BG
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = ACCENT_DARK
MainStroke.Thickness = 1

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 3)
TopBar.BackgroundColor3 = ACCENT
TopBar.BorderSizePixel = 0
TopBar.Parent = Main
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 0, 32)
Title.Position = UDim2.new(0, 12, 0, 6)
Title.BackgroundTransparency = 1
Title.Text = "ZilikHub"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextColor3 = TXT
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.Parent = Main

local Sub = Instance.new("TextLabel")
Sub.Size = UDim2.new(1, -16, 0, 14)
Sub.Position = UDim2.new(0, 12, 0, 34)
Sub.BackgroundTransparency = 1
Sub.Text = "Aimbot · ESP · Skeleton"
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.TextColor3 = DIM
Sub.Font = Enum.Font.Gotham
Sub.TextSize = 10
Sub.Parent = Main

local XBtn = Instance.new("TextButton")
XBtn.Size = UDim2.new(0, 22, 0, 22)
XBtn.Position = UDim2.new(1, -30, 0, 12)
XBtn.BackgroundColor3 = ACCENT_DARK
XBtn.BorderSizePixel = 0
XBtn.Text = "X"
XBtn.TextColor3 = TXT
XBtn.Font = Enum.Font.GothamBold
XBtn.TextSize = 12
XBtn.AutoButtonColor = false
XBtn.Parent = Main
Instance.new("UICorner", XBtn).CornerRadius = UDim.new(0, 6)
XBtn.MouseEnter:Connect(function() XBtn.BackgroundColor3 = ACCENT end)
XBtn.MouseLeave:Connect(function() XBtn.BackgroundColor3 = ACCENT_DARK end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 26)
TabBar.Position = UDim2.new(0, 10, 0, 50)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Main
local TabLayout = Instance.new("UIListLayout", TabBar)
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 5)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -12, 0, 300)
Content.Position = UDim2.new(0, 6, 0, 80)
Content.BackgroundColor3 = PANEL
Content.BorderSizePixel = 0
Content.Parent = Main
Instance.new("UICorner", Content).CornerRadius = UDim.new(0, 8)

-- floating ghost icon
local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 44, 0, 44)
OpenBtn.Position = UDim2.new(S.IconX, 0, S.IconY, 0)
OpenBtn.BackgroundColor3 = BG
OpenBtn.Text = "👻"
OpenBtn.TextColor3 = TXT
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextSize = 22
OpenBtn.AutoButtonColor = false
OpenBtn.Visible = false
OpenBtn.Parent = Gui
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 12)
local OpenStroke = Instance.new("UIStroke", OpenBtn)
OpenStroke.Color = ACCENT_DARK

local FOVCircle = Instance.new("Frame")
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVCircle.Size = UDim2.new(0, 280, 0, 280)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Visible = false
FOVCircle.Parent = Gui
Instance.new("UICorner", FOVCircle).CornerRadius = UDim.new(1, 0)
local CircleStroke = Instance.new("UIStroke", FOVCircle)
CircleStroke.Thickness = 1.6
CircleStroke.Color = ACCENT

--// ================= COMPONENTS =================
local function makePage()
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = ACCENT_DARK
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.Visible = false
    p.Parent = Content
    local pad = Instance.new("UIPadding", p)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.PaddingTop = UDim.new(0, 8)
    local lay = Instance.new("UIListLayout", p)
    lay.Padding = UDim.new(0, 5)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 12)
    end)
    return p
end

local function makeToggle(parent, text, key)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 28)
    b.BackgroundColor3 = ELEM
    b.BorderSizePixel = 0
    b.Text = "  " .. text
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextColor3 = TXT
    b.Font = Enum.Font.Gotham
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(1, -16, 0.5, -4)
    dot.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    dot.Parent = b
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local function refresh()
        local on = S[key]
        b.BackgroundColor3 = on and ELEM_ON or ELEM
        dot.BackgroundColor3 = on and ACCENT or Color3.fromRGB(70, 70, 80)
    end
    table.insert(Refreshers, refresh)

    b.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        refresh()
        queueSave()
        if key == "Aimbot" then
            FOVCircle.Visible = S.Aimbot and S.FOVVisible
            AimHeld = S.Aimbot
        end
    end)
    refresh()
    return b
end

local function makeCycle(parent, text, key, values, label)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 28)
    b.BackgroundColor3 = ELEM
    b.BorderSizePixel = 0
    b.TextColor3 = TXT
    b.Font = Enum.Font.Gotham
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)

    local idx = 1
    for i, v in ipairs(values) do if v == S[key] then idx = i end end
    local function refresh() b.Text = "  " .. text .. ": " .. label(values[idx]) end
    table.insert(Refreshers, refresh)

    b.MouseButton1Click:Connect(function()
        idx = (idx % #values) + 1
        S[key] = values[idx]
        refresh()
        queueSave()
    end)
    refresh()
    return b
end

local function makeSlider(parent, text, key, min, max, step, suffix)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -16, 0, 44)
    row.BackgroundColor3 = ELEM
    row.BackgroundTransparency = 0.4
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 0, 16)
    lbl.Position = UDim2.new(0, 8, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = TXT
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 6)
    track.Position = UDim2.new(0, 10, 0, 28)
    track.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = ACCENT
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = TXT
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function paint()
        local a = math.clamp((S[key] - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        local shown = step < 1 and string.format("%.2f", S[key]) or tostring(math.floor(S[key]))
        lbl.Text = "  " .. text .. ": " .. shown .. (suffix or "")
    end
    table.insert(Refreshers, paint)

    local dragging = false
    local function fromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = min + (max - min) * rel
        v = math.floor(v / step + 0.5) * step
        S[key] = math.clamp(v, min, max)
        paint()
    end

    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(i.Position.X)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch then
            fromX(i.Position.X)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            if dragging then queueSave() end
            dragging = false
        end
    end)

    paint()
    return row
end

local function makeButton(parent, text, color, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 28)
    b.BackgroundColor3 = color or ELEM
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = TXT
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.AutoButtonColor = true
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(cb)
    return b
end

local function makeHeader(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 0, 20)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = ACCENT
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.Parent = parent
    return l
end

--// ================= TABS =================
local TabBtns = {}
local function addTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 56, 0, 24)
    btn.BackgroundColor3 = ELEM
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = DIM
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 10
    btn.LayoutOrder = order
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local page = makePage()
    table.insert(TabBtns, {btn = btn, page = page})

    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(TabBtns) do
            t.page.Visible = (t.page == page)
            t.btn.BackgroundColor3 = (t.page == page) and ELEM_ON or ELEM
            t.btn.TextColor3 = (t.page == page) and TXT or DIM
        end
    end)
    return page
end

local AimPage = addTab("Aimbot", 1)
local VisPage = addTab("Visuals", 2)
local TgtPage = addTab("Target", 3)
local SetPage = addTab("Settings", 4)

--// Aimbot
makeHeader(AimPage, "AIMBOT")
makeToggle(AimPage, "Aimbot", "Aimbot")

local TargetLabel = Instance.new("TextLabel")
TargetLabel.Size = UDim2.new(1, -16, 0, 16)
TargetLabel.BackgroundTransparency = 1
TargetLabel.Text = "Aiming at: —"
TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetLabel.TextColor3 = ACCENT
TargetLabel.Font = Enum.Font.Gotham
TargetLabel.TextSize = 10
TargetLabel.Parent = AimPage

makeHeader(AimPage, "RANGE / FOV")
makeSlider(AimPage, "FOV (radius)", "FOV", 40, 500, 5, " px")
makeToggle(AimPage, "FOV Visible", "FOVVisible")

makeHeader(AimPage, "BEHAVIOUR")
makeToggle(AimPage, "Hold Key", "HoldKey")
makeToggle(AimPage, "Toggle Mode", "AimToggle")
makeCycle(AimPage, "Hotkey", "AimKey", {"MouseButton2", "E", "Q", "LeftAlt", "CapsLock"}, function(v) return v end)
makeCycle(AimPage, "Lock Part", "LockPart", {"Head", "HumanoidRootPart", "Torso", "UpperTorso"}, function(v) return v end)
makeSlider(AimPage, "Smooth (speed)", "Smooth", 4, 40, 1)

--// Visuals
makeHeader(VisPage, "ESP MASTER")
makeToggle(VisPage, "ESP", "ESP")
makeHeader(VisPage, "ELEMENTS")
makeToggle(VisPage, "Boxes", "Boxes")
makeToggle(VisPage, "Tracers", "Tracers")
makeToggle(VisPage, "Names", "Names")
makeToggle(VisPage, "Health Bar", "Health")
makeToggle(VisPage, "Distance", "Distance")
makeToggle(VisPage, "Head Dot", "HeadDot")
makeToggle(VisPage, "Skeleton", "Skeleton")
makeHeader(VisPage, "STYLE")
makeCycle(VisPage, "Style", "Style", {1, 2, 3}, function(v)
    return v == 1 and "Lines + Box" or v == 2 and "Lines" or "Box"
end)
makeToggle(VisPage, "RGB", "RGB")
makeSlider(VisPage, "Thickness", "ESPThick", 1, 4, 0.5)
makeSlider(VisPage, "Transparency", "ESPTransp", 0.1, 1, 0.05)
makeSlider(VisPage, "Text Size", "ESPTextSize", 8, 22, 1)

--// Target
makeHeader(TgtPage, "TARGET")
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -16, 0, 26)
SearchBox.BackgroundColor3 = ELEM
SearchBox.BorderSizePixel = 0
SearchBox.PlaceholderText = "Search player / bot..."
SearchBox.Text = ""
SearchBox.TextColor3 = TXT
SearchBox.PlaceholderColor3 = DIM
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 11
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = TgtPage
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 5)

makeButton(TgtPage, "Normal Mode (release target)", Color3.fromRGB(52, 52, 62), function()
    S.Locked = nil
end)

local LockLabel = Instance.new("TextLabel")
LockLabel.Size = UDim2.new(1, -16, 0, 16)
LockLabel.BackgroundTransparency = 1
LockLabel.Text = "Target: none"
LockLabel.TextXAlignment = Enum.TextXAlignment.Left
LockLabel.TextColor3 = DIM
LockLabel.Font = Enum.Font.Gotham
LockLabel.TextSize = 10
LockLabel.Parent = TgtPage

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(1, -16, 0, 170)
PlayerList.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
PlayerList.BorderSizePixel = 0
PlayerList.ScrollBarThickness = 3
PlayerList.ScrollBarImageColor3 = ACCENT_DARK
PlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerList.Parent = TgtPage
Instance.new("UICorner", PlayerList).CornerRadius = UDim.new(0, 5)
local PlistLayout = Instance.new("UIListLayout", PlayerList)
PlistLayout.Padding = UDim.new(0, 3)
PlistLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function lockName()
    local L = S.Locked
    if not L then return "none" end
    if L.type == "bot" then return "[BOT] " .. L.name end
    return L.name
end

local function refreshList()
    if not TgtPage.Visible then return end
    for _, c in ipairs(PlayerList:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
    end

    local myRoot = LP.Character and getRoot(LP.Character)
    local q = string.lower(SearchBox.Text)
    local list = {}

    for _, t in ipairs(getAllTargets()) do
        local d = myRoot and math.floor((myRoot.Position - t.root.Position).Magnitude) or 0
        local isBot = not t.plr
        if q == "" or string.find(string.lower(t.name), q, 1, true) then
            table.insert(list, {name = t.name, dist = d, bot = isBot, model = t.model})
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)

    local y = 0
    for _, e in ipairs(list) do
        local selected = S.Locked and (
            (S.Locked.type == "bot" and S.Locked.model == e.model) or
            (S.Locked.type == "player" and S.Locked.name == e.name))
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 24)
        b.Position = UDim2.new(0, 3, 0, y)
        b.BackgroundColor3 = selected and Color3.fromRGB(150, 26, 38) or ELEM
        b.BorderSizePixel = 0
        b.Text = "  " .. (e.bot and "[BOT] " or "") .. e.name .. "   [" .. e.dist .. "m]"
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.TextColor3 = TXT
        b.Font = Enum.Font.Gotham
        b.TextSize = 10
        b.Parent = PlayerList
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.MouseButton1Click:Connect(function()
            if e.bot then
                S.Locked = {type = "bot", name = e.name, model = e.model}
            else
                S.Locked = {type = "player", name = e.name}
            end
            refreshList()
        end)
        y = y + 27
    end

    PlayerList.CanvasSize = UDim2.new(0, 0, 0, y + 4)
    LockLabel.Text = "Target: " .. lockName()

    if #list == 0 then
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -6, 0, 24)
        l.BackgroundTransparency = 1
        l.Text = S.Bots and "No targets" or "No players (enable Bots in Settings)"
        l.TextColor3 = DIM
        l.Font = Enum.Font.Gotham
        l.TextSize = 10
        l.Parent = PlayerList
    end
end
SearchBox:GetPropertyChangedSignal("Text"):Connect(refreshList)

task.spawn(function()
    while getgenv().ZilikHub do
        refreshList()
        task.wait(1)
    end
end)

--// Settings
makeHeader(SetPage, "TARGETS")
makeToggle(SetPage, "Include Bots / NPCs (aim + ESP)", "Bots")
makeSlider(SetPage, "Max Distance", "MaxDist", 50, 2000, 25, "m")
makeHeader(SetPage, "CHECKS")
makeToggle(SetPage, "Team Check", "TeamCheck")
makeToggle(SetPage, "Alive Check", "AliveCheck")
makeHeader(SetPage, "CAMERA")
makeSlider(SetPage, "Look Sensitivity", "LookSens", 0.2, 3, 0.1, "x")
makeSlider(SetPage, "Re-engage Delay", "Grace", 0.1, 1.5, 0.05, "s")
makeHeader(SetPage, "SYSTEM")
makeButton(SetPage, "Reset Settings", Color3.fromRGB(52, 52, 62), function()
    for k, v in pairs(DEFAULTS) do S[k] = v end
    S.Locked = nil
    for _, f in ipairs(Refreshers) do pcall(f) end
    FOVCircle.Visible = false
    queueSave()
end)
makeButton(SetPage, "Clear ESP Cache", Color3.fromRGB(52, 52, 62), function()
    for _, d in pairs(ESPCache) do removeESP(d) end
    ESPCache = {}
end)
makeButton(SetPage, "Close Menu", ACCENT_DARK, function()
    Main.Visible = false
    OpenBtn.Visible = true
end)
makeButton(SetPage, "Unload", Color3.fromRGB(110, 24, 30), function()
    saveConfig()
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    pcall(function() RunService:UnbindFromRenderStep("ZilikAim") end)
    for _, d in pairs(ESPCache) do removeESP(d) end
    pcall(function() UIS.MouseDeltaSensitivity = OrigSens end)
    FOVCircle:Destroy()
    Gui:Destroy()
    getgenv().ZilikHub = nil
end)

-- credits card
local Credit = Instance.new("Frame")
Credit.Size = UDim2.new(1, -16, 0, 66)
Credit.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Credit.BorderSizePixel = 0
Credit.Parent = SetPage
Instance.new("UICorner", Credit).CornerRadius = UDim.new(0, 6)
local CreditStroke = Instance.new("UIStroke", Credit)
CreditStroke.Color = ACCENT_DARK
CreditStroke.Thickness = 1

local CreditBar = Instance.new("Frame")
CreditBar.Size = UDim2.new(0, 3, 1, -16)
CreditBar.Position = UDim2.new(0, 8, 0, 8)
CreditBar.BackgroundColor3 = ACCENT
CreditBar.BorderSizePixel = 0
CreditBar.Parent = Credit
Instance.new("UICorner", CreditBar).CornerRadius = UDim.new(1, 0)

local ByLbl = Instance.new("TextLabel")
ByLbl.Size = UDim2.new(1, -24, 0, 14)
ByLbl.Position = UDim2.new(0, 18, 0, 8)
ByLbl.BackgroundTransparency = 1
ByLbl.Text = "EXPLOIT BY"
ByLbl.TextXAlignment = Enum.TextXAlignment.Left
ByLbl.TextColor3 = DIM
ByLbl.Font = Enum.Font.Gotham
ByLbl.TextSize = 9
ByLbl.Parent = Credit

local ByName = Instance.new("TextLabel")
ByName.Size = UDim2.new(1, -24, 0, 18)
ByName.Position = UDim2.new(0, 18, 0, 20)
ByName.BackgroundTransparency = 1
ByName.Text = "iTzDrigoo"
ByName.TextXAlignment = Enum.TextXAlignment.Left
ByName.TextColor3 = ACCENT
ByName.Font = Enum.Font.GothamBold
ByName.TextSize = 14
ByName.Parent = Credit

local ClientLbl = Instance.new("TextLabel")
ClientLbl.Size = UDim2.new(1, -24, 0, 14)
ClientLbl.Position = UDim2.new(0, 18, 0, 40)
ClientLbl.BackgroundTransparency = 1
ClientLbl.Text = "CLIENT"
ClientLbl.TextXAlignment = Enum.TextXAlignment.Left
ClientLbl.TextColor3 = DIM
ClientLbl.Font = Enum.Font.Gotham
ClientLbl.TextSize = 9
ClientLbl.Parent = Credit

local ClientName = Instance.new("TextLabel")
ClientName.Size = UDim2.new(1, -24, 0, 18)
ClientName.Position = UDim2.new(0, 18, 0, 52)
ClientName.BackgroundTransparency = 1
ClientName.Text = LP.DisplayName .. " (@" .. LP.Name .. ")"
ClientName.TextXAlignment = Enum.TextXAlignment.Left
ClientName.TextColor3 = TXT
ClientName.Font = Enum.Font.GothamMedium
ClientName.TextSize = 11
ClientName.Parent = Credit

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(1, -16, 0, 18)
Info.BackgroundTransparency = 1
Info.Text = "ZilikHub v8 · config saved automatically"
Info.TextColor3 = DIM
Info.Font = Enum.Font.Gotham
Info.TextSize = 9
Info.Parent = SetPage

--// buttons
XBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    OpenBtn.Visible = true
end)

--// ghost icon: drag + click
local iconDrag, iconMoved = false, 0
OpenBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
        iconDrag = true
        iconMoved = 0
    end
end)
bind(UIS.InputChanged, function(i)
    if not iconDrag then return end
    if i.UserInputType ~= Enum.UserInputType.MouseMovement
        and i.UserInputType ~= Enum.UserInputType.Touch then return end
    iconMoved = iconMoved + (i.Delta and i.Delta.Magnitude or 0)
    local vp = Camera.ViewportSize
    S.IconX = math.clamp((i.Position.X - 22) / vp.X, 0, 1)
    S.IconY = math.clamp((i.Position.Y - 22) / vp.Y, 0, 1)
    OpenBtn.Position = UDim2.new(S.IconX, 0, S.IconY, 0)
end)
bind(UIS.InputEnded, function(i)
    if not iconDrag then return end
    if i.UserInputType ~= Enum.UserInputType.MouseButton1
        and i.UserInputType ~= Enum.UserInputType.Touch then return end
    iconDrag = false
    if iconMoved < 6 then
        Main.Visible = true
        OpenBtn.Visible = false
    else
        queueSave()
    end
end)

TabBtns[1].page.Visible = true
TabBtns[1].btn.BackgroundColor3 = ELEM_ON
TabBtns[1].btn.TextColor3 = TXT

for _, f in ipairs(Refreshers) do pcall(f) end

--// ================= AIMBOT =================
local DEADZONE = math.rad(0.12)
local LOOK_SENS = 0.0026

local AimHeld = false
local Typing = false
local OrigSens = UIS.MouseDeltaSensitivity
local SensZeroed = false
local AimRot = nil
local LastCF = nil
local LastMouse = 0

local function zeroSens()
    if not SensZeroed then
        OrigSens = UIS.MouseDeltaSensitivity
        if OrigSens <= 0 then OrigSens = 1 end
        UIS.MouseDeltaSensitivity = 0
        SensZeroed = true
    end
end
local function restoreSens()
    if SensZeroed then
        UIS.MouseDeltaSensitivity = OrigSens
        SensZeroed = false
    end
end
local function resetAim()
    AimRot = nil
    LastCF = nil
    restoreSens()
    TargetLabel.Text = "Aiming at: —"
end

local function aimActive()
    if not S.Aimbot then return false end
    if S.HoldKey then return AimHeld end
    return true
end

bind(UIS.TextBoxFocused, function() Typing = true end)
bind(UIS.TextBoxFocusReleased, function() Typing = false end)

local function keyMatches(i)
    return i.UserInputType.Name == S.AimKey or i.KeyCode.Name == S.AimKey
end

bind(UIS.InputBegan, function(i, gp)
    if gp or Typing then return end
    if keyMatches(i) then
        if S.AimToggle then AimHeld = not AimHeld else AimHeld = true end
    end
end)
bind(UIS.InputEnded, function(i)
    if keyMatches(i) and not S.AimToggle then AimHeld = false end
end)

bind(UIS.InputChanged, function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    if not aimActive() then return end
    LastMouse = tick()
    if not AimRot then return end
    local d = i.Delta
    local f = LOOK_SENS * S.LookSens * (OrigSens > 0 and OrigSens or 1)
    AimRot = (CFrame.Angles(0, -d.X * f, 0) * AimRot) * CFrame.Angles(-d.Y * f, 0, 0)
    LastCF = CFrame.new(Camera.CFrame.Position) * AimRot
    Camera.CFrame = LastCF
end)

--// ================= ESP =================
local ESPCache = {}

local R15_BONES = {
    {"Head",false,"UpperTorso",false},
    {"UpperTorso",false,"LowerTorso",false},
    {"UpperTorso",false,"LeftUpperArm",false},{"LeftUpperArm",false,"LeftLowerArm",false},{"LeftLowerArm",false,"LeftHand",false},
    {"UpperTorso",false,"RightUpperArm",false},{"RightUpperArm",false,"RightLowerArm",false},{"RightLowerArm",false,"RightHand",false},
    {"LowerTorso",false,"LeftUpperLeg",false},{"LeftUpperLeg",false,"LeftLowerLeg",false},{"LeftLowerLeg",false,"LeftFoot",false},
    {"LowerTorso",false,"RightUpperLeg",false},{"RightUpperLeg",false,"RightLowerLeg",false},{"RightLowerLeg",false,"RightFoot",false}
}
local R6_BONES = {
    {"Head",false,"Torso",false},
    {"Torso",false,"Left Arm",false},{"Left Arm",false,"Left Arm",true},
    {"Torso",false,"Right Arm",false},{"Right Arm",false,"Right Arm",true},
    {"Torso",false,"Left Leg",false},{"Left Leg",false,"Left Leg",true},
    {"Torso",false,"Right Leg",false},{"Right Leg",false,"Right Leg",true}
}
local MAXBONES = 16

local function createESP()
    local e = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = S.ESPThick
        l.Transparency = S.ESPTransp
        l.Visible = false
        e["box" .. i] = l
    end
    e.tracer = Drawing.new("Line")
    e.tracer.Thickness = S.ESPThick
    e.tracer.Transparency = S.ESPTransp
    e.tracer.Visible = false

    e.name = Drawing.new("Text")
    e.name.Center = true
    e.name.Outline = true
    e.name.Font = 2
    e.name.Visible = false

    e.hpOut = Drawing.new("Square")
    e.hpOut.Thickness = 1
    e.hpOut.Visible = false
    e.hpFill = Drawing.new("Square")
    e.hpFill.Filled = true
    e.hpFill.Visible = false

    e.dot = Drawing.new("Circle")
    e.dot.Filled = false
    e.dot.NumSides = 30
    e.dot.Visible = false

    e.bones = {}
    for i = 1, MAXBONES do
        local l = Drawing.new("Line")
        l.Thickness = 1.2
        l.Transparency = S.ESPTransp
        l.Visible = false
        e.bones[i] = l
    end

    return e
end

local function removeESP(e)
    for _, v in pairs(e) do
        if type(v) == "table" then
            for _, q in pairs(v) do pcall(function() q:Remove() end) end
        else
            pcall(function() v:Remove() end)
        end
    end
end

local function hideESP(e)
    for _, v in pairs(e) do
        if type(v) == "table" then
            for _, q in pairs(v) do q.Visible = false end
        else
            v.Visible = false
        end
    end
end

local function bonePoint(model, name, bottom)
    local p = model:FindFirstChild(name)
    if not p or not p:IsA("BasePart") then return nil end
    if bottom then
        return (p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)).Position
    end
    return p.Position
end

local function drawSkeleton(e, model, col, transp)
    local bones = model:FindFirstChild("LowerTorso") and R15_BONES or R6_BONES
    local n = 0
    for _, bone in ipairs(bones) do
        n = n + 1
        if n > MAXBONES then break end
        local line = e.bones[n]
        local a = bonePoint(model, bone[1], bone[2])
        local b = bonePoint(model, bone[3], bone[4])
        if a and b then
            local sa, onA = Camera:WorldToViewportPoint(a)
            local sb, onB = Camera:WorldToViewportPoint(b)
            if onA and onB and sa.Z > 0 and sb.Z > 0 then
                line.From = Vector2.new(sa.X, sa.Y)
                line.To = Vector2.new(sb.X, sb.Y)
                line.Color = col
                line.Thickness = math.max(S.ESPThick * 0.9, 1)
                line.Transparency = transp
                line.Visible = true
            end
        end
    end
end

local function isLockedModel(t)
    local L = S.Locked
    if not L then return false end
    if L.type == "bot" then return L.model == t.model end
    return L.name == t.name and t.plr ~= nil
end

local function updateESP()
    local targets = getAllTargets()
    local aliveSet = {}

    if not S.ESP then
        for _, e in pairs(ESPCache) do hideESP(e) end
        return
    end

    local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    local hue = (tick() % 6) / 6
    local myRoot = LP.Character and getRoot(LP.Character)

    for _, t in ipairs(targets) do
        aliveSet[t.model] = true
        local e = ESPCache[t.model]
        if not e then
            e = createESP()
            ESPCache[t.model] = e
        end
        hideESP(e)

        local headPos, onH = Camera:WorldToViewportPoint(t.head.Position + Vector3.new(0, 0.6, 0))
        local rootPos, onR = Camera:WorldToViewportPoint(t.root.Position - Vector3.new(0, 2.9, 0))
        if onH and onR and headPos.Z > 0 and rootPos.Z > 0 then
            local col = Color3.fromRGB(235, 235, 235)
            if S.RGB then col = Color3.fromHSV(hue, 1, 1) end
            if isLockedModel(t) then col = Color3.fromRGB(255, 55, 55) end

            local height = math.max(math.abs(rootPos.Y - headPos.Y), 22)
            local width = height / 2
            local cx = headPos.X
            local topY, botY = headPos.Y, headPos.Y + height

            if S.Boxes and S.Style ~= 2 then
                local tl, tr = Vector2.new(cx - width / 2, topY), Vector2.new(cx + width / 2, topY)
                local bl, br = Vector2.new(cx - width / 2, botY), Vector2.new(cx + width / 2, botY)
                e.box1.From, e.box1.To = tl, tr
                e.box2.From, e.box2.To = bl, br
                e.box3.From, e.box3.To = tl, bl
                e.box4.From, e.box4.To = tr, br
                for i = 1, 4 do
                    local l = e["box" .. i]
                    l.Color = col
                    l.Thickness = S.ESPThick
                    l.Transparency = S.ESPTransp
                    l.Visible = true
                end
            end

            if S.Tracers and S.Style ~= 3 then
                e.tracer.From = origin
                e.tracer.To = Vector2.new(cx, botY)
                e.tracer.Color = col
                e.tracer.Thickness = S.ESPThick
                e.tracer.Transparency = S.ESPTransp
                e.tracer.Visible = true
            end

            if S.Names and S.Style ~= 2 then
                local label = (t.plr and t.name) or ("[BOT] " .. t.name)
                if S.Distance and myRoot then
                    label = label .. " [" .. math.floor((myRoot.Position - t.root.Position).Magnitude) .. "m]"
                end
                e.name.Text = label
                e.name.Position = Vector2.new(cx, topY - S.ESPTextSize - 4)
                e.name.Size = S.ESPTextSize
                e.name.Color = col
                e.name.Transparency = S.ESPTransp
                e.name.Visible = true
            end

            if S.Health then
                local hp = math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1)
                local barW, barX = 3, cx - width / 2 - 6
                e.hpOut.Size = Vector2.new(barW, height)
                e.hpOut.Position = Vector2.new(barX, topY)
                e.hpOut.Color = Color3.fromRGB(10, 10, 10)
                e.hpOut.Transparency = 0.35
                e.hpOut.Visible = true
                e.hpFill.Size = Vector2.new(barW, height * hp)
                e.hpFill.Position = Vector2.new(barX, topY + (height * (1 - hp)))
                e.hpFill.Color = Color3.fromRGB(math.floor(255 * (1 - hp)), math.floor(255 * hp), 70)
                e.hpFill.Transparency = 0.25
                e.hpFill.Visible = true
            end

            if S.HeadDot then
                local dp, onD = Camera:WorldToViewportPoint(t.head.Position)
                if onD then
                    e.dot.Position = Vector2.new(dp.X, dp.Y)
                    e.dot.Radius = 7
                    e.dot.Thickness = 1.5
                    e.dot.Color = col
                    e.dot.Transparency = S.ESPTransp
                    e.dot.Visible = true
                end
            end

            if S.Skeleton then drawSkeleton(e, t.model, col, 0.75) end
        end
    end

    for model, e in pairs(ESPCache) do
        if not aliveSet[model] then
            removeESP(e)
            ESPCache[model] = nil
        end
    end
end

--// ================= VISUAL LOOP =================
bind(RunService.RenderStepped, function()
    local hue = (tick() % 6) / 6
    CircleStroke.Color = S.RGB and Color3.fromHSV(hue, 1, 1) or ACCENT
    FOVCircle.Visible = S.Aimbot and S.FOVVisible
    FOVCircle.Size = UDim2.new(0, S.FOV * 2, 0, S.FOV * 2)
    updateESP()

    if aimActive() and LastCF then Camera.CFrame = LastCF end
end)

--// ================= AIM LOOP =================
RunService:BindToRenderStep("ZilikAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not aimActive() then
        if AimRot then resetAim() end
        return
    end

    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        if AimRot then resetAim() end
        return
    end

    if S.Locked and not getLockedTarget() then
        TargetLabel.Text = "Target: " .. lockName() .. " (waiting)"
    end

    local t = getBestTarget()
    if not t then
        if AimRot then resetAim() else TargetLabel.Text = "Aiming at: —" end
        return
    end

    local part = getPart(t.model, S.LockPart) or t.head
    if not part then return end

    TargetLabel.Text = "Aiming at: " .. ((t.plr and t.name) or ("[BOT] " .. t.name))

    local camPos = Camera.CFrame.Position
    if not AimRot then
        AimRot = Camera.CFrame - camPos
        zeroSens()
    end

    if tick() - LastMouse < S.Grace then
        LastCF = CFrame.new(camPos) * AimRot
        Camera.CFrame = LastCF
        return
    end

    local tgtRot = CFrame.lookAt(camPos, part.Position) - camPos
    local ang = math.acos(math.clamp(AimRot.LookVector:Dot(tgtRot.LookVector), -1, 1))

    if ang > DEADZONE then
        local alpha = 1 - math.exp(-S.Smooth * dt)
        local since = tick() - LastMouse
        if since < S.Grace + 0.35 then alpha = alpha * 0.45 end
        if ang < math.rad(4) then alpha = math.max(alpha, 0.6) end
        if ang < math.rad(1) then alpha = 1 end
        AimRot = AimRot:Lerp(tgtRot, math.clamp(alpha, 0, 1))
    else
        AimRot = tgtRot
    end

    LastCF = CFrame.new(camPos) * AimRot
    Camera.CFrame = LastCF
end)

FOVCircle.Visible = false
saveConfig()
print("ZilikHub v8 loaded")
