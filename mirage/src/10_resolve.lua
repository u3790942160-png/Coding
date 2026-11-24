-- @module resolve
-- Runtime discovery. Nothing here hardcodes a Blox Fruits path, a fruit
-- name or a price. Every result carries a tier:
--   "confirmed"  pinned by the operator this session
--   "derived"    scored from engine-visible structure
--   "unknown"    not found; the caller gates its feature
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local Notify = _R("notify")

local R = {}

R.dealer       = nil     -- the NPC model
R.dealerTier   = "unknown"
R.shopRoot     = nil     -- the GuiObject the stock rows live under
R.shopTier     = "unknown"
R.remoteIndex  = {}

local lastDealerScan = 0
local lastShopScan = 0
local DEALER_RESCAN = 4.0
local SHOP_RESCAN = 0.75

-- ── dealer NPC ───────────────────────────────────────────────────────
local DEALER_HINTS = {"dealer", "merchant", "vendor", "shop", "fruit", "advanced", "mirage"}
local PROMPT_HINTS = {"shop", "buy", "fruit", "purchase", "trade", "deal"}

local function hintScore(text, hints, weight)
	local score = 0
	local lower = string.lower(text or "")
	for _, h in ipairs(hints) do
		if string.find(lower, h, 1, true) then score = score + weight end
	end
	return score
end

local function promptScore(model)
	local score = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			score = score + 25
			score = score + hintScore(d.ActionText, PROMPT_HINTS, 20)
			score = score + hintScore(d.ObjectText, DEALER_HINTS, 20)
		elseif d:IsA("ClickDetector") then
			score = score + 15
		end
	end
	return score
end

function R.ScanDealer(force)
	local now = Util.Now()
	if not force and R.dealer and R.dealer.Parent and (now - lastDealerScan) < DEALER_RESCAN then
		return R.dealer
	end
	lastDealerScan = now

	local pinned = Cfg.List(Cfg.target.dealerNames)
	local best, bestScore = nil, 25

	for _, npc in ipairs(Svc.Npcs()) do
		local score = hintScore(npc.Name, DEALER_HINTS, 30)
		for _, pin in ipairs(pinned) do
			if string.lower(npc.Name) == string.lower(pin) then score = score + 300 end
		end
		local ok, ps = pcall(promptScore, npc)
		if ok then score = score + ps end
		if score > bestScore then best, bestScore = npc, score end
	end

	if best then
		R.dealer = best
		R.dealerTier = bestScore >= 250 and "confirmed" or "derived"
	elseif R.dealer and not R.dealer.Parent then
		R.dealer = nil
		R.dealerTier = "unknown"
	end
	return R.dealer
end

function R.DealerPos()
	local d = R.ScanDealer(false)
	if not d then return nil end
	return Svc.ModelPos(d)
end

function R.PinDealer(model)
	if model and model:IsA("Model") then
		R.dealer = model
		R.dealerTier = "confirmed"
		Cfg.target.dealerNames = model.Name
		return true
	end
	return false
end

function R.OpenDealer()
	local d = R.ScanDealer(false)
	if not d then return false, "no dealer found" end
	if not Env.fireproximity then return false, "executor has no fireproximityprompt" end
	local fired = 0
	for _, p in ipairs(d:GetDescendants()) do
		if p:IsA("ProximityPrompt") then
			pcall(function() Env.fireproximity(p, 0) end)
			fired = fired + 1
		end
	end
	if fired == 0 then return false, "dealer has no proximity prompt" end
	return true, fired .. " prompt(s) fired"
end

-- ── shop GUI ─────────────────────────────────────────────────────────
-- A stock row is a container holding a name-ish label and a price-ish
-- label. Find the container that holds the most such pairs: that is the
-- stock list, whatever the game calls it.

local UI_NOISE = {
	"close", "back", "exit", "cancel", "confirm", "ok", "yes", "no",
	"shop", "stock", "buy", "sell", "price", "beli", "money", "robux",
	"inventory", "level", "settings", "menu", "title", "amount", "total",
}

