--!strict
-- S11, Lune half: lune run spike/tests/s11.luau
local TierMath = require("../src/shared/Logic/TierMath")
local SwimModel = require("../src/shared/Logic/SwimModel")

local scale8 = TierMath.bodyScale(8)
assert(math.abs(scale8 - 1.24) < 1e-9, "bodyScale(8) should be 1.24, got " .. scale8)
assert(TierMath.tier(250) == 5, "tier(250) should be 5")
assert(TierMath.bodyScale(99999) == 6.5, "tier 7 scale is 6.5")
local s = SwimModel.new()
for _ = 1, 120 do
	SwimModel.step(s, { x = 1, y = 0, z = 0, throttle = 1 }, 1, 1 / 60)
end
assert(math.abs(s.vx - 26) < 0.1, "tier 1 reaches 26 studs/s, got " .. s.vx)
print(`S11 lune ok: bodyScale(8)={scale8} tier(250)={TierMath.tier(250)} vx={s.vx}`)
local okPack, pack = pcall(function()
	return (require("../src/shared/Pack") :: any).value
end)
print(`S11 lune init.luau + @self: ok={okPack} value={pack}`)
