-- BUU | MM2 ESP (outline): Murder = vermelho, Sheriff = azul, Survivor = amarelo
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

if getgenv and getgenv().KSNEXUS_MM2_ESP then
    pcall(getgenv().KSNEXUS_MM2_ESP)
end

local COLORS = {
    Murder   = Color3.fromRGB(255, 105, 97),  -- vermelho pastel
    Sheriff  = Color3.fromRGB(119, 158, 203), -- azul pastel
    Survivor = Color3.fromRGB(253, 253, 150), -- amarelo pastel
}

local folder = Instance.new("Folder")
folder.Name = "KSNEXUS_ESP"
local okParent = pcall(function()
    folder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not okParent or not folder.Parent then
    folder.Parent = lp:WaitForChild("PlayerGui")
end

local roles, highlights, conns = {}, {}, {}
local running = true

local function hasTool(player, name)
    local bp = player:FindFirstChildOfClass("Backpack")
    local ch = player.Character
    for _, c in ipairs({ bp, ch }) do
        if c then
            local t = c:FindFirstChild(name)
            if t and t:IsA("Tool") then return true end
        end
    end
    return false
end

local function getRole(player)
    if hasTool(player, "Knife") then
        roles[player] = "Murder"
    elseif hasTool(player, "Gun") then
        roles[player] = "Sheriff"
    end
    return roles[player] or "Survivor" -- papel fica em cache, então persiste após a morte
end

local function removeHighlight(player)
    local h = highlights[player]
    if h then h:Destroy() end
    highlights[player] = nil
end

local function hookPlayer(player)
    if player == lp then return end
    conns[#conns + 1] = player.CharacterAdded:Connect(function()
        roles[player] = nil -- novo personagem = nova rodada
    end)
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
conns[#conns + 1] = Players.PlayerAdded:Connect(hookPlayer)
conns[#conns + 1] = Players.PlayerRemoving:Connect(function(p)
    removeHighlight(p)
    roles[p] = nil
end)

task.spawn(function()
    while running do
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lp then
                local char = player.Character
                if char and char.Parent then
                    local h = highlights[player]
                    if not h or not h.Parent then
                        h = Instance.new("Highlight")
                        h.FillTransparency = 1 -- só contorno
                        h.OutlineTransparency = 0
                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        h.Parent = folder
                        highlights[player] = h
                    end
                    h.Adornee = char
                    h.OutlineColor = COLORS[getRole(player)]
                else
                    removeHighlight(player)
                end
            end
        end
        task.wait(0.2)
    end
end)

if getgenv then
    getgenv().KSNEXUS_MM2_ESP = function()
        running = false
        for _, c in ipairs(conns) do c:Disconnect() end
        folder:Destroy()
    end
end
