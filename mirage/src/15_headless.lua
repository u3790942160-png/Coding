-- @module headless
-- Buying with no dealer menu, no NPC and no stock read.
--
-- The purchase is a remote call. The shop GUI is a middleman that makes
-- that call on your behalf, so when the menu will not open, the call
-- still can. This finds which remote does it by firing name-shaped
-- purchase calls and watching your Beli, then keeps firing that one.
--
-- Only the fruit NAME is ever passed, never a slot index. A wrong guess
-- can fail; it cannot buy a different fruit.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local R      = _R("resolve")
local S      = _R("stock")
local Notify = _R("notify")

local D = {}

D.state      = "idle"      -- idle | sweeping | locked | bought | exhausted
D.found      = nil         -- {name = remote name, shape = string}
D.attempts   = 0
D.sweeps     = 0
D.lastLine   = "not run"
D.lastSpend  = 0
D.tried      = {}          -- name|shape -> true, so a sweep does not repeat itself

local lastAttempt = -1e9
local lastSweep = -1e9
local sweeping = false

local BUY_HINTS = {"buy", "purchase", "shop", "dealer", "fruit", "stock", "order"}
local CANDIDATE_CAP = 16
local SETTLE = 0.12        -- seconds to wait for the balance to move

-- Name-only shapes. No slot index, ever.
local SHAPES = {"name", "name_false", "name_one"}

local function fireShape(rem, shape, fruit, token)
	local ok = pcall(function()
		if shape == "name" then
			if rem:IsA("RemoteFunction") then rem:InvokeServer(fruit) else rem:FireServer(fruit) end
		elseif shape == "name_token" then
			if rem:IsA("RemoteFunction") then rem:InvokeServer(fruit, token) else rem:FireServer(fruit, token) end
		elseif shape == "name_false" then
			if rem:IsA("RemoteFunction") then rem:InvokeServer(fruit, false) else rem:FireServer(fruit, false) end
		elseif shape == "name_one" then
			if rem:IsA("RemoteFunction") then rem:InvokeServer(fruit, 1) else rem:FireServer(fruit, 1) end
		else
			error("unknown shape")
		end
	end)
	return ok
end

