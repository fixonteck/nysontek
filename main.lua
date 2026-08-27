local VERSION = "1.2"

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
    local oldEsp = PrevState.espContainer
    if oldEsp and oldEsp.Parent then
        pcall(function() oldEsp:Destroy() end)
    end
end

local Connections = {}
local State = {
    connections = Connections,
    gui = nil,
    espContainer = nil,
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
    EspEnabled = true,
}

local OriginalProps = setmetatable({}, { __mode = "k" })
local EspInstances = {}

local TargetVec = Vector3.new(Settings.HeadSize, Settings.HeadSize, Settings.HeadSize)
local function UpdateTargetVec()
    TargetVec = Vector3.new(Settings.HeadSize, Settings.HeadSize, Settings.HeadSize)
end

local function GetAliveTarget(player)
    local char = player.Character
    if not char or not char.Parent then
        return false, nil, nil
    end

    local dead = char:GetAttribute("Dead")
    if dead == nil then
        dead = player:GetAttribute("Dead")
    end
    if dead == true or dead == 1 then
        return false, nil, nil
    end

    local attrHealth = char:GetAttribute("Health") or player:GetAttribute("Health")
    if type(attrHealth) == "number" and attrHealth <= 0 then
        return false, nil, nil
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MaxHealth > 0 and hum.Health <= 0 then
        return false, nil, nil
    end

    local head = char:FindFirstChild("Head")
        or char:FindFirstChild("Headbox")
        or char:FindFirstChild("Hitbox")
        or char:FindFirstChild("HumanoidRootPart")

    if not head or not head:IsA("BasePart") then
        return false, nil, nil
    end

    local root = char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
        or head

    return true, head, root
end

local function IsTeammateCached(player, myTeamAttr, myTeamObj, myTeamColor, myNeutral)
    local pChar = player.Character
    local pTeamAttr = player:GetAttribute("Team") or (pChar and pChar:GetAttribute("Team"))
    if myTeamAttr ~= nil and pTeamAttr ~= nil then
        return myTeamAttr == pTeamAttr
    end

    if myTeamObj ~= nil and player.Team ~= nil then
        return myTeamObj == player.Team
    end

    if not myNeutral and not player.Neutral then
        return myTeamColor == player.TeamColor
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
end

local function RemoveEsp(player)
    local esp = EspInstances[player]
    if esp then
        pcall(function() esp:Destroy() end)
        EspInstances[player] = nil
    end
end

local function ClearAllEsp()
    for player, esp in pairs(EspInstances) do
        pcall(function()
            esp.Visible = false
            esp.Adornee = nil
            esp:Destroy()
        end)
    end
    table.clear(EspInstances)
end

local function RestoreAll()
    for head in pairs(OriginalProps) do
        RestoreHead(head)
    end
    table.clear(OriginalProps)
    ClearAllEsp()
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
Connect(Players.PlayerRemoving, function(pl)
    RemoveEsp(pl)
    RebuildPlayerList()
end)

