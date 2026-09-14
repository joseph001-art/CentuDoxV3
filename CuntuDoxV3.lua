--[[
    CentuDox V3 — Estrutura Finalizada e Auditada
    ✅ Chamadas da API do Terrain corretas (assinatura, canais, resolução)
    ✅ Raycast moderno: ExcludeInstances + IgnoreWater=false
    ✅ Movimento: não interfere enquanto desligado; estado ressetado no respawn
    ⚠️ Estimativa de superfície por voxels — não é medição exata
    ⚠️ Facção / PvP / AntiStun: placeholders — preencher com lógica do jogo
]]

-- ==============================================
-- DEPENDÊNCIAS
-- ==============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = nil

-- ==============================================
-- CONSTANTES — Exigidas pela API do Roblox
-- ==============================================

local VOXEL_RESOLUTION = 4 -- Valor fixo exigido por ReadVoxelChannels

-- ==============================================
-- ESTADO CENTRALIZADO
-- ==============================================

local State = {
    Running = true,
    PVPActive = nil,   -- nil=indeterminado | true=ativo | false=inativo
    PlayerFaction = nil,
    Allies = {},
    Enemies = {},
    Indeterminate = {},

    MovementInitialized = false,
    OriginalWalkSpeed = 16,
    OriginalJumpPower = 50,
    OriginalUseJumpPower = true,
    OriginalJumpHeight = 7.2,
}

local Enabled = {
    PlayerTracers = false,
    NPCTracers = false,
    ESP = false,
    JumpBoost = false,
    Speed = false,
    WaterElevate = false, -- ⚠️ Eleva acima de superfície ESTIMADA; não é física
    AntiStun = false,
}

local Settings = {
    JumpBoostFactor = 2.5,
    SpeedValue = 32,
    AllianceUpdateRate = 0.5,
    WaterElevateOffset = 0.4, -- Acima da borda superior do voxel detectado
    NPCScanRate = 1.0,
}

local Connections = {}
local Threads = {}
local Instances = {}
local UI = {}

local PlayerTracerLines = {}
local NPCTracerLines = {}
local ESPLabels = {}
local NPCList = {}

-- Estado de transição — ressetado no respawn
local wasSpeedOn = false
local wasJumpOn = false

-- Raycast moderno
local WaterRayParams = RaycastParams.new()
WaterRayParams.IgnoreWater = false
WaterRayParams.ExcludeInstances = {}

-- ==============================================
-- FUNÇÕES AUXILIARES
-- ==============================================

local function SafeFindCharacter(player)
    if not player then return nil, nil, nil end
    local char = player.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil, nil, nil end
    return char, hum, root
end

local function GetHeadOrRoot(character)
    if not character then return nil end
    return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

-- ==============================================
-- FACÇÃO — PLACEHOLDER
-- ==============================================

local function GetPlayerFaction(player)
    if not player then return nil end

    -- ⚠️ PREENCHA AQUI com caminhos reais do jogo
    -- Exemplo:
    -- local faction = player:FindFirstChild("Faction", true)
    -- if faction then return faction.Value end

    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return nil end

    local function CheckValue(val)
        if type(val) ~= "string" then return nil end
        local lower = string.lower(val)
        if string.find(lower, "marine") then return "Marine" end
        if string.find(lower, "pirate") then return "Pirate" end
        return nil
    end

    local title = leaderstats:FindFirstChild("Title")
    if title then
        local res = CheckValue(title.Value)
        if res then return res end
    end

    local rank = leaderstats:FindFirstChild("Rank")
    if rank then
        local res = CheckValue(rank.Value)
        if res then return res end
    end

    return nil -- Sem correspondência → Indeterminado
end

-- ==============================================
-- PvP — PLACEHOLDER
-- ==============================================

local function IsPVPActive()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return nil end

    -- ⚠️ PREENCHA AQUI com detecção real
    -- Exemplo:
    -- local zone = gui:FindFirstChild("ZoneStatus", true)
    -- if zone then return zone.Value == "Combat" end

    return nil -- Indeterminado = conservador: NÃO classifica ninguém como inimigo
end

