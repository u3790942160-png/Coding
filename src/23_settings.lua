-- @module settings
-- Session plumbing: idle defeat, server selection, staff watch, rejoin,
-- quest firing, respawn, panic.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local R      = _R("resolve")
local Notify = _R("notify")

local ST = {}

local maid = Util.Maid.new()
local afkConn = nil
local lastQuest = 0
local lastStaffCheck = 0
ST.PanicHook = nil          -- set by main; called on Panic Eject
ST.hopping = false
ST.lastServerList = {}

-- ── Anti-AFK ─────────────────────────────────────────────────────────
function ST.ApplyAntiAfk()
	if afkConn then
		afkConn:Disconnect()
		afkConn = nil
	end
	if not Cfg.s.settings.antiAfk then return end
	local lp = Svc.LP
	if not lp then return end
	local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
	if not ok or not vu then
		Notify.Once("afk_novu", "anti-afk", "VirtualUser is not reachable from this client.", "warn")
		return
	end
	afkConn = lp.Idled:Connect(function()
		pcall(function()
			vu:CaptureController()
			vu:ClickButton2(Vector2.new(0, 0))
		end)
	end)
	maid:Give(afkConn)
end

-- ── Server list ──────────────────────────────────────────────────────
local function httpGetJson(url)
	local body = nil
	if Env.httpGet then
		body = Env.httpGet(url)
	elseif Env.request then
		local ok, res = pcall(function() return Env.request({Url = url, Method = "GET"}) end)
		if ok and type(res) == "table" then body = res.Body end
	end
	if type(body) ~= "string" then return nil end
	local ok, decoded = pcall(function() return Svc.HttpService:JSONDecode(body) end)
	if not ok then return nil end
	return decoded
end

function ST.PlaceId()
	if Cfg.target.placeId ~= 0 then return Cfg.target.placeId end
	return game.PlaceId
end