pcall(function()
    if CoreGui:FindFirstChild("NysonTekSoftware") then
        CoreGui.NysonTekSoftware:Destroy()
    end
    if CoreGui:FindFirstChild("NysonTek_ESP_Container") then
        CoreGui.NysonTek_ESP_Container:Destroy()
    end
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pGui then
        if pGui:FindFirstChild("NysonTekSoftware") then
            pGui.NysonTekSoftware:Destroy()
        end
        if pGui:FindFirstChild("NysonTek_ESP_Container") then
            pGui.NysonTek_ESP_Container:Destroy()
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NysonTekSoftware"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
State.gui = ScreenGui

local EspContainer = Instance.new("Folder")
EspContainer.Name = "NysonTek_ESP_Container"
State.espContainer = EspContainer

local parentSet = false
if typeof(gethui) == "function" then
    pcall(function()
        ScreenGui.Parent = gethui()
        EspContainer.Parent = gethui()
        parentSet = true
    end)
end
if not parentSet and typeof(syn) == "table" and syn.protect_gui then
    pcall(function()
        syn.protect_gui(ScreenGui)
        syn.protect_gui(EspContainer)
        ScreenGui.Parent = CoreGui
        EspContainer.Parent = CoreGui
        parentSet = true
    end)
end
if not parentSet then
    pcall(function()
        ScreenGui.Parent = CoreGui
        EspContainer.Parent = CoreGui
        parentSet = true
    end)
end
if not parentSet then
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    if pGui then
        ScreenGui.Parent = pGui
        EspContainer.Parent = pGui
        parentSet = true
    end
end

local function CreateEspBox(player)
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "ESP3D_" .. player.Name
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Size = Vector3.new(3.6, 5.0, 2.0)
    box.Transparency = 0.65
    box.Parent = EspContainer
    return box
end

local EnemyColor = Color3.fromRGB(255, 60, 60)
local TeamColor = Color3.fromRGB(80, 220, 120)

Connect(RunService.RenderStepped, function()
    local hitboxOn = Settings.Enabled
    local espOn = Settings.EspEnabled

    if not hitboxOn and not espOn then
        if next(OriginalProps) ~= nil then
            for head in pairs(OriginalProps) do
                RestoreHead(head)
            end
        end
        return
    end

    local myChar = LocalPlayer.Character
    local myTeamAttr = LocalPlayer:GetAttribute("Team") or (myChar and myChar:GetAttribute("Team"))
    local myTeamObj = LocalPlayer.Team
    local myTeamColor = LocalPlayer.TeamColor
    local myNeutral = LocalPlayer.Neutral

    local numPlayers = #CachedPlayers
    for i = 1, numPlayers do
        local player = CachedPlayers[i]
        local alive, head, root = GetAliveTarget(player)
        local espBox = EspInstances[player]

        if alive then
            local isTeam = IsTeammateCached(player, myTeamAttr, myTeamObj, myTeamColor, myNeutral)

            if hitboxOn then
                if isTeam then
                    if head and OriginalProps[head] then
                        RestoreHead(head)
                    end
                elseif head and head.Size ~= TargetVec then
                    ApplyHitbox(head)
                end
            end

            if espOn and root then
                if not espBox or not espBox.Parent then
                    espBox = CreateEspBox(player)
                    EspInstances[player] = espBox
                end
                espBox.Color3 = isTeam and TeamColor or EnemyColor
                espBox.Adornee = root
                espBox.Visible = true
            elseif espBox then
                espBox.Visible = false
                espBox.Adornee = nil
            end
        else
            if espBox then
                espBox.Visible = false
                espBox.Adornee = nil
            end
            if head and OriginalProps[head] then
                RestoreHead(head)
            end
        end
    end
end)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 330, 0, 235)
MainFrame.Position = UDim2.new(0.5, -165, 0.5, -117)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 50, 60)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Parent = MainFrame
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundTransparency = 1
Header.BorderSizePixel = 0

local Icons = {
    Shield = "rbxassetid://6031079138",
    Crosshair = "rbxassetid://6031075931",
    Sliders = "rbxassetid://6031280882",
    Eye = "rbxassetid://6034503203",
}

local function SetFont(obj, weight)
    weight = weight or Enum.FontWeight.Regular
    local applied = false
    pcall(function()
        obj.FontFace = Font.fromName("Inter", weight)
        applied = true
    end)
    if not applied or obj.FontFace == nil then
        pcall(function()
            obj.FontFace = Font.fromEnum(Enum.Font.Gotham, weight)
        end)
    end
end

local HeaderIcon = Instance.new("ImageLabel")
HeaderIcon.Parent = Header
HeaderIcon.Size = UDim2.new(0, 16, 0, 16)
HeaderIcon.Position = UDim2.new(0, 12, 0.5, -8)
HeaderIcon.BackgroundTransparency = 1
HeaderIcon.Image = Icons.Shield
HeaderIcon.ImageColor3 = Color3.fromRGB(80, 140, 255)

local Title = Instance.new("TextLabel")
Title.Parent = Header
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 34, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "NysonTek Software"
SetFont(Title, Enum.FontWeight.Regular)
Title.TextSize = 15
Title.TextColor3 = Color3.fromRGB(240, 240, 250)
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
Sep.Size = UDim2.new(1, -24, 0, 1)
Sep.Position = UDim2.new(0, 12, 0, 40)
Sep.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
Sep.BorderSizePixel = 0

