-- @module session
-- Idle defeat, server selection, rejoin, panic.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local Env    = _R("env")
local Notify = _R("notify")

local ST = {}

local maid = Util.Maid.new()
local afkConn = nil
ST.PanicHook = nil
ST.hopping = false
ST.lastServerList = {}

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

function ST.FetchServers(pages)
	if not Env.canHttp then
		Notify.Once("hop_nohttp", "servers",
			"this executor exposes no http client, so the server list cannot be read.", "warn")
		return {}
	end
	local placeId = game.PlaceId
	local collected, cursor = {}, ""
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
		if srv.id ~= here and (srv.maxPlayers - srv.playing) >= 1 then
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

function ST.QueueReexec()
	if not Env.queueteleport then return false end
	local g = Util.Genv()
	local src = nil
	if type(g.MS_URL) == "string" and g.MS_URL ~= "" then
		src = 'loadstring(game:HttpGet("' .. g.MS_URL .. '"))()'
	elseif type(g.MS_SOURCE) == "string" and g.MS_SOURCE ~= "" then
		src = g.MS_SOURCE
	end
	if not src then return false end
	return (pcall(function() Env.queueteleport(src) end))
end

function ST.Hop()
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
			if srv.ping <= Cfg.s.island.hopMaxPing then pick = srv break end
		end
		if not pick then pick = list[1] end
		ST.QueueReexec()
		local ok = pcall(function()
			Svc.TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, Svc.LP)
		end)
		if not ok then
			Notify.Bad("hop", "teleport refused")
			ST.hopping = false
		end
	end)
	return true
end

function ST.Rejoin()
	Notify.Info("rejoin", "teleporting back into this place")
	ST.QueueReexec()
	local ok = pcall(function() Svc.TeleportService:Teleport(game.PlaceId, Svc.LP) end)
	if not ok then Notify.Bad("rejoin", "teleport refused") end
	return ok
end

function ST.Panic()
	if ST.PanicHook then
		pcall(ST.PanicHook)
		return true
	end
	return false
end

function ST.Destroy()
	maid:Clean()
	if afkConn then afkConn:Disconnect() afkConn = nil end
end

return ST
