-- @module stock
-- Reads what the dealer is selling right now and tells you when it
-- changes. Two readers, tried in order: the stock RemoteFunction when one
-- has been learned, otherwise the open shop GUI. Prices are parsed, never
-- assumed.
local Svc    = _R("svc")
local Cfg    = _R("cfg")
local Util   = _R("util")
local R      = _R("resolve")
local Notify = _R("notify")

local S = {}

S.entries   = {}         -- {name, beli, robux, qty, slot, button, container}
S.source    = "none"     -- remote | gui | none
S.dealerKind= "unknown"  -- mirage | normal | unknown
S.lastRead  = 0
S.hash      = ""
S.lastChange= 0
S.changes   = 0
S.onRestock = nil        -- set by the buy engine
S.onRead    = nil        -- fired after every good read, restock or not

local accum = 0

-- ── price parsing ────────────────────────────────────────────────────
-- "$1,200,000"  "1.2M"  "3,400,000 Beli"  "R$ 2,200"  "12.5k"
function S.ParsePrice(text)
	if type(text) ~= "string" then return nil, nil end
	local lower = string.lower(text)
	local currency = "beli"
	if string.find(lower, "r%$") or string.find(lower, "robux", 1, true) then
		currency = "robux"
	end

	local body = string.gsub(lower, "r%$", " ")
	body = string.gsub(body, "robux", " ")
	body = string.gsub(body, "beli", " ")
	body = string.gsub(body, "[%$,%s]", "")

	local number, suffix = string.match(body, "([%d%.]+)([kmb]?)")
	if not number then return nil, nil end
	local value = tonumber(number)
	if value == nil then return nil, nil end

	if suffix == "k" then value = value * 1e3
	elseif suffix == "m" then value = value * 1e6
	elseif suffix == "b" then value = value * 1e9 end

	return value, currency
end

function S.Format(value)
	if type(value) ~= "number" or value <= 0 then return "-" end
	if value >= 1e9 then return string.format("%.2fB", value / 1e9) end
	if value >= 1e6 then return string.format("%.2fM", value / 1e6) end
	if value >= 1e3 then return string.format("%.1fK", value / 1e3) end
	return string.format("%d", math.floor(value))
end

-- ── GUI reader ───────────────────────────────────────────────────────
local function buttonIn(container)
	if container:IsA("TextButton") or container:IsA("ImageButton") then return container end
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("TextButton") or d:IsA("ImageButton") then
			local ok, visible = pcall(function() return d.Visible end)
			if ok and visible then return d end
		end
	end
	local parent = container.Parent
	if parent and (parent:IsA("TextButton") or parent:IsA("ImageButton")) then return parent end
	return nil
end

function S.ReadFromGui()
	local root = R.ScanShop(false)
	if not root or not Svc.ChainVisible(root) then return nil, "shop not open" end

	local rows = {}
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local name, beli, robux, qty = nil, nil, nil, nil
			for _, d in ipairs(child:GetDescendants()) do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
					local text = Util.Trim(d.Text)
					if R.LooksLikePrice(text) then
						local value, currency = S.ParsePrice(text)
						if value then
							if currency == "robux" then
								if robux == nil or value > robux then robux = value end
							else
								if beli == nil or value > beli then beli = value end
							end
						end
						local stockNum = string.match(string.lower(text), "x%s*(%d+)")
						if stockNum then qty = tonumber(stockNum) end
					elseif name == nil and R.LooksLikeName(text) then
						name = text
					end
				end
			end
			if name and (beli or robux) then
				rows[#rows + 1] = {
					name = name,
					beli = beli or 0,
					robux = robux or 0,
					qty = qty or 1,
					container = child,
					button = buttonIn(child),
					y = child.AbsolutePosition.Y,
					order = child.LayoutOrder or 0,
				}
			end
		end
	end

	table.sort(rows, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.y < b.y
	end)
	for i, row in ipairs(rows) do row.slot = i end

	if #rows == 0 then return nil, "shop open but no priced rows read" end
	return rows, "gui"
end

-- ── remote reader ────────────────────────────────────────────────────
local NAME_KEYS  = {"Name", "name", "Fruit", "fruit", "Item", "item", "Type", "type", "Id", "id"}
local BELI_KEYS  = {"Price", "price", "Cost", "cost", "Beli", "beli", "Money", "money", "Value", "value"}
local ROBUX_KEYS = {"Robux", "robux", "RobuxPrice", "robuxPrice", "Premium", "premium"}
local QTY_KEYS   = {"Stock", "stock", "Amount", "amount", "Count", "count", "Quantity", "quantity"}

local function pick(record, keys, kind)
	for _, k in ipairs(keys) do
		local v = record[k]
		if v ~= nil and type(v) == kind then return v end
	end
	return nil
end

