local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local PrevState = getgenv and getgenv().HEAD_HITBOX_STATE or nil
if PrevState then
    if PrevState.restoreAll then
        pcall(PrevState.restoreAll)
    end
    for _, c in ipairs(PrevState.connections or {}) do
        pcall(function() c:Disconnect() end)
    end
    local oldGui = PrevState.gui
    if oldGui and oldGui.Parent then
        pcall(function() oldGui:Destroy() end)
    end
end

local Connections = {}
local State = {
    connections = Connections,
    gui = nil,
    restoreAll = nil,
}

local function Connect(signal, fn)
    local c = signal:Connect(fn)
    Connections[#Connections + 1] = c
    return c
end

local Settings = {
    Enabled = true,
    HeadSize = 1.0,
    Transparency = 0.5,
}

local OriginalProps = setmetatable({}, { __mode = "k" })

local TargetVec = Vector3.new(Settings.HeadSize, Settings.HeadSize, Settings.HeadSize)
local function UpdateTargetVec()
    TargetVec = Vector3.new(Settings.HeadSize, Settings.HeadSize, Settings.HeadSize)
end

local function GetHeadPart(char)
    if not char then return nil end
    return char:FindFirstChild("Head")
        or char:FindFirstChild("Headbox")
        or char:FindFirstChild("Hitbox")
        or char:FindFirstChild("HumanoidRootPart")
end

local function GetAliveTarget(player)
    local char = player.Character
    if not char or not char.Parent then
        return false, nil
    end

    local head = GetHeadPart(char)
    if not head or not head:IsA("BasePart") then
        return false, nil
    end

    local dead = char:GetAttribute("Dead")
    if dead == nil then
        dead = player:GetAttribute("Dead")
    end
    if dead == true or dead == 1 then
        return false, nil
    end

    local attrHealth = char:GetAttribute("Health") or player:GetAttribute("Health")
    if type(attrHealth) == "number" and attrHealth <= 0 then
        return false, nil
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MaxHealth > 0 and hum.Health <= 0 then
        return false, nil
    end

    return true, head
end

local function IsTeammate(player)
    local myChar = LocalPlayer.Character
    local myTeam = LocalPlayer:GetAttribute("Team") or (myChar and myChar:GetAttribute("Team"))
    local pChar = player.Character
    local pTeam = player:GetAttribute("Team") or (pChar and pChar:GetAttribute("Team"))
    if myTeam ~= nil and pTeam ~= nil then
        return myTeam == pTeam
    end

    if LocalPlayer.Team ~= nil and player.Team ~= nil then
        return LocalPlayer.Team == player.Team
    end

    if not player.Neutral and not LocalPlayer.Neutral then
        return LocalPlayer.TeamColor == player.TeamColor
    end

    return false
end

local function ApplyHitbox(head)
    local rec = OriginalProps[head]
    if not rec then
        local mesh = head:FindFirstChildOfClass("SpecialMesh")
        rec = {
            Size = head.Size,
            Transparency = head.Transparency,
            CanCollide = head.CanCollide,
            CanQuery = head.CanQuery,
            CanTouch = head.CanTouch,
            Massless = head.Massless,
            MeshScale = mesh and mesh.Scale or nil,
        }
        OriginalProps[head] = rec
    end

    head.Size = TargetVec
    head.Transparency = (head.Name == "HumanoidRootPart") and rec.Transparency or Settings.Transparency
    head.CanCollide = false
    head.CanQuery = true
    head.CanTouch = true
    head.Massless = true
    head.CastShadow = false

    local mesh = head:FindFirstChildOfClass("SpecialMesh")
    if mesh and rec.MeshScale then
        mesh.Scale = rec.MeshScale
    end
end

local function RestoreHead(head)
    local rec = OriginalProps[head]
    if not rec then return end
    OriginalProps[head] = nil
    if not head.Parent then return end

    pcall(function()
        head.Size = rec.Size
        head.Transparency = rec.Transparency
        head.CanCollide = rec.CanCollide
        head.CanQuery = rec.CanQuery
        head.CanTouch = rec.CanTouch
        head.Massless = rec.Massless
        local mesh = head:FindFirstChildOfClass("SpecialMesh")
        if mesh and rec.MeshScale then
            mesh.Scale = rec.MeshScale
        end
    end)
end

local function RestoreAll()
    for head in pairs(OriginalProps) do
        RestoreHead(head)
    end
end
State.restoreAll = RestoreAll

local CachedPlayers = {}
local function RebuildPlayerList()
    table.clear(CachedPlayers)
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            CachedPlayers[#CachedPlayers + 1] = pl
        end
    end
end
RebuildPlayerList()
Connect(Players.PlayerAdded, RebuildPlayerList)
Connect(Players.PlayerRemoving, RebuildPlayerList)

Connect(RunService.RenderStepped, function()
    if not Settings.Enabled then
        if next(OriginalProps) ~= nil then
            RestoreAll()
        end
        return
    end

    for i = 1, #CachedPlayers do
        local player = CachedPlayers[i]
        local alive, head = GetAliveTarget(player)

        if alive then
            if IsTeammate(player) then
                if head and OriginalProps[head] then
                    RestoreHead(head)
                end
            elseif head and head.Size ~= TargetVec then
                ApplyHitbox(head)
            end
        end
    end
end)

pcall(function()
    if CoreGui:FindFirstChild("NysonTekSoftware") then
        CoreGui.NysonTekSoftware:Destroy()
    end
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pGui and pGui:FindFirstChild("NysonTekSoftware") then
        pGui.NysonTekSoftware:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NysonTekSoftware"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
State.gui = ScreenGui

local parentSet = false
if typeof(gethui) == "function" then
    pcall(function() ScreenGui.Parent = gethui(); parentSet = true end)
end
if not parentSet and typeof(syn) == "table" and syn.protect_gui then
    pcall(function() syn.protect_gui(ScreenGui); ScreenGui.Parent = CoreGui; parentSet = true end)
end
if not parentSet then
    pcall(function() ScreenGui.Parent = CoreGui; parentSet = true end)
end
if not parentSet then
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    if pGui then
        ScreenGui.Parent = pGui
        parentSet = true
    end
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 310, 0, 200)
MainFrame.Position = UDim2.new(0.5, -155, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Color3.fromRGB(50, 50, 60)
MainFrame.Active = true

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Parent = MainFrame
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel")
Title.Parent = Header
Title.Size = UDim2.new(1, -16, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "NysonTek Software"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = Color3.fromRGB(220, 220, 235)
Title.TextXAlignment = Enum.TextXAlignment.Left

local isDragging = false
local dragStart, startPos

Connect(Header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

local Sep = Instance.new("Frame")
Sep.Parent = MainFrame
Sep.Size = UDim2.new(1, 0, 0, 1)
Sep.Position = UDim2.new(0, 0, 0, 36)
Sep.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
Sep.BorderSizePixel = 0

local function CreateToggle(yPos, text, defaultState, callback)
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.Size = UDim2.new(1, -20, 0, 28)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    btn.BorderSizePixel = 0
    btn.Text = ""

    local label = Instance.new("TextLabel")
    label.Parent = btn
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(200, 200, 215)
    label.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame")
    track.Parent = btn
    track.Size = UDim2.new(0, 32, 0, 14)
    track.Position = UDim2.new(1, -40, 0.5, -7)
    track.BackgroundColor3 = defaultState and Color3.fromRGB(80, 140, 255) or Color3.fromRGB(50, 50, 65)
    track.BorderSizePixel = 0

    local knob = Instance.new("Frame")
    knob.Parent = track
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Position = defaultState and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5)
    knob.BackgroundColor3 = Color3.fromRGB(230, 230, 240)
    knob.BorderSizePixel = 0

    local state = defaultState
    local function Toggle()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(80, 140, 255) or Color3.fromRGB(50, 50, 65)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5)
        }):Play()
        callback(state)
    end

    btn.Activated:Connect(Toggle)
end

CreateToggle(46, "Включить хитбокс", Settings.Enabled, function(state)
    Settings.Enabled = state
    if not state then
        RestoreAll()
    end
end)

local SliderCard = Instance.new("Frame")
SliderCard.Parent = MainFrame
SliderCard.Size = UDim2.new(1, -20, 0, 50)
SliderCard.Position = UDim2.new(0, 10, 0, 84)
SliderCard.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
SliderCard.BorderSizePixel = 0

local SliderTitle = Instance.new("TextLabel")
SliderTitle.Parent = SliderCard
SliderTitle.Size = UDim2.new(1, -70, 0, 18)
SliderTitle.Position = UDim2.new(0, 10, 0, 6)
SliderTitle.BackgroundTransparency = 1
SliderTitle.Text = "Размер головы (studs)"
SliderTitle.Font = Enum.Font.Gotham
SliderTitle.TextSize = 12
SliderTitle.TextColor3 = Color3.fromRGB(200, 200, 215)
SliderTitle.TextXAlignment = Enum.TextXAlignment.Left

local ValueLabel = Instance.new("TextLabel")
ValueLabel.Parent = SliderCard
ValueLabel.Size = UDim2.new(0, 50, 0, 18)
ValueLabel.Position = UDim2.new(1, -60, 0, 6)
ValueLabel.BackgroundTransparency = 1
ValueLabel.Text = string.format("%.1f", Settings.HeadSize)
ValueLabel.Font = Enum.Font.GothamBold
ValueLabel.TextSize = 13
ValueLabel.TextColor3 = Color3.fromRGB(80, 140, 255)
ValueLabel.TextXAlignment = Enum.TextXAlignment.Right

local Bar = Instance.new("Frame")
Bar.Parent = SliderCard
Bar.Size = UDim2.new(1, -20, 0, 6)
Bar.Position = UDim2.new(0, 10, 0, 30)
Bar.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
Bar.BorderSizePixel = 0

local minSize = 1.0
local maxSize = 3.0

local Fill = Instance.new("Frame")
Fill.Parent = Bar
local initialPct = math.clamp((Settings.HeadSize - minSize) / (maxSize - minSize), 0, 1)
Fill.Size = UDim2.new(initialPct, 0, 1, 0)
Fill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
Fill.BorderSizePixel = 0

local function SetSize(newVal)
    newVal = math.clamp(newVal, minSize, maxSize)
    newVal = math.floor(newVal * 10 + 0.5) / 10
    Settings.HeadSize = newVal
    UpdateTargetVec()
    ValueLabel.Text = string.format("%.1f", newVal)
    Fill.Size = UDim2.new((newVal - minSize) / (maxSize - minSize), 0, 1, 0)
end

local sliderDragging = false
local function UpdateSliderFromInput(input)
    local relX = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
    SetSize(minSize + (maxSize - minSize) * relX)
end

Connect(Bar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = true
        UpdateSliderFromInput(input)
    end
end)

Connect(UserInputService.InputChanged, function(input)
    local t = input.UserInputType
    if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then
        return
    end
    if isDragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    elseif sliderDragging then
        UpdateSliderFromInput(input)
    end
end)

Connect(UserInputService.InputEnded, function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        isDragging = false
        sliderDragging = false
    end
end)

local Footer = Instance.new("TextLabel")
Footer.Parent = MainFrame
Footer.Size = UDim2.new(1, -28, 0, 18)
Footer.Position = UDim2.new(0, 14, 1, -22)
Footer.BackgroundTransparency = 1
Footer.Text = "NysonTek Software  |  version 1.1"
Footer.Font = Enum.Font.Gotham
Footer.TextSize = 10
Footer.TextColor3 = Color3.fromRGB(75, 75, 95)
Footer.TextXAlignment = Enum.TextXAlignment.Center

local guiVisible = true
Connect(UserInputService.InputBegan, function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        guiVisible = not guiVisible
        MainFrame.Visible = guiVisible
    end
end)

if getgenv then
    getgenv().HEAD_HITBOX_STATE = State
end

print("[NysonTek Software] Loaded")
