local HU = require("../hud-utils")

local M = {}

local real_djui_attempting_to_open = djui_attempting_to_open_playerlist

_G.djui_attempting_to_open_playerlist = function()
	return false
end

local function get_player_location(i)
	local np = gNetworkPlayers[i]

	if not np then
		return translate("unknown")
	end

	local location = get_level_name(np.currCourseNum, np.currLevelNum, np.currAreaIndex)

	return location or translate("unknown")
end

local function remove_color(text, get_color)
	local start = text:find("\\")
	local next = 1

	while (next ~= nil) and (start ~= nil) do
		start = text:find("\\")

		if start ~= nil then
			next = text:find("\\", start + 1)

			if next == nil then
				next = text:len() + 1
			end

			if get_color then
				local color = text:sub(start, next)
				local render = text:sub(1, start - 1)

				text = text:sub(next + 1)

				return text, color, render
			else
				text = text:sub(1, start - 1) .. text:sub(next + 1)
			end
		end
	end

	return text
end

local MAX_MODS_DISPLAY = 8

local function truncate_to_width(text, scale, maxW)
	if djui_hud_measure_text(text) * scale <= maxW then
		return text
	end

	local safe = ""
	local inSlash = false
	local currentW = 0

	for c = 1, #text do
		local char = text:sub(c, c)

		if char == "\\" then
			inSlash = not inSlash
			safe = safe .. char
		elseif inSlash then
			safe = safe .. char
		else
			local charW = djui_hud_measure_text(char) * scale

			if currentW + charW > maxW then
				break
			end

			currentW = currentW + charW
			safe = safe .. char
		end
	end

	return safe .. "..."
end

local function get_active_mods_list()
	if not gActiveMods or type(gActiveMods) ~= "table" then
		return {}, 0
	end

	local nonCSMods = {}
	local csPackCount = 0
	local csIndex = -1
	local modIdx = 0

	while gActiveMods[modIdx] ~= nil do
		local modData = gActiveMods[modIdx]

		if modData and modData.name then
			local rawName = tostring(modData.name)
			local cleanName = rawName
			local isCS = false

			if cleanName:find("^Character Select") then
				isCS = true
			elseif cleanName:find("^%[CS%]") then
				isCS = true
			elseif modData.category == "cs" then
				isCS = true
			end

			if isCS then
				if cleanName == "Character Select" and csIndex == -1 then
					table.insert(nonCSMods, rawName)
					csIndex = #nonCSMods
				else
					csPackCount = csPackCount + 1
				end
			else
				table.insert(nonCSMods, rawName)
			end
		end

		modIdx = modIdx + 1
	end

	if csIndex ~= -1 and csPackCount > 0 then
		nonCSMods[csIndex] = nonCSMods[csIndex] .. " \\#aaaaaa\\(+" .. tostring(csPackCount) .. ")"
	end

	local total = #nonCSMods

	if total == 0 then
		return {}, 0
	end

	if total <= MAX_MODS_DISPLAY then
		return nonCSMods, total
	end

	local capped = {}

	for i = 1, MAX_MODS_DISPLAY do
		capped[i] = nonCSMods[i]
	end

	capped[MAX_MODS_DISPLAY + 1] = "\\#c8c8c8\\+" .. tostring(total - MAX_MODS_DISPLAY) .. translate("more_suffix")

	return capped, total
end

local function get_display_name(i)
	local np = gNetworkPlayers[i]

	if not np then
		return translate("unknown")
	end

	local name = np.name or translate("unknown")

	if name == "Player" then
		name = translate("player_num") .. i
	end

	return name
end

local scoreboardPage = 0

local switchState = 0
local switchTimer = 0
local switchMax = 4

local ListAnim = {
	time = 0,

	speed = 1,

	progress = 0,

	anim = {
		startVal = 0,
		targetVal = 1,

		timeEnter = 10,
		timeStay = 9999,

		timeExit = 10,
	},
}

local pingCache = {}
local pingTimer = 0

