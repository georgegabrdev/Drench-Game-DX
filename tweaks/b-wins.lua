-- b-wins.lua

local WI = {}

gPlayerSyncTable[0].gameWins = 0

local SECRET = 0x2A4B6C8D
local CHECK = 0x7F1E3D5A
local FILE = "wins.bin"

local function save_wins()
	local modFs = mod_fs_get() or mod_fs_create()
	local file = modFs:get_file(FILE) or modFs:create_file(FILE, false)

	file:erase(file.size)
	file:rewind()

	local wins = gPlayerSyncTable[0].gameWins

	local obfuscated = wins ~ SECRET
	local checksum = (wins + CHECK) ~ SECRET

	file:write_integer(obfuscated, INT_TYPE_S32)
	file:write_integer(checksum, INT_TYPE_S32)

	modFs:save()
end

function WI.load_wins()
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
			gPlayerSyncTable[0].gameWins = val1
			save_wins()
		else
			local wins = val1 ~ SECRET
			local expectedChecksum = ((wins + CHECK) % 0x7FFFFFFF) ~ SECRET

			if val2 == expectedChecksum then
				gPlayerSyncTable[0].gameWins = wins
				print("Loaded wins:", gPlayerSyncTable[0].gameWins)
			else
				gPlayerSyncTable[0].gameWins = 0
				save_wins()
			end
		end
	else
		gPlayerSyncTable[0].gameWins = 0
	end
end

function WI.add_win()
	gPlayerSyncTable[0].gameWins = (gPlayerSyncTable[0].gameWins or 0) + 1
	print("Added win, total wins:", gPlayerSyncTable[0].gameWins)

	save_wins()
end

function WI.reset_wins()
	gPlayerSyncTable[0].gameWins = 0
	save_wins()
end

return WI