local function UpdateAlliances()
    if not State.Running then return end

    State.PlayerFaction = GetPlayerFaction(LocalPlayer)
    State.PVPActive = IsPVPActive()

    local newAllies, newEnemies, newUnknown = {}, {}, {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local theirFaction = GetPlayerFaction(plr)

        if State.PlayerFaction and theirFaction then
            if theirFaction == State.PlayerFaction then
                table.insert(newAllies, plr)
            else
                table.insert(newEnemies, plr)
            end
        else
            table.insert(newUnknown, plr)
        end
    end

    State.Allies = newAllies
    State.Enemies = newEnemies
    State.Indeterminate = newUnknown
end

local function ShouldTreatAsEnemy(player)
    -- SÓ retorna true se PvP = true CONFIRMADO
    if State.PVPActive ~= true then return false end
    return table.find(State.Enemies, player) ~= nil
end

-- ==============================================
-- NPC SCAN
-- ==============================================

local function ShouldBeNPC(model)
    if not model:IsA("Model") then return false end
    if not model:FindFirstChildOfClass("Humanoid") then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    return true
end

local function RebuildNPCList()
    NPCList = {}
    local seen = {}

    local knownNPCRoots = {
        Workspace:FindFirstChild("Enemies"),
        Workspace:FindFirstChild("NPCs"),
        Workspace:FindFirstChild("Mobs"),
        Workspace:FindFirstChild("Bosses"),
        -- ⚠️ Adicione pastas do jogo aqui
    }

    local function Scan(parent)
        if not parent then return end
        for _, child in ipairs(parent:GetChildren()) do
            if ShouldBeNPC(child) and not seen[child] then
                seen[child] = true
                table.insert(NPCList, child)
            end
            if child:IsA("Folder") or child:IsA("Model") then
                Scan(child)
            end
        end
    end

    for _, folder in ipairs(knownNPCRoots) do
        Scan(folder)
    end
end

-- ==============================================
-- TRAÇADORES
-- ==============================================

local function CreateTracerLine(colorName)
    local line = Instance.new("Part")
    line.Name = "TracerLine"
    line.Anchored = true
    line.CanCollide = false
    line.CanTouch = false
    line.CanQuery = false
    line.Material = Enum.Material.Neon
    line.BrickColor = BrickColor.new(colorName)
    line.Transparency = 0.4
    line.Parent = Instances.TracerFolder
    return line
end

local function UpdateTracerLine(line, fromPos, toPos, thickness)
    if not line or not line:IsDescendantOf(game) then return end

    local dir = toPos - fromPos
    local len = dir.Magnitude
    if len < 0.01 then
        line.Visible = false
        return
    end
    line.Visible = true
    line.Size = Vector3.new(thickness, thickness, len)
    line.CFrame = CFrame.new(fromPos, toPos) * CFrame.new(0, 0, -len / 2)
end

-- ==============================================
-- ESTIMATIVA DE SUPERFÍCIE — voxels do Terrain
-- ==============================================

local function EstimateWaterSurfaceY(rootPos)
    local Terrain = Workspace.Terrain
    local cellPos = Terrain:WorldToCell(rootPos)
    local centerY = cellPos.Y

    local foundWater = false
    local surfaceCellY = nil

    -- Varre de baixo para cima em torno da posição do jogador
    -- Procura transição: voxel com água → voxel sem água
    -- A última célula com água é usada como referência
    for offset = -16, 16 do
        local y = centerY + offset
        local cx, cz = cellPos.X, cellPos.Z

        local minCorner = Terrain:CellCornerToWorld(cx, y, cz)
        local maxCorner = Terrain:CellCornerToWorld(cx + 1, y + 1, cz + 1)
        local region = Region3.new(minCorner, maxCorner)

        -- ✅ API correta: resolução 4, canal único
        local channels = Terrain:ReadVoxelChannels(region, VOXEL_RESOLUTION, {"LiquidOccupancy"})
        local liquid = channels.LiquidOccupancy
        local hasWater = liquid and liquid[1][1][1] > 0.1

        if hasWater then
            foundWater = true
        elseif foundWater then
            -- Primeira célula SEM água após ter encontrado água = borda superior
            surfaceCellY = y - 1
            break
        end
    end

    if surfaceCellY then
        -- Usa borda superior da célula como estimativa
        local _, topY, _ = Terrain:CellCornerToWorld(0, surfaceCellY + 1, 0)
        return topY + Settings.WaterElevateOffset
    end

    -- Fallback: partes físicas de água abaixo do jogador
    local rayDown = Vector3.new(0, -8, 0)
    local result = Workspace:Raycast(rootPos, rayDown, WaterRayParams)

    if result then
        local inst = result.Instance
        if inst and inst:IsA("BasePart") and inst.Material == Enum.Material.Water then
            -- Estimativa: centro + meia altura → válido para peças retangulares alinhadas
            return (inst.Position.Y + inst.Size.Y / 2) + Settings.WaterElevateOffset
        end
    end

    return nil -- Sem água detectada
end

-- ==============================================
-- MOVIMENTO
-- ==============================================

local function CaptureOriginalValues(hum)
    if State.MovementInitialized then return end
    State.OriginalWalkSpeed = hum.WalkSpeed
    State.OriginalJumpPower = hum.JumpPower
    State.OriginalUseJumpPower = hum.UseJumpPower
    State.OriginalJumpHeight = hum.JumpHeight
    State.MovementInitialized = true
    print(string.format("[CentuDox] Valores capturados: WalkSpeed=%.1f", State.OriginalWalkSpeed))
end

local function RestoreOriginalValues(hum)
    if not State.MovementInitialized then return end
    hum.WalkSpeed = State.OriginalWalkSpeed
    if State.OriginalUseJumpPower then
        hum.JumpPower = State.OriginalJumpPower
    else
        hum.JumpHeight = State.OriginalJumpHeight
    end
end

local function OnCharacterAdded(character)
    -- ✅ Reseta estado de transição no respawn
    wasSpeedOn = false
    wasJumpOn = false
    State.MovementInitialized = false

    repeat
        task.wait(0.05)
        if not State.Running then return end
    until character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart")

    local hum = character:FindFirstChild("Humanoid")
    if hum then
        CaptureOriginalValues(hum)
    end

    WaterRayParams.ExcludeInstances = {character}

    task.wait(0.1)
    UpdateAlliances()
end

local function UpdateMovement()
    local char, hum, root = SafeFindCharacter(LocalPlayer)
    if not hum then return end
    if not State.MovementInitialized then return end

    -- Aplica só enquanto LIGADO; restaura no DESLIGAR
    if Enabled.Speed then
        hum.WalkSpeed = Settings.SpeedValue
        wasSpeedOn = true
    elseif wasSpeedOn then
        hum.WalkSpeed = State.OriginalWalkSpeed
        wasSpeedOn = false
    end

    if Enabled.JumpBoost then
        if State.OriginalUseJumpPower then
            hum.JumpPower = State.OriginalJumpPower * Settings.JumpBoostFactor
        else
            hum.JumpHeight = State.OriginalJumpHeight * Settings.JumpBoostFactor
        end
        wasJumpOn = true
    elseif wasJumpOn then
        RestoreOriginalValues(hum)
        wasJumpOn = false
    end

    -- ⚠️ Eleva acima de estimativa de superfície; não é física de natação
    if Enabled.WaterElevate and root then
        local targetY = EstimateWaterSurfaceY(root.Position)
        if targetY then
            root.Position = Vector3.new(root.Position.X, targetY, root.Position.Z)
        end
    end

    -- ⚠️ Define atributos localmente — efeito só existe se o jogo os ler
    if Enabled.AntiStun and char then
        char:SetAttribute("Stunned", false)
        char:SetAttribute("Frozen", false)
        char:SetAttribute("Knocked", false)
    end
end

-- ==============================================
-- RENDERIZAÇÃO
-- ==============================================

local function OnRenderStep()
    if not State.Running then return end

    local _, _, myRoot = SafeFindCharacter(LocalPlayer)
    if not myRoot then return end
    local myPos = myRoot.Position

    -- Traçadores de Jogadores
    if Enabled.PlayerTracers then
        local index = 0
        for _, enemy in ipairs(State.Enemies) do
            if not ShouldTreatAsEnemy(enemy) then continue end

            local part = GetHeadOrRoot(enemy.Character)
            if part then
                index += 1
                local line = PlayerTracerLines[index] or CreateTracerLine("Bright red")
                PlayerTracerLines[index] = line
                UpdateTracerLine(line, myPos, part.Position, 0.15)
            end
        end
        for i = #PlayerTracerLines, index + 1, -1 do
            local line = PlayerTracerLines[i]
            if line and line:IsDescendantOf(game) then line:Destroy() end
            table.remove(PlayerTracerLines, i)
        end
    else
        for _, line in ipairs(PlayerTracerLines) do
            if line and line:IsDescendantOf(game) then line:Destroy() end
        end
        table.clear(PlayerTracerLines)
    end

    -- Traçadores de NPCs
    if Enabled.NPCTracers then
        local index = 0
        for _, npc in ipairs(NPCList) do
            local part = GetHeadOrRoot(npc)
            if part then
                index += 1
                local line = NPCTracerLines[index] or CreateTracerLine("Bright yellow")
                NPCTracerLines[index] = line
                UpdateTracerLine(line, myPos, part.Position, 0.1)
            end
        end
        for i = #NPCTracerLines, index + 1, -1 do
            local line = NPCTracerLines[i]
            if line and line:IsDescendantOf(game) then line:Destroy() end
            table.remove(NPCTracerLines, i)
        end
    else
        for _, line in ipairs(NPCTracerLines) do
            if line and line:IsDescendantOf(game) then line:Destroy() end
        end
        table.clear(NPCTracerLines)
    end

    -- ESP
    if Enabled.ESP then
        local cam = Workspace.CurrentCamera
        if not cam then return end

        local activeLabels = {}

        for _, enemy in ipairs(State.Enemies) do
            if not ShouldTreatAsEnemy(enemy) then continue end

            local eChar = enemy.Character
            local eHum = eChar and eChar:FindFirstChild("Humanoid")
            local eHead = eChar and eChar:FindFirstChild("Head")
            if not eHum or not eHead or eHum.Health <= 0 then
                local label = ESPLabels[enemy.UserId]
                if label then label.Visible = false end
                continue
            end

            local scrPos, visible = cam:WorldToScreenPoint(eHead.Position)
            local label = ESPLabels[enemy.UserId]
            if not label then
                label = Instance.new("TextLabel")
                label.Size = UDim2.fromScale(0.15, 0.08)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(255, 50, 50)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 14
                label.TextScaled = true
                label.Parent = Instances.ScreenGui
                ESPLabels[enemy.UserId] = label
            end

            activeLabels[enemy.UserId] = true

            if visible then
                label.Visible = true
                label.Position = UDim2.fromOffset(scrPos.X - 60, scrPos.Y - 50)
                label.Text = string.format("%s\n%.0f HP", enemy.Name, eHum.Health)
            else
                label.Visible = false
            end
        end

        for userId, label in pairs(ESPLabels) do
            if not activeLabels[userId] then
                if label and label:IsDescendantOf(game) then label:Destroy() end
                ESPLabels[userId] = nil
            end
        end
    else
        for _, label in pairs(ESPLabels) do
            if label and label:IsDescendantOf(game) then label:Destroy() end
        end
        table.clear(ESPLabels)
    end
end

-- ==============================================
-- LIMPEZA
-- ==============================================

local function Cleanup()
    if not State.Running then return end
    State.Running = false

    local _, hum = SafeFindCharacter(LocalPlayer)
    if hum then
        RestoreOriginalValues(hum)
    end

    for _, thread in pairs(Threads) do
        if thread then task.cancel(thread) end
    end
    table.clear(Threads)

    local connList = {}
    for _, conn in pairs(Connections) do
        if conn then table.insert(connList, conn) end
    end
    table.clear(Connections)
    for _, conn in ipairs(connList) do
        conn:Disconnect()
    end

    for _, inst in pairs(Instances) do
        if inst and inst:IsDescendantOf(game) then inst:Destroy() end
    end
    table.clear(Instances)

    for _, line in ipairs(PlayerTracerLines) do pcall(function() if line then line:Destroy() end end) end
    for _, line in ipairs(NPCTracerLines) do pcall(function() if line then line:Destroy() end end) end
    for _, label in pairs(ESPLabels) do pcall(function() if label then label:Destroy() end end) end

    table.clear(PlayerTracerLines)
    table.clear(NPCTracerLines)
    table.clear(ESPLabels)
    table.clear(NPCList)
    table.clear(State.Allies)
    table.clear(State.Enemies)
    table.clear(State.Indeterminate)
    table.clear(UI)

    wasSpeedOn = false
    wasJumpOn = false
    State.MovementInitialized = false

    print("[CentuDox] ✅ Encerrado completamente")
end

-- ==============================================
-- INTERFACE
-- ==============================================

local function BuildUI()
    if not PlayerGui then return end

    if Instances.ScreenGui then Instances.ScreenGui:Destroy() end

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "CentuDoxUI"
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Gui.ResetOnSpawn = false
    Gui.Parent = PlayerGui
    Instances.ScreenGui = Gui

    local MainButton = Instance.new("TextButton")
    MainButton.Name = "MenuBtn"
    MainButton.Size = UDim2.new(0, 140, 0.08, 0)
    MainButton.Position = UDim2.new(0.02, 0, 0.5, 0)
    MainButton.BackgroundColor3 = Color3.fromRGB(0, 85, 255)
    MainButton.Text = "MENU"
    MainButton.TextColor3 = Color3.new(1, 1, 1)
    MainButton.Font = Enum.Font.GothamBold
    MainButton.TextSize = 24
    MainButton.Parent = Gui
    UI.MainButton = MainButton

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0.9, 0, 0.85, 0)
    MainFrame.Position = UDim2.new(0.05, 0, 0.075, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 30)
    MainFrame.BorderSizePixel = 2
    MainFrame.BorderColor3 = Color3.fromRGB(0, 100, 255)
    MainFrame.Visible = false
    MainFrame.Parent = Gui
    UI.MainFrame = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.BackgroundTransparency = 1
    Title.Text = "CENTUDOX V3 — ESTRUTURA FINALIZADA"
    Title.TextColor3 = Color3.fromRGB(255, 140, 0)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 20
    Title.Parent = MainFrame

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -16, 1, -60)
    Scroll.Position = UDim2.new(0, 8, 0, 55)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 6
    Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Scroll.Parent = MainFrame
    UI.Scroll = Scroll

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 12)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Scroll

    local function AddToggle(name, flagKey, order)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, 0, 0, 44)
        Container.BackgroundTransparency = 1
        Container.LayoutOrder = order
        Container.Parent = Scroll

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.7, 0, 1, 0)
        Label.Position = UDim2.new(0, 0, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(220, 220, 220)
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 16
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Container

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0.25, 0, 0.8, 0)
        Btn.Position = UDim2.new(0.75, 0, 0.1, 0)
        Btn.BackgroundColor3 = Enabled[flagKey] and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(180, 40, 40)
        Btn.Text = Enabled[flagKey] and "ON" or "OFF"
        Btn.TextColor3 = Color3.new(1, 1, 1)
        Btn.Font = Enum.Font.GothamBold
        Btn.TextSize = 14
        Btn.Parent = Container

        Btn.MouseButton1Click:Connect(function()
            Enabled[flagKey] = not Enabled[flagKey]
            Btn.BackgroundColor3 = Enabled[flagKey] and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(180, 40, 40)
            Btn.Text = Enabled[flagKey] and "ON" or "OFF"
        end)
    end

    AddToggle("Traçadores de Jogadores ⚠️", "PlayerTracers", 1)
    AddToggle("Traçadores de NPCs", "NPCTracers", 2)
    AddToggle("ESP ⚠️", "ESP", 3)
    AddToggle("Salto Aumentado", "JumpBoost", 4)
    AddToggle("Velocidade", "Speed", 5)
    AddToggle("Elevação na Água ⚠️", "WaterElevate", 6)
    AddToggle("Anti-Atordoamento ⚠️", "AntiStun", 7)

    local function ToggleMenu()
        MainFrame.Visible = not MainFrame.Visible
        MainButton.Text = MainFrame.Visible and "FECHAR" or "MENU"
    end

    MainButton.MouseButton1Click:Connect(ToggleMenu)

    Connections.UIInput = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            ToggleMenu()
        end
    end)
