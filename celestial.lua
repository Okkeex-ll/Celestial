-- ===================== KEY CHECK =====================
loadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/06d586a987db770a72076b698587a396ec29ed500fac28936ba2d4608890b6ed/download"))()
while not getgenv().LOAD do task.wait(0.1) end



-- ===================== SERVICES =====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local PhysicsService = game:GetService("PhysicsService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local ScriptLoadStart = tick()

-- ===================== STATE MANAGEMENT =====================
local State = {
    -- Core
    currentTarget = nil,
    kickMode = "Speed",
    kickActive = false,
    activeKicks = {},
    TargetLabel = nil,
    
    -- Anti Systems
    antiGrab = { active = false, proc = false, conn = nil },
    antiRagdoll = { active = false, conn = nil },
    antiExplode = { active = false, conn = nil },
    antiVoid = { active = false, conn = nil, safeY = -50 },
    antiLag = { active = false },
    antiAntiKick = false,
    antiKickAura = { conn = nil },
    antiKickReset = { active = false, conn = nil },
    antiInf = { active = false, detecting = false },
    
    -- Toys & Objects
    shuriken = { active = false, toyType = "NinjaShuriken" },
    snowball = { 
        active = false, conn = nil, obj = nil, root = nil, 
        spawning = false, touchLoop = nil, spawnTime = 0, lifetime = 5 },
    ragdoll = { 
        active = false, conn = nil, pallet = nil, palletPart = nil,
        palletMain = nil, spin = nil, position = nil },
    blobGucci = { active = false, processing = false },
    
    -- Movement & Display
    speed = { value = 16, conn = nil, changedConn = nil, bv = nil },
    thirdPerson = { active = false, distmin = 0, distmax = 1000000 },
    teleport = { active = false, conn = nil,  distance = 50,conn2 = nil },
    vehicleFly = { active = false, speed = 50, conn = nil },
    
    -- Features
    waterWalk = { active = false, parts = {} },
    legs = { deleted = false, autoDelete = false },
    destroyPCLD = { active = false, resetting = false, conn = nil },
    kickNotify = { active = false, conn = nil },

    -- Packet Detection
    packetDetect = { 
        active = false, 
        conn = nil,
        playerData = {},
        notifyCooldown = 5,
        traffic = 0,
        packetCount = 0
    },

        -- Packet Lag
    packetLag = { 
        active = false, 
        conn = nil,
        packetSize = 0.190,
        cooldown = 1
    },
    
    -- BlobKick
    blobKick = { active = false, conn = nil, target = nil },
    
    -- Lag
    lagLine = { active = false, count = 250, parts = {} }
}

local Config = { TargetHeight = 10 }

-- ===================== REMOTES =====================
local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
local destroyGrabLineEvent = GE and GE:FindFirstChild("DestroyGrabLine")
local setOwner = GE and GE:FindFirstChild("SetNetworkOwner")
local CreateGrabLine = GE and GE:FindFirstChild("CreateGrabLine")
local ExtendGrabLine = GE and GE:FindFirstChild("ExtendGrabLine")
local BombEvent = ReplicatedStorage:FindFirstChild("BombEvent")

local MenuToys = ReplicatedStorage:FindFirstChild("MenuToys")
local DestroyToy = MenuToys and MenuToys:FindFirstChild("DestroyToy")
local SpawnToyRemote = MenuToys and MenuToys:FindFirstChild("SpawnToyRemoteFunction")

local CharacterEvents = ReplicatedStorage:FindFirstChild("CharacterEvents")
local Struggle = CharacterEvents and CharacterEvents:FindFirstChild("Struggle")

local GameCorrectionEvents = ReplicatedStorage:FindFirstChild("GameCorrectionEvents")
local StopAllVelocity = GameCorrectionEvents and GameCorrectionEvents:FindFirstChild("StopAllVelocity")

local PlayerEvents = ReplicatedStorage:FindFirstChild("PlayerEvents")
local StickyPartEvent = PlayerEvents and PlayerEvents:FindFirstChild("StickyPartEvent")
local GameCorrectionsNotify = GameCorrectionEvents and GameCorrectionEvents:FindFirstChild("GameCorrectionsNotify")
-- ===================== LIBS =====================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles
Library.ShowToggleFrameInKeybinds = true

-- ===================== COLLISION =====================
local PALLET_GROUP = "PalletGroup"
local PLAYER_GROUP = "PlayerGroup"

pcall(function()
    PhysicsService:RegisterCollisionGroup(PALLET_GROUP)
    PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
    PhysicsService:CollisionGroupSetCollidable(PALLET_GROUP, PLAYER_GROUP, false)
    PhysicsService:CollisionGroupSetCollidable(PALLET_GROUP, PALLET_GROUP, false)
end)

local function SetCollisionGroup(obj, group)
    if not obj then return end
    pcall(function()
        if obj:IsA("BasePart") then obj.CollisionGroup = group end
        for _, v in pairs(obj:GetDescendants()) do
            if v:IsA("BasePart") then v.CollisionGroup = group end
        end
    end)
end

local function ApplyPlayerGroup(char)
    if not char then return end
    SetCollisionGroup(char, PLAYER_GROUP)
end

-- ===================== ESP SYSTEM =====================
local ESP = {
    pclcEnabled = false,
    pclcColor = Color3.fromRGB(255, 0, 0),
    pclcTransparency = 0.5,
    pclcData = {},
    pclcConn = nil,
    enabled = false,
    nameEnabled = false,
    playerColor = Color3.fromRGB(255, 255, 255),
    playerLabels = {},
    highlightEnabled = false,
    highlightColor = Color3.fromRGB(255, 0, 0),
    highlightTransparency = 0.5,
    playerHighlights = {},
}
-- ===================== PCLD ESP =====================
local function UpdatePCLDSettings()
    for _, data in pairs(ESP.pclcData) do
        if data.box then
            data.box.Color3 = ESP.pclcColor
            data.box.Transparency = ESP.pclcTransparency
        end
    end
end

local function AddPCLDESP(obj)
    if not obj or not obj.Parent then return end
    if ESP.pclcData[obj] then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Adornee = obj
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Color3 = ESP.pclcColor
    box.Transparency = ESP.pclcTransparency
    box.Size = obj.Size + Vector3.new(0.1, 0.1, 0.1)
    box.Parent = game.CoreGui
    ESP.pclcData[obj] = { box = box }
    obj.AncestryChanged:Connect(function(_, parent)
        if not parent and ESP.pclcData[obj] then
            pcall(function() ESP.pclcData[obj].box:Destroy() end)
            ESP.pclcData[obj] = nil
        end
    end)
end

local function ScanPCLD()
    task.spawn(function()
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("BasePart") and child.Name == "PlayerCharacterLocationDetector" then
                AddPCLDESP(child)
            end
            for _, obj in ipairs(child:GetChildren()) do
                if obj:IsA("BasePart") and obj.Name == "PlayerCharacterLocationDetector" then
                    AddPCLDESP(obj)
                end
            end
            task.wait()
        end
    end)
end

local function StartPCLD()
    ESP.pclcEnabled = true
    ScanPCLD()
    if ESP.pclcConn then ESP.pclcConn:Disconnect() end
    ESP.pclcConn = workspace.DescendantAdded:Connect(function(obj)
        if not ESP.pclcEnabled then return end
        if obj:IsA("BasePart") and obj.Name == "PlayerCharacterLocationDetector" then
            AddPCLDESP(obj)
        end
    end)
end

local function StopPCLD()
    ESP.pclcEnabled = false
    if ESP.pclcConn then ESP.pclcConn:Disconnect(); ESP.pclcConn = nil end
    for obj, data in pairs(ESP.pclcData) do
        pcall(function() data.box:Destroy() end)
    end
    ESP.pclcData = {}
end

-- ===================== THIRD PERSON =====================
local function StartThirdPerson()
    State.thirdPerson.active = true
    LocalPlayer.CameraMaxZoomDistance = State.thirdPerson.distmax
    LocalPlayer.CameraMinZoomDistance = State.thirdPerson.distmin
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function StopThirdPerson()
    State.thirdPerson.active = false
    LocalPlayer.CameraMaxZoomDistance = 0
    LocalPlayer.CameraMinZoomDistance = 0
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local function ToggleThirdPerson(value)
    if value then StartThirdPerson() else StopThirdPerson() end
end

-- ===================== TELEPORT BY MOUSE =====================
local function TeleportToMouse()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local targetPos = Mouse.Hit.Position
    local direction = (targetPos - hrp.Position).Unit
    local teleportPos = hrp.Position + direction * State.teleport.distance
    
    hrp.CFrame = CFrame.new(teleportPos)
end
        


local function StopTeleport()
    State.teleport.active = false
    if State.teleport.conn then 
        State.teleport.conn:Disconnect() 
        State.teleport.conn = nil 
    end
end

local function ToggleTeleport(value)
    State.teleport.active = value
    if value then StartTeleport() else StopTeleport() end
end

-- ===================== VEHICLE FLY =====================
local function StartVehicleFly()
    State.vehicleFly.active = true
    
    -- Отключаем предыдущее соединение, если есть
    if State.vehicleFly.conn then 
        State.vehicleFly.conn:Disconnect() 
        State.vehicleFly.conn = nil
    end
    
    State.vehicleFly.conn = RunService.Heartbeat:Connect(function()
        if not State.vehicleFly.active then return end
        
        local char = LocalPlayer.Character
        if not char then return end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or not humanoid.SeatPart then return end
        
        local seat = humanoid.SeatPart
        -- Проверка, что мы действительно в транспорте
        if not seat:IsA("VehicleSeat") then return end
        
        -- Ищем модель транспорта (обычно родитель сиденья или выше)
        local vehicleModel = seat.Parent
        while vehicleModel and not vehicleModel:FindFirstChildWhichIsA("BasePart") do
            vehicleModel = vehicleModel.Parent
        end
        
        if not vehicleModel then return end
        
        -- Находим главную часть машины для управления физикой
        local rootPart = vehicleModel.PrimaryPart or vehicleModel:FindFirstChildWhichIsA("BasePart")
        if not rootPart then return end
        
        local camera = Workspace.CurrentCamera
        if not camera then return end
        
        -- Сбор направления ввода
        local moveDirection = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        
        -- Применение движения
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
            -- Используем Velocity для более плавной физики вместо прямого CFrame
            local velocity = moveDirection * State.vehicleFly.speed
            rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, rootPart.AssemblyLinearVelocity.Y, velocity.Z)
            
            -- Для полета нужно также отключить гравитацию для части
            rootPart.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0) 
        else
            -- Остановка если кнопки не нажаты
            rootPart.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

-- Остановка полета
local function StopVehicleFly()
    State.vehicleFly.active = false
    
    if State.vehicleFly.conn then 
        State.vehicleFly.conn:Disconnect() 
        State.vehicleFly.conn = nil 
    end
    
    -- Возвращаем физику транспорта в нормальное состояние (опционально)
    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.SeatPart then
            local vehicleModel = humanoid.SeatPart.Parent
            local rootPart = vehicleModel and (vehicleModel.PrimaryPart or vehicleModel:FindFirstChildWhichIsA("BasePart"))
            if rootPart then
                rootPart.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end
end

-- ===================== PLAYER ESP =====================
local function AddPlayerLabel(player)
    if ESP.playerLabels[player] then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerESP_NameTag"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.Adornee = hrp
    billboard.Parent = game.CoreGui
    
    -- Background Frame
    local bgFrame = Instance.new("Frame")
    bgFrame.Size = UDim2.new(1, 0, 1, 0)
    bgFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bgFrame.BackgroundTransparency = 0.3
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = bgFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = ESP.playerColor
    stroke.Thickness = 2
    stroke.Transparency = 0
    stroke.Parent = bgFrame
    
    -- Name Label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -10, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 5, 0.1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = ESP.playerColor
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = player.DisplayName
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
    nameLabel.Parent = bgFrame
    
    -- Username Label
    local userLabel = Instance.new("TextLabel")
    userLabel.Name = "UserLabel"
    userLabel.Size = UDim2.new(1, -10, 0.4, 0)
    userLabel.Position = UDim2.new(0, 5, 0.55, 0)
    userLabel.BackgroundTransparency = 1
    userLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    userLabel.TextStrokeTransparency = 0.5
    userLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    userLabel.TextSize = 12
    userLabel.Font = Enum.Font.Gotham
    userLabel.Text = "@" .. player.Name
    userLabel.TextXAlignment = Enum.TextXAlignment.Center
    userLabel.TextYAlignment = Enum.TextYAlignment.Top
    userLabel.Parent = bgFrame
    
    ESP.playerLabels[player] = billboard
end

local function RemovePlayerLabel(player)
    if ESP.playerLabels[player] then
        pcall(function() ESP.playerLabels[player]:Destroy() end)
        ESP.playerLabels[player] = nil
    end
end



local function AddHighlight(player)
    if ESP.playerHighlights[player] then return end
    local char = player.Character
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.Name = "WiFiHighlight"
    hl.FillColor = ESP.highlightColor
    hl.OutlineColor = ESP.highlightColor
    hl.FillTransparency = ESP.highlightTransparency
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Parent = game.CoreGui
    ESP.playerHighlights[player] = hl
end

local function RemoveHighlight(player)
    if ESP.playerHighlights[player] then
        pcall(function() ESP.playerHighlights[player]:Destroy() end)
        ESP.playerHighlights[player] = nil
    end
end

local function UpdateESPColors()
    for player, billboard in pairs(ESP.playerLabels) do
        if billboard then
            local bgFrame = billboard:FindFirstChild("Frame")
            if bgFrame then
                local stroke = bgFrame:FindFirstChild("UIStroke")
                local nameLabel = bgFrame:FindFirstChild("NameLabel")
                if stroke then stroke.Color = ESP.playerColor end
                if nameLabel then nameLabel.TextColor3 = ESP.playerColor end
            end
        end
    end
end

local function UpdateHighlightSettings()
    for _, hl in pairs(ESP.playerHighlights) do
        if hl then
            hl.FillColor = ESP.highlightColor
            hl.OutlineColor = ESP.highlightColor
            hl.FillTransparency = ESP.highlightTransparency
        end
    end
end

local function StartESP()
    ESP.enabled = true
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if ESP.nameEnabled and plr.Character then AddPlayerLabel(plr) end
            if ESP.highlightEnabled and plr.Character then AddHighlight(plr) end
        end
    end
    
    Players.PlayerAdded:Connect(function(plr)
        if not ESP.enabled then return end
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            if not ESP.enabled then return end
            if ESP.nameEnabled then AddPlayerLabel(plr) end
            if ESP.highlightEnabled then AddHighlight(plr) end
        end)
    end)
end
local function StopESP()
    ESP.enabled = false
    for plr, _ in pairs(ESP.playerLabels) do RemovePlayerLabel(plr) end
    ESP.playerLabels = {}
    for plr, _ in pairs(ESP.playerHighlights) do RemoveHighlight(plr) end
    ESP.playerHighlights = {}
end

local function ToggleEsp(value)
    if value then StartESP() else StopESP() end
end

