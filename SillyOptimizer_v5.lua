--[[
	Silly Optimizer  ·  v5.0
	FPS booster para Roblox (Luau) — celular e PC

	Como usar
	  • Executor: cole e execute.
	  • Roblox Studio: LocalScript em StarterPlayer > StarterPlayerScripts.
	  • Atalho padrão: RightShift (dá para trocar em Configurações).
	  • Botão flutuante: toque para abrir/fechar; arraste para mover (ele gruda na borda).

	Abas
	  Presets        um toque e pronto: Soft, Medium, Extreme e Potato
	  Ajustes        cada otimização separada, com estado bem claro e busca
	  Farm           anti-AFK, reconectar, parar 3D, tela preta, limitar FPS...
	  HUD            FPS, ping, servidor, memória etc. num painel na tela
	  Configurações  lembrar escolhas, atalho, animações e compatibilidade

	Tudo é local (só no seu aparelho). O valor original de cada propriedade é
	guardado e devolvido quando você desliga a opção. Três recursos dependem de
	executor e ficam marcados como indisponíveis no Studio:
	limitar FPS (setfpscap), lembrar escolhas (writefile) e interface protegida (gethui).
]]

local VERSION = "5.0"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local LocalizationService = game:GetService("LocalizationService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- reexecução: desliga a instância anterior (devolve tudo ao normal) antes de começar
do
	local prev = _G.__SillyOptimizer
	if type(prev) == "table" and type(prev.Destroy) == "function" then
		pcall(prev.Destroy)
	end
end

local Destroyed = false
local Connections = {}
local function track(conn)
	Connections[#Connections + 1] = conn
	return conn
end

--------------------------------------------------------------------------
-- AMBIENTE (funções de executor são opcionais)
--------------------------------------------------------------------------
local function asFn(f)
	return type(f) == "function" and f or nil
end

local Env = {
	setfpscap = asFn(setfpscap),
	getfpscap = asFn(getfpscap),
	writefile = asFn(writefile),
	readfile = asFn(readfile),
	isfile = asFn(isfile),
	gethui = asFn(gethui),
	studio = RunService:IsStudio(),
	touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
}
Env.canSave = Env.writefile ~= nil and Env.readfile ~= nil and Env.isfile ~= nil
do
	local idf = asFn(identifyexecutor) or asFn(getexecutorname)
	if idf then
		local ok, name = pcall(idf)
		if ok and type(name) == "string" and name ~= "" then
			Env.executor = name
		end
	end
end

--------------------------------------------------------------------------
-- TEMA  (fundo preto estilo Discord + pastéis: salmão, pêssego, amarelo queimado, rosa)
--------------------------------------------------------------------------
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local C = {
	Bg = rgb(15, 16, 18), -- janela
	Side = rgb(20, 21, 24), -- menu lateral
	Surface = rgb(28, 29, 33), -- cartões
	Surface2 = rgb(40, 42, 47), -- controles / hover
	Stroke = rgb(44, 46, 52),
	Text = rgb(242, 243, 245),
	Sub = rgb(178, 182, 190),
	Dim = rgb(120, 124, 134),
	Off = rgb(62, 64, 72), -- trilho do switch desligado
	Ink = rgb(34, 25, 23), -- texto sobre cor pastel
	White = rgb(255, 255, 255),
	Black = rgb(0, 0, 0),

	Salmon = rgb(255, 166, 154),
	Peach = rgb(255, 190, 148),
	Gold = rgb(240, 198, 116),
	Pink = rgb(255, 178, 210),
	Apricot = rgb(246, 210, 182),

	Good = rgb(156, 226, 180),
	Warn = rgb(255, 150, 128),
}

local CSK, NSK = ColorSequenceKeypoint.new, NumberSequenceKeypoint.new
local EASE, DIR = Enum.EasingStyle, Enum.EasingDirection
local BRAND = ColorSequence.new({ CSK(0, C.Gold), CSK(0.5, C.Salmon), CSK(1, C.Pink) })
local PASTELS = { C.Salmon, C.Peach, C.Gold, C.Pink, C.Apricot }

local function pickFont(primary, fallback)
	local ok, f = pcall(function()
		return Enum.Font[primary]
	end)
	if ok and f then
		return f
	end
	return Enum.Font[fallback]
end

local F = {
	Heavy = pickFont("BuilderSansExtraBold", "GothamBlack"),
	Bold = pickFont("BuilderSansBold", "GothamBold"),
	Semi = pickFont("BuilderSansMedium", "GothamMedium"),
	Reg = pickFont("BuilderSans", "Gotham"),
}

-- preferências (salvas em Configurações quando o executor permite)
local Prefs = {
	remember = false,
	openOnStart = true,
	reduceMotion = false,
	keybind = "RightShift",
	hudVisible = true,
	hudLayout = 1, -- 1 = lista, 2 = linha
	hudSize = 2, -- 1 pequeno, 2 médio, 3 grande
}

--------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------
local function make(class, props, children)
	local inst = Instance.new(class)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(r)
	return make("UICorner", { CornerRadius = r == "full" and UDim.new(0.5, 0) or UDim.new(0, r) })
end

local function stroke(color, thickness, transparency)
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function pad(l, t, r, b)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r or l),
		PaddingBottom = UDim.new(0, b or t),
	})
end

local function list(dir, gap, halign, valign)
	return make("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.Font = props.Font or F.Reg
	props.TextColor3 = props.TextColor3 or C.Text
	props.TextSize = props.TextSize or 14
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function tween(inst, t, props, style, dir)
	if Prefs.reduceMotion then
		t = 0
	end
	if t <= 0 then
		for k, v in pairs(props) do
			inst[k] = v
		end
		return nil
	end
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or EASE.Quint, dir or DIR.Out), props)
	tw:Play()
	return tw
end

local function isPress(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

local function fmtNum(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return out
end

local function formatDuration(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
end

-- brilho de 4 pontas desenhado com frames (nítido em qualquer tela, sem emoji)
local SPARKLE_FADE = NumberSequence.new({ NSK(0, 1), NSK(0.5, 0), NSK(1, 1) })
local function sparkleShape(parent, size, color)
	local holder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local thick = math.max(2, math.floor(size * 0.16 + 0.5))
	for _, rot in ipairs({ 0, 90 }) do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, thick, 1, 0),
			Rotation = rot,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = holder,
		}, { corner("full"), make("UIGradient", { Rotation = 90, Transparency = SPARKLE_FADE }) })
	end
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(thick + 2, thick + 2),
		Rotation = 45,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = holder,
	}, { corner(2) })
	return holder
end

-- brilho que aparece, gira, sobe um pouco e some
local function twinkle(parent, pos, opts)
	if Prefs.reduceMotion or Destroyed or not parent.Parent then
		return
	end
	opts = opts or {}
	local life = opts.life or (0.7 + math.random() * 0.6)
	local s = sparkleShape(parent, opts.size or math.random(8, 18), opts.color or PASTELS[math.random(#PASTELS)])
	s.Position = pos
	local sc = make("UIScale", { Scale = 0, Parent = s })
	TweenService:Create(sc, TweenInfo.new(life * 0.45, EASE.Back, DIR.Out), { Scale = 1 }):Play()
	TweenService:Create(s, TweenInfo.new(life, EASE.Linear), {
		Rotation = 90,
		Position = pos - UDim2.fromOffset(0, opts.rise or 14),
	}):Play()
	task.delay(life * 0.5, function()
		if s.Parent then
			TweenService:Create(sc, TweenInfo.new(life * 0.5, EASE.Quad, DIR.In), { Scale = 0 }):Play()
		end
	end)
	task.delay(life + 0.05, function()
		s:Destroy()
	end)
end

local function burst(parent, center, count, spread)
	for _ = 1, count do
		local a = math.random() * math.pi * 2
		local r = (spread or 40) * (0.4 + math.random() * 0.6)
		twinkle(parent, center + UDim2.fromOffset(math.cos(a) * r, math.sin(a) * r), {
			size = math.random(8, 16),
			life = 0.6 + math.random() * 0.4,
		})
	end
end

local function brandTile(parent, size, radius, markSize)
	local tile = make("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner(radius) })
	local grad = make("UIGradient", { Rotation = 45, Color = BRAND, Parent = tile })
	local mark = sparkleShape(tile, markSize, C.Ink)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	return tile, mark, grad
end

--------------------------------------------------------------------------
-- GUI RAIZ
--------------------------------------------------------------------------
local function mount(g)
	g:SetAttribute("SillyOptimizer", true)
	if Env.gethui then
		local ok, ui = pcall(Env.gethui)
		if ok and typeof(ui) == "Instance" and pcall(function()
			g.Parent = ui
		end) then
			return
		end
	end
	if not Env.studio and pcall(function()
		g.Parent = game:GetService("CoreGui")
	end) and g.Parent then
		return
	end
	g.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Gui = make("ScreenGui", {
	Name = "SillyOptimizer",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 1000,
})
mount(Gui)

local TopInset = 58
pcall(function()
	TopInset = math.max(36, (GuiService:GetGuiInset()).Y)
end)

local function viewportSize()
	local s = Gui.AbsoluteSize
	if s.X > 10 and s.Y > 10 then
		return s
	end
	local cam = Workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

-- mantém um objeto (filho direto do Gui) dentro da tela
local function clampInside(obj, keep)
	local gs = viewportSize()
	local rel = obj.AbsolutePosition - Gui.AbsolutePosition
	local size = obj.AbsoluteSize
	local minX, maxX, minY, maxY
	if keep then
		minX, maxX = keep - size.X, gs.X - keep
		minY, maxY = 0, gs.Y - keep
	else
		minX, maxX = 8, gs.X - size.X - 8
		minY, maxY = 8, gs.Y - size.Y - 8
	end
	local nx = math.clamp(rel.X, minX, math.max(minX, maxX))
	local ny = math.clamp(rel.Y, minY, math.max(minY, maxY))
	local dx, dy = nx - rel.X, ny - rel.Y
	if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
		tween(obj, 0.35, { Position = obj.Position + UDim2.fromOffset(dx, dy) })
	end
end

-- arrastar que funciona com mouse e toque (sem vazar conexões)
local function makeDraggable(handle, target, onRelease)
	local dragInput, startPos, startInput, moved
	handle.InputBegan:Connect(function(input)
		if dragInput or not isPress(input) then
			return
		end
		dragInput, moved = input, false
		startInput, startPos = input.Position, target.Position
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if not dragInput then
			return
		end
		local isTouch = dragInput.UserInputType == Enum.UserInputType.Touch
		if (isTouch and input == dragInput) or (not isTouch and input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = input.Position - startInput
			if not moved and delta.Magnitude > 6 then
				moved = true
			end
			if moved then
				target.Position = startPos + UDim2.fromOffset(delta.X, delta.Y)
			end
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if not dragInput then
			return
		end
		local same
		if dragInput.UserInputType == Enum.UserInputType.Touch then
			same = input == dragInput
		else
			same = input.UserInputType == dragInput.UserInputType
		end
		if same then
			dragInput = nil
			if onRelease then
				onRelease(moved)
			end
		end
	end))
end

local destroyAll -- definido no fim
-- registro provisório: se o script for executado de novo durante o carregamento,
-- esta instância para e se limpa no fim do carregamento
_G.__SillyOptimizer = {
	Destroy = function()
		if destroyAll then
			destroyAll()
		else
			Destroyed = true
		end
	end,
}

--------------------------------------------------------------------------
-- TELA DE CARREGAMENTO
--------------------------------------------------------------------------
local Splash = {}
do
	local overlay = make("Frame", {
		Name = "Splash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = Gui,
	})
	local card = make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 270),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = overlay,
	}, { corner(26), stroke(C.Stroke, 1, 0) })
	local cardScale = make("UIScale", { Scale = 0.9, Parent = card })
	make("Frame", {
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = C.Salmon,
		BorderSizePixel = 0,
		Parent = card,
	}, { make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.82, 1) }) })

	local sparkArea = make("Frame", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local logo, logoMark, logoGrad = brandTile(card, 76, 22, 42)
	logo.AnchorPoint = Vector2.new(0.5, 0)
	logo.Position = UDim2.new(0.5, 0, 0, 38)
	local logoScale = make("UIScale", { Scale = 0.5, Parent = logo })

	text({
		Text = "Silly Optimizer",
		Font = F.Heavy,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.new(1, -40, 0, 26),
		Parent = card,
	})
	local status = text({
		Text = "Preparando…",
		TextSize = 13,
		TextColor3 = C.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 162),
		Size = UDim2.new(1, -40, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	local track_ = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.new(1, -64, 0, 6),
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Parent = card,
	}, { corner("full") })
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = track_,
	}, { corner("full"), make("UIGradient", { Color = BRAND }) })
	local shine = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Parent = fill,
	}, { corner("full") })
	local shineGrad = make("UIGradient", {
		Transparency = NumberSequence.new({ NSK(0, 1), NSK(0.4, 1), NSK(0.5, 0.45), NSK(0.6, 1), NSK(1, 1) }),
		Offset = Vector2.new(-1, 0),
		Parent = shine,
	})
	local pct = text({
		Text = "0%",
		Font = F.Bold,
		TextSize = 11,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 214),
		Size = UDim2.fromOffset(60, 14),
		Parent = card,
	})
	text({
		Text = "v" .. VERSION,
		Font = F.Bold,
		TextSize = 11,
		TextColor3 = C.Dim,
		Position = UDim2.fromOffset(32, 214),
		Size = UDim2.fromOffset(60, 14),
		Parent = card,
	})

	local alive = true
	local loops = {}

	function Splash.start()
		TweenService:Create(overlay, TweenInfo.new(0.35), { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(card, TweenInfo.new(0.35), { GroupTransparency = 0 }):Play()
		TweenService:Create(cardScale, TweenInfo.new(0.5, EASE.Back), { Scale = 1 }):Play()
		TweenService:Create(logoScale, TweenInfo.new(0.7, EASE.Back), { Scale = 1 }):Play()
		local spin = TweenService:Create(logoGrad, TweenInfo.new(2.4, EASE.Linear, DIR.InOut, -1), { Rotation = 405 })
		spin:Play()
		local sweep = TweenService:Create(shineGrad, TweenInfo.new(1.1, EASE.Sine, DIR.InOut, -1), { Offset = Vector2.new(1, 0) })
		sweep:Play()
		local breathe = TweenService:Create(logoMark, TweenInfo.new(1.2, EASE.Sine, DIR.InOut, -1, true), { Rotation = 45 })
		breathe:Play()
		loops = { spin, sweep, breathe }
		task.spawn(function()
			while alive and not Destroyed do
				twinkle(sparkArea, UDim2.fromOffset(math.random(30, 270), math.random(24, 140)), {})
				task.wait(0.08)
			end
		end)
	end

	function Splash.step(msg, p)
		if Destroyed then
			return
		end
		status.Text = msg
		TweenService:Create(fill, TweenInfo.new(0.35, EASE.Quad), { Size = UDim2.fromScale(p, 1) }):Play()
		pct.Text = math.floor(p * 100 + 0.5) .. "%"
		task.wait(0.18)
	end

	function Splash.finish()
		if Destroyed then
			return
		end
		Splash.step("Tudo pronto", 1)
		burst(card, UDim2.fromOffset(150, 76), 10, 60)
		task.wait(0.45)
		alive = false
		TweenService:Create(cardScale, TweenInfo.new(0.35, EASE.Quint), { Scale = 1.06 }):Play()
		TweenService:Create(card, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
		TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.delay(0.45, function()
			for _, tw in ipairs(loops) do
				tw:Cancel()
			end
			overlay:Destroy()
		end)
	end
end

Splash.start()
Splash.step("Carregando tema e fontes", 0.12)

--------------------------------------------------------------------------
-- MOTOR DE OTIMIZAÇÃO
-- Cada opção guarda o valor original de cada propriedade alterada e devolve
-- ao desligar. Regras por classe também pegam instâncias novas.
--------------------------------------------------------------------------
local QualityChoice = 1
local FpsCap, FarmMinutes, JumpEvery = 30, 60, 60
local FarmSince
local BlackGui
local Hooks = {}

local function getProp(inst, prop)
	return inst[prop]
end
local function setProp(inst, prop, v)
	inst[prop] = v
end
local function same(a, b)
	if type(a) == "number" and type(b) == "number" then
		-- propriedades são float32: tolera arredondamento (ex.: 9e9)
		return math.abs(a - b) <= math.max(1e-3, math.abs(b) * 1e-4)
	end
	return a == b
end

local Active, Saved, Stat, Scanning, Watchers = {}, {}, {}, {}, {}
local ById, ClassOptions, FarmIds = {}, {}, {}

local OPTIONS
do -- definição das opções em escopo próprio (economiza variáveis locais)
local function isTerrain(inst)
	return inst:IsA("Terrain")
end
local function inCharacter(inst)
	local model = inst:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function lightingT()
	return Lighting
end
local function terrainT()
	return Workspace:FindFirstChildOfClass("Terrain")
end
local function soundT()
	return SoundService
end
local function renderT()
	return settings().Rendering
end

-- animações de outros jogadores
local animConns, animChars = {}, 0
local function animOff()
	for _, c in ipairs(animConns) do
		c:Disconnect()
	end
	table.clear(animConns)
	animChars = 0
end
local function animHookChar(char)
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum or not Active.anim_others then
			return
		end
		local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 10)
		if not animator or not Active.anim_others then
			return
		end
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function()
				t:Stop(0)
			end)
		end
		animChars += 1
		table.insert(animConns, animator.AnimationPlayed:Connect(function(t)
			pcall(function()
				t:Stop(0)
			end)
		end))
	end)