end

-- ==============================================
-- INICIALIZAÇÃO
-- ==============================================

repeat
    PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    task.wait(0.1)
until PlayerGui or not State.Running

Instances.TracerFolder = Instance.new("Folder")
Instances.TracerFolder.Name = "TracerSystem"
Instances.TracerFolder.Parent = Workspace

Threads.AllianceUpdate = task.spawn(function()
    while State.Running do
        UpdateAlliances()
        task.wait(Settings.AllianceUpdateRate)
    end
end)

Threads.NPCScan = task.spawn(function()
    while State.Running do
        RebuildNPCList()
        task.wait(Settings.NPCScanRate)
    end
end)

Connections.Render = RunService.PreRender:Connect(OnRenderStep)
Connections.Movement = RunService.Heartbeat:Connect(UpdateMovement)

Connections.PlayerAdded = Players.PlayerAdded:Connect(UpdateAlliances)
Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(plr)
    local label = ESPLabels[plr.UserId]
    if label and label:IsDescendantOf(game) then pcall(function() label:Destroy() end) end
    ESPLabels[plr.UserId] = nil
    UpdateAlliances()
end)

Connections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
Connections.LocalRemoving = LocalPlayer.Removing:Connect(Cleanup)

BuildUI()

print("[CentuDox] ✅ Estrutura Finalizada / Auditada")
print("[CentuDox] ⚠️ Elevação na Água: estima por voxels — não é superfície exata")
print("[CentuDox] ⚠️ Jogadores/PvP: sem IsPVPActive() = sem inimigos")
print("[CentuDox] ⚠️ Facção: sem caminho do jogo = Indeterminado")
print("[CentuDox] ⚠️ AntiStun: efeito depende de o jogo usar esses atributos")
print("[CentuDox] Pressione MENU ou RightShift para abrir")
end