-- ===================== DELETE LEGS =====================
local function DeleteLegs()
    local char = LocalPlayer.Character
    if not char then return end
    
    pcall(function()
        local leftLeg = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftUpperLeg")
        local rightLeg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg")
        
        if leftLeg then leftLeg:Destroy() end
        if rightLeg then rightLeg:Destroy() end
        
        State.legs.deleted = true
        Library:Notify({ Title = "Delete Legs", Description = "Legs removed!", Time = 2 })
    end)
end

-- ===================== ANTI LAG =====================
local function ToggleAntiLag(value)
    State.antiLag.active = value
    pcall(function()
        local charMove = LocalPlayer.PlayerScripts:FindFirstChild("CharacterAndBeamMove")
        if charMove then
            charMove.Enabled = not value
        end
    end)
end

-- ===================== WATER WALK =====================
pcall(function()
    local objectModel = workspace.Map.AlwaysHereTweenedObjects.Ocean.Object.ObjectModel
    for _, part in ipairs(objectModel:GetChildren()) do
        if part:IsA("BasePart") and part.Name == "Ocean" then
            table.insert(State.waterWalk.parts, part)
        end
    end
end)

local function StartWaterWalk()
    State.waterWalk.active = true
    for _, part in ipairs(State.waterWalk.parts) do
        pcall(function()
            part.CanCollide = true
        end)
    end
end

local function StopWaterWalk()
    State.waterWalk.active = false
    for _, part in ipairs(State.waterWalk.parts) do
        pcall(function()
            part.CanCollide = false
        end)
    end
end

-- ===================== ANTI VOID =====================
local function StartAntiVoid()
    State.antiVoid.active = true
    if State.antiVoid.conn then State.antiVoid.conn:Disconnect() end
    
    State.antiVoid.conn = RunService.Heartbeat:Connect(function()
        if not State.antiVoid.active then return end
        
        -- ЛОМАЕМ VOID KILL СИСТЕМЫ ЧЕРЕЗ NaN
        pcall(function()
            workspace.FallenPartsDestroyHeight = "nan"
        end)
        
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        -- ДОПОЛНИТЕЛЬНАЯ ЗАЩИТА
        pcall(function()
            -- Блокируем смерть
            if hum:GetState() == Enum.HumanoidStateType.Dead then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            
            -- Убираем creator tags
            for _, obj in pairs(char:GetDescendants()) do
                if obj.Name == "creator" then
                    obj:Destroy()
                end
            end
        end)
    end)
end

local function StopAntiVoid()
    State.antiVoid.active = false
    if State.antiVoid.conn then State.antiVoid.conn:Disconnect(); State.antiVoid.conn = nil end
    
    pcall(function()
        workspace.FallenPartsDestroyHeight = -500 -- обычное значение
    end)
end

-- ===================== ANTI INF =====================
local function StartAntiInf()
    State.antiInf.active = true
    
    local function SetupAntiInfChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        local head = char:WaitForChild("Head", 5)
        if not hum or not hrp or not head then return end
        
        local ragdollStartTime = nil
        local lowHealthTime = nil
        local lastHealth = hum.Health
        
        -- HEARTBEAT МОНИТОРИНГ - главная защита
        local infConn = RunService.Heartbeat:Connect(function()
            if not State.antiInf.active then return end
            if not hum or not hum.Parent then return end
            
            local currentState = hum:GetState()
            local isGrabbed = head:FindFirstChild("PartOwner") ~= nil
            
            -- ДЕТЕКТ 1: Низкое HP но не мертв
            if hum.Health > 0 and hum.Health < 5 and currentState ~= Enum.HumanoidStateType.Dead then
                if not lowHealthTime then
                    lowHealthTime = tick()
                elseif tick() - lowHealthTime > 1 then
                    -- Застряли с низким HP дольше 1 сек → FORCE RESET
                    Library:Notify({ 
                        Title = "Anti-Inf", 
                        Description = "Inf-die detected! Force reset...", 
                        Time = 2 
                    })
                    
                    -- Множественные попытки ресета
                    for i = 1, 10 do
                        pcall(function() hum.Health = 0 end)
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
                        if Struggle then Struggle:FireServer(LocalPlayer) end
                        task.wait(0.01)
                    end
                    
                    lowHealthTime = nil
                end
            else
                lowHealthTime = nil
            end
            
            -- ДЕТЕКТ 2: Застряли в Ragdoll слишком долго
            if currentState == Enum.HumanoidStateType.Physics or 
               currentState == Enum.HumanoidStateType.Ragdoll or
               hum.PlatformStand then
                
                if not ragdollStartTime then
                    ragdollStartTime = tick()
                elseif tick() - ragdollStartTime > 3 and not isGrabbed then
                    -- Ragdoll дольше 3 сек БЕЗ граба → пытаемся встать
                    Library:Notify({ 
                        Title = "Anti-Inf", 
                        Description = "Stuck in ragdoll! Escaping...", 
                        Time = 2 
                    })
                    
                    task.spawn(function()
                        -- Отключаем BallSockets
                        for _, part in pairs(char:GetChildren()) do
                            if part:IsA("BasePart") and part.Name ~= "Head" then
                                if part:FindFirstChild("BallSocketConstraint") then
                                    part.BallSocketConstraint.Enabled = false
                                end
                                if part:FindFirstChild("RagdollLimbPart") then
                                    pcall(function()
                                        part.RagdollLimbPart.WeldConstraint.Enabled = false
                                    end)
                                end
                            end
                        end
                        
                        -- Force встать
                        hum.PlatformStand = false
                        hum.Sit = false
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                        
                        -- Struggle спам
                        for i = 1, 5 do
                            if Struggle then Struggle:FireServer(LocalPlayer) end
                            task.wait(0.02)
                        end
                        
                        ragdollStartTime = nil
                    end)
                end
            else
                ragdollStartTime = nil
            end
            
            -- ДЕТЕКТ 3: Быстрый урон во время граба → INSTANT RESET
            local damage = lastHealth - hum.Health
            if isGrabbed and damage >= 30 and hum.Health > 0 and hum.Health < 20 then
                Library:Notify({ 
                    Title = "Anti-Inf", 
                    Description = "Fast damage + grab! Resetting...", 
                    Time = 2 
                })
                
                -- Мгновенный ресет чтобы НЕ застрять
                task.spawn(function()
                    for i = 1, 15 do
                        if Struggle then Struggle:FireServer(LocalPlayer) end
                        task.wait(0.001)
                    end
                    
                    pcall(function() hum.Health = 0 end)
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
                    
                    for i = 1, 10 do
                        if Struggle then Struggle:FireServer(LocalPlayer) end
                        task.wait(0.001)
                    end
                end)
            end
            
            lastHealth = hum.Health
        end)
        
        -- При смерти - дополнительная защита
        hum.Died:Connect(function()
            if not State.antiInf.active then return end
            if infConn then infConn:Disconnect() end
            
            -- Спам Struggle на случай если застряли
            task.spawn(function()
                for i = 1, 20 do
                    if Struggle then Struggle:FireServer(LocalPlayer) end
                    task.wait(0.01)
                end
            end)
        end)
        
        -- Следим за Ragdolled value
        local ragdolledVal = hum:FindFirstChild("Ragdolled")
        if ragdolledVal then
            ragdolledVal.Changed:Connect(function()
                if not State.antiInf.active then return end
                
                -- Если регдолл включился при очень низком HP → ресет
                if ragdolledVal.Value and hum.Health > 0 and hum.Health < 10 then
                    local isGrabbed = head:FindFirstChild("PartOwner") ~= nil
                    
                    if isGrabbed then
                        -- В грабе с низким HP → быстрый ресет
                        task.spawn(function()
                            task.wait(0.5) -- ждём 0.5 сек
                            
                            if hum.Health > 0 and hum.Health < 10 then
                                Library:Notify({ 
                                    Title = "Anti-Inf", 
                                    Description = "Low HP ragdoll! Forcing reset...", 
                                    Time = 2 
                                })
                                
                                for i = 1, 10 do
                                    pcall(function() hum.Health = 0 end)
                                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
                                    if Struggle then Struggle:FireServer(LocalPlayer) end
                                    task.wait(0.01)
                                end
                            end
                        end)
                    end
                end
            end)
        end
    end
    
    local char = LocalPlayer.Character
    if char then SetupAntiInfChar(char) end
    
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        if not State.antiInf.active then return end
        task.wait(0.5)
        SetupAntiInfChar(newChar)
    end)
end

local function StopAntiInf()
    State.antiInf.active = false
    State.antiInf.detecting = false
end

local function ToggleAntiInf(value)
    State.antiInf.active = value
    if value then StartAntiInf() else StopAntiInf() end
end

-- ===================== ANTI KICK RESET =====================
local function StartAntiKickReset()
    if not GameCorrectionsNotify then 
        Library:Notify({ Title = "Anti-Kick Reset", Description = "GameCorrectionsNotify not found!", Time = 3 })
        return 
    end
    
    State.antiKickReset.active = true
    
    if State.antiKickReset.conn then State.antiKickReset.conn:Disconnect() end
    
    State.antiKickReset.conn = GameCorrectionsNotify.OnClientEvent:Connect(function(Type)
        if not State.antiKickReset.active then return end
        
        if Type == "Flying" then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if hum then 
                task.spawn(function()
                    -- ПЕРЕД РЕСЕТОМ: Struggle спам 10 раз
                    for i = 1, 10 do
                        if Struggle then
                            Struggle:FireServer(LocalPlayer)
                            Struggle:FireServer(LocalPlayer)
                        end
                        task.wait(0.001)
                    end
                    
                    -- РЕСЕТ через ChangeState
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
                    task.wait(0.01)
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
                    
                    -- ПОСЛЕ РЕСЕТА: Struggle спам еще 10 раз
                    for i = 1, 10 do
                        if Struggle then
                            Struggle:FireServer(LocalPlayer)
                            Struggle:FireServer(LocalPlayer)
                        end
                        task.wait(0.001)
                    end
                    
                    -- Дополнительно: сброс здоровья
                    pcall(function() hum.Health = 0 end)
                end)
            end
        end
    end)
end

local function StopAntiKickReset()
    State.antiKickReset.active = false
    if State.antiKickReset.conn then 
        State.antiKickReset.conn:Disconnect() 
        State.antiKickReset.conn = nil 
    end
end

local function ToggleAntiKickReset(value)
    State.antiKickReset.active = value
    if value then StartAntiKickReset() else StopAntiKickReset() end
end
-- ===================== GUCCI BUTTONS =====================
local function RemoveBlobUI()
    pcall(function()
        local menuGui = LocalPlayer.PlayerGui:FindFirstChild("MenuGui")
        if not menuGui then return end
        local creatureBlobman = menuGui:FindFirstChild("CreatureBlobman", true)
        if not creatureBlobman then return end
        local viewItemButton = creatureBlobman:FindFirstChild("ViewItemButton")
        if not viewItemButton then return end
        local lowResImage = viewItemButton:FindFirstChild("LowResImage")
        if lowResImage then lowResImage:Destroy() end
        local textLabel = viewItemButton:FindFirstChildWhichIsA("TextLabel")
        if textLabel then textLabel.Text = "Blob Gucci" end
    end)
end

local safePosition = nil
local antiGucciConnection = nil
local restoreFrames = 0
local lccWatcherConn = nil

local function BlobmanGucci()
    if State.blobGucci.processing then return end
    State.blobGucci.processing = true

    Library:Notify({ Title = "Blob Gucci", Description = "Starting...", Time = 2 })

    task.spawn(function()
        RemoveBlobUI()

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then
            State.blobGucci.processing = false
            return
        end

        safePosition = hrp.Position

        if not SpawnToyRemote then
            State.blobGucci.processing = false
            return
        end

        -- СЛЕДИМ ЗА LocalCreatureControl
        local playerModel = workspace:FindFirstChild(LocalPlayer.Name)
        if playerModel then
            if lccWatcherConn then lccWatcherConn:Disconnect() end
            lccWatcherConn = playerModel.DescendantAdded:Connect(function(obj)
                if obj.Name == "LocalCreatureControl" then
                    pcall(function() obj:Destroy() end)
                end
            end)
            pcall(function()
                local lcc = playerModel:FindFirstChild("LocalCreatureControl", true)
                if lcc then lcc:Destroy() end
            end)
        end

        -- УДАЛЯЕМ СТАРЫЙ БЛОБ ПЕРЕД СПАВНОМ
        pcall(function()
            local myToys = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if myToys then
                local oldBlob = myToys:FindFirstChild("GucciBlob")
                if oldBlob then
                    DestroyToy:FireServer(oldBlob)
                    task.wait(0.2)
                end
                local oldBlob2 = myToys:FindFirstChild("CreatureBlobman")
                if oldBlob2 then
                    DestroyToy:FireServer(oldBlob2)
                    task.wait(0.2)
                end
            end
        end)

        -- СПАВНИМ СРАЗУ НА ВЫСОТЕ 5000000
        pcall(function()
            SpawnToyRemote:InvokeServer(
                "CreatureBlobman",
                CFrame.new(0, 5000000, 0),
                Vector3.new(0, 60, 0)
            )
        end)

        -- БЫСТРЫЙ поиск блоба и переименование в GucciBlob
        local blob = nil
        local startTime = tick()
        repeat
            task.wait(0.02)
            local myToys = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if myToys then
                local found = myToys:FindFirstChild("CreatureBlobman")
                if found then
                    pcall(function() found.Name = "GucciBlob" end)
                    blob = found
                end
                if not blob then
                    blob = myToys:FindFirstChild("GucciBlob")
                end
            end
        until blob or (tick() - startTime) > 1

        if not blob then
            State.blobGucci.processing = false
            if lccWatcherConn then lccWatcherConn:Disconnect(); lccWatcherConn = nil end
            Library:Notify({ Title = "Blob Gucci", Description = "Blob not found!", Time = 2 })
            return
        end

        -- ЯКОРИМ HEAD СРАЗУ НА ВЫСОТЕ
        local blobHead = blob:FindFirstChild("Head")
        if blobHead then
            pcall(function()
                blobHead.CFrame = CFrame.new(0, 50000, 0)
                blobHead.Anchored = true
            end)
        end

        -- БЫСТРЫЙ поиск VehicleSeat
        local vehicleSeat = nil
        local seatStart = tick()
        repeat
            task.wait(0.02)
            vehicleSeat = blob:FindFirstChildWhichIsA("VehicleSeat")
        until vehicleSeat or (tick() - seatStart) > 0.5

        if not vehicleSeat then
            State.blobGucci.processing = false
            if lccWatcherConn then lccWatcherConn:Disconnect(); lccWatcherConn = nil end
            Library:Notify({ Title = "Blob Gucci", Description = "VehicleSeat not found!", Time = 2 })
            return
        end

        -- Садимся СРАЗУ
        hrp.CFrame = vehicleSeat.CFrame * CFrame.new(0, 2, 0)
        vehicleSeat:Sit(humanoid)

        -- RagdollRemote спам через Heartbeat
        local RagdollRemote = CharacterEvents and CharacterEvents:FindFirstChild("RagdollRemote")

        if antiGucciConnection then antiGucciConnection:Disconnect() end

        antiGucciConnection = RunService.Heartbeat:Connect(function()
            if not hrp or not humanoid then return end
            
            if RagdollRemote then
                pcall(function() RagdollRemote:FireServer(hrp, 0) end)
            end
            
            if restoreFrames > 0 then
                hrp.CFrame = CFrame.new(safePosition)
                restoreFrames = restoreFrames - 1
            end

            -- ДЕРЖИМ HEAD ЗАЯКОРЕННЫМ НА ВЫСОТЕ
            if blobHead and blobHead.Parent then
                pcall(function()
                    blobHead.Anchored = true
                    if blobHead.Position.Y < 9000 then
                        blobHead.CFrame = CFrame.new(0, 50000, 0)
                    end
                end)
            end
        end)

        humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
            if humanoid.Jump and humanoid.Sit then
                restoreFrames = 15
                safePosition = hrp.Position
            end
        end)

        -- Ждём пока не слезем
        task.spawn(function()
            while humanoid.Sit do
                task.wait(0.05)
            end

            task.wait(0.1)

            -- Разякориваем head
            if blobHead then
                pcall(function() blobHead.Anchored = false end)
            end

            -- ПОСЛЕ ТОГО КАК СЛЕЗЛИ
            local playerModel2 = workspace:FindFirstChild(LocalPlayer.Name)
            if playerModel2 then
                -- GrabbingScript disable/enable
                task.spawn(function()
                    for i = 1, 20 do
                        pcall(function()
                            local grabbingScript = playerModel2:FindFirstChild("GrabbingScript", true)
                            if grabbingScript and grabbingScript:IsA("Script") then
                                grabbingScript.Disabled = true
                                task.wait(0.01)
                                grabbingScript.Disabled = false
                            end
                        end)
                        task.wait(0.01)
                    end
                end)

                -- CamPart удаляем
                task.spawn(function()
                    for i = 1, 20 do
                        pcall(function()
                            local camPart = playerModel2:FindFirstChild("CamPart", true)
                            if camPart then camPart:Destroy() end
                        end)
                        task.wait(0.01)
                    end
                end)

                -- LocalCreatureControl финально
                task.spawn(function()
                    for i = 1, 20 do
                        pcall(function()
                            local lcc = playerModel2:FindFirstChild("LocalCreatureControl", true)
                            if lcc then lcc:Destroy() end
                        end)
                        task.wait(0.01)
                    end
                end)
            end

            -- Возвращаем на старую позицию
            if hrp and hrp.Parent and safePosition then
                for i = 1, 3 do
                    task.wait(0.05)
                    if hrp and hrp.Parent then
                        hrp.CFrame = CFrame.new(safePosition)
                    end
                end
            end

            -- Очищаем всё
            if antiGucciConnection then
                antiGucciConnection:Disconnect()
                antiGucciConnection = nil
            end

            if lccWatcherConn then
                lccWatcherConn:Disconnect()
                lccWatcherConn = nil
            end

            State.blobGucci.processing = false
            Library:Notify({ Title = "Blob Gucci", Description = "Completed!", Time = 2 })
        end)
    end)