local function CreateToggle(yPos, text, defaultState, iconId, keybindSupported, callback)
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.Size = UDim2.new(1, -24, 0, 32)
    btn.Position = UDim2.new(0, 12, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    btn.BorderSizePixel = 0
    btn.Text = ""

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    if iconId then
        local itemIcon = Instance.new("ImageLabel")
        itemIcon.Parent = btn
        itemIcon.Size = UDim2.new(0, 15, 0, 15)
        itemIcon.Position = UDim2.new(0, 10, 0.5, -7.5)
        itemIcon.BackgroundTransparency = 1
        itemIcon.Image = iconId
        itemIcon.ImageColor3 = Color3.fromRGB(150, 150, 175)
    end

    local label = Instance.new("TextLabel")
    label.Parent = btn
    label.Size = UDim2.new(1, keybindSupported and -120 or -65, 1, 0)
    label.Position = UDim2.new(0, iconId and 32 or 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    SetFont(label, Enum.FontWeight.Regular)
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(215, 215, 225)
    label.TextXAlignment = Enum.TextXAlignment.Left

    local bindBadge = nil
    local currentBind = nil
    local isBinding = false

    if keybindSupported then
        bindBadge = Instance.new("TextLabel")
        bindBadge.Parent = btn
        bindBadge.Size = UDim2.new(0, 52, 0, 18)
        bindBadge.Position = UDim2.new(1, -104, 0.5, -9)
        bindBadge.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
        bindBadge.BorderSizePixel = 0
        bindBadge.Text = "[None]"
        SetFont(bindBadge, Enum.FontWeight.Regular)
        bindBadge.TextSize = 10
        bindBadge.TextColor3 = Color3.fromRGB(130, 130, 155)

        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(0, 4)
        badgeCorner.Parent = bindBadge
    end

    local track = Instance.new("Frame")
    track.Parent = btn
    track.Size = UDim2.new(0, 36, 0, 16)
    track.Position = UDim2.new(1, -46, 0.5, -8)
    track.BackgroundColor3 = defaultState and Color3.fromRGB(80, 140, 255) or Color3.fromRGB(50, 50, 65)
    track.BorderSizePixel = 0

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local knob = Instance.new("Frame")
    knob.Parent = track
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
    knob.BorderSizePixel = 0

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local state = defaultState
    local function SetState(newState)
        state = newState
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(80, 140, 255) or Color3.fromRGB(50, 50, 65)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        }):Play()
        callback(state)
    end

    local function Toggle()
        SetState(not state)
    end

    btn.Activated:Connect(function()
        if not isBinding then
            Toggle()
        end
    end)

    if keybindSupported then
        local function StartBinding()
            if isBinding then return end
            isBinding = true
            bindBadge.Text = "[...]"
            bindBadge.TextColor3 = Color3.fromRGB(255, 200, 80)

            task.delay(0.1, function()
                if not isBinding then return end

                local bindConn
                bindConn = UserInputService.InputBegan:Connect(function(input)
                    local iType = input.UserInputType
                    local kCode = input.KeyCode

                    if iType == Enum.UserInputType.Keyboard then
                        if kCode == Enum.KeyCode.Escape or kCode == Enum.KeyCode.Backspace then
                            currentBind = nil
                            bindBadge.Text = "[None]"
                            bindBadge.TextColor3 = Color3.fromRGB(130, 130, 155)
                            isBinding = false
                            bindConn:Disconnect()
                            return
                        elseif kCode ~= Enum.KeyCode.Unknown then
                            currentBind = { Type = "Keyboard", KeyCode = kCode }
                            local name = kCode.Name
                            if #name > 5 then
                                name = name:gsub("Left", "L"):gsub("Right", "R")
                            end
                            bindBadge.Text = "[" .. name .. "]"
                            bindBadge.TextColor3 = Color3.fromRGB(80, 140, 255)
                            isBinding = false
                            bindConn:Disconnect()
                            return
                        end
                    elseif iType == Enum.UserInputType.MouseButton2 then
                        currentBind = { Type = "Mouse", UserInputType = Enum.UserInputType.MouseButton2 }
                        bindBadge.Text = "[RMB]"
                        bindBadge.TextColor3 = Color3.fromRGB(80, 140, 255)
                        isBinding = false
                        bindConn:Disconnect()
                        return
                    elseif iType == Enum.UserInputType.MouseButton3 then
                        currentBind = { Type = "Mouse", UserInputType = Enum.UserInputType.MouseButton3 }
                        bindBadge.Text = "[MMB]"
                        bindBadge.TextColor3 = Color3.fromRGB(80, 140, 255)
                        isBinding = false
                        bindConn:Disconnect()
                        return
                    end
                end)

                task.delay(6, function()
                    if isBinding then
                        isBinding = false
                        pcall(function() bindConn:Disconnect() end)
                        if not currentBind then
                            bindBadge.Text = "[None]"
                            bindBadge.TextColor3 = Color3.fromRGB(130, 130, 155)
                        end
                    end
                end)
            end)
        end

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton3 then
                StartBinding()
            end
        end)

        Connect(UserInputService.InputBegan, function(input)
            if isBinding or not currentBind then return end
            if UserInputService:GetFocusedTextBox() then return end

            if currentBind.Type == "Keyboard" and input.KeyCode == currentBind.KeyCode then
                Toggle()
            elseif currentBind.Type == "Mouse" and input.UserInputType == currentBind.UserInputType then
                Toggle()
            end
        end)
    end