-- Returns an array of {id, playing, maxPlayers, ping, fps}, best first.
function ST.FetchServers(pages)
	if not Env.canHttp then
		Notify.Once("hop_nohttp", "servers", "this executor exposes no http client, so the server list cannot be read.", "warn")
		return {}
	end
	local placeId = ST.PlaceId()
	local collected = {}
	local cursor = ""
	for _ = 1, math.max(pages or 2, 1) do
		local url = "https://games.roblox.com/v1/games/" .. tostring(placeId)
			.. "/servers/Public?sortOrder=Asc&limit=100"
		if cursor ~= "" then url = url .. "&cursor=" .. cursor end
		local data = httpGetJson(url)
		if not data or type(data.data) ~= "table" then break end
		for _, srv in ipairs(data.data) do
			if type(srv.id) == "string" then
				collected[#collected + 1] = {
					id = srv.id,
					playing = tonumber(srv.playing) or 0,
					maxPlayers = tonumber(srv.maxPlayers) or 0,
					ping = tonumber(srv.ping) or 9999,
					fps = tonumber(srv.fps) or 0,
				}
			end
		end
		cursor = type(data.nextPageCursor) == "string" and data.nextPageCursor or ""
		if cursor == "" then break end
	end

	local here = game.JobId
	local filtered = {}
	for _, srv in ipairs(collected) do
		local free = srv.maxPlayers - srv.playing
		if srv.id ~= here and free >= Cfg.s.settings.hopMinSlots then
			filtered[#filtered + 1] = srv
		end
	end
	table.sort(filtered, function(a, b)
		if a.ping == b.ping then return a.fps > b.fps end
		return a.ping < b.ping
	end)
	ST.lastServerList = filtered
	return filtered
end

function ST.HopLowPing()
	if ST.hopping then return false end
	ST.hopping = true
	task.spawn(function()
		local list = ST.FetchServers(2)
		if #list == 0 then
			Notify.Warn("hop", "no other server came back from the list")
			ST.hopping = false
			return
		end
		local pick = nil
		for _, srv in ipairs(list) do
			if srv.ping <= Cfg.s.settings.hopMaxPing then pick = srv break end
		end
		if not pick then pick = list[1] end
		Notify.Info("hop", string.format("%d ms, %d/%d", pick.ping, pick.playing, pick.maxPlayers))
		ST.QueueReexec()
		local ok = pcall(function()
			Svc.TeleportService:TeleportToPlaceInstance(ST.PlaceId(), pick.id, Svc.LP)
		end)
		if not ok then
			Notify.Bad("hop", "teleport refused")
			ST.hopping = false
		end
	end)
	return true
end

function ST.AutoBestServer()
	if not Cfg.s.settings.autoBestServer then return end
	ST.HopLowPing()
end

-- ── Rejoin ───────────────────────────────────────────────────────────
-- Re-execute after a teleport. Uses the loader url when the one-liner set
-- one, otherwise the raw source if the loader stashed it.
function ST.QueueReexec()
	if not Env.queueteleport then return false end
	local g = Util.Genv()
	local src = nil
	if type(g.LC_URL) == "string" and g.LC_URL ~= "" then
		src = 'loadstring(game:HttpGet("' .. g.LC_URL .. '"))()'
	elseif type(g.LC_SOURCE) == "string" and g.LC_SOURCE ~= "" then
		src = g.LC_SOURCE
	end
	if not src then return false end
	local ok = pcall(function() Env.queueteleport(src) end)
	return ok
end

function ST.Rejoin()
	Notify.Info("rejoin", "teleporting back into this place")
	ST.QueueReexec()
	local ok = pcall(function()
		Svc.TeleportService:Teleport(ST.PlaceId(), Svc.LP)
	end)
	if not ok then Notify.Bad("rejoin", "teleport refused") end
	return ok
end

-- ── Panic Staff ──────────────────────────────────────────────────────
local function isStaff(plr)
	local groupId = Cfg.target.staffGroupId
	if groupId ~= 0 then
		local ok, rank = pcall(function() return plr:GetRankInGroup(groupId) end)
		if ok and type(rank) == "number" and rank >= Cfg.target.staffMinRank then
			return true
		end
	end
	for _, name in ipairs(Cfg.List(Cfg.target.staffNames)) do
		if string.lower(name) == string.lower(plr.Name) then return true end
		if string.lower(name) == string.lower(plr.DisplayName) then return true end
	end
	return false
end

function ST.StepStaff(now)
	if not Cfg.s.settings.panicStaff then return end
	if now - lastStaffCheck < 2 then return end
	lastStaffCheck = now
	if Cfg.target.staffGroupId == 0 and Cfg.target.staffNames == "" then
		Notify.Once("staff_unset", "panic staff",
			"no staff group id and no staff name list set, so there is nothing to match. CONFIG tab.", "warn")
		return
	end
	for _, p in ipairs(Svc.Others()) do
		if isStaff(p) then
			Notify.Bad("panic staff", p.Name .. " matched. leaving.")
			if ST.PanicHook then pcall(ST.PanicHook) end
			task.delay(0.15, function() ST.HopLowPing() end)
			return
		end
	end
end

-- ── Quests ───────────────────────────────────────────────────────────
function ST.StepQuests(now)
	if not Cfg.s.settings.autoQuest then return end
	if now - lastQuest < 3 then return end
	lastQuest = now
	if Cfg.target.questRemote == "" then
		Notify.Once("quest_unset", "auto quest",
			"quest remote is unset. CONFIG tab: arm the remote spy, hand in one quest, copy the name it logs.", "warn")
		return
	end
	local rem = R.FindRemote(Cfg.target.questRemote)
	if not rem then
		Notify.Once("quest_missing", "auto quest",
			"remote '" .. Cfg.target.questRemote .. "' is not in this place.", "warn")
		return
	end
	pcall(function()
		if rem:IsA("RemoteFunction") then
			rem:InvokeServer()
		else
			rem:FireServer()
		end
	end)
end

-- ── Respawn / panic ──────────────────────────────────────────────────
function ST.ForceRespawn()
	local hum = Svc.Hum()
	if hum then
		pcall(function() hum.Health = 0 end)
		return true
	end
	local char = Svc.Char()
	if char then
		pcall(function() char:BreakJoints() end)
		return true
	end
	return false
end

function ST.PanicEject()
	if ST.PanicHook then
		pcall(ST.PanicHook)
		return true
	end
	return false
end

function ST.Step(dt, now)
	ST.StepStaff(now)
	ST.StepQuests(now)
end

function ST.Destroy()
	maid:Clean()
	if afkConn then afkConn:Disconnect() afkConn = nil end
end

return ST