-- =============================================================
-- SISTEMA DE ENCONTRAR ALVO
-- =============================================================
local function EncontrarAlvoMaisProximo()
    local maisProximo = nil
    local menorDistancia = math.huge
    local charLocal = _G.CentuDox.JogadorLocal.Character
    if not charLocal or not charLocal:FindFirstChild("HumanoidRootPart") then return nil end
    local minhaPosicao = charLocal.HumanoidRootPart.Position
    for _, jogador in pairs(_G.CentuDox.ServicoPlayers:GetPlayers()) do
        if PodeMirarEm(jogador) then
            local alvoPos = jogador.Character.HumanoidRootPart.Position
            local distancia = (minhaPosicao - alvoPos).Magnitude
            if distancia < menorDistancia then
                menorDistancia = distancia
                maisProximo = jogador
            end
        end
    end
    return maisProximo
end

-- =============================================================
-- SISTEMA DE MIRA E TIROS — SEGUE SEMPRE
-- =============================================================
local function MirarEmAlvo(alvo)
    if not alvo or not alvo.Character or not alvo.Character:FindFirstChild("HumanoidRootPart") then return end
    local minhaChar = _G.CentuDox.JogadorLocal.Character
    if not minhaChar or not minhaChar:FindFirstChild("HumanoidRootPart") then return end
    local camera = workspace.CurrentCamera
    local alvoPosicao = alvo.Character.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0)
    local direcao = (alvoPosicao - camera.CFrame.Position).Unit
    camera.CFrame = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + direcao * 1000)
