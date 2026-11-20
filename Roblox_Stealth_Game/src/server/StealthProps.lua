-- StealthProps (ModuleScript, goes in ServerScriptService next to StealthServer)
-- Builds the furniture and scenery for a level out of detailed parts: crate stacks,
-- bookshelves, server racks, sofas, desks, plants, lamps and the city around the building.
-- None of these parts collide. StealthServer adds one invisible box per prop for that.

local Props = {}

local rng = Random.new(7)

local function rgb(r, g, b)
	return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
end

-- ctx.at(x, z, y) turns level coordinates into a world position. ctx.decor is where parts go.
local function part(ctx, size, x, y, z, color, material, extra)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Position = ctx.at(x, z, y)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if size.X < 0.6 or size.Y < 0.3 or size.Z < 0.6 then
		p.CastShadow = false
	end
	for k, v in pairs(extra or {}) do
		p[k] = v
	end
	p.Parent = ctx.decor
	return p
end

-- an upright cylinder
local function cyl(ctx, diameter, height, x, y, z, color, material, extra)
	local p = part(ctx, Vector3.new(height, diameter, diameter), x, y, z, color, material, extra)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function ball(ctx, diameter, x, y, z, color, material, extra)
	local p = part(ctx, Vector3.new(diameter, diameter, diameter), x, y, z, color, material, extra)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Lets a builder think in "along the long side" (u) and "across" (v) no matter which way the prop faces.
local function orient(x, z, sx, sz, flip)
	local alongX = sx >= sz
	local o = { len = alongX and sx or sz, wid = alongX and sz or sx }
	local sign = flip and -1 or 1
	function o.pos(u, v)
		v = v * sign
		if alongX then
			return x + u, z + v
		end
		return x + v, z + u
	end
	function o.size(lu, h, lv)
		if alongX then
			return Vector3.new(lu, h, lv)
		end
		return Vector3.new(lv, h, lu)
	end
	return o
end

local WOOD_DARK = rgb(58, 40, 30)
local WOOD = rgb(112, 80, 54)
local METAL_DARK = rgb(34, 36, 42)
local MARBLE = rgb(206, 202, 196)

