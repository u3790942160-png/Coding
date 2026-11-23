-- @module binds
-- One input listener for the whole tool. Keyboard and gamepad resolve to
-- the same action id, so every feature has both without duplicate code.
local Svc   = _R("svc")
local Cfg   = _R("cfg")
local Util  = _R("util")
local Notify= _R("notify")

local B = {}

local UIS = Svc.UserInputService
local actions = {}      -- id -> {fn = function, label = string}
local maid = Util.Maid.new()
local suspended = false

function B.Register(id, label, fn)
	actions[id] = {fn = fn, label = label}
end

function B.Labels()
	local out = {}
	for id, a in pairs(actions) do out[#out + 1] = {id = id, label = a.label} end
	table.sort(out, function(x, y) return x.id < y.id end)
	return out
end

function B.Suspend(state)
	suspended = state
end

local function fire(id)
	local a = actions[id]
	if not a then return end
	local ok, err = pcall(a.fn)
	if not ok then
		Notify.Bad("bind fault", id .. ": " .. tostring(err))
	end
end

local function matchKeyboard(name)
	for id, bind in pairs(Cfg.s.binds) do
		if bind.key ~= nil and bind.key ~= "" and bind.key == name then return id end
	end
	return nil
end

local function matchPad(name)
	for id, bind in pairs(Cfg.s.binds) do
		if bind.pad ~= nil and bind.pad ~= "" and bind.pad == name then return id end
	end
	return nil
end

function B.Init()
	maid:Clean()
	maid:Give(UIS.InputBegan:Connect(function(input, processed)
		if suspended then return end
		if processed then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.Keyboard then
			local id = matchKeyboard(input.KeyCode.Name)
			if id then fire(id) end
			if input.KeyCode.Name == Cfg.s.settings.menuKey then fire("menu") end
		elseif t == Enum.UserInputType.Gamepad1
			or t == Enum.UserInputType.Gamepad2
			or t == Enum.UserInputType.Gamepad3
			or t == Enum.UserInputType.Gamepad4 then
			local id = matchPad(input.KeyCode.Name)
			if id then fire(id) end
		end
	end))
end

-- Held state for binds that act while down rather than toggling.
function B.IsHeld(id)
	local bind = Cfg.s.binds[id]
	if not bind then return false end
	if bind.key and bind.key ~= "" then
		local ok, code = pcall(function() return Enum.KeyCode[bind.key] end)
		if ok and code and UIS:IsKeyDown(code) then return true end
	end
	if bind.pad and bind.pad ~= "" then
		local ok, code = pcall(function() return Enum.KeyCode[bind.pad] end)
		if ok and code then
			for _, state in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
				if state.KeyCode == code then
					if state.UserInputState == Enum.UserInputState.Begin then return true end
					if type(state.Position) == "userdata" and state.Position.Z > 0.5 then return true end
				end
			end
		end
	end
	return false
end

function B.Fire(id) fire(id) end

function B.Destroy()
	maid:Clean()
	actions = {}
end

return B
