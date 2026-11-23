-- @module cfg
-- Settings store + the single place every build-dependent value lives.

local Cfg = {}

Cfg.VERSION   = "1.0.0"
Cfg.NAME      = "olliE / Lord's Court"
Cfg.SHORT     = "olliE"
Cfg.FOLDER    = "ollie_tf"
Cfg.CFG_EXT   = ".json"

-- =====================================================================
-- TARGET DATA  -- build dependent, ALL UNSET.
--
-- Nothing below was read from a dump, a disassembly, a log or a live
-- session. There is no Touch Football ground truth in this project. The
-- resolver discovers what it can at runtime; anything it cannot discover
-- stays unset and the feature that needs it prints one line and turns
-- itself off. Nothing else stops.
--
-- provenance tag format on every line:
--   [kind | build | source | state]
--     kind   : instance-path / remote-name / arg-shape / number
--     build  : the game build the value came from
--     source : dump / remote spy / manual / resolver
--     state  : live / stale / unset
-- =====================================================================

Cfg.target = {
	-- [number | build unset | source unset | unset]
	-- 0 means "use the running place". Set only if you want hop locked to
	-- one place id.
	placeId = 0,

	-- [remote-name | build unset | source unset | unset]
	-- Fired by the game when you kick. Fill from CONFIG -> Remote Spy:
	-- arm the spy, kick the ball once, copy the name it logs.
	kickRemote = "",

	-- [arg-shape | build unset | source unset | unset]
	-- How kickRemote takes its arguments. One of:
	--   "dir_power"  FireServer(Vector3 unitDirection, number power)
	--   "vector"     FireServer(Vector3 velocity)
	--   "cframe"     FireServer(CFrame aimCFrame, number power)
	--   ""           unset -> remote backend stays off
	kickArgShape = "",

	-- [remote-name | build unset | source third-party page | UNVERIFIED]
	-- Names to try when you press Probe on the CONFIG tab. These are
	-- candidates, not values: each one is fired at the server with a probe
	-- vector and kept only if the ball actually moves. KickBall and
	-- GoalEvent come from a public Touch Football script dump of unknown
	-- date (scriptrb.com post 2279), not from a dump of your build, so
	-- neither is trusted until the probe proves it here.
	-- The prober also sweeps every RemoteEvent in the place whose name
	-- contains kick, shoot or ball, which is discovery rather than guesswork.
	kickCandidates = "KickBall,GoalEvent",

	-- [string | build unset | source resolver | unset]
	-- Written by the learner: how kickRemote was obtained.
	kickSource = "",

	-- [remote-name | build unset | source unset | unset]
	-- Fired to claim / complete a quest. Needed by Auto Complete Quest.
	questRemote = "",

	-- [remote-name | build unset | source unset | unset]
	-- Names to swallow when "Block Kick Deny Events" is on. Comma separated.
	denyRemotes = "",

	-- [instance-path | build unset | source unset | unset]
	-- Extra ball name candidates, comma separated. The resolver already
	-- scores every unanchored ball-shaped part; this just pins a name.
	ballNames = "",

	-- [instance-path | build unset | source unset | unset]
	-- Extra goal name candidates, comma separated. You can also walk into
	-- each goal and press "Capture Goal" on the CONFIG tab.
	goalNames = "",

	-- [number | build unset | source resolver | unset]
	-- Group id checked by Panic Staff. 0 disables the rank check and falls
	-- back to the manual staff name list.
	staffGroupId = 0,
	staffMinRank = 100,
	staffNames = "",
}

-- Measured at runtime by the calibration routine, never guessed.
Cfg.calib = {
	done        = false,
	gravity     = 0,     -- read from workspace at calibrate time
	dragK       = 0,     -- exponential velocity decay constant, 1/s
	powerToStud = 0,     -- studs/s produced per 1.0 power unit
	sampleCount = 0,
	stamp       = "",
}

-- =====================================================================
-- SETTINGS -- these are ours, not the game's. Safe to ship with values.
-- =====================================================================

