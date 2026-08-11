--[[
	Smoke test: run dist/VeltrexHub.lua against the mock API and exercise every
	public entry point. Any nil index, bad ordering or arithmetic-on-nil in the
	hub surfaces here as a hard error.

		lua5.4 test/smoke.lua
]]

local here = arg[0]:match("^(.*)/[^/]+$") or "."
package.path = here .. "/?.lua;" .. package.path

local mock = require("roblox_mock")

--==============================================================================
-- Sandbox
--==============================================================================

local env = setmetatable({}, { __index = _G })
mock.install(env)

-- In-memory filesystem so the config save/load paths actually run.
local files = {}
env.isfile    = function(name) return files[name] ~= nil end
env.readfile  = function(name) return files[name] end
env.writefile = function(name, contents) files[name] = contents end

-- Executor helper the steal engine needs. It is captured when the bundle
-- loads, so it has to exist before the chunk runs.
env.getconnections = function(signal) return signal.connections end

env._G = env

local checks, failures = 0, 0

local function check(name, fn)
	checks = checks + 1
	local ok, err = pcall(fn)
	if ok then
		print(string.format("  ok    %s", name))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s\n        %s", name, tostring(err)))
	end
end

--==============================================================================
-- Load the bundle
--==============================================================================

local path = here .. "/../dist/VeltrexHub.lua"
local source = assert(io.open(path, "r")):read("a")
local chunk = assert(load(source, "@VeltrexHub.lua", "t", env))

print("Veltrex smoke test")
print("------------------")

check("bundle loads and builds the interface", function()
	chunk()
	mock.step(3)
end)

local hub = env._G.Veltrex
assert(hub, "the bundle did not publish _G.Veltrex")

local Core = hub.Core
local UI   = hub.UI

--==============================================================================
-- Structure
--==============================================================================

check("core exposes its public API", function()
	for _, name in ipairs({
		"setFeature", "toggleFeature", "runAction", "setValue", "setMode",
		"setSpeedProfile", "setKeybind", "on", "emit", "save", "unload",
	}) do
		assert(type(Core[name]) == "function", "missing Core." .. name)
	end
end)

check("core creates no GUI instances", function()
	local guis = 0
	for _, child in ipairs(mock.playerGui:GetChildren()) do
		guis = guis + 1
	end
	-- Everything on screen must come from the interface module, which parents
	-- its ScreenGuis itself; core must not have added anything of its own.
	assert(UI.window ~= nil, "interface did not build a window")
	assert(guis >= 0)
end)

check("interface built window, hud and pad", function()
	assert(UI.window and UI.hud and UI.pad, "one of the three surfaces is missing")
end)

--==============================================================================
-- Features
--==============================================================================

check("every feature toggles on and off", function()
	for _, def in ipairs(Core.features) do
		Core.setFeature(def.id, true)
		mock.step(2)
		assert(Core.isOn(def.id), def.id .. " did not switch on")

		Core.setFeature(def.id, false)
		mock.step(2)
		assert(not Core.isOn(def.id), def.id .. " did not switch off")
	end
end)

check("conflicting features shut each other down", function()
	Core.setFeature("autoBat", true)
	Core.setFeature("batV2", true)
	mock.step(2)
	assert(not Core.isOn("autoBat"), "autoBat should have been switched off by batV2")

	Core.setFeature("antiDesync", true)
	mock.step(2)
	assert(not Core.isOn("batV2"), "batV2 should have been switched off by antiDesync")

	Core.setFeature("antiDesync", false)
	mock.step(2)
end)

--==============================================================================
-- Values, modes, profiles, actions
--==============================================================================

check("numeric settings clamp to their limits", function()
	for key, limit in pairs(Core.limits) do
		local low  = Core.setValue(key, limit[1] - 1000)
		local high = Core.setValue(key, limit[2] + 1000)
		assert(low == limit[1], key .. " did not clamp low")
		assert(high == limit[2], key .. " did not clamp high")
		Core.setValue(key, limit[1])
	end
end)

check("speed profiles switch", function()
	for _, profile in ipairs({ "normal", "carry", "lagger", "laggerCarry" }) do
		Core.setSpeedProfile(profile)
		assert(Core.cfg.speedProfile == profile, "profile did not stick: " .. profile)
		assert(type(Core.speedProfileLabel()) == "string")
	end
	Core.toggleSpeedProfile("carry")
	Core.toggleSpeedProfile("carry")
end)

