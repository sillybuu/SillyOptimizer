--[[
	Silly Optimizer  ·  v6.1
	FPS booster e utilitários para Roblox (Luau) — celular e PC

	Como usar
	  • Executor: loadstring(game:HttpGet("link raw do GitHub"))()
	  • Roblox Studio: LocalScript em StarterPlayer > StarterPlayerScripts.
	  • Botão flutuante: toque abre/fecha · arraste move · segure tira print limpa
	  • Engrenagem do botão: perfis, tamanho e opacidade do botão, presets visíveis.

	Abas
	  Home · Presets · Ajustes · Farm · Server · Visual · Áudio · Proteção · HUD · Configurações

	Tudo é local (só no seu aparelho) e pode ser desfeito. Recursos de executor
	(setfpscap, writefile, HttpGet, setclipboard, gethui) ficam marcados como
	indisponíveis quando não existem.
]]

local SillyAbort -- limpa esta execução se o carregamento falhar
local function SillyMain()

local VERSION = "6.1"

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

if not game:IsLoaded() then
	game.Loaded:Wait()
end
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	task.wait(0.1)
	LocalPlayer = Players.LocalPlayer
end

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
	delfile = asFn(delfile),
	setclipboard = asFn(setclipboard) or asFn(toclipboard),
	studio = RunService:IsStudio(),
	touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
}
Env.canSave = Env.writefile ~= nil and Env.readfile ~= nil and Env.isfile ~= nil
-- celular: sem CanvasGroup (no mobile eles podem não aparecer quando a memória de vídeo aperta)
Env.lite = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
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
	Butter = rgb(250, 220, 146),
	Rose = rgb(246, 164, 192),
	Blush = rgb(255, 200, 214),
	Terra = rgb(236, 166, 136),
	Coral = rgb(255, 178, 168),

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
	lang = "pt", -- "pt" | "en"
	notify = true,
	fabSize = 2, -- 1 pequeno, 2 médio, 3 grande
	fabAlpha = 1, -- 1 = 100%, 2 = 80%, 3 = 60%, 4 = 40%
	shotMode = 1, -- 1 = normal, 2 = cinema
	shotHold = 3, -- índice em SHOT_HOLDS (5 s)
	hiddenPresets = {},
	lastVersion = "",
}

-- leitura antecipada do arquivo salvo (idioma e preferências valem já na montagem)
local SAVE_FILE = "SillyOptimizer.json"
local SaveData
if Env.canSave then
	local okF, exists = pcall(Env.isfile, SAVE_FILE)
	if okF and exists then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(Env.readfile(SAVE_FILE))
		end)
		if ok and type(data) == "table" then
			SaveData = data
		end
	end
end
if SaveData and type(SaveData.prefs) == "table" then
	for k, v in pairs(SaveData.prefs) do
		if Prefs[k] ~= nil and type(v) == type(Prefs[k]) then
			Prefs[k] = v
		end
	end
end
if SaveData and SaveData.remember == true then
	Prefs.remember = true -- compatível com o arquivo da v4
end

-- tradução: o texto em português é a chave; sem tradução, fica em português
local EN = { -- EN_DICT
	["Preparando…"] = "Getting ready…",
	["Tudo pronto"] = "All set",
	["Carregando tema e fontes"] = "Loading theme and fonts",
	["Lendo iluminação e terreno"] = "Reading lighting and terrain",
	["Mapeando o mundo"] = "Mapping the world",
	["objetos"] = "objects",
	["Montando interface"] = "Building interface",
	["Carregando preferências"] = "Loading preferences",
	["Nível"] = "Level",
	["ILUMINAÇÃO"] = "LIGHTING",
	["Remover sombras globais"] = "Remove global shadows",
	["Desliga as sombras do sol em todo o mapa"] = "Turns off sun shadows across the map",
	["Remover neblina"] = "Remove fog",
	["Deixa a distância limpa, sem névoa"] = "Clear view into the distance",
	["Remover reflexo do céu"] = "Remove sky reflections",
	["Zera o brilho do ambiente refletido nas superfícies"] = "Removes environment shine on surfaces",
	["Desligar luzes dinâmicas"] = "Turn off dynamic lights",
	["Point, Spot e Surface lights"] = "Point, Spot and Surface lights",
	["Limpar atmosfera"] = "Clear atmosphere",
	["Zera densidade, névoa e brilho da atmosfera"] = "Removes atmosphere density, haze and glare",
	["EFEITOS"] = "EFFECTS",
	["Desligar pós-processamento"] = "Turn off post-processing",
	["Bloom, blur, raios de sol, cor e profundidade"] = "Bloom, blur, sun rays, color and depth",
	["Desligar partículas"] = "Turn off particles",
	["Emissores de partícula, trilhas e feixes"] = "Particle emitters, trails and beams",
	["Desligar fogo e fumaça"] = "Turn off fire and smoke",
	["Fire, Smoke, Sparkles, explosões e escudos"] = "Fire, Smoke, Sparkles, explosions and shields",
	["Esconder sol, lua e estrelas"] = "Hide sun, moon and stars",
	["Remove os corpos celestes do céu"] = "Removes celestial bodies from the sky",
	["ÁGUA E TERRENO"] = "WATER AND TERRAIN",
	["Parar ondas da água"] = "Stop water waves",
	["Zera tamanho e velocidade das ondas"] = "Sets wave size and speed to zero",
	["Remover reflexo da água"] = "Remove water reflections",
	["A água para de refletir o mundo"] = "Water stops reflecting the world",
	["Remover grama do terreno"] = "Remove terrain grass",
	["Tira a grama animada e detalhes do chão"] = "Removes animated grass and ground details",
	["OBJETOS"] = "OBJECTS",
	["Tirar sombra dos objetos"] = "Remove object shadows",
	["Cada parte para de projetar sombra"] = "Parts stop casting shadows",
	["Materiais lisos"] = "Smooth materials",
	["Troca todos os materiais por plástico liso"] = "Turns every material into smooth plastic",
	["Esconder texturas e decals"] = "Hide textures and decals",
	["Preserva o rosto dos personagens"] = "Keeps character faces",
	["Simplificar malhas"] = "Simplify meshes",
	["MeshParts em modo de desempenho"] = "MeshParts in performance mode",
	["Tirar brilho dos objetos"] = "Remove object shine",
	["Zera o reflexo de todas as partes"] = "Removes reflectance from all parts",
	["SISTEMA"] = "SYSTEM",
	["Reduzir qualidade gráfica"] = "Lower graphics quality",
	["Nível 1 é o mais leve. O preset escolhe o nível"] = "Level 1 is the lightest. Presets pick the level",
	["Sem permissão neste ambiente"] = "No permission here",
	["Pausar animações dos outros"] = "Pause other players' animations",
	["Personagens alheios ficam parados (volta ao se mexerem)"] = "Other characters freeze (they resume when they move)",
	["Ativo"] = "On",
	["personagem"] = "character",
	["personagens"] = "characters",
	["Remover eco do som"] = "Remove sound echo",
	["Desliga o reverb global do ambiente"] = "Turns off global ambient reverb",
	["DESEMPENHO"] = "PERFORMANCE",
	["Distância de renderização"] = "Render distance",
	["Esconde o que está longe da câmera (só para você)"] = "Hides what is far from the camera (only for you)",
	["objetos escondidos"] = "objects hidden",
	["Esconder acessórios dos outros"] = "Hide other players' accessories",
	["Chapéus, cabelos e asas pesados somem (só para você)"] = "Heavy hats, hair and wings disappear (only for you)",
	["peças escondidas"] = "pieces hidden",
	["FPS desbloqueado"] = "Unlocked FPS",
	["Libera mais de 60 FPS em telas rápidas"] = "Allows more than 60 FPS on fast screens",
	["Indisponível: precisa de executor (setfpscap)"] = "Unavailable: needs an executor (setfpscap)",
	["Sem limite"] = "Unlimited",
	["Pausado: o Limitar FPS do Farm está ligado"] = "Paused: Farm's FPS limit is on",
	["sem limite"] = "unlimited",
	["Desligado"] = "Off",
	["Competitivo"] = "Competitive",
	["Cinema"] = "Cinema",
	["Voz clara"] = "Clear voice",
	["Graves"] = "Bass",
	["Modo farm ativo · toque no botão flutuante para abrir o menu"] = "Farm mode on · tap the floating button to open the menu",
	["Tempo de farm encerrado"] = "Farm time is over",
	["PROTEÇÃO"] = "PROTECTION",
	["Anti-AFK"] = "Anti-AFK",
	["Evita o kick do Roblox depois de ~20 min parado"] = "Avoids Roblox's kick after ~20 min idle",
	["Ativo · protegido contra kick por inatividade"] = "On · protected from idle kick",
	["ATIVIDADE"] = "ACTIVITY",
	["Pulinho periódico"] = "Periodic jump",
	["Para jogos com AFK próprio"] = "For games with their own AFK check",
	["Ativo · próximo pulo em"] = "On · next jump in",
	["Reconectar sozinho"] = "Auto reconnect",
	["Volta ao jogo (servidor novo) se cair ou for kickado"] = "Rejoins (new server) if you disconnect or get kicked",
	["Reconectando…"] = "Reconnecting…",
	["Ativo · vigiando a conexão"] = "On · watching the connection",
	["BATERIA E CALOR"] = "BATTERY AND HEAT",
	["Parar renderização 3D"] = "Stop 3D rendering",
	["Para de desenhar o mundo: menos GPU e calor"] = "Stops drawing the world: less GPU and heat",
	["Ativo · mundo pausado"] = "On · world paused",
	["Tela preta"] = "Black screen",
	["Cobre tudo de preto (economiza em tela OLED)"] = "Covers everything in black (saves OLED battery)",
	["Limitar FPS"] = "Limit FPS",
	["Menos quadros = menos esforço do aparelho"] = "Fewer frames = less work for your device",
	["Ativo · limite de"] = "On · limit of",
	["Silenciar sons"] = "Mute sounds",
	["Zera o volume dos sons do jogo"] = "Sets every game sound to zero",
	["sons"] = "sounds",
	["som"] = "sound",
	["Esconder outros jogadores"] = "Hide other players",
	["Personagens e nomes somem (só para você)"] = "Characters and names disappear (only for you)",
	["jogador oculto"] = "player hidden",
	["jogadores ocultos"] = "players hidden",
	["Esconder telas do jogo"] = "Hide game screens",
	["Desliga as interfaces do próprio jogo"] = "Turns off the game's own interfaces",
	["tela oculta"] = "screen hidden",
	["telas ocultas"] = "screens hidden",
	["Esconder menus do Roblox"] = "Hide Roblox menus",
	["Chat, lista de jogadores, mochila, emotes e vida"] = "Chat, player list, backpack, emotes and health",
	["AUTOMÁTICO"] = "AUTOMATIC",
	["Desligar tudo depois de"] = "Turn everything off after",
	["Encerra o modo farm sozinho"] = "Ends farm mode by itself",
	["Ativo · desliga em"] = "On · turns off in",
	["Manhã"] = "Morning",
	["Dia"] = "Day",
	["Tarde"] = "Afternoon",
	["Pôr do sol"] = "Sunset",
	["Noite"] = "Night",
	["Padrão do Roblox"] = "Roblox default",
	["Limpo"] = "Clear",
	["Entardecer"] = "Dusk",
	["Rosa"] = "Pink",
	["Noite azul"] = "Blue night",
	["Suave"] = "Soft",
	["Vibrante"] = "Vibrant",
	["Neon"] = "Neon",
	["Retrô"] = "Retro",
	["Salmão"] = "Salmon",
	["Pêssego"] = "Peach",
	["Amarelo"] = "Yellow",
	["Branco"] = "White",
	["AMBIENTE"] = "ENVIRONMENT",
	["Horário do dia"] = "Time of day",
	["Troca o horário só para você"] = "Changes the time only for you",
	["Tudo iluminado, sem cantos escuros"] = "Everything lit, no dark corners",
	["Trocar o céu"] = "Change the sky",
	["Tira o céu do jogo e aplica um estilo"] = "Replaces the game's sky with a style",
	["Cor, brilho e raios de sol mais bonitos (pesa no FPS)"] = "Nicer color, glow and sun rays (costs FPS)",
	["CÂMERA"] = "CAMERA",
	["Campo de visão (FOV)"] = "Field of view (FOV)",
	["Pode atrapalhar a mira com zoom de alguns jogos"] = "May interfere with scoped aiming in some games",
	["Câmera sem colisão"] = "No-clip camera",
	["Paredes ficam transparentes em vez de empurrar a câmera"] = "Walls turn see-through instead of pushing the camera",
	["Este jogo controla a câmera"] = "This game controls the camera",
	["Zoom máximo maior"] = "Bigger max zoom",
	["Deixa afastar mais a câmera"] = "Lets you pull the camera further out",
	["JOGADORES"] = "PLAYERS",
	["Destaque de jogadores"] = "Player highlight",
	["Só aparece em quem você já enxerga (não atravessa paredes)"] = "Only on players you can already see (not through walls)",
	["Contorno"] = "Outline",
	["Preenchido"] = "Filled",
	["Anti-fling"] = "Anti-fling",
	["Ninguém consegue te arremessar encostando em você"] = "Nobody can fling you by touching you",
	["arremessos bloqueados"] = "flings blocked",
	["Anti-lag de efeitos"] = "Effect anti-lag",
	["Limita partículas e feixes exagerados (inclusive dos outros)"] = "Limits excessive particles and beams (including others')",
	["efeito limitado"] = "effect limited",
	["efeitos limitados"] = "effects limited",
	["PRIVACIDADE"] = "PRIVACY",
	["Modo streamer"] = "Streamer mode",
	["Esconde nomes, a lista de jogadores e o ID do servidor"] = "Hides names, the player list and the server ID",
	["Indisponível neste ambiente"] = "Unavailable here",
	["Aplicando…"] = "Applying…",
	["Sem efeito neste jogo"] = "No effect in this game",
	["Ativo · nada disso neste mapa"] = "On · none of this in this map",
	["objeto"] = "object",
	["bloqueados"] = "blocked",
	["luz"] = "light",
	["luzes"] = "lights",
	["efeito"] = "effect",
	["efeitos"] = "effects",
	["textura"] = "texture",
	["texturas"] = "textures",
	["malha"] = "mesh",
	["malhas"] = "meshes",
	["Mantém o visual bonito. Tira neblina, pós-processamento, água animada e sombras globais."] = "Keeps it pretty. Removes fog, post-processing, animated water and global shadows.",
	["Equilíbrio entre visual e FPS. Soma partículas, fogo, grama e sombra dos objetos."] = "Balance between looks and FPS. Adds particles, fire, grass and object shadows.",
	["FPS alto. Remove luzes, atmosfera e céu, deixa materiais lisos e malhas simples."] = "High FPS. Removes lights, atmosphere and sky, smooth materials and simple meshes.",
	["Tudo no mínimo. Visual bem simples, feito para aparelho fraco."] = "Everything at minimum. Very simple look, made for weak devices.",
	["Olá!"] = "Hi!",
	["Olá"] = "Hi",
	["Seu resumo: conta, servidor, desempenho e amigos"] = "Your summary: account, server, performance and friends",
	["Desempenho em um toque"] = "Performance in one tap",
	["Escolha um nível ou deixe o benchmark decidir"] = "Pick a level or let the benchmark decide",
	["Ajustes"] = "Tweaks",
	["AJUSTES"] = "TWEAKS",
	["Ajustes individuais"] = "Individual tweaks",
	["Ligado = otimização aplicada · Desligado = visual original"] = "On = optimization applied · Off = original look",
	["MODO FARM"] = "FARM MODE",
	["Deixe rodando leve"] = "Keep it running light",
	["Fique no jogo gastando o mínimo de bateria e calor"] = "Stay in game using as little battery and heat as possible",
	["Servidor"] = "Server",
	["Reentre, ache um servidor melhor ou chame amigos"] = "Rejoin, find a better server or invite friends",
	["Deixe do seu jeito"] = "Make it yours",
	["Horário, céu, shaders, câmera, destaque e print limpa"] = "Time, sky, shaders, camera, highlight and clean screenshot",
	["Áudio"] = "Audio",
	["ÁUDIO"] = "AUDIO",
	["Ouça o que importa"] = "Hear what matters",
	["Mixer, realce de passos e combate, equalizador e voice"] = "Mixer, footstep and combat boost, equalizer and voice",
	["Proteção"] = "Protection",
	["Jogue tranquilo"] = "Play worry-free",
	["Anti-fling, anti-AFK, reconexão e privacidade"] = "Anti-fling, anti-AFK, reconnect and privacy",
	["Informações na tela"] = "On-screen info",
	["Escolha o que aparece no painel flutuante"] = "Choose what shows on the floating panel",
	["Configurações"] = "Settings",
	["CONFIGURAÇÕES"] = "SETTINGS",
	["Preferências"] = "Preferences",
	["Idioma, notificações, salvamento e compatibilidade"] = "Language, notifications, saving and compatibility",
	["Shift direito"] = "Right Shift",
	["Ctrl direito"] = "Right Ctrl",
	["abre e fecha"] = "opens and closes",
	["Botão flutuante"] = "Floating button",
	["Precisa de executor com setfpscap"] = "Needs an executor with setfpscap",
	["DESEMPENHO AGORA"] = "PERFORMANCE NOW",
	["otimização ativa"] = "optimization on",
	["otimizações ativas"] = "optimizations on",
	["FEITO PARA ESTE JOGO"] = "MADE FOR THIS GAME",
	["O benchmark testa o que pesa aqui e monta dois presets: Competitivo (visão limpa) e Desempenho (mais FPS). Texturas e materiais ficam com você."] = "The benchmark tests what is heavy here and builds two presets: Competitive (clean view) and Performance (more FPS). Textures and materials are up to you.",
	["Original"] = "Original",
	["Desempenho"] = "Performance",
	["Iniciar benchmark"] = "Start benchmark",
	["Salvar ajustes atuais"] = "Save current tweaks",
	["Cancelar"] = "Cancel",
	["Ao entrar neste jogo"] = "When joining this game",
	["Nada"] = "Nothing",
	["Meu preset"] = "My preset",
	["Salve um preset para este jogo primeiro"] = "Save a preset for this game first",
	["Rode o benchmark primeiro"] = "Run the benchmark first",
	["Será aplicado sozinho quando você entrar neste jogo"] = "It will apply automatically when you join this game",
	["Preset"] = "Preset",
	["aplicado"] = "applied",
	["Preset salvo para este jogo"] = "Preset saved for this game",
	["Sombras"] = "Shadows",
	["Pós-processamento"] = "Post-processing",
	["Partículas e fogo"] = "Particles and fire",
	["Luzes e atmosfera"] = "Lights and atmosphere",
	["Água e grama"] = "Water and grass",
	["Malhas e brilho"] = "Meshes and shine",
	["Qualidade gráfica"] = "Graphics quality",
	["Medindo o jogo original"] = "Measuring the original game",
	["Testando"] = "Testing",
	["Medindo o preset Competitivo"] = "Measuring the Competitive preset",
	["Medindo o preset Desempenho"] = "Measuring the Performance preset",
	["Benchmark pronto · o jogo já estava no limite de FPS, a escolha usou a quantidade de efeitos"] = "Benchmark done · the game was already at the FPS cap, so effect counts decided",
	["Benchmark pronto · toque num resultado para aplicar"] = "Benchmark done · tap a result to apply it",
	["Cancelando…"] = "Cancelling…",
	["Este jogo"] = "This game",
	["ESCOLHA UM NÍVEL"] = "PICK A LEVEL",
	["ATIVO"] = "ON",
	["Aplicar"] = "Apply",
	["Preset desfeito · visual original de volta"] = "Preset undone · original look is back",
	["Desfazer preset"] = "Undo preset",
	["Restaurar padrão"] = "Restore default",
	["Desliga todos os ajustes e devolve o visual original"] = "Turns off every tweak and restores the original look",
	["Restaurar"] = "Restore",
	["Visual original restaurado"] = "Original look restored",
	["Tudo acontece só no seu aparelho e pode ser desfeito a qualquer momento."] = "Everything happens only on your device and can be undone at any time.",
	["ajustes"] = "tweaks",
	["ajuste"] = "tweak",
	["qualidade"] = "quality",
	["de"] = "of",
	["OTIMIZAÇÕES ATIVAS"] = "ACTIVE OPTIMIZATIONS",
	["Ligar todas"] = "Turn all on",
	["Ligado = otimização aplicada"] = "On = optimization applied",
	["Desligado = visual original do jogo"] = "Off = the game's original look",
	["Buscar ajuste…"] = "Search tweaks…",
	["Todas"] = "All",
	["Ligadas"] = "On",
	["Desligadas"] = "Off",
	["MEMÓRIA"] = "MEMORY",
	["Limpar memória"] = "Clean memory",
	["Libera o cache do script e o que o executor permitir"] = "Frees the script cache and whatever the executor allows",
	["Limpar"] = "Clean",
	["Memória"] = "Memory",
	["Nenhum ajuste encontrado"] = "No tweaks found",
	["Todas as otimizações ligadas"] = "All optimizations on",
	["Farm desligado"] = "Farm off",
	["Farm ativo"] = "Farm on",
	["Início rápido liga: Anti-AFK, Reconectar, Parar 3D, Silenciar"] = "Quick start turns on: Anti-AFK, Reconnect, Stop 3D, Mute",
	["e 15 FPS"] = "and 15 FPS",
	["Início rápido"] = "Quick start",
	["Desligar tudo"] = "Turn all off",
	["Modo farm desligado"] = "Farm mode off",
	["Modo farm iniciado"] = "Farm mode started",
	["recurso ligado"] = "feature on",
	["recursos ligados"] = "features on",
	["Quadros por segundo"] = "Frames per second",
	["Latência até o servidor"] = "Latency to the server",
	["SERVIDOR"] = "SERVER",
	["Distância do servidor"] = "Server distance",
	["Estimativa pela latência (o Roblox não informa a região)"] = "Estimated from latency (Roblox doesn't share the region)",
	["ESTABILIDADE"] = "STABILITY",
	["Lag do servidor"] = "Server lag",
	["Mostra se a conexão com o servidor está oscilando"] = "Shows whether the server connection is unstable",
	["Memória usada pelo Roblox"] = "Memory used by Roblox",
	["QUADRO"] = "FRAME",
	["Tempo de quadro"] = "Frame time",
	["Milissegundos por quadro"] = "Milliseconds per frame",
	["Jogadores"] = "Players",
	["Pessoas no servidor"] = "People in the server",
	["Preset ativo"] = "Active preset",
	["Qual preset está aplicado"] = "Which preset is applied",
	["HORA"] = "TIME",
	["Horário"] = "Clock",
	["Hora local"] = "Local time",
	["Tempo de farm"] = "Farm time",
	["Há quanto tempo o modo farm está ligado"] = "How long farm mode has been on",
	["nenhum"] = "none",
	["desligado"] = "off",
	["medindo…"] = "measuring…",
	["perto · provável BR"] = "close · probably BR",
	["meio longe · talvez fora do BR"] = "a bit far · maybe outside BR",
	["longe · provável fora do BR"] = "far · probably outside BR",
	["perto de você"] = "close to you",
	["distância média"] = "medium distance",
	["longe de você"] = "far from you",
	["Com lag"] = "Lagging",
	["Oscilando"] = "Unstable",
	["Estável"] = "Stable",
	["PAINEL"] = "PANEL",
	["Mostrar painel"] = "Show panel",
	["Liga ou esconde o painel inteiro"] = "Shows or hides the whole panel",
	["Formato"] = "Layout",
	["Em lista ou numa linha só"] = "As a list or a single line",
	["Lista"] = "List",
	["Linha"] = "Line",
	["Tamanho"] = "Size",
	["Tamanho do texto no painel"] = "Panel text size",
	["Pequeno"] = "Small",
	["Médio"] = "Medium",
	["Grande"] = "Large",
	["Posição"] = "Position",
	["Arraste o painel na tela para mover"] = "Drag the panel on screen to move it",
	["Redefinir"] = "Reset",
	["INFORMAÇÕES"] = "INFO",
	["Selecionar tudo"] = "Select all",
	["Liga ou desliga todas as informações de uma vez"] = "Turns all info on or off at once",
	["MODO STREAMER"] = "STREAMER MODE",
	["SESSÃO"] = "SESSION",
	["Conta com"] = "Account is",
	["dias"] = "days old",
	["USANDO AGORA"] = "IN USE NOW",
	["efeito visual"] = "visual effect",
	["efeitos visuais"] = "visual effects",
	["Áudio personalizado"] = "Custom audio",
	["proteção"] = "protection",
	["proteções"] = "protections",
	["HUD na tela"] = "HUD on screen",
	["Nada ligado ainda · experimente um preset"] = "Nothing on yet · try a preset",
	["AMIGOS JOGANDO AGORA"] = "FRIENDS PLAYING NOW",
	["Atualizar"] = "Refresh",
	["Procurando amigos…"] = "Looking for friends…",
	["Não foi possível carregar os amigos"] = "Couldn't load friends",
	["Amigo"] = "Friend",
	["Aqui"] = "Here",
	["Entrar"] = "Join",
	["Privado"] = "Private",
	["Entrando no servidor de"] = "Joining the server of",
	["Nenhum amigo jogando agora"] = "No friends playing right now",
	["por"] = "by",
	["Novidades"] = "What's new",
	["Jogador"] = "Player",
	["Não deu para entrar"] = "Couldn't join",
	["SERVIDOR ATUAL"] = "CURRENT SERVER",
	["ONLINE HÁ"] = "UPTIME",
	["Precisa de executor (HttpGet)"] = "Needs an executor (HttpGet)",
	["Entrando no servidor…"] = "Joining server…",
	["Nenhum servidor livre encontrado"] = "No free server found",
	["jogadores"] = "players",
	["Procurando servidores…"] = "Searching servers…",
	["Não foi possível listar os servidores"] = "Couldn't list servers",
	["SERVIDORES COM MENOR PING"] = "LOWEST PING SERVERS",
	["SERVIDORES MAIS VAZIOS"] = "EMPTIEST SERVERS",
	["Reentrar"] = "Rejoin",
	["Volta para este mesmo servidor"] = "Back to this same server",
	["Reentrando…"] = "Rejoining…",
	["Menor ping"] = "Lowest ping",
	["Procura o servidor mais rápido para você"] = "Finds the fastest server for you",
	["Mais vazio"] = "Emptiest",
	["Entra no servidor com menos gente"] = "Joins the server with the fewest people",
	["Copiar link"] = "Copy link",
	["Para um amigo entrar no mesmo servidor"] = "So a friend can join the same server",
	["Precisa de executor (setclipboard)"] = "Needs an executor (setclipboard)",
	["Link do servidor copiado"] = "Server link copied",
	["MELHORES SERVIDORES"] = "BEST SERVERS",
	["Toque em Menor ping ou Mais vazio para buscar"] = "Tap Lowest ping or Emptiest to search",
	["A lista de servidores vem do próprio Roblox e precisa de executor (HttpGet). O ping de cada servidor é uma estimativa."] = "The server list comes from Roblox itself and needs an executor (HttpGet). Each server's ping is an estimate.",
	["servidor de teste"] = "test server",
	["Horário do jogo"] = "Game time",
	["Cor do destaque"] = "Highlight color",
	["Cor do contorno ou do preenchimento"] = "Outline or fill color",
	["Opacidade do preenchimento"] = "Fill opacity",
	["Só vale no modo Preenchido"] = "Only in Filled mode",
	["GALERIA"] = "GALLERY",
	["Noite neon"] = "Neon night",
	["Dia limpo"] = "Clear day",
	["Salvo por você"] = "Saved by you",
	["Visual pronto"] = "Ready-made look",
	["Visual apagado da galeria"] = "Look removed from the gallery",
	["Salvar visual atual"] = "Save current look",
	["Horário, céu, shader e fullbright"] = "Time, sky, shader and fullbright",
	["Nome do visual"] = "Look name",
	["Salvar"] = "Save",
	["Meu visual"] = "My look",
	["Visual salvo na galeria"] = "Look saved to the gallery",
	["Visual"] = "Look",
	["PRINT LIMPA"] = "CLEAN SCREENSHOT",
	["Segure o botão flutuante sem mover para tirar uma print sem menus nem HUD."] = "Hold the floating button without moving it to take a screenshot without menus or HUD.",
	["Modo da print"] = "Screenshot mode",
	["Cinema liga gráficos no máximo e shader só na hora"] = "Cinema turns on max graphics and a shader just for the shot",
	["Normal"] = "Normal",
	["Segurar o botão por"] = "Hold the button for",
	["Tempo até a print ser tirada"] = "Time until the screenshot is taken",
	["Tirar print agora"] = "Take screenshot now",
	["Fecha o menu, tira a print e volta"] = "Closes the menu, takes the shot and comes back",
	["Tirar print"] = "Screenshot",
	["EQUALIZADOR"] = "EQUALIZER",
	["Equalizador"] = "Equalizer",
	["Médios"] = "Mids",
	["Agudos"] = "Treble",
	["vozes no servidor"] = "voices in the server",
	["Sem voice novo neste servidor"] = "No new voice chat in this server",
	["MIXER"] = "MIXER",
	["Música"] = "Music",
	["Trilha sonora do jogo"] = "The game's soundtrack",
	["Efeitos"] = "Effects",
	["Sons de ação, objetos e personagens"] = "Action, object and character sounds",
	["Ambiente"] = "Ambience",
	["Vento, chuva, natureza e fundo"] = "Wind, rain, nature and background",
	["Interface"] = "Interface",
	["Cliques e sons de menu"] = "Clicks and menu sounds",
	["Voz"] = "Voice",
	["Voice chat dos outros (jogos com voice novo)"] = "Other players' voice chat (games with new voice)",
	["Mudo"] = "Muted",
	["Mais alto que o original"] = "Louder than original",
	["Mais baixo que o original"] = "Quieter than original",
	["REALCES"] = "BOOSTS",
	["Realçar passos"] = "Boost footsteps",
	["Ouça quem está chegando"] = "Hear who is coming",
	["Realçar sons de combate"] = "Boost combat sounds",
	["Tiros, golpes e explosões mais altos"] = "Louder shots, hits and explosions",
	["Remover música"] = "Remove music",
	["Tira só a trilha sonora, o resto continua"] = "Removes only the soundtrack, the rest stays",
	["Abafar sons muito altos"] = "Tame very loud sounds",
	["Evita estouros e sustos de volume"] = "Prevents sudden volume spikes",
	["ligado"] = "on",
	["O Roblox não informa o tipo de cada som: passos, combate e música são identificados pelo nome e pelo lugar do som. Funciona na maioria dos jogos."] = "Roblox doesn't say what each sound is: footsteps, combat and music are detected by the sound's name and location. Works in most games.",
	["Todas as proteções ligadas"] = "All protections on",
	["Proteções desligadas"] = "Protections off",
	["Protegido"] = "Protected",
	["Sem proteção"] = "Unprotected",
	["proteções ativas"] = "protections on",
	["Desligar todas"] = "Turn all off",
	["Sobre anti-kick: bloquear o kick do próprio jogo é burlar a moderação, então não é feito aqui. O Reconectar sozinho te devolve ao jogo se você cair."] = "About anti-kick: blocking the game's own kick bypasses moderation, so it isn't done here. Auto reconnect brings you back if you drop.",
	["Print indisponível neste ambiente"] = "Screenshots unavailable here",
	["Print tirada · confirme para salvar na galeria"] = "Screenshot taken · confirm to save it to your gallery",
	["Não foi possível tirar a print neste ambiente"] = "Couldn't take a screenshot here",
	["GERAL"] = "GENERAL",
	["Lembrar minhas escolhas"] = "Remember my choices",
	["Reaplica presets, ajustes, farm e HUD ao executar de novo"] = "Reapplies presets, tweaks, farm and HUD when you run it again",
	["Indisponível: precisa de executor (writefile)"] = "Unavailable: needs an executor (writefile)",
	["Precisa de executor com writefile"] = "Needs an executor with writefile",
	["Suas escolhas serão lembradas"] = "Your choices will be remembered",
	["Escolhas não serão mais lembradas"] = "Choices won't be remembered anymore",
	["Abrir o menu ao iniciar"] = "Open the menu on start",
	["Mostra esta janela logo depois do carregamento"] = "Shows this window right after loading",
	["Idioma"] = "Language",
	["Muda na próxima vez que você executar o script"] = "Changes the next time you run the script",
	["O idioma muda na próxima execução"] = "Language changes on the next run",
	["Notificações"] = "Notifications",
	["Avisos no topo da tela ao salvar e aplicar (erros sempre aparecem)"] = "Top-of-screen notices when saving and applying (errors always show)",
	["Reduzir animações"] = "Reduce motion",
	["Troca transições por mudanças instantâneas"] = "Swaps transitions for instant changes",
	["Atalho do teclado"] = "Keyboard shortcut",
	["No celular, use o botão flutuante"] = "On mobile, use the floating button",
	["Tecla que abre e fecha o menu"] = "Key that opens and closes the menu",
	["COMPATIBILIDADE"] = "COMPATIBILITY",
	["Disponível"] = "Available",
	["Indisponível"] = "Unavailable",
	["Cliente"] = "Client",
	["Ambiente de execução"] = "Runtime",
	["Onde o Silly Optimizer está rodando"] = "Where Silly Optimizer is running",
	["Função setfpscap do executor"] = "Executor's setfpscap function",
	["Salvar escolhas"] = "Save choices",
	["Funções writefile e readfile"] = "writefile and readfile functions",
	["Interface protegida"] = "Protected interface",
	["gethui esconde o menu de outros scripts"] = "gethui hides the menu from other scripts",
	["Novidades da versão"] = "What's new",
	["Veja o que mudou na v"] = "See what changed in v",
	["Ver novidades"] = "See what's new",
	["Restaurar tudo"] = "Restore everything",
	["Desliga presets, ajustes, farm, visual, áudio e proteções"] = "Turns off presets, tweaks, farm, look, audio and protections",
	["Tudo restaurado"] = "Everything restored",
	["Reset de fábrica"] = "Factory reset",
	["Apaga perfis, presets por jogo, galeria e preferências"] = "Deletes profiles, per-game presets, gallery and preferences",
	["Resetar"] = "Reset",
	["Confirmar"] = "Confirm",
	["Reset de fábrica concluído"] = "Factory reset done",
	["Fechar o Silly Optimizer"] = "Close Silly Optimizer",
	["Devolve tudo ao normal e remove o menu da tela"] = "Puts everything back to normal and removes the menu",
	["Fechar"] = "Close",
	["Aba Home com sua conta, Premium, servidor, desempenho e amigos jogando"] = "Home tab with your account, Premium, server, performance and friends playing",
	["Benchmark que monta presets Competitivo e Desempenho para cada jogo"] = "Benchmark that builds Competitive and Performance presets for each game",
	["Preset salvo por jogo, aplicado sozinho quando você entra"] = "Per-game preset, applied automatically when you join",
	["Aba Server: reentrar, menor ping, mais vazio e copiar link"] = "Server tab: rejoin, lowest ping, emptiest and copy link",
	["Aba Visual: horário, céu, shaders, fullbright, FOV, câmera e destaque de jogadores"] = "Look tab: time, sky, shaders, fullbright, FOV, camera and player highlight",
	["Galeria de visuais e print limpa segurando o botão flutuante"] = "Look gallery and clean screenshot by holding the floating button",
	["Aba Áudio: mixer, realce de passos e combate, equalizador e voice"] = "Audio tab: mixer, footstep and combat boost, equalizer and voice",
	["Aba Proteção: anti-fling, anti-lag de efeitos e modo streamer"] = "Protection tab: anti-fling, effect anti-lag and streamer mode",
	["Engrenagem no botão flutuante: perfis, tamanho e opacidade"] = "Gear on the floating button: profiles, size and opacity",
	["Distância de renderização, acessórios dos outros e FPS desbloqueado"] = "Render distance, other players' accessories and unlocked FPS",
	["Limpar memória, idioma Português/English e reset de fábrica"] = "Clean memory, Portuguese/English language and factory reset",
	["Modo leve no celular: a interface não usa mais CanvasGroup no mobile"] = "Mobile lite mode: the interface no longer uses CanvasGroup on mobile",
	["Se algo der errado ao abrir, aparece um aviso na tela com o motivo"] = "If something goes wrong on start, an on-screen notice shows why",
	["Correção para executores em que a interface não aparecia"] = "Fix for executors where the interface didn't show up",
	["Visual novo, tela de carregamento e animações"] = "New look, loading screen and animations",
	["Ajustes com estado claro, busca e filtros"] = "Tweaks with clear state, search and filters",
	["HUD personalizável e aba Configurações"] = "Customizable HUD and Settings tab",
	["ATUAL"] = "CURRENT",
	["Entendi"] = "Got it",
	["PAINEL RÁPIDO"] = "QUICK PANEL",
	["Perfis e botão flutuante"] = "Profiles and floating button",
	["PERFIS"] = "PROFILES",
	["Nenhum perfil salvo ainda. Configure as abas e salve abaixo."] = "No saved profiles yet. Set up the tabs and save below.",
	["Perfil"] = "Profile",
	["Perfil apagado"] = "Profile deleted",
	["Salvar configuração atual"] = "Save current setup",
	["Escolha quais abas entram no perfil:"] = "Choose which tabs go into the profile:",
	["Nome do perfil (ex.: Ranked)"] = "Profile name (e.g. Ranked)",
	["Salvar perfil"] = "Save profile",
	["Escolha pelo menos uma aba"] = "Pick at least one tab",
	["Perfil salvo só nesta sessão (sem writefile)"] = "Profile saved for this session only (no writefile)",
	["salvo"] = "saved",
	["BOTÃO FLUTUANTE"] = "FLOATING BUTTON",
	["Tamanho do botão na tela"] = "Button size on screen",
	["Opacidade"] = "Opacity",
	["Deixe o botão mais discreto"] = "Make the button more subtle",
	["PRESETS NA TELA"] = "PRESETS ON SCREEN",
	["Mostrar este preset na aba Presets"] = "Show this preset in the Presets tab",
	["toque no botão flutuante para abrir"] = "tap the floating button to open",
	["abre o menu"] = "opens the menu",
	["Silly Optimizer pronto"] = "Silly Optimizer ready",
	["Preset deste jogo aplicado"] = "This game's preset applied",
	["Desligar"] = "Turn off",
	["Fullbright"] = "Fullbright",
	["Shaders"] = "Shaders",
}
local function T(s)
	if Prefs.lang == "en" and type(s) == "string" then
		return EN[s] or s
	end
	return s
