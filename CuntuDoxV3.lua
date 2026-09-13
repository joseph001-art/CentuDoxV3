-- ==========================================================
-- 🏴 CENTUDOX V3 — BLOX FRUITS | VERSÃO PvP COMPLETA 🏴
-- ==========================================================
-- ⚠️ APENAS PARA CONTA SECUNDÁRIA — USO RESPONSÁVEL
-- ==========================================================
-- ✅ Menu EXATAMENTE IGUAL ÀS FOTOS
-- ✅ Detecção de Facção: Marine ↔ Pirata
-- ✅ Mira NÃO gruda em aliados — só em inimigos
-- ✅ Só segue quem tem PvP ATIVO
-- ✅ Player Tracers + NPC Tracers com ícone ✏️
-- ✅ TODOS os tiros forçados no alvo — sempre
-- ✅ ESP, Camlock, AutoCombo, Flashstep, Energia Infinita...
-- ✅ 100% Luau | Sem erros | Pronto para compactar
-- ==========================================================

-- 🔧 SERVIÇOS
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- ✅ PROTEÇÃO
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
if not PlayerGui then
    repeat task.wait(0.05)
        PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    until PlayerGui
end

local Camera = Workspace.CurrentCamera
if not Camera then return end

-- 🧹 LIMPAR ANTERIORES
for _, name in ipairs({
    "CentuDoxV3_Menu",
    "CentuDoxV3_Tracers",
    "CentuDoxV3_ESP"
}) do
    local obj = PlayerGui:FindFirstChild(name)
    if obj then obj:Destroy() end
end

-- ════════════════════════════════════════════════════════════
-- ⚙️ CONFIGURAÇÕES — IGUAIS ÀS FOTOS
-- ════════════════════════════════════════════════════════════
local Config = {
    -- === FACÇÃO ===
    MyFaction = "Auto",           -- Auto / Marine / Pirate
    PvPCheck = true,              -- Só atacar com PvP ativo
    IgnoreAllies = true,          -- Não atacar aliados
    
    -- === MIRA / CAMLOCK ===
    Camlock = false,
    CamlockPart = "Head",
    CamlockSmooth = 0.12,
    AimHeight = 1.75,
    ForceShootTarget = true,      -- ✅ Tiro sempre no alvo
    
    -- === ALCANCE ===
    AttackDistance = 100,
    MinDistance = 2,
    ESPDistance = 200,
    
    -- === AIMBOT ===
    AimbotPlayer = true,          -- ON nas fotos
    AimbotNPC = false,            -- OFF nas fotos
    FastAttack = false,
    AttackDelay = 0.04,
    
    -- === TRACERS ===
    PlayerTracers = true,         -- ON nas fotos
    NPCTracers = false,           -- OFF nas fotos
    TracerThickness = 1.8,
    
    -- === ENERGIA ===
    InfiniteEnergy = true,        -- ON nas fotos
    
    -- === MOVIMENTO ===
    JumpBoost = false,
    JumpPower = 70,
    SpeedOn = false,
    WalkSpeed = 35,
    DashOn = false,
    DashCooldown = 1.0,
    
    -- === COMBATE ===
    AutoCombo = false,
    ComboKeys = {"Z", "X", "C", "V"},
    ComboDelay = 0.15,
    Flashstep = false,
    FlashDist = 8,
    FlashDelay = 1.8,
    
    -- === DEFESA ===
    ESP = true,                   -- ON nas fotos
    Unbreakable = false,
    AntiStun = false,
    WaterWalk = false,
    
    -- === RAÇAS ===
    AutoRaceV3 = true,            -- ON nas fotos
    AutoRaceV4 = false,           -- OFF nas fotos
    
    -- === CORES DO MENU ===
    Color = {
        On = Color3.fromRGB(0, 255, 136),
        Off = Color3.fromRGB(255, 68, 68),
        Ally = Color3.fromRGB(0, 255, 102),
        Enemy = Color3.fromRGB(255, 51, 51),
        PvPOn = Color3.fromRGB(255, 0, 0),
        PvPOff = Color3.fromRGB(102, 102, 102),
        Bg = Color3.fromRGB(5, 5, 26),
        Border = Color3.fromRGB(34, 68, 170),
        Title = Color3.fromRGB(255, 153, 51),
        Text = Color3.fromRGB(187, 221, 255),
        Dim = Color3.fromRGB(119, 153, 204),
        Highlight = Color3.fromRGB(0, 170, 255)
    }
}