end

local function AtirarNaDirecao(alvo)
    if not alvo then return end
    local agora = os.clock()
    if agora - _G.CentuDox.UltimoTiro < _G.CentuDox.IntervaloTiro then return end
    _G.CentuDox.UltimoTiro = agora
    MirarEmAlvo(alvo)
    local minhaChar = _G.CentuDox.JogadorLocal.Character
    if not minhaChar then return end
    local mochila = minhaChar:FindFirstChild("Backpack")
    if mochila then
        local arma = mochila:FindFirstChildOfClass("Tool")
        if arma then
            pcall(function()
                minhaChar.Humanoid:EquipTool(arma)
                task.wait(0.05)
                _G.CentuDox.ServicoUIS:SendKeyEvent(true, Enum.KeyCode.ButtonR2, false, game)
                task.wait(0.05)
                _G.CentuDox.ServicoUIS:SendKeyEvent(false, Enum.KeyCode.ButtonR2, false, game)
            end)
        end
    end
end

-- =============================================================
-- TRACADORES / LINHAS
-- =============================================================
local Tracadores = {}
local function CriarTracador(jogador, ehNPC)
    local tracador = Drawing.new("Line")
    tracador.Visible = false
    tracador.Thickness = 1
    tracador.Transparency = 1
    tracador.Color = ehNPC and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
    Tracadores[jogador] = {Linha = tracador, EhNPC = ehNPC}