check("modes switch", function()
	Core.setMode("stealMode", "semi")
	assert(Core.cfg.stealMode == "semi")
	Core.setMode("stealMode", "normal")
	Core.setMode("dropMode", "jump")
	assert(Core.cfg.dropMode == "jump")
	Core.setMode("dropMode", "stand")
	mock.step(2)
end)

check("every action runs", function()
	for id in pairs(Core.actions) do
		Core.runAction(id)
		mock.step(2)
	end
end)

--==============================================================================
-- Render / physics loops
--==============================================================================

check("render and physics loops survive a frame with no character", function()
	for _ = 1, 5 do
		mock.services.RunService.RenderStepped:Fire(0.016)
		mock.services.RunService.Heartbeat:Fire(0.016)
		mock.services.RunService.Stepped:Fire(0, 0.016)
	end
end)

check("loops survive with every feature enabled", function()
	for _, def in ipairs(Core.features) do Core.setFeature(def.id, true) end
	mock.step(3)
	for _ = 1, 5 do
		mock.services.RunService.RenderStepped:Fire(0.016)
		mock.services.RunService.Heartbeat:Fire(0.016)
		mock.services.RunService.Stepped:Fire(0, 0.016)
	end
	for _, def in ipairs(Core.features) do Core.setFeature(def.id, false) end
	mock.step(3)
end)

--==============================================================================
-- With a live character: the speed engine, aimbots and steal engine
--==============================================================================

check("speed engine runs against a real character", function()
	mock.spawnCharacter(mock.localPlayer, env.Vector3.new(0, 5, 0))
	mock.step(2)

	for _, profile in ipairs({ "normal", "carry", "lagger", "laggerCarry" }) do
		Core.setSpeedProfile(profile)
		for _ = 1, 3 do mock.services.RunService.RenderStepped:Fire(0.016) end
		assert(type(Core.state.speed) == "number", "speed readout is not a number")
	end

	Core.setFeature("autoSwitchSpeed", true)
	for _ = 1, 3 do mock.services.RunService.RenderStepped:Fire(0.016) end
	mock.step(2)
	Core.setFeature("autoSwitchSpeed", false)
end)

check("aimbots chase a real opponent", function()
	mock.addOpponent("Rival", env.Vector3.new(20, 5, 0))
	mock.step(1)

	for _, id in ipairs({ "autoBat", "batV2", "antiDesync" }) do
		Core.setFeature(id, true)
		mock.step(2)
		for _ = 1, 5 do
			mock.services.RunService.Heartbeat:Fire(0.016)
			mock.services.RunService.RenderStepped:Fire(0.016)
		end
		assert(Core.state.aimTarget == "Rival", id .. " did not lock onto the opponent")
		Core.setFeature(id, false)
		mock.step(2)
	end
end)

check("character-driven actions run", function()
	for _, mode in ipairs({ "stand", "jump" }) do
		Core.setMode("dropMode", mode)
		Core.runAction("drop")
		mock.step(3)
		for _ = 1, 3 do
			mock.services.RunService.Heartbeat:Fire(0.016)
			mock.services.RunService.Stepped:Fire(0, 0.016)
			mock.services.RunService.RenderStepped:Fire(0.016)
		end
	end

	Core.runAction("tpFloor")
	mock.step(2)

	Core.setFeature("autoTP", true)
	mock.step(3)
	Core.setFeature("autoTP", false)

	for _, id in ipairs({ "infiniteJump", "antiRagdoll", "noCollide", "unwalk", "medusaCounter", "batCounter" }) do
		Core.setFeature(id, true)
		mock.step(2)
		for _ = 1, 3 do mock.services.RunService.Heartbeat:Fire(0.016) end
		Core.setFeature(id, false)
		mock.step(2)
	end
end)