end
local function animHookPlayer(plr)
	if plr == LocalPlayer then
		return
	end
	if plr.Character then
		animHookChar(plr.Character)
	end
	table.insert(animConns, plr.CharacterAdded:Connect(animHookChar))
end
local function animOn()
	for _, plr in ipairs(Players:GetPlayers()) do
		animHookPlayer(plr)
	end
	table.insert(animConns, Players.PlayerAdded:Connect(animHookPlayer))
	return true
end

local function qualityFmt(v)
	return "Nível " .. v
end

OPTIONS = {
	-- Iluminação
	{ id = "shadows", cat = "ILUMINAÇÃO", title = "Remover sombras globais",
	  desc = "Desliga as sombras do sol em todo o mapa",
	  targets = { { lightingT, { GlobalShadows = false } } } },
	{ id = "fog", cat = "ILUMINAÇÃO", title = "Remover neblina",
	  desc = "Deixa a distância limpa, sem névoa",
	  targets = { { lightingT, { FogEnd = 9e9 } } } },
	{ id = "reflections", cat = "ILUMINAÇÃO", title = "Remover reflexo do céu",
	  desc = "Zera o brilho do ambiente refletido nas superfícies",
	  targets = { { lightingT, { EnvironmentSpecularScale = 0 } } } },
	{ id = "lights", cat = "ILUMINAÇÃO", title = "Desligar luzes dinâmicas",
	  desc = "Point, Spot e Surface lights", unit = { "luz", "luzes" },
	  classes = { { "Light", { Enabled = false } } } },
	{ id = "atmosphere", cat = "ILUMINAÇÃO", title = "Limpar atmosfera",
	  desc = "Zera densidade, névoa e brilho da atmosfera",
	  classes = { { "Atmosphere", { Density = 0, Haze = 0, Glare = 0 } } } },

	-- Efeitos
	{ id = "post_fx", cat = "EFEITOS", title = "Desligar pós-processamento",
	  desc = "Bloom, blur, raios de sol, cor e profundidade", unit = { "efeito", "efeitos" },
	  classes = { { "PostEffect", { Enabled = false } } } },
	{ id = "particles", cat = "EFEITOS", title = "Desligar partículas",
	  desc = "Emissores de partícula, trilhas e feixes", unit = { "efeito", "efeitos" },
	  classes = {
		  { "ParticleEmitter", { Enabled = false } },
		  { "Trail", { Enabled = false } },
		  { "Beam", { Enabled = false } },
	  } },
	{ id = "fire_smoke", cat = "EFEITOS", title = "Desligar fogo e fumaça",
	  desc = "Fire, Smoke, Sparkles, explosões e escudos", unit = { "efeito", "efeitos" },
	  classes = {
		  { "Fire", { Enabled = false } },
		  { "Smoke", { Enabled = false } },
		  { "Sparkles", { Enabled = false } },
		  { "Explosion", { Visible = false } },
		  { "ForceField", { Visible = false } },
	  } },
	{ id = "sky", cat = "EFEITOS", title = "Esconder sol, lua e estrelas",
	  desc = "Remove os corpos celestes do céu",
	  classes = { { "Sky", { StarCount = 0, CelestialBodiesShown = false } } } },

	-- Água e terreno
	{ id = "water_waves", cat = "ÁGUA E TERRENO", title = "Parar ondas da água",
	  desc = "Zera tamanho e velocidade das ondas",
	  targets = { { terrainT, { WaterWaveSize = 0, WaterWaveSpeed = 0 } } } },
	{ id = "water_reflect", cat = "ÁGUA E TERRENO", title = "Remover reflexo da água",
	  desc = "A água para de refletir o mundo",
	  targets = { { terrainT, { WaterReflectance = 0 } } } },
	{ id = "grass", cat = "ÁGUA E TERRENO", title = "Remover grama do terreno",
	  desc = "Tira a grama animada e detalhes do chão",
	  targets = { { terrainT, { Decoration = false } } } },

	-- Objetos
	{ id = "part_shadows", cat = "OBJETOS", title = "Tirar sombra dos objetos",
	  desc = "Cada parte para de projetar sombra",
	  classes = { { "BasePart", { CastShadow = false }, skip = isTerrain } } },
	{ id = "materials", cat = "OBJETOS", title = "Materiais lisos",
	  desc = "Troca todos os materiais por plástico liso",
	  classes = { { "BasePart", { Material = Enum.Material.SmoothPlastic }, skip = isTerrain } } },
	{ id = "textures", cat = "OBJETOS", title = "Esconder texturas e decals",
	  desc = "Preserva o rosto dos personagens", unit = { "textura", "texturas" },
	  classes = { { "Decal", { Transparency = 1 }, skip = inCharacter } } },
	{ id = "mesh_fidelity", cat = "OBJETOS", title = "Simplificar malhas",
	  desc = "MeshParts em modo de desempenho", unit = { "malha", "malhas" },
	  classes = { { "MeshPart", { RenderFidelity = Enum.RenderFidelity.Performance } } } },
	{ id = "reflectance", cat = "OBJETOS", title = "Tirar brilho dos objetos",
	  desc = "Zera o reflexo de todas as partes",
	  classes = { { "BasePart", { Reflectance = 0 }, skip = isTerrain } } },

	-- Sistema
	{ id = "quality", cat = "SISTEMA", title = "Reduzir qualidade gráfica",
	  desc = "Nível 1 é o mais leve. O preset escolhe o nível",
	  blockedText = "Sem permissão neste ambiente",
	  choices = { 1, 3, 5, 7 }, choiceIndex = 1, fmt = qualityFmt,
	  targets = { { renderT, function()
		  return { QualityLevel = Enum.QualityLevel["Level" .. string.format("%02d", QualityChoice)] }
	  end } } },
	{ id = "anim_others", cat = "SISTEMA", title = "Pausar animações dos outros",
	  desc = "Personagens alheios ficam parados (volta ao se mexerem)",
	  statusText = function()
		  return "Ativo · " .. animChars .. (animChars == 1 and " personagem" or " personagens")
	  end,
	  custom = { on = animOn, off = animOff } },
	{ id = "reverb", cat = "SISTEMA", title = "Remover eco do som",
	  desc = "Desliga o reverb global do ambiente",
	  targets = { { soundT, { AmbientReverb = Enum.ReverbType.NoReverb } } } },
}
end -- fim das opções

local function register(opt)
	ById[opt.id] = opt
	Active[opt.id] = false
	Saved[opt.id] = setmetatable({}, { __mode = "k" })
	Stat[opt.id] = { items = 0, failed = 0, ok = nil }
	Watchers[opt.id] = {}
	if opt.classes then
		table.insert(ClassOptions, opt)
	end
end
for _, opt in ipairs(OPTIONS) do
	register(opt)
end