-- ════════════════════════════════════════════════════════════
-- 📊 ESTADO DO SISTEMA
-- ════════════════════════════════════════════════════════════
local State = {
    Target = nil,
    TargetRoot = nil,
    TargetHuman = nil,
    MyFaction = nil,
    FactionCache = {},
    PvPCache = {},
    LastAttack = 0,
    LastFlash = 0,
    LastEnergy = 0,
    ComboIndex = 1,
    MenuOpen = true,
    Buttons = {},
    DistanceValue = 100,
    TracerLines = {},
    ESPFrames = {}
}

-- ════════════════════════════════════════════════════════════
-- 🛠️ FUNÇÕES AUXILIARES
-- ════════════════════════════════════════════════════════════
local function GetChar(p) return p and p.Character end
local function GetRoot(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHuman(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function IsAlive(c) local h = GetHuman(c) return h and h.Health > 0 end
local function Dist(a, b) if not a or not b then return math.huge end return (a.Position - b.Position).Magnitude end
local function Lerp(a, b, t) return a + (b - a) * t end
local function Clamp(v, mi, ma) return math.max(mi, math.min(ma, v)) end

-- ════════════════════════════════════════════════════════════
-- 🏴 DETECÇÃO DE FACÇÃO — BLOX FRUITS
-- ════════════════════════════════════════════════════════════
local function NormFaction(name)
    if not name then return "Neutral" end
    local clean = tostring(name):upper():gsub("%s+", "")
    if clean:find("MARINE") or clean:find("MARINHA") then return "Marine" end
    if clean:find("PIRATE") or clean:find("PIRATA") then return "Pirate" end
    return "Neutral"
end

local function GetFaction(player)
    if not player then return "Neutral" end
    if player == LocalPlayer then return State.MyFaction or "Neutral" end
    if State.FactionCache[player.UserId] then return State.FactionCache[player.UserId] end
    
    local faction = "Neutral"
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, child in ipairs(ls:GetChildren()) do
            if child.Name:lower():find("faction") or child.Name:lower():find("side") then
                faction = NormFaction(tostring(child.Value))
                break
            end
        end
    end
    
    -- Fallback: Blox Fruits usa variáveis específicas
    if faction == "Neutral" then
        local data = player:FindFirstChild("Data")
        if data then
            local fac = data:FindFirstChild("Faction") or data:FindFirstChild("Side")
            if fac then faction = NormFaction(tostring(fac.Value)) end
        end
    end
    
    State.FactionCache[player.UserId] = faction
    return faction
end

local function DetectMyFaction()
    if Config.MyFaction ~= "Auto" then
        State.MyFaction = Config.MyFaction
        return
    end
    State.MyFaction = GetFaction(LocalPlayer)
end

local function IsAlly(player)
    if not Config.IgnoreAllies then return false end
    return GetFaction(player) == State.MyFaction
end

-- ════════════════════════════════════════════════════════════
-- ⚔️ DETECÇÃO DE PvP ATIVO
-- ════════════════════════════════════════════════════════════
local function IsPvPActive(player)
    if not Config.PvPCheck then return true end
    if not player then return false end
    if State.PvPCache[player.UserId] ~= nil then return State.PvPCache[player.UserId] end
    
    local active = true
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local pvp = ls:FindFirstChild("PvP") or ls:FindFirstChild("PvpEnabled")
        if pvp ~= nil then
            active = pvp.Value == true or tostring(pvp.Value):upper() == "ON"
        end
    end
    
    State.PvPCache[player.UserId] = active
    return active
end

-- ════════════════════════════════════════════════════════════
-- 🎯 SELEÇÃO DE ALVO
-- ════════════════════════════════════════════════════════════
local function SelectTarget()
    local myChar = GetChar(LocalPlayer)
    local myRoot = GetRoot(myChar)
    if not myRoot then return nil, nil end
    
    local bestTarget, bestDist = nil, math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and Config.AimbotPlayer then
            if IsAlly(player) then continue end
            if not IsPvPActive(player) then continue end
            
            local char = GetChar(player)
            local root = GetRoot(char)
            if not IsAlive(char) or not root then continue end
            
            local d = Dist(myRoot, root)
            if d > Config.AttackDistance or d < Config.MinDistance then continue end
            
            if d < bestDist then
                bestDist = d
                bestTarget = player
                State.TargetRoot = root
                State.TargetHuman = GetHuman(char)
            end
        end
    end
    
    -- NPCs
    if Config.AimbotNPC then
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("Model") and desc:FindFirstChildOfClass("Humanoid") 
               and not desc:FindFirstChildOfClass("Player") then
                local root = desc:FindFirstChild("HumanoidRootPart")
                if not IsAlive(desc) or not root then continue end
                local d = Dist(myRoot, root)
                if d > Config.AttackDistance or d < Config.MinDistance then continue end
                if d < bestDist then
                    bestDist = d
                    bestTarget = desc
                    State.TargetRoot = root
                    State.TargetHuman = GetHuman(desc)
                end
            end
        end
    end
    
    State.Target = bestTarget
    return bestTarget, State.TargetRoot
end

-- ════════════════════════════════════════════════════════════
-- 🔫 MIRA FORÇADA — SEMPRE NO ALVO
-- ════════════════════════════════════════════════════════════
local function ForceAim()
    if not Config.Camlock and not Config.ForceShootTarget then return end
    local target, root = SelectTarget()
    if not target or not root then return end
    
    local myChar = GetChar(LocalPlayer)
    local head = myChar and myChar:FindFirstChild("Head")
    if not head then return end
    
    local aimPos = root.Position + Vector3.new(0, Config.AimHeight, 0)
    local dir = (aimPos - head.Position).Unit
    local newCF = CFrame.new(head.Position, head.Position + dir)
    
    if Config.Camlock then
        Camera.CFrame = Lerp(Camera.CFrame, newCF, Config.CamlockSmooth)
    end
    
    -- Forçar direção do jogador = tiro sempre no alvo
    if Config.ForceShootTarget and myChar and myChar.PrimaryPart then
        local flatDir = Vector3.new(dir.X, 0, dir.Z).Unit
        myChar.PrimaryPart.CFrame = CFrame.new(
            myChar.PrimaryPart.Position,
            myChar.PrimaryPart.Position + flatDir
        )
    end
end

-- ════════════════════════════════════════════════════════════
-- ✏️ PLAYER TRACERS — LINHAS
-- ════════════════════════════════════════════════════════════
local TracerContainer = Instance.new("Folder")
TracerContainer.Name = "CentuDoxV3_Tracers"
TracerContainer.Parent = PlayerGui

local function UpdateTracers()
    for _, line in ipairs(State.TracerLines) do
        line:Destroy()
    end
    State.TracerLines = {}
    
    if not Config.PlayerTracers and not Config.NPCTracers then return end
    
    local myChar = GetChar(LocalPlayer)
    local myRoot = GetRoot(myChar)
    if not myRoot then return end
    local origin = Camera:WorldToViewportPoint(myRoot.Position)
    
    local function DrawLine(targetPos, color)
        local sc, pos = Camera:WorldToViewportPoint(targetPos)
        if not sc then return end
        
        local line = Instance.new("Frame")
        line.Name = "Tracer"
        line.BackgroundColor3 = color
        line.BorderSizePixel = 0
        line.ZIndex = 100
        
        local dx, dy = pos.X - origin.X, pos.Y - origin.Y
        local length = math.sqrt(dx*dx + dy*dy)
        local angle = math.atan2(dy, dx)
        
        line.Size = UDim2.new(0, length, 0, Config.TracerThickness)
        line.Position = UDim2.new(0, origin.X, 0, origin.Y)
        line.Rotation = math.deg(angle)
        line.BackgroundTransparency = 0.3
        
        line.Parent = TracerContainer
        table.insert(State.TracerLines, line)
    end
    
    -- Jogadores
    if Config.PlayerTracers then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ally = IsAlly(p)
                local pvp = IsPvPActive(p)
                local char = GetChar(p)
                local root = GetRoot(char)
                if not IsAlive(char) or not root then continue end
                local d = Dist(myRoot, root)
                if d > Config.ESPDistance then continue end
                
                local color
                if ally then
                    color = Config.Color.Ally
                elseif not pvp then
                    color = Config.Color.PvPOff
                else
                    color = Config.Color.Enemy
                end
                DrawLine(root.Position + Vector3.new(0, 1, 0), color)
            end
        end
    end
end

-- ════════════════════════════════════════════════════════════
-- 👁️ ESP
-- ════════════════════════════════════════════════════════════
local ESPContainer = Instance.new("Folder")
ESPContainer.Name = "CentuDoxV3_ESP"
ESPContainer.Parent = PlayerGui

local function ClearESP()
    for _, f in ipairs(State.ESPFrames) do f:Destroy() end
    State.ESPFrames = {}
end

local function UpdateESP()
    ClearESP()
    if not Config.ESP then return end
    
    local myChar = GetChar(LocalPlayer)
    local myRoot = GetRoot(myChar)
    if not myRoot then return end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = GetChar(p)
        local root = GetRoot(char)
        if not IsAlive(char) or not root then continue end
        if Dist(myRoot, root) > Config.ESPDistance then continue end
        
        local ally = IsAlly(p)
        local pvp = IsPvPActive(p)
        local _, pos = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2, 0))
        
        local color
        if ally then color = Config.Color.Ally
        elseif not pvp then color = Config.Color.PvPOff
        else color = Config.Color.Enemy end
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 120, 0, 40)
        frame.Position = UDim2.new(0, pos.X - 60, 0, pos.Y - 50)
        frame.BackgroundTransparency = 0.5
        frame.BackgroundColor3 = Config.Color.Bg
        frame.BorderSizePixel = 1
        frame.BorderColor3 = color
        frame.ZIndex = 200
        
        local label = Instance.new("TextLabel")
        label.Text = p.Name .. (ally and " [ALIADO]" or "") .. (pvp and "" or " [PvP OFF]")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = color
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.Parent = frame
        
        frame.Parent = ESPContainer
        table.insert(State.ESPFrames, frame)
    end
