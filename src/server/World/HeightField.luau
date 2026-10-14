--!strict
-- HeightField: builds WorldIndex's floor height field (docs/09, section 9.1) with one downward
-- ray per 8-stud cell against the `World` parts of the collision shell: 65,536 rays, spread over
-- the first 2 s after start so no frame carries more than a few rows. The layout and sampling
-- are HeightFieldMath's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HeightFieldMath = require(ReplicatedStorage.Shared.Logic.HeightFieldMath)

local HeightField = {}

HeightField.BUILD_SECONDS = 2

export type Field = {
	data: buffer,
	rowsDone: number, -- rows 0 to rowsDone - 1 are built
	ready: boolean,
	params: RaycastParams,
}

local SIZE = HeightFieldMath.SIZE

function HeightField.new(params: RaycastParams): Field
	return { data = HeightFieldMath.new(), rowsDone = 0, ready = false, params = params }
end

--- The floor height under a point by one ray: the highest `World` surface, or the map floor.
function HeightField.cast(params: RaycastParams, x: number, z: number): number
	local top = HeightFieldMath.rayTop()
	local result = workspace:Raycast(
		Vector3.new(x, top, z),
		Vector3.new(0, -HeightFieldMath.rayLength(), 0),
		params
	)
	return if result then result.Position.Y else HeightFieldMath.Y_MIN
end

--- Casts the rays of the next rows, up to (not including) row `untilRow`.
function HeightField.buildRows(field: Field, untilRow: number)
	local target = math.min(untilRow, SIZE)
	local cast, centre, set = HeightField.cast, HeightFieldMath.cellCentre, HeightFieldMath.set
	for iz = field.rowsDone, target - 1 do
		local z = centre(iz)
		for ix = 0, SIZE - 1 do
			set(field.data, ix, iz, cast(field.params, centre(ix), z))
		end
	end
	field.rowsDone = math.max(field.rowsDone, target)
	field.ready = field.rowsDone >= SIZE
end

--- Builds the field over `BUILD_SECONDS`, a share of the rows each Heartbeat. Does not yield.
function HeightField.buildOverTime(field: Field, onDone: (() -> ())?)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		debug.profilebegin("HeightField")
		local share = (os.clock() - started) / HeightField.BUILD_SECONDS
		HeightField.buildRows(field, math.max(field.rowsDone + 1, math.ceil(share * SIZE)))
		debug.profileend()
		if field.ready then
			connection:Disconnect()
			if onDone then
				onDone()
			end
		end
	end)
end

--- The floor height at X and Z: from the field once built, else by one ray.
function HeightField.floorY(field: Field, x: number, z: number): number
	if field.ready then
		return HeightFieldMath.sample(field.data, x, z)
	end
	return HeightField.cast(field.params, x, z)
end

return HeightField