--------------------------------------------------------------------------
-- MODO FARM
--------------------------------------------------------------------------
local FARM_OPTIONS
do
	-- Anti-AFK (evento Idled do Roblox, ~20 min sem input)
	local afkConn
	local function afkOn()
		local okVU, vu = pcall(function()
			return game:GetService("VirtualUser")
		end)
		afkConn = LocalPlayer.Idled:Connect(function()
			if okVU then
				pcall(function()
					vu:CaptureController()
					vu:ClickButton2(Vector2.new())
				end)
			end
		end)
		return okVU
	end
	local function afkOff()
		if afkConn then
			afkConn:Disconnect()
			afkConn = nil
		end
	end

	-- Pulinho periódico
	local jumpToken, nextJump = 0, 0
	local function jumpOn()
		jumpToken += 1
		local my = jumpToken
		task.spawn(function()
			while Active.afk_jump and jumpToken == my and not Destroyed do
				nextJump = os.clock() + JumpEvery
				while os.clock() < nextJump do
					task.wait(1)
					if not (Active.afk_jump and jumpToken == my) or Destroyed then
						return
					end
				end
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					pcall(function()
						hum.Jump = true
					end)
				end
			end
		end)
		return true
	end
	local function jumpOff()
		jumpToken += 1
	end

	-- Reconectar sozinho
	local reconnConns = {}
	local rejoining = false
	local function tryRejoin()
		if rejoining or Destroyed or not Active.reconnect then
			return
		end
		rejoining = true
		task.spawn(function()
			for attempt = 1, 10 do
				if Destroyed or not Active.reconnect then
					break
				end
				pcall(function()
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				end)
				task.wait(8 + attempt * 2)
			end
			rejoining = false
		end)
	end
	local function reconnOn()
		local linked = 0
		if pcall(function()
			table.insert(reconnConns, GuiService.ErrorMessageChanged:Connect(function()
				local okm, msg = pcall(function()
					return GuiService:GetErrorMessage()
				end)
				if okm and msg ~= "" then
					tryRejoin()
				end
			end))
		end) then
			linked += 1
		end
		if pcall(function()
			table.insert(reconnConns, game:GetService("NetworkClient").ChildRemoved:Connect(tryRejoin))
		end) then
			linked += 1
		end
		return linked > 0
	end
	local function reconnOff()
		for _, c in ipairs(reconnConns) do
			c:Disconnect()
		end
		table.clear(reconnConns)
	end

	-- Parar renderização 3D
	local function render3dOn()
		return (pcall(function()
			RunService:Set3dRenderingEnabled(false)
		end))
	end
	local function render3dOff()
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
	end

	-- Tela preta (fica abaixo do menu e do botão flutuante)
	local function blackOn()
		if BlackGui then
			return true
		end
		local g = make("ScreenGui", {
			Name = "SillyOptimizerBlackout",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 999,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		BlackGui = g
		make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Black,
			BorderSizePixel = 0,
			Active = true,
			Parent = g,
		})
		local box = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(360, 120),
			BackgroundTransparency = 1,
			Parent = g,
		})
		local mark = sparkleShape(box, 16, C.Salmon:Lerp(C.Black, 0.55))
		mark.Position = UDim2.new(0.5, 0, 0, 8)
		local clock = text({
			Text = "00:00:00",
			Font = F.Heavy,
			TextSize = 46,
			TextColor3 = rgb(74, 70, 70),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 50),
			Parent = box,
		})
		text({
			Text = "Modo farm ativo · toque no botão flutuante para abrir o menu",
			TextSize = 13,
			TextColor3 = rgb(70, 66, 66),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Position = UDim2.fromOffset(0, 80),
			Size = UDim2.new(1, 0, 0, 34),
			Parent = box,
		})
		mount(g)
		task.spawn(function()
			local n = 0
			while BlackGui == g and not Destroyed do
				clock.Text = formatDuration(FarmSince and (os.clock() - FarmSince) or 0)
				n += 1
				if n % 45 == 0 then
					-- move um pouco para não marcar tela OLED
					box.Position = UDim2.new(0.5, math.random(-60, 60), 0.5, math.random(-60, 60))
				end
				task.wait(1)
			end
		end)
		return true
	end
	local function blackOff()
		if BlackGui then
			BlackGui:Destroy()
			BlackGui = nil
		end
	end

	-- Limitar FPS (precisa de setfpscap)
	local capOriginal
	local function capOn()
		if not Env.setfpscap then
			return false
		end
		if capOriginal == nil and Env.getfpscap then
			local ok, v = pcall(Env.getfpscap)
			if ok and type(v) == "number" then
				capOriginal = v
			end
		end
		return (pcall(Env.setfpscap, FpsCap))
	end
	local function capOff()
		-- sem getfpscap não dá para saber o limite anterior; 60 é o padrão do Roblox
		if Env.setfpscap then
			pcall(Env.setfpscap, capOriginal or 60)
		end
		capOriginal = nil
	end

	-- Esconder outros jogadores (só no seu cliente)
	local hideStore, hideConns, hideChars = {}, {}, {}
	local function hideOne(inst)
		local prop, value
		if inst:IsA("BasePart") then
			prop, value = "LocalTransparencyModifier", 1
		elseif inst:IsA("Decal") then
			prop, value = "Transparency", 1
		elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
			prop, value = "Enabled", false
		elseif inst:IsA("Humanoid") then
			prop, value = "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None
		else
			return
		end
		if hideStore[inst] == nil then
			hideStore[inst] = { prop, inst[prop] }
		end
		inst[prop] = value
	end
	local function hideChar(char)
		hideChars[char] = true
		for _, d in ipairs(char:GetDescendants()) do
			pcall(hideOne, d)
		end
		table.insert(hideConns, char.DescendantAdded:Connect(function(d)
			pcall(hideOne, d)
		end))
		table.insert(hideConns, char.AncestryChanged:Connect(function(_, parent)
			if not parent then
				hideChars[char] = nil
			end
		end))
	end
	local function hidePlr(plr)
		if plr == LocalPlayer then
			return
		end
		if plr.Character then
			hideChar(plr.Character)
		end
		table.insert(hideConns, plr.CharacterAdded:Connect(hideChar))
	end
	local function hidePlayersOn()
		for _, plr in ipairs(Players:GetPlayers()) do
			hidePlr(plr)
		end
		table.insert(hideConns, Players.PlayerAdded:Connect(hidePlr))
		return true
	end
	local function hidePlayersOff()
		for _, c in ipairs(hideConns) do
			c:Disconnect()
		end
		table.clear(hideConns)
		table.clear(hideChars)
		for inst, rec in pairs(hideStore) do
			pcall(function()
				inst[rec[1]] = rec[2]
			end)
		end
		table.clear(hideStore)
	end

	-- Esconder telas do jogo (ScreenGuis do PlayerGui, menos as nossas)
	local guiStore, guiConns, guiCount = {}, {}, 0
	local function hideScreenGui(g)
		if not g:IsA("ScreenGui") or g:GetAttribute("SillyOptimizer") then
			return
		end
		if guiStore[g] == nil then
			guiStore[g] = g.Enabled
			guiCount += 1
			-- se o jogo religar a tela, ela volta a ser escondida
			table.insert(guiConns, g:GetPropertyChangedSignal("Enabled"):Connect(function()
				if Active.hide_game_gui and g.Enabled then
					guiStore[g] = true
					g.Enabled = false
				end
			end))
		end
		g.Enabled = false
	end
	local function gameGuiOn()
		local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return false
		end
		for _, g in ipairs(pg:GetChildren()) do
			pcall(hideScreenGui, g)
		end
		table.insert(guiConns, pg.ChildAdded:Connect(function(g)
			pcall(hideScreenGui, g)
		end))
		return true
	end
	local function gameGuiOff()
		for _, c in ipairs(guiConns) do
			c:Disconnect()
		end
		table.clear(guiConns)
		for g, v in pairs(guiStore) do
			pcall(function()
				g.Enabled = v
			end)
		end
		table.clear(guiStore)
		guiCount = 0
	end

	-- Esconder menus do Roblox
	local CORE_TYPES = {
		Enum.CoreGuiType.PlayerList,
		Enum.CoreGuiType.Chat,
		Enum.CoreGuiType.Backpack,
		Enum.CoreGuiType.EmotesMenu,
		Enum.CoreGuiType.Health,
	}
	local coreStore = {}
	local function coreOn()
		local any = false
		for _, t in ipairs(CORE_TYPES) do
			local okGet, cur = pcall(function()
				return StarterGui:GetCoreGuiEnabled(t)
			end)
			if okGet and coreStore[t] == nil then
				coreStore[t] = cur
			end
			if pcall(function()
				StarterGui:SetCoreGuiEnabled(t, false)
			end) then
				any = true
			end
		end
		return any
	end
	local function coreOff()
		for t, v in pairs(coreStore) do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(t, v)
			end)
		end
		table.clear(coreStore)
	end

	-- Desligar tudo após N minutos
	local timerToken, timerEnds = 0, 0
	local function timerOn()
		timerToken += 1
		local my = timerToken
		timerEnds = os.clock() + FarmMinutes * 60
		task.spawn(function()
			while Active.farm_timer and timerToken == my and not Destroyed do
				task.wait(2)
				if os.clock() >= timerEnds and Active.farm_timer and timerToken == my then
					if Hooks.farmStopAll then
						Hooks.farmStopAll("Tempo de farm encerrado")
					end
					return
				end
			end
		end)
		return true
	end
	local function timerOff()
		timerToken += 1
	end

	local function countKeys(t)
		local n = 0
		for _ in pairs(t) do
			n += 1
		end
		return n
	end

	FARM_OPTIONS = {
		{ id = "antiafk", cat = "PROTEÇÃO", title = "Anti-AFK",
		  desc = "Evita o kick do Roblox depois de ~20 min parado",
		  statusText = function()
			  return "Ativo · protegido contra kick"
		  end,
		  custom = { on = afkOn, off = afkOff } },
		{ id = "afk_jump", cat = "PROTEÇÃO", title = "Pulinho periódico",
		  desc = "Para jogos com AFK próprio",
		  choices = { 30, 60, 120 }, choiceIndex = 2,
		  fmt = function(v)
			  return v < 60 and (v .. " s") or ((v // 60) .. " min")
		  end,
		  onChoice = function(v)
			  JumpEvery = v
			  if Active.afk_jump then
				  jumpOn()
			  end
		  end,
		  statusText = function()
			  return "Ativo · próximo pulo em " .. math.max(0, math.ceil(nextJump - os.clock())) .. " s"
		  end,
		  custom = { on = jumpOn, off = jumpOff } },
		{ id = "reconnect", cat = "PROTEÇÃO", title = "Reconectar sozinho",
		  desc = "Volta ao jogo (servidor novo) se cair ou for kickado",
		  statusText = function()
			  return rejoining and "Reconectando…" or "Ativo · vigiando a conexão"
		  end,
		  custom = { on = reconnOn, off = reconnOff } },

		{ id = "render3d", cat = "BATERIA E CALOR", title = "Parar renderização 3D",
		  desc = "Para de desenhar o mundo: menos GPU e calor",
		  statusText = function()
			  return "Ativo · mundo pausado"
		  end,
		  custom = { on = render3dOn, off = render3dOff } },
		{ id = "blackout", cat = "BATERIA E CALOR", title = "Tela preta",
		  desc = "Cobre tudo de preto (economiza em tela OLED)",
		  custom = { on = blackOn, off = blackOff } },
		{ id = "fpscap", cat = "BATERIA E CALOR", title = "Limitar FPS",
		  desc = Env.setfpscap and "Menos quadros = menos esforço do aparelho" or "Indisponível: precisa de executor (setfpscap)",
		  locked = not Env.setfpscap,
		  choices = { 10, 15, 20, 30, 45, 60 }, choiceIndex = 4,
		  fmt = function(v)
			  return v .. " FPS"
		  end,
		  onChoice = function(v)
			  FpsCap = v
			  if Active.fpscap then
				  Stat.fpscap.ok = capOn()
			  end
		  end,
		  statusText = function()
			  return "Ativo · limite de " .. FpsCap .. " FPS"
		  end,
		  custom = { on = capOn, off = capOff } },
		{ id = "mute", cat = "BATERIA E CALOR", title = "Silenciar sons",
		  desc = "Zera o volume dos sons do jogo", unit = { "som", "sons" },
		  classes = { { "Sound", { Volume = 0 } } } },
		{ id = "hide_players", cat = "BATERIA E CALOR", title = "Esconder outros jogadores",
		  desc = "Personagens e nomes somem (só para você)",
		  statusText = function()
			  local n = countKeys(hideChars)
			  return "Ativo · " .. n .. (n == 1 and " jogador oculto" or " jogadores ocultos")
		  end,
		  custom = { on = hidePlayersOn, off = hidePlayersOff } },
		{ id = "hide_game_gui", cat = "BATERIA E CALOR", title = "Esconder telas do jogo",
		  desc = "Desliga as interfaces do próprio jogo",
		  statusText = function()
			  return "Ativo · " .. guiCount .. (guiCount == 1 and " tela oculta" or " telas ocultas")
		  end,
		  custom = { on = gameGuiOn, off = gameGuiOff } },
		{ id = "hide_core_gui", cat = "BATERIA E CALOR", title = "Esconder menus do Roblox",
		  desc = "Chat, lista de jogadores, mochila, emotes e vida",
		  custom = { on = coreOn, off = coreOff } },

		{ id = "farm_timer", cat = "AUTOMÁTICO", title = "Desligar tudo depois de",
		  desc = "Encerra o modo farm sozinho",
		  choices = { 15, 30, 60, 120, 240, 480 }, choiceIndex = 3,
		  fmt = function(v)
			  return v >= 60 and ((v // 60) .. " h") or (v .. " min")
		  end,
		  onChoice = function(v)
			  FarmMinutes = v
			  if Active.farm_timer then
				  timerOn()
			  end
		  end,
		  statusText = function()
			  return "Ativo · desliga em " .. formatDuration(timerEnds - os.clock())
		  end,
		  custom = { on = timerOn, off = timerOff } },
	}

	for _, opt in ipairs(FARM_OPTIONS) do
		register(opt)
		FarmIds[opt.id] = true
	end
end

--------------------------------------------------------------------------
-- APLICAR / RESTAURAR
--------------------------------------------------------------------------
-- verify = lê de volta depois de escrever (alvos únicos: Lighting, Terrain, qualidade)
local function applyProps(id, inst, props, verify)
	local store, stat = Saved[id], Stat[id]
	local rec = store[inst]
	if not rec then
		rec = {}
		store[inst] = rec
		stat.items += 1
	end
	for prop, value in pairs(props) do
		if rec[prop] == nil then
			local ok, cur = pcall(getProp, inst, prop)
			if ok then
				rec[prop] = cur
			end
		end
		local ok = pcall(setProp, inst, prop, value)
		if ok and verify then
			local okGet, now = pcall(getProp, inst, prop)
			ok = okGet and same(now, value)
		end
		if not ok then
			stat.failed += 1
		end
	end
end

local function clearWatchers(id)
	for _, c in ipairs(Watchers[id]) do
		c:Disconnect()
	end
	table.clear(Watchers[id])
end

-- se o jogo mudar de volta (ex.: ciclo dia/noite mexendo na neblina),
-- o novo valor vira o "original" e a otimização é reaplicada
local Guard = false
local function watchTarget(id, inst, props)
	for prop, value in pairs(props) do
		local ok, sig = pcall(function()
			return inst:GetPropertyChangedSignal(prop)
		end)
		if ok then
			table.insert(Watchers[id], sig:Connect(function()
				if Guard or not Active[id] then
					return
				end
				local okv, cur = pcall(getProp, inst, prop)
				if not okv or same(cur, value) then
					return
				end
				local rec = Saved[id][inst]
				if rec then
					rec[prop] = cur
				end
				Guard = true
				pcall(setProp, inst, prop, value)
				Guard = false
			end))
		end
	end
end

local function applyTargets(opt)
	clearWatchers(opt.id)
	for _, t in ipairs(opt.targets) do
		local okI, inst = pcall(t[1])
		if okI and inst then
			local props = t[2]
			if type(props) == "function" then
				props = props()
			end
			applyProps(opt.id, inst, props, true)
			watchTarget(opt.id, inst, props)
		else
			Stat[opt.id].failed += 1
		end
	end
end

local function applyClassRules(inst, opt)
	for _, r in ipairs(opt.classes) do
		if inst:IsA(r[1]) and not (r.skip and r.skip(inst)) then
			applyProps(opt.id, inst, r[2])
		end
	end
end

local function restore(opt, sync)
	local store = Saved[opt.id]
	local items = {}
	for inst, rec in pairs(store) do
		items[#items + 1] = { inst, rec }
	end
	local function run()
		Guard = true
		for i, item in ipairs(items) do
			if not sync and (Active[opt.id] or Destroyed) then
				break
			end
			for prop, orig in pairs(item[2]) do
				pcall(setProp, item[1], prop, orig)
			end
			store[item[1]] = nil
			if not sync and i % 800 == 0 then
				Guard = false
				task.wait()
				Guard = true
			end
		end
		Guard = false
	end
	if sync then
		run()
	else
		task.spawn(run)
	end
end

local function scanRoots()
	local roots = { Workspace, Lighting, SoundService }
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then
		roots[#roots + 1] = pg
	end
	return roots
end

local scanSerial = 0
local function scan(optList)
	if #optList == 0 then
		return
	end
	scanSerial += 1
	local my = scanSerial
	for _, opt in ipairs(optList) do
		Scanning[opt.id] = my
	end
	task.spawn(function()
		local n = 0
		for _, root in ipairs(scanRoots()) do
			local ok, desc = pcall(root.GetDescendants, root)
			if ok then
				for _, inst in ipairs(desc) do
					if Destroyed then
						return
					end
					for _, opt in ipairs(optList) do
						if Active[opt.id] then
							applyClassRules(inst, opt)
						end
					end
					n += 1
					if n % 1200 == 0 then
						task.wait()
					end
				end
			end
		end
		for _, opt in ipairs(optList) do
			if Scanning[opt.id] == my then
				Scanning[opt.id] = nil
			end
		end
	end)
end

local function handleNew(inst)
	for _, opt in ipairs(ClassOptions) do
		if Active[opt.id] then
			applyClassRules(inst, opt)
		end
	end
end
track(Workspace.DescendantAdded:Connect(handleNew))
track(Lighting.DescendantAdded:Connect(handleNew))
track(SoundService.DescendantAdded:Connect(handleNew))
task.spawn(function()
	local pg = LocalPlayer:WaitForChild("PlayerGui", 30)
	if pg and not Destroyed then
		track(pg.DescendantAdded:Connect(handleNew))
	end
end)

local function setOptions(map)
	local toScan = {}
	for id, v in pairs(map) do
		local opt = ById[id]
		if opt and Active[id] ~= v then
			Active[id] = v
			local s = Stat[id]
			s.failed, s.ok = 0, nil
			if v then
				local n = 0
				for _ in pairs(Saved[id]) do
					n += 1
				end
				s.items = n
				if opt.targets then
					applyTargets(opt)
				end
				if opt.classes then
					table.insert(toScan, opt)
				end
				if opt.custom then
					local ok, res = pcall(opt.custom.on)
					s.ok = ok and res ~= false
				end
			else
				s.items = 0
				Scanning[id] = nil
				clearWatchers(id)
				restore(opt, false)
				if opt.custom then
					pcall(opt.custom.off)
				end
			end
		end
	end
	scan(toScan)
	local anyFarm = false
	for id in pairs(FarmIds) do
		if Active[id] then
			anyFarm = true
			break
		end
	end
	FarmSince = anyFarm and (FarmSince or os.clock()) or nil
	if Hooks.changed then
		Hooks.changed()
	end
end

-- texto e tipo do estado de cada opção (o que aparece embaixo do título)
local function statusOf(id)
	local opt, s = ById[id], Stat[id]
	if not Active[id] then
		return "Desligado", "off"
	end
	if opt.custom then
		if s.ok == false then
			return "Indisponível neste ambiente", "warn"
		end
		if opt.statusText then
			local ok, t = pcall(opt.statusText)
			if ok and t then
				return t, "on"
			end
		end
		return "Ativo", "on"
	end
	if Scanning[id] then
		return "Aplicando…", "busy"
	end
	if opt.targets then
		if s.failed > 0 then
			return opt.blockedText or "Sem efeito neste jogo", "warn"
		end
		return "Ativo", "on"
	end
	if s.items == 0 then
		return "Ativo · nada disso neste mapa", "on"
	end
	local unit = opt.unit or { "objeto", "objetos" }
	local t = "Ativo · " .. fmtNum(s.items) .. " " .. (s.items == 1 and unit[1] or unit[2])
	if s.failed > 0 then
		t = t .. " · " .. fmtNum(s.failed) .. " bloqueados"
	end
	return t, "on"
end

local function countActive(idList)
	local n = 0
	for _, opt in ipairs(idList) do
		if Active[opt.id] then
			n += 1
		end
	end
	return n
end

--------------------------------------------------------------------------
-- PRESETS
--------------------------------------------------------------------------
local PRESETS
do
local softList = { "fog", "post_fx", "water_waves", "water_reflect", "reflections", "reverb", "shadows", "quality" }
local mediumList = table.clone(softList)
for _, id in ipairs({ "particles", "fire_smoke", "part_shadows", "grass", "reflectance" }) do
	table.insert(mediumList, id)
end
local extremeList = table.clone(mediumList)
for _, id in ipairs({ "atmosphere", "lights", "sky", "materials", "mesh_fidelity" }) do
	table.insert(extremeList, id)
end
local potatoList = {}
for _, opt in ipairs(OPTIONS) do
	potatoList[#potatoList + 1] = opt.id
end

PRESETS = {
	{ id = "soft", name = "Soft", level = 1, quality = 5, list = softList, accent = C.Gold,
	  desc = "Mantém o visual bonito. Tira neblina, pós-processamento, água animada e sombras globais." },
	{ id = "medium", name = "Medium", level = 2, quality = 3, list = mediumList, accent = C.Peach,
	  desc = "Equilíbrio entre visual e FPS. Soma partículas, fogo, grama e sombra dos objetos." },
	{ id = "extreme", name = "Extreme", level = 3, quality = 1, list = extremeList, accent = C.Salmon,
	  desc = "FPS alto. Remove luzes, atmosfera e céu, deixa materiais lisos e malhas simples." },
	{ id = "potato", name = "Potato", level = 4, quality = 1, list = potatoList, accent = C.Pink,
	  desc = "Tudo no mínimo. Visual bem simples, feito para aparelho fraco." },
}
end

local State = { preset = nil }

local function setChoice(opt, value, silent)
	for i, v in ipairs(opt.choices) do
		if v == value then
			opt.choiceIndex = i
			if opt.stepper then
				opt.stepper.Set(i, true)
			end
			if opt.onChoice and not silent then
				opt.onChoice(v)
			end
			return true
		end
	end
	return false
end

ById.quality.onChoice = function(v)
	QualityChoice = v
	if Active.quality then
		Stat.quality.failed = 0
		applyTargets(ById.quality)
	end
	if Hooks.changed then
		Hooks.changed()
	end
end

local function applyPreset(p)
	local inList = {}
	if p then
		for _, id in ipairs(p.list) do
			inList[id] = true
		end
		setChoice(ById.quality, p.quality)
	end
	local map = {}
	for _, opt in ipairs(OPTIONS) do
		map[opt.id] = inList[opt.id] == true
	end
	State.preset = p
	setOptions(map)
end

Splash.step("Lendo iluminação e terreno", 0.3)
do
	local ok, n = pcall(function()
		return #Workspace:GetDescendants()
	end)
	Splash.step(ok and ("Mapeando o mundo · " .. fmtNum(n) .. " objetos") or "Mapeando o mundo", 0.46)
end

--------------------------------------------------------------------------
-- COMPONENTES DE INTERFACE
--------------------------------------------------------------------------
-- switch estilo iOS: trilho colorido + bolinha que "estica" ao mudar
local function Switch(parent, accent, initial)
	local api = { value = initial }
	local trackF = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(46, 28),
		BackgroundColor3 = initial and accent or C.Off,
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner("full") })
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, initial and 32 or 14, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Parent = trackF,
	}, { corner("full") })
	make("UIStroke", { Color = C.Black, Transparency = 0.85, Thickness = 1, Parent = knob })
	function api.Set(v, silent)
		if v == api.value then
			return
		end
		api.value = v
		tween(trackF, 0.25, { BackgroundColor3 = v and accent or C.Off }, EASE.Quad)
		tween(knob, 0.1, { Size = UDim2.fromOffset(28, 22) }, EASE.Quad)
		tween(knob, 0.38, { Position = UDim2.new(0, v and 32 or 14, 0.5, 0) }, EASE.Back)
		task.delay(0.1, function()
			tween(knob, 0.25, { Size = UDim2.fromOffset(22, 22) }, EASE.Back)
		end)
		if not silent and api.onChange then
			api.onChange(v)
		end
	end
	function api.Toggle()
		api.Set(not api.value)
	end
	function api.SetLocked(locked)
		trackF.BackgroundTransparency = locked and 0.5 or 0
		knob.BackgroundTransparency = locked and 0.5 or 0
	end
	return api
end

-- seletor com setas: ‹ valor ›
local function Stepper(parent, cfg, accent, rightOffset)
	local f = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(rightOffset or 16), 0.5, 0),
		Size = UDim2.fromOffset(cfg.width or 112, 30),
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		Parent = parent,
	}, { corner(10) })
	local value = text({
		Text = "",
		Font = F.Bold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -52, 1, 0),
		Parent = f,
	})
	local function arrow(glyph, xScale, anchorX)
		return make("TextButton", {
			Text = glyph,
			Font = F.Bold,
			TextSize = 20,
			TextColor3 = accent,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(anchorX, 0),
			Position = UDim2.new(xScale, 0, 0, -1),
			Size = UDim2.new(0, 28, 1, 0),
			Parent = f,
		})
	end
	local minus = arrow("‹", 0, 0)
	local plus = arrow("›", 1, 1)
	local api = { index = cfg.index or 1, frame = f }
	local function paint(dir)
		value.Text = cfg.fmt(cfg.choices[api.index])
		minus.TextColor3 = api.index > 1 and accent or C.Off
		plus.TextColor3 = api.index < #cfg.choices and accent or C.Off
		if dir then
			value.Position = UDim2.fromOffset(26 + dir * 10, 0)
			value.TextTransparency = 1
			tween(value, 0.28, { Position = UDim2.fromOffset(26, 0), TextTransparency = 0 })
		end
	end
	function api.Set(i, silent)
		i = math.clamp(i, 1, #cfg.choices)
		if i == api.index then
			paint()
			return
		end
		local dir = i > api.index and 1 or -1
		api.index = i
		paint(dir)
		if not silent and cfg.onChange then
			cfg.onChange(cfg.choices[i], i)
		end
	end
	minus.Activated:Connect(function()
		api.Set(api.index - 1)
	end)
	plus.Activated:Connect(function()
		api.Set(api.index + 1)
	end)
	paint()
	return api
end

-- controle segmentado com pílula deslizante
local function Segmented(parent, cfg)
	local accent = cfg.accent
	local n = #cfg.items
	local f = make("Frame", {
		Size = cfg.size,
		Position = cfg.position or UDim2.new(),
		AnchorPoint = cfg.anchor or Vector2.zero,
		LayoutOrder = cfg.order or 0,
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Active = true,
		Parent = parent,
	}, { corner(10), stroke(C.Stroke, 1, 0) })
	local pill = make("Frame", {
		BackgroundColor3 = C.Surface2:Lerp(accent, 0.12),
		BorderSizePixel = 0,
		Parent = f,
	}, { corner(8) })
	local function pillGeom(i)
		return UDim2.new((i - 1) / n, 3 - 6 * (i - 1) / n, 0, 3), UDim2.new(1 / n, -6 / n, 1, -6)
	end
	local api = { index = cfg.index or 1 }
	local labels = {}
	local function paint(instant)
		local pos, size = pillGeom(api.index)
		pill.Size = size
		tween(pill, instant and 0 or 0.35, { Position = pos })
		for i, b in ipairs(labels) do
			tween(b, instant and 0 or 0.2, { TextColor3 = i == api.index and accent or C.Dim })
		end
	end
	for i, label in ipairs(cfg.items) do
		local b = make("TextButton", {
			Text = label,
			Font = F.Bold,
			TextSize = 12,
			TextColor3 = C.Dim,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Position = UDim2.fromScale((i - 1) / n, 0),
			Size = UDim2.fromScale(1 / n, 1),
			Parent = f,
		})
		labels[i] = b
		b.Activated:Connect(function()
			api.Set(i)
		end)
	end
	function api.Set(i, silent)
		if i == api.index then
			return
		end
		api.index = i
		paint(false)
		if not silent and cfg.onChange then
			cfg.onChange(i)
		end
	end
	paint(true)
	api.frame = f
	return api
end

-- botão: filled (cor cheia), tinted (fundo suave), ghost (neutro), danger
local function Button(parent, cfg)
	local accent = cfg.accent or C.Salmon
	local function colors(style)
		if style == "filled" then
			return accent, C.Ink
		elseif style == "tinted" then
			return C.Surface:Lerp(accent, 0.16), accent
		elseif style == "danger" then
			return C.Surface:Lerp(C.Warn, 0.16), C.Warn
		elseif style == "dangerFilled" then
			return C.Warn, C.Ink
		end
		return C.Surface2, C.Text
	end
	local bg, fg = colors(cfg.style or "filled")
	local b = make("TextButton", {
		Text = cfg.text,
		Font = F.Bold,
		TextSize = cfg.textSize or 13,
		TextColor3 = fg,
		BackgroundColor3 = bg,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = cfg.size,
		Position = cfg.position or UDim2.new(),
		AnchorPoint = cfg.anchor or Vector2.zero,
		LayoutOrder = cfg.order or 0,
		Parent = parent,
	}, { corner(cfg.radius or 10) })
	local sc = make("UIScale", { Parent = b })
	local api = { inst = b, base = bg, Activated = b.Activated }
	b.MouseEnter:Connect(function()
		tween(b, 0.15, { BackgroundColor3 = api.base:Lerp(C.White, 0.1) })
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.2, { BackgroundColor3 = api.base })
		tween(sc, 0.2, { Scale = 1 })
	end)
	b.InputBegan:Connect(function(i)
		if isPress(i) then
			tween(sc, 0.1, { Scale = 0.95 }, EASE.Quad)
		end
	end)
	b.InputEnded:Connect(function(i)
		if isPress(i) then
			tween(sc, 0.4, { Scale = 1 }, EASE.Back)
		end
	end)
	function api.SetStyle(style, label, newAccent)
		accent = newAccent or accent
		local bg2, fg2 = colors(style)
		api.base = bg2
		tween(b, 0.25, { BackgroundColor3 = bg2, TextColor3 = fg2 })
		if label then
			b.Text = label
		end
	end
	return api
