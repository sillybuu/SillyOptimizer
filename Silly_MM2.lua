-- KS NEXUS | MM2 Role ESP (Murder / Sheriff / Survivor)
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local CONFIG = {
	-- Nomes das tools usados para identificar o papel (ver nota de suposição)
	MurderTool = "Knife",
	SheriffTool = "Gun",

	Colors = {
		Murder   = Color3.fromRGB(255, 128, 128), -- vermelho pastel
		Sheriff  = Color3.fromRGB(128, 170, 255), -- azul pastel
		Survivor = Color3.fromRGB(255, 236, 140), -- amarelo pastel
	},

	FillTransparency    = 0.80, -- preenchimento bem sutil
	OutlineTransparency = 0.35, -- contorno mais visível
	RefreshInterval     = 0.5,  -- varredura de segurança (segundos)
}

local env = (getgenv and getgenv()) or _G
if env.KS_MM2_ESP then
	pcall(env.KS_MM2_ESP.Destroy) -- reexecução limpa a instância anterior
end

local localPlayer = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "KS_MM2_ESP"
do
	local parent = (gethui and gethui()) or CoreGui
	if not pcall(function() folder.Parent = parent end) then
		folder.Parent = localPlayer:WaitForChild("PlayerGui")
	end
end

local entries = {}
local globalConns = {}
local running = true

local function clear(list)
	for i = #list, 1, -1 do
		list[i]:Disconnect()
		list[i] = nil
	end
end

local function hasTool(player, name)
	local char = player.Character
	local t = char and char:FindFirstChild(name)
	if t and t:IsA("Tool") then return true end
	local bp = player:FindFirstChildOfClass("Backpack")
	t = bp and bp:FindFirstChild(name)
	return t ~= nil and t:IsA("Tool")
end

local function roleOf(player)
	if hasTool(player, CONFIG.MurderTool) then return "Murder" end
	if hasTool(player, CONFIG.SheriffTool) then return "Sheriff" end
	return "Survivor"
end

local function refresh(player)
	local e = entries[player]
	if not e then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hl = e.highlight
	if not hum or hum.Health <= 0 then
		hl.Enabled = false
		hl.Adornee = nil
		return
	end
	local color = CONFIG.Colors[roleOf(player)]
	if hl.Adornee ~= char then hl.Adornee = char end
	hl.FillColor = color
	hl.OutlineColor = color
	hl.Enabled = true
end

local function bindBackpack(e, bp)
	clear(e.bpConns)
	local function onChange() refresh(e.player) end
	table.insert(e.bpConns, bp.ChildAdded:Connect(onChange))
	table.insert(e.bpConns, bp.ChildRemoved:Connect(onChange))
end

local function bindCharacter(e, char)
	clear(e.charConns)
	local function onChange() refresh(e.player) end
	table.insert(e.charConns, char.ChildAdded:Connect(onChange))
	table.insert(e.charConns, char.ChildRemoved:Connect(onChange))
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		table.insert(e.charConns, hum.Died:Connect(onChange))
	end
	refresh(e.player)
end

local function addPlayer(player)
	if player == localPlayer or entries[player] then return end

	local hl = Instance.new("Highlight")
	hl.Name = player.Name
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillTransparency = CONFIG.FillTransparency
	hl.OutlineTransparency = CONFIG.OutlineTransparency
	hl.Enabled = false
	hl.Parent = folder

	local e = {
		player = player,
		highlight = hl,
		conns = {},
		charConns = {},
		bpConns = {},
	}
	entries[player] = e

	table.insert(e.conns, player.CharacterAdded:Connect(function(char)
		bindCharacter(e, char)
	end))
	table.insert(e.conns, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			bindBackpack(e, child)
			refresh(player)
		end
	end))

	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then bindBackpack(e, bp) end
	if player.Character then bindCharacter(e, player.Character) end
end

local function removePlayer(player)
	local e = entries[player]
	if not e then return end
	entries[player] = nil
	clear(e.conns)
	clear(e.charConns)
	clear(e.bpConns)
	e.highlight:Destroy()
end

table.insert(globalConns, Players.PlayerAdded:Connect(addPlayer))
table.insert(globalConns, Players.PlayerRemoving:Connect(removePlayer))
for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end

task.spawn(function()
	while running do
		task.wait(CONFIG.RefreshInterval)
		for player in pairs(entries) do refresh(player) end
	end
end)

env.KS_MM2_ESP = {
	Destroy = function()
		running = false
		clear(globalConns)
		for player in pairs(entries) do removePlayer(player) end
		folder:Destroy()
		env.KS_MM2_ESP = nil
	end,
}