end

-- estado compartilhado dos recursos novos (uma variável só, para poupar locais)
local Ext = {
	fov = 90,
	hl = { mode = 1, color = 1, alpha = 2 },
	pings = {},
	gameName = "",
	sessionStart = os.clock(),
	Games = (SaveData and type(SaveData.games) == "table") and SaveData.games or {},
	Profiles = (SaveData and type(SaveData.profiles) == "table") and SaveData.profiles or {},
	Gallery = (SaveData and type(SaveData.gallery) == "table") and SaveData.gallery or {},
}

--------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------
local function make(class, props, children)
	if class == "CanvasGroup" and Env.lite then
		class = "Frame"
		if props then
			props.GroupTransparency = nil
			props.ClipsDescendants = true
		end
	end
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
	props.Text = T(props.Text)
	return make("TextLabel", props)
end

local function tween(inst, t, props, style, dir)
	if props.GroupTransparency ~= nil and not inst:IsA("CanvasGroup") then
		props = table.clone(props)
		props.GroupTransparency = nil
		if next(props) == nil then
			return nil
		end
	end
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
	local function try(parent)
		if typeof(parent) ~= "Instance" then
			return false
		end
		local ok = pcall(function()
			g.Parent = parent
		end)
		return ok and g.Parent == parent
	end
	if Env.gethui then
		local ok, ui = pcall(Env.gethui)
		if ok and typeof(ui) == "Instance" then
			-- alguns executores devolvem uma ScreenGui: ScreenGui dentro de ScreenGui não aparece
			if ui:IsA("LayerCollector") and ui.Parent then
				ui = ui.Parent
			end
			if try(ui) then
				return
			end
		end
	end
	if not Env.studio then
		local okCore, core = pcall(function()
			return game:GetService("CoreGui")
		end)
		if okCore and try(core) then
			return
		end
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
-- se o lugar escolhido não desenha a interface, usa o PlayerGui
RunService.Heartbeat:Wait()
if Gui.AbsoluteSize.X < 2 and Gui.Parent ~= LocalPlayer:FindFirstChildOfClass("PlayerGui") then
	pcall(function()
		Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end)
end

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
-- usado pelo xpcall lá no fim, se algo quebrar no meio do carregamento
SillyAbort = function()
	if destroyAll then
		destroyAll()
	else
		Destroyed = true
		pcall(function()
			Gui:Destroy()
		end)
	end
end

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
		if card:IsA("CanvasGroup") then
			TweenService:Create(card, TweenInfo.new(0.35), { GroupTransparency = 0 }):Play()
		end
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
		status.Text = T(msg)
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
		if card:IsA("CanvasGroup") then
			TweenService:Create(card, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
		end
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

function Ext.inCharacter(inst)
	local model = inst:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- limite de FPS central: o "Limitar FPS" do Farm tem prioridade sobre o "FPS desbloqueado"
local Fps = { original = nil, unlock = 240 }
function Fps.apply(Active_)
	if not Env.setfpscap then
		return false
	end
	if Fps.original == nil then
		Fps.original = 60 -- sem getfpscap não dá para saber o anterior; 60 é o padrão do Roblox
		if Env.getfpscap then
			local ok, v = pcall(Env.getfpscap)
			if ok and type(v) == "number" and v > 0 then
				Fps.original = v
			end
		end
	end
	local target = Fps.original
	if Active_.fpscap then
		target = FpsCap
	elseif Active_.fps_unlock then
		target = Fps.unlock
	end
	return (pcall(Env.setfpscap, target))
end

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
	return T("Nível") .. " " .. v
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
		  return T("Ativo") .. " · " .. animChars .. " " .. T(animChars == 1 and "personagem" or "personagens")
	  end,
	  custom = { on = animOn, off = animOff } },
	{ id = "reverb", cat = "SISTEMA", title = "Remover eco do som",
	  desc = "Desliga o reverb global do ambiente",
	  targets = { { soundT, { AmbientReverb = Enum.ReverbType.NoReverb } } } },
}
end -- fim das opções

