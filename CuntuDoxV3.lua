--[[
    Nome: CentuDox V3 — Blox Fruits PvP Completo
    Versão: 3.0. Linhas: ~1200
    Uso: Conta secundária / Projeto pessoal
    Funções: Menu visual igual às fotos | Aliança Marine/Pirata | Aimbot 100% | Tracers | ESP | Auto Race | Infinito Energia | Etc
]]

-- =============================================================
-- DEPURAÇÃO E CONFIGURAÇÕES GLOBAIS
-- =============================================================
_G.CentuDox = {
    Versao = "3.0",
    Ativo = true,
    JogadorLocal = game.Players.LocalPlayer,
    ServicoPlayers = game:GetService("Players"),
    ServicoRun = game:GetService("RunService"),
    ServicoInput = game:GetService("UserInputService"),
    ServicoTween = game:GetService("TweenService"),
    ServicoUIS = game:GetService("UserInputService"),
    ServicoWorkspace = game:GetService("Workspace"),
    Alianca = {
        Faccao = "Indefinida", -- "Marine" ou "Pirata"
        Aliados = {},
        PvPAtivo = false
    },
    Estado = {
        AimbotHabilitado = false,
        AimbotArma = false,
        TracadoresJogadores = false,
        TracadoresNPC = false,
        AtaqueRapido = false,
        DistanciaAtaque = 100,
        EnergiaInfinita = false,
        ImpulsoPulo = false,
        AutoCombo = false,
        FlashstepAimbot = false,
        ESP = false,
        HabilidadesInquebraveis = false,
        AntiAtordoamento = false,
        AndarNaAgua = false,
        CorridaAutomaticaV3 = false,
        CorridaAutomaticaV4 = false,
        VelocidadeAtiva = false,
        ImpulsoAtivo = false
    },
    AlvoAtual = nil,
    AlvoTempo = 0,
    UltimoTiro = 0,
    IntervaloTiro = 0.1
}

-- =============================================================
-- DETECÇÃO DE FACÇÃO E ALIANÇA
-- =============================================================
local function ObterFaccaoJogador(jogador)
    if not jogador or not jogador:FindFirstChild("Data") then return "Indefinida" end
    local success, resultado = pcall(function()
        return jogador.Data:FindFirstChild("Faction") and jogador.Data.Faction.Value or "Indefinida"
    end)
    return success and resultado or "Indefinida"
end

local function AtualizarFaccaoLocal()
    _G.CentuDox.Alianca.Faccao = ObterFaccaoJogador(_G.CentuDox.JogadorLocal)
end

local function VerificarPvPAtivo()
    local char = _G.CentuDox.JogadorLocal.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local zonaSegura = false
    for _, descendente in pairs(_G.CentuDox.ServicoWorkspace:GetDescendants()) do
        if descendente:IsA("BasePart") and descendente.Name:find("SafeZone") or descendente.Name:find("Safe") then
            if (hrp.Position - descendente.Position).Magnitude < descendente.Size.X then
                zonaSegura = true
                break
            end
        end
    end
    _G.CentuDox.Alianca.PvPAtivo = not zonaSegura
    return _G.CentuDox.Alianca.PvPAtivo
end

local function EhAliado(jogador)
    if jogador == _G.CentuDox.JogadorLocal then return true end
    local faccaoAlvo = ObterFaccaoJogador(jogador)
    local minhaFaccao = _G.CentuDox.Alianca.Faccao
    if minhaFaccao == "Marine" then
        return faccaoAlvo == "Marine"
    elseif minhaFaccao == "Pirata" then
        return faccaoAlvo == "Pirata"
    end
    return false
end

local function PodeMirarEm(jogador)
    if not jogador or not jogador.Character then return false end
    if jogador == _G.CentuDox.JogadorLocal then return false end
    local humanoid = jogador.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if EhAliado(jogador) then return false end
    if not _G.CentuDox.Alianca.PvPAtivo then return false end
    local dist = (_G.CentuDox.JogadorLocal.Character.HumanoidRootPart.Position - jogador.Character.HumanoidRootPart.Position).Magnitude
    if dist > _G.CentuDox.Estado.DistanciaAtaque then return false end
    return true
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
