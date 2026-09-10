-- d-tPoints.lua

local TPM = {}

gPlayerSyncTable[0].totalPoints = 0

local SECRET = 0x2A4B6C8D
local CHECK = 0x7F1E3D5A
local FILE = "points.bin"

local function save_points()
	local modFs = mod_fs_get() or mod_fs_create()
	local file = modFs:get_file(FILE) or modFs:create_file(FILE, false)

	file:erase(file.size)
	file:rewind()

	local points = gPlayerSyncTable[0].totalPoints
	local obfuscated = points ~ SECRET
	local checksum = (points + CHECK) ~ SECRET

	file:write_integer(obfuscated, INT_TYPE_S32)
	file:write_integer(checksum, INT_TYPE_S32)

	modFs:save()
end

function TPM.load_points()
	local modFs = mod_fs_get() or mod_fs_create()
	local file = modFs:get_file(FILE) or modFs:create_file(FILE, false)

	file:rewind()

	if not file:is_eof() then
		local val1 = file:read_integer(INT_TYPE_S32)
		local val2 = nil

		if not file:is_eof() then
			val2 = file:read_integer(INT_TYPE_S32)
		end

		if val2 == nil then
			gPlayerSyncTable[0].totalPoints = val1
			save_points()
		else
			local points = val1 ~ SECRET
			local expectedChecksum = ((points + CHECK) % 0x7FFFFFFF) ~ SECRET

			if val2 == expectedChecksum then
				gPlayerSyncTable[0].totalPoints = points

				print("Loaded total points:", gPlayerSyncTable[0].totalPoints)
			else
				gPlayerSyncTable[0].totalPoints = 0
				save_points()
			end
		end
	else
		gPlayerSyncTable[0].totalPoints = 0
	end
end

function TPM.add_points(amount)
	gPlayerSyncTable[0].totalPoints = (gPlayerSyncTable[0].totalPoints or 0) + (amount or 1)

	print("Added points, total:", gPlayerSyncTable[0].totalPoints)

	save_points()
end

function TPM.reset_points()
	gPlayerSyncTable[0].totalPoints = 0
	save_points()
end

return TPM