-- Desempenho extra: distância de renderização, acessórios e FPS desbloqueado
do
	-- esconde (só para você) objetos longe da câmera; varre o mapa aos poucos para não travar
	local RD = { dist = 500, hidden = {}, count = 0, token = 0 }
	local function rdOn()
		RD.token += 1
		local my = RD.token
		task.spawn(function()
			local parts, idx, refreshAt = {}, 1, 0
			while Active.render_dist and RD.token == my and not Destroyed do
				if os.clock() >= refreshAt then
					parts = {}
					for _, d in ipairs(Workspace:GetDescendants()) do
						if d:IsA("BasePart") and not d:IsA("Terrain") then
							parts[#parts + 1] = d
						end
					end
					refreshAt = os.clock() + 12
					idx = 1
				end
				if idx > #parts then
					idx = 1
				end
				local cam = Workspace.CurrentCamera
				if cam then
					local origin = cam.CFrame.Position
					local stop = math.min(#parts, idx + 1500)
					for i = idx, stop do
						local p = parts[i]
						if p.Parent then
							local far = (p.Position - origin).Magnitude - p.Size.Magnitude * 0.5 > RD.dist
							if far then
								if RD.hidden[p] == nil and not Ext.inCharacter(p) then
									RD.hidden[p] = p.LocalTransparencyModifier
									RD.count += 1
									p.LocalTransparencyModifier = 1
								end
							elseif RD.hidden[p] ~= nil then
								p.LocalTransparencyModifier = RD.hidden[p]
								RD.hidden[p] = nil
								RD.count -= 1
							end
						end
					end
					idx = stop + 1
				end
				task.wait()
			end
		end)
		return true
	end
	local function rdOff()
		RD.token += 1
		for p, v in pairs(RD.hidden) do
			pcall(function()
				p.LocalTransparencyModifier = v
			end)
		end
		table.clear(RD.hidden)
		RD.count = 0
	end

	-- acessórios dos outros jogadores (chapéus, cabelos, asas…)
	local ACC = { store = {}, conns = {}, n = 0 }
	local function accHide(inst)
		if inst:IsA("BasePart") and inst:FindFirstAncestorOfClass("Accessory") then
			if ACC.store[inst] == nil then
				ACC.store[inst] = inst.LocalTransparencyModifier
				ACC.n += 1
			end
			inst.LocalTransparencyModifier = 1
		end
	end
	local function accChar(char)
		for _, d in ipairs(char:GetDescendants()) do
			pcall(accHide, d)
		end
		table.insert(ACC.conns, char.DescendantAdded:Connect(function(d)
			pcall(accHide, d)
		end))
	end
	local function accPlr(plr)
		if plr == LocalPlayer then
			return
		end
		if plr.Character then
			accChar(plr.Character)
		end
		table.insert(ACC.conns, plr.CharacterAdded:Connect(accChar))
	end
	local function accOn()
		for _, plr in ipairs(Players:GetPlayers()) do
			accPlr(plr)
		end
		table.insert(ACC.conns, Players.PlayerAdded:Connect(accPlr))
		return true
	end
	local function accOff()
		for _, c in ipairs(ACC.conns) do
			c:Disconnect()
		end
		table.clear(ACC.conns)
		for p, v in pairs(ACC.store) do
			pcall(function()
				p.LocalTransparencyModifier = v
			end)
		end
		table.clear(ACC.store)
		ACC.n = 0
	end

	local extra = {
		{ id = "render_dist", cat = "DESEMPENHO", title = "Distância de renderização",
		  desc = "Esconde o que está longe da câmera (só para você)",
		  choices = { 300, 500, 800, 1200 }, choiceIndex = 2,
		  fmt = function(v)
			  return v .. " studs"
		  end,
		  onChoice = function(v)
			  RD.dist = v
		  end,
		  statusText = function()
			  return T("Ativo") .. " · " .. fmtNum(RD.count) .. " " .. T("objetos escondidos")
		  end,
		  custom = { on = rdOn, off = rdOff } },
		{ id = "accessories", cat = "DESEMPENHO", title = "Esconder acessórios dos outros",
		  desc = "Chapéus, cabelos e asas pesados somem (só para você)",
		  statusText = function()
			  return T("Ativo") .. " · " .. fmtNum(ACC.n) .. " " .. T("peças escondidas")
		  end,
		  custom = { on = accOn, off = accOff } },
		{ id = "fps_unlock", cat = "DESEMPENHO", title = "FPS desbloqueado",
		  desc = Env.setfpscap and "Libera mais de 60 FPS em telas rápidas" or "Indisponível: precisa de executor (setfpscap)",
		  locked = not Env.setfpscap, noPreset = true,
		  choices = { 120, 144, 240, 999 }, choiceIndex = 3,
		  fmt = function(v)
			  return v >= 999 and T("Sem limite") or (v .. " FPS")
		  end,
		  onChoice = function(v)
			  Fps.unlock = v
			  if Active.fps_unlock then
				  Fps.apply(Active)
			  end
		  end,
		  statusText = function()
			  if Active.fpscap then
				  return T("Pausado: o Limitar FPS do Farm está ligado")
			  end
			  return T("Ativo") .. " · " .. (Fps.unlock >= 999 and T("sem limite") or (Fps.unlock .. " FPS"))
		  end,
		  custom = {
			  on = function()
				  return Fps.apply(Active)
			  end,
			  off = function()
				  Fps.apply(Active)
			  end,
		  } },
	}
	for _, opt in ipairs(extra) do
		table.insert(OPTIONS, opt)
	end
end

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
-- ÁUDIO: mixer por categoria, realces, limitador, equalizador e voice
-- O Roblox não diz o que é passo ou tiro: a categoria vem do nome e do lugar do som.
--------------------------------------------------------------------------
local Audio = {
	mult = { music = 1, effects = 1, ambient = 1, ui = 1, voice = 1, steps = 1, combat = 1 },
	muted = false,
	limiter = false,
	eq = 1,
	recs = setmetatable({}, { __mode = "k" }),
	voices = setmetatable({}, { __mode = "k" }),
	conns = {},
	eqFx = {},
	running = false,
	guard = false,
	voiceCount = 0,
	EQ = {
		{ name = "Desligado" },
		{ name = "Competitivo", low = -6, mid = 2, high = 6, bars = { 0.3, 0.6, 0.95 } },
		{ name = "Cinema", low = 6, mid = 0, high = 2, bars = { 0.95, 0.5, 0.65 } },
		{ name = "Voz clara", low = -4, mid = 5, high = 2, bars = { 0.35, 0.95, 0.6 } },
		{ name = "Graves", low = 8, mid = 0, high = -2, bars = { 1, 0.5, 0.35 } },
	},
}
do
	local KW = {
		steps = { "footstep", "step", "running", "walk", "landing", "climb" },
		combat = { "shot", "shoot", "gun", "fire", "hit", "punch", "slash", "sword", "reload", "bullet",
			"impact", "swing", "explos", "blast", "attack", "damage", "kick" },
		music = { "music", "song", "theme", "bgm", "soundtrack", "musica" },
		ambient = { "ambient", "ambience", "rain", "wind", "bird", "water", "ocean", "forest", "crowd", "cricket" },
		ui = { "click", "button", "hover", "menu", "notif", "select", "purchase", "coin" },
	}
	local function has(n, list)
		for _, k in ipairs(list) do
			if string.find(n, k, 1, true) then
				return true
			end
		end
		return false
	end

	function Audio.classify(s)
		local n = string.lower(s.Name)
		if s:FindFirstAncestorOfClass("PlayerGui") or string.find(n, "%f[%a]ui%f[%A]") then
			return "ui"
		end
		if has(n, KW.steps) then
			return "steps"
		end
		if has(n, KW.combat) then
			return "combat"
		end
		if Ext.inCharacter(s) then
			return "effects"
		end
		if has(n, KW.music) then
			return "music"
		end
		local parent = s.Parent
		local inPart = parent ~= nil and (parent:IsA("BasePart") or parent:IsA("Attachment"))
		if s.Looped and not inPart and (s.TimeLength == 0 or s.TimeLength > 25) then
			return "music"
		end
		if has(n, KW.ambient) or (s.Looped and inPart) then
			return "ambient"
		end
		if has(n, KW.ui) then
			return "ui"
		end
		return "effects"
	end

	local function ensureGroup()
		if not Audio.group or not Audio.group.Parent then
			local g = Instance.new("SoundGroup")
			g.Name = "SillyOptimizerAudio"
			g:SetAttribute("SillyFx", true)
			g.Parent = SoundService
			Audio.group = g
		end
		return Audio.group
	end

	function Audio.needed()
		if Audio.muted or Audio.limiter or Audio.eq > 1 then
			return true
		end
		for k, v in pairs(Audio.mult) do
			if k ~= "voice" and v ~= 1 then
				return true
			end
		end
		return false
	end

	function Audio.applySound(s, rec)
		local v = Audio.muted and 0 or rec.orig * (Audio.mult[rec.cat] or 1)
		if Audio.limiter then
			v = math.min(v, 1.5)
		end
		v = math.clamp(v, 0, 10)
		rec.set = v
		Audio.guard = true
		pcall(function()
			s.Volume = v
		end)
		Audio.guard = false
		if Audio.eq > 1 then
			if not rec.routed and s.SoundGroup == nil then
				rec.routed = true
				pcall(function()
					s.SoundGroup = ensureGroup()
				end)
			end
		elseif rec.routed then
			rec.routed = false
			pcall(function()
				s.SoundGroup = nil
			end)
		end
	end

	function Audio.track(s)
		if not s:IsA("Sound") or s:GetAttribute("SillyFx") then
			return
		end
		local rec = Audio.recs[s]
		if not rec then
			rec = { orig = s.Volume, cat = Audio.classify(s) }
			Audio.recs[s] = rec
			rec.conn = s:GetPropertyChangedSignal("Volume"):Connect(function()
				if Audio.guard or not Audio.running then
					return
				end
				if rec.set and same(s.Volume, rec.set) then
					return
				end
				rec.orig = s.Volume -- o jogo mudou o volume: esse vira o novo original
				Audio.applySound(s, rec)
			end)
		end
		Audio.applySound(s, rec)
	end

	local function roots()
		local r = { Workspace, SoundService }
		local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then
			r[#r + 1] = pg
		end
		return r
	end

	function Audio.start()
		Audio.running = true
		for _, root in ipairs(roots()) do
			table.insert(Audio.conns, root.DescendantAdded:Connect(function(d)
				if d:IsA("Sound") then
					task.defer(function()
						if Audio.running then
							pcall(Audio.track, d)
						end
					end)
				end
			end))
			task.spawn(function()
				local ok, desc = pcall(root.GetDescendants, root)
				if not ok then
					return
				end
				for i, d in ipairs(desc) do
					if not Audio.running then
						return
					end
					if d:IsA("Sound") then
						pcall(Audio.track, d)
					end
					if i % 2000 == 0 then
						task.wait()
					end
				end
			end)
		end
	end

	function Audio.stop()
		Audio.running = false
		for _, c in ipairs(Audio.conns) do
			c:Disconnect()
		end
		table.clear(Audio.conns)
		for s, rec in pairs(Audio.recs) do
			if rec.conn then
				rec.conn:Disconnect()
			end
			Audio.guard = true
			pcall(function()
				s.Volume = rec.orig
				if rec.routed then
					s.SoundGroup = nil
				end
			end)
			Audio.guard = false
		end
		table.clear(Audio.recs)
	end

	function Audio.applyEq()
		for _, fx in ipairs(Audio.eqFx) do
			pcall(function()
				fx:Destroy()
			end)
		end
		table.clear(Audio.eqFx)
		local preset = Audio.EQ[Audio.eq]
		if not preset or not preset.low then
			return
		end
		local groups = { ensureGroup() }
		for _, d in ipairs(SoundService:GetDescendants()) do
			if d:IsA("SoundGroup") and d ~= Audio.group then
				groups[#groups + 1] = d
			end
		end
		for _, g in ipairs(groups) do
			local ok, fx = pcall(function()
				local e = Instance.new("EqualizerSoundEffect")
				e.LowGain, e.MidGain, e.HighGain = preset.low, preset.mid, preset.high
				e:SetAttribute("SillyFx", true)
				e.Parent = g
				return e
			end)
			if ok then
				table.insert(Audio.eqFx, fx)
			end
		end
	end

	-- voice do sistema de áudio novo (AudioDeviceInput dos outros jogadores)
	function Audio.applyVoice()
		local m = Audio.mult.voice
		local found = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				for _, d in ipairs(plr:GetDescendants()) do
					if d.ClassName == "AudioDeviceInput" then
						found += 1
						if Audio.voices[d] == nil then
							local ok, v = pcall(function()
								return d.Volume
							end)
							Audio.voices[d] = ok and v or 1
						end
						pcall(function()
							d.Volume = Audio.voices[d] * m
						end)
					end
				end
			end
		end
		Audio.voiceCount = found
	end

	function Audio.refresh()
		Audio.applyEq()
		if Audio.needed() then
			if not Audio.running then
				Audio.start()
			else
				for s, rec in pairs(Audio.recs) do
					pcall(Audio.applySound, s, rec)
				end
			end
		elseif Audio.running then
			Audio.stop()
		end
		Audio.applyVoice()
	end

	function Audio.count()
		local n = 0
		for _ in pairs(Audio.recs) do
			n += 1
		end
		return n
	end

	function Audio.capture()
		return { mult = table.clone(Audio.mult), limiter = Audio.limiter, eq = Audio.eq }
	end

	function Audio.load(cap)
		if type(cap) ~= "table" then
			return
		end
		if type(cap.mult) == "table" then
			for k, v in pairs(cap.mult) do
				if Audio.mult[k] ~= nil and type(v) == "number" then
					Audio.mult[k] = v
				end
			end
		end
		Audio.limiter = cap.limiter == true
		if type(cap.eq) == "number" and Audio.EQ[cap.eq] then
			Audio.eq = cap.eq
		end
		Audio.refresh()
	end

	-- voice de quem entra depois
	track(Players.DescendantAdded:Connect(function(d)
		if d.ClassName == "AudioDeviceInput" and Audio.mult.voice ~= 1 then
			task.defer(Audio.applyVoice)
		end
	end))
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
		g:SetAttribute("SillyOptimizer", true)
		g.Parent = Gui.Parent
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
	local function capOn()
		return Fps.apply(Active)
	end
	local function capOff()
		Fps.apply(Active)
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
		{ id = "antiafk", cat = "PROTEÇÃO", tab = "protect", title = "Anti-AFK",
		  desc = "Evita o kick do Roblox depois de ~20 min parado",
		  statusText = function()
			  return T("Ativo · protegido contra kick por inatividade")
		  end,
		  custom = { on = afkOn, off = afkOff } },
		{ id = "afk_jump", cat = "ATIVIDADE", title = "Pulinho periódico",
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
			  return T("Ativo · próximo pulo em") .. " " .. math.max(0, math.ceil(nextJump - os.clock())) .. " s"
		  end,
		  custom = { on = jumpOn, off = jumpOff } },
		{ id = "reconnect", cat = "PROTEÇÃO", tab = "protect", title = "Reconectar sozinho",
		  desc = "Volta ao jogo (servidor novo) se cair ou for kickado",
		  statusText = function()
			  return T(rejoining and "Reconectando…" or "Ativo · vigiando a conexão")
		  end,
		  custom = { on = reconnOn, off = reconnOff } },

		{ id = "render3d", cat = "BATERIA E CALOR", title = "Parar renderização 3D",
		  desc = "Para de desenhar o mundo: menos GPU e calor",
		  statusText = function()
			  return T("Ativo · mundo pausado")
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
			  return T("Ativo · limite de") .. " " .. FpsCap .. " FPS"
		  end,
		  custom = { on = capOn, off = capOff } },
		{ id = "mute", cat = "BATERIA E CALOR", title = "Silenciar sons",
		  desc = "Zera o volume dos sons do jogo",
		  statusText = function()
			  return T("Ativo") .. " · " .. fmtNum(Audio.count()) .. " " .. T("sons")
		  end,
		  custom = {
			  on = function()
				  Audio.muted = true
				  Audio.refresh()
				  return true
			  end,
			  off = function()
				  Audio.muted = false
				  Audio.refresh()
			  end,
		  } },
		{ id = "hide_players", cat = "BATERIA E CALOR", title = "Esconder outros jogadores",
		  desc = "Personagens e nomes somem (só para você)",
		  statusText = function()
			  local n = countKeys(hideChars)
			  return T("Ativo") .. " · " .. n .. " " .. T(n == 1 and "jogador oculto" or "jogadores ocultos")
		  end,
		  custom = { on = hidePlayersOn, off = hidePlayersOff } },
		{ id = "hide_game_gui", cat = "BATERIA E CALOR", title = "Esconder telas do jogo",
		  desc = "Desliga as interfaces do próprio jogo",
		  statusText = function()
			  return T("Ativo") .. " · " .. guiCount .. " " .. T(guiCount == 1 and "tela oculta" or "telas ocultas")
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
			  return T("Ativo · desliga em") .. " " .. formatDuration(timerEnds - os.clock())
		  end,
		  custom = { on = timerOn, off = timerOff } },
	}

	for _, opt in ipairs(FARM_OPTIONS) do
		register(opt)
		if opt.tab ~= "protect" then
			FarmIds[opt.id] = true
		end
	end
end

--------------------------------------------------------------------------
-- VISUAL e PROTEÇÃO (opções do motor, mas fora dos presets)
--------------------------------------------------------------------------
local VISUAL_OPTIONS, PROTECT_LIST
do
	Ext.time, Ext.sky, Ext.shader, Ext.zoom = 2, 2, 1, 400
	local function lightingT()
		return Lighting
	end
	local TIMES = {
		{ name = "Manhã", v = 7 },
		{ name = "Dia", v = 13 },
		{ name = "Tarde", v = 16.5 },
		{ name = "Pôr do sol", v = 17.9 },
		{ name = "Noite", v = 0 },
	}
	local SKIES = {
		{ name = "Padrão do Roblox" },
		{ name = "Limpo", atmo = { Density = 0.22, Offset = 0, Color = rgb(199, 217, 232), Decay = rgb(106, 120, 140), Glare = 0, Haze = 0 } },
		{ name = "Entardecer", atmo = { Density = 0.36, Offset = 0.1, Color = rgb(255, 190, 150), Decay = rgb(190, 105, 95), Glare = 0.5, Haze = 1.6 } },
		{ name = "Rosa", atmo = { Density = 0.33, Offset = 0.05, Color = rgb(255, 192, 216), Decay = rgb(205, 120, 170), Glare = 0.25, Haze = 1.1 } },
		{ name = "Noite azul", atmo = { Density = 0.3, Offset = 0, Color = rgb(96, 108, 150), Decay = rgb(40, 44, 78), Glare = 0, Haze = 0.6 } },
	}
	local SHADERS = {
		{ name = "Suave", swatch = { C.Apricot, C.Peach },
		  cc = { Brightness = 0.03, Contrast = 0.06, Saturation = 0.08, TintColor = rgb(255, 248, 242) },
		  bloom = { Intensity = 0.4, Size = 24, Threshold = 1.6 }, rays = { Intensity = 0.04, Spread = 0.6 } },
		{ name = "Vibrante", swatch = { C.Gold, C.Salmon },
		  cc = { Brightness = 0.02, Contrast = 0.14, Saturation = 0.35, TintColor = rgb(255, 255, 255) },
		  bloom = { Intensity = 0.6, Size = 28, Threshold = 1.4 }, rays = { Intensity = 0.08, Spread = 0.8 } },
		{ name = "Cinema", swatch = { C.Terra, rgb(60, 50, 48) },
		  cc = { Brightness = -0.02, Contrast = 0.2, Saturation = -0.05, TintColor = rgb(255, 238, 222) },
		  bloom = { Intensity = 0.8, Size = 32, Threshold = 1.2 }, rays = { Intensity = 0.12, Spread = 1 },
		  dof = { FarIntensity = 0.22, FocusDistance = 60, InFocusRadius = 45, NearIntensity = 0 } },
		{ name = "Neon", swatch = { C.Pink, rgb(150, 120, 230) },
		  cc = { Brightness = 0, Contrast = 0.18, Saturation = 0.45, TintColor = rgb(242, 228, 255) },
		  bloom = { Intensity = 1.2, Size = 40, Threshold = 0.9 } },
		{ name = "Retrô", swatch = { C.Butter, rgb(150, 120, 90) },
		  cc = { Brightness = 0.01, Contrast = 0.1, Saturation = -0.35, TintColor = rgb(255, 226, 192) },
		  bloom = { Intensity = 0.3, Size = 20, Threshold = 1.8 } },
	}
	Ext.TIMES, Ext.SKIES, Ext.SHADERS = TIMES, SKIES, SHADERS

	local function idxFmt(tbl)
		return function(i)
			return T(tbl[i].name)
		end
	end

	-- céu: tira o céu/atmosfera do jogo e coloca um estilo próprio
	local SKY = { moved = {}, atmo = nil }
	local function skyOff()
		if SKY.atmo then
			SKY.atmo:Destroy()
			SKY.atmo = nil
		end
		for inst, parent in pairs(SKY.moved) do
			pcall(function()
				inst.Parent = parent
			end)
		end
		table.clear(SKY.moved)
	end
	local function skyOn()
		skyOff()
		for _, d in ipairs(Lighting:GetChildren()) do
			if (d:IsA("Sky") or d:IsA("Atmosphere")) and not d:GetAttribute("SillyFx") then
				SKY.moved[d] = d.Parent
				d.Parent = nil
			end
		end
		local style = SKIES[Ext.sky]
		if style and style.atmo then
			local a = Instance.new("Atmosphere")
			for k, v in pairs(style.atmo) do
				a[k] = v
			end
			a:SetAttribute("SillyFx", true)
			a.Parent = Lighting
			SKY.atmo = a
		end
		return true
	end

	-- "shaders": efeitos de pós-processamento próprios
	local SH = { fx = {} }
	function Ext.makeShader(style, store)
		local function add(class, props)
			local ok, e = pcall(function()
				local x = Instance.new(class)
				for k, v in pairs(props) do
					x[k] = v
				end
				x:SetAttribute("SillyFx", true)
				x.Parent = Lighting
				return x
			end)
			if ok then
				table.insert(store, e)
			end
		end
		if style.cc then
			add("ColorCorrectionEffect", style.cc)
		end
		if style.bloom then
			add("BloomEffect", style.bloom)
		end
		if style.rays then
			add("SunRaysEffect", style.rays)
		end
		if style.dof then
			add("DepthOfFieldEffect", style.dof)
		end
	end
	local function shaderOff()
		for _, e in ipairs(SH.fx) do
			pcall(function()
				e:Destroy()
			end)
		end
		table.clear(SH.fx)
	end
	local function shaderOn()
		shaderOff()
		Ext.makeShader(SHADERS[Ext.shader], SH.fx)
		return #SH.fx > 0
	end

	-- FOV: reaplica se o jogo mudar, e acompanha troca de câmera
	local FOV = { conns = {}, cam = nil, orig = nil, guard = false }
	local function fovSet()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		if FOV.cam ~= cam then
			if FOV.camConn then
				FOV.camConn:Disconnect()
			end
			FOV.cam, FOV.orig = cam, cam.FieldOfView
			FOV.camConn = cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
				if FOV.guard or not Active.vis_fov then
					return
				end
				if math.abs(cam.FieldOfView - Ext.fov) > 0.05 then
					FOV.orig = cam.FieldOfView
					FOV.guard = true
					cam.FieldOfView = Ext.fov
					FOV.guard = false
				end
			end)
		end
		FOV.guard = true
		cam.FieldOfView = Ext.fov
		FOV.guard = false
	end
	local function fovOn()
		fovSet()
		table.insert(FOV.conns, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			task.defer(fovSet)
		end))
		return Workspace.CurrentCamera ~= nil
	end
	local function fovOff()
		for _, c in ipairs(FOV.conns) do
			c:Disconnect()
		end
		table.clear(FOV.conns)
		if FOV.camConn then
			FOV.camConn:Disconnect()
			FOV.camConn = nil
		end
		if FOV.cam and FOV.orig then
			pcall(function()
				FOV.cam.FieldOfView = FOV.orig
			end)
		end
		FOV.cam, FOV.orig = nil, nil
	end

	-- destaque de jogadores (Highlight, sem atravessar paredes)
	local HL_COLORS = { { "Salmão", C.Salmon }, { "Pêssego", C.Peach }, { "Amarelo", C.Gold }, { "Rosa", C.Pink }, { "Branco", C.White } }
	local HL_ALPHA = { 0.2, 0.35, 0.5 }
	Ext.HL_COLORS, Ext.HL_ALPHA = HL_COLORS, HL_ALPHA
	local HLS = { list = setmetatable({}, { __mode = "k" }), conns = {} }
	local function hlStyle(h)
		local col = HL_COLORS[Ext.hl.color][2]
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		if Ext.hl.mode == 1 then
			h.FillTransparency = 1
			h.OutlineTransparency = 0
			h.OutlineColor = col
		else
			h.FillColor = col
			h.FillTransparency = 1 - HL_ALPHA[Ext.hl.alpha]
			h.OutlineTransparency = 1
		end
	end
	local function hlChar(char)
		if HLS.list[char] then
			HLS.list[char]:Destroy()
		end
		local h = Instance.new("Highlight")
		h.Name = "SillyHighlight"
		h:SetAttribute("SillyFx", true)
		h.Adornee = char
		hlStyle(h)
		h.Parent = char
		HLS.list[char] = h
	end
	local function hlPlr(plr)
		if plr == LocalPlayer then
			return
		end
		if plr.Character then
			hlChar(plr.Character)
		end
		table.insert(HLS.conns, plr.CharacterAdded:Connect(hlChar))
	end
	local function hlOn()
		for _, plr in ipairs(Players:GetPlayers()) do
			hlPlr(plr)
		end
		table.insert(HLS.conns, Players.PlayerAdded:Connect(hlPlr))
		return true
	end
	local function hlOff()
		for _, c in ipairs(HLS.conns) do
			c:Disconnect()
		end
		table.clear(HLS.conns)
		for _, h in pairs(HLS.list) do
			pcall(function()
				h:Destroy()
			end)
		end
		table.clear(HLS.list)
	end
	function Ext.hlRestyle()
		for _, h in pairs(HLS.list) do
			if h.Parent then
				hlStyle(h)
			end
		end
	end

	local function playerT()
		return LocalPlayer
	end

	VISUAL_OPTIONS = {
		{ id = "vis_time", cat = "AMBIENTE", title = "Horário do dia",
		  desc = "Troca o horário só para você",
		  choices = { 1, 2, 3, 4, 5 }, choiceIndex = 2, fmt = idxFmt(TIMES),
		  onChoice = function(v)
			  Ext.time = v
			  Hooks.reapply(ById.vis_time)
		  end,
		  targets = { { lightingT, function()
			  return { ClockTime = TIMES[Ext.time].v }
		  end } } },
		{ id = "vis_fullbright", cat = "AMBIENTE", title = "Fullbright",
		  desc = "Tudo iluminado, sem cantos escuros",
		  targets = { { lightingT, {
			  Brightness = 2,
			  Ambient = rgb(178, 178, 178),
			  OutdoorAmbient = rgb(178, 178, 178),
			  ExposureCompensation = 0,
		  } } } },
		{ id = "vis_sky", cat = "AMBIENTE", title = "Trocar o céu",
		  desc = "Tira o céu do jogo e aplica um estilo",
		  choices = { 1, 2, 3, 4, 5 }, choiceIndex = 2, fmt = idxFmt(SKIES),
		  onChoice = function(v)
			  Ext.sky = v
			  if Active.vis_sky then
				  skyOn()
			  end
		  end,
		  custom = { on = skyOn, off = skyOff } },
		{ id = "vis_shader", cat = "AMBIENTE", title = "Shaders",
		  desc = "Cor, brilho e raios de sol mais bonitos (pesa no FPS)",
		  choices = { 1, 2, 3, 4, 5 }, choiceIndex = 1, fmt = idxFmt(SHADERS),
		  onChoice = function(v)
			  Ext.shader = v
			  if Active.vis_shader then
				  shaderOn()
			  end
		  end,
		  custom = { on = shaderOn, off = shaderOff } },

		{ id = "vis_fov", cat = "CÂMERA", title = "Campo de visão (FOV)",
		  desc = "Pode atrapalhar a mira com zoom de alguns jogos",
		  choices = { 70, 80, 90, 100, 110, 120 }, choiceIndex = 3,
		  fmt = function(v)
			  return v .. "°"
		  end,
		  onChoice = function(v)
			  Ext.fov = v
			  if Active.vis_fov then
				  fovSet()
			  end
		  end,
		  custom = { on = fovOn, off = fovOff } },
		{ id = "vis_nocollide", cat = "CÂMERA", title = "Câmera sem colisão",
		  desc = "Paredes ficam transparentes em vez de empurrar a câmera",
		  blockedText = "Este jogo controla a câmera",
		  targets = { { playerT, { DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam } } } },
		{ id = "vis_zoom", cat = "CÂMERA", title = "Zoom máximo maior",
		  desc = "Deixa afastar mais a câmera",
		  blockedText = "Este jogo controla a câmera",
		  choices = { 200, 400, 1000 }, choiceIndex = 2,
		  fmt = function(v)
			  return v .. " studs"
		  end,
		  onChoice = function(v)
			  Ext.zoom = v
			  Hooks.reapply(ById.vis_zoom)
		  end,
		  targets = { { playerT, function()
			  return { CameraMaxZoomDistance = Ext.zoom }
		  end } } },

		{ id = "vis_highlight", cat = "JOGADORES", title = "Destaque de jogadores",
		  desc = "Só aparece em quem você já enxerga (não atravessa paredes)",
		  choices = { 1, 2 }, choiceIndex = 1,
		  fmt = function(v)
			  return v == 1 and T("Contorno") or T("Preenchido")
		  end,
		  onChoice = function(v)
			  Ext.hl.mode = v
			  Ext.hlRestyle()
		  end,
		  custom = { on = hlOn, off = hlOff } },
	}
	for _, opt in ipairs(VISUAL_OPTIONS) do
		register(opt)
	end

	-- PROTEÇÃO ---------------------------------------------------------------
	-- anti-fling: outros jogadores não te empurram, e giros absurdos são cancelados
	local FL = { conns = {}, safe = nil, saves = 0, coll = setmetatable({}, { __mode = "k" }) }
	local function flOn()
		table.insert(FL.conns, RunService.Stepped:Connect(function()
			for _, plr in ipairs(Players:GetPlayers()) do
				local ch = plr ~= LocalPlayer and plr.Character
				if ch then
					for _, p in ipairs(ch:GetChildren()) do
						if p:IsA("BasePart") and p.CanCollide then
							if FL.coll[p] == nil then
								FL.coll[p] = true
							end
							p.CanCollide = false
						end
					end
				end
			end
		end))
		table.insert(FL.conns, RunService.Heartbeat:Connect(function()
			local ch = LocalPlayer.Character
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end
			local av, lv = root.AssemblyAngularVelocity, root.AssemblyLinearVelocity
			if av.Magnitude > 60 or lv.Magnitude > 600 then
				root.AssemblyAngularVelocity = Vector3.zero
				root.AssemblyLinearVelocity = Vector3.zero
				if FL.safe then
					root.CFrame = FL.safe
				end
				FL.saves += 1
			elseif av.Magnitude < 15 and lv.Magnitude < 150 then
				FL.safe = root.CFrame
			end
		end))
		return true
	end
	local function flOff()
		for _, c in ipairs(FL.conns) do
			c:Disconnect()
		end
		table.clear(FL.conns)
		for p in pairs(FL.coll) do
			pcall(function()
				p.CanCollide = true
			end)
		end
		table.clear(FL.coll)
		FL.safe = nil
	end

	-- modo streamer: esconde nomes acima das cabeças e a lista de jogadores
	local STR = { store = {}, conns = {}, list = nil }
	local function strHum(h)
		if h:IsA("Humanoid") then
			if STR.store[h] == nil then
				STR.store[h] = h.DisplayDistanceType
			end
			h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	local function strChar(char)
		for _, d in ipairs(char:GetDescendants()) do
			pcall(strHum, d)
		end
		table.insert(STR.conns, char.DescendantAdded:Connect(function(d)
			pcall(strHum, d)
		end))
	end
	local function strPlr(plr)
		if plr.Character then
			strChar(plr.Character)
		end
		table.insert(STR.conns, plr.CharacterAdded:Connect(strChar))
	end
	local function strOn()
		Ext.streamer = true
		for _, plr in ipairs(Players:GetPlayers()) do
			strPlr(plr)
		end
		table.insert(STR.conns, Players.PlayerAdded:Connect(strPlr))
		pcall(function()
			STR.list = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		return true
	end
	local function strOff()
		Ext.streamer = false
		for _, c in ipairs(STR.conns) do
			c:Disconnect()
		end
		table.clear(STR.conns)
		for h, v in pairs(STR.store) do
			pcall(function()
				h.DisplayDistanceType = v
			end)
		end
		table.clear(STR.store)
		if STR.list ~= nil then
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, STR.list)
			end)
			STR.list = nil
		end
	end

	local protect = {
		{ id = "antifling", cat = "PROTEÇÃO", tab = "protect", title = "Anti-fling",
		  desc = "Ninguém consegue te arremessar encostando em você",
		  statusText = function()
			  return T("Ativo") .. " · " .. FL.saves .. " " .. T("arremessos bloqueados")
		  end,
		  custom = { on = flOn, off = flOff } },
		{ id = "antilag", cat = "PROTEÇÃO", tab = "protect", title = "Anti-lag de efeitos",
		  desc = "Limita partículas e feixes exagerados (inclusive dos outros)",
		  unit = { "efeito limitado", "efeitos limitados" },
		  classes = {
			  { "ParticleEmitter", function(inst)
				  if inst.Rate > 25 then
					  return { Rate = 25 }
				  end
			  end },
			  { "Beam", function(inst)
				  if inst.Segments > 10 then
					  return { Segments = 10 }
				  end
			  end },
		  } },
		{ id = "streamer", cat = "PRIVACIDADE", tab = "protect", title = "Modo streamer",
		  desc = "Esconde nomes, a lista de jogadores e o ID do servidor",
		  custom = { on = strOn, off = strOff } },
	}
	for _, opt in ipairs(protect) do
		register(opt)
	end
	PROTECT_LIST = { ById.antifling, ById.antiafk, ById.reconnect, ById.antilag, ById.streamer }
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
	Stat[opt.id].failed = 0
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

