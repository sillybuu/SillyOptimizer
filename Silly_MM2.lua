-- KS NEXUS | MM2 ESP + Gun ESP + Speed 18 + Infinite Jump + Shoot Murder (v4.2)
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CONFIG = {
	MurderTool = "Knife",
	SheriffTool = "Gun",
	DroppedGunName = "GunDrop",

	Colors = {
		Murder   = Color3.fromRGB(255, 128, 128),
		Sheriff  = Color3.fromRGB(128, 170, 255),
		Survivor = Color3.fromRGB(255, 236, 140),
	},
	FillTransparency    = 0.80,
	OutlineTransparency = 0.45,
	RefreshInterval     = 0.5,

	GunEsp           = true,
	GunColor         = Color3.fromRGB(170, 60, 255),
	GunLabelColor    = Color3.fromRGB(215, 150, 255),
	GunFillTransp    = 0.45,
	GunOutlineTransp = 0.25,
	GunLabel         = "ARMA",

	LockWalkSpeed = true,
	WalkSpeed     = 18,
	InfiniteJump  = true,

	SilentAim       = true,
	AimPart         = "HumanoidRootPart",
	PredictionDiv   = 40,
	MaxPredictSpeed = 60,

	ShootButton        = true,
	ButtonSize         = 90,
	ButtonPosition     = UDim2.new(1, -135, 1, -270),
	ButtonBgTransp     = 0.55,
	ButtonStrokeTransp = 0.1,
	ButtonStrokeThick  = 3,
	ShootDebounce      = 0.4,
	EquipTimeout       = 0.6,
	ActivateWait       = 0.5,
	VirtualClick       = true, -- fallback se Activate() não gerar o ShootGun

	Debug = false,
}

local env = (getgenv and getgenv()) or _G
if env.KS_MM2_ESP then
	pcall(env.KS_MM2_ESP.Destroy)
end
env.KS_MM2_Handler = nil
env.KS_MM2_ResolveAim = nil

local localPlayer = Players.LocalPlayer

local function try(name, fn)
	local ok, err = pcall(fn)
	if not ok then warn("[KS] falha em " .. name .. ": " .. tostring(err)) end
	return ok
end

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
local touchConns = {}
local running = true
local gui, button, stroke
local hookInstalled = false

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

---------------------------------------------------------------- Silent aim: definições
local lastShotAt = 0

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
	local part = char:FindFirstChild(CONFIG.AimPart) or char.PrimaryPart
	if not part then return nil end
	local pos = part.Position
	local vel = part.AssemblyLinearVelocity
	local speed = vel.Magnitude
	if speed ~= speed then return nil end
	if speed > CONFIG.MaxPredictSpeed then vel = vel.Unit * CONFIG.MaxPredictSpeed end
	if math.abs(vel.Y) >= 10 then vel = Vector3.new(vel.X, 0, vel.Z) end
	pos = pos + vel / CONFIG.PredictionDiv
	if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then return nil end
	return pos
end

local function onShoot(remote, args)
	if not running then return nil end
	if not findTool(localPlayer, CONFIG.SheriffTool) then return nil end
	lastShotAt = os.clock()
	if CONFIG.Debug then
		local types = {}
		for i = 1, args.n do types[i] = typeof(args[i]) end
		warn("[KS] ShootGun:", remote:GetFullName(), remote.ClassName, "args:", table.concat(types, ", "))
	end
	if not CONFIG.SilentAim or typeof(args[2]) ~= "Vector3" then return nil end
	local aim = murdererAimPoint()
	if not aim then return nil end
	local out = table.pack(table.unpack(args, 1, args.n))
	out[2] = aim
	return out
end

---------------------------------------------------------------- Botão: lógica de tiro
local WHITE = Color3.fromRGB(255, 255, 255)
local GREEN = Color3.fromRGB(120, 255, 140)
local RED   = Color3.fromRGB(255, 110, 110)

local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local lastShot = 0
local shooting = false

local function flash(color)
	if not stroke then return end
	stroke.Color = color
	task.delay(0.35, function()
		if stroke and stroke.Parent then stroke.Color = WHITE end
	end)
end

local function fail(reason)
	warn("[KS] tiro não saiu: " .. reason)
	flash(RED)
end

local function waitShot(since)
	local t = os.clock()
	while lastShotAt < since and os.clock() - t < CONFIG.ActivateWait do task.wait() end
	return lastShotAt >= since
end

local function shoot()
	if not running or shooting or os.clock() - lastShot < CONFIG.ShootDebounce then return end
	local gun = findTool(localPlayer, CONFIG.SheriffTool)
	if not gun then return fail("sem " .. CONFIG.SheriffTool) end
	if not findMurderer() then return fail("murder não encontrado (sem " .. CONFIG.MurderTool .. " visível ou morto)") end
	local hum, char = aliveHumanoid(localPlayer)
	if not hum then return end

	shooting = true
	lastShot = os.clock()

	local ok, err = pcall(function()
		if gun.Parent ~= char then
			hum:EquipTool(gun)
			local t0 = os.clock()
			while gun.Parent ~= char and os.clock() - t0 < CONFIG.EquipTimeout do task.wait() end
			if gun.Parent ~= char then return fail("não consegui equipar a arma") end
		end

		local t1 = os.clock()
		gun:Activate()

		if not hookInstalled then return end -- sem hook não dá para observar o ShootGun
		if waitShot(t1) then return flash(GREEN) end

		if CONFIG.VirtualClick and VIM then
			local vp = Workspace.CurrentCamera.ViewportSize
			local x, y = vp.X / 2, vp.Y / 2
			local t2 = os.clock()
			VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
			task.wait(0.03)
			VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
			if waitShot(t2) then return flash(GREEN) end
		end
		fail("nenhum ShootGun visto após Activate e clique virtual")
	end)
	if not ok then warn("[KS] erro no tiro: " .. tostring(err)) end
	shooting = false
