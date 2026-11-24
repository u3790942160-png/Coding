-- @module util
local Env = _R("env")
local Cfg = _R("cfg")

local Util = {}

function Util.Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function Util.Lerp(a, b, t) return a + (b - a) * t end

function Util.Round(v, places)
	local m = 10 ^ (places or 0)
	return math.floor(v * m + 0.5) / m
end

function Util.Approach(current, target, rate, dt)
	local d = target - current
	local step = rate * dt
	if math.abs(d) <= step then return target end
	if d > 0 then return current + step end
	return current - step
end

function Util.DeepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = Util.DeepCopy(v) end
	return out
end

function Util.DeepMerge(dst, src)
	if type(dst) ~= "table" or type(src) ~= "table" then return dst end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			Util.DeepMerge(dst[k], v)
		elseif dst[k] ~= nil or type(v) ~= "table" then
			dst[k] = v
		end
	end
	return dst
end

function Util.Split(str, sep)
	local out = {}
	if type(str) ~= "string" then return out end
	local pattern = "([^" .. sep .. "]+)"
	for piece in string.gmatch(str, pattern) do out[#out + 1] = piece end
	return out
end

function Util.Trim(s)
	if type(s) ~= "string" then return "" end
	return (string.match(s, "^%s*(.-)%s*$"))
end

-- ── Signal ───────────────────────────────────────────────────────────
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({handlers = {}}, Signal)
end

function Signal:Connect(fn)
	local entry = {fn = fn, alive = true}
	self.handlers[#self.handlers + 1] = entry
	return {
		Disconnect = function()
			entry.alive = false
		end,
	}
end

function Signal:Fire(...)
	local list = self.handlers
	local keep = {}
	for i = 1, #list do
		local entry = list[i]
		if entry.alive then
			keep[#keep + 1] = entry
			local ok, err = pcall(entry.fn, ...)
			if not ok then
				warn("[olliE] signal handler error: " .. tostring(err))
			end
		end
	end
	self.handlers = keep
end

function Signal:Clear()
	self.handlers = {}
end

Util.Signal = Signal

-- ── Maid ─────────────────────────────────────────────────────────────
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({items = {}}, Maid)
end

function Maid:Give(item)
	self.items[#self.items + 1] = item
	return item
end

local function destroyItem(item)
	if item == nil then return end
	local t = type(item)
	if t == "function" then
		pcall(item)
		return
	end
	if t == "table" then
		if type(item.Disconnect) == "function" then pcall(item.Disconnect, item) return end
		if type(item.Destroy) == "function" then pcall(item.Destroy, item) return end
		return
	end
	local ok = pcall(function() item:Disconnect() end)
	if ok then return end
	pcall(function() item:Destroy() end)
end

function Maid:Clean()
	local list = self.items
	self.items = {}
	for i = #list, 1, -1 do
		destroyItem(list[i])
	end
end

Util.Maid = Maid

-- ── Rate limiter ─────────────────────────────────────────────────────
function Util.Throttle(perSecond)
	local interval = 1 / math.max(perSecond, 0.0001)
	local last = -1e9
	return function(now)
		if now - last >= interval then
			last = now
			return true
		end
		return false
	end
end

-- ── File io (all gated, never assumed) ───────────────────────────────
local folderReady = false

local function ensureFolder()
	if folderReady then return true end
	if not Env.canFiles then return false end
	if Env.isfolder and Env.makefolder then
		local ok = pcall(function()
			if not Env.isfolder(Cfg.FOLDER) then Env.makefolder(Cfg.FOLDER) end
		end)
		if not ok then return false end
	end
	folderReady = true
	return true
end

function Util.ConfigPath(name)
	return Cfg.FOLDER .. "/" .. tostring(name) .. Cfg.CFG_EXT
end

function Util.SaveJson(name, tbl)
	if not ensureFolder() then return false, "no file io in this executor" end
	local HttpService = game:GetService("HttpService")
	local ok, encoded = pcall(function() return HttpService:JSONEncode(tbl) end)
	if not ok then return false, "encode failed" end
	local wrote = pcall(function() Env.writefile(Util.ConfigPath(name), encoded) end)
	if not wrote then return false, "write failed" end
	return true
end

function Util.LoadJson(name)
	if not ensureFolder() then return nil, "no file io in this executor" end
	local path = Util.ConfigPath(name)
	local exists = false
	pcall(function() exists = Env.isfile(path) end)
	if not exists then return nil, "no such config" end
	local body
	local ok = pcall(function() body = Env.readfile(path) end)
	if not ok or type(body) ~= "string" then return nil, "read failed" end
	local HttpService = game:GetService("HttpService")
	local good, decoded = pcall(function() return HttpService:JSONDecode(body) end)
	if not good then return nil, "decode failed" end
	return decoded
end

function Util.ListConfigs()
	local out = {}
	if not ensureFolder() or not Env.listfiles then return out end
	local ok, files = pcall(function() return Env.listfiles(Cfg.FOLDER) end)
	if not ok or type(files) ~= "table" then return out end
	for _, full in ipairs(files) do
		local base = string.match(full, "([^/\\]+)%" .. Cfg.CFG_EXT .. "$")
		if base then out[#out + 1] = base end
	end
	return out
end

-- ── misc ─────────────────────────────────────────────────────────────
-- getgenv where the executor has it, the plain global table where it does
-- not. Never nil, so callers do not need a branch.
function Util.Genv()
	local ok, g = pcall(function() return getgenv() end)
	if ok and type(g) == "table" then return g end
	return _G
end

function Util.Now()
	return os.clock()
end

function Util.Stamp()
	return os.date("!%Y-%m-%d %H:%M:%S")
end

function Util.SafeCall(fn, ...)
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil, a
end

Cfg.defaults = Util.DeepCopy(Cfg.s)

return Util