-- reaplica alvos quando uma escolha muda (horário, zoom, qualidade…)
Hooks.reapply = function(opt)
	if Active[opt.id] then
		applyTargets(opt)
	end
	if Hooks.changed then
		Hooks.changed()
	end
end

local function applyClassRules(inst, opt)
	for _, r in ipairs(opt.classes) do
		if inst:IsA(r[1]) and not (r.skip and r.skip(inst)) and not inst:GetAttribute("SillyFx") then
			local props = r[2]
			if type(props) == "function" then
				local ok, res = pcall(props, inst)
				props = ok and res or nil
			end
			if props then
				applyProps(opt.id, inst, props)
			end
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
		return T("Desligado"), "off"
	end
	if opt.custom then
		if s.ok == false then
			return T("Indisponível neste ambiente"), "warn"
		end
		if opt.statusText then
			local ok, t = pcall(opt.statusText)
			if ok and t then
				return t, "on"
			end
		end
		return T("Ativo"), "on"
	end
	if Scanning[id] then
		return T("Aplicando…"), "busy"
	end
	if opt.targets then
		if s.failed > 0 then
			return T(opt.blockedText or "Sem efeito neste jogo"), "warn"
		end
		return T("Ativo"), "on"
	end
	if s.items == 0 then
		return T("Ativo · nada disso neste mapa"), "on"
	end
	local unit = opt.unit or { "objeto", "objetos" }
	local t = T("Ativo") .. " · " .. fmtNum(s.items) .. " " .. T(s.items == 1 and unit[1] or unit[2])
	if s.failed > 0 then
		t = t .. " · " .. fmtNum(s.failed) .. " " .. T("bloqueados")
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
	if not opt.noPreset then
		potatoList[#potatoList + 1] = opt.id
	end
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

-- captura e aplica o estado de uma lista de opções (perfis, presets por jogo, galeria)
local FarmList = {}
for _, opt in ipairs(FARM_OPTIONS) do
	if opt.tab ~= "protect" then
		FarmList[#FarmList + 1] = opt
	end
end

function Ext.captureList(lst)
	local cap = { on = {}, choices = {} }
	for _, opt in ipairs(lst) do
		if Active[opt.id] then
			table.insert(cap.on, opt.id)
		end
		if opt.choices then
			cap.choices[opt.id] = opt.choices[opt.choiceIndex]
		end
	end
	return cap
end

function Ext.applyList(lst, cap)
	if type(cap) ~= "table" then
		return
	end
	local on = {}
	for _, id in ipairs(type(cap.on) == "table" and cap.on or {}) do
		on[id] = true
	end
	if type(cap.choices) == "table" then
		for _, opt in ipairs(lst) do
			local v = opt.choices and cap.choices[opt.id]
			if v ~= nil then
				setChoice(opt, v)
			end
		end
	end
	local map = {}
	for _, opt in ipairs(lst) do
		map[opt.id] = on[opt.id] == true and not opt.locked
	end
	setOptions(map)
end

function Ext.captureTweaks()
	local cap = Ext.captureList(OPTIONS)
	cap.preset = State.preset and State.preset.id or nil
	return cap
end

function Ext.applyTweaks(cap)
	if type(cap) ~= "table" then
		return
	end
	Ext.applyList(OPTIONS, cap)
	local found
	for _, p in ipairs(PRESETS) do
		if p.id == cap.preset then
			found = p
		end
	end
	State.preset = found
	if Hooks.changed then
		Hooks.changed()
	end
end

Splash.step("Lendo iluminação e terreno", 0.3)
do
	local ok, n = pcall(function()
		return #Workspace:GetDescendants()
	end)
	Splash.step(ok and (T("Mapeando o mundo") .. " · " .. fmtNum(n) .. " " .. T("objetos")) or "Mapeando o mundo", 0.46)
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
			Text = T(label),
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
		Text = T(cfg.text),
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
			b.Text = T(label)
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
	ZIndex = 48,
	Parent = Gui,
}, { list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center) })

local toastSerial = 0
local function toast(msg, color)
	-- avisos de erro sempre aparecem; os demais respeitam "Notificações"
	if Destroyed or (not Prefs.notify and color ~= C.Warn) then
		return
	end
	toastSerial += 1
	local kids = {}
	for _, c in ipairs(ToastHolder:GetChildren()) do
		if c:GetAttribute("Toast") then
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
	cg:SetAttribute("Toast", true)
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
local WIN_W, WIN_H = 760, 520
local SIDE_W, HEAD_H = 184, 96
local TAB_H, TAB_GAP = 36, 2

-- cada aba tem a própria cor de destaque (sempre pastel)
local TABS = {
	{ id = "home", name = "Home", kicker = "HOME", accent = C.Coral,
	  title = "Olá!", sub = "Seu resumo: conta, servidor, desempenho e amigos" },
	{ id = "presets", name = "Presets", kicker = "PRESETS", accent = C.Salmon,
	  title = "Desempenho em um toque", sub = "Escolha um nível ou deixe o benchmark decidir" },
	{ id = "tweaks", name = "Ajustes", kicker = "AJUSTES", accent = C.Gold,
	  title = "Ajustes individuais", sub = "Ligado = otimização aplicada · Desligado = visual original" },
	{ id = "farm", name = "Farm", kicker = "MODO FARM", accent = C.Peach,
	  title = "Deixe rodando leve", sub = "Fique no jogo gastando o mínimo de bateria e calor" },
	{ id = "server", name = "Server", kicker = "SERVER", accent = C.Butter,
	  title = "Servidor", sub = "Reentre, ache um servidor melhor ou chame amigos" },
	{ id = "visual", name = "Visual", kicker = "VISUAL", accent = C.Pink,
	  title = "Deixe do seu jeito", sub = "Horário, céu, shaders, câmera, destaque e print limpa" },
	{ id = "audio", name = "Áudio", kicker = "ÁUDIO", accent = C.Rose,
	  title = "Ouça o que importa", sub = "Mixer, realce de passos e combate, equalizador e voice" },
	{ id = "protect", name = "Proteção", kicker = "PROTEÇÃO", accent = C.Terra,
	  title = "Jogue tranquilo", sub = "Anti-fling, anti-AFK, reconexão e privacidade" },
	{ id = "hud", name = "HUD", kicker = "HUD", accent = C.Blush,
	  title = "Informações na tela", sub = "Escolha o que aparece no painel flutuante" },
	{ id = "config", name = "Configurações", kicker = "CONFIGURAÇÕES", accent = C.Apricot,
	  title = "Preferências", sub = "Idioma, notificações, salvamento e compatibilidade" },
}
local TI = {}
for i, t in ipairs(TABS) do
	TI[t.id] = i
end

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
}, { corner(22) })
make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, 24, 1, 0),
	BackgroundColor3 = C.Side,
	BorderSizePixel = 0,
	Parent = Sidebar,
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
	Size = UDim2.new(1, 0, 0, 64),
	BackgroundTransparency = 1,
	Active = true,
	Parent = Sidebar,
})
do
	local tile = brandTile(Brand, 36, 11, 20)
	tile.Position = UDim2.fromOffset(18, 16)
	text({ Text = "Silly", Font = F.Heavy, TextSize = 17, Position = UDim2.fromOffset(64, 15), Size = UDim2.fromOffset(100, 18), Parent = Brand })
	text({ Text = "Optimizer", TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(64, 34), Size = UDim2.fromOffset(100, 16), Parent = Brand })
end