Cfg.s = {
	reach = {
		enabled       = false,
		proNatural    = true,
		controlEasier = false,
		radius        = 14,
		priority      = 2,       -- 1 nearest, 2 ball-to-goal, 3 teammate-safe
		ballHold      = false,
		holdDistance  = 4.5,
		holdHeight    = 2.0,
		adaptHighMs   = true,
		adaptPerMs    = 0.045,   -- studs of extra radius per ms of ping
		adaptCap      = 12,
		triggerRange  = 9,
		pulseRate     = 22,      -- touch pulses per second
	},

	skills = {
		sneaky        = false,
		sneakyAirOnly = true,
		sneakyAuto    = true,
		sneakyPower   = 42,
		sneakyLift    = 0.35,

		pokers        = false,
		pokerSpeed    = 12,      -- pokes per second
		pokerPower    = 18,

		juggle        = false,
		juggleReach   = 10,
		juggleHeight  = 14,
		juggleSticky  = 0.55,

		groundShots   = false,
		groundLift    = 0.08,
	},

	aim = {
		aimbot        = false,
		aimlock       = false,
		aimlockSpeed  = 0.35,
		fovDeg        = 0,       -- 0 = unlimited
		power         = 70,
		speed         = 95,
		gravityScale  = 1.0,
		missChance    = 0,       -- percent
		curve         = false,
		curveAmount   = 0.35,
		curveAuto     = true,
		curveRandom   = false,
		topCorner     = false,
		cornerInset   = 2.2,
		autoDetectGoal = true,
		autoNero      = false,
		neroPower     = 88,
		neroLift      = 0.22,
		neroSpin      = 0.6,
		autoHeader    = false,
		headerRange   = 7,
		headerPower   = 55,
		fireRate      = 4,       -- shots per second cap
	},

	pass = {
		enabled       = false,
		teammatesOnly = true,
		throughBalls  = false,
		throughLead   = 0.85,
		curve         = false,
		curveAmount   = 0.25,
		minPower      = 25,
		maxPower      = 80,
		maxLobHeight  = 18,
		smartScore    = true,
		range         = 180,
	},

	keeper = {
		autoGK        = false,
		autoGS        = false,
		diveSpeed     = 70,
		touchReach    = 16,
		blockDeny     = false,
		panicReach    = false,
		panicRadius   = 26,
		predictTime   = 1.4,
	},

	special = {
		phase         = false,
		phaseMode     = 1,       -- 1 look-at, 2 selected
		antiPhase     = false,
		goalFarm      = false,
		goalFarmDelay = 1.5,
		saveFarm      = false,
		saveFarmDelay = 1.5,
		dunk          = false,
		dunkRange     = 22,
		trickOms      = false,
		trickIndex    = 1,
		ballTime      = false,
		ballTimeScale = 1.6,
		framePlayer   = false,
		bringBall     = false,
		bringDistance = 6,
		ballFrozen    = false,
	},

	visuals = {
		ballEsp       = false,
		ballEspBox    = true,
		ballEspTracer = false,
		ballEspDist   = true,
		ballTrail     = false,
		rgbChar       = false,
		rgbSpeed      = 1.0,
		rgbNeon       = true,
		bootTrail     = false,
		timeOfDay     = false,
		clockTime     = 14,
		spoofMarker   = false,
		spoofPing     = 12,
		spoofCpu      = 4,
		spoofSent     = 6,
	},

	character = {
		r6            = false,
		ownAvatar     = false,
		hatId         = 0,
		hairId        = 0,
		stripAccs     = false,
	},

	settings = {
		antiAfk       = true,
		autoBestServer= false,
		panicStaff    = false,
		notifications = true,
		autoQuest     = false,
		hopMaxPing    = 120,
		hopMinSlots   = 1,
		touchButtons  = true,
		touchSize     = 54,
		touchShape    = 1,       -- 1 shield, 2 circle, 3 square
		touchAlpha    = 0.15,
		menuKey       = "Insert",
		configName    = "default",
		touchPos      = {},   -- id -> {x, y} in pixels, written by the drag handler
	},

	binds = {
		reach    = {key = "R",    pad = "ButtonR1"},
		sneaky   = {key = "X",    pad = "ButtonL1"},
		aimbot   = {key = "T",    pad = "ButtonY"},
		aimpass  = {key = "G",    pad = "ButtonX"},
		autogk   = {key = "V",    pad = "ButtonL2"},
		phase    = {key = "F",    pad = "ButtonR2"},
		juggle   = {key = "J",    pad = "DPadUp"},
		pokers   = {key = "P",    pad = "DPadRight"},
		nero     = {key = "N",    pad = "DPadDown"},
		bring    = {key = "B",    pad = "DPadLeft"},
		freeze   = {key = "H",    pad = "ButtonSelect"},
		panic    = {key = "End",  pad = ""},
	},
}

Cfg.defaults = nil  -- filled by util at boot with a deep copy of Cfg.s

-- Comma list -> array of trimmed non-empty strings.
function Cfg.List(str)
	local out = {}
	if type(str) ~= "string" then return out end
	for piece in string.gmatch(str, "([^,]+)") do
		local t = string.match(piece, "^%s*(.-)%s*$")
		if t ~= "" then out[#out + 1] = t end
	end
	return out
end

-- A target value is usable only when it is non-empty / non-zero.
function Cfg.Has(path)
	local v = Cfg.target[path]
	if type(v) == "string" then return v ~= "" end
	if type(v) == "number" then return v ~= 0 end
	return v ~= nil
end

return Cfg
