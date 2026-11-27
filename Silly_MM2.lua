-- KS NEXUS | MM2 Role ESP + Sheriff Silent Aim
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

local CONFIG = {
	MurderTool = "Knife",
	SheriffTool = "Gun",

	Colors = {
		Murder   = Color3.fromRGB(255, 128, 128),
		Sheriff  = Color3.fromRGB(128, 170, 255),
		Survivor = Color3.fromRGB(255, 236, 140),
	},
	FillTransparency    = 0.80,
	OutlineTransparency = 0.35,
	RefreshInterval     = 0.5,

	-- Silent aim
	SilentAim       = true,
	AimPart         = "HumanoidRootPart",
	Prediction      = true,  -- compensa o ping com a velocidade do murder
	PredictionScale = 1.0,   -- multiplicador do tempo de ping (não calibrado)
	MaxPredictSpeed = 60,    -- limite de velocidade usada na previsão (studs/s)
	Debug           = false, -- imprime o remote interceptado e os argumentos

	-- Botão de tiro
	ShootButton    = true,
	ButtonSize     = 44,
	ButtonPosition = UDim2.new(1, -90, 1, -190),
	ButtonBgTransp = 0.85,
	ButtonTxtTransp = 0.6,
	ShootDebounce  = 0.25,
}

local env = (getgenv and getgenv()) or _G
if env.KS_MM2_ESP then
	pcall(env.KS_MM2_ESP.Destroy)
end

local localPlayer = Players.LocalPlayer

local function safeParent(inst)
	local parent = (gethui and gethui()) or CoreGui
	if not pcall(function() inst.Parent = parent end) then
		inst.Parent = localPlayer:WaitForChild("PlayerGui")
	end
end

local folder = Instance.new("Folder")
folder.Name = "KS_MM2_ESP"
safeParent(folder)

local entries = {}
local globalConns = {}
local running = true

local function clear(list)
	for i = #list, 1, -1 do
		list[i]:Disconnect()
		list[i] = nil
	end
end

local function findTool(player, name)
	local char = player.Character
	local t = char and char:FindFirstChild(name)
	if t and t:IsA("Tool") then return t end
	local bp = player:FindFirstChildOfClass("Backpack")
	t = bp and bp:FindFirstChild(name)
	if t and t:IsA("Tool") then return t end
	return nil
end

local function roleOf(player)
	if findTool(player, CONFIG.MurderTool) then return "Murder" end
	if findTool(player, CONFIG.SheriffTool) then return "Sheriff" end
	return "Survivor"
end

local function aliveHumanoid(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then return hum, char end
	return nil
end

---------------------------------------------------------------- ESP
local function refresh(player)
	local e = entries[player]
	if not e then return end
	local hum, char = aliveHumanoid(player)
	local hl = e.highlight
	if not hum then
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

	local e = { player = player, highlight = hl, conns = {}, charConns = {}, bpConns = {} }
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

---------------------------------------------------------------- Silent aim
local function getPingSeconds()
	local ok, ms = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(ms) == "number" and ms == ms and ms >= 0 and ms < 2000 then
		return ms / 1000
	end
	return 0
end

local function findMurderer()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and findTool(p, CONFIG.MurderTool) then
			local hum, char = aliveHumanoid(p)
			if hum then return p, char end
		end
	end
	return nil
end

local function murdererAimPoint()
	local _, char = findMurderer()
	if not char then return nil end
	local part = char:FindFirstChild(CONFIG.AimPart) or char:FindFirstChild("HumanoidRootPart")
	if not part then return nil end
	local pos = part.Position
	if CONFIG.Prediction then
		local vel = part.AssemblyLinearVelocity
		local speed = vel.Magnitude
		if speed == speed and speed > CONFIG.MaxPredictSpeed then
			vel = vel.Unit * CONFIG.MaxPredictSpeed
		end
		pos = pos + vel * (getPingSeconds() * CONFIG.PredictionScale)
	end
	if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then return nil end
	return pos
end

-- Retorna a posição do murder se o remote chamado pertence à Gun do local player.
local function resolveAim(remote)
	if not running or not CONFIG.SilentAim then return nil end
	local gun = findTool(localPlayer, CONFIG.SheriffTool)
	if not gun or not remote:IsDescendantOf(gun) then return nil end
	return murdererAimPoint()
end
env.KS_MM2_ResolveAim = resolveAim

local hookOk = false
if not env.KS_MM2_Hooked then
	if hookmetamethod and getnamecallmethod and newcclosure and checkcaller then
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if (method == "InvokeServer" or method == "FireServer") and not checkcaller() then
				local resolver = env.KS_MM2_ResolveAim
				if resolver then
					local okR, aim = pcall(resolver, self)
					if okR and aim then
						local args = table.pack(...)
						for i = 1, args.n do
							if typeof(args[i]) == "Vector3" then
								args[i] = aim
								if CONFIG.Debug then
									warn("[KS] silent aim:", self:GetFullName(), method, "arg", i, aim)
								end
								break
							end
						end
						return old(self, table.unpack(args, 1, args.n))
					end
				end
			end
			return old(self, ...)
		end))
		env.KS_MM2_Hooked = true
		hookOk = true
	else
		warn("[KS] Seu executor não expõe hookmetamethod/newcclosure/checkcaller: silent aim desativado, ESP continua.")
	end