end

-- ===================== TRACTOR GUCCI =====================
local safeTractorPosition = nil
local antiTractorConnection = nil
local restoreTractorFrames = 0

local function TractorGucci()
    if State.blobGucci.processing then return end
    State.blobGucci.processing = true

    Library:Notify({ Title = "Tractor Gucci", Description = "Starting...", Time = 2 })

    task.spawn(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then
            State.blobGucci.processing = false
            return
        end

        safeTractorPosition = hrp.Position

        if not SpawnToyRemote then
            State.blobGucci.processing = false
            return
        end

        -- УДАЛЯЕМ СТАРЫЙ ТРАКТОР ПЕРЕД СПАВНОМ
        pcall(function()
            local myToys = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if myToys then
                local oldTractor = myToys:FindFirstChild("TractorGucci")
                if oldTractor then
                    DestroyToy:FireServer(oldTractor)
                    task.wait(0.2)
                end
                local oldTractor2 = myToys:FindFirstChild("TractorOrange")
                if oldTractor2 then
                    DestroyToy:FireServer(oldTractor2)
                    task.wait(0.2)
                end
            end
        end)

        -- СПАВНИМ ТРАКТОР НА ВЫСОТЕ 5000000
        pcall(function()
            SpawnToyRemote:InvokeServer(
                "TractorOrange",
                CFrame.new(0, 5000000, 0),
                Vector3.new(0, 60, 0)
            )
        end)

        -- БЫСТРЫЙ поиск трактора и переименование в TractorGucci
        local tractor = nil
        local startTime = tick()
        repeat
            task.wait(0.02)
            local myToys = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if myToys then
                local found = myToys:FindFirstChild("TractorOrange")
                if found then
                    pcall(function() found.Name = "TractorGucci" end)
                    tractor = found
                end
                if not tractor then
                    tractor = myToys:FindFirstChild("TractorGucci")
                end
            end
        until tractor or (tick() - startTime) > 1

        if not tractor then
            State.blobGucci.processing = false
            Library:Notify({ Title = "Tractor Gucci", Description = "Tractor not found!", Time = 2 })
            return
        end

        -- ЯКОРИМ MAIN PART СРАЗУ НА ВЫСОТЕ
        local tractorMain = tractor:FindFirstChild("Main")
        if tractorMain then
            pcall(function()
                tractorMain.CFrame = CFrame.new(0, 50000, 0)
                tractorMain.Anchored = true
            end)
        end

        -- БЫСТРЫЙ поиск VehicleSeat
        local vehicleSeat = nil
        local seatStart = tick()
        repeat
            task.wait(0.02)
            vehicleSeat = tractor:FindFirstChildWhichIsA("VehicleSeat")
        until vehicleSeat or (tick() - seatStart) > 0.5

        if not vehicleSeat then
            State.blobGucci.processing = false
            Library:Notify({ Title = "Tractor Gucci", Description = "VehicleSeat not found!", Time = 2 })
            return
        end

        -- Садимся СРАЗУ
        hrp.CFrame = vehicleSeat.CFrame * CFrame.new(0, 2, 0)
        vehicleSeat:Sit(humanoid)

        -- RagdollRemote спам через Heartbeat
        local RagdollRemote = CharacterEvents and CharacterEvents:FindFirstChild("RagdollRemote")

        if antiTractorConnection then antiTractorConnection:Disconnect() end

        antiTractorConnection = RunService.Heartbeat:Connect(function()
            if not hrp or not humanoid then return end
            
            if RagdollRemote then
                pcall(function() RagdollRemote:FireServer(hrp, 0) end)
            end
            
            if restoreTractorFrames > 0 then
                hrp.CFrame = CFrame.new(safeTractorPosition)
                restoreTractorFrames = restoreTractorFrames - 1
            end

            -- ДЕРЖИМ MAIN ЗАЯКОРЕННЫМ НА ВЫСОТЕ
            if tractorMain and tractorMain.Parent then
                pcall(function()
                    tractorMain.Anchored = true
                    if tractorMain.Position.Y < 9000 then
                        tractorMain.CFrame = CFrame.new(0, 50000, 0)
                    end
                end)
            end
        end)

        humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
            if humanoid.Jump and humanoid.Sit then
                restoreTractorFrames = 15
                safeTractorPosition = hrp.Position
            end
        end)

        -- Ждём пока не слезем
        task.spawn(function()
            while humanoid.Sit do
                task.wait(0.05)
            end

            task.wait(0.1)

            -- Разякориваем main
            if tractorMain then
                pcall(function() tractorMain.Anchored = false end)
            end

            -- ПОСЛЕ ТОГО КАК СЛЕЗЛИ - удаляем только CamPart
            local playerModel2 = workspace:FindFirstChild(LocalPlayer.Name)
            if playerModel2 then
                task.spawn(function()
                    for i = 1, 20 do
                        pcall(function()
                            local camPart = playerModel2:FindFirstChild("CamPart", true)
                            if camPart then camPart:Destroy() end
                        end)
                        task.wait(0.01)
                    end
                end)
            end

            -- Возвращаем на старую позицию
            if hrp and hrp.Parent and safeTractorPosition then
                for i = 1, 3 do
                    task.wait(0.05)
                    if hrp and hrp.Parent then
                        hrp.CFrame = CFrame.new(safeTractorPosition)
                    end
                end
            end

            -- Очищаем всё
            if antiTractorConnection then
                antiTractorConnection:Disconnect()
                antiTractorConnection = nil
            end

            State.blobGucci.processing = false
            Library:Notify({ Title = "Tractor Gucci", Description = "Completed!", Time = 2 })
        end)
    end)
end

local function TrainGucci()
    Library:Notify({ Title = "Gucci", Description = "Train Gucci (Coming Soon)", Time = 2 })
end
-- ===================== SNOWBALL =====================
local function FindSnowball()
    local folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if not folder then return nil end
    for _, v in pairs(folder:GetChildren()) do
        if v.Name == "BallSnowball" then return v end
    end
    return nil
end

local function GetSnowballRoot(toy)
    if not toy then return nil end
    if toy:IsA("BasePart") then return toy end
    return toy.PrimaryPart or toy:FindFirstChild("SoundPart") or toy:FindFirstChildWhichIsA("BasePart")
end

local function ClearSnowballVars()
    if State.snowball.touchLoop then
        pcall(function() State.snowball.touchLoop:Disconnect() end)
        State.snowball.touchLoop = nil
    end
    State.snowball.obj = nil
    State.snowball.root = nil
    State.snowball.spawning = false
    State.snowball.spawnTime = 0
end

local function DestroySnowball()
    pcall(function()
        local toy = State.snowball.obj or FindSnowball()
        if toy and DestroyToy then
            local root = State.snowball.root or GetSnowballRoot(toy)
            if root then DestroyToy:FireServer(root) end
            DestroyToy:FireServer(toy)
        end
    end)
    ClearSnowballVars()
end

