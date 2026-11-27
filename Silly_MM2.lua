-- Configurações de Cores (Pastel)
local colors = {
    Murderer = Color3.fromRGB(255, 182, 193), -- Vermelho Pastel
    Sheriff = Color3.fromRGB(173, 216, 230),  -- Azul Pastel
    Survivor = Color3.fromRGB(255, 255, 224)  -- Amarelo Pastel
}

local Players = game:GetService("Players")

local function applyESP(player)
    local function setupCharacter(character)
        if not character then return end
        
        -- Cria o Highlight (ESP)
        local highlight = Instance.new("Highlight")
        highlight.Name = "MM2_ESP"
        highlight.FillTransparency = 1 -- Deixa transparente apenas o preenchimento
        highlight.OutlineColor = Color3.new(1, 1, 1) -- Cor padrão inicial
        highlight.Parent = character
        
        -- Loop para atualizar a cor baseada no cargo (Role)
        -- Como o MM2 muda o cargo durante a partida, o script checa a cada segundo
        task.spawn(function()
            while character and character.Parent do
                local role = "Survivor" -- Valor padrão
                
                -- Verifica as tags/atributos de cargo do MM2
                -- O script tenta identificar se o jogador é o Murderer ou Sheriff
                if player:GetAttribute("Role") == "Murderer" or character:FindFirstChild("Murderer") then
                    role = "Murderer"
                elseif player:GetAttribute("Role") == "Sheriff" or character:FindFirstChild("Sheriff") then
                    role = "Sheriff"
                end
                
                -- Aplica a cor correspondente
                if colors[role] then
                    highlight.OutlineColor = colors[role]
                end
                
                task.wait(1)
            end
        end)
    end

    -- Garante que o ESP funcione sempre que o personagem renascer
    player.CharacterAdded:Connect(setupCharacter)
    if player.Character then
        setupCharacter(player.Character)
    end
end

-- Aplica o script a todos os jogadores atuais e novos que entrarem
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= Players.LocalPlayer then
        applyESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    applyESP(player)
end)