-- Candidate remotes, best guess first: anything already learned, then
-- anything named like a purchase.
function D.Candidates()
	local out, seen = {}, {}

	local learned = Util.Trim(Cfg.target.buyRemote)
	if learned ~= "" then
		local rem = R.FindRemote(learned)
		if rem then
			out[#out + 1] = rem
			seen[learned] = true
		end
	end

	R.IndexRemotes()
	local scored = {}
	for _, rem in ipairs(R.remoteIndex) do
		if not seen[rem.Name] then
			local lower = string.lower(rem.Name)
			local score = 0
			for _, h in ipairs(BUY_HINTS) do
				if string.find(lower, h, 1, true) then score = score + 10 end
			end
			if string.find(lower, "buy", 1, true) then score = score + 25 end
			if string.find(lower, "purchase", 1, true) then score = score + 25 end
			if score > 0 then
				scored[#scored + 1] = {rem = rem, score = score}
			end
		end
	end
	table.sort(scored, function(a, b) return a.score > b.score end)
	for _, entry in ipairs(scored) do
		if #out >= CANDIDATE_CAP then break end
		out[#out + 1] = entry.rem
	end
	return out
end

-- Did the balance move? That is the only honest confirmation we have.
local function balance()
	local v = R.CurrencyValue()
	return v
end

function D.Target()
	local name = Util.Trim(Cfg.s.direct.target)
	if name ~= "" then return name end
	local list = Cfg.s.auto.watchlist
	if #list > 0 then return list[1] end
	return ""
end

-- One fire of one known remote and shape. Returns bought, spent.
local function tryOnce(rem, shape, fruit, token)
	local before = balance()
	if not fireShape(rem, shape, fruit, token) then return false, 0 end
	task.wait(SETTLE)
	local after = balance()
	if before == nil or after == nil then return false, 0 end
	local spent = before - after
	if spent > 0 then return true, spent end
	return false, 0
end

local function lock(remName, shape, spent)
	D.found = {name = remName, shape = shape}
	D.state = "locked"
	Cfg.target.buyRemote = remName
	Cfg.target.buySource = "direct sweep"
	if shape == "name" then
		Cfg.target.buyArgShape = "name"
	elseif shape == "name_token" then
		Cfg.target.buyArgShape = "name_cur"
	end
	D.lastLine = string.format("%s [%s] spent %s", remName, shape, S.Format(spent))
	Notify.Good("direct", D.lastLine)
end

-- ── a full sweep ─────────────────────────────────────────────────────
function D.Sweep()
	if sweeping then return false end
	local fruit = D.Target()
	if fruit == "" then
		D.lastLine = "no target fruit set"
		Notify.Warn("direct", D.lastLine)
		return false
	end
	if balance() == nil then
		D.lastLine = "no readable balance, so a purchase cannot be confirmed"
		Notify.Bad("direct", D.lastLine)
		return false
	end

	sweeping = true
	D.state = "sweeping"
	D.sweeps = D.sweeps + 1

	task.spawn(function()
		local token = Util.Trim(Cfg.target.buyBeliToken)
		local candidates = D.Candidates()
		local fired = 0

		for _, rem in ipairs(candidates) do
			local shapes = {}
			if token ~= "" then shapes[#shapes + 1] = "name_token" end
			for _, sh in ipairs(SHAPES) do shapes[#shapes + 1] = sh end

			for _, shape in ipairs(shapes) do
				local key = rem.Name .. "|" .. shape
				if not D.tried[key] then
					D.tried[key] = true
					fired = fired + 1
					local bought, spent = tryOnce(rem, shape, fruit, token)
					D.attempts = D.attempts + 1
					if bought then
						D.lastSpend = spent
						lock(rem.Name, shape, spent)
						sweeping = false
						if Cfg.s.direct.stopOnBuy then
							Cfg.s.direct.enabled = false
							D.state = "bought"
							Notify.Good("direct", fruit .. " bought for " .. S.Format(spent))
						end
						return
					end
				end
			end
		end

		sweeping = false
		if fired == 0 then
			D.state = "exhausted"
			D.lastLine = "every candidate and shape already tried; reset to sweep again"
		else
			D.state = "idle"
			D.lastLine = string.format("sweep %d: %d calls, nothing was charged", D.sweeps, fired)
		end
		Notify.Info("direct", D.lastLine)
	end)
	return true
end

-- ── one attempt on the remote we already know ────────────────────────
function D.Attempt()
	local fruit = D.Target()
	if fruit == "" then return false end
	if not D.found then return D.Sweep() end

	local rem = R.FindRemote(D.found.name)
	if not rem then
		D.found = nil
		D.state = "idle"
		D.lastLine = "the locked remote left the place"
		return false
	end

	task.spawn(function()
		local token = Util.Trim(Cfg.target.buyBeliToken)
		local bought, spent = tryOnce(rem, D.found.shape, fruit, token)
		D.attempts = D.attempts + 1
		if bought then
			D.lastSpend = spent
			D.lastLine = fruit .. " bought for " .. S.Format(spent)
			Notify.Good("direct", D.lastLine)
			if Cfg.s.direct.stopOnBuy then
				Cfg.s.direct.enabled = false
				D.state = "bought"
			end
		else
			D.lastLine = string.format("fired %s, nothing charged (attempt %d)", D.found.name, D.attempts)
		end
	end)
	return true
end

-- ── the loop ─────────────────────────────────────────────────────────
-- When a stock source exists it gates the fires, so nothing is sent until
-- the fruit is actually there. With no stock source it fires on a timer,
-- which is the whole point: no menu is needed either way.
function D.Gated()
	if not Cfg.s.direct.useStockGate then return false, "gate off" end
	if #S.entries == 0 then return false, "no stock source" end
	local fruit = D.Target()
	if S.Find(fruit) then return false, "in stock" end
	return true, "not in the read"
end

function D.Step(dt, now)
	local d = Cfg.s.direct
	if not d.enabled then return end
	if sweeping then return end
	if D.state == "bought" then return end

	local gated, why = D.Gated()
	if gated then
		D.lastLine = "waiting: " .. tostring(D.Target()) .. " " .. why
		return
	end

	if D.found then
		if now - lastAttempt < math.max(d.attemptDelay, 0.25) then return end
		lastAttempt = now
		D.Attempt()
		return
	end

	if d.maxSweeps > 0 and D.sweeps >= d.maxSweeps then
		D.state = "exhausted"
		return
	end
	if now - lastSweep < math.max(d.sweepDelay, 5) then return end
	lastSweep = now
	D.Sweep()
end

function D.Reset()
	D.tried = {}
	D.found = nil
	D.state = "idle"
	D.attempts = 0
	D.sweeps = 0
	D.lastLine = "reset"
	lastSweep = -1e9
	lastAttempt = -1e9
end

function D.Arm(name)
	if name and name ~= "" then Cfg.s.direct.target = name end
	Cfg.s.direct.enabled = true
	if D.state == "bought" then D.state = "idle" end
	Notify.Info("direct", "armed on " .. D.Target())
	return true
end

function D.StatusLine()
	local d = Cfg.s.direct
	if not d.enabled then return "off", "dim" end
	if D.state == "bought" then return D.Target() .. " bought", "good" end
	if D.found then
		return string.format("locked on %s [%s], %d attempts", D.found.name, D.found.shape, D.attempts), "good"
	end
	return string.format("hunting the buy remote, sweep %d, %d calls", D.sweeps, D.attempts), "accent"
end

function D.Report()
	local lines = {}
	lines[#lines + 1] = "target: " .. (D.Target() ~= "" and D.Target() or "none set")
	lines[#lines + 1] = "state: " .. D.state .. "  attempts " .. D.attempts .. "  sweeps " .. D.sweeps
	lines[#lines + 1] = D.found and ("locked: " .. D.found.name .. " [" .. D.found.shape .. "]") or "locked: nothing yet"
	lines[#lines + 1] = "candidates: " .. #D.Candidates() .. " remotes named like a purchase"
	local money = R.CurrencyValue()
	lines[#lines + 1] = "balance: " .. (money and S.Format(money) or "unreadable, cannot confirm a buy")
	lines[#lines + 1] = D.lastLine
	return lines
end

return D