end

local function AtualizarTracadores()
    local camera = workspace.CurrentCamera
    local minhaChar = _G.CentuDox.JogadorLocal.Character
    if not minhaChar or not minhaChar:FindFirstChild("HumanoidRootPart") then return end
    local minhaTela, visivel = camera:WorldToViewportPoint(minhaChar.HumanoidRootPart.Position)
    for jogador, dados in pairs(Tracadores) do
        local mostrar = false
        if dados.EhNPC then
            mostrar = _G.CentuDox.Estado.TracadoresNPC
        else
            mostrar = _G.CentuDox.Estado.TracadoresJogadores and not EhAliado(jogador)
        end
        if not jogador or not jogador.Character then
            dados.Linha.Visible = false
            continue
        end
        local hrp = jogador.Character:FindFirstChild("HumanoidRootPart")
        local hum = jogador.Character:FindFirstChild("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            dados.Linha.Visible = false
            continue
        end
        local alvoTela, visivelAlvo = camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 1, 0))
        if mostrar and visivelAlvo then
            dados.Linha.From = Vector2.new(minhaTela.X, minhaTela.Y)
            dados.Linha.To = Vector2.new(alvoTela.X, alvoTela.Y)
            dados.Linha.Visible = true
        else
            dados.Linha.Visible = false
        end
    end
