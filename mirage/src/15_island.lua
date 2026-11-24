-- @module island
-- Mirage Island is the thing worth hopping for. The stock itself is the
-- same on every server, so hopping never changes what is for sale: it
-- only finds a server where the island, and therefore the dealer, exists.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local R      = _R("resolve")
local Notify = _R("notify")

local I = {}

I.lastCheck = 0
I.present = false
I.model = nil
I.tier = "unknown"
I.hopAttempts = 0
I.Hopper = nil          -- set by session so island can ask for a hop

local tpDone = false
local accum = 0

local ISLAND_HINTS = {"mirage", "illusion", "mystic"}

-- The dealer's own presence is the strongest signal the island is here,
-- so the model scan is a bonus rather than the test.
function I.ScanModel()
	local pinned = Cfg.List(Cfg.target.islandNames)
	local radius = math.max(Cfg.s.island.scanRadius, 100)
	local hrp = Svc.HRP()
	local origin = hrp and hrp.Position or Vector3.new(0, 0, 0)

	for _, d in ipairs(Svc.Workspace:GetChildren()) do
		local lower = string.lower(d.Name)
		local hit = false
		for _, h in ipairs(ISLAND_HINTS) do
			if string.find(lower, h, 1, true) then hit = true end
		end
		for _, pin in ipairs(pinned) do
			if string.find(lower, string.lower(pin), 1, true) then hit = true end
		end
		if hit then
			local pos = d:IsA("Model") and Svc.ModelPos(d) or (d:IsA("BasePart") and d.Position or nil)
			if pos and (pos - origin).Magnitude <= radius * 4 then
				return d, pos
			end
		end
	end
	return nil, nil
end

function I.Check(force)
	local now = Util.Now()
	if not force and (now - I.lastCheck) < 2 then return I.present end
	I.lastCheck = now

	local dealer = R.ScanDealer(force)
	local model, pos = I.ScanModel()

	I.model = model
	if dealer then
		I.present = true
		I.tier = "dealer found"
	elseif model then
		I.present = true
		I.tier = "island model found"
	else
		I.present = false
		I.tier = "nothing found"
		tpDone = false
	end
	return I.present
end

function I.Target()
	local dealerPos = R.DealerPos()
	if dealerPos then return dealerPos, "dealer" end
	local model, pos = I.ScanModel()
	if pos then return pos, "island" end
	return nil, "nothing to go to"
end

function I.Goto()
	local pos, what = I.Target()
	if not pos then
		Notify.Warn("island", what)
		return false
	end
	if Svc.Teleport(pos) then
		Notify.Good("island", "moved to the " .. what)
		return true
	end
	Notify.Bad("island", "teleport refused")
	return false
end

function I.Step(dt, now)
	local s = Cfg.s.island
	if not s.autoFind and not s.hopUntilFound then return end

	accum = accum + dt
	if accum < 2 then return end
	accum = 0

	local here = I.Check(false)

	if here then
		I.hopAttempts = 0
		if s.tpToDealer and not tpDone then
			tpDone = true
			I.Goto()
		end
		return
	end

	if s.hopUntilFound and I.Hopper then
		if now - (I.lastHop or 0) < s.hopDelay then return end
		I.lastHop = now
		I.hopAttempts = I.hopAttempts + 1
		Notify.Info("island", "not here, hopping (" .. I.hopAttempts .. ")")
		pcall(I.Hopper)
	end
end

function I.StatusLine()
	if I.present then
		return I.tier, "good"
	end
	return "not in this server", "bad"
end

return I