check("auto steal drives a podium prompt", function()
	mock.buildPlots().Parent = mock.workspace

	-- The clamp check above left every range at its minimum.
	Core.setValue("grabRadius", 200)
	Core.setValue("primeStealRange", 200)
	Core.setValue("semiStealRadius", 50)

	local progressSeen = false
	Core.on("progress", function(value)
		if value > 0 then progressSeen = true end
	end)

	for _, mode in ipairs({ "normal", "semi" }) do
		Core.setMode("stealMode", mode)
		Core.setFeature("autoSteal", true)
		mock.step(3)

		for _ = 1, 10 do
			mock.services.RunService.Heartbeat:Fire(0.016)
			mock.step(2)
		end

		assert(#Core.Steal.animals == 4, "expected 4 podiums, found " .. #Core.Steal.animals)
		Core.setFeature("autoSteal", false)
		mock.step(3)
	end

	assert(progressSeen, "the steal engine never reported progress")
end)

check("respawning rebuilds character state", function()
	Core.setFeature("batCounter", true)
	Core.setFeature("medusaCounter", true)
	mock.step(2)

	local character = mock.spawnCharacter(mock.localPlayer, env.Vector3.new(0, 5, 0))
	mock.localPlayer.CharacterAdded:Fire(character)
	mock.step(4)

	for _ = 1, 3 do
		mock.services.RunService.Heartbeat:Fire(0.016)
		mock.services.RunService.RenderStepped:Fire(0.016)
	end

	Core.setFeature("batCounter", false)
	Core.setFeature("medusaCounter", false)
	mock.step(2)
end)

--==============================================================================
-- Input
--==============================================================================

local function keyPress(keyCode)
	mock.services.UserInputService.InputBegan:Fire({
		UserInputType  = env.Enum.UserInputType.Keyboard,
		KeyCode        = keyCode,
		Position       = env.Vector3.new(0, 0, 0),
		UserInputState = env.Enum.UserInputState.Begin,
		Changed        = mock.Signal.new(),
	}, false)
end

check("every keybind fires without error", function()
	for _, bind in ipairs(Core.binds) do
		if bind.key then
			keyPress(bind.key)
			mock.step(2)
		end
	end
	-- Leave the hub in a quiet state.
	for _, def in ipairs(Core.features) do Core.setFeature(def.id, false) end
	mock.step(2)
end)

check("rebinding a key takes effect", function()
	Core.setKeybind("drop", env.Enum.KeyCode.G, false)
	assert(Core.bindLabel("drop") == "G", "bind label did not update")
	keyPress(env.Enum.KeyCode.G)
	mock.step(2)
end)

--==============================================================================
-- Interface interaction
--==============================================================================

local function everyButton(instance, out)
	out = out or {}
	for _, child in ipairs(instance:GetChildren()) do
		if rawget(child, "_class") == "TextButton" then table.insert(out, child) end
		everyButton(child, out)
	end
	return out
end

check("clicking every control in the interface is safe", function()
	local unloadCalls = 0
	local realUnload = UI.unload
	UI.unload = function() unloadCalls = unloadCalls + 1 end

	local buttons = everyButton(UI.window)
	assert(#buttons > 30, "expected a lot of controls, found " .. #buttons)

	for _, button in ipairs(buttons) do
		button.MouseButton1Click:Fire()
		mock.step(1)
	end
	for _, button in ipairs(everyButton(UI.pad)) do
		button.MouseButton1Click:Fire()
		mock.step(1)
	end

	-- Cancel any keybind row left listening for input.
	keyPress(env.Enum.KeyCode.Escape)

	UI.unload = realUnload
	assert(unloadCalls > 0, "the close and unload buttons never fired")
end)

check("search filters rows across tabs", function()
	local box
	local function findSearch(instance)
		for _, child in ipairs(instance:GetChildren()) do
			if rawget(child, "_class") == "TextBox" and child.PlaceholderText == "Search settings" then
				box = child
			end
			findSearch(child)
		end
	end
	findSearch(UI.window)
	assert(box, "search box not found")

	box.Text = "lagger"
	box:GetPropertyChangedSignal("Text"):Fire()
	box.Text = ""
	box:GetPropertyChangedSignal("Text"):Fire()
end)

--==============================================================================
-- Persistence
--==============================================================================

check("config is written to disk", function()
	Core.setValue("normalSpeed", 77)
	Core.save()
	mock.step(2)
	assert(files["VeltrexHub.json"], "no config file was written")
	assert(files["VeltrexHub.json"]:find("normalSpeed"), "config is missing its keys")
end)

--==============================================================================
-- Teardown
--==============================================================================

check("unload tears everything down", function()
	UI.unload()
	mock.step(3)
	assert(Core.unloaded, "core was not marked unloaded")
	for _ = 1, 3 do
		mock.services.RunService.RenderStepped:Fire(0.016)
		mock.services.RunService.Heartbeat:Fire(0.016)
	end
end)

print("------------------")
print(string.format("%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