end

local function Section(parent, order, title, accent)
	local f = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	text({
		Text = title,
		Font = F.Bold,
		TextSize = 11,
		TextColor3 = accent:Lerp(C.Sub, 0.35),
		Position = UDim2.fromOffset(6, 14),
		Size = UDim2.new(1, -12, 0, 14),
		Parent = f,
	})
	return f
end

-- linha base: título, descrição e (opcional) linha de estado
local function Row(parent, order, cfg)
	local accent = cfg.accent
	local hasStatus = cfg.status == true
	local h = hasStatus and 78 or 64
	local row = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner(14) })
	local st = stroke(C.Stroke, 1, 0)
	st.Parent = row
	local scale = make("UIScale", { Parent = row })
	local hit = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = row,
	})
	local bar = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 3, 0, h - 32),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = row,
	}, { corner("full") })
	local right = cfg.rightWidth or 80
	local y0 = hasStatus and 14 or 13
	local title = text({
		Text = cfg.title,
		Font = F.Bold,
		TextSize = 15,
		Position = UDim2.fromOffset(18, y0),
		Size = UDim2.new(1, -(18 + right), 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	local desc = text({
		Text = cfg.desc or "",
		TextSize = 12,
		TextColor3 = C.Dim,
		Position = UDim2.fromOffset(18, y0 + 20),
		Size = UDim2.new(1, -(18 + right), 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	local api = { frame = row, hit = hit, title = title, desc = desc, accent = accent }
	if hasStatus then
		local dot = make("Frame", {
			Position = UDim2.fromOffset(18, y0 + 45),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = C.Dim,
			BorderSizePixel = 0,
			Parent = row,
		}, { corner("full") })
		local sl = text({
			Text = "Desligado",
			Font = F.Bold,
			TextSize = 11,
			TextColor3 = C.Dim,
			Position = UDim2.fromOffset(30, y0 + 40),
			Size = UDim2.new(1, -(30 + right), 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local lastColor = C.Dim
		function api.SetStatus(t, color)
			if sl.Text ~= t then
				sl.Text = t
			end
			if lastColor ~= color then
				lastColor = color
				tween(sl, 0.25, { TextColor3 = color })
				tween(dot, 0.25, { BackgroundColor3 = color })
			end
		end
	end
	local on = false
	local function baseColor()
		return on and C.Surface:Lerp(accent, 0.07) or C.Surface
	end
	function api.SetOn(v)
		on = v
		tween(row, 0.3, { BackgroundColor3 = baseColor() })
		tween(st, 0.3, { Color = v and C.Stroke:Lerp(accent, 0.5) or C.Stroke })
		tween(bar, 0.3, { BackgroundTransparency = v and 0 or 1 })
	end
	hit.MouseEnter:Connect(function()
		tween(row, 0.15, { BackgroundColor3 = baseColor():Lerp(C.Surface2, 0.5) })
	end)
	hit.MouseLeave:Connect(function()
		tween(row, 0.2, { BackgroundColor3 = baseColor() })
		tween(scale, 0.2, { Scale = 1 })
	end)
	if cfg.pressable ~= false then
		hit.InputBegan:Connect(function(i)
			if isPress(i) then
				tween(scale, 0.12, { Scale = 0.985 }, EASE.Quad)
			end
		end)
		hit.InputEnded:Connect(function(i)
			if isPress(i) then
				tween(scale, 0.35, { Scale = 1 }, EASE.Back)
			end
		end)
	end
	return api
end

-- linha com switch (a linha inteira é clicável)
local function SwitchRow(parent, order, cfg)
	cfg.rightWidth = cfg.rightWidth or (cfg.stepper and 200 or 80)
	local r = Row(parent, order, cfg)
	local sw = Switch(r.frame, cfg.accent, cfg.initial == true)
	r.switch = sw
	if cfg.initial then
		r.SetOn(true)
	end
	if cfg.locked then
		sw.SetLocked(true)
		r.title.TextColor3 = C.Sub
	end
	sw.onChange = function(v)
		r.SetOn(v)
		if cfg.onToggle then
			cfg.onToggle(v)
		end
	end
	r.hit.Activated:Connect(function()
		if cfg.locked then
			if cfg.onLocked then
				cfg.onLocked()
			end
			return
		end
		sw.Toggle()
	end)
	if cfg.stepper then
		r.stepper = Stepper(r.frame, cfg.stepper, cfg.accent, 76)
	end
	function r.Set(v)
		if sw.value ~= v then
			sw.Set(v, true)
			r.SetOn(v)
		end
	end
	return r
end

local function Pill(parent, txt, color, rightOffset)
	local p = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(rightOffset or 16), 0.5, 0),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Surface:Lerp(color, 0.16),
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner("full"), pad(10, 0, 10, 0) })
	local l = text({
		Text = txt,
		Font = F.Bold,
		TextSize = 11,
		TextColor3 = color,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = p,
	})
	return p, l
end

--------------------------------------------------------------------------
-- TOASTS (avisos rápidos no topo)
--------------------------------------------------------------------------
local ToastHolder = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, TopInset + 6),
	Size = UDim2.new(0, 460, 0, 200),
	BackgroundTransparency = 1,
	ZIndex = 40,
	Parent = Gui,
}, { list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center) })

local toastSerial = 0
local function toast(msg, color)
	if Destroyed then
		return
	end
	toastSerial += 1
	local kids = {}
	for _, c in ipairs(ToastHolder:GetChildren()) do
		if c:IsA("CanvasGroup") then
			kids[#kids + 1] = c
		end
	end
	if #kids >= 3 then
		kids[1]:Destroy()
	end
	local cg = make("CanvasGroup", {
		LayoutOrder = toastSerial,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = ToastHolder,
	}, {
		corner("full"),
		stroke(C.Stroke, 1, 0),
		pad(16, 0, 18, 0),
		list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	make("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = color or C.Salmon,
		BorderSizePixel = 0,
		Parent = cg,
	}, { corner("full") })
	text({
		LayoutOrder = 2,
		Text = msg,
		Font = F.Semi,
		TextSize = 13,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = cg,
	})
	local sc = make("UIScale", { Scale = 0.85, Parent = cg })
	tween(sc, 0.45, { Scale = 1 }, EASE.Back)
	tween(cg, 0.25, { GroupTransparency = 0 })
	task.delay(2.6, function()
		if cg.Parent then
			tween(sc, 0.25, { Scale = 0.9 }, EASE.Quad, DIR.In)
			tween(cg, 0.25, { GroupTransparency = 1 })
			task.delay(0.27, function()
				cg:Destroy()
			end)
		end
	end)
end

--------------------------------------------------------------------------
-- JANELA
--------------------------------------------------------------------------
local WIN_W, WIN_H = 720, 460
local SIDE_W, HEAD_H = 184, 96
local TAB_H, TAB_GAP = 40, 4

local TABS = {
	{ id = "presets", name = "Presets", kicker = "PRESETS", accent = C.Salmon,
	  title = "Desempenho em um toque", sub = "Escolha um nível e o jogo fica mais leve na hora" },
	{ id = "tweaks", name = "Ajustes", kicker = "AJUSTES", accent = C.Gold,
	  title = "Ajustes individuais", sub = "Ligado = otimização aplicada · Desligado = visual original" },
	{ id = "farm", name = "Farm", kicker = "MODO FARM", accent = C.Peach,
	  title = "Deixe rodando leve", sub = "Fique no jogo gastando o mínimo de bateria e calor" },
	{ id = "hud", name = "HUD", kicker = "HUD", accent = C.Pink,
	  title = "Informações na tela", sub = "Escolha o que aparece no painel flutuante" },
	{ id = "config", name = "Configurações", kicker = "CONFIGURAÇÕES", accent = C.Apricot,
	  title = "Preferências", sub = "Atalho, animações, salvamento e compatibilidade" },
}

local Root = make("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIN_W, WIN_H),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 5,
	Parent = Gui,
})
local FitScale = make("UIScale", { Parent = Root })
local Holder = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = Root })
local AnimScale = make("UIScale", { Scale = 0.94, Parent = Holder })

local Shadows = {}
for _, s in ipairs({ { 8, 10, 0.86 }, { 22, 26, 0.92 }, { 42, 48, 0.96 } }) do
	local f = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.new(1, s[1], 1, s[2]),
		BackgroundColor3 = C.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = Holder,
	}, { corner(26 + s[1] // 4) })
	table.insert(Shadows, { frame = f, shown = s[3] })
end

local Window = make("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Bg,
	BorderSizePixel = 0,
	GroupTransparency = 1,
	Parent = Holder,
}, { corner(22), stroke(C.Stroke, 1, 0) })

-- menu lateral
local Sidebar = make("Frame", {
	Size = UDim2.new(0, SIDE_W, 1, 0),
	BackgroundColor3 = C.Side,
	BorderSizePixel = 0,
	Parent = Window,
})
make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = C.Stroke,
	BorderSizePixel = 0,
	Parent = Sidebar,
})
local Brand = make("Frame", {
	Size = UDim2.new(1, 0, 0, 78),
	BackgroundTransparency = 1,
	Active = true,
	Parent = Sidebar,
})
do
	local tile = brandTile(Brand, 36, 11, 20)
	tile.Position = UDim2.fromOffset(18, 22)
	text({ Text = "Silly", Font = F.Heavy, TextSize = 17, Position = UDim2.fromOffset(64, 21), Size = UDim2.fromOffset(100, 18), Parent = Brand })
	text({ Text = "Optimizer", TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(64, 40), Size = UDim2.fromOffset(100, 16), Parent = Brand })
