-- @module learn
-- Finds the purchase remote instead of being told it, and names which
-- part of the chain is dead when nothing buys.
--
-- Buying is Watch-only on purpose. Probing an unknown RemoteEvent to see
-- whether it buys something would spend your Beli or your Robux to find
-- out, so the prober only touches RemoteFunctions that read stock.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local R      = _R("resolve")
local S      = _R("stock")
local Notify = _R("notify")

local L = {}

L.state     = "idle"       -- idle | watching | probing
L.result    = "not run"
L.signature = ""
L.stockResult = "not run"

L.WATCH_LIMIT  = 60        -- seconds before the watch gives up
L.MATCH_WINDOW = 1.2       -- seconds of spy log to look back through
L.MIN_DROP     = 1         -- currency units that count as a purchase

local watchStart = 0
local lastMoney = nil

-- ── shape inference ──────────────────────────────────────────────────
function L.ShapeOf(ev)
	local t = ev.types or {}
	local first, second = t[1], t[2]
	if first == "string" then
		if second == "string" then return "name_cur", "string + string" end
		return "name", "string"
	end
	if first == "number" then
		if second == "string" then return "slot_cur", "number + string" end
		return "slot", "number"
	end
	if ev.argc == 0 then return "bare", "no arguments" end
	for i = 1, #t do
		if t[i] == "string" then return "", "string at arg " .. i .. ", map it by hand" end
		if t[i] == "number" then return "", "number at arg " .. i .. ", map it by hand" end
	end
	return "", table.concat(t, ", ")
end

local function scoreEvent(ev, boughtName)
	local score = 0
	local lower = string.lower(ev.name)
	for _, hint in ipairs({"buy", "purchase", "shop", "dealer", "fruit", "stock", "trade"}) do
		if string.find(lower, hint, 1, true) then score = score + 30 end
	end
	if ev.str ~= nil then score = score + 20 end
	if ev.num ~= nil then score = score + 10 end
	-- the strongest signal: an argument that is the fruit we just bought
	if boughtName and ev.str and string.lower(ev.str) == string.lower(boughtName) then
		score = score + 200
	end
	return score
end

-- ── watch ────────────────────────────────────────────────────────────
function L.ArmBuy()
	if L.state ~= "idle" then
		Notify.Warn("learn", "already running")
		return false
	end
	if not R.InstallHook() then
		L.result = "executor cannot hook namecall"
		Notify.Bad("learn", "this executor cannot hook namecall, so the purchase cannot be seen. Type the remote name in by hand.")
		return false
	end
	local money = R.CurrencyValue()
	if money == nil then
		L.result = "no readable currency"
		Notify.Warn("learn", "no numeric leaderstat to watch. Set the currency stat on this tab.")
		return false
	end

	R.spyOn = true
	R.ClearSpy()
	lastMoney = money
	watchStart = Util.Now()
	L.state = "watching"
	L.result = "watching, buy one fruit by hand"
	Notify.Info("learn", "armed. buy one fruit from the dealer yourself.")
	return true
end

function L.Disarm(reason)
	L.state = "idle"
	R.spyOn = false
	if reason then L.result = reason end
end

-- Which stock line costs about what was just spent.
local function fruitForDrop(drop)
	local best, bestDelta = nil, math.huge
	for _, row in ipairs(S.entries) do
		if row.beli > 0 then
			local delta = math.abs(row.beli - drop)
			if delta < bestDelta then best, bestDelta = row, delta end
		end
	end
	if best and bestDelta <= math.max(drop * 0.02, 1) then return best end
	return nil
end

local function adopt(ev, boughtRow)
	local shape, signature = L.ShapeOf(ev)
	Cfg.target.buyRemote = ev.name
	Cfg.target.buySource = "watch"
	L.signature = signature

	if shape ~= "" then
		Cfg.target.buyArgShape = shape
		-- the second argument of a *_cur shape is the token this build
		-- uses for the currency that was actually spent
		if (shape == "name_cur" or shape == "slot_cur") and ev.types[2] == "string" then
			local token = nil
			local args = ev.text
			token = string.match(args, '",%s*"([^"]+)"%)')
			if token then Cfg.target.buyBeliToken = token end
		end
		L.result = ev.name .. "  [" .. shape .. "]"
		local extra = boughtRow and ("  bought " .. boughtRow.name) or ""
		Notify.Good("learn", ev.name .. " taking " .. signature .. extra)
	else
		Cfg.target.buyArgShape = ""
		L.result = ev.name .. "  shape unclear: " .. signature
		Notify.Warn("learn", ev.name .. " found, but its arguments are " .. signature)
	end
end