local TabHolder = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 66),
	Size = UDim2.new(1, -24, 1, -112),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	CanvasSize = UDim2.fromOffset(0, #TABS * (TAB_H + TAB_GAP)),
	ScrollingDirection = Enum.ScrollingDirection.Y,
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

-- desenho decorativo de cada aba (canto do cabeçalho): dá identidade própria a cada uma
function Ext.buildMotif(page, tab)
	local col = tab.accent:Lerp(C.Bg, 0.45)
	local soft = tab.accent:Lerp(C.Bg, 0.7)
	local m = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 18),
		Size = UDim2.fromOffset(110, 64),
		BackgroundTransparency = 1,
		Parent = page,
	})
	local sc = make("UIScale", { Parent = m })
	local parts = {}
	local function box(x, y, w, h, color, r, rot)
		local f = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = rot or 0,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = m,
		}, { corner(r or "full") })
		parts[#parts + 1] = f
		return f
	end
	local function ring(x, y, d, color, th)
		local f = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(d, d),
			BackgroundTransparency = 1,
			Parent = m,
		}, { corner("full"), stroke(color, th or 2, 0) })
		parts[#parts + 1] = f
		return f
	end
	local id = tab.id
	if id == "home" then
		ring(80, 32, 60, soft, 2)
		ring(80, 32, 40, col, 2)
		box(80, 32, 12, 12, tab.accent)
		box(108, 10, 8, 8, col)
	elseif id == "presets" then
		for k = 1, 4 do
			box(40 + k * 14, 58 - k * 6, 9, k * 12, k == 4 and tab.accent or col, 3)
		end
	elseif id == "tweaks" then
		for k, x in ipairs({ 0.3, 0.75, 0.5 }) do
			box(70, 10 + k * 13, 70, 4, soft)
			box(35 + x * 70, 10 + k * 13, 10, 10, k == 2 and tab.accent or col)
		end
	elseif id == "farm" then
		box(70, 32, 46, 46, col)
		box(98, 16, 22, 22, tab.accent)
		box(104, 12, 18, 18, C.Bg:Lerp(tab.accent, 0.12))
	elseif id == "server" then
		for k = 1, 4 do
			box(48 + k * 13, 56 - k * 5, 8, k * 10, k <= 3 and tab.accent or soft, 3)
		end
		box(104, 50, 8, 8, col)
	elseif id == "visual" then
		local cs = { C.Gold, C.Peach, C.Salmon, C.Pink }
		for k, c2 in ipairs(cs) do
			box(28 + k * 16, 32, 34, 34, c2:Lerp(C.Bg, 0.35))
		end
	elseif id == "audio" then
		for k, h in ipairs({ 14, 30, 22, 40, 26, 34, 16 }) do
			box(22 + k * 11, 32, 6, h, k == 4 and tab.accent or col, 3)
		end
	elseif id == "protect" then
		box(78, 30, 44, 50, col, 14)
		box(70, 34, 4, 14, tab.accent, 2, -45)
		box(82, 30, 4, 24, tab.accent, 2, 40)
	elseif id == "hud" then
		for r = 0, 1 do
			for k = 0, 2 do
				box(48 + k * 24, 20 + r * 22, 20, 16, (r == 0 and k == 0) and tab.accent or col, 5)
			end
		end
	else
		for k = 0, 2 do
			box(78, 32, 8, 46, col, 3, k * 60)
		end
		box(78, 32, 30, 30, col)
		box(78, 32, 12, 12, C.Bg)
	end
	return m, sc, parts
end

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
	local motif, motifScale, motifParts = Ext.buildMotif(page, tab)
	text({ Text = tab.kicker, Font = F.Bold, TextSize = 11, TextColor3 = tab.accent, Position = UDim2.fromOffset(24, 22), Size = UDim2.new(1, -180, 0, 14), Parent = page })
	local titleLabel = text({ Text = tab.title, Font = F.Heavy, TextSize = 26, Position = UDim2.fromOffset(24, 38), Size = UDim2.new(1, -170, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd, Parent = page })
	text({ Text = tab.sub, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(24, 68), Size = UDim2.new(1, -60, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = page })
	TabUI[i].motif, TabUI[i].motifScale, TabUI[i].motifParts, TabUI[i].title = motif, motifScale, motifParts, titleLabel

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
				if page:IsA("CanvasGroup") then
					page.GroupTransparency = 0
				end
				page.Position = UDim2.fromOffset(SIDE_W, 0)
			else
				if page:IsA("CanvasGroup") then
					page.GroupTransparency = 1
				end
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
	-- animação de entrada: desenho do cabeçalho + cartões em cascata
	if not instant and not Prefs.reduceMotion then
		local t = TabUI[i]
		t.motifScale.Scale = 0.6
		t.motif.Rotation = -12
		tween(t.motifScale, 0.6, { Scale = 1 }, EASE.Back)
		tween(t.motif, 0.6, { Rotation = 0 }, EASE.Back)
		local kids = {}
		for _, k in ipairs(Bodies[i]:GetChildren()) do
			if k:IsA("GuiObject") and k.Visible then
				kids[#kids + 1] = k
			end
		end
		table.sort(kids, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		local n = 0
		for _, k in ipairs(kids) do
			local sc = k:FindFirstChildOfClass("UIScale")
			if sc then
				n += 1
				if n > 8 then
					break
				end
				sc.Scale = 0.94
				task.delay(n * 0.035, function()
					tween(sc, 0.45, { Scale = 1 }, EASE.Back)
				end)
			end
		end
		if Ext.TabEnter and Ext.TabEnter[i] then
			Ext.TabEnter[i]()
		end
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
	local tab, body = TABS[TI.presets], Bodies[TI.presets]
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

	TabTick[TI.presets] = function()
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

	-- cartão "feito para este jogo": benchmark + preset salvo por jogo
	do
		local GKEY = tostring(game.PlaceId)
		Ext.GKEY = GKEY
		local function entry()
			local e = Ext.Games[GKEY]
			if type(e) ~= "table" then
				e = {}
				Ext.Games[GKEY] = e
			end
			return e
		end
		local card = make("Frame", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 262),
			BackgroundColor3 = C.Surface:Lerp(A, 0.05),
			BorderSizePixel = 0,
			Parent = body,
		}, { corner(18) })
		local cst = stroke(C.White, 1.5, 0)
		cst.Parent = card
		make("UIGradient", { Rotation = 20, Color = BRAND, Parent = cst })
		make("UIScale", { Parent = card })
		text({ Text = "FEITO PARA ESTE JOGO", Font = F.Bold, TextSize = 11, TextColor3 = A, Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -36, 0, 14), Parent = card })
		local gameLabel = text({ Text = "…", Font = F.Heavy, TextSize = 18, Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -36, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		text({
			Text = "O benchmark testa o que pesa aqui e monta dois presets: Competitivo (visão limpa) e Desempenho (mais FPS). Texturas e materiais ficam com você.",
			TextSize = 12, TextColor3 = C.Sub, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(18, 58), Size = UDim2.new(1, -36, 0, 32), Parent = card,
		})

		-- três caixinhas: original / competitivo / desempenho
		local boxes = {}
		local BOX = { { "Original", nil }, { "Competitivo", "competitive" }, { "Desempenho", "performance" } }
		for k, info in ipairs(BOX) do
			local b = make("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Position = UDim2.new((k - 1) / 3, k == 1 and 18 or 6, 0, 98),
				Size = UDim2.new(1 / 3, k == 1 and -24 or (k == 3 and -24 or -12), 0, 60),
				BackgroundColor3 = C.Surface2,
				BorderSizePixel = 0,
				Parent = card,
			}, { corner(12) })
			local bst = stroke(C.Stroke, 1, 0)
			bst.Parent = b
			text({ Text = info[1], Font = F.Bold, TextSize = 11, TextColor3 = C.Dim, Position = UDim2.fromOffset(12, 9), Size = UDim2.new(1, -24, 0, 14), Parent = b })
			local v = text({ Text = "—", Font = F.Heavy, TextSize = 20, Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 24), Parent = b })
			boxes[k] = { btn = b, value = v, stroke = bst, key = info[2] }
		end

		local benchBtn = Button(card, { text = "Iniciar benchmark", style = "filled", accent = A, size = UDim2.new(0.5, -24, 0, 34), position = UDim2.fromOffset(18, 170) })
		local saveBtn = Button(card, { text = "Salvar ajustes atuais", style = "tinted", accent = A, size = UDim2.new(0.5, -24, 0, 34), anchor = Vector2.new(1, 0), position = UDim2.new(1, -18, 0, 170) })

		-- progresso do teste (aparece no lugar dos botões)
		local prog = make("Frame", { Position = UDim2.fromOffset(18, 166), Size = UDim2.new(1, -36, 0, 42), BackgroundTransparency = 1, Visible = false, Parent = card })
		local progText = text({ Text = "", Font = F.Bold, TextSize = 12, TextColor3 = C.Text, Size = UDim2.new(1, -110, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = prog })
		local progTrack = make("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -110, 0, 6), BackgroundColor3 = C.Surface2, BorderSizePixel = 0, Parent = prog }, { corner("full") })
		local progFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.White, BorderSizePixel = 0, Parent = progTrack }, { corner("full"), make("UIGradient", { Color = BRAND }) })
		local cancelBtn = Button(prog, { text = "Cancelar", style = "ghost", size = UDim2.fromOffset(96, 32), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, 0, 0.5, 0) })

		text({ Text = "Ao entrar neste jogo", Font = F.Bold, TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(18, 222), Size = UDim2.new(0.4, -18, 0, 28), Parent = card })
		local AUTO = { false, "competitive", "performance", "custom" }
		local autoSeg
		autoSeg = Segmented(card, {
			items = { "Nada", "Competitivo", "Desempenho", "Meu preset" },
			accent = A,
			size = UDim2.new(0.6, -18, 0, 32),
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -18, 0, 220),
			onChange = function(i)
				local e = entry()
				local key = AUTO[i]
				if key and type(e[key]) ~= "table" then
					toast(key == "custom" and "Salve um preset para este jogo primeiro" or "Rode o benchmark primeiro", C.Warn)
					autoSeg.Set(1, true)
					e.auto = nil
					return
				end
				e.auto = key or nil
				if key then
					toast("Será aplicado sozinho quando você entrar neste jogo", A)
				end
				scheduleSave()
			end,
		})

		local function paint()
			local e = Ext.Games[GKEY]
			local fps = e and type(e.fps) == "table" and e.fps or {}
			local vals = { fps.base, fps.comp, fps.perf }
			for k, bx in ipairs(boxes) do
				local v = vals[k]
				bx.value.Text = v and (math.floor(v + 0.5) .. " FPS") or "—"
				if k > 1 and v and vals[1] then
					local pct = math.floor((v / math.max(vals[1], 1) - 1) * 100 + 0.5)
					bx.value.Text = bx.value.Text .. (pct >= 0 and ("  +" .. pct .. "%") or ("  " .. pct .. "%"))
				end
				bx.value.TextColor3 = (k > 1 and v) and A or C.Text
			end
			local idx = 1
			for i2, key in ipairs(AUTO) do
				if key and e and e.auto == key then
					idx = i2
				end
			end
			autoSeg.Set(idx, true)
		end

		for k, bx in ipairs(boxes) do
			if bx.key then
				bx.btn.Activated:Connect(function()
					local e = Ext.Games[GKEY]
					if not e or type(e[bx.key]) ~= "table" then
						toast("Rode o benchmark primeiro", C.Warn)
						return
					end
					Ext.applyTweaks(e[bx.key])
					burst(card, UDim2.new((k - 0.5) / 3, 0, 0, 128), 6, 40)
					toast(T("Preset") .. " " .. T(BOX[k][1]) .. " " .. T("aplicado"), A)
				end)
			end
		end

		saveBtn.Activated:Connect(function()
			local e = entry()
			e.custom = Ext.captureTweaks()
			e.auto = "custom"
			e.name = Ext.gameName
			paint()
			scheduleSave()
			burst(card, UDim2.new(0.75, 0, 0, 186), 6, 40)
			toast("Preset salvo para este jogo", A)
		end)

		-- benchmark -------------------------------------------------------
		local GROUPS = {
			{ name = "Sombras", ids = { "shadows", "part_shadows" } },
			{ name = "Pós-processamento", ids = { "post_fx" } },
			{ name = "Partículas e fogo", ids = { "particles", "fire_smoke" } },
			{ name = "Luzes e atmosfera", ids = { "lights", "atmosphere", "reflections" } },
			{ name = "Água e grama", ids = { "water_waves", "water_reflect", "grass" } },
			{ name = "Malhas e brilho", ids = { "mesh_fidelity", "reflectance" } },
			{ name = "Qualidade gráfica", ids = { "quality" }, quality = 3 },
		}
		-- o que atrapalha a visão em jogo competitivo (sempre sai do Competitivo)
		local CLARITY = { "fog", "post_fx", "particles", "fire_smoke", "atmosphere", "reflections", "water_waves", "reverb", "sky" }
		-- nunca entram nos presets gerados (o jogador decide em Ajustes)
		local NEVER = { materials = true, textures = true, render_dist = true, fps_unlock = true }

		local bench = { running = false, token = 0 }
		local function setRunning(v)
			bench.running = v
			prog.Visible = v
			benchBtn.inst.Visible = not v
			saveBtn.inst.Visible = not v
		end
		local function measure(sec)
			local frames = 0
			local conn = RunService.RenderStepped:Connect(function()
				frames += 1
			end)
			local t0 = os.clock()
			task.wait(sec)
			conn:Disconnect()
			return frames / math.max(os.clock() - t0, 0.01)
		end
		local function step(msg, p)
			progText.Text = msg
			tween(progFill, 0.4, { Size = UDim2.fromScale(p, 1) })
		end
		local function capOf(ids, quality)
			local list = {}
			local seen = {}
			for _, id in ipairs(ids) do
				if not seen[id] and ById[id] and not NEVER[id] then
					seen[id] = true
					list[#list + 1] = id
				end
			end
			return { on = list, choices = { quality = quality or 3 } }
		end

		local function run()
			bench.token += 1
			local my = bench.token
			local function alive()
				return bench.token == my and not Destroyed
			end
			setRunning(true)
			local snapshot = Ext.captureTweaks()
			local all = {}
			for _, opt in ipairs(OPTIONS) do
				all[opt.id] = false
			end
			if Env.setfpscap then
				pcall(Env.setfpscap, 999) -- sem limite para medir de verdade
			end
			State.preset = nil
			setOptions(all)
			step(T("Medindo o jogo original"), 0.05)
			task.wait(1)
			local base = measure(2.5)
			local results = {}
			for gi, g in ipairs(GROUPS) do
				if not alive() then
					break
				end
				step(T("Testando") .. ": " .. T(g.name), 0.08 + gi / #GROUPS * 0.62)
				if g.quality then
					setChoice(ById.quality, g.quality)
				end
				local on = {}
				for _, id in ipairs(g.ids) do
					on[id] = true
				end
				setOptions(on)
				task.wait(0.9)
				local fps = measure(1.6)
				local items = 0
				for _, id in ipairs(g.ids) do
					items += Stat[id].items
				end
				results[gi] = { gain = fps - base, items = items }
				local off = {}
				for _, id in ipairs(g.ids) do
					off[id] = false
				end
				setOptions(off)
				task.wait(0.3)
			end
			if not alive() then
				Ext.applyTweaks(snapshot)
				Fps.apply(Active)
				setRunning(false)
				return
			end
			-- decide: o que pesa de verdade neste jogo
			local threshold = math.max(1, base * 0.03)
			local capped = base >= 57 and not Env.setfpscap -- já no limite: decide pela quantidade de efeitos
			local function heavy(gi)
				local r = results[gi]
				return r and (r.gain >= threshold or (capped and r.items >= 25))
			end
			local comp = table.clone(CLARITY)
			local perf = table.clone(CLARITY)
			local qualityHeavy = false
			for gi, g in ipairs(GROUPS) do
				if g.quality then
					qualityHeavy = heavy(gi)
				elseif heavy(gi) then
					for _, id in ipairs(g.ids) do
						table.insert(comp, id)
					end
				end
				for _, id in ipairs(g.ids) do
					if id ~= "quality" then
						table.insert(perf, id)
					end
				end
			end
			for _, id in ipairs({ "anim_others", "accessories", "quality" }) do
				table.insert(perf, id)
			end
			if qualityHeavy then
				table.insert(comp, "quality")
			end
			local compCap = capOf(comp, 5)
			local perfCap = capOf(perf, base < 40 and 1 or 3)

			step(T("Medindo o preset Competitivo"), 0.8)
			Ext.applyTweaks(compCap)
			task.wait(1)
			local compFps = alive() and measure(2) or nil
			step(T("Medindo o preset Desempenho"), 0.92)
			Ext.applyTweaks(perfCap)
			task.wait(1)
			local perfFps = alive() and measure(2) or nil

			Ext.applyTweaks(snapshot)
			Fps.apply(Active)
			setRunning(false)
			if not alive() or not compFps or not perfFps then
				return
			end
			local e = entry()
			e.competitive, e.performance = compCap, perfCap
			e.fps = { base = base, comp = compFps, perf = perfFps }
			e.name = Ext.gameName
			paint()
			scheduleSave()
			burst(card, UDim2.new(0.5, 0, 0, 128), 12, 120)
			toast(capped and "Benchmark pronto · o jogo já estava no limite de FPS, a escolha usou a quantidade de efeitos" or "Benchmark pronto · toque num resultado para aplicar", A)
		end

		benchBtn.Activated:Connect(function()
			if not bench.running then
				task.spawn(run)
			end
		end)
		cancelBtn.Activated:Connect(function()
			bench.token += 1
			step(T("Cancelando…"), 1)
		end)

		Ext.refreshGameCard = function()
			gameLabel.Text = Ext.gameName ~= "" and Ext.gameName or T("Este jogo")
			paint()
		end
		paint()
	end

	Section(body, 3, "ESCOLHA UM NÍVEL", A)

	local grid = make("Frame", {
		LayoutOrder = 4,
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
			Text = #p.list .. " " .. T("ajustes") .. " · " .. T("qualidade") .. " " .. p.quality,
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
				toast(T("Preset") .. " " .. p.name .. " " .. T("aplicado"), p.accent)
			end
		end)
		cards[i] = { preset = p, card = card, stroke = st, btn = btn, pill = activePill, activeText = activeText, wasOn = false }
	end

	table.insert(Refreshers, function()
		for _, c in ipairs(cards) do
			c.card.Visible = not Prefs.hiddenPresets[c.preset.id]
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
	local strip = Row(body, 5, { title = "Restaurar padrão", desc = "Desliga todos os ajustes e devolve o visual original", accent = A, rightWidth = 130, pressable = false })
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
		LayoutOrder = 6,
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
	local tab, body = TABS[TI.tweaks], Bodies[TI.tweaks]
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
	local count = text({ Text = "0 " .. T("de") .. " " .. #OPTIONS, Font = F.Heavy, TextSize = 26, Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -180, 0, 30), Parent = summary })
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
			search = string.lower(T(opt.title) .. " " .. T(opt.desc) .. " " .. opt.title),
		})
	end

	-- limpar memória (fica fora do filtro de busca)
	do
		local memHeader = Section(body, nextOrder(), "MEMÓRIA", A)
		local memRow = Row(body, nextOrder(), {
			title = "Limpar memória",
			desc = "Libera o cache do script e o que o executor permitir",
			accent = A,
			rightWidth = 130,
			pressable = false,
		})
		headers.__mem = memHeader
		rows[#rows + 1] = { frame = memRow.frame, id = "__mem", cat = "__mem", search = string.lower(T("Limpar memória") .. " memoria ram cache") }
		local busy = false
		Button(memRow.frame, {
			text = "Limpar",
			style = "tinted",
			accent = A,
			size = UDim2.fromOffset(100, 34),
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -16, 0.5, 0),
		}).Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			task.spawn(function()
				local function mem()
					local ok, v = pcall(function()
						return Stats:GetTotalMemoryUsageMb()
					end)
					return ok and v or 0
				end
				local before = mem()
				-- referências a objetos que já sumiram
				for _, store in pairs(Saved) do
					for inst in pairs(store) do
						if not inst.Parent then
							store[inst] = nil
						end
					end
				end
				for snd, rec in pairs(Audio.recs) do
					if not snd.Parent then
						if rec.conn then
							rec.conn:Disconnect()
						end
						Audio.recs[snd] = nil
					end
				end
				pcall(function()
					collectgarbage("collect") -- só funciona em executores que liberam isso
				end)
				task.wait(1.5)
				local after = mem()
				busy = false
				toast(T("Memória") .. ": " .. fmtNum(before) .. " MB → " .. fmtNum(after) .. " MB", A)
			end)
		end)
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
			count.Text = n .. " " .. T("de") .. " " .. #OPTIONS
			tween(pfill, 0.45, { Size = UDim2.fromScale(n / #OPTIONS, 1) })
		end
	end)
end

--------------------------------------------------------------------------
-- ABA 3 · FARM
--------------------------------------------------------------------------
do
	local tab, body = TABS[TI.farm], Bodies[TI.farm]
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
		Text = T("Início rápido liga: Anti-AFK, Reconectar, Parar 3D, Silenciar") .. (Env.setfpscap and (" " .. T("e 15 FPS")) or ""),
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
		for _, opt in ipairs(FarmList) do
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
	for _, opt in ipairs(FarmList) do
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
	TabTick[TI.farm] = function()
		local on = FarmSince ~= nil
		timer.Text = formatDuration(on and (os.clock() - FarmSince) or 0)
		local n = countActive(FarmList)
		caption.Text = n .. " " .. T("de") .. " " .. #FarmList .. " " .. T(n == 1 and "recurso ligado" or "recursos ligados")
		if on ~= wasOn then
			wasOn = on
			stateL.Text = T(on and "Farm ativo" or "Farm desligado")
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
	table.insert(Refreshers, TabTick[TI.farm])
end

--------------------------------------------------------------------------
-- HUD (painel flutuante)
--------------------------------------------------------------------------
local OVERLAYS = {
	{ id = "fps", label = "FPS", title = "FPS", desc = "Quadros por segundo", default = true },
	{ id = "ping", label = "PING", title = "Ping", desc = "Latência até o servidor", default = true },
	{ id = "server", label = "SERVIDOR", title = "Distância do servidor", desc = "Estimativa pela latência (o Roblox não informa a região)", default = false },
	{ id = "stability", label = "ESTABILIDADE", title = "Lag do servidor", desc = "Mostra se a conexão com o servidor está oscilando", default = false },
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
		return T("medindo…"), C.Dim
	end
	if Country == "BR" then
		if ping <= 80 then
			return T("perto · provável BR"), C.Good
		end
		if ping <= 140 then
			return T("meio longe · talvez fora do BR"), C.Gold
		end
		return T("longe · provável fora do BR"), C.Warn
	end
	if ping <= 80 then
		return T("perto de você"), C.Good
	end
	if ping <= 140 then
		return T("distância média"), C.Gold
	end
	return T("longe de você"), C.Warn
end

-- estabilidade: variação do ping entre as últimas medições
function Ext.stability()
	local p = Ext.pings
	if #p < 4 then
		return T("medindo…"), C.Dim, 0
	end
	local mean, diff = 0, 0
	for i, v in ipairs(p) do
		mean += v
		if i > 1 then
			diff += math.abs(v - p[i - 1])
		end
	end
	mean /= #p
	local jitter = diff / (#p - 1)
	if mean > 250 or jitter > 35 then
		return T("Com lag"), C.Warn, jitter
	end
	if jitter > 12 then
		return T("Oscilando"), C.Gold, jitter
	end
	return T("Estável"), C.Good, jitter
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
		texts.server = hudLine(T("SERVIDOR"), st, sc)
	end
	if OverlayOn.stability then
		local st, sc = Ext.stability()
		texts.stability = hudLine(T("ESTABILIDADE"), st, sc)
	end
	if OverlayOn.ram then
		local okm, mem = pcall(function()
			return Stats:GetTotalMemoryUsageMb()
		end)
		texts.ram = hudLine("RAM", okm and (fmtNum(mem) .. " MB") or "—")
	end
	texts.frametime = hudLine(T("QUADRO"), string.format("%.1f ms", frameMs))
	texts.players = hudLine(T("JOGADORES"), #Players:GetPlayers() .. "/" .. Players.MaxPlayers)
	texts.preset = hudLine("PRESET", State.preset and State.preset.name or T("nenhum"), State.preset and State.preset.accent or C.Dim)
	if OverlayOn.clock then
		local okc, clock = pcall(function()
			return DateTime.now():FormatLocalTime("HH:mm", "pt-br")
		end)
		texts.clock = hudLine(T("HORA"), okc and clock or "—")
	end
	texts.farm = hudLine("FARM", FarmSince and formatDuration(os.clock() - FarmSince) or T("desligado"), FarmSince and C.Peach or C.Dim)
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
	local tab, body = TABS[TI.hud], Bodies[TI.hud]
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
-- COMPONENTES EXTRAS (cartões das abas novas)
--------------------------------------------------------------------------
function Ext.card(parent, order, h, auto)
	local f = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, h or 0),
		AutomaticSize = auto and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner(16) })
	local st = stroke(C.Stroke, 1, 0)
	st.Parent = f
	make("UIScale", { Parent = f })
	return f, st
end

function Ext.kicker(parent, txt, color, order)
	return text({
		LayoutOrder = order or 0,
		Text = txt,
		Font = F.Bold,
		TextSize = 11,
		TextColor3 = color or C.Dim,
		Size = UDim2.new(1, 0, 0, 14),
		Parent = parent,
	})
end

function Ext.chip(parent, order, txt, color)
	local p = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Surface:Lerp(color, 0.18),
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

function Ext.wrapList(parent, gap)
	local l = list(Enum.FillDirection.Horizontal, gap or 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	pcall(function()
		l.Wraps = true
	end)
	l.Parent = parent
	return l
end

-- nome do jogo (usado na Home, Server e no cartão de benchmark)
task.spawn(function()
	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
	end)
	if ok and type(info) == "table" and type(info.Name) == "string" then
		Ext.gameName = info.Name
	end
	if Ext.refreshGameCard then
		Ext.refreshGameCard()
	end
end)

--------------------------------------------------------------------------
-- ABA · HOME
--------------------------------------------------------------------------
do
	local tab, body = TABS[TI.home], Bodies[TI.home]
	local A = tab.accent
	local premium = false
	pcall(function()
		premium = LocalPlayer.MembershipType == Enum.MembershipType.Premium
	end)

	-- perfil
	local hero = make("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 128),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Parent = body,
	}, {
		corner(18),
		make("UIGradient", { Color = ColorSequence.new(C.Surface:Lerp(A, 0.16), C.Surface) }),
	})
	local heroStroke = stroke(C.Stroke, 1, 0)
	heroStroke.Parent = hero
	make("UIScale", { Parent = hero })
	local ring = make("Frame", {
		Position = UDim2.fromOffset(20, 22),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Parent = hero,
	}, { corner("full") })
	local ringStroke = stroke(C.White, 3, 0)
	ringStroke.Parent = ring
	local ringGrad = make("UIGradient", { Color = BRAND, Parent = ringStroke })
	local avatar = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 1, -10),
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Image = "",
		Parent = ring,
	}, { corner("full") })
	local nameL = text({ Text = "", Font = F.Heavy, TextSize = 22, Position = UDim2.fromOffset(122, 24), Size = UDim2.new(1, -262, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd, Parent = hero })
	local userL = text({ Text = "", TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(122, 52), Size = UDim2.new(1, -262, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = hero })
	local pills = make("Frame", { Position = UDim2.fromOffset(122, 78), Size = UDim2.new(1, -140, 0, 24), BackgroundTransparency = 1, Parent = hero })
	Ext.wrapList(pills, 6)
	local premiumPill = Ext.chip(pills, 1, "PREMIUM", C.Gold)
	premiumPill.Visible = premium
	local _, ageL = Ext.chip(pills, 2, "", C.Sub)
	local streamPill = Ext.chip(pills, 3, "MODO STREAMER", C.Terra)
	streamPill.Visible = false
	text({ Text = "SESSÃO", Font = F.Bold, TextSize = 11, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 26), Size = UDim2.fromOffset(120, 14), Parent = hero })
	local sessionL = text({ Text = "00:00:00", Font = F.Heavy, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 42), Size = UDim2.fromOffset(130, 24), Parent = hero })
	ageL.Text = T("Conta com") .. " " .. fmtNum(LocalPlayer.AccountAge) .. " " .. T("dias")
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and img then
			avatar.Image = img
		end
	end)
	Ext.homeSpin = TweenService:Create(ringGrad, TweenInfo.new(5, EASE.Linear, DIR.InOut, -1), { Rotation = 360 })

	-- números
	local grid = make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 74), CellPadding = UDim2.fromOffset(9, 9), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local STATS = {
		{ "fps", "FPS" }, { "ping", "PING" }, { "stab", "ESTABILIDADE" },
		{ "region", "SERVIDOR" }, { "players", "JOGADORES" }, { "mem", "MEMÓRIA" },
	}
	local statL = {}
	for k, st in ipairs(STATS) do
		local c = make("Frame", { LayoutOrder = k, BackgroundColor3 = C.Surface, BorderSizePixel = 0, Parent = grid }, { corner(14), stroke(C.Stroke, 1, 0) })
		make("Frame", { Position = UDim2.fromOffset(14, 15), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = A, BorderSizePixel = 0, Parent = c }, { corner("full") })
		text({ Text = st[2], Font = F.Bold, TextSize = 11, TextColor3 = C.Dim, Position = UDim2.fromOffset(26, 11), Size = UDim2.new(1, -36, 0, 14), Parent = c })
		statL[st[1]] = text({
			Text = "—",
			Font = F.Heavy,
			TextSize = (st[1] == "region" or st[1] == "stab") and 15 or 20,
			Position = UDim2.fromOffset(14, 32),
			Size = UDim2.new(1, -28, 0, 26),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = c,
		})
	end

	-- o que está ligado agora
	local using = Ext.card(body, 3, 0, true)
	pad(18, 16, 18, 16).Parent = using
	list(Enum.FillDirection.Vertical, 10).Parent = using
	Ext.kicker(using, "USANDO AGORA", A, 1)
	local chips = make("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = using })
	Ext.wrapList(chips, 6)
	local lastSig = ""
	local function refreshUsing()
		local out = {}
		if State.preset then
			out[#out + 1] = { "Preset " .. State.preset.name, State.preset.accent }
		end
		local n = countActive(OPTIONS)
		if n > 0 then
			out[#out + 1] = { n .. " " .. T(n == 1 and "ajuste" or "ajustes"), C.Gold }
		end
		if FarmSince then
			out[#out + 1] = { T("Farm ativo"), C.Peach }
		end
		local v = countActive(VISUAL_OPTIONS)
		if v > 0 then
			out[#out + 1] = { v .. " " .. T(v == 1 and "efeito visual" or "efeitos visuais"), C.Pink }
		end
		if Audio.needed() or Audio.mult.voice ~= 1 then
			out[#out + 1] = { T("Áudio personalizado"), C.Rose }
		end
		local pr = countActive(PROTECT_LIST)
		if pr > 0 then
			out[#out + 1] = { pr .. " " .. T(pr == 1 and "proteção" or "proteções"), C.Terra }
		end
		if Hud.Visible then
			out[#out + 1] = { T("HUD na tela"), C.Blush }
		end
		local sig = ""
		for _, o in ipairs(out) do
			sig ..= o[1] .. "|"
		end
		if sig == lastSig then
			return
		end
		lastSig = sig
		for _, c in ipairs(chips:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		if #out == 0 then
			Ext.chip(chips, 1, T("Nada ligado ainda · experimente um preset"), C.Dim)
		end
		for k, o in ipairs(out) do
			local c = Ext.chip(chips, k, o[1], o[2])
			local sc = make("UIScale", { Scale = 0.8, Parent = c })
			tween(sc, 0.35, { Scale = 1 }, EASE.Back)
		end
	end

	-- amigos jogando agora
	local fr = Ext.card(body, 4, 0, true)
	pad(18, 16, 18, 16).Parent = fr
	list(Enum.FillDirection.Vertical, 8).Parent = fr
	local frHead = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = fr })
	text({ Text = "AMIGOS JOGANDO AGORA", Font = F.Bold, TextSize = 11, TextColor3 = A, Size = UDim2.new(1, -110, 1, 0), Parent = frHead })
	local refreshBtn = Button(frHead, { text = "Atualizar", style = "ghost", size = UDim2.fromOffset(96, 28), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, 0, 0.5, 0), textSize = 12 })
	local frList = make("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = fr }, { list(Enum.FillDirection.Vertical, 6) })
	local frEmpty = text({ LayoutOrder = 3, Text = "", TextSize = 12, TextColor3 = C.Dim, Size = UDim2.new(1, 0, 0, 20), Parent = fr })
	local loadingFriends = false
	local function loadFriends()
		if loadingFriends then
			return
		end
		loadingFriends = true
		for _, c in ipairs(frList:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		frEmpty.Text = T("Procurando amigos…")
		frEmpty.Visible = true
		task.spawn(function()
			local ok, friends = pcall(function()
				return LocalPlayer:GetFriendsOnline(50)
			end)
			loadingFriends = false
			if not ok or type(friends) ~= "table" then
				frEmpty.Text = T("Não foi possível carregar os amigos")
				return
			end
			local shown = 0
			for _, f in ipairs(friends) do
				local inGame = (f.LocationType == 4 or f.LocationType == 1) and f.PlaceId
				if inGame and shown < 6 then
					shown += 1
					local row = make("Frame", { LayoutOrder = shown, Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.Surface2, BorderSizePixel = 0, Parent = frList }, { corner(12) })
					local av = make("ImageLabel", { Position = UDim2.fromOffset(9, 8), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = C.Surface, BorderSizePixel = 0, Parent = row }, { corner("full") })
					local display = Ext.streamer and T("Amigo") or (f.DisplayName or f.UserName or "?")
					text({ Text = display, Font = F.Bold, TextSize = 14, Position = UDim2.fromOffset(54, 8), Size = UDim2.new(1, -170, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
					text({ Text = tostring(f.LastLocation or ""), TextSize = 12, TextColor3 = C.Dim, Position = UDim2.fromOffset(54, 26), Size = UDim2.new(1, -170, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
					local here = f.GameId ~= nil and f.GameId == game.JobId
					local canJoin = f.GameId ~= nil and not here
					local jb = Button(row, {
						text = here and "Aqui" or (canJoin and "Entrar" or "Privado"),
						style = canJoin and "filled" or "ghost",
						accent = A,
						size = UDim2.fromOffset(96, 32),
						anchor = Vector2.new(1, 0.5),
						position = UDim2.new(1, -9, 0.5, 0),
						textSize = 12,
					})
					jb.Activated:Connect(function()
						if not canJoin then
							return
						end
						toast(T("Entrando no servidor de") .. " " .. display .. "…", A)
						pcall(function()
							TeleportService:TeleportToPlaceInstance(f.PlaceId, f.GameId, LocalPlayer)
						end)
					end)
					task.spawn(function()
						local okT, img = pcall(function()
							return Players:GetUserThumbnailAsync(f.VisitorId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
						end)
						if okT and img then
							av.Image = img
						end
					end)
				end
			end
			frEmpty.Visible = shown == 0
			if shown == 0 then
				frEmpty.Text = T("Nenhum amigo jogando agora")
			end
		end)
	end
	refreshBtn.Activated:Connect(loadFriends)
	loadFriends()

	-- rodapé
	local foot = Ext.card(body, 5, 64)
	text({ Text = "Silly Optimizer v" .. VERSION, Font = F.Bold, TextSize = 14, Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -160, 0, 18), Parent = foot })
	text({ Text = T("por") .. " sillybuu · github.com/sillybuu/SillyOptimizer", TextSize = 11, TextColor3 = C.Dim, Position = UDim2.fromOffset(18, 34), Size = UDim2.new(1, -160, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = foot })
	Button(foot, { text = "Novidades", style = "tinted", accent = A, size = UDim2.fromOffset(116, 34), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -16, 0.5, 0) }).Activated:Connect(function()
		if Ext.openChangelog then
			Ext.openChangelog()
		end
	end)

	TabTick[TI.home] = function()
		local fps = math.floor(fpsValue + 0.5)
		statL.fps.Text = tostring(fps)
		statL.fps.TextColor3 = fpsColor(fps)
		local ping = getPing()
		statL.ping.Text = ping and (math.floor(ping + 0.5) .. " ms") or "—"
		statL.ping.TextColor3 = ping and (ping <= 80 and C.Good or (ping <= 150 and C.Gold or C.Warn)) or C.Dim
		local st, sc = Ext.stability()
		statL.stab.Text, statL.stab.TextColor3 = st, sc
		local rt, rc = serverEstimate(ping)
		statL.region.Text, statL.region.TextColor3 = rt, rc
		statL.players.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
		local okm, mem = pcall(function()
			return Stats:GetTotalMemoryUsageMb()
		end)
		statL.mem.Text = okm and (fmtNum(mem) .. " MB") or "—"
		sessionL.Text = formatDuration(os.clock() - Ext.sessionStart)
		if Ext.streamer then
			nameL.Text, userL.Text = T("Jogador"), "@••••••"
			TabUI[TI.home].title.Text = T("Olá!")
		else
			nameL.Text, userL.Text = LocalPlayer.DisplayName, "@" .. LocalPlayer.Name
			TabUI[TI.home].title.Text = T("Olá") .. ", " .. LocalPlayer.DisplayName .. "!"
		end
		streamPill.Visible = Ext.streamer == true
		refreshUsing()
	end
	table.insert(Refreshers, refreshUsing)
end

--------------------------------------------------------------------------
-- ABA · SERVER
--------------------------------------------------------------------------
do
	local tab, body = TABS[TI.server], Bodies[TI.server]
	local A = tab.accent

	track(TeleportService.TeleportInitFailed:Connect(function(plr, _, msg)
		if plr == LocalPlayer then
			toast(T("Não deu para entrar") .. ": " .. tostring(msg), C.Warn)
		end
	end))

	-- "ingresso" do servidor atual
	local ticket = Ext.card(body, 1, 150)
	ticket.BackgroundColor3 = C.Surface:Lerp(A, 0.05)
	text({ Text = "SERVIDOR ATUAL", Font = F.Bold, TextSize = 11, TextColor3 = A, Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -36, 0, 14), Parent = ticket })
	local gameL = text({ Text = "", Font = F.Heavy, TextSize = 20, Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -150, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, Parent = ticket })
	local jobL = text({ Text = "", Font = F.Bold, TextSize = 12, TextColor3 = C.Dim, Position = UDim2.fromOffset(18, 58), Size = UDim2.new(1, -150, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = ticket })
	-- picote do ingresso
	for k = 0, 20 do
		make("Frame", { Position = UDim2.new(k / 21, 8, 0, 86), Size = UDim2.fromOffset(8, 2), BackgroundColor3 = C.Stroke, BorderSizePixel = 0, Parent = ticket })
	end
	local cols = {}
	for k, lbl in ipairs({ "JOGADORES", "PING", "ESTABILIDADE", "ONLINE HÁ" }) do
		local x = (k - 1) / 4
		text({ Text = lbl, Font = F.Bold, TextSize = 10, TextColor3 = C.Dim, Position = UDim2.new(x, 18, 0, 100), Size = UDim2.new(0.25, -18, 0, 12), Parent = ticket })
		cols[k] = text({ Text = "—", Font = F.Heavy, TextSize = 16, Position = UDim2.new(x, 18, 0, 116), Size = UDim2.new(0.25, -18, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = ticket })
	end
	local regionPill, regionL = Pill(ticket, "", A, 18)
	regionPill.AnchorPoint = Vector2.new(1, 0)
	regionPill.Position = UDim2.new(1, -18, 0, 34)

	-- servidores públicos (precisa de HttpGet do executor)
	local function fetchServers()
		local all = {}
		local cursor = nil
		for _ = 1, 3 do
			local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
			if cursor then
				url ..= "&cursor=" .. cursor
			end
			local ok, bodyText = pcall(function()
				return game:HttpGet(url)
			end)
			if not ok then
				return nil, T("Precisa de executor (HttpGet)")
			end
			local ok2, data = pcall(function()
				return HttpService:JSONDecode(bodyText)
			end)
			if not ok2 or type(data) ~= "table" or type(data.data) ~= "table" then
				break
			end
			for _, sv in ipairs(data.data) do
				if type(sv) == "table" and sv.id ~= game.JobId and type(sv.playing) == "number" and type(sv.maxPlayers) == "number" and sv.playing < sv.maxPlayers then
					all[#all + 1] = sv
				end
			end
			cursor = type(data.nextPageCursor) == "string" and data.nextPageCursor or nil
			if not cursor then
				break
			end
		end
		return all
	end

	local resultsCard, resultsList, resultsEmpty
	local function join(sv)
		toast(T("Entrando no servidor…"), A)
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, sv.id, LocalPlayer)
		end)
	end
	local function showResults(title, servers)
		for _, c in ipairs(resultsList:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		resultsCard.kicker.Text = T(title)
		resultsEmpty.Visible = #servers == 0
		resultsEmpty.Text = T("Nenhum servidor livre encontrado")
		for k, sv in ipairs(servers) do
			if k > 5 then
				break
			end
			local row = make("Frame", { LayoutOrder = k, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.Surface2, BorderSizePixel = 0, Parent = resultsList }, { corner(12) })
			local sc = make("UIScale", { Scale = 0.9, Parent = row })
			task.delay(k * 0.05, function()
				tween(sc, 0.4, { Scale = 1 }, EASE.Back)
			end)
			text({ Text = "#" .. k, Font = F.Heavy, TextSize = 14, TextColor3 = A, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 34, 1, 0), Parent = row })
			local pingTxt = type(sv.ping) == "number" and (math.floor(sv.ping) .. " ms") or "— ms"
			text({ Text = pingTxt .. "  ·  " .. sv.playing .. "/" .. sv.maxPlayers .. " " .. T("jogadores"), Font = F.Bold, TextSize = 13, Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -170, 1, 0), Parent = row })
			Button(row, { text = "Entrar", style = "filled", accent = A, size = UDim2.fromOffset(92, 30), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -8, 0.5, 0), textSize = 12 }).Activated:Connect(function()
				join(sv)
			end)
		end
	end

	local searching = false
	local function search(kind)
		if searching then
			return
		end
		searching = true
		toast(T("Procurando servidores…"), A)
		task.spawn(function()
			local servers, err = fetchServers()
			searching = false
			if not servers then
				toast(err or T("Não foi possível listar os servidores"), C.Warn)
				return
			end
			if kind == "ping" then
				table.sort(servers, function(a, b)
					return (a.ping or 9999) < (b.ping or 9999)
				end)
				showResults("SERVIDORES COM MENOR PING", servers)
			else
				table.sort(servers, function(a, b)
					return a.playing < b.playing
				end)
				showResults("SERVIDORES MAIS VAZIOS", servers)
			end
			if servers[1] then
				join(servers[1])
			end
		end)
	end

	-- quatro ações em blocos
	local grid = make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	}, { make("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 92), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local TILES = {
		{ "Reentrar", "Volta para este mesmo servidor", function()
			toast(T("Reentrando…"), A)
			pcall(function()
				if #Players:GetPlayers() <= 1 then
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				else
					TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
				end
			end)
		end },
		{ "Menor ping", "Procura o servidor mais rápido para você", function()
			search("ping")
		end },
		{ "Mais vazio", "Entra no servidor com menos gente", function()
			search("empty")
		end },
		{ "Copiar link", "Para um amigo entrar no mesmo servidor", function()
			if not Env.setclipboard then
				toast("Precisa de executor (setclipboard)", C.Warn)
				return
			end
			local link = "roblox://experiences/start?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId
			pcall(Env.setclipboard, link)
			toast("Link do servidor copiado", A)
		end },
	}
	for k, t in ipairs(TILES) do
		local b = make("TextButton", { LayoutOrder = k, Text = "", AutoButtonColor = false, BackgroundColor3 = C.Surface, BorderSizePixel = 0, Parent = grid }, { corner(16) })
		local bst = stroke(C.Stroke, 1, 0)
		bst.Parent = b
		local sc = make("UIScale", { Parent = b })
		local icon = make("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = C.Surface:Lerp(A, 0.25), BorderSizePixel = 0, Parent = b }, { corner(8) })
		make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = A, BorderSizePixel = 0, Rotation = k * 22, Parent = icon }, { corner(k == 1 and "full" or 3) })
		text({ Text = t[1], Font = F.Heavy, TextSize = 16, Position = UDim2.fromOffset(52, 18), Size = UDim2.new(1, -64, 0, 20), Parent = b })
		text({ Text = t[2], TextSize = 12, TextColor3 = C.Sub, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -32, 0, 32), Parent = b })
		b.MouseEnter:Connect(function()
			tween(bst, 0.2, { Color = A })
		end)
		b.MouseLeave:Connect(function()
			tween(bst, 0.25, { Color = C.Stroke })
			tween(sc, 0.2, { Scale = 1 })
		end)
		b.InputBegan:Connect(function(i)
			if isPress(i) then
				tween(sc, 0.1, { Scale = 0.96 }, EASE.Quad)
			end
		end)
		b.InputEnded:Connect(function(i)
			if isPress(i) then
				tween(sc, 0.4, { Scale = 1 }, EASE.Back)
			end
		end)
		b.Activated:Connect(t[3])
	end

	-- resultados da busca
	local rc = Ext.card(body, 3, 0, true)
	pad(18, 16, 18, 16).Parent = rc
	list(Enum.FillDirection.Vertical, 8).Parent = rc
	resultsCard = { kicker = Ext.kicker(rc, "MELHORES SERVIDORES", A, 1) }
	resultsList = make("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = rc }, { list(Enum.FillDirection.Vertical, 6) })
	resultsEmpty = text({ LayoutOrder = 3, Text = "Toque em Menor ping ou Mais vazio para buscar", TextSize = 12, TextColor3 = C.Dim, TextWrapped = true, Size = UDim2.new(1, 0, 0, 20), Parent = rc })

	text({
		LayoutOrder = 4,
		Text = "A lista de servidores vem do próprio Roblox e precisa de executor (HttpGet). O ping de cada servidor é uma estimativa.",
		TextSize = 11, TextColor3 = C.Dim, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30), Parent = body,
	})

	TabTick[TI.server] = function()
		gameL.Text = Ext.gameName ~= "" and Ext.gameName or T("Este jogo")
		jobL.Text = "ID: " .. (Ext.streamer and "••••••••" or (game.JobId ~= "" and string.sub(game.JobId, 1, 18) .. "…" or T("servidor de teste")))
		local ping = getPing()
		cols[1].Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
		cols[2].Text = ping and (math.floor(ping + 0.5) .. " ms") or "—"
		local st, sc = Ext.stability()
		cols[3].Text, cols[3].TextColor3 = st, sc
		cols[4].Text = formatDuration(Workspace.DistributedGameTime)
		regionL.Text = (serverEstimate(ping))
	end
end

--------------------------------------------------------------------------
-- ABA · VISUAL
--------------------------------------------------------------------------
local SHOT_HOLDS = { 2, 3, 5 }
do
	local tab, body = TABS[TI.visual], Bodies[TI.visual]
	local A = tab.accent
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	-- prévia: céu conforme horário e estilo
	local preview = Ext.card(body, nextOrder(), 96)
	preview.BackgroundColor3 = C.White
	local previewGrad = make("UIGradient", { Rotation = 90, Parent = preview })
	local sun = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = C.Butter, BorderSizePixel = 0, Parent = preview }, { corner("full") })
	local hill = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = preview }, { corner(16) })
	local previewL = text({ Text = "", Font = F.Bold, TextSize = 12, TextColor3 = C.Text, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 0, 26), Parent = hill })
	local SKYCOL = {
		{ C.Peach, C.Blush }, { rgb(150, 196, 236), rgb(220, 236, 250) }, { C.Gold, C.Peach },
		{ C.Salmon, rgb(120, 90, 140) }, { rgb(24, 26, 44), rgb(60, 54, 90) },
	}
	local function paintPreview()
		local t = Active.vis_time and Ext.time or 2
		local cols = SKYCOL[t]
		local top, bottom = cols[1], cols[2]
		if Active.vis_sky and Ext.sky == 4 then
			top, bottom = C.Pink, C.Blush
		end
		if Active.vis_shader then
			local sw = Ext.SHADERS[Ext.shader].swatch
			top = top:Lerp(sw[1], 0.3)
			bottom = bottom:Lerp(sw[2], 0.3)
		end
		previewGrad.Color = ColorSequence.new(top, bottom)
		local x = ({ 0.2, 0.5, 0.7, 0.85, 0.5 })[t]
		local y = ({ 40, 24, 38, 56, 30 })[t]
		tween(sun, 0.6, { Position = UDim2.new(x, 0, 0, y), BackgroundColor3 = t == 5 and C.Apricot or C.Butter })
		local parts = {}
		parts[#parts + 1] = Active.vis_time and T(Ext.TIMES[Ext.time].name) or T("Horário do jogo")
		if Active.vis_sky then
			parts[#parts + 1] = T(Ext.SKIES[Ext.sky].name)
		end
		if Active.vis_shader then
			parts[#parts + 1] = T(Ext.SHADERS[Ext.shader].name)
		end
		if Active.vis_fullbright then
			parts[#parts + 1] = "Fullbright"
		end
		previewL.Text = table.concat(parts, "  ·  ")
	end
	table.insert(Refreshers, paintPreview)

	local lastCat
	for _, opt in ipairs(VISUAL_OPTIONS) do
		if opt.cat ~= lastCat then
			lastCat = opt.cat
			Section(body, nextOrder(), opt.cat, A)
		end
		optionRow(body, nextOrder(), opt, A, function(v)
			setOptions({ [opt.id] = v })
		end)
	end

	-- cor e opacidade do destaque
	local colorRow = Row(body, nextOrder(), { title = "Cor do destaque", desc = "Cor do contorno ou do preenchimento", accent = A, rightWidth = 150, pressable = false })
	Ext.hlColorStepper = Stepper(colorRow.frame, {
		choices = { 1, 2, 3, 4, 5 },
		index = Ext.hl.color,
		fmt = function(v)
			return T(Ext.HL_COLORS[v][1])
		end,
		onChange = function(v)
			Ext.hl.color = v
			Ext.hlRestyle()
			scheduleSave()
		end,
	}, A, 16)
	local alphaRow = Row(body, nextOrder(), { title = "Opacidade do preenchimento", desc = "Só vale no modo Preenchido", accent = A, rightWidth = 150, pressable = false })
	Ext.hlAlphaStepper = Stepper(alphaRow.frame, {
		choices = { 1, 2, 3 },
		index = Ext.hl.alpha,
		fmt = function(v)
			return math.floor(Ext.HL_ALPHA[v] * 100 + 0.5) .. "%"
		end,
		onChange = function(v)
			Ext.hl.alpha = v
			Ext.hlRestyle()
			scheduleSave()
		end,
	}, A, 16)

	-- galeria de visuais
	Section(body, nextOrder(), "GALERIA", A)
	local LOOK = { ById.vis_time, ById.vis_fullbright, ById.vis_sky, ById.vis_shader }
	local BUILTIN = {
		{ name = "Pôr do sol", cap = { on = { "vis_time", "vis_sky", "vis_shader" }, choices = { vis_time = 4, vis_sky = 3, vis_shader = 1 } } },
		{ name = "Noite neon", cap = { on = { "vis_time", "vis_sky", "vis_shader" }, choices = { vis_time = 5, vis_sky = 5, vis_shader = 4 } } },
		{ name = "Dia limpo", cap = { on = { "vis_time", "vis_sky", "vis_shader" }, choices = { vis_time = 2, vis_sky = 2, vis_shader = 2 } } },
		{ name = "Cinema", cap = { on = { "vis_time", "vis_shader" }, choices = { vis_time = 3, vis_shader = 3 } } },
	}
	local galleryWrap = make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body }, {
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 76), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function lookTile(k, look, custom)
		local b = make("TextButton", { LayoutOrder = k, Text = "", AutoButtonColor = false, BackgroundColor3 = C.Surface, BorderSizePixel = 0, Parent = galleryWrap }, { corner(14) })
		local bst = stroke(C.Stroke, 1, 0)
		bst.Parent = b
		local sc = make("UIScale", { Parent = b })
		-- amostra de cor do visual
		local ch = look.cap.choices or {}
		local t = ch.vis_time or 2
		local swatch = make("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C.White, BorderSizePixel = 0, Parent = b }, { corner(12) })
		local c1, c2 = SKYCOL[t][1], SKYCOL[t][2]
		if ch.vis_shader and Ext.SHADERS[ch.vis_shader] then
			c1 = c1:Lerp(Ext.SHADERS[ch.vis_shader].swatch[1], 0.35)
		end
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(c1, c2), Parent = swatch })
		text({ Text = custom and look.name or T(look.name), Font = F.Bold, TextSize = 14, Position = UDim2.fromOffset(76, 18), Size = UDim2.new(1, -112, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
		text({ Text = custom and "Salvo por você" or "Visual pronto", TextSize = 11, TextColor3 = C.Dim, Position = UDim2.fromOffset(76, 38), Size = UDim2.new(1, -112, 0, 14), Parent = b })
		b.Activated:Connect(function()
			Ext.applyList(LOOK, look.cap)
			burst(b, UDim2.fromOffset(38, 38), 6, 30)
			toast(T("Visual") .. " " .. (custom and look.name or T(look.name)) .. " " .. T("aplicado"), A)
		end)
		b.MouseEnter:Connect(function()
			tween(bst, 0.2, { Color = A })
		end)
		b.MouseLeave:Connect(function()
			tween(bst, 0.25, { Color = C.Stroke })
		end)
		b.InputBegan:Connect(function(i)
			if isPress(i) then
				tween(sc, 0.1, { Scale = 0.96 }, EASE.Quad)
			end
		end)
		b.InputEnded:Connect(function(i)
			if isPress(i) then
				tween(sc, 0.4, { Scale = 1 }, EASE.Back)
			end
		end)
		if custom then
			local del = make("TextButton", { Text = "×", Font = F.Bold, TextSize = 18, TextColor3 = C.Dim, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(28, 28), Parent = b })
			del.Activated:Connect(function()
				for i2, g in ipairs(Ext.Gallery) do
					if g == look then
						table.remove(Ext.Gallery, i2)
						break
					end
				end
				Ext.rebuildGallery()
				scheduleSave()
				toast("Visual apagado da galeria", C.Sub)
			end)
		end
	end
	function Ext.rebuildGallery()
		for _, c in ipairs(galleryWrap:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for k, look in ipairs(BUILTIN) do
			lookTile(k, look, false)
		end
		for k, look in ipairs(Ext.Gallery) do
			if type(look) == "table" and type(look.cap) == "table" then
				lookTile(100 + k, look, true)
			end
		end
	end
	Ext.rebuildGallery()

	local saveRow = Row(body, nextOrder(), { title = "Salvar visual atual", desc = "Horário, céu, shader e fullbright", accent = A, rightWidth = 260, pressable = false })
	local nameBox = make("TextBox", {
		Text = "",
		PlaceholderText = T("Nome do visual"),
		PlaceholderColor3 = C.Dim,
		Font = F.Semi,
		TextSize = 13,
		TextColor3 = C.Text,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -112, 0.5, 0),
		Size = UDim2.fromOffset(140, 34),
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Parent = saveRow.frame,
	}, { corner(10), pad(10, 0, 10, 0) })
	Button(saveRow.frame, { text = "Salvar", style = "filled", accent = A, size = UDim2.fromOffset(88, 34), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -16, 0.5, 0) }).Activated:Connect(function()
		local name = string.gsub(nameBox.Text, "^%s+", "")
		if name == "" then
			name = T("Meu visual") .. " " .. (#Ext.Gallery + 1)
		end
		table.insert(Ext.Gallery, { name = string.sub(name, 1, 24), cap = Ext.captureList(LOOK) })
		nameBox.Text = ""
		Ext.rebuildGallery()
		scheduleSave()
		toast(T("Visual salvo na galeria") .. ": " .. name, A)
	end)

	-- print limpa
	Section(body, nextOrder(), "PRINT LIMPA", A)
	text({
		LayoutOrder = nextOrder(),
		Text = "Segure o botão flutuante sem mover para tirar uma print sem menus nem HUD.",
		TextSize = 12, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 18), Parent = body,
	})
	local modeRow = Row(body, nextOrder(), { title = "Modo da print", desc = "Cinema liga gráficos no máximo e shader só na hora", accent = A, rightWidth = 200, pressable = false })
	Ext.shotModeSeg = Segmented(modeRow.frame, {
		items = { "Normal", "Cinema" },
		index = Prefs.shotMode,
		accent = A,
		size = UDim2.fromOffset(170, 32),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
		onChange = function(i)
			Prefs.shotMode = i
			scheduleSave()
		end,
	})
	local holdRow = Row(body, nextOrder(), { title = "Segurar o botão por", desc = "Tempo até a print ser tirada", accent = A, rightWidth = 150, pressable = false })
	Ext.shotHoldStepper = Stepper(holdRow.frame, {
		choices = { 1, 2, 3 },
		index = Prefs.shotHold,
		fmt = function(v)
			return SHOT_HOLDS[v] .. " s"
		end,
		onChange = function(v)
			Prefs.shotHold = v
			scheduleSave()
		end,
	}, A, 16)
	local nowRow = Row(body, nextOrder(), { title = "Tirar print agora", desc = "Fecha o menu, tira a print e volta", accent = A, rightWidth = 140, pressable = false })
	Button(nowRow.frame, { text = "Tirar print", style = "filled", accent = A, size = UDim2.fromOffset(112, 34), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -16, 0.5, 0) }).Activated:Connect(function()
		if Ext.takeShot then
			Ext.takeShot()
		end
	end)
end

--------------------------------------------------------------------------
-- ABA · ÁUDIO
--------------------------------------------------------------------------
do
	local tab, body = TABS[TI.audio], Bodies[TI.audio]
	local A = tab.accent
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local audioUI = {}

	-- cartão do equalizador com barras animadas
	local eqCard = Ext.card(body, nextOrder(), 132)
	eqCard.BackgroundColor3 = C.Surface:Lerp(A, 0.05)
	text({ Text = "EQUALIZADOR", Font = F.Bold, TextSize = 11, TextColor3 = A, Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(200, 14), Parent = eqCard })
	local eqName = text({ Text = "", Font = F.Heavy, TextSize = 20, Position = UDim2.fromOffset(18, 32), Size = UDim2.new(0.5, -18, 0, 24), Parent = eqCard })
	local voiceL = text({ Text = "", TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(18, 60), Size = UDim2.new(0.5, -18, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = eqCard })
	audioUI.eqStep = Stepper(eqCard, {
		choices = { 1, 2, 3, 4, 5 },
		index = Audio.eq,
		width = 150,
		fmt = function(v)
			return T(Audio.EQ[v].name)
		end,
		onChange = function(v)
			Audio.eq = v
			Audio.refresh()
			Hooks.changed()
			toast(T("Equalizador") .. ": " .. T(Audio.EQ[v].name), A)
		end,
	}, A, 0)
	audioUI.eqStep.frame.AnchorPoint = Vector2.new(0, 0)
	audioUI.eqStep.frame.Position = UDim2.fromOffset(18, 86)
	local barsHolder = make("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -18), Size = UDim2.fromOffset(170, 96), BackgroundTransparency = 1, Parent = eqCard })
	local bars = {}
	for k, lbl in ipairs({ "Graves", "Médios", "Agudos" }) do
		local x = (k - 1) * 58
		local trackF = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, x, 1, -18), Size = UDim2.fromOffset(40, 74), BackgroundColor3 = C.Surface2, BorderSizePixel = 0, Parent = barsHolder }, { corner(10) })
		local fill = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = A, BorderSizePixel = 0, Parent = trackF }, { corner(10) })
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(A:Lerp(C.White, 0.25), A), Parent = fill })
		text({ Text = lbl, Font = F.Bold, TextSize = 10, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, x - 6, 1, 0), Size = UDim2.fromOffset(52, 14), Parent = barsHolder })
		bars[k] = fill
	end
	local function paintEq(bounce)
		local preset = Audio.EQ[Audio.eq]
		local h = preset.bars or { 0.5, 0.5, 0.5 }
		for k, f in ipairs(bars) do
			if bounce then
				f.Size = UDim2.fromScale(1, 0.1)
			end
			tween(f, 0.6 + k * 0.08, { Size = UDim2.fromScale(1, h[k]) }, EASE.Back)
		end
		eqName.Text = T(preset.name)
		voiceL.Text = Audio.voiceCount > 0 and (Audio.voiceCount .. " " .. T("vozes no servidor")) or T("Sem voice novo neste servidor")
	end
	Ext.TabEnter = Ext.TabEnter or {}
	Ext.TabEnter[TI.audio] = function()
		Audio.applyVoice()
		paintEq(true)
	end

	-- mixer
	Section(body, nextOrder(), "MIXER", A)
	local LEVELS = { 0, 25, 50, 75, 100, 125, 150, 200 }
	local function levelIndex(m)
		local best, bi = 99, 5
		for i, v in ipairs(LEVELS) do
			if math.abs(v / 100 - m) < best then
				best, bi = math.abs(v / 100 - m), i
			end
		end
		return bi
	end
	local MIX = {
		{ "music", "Música", "Trilha sonora do jogo" },
		{ "effects", "Efeitos", "Sons de ação, objetos e personagens" },
		{ "ambient", "Ambiente", "Vento, chuva, natureza e fundo" },
		{ "ui", "Interface", "Cliques e sons de menu" },
		{ "voice", "Voz", "Voice chat dos outros (jogos com voice novo)" },
	}
	audioUI.mix = {}
	local function mixStatus(r, m)
		if m == 0 then
			r.SetStatus(T("Mudo"), C.Warn)
		elseif m == 1 then
			r.SetStatus(T("Original"), C.Dim)
		elseif m > 1 then
			r.SetStatus(T("Mais alto que o original"), A)
		else
			r.SetStatus(T("Mais baixo que o original"), A)
		end
		r.SetOn(m ~= 1)
	end
	for _, mx in ipairs(MIX) do
		local key = mx[1]
		local r = Row(body, nextOrder(), { title = mx[2], desc = mx[3], accent = A, status = true, rightWidth = 150, pressable = false })
		local st = Stepper(r.frame, {
			choices = LEVELS,
			index = levelIndex(Audio.mult[key]),
			fmt = function(v)
				return v .. "%"
			end,
			onChange = function(v)
				Audio.mult[key] = v / 100
				Audio.refresh()
				mixStatus(r, Audio.mult[key])
				Hooks.changed()
			end,
		}, A, 16)
		audioUI.mix[key] = { row = r, step = st }
		mixStatus(r, Audio.mult[key])
	end

	-- realces
	Section(body, nextOrder(), "REALCES", A)
	local BOOSTS = { 150, 200, 300 }
	local function boostRow(key, title, desc)
		local idx = 2
		local r
		r = SwitchRow(body, nextOrder(), {
			title = title,
			desc = desc,
			accent = A,
			status = true,
			initial = Audio.mult[key] > 1,
			stepper = {
				choices = BOOSTS,
				index = idx,
				fmt = function(v)
					return v .. "%"
				end,
				onChange = function(v, i)
					idx = i
					if r.switch.value then
						Audio.mult[key] = v / 100
						Audio.refresh()
						Hooks.changed()
					end
				end,
			},
			onToggle = function(v)
				Audio.mult[key] = v and BOOSTS[idx] / 100 or 1
				Audio.refresh()
				Hooks.changed()
				toast(T(title) .. " " .. T(v and "ligado" or "desligado"), v and A or C.Sub)
			end,
		})
		return r
	end
	audioUI.steps = boostRow("steps", "Realçar passos", "Ouça quem está chegando")
	audioUI.combat = boostRow("combat", "Realçar sons de combate", "Tiros, golpes e explosões mais altos")
	local savedMusic = 1
	audioUI.noMusic = SwitchRow(body, nextOrder(), {
		title = "Remover música",
		desc = "Tira só a trilha sonora, o resto continua",
		accent = A,
		status = true,
		initial = Audio.mult.music == 0,
		onToggle = function(v)
			if v then
				savedMusic = Audio.mult.music > 0 and Audio.mult.music or 1
				Audio.mult.music = 0
			else
				Audio.mult.music = savedMusic
			end
			Audio.refresh()
			Hooks.changed()
		end,
	})
	audioUI.limiter = SwitchRow(body, nextOrder(), {
		title = "Abafar sons muito altos",
		desc = "Evita estouros e sustos de volume",
		accent = A,
		status = true,
		initial = Audio.limiter,
		onToggle = function(v)
			Audio.limiter = v
			Audio.refresh()
			Hooks.changed()
		end,
	})

	text({
		LayoutOrder = nextOrder(),
		Text = "O Roblox não informa o tipo de cada som: passos, combate e música são identificados pelo nome e pelo lugar do som. Funciona na maioria dos jogos.",
		TextSize = 11, TextColor3 = C.Dim, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30), Parent = body,
	})

	-- sincroniza a aba com o estado (perfis, carregar, outras abas)
	function Ext.syncAudioUI()
		for key, m in pairs(audioUI.mix) do
			m.step.Set(levelIndex(Audio.mult[key]), true)
			mixStatus(m.row, Audio.mult[key])
		end
		audioUI.eqStep.Set(Audio.eq, true)
		audioUI.steps.Set(Audio.mult.steps > 1)
		audioUI.combat.Set(Audio.mult.combat > 1)
		audioUI.noMusic.Set(Audio.mult.music == 0)
		audioUI.limiter.Set(Audio.limiter)
		for _, r in ipairs({ audioUI.steps, audioUI.combat, audioUI.noMusic, audioUI.limiter }) do
			local on = r.switch.value
			r.SetStatus(T(on and "Ativo" or "Desligado"), on and A or C.Dim)
		end
		paintEq(false)
	end
	table.insert(Refreshers, Ext.syncAudioUI)
end

--------------------------------------------------------------------------
-- ABA · PROTEÇÃO
--------------------------------------------------------------------------
do
	local tab, body = TABS[TI.protect], Bodies[TI.protect]
	local A = tab.accent
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	-- escudo com estado geral
	local card = Ext.card(body, nextOrder(), 120)
	local shield = make("Frame", { Position = UDim2.fromOffset(22, 22), Size = UDim2.fromOffset(64, 76), BackgroundTransparency = 1, Parent = card })
	local rings = {}
	for k = 1, 2 do
		rings[k] = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = A, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = shield }, { corner("full") })
	end
	local body_ = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Off, BorderSizePixel = 0, Parent = shield }, { corner(20) })
	local check1 = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -8, 0.5, 6), Size = UDim2.fromOffset(5, 16), Rotation = -45, BackgroundColor3 = C.Bg, BorderSizePixel = 0, Parent = body_ }, { corner("full") })
	local check2 = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 6, 0.5, 0), Size = UDim2.fromOffset(5, 30), Rotation = 40, BackgroundColor3 = C.Bg, BorderSizePixel = 0, Parent = body_ }, { corner("full") })
	local stateL = text({ Text = "", Font = F.Heavy, TextSize = 22, Position = UDim2.fromOffset(108, 26), Size = UDim2.new(1, -270, 0, 26), Parent = card })
	local countL = text({ Text = "", TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(108, 56), Size = UDim2.new(1, -270, 0, 16), Parent = card })
	local allBtn = Button(card, { text = "Ligar todas", style = "filled", accent = A, size = UDim2.fromOffset(136, 34), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -18, 0.5, 0) })
	allBtn.Activated:Connect(function()
		local map = {}
		local anyOff = countActive(PROTECT_LIST) < #PROTECT_LIST
		for _, opt in ipairs(PROTECT_LIST) do
			map[opt.id] = anyOff
		end
		setOptions(map)
		toast(anyOff and "Todas as proteções ligadas" or "Proteções desligadas", anyOff and A or C.Sub)
	end)
	local pulses = {}
	local lastOn
	local function paint()
		local n = countActive(PROTECT_LIST)
		local on = n > 0
		stateL.Text = T(on and "Protegido" or "Sem proteção")
		countL.Text = n .. " " .. T("de") .. " " .. #PROTECT_LIST .. " " .. T("proteções ativas")
		allBtn.SetStyle(n < #PROTECT_LIST and "filled" or "tinted", n < #PROTECT_LIST and "Ligar todas" or "Desligar todas")
		if on ~= lastOn then
			lastOn = on
			tween(body_, 0.4, { BackgroundColor3 = on and A or C.Off })
			for _, t in ipairs(pulses) do
				t:Cancel()
			end
			table.clear(pulses)
			if on and not Prefs.reduceMotion then
				for k, r in ipairs(rings) do
					r.Size = UDim2.fromOffset(64, 64)
					r.BackgroundTransparency = 0.5
					local tw = TweenService:Create(r, TweenInfo.new(1.8, EASE.Quad, DIR.Out, -1, false, (k - 1) * 0.9), { Size = UDim2.fromOffset(112, 112), BackgroundTransparency = 1 })
					tw:Play()
					pulses[#pulses + 1] = tw
				end
			else
				for _, r in ipairs(rings) do
					r.BackgroundTransparency = 1
				end
			end
		end
	end
	table.insert(Refreshers, paint)
	Ext.TabEnter = Ext.TabEnter or {}
	Ext.TabEnter[TI.protect] = function()
		check1.Size = UDim2.fromOffset(5, 0)
		check2.Size = UDim2.fromOffset(5, 0)
		tween(check1, 0.3, { Size = UDim2.fromOffset(5, 16) }, EASE.Quad)
		task.delay(0.2, function()
			tween(check2, 0.35, { Size = UDim2.fromOffset(5, 30) }, EASE.Back)
		end)
	end

	local lastCat
	for _, opt in ipairs(PROTECT_LIST) do
		local cat = opt.cat == "PRIVACIDADE" and "PRIVACIDADE" or "PROTEÇÃO"
		if cat ~= lastCat then
			lastCat = cat
			Section(body, nextOrder(), cat, A)
		end
		optionRow(body, nextOrder(), opt, A, function(v)
			setOptions({ [opt.id] = v })
		end)
	end

	text({
		LayoutOrder = nextOrder(),
		Text = "Sobre anti-kick: bloquear o kick do próprio jogo é burlar a moderação, então não é feito aqui. O Reconectar sozinho te devolve ao jogo se você cair.",
		TextSize = 11, TextColor3 = C.Dim, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30), Parent = body,
	})
end

--------------------------------------------------------------------------
-- SALVAR / CARREGAR
--------------------------------------------------------------------------
local Loading = false
local savePending = false

local function writeSave()
	if not Env.canSave then
		return
	end
	local data = {
		version = 3,
		prefs = Prefs,
		remember = Prefs.remember,
		games = Ext.Games,
		profiles = Ext.Profiles,
		gallery = Ext.Gallery,
	}
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
		for _, l in ipairs({ OPTIONS, FARM_OPTIONS, VISUAL_OPTIONS }) do
			for _, opt in ipairs(l) do
				if opt.choices then
					data.choices[opt.id] = opt.choices[opt.choiceIndex]
				end
			end
		end
		data.overlays = OverlayOn
		data.hudPos = { Hud.Position.X.Offset, Hud.Position.Y.Offset }
		data.visual = Ext.captureList(VISUAL_OPTIONS)
		data.hl = Ext.hl
		data.audio = Audio.capture()
		data.protect = Ext.captureList(PROTECT_LIST)
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
	local data = SaveData
	if type(data) ~= "table" or not Prefs.remember then
		return
	end
	Loading = true
	if type(data.hl) == "table" then
		for k, v in pairs(data.hl) do
			if Ext.hl[k] ~= nil and type(v) == "number" then
				Ext.hl[k] = v
			end
		end
	end
	if type(data.choices) == "table" then
		for _, l in ipairs({ OPTIONS, FARM_OPTIONS, VISUAL_OPTIONS }) do
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
		local keepQuality = type(data.choices) == "table" and data.choices.quality
		applyPreset(preset)
		if keepQuality then
			setChoice(ById.quality, keepQuality)
		end
	elseif type(data.options) == "table" then
		local map = {}
		for _, id in ipairs(data.options) do
			if ById[id] and not FarmIds[id] and not ById[id].locked then
				map[id] = true
			end
		end
		setOptions(map)
	end
	if type(data.farm) == "table" then
		local map = {}
		for id, v in pairs(data.farm) do
			-- antiafk e reconnect vieram do Farm antigo: continuam valendo
			if ById[id] and v == true and not ById[id].locked then
				map[id] = true
			end
		end
		setOptions(map)
	end
	if type(data.visual) == "table" then
		Ext.applyList(VISUAL_OPTIONS, data.visual)
	end
	if type(data.protect) == "table" then
		Ext.applyList(PROTECT_LIST, data.protect)
	end
	if type(data.audio) == "table" then
		Audio.load(data.audio)
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

-- círculo que enche enquanto você segura o botão (print limpa)
FabUI.charge = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0, 0),
	BackgroundColor3 = C.Pink,
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	ZIndex = 0,
	Parent = FabBtn,
}, { corner("full") })

