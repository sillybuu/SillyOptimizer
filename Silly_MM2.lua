-- Murder Mystery 2 ESP Wallhack Script
-- Cores: Vermelho Pastel (Murder), Azul Pastel (Sheriff), Amarelo Pastel (Sobreviventes)
-- Funciona mesmo após morrer

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Criando pasta para os efeitos ESP no CoreGui
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "MM2_ESP"
ESPFolder.Parent = game.CoreGui

-- Cores pastel solicitadas
local Colors = {
    Murderer = Color3.fromRGB(255, 182, 193),   -- Vermelho Pastel
    Sheriff = Color3.fromRGB(173, 216, 230),   -- Azul Pastel  
    Innocent = Color3.fromRGB(255, 255, 224)   -- Amarelo Pastel
}

-- Função para obter a cor com base na função do jogador
local function GetRoleColor(role)
    return Colors[role] or Colors.Innocent
end

-- Função para identificar o papel de um jogador
local function GetPlayerRole(player)
    if player == LocalPlayer then return nil end
    
    local character = player.Character
    if not character then return "Innocent" end
    
    -- Verificando itens no personagem ou backpack
    local hasKnife = character:FindFirstChild("Knife") or 
                     (player.Backpack and player.Backpack:FindFirstChild("Knife"))
    
    local hasGun = character:FindFirstChild("Gun") or 
                   character:FindFirstChild("Revolver") or
                   (player.Backpack and (player.Backpack:FindFirstChild("Gun") or player.Backpack:FindFirstChild("Revolver")))
    
    if hasKnife then return "Murderer" end
    if hasGun then return "Sheriff" end
    
    return "Innocent"
end

-- Função para criar o ESP com outline
local function CreateESP(player)
    -- Criando Highlight (outline) para o jogador
    local highlight = Instance.new("Highlight")
    highlight.Name = player.Name .. "_ESP_Highlight"
    highlight.Enabled = false
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0.3
    highlight.Parent = ESPFolder
    
    -- Criando BillboardGui para texto
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "RoleTag"
    billboard.Size = UDim2.new(0, 80, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = highlight
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextStrokeTransparency = 0.5
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 12
    textLabel.Text = ""
    textLabel.Parent = billboard
    
    -- Conexão para atualizar o ESP a cada frame
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not player or not player.Parent then
            if connection then connection:Disconnect() end
            highlight:Destroy()
            return
        end
        
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            -- Atualizando o adornee para mostrar o outline através das paredes
            highlight.Adornee = char
            highlight.Enabled = true
            
            -- Obter função do jogador e atualizar cor
            local role = GetPlayerRole(player)
            local color = GetRoleColor(role)
            
            highlight.OutlineColor = color
            
            -- Atualizando texto baseado na função
            if role == "Murderer" then
                textLabel.Text = "MURDER"
                textLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
            elseif role == "Sheriff" then
                textLabel.Text = "SHERIFF"
                textLabel.TextColor3 = Color3.fromRGB(50, 100, 200)
            else
                textLabel.Text = "SURVIVOR"
                textLabel.TextColor3 = Color3.fromRGB(200, 180, 50)
            end
            
        else
            -- Se não tiver character (morreu), ainda mostra o ESP para manter a funcionalidade
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                highlight.Adornee = player.Character
                highlight.Enabled = true
                
                local role = GetPlayerRole(player)
                local color = GetRoleColor(role)
                
                highlight.OutlineColor = color
            else
                -- Se o jogador não estiver no jogo, desativar ESP
                highlight.Enabled = false
            end
        end
        
    end)
    
    return connection
end

-- Função para criar ESP de todos os jogadores atuais
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

-- Conectar para novos jogadores
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end)

-- Limpar quando o jogador sair
Players.PlayerRemoving:Connect(function(player)
    local esp = ESPFolder:FindFirstChild(player.Name .. "_ESP_Highlight")
    if esp then esp:Destroy() end
end)

print("Murder Mystery 2 ESP Wallhack Loaded!")
print("Vermelho Pastel - Murder | Azul Pastel - Sheriff | Amarelo Pastel - Sobreviventes")

-- Enviar notificação ao usuário
game.StarterGui:SetCore("SendNotification", {
    Title = "ESP Wallhack MM2",
    Text = "Carregado com sucesso!",
    Duration = 3
})