local function SpawnSnowball()
    if State.snowball.spawning then return end
    State.snowball.spawning = true
    task.spawn(function()
        if not State.snowball.active or not State.currentTarget then State.snowball.spawning = false return end
        if not SpawnToyRemote then State.snowball.spawning = false return end
        local canSpawn = LocalPlayer:FindFirstChild("CanSpawnToy")
        if canSpawn then
            local t = tick()
            while not canSpawn.Value do
                if not State.snowball.active or not State.kickActive or tick() - t > 3 then
                    State.snowball.spawning = false return
                end
                task.wait(0.02)
            end
        end
        local tChar = State.currentTarget and State.currentTarget.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHRP then State.snowball.spawning = false return end
        task.spawn(function()
            pcall(function()
                SpawnToyRemote:InvokeServer("BallSnowball", CFrame.new(0, 10000, 0), Vector3.zero)
            end)
        end)
        local toy = nil
        local waitT = tick()
        repeat
            task.wait()
            toy = FindSnowball()
        until toy or not State.snowball.active or not State.kickActive or tick() - waitT > 5
        if not toy or not State.snowball.active or not State.kickActive then
            State.snowball.spawning = false return
        end
        local soundPart = toy:FindFirstChild("SoundPart")
        if not soundPart then State.snowball.spawning = false return end
        State.snowball.obj = toy
        State.snowball.root = soundPart
        State.snowball.spawnTime = tick()
        pcall(function()
            for _, part in pairs(toy:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Massless = true
                end
            end
        end)
        SetCollisionGroup(toy, PALLET_GROUP)
        pcall(function()
            setOwner:FireServer(soundPart, soundPart.CFrame)
        end)
        local tChar2 = State.currentTarget and State.currentTarget.Character
        local targetPart = tChar2 and (
            tChar2:FindFirstChild("Head")
            or tChar2:FindFirstChild("UpperTorso")
            or tChar2:FindFirstChild("Torso")
            or tChar2:FindFirstChild("HumanoidRootPart")
        )
        if not targetPart then State.snowball.spawning = false return end
        local bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 100000
        bp.D = 500
        bp.Position = targetPart.Position
        bp.Parent = soundPart
        task.wait(0.2)
        local tChar3 = State.currentTarget and State.currentTarget.Character
        local hitPart = tChar3 and (
            tChar3:FindFirstChild("Head")
            or tChar3:FindFirstChild("UpperTorso")
            or tChar3:FindFirstChild("Torso")
            or tChar3:FindFirstChild("HumanoidRootPart")
        )
        if hitPart and soundPart and soundPart.Parent then
            pcall(function()
                local dirs = {
                    hitPart.CFrame.LookVector,
                    -hitPart.CFrame.LookVector,
                    hitPart.CFrame.RightVector,
                    -hitPart.CFrame.RightVector,
                }
                local dir = dirs[math.random(1, #dirs)]
                local launchPos = hitPart.Position + dir * 35 + Vector3.new(0, 5, 0)
                soundPart.CFrame = CFrame.new(launchPos)
                local toTarget = (hitPart.Position - launchPos).Unit
                soundPart.AssemblyLinearVelocity = toTarget * 9999
                soundPart.AssemblyAngularVelocity = Vector3.zero
                bp.Position = hitPart.Position
            end)
            if tChar3 then
                for _, part in pairs(tChar3:GetChildren()) do
                    if part:IsA("BasePart") then
                        pcall(function()
                            firetouchinterest(soundPart, part, 0)
                            firetouchinterest(soundPart, part, 1)
                        end)
                    end
                end
            end
        end
        pcall(function() bp:Destroy() end)
        if State.snowball.touchLoop then
            pcall(function() State.snowball.touchLoop:Disconnect() end)
        end
        State.snowball.touchLoop = RunService.Heartbeat:Connect(function()
            if not State.snowball.active or not soundPart or not soundPart.Parent then
                if State.snowball.touchLoop then State.snowball.touchLoop:Disconnect(); State.snowball.touchLoop = nil end
                return
            end
            local tc = State.currentTarget and State.currentTarget.Character
            if not tc then return end
            for _, part in pairs(tc:GetChildren()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        firetouchinterest(soundPart, part, 0)
                        firetouchinterest(soundPart, part, 1)
                    end)
                end
            end
        end)
        State.snowball.spawning = false
    end)
end

local function StartSnowball()
    State.snowball.active = true
    local respawnCooldown = 0
    State.snowball.conn = RunService.Heartbeat:Connect(function(dt)
        if not State.snowball.active then return end
        respawnCooldown -= dt
        if not State.kickActive or not State.currentTarget then
            if State.snowball.obj and State.snowball.obj.Parent then DestroySnowball() end
            return
        end
        if State.snowball.obj and not State.snowball.obj.Parent then
            ClearSnowballVars()
            respawnCooldown = 0
            return
        end
        if State.snowball.obj and State.snowball.spawnTime > 0 and tick() - State.snowball.spawnTime > State.snowball.lifetime then
            DestroySnowball()
            respawnCooldown = 0
            return
        end
        if not State.snowball.obj and respawnCooldown <= 0 and not State.snowball.spawning then
            respawnCooldown = 0.5
            SpawnSnowball()
        end
    end)
end

local function StopSnowball()
    State.snowball.active = false
    if State.snowball.conn then State.snowball.conn:Disconnect(); State.snowball.conn = nil end
    if State.snowball.touchLoop then
        pcall(function() State.snowball.touchLoop:Disconnect() end)
        State.snowball.touchLoop = nil
    end
    task.wait(0.05)
    DestroySnowball()
end

local function ToggleSnowball(value)
    State.snowball.active = value
    if value then StartSnowball() else StopSnowball() end
end

-- ===================== RAGDOLL PALLET =====================
local function GetMyToys()
    return workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end

local function SpawnRagdollPallet()
    if not SpawnToyRemote then return end
    local myToys = GetMyToys()
    if not myToys then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local canSpawn = LocalPlayer:FindFirstChild("CanSpawnToy")
    if canSpawn then
        local t = tick()
        while not canSpawn.Value do
            if tick() - t > 5 then return end
            task.wait(0.1)
        end
    end
    task.spawn(function()
        pcall(function()
            SpawnToyRemote:InvokeServer("PalletLightBrown", hrp.CFrame, Vector3.new(0, -90, 0))
        end)
    end)
    State.ragdoll.pallet = myToys:WaitForChild("PalletLightBrown", 5)
    if not State.ragdoll.pallet then return end
    State.ragdoll.palletPart = State.ragdoll.pallet:WaitForChild("SoundPart", 5)
    State.ragdoll.palletMain = State.ragdoll.pallet:WaitForChild("Main", 5)
    if not State.ragdoll.palletPart or not State.ragdoll.palletMain then return end
    pcall(function() setOwner:FireServer(State.ragdoll.palletPart, State.ragdoll.palletPart.CFrame) end)
    task.wait(0.1)
    for _, part in pairs(State.ragdoll.pallet:GetChildren()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = false; part.CanQuery = false end)
        end
    end
    local att = State.ragdoll.pallet:FindFirstChild("Attachment") or Instance.new("Attachment", State.ragdoll.palletPart)
    State.ragdoll.spin = Instance.new("AngularVelocity")
    State.ragdoll.spin.Name = "RagdollGrabSpin"
    State.ragdoll.spin.MaxTorque = math.huge
    State.ragdoll.spin.AngularVelocity = Vector3.new(0, 0, 0)
    State.ragdoll.spin.RelativeTo = Enum.ActuatorRelativeTo.World
    State.ragdoll.spin.Attachment0 = att
    State.ragdoll.spin.Parent = State.ragdoll.palletPart
    State.ragdoll.position = Instance.new("BodyPosition")
    State.ragdoll.position.Name = "RagdollGrabPosition"
    State.ragdoll.position.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    State.ragdoll.position.D = 100
    State.ragdoll.position.Position = Vector3.new(0, 10000, 0)
    State.ragdoll.position.Parent = State.ragdoll.palletMain
end

local function DestroyRagdollPallet()
    pcall(function()
        if State.ragdoll.spin then State.ragdoll.spin:Destroy(); State.ragdoll.spin = nil end
        if State.ragdoll.position then State.ragdoll.position:Destroy(); State.ragdoll.position = nil end
        if State.ragdoll.pallet and State.ragdoll.pallet.Parent then
            if DestroyToy then
                if State.ragdoll.palletPart then DestroyToy:FireServer(State.ragdoll.palletPart) end
                DestroyToy:FireServer(State.ragdoll.pallet)
            end
        end
    end)
    State.ragdoll.pallet = nil; State.ragdoll.palletPart = nil; State.ragdoll.palletMain = nil
end

local function StartRagdoll()
    State.ragdoll.active = true
    task.spawn(function()
        SpawnRagdollPallet()
        local ragdollFrame = 0
        State.ragdoll.conn = RunService.Heartbeat:Connect(function()
            if not State.ragdoll.active then return end
            if not State.ragdoll.palletPart or not State.ragdoll.palletPart.Parent then return end
            ragdollFrame += 1
            if State.kickActive and State.currentTarget and State.currentTarget.Character then
                local targetChar = State.currentTarget.Character
                local torso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
                if torso and ragdollFrame % 10 == 0 then
                    pcall(function()
                        setOwner:FireServer(State.ragdoll.palletPart, State.ragdoll.palletPart.CFrame)
                        State.ragdoll.palletPart.CFrame = torso.CFrame * CFrame.new(0, 1.2, 0)
                        State.ragdoll.palletPart.Velocity = Vector3.new(0, -10, 0)
                        State.ragdoll.palletPart.RotVelocity = Vector3.new(0, 0, 0)
                    end)
                end
            else
                if State.ragdoll.position then
                    State.ragdoll.position.Position = Vector3.new(0, 10000, 0)
                end
                pcall(function()
                    State.ragdoll.palletPart.Velocity = Vector3.zero
                    State.ragdoll.palletPart.RotVelocity = Vector3.zero
                end)
            end
        end)
    end)
end

local function StopRagdoll()
    State.ragdoll.active = false
    if State.ragdoll.conn then State.ragdoll.conn:Disconnect(); State.ragdoll.conn = nil end
    DestroyRagdollPallet()
end

local function ToggleRagdoll(value)
    State.ragdoll.active = value
    if value then StartRagdoll() else StopRagdoll() end
end

-- ===================== ANTIGRAB =====================
local Limbs = {"Right Arm", "Left Arm", "Right Leg", "Left Leg"}

local function DisableBallSockets(char)
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
            pcall(function() v.BallSocketConstraint.Enabled = false end)
            if v:FindFirstChild("RagdollLimbPart") then
                pcall(function() v.RagdollLimbPart.WeldConstraint.Enabled = false end)
            end
        end
    end
end

local function SetupAntiGrabChar(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:WaitForChild("Humanoid", 5)
    local head = char:WaitForChild("Head", 5)
    if not hrp or not hum or not head then return end
    DisableBallSockets(char)
    head.ChildAdded:Connect(function(obj)
        if obj.Name ~= "PartOwner" then return end
        if State.antiGrab.proc then return end
        State.antiGrab.proc = true
        hrp.Anchored = true
        task.spawn(function()
            while head:FindFirstChild("PartOwner") or (LocalPlayer:FindFirstChild("IsHeld") and LocalPlayer.IsHeld.Value) do
                pcall(function()
                    if Struggle then
                        Struggle:FireServer(LocalPlayer)
                        Struggle:FireServer(LocalPlayer)
                        Struggle:FireServer(LocalPlayer)
                    end
                end)
                task.wait()
            end
        end)
        repeat task.wait() until
            not head:FindFirstChild("PartOwner") and
            not (LocalPlayer:FindFirstChild("IsHeld") and LocalPlayer.IsHeld.Value)
        hrp.Anchored = false
        State.antiGrab.proc = false
    end)
end

local function StartAntiGrab()
    if State.antiGrab.conn then State.antiGrab.conn:Disconnect(); State.antiGrab.conn = nil end
    local running = true
    State.antiGrab.conn = { Disconnect = function() running = false end }
    local char = LocalPlayer.Character
    if char then SetupAntiGrabChar(char) end
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        if not running then return end
        State.antiGrab.proc = false
        task.wait(0.5)
        SetupAntiGrabChar(newChar)
    end)
end

local function StopAntiGrab()
    if State.antiGrab.conn then State.antiGrab.conn:Disconnect(); State.antiGrab.conn = nil end
    State.antiGrab.proc = false
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = false end
end

local function ToggleAntiGrab(value)
    State.antiGrab.active = value
    if value then StartAntiGrab()
    else if not State.kickActive then StopAntiGrab() end end
end

-- ===================== ANTI RAGDOLL =====================
local RagdollRemote = CharacterEvents and CharacterEvents:FindFirstChild("RagdollRemote")

local function StartAntiRagdoll()
    State.antiRagdoll.active = true
    if State.antiRagdoll.conn then State.antiRagdoll.conn:Disconnect(); State.antiRagdoll.conn = nil end

    local function SetupAntiRagdollChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        local head = char:WaitForChild("Head", 5)
        if not hum or not hrp or not head then return end

        local antiRagdollProc = false -- защита от двойного клика!

        -- Отключаем BallSockets сразу
        DisableBallSockets(char)

        -- СЛЕДИМ ЗА ГРАБОМ
        head.ChildAdded:Connect(function(obj)
            if not State.antiRagdoll.active then return end
            if obj.Name ~= "PartOwner" then return end
            if antiRagdollProc then return end -- УЖЕ ОБРАБАТЫВАЕМ - выходим!

            antiRagdollProc = true
            hrp.Anchored = true

            -- Даём регдолл через Remote (не каждый кадр а каждые 0.1!)
            task.spawn(function()
                while head:FindFirstChild("PartOwner") or
                      (LocalPlayer:FindFirstChild("IsHeld") and LocalPlayer.IsHeld.Value) do
                    if not State.antiRagdoll.active then break end
                    pcall(function()
                        if RagdollRemote then
                            RagdollRemote:FireServer(hrp, 0)
                        end
                        if Struggle then
                            Struggle:FireServer(LocalPlayer)
                        end
                    end)
                    task.wait(0.1) -- каждые 0.1 сек а не каждый кадр!
                end
            end)

            -- Двигаемся через CFrame пока держат
-- ===================== ANTI RAGDOLL =====================
local RagdollRemote = CharacterEvents and CharacterEvents:FindFirstChild("RagdollRemote")

local function StartAntiRagdoll()
    State.antiRagdoll.active = true
    if State.antiRagdoll.conn then State.antiRagdoll.conn:Disconnect(); State.antiRagdoll.conn = nil end

    local function SetupAntiRagdollChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        local head = char:WaitForChild("Head", 5)
        if not hum or not hrp or not head then return end

        local antiRagdollProc = false -- защита от двойного клика

        -- Отключаем BallSockets сразу
        DisableBallSockets(char)

        -- СЛЕДИМ ЗА ГРАБОМ (PartOwner появился)
        head.ChildAdded:Connect(function(obj)
            if not State.antiRagdoll.active then return end
            if obj.Name ~= "PartOwner" then return end
            if antiRagdollProc then return end -- уже обрабатываем

            antiRagdollProc = true
            
            -- НЕ ЯКОРИМ! Позволяем нормальное движение

            -- Спам регдолла и struggle для выскальзывания  
            task.spawn(function()
                while head:FindFirstChild("PartOwner") or
                      (LocalPlayer:FindFirstChild("IsHeld") and LocalPlayer.IsHeld.Value) do
                    if not State.antiRagdoll.active then break end
                    pcall(function()
                        if RagdollRemote then 
                            RagdollRemote:FireServer(hrp, 0) 
                        end
                        if Struggle then 
                            Struggle:FireServer(LocalPlayer) 
                        end
                    end)
                    task.wait(0.1) -- не спамим каждый кадр
                end
                
                antiRagdollProc = false
            end)

            -- Легкая защита от улёта (но не блокируем движение)
            task.spawn(function()
                while head:FindFirstChild("PartOwner") or
                      (LocalPlayer:FindFirstChild("IsHeld") and LocalPlayer.IsHeld.Value) do
                    if not State.antiRagdoll.active then break end
                    
                    if hrp and hrp.Parent then
                        -- Если летим слишком быстро - немного тормозим
                        if hrp.AssemblyLinearVelocity.Magnitude > 150 then
                            hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * 0.8
                        end
                        
                        -- Если крутимся - останавливаем вращение
                        if hrp.AssemblyAngularVelocity.Magnitude > 15 then
                            hrp.AssemblyAngularVelocity = Vector3.zero
                        end
                    end
                    
                    task.wait()
                end
            end)
        end)

        -- Следим за Ragdolled value (блокируем регдолл если НЕ в грабе)
        local ragdolledVal = hum:FindFirstChild("Ragdolled")
        if ragdolledVal then
            ragdolledVal.Changed:Connect(function()
                if not State.antiRagdoll.active then return end
                local isGrabbed = head:FindFirstChild("PartOwner") ~= nil
                
                if ragdolledVal.Value and not isGrabbed then
                    -- Регдолл БЕЗ граба - блокируем
                    DisableBallSockets(char)
                    hum.PlatformStand = false
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
                -- В грабе регдолл разрешаем (помогает выскользнуть)
            end)
        end

        -- Новые BallSockets (отключаем если не в грабе)
        char.DescendantAdded:Connect(function(obj)
            if not State.antiRagdoll.active then return end
            if head:FindFirstChild("PartOwner") then return end -- в грабе не трогаем
            
            if obj:IsA("BallSocketConstraint") and obj.Parent and obj.Parent.Name ~= "Head" then
                task.wait()
                pcall(function()
                    obj.Enabled = false
                    if obj.Parent:FindFirstChild("RagdollLimbPart") then
                        obj.Parent.RagdollLimbPart.WeldConstraint.Enabled = false
                    end
                end)
            end
        end)
    end

    -- Heartbeat для анти-регдолла (только если НЕ в грабе)
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        if not State.antiRagdoll.active then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not hum or not hrp or not head then return end

        local isGrabbed = head:FindFirstChild("PartOwner") ~= nil

        -- Анти-регдолл только если НЕ в грабе
        if not isGrabbed then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Physics or
               state == Enum.HumanoidStateType.Ragdoll or
               state == Enum.HumanoidStateType.FallingDown then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                DisableBallSockets(char)
                -- Сбрасываем скорость если летим
                if hrp.AssemblyLinearVelocity.Magnitude > 50 then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end

            if hum.PlatformStand then hum.PlatformStand = false end
            if hum.Sit then hum.Sit = false end

            -- Отключаем BallSockets
            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") and part:FindFirstChild("BallSocketConstraint") and part.Name ~= "Head" then
                    pcall(function()
                        part.BallSocketConstraint.Enabled = false
                        if part:FindFirstChild("RagdollLimbPart") then
                            part.RagdollLimbPart.WeldConstraint.Enabled = false
                        end
                    end)
                end
            end
        end
    end)

    State.antiRagdoll.conn = {
        Disconnect = function()
            if heartbeatConn then heartbeatConn:Disconnect() end
        end
    }

    -- Настраиваем текущего персонажа
    local char = LocalPlayer.Character
    if char then SetupAntiRagdollChar(char) end

    -- При респавне
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        if not State.antiRagdoll.active then return end
        task.wait(0.5)
        SetupAntiRagdollChar(newChar)
    end)
end

local function StopAntiRagdoll()
    State.antiRagdoll.active = false
    if State.antiRagdoll.conn then
        State.antiRagdoll.conn:Disconnect()
        State.antiRagdoll.conn = nil
    end
end

local function ToggleAntiRagdoll(value)
    State.antiRagdoll.active = value
    if value then StartAntiRagdoll() else StopAntiRagdoll() end
end        end)

        -- Следим за Ragdolled (блокируем если не в грабе)
        local ragdolledVal = hum:FindFirstChild("Ragdolled")
        if ragdolledVal then
            ragdolledVal.Changed:Connect(function()
                if not State.antiRagdoll.active then return end
                local isGrabbed = head:FindFirstChild("PartOwner") ~= nil
                if ragdolledVal.Value and not isGrabbed then
                    DisableBallSockets(char)
                    hum.PlatformStand = false
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
        end

        -- Новые BallSockets (только если не в грабе)
        char.DescendantAdded:Connect(function(obj)
            if not State.antiRagdoll.active then return end
            if head:FindFirstChild("PartOwner") then return end
            if obj:IsA("BallSocketConstraint") and obj.Parent and obj.Parent.Name ~= "Head" then
                task.wait()
                pcall(function()
                    obj.Enabled = false
                    if obj.Parent:FindFirstChild("RagdollLimbPart") then
                        obj.Parent.RagdollLimbPart.WeldConstraint.Enabled = false
                    end
                end)
            end
        end)
    end

    -- Heartbeat только для анти-регдолла без граба
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        if not State.antiRagdoll.active then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not hum or not hrp or not head then return end

        local isGrabbed = head:FindFirstChild("PartOwner") ~= nil

        if not isGrabbed then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Physics or
               state == Enum.HumanoidStateType.Ragdoll or
               state == Enum.HumanoidStateType.FallingDown then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                DisableBallSockets(char)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end

            if hum.PlatformStand then hum.PlatformStand = false end

            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") and part:FindFirstChild("BallSocketConstraint") and part.Name ~= "Head" then
                    pcall(function()
                        part.BallSocketConstraint.Enabled = false
                        if part:FindFirstChild("RagdollLimbPart") then
                            part.RagdollLimbPart.WeldConstraint.Enabled = false
                        end
                    end)
                end
            end
        end
    end)

    State.antiRagdoll.conn = {
        Disconnect = function()
            if heartbeatConn then heartbeatConn:Disconnect() end
        end
    }

    local char = LocalPlayer.Character
    if char then SetupAntiRagdollChar(char) end

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        if not State.antiRagdoll.active then return end
        task.wait(0.5)
        SetupAntiRagdollChar(newChar)
    end)