-- engrenagem: abre o painel rápido (perfis, botão, presets visíveis)
FabUI.gear = make("TextButton", {
	Text = "",
	AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.fromOffset(24, 24),
	BackgroundColor3 = C.Surface2,
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = Fab,
}, { corner("full"), stroke(C.Stroke, 1, 0) })
do
	for k = 0, 2 do
		make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 16), Rotation = k * 60, BackgroundColor3 = C.Sub, BorderSizePixel = 0, Parent = FabUI.gear }, { corner(1) })
	end
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 11), BackgroundColor3 = C.Sub, BorderSizePixel = 0, Parent = FabUI.gear }, { corner("full") })
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = C.Surface2, BorderSizePixel = 0, Parent = FabUI.gear }, { corner("full") })
end
FabUI.gear.Activated:Connect(function()
	tween(FabUI.gear, 0.5, { Rotation = FabUI.gear.Rotation + 120 }, EASE.Back)
	if Ext.openPanel then
		Ext.openPanel()
	end
end)

local FAB_SIZES, FAB_ALPHA = { 46, 56, 66 }, { 1, 0.8, 0.6, 0.4 }
function Ext.applyFab()
	local sz = FAB_SIZES[Prefs.fabSize] or 56
	tween(Fab, 0.35, { Size = UDim2.fromOffset(sz, sz) }, EASE.Back)
	FabUI.mark.Size = UDim2.fromOffset(math.floor(sz * 0.46), math.floor(sz * 0.46))
	local a = FAB_ALPHA[Prefs.fabAlpha] or 1
	FabBtn.BackgroundTransparency = 1 - 0.95 * a
	FabUI.stroke.Transparency = 1 - 0.9 * a
	for _, holder in ipairs({ FabUI.mark, FabUI.mini, FabUI.gear }) do
		for _, d in ipairs(holder:GetDescendants()) do
			if d:IsA("Frame") then
				d.BackgroundTransparency = 1 - a
			end
		end
	end
	FabUI.gear.BackgroundTransparency = 1 - a
	task.delay(0.4, function()
		if not Destroyed then
			snapFab()
		end
	end)
