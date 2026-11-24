-- @module buy
-- Beli only. Pick a fruit, and the instant the dealer is holding it the
-- purchase goes out on the same read that saw it.
--
-- Robux is deliberately not here. The shop button does not say which
-- currency it spends, so a tool that guessed would be spending real money
-- on a guess.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local R      = _R("resolve")
local S      = _R("stock")
local L      = _R("learn")
local Notify = _R("notify")

local B = {}

B.log = {}
B.LOG_MAX = 40
B.lastResult = "idle"
B.boughtThisRestock = 0
B.lastAttempt = 0
B.lastAutoAttempt = -1e9
B.bought = {}            -- name -> clock, so one landing is not bought twice

local pending = nil      -- {name, tries, nextAt}
local REBUY_GUARD = 2.5  -- seconds before the same name may be bought again

local function logLine(name, price, how, ok)
	table.insert(B.log, 1, {t = Util.Stamp(), name = name, price = price, how = how, ok = ok})
	while #B.log > B.LOG_MAX do table.remove(B.log) end
end

function B.LogLines(count)
	local out = {}
	for i = 1, math.min(count or 6, #B.log) do
		local e = B.log[i]
		out[#out + 1] = string.format("%s %s  %s  via %s",
			e.ok and "ok " or "no ", e.name, S.Format(e.price), e.how)
	end
	return out
end

-- ── checks ───────────────────────────────────────────────────────────
function B.Affordable(row)
	local money = R.CurrencyValue()
	local price = row.beli or 0
	if price <= 0 then return true, "no beli price read on this row" end
	if money == nil then return true, "currency not readable, not blocking" end
	if money < price then return false, "short by " .. S.Format(price - money) end
	local budget = Cfg.s.auto.budget
	if budget > 0 and price > budget then return false, "over the budget cap" end
	return true, ""
end

-- ── execution paths ──────────────────────────────────────────────────
local function buyViaRemote(row)
	local name = Util.Trim(Cfg.target.buyRemote)
	local shape = Util.Trim(Cfg.target.buyArgShape)
	local rem = R.FindRemote(name)
	if not rem then return false, "remote missing" end

	local token = Util.Trim(Cfg.target.buyBeliToken)
	if (shape == "name_cur" or shape == "slot_cur") and token == "" then
		return false, "no beli token learned for this shape"
	end

	local ok, err = pcall(function()
		if shape == "name" then
			rem:FireServer(row.name)
		elseif shape == "name_cur" then
			rem:FireServer(row.name, token)
		elseif shape == "slot" then
			rem:FireServer(row.slot)
		elseif shape == "slot_cur" then
			rem:FireServer(row.slot, token)
		elseif shape == "bare" then
			rem:FireServer()
		else
			error("unsupported buyArgShape '" .. tostring(shape) .. "'")
		end
	end)
	if not ok then return false, tostring(err) end
	return true, "remote"
end

local function buyViaButton(row)
	if not row.button then return false, "row has no button" end
	if not Env.getconnections then return false, "no getconnections" end
	local fired = 0
	local ok = pcall(function()
		for _, conn in ipairs(Env.getconnections(row.button.MouseButton1Click)) do
			if conn.Fire then
				conn:Fire()
				fired = fired + 1
			elseif conn.Function then
				conn.Function()
				fired = fired + 1
			end
		end
	end)
	if not ok or fired == 0 then return false, "button had no live handler" end
	return true, "button"
end

-- ── the one call ─────────────────────────────────────────────────────
function B.Now(row)
	if row == nil then
		B.lastResult = "no such row in stock"
		return false, B.lastResult
	end

	local can, reason = B.Affordable(row)
	if not can then
		B.lastResult = row.name .. ": " .. reason
		Notify.Warn("buy", B.lastResult)
		logLine(row.name, row.beli or 0, "blocked", false)
		return false, reason
	end

	local before = R.CurrencyValue()
	local path, pathWhy = L.BuyPath()
	local ok, how = false, pathWhy

	if path == "remote" then
		ok, how = buyViaRemote(row)
		if not ok then
			local okB, howB = buyViaButton(row)
			if okB then ok, how = okB, howB end
		end
	elseif path == "button" then
		ok, how = buyViaButton(row)
	end

	B.lastAttempt = Util.Now()
	if not ok then
		B.lastResult = row.name .. ": " .. tostring(how)
		Notify.Bad("buy", B.lastResult)
		logLine(row.name, row.beli or 0, tostring(how), false)
		return false, how
	end

	B.bought[string.lower(row.name)] = Util.Now()
	logLine(row.name, row.beli or 0, how, true)
	B.lastResult = row.name .. " sent via " .. how
	Notify.Good("buy", B.lastResult)

	if before ~= nil then
		task.delay(1.0, function()
			local after = R.CurrencyValue()
			if after ~= nil and after < before then
				Notify.Good("buy", row.name .. " confirmed, " .. S.Format(before - after) .. " spent")
			end
		end)
	end
	return true, how
end

function B.NowByName(name)
	S.Read(false)
	local row = S.Find(name)
	if not row then
		B.lastResult = tostring(name) .. " is not in the stock right now"
		Notify.Warn("buy", B.lastResult)
		return false, B.lastResult
	end
	return B.Now(row)
end

-- ── instant path ─────────────────────────────────────────────────────
-- Called from the stock reader on every read, so the gap between the
-- fruit appearing and the purchase going out is one read, not one tick of
-- some slower loop.
local function recentlyBought(name)
	local when = B.bought[string.lower(name)]
	if when == nil then return false end
	return (Util.Now() - when) < REBUY_GUARD
end

function B.TryInstant(rows)
	local a = Cfg.s.auto
	if not a.enabled or not a.instant then return false end
	if #a.watchlist == 0 then return false end
	if a.maxPerRestock > 0 and B.boughtThisRestock >= a.maxPerRestock then return false end

	for _, name in ipairs(a.watchlist) do
		local row = S.Find(name)
		if row and not recentlyBought(row.name) then
			local can = B.Affordable(row)
			if can then
				local ok = B.Now(row)
				if ok then
					B.boughtThisRestock = B.boughtThisRestock + 1
					if a.stopAfterBuy then
						a.enabled = false
						Notify.Info("auto", "disarmed after the buy, as set")
					end
					return true
				end
				-- failed: hand it to the retry loop rather than hammering
				pending = {name = row.name, tries = 1, nextAt = Util.Now() + a.retryDelay}
				return false
			end
		end
	end
	return false
end

-- ── restock + retries ────────────────────────────────────────────────
function B.OnRestock(rows, first)
	B.boughtThisRestock = 0
	B.bought = {}
	if first then return end
	if not Cfg.s.stock.notifyWatched then return end
	for _, row in ipairs(rows) do
		if Cfg.Watching(row.name) then
			Notify.Good("watched", row.name .. " is in stock for " .. S.Format(row.beli))
		end
	end
end

function B.Step(dt, now)
	local a = Cfg.s.auto
	if not a.enabled then
		pending = nil
		return
	end
	if #a.watchlist == 0 then return end

	if pending then
		if now < pending.nextAt then return end
		local row = S.Find(pending.name)
		if not row then
			pending = nil
			return
		end
		if B.Now(row) then
			B.boughtThisRestock = B.boughtThisRestock + 1
			pending = nil
			if a.stopAfterBuy then
				a.enabled = false
				Notify.Info("auto", "disarmed after the buy, as set")
			end
		else
			pending.tries = pending.tries + 1
			if pending.tries >= a.retries then
				pending = nil
			else
				pending.nextAt = now + a.retryDelay
			end
		end
		return
	end

	-- the instant path covers the normal case; this is the backstop for
	-- when the reader is off and the list was filled some other way
	if a.instant then return end
	if a.maxPerRestock > 0 and B.boughtThisRestock >= a.maxPerRestock then return end
	if now - B.lastAutoAttempt < 0.4 then return end

	for _, name in ipairs(a.watchlist) do
		local row = S.Find(name)
		if row and not recentlyBought(row.name) then
			if B.Affordable(row) then
				B.lastAutoAttempt = now
				pending = {name = row.name, tries = 0, nextAt = now}
				return
			end
		end
	end
end

function B.ToggleAuto()
	Cfg.s.auto.enabled = not Cfg.s.auto.enabled
	local a = Cfg.s.auto
	if a.enabled and #a.watchlist == 0 then
		Notify.Warn("instant buy", "armed, but nothing is picked. PICK tab.")
	else
		Notify.Info("instant buy", a.enabled
			and ("armed on " .. table.concat(a.watchlist, ", "))
			or "off")
	end
	return a.enabled
end

function B.StatusLine()
	local a = Cfg.s.auto
	if not a.enabled then return "off", "dim" end
	if #a.watchlist == 0 then return "armed with nothing picked", "bad" end
	return string.format("armed on %s | poll %.2fs | %d bought this restock",
		table.concat(a.watchlist, ", "), S.Rate(), B.boughtThisRestock), "good"
end

return B