end

local TabHolder = make("Frame", {
	Position = UDim2.fromOffset(12, 84),
	Size = UDim2.new(1, -24, 1, -140),
	BackgroundTransparency = 1,
	Parent = Sidebar,
})
local Indicator = make("Frame", {
	Size = UDim2.new(1, 0, 0, TAB_H),
	BackgroundColor3 = TABS[1].accent,
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
	Parent = TabHolder,
}, { corner(12) })
local IndicatorBar = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.fromOffset(3, 18),
	BackgroundColor3 = TABS[1].accent,
	BorderSizePixel = 0,
	Parent = Indicator,
}, { corner("full") })

local KEY_NAMES = {
	RightShift = "Shift direito",
	RightControl = "Ctrl direito",
	Insert = "Insert",
	Home = "Home",
	F6 = "F6",
}
local KEY_LIST = { "RightShift", "RightControl", "Insert", "Home", "F6" }
local refreshKeyCap
do -- rodapé do menu lateral: [tecla] abre e fecha
	local foot = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.new(1, -36, 0, 22),
		BackgroundTransparency = 1,
		Parent = Sidebar,
	}, { list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local cap = make("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Parent = foot,
	}, { corner(6), pad(8, 0, 8, 0) })
	local capLabel = text({
		Text = "",
		Font = F.Bold,
		TextSize = 11,
		TextColor3 = C.Sub,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = cap,
	})
	local hint = text({
		LayoutOrder = 2,
		Text = "abre e fecha",
		TextSize = 11,
		TextColor3 = C.Dim,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = foot,
	})
	refreshKeyCap = function()
		capLabel.Text = Env.touch and "Botão flutuante" or (KEY_NAMES[Prefs.keybind] or Prefs.keybind)
		hint.Visible = not Env.touch
	end
end

local TabUI, Pages, Bodies = {}, {}, {}
local CurrentTab
local TabTick = {}

for i, tab in ipairs(TABS) do
	local b = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, (i - 1) * (TAB_H + TAB_GAP)),
		Size = UDim2.new(1, 0, 0, TAB_H),
		Parent = TabHolder,
	})
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = tab.accent:Lerp(C.Side, 0.55),
		BorderSizePixel = 0,
		Parent = b,
	}, { corner("full") })
	local label = text({
		Text = tab.name,
		Font = F.Bold,
		TextSize = 14,
		TextColor3 = C.Sub,
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -40, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = b,
	})
	local badge, badgeText = Pill(b, "", tab.accent, 8)
	badge.Size = UDim2.fromOffset(0, 18)
	badge.Visible = false
	b.MouseEnter:Connect(function()
		if CurrentTab ~= i then
			tween(label, 0.15, { TextColor3 = C.Text })
		end
	end)
	b.MouseLeave:Connect(function()
		if CurrentTab ~= i then
			tween(label, 0.2, { TextColor3 = C.Sub })
		end
	end)
	TabUI[i] = { btn = b, dot = dot, label = label, badge = badge, badgeText = badgeText }

	local page = make("CanvasGroup", {
		Name = tab.id,
		Position = UDim2.fromOffset(SIDE_W, 0),
		Size = UDim2.new(1, -SIDE_W, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		Parent = Window,
	})
	make("Frame", {
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = tab.accent,
		BorderSizePixel = 0,
		Parent = page,
	}, { make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.86, 1) }) })
	local deco = sparkleShape(page, 70, tab.accent:Lerp(C.Bg, 0.72))
	deco.Position = UDim2.new(1, -70, 0, 50)
	deco.Rotation = i * 12
	local deco2 = sparkleShape(page, 22, tab.accent:Lerp(C.Bg, 0.6))
	deco2.Position = UDim2.new(1, -122, 0, 26)
	text({ Text = tab.kicker, Font = F.Bold, TextSize = 11, TextColor3 = tab.accent, Position = UDim2.fromOffset(24, 22), Size = UDim2.new(1, -120, 0, 14), Parent = page })
	text({ Text = tab.title, Font = F.Heavy, TextSize = 26, Position = UDim2.fromOffset(24, 38), Size = UDim2.new(1, -150, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd, Parent = page })
	text({ Text = tab.sub, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(24, 68), Size = UDim2.new(1, -110, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = page })

	local body = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, HEAD_H),
		Size = UDim2.new(1, 0, 1, -HEAD_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = tab.accent,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = page,
	}, { pad(20, 4, 20, 24), list(Enum.FillDirection.Vertical, 8) })
	Pages[i], Bodies[i] = page, body
end

-- área de arrastar a janela (topo do conteúdo + logo)
local DragStrip = make("Frame", {
	Position = UDim2.fromOffset(SIDE_W, 0),
	Size = UDim2.new(1, -SIDE_W - 60, 0, 64),
	BackgroundTransparency = 1,
	Active = true,
	Parent = Window,
})

local CloseBtn = make("TextButton", {
	Text = "",
	AutoButtonColor = false,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 18),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = C.Surface2,
	BorderSizePixel = 0,
	Parent = Window,
}, { corner("full") })
local CloseBars = {}
for _, rot in ipairs({ 45, -45 }) do
	CloseBars[#CloseBars + 1] = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 2),
		Rotation = rot,
		BackgroundColor3 = C.Sub,
		BorderSizePixel = 0,
		Parent = CloseBtn,
	}, { corner("full") })
end
CloseBtn.MouseEnter:Connect(function()
	tween(CloseBtn, 0.15, { BackgroundColor3 = C.Surface:Lerp(C.Warn, 0.3) })
	for _, b in ipairs(CloseBars) do
		tween(b, 0.15, { BackgroundColor3 = C.Text })
	end
end)
CloseBtn.MouseLeave:Connect(function()
	tween(CloseBtn, 0.2, { BackgroundColor3 = C.Surface2 })
	for _, b in ipairs(CloseBars) do
		tween(b, 0.2, { BackgroundColor3 = C.Sub })
	end
end)

local function selectTab(i, instant)
	if CurrentTab == i then
		return
	end
	local prev = CurrentTab
	CurrentTab = i
	local dir = (prev and i < prev) and -1 or 1
	for j, page in ipairs(Pages) do
		if j == i then
			page.Visible = true
			if instant or Prefs.reduceMotion then
				page.GroupTransparency = 0
				page.Position = UDim2.fromOffset(SIDE_W, 0)
			else
				page.GroupTransparency = 1
				page.Position = UDim2.fromOffset(SIDE_W, 24 * dir)
				tween(page, 0.45, { GroupTransparency = 0, Position = UDim2.fromOffset(SIDE_W, 0) })
			end
		elseif j == prev and not instant then
			tween(page, 0.14, { GroupTransparency = 1 }, EASE.Quad)
			task.delay(0.15, function()
				if CurrentTab ~= j then
					page.Visible = false
				end
			end)
		else
			page.Visible = false
		end
	end
	local d = instant and 0 or 0.4
	tween(Indicator, d, { Position = UDim2.fromOffset(0, (i - 1) * (TAB_H + TAB_GAP)), BackgroundColor3 = TABS[i].accent })
	tween(IndicatorBar, d, { BackgroundColor3 = TABS[i].accent })
	for j, t in ipairs(TabUI) do
		local sel = j == i
		tween(t.label, d * 0.6, { TextColor3 = sel and C.Text or C.Sub })
		tween(t.dot, d, {
			BackgroundColor3 = sel and TABS[j].accent or TABS[j].accent:Lerp(C.Side, 0.55),
			Size = sel and UDim2.fromOffset(8, 8) or UDim2.fromOffset(6, 6),
		})
	end
	if TabTick[i] then
		TabTick[i]()
	end
end

for i, t in ipairs(TabUI) do
	t.btn.Activated:Connect(function()
		selectTab(i, false)
	end)
end

-- linhas de opções do motor (Ajustes + Farm), para sincronizar estado
local OptionRows = {}
local function kindColor(kind, accent)
	if kind == "on" then
		return accent
	elseif kind == "warn" then
		return C.Warn
	elseif kind == "busy" then
		return C.Sub
	end
	return C.Dim
end
local function syncRows()
	for id, r in pairs(OptionRows) do
		r.Set(Active[id])
		local t, kind = statusOf(id)
		r.SetStatus(t, kindColor(kind, r.accent))
	end
end

local Refreshers = {}
local scheduleSave -- definido junto do salvamento

local function optionRow(parent, order, opt, accent, onToggle)
	local cfg = {
		title = opt.title,
		desc = opt.desc,
		accent = accent,
		status = true,
		initial = Active[opt.id],
		locked = opt.locked,
		onLocked = function()
			toast("Precisa de executor com setfpscap", C.Warn)
		end,
		onToggle = onToggle,
	}
	if opt.choices then
		cfg.stepper = {
			choices = opt.choices,
			index = opt.choiceIndex,
			fmt = opt.fmt,
			onChange = function(v, i)
				opt.choiceIndex = i
				if opt.onChoice then
					opt.onChoice(v)
				end
				if scheduleSave then
					scheduleSave()
				end
			end,
		}
	end
	local r = SwitchRow(parent, order, cfg)
	opt.stepper = r.stepper
	OptionRows[opt.id] = r
	return r