local function update_switch_anim()
	if ListAnim.time <= 0 then
		switchState = 0
		switchTimer = 0
		return
	end

	if ListAnim.time >= ListAnim.anim.timeEnter and switchState == 0 then
		if (gControllers[0].buttonPressed & L_TRIG) ~= 0 then
			if scoreboardPage == 0 then
				scoreboardPage = 1
			elseif scoreboardPage == 1 then
				if gActiveMods and gActiveMods[1] then
					scoreboardPage = 2
				else
					scoreboardPage = 0
				end
			else
				scoreboardPage = 0
			end

			switchState = 1
		end
	end

	if switchState == 1 then
		switchTimer = switchTimer + 1

		if switchTimer >= switchMax then
			switchTimer = switchMax
			switchState = 2
		end
	elseif switchState == 2 then
		switchTimer = switchTimer - 1

		if switchTimer <= 0 then
			switchTimer = 0
			switchState = 0
		end
	end
end

function M.render_playerlist()
	gServerSettings.enablePlayerList = 0

	local prevSwitchTimer = switchTimer

	djui_hud_set_font(djui_menu_get_font())

	update_switch_anim()

	local currSwitchTimer = switchTimer

	local switchPrev = prevSwitchTimer / switchMax
	local switchCurr = currSwitchTimer / switchMax

	local switchOffsetPrev = (switchPrev * switchPrev) * 14
	local switchOffsetCurr = (switchCurr * switchCurr) * 14

	local switchAlpha = 1 - switchCurr

	pingTimer = pingTimer + 1

	if pingTimer >= 30 then
		pingTimer = 0

		for i = 0, MAX_PLAYERS - 1 do
			local np = gNetworkPlayers[i]

			if np and np.connected then
				pingCache[i] = np.ping or 0
			end
		end
	end

	local prevTime = ListAnim.time

	ListAnim.prevTime = ListAnim.time

	if real_djui_attempting_to_open() then
		if ListAnim.time < ListAnim.anim.timeEnter then
			ListAnim.time = ListAnim.time + 1
		end
	else
		if ListAnim.time > 0 then
			ListAnim.time = ListAnim.time - 1
		end
	end

	if ListAnim.time <= 0 then
		return
	end

	local tPrev = prevTime / ListAnim.anim.timeEnter
	local tCurr = ListAnim.time / ListAnim.anim.timeEnter

	tPrev = 1 - (1 - tPrev) * (1 - tPrev)
	tCurr = 1 - (1 - tCurr) * (1 - tCurr)

	tPrev = tPrev * tPrev * (3 - 2 * tPrev)
	tCurr = tCurr * tCurr * (3 - 2 * tCurr)

	local opacity = math.floor(255 * tCurr * switchAlpha)

	local screenW = djui_hud_get_screen_width()
	local screenH = djui_hud_get_screen_height()

	local width = screenW * 0.5
	local count = network_player_connected_count()

	local rowSpacing = 28
	local headerHeight = 95
	local bottomPadding = 25

	local modsList, modsTotal = get_active_mods_list()

	local height

	if scoreboardPage == 2 then
		height = 70 + (math.max(#modsList, 1) * rowSpacing) + bottomPadding
	else
		height = headerHeight + (math.max(count, 1) * rowSpacing) + bottomPadding
	end

	local x = (screenW - width) / 2 + 50
	local centerY = screenH / 2

	local yPrev = centerY - (height / 2) - ((1 - tPrev) * 120) + switchOffsetPrev

	local yCurr = centerY - (height / 2) - ((1 - tCurr) * 120) + switchOffsetCurr

	local titleYPrev = yPrev + 15
	local titleYCurr = yCurr + 15

	local headerYPrev = yPrev + 55
	local headerYCurr = yCurr + 55

	local baseYPrev = yPrev + 95
	local baseYCurr = yCurr + 95

	djui_hud_set_color(8, 56, 59, math.floor(200 * tCurr))

	HU.djui_hud_render_rect_rounded_interpolated(
		x,
		yPrev + 5,
		width - 100,
		height,
		x,
		yCurr + 5,
		width - 100,
		height,
		24
	)

	if opacity <= 0 then
		return
	end

	if scoreboardPage ~= 2 then
		djui_hud_set_color(255, 255, 255, opacity)

		local activePlayers = {}

		for i = 0, MAX_PLAYERS - 1 do
			if gNetworkPlayers[i].connected then
				table.insert(activePlayers, i)
			end
		end

		local playerCount = #activePlayers

		local title = translate("players_colon") .. " " .. playerCount .. "/" .. tostring(MAX_PLAYERS)

		djui_hud_print_text_interpolated(title, x + 20, titleYPrev, 1, x + 20, titleYCurr, 1)

		djui_hud_set_color(200, 255, 255, opacity)

		djui_hud_print_text_interpolated(translate("name_header"), x + 55, headerYPrev, 0.7, x + 55, headerYCurr, 0.7)

		djui_hud_print_text_interpolated(
			translate("description_header"),
			x + 250,
			headerYPrev,
			0.7,
			x + 250,
			headerYCurr,
			0.7
		)

		djui_hud_print_text_interpolated(
			translate("location_header"),
			x + width - 480,
			headerYPrev,
			0.7,
			x + width - 480,
			headerYCurr,
			0.7
		)

		djui_hud_print_text_interpolated(translate("ping_header"), x + 350, headerYPrev, 0.7, x + 350, headerYCurr, 0.7)

		local statsHeader

		if scoreboardPage == 0 then
			statsHeader = translate("game_wins_header")
		else
			statsHeader = translate("total_points_header")
		end

		if scoreboardPage == 0 then
			djui_hud_print_text_interpolated(
				statsHeader,
				x + width - 280,
				headerYPrev - 15,
				0.7,
				x + width - 280,
				headerYCurr - 15,
				0.7
			)
		else
			djui_hud_print_text_interpolated(
				statsHeader,
				x + width - 280,
				headerYPrev,
				0.7,
				x + width - 280,
				headerYCurr,
				0.7
			)
		end

		djui_hud_set_color(255, 255, 255, math.floor(100 * tCurr))

		HU.djui_hud_render_rect_rounded_interpolated(
			x + 15,
			yPrev + 80,
			width - 130,
			2,
			x + 15,
			yCurr + 80,
			width - 130,
			2,
			1
		)

		djui_hud_set_color(200, 200, 200, opacity)

		local footer

		if gActiveMods and gActiveMods[1] then
			footer = translate("l_next")
		else
			footer = translate("l_points")
		end

		local fw = djui_hud_measure_text(footer) * 0.6

		djui_hud_print_text_interpolated(
			footer,
			x + (width - fw) / 2 - 50,
			yPrev + height - 18,
			0.6,
			x + (width - fw) / 2 - 50,
			yCurr + height - 18,
			0.6
		)

		for idx, pIndex in ipairs(activePlayers) do
			local np = gNetworkPlayers[pIndex]

			if np then
				local location = get_player_location(pIndex)

				local sSync = gPlayerSyncTable[pIndex]

				local wins = sSync.gameWins or 0

				local minigameWins = sSync.minigameWins or 0

				local totalPoints = sSync.totalPoints or 0

				local ping = pingCache[pIndex]

				if ping == nil then
					ping = np.ping or 0
					pingCache[pIndex] = ping
				end

				local rowYPrev = baseYPrev + ((idx - 1) * rowSpacing)

				local rowYCurr = baseYCurr + ((idx - 1) * rowSpacing)

				HU.render_player_head_interpolated(
					pIndex,
					x + 20,
					rowYPrev,
					x + 20,
					rowYCurr,
					1.5,
					1.5,
					false,
					false,
					opacity
				)

				HU.print_colored_text_interpolated(
					network_get_player_text_color_string(pIndex) .. get_display_name(pIndex),

					x + 55,
					rowYPrev,

					x + 55,
					rowYCurr,

					0.8,
					opacity
				)

				djui_hud_set_color(
					np.descriptionR or 255,
					np.descriptionG or 255,
					np.descriptionB or 255,
					(np.descriptionA or 255) * tCurr
				)

				djui_hud_print_text_interpolated(
					tostring(np.description or "???"),
					x + 250,
					rowYPrev,
					0.7,
					x + 250,
					rowYCurr,
					0.7
				)

				djui_hud_set_color(255, 255, 255, opacity)

				djui_hud_print_text_interpolated(
					tostring(location),
					x + width - 480,
					rowYPrev,
					0.7,
					x + width - 480,
					rowYCurr,
					0.7
				)

				local r, g, b

				if ping <= 50 then
					r, g, b = 0, 255, 0
				elseif ping <= 100 then
					r, g, b = 180, 255, 0
				elseif ping <= 150 then
					r, g, b = 255, 255, 0
				elseif ping <= 250 then
					r, g, b = 255, 140, 0
				else
					r, g, b = 255, 0, 0
				end

				djui_hud_set_color(r, g, b, opacity)

				djui_hud_print_text_interpolated(ping .. " ms", x + 350, rowYPrev, 0.7, x + 350, rowYCurr, 0.7)

				djui_hud_set_color(255, 255, 100, opacity)

				local statText

				if scoreboardPage == 0 then
					statText = tostring(wins) .. " | " .. tostring(minigameWins)
				else
					statText = tostring(totalPoints)
				end

				djui_hud_print_text_interpolated(
					statText,
					x + width - 280,
					rowYPrev,
					0.7,
					x + width - 280,
					rowYCurr,
					0.7
				)
			end
		end
	else
		djui_hud_set_color(255, 255, 255, opacity)

		local modTitle = translate("active_mods") .. tostring(modsTotal) .. ")"

		djui_hud_print_text_interpolated(modTitle, x + 20, titleYPrev, 1, x + 20, titleYCurr, 1)

		djui_hud_set_color(255, 255, 255, math.floor(100 * tCurr))

		HU.djui_hud_render_rect_rounded_interpolated(
			x + 15,
			yPrev + 45,
			width - 130,
			2,
			x + 15,
			yCurr + 45,
			width - 130,
			2,
			1
		)

		if #modsList == 0 then
			djui_hud_set_color(200, 200, 200, opacity)

			djui_hud_print_text_interpolated(
				translate("no_mods_active"),
				x + 20,
				yPrev + 65,
				0.7,
				x + 20,
				yCurr + 65,
				0.7
			)
		else
			local rowYBasePrev = yPrev + 65

			local rowYBaseCurr = yCurr + 65

			local maxTextW = width - 40

			for i, modName in ipairs(modsList) do
				local rowYPrev = rowYBasePrev + ((i - 1) * rowSpacing)

				local rowYCurr = rowYBaseCurr + ((i - 1) * rowSpacing)

				if (i - 1) % 2 == 0 then
					djui_hud_set_color(0, 0, 0, math.floor(30 * tCurr))

					HU.djui_hud_render_rect_rounded_interpolated(
						x + 10,
						rowYPrev - 6,
						width - 120,
						rowSpacing,
						x + 10,
						rowYCurr - 6,
						width - 120,
						rowSpacing,
						8
					)
				end

				local safeName = truncate_to_width(modName, 0.7, maxTextW)

				djui_hud_set_color(255, 255, 255, opacity)

				HU.print_colored_text_interpolated(safeName, x + 20, rowYPrev, x + 20, rowYCurr, 0.7, opacity)
			end
		end

		djui_hud_set_color(200, 200, 200, opacity)

		local footer = translate("l_players")

		local fw = djui_hud_measure_text(footer) * 0.6

		djui_hud_print_text_interpolated(
			footer,
			x + (width - fw) / 2 - 50,
			yPrev + height - 18,
			0.6,
			x + (width - fw) / 2 - 50,
			yCurr + height - 18,
			0.6
		)
	end
end

return M