end

local function StopAntiRagdoll()
    State.antiRagdoll.active = false
    if State.antiRagdoll.conn then
        State.antiRagdoll.conn:Disconnect()
        State.antiRagdoll.conn = nil
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = false end
end

local function ToggleAntiRagdoll(value)
    State.antiRagdoll.active = value
    if value then StartAntiRagdoll() else StopAntiRagdoll() end
end
-- ===================== ANTI EXPLODE =====================
local function StartAntiExplode()
    if not BombEvent then return end
    if State.antiExplode.conn then State.antiExplode.conn:Disconnect(); State.antiExplode.conn = nil end
    State.antiExplode.conn = BombEvent.OnClientEvent:Connect(function(tbl, pos)
        if not State.antiExplode.active then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        task.spawn(function()
            local radius = tbl and tbl["Radius"] or 0
            if radius + 10 > (pos - hrp.Position).Magnitude then
                hrp.Anchored = true
                task.wait()
                hum:ChangeState(Enum.HumanoidStateType.Running)
                hrp.Anchored = false
                for i = 1, 4 do
                    local limb = char:FindFirstChild(Limbs[i])
                    if limb and limb:FindFirstChild("RagdollLimbPart") then
                        limb.RagdollLimbPart.CanCollide = false
                    end
                end
            end
        end)
    end)
end

local function StopAntiExplode()
    State.antiExplode.active = false
    if State.antiExplode.conn then State.antiExplode.conn:Disconnect(); State.antiExplode.conn = nil end
end

local function ToggleAntiExplode(value)
    State.antiExplode.active = value
    if value then StartAntiExplode() else StopAntiExplode() end
end

-- ===================== SHURIKEN =====================
local shurikenToys = {
    "NinjaShuriken", "NinjaKunai", "NinjaKatana",
    "ToolCleaver", "ToolDiggingForkRusty", "ToolPencil", "ToolPickaxe",
}

local function GetHRP()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return LocalPlayer.Character.HumanoidRootPart
    end
    local char = LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function ClearShuriken()
    local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if not inv or not setOwner then return end
    for _, v in pairs(inv:GetChildren()) do
        if v.Name == State.shuriken.toyType or v.Name == "AntiKick" then
            local sp = v:FindFirstChild("SoundPart")
            if sp then
                task.spawn(function()
                    pcall(function()
                        setOwner:FireServer(sp, sp.CFrame)
                        task.wait(0.05)
                        if DestroyToy then
                            DestroyToy:FireServer(sp)
                            DestroyToy:FireServer(v)
                        end
                    end)
                end)
            end
        end
    end
end

local function CheckForHome()
    if not workspace.PlotItems.PlayersInPlots:FindFirstChild(LocalPlayer.Name) then return false end
    for _, v in pairs(workspace.Plots:GetChildren()) do
        local sign = v:FindFirstChild("PlotSign")
        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
        if owners then
            for _, b in pairs(owners:GetChildren()) do
                if b.Value == LocalPlayer.Name then
                    local folder = workspace.PlotItems:FindFirstChild(v.Name)
                    if folder then return true, folder end
                end
            end
        end
    end
    return false
end

local function StickKunai(kunai)
    if not kunai or not kunai:FindFirstChild("StickyPart") then return end
    local hrp = GetHRP()
    if not hrp then return end
    if kunai:FindFirstChild("SoundPart") then
        local sp = kunai.SoundPart
        local po = sp:FindFirstChild("PartOwner")
        if not po or po.Value ~= LocalPlayer.Name then
            pcall(function() setOwner:FireServer(sp, sp.CFrame) end)
        end
    end
    local firePart = hrp:FindFirstChild("FirePlayerPart") or hrp:WaitForChild("FirePlayerPart", 5)
    if firePart and StickyPartEvent then
        pcall(function()
            StickyPartEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0,0,0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
        end)
    end
    for _, obj in pairs(kunai:GetChildren()) do
        pcall(function()
            if obj.Name == "Pyramid" then
                obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 0
                if not obj:FindFirstChild("Highlight") then
                    local h = Instance.new("Highlight", obj)
                    h.FillColor = Color3.fromRGB(0,0,0); h.OutlineColor = Color3.fromRGB(255,100,0)
                end
            elseif obj.Name == "Main" then
                obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 0
                if not obj:FindFirstChild("Highlight") then
                    local h = Instance.new("Highlight", obj)
                    h.FillColor = Color3.fromRGB(255,255,255); h.OutlineColor = Color3.fromRGB(255,200,0)
                end
            elseif obj:IsA("BasePart") then
                obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 1
            end
        end)
    end
end

local function SpawnShurikenToy()
    if not SpawnToyRemote then return nil end
    local canSpawn = LocalPlayer:WaitForChild("CanSpawnToy", 5)
    if not canSpawn then return nil end
    local t = tick()
    while not canSpawn.Value do
        if not State.shuriken.active or tick() - t > 5 then return nil end
        task.wait(0.1)
    end
    local hrp = GetHRP()
    if not hrp then return nil end
    task.spawn(function()
        pcall(function()
            SpawnToyRemote:InvokeServer(State.shuriken.toyType, hrp.CFrame * CFrame.new(0,12,20), Vector3.zero)
        end)
    end)
    local boolik, house = CheckForHome()
    local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if boolik and house then return house:WaitForChild(State.shuriken.toyType, 2)
    elseif inv then return inv:WaitForChild(State.shuriken.toyType, 2) end
    return nil
end