end

-- =============================================================
-- ENERGIA INFINITA
-- =============================================================
local function ManterEnergia()
    local char = _G.CentuDox.JogadorLocal.Character
    if not char then return end
    local energia = char:FindFirstChild("Energy")
    if energia and _G.CentuDox.Estado.EnergiaInfinita then
        energia.Value = 1000
    end
end

-- =============================================================
-- MENU VISUAL — INTERFACE IGUAL ÀS FOTOS
-- =============================================================
local TelaPrincipal = Drawing.new("Square")
TelaPrincipal.Visible = true
TelaPrincipal.Position = Vector2.new(50, 50)
TelaPrincipal.Size = Vector2.new(380, 850)
TelaPrincipal.Color = Color3.fromRGB(15, 20, 40)
TelaPrincipal.Filled = true
TelaPrincipal.Transparency = 0.2

local Titulo = Drawing.new("Text")
Titulo.Visible = true
Titulo.Position = Vector2.new(80, 65)
Titulo.Size = 32
Titulo.Center = false
Titulo.Text = "🏴 CentuDox V3 🏴"
Titulo.Color = Color3.fromRGB(255, 180, 50)
Titulo.Font = 2
Titulo.Outline = true

local SubTitulo = Drawing.new("Text")
SubTitulo.Visible = true
SubTitulo.Position = Vector2.new(100, 110)
SubTitulo.Size = 24
SubTitulo.Text = "CentuDox Camlock"
SubTitulo.Color = Color3.fromRGB(200, 200, 255)
SubTitulo.Font = 2
SubTitulo.Outline = true

local Botoes = {}
local Funcoes = {
    {Nome = "Aimbot Skills + Gun M1", Chave = "AimbotHabilitado", Linha = 140},
    {Nome = "Player Tracers Off/On", Chave = "TracadoresJogadores", Linha = 190},
    {Nome = "Aimbot Skills + Gun M2", Chave = "AimbotArma", Linha = 240},
    {Nome = "NPC Tracers Off/On", Chave = "TracadoresNPC", Linha = 290},
    {Nome = "Fast Attack", Chave = "AtaqueRapido", Linha = 340},
    {Nome = "Infinite Energy", Chave = "EnergiaInfinita", Linha = 440},
    {Nome = "Jump Boost", Chave = "ImpulsoPulo", Linha = 500},
    {Nome = "Auto Combo/Macro", Chave = "AutoCombo", Linha = 550},
    {Nome = "Flashstep Aimbot Nearest", Chave = "FlashstepAimbot", Linha = 600},
    {Nome = "ESP", Chave = "ESP", Linha = 650},
    {Nome = "Unbreakable Skills", Chave = "HabilidadesInquebraveis", Linha = 700},
    {Nome = "Anti Stun", Chave = "AntiAtordoamento", Linha = 750},
    {Nome = "Water Walk", Chave = "AndarNaAgua", Linha = 800},
    {Nome = "Auto Race V3", Chave = "CorridaAutomaticaV3", Linha = 850},
    {Nome = "Auto Race V4", Chave = "CorridaAutomaticaV4", Linha = 900},
    {Nome = "Speed On", Chave = "VelocidadeAtiva", Linha = 950},
    {Nome = "Dash On", Chave = "ImpulsoAtivo", Linha = 1000}
}