end

---------------------------------------------------------------- 1) ESP sobe primeiro
try("esp jogadores", function()
	table.insert(globalConns, Players.PlayerAdded:Connect(function(p)
		try("addPlayer", function() addPlayer(p) end)
	end))
	table.insert(globalConns, Players.PlayerRemoving:Connect(removePlayer))
	for _, p in ipairs(Players:GetPlayers()) do
		try("addPlayer", function() addPlayer(p) end)
	end
end)

try("loop de refresh", function()
	task.spawn(function()
		while running do
			task.wait(CONFIG.RefreshInterval)
			for player in pairs(entries) do pcall(refresh, player) end
			for inst in pairs(gunEntries) do
				if not inst.Parent then removeGun(inst) end
			end
			if button then
				button.Visible = findTool(localPlayer, CONFIG.SheriffTool) ~= nil
					and aliveHumanoid(localPlayer) ~= nil
			end
		end
	end)
end)

---------------------------------------------------------------- 2) ESP da arma
if CONFIG.GunEsp then
	try("esp arma", function()
		table.insert(globalConns, Workspace.DescendantAdded:Connect(function(d)
			local n = d.Name
			if (n == CONFIG.DroppedGunName or n == CONFIG.SheriffTool) and isDroppedGun(d) then
				try("addGun", function() addGun(d) end)
			end
		end))
		for _, d in ipairs(Workspace:GetDescendants()) do
			local n = d.Name
			if (n == CONFIG.DroppedGunName or n == CONFIG.SheriffTool) and isDroppedGun(d) then
				try("addGun", function() addGun(d) end)
			end
		end
	end)
end

---------------------------------------------------------------- 3) Velocidade
if CONFIG.LockWalkSpeed then
	try("velocidade", function()
		table.insert(globalConns, RunService.Heartbeat:Connect(function()
			local char = localPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and hum.WalkSpeed ~= CONFIG.WalkSpeed then
				hum.WalkSpeed = CONFIG.WalkSpeed
			end
		end))
	end)
end

---------------------------------------------------------------- 4) Infinite jump (só por toques)
if CONFIG.InfiniteJump then
	try("infinite jump", function()
		local freshPress = false
		local touchButton = nil
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
		end

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
		task.spawn(function()
			while running do
				task.wait(CONFIG.RefreshInterval)
				pcall(bindTouchJumpButton)
			end
		end)
	end)
end

---------------------------------------------------------------- 5) Hook do ShootGun
env.KS_MM2_Handler4 = onShoot
try("hook ShootGun", function()
	if env.KS_MM2_Hook4 then
		hookInstalled = true
		return
	end
	if not (hookmetamethod and getnamecallmethod and newcclosure and checkcaller) then
		warn("[KS] executor sem hookmetamethod/newcclosure/checkcaller: silent aim desativado, o resto continua.")
		return
	end
	local old
	old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if method == "InvokeServer" and not checkcaller() then
			local h = env.KS_MM2_Handler4
			if h and typeof(self) == "Instance" and self.Name == "ShootGun" then
				local okH, newArgs = pcall(h, self, table.pack(...))
				if setnamecallmethod then setnamecallmethod(method) end
				if okH and newArgs then
					return old(self, table.unpack(newArgs, 1, newArgs.n))
				end
			end
		end
		return old(self, ...)
	end))
	env.KS_MM2_Hook4 = true
	hookInstalled = true
end)

---------------------------------------------------------------- 6) Botão (fixo, atira ao toque)
if CONFIG.ShootButton then
	try("botão", function()
		gui = Instance.new("ScreenGui")
		gui.Name = "KS_MM2_Shoot"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 100
		safeParent(gui)

		button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(CONFIG.ButtonSize, CONFIG.ButtonSize)
		button.Position = CONFIG.ButtonPosition
		button.BackgroundColor3 = WHITE
		button.BackgroundTransparency = CONFIG.ButtonBgTransp
		button.Text = ""
		button.AutoButtonColor = false
		button.Active = true
		button.Visible = false
		button.Parent = gui
		Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

		stroke = Instance.new("UIStroke")
		stroke.Color = WHITE
		stroke.Thickness = CONFIG.ButtonStrokeThick
		stroke.Transparency = CONFIG.ButtonStrokeTransp
		stroke.Parent = button

		table.insert(globalConns, button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1 then
				task.spawn(shoot)
			end
		end))
	end)
end

env.KS_MM2_ESP = {
	Destroy = function()
		running = false
		env.KS_MM2_Handler4 = nil
		clear(globalConns)
		clear(touchConns)
		for player in pairs(entries) do removePlayer(player) end
		for inst in pairs(gunEntries) do removeGun(inst) end
		folder:Destroy()
		if gui then gui:Destroy() end
		env.KS_MM2_ESP = nil
	end,
}

local n = 0
for _ in pairs(entries) do n += 1 end
warn("[KS] v4.2 carregada. Jogadores no ESP: " .. n .. " | hook ShootGun: " .. tostring(hookInstalled))