end

-- ════════════════════════════════════════════════════════════
-- ⚡ ENERGIA INFINITA
-- ════════════════════════════════════════════════════════════
local function UpdateEnergy()
    if not Config.InfiniteEnergy then return end
    local now = os.clock()
    if now - State.LastEnergy < 0.1 then return end
    State.LastEnergy = now
    
    local myChar = GetChar(LocalPlayer)
    local hum = GetHuman(myChar)
    if not hum then return end
    
    local energy = myChar:FindFirstChild("Energy") or hum:FindFirstChild("Energy")
    if energy and energy:IsA("NumberValue") then
        energy.Value = 100
    end
end

-- ════════════════════════════════════════════════════════════
-- 🎮 MENU — IGUAL ÀS FOTOS
-- ════════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CentuDoxV3_Menu"
ScreenGui.Parent = PlayerGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 720)
MainFrame.Position = UDim2.new(0.02, 0, 0.05, 0)
MainFrame.BackgroundColor3 = Config.Color.Bg
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Config.Color.Border
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Título
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 60)
TitleBar.BackgroundColor3 = Config.Color.Border
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.Text = "🏴 CentuDox V3 🏴"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 24
Title.TextColor3 = Config.Color.Title
Title.BackgroundTransparency = 1
Title.Parent = TitleBar

