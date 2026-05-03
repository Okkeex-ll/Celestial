-- Загрузка библиотеки
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/m1kp0/BetterOrion/refs/heads/main/Library.lua'))()

-- Сервисы и глобальные переменные
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Struggle = ReplicatedStorage:WaitForChild("Struggle", 5)

-- Состояния
local State = {
    antiGrab = { active = false, proc = false, conn = nil }
}

-- Создание окна
local Window = OrionLib:MakeWindow({
    Name = "Hexagon",
    IntroEnabled = true,
    IntroText = "Hexagon",
    IntroIcon = "hexagon",
    Size = UDim2.fromOffset(600, 400),
    ToggleUIKey = Enum.KeyCode.RightShift
})

-- Вкладка Main
local MainTab = Window:MakeTab({
    Name = "Main",
    Icon = "home"
})

-- Секция Defense
local DefenseSection = MainTab:AddSection({
    Name = "Defense",
    Side = "Left"
})

-- ===================== ANTI-GRAB (оптимизированная версия) =====================
DefenseSection:AddToggle({
    Name = "Anti-grab",
    Default = false,
    Callback = function(enabled)
        State.antiGrab.active = enabled
        
        if enabled then
            -- Включение
            if State.antiGrab.conn then State.antiGrab.conn:Disconnect() end
            
            local running = true
            State.antiGrab.conn = { Disconnect = function() running = false end }
            
            local function Setup(char)
                local hrp, head = char:WaitForChild("HumanoidRootPart", 5), char:WaitForChild("Head", 5)
                if not (hrp and head) then return end
                
                -- Отключение BallSocket
                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                        pcall(function() 
                            v.BallSocketConstraint.Enabled = false
                            local ragdoll = v:FindFirstChild("RagdollLimbPart")
                            if ragdoll then ragdoll.WeldConstraint.Enabled = false end
                        end)
                    end
                end
                
                -- Обработка захвата
                head.ChildAdded:Connect(function(obj)
                    if obj.Name ~= "PartOwner" or State.antiGrab.proc then return end
                    
                    State.antiGrab.proc = true
                    hrp.Anchored = true
                    
                    task.spawn(function()
                        while head:FindFirstChild("PartOwner") or (LocalPlayer:FindFirstChild("IsHeld") and LocalPlayer.IsHeld.Value) do
                            if Struggle then
                                for _ = 1, 3 do pcall(function() Struggle:FireServer(LocalPlayer) end) end
                            end
                            task.wait()
                        end
                    end)
                    
                    repeat task.wait() until not head:FindFirstChild("PartOwner") and not (LocalPlayer.IsHeld and LocalPlayer.IsHeld.Value)
                    
                    hrp.Anchored = false
                    State.antiGrab.proc = false
                end)
            end
            
            if LocalPlayer.Character then Setup(LocalPlayer.Character) end
            LocalPlayer.CharacterAdded:Connect(function(char)
                if not running then return end
                State.antiGrab.proc = false
                task.wait(0.5)
                Setup(char)
            end)
        else
            -- Выключение
            if State.antiGrab.conn then 
                State.antiGrab.conn:Disconnect()
                State.antiGrab.conn = nil 
            end
            State.antiGrab.proc = false
            
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = false end
            end
        end
    end
})

-- Инициализация
OrionLib:Init()
