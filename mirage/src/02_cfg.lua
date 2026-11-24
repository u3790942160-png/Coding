-- @module cfg
-- Settings store plus the single place every build-dependent value lives.

local Cfg = {}

Cfg.VERSION = "1.0.0"
Cfg.NAME    = "mirage stock"
Cfg.SHORT   = "mirage"
Cfg.FOLDER  = "mirage_stock"
Cfg.CFG_EXT = ".json"

-- =====================================================================
-- TARGET DATA -- build dependent, ALL UNSET.
--
-- No Blox Fruits dump was handed over, so nothing below was read from
-- one. Mirage stock rotates roughly every two hours and the game ships
-- updates, so a baked fruit table or price list would be wrong inside a
-- week and would read as real while being wrong. The resolver reads the
-- live shop instead, the learner captures the purchase remote off a buy
-- you make yourself, and anything still unset gates its own feature.
--
-- provenance tag format on every line:
--   [kind | build | source | state]
-- =====================================================================

Cfg.target = {
	-- [remote-name | build unset | source unset | unset]
	-- Fired when you buy from the dealer. CONFIG tab -> Watch a purchase,
	-- then buy one fruit by hand; the learner fills this and the shape.
	buyRemote = "",

	-- [arg-shape | build unset | source unset | unset]
	-- How buyRemote takes its arguments. One of:
	--   "name"        FireServer(string fruitName)
	--   "name_cur"    FireServer(string fruitName, string currency)
	--   "slot"        FireServer(number slotIndex)
	--   "slot_cur"    FireServer(number slotIndex, string currency)
	--   "bare"        FireServer()   -- the server reads a selection it already holds
	--   ""            unset -> buying is disabled and says so
	buyArgShape = "",

	-- [string | build unset | source resolver | unset]
	-- How buyRemote was obtained: watch / probe / manual.
	buySource = "",

	-- [string | build unset | source watch | unset]
	-- The currency token this build passes for a Beli purchase, captured
	-- from a buy you made yourself.
	buyBeliToken = "",

	-- [remote-name | build unset | source watch | unset]
	-- Fired by the game when the dealer's menu opens. Learned by arming
	-- the open watch and opening the shop once by hand.
	openRemote = "",
	openArgShape = "",

	-- [remote-name | build unset | source unset | unset]
	-- A RemoteFunction that returns the current stock, if this build has
	-- one. With it the stock can be polled without opening the shop.
	stockRemote = "",

	-- [remote-name | build unset | source third-party | UNVERIFIED]
	-- Names the prober will try before sweeping the place structurally.
	-- These are candidates, not values: each is checked for existence and,
	-- for buying, only kept once a purchase actually lands.
	buyCandidates = "",

	-- [instance-path | build unset | source unset | unset]
	-- Extra name hints, comma separated. The resolver already scores
	-- structurally; these just pin a name when it guesses wrong.
	dealerNames  = "",
	shopGuiNames = "",
	islandNames  = "",

	-- [string | build unset | source resolver | derived]
	-- leaderstats entry the budget is checked against. Blank means the
	-- resolver picks the largest numeric leaderstat it can find.
	currencyStat = "",
}

-- =====================================================================
-- SETTINGS -- ours, not the game's. Safe to ship with values.
-- =====================================================================

Cfg.s = {
	stock = {
		-- The tool never moves your character. It opens the dealer's menu
		-- where you stand and reads it.
		autoOpen      = true,
		reopenDelay   = 1.5,     -- seconds between attempts while shut
		keepOpen      = true,    -- reopen if the game closes it
		boostPrompt   = true,    -- raise the prompt's reach locally first
		revealHidden  = true,    -- unhide the shop frame already in PlayerGui
		useTouch      = true,    -- fire the dealer's touch parts as a fallback
		autoRefresh   = true,
		refreshRate   = 2.0,     -- seconds between stock reads
		showNormal    = true,    -- also list the normal dealer when readable
		notifyRestock = true,
		notifyWatched = true,
	},

	auto = {
		enabled       = false,
		-- Beli only. Robux is real money and the shop button does not say
		-- which currency it spends, so this tool never spends Robux.
		instant       = true,    -- buy on the same read the fruit appears in
		pollFast      = 0.15,    -- seconds between reads while armed
		budget        = 0,       -- 0 = no cap
		maxPerRestock = 1,
		retries       = 3,
		retryDelay    = 0.6,
		buyOnDetect   = true,
		stopAfterBuy  = false,
		watchlist     = {},      -- array of fruit names, exact as the shop prints them
	},

	island = {
		autoFind      = true,    -- detection only; nothing is moved
		hopUntilFound = false,
		hopDelay      = 4,
		hopMaxPing    = 200,
		scanRadius    = 6000,
	},

	settings = {
		antiAfk       = true,
		notifications = true,
		touchButtons  = true,
		touchSize     = 54,
		touchShape    = 1,
		touchAlpha    = 0.15,
		menuKey       = "Insert",
		configName    = "default",
		touchPos      = {},
	},

	binds = {
		menu    = {key = "Insert", pad = "ButtonStart"},
		refresh = {key = "R",      pad = "ButtonY"},
		buytop  = {key = "B",      pad = "ButtonA"},
		auto    = {key = "O",      pad = "ButtonX"},
		open    = {key = "M",      pad = "ButtonB"},
		hop     = {key = "H",      pad = "DPadRight"},
		panic   = {key = "End",    pad = ""},
	},
}

Cfg.defaults = nil  -- filled by util at boot

-- The fruit catalogue is learned, never shipped. It grows from every
-- stock read and from anything typed into the picker, and persists with
-- the config file.
Cfg.catalog = {}

function Cfg.List(str)
	local out = {}
	if type(str) ~= "string" then return out end
	for piece in string.gmatch(str, "([^,]+)") do
		local t = string.match(piece, "^%s*(.-)%s*$")
		if t ~= "" then out[#out + 1] = t end
	end
	return out
end

function Cfg.Has(path)
	local v = Cfg.target[path]
	if type(v) == "string" then return v ~= "" end
	if type(v) == "number" then return v ~= 0 end
	return v ~= nil
end

-- watchlist helpers, used by the picker and the auto engine
function Cfg.Watching(name)
	for _, n in ipairs(Cfg.s.auto.watchlist) do
		if string.lower(n) == string.lower(name) then return true end
	end
	return false
end

function Cfg.Watch(name)
	if name == nil or name == "" then return false end
	if Cfg.Watching(name) then return false end
	table.insert(Cfg.s.auto.watchlist, name)
	return true
end

function Cfg.Unwatch(name)
	for i, n in ipairs(Cfg.s.auto.watchlist) do
		if string.lower(n) == string.lower(name) then
			table.remove(Cfg.s.auto.watchlist, i)
			return true
		end
	end
	return false
end

function Cfg.ToggleWatch(name)
	if Cfg.Watching(name) then
		Cfg.Unwatch(name)
		return false
	end
	Cfg.Watch(name)
	return true
end

return Cfg