end

CreateToggle(48, "Включить хитбокс", Settings.Enabled, Icons.Crosshair, false, function(state)
    Settings.Enabled = state
    if not state then
        for head in pairs(OriginalProps) do
            RestoreHead(head)
        end
    end
end)

local SliderCard = Instance.new("Frame")
SliderCard.Parent = MainFrame
SliderCard.Size = UDim2.new(1, -24, 0, 56)
SliderCard.Position = UDim2.new(0, 12, 0, 88)
SliderCard.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
SliderCard.BorderSizePixel = 0

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 8)
cardCorner.Parent = SliderCard

local SliderIcon = Instance.new("ImageLabel")
SliderIcon.Parent = SliderCard
SliderIcon.Size = UDim2.new(0, 14, 0, 14)
SliderIcon.Position = UDim2.new(0, 10, 0, 10)
SliderIcon.BackgroundTransparency = 1
SliderIcon.Image = Icons.Sliders
SliderIcon.ImageColor3 = Color3.fromRGB(150, 150, 175)

local SliderTitle = Instance.new("TextLabel")
SliderTitle.Parent = SliderCard
SliderTitle.Size = UDim2.new(1, -100, 0, 20)
SliderTitle.Position = UDim2.new(0, 30, 0, 7)
SliderTitle.BackgroundTransparency = 1
SliderTitle.Text = "Размер головы (studs)"
SetFont(SliderTitle, Enum.FontWeight.Regular)
SliderTitle.TextSize = 14
SliderTitle.TextColor3 = Color3.fromRGB(215, 215, 225)
SliderTitle.TextXAlignment = Enum.TextXAlignment.Left

local ValueLabel = Instance.new("TextLabel")
ValueLabel.Parent = SliderCard
ValueLabel.Size = UDim2.new(0, 60, 0, 20)
ValueLabel.Position = UDim2.new(1, -70, 0, 7)
ValueLabel.BackgroundTransparency = 1
ValueLabel.Text = string.format("%.1f", Settings.HeadSize)
SetFont(ValueLabel, Enum.FontWeight.Regular)
ValueLabel.TextSize = 15
ValueLabel.TextColor3 = Color3.fromRGB(80, 140, 255)
ValueLabel.TextXAlignment = Enum.TextXAlignment.Right

local Bar = Instance.new("Frame")
Bar.Parent = SliderCard
Bar.Size = UDim2.new(1, -20, 0, 7)
Bar.Position = UDim2.new(0, 10, 0, 35)
Bar.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
Bar.BorderSizePixel = 0

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = Bar

local minSize = 1.0
local maxSize = 3.0

local Fill = Instance.new("Frame")
Fill.Parent = Bar
local initialPct = math.clamp((Settings.HeadSize - minSize) / (maxSize - minSize), 0, 1)
Fill.Size = UDim2.new(initialPct, 0, 1, 0)
Fill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
Fill.BorderSizePixel = 0

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = Fill

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

CreateToggle(152, "Включить ESP Box", Settings.EspEnabled, Icons.Eye, true, function(state)
    Settings.EspEnabled = state
    if not state then
        for _, esp in pairs(EspInstances) do
            esp.Visible = false
            esp.Adornee = nil
        end
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
Footer.Position = UDim2.new(0, 14, 1, -24)
Footer.BackgroundTransparency = 1
Footer.Text = "NysonTek Software  |  version " .. VERSION
SetFont(Footer, Enum.FontWeight.Regular)
Footer.TextSize = 11
Footer.TextColor3 = Color3.fromRGB(85, 85, 105)
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

print("[NysonTek Software v" .. VERSION .. "] Loaded")
