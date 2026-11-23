-- @module env
-- Executor capability probe. Every optional global is tested exactly once here.
-- No other module touches an exploit global directly; they ask Env.

local Env = {}

local function probe(name)
	local ok, v = pcall(function() return getfenv(0)[name] end)
	if ok and type(v) == "function" then return v end
	ok, v = pcall(function() return getgenv()[name] end)
	if ok and type(v) == "function" then return v end
	return nil
end

local function probeTable(name)
	local ok, v = pcall(function() return getfenv(0)[name] end)
	if ok and type(v) == "table" then return v end
	return nil
end

Env.hookmetamethod    = probe("hookmetamethod")
Env.getrawmetatable   = probe("getrawmetatable")
Env.setreadonly       = probe("setreadonly") or probe("make_writeable")
Env.checkcaller       = probe("checkcaller")
Env.newcclosure       = probe("newcclosure")
Env.hookfunction      = probe("hookfunction") or probe("replaceclosure")
Env.getnamecallmethod = probe("getnamecallmethod")
Env.getconnections    = probe("getconnections")
Env.firetouchinterest = probe("firetouchinterest")
Env.fireproximity     = probe("fireproximityprompt")
Env.fireclickdetector = probe("fireclickdetector")
Env.sethiddenproperty = probe("sethiddenproperty")
Env.gethiddenproperty = probe("gethiddenproperty")
Env.setsimulationradius = probe("setsimulationradius")
Env.getcustomasset    = probe("getcustomasset")
Env.setfpscap         = probe("setfpscap")
Env.cloneref          = probe("cloneref") or function(x) return x end
Env.getobjects        = probe("getobjects")
Env.identifyexecutor  = probe("identifyexecutor") or probe("getexecutorname")
Env.queueteleport     = probe("queue_on_teleport") or probe("queueonteleport")

Env.writefile = probe("writefile")
Env.readfile  = probe("readfile")
Env.isfile    = probe("isfile")
Env.delfile   = probe("delfile")
Env.makefolder = probe("makefolder")
Env.isfolder   = probe("isfolder")
Env.listfiles  = probe("listfiles")

local syn = probeTable("syn")
Env.request = probe("request") or probe("http_request") or (syn and type(syn.request) == "function" and syn.request) or nil

Env.httpGet = nil
do
	local ok, kind = pcall(function() return type(game.HttpGet) end)
	if ok and kind == "function" then
		Env.httpGet = function(url)
			local good, body = pcall(function() return game:HttpGet(url, true) end)
			if good then return body end
			return nil
		end
	end
end

Env.name = "unknown"
if Env.identifyexecutor then
	local ok, n = pcall(Env.identifyexecutor)
	if ok and type(n) == "string" and #n > 0 then Env.name = n end
end

Env.gethui           = probe("gethui")
Env.protectgui       = probe("protect_gui") or probe("protectgui")

-- Capability groups the features gate on.
Env.canHook      = (Env.hookmetamethod ~= nil) or (Env.getrawmetatable ~= nil and Env.setreadonly ~= nil)
Env.canTouch     = Env.firetouchinterest ~= nil
Env.canFiles     = (Env.writefile ~= nil and Env.readfile ~= nil and Env.isfile ~= nil)
Env.canHttp      = (Env.httpGet ~= nil) or (Env.request ~= nil)
Env.canAssets    = (Env.getobjects ~= nil)
Env.canSimRadius = (Env.setsimulationradius ~= nil) or (Env.sethiddenproperty ~= nil)

function Env.Summary()
	local rows = {
		{"executor", Env.name},
		{"metamethod hooks", Env.canHook and "yes" or "no"},
		{"firetouchinterest", Env.canTouch and "yes" or "no"},
		{"file io", Env.canFiles and "yes" or "no"},
		{"http", Env.canHttp and "yes" or "no"},
		{"asset load", Env.canAssets and "yes" or "no"},
		{"sim radius", Env.canSimRadius and "yes" or "no"},
		{"queue on teleport", Env.queueteleport and "yes" or "no"},
	}
	return rows
end

return Env
