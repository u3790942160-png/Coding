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

function R.DealerParts(model)
	local prompts, clicks, touch = 0, 0, 0
	if not model then return prompts, clicks, touch end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then prompts = prompts + 1
		elseif d:IsA("ClickDetector") then clicks = clicks + 1
		elseif d:IsA("BasePart") then
			if d.CanTouch ~= false then touch = touch + 1 end
		end
	end
	return prompts, clicks, touch
end

function R.ScanDealer(force)
	local now = Util.Now()
	if not force and R.dealer and R.dealer.Parent and (now - lastDealerScan) < DEALER_RESCAN then
		return R.dealer
	end
	lastDealerScan = now

	local pinned = Cfg.List(Cfg.target.dealerNames)

	-- rigs, plus anything named like a dealer whether or not it has one
	local candidates = Svc.Npcs()
	local seen = {}
	for _, m in ipairs(candidates) do seen[m] = true end
	for _, m in ipairs(Svc.NamedModels(DEALER_HINTS, 400)) do
		if not seen[m] then
			seen[m] = true
			candidates[#candidates + 1] = m
		end
	end

	local best, bestScore = nil, 25
	for _, npc in ipairs(candidates) do
		local score = hintScore(npc.Name, DEALER_HINTS, 30)
		for _, pin in ipairs(pinned) do
			if string.lower(npc.Name) == string.lower(pin) then score = score + 300 end
		end
		local ok, ps = pcall(promptScore, npc)
		if ok then score = score + ps end
		-- a dealer you can actually open beats one you cannot
		local prompts, clicks = R.DealerParts(npc)
		if prompts > 0 or clicks > 0 then score = score + 45 end
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

-- Local writes that make a prompt reachable from where you are standing.
-- The server still decides whether the trigger counts, so this helps a
-- build that checks the prompt and does nothing for one that checks the
-- player's position.
function R.BoostPrompts(model)
	local touched = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("ProximityPrompt") then
			pcall(function()
				if p.MaxActivationDistance < 500 then p.MaxActivationDistance = 500 end
				p.RequiresLineOfSight = false
				p.HoldDuration = 0
			end)
			touched = touched + 1
		end
	end
	return touched
end

-- Fire whatever the NPC exposes.
function R.OpenDealer()
	local d = R.ScanDealer(false)
	if not d then return false, "no dealer found" end

	if Cfg.s.stock.boostPrompt then pcall(R.BoostPrompts, d) end

	local fired = 0
	if Env.fireproximity then
		for _, p in ipairs(d:GetDescendants()) do
			if p:IsA("ProximityPrompt") then
				pcall(function() Env.fireproximity(p, 0) end)
				fired = fired + 1
			end
		end
	end
	if Env.fireclickdetector then
		for _, c in ipairs(d:GetDescendants()) do
			if c:IsA("ClickDetector") then
				pcall(function() Env.fireclickdetector(c) end)
				fired = fired + 1
			end
		end
	end

	if fired == 0 then
		if not Env.fireproximity and not Env.fireclickdetector then
			return false, "executor has no fireproximityprompt or fireclickdetector"
		end
		return false, "the dealer model carries no prompt and no click detector"
	end
	return true, fired .. " trigger(s) fired"
end

-- Walk into the dealer without walking: fire the touch on its parts.
function R.TouchDealer()
	if not Env.canTouch then return false, "executor has no firetouchinterest" end
	local d = R.ScanDealer(false)
	if not d then return false, "no dealer found" end
	local hrp = Svc.HRP()
	if not hrp then return false, "no character" end
	local fired = 0
	for _, part in ipairs(d:GetDescendants()) do
		if part:IsA("BasePart") and fired < 12 then
			pcall(function()
				Env.firetouchinterest(hrp, part, 0)
				Env.firetouchinterest(hrp, part, 1)
			end)
			fired = fired + 1
		end
	end
	if fired == 0 then return false, "dealer has no parts to touch" end
	return true, fired .. " part(s) touched"
end

-- A button in your own GUI that opens the shop.
function R.ClickShopButton()
	if not Env.getconnections then return false, "no getconnections" end
	local hints = {"shop", "dealer", "fruit", "stock", "buy"}
	for _, gui in ipairs(Svc.AllTexts()) do
		if gui:IsA("TextButton") then
			local lower = string.lower(gui.Name .. " " .. tostring(gui.Text))
			for _, h in ipairs(hints) do
				if string.find(lower, h, 1, true) then
					local fired = 0
					pcall(function()
						for _, conn in ipairs(Env.getconnections(gui.MouseButton1Click)) do
							if conn.Fire then conn:Fire() fired = fired + 1 end
						end
					end)
					if fired > 0 then return true, gui.Name end
				end
			end
		end
	end
	return false, "no shop-ish button with a live handler"
end

-- The remote the game fires when the menu opens, if the watch caught it.
function R.FireOpenRemote()
	local name = Util.Trim(Cfg.target.openRemote)
	if name == "" then return false, "no open remote learned" end
	local rem = R.FindRemote(name)
	if not rem then return false, "open remote not in this place" end
	local shape = Util.Trim(Cfg.target.openArgShape)
	local ok = pcall(function()
		if rem:IsA("RemoteFunction") then
			rem:InvokeServer()
		elseif shape == "dealer" and R.dealer then
			rem:FireServer(R.dealer.Name)
		else
			rem:FireServer()
		end
	end)
	if not ok then return false, "open remote errored" end
	return true, name
end

-- Every way in, cheapest and least invasive first. Returns ok, how.
function R.OpenAny()
	if R.ShopOpen() then return true, "already open" end

	if Cfg.s.stock.revealHidden then
		local hidden = R.FindHiddenShops()
		if #hidden > 0 then
			local ok, why = R.RevealShop(hidden[1].frame)
			if ok then
				R.ScanShop(true)
				if R.ShopOpen() then return true, "revealed " .. why end
			end
		end
	end

	local ok, why = R.FireOpenRemote()
	if ok then
		R.ScanShop(true)
		if R.ShopOpen() then return true, "open remote " .. why end
	end

	ok, why = R.OpenDealer()
	local lastWhy = why
	if ok then
		R.ScanShop(true)
		if R.ShopOpen() then return true, why end
	end

	if Cfg.s.stock.useTouch then
		ok, why = R.TouchDealer()
		if ok then
			R.ScanShop(true)
			if R.ShopOpen() then return true, "touch: " .. why end
		end
	end

	ok, why = R.ClickShopButton()
	if ok then
		R.ScanShop(true)
		if R.ShopOpen() then return true, "ui button " .. why end
	end

	return false, lastWhy or why or "nothing worked"
end

-- ── auto open ────────────────────────────────────────────────────────
-- Opens the dealer's menu where you stand. Nothing here moves you.
R.openState = "idle"
R.openTries = 0
local lastOpenTry = -1e9

function R.StepAutoOpen(dt, now)
	if not Cfg.s.stock.autoOpen then
		R.openState = "off"
		return
	end

	if R.ShopOpen() then
		if R.openTries > 0 then
			Notify.Good("dealer", "menu open after " .. R.openTries .. " attempt(s)")
		end
		R.openTries = 0
		R.openState = "open"
		return
	end

	-- it was open and the game shut it
	if R.openState == "open" and not Cfg.s.stock.keepOpen then
		R.openState = "closed, not reopening"
		return
	end

	-- a hidden shop frame needs no dealer at all, so only bail when both
	-- the NPC and a hidden frame are missing
	local dealer = R.ScanDealer(false)
	if not dealer and #R.FindHiddenShops() == 0 then
		R.openState = "no dealer and no hidden shop frame"
		return
	end

	-- back off rather than hammering a prompt the server is refusing
	local delay = math.max(Cfg.s.stock.reopenDelay, 0.25)
	if R.openTries >= 8 then delay = delay * 4 end
	if now - lastOpenTry < delay then return end
	lastOpenTry = now
	R.openTries = R.openTries + 1

	local ok, why = R.OpenAny()
	if ok then
		R.openState = "open"
		Notify.Good("dealer", "menu opened: " .. why)
		R.openTries = 0
		return
	end

	R.openState = why .. " (" .. R.openTries .. ")"
	if R.openTries == 8 then
		Notify.Once("open_slow", "dealer",
			"eight tries, menu still shut. CONFIG tab: Scan and report shows what is actually there, and Watch the open captures what the game fires when you open it by hand.", "warn")
	end
end

function R.OpenStatus()
	if R.openState == "open" then return "menu open", "good" end
	if R.openState == "off" then return "auto open off", "dim" end
	return R.openState, "bad"
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

-- Group name+price label pairs by the frame that holds them, and roll
-- those row frames up to the list that holds the most of them.
local function bestList(texts, requireVisible)
	local tally = {}
	for _, label in ipairs(texts) do
		if (not requireVisible) or Svc.ChainVisible(label) then
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

	local listTally = {}
	for box, counts in pairs(tally) do
		if counts.names >= 1 and counts.prices >= 1 then
			local list = box.Parent
			if list and list:IsA("GuiObject") then
				listTally[list] = (listTally[list] or 0) + 1
			end
		end
	end

	local ranked = {}
	local pinned = Cfg.List(Cfg.target.shopGuiNames)
	for list, rows in pairs(listTally) do
		local score = rows
		local path = string.lower(list.Name)
		local parent = list.Parent
		if parent then path = path .. " " .. string.lower(parent.Name) end
		for _, hint in ipairs({"shop", "dealer", "fruit", "stock", "mirage", "buy"}) do
			if string.find(path, hint, 1, true) then score = score + 2 end
		end
		for _, pin in ipairs(pinned) do
			if string.find(path, string.lower(pin), 1, true) then score = score + 100 end
		end
		ranked[#ranked + 1] = {frame = list, rows = rows, score = score}
	end
	table.sort(ranked, function(a, b) return a.score > b.score end)
	return ranked
end

function R.ScanShop(force)
	local now = Util.Now()
	if not force and R.shopRoot and R.shopRoot.Parent and (now - lastShopScan) < SHOP_RESCAN then
		return R.shopRoot
	end
	lastShopScan = now

	local ranked = bestList(Svc.VisibleTexts(), true)
	local top = ranked[1]
	if top and top.rows >= 2 then
		R.shopRoot = top.frame
		R.shopTier = top.score >= 100 and "confirmed" or "derived"
	else
		R.shopRoot = nil
		R.shopTier = "unknown"
	end
	return R.shopRoot
end

-- Shop frames that exist but are switched off. This is the one that
-- matters: a menu you have never opened is still in PlayerGui, hidden.
function R.FindHiddenShops()
	local ranked = bestList(Svc.AllTexts(), false)
	local out = {}
	for _, entry in ipairs(ranked) do
		if entry.rows >= 2 and not Svc.ChainVisible(entry.frame) then
			out[#out + 1] = entry
		end
	end
	return out
end

-- Everything we switched on, so unload puts it back.
R.revealed = {}

local function remember(inst, key, value)
	R.revealed[#R.revealed + 1] = {inst = inst, key = key, old = value}
end

function R.RevealShop(frame)
	if not frame then return false, "nothing to reveal" end
	local node = frame
	local hops = 0
	while node and hops < 24 do
		if node:IsA("ScreenGui") then
			if node.Enabled ~= true then
				remember(node, "Enabled", node.Enabled)
				pcall(function() node.Enabled = true end)
			end
			break
		end
		if node:IsA("GuiObject") and node.Visible ~= true then
			remember(node, "Visible", node.Visible)
			pcall(function() node.Visible = true end)
		end
		node = node.Parent
		hops = hops + 1
	end
	if frame:IsA("GuiObject") and frame.Visible ~= true then
		remember(frame, "Visible", frame.Visible)
		pcall(function() frame.Visible = true end)
	end
	R.shopRoot = frame
	R.shopTier = "revealed"
	lastShopScan = 0
	return true, frame.Name
end

function R.RestoreReveals()
	for i = #R.revealed, 1, -1 do
		local entry = R.revealed[i]
		if entry.inst and entry.inst.Parent then
			pcall(function() entry.inst[entry.key] = entry.old end)
		end
	end
	R.revealed = {}
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

-- What is actually there, in lines. Turns "it does not work" into data.
function R.ScanReport()
	local lines = {}
	local d = R.ScanDealer(true)
	if d then
		local prompts, clicks, touch = R.DealerParts(d)
		lines[#lines + 1] = string.format("dealer: %s  prompts %d  clicks %d  parts %d",
			d.Name, prompts, clicks, touch)
	else
		lines[#lines + 1] = "dealer: none scored above the floor"
	end

	local visible = R.ScanShop(true)
	lines[#lines + 1] = "visible shop frame: " .. (visible and visible.Name or "none")

	local hidden = R.FindHiddenShops()
	if #hidden == 0 then
		lines[#lines + 1] = "hidden shop frames: none"
	else
		for i = 1, math.min(#hidden, 3) do
			lines[#lines + 1] = string.format("hidden #%d: %s  (%d rows)",
				i, hidden[i].frame.Name, hidden[i].rows)
		end
	end

	lines[#lines + 1] = string.format("executor: prompt %s  click %s  touch %s  conns %s",
		Env.fireproximity and "y" or "n",
		Env.fireclickdetector and "y" or "n",
		Env.canTouch and "y" or "n",
		Env.getconnections and "y" or "n")
	return lines
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