end

--------------------------------------------------------------------------
-- ABA 1 · PRESETS
--------------------------------------------------------------------------
local FpsHistory, HIST = {}, 36
local fpsValue, frameMs = 60, 16.7

local function getPing()
	local ok, v = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(v) == "number" and v > 0 then
		return v
	end
	local ok2, p = pcall(function()
		return LocalPlayer:GetNetworkPing() * 1000
	end)
	if ok2 and type(p) == "number" and p > 0 then
		return p
	end
	return nil
end

local function fpsColor(fps)
	return fps >= 55 and C.Good or (fps >= 30 and C.Gold or C.Warn)
end

do
	local tab, body = TABS[1], Bodies[1]
	local A = tab.accent

	-- cartão de desempenho ao vivo
	local perf = make("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 122),
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Parent = body,
	}, { corner(16), stroke(C.Stroke, 1, 0) })
	text({ Text = "DESEMPENHO AGORA", Font = F.Bold, TextSize = 11, TextColor3 = C.Dim, Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(200, 14), Parent = perf })
	local fpsRow = make("Frame", {
		Position = UDim2.fromOffset(16, 30),
		Size = UDim2.new(0.5, -16, 0, 48),
		BackgroundTransparency = 1,
		Parent = perf,
	}, { list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom) })
	local fpsBig = text({ LayoutOrder = 1, Text = "60", Font = F.Heavy, TextSize = 44, TextColor3 = C.Good, Size = UDim2.fromOffset(0, 48), AutomaticSize = Enum.AutomaticSize.X, Parent = fpsRow })
	text({ LayoutOrder = 2, Text = "FPS", Font = F.Bold, TextSize = 14, TextColor3 = C.Sub, Size = UDim2.fromOffset(40, 26), Parent = fpsRow })
	local info = text({ Text = "", TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(18, 88), Size = UDim2.new(0.5, -18, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = perf })
	local spark = make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.new(0.48, 0, 0, 74),
		BackgroundTransparency = 1,
		Parent = perf,
	}, { list(Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })
	local bars = {}
	for i = 1, HIST do
		bars[i] = make("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1 / HIST, -2, 0.04, 0),
			BackgroundColor3 = A,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			Parent = spark,
		}, { corner(2) })
	end

	TabTick[1] = function()
		local fps = math.floor(fpsValue + 0.5)
		fpsBig.Text = tostring(fps)
		fpsBig.TextColor3 = fpsColor(fps)
		local ping = getPing()
		local n = countActive(OPTIONS)
		info.Text = (ping and ("Ping " .. math.floor(ping + 0.5) .. " ms  ·  ") or "")
			.. n .. (n == 1 and " otimização ativa" or " otimizações ativas")
		local maxv = 60
		for _, v in ipairs(FpsHistory) do
			maxv = math.max(maxv, v)
		end
		local offset = HIST - #FpsHistory
		for i = 1, HIST do
			local v = FpsHistory[i - offset]
			local h = v and math.clamp(v / maxv, 0.04, 1) or 0.04
			bars[i].Size = UDim2.new(1 / HIST, -2, h, 0)
			bars[i].BackgroundTransparency = (i == HIST) and 0 or 0.65
			bars[i].BackgroundColor3 = v and fpsColor(v):Lerp(A, 0.5) or C.Surface2
		end
	end

	Section(body, 2, "ESCOLHA UM NÍVEL", A)

	local grid = make("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		make("UIGridLayout", {
			CellSize = UDim2.new(0.5, -5, 0, 164),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local cards = {}
	for i, p in ipairs(PRESETS) do
		local card = make("Frame", {
			LayoutOrder = i,
			BackgroundColor3 = C.Surface,
			BorderSizePixel = 0,
			Parent = grid,
		}, { corner(16) })
		local st = stroke(C.Stroke, 1, 0)
		st.Parent = card
		local cs = make("UIScale", { Parent = card })
		text({ Text = p.name, Font = F.Heavy, TextSize = 19, Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -90, 0, 22), Parent = card })
		-- medidor de intensidade (4 barrinhas)
		local meter = make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 18),
			Size = UDim2.fromOffset(34, 16),
			BackgroundTransparency = 1,
			Parent = card,
		}, { list(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })
		for k = 1, 4 do
			make("Frame", {
				LayoutOrder = k,
				Size = UDim2.fromOffset(6, 4 + k * 3),
				BackgroundColor3 = k <= p.level and p.accent or C.Surface2,
				BorderSizePixel = 0,
				Parent = meter,
			}, { corner(2) })
		end
		local activePill, activeText = Pill(card, "ATIVO", p.accent, 62)
		activePill.AnchorPoint = Vector2.new(1, 0)
		activePill.Position = UDim2.new(1, -60, 0, 14)
		activePill.Size = UDim2.fromOffset(0, 22)
		activePill.Visible = false
		text({
			Text = p.desc,
			TextSize = 12,
			TextColor3 = C.Sub,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(16, 44),
			Size = UDim2.new(1, -32, 0, 48),
			Parent = card,
		})
		text({
			Text = #p.list .. " ajustes · qualidade " .. p.quality,
			Font = F.Bold,
			TextSize = 11,
			TextColor3 = C.Dim,
			Position = UDim2.fromOffset(16, 96),
			Size = UDim2.new(1, -32, 0, 14),
			Parent = card,
		})
		local btn = Button(card, {
			text = "Aplicar",
			style = "filled",
			accent = p.accent,
			size = UDim2.new(1, -32, 0, 34),
			position = UDim2.new(0, 16, 1, -46),
		})
		card.MouseEnter:Connect(function()
			tween(cs, 0.25, { Scale = 1.015 })
		end)
		card.MouseLeave:Connect(function()
			tween(cs, 0.3, { Scale = 1 })
		end)
		btn.Activated:Connect(function()
			if State.preset == p then
				applyPreset(nil)
				toast("Preset desfeito · visual original de volta", C.Sub)
			else
				applyPreset(p)
				burst(card, UDim2.new(0.5, 0, 1, -30), 8, 70)
				toast("Preset " .. p.name .. " aplicado", p.accent)
			end
		end)
		cards[i] = { preset = p, card = card, stroke = st, btn = btn, pill = activePill, activeText = activeText, wasOn = false }
	end

	table.insert(Refreshers, function()
		for _, c in ipairs(cards) do
			local on = State.preset == c.preset
			if on ~= c.wasOn then
				c.wasOn = on
				tween(c.card, 0.3, { BackgroundColor3 = on and C.Surface:Lerp(c.preset.accent, 0.08) or C.Surface })
				tween(c.stroke, 0.3, { Color = on and c.preset.accent or C.Stroke, Thickness = on and 1.5 or 1 })
				c.btn.SetStyle(on and "tinted" or "filled", on and "Desfazer preset" or "Aplicar")
				c.pill.Visible = on
			end
		end
	end)

	-- restaurar padrão
	local strip = Row(body, 4, { title = "Restaurar padrão", desc = "Desliga todos os ajustes e devolve o visual original", accent = A, rightWidth = 130, pressable = false })
	local rb = Button(strip.frame, {
		text = "Restaurar",
		style = "ghost",
		size = UDim2.fromOffset(104, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
	})
	rb.Activated:Connect(function()
		applyPreset(nil)
		toast("Visual original restaurado", C.Sub)
	end)

	text({
		LayoutOrder = 5,
		Text = "Tudo acontece só no seu aparelho e pode ser desfeito a qualquer momento.",
		TextSize = 11,
		TextColor3 = C.Dim,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = body,
	})
end

--------------------------------------------------------------------------
-- ABA 2 · AJUSTES
--------------------------------------------------------------------------
do
	local tab, body = TABS[2], Bodies[2]
	local A = tab.accent
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	-- resumo
	local summary = make("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Parent = body,
	}, { corner(16), stroke(C.Stroke, 1, 0) })
	text({ Text = "OTIMIZAÇÕES ATIVAS", Font = F.Bold, TextSize = 11, TextColor3 = C.Dim, Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(200, 14), Parent = summary })
	local count = text({ Text = "0 de " .. #OPTIONS, Font = F.Heavy, TextSize = 26, Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -180, 0, 30), Parent = summary })
	local pbar = make("Frame", {
		Position = UDim2.fromOffset(18, 72),
		Size = UDim2.new(1, -184, 0, 6),
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Parent = summary,
	}, { corner("full") })
	local pfill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = A, BorderSizePixel = 0, Parent = pbar }, { corner("full") })
	local allOn = Button(summary, {
		text = "Ligar todas",
		style = "filled",
		accent = A,
		size = UDim2.fromOffset(130, 30),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -16, 0, 14),
	})
	local allOff = Button(summary, {
		text = "Restaurar",
		style = "tinted",
		accent = A,
		size = UDim2.fromOffset(130, 30),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -16, 1, -14),
	})

	-- legenda
	local legend = make("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = body,
	}, { pad(6, 0, 0, 0), list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local function legendItem(o, color, label)
		make("Frame", { LayoutOrder = o, Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color, BorderSizePixel = 0, Parent = legend }, { corner("full") })
		text({ LayoutOrder = o + 1, Text = label, TextSize = 11, TextColor3 = C.Sub, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Parent = legend })
	end
	legendItem(1, A, "Ligado = otimização aplicada")
	make("Frame", { LayoutOrder = 3, Size = UDim2.fromOffset(8, 1), BackgroundTransparency = 1, Parent = legend })
	legendItem(4, C.Off, "Desligado = visual original do jogo")

	-- busca + filtro
	local controls = make("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local searchStroke = stroke(C.Stroke, 1, 0)
	local search = make("TextBox", {
		Text = "",
		PlaceholderText = "Buscar ajuste…",
		PlaceholderColor3 = C.Dim,
		Font = F.Semi,
		TextSize = 13,
		TextColor3 = C.Text,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -228, 1, 0),
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Parent = controls,
	}, { corner(10), searchStroke, pad(14, 0, 10, 0) })
	search.Focused:Connect(function()
		tween(searchStroke, 0.2, { Color = A })
	end)
	search.FocusLost:Connect(function()
		tween(searchStroke, 0.2, { Color = C.Stroke })
	end)

	local rows, headers = {}, {}
	local filterMode = 1
	local emptyLabel

	local function filter()
		local q = string.lower(search.Text)
		local seen = {}
		local anyShown = false
		for _, r in ipairs(rows) do
			local show = (q == "" or string.find(r.search, q, 1, true) ~= nil)
			if filterMode == 2 then
				show = show and Active[r.id]
			elseif filterMode == 3 then
				show = show and not Active[r.id]
			end
			r.frame.Visible = show
			if show then
				seen[r.cat] = true
				anyShown = true
			end
		end
		for cat, h in pairs(headers) do
			h.Visible = seen[cat] == true
		end
		emptyLabel.Visible = not anyShown
	end

	Segmented(controls, {
		items = { "Todas", "Ligadas", "Desligadas" },
		accent = A,
		size = UDim2.fromOffset(216, 36),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		onChange = function(i)
			filterMode = i
			filter()
		end,
	})
	search:GetPropertyChangedSignal("Text"):Connect(filter)

	local lastCat
	for _, opt in ipairs(OPTIONS) do
		if opt.cat ~= lastCat then
			lastCat = opt.cat
			headers[opt.cat] = Section(body, nextOrder(), opt.cat, A)
		end
		local r = optionRow(body, nextOrder(), opt, A, function(v)
			State.preset = nil
			setOptions({ [opt.id] = v })
			if filterMode ~= 1 then
				task.delay(0.4, filter)
			end
		end)
		table.insert(rows, {
			frame = r.frame,
			id = opt.id,
			cat = opt.cat,
			search = string.lower(opt.title .. " " .. opt.desc),
		})
	end

	emptyLabel = text({
		LayoutOrder = nextOrder(),
		Text = "Nenhum ajuste encontrado",
		TextSize = 13,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 60),
		Visible = false,
		Parent = body,
	})

	local function setAll(v)
		local map = {}
		for _, opt in ipairs(OPTIONS) do
			map[opt.id] = v
		end
		State.preset = nil
		setOptions(map)
		if filterMode ~= 1 then
			filter()
		end
	end
	allOn.Activated:Connect(function()
		setAll(true)
		toast("Todas as otimizações ligadas", A)
	end)
	allOff.Activated:Connect(function()
		setAll(false)
		toast("Visual original restaurado", C.Sub)
	end)

	local lastN = -1
	table.insert(Refreshers, function()
		local n = countActive(OPTIONS)
		if n ~= lastN then
			lastN = n
			count.Text = n .. " de " .. #OPTIONS
			tween(pfill, 0.45, { Size = UDim2.fromScale(n / #OPTIONS, 1) })
		end
	end)
end

--------------------------------------------------------------------------
-- ABA 3 · FARM
--------------------------------------------------------------------------
do
	local tab, body = TABS[3], Bodies[3]
	local A = tab.accent
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local hero = make("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 136),
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Parent = body,
	}, { corner(16) })
	local heroStroke = stroke(C.Stroke, 1, 0)
	heroStroke.Parent = hero
	local pulse = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(22, 24),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = A,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = hero,
	}, { corner("full") })
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(22, 24),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = C.Off,
		BorderSizePixel = 0,
		Parent = hero,
	}, { corner("full") })
	local stateL = text({ Text = "Farm desligado", Font = F.Bold, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(34, 16), Size = UDim2.new(1, -200, 0, 16), Parent = hero })
	local timer = text({ Text = "00:00:00", Font = F.Heavy, TextSize = 36, TextColor3 = C.Dim, Position = UDim2.fromOffset(17, 36), Size = UDim2.new(1, -200, 0, 40), Parent = hero })
	local caption = text({ Text = "", TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(18, 82), Size = UDim2.new(1, -200, 0, 16), Parent = hero })
	text({
		Text = "Início rápido liga: Anti-AFK, Reconectar, Parar 3D, Silenciar" .. (Env.setfpscap and " e 15 FPS" or ""),
		TextSize = 11,
		TextColor3 = C.Dim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(18, 102),
		Size = UDim2.new(1, -200, 0, 28),
		Parent = hero,
	})
	local quick = Button(hero, {
		text = "Início rápido",
		style = "filled",
		accent = A,
		size = UDim2.fromOffset(150, 36),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -16, 0, 18),
	})
	local stopAll = Button(hero, {
		text = "Desligar tudo",
		style = "tinted",
		accent = A,
		size = UDim2.fromOffset(150, 36),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -16, 1, -18),
	})

	local function farmStopAll(msg)
		local map = {}
		for _, opt in ipairs(FARM_OPTIONS) do
			map[opt.id] = false
		end
		setOptions(map)
		toast(msg or "Modo farm desligado", C.Sub)
	end
	Hooks.farmStopAll = farmStopAll
	stopAll.Activated:Connect(function()
		farmStopAll()
	end)
	quick.Activated:Connect(function()
		local map = { antiafk = true, reconnect = true, render3d = true, mute = true }
		if Env.setfpscap then
			setChoice(ById.fpscap, 15)
			map.fpscap = true
		end
		setOptions(map)
		burst(hero, UDim2.new(1, -90, 0, 36), 8, 60)
		toast("Modo farm iniciado", A)
	end)

	local lastCat
	for _, opt in ipairs(FARM_OPTIONS) do
		if opt.cat ~= lastCat then
			lastCat = opt.cat
			Section(body, nextOrder(), opt.cat, A)
		end
		optionRow(body, nextOrder(), opt, A, function(v)
			setOptions({ [opt.id] = v })
		end)
	end

	local pulseTween
	local wasOn
	TabTick[3] = function()
		local on = FarmSince ~= nil
		timer.Text = formatDuration(on and (os.clock() - FarmSince) or 0)
		local n = countActive(FARM_OPTIONS)
		caption.Text = n .. " de " .. #FARM_OPTIONS .. (n == 1 and " recurso ligado" or " recursos ligados")
		if on ~= wasOn then
			wasOn = on
			stateL.Text = on and "Farm ativo" or "Farm desligado"
			tween(stateL, 0.3, { TextColor3 = on and A or C.Sub })
			tween(timer, 0.3, { TextColor3 = on and C.Text or C.Dim })
			tween(dot, 0.3, { BackgroundColor3 = on and A or C.Off })
			tween(heroStroke, 0.3, { Color = on and C.Stroke:Lerp(A, 0.5) or C.Stroke })
			tween(hero, 0.3, { BackgroundColor3 = on and C.Surface:Lerp(A, 0.06) or C.Surface })
			if on and not Prefs.reduceMotion then
				pulse.Size = UDim2.fromOffset(8, 8)
				pulse.BackgroundTransparency = 0.3
				pulseTween = TweenService:Create(pulse, TweenInfo.new(1.4, EASE.Quad, DIR.Out, -1), {
					Size = UDim2.fromOffset(24, 24),
					BackgroundTransparency = 1,
				})
				pulseTween:Play()
			elseif pulseTween then
				pulseTween:Cancel()
				pulseTween = nil
				pulse.BackgroundTransparency = 1
			end
		end
	end
	table.insert(Refreshers, TabTick[3])
