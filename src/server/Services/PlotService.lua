--!nonstrict
-- Builds and maintains each player's procedural factory plot. Purely presentational: it reads the
-- (server-authoritative) profile and never changes it. Prompt interactions are forwarded to a callback
-- that goes through the same Engine validation as any remote request.

local Players = game:GetService("Players")

local Shared = require(script.Parent.Parent.Logic.Shared)
local Config, Creatures, Machines, Monetization, Format =
	Shared.Config, Shared.Creatures, Shared.Machines, Shared.Monetization, Shared.Format

local PlotService = {}

local SPACING = 170
local COLUMNS = 4

type PlotState = {
	index: number,
	model: Model,
	origin: Vector3,
	structSig: string,
	machines: { [string]: { model: Model, petSig: string, label: TextLabel, prompt: ProximityPrompt, builtSig: string } },
}

local plots: { [Player]: PlotState } = {}
local used: { [number]: boolean } = {}
local plotsFolder: Folder
local promptHandler: ((Player, string) -> ())? = nil

function PlotService.setPromptHandler(fn: (Player, string) -> ())
	promptHandler = fn
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function billboard(adornee: BasePart, offset: Vector3, width: number, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.RichText = true
	label.Text = ""
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	return label
end

local function rarityColor(rarity: number): Color3
	return Config.Rarities[rarity].color
end

----------------------------------------------------------------------------------------------------

function PlotService.init()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	local base = Instance.new("Part")
	base.Name = "Ground"
	base.Anchored = true
	base.Size = Vector3.new(COLUMNS * SPACING + 200, 2, 4 * SPACING + 200)
	base.CFrame = CFrame.new((COLUMNS - 1) * SPACING / 2, -1.5, (3 * SPACING) / 2)
	base.Color = Color3.fromRGB(38, 44, 58)
	base.Material = Enum.Material.Slate
	base.Parent = workspace

	-- a fallback spawn so characters never fall before being moved to their plot
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new((COLUMNS - 1) * SPACING / 2, 0.5, -60)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Parent = workspace
end

local function originFor(index: number): Vector3
	local i = index - 1
	return Vector3.new((i % COLUMNS) * SPACING, 0, (i // COLUMNS) * SPACING)
end

function PlotService.assign(player: Player): PlotState
	local existing = plots[player]
	if existing then
		return existing
	end
	local index = 1
	while used[index] do
		index += 1
	end
	used[index] = true
	local model = Instance.new("Model")
	model.Name = "Plot_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = plotsFolder
	local state: PlotState = { index = index, model = model, origin = originFor(index), structSig = "", machines = {} }
	plots[player] = state
	return state
end

function PlotService.release(player: Player)
	local state = plots[player]
	if state then
		state.model:Destroy()
		used[state.index] = nil
		plots[player] = nil
	end
end

function PlotService.spawnCFrame(player: Player): CFrame?
	local state = plots[player]
	if not state then
		return nil
	end
	return CFrame.new(state.origin + Vector3.new(0, 4, -34)) * CFrame.Angles(0, math.rad(180), 0)
end

--- Spot for a visitor (outside the owner's front edge, facing the factory).
function PlotService.visitorCFrame(owner: Player): CFrame?
	local state = plots[owner]
	if not state then
		return nil
	end
	return CFrame.new(state.origin + Vector3.new(0, 4, -46), state.origin + Vector3.new(0, 4, 0))
end

----------------------------------------------------------------------------------------------------
-- Structure (floor, railings, decor) rebuilt only when zone/theme change
----------------------------------------------------------------------------------------------------

local function buildStructure(state: PlotState, zone: number, themeId: string)
	local old = state.model:FindFirstChild("Structure")
	if old then
		old:Destroy()
	end
	local theme = Monetization.themes[themeId] or Monetization.themes.default
	local mat = Enum.Material[theme.material] or Enum.Material.Metal
	local folder = Instance.new("Folder")
	folder.Name = "Structure"
	folder.Parent = state.model

	local size = Machines.zones[zone].size
	local o = state.origin
	local floorCol = Color3.fromRGB(58, 64, 80)
	part(folder, "Floor", Vector3.new(size[1], 1, size[2]), CFrame.new(o + Vector3.new(0, 0.5, 0)), floorCol, Enum.Material.Concrete)

	-- railings
	local hx, hz = size[1] / 2, size[2] / 2
	local function rail(name: string, sx: number, sz: number, px: number, pz: number)
		part(folder, name, Vector3.new(sx, 2, sz), CFrame.new(o + Vector3.new(px, 2, pz)), theme.trim, mat)
	end
	rail("RailN", size[1], 0.6, 0, hz)
	rail("RailS1", size[1] / 2 - 6, 0.6, -(size[1] / 4 + 3), -hz)
	rail("RailS2", size[1] / 2 - 6, 0.6, size[1] / 4 + 3, -hz)
	rail("RailE", 0.6, size[2], hx, 0)
	rail("RailW", 0.6, size[2], -hx, 0)

	-- entrance sign
	local sign = part(folder, "Sign", Vector3.new(24, 6, 1), CFrame.new(o + Vector3.new(0, 9, -hz)), theme.trim, mat)
	local owner = Players:GetPlayerByUserId(state.model:GetAttribute("OwnerUserId") :: number)
	local lbl = billboard(sign, Vector3.new(0, 0, 0), 300, 70)
	lbl.Text = (if owner then owner.DisplayName else "Factory") .. "'s Empire"
	lbl.BackgroundTransparency = 1
	part(folder, "SignPostL", Vector3.new(1, 9, 1), CFrame.new(o + Vector3.new(-11, 4.5, -hz)), theme.trim, mat)
	part(folder, "SignPostR", Vector3.new(1, 9, 1), CFrame.new(o + Vector3.new(11, 4.5, -hz)), theme.trim, mat)

	-- zone decor: each unlocked zone visibly upgrades the factory
	if zone >= 2 then
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local pos = o + Vector3.new(sx * (hx - 2), 0, sz * (hz - 2))
				part(folder, "Pillar", Vector3.new(1.5, 14, 1.5), CFrame.new(pos + Vector3.new(0, 7, 0)), theme.trim, mat)
				local lamp = part(folder, "Lamp", Vector3.new(2.5, 2.5, 2.5), CFrame.new(pos + Vector3.new(0, 15, 0)), theme.accent, Enum.Material.Neon, Enum.PartType.Ball)
				local light = Instance.new("PointLight")
				light.Range = 26
				light.Brightness = 1.5
				light.Color = theme.accent
				light.Parent = lamp
			end
		end
	end
	if zone >= 3 then
		part(folder, "TrimStripN", Vector3.new(size[1] - 4, 0.2, 0.8), CFrame.new(o + Vector3.new(0, 1.1, hz - 3)), theme.accent, Enum.Material.Neon)
		part(folder, "TrimStripS", Vector3.new(size[1] - 4, 0.2, 0.8), CFrame.new(o + Vector3.new(0, 1.1, -hz + 3)), theme.accent, Enum.Material.Neon)
		local roof = part(folder, "GlassRoof", Vector3.new(size[1], 1, size[2]), CFrame.new(o + Vector3.new(0, 24, 0)), Color3.fromRGB(150, 200, 255), Enum.Material.Glass)
		roof.Transparency = 0.8
		roof.CanCollide = false
	end
	if zone >= 4 then
		local ring = part(folder, "SkyRing", Vector3.new(1, 50, 50), CFrame.new(o + Vector3.new(0, 34, 0)) * CFrame.Angles(0, 0, math.rad(90)), theme.accent, Enum.Material.Neon, Enum.PartType.Cylinder)
		ring.Transparency = 0.5
		ring.CanCollide = false
		local beam = part(folder, "Beacon", Vector3.new(3, 90, 3), CFrame.new(o + Vector3.new(0, 70, 0)), theme.accent, Enum.Material.Neon)
		beam.Transparency = 0.7
		beam.CanCollide = false
	end
end

----------------------------------------------------------------------------------------------------
-- Machines
----------------------------------------------------------------------------------------------------

local function ensureMachine(player: Player, state: PlotState, def: any): any
	local rec = state.machines[def.id]
	if rec then
		return rec
	end
	local o = state.origin
	local model = Instance.new("Model")
	model.Name = "M_" .. def.id
	model.Parent = state.model
	local pos = o + Vector3.new(def.pos[1], 0, def.pos[2])
	part(model, "Base", Vector3.new(11, 1, 11), CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(30, 34, 44), Enum.Material.DiamondPlate)
	local body = part(model, "Body", Vector3.new(7, 7, 7), CFrame.new(pos + Vector3.new(0, 5.5, 0)), def.color, Enum.Material.Metal)
	local core = part(model, "Core", Vector3.new(4, 4, 4), CFrame.new(pos + Vector3.new(0, 11, 0)), def.color, Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 18
	light.Parent = core
	local label = billboard(body, Vector3.new(0, 7, 0), 240, 66)
	local prompt = Instance.new("ProximityPrompt")
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = body
	prompt.Triggered:Connect(function(who: Player)
		if who == player and promptHandler then
			promptHandler(who, def.id)
		end
	end)
	rec = { model = model, petSig = "", label = label, prompt = prompt, builtSig = "" }
	state.machines[def.id] = rec
	return rec
end

local function setGhost(model: Model, ghost: boolean)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Base" then
			d.Transparency = if ghost then 0.75 else 0
			d.CanCollide = not ghost
		end
	end
end

local function rebuildPets(player: Player, rec: any, def: any, pos: Vector3, p: any, info: any)
	for _, d in ipairs(rec.model:GetChildren()) do
		if d.Name == "Pet" then
			d:Destroy()
		end
	end
	local n = 0
	for _, uid in ipairs(info.assigned) do
		local c = p.creatures[uid]
		local cdef = Creatures.byId[c.sp]
		local mut = Creatures.mutations[Creatures.mutationIndex[c.mut] or 1]
		n += 1
		local angle = (n - 1) * (math.pi / 2.2) + math.pi * 0.35
		local at = pos + Vector3.new(math.cos(angle) * 8.5, 3.2, math.sin(angle) * 8.5 + 0)
		local color = if c.mut ~= "normal" then mut.color else rarityColor(cdef.rarity)
		local pet = part(rec.model, "Pet", Vector3.new(2.6, 2.6, 2.6), CFrame.new(at), color, if c.mut ~= "normal" then Enum.Material.Neon else Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		pet.CanCollide = false
		if p.theme and p.owned and p.owned.fx_sparkle then
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = color
			sp.Parent = pet
		end
		local lbl = billboard(pet, Vector3.new(0, 2.6, 0), 160, 40)
		lbl.Text = string.format("<font color='#%s'>%s</font> L%d", rarityColor(cdef.rarity):ToHex(), cdef.name, c.lvl)
		lbl.TextSize = 14
	end
end

--- Syncs the plot with the profile. Cheap when nothing changed.
function PlotService.update(player: Player, p: any, stats: any)
	local state = plots[player]
	if not state then
		return
	end
	local structSig = p.zone .. ":" .. (p.theme or "default")
	if state.structSig ~= structSig then
		state.structSig = structSig
		buildStructure(state, p.zone, p.theme or "default")
	end

	for _, def in ipairs(Machines.list) do
		if def.zone <= p.zone then
			local rec = ensureMachine(player, state, def)
			local m = p.machines[def.id]
			local pos = state.origin + Vector3.new(def.pos[1], 0, def.pos[2])
			local builtSig = if m then "b" else "g"
			if rec.builtSig ~= builtSig then
				rec.builtSig = builtSig
				setGhost(rec.model, m == nil)
				rec.prompt.ActionText = if m then "Upgrade" else "Build ($" .. Format.number(def.unlockCost) .. ")"
				rec.prompt.ObjectText = def.name
				rec.petSig = "" -- force pet refresh
			end
			if m then
				local info = stats.machines[def.id]
				local text = string.format("%s\n<font color='#9ff'>Lv %d</font> | +%s %s/s", def.name, m.level, Format.rate(info.rate), def.produces)
				if rec.label.Text ~= text then
					rec.label.Text = text
				end
				local sig = table.concat(info.assigned, ",")
				for _, uid in ipairs(info.assigned) do
					local c = p.creatures[uid]
					sig ..= c.sp .. c.mut .. c.lvl
				end
				if sig ~= rec.petSig then
					rec.petSig = sig
					rebuildPets(player, rec, def, pos, p, info)
				end
			else
				local text = string.format("%s\nBuild for $%s", def.name, Format.number(def.unlockCost))
				if rec.label.Text ~= text then
					rec.label.Text = text
				end
				if rec.petSig ~= "ghost" then
					rec.petSig = "ghost"
					for _, d in ipairs(rec.model:GetChildren()) do
						if d.Name == "Pet" then
							d:Destroy()
						end
					end
				end
			end
		end
	end
end

function PlotService.moveCharacter(player: Player, cf: CFrame?)
	local char = player.Character
	if char and cf then
		char:PivotTo(cf)
	end
end

return PlotService
