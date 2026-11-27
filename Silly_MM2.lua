-- KS NEXUS | MM2 Role ESP + Gun ESP + Sheriff Silent Aim (v2)
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local CONFIG = {
	MurderTool = "Knife",
	SheriffTool = "Gun",
	DroppedGunName = "GunDrop", -- nome da arma dropada (não verificado na build atual)

	Colors = {
		Murder   = Color3.fromRGB(255, 128, 128),
		Sheriff  = Color3.fromRGB(128, 170, 255),
		Survivor = Color3.fromRGB(255, 236, 140),
	},
	FillTransparency    = 0.80,
	OutlineTransparency = 0.35,
	RefreshInterval     = 0.5,

	-- ESP da arma dropada
	GunEsp          = true,
	GunColor        = Color3.fromRGB(170, 60, 255),  -- violeta forte
	GunLabelColor   = Color3.fromRGB(215, 150, 255),
	GunFillTransp   = 0.45,
	GunOutlineTransp = 0.05,
	GunLabel        = "ARMA",

	-- Silent aim
	SilentAim       = true,
	AimPart         = "HumanoidRootPart",
	Prediction      = true,
	PredictionScale = 1.0,   -- não calibrado
	MaxPredictSpeed = 60,
	Debug           = false, -- true: imprime remotes da arma e o argumento trocado

	-- Botão de tiro
	ShootButton     = true,
	ButtonSize      = 90,
	ButtonPosition  = UDim2.new(1, -135, 1, -270),
	ButtonBgTransp  = 0.82,
	ButtonTxtTransp = 0.45,
	ShootDebounce   = 0.25,
}

local HOOK_VERSION = 2

local env = (getgenv and getgenv()) or _G
if env.KS_MM2_ESP then
	pcall(env.KS_MM2_ESP.Destroy)
end
env.KS_MM2_ResolveAim = nil -- deixa inerte o hook da versão 1, se existir

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
local gunEntries = {}
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

---------------------------------------------------------------- ESP de jogadores
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

---------------------------------------------------------------- ESP da arma dropada
local function isUnderCharacter(inst)
	local a = inst.Parent
	while a and a ~= Workspace do
		if a:IsA("Model") and Players:GetPlayerFromCharacter(a) then return true end
		a = a.Parent
	end
	return false
end

local function isDroppedGun(inst)
	if not (inst:IsA("BasePart") or inst:IsA("Model") or inst:IsA("Tool")) then return false end
	local byName = inst.Name == CONFIG.DroppedGunName
	local looseTool = inst:IsA("Tool") and inst.Name == CONFIG.SheriffTool and inst.Parent == Workspace
	if not (byName or looseTool) then return false end
	return not isUnderCharacter(inst)
end

local function gunPart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Tool") then
		return inst:FindFirstChild("Handle") or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function removeGun(inst)
	local e = gunEntries[inst]
	if not e then return end
	gunEntries[inst] = nil
	clear(e.conns)
	e.highlight:Destroy()
	e.billboard:Destroy()
end

local function hasTrackedAncestor(inst)
	local a = inst.Parent
	while a and a ~= Workspace do
		if gunEntries[a] then return true end
		a = a.Parent
	end
	return false
end

local function addGun(inst)
	if gunEntries[inst] or hasTrackedAncestor(inst) then return end

	local hl = Instance.new("Highlight")
	hl.Name = "Gun"
	hl.Adornee = inst
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillColor = CONFIG.GunColor
	hl.OutlineColor = CONFIG.GunColor
	hl.FillTransparency = CONFIG.GunFillTransp
	hl.OutlineTransparency = CONFIG.GunOutlineTransp
	hl.Parent = folder

	local bb = Instance.new("BillboardGui")
	bb.Name = "GunLabel"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(100, 28)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = math.huge
	bb.Enabled = false
	bb.Parent = folder

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = CONFIG.GunLabel
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = CONFIG.GunLabelColor
	label.TextStrokeColor3 = Color3.fromRGB(40, 0, 70)
	label.TextStrokeTransparency = 0.2
	label.Parent = bb

	local e = { highlight = hl, billboard = bb, conns = {} }
	gunEntries[inst] = e

	table.insert(e.conns, inst.AncestryChanged:Connect(function()
		if not inst:IsDescendantOf(Workspace) or isUnderCharacter(inst) then
			removeGun(inst)
		end
	end))

	if CONFIG.Debug then warn("[KS] arma dropada detectada:", inst:GetFullName()) end

	task.spawn(function()
		local t0 = os.clock()
		local part
		repeat
			part = gunPart(inst)
			if not part then task.wait(0.1) end
		until part or os.clock() - t0 > 3 or gunEntries[inst] ~= e
		if part and gunEntries[inst] == e then
			bb.Adornee = part
			bb.Enabled = true
		end
	end)
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