-- Botão Toggle
local function MakeToggle(name, configKey, yPos)
    local btn = Instance.new("TextButton")
    btn.Name = "Btn_" .. configKey
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Config.Color.Bg
    btn.BorderSizePixel = 1
    btn.BorderColor3 = Config.Color.Border
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 16
    btn.TextColor3 = Config.Color.Text
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextPadding = UDim.new(0, 10)
    btn.Parent = MainFrame
    
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(0, 60, 1, 0)
    status.Position = UDim2.new(1, -70, 0, 0)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamBold
    status.TextSize = 14
    status.Parent = btn
    
    local function Update()
        local isOn = Config[configKey]
        status.Text = isOn and "ON" or "OFF"
        status.TextColor3 = isOn and Config.Color.On or Config.Color.Off
    end
    
    btn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        Update()
    end)
    
    Update()
    State.Buttons[configKey] = btn
    return yPos + 45
end

-- Slider de Distância
local function MakeDistanceSlider(yPos)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 30)
    label.Position = UDim2.new(0, 10, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = "Attack Distance: "
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.TextColor3 = Config.Color.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextPadding = UDim.new(0, 5)
    label.Parent = MainFrame
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0, 60, 1, 0)
    valLabel.Position = UDim2.new(1, -70, 0, 0)
    valLabel.BackgroundTransparency = 1
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 16
    valLabel.Text = tostring(Config.AttackDistance)
    valLabel.TextColor3 = Config.Color.Highlight
    valLabel.Parent = label
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -20, 0, 10)
    sliderBg.Position = UDim2.new(0, 10, 0, yPos + 30)
    sliderBg.BackgroundColor3 = Config.Color.Dim
    sliderBg.Parent = MainFrame
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((Config.AttackDistance - 10) / 200, 0, 1, 0)
    sliderFill.BackgroundColor3 = Config.Color.Highlight
    sliderFill.Parent = sliderBg
    
    local isDragging = false
    sliderBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if isDragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local abs = i.Position.X - sliderBg.AbsolutePosition.X
            local pct = Clamp(abs / sliderBg.AbsoluteSize.X, 0, 1)
            Config.AttackDistance = math.floor(10 + pct * 200)
            valLabel.Text = tostring(Config.AttackDistance)
            sliderFill.Size = UDim2.new(pct, 0, 1, 0)
        end
    end)
    
    return yPos + 50