local function StartShuriken()
    _G.ShurikenAntiKick = true
    task.spawn(function()
        while _G.ShurikenAntiKick do
            task.wait(0.005)
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if not char or not hum or hum.Health <= 0 then continue end
            local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            local kunai = inv and inv:FindFirstChild("AntiKick")
            if workspace.PlotItems.PlayersInPlots:FindFirstChild(LocalPlayer.Name) then
                local boolik, house = CheckForHome()
                if boolik and house and workspace.Plots:FindFirstChild(house.Name) then
                    local sign = workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                    if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                        kunai = SpawnShurikenToy()
                        if not kunai then continue end
                        kunai.Name = "AntiKick"; StickKunai(kunai)
                    end
                end
            end
            if not kunai then
                if workspace.PlotItems.PlayersInPlots:FindFirstChild(LocalPlayer.Name) then continue end
                kunai = SpawnShurikenToy()
                if not kunai then continue end
                kunai.Name = "AntiKick"
            end
            repeat
                if kunai and kunai:FindFirstChild("StickyPart") and kunai.StickyPart.CanTouch == true then
                    StickKunai(kunai); kunai.Name = "AntiKick"
                end
                task.wait(0.3)
            until not _G.ShurikenAntiKick or not kunai or not kunai:FindFirstChild("StickyPart")
                or kunai.StickyPart.CanTouch == false or not char or not char:FindFirstChild("HumanoidRootPart")
                or (char.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20
            local hrp2 = char and char:FindFirstChild("HumanoidRootPart")
            if not kunai or not kunai:FindFirstChild("StickyPart") or not hrp2
                or (hrp2.Position - kunai.StickyPart.Position).Magnitude >= 20 then ClearShuriken() end
            pcall(function()
                repeat task.wait(0.05) until not _G.ShurikenAntiKick or not char
                    or not char:FindFirstChild("Humanoid") or not kunai
                    or not kunai:FindFirstChild("StickyPart")
                    or not kunai.StickyPart:FindFirstChild("StickyWeld")
                    or not kunai.StickyPart.StickyWeld.Part1
                if not kunai or not kunai:FindFirstChild("StickyPart")
                    or (char and char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0)
                    or not kunai.StickyPart:FindFirstChild("StickyWeld")
                    or not kunai.StickyPart.StickyWeld.Part1 then ClearShuriken() end
            end)
        end
    end)
end

local function StopShuriken()
    _G.ShurikenAntiKick = false; State.shuriken.active = false; ClearShuriken()
end

local function ToggleShuriken(value)
    State.shuriken.active = value
    if value then StartShuriken() else StopShuriken() end
end

-- ===================== KICK NOTIFY =====================
local function StartKickNotify()
    if State.kickNotify.conn then State.kickNotify.conn:Disconnect(); State.kickNotify.conn = nil end
    State.kickNotify.conn = workspace.ChildAdded:Connect(function(part)
        if not State.kickNotify.active then return end
        if part.Name ~= "BlackHoleKick" then return end
        local kicklist = {}
        local kicklistDis = {}
        part.Name = "BlackHoleDetected"
        for _, player in pairs(Players:GetPlayers()) do
            table.insert(kicklist, player.Name)
            table.insert(kicklistDis, player.DisplayName)
        end
        task.wait(3.25)
        if #kicklist - #Players:GetPlayers() > 1 then
            Library:Notify({ Title = "Kick Notify", Description = "Multiple players kicked (" .. #kicklist - #Players:GetPlayers() .. ")", Time = 5 })
            return
        end
        for i, player in ipairs(Players:GetPlayers()) do
            if player.Name ~= kicklist[i] then
                Library:Notify({ Title = "Kicked!", Description = kicklistDis[i] .. " (" .. kicklist[i] .. ") got kicked!", Time = 5, SoundId = 4590662766 })
                return
            end
            if #kicklist - #Players:GetPlayers() == 1 and i + 1 == #kicklist then
                Library:Notify({ Title = "Kicked!", Description = kicklistDis[i+1] .. " (" .. kicklist[i+1] .. ") got kicked!", Time = 5, SoundId = 4590662766 })
                return
            end
        end
    end)
end

local function StopKickNotify()
    State.kickNotify.active = false
    if State.kickNotify.conn then State.kickNotify.conn:Disconnect(); State.kickNotify.conn = nil end
end

local function ToggleKickNotify(value)
    State.kickNotify.active = value
    if value then StartKickNotify() else StopKickNotify() end
end

-- ===================== PACKET LAG =====================
local function StartPacketLag()
    if not ExtendGrabLine then 
        Library:Notify({ Title = "Packet Lag", Description = "ExtendGrabLine not found!", Time = 3 })
        return 
    end
    
    State.packetLag.active = true
    
    task.spawn(function()
        while State.packetLag.active do
            if ExtendGrabLine then
                -- Создаём строку для отправки пакета
                local dataString = string.rep("a", math.floor(State.packetLag.packetSize * 1024 * 1024))
                
                pcall(function()
                    ExtendGrabLine:FireServer(dataString)
                end)
            end
            
            task.wait(State.packetLag.cooldown)
        end
    end)
end

local function StopPacketLag()
    State.packetLag.active = false
    if State.packetLag.conn then 
        State.packetLag.conn:Disconnect() 
        State.packetLag.conn = nil 
    end
end

local function TogglePacketLag(value)
    State.packetLag.active = value
    if value then StartPacketLag() else StopPacketLag() end
end

-- ===================== PACKET DETECT =====================
local function GetSizeMB(StringLength)
    return StringLength / (1024 * 1024)
end

local function GetSizeKB(bytes)
    return bytes / 1024
end

local function StartPacketDetect()
    if not ExtendGrabLine then 
        Library:Notify({ Title = "Packet Detect", Description = "ExtendGrabLine not found!", Time = 3 })
        return 
    end
    
    State.packetDetect.active = true
    State.packetDetect.playerData = {}
    State.packetDetect.traffic = 0
    State.packetDetect.packetCount = 0
    
    if State.packetDetect.conn then State.packetDetect.conn:Disconnect() end
    
    State.packetDetect.conn = ExtendGrabLine.OnClientEvent:Connect(function(player, data)
        if not State.packetDetect.active then return end
        if not player or player == LocalPlayer then return end
        
        local playerName = tostring(player)
        local plrObj = Players:FindFirstChild(playerName)
        if not plrObj then return end
        
        -- Считаем размер пакета
        local packetSize = 0
        if typeof(data) == "string" then
            packetSize = string.len(data)
        elseif type(data) == "table" then
            for _, v in pairs(data) do
                if type(v) == "string" then packetSize = packetSize + #v
                elseif typeof(v) == "CFrame" then packetSize = packetSize + 48
                elseif typeof(v) == "Vector3" then packetSize = packetSize + 12
                else packetSize = packetSize + 8 end
            end
        end
        
        -- ПРОВЕРКА: Только пакеты больше 300 байт (реальные лаг-пакеты)
        if packetSize <= 300 then return end
        
        -- Инициализация данных игрока
        if not State.packetDetect.playerData[playerName] then
            State.packetDetect.playerData[playerName] = {
                packets = 0,
                size = 0,
                lastNotify = 0,
                startTime = tick(),
                inCooldown = false
            }
        end
        
        local pData = State.packetDetect.playerData[playerName]
        
        -- Обновляем статистику (только для больших пакетов)
        pData.packets = pData.packets + 1
        pData.size = pData.size + packetSize
        State.packetDetect.packetCount = State.packetDetect.packetCount + 1
        State.packetDetect.traffic = State.packetDetect.traffic + packetSize
        
        local now = tick()
        local elapsed = now - pData.startTime
        
        -- Нотифи только если прошло время cooldown
        if not pData.inCooldown and now - pData.lastNotify >= State.packetDetect.notifyCooldown then
            local packetsPerSec = math.floor(pData.packets / math.max(elapsed, 1))
            local avgSize = pData.packets > 0 and math.floor(pData.size / pData.packets) or 0
            local sizeMB = GetSizeMB(packetSize)
            local sizeKB = GetSizeKB(packetSize)
            
            -- Форматируем размер
            local sizeStr = sizeMB >= 0.001 and string.format("%.3f MB", sizeMB) or string.format("%.2f KB", sizeKB)
            
            Library:Notify({
                Title = "Packet Detected",
                Description = string.format(
                    "%s (@%s)\n%s\n%s\n%s",
                    plrObj.DisplayName,
                    plrObj.Name,
                    "Packets/s: " .. packetsPerSec,
                    "Size: " .. sizeStr,
                    "Avg: " .. avgSize .. " bytes"
                ),
                Time = 5,
                Icon = "wifi"
            })
            
            pData.lastNotify = now
            pData.inCooldown = true
            
            -- Сброс cooldown
            task.delay(State.packetDetect.notifyCooldown, function()
                if State.packetDetect.playerData[playerName] then
                    State.packetDetect.playerData[playerName].inCooldown = false
                end
            end)
        end
    end)
    
    -- Очистка при выходе игрока
    Players.PlayerRemoving:Connect(function(plr)
        if State.packetDetect.playerData[plr.Name] then
            State.packetDetect.playerData[plr.Name] = nil
        end
    end)
end

local function StopPacketDetect()
    State.packetDetect.active = false
    if State.packetDetect.conn then 
        State.packetDetect.conn:Disconnect() 
        State.packetDetect.conn = nil 
    end
    State.packetDetect.playerData = {}
    State.packetDetect.traffic = 0
    State.packetDetect.packetCount = 0
end

local function TogglePacketDetect(value)
    State.packetDetect.active = value
    if value then StartPacketDetect() else StopPacketDetect() end
end

-- ===================== SPEED KICK CORE =====================
local function KickPlayer(targetPlayer)
    if not targetPlayer then return end
    if State.activeKicks[targetPlayer] then
        State.activeKicks[targetPlayer]()
        State.activeKicks[targetPlayer] = nil
    end
    local kickActive_local = true
    task.spawn(function()
        local lastTick = tick()
        while kickActive_local do
            if not targetPlayer or not targetPlayer.Parent then break end
            local now = tick()
            local dt = now - lastTick
            lastTick = now
            local targetChar = targetPlayer.Character
            local myChar = LocalPlayer.Character
            if targetChar and myChar then
                local tHRP = targetChar:FindFirstChild("HumanoidRootPart")
                local mHRP = myChar:FindFirstChild("HumanoidRootPart")
                if tHRP and mHRP then
                    local force = math.clamp(20000 * (dt * 60), 10000, 80000)
                    local damp = math.clamp(200 * (dt * 60), 100, 800)
                    local bp = tHRP:FindFirstChild("KickBP") or Instance.new("BodyPosition", tHRP)
                    bp.Name = "KickBP"
                    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bp.D = damp
                    bp.P = force
                    bp.Position = mHRP.Position + Vector3.new(0, Config.TargetHeight, 0)
                    local bg = tHRP:FindFirstChild("KickBG") or Instance.new("BodyGyro", tHRP)
                    bg.Name = "KickBG"
                    bg.MaxTorque = Vector3.new(0, 0, 0)
                    bg.CFrame = tHRP.CFrame
                    if tHRP.Position.Y < 2000 and destroyGrabLineEvent then
                        setOwner:FireServer(tHRP, tHRP.CFrame)
                        destroyGrabLineEvent:FireServer(tHRP)
                    end
                    local spawned = workspace:FindFirstChild(targetPlayer.Name .. "SpawnedInToys")
                    if spawned and State.antiAntiKick then
                        local function yeet(part)
                            if part then
                                setOwner:FireServer(part, part.CFrame)
                                if part:FindFirstChild("PartOwner") and part.PartOwner.Value == targetPlayer.Name then
                                    part.CFrame = CFrame.new(0, 10000, 0)
                                end
                            end
                        end
                        if spawned:FindFirstChild("NinjaKunai") then yeet(spawned.NinjaKunai:FindFirstChild("SoundPart")) end
                        if spawned:FindFirstChild("NinjaShuriken") then yeet(spawned.NinjaShuriken:FindFirstChild("SoundPart")) end
                    end
                    local dist = (mHRP.Position - tHRP.Position).Magnitude
                    if tHRP.Position.Y < 2000 and dist > 25 then
                        local oldCF = mHRP.CFrame
                        mHRP.CFrame = tHRP.CFrame * CFrame.new(0, -Config.TargetHeight, 0)
                        task.wait(0.01)
                        if myChar and mHRP then mHRP.CFrame = oldCF end
                    end
                end
            end
            task.wait()
        end
        if targetPlayer and targetPlayer.Character then
            local r = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if r then
                if r:FindFirstChild("KickBP") then r.KickBP:Destroy() end
                if r:FindFirstChild("KickBG") then r.KickBG:Destroy() end
            end
        end
    end)
    State.activeKicks[targetPlayer] = function() kickActive_local = false end
end

local function StopKick(targetPlayer)
    if targetPlayer and State.activeKicks[targetPlayer] then
        State.activeKicks[targetPlayer]()
        State.activeKicks[targetPlayer] = nil
    end
    if targetPlayer and targetPlayer.Character then
        local r = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if r then
            pcall(function()
                if r:FindFirstChild("StrongBP") then r.StrongBP:Destroy() end
                if r:FindFirstChild("StrongBG") then r.StrongBG:Destroy() end
            end)
        end
    end
end

local function StopAllKicks()
    for _, stopFunc in pairs(State.activeKicks) do stopFunc() end
    table.clear(State.activeKicks)
end

local function StrongKickPlayer(targetPlayer)
    if not targetPlayer then return end
    if State.activeKicks[targetPlayer] then
        State.activeKicks[targetPlayer]()
        State.activeKicks[targetPlayer] = nil
    end
    local kickActive_local = true
    local lastTpTick = 0
    local lastTick = tick()
    task.spawn(function()
        while kickActive_local do
            if not targetPlayer or not targetPlayer.Parent then break end
            local now = tick()
            local dt = now - lastTick
            lastTick = now
            local targetChar = targetPlayer.Character
            local myChar = LocalPlayer.Character
            if targetChar and myChar then
                local tHRP = targetChar:FindFirstChild("HumanoidRootPart")
                local mHRP = myChar:FindFirstChild("HumanoidRootPart")
                if tHRP and mHRP then
                    local force = math.clamp(45000 * (dt * 60), 20000, 150000)
                    local damp = math.clamp(300 * (dt * 60), 150, 600)
                    local bp = tHRP:FindFirstChild("StrongBP") or Instance.new("BodyPosition", tHRP)
                    bp.Name = "StrongBP"
                    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bp.P = force
                    bp.D = damp
                    bp.Position = mHRP.Position + Vector3.new(0, Config.TargetHeight, 0)
                    local bg = tHRP:FindFirstChild("StrongBG") or Instance.new("BodyGyro", tHRP)
                    bg.Name = "StrongBG"
                    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    bg.P = 80000
                    bg.D = 150
                    bg.CFrame = tHRP.CFrame
                    if tHRP.Position.Y < 2000 then
                        pcall(function()
                            setOwner:FireServer(tHRP, tHRP.CFrame)
                            setOwner:FireServer(tHRP, tHRP.CFrame)
                        end)
                        pcall(function()
                            if destroyGrabLineEvent then
                                destroyGrabLineEvent:FireServer(tHRP)
                                destroyGrabLineEvent:FireServer(tHRP)
                            end
                        end)
                    end
                    local spawned = workspace:FindFirstChild(targetPlayer.Name .. "SpawnedInToys")
                    if spawned and State.antiAntiKick then
                        local function yeet(part)
                            if part then
                                setOwner:FireServer(part, part.CFrame)
                                if part:FindFirstChild("PartOwner") and part.PartOwner.Value == targetPlayer.Name then
                                    part.CFrame = CFrame.new(0, 10000, 0)
                                end
                            end
                        end
                        if spawned:FindFirstChild("NinjaKunai") then yeet(spawned.NinjaKunai:FindFirstChild("SoundPart")) end
                        if spawned:FindFirstChild("NinjaShuriken") then yeet(spawned.NinjaShuriken:FindFirstChild("SoundPart")) end
                    end
                    local dist = (mHRP.Position - tHRP.Position).Magnitude
                    if tHRP.Position.Y < 2000 and dist > 24 and now - lastTpTick > 0.05 then
                        lastTpTick = now
                        local oldCF = mHRP.CFrame
                        mHRP.CFrame = tHRP.CFrame * CFrame.new(0, -Config.TargetHeight, 0)
                        task.wait()
                        if myChar and mHRP then mHRP.CFrame = oldCF end
                    end
                end
            end
            task.wait()
        end
        if targetPlayer and targetPlayer.Character then
            local r = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if r then
                pcall(function()
                    if r:FindFirstChild("StrongBP") then r.StrongBP:Destroy() end
                    if r:FindFirstChild("StrongBG") then r.StrongBG:Destroy() end
                end)
            end
        end
    end)
    State.activeKicks[targetPlayer] = function() kickActive_local = false end
end

-- ===================== TARGET SYSTEM =====================
local function UpdateTargetLabel()
    if not State.TargetLabel then return end
    if State.currentTarget then
        State.TargetLabel:SetText("Kicking: <b>" .. State.currentTarget.Name .. "</b>")
    else
        State.TargetLabel:SetText("Kicking: <b>None</b>")
    end
end

local function GetPlayerList()
    local list = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, plr.DisplayName .. " (@" .. plr.Name .. ")")
        end
    end
    return list
end

local function ToggleKickUI(value)
    if value then
        local selName = Options.TargetSelectDropdown and Options.TargetSelectDropdown.Value
        if not selName then
            Library:Notify({ Title = "Celestial", Description = "Select a player first!", Time = 2 })
            Toggles.KickToggle:SetValue(false)
            return
        end
        local realName = selName:match("@(.+)%)") or selName
        local targetPlayer = Players:FindFirstChild(realName)
        if not targetPlayer then
            Library:Notify({ Title = "Celestial", Description = "Player not found!", Time = 2 })
            Toggles.KickToggle:SetValue(false)
            return
        end
        State.currentTarget = targetPlayer
        State.kickActive = true
        if State.kickMode == "Strong" then
            StrongKickPlayer(State.currentTarget)
        else
            KickPlayer(State.currentTarget)
        end
        UpdateTargetLabel()
        Library:Notify({ Title = "Celestial", Description = "Kicking: " .. State.currentTarget.Name, Time = 2 })
    else
        StopKick(State.currentTarget)
        State.currentTarget = nil
        State.kickActive = false
        UpdateTargetLabel()
        Library:Notify({ Title = "Celestial", Description = "Kick stopped.", Time = 2 })
    end
end

-- ===================== SPEED SYSTEM =====================
local function StartSpeed()
    if State.speed.conn then State.speed.conn:Disconnect(); State.speed.conn = nil end
    if State.speed.changedConn then State.speed.changedConn:Disconnect(); State.speed.changedConn = nil end
    
    local function GetOrCreateBV()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        if State.speed.bv and State.speed.bv.Parent == hrp then return State.speed.bv end
        local old = hrp:FindFirstChild("SpeedBV")
        if old then old:Destroy() end
        State.speed.bv = Instance.new("BodyVelocity")
        State.speed.bv.Name = "SpeedBV"
        State.speed.bv.MaxForce = Vector3.new(1e5, 0, 1e5)
        State.speed.bv.Velocity = Vector3.zero
        State.speed.bv.Parent = hrp
        return State.speed.bv
    end
    
    GetOrCreateBV()
    State.speed.conn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        if hum.WalkSpeed ~= State.speed.value then
            hum.WalkSpeed = State.speed.value
        end
        local currentBV = (State.speed.bv and State.speed.bv.Parent == hrp) and State.speed.bv or GetOrCreateBV()
        if not currentBV then return end
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0.1 then
            currentBV.Velocity = moveDir * State.speed.value
        else
            currentBV.Velocity = Vector3.zero
        end
    end)
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = State.speed.value
        State.speed.changedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Toggles.PlayerSpeedToggle and Toggles.PlayerSpeedToggle.Value then
                if hum.WalkSpeed ~= State.speed.value then
                    hum.WalkSpeed = State.speed.value
                end
            end
        end)
    end
end

local function StopSpeed()
    if State.speed.conn then State.speed.conn:Disconnect(); State.speed.conn = nil end
    if State.speed.changedConn then State.speed.changedConn:Disconnect(); State.speed.changedConn = nil end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local old = hrp:FindFirstChild("SpeedBV")
        if old then old:Destroy() end
    end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end
end

-- ===================== DELETE PCLD SYSTEM =====================
local function DoDoubleReset()
    if State.destroyPCLD.resetting then return end
    State.destroyPCLD.resetting = true
    task.spawn(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then State.destroyPCLD.resetting = false; return end
        hum.Health = 0
        LocalPlayer.CharacterAdded:Wait()
        task.wait(0.15)
        if not State.destroyPCLD.active then State.destroyPCLD.resetting = false; return end
        local char2 = LocalPlayer.Character
        local hum2 = char2 and char2:FindFirstChildOfClass("Humanoid")
        if hum2 then
            hum2.Health = 0
        end
        task.wait(2)
        State.destroyPCLD.resetting = false
    end)
end

local function OnCharacterDied()
    if not State.destroyPCLD.active then return end
    if State.destroyPCLD.resetting then return end
    task.spawn(function()
        State.destroyPCLD.resetting = true
        LocalPlayer.CharacterAdded:Wait()
        task.wait(0.15)
        if not State.destroyPCLD.active then State.destroyPCLD.resetting = false; return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = 0
        end
        task.wait(2)
        State.destroyPCLD.resetting = false
    end)
end

local function StartDestroyPCLD()
    State.destroyPCLD.active = true
    State.destroyPCLD.resetting = false
    DoDoubleReset()
    if State.destroyPCLD.conn then State.destroyPCLD.conn:Disconnect() end
    State.destroyPCLD.conn = LocalPlayer.CharacterAdded:Connect(function(char)
        if not State.destroyPCLD.active then return end
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                OnCharacterDied()
            end)
        end
    end)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Died:Connect(function()
                OnCharacterDied()
            end)
        end
    end
end

local function StopDestroyPCLD()
    State.destroyPCLD.active = false
    State.destroyPCLD.resetting = false
    if State.destroyPCLD.conn then State.destroyPCLD.conn:Disconnect(); State.destroyPCLD.conn = nil end
end

-- ===================== LAG LINE SYSTEM =====================
local lagPart = nil
pcall(function()
    local objectModel = workspace.Map.AlwaysHereTweenedObjects.Ocean.Object.ObjectModel
    local children = objectModel:GetChildren()
    if children[17] then
        lagPart = children[17]

    end
end)

local function ServerLagLineFunction()
    task.spawn(function()
        if not CreateGrabLine or not lagPart then return end
        if not destroyGrabLineEvent then 
            print("❌ destroyGrabLineEvent not found!")
            return 
        end
        
        while State.lagLine.active do
            if not lagPart or not lagPart.Parent then break end
            
            -- СОЗДАЁМ 50 ЛИНИЙ
            for i = 1, 50 do
                if not State.lagLine.active then break end
                pcall(function()
                    CreateGrabLine:FireServer(lagPart, lagPart.CFrame)
                end)
            end
            
            -- СРАЗУ УДАЛЯЕМ 50 ЛИНИЙ
            for i = 1, 50 do
                if not State.lagLine.active then break end
                pcall(function()
                    destroyGrabLineEvent:FireServer(lagPart)
                end)
            end
            
            task.wait(0.1) -- 50 созданий + 50 удалений каждые 0.1 сек
        end
    end)
