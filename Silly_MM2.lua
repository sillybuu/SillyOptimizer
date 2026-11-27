-- Silly | MM2 Role ESP + Gun ESP + Speed 20 + Infinite Jump (taps) (v3)
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
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
	OutlineTransparency = 0.45,
	RefreshInterval     = 0.5,

	-- ESP da arma dropada
	GunEsp           = true,
	GunColor         = Color3.fromRGB(170, 60, 255),
	GunLabelColor    = Color3.fromRGB(215, 150, 255),
	GunFillTransp    = 0.45,
	GunOutlineTransp = 0.25,
	GunLabel         = "ARMA",

	-- Movimento
	LockWalkSpeed = true,
	WalkSpeed     = 20,
	InfiniteJump  = true, -- só funciona com toques separados; segurar não repete

	Debug = false,
}

local env = (getgenv and getgenv()) or _G
if env.KS_MM2_ESP then
	pcall(env.KS_MM2_ESP.Destroy)
end
-- deixa inertes os hooks das versões antigas, se existirem
env.KS_MM2_Handler = nil
env.KS_MM2_ResolveAim = nil

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

---------------------------------------------------------------- Velocidade travada
if CONFIG.LockWalkSpeed then
	table.insert(globalConns, RunService.Heartbeat:Connect(function()
		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and hum.WalkSpeed ~= CONFIG.WalkSpeed then
			hum.WalkSpeed = CONFIG.WalkSpeed
		end
	end))
end

---------------------------------------------------------------- Infinite jump (só por toques)
-- "freshPress" vira true a cada novo toque/pressão e é consumido pelo primeiro JumpRequest.
-- Segurar o botão gera JumpRequests extras, mas sem nova pressão eles são ignorados.
local freshPress = false
local touchButton, touchConns = nil, {}

local function markPress() freshPress = true end

local function bindTouchJumpButton()
	if not UserInputService.TouchEnabled then return end
	if touchButton and touchButton.Parent then return end
	clear(touchConns)
	touchButton = nil
	local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
	local touchGui = pg and pg:FindFirstChild("TouchGui")
	local btn = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if not btn then return end
	touchButton = btn
	table.insert(touchConns, btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			markPress()
		end
	end))
	if CONFIG.Debug then warn("[KS] botão de pulo do celular encontrado:", btn:GetFullName()) end
end

if CONFIG.InfiniteJump then
	table.insert(globalConns, UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			markPress()
		end
	end))

	table.insert(globalConns, UserInputService.JumpRequest:Connect(function()
		if not running then return end
		local wasFresh = freshPress
		freshPress = false
		if not wasFresh then return end
		local hum = aliveHumanoid(localPlayer)
		if not hum then return end
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end))

	bindTouchJumpButton()
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
		if CONFIG.InfiniteJump then bindTouchJumpButton() end
	end
end)

env.KS_MM2_ESP = {
	Destroy = function()
		running = false
		clear(globalConns)
		clear(touchConns)
		for player in pairs(entries) do removePlayer(player) end
		for inst in pairs(gunEntries) do removeGun(inst) end
		folder:Destroy()
		env.KS_MM2_ESP = nil
	end,
}