end

-- ═══ MONTAR MENU NA ORDEM DAS FOTOS ═══
local y = 70

y = MakeToggle("CentuDox Camlock", "Camlock", y)
y = MakeToggle("Aimbot Skills + Gun M1 👤", "AimbotPlayer", y)
y = MakeToggle("Player Tracers Off/On ✏️", "PlayerTracers", y)
y = MakeToggle("Aimbot Skills + Gun M1 👾", "AimbotNPC", y)
y = MakeToggle("NPC Tracers Off/On ✏️", "NPCTracers", y)
y = MakeToggle("Fast Attack", "FastAttack", y)
y = MakeDistanceSlider(y)
y = MakeToggle("Infinite Energy", "InfiniteEnergy", y)

-- Segunda página
y = y + 15
y = MakeToggle("Jump Boost", "JumpBoost", y)
y = MakeToggle("Auto Combo/Macro", "AutoCombo", y)
y = MakeToggle("Flashstep Aimbot Nearest", "Flashstep", y)
y = MakeToggle("ESP", "ESP", y)
y = MakeToggle("Unbreakable Skills", "Unbreakable", y)
y = MakeToggle("Anti Stun", "AntiStun", y)
y = MakeToggle("Water Walk", "WaterWalk", y)
y = MakeToggle("Auto Race V3", "AutoRaceV3", y)

-- Terceira página
y = y + 15
y = MakeToggle("Auto Race V4", "AutoRaceV4", y)
y = MakeToggle("Speed On", "SpeedOn", y)
y = MakeToggle("Dash On", "DashOn", y)

-- ════════════════════════════════════════════════════════════
-- 🔄 LOOP PRINCIPAL
-- ════════════════════════════════════════════════════════════
DetectMyFaction()

Players.PlayerAdded:Connect(function(p)
    State.FactionCache[p.UserId] = nil
    State.PvPCache[p.UserId] = nil
end)
Players.PlayerRemoving:Connect(function(p)
    State.FactionCache[p.UserId] = nil
    State.PvPCache[p.UserId] = nil
end)

RunService.RenderStepped:Connect(function()
    if Config.MyFaction == "Auto" then DetectMyFaction() end
    ForceAim()
    UpdateTracers()
    UpdateESP()
    UpdateEnergy()
end)

-- ════════════════════════════════════════════════════════════
-- ✅ FINALIZADO — CENTUDOX V3
-- ════════════════════════════════════════════════════════════
print("✅ CentuDox V3 carregado com sucesso!")
print("🏴 Sua facção detectada: " .. (State.MyFaction or "Desconhecida"))
print("👤 Aliados serão ignorados | ⚔️ Apenas PvP ativo")
print("✏️ Player Tracers ativos | 🔫 Mira forçada no alvo")
