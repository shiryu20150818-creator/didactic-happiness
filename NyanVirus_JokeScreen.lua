--[[
	N Y A N . E X E   -   JOKE SCREEN-WRECKER (mobile / executor UI)
	=====================================================================
	A harmless "joke virus" simulator. EVERYTHING is local to your own screen:
	  * no remotes, no server calls, nothing is sent to other players
	  * only touches your own GUI layers, your own Lighting post-effects and your own camera
	  * a STOP button is always on screen (it sits above every effect) + auto-stop timer
	  * Safe mode (default ON) limits flash rate / brightness / camera motion

	What a real joke-virus (MEMZ / Nyan style) does to a screen, and how it is rebuilt here:
	  TV static ........ hundreds of random grey cells re-rolled ~24x/s (+ chroma cells)
	  VHS roll ......... scanlines + a bright band rolling down + horizontal wobble
	  tearing .......... short glitch bars, shifted sideways, cyan / magenta / white / black
	  melt ............. dark columns of different speed dripping down with soft ends
	  colour flip ...... hue cycling + invert-like pulses (ColorCorrection, client only)
	  blackout ......... pulsing dim, vignette, random brown-outs
	  camera warp ...... shake / roll / FOV pulse (render-step offset, restored on stop)
	  blur pulses ...... BlurEffect that breathes with the chaos level
	  popup flood ...... retro error windows that multiply when you close them
	  fake BSOD ........ blue screen with fake progress counter
	  code rain ........ falling hex / katakana columns
	  rainbow cat ...... a pixel cat on toast with a wavy rainbow trail (drawn from Frames)
	  touch trail ...... your finger leaves a rainbow of fading squares
	  dead pixels ...... stuck red / green / blue / white dots that blink
	  infection log .... fake "[ FAIL ] payload.dll" ticker
	  banner ........... glitchy RGB-split headline
	  CRT boot/shutdown  curtain closes to a line, a dot, and opens back up
	Scenarios run these as a scripted timeline (Nyan Joke, Static Storm, ...).
]]

-- ======================================================================
-- SERVICES
-- ======================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

local function Notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = duration
	})
end

if getgenv().NyanVirus then
	pcall(function() getgenv().NyanVirus.Unload() end)
end

-- ======================================================================
-- CORE TABLE (one table instead of hundreds of locals)
-- ======================================================================
local V = {
	Conns = {}, FX = {}, Order = {}, Eff = {}, Layers = {},
	Running = false, RunT = 0, EndAt = 0, LastFlash = 0, Dead = false,
	R = Random.new(),
	Scn = nil, ScnIdx = 1, SavedSel = nil,
	Cfg = {
		Master = 0.7, Safe = true, Duration = 60, AutoStop = true,
		Sound = false, Volume = 0.25, Quality = 1, Boot = true, Shutdown = true, Lang = "ja",
	},
	UI = {OnState = function() end, Refresh = function() end, Stage = function() end},
}

function V.New(class, props)
	local o = Instance.new(class)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end