end
-- ===================== FULL CLEANUP =====================
local function FullCleanup()
    State.kickActive = false
    StopAllKicks()
    State.antiGrab.active = false; State.shuriken.active = false
    State.ragdoll.active = false; State.snowball.active = false
    State.antiVoid.active = false; State.waterWalk.active = false; State.antiLag.active = false
    State.antiKickReset.active = false; State.teleport.active = false; State.blobGucci.processing = false; State.vehicleFly.active = false
    StopAntiGrab(); StopShuriken(); StopRagdoll(); StopSnowball()
    StopAntiVoid(); StopWaterWalk(); StopPCLD(); StopESP()
    StopPacketDetect()
    StopPacketLag()
    StopAntiKickReset()
    StopVehicleFly()
    StopTeleport()
    if antiGucciConnection then antiGucciConnection:Disconnect(); antiGucciConnection = nil end
    if localCreatureControlConn then localCreatureControlConn:Disconnect(); localCreatureControlConn = nil end
    State.currentTarget = nil
    UpdateTargetLabel()
    Library:Notify({ Title = "Celestial", Description = "Everything stopped.", Time = 2 })
end
-- ===================== CHARACTER HANDLERS =====================
ApplyPlayerGroup(LocalPlayer.Character)
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    State.legs.deleted = false
    if State.legs.autoDelete then
        task.wait(0.5)
        DeleteLegs()
    end
    if Toggles.PlayerSpeedToggle and Toggles.PlayerSpeedToggle.Value then
        if State.speed.changedConn then State.speed.changedConn:Disconnect(); State.speed.changedConn = nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            State.speed.changedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if Toggles.PlayerSpeedToggle and Toggles.PlayerSpeedToggle.Value then
                    if hum.WalkSpeed ~= State.speed.value then
                        hum.WalkSpeed = State.speed.value
                    end
                end
            end)
        end
        StartSpeed()
    end
    if State.thirdPerson.active then
        task.wait(0.5)
        StartThirdPerson()
    end
    if State.antiGrab.active or State.kickActive then
        if State.antiGrab.conn then State.antiGrab.conn:Disconnect(); State.antiGrab.conn = nil end
        task.wait(1); StartAntiGrab()
    end
    if State.shuriken.active then
        _G.ShurikenAntiKick = false; ClearShuriken(); task.wait(1)
        if State.shuriken.active then StartShuriken() end
    end
    if State.ragdoll.active then
        if State.ragdoll.conn then State.ragdoll.conn:Disconnect(); State.ragdoll.conn = nil end
        DestroyRagdollPallet(); task.wait(1)
        if State.ragdoll.active then StartRagdoll() end
    end
    if State.snowball.active then
        if State.snowball.conn then State.snowball.conn:Disconnect(); State.snowball.conn = nil end
        if State.snowball.touchLoop then
            pcall(function() State.snowball.touchLoop:Disconnect() end)
            State.snowball.touchLoop = nil
        end
        DestroySnowball(); task.wait(1)
        if State.snowball.active then StartSnowball() end
    end
end)

local playerGroupConn = RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.CollisionGroup ~= PLAYER_GROUP then ApplyPlayerGroup(char) end
end)



-- ===================== WINDOW =====================
local Window = Library:CreateWindow({
Title = "Celestial",
Footer = "Celestial v0.1 | " .. game.PlaceId,
Icon = "101623576369972",
NotifySide = "Right",
AutoShow = true,
EnableCompacting = true,
SidebarCompacted = true,
CornerRadius = 17,
})

local DraggableLabel = Library:AddDraggableLabel("Celestial | " .. LocalPlayer.Name)
DraggableLabel:SetVisible(true)

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60

RunService.RenderStepped:Connect(function()
    FrameCounter += 1
    if tick() - FrameTimer >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end
    local ping = 0
    pcall(function()
        ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
    DraggableLabel:SetText(("Celestial | %s | %s fps | %s ms"):format(LocalPlayer.Name, math.floor(FPS), ping))
end)

-- ===================== TABS =====================
local Tabs = {
    Home = Window:AddTab("Home", "house"),
    Aura = Window:AddTab("Aura", "sun"),
    Grab = Window:AddTab("Grab", "hand"),
    Defense = Window:AddTab("Defense", "shield"),
    Player = Window:AddTab("Player", "user"),
    BlobKick = Window:AddTab("BlobKick", "blend"),
    Visual = Window:AddTab("Visual", "eye"),
    Misc = Window:AddTab("Misc", "sparkles"),
    ["UI"] = Window:AddTab("UI Settings", "settings"),
}

-- ===================== DEFENSE TAB =====================
-- LEFT SIDE
local DefenseBox1 = Tabs.Defense:AddLeftGroupbox("Defense", "shield")

DefenseBox1:AddToggle("AntiGrabToggle", {
    Text = "Anti-Grab",
    Default = false,
    Callback = function(v) ToggleAntiGrab(v) end
})



DefenseBox1:AddToggle("AntiRagdollToggle", {
    Text = "Anti-Ragdoll",
    Default = false,
    Callback = function(v) ToggleAntiRagdoll(v) end
})



DefenseBox1:AddToggle("AntiInfToggle", {
    Text = "Anti-Inf",
    Default = false,
    Callback = function(v) ToggleAntiInf(v) end
})



DefenseBox1:AddToggle("DestroyPCLDToggle", {
    Text = "Destroy PCLD",
    Default = false,
    Callback = function(v)
        if v then StartDestroyPCLD() else StopDestroyPCLD() end
    end
})

DefenseBox1:AddButton({
    Text = "Delete Legs",
    Func = function()
        DeleteLegs()
    end
})

DefenseBox1:AddToggle("AutoDeleteLegsToggle", {
    Text = "Auto Delete on Respawn",
    Default = false,
    Callback = function(v)
        State.legs.autoDelete = v
    end
})

-- ANTI-KICK BOX
local AntiKickBox = Tabs.Defense:AddLeftGroupbox("Anti-Kick", "shield-alert")

AntiKickBox:AddToggle("ShurikenToggle", {
    Text = "Shuriken Anti-Kick",
    Default = false,
    Callback = function(v)
        State.shuriken.active = v
        if v then StartShuriken() else StopShuriken() end
    end
})

AntiKickBox:AddToggle("AntiKickResetToggle", {
    Text = "Anti-Kick (Reset)",
    Default = false,
    Callback = function(v)
        ToggleAntiKickReset(v)
    end
})
-- ANTI-LAG BOX
local AntiLagBox = Tabs.Defense:AddLeftGroupbox("Anti-Lag", "gauge")

AntiLagBox:AddToggle("AntiLagToggle", {
    Text = "Anti-Lag",
    Default = false,
    Callback = function(v)
        ToggleAntiLag(v)
    end
})

-- RIGHT SIDE
-- RIGHT SIDE
local GucciBox = Tabs.Defense:AddRightGroupbox("Gucci", "sparkles")

GucciBox:AddButton({
    Text = "Blobman Gucci",
    Func = function()
        BlobmanGucci()
    end
})

GucciBox:AddButton({
    Text = "Tractor Gucci", 
    Func = function()
        TractorGucci()
    end
})

GucciBox:AddButton({
    Text = "Train Gucci",
    Func = function()
        TrainGucci()
    end
})

GucciBox:AddDivider({ Text = "Gucci Binds" })

local BlobmanToggle = GucciBox:AddToggle("BlobmanGucciToggle", {
    Text = "Blobman Auto",
    Default = false,
    Callback = function(v)
        -- Placeholder for future functionality
    end
})

BlobmanToggle:AddKeyPicker("BlobmanGucciBind", {
    Default = "None",
    Mode = "Toggle", 
    Text = "Blobman Bind",
    NoUI = false,
    Callback = function()
        BlobmanGucci()
    end
})

local TractorToggle = GucciBox:AddToggle("TractorGucciToggle", {
    Text = "Tractor Auto",
    Default = false,
    Callback = function(v)
        -- Placeholder for future functionality  
    end
})

TractorToggle:AddKeyPicker("TractorGucciBind", {
    Default = "None",
    Mode = "Toggle",
    Text = "Tractor Bind", 
    NoUI = false,
    Callback = function()
        TractorGucci()
    end
})

local TrainToggle = GucciBox:AddToggle("TrainGucciToggle", {
    Text = "Train Auto",
    Default = false,
    Callback = function(v)
        -- Placeholder for future functionality
    end
})

TrainToggle:AddKeyPicker("TrainGucciBind", {
    Default = "None", 
    Mode = "Toggle",
    Text = "Train Bind",
    NoUI = false,
    Callback = function()
        TrainGucci()
    end
})
-- ANTI-OTHER BOX
local AntiOtherBox = Tabs.Defense:AddRightGroupbox("Anti-Other", "shield-check")

AntiOtherBox:AddToggle("AntiVoidToggle", {
    Text = "Anti-Void",
    Default = false,
    Callback = function(v)
        if v then StartAntiVoid() else StopAntiVoid() end
    end
})



AntiOtherBox:AddToggle("WaterWalkToggle", {
    Text = "Water Walk",
    Default = false,
    Callback = function(v)
        if v then StartWaterWalk() else StopWaterWalk() end
    end
})

AntiOtherBox:AddToggle("AntiExplodeToggle", {
    Text = "Anti-Explosion",
    Default = false,
    Callback = function(v) ToggleAntiExplode(v) end
})

-- ===================== BLOBKICK TAB =====================
local BlobKickLeft = Tabs.BlobKick:AddLeftGroupbox("Controls", "zap")

local BK_TargetLabel = BlobKickLeft:AddLabel({ Text = "Target: <b>None</b>", DoesWrap = false })

BlobKickLeft:AddDropdown("BK_TargetDropdown", {
    Text = "Select Target",
    Values = GetPlayerList(),
    Default = 1,
    AllowNull = true,
    Callback = function(value)
        if value then
            local realName = value:match("@(.+)%)") or value
            local plr = Players:FindFirstChild(realName)
            if plr then
                State.blobKick.target = plr
                BK_TargetLabel:SetText("Target: <b>" .. plr.Name .. "</b>")
            end
        else
            State.blobKick.target = nil
            BK_TargetLabel:SetText("Target: <b>None</b>")
        end
    end
})

local BK_Toggle
BK_Toggle = BlobKickLeft:AddToggle("BK_Toggle", {
    Text = "Blob Kick",
    Default = false,
    Callback = function(v)
        if State.blobKick.conn then State.blobKick.conn:Disconnect(); State.blobKick.conn = nil end
        State.blobKick.active = v

        if v then
            if not State.blobKick.target then
                Library:Notify({ Title = "BlobKick", Description = "Select a target first!", Time = 2 })
                BK_Toggle:SetValue(false)
                return
            end

            task.spawn(function()
                local ok, err = pcall(function()
                    local myToys = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    local toy = myToys and myToys:WaitForChild("CreatureBlobman", 3)
                    if not toy then
                        Library:Notify({ Title = "BlobKick", Description = "Sit on Blobman first!", Time = 2 })
                        State.blobKick.active = false; BK_Toggle:SetValue(false); return
                    end

                    local detector = toy:WaitForChild("LeftDetector", 3)
                    local seatScript = toy:WaitForChild("BlobmanSeatAndOwnerScript", 3)
                    local grab = seatScript:WaitForChild("CreatureGrab", 3)
                    local release = seatScript:WaitForChild("CreatureRelease", 3)

                    local tChar = State.blobKick.target.Character
                    local tHRP = tChar and tChar:WaitForChild("HumanoidRootPart", 3)
                    local myHRP = LocalPlayer.Character and LocalPlayer.Character:WaitForChild("HumanoidRootPart", 3)

                    if not tHRP or not myHRP then return end

                    local oldCF = myHRP.CFrame

                    local weld = Instance.new("Weld", detector)
                    weld.Part0 = detector
                    weld.Part1 = tHRP

                    myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 3, 0)
                    task.wait(0.1)

                    for i = 1, 30 do
                        if not State.blobKick.active then break end
                        if tHRP.Parent then
                            grab:FireServer(detector, tHRP, weld)
                        end
                        task.wait(0.02)
                    end

                    if not State.blobKick.active then return end

                    local bp = Instance.new("BodyPosition", tHRP)
                    bp.Name = "BlobKickBP"
                    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bp.D = 150
                    bp.P = 60000
                    bp.Position = oldCF.Position

                    local bg = Instance.new("BodyGyro", tHRP)
                    bg.Name = "BlobKickBG"
                    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    bg.P = 50000
                    bg.D = 100
                    bg.CFrame = tHRP.CFrame

                    if setOwner then
                        setOwner:FireServer(tHRP, tHRP.CFrame)
                        setOwner:FireServer(tHRP, tHRP.CFrame)
                    end

                    task.wait(0.1)
                    bp.Position = oldCF.Position + Vector3.new(0, 15, 0)

                    State.blobKick.conn = RunService.Heartbeat:Connect(function()
                        if not State.blobKick.active then return end
                        local myH = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if not myH or not tHRP.Parent then return end

                        local bpE = tHRP:FindFirstChild("BlobKickBP")
                        if bpE then bpE.Position = myH.Position + Vector3.new(0, 15, 0) end

                        pcall(function()
                            if setOwner then setOwner:FireServer(tHRP, tHRP.CFrame) end
                            if destroyGrabLineEvent then destroyGrabLineEvent:FireServer(tHRP) end
                            grab:FireServer(detector, tHRP, weld)
                            release:FireServer(weld)
                        end)
                    end)
                end)

                if not ok then
                    Library:Notify({ Title = "BlobKick ERROR", Description = tostring(err):sub(1, 100), Time = 5 })
                    State.blobKick.active = false
                    if BK_Toggle then BK_Toggle:SetValue(false) end
                end
            end)
        else
            for _, plr in pairs(Players:GetPlayers()) do
                local th = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if th then
                    pcall(function()
                        if th:FindFirstChild("BlobKickBP") then th.BlobKickBP:Destroy() end
                        if th:FindFirstChild("BlobKickBG") then th.BlobKickBG:Destroy() end
                    end)
                end
            end
        end
    end
})

BK_Toggle:AddKeyPicker("BK_Bind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Blob Kick Bind",
    NoUI = false
})

-- ===================== AURA TAB =====================
local AuraRight = Tabs.Aura:AddRightGroupbox("Aura", "sun")

AuraRight:AddToggle("AntiKickAuraToggle", {
    Text = "AntiKick Aura",
    Default = false,
    Callback = function(v)
        if State.antiKickAura.conn then State.antiKickAura.conn:Disconnect(); State.antiKickAura.conn = nil end
        if not v then return end
        State.antiKickAura.conn = RunService.Heartbeat:Connect(function()
            local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not myHRP then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr == LocalPlayer then continue end
                local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                if not inv then continue end
                for _, obj in ipairs(inv:GetChildren()) do
                    if obj.Name == "NinjaShuriken" or obj.Name == "AntiKick" then
                        local sp = obj:FindFirstChild("SoundPart")
                        if sp and (myHRP.Position - sp.Position).Magnitude <= 25 then
                            local owner = sp:FindFirstChild("PartOwner")
                            if not owner or owner.Value ~= LocalPlayer.Name then
                                if setOwner then setOwner:FireServer(sp, sp.CFrame) end
                                sp.CFrame = CFrame.new(0, -10000, 0)
                            end
                        end
                    end
                end
            end
        end)
    end
})

-- ===================== PLAYER TAB =====================
local PlayerLeft = Tabs.Player:AddLeftGroupbox("Movement", "user")

