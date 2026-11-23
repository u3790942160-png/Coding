-- @module amath
-- Pure aim / prediction math. No game reads in here, no Instance touched.
-- Every function takes its world constants as arguments so it can be
-- checked without the game running.
--
-- Coordinate system: Roblox. Y up, right handed, studs, CFrame is
-- row-vector style via CFrame.lookAt. Angles in radians unless the name
-- says Deg.

local AM = {}

local V3 = Vector3.new
local ZERO = Vector3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)

AM.ZERO = ZERO
AM.UP = UP

function AM.Finite(v)
	if typeof(v) == "Vector3" then
		return v.X == v.X and v.Y == v.Y and v.Z == v.Z
			and math.abs(v.X) < 1e9 and math.abs(v.Y) < 1e9 and math.abs(v.Z) < 1e9
	end
	return type(v) == "number" and v == v and math.abs(v) < 1e12
end

function AM.Flat(v)
	return V3(v.X, 0, v.Z)
end

function AM.SafeUnit(v)
	local m = v.Magnitude
	if m < 1e-5 or not AM.Finite(v) then return ZERO end
	return v / m
end

function AM.Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- ── Ballistics ───────────────────────────────────────────────────────
-- Launch velocity that carries a projectile from p0 to p1 at fixed speed
-- under gravity g (studs/s^2, positive magnitude, acting -Y).
-- lowArc true picks the flat trajectory, false the lob.
-- Returns Vector3 velocity, or nil when the target is out of range.
function AM.SolveLaunch(p0, p1, speed, g, lowArc)
	if speed <= 0 then return nil end
	local delta = p1 - p0
	local flat = AM.Flat(delta)
	local d = flat.Magnitude
	local y = delta.Y

	if g <= 1e-6 then
		local dir = AM.SafeUnit(delta)
		if dir == ZERO then return nil end
		return dir * speed
	end

	if d < 1e-4 then
		-- Straight up or straight down.
		local need = math.sqrt(math.max(2 * g * math.abs(y), 0))
		if need > speed then return nil end
		if y >= 0 then return V3(0, speed, 0) end
		return V3(0, -speed, 0)
	end

	local s2 = speed * speed
	local disc = s2 * s2 - g * (g * d * d + 2 * y * s2)
	if disc < 0 then return nil end
	local root = math.sqrt(disc)
	local numer
	if lowArc then numer = s2 - root else numer = s2 + root end
	local angle = math.atan2(numer, g * d)

	local dirFlat = flat / d
	local vy = speed * math.sin(angle)
	local vxz = speed * math.cos(angle)
	local vel = dirFlat * vxz + V3(0, vy, 0)
	if not AM.Finite(vel) then return nil end
	return vel
end

-- Minimum launch speed that can reach p1 from p0 under gravity g.
function AM.MinSpeed(p0, p1, g)
	if g <= 1e-6 then return 1 end
	local delta = p1 - p0
	local d = AM.Flat(delta).Magnitude
	local y = delta.Y
	local inner = y + math.sqrt(math.max(y * y + d * d, 0))
	if inner <= 0 then return 1 end
	return math.sqrt(math.max(g * inner, 0))
end

-- Projectile position at time t.
function AM.ParabolaAt(p0, v0, g, t)
	return p0 + v0 * t - V3(0, 0.5 * g * t * t, 0)
end

-- Flight time for a launch solved by SolveLaunch.
function AM.FlightTime(p0, p1, vel)
	local flat = AM.Flat(p1 - p0)
	local vflat = AM.Flat(vel)
	local vm = vflat.Magnitude
	if vm < 1e-4 then
		if math.abs(vel.Y) < 1e-4 then return 0 end
		return math.abs((p1.Y - p0.Y) / vel.Y)
	end
	return flat.Magnitude / vm
end