function L.Step(dt, now)
	if L.state ~= "watching" then return end

	if now - watchStart > L.WATCH_LIMIT then
		L.Disarm("nothing seen in " .. L.WATCH_LIMIT .. "s")
		Notify.Warn("learn", "no purchase seen. Arm it again and buy one fruit while it runs.")
		return
	end

	local money = R.CurrencyValue()
	if money == nil then return end
	if lastMoney == nil then lastMoney = money return end

	local drop = lastMoney - money
	lastMoney = money
	if drop < L.MIN_DROP then return end

	local row = fruitForDrop(drop)
	local sends = R.RecentSends(L.MATCH_WINDOW)
	if #sends == 0 then
		L.Disarm("spend seen with no remote send behind it")
		Notify.Warn("learn",
			"you spent " .. S.Format(drop) .. " with no remote send in the window. The buy button path is the one to use.")
		return
	end

	local best, bestScore = nil, -1
	for _, ev in ipairs(sends) do
		local sc = scoreEvent(ev, row and row.name or nil)
		if sc > bestScore then best, bestScore = ev, sc end
	end
	adopt(best, row)
	L.Disarm()
end

-- ── stock remote prober ──────────────────────────────────────────────
-- RemoteFunctions only, and only ones named like a read. Invoking a read
-- is cheap; firing an unknown event is not, so this never does that.
function L.ProbeStock()
	if L.state ~= "idle" then return false end
	R.IndexRemotes()

	local tried, found = 0, nil
	for _, rem in ipairs(R.remoteIndex) do
		if rem:IsA("RemoteFunction") then
			local lower = string.lower(rem.Name)
			local looksRead = string.find(lower, "stock", 1, true)
				or string.find(lower, "shop", 1, true)
				or string.find(lower, "get", 1, true)
				or string.find(lower, "dealer", 1, true)
				or string.find(lower, "fruit", 1, true)
			if looksRead and tried < 14 then
				tried = tried + 1
				local ok, payload = pcall(function() return rem:InvokeServer() end)
				if ok and type(payload) == "table" then
					local rows = S.NormaliseRemote(payload)
					if #rows >= 2 then
						found = rem.Name
						break
					end
				end
			end
		end
	end

	if found then
		Cfg.target.stockRemote = found
		L.stockResult = found .. " returns parseable stock"
		Notify.Good("probe", L.stockResult)
		return true
	end
	L.stockResult = "no read remote returned stock (" .. tried .. " tried)"
	Notify.Warn("probe", L.stockResult .. ". The GUI reader still works with the shop open.")
	return false
end

-- ── diagnosis ────────────────────────────────────────────────────────
function L.Diagnose()
	local rows = {}
	local dealer = R.ScanDealer(false)
	rows[#rows + 1] = {"dealer npc", dealer and (dealer.Name .. " [" .. R.dealerTier .. "]") or "not found", dealer ~= nil}

	local shopOpen = R.ShopOpen()
	rows[#rows + 1] = {"shop gui", shopOpen and (R.shopRoot.Name .. " open") or "not open", shopOpen}

	rows[#rows + 1] = {"stock read", #S.entries > 0 and (#S.entries .. " via " .. S.source) or "nothing read", #S.entries > 0}

	local buyPath, why = L.BuyPath()
	rows[#rows + 1] = {"buy path", buyPath or why, buyPath ~= nil}

	local money, statName = R.CurrencyValue()
	rows[#rows + 1] = {"currency", money and (statName .. " " .. S.Format(money)) or (statName or "unreadable"), money ~= nil}

	local verdict
	if not dealer and #S.entries == 0 then
		verdict = "no dealer and no stock. Get to Mirage Island, open the dealer, then press Read stock."
	elseif #S.entries == 0 then
		verdict = "dealer found but nothing read. Open its shop, then Read stock, or probe for a stock remote."
	elseif buyPath == nil then
		verdict = "stock reads fine, buying has no path: " .. why
	else
		verdict = "stock reads and buying goes through the " .. buyPath .. " path."
	end
	return rows, verdict
end

-- Which way a purchase can actually go right now.
function L.BuyPath()
	if Util.Trim(Cfg.target.buyRemote) ~= "" and Util.Trim(Cfg.target.buyArgShape) ~= "" then
		if R.FindRemote(Cfg.target.buyRemote) then return "remote", "" end
		return nil, "remote '" .. Cfg.target.buyRemote .. "' not in this place"
	end
	if Env.getconnections then
		for _, row in ipairs(S.entries) do
			if row.button then return "button", "" end
		end
		return nil, "no buy remote learned and no clickable row in the read"
	end
	return nil, "no buy remote learned and this executor has no getconnections"
end

function L.Status()
	if L.state == "watching" then return "watching for a purchase", "accent" end
	local good = Util.Trim(Cfg.target.buyRemote) ~= ""
	return L.result, good and "good" or "dim"
end

return L