local TeleportLabel = PlayerLeft:AddLabel({ Text = "Teleport to Mouse", DoesWrap = false })
TeleportLabel:AddKeyPicker("TeleportBind", {
    Default = "None",
    Mode = "Hold",
    Text = "TP Bind",
    NoUI = false,
    Callback = function()
        TeleportToMouse()
    end
})

PlayerLeft:AddSlider("TeleportDistance", {
    Text = "TP Distance",
    Default = 50,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(v)
        State.teleport.distance = v
    end,
})

PlayerLeft:AddDivider()

local SpeedToggle = PlayerLeft:AddToggle("PlayerSpeedToggle", {
    Text = "Player Speed",
    Default = false,
    Callback = function(v)
        if v then StartSpeed() else StopSpeed() end
    end,
})

SpeedToggle:AddKeyPicker("PlayerSpeedBind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Speed Bind",
    NoUI = false,
})

PlayerLeft:AddSlider("PlayerSpeedSlider", {
    Text = "Speed",
    Default = 16,
    Min = 1,
    Max = 900,
    Rounding = 0,
    Callback = function(v)
        State.speed.value = v
    end,
})

-- RIGHT SIDE - VEHICLE FLY
local PlayerRight = Tabs.Player:AddRightGroupbox("Vehicle", "car")

local VehicleFlyToggle = PlayerRight:AddToggle("VehicleFlyToggle", {
    Text = "Vehicle Fly",
    Default = false,
    Callback = function(v)
        ToggleVehicleFly(v)
    end,
})

VehicleFlyToggle:AddKeyPicker("VehicleFlyBind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Fly Bind",
    NoUI = false,
})

PlayerRight:AddSlider("VehicleFlySpeed", {
    Text = "Fly Speed",
    Default = 16,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(v)
        State.vehicleFly.speed = v
    end,
})


-- ===================== GRAB TAB =====================
local GrabLeft = Tabs.Grab:AddLeftGroupbox("Controls", "zap")

State.TargetLabel = GrabLeft:AddLabel({ Text = "Kicking: <b>None</b>", DoesWrap = false })

GrabLeft:AddDropdown("TargetSelectDropdown", {
    Text = "Select Target",
    Values = GetPlayerList(),
    Default = 1,
    AllowNull = true,
    Callback = function(value)
        if value then
            local realName = value:match("@(.+)%)") or value
            local plr = Players:FindFirstChild(realName)
            if plr then
                State.currentTarget = plr
                UpdateTargetLabel()
            end
        end
    end,
})

GrabLeft:AddDropdown("KickModeDropdown", {
    Text = "Ownership Mode",
    Values = {"Speed Kick", "Strong Kick"},
    Default = 1,
    AllowNull = false,
    Callback = function(value)
        if value == "Speed Kick" then
            State.kickMode = "Speed"
        elseif value == "Strong Kick" then
            State.kickMode = "Strong"
        end
        Library:Notify({ Title = "Celestial", Description = "Kick mode: " .. value, Time = 2 })
    end,
})

GrabLeft:AddDivider()

local KickToggle = GrabLeft:AddToggle("KickToggle", {
    Text = "Kick",
    Default = false,
    Callback = function(v) ToggleKickUI(v) end
})

KickToggle:AddKeyPicker("KickBind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Kick Bind",
    NoUI = false
})

GrabLeft:AddDivider()

GrabLeft:AddToggle("RagdollToggle", {
    Text = "Ragdoll",
    Default = false,
    Callback = function(v)
        ToggleRagdoll(v)
    end
})

GrabLeft:AddToggle("SnowballToggle", {
    Text = "Snowball",
    Default = false,
    Callback = function(v)
        ToggleSnowball(v)
    end
})

GrabLeft:AddToggle("AntiAntiKickToggle", {
    Text = "Anti-AntiKick",
    Default = false,
    Callback = function(value)
        State.antiAntiKick = value
    end
})

GrabLeft:AddDivider({ Text = "Settings" })

GrabLeft:AddSlider("TargetHeight", {
    Text = "Target Height",
    Default = Config.TargetHeight,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = function(v)
        Config.TargetHeight = v
    end,
})

-- ===================== VISUAL TAB =====================
local VisualLeft = Tabs.Visual:AddLeftGroupbox("PCLD", "box")
local VisualRight = Tabs.Visual:AddRightGroupbox("ESP", "eye")

VisualLeft:AddToggle("PCLDToggle", {
    Text = "PCLD",
    Default = false,
    Callback = function(v)
        if v then StartPCLD() else StopPCLD() end
    end
})

local PCLDColorLabel = VisualLeft:AddLabel({ Text = "Box Color", DoesWrap = false })
PCLDColorLabel:AddColorPicker("PCLDColorPicker", {
    Default = Color3.fromRGB(255,0,0),
    Title = "PCLD Color",
    Callback = function(color)
        ESP.pclcColor = color
        UpdatePCLDSettings()
    end
})

VisualLeft:AddSlider("PCLDTransparency", {
    Text = "Box Transparency",
    Default = 5,
    Min = 0,
    Max = 9,
    Rounding = 0,
    Callback = function(v)
        ESP.pclcTransparency = v/10
        UpdatePCLDSettings()
    end
})

-- ESP Settings
VisualRight:AddToggle("ESPToggle", {
    Text = "ESP Master",
    Default = false,
    Callback = function(v)
        ToggleEsp(v)
    end
})

VisualRight:AddToggle("ESPNameToggle", {
    Text = "NameTags",
    Default = false,
    Callback = function(value)
        ESP.nameEnabled = value
        if ESP.enabled then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    if value and plr.Character then 
                        AddPlayerLabel(plr) 
                    else 
                        RemovePlayerLabel(plr) 
                    end
                end
            end
        end
    end
})

VisualRight:AddToggle("HighlightToggle", {
    Text = "Highlight (Chams)",
    Default = false,
    Callback = function(value)
        ESP.highlightEnabled = value
        if ESP.enabled then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    if value and plr.Character then 
                        AddHighlight(plr) 
                    else 
                        RemoveHighlight(plr) 
                    end
                end
            end
        end
    end
})

VisualRight:AddDivider({ Text = "Colors" })

local ESPColorLabel = VisualRight:AddLabel({ Text = "NameTag Color", DoesWrap = false })
ESPColorLabel:AddColorPicker("ESPColorPicker", {
    Default = Color3.fromRGB(255,255,255),
    Title = "NameTag Color",
    Callback = function(color)
        ESP.playerColor = color
        UpdateESPColors()
    end
})

local HLColorLabel = VisualRight:AddLabel({ Text = "Highlight Color", DoesWrap = false })
HLColorLabel:AddColorPicker("HighlightColorPicker", {
    Default = Color3.fromRGB(255,0,0),
    Title = "Highlight Color",
    Callback = function(color)
        ESP.highlightColor = color
        UpdateHighlightSettings()
    end
})

VisualRight:AddSlider("HighlightTransparency", {
    Text = "Highlight Transparency",
    Default = 5,
    Min = 0,
    Max = 9,
    Rounding = 0,
    Callback = function(v)
        ESP.highlightTransparency = v/10
        UpdateHighlightSettings()
    end
})

VisualRight:AddDivider({ Text = "Third Person" })

VisualRight:AddToggle("ThirdPersonToggle", {
    Text = "Third Person Unlock",
    Default = false,
    Callback = function(v)
        ToggleThirdPerson(v)
    end
})
-- ===================== MISC TAB =====================
local MiscLeft = Tabs.Misc:AddLeftGroupbox("Notifications", "bell")

MiscLeft:AddToggle("KickNotifyToggle", {
    Text = "Kick Notify",
    Default = false,
    Callback = function(v)
        ToggleKickNotify(v)
    end
})

local MiscLeft2 = Tabs.Misc:AddLeftGroupbox("Server Lag", "server")

MiscLeft2:AddToggle("LineLag", {
    Text = "Lag Server",
    Default = false,
    Callback = function(v)
        State.lagLine.active = v
        if v then
            ServerLagLineFunction()
        end
    end
})

local MiscRight = Tabs.Misc:AddRightGroupbox("Packet Lag", "wifi")

MiscRight:AddToggle("PacketLagToggle", {
    Text = "Enable Packet Lag",
    Default = false,
    Callback = function(v)
        TogglePacketLag(v)
    end
})

MiscRight:AddSlider("PacketLagSize", {
    Text = "Packet Size (MB)",
    Default = 0.190,
    Min = 0.190,
    Max = 19,
    Rounding = 3,
    Callback = function(v)
        State.packetLag.packetSize = v
    end
})

MiscRight:AddSlider("PacketLagCooldown", {
    Text = "Cooldown (s)",
    Default = 1,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Callback = function(v)
        State.packetLag.cooldown = v
    end
})

MiscRight:AddDivider({ Text = "Packet Detection" })

MiscRight:AddToggle("PacketDetectToggle", {
    Text = "Enable Packet Detection",
    Default = false,
    Callback = function(v)
        TogglePacketDetect(v)
    end
})

MiscRight:AddSlider("PacketNotifyCooldown", {
    Text = "Notify Cooldown (s)",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(v)
        State.packetDetect.notifyCooldown = v
    end
})
-- ===================== HOME TAB =====================
local function GetGreeting()
    local hour = tonumber(os.date("%H"))
    if hour >= 5 and hour < 12 then return "Morning"
    elseif hour >= 12 and hour < 17 then return "Afternoon"
    elseif hour >= 17 and hour < 21 then return "Evening"
    else return "Night" end
end

local GreetingsBox = Tabs.Home:AddLeftGroupbox("Greetings", "crown")
local GreetLabel = GreetingsBox:AddLabel({ Text = GetGreeting() .. ", <b>" .. LocalPlayer.Name .. "</b>", DoesWrap = true })
GreetingsBox:AddDivider()
GreetingsBox:AddLabel({ Text = "Welcome to <b><font color=\"rgb(180, 100, 255)\">Celestial</font></b>", DoesWrap = true })


local StatsBox = Tabs.Home:AddRightGroupbox("Statistics", "chart-column-increasing")
local TimeLabel = StatsBox:AddLabel({ Text = "Current time: <b>" .. os.date("%H:%M") .. "</b>", DoesWrap = false })
StatsBox:AddLabel({ Text = "Current script version: <b>v2.7</b>", DoesWrap = false })

local function CountToggles()
    local count = 0
    for _, v in pairs(Library.Toggles) do
        if v.Value == true then count += 1 end
    end
    return count
end

local TogglesLabel = StatsBox:AddLabel({ Text = "Toggles currently on: <b>" .. CountToggles() .. "</b>", DoesWrap = false })
StatsBox:AddDivider({ Text = "Server Statistics" })

local ok, productInfo = pcall(function()
    return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
end)
local gameName = ok and productInfo.Name or "Unknown"
StatsBox:AddLabel({ Text = "Game name: <b>" .. gameName .. "</b>", DoesWrap = true })

local ElapsedLabel = StatsBox:AddLabel({ Text = "Elapsed time: <b>0 seconds</b>", DoesWrap = false })
local KickedLabel = StatsBox:AddLabel({ Text = "Kicked players: <b>0</b>", DoesWrap = false })

local ScriptBox = Tabs.Home:AddRightGroupbox("Script", "monitor")
ScriptBox:AddButton({ Text = "Unload Script", Func = function()
    Library:Notify({ Title = "Celestial", Description = "Script unloaded.", Time = 3, Icon = "rss" })
    Library:Unload()
end })
ScriptBox:AddButton({ Text = "Rejoin", Func = function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end })
ScriptBox:AddButton({ Text = "Server-hop", Func = function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end })

-- ===================== PLAYER LIST AUTO REFRESH =====================
Players.PlayerAdded:Connect(function()
    task.wait(1)
    pcall(function() 
        Options.TargetSelectDropdown:SetValues(GetPlayerList())
        Options.BK_TargetDropdown:SetValues(GetPlayerList())
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    if plr == State.currentTarget then
        StopKick(plr)
        State.currentTarget = nil
        State.kickActive = false
        if Toggles.KickToggle then Toggles.KickToggle:SetValue(false) end
        UpdateTargetLabel()
    end
    if plr == State.blobKick.target then
        if State.blobKick.conn then State.blobKick.conn:Disconnect(); State.blobKick.conn = nil end
        State.blobKick.active = false
        State.blobKick.target = nil
        if BK_Toggle then BK_Toggle:SetValue(false) end
        BK_TargetLabel:SetText("Target: <b>None</b>")
    end
    task.wait(0.5)
    pcall(function() 
        Options.TargetSelectDropdown:SetValues(GetPlayerList())
        Options.BK_TargetDropdown:SetValues(GetPlayerList())
    end)
end)

-- ===================== LIVE UPDATE =====================
local startTime = tick()
local kickedCount = 0

Players.PlayerRemoving:Connect(function(p)
    if p ~= LocalPlayer then
        kickedCount += 1
        KickedLabel:SetText("Kicked players: <b>" .. kickedCount .. "</b>")
    end
end)

local lastUpdate = 0
local lastPlayerRefresh = 0

RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastUpdate < 1 then return end
    lastUpdate = now
    TimeLabel:SetText("Current time: <b>" .. os.date("%H:%M") .. "</b>")
    GreetLabel:SetText(GetGreeting() .. ", <b>" .. LocalPlayer.Name .. "</b>")
    local elapsed = math.floor(now - startTime)
    local unit = elapsed == 1 and "second" or "seconds"
    ElapsedLabel:SetText("Elapsed time: <b>" .. elapsed .. " " .. unit .. "</b>")
    TogglesLabel:SetText("Toggles currently on: <b>" .. CountToggles() .. "</b>")
    if now - lastPlayerRefresh >= 3 then
        lastPlayerRefresh = now
        pcall(function() 
            Options.TargetSelectDropdown:SetValues(GetPlayerList())
            Options.BK_TargetDropdown:SetValues(GetPlayerList())
        end)
    end
end)

-- ===================== THEME / SAVE =====================
SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("WifiHub")
ThemeManager:SetFolder("WifiHub")
ThemeManager:SetDefaultTheme({
    FontColor = Color3.fromRGB(255, 255, 255),
    MainColor = Color3.fromRGB(25, 20, 40),
    AccentColor = Color3.fromRGB(160, 80, 255),
    BackgroundColor = Color3.fromRGB(15, 10, 30),
    OutlineColor = Color3.fromRGB(80, 50, 120),
})
ThemeManager:ApplyToTab(Tabs["UI"])
SaveManager:BuildConfigSection(Tabs["UI"])

Library:OnUnload(function()
    FullCleanup()
    if playerGroupConn then playerGroupConn:Disconnect() end
    if State.packetDetect.conn then State.packetDetect.conn:Disconnect() end
    if State.packetLag.conn then State.packetLag.conn:Disconnect() end
    if State.antiKickReset.conn then State.antiKickReset.conn:Disconnect() end
    if State.teleport.conn then State.teleport.conn:Disconnect() end
    if antiGucciConnection then antiGucciConnection:Disconnect() end
    if localCreatureControlConn then localCreatureControlConn:Disconnect() end
end)


Library:Notify({
    Title = "Celestial loaded!",
    Description = "Loaded in " .. tostring(math.floor((tick() - ScriptLoadStart) * 100) / 100) .. "s",
    Time = 4,
    SoundId = 4590662766,
})