function V.T(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function V.Connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(V.Conns, c)
	return c
end

function V.Rf(a, b) return a + V.R:NextNumber() * (b - a) end
function V.Ri(a, b) return V.R:NextInteger(a, b) end
function V.Pick(t) return t[V.R:NextInteger(1, #t)] end
function V.Tr(ja, en) if V.Cfg.Lang == "ja" then return ja end return en end
function V.Clamp(v, a, b) return math.max(a, math.min(b, v)) end

function V.RandName()
	local s = ""
	for _ = 1, 10 do s = s .. string.char(V.Ri(97, 122)) end
	return s
end

function V.Corner(p, r)
	return V.New("UICorner", {CornerRadius = UDim.new(0, r), Parent = p})
end

function V.ParentGui(g)
	local ok = pcall(function() g.Parent = CoreGui end)
	if not ok or not g.Parent then
		g.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

-- ======================================================================
-- GUI ROOTS
--   V.Gui  = effect overlay (DisplayOrder 500, never blocks touches except popups / BSOD)
--   V.CGui = control UI + STOP button (DisplayOrder 1000, always above the effects)
-- ======================================================================
V.Gui = V.New("ScreenGui", {
	Name = V.RandName(), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 500,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
V.ParentGui(V.Gui)
V.CGui = V.New("ScreenGui", {
	Name = V.RandName(), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
V.ParentGui(V.CGui)

function V.Layer(name, z)
	V.DropLayer(name)
	local f = V.New("Frame", {
		Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false,
		ZIndex = z, ClipsDescendants = true, BorderSizePixel = 0, Parent = V.Gui,
	})
	V.Layers[name] = f
	return f
end

function V.DropLayer(name)
	local l = V.Layers[name]
	if l then
		pcall(function() l:Destroy() end)
		V.Layers[name] = nil
	end
end

-- Lighting post effects (client only). Created lazily, destroyed on stop.
function V.Ensure(key, class, props)
	local o = V.Eff[key]
	if o and o.Parent then return o end
	o = V.New(class, props or {})
	o.Name = "NV_" .. key
	o.Parent = Lighting
	V.Eff[key] = o
	return o
end

function V.DropEff(key)
	local o = V.Eff[key]
	if o then
		pcall(function() o:Destroy() end)
		V.Eff[key] = nil
	end
end

function V.ClearEff()
	for k in pairs(V.Eff) do V.DropEff(k) end
end

function V.Cam()
	return workspace.CurrentCamera
end

-- ======================================================================
-- SAFETY HELPERS
-- ======================================================================
-- V.Allow(interval): in safe mode a strobe-like event may only fire every >= max(interval, 0.34s)
function V.Allow(key, interval)
	V.Gate = V.Gate or {}
	local now = tick()
	local minI = interval
	if V.Cfg.Safe then minI = math.max(interval, 0.34) end
	if now - (V.Gate[key] or 0) >= minI then
		V.Gate[key] = now
		return true
	end
	return false
end

function V.Beep(pitch, vol)
	if not V.Cfg.Sound then return end
	local s = V.New("Sound", {
		SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = vol or V.Cfg.Volume,
		PlaybackSpeed = pitch or 1, Parent = SoundService,
	})
	s:Play()
	Debris:AddItem(s, 3)
end

-- full-screen flash (above every effect, below the control UI)
V.FlashFrame = V.New("Frame", {
	Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
	BorderSizePixel = 0, Active = false, ZIndex = 40, Parent = V.Gui,
})
function V.Flash(color, alpha, dur)
	if not V.Allow("flash", 0.34) then return false end
	if V.Cfg.Safe then alpha = math.min(alpha, 0.3) end
	V.FlashFrame.BackgroundColor3 = color
	V.FlashFrame.BackgroundTransparency = 1 - alpha
	V.T(V.FlashFrame, dur or 0.2, {BackgroundTransparency = 1})
	return true
end

-- ======================================================================
-- TOUCH DRAG (shared) - popups, windows, orb
-- ======================================================================
V.DragH, V.DragE = nil, nil
V.Connect(UserInputService.InputChanged, function(i)
	if V.DragH and i.UserInputType == Enum.UserInputType.Touch then V.DragH(i.Position) end
end)
V.Connect(UserInputService.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.Touch and V.DragE then V.DragE() end
end)
function V.Draggable(handle, target, onTap, onStart)
	V.Connect(handle.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		if onStart then onStart() end
		local start = input.Position
		local sp = target.Position
		local moved = false
		V.DragH = function(pos)
			local d = pos - start
			if d.Magnitude > 8 then moved = true end
			if moved then
				target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
			end
		end
		V.DragE = function()
			V.DragH = nil
			V.DragE = nil
			if not moved and onTap then onTap() end
		end
	end)
end

-- ======================================================================
-- EFFECT REGISTRY + RUNNER
-- ======================================================================
function V.Define(id, ja, en, def, api)
	V.FX[id] = {id = id, ja = ja, en = en, level = def, sel = false, on = false, api = api, ctx = {}, t0 = 0, def = def}
	table.insert(V.Order, id)
end

function V.StartFX(id)
	local fx = V.FX[id]
	if not fx or fx.on then return end
	fx.on = true
	fx.t0 = tick()
	fx.ctx = {}
	local ok, err = pcall(fx.api.Start, fx.ctx, fx)
	if not ok then
		fx.on = false
		fx.sel = false
		Notify("NyanVirus", id .. " start: " .. string.sub(tostring(err), 1, 90), 5)
	end
end

function V.StopFX(id)
	local fx = V.FX[id]
	if not fx or not fx.on then return end
	fx.on = false
	pcall(fx.api.Stop, fx.ctx, fx)
	fx.ctx = {}
end

function V.SetSel(id, on)
	local fx = V.FX[id]
	if not fx then return end
	fx.sel = on
	if V.Running then
		if on then V.StartFX(id) else V.StopFX(id) end
	end
end

function V.SetLevel(id, lv)
	local fx = V.FX[id]
	if fx then fx.level = V.Clamp(lv, 0, 1) end
end

-- ---------------- CRT curtain (boot / shutdown) ----------------
-- closes onto a bright line, calls cb() while the screen is black, then opens again
function V.Curtain(closing, cb)
	local layer = V.Layer("Curtain", 30)
	local top = V.New("Frame", {Size = UDim2.new(1, 0, 0.5, 1), Position = UDim2.fromScale(0, closing and -0.5 or 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 30, Parent = layer})
	local bot = V.New("Frame", {Size = UDim2.new(1, 0, 0.5, 1), Position = UDim2.fromScale(0, closing and 1 or 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 30, Parent = layer})
	local line = V.New("Frame", {Size = UDim2.new(0, 0, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 31, Parent = layer})
	local dot = V.New("Frame", {Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 32, Parent = layer})
	V.Corner(dot, 20)
	task.spawn(function()
		if closing then
			V.T(top, 0.4, {Position = UDim2.fromScale(0, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			V.T(bot, 0.4, {Position = UDim2.fromScale(0, 0.5)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			task.wait(0.4)
			V.T(line, 0.15, {Size = UDim2.new(1, 0, 0, 3)})
			task.wait(0.15)
			if cb then pcall(cb) end
			V.T(line, 0.25, {Size = UDim2.new(0, 10, 0, 3)})
			task.wait(0.22)
			dot.Size = UDim2.fromOffset(12, 12)
			line.Visible = false
			task.wait(0.12)
			V.T(dot, 0.2, {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1})
			top.BackgroundTransparency = 0
			V.T(top, 0.35, {Position = UDim2.fromScale(0, -0.5)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			V.T(bot, 0.35, {Position = UDim2.fromScale(0, 1)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(0.4)
		else
			line.Size = UDim2.new(0, 10, 0, 3)
			V.T(line, 0.25, {Size = UDim2.new(1, 0, 0, 3)}, Enum.EasingStyle.Quart)
			task.wait(0.28)
			if cb then pcall(cb) end
			V.T(top, 0.4, {Position = UDim2.fromScale(0, -0.5)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			V.T(bot, 0.4, {Position = UDim2.fromScale(0, 1)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			V.T(line, 0.4, {BackgroundTransparency = 1})
			task.wait(0.45)
		end
		V.DropLayer("Curtain")
	end)
end

-- ---------------- begin / end ----------------
function V.Begin()
	if V.Running or V.Dead then return end
	V.Running = true
	V.RunT = 0
	V.EndAt = tick() + V.Cfg.Duration
	local function go()
		if not V.Running then return end
		if V.Scn then
			V.ScnIdx = 1
		else
			for _, id in ipairs(V.Order) do
				if V.FX[id].sel then V.StartFX(id) end
			end
		end
	end
	if V.Cfg.Boot then
		V.RunT = -0.6
		task.spawn(function() V.Curtain(false, go) end)
	else
		go()
	end
	V.UI.OnState(true)
end

function V.End(instant)
	if not V.Running then return end
	V.Running = false
	local function finish()
		for _, id in ipairs(V.Order) do V.StopFX(id) end
		V.ClearEff()
		if V.SavedSel then
			for id, st in pairs(V.SavedSel) do
				if V.FX[id] then
					V.FX[id].sel = st.sel
					V.FX[id].level = st.level
				end
			end
			V.SavedSel = nil
		end
		V.Scn = nil
		V.UI.OnState(false)
		V.UI.Refresh()
	end
	if instant or not V.Cfg.Shutdown or V.Dead then
		finish()
		V.DropLayer("Curtain")
	else
		V.Curtain(true, finish)
	end
end

-- panic: kill everything right now, no animation
function V.Panic()
	V.Running = false
	for _, id in ipairs(V.Order) do V.StopFX(id) end
	V.ClearEff()
	V.DropLayer("Curtain")
	V.FlashFrame.BackgroundTransparency = 1
	if V.SavedSel then
		for id, st in pairs(V.SavedSel) do
			if V.FX[id] then
				V.FX[id].sel = st.sel
				V.FX[id].level = st.level
			end
		end
		V.SavedSel = nil
	end
	V.Scn = nil
	V.UI.OnState(false)
	V.UI.Refresh()
end

-- ---------------- scenarios (timeline) ----------------
V.Scenarios = {}
function V.AddScenario(id, ja, en, dur, events)
	table.sort(events, function(a, b) return a.t < b.t end)
	table.insert(V.Scenarios, {id = id, ja = ja, en = en, dur = dur, events = events})
end

function V.RunScenario(sc)
	if V.Running then V.End(true) end
	V.SavedSel = {}
	for id, fx in pairs(V.FX) do
		V.SavedSel[id] = {sel = fx.sel, level = fx.level}
		fx.sel = false
	end
	V.Scn = sc
	V.ScnIdx = 1
	V.Cfg.Duration = sc.dur
	V.Begin()
end

-- ---------------- main loop ----------------
V.Frames, V.FpsAcc, V.Fps = 0, 0, 60
V.Connect(RunService.Heartbeat, function(dt)
	V.Frames = V.Frames + 1
	V.FpsAcc = V.FpsAcc + dt
	if V.FpsAcc >= 0.5 then
		V.Fps = math.floor(V.Frames / V.FpsAcc + 0.5)
		V.Frames, V.FpsAcc = 0, 0
	end
	if not V.Running then return end
	V.RunT = V.RunT + dt
	if V.RunT < 0 then return end
	local ramp = math.min(1, V.RunT / 2.5)
	local now = tick()
	for _, id in ipairs(V.Order) do
		local fx = V.FX[id]
		if fx.on then
			local k = V.Clamp(fx.level * V.Cfg.Master * ramp, 0, 1)
			if V.Cfg.Safe then k = k * 0.8 end
			local ok, err = pcall(fx.api.Step, fx.ctx, dt, now - fx.t0, k)
			if not ok then
				V.StopFX(id)
				fx.sel = false
				Notify("NyanVirus", id .. ": " .. string.sub(tostring(err), 1, 90), 5)
				V.UI.Refresh()
			end
		end
	end
	if V.Scn then
		local ev = V.Scn.events
		while V.ScnIdx <= #ev and ev[V.ScnIdx].t <= V.RunT do
			local e = ev[V.ScnIdx]
			V.ScnIdx = V.ScnIdx + 1
			local ok, err = pcall(e.fn)
			if not ok then Notify("NyanVirus", "scenario: " .. string.sub(tostring(err), 1, 90), 5) end
			if e.label then V.UI.Stage(e.label) end
		end
	end
	if V.Cfg.AutoStop and tick() >= V.EndAt then
		V.End(false)
	end
end)

-- ======================================================================
-- EFFECTS 1/3  -  signal damage (static / scanlines / tearing / melt)
-- ======================================================================
local GREY = function(g) return Color3.fromRGB(g, g, g) end
local NEON = {
	Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 255, 0),
	Color3.fromRGB(255, 40, 60), Color3.fromRGB(60, 255, 120), Color3.fromRGB(80, 120, 255),
}

-- ---------------- 1. TV static ----------------
do
	V.Define("static", "テレビノイズ", "TV Static", 0.7, {
		Start = function(c)
			local q = V.Cfg.Quality
			c.cols = math.max(8, math.floor(22 * q))
			c.rows = math.max(5, math.floor(12 * q))
			c.layer = V.Layer("Static", 4)
			c.cells = {}
			for y = 0, c.rows - 1 do
				for x = 0, c.cols - 1 do
					local f = V.New("Frame", {
						Size = UDim2.new(1 / c.cols, 1, 1 / c.rows, 1),
						Position = UDim2.fromScale(x / c.cols, y / c.rows),
						BorderSizePixel = 0, BackgroundTransparency = 1, Parent = c.layer,
					})
					table.insert(c.cells, f)
				end
			end
			c.acc = 0
		end,
		Step = function(c, dt, t, k)
			c.acc = c.acc + dt
			if c.acc < 1 / 24 then return end
			c.acc = 0
			local chroma = 0.03 + 0.05 * k
			for _, f in ipairs(c.cells) do
				local alpha = k * (0.1 + 0.6 * V.R:NextNumber())
				if V.R:NextNumber() < chroma then
					f.BackgroundColor3 = V.Pick(NEON)
					alpha = alpha * 0.8
				else
					f.BackgroundColor3 = GREY(V.Ri(0, 255))
				end
				f.BackgroundTransparency = 1 - alpha
			end
			-- occasional full-width horizontal noise line
			if V.R:NextNumber() < 0.15 * k then
				local l = V.New("Frame", {
					Size = UDim2.new(1, 0, 0, V.Ri(1, 4)), Position = UDim2.fromScale(0, V.R:NextNumber()),
					BackgroundColor3 = GREY(V.Ri(120, 255)), BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = c.layer,
				})
				Debris:AddItem(l, 0.08)
			end
		end,
		Stop = function(c) V.DropLayer("Static") end,
	})
end

-- ---------------- 2. scanlines + VHS roll ----------------
do
	V.Define("scan", "走査線 / VHSロール", "Scanlines / VHS roll", 0.6, {
		Start = function(c)
			local q = V.Cfg.Quality
			c.n = math.max(24, math.floor(64 * q))
			c.layer = V.Layer("Scan", 6)
			c.lines = {}
			for i = 0, c.n - 1 do
				if i % 2 == 0 then
					local f = V.New("Frame", {
						Size = UDim2.new(1, 0, 1 / c.n, 0), Position = UDim2.fromScale(0, i / c.n),
						BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = c.layer,
					})
					table.insert(c.lines, f)
				end
			end
			c.band = V.New("Frame", {
				Size = UDim2.fromScale(1, 0.16), Position = UDim2.fromScale(0, -0.2), BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0, BorderSizePixel = 0, Parent = c.layer,
			})
			V.New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = c.band,
			})
			c.y = -0.2
		end,
		Step = function(c, dt, t, k)
			local lt = 1 - 0.45 * k
			for _, f in ipairs(c.lines) do f.BackgroundTransparency = lt end
			c.y = c.y + dt * (0.18 + 0.5 * k)
			if c.y > 1.1 then c.y = -0.25 end
			c.band.Position = UDim2.fromScale(0, c.y)
			c.band.BackgroundTransparency = 1 - 0.35 * k
			local wob = math.sin(t * 7) * 0.004 * k + (V.R:NextNumber() - 0.5) * 0.006 * k
			c.layer.Position = UDim2.fromScale(wob, 0)
		end,
		Stop = function(c) V.DropLayer("Scan") end,
	})
end

-- ---------------- 3. glitch bars (tearing) ----------------
do
	V.Define("bars", "ティアリング(グリッチバー)", "Tearing glitch bars", 0.7, {
		Start = function(c)
			c.layer = V.Layer("Bars", 5)
			c.bars = {}
			local n = math.max(6, math.floor(12 * V.Cfg.Quality))
			for _ = 1, n do
				local f = V.New("Frame", {
					Size = UDim2.fromScale(1, 0.02), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = c.layer,
				})
				table.insert(c.bars, {f = f, life = V.Rf(0, 0.2)})
			end
		end,
		Step = function(c, dt, t, k)
			for _, b in ipairs(c.bars) do
				b.life = b.life - dt
				if b.life <= 0 then
					if V.R:NextNumber() < 0.2 + 0.7 * k then
						local h = 0.004 + V.R:NextNumber() * (0.02 + 0.07 * k)
						local shift = (V.R:NextNumber() - 0.5) * 0.3 * (0.3 + k)
						local pick = V.Ri(1, 6)
						local col
						if pick <= 2 then col = Color3.fromRGB(0, 255, 255)
						elseif pick <= 4 then col = Color3.fromRGB(255, 0, 255)
						elseif pick == 5 then col = Color3.new(1, 1, 1)
						else col = Color3.new(0, 0, 0) end
						b.f.Size = UDim2.fromScale(0.4 + V.R:NextNumber() * 0.7, h)
						b.f.Position = UDim2.fromScale(shift, V.R:NextNumber())
						b.f.BackgroundColor3 = col
						b.f.BackgroundTransparency = V.Rf(0.3, 0.75)
						b.life = V.Rf(0.03, 0.18)
					else
						b.f.BackgroundTransparency = 1
						b.life = V.Rf(0.02, 0.25)
					end
				end
			end
		end,
		Stop = function(c) V.DropLayer("Bars") end,
	})
end

-- ---------------- 4. melt ----------------
do
	local MELT_COL = {
		Color3.fromRGB(8, 0, 18), Color3.fromRGB(38, 0, 58), Color3.fromRGB(0, 26, 30),
		Color3.fromRGB(58, 0, 12), Color3.fromRGB(10, 10, 10), Color3.fromRGB(0, 20, 60),
	}
	V.Define("melt", "メルト(溶ける画面)", "Screen melt", 0.6, {
		Start = function(c)
			c.layer = V.Layer("Melt", 2)
			c.cols = {}
			local n = math.max(14, math.floor(36 * V.Cfg.Quality))
			c.n = n
			for i = 0, n - 1 do
				local f = V.New("Frame", {
					Size = UDim2.new(1 / n, 1, 0, 0), Position = UDim2.fromScale(i / n, 0),
					BackgroundColor3 = V.Pick(MELT_COL), BorderSizePixel = 0, BackgroundTransparency = 0.2, Parent = c.layer,
				})
				V.New("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.82, 0.1), NumberSequenceKeypoint.new(1, 1),
					}),
					Parent = f,
				})
				table.insert(c.cols, {f = f, h = 0, sp = V.Rf(0.08, 0.5), delay = V.Rf(0, 4), idx = i})
			end
		end,
		Step = function(c, dt, t, k)
			for _, col in ipairs(c.cols) do
				local active = (col.idx / c.n) < (k + 0.15)
				if not active then
					col.f.Size = UDim2.new(1 / c.n, 1, 0, 0)
				elseif col.delay > 0 then
					col.delay = col.delay - dt
				else
					col.h = col.h + col.sp * dt * (0.4 + 1.6 * k)
					if col.h > 1.25 then
						col.h = 0
						col.delay = V.Rf(0.5, 4)
						col.sp = V.Rf(0.08, 0.5)
						col.f.BackgroundColor3 = V.Pick(MELT_COL)
					end
					col.f.Size = UDim2.new(1 / c.n, 1, col.h, 0)
					col.f.BackgroundTransparency = 1 - 0.85 * k
				end
			end
		end,
		Stop = function(c) V.DropLayer("Melt") end,
	})
end

-- ======================================================================
-- EFFECTS 2/3  -  colour, light, camera
-- ======================================================================

-- ---------------- 5. colour flip ----------------
do
	V.Define("flip", "色反転 / 色相ぐるぐる", "Colour flip / hue spin", 0.7, {
		Start = function(c)
			c.cc = V.Ensure("cc", "ColorCorrectionEffect")
			c.inv = 0
			c.nextInv = 2
		end,
		Step = function(c, dt, t, k)
			local cc = c.cc
			local hue = (t * (0.12 + 0.3 * k)) % 1
			local tint = Color3.fromHSV(hue, 0.5 * k, 1)
			local sat = math.sin(t * 1.3) * 1.1 * k
			local con = 0.1 * k
			local bri = 0
			-- invert-like pulse: washed negative look (Roblox cannot do a true pixel negative)
			c.nextInv = c.nextInv - dt
			if c.nextInv <= 0 and V.Allow("invert", 1.2) then
				c.inv = V.Rf(0.12, 0.35)
				c.nextInv = V.Rf(1.6, 4.5) / (0.4 + k)
			end
			if c.inv > 0 then
				c.inv = c.inv - dt
				sat = -1
				con = 0.9 * math.min(1, k + 0.3)
				bri = 0.12
				tint = Color3.fromRGB(180, 255, 255):Lerp(Color3.fromHSV(1 - hue, 0.7, 1), 0.4)
			end
			cc.Saturation = sat
			cc.Contrast = con
			cc.Brightness = bri
			cc.TintColor = tint
		end,
		Stop = function(c) V.DropEff("cc") end,
	})
end

-- ---------------- 6. blackout / vignette ----------------
do
	V.Define("dark", "暗転 / ブラウンアウト", "Blackout / brown-out", 0.6, {
		Start = function(c)
			c.layer = V.Layer("Dark", 1)
			c.dim = V.New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = c.layer})
			c.edges = {}
			local defs = {
				{UDim2.new(0, 0, 0, 0), UDim2.new(0.28, 0, 1, 0), 0},
				{UDim2.new(0.72, 0, 0, 0), UDim2.new(0.28, 0, 1, 0), 180},
				{UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.32, 0), 90},
				{UDim2.new(0, 0, 0.68, 0), UDim2.new(1, 0, 0.32, 0), 270},
			}
			for _, d in ipairs(defs) do
				local f = V.New("Frame", {Position = d[1], Size = d[2], BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = c.layer})
				V.New("UIGradient", {Rotation = d[3], Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}), Parent = f})
				table.insert(c.edges, f)
			end
			c.cc = V.Ensure("ccDark", "ColorCorrectionEffect")
			c.brown = 0
		end,
		Step = function(c, dt, t, k)
			local pulse = 0.5 + 0.5 * math.sin(t * 1.6)
			local dim = k * (0.22 + 0.3 * pulse)
			c.brown = c.brown - dt
			if c.brown <= 0 and V.R:NextNumber() < 0.01 * (0.5 + k) and V.Allow("brown", 0.7) then
				c.brown = V.Rf(0.05, 0.14)
			end
			if c.brown > 0 then dim = math.max(dim, 0.55 * k + 0.2) end
			c.dim.BackgroundTransparency = 1 - V.Clamp(dim, 0, 0.85)
			for _, e in ipairs(c.edges) do e.BackgroundTransparency = 1 - (0.5 + 0.4 * k) end
			c.cc.Brightness = -0.12 * k * (0.6 + 0.4 * pulse)
		end,
		Stop = function(c)
			V.DropLayer("Dark")
			V.DropEff("ccDark")
		end,
	})
end

-- ---------------- 7. camera warp ----------------
do
	V.Define("warp", "カメラ歪み(揺れ/傾き/FOV)", "Camera warp (shake/roll/FOV)", 0.5, {
		Start = function(c)
			local cam = V.Cam()
			c.baseFov = cam.FieldOfView
			c.k = 0
			c.t = 0
			local id = "NV_Warp_" .. V.RandName()
			c.bind = id
			RunService:BindToRenderStep(id, Enum.RenderPriority.Camera.Value + 1, function(dt)
				local cm = V.Cam()
				if not cm or not c.alive then return end
				c.t = c.t + dt
				local k = c.k
				local safe = V.Cfg.Safe and 0.6 or 1
				local roll = (math.sin(c.t * 0.9) * 0.1 + (V.R:NextNumber() - 0.5) * 0.02) * k * safe
				local sh = Vector3.new((V.R:NextNumber() - 0.5), (V.R:NextNumber() - 0.5), 0) * 0.18 * k * safe
				cm.FieldOfView = c.baseFov + math.sin(c.t * 1.3) * 16 * k * safe
				cm.CFrame = cm.CFrame * CFrame.new(sh) * CFrame.Angles(0, 0, roll)
			end)
			c.alive = true
		end,
		Step = function(c, dt, t, k) c.k = k end,
		Stop = function(c)
			c.alive = false
			if c.bind then pcall(function() RunService:UnbindFromRenderStep(c.bind) end) end
			local cam = V.Cam()
			if cam and c.baseFov then cam.FieldOfView = c.baseFov end
		end,
	})
end

-- ---------------- 8. blur pulses ----------------
do
	V.Define("blur", "ぼかしパルス", "Blur pulses", 0.5, {
		Start = function(c) c.b = V.Ensure("blur", "BlurEffect", {Size = 0}) end,
		Step = function(c, dt, t, k)
			local s = k * (6 + 16 * math.abs(math.sin(t * 2.1)))
			if V.Cfg.Safe then s = s * 0.6 end
			c.b.Size = s
		end,
		Stop = function(c) V.DropEff("blur") end,
	})
end

-- ======================================================================
-- EFFECTS 3/3  -  fake system chaos (popups / BSOD / code rain / ticker / banner)
-- ======================================================================
local GuiService = game:GetService("GuiService")
local function Inset()
	local ok, v = pcall(function() return GuiService:GetGuiInset() end)
	return (ok and v) and v or Vector2.new(0, 0)
end

-- ---------------- message data (all fake / jokes) ----------------
local POP_TITLES = {
	{"エラー", "Error"}, {"警告", "Warning"}, {"システム", "System"}, {"重大な問題", "Critical"},
	{"確認", "Confirm"}, {"ニャン.exe", "nyan.exe"}, {"ウイルス対策", "Antivirus"}, {"更新", "Update"},
	{"ストレージ", "Storage"}, {"ネットワーク", "Network"},
}
local POP_MSGS = {
	{"あなたの端末はネコに感染しました。", "Your device has been infected by cats."},
	{"レインボー.dll が応答していません。", "rainbow.dll is not responding."},
	{"ホームワークを削除しています... (ウソ)", "Deleting homework... (just kidding)"},
	{"このメッセージを閉じるともっと増えます。", "Closing this will make more of them."},
	{"空腹のため処理を続行できません。トーストを入れてください。", "Out of toast. Please insert toast to continue."},
	{"画面の色が反転しました。元に戻しますか?", "Your screen colours are flipped. Restore?"},
	{"3,000,000個のニャンを検出しました。", "3,000,000 nyans detected."},
	{"ファイル 'おやつ.txt' が見つかりません。", "File 'snacks.txt' not found."},
	{"重力を再計算しています...", "Recalculating gravity..."},
	{"あなたはこの画面を3秒見つめました。", "You have stared at this screen for 3 seconds."},
	{"ウイルスが「ごめんね」と言っています。", "The virus says: sorry!"},
	{"メモリ不足: ネコ(100%)", "Out of memory: cats (100%)"},
	{"これはジョークです。何も壊れません。", "This is a joke. Nothing is broken."},
	{"レインボーバッファがオーバーフローしました。", "Rainbow buffer overflow."},
	{"アップデートを確認中... 永遠に。", "Checking for updates... forever."},
	{"お使いのWi-Fiが猫のポーズをしています。", "Your Wi-Fi is doing a cat pose."},
	{"エラーが発生しました。もう一度エラーを発生させますか?", "An error occurred. Cause another error?"},
	{"キーボードが見つかりません。続行するにはEnterを押してください。", "Keyboard not found. Press Enter to continue."},
	{"クリックありがとう! ボーナスのポップアップをどうぞ。", "Thanks for clicking! Here is a bonus popup."},
	{"システムは正常です。たぶん。", "System is fine. Probably."},
	{"ニャンキャットが画面を横切りました。", "A nyan cat crossed your screen."},
	{"ピクセルが逃げ出しました。", "Some pixels have escaped."},
	{"この操作は取り消せません (取り消せます)。", "This cannot be undone (it can)."},
	{"ディスクの空き容量: ∞ (ウソ)", "Disk space: infinity (not really)"},
}
local POP_ICONS = {
	{"X", Color3.fromRGB(220, 30, 30)}, {"!", Color3.fromRGB(240, 190, 20)},
	{"?", Color3.fromRGB(40, 110, 220)}, {"i", Color3.fromRGB(40, 150, 220)},
}
local BTN_JA = {"OK", "キャンセル", "はい", "いいえ", "閉じる", "無視"}
local BTN_EN = {"OK", "Cancel", "Yes", "No", "Close", "Ignore"}

-- ---------------- 9. popup flood ----------------
do
	V.Define("popups", "ポップアップ連打(増殖)", "Popup flood (multiplies)", 0.5, {
		Start = function(c)
			c.layer = V.Layer("Pops", 12)
			c.list = {}
			c.z = 1
			c.acc = 0
			c.spawn = nil
		end,
		Step = function(c, dt, t, k)
			-- cap and interval scale with intensity
			c.cap = math.floor(5 + 14 * k)
			c.acc = c.acc + dt
			local interval = 1.6 / (0.3 + k * 2.4)
			if c.acc >= interval and #c.list < c.cap then
				c.acc = 0
				c.spawn()
			end
		end,
		Stop = function(c) V.DropLayer("Pops") end,
	})
	-- the popup factory lives on the effect so Start can bind it to the new layer
	local fx = V.FX["popups"]
	local origStart = fx.api.Start
	fx.api.Start = function(c, f)
		origStart(c, f)
		c.spawn = function()
			if not c.layer or not c.layer.Parent then return end
			local vp = V.Cam().ViewportSize
			local w, h = 250, 120
			local x = V.Ri(0, math.max(1, math.floor(vp.X - w)))
			local y = V.Ri(0, math.max(1, math.floor(vp.Y - h)))
			c.z = c.z + 1
			local pop = V.New("Frame", {
				Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y), BackgroundColor3 = Color3.fromRGB(192, 192, 192),
				BorderSizePixel = 0, ZIndex = c.z, Active = true, Parent = c.layer,
			})
			V.New("UIStroke", {Thickness = 2, Color = Color3.new(0, 0, 0), Parent = pop})
			local title = V.Pick(POP_TITLES)
			local msg = V.Pick(POP_MSGS)
			local bar = V.New("Frame", {Size = UDim2.new(1, -4, 0, 22), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = pop})
			V.New("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(0, 0, 128), Color3.fromRGB(16, 132, 208)), Parent = bar})
			V.New("TextLabel", {
				Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(6, 0), BackgroundTransparency = 1,
				Text = "[JOKE] " .. V.Tr(title[1], title[2]), Font = Enum.Font.GothamBold, TextSize = 12,
				TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = bar,
			})
			local close = V.New("TextButton", {
				Size = UDim2.fromOffset(18, 16), Position = UDim2.new(1, -20, 0, 3), BackgroundColor3 = Color3.fromRGB(192, 192, 192),
				Text = "X", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(0, 0, 0), AutoButtonColor = false, Parent = bar,
			})
			V.New("UIStroke", {Thickness = 1, Color = Color3.new(0, 0, 0), Parent = close})
			local ic = V.Pick(POP_ICONS)
			local icon = V.New("Frame", {Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(12, 36), BackgroundColor3 = ic[2], BorderSizePixel = 0, Parent = pop})
			V.Corner(icon, 16)
			V.New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = ic[1], Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Parent = icon})
			V.New("TextLabel", {
				Size = UDim2.new(1, -64, 0, 48), Position = UDim2.fromOffset(54, 30), BackgroundTransparency = 1,
				Text = V.Tr(msg[1], msg[2]), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.new(0, 0, 0),
				TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = pop,
			})
			table.insert(c.list, pop)
			local function kill(spawnMore)
				for i, p in ipairs(c.list) do
					if p == pop then table.remove(c.list, i) break end
				end
				pcall(function() pop:Destroy() end)
				V.Beep(V.Rf(0.8, 1.4), 0.12)
				if spawnMore and c.spawn then
					local r = V.R:NextNumber()
					local n = (r < 0.55) and 2 or ((r < 0.8) and 1 or 0)
					for _ = 1, n do
						if #c.list < (c.cap or 8) then c.spawn() end
					end
				end
			end
			V.Connect(close.Activated, function() kill(true) end)
			-- two bottom buttons
			for i = 1, 2 do
				local idx = V.Ri(1, #BTN_JA)
				local b = V.New("TextButton", {
					Size = UDim2.fromOffset(84, 24), Position = UDim2.new(0.5, i == 1 and -92 or 8, 1, -32), BackgroundColor3 = Color3.fromRGB(192, 192, 192),
					Text = V.Tr(BTN_JA[idx], BTN_EN[idx]), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.new(0, 0, 0),
					AutoButtonColor = false, Parent = pop,
				})
				V.New("UIStroke", {Thickness = 1.5, Color = Color3.new(0, 0, 0), Parent = b})
				V.Connect(b.Activated, function() kill(true) end)
			end
			V.Draggable(bar, pop, nil, function()
				c.z = c.z + 1
				pop.ZIndex = c.z
			end)
			V.Beep(V.Rf(0.7, 1.2), 0.15)
		end
	end
end

-- ---------------- 10. fake BSOD ----------------
do
	V.BSODOn = false
	function V.ShowBSOD(dur)
		if V.BSODOn then return end
		V.BSODOn = true
		local layer = V.Layer("BSOD", 20)
		local cover = V.New("TextButton", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 80, 170), BorderSizePixel = 0, Text = "",
			AutoButtonColor = false, ZIndex = 20, Parent = layer,
		})
		V.New("TextLabel", {
			Size = UDim2.new(0, 120, 0, 90), Position = UDim2.new(0.08, 0, 0.1, 0), BackgroundTransparency = 1, Text = ":(",
			Font = Enum.Font.Code, TextSize = 80, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = cover,
		})
		local body = V.New("TextLabel", {
			Size = UDim2.new(0.84, 0, 0, 90), Position = UDim2.new(0.08, 0, 0.1, 100), BackgroundTransparency = 1,
			Text = V.Tr("お使いのPCで問題が発生したため、再起動する必要があります。\nエラー情報を収集しています。(ジョークです)", "Your PC ran into a problem and needs to restart.\nWe are just collecting some error info. (joke)"),
			Font = Enum.Font.Code, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 21, Parent = cover,
		})
		local prog = V.New("TextLabel", {
			Size = UDim2.new(0.84, 0, 0, 24), Position = UDim2.new(0.08, 0, 0.1, 200), BackgroundTransparency = 1, Text = "0% complete",
			Font = Enum.Font.Code, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = cover,
		})
		V.New("TextLabel", {
			Size = UDim2.new(0.84, 0, 0, 40), Position = UDim2.new(0.08, 0, 1, -60), BackgroundTransparency = 1,
			Text = V.Tr("停止コード: NYAN_CAT_JOKE_EXCEPTION\n(タップで閉じる)", "Stop code: NYAN_CAT_JOKE_EXCEPTION\n(tap to dismiss)"),
			Font = Enum.Font.Code, TextSize = 13, TextColor3 = Color3.fromRGB(200, 220, 255), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = cover,
		})
		local alive = true
		V.Connect(cover.Activated, function() alive = false end)
		V.Beep(0.5, 0.3)
		task.spawn(function()
			local t0 = tick()
			while alive and layer.Parent do
				local p = math.min(100, math.floor((tick() - t0) / dur * 100))
				prog.Text = p .. "% complete"
				if p >= 100 then break end
				task.wait(0.1)
			end
			V.DropLayer("BSOD")
			V.BSODOn = false
		end)
	end

	V.Define("bsod", "偽ブルースクリーン", "Fake blue screen", 0.5, {
		Start = function(c) c.nextAt = 5 end,
		Step = function(c, dt, t, k)
			c.nextAt = c.nextAt - dt
			if c.nextAt <= 0 and not V.BSODOn then
				V.ShowBSOD(6)
				c.nextAt = V.Rf(16, 30) / (0.4 + k)
			end
		end,
		Stop = function(c)
			V.DropLayer("BSOD")
			V.BSODOn = false
		end,
	})
end

-- ---------------- 11. code rain ----------------
do
	local CHARS = {}
	for ch in string.gmatch("0123456789ABCDEF01アイウエオカキクケコサシスセソタチツテトナニヌネノ", utf8.charpattern) do
		table.insert(CHARS, ch)
	end
	V.Define("rain", "コードレイン", "Code rain", 0.6, {
		Start = function(c)
			local q = V.Cfg.Quality
			c.n = math.max(10, math.floor(24 * q))
			c.lines = 18
			c.layer = V.Layer("Rain", 3)
			c.cols = {}
			local vp = V.Cam().ViewportSize
			c.vh = vp.Y
			for i = 0, c.n - 1 do
				local lbl = V.New("TextLabel", {
					Size = UDim2.new(1 / c.n, 0, 0, c.lines * 15), Position = UDim2.new(i / c.n, 0, 0, -c.lines * 15), BackgroundTransparency = 1,
					Text = "", Font = Enum.Font.Code, TextSize = 14, TextColor3 = Color3.fromRGB(0, 255, 80), TextTransparency = 0.2, Parent = c.layer,
				})
				V.New("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0)}),
					Parent = lbl,
				})
				table.insert(c.cols, {f = lbl, y = -V.Rf(0, c.vh), sp = V.Rf(120, 360), acc = 0})
			end
		end,
		Step = function(c, dt, t, k)
			for i, col in ipairs(c.cols) do
				local active = (i / c.n) < (k + 0.2)
				col.f.Visible = active
				if active then
					col.y = col.y + col.sp * dt * (0.5 + k)
					if col.y > c.vh then
						col.y = -c.lines * 15 - V.Rf(0, 120)
						col.sp = V.Rf(120, 360)
					end
					col.f.Position = UDim2.new((i - 1) / c.n, 0, 0, col.y)
					col.acc = col.acc + dt
					if col.acc > 0.11 then
						col.acc = 0
						local parts = {}
						for r = 1, c.lines do parts[r] = CHARS[V.Ri(1, #CHARS)] end
						col.f.Text = table.concat(parts, "\n")
					end
					col.f.TextTransparency = 0.6 - 0.5 * k
				end
			end
		end,
		Stop = function(c) V.DropLayer("Rain") end,
	})
end

-- ---------------- 12. infection log ticker ----------------
do
	local TPL = {
		{"[ OK ] ", "hooking cat.dll @ 0x%X", Color3.fromRGB(80, 255, 140)},
		{"[FAIL] ", "firewall.sys refused (joke) 0x%X", Color3.fromRGB(255, 80, 90)},
		{"[WARN] ", "rainbow overflow at 0x%X", Color3.fromRGB(255, 210, 80)},
		{"[ OK ] ", "mounting /dev/toast0 sector %d", Color3.fromRGB(80, 255, 140)},
		{"[INFO] ", "injecting nyan payload... %d%%", Color3.fromRGB(120, 190, 255)},
		{"[FAIL] ", "homework.exe could not be deleted: it is too cute", Color3.fromRGB(255, 80, 90)},
		{"[ OK ] ", "pixels relocated: %d", Color3.fromRGB(80, 255, 140)},
		{"[WARN] ", "scanlines exceed legal limit by %d%%", Color3.fromRGB(255, 210, 80)},
		{"[INFO] ", "spawning cat thread #%d", Color3.fromRGB(120, 190, 255)},
		{"[FAIL] ", "sanity.dll not found (0x%X)", Color3.fromRGB(255, 80, 90)},
	}
	V.Define("ticker", "感染ログ(偽)", "Fake infection log", 0.6, {
		Start = function(c)
			c.layer = V.Layer("Ticker", 10)
			c.lbl = V.New("TextLabel", {
				Size = UDim2.new(0.62, 0, 0, 150), Position = UDim2.new(0, 8, 1, -158), BackgroundTransparency = 1, Text = "",
				Font = Enum.Font.Code, TextSize = 12, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom, TextColor3 = Color3.new(1, 1, 1), Parent = c.layer,
			})
			c.lines = {}
			c.acc = 0
		end,
		Step = function(c, dt, t, k)
			c.acc = c.acc + dt
			if c.acc < 0.45 / (0.3 + k * 1.6) then return end
			c.acc = 0
			local tp = V.Pick(TPL)
			local arg = (string.find(tp[2], "%%d") and V.Ri(1, 99999)) or V.Ri(4096, 65535)
			local line = string.format(tp[2], arg)
			local col = tp[3]
			local txt = string.format('<font color="rgb(%d,%d,%d)">%s%s</font>', math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255), tp[1], line)
			table.insert(c.lines, txt)
			if #c.lines > 9 then table.remove(c.lines, 1) end
			c.lbl.Text = table.concat(c.lines, "\n")
			c.lbl.TextTransparency = 0.4 - 0.4 * k
		end,
		Stop = function(c) V.DropLayer("Ticker") end,
	})
end

-- ---------------- 13. glitch banner ----------------
do
	local HEAD = {
		{"システム感染中...", "SYSTEM INFECTED..."}, {"ニャーーーン", "NYAAAAN"}, {"ジョークです", "JUST A JOKE"},
		{"画面が壊れました", "SCREEN BROKEN"}, {"ERROR 0xCAT", "ERROR 0xCAT"}, {"レインボー過多", "RAINBOW OVERLOAD"},
		{"応答なし", "NOT RESPONDING"}, {"ノイズ検出", "NOISE DETECTED"},
	}
	local COMB = {"\u{0300}", "\u{0301}", "\u{0302}", "\u{0303}", "\u{0308}", "\u{0336}", "\u{0337}", "\u{0338}"}
	function V.Zalgo(s, amount)
		local out = {}
		for ch in string.gmatch(s, utf8.charpattern) do
			table.insert(out, ch)
			if V.R:NextNumber() < amount then table.insert(out, V.Pick(COMB)) end
		end
		return table.concat(out)
	end
	V.Define("banner", "グリッチ見出し", "Glitch banner", 0.5, {
		Start = function(c)
			c.layer = V.Layer("Banner", 11)
			c.labels = {}
			local cols = {Color3.fromRGB(255, 0, 60), Color3.fromRGB(0, 255, 255), Color3.new(1, 1, 1)}
			for i = 1, 3 do
				local l = V.New("TextLabel", {
					Size = UDim2.new(1, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
					BackgroundTransparency = 1, Text = "", Font = Enum.Font.Code, TextSize = 38, TextColor3 = cols[i],
					TextTransparency = 1, ZIndex = 11 + i, Parent = c.layer,
				})
				table.insert(c.labels, l)
			end
			c.show = 0
			c.wait = 2
			c.base = V.Pick(HEAD)
		end,
		Step = function(c, dt, t, k)
			if c.show > 0 then
				c.show = c.show - dt
				local txt = V.Zalgo(V.Tr(c.base[1], c.base[2]), 0.25 * k)
				for i, l in ipairs(c.labels) do
					l.Text = txt
					local j = (V.R:NextNumber() - 0.5) * 18 * k
					l.Position = UDim2.new(0.5, (i == 1 and -6 or (i == 2 and 6 or 0)) * k + j, 0.4, (V.R:NextNumber() - 0.5) * 8 * k)
					l.TextTransparency = (i == 3) and 0.1 or 0.35
				end
				if c.show <= 0 then
					for _, l in ipairs(c.labels) do l.TextTransparency = 1 end
					c.wait = V.Rf(2, 6) / (0.4 + k)
				end
			else
				c.wait = c.wait - dt
				if c.wait <= 0 then
					c.base = V.Pick(HEAD)
					c.show = V.Rf(0.8, 1.8)
					V.Beep(V.Rf(0.6, 1), 0.15)
				end
			end
		end,
		Stop = function(c) V.DropLayer("Banner") end,
	})
end

-- ---------------- 14. dead / stuck pixels ----------------
do
	V.Define("deadpx", "ドット欠け(固定ピクセル)", "Dead / stuck pixels", 0.5, {
		Start = function(c)
			c.layer = V.Layer("DeadPx", 9)
			c.px = {}
			local cols = {Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255), Color3.new(1, 1, 1), Color3.new(0, 0, 0)}
			for _ = 1, 48 do
				local s = V.Ri(3, 7)
				local f = V.New("Frame", {
					Size = UDim2.fromOffset(s, s), Position = UDim2.fromScale(V.R:NextNumber(), V.R:NextNumber()),
					BackgroundColor3 = V.Pick(cols), BorderSizePixel = 0, Visible = false, Parent = c.layer,
				})
				table.insert(c.px, f)
			end
		end,
		Step = function(c, dt, t, k)
			local count = math.floor(8 + 40 * k)
			c.off = c.off or {}
			for i, f in ipairs(c.px) do
				if i <= count then
					local o = c.off[i] or 0
					if o > 0 then
						c.off[i] = o - dt
						f.Visible = false
					else
						f.Visible = true
						if V.R:NextNumber() < 0.01 then c.off[i] = V.Rf(0.05, 0.5) end
					end
				else
					f.Visible = false
				end
			end
		end,
		Stop = function(c) V.DropLayer("DeadPx") end,
	})
end

-- ---------------- 15. touch trail ----------------
do
	V.Define("trail", "タッチ虹トレイル", "Touch rainbow trail", 0.7, {
		Start = function(c)
			c.layer = V.Layer("Trail", 8)
			c.alive = 0
			c.k = 0.5
			local function spawn(pos)
				if c.alive > 70 then return end
				local ins = Inset()
				c.alive = c.alive + 1
				local s = V.Ri(10, 26)
				local f = V.New("Frame", {
					Size = UDim2.fromOffset(s, s), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y + ins.Y),
					BackgroundColor3 = Color3.fromHSV((tick() * 0.6) % 1, 0.9, 1), BorderSizePixel = 0, Rotation = V.Ri(0, 90), Parent = c.layer,
				})
				V.T(f, 0.7, {BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2), Rotation = V.Ri(90, 270)})
				task.delay(0.72, function()
					c.alive = c.alive - 1
					pcall(function() f:Destroy() end)
				end)
			end
			c.c1 = UserInputService.TouchStarted:Connect(function(t) spawn(t.Position) end)
			c.c2 = UserInputService.TouchMoved:Connect(function(t)
				spawn(t.Position)
				if c.k > 0.6 then spawn(t.Position + Vector3.new(V.Ri(-14, 14), V.Ri(-14, 14), 0)) end
			end)
		end,
		Step = function(c, dt, t, k) c.k = k end,
		Stop = function(c)
			if c.c1 then c.c1:Disconnect() end
			if c.c2 then c.c2:Disconnect() end
			V.DropLayer("Trail")
		end,
	})
end

-- ======================================================================
-- EFFECT 16 - RAINBOW PIXEL CAT (original pixel art drawn from Frames)
-- ======================================================================
do
	local K = Color3.new(0, 0, 0)
	local TOAST = Color3.fromRGB(238, 198, 132)
	local ICING = Color3.fromRGB(255, 150, 200)
	local SPRK = Color3.fromRGB(255, 70, 150)
	local GRAY = Color3.fromRGB(158, 158, 158)
	local CHEEK = Color3.fromRGB(255, 170, 170)
	local BANDS = {
		Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 153, 0), Color3.fromRGB(255, 255, 0),
		Color3.fromRGB(51, 255, 0), Color3.fromRGB(0, 153, 255), Color3.fromRGB(102, 51, 255),
	}
	local SEGS = 12

	local function R(parent, x, y, w, h, col, u)
		return V.New("Frame", {
			Size = UDim2.fromOffset(w * u, h * u), Position = UDim2.fromOffset(x * u, y * u),
			BackgroundColor3 = col, BorderSizePixel = 0, Parent = parent,
		})
	end

	local function BuildCat(layer, u)
		local root = V.New("Frame", {Size = UDim2.fromOffset(26 * u, 16 * u), BackgroundTransparency = 1, ZIndex = 7, Parent = layer})
		-- rainbow trail (children of the root, to the left of the cat, wavy)
		local trail = {}
		for i = 1, SEGS do
			local seg = {}
			for b = 1, 6 do
				local f = R(root, 3 - i * 2, 3 + (b - 1) * 1.6, 2.2, 1.7, BANDS[b], u)
				table.insert(seg, f)
			end
			table.insert(trail, seg)
		end
		-- toast body
		R(root, 3, 2, 15, 12, K, u)
		R(root, 4, 3, 13, 10, TOAST, u)
		R(root, 5, 4, 11, 8, ICING, u)
		for _, p in ipairs({{6, 5}, {9, 6}, {12, 5}, {7, 9}, {10, 10}, {13, 8}, {14, 10}, {8, 7}}) do
			R(root, p[1], p[2], 1, 1, SPRK, u)
		end
		-- head, ears
		R(root, 16, 4, 10, 9, K, u)
		R(root, 17, 5, 8, 7, GRAY, u)
		R(root, 16, 2, 3, 3, K, u)
		R(root, 23, 2, 3, 3, K, u)
		R(root, 17, 3, 1, 2, ICING, u)
		R(root, 24, 3, 1, 2, ICING, u)
		-- face
		R(root, 18, 7, 1, 2, K, u)
		R(root, 22, 7, 1, 2, K, u)
		R(root, 17, 9, 1, 1, CHEEK, u)
		R(root, 24, 9, 1, 1, CHEEK, u)
		R(root, 19, 10, 3, 1, K, u)
		R(root, 20, 9, 1, 1, K, u)
		-- tail
		local tail = R(root, 0, 6, 4, 3, K, u)
		R(root, 1, 7, 2, 1, GRAY, u)
		-- legs
		local legs = {}
		for _, x in ipairs({4, 8, 12, 16}) do
			local o = R(root, x, 14, 3, 2, K, u)
			local inner = V.New("Frame", {Size = UDim2.new(1, -4, 1, -3), Position = UDim2.fromOffset(2, 1), BackgroundColor3 = GRAY, BorderSizePixel = 0, Parent = o})
			table.insert(legs, o)
		end
		return {root = root, trail = trail, legs = legs, tail = tail, u = u, x = 0, y = 0, sp = 200, flip = 0, bob = V.Rf(0, 6)}
	end

	V.Define("cat", "レインボーキャット", "Rainbow cat", 0.8, {
		Start = function(c)
			local vp = V.Cam().ViewportSize
			c.vp = vp
			c.u = math.clamp(math.floor(vp.Y / 30), 7, 16)
			c.layer = V.Layer("Cat", 7)
			c.cats = {}
			for i = 1, 3 do
				local cat = BuildCat(c.layer, c.u)
				cat.x = -(60 * c.u) - (i - 1) * (vp.X * 0.45)
				cat.y = V.Rf(0.1, 0.72) * vp.Y
				cat.sp = V.Rf(170, 260)
				table.insert(c.cats, cat)
			end
			c.stars = {}
			for _ = 1, 18 do
				local s = V.Ri(2, 5)
				local f = V.New("Frame", {
					Size = UDim2.fromOffset(s, s), Position = UDim2.fromOffset(V.R:NextNumber() * vp.X, V.R:NextNumber() * vp.Y),
					BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6, Parent = c.layer,
				})
				table.insert(c.stars, {f = f, x = f.Position.X.Offset, y = f.Position.Y.Offset, sp = V.Rf(80, 240), ph = V.Rf(0, 6)})
			end
			c.legT = 0
			c.legFlip = false
		end,
		Step = function(c, dt, t, k)
			local vp = c.vp
			local n = 1 + math.floor(k * 2.2)
			c.legT = c.legT + dt
			if c.legT > 0.12 then
				c.legT = 0
				c.legFlip = not c.legFlip
			end
			for i, cat in ipairs(c.cats) do
				cat.root.Visible = i <= n
				if i <= n then
					cat.x = cat.x + cat.sp * dt * (0.7 + 0.9 * k)
					if cat.x > vp.X + 4 * c.u then
						cat.x = -(26 + SEGS * 2) * c.u
						cat.y = V.Rf(0.08, 0.7) * vp.Y
						cat.sp = V.Rf(170, 260)
					end
					local bob = math.sin(t * 9 + cat.bob) * c.u * 0.5
					cat.root.Position = UDim2.fromOffset(cat.x, cat.y + bob)
					for si, seg in ipairs(cat.trail) do
						local off = math.sin(t * 11 - si * 0.7 + cat.bob) * c.u * 0.7
						for b, f in ipairs(seg) do
							f.Position = UDim2.fromOffset(f.Position.X.Offset, (3 + (b - 1) * 1.6) * c.u + off)
						end
					end
					for li, leg in ipairs(cat.legs) do
						local up = ((li % 2 == 0) == c.legFlip) and 0 or -c.u * 0.5
						leg.Position = UDim2.fromOffset(leg.Position.X.Offset, 14 * c.u + up)
					end
					cat.tail.Position = UDim2.fromOffset(cat.tail.Position.X.Offset, 6 * c.u + (c.legFlip and 0 or c.u * 0.5))
				end
			end
			for _, s in ipairs(c.stars) do
				s.x = s.x - s.sp * dt
				if s.x < -6 then
					s.x = vp.X + 6
					s.y = V.R:NextNumber() * vp.Y
				end
				s.f.Position = UDim2.fromOffset(s.x, s.y)
				s.f.BackgroundTransparency = 0.2 + 0.7 * (0.5 + 0.5 * math.sin(t * 8 + s.ph)) * (1 - k * 0.6)
			end
		end,
		Stop = function(c) V.DropLayer("Cat") end,
	})
end

-- ======================================================================
-- SCENARIOS (scripted timelines)
-- ======================================================================
do
	local function L(id, lv)
		return function()
			V.SetLevel(id, lv)
			V.SetSel(id, true)
		end
	end
	local function Off(id)
		return function() V.SetSel(id, false) end
	end
	local function Multi(...)
		local fns = {...}
		return function() for _, f in ipairs(fns) do f() end end
	end

	V.AddScenario("nyan", "ニャン・ジョーク (60秒)", "Nyan Joke (60s)", 60, {
		{t = 0, fn = L("ticker", 0.5), label = {"起動シーケンス", "Boot sequence"}},
		{t = 3, fn = L("static", 0.3), label = {"信号が乱れ始めた", "Signal degrading"}},
		{t = 6, fn = L("scan", 0.5)},
		{t = 10, fn = Multi(L("bars", 0.6), L("deadpx", 0.4)), label = {"ティアリング発生", "Tearing detected"}},
		{t = 14, fn = Multi(L("cat", 0.8), L("banner", 0.5)), label = {"ニャンキャット出現!", "Nyan cat spotted!"}},
		{t = 20, fn = L("flip", 0.6), label = {"色が反転し始めた", "Colours flipping"}},
		{t = 26, fn = L("trail", 0.8), label = {"指先が虹になった", "Your finger is a rainbow"}},
		{t = 30, fn = L("popups", 0.45), label = {"ポップアップ増殖", "Popups multiplying"}},
		{t = 38, fn = Multi(L("melt", 0.55), L("warp", 0.4)), label = {"画面が溶ける", "Screen melting"}},
		{t = 46, fn = L("bsod", 0.5), label = {"ブルースクリーン接近", "BSOD incoming"}},
		{t = 52, fn = Multi(L("rain", 0.6), Off("popups")), label = {"コードレイン", "Code rain"}},
		{t = 56, fn = L("dark", 0.7), label = {"暗転", "Blackout"}},
	})

	V.AddScenario("static", "ノイズストーム (45秒)", "Static Storm (45s)", 45, {
		{t = 0, fn = L("static", 0.25), label = {"微弱なノイズ", "Faint static"}},
		{t = 5, fn = L("scan", 0.5)},
		{t = 10, fn = L("static", 0.55), label = {"ノイズ増加", "Static rising"}},
		{t = 14, fn = Multi(L("bars", 0.7), L("deadpx", 0.6))},
		{t = 20, fn = Multi(L("static", 0.85), L("blur", 0.4)), label = {"ノイズの嵐", "Storm"}},
		{t = 26, fn = L("flip", 0.5)},
		{t = 32, fn = Multi(L("static", 1.0), L("warp", 0.35)), label = {"信号ロスト", "Signal lost"}},
		{t = 40, fn = L("dark", 0.6)},
	})

	V.AddScenario("blackout", "ブラックアウト (40秒)", "Blackout Flicker (40s)", 40, {
		{t = 0, fn = L("dark", 0.3), label = {"電圧低下", "Voltage drop"}},
		{t = 6, fn = Multi(L("dark", 0.55), L("scan", 0.4))},
		{t = 12, fn = L("bars", 0.5), label = {"ブラウンアウト", "Brown-outs"}},
		{t = 18, fn = Multi(L("dark", 0.8), L("ticker", 0.6), L("deadpx", 0.5))},
		{t = 24, fn = L("banner", 0.5), label = {"警告", "Warning"}},
		{t = 30, fn = Multi(L("warp", 0.3), L("dark", 0.9)), label = {"完全暗転へ", "Going dark"}},
	})

	V.AddScenario("hack", "コードレイン・ハック (50秒)", "Code Rain Hack (50s)", 50, {
		{t = 0, fn = L("ticker", 0.7), label = {"侵入開始", "Intrusion started"}},
		{t = 4, fn = L("rain", 0.4)},
		{t = 10, fn = Multi(L("rain", 0.7), L("scan", 0.4)), label = {"データ流出(ウソ)", "Data exfiltration (fake)"}},
		{t = 18, fn = Multi(L("banner", 0.6), L("bars", 0.4))},
		{t = 26, fn = L("flip", 0.35), label = {"色相シフト", "Hue shift"}},
		{t = 34, fn = Multi(L("rain", 1.0), L("static", 0.3)), label = {"全システム掌握", "Total takeover"}},
		{t = 42, fn = L("bsod", 0.6), label = {"…と思ったらジョーク", "...just kidding"}},
	})

	V.AddScenario("popup", "ポップアップ増殖 (45秒)", "Popup Flood (45s)", 45, {
		{t = 0, fn = L("popups", 0.3), label = {"最初のエラー", "First error"}},
		{t = 8, fn = L("popups", 0.55), label = {"閉じるほど増える", "Closing makes more"}},
		{t = 16, fn = Multi(L("popups", 0.8), L("banner", 0.4))},
		{t = 24, fn = Multi(L("popups", 1.0), L("ticker", 0.6), L("scan", 0.3)), label = {"もう手遅れ", "Too late"}},
		{t = 34, fn = L("bsod", 0.5)},
	})

	V.AddScenario("chaos", "フルカオス (90秒)", "Full Chaos (90s)", 90, {
		{t = 0, fn = Multi(L("ticker", 0.5), L("static", 0.3)), label = {"ようこそ", "Welcome"}},
		{t = 6, fn = Multi(L("scan", 0.5), L("bars", 0.5))},
		{t = 12, fn = Multi(L("cat", 0.7), L("trail", 0.8), L("banner", 0.5)), label = {"ニャン", "Nyan"}},
		{t = 20, fn = Multi(L("flip", 0.6), L("deadpx", 0.5), L("blur", 0.3))},
		{t = 28, fn = Multi(L("popups", 0.5), L("rain", 0.5)), label = {"カオス開始", "Chaos begins"}},
		{t = 38, fn = Multi(L("melt", 0.6), L("warp", 0.4), L("static", 0.6))},
		{t = 48, fn = L("bsod", 0.6), label = {"BSOD", "BSOD"}},
		{t = 56, fn = Multi(L("cat", 1.0), L("static", 0.8), L("bars", 0.8), L("flip", 0.8)), label = {"最大出力", "Max output"}},
		{t = 68, fn = Multi(L("popups", 0.9), L("melt", 0.9), L("dark", 0.6), L("rain", 0.8)), label = {"限界突破", "Beyond limits"}},
		{t = 80, fn = Multi(Off("popups"), Off("rain"), L("dark", 0.85)), label = {"シャットダウン", "Shutting down"}},
	})
end

-- ======================================================================
-- CONTROL UI (mobile / touch)  -  always above the effects
-- ======================================================================
do
	local New, T, Tr = V.New, V.T, V.Tr
	local WHITE = Color3.new(1, 1, 1)
	local function RGB(r, g, b) return Color3.fromRGB(r, g, b) end
	local PAL = ColorSequence.new({
		ColorSequenceKeypoint.new(0, RGB(255, 50, 80)), ColorSequenceKeypoint.new(0.5, RGB(60, 255, 140)),
		ColorSequenceKeypoint.new(1, RGB(255, 50, 80)),
	})
	local Grads, LangB = {}, {}

	local function Txt(inst, ja, en, prop)
		prop = prop or "Text"
		table.insert(LangB, {i = inst, ja = ja, en = en, p = prop})
		inst[prop] = (V.Cfg.Lang == "ja") and ja or en
	end
	local function RefreshLang()
		for idx = #LangB, 1, -1 do
			local e = LangB[idx]
			if e.i.Parent then e.i[e.p] = (V.Cfg.Lang == "ja") and e.ja or e.en else table.remove(LangB, idx) end
		end
	end
	local function Grad(parent, rot)
		local g = New("UIGradient", {Color = PAL, Rotation = rot or V.Ri(0, 359), Parent = parent})
		table.insert(Grads, g)
		return g
	end
	local function Stroke(p, th, col)
		return New("UIStroke", {Thickness = th, Color = col or RGB(60, 255, 140), Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p})
	end

	-- ---------------- root window ----------------
	local vp = V.Cam().ViewportSize
	local base = math.clamp(math.min(vp.X / 540, vp.Y / 340), 0.6, 1)
	local Holder = New("Frame", {Size = UDim2.fromOffset(500, 310), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundTransparency = 1, Visible = false, Parent = V.CGui})
	local Window = New("Frame", {Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = RGB(8, 10, 16), BackgroundTransparency = 0.04, ClipsDescendants = true, Parent = Holder})
	V.Corner(Window, 14)
	local WS = New("UIScale", {Scale = 0.01, Parent = Window})
	Stroke(Window, 2)
	local top = New("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = RGB(14, 18, 28), BorderSizePixel = 0, Parent = Window})
	local title = New("TextLabel", {Size = UDim2.new(0, 260, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1, Text = "NYAN.EXE  //  joke screen wrecker", Font = Enum.Font.Code, TextSize = 15, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Parent = top})
	Grad(title, 0)
	local minB = New("TextButton", {Size = UDim2.fromOffset(30, 26), Position = UDim2.new(1, -40, 0.5, -13), BackgroundColor3 = RGB(26, 32, 48), Text = "-", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = WHITE, AutoButtonColor = false, Parent = top})
	V.Corner(minB, 8)
	V.Draggable(top, Holder, nil)

	-- ---------------- pill + STOP ----------------
	local pill = New("TextButton", {Size = UDim2.fromOffset(86, 30), Position = UDim2.fromOffset(14, 62), BackgroundColor3 = RGB(6, 6, 10), Text = "NYAN", Font = Enum.Font.Code, TextSize = 14, TextColor3 = RGB(60, 255, 140), AutoButtonColor = false, ZIndex = 50, Parent = V.CGui})
	V.Corner(pill, 8)
	Stroke(pill, 1.6)
	local stop = New("TextButton", {Size = UDim2.fromOffset(132, 36), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), BackgroundColor3 = RGB(200, 20, 40), Text = "", AutoButtonColor = false, ZIndex = 60, Parent = V.CGui})
	V.Corner(stop, 10)
	Stroke(stop, 2, WHITE)
	local stopLbl = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = WHITE, ZIndex = 61, Parent = stop})
	Txt(stopLbl, "■ 停止 / STOP", "■ STOP")
	V.Connect(stop.Activated, function()
		V.Panic()
		Notify("NyanVirus", "Stopped", 2)
	end)

	local open, busy = false, false
	local function SetOpen(state)
		if busy or open == state then return end
		busy, open = true, state
		if state then
			Holder.Visible = true
			WS.Scale = 0.01
			T(WS, 0.4, {Scale = base}, Enum.EasingStyle.Back)
			task.delay(0.4, function() busy = false end)
		else
			T(WS, 0.25, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.28, function() Holder.Visible = false busy = false end)
		end
	end
	V.Draggable(pill, pill, function() SetOpen(not open) end)
	V.Connect(minB.Activated, function() SetOpen(false) end)

	-- ---------------- pages ----------------
	local side = New("Frame", {Size = UDim2.new(0, 92, 1, -46), Position = UDim2.fromOffset(6, 42), BackgroundTransparency = 1, Parent = Window})
	New("UIListLayout", {Padding = UDim.new(0, 4), Parent = side})
	local content = New("Frame", {Size = UDim2.new(1, -108, 1, -50), Position = UDim2.fromOffset(102, 44), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Window})
	local pages, tabs, cur = {}, {}, nil
	local function Select(id)
		if cur == id then return end
		cur = id
		for n, pg in pairs(pages) do
			local a = (n == id)
			tabs[n].g.Enabled = a
			T(tabs[n].b, 0.2, {BackgroundColor3 = a and WHITE or RGB(22, 28, 42)})
			pg.Visible = a
		end
	end
	local function Order(pg)
		local n = (pg:GetAttribute("n") or 0) + 1
		pg:SetAttribute("n", n)
		return n
	end
	local function Tab(id, ja, en)
		local b = New("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = RGB(22, 28, 42), Text = "", AutoButtonColor = false, Parent = side})
		V.Corner(b, 8)
		local g = Grad(b)
		g.Enabled = false
		local l = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE, ZIndex = 2, Parent = b})
		Txt(l, ja, en)
		local pg = New("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = content})
		New("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pg})
		New("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), Parent = pg})
		pages[id], tabs[id] = pg, {b = b, g = g}
		V.Connect(b.Activated, function() Select(id) end)
		return pg
	end

	-- ---------------- components ----------------
	local function Section(pg, ja, en)
		local l = New("TextLabel", {Size = UDim2.new(1, -4, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = Order(pg), Parent = pg})
		Txt(l, ja, en)
		Grad(l, 0)
	end
	local function Info(pg, ja, en, h)
		local f = New("Frame", {Size = UDim2.new(1, -4, 0, h or 28), BackgroundColor3 = RGB(18, 22, 34), LayoutOrder = Order(pg), Parent = pg})
		V.Corner(f, 8)
		local l = New("TextLabel", {Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = RGB(215, 225, 245), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
		if ja then Txt(l, ja, en) end
		return l
	end
	local function Btn(pg, ja, en, cb, col)
		local b = New("TextButton", {Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = col or WHITE, Text = "", AutoButtonColor = false, LayoutOrder = Order(pg), Parent = pg})
		V.Corner(b, 9)
		if not col then Grad(b) end
		Stroke(b, 1.2)
		local l = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, ZIndex = 2, Parent = b})
		Txt(l, ja, en)
		V.Connect(b.Activated, function() cb(l) end)
		return b, l
	end
	local function Sw(pg, ja, en, def, cb)
		local h = New("TextButton", {Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = RGB(18, 22, 34), Text = "", AutoButtonColor = false, LayoutOrder = Order(pg), Parent = pg})
		V.Corner(h, 9)
		local l = New("TextLabel", {Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = RGB(228, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = h})
		Txt(l, ja, en)
		local tr = New("Frame", {Size = UDim2.fromOffset(42, 20), Position = UDim2.new(1, -52, 0.5, -10), BackgroundColor3 = RGB(46, 52, 74), Parent = h})
		V.Corner(tr, 10)
		local g = Grad(tr)
		local kn = New("Frame", {Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = WHITE, Parent = tr})
		V.Corner(kn, 8)
		local st = def and true or false
		local function render()
			g.Enabled = st
			tr.BackgroundColor3 = st and WHITE or RGB(46, 52, 74)
			kn.Position = st and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2)
		end
		render()
		V.Connect(h.Activated, function()
			st = not st
			render()
			cb(st)
		end)
		return {Set = function(v) st = v and true or false render() end}
	end
	local function Sl(pg, ja, en, mn, mx, def, dec, cb)
		local h = New("Frame", {Size = UDim2.new(1, -4, 0, 46), BackgroundColor3 = RGB(18, 22, 34), LayoutOrder = Order(pg), Parent = pg})
		V.Corner(h, 9)
		local l = New("TextLabel", {Size = UDim2.new(1, -80, 0, 20), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = RGB(228, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = h})
		Txt(l, ja, en)
		local val = New("TextLabel", {Size = UDim2.fromOffset(64, 20), Position = UDim2.new(1, -72, 0, 4), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 12, TextColor3 = RGB(60, 255, 140), TextXAlignment = Enum.TextXAlignment.Right, Parent = h})
		local bar = New("Frame", {Size = UDim2.new(1, -20, 0, 8), Position = UDim2.new(0, 10, 0, 31), BackgroundColor3 = RGB(36, 42, 64), Parent = h})
		V.Corner(bar, 4)
		local fill = New("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = bar})
		V.Corner(fill, 4)
		Grad(fill)
		local kn = New("Frame", {Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = WHITE, ZIndex = 3, Parent = bar})
		V.Corner(kn, 7)
		local function set(v, silent)
			local m = 10 ^ dec
			v = math.clamp(math.floor(v * m + 0.5) / m, mn, mx)
			local a = (v - mn) / (mx - mn)
			fill.Size = UDim2.fromScale(a, 1)
			kn.Position = UDim2.fromScale(a, 0.5)
			val.Text = tostring(v)
			if not silent then cb(v) end
		end
		set(def, true)
		local function fromX(x) set(mn + (mx - mn) * math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1), false) end
		V.Connect(h.InputBegan, function(i)
			if i.UserInputType ~= Enum.UserInputType.Touch then return end
			pg.ScrollingEnabled = false
			fromX(i.Position.X)
			V.DragH = function(pos) fromX(pos.X) end
			V.DragE = function()
				V.DragH, V.DragE = nil, nil
				pg.ScrollingEnabled = true
			end
		end)
		return {Set = set}
	end
	local function Chips(pg, opts, def, cb)
		local row = New("Frame", {Size = UDim2.new(1, -4, 0, 30), BackgroundTransparency = 1, LayoutOrder = Order(pg), Parent = pg})
		New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = row})
		local n, chips = #opts, {}
		local function sel(id)
			for _, c in ipairs(chips) do
				c.g.Enabled = (c.id == id)
				c.b.BackgroundColor3 = (c.id == id) and WHITE or RGB(22, 28, 42)
			end
		end
		for _, o in ipairs(opts) do
			local b = New("TextButton", {Size = UDim2.new(1 / n, -(4 * (n - 1)) / n, 1, 0), BackgroundColor3 = RGB(22, 28, 42), Text = "", AutoButtonColor = false, Parent = row})
			V.Corner(b, 9)
			local g = Grad(b)
			local l = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = WHITE, ZIndex = 2, Parent = b})
			Txt(l, o.ja, o.en)
			table.insert(chips, {b = b, g = g, id = o.id})
			V.Connect(b.Activated, function() sel(o.id) cb(o.id) end)
		end
		sel(def)
	end

	-- ---------------- warning modal ----------------
	local modal = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 80, Active = true, Parent = V.CGui})
	local box = New("Frame", {Size = UDim2.fromOffset(340, 190), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = RGB(12, 14, 22), ZIndex = 81, Parent = modal})
	V.Corner(box, 14)
	Stroke(box, 2, RGB(255, 200, 60))
	local mt = New("TextLabel", {Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 10), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = RGB(255, 200, 60), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 82, Parent = box})
	Txt(mt, "警告: 光の点滅・画面の揺れ", "WARNING: flashing lights / screen shake")
	local mb = New("TextLabel", {Size = UDim2.new(1, -24, 0, 90), Position = UDim2.fromOffset(12, 38), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 82, Parent = box})
	Txt(mb, "これはあなたの画面だけに出るジョークです。点滅・ノイズ・カメラの揺れを含みます。光に敏感な方や酔いやすい方は使わないでください。上の「停止」でいつでも止まります。安全モードは初期でONです。", "This is a joke that only shows on YOUR screen. It contains flashing, noise and camera shake. Do not use it if you are sensitive to light or motion. The STOP button at the top always works. Safe mode is ON by default.")
	local pendingCb = nil
	local function WBtn(ja, en, x, col, fn)
		local b = New("TextButton", {Size = UDim2.fromOffset(150, 34), Position = UDim2.new(0, x, 1, -46), BackgroundColor3 = col, Text = "", AutoButtonColor = false, ZIndex = 82, Parent = box})
		V.Corner(b, 9)
		local l = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, ZIndex = 83, Parent = b})
		Txt(l, ja, en)
		V.Connect(b.Activated, fn)
	end
	WBtn("続ける", "Continue", 12, RGB(30, 160, 90), function()
		modal.Visible = false
		V.Acked = true
		local cb = pendingCb
		pendingCb = nil
		if cb then cb() end
	end)
	WBtn("やめる", "Cancel", 178, RGB(120, 40, 50), function()
		modal.Visible = false
		pendingCb = nil
	end)
	local function Guarded(fn)
		if V.Acked then fn() else pendingCb = fn modal.Visible = true end
	end

	-- ---------------- CONTROL page ----------------
	local pCtl = Tab("ctl", "操作", "Control")
	local statusL = Info(pCtl, nil, nil, 44)
	statusL.TextSize = 12
	local startBtn, startLbl
	startBtn, startLbl = Btn(pCtl, "▶ 感染スタート", "▶ START INFECTION", function()
		if V.Running then
			V.End(false)
		else
			Guarded(function()
				V.Scn = nil
				local any = false
				for _, id in ipairs(V.Order) do if V.FX[id].sel then any = true end end
				if not any then
					for _, id in ipairs({"static", "scan", "bars", "flip", "cat"}) do V.FX[id].sel = true end
					V.UI.Refresh()
				end
				V.Begin()
			end)
		end
	end)
	Section(pCtl, "強さ / 時間", "Intensity / time")
	Sl(pCtl, "全体の強さ (%)", "Master intensity (%)", 5, 100, 70, 0, function(v) V.Cfg.Master = v / 100 end)
	Sl(pCtl, "継続時間 (秒)", "Duration (s)", 10, 300, 60, 0, function(v)
		V.Cfg.Duration = v
		if V.Running and not V.Scn then V.EndAt = tick() + v end
	end)
	Sw(pCtl, "自動停止", "Auto stop", true, function(s) V.Cfg.AutoStop = s end)
	Sw(pCtl, "安全モード (点滅/揺れを抑える)", "Safe mode (limits flashes / shake)", true, function(s)
		V.Cfg.Safe = s
		if not s then Notify("NyanVirus", "Safe mode OFF - stronger flashing", 3) end
	end)
	Section(pCtl, "ワンショット", "One-shot")
	Btn(pCtl, "偽ブルースクリーン", "Fake blue screen", function() Guarded(function() V.ShowBSOD(6) end) end)
	Btn(pCtl, "白フラッシュ (1回)", "White flash (once)", function() Guarded(function() V.Flash(Color3.new(1, 1, 1), 0.3, 0.3) end) end)

	-- ---------------- EFFECTS page ----------------
	local pFx = Tab("fx", "エフェクト", "Effects")
	local rows = {}
	Section(pFx, "オン/オフと強さ", "Toggle + level")
	for _, id in ipairs(V.Order) do
		local fx = V.FX[id]
		local sw = Sw(pFx, fx.ja, fx.en, fx.sel, function(s) V.SetSel(id, s) end)
		local sl = Sl(pFx, "└ 強さ", "└ level", 0, 100, math.floor(fx.level * 100), 0, function(v) V.SetLevel(id, v / 100) end)
		rows[id] = {sw = sw, sl = sl}
	end
	V.UI.Refresh = function()
		for id, r in pairs(rows) do
			r.sw.Set(V.FX[id].sel)
			r.sl.Set(math.floor(V.FX[id].level * 100), true)
		end
	end

	-- ---------------- SCENARIO page ----------------
	local pSc = Tab("sc", "シナリオ", "Scenarios")
	Section(pSc, "台本どおりに荒らす", "Scripted timelines")
	for _, sc in ipairs(V.Scenarios) do
		Btn(pSc, "▶ " .. sc.ja, "▶ " .. sc.en, function() Guarded(function() V.RunScenario(sc) end) end)
	end
	Info(pSc, "シナリオ中はエフェクトが時間とともに自動で増えます。終わると元の設定に戻ります。", "Effects ramp up on a timeline. Your own selection is restored afterwards.", 52)

	-- ---------------- SETTINGS page ----------------
	local pSet = Tab("set", "設定", "Settings")
	Section(pSet, "品質", "Quality")
	Chips(pSet, {{id = 0.6, ja = "軽い", en = "Low"}, {id = 1, ja = "標準", en = "Mid"}, {id = 1.5, ja = "高", en = "High"}}, 1, function(id) V.Cfg.Quality = id end)
	Info(pSet, "品質は次にエフェクトを開始したときに反映されます。", "Quality applies the next time an effect starts.", 40)
	Section(pSet, "演出", "Show")
	Sw(pSet, "CRT起動アニメ", "CRT boot animation", true, function(s) V.Cfg.Boot = s end)
	Sw(pSet, "CRT終了アニメ", "CRT shutdown animation", true, function(s) V.Cfg.Shutdown = s end)
	Sw(pSet, "効果音 (ピッ)", "Beep sounds", false, function(s) V.Cfg.Sound = s end)
	Sl(pSet, "音量", "Volume", 0, 100, 25, 0, function(v) V.Cfg.Volume = v / 100 end)
	Section(pSet, "言語 / UI", "Language / UI")
	Chips(pSet, {{id = "ja", ja = "日本語", en = "日本語"}, {id = "en", ja = "English", en = "English"}}, "ja", function(id)
		V.Cfg.Lang = id
		RefreshLang()
	end)
	Sl(pSet, "UIサイズ", "UI scale", 0.5, 1.3, base, 2, function(v)
		base = v
		if open then WS.Scale = v end
	end)

	-- ---------------- ABOUT page ----------------
	local pAb = Tab("ab", "説明", "About")
	Section(pAb, "これは何?", "What is this?")
	Info(pAb, "ウイルス風のジョーク画面荒らしです。ノイズ・走査線・色反転・暗転・画面の溶解・偽BSOD・ポップアップ・虹ネコなどを画面上で再現します。", "A joke 'virus' that wrecks your own screen: static, scanlines, colour flips, blackouts, melt, fake BSOD, popups, a rainbow cat and more.", 74)
	Section(pAb, "安全について", "Safety")
	Info(pAb, "・効果はすべて自分の画面だけ(ほかの人には見えません)\n・サーバーへの通信やキャラの改変はしません\n・上の STOP は常に最前面で動きます", "- Everything is local to your own screen (nobody else sees it)\n- No server calls, no character changes\n- The STOP button is always on top and always works", 84)
	Info(pAb, "色の反転は『反転風』です。Robloxにはピクセル単位の真の反転がないため、色調補正で近づけています。", "'Colour flip' is invert-LIKE: Roblox has no true pixel negative, so it is approximated with colour correction.", 60)

	-- ---------------- state hooks / status ----------------
	local stageText = ""
	V.UI.Stage = function(label)
		if type(label) == "table" then stageText = Tr(label[1], label[2]) else stageText = tostring(label) end
	end
	V.UI.OnState = function(running)
		stageText = ""
		if startLbl then
			startLbl.Text = running and Tr("■ 停止して元に戻す", "■ STOP & RESTORE") or Tr("▶ 感染スタート", "▶ START INFECTION")
		end
	end
	local acc = 0
	V.Connect(game:GetService("RunService").Heartbeat, function(dt)
		for i = #Grads, 1, -1 do
			local g = Grads[i]
			if g.Parent then
				if g.Enabled then g.Rotation = (g.Rotation + dt * 40) % 360 end
			else
				table.remove(Grads, i)
			end
		end
		acc = acc + dt
		if acc < 0.25 then return end
		acc = 0
		local st = V.Running and Tr("感染中", "INFECTED") or Tr("待機中", "IDLE")
		local el = math.max(0, math.floor(V.RunT))
		statusL.Text = string.format("%s: %s   %s %ds / %ds   FPS %d\n%s %s", Tr("状態", "State"), st, Tr("経過", "t"), el, V.Cfg.Duration, V.Fps, Tr("ステージ:", "Stage:"), stageText)
	end)

	Select("ctl")
	SetOpen(true)
end

-- ======================================================================
-- PUBLIC HANDLE
-- ======================================================================
local function Unload()
	V.Dead = true
	pcall(V.Panic)
	for _, c in ipairs(V.Conns) do pcall(function() c:Disconnect() end) end
	V.Conns = {}
	pcall(function() V.Gui:Destroy() end)
	pcall(function() V.CGui:Destroy() end)
	getgenv().NyanVirus = nil
end

getgenv().NyanVirus = {Unload = Unload, Begin = V.Begin, End = V.End, Panic = V.Panic, V = V}
Notify("NyanVirus", "Loaded - tap the STOP button any time to stop", 4)