-- ── Lead ─────────────────────────────────────────────────────────────
-- Iterative intercept of a target moving at constant velocity.
function AM.Lead(origin, targetPos, targetVel, speed, g, iters)
	iters = iters or 4
	local aim = targetPos
	local vel = nil
	for _ = 1, iters do
		local v = AM.SolveLaunch(origin, aim, speed, g, true)
		if not v then
			v = AM.SolveLaunch(origin, aim, speed, g, false)
		end
		if not v then return nil, aim end
		vel = v
		local t = AM.FlightTime(origin, aim, v)
		aim = targetPos + targetVel * t
		if not AM.Finite(aim) then return nil, targetPos end
	end
	return vel, aim
end

-- Exponential drag correction. k is the decay constant from calibration.
-- Returns the launch speed to use so the projectile still arrives.
function AM.DragCompensate(speed, distance, k)
	if k <= 1e-6 or speed <= 0 then return speed end
	local t = distance / speed
	local scale = math.exp(k * t * 0.5)
	return speed * AM.Clamp(scale, 1, 3)
end

-- ── Plane / goal geometry ────────────────────────────────────────────
-- First time the parabola crosses the plane (point q, unit normal n).
-- Returns t or nil.
function AM.ParabolaPlaneTime(p0, v0, g, q, n)
	-- 0.5*g*n.Y*t^2 - (v0.n)*t - (p0-q).n = 0   (sign set below)
	local a = -0.5 * g * n.Y
	local b = v0:Dot(n)
	local c = (p0 - q):Dot(n)
	if math.abs(a) < 1e-9 then
		if math.abs(b) < 1e-9 then return nil end
		local t = -c / b
		if t >= 0 then return t end
		return nil
	end
	local disc = b * b - 4 * a * c
	if disc < 0 then return nil end
	local root = math.sqrt(disc)
	local t1 = (-b + root) / (2 * a)
	local t2 = (-b - root) / (2 * a)
	local best = nil
	if t1 >= 0 then best = t1 end
	if t2 >= 0 and (best == nil or t2 < best) then best = t2 end
	return best
end

-- Goal described by a CFrame (look vector points out of the mouth) and a
-- Vector3 size in that frame's local axes (X width, Y height, Z depth).
-- Returns an aim point near a top corner, insetting from post and bar.
-- side: -1 left, 1 right, 0 auto from keeperPos.
function AM.GoalCorner(goalCF, goalSize, inset, side, keeperPos)
	local halfW = math.max(goalSize.X * 0.5 - inset, 0.25)
	local halfH = math.max(goalSize.Y * 0.5 - inset, 0.25)
	if side == 0 then
		side = 1
		if keeperPos then
			local local_ = goalCF:PointToObjectSpace(keeperPos)
			if local_.X > 0 then side = -1 else side = 1 end
		end
	end
	local offset = Vector3.new(side * halfW, halfH, 0)
	return goalCF:PointToWorldSpace(offset)
end

-- Centre-of-mouth aim point, slightly inside the line.
function AM.GoalCentre(goalCF, goalSize)
	return goalCF:PointToWorldSpace(Vector3.new(0, goalSize.Y * 0.25, 0))
end

-- Is a world point inside the goal mouth box?
function AM.InsideGoal(goalCF, goalSize, point, pad)
	pad = pad or 0
	local l = goalCF:PointToObjectSpace(point)
	return math.abs(l.X) <= goalSize.X * 0.5 + pad
		and math.abs(l.Y) <= goalSize.Y * 0.5 + pad
		and math.abs(l.Z) <= goalSize.Z * 0.5 + pad
end

-- ── Curve ────────────────────────────────────────────────────────────
-- Lateral acceleration that bends a shot. amount in [-1, 1], left negative.
-- Applied per frame by the shot controller, not baked into the launch.
function AM.CurveAccel(velocity, amount, strength)
	local dir = AM.SafeUnit(velocity)
	if dir == ZERO then return ZERO end
	local lateral = dir:Cross(UP)
	if lateral.Magnitude < 1e-4 then return ZERO end
	lateral = lateral.Unit
	return lateral * (amount * strength)
end