end

--------------------------------------------------------------------------
-- HUD (painel flutuante)
--------------------------------------------------------------------------
local OVERLAYS = {
	{ id = "fps", label = "FPS", title = "FPS", desc = "Quadros por segundo", default = true },
	{ id = "ping", label = "PING", title = "Ping", desc = "Latência até o servidor", default = true },
	{ id = "server", label = "SERVIDOR", title = "Distância do servidor", desc = "Estimativa pela latência (o Roblox não informa a região)", default = false },
	{ id = "ram", label = "RAM", title = "Memória", desc = "Memória usada pelo Roblox", default = false },
	{ id = "frametime", label = "QUADRO", title = "Tempo de quadro", desc = "Milissegundos por quadro", default = false },
	{ id = "players", label = "JOGADORES", title = "Jogadores", desc = "Pessoas no servidor", default = false },
	{ id = "preset", label = "PRESET", title = "Preset ativo", desc = "Qual preset está aplicado", default = false },
	{ id = "clock", label = "HORA", title = "Horário", desc = "Hora local", default = false },
	{ id = "farm", label = "FARM", title = "Tempo de farm", desc = "Há quanto tempo o modo farm está ligado", default = false },
}
local OverlayOn = {}
for _, o in ipairs(OVERLAYS) do
	OverlayOn[o.id] = o.default
end
local HUD_SIZES = { 0.85, 1, 1.2 }
local HUD_HOME = UDim2.fromOffset(16, TopInset + 12)

local Hud = make("Frame", {
	Name = "Hud",
	Position = HUD_HOME,
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = C.Bg,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 2,
	Parent = Gui,
}, { corner(14), stroke(C.White, 1, 0.9), pad(14, 9, 14, 9) })
local HudLayout = list(Enum.FillDirection.Vertical, 3)
HudLayout.Parent = Hud
local HudScale = make("UIScale", { Parent = Hud })
makeDraggable(Hud, Hud, function(moved)
	if moved then
		clampInside(Hud)
		if scheduleSave then
			scheduleSave()
		end
	end
end)

local HudLabels = {}
for i, o in ipairs(OVERLAYS) do
	HudLabels[o.id] = text({
		LayoutOrder = i,
		Text = "",
		RichText = true,
		Font = F.Bold,
		TextSize = 14,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = OverlayOn[o.id],
		Parent = Hud,
	})
end

local function applyHudPrefs()
	local any = false
	for id, lbl in pairs(HudLabels) do
		lbl.Visible = OverlayOn[id]
		any = any or OverlayOn[id]
	end
	Hud.Visible = Prefs.hudVisible and any
	HudLayout.FillDirection = Prefs.hudLayout == 2 and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	HudLayout.Padding = UDim.new(0, Prefs.hudLayout == 2 and 16 or 3)
	tween(HudScale, 0.25, { Scale = HUD_SIZES[Prefs.hudSize] or 1 })
end

local Country
task.spawn(function()
	local ok, c = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer)
	end)
	if ok then
		Country = c
	end
end)

local function serverEstimate(ping)
	if not ping then
		return "medindo…", C.Dim
	end
	if Country == "BR" then
		if ping <= 80 then
			return "perto · provável BR", C.Good
		end
		if ping <= 140 then
			return "meio longe · talvez fora do BR", C.Gold
		end
		return "longe · provável fora do BR", C.Warn
	end
	if ping <= 80 then
		return "perto de você", C.Good
	end
	if ping <= 140 then
		return "distância média", C.Gold
	end
	return "longe de você", C.Warn
end

local DIM_HEX = C.Dim:ToHex()
local function hudLine(label, value, color)
	return string.format('<font color="#%s" size="11">%s</font>  <font color="#%s">%s</font>', DIM_HEX, label, (color or C.Text):ToHex(), value)
end

local function updateHud()
	local texts = {}
	local fps = math.floor(fpsValue + 0.5)
	texts.fps = hudLine("FPS", tostring(fps), fpsColor(fps))
	local ping = (OverlayOn.ping or OverlayOn.server) and getPing() or nil
	if OverlayOn.ping then
		texts.ping = hudLine("PING", ping and (math.floor(ping + 0.5) .. " ms") or "—",
			ping and (ping <= 80 and C.Good or (ping <= 150 and C.Gold or C.Warn)) or C.Dim)
	end
	if OverlayOn.server then
		local st, sc = serverEstimate(ping)
		texts.server = hudLine("SERVIDOR", st, sc)
	end
	if OverlayOn.ram then
		local okm, mem = pcall(function()
			return Stats:GetTotalMemoryUsageMb()
		end)
		texts.ram = hudLine("RAM", okm and (fmtNum(mem) .. " MB") or "—")
	end
	texts.frametime = hudLine("QUADRO", string.format("%.1f ms", frameMs))
	texts.players = hudLine("JOGADORES", #Players:GetPlayers() .. "/" .. Players.MaxPlayers)
	texts.preset = hudLine("PRESET", State.preset and State.preset.name or "nenhum", State.preset and State.preset.accent or C.Dim)
	if OverlayOn.clock then
		local okc, clock = pcall(function()
			return DateTime.now():FormatLocalTime("HH:mm", "pt-br")
		end)
		texts.clock = hudLine("HORA", okc and clock or "—")
	end
	texts.farm = hudLine("FARM", FarmSince and formatDuration(os.clock() - FarmSince) or "desligado", FarmSince and C.Peach or C.Dim)
	for id, lbl in pairs(HudLabels) do
		if lbl.Visible and texts[id] and lbl.Text ~= texts[id] then
			lbl.Text = texts[id]
		end
	end
end

--------------------------------------------------------------------------
-- ABA 4 · HUD
--------------------------------------------------------------------------
local OverlayRows = {}
local HudControls = {}
do
	local tab, body = TABS[4], Bodies[4]
	local A = tab.accent
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	Section(body, nextOrder(), "PAINEL", A)
	HudControls.visible = SwitchRow(body, nextOrder(), {
		title = "Mostrar painel",
		desc = "Liga ou esconde o painel inteiro",
		accent = A,
		initial = Prefs.hudVisible,
		onToggle = function(v)
			Prefs.hudVisible = v
			applyHudPrefs()
			updateHud()
			scheduleSave()
		end,
	})
	local layoutRow = Row(body, nextOrder(), { title = "Formato", desc = "Em lista ou numa linha só", accent = A, rightWidth = 190, pressable = false })
	HudControls.layout = Segmented(layoutRow.frame, {
		items = { "Lista", "Linha" },
		index = Prefs.hudLayout,
		accent = A,
		size = UDim2.fromOffset(160, 32),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
		onChange = function(i)
			Prefs.hudLayout = i
			applyHudPrefs()
			scheduleSave()
		end,
	})
	local sizeRow = Row(body, nextOrder(), { title = "Tamanho", desc = "Tamanho do texto no painel", accent = A, rightWidth = 150, pressable = false })
	HudControls.size = Stepper(sizeRow.frame, {
		choices = { 1, 2, 3 },
		index = Prefs.hudSize,
		fmt = function(v)
			return ({ "Pequeno", "Médio", "Grande" })[v]
		end,
		onChange = function(v)
			Prefs.hudSize = v
			applyHudPrefs()
			scheduleSave()
		end,
	}, A, 16)
	local posRow = Row(body, nextOrder(), { title = "Posição", desc = "Arraste o painel na tela para mover", accent = A, rightWidth = 130, pressable = false })
	Button(posRow.frame, {
		text = "Redefinir",
		style = "ghost",
		size = UDim2.fromOffset(104, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
	}).Activated:Connect(function()
		tween(Hud, 0.45, { Position = HUD_HOME })
		scheduleSave()
	end)

	Section(body, nextOrder(), "INFORMAÇÕES", A)
	local master
	local function syncMaster()
		local all = true
		for _, o in ipairs(OVERLAYS) do
			all = all and OverlayOn[o.id]
		end
		master.Set(all)
	end
	master = SwitchRow(body, nextOrder(), {
		title = "Selecionar tudo",
		desc = "Liga ou desliga todas as informações de uma vez",
		accent = A,
		onToggle = function(v)
			for _, o in ipairs(OVERLAYS) do
				OverlayOn[o.id] = v
				OverlayRows[o.id].Set(v)
			end
			applyHudPrefs()
			updateHud()
			scheduleSave()
		end,
	})
	for _, o in ipairs(OVERLAYS) do
		OverlayRows[o.id] = SwitchRow(body, nextOrder(), {
			title = o.title,
			desc = o.desc,
			accent = A,
			initial = OverlayOn[o.id],
			onToggle = function(v)
				OverlayOn[o.id] = v
				syncMaster()
				applyHudPrefs()
				updateHud()
				scheduleSave()
			end,
		})
	end
	syncMaster()
	HudControls.syncMaster = syncMaster
end

--------------------------------------------------------------------------
-- SALVAR / CARREGAR
--------------------------------------------------------------------------
local SAVE_FILE = "SillyOptimizer.json"
local Loading = false
local savePending = false

local function writeSave()
	if not Env.canSave then
		return
	end
	local data = { version = 2, prefs = Prefs, remember = Prefs.remember }
	if Prefs.remember then
		data.preset = State.preset and State.preset.id or nil
		data.options = {}
		for _, opt in ipairs(OPTIONS) do
			if Active[opt.id] then
				table.insert(data.options, opt.id)
			end
		end
		data.farm = {}
		for id in pairs(FarmIds) do
			data.farm[id] = Active[id] == true
		end
		data.choices = {}
		for _, l in ipairs({ OPTIONS, FARM_OPTIONS }) do
			for _, opt in ipairs(l) do
				if opt.choices then
					data.choices[opt.id] = opt.choices[opt.choiceIndex]
				end
			end
		end
		data.overlays = OverlayOn
		data.hudPos = { Hud.Position.X.Offset, Hud.Position.Y.Offset }
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if ok then
		pcall(Env.writefile, SAVE_FILE, json)
	end
end

scheduleSave = function()
	if Loading or not Env.canSave or savePending then
		return
	end
	savePending = true
	task.delay(0.5, function()
		savePending = false
		if not Destroyed then
			writeSave()
		end
	end)
end

local function loadSave()
	if not Env.canSave then
		return
	end
	local okF, exists = pcall(Env.isfile, SAVE_FILE)
	if not okF or not exists then
		return
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(Env.readfile(SAVE_FILE))
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	Loading = true
	if type(data.prefs) == "table" then
		for k, v in pairs(data.prefs) do
			if Prefs[k] ~= nil and type(v) == type(Prefs[k]) then
				Prefs[k] = v
			end
		end
	end
	if data.remember == true then
		Prefs.remember = true
	end
	if Prefs.remember then
		if type(data.choices) == "table" then
			for _, l in ipairs({ OPTIONS, FARM_OPTIONS }) do
				for _, opt in ipairs(l) do
					local v = opt.choices and data.choices[opt.id]
					if v ~= nil then
						setChoice(opt, v)
					end
				end
			end
		end
		if type(data.overlays) == "table" then
			for id, v in pairs(data.overlays) do
				if OverlayOn[id] ~= nil then
					OverlayOn[id] = v == true
					OverlayRows[id].Set(v == true)
				end
			end
			HudControls.syncMaster()
		end
		if type(data.hudPos) == "table" and type(data.hudPos[1]) == "number" and type(data.hudPos[2]) == "number" then
			Hud.Position = UDim2.fromOffset(data.hudPos[1], data.hudPos[2])
		end
		local preset
		for _, p in ipairs(PRESETS) do
			if p.id == data.preset then
				preset = p
			end
		end
		if preset then
			local keepQuality = data.choices and data.choices.quality
			applyPreset(preset)
			if keepQuality then
				setChoice(ById.quality, keepQuality)
			end
		elseif type(data.options) == "table" then
			local map = {}
			for _, id in ipairs(data.options) do
				if ById[id] and not FarmIds[id] then
					map[id] = true
				end
			end
			setOptions(map)
		end
		if type(data.farm) == "table" then
			local map = {}
			for id, v in pairs(data.farm) do
				if FarmIds[id] and v == true and not (id == "fpscap" and not Env.setfpscap) then
					map[id] = true
				end
			end
			setOptions(map)
		end
	end
	Loading = false
end

--------------------------------------------------------------------------
-- ABRIR / FECHAR + BOTÃO FLUTUANTE
--------------------------------------------------------------------------
local isOpen = false
local openSerial = 0

local function fitWindow()
	local vp = viewportSize()
	local s = math.min(1, (vp.X - 24) / WIN_W, (vp.Y - 24) / WIN_H)
	FitScale.Scale = math.max(0.45, s)
end

local Fab = make("Frame", {
	Name = "Fab",
	Size = UDim2.fromOffset(56, 56),
	Position = UDim2.new(1, -76, 0.5, -28),
	BackgroundTransparency = 1,
	ZIndex = 6,
	Parent = Gui,
})
local FabPop = make("UIScale", { Scale = 0, Parent = Fab })
local FabUI = {}
FabUI.ring = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Salmon,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = Fab,
}, { corner("full") })
local FabBtn = make("TextButton", {
	Text = "",
	AutoButtonColor = false,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Bg,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	Parent = Fab,
}, { corner("full") })
FabUI.stroke = stroke(C.White, 2, 0.1)
FabUI.stroke.Parent = FabBtn
FabUI.grad = make("UIGradient", { Rotation = 45, Color = BRAND, Parent = FabUI.stroke })
FabUI.mark = sparkleShape(FabBtn, 26, C.Salmon:Lerp(C.White, 0.3))
FabUI.mark.Position = UDim2.fromScale(0.5, 0.5)
FabUI.mini = sparkleShape(FabBtn, 10, C.Gold)
FabUI.mini.Position = UDim2.new(0.5, 11, 0.5, -11)
FabUI.press = make("UIScale", { Parent = FabBtn })