end

local fabHold = { token = 0, fired = false }
FabBtn.InputBegan:Connect(function(i)
	if not isPress(i) then
		return
	end
	fabHold.token += 1
	local my = fabHold.token
	fabHold.fired = false
	local startPos = Fab.Position
	local dur = SHOT_HOLDS[Prefs.shotHold] or 5
	task.spawn(function()
		task.wait(0.4) -- toque rápido não mostra a carga
		if fabHold.token ~= my then
			return
		end
		FabUI.charge.Size = UDim2.fromScale(0, 0)
		local tw = TweenService:Create(FabUI.charge, TweenInfo.new(dur - 0.4, EASE.Linear), { Size = UDim2.fromScale(1, 1) })
		tw:Play()
		local t0 = os.clock()
		while fabHold.token == my and os.clock() - t0 < dur - 0.4 do
			if Fab.Position ~= startPos then
				fabHold.token += 1 -- arrastou: cancela
				break
			end
			task.wait()
		end
		tw:Cancel()
		FabUI.charge.Size = UDim2.fromScale(0, 0)
		if fabHold.token == my and not Destroyed then
			fabHold.fired = true
			if Ext.takeShot then
				Ext.takeShot()
			end
		end
	end)
end)
FabBtn.InputEnded:Connect(function(i)
	if isPress(i) and not fabHold.fired then
		fabHold.token += 1
	end
end)

makeDraggable(FabBtn, Fab, function(moved)
	if moved then
		snapFab()
	elseif fabHold.fired then
		fabHold.fired = false -- a print já foi tirada: não abre o menu
	else
		setOpen(not isOpen)
	end
end)

-- print limpa: esconde menu, HUD e interfaces, tira a print e volta tudo
function Ext.takeShot()
	if Ext.shotBusy then
		return
	end
	local okCS, CS = pcall(function()
		return game:GetService("CaptureService")
	end)
	if not okCS or not CS then
		toast("Print indisponível neste ambiente", C.Warn)
		return
	end
	Ext.shotBusy = true
	task.spawn(function()
		local cinema = Prefs.shotMode == 2
		Gui.Enabled = false
		if BlackGui then
			BlackGui.Enabled = false
		end
		local coreTypes = {
			Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.Backpack,
			Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health,
		}
		local coreState = {}
		for _, t in ipairs(coreTypes) do
			pcall(function()
				coreState[t] = StarterGui:GetCoreGuiEnabled(t)
				StarterGui:SetCoreGuiEnabled(t, false)
			end)
		end
		local hidden = {}
		local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then
			for _, g in ipairs(pg:GetChildren()) do
				if g:IsA("ScreenGui") and g.Enabled and g ~= Gui then
					hidden[#hidden + 1] = g
					g.Enabled = false
				end
			end
		end
		local cin, snapshot, prevQ = {}, nil, nil
		if cinema then
			snapshot = Ext.captureTweaks()
			local all = {}
			for _, o in ipairs(OPTIONS) do
				all[o.id] = false
			end
			setOptions(all)
			pcall(function()
				prevQ = settings().Rendering.QualityLevel
				settings().Rendering.QualityLevel = Enum.QualityLevel.Level21
			end)
			if not Active.vis_shader then
				Ext.makeShader(Ext.SHADERS[3], cin)
			end
			task.wait(1.4)
		else
			task.wait(0.25)
		end
		local done = false
		local okCap = pcall(function()
			CS:CaptureScreenshot(function(contentId)
				done = true
				pcall(function()
					CS:PromptSaveCapturesToGallery({ contentId }, function() end)
				end)
			end)
		end)
		local t0 = os.clock()
		while okCap and not done and os.clock() - t0 < 4 do
			task.wait()
		end
		for _, e in ipairs(cin) do
			pcall(function()
				e:Destroy()
			end)
		end
		if cinema then
			if prevQ then
				pcall(function()
					settings().Rendering.QualityLevel = prevQ
				end)
			end
			Ext.applyTweaks(snapshot)
		end
		for _, g in ipairs(hidden) do
			pcall(function()
				g.Enabled = true
			end)
		end
		for t, v in pairs(coreState) do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(t, v)
			end)
		end
		if BlackGui then
			BlackGui.Enabled = true
		end
		Gui.Enabled = true
		Ext.shotBusy = false
		if okCap and done then
			toast("Print tirada · confirme para salvar na galeria", C.Pink)
		else
			toast("Não foi possível tirar a print neste ambiente", C.Warn)
		end
	end)