-- Entre vários Vector3, escolhe o mais distante do seu personagem (a origem do tiro fica perto de você).
local function pickAimIndex(args)
	local myChar = localPlayer.Character
	local root = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local bestIdx, bestDist
	for i = 1, args.n do
		if typeof(args[i]) == "Vector3" then
			local d = root and (args[i] - root.Position).Magnitude or 0
			if not bestIdx or d > bestDist then bestIdx, bestDist = i, d end
		end
	end
	return bestIdx
end

-- Recebe o remote e os argumentos empacotados; devolve os argumentos novos ou nil (= não mexe).
local function handler(remote, args)
	if not running or not CONFIG.SilentAim then return nil end
	if typeof(remote) ~= "Instance" then return nil end
	local gun = findTool(localPlayer, CONFIG.SheriffTool)
	if not gun or not remote:IsDescendantOf(gun) then return nil end

	local idx = pickAimIndex(args)
	if CONFIG.Debug then
		local types = {}
		for i = 1, args.n do types[i] = typeof(args[i]) end
		warn("[KS] remote da arma:", remote:GetFullName(), "args:", table.concat(types, ", "),
			"vector escolhido:", idx)
	end
	if not idx then return nil end

	local aim = murdererAimPoint()
	if not aim then return nil end

	local out = table.pack(table.unpack(args, 1, args.n))
	out[idx] = aim
	return out
end
env.KS_MM2_Handler = handler

local hookOk = false
if env.KS_MM2_HookVersion == HOOK_VERSION then
	hookOk = true -- hook v2 já instalado; ele lê o handler novo
elseif hookmetamethod and getnamecallmethod and newcclosure and checkcaller then
	local old
	old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if method == "InvokeServer" or method == "FireServer" then
			local h = env.KS_MM2_Handler
			if h and not checkcaller() then
				local okH, newArgs = pcall(h, self, table.pack(...))
				if okH and newArgs then
					return old(self, table.unpack(newArgs, 1, newArgs.n))
				end
			end
		end
		return old(self, ...)
	end))
	env.KS_MM2_HookVersion = HOOK_VERSION
	hookOk = true
else
	warn("[KS] Seu executor não expõe hookmetamethod/newcclosure/checkcaller: silent aim desativado, ESP continua.")
end

---------------------------------------------------------------- Botão de tiro
local gui, button
local lastShot = 0

local function shoot()
	if not running or os.clock() - lastShot < CONFIG.ShootDebounce then return end
	local gun = findTool(localPlayer, CONFIG.SheriffTool)
	if not gun or not findMurderer() then return end
	local hum, char = aliveHumanoid(localPlayer)
	if not hum then return end
	lastShot = os.clock()
	if gun.Parent ~= char then
		hum:EquipTool(gun)
		local t0 = os.clock()
		while gun.Parent ~= char and os.clock() - t0 < 0.4 do task.wait() end
		if gun.Parent ~= char then return end
	end
	gun:Activate()
end

if CONFIG.ShootButton then
	gui = Instance.new("ScreenGui")
	gui.Name = "KS_MM2_Shoot"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	safeParent(gui)

	button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(CONFIG.ButtonSize, CONFIG.ButtonSize)
	button.Position = CONFIG.ButtonPosition
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundTransparency = CONFIG.ButtonBgTransp
	button.Text = "◎"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextTransparency = CONFIG.ButtonTxtTransp
	button.TextSize = math.floor(CONFIG.ButtonSize * 0.5)
	button.AutoButtonColor = false
	button.Active = true
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
			if d.Magnitude > 10 then moved = true end
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

if CONFIG.GunEsp then
	table.insert(globalConns, Workspace.DescendantAdded:Connect(function(d)
		local n = d.Name
		if (n == CONFIG.DroppedGunName or n == CONFIG.SheriffTool) and isDroppedGun(d) then
			addGun(d)
		end
	end))
	for _, d in ipairs(Workspace:GetDescendants()) do
		local n = d.Name
		if (n == CONFIG.DroppedGunName or n == CONFIG.SheriffTool) and isDroppedGun(d) then
			addGun(d)
		end
	end
end

task.spawn(function()
	while running do
		task.wait(CONFIG.RefreshInterval)
		for player in pairs(entries) do refresh(player) end
		for inst in pairs(gunEntries) do
			if not inst.Parent then removeGun(inst) end
		end
		if button then
			button.Visible = hookOk and findTool(localPlayer, CONFIG.SheriffTool) ~= nil
				and aliveHumanoid(localPlayer) ~= nil
		end
	end
end)

env.KS_MM2_ESP = {
	Destroy = function()
		running = false
		env.KS_MM2_Handler = nil -- o hook continua instalado, mas repassa tudo sem alterar
		clear(globalConns)
		for player in pairs(entries) do removePlayer(player) end
		for inst in pairs(gunEntries) do removeGun(inst) end
		folder:Destroy()
		if gui then gui:Destroy() end
		env.KS_MM2_ESP = nil
	end,
}