---------------------------------------------------------------------------
-- Tall props (these block a guard's view)
---------------------------------------------------------------------------
local tall = {}

function tall.crates(ctx, x, z, sx, sz)
	local nx = math.max(1, math.floor(sx / 3 + 0.5))
	local nz = math.max(1, math.floor(sz / 3 + 0.5))
	local cx, cz = sx / nx, sz / nz
	for i = 1, nx do
		for j = 1, nz do
			local px = x - sx / 2 + cx * (i - 0.5)
			local pz = z - sz / 2 + cz * (j - 0.5)
			local tone = rng:NextNumber(0.82, 1.08)
			local wood = rgb(124 * tone, 90 * tone, 58 * tone)
			part(ctx, Vector3.new(cx - 0.2, 3, cz - 0.2), px, 1.5, pz, wood, Enum.Material.WoodPlanks)
			part(ctx, Vector3.new(cx - 0.1, 0.25, cz - 0.1), px, 0.3, pz, WOOD_DARK, Enum.Material.Wood)
			part(ctx, Vector3.new(cx - 0.1, 0.25, cz - 0.1), px, 2.75, pz, WOOD_DARK, Enum.Material.Wood)
			local s = rng:NextNumber(0.72, 0.94)
			local tone2 = rng:NextNumber(0.8, 1.05)
			local w2, d2 = (cx - 0.2) * s, (cz - 0.2) * s
			part(ctx, Vector3.new(w2, 2.6, d2), px, 4.3, pz, rgb(132 * tone2, 98 * tone2, 64 * tone2),
				Enum.Material.WoodPlanks)
			part(ctx, Vector3.new(w2 + 0.1, 0.2, d2 + 0.1), px, 5.5, pz, WOOD_DARK, Enum.Material.Wood)
			-- stencil mark on the lid
			part(ctx, Vector3.new(w2 * 0.5, 0.04, d2 * 0.18), px, 5.62, pz, rgb(200, 60, 50), Enum.Material.SmoothPlastic)
		end
	end
end

function tall.pillar(ctx, x, z, sx, sz)
	part(ctx, Vector3.new(sx + 0.3, 0.5, sz + 0.3), x, 0.25, z, rgb(60, 60, 66), Enum.Material.Marble)
	part(ctx, Vector3.new(sx - 0.5, 6.2, sz - 0.5), x, 3.6, z, MARBLE, Enum.Material.Marble)
	part(ctx, Vector3.new(sx + 0.3, 0.4, sz + 0.3), x, 6.9, z, rgb(60, 60, 66), Enum.Material.Marble)
	part(ctx, Vector3.new(sx - 0.3, 0.12, sz - 0.3), x, 0.9, z, rgb(214, 170, 90), Enum.Material.Metal)
end

function tall.reception(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	local px, pz = o.pos(0, o.wid * 0.2)
	part(ctx, o.size(o.len, 3.3, o.wid * 0.6), px, 1.65, pz, WOOD_DARK, Enum.Material.Wood)
	part(ctx, o.size(o.len + 0.3, 0.2, o.wid * 0.6 + 0.3), px, 3.4, pz, MARBLE, Enum.Material.Marble)
	local nx, nz = o.pos(0, o.wid * 0.5 + 0.03)
	part(ctx, o.size(o.len - 1, 0.12, 0.1), nx, 2.2, nz, rgb(255, 190, 110), Enum.Material.Neon)
	-- tall backdrop with a glowing logo bar
	local bx, bz = o.pos(0, -o.wid * 0.35)
	part(ctx, o.size(o.len, 5.8, o.wid * 0.25), bx, 2.9, bz, rgb(28, 30, 38), Enum.Material.SmoothPlastic)
	part(ctx, o.size(o.len * 0.5, 0.5, o.wid * 0.25 + 0.08), bx, 4.6, bz, rgb(255, 80, 80), Enum.Material.Neon)
	part(ctx, o.size(o.len + 0.2, 0.15, o.wid * 0.25 + 0.2), bx, 5.85, bz, rgb(214, 170, 90), Enum.Material.Metal)
	-- monitors on the desk
	for _, u in ipairs({ -o.len * 0.25, o.len * 0.25 }) do
		local mx, mz = o.pos(u, o.wid * 0.15)
		part(ctx, o.size(1.6, 1, 0.12), mx, 4.1, mz, METAL_DARK, Enum.Material.SmoothPlastic)
		part(ctx, o.size(1.4, 0.8, 0.14), mx, 4.1, mz, rgb(90, 190, 255), Enum.Material.Neon)
	end
end

function tall.planter(ctx, x, z, sx, sz)
	part(ctx, Vector3.new(sx, 1.6, sz), x, 0.8, z, rgb(52, 54, 60), Enum.Material.Concrete)
	part(ctx, Vector3.new(sx + 0.2, 0.2, sz + 0.2), x, 1.6, z, rgb(36, 38, 44), Enum.Material.Concrete)
	part(ctx, Vector3.new(sx - 0.4, 0.15, sz - 0.4), x, 1.68, z, rgb(44, 32, 24), Enum.Material.Ground)
	local o = orient(x, z, sx, sz)
	local count = math.max(2, math.floor(o.len / 1.6))
	for i = 1, count do
		local u = -o.len / 2 + o.len * (i - 0.5) / count
		local px, pz = o.pos(u, rng:NextNumber(-0.2, 0.2))
		local height = rng:NextNumber(4.6, 6.2)
		cyl(ctx, 0.22, height - 1.6, px, 1.6 + (height - 1.6) / 2, pz, rgb(70, 52, 36), Enum.Material.Wood)
		for _ = 1, 3 do
			local g = rng:NextNumber(0.75, 1.15)
			ball(ctx, rng:NextNumber(1.5, 2.3), px + rng:NextNumber(-0.5, 0.5), height - rng:NextNumber(0, 1.6),
				pz + rng:NextNumber(-0.4, 0.4), rgb(40 * g, 104 * g, 58 * g), Enum.Material.Grass)
		end
	end
end

function tall.servers(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	local count = math.max(1, math.floor(o.len / 2.5 + 0.5))
	local w = o.len / count
	for i = 1, count do
		local u = -o.len / 2 + w * (i - 0.5)
		local px, pz = o.pos(u, 0)
		part(ctx, o.size(w - 0.15, 5.7, o.wid), px, 2.85, pz, rgb(26, 28, 34), Enum.Material.Metal)
		part(ctx, o.size(w - 0.5, 0.08, o.wid - 0.5), px, 5.74, pz, rgb(14, 15, 18), Enum.Material.DiamondPlate)
		for side = -1, 1, 2 do
			local fx, fz = o.pos(u, side * (o.wid / 2 + 0.03))
			part(ctx, o.size(w - 0.5, 4.8, 0.06), fx, 2.9, fz, rgb(12, 13, 16), Enum.Material.SmoothPlastic)
			for row = 1, 5 do
				local led = (rng:NextNumber() < 0.25) and rgb(255, 170, 40) or rgb(60, 255, 130)
				local lx, lz = o.pos(u + rng:NextNumber(-w * 0.25, w * 0.25), side * (o.wid / 2 + 0.07))
				part(ctx, o.size(0.5, 0.1, 0.05), lx, 0.9 + row * 0.8, lz, led, Enum.Material.Neon)
			end
		end
		local tx, tz = o.pos(u, 0)
		part(ctx, o.size(0.4, 0.05, 0.4), tx, 5.8, tz, rgb(60, 255, 130), Enum.Material.Neon)
	end
end

function tall.lockers(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	local count = math.max(2, math.floor(o.len / 1.5 + 0.5))
	local w = o.len / count
	for i = 1, count do
		local u = -o.len / 2 + w * (i - 0.5)
		local px, pz = o.pos(u, 0)
		part(ctx, o.size(w - 0.08, 5.7, o.wid), px, 2.85, pz, rgb(64, 84, 104), Enum.Material.Metal)
		for side = -1, 1, 2 do
			local hx, hz = o.pos(u + w * 0.25, side * (o.wid / 2 + 0.04))
			part(ctx, o.size(0.12, 0.5, 0.06), hx, 3, hz, rgb(190, 195, 205), Enum.Material.Metal)
			local vx, vz = o.pos(u, side * (o.wid / 2 + 0.03))
			part(ctx, o.size(w * 0.6, 0.5, 0.05), vx, 4.8, vz, rgb(40, 54, 70), Enum.Material.Metal)
		end
	end
	part(ctx, Vector3.new(sx + 0.1, 0.12, sz + 0.1), x, 5.76, z, rgb(44, 60, 76), Enum.Material.Metal)
end

function tall.bar(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	-- back shelf (tall) with bottles, counter in front
	local bx, bz = o.pos(0, -o.wid * 0.3)
	part(ctx, o.size(o.len, 5.7, o.wid * 0.38), bx, 2.85, bz, WOOD_DARK, Enum.Material.Wood)
	part(ctx, o.size(o.len - 0.4, 0.1, o.wid * 0.38 + 0.1), bx, 4.2, bz, rgb(255, 170, 90), Enum.Material.Neon)
	local bottles = { rgb(90, 200, 120), rgb(230, 170, 70), rgb(120, 170, 240), rgb(220, 90, 90), rgb(240, 240, 230) }
	local count = math.floor(o.len / 0.9)
	for i = 1, count do
		local u = -o.len / 2 + o.len * (i - 0.5) / count
		local px, pz = o.pos(u, -o.wid * 0.3)
		local c = bottles[rng:NextInteger(1, #bottles)]
		local h = rng:NextNumber(0.7, 1.1)
		cyl(ctx, 0.32, h, px, 5.7 + h / 2, pz, c, Enum.Material.Glass, { Transparency = 0.25 })
	end
	local cx, cz = o.pos(0, o.wid * 0.22)
	part(ctx, o.size(o.len, 3.3, o.wid * 0.5), cx, 1.65, cz, rgb(74, 52, 38), Enum.Material.Wood)
	part(ctx, o.size(o.len + 0.3, 0.2, o.wid * 0.5 + 0.3), cx, 3.4, cz, rgb(30, 30, 34), Enum.Material.Marble,
		{ Reflectance = 0.15 })
	local rx, rz = o.pos(0, o.wid * 0.5)
	part(ctx, o.size(o.len, 0.1, 0.08), rx, 0.5, rz, rgb(214, 170, 90), Enum.Material.Metal)
end

function tall.screen(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	local slats = math.floor(o.len / 0.7)
	for i = 1, slats do
		local u = -o.len / 2 + o.len * (i - 0.5) / slats
		local px, pz = o.pos(u, 0)
		part(ctx, o.size(0.28, 5.4, o.wid * 0.5), px, 2.9, pz, WOOD, Enum.Material.Wood)
	end
	part(ctx, o.size(o.len, 0.25, o.wid * 0.7), x, 0.2, z, WOOD_DARK, Enum.Material.Wood)
	part(ctx, o.size(o.len, 0.25, o.wid * 0.7), x, 5.6, z, WOOD_DARK, Enum.Material.Wood)
end

function tall.bookshelf(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	part(ctx, o.size(o.len, 5.7, o.wid), x, 2.85, z, WOOD_DARK, Enum.Material.Wood)
	part(ctx, o.size(o.len + 0.2, 0.15, o.wid + 0.2), x, 5.78, z, rgb(40, 28, 22), Enum.Material.Wood)
	local colors = { rgb(150, 40, 40), rgb(40, 70, 120), rgb(50, 100, 70), rgb(190, 160, 90), rgb(90, 60, 110), rgb(200, 200, 190) }
	for side = -1, 1, 2 do
		for row = 1, 4 do
			local u = -o.len / 2 + 0.3
			while u < o.len / 2 - 0.5 do
				local w = rng:NextNumber(0.25, 0.5)
				local h = rng:NextNumber(0.7, 1)
				local px, pz = o.pos(u + w / 2, side * (o.wid / 2 + 0.02))
				part(ctx, o.size(w - 0.04, h, 0.12), px, 0.45 + (row - 1) * 1.3 + h / 2, pz,
					colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic)
				u = u + w
				if rng:NextNumber() < 0.12 then
					u = u + 0.5 -- a gap on the shelf
				end
			end
		end
	end
end

function tall.cabinet(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	local count = math.max(2, math.floor(o.len / 2 + 0.5))
	local w = o.len / count
	for i = 1, count do
		local u = -o.len / 2 + w * (i - 0.5)
		local px, pz = o.pos(u, 0)
		part(ctx, o.size(w - 0.1, 5.7, o.wid), px, 2.85, pz, rgb(92, 96, 104), Enum.Material.Metal)
		for side = -1, 1, 2 do
			for row = 1, 4 do
				local hx, hz = o.pos(u, side * (o.wid / 2 + 0.04))
				part(ctx, o.size(w * 0.5, 0.12, 0.06), hx, row * 1.3, hz, rgb(200, 204, 212), Enum.Material.Metal)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Low props (you can't walk through them, but guards see over them)
---------------------------------------------------------------------------
local low = {}

function low.desk(ctx, x, z, sx, sz, flip)
	local o = orient(x, z, sx, sz, flip)
	part(ctx, o.size(o.len, 0.25, o.wid), x, 2.75, z, rgb(66, 44, 32), Enum.Material.Wood, { Reflectance = 0.08 })
	for _, u in ipairs({ -o.len / 2 + 1.1, o.len / 2 - 1.1 }) do
		local px, pz = o.pos(u, 0)
		part(ctx, o.size(1.8, 2.6, o.wid - 0.4), px, 1.3, pz, WOOD_DARK, Enum.Material.Wood)
	end
	-- laptop, papers, desk lamp
	local lx, lz = o.pos(0, 0.2)
	part(ctx, o.size(1.4, 0.06, 0.9), lx, 2.92, lz, METAL_DARK, Enum.Material.Metal)
	local sxp, szp = o.pos(0, -0.3)
	part(ctx, o.size(1.4, 0.9, 0.06), sxp, 3.35, szp, rgb(120, 200, 255), Enum.Material.Neon)
	local px, pz = o.pos(-o.len * 0.28, 0.1)
	part(ctx, o.size(0.9, 0.03, 1.2), px, 2.9, pz, rgb(235, 232, 220), Enum.Material.SmoothPlastic)
	local dx, dz = o.pos(o.len * 0.32, -0.3)
	cyl(ctx, 0.5, 0.1, dx, 2.92, dz, METAL_DARK, Enum.Material.Metal)
	cyl(ctx, 0.1, 0.9, dx, 3.35, dz, METAL_DARK, Enum.Material.Metal)
	cyl(ctx, 0.6, 0.3, dx, 3.9, dz, rgb(255, 214, 150), Enum.Material.Neon)
	-- chair behind the desk
	local cx, cz = o.pos(0, o.wid / 2 + 1.3)
	part(ctx, o.size(1.8, 0.3, 1.8), cx, 1.7, cz, rgb(30, 30, 34), Enum.Material.Fabric)
	local bx, bz = o.pos(0, o.wid / 2 + 2.1)
	part(ctx, o.size(1.8, 2.4, 0.3), bx, 2.8, bz, rgb(30, 30, 34), Enum.Material.Fabric)
	cyl(ctx, 0.3, 1.5, cx, 0.8, cz, METAL_DARK, Enum.Material.Metal)
end

function low.sofa(ctx, x, z, sx, sz, flip)
	local o = orient(x, z, sx, sz, flip)
	local fabric = rgb(86, 34, 40)
	part(ctx, o.size(o.len, 1.2, o.wid), x, 0.7, z, rgb(40, 22, 24), Enum.Material.Fabric)
	local bx, bz = o.pos(0, -o.wid / 2 + 0.35)
	part(ctx, o.size(o.len, 1.8, 0.7), bx, 2.1, bz, fabric, Enum.Material.Fabric)
	for _, u in ipairs({ -o.len / 2 + 0.35, o.len / 2 - 0.35 }) do
		local ax, az = o.pos(u, 0)
		part(ctx, o.size(0.7, 1, o.wid), ax, 1.7, az, fabric, Enum.Material.Fabric)
	end
	local seats = math.max(2, math.floor((o.len - 1.4) / 2.2 + 0.5))
	local w = (o.len - 1.4) / seats
	for i = 1, seats do
		local u = -(o.len - 1.4) / 2 + w * (i - 0.5)
		local cx, cz = o.pos(u, 0.3)
		part(ctx, o.size(w - 0.12, 0.45, o.wid - 0.9), cx, 1.5, cz, rgb(104, 42, 48), Enum.Material.Fabric)
	end
end

function low.table(ctx, x, z, sx, sz)
	part(ctx, Vector3.new(sx, 0.2, sz), x, 1.5, z, rgb(24, 24, 28), Enum.Material.Glass, { Reflectance = 0.2 })
	part(ctx, Vector3.new(sx - 0.8, 1.3, sz - 0.8), x, 0.75, z, WOOD_DARK, Enum.Material.Wood)
	cyl(ctx, 0.5, 0.5, x - sx * 0.2, 1.85, z, rgb(214, 170, 90), Enum.Material.Metal)
	part(ctx, Vector3.new(1, 0.08, 0.7), x + sx * 0.2, 1.64, z + 0.2, rgb(150, 40, 40), Enum.Material.SmoothPlastic)
end

function low.bench(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	part(ctx, o.size(o.len, 0.4, o.wid), x, 1.5, z, rgb(40, 40, 46), Enum.Material.Fabric)
	for _, u in ipairs({ -o.len / 2 + 0.5, o.len / 2 - 0.5 }) do
		local px, pz = o.pos(u, 0)
		part(ctx, o.size(0.3, 1.3, o.wid - 0.4), px, 0.65, pz, rgb(214, 170, 90), Enum.Material.Metal)
	end
end

function low.pallet(ctx, x, z, sx, sz)
	part(ctx, Vector3.new(sx, 0.4, sz), x, 0.2, z, WOOD, Enum.Material.WoodPlanks)
	for i = -1, 1 do
		local tone = rng:NextNumber(0.85, 1.1)
		part(ctx, Vector3.new(sx * 0.28, 1.6, sz * 0.8), x + i * sx * 0.31, 1.2, z,
			rgb(150 * tone, 130 * tone, 96 * tone), Enum.Material.Fabric)
	end
	part(ctx, Vector3.new(sx * 0.9, 0.1, 0.25), x, 2.05, z, rgb(30, 30, 30), Enum.Material.Fabric)
end

function low.console(ctx, x, z, sx, sz, flip)
	local o = orient(x, z, sx, sz, flip)
	part(ctx, o.size(o.len, 2.5, o.wid), x, 1.25, z, rgb(34, 36, 44), Enum.Material.Metal)
	part(ctx, o.size(o.len + 0.2, 0.15, o.wid + 0.2), x, 2.55, z, rgb(20, 21, 26), Enum.Material.SmoothPlastic)
	local count = math.max(2, math.floor(o.len / 2.4))
	for i = 1, count do
		local u = -o.len / 2 + o.len * (i - 0.5) / count
		local px, pz = o.pos(u, -o.wid * 0.25)
		part(ctx, o.size(1.9, 1.3, 0.12), px, 3.4, pz, METAL_DARK, Enum.Material.SmoothPlastic)
		local tint = (i % 2 == 0) and rgb(90, 255, 160) or rgb(90, 190, 255)
		part(ctx, o.size(1.7, 1.1, 0.14), px, 3.4, pz, tint, Enum.Material.Neon)
		local kx, kz = o.pos(u, o.wid * 0.2)
		part(ctx, o.size(1.3, 0.06, 0.5), kx, 2.66, kz, rgb(12, 12, 14), Enum.Material.SmoothPlastic)
	end
end

function low.lounger(ctx, x, z, sx, sz)
	local o = orient(x, z, sx, sz)
	part(ctx, o.size(o.len, 0.4, o.wid), x, 1, z, rgb(226, 222, 212), Enum.Material.Fabric)
	local hx, hz = o.pos(-o.len / 2 + 0.9, 0)
	part(ctx, o.size(1.8, 0.4, o.wid), hx, 1.6, hz, rgb(226, 222, 212), Enum.Material.Fabric)
	part(ctx, o.size(o.len - 0.4, 0.8, o.wid - 0.4), x, 0.4, z, WOOD_DARK, Enum.Material.Wood)
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function Props.buildTall(ctx, kind, x, z, sx, sz, flip)
	local builder = tall[kind] or tall.crates
	builder(ctx, x, z, sx, sz, flip)
end

function Props.buildLow(ctx, kind, x, z, sx, sz, flip)
	local builder = low[kind] or low.table
	builder(ctx, x, z, sx, sz, flip)
end

-- A floor lamp. Returns the glowing shade and its light so the server can switch it off.
function Props.lamp(ctx, x, z, radius)
	cyl(ctx, 1.6, 0.2, x, 0.1, z, METAL_DARK, Enum.Material.Metal)
	cyl(ctx, 0.22, 6, x, 3.1, z, rgb(214, 170, 90), Enum.Material.Metal)
	local shade = cyl(ctx, 2.1, 1.3, x, 6.6, z, rgb(255, 214, 150), Enum.Material.Neon)
	cyl(ctx, 2.25, 0.12, x, 7.3, z, METAL_DARK, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Range = radius + 6
	light.Brightness = 1.7
	light.Color = rgb(255, 214, 150)
	light.Shadows = true
	light.Parent = shade
	return shade, light
end

function Props.fuseBox(ctx, x, z)
	part(ctx, Vector3.new(1.1, 4.2, 3.2), x, 3, z, rgb(210, 172, 40), Enum.Material.Metal)
	part(ctx, Vector3.new(0.1, 3.4, 2.4), x - 0.6, 3, z, rgb(60, 60, 64), Enum.Material.Metal)
	for i = -1, 1 do
		part(ctx, Vector3.new(0.12, 0.3, 2.4), x - 0.62, 3 + i * 1.2, z, rgb(20, 20, 20), Enum.Material.SmoothPlastic)
	end
	local lamp = part(ctx, Vector3.new(0.15, 0.3, 0.3), x - 0.66, 4.7, z + 0.8, rgb(90, 255, 120), Enum.Material.Neon)
	cyl(ctx, 0.3, 2.4, x, 6.2, z, rgb(80, 82, 88), Enum.Material.Metal)
	return lamp
end

-- Dark towers with lit windows around and below the penthouse, so the edges of the map aren't empty.
function Props.skyline(ctx, halfWidth, halfDepth)
	part(ctx, Vector3.new(900, 2, 800), 0, -160, 0, rgb(8, 9, 14), Enum.Material.Asphalt)
	for i = -3, 3 do
		part(ctx, Vector3.new(900, 0.3, 3), 0, -158.8, i * 90, rgb(255, 160, 70), Enum.Material.Neon, { Transparency = 0.3 })
		part(ctx, Vector3.new(3, 0.3, 800), i * 110, -158.8, 0, rgb(255, 160, 70), Enum.Material.Neon, { Transparency = 0.3 })
	end
	local built = 0
	local tries = 0
	while built < 64 and tries < 400 do
		tries = tries + 1
		local x = rng:NextNumber(-300, 300)
		local z = rng:NextNumber(-260, 260)
		if math.abs(x) > halfWidth + 24 or math.abs(z) > halfDepth + 24 then
			built = built + 1
			local w = rng:NextNumber(26, 54)
			local d = rng:NextNumber(26, 54)
			local top = -rng:NextNumber(10, 90)
			local height = 160 + top
			local tone = rng:NextNumber(0.8, 1.3)
			part(ctx, Vector3.new(w, height, d), x, top - height / 2, z, rgb(20 * tone, 22 * tone, 30 * tone),
				Enum.Material.Concrete)
			-- roof details you see from above
			part(ctx, Vector3.new(w - 3, 0.6, d - 3), x, top + 0.3, z, rgb(14, 15, 20), Enum.Material.Concrete)
			part(ctx, Vector3.new(w * 0.25, 3, d * 0.2), x + w * 0.2, top + 1.5, z - d * 0.2, rgb(40, 42, 50), Enum.Material.Metal)
			if rng:NextNumber() < 0.5 then
				local glow = (rng:NextNumber() < 0.5) and rgb(255, 70, 90) or rgb(80, 200, 255)
				part(ctx, Vector3.new(w * 0.5, 0.3, 0.6), x - w * 0.1, top + 0.8, z + d * 0.3, glow, Enum.Material.Neon)
			end
			if rng:NextNumber() < 0.4 then
				ball(ctx, 1.2, x - w * 0.4, top + 4, z - d * 0.4, rgb(255, 40, 40), Enum.Material.Neon)
			end
			-- window bands on the side facing the camera
			for band = 1, 3 do
				local warm = rng:NextNumber() < 0.7
				part(ctx, Vector3.new(w * rng:NextNumber(0.4, 0.85), 1.2, 0.3), x, top - band * rng:NextNumber(7, 11), z + d / 2,
					warm and rgb(255, 206, 130) or rgb(140, 200, 255), Enum.Material.Neon, { Transparency = 0.2 })
			end
		end
	end
end

return Props