function R.LooksLikePrice(text)
	if type(text) ~= "string" then return false end
	if not string.find(text, "%d") then return false end
	local stripped = string.gsub(text, "[%s,%.]", "")
	-- a price is mostly digits with at most a short unit around it
	local digits = select(2, string.gsub(stripped, "%d", ""))
	return digits >= 2 and digits >= (#stripped - 8)
end

function R.LooksLikeName(text)
	if type(text) ~= "string" then return false end
	local trimmed = Util.Trim(text)
	local n = #trimmed
	if n < 3 or n > 28 then return false end
	if string.find(trimmed, "%d") then return false end
	if not string.find(trimmed, "%a") then return false end
	local lower = string.lower(trimmed)
	for _, noise in ipairs(UI_NOISE) do
		if lower == noise then return false end
	end
	return true
end

local function containerOf(gui, hops)
	local node = gui.Parent
	local n = 0
	while node and n < (hops or 2) do
		if node:IsA("GuiObject") then return node end
		node = node.Parent
		n = n + 1
	end
	return nil
end

function R.ScanShop(force)
	local now = Util.Now()
	if not force and R.shopRoot and R.shopRoot.Parent and (now - lastShopScan) < SHOP_RESCAN then
		return R.shopRoot
	end
	lastShopScan = now

	local pinned = Cfg.List(Cfg.target.shopGuiNames)
	local texts = Svc.VisibleTexts()
	local tally = {}       -- container -> {names = n, prices = n}

	for _, label in ipairs(texts) do
		if Svc.ChainVisible(label) then
			local box = containerOf(label, 2)
			if box then
				tally[box] = tally[box] or {names = 0, prices = 0}
				if R.LooksLikePrice(label.Text) then
					tally[box].prices = tally[box].prices + 1
				elseif R.LooksLikeName(label.Text) then
					tally[box].names = tally[box].names + 1
				end
			end
		end
	end

	-- roll each row container up to its parent list, counting paired rows
	local listTally = {}
	for box, counts in pairs(tally) do
		if counts.names >= 1 and counts.prices >= 1 then
			local list = box.Parent
			if list and list:IsA("GuiObject") then
				listTally[list] = (listTally[list] or 0) + 1
			end
		end
	end

	local best, bestRows = nil, 1
	for list, rows in pairs(listTally) do
		local score = rows
		for _, pin in ipairs(pinned) do
			if string.find(string.lower(list.Name), string.lower(pin), 1, true) then
				score = score + 100
			end
		end
		if score > bestRows then best, bestRows = list, score end
	end

	if best then
		R.shopRoot = best
		R.shopTier = bestRows >= 100 and "confirmed" or "derived"
	else
		R.shopRoot = nil
		R.shopTier = "unknown"
	end
	return R.shopRoot
end

function R.ShopOpen()
	local root = R.ScanShop(false)
	return root ~= nil and Svc.ChainVisible(root)
end

function R.PinShop(gui)
	if gui and gui:IsA("GuiObject") then
		R.shopRoot = gui
		R.shopTier = "confirmed"
		Cfg.target.shopGuiNames = gui.Name
		return true
	end
	return false
end

-- ── currency ─────────────────────────────────────────────────────────
function R.CurrencyValue()
	local stats = Svc.Leaderstats()
	if not stats then return nil, "no leaderstats" end
	local wanted = Util.Trim(Cfg.target.currencyStat)
	if wanted ~= "" then
		local v = stats:FindFirstChild(wanted)
		if v and type(v.Value) == "number" then return v.Value, wanted end
		return nil, "no leaderstat named " .. wanted
	end
	local best, bestName = nil, nil
	for _, child in ipairs(stats:GetChildren()) do
		local ok, value = pcall(function() return child.Value end)
		if ok and type(value) == "number" then
			if best == nil or value > best then best, bestName = value, child.Name end
		end
	end
	if best == nil then return nil, "no numeric leaderstat" end
	return best, bestName
end

-- ── remotes ──────────────────────────────────────────────────────────
function R.IndexRemotes()
	local out = {}
	local roots = {Svc.ReplicatedStorage, Svc.Workspace}
	local rf = game:FindFirstChild("ReplicatedFirst")
	if rf then roots[#roots + 1] = rf end
	for _, root in ipairs(roots) do
		local ok, desc = pcall(function() return root:GetDescendants() end)
		if ok then
			for _, d in ipairs(desc) do
				if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
					out[#out + 1] = d
				end
			end
		end
	end
	R.remoteIndex = out
	return out
end

function R.FindRemote(name)
	if type(name) ~= "string" or name == "" then return nil end
	if #R.remoteIndex == 0 then R.IndexRemotes() end
	for _, rem in ipairs(R.remoteIndex) do
		if rem.Name == name then return rem end
	end
	R.IndexRemotes()
	for _, rem in ipairs(R.remoteIndex) do
		if rem.Name == name then return rem end
	end
	return nil
end

-- ── namecall spy, the learner's input ────────────────────────────────
R.spyOn = false
R.spyLog = {}
R.spyEvents = {}
R.SPY_MAX = 60
R.SPY_EVENTS_MAX = 120
local hookInstalled = false
local oldNamecall = nil

local function summarise(value)
	local t = typeof(value)
	if t == "Instance" then return value.ClassName .. "(" .. value.Name .. ")" end
	if t == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)", value.X, value.Y, value.Z) end
	if t == "number" then return string.format("%.3f", value) end
	if t == "boolean" then return tostring(value) end
	if t == "string" then
		if #value > 28 then return '"' .. string.sub(value, 1, 28) .. '..."' end
		return '"' .. value .. '"'
	end
	if t == "table" then return "table" end
	return t
end

local function record(name, method, args)
	local parts, types = {}, {}
	local firstString, firstNumber = nil, nil
	for i = 1, args.n or #args do
		local v = args[i]
		parts[#parts + 1] = summarise(v)
		local t = typeof(v)
		types[#types + 1] = t
		if t == "string" and firstString == nil then firstString = v end
		if t == "number" and firstNumber == nil then firstNumber = v end
	end
	local line = method .. " " .. name .. "(" .. table.concat(parts, ", ") .. ")"
	table.insert(R.spyLog, 1, {t = Util.Stamp(), name = name, text = line})
	while #R.spyLog > R.SPY_MAX do table.remove(R.spyLog) end

	table.insert(R.spyEvents, 1, {
		clock = Util.Now(),
		name = name,
		method = method,
		types = types,
		argc = args.n or #args,
		str = firstString,
		num = firstNumber,
		text = line,
	})
	while #R.spyEvents > R.SPY_EVENTS_MAX do table.remove(R.spyEvents) end
end

function R.IsRemoteCall(self, method)
	if typeof(self) ~= "Instance" then return false end
	if method == "FireServer" or method == "InvokeServer" then return true end
	if method == "" or method == nil then
		local ok, isRemote = pcall(function()
			return self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
		end)
		return ok and isRemote
	end
	return false
end

function R.SelfCall()
	if not Env.checkcaller then return false end
	local ok, mine = pcall(Env.checkcaller)
	return ok and mine == true
end

function R.InstallHook()
	if hookInstalled then return true end
	if not Env.canHook then return false end
	local ok = pcall(function()
		if Env.hookmetamethod then
			oldNamecall = Env.hookmetamethod(game, "__namecall", function(self, ...)
				local method = Env.getnamecallmethod and Env.getnamecallmethod() or ""
				if R.spyOn and R.IsRemoteCall(self, method) and not R.SelfCall() then
					local args = table.pack(...)
					pcall(record, self.Name, method, args)
				end
				return oldNamecall(self, ...)
			end)
		else
			local mt = Env.getrawmetatable(game)
			Env.setreadonly(mt, false)
			oldNamecall = mt.__namecall
			mt.__namecall = function(self, ...)
				local method = Env.getnamecallmethod and Env.getnamecallmethod() or ""
				if R.spyOn and R.IsRemoteCall(self, method) and not R.SelfCall() then
					local args = table.pack(...)
					pcall(record, self.Name, method, args)
				end
				return oldNamecall(self, ...)
			end
			Env.setreadonly(mt, true)
		end
	end)
	hookInstalled = ok
	return ok
end

function R.HookInstalled() return hookInstalled end

function R.ClearSpy()
	R.spyLog = {}
	R.spyEvents = {}
end

function R.RecentSends(seconds)
	local cutoff = Util.Now() - (seconds or 0.6)
	local out = {}
	for _, ev in ipairs(R.spyEvents) do
		if ev.clock >= cutoff then out[#out + 1] = ev else break end
	end
	return out
end

function R.SpyLines(count)
	local out = {}
	for i = 1, math.min(count or 8, #R.spyLog) do
		out[#out + 1] = R.spyLog[i].text
	end
	return out
end

function R.Status()
	local money, statName = R.CurrencyValue()
	return {
		dealer   = R.dealer and (R.dealer.Name .. " [" .. R.dealerTier .. "]") or "not found",
		shop     = R.shopRoot and (R.shopRoot.Name .. " [" .. R.shopTier .. "]") or "not open",
		remotes  = #R.remoteIndex,
		hook     = hookInstalled and "installed" or "none",
		currency = money and (statName .. " " .. tostring(math.floor(money))) or (statName or "unknown"),
	}
end

return R