-- Walk whatever the remote returned and keep anything shaped like a
-- stock line. Works on an array of records and on a name -> price map.
function S.NormaliseRemote(payload)
	local rows = {}
	if type(payload) ~= "table" then return rows end

	for key, value in pairs(payload) do
		if type(value) == "table" then
			local name = pick(value, NAME_KEYS, "string")
			if name == nil and type(key) == "string" then name = key end
			local beli = pick(value, BELI_KEYS, "number")
			local robux = pick(value, ROBUX_KEYS, "number")
			local qty = pick(value, QTY_KEYS, "number")
			if name and (beli or robux) then
				rows[#rows + 1] = {
					name = name, beli = beli or 0, robux = robux or 0,
					qty = qty or 1, container = nil, button = nil, order = 0,
				}
			end
		elseif type(value) == "number" and type(key) == "string" then
			rows[#rows + 1] = {
				name = key, beli = value, robux = 0, qty = 1,
				container = nil, button = nil, order = 0,
			}
		elseif type(value) == "string" and type(key) == "number" then
			rows[#rows + 1] = {
				name = value, beli = 0, robux = 0, qty = 1,
				container = nil, button = nil, order = 0,
			}
		end
	end

	table.sort(rows, function(a, b) return a.name < b.name end)
	for i, row in ipairs(rows) do row.slot = i end
	return rows
end

function S.ReadFromRemote()
	local name = Util.Trim(Cfg.target.stockRemote)
	if name == "" then return nil, "no stock remote set" end
	local rem = R.FindRemote(name)
	if not rem then return nil, "remote '" .. name .. "' not in this place" end

	local ok, payload = pcall(function()
		if rem:IsA("RemoteFunction") then return rem:InvokeServer() end
		return nil
	end)
	if not ok or payload == nil then return nil, "remote returned nothing" end

	local rows = S.NormaliseRemote(payload)
	if #rows == 0 then return nil, "remote payload had no priced rows" end
	return rows, "remote"
end

-- ── classify ─────────────────────────────────────────────────────────
-- Public guides say the Mirage dealer carries seven fruits and the normal
-- dealer three. That is a third-party claim, not something read from this
-- build, so it is only used when the names give nothing.
function S.Classify(rows)
	local hintSource = ""
	if R.shopRoot then hintSource = hintSource .. " " .. R.shopRoot.Name end
	if R.dealer then hintSource = hintSource .. " " .. R.dealer.Name end
	local lower = string.lower(hintSource)
	if string.find(lower, "mirage", 1, true) or string.find(lower, "advanc", 1, true) then
		return "mirage"
	end
	if string.find(lower, "normal", 1, true) or string.find(lower, "regular", 1, true) then
		return "normal"
	end
	if #rows >= 5 then return "mirage" end
	if #rows > 0 and #rows <= 4 then return "normal" end
	return "unknown"
end

-- ── read + diff ──────────────────────────────────────────────────────
local function hashOf(rows)
	local names = {}
	for _, row in ipairs(rows) do names[#names + 1] = string.lower(row.name) end
	table.sort(names)
	return table.concat(names, "|")
end

function S.Read(force)
	local rows, source = S.ReadFromRemote()
	if not rows then
		rows, source = S.ReadFromGui()
	end
	if not rows then
		-- keep the last good read rather than blanking the list while the
		-- shop is shut; say so through source
		S.source = "none"
		return false, source
	end

	S.entries = rows
	S.source = source
	S.dealerKind = S.Classify(rows)
	S.lastRead = Util.Now()

	local newHash = hashOf(rows)
	if newHash ~= S.hash then
		local first = (S.hash == "")
		S.hash = newHash
		S.lastChange = S.lastRead
		S.changes = S.changes + 1
		if not first then
			if Cfg.s.stock.notifyRestock then
				Notify.Info("restock", #rows .. " in stock: " .. S.NameLine())
			end
		end
		if S.onRestock then pcall(S.onRestock, rows, first) end
	end

	-- every read, not just a changed one: a watched fruit can be sitting
	-- there already when the tool is armed
	if S.onRead then pcall(S.onRead, rows) end
	return true, source
end

function S.Rate()
	-- armed means the gap between the fruit landing and the buy going out
	-- is what matters, so the poll tightens on its own
	if Cfg.s.auto.enabled then
		return math.max(Cfg.s.auto.pollFast, 0.05)
	end
	return math.max(Cfg.s.stock.refreshRate, 0.25)
end

function S.Step(dt, now)
	if not Cfg.s.stock.autoRefresh then return end
	accum = accum + dt
	if accum < S.Rate() then return end
	accum = 0
	S.Read(false)
end

function S.Find(name)
	if type(name) ~= "string" then return nil end
	local wanted = string.lower(Util.Trim(name))
	for _, row in ipairs(S.entries) do
		if string.lower(row.name) == wanted then return row end
	end
	for _, row in ipairs(S.entries) do
		if string.find(string.lower(row.name), wanted, 1, true) then return row end
	end
	return nil
end

function S.NameLine()
	local names = {}
	for _, row in ipairs(S.entries) do names[#names + 1] = row.name end
	if #names == 0 then return "nothing read" end
	return table.concat(names, ", ")
end

function S.Age()
	if S.lastRead == 0 then return -1 end
	return Util.Now() - S.lastRead
end

function S.StatusLine()
	if #S.entries == 0 then
		return "no stock read yet", "bad"
	end
	return string.format("%d items | %s dealer | via %s | %.0fs ago",
		#S.entries, S.dealerKind, S.source, S.Age()), "good"
end

return S