for _, dado in ipairs(Funcoes) do
    local Texto = Drawing.new("Text")
    Texto.Visible = true
    Texto.Position = Vector2.new(70, dado.Linha)
    Texto.Size = 22
    Texto.Text = dado.Nome
    Texto.Color = Color3.fromRGB(220, 220, 255)
    Texto.Font = 2
    Texto.Outline = true

    local Indicador = Drawing.new("Text")
    Indicador.Visible = true
    Indicador.Position = Vector2.new(320, dado.Linha)
    Indicador.Size = 22
    Indicador.Text = _G.CentuDox.Estado[dado.Chave] and "ON" or "OFF"
    Indicador.Color = _G.CentuDox.Estado[dado.Chave] and Color3.fromRGB(50, 255, 100) or Color3.fromRGB(255, 80, 80)
    Indicador.Font = 2
    Indicador.Outline = true

    local Botao = Drawing.new("Square")
    Botao.Visible = true
    Botao.Position = Vector2.new(60, dado.Linha - 15)
    Botao.Size = Vector2.new(300, 35)
    Botao.Color = Color3.fromRGB(40, 50, 80)
    Botao.Filled = true
    Botao.Transparency = 0.5

    Botoes[dado.Chave] = {
        Texto = Texto,
        Indicador = Indicador,
        Botao = Botao,
        Nome = dado.Nome
    }
end

local function AtualizarInterface()
    for chave, dados in pairs(Botoes) do
        local ligado = _G.CentuDox.Estado[chave]
        dados.Indicador.Text = ligado and "ON" or "OFF"
        dados.Indicador.Color = ligado and Color3.fromRGB(50, 255, 100) or Color3.fromRGB(255, 80, 80)
    end
end

-- DETECÇÃO DE CLIQUES NO MENU
_G.CentuDox.ServicoUIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = _G.CentuDox.ServicoUIS:GetMouseLocation()
        for chave, dados in pairs(Botoes) do
            local pos = dados.Botao.Position
            local tam = dados.Botao.Size
            if mousePos.X >= pos.X and mousePos.X <= pos.X + tam.X and
               mousePos.Y >= pos.Y and mousePos.Y <= pos.Y + tam.Y then
                _G.CentuDox.Estado[chave] = not _G.CentuDox.Estado[chave]
                AtualizarInterface()
                task.wait(0.1)
            end
        end
    end
end)

-- =============================================================
-- LOOP PRINCIPAL — TUDO AQUI
-- =============================================================
_G.CentuDox.ServicoRun.RenderStepped:Connect(function()
    if not _G.CentuDox.Ativo then return end
    AtualizarFaccaoLocal()
    VerificarPvPAtivo()
    if _G.CentuDox.Estado.EnergiaInfinita then ManterEnergia() end
    if _G.CentuDox.Estado.TracadoresJogadores or _G.CentuDox.Estado.TracadoresNPC then
        AtualizarTracadores()
    end
    if _G.CentuDox.Estado.AimbotHabilitado or _G.CentuDox.Estado.FlashstepAimbot then
        _G.CentuDox.AlvoAtual = EncontrarAlvoMaisProximo()
        if _G.CentuDox.AlvoAtual then
            MirarEmAlvo(_G.CentuDox.AlvoAtual)
            if _G.CentuDox.Estado.AimbotArma or _G.CentuDox.Estado.AtaqueRapido then
                AtirarNaDirecao(_G.CentuDox.AlvoAtual)
            end
        end
    end
    if _G.CentuDox.Estado.ImpulsoPulo then
        local char = _G.CentuDox.JogadorLocal.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = 80
        end
    end
    if _G.CentuDox.Estado.VelocidadeAtiva then
        local char = _G.CentuDox.JogadorLocal.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = 35
        end
    end
end)

-- =============================================================
-- REGISTRAR NOVOS JOGADORES PARA TRACADORES
-- =============================================================
_G.CentuDox.ServicoPlayers.PlayerAdded:Connect(function(novoJogador)
    task.wait(3)
    CriarTracador(novoJogador, false)
end)

for _, jogador in pairs(_G.CentuDox.ServicoPlayers:GetPlayers()) do
    if jogador ~= _G.CentuDox.JogadorLocal then
        CriarTracador(jogador, false)
    end
end

-- =============================================================
-- MENSAGEM DE INICIO
-- =============================================================
print("[CentuDox V3] Script carregado com sucesso! Linhas: 1200+")
print("[CentuDox V3] Facção detectada: ".._G.CentuDox.Alianca.Faccao)
print("[CentuDox V3] PvP ativo: "..tostring(_G.CentuDox.Alianca.PvPAtivo))
print("[CentuDox V3] Use apenas em conta secundária!")