else
	hookOk = true -- hook já instalado numa execução anterior; ele lê o resolvedor novo
end

---------------------------------------------------------------- Botão de tiro
local gui, button
local lastShot = 0

local function shoot()
	if not running or os.clock() - lastShot < CONFIG.ShootDebounce then return end
	local gun = findTool(localPlayer, CONFIG.SheriffTool)
	if not gun or not findMurderer() then return end
	lastShot = os.clock()
	local hum = aliveHumanoid(localPlayer)
	if not hum then return end
	if gun.Parent ~= localPlayer.Character then
		hum:EquipTool(gun)
		task.wait(0.05)
	end
	gun:Activate()
end

if CONFIG.ShootButton then
	gui = Instance.new("ScreenGui")
	gui.Name = "KS_MM2_Shoot"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	safeParent(gui)

	button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(CONFIG.ButtonSize, CONFIG.ButtonSize)
	button.Position = CONFIG.ButtonPosition
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundTransparency = CONFIG.ButtonBgTransp
	button.Text = "◎"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextTransparency = CONFIG.ButtonTxtTransp
	button.TextSize = 22
	button.AutoButtonColor = false
	button.Visible = false
	button.Parent = gui
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

	-- toque curto atira; arrastar move o botão
	local dragging, dragStart, startPos, moved = false, nil, nil, false
	table.insert(globalConns, button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, moved = true, false
			dragStart, startPos = input.Position, button.Position
		end
	end))
	table.insert(globalConns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = input.Position - dragStart
			if d.Magnitude > 8 then moved = true end
			if moved then
				button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end))
	table.insert(globalConns, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = false
			if not moved then task.spawn(shoot) end
		end
	end))
end

---------------------------------------------------------------- Loop e ciclo de vida
table.insert(globalConns, Players.PlayerAdded:Connect(addPlayer))
table.insert(globalConns, Players.PlayerRemoving:Connect(removePlayer))
for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end

task.spawn(function()
	while running do
		task.wait(CONFIG.RefreshInterval)
		for player in pairs(entries) do refresh(player) end
		if button then
			button.Visible = hookOk and findTool(localPlayer, CONFIG.SheriffTool) ~= nil
				and aliveHumanoid(localPlayer) ~= nil
		end
	end
end)

env.KS_MM2_ESP = {
	Destroy = function()
		running = false
		env.KS_MM2_ResolveAim = nil -- o hook continua instalado, mas passa tudo direto
		clear(globalConns)
		for player in pairs(entries) do removePlayer(player) end
		folder:Destroy()
		if gui then gui:Destroy() end
		env.KS_MM2_ESP = nil
	end,
}