FabBtn.MouseEnter:Connect(function()
	tween(FabUI.press, 0.2, { Scale = 1.06 })
end)
FabBtn.MouseLeave:Connect(function()
	tween(FabUI.press, 0.25, { Scale = 1 })
end)
FabBtn.InputBegan:Connect(function(i)
	if isPress(i) then
		tween(FabUI.press, 0.1, { Scale = 0.9 }, EASE.Quad)
	end
end)
FabBtn.InputEnded:Connect(function(i)
	if isPress(i) then
		tween(FabUI.press, 0.45, { Scale = 1 }, EASE.Back)
	end
end)

local function fabRipple()
	if Prefs.reduceMotion then
		return
	end
	FabUI.ring.Size = UDim2.fromScale(1, 1)
	FabUI.ring.BackgroundTransparency = 0.55
	TweenService:Create(FabUI.ring, TweenInfo.new(0.6, EASE.Quad), { Size = UDim2.fromScale(1.9, 1.9), BackgroundTransparency = 1 }):Play()
end

local function setOpen(v)
	if v == isOpen or Destroyed then
		return
	end
	isOpen = v
	openSerial += 1
	local my = openSerial
	fabRipple()
	tween(FabUI.mark, 0.5, { Rotation = v and 135 or 0 }, EASE.Back)
	tween(FabUI.grad, 0.6, { Rotation = v and 225 or 45 })
	FabUI.mini.Visible = not v
	if v then
		fitWindow()
		if not Root.Visible then
			AnimScale.Scale = 0.92
			Holder.Position = UDim2.fromOffset(0, 16)
		end
		Root.Visible = true
		tween(AnimScale, 0.5, { Scale = 1 }, EASE.Back)
		tween(Holder, 0.45, { Position = UDim2.new() })
		tween(Window, 0.28, { GroupTransparency = 0 }, EASE.Quad)
		for _, s in ipairs(Shadows) do
			tween(s.frame, 0.35, { BackgroundTransparency = s.shown })
		end
		if Hooks.changed then
			Hooks.changed()
		end
		if TabTick[CurrentTab] then
			TabTick[CurrentTab]()
		end
		task.delay(0.05, function()
			clampInside(Root, 80)
		end)
	else
		tween(AnimScale, 0.2, { Scale = 0.95 }, EASE.Quad, DIR.In)
		tween(Holder, 0.2, { Position = UDim2.fromOffset(0, 10) }, EASE.Quad, DIR.In)
		tween(Window, 0.18, { GroupTransparency = 1 }, EASE.Quad)
		for _, s in ipairs(Shadows) do
			tween(s.frame, 0.18, { BackgroundTransparency = 1 })
		end
		task.delay(Prefs.reduceMotion and 0 or 0.21, function()
			if openSerial == my and not isOpen and not Destroyed then
				Root.Visible = false
			end
		end)
	end
end

CloseBtn.Activated:Connect(function()
	setOpen(false)
end)

local function snapFab()
	local vp = viewportSize()
	local rel = Fab.AbsolutePosition - Gui.AbsolutePosition
	local size = Fab.AbsoluteSize
	local x = (rel.X + size.X / 2) < vp.X / 2 and 14 or (vp.X - size.X - 14)
	local y = math.clamp(rel.Y, TopInset + 8, math.max(TopInset + 8, vp.Y - size.Y - 14))
	tween(Fab, 0.5, { Position = UDim2.fromOffset(x, y) }, EASE.Back)
end

makeDraggable(FabBtn, Fab, function(moved)
	if moved then
		snapFab()
	else
		setOpen(not isOpen)
	end
end)
makeDraggable(DragStrip, Root, function(moved)
	if moved then
		clampInside(Root, 80)
	end
end)
makeDraggable(Brand, Root, function(moved)
	if moved then
		clampInside(Root, 80)
	end
end)

track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local ok, key = pcall(function()
		return Enum.KeyCode[Prefs.keybind]
	end)
	if ok and input.KeyCode == key then
		setOpen(not isOpen)
	end
end))

track(Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	fitWindow()
	task.defer(function()
		if Root.Visible then
			clampInside(Root, 80)
		end
		clampInside(Hud)
		snapFab()
	end)
end))

--------------------------------------------------------------------------
-- ABA 5 · CONFIGURAÇÕES
--------------------------------------------------------------------------
local ConfigRows = {}
do
	local tab, body = TABS[5], Bodies[5]
	local A = tab.accent
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	Section(body, nextOrder(), "GERAL", A)
	ConfigRows.remember = SwitchRow(body, nextOrder(), {
		title = "Lembrar minhas escolhas",
		desc = Env.canSave and "Reaplica presets, ajustes, farm e HUD ao executar de novo"
			or "Indisponível: precisa de executor (writefile)",
		accent = A,
		initial = Prefs.remember,
		locked = not Env.canSave,
		onLocked = function()
			toast("Precisa de executor com writefile", C.Warn)
		end,
		onToggle = function(v)
			Prefs.remember = v
			scheduleSave()
			toast(v and "Suas escolhas serão lembradas" or "Escolhas não serão mais lembradas", v and A or C.Sub)
		end,
	})
	ConfigRows.openOnStart = SwitchRow(body, nextOrder(), {
		title = "Abrir o menu ao iniciar",
		desc = "Mostra esta janela logo depois do carregamento",
		accent = A,
		initial = Prefs.openOnStart,
		onToggle = function(v)
			Prefs.openOnStart = v
			scheduleSave()
		end,
	})
	ConfigRows.reduceMotion = SwitchRow(body, nextOrder(), {
		title = "Reduzir animações",
		desc = "Troca transições por mudanças instantâneas",
		accent = A,
		initial = Prefs.reduceMotion,
		onToggle = function(v)
			Prefs.reduceMotion = v
			scheduleSave()
		end,
	})
	local keyRow = Row(body, nextOrder(), {
		title = "Atalho do teclado",
		desc = Env.touch and "No celular, use o botão flutuante" or "Tecla que abre e fecha o menu",
		accent = A,
		rightWidth = 160,
		pressable = false,
	})
	local keyIndex = table.find(KEY_LIST, Prefs.keybind) or 1
	ConfigRows.key = Stepper(keyRow.frame, {
		choices = KEY_LIST,
		index = keyIndex,
		width = 132,
		fmt = function(v)
			return KEY_NAMES[v] or v
		end,
		onChange = function(v)
			Prefs.keybind = v
			refreshKeyCap()
			scheduleSave()
		end,
	}, A, 16)

	Section(body, nextOrder(), "COMPATIBILIDADE", A)
	local function infoRow(title, desc, ok, label)
		local r = Row(body, nextOrder(), { title = title, desc = desc, accent = A, rightWidth = 150, pressable = false })
		Pill(r.frame, label or (ok and "Disponível" or "Indisponível"), ok and C.Good or C.Dim, 16)
	end
	local envName = Env.studio and "Roblox Studio" or Env.executor or ((Env.setfpscap or Env.writefile) and "Executor" or "Cliente")
	infoRow("Ambiente", "Onde o Silly Optimizer está rodando", true, envName)
	infoRow("Limitar FPS", "Função setfpscap do executor", Env.setfpscap ~= nil)
	infoRow("Salvar escolhas", "Funções writefile e readfile", Env.canSave)
	infoRow("Interface protegida", "gethui esconde o menu de outros scripts", Env.gethui ~= nil)

	Section(body, nextOrder(), "SISTEMA", A)
	local resetRow = Row(body, nextOrder(), {
		title = "Restaurar tudo",
		desc = "Desliga presets, ajustes e modo farm",
		accent = A,
		rightWidth = 140,
		pressable = false,
	})
	Button(resetRow.frame, {
		text = "Restaurar",
		style = "ghost",
		size = UDim2.fromOffset(110, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
	}).Activated:Connect(function()
		local map = {}
		for _, l in ipairs({ OPTIONS, FARM_OPTIONS }) do
			for _, opt in ipairs(l) do
				map[opt.id] = false
			end
		end
		State.preset = nil
		setOptions(map)
		toast("Tudo restaurado", C.Sub)
	end)
	local closeRow = Row(body, nextOrder(), {
		title = "Fechar o Silly Optimizer",
		desc = "Devolve tudo ao normal e remove o menu da tela",
		accent = C.Warn,
		rightWidth = 140,
		pressable = false,
	})
	local confirmArmed = 0
	local closeBtn = Button(closeRow.frame, {
		text = "Fechar",
		style = "danger",
		size = UDim2.fromOffset(110, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
	})
	closeBtn.Activated:Connect(function()
		if confirmArmed > 0 then
			if destroyAll then
				destroyAll()
			end
			return
		end
		confirmArmed += 1
		local my = confirmArmed
		closeBtn.SetStyle("dangerFilled", "Confirmar")
		task.delay(3, function()
			if confirmArmed == my and not Destroyed then
				confirmArmed = 0
				closeBtn.SetStyle("danger", "Fechar")
			end
		end)
	end)

	text({
		LayoutOrder = nextOrder(),
		Text = "Silly Optimizer v" .. VERSION .. " · leve no celular e no PC",
		TextSize = 11,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = body,
	})
end

local function applyPrefsToUI()
	ConfigRows.remember.Set(Prefs.remember)
	ConfigRows.openOnStart.Set(Prefs.openOnStart)
	ConfigRows.reduceMotion.Set(Prefs.reduceMotion)
	ConfigRows.key.Set(table.find(KEY_LIST, Prefs.keybind) or 1, true)
	HudControls.visible.Set(Prefs.hudVisible)
	HudControls.layout.Set(Prefs.hudLayout, true)
	HudControls.size.Set(Prefs.hudSize, true)
	refreshKeyCap()
	applyHudPrefs()
end

--------------------------------------------------------------------------
-- ATUALIZAÇÃO GERAL
--------------------------------------------------------------------------
local function refreshBadges()
	local nOpt = countActive(OPTIONS)
	local nFarm = countActive(FARM_OPTIONS)
	local values = {
		State.preset and State.preset.name or "",
		nOpt > 0 and tostring(nOpt) or "",
		nFarm > 0 and "ON" or "",
		"",
		"",
	}
	for i, t in ipairs(TabUI) do
		local v = values[i]
		if t.badgeText.Text ~= v then
			t.badgeText.Text = v
		end
		t.badge.Visible = v ~= ""
	end
end

Hooks.changed = function()
	if Destroyed then
		return
	end
	syncRows()
	refreshBadges()
	for _, f in ipairs(Refreshers) do
		f()
	end
	scheduleSave()
end

local function Tick()
	if Destroyed then
		return
	end
	if Hud.Visible then
		updateHud()
	end
	if isOpen then
		syncRows()
		if TabTick[CurrentTab] then
			TabTick[CurrentTab]()
		end
	end
end

do
	local acc, frames = 0, 0
	track(RunService.RenderStepped:Connect(function(dt)
		acc += dt
		frames += 1
		if acc >= 0.5 then
			fpsValue = frames / acc
			frameMs = acc / frames * 1000
			acc, frames = 0, 0
			table.insert(FpsHistory, fpsValue)
			if #FpsHistory > HIST then
				table.remove(FpsHistory, 1)
			end
			Tick()
		end
	end))
end

--------------------------------------------------------------------------
-- LIMPEZA
--------------------------------------------------------------------------
local CleanedUp = false
destroyAll = function()
	if CleanedUp then
		return
	end
	CleanedUp = true
	Destroyed = true
	for _, c in ipairs(Connections) do
		c:Disconnect()
	end
	table.clear(Connections)
	for _, l in ipairs({ OPTIONS, FARM_OPTIONS }) do
		for _, opt in ipairs(l) do
			clearWatchers(opt.id)
			if Active[opt.id] then
				Active[opt.id] = false
				if opt.custom then
					pcall(opt.custom.off)
				end
			end
			restore(opt, true)
		end
	end
	if BlackGui then
		BlackGui:Destroy()
		BlackGui = nil
	end
	Gui:Destroy()
	if type(_G.__SillyOptimizer) == "table" and _G.__SillyOptimizer.owner == Gui then
		_G.__SillyOptimizer = nil
	end
end

if Destroyed then
	-- outra execução pediu para fechar enquanto esta carregava
	destroyAll()
	return
end
_G.__SillyOptimizer = { Destroy = destroyAll, owner = Gui }

--------------------------------------------------------------------------
-- INÍCIO
--------------------------------------------------------------------------
Splash.step("Montando interface", 0.72)
selectTab(1, true)
Splash.step("Carregando preferências", 0.88)
loadSave()
applyPrefsToUI()
Hooks.changed()
updateHud()
Splash.finish()

if not Destroyed then
	task.wait(0.15)
	fitWindow()
	TweenService:Create(FabPop, TweenInfo.new(0.55, EASE.Back), { Scale = 1 }):Play()
	task.delay(0.3, fabRipple)
	if Prefs.openOnStart then
		task.delay(0.1, function()
			setOpen(true)
		end)
	end
	local hint = Env.touch and "toque no botão flutuante para abrir" or ((KEY_NAMES[Prefs.keybind] or Prefs.keybind) .. " abre o menu")
	toast("Silly Optimizer pronto · " .. hint, C.Salmon)
end