-- Spin vector for the visual ball rotation that matches a curve amount.
function AM.CurveSpin(velocity, amount, rate)
	local dir = AM.SafeUnit(velocity)
	if dir == ZERO then return ZERO end
	return UP * (-amount * rate) + dir * (amount * rate * 0.25)
end

-- Auto curve: how much bend is needed to get round an obstacle that sits
-- between origin and target. blockerPos is the nearest blocking body.
function AM.AutoCurve(origin, target, blockerPos, maxAmount)
	if not blockerPos then return 0 end
	local toT = target - origin
	local flatT = AM.Flat(toT)
	local len = flatT.Magnitude
	if len < 1e-3 then return 0 end
	local dir = flatT / len
	local toB = AM.Flat(blockerPos - origin)
	local along = toB:Dot(dir)
	if along <= 0 or along >= len then return 0 end
	local lateral = toB - dir * along
	local side = dir:Cross(UP):Dot(lateral)
	local dist = lateral.Magnitude
	if dist > 12 then return 0 end
	local need = (12 - dist) / 12
	local sign = 1
	if side > 0 then sign = -1 end
	return AM.Clamp(sign * need, -maxAmount, maxAmount)
end

-- ── Scatter ──────────────────────────────────────────────────────────
-- Deliberate miss. chancePct in [0,100]. Returns the displaced aim point.
function AM.ApplyMiss(aimPoint, goalCF, goalSize, chancePct, rng)
	if chancePct <= 0 then return aimPoint, false end
	local roll = rng and rng:NextNumber(0, 100) or math.random() * 100
	if roll > chancePct then return aimPoint, false end
	local l = goalCF:PointToObjectSpace(aimPoint)
	local pushX = (goalSize.X * 0.5 + 2.5) * (l.X >= 0 and 1 or -1)
	local pushY = goalSize.Y * 0.5 + 2.0
	local pick = rng and rng:NextInteger(1, 2) or math.random(1, 2)
	local out
	if pick == 1 then
		out = Vector3.new(pushX, l.Y, l.Z)
	else
		out = Vector3.new(l.X, pushY, l.Z)
	end
	return goalCF:PointToWorldSpace(out), true
end

-- ── Smoothing ────────────────────────────────────────────────────────
-- Framerate independent exponential smoothing toward a target CFrame.
function AM.SmoothCFrame(current, target, speed, dt)
	local alpha = 1 - math.exp(-math.max(speed, 0.0001) * 60 * dt / 60)
	alpha = AM.Clamp(alpha, 0, 1)
	return current:Lerp(target, alpha)
end

function AM.SmoothNumber(current, target, speed, dt)
	local alpha = AM.Clamp(1 - math.exp(-math.max(speed, 0.0001) * dt * 60 / 60), 0, 1)
	return current + (target - current) * alpha
end

-- ── Latency adaptation ───────────────────────────────────────────────
-- Extra reach radius earned by ping, capped. perMs is studs per ms.
function AM.AdaptRadius(baseRadius, pingMs, perMs, cap)
	local extra = AM.Clamp(pingMs * perMs, 0, cap)
	return baseRadius + extra
end

-- Where a body will be after one round trip of latency.
function AM.LatencyLead(pos, vel, pingMs)
	return pos + vel * (pingMs / 1000)
end

-- ── Screen helpers (need a camera, so they take one) ─────────────────
-- Returns Vector2, onScreen, depth. Handles points behind the camera.
function AM.WorldToScreen(camera, worldPos)
	local vec, onScreen = camera:WorldToViewportPoint(worldPos)
	return Vector2.new(vec.X, vec.Y), onScreen and vec.Z > 0, vec.Z
end

function AM.InFov(camera, worldPos, fovDeg)
	if fovDeg <= 0 then return true, 0 end
	local screen, visible = AM.WorldToScreen(camera, worldPos)
	if not visible then return false, math.huge end
	local vp = camera.ViewportSize
	local centre = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	local px = (screen - centre).Magnitude
	local radiusPx = (fovDeg / math.max(camera.FieldOfView, 1)) * vp.Y * 0.5
	return px <= radiusPx, px
end

return AM
