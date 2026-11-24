-- @module catalog
-- The fruit list is learned, never shipped. Names come from stock reads
-- and from anything you type into the picker, and they persist with the
-- config file. No ModuleScript in the place is required: requiring an
-- unknown module runs its code, and that is not worth a name list.
local Cfg    = _R("cfg")
local Util   = _R("util")
local Notify = _R("notify")

local C = {}

function C.Has(name)
	local wanted = string.lower(Util.Trim(name or ""))
	if wanted == "" then return false end
	for _, n in ipairs(Cfg.catalog) do
		if string.lower(n) == wanted then return true end
	end
	return false
end

function C.Add(name)
	local clean = Util.Trim(name or "")
	if clean == "" then return false end
	if C.Has(clean) then return false end
	table.insert(Cfg.catalog, clean)
	table.sort(Cfg.catalog, function(a, b) return string.lower(a) < string.lower(b) end)
	return true
end

function C.Remove(name)
	local wanted = string.lower(Util.Trim(name or ""))
	for i, n in ipairs(Cfg.catalog) do
		if string.lower(n) == wanted then
			table.remove(Cfg.catalog, i)
			return true
		end
	end
	return false
end

-- Harvest every name out of a stock read.
function C.Harvest(rows)
	local added = 0
	for _, row in ipairs(rows or {}) do
		if C.Add(row.name) then added = added + 1 end
	end
	return added
end

function C.Count() return #Cfg.catalog end

-- Names matching a filter, watched ones first so the picker reads well.
function C.Filtered(query)
	local q = string.lower(Util.Trim(query or ""))
	local watched, rest = {}, {}
	for _, n in ipairs(Cfg.catalog) do
		if q == "" or string.find(string.lower(n), q, 1, true) then
			if Cfg.Watching(n) then watched[#watched + 1] = n else rest[#rest + 1] = n end
		end
	end
	local out = {}
	for _, n in ipairs(watched) do out[#out + 1] = n end
	for _, n in ipairs(rest) do out[#out + 1] = n end
	return out
end

function C.Clear()
	Cfg.catalog = {}
	Notify.Info("catalog", "cleared")
end

return C