end
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
	local tab, body = TABS[TI.config], Bodies[TI.config]
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
	local langRow = Row(body, nextOrder(), {
		title = "Idioma",
		desc = "Muda na próxima vez que você executar o script",
		accent = A,
		rightWidth = 200,
		pressable = false,
	})
	ConfigRows.lang = Segmented(langRow.frame, {
		items = { "Português", "English" },
		index = Prefs.lang == "en" and 2 or 1,
		accent = A,
		size = UDim2.fromOffset(180, 32),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
		onChange = function(i)
			Prefs.lang = i == 2 and "en" or "pt"
			scheduleSave()
			toast(i == 2 and "Language changes the next time you run the script" or "O idioma muda na próxima execução", A)
		end,
	})
	ConfigRows.notify = SwitchRow(body, nextOrder(), {
		title = "Notificações",
		desc = "Avisos no topo da tela ao salvar e aplicar (erros sempre aparecem)",
		accent = A,
		initial = Prefs.notify,
		onToggle = function(v)
			Prefs.notify = v
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
	infoRow("Ambiente de execução", "Onde o Silly Optimizer está rodando", true, envName)
	infoRow("Limitar FPS", "Função setfpscap do executor", Env.setfpscap ~= nil)
	infoRow("Salvar escolhas", "Funções writefile e readfile", Env.canSave)
	infoRow("Interface protegida", "gethui esconde o menu de outros scripts", Env.gethui ~= nil)

	Section(body, nextOrder(), "SISTEMA", A)
	local logRow = Row(body, nextOrder(), {
		title = "Novidades da versão",
		desc = "Veja o que mudou na v" .. VERSION,
		accent = A,
		rightWidth = 140,
		pressable = false,
	})
	Button(logRow.frame, {
		text = "Ver novidades",
		style = "tinted",
		accent = A,
		size = UDim2.fromOffset(120, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
	}).Activated:Connect(function()
		if Ext.openChangelog then
			Ext.openChangelog()
		end
	end)
	local resetRow = Row(body, nextOrder(), {
		title = "Restaurar tudo",
		desc = "Desliga presets, ajustes, farm, visual, áudio e proteções",
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
		Ext.restoreEverything()
		toast("Tudo restaurado", C.Sub)
	end)

	-- reset de fábrica: apaga o que foi salvo e volta tudo ao padrão
	local factoryRow = Row(body, nextOrder(), {
		title = "Reset de fábrica",
		desc = "Apaga perfis, presets por jogo, galeria e preferências",
		accent = C.Warn,
		rightWidth = 140,
		pressable = false,
	})
	local factoryArmed = 0
	local factoryBtn = Button(factoryRow.frame, {
		text = "Resetar",
		style = "danger",
		size = UDim2.fromOffset(110, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 0),
	})
	factoryBtn.Activated:Connect(function()
		if factoryArmed == 0 then
			factoryArmed += 1
			local my = factoryArmed
			factoryBtn.SetStyle("dangerFilled", "Confirmar")
			task.delay(3, function()
				if factoryArmed == my and not Destroyed then
					factoryArmed = 0
					factoryBtn.SetStyle("danger", "Resetar")
				end
			end)
			return
		end
		factoryArmed = 0
		factoryBtn.SetStyle("danger", "Resetar")
		Ext.restoreEverything()
		table.clear(Ext.Profiles)
		table.clear(Ext.Games)
		table.clear(Ext.Gallery)
		local defaults = {
			remember = false, openOnStart = true, reduceMotion = false, keybind = "RightShift",
			hudVisible = true, hudLayout = 1, hudSize = 2, notify = true, fabSize = 2, fabAlpha = 1,
			shotMode = 1, shotHold = 3,
		}
		for k, v in pairs(defaults) do
			Prefs[k] = v
		end
		table.clear(Prefs.hiddenPresets)
		for k, o in pairs(OverlayOn) do
			OverlayOn[k] = k == "fps" or k == "ping"
			OverlayRows[k].Set(OverlayOn[k])
		end
		HudControls.syncMaster()
		if Env.delfile then
			pcall(Env.delfile, SAVE_FILE)
		end
		if Ext.applyPrefsToUI then
			Ext.applyPrefsToUI()
		end
		if Ext.rebuildGallery then
			Ext.rebuildGallery()
		end
		Hooks.changed()
		toast("Reset de fábrica concluído", C.Sub)
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
	ConfigRows.notify.Set(Prefs.notify)
	ConfigRows.lang.Set(Prefs.lang == "en" and 2 or 1, true)
	ConfigRows.key.Set(table.find(KEY_LIST, Prefs.keybind) or 1, true)
	HudControls.visible.Set(Prefs.hudVisible)
	HudControls.layout.Set(Prefs.hudLayout, true)
	HudControls.size.Set(Prefs.hudSize, true)
	Ext.shotModeSeg.Set(Prefs.shotMode, true)
	Ext.shotHoldStepper.Set(Prefs.shotHold, true)
	Ext.hlColorStepper.Set(Ext.hl.color, true)
	Ext.hlAlphaStepper.Set(Ext.hl.alpha, true)
	refreshKeyCap()
	applyHudPrefs()
	Ext.applyFab()
	if Ext.syncAudioUI then
		Ext.syncAudioUI()
	end
end
Ext.applyPrefsToUI = applyPrefsToUI

-- desliga tudo de todas as abas (Restaurar tudo / Reset de fábrica)
function Ext.restoreEverything()
	local map = {}
	for _, l in ipairs({ OPTIONS, FARM_OPTIONS, VISUAL_OPTIONS, PROTECT_LIST }) do
		for _, opt in ipairs(l) do
			map[opt.id] = false
		end
	end
	State.preset = nil
	setOptions(map)
	for k in pairs(Audio.mult) do
		Audio.mult[k] = 1
	end
	Audio.limiter, Audio.eq = false, 1
	Audio.refresh()
	if Ext.syncAudioUI then
		Ext.syncAudioUI()
	end
	Hooks.changed()
end

--------------------------------------------------------------------------
-- ATUALIZAÇÃO GERAL
--------------------------------------------------------------------------
local function refreshBadges()
	local nOpt = countActive(OPTIONS)
	local nVis = countActive(VISUAL_OPTIONS)
	local nPro = countActive(PROTECT_LIST)
	local values = {
		presets = State.preset and State.preset.name or "",
		tweaks = nOpt > 0 and tostring(nOpt) or "",
		farm = FarmSince and "ON" or "",
		visual = nVis > 0 and tostring(nVis) or "",
		audio = (Audio.needed() or Audio.mult.voice ~= 1) and "ON" or "",
		protect = nPro > 0 and tostring(nPro) or "",
	}
	for i, t in ipairs(TabUI) do
		local v = values[TABS[i].id] or ""
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
	-- amostras de ping para a estabilidade do servidor
	local ping = getPing()
	if ping then
		table.insert(Ext.pings, ping)
		if #Ext.pings > 24 then
			table.remove(Ext.pings, 1)
		end
	end
	if Ext.homeSpin then
		local spin = isOpen and CurrentTab == TI.home and not Prefs.reduceMotion
		if spin ~= Ext.homeSpinning then
			Ext.homeSpinning = spin
			if spin then
				Ext.homeSpin:Play()
			else
				Ext.homeSpin:Pause()
			end
		end
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
-- JANELAS SOBREPOSTAS: painel rápido (engrenagem) e novidades
--------------------------------------------------------------------------
-- base comum: fundo escurecido + cartão que aparece com escala
function Ext.modal(w, h, accent)
	local overlay = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 45,
		Parent = Gui,
	})
	local card = make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = overlay,
	}, { corner(22), stroke(C.Stroke, 1, 0) })
	-- bloqueia o clique de "fechar" dentro do cartão
	make("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = card })
	local fit = make("UIScale", { Parent = card })
	make("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = card }, {
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.84, 1) }),
	})
	local api = { overlay = overlay, card = card, open = false }
	function api.Show()
		local vp = viewportSize()
		local target = math.max(0.5, math.min(1, (vp.X - 24) / w, (vp.Y - 24) / h))
		api.open = true
		overlay.Visible = true
		tween(overlay, 0.25, { BackgroundTransparency = 0.45 })
		tween(card, 0.25, { GroupTransparency = 0 })
		card.Position = UDim2.new(0.5, 0, 0.5, 18)
		tween(card, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, EASE.Back)
		fit.Scale = target * 0.94
		tween(fit, 0.45, { Scale = target }, EASE.Back)
	end
	function api.Hide()
		api.open = false
		tween(overlay, 0.2, { BackgroundTransparency = 1 })
		tween(card, 0.18, { GroupTransparency = 1 })
		task.delay(Prefs.reduceMotion and 0 or 0.2, function()
			if not api.open then
				overlay.Visible = false
			end
		end)
	end
	overlay.Activated:Connect(api.Hide)
	-- botão fechar
	local close = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Parent = card,
	}, { corner("full") })
	for _, rot in ipairs({ 45, -45 }) do
		make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 2), Rotation = rot, BackgroundColor3 = C.Sub, BorderSizePixel = 0, Parent = close }, { corner("full") })
	end
	close.Activated:Connect(api.Hide)
	return api
end

-- NOVIDADES -------------------------------------------------------------------
do
	local CHANGELOG = {
		{ v = "6.1", items = {
			"Modo leve no celular: a interface não usa mais CanvasGroup no mobile",
			"Se algo der errado ao abrir, aparece um aviso na tela com o motivo",
		} },
		{ v = "6.0", items = {
			"Aba Home com sua conta, Premium, servidor, desempenho e amigos jogando",
			"Benchmark que monta presets Competitivo e Desempenho para cada jogo",
			"Preset salvo por jogo, aplicado sozinho quando você entra",
			"Aba Server: reentrar, menor ping, mais vazio e copiar link",
			"Aba Visual: horário, céu, shaders, fullbright, FOV, câmera e destaque de jogadores",
			"Galeria de visuais e print limpa segurando o botão flutuante",
			"Aba Áudio: mixer, realce de passos e combate, equalizador e voice",
			"Aba Proteção: anti-fling, anti-lag de efeitos e modo streamer",
			"Engrenagem no botão flutuante: perfis, tamanho e opacidade",
			"Distância de renderização, acessórios dos outros e FPS desbloqueado",
			"Limpar memória, idioma Português/English e reset de fábrica",
			"Correção para executores em que a interface não aparecia",
		} },
		{ v = "5.0", items = {
			"Visual novo, tela de carregamento e animações",
			"Ajustes com estado claro, busca e filtros",
			"HUD personalizável e aba Configurações",
		} },
	}
	local m = Ext.modal(440, 460, C.Coral)
	local tile = brandTile(m.card, 44, 13, 24)
	tile.Position = UDim2.fromOffset(22, 22)
	text({ Text = "Novidades", Font = F.Heavy, TextSize = 22, Position = UDim2.fromOffset(78, 22), Size = UDim2.new(1, -140, 0, 26), Parent = m.card })
	text({ Text = "Silly Optimizer v" .. VERSION, TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(78, 48), Size = UDim2.new(1, -140, 0, 16), Parent = m.card })
	local scroll = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -146),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Coral,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = m.card,
	}, { pad(22, 0, 22, 10), list(Enum.FillDirection.Vertical, 8) })
	local items = {}
	local o = 0
	for gi, group in ipairs(CHANGELOG) do
		o += 1
		local h = make("Frame", { LayoutOrder = o, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = scroll })
		Ext.chip(h, 1, "v" .. group.v .. (gi == 1 and ("  ·  " .. T("ATUAL")) or ""), gi == 1 and C.Coral or C.Dim)
		for _, it in ipairs(group.items) do
			o += 1
			local row = make("Frame", { LayoutOrder = o, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll })
			make("Frame", { Position = UDim2.fromOffset(2, 6), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = gi == 1 and C.Coral or C.Dim, BorderSizePixel = 0, Parent = row }, { corner("full") })
			local l = text({ Text = it, TextSize = 13, TextColor3 = gi == 1 and C.Text or C.Sub, TextWrapped = true, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -18, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
			items[#items + 1] = l
		end
	end
	local ok = Button(m.card, { text = "Entendi", style = "filled", accent = C.Coral, size = UDim2.new(1, -44, 0, 38), anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -16) })
	ok.Activated:Connect(m.Hide)
	function Ext.openChangelog()
		m.Show()
		-- itens entram em cascata
		if not Prefs.reduceMotion then
			for k, l in ipairs(items) do
				if k > 12 then
					break
				end
				l.TextTransparency = 1
				task.delay(0.15 + k * 0.04, function()
					tween(l, 0.3, { TextTransparency = 0 })
				end)
			end
		end
		burst(m.card, UDim2.fromOffset(44, 44), 6, 40)
	end
end

-- PAINEL RÁPIDO (engrenagem) ---------------------------------------------------
do
	local A = C.Salmon
	local m = Ext.modal(420, 500, A)
	text({ Text = "PAINEL RÁPIDO", Font = F.Bold, TextSize = 11, TextColor3 = A, Position = UDim2.fromOffset(22, 22), Size = UDim2.new(1, -90, 0, 14), Parent = m.card })
	text({ Text = "Perfis e botão flutuante", Font = F.Heavy, TextSize = 21, Position = UDim2.fromOffset(22, 38), Size = UDim2.new(1, -90, 0, 26), Parent = m.card })
	local body = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 1, -78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = A,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = m.card,
	}, { pad(18, 4, 18, 20), list(Enum.FillDirection.Vertical, 8) })
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	-- partes que um perfil pode guardar
	local PARTS = {
		{ id = "tweaks", name = "Ajustes" }, { id = "farm", name = "Farm" }, { id = "visual", name = "Visual" },
		{ id = "audio", name = "Áudio" }, { id = "protect", name = "Proteção" }, { id = "hud", name = "HUD" },
	}
	local function capturePart(id)
		if id == "tweaks" then
			return Ext.captureTweaks()
		elseif id == "farm" then
			return Ext.captureList(FarmList)
		elseif id == "visual" then
			local c = Ext.captureList(VISUAL_OPTIONS)
			c.hl = table.clone(Ext.hl)
			return c
		elseif id == "audio" then
			return Audio.capture()
		elseif id == "protect" then
			return Ext.captureList(PROTECT_LIST)
		elseif id == "hud" then
			return { overlays = table.clone(OverlayOn), visible = Prefs.hudVisible, layout = Prefs.hudLayout, size = Prefs.hudSize }
		end
		return nil
	end
	local function applyPart(id, cap)
		if type(cap) ~= "table" then
			return
		end
		if id == "tweaks" then
			Ext.applyTweaks(cap)
		elseif id == "farm" then
			Ext.applyList(FarmList, cap)
		elseif id == "visual" then
			if type(cap.hl) == "table" then
				for k, v in pairs(cap.hl) do
					if Ext.hl[k] ~= nil and type(v) == "number" then
						Ext.hl[k] = v
					end
				end
				Ext.hlRestyle()
			end
			Ext.applyList(VISUAL_OPTIONS, cap)
		elseif id == "audio" then
			Audio.load(cap)
		elseif id == "protect" then
			Ext.applyList(PROTECT_LIST, cap)
		elseif id == "hud" then
			for k, v in pairs(type(cap.overlays) == "table" and cap.overlays or {}) do
				if OverlayOn[k] ~= nil then
					OverlayOn[k] = v == true
					OverlayRows[k].Set(v == true)
				end
			end
			Prefs.hudVisible = cap.visible ~= false
			Prefs.hudLayout = type(cap.layout) == "number" and cap.layout or 1
			Prefs.hudSize = type(cap.size) == "number" and cap.size or 2
			HudControls.syncMaster()
		end
	end

	Section(body, nextOrder(), "PERFIS", A)
	local profList = make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body }, { list(Enum.FillDirection.Vertical, 6) })
	local function partsText(p)
		local names = {}
		for _, part in ipairs(PARTS) do
			if type(p.data) == "table" and p.data[part.id] ~= nil then
				names[#names + 1] = T(part.name)
			end
		end
		return table.concat(names, ", ")
	end
	local refreshProfiles
	refreshProfiles = function()
		for _, c in ipairs(profList:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		if #Ext.Profiles == 0 then
			text({ LayoutOrder = 1, Text = "Nenhum perfil salvo ainda. Configure as abas e salve abaixo.", TextSize = 12, TextColor3 = C.Dim, TextWrapped = true, Size = UDim2.new(1, 0, 0, 32), Parent = profList })
		end
		for k, p in ipairs(Ext.Profiles) do
			if type(p) == "table" then
				local row = make("Frame", { LayoutOrder = k, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.Surface, BorderSizePixel = 0, Parent = profList }, { corner(12), stroke(C.Stroke, 1, 0) })
				text({ Text = tostring(p.name or "?"), Font = F.Bold, TextSize = 14, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -150, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
				text({ Text = partsText(p), TextSize = 11, TextColor3 = C.Dim, Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -150, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
				Button(row, { text = "Aplicar", style = "filled", accent = A, size = UDim2.fromOffset(84, 30), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -46, 0.5, 0), textSize = 12 }).Activated:Connect(function()
					for _, part in ipairs(PARTS) do
						if type(p.data) == "table" and p.data[part.id] ~= nil then
							applyPart(part.id, p.data[part.id])
						end
					end
					if Ext.applyPrefsToUI then
						Ext.applyPrefsToUI()
					end
					Hooks.changed()
					burst(row, UDim2.new(1, -88, 0.5, 0), 6, 30)
					toast(T("Perfil") .. " " .. tostring(p.name) .. " " .. T("aplicado"), A)
				end)
				local del = make("TextButton", { Text = "×", Font = F.Bold, TextSize = 18, TextColor3 = C.Dim, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(30, 30), Parent = row })
				del.Activated:Connect(function()
					table.remove(Ext.Profiles, k)
					refreshProfiles()
					scheduleSave()
					toast("Perfil apagado", C.Sub)
				end)
			end
		end
	end

	-- salvar perfil: nome + quais abas entram
	local saveCard = make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Surface, BorderSizePixel = 0, Parent = body }, {
		corner(14), stroke(C.Stroke, 1, 0), pad(14, 14, 14, 14), list(Enum.FillDirection.Vertical, 10),
	})
	text({ LayoutOrder = 1, Text = "Salvar configuração atual", Font = F.Bold, TextSize = 14, Size = UDim2.new(1, 0, 0, 18), Parent = saveCard })
	text({ LayoutOrder = 2, Text = "Escolha quais abas entram no perfil:", TextSize = 12, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 16), Parent = saveCard })
	local chipWrap = make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = saveCard })
	Ext.wrapList(chipWrap, 6)
	local selected = {}
	for k, part in ipairs(PARTS) do
		selected[part.id] = true
		local chip = make("TextButton", {
			LayoutOrder = k,
			Text = T(part.name),
			Font = F.Bold,
			TextSize = 12,
			TextColor3 = C.Ink,
			AutoButtonColor = false,
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = A,
			BorderSizePixel = 0,
			Parent = chipWrap,
		}, { corner("full"), pad(12, 0, 12, 0) })
		chip.Activated:Connect(function()
			selected[part.id] = not selected[part.id]
			local on = selected[part.id]
			tween(chip, 0.2, { BackgroundColor3 = on and A or C.Surface2, TextColor3 = on and C.Ink or C.Sub })
		end)
	end
	local nameRow = make("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = saveCard })
	local nameBox = make("TextBox", {
		Text = "",
		PlaceholderText = T("Nome do perfil (ex.: Ranked)"),
		PlaceholderColor3 = C.Dim,
		Font = F.Semi,
		TextSize = 13,
		TextColor3 = C.Text,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -118, 1, 0),
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Parent = nameRow,
	}, { corner(10), pad(12, 0, 10, 0) })
	Button(nameRow, { text = "Salvar perfil", style = "filled", accent = A, size = UDim2.fromOffset(110, 36), anchor = Vector2.new(1, 0), position = UDim2.new(1, 0, 0, 0), textSize = 12 }).Activated:Connect(function()
		local data = {}
		local any = false
		for _, part in ipairs(PARTS) do
			if selected[part.id] then
				data[part.id] = capturePart(part.id)
				any = true
			end
		end
		if not any then
			toast("Escolha pelo menos uma aba", C.Warn)
			return
		end
		local name = string.gsub(nameBox.Text, "^%s+", "")
		if name == "" then
			name = T("Perfil") .. " " .. (#Ext.Profiles + 1)
		end
		name = string.sub(name, 1, 24)
		table.insert(Ext.Profiles, { name = name, data = data })
		nameBox.Text = ""
		refreshProfiles()
		scheduleSave()
		if not Env.canSave then
			toast("Perfil salvo só nesta sessão (sem writefile)", C.Warn)
		else
			toast(T("Perfil") .. " " .. name .. " " .. T("salvo"), A)
		end
	end)

	-- botão flutuante
	Section(body, nextOrder(), "BOTÃO FLUTUANTE", A)
	local sizeRow = Row(body, nextOrder(), { title = "Tamanho", desc = "Tamanho do botão na tela", accent = A, rightWidth = 140, pressable = false })
	local sizeStep = Stepper(sizeRow.frame, {
		choices = { 1, 2, 3 },
		index = Prefs.fabSize,
		fmt = function(v)
			return T(({ "Pequeno", "Médio", "Grande" })[v])
		end,
		onChange = function(v)
			Prefs.fabSize = v
			Ext.applyFab()
			scheduleSave()
		end,
	}, A, 16)
	local alphaRow = Row(body, nextOrder(), { title = "Opacidade", desc = "Deixe o botão mais discreto", accent = A, rightWidth = 140, pressable = false })
	local alphaStep = Stepper(alphaRow.frame, {
		choices = { 1, 2, 3, 4 },
		index = Prefs.fabAlpha,
		fmt = function(v)
			return math.floor(FAB_ALPHA[v] * 100 + 0.5) .. "%"
		end,
		onChange = function(v)
			Prefs.fabAlpha = v
			Ext.applyFab()
			scheduleSave()
		end,
	}, A, 16)

	-- quais presets aparecem na aba Presets
	Section(body, nextOrder(), "PRESETS NA TELA", A)
	local presetRows = {}
	for _, p in ipairs(PRESETS) do
		presetRows[p.id] = SwitchRow(body, nextOrder(), {
			title = p.name,
			desc = "Mostrar este preset na aba Presets",
			accent = p.accent,
			initial = not Prefs.hiddenPresets[p.id],
			onToggle = function(v)
				Prefs.hiddenPresets[p.id] = (not v) or nil
				Hooks.changed()
				scheduleSave()
			end,
		})
	end

	function Ext.openPanel()
		refreshProfiles()
		sizeStep.Set(Prefs.fabSize, true)
		alphaStep.Set(Prefs.fabAlpha, true)
		for id, r in pairs(presetRows) do
			r.Set(not Prefs.hiddenPresets[id])
		end
		m.Show()
	end
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
selectTab(TI.home, true)
Splash.step("Carregando preferências", 0.88)
loadSave()
applyPrefsToUI()
-- preset salvo para este jogo (benchmark ou "Meu preset")
do
	local e = Ext.Games[Ext.GKEY]
	if type(e) == "table" and e.auto and type(e[e.auto]) == "table" then
		Ext.applyTweaks(e[e.auto])
		Ext.autoApplied = e.auto
	end
end
Hooks.changed()
updateHud()
if Ext.refreshGameCard then
	Ext.refreshGameCard()
end
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
	local hint = Env.touch and T("toque no botão flutuante para abrir") or (T(KEY_NAMES[Prefs.keybind] or Prefs.keybind) .. " " .. T("abre o menu"))
	toast(T("Silly Optimizer pronto") .. " · " .. hint, C.Salmon)
	if Ext.autoApplied then
		local names = { competitive = "Competitivo", performance = "Desempenho", custom = "Meu preset" }
		task.delay(0.8, function()
			toast(T("Preset deste jogo aplicado") .. ": " .. T(names[Ext.autoApplied] or ""), C.Salmon)
		end)
	end
	-- novidades na primeira execução de uma versão nova
	if Prefs.lastVersion ~= VERSION then
		Prefs.lastVersion = VERSION
		scheduleSave()
		task.delay(Prefs.openOnStart and 1.2 or 0.6, function()
			if not Destroyed and Ext.openChangelog then
				Ext.openChangelog()
			end
		end)
	end
end

end -- SillyMain

local okMain, errMain = xpcall(SillyMain, function(e)
	return debug.traceback(tostring(e), 2)
end)
if not okMain then
	warn("[Silly Optimizer] " .. tostring(errMain))
	if SillyAbort then
		pcall(SillyAbort)
	end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Silly Optimizer",
			Text = "Erro ao iniciar: " .. string.sub(tostring(errMain), 1, 160),
			Duration = 25,
		})
	end)
	-- painel de erro próprio (a notificação do Roblox às vezes não aparece em executores)
	pcall(function()
		local g = Instance.new("ScreenGui")
		g.Name = "SillyOptimizerError"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 1001
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.Position = UDim2.new(0.5, 0, 0, 70)
		f.Size = UDim2.new(0.9, 0, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.BackgroundColor3 = Color3.fromRGB(28, 29, 33)
		f.BorderSizePixel = 0
		f.Parent = g
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
		local p = Instance.new("UIPadding", f)
		p.PaddingLeft, p.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
		p.PaddingTop, p.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -40, 0, 0)
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Font = Enum.Font.GothamMedium
		t.TextSize = 13
		t.TextColor3 = Color3.fromRGB(242, 243, 245)
		t.Text = "Silly Optimizer não abriu. Mande um print desta mensagem:\n\n" .. string.sub(tostring(errMain), 1, 700)
		t.Parent = f
		local x = Instance.new("TextButton")
		x.Text = "X"
		x.Font = Enum.Font.GothamBold
		x.TextSize = 16
		x.TextColor3 = Color3.fromRGB(255, 166, 154)
		x.BackgroundTransparency = 1
		x.AnchorPoint = Vector2.new(1, 0)
		x.Position = UDim2.new(1, 10, 0, -6)
		x.Size = UDim2.fromOffset(32, 32)
		x.Parent = f
		x.Activated:Connect(function()
			g:Destroy()
		end)
		local parent
		if type(gethui) == "function" then
			local ok, ui = pcall(gethui)
			if ok and typeof(ui) == "Instance" then
				parent = ui:IsA("LayerCollector") and ui.Parent or ui
			end
		end
		local okSet = parent and pcall(function()
			g.Parent = parent
		end)
		if not okSet then
			g.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		end
	end)
end
